use std::collections::HashMap;
use std::env;
use std::error::Error;
use std::fs;
use std::io::{Error as IoError, ErrorKind};
use std::path::Path;

use cranelift_codegen::ir::{AbiParam, FuncRef, InstBuilder, Type, condcodes::IntCC, types};
use cranelift_codegen::settings;
use cranelift_frontend::{FunctionBuilder, FunctionBuilderContext, Variable};
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
const EXTERN_PREDICATE_BRANCH_I32_SYMBOL: &str = "tiny_cranelift_extern_predicate_branch_i32";
const HOST_IS_POSITIVE_I32_SYMBOL: &str = "tiny_host_is_positive_i32";
const MIR_RETURN_INT_SYMBOL: &str = "tiny_cranelift_mir_return_int";
const MIR_LOCAL_BINDING_READ_SYMBOL: &str = "tiny_cranelift_mir_local_binding_read";
const MIR_CONDITIONAL_BRANCH_SYMBOL: &str = "tiny_cranelift_mir_conditional_branch";
const MIR_ADD_I32_SYMBOL: &str = "tiny_cranelift_mir_add_i32";
const MIR_POSITIVE_I32_BRANCH_SYMBOL: &str = "tiny_cranelift_mir_positive_i32_branch";
const MIR_INCREMENT_LOCAL_I32_SYMBOL: &str = "tiny_cranelift_mir_increment_local_i32";
const MIR_CALL_HELPER_I32_SYMBOL: &str = "tiny_cranelift_mir_call_helper_i32";
const MIR_ADD_ONE_HELPER_I32_SYMBOL: &str = "tiny_cranelift_mir_add_one_helper_i32";
const MIR_EXTERN_CALL_I32_SYMBOL: &str = "tiny_cranelift_mir_extern_call_i32";
const MIR_EXTERN_ADD_I32_SYMBOL: &str = "tiny_cranelift_mir_extern_add_i32";

#[derive(Clone, Copy)]
enum TinyMirType {
    I32,
}

#[derive(Clone, Copy)]
struct TinyMirLocal {
    name: &'static str,
    ty: TinyMirType,
}

#[derive(Clone, Copy)]
enum TinyMirStatement {
    LocalI32Set { name: &'static str, value: i32 },
    LocalI32SetParam { name: &'static str, param: usize },
    LocalI32AddI32Literal { name: &'static str, value: i32 },
}

#[derive(Clone, Copy)]
enum TinyMirTerminator {
    ReturnI32(i32),
    ReturnLocalI32(&'static str),
    BranchI32Literal {
        condition: i32,
        then_return: i32,
        else_return: i32,
    },
    ReturnParamI32Add {
        lhs_param: usize,
        rhs_param: usize,
    },
    ReturnParamI32AddLiteral {
        param: usize,
        value: i32,
    },
    ReturnLocalFunctionI32Call {
        function_symbol: &'static str,
        arg_param: usize,
    },
    ReturnImportedFunctionI32Call {
        function_symbol: &'static str,
        arg_param: usize,
    },
    ReturnImportedFunctionI32CallParamLiteral {
        function_symbol: &'static str,
        arg_param: usize,
        arg_literal: i32,
    },
    BranchParamI32Positive {
        param: usize,
        then_return: i32,
        else_return: i32,
    },
}

struct TinyMirFunction {
    object_name: &'static str,
    symbol: &'static str,
    params: &'static [TinyMirType],
    return_type: TinyMirType,
    locals: &'static [TinyMirLocal],
    statements: &'static [TinyMirStatement],
    terminator: TinyMirTerminator,
}

static MIR_LOCAL_BINDING_READ_LOCALS: [TinyMirLocal; 1] = [TinyMirLocal {
    name: "value",
    ty: TinyMirType::I32,
}];

static MIR_LOCAL_BINDING_READ_STATEMENTS: [TinyMirStatement; 1] =
    [TinyMirStatement::LocalI32Set {
        name: "value",
        value: 2,
    }];

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
        "mir-return-int-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_return_int_object(Path::new(&output_path))
        }
        "mir-local-binding-read-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_local_binding_read_object(Path::new(&output_path))
        }
        "mir-conditional-branch-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_conditional_branch_object(Path::new(&output_path))
        }
        "mir-add-i32-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_add_i32_object(Path::new(&output_path))
        }
        "mir-positive-i32-branch-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_positive_i32_branch_object(Path::new(&output_path))
        }
        "mir-increment-local-i32-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_increment_local_i32_object(Path::new(&output_path))
        }
        "mir-call-helper-i32-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_call_helper_i32_object(Path::new(&output_path))
        }
        "mir-extern-call-i32-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_extern_call_i32_object(Path::new(&output_path))
        }
        "mir-extern-add-i32-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_extern_add_i32_object(Path::new(&output_path))
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
        "extern-predicate-branch-i32-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_extern_predicate_branch_i32_object(Path::new(&output_path))
        }
        _ => Err(usage_error().into()),
    }
}

fn usage_error() -> IoError {
    IoError::new(
        ErrorKind::InvalidInput,
        "usage: gust-cranelift-experiment <return-int-object|mir-return-int-object|mir-local-binding-read-object|mir-conditional-branch-object|mir-add-i32-object|mir-positive-i32-branch-object|mir-increment-local-i32-object|mir-call-helper-i32-object|mir-extern-call-i32-object|mir-extern-add-i32-object|local-binding-read-object|conditional-branch-object|identity-i32-object|add-i32-object|positive-i32-branch-object|increment-local-i32-object|call-helper-i32-object|extern-call-i32-object|extern-add-i32-object|extern-predicate-branch-i32-object> <output.o>",
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

fn emit_mir_return_int_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    let mir_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_return_int",
        symbol: MIR_RETURN_INT_SYMBOL,
        params: &[],
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnI32(1),
    };

    lower_tiny_mir_function_to_object(output_path, &mir_function)
}

fn emit_mir_local_binding_read_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    let mir_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_local_binding_read",
        symbol: MIR_LOCAL_BINDING_READ_SYMBOL,
        params: &[],
        return_type: TinyMirType::I32,
        locals: &MIR_LOCAL_BINDING_READ_LOCALS,
        statements: &MIR_LOCAL_BINDING_READ_STATEMENTS,
        terminator: TinyMirTerminator::ReturnLocalI32("value"),
    };

    lower_tiny_mir_function_to_object(output_path, &mir_function)
}

fn emit_mir_conditional_branch_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    let mir_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_conditional_branch",
        symbol: MIR_CONDITIONAL_BRANCH_SYMBOL,
        params: &[],
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::BranchI32Literal {
            condition: 1,
            then_return: 1,
            else_return: 2,
        },
    };

    lower_tiny_mir_function_to_object(output_path, &mir_function)
}

fn emit_mir_add_i32_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    static MIR_ADD_I32_PARAMS: [TinyMirType; 2] = [TinyMirType::I32, TinyMirType::I32];

    let mir_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_add_i32",
        symbol: MIR_ADD_I32_SYMBOL,
        params: &MIR_ADD_I32_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32Add {
            lhs_param: 0,
            rhs_param: 1,
        },
    };

    lower_tiny_mir_function_to_object(output_path, &mir_function)
}

fn emit_mir_positive_i32_branch_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    static MIR_POSITIVE_I32_BRANCH_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];

    let mir_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_positive_i32_branch",
        symbol: MIR_POSITIVE_I32_BRANCH_SYMBOL,
        params: &MIR_POSITIVE_I32_BRANCH_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::BranchParamI32Positive {
            param: 0,
            then_return: 7,
            else_return: 9,
        },
    };

    lower_tiny_mir_function_to_object(output_path, &mir_function)
}

fn emit_mir_increment_local_i32_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    static MIR_INCREMENT_LOCAL_I32_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static MIR_INCREMENT_LOCAL_I32_LOCALS: [TinyMirLocal; 1] = [TinyMirLocal {
        name: "value",
        ty: TinyMirType::I32,
    }];
    static MIR_INCREMENT_LOCAL_I32_STATEMENTS: [TinyMirStatement; 2] = [
        TinyMirStatement::LocalI32SetParam {
            name: "value",
            param: 0,
        },
        TinyMirStatement::LocalI32AddI32Literal {
            name: "value",
            value: 1,
        },
    ];

    let mir_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_increment_local_i32",
        symbol: MIR_INCREMENT_LOCAL_I32_SYMBOL,
        params: &MIR_INCREMENT_LOCAL_I32_PARAMS,
        return_type: TinyMirType::I32,
        locals: &MIR_INCREMENT_LOCAL_I32_LOCALS,
        statements: &MIR_INCREMENT_LOCAL_I32_STATEMENTS,
        terminator: TinyMirTerminator::ReturnLocalI32("value"),
    };

    lower_tiny_mir_function_to_object(output_path, &mir_function)
}

fn emit_mir_call_helper_i32_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    static MIR_CALL_HELPER_I32_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder = cranelift_native::builder()
        .map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_call_helper_i32",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let helper_mir_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_add_one_helper_i32",
        symbol: MIR_ADD_ONE_HELPER_I32_SYMBOL,
        params: &MIR_CALL_HELPER_I32_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32AddLiteral { param: 0, value: 1 },
    };

    let mut helper_signature = module.make_signature();
    helper_signature.params.push(AbiParam::new(types::I32));
    helper_signature.returns.push(AbiParam::new(types::I32));

    let helper_function_id = module.declare_function(
        helper_mir_function.symbol,
        Linkage::Local,
        &helper_signature,
    )?;
    let mut helper_context = module.make_context();
    helper_context.func.signature = helper_signature;

    let mut helper_builder_context = FunctionBuilderContext::new();
    let mut helper_builder =
        FunctionBuilder::new(&mut helper_context.func, &mut helper_builder_context);
    let helper_function_refs: HashMap<&'static str, FuncRef> = HashMap::new();
    build_tiny_mir_body(
        &mut helper_builder,
        &helper_mir_function,
        &helper_function_refs,
    )?;
    helper_builder.seal_all_blocks();
    helper_builder.finalize();

    module.define_function(helper_function_id, &mut helper_context)?;
    module.clear_context(&mut helper_context);

    let caller_mir_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_call_helper_i32",
        symbol: MIR_CALL_HELPER_I32_SYMBOL,
        params: &MIR_CALL_HELPER_I32_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnLocalFunctionI32Call {
            function_symbol: MIR_ADD_ONE_HELPER_I32_SYMBOL,
            arg_param: 0,
        },
    };

    let mut caller_signature = module.make_signature();
    caller_signature.params.push(AbiParam::new(types::I32));
    caller_signature.returns.push(AbiParam::new(types::I32));

    let caller_function_id = module.declare_function(
        caller_mir_function.symbol,
        Linkage::Export,
        &caller_signature,
    )?;
    let mut caller_context = module.make_context();
    caller_context.func.signature = caller_signature;

    let mut caller_builder_context = FunctionBuilderContext::new();
    let mut caller_builder =
        FunctionBuilder::new(&mut caller_context.func, &mut caller_builder_context);
    let helper_function_ref = module.declare_func_in_func(helper_function_id, caller_builder.func);
    let mut caller_function_refs: HashMap<&'static str, FuncRef> = HashMap::new();
    caller_function_refs.insert(MIR_ADD_ONE_HELPER_I32_SYMBOL, helper_function_ref);
    build_tiny_mir_body(
        &mut caller_builder,
        &caller_mir_function,
        &caller_function_refs,
    )?;
    caller_builder.seal_all_blocks();
    caller_builder.finalize();

    module.define_function(caller_function_id, &mut caller_context)?;
    module.clear_context(&mut caller_context);

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_mir_extern_call_i32_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    static MIR_EXTERN_CALL_I32_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder = cranelift_native::builder()
        .map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_extern_call_i32",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut host_signature = module.make_signature();
    host_signature.params.push(AbiParam::new(types::I32));
    host_signature.returns.push(AbiParam::new(types::I32));

    let host_function_id =
        module.declare_function(HOST_ADD_ONE_I32_SYMBOL, Linkage::Import, &host_signature)?;

    let caller_mir_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_extern_call_i32",
        symbol: MIR_EXTERN_CALL_I32_SYMBOL,
        params: &MIR_EXTERN_CALL_I32_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnImportedFunctionI32Call {
            function_symbol: HOST_ADD_ONE_I32_SYMBOL,
            arg_param: 0,
        },
    };

    let mut caller_signature = module.make_signature();
    caller_signature.params.push(AbiParam::new(types::I32));
    caller_signature.returns.push(AbiParam::new(types::I32));

    let caller_function_id = module.declare_function(
        caller_mir_function.symbol,
        Linkage::Export,
        &caller_signature,
    )?;
    let mut caller_context = module.make_context();
    caller_context.func.signature = caller_signature;

    let mut caller_builder_context = FunctionBuilderContext::new();
    let mut caller_builder =
        FunctionBuilder::new(&mut caller_context.func, &mut caller_builder_context);
    let host_function_ref = module.declare_func_in_func(host_function_id, caller_builder.func);
    let mut caller_function_refs: HashMap<&'static str, FuncRef> = HashMap::new();
    caller_function_refs.insert(HOST_ADD_ONE_I32_SYMBOL, host_function_ref);
    build_tiny_mir_body(
        &mut caller_builder,
        &caller_mir_function,
        &caller_function_refs,
    )?;
    caller_builder.seal_all_blocks();
    caller_builder.finalize();

    module.define_function(caller_function_id, &mut caller_context)?;
    module.clear_context(&mut caller_context);

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_mir_extern_add_i32_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    static MIR_EXTERN_ADD_I32_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder = cranelift_native::builder()
        .map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_extern_add_i32",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut host_signature = module.make_signature();
    host_signature.params.push(AbiParam::new(types::I32));
    host_signature.params.push(AbiParam::new(types::I32));
    host_signature.returns.push(AbiParam::new(types::I32));

    let host_function_id =
        module.declare_function(HOST_ADD_I32_SYMBOL, Linkage::Import, &host_signature)?;

    let caller_mir_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_extern_add_i32",
        symbol: MIR_EXTERN_ADD_I32_SYMBOL,
        params: &MIR_EXTERN_ADD_I32_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnImportedFunctionI32CallParamLiteral {
            function_symbol: HOST_ADD_I32_SYMBOL,
            arg_param: 0,
            arg_literal: 3,
        },
    };

    let mut caller_signature = module.make_signature();
    caller_signature.params.push(AbiParam::new(types::I32));
    caller_signature.returns.push(AbiParam::new(types::I32));

    let caller_function_id = module.declare_function(
        caller_mir_function.symbol,
        Linkage::Export,
        &caller_signature,
    )?;
    let mut caller_context = module.make_context();
    caller_context.func.signature = caller_signature;

    let mut caller_builder_context = FunctionBuilderContext::new();
    let mut caller_builder =
        FunctionBuilder::new(&mut caller_context.func, &mut caller_builder_context);
    let host_function_ref = module.declare_func_in_func(host_function_id, caller_builder.func);
    let mut caller_function_refs: HashMap<&'static str, FuncRef> = HashMap::new();
    caller_function_refs.insert(HOST_ADD_I32_SYMBOL, host_function_ref);
    build_tiny_mir_body(
        &mut caller_builder,
        &caller_mir_function,
        &caller_function_refs,
    )?;
    caller_builder.seal_all_blocks();
    caller_builder.finalize();

    module.define_function(caller_function_id, &mut caller_context)?;
    module.clear_context(&mut caller_context);

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
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

fn emit_extern_predicate_branch_i32_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder = cranelift_native::builder()
        .map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_extern_predicate_branch_i32",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut host_signature = module.make_signature();
    host_signature.params.push(AbiParam::new(types::I32));
    host_signature.returns.push(AbiParam::new(types::I32));

    let host_function_id = module.declare_function(
        HOST_IS_POSITIVE_I32_SYMBOL,
        Linkage::Import,
        &host_signature,
    )?;

    let mut caller_signature = module.make_signature();
    caller_signature.params.push(AbiParam::new(types::I32));
    caller_signature.returns.push(AbiParam::new(types::I32));

    let caller_function_id = module.declare_function(
        EXTERN_PREDICATE_BRANCH_I32_SYMBOL,
        Linkage::Export,
        &caller_signature,
    )?;
    let mut caller_context = module.make_context();
    caller_context.func.signature = caller_signature;

    let mut caller_builder_context = FunctionBuilderContext::new();
    let mut caller_builder =
        FunctionBuilder::new(&mut caller_context.func, &mut caller_builder_context);

    let entry_block = caller_builder.create_block();
    let then_block = caller_builder.create_block();
    let else_block = caller_builder.create_block();

    caller_builder.append_block_params_for_function_params(entry_block);
    caller_builder.switch_to_block(entry_block);

    let argument_value = caller_builder.block_params(entry_block)[0];
    let host_function_ref = module.declare_func_in_func(host_function_id, caller_builder.func);
    let call_inst = caller_builder.ins().call(host_function_ref, &[argument_value]);
    let predicate_value = caller_builder.inst_results(call_inst)[0];
    let is_nonzero = caller_builder
        .ins()
        .icmp_imm(IntCC::NotEqual, predicate_value, 0);
    caller_builder
        .ins()
        .brif(is_nonzero, then_block, &[], else_block, &[]);

    caller_builder.switch_to_block(then_block);
    let then_value = caller_builder.ins().iconst(types::I32, 11);
    caller_builder.ins().return_(&[then_value]);

    caller_builder.switch_to_block(else_block);
    let else_value = caller_builder.ins().iconst(types::I32, 13);
    caller_builder.ins().return_(&[else_value]);

    caller_builder.seal_all_blocks();
    caller_builder.finalize();

    module.define_function(caller_function_id, &mut caller_context)?;
    module.clear_context(&mut caller_context);

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn tiny_mir_type_to_cranelift_type(mir_type: TinyMirType) -> Type {
    match mir_type {
        TinyMirType::I32 => types::I32,
    }
}

fn lower_tiny_mir_function_to_object(
    output_path: &Path,
    mir_function: &TinyMirFunction,
) -> Result<(), Box<dyn Error>> {
    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder = cranelift_native::builder()
        .map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(isa, mir_function.object_name, default_libcall_names())?;
    let mut module = ObjectModule::new(object_builder);

    let mut signature = module.make_signature();
    for param in mir_function.params {
        signature
            .params
            .push(AbiParam::new(tiny_mir_type_to_cranelift_type(*param)));
    }
    signature
        .returns
        .push(AbiParam::new(tiny_mir_type_to_cranelift_type(
            mir_function.return_type,
        )));

    let function_id = module.declare_function(mir_function.symbol, Linkage::Export, &signature)?;
    let mut context = module.make_context();
    context.func.signature = signature;

    let mut builder_context = FunctionBuilderContext::new();
    let mut builder = FunctionBuilder::new(&mut context.func, &mut builder_context);
    let local_function_refs: HashMap<&'static str, FuncRef> = HashMap::new();
    build_tiny_mir_body(&mut builder, mir_function, &local_function_refs)?;
    builder.seal_all_blocks();
    builder.finalize();

    module.define_function(function_id, &mut context)?;
    module.clear_context(&mut context);

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn build_tiny_mir_body(
    builder: &mut FunctionBuilder<'_>,
    mir_function: &TinyMirFunction,
    local_function_refs: &HashMap<&'static str, FuncRef>,
) -> Result<(), Box<dyn Error>> {
    let entry_block = builder.create_block();
    builder.append_block_params_for_function_params(entry_block);
    builder.switch_to_block(entry_block);

    let mut local_slots: HashMap<&'static str, Variable> = HashMap::new();
    for local in mir_function.locals {
        let slot = builder.declare_var(tiny_mir_type_to_cranelift_type(local.ty));
        local_slots.insert(local.name, slot);
    }

    for statement in mir_function.statements {
        match *statement {
            TinyMirStatement::LocalI32Set { name, value } => {
                let local_slot = *local_slots.get(name).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR local binding: {name}"),
                    )
                })?;
                let local_value = builder.ins().iconst(types::I32, i64::from(value));
                builder.def_var(local_slot, local_value);
            }
            TinyMirStatement::LocalI32SetParam { name, param } => {
                let local_slot = *local_slots.get(name).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR set-param local binding: {name}"),
                    )
                })?;
                let param_value = {
                    let block_params = builder.block_params(entry_block);
                    block_params.get(param).copied().ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR set-param index: {param}"),
                        )
                    })?
                };
                builder.def_var(local_slot, param_value);
            }
            TinyMirStatement::LocalI32AddI32Literal { name, value } => {
                let local_slot = *local_slots.get(name).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR add-literal local binding: {name}"),
                    )
                })?;
                let current_value = builder.use_var(local_slot);
                let literal_value = builder.ins().iconst(types::I32, i64::from(value));
                let updated_value = builder.ins().iadd(current_value, literal_value);
                builder.def_var(local_slot, updated_value);
            }
        }
    }

    match mir_function.terminator {
        TinyMirTerminator::ReturnI32(value) => {
            let return_value = builder.ins().iconst(types::I32, i64::from(value));
            builder.ins().return_(&[return_value]);
        }
        TinyMirTerminator::ReturnLocalI32(name) => {
            let local_slot = *local_slots.get(name).ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR return local: {name}"),
                )
            })?;
            let return_value = builder.use_var(local_slot);
            builder.ins().return_(&[return_value]);
        }
        TinyMirTerminator::BranchI32Literal {
            condition,
            then_return,
            else_return,
        } => {
            let then_block = builder.create_block();
            let else_block = builder.create_block();
            let condition_value = builder.ins().iconst(types::I32, i64::from(condition));
            let branch_condition = builder
                .ins()
                .icmp_imm(IntCC::NotEqual, condition_value, 0);
            builder
                .ins()
                .brif(branch_condition, then_block, &[], else_block, &[]);

            builder.switch_to_block(then_block);
            let then_value = builder.ins().iconst(types::I32, i64::from(then_return));
            builder.ins().return_(&[then_value]);

            builder.switch_to_block(else_block);
            let else_value = builder.ins().iconst(types::I32, i64::from(else_return));
            builder.ins().return_(&[else_value]);
        }
        TinyMirTerminator::ReturnParamI32Add {
            lhs_param,
            rhs_param,
        } => {
            let block_params = builder.block_params(entry_block);
            let lhs = block_params.get(lhs_param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR add lhs param index: {lhs_param}"),
                )
            })?;
            let rhs = block_params.get(rhs_param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR add rhs param index: {rhs_param}"),
                )
            })?;
            let sum = builder.ins().iadd(lhs, rhs);
            builder.ins().return_(&[sum]);
        }
        TinyMirTerminator::ReturnParamI32AddLiteral { param, value } => {
            let block_params = builder.block_params(entry_block);
            let argument_value = block_params.get(param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR add-literal param index: {param}"),
                )
            })?;
            let literal_value = builder.ins().iconst(types::I32, i64::from(value));
            let return_value = builder.ins().iadd(argument_value, literal_value);
            builder.ins().return_(&[return_value]);
        }
        TinyMirTerminator::ReturnLocalFunctionI32Call {
            function_symbol,
            arg_param,
        } => {
            let block_params = builder.block_params(entry_block);
            let argument_value = block_params.get(arg_param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR call arg param index: {arg_param}"),
                )
            })?;
            let function_ref = *local_function_refs.get(function_symbol).ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR local function: {function_symbol}"),
                )
            })?;
            let call_inst = builder.ins().call(function_ref, &[argument_value]);
            let return_value = builder.inst_results(call_inst)[0];
            builder.ins().return_(&[return_value]);
        }
        TinyMirTerminator::ReturnImportedFunctionI32Call {
            function_symbol,
            arg_param,
        } => {
            let block_params = builder.block_params(entry_block);
            let argument_value = block_params.get(arg_param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR imported call arg param index: {arg_param}"),
                )
            })?;
            let function_ref = *local_function_refs.get(function_symbol).ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR imported function: {function_symbol}"),
                )
            })?;
            let call_inst = builder.ins().call(function_ref, &[argument_value]);
            let return_value = builder.inst_results(call_inst)[0];
            builder.ins().return_(&[return_value]);
        }
        TinyMirTerminator::ReturnImportedFunctionI32CallParamLiteral {
            function_symbol,
            arg_param,
            arg_literal,
        } => {
            let block_params = builder.block_params(entry_block);
            let argument_value = block_params.get(arg_param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR imported add call arg param index: {arg_param}"),
                )
            })?;
            let literal_value = builder.ins().iconst(types::I32, i64::from(arg_literal));
            let function_ref = *local_function_refs.get(function_symbol).ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR imported add function: {function_symbol}"),
                )
            })?;
            let call_inst = builder
                .ins()
                .call(function_ref, &[argument_value, literal_value]);
            let return_value = builder.inst_results(call_inst)[0];
            builder.ins().return_(&[return_value]);
        }
        TinyMirTerminator::BranchParamI32Positive {
            param,
            then_return,
            else_return,
        } => {
            let block_params = builder.block_params(entry_block);
            let condition_param = block_params.get(param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR positive branch param index: {param}"),
                )
            })?;
            let then_block = builder.create_block();
            let else_block = builder.create_block();
            let branch_condition = builder
                .ins()
                .icmp_imm(IntCC::SignedGreaterThan, condition_param, 0);
            builder
                .ins()
                .brif(branch_condition, then_block, &[], else_block, &[]);

            builder.switch_to_block(then_block);
            let then_value = builder.ins().iconst(types::I32, i64::from(then_return));
            builder.ins().return_(&[then_value]);

            builder.switch_to_block(else_block);
            let else_value = builder.ins().iconst(types::I32, i64::from(else_return));
            builder.ins().return_(&[else_value]);
        }
    }

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
