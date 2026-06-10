use crate::ast::{Expression, FieldDef};
use std::collections::{HashMap, HashSet};

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum Type {
    Int,
    Byte,
    Void,
    Arena,
    ByteSlice, // Kept for legacy definitions
    Slice(Box<Type>),
    Index(String, Option<String>),
    Struct(String, Option<String>),
    RawPointer(Box<Type>),
    Generic(String, Vec<Type>),
    Str, // Added for String Views Option 2
}

pub fn types_match(expected: &Type, actual: &Type) -> bool {
    match (expected, actual) {
        (Type::Int, Type::Byte) | (Type::Byte, Type::Int) => true,
        (Type::RawPointer(e_inner), Type::Arena) if matches!(**e_inner, Type::Arena) => true,
        (Type::Arena, Type::RawPointer(a_inner)) if matches!(**a_inner, Type::Arena) => true,
        (Type::Generic(e_name, e_args), Type::Generic(a_name, a_args)) => {
            if e_name != a_name || e_args.len() != a_args.len() {
                return false;
            }
            for i in 0..e_args.len() {
                if !types_match(&e_args[i], &a_args[i]) {
                    return false;
                }
            }
            true
        }
        (Type::Index(e_struct, e_brand), Type::Index(a_struct, a_brand)) => {
            if e_struct != a_struct && e_struct != "Any" && a_struct != "Any" {
                return false;
            }
            if e_brand.is_none() || a_brand.is_none() {
                return true;
            }
            e_brand == a_brand
        }
        (Type::Struct(e_struct, e_brand), Type::Struct(a_struct, a_brand)) => {
            if e_struct != a_struct {
                let is_vector_any = (e_struct.starts_with("Vector_")
                    && a_struct.starts_with("Vector_Any"))
                    || (a_struct.starts_with("Vector_") && e_struct.starts_with("Vector_Any"));
                let is_hashmap_any = (e_struct.starts_with("HashMap_")
                    && a_struct.starts_with("HashMap_Any"))
                    || (a_struct.starts_with("HashMap_") && e_struct.starts_with("HashMap_Any"));
                if !is_vector_any && !is_hashmap_any {
                    return false;
                }
            }
            if e_brand.is_none() || a_brand.is_none() {
                return true;
            }
            e_brand == a_brand
        }
        (Type::Slice(e_inner), Type::Slice(a_inner)) => types_match(e_inner, a_inner),
        (Type::RawPointer(e_inner), Type::RawPointer(a_inner)) => types_match(e_inner, a_inner),
        _ => expected == actual,
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TypeErrorKind {
    UninitializedVariable,
    TypeMismatch,
    LoopConditionInvalid,
    IfConditionInvalid,
    ReturnOutsideFunction,
    TemplateNotFound,
    TemplateArgumentMismatch,
    UseOfMovedVariable,
    VariableOriginInvalidated,
    AllocatorMovedOrFreed,
    UndefinedVariable,
    InvalidMoveTarget,
    TakePrimitiveBanned,
    UnsafeProhibited,
    DereferenceNonPointer,
    InvalidCast,
    InvalidIndexType,
    BrandLifetimeViolation,
    InvalidIndexTarget,
    FieldNotFound,
    MethodNotFound,
    UnresolvedSelector,
    ArgumentMismatch,
    UndefinedFunction,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TypeError {
    pub kind: TypeErrorKind,
    pub message: String,
}

impl std::fmt::Display for TypeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Semantic Error [{:?}]: {}", self.kind, self.message)
    }
}

#[derive(Debug, Clone)]
pub struct StructLayout {
    pub brand: Option<String>,
    pub fields: HashMap<String, Type>,
}

#[derive(Debug, Clone)]
pub struct StructTemplate {
    pub generics: Vec<String>,
    pub fields: Vec<FieldDef>,
}

#[derive(Debug, Clone)]
pub struct FunctionSignature {
    pub param_names: Vec<String>,
    pub params: Vec<Type>,
    pub return_type: Type,
    pub return_origins: HashSet<String>, // Added Set-Based formal return origins
}

pub fn expression_to_string(expr: &Expression) -> String {
    match expr {
        Expression::Identifier(name) => name.clone(),
        Expression::Integer(val) => val.to_string(),
        Expression::String(val) => format!("\"{}\"", val),
        Expression::Call {
            function,
            arguments,
        } => {
            let args_strs: Vec<String> = arguments.iter().map(expression_to_string).collect();
            format!(
                "{}({})",
                expression_to_string(function),
                args_strs.join(", ")
            )
        }
        Expression::Selector { left, right } => {
            format!("{}.{}", expression_to_string(left), right)
        }
        Expression::IndexAccess { allocator, index } => {
            format!(
                "{}[{}]",
                expression_to_string(allocator),
                expression_to_string(index)
            )
        }
        Expression::Move(inner) => expression_to_string(inner),
        Expression::Take(inner) => expression_to_string(inner),
        Expression::Binary { op, left, right } => {
            format!(
                "{} {} {}",
                expression_to_string(left),
                op,
                expression_to_string(right)
            )
        }
        Expression::AsCast { left, .. } => expression_to_string(left),
        Expression::AddressOf(inner) => format!("&{}", expression_to_string(inner)),
        Expression::Dereference(inner) => format!("*{}", expression_to_string(inner)),
    }
}
