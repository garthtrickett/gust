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

# C replayed from the frozen oracle (#398). Retained, and a class of its own
# rather than folded into BACKEND_PRODUCT or SCRIPT_AUTHORED_C, because it is
# neither and the difference is the whole point of this guard.
#
# It is not a backend product: no generated-C backend runs, and none exists to
# run -- the bytes were emitted at capture time and are read back from
# compiler/fixtures. Scoring it as one would make this guard report live
# backend residue that is not there, and hand the site an owner from the
# retirement inventory for work already done.
#
# It is not script-authored either: nobody wrote this C by hand, and calling
# it authored would lose the fact that it is a recording of what the retired
# backend produced -- which is exactly what Phase 25 will need to know when it
# asks what still compiles C.
FROZEN_ORACLE_C = "frozen-oracle-c"

RETAINED = frozenset(
    {NATIVE_OBJECT, RETAINED_RUNTIME_C, SCRIPT_AUTHORED_C, RUST_ARCHIVE,
     TOOLCHAIN_QUERY, FROZEN_ORACLE_C}
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
    # PR #450 review (P1): the head was anchored past `if`/`!`/`then` only,
    # so a compile written as
    #   CC_BIN="${CC:-cc}"; CFLAGS_VAL="..."; "$CC_BIN" $CFLAGS_VAL ...
    # was not an invocation at all. justfile:22547, :22614 and :22654 are
    # exactly that shape and were absent from the population, which made a
    # "zero unresolved" result a statement about an incomplete enumeration.
    # Leading `VAR=value;` assignments are skipped so the command is seen.
    r'''(?:[A-Za-z_][A-Za-z0-9_]*=(?:"[^"]*"|'[^']*'|\S*)\s*;\s*)*'''
    r'(?:if\s+|!\s+|then\s+)*'
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


# `bootstrap-emitter` is a C-emitting backend spelling too. Patch 24.13 moved
# the whole bootstrap chain onto it, so a producer written as
# `--backend bootstrap-emitter ... > stage2.c` was invisible here and its
# consumer failed as "no producer resolved" -- which is this guard working:
# a new way of producing a C input must be classified before it lands.
BACKEND_EMIT = re.compile(
    r'--backend (?:mir-to-c|bootstrap-emitter|c)(?=[\s"\']|$)')
NATIVE_EMIT = re.compile(
    r'--backend cranelift|compiler-mir-ingestion-object|--emit[= ]obj|'
    r'compiler-mir-native-object|gust-native-backend|cranelift-experiment|'
    # Issue #436: the justfile runs the Cranelift experiment through
    # `cargo run --manifest-path compiler/experiments/cranelift/Cargo.toml
    #  -- <subcommand> "$object_file"`, writing the object POSITIONALLY.
    # That form matched nothing here, so `writes_key`'s positional branch
    # never fired and the objects resolved to no producer at all -- 52 of
    # the 54 that remained unresolved once scoping landed. It also matches
    # ARCHIVE_PRODUCER on `--manifest-path`, so anything that did reach the
    # fallback was called a rust-archive. `cargo run` on that crate emits
    # objects; it does not build an archive.
    r'cargo\s+run[^\n]*experiments/cranelift'
)
ARCHIVE_PRODUCER = re.compile(r'cargo\s+build|--manifest-path|staticlib')
AUTHORED_WRITE = re.compile(r'<<[-~]?\s*[\'"]?[A-Za-z_]+|printf\s|echo\s|cat\s+>')
# A file taken from `<prefix>.compile.stdout` came out of the frozen oracle:
# that suffix is written by `phase24_frozen_oracle.py materialize` and by
# nothing else. Matching the name rather than the materialize call is what
# lets provenance survive the copy -- the script materializes into one path
# and compiles a concatenation of another, and the resolver follows one hop.
# The name alone is not trusted: FROZEN_MATERIALIZE must also appear in the
# same file, so a coincidental filename cannot claim the class.
FROZEN_RECORD = re.compile(r'\.compile\.stdout')
FROZEN_MATERIALIZE = re.compile(r'phase24_frozen_oracle\.py\s+materialize')

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


def classify_producer(line: str, source: str = "") -> str:
    """What kind of thing writes a file, judged by the command that writes it."""
    if FROZEN_RECORD.search(line) and FROZEN_MATERIALIZE.search(source):
        return FROZEN_ORACLE_C
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


def looks_like_path(token: str) -> bool:
    """True when a token could name a file, so the one-hop can follow it.

    Issue #436. The hop below split the writing line and followed EVERY
    token, so it grepped the script for `-c`, `-o` and `cc` and classified
    from whatever those substrings happened to hit. Measured on
    scripts/phase17_retained_c_runtime_parity.sh, following `-c` reached a
    line that reads as native-object and that is how arena.o -- an object
    compiled from tracked hand-written runtime C -- acquired a
    Cranelift-output classification.

    A flag is not a file, and neither is a bare word with no separator in
    it. A `/` or a `.` says the token can name a path; a `$` says it holds
    one.

    Raised in review on #442 (P2): an earlier draft required `/` or `.`
    only, which filtered `"$generated_c"` -- a variable holding a path with
    no separator in its own name. That broke the hop for

        ./gust --backend c ... > "$generated_c"
        cat "$generated_c" > "$build_dir/final.c"

    and would have reported final.c unresolved where the parent correctly
    reached backend-emitted-c. No site in the current population took that
    shape, so the per-site diff stayed clean and the gap was invisible --
    but variable-held inputs are pervasive in the justfile recipes this is
    preparing to scan, which is exactly where it would have bitten.
    """
    bare = strip_quotes(token)
    if not bare or bare.startswith("-"):
        return False
    return "/" in bare or "." in bare or "$" in bare


def classify_writer_inputs(line: str) -> str:
    """Classify a product from the tracked source its writing line compiles.

    Issue #436. Preferring the writing line is only half the repair: the
    generic classifier matches on how a line SPELLS its producer -- a
    backend flag, a cargo invocation, a heredoc -- and

        cc -O2 -c src/runtime/arena.c -I src/runtime -o "$build_dir/arena.o"

    spells none of them. It returns nothing, resolution falls through, and
    the object gets whatever some later heuristic offers.

    Measured on that exact line: before the writer preference, arena.o was
    classified script-authored-c from an `echo` on line 52 that merely
    names it in a note; after, it fell through to native-object. Both are
    wrong. It is an object compiled from tracked hand-written runtime C, so
    it inherits that source's class.

    Only tracked files count. A `$`-bearing token names something this
    function cannot resolve, and a path that is not in the repo is not
    hand-written runtime C by any evidence available here.
    """
    tokens = split_tokens(line)
    skip_next = False
    for token in tokens:
        bare = strip_quotes(token)
        if skip_next:
            skip_next = False
            continue
        if bare in FLAG_WITH_VALUE:
            skip_next = True
            continue
        if bare.startswith("-") or "$" in bare:
            continue
        candidate = ROOT / bare.lstrip("./")
        if candidate.is_file() and candidate.suffix in (".c", ".h"):
            return RETAINED_RUNTIME_C
    return ""


def var_aliases(name: str) -> list:
    """The spellings a shell line uses to name a variable-bound path."""
    if not name:
        return []
    return [f"${name}", "${" + name + "}"]


def writes_any(line: str, variant: str, name: str) -> bool:
    """True when `line` writes the key, named directly or through its variable.

    Issue #436: `writes_key` compared only against the resolved tail, but a
    justfile recipe binds `generated_c="build/.../tiny_return_int.c"` and then
    writes `printf ... > "$generated_c"`. The binding mentions the key and the
    writer does not, so the writer scan found nothing and resolution fell
    through. The variable is an alias for the key on the lines that matter.
    """
    if writes_key(line, variant):
        return True
    if not name:
        return False
    # PR #447 review (P2): `writes_key` tests substring containment, so an
    # alias of `$foo` matched a redirect to `$foobar` and `resolve_input`
    # adopted the wrong producer's class. Reproduced before fixing. A
    # variable reference has a boundary -- `$name` ends at the first
    # character that cannot continue an identifier -- so match the whole
    # reference rather than a prefix of one.
    return writes_variable(line, name)


VAR_REFERENCE = re.compile(r'\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?')


def writes_variable(line: str, name: str) -> bool:
    """True when `line` writes to the variable `name`, matched whole.

    Tokenises like `writes_key` and then compares the *resolved identifier*
    of each redirect or `-o` target, so `$foobar` is never a write to `$foo`.
    """
    tokens = split_tokens(line)
    for index, token in enumerate(tokens):
        target = None
        # A bare `>` is a redirect operator whose target is the NEXT token;
        # `>file` carries its own. Testing startswith(">") first swallowed
        # the bare case with an empty target and never looked ahead.
        if token in (">", ">>", "-o"):
            if index + 1 < len(tokens):
                target = tokens[index + 1]
        elif token.startswith(">") and token.lstrip(">"):
            target = token.lstrip(">")
        if target is None:
            continue
        match = VAR_REFERENCE.fullmatch(strip_quotes(target).strip())
        if match and match.group(1) == name:
            return True
    # Issue #436: the Cranelift experiment writes its object POSITIONALLY --
    # `cargo run --manifest-path .../cranelift -- <subcommand> "$object_file"`
    # -- and `cp`/`mv`/`install` write their destination the same way. Both
    # shapes are already honoured by writes_key for a literal key; they were
    # not honoured for a key reached through a variable, which is how these
    # objects were named. 52 of the 54 inputs left unresolved after scoping
    # were this.
    if not tokens:
        return False
    last = VAR_REFERENCE.fullmatch(strip_quotes(tokens[-1]).strip())
    if not last or last.group(1) != name:
        return False
    head = strip_quotes(tokens[0]).rsplit("/", 1)[-1]
    return bool(NATIVE_EMIT.search(line)) or head in ("cp", "mv", "install")


def writes_key(line: str, key: str) -> bool:
    """True when this line WRITES the named file, not merely mentions it.

    Issue #436: resolve_input picked a producer from any line naming the
    file, so for a justfile recipe it selected whichever mention happened to
    classify -- an unrelated `rg` over the file, a `cat` that reads it, a
    comment. The line that actually creates a file is the one that says what
    produced it; every other mention is a consumer and says nothing.

    Four shapes count as writing, and they are the four this tree uses:
    a redirection, an `-o` output, a `cp`/`mv` destination, and the worker's
    positional object output. A fifth shape appearing later fails closed --
    it simply is not a writer here, so resolution falls back to the mention
    scan rather than silently trusting a consumer.
    """
    tokens = split_tokens(line)
    for index, token in enumerate(tokens):
        if token.startswith(">"):
            if key in strip_quotes(token.lstrip(">")):
                return True
        if token in (">", ">>", "-o") and index + 1 < len(tokens):
            if key in strip_quotes(tokens[index + 1]):
                return True
    if not tokens:
        return False
    head = strip_quotes(tokens[0]).rsplit("/", 1)[-1]
    if head in ("cp", "mv", "install") and key in strip_quotes(tokens[-1]):
        return True
    if NATIVE_EMIT.search(line) and key in strip_quotes(tokens[-1]):
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
        # The whole script is the context for the frozen-oracle class: the
        # name says the file came from a recording, and this proves the
        # script is one that makes recordings.
        source = "\n".join(text for _, text in scope)
        # Issue #436: writers first. A line that creates the file says what
        # produced it; a line that reads it says nothing, and picking from
        # the mention set at large is how a justfile recipe's input got
        # classified from an unrelated `rg` over the same path.
        #
        # Fall back to the full mention set when no line writes the file,
        # rather than reporting no provenance: the positional worker output
        # and the build-system cases below are still resolved that way, and
        # narrowing this without them would turn resolvable inputs into
        # failures.
        alias_rows = list(mentions)
        seen = {row[0] for row in mentions}
        for alias in var_aliases(name):
            for row in scope:
                if alias in row[1] and row[0] not in seen:
                    alias_rows.append(row)
                    seen.add(row[0])
        writers = [row for row in alias_rows if writes_any(row[1], variant, name)]
        found = {classify_producer(line, source)
                 for _, line in (writers or mentions)}
        found.discard("")

        # `cat src/runtime.c "$dir/x.c" > "$dir/x-final.c"` makes the final file
        # a backend product when a concatenated part is one. Follow one hop.
        if not found:
            for _, line in mentions:
                for part in split_tokens(line):
                    if not looks_like_path(part):
                        continue
                    part_key = tail_key(part)
                    if not part_key or part_key == variant:
                        continue
                    for _, deep in mention_lines(part_key, scope, lineno):
                        klass = classify_producer(deep, source)
                        if klass:
                            found.add(klass)

        if not found:
            klass = build_system_produces(variant, scope)
            if klass:
                found.add(klass)

        # LAST, and the ordering is load-bearing. A writing line that spells
        # no producer still says what it compiled -- but only after the
        # one-hop above has had its say, because
        #
        #     cat src/runtime.c "$dir/stage2.c" > "$dir/stage2-final.c"
        #
        # writes a file whose tracked input is the runtime prelude and whose
        # MEANING is the emitted half. Running this first classified
        # stage2-final.c as retained-runtime-c and hid a backend product,
        # which is worse than the gap it was meant to close.
        if writers and not found:
            found = {classify_writer_inputs(line) for _, line in writers}
            found.discard("")

        classes |= found

    if LAYOUT_ORACLE_C in classes:
        record["klass"] = LAYOUT_ORACLE_C
        record["why"] = f"{key} is written by a .gst entry's MIR-to-C emitter (#422)"
        return record

    if BACKEND_PRODUCT in classes:
        record["klass"] = BACKEND_PRODUCT
        record["why"] = f"{key} is written by a retired-backend emission"
        return record
    # After BACKEND_PRODUCT, deliberately. If any path to this file runs a
    # live backend, that is the honest class even when another path replays a
    # record -- a site that does both is still a site that emits C.
    if FROZEN_ORACLE_C in classes:
        record["klass"] = FROZEN_ORACLE_C
        record["why"] = (
            f"{key} is replayed from the frozen oracle, not emitted (#398)")
        return record
    if classes:
        record["klass"] = sorted(classes)[0]
        record["why"] = f"{key} is written by a {sorted(classes)[0]} producer"
        return record

    # Issue #436: a shell function binds `local source="$1"` and the caller
    # passes `run_c "$mir_c" "$mir_bin"`, so the value is two hops away --
    # parameter, then the caller's variable. Resolving inside the function
    # body alone reports no producer for a file the recipe plainly writes.
    # The last three unresolved justfile inputs were exactly this shape.
    via_param = resolve_through_parameter(name, lines, lineno)
    if via_param:
        record["klass"] = via_param["klass"]
        record["why"] = (f"{key} is bound from a shell-function parameter; "
                         f"{via_param['why']}")
        return record

    record["klass"] = ""
    record["why"] = f"no producer resolved for {key}"
    return record


LOCAL_PARAM = re.compile(r'^\s*local\s+([A-Za-z_][A-Za-z0-9_]*)="?\$\{?([0-9]+)\}?"?\s*$')
FUNC_HEAD = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{')


def resolve_through_parameter(name: str, lines: list, lineno: int) -> dict:
    """Resolve a name bound from a positional shell-function parameter.

    Bounded on purpose: one hop from `local NAME="$N"` to the Nth argument
    at each call site, then the ordinary variable resolution on that
    argument. If the call sites disagree about the class, this returns
    nothing rather than picking one -- an ambiguous answer is worse than an
    honest gap.
    """
    if not name:
        return {}
    index = None
    for row_lineno, line in lines:
        match = LOCAL_PARAM.match(line)
        if match and match.group(1) == name:
            index = int(match.group(2))
            bind_at = row_lineno
            break
    if index is None or index < 1:
        return {}
    func = None
    for row_lineno, line in lines:
        if row_lineno > bind_at:
            break
        head = FUNC_HEAD.match(line)
        if head:
            func = head.group(1)
    if not func:
        return {}
    call = re.compile(r'\b' + re.escape(func) + r'\s+(.+)$')
    seen = {}
    for row_lineno, line in lines:
        if row_lineno == bind_at or LOCAL_PARAM.match(line):
            continue
        match = call.search(line)
        if not match:
            continue
        args = split_tokens(match.group(1).rstrip(')"\''))
        if len(args) < index:
            continue
        inner = resolve_input(args[index - 1], lines, row_lineno)
        # PR #450 review (P2): recording only the calls that resolved meant
        # `run_c "$good"` plus `run_c "$unknown"` left exactly one class in
        # `seen`, and the unresolved call was silently accepted as the good
        # one. That is the opposite of the fail-closed contract this
        # docstring claims. An argument that does not resolve is a
        # disagreement.
        seen[inner.get("klass") or ""] = inner.get("why", "")
    if len(seen) != 1 or "" in seen:
        return {}
    klass, why = next(iter(seen.items()))
    return {"klass": klass, "why": f"call sites pass {why}"}


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
    r"""Every file this guard reads for C toolchain sites.

    Issue #436 wants the justfile in here. It is still out, and the reason
    changed: the resolver can now classify it, and doing so uncovers a
    census gap that must be filed rather than absorbed.

    With the justfile enabled the population is 102 invocations and **zero
    unresolved** -- every input classified. But three of them,
    justfile:22547, :22614 and :22654, compile retired-backend products
    (`test_runner_step52_positive_final.c`, `test_runner_final.c`) that the
    retirement inventory does not own, and `validate` refuses:

        cc invocations compiling a retired-backend product that the
        retirement inventory does not own: justfile:22547, :22614, :22654

    `inventory_owner`'s own docstring says that is the finding and not
    something to paper over locally, so no local owner is added here. The
    three sites need an owning patch in the inventory; until they have one,
    enabling the scan would be trading a classification gap for an
    ownership gap.

    They were invisible until this patch. They are written as
    `CC_BIN=...; CFLAGS_VAL=...; "$CC_BIN" ...`, and `scan_script` matched
    CC_BINDING first and `continue`d, so a line that both binds and invokes
    was only ever counted as a binding.

    The history is kept because two diagnoses were wrong before the right
    one, and the wrongness is the useful part.

    First diagnosis: `build_system_produces`'s `\.a\b` fallback matched
    anywhere in a target body. Binding it to the key it writes left the
    count unchanged at 106, which is what said the cause was structural.

    Second: SCOPE. `scan_script` passed the whole file as the resolution
    scope -- right for `scripts/*.sh`, catastrophic for 22,605 lines of
    justfile. Per-recipe scoping plus variable aliasing in the writer scan
    took rust-archive 106 -> 1 and script-authored-c 5 -> 67, leaving 54
    honest "no producer resolved" gaps rather than false archives.

    Those 54 were two more shapes the resolver did not know:

      - The Cranelift experiment writes its object POSITIONALLY, via
        `cargo run --manifest-path .../cranelift -- <subcommand> "$out"`.
        `NATIVE_EMIT` did not match that form, and `ARCHIVE_PRODUCER` did
        match it on `--manifest-path`, so these were either unresolved or
        called archives. `cargo run` on that crate emits objects.

      - A shell function binds `local source="$1"` and the caller passes
        `run_c "$mir_c" "$mir_bin"`, so the value is two hops away. One
        bounded hop to the call sites resolves it; disagreeing call sites
        return nothing rather than a guess.

    Final population with the justfile in: bootstrap-chain-c 4,
    frozen-oracle-c 12, layout-oracle-c 10, native-object 57,
    retained-runtime-c 7, rust-archive 1, script-authored-c 69,
    toolchain-query 1. Zero unresolved.

    The check that matters is the one the issue posed. `justfile:1875` is
    `"$CC_BIN" $CFLAGS_VAL "$shim_c" "$object_file" -o "$binary"`, and it
    now classifies as BOTH `script-authored-c` for the printf shim and
    `native-object` for the Cranelift object -- the two samples #436 named
    as falsely `rust-archive`.

    Every repair is behaviour-preserving with the justfile excluded: the
    35-invocation population and its whole by_class distribution are
    unchanged from before any of this.
    """
    return sorted(ROOT.glob("scripts/*.sh")) + [ROOT / "justfile"]
RECIPE_HEAD = re.compile(r'^@?[A-Za-z0-9_][A-Za-z0-9_-]*(?:\s+[^:\n]*)?:(?!=)')


def recipe_names(lines: list) -> dict:
    """Map each line number to the name of the recipe containing it.

    PR #452 review (P1): authorization has to be per `(file, recipe,
    product)`. Product granularity still let any *new* recipe compiling a
    registered product inherit its owner. The scope machinery already
    knows where each recipe starts; this exposes the name so the
    invocation record can carry it.
    """
    names = {}
    current = ""
    for lineno, line in lines:
        head = RECIPE_HEAD.match(line)
        if head:
            current = line.split(":", 1)[0].strip().lstrip("@").split()[0]
        names[lineno] = current
    return names


def recipe_scopes(lines: list) -> dict:
    """Map each line number to the lines of the recipe that contains it.

    Issue #436: `scan_script` passed the WHOLE file as the resolution scope.
    For `scripts/*.sh` that is right -- they are small and single-purpose. For
    the 22,605-line justfile it is not: every `cc` site was resolved against
    every other recipe, and `build_system_produces` collected every `make`/
    `just` target in the file. `gust-runtime-package.a` appears among them, so
    inputs fell through to the archive fallback -- 105 of 117 classified
    `rust-archive`, including a printf shim and a native object.

    Scoping is the fix. A key-binding tweak to the fallback pattern was tried
    first and left the number unchanged at 106, which is what said the cause
    was structural rather than a pattern.
    """
    starts = [lineno for lineno, line in lines if RECIPE_HEAD.match(line)]
    if not starts:
        return {}
    scoped = {}
    for index, start in enumerate(starts):
        end = starts[index + 1] if index + 1 < len(starts) else None
        block = [
            (lineno, line)
            for lineno, line in lines
            if lineno >= start and (end is None or lineno < end)
        ]
        for lineno, _ in block:
            scoped[lineno] = block
    return scoped


def scan_script(path: Path) -> dict:
    text = path.read_text()
    lines = [
        (lineno, line)
        for lineno, line in logical_lines(text)
        if not line.strip().startswith("#")
    ]
    rel = path.relative_to(ROOT).as_posix()
    scoped = recipe_scopes(lines) if rel == "justfile" else {}
    recipe_of = recipe_names(lines) if rel == "justfile" else {}

    bindings = {}
    invocations = []
    for lineno, line in lines:
        binding = CC_BINDING.match(line)
        if binding and re.search(r'\$\{?CC\b|(?<![\w-])cc(?![\w-])', binding.group("rhs")):
            bindings[binding.group("name")] = lineno
            # PR #450 review (P1): this used to `continue`, so a line that
            # BOTH binds and invokes was only ever counted as a binding.
            # justfile:22547, :22614 and :22654 are
            #   CC_BIN="${CC:-cc}"; CFLAGS_VAL="..."; "$CC_BIN" ... 
            # and were therefore absent from the population entirely, which
            # made "zero unresolved" a claim about an incomplete
            # enumeration rather than a complete one. Record the binding
            # and fall through so the invocation on the same line is seen.
            if not CC_HEAD.match(line):
                continue
        head = CC_HEAD.match(line)
        if not head:
            continue
        # Parse from the compiler head, not the line start: a line like
        # `CC_BIN=...; CFLAGS_VAL=...; "$CC_BIN" ...` would otherwise offer
        # its leading assignments as compiler inputs.
        inputs, is_query = command_inputs(line[head.start("cc"):])
        invocations.append(
            {
                "file": rel,
                "line": lineno,
                "spelling": strip_quotes(head.group("cc")),
                "query": is_query,
                "recipe": recipe_of.get(lineno, ""),
                "inputs": [
                    resolve_input(token, scoped.get(lineno, lines), lineno)
                    for token in inputs
                ],
            }
        )

    referenced = set()
    for name, bound_at in bindings.items():
        pattern = re.compile(r'\$\{?' + re.escape(name) + r'\}?')
        # PR #452 review (P2): the reference search was file-wide. Many
        # just recipes declare their own `CC_BIN="${CC:-cc}"`, so removing
        # one recipe's compile left its discovery line looking live
        # because a DIFFERENT recipe referenced the same name -- the
        # dead-discovery invariant silently did not hold for the justfile.
        # A binding is referenced only within the recipe that made it.
        search = scoped.get(bound_at, lines)
        for lineno, line in search:
            if lineno == bound_at:
                # The justfile binds and uses on ONE line:
                #   CC_BIN="${CC:-cc}"; ...; "$CC_BIN" $CFLAGS_VAL ...
                # Skipping the whole line calls that binding dead. Skip
                # only the assignment and search the rest of the line.
                tail = line.split(";", 1)[1] if ";" in line else ""
                if tail and pattern.search(tail):
                    referenced.add(name)
                    break
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
        where = {"file": inv["file"], "line": inv["line"],
                 "recipe": inv.get("recipe", "")}
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


def inventory_owner(path: str, site: str = "", recipe: str = "") -> str:
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
            # PR #452 review (P1): matching on the file alone made a cell
            # naming `justfile` authorize EVERY backend-emitted-C
            # invocation anywhere in it, including ones with no row --
            # the inverse of a guard that exists to reject unregistered
            # consumers. A row authorizes a SITE: the file and the
            # product it compiles.
            if site and not any(site in cell for cell in cells):
                continue
            # PR #452 review (P1), second pass: product granularity still
            # let a NEW recipe compiling a registered product inherit its
            # owner. A row authorizes one `(file, recipe, product)`, so a
            # new consumer of the same artifact is still unregistered.
            if recipe and not any(recipe in cell for cell in cells):
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
        # The product name is the site identity: `why` reads
        # "<product> is written by a retired-backend emission".
        product = record.get("why", "").split(" is written by", 1)[0].strip()
        owner = inventory_owner(record["file"], product,
                                record.get("recipe", ""))
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
