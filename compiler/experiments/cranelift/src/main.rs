use std::env;
use std::error::Error;
use std::fs;
use std::io::{Error as IoError, ErrorKind};
use std::path::Path;

use cranelift_codegen::ir::{AbiParam, InstBuilder, types};
use cranelift_codegen::settings;
use cranelift_frontend::{FunctionBuilder, FunctionBuilderContext};
use cranelift_module::{Linkage, Module, default_libcall_names};
use cranelift_object::{ObjectBuilder, ObjectModule};

const RETURN_INT_SYMBOL: &str = "tiny_cranelift_return_int";
const LOCAL_BINDING_READ_SYMBOL: &str = "tiny_cranelift_local_binding_read";

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
        _ => Err(usage_error().into()),
    }
}

fn usage_error() -> IoError {
    IoError::new(
        ErrorKind::InvalidInput,
        "usage: gust-cranelift-experiment <return-int-object|local-binding-read-object> <output.o>",
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
