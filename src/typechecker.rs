pub mod monomorphize;
pub mod types;
pub mod visitor;

pub use types::{
    FunctionSignature, StructLayout, StructTemplate, Type, TypeError, TypeErrorKind,
    expression_to_string, types_match, format_diagnostic,
};

use std::collections::{HashMap, HashSet};

pub struct TypeChecker {
    pub current_prefix: String,
    pub imports: HashMap<String, String>,
    pub resolved_names: HashMap<crate::token::Span, String>,
    pub resolved_types: HashMap<crate::token::Span, Type>,
    pub(crate) symbol_table: HashMap<String, Type>,
    pub variable_types: HashMap<String, Type>,
    pub(crate) moved_vars: HashSet<String>,
    pub(crate) in_unsafe_block: bool,
    pub struct_registry: HashMap<String, StructLayout>,
    pub(crate) struct_templates: HashMap<String, StructTemplate>,
    pub enum_registry: HashMap<String, Vec<String>>, // Added Enum Registry
    pub(crate) variable_origins: HashMap<String, HashSet<String>>, // Upgraded to Set-Based Union Tracker
    pub function_registry: HashMap<String, FunctionSignature>,     // Function Registry
    pub(crate) expected_return_type: Option<Type>,
    pub(crate) current_function_return_origins: Option<HashSet<String>>, // Track return statement origins
    pub checked_results: HashSet<String>, // Added for Definite Check Rule
    pub(crate) current_function_inout_params: Option<Vec<String>>, // Track inout parameters for return checks
    pub(crate) current_function_local_vars: Option<HashSet<String>>, // Track local variables inside function body
}

impl Default for TypeChecker {
    fn default() -> Self {
        Self::new()
    }
}

impl TypeChecker {
    pub(crate) fn resolve_type_namespacing(&self, t: &Type) -> Result<Type, TypeError> { 
        match t {
            Type::Struct(name, brand) => {
                let resolved_name = self.resolve_namespaced_ident(name)?;
                Ok(Type::Struct(resolved_name, brand.clone()))
            }
            Type::Index(name, brand) => {
                let resolved_name = self.resolve_namespaced_ident(name)?;
                Ok(Type::Index(resolved_name, brand.clone()))
            }
            Type::RawPointer(inner) => {
                let resolved = self.resolve_type_namespacing(inner)?;
                Ok(Type::RawPointer(Box::new(resolved)))
            }
            Type::Slice(inner) => {
                let resolved = self.resolve_type_namespacing(inner)?;
                Ok(Type::Slice(Box::new(resolved)))
            }
            Type::Generic(name, args) => {
                let resolved_name = self.resolve_namespaced_ident(name)?;
                let mut resolved_args = Vec::new();
                for arg in args { 
                    resolved_args.push(self.resolve_type_namespacing(arg)?);
                }
                Ok(Type::Generic(resolved_name, resolved_args))
            }
            _ => Ok(t.clone()),
        }
    }

    pub(crate) fn resolve_namespaced_ident(&self, name: &str) -> Result<String, TypeError> { 
        if name == "int" || name == "byte" || name == "bool" || name == "str" || name == "Arena" || name == "os_Arena" || name == "os.Arena" || name == "void" || name == "Any" { 
            return Ok(name.to_string());
        }
        if let Some(pos) = name.find('.') {
            let alias = &name[..pos];
            let rest = &name[pos+1..];
            if let Some(prefix) = self.imports.get(alias) { 
                return Ok(format!("{}{}", prefix, rest));
            } else {
                return Err(TypeError { 
                    kind: TypeErrorKind::TypeMismatch,
                    message: format!("Semantic Error: Unresolved namespace alias '{}'", alias),
                    span: None,
                });
            }
        }
        if name.contains("__") { 
            return Ok(name.to_string());
        }
        Ok(format!("{}{}", self.current_prefix, name))
    } 
}

impl TypeChecker {
    pub fn is_linear(&self, t: &Type) -> bool {
        let mut visited = HashSet::new();
        self.is_linear_impl(t, &mut visited)
    }

    fn is_linear_impl(&self, t: &Type, visited: &mut HashSet<String>) -> bool {
        match t {
            Type::Int | Type::Byte | Type::Bool | Type::Void | Type::Index(_, _) => false,
            Type::Arena | Type::RawPointer(_) | Type::Slice(_) | Type::ByteSlice | Type::Str => true,
            Type::Generic(_, _) => true,
            Type::Struct(name, _) => {
                if name == "T" || name == "K" || name == "V" {
                    return true;
                }
                if visited.contains(name) {
                    return false;
                }
                visited.insert(name.clone());
                if let Some(layout) = self.struct_registry.get(name) {
                    for field_type in layout.fields.values() {
                        if self.is_linear_impl(field_type, visited) {
                            return true;
                        }
                    }
                    false
                } else {
                    true // Conservative fallback
                }
            }
        }
    }

    pub fn contains_ephemeral_view(&self, t: &Type) -> bool {
        let mut visited = HashSet::new();
        self.contains_ephemeral_view_impl(t, &mut visited)
    }

    fn contains_ephemeral_view_impl(&self, t: &Type, visited: &mut HashSet<String>) -> bool {
        match t {
            Type::Str | Type::ByteSlice | Type::Slice(_) => true,
            Type::Struct(name, _) => {
                if visited.contains(name) {
                    return false;
                }
                visited.insert(name.clone());
                if let Some(layout) = self.struct_registry.get(name) {
                    for field_type in layout.fields.values() {
                        if self.contains_ephemeral_view_impl(field_type, visited) {
                            return true;
                        }
                    }
                }
                false
            }
            Type::RawPointer(inner) => self.contains_ephemeral_view_impl(inner, visited),
            _ => false,
        }
    }

    pub fn insert_symbol(&mut self, name: String, t: Type) {
        self.symbol_table.insert(name.clone(), t.clone());
        let mut origins = HashSet::new();
        origins.insert(name.clone());
        self.variable_origins.insert(name, origins);
    }

    pub fn new() -> Self {
        let mut struct_registry = HashMap::new();

        // Backwards-compatible SessionNode definition
        let mut session_node_fields = HashMap::new();
        session_node_fields.insert("SessionID".to_string(), Type::Int);
        session_node_fields.insert(
            "Next".to_string(),
            Type::Index("SessionNode".to_string(), Some("connCtx".to_string())),
        );
        struct_registry.insert(
            "SessionNode".to_string(),
            StructLayout {
                brand: Some("connCtx".to_string()),
                fields: session_node_fields,
            },
        );

        // Backwards-compatible APIRequest definition
        let mut api_fields = HashMap::new();
        api_fields.insert("UserID".to_string(), Type::Int);
        api_fields.insert("SessionID".to_string(), Type::Int);
        api_fields.insert("Active".to_string(), Type::Int);
        struct_registry.insert(
            "APIRequest".to_string(),
            StructLayout {
                brand: None,
                fields: api_fields,
            },
        );

        let mut struct_templates = HashMap::new();

        // Vector[T, ctx]
        let vector_fields = vec![
            crate::ast::FieldDef {
                name: "data".to_string(),
                field_type: Type::RawPointer(Box::new(Type::Struct("T".to_string(), None))),
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "len".to_string(),
                field_type: Type::Int,
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "capacity".to_string(),
                field_type: Type::Int,
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "arena".to_string(),
                field_type: Type::RawPointer(Box::new(Type::Arena)),
                span: crate::token::Span::dummy(),
            },
        ];
        struct_templates.insert(
            "Vector".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: vector_fields.clone(),
            },
        );
        struct_templates.insert(
            "std.Vector".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: vector_fields.clone(),
            },
        );
        struct_templates.insert(
            "std_Vector".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: vector_fields,
            },
        );

        // HashMap[K, V, ctx]
        let hashmap_fields = vec![
            crate::ast::FieldDef {
                name: "keys".to_string(),
                field_type: Type::RawPointer(Box::new(Type::Struct("K".to_string(), None))),
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "values".to_string(),
                field_type: Type::RawPointer(Box::new(Type::Struct("V".to_string(), None))),
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "occupied".to_string(),
                field_type: Type::RawPointer(Box::new(Type::Int)),
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "len".to_string(),
                field_type: Type::Int,
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "capacity".to_string(),
                field_type: Type::Int,
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "arena".to_string(),
                field_type: Type::RawPointer(Box::new(Type::Arena)),
                span: crate::token::Span::dummy(),
            },
        ];
        struct_templates.insert(
            "HashMap".to_string(),
            StructTemplate {
                generics: vec!["K".to_string(), "V".to_string(), "ctx".to_string()],
                fields: hashmap_fields.clone(),
            },
        );
        struct_templates.insert(
            "std.HashMap".to_string(),
            StructTemplate {
                generics: vec!["K".to_string(), "V".to_string(), "ctx".to_string()],
                fields: hashmap_fields.clone(),
            },
        );
        struct_templates.insert(
            "std_HashMap".to_string(),
            StructTemplate {
                generics: vec!["K".to_string(), "V".to_string(), "ctx".to_string()],
                fields: hashmap_fields,
            },
        );

        // Pool[T, ctx]
        let pool_fields = vec![
            crate::ast::FieldDef {
                name: "data".to_string(),
                field_type: Type::RawPointer(Box::new(Type::Struct("T".to_string(), None))),
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "occupied".to_string(),
                field_type: Type::RawPointer(Box::new(Type::Int)),
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "free_list".to_string(),
                field_type: Type::RawPointer(Box::new(Type::Int)),
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "len".to_string(),
                field_type: Type::Int,
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "capacity".to_string(),
                field_type: Type::Int,
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "free_len".to_string(),
                field_type: Type::Int,
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "arena".to_string(),
                field_type: Type::RawPointer(Box::new(Type::Arena)),
                span: crate::token::Span::dummy(),
            },
        ];
        struct_templates.insert(
            "Pool".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: pool_fields.clone(),
            },
        );
        struct_templates.insert(
            "std.Pool".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: pool_fields.clone(),
            },
        );
        struct_templates.insert(
            "std_Pool".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: pool_fields,
            },
        );

        // RcNode[T]
        let rc_node_fields = vec![
            crate::ast::FieldDef {
                name: "value".to_string(),
                field_type: Type::Struct("T".to_string(), None),
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "ref_count".to_string(),
                field_type: Type::Int,
                span: crate::token::Span::dummy(),
            },
        ];
        struct_templates.insert(
            "RcNode".to_string(),
            StructTemplate {
                generics: vec!["T".to_string()],
                fields: rc_node_fields.clone(),
            },
        );
        struct_templates.insert( 
            "std.RcNode".to_string(),
            StructTemplate {
                generics: vec!["T".to_string()],
                fields: rc_node_fields.clone(),
            },
        );
        struct_templates.insert( 
            "std_RcNode".to_string(),
            StructTemplate {
                generics: vec!["T".to_string()],
                fields: rc_node_fields,
            },
        );

        // Rc[T, ctx]
        let rc_fields = vec![
            crate::ast::FieldDef {
                name: "node_index".to_string(),
                field_type: Type::Index("std_RcNode_T".to_string(), Some("ctx".to_string())),
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "pool".to_string(),
                field_type: Type::RawPointer(Box::new(Type::Generic(
                    "std.Pool".to_string(),
                    vec![
                        Type::Struct("std_RcNode_T".to_string(), None),
                        Type::Struct("ctx".to_string(), None),
                    ],
                ))),
                span: crate::token::Span::dummy(),
            },
        ];
        struct_templates.insert(
            "Rc".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: rc_fields.clone(),
            },
        );
        struct_templates.insert(
            "std.Rc".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: rc_fields.clone(),
            },
        );
        struct_templates.insert(
            "std_Rc".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: rc_fields,
            },
        );

        // GraphNode[T, ctx]
        let graph_node_fields = vec![
            crate::ast::FieldDef {
                name: "value".to_string(),
                field_type: Type::Struct("T".to_string(), None),
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "edges".to_string(),
                field_type: Type::Generic(
                    "std.Vector".to_string(),
                    vec![Type::Int, Type::Struct("ctx".to_string(), None)],
                ),
                span: crate::token::Span::dummy(),
            },
        ];
        struct_templates.insert(
            "GraphNode".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: graph_node_fields.clone(),
            },
        );
        struct_templates.insert(
            "std.GraphNode".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: graph_node_fields.clone(),
            },
        );
        struct_templates.insert(
            "std_GraphNode".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: graph_node_fields,
            },
        );

        // Graph[T, ctx]
        let graph_fields = vec![
            crate::ast::FieldDef {
                name: "nodes".to_string(),
                field_type: Type::Generic(
                    "std.Pool".to_string(),
                    vec![
                        Type::Struct("std_GraphNode_T_ctx".to_string(), None),
                        Type::Struct("ctx".to_string(), None),
                    ],
                ),
                span: crate::token::Span::dummy(),
            },
        ];
        struct_templates.insert(
            "Graph".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: graph_fields.clone(),
            },
        );
        struct_templates.insert(
            "std.Graph".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: graph_fields.clone(),
            },
        );
        struct_templates.insert(
            "std_Graph".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: graph_fields,
            },
        );

        TypeChecker {
            current_prefix: "".to_string(),
            imports: HashMap::new(),
            resolved_names: HashMap::new(),
            resolved_types: HashMap::new(),
            symbol_table: HashMap::new(),
            variable_types: HashMap::new(),
            moved_vars: HashSet::new(),
            in_unsafe_block: false,
            struct_registry,
            struct_templates,
            enum_registry: HashMap::new(),
            variable_origins: HashMap::new(),
            function_registry: HashMap::new(),
            expected_return_type: None,
            current_function_return_origins: None,
            checked_results: HashSet::new(),
            current_function_inout_params: None,
            current_function_local_vars: None,
        }
    }
}
