#!/usr/bin/env python3
"""Qualify lexical allocator proof identities and actual-origin owner dependencies."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_specification(specification):
    cases = specification['cases']
    # This successor isolates proof metadata using an already admitted Arena argument.
    # Preserve the failed implicit-call expectations; they are not passing cases.
    canonical = lambda value: hashlib.sha256(json.dumps(
        value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    assert specification['qualification_cohort'] == 'explicit-arena-anchors-v2'
    assert canonical(cases[:43]) == 'c56b5477786b161a694caf97dc032b70b4f407ef58bfe4c4ed30909a9a421c97', 'original43 payload drift'
    pending = specification['unqualified_source_prerequisites']
    assert pending['key'] == 'P26-QUALIFIED-CALL-BRAND-NORMALIZATION'
    assert pending['status'].startswith('UNQUALIFIED;'), 'pending implicit qualification drift'
    assert canonical(pending['original_cases']) == '41b5232e78ee1730ae9492bb0bbc83ec9ad189fd14f6e0c44bec4f4410e7c521', 'original implicit payload drift'
    assert [case['name'] for case in cases[-2:]] == [
        'qualified_brand_explicit_arena_native',
        'qualified_brand_explicit_arena_shadow_assignment']
    assert specification['schema'] == 'gust.allocator_identity.cases.v1'
    assert len(cases) == len({case['name'] for case in cases}) == 45
    assert {mode: sum(case['mode'] == mode for case in cases)
            for mode in ('reject', 'native', 'frontend_accept')} == {
                'reject': 22, 'native': 11, 'frontend_accept': 12}
    return cases, pending


def primitive_observation_output_matches(case, exit_code, stdout, stderr):
    """Require one primary diagnostic and each declared exact auxiliary once."""
    if exit_code != 0 or stderr:
        return False
    auxiliary = case.get('expected_auxiliary_errors', [])
    expected = case['expected_candidate']
    if expected == 'ACCEPTED':
        return not auxiliary and stdout == b'ACCEPTED\n'
    lines = stdout.splitlines()
    if len(lines) != 1 + len(auxiliary):
        return False
    for message in auxiliary:
        encoded = message.encode()
        if lines.count(encoded) != 1:
            return False
        lines.remove(encoded)
    return len(lines) == 1 and ('[' + expected + ']').encode() in lines[0]


def qualify_primitive_observations(compiler, output, source, specification):
    """Execute the compiler unit; source snippets themselves never execute."""
    cases = json.loads(specification.read_text())
    assert cases['schema'] == 'gust.primitive_arena_observations.cases.v1'
    rows = cases['cases']
    assert len(rows) == len({row['name'] for row in rows}) == 18
    directory = output / 'primitive-lifecycle-controls'
    directory.mkdir()
    binary = directory / 'checker-unit'
    command = [str(compiler), '--backend', 'cranelift', '-o', str(binary), str(source)]
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, timeout=120)
    (directory / 'compile.stdout').write_bytes(result.stdout)
    (directory / 'compile.stderr').write_bytes(result.stderr)
    report = dict(source_sha256=digest(source), specification_sha256=digest(specification),
                  command=command, compile_exit=result.returncode,
                  stdout_sha256=digest(directory / 'compile.stdout'),
                  stderr_sha256=digest(directory / 'compile.stderr'),
                  compiler_unit_executed=False, user_programs_executed=False,
                  cases=[], pass_result=False)
    if result.returncode != 0 or not binary.is_file():
        return report
    report['elf_sha256'] = digest(binary)
    report['compiler_unit_executed'] = True
    for case in rows:
        case_dir = directory / case['name']
        case_dir.mkdir()
        snippet = case_dir / 'source.gst'
        snippet.write_text(case['source'])
        process = subprocess.run([str(binary), case['source']], cwd=case_dir,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15)
        (case_dir / 'stdout').write_bytes(process.stdout)
        (case_dir / 'stderr').write_bytes(process.stderr)
        expected = case['expected_candidate']
        passed = primitive_observation_output_matches(
            case, process.returncode, process.stdout, process.stderr)
        record = dict(case=case['name'], expected=expected,
                      expected_auxiliary_errors=case.get('expected_auxiliary_errors', []),
                      unit_exit=process.returncode,
                      source_sha256=digest(snippet), stdout_sha256=digest(case_dir / 'stdout'),
                      stderr_sha256=digest(case_dir / 'stderr'), pass_result=passed,
                      verdict=('ACCEPTED' if process.returncode == 0 and process.stdout == b'ACCEPTED\n'
                               else 'REJECTED (expected assertion)' if passed
                               else 'REJECTED (different assertion)'), user_program_executed=False)
        report['cases'].append(record)
        print(json.dumps(dict(primitive_lifecycle_control=record)), flush=True)
        (directory / 'partial-results.json').write_text(json.dumps(report, indent=2) + '\n')
    report['pass_result'] = all(row['pass_result'] for row in report['cases'])
    return report


def qualify(compiler, output, cases_path):
    specification = json.loads(cases_path.read_text())
    cases, pending = validate_specification(specification)
    canonical = lambda value: hashlib.sha256(json.dumps(
        value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    budget = 64 * 1024 ** 2
    space = os.statvfs(ROOT)
    if space.f_bavail * space.f_frsize < budget + 2 * 1024 ** 3:
        raise SystemExit('allocator identity matrix disk admission refused')
    output.mkdir(exist_ok=False, parents=True)
    proof_source = ROOT / 'compiler/phase26-2-allocator-identity/proof_facts.gst'
    primitive_source = ROOT / 'compiler/phase26-2-allocator-identity/primitive_fields.gst'
    primitive_cases = ROOT / 'compiler/phase26-2-allocator-identity/primitive_cases.json'
    inputs = [cases_path, Path(__file__), ROOT / 'compiler/typechecker.gst', proof_source,
              primitive_source, primitive_cases,
              ROOT / 'scripts/phase26_bootstrap_bounded.py']
    before = {str(path): digest(path) for path in inputs}
    compiler_hash = digest(compiler)
    records = []
    for case in cases:
        directory = output / case['name']
        directory.mkdir()
        source = directory / 'case.gst'
        support = directory / 'support.gst'
        source.write_text(case['source'])
        support.write_text(case['support'])
        binary = directory / 'program'
        environment = os.environ.copy()
        if case['mode'] != 'native':
            environment['GUST_NATIVE_BACKEND_DRIVER'] = '/bin/false'
        command = [str(compiler), '--backend', 'cranelift', '-o', str(binary),
                   str(source)]
        result = subprocess.run(command, cwd=ROOT, env=environment,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                timeout=120)
        (directory / 'compile.stdout').write_bytes(result.stdout)
        (directory / 'compile.stderr').write_bytes(result.stderr)
        driver_reached = b'handshake process failed' in result.stderr
        row = dict(case=case['name'], mode=case['mode'], command=command,
                   compile_exit=result.returncode, executed=False,
                   source_sha256=digest(source), support_sha256=digest(support),
                   stdout_sha256=digest(directory / 'compile.stdout'),
                   stderr_sha256=digest(directory / 'compile.stderr'),
                   driver_reached=driver_reached)
        if case['mode'] == 'reject':
            expected = ('[' + case['expected_diagnostic'] + ']').encode()
            row['pass'] = (result.returncode == 1 and expected in result.stdout
                           and case.get('expected_message', '').encode() in result.stdout
                           and not result.stderr and not driver_reached
                           and not binary.exists())
            row['verdict'] = ('REJECTED (expected assertion)' if row['pass'] else
                              'ACCEPTED' if result.returncode == 0 else
                              'REJECTED (different assertion)')
        elif case['mode'] == 'frontend_accept':
            row['pass'] = (result.returncode == 1 and driver_reached
                           and not binary.exists())
        else:
            row['pass'] = result.returncode == 0 and binary.is_file()
            if row['pass']:
                execution = subprocess.run([str(binary)], cwd=ROOT,
                                           stdout=subprocess.PIPE,
                                           stderr=subprocess.PIPE, timeout=15)
                (directory / 'run.stdout').write_bytes(execution.stdout)
                (directory / 'run.stderr').write_bytes(execution.stderr)
                row.update(executed=True, run_exit=execution.returncode,
                           elf_sha256=digest(binary),
                           run_stdout_sha256=digest(directory / 'run.stdout'),
                           run_stderr_sha256=digest(directory / 'run.stderr'))
                row['pass'] = (execution.returncode == 0 and not execution.stderr
                               and execution.stdout ==
                               case['expected_native_stdout'].encode())
        records.append(row)
        print(json.dumps(row), flush=True)
        (output / 'partial-results.json').write_text(
            json.dumps(records, indent=2) + '\n')
    proof = output / 'internal-proof-facts'
    proof.mkdir()
    binary = proof / 'program'
    command = [str(compiler), '--backend', 'cranelift', '-o', str(binary),
               str(proof_source)]
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, timeout=120)
    (proof / 'compile.stdout').write_bytes(result.stdout)
    (proof / 'compile.stderr').write_bytes(result.stderr)
    internal = dict(source_sha256=digest(proof_source), command=command,
                    compile_exit=result.returncode, executed=False,
                    stdout_sha256=digest(proof / 'compile.stdout'),
                    stderr_sha256=digest(proof / 'compile.stderr'),
                    pass_result=result.returncode == 0 and binary.is_file())
    if internal['pass_result']:
        execution = subprocess.run([str(binary)], cwd=ROOT, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, timeout=15)
        (proof / 'run.stdout').write_bytes(execution.stdout)
        (proof / 'run.stderr').write_bytes(execution.stderr)
        internal.update(executed=True, run_exit=execution.returncode,
                        elf_sha256=digest(binary),
                        run_stdout_sha256=digest(proof / 'run.stdout'),
                        run_stderr_sha256=digest(proof / 'run.stderr'),
                        pass_result=execution.returncode == 0 and
                        execution.stdout == b'1\n' * 12 and not execution.stderr)
    print(json.dumps(dict(internal_proof_facts=internal)), flush=True)
    primitive = qualify_primitive_observations(compiler, output, primitive_source, primitive_cases)
    after = {str(path): digest(path) for path in inputs}
    allocated = sum(path.stat().st_blocks * 512 for path in output.rglob('*')
                    if path.is_file())
    passed = (before == after and compiler_hash == digest(compiler)
              and allocated <= budget and all(row['pass'] for row in records)
              and internal['pass_result'] and primitive['pass_result'])
    report = dict(utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  status='PASS lexical allocator identity matrix' if passed else 'FAIL',
                  qualification_cohort=specification['qualification_cohort'],
                  unqualified_source_prerequisite=dict(
                      key=pending['key'], status=pending['status'],
                      original_cases_sha256=canonical(pending['original_cases'])),
                  source_before=before, source_after=after,
                  compiler_sha256=compiler_hash, cases=records, internal_proof_facts=internal,
                  primitive_lifecycle_controls=primitive,
                  owned_output_budget_bytes=budget,
                  owned_allocated_end_bytes=allocated,
                  limits='No OD23 slot admission, deferred exit-order, or '
                         'runtime claim for frontend-only controls; no native '
                         'support claim for implicit qualified-call inference or the original main-only scalar '
                         'projection or collection-annotation forms')
    (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    if not passed:
        raise SystemExit('allocator identity matrix failed')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--compiler', type=Path, default=ROOT / 'gust')
    parser.add_argument('--output', type=Path, default=ROOT / 'build/guards/phase26_2_allocator_identity')
    parser.add_argument('--cases', type=Path, default=ROOT / 'compiler/phase26-2-allocator-identity/cases.json')
    args = parser.parse_args()
    qualify(args.compiler.resolve(), args.output.resolve(), args.cases.resolve())
