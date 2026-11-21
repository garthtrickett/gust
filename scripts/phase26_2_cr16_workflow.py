"""Exact owner-supplied CI dependency amendment for the CR16 refusal helpers."""
import copy
import gzip
import hashlib
import json
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
BASE = '39e37696b775b25827d54c1c5a52b005d30e386b'
WORKFLOW = '.github/workflows/stdlib-s1-mutex-guard-scope.yml'
HELPERS = ('scripts/stdlib_s1_mutex_guard_scope_refusal.py',
           'scripts/stdlib_s1_mutex_guard_scope_refusal_test.py')
PREDECESSOR = 'compiler/phase26-2-deferred-allocator-order/cr16-workflow-predecessor-v1.json.gz'
PREDECESSOR_SHA256 = 'd176fc21ad94471fac5229991898a5fb368194464c7a71d07432f6a93196c9d4'
PREDECESSOR_FILES = {
    WORKFLOW: '16e4b2d2a7fb6f2f5cf2ef3b48378488b98829d97978f0523487df3f23440fe7',
}


class ContractError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise ContractError(message)


def checked_predecessor(value):
    from phase26_predecessor_data import decoded_payload
    require(set(value) == {'schema', 'base', 'files'} and
            value['schema'] == 'gust.cr16_scope_workflow.predecessor.v1' and
            value['base'] == BASE and set(value['files']) == set(PREDECESSOR_FILES),
            'CR16 workflow predecessor identity or population drifted')
    require(hashlib.sha256(decoded_payload(value['files'][WORKFLOW])).hexdigest() ==
            PREDECESSOR_FILES[WORKFLOW], 'CR16 workflow predecessor payload drifted')
    return value


def predecessor_bytes(name):
    from phase26_predecessor_data import decoded_payload
    path = ROOT / PREDECESSOR
    require(path.is_file() and not path.is_symlink(),
            'CR16 workflow predecessor is missing or nonregular')
    raw = path.read_bytes()
    require(hashlib.sha256(raw).hexdigest() == PREDECESSOR_SHA256,
            'CR16 workflow predecessor archive drifted')
    require(name == WORKFLOW, 'CR16 workflow predecessor file is unregistered')
    value = checked_predecessor(json.loads(gzip.decompress(raw)))
    return decoded_payload(value['files'][name])


def expected_workflow():
    before = predecessor_bytes(WORKFLOW).decode()
    anchor = "      - 'scripts/stdlib_s1_raw_double_unlock_test.py'\n"
    require(before.count(anchor) == 2, 'CR16 workflow predecessor dependency anchors drifted')
    added = ''.join("      - '" + name + "'\n" for name in HELPERS)
    return before.replace(anchor, anchor + added)


def event_filters(text, event):
    import phase26_release_ci as ci
    if event == 'pull_request':
        return ci.workflow_trigger(text)
    require(event == 'push' and text.count('  push:\n') == 1 and
            text.count('  workflow_dispatch:\n') == 1,
            'CR16 workflow event shape drifted')
    block = text.split('  push:\n', 1)[1].split('  workflow_dispatch:\n', 1)[0]
    branch = '    branches: [main]\n'
    require(block.startswith(branch), 'CR16 workflow main push boundary drifted')
    # Exercise the maintained path matcher over the actual push path block.
    # This is an input projection for the closed parser, not a workflow edit.
    return ci.workflow_trigger('name: CR16 push dependency\non:\n  pull_request:\n' +
                               block[len(branch):] + 'jobs:\n')


def check_workflow(text):
    import phase26_release_ci as ci
    require(text == expected_workflow(), 'CR16 helper workflow bytes drifted')
    for event in ('pull_request', 'push'):
        filters = event_filters(text, event)
        require(isinstance(filters, list) and
                all(filters.count(name) == 1 for name in HELPERS),
                'CR16 helper path coverage drifted: ' + event)
        require(all(any(ci.path_matches(pattern, name) for pattern in filters)
                    for name in HELPERS),
                'CR16 helper-only workflow dispatch drifted: ' + event)


def validate():
    path = ROOT / WORKFLOW
    require(path.is_file() and not path.is_symlink(),
            'CR16 helper workflow is missing or nonregular')
    check_workflow(path.read_text())


def inversions():
    import phase26_release_ci as ci
    text = (ROOT / WORKFLOW).read_text()
    validate()
    rows = []

    def reject(label, expected, action):
        try:
            action()
        except ValueError as error:
            message = str(error)
            matched = message == expected or message.startswith(expected + ':')
            rows.append(dict(label='workflow ' + label,
                verdict='REJECTED (expected assertion)' if matched else
                        'REJECTED (different assertion)', assertion=message))
            require(matched, 'CR16 workflow inversion used a different assertion: ' + label)
        else:
            raise ContractError('CR16 workflow inversion ACCEPTED: ' + label)

    for name in HELPERS:
        line = "      - '" + name + "'\n"
        first = text.index(line)
        second = text.index(line, first + len(line))
        for event, start in (('pull_request', first), ('push', second)):
            changed = text[:start] + text[start + len(line):]
            reject(event + ' helper omitted ' + name, 'CR16 helper workflow bytes drifted',
                   lambda changed=changed: check_workflow(changed))
    for label, before, after in (
            ('permission', 'contents: read', 'contents: write'),
            ('owning guard', 'run: just guard-stdlib-s1-mutex-guard-scope', 'run: true'),
            ('main boundary', 'branches: [main]', 'branches: [unselected]'),
            ('unselected extra filter', "      - 'justfile'", "      - 'unselected/**'")):
        require(before in text, 'CR16 workflow mutation did not move: ' + label)
        reject(label, 'CR16 helper workflow bytes drifted',
               lambda before=before, after=after: check_workflow(text.replace(before, after, 1)))
    original_trigger = ci.workflow_trigger
    with patch.object(ci, 'workflow_trigger', lambda value:
                      [name for name in original_trigger(value) if name not in HELPERS]):
        reject('actual parser loses helper coverage', 'CR16 helper path coverage drifted',
               lambda: check_workflow(text))
    with patch.object(ci, 'path_matches', return_value=False):
        reject('actual helper-only dispatch loses match', 'CR16 helper-only workflow dispatch drifted',
               lambda: check_workflow(text))
    previous = checked_predecessor(json.loads(gzip.decompress((ROOT / PREDECESSOR).read_bytes())))
    for field, replacement in (('schema', 'unregistered'), ('base', '0' * 40)):
        changed = copy.deepcopy(previous)
        changed[field] = replacement
        reject('predecessor ' + field, 'CR16 workflow predecessor identity or population drifted',
               lambda changed=changed: checked_predecessor(changed))
    for label, mutate in (
            ('missing', lambda value: value['files'].pop(WORKFLOW)),
            ('extra', lambda value: value['files'].__setitem__('unselected', 'Y2hhbmdlZA=='))):
        changed = copy.deepcopy(previous)
        mutate(changed)
        reject('predecessor ' + label, 'CR16 workflow predecessor identity or population drifted',
               lambda changed=changed: checked_predecessor(changed))
    changed = copy.deepcopy(previous)
    changed['files'][WORKFLOW] = 'Y2hhbmdlZA=='
    reject('predecessor payload', 'CR16 workflow predecessor payload drifted',
           lambda: checked_predecessor(changed))
    read = Path.read_bytes
    with patch.object(Path, 'read_bytes', lambda path:
                      read(path) + b'changed' if path == ROOT / PREDECESSOR else read(path)):
        reject('predecessor archive', 'CR16 workflow predecessor archive drifted',
               lambda: predecessor_bytes(WORKFLOW))
    is_link = Path.is_symlink
    for label, path, action, expected in (
            ('workflow symlink', ROOT / WORKFLOW, validate,
             'CR16 helper workflow is missing or nonregular'),
            ('predecessor symlink', ROOT / PREDECESSOR,
             lambda: predecessor_bytes(WORKFLOW),
             'CR16 workflow predecessor is missing or nonregular')):
        with patch.object(Path, 'is_symlink', lambda value, path=path:
                          True if value == path else is_link(value)):
            reject(label, expected, action)
    validate()
    return rows
