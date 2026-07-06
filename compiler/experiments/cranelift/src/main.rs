use std::collections::HashMap;
use std::env;
use std::error::Error;
use std::fs;
use std::io::{Error as IoError, ErrorKind};
use std::path::Path;

use cranelift_codegen::ir::{AbiParam, Block, FuncRef, InstBuilder, Type, condcodes::IntCC, types};
use cranelift_codegen::ir::instructions::BlockArg;
use cranelift_codegen::settings;
use cranelift_frontend::{FunctionBuilder, FunctionBuilderContext, Variable};
use cranelift_module::{FuncId, Linkage, Module, default_libcall_names};
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
const MIR_EXTERN_PREDICATE_BRANCH_I32_SYMBOL: &str =
    "tiny_cranelift_mir_extern_predicate_branch_i32";
const MIR_ARITHMETIC_SUB_I32_SYMBOL: &str = "tiny_cranelift_mir_arithmetic_sub_i32";
const MIR_ARITHMETIC_MUL_I32_SYMBOL: &str = "tiny_cranelift_mir_arithmetic_mul_i32";
const MIR_COMPARISON_EQ_I32_SYMBOL: &str = "tiny_cranelift_mir_comparison_eq_i32";
const MIR_COMPARISON_SGT_I32_SYMBOL: &str = "tiny_cranelift_mir_comparison_sgt_i32";
const MIR_COMPARISON_BRANCH_EQ_I32_SYMBOL: &str = "tiny_cranelift_mir_comparison_branch_eq_i32";
const MIR_COMPARISON_BRANCH_SGT_I32_SYMBOL: &str = "tiny_cranelift_mir_comparison_branch_sgt_i32";
const MIR_BLOCK_GRAPH_JUMP_I32_SYMBOL: &str = "tiny_cranelift_mir_block_graph_jump_i32";
const MIR_BLOCK_GRAPH_BRANCH_I32_SYMBOL: &str = "tiny_cranelift_mir_block_graph_branch_i32";
const MIR_BLOCK_GRAPH_LOCAL_READ_I32_SYMBOL: &str = "tiny_cranelift_mir_block_graph_local_read_i32";
const MIR_BLOCK_GRAPH_LOCAL_BRANCH_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_local_branch_i32";
const MIR_BLOCK_GRAPH_LOCAL_UPDATE_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_local_update_i32";
const MIR_BLOCK_GRAPH_LOCAL_UPDATE_BRANCH_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_local_update_branch_i32";
const MIR_BLOCK_GRAPH_PARAM_FORWARD_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_param_forward_i32";
const MIR_BLOCK_GRAPH_PARAM_UPDATE_BRANCH_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_param_update_branch_i32";
const MIR_BLOCK_GRAPH_PARAM_CALL_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_param_call_i32";
const MIR_BLOCK_GRAPH_PARAM_CALL_BRANCH_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_param_call_branch_i32";
const MIR_BLOCK_GRAPH_PARAM_CALL_HELPER_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_param_add_one_helper_i32";
const MIR_BLOCK_GRAPH_PARAM_EXTERN_CALL_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_param_extern_call_i32";
const MIR_BLOCK_GRAPH_PARAM_EXTERN_CALL_BRANCH_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_param_extern_call_branch_i32";
const MIR_BLOCK_GRAPH_PARAM_EXTERN_ADD_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_param_extern_add_i32";
const MIR_BLOCK_GRAPH_PARAM_EXTERN_ADD_BRANCH_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_param_extern_add_branch_i32";
const MIR_BLOCK_GRAPH_PARAM_EXTERN_PREDICATE_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_param_extern_predicate_i32";
const MIR_BLOCK_GRAPH_PARAM_EXTERN_PREDICATE_UPDATE_BRANCH_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_param_extern_predicate_update_branch_i32";
const MIR_BLOCK_GRAPH_PARAM_MERGE_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_param_merge_i32";
const MIR_BLOCK_GRAPH_PARAM_MERGE_UPDATE_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_param_merge_update_i32";
const MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_param_merge_call_i32";
const MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_BRANCH_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_param_merge_call_branch_i32";
const MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_HELPER_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_param_merge_add_one_helper_i32";

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
    ReturnParamI32Sub {
        lhs_param: usize,
        rhs_param: usize,
    },
    ReturnParamI32Mul {
        lhs_param: usize,
        rhs_param: usize,
    },
    ReturnParamI32EqPredicate {
        lhs_param: usize,
        rhs_param: usize,
    },
    ReturnParamI32SignedGreaterThanPredicate {
        lhs_param: usize,
        rhs_param: usize,
    },
    BranchParamI32Eq {
        lhs_param: usize,
        rhs_param: usize,
        then_return: i32,
        else_return: i32,
    },
    BranchParamI32SignedGreaterThan {
        lhs_param: usize,
        rhs_param: usize,
        then_return: i32,
        else_return: i32,
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
    BranchImportedFunctionI32Predicate {
        function_symbol: &'static str,
        arg_param: usize,
        then_return: i32,
        else_return: i32,
    },
    BranchParamI32Positive {
        param: usize,
        then_return: i32,
        else_return: i32,
    },
}

#[derive(Clone, Copy)]
enum TinyMirBlockStatement {
    LocalI32Set { name: &'static str, value: i32 },
    LocalI32SetParam { name: &'static str, param: usize },
    LocalI32AddI32Literal { name: &'static str, value: i32 },
}

#[derive(Clone, Copy)]
enum TinyMirBlockTerminator {
    Jump {
        target: &'static str,
    },
    BranchParamI32Positive {
        param: usize,
        then_block: &'static str,
        else_block: &'static str,
    },
    BranchLocalI32Positive {
        name: &'static str,
        then_block: &'static str,
        else_block: &'static str,
    },
    ReturnI32(i32),
    ReturnLocalI32(&'static str),
}

#[derive(Clone, Copy)]
struct TinyMirBlock {
    label: &'static str,
    statements: &'static [TinyMirBlockStatement],
    terminator: TinyMirBlockTerminator,
}

struct TinyMirBlockFunction {
    object_name: &'static str,
    symbol: &'static str,
    params: &'static [TinyMirType],
    return_type: TinyMirType,
    locals: &'static [TinyMirLocal],
    entry_block: &'static str,
    blocks: &'static [TinyMirBlock],
}

#[derive(Clone, Copy)]
enum TinyMirParamBlockTerminator {
    JumpI32Literal {
        target: &'static str,
        value: i32,
    },
    JumpFunctionParamI32 {
        target: &'static str,
        param: usize,
    },
    JumpBlockParamI32AddI32Literal {
        target: &'static str,
        param: usize,
        value: i32,
    },
    BranchBlockParamI32Positive {
        param: usize,
        then_block: &'static str,
        else_block: &'static str,
    },
    ReturnBlockParamLocalFunctionI32Call {
        function_symbol: &'static str,
        param: usize,
    },
    BranchBlockParamLocalFunctionI32CallPositive {
        function_symbol: &'static str,
        param: usize,
        then_block: &'static str,
        else_block: &'static str,
    },
    ReturnBlockParamImportedFunctionI32Call {
        function_symbol: &'static str,
        param: usize,
    },
    BranchBlockParamImportedFunctionI32CallPositive {
        function_symbol: &'static str,
        param: usize,
        then_block: &'static str,
        else_block: &'static str,
    },
    ReturnBlockParamImportedFunctionI32CallI32Literal {
        function_symbol: &'static str,
        param: usize,
        value: i32,
    },
    BranchBlockParamImportedFunctionI32CallI32LiteralPositive {
        function_symbol: &'static str,
        param: usize,
        value: i32,
        then_block: &'static str,
        else_block: &'static str,
    },
    BranchBlockParamImportedFunctionI32Predicate {
        function_symbol: &'static str,
        param: usize,
        then_block: &'static str,
        else_block: &'static str,
    },
    BranchBlockParamI32PositiveToI32Literals {
        param: usize,
        then_block: &'static str,
        then_value: i32,
        else_block: &'static str,
        else_value: i32,
    },
    ReturnI32(i32),
    ReturnBlockParamI32(usize),
}

#[derive(Clone, Copy)]
struct TinyMirParamBlock {
    label: &'static str,
    params: &'static [TinyMirType],
    terminator: TinyMirParamBlockTerminator,
}

struct TinyMirParamBlockFunction {
    object_name: &'static str,
    symbol: &'static str,
    params: &'static [TinyMirType],
    return_type: TinyMirType,
    entry_block: &'static str,
    blocks: &'static [TinyMirParamBlock],
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

static MIR_LOCAL_BINDING_READ_STATEMENTS: [TinyMirStatement; 1] = [TinyMirStatement::LocalI32Set {
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
        "mir-arithmetic-i32-bundle-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_arithmetic_i32_bundle_object(Path::new(&output_path))
        }
        "mir-comparison-i32-bundle-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_comparison_i32_bundle_object(Path::new(&output_path))
        }
        "mir-comparison-branch-i32-bundle-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_comparison_branch_i32_bundle_object(Path::new(&output_path))
        }
        "mir-block-graph-i32-bundle-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_block_graph_i32_bundle_object(Path::new(&output_path))
        }
        "mir-block-graph-local-i32-bundle-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_block_graph_local_i32_bundle_object(Path::new(&output_path))
        }
        "mir-block-graph-local-update-i32-bundle-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_block_graph_local_update_i32_bundle_object(Path::new(&output_path))
        }
        "mir-block-graph-param-i32-bundle-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_block_graph_param_i32_bundle_object(Path::new(&output_path))
        }
        "mir-block-graph-param-call-i32-bundle-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_block_graph_param_call_i32_bundle_object(Path::new(&output_path))
        }
        "mir-block-graph-param-extern-i32-bundle-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_block_graph_param_extern_i32_bundle_object(Path::new(&output_path))
        }
        "mir-block-graph-param-extern-add-i32-bundle-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_block_graph_param_extern_add_i32_bundle_object(Path::new(&output_path))
        }
        "mir-block-graph-param-extern-predicate-i32-bundle-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_block_graph_param_extern_predicate_i32_bundle_object(Path::new(&output_path))
        }
        "mir-block-graph-param-merge-i32-bundle-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_block_graph_param_merge_i32_bundle_object(Path::new(&output_path))
        }
        "mir-block-graph-param-merge-call-i32-bundle-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_block_graph_param_merge_call_i32_bundle_object(Path::new(&output_path))
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
        "mir-extern-predicate-branch-i32-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_extern_predicate_branch_i32_object(Path::new(&output_path))
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
        "usage: gust-cranelift-experiment <return-int-object|mir-return-int-object|mir-local-binding-read-object|mir-conditional-branch-object|mir-add-i32-object|mir-arithmetic-i32-bundle-object|mir-comparison-i32-bundle-object|mir-comparison-branch-i32-bundle-object|mir-block-graph-i32-bundle-object|mir-block-graph-local-i32-bundle-object|mir-block-graph-local-update-i32-bundle-object|mir-block-graph-param-i32-bundle-object|mir-block-graph-param-call-i32-bundle-object|mir-block-graph-param-extern-i32-bundle-object|mir-block-graph-param-extern-add-i32-bundle-object|mir-block-graph-param-extern-predicate-i32-bundle-object|mir-block-graph-param-merge-i32-bundle-object|mir-block-graph-param-merge-call-i32-bundle-object|mir-positive-i32-branch-object|mir-increment-local-i32-object|mir-call-helper-i32-object|mir-extern-call-i32-object|mir-extern-add-i32-object|mir-extern-predicate-branch-i32-object|local-binding-read-object|conditional-branch-object|identity-i32-object|add-i32-object|positive-i32-branch-object|increment-local-i32-object|call-helper-i32-object|extern-call-i32-object|extern-add-i32-object|extern-predicate-branch-i32-object> <output.o>",
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

fn emit_mir_arithmetic_i32_bundle_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    static MIR_ARITHMETIC_I32_PARAMS: [TinyMirType; 2] = [TinyMirType::I32, TinyMirType::I32];

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_arithmetic_i32_bundle",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);
    let local_function_refs: HashMap<&'static str, FuncRef> = HashMap::new();

    let sub_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_arithmetic_i32_bundle",
        symbol: MIR_ARITHMETIC_SUB_I32_SYMBOL,
        params: &MIR_ARITHMETIC_I32_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32Sub {
            lhs_param: 0,
            rhs_param: 1,
        },
    };
    define_tiny_mir_exported_function(&mut module, &sub_function, &local_function_refs)?;

    let mul_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_arithmetic_i32_bundle",
        symbol: MIR_ARITHMETIC_MUL_I32_SYMBOL,
        params: &MIR_ARITHMETIC_I32_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32Mul {
            lhs_param: 0,
            rhs_param: 1,
        },
    };
    define_tiny_mir_exported_function(&mut module, &mul_function, &local_function_refs)?;

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_mir_comparison_i32_bundle_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    static MIR_COMPARISON_I32_PARAMS: [TinyMirType; 2] = [TinyMirType::I32, TinyMirType::I32];

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_comparison_i32_bundle",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);
    let local_function_refs: HashMap<&'static str, FuncRef> = HashMap::new();

    let eq_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_comparison_i32_bundle",
        symbol: MIR_COMPARISON_EQ_I32_SYMBOL,
        params: &MIR_COMPARISON_I32_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32EqPredicate {
            lhs_param: 0,
            rhs_param: 1,
        },
    };
    define_tiny_mir_exported_function(&mut module, &eq_function, &local_function_refs)?;

    let sgt_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_comparison_i32_bundle",
        symbol: MIR_COMPARISON_SGT_I32_SYMBOL,
        params: &MIR_COMPARISON_I32_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32SignedGreaterThanPredicate {
            lhs_param: 0,
            rhs_param: 1,
        },
    };
    define_tiny_mir_exported_function(&mut module, &sgt_function, &local_function_refs)?;

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_mir_comparison_branch_i32_bundle_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    static MIR_COMPARISON_BRANCH_I32_PARAMS: [TinyMirType; 2] =
        [TinyMirType::I32, TinyMirType::I32];

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_comparison_branch_i32_bundle",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);
    let local_function_refs: HashMap<&'static str, FuncRef> = HashMap::new();

    let eq_branch_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_comparison_branch_i32_bundle",
        symbol: MIR_COMPARISON_BRANCH_EQ_I32_SYMBOL,
        params: &MIR_COMPARISON_BRANCH_I32_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::BranchParamI32Eq {
            lhs_param: 0,
            rhs_param: 1,
            then_return: 21,
            else_return: 22,
        },
    };
    define_tiny_mir_exported_function(&mut module, &eq_branch_function, &local_function_refs)?;

    let sgt_branch_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_comparison_branch_i32_bundle",
        symbol: MIR_COMPARISON_BRANCH_SGT_I32_SYMBOL,
        params: &MIR_COMPARISON_BRANCH_I32_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::BranchParamI32SignedGreaterThan {
            lhs_param: 0,
            rhs_param: 1,
            then_return: 23,
            else_return: 24,
        },
    };
    define_tiny_mir_exported_function(&mut module, &sgt_branch_function, &local_function_refs)?;

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_mir_block_graph_i32_bundle_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    static MIR_BLOCK_GRAPH_BRANCH_I32_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static MIR_BLOCK_GRAPH_JUMP_BLOCKS: [TinyMirBlock; 2] = [
        TinyMirBlock {
            label: "entry",
            statements: &[],
            terminator: TinyMirBlockTerminator::Jump { target: "return" },
        },
        TinyMirBlock {
            label: "return",
            statements: &[],
            terminator: TinyMirBlockTerminator::ReturnI32(29),
        },
    ];
    static MIR_BLOCK_GRAPH_BRANCH_BLOCKS: [TinyMirBlock; 3] = [
        TinyMirBlock {
            label: "entry",
            statements: &[],
            terminator: TinyMirBlockTerminator::BranchParamI32Positive {
                param: 0,
                then_block: "positive",
                else_block: "non_positive",
            },
        },
        TinyMirBlock {
            label: "positive",
            statements: &[],
            terminator: TinyMirBlockTerminator::ReturnI32(31),
        },
        TinyMirBlock {
            label: "non_positive",
            statements: &[],
            terminator: TinyMirBlockTerminator::ReturnI32(37),
        },
    ];

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_block_graph_i32_bundle",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let jump_function = TinyMirBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_JUMP_I32_SYMBOL,
        params: &[],
        return_type: TinyMirType::I32,
        locals: &[],
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_JUMP_BLOCKS,
    };
    let branch_function = TinyMirBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_BRANCH_I32_SYMBOL,
        params: &MIR_BLOCK_GRAPH_BRANCH_I32_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_BRANCH_BLOCKS,
    };

    define_tiny_mir_block_graph_exported_function(&mut module, &jump_function)?;
    define_tiny_mir_block_graph_exported_function(&mut module, &branch_function)?;

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_mir_block_graph_local_i32_bundle_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    static MIR_BLOCK_GRAPH_LOCAL_I32_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static MIR_BLOCK_GRAPH_LOCAL_I32_LOCALS: [TinyMirLocal; 1] = [TinyMirLocal {
        name: "value",
        ty: TinyMirType::I32,
    }];
    static MIR_BLOCK_GRAPH_LOCAL_SET_READ_ENTRY_STATEMENTS: [TinyMirBlockStatement; 1] =
        [TinyMirBlockStatement::LocalI32Set {
            name: "value",
            value: 41,
        }];
    static MIR_BLOCK_GRAPH_LOCAL_BRANCH_ENTRY_STATEMENTS: [TinyMirBlockStatement; 1] =
        [TinyMirBlockStatement::LocalI32SetParam {
            name: "value",
            param: 0,
        }];
    static MIR_BLOCK_GRAPH_LOCAL_SET_READ_BLOCKS: [TinyMirBlock; 2] = [
        TinyMirBlock {
            label: "entry",
            statements: &MIR_BLOCK_GRAPH_LOCAL_SET_READ_ENTRY_STATEMENTS,
            terminator: TinyMirBlockTerminator::Jump { target: "return" },
        },
        TinyMirBlock {
            label: "return",
            statements: &[],
            terminator: TinyMirBlockTerminator::ReturnLocalI32("value"),
        },
    ];
    static MIR_BLOCK_GRAPH_LOCAL_BRANCH_BLOCKS: [TinyMirBlock; 3] = [
        TinyMirBlock {
            label: "entry",
            statements: &MIR_BLOCK_GRAPH_LOCAL_BRANCH_ENTRY_STATEMENTS,
            terminator: TinyMirBlockTerminator::BranchLocalI32Positive {
                name: "value",
                then_block: "positive",
                else_block: "non_positive",
            },
        },
        TinyMirBlock {
            label: "positive",
            statements: &[],
            terminator: TinyMirBlockTerminator::ReturnI32(43),
        },
        TinyMirBlock {
            label: "non_positive",
            statements: &[],
            terminator: TinyMirBlockTerminator::ReturnI32(47),
        },
    ];

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_block_graph_local_i32_bundle",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let local_read_function = TinyMirBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_local_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_LOCAL_READ_I32_SYMBOL,
        params: &[],
        return_type: TinyMirType::I32,
        locals: &MIR_BLOCK_GRAPH_LOCAL_I32_LOCALS,
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_LOCAL_SET_READ_BLOCKS,
    };
    let local_branch_function = TinyMirBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_local_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_LOCAL_BRANCH_I32_SYMBOL,
        params: &MIR_BLOCK_GRAPH_LOCAL_I32_PARAMS,
        return_type: TinyMirType::I32,
        locals: &MIR_BLOCK_GRAPH_LOCAL_I32_LOCALS,
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_LOCAL_BRANCH_BLOCKS,
    };

    define_tiny_mir_block_graph_exported_function(&mut module, &local_read_function)?;
    define_tiny_mir_block_graph_exported_function(&mut module, &local_branch_function)?;

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_mir_block_graph_local_update_i32_bundle_object(
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    static MIR_BLOCK_GRAPH_LOCAL_UPDATE_I32_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static MIR_BLOCK_GRAPH_LOCAL_UPDATE_I32_LOCALS: [TinyMirLocal; 1] = [TinyMirLocal {
        name: "value",
        ty: TinyMirType::I32,
    }];
    static MIR_BLOCK_GRAPH_LOCAL_UPDATE_ENTRY_STATEMENTS: [TinyMirBlockStatement; 1] =
        [TinyMirBlockStatement::LocalI32Set {
            name: "value",
            value: 40,
        }];
    static MIR_BLOCK_GRAPH_LOCAL_UPDATE_STEP_STATEMENTS: [TinyMirBlockStatement; 1] =
        [TinyMirBlockStatement::LocalI32AddI32Literal {
            name: "value",
            value: 5,
        }];
    static MIR_BLOCK_GRAPH_LOCAL_UPDATE_BRANCH_ENTRY_STATEMENTS: [TinyMirBlockStatement; 1] =
        [TinyMirBlockStatement::LocalI32SetParam {
            name: "value",
            param: 0,
        }];
    static MIR_BLOCK_GRAPH_LOCAL_UPDATE_BRANCH_STEP_STATEMENTS: [TinyMirBlockStatement; 1] =
        [TinyMirBlockStatement::LocalI32AddI32Literal {
            name: "value",
            value: 2,
        }];
    static MIR_BLOCK_GRAPH_LOCAL_UPDATE_BLOCKS: [TinyMirBlock; 3] = [
        TinyMirBlock {
            label: "entry",
            statements: &MIR_BLOCK_GRAPH_LOCAL_UPDATE_ENTRY_STATEMENTS,
            terminator: TinyMirBlockTerminator::Jump { target: "increment" },
        },
        TinyMirBlock {
            label: "increment",
            statements: &MIR_BLOCK_GRAPH_LOCAL_UPDATE_STEP_STATEMENTS,
            terminator: TinyMirBlockTerminator::Jump { target: "return" },
        },
        TinyMirBlock {
            label: "return",
            statements: &[],
            terminator: TinyMirBlockTerminator::ReturnLocalI32("value"),
        },
    ];
    static MIR_BLOCK_GRAPH_LOCAL_UPDATE_BRANCH_BLOCKS: [TinyMirBlock; 4] = [
        TinyMirBlock {
            label: "entry",
            statements: &MIR_BLOCK_GRAPH_LOCAL_UPDATE_BRANCH_ENTRY_STATEMENTS,
            terminator: TinyMirBlockTerminator::Jump { target: "increment" },
        },
        TinyMirBlock {
            label: "increment",
            statements: &MIR_BLOCK_GRAPH_LOCAL_UPDATE_BRANCH_STEP_STATEMENTS,
            terminator: TinyMirBlockTerminator::BranchLocalI32Positive {
                name: "value",
                then_block: "positive",
                else_block: "non_positive",
            },
        },
        TinyMirBlock {
            label: "positive",
            statements: &[],
            terminator: TinyMirBlockTerminator::ReturnI32(53),
        },
        TinyMirBlock {
            label: "non_positive",
            statements: &[],
            terminator: TinyMirBlockTerminator::ReturnI32(59),
        },
    ];

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_block_graph_local_update_i32_bundle",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let local_update_function = TinyMirBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_local_update_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_LOCAL_UPDATE_I32_SYMBOL,
        params: &[],
        return_type: TinyMirType::I32,
        locals: &MIR_BLOCK_GRAPH_LOCAL_UPDATE_I32_LOCALS,
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_LOCAL_UPDATE_BLOCKS,
    };
    let local_update_branch_function = TinyMirBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_local_update_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_LOCAL_UPDATE_BRANCH_I32_SYMBOL,
        params: &MIR_BLOCK_GRAPH_LOCAL_UPDATE_I32_PARAMS,
        return_type: TinyMirType::I32,
        locals: &MIR_BLOCK_GRAPH_LOCAL_UPDATE_I32_LOCALS,
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_LOCAL_UPDATE_BRANCH_BLOCKS,
    };

    define_tiny_mir_block_graph_exported_function(&mut module, &local_update_function)?;
    define_tiny_mir_block_graph_exported_function(&mut module, &local_update_branch_function)?;

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_mir_block_graph_param_i32_bundle_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    static MIR_BLOCK_GRAPH_PARAM_I32_FUNCTION_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static MIR_BLOCK_GRAPH_PARAM_I32_BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];

    static MIR_BLOCK_GRAPH_PARAM_FORWARD_BLOCKS: [TinyMirParamBlock; 2] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpI32Literal {
                target: "return",
                value: 53,
            },
        },
        TinyMirParamBlock {
            label: "return",
            params: &MIR_BLOCK_GRAPH_PARAM_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamI32(0),
        },
    ];

    static MIR_BLOCK_GRAPH_PARAM_UPDATE_BRANCH_BLOCKS: [TinyMirParamBlock; 5] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "increment",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "increment",
            params: &MIR_BLOCK_GRAPH_PARAM_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "branch",
                param: 0,
                value: 4,
            },
        },
        TinyMirParamBlock {
            label: "branch",
            params: &MIR_BLOCK_GRAPH_PARAM_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32Positive {
                param: 0,
                then_block: "positive",
                else_block: "non_positive",
            },
        },
        TinyMirParamBlock {
            label: "positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(67),
        },
        TinyMirParamBlock {
            label: "non_positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(71),
        },
    ];

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_block_graph_param_i32_bundle",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let param_forward_function = TinyMirParamBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_param_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_PARAM_FORWARD_I32_SYMBOL,
        params: &[],
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_PARAM_FORWARD_BLOCKS,
    };
    let param_update_branch_function = TinyMirParamBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_param_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_PARAM_UPDATE_BRANCH_I32_SYMBOL,
        params: &MIR_BLOCK_GRAPH_PARAM_I32_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_PARAM_UPDATE_BRANCH_BLOCKS,
    };

    let local_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &param_forward_function,
        &local_function_ids,
    )?;
    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &param_update_branch_function,
        &local_function_ids,
    )?;

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_mir_block_graph_param_call_i32_bundle_object(
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    static MIR_BLOCK_GRAPH_PARAM_CALL_I32_FUNCTION_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static MIR_BLOCK_GRAPH_PARAM_CALL_I32_BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];

    static MIR_BLOCK_GRAPH_PARAM_CALL_BLOCKS: [TinyMirParamBlock; 2] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "call",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "call",
            params: &MIR_BLOCK_GRAPH_PARAM_CALL_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamLocalFunctionI32Call {
                function_symbol: MIR_BLOCK_GRAPH_PARAM_CALL_HELPER_I32_SYMBOL,
                param: 0,
            },
        },
    ];

    static MIR_BLOCK_GRAPH_PARAM_CALL_BRANCH_BLOCKS: [TinyMirParamBlock; 4] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "call",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "call",
            params: &MIR_BLOCK_GRAPH_PARAM_CALL_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamLocalFunctionI32CallPositive {
                function_symbol: MIR_BLOCK_GRAPH_PARAM_CALL_HELPER_I32_SYMBOL,
                param: 0,
                then_block: "positive",
                else_block: "non_positive",
            },
        },
        TinyMirParamBlock {
            label: "positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(79),
        },
        TinyMirParamBlock {
            label: "non_positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(83),
        },
    ];

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_block_graph_param_call_i32_bundle",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let helper_mir_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_block_graph_param_call_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_PARAM_CALL_HELPER_I32_SYMBOL,
        params: &MIR_BLOCK_GRAPH_PARAM_CALL_I32_FUNCTION_PARAMS,
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

    let mut local_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    local_function_ids.insert(MIR_BLOCK_GRAPH_PARAM_CALL_HELPER_I32_SYMBOL, helper_function_id);

    let param_call_function = TinyMirParamBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_param_call_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_PARAM_CALL_I32_SYMBOL,
        params: &MIR_BLOCK_GRAPH_PARAM_CALL_I32_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_PARAM_CALL_BLOCKS,
    };
    let param_call_branch_function = TinyMirParamBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_param_call_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_PARAM_CALL_BRANCH_I32_SYMBOL,
        params: &MIR_BLOCK_GRAPH_PARAM_CALL_I32_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_PARAM_CALL_BRANCH_BLOCKS,
    };

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &param_call_function,
        &local_function_ids,
    )?;
    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &param_call_branch_function,
        &local_function_ids,
    )?;

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_mir_block_graph_param_extern_i32_bundle_object(
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    static MIR_BLOCK_GRAPH_PARAM_EXTERN_I32_FUNCTION_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static MIR_BLOCK_GRAPH_PARAM_EXTERN_I32_BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];

    static MIR_BLOCK_GRAPH_PARAM_EXTERN_CALL_BLOCKS: [TinyMirParamBlock; 2] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "extern_call",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "extern_call",
            params: &MIR_BLOCK_GRAPH_PARAM_EXTERN_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32Call {
                function_symbol: HOST_ADD_ONE_I32_SYMBOL,
                param: 0,
            },
        },
    ];

    static MIR_BLOCK_GRAPH_PARAM_EXTERN_CALL_BRANCH_BLOCKS: [TinyMirParamBlock; 4] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "extern_call",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "extern_call",
            params: &MIR_BLOCK_GRAPH_PARAM_EXTERN_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32CallPositive {
                function_symbol: HOST_ADD_ONE_I32_SYMBOL,
                param: 0,
                then_block: "positive",
                else_block: "non_positive",
            },
        },
        TinyMirParamBlock {
            label: "positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(101),
        },
        TinyMirParamBlock {
            label: "non_positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(103),
        },
    ];

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_block_graph_param_extern_i32_bundle",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut host_add_one_signature = module.make_signature();
    host_add_one_signature.params.push(AbiParam::new(types::I32));
    host_add_one_signature.returns.push(AbiParam::new(types::I32));
    let host_add_one_function_id = module.declare_function(
        HOST_ADD_ONE_I32_SYMBOL,
        Linkage::Import,
        &host_add_one_signature,
    )?;

    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(HOST_ADD_ONE_I32_SYMBOL, host_add_one_function_id);

    let param_extern_call_function = TinyMirParamBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_param_extern_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_PARAM_EXTERN_CALL_I32_SYMBOL,
        params: &MIR_BLOCK_GRAPH_PARAM_EXTERN_I32_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_PARAM_EXTERN_CALL_BLOCKS,
    };
    let param_extern_call_branch_function = TinyMirParamBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_param_extern_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_PARAM_EXTERN_CALL_BRANCH_I32_SYMBOL,
        params: &MIR_BLOCK_GRAPH_PARAM_EXTERN_I32_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_PARAM_EXTERN_CALL_BRANCH_BLOCKS,
    };

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &param_extern_call_function,
        &imported_function_ids,
    )?;
    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &param_extern_call_branch_function,
        &imported_function_ids,
    )?;

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_mir_block_graph_param_extern_add_i32_bundle_object(
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    static MIR_BLOCK_GRAPH_PARAM_EXTERN_ADD_I32_FUNCTION_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static MIR_BLOCK_GRAPH_PARAM_EXTERN_ADD_I32_BLOCK_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];

    static MIR_BLOCK_GRAPH_PARAM_EXTERN_ADD_BLOCKS: [TinyMirParamBlock; 2] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "extern_add",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "extern_add",
            params: &MIR_BLOCK_GRAPH_PARAM_EXTERN_ADD_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal {
                function_symbol: HOST_ADD_I32_SYMBOL,
                param: 0,
                value: 5,
            },
        },
    ];

    static MIR_BLOCK_GRAPH_PARAM_EXTERN_ADD_BRANCH_BLOCKS: [TinyMirParamBlock; 4] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "extern_add",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "extern_add",
            params: &MIR_BLOCK_GRAPH_PARAM_EXTERN_ADD_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32CallI32LiteralPositive {
                function_symbol: HOST_ADD_I32_SYMBOL,
                param: 0,
                value: -2,
                then_block: "positive",
                else_block: "non_positive",
            },
        },
        TinyMirParamBlock {
            label: "positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(107),
        },
        TinyMirParamBlock {
            label: "non_positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(109),
        },
    ];

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_block_graph_param_extern_add_i32_bundle",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut host_add_signature = module.make_signature();
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.returns.push(AbiParam::new(types::I32));
    let host_add_function_id = module.declare_function(
        HOST_ADD_I32_SYMBOL,
        Linkage::Import,
        &host_add_signature,
    )?;

    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(HOST_ADD_I32_SYMBOL, host_add_function_id);

    let param_extern_add_function = TinyMirParamBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_param_extern_add_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_PARAM_EXTERN_ADD_I32_SYMBOL,
        params: &MIR_BLOCK_GRAPH_PARAM_EXTERN_ADD_I32_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_PARAM_EXTERN_ADD_BLOCKS,
    };
    let param_extern_add_branch_function = TinyMirParamBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_param_extern_add_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_PARAM_EXTERN_ADD_BRANCH_I32_SYMBOL,
        params: &MIR_BLOCK_GRAPH_PARAM_EXTERN_ADD_I32_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_PARAM_EXTERN_ADD_BRANCH_BLOCKS,
    };

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &param_extern_add_function,
        &imported_function_ids,
    )?;
    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &param_extern_add_branch_function,
        &imported_function_ids,
    )?;

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}


fn emit_mir_block_graph_param_extern_predicate_i32_bundle_object(
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    static MIR_BLOCK_GRAPH_PARAM_EXTERN_PREDICATE_I32_FUNCTION_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static MIR_BLOCK_GRAPH_PARAM_EXTERN_PREDICATE_I32_BLOCK_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];

    static MIR_BLOCK_GRAPH_PARAM_EXTERN_PREDICATE_BLOCKS: [TinyMirParamBlock; 4] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "predicate",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "predicate",
            params: &MIR_BLOCK_GRAPH_PARAM_EXTERN_PREDICATE_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32Predicate {
                function_symbol: HOST_IS_POSITIVE_I32_SYMBOL,
                param: 0,
                then_block: "positive",
                else_block: "non_positive",
            },
        },
        TinyMirParamBlock {
            label: "positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(149),
        },
        TinyMirParamBlock {
            label: "non_positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(151),
        },
    ];

    static MIR_BLOCK_GRAPH_PARAM_EXTERN_PREDICATE_UPDATE_BRANCH_BLOCKS: [TinyMirParamBlock; 5] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "adjust",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "adjust",
            params: &MIR_BLOCK_GRAPH_PARAM_EXTERN_PREDICATE_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "predicate",
                param: 0,
                value: -4,
            },
        },
        TinyMirParamBlock {
            label: "predicate",
            params: &MIR_BLOCK_GRAPH_PARAM_EXTERN_PREDICATE_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32Predicate {
                function_symbol: HOST_IS_POSITIVE_I32_SYMBOL,
                param: 0,
                then_block: "positive",
                else_block: "non_positive",
            },
        },
        TinyMirParamBlock {
            label: "positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(157),
        },
        TinyMirParamBlock {
            label: "non_positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(163),
        },
    ];

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_block_graph_param_extern_predicate_i32_bundle",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut host_predicate_signature = module.make_signature();
    host_predicate_signature.params.push(AbiParam::new(types::I32));
    host_predicate_signature.returns.push(AbiParam::new(types::I32));
    let host_predicate_function_id = module.declare_function(
        HOST_IS_POSITIVE_I32_SYMBOL,
        Linkage::Import,
        &host_predicate_signature,
    )?;

    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(HOST_IS_POSITIVE_I32_SYMBOL, host_predicate_function_id);

    let param_extern_predicate_function = TinyMirParamBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_param_extern_predicate_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_PARAM_EXTERN_PREDICATE_I32_SYMBOL,
        params: &MIR_BLOCK_GRAPH_PARAM_EXTERN_PREDICATE_I32_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_PARAM_EXTERN_PREDICATE_BLOCKS,
    };
    let param_extern_predicate_update_branch_function = TinyMirParamBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_param_extern_predicate_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_PARAM_EXTERN_PREDICATE_UPDATE_BRANCH_I32_SYMBOL,
        params: &MIR_BLOCK_GRAPH_PARAM_EXTERN_PREDICATE_I32_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_PARAM_EXTERN_PREDICATE_UPDATE_BRANCH_BLOCKS,
    };

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &param_extern_predicate_function,
        &imported_function_ids,
    )?;
    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &param_extern_predicate_update_branch_function,
        &imported_function_ids,
    )?;

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_mir_block_graph_param_merge_i32_bundle_object(
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    static MIR_BLOCK_GRAPH_PARAM_MERGE_I32_FUNCTION_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static MIR_BLOCK_GRAPH_PARAM_MERGE_I32_BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];

    static MIR_BLOCK_GRAPH_PARAM_MERGE_BLOCKS: [TinyMirParamBlock; 4] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "then_value",
                then_value: 173,
                else_block: "else_value",
                else_value: 179,
            },
        },
        TinyMirParamBlock {
            label: "then_value",
            params: &MIR_BLOCK_GRAPH_PARAM_MERGE_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 0,
            },
        },
        TinyMirParamBlock {
            label: "else_value",
            params: &MIR_BLOCK_GRAPH_PARAM_MERGE_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 0,
            },
        },
        TinyMirParamBlock {
            label: "join",
            params: &MIR_BLOCK_GRAPH_PARAM_MERGE_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamI32(0),
        },
    ];

    static MIR_BLOCK_GRAPH_PARAM_MERGE_UPDATE_BLOCKS: [TinyMirParamBlock; 6] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "adjust",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "adjust",
            params: &MIR_BLOCK_GRAPH_PARAM_MERGE_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "branch",
                param: 0,
                value: 4,
            },
        },
        TinyMirParamBlock {
            label: "branch",
            params: &MIR_BLOCK_GRAPH_PARAM_MERGE_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "then_value",
                then_value: 181,
                else_block: "else_value",
                else_value: 191,
            },
        },
        TinyMirParamBlock {
            label: "then_value",
            params: &MIR_BLOCK_GRAPH_PARAM_MERGE_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 0,
            },
        },
        TinyMirParamBlock {
            label: "else_value",
            params: &MIR_BLOCK_GRAPH_PARAM_MERGE_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 0,
            },
        },
        TinyMirParamBlock {
            label: "join",
            params: &MIR_BLOCK_GRAPH_PARAM_MERGE_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamI32(0),
        },
    ];

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_block_graph_param_merge_i32_bundle",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);
    let local_function_ids: HashMap<&'static str, FuncId> = HashMap::new();

    let param_merge_function = TinyMirParamBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_param_merge_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_PARAM_MERGE_I32_SYMBOL,
        params: &MIR_BLOCK_GRAPH_PARAM_MERGE_I32_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_PARAM_MERGE_BLOCKS,
    };
    let param_merge_update_function = TinyMirParamBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_param_merge_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_PARAM_MERGE_UPDATE_I32_SYMBOL,
        params: &MIR_BLOCK_GRAPH_PARAM_MERGE_I32_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_PARAM_MERGE_UPDATE_BLOCKS,
    };

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &param_merge_function,
        &local_function_ids,
    )?;
    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &param_merge_update_function,
        &local_function_ids,
    )?;

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_mir_block_graph_param_merge_call_i32_bundle_object(
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    static MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_I32_FUNCTION_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_I32_BLOCK_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];

    static MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_BLOCKS: [TinyMirParamBlock; 4] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "then_value",
                then_value: 197,
                else_block: "else_value",
                else_value: 199,
            },
        },
        TinyMirParamBlock {
            label: "then_value",
            params: &MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 0,
            },
        },
        TinyMirParamBlock {
            label: "else_value",
            params: &MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 0,
            },
        },
        TinyMirParamBlock {
            label: "join",
            params: &MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamLocalFunctionI32Call {
                function_symbol: MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_HELPER_I32_SYMBOL,
                param: 0,
            },
        },
    ];

    static MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_BRANCH_BLOCKS: [TinyMirParamBlock; 8] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "adjust",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "adjust",
            params: &MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "branch",
                param: 0,
                value: -2,
            },
        },
        TinyMirParamBlock {
            label: "branch",
            params: &MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "then_value",
                then_value: 11,
                else_block: "else_value",
                else_value: -2,
            },
        },
        TinyMirParamBlock {
            label: "then_value",
            params: &MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 0,
            },
        },
        TinyMirParamBlock {
            label: "else_value",
            params: &MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 0,
            },
        },
        TinyMirParamBlock {
            label: "join",
            params: &MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_I32_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamLocalFunctionI32CallPositive {
                function_symbol: MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_HELPER_I32_SYMBOL,
                param: 0,
                then_block: "positive",
                else_block: "non_positive",
            },
        },
        TinyMirParamBlock {
            label: "positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(227),
        },
        TinyMirParamBlock {
            label: "non_positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(229),
        },
    ];

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_block_graph_param_merge_call_i32_bundle",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let helper_mir_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_block_graph_param_merge_call_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_HELPER_I32_SYMBOL,
        params: &MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_I32_FUNCTION_PARAMS,
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

    let mut local_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    local_function_ids.insert(
        MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_HELPER_I32_SYMBOL,
        helper_function_id,
    );

    let param_merge_call_function = TinyMirParamBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_param_merge_call_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_I32_SYMBOL,
        params: &MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_I32_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_BLOCKS,
    };
    let param_merge_call_branch_function = TinyMirParamBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_param_merge_call_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_BRANCH_I32_SYMBOL,
        params: &MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_I32_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_BRANCH_BLOCKS,
    };

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &param_merge_call_function,
        &local_function_ids,
    )?;
    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &param_merge_call_branch_function,
        &local_function_ids,
    )?;

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
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

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
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

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
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

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
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

fn emit_mir_extern_predicate_branch_i32_object(output_path: &Path) -> Result<(), Box<dyn Error>> {
    static MIR_EXTERN_PREDICATE_BRANCH_I32_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_extern_predicate_branch_i32",
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

    let caller_mir_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_extern_predicate_branch_i32",
        symbol: MIR_EXTERN_PREDICATE_BRANCH_I32_SYMBOL,
        params: &MIR_EXTERN_PREDICATE_BRANCH_I32_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::BranchImportedFunctionI32Predicate {
            function_symbol: HOST_IS_POSITIVE_I32_SYMBOL,
            arg_param: 0,
            then_return: 11,
            else_return: 13,
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
    caller_function_refs.insert(HOST_IS_POSITIVE_I32_SYMBOL, host_function_ref);
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

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder =
        ObjectBuilder::new(isa, "gust_cranelift_add_i32", default_libcall_names())?;
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

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_call_helper_i32",
        default_libcall_names(),
    )?;
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
    let call_inst = caller_builder
        .ins()
        .call(helper_function_ref, &[argument_value]);
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

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_extern_call_i32",
        default_libcall_names(),
    )?;
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
    let call_inst = caller_builder
        .ins()
        .call(host_function_ref, &[argument_value]);
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

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_extern_add_i32",
        default_libcall_names(),
    )?;
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

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
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
    let call_inst = caller_builder
        .ins()
        .call(host_function_ref, &[argument_value]);
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

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;

    let object_builder =
        ObjectBuilder::new(isa, mir_function.object_name, default_libcall_names())?;
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

fn define_tiny_mir_exported_function(
    module: &mut ObjectModule,
    mir_function: &TinyMirFunction,
    local_function_refs: &HashMap<&'static str, FuncRef>,
) -> Result<(), Box<dyn Error>> {
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
    build_tiny_mir_body(&mut builder, mir_function, local_function_refs)?;
    builder.seal_all_blocks();
    builder.finalize();

    module.define_function(function_id, &mut context)?;
    module.clear_context(&mut context);
    Ok(())
}

fn define_tiny_mir_param_block_graph_exported_function(
    module: &mut ObjectModule,
    mir_function: &TinyMirParamBlockFunction,
    local_function_ids: &HashMap<&'static str, FuncId>,
) -> Result<(), Box<dyn Error>> {
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
    let mut local_function_refs: HashMap<&'static str, FuncRef> = HashMap::new();
    for (symbol, function_id) in local_function_ids {
        let function_ref = module.declare_func_in_func(*function_id, builder.func);
        local_function_refs.insert(*symbol, function_ref);
    }
    build_tiny_mir_param_block_graph_body(&mut builder, mir_function, &local_function_refs)?;
    builder.seal_all_blocks();
    builder.finalize();

    module.define_function(function_id, &mut context)?;
    module.clear_context(&mut context);
    Ok(())
}

fn build_tiny_mir_param_block_graph_body(
    builder: &mut FunctionBuilder<'_>,
    mir_function: &TinyMirParamBlockFunction,
    local_function_refs: &HashMap<&'static str, FuncRef>,
) -> Result<(), Box<dyn Error>> {
    let mut cranelift_blocks: HashMap<&'static str, Block> = HashMap::new();
    for block in mir_function.blocks {
        let cranelift_block = builder.create_block();
        if cranelift_blocks
            .insert(block.label, cranelift_block)
            .is_some()
        {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!("duplicate tiny MIR param block label: {}", block.label),
            )
            .into());
        }

        for param in block.params {
            builder.append_block_param(cranelift_block, tiny_mir_type_to_cranelift_type(*param));
        }
    }

    let entry_block = *cranelift_blocks
        .get(mir_function.entry_block)
        .ok_or_else(|| {
            IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "unknown tiny MIR param block entry block: {}",
                    mir_function.entry_block
                ),
            )
        })?;
    builder.append_block_params_for_function_params(entry_block);

    for block in mir_function.blocks {
        let current_block = *cranelift_blocks.get(block.label).ok_or_else(|| {
            IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "unknown tiny MIR param block during lowering: {}",
                    block.label
                ),
            )
        })?;
        builder.switch_to_block(current_block);

        match block.terminator {
            TinyMirParamBlockTerminator::JumpI32Literal { target, value } => {
                let target_block = *cranelift_blocks.get(target).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param jump target block: {target}"),
                    )
                })?;
                let jump_value = builder.ins().iconst(types::I32, i64::from(value));
                let jump_arguments = [BlockArg::Value(jump_value)];
                builder.ins().jump(target_block, &jump_arguments);
            }
            TinyMirParamBlockTerminator::JumpFunctionParamI32 { target, param } => {
                let target_block = *cranelift_blocks.get(target).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param function jump target block: {target}"),
                    )
                })?;
                let argument_value = {
                    let entry_params = builder.block_params(entry_block);
                    entry_params.get(param).copied().ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR param function param index: {param}"),
                        )
                    })?
                };
                let jump_arguments = [BlockArg::Value(argument_value)];
                builder.ins().jump(target_block, &jump_arguments);
            }
            TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target,
                param,
                value,
            } => {
                let target_block = *cranelift_blocks.get(target).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param add jump target block: {target}"),
                    )
                })?;
                let block_value = {
                    let block_params = builder.block_params(current_block);
                    block_params.get(param).copied().ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR block param add index: {param}"),
                        )
                    })?
                };
                let literal_value = builder.ins().iconst(types::I32, i64::from(value));
                let updated_value = builder.ins().iadd(block_value, literal_value);
                let jump_arguments = [BlockArg::Value(updated_value)];
                builder.ins().jump(target_block, &jump_arguments);
            }
            TinyMirParamBlockTerminator::BranchBlockParamI32Positive {
                param,
                then_block,
                else_block,
            } => {
                let condition_value = {
                    let block_params = builder.block_params(current_block);
                    block_params.get(param).copied().ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR branch block param index: {param}"),
                        )
                    })?
                };
                let then_cranelift_block = *cranelift_blocks.get(then_block).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param then block: {then_block}"),
                    )
                })?;
                let else_cranelift_block = *cranelift_blocks.get(else_block).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param else block: {else_block}"),
                    )
                })?;
                let branch_condition =
                    builder
                        .ins()
                        .icmp_imm(IntCC::SignedGreaterThan, condition_value, 0);
                builder.ins().brif(
                    branch_condition,
                    then_cranelift_block,
                    &[],
                    else_cranelift_block,
                    &[],
                );
            }
            TinyMirParamBlockTerminator::ReturnBlockParamLocalFunctionI32Call {
                function_symbol,
                param,
            } => {
                let argument_value = {
                    let block_params = builder.block_params(current_block);
                    block_params.get(param).copied().ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR param call return block param index: {param}"),
                        )
                    })?
                };
                let function_ref = *local_function_refs.get(function_symbol).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param block local function: {function_symbol}"),
                    )
                })?;
                let call_inst = builder.ins().call(function_ref, &[argument_value]);
                let return_value = builder.inst_results(call_inst)[0];
                builder.ins().return_(&[return_value]);
            }
            TinyMirParamBlockTerminator::BranchBlockParamLocalFunctionI32CallPositive {
                function_symbol,
                param,
                then_block,
                else_block,
            } => {
                let argument_value = {
                    let block_params = builder.block_params(current_block);
                    block_params.get(param).copied().ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR param call branch block param index: {param}"),
                        )
                    })?
                };
                let function_ref = *local_function_refs.get(function_symbol).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param block branch local function: {function_symbol}"),
                    )
                })?;
                let then_cranelift_block = *cranelift_blocks.get(then_block).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param call then block: {then_block}"),
                    )
                })?;
                let else_cranelift_block = *cranelift_blocks.get(else_block).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param call else block: {else_block}"),
                    )
                })?;
                let call_inst = builder.ins().call(function_ref, &[argument_value]);
                let call_value = builder.inst_results(call_inst)[0];
                let branch_condition =
                    builder
                        .ins()
                        .icmp_imm(IntCC::SignedGreaterThan, call_value, 0);
                builder.ins().brif(
                    branch_condition,
                    then_cranelift_block,
                    &[],
                    else_cranelift_block,
                    &[],
                );
            }
            TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32Call {
                function_symbol,
                param,
            } => {
                let argument_value = {
                    let block_params = builder.block_params(current_block);
                    block_params.get(param).copied().ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR param extern call return block param index: {param}"),
                        )
                    })?
                };
                let function_ref = *local_function_refs.get(function_symbol).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param block imported function: {function_symbol}"),
                    )
                })?;
                let call_inst = builder.ins().call(function_ref, &[argument_value]);
                let return_value = builder.inst_results(call_inst)[0];
                builder.ins().return_(&[return_value]);
            }
            TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32CallPositive {
                function_symbol,
                param,
                then_block,
                else_block,
            } => {
                let argument_value = {
                    let block_params = builder.block_params(current_block);
                    block_params.get(param).copied().ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR param extern call branch block param index: {param}"),
                        )
                    })?
                };
                let function_ref = *local_function_refs.get(function_symbol).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param block branch imported function: {function_symbol}"),
                    )
                })?;
                let then_cranelift_block = *cranelift_blocks.get(then_block).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param extern call then block: {then_block}"),
                    )
                })?;
                let else_cranelift_block = *cranelift_blocks.get(else_block).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param extern call else block: {else_block}"),
                    )
                })?;
                let call_inst = builder.ins().call(function_ref, &[argument_value]);
                let call_value = builder.inst_results(call_inst)[0];
                let branch_condition =
                    builder
                        .ins()
                        .icmp_imm(IntCC::SignedGreaterThan, call_value, 0);
                builder.ins().brif(
                    branch_condition,
                    then_cranelift_block,
                    &[],
                    else_cranelift_block,
                    &[],
                );
            }
            TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal {
                function_symbol,
                param,
                value,
            } => {
                let argument_value = {
                    let block_params = builder.block_params(current_block);
                    block_params.get(param).copied().ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR param extern add return block param index: {param}"),
                        )
                    })?
                };
                let function_ref = *local_function_refs.get(function_symbol).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param block imported add function: {function_symbol}"),
                    )
                })?;
                let literal_value = builder.ins().iconst(types::I32, i64::from(value));
                let call_inst = builder.ins().call(function_ref, &[argument_value, literal_value]);
                let return_value = builder.inst_results(call_inst)[0];
                builder.ins().return_(&[return_value]);
            }
            TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32CallI32LiteralPositive {
                function_symbol,
                param,
                value,
                then_block,
                else_block,
            } => {
                let argument_value = {
                    let block_params = builder.block_params(current_block);
                    block_params.get(param).copied().ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR param extern add branch block param index: {param}"),
                        )
                    })?
                };
                let function_ref = *local_function_refs.get(function_symbol).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param block branch imported add function: {function_symbol}"),
                    )
                })?;
                let then_cranelift_block = *cranelift_blocks.get(then_block).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param extern add then block: {then_block}"),
                    )
                })?;
                let else_cranelift_block = *cranelift_blocks.get(else_block).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param extern add else block: {else_block}"),
                    )
                })?;
                let literal_value = builder.ins().iconst(types::I32, i64::from(value));
                let call_inst = builder.ins().call(function_ref, &[argument_value, literal_value]);
                let call_value = builder.inst_results(call_inst)[0];
                let branch_condition =
                    builder
                        .ins()
                        .icmp_imm(IntCC::SignedGreaterThan, call_value, 0);
                builder.ins().brif(
                    branch_condition,
                    then_cranelift_block,
                    &[],
                    else_cranelift_block,
                    &[],
                );
            }
            TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32Predicate {
                function_symbol,
                param,
                then_block,
                else_block,
            } => {
                let argument_value = {
                    let block_params = builder.block_params(current_block);
                    block_params.get(param).copied().ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR param extern predicate branch block param index: {param}"),
                        )
                    })?
                };
                let function_ref = *local_function_refs.get(function_symbol).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param block branch imported predicate function: {function_symbol}"),
                    )
                })?;
                let then_cranelift_block = *cranelift_blocks.get(then_block).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param extern predicate then block: {then_block}"),
                    )
                })?;
                let else_cranelift_block = *cranelift_blocks.get(else_block).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param extern predicate else block: {else_block}"),
                    )
                })?;
                let call_inst = builder.ins().call(function_ref, &[argument_value]);
                let predicate_value = builder.inst_results(call_inst)[0];
                let branch_condition = builder.ins().icmp_imm(IntCC::NotEqual, predicate_value, 0);
                builder.ins().brif(
                    branch_condition,
                    then_cranelift_block,
                    &[],
                    else_cranelift_block,
                    &[],
                );
            }
            TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param,
                then_block,
                then_value,
                else_block,
                else_value,
            } => {
                let condition_value = {
                    let block_params = builder.block_params(current_block);
                    block_params.get(param).copied().ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR param merge branch block param index: {param}"),
                        )
                    })?
                };
                let then_cranelift_block = *cranelift_blocks.get(then_block).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param merge then block: {then_block}"),
                    )
                })?;
                let else_cranelift_block = *cranelift_blocks.get(else_block).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param merge else block: {else_block}"),
                    )
                })?;
                let branch_condition =
                    builder
                        .ins()
                        .icmp_imm(IntCC::SignedGreaterThan, condition_value, 0);
                let then_argument = builder.ins().iconst(types::I32, i64::from(then_value));
                let else_argument = builder.ins().iconst(types::I32, i64::from(else_value));
                let then_args = [BlockArg::Value(then_argument)];
                let else_args = [BlockArg::Value(else_argument)];
                builder.ins().brif(
                    branch_condition,
                    then_cranelift_block,
                    &then_args,
                    else_cranelift_block,
                    &else_args,
                );
            }
            TinyMirParamBlockTerminator::ReturnI32(value) => {
                let return_value = builder.ins().iconst(types::I32, i64::from(value));
                builder.ins().return_(&[return_value]);
            }
            TinyMirParamBlockTerminator::ReturnBlockParamI32(param) => {
                let return_value = {
                    let block_params = builder.block_params(current_block);
                    block_params.get(param).copied().ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR return block param index: {param}"),
                        )
                    })?
                };
                builder.ins().return_(&[return_value]);
            }
        }
    }

    Ok(())
}

fn define_tiny_mir_block_graph_exported_function(
    module: &mut ObjectModule,
    mir_function: &TinyMirBlockFunction,
) -> Result<(), Box<dyn Error>> {
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
    build_tiny_mir_block_graph_body(&mut builder, mir_function)?;
    builder.seal_all_blocks();
    builder.finalize();

    module.define_function(function_id, &mut context)?;
    module.clear_context(&mut context);
    Ok(())
}

fn build_tiny_mir_block_graph_body(
    builder: &mut FunctionBuilder<'_>,
    mir_function: &TinyMirBlockFunction,
) -> Result<(), Box<dyn Error>> {
    let mut cranelift_blocks: HashMap<&'static str, Block> = HashMap::new();
    for block in mir_function.blocks {
        let cranelift_block = builder.create_block();
        if cranelift_blocks
            .insert(block.label, cranelift_block)
            .is_some()
        {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!("duplicate tiny MIR block label: {}", block.label),
            )
            .into());
        }
    }

    let entry_block = *cranelift_blocks
        .get(mir_function.entry_block)
        .ok_or_else(|| {
            IoError::new(
                ErrorKind::InvalidInput,
                format!("unknown tiny MIR entry block: {}", mir_function.entry_block),
            )
        })?;
    builder.append_block_params_for_function_params(entry_block);

    let mut local_slots: HashMap<&'static str, Variable> = HashMap::new();
    for local in mir_function.locals {
        let slot = builder.declare_var(tiny_mir_type_to_cranelift_type(local.ty));
        if local_slots.insert(local.name, slot).is_some() {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!("duplicate tiny MIR block graph local: {}", local.name),
            )
            .into());
        }
    }

    for block in mir_function.blocks {
        let current_block = *cranelift_blocks.get(block.label).ok_or_else(|| {
            IoError::new(
                ErrorKind::InvalidInput,
                format!("unknown tiny MIR block during lowering: {}", block.label),
            )
        })?;
        builder.switch_to_block(current_block);

        for statement in block.statements {
            match *statement {
                TinyMirBlockStatement::LocalI32Set { name, value } => {
                    let slot = *local_slots.get(name).ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR block graph local set target: {name}"),
                        )
                    })?;
                    let literal_value = builder.ins().iconst(types::I32, i64::from(value));
                    builder.def_var(slot, literal_value);
                }
                TinyMirBlockStatement::LocalI32SetParam { name, param } => {
                    let slot = *local_slots.get(name).ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR block graph param set target: {name}"),
                        )
                    })?;
                    let param_value = {
                        let block_params = builder.block_params(entry_block);
                        block_params.get(param).copied().ok_or_else(|| {
                            IoError::new(
                                ErrorKind::InvalidInput,
                                format!("unknown tiny MIR block graph local param index: {param}"),
                            )
                        })?
                    };
                    builder.def_var(slot, param_value);
                }
                TinyMirBlockStatement::LocalI32AddI32Literal { name, value } => {
                    let slot = *local_slots.get(name).ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR block graph add-literal local: {name}"),
                        )
                    })?;
                    let current_value = builder.use_var(slot);
                    let literal_value = builder.ins().iconst(types::I32, i64::from(value));
                    let updated_value = builder.ins().iadd(current_value, literal_value);
                    builder.def_var(slot, updated_value);
                }
            }
        }

        match block.terminator {
            TinyMirBlockTerminator::Jump { target } => {
                let target_block = *cranelift_blocks.get(target).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR jump target block: {target}"),
                    )
                })?;
                builder.ins().jump(target_block, &[]);
            }
            TinyMirBlockTerminator::BranchParamI32Positive {
                param,
                then_block,
                else_block,
            } => {
                let condition_value = {
                    let block_params = builder.block_params(entry_block);
                    block_params.get(param).copied().ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR block branch param index: {param}"),
                        )
                    })?
                };
                let then_cranelift_block = *cranelift_blocks.get(then_block).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR then block: {then_block}"),
                    )
                })?;
                let else_cranelift_block = *cranelift_blocks.get(else_block).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR else block: {else_block}"),
                    )
                })?;
                let branch_condition =
                    builder
                        .ins()
                        .icmp_imm(IntCC::SignedGreaterThan, condition_value, 0);
                builder.ins().brif(
                    branch_condition,
                    then_cranelift_block,
                    &[],
                    else_cranelift_block,
                    &[],
                );
            }
            TinyMirBlockTerminator::BranchLocalI32Positive {
                name,
                then_block,
                else_block,
            } => {
                let slot = *local_slots.get(name).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR block graph branch local: {name}"),
                    )
                })?;
                let condition_value = builder.use_var(slot);
                let then_cranelift_block = *cranelift_blocks.get(then_block).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR then block: {then_block}"),
                    )
                })?;
                let else_cranelift_block = *cranelift_blocks.get(else_block).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR else block: {else_block}"),
                    )
                })?;
                let branch_condition =
                    builder
                        .ins()
                        .icmp_imm(IntCC::SignedGreaterThan, condition_value, 0);
                builder.ins().brif(
                    branch_condition,
                    then_cranelift_block,
                    &[],
                    else_cranelift_block,
                    &[],
                );
            }
            TinyMirBlockTerminator::ReturnI32(value) => {
                let return_value = builder.ins().iconst(types::I32, i64::from(value));
                builder.ins().return_(&[return_value]);
            }
            TinyMirBlockTerminator::ReturnLocalI32(name) => {
                let slot = *local_slots.get(name).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR block graph return local: {name}"),
                    )
                })?;
                let return_value = builder.use_var(slot);
                builder.ins().return_(&[return_value]);
            }
        }
    }

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
            let branch_condition = builder.ins().icmp_imm(IntCC::NotEqual, condition_value, 0);
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
        TinyMirTerminator::ReturnParamI32Sub {
            lhs_param,
            rhs_param,
        } => {
            let block_params = builder.block_params(entry_block);
            let lhs = block_params.get(lhs_param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR sub lhs param index: {lhs_param}"),
                )
            })?;
            let rhs = block_params.get(rhs_param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR sub rhs param index: {rhs_param}"),
                )
            })?;
            let difference = builder.ins().isub(lhs, rhs);
            builder.ins().return_(&[difference]);
        }
        TinyMirTerminator::ReturnParamI32Mul {
            lhs_param,
            rhs_param,
        } => {
            let block_params = builder.block_params(entry_block);
            let lhs = block_params.get(lhs_param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR mul lhs param index: {lhs_param}"),
                )
            })?;
            let rhs = block_params.get(rhs_param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR mul rhs param index: {rhs_param}"),
                )
            })?;
            let product = builder.ins().imul(lhs, rhs);
            builder.ins().return_(&[product]);
        }
        TinyMirTerminator::ReturnParamI32EqPredicate {
            lhs_param,
            rhs_param,
        } => {
            let block_params = builder.block_params(entry_block);
            let lhs = block_params.get(lhs_param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR eq lhs param index: {lhs_param}"),
                )
            })?;
            let rhs = block_params.get(rhs_param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR eq rhs param index: {rhs_param}"),
                )
            })?;
            let branch_condition = builder.ins().icmp(IntCC::Equal, lhs, rhs);
            let then_block = builder.create_block();
            let else_block = builder.create_block();
            builder
                .ins()
                .brif(branch_condition, then_block, &[], else_block, &[]);

            builder.switch_to_block(then_block);
            let true_value = builder.ins().iconst(types::I32, 1);
            builder.ins().return_(&[true_value]);

            builder.switch_to_block(else_block);
            let false_value = builder.ins().iconst(types::I32, 0);
            builder.ins().return_(&[false_value]);
        }
        TinyMirTerminator::ReturnParamI32SignedGreaterThanPredicate {
            lhs_param,
            rhs_param,
        } => {
            let block_params = builder.block_params(entry_block);
            let lhs = block_params.get(lhs_param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR signed-greater-than lhs param index: {lhs_param}"),
                )
            })?;
            let rhs = block_params.get(rhs_param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR signed-greater-than rhs param index: {rhs_param}"),
                )
            })?;
            let branch_condition = builder.ins().icmp(IntCC::SignedGreaterThan, lhs, rhs);
            let then_block = builder.create_block();
            let else_block = builder.create_block();
            builder
                .ins()
                .brif(branch_condition, then_block, &[], else_block, &[]);

            builder.switch_to_block(then_block);
            let true_value = builder.ins().iconst(types::I32, 1);
            builder.ins().return_(&[true_value]);

            builder.switch_to_block(else_block);
            let false_value = builder.ins().iconst(types::I32, 0);
            builder.ins().return_(&[false_value]);
        }
        TinyMirTerminator::BranchParamI32Eq {
            lhs_param,
            rhs_param,
            then_return,
            else_return,
        } => {
            let block_params = builder.block_params(entry_block);
            let lhs = block_params.get(lhs_param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR eq-branch lhs param index: {lhs_param}"),
                )
            })?;
            let rhs = block_params.get(rhs_param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR eq-branch rhs param index: {rhs_param}"),
                )
            })?;
            let branch_condition = builder.ins().icmp(IntCC::Equal, lhs, rhs);
            let then_block = builder.create_block();
            let else_block = builder.create_block();
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
        TinyMirTerminator::BranchParamI32SignedGreaterThan {
            lhs_param,
            rhs_param,
            then_return,
            else_return,
        } => {
            let block_params = builder.block_params(entry_block);
            let lhs = block_params.get(lhs_param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "unknown tiny MIR signed-greater-than-branch lhs param index: {lhs_param}"
                    ),
                )
            })?;
            let rhs = block_params.get(rhs_param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "unknown tiny MIR signed-greater-than-branch rhs param index: {rhs_param}"
                    ),
                )
            })?;
            let branch_condition = builder.ins().icmp(IntCC::SignedGreaterThan, lhs, rhs);
            let then_block = builder.create_block();
            let else_block = builder.create_block();
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
        TinyMirTerminator::BranchImportedFunctionI32Predicate {
            function_symbol,
            arg_param,
            then_return,
            else_return,
        } => {
            let block_params = builder.block_params(entry_block);
            let argument_value = block_params.get(arg_param).copied().ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR imported predicate arg param index: {arg_param}"),
                )
            })?;
            let function_ref = *local_function_refs.get(function_symbol).ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown tiny MIR imported predicate function: {function_symbol}"),
                )
            })?;
            let call_inst = builder.ins().call(function_ref, &[argument_value]);
            let predicate_value = builder.inst_results(call_inst)[0];
            let branch_condition = builder.ins().icmp_imm(IntCC::NotEqual, predicate_value, 0);
            let then_block = builder.create_block();
            let else_block = builder.create_block();
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
            let branch_condition =
                builder
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

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
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
