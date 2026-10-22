//! Checked storage primitives shared by the ordinary collection lowerers.
//!
//! Dispatch and resolved element identity belong to the caller. This module
//! accepts a typed storage record and never recognizes a library/type spelling.
use super::*;

pub(super) struct Storage {
    pub data: Value,
    pub len: Value,
    pub capacity: Value,
    pub arena: Value,
    pub arena_capacity: Value,
    pub data_field: Place,
    pub len_field: Place,
    pub capacity_field: Place,
    pub element_size: u32,
}

pub(super) fn trap() -> TrapCode {
    TrapCode::unwrap_user(26)
}

// A separate pure emitter lets qualification exercise count/byte boundaries
// without allocating gigabytes or fabricating initialized storage.
fn checked_growth(
    builder: &mut FunctionBuilder<'_>,
    capacity: Value,
    element_size: u32,
    arena_capacity: Value,
) -> (Value, Value) {
    let zero = builder.ins().icmp_imm(IntCC::Equal, capacity, 0);
    let capacity64 = builder.ins().uextend(types::I64, capacity);
    let doubled = builder.ins().imul_imm(capacity64, 2);
    let eight = builder.ins().iconst(types::I64, 8);
    let new_capacity64 = builder.ins().select(zero, eight, doubled);
    let count_valid = builder.ins().icmp_imm(
        IntCC::UnsignedLessThanOrEqual,
        new_capacity64,
        i64::from(i32::MAX),
    );
    builder.ins().trapz(count_valid, trap());
    let bytes = builder
        .ins()
        .imul_imm(new_capacity64, i64::from(element_size));
    let bytes_valid = builder
        .ins()
        .icmp(IntCC::UnsignedLessThanOrEqual, bytes, arena_capacity);
    builder.ins().trapz(bytes_valid, trap());
    (new_capacity64, bytes)
}

// Private object-local machine-code factoring. These symbols are defined in
// every emitted object, never imported from or exported by the runtime ABI.
const SLOT_CHECK: &str = ".gust.checked_arena_slot";
const STORAGE_CHECK: &str = ".gust.checked_collection_storage";

pub(super) fn define_checks(module: &mut ObjectModule) -> Result<(), Box<dyn Error>> {
    for (name, parameters) in [
        (SLOT_CHECK, vec![types::I64, types::I32, types::I64]),
        (
            STORAGE_CHECK,
            vec![types::I64, types::I32, types::I32, types::I64, types::I64],
        ),
    ] {
        let mut context = module.make_context();
        context.func.signature.params = parameters.into_iter().map(AbiParam::new).collect();
        context
            .func
            .signature
            .returns
            .push(AbiParam::new(types::I64));
        let id = module.declare_function(name, Linkage::Local, &context.func.signature)?;
        let mut frontend = FunctionBuilderContext::new();
        {
            let mut builder = FunctionBuilder::new(&mut context.func, &mut frontend);
            let entry = builder.create_block();
            builder.append_block_params_for_function_params(entry);
            builder.switch_to_block(entry);
            builder.seal_block(entry);
            let args = builder.block_params(entry).to_vec();
            let result = if name == SLOT_CHECK {
                emit_slot_check(&mut builder, args[0], args[1], args[2])
            } else {
                emit_storage_check(&mut builder, args[0], args[1], args[2], args[3], args[4])
            };
            builder.ins().return_(&[result]);
            builder.finalize();
        }
        module.define_function(id, &mut context)?;
    }
    Ok(())
}

fn emit_slot_check(
    builder: &mut FunctionBuilder<'_>,
    arena: Value,
    index: Value,
    size: Value,
) -> Value {
    let live = builder.ins().icmp_imm(IntCC::NotEqual, arena, 0);
    builder.ins().trapz(live, trap());
    let base = builder
        .ins()
        .load(types::I64, MemFlags::trusted(), arena, 0);
    let used = builder
        .ins()
        .load(types::I64, MemFlags::trusted(), arena, 8);
    let capacity = builder
        .ins()
        .load(types::I64, MemFlags::trusted(), arena, 16);
    let live = builder.ins().icmp_imm(IntCC::NotEqual, base, 0);
    builder.ins().trapz(live, trap());
    let valid = builder
        .ins()
        .icmp(IntCC::UnsignedLessThanOrEqual, used, capacity);
    builder.ins().trapz(valid, trap());
    let present = builder.ins().icmp_imm(IntCC::NotEqual, index, -1);
    builder.ins().trapz(present, trap());
    let offset = builder.ins().uextend(types::I64, index);
    let end = builder.ins().iadd(offset, size);
    let valid = builder
        .ins()
        .icmp(IntCC::UnsignedLessThanOrEqual, end, used);
    builder.ins().trapz(valid, trap());
    builder.ins().iadd(base, offset)
}

fn emit_storage_check(
    builder: &mut FunctionBuilder<'_>,
    data: Value,
    len: Value,
    capacity: Value,
    arena: Value,
    element_size: Value,
) -> Value {
    let nonnegative = builder
        .ins()
        .icmp_imm(IntCC::SignedGreaterThanOrEqual, len, 0);
    let ordered = builder
        .ins()
        .icmp(IntCC::SignedGreaterThanOrEqual, capacity, len);
    let counts_valid = builder.ins().band(nonnegative, ordered);
    builder.ins().trapz(counts_valid, trap());
    let live_arena = builder.ins().icmp_imm(IntCC::NotEqual, arena, 0);
    builder.ins().trapz(live_arena, trap());
    // Existing OsArena ABI: base pointer, usize offset, usize capacity.
    let base = builder
        .ins()
        .load(types::I64, MemFlags::trusted(), arena, 0);
    let live_base = builder.ins().icmp_imm(IntCC::NotEqual, base, 0);
    builder.ins().trapz(live_base, trap());
    let used = builder
        .ins()
        .load(types::I64, MemFlags::trusted(), arena, 8);
    let arena_capacity = builder
        .ins()
        .load(types::I64, MemFlags::trusted(), arena, 16);
    let used_valid = builder
        .ins()
        .icmp(IntCC::UnsignedLessThanOrEqual, used, arena_capacity);
    builder.ins().trapz(used_valid, trap());
    let capacity64 = builder.ins().uextend(types::I64, capacity);
    // Int count * u32 stride fits in u64; no i32 byte ceiling is imposed.
    let bytes = builder.ins().imul(capacity64, element_size);
    let bytes_valid = builder
        .ins()
        .icmp(IntCC::UnsignedLessThanOrEqual, bytes, arena_capacity);
    builder.ins().trapz(bytes_valid, trap());
    let empty = builder.ins().icmp_imm(IntCC::Equal, capacity, 0);
    let nonnull = builder.ins().icmp_imm(IntCC::NotEqual, data, 0);
    let above_base = builder
        .ins()
        .icmp(IntCC::UnsignedGreaterThanOrEqual, data, base);
    let offset = builder.ins().isub(data, base);
    let end = builder.ins().iadd(offset, bytes);
    let no_wrap = builder
        .ins()
        .icmp(IntCC::UnsignedGreaterThanOrEqual, end, offset);
    let in_arena = builder
        .ins()
        .icmp(IntCC::UnsignedLessThanOrEqual, end, used);
    let backing = builder.ins().band(nonnull, above_base);
    let backing = builder.ins().band(backing, no_wrap);
    let backing = builder.ins().band(backing, in_arena);
    let backing_valid = builder.ins().bor(empty, backing);
    builder.ins().trapz(backing_valid, trap());
    arena_capacity
}

impl<'a, 'm> FunctionLowerer<'a, 'm> {
    fn call_storage_check(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        name: &str,
        args: &[Value],
    ) -> Value {
        let Some(cranelift_module::FuncOrDataId::Func(id)) = self.module.get_name(name) else {
            unreachable!("private storage check must be defined before lowering functions")
        };
        let reference = self.module.declare_func_in_func(id, builder.func);
        let call = builder.ins().call(reference, args);
        builder.inst_results(call)[0]
    }

    /// An absent branded Index is not initialized storage. Validate the slot
    /// extent before a collection record (or any other typed arena value) can
    /// be loaded through it. Allocation itself already zeroes its payload.
    pub(super) fn checked_arena_slot(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        arena: Value,
        index: Value,
        size: u32,
    ) -> Place {
        let size = builder.ins().iconst(types::I64, i64::from(size));
        Place {
            address: self.call_storage_check(builder, SLOT_CHECK, &[arena, index, size]),
        }
    }

    /// Snapshot only after all operands have been evaluated. The source
    /// authority must also exclude metadata fabrication: numeric checks cannot
    /// prove that an arbitrary address names an allocation.
    pub(super) fn checked_storage(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        receiver: Place,
        receiver_type: &str,
    ) -> Result<Storage, Box<dyn Error>> {
        let (data_field, data_type) = self.field_place(builder, receiver, receiver_type, "data")?;
        let element_type = pointer_inner_type(&data_type)
            .ok_or_else(|| invalid("checked storage data has no resolved element"))?;
        let element_size = self.layouts.layout(element_type)?.size;
        if element_size == 0 {
            return Err(invalid("checked storage has zero element stride"));
        }
        let (len_field, len_type) = self.field_place(builder, receiver, receiver_type, "len")?;
        let (capacity_field, capacity_type) =
            self.field_place(builder, receiver, receiver_type, "capacity")?;
        if len_type != "Int" || capacity_type != "Int" {
            return Err(invalid("checked storage count fields are not Int"));
        }
        let (arena_field, _) = self.field_place(builder, receiver, receiver_type, "arena")?;
        let len = builder
            .ins()
            .load(types::I32, MemFlags::trusted(), len_field.address, 0);
        let capacity =
            builder
                .ins()
                .load(types::I32, MemFlags::trusted(), capacity_field.address, 0);
        let arena = builder.ins().load(
            self.pointer_type(),
            MemFlags::trusted(),
            arena_field.address,
            0,
        );
        let data = builder.ins().load(
            self.pointer_type(),
            MemFlags::trusted(),
            data_field.address,
            0,
        );
        let stride = builder.ins().iconst(types::I64, i64::from(element_size));
        let arena_capacity = self.call_storage_check(
            builder,
            STORAGE_CHECK,
            &[data, len, capacity, arena, stride],
        );
        Ok(Storage {
            data,
            len,
            capacity,
            arena,
            arena_capacity,
            data_field,
            len_field,
            capacity_field,
            element_size,
        })
    }

    pub(super) fn checked_element(
        &self,
        builder: &mut FunctionBuilder<'_>,
        storage: &Storage,
        index: Value,
    ) -> Place {
        let nonnegative = builder
            .ins()
            .icmp_imm(IntCC::SignedGreaterThanOrEqual, index, 0);
        let in_bounds = builder
            .ins()
            .icmp(IntCC::SignedLessThan, index, storage.len);
        let valid = builder.ins().band(nonnegative, in_bounds);
        builder.ins().trapz(valid, trap());
        let wide = builder.ins().uextend(types::I64, index);
        let offset = builder
            .ins()
            .imul_imm(wide, i64::from(storage.element_size));
        Place {
            address: builder.ins().iadd(storage.data, offset),
        }
    }

    /// Ensure one append slot without narrowing any allocation/copy byte count.
    /// The allocator returns an unsigned offset encoded in i32 and aborts on
    /// exhaustion; neither a negative-result test nor a new byte cap belongs here.
    pub(super) fn checked_append_slot(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        storage: &Storage,
    ) -> Result<Place, Box<dyn Error>> {
        let count_room =
            builder
                .ins()
                .icmp_imm(IntCC::SignedLessThan, storage.len, i64::from(i32::MAX));
        builder.ins().trapz(count_room, trap());
        let must_grow = builder
            .ins()
            .icmp(IntCC::Equal, storage.len, storage.capacity);
        let grow = builder.create_block();
        let ready = builder.create_block();
        builder.ins().brif(must_grow, grow, &[], ready, &[]);
        builder.switch_to_block(grow);
        let (new_capacity64, bytes) = checked_growth(
            builder,
            storage.capacity,
            storage.element_size,
            storage.arena_capacity,
        );
        let allocate = self
            .runtime
            .get("os_ArenaAlloc")
            .ok_or_else(|| invalid("checked storage allocator is absent"))?
            .clone();
        let allocate_ref = self.module.declare_func_in_func(allocate.id, builder.func);
        let allocation = builder.ins().call(allocate_ref, &[storage.arena, bytes]);
        let allocation_result = builder.inst_results(allocation)[0];
        let offset = builder.ins().uextend(types::I64, allocation_result);
        let base = builder
            .ins()
            .load(self.pointer_type(), MemFlags::trusted(), storage.arena, 0);
        let new_data = builder.ins().iadd(base, offset);
        let copy = builder.create_block();
        let grown = builder.create_block();
        let has_values = builder.ins().icmp_imm(IntCC::NotEqual, storage.len, 0);
        builder.ins().brif(has_values, copy, &[], grown, &[]);
        builder.switch_to_block(copy);
        let len64 = builder.ins().uextend(types::I64, storage.len);
        let used64 = builder
            .ins()
            .imul_imm(len64, i64::from(storage.element_size));
        let memcpy = self
            .runtime
            .get("memcpy")
            .ok_or_else(|| invalid("checked storage memcpy is absent"))?
            .clone();
        let memcpy_ref = self.module.declare_func_in_func(memcpy.id, builder.func);
        builder
            .ins()
            .call(memcpy_ref, &[new_data, storage.data, used64]);
        builder.ins().jump(grown, &[]);
        builder.switch_to_block(grown);
        let new_capacity = builder.ins().ireduce(types::I32, new_capacity64);
        builder
            .ins()
            .store(MemFlags::trusted(), new_data, storage.data_field.address, 0);
        builder.ins().store(
            MemFlags::trusted(),
            new_capacity,
            storage.capacity_field.address,
            0,
        );
        builder.ins().jump(ready, &[]);
        builder.switch_to_block(ready);
        let data = builder.ins().load(
            self.pointer_type(),
            MemFlags::trusted(),
            storage.data_field.address,
            0,
        );
        let index64 = builder.ins().uextend(types::I64, storage.len);
        let offset = builder
            .ins()
            .imul_imm(index64, i64::from(storage.element_size));
        Ok(Place {
            address: builder.ins().iadd(data, offset),
        })
    }
}

#[cfg(all(test, unix))]
#[path = "checked_collection_tests.rs"]
mod tests;
