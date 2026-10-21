import gdb
import json
import os

reads = []
completed = []
frees = []
free_done = []
errors = []
exit_code = None
sequence = []
wrapper_entries = []
wrapper_returns = []
allocations = []
backing_before_free = []
wrapper_active = False
expected = json.loads(os.environ['R2_EXPECTED_BYTES'])

def reg(name):
    return int(gdb.parse_and_eval('$' + name))

def signed32(value):
    value &= 0xffffffff
    return value - (0x100000000 if value & 0x80000000 else 0)

class Finished(gdb.FinishBreakpoint):
    def __init__(self, kind, record):
        self.kind = kind
        self.record = record
        super().__init__(gdb.newest_frame(), internal=True)

    def stop(self):
        try:
            if self.kind == 'read':
                record = dict(self.record)
                record['status'] = signed32(reg('rax'))
                record['byte'] = bytes(gdb.selected_inferior().read_memory(record['out'], 1))[0]
                completed.append(record)
                sequence.append('read_completed')
            else:
                free_done.append(dict(self.record))
                sequence.append('free_completed')
            return False
        except Exception as error:
            errors.append(str(error))
            return True

    def out_of_scope(self):
        errors.append(self.kind + ' frame left without normal return')

class WrapperReturn(gdb.FinishBreakpoint):
    def __init__(self):
        super().__init__(gdb.newest_frame(), internal=True)

    def stop(self):
        global wrapper_active
        try:
            if len(allocations) != 1 or len(free_done) != 1:
                raise ValueError('wrapper returned without unique output allocation and completed Free')
            pointer = allocations[0]['data']
            wrapper_returns.append(dict(status=signed32(reg('rax')),
                bytes=list(bytes(gdb.selected_inferior().read_memory(pointer, 2)))))
            wrapper_active = False
            return False
        except Exception as error:
            errors.append(str(error))
            return True

    def out_of_scope(self):
        errors.append('wrapper left without normal return')

class WrapperEntry(gdb.Breakpoint):
    def __init__(self):
        super().__init__('*copy_shape', internal=True)

    def stop(self):
        global wrapper_active
        try:
            if wrapper_entries or gdb.newest_frame().pc() != int(gdb.parse_and_eval('&copy_shape')):
                raise ValueError('wrapper entry multiplicity or symbol differs')
            record = dict(arena=reg('rdi'), input=reg('rsi'), capacity=signed32(reg('rdx')),level=signed32(reg('rcx')))
            if not record['arena'] or not record['input'] or record['capacity'] != 8 or record['level'] != 1:
                raise ValueError('wrapper fixture arguments differ')
            wrapper_entries.append(record)
            wrapper_active = True
            WrapperReturn()
            return False
        except Exception as error:
            errors.append(str(error))
            return True

class AllocationReturn(gdb.FinishBreakpoint):
    def __init__(self, arena, size):
        self.arena = arena
        self.size = size
        super().__init__(gdb.newest_frame(), internal=True)

    def stop(self):
        try:
            # Exact pinned runtime OsArena repr(C) stores base_address at byte0;
            # os_ArenaAlloc returns a u32 byte offset under the existing ABI.
            base = int.from_bytes(bytes(gdb.selected_inferior().read_memory(self.arena, 8)), 'little')
            offset = reg('rax') & 0xffffffff
            pointer = base + offset
            initial = list(bytes(gdb.selected_inferior().read_memory(pointer, self.size)))
            if allocations or self.size != 8 or initial != [0] * 8:
                raise ValueError('output allocation not unique size8 initially zero')
            allocations.append(dict(arena=self.arena,size=self.size,base=base,offset=offset,data=pointer,initial=initial))
            return False
        except Exception as error:
            errors.append(str(error))
            return True

    def out_of_scope(self):
        errors.append('output allocation left without normal return')

class AllocationEntry(gdb.Breakpoint):
    def __init__(self):
        super().__init__('*os_ArenaAlloc', internal=True)

    def stop(self):
        try:
            if not wrapper_active:
                return False
            caller = gdb.newest_frame().older()
            if caller is None or caller.name() != 'copy_shape':
                raise ValueError('unexpected allocator caller inside wrapper')
            if gdb.newest_frame().pc() != int(gdb.parse_and_eval('&os_ArenaAlloc')) or allocations:
                raise ValueError('allocator entry symbol or count differs')
            arena = reg('rdi')
            if arena != wrapper_entries[0]['arena'] or reg('rsi') != 8:
                raise ValueError('output allocation arena or size differs')
            AllocationReturn(arena, reg('rsi'))
            return False
        except Exception as error:
            errors.append(str(error))
            return True

class Enter(gdb.Breakpoint):
    def __init__(self, symbol, kind):
        self.symbol = symbol
        self.kind = kind
        super().__init__('*' + symbol, internal=True)

    def stop(self):
        try:
            if gdb.newest_frame().pc() != int(gdb.parse_and_eval('&' + self.symbol)):
                raise ValueError('entry PC differs from exact symbol')
            record = {'region': reg('rdi')}
            if not record['region']:
                raise ValueError('null owner')
            if self.kind == 'read':
                record.update(index=signed32(reg('rsi')), out=reg('rdx'))
                if not record['out'] or len(reads) >= 2:
                    raise ValueError('null output or unexpected read entry')
                reads.append(record)
                sequence.append('read_entry')
            else:
                if frees or len(completed) != 2:
                    raise ValueError('duplicate Free or Free before two completed reads')
                if len(allocations) != 1:
                    raise ValueError('Free lacks uniquely identified output backing')
                pointer = allocations[0]['data']
                backing_before_free.append(list(bytes(gdb.selected_inferior().read_memory(pointer, 8))))
                frees.append(record)
                sequence.append('free_entry')
            Finished(self.kind, record)
            return False
        except Exception as error:
            errors.append(str(error))
            return True

def exited(event):
    global exit_code
    exit_code = getattr(event, 'exit_code', None)

gdb.execute('set pagination off')
gdb.execute('set confirm off')
gdb.execute('set debuginfod enabled off')
gdb.execute('set disable-randomization off')
gdb.events.exited.connect(exited)
verdict = 'REJECTED (different assertion)'
reason = ''
try:
    WrapperEntry()
    AllocationEntry()
    Enter('os_FfiCallRegionReadOutput', 'read')
    Enter('os_FfiCallRegionFree', 'free')
    gdb.execute('run')
    if errors or exit_code != 2 or len(reads) != 2 or len(completed) != 2 or len(frees) != 1 or len(free_done) != 1:
        raise ValueError('entry/completion/exit cardinality mismatch: ' + repr(errors))
    if [(r['index'],r['status']) for r in completed] != [(0,0),(1,0)]:
        raise ValueError('index or status differs')
    if any(a != {k:b[k] for k in a} for a,b in zip(reads,completed)):
        raise ValueError('read completion does not match entry')
    owner = reads[0]['region']
    if any(r['region'] != owner for r in reads + completed + frees + free_done):
        raise ValueError('owner identity differs')
    if sequence != ['read_entry','read_completed','read_entry','read_completed','free_entry','free_completed']:
        raise ValueError('completion sequence differs')
    if len(wrapper_entries) != 1 or len(wrapper_returns) != 1 or wrapper_returns[0]['status'] != 2 or len(allocations) != 1 or len(backing_before_free) != 1:
        raise ValueError('wrapper/output allocation observation incomplete')
    if backing_before_free[0][:2] != expected or wrapper_returns[0]['bytes'] != expected or backing_before_free[0][2:] != [0] * 6:
        verdict = 'REJECTED (expected assertion)'
        raise ValueError('actual output backing bytes differ from expected oracle')
    if [r['byte'] for r in completed] != expected:
        verdict = 'REJECTED (expected assertion)'
        raise ValueError('copied byte values differ from expected oracle')
    verdict = 'ACCEPTED'
except Exception as error:
    reason = str(error)
report = dict(verdict=verdict,reason=reason,expected=expected,reads=reads,completed=completed,frees=frees,free_completed=free_done,sequence=sequence,errors=errors,inferior_exit=exit_code,wrapper_entries=wrapper_entries,wrapper_returns=wrapper_returns,allocations=allocations,backing_before_free=backing_before_free)
with open(os.environ['R2_OBSERVER_RESULT'], 'x') as stream:
    json.dump(report,stream,indent=2,sort_keys=True)
    stream.write('\n')
gdb.write('R2_FINISH_OBSERVER ' + verdict + ': ' + reason + '\n')
gdb.execute('quit ' + ('0' if verdict == 'ACCEPTED' else '1'))
