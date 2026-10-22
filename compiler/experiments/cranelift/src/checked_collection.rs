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
    pub len_field: Place,
    pub element_size: u32,
}

pub(super) struct AppendSlot {
    pub destination: Place,
    pub len: Value,
    pub len_field: Place,
    pub element_size: u32,
}

// Machine-code sharing is keyed by resolved placement, never source identity.
struct StorageShape {
    offsets: [u32; 4], // data, len, capacity, arena
    stride: u32,
}
impl StorageShape {
    fn load(&self, builder: &mut FunctionBuilder<'_>, receiver: Place) -> [Value; 4] {
        let types = [types::I64, types::I32, types::I32, types::I64];
        let mut load = |index: usize| {
            let address = add_offset(builder, receiver.address, self.offsets[index]);
            builder
                .ins()
                .load(types[index], MemFlags::trusted(), address, 0)
        };
        let len = load(1);
        let capacity = load(2);
        let arena = load(3);
        let data = load(0);
        [data, len, capacity, arena]
    }
}

// Source/canonical identities must never impersonate module-cached helpers.
pub(super) fn reject_private_symbol(symbol: &str) -> Result<(), Box<dyn Error>> {
    if symbol.starts_with(".gust.checked_") {
        return Err(invalid(
            "checked collection helper namespace is compiler-private",
        ));
    }
    Ok(())
}

pub(super) fn trap() -> TrapCode {
    TrapCode::unwrap_user(26)
}

// A separate pure emitter lets qualification exercise count/byte boundaries
// without allocating gigabytes or fabricating initialized storage.
fn checked_growth(
    builder: &mut FunctionBuilder<'_>,
    capacity: Value,
    element_size: Value,
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
    let bytes = builder.ins().imul(new_capacity64, element_size);
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
const ELEMENT_CHECK: &str = ".gust.checked_collection_element";
const APPEND_CHECK: &str = ".gust.checked_collection_append";

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
            } else if name == STORAGE_CHECK {
                emit_storage_check(&mut builder, args[0], args[1], args[2], args[3], args[4])
            } else {
                unreachable!("private check definitions have fixed names")
            };
            builder.ins().return_(&[result]);
            builder.seal_all_blocks();
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

// Called only after the caller's checked storage snapshot, with no intervening
// operand evaluation. It preserves the existing allocation/copy/metadata order.
fn emit_append(
    builder: &mut FunctionBuilder<'_>,
    args: &[Value],
    allocate: cranelift_codegen::ir::FuncRef,
    memcpy: cranelift_codegen::ir::FuncRef,
) -> Value {
    let [data, len, capacity, arena, element_size, data_field, capacity_field] = args else {
        unreachable!("private append helper has a fixed signature")
    };
    let (data, len, capacity, arena, element_size, data_field, capacity_field) = (
        *data,
        *len,
        *capacity,
        *arena,
        *element_size,
        *data_field,
        *capacity_field,
    );
    let count_room = builder
        .ins()
        .icmp_imm(IntCC::SignedLessThan, len, i64::from(i32::MAX));
    builder.ins().trapz(count_room, trap());
    let must_grow = builder.ins().icmp(IntCC::Equal, len, capacity);
    let grow = builder.create_block();
    let ready = builder.create_block();
    builder.ins().brif(must_grow, grow, &[], ready, &[]);
    builder.switch_to_block(grow);
    let arena_capacity = builder
        .ins()
        .load(types::I64, MemFlags::trusted(), arena, 16);
    let (new_capacity64, bytes) = checked_growth(builder, capacity, element_size, arena_capacity);
    let allocation = builder.ins().call(allocate, &[arena, bytes]);
    let allocation_result = builder.inst_results(allocation)[0];
    let offset = builder.ins().uextend(types::I64, allocation_result);
    let base = builder
        .ins()
        .load(types::I64, MemFlags::trusted(), arena, 0);
    let new_data = builder.ins().iadd(base, offset);
    let copy = builder.create_block();
    let grown = builder.create_block();
    let has_values = builder.ins().icmp_imm(IntCC::NotEqual, len, 0);
    builder.ins().brif(has_values, copy, &[], grown, &[]);
    builder.switch_to_block(copy);
    let len64 = builder.ins().uextend(types::I64, len);
    let used64 = builder.ins().imul(len64, element_size);
    builder.ins().call(memcpy, &[new_data, data, used64]);
    builder.ins().jump(grown, &[]);
    builder.switch_to_block(grown);
    let new_capacity = builder.ins().ireduce(types::I32, new_capacity64);
    builder
        .ins()
        .store(MemFlags::trusted(), new_data, data_field, 0);
    builder
        .ins()
        .store(MemFlags::trusted(), new_capacity, capacity_field, 0);
    builder.ins().jump(ready, &[]);
    builder.switch_to_block(ready);
    let data = builder
        .ins()
        .load(types::I64, MemFlags::trusted(), data_field, 0);
    let index64 = builder.ins().uextend(types::I64, len);
    let offset = builder.ins().imul(index64, element_size);
    builder.ins().iadd(data, offset)
}

impl<'a, 'm> FunctionLowerer<'a, 'm> {
    fn storage_shape(&mut self, receiver_type: &str) -> Result<StorageShape, Box<dyn Error>> {
        let layout = self.layouts.layout(receiver_type)?;
        let mut offsets = [0; 4];
        for (index, field) in ["data", "len", "capacity", "arena"].into_iter().enumerate() {
            offsets[index] = layout
                .fields
                .get(field)
                .ok_or_else(|| invalid(format!("checked storage has no {field} field")))?
                .offset;
        }
        if layout.fields["len"].ty != "Int" || layout.fields["capacity"].ty != "Int" {
            return Err(invalid("checked storage count fields are not Int"));
        }
        let element = pointer_inner_type(&layout.fields["data"].ty)
            .ok_or_else(|| invalid("checked storage data has no resolved element"))?;
        let stride = self.layouts.layout(element)?.size;
        if stride == 0 {
            return Err(invalid("checked storage has zero element stride"));
        }
        Ok(StorageShape { offsets, stride })
    }

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
    fn storage_fields(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        receiver: Place,
        receiver_type: &str,
    ) -> Result<Storage, Box<dyn Error>> {
        let shape = self.storage_shape(receiver_type)?;
        let [data, len, capacity, arena] = shape.load(builder, receiver);
        let len_field = Place {
            address: add_offset(builder, receiver.address, shape.offsets[1]),
        };
        let element_size = shape.stride;
        Ok(Storage {
            data,
            len,
            capacity,
            arena,
            len_field,
            element_size,
        })
    }

    pub(super) fn checked_storage(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        receiver: Place,
        receiver_type: &str,
    ) -> Result<Storage, Box<dyn Error>> {
        let storage = self.storage_fields(builder, receiver, receiver_type)?;
        let stride = builder
            .ins()
            .iconst(types::I64, i64::from(storage.element_size));
        self.call_storage_check(
            builder,
            STORAGE_CHECK,
            &[
                storage.data,
                storage.len,
                storage.capacity,
                storage.arena,
                stride,
            ],
        );
        Ok(storage)
    }

    fn shape_check(
        &mut self,
        shape: &StorageShape,
        operation: &str,
    ) -> Result<FuncId, Box<dyn Error>> {
        let name = format!(
            "{operation}_{}_{}_{}_{}_{}",
            shape.offsets[0], shape.offsets[1], shape.offsets[2], shape.offsets[3], shape.stride
        );
        if let Some(cranelift_module::FuncOrDataId::Func(id)) = self.module.get_name(&name) {
            return Ok(id);
        }
        let append = operation == APPEND_CHECK;
        let mut context = self.module.make_context();
        context
            .func
            .signature
            .params
            .push(AbiParam::new(types::I64));
        if !append {
            context
                .func
                .signature
                .params
                .push(AbiParam::new(types::I32));
        }
        context
            .func
            .signature
            .returns
            .push(AbiParam::new(types::I64));
        if append {
            context
                .func
                .signature
                .returns
                .push(AbiParam::new(types::I32));
        }
        let id = self
            .module
            .declare_function(&name, Linkage::Local, &context.func.signature)?;
        let mut frontend = FunctionBuilderContext::new();
        {
            let mut check = FunctionBuilder::new(&mut context.func, &mut frontend);
            let entry = check.create_block();
            check.append_block_params_for_function_params(entry);
            check.switch_to_block(entry);
            check.seal_block(entry);
            let params = check.block_params(entry).to_vec();
            let [data, len, capacity, arena] = shape.load(&mut check, Place { address: params[0] });
            let stride = check.ins().iconst(types::I64, i64::from(shape.stride));
            emit_storage_check(&mut check, data, len, capacity, arena, stride);
            if append {
                let data_field = add_offset(&mut check, params[0], shape.offsets[0]);
                let capacity_field = add_offset(&mut check, params[0], shape.offsets[2]);
                let allocate = self
                    .module
                    .declare_func_in_func(self.runtime["os_ArenaAlloc"].id, check.func);
                let memcpy = self
                    .module
                    .declare_func_in_func(self.runtime["memcpy"].id, check.func);
                let address = emit_append(
                    &mut check,
                    &[
                        data,
                        len,
                        capacity,
                        arena,
                        stride,
                        data_field,
                        capacity_field,
                    ],
                    allocate,
                    memcpy,
                );
                check.ins().return_(&[address, len]);
            } else {
                let valid = check.ins().icmp(IntCC::UnsignedLessThan, params[1], len);
                check.ins().trapz(valid, trap());
                let index = check.ins().uextend(types::I64, params[1]);
                let offset = check.ins().imul(index, stride);
                let address = check.ins().iadd(data, offset);
                check.ins().return_(&[address]);
            }
            check.seal_all_blocks();
            check.finalize();
        }
        self.module.define_function(id, &mut context)?;
        Ok(id)
    }

    /// Snapshot and validate after all operands, sharing only resolved placement.
    pub(super) fn checked_storage_element(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        receiver: Place,
        receiver_type: &str,
        index: Value,
    ) -> Result<Place, Box<dyn Error>> {
        let shape = self.storage_shape(receiver_type)?;
        let id = self.shape_check(&shape, ELEMENT_CHECK)?;
        let reference = self.module.declare_func_in_func(id, builder.func);
        let call = builder.ins().call(reference, &[receiver.address, index]);
        Ok(Place {
            address: builder.inst_results(call)[0],
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
        receiver: Place,
        receiver_type: &str,
    ) -> Result<AppendSlot, Box<dyn Error>> {
        let shape = self.storage_shape(receiver_type)?;
        let id = self.shape_check(&shape, APPEND_CHECK)?;
        let reference = self.module.declare_func_in_func(id, builder.func);
        let call = builder.ins().call(reference, &[receiver.address]);
        let results = builder.inst_results(call);
        let destination = Place {
            address: results[0],
        };
        let len = results[1];
        Ok(AppendSlot {
            destination,
            len,
            len_field: Place {
                address: add_offset(builder, receiver.address, shape.offsets[1]),
            },
            element_size: shape.stride,
        })
    }
}

#[cfg(all(test, unix))]
#[path = "checked_collection_tests.rs"]
mod tests;
