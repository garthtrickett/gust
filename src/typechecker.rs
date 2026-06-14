pub mod monomorphize;
pub mod types;
pub mod visitor;

pub use types::{
    FunctionSignature, StructLayout, StructTemplate, Type, TypeError, TypeErrorKind,
    expression_to_string, format_diagnostic, types_match,
};

use std::collections::{HashMap, HashSet};

pub struct TypeChecker {
    pub current_prefix: String,
    pub imports: HashMap<String, String>,
    pub resolved_names: HashMap<crate::token::Span, String>,
    pub resolved_types: HashMap<crate::token::Span, Type>,
    pub symbol_table: HashMap<String, Type>,
    pub variable_types: HashMap<String, Type>,
    pub(crate) moved_vars: HashSet<String>,
    pub(crate) in_unsafe_block: bool,
    pub struct_registry: HashMap<String, StructLayout>,
    pub(crate) struct_templates: HashMap<String, StructTemplate>,
    pub(crate) enum_templates: HashMap<String, types::EnumTemplate>,
    pub enum_registry: HashMap<String, Vec<String>>, // Added Enum Registry
    pub variable_origins: HashMap<String, HashSet<String>>, // Upgraded to Set-Based Union Tracker
    pub all_variable_origins: HashMap<String, HashSet<String>>,
    pub function_registry: HashMap<String, FunctionSignature>, // Function Registry
    pub(crate) expected_return_type: Option<Type>,
    pub(crate) current_function_return_origins: Option<HashSet<String>>, // Track return statement origins
    pub checked_results: HashSet<String>, // Added for Definite Check Rule
    pub(crate) current_function_inout_params: Option<Vec<String>>, // Track inout parameters for return checks
    pub(crate) current_function_local_vars: Option<HashSet<String>>, // Track local variables inside function body
    pub(crate) open_directories: HashSet<String>,
    pub(crate) module_imports: HashMap<String, HashMap<String, String>>,
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
        if let Some(suffix) = name.strip_prefix("LookupResult_") {
            let resolved_suffix = self.resolve_namespaced_ident(suffix)?;
            return Ok(format!("LookupResult_{}", resolved_suffix));
        }
        if let Some(suffix) = name.strip_prefix("CastResult_") {
            let resolved_suffix = self.resolve_namespaced_ident(suffix)?;
            return Ok(format!("CastResult_{}", resolved_suffix));
        }

        let prefixes = [
            "std_Vector_",
            "std_HashMap_",
            "std_Pool_",
            "std_RcNode_",
            "std_Rc_",
            "std_GraphNode_",
            "std_Graph_",
            "std_Mutex_",
            "std_Channel_",
            "std_GenerationalArena_",
            "std_ThreadLocalContext_",
            "os_Dir_",
            "os_DirEntry_",
        ];
        for prefix in &prefixes {
            if let Some(suffix) = name.strip_prefix(prefix) {
                if suffix.contains("__") {
                    return Ok(name.to_string());
                }
                let normalized = suffix.replace("__", "@");
                let parts: Vec<&str> = normalized.split('_').collect();
                let mut resolved_parts = Vec::new();
                let mut active_prefix = self.current_prefix.clone();
                for part in parts {
                    let clean_part = part.replace("@", "__");
                    if let Some(import_prefix) = self.imports.get(&clean_part) {
                        active_prefix = import_prefix.clone();
                    } else {
                        let temp_resolved = if clean_part == "len"
                            || clean_part == "int"
                            || clean_part == "byte"
                            || clean_part == "bool"
                            || clean_part == "str"
                            || clean_part == "Arena"
                            || clean_part == "os_Arena"
                            || clean_part == "os.Arena"
                            || clean_part == "void"
                            || clean_part == "Any"
                            || clean_part == "SessionNode"
                            || clean_part == "APIRequest"
                            || clean_part == "Vector_Any"
                            || clean_part == "HashMap_Any"
                            || clean_part == "Pool_Any"
                            || clean_part == "Mutex_Any"
                            || clean_part == "Channel_Any"
                            || clean_part == "ThreadLocalContext_Any"
                            || clean_part == "std_ThreadLocalContext_Any"
                            || clean_part == "ctx"
                            || clean_part == "connCtx"
                            || clean_part == "arena"
                            || clean_part == "a"
                        {
                            clean_part.clone()
                        } else {
                            format!("{}{}", active_prefix, clean_part)
                        };
                        resolved_parts.push(temp_resolved);
                        active_prefix = self.current_prefix.clone();
                    }
                }
                let joined = format!("{}{}", prefix, resolved_parts.join("_")).replace("___", "__");
                return Ok(joined);
            }
        }

        let resolved = if name == "len"
            || name == "int"
            || name == "byte"
            || name == "bool"
            || name == "str"
            || name == "Arena"
            || name == "os_Arena"
            || name == "os.Arena"
            || name == "void"
            || name == "Any"
            || name == "SessionNode"
            || name == "APIRequest"
            || name == "Vector_Any"
            || name == "HashMap_Any"
            || name == "Pool_Any"
            || name == "Mutex_Any"
            || name == "Channel_Any"
            || name == "ThreadLocalContext_Any"
            || name == "std_ThreadLocalContext_Any"
            || name == "ctx"
            || name == "connCtx"
            || name == "arena"
            || name == "a"
        {
            name.to_string()
        } else if let Some(pos) = name.find('.') {
            let alias = &name[..pos];
            let rest = &name[pos + 1..];
            if let Some(prefix) = self.imports.get(alias) {
                format!("{}{}", prefix, rest)
            } else {
                return Err(TypeError {
                    kind: TypeErrorKind::TypeMismatch,
                    message: format!("Semantic Error: Unresolved namespace alias '{}'", alias),
                    span: None,
                });
            }
        } else if name.contains("__") || name.starts_with("std_") || name.starts_with("os_") {
            name.to_string()
        } else {
            format!("{}{}", self.current_prefix, name)
        };

        let mut final_resolved = resolved;
        for (alias, prefix) in &self.imports {
            let start_pattern = format!("{}_", alias);
            let mid_pattern = format!("_{}_", alias);
            if final_resolved.starts_with(&start_pattern) && !final_resolved.contains(prefix) {
                final_resolved = final_resolved.replacen(&start_pattern, prefix, 1);
            } else if let Some(pos) = final_resolved.find(&mid_pattern) {
                let is_standard_monomorphized =
                    final_resolved.starts_with("std_") || final_resolved.starts_with("os_");
                if is_standard_monomorphized && !final_resolved.contains(prefix) {
                    let replacement = format!("_{}", prefix);
                    final_resolved.replace_range(pos..pos + mid_pattern.len(), &replacement);
                }
            }
        }

        tracing::debug!(
            "👁️ Namespace Resolution: Lookup '{}' -> Resolved: '{}' (Current Prefix: '{}')",
            name,
            final_resolved,
            self.current_prefix
        );

        Ok(final_resolved)
    }

    pub fn is_linear(&self, t: &Type) -> bool {
        let mut visited = HashSet::new();
        self.is_linear_impl(t, &mut visited)
    }

    fn is_linear_impl(&self, t: &Type, visited: &mut HashSet<String>) -> bool {
        match t {
            Type::Int | Type::Byte | Type::Bool | Type::Void | Type::Index(_, _) => false,
            Type::Arena | Type::RawPointer(_) | Type::Slice(_) | Type::ByteSlice | Type::Str => {
                true
            }
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
                if name.ends_with("_Any") {
                    return true;
                }
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
        self.variable_origins.insert(name.clone(), origins.clone());
        self.all_variable_origins.insert(name, origins);
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
        let graph_fields = vec![crate::ast::FieldDef {
            name: "nodes".to_string(),
            field_type: Type::Generic(
                "std.Pool".to_string(),
                vec![
                    Type::Struct("std_GraphNode_T_ctx".to_string(), None),
                    Type::Struct("ctx".to_string(), None),
                ],
            ),
            span: crate::token::Span::dummy(),
        }];
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

        // Mutex[T, ctx]
        let mutex_fields = vec![
            crate::ast::FieldDef {
                name: "value".to_string(),
                field_type: Type::Struct("T".to_string(), None),
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "lock_state".to_string(),
                field_type: Type::Int,
                span: crate::token::Span::dummy(),
            },
        ];
        struct_templates.insert(
            "Mutex".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: mutex_fields.clone(),
            },
        );
        struct_templates.insert(
            "std.Mutex".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: mutex_fields.clone(),
            },
        );
        struct_templates.insert(
            "std_Mutex".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: mutex_fields,
            },
        );

        // Channel[T, ctx]
        let channel_fields = vec![
            crate::ast::FieldDef {
                name: "capacity".to_string(),
                field_type: Type::Int,
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "len".to_string(),
                field_type: Type::Int,
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "_phantom".to_string(),
                field_type: Type::RawPointer(Box::new(Type::Struct("T".to_string(), None))),
                span: crate::token::Span::dummy(),
            },
        ];
        struct_templates.insert(
            "Channel".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: channel_fields.clone(),
            },
        );
        struct_templates.insert(
            "std.Channel".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: channel_fields.clone(),
            },
        );
        struct_templates.insert(
            "std_Channel".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: channel_fields,
            },
        );

        // os.Dir[ctx]
        let os_dir_fields = vec![crate::ast::FieldDef {
            name: "handle".to_string(),
            field_type: Type::RawPointer(Box::new(Type::Byte)),
            span: crate::token::Span::dummy(),
        }];
        struct_templates.insert(
            "os.Dir".to_string(),
            StructTemplate {
                generics: vec!["ctx".to_string()],
                fields: os_dir_fields.clone(),
            },
        );
        struct_templates.insert(
            "os_Dir".to_string(),
            StructTemplate {
                generics: vec!["ctx".to_string()],
                fields: os_dir_fields,
            },
        );

        // os.DirEntry[ctx]
        let os_dir_entry_fields = vec![
            crate::ast::FieldDef {
                name: "name".to_string(),
                field_type: Type::Str,
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "is_dir".to_string(),
                field_type: Type::Int,
                span: crate::token::Span::dummy(),
            },
        ];
        struct_templates.insert(
            "os.DirEntry".to_string(),
            StructTemplate {
                generics: vec!["ctx".to_string()],
                fields: os_dir_entry_fields.clone(),
            },
        );
        struct_templates.insert(
            "os_DirEntry".to_string(),
            StructTemplate {
                generics: vec!["ctx".to_string()],
                fields: os_dir_entry_fields,
            },
        );

        // std.ThreadLocalContext[ctx]
        let tl_fields = vec![
            crate::ast::FieldDef {
                name: "arena".to_string(),
                field_type: Type::RawPointer(Box::new(Type::Arena)),
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "_phantom".to_string(),
                field_type: Type::RawPointer(Box::new(Type::Struct("ctx".to_string(), None))),
                span: crate::token::Span::dummy(),
            },
        ];
        struct_templates.insert(
            "ThreadLocalContext".to_string(),
            StructTemplate {
                generics: vec!["ctx".to_string()],
                fields: tl_fields.clone(),
            },
        );
        struct_templates.insert(
            "std.ThreadLocalContext".to_string(),
            StructTemplate {
                generics: vec!["ctx".to_string()],
                fields: tl_fields.clone(),
            },
        );
        struct_templates.insert(
            "std_ThreadLocalContext".to_string(),
            StructTemplate {
                generics: vec!["ctx".to_string()],
                fields: tl_fields,
            },
        );

        // std.GenerationalArena[T, ctx]
        let gen_arena_fields = vec![
            crate::ast::FieldDef {
                name: "current_ctx".to_string(),
                field_type: Type::Arena,
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "next_ctx".to_string(),
                field_type: Type::Arena,
                span: crate::token::Span::dummy(),
            },
            crate::ast::FieldDef {
                name: "survivor".to_string(),
                field_type: Type::Index("T".to_string(), Some("current_ctx".to_string())),
                span: crate::token::Span::dummy(),
            },
        ];
        struct_templates.insert(
            "GenerationalArena".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: gen_arena_fields.clone(),
            },
        );
        struct_templates.insert(
            "std.GenerationalArena".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: gen_arena_fields.clone(),
            },
        );
        struct_templates.insert(
            "std_GenerationalArena".to_string(),
            StructTemplate {
                generics: vec!["T".to_string(), "ctx".to_string()],
                fields: gen_arena_fields,
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
            enum_templates: HashMap::new(),
            enum_registry: HashMap::new(),
            variable_origins: HashMap::new(),
            all_variable_origins: HashMap::new(),
            function_registry: HashMap::new(),
            expected_return_type: None,
            current_function_return_origins: None,
            checked_results: HashSet::new(),
            current_function_inout_params: None,
            current_function_local_vars: None,
            open_directories: HashSet::new(),
            module_imports: HashMap::new(),
        }
    }

    pub fn serialize(&self) -> String {
        let mut out = String::new();

        // 1. Variables
        out.push_str("Variables:\n");
        let mut sorted_vars: Vec<(&String, &Type)> = self.variable_types.iter().collect();
        sorted_vars.sort_by(|a, b| a.0.cmp(b.0));
        for (name, ty) in sorted_vars {
            out.push_str(&format!("  {} : {:?}\n", name, ty));
        }

        // 2. Structures
        out.push_str("Structures:\n");
        let mut sorted_structs: Vec<(&String, &StructLayout)> =
            self.struct_registry.iter().collect();
        sorted_structs.sort_by(|a, b| a.0.cmp(b.0));
        for (name, layout) in sorted_structs {
            let brand_str = match &layout.brand {
                Some(b) => format!(" [{}]", b),
                None => "".to_string(),
            };
            out.push_str(&format!("  {}{}:\n", name, brand_str));
            let mut sorted_fields: Vec<(&String, &Type)> = layout.fields.iter().collect();
            sorted_fields.sort_by(|a, b| a.0.cmp(b.0));
            for (f_name, f_type) in sorted_fields {
                out.push_str(&format!("    {} : {:?}\n", f_name, f_type));
            }
        }

        // 3. Enums
        out.push_str("Enums:\n");
        let mut sorted_enums: Vec<(&String, &Vec<String>)> = self.enum_registry.iter().collect();
        sorted_enums.sort_by(|a, b| a.0.cmp(b.0));
        for (name, variants) in sorted_enums {
            let mut sorted_variants = variants.clone();
            sorted_variants.sort();
            out.push_str(&format!("  {}:\n", name));
            for var in sorted_variants {
                out.push_str(&format!("    {}\n", var));
            }
        }

        // 4. Functions
        out.push_str("Functions:\n");
        let mut sorted_funcs: Vec<(&String, &FunctionSignature)> =
            self.function_registry.iter().collect();
        sorted_funcs.sort_by(|a, b| a.0.cmp(b.0));
        for (name, sig) in sorted_funcs {
            let mut params_str = Vec::new();
            for (p_name, p_type) in sig.param_names.iter().zip(sig.params.iter()) {
                params_str.push(format!("{}: {:?}", p_name, p_type));
            }
            out.push_str(&format!(
                "  {}({}) -> {:?}\n",
                name,
                params_str.join(", "),
                sig.return_type
            ));
        }

        out
    }
}
