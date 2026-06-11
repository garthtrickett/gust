use crate::ast::{Expression, FieldDef};
use std::collections::{HashMap, HashSet};

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum Type {
    Int,
    Byte,
    Bool,
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

fn strip_std_prefix(s: &str) -> &str {
    if let Some(stripped) = s.strip_prefix("std_") {
        stripped
    } else if let Some(stripped) = s.strip_prefix("std.") {
        stripped
    } else {
        s
    }
}

// Brand crossing rule helper: checks if two types are structurally identical
// but differ only by their value-brands.
pub fn types_match_except_brand(expected: &Type, actual: &Type) -> bool {
    match (expected, actual) {
        (Type::Index(e_struct, _), Type::Index(a_struct, _)) => e_struct == a_struct,
        (Type::Struct(e_struct, _), Type::Struct(a_struct, _)) => e_struct == a_struct,
        (Type::RawPointer(e_inner), Type::RawPointer(a_inner)) => {
            types_match_except_brand(e_inner, a_inner)
        }
        (Type::Slice(e_inner), Type::Slice(a_inner)) => {
            types_match_except_brand(e_inner, a_inner)
        }
        (Type::Generic(e_name, e_args), Type::Generic(a_name, a_args)) => {
            if e_name != a_name || e_args.len() != a_args.len() {
                return false;
            }
            for i in 0..e_args.len() {
                if !types_match_except_brand(&e_args[i], &a_args[i]) {
                    return false;
                }
            }
            true
        }
        _ => types_match(expected, actual),
    } 
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
            let e_clean = strip_std_prefix(e_struct);
            let a_clean = strip_std_prefix(a_struct);
            if e_clean != a_clean && e_clean != "Any" && a_clean != "Any" {
                return false;
            }
            if e_brand.is_none() || a_brand.is_none() {
                return true;
            }
            e_brand == a_brand
        }
        (Type::Struct(e_struct, e_brand), Type::Struct(a_struct, a_brand)) => {
            let e_clean = strip_std_prefix(e_struct);
            let a_clean = strip_std_prefix(a_struct);
            if e_clean != a_clean {
                let is_vector_any = (e_clean.starts_with("Vector_")
                    && a_clean.starts_with("Vector_Any"))
                    || (a_clean.starts_with("Vector_") && e_clean.starts_with("Vector_Any"));
                let is_hashmap_any = (e_clean.starts_with("HashMap_")
                    && a_clean.starts_with("HashMap_Any"))
                    || (a_clean.starts_with("HashMap_") && e_clean.starts_with("HashMap_Any"));
                let is_pool_any = (e_clean.starts_with("Pool_")
                    && a_clean.starts_with("Pool_Any"))
                    || (a_clean.starts_with("Pool_") && e_clean.starts_with("Pool_Any"));
                let is_rc_any = (e_clean.starts_with("Rc_")
                    && a_clean.starts_with("Rc_Any"))
                    || (a_clean.starts_with("Rc_") && e_clean.starts_with("Rc_Any"));
                let is_graph_any = (e_clean.starts_with("Graph_")
                    && a_clean.starts_with("Graph_Any"))
                    || (a_clean.starts_with("Graph_") && e_clean.starts_with("Graph_Any"));
                if !is_vector_any && !is_hashmap_any && !is_pool_any && !is_rc_any && !is_graph_any {
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
    LargeEnumVariantPayload,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TypeError {
    pub kind: TypeErrorKind,
    pub message: String,
    pub span: Option<crate::token::Span>,
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
        Expression::Identifier(name, _) => name.clone(),
        Expression::Integer(val, _) => val.to_string(),
        Expression::String(val, _) => format!("\"{}\"", val),
        Expression::Bool(val, _) => val.to_string(),
        Expression::Call {
            function,
            arguments,
            ..
        } => {
            let args_strs: Vec<String> = arguments.iter().map(expression_to_string).collect();
            format!(
                "{}({})",
                expression_to_string(function),
                args_strs.join(", ")
            )
        }
        Expression::Selector { left, right, .. } => {
            format!("{}.{}", expression_to_string(left), right)
        }
        Expression::IndexAccess { allocator, index, .. } => {
            format!(
                "{}[{}]",
                expression_to_string(allocator),
                expression_to_string(index)
            )
        }
        Expression::Move(inner, _) => expression_to_string(inner),
        Expression::Take(inner, _) => expression_to_string(inner),
        Expression::Binary { op, left, right, .. } => {
            format!(
                "{} {} {}",
                expression_to_string(left),
                op,
                expression_to_string(right)
            )
        }
        Expression::AsCast { left, .. } => expression_to_string(left),
        Expression::AddressOf(inner, _) => format!("&{}", expression_to_string(inner)),
        Expression::Dereference(inner, _) => format!("*{}", expression_to_string(inner)),
        Expression::Empty(target_type, _) => format!("empty[{:?}]", target_type),
    }
}

pub fn format_diagnostic(source: &str, error: &TypeError) -> String {
    if let Some(span) = error.span {
        let lines: Vec<&str> = source.lines().collect();
        let line_idx = if span.start.line > 0 { span.start.line - 1 } else { 0 };
        let line_content = if line_idx < lines.len() {
            lines[line_idx]
        } else {
            ""
        };

        let start_col = span.start.column;
        let end_col = if span.start.line == span.end.line {
            span.end.column
        } else {
            line_content.len() + 1
        };

        let width = if end_col > start_col { end_col - start_col } else { 1 };
        let padding = " ".repeat(start_col.saturating_sub(1));
        let carets = "^".repeat(width);

        let mut out = String::new();
        out.push_str(&format!(
            "[line {}:{}] input.gst: {:?}\n",
            span.start.line, span.start.column, error.kind
        ));
        out.push_str(&format!("{:4} | {}\n", span.start.line, line_content));
        out.push_str(&format!("     | {}{}\n", padding, carets));
        out.push_str(&format!("Error: {}\n", error.message));
        out
    } else {
        format!("Error [{:?}]: {}\n", error.kind, error.message)
    }
}
