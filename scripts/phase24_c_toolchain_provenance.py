"""Patch 24.14: C toolchain provenance classification.

Static and report-only: no compiler build, no test execution.

Patch 24.14 removes C compiler discovery that exists to emit and build C as
a *backend product*, and must keep the supported native route's linker
driver, the retained hand-written C runtime, and the Phase-25-owned
bootstrap chain. Those share the `CC` variable and the `cc` binary, so a
criterion over how a call line is *spelled* cannot separate them. TASK.md
records one such attempt -- a categorisation by whether the command line
named a native object or a `.c` file -- as classifying 13 of 46 sites and
leaving 33 ambiguous, and rejects refining it as fitting rather than
measuring.

This instrument classifies by *provenance of the compiled input* instead:
for every surviving `cc` invocation it resolves each input argument to the
command that produces that file in the same script, and classifies the
producer. `"$build_root/native.o"` is a native object because
`compiler-mir-ingestion-object` writes it, not because the token ends in
`.o`; `"$build_dir/installed-final.c"` is a backend product because a
`--backend c` invocation writes the file it is concatenated from, not
because the token ends in `.c`.

Discovery sites that bind a compiler name are classified separately. A
binding no site references is dead C-toolchain discovery: it exists only to
serve an emission path that has already been converted away.

Falsifiability is over-approximating, and within the scope TASK.md fixes:
an input whose producer cannot be resolved is a FAILURE, not a pass. A new
`cc` site, or a new way of producing its input, fails here until it is
classified. The assertion is NOT that the retained discovery is the only
surviving `cc` consumer -- that form is unsatisfiable without deleting the
native route's own linking evidence.
"""

import argparse
import hashlib
import importlib.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts" / "cranelift_feature_registry.json"

GUARD = "guard-cranelift-phase24-c-toolchain-provenance-contract"
VERSION = "phase24_c_toolchain_provenance_v1"

# Classes whose compiled input is a product of the retired generated-C
# backend. A surviving invocation in this class is residue 24.14 or a named
# later owner must take out.
BACKEND_PRODUCT = "backend-emitted-c"

# Retained classes. Each names a thing that survives Phase 24 by decision,
# not by oversight.
NATIVE_OBJECT = "native-object"          # Cranelift output; cc links it
RETAINED_RUNTIME_C = "retained-runtime-c"  # hand-written, Phase 17.7
SCRIPT_AUTHORED_C = "script-authored-c"  # heredoc probe, not a backend product
RUST_ARCHIVE = "rust-archive"            # Phase 17.6 staticlib
TOOLCHAIN_QUERY = "toolchain-query"      # --version / -dumpmachine, no input

RETAINED = frozenset(
    {NATIVE_OBJECT, RETAINED_RUNTIME_C, SCRIPT_AUTHORED_C, RUST_ARCHIVE, TOOLCHAIN_QUERY}
)

# Ownership for surviving backend-product invocations. 24.14 removes the
# *toolchain* half of a route; where the emitting half is owned by a later
# patch, the cc site retires with it rather than being deleted early.
#
# Owners are DERIVED from the retirement inventory, never listed here. A hand
# list would drift away from the census silently and would let a site keep an
# owner the inventory no longer gives it; deriving means a backend-product cc
# site whose file the inventory does not own fails here.
INVENTORY = ROOT / "scripts" / "phase24_retirement_consumer_inventory.py"

# The native route's linker driver, excepted by name (#401).
LINKER_DRIVER_FILE = "compiler/experiments/cranelift/src/main.rs"

FLAG_WITH_VALUE = {"-o", "-I", "-L", "-include", "-isystem", "-MF", "-x"}

TOOLCHAIN_QUERY_FLAGS = ("--version", "-dumpmachine", "-dumpversion", "-print-prog-name")

CC_HEAD = re.compile(
    r'^\s*(?:if\s+|!\s+|then\s+)*'
    r'(?P<cc>"?\$\{CC:-cc\}"?|"?\$\{CC_BIN\}"?|"?\$CC_BIN"?|"?\$CC"?|cc)\s'
)
CC_BINDING = re.compile(r'^\s*(?P<name>[A-Za-z_][A-Za-z0-9_]*)=(?P<rhs>.*\$\{?CC\b.*|"?cc"?)\s*$')


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD}: {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def digest(value: object) -> str:
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()


CONTINUES = ("\\", "|", "&&", "||")


def logical_lines(text: str):
    """Yield (lineno, joined) with shell line continuations folded in.

    A trailing `|` continues a command as surely as a trailing backslash does.
    `./gust --backend c "$src" |` on one line and `grep ... >"$dir/stage2.c"` on
    the next is one pipeline producing one file; reading them separately shows
    a redirect with no visible producer and a backend emission with no visible
    output.
    """
    raw = text.split("\n")
    index = 0
    while index < len(raw):
        start = index
        buf = raw[index]
        while index + 1 < len(raw):
            stripped = buf.rstrip()
            if stripped.endswith("\\"):
                buf = stripped[:-1]
            elif any(stripped.endswith(op) for op in CONTINUES[1:]):
                buf = stripped
            else:
                break
            index += 1
            buf = buf + " " + raw[index]
        yield start + 1, buf
        index += 1


def strip_quotes(token: str) -> str:
    token = token.strip()
    while len(token) >= 2 and token[0] == token[-1] and token[0] in "\"'":
        token = token[1:-1]
    return token


def split_tokens(line: str) -> list:
    """Split a shell command line on unquoted whitespace, keeping quotes."""
    tokens = []
    buf = ""
    quote = None
    for char in line:
        if quote:
            buf += char
            if char == quote:
                quote = None
            continue
        if char in "\"'":
            quote = char
            buf += char
            continue
        if char.isspace():
            if buf:
                tokens.append(buf)
                buf = ""
            continue
        buf += char
    if buf:
        tokens.append(buf)
    return tokens


def command_inputs(line: str) -> tuple:
    """Return (inputs, is_query) for a cc command line.

    Inputs are the non-flag arguments that name something the compiler
    reads. Redirections, the -o target, and flag values are excluded.
    """
    tokens = split_tokens(line)
    # Drop everything from the first redirection or pipeline operator on:
    # a redirect target is not a compiler input.
    cut = len(tokens)
    for index, token in enumerate(tokens):
        bare = strip_quotes(token)
        if token.startswith((">", "<", "2>", "|", "&&", ";")) or bare in {"|", "&&", ";"}:
            cut = index
            break
        if re.match(r'^\d?>>?', token):
            cut = index
            break
    tokens = tokens[:cut]

    if any(strip_quotes(t) in TOOLCHAIN_QUERY_FLAGS for t in tokens):
        return [], True

    # `if cc ... ; then` puts a shell keyword in front of the compiler word.
    # Dropping "the first token" drops the keyword and leaves `cc` looking like
    # an input file with no producer.
    while tokens and strip_quotes(tokens[0]) in {"if", "!", "then", "else", "do"}:
        tokens = tokens[1:]

    inputs = []
    skip = False
    seen_cc = False
    for token in tokens:
        if skip:
            skip = False
            continue
        bare = strip_quotes(token)
        if not seen_cc:
            # the compiler word itself
            seen_cc = True
            continue
        if bare in FLAG_WITH_VALUE:
            skip = True
            continue
        if bare.startswith("-"):
            continue
        if bare.startswith("${") and ":-" in bare:
            # ${CFLAGS:--O2 ...} / ${INCLUDES:--Isrc}: flag defaults
            continue
        if bare.startswith("$") and re.fullmatch(r'\$\{?[A-Z_]+\}?', bare):
            # a bare uppercase variable holding flags
            continue
        if not bare:
            continue
        inputs.append(bare)
    return inputs, False


BACKEND_EMIT = re.compile(r'--backend (?:mir-to-c|c)(?=[\s"\']|$)')
NATIVE_EMIT = re.compile(
    r'--backend cranelift|compiler-mir-ingestion-object|--emit[= ]obj|'
    r'compiler-mir-native-object|gust-native-backend|cranelift-experiment'
)
ARCHIVE_PRODUCER = re.compile(r'cargo\s+build|--manifest-path|staticlib')
AUTHORED_WRITE = re.compile(r'<<[-~]?\s*[\'"]?[A-Za-z_]+|printf\s|echo\s|cat\s+>')

# The `.gst` smoke-test entries reach a MIR-to-C emitter as a library call and
# write its output straight to disk, never spelling `--backend` (#422). The
# compiled result is a layout oracle for the *surviving* native route: its
# `_Static_assert`s fail if a Cranelift-computed offset, size, or alignment
# disagrees with the platform C ABI. The consumer is therefore retained and the
# producer is unowned, which is what #422 exists to resolve -- so it gets its
# own class rather than being folded into either side.
LAYOUT_ORACLE_C = "layout-oracle-c"

# The Makefile's C is the bootstrap chain: it assembles generated stage files
# with the host C compiler to build the gust compiler binary itself. TASK.md
# excepts this BY NAME and leaves it Phase-25-owned -- removing the backend is
# not removing the bootstrap chain's C.
#
# The exception is defined by what the compile PRODUCES, not by which file it
# lives in: a cc invocation in the Makefile qualifies only if its -o target is
# a gust compiler binary. A new Makefile cc site building anything else is not
# covered by the Phase 25 exception and fails.
BOOTSTRAP_CHAIN_C = "bootstrap-chain-c"
COMPILER_BINARIES = frozenset(
    {"gust", "gust_bootstrap", "build/gust_stage1_bin", "build/gust_stage2_bin"}
)

RETAINED = RETAINED | frozenset({LAYOUT_ORACLE_C, BOOTSTRAP_CHAIN_C})

GST_EMITTER = re.compile(r'mir_[a-z_0-9]*_c_source|_to_c_source')
JUST_GUARD_ENTRY = re.compile(r'just guard (compiler/[A-Za-z0-9_]+\.gst)')


def tail_key(token: str) -> str:
    """The recognisable tail of a path expression: what a producer writes."""
    token = strip_quotes(token)
    if "/" in token:
        token = token.rsplit("/", 1)[1]
    return token


def variable_name(token: str):
    bare = strip_quotes(token)
    match = re.fullmatch(r'\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?', bare)
    return match.group(1) if match else None


def resolve_variable(name: str, lines: list, depth: int = 0):
    """Follow `name=<value>` assignments to a concrete-ish expression."""
    if depth > 4:
        return None
    for _, line in lines:
        match = re.match(r'^\s*(?:local\s+)?' + re.escape(name) + r'=(.+)$', line)
        if not match:
            continue
        value = strip_quotes(match.group(1).strip())
        nested = variable_name(value)
        if nested:
            return resolve_variable(nested, lines, depth + 1)
        return value
    return None


def classify_producer(line: str) -> str:
    """What kind of thing writes a file, judged by the command that writes it."""
    if BACKEND_EMIT.search(line):
        return BACKEND_PRODUCT
    if NATIVE_EMIT.search(line):
        return NATIVE_OBJECT
    if ARCHIVE_PRODUCER.search(line):
        return RUST_ARCHIVE
    if AUTHORED_WRITE.search(line):
        return SCRIPT_AUTHORED_C
    return ""


def gst_entry_emits(key: str, lines: list) -> bool:
    """True when a `.gst` entry this script runs writes `key` from an emitter.

    Provenance leaves the shell here: the script runs `just guard <entry>.gst`,
    and the entry calls a MIR-to-C emitter and writes the result itself. A
    resolver that only reads the script sees a file with no producer, which is
    exactly how this family stayed out of the census (#422).
    """
    for _, line in lines:
        match = JUST_GUARD_ENTRY.search(line)
        if not match:
            continue
        entry = ROOT / match.group(1)
        if not entry.exists():
            continue
        text = entry.read_text()
        if key in text and GST_EMITTER.search(text):
            return True
    return False


def mention_lines(key: str, lines: list, skip_lineno: int) -> list:
    """Every line naming the file, not only those spelling `-o` or `>`.

    A native object is written positionally --
    `"$worker" compiler-mir-ingestion-object "$mir" "$build_root/native.o"` --
    so a producer search keyed on redirection syntax misses it and reports no
    provenance for the supported route's own output.
    """
    pattern = re.compile(re.escape(key))
    return [
        (lineno, line)
        for lineno, line in lines
        if lineno != skip_lineno and pattern.search(line)
    ]


def loop_expansions(key: str, lines: list) -> list:
    """Expand `for VAR in a b c` bindings appearing in a path key.

    `"$build_dir/$variant-final.c"` names two files, not one. Leaving the
    variable unexpanded loses the producer for both.
    """
    match = re.search(r'\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?', key)
    if not match:
        return [(key, lines)]
    name = match.group(1)
    values = []
    for _, line in lines:
        loop = re.match(r'^\s*for\s+' + re.escape(name) + r'\s+in\s+(.+?)(?:;|$)', line)
        if loop:
            values = [strip_quotes(v) for v in split_tokens(loop.group(1))]
            break
    values = [value for value in values if "$" not in value]
    if not values:
        return [(key, lines)]
    spelling = match.group(0)
    # Substituting into the key alone finds nothing: the producer spells the
    # variable too. Expand both sides, so `"$build_dir/$variant-final.c"` and
    # the `cat ... >"$build_dir/$variant-final.c"` that writes it meet.
    return [
        (
            key.replace(spelling, value),
            [(lineno, line.replace(spelling, value)) for lineno, line in lines],
        )
        for value in values
    ]


BUILD_FILES = ("Makefile", "justfile")
BUILD_INVOKE = re.compile(r'\b(?:make|just)\s+([A-Za-z0-9_.-]+)')


def build_system_produces(key: str, lines: list) -> str:
    """Classify a key produced by a `make`/`just` target the script runs.

    Provenance leaves the shell a second way: `make phase10-native-package`
    builds `build/gust-runtime-package.a` before any `cc` sees it. A resolver
    confined to the script reports no producer for an artifact the build
    system plainly owns.
    """
    targets = set()
    for _, line in lines:
        for match in BUILD_INVOKE.finditer(line):
            targets.add(match.group(1))
    if not targets:
        return ""
    for name in BUILD_FILES:
        path = ROOT / name
        if not path.exists():
            continue
        text = path.read_text()
        for target in targets:
            block = re.search(
                r'^' + re.escape(target) + r'\s*:.*?(?=^\S|\Z)',
                text,
                re.MULTILINE | re.DOTALL,
            )
            if not block:
                continue
            body = block.group(0)
            if key not in body and tail_key(key) not in body:
                continue
            klass = classify_producer(body)
            if klass:
                return klass
            if re.search(r'\bar\b|\.a\b|libtool', body):
                return RUST_ARCHIVE
    return ""


def cargo_artifact(expression: str) -> bool:
    """True when the resolved path sits under a crate the tree builds."""
    parts = Path(expression).parts
    for stop in range(len(parts), 0, -1):
        candidate = ROOT.joinpath(*parts[:stop])
        if (candidate / "Cargo.toml").exists():
            return True
    return False


def resolve_input(token: str, lines: list, lineno: int) -> dict:
    """Classify one compiler input by how the file it names is produced."""
    bare = strip_quotes(token)
    record = {"token": bare}

    literal = bare.lstrip("./")
    if "$" not in bare and (ROOT / literal).exists():
        record["klass"] = RETAINED_RUNTIME_C
        record["why"] = f"tracked repo source {literal}"
        return record

    name = variable_name(bare)
    expression = bare
    if name:
        resolved = resolve_variable(name, lines)
        if resolved:
            expression = resolved
            record["resolved"] = resolved

    # A resolved path that exists is hand-written source, wherever the token
    # reached it from: `"$probe"` naming compiler/fixtures/*.c is no more a
    # backend product than `src/runtime/arena.c` spelled literally.
    if "$" not in expression and (ROOT / expression.lstrip("./")).exists():
        record["klass"] = RETAINED_RUNTIME_C
        record["why"] = f"tracked repo source {expression}"
        return record

    if "$" not in expression and cargo_artifact(expression):
        record["klass"] = RUST_ARCHIVE
        record["why"] = f"{expression} is built from a crate in this tree"
        return record

    key = tail_key(expression)
    if not key or key.startswith("$"):
        key = tail_key(bare)

    classes = set()
    for variant, scope in loop_expansions(key, lines):
        if gst_entry_emits(variant, scope):
            classes.add(LAYOUT_ORACLE_C)
            continue

        mentions = mention_lines(variant, scope, lineno)
        found = {classify_producer(line) for _, line in mentions}
        found.discard("")

        # `cat src/runtime.c "$dir/x.c" > "$dir/x-final.c"` makes the final file
        # a backend product when a concatenated part is one. Follow one hop.
        if not found:
            for _, line in mentions:
                for part in split_tokens(line):
                    part_key = tail_key(part)
                    if not part_key or part_key == variant:
                        continue
                    for _, deep in mention_lines(part_key, scope, lineno):
                        klass = classify_producer(deep)
                        if klass:
                            found.add(klass)

        if not found:
            klass = build_system_produces(variant, scope)
            if klass:
                found.add(klass)

        classes |= found

    if LAYOUT_ORACLE_C in classes:
        record["klass"] = LAYOUT_ORACLE_C
        record["why"] = f"{key} is written by a .gst entry's MIR-to-C emitter (#422)"
        return record

    if BACKEND_PRODUCT in classes:
        record["klass"] = BACKEND_PRODUCT
        record["why"] = f"{key} is written by a retired-backend emission"
        return record
    if classes:
        record["klass"] = sorted(classes)[0]
        record["why"] = f"{key} is written by a {sorted(classes)[0]} producer"
        return record

    record["klass"] = ""
    record["why"] = f"no producer resolved for {key}"
    return record


MAKE_CC = re.compile(r'^\s*@?\$\{CC\}\s')
MAKE_OUTPUT = re.compile(r'-o\s+(\S+)\s*$')


def scan_makefile() -> dict:
    """Classify the Makefile's own C toolchain sites.

    The provenance instrument covered scripts/*.sh only, which left the
    bootstrap chain -- the largest surviving C consumer in the tree -- outside
    the measurement entirely. An exception nothing checks is an assertion, not
    an exception.
    """
    path = ROOT / "Makefile"
    text = path.read_text()
    lines = [
        (lineno, line)
        for lineno, line in logical_lines(text)
        if not line.strip().startswith("#")
    ]

    invocations = []
    for lineno, line in lines:
        if not MAKE_CC.match(line):
            continue
        output = MAKE_OUTPUT.search(line)
        target = output.group(1) if output else ""
        invocations.append(
            {
                "file": "Makefile",
                "line": lineno,
                "spelling": "${CC}",
                "query": False,
                "target": target,
                "inputs": [
                    {
                        "token": target,
                        "klass": BOOTSTRAP_CHAIN_C if target in COMPILER_BINARIES else "",
                        "why": (
                            f"builds the compiler binary {target}; Phase-25-owned "
                            "bootstrap chain, excepted by name"
                            if target in COMPILER_BINARIES
                            else f"Makefile cc builds {target!r}, which is not a gust "
                            "compiler binary, so the Phase 25 bootstrap exception "
                            "does not cover it"
                        ),
                    }
                ],
            }
        )
    return {"file": "Makefile", "bindings": {}, "dead_bindings": [], "invocations": invocations}


def shell_scripts() -> list:
    return sorted(ROOT.glob("scripts/*.sh"))


def scan_script(path: Path) -> dict:
    text = path.read_text()
    lines = [
        (lineno, line)
        for lineno, line in logical_lines(text)
        if not line.strip().startswith("#")
    ]
    rel = path.relative_to(ROOT).as_posix()

    bindings = {}
    invocations = []
    for lineno, line in lines:
        binding = CC_BINDING.match(line)
        if binding and re.search(r'\$\{?CC\b|(?<![\w-])cc(?![\w-])', binding.group("rhs")):
            bindings[binding.group("name")] = lineno
            continue
        head = CC_HEAD.match(line)
        if not head:
            continue
        inputs, is_query = command_inputs(line)
        invocations.append(
            {
                "file": rel,
                "line": lineno,
                "spelling": strip_quotes(head.group("cc")),
                "query": is_query,
                "inputs": [resolve_input(token, lines, lineno) for token in inputs],
            }
        )

    referenced = set()
    for name, bound_at in bindings.items():
        pattern = re.compile(r'\$\{?' + re.escape(name) + r'\}?')
        for lineno, line in lines:
            if lineno == bound_at:
                continue
            if pattern.search(line):
                referenced.add(name)
                break

    dead = sorted(name for name in bindings if name not in referenced)
    return {
        "file": rel,
        "bindings": bindings,
        "dead_bindings": [{"name": n, "line": bindings[n]} for n in dead],
        "invocations": invocations,
    }


def scan() -> dict:
    scripts = []
    for path in shell_scripts():
        record = scan_script(path)
        if record["bindings"] or record["invocations"]:
            scripts.append(record)
    scripts.append(scan_makefile())
    return {"scripts": scripts}


def population(report: dict) -> dict:
    invocations = [i for s in report["scripts"] for i in s["invocations"]]
    dead = [
        {"file": s["file"], **binding}
        for s in report["scripts"]
        for binding in s["dead_bindings"]
    ]
    by_class = {}
    unresolved = []
    backend = []
    for inv in invocations:
        where = {"file": inv["file"], "line": inv["line"]}
        if inv["query"]:
            by_class.setdefault(TOOLCHAIN_QUERY, []).append(where)
            continue
        if not inv["inputs"]:
            unresolved.append({**where, "reason": "invocation with no resolvable input"})
            continue
        for record in inv["inputs"]:
            klass = record["klass"]
            if not klass:
                unresolved.append({**where, "reason": record["why"]})
            elif klass == BACKEND_PRODUCT:
                backend.append({**where, "why": record["why"]})
            else:
                by_class.setdefault(klass, []).append(where)
    return {
        "invocations": len(invocations),
        "dead_bindings": dead,
        "by_class": {k: len(v) for k, v in sorted(by_class.items())},
        "members": {k: sorted({(w["file"], w["line"]) for w in v}) for k, v in by_class.items()},
        "backend_product": backend,
        "unresolved": unresolved,
    }


def inventory_owner(path: str) -> str:
    """The owning patch the retirement inventory records for a file.

    Read out of the inventory's own tables so the two cannot disagree. The
    inventory is the census every removal patch is sequenced from; if it does
    not own a file that still compiles a backend product, that is the finding,
    not something to paper over locally.
    """
    spec = importlib.util.spec_from_file_location("_inventory", INVENTORY)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    for family in module.SH_FAMILIES.values():
        if path in family.get("files", {}):
            return family["owner_patch"]
    # Row tables name the file inside a command string as often as they name
    # it as a cell: `bash scripts/run-gust-file.sh "$fixture"` owns the script
    # without ever spelling it alone. Match on containment, not equality.
    tables = (
        "RECIPE_ROWS", "WORKFLOW_ROWS", "REGISTRY_ROWS",
        "FILE_ROWS", "SCRIPT_ROWS", "RETIRED_FILE_SURFACES",
    )
    owner_pattern = re.compile(r'^(?:24\.\d+[a-z]?|stdlib-coordination|phase25)$')
    for table in tables:
        for row in getattr(module, table, []):
            if not isinstance(row, (list, tuple)):
                continue
            cells = [c for c in row if isinstance(c, str)]
            if not any(path in cell for cell in cells):
                continue
            for cell in cells:
                if owner_pattern.match(cell):
                    return cell
    return ""


TEST_SUITE_PASSTHROUGH = (
    'CC="${CC}" CFLAGS="${CFLAGS}" INCLUDES="${INCLUDES}" just make-test-suite'
)


def check_test_suite_passthrough() -> None:
    """`make test` hands CC to the suite; 24.14 migrates that row, not deletes it.

    The inventory files this row under `migrate`, and the migration is a
    RECLASSIFICATION rather than a removal: after the provenance pass, every
    surviving consumer of this passthrough is a native-route linker, a retained
    hand-written C source, a script-authored probe, a Phase 17.6 archive, or a
    layout oracle (#422) -- plus the backend products the inventory still owns
    by name. None of them is an unowned backend product, which is exactly what
    validate() asserts globally.

    So the row survives, and deleting the passthrough would break the native
    route's own linking rather than remove a generated-C route. Pinning it here
    means a patch that reads "24.14 removes C compiler discovery" literally, and
    takes this line out, fails with the reason instead of somewhere downstream
    with a missing binary.
    """
    makefile = (ROOT / "Makefile").read_text()
    require(
        TEST_SUITE_PASSTHROUGH in makefile,
        "the test-suite C toolchain passthrough is gone. 24.14 migrates this "
        "row rather than retiring it: its surviving consumers link Cranelift "
        "output and compile the retained hand-written runtime, so removing it "
        "breaks the supported route instead of removing a backend route",
    )


def check_linker_driver() -> None:
    """The native route's linker driver, excepted by name (#401)."""
    path = ROOT / LINKER_DRIVER_FILE
    require(path.exists(), f"the native linker driver file is missing: {LINKER_DRIVER_FILE}")
    text = path.read_text()
    require(
        'env::var_os("CC")' in text,
        "the native route's CC discovery is gone: deleting it removes the "
        "ability to link, not the ability to emit C (#401)",
    )
    require(
        "Command::new(&request.linker_driver)" in text,
        "the discovered linker driver is no longer invoked from the link "
        "request: discovery that nothing reaches is not an exception (#401)",
    )


def validate() -> dict:
    report = scan()
    pop = population(report)

    check_linker_driver()
    check_test_suite_passthrough()

    require(
        not pop["unresolved"],
        "C toolchain inputs with no resolved provenance: "
        + ", ".join(
            f"{u['file']}:{u['line']} ({u['reason']})" for u in pop["unresolved"][:6]
        )
        + (f" and {len(pop['unresolved']) - 6} more" if len(pop["unresolved"]) > 6 else "")
        + ". An input whose producer cannot be resolved fails here rather than "
        "passing as retained: a new cc site, or a new way of producing its "
        "input, must be classified before it lands.",
    )

    owners = {}
    unowned = []
    for record in pop["backend_product"]:
        owner = inventory_owner(record["file"])
        if owner:
            owners[f"{record['file']}:{record['line']}"] = owner
        else:
            unowned.append(record)
    require(
        not unowned,
        "cc invocations compiling a retired-backend product that the "
        "retirement inventory does not own: "
        + ", ".join(f"{b['file']}:{b['line']}" for b in unowned)
        + ". 24.14 removes the toolchain half of a route; the emitting half "
        "must have a named owner, or the route has no retirement at all.",
    )

    require(
        not pop["dead_bindings"],
        "C toolchain discovery that nothing references: "
        + ", ".join(f"{b['file']}:{b['line']} ({b['name']})" for b in pop["dead_bindings"])
        + ". A binding no site reads exists only to serve an emission path "
        "that has already been converted away.",
    )

    summary = {
        "version": VERSION,
        "invocations": pop["invocations"],
        "by_class": pop["by_class"],
        "dead_bindings": len(pop["dead_bindings"]),
        "backend_product": len(pop["backend_product"]),
    }
    summary["backend_product_owners"] = owners
    summary["digest"] = digest(
        {"by_class": pop["by_class"], "members": {k: v for k, v in sorted(pop["members"].items())}}
    )
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command", choices=["report", "validate"], nargs="?", default="validate"
    )
    arguments = parser.parse_args()
    if arguments.command == "report":
        pop = population(scan())
        print(json.dumps(pop, indent=2, sort_keys=True, default=list))
        return
    summary = validate()
    print(json.dumps(summary, indent=2, sort_keys=True))
    print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
