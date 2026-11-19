#!/usr/bin/env python3
"""Qualify captured owner storage against existing deferred teardown order."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CASES = ROOT / 'compiler/phase26-2-deferred-allocator-order/cases.json'
CHECKER = ROOT / 'compiler/typechecker.gst'
SUPPORT = ROOT / 'compiler/phase20_protected_access_module.gst'
BUILD = ROOT / 'build/guards/phase26_2_deferred_allocator_order'
INTERNAL = ROOT / 'compiler/phase26-2-deferred-allocator-order/observation_facts.gst'
CASE_DIGEST = '8adb102d5010cc67b4d44969efbc06f99056579b52fe93458c5d40e09acaa2c7'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate(value=None, checker=None):
    value = json.loads(CASES.read_text()) if value is None else value
    canonical = json.dumps(value, sort_keys=True, separators=(',', ':')).encode()
    assert hashlib.sha256(canonical).hexdigest() == CASE_DIGEST, 'deferred allocator case contract drifted'
    assert len(value['cases']) == 29 and sum(c['original_baseline'] for c in value['cases']) == 8
    assert value['support_sha256'] == digest(SUPPORT), 'deferred allocator support drifted'
    assert value['internal_control_sha256'] == digest(INTERNAL), 'deferred allocator observation controls drifted'
    source = CHECKER.read_text() if checker is None else checker
    for obligation in (
        'type ResourceDeferredAction[ctx] struct {',
        'action.binding_scope = env_allocator_binding_scope(env, path, ctx);',
        'action.storage_key = env_resource_lexical_storage_key(action.binding_scope, path, ctx);',
        'mut actual := (*env).resource_value_identities.Get(action.storage_key);',
        'mut owners := typechecker_clone_resource_acquisition_obligation_map((*env).resource_acquisition_obligations, ctx);',
        'actions[start - 1].registration == actions[end - 1].registration',
        'if mode != 1 {',
        'if mode == 0 && valid == 1 {',
        'allocator_dependencies_overlap(owner.allocator_dependencies, allocator, ctx)',
        'allocator_dependencies_overlap(escaping, allocator, ctx)',
        'Semantic Error: [ResourceDeferredUnresolved] Deferred allocator Free has no proved late receiver identity',
        'Semantic Error: [ResourceDeferredUnresolved] Deferred resource consumption requires existing captured owner storage; late producer effects are not represented',
        'env_validate_resource_deferred_exit(env, 1, 0, escaping_allocator_dependencies, stmt.Return.span, ctx);',
        'env_validate_resource_deferred_exit(env, 2, (*env).resource_loop_scope_depth, allocator_dependencies_empty(ctx), stmt.Expression.span, ctx);',
        '(*env).resource_deferred_actions = parent_deferred_actions;',
        '(*env).resource_deferred_actions = parent_resource_deferred_actions;',
        '(*env).arena_lifecycle_states = alternative_lifecycle_if;',
        '(*env).resource_loop_exit_frees.Insert(std.Clone(ctx, destroyed[f]), 1);',
        'typechecker_join_allocator_observations(consequence_observations_if, alternative_observations_if, ctx)',
        'if mode == 3 && entry.Ok && entry.Val.state != arena_lifecycle_state_freed() {',
    ):
        assert obligation in source, 'deferred allocator proof missing: ' + obligation
    returned = source.split('mut escaping_allocator_dependencies := allocator_dependencies_empty(ctx);', 1)[1]
    assert returned.index('env_resource_expression_allocator_dependencies(env, expr_idx, ctx)') < returned.index('env_transfer_resource_return_expression(env, expr_idx, ctx)'), 'escaping dependencies captured after transfer'
    return value['cases']


def inversions():
    value = json.loads(CASES.read_text())
    source = CHECKER.read_text()
    validate(value, source)
    changes = []
    changed = copy.deepcopy(value)
    changed['cases'][1]['mode'] = 'native'
    changes.append(('unsafe baseline admitted', changed, source, 'deferred allocator case contract drifted'))
    changed = copy.deepcopy(value)
    changed['cases'].pop()
    changes.append(('missing late unknown control', changed, source, 'deferred allocator case contract drifted'))
    for label, obligation in (
        ('missing return simulation', 'env_validate_resource_deferred_exit(env, 1, 0, escaping_allocator_dependencies, stmt.Return.span, ctx);'),
        ('missing loop unwind', 'env_validate_resource_deferred_exit(env, 2, (*env).resource_loop_scope_depth, allocator_dependencies_empty(ctx), stmt.Expression.span, ctx);'),
        ('registration values substituted', 'mut actual := (*env).resource_value_identities.Get(action.storage_key);'),
        ('automatic cleanup wrongly precedes return defers', 'if mode != 1 {'),
        ('missing sibling restore', '(*env).arena_lifecycle_states = alternative_lifecycle_if;'),
        ('lost loop destruction', '(*env).resource_loop_exit_frees.Insert(std.Clone(ctx, destroyed[f]), 1);'),
        ('last branch field treated as exact', 'typechecker_join_allocator_observations(consequence_observations_if, alternative_observations_if, ctx)'),
    ):
        assert obligation in source
        changes.append((label, value, source.replace(obligation, '/* omitted by control */', 1), 'deferred allocator proof missing: ' + obligation))
    for name, cases, text, expected in changes:
        try:
            validate(cases, text)
        except AssertionError as error:
            assert str(error) == expected, 'REJECTED (different assertion): ' + name + ': ' + str(error)
            print('REJECTED (expected assertion): ' + name)
        else:
            raise AssertionError('ACCEPTED mutation: ' + name)


def native(output):
    cases = validate()
    budget = 128 * 1024 ** 2
    space = os.statvfs(ROOT)
    assert space.f_bavail * space.f_frsize >= budget + 2 * 1024 ** 3, 'deferred matrix disk admission refused'
    output.mkdir(parents=True, exist_ok=False)
    tools = {name: digest(ROOT / name) for name in ('gust', 'gust-native-backend', 'gust-runtime-package.a')}
    inputs = {str(path.relative_to(ROOT)): digest(path) for path in (CASES, CHECKER, SUPPORT, INTERNAL, Path(__file__))}
    (output / 'source-before.json').write_text(json.dumps(inputs, indent=2) + '\n')
    rows = []
    for case in cases:
        folder = output / case['name']
        folder.mkdir()
        source = folder / 'case.gst'
        source.write_text(case['source'])
        (folder / 'support.gst').write_bytes(SUPPORT.read_bytes())
        binary = folder / 'program'
        environment = dict(os.environ, GUST_NATIVE_BACKEND_DRIVER=str(ROOT / 'gust-native-backend'))
        if case['mode'] == 'reject':
            # Unexpected admission must never reach native compile or execution.
            # Driver failure is explicitly distinct from a frontend diagnostic.
            environment['GUST_NATIVE_BACKEND_DRIVER'] = '/bin/false'
        command = [str(ROOT / 'gust'), '--backend', 'cranelift', '-o', str(binary), str(source)]
        compiled = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=120, env=environment)
        (folder / 'compile.stdout').write_bytes(compiled.stdout)
        (folder / 'compile.stderr').write_bytes(compiled.stderr)
        (folder / 'compile.status').write_text(str(compiled.returncode) + '\n')
        row = dict(name=case['name'], command=command, mode=case['mode'], compile_exit=compiled.returncode, executed=False)
        if case['mode'] == 'reject':
            expected = (compiled.returncode == 1 and not compiled.stderr and
                        case['diagnostic'].encode() in compiled.stdout and
                        b'driver_handshake' not in compiled.stdout and
                        b'gust_native_capability_decision' not in compiled.stdout and not binary.exists())
            row.update(passed=expected, verdict='REJECTED (expected assertion)' if expected else
                       'ACCEPTED' if compiled.returncode == 0 else 'REJECTED (different assertion)')
        else:
            row['passed'] = compiled.returncode == 0 and binary.is_file()
            if row['passed']:
                header = binary.read_bytes()[:20]
                assert header[:7] == b'\x7fELF\x02\x01\x01' and int.from_bytes(header[18:20], 'little') == 62
                run = subprocess.run([str(binary)], cwd=folder, capture_output=True, timeout=15)
                (folder / 'run.stdout').write_bytes(run.stdout)
                (folder / 'run.stderr').write_bytes(run.stderr)
                (folder / 'run.status').write_text(str(run.returncode) + '\n')
                row.update(executed=True, run_exit=run.returncode, elf_sha256=digest(binary), stdout=run.stdout.decode())
                row['passed'] = run.returncode == case['exit'] and run.stdout == case['stdout'].encode() and not run.stderr
        row['files'] = {p.name: digest(p) for p in folder.iterdir() if p.is_file()}
        rows.append(row)
        (output / 'cases.json').write_text(json.dumps(rows, indent=2) + '\n')
        print(json.dumps({k: row[k] for k in ('name', 'mode', 'compile_exit', 'executed', 'passed')}), flush=True)
    internal = output / 'observation_facts'
    internal.mkdir()
    binary = internal / 'program'
    command = [str(ROOT / 'gust'), '--backend', 'cranelift', '-o', str(binary), str(INTERNAL)]
    compiled = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=180,
                              env=dict(os.environ, GUST_NATIVE_BACKEND_DRIVER=str(ROOT / 'gust-native-backend')))
    (internal / 'compile.stdout').write_bytes(compiled.stdout)
    (internal / 'compile.stderr').write_bytes(compiled.stderr)
    (internal / 'compile.status').write_text(str(compiled.returncode) + '\n')
    internal_pass = compiled.returncode == 0 and binary.is_file()
    internal_record = dict(command=command, compile_exit=compiled.returncode, executed=False)
    if internal_pass:
        header = binary.read_bytes()[:20]
        assert header[:7] == b'\x7fELF\x02\x01\x01' and int.from_bytes(header[18:20], 'little') == 62
        run = subprocess.run([str(binary)], cwd=internal, capture_output=True, timeout=15)
        (internal / 'run.stdout').write_bytes(run.stdout)
        (internal / 'run.stderr').write_bytes(run.stderr)
        (internal / 'run.status').write_text(str(run.returncode) + '\n')
        internal_record.update(executed=True, run_exit=run.returncode, elf_sha256=digest(binary))
        internal_pass = run.returncode == 0 and run.stdout == b'1\n1\n1\n1\n' and not run.stderr
    internal_record.update(passed=internal_pass, files={p.name: digest(p) for p in internal.iterdir() if p.is_file()})
    (output / 'internal.json').write_text(json.dumps(internal_record, indent=2) + '\n')
    after = {path: digest(ROOT / path) for path in inputs}
    allocated = sum(p.stat().st_blocks * 512 for p in output.rglob('*') if p.is_file())
    passed = inputs == after and tools == {name: digest(ROOT / name) for name in tools} and allocated <= budget and internal_pass and all(r['passed'] for r in rows)
    result = dict(status='PASS' if passed else 'FAIL', scope='Captured bound-owner cleanup order only; unsupported late producers/unknown Free explicitly refused; no OD23 slot decision or full Phase26 closure',
                  source_before=inputs, source_after=after, tools=tools, cases=rows, internal=internal_record,
                  owned_allocated_bytes=allocated, owned_output_budget_bytes=budget)
    (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    assert passed, 'deferred allocator order matrix failed; read first differing case'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=('validate', 'inversions', 'native'), nargs='?', default='native')
    parser.add_argument('--output', type=Path, default=BUILD)
    args = parser.parse_args()
    if args.mode == 'native':
        native(args.output.resolve())
    else:
        {'validate': validate, 'inversions': inversions}[args.mode]()
