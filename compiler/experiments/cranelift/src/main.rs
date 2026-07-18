use std::collections::{HashMap, HashSet, VecDeque};
use std::env;
use std::error::Error;
use std::ffi::OsString;
use std::fmt;
use std::fs;
use std::io::{Error as IoError, ErrorKind, Write};
use std::path::{Path, PathBuf};
use std::process::Command;

use cranelift_codegen::ir::instructions::BlockArg;
use cranelift_codegen::ir::{AbiParam, Block, FuncRef, InstBuilder, Type, condcodes::IntCC, types};
use cranelift_codegen::settings::{self, Configurable};
use cranelift_frontend::{FunctionBuilder, FunctionBuilderContext, Variable};
use cranelift_module::{FuncId, Linkage, Module, default_libcall_names};
use cranelift_object::{ObjectBuilder, ObjectModule};
use object::write::{
    Object as WriteObject, StandardSection, Symbol as WriteSymbol, SymbolSection,
};
use object::{
    Architecture, BinaryFormat, Endianness, Object, ObjectSection, ObjectSymbol,
    RelocationTarget, SectionKind, SymbolFlags, SymbolKind, SymbolScope,
};

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
    Bool,
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
const COMPILER_MIR_CANONICAL_MODULE_FORMAT: &str = "gust.compiler_mir_ingestion.v2";
const COMPILER_MIR_CANONICAL_MODULE_FUNCTION_FORMAT: &str =
    "gust.compiler_mir_ingestion.function.v2";

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
    "metadata_0_payload: kind=LocalBinding;local=value;origin=compiler/mir_feature_local_binding_read_provenance_metadata_preservation_source.gst;codegen=none;proof=provenance_is_diagnostic_only_after_typecheck\n",
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
    "metadata_0_payload: kind=LinearResource;state=Live;local=value;cleanup_required=false;codegen=none;proof=resource_cleanup_was_verified_before_native_lowering\n",
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
    "metadata_0_payload: kind=RuntimeCall;symbol=tiny_runtime_boundary;origin=compiler/mir_to_c_native_boundary_metadata_smoke_test_entry.gst;codegen=none;proof=runtime_boundary_classification_is_registry_validated\n",
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

const PHASE9E_CANONICAL_BLOCK_PARAM_UPDATE_BRANCH_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_block_param_update_branch\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_update_branch\n",
    "parameter_count: 1\n",
    "parameter_0_type: int\n",
    "return_type: int\n",
    "local_count: 0\n",
    "entry_block: entry\n",
    "block_count: 5\n",
    "block_0_label: entry\n",
    "block_0_parameter_count: 0\n",
    "block_0_statement_count: 0\n",
    "block_0_terminator_kind: Jump\n",
    "block_0_terminator_target: increment\n",
    "block_0_terminator_argument_count: 1\n",
    "block_0_terminator_argument_0_kind: FunctionParamI32\n",
    "block_0_terminator_argument_0_param: 0\n",
    "block_1_label: increment\n",
    "block_1_parameter_count: 1\n",
    "block_1_parameter_0_name: value\n",
    "block_1_parameter_0_type: int\n",
    "block_1_statement_count: 0\n",
    "block_1_terminator_kind: Jump\n",
    "block_1_terminator_target: branch\n",
    "block_1_terminator_argument_count: 1\n",
    "block_1_terminator_argument_0_kind: BlockParamI32AddI32Literal\n",
    "block_1_terminator_argument_0_block_param: value\n",
    "block_1_terminator_argument_0_value: 4\n",
    "block_2_label: branch\n",
    "block_2_parameter_count: 1\n",
    "block_2_parameter_0_name: adjusted\n",
    "block_2_parameter_0_type: int\n",
    "block_2_statement_count: 0\n",
    "block_2_terminator_kind: BranchBlockParamI32Positive\n",
    "block_2_terminator_block_param: adjusted\n",
    "block_2_terminator_then: positive\n",
    "block_2_terminator_then_argument_count: 0\n",
    "block_2_terminator_else: non_positive\n",
    "block_2_terminator_else_argument_count: 0\n",
    "block_3_label: positive\n",
    "block_3_parameter_count: 0\n",
    "block_3_statement_count: 0\n",
    "block_3_terminator_kind: ReturnI32\n",
    "block_3_terminator_value: 67\n",
    "block_4_label: non_positive\n",
    "block_4_parameter_count: 0\n",
    "block_4_statement_count: 0\n",
    "block_4_terminator_kind: ReturnI32\n",
    "block_4_terminator_value: 71\n",
    "metadata_count: 0\n",
    "expected_exit: 67\n",
);

const PHASE9E_CANONICAL_BLOCK_PARAM_MERGE_UPDATE_BRANCH_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_block_param_merge_update_branch\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_merge_update_branch\n",
    "parameter_count: 1\n",
    "parameter_0_type: int\n",
    "return_type: int\n",
    "local_count: 0\n",
    "entry_block: entry\n",
    "block_count: 6\n",
    "block_0_label: entry\n",
    "block_0_parameter_count: 0\n",
    "block_0_statement_count: 0\n",
    "block_0_terminator_kind: Jump\n",
    "block_0_terminator_target: adjust\n",
    "block_0_terminator_argument_count: 1\n",
    "block_0_terminator_argument_0_kind: FunctionParamI32\n",
    "block_0_terminator_argument_0_param: 0\n",
    "block_1_label: adjust\n",
    "block_1_parameter_count: 1\n",
    "block_1_parameter_0_name: value\n",
    "block_1_parameter_0_type: int\n",
    "block_1_statement_count: 0\n",
    "block_1_terminator_kind: Jump\n",
    "block_1_terminator_target: branch\n",
    "block_1_terminator_argument_count: 1\n",
    "block_1_terminator_argument_0_kind: BlockParamI32AddI32Literal\n",
    "block_1_terminator_argument_0_block_param: value\n",
    "block_1_terminator_argument_0_value: 4\n",
    "block_2_label: branch\n",
    "block_2_parameter_count: 1\n",
    "block_2_parameter_0_name: adjusted\n",
    "block_2_parameter_0_type: int\n",
    "block_2_statement_count: 0\n",
    "block_2_terminator_kind: BranchBlockParamI32Positive\n",
    "block_2_terminator_block_param: adjusted\n",
    "block_2_terminator_then: then_value\n",
    "block_2_terminator_then_argument_count: 1\n",
    "block_2_terminator_then_argument_0_kind: I32Literal\n",
    "block_2_terminator_then_argument_0_value: 181\n",
    "block_2_terminator_else: else_value\n",
    "block_2_terminator_else_argument_count: 1\n",
    "block_2_terminator_else_argument_0_kind: I32Literal\n",
    "block_2_terminator_else_argument_0_value: 191\n",
    "block_3_label: then_value\n",
    "block_3_parameter_count: 1\n",
    "block_3_parameter_0_name: selected_then\n",
    "block_3_parameter_0_type: int\n",
    "block_3_statement_count: 0\n",
    "block_3_terminator_kind: Jump\n",
    "block_3_terminator_target: join\n",
    "block_3_terminator_argument_count: 1\n",
    "block_3_terminator_argument_0_kind: BlockParamI32\n",
    "block_3_terminator_argument_0_block_param: selected_then\n",
    "block_4_label: else_value\n",
    "block_4_parameter_count: 1\n",
    "block_4_parameter_0_name: selected_else\n",
    "block_4_parameter_0_type: int\n",
    "block_4_statement_count: 0\n",
    "block_4_terminator_kind: Jump\n",
    "block_4_terminator_target: join\n",
    "block_4_terminator_argument_count: 1\n",
    "block_4_terminator_argument_0_kind: BlockParamI32\n",
    "block_4_terminator_argument_0_block_param: selected_else\n",
    "block_5_label: join\n",
    "block_5_parameter_count: 1\n",
    "block_5_parameter_0_name: result\n",
    "block_5_parameter_0_type: int\n",
    "block_5_statement_count: 0\n",
    "block_5_terminator_kind: ReturnBlockParamI32\n",
    "block_5_terminator_block_param: result\n",
    "metadata_count: 0\n",
    "expected_exit: 181\n",
);

const PHASE9E_CANONICAL_BLOCK_PARAM_DUAL_MATERIALIZE_RETURN_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_block_param_dual_materialize_return\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_dual_materialize_return\n",
    "parameter_count: 1\n",
    "parameter_0_type: int\n",
    "return_type: int\n",
    "local_count: 0\n",
    "entry_block: entry\n",
    "block_count: 4\n",
    "block_0_label: entry\n",
    "block_0_parameter_count: 0\n",
    "block_0_statement_count: 0\n",
    "block_0_terminator_kind: Jump\n",
    "block_0_terminator_target: adjust\n",
    "block_0_terminator_argument_count: 1\n",
    "block_0_terminator_argument_0_kind: FunctionParamI32\n",
    "block_0_terminator_argument_0_param: 0\n",
    "block_1_label: adjust\n",
    "block_1_parameter_count: 1\n",
    "block_1_parameter_0_name: input_value\n",
    "block_1_parameter_0_type: int\n",
    "block_1_statement_count: 0\n",
    "block_1_terminator_kind: Jump\n",
    "block_1_terminator_target: branch\n",
    "block_1_terminator_argument_count: 2\n",
    "block_1_terminator_argument_0_kind: I32Literal\n",
    "block_1_terminator_argument_0_value: -100\n",
    "block_1_terminator_argument_1_kind: BlockParamI32AddI32Literal\n",
    "block_1_terminator_argument_1_block_param: input_value\n",
    "block_1_terminator_argument_1_value: -2\n",
    "block_2_label: branch\n",
    "block_2_parameter_count: 2\n",
    "block_2_parameter_0_name: carry_0\n",
    "block_2_parameter_0_type: int\n",
    "block_2_parameter_1_name: condition\n",
    "block_2_parameter_1_type: int\n",
    "block_2_statement_count: 0\n",
    "block_2_terminator_kind: BranchBlockParamI32Positive\n",
    "block_2_terminator_block_param: condition\n",
    "block_2_terminator_then: result\n",
    "block_2_terminator_then_argument_count: 2\n",
    "block_2_terminator_then_argument_0_kind: I32Literal\n",
    "block_2_terminator_then_argument_0_value: 100\n",
    "block_2_terminator_then_argument_1_kind: I32Literal\n",
    "block_2_terminator_then_argument_1_value: 518\n",
    "block_2_terminator_else: result\n",
    "block_2_terminator_else_argument_count: 2\n",
    "block_2_terminator_else_argument_0_kind: I32Literal\n",
    "block_2_terminator_else_argument_0_value: -200\n",
    "block_2_terminator_else_argument_1_kind: I32Literal\n",
    "block_2_terminator_else_argument_1_value: 540\n",
    "block_3_label: result\n",
    "block_3_parameter_count: 2\n",
    "block_3_parameter_0_name: result_carry_0\n",
    "block_3_parameter_0_type: int\n",
    "block_3_parameter_1_name: result\n",
    "block_3_parameter_1_type: int\n",
    "block_3_statement_count: 0\n",
    "block_3_terminator_kind: ReturnBlockParamI32\n",
    "block_3_terminator_block_param: result\n",
    "metadata_count: 0\n",
    "expected_exit: 6\n",
);

const PHASE9E_CANONICAL_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_block_param_triple_materialize_return\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_triple_materialize_return\n",
    "parameter_count: 1\n",
    "parameter_0_type: int\n",
    "return_type: int\n",
    "local_count: 0\n",
    "entry_block: entry\n",
    "block_count: 4\n",
    "block_0_label: entry\n",
    "block_0_parameter_count: 0\n",
    "block_0_statement_count: 0\n",
    "block_0_terminator_kind: Jump\n",
    "block_0_terminator_target: adjust\n",
    "block_0_terminator_argument_count: 1\n",
    "block_0_terminator_argument_0_kind: FunctionParamI32\n",
    "block_0_terminator_argument_0_param: 0\n",
    "block_1_label: adjust\n",
    "block_1_parameter_count: 1\n",
    "block_1_parameter_0_name: input_value\n",
    "block_1_parameter_0_type: int\n",
    "block_1_statement_count: 0\n",
    "block_1_terminator_kind: Jump\n",
    "block_1_terminator_target: branch\n",
    "block_1_terminator_argument_count: 3\n",
    "block_1_terminator_argument_0_kind: I32Literal\n",
    "block_1_terminator_argument_0_value: -100\n",
    "block_1_terminator_argument_1_kind: I32Literal\n",
    "block_1_terminator_argument_1_value: -101\n",
    "block_1_terminator_argument_2_kind: BlockParamI32AddI32Literal\n",
    "block_1_terminator_argument_2_block_param: input_value\n",
    "block_1_terminator_argument_2_value: -1\n",
    "block_2_label: branch\n",
    "block_2_parameter_count: 3\n",
    "block_2_parameter_0_name: carry_0\n",
    "block_2_parameter_0_type: int\n",
    "block_2_parameter_1_name: carry_1\n",
    "block_2_parameter_1_type: int\n",
    "block_2_parameter_2_name: condition\n",
    "block_2_parameter_2_type: int\n",
    "block_2_statement_count: 0\n",
    "block_2_terminator_kind: BranchBlockParamI32Positive\n",
    "block_2_terminator_block_param: condition\n",
    "block_2_terminator_then: result\n",
    "block_2_terminator_then_argument_count: 3\n",
    "block_2_terminator_then_argument_0_kind: I32Literal\n",
    "block_2_terminator_then_argument_0_value: 100\n",
    "block_2_terminator_then_argument_1_kind: I32Literal\n",
    "block_2_terminator_then_argument_1_value: 101\n",
    "block_2_terminator_then_argument_2_kind: I32Literal\n",
    "block_2_terminator_then_argument_2_value: 707\n",
    "block_2_terminator_else: result\n",
    "block_2_terminator_else_argument_count: 3\n",
    "block_2_terminator_else_argument_0_kind: I32Literal\n",
    "block_2_terminator_else_argument_0_value: -200\n",
    "block_2_terminator_else_argument_1_kind: I32Literal\n",
    "block_2_terminator_else_argument_1_value: -201\n",
    "block_2_terminator_else_argument_2_kind: I32Literal\n",
    "block_2_terminator_else_argument_2_value: 739\n",
    "block_3_label: result\n",
    "block_3_parameter_count: 3\n",
    "block_3_parameter_0_name: result_carry_0\n",
    "block_3_parameter_0_type: int\n",
    "block_3_parameter_1_name: result_carry_1\n",
    "block_3_parameter_1_type: int\n",
    "block_3_parameter_2_name: result\n",
    "block_3_parameter_2_type: int\n",
    "block_3_statement_count: 0\n",
    "block_3_terminator_kind: ReturnBlockParamI32\n",
    "block_3_terminator_block_param: result\n",
    "metadata_count: 0\n",
    "expected_exit: 195\n",
);

const PHASE9E_CANONICAL_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_block_param_quad_materialize_return\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quad_materialize_return\n",
    "parameter_count: 1\n",
    "parameter_0_type: int\n",
    "return_type: int\n",
    "local_count: 0\n",
    "entry_block: entry\n",
    "block_count: 4\n",
    "block_0_label: entry\n",
    "block_0_parameter_count: 0\n",
    "block_0_statement_count: 0\n",
    "block_0_terminator_kind: Jump\n",
    "block_0_terminator_target: adjust\n",
    "block_0_terminator_argument_count: 1\n",
    "block_0_terminator_argument_0_kind: FunctionParamI32\n",
    "block_0_terminator_argument_0_param: 0\n",
    "block_1_label: adjust\n",
    "block_1_parameter_count: 1\n",
    "block_1_parameter_0_name: input_value\n",
    "block_1_parameter_0_type: int\n",
    "block_1_statement_count: 0\n",
    "block_1_terminator_kind: Jump\n",
    "block_1_terminator_target: branch\n",
    "block_1_terminator_argument_count: 4\n",
    "block_1_terminator_argument_0_kind: I32Literal\n",
    "block_1_terminator_argument_0_value: -100\n",
    "block_1_terminator_argument_1_kind: I32Literal\n",
    "block_1_terminator_argument_1_value: -101\n",
    "block_1_terminator_argument_2_kind: I32Literal\n",
    "block_1_terminator_argument_2_value: -102\n",
    "block_1_terminator_argument_3_kind: BlockParamI32AddI32Literal\n",
    "block_1_terminator_argument_3_block_param: input_value\n",
    "block_1_terminator_argument_3_value: -2\n",
    "block_2_label: branch\n",
    "block_2_parameter_count: 4\n",
    "block_2_parameter_0_name: carry_0\n",
    "block_2_parameter_0_type: int\n",
    "block_2_parameter_1_name: carry_1\n",
    "block_2_parameter_1_type: int\n",
    "block_2_parameter_2_name: carry_2\n",
    "block_2_parameter_2_type: int\n",
    "block_2_parameter_3_name: condition\n",
    "block_2_parameter_3_type: int\n",
    "block_2_statement_count: 0\n",
    "block_2_terminator_kind: BranchBlockParamI32Positive\n",
    "block_2_terminator_block_param: condition\n",
    "block_2_terminator_then: result\n",
    "block_2_terminator_then_argument_count: 4\n",
    "block_2_terminator_then_argument_0_kind: I32Literal\n",
    "block_2_terminator_then_argument_0_value: 100\n",
    "block_2_terminator_then_argument_1_kind: I32Literal\n",
    "block_2_terminator_then_argument_1_value: 101\n",
    "block_2_terminator_then_argument_2_kind: I32Literal\n",
    "block_2_terminator_then_argument_2_value: 102\n",
    "block_2_terminator_then_argument_3_kind: I32Literal\n",
    "block_2_terminator_then_argument_3_value: 830\n",
    "block_2_terminator_else: result\n",
    "block_2_terminator_else_argument_count: 4\n",
    "block_2_terminator_else_argument_0_kind: I32Literal\n",
    "block_2_terminator_else_argument_0_value: -200\n",
    "block_2_terminator_else_argument_1_kind: I32Literal\n",
    "block_2_terminator_else_argument_1_value: -201\n",
    "block_2_terminator_else_argument_2_kind: I32Literal\n",
    "block_2_terminator_else_argument_2_value: -202\n",
    "block_2_terminator_else_argument_3_kind: I32Literal\n",
    "block_2_terminator_else_argument_3_value: 872\n",
    "block_3_label: result\n",
    "block_3_parameter_count: 4\n",
    "block_3_parameter_0_name: result_carry_0\n",
    "block_3_parameter_0_type: int\n",
    "block_3_parameter_1_name: result_carry_1\n",
    "block_3_parameter_1_type: int\n",
    "block_3_parameter_2_name: result_carry_2\n",
    "block_3_parameter_2_type: int\n",
    "block_3_parameter_3_name: result\n",
    "block_3_parameter_3_type: int\n",
    "block_3_statement_count: 0\n",
    "block_3_terminator_kind: ReturnBlockParamI32\n",
    "block_3_terminator_block_param: result\n",
    "metadata_count: 0\n",
    "expected_exit: 62\n",
);

const PHASE9E_CANONICAL_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_block_param_quint_materialize_return\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_quint_materialize_return\n",
    "parameter_count: 1\n",
    "parameter_0_type: int\n",
    "return_type: int\n",
    "local_count: 0\n",
    "entry_block: entry\n",
    "block_count: 4\n",
    "block_0_label: entry\n",
    "block_0_parameter_count: 0\n",
    "block_0_statement_count: 0\n",
    "block_0_terminator_kind: Jump\n",
    "block_0_terminator_target: adjust\n",
    "block_0_terminator_argument_count: 1\n",
    "block_0_terminator_argument_0_kind: FunctionParamI32\n",
    "block_0_terminator_argument_0_param: 0\n",
    "block_1_label: adjust\n",
    "block_1_parameter_count: 1\n",
    "block_1_parameter_0_name: input_value\n",
    "block_1_parameter_0_type: int\n",
    "block_1_statement_count: 0\n",
    "block_1_terminator_kind: Jump\n",
    "block_1_terminator_target: branch\n",
    "block_1_terminator_argument_count: 5\n",
    "block_1_terminator_argument_0_kind: I32Literal\n",
    "block_1_terminator_argument_0_value: -100\n",
    "block_1_terminator_argument_1_kind: I32Literal\n",
    "block_1_terminator_argument_1_value: -101\n",
    "block_1_terminator_argument_2_kind: I32Literal\n",
    "block_1_terminator_argument_2_value: -102\n",
    "block_1_terminator_argument_3_kind: I32Literal\n",
    "block_1_terminator_argument_3_value: -103\n",
    "block_1_terminator_argument_4_kind: BlockParamI32AddI32Literal\n",
    "block_1_terminator_argument_4_block_param: input_value\n",
    "block_1_terminator_argument_4_value: -3\n",
    "block_2_label: branch\n",
    "block_2_parameter_count: 5\n",
    "block_2_parameter_0_name: carry_0\n",
    "block_2_parameter_0_type: int\n",
    "block_2_parameter_1_name: carry_1\n",
    "block_2_parameter_1_type: int\n",
    "block_2_parameter_2_name: carry_2\n",
    "block_2_parameter_2_type: int\n",
    "block_2_parameter_3_name: carry_3\n",
    "block_2_parameter_3_type: int\n",
    "block_2_parameter_4_name: condition\n",
    "block_2_parameter_4_type: int\n",
    "block_2_statement_count: 0\n",
    "block_2_terminator_kind: BranchBlockParamI32Positive\n",
    "block_2_terminator_block_param: condition\n",
    "block_2_terminator_then: result\n",
    "block_2_terminator_then_argument_count: 5\n",
    "block_2_terminator_then_argument_0_kind: I32Literal\n",
    "block_2_terminator_then_argument_0_value: 100\n",
    "block_2_terminator_then_argument_1_kind: I32Literal\n",
    "block_2_terminator_then_argument_1_value: 101\n",
    "block_2_terminator_then_argument_2_kind: I32Literal\n",
    "block_2_terminator_then_argument_2_value: 102\n",
    "block_2_terminator_then_argument_3_kind: I32Literal\n",
    "block_2_terminator_then_argument_3_value: 103\n",
    "block_2_terminator_then_argument_4_kind: I32Literal\n",
    "block_2_terminator_then_argument_4_value: 927\n",
    "block_2_terminator_else: result\n",
    "block_2_terminator_else_argument_count: 5\n",
    "block_2_terminator_else_argument_0_kind: I32Literal\n",
    "block_2_terminator_else_argument_0_value: -200\n",
    "block_2_terminator_else_argument_1_kind: I32Literal\n",
    "block_2_terminator_else_argument_1_value: -201\n",
    "block_2_terminator_else_argument_2_kind: I32Literal\n",
    "block_2_terminator_else_argument_2_value: -202\n",
    "block_2_terminator_else_argument_3_kind: I32Literal\n",
    "block_2_terminator_else_argument_3_value: -203\n",
    "block_2_terminator_else_argument_4_kind: I32Literal\n",
    "block_2_terminator_else_argument_4_value: 975\n",
    "block_3_label: result\n",
    "block_3_parameter_count: 5\n",
    "block_3_parameter_0_name: result_carry_0\n",
    "block_3_parameter_0_type: int\n",
    "block_3_parameter_1_name: result_carry_1\n",
    "block_3_parameter_1_type: int\n",
    "block_3_parameter_2_name: result_carry_2\n",
    "block_3_parameter_2_type: int\n",
    "block_3_parameter_3_name: result_carry_3\n",
    "block_3_parameter_3_type: int\n",
    "block_3_parameter_4_name: result\n",
    "block_3_parameter_4_type: int\n",
    "block_3_statement_count: 0\n",
    "block_3_terminator_kind: ReturnBlockParamI32\n",
    "block_3_terminator_block_param: result\n",
    "metadata_count: 0\n",
    "expected_exit: 159\n",
);

const PHASE9E_CANONICAL_BLOCK_PARAM_LOCAL_MATERIALIZE_RETURN_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_block_param_local_materialize_return\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_return\n",
    "parameter_count: 1\n",
    "parameter_0_type: int\n",
    "return_type: int\n",
    "local_count: 1\n",
    "local_0_name: materialized\n",
    "local_0_type: int\n",
    "entry_block: entry\n",
    "block_count: 3\n",
    "block_0_label: entry\n",
    "block_0_parameter_count: 0\n",
    "block_0_statement_count: 0\n",
    "block_0_terminator_kind: Jump\n",
    "block_0_terminator_target: materialize\n",
    "block_0_terminator_argument_count: 1\n",
    "block_0_terminator_argument_0_kind: FunctionParamI32\n",
    "block_0_terminator_argument_0_param: 0\n",
    "block_1_label: materialize\n",
    "block_1_parameter_count: 1\n",
    "block_1_parameter_0_name: input_value\n",
    "block_1_parameter_0_type: int\n",
    "block_1_statement_count: 2\n",
    "block_1_statement_0_kind: LocalI32SetBlockParam\n",
    "block_1_statement_0_local: materialized\n",
    "block_1_statement_0_block_param: input_value\n",
    "block_1_statement_1_kind: LocalI32AddI32Literal\n",
    "block_1_statement_1_local: materialized\n",
    "block_1_statement_1_value: 2\n",
    "block_1_terminator_kind: BranchLocalI32Positive\n",
    "block_1_terminator_local: materialized\n",
    "block_1_terminator_then: result\n",
    "block_1_terminator_then_argument_count: 1\n",
    "block_1_terminator_then_argument_0_kind: I32Literal\n",
    "block_1_terminator_then_argument_0_value: 401\n",
    "block_1_terminator_else: result\n",
    "block_1_terminator_else_argument_count: 1\n",
    "block_1_terminator_else_argument_0_kind: I32Literal\n",
    "block_1_terminator_else_argument_0_value: 421\n",
    "block_2_label: result\n",
    "block_2_parameter_count: 1\n",
    "block_2_parameter_0_name: selected\n",
    "block_2_parameter_0_type: int\n",
    "block_2_statement_count: 2\n",
    "block_2_statement_0_kind: LocalI32SetBlockParam\n",
    "block_2_statement_0_local: materialized\n",
    "block_2_statement_0_block_param: selected\n",
    "block_2_statement_1_kind: LocalI32AddI32Literal\n",
    "block_2_statement_1_local: materialized\n",
    "block_2_statement_1_value: 2\n",
    "block_2_terminator_kind: ReturnLocalI32\n",
    "block_2_terminator_local: materialized\n",
    "metadata_count: 0\n",
    "expected_exit: 147\n",
);

const PHASE9E_CANONICAL_BLOCK_PARAM_LOCAL_MATERIALIZE_BRANCH_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_block_param_local_materialize_branch\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_materialize_branch\n",
    "parameter_count: 1\n",
    "parameter_0_type: int\n",
    "return_type: int\n",
    "local_count: 1\n",
    "local_0_name: materialized\n",
    "local_0_type: int\n",
    "entry_block: entry\n",
    "block_count: 3\n",
    "block_0_label: entry\n",
    "block_0_parameter_count: 0\n",
    "block_0_statement_count: 0\n",
    "block_0_terminator_kind: Jump\n",
    "block_0_terminator_target: materialize\n",
    "block_0_terminator_argument_count: 1\n",
    "block_0_terminator_argument_0_kind: FunctionParamI32\n",
    "block_0_terminator_argument_0_param: 0\n",
    "block_1_label: materialize\n",
    "block_1_parameter_count: 1\n",
    "block_1_parameter_0_name: input_value\n",
    "block_1_parameter_0_type: int\n",
    "block_1_statement_count: 2\n",
    "block_1_statement_0_kind: LocalI32SetBlockParam\n",
    "block_1_statement_0_local: materialized\n",
    "block_1_statement_0_block_param: input_value\n",
    "block_1_statement_1_kind: LocalI32AddI32Literal\n",
    "block_1_statement_1_local: materialized\n",
    "block_1_statement_1_value: 1\n",
    "block_1_terminator_kind: BranchLocalI32Positive\n",
    "block_1_terminator_local: materialized\n",
    "block_1_terminator_then: result\n",
    "block_1_terminator_then_argument_count: 1\n",
    "block_1_terminator_then_argument_0_kind: I32Literal\n",
    "block_1_terminator_then_argument_0_value: 293\n",
    "block_1_terminator_else: result\n",
    "block_1_terminator_else_argument_count: 1\n",
    "block_1_terminator_else_argument_0_kind: I32Literal\n",
    "block_1_terminator_else_argument_0_value: 307\n",
    "block_2_label: result\n",
    "block_2_parameter_count: 1\n",
    "block_2_parameter_0_name: selected\n",
    "block_2_parameter_0_type: int\n",
    "block_2_statement_count: 0\n",
    "block_2_terminator_kind: ReturnBlockParamI32\n",
    "block_2_terminator_block_param: selected\n",
    "metadata_count: 0\n",
    "expected_exit: 37\n",
);

const PHASE9E_CANONICAL_BLOCK_PARAM_LOCAL_FIRST_DUAL_MATERIALIZE_RETURN_FIXTURE: &str = concat!(
    "format: gust.compiler_mir_ingestion.v1\n",
    "function: tiny_block_param_local_first_dual_materialize_return\n",
    "backend_symbol: tiny_native_backend_compiler_mir_ingested_block_param_local_first_dual_materialize_return\n",
    "parameter_count: 1\n",
    "parameter_0_type: int\n",
    "return_type: int\n",
    "local_count: 1\n",
    "local_0_name: materialized\n",
    "local_0_type: int\n",
    "entry_block: entry\n",
    "block_count: 3\n",
    "block_0_label: entry\n",
    "block_0_parameter_count: 0\n",
    "block_0_statement_count: 0\n",
    "block_0_terminator_kind: Jump\n",
    "block_0_terminator_target: materialize\n",
    "block_0_terminator_argument_count: 1\n",
    "block_0_terminator_argument_0_kind: FunctionParamI32\n",
    "block_0_terminator_argument_0_param: 0\n",
    "block_1_label: materialize\n",
    "block_1_parameter_count: 1\n",
    "block_1_parameter_0_name: input_value\n",
    "block_1_parameter_0_type: int\n",
    "block_1_statement_count: 3\n",
    "block_1_statement_0_kind: LocalI32SetBlockParam\n",
    "block_1_statement_0_local: materialized\n",
    "block_1_statement_0_block_param: input_value\n",
    "block_1_statement_1_kind: LocalI32AddI32Literal\n",
    "block_1_statement_1_local: materialized\n",
    "block_1_statement_1_value: 4\n",
    "block_1_statement_2_kind: LocalI32AddI32Literal\n",
    "block_1_statement_2_local: materialized\n",
    "block_1_statement_2_value: -7\n",
    "block_1_terminator_kind: BranchLocalI32Positive\n",
    "block_1_terminator_local: materialized\n",
    "block_1_terminator_then: result\n",
    "block_1_terminator_then_argument_count: 1\n",
    "block_1_terminator_then_argument_0_kind: I32Literal\n",
    "block_1_terminator_then_argument_0_value: 601\n",
    "block_1_terminator_else: result\n",
    "block_1_terminator_else_argument_count: 1\n",
    "block_1_terminator_else_argument_0_kind: I32Literal\n",
    "block_1_terminator_else_argument_0_value: 631\n",
    "block_2_label: result\n",
    "block_2_parameter_count: 1\n",
    "block_2_parameter_0_name: selected\n",
    "block_2_parameter_0_type: int\n",
    "block_2_statement_count: 2\n",
    "block_2_statement_0_kind: LocalI32SetBlockParam\n",
    "block_2_statement_0_local: materialized\n",
    "block_2_statement_0_block_param: selected\n",
    "block_2_statement_1_kind: LocalI32AddI32Literal\n",
    "block_2_statement_1_local: materialized\n",
    "block_2_statement_1_value: 4\n",
    "block_2_terminator_kind: ReturnLocalI32\n",
    "block_2_terminator_local: materialized\n",
    "metadata_count: 0\n",
    "expected_exit: 93\n",
);

#[derive(Clone, Copy)]
enum CompilerMirLoweringCallTarget<'a> {
    LocalFunction(&'a str),
    ImportedFunction(&'a str),
}

#[derive(Clone, Copy)]
enum CompilerMirLoweringCallArgument<'a> {
    I32Literal(i32),
    BoolLiteral(i32),
    FunctionParamI32(usize),
    LocalI32(&'a str),
    BlockParamI32(&'a str),
    BlockParamI32AddI32Literal {
        name: &'a str,
        value: i32,
    },
}

#[derive(Clone)]
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
    LocalI32SetCall {
        name: &'a str,
        target: CompilerMirLoweringCallTarget<'a>,
        arguments: Vec<CompilerMirLoweringCallArgument<'a>>,
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

#[derive(Clone, Copy, PartialEq, Eq)]
enum CompilerMirLoweringFunctionLinkage {
    ExportedEntry,
    ModuleLocal,
    ImportedHost,
    BundleExport,
    ImportedBundle,
}

struct CompilerMirLoweringImportedFunction<'a> {
    name: &'a str,
    link_symbol: &'a str,
    linkage: CompilerMirLoweringFunctionLinkage,
    params: Vec<TinyMirType>,
    return_type: TinyMirType,
}

struct CompilerMirLoweringDefinedFunction<'a> {
    linkage: CompilerMirLoweringFunctionLinkage,
    fixture: ParsedCompilerMirFixture<'a>,
}

struct CompilerMirLoweringModule<'a> {
    name: &'a str,
    imports: Vec<CompilerMirLoweringImportedFunction<'a>>,
    functions: Vec<CompilerMirLoweringDefinedFunction<'a>>,
}

enum ParsedCompilerMirInput<'a> {
    V1(ParsedCompilerMirFixture<'a>),
    V2(CompilerMirLoweringModule<'a>),
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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum CompilerMirPipelineStage {
    FixtureParse,
    FixtureValidation,
    MirLowering,
    ObjectBuild,
    ObjectVerification,
    ObjectPublication,
    LinkInputValidation,
    LinkerSpawn,
    NativeLink,
    ExecutablePublication,
    NativeExecution,
}

impl CompilerMirPipelineStage {
    fn as_str(self) -> &'static str {
        match self {
            Self::FixtureParse => "fixture_parse",
            Self::FixtureValidation => "fixture_validation",
            Self::MirLowering => "mir_lowering",
            Self::ObjectBuild => "object_build",
            Self::ObjectVerification => "object_verification",
            Self::ObjectPublication => "object_publication",
            Self::LinkInputValidation => "link_input_validation",
            Self::LinkerSpawn => "linker_spawn",
            Self::NativeLink => "native_link",
            Self::ExecutablePublication => "executable_publication",
            Self::NativeExecution => "native_execution",
        }
    }
}

const COMPILER_MIR_PIPELINE_STAGES: [CompilerMirPipelineStage; 11] = [
    CompilerMirPipelineStage::FixtureParse,
    CompilerMirPipelineStage::FixtureValidation,
    CompilerMirPipelineStage::MirLowering,
    CompilerMirPipelineStage::ObjectBuild,
    CompilerMirPipelineStage::ObjectVerification,
    CompilerMirPipelineStage::ObjectPublication,
    CompilerMirPipelineStage::LinkInputValidation,
    CompilerMirPipelineStage::LinkerSpawn,
    CompilerMirPipelineStage::NativeLink,
    CompilerMirPipelineStage::ExecutablePublication,
    CompilerMirPipelineStage::NativeExecution,
];

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum CompilerMirPipelineFailureKind {
    InvalidFixture,
    InvalidRequest,
    LoweringFailed,
    ObjectBuildFailed,
    UnresolvedSymbol,
    DuplicateSymbol,
    InvalidObject,
    MissingInput,
    UnsupportedTarget,
    LinkerUnavailable,
    LinkerRejectedOptions,
    OutputNotWritable,
    UnknownNativeLinkFailure,
    NativeExecutionFailed,
}

impl CompilerMirPipelineFailureKind {
    fn as_str(self) -> &'static str {
        match self {
            Self::InvalidFixture => "invalid_fixture",
            Self::InvalidRequest => "invalid_request",
            Self::LoweringFailed => "lowering_failed",
            Self::ObjectBuildFailed => "object_build_failed",
            Self::UnresolvedSymbol => "unresolved_symbol",
            Self::DuplicateSymbol => "duplicate_symbol",
            Self::InvalidObject => "invalid_object",
            Self::MissingInput => "missing_input",
            Self::UnsupportedTarget => "unsupported_target",
            Self::LinkerUnavailable => "linker_unavailable",
            Self::LinkerRejectedOptions => "linker_rejected_options",
            Self::OutputNotWritable => "output_not_writable",
            Self::UnknownNativeLinkFailure => "unknown_native_link_failure",
            Self::NativeExecutionFailed => "native_execution_failed",
        }
    }

    fn parse_link_failure_kind(value: &str) -> Result<Self, Box<dyn Error>> {
        match value {
            "unresolved_symbol" => Ok(Self::UnresolvedSymbol),
            "duplicate_symbol" => Ok(Self::DuplicateSymbol),
            "invalid_object" => Ok(Self::InvalidObject),
            "missing_input" => Ok(Self::MissingInput),
            "unsupported_target" => Ok(Self::UnsupportedTarget),
            "linker_unavailable" => Ok(Self::LinkerUnavailable),
            "linker_rejected_options" => Ok(Self::LinkerRejectedOptions),
            "output_not_writable" => Ok(Self::OutputNotWritable),
            "unknown_native_link_failure" => Ok(Self::UnknownNativeLinkFailure),
            other => Err(IoError::new(
                ErrorKind::InvalidData,
                format!(
                    "compiler MIR link request expected_failure_kind is not a stable link failure kind: {other}"
                ),
            )
            .into()),
        }
    }
}

const COMPILER_MIR_LINK_FAILURE_KINDS: [CompilerMirPipelineFailureKind; 9] = [
    CompilerMirPipelineFailureKind::UnresolvedSymbol,
    CompilerMirPipelineFailureKind::DuplicateSymbol,
    CompilerMirPipelineFailureKind::InvalidObject,
    CompilerMirPipelineFailureKind::MissingInput,
    CompilerMirPipelineFailureKind::UnsupportedTarget,
    CompilerMirPipelineFailureKind::LinkerUnavailable,
    CompilerMirPipelineFailureKind::LinkerRejectedOptions,
    CompilerMirPipelineFailureKind::OutputNotWritable,
    CompilerMirPipelineFailureKind::UnknownNativeLinkFailure,
];

#[derive(Debug)]
struct CompilerMirPipelineError {
    stage: CompilerMirPipelineStage,
    kind: CompilerMirPipelineFailureKind,
    detail: String,
}

impl CompilerMirPipelineError {
    fn new(
        stage: CompilerMirPipelineStage,
        kind: CompilerMirPipelineFailureKind,
        detail: impl Into<String>,
    ) -> Self {
        Self {
            stage,
            kind,
            detail: detail.into(),
        }
    }

    fn machine_line(&self) -> String {
        compiler_mir_pipeline_machine_line(self.stage, self.kind)
    }
}

impl fmt::Display for CompilerMirPipelineError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(&self.detail)
    }
}

impl Error for CompilerMirPipelineError {}

fn compiler_mir_pipeline_machine_line(
    stage: CompilerMirPipelineStage,
    kind: CompilerMirPipelineFailureKind,
) -> String {
    format!(
        "gust_pipeline_failure: stage={} kind={}",
        stage.as_str(),
        kind.as_str()
    )
}

fn compiler_mir_pipeline_error(
    stage: CompilerMirPipelineStage,
    kind: CompilerMirPipelineFailureKind,
    detail: impl Into<String>,
) -> Box<dyn Error> {
    Box::new(CompilerMirPipelineError::new(stage, kind, detail))
}

fn compiler_mir_pipeline_wrap<T, E>(
    result: Result<T, E>,
    stage: CompilerMirPipelineStage,
    kind: CompilerMirPipelineFailureKind,
) -> Result<T, Box<dyn Error>>
where
    E: fmt::Display,
{
    result.map_err(|error| compiler_mir_pipeline_error(stage, kind, error.to_string()))
}

fn compiler_mir_pipeline_wrap_box<T>(
    result: Result<T, Box<dyn Error>>,
    stage: CompilerMirPipelineStage,
    kind: CompilerMirPipelineFailureKind,
) -> Result<T, Box<dyn Error>> {
    result.map_err(
        |error| match error.downcast::<CompilerMirPipelineError>() {
            Ok(pipeline_error) => {
                let pipeline_error: Box<dyn Error> = pipeline_error;
                pipeline_error
            }
            Err(error) => {
                compiler_mir_pipeline_error(stage, kind, error.to_string())
            }
        },
    )
}


const PHASE10_BACKEND_REQUEST_FORMAT: &str = "gust.native_backend.request.v1";
const PHASE10_BACKEND_REQUEST_ARTIFACT_KIND: &str = "native_executable";
const PHASE10_BACKEND_REQUEST_FAILURE_TAXONOMY: &str =
    "gust.native_backend.request.failure.v1";

#[derive(Debug, Clone, Copy)]
enum Phase10BackendRequestStage {
    RequestParse,
    RequestValidation,
    TargetValidation,
    ProgramMirBundleValidation,
    CanonicalMirValidation,
}

impl Phase10BackendRequestStage {
    fn as_str(self) -> &'static str {
        match self {
            Self::RequestParse => "request_parse",
            Self::RequestValidation => "request_validation",
            Self::TargetValidation => "target_validation",
            Self::ProgramMirBundleValidation => "program_mir_bundle_validation",
            Self::CanonicalMirValidation => "canonical_mir_validation",
        }
    }
}

#[derive(Debug, Clone, Copy)]
enum Phase10BackendRequestFailureKind {
    InvalidRequest,
    ProtocolMismatch,
    UnsupportedArtifact,
    TargetMismatch,
    InvalidBundle,
    InvalidCanonicalMir,
}

impl Phase10BackendRequestFailureKind {
    fn as_str(self) -> &'static str {
        match self {
            Self::InvalidRequest => "invalid_request",
            Self::ProtocolMismatch => "protocol_mismatch",
            Self::UnsupportedArtifact => "unsupported_artifact",
            Self::TargetMismatch => "target_mismatch",
            Self::InvalidBundle => "invalid_bundle",
            Self::InvalidCanonicalMir => "invalid_canonical_mir",
        }
    }
}

#[derive(Debug)]
struct Phase10BackendRequestError {
    stage: Phase10BackendRequestStage,
    kind: Phase10BackendRequestFailureKind,
    detail: String,
}

impl Phase10BackendRequestError {
    fn machine_line(&self) -> String {
        format!(
            "gust_backend_request_failure: taxonomy={} stage={} kind={}",
            PHASE10_BACKEND_REQUEST_FAILURE_TAXONOMY,
            self.stage.as_str(),
            self.kind.as_str(),
        )
    }
}

impl fmt::Display for Phase10BackendRequestError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(&self.detail)
    }
}

impl Error for Phase10BackendRequestError {}

fn phase10_backend_request_error(
    stage: Phase10BackendRequestStage,
    kind: Phase10BackendRequestFailureKind,
    detail: impl Into<String>,
) -> Box<dyn Error> {
    Box::new(Phase10BackendRequestError {
        stage,
        kind,
        detail: detail.into(),
    })
}

const PHASE11_BACKEND_DIAGNOSTIC_TAXONOMY: &str =
    "gust.backend_parity.diagnostic.v1";

const PHASE11_BACKEND_DIAGNOSTIC_CLASSES: [&str; 6] = [
    "source_type_error",
    "canonical_mir_verification_error",
    "unsupported_native_capability",
    "driver_handshake_error",
    "worker_lowering_error",
    "object_link_publication_error",
];

fn phase11_request_diagnostic_class(
    error: &Phase10BackendRequestError,
) -> &'static str {
    match error.stage {
        Phase10BackendRequestStage::ProgramMirBundleValidation
        | Phase10BackendRequestStage::CanonicalMirValidation => {
            "canonical_mir_verification_error"
        }
        Phase10BackendRequestStage::RequestParse
        | Phase10BackendRequestStage::RequestValidation
        | Phase10BackendRequestStage::TargetValidation => {
            "driver_handshake_error"
        }
    }
}

fn phase11_pipeline_diagnostic_class(
    error: &CompilerMirPipelineError,
) -> &'static str {
    match error.stage {
        CompilerMirPipelineStage::FixtureParse
        | CompilerMirPipelineStage::FixtureValidation => {
            "canonical_mir_verification_error"
        }
        CompilerMirPipelineStage::MirLowering => "worker_lowering_error",
        CompilerMirPipelineStage::ObjectBuild
        | CompilerMirPipelineStage::ObjectVerification
        | CompilerMirPipelineStage::ObjectPublication
        | CompilerMirPipelineStage::LinkInputValidation
        | CompilerMirPipelineStage::LinkerSpawn
        | CompilerMirPipelineStage::NativeLink
        | CompilerMirPipelineStage::ExecutablePublication
        | CompilerMirPipelineStage::NativeExecution => {
            "object_link_publication_error"
        }
    }
}

fn phase11_diagnostic_machine_line(class_name: &str) -> String {
    format!(
        "gust_backend_parity_diagnostic: taxonomy={} class={class_name}",
        PHASE11_BACKEND_DIAGNOSTIC_TAXONOMY
    )
}

struct Phase10TextCursor<'a> {
    remaining: &'a str,
    line_number: usize,
}

impl<'a> Phase10TextCursor<'a> {
    fn new(contents: &'a str) -> Self {
        Self {
            remaining: contents,
            line_number: 1,
        }
    }

    fn take_line(
        &mut self,
        stage: Phase10BackendRequestStage,
        kind: Phase10BackendRequestFailureKind,
    ) -> Result<&'a str, Box<dyn Error>> {
        let Some(newline_index) = self.remaining.find('\n') else {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!(
                    "line {} must be newline terminated",
                    self.line_number
                ),
            ));
        };
        let line = &self.remaining[..newline_index];
        self.remaining = &self.remaining[newline_index + 1..];
        self.line_number += 1;
        if line.contains('\r') {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!(
                    "line {} contains a carriage return",
                    self.line_number - 1
                ),
            ));
        }
        Ok(line)
    }

    fn take_expected_line(
        &mut self,
        expected: &str,
        stage: Phase10BackendRequestStage,
        kind: Phase10BackendRequestFailureKind,
    ) -> Result<(), Box<dyn Error>> {
        let line = self.take_line(stage, kind)?;
        if line != expected {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!(
                    "line {} expected {expected}, got {line}",
                    self.line_number - 1
                ),
            ));
        }
        Ok(())
    }

    fn take_field(
        &mut self,
        field: &str,
        allow_empty: bool,
        stage: Phase10BackendRequestStage,
        kind: Phase10BackendRequestFailureKind,
    ) -> Result<&'a str, Box<dyn Error>> {
        let line = self.take_line(stage, kind)?;
        let prefix = format!("{field}: ");
        let Some(value) = line.strip_prefix(&prefix) else {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!(
                    "line {} expected field {field}",
                    self.line_number - 1
                ),
            ));
        };
        if !allow_empty && value.is_empty() {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!("field {field} must not be empty"),
            ));
        }
        Ok(value)
    }

    fn take_usize_field(
        &mut self,
        field: &str,
        stage: Phase10BackendRequestStage,
        kind: Phase10BackendRequestFailureKind,
    ) -> Result<usize, Box<dyn Error>> {
        let value = self.take_field(field, false, stage, kind)?;
        value.parse::<usize>().map_err(|_| {
            phase10_backend_request_error(
                stage,
                kind,
                format!("field {field} must be a nonnegative integer"),
            )
        })
    }

    fn take_exact_bytes(
        &mut self,
        byte_length: usize,
        stage: Phase10BackendRequestStage,
        kind: Phase10BackendRequestFailureKind,
    ) -> Result<&'a str, Box<dyn Error>> {
        let Some(value) = self.remaining.get(..byte_length) else {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!(
                    "declared byte length {byte_length} exceeds the remaining input"
                ),
            ));
        };
        self.remaining = &self.remaining[byte_length..];
        self.line_number += value.bytes().filter(|byte| *byte == b'\n').count();
        Ok(value)
    }

    fn finish(
        self,
        stage: Phase10BackendRequestStage,
        kind: Phase10BackendRequestFailureKind,
    ) -> Result<(), Box<dyn Error>> {
        if !self.remaining.is_empty() {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                "unexpected trailing request or bundle content",
            ));
        }
        Ok(())
    }
}

#[derive(Debug)]
struct Phase10BackendRequest {
    target_triple: String,
    object_format: String,
    output_path: PathBuf,
    program_mir_bundle_path: PathBuf,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct Phase11PreservedMetadata {
    kind: String,
    attachment: String,
    policy: String,
    payload: String,
}

#[derive(Debug)]
struct Phase10ProgramMirBundleModule {
    module_path: String,
    object_name: String,
    canonical_format: String,
    canonical_mir: String,
    metadata: Vec<Phase11PreservedMetadata>,
}

#[derive(Debug)]
struct Phase10ProgramMirBundle {
    entry_symbol: String,
    module_count: usize,
    modules: Vec<Phase10ProgramMirBundleModule>,
}

fn parse_phase10_backend_request(
    contents: &str,
) -> Result<Phase10BackendRequest, Box<dyn Error>> {
    let stage = Phase10BackendRequestStage::RequestParse;
    let kind = Phase10BackendRequestFailureKind::InvalidRequest;
    let mut cursor = Phase10TextCursor::new(contents);

    let format_name = cursor.take_field("format", false, stage, kind)?;
    if format_name != PHASE10_BACKEND_REQUEST_FORMAT {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::RequestValidation,
            Phase10BackendRequestFailureKind::ProtocolMismatch,
            format!(
                "backend request format expected {}, got {format_name}",
                PHASE10_BACKEND_REQUEST_FORMAT
            ),
        ));
    }

    let driver_protocol =
        cursor.take_field("driver_protocol", false, stage, kind)?;
    if driver_protocol != PHASE10_DRIVER_PROTOCOL {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::RequestValidation,
            Phase10BackendRequestFailureKind::ProtocolMismatch,
            format!(
                "backend request driver protocol expected {}, got {driver_protocol}",
                PHASE10_DRIVER_PROTOCOL
            ),
        ));
    }

    let artifact_kind =
        cursor.take_field("artifact_kind", false, stage, kind)?;
    if artifact_kind != PHASE10_BACKEND_REQUEST_ARTIFACT_KIND {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::RequestValidation,
            Phase10BackendRequestFailureKind::UnsupportedArtifact,
            format!(
                "backend request artifact kind expected {}, got {artifact_kind}",
                PHASE10_BACKEND_REQUEST_ARTIFACT_KIND
            ),
        ));
    }

    let target_triple = cursor
        .take_field("target_triple", false, stage, kind)?
        .to_string();
    let object_format = cursor
        .take_field("object_format", false, stage, kind)?
        .to_string();
    let output_path = PathBuf::from(
        cursor.take_field("output_path", false, stage, kind)?,
    );
    let program_mir_bundle_path = PathBuf::from(
        cursor.take_field(
            "program_mir_bundle_path",
            false,
            stage,
            kind,
        )?,
    );
    cursor.finish(stage, kind)?;

    if !output_path.is_absolute() {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::RequestValidation,
            Phase10BackendRequestFailureKind::InvalidRequest,
            "backend request output_path must be absolute",
        ));
    }
    if !program_mir_bundle_path.is_absolute() {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::RequestValidation,
            Phase10BackendRequestFailureKind::InvalidRequest,
            "backend request program_mir_bundle_path must be absolute",
        ));
    }
    if output_path == program_mir_bundle_path {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::RequestValidation,
            Phase10BackendRequestFailureKind::InvalidRequest,
            "backend request output and bundle paths must differ",
        ));
    }

    Ok(Phase10BackendRequest {
        target_triple,
        object_format,
        output_path,
        program_mir_bundle_path,
    })
}

fn phase10_tiny_mir_type_name(ty: TinyMirType) -> &'static str {
    match ty {
        TinyMirType::I32 => "int",
        TinyMirType::Bool => "bool",
        TinyMirType::Void => "void",
    }
}

fn phase10_function_signature(
    params: &[TinyMirType],
    return_type: TinyMirType,
) -> String {
    let parameters = params
        .iter()
        .map(|ty| phase10_tiny_mir_type_name(*ty))
        .collect::<Vec<_>>()
        .join(",");
    format!(
        "({parameters})->{}",
        phase10_tiny_mir_type_name(return_type)
    )
}

fn phase10_linkage_name(
    linkage: CompilerMirLoweringFunctionLinkage,
) -> &'static str {
    match linkage {
        CompilerMirLoweringFunctionLinkage::ExportedEntry => "exported_entry",
        CompilerMirLoweringFunctionLinkage::ModuleLocal => "module_local",
        CompilerMirLoweringFunctionLinkage::ImportedHost => "imported_host",
        CompilerMirLoweringFunctionLinkage::BundleExport => "bundle_export",
        CompilerMirLoweringFunctionLinkage::ImportedBundle => "imported_bundle",
    }
}

fn phase10_metadata_counts(
    metadata: &[CompilerMirFixtureMetadata<'_>],
) -> (usize, usize, usize) {
    let mut resource = 0;
    let mut provenance = 0;
    let mut native_boundary = 0;
    for item in metadata {
        match item.kind {
            "resource" => resource += 1,
            "provenance" => provenance += 1,
            "native_boundary" => native_boundary += 1,
            _ => {}
        }
    }
    (resource, provenance, native_boundary)
}

fn phase11_preserve_metadata(
    metadata: &[CompilerMirFixtureMetadata<'_>],
) -> Vec<Phase11PreservedMetadata> {
    metadata
        .iter()
        .map(|item| Phase11PreservedMetadata {
            kind: item.kind.to_string(),
            attachment: item.attachment.to_string(),
            policy: item.policy.to_string(),
            payload: item.payload.to_string(),
        })
        .collect()
}

fn phase10_expected_block_parameters(
    function: &CompilerMirLoweringFunction<'_>,
) -> HashSet<(String, String, usize, String, String)> {
    let mut parameters = HashSet::new();
    for block in &function.blocks {
        for (ordinal, parameter) in block.parameters.iter().enumerate() {
            parameters.insert((
                function.symbol.to_string(),
                block.label.to_string(),
                ordinal,
                parameter.name.to_string(),
                phase10_tiny_mir_type_name(parameter.ty).to_string(),
            ));
        }
    }
    parameters
}

fn parse_phase10_program_mir_bundle(
    contents: &str,
) -> Result<Phase10ProgramMirBundle, Box<dyn Error>> {
    let stage = Phase10BackendRequestStage::ProgramMirBundleValidation;
    let kind = Phase10BackendRequestFailureKind::InvalidBundle;
    let mut cursor = Phase10TextCursor::new(contents);

    let format_name = cursor.take_field("format", false, stage, kind)?;
    if format_name != PHASE10_PROGRAM_MIR_BUNDLE_FORMAT {
        return Err(phase10_backend_request_error(
            stage,
            kind,
            format!(
                "program MIR bundle format expected {}, got {format_name}",
                PHASE10_PROGRAM_MIR_BUNDLE_FORMAT
            ),
        ));
    }

    let entry_symbol =
        cursor.take_field("entry_symbol", false, stage, kind)?.to_string();
    let module_count =
        cursor.take_usize_field("module_count", stage, kind)?;
    if module_count == 0 {
        return Err(phase10_backend_request_error(
            stage,
            kind,
            "program MIR bundle must contain at least one module",
        ));
    }

    let mut module_paths = HashSet::new();
    let mut object_names = HashSet::new();
    let mut global_symbol_signatures: HashMap<String, String> =
        HashMap::new();
    let mut global_defined_linkages: HashMap<String, String> =
        HashMap::new();
    let mut global_imported_bundle_links: HashSet<String> = HashSet::new();
    let mut global_imported_host_links: HashSet<String> = HashSet::new();
    let mut exported_entry_count = 0usize;
    let mut canonical_defined_symbols = HashSet::new();
    let mut modules = Vec::with_capacity(module_count);

    for module_index in 0..module_count {
        let module_key = format!("module_{module_index}");
        let module_path = cursor
            .take_field(
                &format!("{module_key}_path"),
                false,
                stage,
                kind,
            )?
            .to_string();
        let _module_prefix = cursor.take_field(
            &format!("{module_key}_prefix"),
            true,
            stage,
            kind,
        )?;
        let object_name = cursor
            .take_field(
                &format!("{module_key}_object_name"),
                false,
                stage,
                kind,
            )?
            .to_string();
        let canonical_format = cursor
            .take_field(
                &format!("{module_key}_canonical_format"),
                false,
                stage,
                kind,
            )?
            .to_string();
        let resource_metadata_count = cursor.take_usize_field(
            &format!("{module_key}_resource_metadata_count"),
            stage,
            kind,
        )?;
        let provenance_metadata_count = cursor.take_usize_field(
            &format!("{module_key}_provenance_metadata_count"),
            stage,
            kind,
        )?;
        let native_boundary_metadata_count = cursor.take_usize_field(
            &format!("{module_key}_native_boundary_metadata_count"),
            stage,
            kind,
        )?;

        if !module_paths.insert(module_path.clone()) {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!("duplicate module path: {module_path}"),
            ));
        }
        if !object_names.insert(object_name.clone()) {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!("duplicate module object name: {object_name}"),
            ));
        }
        if !PHASE10_CANONICAL_MIR_FORMATS.contains(
            &canonical_format.as_str(),
        ) {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!(
                    "unsupported canonical MIR format: {canonical_format}"
                ),
            ));
        }

        let symbol_count = cursor.take_usize_field(
            &format!("{module_key}_symbol_count"),
            stage,
            kind,
        )?;
        let defined_symbol_count = cursor.take_usize_field(
            &format!("{module_key}_defined_symbol_count"),
            stage,
            kind,
        )?;
        let undefined_symbol_count = cursor.take_usize_field(
            &format!("{module_key}_undefined_symbol_count"),
            stage,
            kind,
        )?;
        if defined_symbol_count + undefined_symbol_count != symbol_count {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!(
                    "{module_key} symbol totals do not match symbol_count"
                ),
            ));
        }

        let mut bundle_symbols:
            HashMap<String, (String, String)> = HashMap::new();
        let mut observed_defined = 0usize;
        let mut observed_undefined = 0usize;
        for symbol_index in 0..symbol_count {
            let symbol_key =
                format!("{module_key}_symbol_{symbol_index}");
            let _symbol_name = cursor.take_field(
                &format!("{symbol_key}_name"),
                false,
                stage,
                kind,
            )?;
            let link_name = cursor
                .take_field(
                    &format!("{symbol_key}_link_name"),
                    false,
                    stage,
                    kind,
                )?
                .to_string();
            let signature = cursor
                .take_field(
                    &format!("{symbol_key}_signature"),
                    false,
                    stage,
                    kind,
                )?
                .to_string();
            let linkage = cursor
                .take_field(
                    &format!("{symbol_key}_linkage"),
                    false,
                    stage,
                    kind,
                )?
                .to_string();

            match linkage.as_str() {
                "exported_entry" => {
                    observed_defined += 1;
                    exported_entry_count += 1;
                    if link_name != entry_symbol {
                        return Err(phase10_backend_request_error(
                            stage,
                            kind,
                            format!(
                                "exported entry {link_name} does not match bundle entry {entry_symbol}"
                            ),
                        ));
                    }
                }
                "module_local" | "bundle_export" => {
                    observed_defined += 1;
                }
                "imported_host" | "imported_bundle" => {
                    observed_undefined += 1;
                }
                _ => {
                    return Err(phase10_backend_request_error(
                        stage,
                        kind,
                        format!(
                            "unsupported symbol linkage: {linkage}"
                        ),
                    ));
                }
            }

            if let Some(previous_signature) =
                global_symbol_signatures.get(&link_name)
            {
                if previous_signature != &signature {
                    return Err(phase10_backend_request_error(
                        stage,
                        kind,
                        format!(
                            "whole-program symbol signature disagreement for {link_name}"
                        ),
                    ));
                }
            } else {
                global_symbol_signatures
                    .insert(link_name.clone(), signature.clone());
            }

            match linkage.as_str() {
                "exported_entry" | "module_local" | "bundle_export" => {
                    if global_defined_linkages
                        .insert(link_name.clone(), linkage.clone())
                        .is_some()
                    {
                        return Err(phase10_backend_request_error(
                            stage,
                            kind,
                            format!(
                                "duplicate whole-program defined symbol: {link_name}"
                            ),
                        ));
                    }
                }
                "imported_bundle" => {
                    global_imported_bundle_links.insert(link_name.clone());
                }
                "imported_host" => {
                    global_imported_host_links.insert(link_name.clone());
                }
                _ => unreachable!(),
            }

            if bundle_symbols
                .insert(link_name.clone(), (signature, linkage))
                .is_some()
            {
                return Err(phase10_backend_request_error(
                    stage,
                    kind,
                    format!(
                        "duplicate symbol link inside {module_key}: {link_name}"
                    ),
                ));
            }
        }
        if observed_defined != defined_symbol_count ||
            observed_undefined != undefined_symbol_count
        {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!(
                    "{module_key} observed linkage totals do not match declared totals"
                ),
            ));
        }

        let block_parameter_count = cursor.take_usize_field(
            &format!("{module_key}_block_parameter_count"),
            stage,
            kind,
        )?;
        let mut bundle_block_parameters = HashSet::new();
        for parameter_index in 0..block_parameter_count {
            let parameter_key =
                format!("{module_key}_block_parameter_{parameter_index}");
            let function_name = cursor
                .take_field(
                    &format!("{parameter_key}_function"),
                    false,
                    stage,
                    kind,
                )?
                .to_string();
            let block_label = cursor
                .take_field(
                    &format!("{parameter_key}_block"),
                    false,
                    stage,
                    kind,
                )?
                .to_string();
            let ordinal = cursor.take_usize_field(
                &format!("{parameter_key}_ordinal"),
                stage,
                kind,
            )?;
            let parameter_name = cursor
                .take_field(
                    &format!("{parameter_key}_name"),
                    false,
                    stage,
                    kind,
                )?
                .to_string();
            let parameter_type = cursor
                .take_field(
                    &format!("{parameter_key}_type"),
                    false,
                    stage,
                    kind,
                )?
                .to_string();
            if !bundle_block_parameters.insert((
                function_name,
                block_label,
                ordinal,
                parameter_name,
                parameter_type,
            )) {
                return Err(phase10_backend_request_error(
                    stage,
                    kind,
                    format!(
                        "duplicate block parameter in {module_key}"
                    ),
                ));
            }
        }

        let canonical_length = cursor.take_usize_field(
            &format!("{module_key}_canonical_mir_length"),
            stage,
            kind,
        )?;
        if canonical_length == 0 {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!("{module_key} canonical MIR must not be empty"),
            ));
        }
        cursor.take_expected_line(
            &format!("{module_key}_canonical_mir_begin"),
            stage,
            kind,
        )?;
        let canonical_mir = cursor.take_exact_bytes(
            canonical_length,
            stage,
            kind,
        )?;
        cursor.take_expected_line(
            &format!("{module_key}_canonical_mir_end"),
            stage,
            kind,
        )?;

        if !canonical_mir.ends_with('\n') {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!(
                    "{module_key} canonical MIR must end with a newline"
                ),
            ));
        }
        let expected_header = format!("format: {canonical_format}\n");
        if !canonical_mir.starts_with(&expected_header) {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!(
                    "{module_key} canonical format header does not match its index"
                ),
            ));
        }

        let parsed = parse_compiler_mir_input(canonical_mir).map_err(
            |error| {
                phase10_backend_request_error(
                    Phase10BackendRequestStage::CanonicalMirValidation,
                    Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                    format!(
                        "{module_key} canonical MIR parse failed: {error}"
                    ),
                )
            },
        )?;

        let mut expected_symbols:
            HashMap<String, (String, Option<String>)> = HashMap::new();
        let mut expected_block_parameters = HashSet::new();
        let mut expected_resource_metadata = 0usize;
        let mut expected_provenance_metadata = 0usize;
        let mut expected_native_boundary_metadata = 0usize;
        let mut expected_metadata = Vec::new();

        match parsed {
            ParsedCompilerMirInput::V1(fixture) => {
                if canonical_format != COMPILER_MIR_CANONICAL_FIXTURE_FORMAT {
                    return Err(phase10_backend_request_error(
                        stage,
                        kind,
                        format!(
                            "{module_key} indexed canonical format disagrees with parsed v1 input"
                        ),
                    ));
                }
                validate_compiler_mir_fixture(&fixture).map_err(|error| {
                    phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        format!(
                            "{module_key} canonical MIR validation failed: {error}"
                        ),
                    )
                })?;
                recognize_compiler_mir_fixture_metadata(
                    &fixture.metadata,
                )
                .map_err(|error| {
                    phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        format!(
                            "{module_key} canonical metadata validation failed: {error}"
                        ),
                    )
                })?;

                expected_symbols.insert(
                    fixture.function.symbol.to_string(),
                    (
                        phase10_function_signature(
                            &fixture.function.params,
                            fixture.function.return_type,
                        ),
                        None,
                    ),
                );
                canonical_defined_symbols
                    .insert(fixture.function.symbol.to_string());
                expected_block_parameters.extend(
                    phase10_expected_block_parameters(&fixture.function),
                );
                let counts = phase10_metadata_counts(&fixture.metadata);
                expected_resource_metadata += counts.0;
                expected_provenance_metadata += counts.1;
                expected_native_boundary_metadata += counts.2;
                expected_metadata.extend(
                    phase11_preserve_metadata(&fixture.metadata),
                );
            }
            ParsedCompilerMirInput::V2(module) => {
                if canonical_format != COMPILER_MIR_CANONICAL_MODULE_FORMAT {
                    return Err(phase10_backend_request_error(
                        stage,
                        kind,
                        format!(
                            "{module_key} indexed canonical format disagrees with parsed v2 input"
                        ),
                    ));
                }
                validate_compiler_mir_module(&module).map_err(|error| {
                    phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        format!(
                            "{module_key} canonical MIR validation failed: {error}"
                        ),
                    )
                })?;

                for defined in &module.functions {
                    recognize_compiler_mir_fixture_metadata(
                        &defined.fixture.metadata,
                    )
                    .map_err(|error| {
                        phase10_backend_request_error(
                            Phase10BackendRequestStage::CanonicalMirValidation,
                            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                            format!(
                                "{module_key} canonical metadata validation failed: {error}"
                            ),
                        )
                    })?;
                    expected_symbols.insert(
                        defined.fixture.function.symbol.to_string(),
                        (
                            phase10_function_signature(
                                &defined.fixture.function.params,
                                defined.fixture.function.return_type,
                            ),
                            Some(
                                phase10_linkage_name(defined.linkage)
                                    .to_string(),
                            ),
                        ),
                    );
                    canonical_defined_symbols.insert(
                        defined.fixture.function.symbol.to_string(),
                    );
                    expected_block_parameters.extend(
                        phase10_expected_block_parameters(
                            &defined.fixture.function,
                        ),
                    );
                    let counts =
                        phase10_metadata_counts(&defined.fixture.metadata);
                    expected_resource_metadata += counts.0;
                    expected_provenance_metadata += counts.1;
                    expected_native_boundary_metadata += counts.2;
                    expected_metadata.extend(
                        phase11_preserve_metadata(
                            &defined.fixture.metadata,
                        ),
                    );
                }

                for imported in &module.imports {
                    expected_symbols.insert(
                        imported.link_symbol.to_string(),
                        (
                            phase10_function_signature(
                                &imported.params,
                                imported.return_type,
                            ),
                            Some(
                                phase10_linkage_name(imported.linkage)
                                    .to_string(),
                            ),
                        ),
                    );
                }
            }
        }

        if expected_symbols.len() != bundle_symbols.len() {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!(
                    "{module_key} bundle symbol count does not match canonical MIR"
                ),
            ));
        }
        for (link_name, (expected_signature, expected_linkage)) in
            expected_symbols
        {
            let Some((actual_signature, actual_linkage)) =
                bundle_symbols.get(&link_name)
            else {
                return Err(phase10_backend_request_error(
                    stage,
                    kind,
                    format!(
                        "{module_key} is missing canonical symbol {link_name}"
                    ),
                ));
            };
            if actual_signature != &expected_signature {
                return Err(phase10_backend_request_error(
                    stage,
                    kind,
                    format!(
                        "{module_key} signature mismatch for {link_name}"
                    ),
                ));
            }
            if let Some(expected_linkage) = expected_linkage {
                if actual_linkage != &expected_linkage {
                    return Err(phase10_backend_request_error(
                        stage,
                        kind,
                        format!(
                            "{module_key} linkage mismatch for {link_name}"
                        ),
                    ));
                }
            } else if link_name == entry_symbol &&
                actual_linkage != "exported_entry"
            {
                return Err(phase10_backend_request_error(
                    stage,
                    kind,
                    format!(
                        "{module_key} v1 entry symbol must be exported"
                    ),
                ));
            }
        }

        if expected_block_parameters != bundle_block_parameters {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!(
                    "{module_key} block-parameter index does not match canonical MIR"
                ),
            ));
        }
        if resource_metadata_count != expected_resource_metadata ||
            provenance_metadata_count != expected_provenance_metadata ||
            native_boundary_metadata_count !=
                expected_native_boundary_metadata
        {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!(
                    "{module_key} metadata counts do not match canonical MIR"
                ),
            ));
        }
        if expected_metadata.len()
            != resource_metadata_count
                + provenance_metadata_count
                + native_boundary_metadata_count
        {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!(
                    "{module_key} retained metadata records do not match canonical metadata totals"
                ),
            ));
        }

        modules.push(Phase10ProgramMirBundleModule {
            module_path,
            object_name,
            canonical_format,
            canonical_mir: canonical_mir.to_string(),
            metadata: expected_metadata,
        });
    }

    cursor.finish(stage, kind)?;

    for link_name in &global_imported_bundle_links {
        match global_defined_linkages.get(link_name) {
            Some(linkage) if linkage == "bundle_export" => {}
            Some(linkage) => {
                return Err(phase10_backend_request_error(
                    stage,
                    kind,
                    format!(
                        "imported bundle symbol {link_name} resolves to forbidden linkage {linkage}"
                    ),
                ));
            }
            None => {
                return Err(phase10_backend_request_error(
                    stage,
                    kind,
                    format!(
                        "unresolved imported bundle symbol: {link_name}"
                    ),
                ));
            }
        }
    }
    for link_name in &global_imported_host_links {
        if global_defined_linkages.contains_key(link_name) {
            return Err(phase10_backend_request_error(
                stage,
                kind,
                format!(
                    "imported host symbol collides with a bundle definition: {link_name}"
                ),
            ));
        }
    }

    if exported_entry_count != 1 {
        return Err(phase10_backend_request_error(
            stage,
            kind,
            format!(
                "program MIR bundle must contain exactly one exported entry, found {exported_entry_count}"
            ),
        ));
    }
    if !canonical_defined_symbols.contains(&entry_symbol) {
        return Err(phase10_backend_request_error(
            stage,
            kind,
            format!(
                "program MIR bundle entry {entry_symbol} is absent from canonical defined symbols"
            ),
        ));
    }

    Ok(Phase10ProgramMirBundle {
        entry_symbol,
        module_count,
        modules,
    })
}

fn validate_phase10_backend_request_path(
    request_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let request_contents = fs::read_to_string(request_path).map_err(|error| {
        phase10_backend_request_error(
            Phase10BackendRequestStage::RequestParse,
            Phase10BackendRequestFailureKind::InvalidRequest,
            format!(
                "failed to read backend request {}: {error}",
                request_path.display()
            ),
        )
    })?;
    let request = parse_phase10_backend_request(&request_contents)?;

    let (_object_builder, target_contract) =
        build_compiler_mir_native_object_builder(
            "gust_phase10_backend_request_validation_probe",
        )
        .map_err(|error| {
            phase10_backend_request_error(
                Phase10BackendRequestStage::TargetValidation,
                Phase10BackendRequestFailureKind::TargetMismatch,
                format!(
                    "failed to resolve native target contract: {error}"
                ),
            )
        })?;

    if request.target_triple != target_contract.triple {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::TargetValidation,
            Phase10BackendRequestFailureKind::TargetMismatch,
            format!(
                "backend request target triple expected {}, got {}",
                target_contract.triple, request.target_triple
            ),
        ));
    }
    if request.object_format != target_contract.object_format {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::TargetValidation,
            Phase10BackendRequestFailureKind::TargetMismatch,
            format!(
                "backend request object format expected {}, got {}",
                target_contract.object_format, request.object_format
            ),
        ));
    }

    let bundle_contents =
        fs::read_to_string(&request.program_mir_bundle_path).map_err(
            |error| {
                phase10_backend_request_error(
                    Phase10BackendRequestStage::ProgramMirBundleValidation,
                    Phase10BackendRequestFailureKind::InvalidBundle,
                    format!(
                        "failed to read program MIR bundle {}: {error}",
                        request.program_mir_bundle_path.display()
                    ),
                )
            },
        )?;
    let bundle = parse_phase10_program_mir_bundle(&bundle_contents)?;

    println!("request_protocol: {PHASE10_BACKEND_REQUEST_FORMAT}");
    println!("request_status: validated");
    println!(
        "artifact_kind: {PHASE10_BACKEND_REQUEST_ARTIFACT_KIND}"
    );
    println!("entry_symbol: {}", bundle.entry_symbol);
    println!("module_count: {}", bundle.module_count);
    println!("target_triple: {}", request.target_triple);
    println!("object_format: {}", request.object_format);
    println!("output_path: {}", request.output_path.display());
    Ok(())
}

fn phase11_local_state_payload_field<'a>(
    payload: &'a str,
    key: &str,
) -> Option<&'a str> {
    payload.split(';').find_map(|field| {
        let (field_key, value) = field.split_once('=')?;
        (field_key == key).then_some(value)
    })
}

fn is_phase11_local_state_fixture(
    fixture: &ParsedCompilerMirFixture<'_>,
) -> bool {
    fixture.metadata.iter().any(|item| {
        item.payload.starts_with("kind=LocalDeclaration;") ||
            item.payload.starts_with("kind=LocalAssignment;")
    })
}

fn phase11_local_state_local_index(
    function: &CompilerMirLoweringFunction<'_>,
    name: &str,
) -> Result<usize, Box<dyn Error>> {
    function
        .locals
        .iter()
        .position(|local| local.name == name)
        .ok_or_else(|| {
            phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                format!(
                    "Phase 11 local-state canonical MIR references unknown local {name}"
                ),
            )
        })
}

fn phase11_local_state_apply_statements(
    function: &CompilerMirLoweringFunction<'_>,
    block: &CompilerMirLoweringBlock<'_>,
    assigned: &mut [bool],
) -> Result<(), Box<dyn Error>> {
    for statement in &block.statements {
        match statement {
            CompilerMirLoweringStatement::LocalI32Set {
                name,
                ..
            } => {
                let local_index =
                    phase11_local_state_local_index(function, name)?;
                assigned[local_index] = true;
            }
            CompilerMirLoweringStatement::LocalI32AddI32Literal {
                name,
                ..
            } => {
                let local_index =
                    phase11_local_state_local_index(function, name)?;
                if !assigned[local_index] {
                    return Err(phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        format!(
                            "Phase 11 local-state canonical MIR reads local {name} before definite assignment"
                        ),
                    ));
                }
            }
            _ => {
                return Err(phase10_backend_request_error(
                    Phase10BackendRequestStage::CanonicalMirValidation,
                    Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                    "Phase 11 local-state source route accepts only canonical i32 set/add statements",
                ));
            }
        }
    }
    Ok(())
}

fn phase11_local_state_validate_return(
    function: &CompilerMirLoweringFunction<'_>,
    terminator: &CompilerMirLoweringTerminator<'_>,
    assigned: &[bool],
) -> Result<(), Box<dyn Error>> {
    let CompilerMirLoweringTerminator::ReturnLocalI32(name) = terminator else {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 local-state source route requires a local i32 return",
        ));
    };
    let local_index = phase11_local_state_local_index(function, name)?;
    if !assigned[local_index] {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            format!(
                "Phase 11 local-state canonical MIR returns local {name} before definite assignment"
            ),
        ));
    }
    Ok(())
}

fn compiler_mir_cfg_successors<'a>(
    terminator: &CompilerMirLoweringTerminator<'a>,
) -> Vec<&'a str> {
    match terminator {
        CompilerMirLoweringTerminator::ReturnI32(_)
        | CompilerMirLoweringTerminator::ReturnLocalI32(_)
        | CompilerMirLoweringTerminator::ReturnBlockParamI32(_)
        | CompilerMirLoweringTerminator::ReturnVoid => Vec::new(),
        CompilerMirLoweringTerminator::Jump { edge } => vec![edge.target],
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
        } => vec![then_edge.target, else_edge.target],
    }
}

fn compiler_mir_cfg_block_indices<'a>(
    function: &CompilerMirLoweringFunction<'a>,
) -> HashMap<&'a str, usize> {
    function
        .blocks
        .iter()
        .enumerate()
        .map(|(index, block)| (block.label, index))
        .collect()
}

fn compiler_mir_cfg_predecessor_counts(
    function: &CompilerMirLoweringFunction<'_>,
) -> Result<Vec<usize>, Box<dyn Error>> {
    let block_indices = compiler_mir_cfg_block_indices(function);
    let mut predecessor_counts = vec![0usize; function.blocks.len()];
    for block in &function.blocks {
        for successor in compiler_mir_cfg_successors(&block.terminator) {
            let successor_index = *block_indices.get(successor).ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "unknown compiler MIR lowering successor {successor} from block {}",
                        block.label
                    ),
                )
            })?;
            predecessor_counts[successor_index] += 1;
        }
    }
    Ok(predecessor_counts)
}

fn compiler_mir_cfg_lowering_order(
    function: &CompilerMirLoweringFunction<'_>,
) -> Result<Vec<usize>, Box<dyn Error>> {
    let block_indices = compiler_mir_cfg_block_indices(function);
    let entry_index = *block_indices.get(function.entry_block).ok_or_else(|| {
        IoError::new(
            ErrorKind::InvalidInput,
            format!(
                "unknown compiler MIR lowering entry block: {}",
                function.entry_block
            ),
        )
    })?;
    let mut pending = VecDeque::from([entry_index]);
    let mut visited = vec![false; function.blocks.len()];
    let mut order = Vec::with_capacity(function.blocks.len());
    while let Some(block_index) = pending.pop_front() {
        if visited[block_index] {
            continue;
        }
        visited[block_index] = true;
        order.push(block_index);
        for successor in
            compiler_mir_cfg_successors(&function.blocks[block_index].terminator)
        {
            let successor_index = *block_indices.get(successor).ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "unknown compiler MIR lowering successor {successor} from block {}",
                        function.blocks[block_index].label
                    ),
                )
            })?;
            if !visited[successor_index] {
                pending.push_back(successor_index);
            }
        }
    }
    if order.len() != function.blocks.len() {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            "compiler MIR lowering graph contains unreachable blocks",
        )
        .into());
    }
    Ok(order)
}

fn compiler_mir_cfg_acyclic_order(
    function: &CompilerMirLoweringFunction<'_>,
) -> Result<Option<Vec<usize>>, Box<dyn Error>> {
    let block_indices = compiler_mir_cfg_block_indices(function);
    let mut remaining_predecessors =
        compiler_mir_cfg_predecessor_counts(function)?;
    let mut pending: VecDeque<usize> = remaining_predecessors
        .iter()
        .enumerate()
        .filter_map(|(index, count)| (*count == 0).then_some(index))
        .collect();
    let mut order = Vec::with_capacity(function.blocks.len());
    while let Some(block_index) = pending.pop_front() {
        order.push(block_index);
        for successor in
            compiler_mir_cfg_successors(&function.blocks[block_index].terminator)
        {
            let successor_index = *block_indices.get(successor).ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "unknown compiler MIR lowering successor {successor} from block {}",
                        function.blocks[block_index].label
                    ),
                )
            })?;
            remaining_predecessors[successor_index] -= 1;
            if remaining_predecessors[successor_index] == 0 {
                pending.push_back(successor_index);
            }
        }
    }
    if order.len() == function.blocks.len() {
        Ok(Some(order))
    } else {
        Ok(None)
    }
}

fn compiler_mir_cfg_predecessors(
    function: &CompilerMirLoweringFunction<'_>,
) -> Result<Vec<Vec<usize>>, Box<dyn Error>> {
    let block_indices = compiler_mir_cfg_block_indices(function);
    let mut predecessors = vec![Vec::new(); function.blocks.len()];
    for (source_index, block) in function.blocks.iter().enumerate() {
        for successor in compiler_mir_cfg_successors(&block.terminator) {
            let target_index = *block_indices.get(successor).ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "unknown compiler MIR lowering successor {successor} from block {}",
                        block.label
                    ),
                )
            })?;
            predecessors[target_index].push(source_index);
        }
    }
    Ok(predecessors)
}

fn compiler_mir_cfg_dominators(
    function: &CompilerMirLoweringFunction<'_>,
) -> Result<Vec<HashSet<usize>>, Box<dyn Error>> {
    let block_indices = compiler_mir_cfg_block_indices(function);
    let entry_index = *block_indices.get(function.entry_block).ok_or_else(|| {
        IoError::new(
            ErrorKind::InvalidInput,
            format!(
                "unknown compiler MIR lowering entry block: {}",
                function.entry_block
            ),
        )
    })?;
    let predecessors = compiler_mir_cfg_predecessors(function)?;
    let all_blocks: HashSet<usize> =
        (0..function.blocks.len()).collect();
    let mut dominators = vec![all_blocks.clone(); function.blocks.len()];
    dominators[entry_index] = HashSet::from([entry_index]);

    let mut changed = true;
    while changed {
        changed = false;
        for block_index in 0..function.blocks.len() {
            if block_index == entry_index {
                continue;
            }
            let mut next = all_blocks.clone();
            for predecessor in &predecessors[block_index] {
                next = next
                    .intersection(&dominators[*predecessor])
                    .copied()
                    .collect();
            }
            next.insert(block_index);
            if next != dominators[block_index] {
                dominators[block_index] = next;
                changed = true;
            }
        }
    }
    Ok(dominators)
}

fn compiler_mir_cfg_reducible_backedge_count(
    function: &CompilerMirLoweringFunction<'_>,
) -> Result<usize, Box<dyn Error>> {
    let block_indices = compiler_mir_cfg_block_indices(function);
    let dominators = compiler_mir_cfg_dominators(function)?;
    let mut non_backedge_indegree = vec![0usize; function.blocks.len()];
    let mut non_backedge_successors = vec![Vec::new(); function.blocks.len()];
    let mut backedge_count = 0usize;

    for (source_index, block) in function.blocks.iter().enumerate() {
        for successor in compiler_mir_cfg_successors(&block.terminator) {
            let target_index = *block_indices.get(successor).ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "unknown compiler MIR lowering successor {successor} from block {}",
                        block.label
                    ),
                )
            })?;
            if dominators[source_index].contains(&target_index) {
                backedge_count += 1;
            } else {
                non_backedge_indegree[target_index] += 1;
                non_backedge_successors[source_index].push(target_index);
            }
        }
    }

    let mut pending: VecDeque<usize> = non_backedge_indegree
        .iter()
        .enumerate()
        .filter_map(|(index, count)| (*count == 0).then_some(index))
        .collect();
    let mut visited = 0usize;
    while let Some(block_index) = pending.pop_front() {
        visited += 1;
        for successor in &non_backedge_successors[block_index] {
            non_backedge_indegree[*successor] -= 1;
            if non_backedge_indegree[*successor] == 0 {
                pending.push_back(*successor);
            }
        }
    }
    if visited != function.blocks.len() {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            "canonical compiler MIR contains an irreducible cycle or a backedge whose target does not dominate its source",
        )
        .into());
    }
    Ok(backedge_count)
}

fn is_phase11_block_parameter_loop_fixture(
    fixture: &ParsedCompilerMirFixture<'_>,
) -> bool {
    fixture.metadata.iter().any(|item| {
        item.payload.starts_with("kind=BlockParameterLoop;")
    })
}

fn validate_phase11_block_parameter_loop_fixture(
    fixture: &ParsedCompilerMirFixture<'_>,
) -> Result<(), Box<dyn Error>> {
    let function = &fixture.function;
    if !function.params.is_empty()
        || function.return_type != TinyMirType::I32
    {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 block-parameter/loop source route requires a zero-argument i32 entry",
        ));
    }
    if !function.locals.is_empty() {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 block-parameter/loop source route transports scalar state through block parameters rather than fixture-shaped locals",
        ));
    }

    recognize_compiler_mir_fixture_metadata(&fixture.metadata)?;
    let metadata = fixture.metadata.iter().find(|item| {
        item.payload.starts_with("kind=BlockParameterLoop;")
    }).ok_or_else(|| {
        phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 block-parameter/loop source route is missing its ownership metadata",
        )
    })?;
    if metadata.attachment != "function" {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 block-parameter/loop ownership metadata must attach to the function",
        ));
    }
    let profile = phase11_local_state_payload_field(
        metadata.payload,
        "profile",
    ).ok_or_else(|| {
        phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 block-parameter/loop metadata is missing its profile",
        )
    })?;
    if !matches!(profile, "non_final_join" | "bounded_loop") {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            format!(
                "Phase 11 block-parameter/loop metadata has unsupported profile {profile}"
            ),
        ));
    }

    let mut parameter_block_count = 0usize;
    let mut multi_parameter_block_count = 0usize;
    let mut non_final_parameter_block_count = 0usize;
    for block in &function.blocks {
        if !block.parameters.is_empty() {
            parameter_block_count += 1;
            if block.parameters.len() > 1 {
                multi_parameter_block_count += 1;
            }
            if !matches!(
                &block.terminator,
                CompilerMirLoweringTerminator::ReturnBlockParamI32(_)
            ) {
                non_final_parameter_block_count += 1;
            }
        }
        if block
            .parameters
            .iter()
            .any(|parameter| parameter.ty != TinyMirType::I32)
        {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                format!(
                    "Phase 11 block-parameter/loop block {} has a non-i32 parameter",
                    block.label
                ),
            ));
        }
        if !block.statements.is_empty() {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                "Phase 11 block-parameter/loop source route keeps scalar transport on edges and accepts no block statements",
            ));
        }

        let edges: Vec<&CompilerMirLoweringEdge<'_>> = match &block.terminator {
            CompilerMirLoweringTerminator::Jump { edge } => vec![edge],
            CompilerMirLoweringTerminator::BranchI32Literal {
                then_edge,
                else_edge,
                ..
            }
            | CompilerMirLoweringTerminator::BranchBlockParamI32Positive {
                then_edge,
                else_edge,
                ..
            } => vec![then_edge, else_edge],
            CompilerMirLoweringTerminator::ReturnBlockParamI32(_) => Vec::new(),
            _ => {
                return Err(phase10_backend_request_error(
                    Phase10BackendRequestStage::CanonicalMirValidation,
                    Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                    "Phase 11 block-parameter/loop source route accepts only literal or block-parameter branches, parameterized jumps, and block-parameter returns",
                ));
            }
        };
        for edge in edges {
            for argument in &edge.arguments {
                if !matches!(
                    argument,
                    CompilerMirLoweringEdgeArgument::I32Literal(_)
                        | CompilerMirLoweringEdgeArgument::BlockParamI32(_)
                        | CompilerMirLoweringEdgeArgument::BlockParamI32AddI32Literal {
                            ..
                        }
                ) {
                    return Err(phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        "Phase 11 block-parameter/loop source route accepts only i32 literal and current-block-parameter edge arguments",
                    ));
                }
            }
        }
    }
    if parameter_block_count == 0
        || multi_parameter_block_count == 0
        || non_final_parameter_block_count == 0
    {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 block-parameter parity requires multiple parameters and at least one parameterized non-final block",
        ));
    }

    let backedge_count = compiler_mir_cfg_reducible_backedge_count(function)
        .map_err(|error| {
            phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                error.to_string(),
            )
        })?;
    match profile {
        "non_final_join" if backedge_count != 0 => {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                "Phase 11 non-final join profile must remain acyclic",
            ));
        }
        "bounded_loop" if backedge_count == 0 => {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                "Phase 11 bounded-loop profile requires at least one natural backedge",
            ));
        }
        _ => {}
    }
    Ok(())
}

fn is_phase11_structured_cfg_fixture(
    fixture: &ParsedCompilerMirFixture<'_>,
) -> bool {
    fixture.metadata.iter().any(|item| {
        item.payload.starts_with("kind=StructuredCfg;")
    })
}

fn phase11_cfg_intersect_assignment_state(
    incoming: &mut Option<Vec<bool>>,
    candidate: &[bool],
) {
    match incoming {
        Some(existing) => {
            for (existing_value, candidate_value) in
                existing.iter_mut().zip(candidate)
            {
                *existing_value = *existing_value && *candidate_value;
            }
        }
        None => *incoming = Some(candidate.to_vec()),
    }
}

fn validate_phase11_local_state_fixture(
    fixture: &ParsedCompilerMirFixture<'_>,
) -> Result<(), Box<dyn Error>> {
    let function = &fixture.function;
    if !function.params.is_empty()
        || function.return_type != TinyMirType::I32
    {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 local-state/structured-CFG source route requires a zero-argument i32 entry",
        ));
    }
    if function.locals.is_empty()
        || function
            .locals
            .iter()
            .any(|local| local.ty != TinyMirType::I32)
    {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 local-state/structured-CFG source route requires a nonempty generic i32 local inventory",
        ));
    }
    if function
        .blocks
        .iter()
        .any(|block| !block.parameters.is_empty())
    {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 structured CFG parity keeps block parameters and edge arguments deferred to Patch 7",
        ));
    }

    recognize_compiler_mir_fixture_metadata(&fixture.metadata)?;

    let mut declaration_seen = vec![false; function.locals.len()];
    let mut assignment_metadata_count = 0usize;
    for item in &fixture.metadata {
        let Some(kind) =
            phase11_local_state_payload_field(item.payload, "kind")
        else {
            continue;
        };
        match kind {
            "LocalDeclaration" => {
                let Some(local_name) = phase11_local_state_payload_field(
                    item.payload,
                    "local",
                ) else {
                    return Err(phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        "Phase 11 local declaration provenance is missing its local name",
                    ));
                };
                let Some(index_text) = phase11_local_state_payload_field(
                    item.payload,
                    "index",
                ) else {
                    return Err(phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        "Phase 11 local declaration provenance is missing its stable index",
                    ));
                };
                let local_index: usize = index_text.parse().map_err(|_| {
                    phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        "Phase 11 local declaration provenance has an invalid stable index",
                    )
                })?;
                if local_index >= function.locals.len()
                    || function.locals[local_index].name != local_name
                    || declaration_seen[local_index]
                    || item.attachment != format!("local:{local_index}")
                {
                    return Err(phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        "Phase 11 local declaration provenance does not match the serialized local inventory",
                    ));
                }
                declaration_seen[local_index] = true;
            }
            "LocalAssignment" => {
                let Some(local_name) = phase11_local_state_payload_field(
                    item.payload,
                    "local",
                ) else {
                    return Err(phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        "Phase 11 local assignment provenance is missing its local name",
                    ));
                };
                phase11_local_state_local_index(function, local_name)?;
                if !item.attachment.starts_with("statement:") {
                    return Err(phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        "Phase 11 local assignment provenance must attach to a canonical statement",
                    ));
                }
                assignment_metadata_count += 1;
            }
            "StructuredCfg" => {
                if item.attachment != "function"
                    || phase11_local_state_payload_field(
                        item.payload,
                        "reducibility",
                    ) != Some("acyclic")
                {
                    return Err(phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        "Phase 11 structured CFG provenance must declare function-scoped acyclic reducibility",
                    ));
                }
            }
            _ => {}
        }
    }
    if declaration_seen.iter().any(|seen| !seen)
        || assignment_metadata_count == 0
    {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 local-state/structured-CFG source route requires one declaration provenance record per local and at least one assignment record",
        ));
    }

    let Some(order) = compiler_mir_cfg_acyclic_order(function).map_err(
        |error| {
            phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                error.to_string(),
            )
        },
    )? else {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 structured CFG parity explicitly defers backedges and cyclic or irreducible control flow to Patch 7",
        ));
    };
    let block_indices = compiler_mir_cfg_block_indices(function);
    let entry_index = *block_indices.get(function.entry_block).ok_or_else(|| {
        phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 structured CFG entry block is unknown",
        )
    })?;
    let mut incoming_assignment =
        vec![None::<Vec<bool>>; function.blocks.len()];
    incoming_assignment[entry_index] =
        Some(vec![false; function.locals.len()]);

    for block_index in order {
        let block = &function.blocks[block_index];
        let mut assigned = incoming_assignment[block_index]
            .take()
            .ok_or_else(|| {
                phase10_backend_request_error(
                    Phase10BackendRequestStage::CanonicalMirValidation,
                    Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                    format!(
                        "Phase 11 structured CFG block {} has no reachable predecessor assignment state",
                        block.label
                    ),
                )
            })?;
        phase11_local_state_apply_statements(
            function,
            block,
            &mut assigned,
        )?;

        match &block.terminator {
            CompilerMirLoweringTerminator::ReturnLocalI32(_) => {
                phase11_local_state_validate_return(
                    function,
                    &block.terminator,
                    &assigned,
                )?;
            }
            CompilerMirLoweringTerminator::Jump { edge } => {
                if !edge.arguments.is_empty() {
                    return Err(phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        "Phase 11 structured CFG parity keeps edge arguments deferred to Patch 7",
                    ));
                }
            }
            CompilerMirLoweringTerminator::BranchLocalI32Positive {
                name,
                then_edge,
                else_edge,
            } => {
                let condition_index =
                    phase11_local_state_local_index(function, name)?;
                if !assigned[condition_index] {
                    return Err(phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        format!(
                            "Phase 11 structured CFG branch reads local {name} before definite assignment"
                        ),
                    ));
                }
                if !then_edge.arguments.is_empty()
                    || !else_edge.arguments.is_empty()
                {
                    return Err(phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        "Phase 11 structured CFG parity keeps edge arguments deferred to Patch 7",
                    ));
                }
            }
            _ => {
                return Err(phase10_backend_request_error(
                    Phase10BackendRequestStage::CanonicalMirValidation,
                    Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                    "Phase 11 structured CFG source route accepts local i32 return, zero-argument jump, and positive-local branch terminators",
                ));
            }
        }

        for successor in compiler_mir_cfg_successors(&block.terminator) {
            let successor_index = *block_indices.get(successor).ok_or_else(|| {
                phase10_backend_request_error(
                    Phase10BackendRequestStage::CanonicalMirValidation,
                    Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                    format!(
                        "Phase 11 structured CFG block {} targets unknown successor {successor}",
                        block.label
                    ),
                )
            })?;
            phase11_cfg_intersect_assignment_state(
                &mut incoming_assignment[successor_index],
                &assigned,
            );
        }
    }

    Ok(())
}

fn validate_phase11_scalar_expression_fixture(
    fixture: &ParsedCompilerMirFixture<'_>,
) -> Result<(), Box<dyn Error>> {
    let function = &fixture.function;
    if !function.params.is_empty() {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 scalar-expression source route requires a zero-argument entry",
        ));
    }
    if function.return_type != TinyMirType::I32 {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 scalar-expression source route requires an i32 entry return",
        ));
    }
    if function.blocks.len() != 1 ||
        function.entry_block != function.blocks[0].label
    {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 scalar-expression source route requires one canonical block",
        ));
    }
    if function
        .locals
        .iter()
        .any(|local| local.ty != TinyMirType::I32)
    {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 scalar-expression source route accepts only i32 locals",
        ));
    }

    let block = &function.blocks[0];
    if !block.parameters.is_empty() {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 scalar-expression source route does not accept block parameters",
        ));
    }
    for statement in &block.statements {
        if !matches!(
            statement,
            CompilerMirLoweringStatement::LocalI32Set { .. } |
                CompilerMirLoweringStatement::LocalI32AddI32Literal { .. }
        ) {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                "Phase 11 scalar-expression source route accepts only canonical i32 set/add statements",
            ));
        }
    }
    if !matches!(
        &block.terminator,
        CompilerMirLoweringTerminator::ReturnI32(_) |
            CompilerMirLoweringTerminator::ReturnLocalI32(_)
    ) {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 11 scalar-expression source route accepts only scalar returns",
        ));
    }

    recognize_compiler_mir_fixture_metadata(&fixture.metadata)?;
    Ok(())
}

fn validate_phase10_scalar_metadata_fixture(
    fixture: &ParsedCompilerMirFixture<'_>,
) -> Result<(), Box<dyn Error>> {
    validate_phase11_scalar_expression_fixture(fixture)
}

fn validate_phase10_cfg_edge(
    edge: &CompilerMirLoweringEdge<'_>,
    context: &str,
) -> Result<(), Box<dyn Error>> {
    if edge.arguments.len() > 1 {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            format!(
                "Phase 10 Patch 9 source route accepts at most one edge argument at {context}"
            ),
        ));
    }
    for argument in &edge.arguments {
        if !matches!(
            argument,
            CompilerMirLoweringEdgeArgument::I32Literal(_)
        ) {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                format!(
                    "Phase 10 Patch 9 source route accepts only literal i32 edge arguments at {context}"
                ),
            ));
        }
    }
    Ok(())
}

fn validate_phase10_cfg_block_parameter_fixture(
    fixture: &ParsedCompilerMirFixture<'_>,
) -> Result<(), Box<dyn Error>> {
    let function = &fixture.function;
    if !function.params.is_empty() {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 10 Patch 9 source route requires a zero-argument entry",
        ));
    }
    if function.return_type != TinyMirType::I32 {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 10 Patch 9 source route requires an i32 entry return",
        ));
    }
    if function.blocks.len() < 3 || function.blocks.len() > 4 {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 10 Patch 9 source route accepts only three- or four-block CFGs",
        ));
    }
    if function.entry_block != function.blocks[0].label {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 10 Patch 9 source route requires the first canonical block to be the entry",
        ));
    }
    if function.locals.len() > 1 ||
        function
            .locals
            .iter()
            .any(|local| local.ty != TinyMirType::I32)
    {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 10 Patch 9 source route accepts at most one i32 local",
        ));
    }

    let mut block_parameter_count = 0usize;
    for (block_index, block) in function.blocks.iter().enumerate() {
        if block.parameters.len() > 1 ||
            block
                .parameters
                .iter()
                .any(|parameter| parameter.ty != TinyMirType::I32)
        {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                format!(
                    "Phase 10 Patch 9 source route accepts at most one i32 parameter in block {}",
                    block.label
                ),
            ));
        }
        if !block.parameters.is_empty() &&
            block_index + 1 != function.blocks.len()
        {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                "Phase 10 Patch 9 source route permits a block parameter only on the final merge block",
            ));
        }
        block_parameter_count += block.parameters.len();

        for statement in &block.statements {
            if !matches!(
                statement,
                CompilerMirLoweringStatement::LocalI32Set { .. }
            ) {
                return Err(phase10_backend_request_error(
                    Phase10BackendRequestStage::CanonicalMirValidation,
                    Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                    "Phase 10 Patch 9 source route accepts only LocalI32Set statements",
                ));
            }
        }

        match &block.terminator {
            CompilerMirLoweringTerminator::ReturnI32(_) |
            CompilerMirLoweringTerminator::ReturnLocalI32(_) |
            CompilerMirLoweringTerminator::ReturnBlockParamI32(_) => {}
            CompilerMirLoweringTerminator::Jump { edge } => {
                validate_phase10_cfg_edge(
                    edge,
                    &format!("block {} jump", block.label),
                )?;
            }
            CompilerMirLoweringTerminator::BranchI32Literal {
                then_edge,
                else_edge,
                ..
            } => {
                validate_phase10_cfg_edge(
                    then_edge,
                    &format!("block {} then edge", block.label),
                )?;
                validate_phase10_cfg_edge(
                    else_edge,
                    &format!("block {} else edge", block.label),
                )?;
            }
            CompilerMirLoweringTerminator::BranchLocalI32Positive {
                then_edge,
                else_edge,
                ..
            } => {
                validate_phase10_cfg_edge(
                    then_edge,
                    &format!("block {} then edge", block.label),
                )?;
                validate_phase10_cfg_edge(
                    else_edge,
                    &format!("block {} else edge", block.label),
                )?;
            }
            _ => {
                return Err(phase10_backend_request_error(
                    Phase10BackendRequestStage::CanonicalMirValidation,
                    Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                    "Phase 10 Patch 9 source route encountered a deferred terminator",
                ));
            }
        }
    }

    if block_parameter_count > 1 {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 10 Patch 9 source route accepts at most one block parameter",
        ));
    }
    if block_parameter_count == 0 && function.blocks.len() != 3 {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 10 Patch 9 parameter-free CFG must contain exactly three blocks",
        ));
    }
    if block_parameter_count == 1 && function.blocks.len() != 4 {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 10 Patch 9 block-parameter CFG must contain exactly four blocks",
        ));
    }

    recognize_compiler_mir_fixture_metadata(&fixture.metadata)?;
    Ok(())
}

fn validate_phase10_call_result_function(
    defined: &CompilerMirLoweringDefinedFunction<'_>,
    expected_linkage: CompilerMirLoweringFunctionLinkage,
    expected_callee: &str,
    expect_imported: bool,
) -> Result<i32, Box<dyn Error>> {
    if defined.linkage != expected_linkage {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 10 Patch 10 function linkage does not match the connected call shape",
        ));
    }

    let fixture = &defined.fixture;
    let function = &fixture.function;
    if function.object_name != "main" ||
        function.symbol != "main" ||
        !function.params.is_empty() ||
        function.return_type != TinyMirType::I32 ||
        function.locals.len() != 1 ||
        function.locals[0].ty != TinyMirType::I32 ||
        function.entry_block != "entry" ||
        function.blocks.len() != 1
    {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 10 Patch 10 entry must be one zero-argument main() int with one i32 call-result local and one entry block",
        ));
    }

    let block = &function.blocks[0];
    if block.label != "entry" ||
        !block.parameters.is_empty() ||
        block.statements.len() != 1
    {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 10 Patch 10 entry block shape drifted",
        ));
    }

    let (
        result_local,
        target,
        arguments,
    ) = match &block.statements[0] {
        CompilerMirLoweringStatement::LocalI32SetCall {
            name,
            target,
            arguments,
        } => (*name, target, arguments),
        _ => {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                "Phase 10 Patch 10 entry accepts exactly one LocalI32SetCall statement",
            ));
        }
    };

    if result_local != function.locals[0].name ||
        result_local != "call_result"
    {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 10 Patch 10 call result must target the canonical call_result local",
        ));
    }

    match (expect_imported, target) {
        (
            false,
            CompilerMirLoweringCallTarget::LocalFunction(name),
        ) if *name == expected_callee => {}
        (
            true,
            CompilerMirLoweringCallTarget::ImportedFunction(name),
        ) if *name == expected_callee => {}
        _ => {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                "Phase 10 Patch 10 call target kind or name is outside the connected cohort",
            ));
        }
    }

    if arguments.len() != 1 {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 10 Patch 10 calls require exactly one literal i32 argument",
        ));
    }
    let argument_value = match arguments[0] {
        CompilerMirLoweringCallArgument::I32Literal(value) if value >= 0 => value,
        _ => {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                "Phase 10 Patch 10 calls accept only one non-negative i32 literal argument",
            ));
        }
    };

    match &block.terminator {
        CompilerMirLoweringTerminator::ReturnLocalI32(name)
            if *name == result_local => {}
        _ => {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                "Phase 10 Patch 10 entry must return the call-result local",
            ));
        }
    }

    Ok(argument_value)
}

fn validate_phase10_local_identity_helper(
    defined: &CompilerMirLoweringDefinedFunction<'_>,
) -> Result<(), Box<dyn Error>> {
    if defined.linkage != CompilerMirLoweringFunctionLinkage::ModuleLocal {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 10 Patch 10 local helper must use module_local linkage",
        ));
    }

    let fixture = &defined.fixture;
    let function = &fixture.function;
    if function.object_name != "phase10_local_identity" ||
        function.symbol != "phase10_local_identity" ||
        function.params.as_slice() != [TinyMirType::I32] ||
        function.return_type != TinyMirType::I32 ||
        function.locals.len() != 1 ||
        function.locals[0].name != "param_value" ||
        function.locals[0].ty != TinyMirType::I32 ||
        function.entry_block != "entry" ||
        function.blocks.len() != 1
    {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 10 Patch 10 local helper signature or storage shape drifted",
        ));
    }

    let block = &function.blocks[0];
    if block.label != "entry" ||
        !block.parameters.is_empty() ||
        block.statements.len() != 1
    {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 10 Patch 10 local helper block shape drifted",
        ));
    }

    match &block.statements[0] {
        CompilerMirLoweringStatement::LocalI32SetParam {
            name,
            param: 0,
        } if *name == "param_value" => {}
        _ => {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                "Phase 10 Patch 10 local helper must copy parameter zero into param_value",
            ));
        }
    }
    match &block.terminator {
        CompilerMirLoweringTerminator::ReturnLocalI32(name)
            if *name == "param_value" => {}
        _ => {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                "Phase 10 Patch 10 local helper must return param_value",
            ));
        }
    }
    if !fixture.metadata.is_empty() {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::CanonicalMirValidation,
            Phase10BackendRequestFailureKind::InvalidCanonicalMir,
            "Phase 10 Patch 10 local helper carries no metadata",
        ));
    }
    Ok(())
}

fn validate_phase10_calls_imports_runtime_module(
    module: &CompilerMirLoweringModule<'_>,
) -> Result<&'static str, Box<dyn Error>> {
    validate_compiler_mir_module(module)?;

    if module.name == "phase10_local_call" {
        if !module.imports.is_empty() || module.functions.len() != 2 {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                "Phase 10 Patch 10 local-call module requires two defined functions and no imports",
            ));
        }

        validate_phase10_local_identity_helper(&module.functions[0])?;
        let argument = validate_phase10_call_result_function(
            &module.functions[1],
            CompilerMirLoweringFunctionLinkage::ExportedEntry,
            "phase10_local_identity",
            false,
        )?;
        if module.functions[1].fixture.expected_exit != argument ||
            !module.functions[1].fixture.metadata.is_empty()
        {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                "Phase 10 Patch 10 local-call expected exit or metadata drifted",
            ));
        }
        return Ok("local_call");
    }

    if module.name == "phase10_runtime_boundary" {
        if module.imports.len() != 1 || module.functions.len() != 1 {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                "Phase 10 Patch 10 runtime-boundary module requires one imported host function and one entry",
            ));
        }

        let imported = &module.imports[0];
        if imported.name != "abs" ||
            imported.link_symbol != "abs" ||
            imported.linkage !=
                CompilerMirLoweringFunctionLinkage::ImportedHost ||
            imported.params.as_slice() != [TinyMirType::I32] ||
            imported.return_type != TinyMirType::I32
        {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                "Phase 10 Patch 10 runtime boundary permits only imported_host abs(int)->int",
            ));
        }

        let argument = validate_phase10_call_result_function(
            &module.functions[0],
            CompilerMirLoweringFunctionLinkage::ExportedEntry,
            "abs",
            true,
        )?;
        let fixture = &module.functions[0].fixture;
        if fixture.expected_exit != argument || fixture.metadata.len() != 1 {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                "Phase 10 Patch 10 runtime-boundary expected exit or metadata count drifted",
            ));
        }
        let metadata = &fixture.metadata[0];
        if metadata.kind != "native_boundary" ||
            metadata.attachment != "statement:entry:0" ||
            metadata.policy != "ignored_with_proof" ||
            !metadata
                .payload
                .starts_with("kind=RuntimeCall;symbol=abs;")
        {
            return Err(phase10_backend_request_error(
                Phase10BackendRequestStage::CanonicalMirValidation,
                Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                "Phase 10 Patch 10 runtime boundary requires one statement-attached abs RuntimeCall metadata record",
            ));
        }
        return Ok("runtime_boundary");
    }

    Err(phase10_backend_request_error(
        Phase10BackendRequestStage::CanonicalMirValidation,
        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
        "Phase 10 Patch 10 canonical v2 module is outside the connected local-call and runtime-boundary cohorts",
    ))
}


fn phase11_import_registry_classification(
    imported: &CompilerMirLoweringImportedFunction<'_>,
) -> Option<&'static str> {
    if imported.linkage != CompilerMirLoweringFunctionLinkage::ImportedHost
        || imported.params.as_slice() != [TinyMirType::I32]
        || imported.return_type != TinyMirType::I32
    {
        return None;
    }
    match imported.link_symbol {
        "abs" if imported.name == "abs" => Some("RuntimeCall"),
        "toupper" if imported.name == "toupper" => Some("ExternFunction"),
        _ => None,
    }
}

fn validate_phase11_import_boundary_metadata(
    module: &CompilerMirLoweringModule<'_>,
) -> Result<(), Box<dyn Error>> {
    let imported_hosts: HashMap<&str, (&str, &str)> = module
        .imports
        .iter()
        .filter_map(|imported| {
            phase11_import_registry_classification(imported).map(
                |classification| {
                    (
                        imported.name,
                        (imported.link_symbol, classification),
                    )
                },
            )
        })
        .collect();

    for defined in &module.functions {
        for block in &defined.fixture.function.blocks {
            for (statement_index, statement) in block.statements.iter().enumerate() {
                let CompilerMirLoweringStatement::LocalI32SetCall {
                    target:
                        CompilerMirLoweringCallTarget::ImportedFunction(
                            imported_name,
                        ),
                    ..
                } = statement
                else {
                    continue;
                };
                let Some((link_symbol, classification)) =
                    imported_hosts.get(imported_name)
                else {
                    continue;
                };
                let attachment =
                    format!("statement:{}:{statement_index}", block.label);
                let payload_prefix = format!(
                    "kind={classification};symbol={link_symbol};"
                );
                let matching_metadata = defined
                    .fixture
                    .metadata
                    .iter()
                    .filter(|metadata| {
                        metadata.kind == "native_boundary"
                            && metadata.attachment == attachment
                            && metadata.policy == "ignored_with_proof"
                            && metadata.payload.starts_with(&payload_prefix)
                    })
                    .count();
                if matching_metadata != 1 {
                    return Err(phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        format!(
                            "approved host import {link_symbol} requires exactly one {classification} metadata record attached to {attachment}"
                        ),
                    ));
                }
            }
        }
    }
    Ok(())
}

fn validate_phase11_module_import_runtime_module(
    module: &CompilerMirLoweringModule<'_>,
) -> Result<&'static str, Box<dyn Error>> {
    validate_compiler_mir_module(module)?;

    let mut has_bundle_import = false;
    let mut has_runtime_import = false;
    let mut has_declared_external = false;
    for imported in &module.imports {
        match imported.linkage {
            CompilerMirLoweringFunctionLinkage::ImportedBundle => {
                has_bundle_import = true;
            }
            CompilerMirLoweringFunctionLinkage::ImportedHost => {
                let Some(classification) =
                    phase11_import_registry_classification(imported)
                else {
                    return Err(phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        format!(
                            "host import {} with symbol {} is absent from the Phase 11 import/runtime registry",
                            imported.name, imported.link_symbol
                        ),
                    ));
                };
                if classification == "RuntimeCall" {
                    has_runtime_import = true;
                } else {
                    has_declared_external = true;
                }
            }
            _ => {
                return Err(phase10_backend_request_error(
                    Phase10BackendRequestStage::CanonicalMirValidation,
                    Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                    format!(
                        "canonical import {} has a non-import linkage",
                        imported.name
                    ),
                ));
            }
        }
    }

    validate_phase11_import_boundary_metadata(module)?;

    if has_bundle_import {
        Ok("module_import_runtime")
    } else if has_declared_external {
        Ok("declared_external_import")
    } else if has_runtime_import {
        Ok("runtime_boundary")
    } else {
        Ok("direct_call_abi")
    }
}

fn compile_phase10_scalar_metadata_request_path(
    request_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let request_contents = fs::read_to_string(request_path).map_err(|error| {
        phase10_backend_request_error(
            Phase10BackendRequestStage::RequestParse,
            Phase10BackendRequestFailureKind::InvalidRequest,
            format!(
                "failed to read backend request {}: {error}",
                request_path.display()
            ),
        )
    })?;
    let request = parse_phase10_backend_request(&request_contents)?;

    let (_object_builder, target_contract) =
        build_compiler_mir_native_object_builder(
            "gust_phase10_source_route_compile_probe",
        )
        .map_err(|error| {
            phase10_backend_request_error(
                Phase10BackendRequestStage::TargetValidation,
                Phase10BackendRequestFailureKind::TargetMismatch,
                format!(
                    "failed to resolve native target contract: {error}"
                ),
            )
        })?;

    if request.target_triple != target_contract.triple
        || request.object_format != target_contract.object_format
    {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::TargetValidation,
            Phase10BackendRequestFailureKind::TargetMismatch,
            "backend request target or object format does not match the native Phase 9G contract",
        ));
    }

    let bundle_contents =
        fs::read_to_string(&request.program_mir_bundle_path).map_err(
            |error| {
                phase10_backend_request_error(
                    Phase10BackendRequestStage::ProgramMirBundleValidation,
                    Phase10BackendRequestFailureKind::InvalidBundle,
                    format!(
                        "failed to read program MIR bundle {}: {error}",
                        request.program_mir_bundle_path.display()
                    ),
                )
            },
        )?;
    let bundle = parse_phase10_program_mir_bundle(&bundle_contents)?;
    if bundle.modules.len() != bundle.module_count {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::ProgramMirBundleValidation,
            Phase10BackendRequestFailureKind::InvalidBundle,
            "program MIR bundle module records do not match module_count",
        ));
    }

    let mut object_paths = Vec::with_capacity(bundle.module_count);
    let mut source_route = "scalar_metadata";
    let mut reported_module_path = "";
    let mut reported_object_name = "";
    let mut preserved_metadata_count = 0usize;
    let mut preserved_resource_metadata_count = 0usize;
    let mut preserved_provenance_metadata_count = 0usize;
    let mut preserved_native_boundary_metadata_count = 0usize;

    for (module_index, module_record) in bundle.modules.iter().enumerate() {
        preserved_metadata_count += module_record.metadata.len();
        for metadata in &module_record.metadata {
            match metadata.kind.as_str() {
                "resource" => preserved_resource_metadata_count += 1,
                "provenance" => preserved_provenance_metadata_count += 1,
                "native_boundary" => {
                    preserved_native_boundary_metadata_count += 1
                }
                _ => {
                    return Err(phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        format!(
                            "retained metadata class drifted after bundle validation: {}",
                            metadata.kind
                        ),
                    ));
                }
            }
            if metadata.attachment.is_empty()
                || metadata.policy.is_empty()
                || metadata.payload.is_empty()
            {
                return Err(phase10_backend_request_error(
                    Phase10BackendRequestStage::CanonicalMirValidation,
                    Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                    "retained metadata record became incomplete before lowering",
                ));
            }
        }
        let parsed =
            parse_compiler_mir_input(&module_record.canonical_mir).map_err(
                |error| {
                    phase10_backend_request_error(
                        Phase10BackendRequestStage::CanonicalMirValidation,
                        Phase10BackendRequestFailureKind::InvalidCanonicalMir,
                        format!(
                            "canonical MIR module {module_index} parse failed: {error}"
                        ),
                    )
                },
            )?;

        let object_suffix = if bundle.module_count == 1 {
            ".phase10-source-route.o".to_string()
        } else {
            format!(".phase10-source-route-{module_index}.o")
        };
        let object_path = compiler_mir_link_sibling_path(
            &request.output_path,
            &object_suffix,
        )?;

        match parsed {
            ParsedCompilerMirInput::V1(fixture) => {
                if bundle.module_count != 1 {
                    return Err(phase10_backend_request_error(
                        Phase10BackendRequestStage::ProgramMirBundleValidation,
                        Phase10BackendRequestFailureKind::InvalidBundle,
                        "multi-module source routes require canonical MIR v2 modules",
                    ));
                }
                if module_record.canonical_format
                    != COMPILER_MIR_CANONICAL_FIXTURE_FORMAT
                {
                    return Err(phase10_backend_request_error(
                        Phase10BackendRequestStage::ProgramMirBundleValidation,
                        Phase10BackendRequestFailureKind::InvalidBundle,
                        "Phase 10 v1 source route canonical format record drifted",
                    ));
                }
                validate_compiler_mir_fixture(&fixture)?;
                if is_phase11_block_parameter_loop_fixture(&fixture) {
                    validate_phase11_block_parameter_loop_fixture(&fixture)?;
                    source_route = "block_parameter_loop";
                } else if is_phase11_structured_cfg_fixture(&fixture) {
                    validate_phase11_local_state_fixture(&fixture)?;
                    source_route = "structured_cfg";
                } else if is_phase11_local_state_fixture(&fixture) {
                    validate_phase11_local_state_fixture(&fixture)?;
                    source_route = "local_state";
                } else if fixture.function.blocks.len() == 1 {
                    validate_phase11_scalar_expression_fixture(&fixture)?;
                    let has_scalar_add = fixture.function.blocks[0]
                        .statements
                        .iter()
                        .any(|statement| {
                            matches!(
                                statement,
                                CompilerMirLoweringStatement::LocalI32AddI32Literal {
                                    ..
                                }
                            )
                        });
                    source_route = if has_scalar_add {
                        "scalar_expression"
                    } else {
                        "scalar_metadata"
                    };
                } else {
                    validate_phase10_cfg_block_parameter_fixture(&fixture)?;
                    source_route = "cfg_block_parameter";
                }
                lower_compiler_mir_ingestion_function_to_object(
                    &object_path,
                    &fixture.function,
                )?;
            }
            ParsedCompilerMirInput::V2(module) => {
                if module_record.canonical_format
                    != COMPILER_MIR_CANONICAL_MODULE_FORMAT
                {
                    return Err(phase10_backend_request_error(
                        Phase10BackendRequestStage::ProgramMirBundleValidation,
                        Phase10BackendRequestFailureKind::InvalidBundle,
                        "canonical v2 source route format record drifted",
                    ));
                }

                let module_route = if matches!(
                    module.name,
                    "phase10_local_call" | "phase10_runtime_boundary"
                ) {
                    validate_phase10_calls_imports_runtime_module(&module)?
                } else {
                    validate_phase11_module_import_runtime_module(&module)?
                };
                if module_route == "module_import_runtime" {
                    source_route = "module_import_runtime";
                } else if source_route != "module_import_runtime"
                    && module_route == "declared_external_import"
                {
                    source_route = "declared_external_import";
                } else if source_route == "scalar_metadata"
                    || source_route == "direct_call_abi"
                {
                    source_route = module_route;
                }

                lower_compiler_mir_ingestion_module_to_object(
                    &object_path,
                    &module,
                )?;
            }
        }

        object_paths.push(object_path);
        reported_module_path = &module_record.module_path;
        reported_object_name = &module_record.object_name;
    }

    let linker_driver =
        env::var_os("CC").unwrap_or_else(|| OsString::from("cc"));
    let link_request = CompilerMirLinkRequest {
        output_path: request.output_path.clone(),
        ordered_object_inputs: object_paths.clone(),
        c_source: None,
        host_object: None,
        additional_libraries: Vec::new(),
        additional_linker_args: Vec::new(),
        linker_driver,
        environment_overrides: Vec::new(),
        expected_result: CompilerMirLinkExpectedResult::Success,
        expected_failure_kind: None,
    };

    let report = run_compiler_mir_link_request(link_request)?;
    if !report.published {
        return Err(phase10_backend_request_error(
            Phase10BackendRequestStage::RequestValidation,
            Phase10BackendRequestFailureKind::InvalidRequest,
            "Phase 9G link pipeline did not publish the requested executable",
        ));
    }

    for object_path in &object_paths {
        fs::remove_file(object_path).map_err(|error| {
            phase10_backend_request_error(
                Phase10BackendRequestStage::RequestValidation,
                Phase10BackendRequestFailureKind::InvalidRequest,
                format!(
                    "could not remove successful hidden source-route object {}: {error}",
                    object_path.display()
                ),
            )
        })?;
    }

    println!("request_protocol: {PHASE10_BACKEND_REQUEST_FORMAT}");
    println!("request_status: compiled");
    println!("artifact_kind: {PHASE10_BACKEND_REQUEST_ARTIFACT_KIND}");
    println!("source_route: {source_route}");
    println!("entry_symbol: {}", bundle.entry_symbol);
    println!("module_count: {}", bundle.module_count);
    println!("module_path: {reported_module_path}");
    println!("object_name: {reported_object_name}");
    println!("metadata_record_count: {preserved_metadata_count}");
    println!(
        "resource_metadata_count: {preserved_resource_metadata_count}"
    );
    println!(
        "provenance_metadata_count: {preserved_provenance_metadata_count}"
    );
    println!(
        "native_boundary_metadata_count: {preserved_native_boundary_metadata_count}"
    );
    println!("target_triple: {}", request.target_triple);
    println!("object_format: {}", request.object_format);
    println!("output_path: {}", request.output_path.display());
    Ok(())
}

const PHASE10_DRIVER_PROTOCOL: &str = "gust.native_backend.driver.v1";
const PHASE10_PROGRAM_MIR_BUNDLE_FORMAT: &str = "gust.compiler_program_mir_bundle.v1";
const PHASE10_PIPELINE_TAXONOMY: &str = "gust.phase9g.pipeline.v1";
const PHASE10_CANONICAL_MIR_FORMATS: [&str; 2] = [
    "gust.compiler_mir_ingestion.v1",
    "gust.compiler_mir_ingestion.v2",
];
const PHASE10_DRIVER_OPERATIONS: [&str; 15] = [
    "ReturnI32",
    "LocalI32Set",
    "LocalI32Read",
    "AddI32",
    "SubI32",
    "MulI32",
    "EqI32",
    "SgtI32",
    "Jump",
    "Branch",
    "BlockParam",
    "LocalCallI32",
    "ImportedCallI32",
    "ImportedPredicateI32",
    "ImportedMaterializeI32",
];
const PHASE10_DRIVER_TYPES_AND_ABIS: [&str; 6] = [
    "int",
    "bool",
    "()->int",
    "(int)->int",
    "(int,int)->int",
    "direct_scalar_abi",
];
const PHASE10_DRIVER_RUNTIME_IMPORTS: [&str; 5] = [
    "tiny_host_add_one_i32",
    "tiny_host_add_i32",
    "tiny_host_is_positive_i32",
    "abs",
    "toupper",
];
const PHASE10_DRIVER_TARGET_REQUIREMENTS: [&str; 3] = [
    "native_host",
    "position_independent_code",
    "native_executable_link",
];

fn print_phase10_driver_handshake() -> Result<(), Box<dyn Error>> {
    let (_object_builder, target_contract) =
        build_compiler_mir_native_object_builder("gust_phase10_driver_handshake_probe")?;

    println!("protocol: {PHASE10_DRIVER_PROTOCOL}");
    println!("driver_name: {}", env!("CARGO_PKG_NAME"));
    println!("driver_version: {}", env!("CARGO_PKG_VERSION"));
    println!(
        "program_mir_bundle_format: {PHASE10_PROGRAM_MIR_BUNDLE_FORMAT}"
    );
    for format_name in PHASE10_CANONICAL_MIR_FORMATS {
        println!("canonical_mir_format: {format_name}");
    }
    println!("target_triple: {}", target_contract.triple);
    println!("object_format: {}", target_contract.object_format);
    println!("link_capability: native_executable");
    println!("pipeline_taxonomy: {PHASE10_PIPELINE_TAXONOMY}");
    for operation in PHASE10_DRIVER_OPERATIONS {
        println!("operation: {operation}");
    }
    for type_or_abi in PHASE10_DRIVER_TYPES_AND_ABIS {
        println!("type_or_abi: {type_or_abi}");
    }
    for runtime_import in PHASE10_DRIVER_RUNTIME_IMPORTS {
        println!("runtime_import: {runtime_import}");
    }
    for target_requirement in PHASE10_DRIVER_TARGET_REQUIREMENTS {
        println!("target_requirement: {target_requirement}");
    }
    Ok(())
}

fn print_compiler_mir_pipeline_taxonomy() -> Result<(), Box<dyn Error>> {
    println!("pipeline_stage_count: {}", COMPILER_MIR_PIPELINE_STAGES.len());
    for stage in COMPILER_MIR_PIPELINE_STAGES {
        println!("pipeline_stage: {}", stage.as_str());
    }
    println!(
        "link_failure_kind_count: {}",
        COMPILER_MIR_LINK_FAILURE_KINDS.len()
    );
    for kind in COMPILER_MIR_LINK_FAILURE_KINDS {
        println!("link_failure_kind: {}", kind.as_str());
    }
    println!(
        "machine_line_format: gust_pipeline_failure: stage=<stage> kind=<kind>"
    );
    println!(
        "diagnostic_taxonomy: {PHASE11_BACKEND_DIAGNOSTIC_TAXONOMY}"
    );
    println!(
        "diagnostic_class_count: {}",
        PHASE11_BACKEND_DIAGNOSTIC_CLASSES.len()
    );
    for class_name in PHASE11_BACKEND_DIAGNOSTIC_CLASSES {
        println!("diagnostic_class: {class_name}");
    }
    Ok(())
}

fn main() {
    if let Err(error) = run() {
        if let Some(request_error) =
            error.downcast_ref::<Phase10BackendRequestError>()
        {
            eprintln!(
                "{}",
                phase11_diagnostic_machine_line(
                    phase11_request_diagnostic_class(request_error),
                )
            );
            eprintln!("{}", request_error.machine_line());
        }
        if let Some(pipeline_error) =
            error.downcast_ref::<CompilerMirPipelineError>()
        {
            eprintln!(
                "{}",
                phase11_diagnostic_machine_line(
                    phase11_pipeline_diagnostic_class(pipeline_error),
                )
            );
            eprintln!("{}", pipeline_error.machine_line());
        }
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
        "phase10-backend-request-compile" => {
            let Some(request_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            compile_phase10_scalar_metadata_request_path(
                Path::new(&request_path),
            )
        }
        "phase10-backend-request-validate" => {
            let Some(request_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            validate_phase10_backend_request_path(Path::new(&request_path))
        }
        "phase10-driver-handshake" => {
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            print_phase10_driver_handshake()
        }
        "compiler-mir-pipeline-taxonomy" => {
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            print_compiler_mir_pipeline_taxonomy()
        }
        "compiler-mir-object-target-contract" => {
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            print_compiler_mir_object_target_contract()
        }
        "compiler-mir-inspect-object" => {
            let Some(input_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            inspect_compiler_mir_object_path(Path::new(&input_path))
        }
        "compiler-mir-verify-object-contract" => {
            let Some(fixture_path) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(object_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            verify_compiler_mir_object_contract_path(
                Path::new(&fixture_path),
                Path::new(&object_path),
            )
        }
        "compiler-mir-write-negative-object-fixture" => {
            let Some(fixture_kind) = args.next() else {
                return Err(usage_error().into());
            };
            let Some(output_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            write_compiler_mir_negative_object_fixture(
                &fixture_kind,
                Path::new(&output_path),
            )
        }
        "compiler-mir-link-request" => {
            let Some(request_path) = args.next() else {
                return Err(usage_error().into());
            };
            if args.next().is_some() {
                return Err(usage_error().into());
            }
            execute_compiler_mir_link_request_path(Path::new(&request_path))
        }
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
            compiler_mir_pipeline_wrap_box(
                validate_compiler_mir_fixture_path(Path::new(&input_path)),
                CompilerMirPipelineStage::FixtureValidation,
                CompilerMirPipelineFailureKind::InvalidFixture,
            )
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
            "  gust-cranelift-experiment phase10-backend-request-compile <request.native>\n",
            "  gust-cranelift-experiment phase10-backend-request-validate <request.native>\n",
            "  gust-cranelift-experiment phase10-driver-handshake\n",
            "  gust-cranelift-experiment compiler-mir-pipeline-taxonomy\n",
            "  gust-cranelift-experiment compiler-mir-object-target-contract\n",
            "  gust-cranelift-experiment compiler-mir-inspect-object <input.o>\n",
            "  gust-cranelift-experiment compiler-mir-verify-object-contract <input.mir> <input.o>\n",
            "  gust-cranelift-experiment compiler-mir-write-negative-object-fixture <wrong-format|unsupported-architecture> <output.o>\n",
            "  gust-cranelift-experiment compiler-mir-link-request <request.link>\n",
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
    parse_compiler_mir_fixture_field_map(
        fields,
        COMPILER_MIR_CANONICAL_FIXTURE_FORMAT,
        false,
    )
}

fn parse_compiler_mir_fixture_field_map<'a>(
    fields: HashMap<&'a str, &'a str>,
    expected_format: &str,
    allow_calls: bool,
) -> Result<ParsedCompilerMirFixture<'a>, Box<dyn Error>> {
    let mut consumed: HashSet<&str> = HashSet::new();

    let format = required_canonical_compiler_mir_fixture_field(
        &fields,
        &mut consumed,
        "format",
    )?;
    if format != expected_format {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            format!(
                "canonical compiler MIR fixture format expected {}, got {format}",
                expected_format
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
                "LocalI32SetCall" => {
                    if !allow_calls {
                        return Err(IoError::new(
                            ErrorKind::InvalidInput,
                            "gust.compiler_mir_ingestion.v1 remains call/import-free",
                        )
                        .into());
                    }
                    let local_key = format!("{prefix}_local");
                    let callee_kind_key = format!("{prefix}_callee_kind");
                    let callee_key = format!("{prefix}_callee");
                    let callee_kind = required_canonical_compiler_mir_fixture_field(
                        &fields,
                        &mut consumed,
                        &callee_kind_key,
                    )?;
                    let callee = required_canonical_compiler_mir_fixture_field(
                        &fields,
                        &mut consumed,
                        &callee_key,
                    )?;
                    let target = match callee_kind {
                        "LocalFunction" => {
                            CompilerMirLoweringCallTarget::LocalFunction(callee)
                        }
                        "ImportedFunction" => {
                            CompilerMirLoweringCallTarget::ImportedFunction(callee)
                        }
                        other => {
                            return Err(IoError::new(
                                ErrorKind::InvalidInput,
                                format!(
                                    "unsupported canonical compiler MIR call target kind at {callee_kind_key}: {other}"
                                ),
                            )
                            .into());
                        }
                    };
                    CompilerMirLoweringStatement::LocalI32SetCall {
                        name: required_canonical_compiler_mir_fixture_field(
                            &fields,
                            &mut consumed,
                            &local_key,
                        )?,
                        target,
                        arguments: parse_canonical_compiler_mir_call_arguments(
                            &fields,
                            &mut consumed,
                            &prefix,
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

fn parse_compiler_mir_input<'a>(
    contents: &'a str,
) -> Result<ParsedCompilerMirInput<'a>, Box<dyn Error>> {
    let fields = parse_compiler_mir_fixture_fields(contents)?;
    let format = fields.get("format").copied().ok_or_else(|| {
        IoError::new(
            ErrorKind::InvalidInput,
            "missing canonical compiler MIR fixture field: format",
        )
    })?;
    match format {
        COMPILER_MIR_CANONICAL_FIXTURE_FORMAT => {
            parse_compiler_mir_fixture(contents).map(ParsedCompilerMirInput::V1)
        }
        COMPILER_MIR_CANONICAL_MODULE_FORMAT => {
            parse_compiler_mir_module_field_map(&fields).map(ParsedCompilerMirInput::V2)
        }
        other => Err(IoError::new(
            ErrorKind::InvalidInput,
            format!("unsupported canonical compiler MIR fixture format: {other}"),
        )
        .into()),
    }
}

fn parse_compiler_mir_module_field_map<'a>(
    fields: &HashMap<&'a str, &'a str>,
) -> Result<CompilerMirLoweringModule<'a>, Box<dyn Error>> {
    let mut consumed: HashSet<&str> = HashSet::new();
    let format = required_canonical_compiler_mir_fixture_field(
        fields,
        &mut consumed,
        "format",
    )?;
    if format != COMPILER_MIR_CANONICAL_MODULE_FORMAT {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            format!(
                "canonical compiler MIR module format expected {}, got {format}",
                COMPILER_MIR_CANONICAL_MODULE_FORMAT
            ),
        )
        .into());
    }

    let name = required_canonical_compiler_mir_fixture_field(
        fields,
        &mut consumed,
        "module",
    )?;

    let import_count = parse_canonical_compiler_mir_usize_field(
        fields,
        &mut consumed,
        "import_count",
    )?;
    let mut imports = Vec::with_capacity(import_count);
    for index in 0..import_count {
        let prefix = format!("import_{index}");
        let name_key = format!("{prefix}_name");
        let link_symbol_key = format!("{prefix}_link_symbol");
        let linkage_key = format!("{prefix}_linkage");
        let parameter_count_key = format!("{prefix}_parameter_count");
        let return_type_key = format!("{prefix}_return_type");
        let linkage_value = required_canonical_compiler_mir_fixture_field(
            fields,
            &mut consumed,
            &linkage_key,
        )?;
        let linkage = match linkage_value {
            "imported_host" => CompilerMirLoweringFunctionLinkage::ImportedHost,
            "imported_bundle" => CompilerMirLoweringFunctionLinkage::ImportedBundle,
            other => {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "invalid canonical compiler MIR imported function linkage at {linkage_key}: {other}"
                    ),
                )
                .into());
            }
        };
        let parameter_count = parse_canonical_compiler_mir_usize_field(
            fields,
            &mut consumed,
            &parameter_count_key,
        )?;
        let mut params = Vec::with_capacity(parameter_count);
        for parameter_index in 0..parameter_count {
            let key = format!("{prefix}_parameter_{parameter_index}_type");
            let value = required_canonical_compiler_mir_fixture_field(
                fields,
                &mut consumed,
                &key,
            )?;
            params.push(parse_canonical_compiler_mir_type(value, &key)?);
        }
        let return_type_value = required_canonical_compiler_mir_fixture_field(
            fields,
            &mut consumed,
            &return_type_key,
        )?;
        imports.push(CompilerMirLoweringImportedFunction {
            name: required_canonical_compiler_mir_fixture_field(
                fields,
                &mut consumed,
                &name_key,
            )?,
            link_symbol: required_canonical_compiler_mir_fixture_field(
                fields,
                &mut consumed,
                &link_symbol_key,
            )?,
            linkage,
            params,
            return_type: parse_canonical_compiler_mir_type(
                return_type_value,
                &return_type_key,
            )?,
        });
    }

    let function_count = parse_canonical_compiler_mir_usize_field(
        fields,
        &mut consumed,
        "function_count",
    )?;
    let mut functions = Vec::with_capacity(function_count);
    for index in 0..function_count {
        let prefix = format!("function_{index}_");
        let linkage_key = format!("function_{index}_linkage");
        let linkage_value = required_canonical_compiler_mir_fixture_field(
            fields,
            &mut consumed,
            &linkage_key,
        )?;
        let linkage = match linkage_value {
            "exported_entry" => CompilerMirLoweringFunctionLinkage::ExportedEntry,
            "module_local" => CompilerMirLoweringFunctionLinkage::ModuleLocal,
            "bundle_export" => CompilerMirLoweringFunctionLinkage::BundleExport,
            other => {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "invalid canonical compiler MIR defined function linkage at {linkage_key}: {other}"
                    ),
                )
                .into());
            }
        };

        let mut function_fields: HashMap<&str, &str> = HashMap::new();
        for (&key, &value) in fields {
            let Some(stripped_key) = key.strip_prefix(&prefix) else {
                continue;
            };
            if stripped_key == "linkage" {
                continue;
            }
            consumed.insert(key);
            if function_fields.insert(stripped_key, value).is_some() {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "duplicate canonical compiler MIR function field at {key}"
                    ),
                )
                .into());
            }
        }
        if function_fields.contains_key("format") {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "canonical compiler MIR v2 function {index} must not declare a nested format"
                ),
            )
            .into());
        }
        function_fields.insert(
            "format",
            COMPILER_MIR_CANONICAL_MODULE_FUNCTION_FORMAT,
        );
        let fixture = parse_compiler_mir_fixture_field_map(
            function_fields,
            COMPILER_MIR_CANONICAL_MODULE_FUNCTION_FORMAT,
            true,
        )?;
        functions.push(CompilerMirLoweringDefinedFunction { linkage, fixture });
    }

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
                "unknown canonical compiler MIR module field(s): {}",
                unknown_fields.join(",")
            ),
        )
        .into());
    }

    Ok(CompilerMirLoweringModule {
        name,
        imports,
        functions,
    })
}


fn validate_compiler_mir_fixture(
    fixture: &ParsedCompilerMirFixture<'_>,
) -> Result<(), Box<dyn Error>> {
    validate_compiler_mir_function_fixture(fixture, false)
}

fn validate_compiler_mir_function_fixture(
    fixture: &ParsedCompilerMirFixture<'_>,
    allow_calls: bool,
) -> Result<(), Box<dyn Error>> {
    let function = &fixture.function;
    validate_canonical_compiler_mir_name(function.object_name, "function")?;
    validate_canonical_compiler_mir_name(function.symbol, "backend_symbol")?;

    if function
        .params
        .iter()
        .any(|ty| !matches!(*ty, TinyMirType::I32 | TinyMirType::Bool))
    {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            "canonical compiler MIR fixture supports only int and bool parameters",
        )
        .into());
    }
    match fixture.return_type {
        TinyMirType::I32 | TinyMirType::Bool => {
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
    let mut local_types: HashMap<&str, TinyMirType> = HashMap::new();
    for local in &function.locals {
        validate_canonical_compiler_mir_name(local.name, "local")?;
        if !matches!(local.ty, TinyMirType::I32 | TinyMirType::Bool) {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "canonical compiler MIR fixture local {} must have int or bool type",
                    local.name
                ),
            )
            .into());
        }
        if !local_names.insert(local.name)
            || local_types.insert(local.name, local.ty).is_some()
        {
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
            match statement.clone() {
                CompilerMirLoweringStatement::LocalI32Set { name, .. } => {
                    validate_canonical_compiler_mir_local_reference(
                        &local_names,
                        name,
                        block.label,
                        statement_index,
                    )?;
                    if !matches!(local_types.get(name).copied(), Some(TinyMirType::I32)) {
                        return Err(IoError::new(
                            ErrorKind::InvalidInput,
                            format!(
                                "canonical compiler MIR integer literal assignment requires int local {name} at block {} statement {statement_index}",
                                block.label
                            ),
                        )
                        .into());
                    }
                }
                CompilerMirLoweringStatement::LocalI32AddI32Literal { name, .. } => {
                    validate_canonical_compiler_mir_local_reference(
                        &local_names,
                        name,
                        block.label,
                        statement_index,
                    )?;
                    if !matches!(local_types.get(name).copied(), Some(TinyMirType::I32)) {
                        return Err(IoError::new(
                            ErrorKind::InvalidInput,
                            format!(
                                "canonical compiler MIR integer addition requires int local {name} at block {} statement {statement_index}",
                                block.label
                            ),
                        )
                        .into());
                    }
                }
                CompilerMirLoweringStatement::LocalI32SetParam { name, param } => {
                    validate_canonical_compiler_mir_local_reference(
                        &local_names,
                        name,
                        block.label,
                        statement_index,
                    )?;
                    let Some(parameter_type) = function.params.get(param).copied() else {
                        return Err(IoError::new(
                            ErrorKind::InvalidInput,
                            format!(
                                "unknown canonical compiler MIR parameter {param} at block {} statement {statement_index}",
                                block.label
                            ),
                        )
                        .into());
                    };
                    if local_types.get(name).copied() != Some(parameter_type) {
                        return Err(IoError::new(
                            ErrorKind::InvalidInput,
                            format!(
                                "canonical compiler MIR parameter assignment type mismatch for local {name} at block {} statement {statement_index}",
                                block.label
                            ),
                        )
                        .into());
                    }
                }
                CompilerMirLoweringStatement::LocalI32AddParam { name, param } => {
                    validate_canonical_compiler_mir_local_reference(
                        &local_names,
                        name,
                        block.label,
                        statement_index,
                    )?;
                    let Some(parameter_type) = function.params.get(param).copied() else {
                        return Err(IoError::new(
                            ErrorKind::InvalidInput,
                            format!(
                                "unknown canonical compiler MIR parameter {param} at block {} statement {statement_index}",
                                block.label
                            ),
                        )
                        .into());
                    };
                    if !matches!(local_types.get(name).copied(), Some(TinyMirType::I32))
                        || !matches!(parameter_type, TinyMirType::I32)
                    {
                        return Err(IoError::new(
                            ErrorKind::InvalidInput,
                            format!(
                                "canonical compiler MIR integer addition requires int local and parameter at block {} statement {statement_index}",
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
                    let block_parameter_type =
                        validate_canonical_compiler_mir_block_parameter_reference(
                            current_block_parameters,
                            &block_parameter_owners,
                            block_param,
                            block.label,
                            &format!("statement {statement_index}"),
                        )?;
                    if local_types.get(name).copied() != Some(block_parameter_type) {
                        return Err(IoError::new(
                            ErrorKind::InvalidInput,
                            format!(
                                "canonical compiler MIR block-parameter assignment type mismatch for local {name} at block {} statement {statement_index}",
                                block.label
                            ),
                        )
                        .into());
                    }
                }
                CompilerMirLoweringStatement::LocalI32SetCall {
                    name,
                    ref arguments,
                    ..
                } => {
                    if !allow_calls {
                        return Err(IoError::new(
                            ErrorKind::InvalidInput,
                            "gust.compiler_mir_ingestion.v1 remains call/import-free",
                        )
                        .into());
                    }
                    validate_canonical_compiler_mir_local_reference(
                        &local_names,
                        name,
                        block.label,
                        statement_index,
                    )?;
                    for (argument_index, argument) in arguments.iter().enumerate() {
                        validate_canonical_compiler_mir_call_argument(
                            function,
                            &local_types,
                            current_block_parameters,
                            &block_parameter_owners,
                            block.label,
                            statement_index,
                            argument_index,
                            argument,
                        )?;
                    }
                }
            }
        }

        match &block.terminator {
            CompilerMirLoweringTerminator::ReturnI32(_) => {
                if !matches!(fixture.return_type, TinyMirType::I32) {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "canonical compiler MIR non-int function cannot return an int literal at block {}",
                            block.label
                        ),
                    )
                    .into());
                }
            }
            CompilerMirLoweringTerminator::ReturnLocalI32(name) => {
                let Some(local_type) = local_types.get(name).copied() else {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "unknown canonical compiler MIR return local {name} at block {}",
                            block.label
                        ),
                    )
                    .into());
                };
                if local_type != fixture.return_type {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "canonical compiler MIR return local {name} type does not match function return type at block {}",
                            block.label
                        ),
                    )
                    .into());
                }
            }
            CompilerMirLoweringTerminator::ReturnBlockParamI32(name) => {
                if !matches!(fixture.return_type, TinyMirType::I32) {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "canonical compiler MIR non-int function cannot return int block parameter {name} at block {}",
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
                if !matches!(fixture.return_type, TinyMirType::Void) {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "canonical compiler MIR value-returning function cannot use ReturnVoid at block {}",
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
                if !matches!(local_types.get(name).copied(), Some(TinyMirType::I32)) {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "canonical compiler MIR positive branch requires int local {name} at block {}",
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
            function.locals.len(),
            &block_indices,
            &function.blocks,
            index,
        )?;
    }

    Ok(())
}

fn validate_compiler_mir_module(
    module: &CompilerMirLoweringModule<'_>,
) -> Result<(), Box<dyn Error>> {
    validate_canonical_compiler_mir_name(module.name, "module")?;
    if module.functions.is_empty() {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            "canonical compiler MIR module must define at least one function",
        )
        .into());
    }

    let mut import_names = HashMap::new();
    let mut import_link_signatures: HashMap<&str, (&[TinyMirType], TinyMirType)> =
        HashMap::new();
    for imported in &module.imports {
        validate_canonical_compiler_mir_name(imported.name, "import name")?;
        validate_canonical_compiler_mir_name(
            imported.link_symbol,
            "import link symbol",
        )?;
        if !matches!(
            imported.linkage,
            CompilerMirLoweringFunctionLinkage::ImportedHost
                | CompilerMirLoweringFunctionLinkage::ImportedBundle
        ) {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "canonical compiler MIR import {} must use imported_host or imported_bundle linkage",
                    imported.name
                ),
            )
            .into());
        }
        let import_uses_scalar_abi = imported
            .params
            .iter()
            .all(|ty| matches!(*ty, TinyMirType::I32 | TinyMirType::Bool))
            && matches!(
                imported.return_type,
                TinyMirType::I32 | TinyMirType::Bool
            );
        let imported_host_uses_int_abi = imported
            .params
            .iter()
            .all(|ty| matches!(*ty, TinyMirType::I32))
            && matches!(imported.return_type, TinyMirType::I32);
        if !import_uses_scalar_abi
            || (imported.linkage
                == CompilerMirLoweringFunctionLinkage::ImportedHost
                && !imported_host_uses_int_abi)
        {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "canonical compiler MIR import {} uses an unsupported scalar ABI",
                    imported.name
                ),
            )
            .into());
        }
        if import_names.insert(imported.name, imported).is_some() {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "duplicate canonical compiler MIR imported function name: {}",
                    imported.name
                ),
            )
            .into());
        }
        if let Some((params, return_type)) =
            import_link_signatures.get(imported.link_symbol)
        {
            if *params != imported.params.as_slice()
                || *return_type != imported.return_type
            {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "canonical compiler MIR imported link symbol {} has conflicting signatures",
                        imported.link_symbol
                    ),
                )
                .into());
            }
        } else {
            import_link_signatures.insert(
                imported.link_symbol,
                (imported.params.as_slice(), imported.return_type),
            );
        }
    }

    let mut function_names = HashMap::new();
    let mut backend_symbols: HashSet<&str> = HashSet::new();
    let mut exported_entry_count = 0usize;
    let mut bundle_export_count = 0usize;
    for defined in &module.functions {
        validate_compiler_mir_function_fixture(&defined.fixture, true)?;
        let function = &defined.fixture.function;
        if function
            .params
            .iter()
            .any(|ty| !matches!(*ty, TinyMirType::I32 | TinyMirType::Bool))
            || !matches!(
                function.return_type,
                TinyMirType::I32 | TinyMirType::Bool
            )
        {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "canonical compiler MIR defined function {} must use only int/bool parameters and one int/bool return",
                    function.object_name
                ),
            )
            .into());
        }
        if function_names.insert(function.object_name, defined).is_some() {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "duplicate canonical compiler MIR local function name: {}",
                    function.object_name
                ),
            )
            .into());
        }
        if !backend_symbols.insert(function.symbol) {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "duplicate canonical compiler MIR emitted backend symbol: {}",
                    function.symbol
                ),
            )
            .into());
        }
        if import_names.contains_key(function.object_name) {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "canonical compiler MIR import/function name collision: {}",
                    function.object_name
                ),
            )
            .into());
        }
        if import_link_signatures.contains_key(function.symbol) {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "canonical compiler MIR emitted backend symbol collides with imported link symbol: {}",
                    function.symbol
                ),
            )
            .into());
        }
        match defined.linkage {
            CompilerMirLoweringFunctionLinkage::ExportedEntry => {
                exported_entry_count += 1;
            }
            CompilerMirLoweringFunctionLinkage::BundleExport => {
                bundle_export_count += 1;
            }
            CompilerMirLoweringFunctionLinkage::ModuleLocal => {}
            CompilerMirLoweringFunctionLinkage::ImportedHost
            | CompilerMirLoweringFunctionLinkage::ImportedBundle => {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "canonical compiler MIR defined function {} cannot use imported linkage",
                        function.object_name
                    ),
                )
                .into());
            }
        }
    }
    if exported_entry_count == 0 && bundle_export_count == 0 {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            "canonical compiler MIR module must define an exported_entry or bundle_export function",
        )
        .into());
    }

    let mut local_call_edges: HashMap<&str, Vec<&str>> = module
        .functions
        .iter()
        .map(|defined| (defined.fixture.function.object_name, Vec::new()))
        .collect();

    for defined in &module.functions {
        let caller = &defined.fixture.function;
        let local_types: HashMap<&str, TinyMirType> = caller
            .locals
            .iter()
            .map(|local| (local.name, local.ty))
            .collect();
        let mut block_parameter_owners: HashMap<&str, Vec<&str>> =
            HashMap::new();
        for block in &caller.blocks {
            for parameter in &block.parameters {
                block_parameter_owners
                    .entry(parameter.name)
                    .or_default()
                    .push(block.label);
            }
        }

        for block in &caller.blocks {
            let current_block_parameters: HashMap<&str, TinyMirType> = block
                .parameters
                .iter()
                .map(|parameter| (parameter.name, parameter.ty))
                .collect();
            for (statement_index, statement) in
                block.statements.iter().enumerate()
            {
                let CompilerMirLoweringStatement::LocalI32SetCall {
                    name: result_local,
                    target,
                    arguments,
                } = statement
                else {
                    continue;
                };
                let (callee_params, callee_return_type) = match *target {
                    CompilerMirLoweringCallTarget::LocalFunction(name) => {
                        let callee =
                            function_names.get(name).copied().ok_or_else(|| {
                                IoError::new(
                                    ErrorKind::InvalidInput,
                                    format!(
                                        "unknown canonical compiler MIR local callee {name} in function {}",
                                        caller.object_name
                                    ),
                                )
                            })?;
                        local_call_edges
                            .get_mut(caller.object_name)
                            .ok_or_else(|| {
                                IoError::new(
                                    ErrorKind::InvalidInput,
                                    format!(
                                        "unknown canonical compiler MIR caller function: {}",
                                        caller.object_name
                                    ),
                                )
                            })?
                            .push(name);
                        (
                            callee.fixture.function.params.as_slice(),
                            callee.fixture.return_type,
                        )
                    }
                    CompilerMirLoweringCallTarget::ImportedFunction(name) => {
                        let callee =
                            import_names.get(name).copied().ok_or_else(|| {
                                IoError::new(
                                    ErrorKind::InvalidInput,
                                    format!(
                                        "unknown canonical compiler MIR imported callee {name} in function {}",
                                        caller.object_name
                                    ),
                                )
                            })?;
                        (callee.params.as_slice(), callee.return_type)
                    }
                };
                if arguments.len() != callee_params.len() {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "canonical compiler MIR call in function {} passes {} argument(s), but callee declares {} parameter(s)",
                            caller.object_name,
                            arguments.len(),
                            callee_params.len()
                        ),
                    )
                    .into());
                }

                for (argument_index, (argument, parameter_type)) in arguments
                    .iter()
                    .zip(callee_params.iter().copied())
                    .enumerate()
                {
                    let argument_type =
                        validate_canonical_compiler_mir_call_argument(
                            caller,
                            &local_types,
                            &current_block_parameters,
                            &block_parameter_owners,
                            block.label,
                            statement_index,
                            argument_index,
                            argument,
                        )?;
                    if argument_type != parameter_type {
                        return Err(IoError::new(
                            ErrorKind::InvalidInput,
                            format!(
                                "canonical compiler MIR call argument type mismatch in function {} at block {} statement {statement_index} argument {argument_index}",
                                caller.object_name, block.label
                            ),
                        )
                        .into());
                    }
                }

                if local_types.get(result_local).copied()
                    != Some(callee_return_type)
                {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "canonical compiler MIR call result type mismatch for local {result_local} in function {} at block {} statement {statement_index}",
                            caller.object_name, block.label
                        ),
                    )
                    .into());
                }
            }
        }
    }

    validate_canonical_compiler_mir_local_call_graph_acyclic(
        &local_call_edges,
    )
}

fn validate_canonical_compiler_mir_local_call_graph_acyclic(
    call_edges: &HashMap<&str, Vec<&str>>,
) -> Result<(), Box<dyn Error>> {
    let mut indegree: HashMap<&str, usize> =
        call_edges.keys().copied().map(|name| (name, 0)).collect();
    for targets in call_edges.values() {
        for target in targets {
            let count = indegree.get_mut(target).ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown canonical compiler MIR local call target: {target}"),
                )
            })?;
            *count += 1;
        }
    }
    let mut pending: VecDeque<&str> = indegree
        .iter()
        .filter_map(|(name, count)| (*count == 0).then_some(*name))
        .collect();
    let mut visited = 0usize;
    while let Some(name) = pending.pop_front() {
        visited += 1;
        let targets = call_edges.get(name).ok_or_else(|| {
            IoError::new(
                ErrorKind::InvalidInput,
                format!("unknown canonical compiler MIR local call source: {name}"),
            )
        })?;
        for target in targets {
            let count = indegree.get_mut(target).ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!("unknown canonical compiler MIR local call target: {target}"),
                )
            })?;
            *count -= 1;
            if *count == 0 {
                pending.push_back(target);
            }
        }
    }
    if visited != call_edges.len() {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            "canonical compiler MIR local call graph must not contain recursion or mutual recursion",
        )
        .into());
    }
    Ok(())
}

fn validate_canonical_compiler_mir_call_argument<'a>(
    function: &CompilerMirLoweringFunction<'a>,
    local_types: &HashMap<&'a str, TinyMirType>,
    current_block_parameters: &HashMap<&'a str, TinyMirType>,
    block_parameter_owners: &HashMap<&'a str, Vec<&'a str>>,
    source_block: &str,
    statement_index: usize,
    argument_index: usize,
    argument: &CompilerMirLoweringCallArgument<'a>,
) -> Result<TinyMirType, Box<dyn Error>> {
    match *argument {
        CompilerMirLoweringCallArgument::I32Literal(_) => Ok(TinyMirType::I32),
        CompilerMirLoweringCallArgument::BoolLiteral(_) => Ok(TinyMirType::Bool),
        CompilerMirLoweringCallArgument::FunctionParamI32(param) => function
            .params
            .get(param)
            .copied()
            .ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "unknown canonical compiler MIR function parameter {param} at block {source_block} statement {statement_index} call argument {argument_index}"
                    ),
                )
                .into()
            }),
        CompilerMirLoweringCallArgument::LocalI32(name) => local_types
            .get(name)
            .copied()
            .ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "unknown canonical compiler MIR local {name} at block {source_block} statement {statement_index} call argument {argument_index}"
                    ),
                )
                .into()
            }),
        CompilerMirLoweringCallArgument::BlockParamI32(name)
        | CompilerMirLoweringCallArgument::BlockParamI32AddI32Literal {
            name,
            ..
        } => validate_canonical_compiler_mir_block_parameter_reference(
            current_block_parameters,
            block_parameter_owners,
            name,
            source_block,
            &format!(
                "statement {statement_index} call argument {argument_index}"
            ),
        ),
    }
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

fn parse_canonical_compiler_mir_call_arguments<'a>(
    fields: &HashMap<&'a str, &'a str>,
    consumed: &mut HashSet<&'a str>,
    prefix: &str,
) -> Result<Vec<CompilerMirLoweringCallArgument<'a>>, Box<dyn Error>> {
    let count_key = format!("{prefix}_argument_count");
    let count = parse_canonical_compiler_mir_usize_field(
        fields,
        consumed,
        &count_key,
    )?;
    let mut arguments = Vec::with_capacity(count);
    for index in 0..count {
        let argument_prefix = format!("{prefix}_argument_{index}");
        let kind_key = format!("{argument_prefix}_kind");
        let kind = required_canonical_compiler_mir_fixture_field(
            fields,
            consumed,
            &kind_key,
        )?;
        let argument = match kind {
            "I32Literal" => {
                let value_key = format!("{argument_prefix}_value");
                CompilerMirLoweringCallArgument::I32Literal(
                    parse_canonical_compiler_mir_i32_field(
                        fields,
                        consumed,
                        &value_key,
                    )?,
                )
            }
            "BoolLiteral" => {
                let value_key = format!("{argument_prefix}_value");
                let value = parse_canonical_compiler_mir_i32_field(
                    fields,
                    consumed,
                    &value_key,
                )?;
                if !matches!(value, 0 | 1) {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "canonical compiler MIR BoolLiteral at {value_key} must be 0 or 1, got {value}"
                        ),
                    )
                    .into());
                }
                CompilerMirLoweringCallArgument::BoolLiteral(value)
            }
            "FunctionParamI32" => {
                let param_key = format!("{argument_prefix}_param");
                CompilerMirLoweringCallArgument::FunctionParamI32(
                    parse_canonical_compiler_mir_usize_field(
                        fields,
                        consumed,
                        &param_key,
                    )?,
                )
            }
            "LocalI32" => {
                let local_key = format!("{argument_prefix}_local");
                CompilerMirLoweringCallArgument::LocalI32(
                    required_canonical_compiler_mir_fixture_field(
                        fields,
                        consumed,
                        &local_key,
                    )?,
                )
            }
            "BlockParamI32" => {
                let block_param_key = format!("{argument_prefix}_block_param");
                CompilerMirLoweringCallArgument::BlockParamI32(
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
                CompilerMirLoweringCallArgument::BlockParamI32AddI32Literal {
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
                        "unsupported canonical compiler MIR call argument kind at {kind_key}: {other}"
                    ),
                )
                .into());
            }
        };
        arguments.push(argument);
    }
    Ok(arguments)
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
        "bool" => Ok(TinyMirType::Bool),
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
    local_count: usize,
    block_indices: &HashMap<&str, usize>,
    blocks: &[CompilerMirLoweringBlock<'_>],
    metadata_index: usize,
) -> Result<(), Box<dyn Error>> {
    if attachment == "function" {
        return Ok(());
    }

    if let Some(index_text) = attachment.strip_prefix("local:") {
        if let Ok(local_index) = index_text.parse::<usize>() {
            if local_index < local_count {
                return Ok(());
            }
        }
    } else if let Some(label) = attachment.strip_prefix("block:") {
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
    match parse_compiler_mir_input(&contents)? {
        ParsedCompilerMirInput::V1(fixture) => {
            validate_compiler_mir_fixture(&fixture)?;
            recognize_compiler_mir_fixture_metadata(&fixture.metadata)?;
            if is_phase11_block_parameter_loop_fixture(&fixture) {
                validate_phase11_block_parameter_loop_fixture(&fixture)?;
            }
            let counts = phase10_metadata_counts(&fixture.metadata);
            println!(
                "validated canonical compiler MIR fixture: {} -> {}",
                fixture.function.object_name, fixture.function.symbol
            );
            println!("metadata_record_count: {}", fixture.metadata.len());
            println!("resource_metadata_count: {}", counts.0);
            println!("provenance_metadata_count: {}", counts.1);
            println!("native_boundary_metadata_count: {}", counts.2);
        }
        ParsedCompilerMirInput::V2(module) => {
            validate_compiler_mir_module(&module)?;
            let mut metadata_record_count = 0usize;
            let mut resource_metadata_count = 0usize;
            let mut provenance_metadata_count = 0usize;
            let mut native_boundary_metadata_count = 0usize;
            for defined in &module.functions {
                recognize_compiler_mir_fixture_metadata(
                    &defined.fixture.metadata,
                )?;
                metadata_record_count += defined.fixture.metadata.len();
                let counts =
                    phase10_metadata_counts(&defined.fixture.metadata);
                resource_metadata_count += counts.0;
                provenance_metadata_count += counts.1;
                native_boundary_metadata_count += counts.2;
            }
            println!(
                "validated canonical compiler MIR module: {} ({} defined, {} imported)",
                module.name,
                module.functions.len(),
                module.imports.len()
            );
            println!("metadata_record_count: {metadata_record_count}");
            println!("resource_metadata_count: {resource_metadata_count}");
            println!("provenance_metadata_count: {provenance_metadata_count}");
            println!(
                "native_boundary_metadata_count: {native_boundary_metadata_count}"
            );
        }
    }
    Ok(())
}

fn emit_compiler_mir_fixture_object(
    input_path: &Path,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let contents = compiler_mir_pipeline_wrap(
        fs::read_to_string(input_path),
        CompilerMirPipelineStage::FixtureParse,
        CompilerMirPipelineFailureKind::InvalidFixture,
    )?;
    let parsed = compiler_mir_pipeline_wrap_box(
        parse_compiler_mir_input(&contents),
        CompilerMirPipelineStage::FixtureParse,
        CompilerMirPipelineFailureKind::InvalidFixture,
    )?;
    match parsed {
        ParsedCompilerMirInput::V1(fixture) => {
            compiler_mir_pipeline_wrap_box(
                validate_compiler_mir_fixture(&fixture),
                CompilerMirPipelineStage::FixtureValidation,
                CompilerMirPipelineFailureKind::InvalidFixture,
            )?;
            compiler_mir_pipeline_wrap_box(
                recognize_compiler_mir_fixture_metadata(
                    &fixture.metadata,
                ),
                CompilerMirPipelineStage::FixtureValidation,
                CompilerMirPipelineFailureKind::InvalidFixture,
            )?;
            if is_phase11_block_parameter_loop_fixture(&fixture) {
                compiler_mir_pipeline_wrap_box(
                    validate_phase11_block_parameter_loop_fixture(&fixture),
                    CompilerMirPipelineStage::FixtureValidation,
                    CompilerMirPipelineFailureKind::InvalidFixture,
                )?;
            }
            lower_compiler_mir_ingestion_function_to_object(
                output_path,
                &fixture.function,
            )
        }
        ParsedCompilerMirInput::V2(module) => {
            lower_compiler_mir_ingestion_module_to_object(output_path, &module)
        }
    }
}

fn emit_compiler_mir_fixture_contents_object(
    contents: &str,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let fixture = compiler_mir_pipeline_wrap_box(
        parse_compiler_mir_fixture(contents),
        CompilerMirPipelineStage::FixtureParse,
        CompilerMirPipelineFailureKind::InvalidFixture,
    )?;
    compiler_mir_pipeline_wrap_box(
        validate_compiler_mir_fixture(&fixture),
        CompilerMirPipelineStage::FixtureValidation,
        CompilerMirPipelineFailureKind::InvalidFixture,
    )?;
    compiler_mir_pipeline_wrap_box(
        recognize_compiler_mir_fixture_metadata(&fixture.metadata),
        CompilerMirPipelineStage::FixtureValidation,
        CompilerMirPipelineFailureKind::InvalidFixture,
    )?;
    lower_compiler_mir_ingestion_function_to_object(
        output_path,
        &fixture.function,
    )
}

fn compiler_mir_metadata_payload_field<'a>(
    payload: &'a str,
    key: &str,
) -> Option<&'a str> {
    payload.split(';').find_map(|field| {
        let (field_key, field_value) = field.split_once('=')?;
        (field_key == key).then_some(field_value)
    })
}

fn recognize_compiler_mir_fixture_metadata(
    metadata: &[CompilerMirFixtureMetadata<'_>],
) -> Result<(), Box<dyn Error>> {
    for (index, item) in metadata.iter().enumerate() {
        if !matches!(
            item.kind,
            "provenance" | "resource" | "native_boundary"
        ) {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "unknown canonical compiler MIR metadata class at metadata {index}: {}",
                    item.kind
                ),
            )
            .into());
        }
        if !matches!(
            item.policy,
            "recognized_preserved" | "ignored_with_proof"
        ) {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "unsupported canonical compiler MIR metadata policy at metadata {index}: {}",
                    item.policy
                ),
            )
            .into());
        }
        if item.payload.is_empty() {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "canonical compiler MIR metadata {index} has an empty payload"
                ),
            )
            .into());
        }

        let codegen_claim =
            compiler_mir_metadata_payload_field(item.payload, "codegen");
        if codegen_claim == Some("required") {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "canonical compiler MIR metadata {index} claims code-generation semantics the worker does not implement"
                ),
            )
            .into());
        }
        if let Some(codegen_claim) = codegen_claim {
            if !matches!(codegen_claim, "none" | "preserved") {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "canonical compiler MIR metadata {index} has an unknown codegen claim: {codegen_claim}"
                    ),
                )
                .into());
            }
        }

        if matches!(item.kind, "provenance" | "native_boundary") {
            let origin = compiler_mir_metadata_payload_field(
                item.payload,
                "origin",
            );
            if origin.is_none() || origin == Some("") {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "canonical compiler MIR metadata {index} must retain a non-empty origin"
                    ),
                )
                .into());
            }
        }

        if item.policy == "ignored_with_proof" {
            if codegen_claim != Some("none") {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "ignored canonical compiler MIR metadata {index} must declare codegen=none"
                    ),
                )
                .into());
            }
            let proof = compiler_mir_metadata_payload_field(
                item.payload,
                "proof",
            );
            if proof.is_none() || proof == Some("") {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "ignored canonical compiler MIR metadata {index} must retain a non-empty ignored_with_proof justification"
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
    emit_compiler_mir_fixture_contents_object(
        PHASE9E_CANONICAL_BLOCK_PARAM_UPDATE_BRANCH_FIXTURE,
        output_path,
    )
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
    let module = build_compiler_mir_block_param_local_call_branch_module();
    lower_compiler_mir_ingestion_module_to_object(output_path, &module)
}

fn build_compiler_mir_block_param_local_call_branch_module(
) -> CompilerMirLoweringModule<'static> {
    CompilerMirLoweringModule {
        name: "gust_native_backend_compiler_mir_ingested_block_param_local_call_branch",
        imports: Vec::new(),
        functions: vec![
            CompilerMirLoweringDefinedFunction {
                linkage: CompilerMirLoweringFunctionLinkage::ExportedEntry,
                fixture: ParsedCompilerMirFixture {
                    function: CompilerMirLoweringFunction {
                        object_name: "tiny_block_param_local_call_branch",
                        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_CALL_BRANCH_SYMBOL,
                        return_type: TinyMirType::I32,
                        params: vec![TinyMirType::I32],
                        locals: vec![CompilerMirLoweringLocal {
                            name: "called",
                            ty: TinyMirType::I32,
                        }],
                        entry_block: "entry",
                        blocks: vec![
                            CompilerMirLoweringBlock {
                                label: "entry",
                                parameters: Vec::new(),
                                statements: Vec::new(),
                                terminator: CompilerMirLoweringTerminator::Jump {
                                    edge: CompilerMirLoweringEdge {
                                        target: "branch",
                                        arguments: vec![
                                            CompilerMirLoweringEdgeArgument::FunctionParamI32(0),
                                        ],
                                    },
                                },
                            },
                            CompilerMirLoweringBlock {
                                label: "branch",
                                parameters: vec![CompilerMirLoweringBlockParameter {
                                    name: "input",
                                    ty: TinyMirType::I32,
                                }],
                                statements: vec![
                                    CompilerMirLoweringStatement::LocalI32SetCall {
                                        name: "called",
                                        target: CompilerMirLoweringCallTarget::LocalFunction(
                                            "tiny_block_param_local_call_helper",
                                        ),
                                        arguments: vec![
                                            CompilerMirLoweringCallArgument::BlockParamI32(
                                                "input",
                                            ),
                                        ],
                                    },
                                ],
                                terminator:
                                    CompilerMirLoweringTerminator::BranchLocalI32Positive {
                                        name: "called",
                                        then_edge: CompilerMirLoweringEdge {
                                            target: "positive",
                                            arguments: Vec::new(),
                                        },
                                        else_edge: CompilerMirLoweringEdge {
                                            target: "non_positive",
                                            arguments: Vec::new(),
                                        },
                                    },
                            },
                            CompilerMirLoweringBlock {
                                label: "positive",
                                parameters: Vec::new(),
                                statements: Vec::new(),
                                terminator: CompilerMirLoweringTerminator::ReturnI32(79),
                            },
                            CompilerMirLoweringBlock {
                                label: "non_positive",
                                parameters: Vec::new(),
                                statements: Vec::new(),
                                terminator: CompilerMirLoweringTerminator::ReturnI32(83),
                            },
                        ],
                    },
                    return_type: TinyMirType::I32,
                    metadata: Vec::new(),
                    expected_exit: 0,
                },
            },
            CompilerMirLoweringDefinedFunction {
                linkage: CompilerMirLoweringFunctionLinkage::ModuleLocal,
                fixture: ParsedCompilerMirFixture {
                    function: CompilerMirLoweringFunction {
                        object_name: "tiny_block_param_local_call_helper",
                        symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_LOCAL_CALL_HELPER_SYMBOL,
                        return_type: TinyMirType::I32,
                        params: vec![TinyMirType::I32],
                        locals: vec![CompilerMirLoweringLocal {
                            name: "result",
                            ty: TinyMirType::I32,
                        }],
                        entry_block: "entry",
                        blocks: vec![CompilerMirLoweringBlock {
                            label: "entry",
                            parameters: Vec::new(),
                            statements: vec![
                                CompilerMirLoweringStatement::LocalI32SetParam {
                                    name: "result",
                                    param: 0,
                                },
                                CompilerMirLoweringStatement::LocalI32AddI32Literal {
                                    name: "result",
                                    value: 1,
                                },
                            ],
                            terminator: CompilerMirLoweringTerminator::ReturnLocalI32(
                                "result",
                            ),
                        }],
                    },
                    return_type: TinyMirType::I32,
                    metadata: Vec::new(),
                    expected_exit: 0,
                },
            },
        ],
    }
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
    let module = build_compiler_mir_block_param_imported_call_branch_module();
    lower_compiler_mir_ingestion_module_to_object(output_path, &module)
}

fn build_compiler_mir_block_param_imported_call_branch_module(
) -> CompilerMirLoweringModule<'static> {
    CompilerMirLoweringModule {
        name: "gust_native_backend_compiler_mir_ingested_block_param_imported_call_branch",
        imports: vec![CompilerMirLoweringImportedFunction {
            name: "host_add",
            link_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_HOST_ADD_SYMBOL,
            linkage: CompilerMirLoweringFunctionLinkage::ImportedHost,
            params: vec![TinyMirType::I32, TinyMirType::I32],
            return_type: TinyMirType::I32,
        }],
        functions: vec![CompilerMirLoweringDefinedFunction {
            linkage: CompilerMirLoweringFunctionLinkage::ExportedEntry,
            fixture: ParsedCompilerMirFixture {
                function: CompilerMirLoweringFunction {
                    object_name: "tiny_block_param_imported_call_branch",
                    symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_BRANCH_SYMBOL,
                    return_type: TinyMirType::I32,
                    params: vec![TinyMirType::I32],
                    locals: vec![CompilerMirLoweringLocal {
                        name: "called",
                        ty: TinyMirType::I32,
                    }],
                    entry_block: "entry",
                    blocks: vec![
                        CompilerMirLoweringBlock {
                            label: "entry",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "branch",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::FunctionParamI32(0),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "branch",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "input",
                                ty: TinyMirType::I32,
                            }],
                            statements: vec![
                                CompilerMirLoweringStatement::LocalI32SetCall {
                                    name: "called",
                                    target:
                                        CompilerMirLoweringCallTarget::ImportedFunction(
                                            "host_add",
                                        ),
                                    arguments: vec![
                                        CompilerMirLoweringCallArgument::BlockParamI32(
                                            "input",
                                        ),
                                        CompilerMirLoweringCallArgument::I32Literal(-3),
                                    ],
                                },
                            ],
                            terminator:
                                CompilerMirLoweringTerminator::BranchLocalI32Positive {
                                    name: "called",
                                    then_edge: CompilerMirLoweringEdge {
                                        target: "positive",
                                        arguments: Vec::new(),
                                    },
                                    else_edge: CompilerMirLoweringEdge {
                                        target: "non_positive",
                                        arguments: Vec::new(),
                                    },
                                },
                        },
                        CompilerMirLoweringBlock {
                            label: "positive",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::ReturnI32(89),
                        },
                        CompilerMirLoweringBlock {
                            label: "non_positive",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::ReturnI32(97),
                        },
                    ],
                },
                return_type: TinyMirType::I32,
                metadata: Vec::new(),
                expected_exit: 0,
            },
        }],
    }
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
    let module = build_compiler_mir_block_param_imported_call_return_module();
    lower_compiler_mir_ingestion_module_to_object(output_path, &module)
}

fn build_compiler_mir_block_param_imported_call_return_module(
) -> CompilerMirLoweringModule<'static> {
    CompilerMirLoweringModule {
        name: "gust_native_backend_compiler_mir_ingested_block_param_imported_call_return",
        imports: vec![CompilerMirLoweringImportedFunction {
            name: "host_add",
            link_symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
            linkage: CompilerMirLoweringFunctionLinkage::ImportedHost,
            params: vec![TinyMirType::I32, TinyMirType::I32],
            return_type: TinyMirType::I32,
        }],
        functions: vec![CompilerMirLoweringDefinedFunction {
            linkage: CompilerMirLoweringFunctionLinkage::ExportedEntry,
            fixture: ParsedCompilerMirFixture {
                function: CompilerMirLoweringFunction {
                    object_name: "tiny_block_param_imported_call_return",
                    symbol: COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_CALL_RETURN_SYMBOL,
                    return_type: TinyMirType::I32,
                    params: vec![TinyMirType::I32],
                    locals: vec![CompilerMirLoweringLocal {
                        name: "called",
                        ty: TinyMirType::I32,
                    }],
                    entry_block: "entry",
                    blocks: vec![
                        CompilerMirLoweringBlock {
                            label: "entry",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "return_imported",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::FunctionParamI32(0),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "return_imported",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "input",
                                ty: TinyMirType::I32,
                            }],
                            statements: vec![
                                CompilerMirLoweringStatement::LocalI32SetCall {
                                    name: "called",
                                    target:
                                        CompilerMirLoweringCallTarget::ImportedFunction(
                                            "host_add",
                                        ),
                                    arguments: vec![
                                        CompilerMirLoweringCallArgument::BlockParamI32(
                                            "input",
                                        ),
                                        CompilerMirLoweringCallArgument::I32Literal(11),
                                    ],
                                },
                            ],
                            terminator:
                                CompilerMirLoweringTerminator::ReturnLocalI32("called"),
                        },
                    ],
                },
                return_type: TinyMirType::I32,
                metadata: Vec::new(),
                expected_exit: 0,
            },
        }],
    }
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
    let module =
        build_compiler_mir_block_param_imported_predicate_update_branch_module();
    lower_compiler_mir_ingestion_module_to_object(output_path, &module)
}

fn build_compiler_mir_block_param_imported_predicate_update_branch_module(
) -> CompilerMirLoweringModule<'static> {
    CompilerMirLoweringModule {
        name: "gust_native_backend_compiler_mir_ingested_block_param_imported_predicate_update_branch",
        imports: vec![CompilerMirLoweringImportedFunction {
            name: "host_is_positive",
            link_symbol:
                COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_PREDICATE_HOST_IS_POSITIVE_SYMBOL,
            linkage: CompilerMirLoweringFunctionLinkage::ImportedHost,
            params: vec![TinyMirType::I32],
            return_type: TinyMirType::I32,
        }],
        functions: vec![CompilerMirLoweringDefinedFunction {
            linkage: CompilerMirLoweringFunctionLinkage::ExportedEntry,
            fixture: ParsedCompilerMirFixture {
                function: CompilerMirLoweringFunction {
                    object_name: "tiny_block_param_imported_predicate_update_branch",
                    symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_PREDICATE_UPDATE_BRANCH_SYMBOL,
                    return_type: TinyMirType::I32,
                    params: vec![TinyMirType::I32],
                    locals: vec![CompilerMirLoweringLocal {
                        name: "predicate_result",
                        ty: TinyMirType::I32,
                    }],
                    entry_block: "entry",
                    blocks: vec![
                        CompilerMirLoweringBlock {
                            label: "entry",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "adjust",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::FunctionParamI32(0),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "adjust",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "input",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "predicate",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::BlockParamI32AddI32Literal {
                                            name: "input",
                                            value: -4,
                                        },
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "predicate",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "adjusted",
                                ty: TinyMirType::I32,
                            }],
                            statements: vec![
                                CompilerMirLoweringStatement::LocalI32SetCall {
                                    name: "predicate_result",
                                    target:
                                        CompilerMirLoweringCallTarget::ImportedFunction(
                                            "host_is_positive",
                                        ),
                                    arguments: vec![
                                        CompilerMirLoweringCallArgument::BlockParamI32(
                                            "adjusted",
                                        ),
                                    ],
                                },
                            ],
                            terminator:
                                CompilerMirLoweringTerminator::BranchLocalI32Positive {
                                    name: "predicate_result",
                                    then_edge: CompilerMirLoweringEdge {
                                        target: "positive",
                                        arguments: Vec::new(),
                                    },
                                    else_edge: CompilerMirLoweringEdge {
                                        target: "non_positive",
                                        arguments: Vec::new(),
                                    },
                                },
                        },
                        CompilerMirLoweringBlock {
                            label: "positive",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::ReturnI32(101),
                        },
                        CompilerMirLoweringBlock {
                            label: "non_positive",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::ReturnI32(107),
                        },
                    ],
                },
                return_type: TinyMirType::I32,
                metadata: Vec::new(),
                expected_exit: 0,
            },
        }],
    }
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
    emit_compiler_mir_fixture_contents_object(
        PHASE9E_CANONICAL_BLOCK_PARAM_MERGE_UPDATE_BRANCH_FIXTURE,
        output_path,
    )
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
    let module = build_compiler_mir_block_param_merge_imported_call_return_module();
    lower_compiler_mir_ingestion_module_to_object(output_path, &module)
}

fn build_compiler_mir_block_param_merge_imported_call_return_module(
) -> CompilerMirLoweringModule<'static> {
    CompilerMirLoweringModule {
        name: "gust_native_backend_compiler_mir_ingested_block_param_merge_imported_call_return",
        imports: vec![CompilerMirLoweringImportedFunction {
            name: "host_add",
            link_symbol:
                COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
            linkage: CompilerMirLoweringFunctionLinkage::ImportedHost,
            params: vec![TinyMirType::I32, TinyMirType::I32],
            return_type: TinyMirType::I32,
        }],
        functions: vec![CompilerMirLoweringDefinedFunction {
            linkage: CompilerMirLoweringFunctionLinkage::ExportedEntry,
            fixture: ParsedCompilerMirFixture {
                function: CompilerMirLoweringFunction {
                    object_name: "tiny_block_param_merge_imported_call_return",
                    symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_CALL_RETURN_SYMBOL,
                    return_type: TinyMirType::I32,
                    params: vec![TinyMirType::I32],
                    locals: vec![CompilerMirLoweringLocal {
                        name: "returned",
                        ty: TinyMirType::I32,
                    }],
                    entry_block: "entry",
                    blocks: vec![
                        CompilerMirLoweringBlock {
                            label: "entry",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "adjust",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::FunctionParamI32(0),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "adjust",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "input",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "branch",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::BlockParamI32AddI32Literal {
                                            name: "input",
                                            value: 4,
                                        },
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "branch",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "adjusted",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator:
                                CompilerMirLoweringTerminator::BranchBlockParamI32Positive {
                                    name: "adjusted",
                                    then_edge: CompilerMirLoweringEdge {
                                        target: "then_value",
                                        arguments: vec![
                                            CompilerMirLoweringEdgeArgument::I32Literal(211),
                                        ],
                                    },
                                    else_edge: CompilerMirLoweringEdge {
                                        target: "else_value",
                                        arguments: vec![
                                            CompilerMirLoweringEdgeArgument::I32Literal(223),
                                        ],
                                    },
                                },
                        },
                        CompilerMirLoweringBlock {
                            label: "then_value",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "selected",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "join",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::BlockParamI32(
                                            "selected",
                                        ),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "else_value",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "selected",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "join",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::BlockParamI32(
                                            "selected",
                                        ),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "join",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "merged",
                                ty: TinyMirType::I32,
                            }],
                            statements: vec![
                                CompilerMirLoweringStatement::LocalI32SetCall {
                                    name: "returned",
                                    target:
                                        CompilerMirLoweringCallTarget::ImportedFunction(
                                            "host_add",
                                        ),
                                    arguments: vec![
                                        CompilerMirLoweringCallArgument::BlockParamI32(
                                            "merged",
                                        ),
                                        CompilerMirLoweringCallArgument::I32Literal(5),
                                    ],
                                },
                            ],
                            terminator:
                                CompilerMirLoweringTerminator::ReturnLocalI32("returned"),
                        },
                    ],
                },
                return_type: TinyMirType::I32,
                metadata: Vec::new(),
                expected_exit: 0,
            },
        }],
    }
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
    let module =
        build_compiler_mir_block_param_merge_arm_update_imported_call_return_module();
    lower_compiler_mir_ingestion_module_to_object(output_path, &module)
}

fn build_compiler_mir_block_param_merge_arm_update_imported_call_return_module(
) -> CompilerMirLoweringModule<'static> {
    CompilerMirLoweringModule {
        name: "gust_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_return",
        imports: vec![CompilerMirLoweringImportedFunction {
            name: "host_add",
            link_symbol:
                COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_HOST_ADD_SYMBOL,
            linkage: CompilerMirLoweringFunctionLinkage::ImportedHost,
            params: vec![TinyMirType::I32, TinyMirType::I32],
            return_type: TinyMirType::I32,
        }],
        functions: vec![CompilerMirLoweringDefinedFunction {
            linkage: CompilerMirLoweringFunctionLinkage::ExportedEntry,
            fixture: ParsedCompilerMirFixture {
                function: CompilerMirLoweringFunction {
                    object_name:
                        "tiny_block_param_merge_arm_update_imported_call_return",
                    symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_RETURN_SYMBOL,
                    return_type: TinyMirType::I32,
                    params: vec![TinyMirType::I32],
                    locals: vec![
                        CompilerMirLoweringLocal {
                            name: "then_value",
                            ty: TinyMirType::I32,
                        },
                        CompilerMirLoweringLocal {
                            name: "else_value",
                            ty: TinyMirType::I32,
                        },
                        CompilerMirLoweringLocal {
                            name: "returned",
                            ty: TinyMirType::I32,
                        },
                    ],
                    entry_block: "entry",
                    blocks: vec![
                        CompilerMirLoweringBlock {
                            label: "entry",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "adjust",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::FunctionParamI32(0),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "adjust",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "input",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "branch",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::BlockParamI32AddI32Literal {
                                            name: "input",
                                            value: 4,
                                        },
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "branch",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "adjusted",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator:
                                CompilerMirLoweringTerminator::BranchBlockParamI32Positive {
                                    name: "adjusted",
                                    then_edge: CompilerMirLoweringEdge {
                                        target: "then_value",
                                        arguments: vec![
                                            CompilerMirLoweringEdgeArgument::I32Literal(211),
                                        ],
                                    },
                                    else_edge: CompilerMirLoweringEdge {
                                        target: "else_value",
                                        arguments: vec![
                                            CompilerMirLoweringEdgeArgument::I32Literal(223),
                                        ],
                                    },
                                },
                        },
                        CompilerMirLoweringBlock {
                            label: "then_value",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "selected",
                                ty: TinyMirType::I32,
                            }],
                            statements: vec![
                                CompilerMirLoweringStatement::LocalI32SetCall {
                                    name: "then_value",
                                    target:
                                        CompilerMirLoweringCallTarget::ImportedFunction(
                                            "host_add",
                                        ),
                                    arguments: vec![
                                        CompilerMirLoweringCallArgument::BlockParamI32(
                                            "selected",
                                        ),
                                        CompilerMirLoweringCallArgument::I32Literal(5),
                                    ],
                                },
                                CompilerMirLoweringStatement::LocalI32AddI32Literal {
                                    name: "then_value",
                                    value: 2,
                                },
                            ],
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "join",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::LocalI32(
                                            "then_value",
                                        ),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "else_value",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "selected",
                                ty: TinyMirType::I32,
                            }],
                            statements: vec![
                                CompilerMirLoweringStatement::LocalI32SetCall {
                                    name: "else_value",
                                    target:
                                        CompilerMirLoweringCallTarget::ImportedFunction(
                                            "host_add",
                                        ),
                                    arguments: vec![
                                        CompilerMirLoweringCallArgument::BlockParamI32(
                                            "selected",
                                        ),
                                        CompilerMirLoweringCallArgument::I32Literal(5),
                                    ],
                                },
                                CompilerMirLoweringStatement::LocalI32AddI32Literal {
                                    name: "else_value",
                                    value: 4,
                                },
                            ],
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "join",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::LocalI32(
                                            "else_value",
                                        ),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "join",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "merged",
                                ty: TinyMirType::I32,
                            }],
                            statements: vec![
                                CompilerMirLoweringStatement::LocalI32SetCall {
                                    name: "returned",
                                    target:
                                        CompilerMirLoweringCallTarget::ImportedFunction(
                                            "host_add",
                                        ),
                                    arguments: vec![
                                        CompilerMirLoweringCallArgument::BlockParamI32(
                                            "merged",
                                        ),
                                        CompilerMirLoweringCallArgument::I32Literal(5),
                                    ],
                                },
                            ],
                            terminator:
                                CompilerMirLoweringTerminator::ReturnLocalI32("returned"),
                        },
                    ],
                },
                return_type: TinyMirType::I32,
                metadata: Vec::new(),
                expected_exit: 0,
            },
        }],
    }
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
    let module =
        build_compiler_mir_block_param_merge_arm_update_imported_call_branch_module();
    lower_compiler_mir_ingestion_module_to_object(output_path, &module)
}

fn build_compiler_mir_block_param_merge_arm_update_imported_call_branch_module(
) -> CompilerMirLoweringModule<'static> {
    CompilerMirLoweringModule {
        name: "gust_native_backend_compiler_mir_ingested_block_param_merge_arm_update_imported_call_branch",
        imports: vec![CompilerMirLoweringImportedFunction {
            name: "host_add",
            link_symbol:
                COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_HOST_ADD_SYMBOL,
            linkage: CompilerMirLoweringFunctionLinkage::ImportedHost,
            params: vec![TinyMirType::I32, TinyMirType::I32],
            return_type: TinyMirType::I32,
        }],
        functions: vec![CompilerMirLoweringDefinedFunction {
            linkage: CompilerMirLoweringFunctionLinkage::ExportedEntry,
            fixture: ParsedCompilerMirFixture {
                function: CompilerMirLoweringFunction {
                    object_name:
                        "tiny_block_param_merge_arm_update_imported_call_branch",
                    symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_ARM_UPDATE_IMPORTED_CALL_BRANCH_SYMBOL,
                    return_type: TinyMirType::I32,
                    params: vec![TinyMirType::I32],
                    locals: vec![
                        CompilerMirLoweringLocal {
                            name: "then_value",
                            ty: TinyMirType::I32,
                        },
                        CompilerMirLoweringLocal {
                            name: "else_value",
                            ty: TinyMirType::I32,
                        },
                        CompilerMirLoweringLocal {
                            name: "predicate_result",
                            ty: TinyMirType::I32,
                        },
                    ],
                    entry_block: "entry",
                    blocks: vec![
                        CompilerMirLoweringBlock {
                            label: "entry",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "adjust",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::FunctionParamI32(0),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "adjust",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "input",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "branch",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::BlockParamI32AddI32Literal {
                                            name: "input",
                                            value: 4,
                                        },
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "branch",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "adjusted",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator:
                                CompilerMirLoweringTerminator::BranchBlockParamI32Positive {
                                    name: "adjusted",
                                    then_edge: CompilerMirLoweringEdge {
                                        target: "then_value",
                                        arguments: vec![
                                            CompilerMirLoweringEdgeArgument::I32Literal(211),
                                        ],
                                    },
                                    else_edge: CompilerMirLoweringEdge {
                                        target: "else_value",
                                        arguments: vec![
                                            CompilerMirLoweringEdgeArgument::I32Literal(223),
                                        ],
                                    },
                                },
                        },
                        CompilerMirLoweringBlock {
                            label: "then_value",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "selected",
                                ty: TinyMirType::I32,
                            }],
                            statements: vec![
                                CompilerMirLoweringStatement::LocalI32SetCall {
                                    name: "then_value",
                                    target:
                                        CompilerMirLoweringCallTarget::ImportedFunction(
                                            "host_add",
                                        ),
                                    arguments: vec![
                                        CompilerMirLoweringCallArgument::BlockParamI32(
                                            "selected",
                                        ),
                                        CompilerMirLoweringCallArgument::I32Literal(5),
                                    ],
                                },
                                CompilerMirLoweringStatement::LocalI32AddI32Literal {
                                    name: "then_value",
                                    value: 2,
                                },
                            ],
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "join",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::LocalI32(
                                            "then_value",
                                        ),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "else_value",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "selected",
                                ty: TinyMirType::I32,
                            }],
                            statements: vec![
                                CompilerMirLoweringStatement::LocalI32SetBlockParam {
                                    name: "else_value",
                                    block_param: "selected",
                                },
                                CompilerMirLoweringStatement::LocalI32AddI32Literal {
                                    name: "else_value",
                                    value: 9,
                                },
                            ],
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "join",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::LocalI32(
                                            "else_value",
                                        ),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "join",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "merged",
                                ty: TinyMirType::I32,
                            }],
                            statements: vec![
                                CompilerMirLoweringStatement::LocalI32SetCall {
                                    name: "predicate_result",
                                    target:
                                        CompilerMirLoweringCallTarget::ImportedFunction(
                                            "host_add",
                                        ),
                                    arguments: vec![
                                        CompilerMirLoweringCallArgument::BlockParamI32(
                                            "merged",
                                        ),
                                        CompilerMirLoweringCallArgument::I32Literal(-220),
                                    ],
                                },
                            ],
                            terminator:
                                CompilerMirLoweringTerminator::BranchLocalI32Positive {
                                    name: "predicate_result",
                                    then_edge: CompilerMirLoweringEdge {
                                        target: "positive",
                                        arguments: Vec::new(),
                                    },
                                    else_edge: CompilerMirLoweringEdge {
                                        target: "non_positive",
                                        arguments: Vec::new(),
                                    },
                                },
                        },
                        CompilerMirLoweringBlock {
                            label: "positive",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::ReturnI32(241),
                        },
                        CompilerMirLoweringBlock {
                            label: "non_positive",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::ReturnI32(251),
                        },
                    ],
                },
                return_type: TinyMirType::I32,
                metadata: Vec::new(),
                expected_exit: 0,
            },
        }],
    }
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
    let module =
        build_compiler_mir_block_param_merge_imported_branch_joined_return_module();
    lower_compiler_mir_ingestion_module_to_object(output_path, &module)
}

fn build_compiler_mir_block_param_merge_imported_branch_joined_return_module(
) -> CompilerMirLoweringModule<'static> {
    CompilerMirLoweringModule {
        name: "gust_native_backend_compiler_mir_ingested_block_param_merge_imported_branch_joined_return",
        imports: vec![CompilerMirLoweringImportedFunction {
            name: "host_add",
            link_symbol:
                COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_HOST_ADD_SYMBOL,
            linkage: CompilerMirLoweringFunctionLinkage::ImportedHost,
            params: vec![TinyMirType::I32, TinyMirType::I32],
            return_type: TinyMirType::I32,
        }],
        functions: vec![CompilerMirLoweringDefinedFunction {
            linkage: CompilerMirLoweringFunctionLinkage::ExportedEntry,
            fixture: ParsedCompilerMirFixture {
                function: CompilerMirLoweringFunction {
                    object_name:
                        "tiny_block_param_merge_imported_branch_joined_return",
                    symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_IMPORTED_BRANCH_JOINED_RETURN_SYMBOL,
                    return_type: TinyMirType::I32,
                    params: vec![TinyMirType::I32],
                    locals: vec![
                        CompilerMirLoweringLocal {
                            name: "predicate_result",
                            ty: TinyMirType::I32,
                        },
                        CompilerMirLoweringLocal {
                            name: "returned",
                            ty: TinyMirType::I32,
                        },
                    ],
                    entry_block: "entry",
                    blocks: vec![
                        CompilerMirLoweringBlock {
                            label: "entry",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "adjust",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::FunctionParamI32(0),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "adjust",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "input",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "branch",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::BlockParamI32AddI32Literal {
                                            name: "input",
                                            value: 4,
                                        },
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "branch",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "adjusted",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator:
                                CompilerMirLoweringTerminator::BranchBlockParamI32Positive {
                                    name: "adjusted",
                                    then_edge: CompilerMirLoweringEdge {
                                        target: "then_value",
                                        arguments: vec![
                                            CompilerMirLoweringEdgeArgument::I32Literal(211),
                                        ],
                                    },
                                    else_edge: CompilerMirLoweringEdge {
                                        target: "else_value",
                                        arguments: vec![
                                            CompilerMirLoweringEdgeArgument::I32Literal(223),
                                        ],
                                    },
                                },
                        },
                        CompilerMirLoweringBlock {
                            label: "then_value",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "selected",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "join",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::BlockParamI32AddI32Literal {
                                            name: "selected",
                                            value: 7,
                                        },
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "else_value",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "selected",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "join",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::BlockParamI32AddI32Literal {
                                            name: "selected",
                                            value: 9,
                                        },
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "join",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "merged",
                                ty: TinyMirType::I32,
                            }],
                            statements: vec![
                                CompilerMirLoweringStatement::LocalI32SetCall {
                                    name: "predicate_result",
                                    target:
                                        CompilerMirLoweringCallTarget::ImportedFunction(
                                            "host_add",
                                        ),
                                    arguments: vec![
                                        CompilerMirLoweringCallArgument::BlockParamI32(
                                            "merged",
                                        ),
                                        CompilerMirLoweringCallArgument::I32Literal(-220),
                                    ],
                                },
                            ],
                            terminator:
                                CompilerMirLoweringTerminator::BranchLocalI32Positive {
                                    name: "predicate_result",
                                    then_edge: CompilerMirLoweringEdge {
                                        target: "positive_value",
                                        arguments: Vec::new(),
                                    },
                                    else_edge: CompilerMirLoweringEdge {
                                        target: "non_positive_value",
                                        arguments: Vec::new(),
                                    },
                                },
                        },
                        CompilerMirLoweringBlock {
                            label: "positive_value",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "return_join",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::I32Literal(241),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "non_positive_value",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "return_join",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::I32Literal(251),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "return_join",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "joined",
                                ty: TinyMirType::I32,
                            }],
                            statements: vec![
                                CompilerMirLoweringStatement::LocalI32SetCall {
                                    name: "returned",
                                    target:
                                        CompilerMirLoweringCallTarget::ImportedFunction(
                                            "host_add",
                                        ),
                                    arguments: vec![
                                        CompilerMirLoweringCallArgument::BlockParamI32(
                                            "joined",
                                        ),
                                        CompilerMirLoweringCallArgument::I32Literal(3),
                                    ],
                                },
                            ],
                            terminator:
                                CompilerMirLoweringTerminator::ReturnLocalI32("returned"),
                        },
                    ],
                },
                return_type: TinyMirType::I32,
                metadata: Vec::new(),
                expected_exit: 0,
            },
        }],
    }
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
    let module =
        build_compiler_mir_block_param_merge_dual_imported_joined_return_module();
    lower_compiler_mir_ingestion_module_to_object(output_path, &module)
}

fn build_compiler_mir_block_param_merge_dual_imported_joined_return_module(
) -> CompilerMirLoweringModule<'static> {
    CompilerMirLoweringModule {
        name: "gust_native_backend_compiler_mir_ingested_block_param_merge_dual_imported_joined_return",
        imports: vec![
            CompilerMirLoweringImportedFunction {
                name: "branch_host_add",
                link_symbol:
                    COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_BRANCH_HOST_ADD_SYMBOL,
                linkage: CompilerMirLoweringFunctionLinkage::ImportedHost,
                params: vec![TinyMirType::I32, TinyMirType::I32],
                return_type: TinyMirType::I32,
            },
            CompilerMirLoweringImportedFunction {
                name: "return_host_add",
                link_symbol:
                    COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_RETURN_HOST_ADD_SYMBOL,
                linkage: CompilerMirLoweringFunctionLinkage::ImportedHost,
                params: vec![TinyMirType::I32, TinyMirType::I32],
                return_type: TinyMirType::I32,
            },
        ],
        functions: vec![CompilerMirLoweringDefinedFunction {
            linkage: CompilerMirLoweringFunctionLinkage::ExportedEntry,
            fixture: ParsedCompilerMirFixture {
                function: CompilerMirLoweringFunction {
                    object_name:
                        "tiny_block_param_merge_dual_imported_joined_return",
                    symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_MERGE_DUAL_IMPORTED_JOINED_RETURN_SYMBOL,
                    return_type: TinyMirType::I32,
                    params: vec![TinyMirType::I32],
                    locals: vec![
                        CompilerMirLoweringLocal {
                            name: "predicate_result",
                            ty: TinyMirType::I32,
                        },
                        CompilerMirLoweringLocal {
                            name: "returned",
                            ty: TinyMirType::I32,
                        },
                    ],
                    entry_block: "entry",
                    blocks: vec![
                        CompilerMirLoweringBlock {
                            label: "entry",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "adjust",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::FunctionParamI32(0),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "adjust",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "input",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "branch",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::BlockParamI32AddI32Literal {
                                            name: "input",
                                            value: 4,
                                        },
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "branch",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "adjusted",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator:
                                CompilerMirLoweringTerminator::BranchBlockParamI32Positive {
                                    name: "adjusted",
                                    then_edge: CompilerMirLoweringEdge {
                                        target: "then_value",
                                        arguments: vec![
                                            CompilerMirLoweringEdgeArgument::I32Literal(211),
                                        ],
                                    },
                                    else_edge: CompilerMirLoweringEdge {
                                        target: "else_value",
                                        arguments: vec![
                                            CompilerMirLoweringEdgeArgument::I32Literal(223),
                                        ],
                                    },
                                },
                        },
                        CompilerMirLoweringBlock {
                            label: "then_value",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "selected",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "join",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::BlockParamI32AddI32Literal {
                                            name: "selected",
                                            value: 7,
                                        },
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "else_value",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "selected",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "join",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::BlockParamI32AddI32Literal {
                                            name: "selected",
                                            value: 9,
                                        },
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "join",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "merged",
                                ty: TinyMirType::I32,
                            }],
                            statements: vec![
                                CompilerMirLoweringStatement::LocalI32SetCall {
                                    name: "predicate_result",
                                    target:
                                        CompilerMirLoweringCallTarget::ImportedFunction(
                                            "branch_host_add",
                                        ),
                                    arguments: vec![
                                        CompilerMirLoweringCallArgument::BlockParamI32(
                                            "merged",
                                        ),
                                        CompilerMirLoweringCallArgument::I32Literal(-220),
                                    ],
                                },
                            ],
                            terminator:
                                CompilerMirLoweringTerminator::BranchLocalI32Positive {
                                    name: "predicate_result",
                                    then_edge: CompilerMirLoweringEdge {
                                        target: "positive_value",
                                        arguments: Vec::new(),
                                    },
                                    else_edge: CompilerMirLoweringEdge {
                                        target: "non_positive_value",
                                        arguments: Vec::new(),
                                    },
                                },
                        },
                        CompilerMirLoweringBlock {
                            label: "positive_value",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "return_join",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::I32Literal(241),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "non_positive_value",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "return_join",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::I32Literal(251),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "return_join",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "joined",
                                ty: TinyMirType::I32,
                            }],
                            statements: vec![
                                CompilerMirLoweringStatement::LocalI32SetCall {
                                    name: "returned",
                                    target:
                                        CompilerMirLoweringCallTarget::ImportedFunction(
                                            "return_host_add",
                                        ),
                                    arguments: vec![
                                        CompilerMirLoweringCallArgument::BlockParamI32(
                                            "joined",
                                        ),
                                        CompilerMirLoweringCallArgument::I32Literal(4),
                                    ],
                                },
                            ],
                            terminator:
                                CompilerMirLoweringTerminator::ReturnLocalI32("returned"),
                        },
                    ],
                },
                return_type: TinyMirType::I32,
                metadata: Vec::new(),
                expected_exit: 0,
            },
        }],
    }
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
    emit_compiler_mir_fixture_contents_object(
        PHASE9E_CANONICAL_BLOCK_PARAM_QUINT_MATERIALIZE_RETURN_FIXTURE,
        output_path,
    )
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
    emit_compiler_mir_fixture_contents_object(
        PHASE9E_CANONICAL_BLOCK_PARAM_QUAD_MATERIALIZE_RETURN_FIXTURE,
        output_path,
    )
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
    emit_compiler_mir_fixture_contents_object(
        PHASE9E_CANONICAL_BLOCK_PARAM_TRIPLE_MATERIALIZE_RETURN_FIXTURE,
        output_path,
    )
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
    parse_compiler_mir_block_param_local_first_dual_materialize_return_ingestion_fixture(&contents)?;
    emit_compiler_mir_fixture_contents_object(
        PHASE9E_CANONICAL_BLOCK_PARAM_LOCAL_FIRST_DUAL_MATERIALIZE_RETURN_FIXTURE,
        output_path,
    )
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
    emit_compiler_mir_fixture_contents_object(
        PHASE9E_CANONICAL_BLOCK_PARAM_DUAL_MATERIALIZE_RETURN_FIXTURE,
        output_path,
    )
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
    emit_compiler_mir_fixture_contents_object(
        PHASE9E_CANONICAL_BLOCK_PARAM_LOCAL_MATERIALIZE_RETURN_FIXTURE,
        output_path,
    )
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
    let module = build_compiler_mir_block_param_imported_materialize_return_module();
    lower_compiler_mir_ingestion_module_to_object(output_path, &module)
}

fn build_compiler_mir_block_param_imported_materialize_return_module(
) -> CompilerMirLoweringModule<'static> {
    CompilerMirLoweringModule {
        name: "gust_native_backend_compiler_mir_ingested_block_param_imported_materialize_return",
        imports: vec![CompilerMirLoweringImportedFunction {
            name: "host_add",
            link_symbol:
                COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_RETURN_HOST_ADD_SYMBOL,
            linkage: CompilerMirLoweringFunctionLinkage::ImportedHost,
            params: vec![TinyMirType::I32, TinyMirType::I32],
            return_type: TinyMirType::I32,
        }],
        functions: vec![CompilerMirLoweringDefinedFunction {
            linkage: CompilerMirLoweringFunctionLinkage::ExportedEntry,
            fixture: ParsedCompilerMirFixture {
                function: CompilerMirLoweringFunction {
                    object_name: "tiny_block_param_imported_materialize_return",
                    symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_RETURN_SYMBOL,
                    return_type: TinyMirType::I32,
                    params: vec![TinyMirType::I32],
                    locals: vec![
                        CompilerMirLoweringLocal {
                            name: "materialized",
                            ty: TinyMirType::I32,
                        },
                        CompilerMirLoweringLocal {
                            name: "returned",
                            ty: TinyMirType::I32,
                        },
                    ],
                    entry_block: "entry",
                    blocks: vec![
                        CompilerMirLoweringBlock {
                            label: "entry",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "materialize_imported_call",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::FunctionParamI32(0),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "materialize_imported_call",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "input",
                                ty: TinyMirType::I32,
                            }],
                            statements: vec![
                                CompilerMirLoweringStatement::LocalI32SetCall {
                                    name: "materialized",
                                    target:
                                        CompilerMirLoweringCallTarget::ImportedFunction(
                                            "host_add",
                                        ),
                                    arguments: vec![
                                        CompilerMirLoweringCallArgument::BlockParamI32(
                                            "input",
                                        ),
                                        CompilerMirLoweringCallArgument::I32Literal(-5),
                                    ],
                                },
                            ],
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "branch_on_materialized_call",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::LocalI32(
                                            "materialized",
                                        ),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "branch_on_materialized_call",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "materialized_value",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator:
                                CompilerMirLoweringTerminator::BranchBlockParamI32Positive {
                                    name: "materialized_value",
                                    then_edge: CompilerMirLoweringEdge {
                                        target: "result",
                                        arguments: vec![
                                            CompilerMirLoweringEdgeArgument::I32Literal(331),
                                        ],
                                    },
                                    else_edge: CompilerMirLoweringEdge {
                                        target: "result",
                                        arguments: vec![
                                            CompilerMirLoweringEdgeArgument::I32Literal(347),
                                        ],
                                    },
                                },
                        },
                        CompilerMirLoweringBlock {
                            label: "result",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "selected",
                                ty: TinyMirType::I32,
                            }],
                            statements: vec![
                                CompilerMirLoweringStatement::LocalI32SetCall {
                                    name: "returned",
                                    target:
                                        CompilerMirLoweringCallTarget::ImportedFunction(
                                            "host_add",
                                        ),
                                    arguments: vec![
                                        CompilerMirLoweringCallArgument::BlockParamI32(
                                            "selected",
                                        ),
                                        CompilerMirLoweringCallArgument::I32Literal(13),
                                    ],
                                },
                            ],
                            terminator:
                                CompilerMirLoweringTerminator::ReturnLocalI32("returned"),
                        },
                    ],
                },
                return_type: TinyMirType::I32,
                metadata: Vec::new(),
                expected_exit: 0,
            },
        }],
    }
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
    emit_compiler_mir_fixture_contents_object(
        PHASE9E_CANONICAL_BLOCK_PARAM_LOCAL_MATERIALIZE_BRANCH_FIXTURE,
        output_path,
    )
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
    let module = build_compiler_mir_block_param_imported_materialize_branch_module();
    lower_compiler_mir_ingestion_module_to_object(output_path, &module)
}

fn build_compiler_mir_block_param_imported_materialize_branch_module(
) -> CompilerMirLoweringModule<'static> {
    CompilerMirLoweringModule {
        name: "gust_native_backend_compiler_mir_ingested_block_param_imported_materialize_branch",
        imports: vec![CompilerMirLoweringImportedFunction {
            name: "host_add",
            link_symbol:
                COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_BRANCH_HOST_ADD_SYMBOL,
            linkage: CompilerMirLoweringFunctionLinkage::ImportedHost,
            params: vec![TinyMirType::I32, TinyMirType::I32],
            return_type: TinyMirType::I32,
        }],
        functions: vec![CompilerMirLoweringDefinedFunction {
            linkage: CompilerMirLoweringFunctionLinkage::ExportedEntry,
            fixture: ParsedCompilerMirFixture {
                function: CompilerMirLoweringFunction {
                    object_name: "tiny_block_param_imported_materialize_branch",
                    symbol:
                        COMPILER_MIR_INGESTED_BLOCK_PARAM_IMPORTED_MATERIALIZE_BRANCH_SYMBOL,
                    return_type: TinyMirType::I32,
                    params: vec![TinyMirType::I32],
                    locals: vec![CompilerMirLoweringLocal {
                        name: "materialized",
                        ty: TinyMirType::I32,
                    }],
                    entry_block: "entry",
                    blocks: vec![
                        CompilerMirLoweringBlock {
                            label: "entry",
                            parameters: Vec::new(),
                            statements: Vec::new(),
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "materialize_imported_call",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::FunctionParamI32(0),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "materialize_imported_call",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "input",
                                ty: TinyMirType::I32,
                            }],
                            statements: vec![
                                CompilerMirLoweringStatement::LocalI32SetCall {
                                    name: "materialized",
                                    target:
                                        CompilerMirLoweringCallTarget::ImportedFunction(
                                            "host_add",
                                        ),
                                    arguments: vec![
                                        CompilerMirLoweringCallArgument::BlockParamI32(
                                            "input",
                                        ),
                                        CompilerMirLoweringCallArgument::I32Literal(-5),
                                    ],
                                },
                            ],
                            terminator: CompilerMirLoweringTerminator::Jump {
                                edge: CompilerMirLoweringEdge {
                                    target: "branch_on_materialized_call",
                                    arguments: vec![
                                        CompilerMirLoweringEdgeArgument::LocalI32(
                                            "materialized",
                                        ),
                                    ],
                                },
                            },
                        },
                        CompilerMirLoweringBlock {
                            label: "branch_on_materialized_call",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "materialized_value",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator:
                                CompilerMirLoweringTerminator::BranchBlockParamI32Positive {
                                    name: "materialized_value",
                                    then_edge: CompilerMirLoweringEdge {
                                        target: "result",
                                        arguments: vec![
                                            CompilerMirLoweringEdgeArgument::I32Literal(271),
                                        ],
                                    },
                                    else_edge: CompilerMirLoweringEdge {
                                        target: "result",
                                        arguments: vec![
                                            CompilerMirLoweringEdgeArgument::I32Literal(283),
                                        ],
                                    },
                                },
                        },
                        CompilerMirLoweringBlock {
                            label: "result",
                            parameters: vec![CompilerMirLoweringBlockParameter {
                                name: "selected",
                                ty: TinyMirType::I32,
                            }],
                            statements: Vec::new(),
                            terminator:
                                CompilerMirLoweringTerminator::ReturnBlockParamI32("selected"),
                        },
                    ],
                },
                return_type: TinyMirType::I32,
                metadata: Vec::new(),
                expected_exit: 0,
            },
        }],
    }
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
        TinyMirType::I32 | TinyMirType::Bool => types::I32,
        TinyMirType::Void => panic!("void tiny MIR type has no Cranelift value representation"),
    }
}

fn validate_compiler_mir_ingestion_lowering_readiness(
    _mir_function: &CompilerMirLoweringFunction<'_>,
) -> Result<(), Box<dyn Error>> {
    Ok(())
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct CompilerMirObjectTargetContract {
    triple: String,
    architecture: String,
    pointer_width_bits: u8,
    endianness: String,
    object_format: String,
    default_call_conv: String,
    relocation_model: &'static str,
    is_pic: bool,
}

fn compiler_mir_object_architecture_from_target_name(
    target_architecture: &str,
) -> Result<Architecture, Box<dyn Error>> {
    let normalized = target_architecture.to_ascii_lowercase();
    let architecture = match normalized.as_str() {
        "x64" | "x86_64" | "x86-64" => Architecture::X86_64,
        "i386" | "i486" | "i586" | "i686" | "x86" => Architecture::I386,
        "aarch64" | "aarch64_be" => Architecture::Aarch64,
        "arm" => Architecture::Arm,
        "riscv32" | "riscv32gc" | "riscv32imac" => Architecture::Riscv32,
        "riscv64" | "riscv64gc" | "riscv64imac" => Architecture::Riscv64,
        "s390x" => Architecture::S390x,
        "powerpc" | "ppc" => Architecture::PowerPc,
        "powerpc64" | "powerpc64le" | "ppc64" | "ppc64le" => {
            Architecture::PowerPc64
        }
        "loongarch64" => Architecture::LoongArch64,
        other if other.starts_with("armv") => Architecture::Arm,
        other if other.starts_with("riscv32") => Architecture::Riscv32,
        other if other.starts_with("riscv64") => Architecture::Riscv64,
        other => {
            return Err(IoError::new(
                ErrorKind::Unsupported,
                format!(
                    "canonical compiler MIR object target architecture is unsupported: {other}"
                ),
            )
            .into());
        }
    };
    Ok(architecture)
}

fn build_compiler_mir_native_object_builder(
    object_name: &str,
) -> Result<(ObjectBuilder, CompilerMirObjectTargetContract), Box<dyn Error>> {
    let mut flag_builder = settings::builder();
    flag_builder.set("is_pic", "true")?;
    let flags = settings::Flags::new(flag_builder);

    let isa_builder =
        cranelift_native::builder().map_err(|message| IoError::new(ErrorKind::Other, message))?;
    let isa = isa_builder.finish(flags)?;
    let object_architecture =
        compiler_mir_object_architecture_from_target_name(
            &isa.triple().architecture.to_string(),
        )?;
    let target_contract = CompilerMirObjectTargetContract {
        triple: isa.triple().to_string(),
        architecture: format!("{object_architecture:?}"),
        pointer_width_bits: isa.pointer_bits(),
        endianness: format!("{:?}", isa.endianness()),
        object_format: format!("{:?}", isa.triple().binary_format),
        default_call_conv: format!("{:?}", isa.default_call_conv()),
        relocation_model: "pic",
        is_pic: isa.flags().is_pic(),
    };

    if !matches!(target_contract.pointer_width_bits, 32 | 64) {
        return Err(IoError::new(
            ErrorKind::Unsupported,
            format!(
                "canonical compiler MIR object target {} has unsupported pointer width {}",
                target_contract.triple, target_contract.pointer_width_bits
            ),
        )
        .into());
    }
    if !matches!(
        target_contract.object_format.as_str(),
        "Elf" | "Coff" | "Macho"
    ) {
        return Err(IoError::new(
            ErrorKind::Unsupported,
            format!(
                "canonical compiler MIR object target {} has unsupported object format {}",
                target_contract.triple, target_contract.object_format
            ),
        )
        .into());
    }
    if !target_contract.is_pic {
        return Err(IoError::new(
            ErrorKind::InvalidData,
            "canonical compiler MIR object target must enable position-independent code",
        )
        .into());
    }

    let object_builder =
        ObjectBuilder::new(isa, object_name, default_libcall_names())?;
    Ok((object_builder, target_contract))
}

fn print_compiler_mir_object_target_contract() -> Result<(), Box<dyn Error>> {
    let (_object_builder, target_contract) =
        build_compiler_mir_native_object_builder("gust_cranelift_target_contract_probe")?;
    println!("target_triple: {}", target_contract.triple);
    println!("architecture: {}", target_contract.architecture);
    println!(
        "pointer_width_bits: {}",
        target_contract.pointer_width_bits
    );
    println!("endianness: {}", target_contract.endianness);
    println!("object_format: {}", target_contract.object_format);
    println!(
        "default_call_conv: {}",
        target_contract.default_call_conv
    );
    println!("relocation_model: {}", target_contract.relocation_model);
    println!("is_pic: {}", target_contract.is_pic);
    Ok(())
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct CompilerMirObjectSymbolContract {
    expected_exports: Vec<String>,
    expected_module_locals: Vec<String>,
    expected_unresolved_imports: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct CompilerMirObjectInspectionReport {
    binary_format: String,
    architecture: String,
    endianness: String,
    pointer_width_bits: u8,
    object_kind: String,
    defined_global_symbols: Vec<String>,
    defined_local_symbols: Vec<String>,
    undefined_symbols: Vec<String>,
    symbol_visibility: Vec<String>,
    sections: Vec<String>,
    has_code_section: bool,
    relocation_targets: Vec<String>,
    duplicate_symbols: Vec<String>,
}

fn sorted_unique_compiler_mir_object_symbols<I>(symbols: I) -> Vec<String>
where
    I: IntoIterator<Item = String>,
{
    let mut symbols = symbols
        .into_iter()
        .collect::<HashSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    symbols.sort();
    symbols
}

fn compiler_mir_function_object_symbol_contract(
    mir_function: &CompilerMirLoweringFunction<'_>,
) -> CompilerMirObjectSymbolContract {
    CompilerMirObjectSymbolContract {
        expected_exports: vec![mir_function.symbol.to_string()],
        expected_module_locals: Vec::new(),
        expected_unresolved_imports: Vec::new(),
    }
}

fn compiler_mir_module_object_symbol_contract(
    mir_module: &CompilerMirLoweringModule<'_>,
) -> CompilerMirObjectSymbolContract {
    let mut expected_exports = Vec::new();
    let mut expected_module_locals = Vec::new();
    for defined in &mir_module.functions {
        match defined.linkage {
            CompilerMirLoweringFunctionLinkage::ExportedEntry
            | CompilerMirLoweringFunctionLinkage::BundleExport => {
                expected_exports.push(defined.fixture.function.symbol.to_string());
            }
            CompilerMirLoweringFunctionLinkage::ModuleLocal => {
                expected_module_locals.push(defined.fixture.function.symbol.to_string());
            }
            CompilerMirLoweringFunctionLinkage::ImportedHost
            | CompilerMirLoweringFunctionLinkage::ImportedBundle => {}
        }
    }

    CompilerMirObjectSymbolContract {
        expected_exports: sorted_unique_compiler_mir_object_symbols(expected_exports),
        expected_module_locals: sorted_unique_compiler_mir_object_symbols(
            expected_module_locals,
        ),
        expected_unresolved_imports: sorted_unique_compiler_mir_object_symbols(
            mir_module
                .imports
                .iter()
                .map(|imported| imported.link_symbol.to_string()),
        ),
    }
}

fn compiler_mir_object_binary_format_name(format: object::BinaryFormat) -> String {
    match format {
        object::BinaryFormat::Elf => "Elf".to_string(),
        object::BinaryFormat::Coff => "Coff".to_string(),
        object::BinaryFormat::MachO => "Macho".to_string(),
        other => format!("{other:?}"),
    }
}

fn validate_compiler_mir_object_symbol_contract(
    report: &CompilerMirObjectInspectionReport,
    contract: &CompilerMirObjectSymbolContract,
) -> Result<(), Box<dyn Error>> {
    if report.defined_global_symbols != contract.expected_exports {
        return Err(IoError::new(
            ErrorKind::InvalidData,
            format!(
                "compiler MIR object defined global symbol contract mismatch: expected {:?}, got {:?}",
                contract.expected_exports, report.defined_global_symbols
            ),
        )
        .into());
    }
    if report.defined_local_symbols != contract.expected_module_locals {
        return Err(IoError::new(
            ErrorKind::InvalidData,
            format!(
                "compiler MIR object module-local symbol contract mismatch: expected {:?}, got {:?}",
                contract.expected_module_locals, report.defined_local_symbols
            ),
        )
        .into());
    }
    if report.undefined_symbols != contract.expected_unresolved_imports {
        return Err(IoError::new(
            ErrorKind::InvalidData,
            format!(
                "compiler MIR object unresolved import contract mismatch: expected {:?}, got {:?}",
                contract.expected_unresolved_imports, report.undefined_symbols
            ),
        )
        .into());
    }
    Ok(())
}

fn validate_compiler_mir_object_target_contract(
    report: &CompilerMirObjectInspectionReport,
    target_contract: &CompilerMirObjectTargetContract,
) -> Result<(), Box<dyn Error>> {
    if report.binary_format != target_contract.object_format {
        return Err(IoError::new(
            ErrorKind::InvalidData,
            format!(
                "compiler MIR object format mismatch: target expected {}, object contains {}",
                target_contract.object_format, report.binary_format
            ),
        )
        .into());
    }
    if report.architecture != target_contract.architecture {
        return Err(IoError::new(
            ErrorKind::InvalidData,
            format!(
                "compiler MIR object architecture mismatch: target expected {}, object contains {}",
                target_contract.architecture, report.architecture
            ),
        )
        .into());
    }
    if report.pointer_width_bits != target_contract.pointer_width_bits {
        return Err(IoError::new(
            ErrorKind::InvalidData,
            format!(
                "compiler MIR object pointer width mismatch: target expected {}, object contains {}",
                target_contract.pointer_width_bits, report.pointer_width_bits
            ),
        )
        .into());
    }
    if report.endianness != target_contract.endianness {
        return Err(IoError::new(
            ErrorKind::InvalidData,
            format!(
                "compiler MIR object endianness mismatch: target expected {}, object contains {}",
                target_contract.endianness, report.endianness
            ),
        )
        .into());
    }
    Ok(())
}

fn inspect_compiler_mir_object_artifact(
    object_bytes: &[u8],
    target_contract: Option<&CompilerMirObjectTargetContract>,
    symbol_contract: Option<&CompilerMirObjectSymbolContract>,
) -> Result<CompilerMirObjectInspectionReport, Box<dyn Error>> {
    let object_file = object::File::parse(object_bytes).map_err(|error| {
        IoError::new(
            ErrorKind::InvalidData,
            format!(
                "compiler MIR object inspection could not parse object bytes: {error}"
            ),
        )
    })?;

    let binary_format = compiler_mir_object_binary_format_name(object_file.format());
    let architecture = format!("{:?}", object_file.architecture());
    let endianness = format!("{:?}", object_file.endianness());
    let pointer_width_bits = if object_file.is_64() { 64 } else { 32 };
    let object_kind = format!("{:?}", object_file.kind());

    let mut sections = Vec::new();
    let mut has_code_section = false;
    let mut relocation_targets = Vec::new();
    for section in object_file.sections() {
        let section_name = section.name()?.to_string();
        let section_kind = section.kind();
        if section_kind == SectionKind::Text && section.size() > 0 {
            has_code_section = true;
        }

        let mut relocation_count = 0usize;
        for (offset, relocation) in section.relocations() {
            relocation_count += 1;
            let target_name = match relocation.target() {
                RelocationTarget::Symbol(index) => {
                    let symbol = object_file.symbol_by_index(index)?;
                    let name = symbol.name()?;
                    if name.is_empty() {
                        format!("<symbol:{index:?}>")
                    } else {
                        name.to_string()
                    }
                }
                RelocationTarget::Section(index) => {
                    let target_section = object_file.section_by_index(index)?;
                    let name = target_section.name()?;
                    if name.is_empty() {
                        format!("<section:{index:?}>")
                    } else {
                        name.to_string()
                    }
                }
                RelocationTarget::Absolute => "<absolute>".to_string(),
                other => format!("<{other:?}>"),
            };
            relocation_targets.push(format!(
                "{}+0x{offset:x}->{target_name}|kind={:?}|encoding={:?}|size={}",
                section_name,
                relocation.kind(),
                relocation.encoding(),
                relocation.size()
            ));
        }
        sections.push(format!(
            "{}|kind={:?}|size={}|relocations={relocation_count}",
            section_name,
            section_kind,
            section.size()
        ));
    }
    sections.sort();
    relocation_targets.sort();

    let mut defined_global_symbols = Vec::new();
    let mut defined_local_symbols = Vec::new();
    let mut undefined_symbols = Vec::new();
    let mut symbol_visibility = Vec::new();
    let mut symbol_name_counts: HashMap<String, usize> = HashMap::new();

    for symbol in object_file.symbols() {
        let name = symbol.name()?.to_string();
        if name.is_empty() {
            continue;
        }

        symbol_visibility.push(format!(
            "{}|kind={:?}|scope={:?}|definition={}|undefined={}|global={}|local={}|weak={}",
            name,
            symbol.kind(),
            symbol.scope(),
            symbol.is_definition(),
            symbol.is_undefined(),
            symbol.is_global(),
            symbol.is_local(),
            symbol.is_weak()
        ));

        if !matches!(symbol.kind(), SymbolKind::Section | SymbolKind::File) {
            *symbol_name_counts.entry(name.clone()).or_insert(0) += 1;
        }

        if symbol.is_undefined() {
            undefined_symbols.push(name);
        } else if symbol.is_definition() && symbol.kind() == SymbolKind::Text {
            if symbol.is_global() {
                defined_global_symbols.push(name);
            } else {
                defined_local_symbols.push(name);
            }
        }
    }

    defined_global_symbols.sort();
    defined_local_symbols.sort();
    undefined_symbols.sort();
    symbol_visibility.sort();

    let mut duplicate_symbols = symbol_name_counts
        .into_iter()
        .filter_map(|(name, count)| (count > 1).then_some(format!("{name}:{count}")))
        .collect::<Vec<_>>();
    duplicate_symbols.sort();

    let report = CompilerMirObjectInspectionReport {
        binary_format,
        architecture,
        endianness,
        pointer_width_bits,
        object_kind,
        defined_global_symbols,
        defined_local_symbols,
        undefined_symbols,
        symbol_visibility,
        sections,
        has_code_section,
        relocation_targets,
        duplicate_symbols,
    };

    if report.object_kind != "Relocatable" {
        return Err(IoError::new(
            ErrorKind::InvalidData,
            format!(
                "compiler MIR object inspection expected a relocatable object, got {}",
                report.object_kind
            ),
        )
        .into());
    }
    if !report.has_code_section {
        return Err(IoError::new(
            ErrorKind::InvalidData,
            "compiler MIR object inspection found no nonempty code section",
        )
        .into());
    }
    if !report.duplicate_symbols.is_empty() {
        return Err(IoError::new(
            ErrorKind::InvalidData,
            format!(
                "compiler MIR object inspection found duplicate symbol-table entries: {:?}",
                report.duplicate_symbols
            ),
        )
        .into());
    }

    if let Some(target_contract) = target_contract {
        validate_compiler_mir_object_target_contract(
            &report,
            target_contract,
        )?;
    }

    if let Some(symbol_contract) = symbol_contract {
        validate_compiler_mir_object_symbol_contract(&report, symbol_contract)?;
    }

    Ok(report)
}

fn print_compiler_mir_object_inspection_report(
    report: &CompilerMirObjectInspectionReport,
) {
    println!("binary_format: {}", report.binary_format);
    println!("architecture: {}", report.architecture);
    println!("endianness: {}", report.endianness);
    println!("pointer_width_bits: {}", report.pointer_width_bits);
    println!("object_kind: {}", report.object_kind);
    println!("has_code_section: {}", report.has_code_section);
    println!(
        "defined_global_symbol_count: {}",
        report.defined_global_symbols.len()
    );
    println!(
        "defined_local_symbol_count: {}",
        report.defined_local_symbols.len()
    );
    println!("undefined_symbol_count: {}", report.undefined_symbols.len());
    println!("section_count: {}", report.sections.len());
    println!(
        "relocation_target_count: {}",
        report.relocation_targets.len()
    );
    println!("duplicate_symbol_count: {}", report.duplicate_symbols.len());
    for symbol in &report.defined_global_symbols {
        println!("defined_global_symbol: {symbol}");
    }
    for symbol in &report.defined_local_symbols {
        println!("defined_local_symbol: {symbol}");
    }
    for symbol in &report.undefined_symbols {
        println!("undefined_symbol: {symbol}");
    }
    for visibility in &report.symbol_visibility {
        println!("symbol_visibility: {visibility}");
    }
    for section in &report.sections {
        println!("section: {section}");
    }
    for relocation_target in &report.relocation_targets {
        println!("relocation_target: {relocation_target}");
    }
    for duplicate_symbol in &report.duplicate_symbols {
        println!("duplicate_symbol: {duplicate_symbol}");
    }
}

fn inspect_compiler_mir_object_path(
    input_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let object_bytes = compiler_mir_pipeline_wrap(
        fs::read(input_path),
        CompilerMirPipelineStage::ObjectVerification,
        CompilerMirPipelineFailureKind::InvalidObject,
    )?;
    let report = compiler_mir_pipeline_wrap_box(
        inspect_compiler_mir_object_artifact(&object_bytes, None, None),
        CompilerMirPipelineStage::ObjectVerification,
        CompilerMirPipelineFailureKind::InvalidObject,
    )?;
    print_compiler_mir_object_inspection_report(&report);
    Ok(())
}

fn compiler_mir_object_symbol_contract_for_fixture_path(
    fixture_path: &Path,
) -> Result<CompilerMirObjectSymbolContract, Box<dyn Error>> {
    let contents = compiler_mir_pipeline_wrap(
        fs::read_to_string(fixture_path),
        CompilerMirPipelineStage::FixtureParse,
        CompilerMirPipelineFailureKind::InvalidFixture,
    )?;
    let parsed = compiler_mir_pipeline_wrap_box(
        parse_compiler_mir_input(&contents),
        CompilerMirPipelineStage::FixtureParse,
        CompilerMirPipelineFailureKind::InvalidFixture,
    )?;
    match parsed {
        ParsedCompilerMirInput::V1(fixture) => {
            compiler_mir_pipeline_wrap_box(
                validate_compiler_mir_fixture(&fixture),
                CompilerMirPipelineStage::FixtureValidation,
                CompilerMirPipelineFailureKind::InvalidFixture,
            )?;
            compiler_mir_pipeline_wrap_box(
                recognize_compiler_mir_fixture_metadata(&fixture.metadata),
                CompilerMirPipelineStage::FixtureValidation,
                CompilerMirPipelineFailureKind::InvalidFixture,
            )?;
            Ok(compiler_mir_function_object_symbol_contract(
                &fixture.function,
            ))
        }
        ParsedCompilerMirInput::V2(module) => {
            compiler_mir_pipeline_wrap_box(
                validate_compiler_mir_module(&module),
                CompilerMirPipelineStage::FixtureValidation,
                CompilerMirPipelineFailureKind::InvalidFixture,
            )?;
            for defined in &module.functions {
                compiler_mir_pipeline_wrap_box(
                    validate_compiler_mir_ingestion_lowering_readiness(
                        &defined.fixture.function,
                    ),
                    CompilerMirPipelineStage::FixtureValidation,
                    CompilerMirPipelineFailureKind::InvalidFixture,
                )?;
                compiler_mir_pipeline_wrap_box(
                    recognize_compiler_mir_fixture_metadata(
                        &defined.fixture.metadata,
                    ),
                    CompilerMirPipelineStage::FixtureValidation,
                    CompilerMirPipelineFailureKind::InvalidFixture,
                )?;
            }
            Ok(compiler_mir_module_object_symbol_contract(&module))
        }
    }
}

fn verify_compiler_mir_object_contract_path(
    fixture_path: &Path,
    object_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let symbol_contract =
        compiler_mir_object_symbol_contract_for_fixture_path(fixture_path)?;
    let object_bytes = compiler_mir_pipeline_wrap(
        fs::read(object_path),
        CompilerMirPipelineStage::ObjectVerification,
        CompilerMirPipelineFailureKind::InvalidObject,
    )?;
    let report = compiler_mir_pipeline_wrap_box(
        inspect_compiler_mir_object_artifact(
            &object_bytes,
            None,
            Some(&symbol_contract),
        ),
        CompilerMirPipelineStage::ObjectVerification,
        CompilerMirPipelineFailureKind::InvalidObject,
    )?;
    print_compiler_mir_object_inspection_report(&report);
    Ok(())
}

fn compiler_mir_binary_format_from_contract_name(
    format_name: &str,
) -> Result<BinaryFormat, Box<dyn Error>> {
    match format_name {
        "Elf" => Ok(BinaryFormat::Elf),
        "Coff" => Ok(BinaryFormat::Coff),
        "Macho" => Ok(BinaryFormat::MachO),
        other => Err(IoError::new(
            ErrorKind::Unsupported,
            format!(
                "compiler MIR negative object fixture cannot map object format {other}"
            ),
        )
        .into()),
    }
}

fn compiler_mir_endianness_from_contract_name(
    endianness: &str,
) -> Result<Endianness, Box<dyn Error>> {
    match endianness {
        "Little" => Ok(Endianness::Little),
        "Big" => Ok(Endianness::Big),
        other => Err(IoError::new(
            ErrorKind::Unsupported,
            format!(
                "compiler MIR negative object fixture cannot map endianness {other}"
            ),
        )
        .into()),
    }
}

fn compiler_mir_alternate_object_architecture(
    architecture: Architecture,
) -> Architecture {
    match architecture {
        Architecture::X86_64 => Architecture::Aarch64,
        Architecture::Aarch64 => Architecture::X86_64,
        Architecture::I386 => Architecture::Arm,
        Architecture::Arm => Architecture::I386,
        Architecture::Riscv32 => Architecture::I386,
        Architecture::Riscv64 => Architecture::X86_64,
        Architecture::PowerPc => Architecture::I386,
        Architecture::PowerPc64 => Architecture::X86_64,
        Architecture::S390x => Architecture::X86_64,
        Architecture::LoongArch64 => Architecture::X86_64,
        _ => Architecture::X86_64,
    }
}

fn write_compiler_mir_negative_object_fixture(
    fixture_kind: &str,
    output_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let (_object_builder, target_contract) =
        build_compiler_mir_native_object_builder(
            "gust_cranelift_negative_object_fixture_probe",
        )?;
    let native_format =
        compiler_mir_binary_format_from_contract_name(
            &target_contract.object_format,
        )?;
    let native_architecture =
        compiler_mir_object_architecture_from_target_name(
            &target_contract.architecture,
        )?;
    let native_endianness =
        compiler_mir_endianness_from_contract_name(
            &target_contract.endianness,
        )?;

    let (fixture_format, fixture_architecture, fixture_endianness) =
        match fixture_kind {
            "wrong-format" => {
                let alternate_format = match native_format {
                    BinaryFormat::Elf => BinaryFormat::Coff,
                    BinaryFormat::Coff | BinaryFormat::MachO => {
                        BinaryFormat::Elf
                    }
                    _ => {
                        return Err(IoError::new(
                            ErrorKind::Unsupported,
                            "compiler MIR negative object fixture requires Elf, Coff, or Macho",
                        )
                        .into());
                    }
                };
                let alternate_endianness =
                    if alternate_format == BinaryFormat::Coff {
                        Endianness::Little
                    } else {
                        native_endianness
                    };
                (
                    alternate_format,
                    native_architecture,
                    alternate_endianness,
                )
            }
            "unsupported-architecture" => (
                native_format,
                compiler_mir_alternate_object_architecture(
                    native_architecture,
                ),
                native_endianness,
            ),
            other => {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "compiler MIR negative object fixture kind must be wrong-format or unsupported-architecture, got {other}"
                    ),
                )
                .into());
            }
        };

    let mut object = WriteObject::new(
        fixture_format,
        fixture_architecture,
        fixture_endianness,
    );
    let text_section = object.section_id(StandardSection::Text);
    let code = [0u8];
    let symbol_offset =
        object.append_section_data(text_section, &code, 1);
    object.add_symbol(WriteSymbol {
        name: b"phase9g_negative_object_probe".to_vec(),
        value: symbol_offset,
        size: code.len() as u64,
        kind: SymbolKind::Text,
        scope: SymbolScope::Linkage,
        weak: false,
        section: SymbolSection::Section(text_section),
        flags: SymbolFlags::None,
    });
    let object_bytes = object.write()?;

    if let Some(parent) = output_path
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
    {
        fs::create_dir_all(parent)?;
    }
    fs::write(output_path, object_bytes)?;
    Ok(())
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum CompilerMirLinkExpectedResult {
    Success,
    Failure,
}

impl CompilerMirLinkExpectedResult {
    fn parse(value: &str) -> Result<Self, Box<dyn Error>> {
        match value {
            "success" => Ok(Self::Success),
            "failure" => Ok(Self::Failure),
            other => Err(IoError::new(
                ErrorKind::InvalidData,
                format!(
                    "compiler MIR link request expected_result must be success or failure, got {other}"
                ),
            )
            .into()),
        }
    }

    fn as_str(self) -> &'static str {
        match self {
            Self::Success => "success",
            Self::Failure => "failure",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum CompilerMirLinkClassification {
    Linked,
    NativeLinkFailure,
}

impl CompilerMirLinkClassification {
    fn as_str(self) -> &'static str {
        match self {
            Self::Linked => "linked",
            Self::NativeLinkFailure => "native_link_failure",
        }
    }
}

fn compiler_mir_classify_native_link_failure(
    stdout: &[u8],
    stderr: &[u8],
) -> CompilerMirPipelineFailureKind {
    let diagnostics = format!(
        "{}\n{}",
        String::from_utf8_lossy(stdout),
        String::from_utf8_lossy(stderr)
    )
    .to_ascii_lowercase();

    if diagnostics.contains("multiple definition")
        || diagnostics.contains("duplicate symbol")
        || diagnostics.contains("already defined")
    {
        CompilerMirPipelineFailureKind::DuplicateSymbol
    } else if diagnostics.contains("undefined reference")
        || diagnostics.contains("undefined symbol")
        || diagnostics.contains("unresolved external symbol")
        || diagnostics.contains("symbol(s) not found")
    {
        CompilerMirPipelineFailureKind::UnresolvedSymbol
    } else if diagnostics.contains("file format not recognized")
        || diagnostics.contains("not an object")
        || diagnostics.contains("unknown file type")
        || diagnostics.contains("malformed object")
        || diagnostics.contains("truncated")
    {
        CompilerMirPipelineFailureKind::InvalidObject
    } else if diagnostics.contains("unrecognized command-line option")
        || diagnostics.contains("unrecognized option")
        || diagnostics.contains("unknown argument")
        || diagnostics.contains("unknown option")
        || diagnostics.contains("unsupported option")
    {
        CompilerMirPipelineFailureKind::LinkerRejectedOptions
    } else if diagnostics.contains("cannot open output file")
        || diagnostics.contains("cannot write output")
        || diagnostics.contains("permission denied")
        || diagnostics.contains("read-only file system")
    {
        CompilerMirPipelineFailureKind::OutputNotWritable
    } else {
        CompilerMirPipelineFailureKind::UnknownNativeLinkFailure
    }
}

#[derive(Debug)]
struct CompilerMirLinkRequest {
    output_path: PathBuf,
    ordered_object_inputs: Vec<PathBuf>,
    c_source: Option<PathBuf>,
    host_object: Option<PathBuf>,
    additional_libraries: Vec<String>,
    additional_linker_args: Vec<OsString>,
    linker_driver: OsString,
    environment_overrides: Vec<(OsString, OsString)>,
    expected_result: CompilerMirLinkExpectedResult,
    expected_failure_kind: Option<CompilerMirPipelineFailureKind>,
}

#[derive(Debug)]
struct CompilerMirLinkReport {
    classification: CompilerMirLinkClassification,
    failure_stage: Option<CompilerMirPipelineStage>,
    failure_kind: Option<CompilerMirPipelineFailureKind>,
    expected_result: CompilerMirLinkExpectedResult,
    expected_failure_kind: Option<CompilerMirPipelineFailureKind>,
    matched_expectation: bool,
    published: bool,
    exit_code: Option<i32>,
    output_path: PathBuf,
    temp_path: PathBuf,
    stdout_log_path: PathBuf,
    stderr_log_path: PathBuf,
    linker_driver: OsString,
    ordered_object_inputs: Vec<PathBuf>,
    c_source: Option<PathBuf>,
    host_object: Option<PathBuf>,
    additional_libraries: Vec<String>,
    additional_linker_args: Vec<OsString>,
    environment_overrides: Vec<(OsString, OsString)>,
}

fn compiler_mir_link_request_path(base_dir: &Path, value: &str) -> PathBuf {
    let path = Path::new(value);
    if path.is_absolute() {
        path.to_path_buf()
    } else {
        base_dir.join(path)
    }
}

fn parse_compiler_mir_link_request(
    request_path: &Path,
) -> Result<CompilerMirLinkRequest, Box<dyn Error>> {
    let contents = fs::read_to_string(request_path)?;
    let base_dir = request_path
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."));

    let mut format_name: Option<String> = None;
    let mut output_path: Option<PathBuf> = None;
    let mut ordered_object_inputs = Vec::new();
    let mut c_source: Option<PathBuf> = None;
    let mut host_object: Option<PathBuf> = None;
    let mut additional_libraries = Vec::new();
    let mut additional_linker_args = Vec::new();
    let mut linker_driver: Option<OsString> = None;
    let mut environment_overrides = Vec::new();
    let mut expected_result: Option<CompilerMirLinkExpectedResult> = None;
    let mut expected_failure_kind: Option<CompilerMirPipelineFailureKind> = None;

    for (line_index, raw_line) in contents.lines().enumerate() {
        let line_number = line_index + 1;
        let line = raw_line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }

        let Some((field, raw_value)) = line.split_once(':') else {
            return Err(IoError::new(
                ErrorKind::InvalidData,
                format!(
                    "compiler MIR link request line {line_number} must use field: value syntax"
                ),
            )
            .into());
        };
        let field = field.trim();
        let value = raw_value.trim();
        if value.is_empty() {
            return Err(IoError::new(
                ErrorKind::InvalidData,
                format!(
                    "compiler MIR link request field {field} on line {line_number} must not be empty"
                ),
            )
            .into());
        }

        match field {
            "format" => {
                if format_name.replace(value.to_string()).is_some() {
                    return Err(IoError::new(
                        ErrorKind::InvalidData,
                        "compiler MIR link request format may appear only once",
                    )
                    .into());
                }
            }
            "output" => {
                if output_path
                    .replace(compiler_mir_link_request_path(base_dir, value))
                    .is_some()
                {
                    return Err(IoError::new(
                        ErrorKind::InvalidData,
                        "compiler MIR link request output may appear only once",
                    )
                    .into());
                }
            }
            "object" => ordered_object_inputs
                .push(compiler_mir_link_request_path(base_dir, value)),
            "c_source" => {
                if c_source
                    .replace(compiler_mir_link_request_path(base_dir, value))
                    .is_some()
                {
                    return Err(IoError::new(
                        ErrorKind::InvalidData,
                        "compiler MIR link request c_source may appear only once",
                    )
                    .into());
                }
            }
            "host_object" => {
                if host_object
                    .replace(compiler_mir_link_request_path(base_dir, value))
                    .is_some()
                {
                    return Err(IoError::new(
                        ErrorKind::InvalidData,
                        "compiler MIR link request host_object may appear only once",
                    )
                    .into());
                }
            }
            "library" => additional_libraries.push(value.to_string()),
            "link_arg" => additional_linker_args.push(OsString::from(value)),
            "driver" => {
                if linker_driver.replace(OsString::from(value)).is_some() {
                    return Err(IoError::new(
                        ErrorKind::InvalidData,
                        "compiler MIR link request driver may appear only once",
                    )
                    .into());
                }
            }
            "env" => {
                let Some((key, env_value)) = value.split_once('=') else {
                    return Err(IoError::new(
                        ErrorKind::InvalidData,
                        format!(
                            "compiler MIR link request env on line {line_number} must use KEY=VALUE syntax"
                        ),
                    )
                    .into());
                };
                if key.is_empty() || key.contains('=') {
                    return Err(IoError::new(
                        ErrorKind::InvalidData,
                        format!(
                            "compiler MIR link request env on line {line_number} has an invalid key"
                        ),
                    )
                    .into());
                }
                environment_overrides
                    .push((OsString::from(key), OsString::from(env_value)));
            }
            "expected_result" => {
                if expected_result
                    .replace(CompilerMirLinkExpectedResult::parse(value)?)
                    .is_some()
                {
                    return Err(IoError::new(
                        ErrorKind::InvalidData,
                        "compiler MIR link request expected_result may appear only once",
                    )
                    .into());
                }
            }
            "expected_failure_kind" => {
                if expected_failure_kind
                    .replace(
                        CompilerMirPipelineFailureKind::parse_link_failure_kind(
                            value,
                        )?,
                    )
                    .is_some()
                {
                    return Err(IoError::new(
                        ErrorKind::InvalidData,
                        "compiler MIR link request expected_failure_kind may appear only once",
                    )
                    .into());
                }
            }
            other => {
                return Err(IoError::new(
                    ErrorKind::InvalidData,
                    format!(
                        "compiler MIR link request line {line_number} has unknown field {other}"
                    ),
                )
                .into());
            }
        }
    }

    if format_name.as_deref() != Some("gust.compiler_mir_link_request.v1") {
        return Err(IoError::new(
            ErrorKind::InvalidData,
            format!(
                "compiler MIR link request format must be gust.compiler_mir_link_request.v1, got {:?}",
                format_name
            ),
        )
        .into());
    }

    let request = CompilerMirLinkRequest {
        output_path: output_path.ok_or_else(|| {
            IoError::new(
                ErrorKind::InvalidData,
                "compiler MIR link request is missing output",
            )
        })?,
        ordered_object_inputs,
        c_source,
        host_object,
        additional_libraries,
        additional_linker_args,
        linker_driver: linker_driver.ok_or_else(|| {
            IoError::new(
                ErrorKind::InvalidData,
                "compiler MIR link request is missing driver",
            )
        })?,
        environment_overrides,
        expected_result: expected_result.ok_or_else(|| {
            IoError::new(
                ErrorKind::InvalidData,
                "compiler MIR link request is missing expected_result",
            )
        })?,
        expected_failure_kind,
    };
    Ok(request)
}

fn validate_compiler_mir_link_input(
    input_kind: &str,
    input_path: &Path,
    inspect_object: bool,
    target_contract: Option<&CompilerMirObjectTargetContract>,
) -> Result<(), Box<dyn Error>> {
    let metadata = fs::metadata(input_path).map_err(|error| {
        compiler_mir_pipeline_error(
            CompilerMirPipelineStage::LinkInputValidation,
            CompilerMirPipelineFailureKind::MissingInput,
            format!(
                "compiler MIR link {input_kind} input does not exist or cannot be read: {}: {error}",
                input_path.display()
            ),
        )
    })?;
    if !metadata.is_file() {
        return Err(compiler_mir_pipeline_error(
            CompilerMirPipelineStage::LinkInputValidation,
            CompilerMirPipelineFailureKind::MissingInput,
            format!(
                "compiler MIR link {input_kind} input must be a file: {}",
                input_path.display()
            ),
        ));
    }
    if inspect_object {
        let object_bytes = fs::read(input_path).map_err(|error| {
            compiler_mir_pipeline_error(
                CompilerMirPipelineStage::LinkInputValidation,
                CompilerMirPipelineFailureKind::MissingInput,
                format!(
                    "compiler MIR link {input_kind} input cannot be read: {}: {error}",
                    input_path.display()
                ),
            )
        })?;
        let inspection_report = compiler_mir_pipeline_wrap_box(
            inspect_compiler_mir_object_artifact(
                &object_bytes,
                None,
                None,
            ),
            CompilerMirPipelineStage::LinkInputValidation,
            CompilerMirPipelineFailureKind::InvalidObject,
        )?;
        if let Some(target_contract) = target_contract {
            compiler_mir_pipeline_wrap_box(
                validate_compiler_mir_object_target_contract(
                    &inspection_report,
                    target_contract,
                ),
                CompilerMirPipelineStage::LinkInputValidation,
                CompilerMirPipelineFailureKind::UnsupportedTarget,
            )?;
        }
    }
    Ok(())
}

fn validate_compiler_mir_link_request(
    request: &CompilerMirLinkRequest,
) -> Result<(), Box<dyn Error>> {
    if request.output_path.file_name().is_none() {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            format!(
                "compiler MIR link output path must name a file: {}",
                request.output_path.display()
            ),
        )
        .into());
    }
    if request.ordered_object_inputs.is_empty() {
        return Err(IoError::new(
            ErrorKind::InvalidData,
            "compiler MIR link request requires at least one ordered object input",
        )
        .into());
    }
    if request.c_source.is_some() && request.host_object.is_some() {
        return Err(IoError::new(
            ErrorKind::InvalidData,
            "compiler MIR link request may contain c_source or host_object, not both",
        )
        .into());
    }
    if request.linker_driver.as_os_str().is_empty() {
        return Err(IoError::new(
            ErrorKind::InvalidData,
            "compiler MIR link request driver must not be empty",
        )
        .into());
    }
    match (
        request.expected_result,
        request.expected_failure_kind,
    ) {
        (CompilerMirLinkExpectedResult::Success, None) => {}
        (CompilerMirLinkExpectedResult::Failure, Some(_)) => {}
        (CompilerMirLinkExpectedResult::Success, Some(_)) => {
            return Err(IoError::new(
                ErrorKind::InvalidData,
                "compiler MIR link request expected_failure_kind is forbidden when expected_result is success",
            )
            .into());
        }
        (CompilerMirLinkExpectedResult::Failure, None) => {
            return Err(IoError::new(
                ErrorKind::InvalidData,
                "compiler MIR link request expected_result failure requires expected_failure_kind",
            )
            .into());
        }
    }
    for linker_arg in &request.additional_linker_args {
        let linker_arg = linker_arg.to_string_lossy();
        if linker_arg == "-o"
            || linker_arg == "--output"
            || linker_arg.starts_with("--output=")
        {
            return Err(IoError::new(
                ErrorKind::InvalidData,
                format!(
                    "compiler MIR link request reserves executable output control and rejects linker argument {linker_arg}"
                ),
            )
            .into());
        }
    }

    let (_target_probe, target_contract) =
        compiler_mir_pipeline_wrap_box(
            build_compiler_mir_native_object_builder(
                "gust_cranelift_link_input_validation",
            ),
            CompilerMirPipelineStage::LinkInputValidation,
            CompilerMirPipelineFailureKind::UnsupportedTarget,
        )?;
    for input_path in &request.ordered_object_inputs {
        validate_compiler_mir_link_input(
            "object",
            input_path,
            true,
            Some(&target_contract),
        )?;
    }
    if let Some(c_source) = request.c_source.as_deref() {
        validate_compiler_mir_link_input(
            "C source",
            c_source,
            false,
            None,
        )?;
    }
    if let Some(host_object) = request.host_object.as_deref() {
        validate_compiler_mir_link_input(
            "host object",
            host_object,
            true,
            Some(&target_contract),
        )?;
    }

    let temp_path =
        compiler_mir_link_sibling_path(&request.output_path, ".phase9g-link.tmp")?;
    let stdout_log_path = compiler_mir_link_sibling_path(
        &request.output_path,
        ".phase9g-link.stdout.log",
    )?;
    let stderr_log_path = compiler_mir_link_sibling_path(
        &request.output_path,
        ".phase9g-link.stderr.log",
    )?;
    for input_path in request
        .ordered_object_inputs
        .iter()
        .map(PathBuf::as_path)
        .chain(request.c_source.as_deref())
        .chain(request.host_object.as_deref())
    {
        if input_path == request.output_path.as_path()
            || input_path == temp_path.as_path()
            || input_path == stdout_log_path.as_path()
            || input_path == stderr_log_path.as_path()
        {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "compiler MIR link output or owned sibling artifact must not alias an input: {}",
                    input_path.display()
                ),
            )
            .into());
        }
    }

    Ok(())
}

fn compiler_mir_link_sibling_path(
    output_path: &Path,
    suffix: &str,
) -> Result<PathBuf, Box<dyn Error>> {
    let file_name = output_path.file_name().ok_or_else(|| {
        IoError::new(
            ErrorKind::InvalidInput,
            format!(
                "compiler MIR link output path must name a file: {}",
                output_path.display()
            ),
        )
    })?;
    let mut sibling_name = OsString::from(".");
    sibling_name.push(file_name);
    sibling_name.push(suffix);
    Ok(output_path.with_file_name(sibling_name))
}

fn remove_compiler_mir_link_temp(temp_path: &Path) -> Result<(), Box<dyn Error>> {
    match fs::remove_file(temp_path) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == ErrorKind::NotFound => Ok(()),
        Err(error) => Err(error.into()),
    }
}

fn run_compiler_mir_link_request(
    request: CompilerMirLinkRequest,
) -> Result<CompilerMirLinkReport, Box<dyn Error>> {
    compiler_mir_pipeline_wrap_box(
        validate_compiler_mir_link_request(&request),
        CompilerMirPipelineStage::LinkInputValidation,
        CompilerMirPipelineFailureKind::InvalidRequest,
    )?;

    let temp_path = compiler_mir_pipeline_wrap_box(
        compiler_mir_link_sibling_path(
            &request.output_path,
            ".phase9g-link.tmp",
        ),
        CompilerMirPipelineStage::LinkInputValidation,
        CompilerMirPipelineFailureKind::InvalidRequest,
    )?;
    let stdout_log_path = compiler_mir_pipeline_wrap_box(
        compiler_mir_link_sibling_path(
            &request.output_path,
            ".phase9g-link.stdout.log",
        ),
        CompilerMirPipelineStage::LinkInputValidation,
        CompilerMirPipelineFailureKind::InvalidRequest,
    )?;
    let stderr_log_path = compiler_mir_pipeline_wrap_box(
        compiler_mir_link_sibling_path(
            &request.output_path,
            ".phase9g-link.stderr.log",
        ),
        CompilerMirPipelineStage::LinkInputValidation,
        CompilerMirPipelineFailureKind::InvalidRequest,
    )?;

    if let Some(parent) = request
        .output_path
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
    {
        compiler_mir_pipeline_wrap(
            fs::create_dir_all(parent),
            CompilerMirPipelineStage::ExecutablePublication,
            CompilerMirPipelineFailureKind::OutputNotWritable,
        )?;
    }
    compiler_mir_pipeline_wrap_box(
        remove_compiler_mir_link_temp(&temp_path),
        CompilerMirPipelineStage::ExecutablePublication,
        CompilerMirPipelineFailureKind::OutputNotWritable,
    )?;

    let mut command = Command::new(&request.linker_driver);
    for linker_arg in &request.additional_linker_args {
        command.arg(linker_arg);
    }
    for object_input in &request.ordered_object_inputs {
        command.arg(object_input);
    }
    if let Some(c_source) = request.c_source.as_deref() {
        command.arg(c_source);
    }
    if let Some(host_object) = request.host_object.as_deref() {
        command.arg(host_object);
    }
    for library in &request.additional_libraries {
        command.arg(format!("-l{library}"));
    }
    command.arg("-o").arg(&temp_path);
    for (key, value) in &request.environment_overrides {
        command.env(key, value);
    }

    let process_output = match command.output() {
        Ok(output) => output,
        Err(error) => {
            let _ = remove_compiler_mir_link_temp(&temp_path);
            let _ = fs::write(&stdout_log_path, b"");
            let _ = fs::write(
                &stderr_log_path,
                format!("linker spawn failed: {error}\n").as_bytes(),
            );
            return Err(compiler_mir_pipeline_error(
                CompilerMirPipelineStage::LinkerSpawn,
                CompilerMirPipelineFailureKind::LinkerUnavailable,
                format!(
                    "compiler MIR linker spawn failed: {error}; stderr log: {}",
                    stderr_log_path.display()
                ),
            ));
        }
    };

    compiler_mir_pipeline_wrap(
        fs::write(&stdout_log_path, &process_output.stdout),
        CompilerMirPipelineStage::NativeLink,
        CompilerMirPipelineFailureKind::OutputNotWritable,
    )?;
    compiler_mir_pipeline_wrap(
        fs::write(&stderr_log_path, &process_output.stderr),
        CompilerMirPipelineStage::NativeLink,
        CompilerMirPipelineFailureKind::OutputNotWritable,
    )?;

    let (classification, failure_stage, failure_kind) =
        if process_output.status.success() {
            (CompilerMirLinkClassification::Linked, None, None)
        } else {
            (
                CompilerMirLinkClassification::NativeLinkFailure,
                Some(CompilerMirPipelineStage::NativeLink),
                Some(compiler_mir_classify_native_link_failure(
                    &process_output.stdout,
                    &process_output.stderr,
                )),
            )
        };

    let matched_expectation = match (
        request.expected_result,
        request.expected_failure_kind,
        classification,
        failure_kind,
    ) {
        (
            CompilerMirLinkExpectedResult::Success,
            None,
            CompilerMirLinkClassification::Linked,
            None,
        ) => true,
        (
            CompilerMirLinkExpectedResult::Failure,
            Some(expected_kind),
            CompilerMirLinkClassification::NativeLinkFailure,
            Some(actual_kind),
        ) => expected_kind == actual_kind,
        _ => false,
    };

    let published = if classification == CompilerMirLinkClassification::Linked
        && matched_expectation
    {
        let temp_metadata = fs::metadata(&temp_path).map_err(|error| {
            compiler_mir_pipeline_error(
                CompilerMirPipelineStage::ExecutablePublication,
                CompilerMirPipelineFailureKind::OutputNotWritable,
                format!(
                    "linker reported success but temporary executable is unavailable at {}: {error}",
                    temp_path.display()
                ),
            )
        })?;
        if temp_metadata.len() == 0 {
            let _ = remove_compiler_mir_link_temp(&temp_path);
            return Err(compiler_mir_pipeline_error(
                CompilerMirPipelineStage::ExecutablePublication,
                CompilerMirPipelineFailureKind::OutputNotWritable,
                "linker produced an empty temporary executable",
            ));
        }
        if let Err(error) = fs::rename(&temp_path, &request.output_path) {
            let _ = remove_compiler_mir_link_temp(&temp_path);
            return Err(compiler_mir_pipeline_error(
                CompilerMirPipelineStage::ExecutablePublication,
                CompilerMirPipelineFailureKind::OutputNotWritable,
                format!(
                    "could not publish {}: {error}",
                    request.output_path.display()
                ),
            ));
        }
        true
    } else {
        compiler_mir_pipeline_wrap_box(
            remove_compiler_mir_link_temp(&temp_path),
            CompilerMirPipelineStage::ExecutablePublication,
            CompilerMirPipelineFailureKind::OutputNotWritable,
        )?;
        false
    };

    if !matched_expectation {
        let actual_kind = failure_kind.unwrap_or(
            CompilerMirPipelineFailureKind::UnknownNativeLinkFailure,
        );
        return Err(compiler_mir_pipeline_error(
            CompilerMirPipelineStage::NativeLink,
            actual_kind,
            format!(
                "compiler MIR link result mismatch: expected {} {:?}, classified {} {:?}; stdout log: {}; stderr log: {}",
                request.expected_result.as_str(),
                request.expected_failure_kind.map(
                    CompilerMirPipelineFailureKind::as_str
                ),
                classification.as_str(),
                failure_kind.map(CompilerMirPipelineFailureKind::as_str),
                stdout_log_path.display(),
                stderr_log_path.display()
            ),
        ));
    }

    Ok(CompilerMirLinkReport {
        classification,
        failure_stage,
        failure_kind,
        expected_result: request.expected_result,
        expected_failure_kind: request.expected_failure_kind,
        matched_expectation,
        published,
        exit_code: process_output.status.code(),
        output_path: request.output_path,
        temp_path,
        stdout_log_path,
        stderr_log_path,
        linker_driver: request.linker_driver,
        ordered_object_inputs: request.ordered_object_inputs,
        c_source: request.c_source,
        host_object: request.host_object,
        additional_libraries: request.additional_libraries,
        additional_linker_args: request.additional_linker_args,
        environment_overrides: request.environment_overrides,
    })
}

fn print_compiler_mir_link_report(report: &CompilerMirLinkReport) {
    println!("classification: {}", report.classification.as_str());
    match (report.failure_stage, report.failure_kind) {
        (Some(stage), Some(kind)) => {
            println!("pipeline_stage: {}", stage.as_str());
            println!("failure_kind: {}", kind.as_str());
            println!(
                "{}",
                compiler_mir_pipeline_machine_line(stage, kind)
            );
        }
        _ => {
            println!("pipeline_stage: none");
            println!("failure_kind: none");
        }
    }
    println!("expected_result: {}", report.expected_result.as_str());
    match report.expected_failure_kind {
        Some(kind) => println!("expected_failure_kind: {}", kind.as_str()),
        None => println!("expected_failure_kind: none"),
    }
    println!("matched_expectation: {}", report.matched_expectation);
    println!("published: {}", report.published);
    match report.exit_code {
        Some(exit_code) => println!("exit_code: {exit_code}"),
        None => println!("exit_code: none"),
    }
    println!("output_path: {}", report.output_path.display());
    println!("temp_path: {}", report.temp_path.display());
    println!("stdout_log_path: {}", report.stdout_log_path.display());
    println!("stderr_log_path: {}", report.stderr_log_path.display());
    println!(
        "linker_driver: {}",
        report.linker_driver.to_string_lossy()
    );
    println!(
        "ordered_object_input_count: {}",
        report.ordered_object_inputs.len()
    );
    for (index, input_path) in report.ordered_object_inputs.iter().enumerate() {
        println!("ordered_object_input_{index}: {}", input_path.display());
    }
    if let Some(c_source) = report.c_source.as_deref() {
        println!("c_source: {}", c_source.display());
    }
    if let Some(host_object) = report.host_object.as_deref() {
        println!("host_object: {}", host_object.display());
    }
    for library in &report.additional_libraries {
        println!("additional_library: {library}");
    }
    for linker_arg in &report.additional_linker_args {
        println!(
            "additional_linker_arg: {}",
            linker_arg.to_string_lossy()
        );
    }
    for (key, value) in &report.environment_overrides {
        println!(
            "environment_override: {}={}",
            key.to_string_lossy(),
            value.to_string_lossy()
        );
    }
}

fn execute_compiler_mir_link_request_path(
    request_path: &Path,
) -> Result<(), Box<dyn Error>> {
    let request = compiler_mir_pipeline_wrap_box(
        parse_compiler_mir_link_request(request_path),
        CompilerMirPipelineStage::LinkInputValidation,
        CompilerMirPipelineFailureKind::InvalidRequest,
    )?;
    let report = run_compiler_mir_link_request(request)?;
    print_compiler_mir_link_report(&report);
    Ok(())
}

#[derive(Debug)]
struct CompilerMirObjectArtifactReport {
    final_path: PathBuf,
    byte_size: usize,
}

fn compiler_mir_object_temp_path(
    output_path: &Path,
) -> Result<PathBuf, Box<dyn Error>> {
    let file_name = output_path.file_name().ok_or_else(|| {
        IoError::new(
            ErrorKind::InvalidInput,
            format!(
                "compiler MIR object output path must name a file: {}",
                output_path.display()
            ),
        )
    })?;
    let mut temp_file_name = OsString::from(".");
    temp_file_name.push(file_name);
    temp_file_name.push(".phase9g.tmp");
    Ok(output_path.with_file_name(temp_file_name))
}

fn publish_compiler_mir_object_artifact(
    output_path: &Path,
    object_bytes: Vec<u8>,
) -> Result<CompilerMirObjectArtifactReport, Box<dyn Error>> {
    if object_bytes.is_empty() {
        return Err(IoError::new(
            ErrorKind::InvalidData,
            "compiler MIR object emission produced an empty object artifact",
        )
        .into());
    }

    let byte_size = object_bytes.len();
    let temp_path = compiler_mir_object_temp_path(output_path)?;
    if let Some(parent) = output_path
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
    {
        fs::create_dir_all(parent)?;
    }

    match fs::remove_file(&temp_path) {
        Ok(()) => {}
        Err(error) if error.kind() == ErrorKind::NotFound => {}
        Err(error) => return Err(error.into()),
    }

    let publication_result = (|| -> Result<(), IoError> {
        let mut temp_file = fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&temp_path)?;
        temp_file.write_all(&object_bytes)?;
        temp_file.sync_all()?;
        drop(temp_file);
        fs::rename(&temp_path, output_path)?;
        Ok(())
    })();

    if let Err(error) = publication_result {
        let _ = fs::remove_file(&temp_path);
        return Err(error.into());
    }

    Ok(CompilerMirObjectArtifactReport {
        final_path: output_path.to_path_buf(),
        byte_size,
    })
}

fn lower_compiler_mir_ingestion_function_to_object(
    output_path: &Path,
    mir_function: &CompilerMirLoweringFunction<'_>,
) -> Result<(), Box<dyn Error>> {
    compiler_mir_pipeline_wrap_box(
        validate_compiler_mir_ingestion_lowering_readiness(mir_function),
        CompilerMirPipelineStage::FixtureValidation,
        CompilerMirPipelineFailureKind::InvalidFixture,
    )?;

    let (object_builder, target_contract) =
        compiler_mir_pipeline_wrap_box(
            build_compiler_mir_native_object_builder(
                mir_function.object_name,
            ),
            CompilerMirPipelineStage::ObjectBuild,
            CompilerMirPipelineFailureKind::UnsupportedTarget,
        )?;
    debug_assert!(target_contract.is_pic);
    let mut module = ObjectModule::new(object_builder);

    compiler_mir_pipeline_wrap_box(
        define_compiler_mir_ingestion_exported_function(
            &mut module,
            mir_function,
        ),
        CompilerMirPipelineStage::MirLowering,
        CompilerMirPipelineFailureKind::LoweringFailed,
    )?;

    let object_product = module.finish();
    let object_bytes = compiler_mir_pipeline_wrap(
        object_product.emit(),
        CompilerMirPipelineStage::ObjectBuild,
        CompilerMirPipelineFailureKind::ObjectBuildFailed,
    )?;
    let symbol_contract =
        compiler_mir_function_object_symbol_contract(mir_function);
    let inspection_report = compiler_mir_pipeline_wrap_box(
        inspect_compiler_mir_object_artifact(
            &object_bytes,
            Some(&target_contract),
            Some(&symbol_contract),
        ),
        CompilerMirPipelineStage::ObjectVerification,
        CompilerMirPipelineFailureKind::InvalidObject,
    )?;
    debug_assert!(inspection_report.has_code_section);
    let artifact_report = compiler_mir_pipeline_wrap_box(
        publish_compiler_mir_object_artifact(output_path, object_bytes),
        CompilerMirPipelineStage::ObjectPublication,
        CompilerMirPipelineFailureKind::OutputNotWritable,
    )?;
    debug_assert_eq!(artifact_report.final_path.as_path(), output_path);
    debug_assert!(artifact_report.byte_size > 0);
    Ok(())
}

fn compiler_mir_ingestion_signature(
    module: &ObjectModule,
    mir_function: &CompilerMirLoweringFunction<'_>,
) -> cranelift_codegen::ir::Signature {
    let mut signature = module.make_signature();
    for param in &mir_function.params {
        signature
            .params
            .push(AbiParam::new(tiny_mir_type_to_cranelift_type(*param)));
    }
    if matches!(
        mir_function.return_type,
        TinyMirType::I32 | TinyMirType::Bool
    ) {
        signature.returns.push(AbiParam::new(types::I32));
    }
    signature
}

fn compiler_mir_ingestion_import_signature(
    module: &ObjectModule,
    imported: &CompilerMirLoweringImportedFunction<'_>,
) -> cranelift_codegen::ir::Signature {
    let mut signature = module.make_signature();
    for param in &imported.params {
        signature
            .params
            .push(AbiParam::new(tiny_mir_type_to_cranelift_type(*param)));
    }
    if matches!(imported.return_type, TinyMirType::I32) {
        signature.returns.push(AbiParam::new(types::I32));
    }
    signature
}

fn lower_compiler_mir_ingestion_module_to_object(
    output_path: &Path,
    mir_module: &CompilerMirLoweringModule<'_>,
) -> Result<(), Box<dyn Error>> {
    compiler_mir_pipeline_wrap_box(
        validate_compiler_mir_module(mir_module),
        CompilerMirPipelineStage::FixtureValidation,
        CompilerMirPipelineFailureKind::InvalidFixture,
    )?;
    for defined in &mir_module.functions {
        compiler_mir_pipeline_wrap_box(
            validate_compiler_mir_ingestion_lowering_readiness(
                &defined.fixture.function,
            ),
            CompilerMirPipelineStage::FixtureValidation,
            CompilerMirPipelineFailureKind::InvalidFixture,
        )?;
        compiler_mir_pipeline_wrap_box(
            recognize_compiler_mir_fixture_metadata(
                &defined.fixture.metadata,
            ),
            CompilerMirPipelineStage::FixtureValidation,
            CompilerMirPipelineFailureKind::InvalidFixture,
        )?;
    }

    let (object_builder, target_contract) =
        compiler_mir_pipeline_wrap_box(
            build_compiler_mir_native_object_builder(mir_module.name),
            CompilerMirPipelineStage::ObjectBuild,
            CompilerMirPipelineFailureKind::UnsupportedTarget,
        )?;
    debug_assert!(target_contract.is_pic);
    let mut module = ObjectModule::new(object_builder);

    let mut imported_link_ids: HashMap<&str, FuncId> = HashMap::new();
    let mut imported_function_ids: HashMap<&str, FuncId> = HashMap::new();
    for imported in &mir_module.imports {
        if !matches!(
            imported.linkage,
            CompilerMirLoweringFunctionLinkage::ImportedHost
                | CompilerMirLoweringFunctionLinkage::ImportedBundle
        ) {
            return Err(compiler_mir_pipeline_error(
                CompilerMirPipelineStage::MirLowering,
                CompilerMirPipelineFailureKind::LoweringFailed,
                format!(
                    "canonical compiler MIR imported function {} must use imported linkage",
                    imported.name
                ),
            ));
        }
        let function_id = if let Some(existing) =
            imported_link_ids.get(imported.link_symbol).copied()
        {
            existing
        } else {
            let signature =
                compiler_mir_ingestion_import_signature(&module, imported);
            let declared = compiler_mir_pipeline_wrap(
                module.declare_function(
                    imported.link_symbol,
                    Linkage::Import,
                    &signature,
                ),
                CompilerMirPipelineStage::MirLowering,
                CompilerMirPipelineFailureKind::LoweringFailed,
            )?;
            imported_link_ids.insert(imported.link_symbol, declared);
            declared
        };
        imported_function_ids.insert(imported.name, function_id);
    }

    let mut local_function_ids: HashMap<&str, FuncId> = HashMap::new();
    for defined in &mir_module.functions {
        let mir_function = &defined.fixture.function;
        let signature =
            compiler_mir_ingestion_signature(&module, mir_function);
        let linkage = match defined.linkage {
            CompilerMirLoweringFunctionLinkage::ExportedEntry
            | CompilerMirLoweringFunctionLinkage::BundleExport => {
                Linkage::Export
            }
            CompilerMirLoweringFunctionLinkage::ModuleLocal => Linkage::Local,
            CompilerMirLoweringFunctionLinkage::ImportedHost
            | CompilerMirLoweringFunctionLinkage::ImportedBundle => {
                return Err(compiler_mir_pipeline_error(
                    CompilerMirPipelineStage::MirLowering,
                    CompilerMirPipelineFailureKind::LoweringFailed,
                    format!(
                        "canonical compiler MIR defined function {} cannot use imported linkage",
                        mir_function.object_name
                    ),
                ));
            }
        };
        let function_id = compiler_mir_pipeline_wrap(
            module.declare_function(
                mir_function.symbol,
                linkage,
                &signature,
            ),
            CompilerMirPipelineStage::MirLowering,
            CompilerMirPipelineFailureKind::LoweringFailed,
        )?;
        local_function_ids.insert(mir_function.object_name, function_id);
    }

    for defined in &mir_module.functions {
        compiler_mir_pipeline_wrap_box(
            define_compiler_mir_ingestion_module_function(
                &mut module,
                defined,
                &local_function_ids,
                &imported_function_ids,
            ),
            CompilerMirPipelineStage::MirLowering,
            CompilerMirPipelineFailureKind::LoweringFailed,
        )?;
    }

    let object_product = module.finish();
    let object_bytes = compiler_mir_pipeline_wrap(
        object_product.emit(),
        CompilerMirPipelineStage::ObjectBuild,
        CompilerMirPipelineFailureKind::ObjectBuildFailed,
    )?;
    let symbol_contract =
        compiler_mir_module_object_symbol_contract(mir_module);
    let inspection_report = compiler_mir_pipeline_wrap_box(
        inspect_compiler_mir_object_artifact(
            &object_bytes,
            Some(&target_contract),
            Some(&symbol_contract),
        ),
        CompilerMirPipelineStage::ObjectVerification,
        CompilerMirPipelineFailureKind::InvalidObject,
    )?;
    debug_assert!(inspection_report.has_code_section);
    let artifact_report = compiler_mir_pipeline_wrap_box(
        publish_compiler_mir_object_artifact(output_path, object_bytes),
        CompilerMirPipelineStage::ObjectPublication,
        CompilerMirPipelineFailureKind::OutputNotWritable,
    )?;
    debug_assert_eq!(artifact_report.final_path.as_path(), output_path);
    debug_assert!(artifact_report.byte_size > 0);
    Ok(())
}

fn define_compiler_mir_ingestion_module_function(
    module: &mut ObjectModule,
    defined: &CompilerMirLoweringDefinedFunction<'_>,
    local_function_ids: &HashMap<&str, FuncId>,
    imported_function_ids: &HashMap<&str, FuncId>,
) -> Result<(), Box<dyn Error>> {
    let mir_function = &defined.fixture.function;
    let function_id = *local_function_ids
        .get(mir_function.object_name)
        .ok_or_else(|| {
            IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "missing canonical compiler MIR declared function id: {}",
                    mir_function.object_name
                ),
            )
        })?;
    let signature = compiler_mir_ingestion_signature(module, mir_function);
    let mut context = module.make_context();
    context.func.signature = signature;

    let mut builder_context = FunctionBuilderContext::new();
    let mut builder = FunctionBuilder::new(&mut context.func, &mut builder_context);
    let mut local_function_refs: HashMap<&str, FuncRef> = HashMap::new();
    for (name, candidate_id) in local_function_ids {
        if *name == mir_function.object_name {
            continue;
        }
        local_function_refs.insert(
            *name,
            module.declare_func_in_func(*candidate_id, builder.func),
        );
    }
    let mut imported_function_refs: HashMap<&str, FuncRef> = HashMap::new();
    for (name, imported_id) in imported_function_ids {
        imported_function_refs.insert(
            *name,
            module.declare_func_in_func(*imported_id, builder.func),
        );
    }
    build_compiler_mir_ingestion_body_with_calls(
        &mut builder,
        mir_function,
        &local_function_refs,
        &imported_function_refs,
    )?;
    builder.finalize();

    module.define_function(function_id, &mut context)?;
    module.clear_context(&mut context);
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
    if matches!(
        mir_function.return_type,
        TinyMirType::I32 | TinyMirType::Bool
    ) {
        signature.returns.push(AbiParam::new(types::I32));
    }

    let function_id = module.declare_function(mir_function.symbol, Linkage::Export, &signature)?;
    let mut context = module.make_context();
    context.func.signature = signature;

    let mut builder_context = FunctionBuilderContext::new();
    let mut builder = FunctionBuilder::new(&mut context.func, &mut builder_context);
    build_compiler_mir_ingestion_body(&mut builder, mir_function)?;
    builder.finalize();

    module.define_function(function_id, &mut context)?;
    module.clear_context(&mut context);
    Ok(())
}

fn lower_compiler_mir_ingestion_edge_arguments(
    builder: &mut FunctionBuilder<'_>,
    edge: &CompilerMirLoweringEdge<'_>,
    function_params: &[cranelift_codegen::ir::Value],
    local_slots: &HashMap<&str, Variable>,
    block_parameter_values: &HashMap<&str, cranelift_codegen::ir::Value>,
    current_block_label: &str,
) -> Result<Vec<BlockArg>, Box<dyn Error>> {
    let mut lowered_arguments = Vec::with_capacity(edge.arguments.len());
    for argument in &edge.arguments {
        let value = match *argument {
            CompilerMirLoweringEdgeArgument::I32Literal(value) => {
                builder.ins().iconst(types::I32, i64::from(value))
            }
            CompilerMirLoweringEdgeArgument::FunctionParamI32(param) => {
                function_params.get(param).copied().ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "unknown compiler MIR lowering function parameter {param} at block {current_block_label}"
                        ),
                    )
                })?
            }
            CompilerMirLoweringEdgeArgument::LocalI32(name) => {
                let slot = *local_slots.get(name).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "unknown compiler MIR lowering edge local {name} at block {current_block_label}"
                        ),
                    )
                })?;
                builder.use_var(slot)
            }
            CompilerMirLoweringEdgeArgument::BlockParamI32(name) => {
                *block_parameter_values.get(name).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "unknown compiler MIR lowering edge block parameter {name} at block {current_block_label}"
                        ),
                    )
                })?
            }
            CompilerMirLoweringEdgeArgument::BlockParamI32AddI32Literal { name, value } => {
                let block_value = *block_parameter_values.get(name).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "unknown compiler MIR lowering edge block parameter {name} at block {current_block_label}"
                        ),
                    )
                })?;
                builder.ins().iadd_imm(block_value, i64::from(value))
            }
        };
        lowered_arguments.push(BlockArg::Value(value));
    }
    Ok(lowered_arguments)
}

fn build_compiler_mir_ingestion_body(
    builder: &mut FunctionBuilder<'_>,
    mir_function: &CompilerMirLoweringFunction<'_>,
) -> Result<(), Box<dyn Error>> {
    let local_function_refs: HashMap<&str, FuncRef> = HashMap::new();
    let imported_function_refs: HashMap<&str, FuncRef> = HashMap::new();
    build_compiler_mir_ingestion_body_with_calls(
        builder,
        mir_function,
        &local_function_refs,
        &imported_function_refs,
    )
}

fn build_compiler_mir_ingestion_body_with_calls(
    builder: &mut FunctionBuilder<'_>,
    mir_function: &CompilerMirLoweringFunction<'_>,
    local_function_refs: &HashMap<&str, FuncRef>,
    imported_function_refs: &HashMap<&str, FuncRef>,
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

        for parameter in &block.parameters {
            let parameter_type = match parameter.ty {
                TinyMirType::I32 => types::I32,
                TinyMirType::Bool | TinyMirType::Void => {
                    return Err(IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "unsupported compiler MIR lowering block parameter type: {} in block {}",
                            parameter.name, block.label
                        ),
                    )
                    .into());
                }
            };
            builder.append_block_param(cranelift_block, parameter_type);
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
            TinyMirType::I32 | TinyMirType::Bool => types::I32,
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

    let block_indices = compiler_mir_cfg_block_indices(mir_function);
    let predecessor_counts = compiler_mir_cfg_predecessor_counts(mir_function)?;
    let mut emitted_predecessors = vec![0usize; mir_function.blocks.len()];
    let mut sealed_blocks = vec![false; mir_function.blocks.len()];
    for (block_index, predecessor_count) in predecessor_counts.iter().enumerate() {
        if *predecessor_count == 0 {
            let block = *cranelift_blocks
                .get(mir_function.blocks[block_index].label)
                .ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "unknown compiler MIR lowering block: {}",
                            mir_function.blocks[block_index].label
                        ),
                    )
                })?;
            builder.seal_block(block);
            sealed_blocks[block_index] = true;
        }
    }

    let lowering_order = compiler_mir_cfg_lowering_order(mir_function)?;
    for block_index in lowering_order {
        let block = &mir_function.blocks[block_index];
        let current_block = *cranelift_blocks.get(block.label).ok_or_else(|| {
            IoError::new(
                ErrorKind::InvalidInput,
                format!("unknown compiler MIR lowering block: {}", block.label),
            )
        })?;
        builder.switch_to_block(current_block);

        let current_cranelift_parameters = builder.block_params(current_block).to_vec();
        if current_cranelift_parameters.len() < block.parameters.len() {
            return Err(IoError::new(
                ErrorKind::InvalidInput,
                format!(
                    "compiler MIR lowering block {} declares {} parameter(s), but Cranelift exposes {}",
                    block.label,
                    block.parameters.len(),
                    current_cranelift_parameters.len()
                ),
            )
            .into());
        }
        let mut block_parameter_values: HashMap<&str, cranelift_codegen::ir::Value> =
            HashMap::new();
        for (parameter, value) in block
            .parameters
            .iter()
            .zip(current_cranelift_parameters.iter().copied())
        {
            if block_parameter_values.insert(parameter.name, value).is_some() {
                return Err(IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "duplicate compiler MIR lowering block parameter {} in block {}",
                        parameter.name, block.label
                    ),
                )
                .into());
            }
        }

        for statement in &block.statements {
            match statement.clone() {
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
                CompilerMirLoweringStatement::LocalI32SetBlockParam {
                    name,
                    block_param,
                } => {
                    let slot = *local_slots.get(name).ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown compiler MIR lowering local set target: {name}"),
                        )
                    })?;
                    let block_value = *block_parameter_values.get(block_param).ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!(
                                "unknown compiler MIR lowering block parameter {block_param} at block {}",
                                block.label
                            ),
                        )
                    })?;
                    builder.def_var(slot, block_value);
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
                CompilerMirLoweringStatement::LocalI32SetCall {
                    name,
                    target,
                    arguments,
                } => {
                    let slot = *local_slots.get(name).ok_or_else(|| {
                        IoError::new(
                            ErrorKind::InvalidInput,
                            format!("unknown compiler MIR lowering call result local: {name}"),
                        )
                    })?;
                    let function_ref = match target {
                        CompilerMirLoweringCallTarget::LocalFunction(callee) => {
                            *local_function_refs.get(callee).ok_or_else(|| {
                                IoError::new(
                                    ErrorKind::InvalidInput,
                                    format!(
                                        "unknown compiler MIR lowering local callee {callee} at block {}",
                                        block.label
                                    ),
                                )
                            })?
                        }
                        CompilerMirLoweringCallTarget::ImportedFunction(callee) => {
                            *imported_function_refs.get(callee).ok_or_else(|| {
                                IoError::new(
                                    ErrorKind::InvalidInput,
                                    format!(
                                        "unknown compiler MIR lowering imported callee {callee} at block {}",
                                        block.label
                                    ),
                                )
                            })?
                        }
                    };
                    let mut lowered_arguments = Vec::with_capacity(arguments.len());
                    for argument in arguments {
                        let value = match argument {
                            CompilerMirLoweringCallArgument::I32Literal(value)
                            | CompilerMirLoweringCallArgument::BoolLiteral(value) => {
                                builder.ins().iconst(types::I32, i64::from(value))
                            }
                            CompilerMirLoweringCallArgument::FunctionParamI32(param) => {
                                function_params.get(param).copied().ok_or_else(|| {
                                    IoError::new(
                                        ErrorKind::InvalidInput,
                                        format!(
                                            "unknown compiler MIR lowering function parameter {param} at block {}",
                                            block.label
                                        ),
                                    )
                                })?
                            }
                            CompilerMirLoweringCallArgument::LocalI32(local) => {
                                let argument_slot = *local_slots.get(local).ok_or_else(|| {
                                    IoError::new(
                                        ErrorKind::InvalidInput,
                                        format!(
                                            "unknown compiler MIR lowering call local {local} at block {}",
                                            block.label
                                        ),
                                    )
                                })?;
                                builder.use_var(argument_slot)
                            }
                            CompilerMirLoweringCallArgument::BlockParamI32(block_param) => {
                                *block_parameter_values.get(block_param).ok_or_else(|| {
                                    IoError::new(
                                        ErrorKind::InvalidInput,
                                        format!(
                                            "unknown compiler MIR lowering call block parameter {block_param} at block {}",
                                            block.label
                                        ),
                                    )
                                })?
                            }
                            CompilerMirLoweringCallArgument::BlockParamI32AddI32Literal {
                                name: block_param,
                                value,
                            } => {
                                let block_value =
                                    *block_parameter_values.get(block_param).ok_or_else(|| {
                                        IoError::new(
                                            ErrorKind::InvalidInput,
                                            format!(
                                                "unknown compiler MIR lowering call block parameter {block_param} at block {}",
                                                block.label
                                            ),
                                        )
                                    })?;
                                builder.ins().iadd_imm(block_value, i64::from(value))
                            }
                        };
                        lowered_arguments.push(value);
                    }
                    let call_inst = builder.ins().call(function_ref, &lowered_arguments);
                    let return_value = builder
                        .inst_results(call_inst)
                        .first()
                        .copied()
                        .ok_or_else(|| {
                            IoError::new(
                                ErrorKind::InvalidInput,
                                format!(
                                    "canonical compiler MIR call at block {} produced no i32 result",
                                    block.label
                                ),
                            )
                        })?;
                    builder.def_var(slot, return_value);
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
            CompilerMirLoweringTerminator::ReturnBlockParamI32(name) => {
                let return_value = *block_parameter_values.get(name).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "unknown compiler MIR lowering return block parameter {name} at block {}",
                            block.label
                        ),
                    )
                })?;
                builder.ins().return_(&[return_value]);
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
                let arguments = lower_compiler_mir_ingestion_edge_arguments(
                    builder,
                    edge,
                    &function_params,
                    &local_slots,
                    &block_parameter_values,
                    block.label,
                )?;
                builder.ins().jump(target_block, &arguments);
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
                let then_arguments = lower_compiler_mir_ingestion_edge_arguments(
                    builder,
                    then_edge,
                    &function_params,
                    &local_slots,
                    &block_parameter_values,
                    block.label,
                )?;
                let else_arguments = lower_compiler_mir_ingestion_edge_arguments(
                    builder,
                    else_edge,
                    &function_params,
                    &local_slots,
                    &block_parameter_values,
                    block.label,
                )?;
                let condition_value = builder.ins().iconst(types::I32, i64::from(*condition));
                let branch_condition = builder.ins().icmp_imm(IntCC::NotEqual, condition_value, 0);
                builder.ins().brif(
                    branch_condition,
                    then_cranelift_block,
                    &then_arguments,
                    else_cranelift_block,
                    &else_arguments,
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
                let then_arguments = lower_compiler_mir_ingestion_edge_arguments(
                    builder,
                    then_edge,
                    &function_params,
                    &local_slots,
                    &block_parameter_values,
                    block.label,
                )?;
                let else_arguments = lower_compiler_mir_ingestion_edge_arguments(
                    builder,
                    else_edge,
                    &function_params,
                    &local_slots,
                    &block_parameter_values,
                    block.label,
                )?;
                let condition_value = builder.use_var(slot);
                let branch_condition =
                    builder
                        .ins()
                        .icmp_imm(IntCC::SignedGreaterThan, condition_value, 0);
                builder.ins().brif(
                    branch_condition,
                    then_cranelift_block,
                    &then_arguments,
                    else_cranelift_block,
                    &else_arguments,
                );
            }
            CompilerMirLoweringTerminator::BranchBlockParamI32Positive {
                name,
                then_edge,
                else_edge,
            } => {
                let condition_value = *block_parameter_values.get(name).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "unknown compiler MIR lowering branch block parameter {name} at block {}",
                            block.label
                        ),
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
                let then_arguments = lower_compiler_mir_ingestion_edge_arguments(
                    builder,
                    then_edge,
                    &function_params,
                    &local_slots,
                    &block_parameter_values,
                    block.label,
                )?;
                let else_arguments = lower_compiler_mir_ingestion_edge_arguments(
                    builder,
                    else_edge,
                    &function_params,
                    &local_slots,
                    &block_parameter_values,
                    block.label,
                )?;
                let branch_condition =
                    builder
                        .ins()
                        .icmp_imm(IntCC::SignedGreaterThan, condition_value, 0);
                builder.ins().brif(
                    branch_condition,
                    then_cranelift_block,
                    &then_arguments,
                    else_cranelift_block,
                    &else_arguments,
                );
            }
        }

        for successor in compiler_mir_cfg_successors(&block.terminator) {
            let successor_index = *block_indices.get(successor).ok_or_else(|| {
                IoError::new(
                    ErrorKind::InvalidInput,
                    format!(
                        "unknown compiler MIR lowering successor {successor} from block {}",
                        block.label
                    ),
                )
            })?;
            emitted_predecessors[successor_index] += 1;
            if emitted_predecessors[successor_index]
                == predecessor_counts[successor_index]
                && !sealed_blocks[successor_index]
            {
                let successor_block = *cranelift_blocks.get(successor).ok_or_else(|| {
                    IoError::new(
                        ErrorKind::InvalidInput,
                        format!("unknown compiler MIR lowering block: {successor}"),
                    )
                })?;
                builder.seal_block(successor_block);
                sealed_blocks[successor_index] = true;
            }
        }
    }

    if sealed_blocks.iter().any(|sealed| !sealed) {
        return Err(IoError::new(
            ErrorKind::InvalidInput,
            "compiler MIR lowering left an unsealed block after all predecessor edges were emitted",
        )
        .into());
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
        TinyMirType::I32 | TinyMirType::Bool => {
            signature.returns.push(AbiParam::new(types::I32))
        }
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
        TinyMirType::I32 | TinyMirType::Bool => {
            signature.returns.push(AbiParam::new(types::I32))
        }
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
