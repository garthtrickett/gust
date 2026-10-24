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


def qualify(compiler, output, cases_path):
    specification = json.loads(cases_path.read_text())
    cases = specification['cases']
    assert specification['schema'] == 'gust.allocator_identity.cases.v1'
    assert len(cases) == len({case['name'] for case in cases}) == 41
    assert {mode: sum(case['mode'] == mode for case in cases)
            for mode in ('reject', 'native', 'frontend_accept')} == {
                'reject': 20, 'native': 9, 'frontend_accept': 12}
    budget = 64 * 1024 ** 2
    space = os.statvfs(ROOT)
    if space.f_bavail * space.f_frsize < budget + 2 * 1024 ** 3:
        raise SystemExit('allocator identity matrix disk admission refused')
    output.mkdir(exist_ok=False, parents=True)
    proof_source = ROOT / 'compiler/phase26-2-allocator-identity/proof_facts.gst'
    inputs = [cases_path, Path(__file__), ROOT / 'compiler/typechecker.gst', proof_source]
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
                        execution.stdout == b'1\n1\n1\n1\n1\n1\n' and not execution.stderr)
    print(json.dumps(dict(internal_proof_facts=internal)), flush=True)
    after = {str(path): digest(path) for path in inputs}
    allocated = sum(path.stat().st_blocks * 512 for path in output.rglob('*')
                    if path.is_file())
    passed = (before == after and compiler_hash == digest(compiler)
              and allocated <= budget and all(row['pass'] for row in records)
              and internal['pass_result'])
    report = dict(utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  status='PASS lexical allocator identity matrix' if passed else 'FAIL',
                  source_before=before, source_after=after,
                  compiler_sha256=compiler_hash, cases=records, internal_proof_facts=internal,
                  owned_output_budget_bytes=budget,
                  owned_allocated_end_bytes=allocated,
                  limits='No OD23 slot admission, deferred exit-order, or '
                         'runtime claim for frontend-only controls')
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
