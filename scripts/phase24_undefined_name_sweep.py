"""Patch 24.12b: no script may read a name nothing binds.

Three separate guards in this patch died on NameError because a conversion
retired a producer and left its consumer behind:

  phase24_cr15_qualification.py                  c_outputs
  phase21_compiler_support_native_qualification  oracle
  phase21_selected_compiler_module_qualification oracle

All three are in `evidence`/`run_evidence` paths that `validate` never calls,
so every local run passed and only the packaged-compiler CI jobs reached them.
Two were found by CI one at a time; the third was found here.

The check is deliberately narrow -- it looks for that shape, not for general
lint -- and it must OVER-report rather than under-report. Its first version
under-reported and returned a clean sweep over a tree containing two live
instances: it collected module scope by walking the whole tree, so a name bound
inside some other function looked module-global and every function appeared to
have it in scope. Closure scopes are modelled for the same reason in reverse: a
nested helper reading its parent's local is not a defect, and a report drowned
in those stops being read.
"""

import ast, builtins, sys
from pathlib import Path

BUILTINS = set(dir(builtins)) | {"__file__", "__name__", "__doc__", "__package__", "__spec__"}


def bound_names(node):
    """Every name this node binds, at any depth below it."""
    out = set()
    for child in ast.walk(node):
        if isinstance(child, ast.Name) and isinstance(child.ctx, (ast.Store, ast.Del)):
            out.add(child.id)
        elif isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            out.add(child.name)
        elif isinstance(child, (ast.Import, ast.ImportFrom)):
            for alias in child.names:
                out.add((alias.asname or alias.name).split(".")[0])
        elif isinstance(child, ast.arg):
            out.add(child.arg)
        elif isinstance(child, ast.ExceptHandler) and child.name:
            out.add(child.name)
        elif isinstance(child, ast.Global):
            out.update(child.names)
    return out


def module_scope_names(tree):
    """Only names bound at MODULE scope.

    bound_names(tree) walks the whole tree, so `oracle = ...` inside some other
    function counted as module-level and every function appeared to have it in
    scope. That is how this checker reported 0 for a file whose evidence path
    dies on `NameError: name 'oracle' is not defined`.
    """
    out = set()
    for node in tree.body:
        out |= bound_names(node) if not isinstance(
            node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)
        ) else {node.name}
    return out


def check(path):
    tree = ast.parse(Path(path).read_text())
    module_level = module_scope_names(tree)
    problems = []
    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        # Names bound by any ENCLOSING function are in scope too: a nested
        # helper reading its parent's local is a closure, not a defect. Without
        # this the report is dominated by false positives and the real hits
        # stop being visible.
        enclosing = set()
        for outer in ast.walk(tree):
            if isinstance(outer, (ast.FunctionDef, ast.AsyncFunctionDef)):
                if outer is node:
                    continue
                if any(inner is node for inner in ast.walk(outer)):
                    enclosing |= bound_names(outer)
        local = bound_names(node)
        for child in ast.walk(node):
            if isinstance(child, ast.Name) and isinstance(child.ctx, ast.Load):
                name = child.id
                if (name in local or name in enclosing
                        or name in module_level or name in BUILTINS):
                    continue
                problems.append((child.lineno, node.name, name))
    return problems


GUARD = "guard-cranelift-phase24-undefined-name-sweep-contract"

# Default corpus is every script, not whatever the caller passes. A sweep whose
# population is an argument is a sweep whose completeness is the caller's
# claim -- the same shape as the enumerations this phase keeps finding wrong.
targets = sys.argv[1:] or sorted(
    str(q) for q in Path(__file__).resolve().parent.glob("*.py"))

bad = 0
for path in targets:
    for lineno, func, name in check(path):
        print(f"{path}:{lineno}: {func}() reads undefined name {name!r}")
        bad += 1
if bad:
    raise SystemExit(
        f"{GUARD}: {bad} script(s) read a name nothing binds. A conversion "
        "that retires a producer must retire its consumers with it; these "
        "fail at runtime in evidence paths that `validate` never calls.")
print(f"{GUARD}: ok ({len(targets)} scripts, 0 undefined-name reads)")
