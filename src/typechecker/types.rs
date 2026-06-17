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

fn strip_module_prefixes(s: &str) -> String {
    let mut clean = s.to_string();
    for prefix in &["ast_", "lexer_", "parser_", "errors_", "token_"] {
        clean = clean.replace(prefix, "");
    }
    clean
}

pub fn strip_brand_prefix(brand: &str) -> &str {
    if let Some(pos) = brand.rfind("__") {
        &brand[pos + 2..]
    } else {
        brand
    }
}

pub fn normalize_struct_name(name: &str, brand: &Option<String>) -> String {
    let mut clean = name.to_string();
    if let Some(b) = brand {
        let stripped_b = strip_brand_prefix(b);
        let old_suffix = format!("_{}", b);
        let new_suffix = format!("_{}", stripped_b);
        if clean.ends_with(&old_suffix) {
            clean = format!("{}{}", &clean[..clean.len() - old_suffix.len()], new_suffix);
        }
    }
    clean
}

pub fn clean_monomorphized_name(name: &str) -> String {
    let mut erased = name.to_string();
    let brand_bases = ["connCtx", "arena", "ctx", "Any", "a"];
    let mut changed = true;
    while changed {
        changed = false;
        for base in &brand_bases {
            let ns_suffix = format!("__{}", base);
            if erased.ends_with(&ns_suffix) {
                let pos = erased.len() - ns_suffix.len();
                if let Some(start_pos) = erased[..pos].rfind('_') {
                    if !erased[..pos].ends_with("__") {
                        erased.truncate(start_pos);
                        changed = true;
                        break;
                    }
                }
            }
            let ns_mid = format!("__{}_", base);
            if let Some(pos) = erased.find(&ns_mid)
                && let Some(start_pos) = erased[..pos].rfind('_')
            {
                if !erased[..pos].ends_with("__") {
                    erased.replace_range(start_pos..pos + ns_mid.len() - 1, "");
                    changed = true;
                    break;
                }
            }
            let flat_suffix = format!("_{}", base);
            if erased.ends_with(&flat_suffix) {
                erased.truncate(erased.len() - flat_suffix.len());
                changed = true;
                break;
            }
            let flat_mid = format!("_{}_", base);
            if let Some(pos) = erased.find(&flat_mid) {
                erased.replace_range(pos..pos + flat_mid.len() - 1, "");
                changed = true;
                break;
            }
        }
    }
    erased
}

// Brand crossing rule helper: checks if two types are structurally identical
// but differ only by their value-brands.
pub fn types_match_except_brand(expected: &Type, actual: &Type) -> bool {
    match (expected, actual) {
        (Type::Struct(e_name, _), Type::Str) if e_name == "str" => true,
        (Type::Str, Type::Struct(a_name, _)) if a_name == "str" => true,
        (Type::Index(e_name, _), Type::Str) if e_name == "str" => true,
        (Type::Str, Type::Index(a_name, _)) if a_name == "str" => true,
        (Type::Index(e_struct, _), Type::Index(a_struct, _)) => {
            let e_norm = normalize_struct_name(e_struct, &None);
            let a_norm = normalize_struct_name(a_struct, &None);
            let e_clean = strip_module_prefixes(strip_std_prefix(&e_norm));
            let a_clean = strip_module_prefixes(strip_std_prefix(&a_norm));
            let e_clean_final = clean_monomorphized_name(&e_clean);
            let a_clean_final = clean_monomorphized_name(&a_clean);
            if e_clean_final.contains("__GUST_MONO_RESOLVE_TEMP_")
                || a_clean_final.contains("__GUST_MONO_RESOLVE_TEMP_")
                || e_clean_final.contains("__PLACEHOLDER_")
                || a_clean_final.contains("__PLACEHOLDER_")
            {
                return true;
            }
            e_clean_final == a_clean_final
        }
        (Type::Struct(e_struct, _), Type::Struct(a_struct, _)) => {
            let e_norm = normalize_struct_name(e_struct, &None);
            let a_norm = normalize_struct_name(a_struct, &None);
            let e_clean = strip_module_prefixes(strip_std_prefix(&e_norm));
            let a_clean = strip_module_prefixes(strip_std_prefix(&a_norm));
            let e_clean_final = clean_monomorphized_name(&e_clean);
            let a_clean_final = clean_monomorphized_name(&a_clean);
            if e_clean_final.contains("__GUST_MONO_RESOLVE_TEMP_")
                || a_clean_final.contains("__GUST_MONO_RESOLVE_TEMP_")
                || e_clean_final.contains("__PLACEHOLDER_")
                || a_clean_final.contains("__PLACEHOLDER_")
            {
                return true;
            }
            e_clean_final == a_clean_final
        }
        (Type::RawPointer(e_inner), Type::RawPointer(a_inner)) => {
            types_match_except_brand(e_inner, a_inner)
        }
        (Type::Slice(e_inner), Type::Slice(a_inner)) => types_match_except_brand(e_inner, a_inner),
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
        (Type::Struct(e_name, _), Type::Str) if e_name == "str" => true,
        (Type::Str, Type::Struct(a_name, _)) if a_name == "str" => true,
        (Type::Index(e_name, _), Type::Str) if e_name == "str" => true,
        (Type::Str, Type::Index(a_name, _)) if a_name == "str" => true,
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
            let e_norm = normalize_struct_name(e_struct, e_brand);
            let a_norm = normalize_struct_name(a_struct, a_brand);
            let e_clean = strip_module_prefixes(strip_std_prefix(&e_norm));
            let a_clean = strip_module_prefixes(strip_std_prefix(&a_norm));
            let e_clean_final = clean_monomorphized_name(&e_clean);
            let a_clean_final = clean_monomorphized_name(&a_clean);
            if e_clean_final.contains("__GUST_MONO_RESOLVE_TEMP_")
                || a_clean_final.contains("__GUST_MONO_RESOLVE_TEMP_")
                || e_clean_final.contains("__PLACEHOLDER_")
                || a_clean_final.contains("__PLACEHOLDER_")
            {
                return true;
            }
            if e_clean_final != a_clean_final && e_clean_final != "Any" && a_clean_final != "Any" {
                return false;
            }
            if e_brand.is_none()
                || a_brand.is_none()
                || e_brand.as_deref() == Some("Any")
                || a_brand.as_deref() == Some("Any")
            {
                return true;
            }
            let e_b = e_brand.as_ref().map(|b| strip_brand_prefix(b));
            let a_b = a_brand.as_ref().map(|b| strip_brand_prefix(b));
            e_b == a_b
        }
        (Type::Struct(e_struct, e_brand), Type::Struct(a_struct, a_brand)) => {
            let e_norm = normalize_struct_name(e_struct, e_brand);
            let a_norm = normalize_struct_name(a_struct, a_brand);
            let e_clean = strip_module_prefixes(strip_std_prefix(&e_norm));
            let a_clean = strip_module_prefixes(strip_std_prefix(&a_norm));
            let e_clean_final = clean_monomorphized_name(&e_clean);
            let a_clean_final = clean_monomorphized_name(&a_clean);
            if e_clean_final.contains("__GUST_MONO_RESOLVE_TEMP_")
                || a_clean_final.contains("__GUST_MONO_RESOLVE_TEMP_")
                || e_clean_final.contains("__PLACEHOLDER_")
                || a_clean_final.contains("__PLACEHOLDER_")
            {
                return true;
            }
            if e_clean_final != a_clean_final {
                let is_vector_any = (e_clean_final.starts_with("Vector_")
                    && a_clean_final == "Vector")
                    || (a_clean_final.starts_with("Vector_") && e_clean_final == "Vector");
                let is_hashmap_any = (e_clean_final.starts_with("HashMap_")
                    && a_clean_final == "HashMap")
                    || (a_clean_final.starts_with("HashMap_") && e_clean_final == "HashMap");
                let is_pool_any = (e_clean_final.starts_with("Pool_") && a_clean_final == "Pool")
                    || (a_clean_final.starts_with("Pool_") && e_clean_final == "Pool");
                let is_rc_any = (e_clean_final.starts_with("Rc_") && a_clean_final == "Rc")
                    || (a_clean_final.starts_with("Rc_") && e_clean_final == "Rc");
                let is_graph_any = (e_clean_final.starts_with("Graph_")
                    && a_clean_final == "Graph")
                    || (a_clean_final.starts_with("Graph_") && e_clean_final == "Graph");
                let is_mutex_any = (e_clean_final.starts_with("Mutex_")
                    && a_clean_final == "Mutex")
                    || (a_clean_final.starts_with("Mutex_") && e_clean_final == "Mutex");
                let is_channel_any = (e_clean_final.starts_with("Channel_")
                    && a_clean_final == "Channel")
                    || (a_clean_final.starts_with("Channel_") && e_clean_final == "Channel");
                let is_tl_any = (e_clean_final.starts_with("ThreadLocalContext_")
                    && a_clean_final == "ThreadLocalContext")
                    || (a_clean_final.starts_with("ThreadLocalContext_")
                        && e_clean_final == "ThreadLocalContext");
                if !is_vector_any
                    && !is_hashmap_any
                    && !is_pool_any
                    && !is_rc_any
                    && !is_graph_any
                    && !is_mutex_any
                    && !is_channel_any
                    && !is_tl_any
                {
                    return false;
                }
            }
            if e_brand.is_none()
                || a_brand.is_none()
                || e_brand.as_deref() == Some("Any")
                || a_brand.as_deref() == Some("Any")
            {
                return true;
            }
            let e_b = e_brand.as_ref().map(|b| strip_brand_prefix(b));
            let a_b = a_brand.as_ref().map(|b| strip_brand_prefix(b));
            e_b == a_b
        }
        (Type::Slice(e_inner), Type::Slice(a_inner)) => types_match(e_inner, a_inner),
        (Type::RawPointer(e_inner), Type::RawPointer(a_inner)) => types_match(e_inner, a_inner),
        _ => expected == actual,
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TypeErrorKind {
    SyntaxError,
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
    DuplicateFunctionDefinition,
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
pub struct EnumTemplate {
    pub generics: Vec<String>,
    pub variants: Vec<crate::ast::VariantDef>,
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
        Expression::IndexAccess {
            allocator, index, ..
        } => {
            format!(
                "{}[{}]",
                expression_to_string(allocator),
                expression_to_string(index)
            )
        }
        Expression::Move(inner, _) => expression_to_string(inner),
        Expression::Take(inner, _) => expression_to_string(inner),
        Expression::Binary {
            op, left, right, ..
        } => {
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
        let line_idx = if span.start.line > 0 {
            span.start.line - 1
        } else {
            0
        };
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

        let width = if end_col > start_col {
            end_col - start_col
        } else {
            1
        };
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

pub fn extract_brand_from_suffix(suffix: &str) -> Option<String> {
    let brands = [
        "ctx", "connCtx", "arena", "a", "Any", 
        "ctx1", "ctx2", "innerCtx", "outerCtx", 
        "current_ctx", "next_ctx"
    ];
    if brands.contains(&suffix) {
        return Some(suffix.to_string());
    }
    for brand in &brands {
        let pattern1 = format!("_{}", brand);
        let pattern2_str = format!("__{}", brand);
        if suffix.ends_with(&pattern1) || suffix.ends_with(&pattern2_str) {
            return Some(brand.to_string());
        }
    }
    None
}
