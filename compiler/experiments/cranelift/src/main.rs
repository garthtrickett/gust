use std::collections::{HashMap, HashSet, VecDeque};
use std::env;
use std::error::Error;
use std::fs;
use std::io::{Error as IoError, ErrorKind};
use std::path::Path;

use cranelift_codegen::ir::instructions::BlockArg;
use cranelift_codegen::ir::{AbiParam, Block, FuncRef, InstBuilder, Type, condcodes::IntCC, types};
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
const COMPILER_MIR_INGESTED_RETURN_INT_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_return_int";
const COMPILER_MIR_TO_CRANELIFT_RETURN_INT_TRANSLATOR_SYMBOL: &str =
    "tiny_native_backend_mir_to_cranelift_return_int_translator";
const COMPILER_MIR_TO_CRANELIFT_LOCAL_BINDING_READ_TRANSLATOR_SYMBOL: &str =
    "tiny_native_backend_mir_to_cranelift_local_binding_read_translator";
const COMPILER_MIR_TO_CRANELIFT_CONDITIONAL_BRANCH_TRANSLATOR_SYMBOL: &str =
    "tiny_native_backend_mir_to_cranelift_conditional_branch_translator";
const COMPILER_MIR_TO_CRANELIFT_BLOCK_JUMP_TRANSLATOR_SYMBOL: &str =
    "tiny_native_backend_mir_to_cranelift_block_jump_translator";
const COMPILER_MIR_TO_CRANELIFT_PROVENANCE_METADATA_TRANSLATOR_SYMBOL: &str =
    "tiny_native_backend_mir_to_cranelift_provenance_metadata_translator";
const COMPILER_MIR_TO_CRANELIFT_RESOURCE_METADATA_TRANSLATOR_SYMBOL: &str =
    "tiny_native_backend_mir_to_cranelift_resource_metadata_translator";
const COMPILER_MIR_TO_CRANELIFT_NATIVE_BOUNDARY_METADATA_TRANSLATOR_SYMBOL: &str =
    "tiny_native_backend_mir_to_cranelift_native_boundary_metadata_translator";
const COMPILER_MIR_TO_CRANELIFT_ADD_I32_TRANSLATOR_SYMBOL: &str =
    "tiny_native_backend_mir_to_cranelift_add_i32_translator";
const COMPILER_MIR_TO_CRANELIFT_POSITIVE_I32_BRANCH_TRANSLATOR_SYMBOL: &str =
    "tiny_native_backend_mir_to_cranelift_positive_i32_branch_translator";
const COMPILER_MIR_TO_CRANELIFT_BLOCK_LOCAL_BRANCH_JOIN_TRANSLATOR_SYMBOL: &str =
    "tiny_native_backend_mir_to_cranelift_block_local_branch_join_translator";
const COMPILER_MIR_TO_CRANELIFT_BLOCK_PARAM_UPDATE_BRANCH_TRANSLATOR_SYMBOL: &str =
    "tiny_native_backend_mir_to_cranelift_block_param_update_branch_translator";
const COMPILER_MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_UPDATE_BRANCH_TRANSLATOR_SYMBOL: &str =
    "tiny_native_backend_mir_to_cranelift_block_param_merge_update_branch_translator";
const COMPILER_MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_TRANSLATOR_SYMBOL: &str =
    "tiny_native_backend_mir_to_cranelift_block_param_merge_imported_call_return_translator";
const COMPILER_MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_TRANSLATOR_SYMBOL: &str =
    "tiny_native_backend_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator";
const COMPILER_MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_TRANSLATOR_SYMBOL: &str =
    "tiny_native_backend_mir_to_cranelift_block_param_merge_arm_update_imported_call_branch_translator";
const COMPILER_MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_TRANSLATOR_SYMBOL: &str =
    "tiny_native_backend_mir_to_cranelift_block_param_merge_imported_branch_joined_return_translator";
const COMPILER_MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_TRANSLATOR_SYMBOL:
    &str =
    "tiny_native_backend_mir_to_cranelift_block_param_merge_dual_imported_joined_return_translator";
const COMPILER_MIR_INGESTED_LOCAL_BINDING_READ_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_local_binding_read";
const COMPILER_MIR_INGESTED_CONDITIONAL_BRANCH_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_conditional_branch";
const COMPILER_MIR_INGESTED_ADD_I32_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_add_i32";
const COMPILER_MIR_INGESTED_PROVENANCE_METADATA_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_provenance_metadata";
const COMPILER_MIR_INGESTED_RESOURCE_METADATA_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_resource_metadata";
const COMPILER_MIR_INGESTED_NATIVE_BOUNDARY_METADATA_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_native_boundary_metadata";
const COMPILER_MIR_INGESTED_POSITIVE_I32_BRANCH_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_positive_i32_branch";
const COMPILER_MIR_INGESTED_BLOCK_JUMP_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_jump";
const COMPILER_MIR_INGESTED_BLOCK_LOCAL_BRANCH_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_local_branch";
const COMPILER_MIR_INGESTED_BLOCK_LOCAL_UPDATE_BRANCH_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_local_update_branch";
const COMPILER_MIR_INGESTED_BLOCK_TWO_LOCAL_UPDATE_BRANCH_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_two_local_update_branch";
const COMPILER_MIR_INGESTED_BLOCK_LOCAL_BRANCH_JOIN_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_local_branch_join";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_UPDATE_BRANCH_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_update_branch";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_CALL_BRANCH_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_local_call_branch";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_CALL_HELPER_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_local_call_helper";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_BRANCH_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_imported_call_branch";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_HOST_ADD_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_imported_call_host_add";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_RETURN_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_imported_call_return";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_imported_call_return_host_add";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_PREDICATE_UPDATE_BRANCH_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_imported_predicate_update_branch";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_PREDICATE_HOST_IS_POSITIVE_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_imported_predicate_host_is_positive";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_UPDATE_BRANCH_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_merge_update_branch";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return_host_add";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL:
    &str = "tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return_host_add";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_HOST_ADD_SYMBOL:
    &str = "tiny_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch_host_add";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_HOST_ADD_SYMBOL: &str = "tiny_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return_host_add";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_BRANCH_HOST_ADD_SYMBOL:
    &str = "tiny_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return_branch_host_add";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_RETURN_HOST_ADD_SYMBOL:
    &str = "tiny_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return_return_host_add";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_BRANCH_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_branch";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_BRANCH_HOST_ADD_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_branch_host_add";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_MATERIALIZE_BRANCH_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_branch";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_MATERIALIZE_BRANCH_HELPER_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_branch_helper";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_MATERIALIZE_RETURN_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_return";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_MATERIALIZE_RETURN_HELPER_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_return_helper";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_DUAL_MATERIALIZE_RETURN_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_dual_materialize_return";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_DUAL_MATERIALIZE_RETURN_HELPER_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_dual_materialize_return_helper";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_DUAL_MATERIALIZE_RETURN_HOST_ADD_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_dual_materialize_return_host_add";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_FIRST_DUAL_MATERIALIZE_RETURN_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_FIRST_DUAL_MATERIALIZE_RETURN_HELPER_SYMBOL: &str = "tiny_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return_helper";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_FIRST_DUAL_MATERIALIZE_RETURN_HOST_ADD_SYMBOL: &str = "tiny_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return_host_add";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_HELPER_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return_helper";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_EXIT_HELPER_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return_exit_helper";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_HOST_ADD_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return_host_add";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_HELPER_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return_helper";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_SECOND_HELPER_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return_second_helper";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_HOST_ADD_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return_host_add";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_HELPER_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return_helper";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_SECOND_HELPER_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return_second_helper";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_EXIT_HELPER_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return_exit_helper";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_HOST_ADD_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return_host_add";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_RETURN_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_return";
const COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_RETURN_HOST_ADD_SYMBOL: &str =
    "tiny_native_backend_compiler_mir_ingested_block_param_imported_materialize_return_host_add";
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
const MIR_BLOCK_GRAPH_PARAM_CALL_I32_SYMBOL: &str = "tiny_cranelift_mir_block_graph_param_call_i32";
const MIR_BLOCK_GRAPH_PARAM_CALL_BRANCH_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_param_call_branch_i32";
const MIR_BLOCK_GRAPH_PARAM_CALL_MATERIALIZE_I32_SYMBOL: &str =
    "tiny_cranelift_mir_block_graph_param_call_materialize_i32";
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

#[derive(Clone, Copy, PartialEq, Eq)]
enum TinyMirType {
    I32,
    Void,
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
    ReturnVoid,
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
const COMPILER_MIR_CANONICAL_FIXTURE_FORMAT: &str = "gust.compiler_mir_ingestion.v1";

const PHASE9C_CANONICAL_RETURN_INT_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_return_int\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_return_int\n",
    "parameter_count: 0\n",
    "return_type: int\n",
    "local_count: 0\n",
    "entry_block: entry\n",
    "block_count: 1\n",
    "block_0_label: entry\n",
    "block_0_statement_count: 0\n",
    "block_0_terminator_kind: ReturnI32\n",
    "block_0_terminator_value: 1\n",
    "metadata_count: 0\n",
    "expected_exit: 1\n",
);

const PHASE9C_CANONICAL_LOCAL_BINDING_READ_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_local_binding_read\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_local_binding_read\n",
    "parameter_count: 0\n",
    "return_type: int\n",
    "local_count: 1\n",
    "local_0_name: value\n",
    "local_0_type: int\n",
    "entry_block: entry\n",
    "block_count: 1\n",
    "block_0_label: entry\n",
    "block_0_statement_count: 1\n",
    "block_0_statement_0_kind: LocalI32Set\n",
    "block_0_statement_0_local: value\n",
    "block_0_statement_0_value: 2\n",
    "block_0_terminator_kind: ReturnLocalI32\n",
    "block_0_terminator_local: value\n",
    "metadata_count: 0\n",
    "expected_exit: 2\n",
);

const PHASE9C_CANONICAL_CONDITIONAL_BRANCH_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_conditional_branch\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_conditional_branch\n",
    "parameter_count: 0\n",
    "return_type: int\n",
    "local_count: 0\n",
    "entry_block: entry\n",
    "block_count: 3\n",
    "block_0_label: entry\n",
    "block_0_statement_count: 0\n",
    "block_0_terminator_kind: BranchI32Literal\n",
    "block_0_terminator_condition: 1\n",
    "block_0_terminator_then: then\n",
    "block_0_terminator_else: else\n",
    "block_1_label: then\n",
    "block_1_statement_count: 0\n",
    "block_1_terminator_kind: ReturnI32\n",
    "block_1_terminator_value: 1\n",
    "block_2_label: else\n",
    "block_2_statement_count: 0\n",
    "block_2_terminator_kind: ReturnI32\n",
    "block_2_terminator_value: 2\n",
    "metadata_count: 0\n",
    "expected_exit: 1\n",
);

const PHASE9C_CANONICAL_BLOCK_JUMP_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_block_jump\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_jump\n",
    "parameter_count: 0\n",
    "return_type: int\n",
    "local_count: 0\n",
    "entry_block: entry\n",
    "block_count: 2\n",
    "block_0_label: entry\n",
    "block_0_statement_count: 0\n",
    "block_0_terminator_kind: Jump\n",
    "block_0_terminator_target: return\n",
    "block_1_label: return\n",
    "block_1_statement_count: 0\n",
    "block_1_terminator_kind: ReturnI32\n",
    "block_1_terminator_value: 1\n",
    "metadata_count: 0\n",
    "expected_exit: 1\n",
);

const PHASE9C_CANONICAL_PROVENANCE_METADATA_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_provenance_metadata_local_read\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_provenance_metadata\n",
    "parameter_count: 0\n",
    "return_type: int\n",
    "local_count: 1\n",
    "local_0_name: value\n",
    "local_0_type: int\n",
    "entry_block: entry\n",
    "block_count: 1\n",
    "block_0_label: entry\n",
    "block_0_statement_count: 1\n",
    "block_0_statement_0_kind: LocalI32Set\n",
    "block_0_statement_0_local: value\n",
    "block_0_statement_0_value: 2\n",
    "block_0_terminator_kind: ReturnLocalI32\n",
    "block_0_terminator_local: value\n",
    "metadata_count: 1\n",
    "metadata_0_kind: provenance\n",
    "metadata_0_attachment: statement:entry:0\n",
    "metadata_0_policy: ignored_with_proof\n",
    "metadata_0_payload: kind=LocalBinding;local=value;origin=compiler/mir_feature_local_binding_read_provenance_metadata_preservation_source.gst\n",
    "expected_exit: 2\n",
);

const PHASE9C_CANONICAL_RESOURCE_METADATA_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_resource_metadata_local\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_resource_metadata\n",
    "parameter_count: 0\n",
    "return_type: int\n",
    "local_count: 1\n",
    "local_0_name: value\n",
    "local_0_type: int\n",
    "entry_block: entry\n",
    "block_count: 1\n",
    "block_0_label: entry\n",
    "block_0_statement_count: 1\n",
    "block_0_statement_0_kind: LocalI32Set\n",
    "block_0_statement_0_local: value\n",
    "block_0_statement_0_value: 2\n",
    "block_0_terminator_kind: ReturnLocalI32\n",
    "block_0_terminator_local: value\n",
    "metadata_count: 1\n",
    "metadata_0_kind: resource\n",
    "metadata_0_attachment: statement:entry:0\n",
    "metadata_0_policy: ignored_with_proof\n",
    "metadata_0_payload: kind=LinearResource;state=Live;local=value;cleanup_required=false\n",
    "expected_exit: 2\n",
);

const PHASE9C_CANONICAL_NATIVE_BOUNDARY_METADATA_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_native_boundary_metadata_function\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_native_boundary_metadata\n",
    "parameter_count: 0\n",
    "return_type: void\n",
    "local_count: 0\n",
    "entry_block: entry\n",
    "block_count: 1\n",
    "block_0_label: entry\n",
    "block_0_statement_count: 0\n",
    "block_0_terminator_kind: ReturnVoid\n",
    "metadata_count: 1\n",
    "metadata_0_kind: native_boundary\n",
    "metadata_0_attachment: function\n",
    "metadata_0_policy: ignored_with_proof\n",
    "metadata_0_payload: kind=RuntimeCall;symbol=tiny_runtime_boundary;origin=compiler/mir_to_c_native_boundary_metadata_smoke_test_entry.gst\n",
    "expected_exit: 0\n",
);

const PHASE9D_CANONICAL_ADD_I32_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_add_i32\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_add_i32\n",
    "parameter_count: 2\n",
    "parameter_0_type: int\n",
    "parameter_1_type: int\n",
    "return_type: int\n",
    "local_count: 1\n",
    "local_0_name: result\n",
    "local_0_type: int\n",
    "entry_block: entry\n",
    "block_count: 1\n",
    "block_0_label: entry\n",
    "block_0_statement_count: 2\n",
    "block_0_statement_0_kind: LocalI32SetParam\n",
    "block_0_statement_0_local: result\n",
    "block_0_statement_0_param: 0\n",
    "block_0_statement_1_kind: LocalI32AddParam\n",
    "block_0_statement_1_local: result\n",
    "block_0_statement_1_param: 1\n",
    "block_0_terminator_kind: ReturnLocalI32\n",
    "block_0_terminator_local: result\n",
    "metadata_count: 0\n",
    "expected_exit: 5\n",
);

const PHASE9D_CANONICAL_POSITIVE_I32_BRANCH_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_positive_i32_branch\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_positive_i32_branch\n",
    "parameter_count: 1\n",
    "parameter_0_type: int\n",
    "return_type: int\n",
    "local_count: 1\n",
    "local_0_name: value\n",
    "local_0_type: int\n",
    "entry_block: entry\n",
    "block_count: 3\n",
    "block_0_label: entry\n",
    "block_0_statement_count: 1\n",
    "block_0_statement_0_kind: LocalI32SetParam\n",
    "block_0_statement_0_local: value\n",
    "block_0_statement_0_param: 0\n",
    "block_0_terminator_kind: BranchLocalI32Positive\n",
    "block_0_terminator_local: value\n",
    "block_0_terminator_then: positive\n",
    "block_0_terminator_else: non_positive\n",
    "block_1_label: positive\n",
    "block_1_statement_count: 0\n",
    "block_1_terminator_kind: ReturnI32\n",
    "block_1_terminator_value: 7\n",
    "block_2_label: non_positive\n",
    "block_2_statement_count: 0\n",
    "block_2_terminator_kind: ReturnI32\n",
    "block_2_terminator_value: 9\n",
    "metadata_count: 0\n",
    "expected_exit: 7\n",
);

const PHASE9E_CANONICAL_BLOCK_LOCAL_BRANCH_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_block_local_branch\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_local_branch\n",
    "parameter_count: 1\n",
    "parameter_0_type: int\n",
    "return_type: int\n",
    "local_count: 1\n",
    "local_0_name: value\n",
    "local_0_type: int\n",
    "entry_block: entry\n",
    "block_count: 3\n",
    "block_0_label: entry\n",
    "block_0_statement_count: 1\n",
    "block_0_statement_0_kind: LocalI32SetParam\n",
    "block_0_statement_0_local: value\n",
    "block_0_statement_0_param: 0\n",
    "block_0_terminator_kind: BranchLocalI32Positive\n",
    "block_0_terminator_local: value\n",
    "block_0_terminator_then: positive\n",
    "block_0_terminator_else: non_positive\n",
    "block_1_label: positive\n",
    "block_1_statement_count: 0\n",
    "block_1_terminator_kind: ReturnI32\n",
    "block_1_terminator_value: 43\n",
    "block_2_label: non_positive\n",
    "block_2_statement_count: 0\n",
    "block_2_terminator_kind: ReturnI32\n",
    "block_2_terminator_value: 47\n",
    "metadata_count: 0\n",
    "expected_exit: 43\n",
);

const PHASE9E_CANONICAL_BLOCK_LOCAL_UPDATE_BRANCH_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_block_local_update_branch\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_local_update_branch\n",
    "parameter_count: 1\n",
    "parameter_0_type: int\n",
    "return_type: int\n",
    "local_count: 1\n",
    "local_0_name: value\n",
    "local_0_type: int\n",
    "entry_block: entry\n",
    "block_count: 4\n",
    "block_0_label: entry\n",
    "block_0_statement_count: 1\n",
    "block_0_statement_0_kind: LocalI32SetParam\n",
    "block_0_statement_0_local: value\n",
    "block_0_statement_0_param: 0\n",
    "block_0_terminator_kind: Jump\n",
    "block_0_terminator_target: increment\n",
    "block_1_label: increment\n",
    "block_1_statement_count: 1\n",
    "block_1_statement_0_kind: LocalI32AddI32Literal\n",
    "block_1_statement_0_local: value\n",
    "block_1_statement_0_value: 2\n",
    "block_1_terminator_kind: BranchLocalI32Positive\n",
    "block_1_terminator_local: value\n",
    "block_1_terminator_then: positive\n",
    "block_1_terminator_else: non_positive\n",
    "block_2_label: positive\n",
    "block_2_statement_count: 0\n",
    "block_2_terminator_kind: ReturnI32\n",
    "block_2_terminator_value: 53\n",
    "block_3_label: non_positive\n",
    "block_3_statement_count: 0\n",
    "block_3_terminator_kind: ReturnI32\n",
    "block_3_terminator_value: 59\n",
    "metadata_count: 0\n",
    "expected_exit: 53\n",
);

const PHASE9E_CANONICAL_BLOCK_TWO_LOCAL_UPDATE_BRANCH_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_block_two_local_update_branch\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_two_local_update_branch\n",
    "parameter_count: 1\n",
    "parameter_0_type: int\n",
    "return_type: int\n",
    "local_count: 2\n",
    "local_0_name: raw\n",
    "local_0_type: int\n",
    "local_1_name: adjusted\n",
    "local_1_type: int\n",
    "entry_block: entry\n",
    "block_count: 4\n",
    "block_0_label: entry\n",
    "block_0_statement_count: 2\n",
    "block_0_statement_0_kind: LocalI32SetParam\n",
    "block_0_statement_0_local: raw\n",
    "block_0_statement_0_param: 0\n",
    "block_0_statement_1_kind: LocalI32SetParam\n",
    "block_0_statement_1_local: adjusted\n",
    "block_0_statement_1_param: 0\n",
    "block_0_terminator_kind: Jump\n",
    "block_0_terminator_target: adjust\n",
    "block_1_label: adjust\n",
    "block_1_statement_count: 1\n",
    "block_1_statement_0_kind: LocalI32AddI32Literal\n",
    "block_1_statement_0_local: adjusted\n",
    "block_1_statement_0_value: 3\n",
    "block_1_terminator_kind: BranchLocalI32Positive\n",
    "block_1_terminator_local: adjusted\n",
    "block_1_terminator_then: positive\n",
    "block_1_terminator_else: non_positive\n",
    "block_2_label: positive\n",
    "block_2_statement_count: 0\n",
    "block_2_terminator_kind: ReturnI32\n",
    "block_2_terminator_value: 61\n",
    "block_3_label: non_positive\n",
    "block_3_statement_count: 0\n",
    "block_3_terminator_kind: ReturnI32\n",
    "block_3_terminator_value: 67\n",
    "metadata_count: 0\n",
    "expected_exit: 61\n",
);

#[derive(Clone, Copy)]
enum CompilerMirLoweringStatement<'a> {
    LocalI32Set { name: &'a str, value: i32 },
    LocalI32SetParam {
        name: &'a str,
        param: usize,
    },
    LocalI32SetBlockParam {
        name: &'a str,
        block_param: &'a str,
    },
    LocalI32AddI32Literal {
        name: &'a str,
        value: i32,
    },
    LocalI32AddParam {
        name: &'a str,
        param: usize,
    },
}

#[derive(Clone, Copy)]
struct CompilerMirLoweringBlockParameter<'a> {
    name: &'a str,
    ty: TinyMirType,
}

#[derive(Clone, Copy)]
enum CompilerMirLoweringEdgeArgument<'a> {
    I32Literal(i32),
    FunctionParamI32(usize),
    LocalI32(&'a str),
    BlockParamI32(&'a str),
    BlockParamI32AddI32Literal {
        name: &'a str,
        value: i32,
    },
}

#[derive(Clone)]
struct CompilerMirLoweringEdge<'a> {
    target: &'a str,
    arguments: Vec<CompilerMirLoweringEdgeArgument<'a>>,
}

#[derive(Clone)]
enum CompilerMirLoweringTerminator<'a> {
    ReturnI32(i32),
    ReturnLocalI32(&'a str),
    ReturnBlockParamI32(&'a str),
    ReturnVoid,
    Jump {
        edge: CompilerMirLoweringEdge<'a>,
    },
    BranchI32Literal {
        condition: i32,
        then_edge: CompilerMirLoweringEdge<'a>,
        else_edge: CompilerMirLoweringEdge<'a>,
    },
    BranchLocalI32Positive {
        name: &'a str,
        then_edge: CompilerMirLoweringEdge<'a>,
        else_edge: CompilerMirLoweringEdge<'a>,
    },
    BranchBlockParamI32Positive {
        name: &'a str,
        then_edge: CompilerMirLoweringEdge<'a>,
        else_edge: CompilerMirLoweringEdge<'a>,
    },
}

struct CompilerMirLoweringLocal<'a> {
    name: &'a str,
    ty: TinyMirType,
}

struct CompilerMirLoweringBlock<'a> {
    label: &'a str,
    parameters: Vec<CompilerMirLoweringBlockParameter<'a>>,
    statements: Vec<CompilerMirLoweringStatement<'a>>,
    terminator: CompilerMirLoweringTerminator<'a>,
}

struct CompilerMirLoweringFunction<'a> {
    object_name: &'a str,
    symbol: &'a str,
    return_type: TinyMirType,
    params: Vec<TinyMirType>,
    locals: Vec<CompilerMirLoweringLocal<'a>>,
    entry_block: &'a str,
    blocks: Vec<CompilerMirLoweringBlock<'a>>,
}

struct CompilerMirFixtureMetadata<'a> {
    kind: &'a str,
    attachment: &'a str,
    policy: &'a str,
    payload: &'a str,
}

struct ParsedCompilerMirFixture<'a> {
    function: CompilerMirLoweringFunction<'a>,
    return_type: TinyMirType,
    metadata: Vec<CompilerMirFixtureMetadata<'a>>,
    expected_exit: i32,
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
    JumpBlockParamLocalFunctionI32Call {
        target: &'static str,
        function_symbol: &'static str,
        param: usize,
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
    JumpBlockParamImportedFunctionI32CallI32Literal {
        target: &'static str,
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

struct CompilerMirReturnIntIngestionFixture {
    return_value: i32,
}

static MIR_TO_CRANELIFT_RETURN_INT_TRANSLATOR_EMPTY_PARAMS: [TinyMirType; 0] = [];
static MIR_TO_CRANELIFT_RETURN_INT_TRANSLATOR_EMPTY_LOCALS: [TinyMirLocal; 0] = [];
static MIR_TO_CRANELIFT_RETURN_INT_TRANSLATOR_EMPTY_STATEMENTS: [TinyMirStatement; 0] = [];

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
        "compiler-mir-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_fixture_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-validate-fixture" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            validate_compiler_mir_fixture_path(Path::new(&input_path))
        }
        "return-int-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_return_int_object(Path::new(&output_path))
        }
        "compiler-mir-return-int-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_return_int_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-to-cranelift-return-int-translator-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_to_cranelift_return_int_translator_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-to-cranelift-local-binding-read-translator-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_to_cranelift_local_binding_read_translator_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-to-cranelift-conditional-branch-translator-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_to_cranelift_conditional_branch_translator_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-to-cranelift-block-jump-translator-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_to_cranelift_block_jump_translator_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-to-cranelift-provenance-metadata-translator-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_to_cranelift_provenance_metadata_translator_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-to-cranelift-resource-metadata-translator-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_to_cranelift_resource_metadata_translator_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-to-cranelift-native-boundary-metadata-translator-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_to_cranelift_native_boundary_metadata_translator_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-to-cranelift-add-i32-translator-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_to_cranelift_add_i32_translator_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-to-cranelift-positive-i32-branch-translator-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_to_cranelift_positive_i32_branch_translator_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-to-cranelift-block-local-branch-join-translator-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_to_cranelift_block_local_branch_join_translator_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-to-cranelift-block-param-update-branch-translator-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_to_cranelift_block_param_update_branch_translator_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-to-cranelift-block-param-merge-update-branch-translator-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_to_cranelift_block_param_merge_update_branch_translator_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-to-cranelift-block-param-merge-imported-call-return-translator-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_to_cranelift_block_param_merge_imported_call_return_translator_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-to-cranelift-block-param-merge-arm-update-imported-call-return-translator-object" =>
        {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-to-cranelift-block-param-merge-arm-update-imported-call-branch-translator-object" =>
        {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_to_cranelift_block_param_merge_arm_update_imported_call_branch_translator_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-to-cranelift-block-param-merge-imported-branch-joined-return-translator-object" =>
        {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_to_cranelift_block_param_merge_imported_branch_joined_return_translator_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-to-cranelift-block-param-merge-dual-imported-joined-return-translator-object" =>
        {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_to_cranelift_block_param_merge_dual_imported_joined_return_translator_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-local-binding-read-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_local_binding_read_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-conditional-branch-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_conditional_branch_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-add-i32-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_add_i32_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-provenance-metadata-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_provenance_metadata_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-resource-metadata-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_resource_metadata_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-native-boundary-metadata-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_native_boundary_metadata_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-positive-i32-branch-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_positive_i32_branch_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-jump-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_jump_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-local-branch-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_local_branch_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-local-update-branch-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_local_update_branch_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-two-local-update-branch-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_two_local_update_branch_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-local-branch-join-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_local_branch_join_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-update-branch-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_update_branch_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-local-call-branch-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_local_call_branch_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-imported-call-branch-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_imported_call_branch_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-imported-call-return-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_imported_call_return_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-imported-predicate-update-branch-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_imported_predicate_update_branch_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-merge-update-branch-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_merge_update_branch_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-merge-imported-call-return-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_merge_imported_call_return_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-merge-arm-update-imported-call-return-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_merge_arm_update_imported_call_return_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-merge-arm-update-imported-call-branch-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_merge_arm_update_imported_call_branch_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-merge-imported-branch-joined-return-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_merge_imported_branch_joined_return_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-merge-dual-imported-joined-return-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_merge_dual_imported_joined_return_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-imported-materialize-branch-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_imported_materialize_branch_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-local-materialize-branch-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_local_materialize_branch_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-imported-materialize-return-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_imported_materialize_return_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-local-materialize-return-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_local_materialize_return_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-dual-materialize-return-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_dual_materialize_return_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-local-first-dual-materialize-return-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_local_first_dual_materialize_return_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-triple-materialize-return-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_triple_materialize_return_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-quad-materialize-return-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_quad_materialize_return_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
        }
        "compiler-mir-block-param-quint-materialize-return-ingestion-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_compiler_mir_block_param_quint_materialize_return_ingestion_object(
                Path::new(&input_path),
                Path::new(&output_path),
            )
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
        "mir-block-graph-param-call-materialize-i32-bundle-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_block_graph_param_call_materialize_i32_bundle_object(Path::new(&output_path))
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
        "mir-block-graph-param-extern-materialize-i32-bundle-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_block_graph_param_extern_materialize_i32_bundle_object(Path::new(&output_path))
        }
        "mir-block-graph-param-extern-materialize-return-i32-bundle-object" => {
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            emit_mir_block_graph_param_extern_materialize_return_i32_bundle_object(Path::new(
                &output_path,
            ))
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
        concat!(
            "usage:\n",
            "  gust-cranelift-experiment compiler-mir-ingestion-object <input.mir> <output.o>\n",
            "  gust-cranelift-experiment compiler-mir-validate-fixture <input.mir>\n",
            "  gust-cranelift-experiment compiler-mir-return-int-ingestion-object <input.mir> <output.o>\n",
            "  gust-cranelift-experiment ",
            "<return-int-object|",
            "mir-return-int-object|",
            "mir-local-binding-read-object|",
            "mir-conditional-branch-object|",
            "mir-add-i32-object|",
            "mir-arithmetic-i32-bundle-object|",
            "mir-comparison-i32-bundle-object|",
            "mir-comparison-branch-i32-bundle-object|",
            "mir-block-graph-i32-bundle-object|",
            "mir-block-graph-local-i32-bundle-object|",
            "mir-block-graph-local-update-i32-bundle-object|",
            "mir-block-graph-param-i32-bundle-object|",
            "mir-block-graph-param-call-i32-bundle-object|",
            "mir-block-graph-param-extern-i32-bundle-object|",
            "mir-block-graph-param-extern-add-i32-bundle-object|",
            "mir-block-graph-param-extern-predicate-i32-bundle-object|",
            "mir-block-graph-param-merge-i32-bundle-object|",
            "mir-block-graph-param-merge-call-i32-bundle-object|",
            "mir-positive-i32-branch-object|",
            "mir-increment-local-i32-object|",
            "mir-call-helper-i32-object|",
            "mir-extern-call-i32-object|",
            "mir-extern-add-i32-object|",
            "mir-extern-predicate-branch-i32-object|",
            "local-binding-read-object|",
            "conditional-branch-object|",
            "identity-i32-object|",
            "add-i32-object|",
            "positive-i32-branch-object|",
            "increment-local-i32-object|",
            "call-helper-i32-object|",
            "extern-call-i32-object|",
            "extern-add-i32-object|",
            "extern-predicate-branch-i32-object> ",
            "<output.o>",
        ),
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

fn emit_compiler_mir_return_int_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_return_int_ingestion_fixture(&contents)?;
    emit_compiler_mir_fixture_contents_object(
        PHASE9C_CANONICAL_RETURN_INT_FIXTURE,
        output_path,
    )
}

fn emit_compiler_mir_to_cranelift_return_int_translator_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    let fixture = parse_compiler_mir_return_int_ingestion_fixture(&contents)?;
    let mir_function = translate_compiler_mir_return_int_fixture_to_tiny_mir_function(&fixture);
    lower_tiny_mir_function_to_object(output_path, &mir_function)
}

fn translate_compiler_mir_return_int_fixture_to_tiny_mir_function(
    fixture: &CompilerMirReturnIntIngestionFixture,
) -> TinyMirFunction {
    TinyMirFunction {
        object_name: "gust_native_backend_mir_to_cranelift_return_int_translator",
        symbol: COMPILER_MIR_TO_CRANELIFT_RETURN_INT_TRANSLATOR_SYMBOL,
        params: &MIR_TO_CRANELIFT_RETURN_INT_TRANSLATOR_EMPTY_PARAMS,
        return_type: TinyMirType::I32,
        locals: &MIR_TO_CRANELIFT_RETURN_INT_TRANSLATOR_EMPTY_LOCALS,
        statements: &MIR_TO_CRANELIFT_RETURN_INT_TRANSLATOR_EMPTY_STATEMENTS,
        terminator: TinyMirTerminator::ReturnI32(fixture.return_value),
    }
}

fn parse_compiler_mir_return_int_ingestion_fixture(
    contents: &str,
) -> Result<CompilerMirReturnIntIngestionFixture, Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;

    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.return_int.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_return_int_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "mir_lower_return_int_literal_fixture",
    )?;
    require_compiler_mir_ingestion_field(&fields, "function", "tiny_return_int")?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_RETURN_INT_SYMBOL,
    )?;

    let return_value = required_compiler_mir_ingestion_field(&fields, "return_value")?
        .parse::<i32>()
        .map_err(|_| {
            IoError::new(
                ErrorKind::InvalidInput,
                "compiler MIR ingestion fixture return_value must be an i32",
            )
        })?;
    if return_value != 1 {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            "compiler MIR ingestion fixture currently admits only tiny_return_int returning 1",
        )
        .into());
    }

    Ok(CompilerMirReturnIntIngestionFixture { return_value })
}

fn parse_compiler_mir_fixture<'a>(
    contents: &'a str,
) -> Result<ParsedCompilerMirFixture<'a>, Box<dyn Error>> {
    let fields = parse_compiler_mir_fixture_fields(contents)?;
    let mut consumed: HashSet<&str> = HashSet::new();

    let format = required_canonical_compiler_mir_fixture_field(
        &fields,
        &mut consumed,
        "format",
    )?;
    if format != COMPILER_MIR_CANONICAL_FIXTURE_FORMAT {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            format!(
                "canonical compiler MIR fixture format expected {}, got {format}",
                COMPILER_MIR_CANONICAL_FIXTURE_FORMAT
            ),
        )
        .into());
    }

    let function_name = required_canonical_compiler_mir_fixture_field(
        &fields,
        &mut consumed,
        "function",
    )?;
    let backend_symbol = required_canonical_compiler_mir_fixture_field(
        &fields,
        &mut consumed,
        "backend_symbol",
    )?;

    let parameter_count = parse_canonical_compiler_mir_usize_field(
        &fields,
        &mut consumed,
        "parameter_count",
    )?;
    let mut params = Vec::with_capacity(parameter_count);
    for index in 0..parameter_count {
        let key = format!("parameter_{index}_type");
        let value = required_canonical_compiler_mir_fixture_field(
            &fields,
            &mut consumed,
            &key,
        )?;
        params.push(parse_canonical_compiler_mir_type(value, &key)?);
    }

    let return_type_value = required_canonical_compiler_mir_fixture_field(
        &fields,
        &mut consumed,
        "return_type",
    )?;
    let return_type = parse_canonical_compiler_mir_type(return_type_value, "return_type")?;

    let local_count = parse_canonical_compiler_mir_usize_field(
        &fields,
        &mut consumed,
        "local_count",
    )?;
    let mut locals = Vec::with_capacity(local_count);
    for index in 0..local_count {
        let name_key = format!("local_{index}_name");
        let type_key = format!("local_{index}_type");
        let name = required_canonical_compiler_mir_fixture_field(
            &fields,
            &mut consumed,
            &name_key,
        )?;
        let ty_value = required_canonical_compiler_mir_fixture_field(
            &fields,
            &mut consumed,
            &type_key,
        )?;
        locals.push(CompilerMirLoweringLocal {
            name,
            ty: parse_canonical_compiler_mir_type(ty_value, &type_key)?,
        });
    }

    let entry_block = required_canonical_compiler_mir_fixture_field(
        &fields,
        &mut consumed,
        "entry_block",
    )?;
    let block_count = parse_canonical_compiler_mir_usize_field(
        &fields,
        &mut consumed,
        "block_count",
    )?;
    let mut blocks = Vec::with_capacity(block_count);
    for block_index in 0..block_count {
        let label_key = format!("block_{block_index}_label");
        let statement_count_key = format!("block_{block_index}_statement_count");
        let label = required_canonical_compiler_mir_fixture_field(
            &fields,
            &mut consumed,
            &label_key,
        )?;
        let block_parameter_count_key = format!("block_{block_index}_parameter_count");
        let block_parameter_count = parse_optional_canonical_compiler_mir_usize_field(
            &fields,
            &mut consumed,
            &block_parameter_count_key,
            0,
        )?;
        let mut block_parameters = Vec::with_capacity(block_parameter_count);
        for parameter_index in 0..block_parameter_count {
            let name_key = format!(
                "block_{block_index}_parameter_{parameter_index}_name"
            );
            let type_key = format!(
                "block_{block_index}_parameter_{parameter_index}_type"
            );
            let name = required_canonical_compiler_mir_fixture_field(
                &fields,
                &mut consumed,
                &name_key,
            )?;
            let ty_value = required_canonical_compiler_mir_fixture_field(
                &fields,
                &mut consumed,
                &type_key,
            )?;
            block_parameters.push(CompilerMirLoweringBlockParameter {
                name,
                ty: parse_canonical_compiler_mir_type(ty_value, &type_key)?,
            });
        }
        let statement_count = parse_canonical_compiler_mir_usize_field(
            &fields,
            &mut consumed,
            &statement_count_key,
        )?;
        let mut statements = Vec::with_capacity(statement_count);
        for statement_index in 0..statement_count {
            let prefix = format!("block_{block_index}_statement_{statement_index}");
            let kind_key = format!("{prefix}_kind");
            let kind = required_canonical_compiler_mir_fixture_field(
                &fields,
                &mut consumed,
                &kind_key,
            )?;
            let statement = match kind {
                "LocalI32Set" => {
                    let local_key = format!("{prefix}_local");
                    let value_key = format!("{prefix}_value");
                    CompilerMirLoweringStatement::LocalI32Set {
                        name: required_canonical_compiler_mir_fixture_field(
                            &fields,
                            &mut consumed,
                            &local_key,
                        )?,
                        value: parse_canonical_compiler_mir_i32_field(
                            &fields,
                            &mut consumed,
                            &value_key,
                        )?,
                    }
                }
                "LocalI32SetParam" => {
                    let local_key = format!("{prefix}_local");
                    let param_key = format!("{prefix}_param");
                    CompilerMirLoweringStatement::LocalI32SetParam {
                        name: required_canonical_compiler_mir_fixture_field(
                            &fields,
                            &mut consumed,
                            &local_key,
                        )?,
                        param: parse_canonical_compiler_mir_usize_field(
                            &fields,
                            &mut consumed,
                            &param_key,
                        )?,
                    }
                }
                "LocalI32SetBlockParam" => {
                    let local_key = format!("{prefix}_local");
                    let block_param_key = format!("{prefix}_block_param");
                    CompilerMirLoweringStatement::LocalI32SetBlockParam {
                        name: required_canonical_compiler_mir_fixture_field(
                            &fields,
                            &mut consumed,
                            &local_key,
                        )?,
                        block_param: required_canonical_compiler_mir_fixture_field(
                            &fields,
                            &mut consumed,
                            &block_param_key,
                        )?,
                    }
                }
                "LocalI32AddI32Literal" => {
                    let local_key = format!("{prefix}_local");
                    let value_key = format!("{prefix}_value");
                    CompilerMirLoweringStatement::LocalI32AddI32Literal {
                        name: required_canonical_compiler_mir_fixture_field(
                            &fields,
                            &mut consumed,
                            &local_key,
                        )?,
                        value: parse_canonical_compiler_mir_i32_field(
                            &fields,
                            &mut consumed,
                            &value_key,
                        )?,
                    }
                }
                "LocalI32AddParam" => {
                    let local_key = format!("{prefix}_local");
                    let param_key = format!("{prefix}_param");
                    CompilerMirLoweringStatement::LocalI32AddParam {
                        name: required_canonical_compiler_mir_fixture_field(
                            &fields,
                            &mut consumed,
                            &local_key,
                        )?,
                        param: parse_canonical_compiler_mir_usize_field(
                            &fields,
                            &mut consumed,
                            &param_key,
                        )?,
                    }
                }
                other => {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "unsupported canonical compiler MIR statement kind at {kind_key}: {other}"
                        ),
                    )
                    .into());
                }
            };
            statements.push(statement);
        }

        let terminator_prefix = format!("block_{block_index}_terminator");
        let terminator_kind_key = format!("{terminator_prefix}_kind");
        let terminator_kind = required_canonical_compiler_mir_fixture_field(
            &fields,
            &mut consumed,
            &terminator_kind_key,
        )?;
        let terminator = match terminator_kind {
            "ReturnI32" => {
                let value_key = format!("{terminator_prefix}_value");
                CompilerMirLoweringTerminator::ReturnI32(
                    parse_canonical_compiler_mir_i32_field(
                        &fields,
                        &mut consumed,
                        &value_key,
                    )?,
                )
            }
            "ReturnLocalI32" => {
                let local_key = format!("{terminator_prefix}_local");
                CompilerMirLoweringTerminator::ReturnLocalI32(
                    required_canonical_compiler_mir_fixture_field(
                        &fields,
                        &mut consumed,
                        &local_key,
                    )?,
                )
            }
            "ReturnBlockParamI32" => {
                let block_param_key = format!("{terminator_prefix}_block_param");
                CompilerMirLoweringTerminator::ReturnBlockParamI32(
                    required_canonical_compiler_mir_fixture_field(
                        &fields,
                        &mut consumed,
                        &block_param_key,
                    )?,
                )
            }
            "ReturnVoid" => CompilerMirLoweringTerminator::ReturnVoid,
            "Jump" => {
                let target_key = format!("{terminator_prefix}_target");
                CompilerMirLoweringTerminator::Jump {
                    edge: CompilerMirLoweringEdge {
                        target: required_canonical_compiler_mir_fixture_field(
                            &fields,
                            &mut consumed,
                            &target_key,
                        )?,
                        arguments: parse_canonical_compiler_mir_edge_arguments(
                            &fields,
                            &mut consumed,
                            &terminator_prefix,
                        )?,
                    },
                }
            }
            "BranchI32Literal" => {
                let condition_key = format!("{terminator_prefix}_condition");
                let then_key = format!("{terminator_prefix}_then");
                let else_key = format!("{terminator_prefix}_else");
                let then_argument_prefix = format!("{terminator_prefix}_then");
                let else_argument_prefix = format!("{terminator_prefix}_else");
                CompilerMirLoweringTerminator::BranchI32Literal {
                    condition: parse_canonical_compiler_mir_i32_field(
                        &fields,
                        &mut consumed,
                        &condition_key,
                    )?,
                    then_edge: CompilerMirLoweringEdge {
                        target: required_canonical_compiler_mir_fixture_field(
                            &fields,
                            &mut consumed,
                            &then_key,
                        )?,
                        arguments: parse_canonical_compiler_mir_edge_arguments(
                            &fields,
                            &mut consumed,
                            &then_argument_prefix,
                        )?,
                    },
                    else_edge: CompilerMirLoweringEdge {
                        target: required_canonical_compiler_mir_fixture_field(
                            &fields,
                            &mut consumed,
                            &else_key,
                        )?,
                        arguments: parse_canonical_compiler_mir_edge_arguments(
                            &fields,
                            &mut consumed,
                            &else_argument_prefix,
                        )?,
                    },
                }
            }
            "BranchLocalI32Positive" => {
                let local_key = format!("{terminator_prefix}_local");
                let then_key = format!("{terminator_prefix}_then");
                let else_key = format!("{terminator_prefix}_else");
                let then_argument_prefix = format!("{terminator_prefix}_then");
                let else_argument_prefix = format!("{terminator_prefix}_else");
                CompilerMirLoweringTerminator::BranchLocalI32Positive {
                    name: required_canonical_compiler_mir_fixture_field(
                        &fields,
                        &mut consumed,
                        &local_key,
                    )?,
                    then_edge: CompilerMirLoweringEdge {
                        target: required_canonical_compiler_mir_fixture_field(
                            &fields,
                            &mut consumed,
                            &then_key,
                        )?,
                        arguments: parse_canonical_compiler_mir_edge_arguments(
                            &fields,
                            &mut consumed,
                            &then_argument_prefix,
                        )?,
                    },
                    else_edge: CompilerMirLoweringEdge {
                        target: required_canonical_compiler_mir_fixture_field(
                            &fields,
                            &mut consumed,
                            &else_key,
                        )?,
                        arguments: parse_canonical_compiler_mir_edge_arguments(
                            &fields,
                            &mut consumed,
                            &else_argument_prefix,
                        )?,
                    },
                }
            }
            "BranchBlockParamI32Positive" => {
                let block_param_key = format!("{terminator_prefix}_block_param");
                let then_key = format!("{terminator_prefix}_then");
                let else_key = format!("{terminator_prefix}_else");
                let then_argument_prefix = format!("{terminator_prefix}_then");
                let else_argument_prefix = format!("{terminator_prefix}_else");
                CompilerMirLoweringTerminator::BranchBlockParamI32Positive {
                    name: required_canonical_compiler_mir_fixture_field(
                        &fields,
                        &mut consumed,
                        &block_param_key,
                    )?,
                    then_edge: CompilerMirLoweringEdge {
                        target: required_canonical_compiler_mir_fixture_field(
                            &fields,
                            &mut consumed,
                            &then_key,
                        )?,
                        arguments: parse_canonical_compiler_mir_edge_arguments(
                            &fields,
                            &mut consumed,
                            &then_argument_prefix,
                        )?,
                    },
                    else_edge: CompilerMirLoweringEdge {
                        target: required_canonical_compiler_mir_fixture_field(
                            &fields,
                            &mut consumed,
                            &else_key,
                        )?,
                        arguments: parse_canonical_compiler_mir_edge_arguments(
                            &fields,
                            &mut consumed,
                            &else_argument_prefix,
                        )?,
                    },
                }
            }
            other => {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "unsupported canonical compiler MIR terminator kind at {terminator_kind_key}: {other}"
                    ),
                )
                .into());
            }
        };

        blocks.push(CompilerMirLoweringBlock {
            label,
            parameters: block_parameters,
            statements,
            terminator,
        });
    }

    let metadata_count = parse_canonical_compiler_mir_usize_field(
        &fields,
        &mut consumed,
        "metadata_count",
    )?;
    let mut metadata = Vec::with_capacity(metadata_count);
    for index in 0..metadata_count {
        let kind_key = format!("metadata_{index}_kind");
        let attachment_key = format!("metadata_{index}_attachment");
        let policy_key = format!("metadata_{index}_policy");
        let payload_key = format!("metadata_{index}_payload");
        metadata.push(CompilerMirFixtureMetadata {
            kind: required_canonical_compiler_mir_fixture_field(
                &fields,
                &mut consumed,
                &kind_key,
            )?,
            attachment: required_canonical_compiler_mir_fixture_field(
                &fields,
                &mut consumed,
                &attachment_key,
            )?,
            policy: required_canonical_compiler_mir_fixture_field(
                &fields,
                &mut consumed,
                &policy_key,
            )?,
            payload: required_canonical_compiler_mir_fixture_field(
                &fields,
                &mut consumed,
                &payload_key,
            )?,
        });
    }

    let expected_exit = parse_canonical_compiler_mir_i32_field(
        &fields,
        &mut consumed,
        "expected_exit",
    )?;

    let mut unknown_fields: Vec<&str> = fields
        .keys()
        .copied()
        .filter(|key| !consumed.contains(*key))
        .collect();
    unknown_fields.sort_unstable();
    if !unknown_fields.is_empty() {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            format!(
                "unknown canonical compiler MIR fixture field(s): {}",
                unknown_fields.join(",")
            ),
        )
        .into());
    }

    Ok(ParsedCompilerMirFixture {
        function: CompilerMirLoweringFunction {
            object_name: function_name,
            symbol: backend_symbol,
            return_type,
            params,
            locals,
            entry_block,
            blocks,
        },
        return_type,
        metadata,
        expected_exit,
    })
}

fn validate_compiler_mir_fixture(
    fixture: &ParsedCompilerMirFixture<'_>,
) -> Result<(), Box<dyn Error>> {
    let function = &fixture.function;
    validate_canonical_compiler_mir_name(function.object_name, "function")?;
    validate_canonical_compiler_mir_name(function.symbol, "backend_symbol")?;

    if function
        .params
        .iter()
        .any(|ty| !matches!(*ty, TinyMirType::I32))
    {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            "canonical compiler MIR fixture currently supports only int parameters",
        )
        .into());
    }
    match fixture.return_type {
        TinyMirType::I32 => {
            if !(0..=255).contains(&fixture.expected_exit) {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "canonical compiler MIR fixture expected_exit must be in 0..=255, got {}",
                        fixture.expected_exit
                    ),
                )
                .into());
            }
        }
        TinyMirType::Void => {
            if fixture.expected_exit != 0 {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "canonical compiler MIR void fixture expected_exit must be 0, got {}",
                        fixture.expected_exit
                    ),
                )
                .into());
            }
        }
    }

    let mut local_names: HashSet<&str> = HashSet::new();
    for local in &function.locals {
        validate_canonical_compiler_mir_name(local.name, "local")?;
        if !matches!(local.ty, TinyMirType::I32) {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "canonical compiler MIR fixture local {} must have int type",
                    local.name
                ),
            )
            .into());
        }
        if !local_names.insert(local.name) {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "duplicate canonical compiler MIR local name: {}",
                    local.name
                ),
            )
            .into());
        }
    }

    if function.blocks.is_empty() {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            "canonical compiler MIR fixture must contain at least one block",
        )
        .into());
    }

    let mut block_indices: HashMap<&str, usize> = HashMap::new();
    for (index, block) in function.blocks.iter().enumerate() {
        validate_canonical_compiler_mir_name(block.label, "block")?;
        if block_indices.insert(block.label, index).is_some() {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "duplicate canonical compiler MIR block label: {}",
                    block.label
                ),
            )
            .into());
        }
    }
    if !block_indices.contains_key(function.entry_block) {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            format!(
                "unknown canonical compiler MIR entry block: {}",
                function.entry_block
            ),
        )
        .into());
    }

    let mut block_parameter_types: Vec<HashMap<&str, TinyMirType>> =
        Vec::with_capacity(function.blocks.len());
    let mut block_parameter_owners: HashMap<&str, Vec<&str>> = HashMap::new();
    for block in &function.blocks {
        if block.label == function.entry_block && !block.parameters.is_empty() {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "canonical compiler MIR entry block {} cannot declare block parameters",
                    block.label
                ),
            )
            .into());
        }
        let mut parameter_types: HashMap<&str, TinyMirType> = HashMap::new();
        for parameter in &block.parameters {
            validate_canonical_compiler_mir_name(parameter.name, "block parameter")?;
            if !matches!(parameter.ty, TinyMirType::I32) {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "canonical compiler MIR block parameter {} in block {} must have int type",
                        parameter.name, block.label
                    ),
                )
                .into());
            }
            if parameter_types.insert(parameter.name, parameter.ty).is_some() {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "duplicate canonical compiler MIR block parameter {} in block {}",
                        parameter.name, block.label
                    ),
                )
                .into());
            }
            block_parameter_owners
                .entry(parameter.name)
                .or_default()
                .push(block.label);
        }
        block_parameter_types.push(parameter_types);
    }

    for (block_index, block) in function.blocks.iter().enumerate() {
        let current_block_parameters = &block_parameter_types[block_index];
        for (statement_index, statement) in block.statements.iter().enumerate() {
            match *statement {
                CompilerMirLoweringStatement::LocalI32Set { name, .. }
                | CompilerMirLoweringStatement::LocalI32AddI32Literal { name, .. } => {
                    validate_canonical_compiler_mir_local_reference(
                        &local_names,
                        name,
                        block.label,
                        statement_index,
                    )?;
                }
                CompilerMirLoweringStatement::LocalI32SetParam { name, param }
                | CompilerMirLoweringStatement::LocalI32AddParam { name, param } => {
                    validate_canonical_compiler_mir_local_reference(
                        &local_names,
                        name,
                        block.label,
                        statement_index,
                    )?;
                    if param >= function.params.len() {
                        return Err(IoError::new(
                            ErrorKind::InvalidInput,
                            format!(
                                "unknown canonical compiler MIR parameter {param} at block {} statement {statement_index}",
                                block.label
                            ),
                        )
                        .into());
                    }
                }
                CompilerMirLoweringStatement::LocalI32SetBlockParam {
                    name,
                    block_param,
                } => {
                    validate_canonical_compiler_mir_local_reference(
                        &local_names,
                        name,
                        block.label,
                        statement_index,
                    )?;
                    validate_canonical_compiler_mir_block_parameter_reference(
                        current_block_parameters,
                        &block_parameter_owners,
                        block_param,
                        block.label,
                        &format!("statement {statement_index}"),
                    )?;
                }
            }
        }

        match &block.terminator {
            CompilerMirLoweringTerminator::ReturnI32(_) => {
                if matches!(fixture.return_type, TinyMirType::Void) {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "canonical compiler MIR void function cannot return int at block {}",
                            block.label
                        ),
                    )
                    .into());
                }
            }
            CompilerMirLoweringTerminator::ReturnLocalI32(name) => {
                if matches!(fixture.return_type, TinyMirType::Void) {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "canonical compiler MIR void function cannot return local {name} at block {}",
                            block.label
                        ),
                    )
                    .into());
                }
                if !local_names.contains(name) {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "unknown canonical compiler MIR return local {name} at block {}",
                            block.label
                        ),
                    )
                    .into());
                }
            }
            CompilerMirLoweringTerminator::ReturnBlockParamI32(name) => {
                if matches!(fixture.return_type, TinyMirType::Void) {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "canonical compiler MIR void function cannot return block parameter {name} at block {}",
                            block.label
                        ),
                    )
                    .into());
                }
                validate_canonical_compiler_mir_block_parameter_reference(
                    current_block_parameters,
                    &block_parameter_owners,
                    name,
                    block.label,
                    "return",
                )?;
            }
            CompilerMirLoweringTerminator::ReturnVoid => {
                if matches!(fixture.return_type, TinyMirType::I32) {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "canonical compiler MIR int function cannot use ReturnVoid at block {}",
                            block.label
                        ),
                    )
                    .into());
                }
            }
            CompilerMirLoweringTerminator::Jump { edge } => {
                validate_canonical_compiler_mir_edge(
                    function,
                    &block_indices,
                    &local_names,
                    current_block_parameters,
                    &block_parameter_owners,
                    block.label,
                    "jump",
                    edge,
                )?;
            }
            CompilerMirLoweringTerminator::BranchI32Literal {
                then_edge,
                else_edge,
                ..
            } => {
                validate_canonical_compiler_mir_edge(
                    function,
                    &block_indices,
                    &local_names,
                    current_block_parameters,
                    &block_parameter_owners,
                    block.label,
                    "branch then",
                    then_edge,
                )?;
                validate_canonical_compiler_mir_edge(
                    function,
                    &block_indices,
                    &local_names,
                    current_block_parameters,
                    &block_parameter_owners,
                    block.label,
                    "branch else",
                    else_edge,
                )?;
            }
            CompilerMirLoweringTerminator::BranchLocalI32Positive {
                name,
                then_edge,
                else_edge,
            } => {
                if !local_names.contains(name) {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "unknown canonical compiler MIR branch local {name} at block {}",
                            block.label
                        ),
                    )
                    .into());
                }
                validate_canonical_compiler_mir_edge(
                    function,
                    &block_indices,
                    &local_names,
                    current_block_parameters,
                    &block_parameter_owners,
                    block.label,
                    "branch then",
                    then_edge,
                )?;
                validate_canonical_compiler_mir_edge(
                    function,
                    &block_indices,
                    &local_names,
                    current_block_parameters,
                    &block_parameter_owners,
                    block.label,
                    "branch else",
                    else_edge,
                )?;
            }
            CompilerMirLoweringTerminator::BranchBlockParamI32Positive {
                name,
                then_edge,
                else_edge,
            } => {
                validate_canonical_compiler_mir_block_parameter_reference(
                    current_block_parameters,
                    &block_parameter_owners,
                    name,
                    block.label,
                    "branch condition",
                )?;
                validate_canonical_compiler_mir_edge(
                    function,
                    &block_indices,
                    &local_names,
                    current_block_parameters,
                    &block_parameter_owners,
                    block.label,
                    "branch then",
                    then_edge,
                )?;
                validate_canonical_compiler_mir_edge(
                    function,
                    &block_indices,
                    &local_names,
                    current_block_parameters,
                    &block_parameter_owners,
                    block.label,
                    "branch else",
                    else_edge,
                )?;
            }
        }
    }

    validate_canonical_compiler_mir_reachability(function, &block_indices)?;

    for (index, metadata) in fixture.metadata.iter().enumerate() {
        if !matches!(metadata.kind, "provenance" | "resource" | "native_boundary") {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "unsupported canonical compiler MIR metadata kind at metadata {index}: {}",
                    metadata.kind
                ),
            )
            .into());
        }
        if metadata.payload.is_empty() {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!("canonical compiler MIR metadata {index} has an empty payload"),
            )
            .into());
        }
        if !matches!(
            metadata.policy,
            "recognized_preserved" | "ignored_with_proof"
        ) {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "unsupported canonical compiler MIR metadata policy at metadata {index}: {}",
                    metadata.policy
                ),
            )
            .into());
        }
        validate_canonical_compiler_mir_metadata_attachment(
            metadata.attachment,
            &block_indices,
            &function.blocks,
            index,
        )?;
    }

    Ok(())
}

fn validate_canonical_compiler_mir_block_parameter_reference<'a>(
    current_block_parameters: &HashMap<&'a str, TinyMirType>,
    block_parameter_owners: &HashMap<&'a str, Vec<&'a str>>,
    name: &str,
    block: &str,
    context: &str,
) -> Result<TinyMirType, Box<dyn Error>> {
    if let Some(ty) = current_block_parameters.get(name).copied() {
        return Ok(ty);
    }
    if let Some(owners) = block_parameter_owners.get(name) {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            format!(
                "canonical compiler MIR {context} in block {block} references block parameter {name} owned by block(s): {}",
                owners.join(",")
            ),
        )
        .into());
    }
    Err(IoError::new(
        ErrorKind::InvalidInput,
        format!(
            "unknown canonical compiler MIR block parameter {name} at block {block} {context}"
        ),
    )
    .into())
}

fn validate_canonical_compiler_mir_edge_argument<'a>(
    function: &CompilerMirLoweringFunction<'a>,
    local_names: &HashSet<&'a str>,
    current_block_parameters: &HashMap<&'a str, TinyMirType>,
    block_parameter_owners: &HashMap<&'a str, Vec<&'a str>>,
    source_block: &str,
    edge_name: &str,
    argument_index: usize,
    argument: &CompilerMirLoweringEdgeArgument<'a>,
) -> Result<TinyMirType, Box<dyn Error>> {
    match *argument {
        CompilerMirLoweringEdgeArgument::I32Literal(_) => Ok(TinyMirType::I32),
        CompilerMirLoweringEdgeArgument::FunctionParamI32(param) => function
            .params
            .get(param)
            .copied()
            .ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "unknown canonical compiler MIR function parameter {param} at block {source_block} {edge_name} argument {argument_index}"
                    ),
                )
                .into()
            }),
        CompilerMirLoweringEdgeArgument::LocalI32(name) => {
            if !local_names.contains(name) {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "unknown canonical compiler MIR local {name} at block {source_block} {edge_name} argument {argument_index}"
                    ),
                )
                .into());
            }
            Ok(TinyMirType::I32)
        }
        CompilerMirLoweringEdgeArgument::BlockParamI32(name)
        | CompilerMirLoweringEdgeArgument::BlockParamI32AddI32Literal { name, .. } => {
            validate_canonical_compiler_mir_block_parameter_reference(
                current_block_parameters,
                block_parameter_owners,
                name,
                source_block,
                &format!("{edge_name} argument {argument_index}"),
            )
        }
    }
}

fn validate_canonical_compiler_mir_edge<'a>(
    function: &CompilerMirLoweringFunction<'a>,
    block_indices: &HashMap<&'a str, usize>,
    local_names: &HashSet<&'a str>,
    current_block_parameters: &HashMap<&'a str, TinyMirType>,
    block_parameter_owners: &HashMap<&'a str, Vec<&'a str>>,
    source_block: &str,
    edge_name: &str,
    edge: &CompilerMirLoweringEdge<'a>,
) -> Result<(), Box<dyn Error>> {
    validate_canonical_compiler_mir_block_target(
        block_indices,
        edge.target,
        source_block,
        edge_name,
    )?;
    let target_index = *block_indices.get(edge.target).ok_or_else(|| {
        IoError::new(
            ErrorKind::InvalidInput,
            format!(
                "unknown canonical compiler MIR {edge_name} target {} from block {source_block}",
                edge.target
            ),
        )
    })?;
    let target_parameters = &function.blocks[target_index].parameters;
    if edge.arguments.len() != target_parameters.len() {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            format!(
                "canonical compiler MIR {edge_name} from block {source_block} to {} passes {} argument(s), but target declares {} block parameter(s)",
                edge.target,
                edge.arguments.len(),
                target_parameters.len()
            ),
        )
        .into());
    }
    for (argument_index, (argument, target_parameter)) in edge
        .arguments
        .iter()
        .zip(target_parameters.iter())
        .enumerate()
    {
        let argument_type = validate_canonical_compiler_mir_edge_argument(
            function,
            local_names,
            current_block_parameters,
            block_parameter_owners,
            source_block,
            edge_name,
            argument_index,
            argument,
        )?;
        if argument_type != target_parameter.ty {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "canonical compiler MIR {edge_name} argument {argument_index} from block {source_block} does not match target block parameter {} in block {}",
                    target_parameter.name, edge.target
                ),
            )
            .into());
        }
    }
    Ok(())
}

fn parse_compiler_mir_fixture_fields<'a>(
    contents: &'a str,
) -> Result<HashMap<&'a str, &'a str>, Box<dyn Error>> {
    let mut fields: HashMap<&str, &str> = HashMap::new();
    for (line_index, raw_line) in contents.lines().enumerate() {
        let line = raw_line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let Some((raw_key, raw_value)) = line.split_once(':') else {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "invalid canonical compiler MIR fixture line {}: {line}",
                    line_index + 1
                ),
            )
            .into());
        };
        let key = raw_key.trim();
        let value = raw_value.trim();
        if key.is_empty() {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "empty canonical compiler MIR fixture field name at line {}",
                    line_index + 1
                ),
            )
            .into());
        }
        if fields.insert(key, value).is_some() {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!("duplicate canonical compiler MIR fixture field: {key}"),
            )
            .into());
        }
    }
    Ok(fields)
}

fn required_canonical_compiler_mir_fixture_field<'a>(
    fields: &HashMap<&'a str, &'a str>,
    consumed: &mut HashSet<&'a str>,
    key: &str,
) -> Result<&'a str, Box<dyn Error>> {
    let Some((stored_key, value)) = fields.get_key_value(key) else {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            format!("missing canonical compiler MIR fixture field: {key}"),
        )
        .into());
    };
    consumed.insert(*stored_key);
    Ok(*value)
}

fn parse_canonical_compiler_mir_usize_field<'a>(
    fields: &HashMap<&'a str, &'a str>,
    consumed: &mut HashSet<&'a str>,
    key: &str,
) -> Result<usize, Box<dyn Error>> {
    let value = required_canonical_compiler_mir_fixture_field(fields, consumed, key)?;
    value.parse::<usize>().map_err(|_| {
        IoError::new(
            ErrorKind::InvalidInput,
            format!("canonical compiler MIR fixture field {key} must be a usize, got {value}"),
        )
        .into()
    })
}

fn parse_canonical_compiler_mir_i32_field<'a>(
    fields: &HashMap<&'a str, &'a str>,
    consumed: &mut HashSet<&'a str>,
    key: &str,
) -> Result<i32, Box<dyn Error>> {
    let value = required_canonical_compiler_mir_fixture_field(fields, consumed, key)?;
    value.parse::<i32>().map_err(|_| {
        IoError::new(
            ErrorKind::InvalidInput,
            format!("canonical compiler MIR fixture field {key} must be an i32, got {value}"),
        )
        .into()
    })
}

fn parse_optional_canonical_compiler_mir_usize_field<'a>(
    fields: &HashMap<&'a str, &'a str>,
    consumed: &mut HashSet<&'a str>,
    key: &str,
    default: usize,
) -> Result<usize, Box<dyn Error>> {
    let Some((stored_key, value)) = fields.get_key_value(key) else {
        return Ok(default);
    };
    consumed.insert(*stored_key);
    value.parse::<usize>().map_err(|_| {
        IoError::new(
            ErrorKind::InvalidInput,
            format!("canonical compiler MIR fixture field {key} must be a usize, got {value}"),
        )
        .into()
    })
}

fn parse_canonical_compiler_mir_edge_arguments<'a>(
    fields: &HashMap<&'a str, &'a str>,
    consumed: &mut HashSet<&'a str>,
    prefix: &str,
) -> Result<Vec<CompilerMirLoweringEdgeArgument<'a>>, Box<dyn Error>> {
    let argument_count_key = format!("{prefix}_argument_count");
    let argument_count = parse_optional_canonical_compiler_mir_usize_field(
        fields,
        consumed,
        &argument_count_key,
        0,
    )?;
    let mut arguments = Vec::with_capacity(argument_count);
    for argument_index in 0..argument_count {
        let argument_prefix = format!("{prefix}_argument_{argument_index}");
        let kind_key = format!("{argument_prefix}_kind");
        let kind = required_canonical_compiler_mir_fixture_field(
            fields,
            consumed,
            &kind_key,
        )?;
        let argument = match kind {
            "I32Literal" => {
                let value_key = format!("{argument_prefix}_value");
                CompilerMirLoweringEdgeArgument::I32Literal(
                    parse_canonical_compiler_mir_i32_field(
                        fields,
                        consumed,
                        &value_key,
                    )?,
                )
            }
            "FunctionParamI32" => {
                let param_key = format!("{argument_prefix}_param");
                CompilerMirLoweringEdgeArgument::FunctionParamI32(
                    parse_canonical_compiler_mir_usize_field(
                        fields,
                        consumed,
                        &param_key,
                    )?,
                )
            }
            "LocalI32" => {
                let local_key = format!("{argument_prefix}_local");
                CompilerMirLoweringEdgeArgument::LocalI32(
                    required_canonical_compiler_mir_fixture_field(
                        fields,
                        consumed,
                        &local_key,
                    )?,
                )
            }
            "BlockParamI32" => {
                let block_param_key = format!("{argument_prefix}_block_param");
                CompilerMirLoweringEdgeArgument::BlockParamI32(
                    required_canonical_compiler_mir_fixture_field(
                        fields,
                        consumed,
                        &block_param_key,
                    )?,
                )
            }
            "BlockParamI32AddI32Literal" => {
                let block_param_key = format!("{argument_prefix}_block_param");
                let value_key = format!("{argument_prefix}_value");
                CompilerMirLoweringEdgeArgument::BlockParamI32AddI32Literal {
                    name: required_canonical_compiler_mir_fixture_field(
                        fields,
                        consumed,
                        &block_param_key,
                    )?,
                    value: parse_canonical_compiler_mir_i32_field(
                        fields,
                        consumed,
                        &value_key,
                    )?,
                }
            }
            other => {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "unsupported canonical compiler MIR edge argument kind at {kind_key}: {other}"
                    ),
                )
                .into());
            }
        };
        arguments.push(argument);
    }
    Ok(arguments)
}

fn parse_canonical_compiler_mir_type(
    value: &str,
    key: &str,
) -> Result<TinyMirType, Box<dyn Error>> {
    match value {
        "int" => Ok(TinyMirType::I32),
        "void" => Ok(TinyMirType::Void),
        other => Err(IoError::new(
            ErrorKind::InvalidInput,
            format!("unsupported canonical compiler MIR type at {key}: {other}"),
        )
        .into()),
    }
}

fn validate_canonical_compiler_mir_name(
    value: &str,
    field: &str,
) -> Result<(), Box<dyn Error>> {
    let mut chars = value.chars();
    let Some(first) = chars.next() else {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            format!("canonical compiler MIR fixture {field} must not be empty"),
        )
        .into());
    };
    if !(first == '_' || first.is_ascii_alphabetic())
        || chars.any(|ch| !(ch == '_' || ch.is_ascii_alphanumeric()))
    {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            format!(
                "canonical compiler MIR fixture {field} must be an ASCII identifier, got {value}"
            ),
        )
        .into());
    }
    Ok(())
}

fn validate_canonical_compiler_mir_local_reference(
    local_names: &HashSet<&str>,
    name: &str,
    block: &str,
    statement_index: usize,
) -> Result<(), Box<dyn Error>> {
    if !local_names.contains(name) {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            format!(
                "unknown canonical compiler MIR local {name} at block {block} statement {statement_index}"
            ),
        )
        .into());
    }
    Ok(())
}

fn validate_canonical_compiler_mir_block_target(
    block_indices: &HashMap<&str, usize>,
    target: &str,
    source: &str,
    edge: &str,
) -> Result<(), Box<dyn Error>> {
    if !block_indices.contains_key(target) {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            format!(
                "unknown canonical compiler MIR {edge} target {target} from block {source}"
            ),
        )
        .into());
    }
    Ok(())
}

fn validate_canonical_compiler_mir_reachability(
    function: &CompilerMirLoweringFunction<'_>,
    block_indices: &HashMap<&str, usize>,
) -> Result<(), Box<dyn Error>> {
    let mut reachable: HashSet<&str> = HashSet::new();
    let mut pending: VecDeque<&str> = VecDeque::new();
    pending.push_back(function.entry_block);
    let mut has_reachable_return = false;

    while let Some(label) = pending.pop_front() {
        if !reachable.insert(label) {
            continue;
        }
        let block_index = *block_indices.get(label).ok_or_else(|| {
            IoError::new(
                ErrorKind::InvalidInput,
                format!("unknown canonical compiler MIR reachable block: {label}"),
            )
        })?;
        match &function.blocks[block_index].terminator {
            CompilerMirLoweringTerminator::ReturnI32(_)
            | CompilerMirLoweringTerminator::ReturnLocalI32(_)
            | CompilerMirLoweringTerminator::ReturnBlockParamI32(_)
            | CompilerMirLoweringTerminator::ReturnVoid => {
                has_reachable_return = true;
            }
            CompilerMirLoweringTerminator::Jump { edge } => {
                pending.push_back(edge.target);
            }
            CompilerMirLoweringTerminator::BranchI32Literal {
                then_edge,
                else_edge,
                ..
            }
            | CompilerMirLoweringTerminator::BranchLocalI32Positive {
                then_edge,
                else_edge,
                ..
            }
            | CompilerMirLoweringTerminator::BranchBlockParamI32Positive {
                then_edge,
                else_edge,
                ..
            } => {
                pending.push_back(then_edge.target);
                pending.push_back(else_edge.target);
            }
        }
    }

    if !has_reachable_return {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            "canonical compiler MIR fixture entry graph has no reachable Return terminator",
        )
        .into());
    }
    if reachable.len() != function.blocks.len() {
        let mut unreachable: Vec<&str> = function
            .blocks
            .iter()
            .map(|block| block.label)
            .filter(|label| !reachable.contains(*label))
            .collect();
        unreachable.sort_unstable();
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            format!(
                "canonical compiler MIR fixture has unreachable block(s): {}",
                unreachable.join(",")
            ),
        )
        .into());
    }

    Ok(())
}

fn validate_canonical_compiler_mir_metadata_attachment(
    attachment: &str,
    block_indices: &HashMap<&str, usize>,
    blocks: &[CompilerMirLoweringBlock<'_>],
    metadata_index: usize,
) -> Result<(), Box<dyn Error>> {
    if attachment == "function" {
        return Ok(());
    }

    if let Some(label) = attachment.strip_prefix("block:") {
        if block_indices.contains_key(label) {
            return Ok(());
        }
    } else if let Some(label) = attachment.strip_prefix("terminator:") {
        if block_indices.contains_key(label) {
            return Ok(());
        }
    } else if let Some(rest) = attachment.strip_prefix("statement:") {
        if let Some((label, index_text)) = rest.rsplit_once(':') {
            if let (Some(block_index), Ok(statement_index)) = (
                block_indices.get(label).copied(),
                index_text.parse::<usize>(),
            ) {
                if statement_index < blocks[block_index].statements.len() {
                    return Ok(());
                }
            }
        }
    }

    Err(IoError::new(
        ErrorKind::InvalidInput,
        format!(
            "invalid canonical compiler MIR metadata attachment at metadata {metadata_index}: {attachment}"
        ),
    )
    .into())
}

fn validate_compiler_mir_fixture_path(input_path: &Path) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    let fixture = parse_compiler_mir_fixture(&contents)?;
    validate_compiler_mir_fixture(&fixture)?;
    println!(
        "validated canonical compiler MIR fixture: {} -> {}",
        fixture.function.object_name, fixture.function.symbol
    );
    Ok(())
}

fn emit_compiler_mir_fixture_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    emit_compiler_mir_fixture_contents_object(&contents, output_path)
}

fn emit_compiler_mir_fixture_contents_object(
    contents: &str,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let fixture = parse_compiler_mir_fixture(contents)?;
    validate_compiler_mir_fixture(&fixture)?;
    recognize_compiler_mir_fixture_metadata(&fixture.metadata)?;
    lower_compiler_mir_ingestion_function_to_object(output_path, &fixture.function)
}

fn recognize_compiler_mir_fixture_metadata(
    metadata: &[CompilerMirFixtureMetadata<'_>],
) -> Result<(), Box<dyn Error>> {
    for (index, item) in metadata.iter().enumerate() {
        match (item.kind, item.policy) {
            (
                "provenance" | "resource" | "native_boundary",
                "recognized_preserved" | "ignored_with_proof",
            ) => {}
            _ => {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "unsupported canonical compiler MIR metadata lowering policy at metadata {index}: kind={} policy={}",
                        item.kind, item.policy
                    ),
                )
                .into());
            }
        }
    }
    Ok(())
}

fn parse_compiler_mir_ingestion_fields(
    contents: &str,
) -> Result<HashMap<&str, &str>, Box<dyn Error>> {
    let mut fields: HashMap<&str, &str> = HashMap::new();
    for raw_line in contents.lines() {
        let line = raw_line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let Some((key, value)) = line.split_once(':') else {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!("invalid compiler MIR ingestion fixture line: {line}"),
            )
            .into());
        };
        fields.insert(key.trim(), value.trim());
    }
    Ok(fields)
}

fn required_compiler_mir_ingestion_field<'a>(
    fields: &'a HashMap<&str, &str>,
    key: &str,
) -> Result<&'a str, Box<dyn Error>> {
    fields.get(key).copied().ok_or_else(|| {
        IoError::new(
            ErrorKind::InvalidInput,
            format!("missing compiler MIR ingestion fixture field: {key}"),
        )
        .into()
    })
}

fn require_compiler_mir_ingestion_field(
    fields: &HashMap<&str, &str>,
    key: &str,
    expected: &str,
) -> Result<(), Box<dyn Error>> {
    let actual = required_compiler_mir_ingestion_field(fields, key)?;
    if actual != expected {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            format!("compiler MIR ingestion fixture field {key} expected {expected}, got {actual}"),
        )
        .into());
    }
    Ok(())
}

fn emit_compiler_mir_to_cranelift_local_binding_read_translator_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_local_binding_read_ingestion_fixture(&contents)?;
    let mir_function = translate_compiler_mir_local_binding_read_fixture_to_tiny_mir_function();
    lower_tiny_mir_function_to_object(output_path, &mir_function)
}

fn translate_compiler_mir_local_binding_read_fixture_to_tiny_mir_function() -> TinyMirFunction {
    TinyMirFunction {
        object_name: "gust_native_backend_mir_to_cranelift_local_binding_read_translator",
        symbol: COMPILER_MIR_TO_CRANELIFT_LOCAL_BINDING_READ_TRANSLATOR_SYMBOL,
        params: &[],
        return_type: TinyMirType::I32,
        locals: &MIR_LOCAL_BINDING_READ_LOCALS,
        statements: &MIR_LOCAL_BINDING_READ_STATEMENTS,
        terminator: TinyMirTerminator::ReturnLocalI32("value"),
    }
}

fn emit_compiler_mir_local_binding_read_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_local_binding_read_ingestion_fixture(&contents)?;
    emit_compiler_mir_fixture_contents_object(
        PHASE9C_CANONICAL_LOCAL_BINDING_READ_FIXTURE,
        output_path,
    )
}

fn parse_compiler_mir_local_binding_read_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;

    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.local_binding_read.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_local_binding_read_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "mir_lower_local_binding_read_fixture",
    )?;
    require_compiler_mir_ingestion_field(&fields, "function", "tiny_local_binding_read")?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "local_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "local_0_name", "value")?;
    require_compiler_mir_ingestion_field(&fields, "local_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "statement_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "statement_0_kind", "LocalI32Set")?;
    require_compiler_mir_ingestion_field(&fields, "statement_0_local", "value")?;
    require_compiler_mir_ingestion_field(&fields, "statement_0_value", "2")?;
    require_compiler_mir_ingestion_field(&fields, "terminator", "ReturnLocal")?;
    require_compiler_mir_ingestion_field(&fields, "return_local", "value")?;
    require_compiler_mir_ingestion_field(&fields, "return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_LOCAL_BINDING_READ_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_exit", "2")?;

    Ok(())
}

fn emit_compiler_mir_to_cranelift_conditional_branch_translator_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_conditional_branch_ingestion_fixture(&contents)?;
    let mir_function = translate_compiler_mir_conditional_branch_fixture_to_tiny_mir_function();
    lower_tiny_mir_function_to_object(output_path, &mir_function)
}

fn translate_compiler_mir_conditional_branch_fixture_to_tiny_mir_function() -> TinyMirFunction {
    TinyMirFunction {
        object_name: "gust_native_backend_mir_to_cranelift_conditional_branch_translator",
        symbol: COMPILER_MIR_TO_CRANELIFT_CONDITIONAL_BRANCH_TRANSLATOR_SYMBOL,
        params: &[],
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::BranchI32Literal {
            condition: 1,
            then_return: 1,
            else_return: 2,
        },
    }
}

fn emit_compiler_mir_conditional_branch_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_conditional_branch_ingestion_fixture(&contents)?;
    emit_compiler_mir_fixture_contents_object(
        PHASE9C_CANONICAL_CONDITIONAL_BRANCH_FIXTURE,
        output_path,
    )
}

fn parse_compiler_mir_conditional_branch_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;

    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.conditional_branch.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_conditional_branch_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "mir_lower_conditional_branch_fixture",
    )?;
    require_compiler_mir_ingestion_field(&fields, "function", "tiny_conditional_branch")?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "3")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_terminator", "Branch")?;
    require_compiler_mir_ingestion_field(&fields, "branch_condition_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "branch_condition_value", "1")?;
    require_compiler_mir_ingestion_field(&fields, "branch_condition_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_block", "1")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_block", "2")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_return_value", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value", "2")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_CONDITIONAL_BRANCH_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_exit", "1")?;

    Ok(())
}

fn emit_compiler_mir_add_i32_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_add_i32_ingestion_fixture(&contents)?;
    emit_compiler_mir_fixture_contents_object(PHASE9D_CANONICAL_ADD_I32_FIXTURE, output_path)
}

fn parse_compiler_mir_add_i32_ingestion_fixture(contents: &str) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.add_i32.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_add_i32_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_add_i32_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_param_add_i32_serialization",
    )?;
    require_compiler_mir_ingestion_field(&fields, "function", "tiny_add_i32")?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "2")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_name", "lhs")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "param_1_name", "rhs")?;
    require_compiler_mir_ingestion_field(&fields, "param_1_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "terminator", "ReturnParamAdd")?;
    require_compiler_mir_ingestion_field(&fields, "lhs_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "rhs_param", "1")?;
    require_compiler_mir_ingestion_field(&fields, "return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_ADD_I32_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_count", "2")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_lhs", "2")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_rhs", "3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "5")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_lhs", "0")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_rhs", "4")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "4")?;
    Ok(())
}

fn emit_compiler_mir_to_cranelift_block_local_branch_join_translator_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_local_branch_join_ingestion_fixture(&contents)?;
    let mir_function =
        translate_compiler_mir_block_local_branch_join_fixture_to_tiny_mir_block_function();

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_mir_to_cranelift_block_local_branch_join_translator",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);
    define_tiny_mir_block_graph_exported_function(&mut module, &mir_function)?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn translate_compiler_mir_block_local_branch_join_fixture_to_tiny_mir_block_function()
-> TinyMirBlockFunction {
    static MIR_TO_CRANELIFT_BLOCK_LOCAL_BRANCH_JOIN_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static MIR_TO_CRANELIFT_BLOCK_LOCAL_BRANCH_JOIN_LOCALS: [TinyMirLocal; 1] = [TinyMirLocal {
        name: "value",
        ty: TinyMirType::I32,
    }];
    static MIR_TO_CRANELIFT_BLOCK_LOCAL_BRANCH_JOIN_ENTRY_STATEMENTS: [TinyMirBlockStatement; 1] =
        [TinyMirBlockStatement::LocalI32SetParam {
            name: "value",
            param: 0,
        }];
    static MIR_TO_CRANELIFT_BLOCK_LOCAL_BRANCH_JOIN_POSITIVE_STATEMENTS: [TinyMirBlockStatement;
        1] = [TinyMirBlockStatement::LocalI32AddI32Literal {
        name: "value",
        value: 4,
    }];
    static MIR_TO_CRANELIFT_BLOCK_LOCAL_BRANCH_JOIN_NON_POSITIVE_STATEMENTS:
        [TinyMirBlockStatement; 1] = [TinyMirBlockStatement::LocalI32AddI32Literal {
        name: "value",
        value: 8,
    }];
    static MIR_TO_CRANELIFT_BLOCK_LOCAL_BRANCH_JOIN_BLOCKS: [TinyMirBlock; 4] = [
        TinyMirBlock {
            label: "entry",
            statements: &MIR_TO_CRANELIFT_BLOCK_LOCAL_BRANCH_JOIN_ENTRY_STATEMENTS,
            terminator: TinyMirBlockTerminator::BranchLocalI32Positive {
                name: "value",
                then_block: "positive",
                else_block: "non_positive",
            },
        },
        TinyMirBlock {
            label: "positive",
            statements: &MIR_TO_CRANELIFT_BLOCK_LOCAL_BRANCH_JOIN_POSITIVE_STATEMENTS,
            terminator: TinyMirBlockTerminator::Jump { target: "join" },
        },
        TinyMirBlock {
            label: "non_positive",
            statements: &MIR_TO_CRANELIFT_BLOCK_LOCAL_BRANCH_JOIN_NON_POSITIVE_STATEMENTS,
            terminator: TinyMirBlockTerminator::Jump { target: "join" },
        },
        TinyMirBlock {
            label: "join",
            statements: &[],
            terminator: TinyMirBlockTerminator::ReturnLocalI32("value"),
        },
    ];

    TinyMirBlockFunction {
        object_name: "gust_native_backend_mir_to_cranelift_block_local_branch_join_translator",
        symbol: COMPILER_MIR_TO_CRANELIFT_BLOCK_LOCAL_BRANCH_JOIN_TRANSLATOR_SYMBOL,
        params: &MIR_TO_CRANELIFT_BLOCK_LOCAL_BRANCH_JOIN_PARAMS,
        return_type: TinyMirType::I32,
        locals: &MIR_TO_CRANELIFT_BLOCK_LOCAL_BRANCH_JOIN_LOCALS,
        entry_block: "entry",
        blocks: &MIR_TO_CRANELIFT_BLOCK_LOCAL_BRANCH_JOIN_BLOCKS,
    }
}

fn emit_compiler_mir_to_cranelift_block_param_merge_dual_imported_joined_return_translator_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_merge_dual_imported_joined_return_ingestion_fixture(&contents)?;
    let mir_function =
        translate_compiler_mir_block_param_merge_dual_imported_joined_return_fixture_to_tiny_mir_param_block_function();

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_mir_to_cranelift_block_param_merge_dual_imported_joined_return_translator",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut branch_signature = module.make_signature();
    branch_signature.params.push(AbiParam::new(types::I32));
    branch_signature.params.push(AbiParam::new(types::I32));
    branch_signature.returns.push(AbiParam::new(types::I32));
    let branch_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_BRANCH_HOST_ADD_SYMBOL,
        Linkage::Import,
        &branch_signature,
    )?;

    let mut return_signature = module.make_signature();
    return_signature.params.push(AbiParam::new(types::I32));
    return_signature.params.push(AbiParam::new(types::I32));
    return_signature.returns.push(AbiParam::new(types::I32));
    let return_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_RETURN_HOST_ADD_SYMBOL,
        Linkage::Import,
        &return_signature,
    )?;

    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_BRANCH_HOST_ADD_SYMBOL,
        branch_id,
    );
    imported_function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_RETURN_HOST_ADD_SYMBOL,
        return_id,
    );

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &imported_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn translate_compiler_mir_block_param_merge_dual_imported_joined_return_fixture_to_tiny_mir_param_block_function()
-> TinyMirParamBlockFunction {
    static MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_FUNCTION_PARAMS:
        [TinyMirType; 1] = [TinyMirType::I32];
    static MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_BLOCK_PARAMS:
        [TinyMirType; 1] = [TinyMirType::I32];
    static MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_BLOCKS: [TinyMirParamBlock; 9] = [
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
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "branch",
                param: 0,
                value: 4,
            },
        },
        TinyMirParamBlock {
            label: "branch",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "then_value",
                then_value: 211,
                else_block: "else_value",
                else_value: 223,
            },
        },
        TinyMirParamBlock {
            label: "then_value",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 7,
            },
        },
        TinyMirParamBlock {
            label: "else_value",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 9,
            },
        },
        TinyMirParamBlock {
            label: "join",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32CallI32LiteralPositive {
                function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_BRANCH_HOST_ADD_SYMBOL,
                param: 0,
                value: -220,
                then_block: "positive_value",
                else_block: "non_positive_value",
            },
        },
        TinyMirParamBlock {
            label: "positive_value",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpI32Literal {
                target: "return_join",
                value: 241,
            },
        },
        TinyMirParamBlock {
            label: "non_positive_value",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpI32Literal {
                target: "return_join",
                value: 251,
            },
        },
        TinyMirParamBlock {
            label: "return_join",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal {
                function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_RETURN_HOST_ADD_SYMBOL,
                param: 0,
                value: 4,
            },
        },
    ];

    TinyMirParamBlockFunction {
        object_name: "gust_native_backend_mir_to_cranelift_block_param_merge_dual_imported_joined_return_translator",
        symbol: COMPILER_MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_TRANSLATOR_SYMBOL,
        params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_BLOCKS,
    }
}

fn emit_compiler_mir_to_cranelift_block_param_merge_imported_branch_joined_return_translator_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_merge_imported_branch_joined_return_ingestion_fixture(
        &contents,
    )?;
    let mir_function =
        translate_compiler_mir_block_param_merge_imported_branch_joined_return_fixture_to_tiny_mir_param_block_function();

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_mir_to_cranelift_block_param_merge_imported_branch_joined_return_translator",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut imported_add_signature = module.make_signature();
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .returns
        .push(AbiParam::new(types::I32));
    let imported_add_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_HOST_ADD_SYMBOL,
        Linkage::Import,
        &imported_add_signature,
    )?;
    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_HOST_ADD_SYMBOL,
        imported_add_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &imported_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn translate_compiler_mir_block_param_merge_imported_branch_joined_return_fixture_to_tiny_mir_param_block_function()
-> TinyMirParamBlockFunction {
    static MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_FUNCTION_PARAMS:
        [TinyMirType; 1] = [TinyMirType::I32];
    static MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_BLOCK_PARAMS:
        [TinyMirType; 1] = [TinyMirType::I32];
    static MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_BLOCKS: [TinyMirParamBlock; 9] = [
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
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "branch",
                param: 0,
                value: 4,
            },
        },
        TinyMirParamBlock {
            label: "branch",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "then_value",
                then_value: 211,
                else_block: "else_value",
                else_value: 223,
            },
        },
        TinyMirParamBlock {
            label: "then_value",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 7,
            },
        },
        TinyMirParamBlock {
            label: "else_value",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 9,
            },
        },
        TinyMirParamBlock {
            label: "join",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32CallI32LiteralPositive {
                function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_HOST_ADD_SYMBOL,
                param: 0,
                value: -220,
                then_block: "positive_value",
                else_block: "non_positive_value",
            },
        },
        TinyMirParamBlock {
            label: "positive_value",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpI32Literal {
                target: "return_join",
                value: 241,
            },
        },
        TinyMirParamBlock {
            label: "non_positive_value",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpI32Literal {
                target: "return_join",
                value: 251,
            },
        },
        TinyMirParamBlock {
            label: "return_join",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal {
                function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_HOST_ADD_SYMBOL,
                param: 0,
                value: 3,
            },
        },
    ];

    TinyMirParamBlockFunction {
        object_name: "gust_native_backend_mir_to_cranelift_block_param_merge_imported_branch_joined_return_translator",
        symbol: COMPILER_MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_TRANSLATOR_SYMBOL,
        params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_BLOCKS,
    }
}

fn emit_compiler_mir_to_cranelift_block_param_merge_arm_update_imported_call_branch_translator_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_merge_arm_update_imported_call_branch_ingestion_fixture(
        &contents,
    )?;
    let mir_function =
        translate_compiler_mir_block_param_merge_arm_update_imported_call_branch_fixture_to_tiny_mir_param_block_function();

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_mir_to_cranelift_block_param_merge_arm_update_imported_call_branch_translator",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut imported_add_signature = module.make_signature();
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .returns
        .push(AbiParam::new(types::I32));
    let imported_add_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_HOST_ADD_SYMBOL,
        Linkage::Import,
        &imported_add_signature,
    )?;
    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_HOST_ADD_SYMBOL,
        imported_add_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &imported_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn translate_compiler_mir_block_param_merge_arm_update_imported_call_branch_fixture_to_tiny_mir_param_block_function()
-> TinyMirParamBlockFunction {
    static MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_FUNCTION_PARAMS:
        [TinyMirType; 1] = [TinyMirType::I32];
    static MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_BLOCK_PARAMS:
        [TinyMirType; 1] = [TinyMirType::I32];
    static MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_BLOCKS: [TinyMirParamBlock; 8] = [
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
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "branch",
                param: 0,
                value: 4,
            },
        },
        TinyMirParamBlock {
            label: "branch",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "then_value",
                then_value: 211,
                else_block: "else_value",
                else_value: 223,
            },
        },
        TinyMirParamBlock {
            label: "then_value",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 7,
            },
        },
        TinyMirParamBlock {
            label: "else_value",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 9,
            },
        },
        TinyMirParamBlock {
            label: "join",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32CallI32LiteralPositive {
                function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_HOST_ADD_SYMBOL,
                param: 0,
                value: -220,
                then_block: "positive",
                else_block: "non_positive",
            },
        },
        TinyMirParamBlock {
            label: "positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(241),
        },
        TinyMirParamBlock {
            label: "non_positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(251),
        },
    ];

    TinyMirParamBlockFunction {
        object_name: "gust_native_backend_mir_to_cranelift_block_param_merge_arm_update_imported_call_branch_translator",
        symbol: COMPILER_MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_TRANSLATOR_SYMBOL,
        params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_BLOCKS,
    }
}

fn emit_compiler_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_merge_arm_update_imported_call_return_ingestion_fixture(
        &contents,
    )?;
    let mir_function =
        translate_compiler_mir_block_param_merge_arm_update_imported_call_return_fixture_to_tiny_mir_param_block_function();

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut imported_add_signature = module.make_signature();
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .returns
        .push(AbiParam::new(types::I32));
    let imported_add_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
        Linkage::Import,
        &imported_add_signature,
    )?;
    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
        imported_add_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &imported_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn translate_compiler_mir_block_param_merge_arm_update_imported_call_return_fixture_to_tiny_mir_param_block_function()
-> TinyMirParamBlockFunction {
    static MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_FUNCTION_PARAMS:
        [TinyMirType; 1] = [TinyMirType::I32];
    static MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_BLOCK_PARAMS:
        [TinyMirType; 1] = [TinyMirType::I32];
    static MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_BLOCKS: [TinyMirParamBlock; 6] = [
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
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "branch",
                param: 0,
                value: 4,
            },
        },
        TinyMirParamBlock {
            label: "branch",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "then_value",
                then_value: 211,
                else_block: "else_value",
                else_value: 223,
            },
        },
        TinyMirParamBlock {
            label: "then_value",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 7,
            },
        },
        TinyMirParamBlock {
            label: "else_value",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 9,
            },
        },
        TinyMirParamBlock {
            label: "join",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal {
                function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
                param: 0,
                value: 5,
            },
        },
    ];

    TinyMirParamBlockFunction {
        object_name: "gust_native_backend_mir_to_cranelift_block_param_merge_arm_update_imported_call_return_translator",
        symbol: COMPILER_MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_TRANSLATOR_SYMBOL,
        params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_BLOCKS,
    }
}

fn emit_compiler_mir_to_cranelift_block_param_merge_imported_call_return_translator_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_merge_imported_call_return_ingestion_fixture(&contents)?;
    let mir_function =
        translate_compiler_mir_block_param_merge_imported_call_return_fixture_to_tiny_mir_param_block_function();

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_mir_to_cranelift_block_param_merge_imported_call_return_translator",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut imported_add_signature = module.make_signature();
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .returns
        .push(AbiParam::new(types::I32));
    let imported_add_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
        Linkage::Import,
        &imported_add_signature,
    )?;
    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
        imported_add_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &imported_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn translate_compiler_mir_block_param_merge_imported_call_return_fixture_to_tiny_mir_param_block_function()
-> TinyMirParamBlockFunction {
    static MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_FUNCTION_PARAMS: [TinyMirType;
        1] = [TinyMirType::I32];
    static MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_BLOCK_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_BLOCKS: [TinyMirParamBlock; 6] = [
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
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "branch",
                param: 0,
                value: 4,
            },
        },
        TinyMirParamBlock {
            label: "branch",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "then_value",
                then_value: 211,
                else_block: "else_value",
                else_value: 223,
            },
        },
        TinyMirParamBlock {
            label: "then_value",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 0,
            },
        },
        TinyMirParamBlock {
            label: "else_value",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 0,
            },
        },
        TinyMirParamBlock {
            label: "join",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator:
                TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal {
                    function_symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
                    param: 0,
                    value: 5,
                },
        },
    ];

    TinyMirParamBlockFunction {
        object_name: "gust_native_backend_mir_to_cranelift_block_param_merge_imported_call_return_translator",
        symbol: COMPILER_MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_TRANSLATOR_SYMBOL,
        params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_BLOCKS,
    }
}

fn emit_compiler_mir_to_cranelift_block_param_merge_update_branch_translator_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_merge_update_branch_ingestion_fixture(&contents)?;
    let mir_function =
        translate_compiler_mir_block_param_merge_update_branch_fixture_to_tiny_mir_param_block_function();

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_mir_to_cranelift_block_param_merge_update_branch_translator",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);
    let local_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &local_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn translate_compiler_mir_block_param_merge_update_branch_fixture_to_tiny_mir_param_block_function()
-> TinyMirParamBlockFunction {
    static MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_UPDATE_BRANCH_FUNCTION_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_UPDATE_BRANCH_BLOCK_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_UPDATE_BRANCH_BLOCKS: [TinyMirParamBlock; 6] = [
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
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_UPDATE_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "branch",
                param: 0,
                value: 4,
            },
        },
        TinyMirParamBlock {
            label: "branch",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_UPDATE_BRANCH_BLOCK_PARAMS,
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
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_UPDATE_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 0,
            },
        },
        TinyMirParamBlock {
            label: "else_value",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_UPDATE_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 0,
            },
        },
        TinyMirParamBlock {
            label: "join",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_UPDATE_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamI32(0),
        },
    ];

    TinyMirParamBlockFunction {
        object_name: "gust_native_backend_mir_to_cranelift_block_param_merge_update_branch_translator",
        symbol: COMPILER_MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_UPDATE_BRANCH_TRANSLATOR_SYMBOL,
        params: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_UPDATE_BRANCH_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_TO_CRANELIFT_BLOCK_PARAM_MERGE_UPDATE_BRANCH_BLOCKS,
    }
}

fn emit_compiler_mir_to_cranelift_block_param_update_branch_translator_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_update_branch_ingestion_fixture(&contents)?;
    let mir_function =
        translate_compiler_mir_block_param_update_branch_fixture_to_tiny_mir_param_block_function();

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_mir_to_cranelift_block_param_update_branch_translator",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);
    let local_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &local_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn translate_compiler_mir_block_param_update_branch_fixture_to_tiny_mir_param_block_function()
-> TinyMirParamBlockFunction {
    static MIR_TO_CRANELIFT_BLOCK_PARAM_UPDATE_BRANCH_FUNCTION_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static MIR_TO_CRANELIFT_BLOCK_PARAM_UPDATE_BRANCH_BLOCK_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static MIR_TO_CRANELIFT_BLOCK_PARAM_UPDATE_BRANCH_BLOCKS: [TinyMirParamBlock; 5] = [
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
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_UPDATE_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "branch",
                param: 0,
                value: 4,
            },
        },
        TinyMirParamBlock {
            label: "branch",
            params: &MIR_TO_CRANELIFT_BLOCK_PARAM_UPDATE_BRANCH_BLOCK_PARAMS,
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

    TinyMirParamBlockFunction {
        object_name: "gust_native_backend_mir_to_cranelift_block_param_update_branch_translator",
        symbol: COMPILER_MIR_TO_CRANELIFT_BLOCK_PARAM_UPDATE_BRANCH_TRANSLATOR_SYMBOL,
        params: &MIR_TO_CRANELIFT_BLOCK_PARAM_UPDATE_BRANCH_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &MIR_TO_CRANELIFT_BLOCK_PARAM_UPDATE_BRANCH_BLOCKS,
    }
}

fn emit_compiler_mir_to_cranelift_positive_i32_branch_translator_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_positive_i32_branch_ingestion_fixture(&contents)?;
    let mir_function = translate_compiler_mir_positive_i32_branch_fixture_to_tiny_mir_function();
    lower_tiny_mir_function_to_object(output_path, &mir_function)
}

fn translate_compiler_mir_positive_i32_branch_fixture_to_tiny_mir_function() -> TinyMirFunction {
    static MIR_TO_CRANELIFT_POSITIVE_I32_BRANCH_TRANSLATOR_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];

    TinyMirFunction {
        object_name: "gust_native_backend_mir_to_cranelift_positive_i32_branch_translator",
        symbol: COMPILER_MIR_TO_CRANELIFT_POSITIVE_I32_BRANCH_TRANSLATOR_SYMBOL,
        params: &MIR_TO_CRANELIFT_POSITIVE_I32_BRANCH_TRANSLATOR_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::BranchParamI32Positive {
            param: 0,
            then_return: 7,
            else_return: 9,
        },
    }
}

fn emit_compiler_mir_to_cranelift_add_i32_translator_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_add_i32_ingestion_fixture(&contents)?;
    let mir_function = translate_compiler_mir_add_i32_fixture_to_tiny_mir_function();
    lower_tiny_mir_function_to_object(output_path, &mir_function)
}

fn translate_compiler_mir_add_i32_fixture_to_tiny_mir_function() -> TinyMirFunction {
    static MIR_TO_CRANELIFT_ADD_I32_TRANSLATOR_PARAMS: [TinyMirType; 2] =
        [TinyMirType::I32, TinyMirType::I32];

    TinyMirFunction {
        object_name: "gust_native_backend_mir_to_cranelift_add_i32_translator",
        symbol: COMPILER_MIR_TO_CRANELIFT_ADD_I32_TRANSLATOR_SYMBOL,
        params: &MIR_TO_CRANELIFT_ADD_I32_TRANSLATOR_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32Add {
            lhs_param: 0,
            rhs_param: 1,
        },
    }
}

fn emit_compiler_mir_to_cranelift_provenance_metadata_translator_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_provenance_metadata_ingestion_fixture(&contents)?;
    let mir_function = translate_compiler_mir_provenance_metadata_fixture_to_tiny_mir_function();
    lower_tiny_mir_function_to_object(output_path, &mir_function)
}

fn translate_compiler_mir_provenance_metadata_fixture_to_tiny_mir_function() -> TinyMirFunction {
    TinyMirFunction {
        object_name: "gust_native_backend_mir_to_cranelift_provenance_metadata_translator",
        symbol: COMPILER_MIR_TO_CRANELIFT_PROVENANCE_METADATA_TRANSLATOR_SYMBOL,
        params: &[],
        return_type: TinyMirType::I32,
        locals: &MIR_LOCAL_BINDING_READ_LOCALS,
        statements: &MIR_LOCAL_BINDING_READ_STATEMENTS,
        terminator: TinyMirTerminator::ReturnLocalI32("value"),
    }
}

fn emit_compiler_mir_to_cranelift_resource_metadata_translator_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_resource_metadata_ingestion_fixture(&contents)?;
    let mir_function = translate_compiler_mir_resource_metadata_fixture_to_tiny_mir_function();
    lower_tiny_mir_function_to_object(output_path, &mir_function)
}

fn translate_compiler_mir_resource_metadata_fixture_to_tiny_mir_function() -> TinyMirFunction {
    TinyMirFunction {
        object_name: "gust_native_backend_mir_to_cranelift_resource_metadata_translator",
        symbol: COMPILER_MIR_TO_CRANELIFT_RESOURCE_METADATA_TRANSLATOR_SYMBOL,
        params: &[],
        return_type: TinyMirType::I32,
        locals: &MIR_LOCAL_BINDING_READ_LOCALS,
        statements: &MIR_LOCAL_BINDING_READ_STATEMENTS,
        terminator: TinyMirTerminator::ReturnLocalI32("value"),
    }
}

fn emit_compiler_mir_to_cranelift_native_boundary_metadata_translator_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_native_boundary_metadata_ingestion_fixture(&contents)?;
    let mir_function =
        translate_compiler_mir_native_boundary_metadata_fixture_to_tiny_mir_function();
    lower_tiny_mir_function_to_object(output_path, &mir_function)
}

fn translate_compiler_mir_native_boundary_metadata_fixture_to_tiny_mir_function() -> TinyMirFunction
{
    TinyMirFunction {
        object_name: "gust_native_backend_mir_to_cranelift_native_boundary_metadata_translator",
        symbol: COMPILER_MIR_TO_CRANELIFT_NATIVE_BOUNDARY_METADATA_TRANSLATOR_SYMBOL,
        params: &[],
        return_type: TinyMirType::Void,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnVoid,
    }
}

fn emit_compiler_mir_provenance_metadata_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_provenance_metadata_ingestion_fixture(&contents)?;
    emit_compiler_mir_fixture_contents_object(
        PHASE9C_CANONICAL_PROVENANCE_METADATA_FIXTURE,
        output_path,
    )
}

fn parse_compiler_mir_provenance_metadata_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.provenance_metadata.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_provenance_metadata_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_local_binding_read_provenance_metadata_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "mir_lower_provenance_metadata_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_provenance_metadata_local_read",
    )?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "local_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "local_0_name", "value")?;
    require_compiler_mir_ingestion_field(&fields, "local_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "statement_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "statement_0_kind", "LocalI32Set")?;
    require_compiler_mir_ingestion_field(&fields, "statement_0_local", "value")?;
    require_compiler_mir_ingestion_field(&fields, "statement_0_value", "2")?;
    require_compiler_mir_ingestion_field(&fields, "terminator", "ReturnLocal")?;
    require_compiler_mir_ingestion_field(&fields, "return_local", "value")?;
    require_compiler_mir_ingestion_field(&fields, "return_value_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "provenance_metadata_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "provenance_0_kind", "LocalBinding")?;
    require_compiler_mir_ingestion_field(&fields, "provenance_0_local", "value")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "provenance_0_origin",
        "compiler/mir_feature_local_binding_read_provenance_metadata_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(&fields, "resource_metadata_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "native_boundary_metadata_count", "0")?;
    recognize_compiler_mir_metadata_preservation_contract(&fields, "provenance_metadata")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_PROVENANCE_METADATA_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_exit", "2")?;
    Ok(())
}

fn emit_compiler_mir_resource_metadata_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_resource_metadata_ingestion_fixture(&contents)?;
    emit_compiler_mir_fixture_contents_object(
        PHASE9C_CANONICAL_RESOURCE_METADATA_FIXTURE,
        output_path,
    )
}

fn parse_compiler_mir_resource_metadata_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.resource_metadata.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_resource_metadata_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_local_binding_read_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "mir_lower_resource_metadata_fixture",
    )?;
    require_compiler_mir_ingestion_field(&fields, "function", "tiny_resource_metadata_local")?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "local_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "local_0_name", "value")?;
    require_compiler_mir_ingestion_field(&fields, "local_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "statement_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "statement_0_kind", "LocalI32Set")?;
    require_compiler_mir_ingestion_field(&fields, "statement_0_local", "value")?;
    require_compiler_mir_ingestion_field(&fields, "statement_0_value", "2")?;
    require_compiler_mir_ingestion_field(&fields, "terminator", "ReturnLocal")?;
    require_compiler_mir_ingestion_field(&fields, "return_local", "value")?;
    require_compiler_mir_ingestion_field(&fields, "return_value_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "resource_metadata_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "resource_0_kind", "LinearResource")?;
    require_compiler_mir_ingestion_field(&fields, "resource_0_state", "Live")?;
    require_compiler_mir_ingestion_field(&fields, "resource_0_local", "value")?;
    require_compiler_mir_ingestion_field(&fields, "resource_0_cleanup_required", "false")?;
    require_compiler_mir_ingestion_field(&fields, "provenance_metadata_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "native_boundary_metadata_count", "0")?;
    recognize_compiler_mir_metadata_preservation_contract(&fields, "resource_metadata")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_RESOURCE_METADATA_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_exit", "2")?;
    Ok(())
}

fn emit_compiler_mir_native_boundary_metadata_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_native_boundary_metadata_ingestion_fixture(&contents)?;
    emit_compiler_mir_fixture_contents_object(
        PHASE9C_CANONICAL_NATIVE_BOUNDARY_METADATA_FIXTURE,
        output_path,
    )
}

fn parse_compiler_mir_native_boundary_metadata_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.native_boundary_metadata.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_native_boundary_metadata_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_to_c_native_boundary_metadata_smoke_test_entry.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "mir_lower_native_boundary_metadata_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_native_boundary_metadata_function",
    )?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "void")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "statement_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "terminator", "ReturnVoid")?;
    require_compiler_mir_ingestion_field(&fields, "resource_metadata_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "provenance_metadata_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "native_boundary_metadata_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "native_boundary_0_kind", "RuntimeCall")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "native_boundary_0_symbol",
        "tiny_runtime_boundary",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "native_boundary_0_origin",
        "compiler/mir_to_c_native_boundary_metadata_smoke_test_entry.gst",
    )?;
    recognize_compiler_mir_metadata_preservation_contract(&fields, "native_boundary_metadata")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_NATIVE_BOUNDARY_METADATA_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_exit", "0")?;
    Ok(())
}

fn recognize_compiler_mir_metadata_preservation_contract(
    fields: &HashMap<&str, &str>,
    lane: &str,
) -> Result<(), Box<dyn Error>> {
    match lane {
        "provenance_metadata" => {
            require_compiler_mir_ingestion_field(fields, "provenance_metadata_count", "1")?;
            require_compiler_mir_ingestion_field(fields, "provenance_0_kind", "LocalBinding")?;
            require_compiler_mir_ingestion_field(fields, "resource_metadata_count", "0")?;
            require_compiler_mir_ingestion_field(fields, "native_boundary_metadata_count", "0")?;
        }
        "resource_metadata" => {
            require_compiler_mir_ingestion_field(fields, "resource_metadata_count", "1")?;
            require_compiler_mir_ingestion_field(fields, "resource_0_kind", "LinearResource")?;
            require_compiler_mir_ingestion_field(fields, "resource_0_state", "Live")?;
            require_compiler_mir_ingestion_field(fields, "provenance_metadata_count", "0")?;
            require_compiler_mir_ingestion_field(fields, "native_boundary_metadata_count", "0")?;
        }
        "native_boundary_metadata" => {
            require_compiler_mir_ingestion_field(fields, "native_boundary_metadata_count", "1")?;
            require_compiler_mir_ingestion_field(fields, "native_boundary_0_kind", "RuntimeCall")?;
            require_compiler_mir_ingestion_field(fields, "resource_metadata_count", "0")?;
            require_compiler_mir_ingestion_field(fields, "provenance_metadata_count", "0")?;
        }
        other => {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!("unsupported compiler MIR metadata preservation lane: {other}"),
            )
            .into());
        }
    }
    Ok(())
}

fn emit_compiler_mir_positive_i32_branch_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_positive_i32_branch_ingestion_fixture(&contents)?;
    emit_compiler_mir_fixture_contents_object(
        PHASE9D_CANONICAL_POSITIVE_I32_BRANCH_FIXTURE,
        output_path,
    )
}

fn parse_compiler_mir_positive_i32_branch_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.positive_i32_branch.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_positive_i32_branch_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_positive_i32_branch_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_param_positive_i32_branch_serialization",
    )?;
    require_compiler_mir_ingestion_field(&fields, "function", "tiny_positive_i32_branch")?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_name", "value")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "3")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_terminator", "BranchParamPositive")?;
    require_compiler_mir_ingestion_field(&fields, "branch_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "branch_condition", "greater_than_zero")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_block", "1")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_block", "2")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_return_value", "7")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value", "9")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_POSITIVE_I32_BRANCH_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_count", "3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_value", "3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "7")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_value", "0")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "9")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_value", "-4")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "9")?;
    Ok(())
}

fn emit_compiler_mir_to_cranelift_block_jump_translator_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_jump_ingestion_fixture(&contents)?;
    static MIR_TO_CRANELIFT_BLOCK_JUMP_BLOCKS: [TinyMirBlock; 2] = [
        TinyMirBlock {
            label: "entry",
            statements: &[],
            terminator: TinyMirBlockTerminator::Jump { target: "return" },
        },
        TinyMirBlock {
            label: "return",
            statements: &[],
            terminator: TinyMirBlockTerminator::ReturnI32(1),
        },
    ];
    let mir_function = translate_compiler_mir_block_jump_fixture_to_tiny_mir_block_function(
        &MIR_TO_CRANELIFT_BLOCK_JUMP_BLOCKS,
    );

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_mir_to_cranelift_block_jump_translator",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);
    define_tiny_mir_block_graph_exported_function(&mut module, &mir_function)?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn translate_compiler_mir_block_jump_fixture_to_tiny_mir_block_function(
    blocks: &'static [TinyMirBlock],
) -> TinyMirBlockFunction {
    TinyMirBlockFunction {
        object_name: "gust_native_backend_mir_to_cranelift_block_jump_translator",
        symbol: COMPILER_MIR_TO_CRANELIFT_BLOCK_JUMP_TRANSLATOR_SYMBOL,
        params: &[],
        return_type: TinyMirType::I32,
        locals: &[],
        entry_block: "entry",
        blocks,
    }
}

fn emit_compiler_mir_block_jump_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_jump_ingestion_fixture(&contents)?;
    emit_compiler_mir_fixture_contents_object(
        PHASE9C_CANONICAL_BLOCK_JUMP_FIXTURE,
        output_path,
    )
}

fn parse_compiler_mir_block_jump_ingestion_fixture(contents: &str) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_jump.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_jump_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_lower_block_jump_smoke_test_entry.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "mir_lower_block_jump_fixture",
    )?;
    require_compiler_mir_ingestion_field(&fields, "function", "tiny_block_jump")?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "2")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_label", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_terminator", "Jump")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_target", "return")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_label", "return")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_statement_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_return_value", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_JUMP_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_exit", "1")?;
    Ok(())
}

fn emit_compiler_mir_block_local_branch_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_local_branch_ingestion_fixture(&contents)?;
    emit_compiler_mir_fixture_contents_object(
        PHASE9E_CANONICAL_BLOCK_LOCAL_BRANCH_FIXTURE,
        output_path,
    )
}

fn parse_compiler_mir_block_local_branch_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_local_branch.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_local_branch_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_local_branch_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_local_branch_serialization",
    )?;
    require_compiler_mir_ingestion_field(&fields, "function", "tiny_block_local_branch")?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_name", "input")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "local_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "local_0_name", "value")?;
    require_compiler_mir_ingestion_field(&fields, "local_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "3")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_label", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_0_kind", "LocalI32SetParam")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_0_local", "value")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_0_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_terminator", "BranchLocalPositive")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_branch_local", "value")?;
    require_compiler_mir_ingestion_field(&fields, "branch_condition", "greater_than_zero")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_block", "positive")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_block", "non_positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_label", "positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_statement_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_return_value", "43")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_label", "non_positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_statement_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value", "47")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_LOCAL_BRANCH_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_count", "3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_value", "5")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "43")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_value", "0")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "47")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_value", "-2")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "47")?;
    Ok(())
}

fn emit_compiler_mir_block_local_update_branch_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_local_update_branch_ingestion_fixture(&contents)?;
    emit_compiler_mir_fixture_contents_object(
        PHASE9E_CANONICAL_BLOCK_LOCAL_UPDATE_BRANCH_FIXTURE,
        output_path,
    )
}

fn parse_compiler_mir_block_local_update_branch_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_local_update_branch.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_local_update_branch_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_local_update_branch_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_local_update_branch_serialization",
    )?;
    require_compiler_mir_ingestion_field(&fields, "function", "tiny_block_local_update_branch")?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_name", "input")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "local_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "local_0_name", "value")?;
    require_compiler_mir_ingestion_field(&fields, "local_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "4")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_label", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_0_kind", "LocalI32SetParam")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_0_local", "value")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_0_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_terminator", "Jump")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_target", "increment")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_label", "increment")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_statement_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_statement_0_kind",
        "LocalI32AddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_statement_0_local", "value")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_statement_0_value", "2")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_terminator", "BranchLocalPositive")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_branch_local", "value")?;
    require_compiler_mir_ingestion_field(&fields, "branch_condition", "greater_than_zero")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_block", "positive")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_block", "non_positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_label", "positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_statement_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value", "53")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_label", "non_positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_statement_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value", "59")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_LOCAL_UPDATE_BRANCH_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_count", "3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_value", "5")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "53")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_value", "0")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "53")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_value", "-3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "59")?;
    Ok(())
}

fn emit_compiler_mir_block_two_local_update_branch_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_two_local_update_branch_ingestion_fixture(&contents)?;
    emit_compiler_mir_fixture_contents_object(
        PHASE9E_CANONICAL_BLOCK_TWO_LOCAL_UPDATE_BRANCH_FIXTURE,
        output_path,
    )
}

fn parse_compiler_mir_block_two_local_update_branch_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_two_local_update_branch.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_two_local_update_branch_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_two_local_update_branch_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_two_local_update_branch_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_two_local_update_branch",
    )?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_name", "input")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "local_count", "2")?;
    require_compiler_mir_ingestion_field(&fields, "local_0_name", "raw")?;
    require_compiler_mir_ingestion_field(&fields, "local_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "local_1_name", "adjusted")?;
    require_compiler_mir_ingestion_field(&fields, "local_1_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "4")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_label", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_count", "2")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_0_kind", "LocalI32SetParam")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_0_local", "raw")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_0_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_1_kind", "LocalI32SetParam")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_1_local", "adjusted")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_1_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_terminator", "Jump")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_target", "adjust")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_label", "adjust")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_statement_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_statement_0_kind",
        "LocalI32AddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_statement_0_local", "adjusted")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_statement_0_value", "3")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_terminator", "BranchLocalPositive")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_branch_local", "adjusted")?;
    require_compiler_mir_ingestion_field(&fields, "branch_condition", "greater_than_zero")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_block", "positive")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_block", "non_positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_label", "positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_statement_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value", "61")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_label", "non_positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_statement_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value", "67")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_TWO_LOCAL_UPDATE_BRANCH_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_count", "3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_value", "5")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "61")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_value", "-2")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "61")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_value", "-3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "67")?;
    Ok(())
}

fn emit_compiler_mir_block_local_branch_join_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_local_branch_join_ingestion_fixture(&contents)?;
    let mir_function = CompilerMirLoweringFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_local_branch_join",
        symbol: COMPILER_MIR_INGESTED_BLOCK_LOCAL_BRANCH_JOIN_SYMBOL,
        return_type: TinyMirType::I32,
        params: vec![TinyMirType::I32],
        locals: vec![CompilerMirLoweringLocal {
            name: "value",
            ty: TinyMirType::I32,
        }],
        entry_block: "entry",
        blocks: vec![
            CompilerMirLoweringBlock {
                label: "entry",
                parameters: vec![],
                statements: vec![CompilerMirLoweringStatement::LocalI32SetParam {
                    name: "value",
                    param: 0,
                }],
                terminator: CompilerMirLoweringTerminator::BranchLocalI32Positive {
                    name: "value",
                    then_edge: CompilerMirLoweringEdge {
                        target: "positive",
                        arguments: vec![],
                    },
                    else_edge: CompilerMirLoweringEdge {
                        target: "non_positive",
                        arguments: vec![],
                    },
                },
            },
            CompilerMirLoweringBlock {
                label: "positive",
                parameters: vec![],
                statements: vec![CompilerMirLoweringStatement::LocalI32AddI32Literal {
                    name: "value",
                    value: 4,
                }],
                terminator: CompilerMirLoweringTerminator::Jump {
                    edge: CompilerMirLoweringEdge {
                        target: "join",
                        arguments: vec![],
                    },
                },
            },
            CompilerMirLoweringBlock {
                label: "non_positive",
                parameters: vec![],
                statements: vec![CompilerMirLoweringStatement::LocalI32AddI32Literal {
                    name: "value",
                    value: 8,
                }],
                terminator: CompilerMirLoweringTerminator::Jump {
                    edge: CompilerMirLoweringEdge {
                        target: "join",
                        arguments: vec![],
                    },
                },
            },
            CompilerMirLoweringBlock {
                label: "join",
                parameters: vec![],
                statements: vec![],
                terminator: CompilerMirLoweringTerminator::ReturnLocalI32("value"),
            },
        ],
    };

    lower_compiler_mir_ingestion_function_to_object(output_path, &mir_function)
}

fn parse_compiler_mir_block_local_branch_join_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_local_branch_join.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_local_branch_join_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_local_branch_join_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_local_branch_join_serialization",
    )?;
    require_compiler_mir_ingestion_field(&fields, "function", "tiny_block_local_branch_join")?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_name", "input")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "local_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "local_0_name", "value")?;
    require_compiler_mir_ingestion_field(&fields, "local_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "4")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_label", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_0_kind", "LocalI32SetParam")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_0_local", "value")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_statement_0_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_terminator", "BranchLocalPositive")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_branch_local", "value")?;
    require_compiler_mir_ingestion_field(&fields, "branch_condition", "greater_than_zero")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_block", "positive")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_block", "non_positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_label", "positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_statement_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_statement_0_kind",
        "LocalI32AddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_statement_0_local", "value")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_statement_0_value", "4")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_terminator", "Jump")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_target", "join")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_label", "non_positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_statement_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_statement_0_kind",
        "LocalI32AddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_2_statement_0_local", "value")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_statement_0_value", "8")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_terminator", "Jump")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_target", "join")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_label", "join")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_statement_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value_kind", "LocalRead")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_local", "value")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_LOCAL_BRANCH_JOIN_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_count", "3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_value", "5")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "9")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_value", "0")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "8")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_value", "-3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "5")?;
    Ok(())
}

fn emit_compiler_mir_block_param_update_branch_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_update_branch_ingestion_fixture(&contents)?;
    static COMPILER_MIR_BLOCK_PARAM_UPDATE_BRANCH_FUNCTION_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_UPDATE_BRANCH_BLOCK_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_UPDATE_BRANCH_BLOCKS: [TinyMirParamBlock; 5] = [
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
            params: &COMPILER_MIR_BLOCK_PARAM_UPDATE_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "branch",
                param: 0,
                value: 4,
            },
        },
        TinyMirParamBlock {
            label: "branch",
            params: &COMPILER_MIR_BLOCK_PARAM_UPDATE_BRANCH_BLOCK_PARAMS,
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
    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_update_branch",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_UPDATE_BRANCH_SYMBOL,
        params: &COMPILER_MIR_BLOCK_PARAM_UPDATE_BRANCH_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &COMPILER_MIR_BLOCK_PARAM_UPDATE_BRANCH_BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_update_branch",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);
    let local_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &local_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_update_branch_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_update_branch.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_update_branch_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_update_branch_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_update_branch_serialization",
    )?;
    require_compiler_mir_ingestion_field(&fields, "function", "tiny_block_param_update_branch")?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_name", "input")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "5")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_label", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_terminator", "JumpFunctionParam")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_target", "increment")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_label", "increment")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "JumpBlockParamAddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_target", "branch")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_add_value", "4")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_label", "branch")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_terminator",
        "BranchBlockParamPositive",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_2_branch_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "branch_condition", "greater_than_zero")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_block", "positive")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_block", "non_positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_label", "positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value", "67")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_label", "non_positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_return_value", "71")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_UPDATE_BRANCH_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_count", "3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_value", "5")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "67")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_value", "0")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "67")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_value", "-4")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "71")?;
    Ok(())
}

fn emit_compiler_mir_block_param_local_call_branch_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_local_call_branch_ingestion_fixture(&contents)?;
    static COMPILER_MIR_BLOCK_PARAM_LOCAL_CALL_BRANCH_FUNCTION_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_LOCAL_CALL_BRANCH_BLOCK_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_LOCAL_CALL_BRANCH_BLOCKS: [TinyMirParamBlock; 4] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "branch",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "branch",
            params: &COMPILER_MIR_BLOCK_PARAM_LOCAL_CALL_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamLocalFunctionI32CallPositive {
                function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_CALL_HELPER_SYMBOL,
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
    let helper_mir_function = TinyMirFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_local_call_branch",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_CALL_HELPER_SYMBOL,
        params: &COMPILER_MIR_BLOCK_PARAM_LOCAL_CALL_BRANCH_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32AddLiteral { param: 0, value: 1 },
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_local_call_branch",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut helper_signature = module.make_signature();
    helper_signature.params.push(AbiParam::new(types::I32));
    helper_signature.returns.push(AbiParam::new(types::I32));
    let helper_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_CALL_HELPER_SYMBOL,
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
        COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_CALL_HELPER_SYMBOL,
        helper_function_id,
    );

    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_local_call_branch",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_CALL_BRANCH_SYMBOL,
        params: &COMPILER_MIR_BLOCK_PARAM_LOCAL_CALL_BRANCH_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &COMPILER_MIR_BLOCK_PARAM_LOCAL_CALL_BRANCH_BLOCKS,
    };
    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &local_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_local_call_branch_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_local_call_branch.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_local_call_branch_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_local_call_branch_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_local_call_branch_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_local_call_branch",
    )?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_name", "input")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "local_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "local_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_CALL_HELPER_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "local_function_0_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "local_function_0_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "local_function_0_return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "local_function_0_operation", "AddI32Literal")?;
    require_compiler_mir_ingestion_field(&fields, "local_function_0_add_value", "1")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "4")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_label", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_terminator", "JumpFunctionParam")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_target", "branch")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_label", "branch")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "BranchBlockParamLocalFunctionPositive",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_local_function_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_CALL_HELPER_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_branch_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "branch_condition", "greater_than_zero")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_block", "positive")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_block", "non_positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_label", "positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value", "79")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_label", "non_positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value", "83")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_CALL_BRANCH_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_count", "3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_value", "5")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "79")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_value", "0")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "79")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_value", "-1")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "83")?;
    Ok(())
}

fn emit_compiler_mir_block_param_imported_call_branch_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_imported_call_branch_ingestion_fixture(&contents)?;
    static COMPILER_MIR_BLOCK_PARAM_IMPORTED_CALL_BRANCH_FUNCTION_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_IMPORTED_CALL_BRANCH_BLOCK_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_IMPORTED_CALL_BRANCH_BLOCKS: [TinyMirParamBlock; 4] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "branch",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "branch",
            params: &COMPILER_MIR_BLOCK_PARAM_IMPORTED_CALL_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32CallI32LiteralPositive {
                function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_HOST_ADD_SYMBOL,
                param: 0,
                value: -3,
                then_block: "positive",
                else_block: "non_positive",
            },
        },
        TinyMirParamBlock {
            label: "positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(89),
        },
        TinyMirParamBlock {
            label: "non_positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(97),
        },
    ];
    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_imported_call_branch",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_BRANCH_SYMBOL,
        params: &COMPILER_MIR_BLOCK_PARAM_IMPORTED_CALL_BRANCH_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &COMPILER_MIR_BLOCK_PARAM_IMPORTED_CALL_BRANCH_BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_imported_call_branch",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut imported_add_signature = module.make_signature();
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .returns
        .push(AbiParam::new(types::I32));
    let imported_add_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_HOST_ADD_SYMBOL,
        Linkage::Import,
        &imported_add_signature,
    )?;
    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_HOST_ADD_SYMBOL,
        imported_add_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &imported_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_imported_call_branch_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_imported_call_branch.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_imported_call_branch_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_imported_call_branch_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_imported_call_branch_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_imported_call_branch",
    )?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_name", "input")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "imported_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_count", "2")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_1_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_operation", "HostAddI32")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "4")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_label", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_terminator", "JumpFunctionParam")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_target", "branch")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_label", "branch")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "BranchBlockParamImportedFunctionCallI32LiteralPositive",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_imported_function_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_branch_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_call_literal", "-3")?;
    require_compiler_mir_ingestion_field(&fields, "branch_condition", "greater_than_zero")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_block", "positive")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_block", "non_positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_label", "positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value", "89")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_label", "non_positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value", "97")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_BRANCH_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_count", "3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_value", "5")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "89")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_value", "3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "97")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_value", "-2")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "97")?;
    Ok(())
}

fn emit_compiler_mir_block_param_imported_call_return_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_imported_call_return_ingestion_fixture(&contents)?;
    static COMPILER_MIR_BLOCK_PARAM_IMPORTED_CALL_RETURN_FUNCTION_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_IMPORTED_CALL_RETURN_BLOCK_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_IMPORTED_CALL_RETURN_BLOCKS: [TinyMirParamBlock; 2] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "return_imported",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "return_imported",
            params: &COMPILER_MIR_BLOCK_PARAM_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator:
                TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal {
                    function_symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
                    param: 0,
                    value: 11,
                },
        },
    ];
    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_imported_call_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_RETURN_SYMBOL,
        params: &COMPILER_MIR_BLOCK_PARAM_IMPORTED_CALL_RETURN_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &COMPILER_MIR_BLOCK_PARAM_IMPORTED_CALL_RETURN_BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_imported_call_return",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut imported_add_signature = module.make_signature();
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .returns
        .push(AbiParam::new(types::I32));
    let imported_add_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
        Linkage::Import,
        &imported_add_signature,
    )?;
    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
        imported_add_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &imported_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_imported_call_return_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_imported_call_return.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_imported_call_return_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_imported_call_return_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_imported_call_return_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_imported_call_return",
    )?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_name", "input")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "imported_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_count", "2")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_1_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_operation", "HostAddI32")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "2")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_label", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_terminator", "JumpFunctionParam")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_target", "return_imported")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_label", "return_imported")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "ReturnBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_imported_function_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_return_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_call_literal", "11")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_return_value_kind", "ImportedCall")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_RETURN_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_count", "3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_value", "5")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "16")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_value", "0")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "11")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_value", "-12")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "-1")?;
    Ok(())
}

fn emit_compiler_mir_block_param_imported_predicate_update_branch_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_imported_predicate_update_branch_ingestion_fixture(&contents)?;
    static COMPILER_MIR_BLOCK_PARAM_IMPORTED_PREDICATE_UPDATE_BRANCH_FUNCTION_PARAMS:
        [TinyMirType; 1] = [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_IMPORTED_PREDICATE_UPDATE_BRANCH_BLOCK_PARAMS: [TinyMirType;
        1] = [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_IMPORTED_PREDICATE_UPDATE_BRANCH_BLOCKS: [TinyMirParamBlock;
        5] = [
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
            params: &COMPILER_MIR_BLOCK_PARAM_IMPORTED_PREDICATE_UPDATE_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "predicate",
                param: 0,
                value: -4,
            },
        },
        TinyMirParamBlock {
            label: "predicate",
            params: &COMPILER_MIR_BLOCK_PARAM_IMPORTED_PREDICATE_UPDATE_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32Predicate {
                function_symbol:
                    COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_PREDICATE_HOST_IS_POSITIVE_SYMBOL,
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
            terminator: TinyMirParamBlockTerminator::ReturnI32(107),
        },
    ];
    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_imported_predicate_update_branch",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_PREDICATE_UPDATE_BRANCH_SYMBOL,
        params: &COMPILER_MIR_BLOCK_PARAM_IMPORTED_PREDICATE_UPDATE_BRANCH_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &COMPILER_MIR_BLOCK_PARAM_IMPORTED_PREDICATE_UPDATE_BRANCH_BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_imported_predicate_update_branch",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut imported_predicate_signature = module.make_signature();
    imported_predicate_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_predicate_signature
        .returns
        .push(AbiParam::new(types::I32));
    let imported_predicate_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_PREDICATE_HOST_IS_POSITIVE_SYMBOL,
        Linkage::Import,
        &imported_predicate_signature,
    )?;
    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_PREDICATE_HOST_IS_POSITIVE_SYMBOL,
        imported_predicate_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &imported_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_imported_predicate_update_branch_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_imported_predicate_update_branch.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_imported_predicate_update_branch_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_imported_predicate_update_branch_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_imported_predicate_update_branch_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_imported_predicate_update_branch",
    )?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_name", "input")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "imported_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_PREDICATE_HOST_IS_POSITIVE_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_return_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "imported_function_0_operation",
        "HostIsPositiveI32",
    )?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "5")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_label", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_terminator", "JumpFunctionParam")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_target", "adjust")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_label", "adjust")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "JumpBlockParamAddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_target", "predicate")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_add_value", "-4")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_label", "predicate")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_terminator",
        "BranchBlockParamImportedFunctionPredicate",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_imported_function_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_PREDICATE_HOST_IS_POSITIVE_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_2_branch_param", "0")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "branch_condition",
        "imported_predicate_nonzero",
    )?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_block", "positive")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_block", "non_positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_label", "positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value", "101")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_label", "non_positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_return_value", "107")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_PREDICATE_UPDATE_BRANCH_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_count", "3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_value", "6")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "101")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_value", "4")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "107")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_value", "-1")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "107")?;
    Ok(())
}

fn emit_compiler_mir_block_param_merge_update_branch_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_merge_update_branch_ingestion_fixture(&contents)?;
    static COMPILER_MIR_BLOCK_PARAM_MERGE_UPDATE_BRANCH_FUNCTION_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_MERGE_UPDATE_BRANCH_BLOCK_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_MERGE_UPDATE_BRANCH_BLOCKS: [TinyMirParamBlock; 6] = [
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
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_UPDATE_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "branch",
                param: 0,
                value: 4,
            },
        },
        TinyMirParamBlock {
            label: "branch",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_UPDATE_BRANCH_BLOCK_PARAMS,
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
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_UPDATE_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 0,
            },
        },
        TinyMirParamBlock {
            label: "else_value",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_UPDATE_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 0,
            },
        },
        TinyMirParamBlock {
            label: "join",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_UPDATE_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamI32(0),
        },
    ];
    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_merge_update_branch",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_UPDATE_BRANCH_SYMBOL,
        params: &COMPILER_MIR_BLOCK_PARAM_MERGE_UPDATE_BRANCH_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &COMPILER_MIR_BLOCK_PARAM_MERGE_UPDATE_BRANCH_BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_merge_update_branch",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);
    let local_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &local_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_merge_update_branch_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_merge_update_branch.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_merge_update_branch_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_merge_update_branch_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_merge_update_branch_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_merge_update_branch",
    )?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_name", "input")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "6")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_label", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_terminator", "JumpFunctionParam")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_target", "adjust")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_label", "adjust")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "JumpBlockParamAddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_target", "branch")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_add_value", "4")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_label", "branch")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_terminator",
        "BranchBlockParamPositiveToI32Literals",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_2_branch_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "branch_condition", "greater_than_zero")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_block", "then_value")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_value", "181")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_block", "else_value")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_value", "191")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_label", "then_value")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_3_terminator",
        "JumpBlockParamAddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_3_target", "join")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_add_value", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_label", "else_value")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_4_terminator",
        "JumpBlockParamAddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_4_target", "join")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_add_value", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_label", "join")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_terminator", "ReturnBlockParam")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_return_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_return_value_kind", "BlockParam")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_UPDATE_BRANCH_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_count", "3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_value", "1")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "181")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_value", "-4")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "191")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_value", "-9")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "191")?;
    Ok(())
}

fn emit_compiler_mir_block_param_merge_imported_call_return_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_merge_imported_call_return_ingestion_fixture(&contents)?;
    static COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_FUNCTION_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_BLOCK_PARAMS: [TinyMirType; 1] =
        [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_BLOCKS: [TinyMirParamBlock; 6] = [
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
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "branch",
                param: 0,
                value: 4,
            },
        },
        TinyMirParamBlock {
            label: "branch",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "then_value",
                then_value: 211,
                else_block: "else_value",
                else_value: 223,
            },
        },
        TinyMirParamBlock {
            label: "then_value",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 0,
            },
        },
        TinyMirParamBlock {
            label: "else_value",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 0,
            },
        },
        TinyMirParamBlock {
            label: "join",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator:
                TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal {
                    function_symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
                    param: 0,
                    value: 5,
                },
        },
    ];
    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_SYMBOL,
        params: &COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut imported_add_signature = module.make_signature();
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .returns
        .push(AbiParam::new(types::I32));
    let imported_add_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
        Linkage::Import,
        &imported_add_signature,
    )?;
    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
        imported_add_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &imported_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_merge_imported_call_return_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_merge_imported_call_return.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_merge_imported_call_return_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_merge_imported_call_return_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_merge_imported_call_return_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_merge_imported_call_return",
    )?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_name", "input")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "imported_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_count", "2")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_1_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_operation", "HostAddI32")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "6")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_label", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_terminator", "JumpFunctionParam")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_target", "adjust")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_label", "adjust")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "JumpBlockParamAddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_target", "branch")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_add_value", "4")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_label", "branch")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_terminator",
        "BranchBlockParamPositiveToI32Literals",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_2_branch_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "branch_condition", "greater_than_zero")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_block", "then_value")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_value", "211")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_block", "else_value")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_value", "223")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_label", "then_value")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_3_terminator",
        "JumpBlockParamAddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_3_target", "join")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_add_value", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_label", "else_value")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_4_terminator",
        "JumpBlockParamAddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_4_target", "join")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_add_value", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_label", "join")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_5_terminator",
        "ReturnBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_5_imported_function_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_5_return_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_call_literal", "5")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_return_value_kind", "ImportedCall")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_count", "3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_value", "1")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "216")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_value", "-4")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "228")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_value", "-9")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "228")?;
    Ok(())
}

fn emit_compiler_mir_block_param_merge_arm_update_imported_call_return_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_merge_arm_update_imported_call_return_ingestion_fixture(
        &contents,
    )?;
    static COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_FUNCTION_PARAMS:
        [TinyMirType; 1] = [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_BLOCK_PARAMS:
        [TinyMirType; 1] = [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_BLOCKS: [TinyMirParamBlock; 6] = [
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
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "branch",
                param: 0,
                value: 4,
            },
        },
        TinyMirParamBlock {
            label: "branch",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "then_value",
                then_value: 211,
                else_block: "else_value",
                else_value: 223,
            },
        },
        TinyMirParamBlock {
            label: "then_value",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 7,
            },
        },
        TinyMirParamBlock {
            label: "else_value",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 9,
            },
        },
        TinyMirParamBlock {
            label: "join",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal {
                function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
                param: 0,
                value: 5,
            },
        },
    ];
    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_SYMBOL,
        params: &COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut imported_add_signature = module.make_signature();
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .returns
        .push(AbiParam::new(types::I32));
    let imported_add_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
        Linkage::Import,
        &imported_add_signature,
    )?;
    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
        imported_add_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &imported_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_merge_arm_update_imported_call_return_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_merge_arm_update_imported_call_return.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_merge_arm_update_imported_call_return_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_merge_arm_update_imported_call_return_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_merge_arm_update_imported_call_return_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_merge_arm_update_imported_call_return",
    )?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_name", "input")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "imported_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_count", "2")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_1_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_operation", "HostAddI32")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "6")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_label", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_terminator", "JumpFunctionParam")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_target", "adjust")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_label", "adjust")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "JumpBlockParamAddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_target", "branch")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_add_value", "4")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_label", "branch")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_terminator",
        "BranchBlockParamPositiveToI32Literals",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_2_branch_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "branch_condition", "greater_than_zero")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_block", "then_value")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_value", "211")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_block", "else_value")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_value", "223")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_label", "then_value")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_3_terminator",
        "JumpBlockParamAddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_3_target", "join")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_add_value", "7")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_label", "else_value")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_4_terminator",
        "JumpBlockParamAddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_4_target", "join")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_add_value", "9")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_label", "join")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_5_terminator",
        "ReturnBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_5_imported_function_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_5_return_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_call_literal", "5")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_return_value_kind", "ImportedCall")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_count", "3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_value", "1")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "223")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_value", "-4")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "237")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_value", "-9")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "237")?;
    Ok(())
}

fn emit_compiler_mir_block_param_merge_arm_update_imported_call_branch_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_merge_arm_update_imported_call_branch_ingestion_fixture(
        &contents,
    )?;
    static COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_FUNCTION_PARAMS:
        [TinyMirType; 1] = [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_BLOCK_PARAMS:
        [TinyMirType; 1] = [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_BLOCKS: [TinyMirParamBlock; 8] = [
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
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "branch",
                param: 0,
                value: 4,
            },
        },
        TinyMirParamBlock {
            label: "branch",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "then_value",
                then_value: 211,
                else_block: "else_value",
                else_value: 223,
            },
        },
        TinyMirParamBlock {
            label: "then_value",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 7,
            },
        },
        TinyMirParamBlock {
            label: "else_value",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 9,
            },
        },
        TinyMirParamBlock {
            label: "join",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32CallI32LiteralPositive {
                function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_HOST_ADD_SYMBOL,
                param: 0,
                value: -220,
                then_block: "positive",
                else_block: "non_positive",
            },
        },
        TinyMirParamBlock {
            label: "positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(241),
        },
        TinyMirParamBlock {
            label: "non_positive",
            params: &[],
            terminator: TinyMirParamBlockTerminator::ReturnI32(251),
        },
    ];
    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_SYMBOL,
        params: &COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &COMPILER_MIR_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut imported_add_signature = module.make_signature();
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .returns
        .push(AbiParam::new(types::I32));
    let imported_add_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_HOST_ADD_SYMBOL,
        Linkage::Import,
        &imported_add_signature,
    )?;
    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_HOST_ADD_SYMBOL,
        imported_add_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &imported_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_merge_arm_update_imported_call_branch_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_merge_arm_update_imported_call_branch.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_merge_arm_update_imported_call_branch_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_merge_arm_update_imported_call_branch_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_merge_arm_update_imported_call_branch_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_merge_arm_update_imported_call_branch",
    )?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_name", "input")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "imported_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_count", "2")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_1_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_operation", "HostAddI32")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "8")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_label", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_terminator", "JumpFunctionParam")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_target", "adjust")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_label", "adjust")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "JumpBlockParamAddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_target", "branch")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_add_value", "4")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_label", "branch")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_terminator",
        "BranchBlockParamPositiveToI32Literals",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_2_branch_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "branch_condition", "greater_than_zero")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_block", "then_value")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_value", "211")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_block", "else_value")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_value", "223")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_label", "then_value")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_3_terminator",
        "JumpBlockParamAddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_3_target", "join")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_add_value", "7")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_label", "else_value")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_4_terminator",
        "JumpBlockParamAddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_4_target", "join")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_add_value", "9")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_label", "join")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_5_terminator",
        "BranchBlockParamImportedFunctionCallI32LiteralPositive",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_5_imported_function_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_5_branch_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_call_literal", "-220")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_5_branch_condition",
        "imported_call_greater_than_zero",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_5_branch_then_block", "positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_branch_else_block", "non_positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_6_label", "positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_6_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_6_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_6_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_6_return_value", "241")?;
    require_compiler_mir_ingestion_field(&fields, "block_6_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "block_7_label", "non_positive")?;
    require_compiler_mir_ingestion_field(&fields, "block_7_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_7_terminator", "Return")?;
    require_compiler_mir_ingestion_field(&fields, "block_7_return_value_kind", "IntLiteral")?;
    require_compiler_mir_ingestion_field(&fields, "block_7_return_value", "251")?;
    require_compiler_mir_ingestion_field(&fields, "block_7_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_count", "3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_value", "1")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "251")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_value", "-4")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "241")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_value", "-9")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "241")?;
    Ok(())
}

fn emit_compiler_mir_block_param_merge_imported_branch_joined_return_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_merge_imported_branch_joined_return_ingestion_fixture(
        &contents,
    )?;
    static COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_FUNCTION_PARAMS:
        [TinyMirType; 1] = [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_BLOCK_PARAMS:
        [TinyMirType; 1] = [TinyMirType::I32];
    static COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_BLOCKS: [TinyMirParamBlock; 9] = [
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
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "branch",
                param: 0,
                value: 4,
            },
        },
        TinyMirParamBlock {
            label: "branch",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "then_value",
                then_value: 211,
                else_block: "else_value",
                else_value: 223,
            },
        },
        TinyMirParamBlock {
            label: "then_value",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 7,
            },
        },
        TinyMirParamBlock {
            label: "else_value",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal {
                target: "join",
                param: 0,
                value: 9,
            },
        },
        TinyMirParamBlock {
            label: "join",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32CallI32LiteralPositive {
                function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_HOST_ADD_SYMBOL,
                param: 0,
                value: -220,
                then_block: "positive_value",
                else_block: "non_positive_value",
            },
        },
        TinyMirParamBlock {
            label: "positive_value",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpI32Literal {
                target: "return_join",
                value: 241,
            },
        },
        TinyMirParamBlock {
            label: "non_positive_value",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpI32Literal {
                target: "return_join",
                value: 251,
            },
        },
        TinyMirParamBlock {
            label: "return_join",
            params: &COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal {
                function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_HOST_ADD_SYMBOL,
                param: 0,
                value: 3,
            },
        },
    ];
    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_SYMBOL,
        params: &COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &COMPILER_MIR_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut imported_add_signature = module.make_signature();
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .params
        .push(AbiParam::new(types::I32));
    imported_add_signature
        .returns
        .push(AbiParam::new(types::I32));
    let imported_add_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_HOST_ADD_SYMBOL,
        Linkage::Import,
        &imported_add_signature,
    )?;
    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_HOST_ADD_SYMBOL,
        imported_add_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &imported_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_merge_imported_branch_joined_return_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_merge_imported_branch_joined_return.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_merge_imported_branch_joined_return_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_merge_imported_branch_joined_return_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_merge_imported_branch_joined_return_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_merge_imported_branch_joined_return",
    )?;
    require_compiler_mir_ingestion_field(&fields, "return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_name", "input")?;
    require_compiler_mir_ingestion_field(&fields, "param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "imported_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_count", "2")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_param_1_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_return_type", "int")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_operation", "HostAddI32")?;
    require_compiler_mir_ingestion_field(&fields, "entry_block", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "9")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_label", "entry")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_terminator", "JumpFunctionParam")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_target", "adjust")?;
    require_compiler_mir_ingestion_field(&fields, "block_0_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_label", "adjust")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "JumpBlockParamAddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_target", "branch")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_add_value", "4")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_label", "branch")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_2_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_terminator",
        "BranchBlockParamPositiveToI32Literals",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_2_branch_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "branch_condition", "greater_than_zero")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_block", "then_value")?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_value", "211")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_block", "else_value")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_value", "223")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_label", "then_value")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_3_terminator",
        "JumpBlockParamAddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_3_target", "join")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_add_value", "7")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_label", "else_value")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_4_terminator",
        "JumpBlockParamAddI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_4_target", "join")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_add_value", "9")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_label", "join")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_5_terminator",
        "BranchBlockParamImportedFunctionCallI32LiteralPositive",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_5_imported_function_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_5_branch_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_5_call_literal", "-220")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_5_branch_condition",
        "imported_call_greater_than_zero",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_5_branch_then_block", "positive_value")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_5_branch_else_block",
        "non_positive_value",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_6_label", "positive_value")?;
    require_compiler_mir_ingestion_field(&fields, "block_6_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_6_terminator", "JumpI32Literal")?;
    require_compiler_mir_ingestion_field(&fields, "block_6_target", "return_join")?;
    require_compiler_mir_ingestion_field(&fields, "block_6_value", "241")?;
    require_compiler_mir_ingestion_field(&fields, "block_7_label", "non_positive_value")?;
    require_compiler_mir_ingestion_field(&fields, "block_7_param_count", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_7_terminator", "JumpI32Literal")?;
    require_compiler_mir_ingestion_field(&fields, "block_7_target", "return_join")?;
    require_compiler_mir_ingestion_field(&fields, "block_7_value", "251")?;
    require_compiler_mir_ingestion_field(&fields, "block_8_label", "return_join")?;
    require_compiler_mir_ingestion_field(&fields, "block_8_param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_8_param_0_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_8_terminator",
        "ReturnBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_8_imported_function_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_8_return_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_8_call_literal", "3")?;
    require_compiler_mir_ingestion_field(&fields, "block_8_return_value_kind", "ImportedCall")?;
    require_compiler_mir_ingestion_field(&fields, "block_8_return_value_type", "int")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_count", "3")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_value", "1")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "254")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_value", "-4")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "244")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_value", "-9")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "244")?;
    Ok(())
}

fn emit_compiler_mir_block_param_merge_dual_imported_joined_return_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_merge_dual_imported_joined_return_ingestion_fixture(&contents)?;
    static FUNCTION_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCKS: [TinyMirParamBlock; 9] = [
        TinyMirParamBlock { label: "entry", params: &[], terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 { target: "adjust", param: 0 } },
        TinyMirParamBlock { label: "adjust", params: &BLOCK_PARAMS, terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal { target: "branch", param: 0, value: 4 } },
        TinyMirParamBlock { label: "branch", params: &BLOCK_PARAMS, terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals { param: 0, then_block: "then_value", then_value: 211, else_block: "else_value", else_value: 223 } },
        TinyMirParamBlock { label: "then_value", params: &BLOCK_PARAMS, terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal { target: "join", param: 0, value: 7 } },
        TinyMirParamBlock { label: "else_value", params: &BLOCK_PARAMS, terminator: TinyMirParamBlockTerminator::JumpBlockParamI32AddI32Literal { target: "join", param: 0, value: 9 } },
        TinyMirParamBlock { label: "join", params: &BLOCK_PARAMS, terminator: TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32CallI32LiteralPositive { function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_BRANCH_HOST_ADD_SYMBOL, param: 0, value: -220, then_block: "positive_value", else_block: "non_positive_value" } },
        TinyMirParamBlock { label: "positive_value", params: &[], terminator: TinyMirParamBlockTerminator::JumpI32Literal { target: "return_join", value: 241 } },
        TinyMirParamBlock { label: "non_positive_value", params: &[], terminator: TinyMirParamBlockTerminator::JumpI32Literal { target: "return_join", value: 251 } },
        TinyMirParamBlock { label: "return_join", params: &BLOCK_PARAMS, terminator: TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal { function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_RETURN_HOST_ADD_SYMBOL, param: 0, value: 4 } },
    ];
    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut branch_signature = module.make_signature();
    branch_signature.params.push(AbiParam::new(types::I32));
    branch_signature.params.push(AbiParam::new(types::I32));
    branch_signature.returns.push(AbiParam::new(types::I32));
    let branch_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_BRANCH_HOST_ADD_SYMBOL,
        Linkage::Import,
        &branch_signature,
    )?;

    let mut return_signature = module.make_signature();
    return_signature.params.push(AbiParam::new(types::I32));
    return_signature.params.push(AbiParam::new(types::I32));
    return_signature.returns.push(AbiParam::new(types::I32));
    let return_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_RETURN_HOST_ADD_SYMBOL,
        Linkage::Import,
        &return_signature,
    )?;

    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_BRANCH_HOST_ADD_SYMBOL,
        branch_id,
    );
    imported_function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_RETURN_HOST_ADD_SYMBOL,
        return_id,
    );

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &imported_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_merge_dual_imported_joined_return_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_merge_dual_imported_joined_return.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_merge_dual_imported_joined_return_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_merge_dual_imported_joined_return_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_merge_dual_imported_joined_return_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_merge_dual_imported_joined_return",
    )?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_count", "2")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "imported_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_BRANCH_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "imported_function_1_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_RETURN_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "9")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_add_value", "7")?;
    require_compiler_mir_ingestion_field(&fields, "block_4_add_value", "9")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_5_terminator",
        "BranchBlockParamImportedFunctionCallI32LiteralPositive",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_5_call_literal", "-220")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_8_terminator",
        "ReturnBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_8_call_literal", "4")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "255")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "245")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "245")?;
    Ok(())
}

fn emit_compiler_mir_block_param_quint_materialize_return_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_quint_materialize_return_ingestion_fixture(&contents)?;
    static FUNCTION_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCKS: [TinyMirParamBlock; 8] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "materialize_imported_call_first",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "materialize_imported_call_first",
            params: &BLOCK_PARAMS,
            terminator:
                TinyMirParamBlockTerminator::JumpBlockParamImportedFunctionI32CallI32Literal {
                    target: "materialize_local_call_first",
                    function_symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
                    param: 0,
                    value: -1,
                },
        },
        TinyMirParamBlock {
            label: "materialize_local_call_first",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamLocalFunctionI32Call {
                target: "materialize_imported_call_second",
                function_symbol:
                    COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_HELPER_SYMBOL,
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "materialize_imported_call_second",
            params: &BLOCK_PARAMS,
            terminator:
                TinyMirParamBlockTerminator::JumpBlockParamImportedFunctionI32CallI32Literal {
                    target: "materialize_local_call_second",
                    function_symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
                    param: 0,
                    value: -3,
                },
        },
        TinyMirParamBlock {
            label: "materialize_local_call_second",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamLocalFunctionI32Call {
                target: "materialize_imported_call_third",
                function_symbol:
                    COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_SECOND_HELPER_SYMBOL,
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "materialize_imported_call_third",
            params: &BLOCK_PARAMS,
            terminator:
                TinyMirParamBlockTerminator::JumpBlockParamImportedFunctionI32CallI32Literal {
                    target: "branch_on_quint_materialized_call",
                    function_symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
                    param: 0,
                    value: -5,
                },
        },
        TinyMirParamBlock {
            label: "branch_on_quint_materialized_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "result",
                then_value: 919,
                else_block: "result",
                else_value: 967,
            },
        },
        TinyMirParamBlock {
            label: "result",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamLocalFunctionI32Call {
                function_symbol:
                    COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_EXIT_HELPER_SYMBOL,
                param: 0,
            },
        },
    ];

    let helper_mir_function = TinyMirFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_quint_materialize_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_HELPER_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32AddLiteral { param: 0, value: 2 },
    };
    let second_helper_mir_function = TinyMirFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_quint_materialize_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_SECOND_HELPER_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32AddLiteral { param: 0, value: 4 },
    };
    let exit_helper_mir_function = TinyMirFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_quint_materialize_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_EXIT_HELPER_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32AddLiteral { param: 0, value: 8 },
    };

    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_quint_materialize_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_quint_materialize_return",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

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

    let mut second_helper_signature = module.make_signature();
    second_helper_signature
        .params
        .push(AbiParam::new(types::I32));
    second_helper_signature
        .returns
        .push(AbiParam::new(types::I32));
    let second_helper_function_id = module.declare_function(
        second_helper_mir_function.symbol,
        Linkage::Local,
        &second_helper_signature,
    )?;
    let mut second_helper_context = module.make_context();
    second_helper_context.func.signature = second_helper_signature;
    let mut second_helper_builder_context = FunctionBuilderContext::new();
    let mut second_helper_builder = FunctionBuilder::new(
        &mut second_helper_context.func,
        &mut second_helper_builder_context,
    );
    let second_helper_function_refs: HashMap<&'static str, FuncRef> = HashMap::new();
    build_tiny_mir_body(
        &mut second_helper_builder,
        &second_helper_mir_function,
        &second_helper_function_refs,
    )?;
    second_helper_builder.seal_all_blocks();
    second_helper_builder.finalize();
    module.define_function(second_helper_function_id, &mut second_helper_context)?;
    module.clear_context(&mut second_helper_context);

    let mut exit_helper_signature = module.make_signature();
    exit_helper_signature.params.push(AbiParam::new(types::I32));
    exit_helper_signature
        .returns
        .push(AbiParam::new(types::I32));
    let exit_helper_function_id = module.declare_function(
        exit_helper_mir_function.symbol,
        Linkage::Local,
        &exit_helper_signature,
    )?;
    let mut exit_helper_context = module.make_context();
    exit_helper_context.func.signature = exit_helper_signature;
    let mut exit_helper_builder_context = FunctionBuilderContext::new();
    let mut exit_helper_builder = FunctionBuilder::new(
        &mut exit_helper_context.func,
        &mut exit_helper_builder_context,
    );
    let exit_helper_function_refs: HashMap<&'static str, FuncRef> = HashMap::new();
    build_tiny_mir_body(
        &mut exit_helper_builder,
        &exit_helper_mir_function,
        &exit_helper_function_refs,
    )?;
    exit_helper_builder.seal_all_blocks();
    exit_helper_builder.finalize();
    module.define_function(exit_helper_function_id, &mut exit_helper_context)?;
    module.clear_context(&mut exit_helper_context);

    let mut host_add_signature = module.make_signature();
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.returns.push(AbiParam::new(types::I32));
    let host_add_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
        Linkage::Import,
        &host_add_signature,
    )?;

    let mut function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_HELPER_SYMBOL,
        helper_function_id,
    );
    function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_SECOND_HELPER_SYMBOL,
        second_helper_function_id,
    );
    function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_EXIT_HELPER_SYMBOL,
        exit_helper_function_id,
    );
    function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
        host_add_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(&mut module, &mir_function, &function_ids)?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_quint_materialize_return_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_quint_materialize_return.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_quint_materialize_return_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_quint_materialize_return_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_quint_materialize_return_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_quint_materialize_return",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "helper_function",
        "tiny_block_param_quint_materialize_return_helper",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "second_helper_function",
        "tiny_block_param_quint_materialize_return_second_helper",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "exit_helper_function",
        "tiny_block_param_quint_materialize_return_exit_helper",
    )?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "imported_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_operation", "HostAddI32")?;
    require_compiler_mir_ingestion_field(&fields, "local_function_count", "3")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "local_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_HELPER_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "local_function_0_add_value", "2")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "local_function_1_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_SECOND_HELPER_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "local_function_1_add_value", "4")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "local_function_2_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_EXIT_HELPER_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "local_function_2_add_value", "8")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "8")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "JumpBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_call_literal", "-1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_terminator",
        "JumpBlockParamLocalFunctionCall",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_target",
        "materialize_imported_call_second",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_3_terminator",
        "JumpBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_3_call_literal", "-3")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_4_terminator",
        "JumpBlockParamLocalFunctionCall",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_4_target",
        "materialize_imported_call_third",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_5_terminator",
        "JumpBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_5_call_literal", "-5")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_6_terminator",
        "BranchBlockParamPositiveToI32Literals",
    )?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_value", "919")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_value", "967")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_7_terminator",
        "ReturnBlockParamLocalFunctionCall",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_7_return_param", "0")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "927")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "975")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "975")?;
    Ok(())
}

fn emit_compiler_mir_block_param_quad_materialize_return_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_quad_materialize_return_ingestion_fixture(&contents)?;
    static FUNCTION_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCKS: [TinyMirParamBlock; 7] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "materialize_local_call_first",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "materialize_local_call_first",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamLocalFunctionI32Call {
                target: "materialize_imported_call_first",
                function_symbol:
                    COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_HELPER_SYMBOL,
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "materialize_imported_call_first",
            params: &BLOCK_PARAMS,
            terminator:
                TinyMirParamBlockTerminator::JumpBlockParamImportedFunctionI32CallI32Literal {
                    target: "materialize_local_call_second",
                    function_symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
                    param: 0,
                    value: -3,
                },
        },
        TinyMirParamBlock {
            label: "materialize_local_call_second",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamLocalFunctionI32Call {
                target: "materialize_imported_call_second",
                function_symbol:
                    COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_SECOND_HELPER_SYMBOL,
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "materialize_imported_call_second",
            params: &BLOCK_PARAMS,
            terminator:
                TinyMirParamBlockTerminator::JumpBlockParamImportedFunctionI32CallI32Literal {
                    target: "branch_on_quad_materialized_call",
                    function_symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
                    param: 0,
                    value: -5,
                },
        },
        TinyMirParamBlock {
            label: "branch_on_quad_materialized_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "result",
                then_value: 811,
                else_block: "result",
                else_value: 853,
            },
        },
        TinyMirParamBlock {
            label: "result",
            params: &BLOCK_PARAMS,
            terminator:
                TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal {
                    function_symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
                    param: 0,
                    value: 19,
                },
        },
    ];

    let helper_mir_function = TinyMirFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_quad_materialize_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_HELPER_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32AddLiteral { param: 0, value: 2 },
    };
    let second_helper_mir_function = TinyMirFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_quad_materialize_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_SECOND_HELPER_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32AddLiteral { param: 0, value: 4 },
    };

    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_quad_materialize_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_quad_materialize_return",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

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

    let mut second_helper_signature = module.make_signature();
    second_helper_signature
        .params
        .push(AbiParam::new(types::I32));
    second_helper_signature
        .returns
        .push(AbiParam::new(types::I32));
    let second_helper_function_id = module.declare_function(
        second_helper_mir_function.symbol,
        Linkage::Local,
        &second_helper_signature,
    )?;
    let mut second_helper_context = module.make_context();
    second_helper_context.func.signature = second_helper_signature;
    let mut second_helper_builder_context = FunctionBuilderContext::new();
    let mut second_helper_builder = FunctionBuilder::new(
        &mut second_helper_context.func,
        &mut second_helper_builder_context,
    );
    let second_helper_function_refs: HashMap<&'static str, FuncRef> = HashMap::new();
    build_tiny_mir_body(
        &mut second_helper_builder,
        &second_helper_mir_function,
        &second_helper_function_refs,
    )?;
    second_helper_builder.seal_all_blocks();
    second_helper_builder.finalize();
    module.define_function(second_helper_function_id, &mut second_helper_context)?;
    module.clear_context(&mut second_helper_context);

    let mut host_add_signature = module.make_signature();
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.returns.push(AbiParam::new(types::I32));
    let host_add_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
        Linkage::Import,
        &host_add_signature,
    )?;

    let mut function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_HELPER_SYMBOL,
        helper_function_id,
    );
    function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_SECOND_HELPER_SYMBOL,
        second_helper_function_id,
    );
    function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
        host_add_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(&mut module, &mir_function, &function_ids)?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_quad_materialize_return_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_quad_materialize_return.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_quad_materialize_return_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_quad_materialize_return_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_quad_materialize_return_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_quad_materialize_return",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "helper_function",
        "tiny_block_param_quad_materialize_return_helper",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "second_helper_function",
        "tiny_block_param_quad_materialize_return_second_helper",
    )?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "local_function_count", "2")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "local_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_HELPER_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "local_function_0_add_value", "2")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "local_function_1_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_SECOND_HELPER_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "local_function_1_add_value", "4")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "imported_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_operation", "HostAddI32")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "7")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "JumpBlockParamLocalFunctionCall",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_target",
        "materialize_imported_call_first",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_terminator",
        "JumpBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_2_call_literal", "-3")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_3_terminator",
        "JumpBlockParamLocalFunctionCall",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_3_target",
        "materialize_imported_call_second",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_4_terminator",
        "JumpBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_4_call_literal", "-5")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_5_terminator",
        "BranchBlockParamPositiveToI32Literals",
    )?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_value", "811")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_value", "853")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_6_terminator",
        "ReturnBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_6_call_literal", "19")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "830")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "872")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "872")?;
    Ok(())
}

fn emit_compiler_mir_block_param_triple_materialize_return_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_triple_materialize_return_ingestion_fixture(&contents)?;
    static FUNCTION_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCKS: [TinyMirParamBlock; 6] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "materialize_imported_call_first",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "materialize_imported_call_first",
            params: &BLOCK_PARAMS,
            terminator:
                TinyMirParamBlockTerminator::JumpBlockParamImportedFunctionI32CallI32Literal {
                    target: "materialize_local_call",
                    function_symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
                    param: 0,
                    value: -2,
                },
        },
        TinyMirParamBlock {
            label: "materialize_local_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamLocalFunctionI32Call {
                target: "materialize_imported_call_second",
                function_symbol:
                    COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_HELPER_SYMBOL,
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "materialize_imported_call_second",
            params: &BLOCK_PARAMS,
            terminator:
                TinyMirParamBlockTerminator::JumpBlockParamImportedFunctionI32CallI32Literal {
                    target: "branch_on_triple_materialized_call",
                    function_symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
                    param: 0,
                    value: -4,
                },
        },
        TinyMirParamBlock {
            label: "branch_on_triple_materialized_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "result",
                then_value: 701,
                else_block: "result",
                else_value: 733,
            },
        },
        TinyMirParamBlock {
            label: "result",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamLocalFunctionI32Call {
                function_symbol:
                    COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_EXIT_HELPER_SYMBOL,
                param: 0,
            },
        },
    ];

    let helper_mir_function = TinyMirFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_triple_materialize_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_HELPER_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32AddLiteral { param: 0, value: 5 },
    };
    let exit_helper_mir_function = TinyMirFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_triple_materialize_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_EXIT_HELPER_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32AddLiteral { param: 0, value: 6 },
    };

    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_triple_materialize_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_triple_materialize_return",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

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

    let mut exit_helper_signature = module.make_signature();
    exit_helper_signature.params.push(AbiParam::new(types::I32));
    exit_helper_signature
        .returns
        .push(AbiParam::new(types::I32));
    let exit_helper_function_id = module.declare_function(
        exit_helper_mir_function.symbol,
        Linkage::Local,
        &exit_helper_signature,
    )?;
    let mut exit_helper_context = module.make_context();
    exit_helper_context.func.signature = exit_helper_signature;
    let mut exit_helper_builder_context = FunctionBuilderContext::new();
    let mut exit_helper_builder = FunctionBuilder::new(
        &mut exit_helper_context.func,
        &mut exit_helper_builder_context,
    );
    let exit_helper_function_refs: HashMap<&'static str, FuncRef> = HashMap::new();
    build_tiny_mir_body(
        &mut exit_helper_builder,
        &exit_helper_mir_function,
        &exit_helper_function_refs,
    )?;
    exit_helper_builder.seal_all_blocks();
    exit_helper_builder.finalize();
    module.define_function(exit_helper_function_id, &mut exit_helper_context)?;
    module.clear_context(&mut exit_helper_context);

    let mut host_add_signature = module.make_signature();
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.returns.push(AbiParam::new(types::I32));
    let host_add_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
        Linkage::Import,
        &host_add_signature,
    )?;

    let mut function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_HELPER_SYMBOL,
        helper_function_id,
    );
    function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_EXIT_HELPER_SYMBOL,
        exit_helper_function_id,
    );
    function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
        host_add_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(&mut module, &mir_function, &function_ids)?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_triple_materialize_return_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_triple_materialize_return.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_triple_materialize_return_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_triple_materialize_return_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_triple_materialize_return_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_triple_materialize_return",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "helper_function",
        "tiny_block_param_triple_materialize_return_helper",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "exit_helper_function",
        "tiny_block_param_triple_materialize_return_exit_helper",
    )?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "imported_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_operation", "HostAddI32")?;
    require_compiler_mir_ingestion_field(&fields, "local_function_count", "2")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "local_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_HELPER_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "local_function_0_add_value", "5")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "local_function_1_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_EXIT_HELPER_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "local_function_1_add_value", "6")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "6")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "JumpBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_call_literal", "-2")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_terminator",
        "JumpBlockParamLocalFunctionCall",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_target",
        "materialize_imported_call_second",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_3_terminator",
        "JumpBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_3_call_literal", "-4")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_4_terminator",
        "BranchBlockParamPositiveToI32Literals",
    )?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_value", "701")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_value", "733")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_5_terminator",
        "ReturnBlockParamLocalFunctionCall",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_5_return_param", "0")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "707")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "739")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "739")?;
    Ok(())
}

fn emit_compiler_mir_block_param_local_first_dual_materialize_return_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_local_first_dual_materialize_return_ingestion_fixture(
        &contents,
    )?;
    static FUNCTION_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCKS: [TinyMirParamBlock; 5] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "materialize_local_call",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "materialize_local_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamLocalFunctionI32Call {
                target: "materialize_imported_call",
                function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_FIRST_DUAL_MATERIALIZE_RETURN_HELPER_SYMBOL,
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "materialize_imported_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamImportedFunctionI32CallI32Literal {
                target: "branch_on_dual_materialized_call",
                function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_FIRST_DUAL_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
                param: 0,
                value: -7,
            },
        },
        TinyMirParamBlock {
            label: "branch_on_dual_materialized_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "result",
                then_value: 601,
                else_block: "result",
                else_value: 631,
            },
        },
        TinyMirParamBlock {
            label: "result",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamLocalFunctionI32Call {
                function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_FIRST_DUAL_MATERIALIZE_RETURN_HELPER_SYMBOL,
                param: 0,
            },
        },
    ];

    let helper_mir_function = TinyMirFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_FIRST_DUAL_MATERIALIZE_RETURN_HELPER_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32AddLiteral { param: 0, value: 4 },
    };

    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_FIRST_DUAL_MATERIALIZE_RETURN_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

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

    let mut host_add_signature = module.make_signature();
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.returns.push(AbiParam::new(types::I32));
    let host_add_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_FIRST_DUAL_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
        Linkage::Import,
        &host_add_signature,
    )?;

    let mut function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_FIRST_DUAL_MATERIALIZE_RETURN_HELPER_SYMBOL,
        helper_function_id,
    );
    function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_FIRST_DUAL_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
        host_add_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(&mut module, &mir_function, &function_ids)?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_local_first_dual_materialize_return_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_local_first_dual_materialize_return.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_local_first_dual_materialize_return_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_local_first_dual_materialize_return_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_local_first_dual_materialize_return_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_local_first_dual_materialize_return",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "helper_function",
        "tiny_block_param_local_first_dual_materialize_return_helper",
    )?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "local_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "local_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_FIRST_DUAL_MATERIALIZE_RETURN_HELPER_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "local_function_0_operation", "AddI32Literal")?;
    require_compiler_mir_ingestion_field(&fields, "local_function_0_add_value", "4")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "imported_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_FIRST_DUAL_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_operation", "HostAddI32")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "5")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "JumpBlockParamLocalFunctionCall",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_call_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_target", "materialize_imported_call")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_terminator",
        "JumpBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_2_call_literal", "-7")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_target",
        "branch_on_dual_materialized_call",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_3_terminator",
        "BranchBlockParamPositiveToI32Literals",
    )?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_value", "601")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_value", "631")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_4_terminator",
        "ReturnBlockParamLocalFunctionCall",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_4_return_param", "0")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_FIRST_DUAL_MATERIALIZE_RETURN_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "605")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "635")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "635")?;
    Ok(())
}

fn emit_compiler_mir_block_param_dual_materialize_return_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_dual_materialize_return_ingestion_fixture(&contents)?;
    static FUNCTION_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCKS: [TinyMirParamBlock; 5] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "materialize_imported_call",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "materialize_imported_call",
            params: &BLOCK_PARAMS,
            terminator:
                TinyMirParamBlockTerminator::JumpBlockParamImportedFunctionI32CallI32Literal {
                    target: "materialize_local_call",
                    function_symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_DUAL_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
                    param: 0,
                    value: -5,
                },
        },
        TinyMirParamBlock {
            label: "materialize_local_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamLocalFunctionI32Call {
                target: "branch_on_dual_materialized_call",
                function_symbol:
                    COMPILER_MIR_INGESTED_BLOCK_PARAM_DUAL_MATERIALIZE_RETURN_HELPER_SYMBOL,
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "branch_on_dual_materialized_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "result",
                then_value: 501,
                else_block: "result",
                else_value: 523,
            },
        },
        TinyMirParamBlock {
            label: "result",
            params: &BLOCK_PARAMS,
            terminator:
                TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal {
                    function_symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_DUAL_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
                    param: 0,
                    value: 17,
                },
        },
    ];

    let helper_mir_function = TinyMirFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_dual_materialize_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_DUAL_MATERIALIZE_RETURN_HELPER_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32AddLiteral { param: 0, value: 3 },
    };

    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_dual_materialize_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_DUAL_MATERIALIZE_RETURN_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_dual_materialize_return",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

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

    let mut host_add_signature = module.make_signature();
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.returns.push(AbiParam::new(types::I32));
    let host_add_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_DUAL_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
        Linkage::Import,
        &host_add_signature,
    )?;

    let mut function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_DUAL_MATERIALIZE_RETURN_HELPER_SYMBOL,
        helper_function_id,
    );
    function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_DUAL_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
        host_add_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(&mut module, &mir_function, &function_ids)?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_dual_materialize_return_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_dual_materialize_return.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_dual_materialize_return_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_dual_materialize_return_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_dual_materialize_return_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_dual_materialize_return",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "helper_function",
        "tiny_block_param_dual_materialize_return_helper",
    )?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "imported_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_DUAL_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_operation", "HostAddI32")?;
    require_compiler_mir_ingestion_field(&fields, "local_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "local_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_DUAL_MATERIALIZE_RETURN_HELPER_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "local_function_0_operation", "AddI32Literal")?;
    require_compiler_mir_ingestion_field(&fields, "local_function_0_add_value", "3")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "5")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "JumpBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_call_literal", "-5")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_target", "materialize_local_call")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_terminator",
        "JumpBlockParamLocalFunctionCall",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_2_call_param", "0")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_target",
        "branch_on_dual_materialized_call",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_3_terminator",
        "BranchBlockParamPositiveToI32Literals",
    )?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_value", "501")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_value", "523")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_4_terminator",
        "ReturnBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_4_call_literal", "17")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_DUAL_MATERIALIZE_RETURN_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "518")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "540")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "540")?;
    Ok(())
}

fn emit_compiler_mir_block_param_local_materialize_return_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_local_materialize_return_ingestion_fixture(&contents)?;
    static FUNCTION_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCKS: [TinyMirParamBlock; 4] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "materialize_local_call",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "materialize_local_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamLocalFunctionI32Call {
                target: "branch_on_materialized_call",
                function_symbol:
                    COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_MATERIALIZE_RETURN_HELPER_SYMBOL,
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "branch_on_materialized_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "result",
                then_value: 401,
                else_block: "result",
                else_value: 421,
            },
        },
        TinyMirParamBlock {
            label: "result",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamLocalFunctionI32Call {
                function_symbol:
                    COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_MATERIALIZE_RETURN_HELPER_SYMBOL,
                param: 0,
            },
        },
    ];

    let helper_mir_function = TinyMirFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_local_materialize_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_MATERIALIZE_RETURN_HELPER_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32AddLiteral { param: 0, value: 2 },
    };

    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_local_materialize_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_MATERIALIZE_RETURN_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_local_materialize_return",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

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
        COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_MATERIALIZE_RETURN_HELPER_SYMBOL,
        helper_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &local_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_local_materialize_return_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_local_materialize_return.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_local_materialize_return_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_local_materialize_return_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_local_materialize_return_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_local_materialize_return",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "helper_function",
        "tiny_block_param_local_materialize_return_helper",
    )?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "local_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "local_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_MATERIALIZE_RETURN_HELPER_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "local_function_0_operation", "AddI32Literal")?;
    require_compiler_mir_ingestion_field(&fields, "local_function_0_add_value", "2")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "4")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "JumpBlockParamLocalFunctionCall",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_call_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_target", "branch_on_materialized_call")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_terminator",
        "BranchBlockParamPositiveToI32Literals",
    )?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_value", "401")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_value", "421")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_3_terminator",
        "ReturnBlockParamLocalFunctionCall",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_3_return_param", "0")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_MATERIALIZE_RETURN_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "403")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "423")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "423")?;
    Ok(())
}

fn emit_compiler_mir_block_param_imported_materialize_return_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_imported_materialize_return_ingestion_fixture(&contents)?;
    static FUNCTION_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCKS: [TinyMirParamBlock; 4] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "materialize_imported_call",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "materialize_imported_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamImportedFunctionI32CallI32Literal {
                target: "branch_on_materialized_call",
                function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
                param: 0,
                value: -5,
            },
        },
        TinyMirParamBlock {
            label: "branch_on_materialized_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "result",
                then_value: 331,
                else_block: "result",
                else_value: 347,
            },
        },
        TinyMirParamBlock {
            label: "result",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal {
                function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
                param: 0,
                value: 13,
            },
        },
    ];
    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_imported_materialize_return",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_RETURN_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_imported_materialize_return",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut host_add_signature = module.make_signature();
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.returns.push(AbiParam::new(types::I32));
    let host_add_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
        Linkage::Import,
        &host_add_signature,
    )?;
    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
        host_add_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &imported_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_imported_materialize_return_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_imported_materialize_return.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_imported_materialize_return_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_imported_materialize_return_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_imported_materialize_return_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_imported_materialize_return",
    )?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "imported_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_operation", "HostAddI32")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "4")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "JumpBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_call_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_call_literal", "-5")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_target", "branch_on_materialized_call")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_terminator",
        "BranchBlockParamPositiveToI32Literals",
    )?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_value", "331")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_value", "347")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_3_terminator",
        "ReturnBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_3_call_literal", "13")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_RETURN_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "344")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "360")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "360")?;
    Ok(())
}

fn emit_compiler_mir_block_param_local_materialize_branch_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_local_materialize_branch_ingestion_fixture(&contents)?;
    static FUNCTION_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCKS: [TinyMirParamBlock; 4] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "materialize_local_call",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "materialize_local_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamLocalFunctionI32Call {
                target: "branch_on_materialized_call",
                function_symbol:
                    COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_MATERIALIZE_BRANCH_HELPER_SYMBOL,
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "branch_on_materialized_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "result",
                then_value: 293,
                else_block: "result",
                else_value: 307,
            },
        },
        TinyMirParamBlock {
            label: "result",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamI32(0),
        },
    ];

    let helper_mir_function = TinyMirFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_local_materialize_branch",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_MATERIALIZE_BRANCH_HELPER_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32AddLiteral { param: 0, value: 1 },
    };

    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_local_materialize_branch",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_MATERIALIZE_BRANCH_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_local_materialize_branch",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

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
        COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_MATERIALIZE_BRANCH_HELPER_SYMBOL,
        helper_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &local_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_local_materialize_branch_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_local_materialize_branch.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_local_materialize_branch_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_local_materialize_branch_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_local_materialize_branch_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_local_materialize_branch",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "helper_function",
        "tiny_block_param_local_materialize_branch_helper",
    )?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "local_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "local_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_MATERIALIZE_BRANCH_HELPER_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "local_function_0_operation", "AddI32Literal")?;
    require_compiler_mir_ingestion_field(&fields, "local_function_0_add_value", "1")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "4")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "JumpBlockParamLocalFunctionCall",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_call_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_target", "branch_on_materialized_call")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_terminator",
        "BranchBlockParamPositiveToI32Literals",
    )?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_value", "293")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_value", "307")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_terminator", "ReturnBlockParam")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_MATERIALIZE_BRANCH_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "293")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "307")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "307")?;
    Ok(())
}

fn emit_compiler_mir_block_param_imported_materialize_branch_ingestion_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = fs::read_to_string(input_path)?;
    parse_compiler_mir_block_param_imported_materialize_branch_ingestion_fixture(&contents)?;
    static FUNCTION_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCKS: [TinyMirParamBlock; 4] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "materialize_imported_call",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "materialize_imported_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamImportedFunctionI32CallI32Literal {
                target: "branch_on_materialized_call",
                function_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_BRANCH_HOST_ADD_SYMBOL,
                param: 0,
                value: -5,
            },
        },
        TinyMirParamBlock {
            label: "branch_on_materialized_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "result",
                then_value: 271,
                else_block: "result",
                else_value: 283,
            },
        },
        TinyMirParamBlock {
            label: "result",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamI32(0),
        },
    ];
    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_native_backend_compiler_mir_ingested_block_param_imported_materialize_branch",
        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_BRANCH_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_native_backend_compiler_mir_ingested_block_param_imported_materialize_branch",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut host_add_signature = module.make_signature();
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.returns.push(AbiParam::new(types::I32));
    let host_add_function_id = module.declare_function(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_BRANCH_HOST_ADD_SYMBOL,
        Linkage::Import,
        &host_add_signature,
    )?;
    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_BRANCH_HOST_ADD_SYMBOL,
        host_add_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &imported_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn parse_compiler_mir_block_param_imported_materialize_branch_ingestion_fixture(
    contents: &str,
) -> Result<(), Box<dyn Error>> {
    let fields = parse_compiler_mir_ingestion_fields(contents)?;
    require_compiler_mir_ingestion_field(
        &fields,
        "format",
        "gust.compiler_mir_ingestion.block_param_imported_materialize_branch.v1",
    )?;
    require_compiler_mir_ingestion_field(&fields, "producer", "compiler/mir.gst")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "producer_entry",
        "mir_emit_native_backend_block_param_imported_materialize_branch_ingestion_fixture",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "source_fixture",
        "compiler/mir_feature_block_param_imported_materialize_branch_preservation_source.gst",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "lowering_entry",
        "fixture_only_block_param_imported_materialize_branch_serialization",
    )?;
    require_compiler_mir_ingestion_field(
        &fields,
        "function",
        "tiny_block_param_imported_materialize_branch",
    )?;
    require_compiler_mir_ingestion_field(&fields, "param_count", "1")?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_count", "1")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "imported_function_0_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_BRANCH_HOST_ADD_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "imported_function_0_operation", "HostAddI32")?;
    require_compiler_mir_ingestion_field(&fields, "block_count", "4")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_1_terminator",
        "JumpBlockParamImportedFunctionCallI32Literal",
    )?;
    require_compiler_mir_ingestion_field(&fields, "block_1_call_param", "0")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_call_literal", "-5")?;
    require_compiler_mir_ingestion_field(&fields, "block_1_target", "branch_on_materialized_call")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "block_2_terminator",
        "BranchBlockParamPositiveToI32Literals",
    )?;
    require_compiler_mir_ingestion_field(&fields, "branch_then_value", "271")?;
    require_compiler_mir_ingestion_field(&fields, "branch_else_value", "283")?;
    require_compiler_mir_ingestion_field(&fields, "block_3_terminator", "ReturnBlockParam")?;
    require_compiler_mir_ingestion_field(
        &fields,
        "backend_symbol",
        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_BRANCH_SYMBOL,
    )?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_0_result", "271")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_1_result", "283")?;
    require_compiler_mir_ingestion_field(&fields, "expected_case_2_result", "283")?;
    Ok(())
}

fn emit_mir_block_graph_param_extern_materialize_return_i32_bundle_object(
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    static FUNCTION_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCKS: [TinyMirParamBlock; 4] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "materialize_imported_call",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "materialize_imported_call",
            params: &BLOCK_PARAMS,
            terminator:
                TinyMirParamBlockTerminator::JumpBlockParamImportedFunctionI32CallI32Literal {
                    target: "branch_on_materialized_call",
                    function_symbol: HOST_ADD_I32_SYMBOL,
                    param: 0,
                    value: -5,
                },
        },
        TinyMirParamBlock {
            label: "branch_on_materialized_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "result",
                then_value: 331,
                else_block: "result",
                else_value: 347,
            },
        },
        TinyMirParamBlock {
            label: "result",
            params: &BLOCK_PARAMS,
            terminator:
                TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal {
                    function_symbol: HOST_ADD_I32_SYMBOL,
                    param: 0,
                    value: 13,
                },
        },
    ];
    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_param_extern_materialize_return_i32_bundle",
        symbol: "tiny_cranelift_mir_block_graph_param_extern_materialize_return_i32",
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_block_graph_param_extern_materialize_return_i32_bundle",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut host_add_signature = module.make_signature();
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.returns.push(AbiParam::new(types::I32));
    let host_add_function_id =
        module.declare_function(HOST_ADD_I32_SYMBOL, Linkage::Import, &host_add_signature)?;

    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(HOST_ADD_I32_SYMBOL, host_add_function_id);

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &imported_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn emit_mir_block_graph_param_extern_materialize_i32_bundle_object(
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    static FUNCTION_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCKS: [TinyMirParamBlock; 4] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "materialize_imported_call",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "materialize_imported_call",
            params: &BLOCK_PARAMS,
            terminator:
                TinyMirParamBlockTerminator::JumpBlockParamImportedFunctionI32CallI32Literal {
                    target: "branch_on_materialized_call",
                    function_symbol: HOST_ADD_I32_SYMBOL,
                    param: 0,
                    value: -5,
                },
        },
        TinyMirParamBlock {
            label: "branch_on_materialized_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "result",
                then_value: 271,
                else_block: "result",
                else_value: 283,
            },
        },
        TinyMirParamBlock {
            label: "result",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamI32(0),
        },
    ];
    let mir_function = TinyMirParamBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_param_extern_materialize_i32_bundle",
        symbol: "tiny_cranelift_mir_block_graph_param_extern_materialize_i32",
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_block_graph_param_extern_materialize_i32_bundle",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

    let mut host_add_signature = module.make_signature();
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.params.push(AbiParam::new(types::I32));
    host_add_signature.returns.push(AbiParam::new(types::I32));
    let host_add_function_id =
        module.declare_function(HOST_ADD_I32_SYMBOL, Linkage::Import, &host_add_signature)?;

    let mut imported_function_ids: HashMap<&'static str, FuncId> = HashMap::new();
    imported_function_ids.insert(HOST_ADD_I32_SYMBOL, host_add_function_id);

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &mir_function,
        &imported_function_ids,
    )?;
    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
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
            terminator: TinyMirBlockTerminator::Jump {
                target: "increment",
            },
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
            terminator: TinyMirBlockTerminator::Jump {
                target: "increment",
            },
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
    local_function_ids.insert(
        MIR_BLOCK_GRAPH_PARAM_CALL_HELPER_I32_SYMBOL,
        helper_function_id,
    );

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

fn emit_mir_block_graph_param_call_materialize_i32_bundle_object(
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    static FUNCTION_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];
    static BLOCKS: [TinyMirParamBlock; 4] = [
        TinyMirParamBlock {
            label: "entry",
            params: &[],
            terminator: TinyMirParamBlockTerminator::JumpFunctionParamI32 {
                target: "materialize_local_call",
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "materialize_local_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::JumpBlockParamLocalFunctionI32Call {
                target: "branch_on_materialized_call",
                function_symbol: MIR_BLOCK_GRAPH_PARAM_CALL_HELPER_I32_SYMBOL,
                param: 0,
            },
        },
        TinyMirParamBlock {
            label: "branch_on_materialized_call",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::BranchBlockParamI32PositiveToI32Literals {
                param: 0,
                then_block: "result",
                then_value: 293,
                else_block: "result",
                else_value: 307,
            },
        },
        TinyMirParamBlock {
            label: "result",
            params: &BLOCK_PARAMS,
            terminator: TinyMirParamBlockTerminator::ReturnBlockParamI32(0),
        },
    ];

    let helper_mir_function = TinyMirFunction {
        object_name: "gust_cranelift_mir_block_graph_param_call_materialize_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_PARAM_CALL_HELPER_I32_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        locals: &[],
        statements: &[],
        terminator: TinyMirTerminator::ReturnParamI32AddLiteral { param: 0, value: 1 },
    };

    let materialize_function = TinyMirParamBlockFunction {
        object_name: "gust_cranelift_mir_block_graph_param_call_materialize_i32_bundle",
        symbol: MIR_BLOCK_GRAPH_PARAM_CALL_MATERIALIZE_I32_SYMBOL,
        params: &FUNCTION_PARAMS,
        return_type: TinyMirType::I32,
        entry_block: "entry",
        blocks: &BLOCKS,
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder = ObjectBuilder::new(
        isa,
        "gust_cranelift_mir_block_graph_param_call_materialize_i32_bundle",
        default_libcall_names(),
    )?;
    let mut module = ObjectModule::new(object_builder);

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
        MIR_BLOCK_GRAPH_PARAM_CALL_HELPER_I32_SYMBOL,
        helper_function_id,
    );

    define_tiny_mir_param_block_graph_exported_function(
        &mut module,
        &materialize_function,
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
            terminator:
                TinyMirParamBlockTerminator::BranchBlockParamImportedFunctionI32CallPositive {
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
    host_add_one_signature
        .params
        .push(AbiParam::new(types::I32));
    host_add_one_signature
        .returns
        .push(AbiParam::new(types::I32));
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
    static MIR_BLOCK_GRAPH_PARAM_EXTERN_ADD_I32_BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];

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
            terminator:
                TinyMirParamBlockTerminator::ReturnBlockParamImportedFunctionI32CallI32Literal {
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
    let host_add_function_id =
        module.declare_function(HOST_ADD_I32_SYMBOL, Linkage::Import, &host_add_signature)?;

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
    host_predicate_signature
        .params
        .push(AbiParam::new(types::I32));
    host_predicate_signature
        .returns
        .push(AbiParam::new(types::I32));
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
    static MIR_BLOCK_GRAPH_PARAM_MERGE_CALL_I32_BLOCK_PARAMS: [TinyMirType; 1] = [TinyMirType::I32];

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
        TinyMirType::Void => panic!("void tiny MIR type has no Cranelift value representation"),
    }
}

fn validate_compiler_mir_ingestion_lowering_readiness(
    mir_function: &CompilerMirLoweringFunction<'_>,
) -> Result<(), Box<dyn Error>> {
    for block in &mir_function.blocks {
        if !block.parameters.is_empty() {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                "canonical compiler MIR block parameters are validated but object lowering is not enabled until the Phase 9E shared block-parameter lowering core",
            )
            .into());
        }
        if block.statements.iter().any(|statement| {
            matches!(
                statement,
                CompilerMirLoweringStatement::LocalI32SetBlockParam { .. }
            )
        }) {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                "canonical compiler MIR block-parameter local materialization is validated but object lowering is not enabled until the Phase 9E shared block-parameter lowering core",
            )
            .into());
        }
        match &block.terminator {
            CompilerMirLoweringTerminator::ReturnBlockParamI32(_)
            | CompilerMirLoweringTerminator::BranchBlockParamI32Positive { .. } => {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    "canonical compiler MIR block-parameter terminators are validated but object lowering is not enabled until the Phase 9E shared block-parameter lowering core",
                )
                .into());
            }
            CompilerMirLoweringTerminator::Jump { edge } => {
                if !edge.arguments.is_empty() {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        "canonical compiler MIR edge arguments are validated but object lowering is not enabled until the Phase 9E shared block-parameter lowering core",
                    )
                    .into());
                }
            }
            CompilerMirLoweringTerminator::BranchI32Literal {
                then_edge,
                else_edge,
                ..
            }
            | CompilerMirLoweringTerminator::BranchLocalI32Positive {
                then_edge,
                else_edge,
                ..
            } => {
                if !then_edge.arguments.is_empty() || !else_edge.arguments.is_empty() {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        "canonical compiler MIR edge arguments are validated but object lowering is not enabled until the Phase 9E shared block-parameter lowering core",
                    )
                    .into());
                }
            }
            CompilerMirLoweringTerminator::ReturnI32(_)
            | CompilerMirLoweringTerminator::ReturnLocalI32(_)
            | CompilerMirLoweringTerminator::ReturnVoid => {}
        }
    }
    Ok(())
}

fn lower_compiler_mir_ingestion_function_to_object(
    output_path: &Path,
    mir_function: &CompilerMirLoweringFunction<'_>,
) -> Result<(), Box<dyn Error>> {
    validate_compiler_mir_ingestion_lowering_readiness(mir_function)?;
    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(settings::Flags::new(settings::builder()))?;
    let object_builder =
        ObjectBuilder::new(isa, mir_function.object_name, default_libcall_names())?;
    let mut module = ObjectModule::new(object_builder);

    define_compiler_mir_ingestion_exported_function(&mut module, mir_function)?;

    let object_product = module.finish();
    fs::write(output_path, object_product.emit()?)?;
    Ok(())
}

fn define_compiler_mir_ingestion_exported_function(
    module: &mut ObjectModule,
    mir_function: &CompilerMirLoweringFunction<'_>,
) -> Result<(), Box<dyn Error>> {
    let mut signature = module.make_signature();
    for param in &mir_function.params {
        signature
            .params
            .push(AbiParam::new(tiny_mir_type_to_cranelift_type(*param)));
    }
    if matches!(mir_function.return_type, TinyMirType::I32) {
        signature.returns.push(AbiParam::new(types::I32));
    }

    let function_id = module.declare_function(mir_function.symbol, Linkage::Export, &signature)?;
    let mut context = module.make_context();
    context.func.signature = signature;

    let mut builder_context = FunctionBuilderContext::new();
    let mut builder = FunctionBuilder::new(&mut context.func, &mut builder_context);
    build_compiler_mir_ingestion_body(&mut builder, mir_function)?;
    builder.seal_all_blocks();
    builder.finalize();

    module.define_function(function_id, &mut context)?;
    module.clear_context(&mut context);
    Ok(())
}

fn build_compiler_mir_ingestion_body(
    builder: &mut FunctionBuilder<'_>,
    mir_function: &CompilerMirLoweringFunction<'_>,
) -> Result<(), Box<dyn Error>> {
    let mut cranelift_blocks: HashMap<&str, Block> = HashMap::new();
    for block in &mir_function.blocks {
        let cranelift_block = builder.create_block();
        if cranelift_blocks
            .insert(block.label, cranelift_block)
            .is_some()
        {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "duplicate compiler MIR lowering block label: {}",
                    block.label
                ),
            )
            .into());
        }
    }

    let entry_block = *cranelift_blocks
        .get(mir_function.entry_block)
        .ok_or_else(|| {
            IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "unknown compiler MIR lowering entry block: {}",
                    mir_function.entry_block
                ),
            )
        })?;
    builder.append_block_params_for_function_params(entry_block);
    let function_params = builder.block_params(entry_block).to_vec();

    let mut local_slots: HashMap<&str, Variable> = HashMap::new();
    for local in &mir_function.locals {
        let local_type = match local.ty {
            TinyMirType::I32 => types::I32,
            TinyMirType::Void => {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "unsupported compiler MIR lowering local type: {}",
                        local.name
                    ),
                )
                .into());
            }
        };
        let slot = builder.declare_var(local_type);
        if local_slots.insert(local.name, slot).is_some() {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!("duplicate compiler MIR lowering local: {}", local.name),
            )
            .into());
        }
    }

    for block in &mir_function.blocks {
        let current_block = *cranelift_blocks.get(block.label).ok_or_else(|| {
            IoError::new(
                ErrorKind::InvalidInput,
                format!("unknown compiler MIR lowering block: {}", block.label),
            )
        })?;
        builder.switch_to_block(current_block);

        for statement in &block.statements {
            match *statement {
                CompilerMirLoweringStatement::LocalI32Set { name, value } => {
                    let slot = *local_slots.get(name).ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown compiler MIR lowering local set target: {name}"),
                        )
                    })?;
                    let literal_value = builder.ins().iconst(types::I32, i64::from(value));
                    builder.def_var(slot, literal_value);
                }
                CompilerMirLoweringStatement::LocalI32SetParam { name, param } => {
                    let slot = *local_slots.get(name).ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown compiler MIR lowering local set target: {name}"),
                        )
                    })?;
                    let param_value = function_params.get(param).copied().ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown compiler MIR lowering function parameter: {param}"),
                        )
                    })?;
                    builder.def_var(slot, param_value);
                }
                CompilerMirLoweringStatement::LocalI32SetBlockParam { .. } => {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        "compiler MIR block-parameter local materialization reached lowering before the Phase 9E shared lowering core",
                    )
                    .into());
                }
                CompilerMirLoweringStatement::LocalI32AddI32Literal { name, value } => {
                    let slot = *local_slots.get(name).ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown compiler MIR lowering local add target: {name}"),
                        )
                    })?;
                    let current_value = builder.use_var(slot);
                    let updated_value = builder.ins().iadd_imm(current_value, i64::from(value));
                    builder.def_var(slot, updated_value);
                }
                CompilerMirLoweringStatement::LocalI32AddParam { name, param } => {
                    let slot = *local_slots.get(name).ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown compiler MIR lowering local add target: {name}"),
                        )
                    })?;
                    let param_value = function_params.get(param).copied().ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown compiler MIR lowering function parameter: {param}"),
                        )
                    })?;
                    let current_value = builder.use_var(slot);
                    let updated_value = builder.ins().iadd(current_value, param_value);
                    builder.def_var(slot, updated_value);
                }
            }
        }

        match &block.terminator {
            CompilerMirLoweringTerminator::ReturnI32(value) => {
                let return_value = builder.ins().iconst(types::I32, i64::from(*value));
                builder.ins().return_(&[return_value]);
            }
            CompilerMirLoweringTerminator::ReturnLocalI32(name) => {
                let slot = *local_slots.get(name).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown compiler MIR lowering return local: {name}"),
                    )
                })?;
                let return_value = builder.use_var(slot);
                builder.ins().return_(&[return_value]);
            }
            CompilerMirLoweringTerminator::ReturnBlockParamI32(_)
            | CompilerMirLoweringTerminator::BranchBlockParamI32Positive { .. } => {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    "compiler MIR block-parameter terminator reached lowering before the Phase 9E shared lowering core",
                )
                .into());
            }
            CompilerMirLoweringTerminator::ReturnVoid => {
                builder.ins().return_(&[]);
            }
            CompilerMirLoweringTerminator::Jump { edge } => {
                let target_block = *cranelift_blocks.get(edge.target).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "unknown compiler MIR lowering jump target: {}",
                            edge.target
                        ),
                    )
                })?;
                builder.ins().jump(target_block, &[]);
            }
            CompilerMirLoweringTerminator::BranchI32Literal {
                condition,
                then_edge,
                else_edge,
            } => {
                let then_cranelift_block = *cranelift_blocks.get(then_edge.target).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "unknown compiler MIR lowering then block: {}",
                            then_edge.target
                        ),
                    )
                })?;
                let else_cranelift_block = *cranelift_blocks.get(else_edge.target).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "unknown compiler MIR lowering else block: {}",
                            else_edge.target
                        ),
                    )
                })?;
                let condition_value = builder.ins().iconst(types::I32, i64::from(*condition));
                let branch_condition = builder.ins().icmp_imm(IntCC::NotEqual, condition_value, 0);
                builder.ins().brif(
                    branch_condition,
                    then_cranelift_block,
                    &[],
                    else_cranelift_block,
                    &[],
                );
            }
            CompilerMirLoweringTerminator::BranchLocalI32Positive {
                name,
                then_edge,
                else_edge,
            } => {
                let slot = *local_slots.get(name).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown compiler MIR lowering branch local: {name}"),
                    )
                })?;
                let then_cranelift_block = *cranelift_blocks.get(then_edge.target).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "unknown compiler MIR lowering then block: {}",
                            then_edge.target
                        ),
                    )
                })?;
                let else_cranelift_block = *cranelift_blocks.get(else_edge.target).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "unknown compiler MIR lowering else block: {}",
                            else_edge.target
                        ),
                    )
                })?;
                let condition_value = builder.use_var(slot);
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
        }
    }

    Ok(())
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
    match mir_function.return_type {
        TinyMirType::I32 => signature.returns.push(AbiParam::new(types::I32)),
        TinyMirType::Void => {}
    }

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
    match mir_function.return_type {
        TinyMirType::I32 => signature.returns.push(AbiParam::new(types::I32)),
        TinyMirType::Void => {}
    }

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
            TinyMirParamBlockTerminator::JumpBlockParamLocalFunctionI32Call {
                target,
                function_symbol,
                param,
            } => {
                let target_block = *cranelift_blocks.get(target).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param local call materialize jump target block: {target}"),
                    )
                })?;
                let argument_value = {
                    let block_params = builder.block_params(current_block);
                    block_params.get(param).copied().ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR param local call materialize block param index: {param}"),
                        )
                    })?
                };
                let function_ref = *local_function_refs.get(function_symbol).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param block local call materialize function: {function_symbol}"),
                    )
                })?;
                let call_inst = builder.ins().call(function_ref, &[argument_value]);
                let call_value = builder.inst_results(call_inst)[0];
                let jump_arguments = [BlockArg::Value(call_value)];
                builder.ins().jump(target_block, &jump_arguments);
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
            TinyMirParamBlockTerminator::JumpBlockParamImportedFunctionI32CallI32Literal {
                target,
                function_symbol,
                param,
                value,
            } => {
                let target_block = *cranelift_blocks.get(target).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param imported materialize jump target block: {target}"),
                    )
                })?;
                let argument_value = {
                    let block_params = builder.block_params(current_block);
                    block_params.get(param).copied().ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown tiny MIR param imported materialize block param index: {param}"),
                        )
                    })?
                };
                let function_ref = *local_function_refs.get(function_symbol).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown tiny MIR param block imported materialize function: {function_symbol}"),
                    )
                })?;
                let literal_value = builder.ins().iconst(types::I32, i64::from(value));
                let call_inst = builder.ins().call(function_ref, &[argument_value, literal_value]);
                let call_value = builder.inst_results(call_inst)[0];
                let jump_arguments = [BlockArg::Value(call_value)];
                builder.ins().jump(target_block, &jump_arguments);
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
        TinyMirTerminator::ReturnVoid => {
            builder.ins().return_(&[]);
        }
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
