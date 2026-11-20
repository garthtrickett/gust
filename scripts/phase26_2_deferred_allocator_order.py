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
CASE_DIGEST = 'e853d17f935625b2666126a23d1417e01832045a210a859d9689e7f868b04477'
ORIGINAL54_DIGEST = 'ef229dbe96fd8c7bfb3f63785c9c4b41df9e392bb4e75a8824ef1f766624c066'
MALFORMED_REFERENCE_CASE = 'unsupported_implicit_reference_call'
REFERENCE_ARGUMENT_DIAGNOSTIC = "Argument type mismatch for function 'expose'"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_reference_fixture_amendment(value):
    original = value.get('original54_cases')
    assert isinstance(original, list) and len(original) == 54, 'preserved original54 population drifted'
    assert len({row['name'] for row in original}) == 54, 'preserved original54 population drifted'
    canonical = json.dumps(original, sort_keys=True, separators=(',', ':')).encode()
    assert value['original54_cases_sha256'] == hashlib.sha256(canonical).hexdigest() == ORIGINAL54_DIGEST, 'preserved original54 controls changed'
    attempted = next(row for row in original if row['name'] == MALFORMED_REFERENCE_CASE)
    assert value['unqualified_reference_fixture_attempt'] == dict(
        status='UNQUALIFIED historical attempted implicit-reference control',
        original_case=attempted,
        actual_primary_diagnostic=REFERENCE_ARGUMENT_DIAGNOSTIC,
        limitation='Ordinary calls require an explicit reference argument; the previous cleanup diagnostic was secondary.'
    ), 'failed reference fixture preservation drifted'
    malformed = copy.deepcopy(attempted)
    malformed.update(name='reject_malformed_reference_argument', diagnostic=REFERENCE_ARGUMENT_DIAGNOSTIC)
    reference = copy.deepcopy(attempted)
    assert reference['source'].count('expose(holder);') == 1, 'original reference-call source drifted'
    reference.update(name='unsupported_explicit_reference_parameter_call',
                     source=reference['source'].replace('expose(holder);', 'expose(&holder);'))
    expected = [row for row in original if row['name'] != MALFORMED_REFERENCE_CASE] + [malformed, reference]
    assert value['cases'] == expected, 'reviewed reference fixture population mapping drifted'
    assert len(value['cases']) == len({row['name'] for row in value['cases']}) == 55


def validate(value=None, checker=None):
    value = json.loads(CASES.read_text()) if value is None else value
    canonical = json.dumps(value, sort_keys=True, separators=(',', ':')).encode()
    assert hashlib.sha256(canonical).hexdigest() == CASE_DIGEST, 'deferred allocator case contract drifted'
    validate_reference_fixture_amendment(value)
    assert len(value['cases']) == 55 and sum(c['original_baseline'] for c in value['cases']) == 8
    original32 = json.dumps(value['cases'][:32], sort_keys=True, separators=(',', ':')).encode()
    assert hashlib.sha256(original32).hexdigest() == '6d11471af2986e33c2c5b00ea9269885fa161508ade37ad24ec1a5637f111685', 'original32 controls changed'
    assert len(value['unqualified_fixture_attempts']) == 3
    assert value['support_sha256'] == digest(SUPPORT), 'deferred allocator support drifted'
    assert value['internal_control_sha256'] == digest(INTERNAL), 'deferred allocator observation controls drifted'
    literal = value['literal_source_controls']
    assert len(literal) == len({row['name'] for row in literal}) == 18
    unit = INTERNAL.read_text()
    for index, row in enumerate(literal):
        call = ('if std.str_eq(source, ' + json.dumps(row['source']) + ') == 1 && std.str_eq(expected, ' +
                json.dumps(row['expected_diagnostic']) + ') == 1 { return ' + str(index) + '; }')
        assert call in unit, 'literal observation source control missing: ' + row['name']
    assert 'if len(args) != 1 { return 2; }' in unit and 'if len(args) == 4 {' in unit
    assert 'if literal_observation_source_index(args[2], args[3]) < 0 { return 2; }' in unit
    assert 'if check_literal_observation_source(args[2], args[3], &ctx) == 0 { return 1; }' in unit
    diagnostic = value['diagnostic_precedence_controls']
    expected_diagnostic = [dict(name='exit_' + str(mode) + '_prior_' + str(prior) + '_storage_' + str(storage),
                                index=str(mode * 4 + prior * 2 + storage),
                                mode=mode, prior_error=prior, valid_storage=storage)
                           for mode in range(4) for prior in range(2) for storage in range(2)]
    assert diagnostic == expected_diagnostic, 'deferred diagnostic tuple population drifted'
    for row in diagnostic:
        assert ('if std.str_eq(label, ' + json.dumps(row['index']) + ') == 1 { return ' +
                row['index'] + '; }') in unit, 'deferred diagnostic argument missing'
    for obligation in ('if len(args) == 3 {',
                       'if std.str_eq(args[1], "diagnostic-precedence") == 0 { return 2; }',
                       'if index < 0 { return 2; }',
                       'mut mode := index / 4;',
                       'mut prior_error := index / 2 - mode * 2;',
                       'mut valid_storage := index - (index / 2) * 2;',
                       'if check_deferred_error_precedence(mode, prior_error, valid_storage, &ctx) == 0 { return 1; }'):
        assert obligation in unit, 'deferred diagnostic isolated invocation missing: ' + obligation
    source = CHECKER.read_text() if checker is None else checker
    deferred_exit = source.split('func env_validate_resource_deferred_exit(', 1)[1].split('\nfunc ', 1)[0]
    precedence = 'if len((*env).errors) != 0 { return 1; }'
    assert precedence in deferred_exit, 'deferred diagnostic precedence missing'
    assert deferred_exit.index(precedence) < deferred_exit.index('mut actions := '), 'deferred diagnostic precedence follows simulation'
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
        'mut receiver := env_deferred_allocator_receiver(env, action, ctx);',
        'if receiver.present == 0 || receiver.unresolved == 1 || len(receiver.identity) == 0 {',
        'mut allocator := env_deferred_allocator_proof(env, action, ctx);',
        '(*freed).Insert(std.Clone(ctx, receiver.identity), 1);',
        'primitive_arena_observations: std.HashMap[str, AllocatorIdentityProof[ctx], ctx]',
        'if observed.Ok { return env_arena_lifecycle_storage_observation(declaration, path, observed.Val, ctx); }',
        'return env_arena_lifecycle_storage_observation(declaration, path, env_allocator_expression_proof(expr_idx, env, ctx), ctx);',
        'observed.unresolved = 1;',
        'env_arena_lifecycle_expose_aggregate(env, expr.AddressOf.expr, inner, ctx);',
        'env_arena_lifecycle_expose_aggregate(env, arg_idx_check_call_nlaunder, resolved_arg, ctx);',
        'env_arena_lifecycle_observe_indirect_write(env, left_idx, ctx);',
        'result.exposed_storage = typechecker_union_int_maps(result.exposed_storage, right[r].exposed_storage, ctx);',
        'if right[r].indirect_write == 1 { result.indirect_write = 1; }',
        'changed.primitive_arena_indirect_write = 1;',
        'env_arena_lifecycle_storage_observation(declaration, keys[i], identity, ctx)',
        'left_value.unresolved != right_value.unresolved || left_value.present != right_value.present',
        'Semantic Error: [ResourceDeferredUnresolved] Deferred allocator Free has no proved late receiver identity',
        'Semantic Error: [ResourceDeferredUnresolved] Deferred resource consumption requires existing captured owner storage; late producer effects are not represented',
        'env_validate_resource_deferred_exit(env, 1, 0, escaping_allocator_dependencies, stmt.Return.span, ctx);',
        'env_validate_resource_deferred_exit(env, 2, (*env).resource_loop_scope_depth, allocator_dependencies_empty(ctx), stmt.Expression.span, ctx);',
        '(*env).resource_deferred_actions = parent_deferred_actions;',
        '(*env).resource_deferred_actions = parent_resource_deferred_actions;',
        '(*env).arena_lifecycle_states = alternative_lifecycle_if;',
        '(*env).resource_loop_exit_frees.Insert(std.Clone(ctx, destroyed[f]), 1);',
        'typechecker_if_allocator_observations(cond_idx, consequence_observations_if, alternative_observations_if, ctx)',
        'mut joined := typechecker_join_allocator_observations(consequence, alternative, ctx);',
        'if condition.tag != 3 { return joined; }',
        'merged.observations.Insert(std.Clone(ctx, keys[k]), proof);',
        'if mode == 3 && env_validate_resource_loop_backedge(env, freed, span, ctx) == 0 { valid = 0; }',
        'env_validate_resource_loop_backedge(env, env_resource_freed_allocator_set(env, ctx), ctx[body_idx].span, ctx);',
    ):
        assert obligation in source, 'deferred allocator proof missing: ' + obligation
    returned = source.split('mut escaping_allocator_dependencies := allocator_dependencies_empty(ctx);', 1)[1]
    assert returned.index('env_resource_expression_allocator_dependencies(env, expr_idx, ctx)') < returned.index('env_transfer_resource_return_expression(env, expr_idx, ctx)'), 'escaping dependencies captured after transfer'
    return value['cases']


def inversions():
    value = json.loads(CASES.read_text())
    source = CHECKER.read_text()
    validate(value, source)
    reference_fixture_inversions(value)
    changes = []
    changed = copy.deepcopy(value)
    changed['cases'][1]['mode'] = 'native'
    changes.append(('unsafe baseline admitted', changed, source, 'deferred allocator case contract drifted'))
    changed = copy.deepcopy(value)
    changed['cases'].pop()
    changes.append(('missing late unknown control', changed, source, 'deferred allocator case contract drifted'))
    changed = copy.deepcopy(value)
    changed['unqualified_fixture_attempts'][0]['original_case']['source'] += '\n'
    changes.append(('original failed fixture overwritten', changed, source, 'deferred allocator case contract drifted'))
    marker = 'func env_validate_resource_deferred_exit('
    before_exit, after_exit = source.split(marker, 1)
    changed_exit = after_exit.replace('if len((*env).errors) != 0 { return 1; }', '/* omitted by control */', 1)
    changes.append(('earlier diagnostic precedence omitted', value, before_exit + marker + changed_exit, 'deferred diagnostic precedence missing'))
    changed_exit = after_exit.replace('if len((*env).errors) != 0 { return 1; }', '', 1)
    changed_exit = changed_exit.replace('mut actions := (*env).resource_deferred_actions;',
        'mut actions := (*env).resource_deferred_actions;\n        if len((*env).errors) != 0 { return 1; }', 1)
    changes.append(('earlier diagnostic precedence moved after simulation entry', value,
                    before_exit + marker + changed_exit, 'deferred diagnostic precedence follows simulation'))
    for label, obligation in (
        ('missing return simulation', 'env_validate_resource_deferred_exit(env, 1, 0, escaping_allocator_dependencies, stmt.Return.span, ctx);'),
        ('missing loop unwind', 'env_validate_resource_deferred_exit(env, 2, (*env).resource_loop_scope_depth, allocator_dependencies_empty(ctx), stmt.Expression.span, ctx);'),
        ('registration values substituted', 'mut actual := (*env).resource_value_identities.Get(action.storage_key);'),
        ('automatic cleanup wrongly precedes return defers', 'if mode != 1 {'),
        ('missing sibling restore', '(*env).arena_lifecycle_states = alternative_lifecycle_if;'),
        ('lost loop destruction', '(*env).resource_loop_exit_frees.Insert(std.Clone(ctx, destroyed[f]), 1);'),
        ('last branch field treated as exact', 'typechecker_if_allocator_observations(cond_idx, consequence_observations_if, alternative_observations_if, ctx)'),
        ('literal taint union omitted', 'mut joined := typechecker_join_allocator_observations(consequence, alternative, ctx);'),
        ('nonliteral condition treated as known', 'if condition.tag != 3 { return joined; }'),
        ('literal selected value discarded', 'merged.observations.Insert(std.Clone(ctx, keys[k]), proof);'),
        ('unchecked normal backedge', 'env_validate_resource_loop_backedge(env, env_resource_freed_allocator_set(env, ctx), ctx[body_idx].span, ctx);'),
        ('unknown receiver treated as known', 'if receiver.present == 0 || receiver.unresolved == 1 || len(receiver.identity) == 0 {'),
        ('physical observation substituted for resource proof', 'mut allocator := env_deferred_allocator_proof(env, action, ctx);'),
        ('missing explicit aggregate exposure', 'env_arena_lifecycle_expose_aggregate(env, expr.AddressOf.expr, inner, ctx);'),
        ('missing reference parameter exposure', 'env_arena_lifecycle_expose_aggregate(env, arg_idx_check_call_nlaunder, resolved_arg, ctx);'),
        ('missing indirect write invalidation', 'env_arena_lifecycle_observe_indirect_write(env, left_idx, ctx);'),
        ('branch exposure forgotten', 'result.exposed_storage = typechecker_union_int_maps(result.exposed_storage, right[r].exposed_storage, ctx);'),
        ('unknown identity refined at join', 'left_value.unresolved != right_value.unresolved || left_value.present != right_value.present'),
        ('exposed fallback regains precision', 'return env_arena_lifecycle_storage_observation(declaration, path, env_allocator_expression_proof(expr_idx, env, ctx), ctx);'),
        ('indirect reference mutation forgotten', 'changed.primitive_arena_indirect_write = 1;'),
        ('indirect mutation lost on join', 'if right[r].indirect_write == 1 { result.indirect_write = 1; }'),
        ('copy launders indirect mutation', 'env_arena_lifecycle_storage_observation(declaration, keys[i], identity, ctx)'),
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


def reference_fixture_inversions(value):
    # Exercise the real preservation/mapping predicate independently of the
    # overall document digest, so its failure cannot be a hash short circuit.
    validate_reference_fixture_amendment(value)
    changes = []
    def changed(label, mutate, expected):
        candidate = copy.deepcopy(value)
        mutate(candidate)
        changes.append((label, candidate, expected))
    changed('old active54 expectation re-admitted',
            lambda v: v.update(cases=copy.deepcopy(v['original54_cases'])),
            'reviewed reference fixture population mapping drifted')
    changed('old document without preserved54 snapshot', lambda v: v.pop('original54_cases'),
            'preserved original54 population drifted')
    changed('preserved original source changed',
            lambda v: v['original54_cases'][0].update(source='changed'),
            'preserved original54 controls changed')
    changed('preserved original expectation changed',
            lambda v: v['original54_cases'][0].update(diagnostic='changed'),
            'preserved original54 controls changed')
    changed('preserved original missing', lambda v: v['original54_cases'].pop(),
            'preserved original54 population drifted')
    changed('preserved original duplicate',
            lambda v: v['original54_cases'].__setitem__(1, copy.deepcopy(v['original54_cases'][0])),
            'preserved original54 population drifted')
    changed('preserved original digest changed', lambda v: v.update(original54_cases_sha256='0' * 64),
            'preserved original54 controls changed')
    changed('historical failure relabelled qualified',
            lambda v: v['unqualified_reference_fixture_attempt'].update(status='PASS'),
            'failed reference fixture preservation drifted')
    changed('historical failed object changed',
            lambda v: v['unqualified_reference_fixture_attempt']['original_case'].update(source='changed'),
            'failed reference fixture preservation drifted')
    changed('malformed primary diagnostic weakened',
            lambda v: v['cases'][-2].update(diagnostic='[ResourceDeferredUnresolved]'),
            'reviewed reference fixture population mapping drifted')
    changed('valid reference changed back to malformed value',
            lambda v: v['cases'][-1].update(source=v['cases'][-2]['source']),
            'reviewed reference fixture population mapping drifted')
    changed('valid reference refusal weakened', lambda v: v['cases'][-1].update(mode='native'),
            'reviewed reference fixture population mapping drifted')
    changed('valid reference control removed', lambda v: v['cases'].pop(),
            'reviewed reference fixture population mapping drifted')
    changed('malformed primary control removed', lambda v: v['cases'].pop(-2),
            'reviewed reference fixture population mapping drifted')
    changed('unchanged active original altered', lambda v: v['cases'][0].update(source='changed'),
            'reviewed reference fixture population mapping drifted')
    changed('historical attempted control silently active',
            lambda v: v['cases'].append(copy.deepcopy(v['unqualified_reference_fixture_attempt']['original_case'])),
            'reviewed reference fixture population mapping drifted')
    for label, candidate, expected in changes:
        try:
            validate_reference_fixture_amendment(candidate)
        except AssertionError as error:
            assert str(error) == expected, 'REJECTED (different assertion): ' + label + ': ' + str(error)
            print('REJECTED (expected assertion): ' + label)
        else:
            raise AssertionError('ACCEPTED mutation: ' + label)


def qualify_literal_sources(binary, output):
    """One current-checker process per source; represented programs never run."""
    controls = json.loads(CASES.read_text())['literal_source_controls']
    directory = output / 'literal_source_controls'
    directory.mkdir()
    rows, argument_rows = [], []
    unit_hash = digest(binary)
    for case in controls:
        folder = directory / case['name']
        folder.mkdir()
        (folder / 'source.gst').write_text(case['source'])
        (folder / 'expected.txt').write_text(case['expected_diagnostic'])
        command = [str(binary), 'literal-source', case['source'], case['expected_diagnostic']]
        run = subprocess.run(command, cwd=folder, capture_output=True, timeout=15)
        (folder / 'run.stdout').write_bytes(run.stdout)
        (folder / 'run.stderr').write_bytes(run.stderr)
        (folder / 'run.status').write_text(str(run.returncode) + '\n')
        passed = run.returncode == 0 and run.stdout == b'1\n' and not run.stderr
        rows.append(dict(name=case['name'], command=command, run_exit=run.returncode,
                         passed=passed, unit_sha256=unit_hash, user_program_executed=False,
                         files={p.name: digest(p) for p in folder.iterdir() if p.is_file()}))
        (output / 'literal-controls.json').write_text(json.dumps(dict(cases=rows), indent=2) + '\n')
        if not passed:
            break
    cases_passed = len(rows) == len(controls) == 18 and all(row['passed'] for row in rows)
    if cases_passed:
        first = controls[0]
        for label, arguments in (
            ('wrong_count', ['literal-source']),
            ('unknown_mode', ['unknown-mode', first['source'], first['expected_diagnostic']]),
            ('unknown_source', ['literal-source', 'func main() {}', '']),
            ('wrong_expectation', ['literal-source', first['source'], '[UnregisteredDiagnostic]']),
        ):
            folder = directory / label
            folder.mkdir()
            command = [str(binary), *arguments]
            run = subprocess.run(command, cwd=folder, capture_output=True, timeout=15)
            (folder / 'run.stdout').write_bytes(run.stdout)
            (folder / 'run.stderr').write_bytes(run.stderr)
            (folder / 'run.status').write_text(str(run.returncode) + '\n')
            passed = run.returncode == 2 and not run.stdout and not run.stderr
            argument_rows.append(dict(name=label, command=command, run_exit=run.returncode,
                                      passed=passed, unit_sha256=unit_hash, user_program_executed=False,
                                      files={p.name: digest(p) for p in folder.iterdir() if p.is_file()}))
            if not passed:
                break
    passed = cases_passed and len(argument_rows) == 4 and all(row['passed'] for row in argument_rows)
    report = dict(status='PASS' if passed else 'FAIL', cases=rows, argument_refusals=argument_rows,
                  unit_sha256=unit_hash, represented_user_programs_executed=0,
                  source_checker_executions=len(rows),
                  accepted_source_executions=sum(row['passed'] for row in rows),
                  argument_check_executions=len(argument_rows),
                  expected_argument_refusals=sum(row['passed'] for row in argument_rows))
    (output / 'literal-controls.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


def qualify_diagnostic_precedence(binary, output):
    """Keep every exact tuple in its own current-checker process."""
    controls = json.loads(CASES.read_text())['diagnostic_precedence_controls']
    directory = output / 'diagnostic_precedence_controls'
    directory.mkdir()
    unit_hash = digest(binary)
    rows, bad_rows = [], []

    def execute(name, arguments, expected_exit, expected_stdout):
        folder = directory / name
        folder.mkdir()
        command = [str(binary), *arguments]
        run = subprocess.run(command, cwd=folder, capture_output=True, timeout=15)
        (folder / 'run.stdout').write_bytes(run.stdout)
        (folder / 'run.stderr').write_bytes(run.stderr)
        (folder / 'run.status').write_text(str(run.returncode) + '\n')
        return dict(name=name, command=command, run_exit=run.returncode,
                    passed=run.returncode == expected_exit and run.stdout == expected_stdout and not run.stderr,
                    unit_sha256=unit_hash, user_program_executed=False,
                    files={p.name: digest(p) for p in folder.iterdir() if p.is_file()})

    for case in controls:
        row = execute(case['name'], ['diagnostic-precedence', case['index']], 0, b'1\n')
        rows.append(row)
        (output / 'diagnostic-controls.json').write_text(json.dumps(dict(cases=rows), indent=2) + '\n')
        if not row['passed']:
            break
    cases_passed = len(rows) == len(controls) == 16 and all(row['passed'] for row in rows)
    if cases_passed:
        for name, arguments in (
            ('missing_case', ['diagnostic-precedence']),
            ('extra_argument', ['diagnostic-precedence', '0', 'extra']),
            ('unknown_case', ['diagnostic-precedence', '16']),
            ('unknown_mode', ['invalid-mode', '0']),
        ):
            row = execute(name, arguments, 2, b'')
            bad_rows.append(row)
            if not row['passed']:
                break
    passed = cases_passed and len(bad_rows) == 4 and all(row['passed'] for row in bad_rows)
    report = dict(status='PASS' if passed else 'FAIL', cases=rows, argument_refusals=bad_rows,
                  unit_sha256=unit_hash, represented_user_programs_executed=0,
                  checker_executions=len(rows), accepted_checker_executions=sum(row['passed'] for row in rows),
                  argument_check_executions=len(bad_rows), expected_argument_refusals=sum(row['passed'] for row in bad_rows))
    (output / 'diagnostic-controls.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


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
    internal_record.update(passed=internal_pass,
                           files={p.name: digest(p) for p in internal.iterdir() if p.is_file()})
    (output / 'internal.json').write_text(json.dumps(internal_record, indent=2) + '\n')
    literal = qualify_literal_sources(binary, output) if internal_pass else None
    diagnostic = qualify_diagnostic_precedence(binary, output) if internal_pass else None
    after = {path: digest(ROOT / path) for path in inputs}
    allocated = sum(p.stat().st_blocks * 512 for p in output.rglob('*') if p.is_file())
    passed = (inputs == after and tools == {name: digest(ROOT / name) for name in tools} and
              allocated <= budget and internal_pass and literal is not None and
              literal['status'] == 'PASS' and diagnostic is not None and
              diagnostic['status'] == 'PASS' and all(r['passed'] for r in rows))
    result = dict(status='PASS' if passed else 'FAIL', scope='Captured bound-owner cleanup order only; unsupported late producers/unknown Free explicitly refused; no OD23 slot decision or full Phase26 closure',
                  source_before=inputs, source_after=after, tools=tools, cases=rows,
                  active_case_count=55, original54_cases_sha256=ORIGINAL54_DIGEST,
                  unqualified_reference_attempt=MALFORMED_REFERENCE_CASE,
                  internal=internal_record, literal_controls=literal, diagnostic_controls=diagnostic,
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
