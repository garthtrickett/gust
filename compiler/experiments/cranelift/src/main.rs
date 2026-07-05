use std::env;
use std::error::Error;
use std::fs;
use std::io::{Error as IoError, ErrorKind};
use std::path::Path;

use cranelift_codegen::ir::{AbiParam, InstBuilder, condcodes::IntCC, types};
use cranelift_codegen::settings;
use cranelift_frontend::{FunctionBuilder, FunctionBuilderContext};
use cranelift_module::{Linkage, Module, default_libcall_names};
use cranelift_object::{ObjectBuilder, ObjectModule};

const RETURN_INT_SYMBOL: &str = "tiny_cranelift_return_int";
const LOCAL_BINDING_READ_SYMBOL: &str = "tiny_cranelift_local_binding_read";
const CONDITIONAL_BRANCH_SYMBOL: &str = "tiny_cranelift_conditional_branch";
const IDENTITY_I32_SYMBOL: &str = "tiny_cranelift_identity_i32";
const ADD_I32_SYMBOL: &str = "tiny_cranelift_add_i32";
const POSITIVE_I32_BRANCH_SYMBOL: &str = "tiny_cranelift_positive_i32_branch";
const INCREMENT_LOCAL_I32_SYMBOL: &str = "tiny_cranelift_increment_local_i32";
const CALL_HELPER_I32_SYMBOL: &str = "tiny_cranelift_call_helper_i32";
const ADD_ONE_HELPER_I32_SYMBOL: &str = "tiny_cranelift_add_one_helper_i32";
const EXTERN_CALL_I32_SYMBOL: &str = "tiny_cranelift_extern_call_i32";
const HOST_ADD_ONE_I32_SYMBOL: &str = "tiny_host_add_one_i32";
const EXTERN_ADD_I32_SYMBOL: &str = "tiny_cranelift_extern_add_i32";
const HOST_ADD_I32_SYMBOL: &str = "tiny_host_add_i32";

fn main() {
    if let Err(error) = run() {
        eprintln!("gust Cranelift experiment failed: {error}");
        std::process::exit(2);
    }
}

fn run() -> Result<(), Box<dyn Error>> {
    let mut args = env::args().skip(1);
    let Some(command) = args.next() else {
        return Err(usage_error().into());
    };

    match command.as_str() {
        "return-int-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_return_int_object(Path::new(&output_path))
        }
        "local-binding-read-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_local_binding_read_object(Path::new(&output_path))
        }
        "conditional-branch-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_conditional_branch_object(Path::new(&output_path))
        }
        "identity-i32-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_identity_i32_object(Path::new(&output_path))
        }
        "add-i32-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_add_i32_object(Path::new(&output_path))
        }
        "positive-i32-branch-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_positive_i32_branch_object(Path::new(&output_path))
        }
        "increment-local-i32-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_increment_local_i32_object(Path::new(&output_path))
        }
        "call-helper-i32-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_call_helper_i32_object(Path::new(&output_path))
        }
        "extern-call-i32-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_extern_call_i32_object(Path::new(&output_path))
        }
        "extern-add-i32-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_extern_add_i32_object(Path::new(&output_path))
        }
        _ => Err(usage_error().into()),
    }
}

fn usage_error() -> IoError {
    IoError::new(
        ErrorKind::InvalidInput,
        "usage: gust-cranelift-experiment <return-int-object|local-binding-read-object|conditional-branch-object|identity-i32-object|add-i32-object|positive-i32-branch-object|increment-local-i32-object|call-helper-i32-object|extern-call-i32-object|extern-add-i32-object> <output.o>",
    )
}

fn emit_return_int_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    emit_zero_arg_i32_object(
        output_path,
        "gust_cranelift_return_int",
        RETURN_INT_SYMBOL,
        build_return_int_body,
    )
}

fn emit_local_binding_read_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    emit_zero_arg_i32_object(
        output_path,
        "gust_cranelift_local_binding_read",
        LOCAL_BINDING_READ_SYMBOL,
        build_local_binding_read_body,
    )
}

fn emit_conditional_branch_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    emit_zero_arg_i32_object(
        output_path,
        "gust_cranelift_conditional_branch",
        CONDITIONAL_BRANCH_SYMBOL,
        build_conditional_branch_body,
    )
}

fn emit_identity_i32_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    emit_one_i32_arg_i32_object(
        output_path,
        "gust_cranelift_identity_i32",
        IDENTITY_I32_SYMBOL,
        build_identity_i32_body,
    )
}

fn emit_add_i32_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder = cranelift_native::builder()
        .map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(isa, "gust_cranelift_add_i32", default_libcall_names())?;
    let mut module = ObjectModule::new(object_builder);

    let mut signature = module.make_signature();
    signature.params.push(AbiParam::new(types::I32));
    signature.params.push(AbiParam::new(types::I32));
    signature.returns.push(AbiParam::new(types::I32));

    let function_id = module.declare_function(ADD_I32_SYMBOL, Linkage::Export, &signature)?;
    let mut context = module.make_context();
    context.func.signature = signature;

    let mut builder_context = FunctionBuilderContext::new();
    let mut builder = FunctionBuilder::new(&mut context.func, &mut builder_context);
    build_add_i32_body(&mut builder);
    builder.seal_all_blocks();
    builder.finalize();

    module.define_function(function_id, &mut context)?;
    module.clear_context(&mut context);

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_positive_i32_branch_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    emit_one_i32_arg_i32_object(
        output_path,
        "gust_cranelift_positive_i32_branch",
        POSITIVE_I32_BRANCH_SYMBOL,
        build_positive_i32_branch_body,
    )
}

fn emit_increment_local_i32_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    emit_one_i32_arg_i32_object(
        output_path,
        "gust_cranelift_increment_local_i32",
        INCREMENT_LOCAL_I32_SYMBOL,
        build_increment_local_i32_body,
    )
}

fn emit_call_helper_i32_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder = cranelift_native::builder()
        .map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder =
        ObjectBuilder::new(isa, "gust_cranelift_call_helper_i32", default_libcall_names())?;
    let mut module = ObjectModule::new(object_builder);

    let mut helper_signature = module.make_signature();
    helper_signature.params.push(AbiParam::new(types::I32));
    helper_signature.returns.push(AbiParam::new(types::I32));

    let helper_function_id =
        module.declare_function(ADD_ONE_HELPER_I32_SYMBOL, Linkage::Local, &helper_signature)?;
    let mut helper_context = module.make_context();
    helper_context.func.signature = helper_signature;

    let mut helper_builder_context = FunctionBuilderContext::new();
    let mut helper_builder =
        FunctionBuilder::new(&mut helper_context.func, &mut helper_builder_context);
    build_add_one_helper_i32_body(&mut helper_builder);
    helper_builder.seal_all_blocks();
    helper_builder.finalize();

    module.define_function(helper_function_id, &mut helper_context)?;
    module.clear_context(&mut helper_context);

    let mut caller_signature = module.make_signature();
    caller_signature.params.push(AbiParam::new(types::I32));
    caller_signature.returns.push(AbiParam::new(types::I32));

    let caller_function_id =
        module.declare_function(CALL_HELPER_I32_SYMBOL, Linkage::Export, &caller_signature)?;
    let mut caller_context = module.make_context();
    caller_context.func.signature = caller_signature;

    let mut caller_builder_context = FunctionBuilderContext::new();
    let mut caller_builder =
        FunctionBuilder::new(&mut caller_context.func, &mut caller_builder_context);

    let entry_block = caller_builder.create_block();
    caller_builder.append_block_params_for_function_params(entry_block);
    caller_builder.switch_to_block(entry_block);

    let argument_value = caller_builder.block_params(entry_block)[0];
    let helper_function_ref = module.declare_func_in_func(helper_function_id, caller_builder.func);
    let call_inst = caller_builder.ins().call(helper_function_ref, &[argument_value]);
    let return_value = caller_builder.inst_results(call_inst)[0];
    caller_builder.ins().return_(&[return_value]);

    caller_builder.seal_all_blocks();
    caller_builder.finalize();

    module.define_function(caller_function_id, &mut caller_context)?;
    module.clear_context(&mut caller_context);

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_extern_call_i32_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder = cranelift_native::builder()
        .map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder =
        ObjectBuilder::new(isa, "gust_cranelift_extern_call_i32", default_libcall_names())?;
    let mut module = ObjectModule::new(object_builder);

    let mut host_signature = module.make_signature();
    host_signature.params.push(AbiParam::new(types::I32));
    host_signature.returns.push(AbiParam::new(types::I32));

    let host_function_id =
        module.declare_function(HOST_ADD_ONE_I32_SYMBOL, Linkage::Import, &host_signature)?;

    let mut caller_signature = module.make_signature();
    caller_signature.params.push(AbiParam::new(types::I32));
    caller_signature.returns.push(AbiParam::new(types::I32));

    let caller_function_id =
        module.declare_function(EXTERN_CALL_I32_SYMBOL, Linkage::Export, &caller_signature)?;
    let mut caller_context = module.make_context();
    caller_context.func.signature = caller_signature;

    let mut caller_builder_context = FunctionBuilderContext::new();
    let mut caller_builder =
        FunctionBuilder::new(&mut caller_context.func, &mut caller_builder_context);

    let entry_block = caller_builder.create_block();
    caller_builder.append_block_params_for_function_params(entry_block);
    caller_builder.switch_to_block(entry_block);

    let argument_value = caller_builder.block_params(entry_block)[0];
    let host_function_ref = module.declare_func_in_func(host_function_id, caller_builder.func);
    let call_inst = caller_builder.ins().call(host_function_ref, &[argument_value]);
    let return_value = caller_builder.inst_results(call_inst)[0];
    caller_builder.ins().return_(&[return_value]);

    caller_builder.seal_all_blocks();
    caller_builder.finalize();

    module.define_function(caller_function_id, &mut caller_context)?;
    module.clear_context(&mut caller_context);

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_extern_add_i32_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder = cranelift_native::builder()
        .map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder =
        ObjectBuilder::new(isa, "gust_cranelift_extern_add_i32", default_libcall_names())?;
    let mut module = ObjectModule::new(object_builder);

    let mut host_signature = module.make_signature();
    host_signature.params.push(AbiParam::new(types::I32));
    host_signature.params.push(AbiParam::new(types::I32));
    host_signature.returns.push(AbiParam::new(types::I32));

    let host_function_id =
        module.declare_function(HOST_ADD_I32_SYMBOL, Linkage::Import, &host_signature)?;

    let mut caller_signature = module.make_signature();
    caller_signature.params.push(AbiParam::new(types::I32));
    caller_signature.returns.push(AbiParam::new(types::I32));

    let caller_function_id =
        module.declare_function(EXTERN_ADD_I32_SYMBOL, Linkage::Export, &caller_signature)?;
    let mut caller_context = module.make_context();
    caller_context.func.signature = caller_signature;

    let mut caller_builder_context = FunctionBuilderContext::new();
    let mut caller_builder =
        FunctionBuilder::new(&mut caller_context.func, &mut caller_builder_context);

    let entry_block = caller_builder.create_block();
    caller_builder.append_block_params_for_function_params(entry_block);
    caller_builder.switch_to_block(entry_block);

    let argument_value = caller_builder.block_params(entry_block)[0];
    let three = caller_builder.ins().iconst(types::I32, 3);
    let host_function_ref = module.declare_func_in_func(host_function_id, caller_builder.func);
    let call_inst = caller_builder
        .ins()
        .call(host_function_ref, &[argument_value, three]);
    let return_value = caller_builder.inst_results(call_inst)[0];
    caller_builder.ins().return_(&[return_value]);

    caller_builder.seal_all_blocks();
    caller_builder.finalize();

    module.define_function(caller_function_id, &mut caller_context)?;
    module.clear_context(&mut caller_context);

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_zero_arg_i32_object(
    output_path: &Path,
    object_name: &str,
    symbol: &str,
    build_body: fn(&mut FunctionBuilder<'_>),
) -> Result<(), Box<dyn Error>> {
    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(isa, object_name, default_libcall_names())?;
    let mut module = ObjectModule::new(object_builder);

    let mut signature = module.make_signature();
    signature.returns.push(AbiParam::new(types::I32));

    let function_id = module.declare_function(symbol, Linkage::Export, &signature)?;
    let mut context = module.make_context();
    context.func.signature = signature;

    let mut builder_context = FunctionBuilderContext::new();
    let mut builder = FunctionBuilder::new(&mut context.func, &mut builder_context);
    build_body(&mut builder);
    builder.seal_all_blocks();
    builder.finalize();

    module.define_function(function_id, &mut context)?;
    module.clear_context(&mut context);

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_one_i32_arg_i32_object(
    output_path: &Path,
    object_name: &str,
    symbol: &str,
    build_body: fn(&mut FunctionBuilder<'_>),
) -> Result<(), Box<dyn Error>> {
    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder = cranelift_native::builder()
        .map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(isa, object_name, default_libcall_names())?;
    let mut module = ObjectModule::new(object_builder);

    let mut signature = module.make_signature();
    signature.params.push(AbiParam::new(types::I32));
    signature.returns.push(AbiParam::new(types::I32));

    let function_id = module.declare_function(symbol, Linkage::Export, &signature)?;
    let mut context = module.make_context();
    context.func.signature = signature;

    let mut builder_context = FunctionBuilderContext::new();
    let mut builder = FunctionBuilder::new(&mut context.func, &mut builder_context);
    build_body(&mut builder);
    builder.seal_all_blocks();
    builder.finalize();

    module.define_function(function_id, &mut context)?;
    module.clear_context(&mut context);

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn build_return_int_body(builder: &mut FunctionBuilder<'_>) {
    let entry_block = builder.create_block();
    builder.switch_to_block(entry_block);
    builder.append_block_params_for_function_params(entry_block);
    let return_value = builder.ins().iconst(types::I32, 1);
    builder.ins().return_(&[return_value]);
}

fn build_local_binding_read_body(builder: &mut FunctionBuilder<'_>) {
    let entry_block = builder.create_block();
    builder.switch_to_block(entry_block);
    builder.append_block_params_for_function_params(entry_block);

    let value_slot = builder.declare_var(types::I32);
    let assigned_value = builder.ins().iconst(types::I32, 2);
    builder.def_var(value_slot, assigned_value);
    let read_value = builder.use_var(value_slot);
    builder.ins().return_(&[read_value]);
}

fn build_conditional_branch_body(builder: &mut FunctionBuilder<'_>) {
    let entry_block = builder.create_block();
    let then_block = builder.create_block();
    let else_block = builder.create_block();

    builder.switch_to_block(entry_block);
    builder.append_block_params_for_function_params(entry_block);
    let condition = builder.ins().iconst(types::I32, 1);
    builder
        .ins()
        .brif(condition, then_block, &[], else_block, &[]);

    builder.switch_to_block(then_block);
    let then_value = builder.ins().iconst(types::I32, 1);
    builder.ins().return_(&[then_value]);

    builder.switch_to_block(else_block);
    let else_value = builder.ins().iconst(types::I32, 2);
    builder.ins().return_(&[else_value]);
}

fn build_identity_i32_body(builder: &mut FunctionBuilder<'_>) {
    let entry_block = builder.create_block();
    builder.append_block_params_for_function_params(entry_block);
    builder.switch_to_block(entry_block);

    let argument_value = builder.block_params(entry_block)[0];
    builder.ins().return_(&[argument_value]);
}

fn build_add_i32_body(builder: &mut FunctionBuilder<'_>) {
    let entry_block = builder.create_block();
    builder.append_block_params_for_function_params(entry_block);
    builder.switch_to_block(entry_block);

    let block_params = builder.block_params(entry_block);
    let lhs = block_params[0];
    let rhs = block_params[1];
    let sum = builder.ins().iadd(lhs, rhs);
    builder.ins().return_(&[sum]);
}

fn build_positive_i32_branch_body(builder: &mut FunctionBuilder<'_>) {
    let entry_block = builder.create_block();
    let then_block = builder.create_block();
    let else_block = builder.create_block();

    builder.append_block_params_for_function_params(entry_block);
    builder.switch_to_block(entry_block);
    let argument_value = builder.block_params(entry_block)[0];
    let is_positive = builder
        .ins()
        .icmp_imm(IntCC::SignedGreaterThan, argument_value, 0);
    builder
        .ins()
        .brif(is_positive, then_block, &[], else_block, &[]);

    builder.switch_to_block(then_block);
    let then_value = builder.ins().iconst(types::I32, 7);
    builder.ins().return_(&[then_value]);

    builder.switch_to_block(else_block);
    let else_value = builder.ins().iconst(types::I32, 9);
    builder.ins().return_(&[else_value]);
}

fn build_increment_local_i32_body(builder: &mut FunctionBuilder<'_>) {
    let entry_block = builder.create_block();
    builder.append_block_params_for_function_params(entry_block);
    builder.switch_to_block(entry_block);

    let argument_value = builder.block_params(entry_block)[0];
    let value_slot = builder.declare_var(types::I32);
    builder.def_var(value_slot, argument_value);

    let current_value = builder.use_var(value_slot);
    let one = builder.ins().iconst(types::I32, 1);
    let incremented_value = builder.ins().iadd(current_value, one);
    builder.def_var(value_slot, incremented_value);

    let return_value = builder.use_var(value_slot);
    builder.ins().return_(&[return_value]);
}

fn build_add_one_helper_i32_body(builder: &mut FunctionBuilder<'_>) {
    let entry_block = builder.create_block();
    builder.append_block_params_for_function_params(entry_block);
    builder.switch_to_block(entry_block);

    let argument_value = builder.block_params(entry_block)[0];
    let one = builder.ins().iconst(types::I32, 1);
    let return_value = builder.ins().iadd(argument_value, one);
    builder.ins().return_(&[return_value]);
}
