use super::TypeChecker;
use super::types::{
    StructLayout, Type, TypeError, TypeErrorKind, expression_to_string, strip_brand_prefix,
    types_match,
};
use crate::ast::{Expression, Program, Statement};
use std::collections::{HashMap, HashSet};

fn get_root_variable(expr: &Expression) -> Option<String> {
    match expr {
        Expression::Identifier(name, _) => Some(name.clone()),
        Expression::Selector { left, .. } => get_root_variable(left),
        Expression::IndexAccess { allocator, .. } => get_root_variable(allocator),
        Expression::Dereference(inner, _) => get_root_variable(inner),
        Expression::AddressOf(inner, _) => get_root_variable(inner),
        Expression::AsCast { left, .. } => get_root_variable(left),
        Expression::Move(inner, _) => get_root_variable(inner),
        Expression::Take(inner, _) => get_root_variable(inner),
        _ => None,
    }
}

fn get_file_stem(path_str: &str) -> String {
    let p = std::path::Path::new(path_str);
    p.file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or(path_str)
        .to_string()
}

impl TypeChecker {
    pub fn is_ephemeral_view(&self, t: &Type) -> bool {
        match t {
            Type::Str | Type::Slice(_) | Type::ByteSlice | Type::RawPointer(_) => true,
            Type::Struct(name, _) => {
                let clean_name = strip_brand_prefix(name);
                if clean_name.starts_with("CastResult_")
                    || clean_name.starts_with("LookupResult_")
                    || clean_name.ends_with("_Any")
                {
                    return true;
                }
                self.contains_ephemeral_view(t)
            }
            _ => false,
        }
    }

    fn erase_struct_name(&self, name: &str, brand: &Option<String>) -> String {
        let mut actual_brand = brand.clone();
        if actual_brand.is_none()
            && let Some(layout) = self.struct_registry.get(name)
        {
            actual_brand = layout.brand.clone();
        }
        if let Some(b) = &actual_brand {
            let suffix = format!("_{}", b);
            if name.ends_with(&suffix) {
                return name[..name.len() - suffix.len()].to_string();
            }
        }
        name.to_string()
    }

    fn types_match_modulo_brand(&self, expected: &Type, actual: &Type) -> bool {
        match (expected, actual) {
            (Type::RawPointer(e_inner), Type::RawPointer(a_inner)) => {
                self.types_match_modulo_brand(e_inner, a_inner)
            }
            (Type::Slice(e_inner), Type::Slice(a_inner)) => {
                self.types_match_modulo_brand(e_inner, a_inner)
            }
            (Type::Struct(e_name, e_brand), Type::Struct(a_name, a_brand)) => {
                let e_erased = self.erase_struct_name(e_name, e_brand);
                let a_erased = self.erase_struct_name(a_name, a_brand);
                e_erased == a_erased
            }
            (Type::Index(e_name, e_brand), Type::Index(a_name, a_brand)) => {
                let e_erased = self.erase_struct_name(e_name, e_brand);
                let a_erased = self.erase_struct_name(a_name, a_brand);
                e_erased == a_erased
            }
            _ => types_match(expected, actual),
        }
    }

    fn is_diverging_block(&self, body: &crate::ast::BlockStatement) -> bool {
        for stmt in &body.statements {
            if self.is_diverging_statement(stmt) {
                return true;
            }
        }
        false
    }

    fn is_diverging_statement(&self, stmt: &Statement) -> bool {
        match stmt {
            Statement::Return(_, _) => true,
            Statement::Expression(Expression::Call { function, .. }, _) => {
                let raw_func_path = expression_to_string(function);
                let func_path = self
                    .resolve_namespaced_ident(&raw_func_path)
                    .unwrap_or(raw_func_path);
                func_path == "os.Exit" || func_path == "os_Exit"
            }
            Statement::UnsafeBlock { body, .. } => self.is_diverging_block(body),
            Statement::If {
                consequence,
                alternative,
                ..
            } => {
                let cons_div = self.is_diverging_block(consequence);
                let alt_div = if let Some(alt) = alternative {
                    self.is_diverging_block(alt)
                } else {
                    false
                };
                cons_div && alt_div
            }
            _ => false,
        }
    }

    fn get_vector_element_type(&self, struct_name: &str) -> Option<Type> {
        if let Some(layout) = self.struct_registry.get(struct_name)
            && let Some(Type::RawPointer(inner)) = layout.fields.get("data")
        {
            return Some((**inner).clone());
        }
        None
    }

    fn get_pool_element_type(&self, struct_name: &str) -> Option<Type> {
        if let Some(layout) = self.struct_registry.get(struct_name)
            && let Some(Type::RawPointer(inner)) = layout.fields.get("data")
        {
            return Some((**inner).clone());
        }
        None
    }

    fn get_channel_element_type(&self, struct_name: &str) -> Option<Type> {
        if let Some(layout) = self.struct_registry.get(struct_name)
            && let Some(Type::RawPointer(inner)) = layout.fields.get("_phantom")
        {
            return Some((**inner).clone());
        }
        None
    }

    fn get_hashmap_key_value_types(&self, struct_name: &str) -> Option<(Type, Type)> {
        if let Some(layout) = self.struct_registry.get(struct_name) {
            let k = layout.fields.get("keys")?;
            let v = layout.fields.get("values")?;
            if let (Type::RawPointer(k_inner), Type::RawPointer(v_inner)) = (k, v) {
                return Some(((**k_inner).clone(), (**v_inner).clone()));
            }
        }
        None
    }

    fn has_boolean_fields_recursive(&self, t: &Type, visited: &mut HashSet<String>) -> bool {
        match t {
            Type::Byte | Type::Bool => true,
            Type::Struct(name, _) => {
                if visited.contains(name) {
                    return false;
                }
                visited.insert(name.clone());
                if let Some(layout) = self.struct_registry.get(name) {
                    for field_type in layout.fields.values() {
                        if self.has_boolean_fields_recursive(field_type, visited) {
                            return true;
                        }
                    }
                }
                false
            }
            Type::RawPointer(inner) => self.has_boolean_fields_recursive(inner, visited),
            Type::Slice(inner) => self.has_boolean_fields_recursive(inner, visited),
            Type::Generic(name, args) => {
                for arg in args {
                    if self.has_boolean_fields_recursive(arg, visited) {
                        return true;
                    }
                }
                if let Some(template) = self.struct_templates.get(name) {
                    for field in &template.fields {
                        if self.has_boolean_fields_recursive(&field.field_type, visited) {
                            return true;
                        }
                    }
                }
                false
            }
            _ => false,
        }
    }

    fn has_boolean_fields(&self, t: &Type) -> bool {
        let mut visited = HashSet::new();
        self.has_boolean_fields_recursive(t, &mut visited)
    }

    fn extract_ok_checked_variable(&self, expr: &Expression) -> Option<String> {
        match expr {
            Expression::Selector { left, right, .. } => {
                if right == "Ok" {
                    return Some(expression_to_string(left));
                }
                None
            }
            Expression::Binary {
                op, left, right, ..
            } => {
                if op == "==" {
                    // Case: path.Ok == 1
                    if let Expression::Selector {
                        left: sel_left,
                        right: sel_right,
                        ..
                    } = &**left
                        && sel_right == "Ok"
                        && let Expression::Integer(1, _) = &**right
                    {
                        return Some(expression_to_string(sel_left));
                    }
                    // Case: 1 == path.Ok
                    if let Expression::Selector {
                        left: sel_left,
                        right: sel_right,
                        ..
                    } = &**right
                        && sel_right == "Ok"
                        && let Expression::Integer(1, _) = &**left
                    {
                        return Some(expression_to_string(sel_left));
                    }
                }
                None
            }
            _ => None,
        }
    }

    pub fn pre_register_std_functions(&mut self) {
        self.function_registry.insert(
            "os.ScratchAlloc".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["size".to_string()],
                params: vec![Type::Int],
                return_type: Type::RawPointer(Box::new(Type::Byte)),
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "os_ScratchAlloc".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["size".to_string()],
                params: vec![Type::Int],
                return_type: Type::RawPointer(Box::new(Type::Byte)),
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "os.ScratchReset".to_string(),
            super::types::FunctionSignature {
                param_names: vec![],
                params: vec![],
                return_type: Type::Void,
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "os_ScratchReset".to_string(),
            super::types::FunctionSignature {
                param_names: vec![],
                params: vec![],
                return_type: Type::Void,
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "std.FormatInt".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["val".to_string()],
                params: vec![Type::Int],
                return_type: Type::Str,
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "std_FormatInt".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["val".to_string()],
                params: vec![Type::Int],
                return_type: Type::Str,
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "std.Concat".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["s1".to_string(), "s2".to_string()],
                params: vec![Type::Str, Type::Str],
                return_type: Type::Str,
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "std_Concat".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["s1".to_string(), "s2".to_string()],
                params: vec![Type::Str, Type::Str],
                return_type: Type::Str,
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "std_str_eq".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["s1".to_string(), "s2".to_string()],
                params: vec![Type::Str, Type::Str],
                return_type: Type::Int,
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "std.str_eq".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["s1".to_string(), "s2".to_string()],
                params: vec![Type::Str, Type::Str],
                return_type: Type::Int,
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "std.Clone".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["dest_ctx".to_string(), "src_val".to_string()],
                params: vec![
                    Type::RawPointer(Box::new(Type::Arena)),
                    Type::Index("Any".to_string(), None),
                ],
                return_type: Type::Index("Any".to_string(), None),
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "std_Clone".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["dest_ctx".to_string(), "src_val".to_string()],
                params: vec![
                    Type::RawPointer(Box::new(Type::Arena)),
                    Type::Index("Any".to_string(), None),
                ],
                return_type: Type::Index("Any".to_string(), None),
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "std.GenerationalSwap".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["current_ctx".to_string(), "next_ctx".to_string()],
                params: vec![
                    Type::RawPointer(Box::new(Type::Arena)),
                    Type::RawPointer(Box::new(Type::Arena)),
                ],
                return_type: Type::Void,
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "std_GenerationalSwap".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["current_ctx".to_string(), "next_ctx".to_string()],
                params: vec![
                    Type::RawPointer(Box::new(Type::Arena)),
                    Type::RawPointer(Box::new(Type::Arena)),
                ],
                return_type: Type::Void,
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "std.PoolNew".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["ctx".to_string()],
                params: vec![Type::RawPointer(Box::new(Type::Arena))],
                return_type: Type::Struct("Pool_Any".to_string(), Some("ctx".to_string())),
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "os.PoolNew".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["ctx".to_string()],
                params: vec![Type::RawPointer(Box::new(Type::Arena))],
                return_type: Type::Struct("Pool_Any".to_string(), Some("ctx".to_string())),
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "std.MutexNew".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["ctx".to_string()],
                params: vec![Type::RawPointer(Box::new(Type::Arena))],
                return_type: Type::Struct("Mutex_Any".to_string(), Some("ctx".to_string())),
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "std_MutexNew".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["ctx".to_string()],
                params: vec![Type::RawPointer(Box::new(Type::Arena))],
                return_type: Type::Struct("Mutex_Any".to_string(), Some("ctx".to_string())),
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "std.ChannelNew".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["ctx".to_string()],
                params: vec![Type::RawPointer(Box::new(Type::Arena))],
                return_type: Type::Struct("Channel_Any".to_string(), Some("ctx".to_string())),
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "std_ChannelNew".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["ctx".to_string()],
                params: vec![Type::RawPointer(Box::new(Type::Arena))],
                return_type: Type::Struct("Channel_Any".to_string(), Some("ctx".to_string())),
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "std.Format".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["template".to_string()],
                params: vec![Type::Str],
                return_type: Type::Str,
                return_origins: {
                    let mut s = std::collections::HashSet::new();
                    s.insert("scratch".to_string());
                    s
                },
            },
        );
        self.function_registry.insert(
            "std_Format".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["template".to_string()],
                params: vec![Type::Str],
                return_type: Type::Str,
                return_origins: {
                    let mut s = std::collections::HashSet::new();
                    s.insert("scratch".to_string());
                    s
                },
            },
        );

        self.function_registry.insert(
            "std.str_slice".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["s".to_string(), "start".to_string(), "end".to_string()],
                params: vec![Type::Str, Type::Int, Type::Int],
                return_type: Type::Str,
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "std_str_slice".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["s".to_string(), "start".to_string(), "end".to_string()],
                params: vec![Type::Str, Type::Int, Type::Int],
                return_type: Type::Str,
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "std.str_byte_at".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["s".to_string(), "idx".to_string()],
                params: vec![Type::Str, Type::Int],
                return_type: Type::Byte,
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "std_str_byte_at".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["s".to_string(), "idx".to_string()],
                params: vec![Type::Str, Type::Int],
                return_type: Type::Byte,
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "std.str_find".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["s".to_string(), "target".to_string()],
                params: vec![Type::Str, Type::Str],
                return_type: Type::Int,
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "std_str_find".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["s".to_string(), "target".to_string()],
                params: vec![Type::Str, Type::Str],
                return_type: Type::Int,
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "std.str_trim".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["s".to_string()],
                params: vec![Type::Str],
                return_type: Type::Str,
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "std_str_trim".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["s".to_string()],
                params: vec![Type::Str],
                return_type: Type::Str,
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "std.str_split".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["s".to_string(), "delim".to_string(), "ctx".to_string()],
                params: vec![
                    Type::Str,
                    Type::Str,
                    Type::RawPointer(Box::new(Type::Arena)),
                ],
                return_type: Type::Generic(
                    "std.Vector".to_string(),
                    vec![Type::Str, Type::Struct("ctx".to_string(), None)],
                ),
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "std_str_split".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["s".to_string(), "delim".to_string(), "ctx".to_string()],
                params: vec![
                    Type::Str,
                    Type::Str,
                    Type::RawPointer(Box::new(Type::Arena)),
                ],
                return_type: Type::Generic(
                    "std.Vector".to_string(),
                    vec![Type::Str, Type::Struct("ctx".to_string(), None)],
                ),
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "std.is_alpha".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["b".to_string()],
                params: vec![Type::Byte],
                return_type: Type::Bool,
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "std_is_alpha".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["b".to_string()],
                params: vec![Type::Byte],
                return_type: Type::Bool,
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "std.is_digit".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["b".to_string()],
                params: vec![Type::Byte],
                return_type: Type::Bool,
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "std_is_digit".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["b".to_string()],
                params: vec![Type::Byte],
                return_type: Type::Bool,
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "std.is_whitespace".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["b".to_string()],
                params: vec![Type::Byte],
                return_type: Type::Bool,
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "std_is_whitespace".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["b".to_string()],
                params: vec![Type::Byte],
                return_type: Type::Bool,
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "std.parse_int".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["s".to_string()],
                params: vec![Type::Str],
                return_type: Type::Int,
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "std_parse_int".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["s".to_string()],
                params: vec![Type::Str],
                return_type: Type::Int,
                return_origins: std::collections::HashSet::new(),
            },
        );

        self.function_registry.insert(
            "os.Args".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["ctx".to_string()],
                params: vec![Type::RawPointer(Box::new(Type::Arena))],
                return_type: Type::Generic(
                    "std.Vector".to_string(),
                    vec![Type::Str, Type::Struct("ctx".to_string(), None)],
                ),
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "os_Args".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["ctx".to_string()],
                params: vec![Type::RawPointer(Box::new(Type::Arena))],
                return_type: Type::Generic(
                    "std.Vector".to_string(),
                    vec![Type::Str, Type::Struct("ctx".to_string(), None)],
                ),
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "os.Exit".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["code".to_string()],
                params: vec![Type::Int],
                return_type: Type::Void,
                return_origins: std::collections::HashSet::new(),
            },
        );
        self.function_registry.insert(
            "os_Exit".to_string(),
            super::types::FunctionSignature {
                param_names: vec!["code".to_string()],
                params: vec![Type::Int],
                return_type: Type::Void,
                return_origins: std::collections::HashSet::new(),
            },
        );

        // os.OpenDir
        let open_dir_sig = super::types::FunctionSignature {
            param_names: vec!["ctx".to_string(), "path".to_string()],
            params: vec![Type::RawPointer(Box::new(Type::Arena)), Type::Str],
            return_type: Type::Struct(
                "LookupResult_os_Dir_ctx".to_string(),
                Some("ctx".to_string()),
            ),
            return_origins: std::collections::HashSet::new(),
        };
        self.function_registry
            .insert("os.OpenDir".to_string(), open_dir_sig.clone());
        self.function_registry
            .insert("os_OpenDir".to_string(), open_dir_sig);

        // os.ReadDir
        let read_dir_sig = super::types::FunctionSignature {
            param_names: vec!["ctx".to_string(), "dir".to_string()],
            params: vec![
                Type::RawPointer(Box::new(Type::Arena)),
                Type::Struct("os_Dir_ctx".to_string(), Some("ctx".to_string())),
            ],
            return_type: Type::Struct(
                "LookupResult_os_DirEntry_ctx".to_string(),
                Some("ctx".to_string()),
            ),
            return_origins: std::collections::HashSet::new(),
        };
        self.function_registry
            .insert("os.ReadDir".to_string(), read_dir_sig.clone());
        self.function_registry
            .insert("os_ReadDir".to_string(), read_dir_sig);

        // os.CloseDir
        let close_dir_sig = super::types::FunctionSignature {
            param_names: vec!["dir".to_string()],
            params: vec![Type::Struct(
                "os_Dir_ctx".to_string(),
                Some("ctx".to_string()),
            )],
            return_type: Type::Void,
            return_origins: std::collections::HashSet::new(),
        };
        self.function_registry
            .insert("os.CloseDir".to_string(), close_dir_sig.clone());
        self.function_registry
            .insert("os_CloseDir".to_string(), close_dir_sig);

        // os.path_join
        let path_join_sig = super::types::FunctionSignature {
            param_names: vec!["dir".to_string(), "file".to_string(), "ctx".to_string()],
            params: vec![
                Type::Str,
                Type::Str,
                Type::RawPointer(Box::new(Type::Arena)),
            ],
            return_type: Type::Str,
            return_origins: std::collections::HashSet::new(),
        };
        self.function_registry
            .insert("os.path_join".to_string(), path_join_sig.clone());
        self.function_registry
            .insert("os_path_join".to_string(), path_join_sig);

        // os.SetThreadScratch
        let set_thread_scratch_sig = super::types::FunctionSignature {
            param_names: vec!["ctx".to_string()],
            params: vec![Type::RawPointer(Box::new(Type::Arena))],
            return_type: Type::Void,
            return_origins: std::collections::HashSet::new(),
        };
        self.function_registry.insert(
            "os.SetThreadScratch".to_string(),
            set_thread_scratch_sig.clone(),
        );
        self.function_registry
            .insert("os_SetThreadScratch".to_string(), set_thread_scratch_sig);

        // os.GetThreadScratch
        let get_thread_scratch_sig = super::types::FunctionSignature {
            param_names: vec![],
            params: vec![],
            return_type: Type::Struct(
                "std_ThreadLocalContext_Any".to_string(),
                Some("Any".to_string()),
            ),
            return_origins: std::collections::HashSet::new(),
        };
        self.function_registry.insert(
            "os.GetThreadScratch".to_string(),
            get_thread_scratch_sig.clone(),
        );
        self.function_registry
            .insert("os_GetThreadScratch".to_string(), get_thread_scratch_sig);

        // os.ArenaValidate
        let arena_validate_sig = super::types::FunctionSignature {
            param_names: vec!["arena".to_string()],
            params: vec![Type::RawPointer(Box::new(Type::Arena))],
            return_type: Type::Void,
            return_origins: std::collections::HashSet::new(),
        };
        self.function_registry
            .insert("os.ArenaValidate".to_string(), arena_validate_sig.clone());
        self.function_registry
            .insert("os_ArenaValidate".to_string(), arena_validate_sig);

        let yield_sig = super::types::FunctionSignature {
            param_names: vec![],
            params: vec![],
            return_type: Type::Void,
            return_origins: std::collections::HashSet::new(),
        };
        self.function_registry
            .insert("std.Yield".to_string(), yield_sig.clone());
        self.function_registry
            .insert("std_Yield".to_string(), yield_sig);
    }

    pub fn check_program(&mut self, program: &Program) -> Result<(), TypeError> {
        self.current_prefix = "".to_string();
        self.check_module(program, "")
    }

    pub fn check_module(&mut self, program: &Program, prefix: &str) -> Result<(), TypeError> {
        self.current_prefix = prefix.to_string();
        self.symbol_table.clear();
        self.variable_origins.clear();
        self.all_variable_origins.clear();
        self.moved_vars.clear();
        self.checked_results.clear();
        self.open_directories.clear();

        // 1. Pre-register std library namespaces
        self.imports.insert("os".to_string(), "os_".to_string());
        tracing::debug!("🗄️ Stdlib Registered: Alias 'os' maps to prefix 'os_'");
        self.imports.insert("std".to_string(), "std_".to_string());
        tracing::debug!("🗄️ Stdlib Registered: Alias 'std' maps to prefix 'std_'");
        self.pre_register_std_functions();

        // Pre-pass: Dynamically register structs, templates, enums, and functions [3]
        for stmt in &program.statements {
            if let Statement::Import { path, alias, .. } = stmt {
                let stem = get_file_stem(path);
                let pfx = format!("{}__", stem);
                let alias_name = alias.clone().unwrap_or_else(|| stem.clone());
                tracing::debug!(
                    "🗄️ Import Alias Mapping Registered (Pre-pass): '{}' -> '{}' (for path '{}')",
                    alias_name,
                    pfx,
                    path
                );
                self.imports.insert(alias_name, pfx);
            }

            if let Statement::StructDecl {
                name,
                generics,
                fields,
                span,
                ..
            } = stmt
            {
                let namespaced_name = format!("{}{}", self.current_prefix, name);
                self.resolved_names.insert(*span, namespaced_name.clone());

                if generics.is_empty() {
                    let mut layout_fields = HashMap::new();
                    for field in fields {
                        let resolved_field_type = self.resolve_type(&field.field_type)?;
                        let resolved_field_type =
                            self.resolve_type_namespacing(&resolved_field_type)?;
                        if (matches!(resolved_field_type, Type::Slice(_))
                            || resolved_field_type == Type::ByteSlice
                            || resolved_field_type == Type::Str)
                            && namespaced_name != "errors__CompilerError"
                        {
                            return Err(TypeError {
                                kind: TypeErrorKind::BrandLifetimeViolation,
                                message: format!(
                                    "Semantic Error: Unbranded struct '{}' cannot contain ephemeral slice or view field '{}' of type '{:?}'",
                                    namespaced_name, field.name, resolved_field_type
                                ),
                                span: None,
                            });
                        }
                        layout_fields.insert(field.name.clone(), resolved_field_type);
                    }
                    self.struct_registry.insert(
                        namespaced_name.clone(),
                        StructLayout {
                            brand: None,
                            fields: layout_fields,
                        },
                    );
                } else {
                    self.struct_templates.insert(
                        namespaced_name.clone(),
                        super::types::StructTemplate {
                            generics: generics.clone(),
                            fields: fields.clone(),
                        },
                    );
                }
            }

            if let Statement::EnumDecl {
                name,
                generics,
                variants,
                span,
                ..
            } = stmt
            {
                let namespaced_name = format!("{}{}", self.current_prefix, name);
                self.resolved_names.insert(*span, namespaced_name.clone());

                if generics.is_empty() {
                    // Register the enum in the enum registry
                    let variant_names: Vec<String> =
                        variants.iter().map(|v| v.name.clone()).collect();
                    self.enum_registry
                        .insert(namespaced_name.clone(), variant_names);

                    // Register nested variant structs in struct_registry
                    let mut enum_fields = HashMap::new();
                    enum_fields.insert("tag".to_string(), Type::Int);

                    for variant in variants {
                        let concrete_variant_struct_name =
                            format!("{}_{}", namespaced_name, variant.name);

                        // Register the variant struct fields in struct_registry
                        let mut variant_fields = HashMap::new();
                        for field in &variant.fields {
                            let resolved_t = self.resolve_type(&field.field_type)?;
                            let resolved_t = self.resolve_type_namespacing(&resolved_t)?;
                            if let Type::Struct(ref struct_name, _) = resolved_t
                                && let Some(layout) = self.struct_registry.get(struct_name)
                                && layout.fields.len() > 2
                            {
                                return Err(TypeError {
                                    kind: TypeErrorKind::LargeEnumVariantPayload,
                                    message: format!(
                                        "Semantic Error: Variant '{}' contains a large enum variant payload struct '{}' ({} fields). Use Index[{}], or pointer indirection to avoid memory bloat.",
                                        variant.name,
                                        struct_name,
                                        layout.fields.len(),
                                        struct_name
                                    ),
                                    span: None,
                                });
                            }
                            variant_fields.insert(field.name.clone(), resolved_t);
                        }
                        self.struct_registry.insert(
                            concrete_variant_struct_name.clone(),
                            StructLayout {
                                brand: None,
                                fields: variant_fields,
                            },
                        );

                        // Add the variant as a field of the Enum struct
                        enum_fields.insert(
                            variant.name.clone(),
                            Type::Struct(concrete_variant_struct_name, None),
                        );
                    }

                    // Register the Enum struct itself
                    self.struct_registry.insert(
                        namespaced_name.clone(),
                        StructLayout {
                            brand: None,
                            fields: enum_fields,
                        },
                    );
                } else {
                    self.enum_templates.insert(
                        namespaced_name.clone(),
                        super::types::EnumTemplate {
                            generics: generics.clone(),
                            variants: variants.clone(),
                        },
                    );
                }
            }

            if let Statement::FunctionDecl {
                name,
                params,
                return_type,
                span,
                ..
            } = stmt
            {
                let namespaced_name = format!("{}{}", self.current_prefix, name);
                self.resolved_names.insert(*span, namespaced_name.clone());

                let resolved_params: Result<Vec<Type>, TypeError> = params
                    .iter()
                    .map(|p| {
                        let resolved = self.resolve_type(&p.param_type)?;
                        self.resolve_type_namespacing(&resolved)
                    })
                    .collect();
                let resolved_return = self.resolve_type(return_type)?;
                let resolved_return = self.resolve_type_namespacing(&resolved_return)?;
                let param_names: Vec<String> = params.iter().map(|p| p.name.clone()).collect();

                let params_ok = resolved_params?;

                tracing::debug!(
                    "🗄️ Function Pre-Registration: Raw name: '{}', Namespaced: '{}', Parameter Count: {}, Params: {:?}",
                    name,
                    namespaced_name,
                    params_ok.len(),
                    param_names
                        .iter()
                        .zip(params_ok.iter())
                        .map(|(p_name, p_type)| format!("{}: {:?}", p_name, p_type))
                        .collect::<Vec<_>>()
                );

                let existing_sig = self.function_registry.get(&namespaced_name);
                if let Some(sig) = existing_sig {
                    // If function already registered, check if signatures match. If not, report error.
                    // For now, we'll allow redefinition if signatures are identical to simplify.
                    // In a future iteration, we might want to enforce uniqueness more strictly.
                    // However, for this fix, we need to ensure we don't silently overwrite.
                    // Check parameter count and type compatibility.
                    // Note: Full signature comparison might be complex due to complex type monomorphization.
                    // For now, let's focus on parameter count as a primary check.
                    if sig.params.len() != params_ok.len() {
                        return Err(TypeError {
                            kind: TypeErrorKind::DuplicateFunctionDefinition,
                            message: format!(
                                "Semantic Error: Duplicate function definition for '{}'. Found different parameter counts ({} vs {})",
                                namespaced_name,
                                sig.params.len(),
                                params_ok.len()
                            ),
                            span: Some(*span),
                        });
                    }
                    // If parameter counts match, we *could* compare types, but it's complex.
                    // For now, accept identical signatures, but error on parameter count mismatch.
                    // If we want to be stricter, we'd need a deep type comparison here.
                } else {
                    // Insert the new signature if no existing one is found
                    self.function_registry.insert(
                        namespaced_name.clone(),
                        super::types::FunctionSignature {
                            param_names,
                            params: params_ok,
                            return_type: resolved_return,
                            return_origins: HashSet::new(),
                        },
                    );
                }
            }
        }

        // Synthesize IsValid helpers for structs containing boolean (byte) fields
        let mut structs_to_register_is_valid = Vec::new();
        for struct_name in self.struct_registry.keys() {
            if self.has_boolean_fields(&Type::Struct(struct_name.clone(), None)) {
                structs_to_register_is_valid.push(struct_name.clone());
            }
        }
        for struct_name in structs_to_register_is_valid {
            let func_name = format!("{}_IsValid", struct_name);
            self.function_registry.insert(
                func_name,
                super::types::FunctionSignature {
                    param_names: vec!["req".to_string()],
                    params: vec![Type::RawPointer(Box::new(Type::Struct(
                        struct_name.clone(),
                        None,
                    )))],
                    return_type: Type::Int,
                    return_origins: HashSet::new(),
                },
            );
        }

        // Processing Pass
        for stmt in &program.statements {
            self.check_statement(stmt)?;
        }
        Ok(())
    }

    // Tier A: Entry-Point Interception Wrapper for Statements
    pub fn check_statement(&mut self, stmt: &Statement) -> Result<(), TypeError> {
        let res = self.check_statement_internal(stmt);
        match res {
            Err(mut err) => {
                if err.span.is_none() {
                    err.span = Some(stmt.span());
                }
                Err(err)
            }
            Ok(()) => Ok(()),
        }
    }

    fn check_statement_internal(&mut self, stmt: &Statement) -> Result<(), TypeError> {
        match stmt {
            Statement::Import {
                path,
                alias,
                span: _,
            } => {
                let stem = get_file_stem(path);
                let prefix = format!("{}__", stem);
                let alias_name = alias.clone().unwrap_or_else(|| stem.clone());
                tracing::debug!(
                    "🗄️ Import Alias Mapping Registered (Statement Pass): '{}' -> '{}' (for path '{}')",
                    alias_name,
                    prefix,
                    path
                );
                self.imports.insert(alias_name, prefix);
            }
            Statement::StructDecl { .. } => {}
            Statement::EnumDecl { .. } => {}
            Statement::FunctionDecl {
                name,
                params,
                return_type,
                body,
                span,
                ..
            } => {
                let parent_scope = self.symbol_table.clone();
                let parent_origins = self.variable_origins.clone();
                let parent_moved = self.moved_vars.clone();
                let parent_checked = self.checked_results.clone();
                let parent_open_dirs = self.open_directories.clone();

                self.moved_vars.clear();
                self.checked_results.clear();
                self.open_directories.clear();

                let mut inout_params = Vec::new();

                // Register all function parameters in the local symbol table & origins
                for param in params {
                    let resolved_param_type = self.resolve_type(&param.param_type)?;
                    if matches!(resolved_param_type, Type::RawPointer(_)) {
                        inout_params.push(param.name.clone());
                    }
                    self.symbol_table
                        .insert(param.name.clone(), resolved_param_type);

                    let mut param_origins = HashSet::new();
                    param_origins.insert(param.name.clone());
                    self.variable_origins
                        .insert(param.name.clone(), param_origins.clone());
                    self.all_variable_origins
                        .insert(param.name.clone(), param_origins);
                }

                // Register and track expected return types inside local scope [3]
                let resolved_return_type = self.resolve_type(return_type)?;
                let old_expected = self.expected_return_type.clone();
                let old_return_origins = self.current_function_return_origins.clone();
                let old_inout_params = self.current_function_inout_params.clone();
                let old_local_vars = self.current_function_local_vars.clone();

                self.expected_return_type = Some(resolved_return_type);
                self.current_function_return_origins = Some(HashSet::new());
                self.current_function_inout_params = Some(inout_params.clone());
                self.current_function_local_vars = Some(HashSet::new());

                for s in &body.statements {
                    self.check_statement(s)?;
                }

                if let Some(ref current_inouts) = self.current_function_inout_params {
                    for inout_p in current_inouts {
                        if self.moved_vars.contains(inout_p) {
                            return Err(TypeError {
                                kind: TypeErrorKind::UseOfMovedVariable,
                                message: format!(
                                    "Semantic Error: Inout reference parameter '{}' was moved but never re-initialized before function exit",
                                    inout_p
                                ),
                                span: None,
                            });
                        }
                    }
                }

                let formal_return_origins = self
                    .current_function_return_origins
                    .clone()
                    .unwrap_or_default();

                let namespaced_name = self
                    .resolved_names
                    .get(span)
                    .cloned()
                    .unwrap_or_else(|| self.current_prefix.clone() + name.as_str());

                // Populate formal return origins on signature for propagation
                if let Some(sig) = self.function_registry.get_mut(&namespaced_name) {
                    sig.return_origins = formal_return_origins;
                }
                // Check for resource leaks in local scope before clean-up and restoring parent scopes
                if let Some(ref local_vars) = self.current_function_local_vars {
                    for local_var in local_vars {
                        if self.open_directories.contains(local_var) {
                            return Err(TypeError {
                                kind: TypeErrorKind::BrandLifetimeViolation,
                                message: format!(
                                    "Semantic Error: Resource leak. Directory resource variable '{}' must be cleanly closed with os.CloseDir before leaving local scope",
                                    local_var
                                ),
                                span: None,
                            });
                        }
                    }
                }

                // Clean-up and restore parent scopes [3]
                self.symbol_table = parent_scope;
                self.variable_origins = parent_origins;
                self.moved_vars = parent_moved;
                self.checked_results = parent_checked;
                self.open_directories = parent_open_dirs;
                self.expected_return_type = old_expected;
                self.current_function_return_origins = old_return_origins;
                self.current_function_inout_params = old_inout_params;
                self.current_function_local_vars = old_local_vars;
            }
            Statement::Guard {
                name,
                is_mut: _,
                value,
                else_body,
                span,
            } => {
                // 1. Typecheck the RHS expression 'value'
                let val_type = self.check_expression(value)?;
                let resolved_val_type = self.resolve_type(&val_type)?;

                // Confirm it is a fallible wrapper type containing both Ok and Val fields
                let mut bound_type = None;
                if let Type::Struct(ref struct_name, ref _brand) = resolved_val_type
                    && let Some(layout) = self.struct_registry.get(struct_name)
                {
                    let ok_field = layout.fields.get("Ok");
                    let val_field = layout.fields.get("Val");
                    if let (Some(ok_t), Some(val_t)) = (ok_field, val_field)
                        && (*ok_t == Type::Int || *ok_t == Type::Bool)
                    {
                        bound_type = Some(val_t.clone());
                    }
                }

                let Some(payload_type) = bound_type else {
                    return Err(TypeError {
                        kind: TypeErrorKind::TypeMismatch,
                        message: format!(
                            "Semantic Error: Guard statement RHS expression must evaluate to a fallible wrapper type, but got {:?}",
                            resolved_val_type
                        ),
                        span: Some(value.span()),
                    });
                };

                // 2. Evaluate the diverging else_body block statement in an isolated scope
                let parent_scope = self.symbol_table.clone();
                let parent_origins = self.variable_origins.clone();
                let parent_moved = self.moved_vars.clone();

                for s in &else_body.statements {
                    self.check_statement(s)?;
                }

                // 3. Verify block divergence
                if !self.is_diverging_block(else_body) {
                    return Err(TypeError {
                        kind: TypeErrorKind::TypeMismatch,
                        message: "Semantic Error: Guard 'else' block must diverge (i.e. end with a return statement or an exit call)".to_string(),
                        span: Some(else_body.span),
                    });
                }

                // Restore parent scope after checks inside else_body
                self.symbol_table = parent_scope;
                self.variable_origins = parent_origins;
                self.moved_vars = parent_moved;

                // 4. Bind the <identifier> to the active symbol table using the type of the .Val field
                self.symbol_table.insert(name.clone(), payload_type.clone());
                self.variable_types
                    .insert(name.clone(), payload_type.clone());
                self.resolved_types.insert(*span, payload_type.clone());

                // 5. Track memory origins
                let origins = self.get_expression_origins(value);
                let is_cast_result = if let Type::Struct(ref struct_name, _) = resolved_val_type {
                    struct_name.starts_with("CastResult_")
                } else {
                    false
                };
                let mut final_origins = if self.is_ephemeral_view(&payload_type) || is_cast_result {
                    origins
                } else {
                    HashSet::new()
                };
                if final_origins.is_empty() {
                    final_origins.insert(name.clone());
                }
                self.variable_origins
                    .insert(name.clone(), final_origins.clone());
                self.all_variable_origins
                    .insert(name.clone(), final_origins);

                self.moved_vars.remove(name);

                if let Some(ref mut local_vars) = self.current_function_local_vars {
                    local_vars.insert(name.clone());
                }
            }
            Statement::VarDecl {
                name,
                is_mut: _,
                value,
                var_type,
                span,
                ..
            } => {
                let val_type = if let Some(val_expr) = value {
                    let mut t = self.check_expression(val_expr)?;
                    t = self.resolve_type(&t)?;
                    t = self.resolve_type_namespacing(&t)?;
                    let mut origs = if self.is_ephemeral_view(&t) {
                        self.get_expression_origins(val_expr)
                    } else {
                        HashSet::new()
                    };
                    // Fallback to itself as a root origin if expression contains no active origins
                    if origs.is_empty() {
                        origs.insert(name.clone());
                    }
                    self.variable_origins.insert(name.clone(), origs.clone());
                    self.all_variable_origins.insert(name.clone(), origs);
                    t
                } else {
                    if let Some(explicit_t) = var_type {
                        let mut origs = HashSet::new();
                        origs.insert(name.clone());
                        self.variable_origins.insert(name.clone(), origs.clone());
                        self.all_variable_origins.insert(name.clone(), origs);
                        let resolved = self.resolve_type(explicit_t)?;

                        self.resolve_type_namespacing(&resolved)?
                    } else {
                        return Err(TypeError {
                            kind: TypeErrorKind::UninitializedVariable,
                            message: format!(
                                "Semantic Error: Uninitialized variable '{}' must have an explicit type annotation",
                                name
                            ),
                            span: None,
                        });
                    }
                };

                if let Some(explicit_t) = var_type {
                    let resolved_explicit = self.resolve_type(explicit_t)?;
                    let resolved_explicit = self.resolve_type_namespacing(&resolved_explicit)?;
                    self.resolved_types.insert(*span, resolved_explicit.clone());

                    if !types_match(&resolved_explicit, &val_type) {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: format!(
                                "Semantic Error: Explicit Type Annotation Mismatch. Declared {:?} but got value {:?}",
                                resolved_explicit, val_type
                            ),
                            span: value.as_ref().map(|v| v.span()), // Tier B: Point directly to the offending RHS value
                        });
                    }
                    self.symbol_table
                        .insert(name.clone(), resolved_explicit.clone());
                    self.variable_types
                        .insert(name.clone(), resolved_explicit.clone());
                } else {
                    self.symbol_table.insert(name.clone(), val_type.clone());
                    self.variable_types.insert(name.clone(), val_type.clone());
                    self.resolved_types.insert(*span, val_type.clone());
                }

                if let Type::Struct(ref struct_name, _) = val_type
                    && struct_name.starts_with("os_Dir_")
                {
                    self.open_directories.insert(name.clone());
                }

                if let Some(ref mut local_vars) = self.current_function_local_vars {
                    local_vars.insert(name.clone());
                }
            }
            Statement::Assignment { left, value, .. } => {
                let left_type = match left {
                    Expression::Identifier(name, _) => {
                        if let Some(t) = self.symbol_table.get(name) {
                            Ok(t.clone())
                        } else {
                            Err(TypeError {
                                kind: TypeErrorKind::UndefinedVariable,
                                message: format!(
                                    "Semantic Error: Undefined variable '{}' in assignment LHS",
                                    name
                                ),
                                span: Some(left.span()), // Tier B: Point directly to LHS identifier
                            })
                        } 
                    }
                    _ => self.check_expression(left),
                }?;
                let val_type = self.check_expression(value)?;
                if !types_match(&left_type, &val_type) {
                    return Err(TypeError {
                        kind: TypeErrorKind::TypeMismatch,
                        message: format!(
                            "Semantic Error: Mismatched types in assignment. Cannot assign {:?} to {:?}",
                            val_type, left_type
                        ),
                        span: Some(value.span()), // Tier B: Point directly to RHS value
                    });
                }

                // Scratchpad storage restriction check (Step 3 verification)
                if let Expression::Selector {
                    left: selector_left,
                    ..
                } = left
                    && let Ok(parent_type) = self.check_expression(selector_left)
                    && self.get_type_brand(&parent_type).is_some()
                {
                    let rhs_origins = self.get_expression_origins(value);
                    if rhs_origins.contains("scratch") {
                        return Err(TypeError {
                            kind: TypeErrorKind::BrandLifetimeViolation,
                            message: format!(
                                "Semantic Error: Cannot assign scratchpad-allocated view to field of branded struct '{:?}'",
                                parent_type
                            ),
                            span: Some(value.span()),
                        });
                    }
                }

                let is_ptr_write = self.is_pointer_write(left);

                if !is_ptr_write {
                    // Invalidate any active views that borrow from the root variable being modified
                    if let Some(root_name) = get_root_variable(left) {
                        let mut to_invalidate = Vec::new();
                        for (var_name, origins) in &self.variable_origins {
                            if var_name != &root_name && origins.contains(&root_name) {
                                to_invalidate.push(var_name.clone());
                            }
                        }
                        for var in to_invalidate {
                            self.moved_vars.insert(var);
                        }
                    }

                    // Track assignments to variables to update their active memory origins
                    if let Some(root_name) = get_root_variable(left) {
                        let mut origs = if self.is_ephemeral_view(&left_type) {
                            self.get_expression_origins(value)
                        } else {
                            HashSet::new()
                        };
                        if matches!(left, Expression::Identifier(_, _)) {
                            if origs.is_empty() {
                                origs.insert(root_name.clone());
                            }
                            self.variable_origins
                                .insert(root_name.clone(), origs.clone());
                            self.all_variable_origins.insert(root_name.clone(), origs);
                        } else {
                            if !origs.is_empty() {
                                if let Some(existing) = self.variable_origins.get_mut(&root_name) {
                                    existing.extend(origs.clone());
                                } else {
                                    self.variable_origins
                                        .insert(root_name.clone(), origs.clone());
                                }
                                if let Some(existing) =
                                    self.all_variable_origins.get_mut(&root_name)
                                {
                                    existing.extend(origs.clone());
                                } else {
                                    self.all_variable_origins.insert(root_name.clone(), origs);
                                }
                            }
                        }
                        self.moved_vars.remove(&root_name); // Re-initialized!

                        if let Type::Struct(ref struct_name, _) = val_type
                            && struct_name.starts_with("os_Dir_")
                        {
                            self.open_directories.insert(root_name.clone());
                        }
                    }
                }
            }
            Statement::While {
                condition, body, ..
            } => {
                let cond_type = self.check_expression(condition)?;
                if cond_type != Type::Int && cond_type != Type::Bool {
                    return Err(TypeError {
                        kind: TypeErrorKind::LoopConditionInvalid,
                        message: "Semantic Error: Loop condition must evaluate to an Int or Bool (binary comparison or boolean)".to_string(),
                        span: Some(condition.span()), // Tier B: Point specifically to condition
                    });
                }

                let parent_scope = self.symbol_table.clone();
                for s in &body.statements {
                    self.check_statement(s)?;
                }
                self.symbol_table = parent_scope;
            }
            Statement::If {
                condition,
                consequence,
                alternative,
                ..
            } => {
                let cond_type = self.check_expression(condition)?;
                if cond_type != Type::Int && cond_type != Type::Bool {
                    return Err(TypeError {
                        kind: TypeErrorKind::IfConditionInvalid,
                        message: "Semantic Error: If condition must evaluate to an Int or Bool (binary comparison or boolean)".to_string(),
                        span: Some(condition.span()), // Tier B: Point specifically to condition
                    });
                }

                let pre_origins = self.variable_origins.clone();
                let pre_moved = self.moved_vars.clone();
                let pre_checked = self.checked_results.clone();

                let checked_var = self.extract_ok_checked_variable(condition);
                if let Some(ref var) = checked_var {
                    self.checked_results.insert(var.clone());
                }

                let parent_scope = self.symbol_table.clone();
                for s in &consequence.statements {
                    self.check_statement(s)?;
                }
                self.symbol_table = parent_scope;

                let consequence_origins = self.variable_origins.clone();
                let consequence_moved = self.moved_vars.clone();

                if let Some(alt_body) = alternative {
                    // Reset to pre-if state for alternative branch evaluation
                    self.variable_origins = pre_origins.clone();
                    self.moved_vars = pre_moved.clone();
                    self.checked_results = pre_checked.clone();

                    let parent_scope = self.symbol_table.clone();
                    for s in &alt_body.statements {
                        self.check_statement(s)?;
                    }
                    self.symbol_table = parent_scope;

                    let alternative_origins = self.variable_origins.clone();
                    let alternative_moved = self.moved_vars.clone();

                    // Classic compiler join-point union for conditional path merging
                    let mut merged_origins = pre_origins.clone();
                    let mut all_vars = HashSet::new();
                    all_vars.extend(consequence_origins.keys().cloned());
                    all_vars.extend(alternative_origins.keys().cloned());

                    for var in all_vars {
                        let orig_conseq = consequence_origins.get(&var);
                        let orig_alt = alternative_origins.get(&var);

                        match (orig_conseq, orig_alt) {
                            (Some(c_set), Some(a_set)) => {
                                let mut union_set = c_set.clone();
                                union_set.extend(a_set.clone());
                                merged_origins.insert(var, union_set);
                            }
                            (Some(c_set), None) => {
                                if let Some(p_set) = pre_origins.get(&var) {
                                    let mut union_set = p_set.clone();
                                    union_set.extend(c_set.clone());
                                    merged_origins.insert(var, union_set);
                                } else {
                                    merged_origins.insert(var, c_set.clone());
                                }
                            }
                            (None, Some(a_set)) => {
                                if let Some(p_set) = pre_origins.get(&var) {
                                    let mut union_set = p_set.clone();
                                    union_set.extend(a_set.clone());
                                    merged_origins.insert(var, union_set);
                                } else {
                                    merged_origins.insert(var, a_set.clone());
                                }
                            }
                            (None, None) => {}
                        }
                    }

                    let mut merged_moved = pre_moved;
                    merged_moved.extend(consequence_moved);
                    merged_moved.extend(alternative_moved);

                    self.variable_origins = merged_origins;
                    self.moved_vars = merged_moved;
                } else {
                    // Merging consequence outcomes with pre-if context
                    let mut merged_origins = pre_origins.clone();
                    for (var, c_set) in &consequence_origins {
                        if let Some(p_set) = pre_origins.get(var) {
                            if p_set != c_set {
                                let mut union_set = p_set.clone();
                                union_set.extend(c_set.clone());
                                merged_origins.insert(var.clone(), union_set);
                            }
                        } else {
                            merged_origins.insert(var.clone(), c_set.clone());
                        }
                    }

                    let mut merged_moved = pre_moved;
                    merged_moved.extend(consequence_moved);

                    self.variable_origins = merged_origins;
                    self.moved_vars = merged_moved;
                }

                // Restore checked_results for the parent scope
                self.checked_results = pre_checked;
            }
            Statement::Match {
                expression, cases, ..
            } => {
                let expr_type = self.check_expression(expression)?;

                // Get the enum name from expr_type
                if let Type::Struct(enum_name, _) = &expr_type {
                    if let Some(expected_variants) = self.enum_registry.get(enum_name).cloned() {
                        let mut matched_variants = HashSet::new();

                        for case in cases {
                            if !expected_variants.contains(&case.variant_name) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Semantic Error: Variant '{}' is not a valid variant of enum '{}'",
                                        case.variant_name, enum_name
                                    ),
                                    span: Some(case.span), // Tier B: Point to the offending match case
                                });
                            }

                            if matched_variants.contains(&case.variant_name) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Semantic Error: Duplicate match case for variant '{}' of enum '{}'",
                                        case.variant_name, enum_name
                                    ),
                                    span: Some(case.span), // Tier B: Point to duplicate match case
                                });
                            }
                            matched_variants.insert(case.variant_name.clone());

                            // Typecheck the case body in its own scope
                            let parent_scope = self.symbol_table.clone();
                            let parent_origins = self.variable_origins.clone();
                            let parent_all_origins = self.all_variable_origins.clone();

                            // Look up variant layout and inject destructured fields
                            if !case.fields.is_empty() {
                                let variant_struct_name =
                                    format!("{}_{}", enum_name, case.variant_name);
                                if let Some(layout) = self.struct_registry.get(&variant_struct_name)
                                {
                                    for field_name in &case.fields {
                                        if let Some(field_type) = layout.fields.get(field_name) {
                                            self.symbol_table
                                                .insert(field_name.clone(), field_type.clone());
                                            self.variable_types
                                                .insert(field_name.clone(), field_type.clone());

                                            // Flow the memory origin
                                            let parent_origins_set =
                                                self.get_expression_origins(expression);
                                            let mut final_origins =
                                                if self.is_ephemeral_view(field_type) {
                                                    parent_origins_set
                                                } else {
                                                    HashSet::new()
                                                };
                                            if final_origins.is_empty() {
                                                final_origins.insert(field_name.clone());
                                            }
                                            self.variable_origins
                                                .insert(field_name.clone(), final_origins.clone());
                                            self.all_variable_origins
                                                .insert(field_name.clone(), final_origins);

                                            if let Some(ref mut local_vars) =
                                                self.current_function_local_vars
                                            {
                                                local_vars.insert(field_name.clone());
                                            }
                                        } else {
                                            return Err(TypeError {
                                                kind: TypeErrorKind::FieldNotFound,
                                                message: format!(
                                                    "Semantic Error: Field '{}' not found on variant '{}' of enum '{}'",
                                                    field_name, case.variant_name, enum_name
                                                ),
                                                span: Some(case.span),
                                            });
                                        }
                                    }
                                } else {
                                    return Err(TypeError {
                                        kind: TypeErrorKind::TypeMismatch,
                                        message: format!(
                                            "Semantic Error: Struct layout for variant '{}' of enum '{}' not found",
                                            case.variant_name, enum_name
                                        ),
                                        span: Some(case.span),
                                    });
                                }
                            }

                            for s in &case.body.statements {
                                self.check_statement(s)?;
                            }
                            self.symbol_table = parent_scope;
                            self.variable_origins = parent_origins;
                            self.all_variable_origins = parent_all_origins;
                        }

                        // Exhaustiveness check: Ensure all variants are matched
                        for expected in &expected_variants {
                            if !matched_variants.contains(expected) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Semantic Error: Match on enum '{}' is not exhaustive. Missing variant '{}'",
                                        enum_name, expected
                                    ),
                                    span: None,
                                });
                            }
                        }
                    } else {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: format!(
                                "Semantic Error: Match target type '{:?}' is not a registered enum",
                                expr_type
                            ),
                            span: Some(expression.span()), // Tier B: Point directly to target expression
                        });
                    }
                } else {
                    return Err(TypeError {
                        kind: TypeErrorKind::TypeMismatch,
                        message: format!(
                            "Semantic Error: Match target type '{:?}' is not an enum struct",
                            expr_type
                        ),
                        span: Some(expression.span()), // Tier B: Point directly to target expression
                    });
                }
            }
            Statement::UnsafeBlock { body, .. } => {
                let was_unsafe = self.in_unsafe_block;
                self.in_unsafe_block = true;

                let parent_scope = self.symbol_table.clone();
                for s in &body.statements {
                    self.check_statement(s)?;
                }
                self.symbol_table = parent_scope;

                self.in_unsafe_block = was_unsafe;
            }
            Statement::Defer { expr, .. } => {
                self.check_expression(expr)?;
            }
            Statement::Return(maybe_expr, _) => {
                if let Some(ref inout_params) = self.current_function_inout_params {
                    for inout_p in inout_params {
                        if self.moved_vars.contains(inout_p) {
                            return Err(TypeError {
                                kind: TypeErrorKind::UseOfMovedVariable,
                                message: format!(
                                    "Semantic Error: Inout reference parameter '{}' was moved but never re-initialized before return",
                                    inout_p
                                ),
                                span: None,
                            });
                        }
                    }
                }

                let actual_return = if let Some(expr) = maybe_expr {
                    let mut t = self.check_expression(expr)?;
                    t = self.resolve_type(&t)?;

                    // Retrieve expression origins immutably first
                    let expr_origins = self.get_expression_origins(expr);

                    if expr_origins.contains("scratch") {
                        // Safe Scratchpad-allocated view check (Step 3 verification)
                        return Err(TypeError {
                            kind: TypeErrorKind::BrandLifetimeViolation,
                            message: format!(
                                "Semantic Error: Escape analysis violation. Returning scratchpad-allocated view of type {:?}",
                                t
                            ),
                            span: Some(expr.span()),
                        });
                    }

                    if self.contains_ephemeral_view(&t)
                        && let Some(ref local_vars) = self.current_function_local_vars
                    {
                        for origin in &expr_origins {
                            if local_vars.contains(origin) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::BrandLifetimeViolation,
                                    message: format!(
                                        "Semantic Error: Escape analysis violation. Returning ephemeral view of type {:?} whose origin traces back to local stack variable '{}'",
                                        t, origin
                                    ),
                                    span: Some(expr.span()), // Tier B: Point to local escape target
                                });
                            }
                        }
                    }

                    // Populate return statement origins to the enclosing function
                    if let Some(ref mut return_origins_set) = self.current_function_return_origins {
                        return_origins_set.extend(expr_origins);
                    }
                    t
                } else {
                    Type::Void
                };

                if let Some(expected_t) = &self.expected_return_type {
                    if !types_match(expected_t, &actual_return) {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: format!(
                                "Semantic Error: Return type mismatch. Expected {:?} but got {:?}",
                                expected_t, actual_return
                            ),
                            span: maybe_expr.as_ref().map(|e| e.span()), // Tier B: Point to returned expression
                        });
                    }
                } else {
                    return Err(TypeError {
                        kind: TypeErrorKind::ReturnOutsideFunction,
                        message: "Semantic Error: Return statement used outside function body"
                            .to_string(),
                        span: None,
                    });
                }
            }
            Statement::Expression(expr, _) => {
                self.check_expression(expr)?;
            }
        }
        Ok(())
    }

    pub fn is_pointer_write(&self, expr: &Expression) -> bool {
        match expr {
            Expression::Dereference(_, _) => true,
            Expression::IndexAccess { .. } => true,
            Expression::Selector { left, .. } => {
                if let Some(left_type) = self.resolved_types.get(&left.span()) {
                    matches!(left_type, Type::RawPointer(_)) || self.is_pointer_write(left)
                } else {
                    self.is_pointer_write(left)
                }
            }
            Expression::AsCast { left, .. } => self.is_pointer_write(left),
            Expression::Move(inner, _) => self.is_pointer_write(inner),
            Expression::Take(inner, _) => self.is_pointer_write(inner),
            _ => false,
        }
    }

    // Dynamic, recursive Set-Based memory origin extractor
    pub fn get_expression_origins(&self, expr: &Expression) -> HashSet<String> {
        match expr {
            Expression::Identifier(name, _) => {
                if let Some(t) = self.symbol_table.get(name) {
                    // Value-types (POD structs, primitive types) do not borrow/carry origins
                    let is_pod_struct = if let Type::Struct(_, None) = t {
                        !self.is_linear(t) && !self.contains_ephemeral_view(t)
                    } else {
                        false
                    };
                    if is_pod_struct || *t == Type::Int || *t == Type::Byte || *t == Type::Bool {
                        return HashSet::new();
                    }
                }
                if let Some(origins) = self.variable_origins.get(name) {
                    origins.clone()
                } else if name == "null" {
                    HashSet::new()
                } else {
                    let mut s = HashSet::new();
                    s.insert(name.clone());
                    s
                }
            }
            Expression::AsCast { left, .. } => self.get_expression_origins(left),
            Expression::AddressOf(inner, _) => self.get_expression_origins(inner),
            Expression::Dereference(inner, _) => self.get_expression_origins(inner),
            Expression::Selector { left, .. } => self.get_expression_origins(left),
            Expression::IndexAccess { allocator, .. } => self.get_expression_origins(allocator),
            Expression::Move(inner, _) => {
                if let Expression::Identifier(name, _) = &**inner
                    && let Some(t) = self.symbol_table.get(name)
                    && !self.is_linear(t)
                {
                    return HashSet::new();
                }
                self.get_expression_origins(inner)
            }
            Expression::Take(inner, _) => {
                if let Expression::Identifier(name, _) = &**inner
                    && let Some(t) = self.symbol_table.get(name)
                    && !self.is_linear(t)
                {
                    return HashSet::new();
                }
                self.get_expression_origins(inner)
            }
            Expression::Call {
                function,
                arguments,
                ..
            } => {
                let raw_func_path = expression_to_string(function);
                let func_path = self
                    .resolve_namespaced_ident(&raw_func_path)
                    .unwrap_or(raw_func_path);
                if func_path == "os.ScratchAlloc"
                    || func_path == "os_ScratchAlloc"
                    || func_path == "std.FormatInt"
                    || func_path == "std_FormatInt"
                    || func_path == "std.Concat"
                    || func_path == "std_Concat"
                    || func_path == "std.Format"
                    || func_path == "std_Format"
                {
                    let mut call_origins = HashSet::new();
                    call_origins.insert("scratch".to_string());
                    return call_origins;
                }
                if (func_path == "std.VectorNew"
                    || func_path == "os.VectorNew"
                    || func_path == "std_VectorNew"
                    || func_path == "os_VectorNew"
                    || func_path == "std.HashMapNew"
                    || func_path == "os.HashMapNew"
                    || func_path == "std_HashMapNew"
                    || func_path == "os_HashMapNew"
                    || func_path == "std.PoolNew"
                    || func_path == "os.PoolNew"
                    || func_path == "std_PoolNew"
                    || func_path == "os_PoolNew"
                    || func_path == "std.GraphNew"
                    || func_path == "std_GraphNew"
                    || func_path == "std.MutexNew"
                    || func_path == "std_MutexNew"
                    || func_path == "std.ChannelNew"
                    || func_path == "std_ChannelNew")
                    && !arguments.is_empty()
                {
                    return self.get_expression_origins(&arguments[0]);
                }
                if let Some(sig) = self.function_registry.get(&func_path).cloned() {
                    let mut call_origins = HashSet::new();
                    if self.contains_ephemeral_view(&sig.return_type) {
                        for arg in arguments {
                            let arg_origins = self.get_expression_origins(arg);
                            call_origins.extend(arg_origins);
                        }
                    } else {
                        let mut param_map = HashMap::new();
                        for (i, param_name) in sig.param_names.iter().enumerate() {
                            if i < arguments.len() {
                                param_map.insert(
                                    param_name.clone(),
                                    self.get_expression_origins(&arguments[i]),
                                );
                            }
                        }
                        // Propagate and map formal argument placeholders to call-site values
                        for formal_origin in &sig.return_origins {
                            if let Some(actual_origins) = param_map.get(formal_origin) {
                                call_origins.extend(actual_origins.clone());
                            } else {
                                call_origins.insert(formal_origin.clone());
                            }
                        }
                    }
                    call_origins
                } else {
                    HashSet::new()
                }
            }
            _ => HashSet::new(),
        }
    }

    // Tier A: Entry-Point Interception Wrapper for Expressions
    pub fn check_expression(&mut self, expr: &Expression) -> Result<Type, TypeError> {
        let res = self.check_expression_internal(expr);
        match res {
            Err(mut err) => {
                if err.span.is_none() {
                    err.span = Some(expr.span());
                }
                Err(err)
            }
            Ok(t) => {
                self.resolved_types.insert(expr.span(), t.clone());
                Ok(t)
            }
        }
    }

    fn check_expression_internal(&mut self, expr: &Expression) -> Result<Type, TypeError> {
        match expr {
            Expression::Identifier(name, span) => {
                let resolved_name = if self.symbol_table.contains_key(name) {
                    name.clone()
                } else {
                    self.resolve_namespaced_ident(name)?
                };
                self.resolved_names.insert(*span, resolved_name.clone());

                if self.moved_vars.contains(&resolved_name) {
                    return Err(TypeError {
                        kind: TypeErrorKind::UseOfMovedVariable,
                        message: format!("Semantic Error: Use of moved variable '{}'", name),
                        span: None,
                    });
                }

                // Union evaluation: Reject reading if ANY of the potential origins are moved/invalid
                if let Some(origins) = self.variable_origins.get(&resolved_name) {
                    for origin in origins {
                        if self.moved_vars.contains(origin) {
                            return Err(TypeError {
                                kind: TypeErrorKind::VariableOriginInvalidated,
                                message: format!(
                                    "Semantic Error: Variable '{}' cannot be used because its backing origin '{}' has been moved or invalidated",
                                    name, origin
                                ),
                                span: None,
                            });
                        }
                    }
                }

                if let Some(t) = self.symbol_table.get(&resolved_name) {
                    if let Some(brand) = self.get_type_brand(t)
                        && self.moved_vars.contains(&brand)
                    {
                        return Err(TypeError {
                            kind: TypeErrorKind::AllocatorMovedOrFreed,
                            message: format!(
                                "Semantic Error: Variable '{}' cannot be used because its branding allocator '{}' has been moved or freed",
                                name, brand
                            ),
                            span: None,
                        });
                    }
                    Ok(t.clone())
                } else {
                    if name == "null" {
                        return Ok(Type::Index("Any".to_string(), None));
                    }
                    Err(TypeError {
                        kind: TypeErrorKind::UndefinedVariable,
                        message: format!("Semantic Error: Undefined variable '{}'", name),
                        span: None,
                    })
                }
            }
            Expression::Integer(_, _) => Ok(Type::Int),
            Expression::String(_, _) => Ok(Type::Str), // Added for String Views Option 2
            Expression::Bool(_, _) => Ok(Type::Bool),
            Expression::Move(inner_expr, _) => {
                if let Expression::Identifier(name, _) = &**inner_expr {
                    if self.moved_vars.contains(name) {
                        return Err(TypeError {
                            kind: TypeErrorKind::UseOfMovedVariable,
                            message: format!(
                                "Semantic Error: Variable '{}' has already been moved",
                                name
                            ),
                            span: None,
                        });
                    }
                    let Some(var_type) = self.symbol_table.get(name).cloned() else {
                        return Err(TypeError {
                            kind: TypeErrorKind::UndefinedVariable,
                            message: format!(
                                "Semantic Error: Cannot move undefined variable '{}'",
                                name
                            ),
                            span: None,
                        });
                    };

                    if let Some(origins) = self.variable_origins.get(name) {
                        for origin in origins {
                            if self.moved_vars.contains(origin) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::VariableOriginInvalidated,
                                    message: format!(
                                        "Semantic Error: Variable '{}' cannot be moved because its backing origin '{}' has been moved or invalidated",
                                        name, origin
                                    ),
                                    span: None,
                                });
                            }
                        }
                    }

                    if var_type == Type::Arena {
                        // 1. Isolation Check
                        if let Some(ref local_vars) = self.current_function_local_vars {
                            for (v, origins) in &self.variable_origins {
                                if v == name {
                                    continue;
                                }
                                if let Some(v_type) = self.symbol_table.get(v)
                                    && self.get_type_brand(v_type) == Some(name.clone())
                                {
                                    for origin in origins {
                                        if local_vars.contains(origin) && origin != name {
                                            let is_origin_branded = if let Some(orig_type) =
                                                self.symbol_table.get(origin)
                                            {
                                                self.get_type_brand(orig_type) == Some(name.clone())
                                            } else {
                                                false
                                            };
                                            if !is_origin_branded {
                                                return Err(TypeError {
                                                    kind: TypeErrorKind::BrandLifetimeViolation,
                                                    message: format!(
                                                        "Semantic Error: Thread-safety violation. Branded variable '{}' has origin tracing back to thread-local stack variable '{}', preventing safe handoff of arena '{}'",
                                                        v, origin, name
                                                    ),
                                                    span: None,
                                                });
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 2. Transitive Invalidation
                        let mut to_invalidate = Vec::new();
                        for (v, v_type) in &self.symbol_table {
                            if self.get_type_brand(v_type) == Some(name.clone()) {
                                to_invalidate.push(v.clone());
                            }
                        }
                        for v in to_invalidate {
                            self.moved_vars.insert(v.clone());
                            self.open_directories.remove(&v);
                        }
                    }

                    if self.open_directories.contains(name) {
                        return Err(TypeError {
                            kind: TypeErrorKind::BrandLifetimeViolation,
                            message: format!(
                                "Semantic Error: Directory resource variable '{}' cannot be moved while open. Close it first.",
                                name
                            ),
                            span: None,
                        });
                    }

                    if self.is_linear(&var_type) {
                        self.moved_vars.insert(name.clone());
                    }
                    Ok(var_type)
                } else {
                    let is_place = matches!(
                        &**inner_expr,
                        Expression::Selector { .. }
                            | Expression::Dereference(..)
                            | Expression::IndexAccess { .. }
                            | Expression::AsCast { .. }
                            | Expression::Call { .. }
                    );

                    if is_place {
                        let var_type = self.check_expression(inner_expr)?;
                        if let Some(root_name) = get_root_variable(inner_expr) {
                            if self.moved_vars.contains(&root_name) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::UseOfMovedVariable,
                                    message: format!(
                                        "Semantic Error: Variable '{}' has already been moved",
                                        root_name
                                    ),
                                    span: None,
                                });
                            }
                            if let Some(origins) = self.variable_origins.get(&root_name) {
                                for origin in origins {
                                    if self.moved_vars.contains(origin) {
                                        return Err(TypeError {
                                            kind: TypeErrorKind::VariableOriginInvalidated,
                                            message: format!(
                                                "Semantic Error: Variable '{}' cannot be used because its backing origin '{}' has been moved or invalidated",
                                                root_name, origin
                                            ),
                                            span: None,
                                        });
                                    }
                                }
                            }
                        }
                        Ok(var_type)
                    } else {
                        Err(TypeError {
                            kind: TypeErrorKind::InvalidMoveTarget,
                            message: "Semantic Error: Only variables can be moved".to_string(),
                            span: None,
                        })
                    }
                }
            }
            Expression::Take(inner_expr, _) => {
                let expr_type = self.check_expression(inner_expr)?;
                if expr_type == Type::Int || expr_type == Type::Byte {
                    return Err(TypeError {
                        kind: TypeErrorKind::TakePrimitiveBanned,
                        message: "Semantic Error: The 'take' operator is strictly banned on primitive POD types (like Int)".to_string(),
                        span: None,
                    });
                }
                Ok(expr_type)
            }
            Expression::AddressOf(inner, _) => {
                let inner_type = self.check_expression(inner)?;
                Ok(Type::RawPointer(Box::new(inner_type)))
            }
            Expression::Dereference(inner, _) => {
                if !self.in_unsafe_block {
                    return Err(TypeError {
                        kind: TypeErrorKind::UnsafeProhibited,
                        message: "Semantic Error: Dereferencing raw pointers is strictly prohibited outside 'unsafe' blocks".to_string(),
                        span: None,
                    });
                }

                let inner_type = self.check_expression(inner)?;
                if let Type::RawPointer(target_type) = inner_type {
                    Ok((*target_type).clone())
                } else {
                    Err(TypeError {
                        kind: TypeErrorKind::DereferenceNonPointer,
                        message: format!(
                            "Semantic Error: Cannot dereference non-pointer type {:?}",
                            inner_type
                        ),
                        span: None,
                    })
                }
            }
            Expression::AsCast {
                left,
                target_type,
                is_reference: _,
                span,
                ..
            } => {
                let left_type = self.check_expression(left)?;
                let resolved_target = self.resolve_type(target_type)?;
                let resolved_target = self.resolve_type_namespacing(&resolved_target)?;
                self.resolved_types.insert(*span, resolved_target.clone());

                if (left_type == Type::Int
                    || left_type == Type::Byte
                    || left_type == Type::Bool
                    || matches!(left_type, Type::Index(_, _)))
                    && (resolved_target == Type::Int
                        || resolved_target == Type::Byte
                        || resolved_target == Type::Bool
                        || matches!(resolved_target, Type::Index(_, _)))
                {
                    if (matches!(left_type, Type::Index(_, _))
                        || matches!(resolved_target, Type::Index(_, _)))
                        && !self.in_unsafe_block
                    {
                        return Err(TypeError {
                            kind: TypeErrorKind::UnsafeProhibited,
                            message: "Semantic Error: Casting to or from Index types is strictly prohibited outside 'unsafe' blocks".to_string(),
                            span: None,
                        });
                    }
                    return Ok(resolved_target.clone());
                }

                if let Type::RawPointer(_) = left_type {
                    if !self.in_unsafe_block {
                        return Err(TypeError {
                            kind: TypeErrorKind::UnsafeProhibited,
                            message: "Semantic Error: Casting pointers is strictly prohibited outside 'unsafe' blocks".to_string(),
                            span: None,
                        });
                    }
                    if let Type::RawPointer(_) = &resolved_target {
                        return Ok(resolved_target.clone());
                    }
                    if let Type::Slice(_) = &resolved_target {
                        return Ok(resolved_target.clone());
                    }
                    if resolved_target == Type::ByteSlice {
                        return Ok(resolved_target.clone());
                    }
                    if resolved_target == Type::Str {
                        return Ok(resolved_target.clone());
                    }
                }

                if let Type::RawPointer(_) = &resolved_target
                    && !self.in_unsafe_block
                {
                    return Err(TypeError {
                            kind: TypeErrorKind::UnsafeProhibited,
                            message: "Semantic Error: Casting to raw pointers is strictly prohibited outside 'unsafe' blocks".to_string(),
                            span: None,
                        });
                }

                let is_left_slice_like = matches!(left_type, Type::Slice(_))
                    || left_type == Type::ByteSlice
                    || left_type == Type::Str;
                let is_target_slice_like = matches!(resolved_target, Type::Slice(_))
                    || resolved_target == Type::ByteSlice
                    || resolved_target == Type::Str;

                if is_left_slice_like && is_target_slice_like {
                    if !self.in_unsafe_block {
                        return Err(TypeError {
                            kind: TypeErrorKind::UnsafeProhibited,
                            message: "Semantic Error: Casting slice-like types is strictly prohibited outside 'unsafe' blocks".to_string(),
                            span: None,
                        });
                    }
                    return Ok(resolved_target.clone());
                }

                if !matches!(left_type, Type::Slice(_)) && left_type != Type::ByteSlice {
                    return Err(TypeError {
                        kind: TypeErrorKind::InvalidCast,
                        message: format!(
                            "Semantic Error: Casting source must be a Slice, but got {:?}",
                            left_type
                        ),
                        span: None,
                    });
                }

                if let Type::Struct(struct_name, _) = &resolved_target
                    && self.struct_registry.contains_key(struct_name)
                {
                    return Ok(Type::Struct(format!("CastResult_{}", struct_name), None));
                }

                Err(TypeError {
                    kind: TypeErrorKind::InvalidCast,
                    message: format!(
                        "Semantic Error: Unsupported cast target type {:?}",
                        resolved_target
                    ),
                    span: None,
                })
            }
            Expression::IndexAccess {
                allocator, index, ..
            } => {
                let alloc_type = self.check_expression(allocator)?;
                let index_type = self.check_expression(index)?;

                if let Type::Slice(elem_type) = &alloc_type {
                    if index_type != Type::Int && index_type != Type::Byte {
                        return Err(TypeError {
                            kind: TypeErrorKind::InvalidIndexType,
                            message: "Semantic Error: Slice index must resolve to an Int or Byte"
                                .to_string(),
                            span: Some(index.span()), // Tier B: Point directly to index
                        });
                    }
                    let resolved_elem = self.resolve_type(elem_type)?;
                    Ok(resolved_elem)
                } else if alloc_type == Type::Str {
                    if index_type != Type::Int && index_type != Type::Byte {
                        return Err(TypeError {
                            kind: TypeErrorKind::InvalidIndexType,
                            message: "Semantic Error: String index must resolve to an Int or Byte"
                                .to_string(),
                            span: Some(index.span()), // Tier B: Point directly to index
                        });
                    }
                    Ok(Type::Byte)
                } else if let Type::Struct(struct_name, _) = &alloc_type {
                    if struct_name.starts_with("Vector_") || struct_name.starts_with("std_Vector_")
                    {
                        if index_type != Type::Int && index_type != Type::Byte {
                            return Err(TypeError {
                                kind: TypeErrorKind::InvalidIndexType,
                                message: "Vector index must resolve to an Int or Byte".to_string(),
                                span: Some(index.span()), // Tier B: Point directly to index
                            });
                        }
                        let elem_type =
                            self.get_vector_element_type(struct_name)
                                .ok_or_else(|| TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: "Invalid Vector struct layout".to_string(),
                                    span: None,
                                })?;
                        Ok(elem_type)
                    } else if struct_name.starts_with("HashMap_")
                        || struct_name.starts_with("std_HashMap_")
                    {
                        let (k_type, v_type) = self
                            .get_hashmap_key_value_types(struct_name)
                            .ok_or_else(|| TypeError {
                                kind: TypeErrorKind::TypeMismatch,
                                message: "Invalid HashMap struct layout".to_string(),
                                span: None,
                            })?;
                        if !types_match(&k_type, &index_type) {
                            return Err(TypeError {
                                kind: TypeErrorKind::InvalidIndexType,
                                message: format!(
                                    "HashMap index type mismatch. Expected {:?} but got {:?}",
                                    k_type, index_type
                                ),
                                span: Some(index.span()), // Tier B: Point directly to index
                            });
                        }
                        Ok(v_type)
                    } else if struct_name.starts_with("Pool_")
                        || struct_name.starts_with("std_Pool_")
                    {
                        if index_type != Type::Int
                            && index_type != Type::Byte
                            && !matches!(index_type, Type::Index(_, _))
                        {
                            return Err(TypeError {
                                kind: TypeErrorKind::InvalidIndexType,
                                message: "Pool index must resolve to an Int or Byte or Index"
                                    .to_string(),
                                span: Some(index.span()), // Tier B: Point directly to index
                            });
                        }
                        let elem_type =
                            self.get_pool_element_type(struct_name)
                                .ok_or_else(|| TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: "Invalid Pool struct layout".to_string(),
                                    span: None,
                                })?;
                        Ok(elem_type)
                    } else {
                        Err(TypeError {
                            kind: TypeErrorKind::InvalidIndexTarget,
                            message: format!(
                                "Semantic Error: Subscript indexing is only valid on Arenas, Slices, Vectors, HashMaps, or Pools, but got {:?}",
                                alloc_type
                            ),
                            span: None,
                        })
                    }
                } else if alloc_type == Type::Arena
                    || matches!(alloc_type, Type::RawPointer(ref inner) if **inner == Type::Arena)
                {
                    let alloc_name = expression_to_string(allocator);
                    if let Type::Index(struct_name, Some(brand_name)) = index_type {
                        if brand_name != alloc_name
                            && !alloc_name.ends_with(&format!(".{}", brand_name))
                        {
                            return Err(TypeError {
                                kind: TypeErrorKind::BrandLifetimeViolation,
                                message: format!(
                                    "Semantic Error: Value-Branded Lifetime Violation! Attempted to index allocator '{}' with index '{}' branded for '{}'",
                                    alloc_name,
                                    expression_to_string(index),
                                    brand_name
                                ),
                                span: Some(index.span()), // Tier B: Point directly to offending index
                            });
                        }

                        let mut actual_struct = struct_name;
                        if actual_struct == "Any" {
                            actual_struct = "SessionNode".to_string();
                        }

                        Ok(Type::Struct(actual_struct, Some(brand_name)))
                    } else {
                        Err(TypeError {
                            kind: TypeErrorKind::InvalidIndexTarget,
                            message: format!(
                                "Semantic Error: Expected a branded Index offset for subscript indexing, but got {:?}",
                                index_type
                            ),
                            span: None,
                        })
                    }
                } else {
                    Err(TypeError {
                        kind: TypeErrorKind::InvalidIndexTarget,
                        message: format!(
                            "Semantic Error: Subscript indexing is only valid on Arenas, Slices, Vectors, HashMaps, or Pools, but got {:?}",
                            alloc_type
                        ),
                        span: None,
                    })
                }
            }
            Expression::Binary {
                op, left, right, ..
            } => {
                let left_type = self.check_expression(left)?;
                let right_type = self.check_expression(right)?;

                if op == "==" || op == "!=" {
                    if let Type::Index(_, _) = left_type
                        && let Expression::Identifier(name, _) = &**right
                        && name == "null"
                    {
                        return Ok(Type::Int);
                    }
                    if let Type::Index(_, _) = right_type
                        && let Expression::Identifier(name, _) = &**left
                        && name == "null"
                    {
                        return Ok(Type::Int);
                    }
                }

                if (op == "+" || op == "-")
                    && matches!(left_type, Type::RawPointer(_))
                    && (right_type == Type::Int || right_type == Type::Byte)
                {
                    if !self.in_unsafe_block {
                        return Err(TypeError {
                            kind: TypeErrorKind::UnsafeProhibited,
                            message: "Semantic Error: Pointer arithmetic is strictly prohibited outside 'unsafe' blocks".to_string(),
                            span: None,
                        });
                    }
                    return Ok(left_type);
                }

                if !types_match(&left_type, &right_type) {
                    return Err(TypeError {
                        kind: TypeErrorKind::TypeMismatch,
                        message: format!(
                            "Semantic Error: Mismatched types in binary operation '{}'. Left: {:?}, Right: {:?}",
                            op, left_type, right_type
                        ),
                        span: None,
                    });
                }

                if (op == "+" || op == "-" || op == "*" || op == "/")
                    && left_type != Type::Int
                    && left_type != Type::Byte
                {
                    return Err(TypeError {
                        kind: TypeErrorKind::TypeMismatch,
                        message: format!(
                            "Semantic Error: Math operation '{}' is only allowed on Int or Byte types, but got {:?}",
                            op, left_type
                        ),
                        span: None,
                    });
                }

                Ok(Type::Int)
            }
            Expression::Selector { left, right, .. } => {
                let mut left_type = self.check_expression(left)?;
                if let Type::RawPointer(inner) = &left_type {
                    left_type = *inner.clone();
                }
                let left_str = expression_to_string(left);
                let path = format!("{}.{}", left_str, right);

                if path == "os.Arena" {
                    return Ok(Type::Void);
                }

                if let Type::Struct(struct_name, _brand) = &left_type {
                    let clean_struct_name = strip_brand_prefix(struct_name);
                    if clean_struct_name.starts_with("CastResult_")
                        || clean_struct_name.starts_with("LookupResult_")
                    {
                        if right == "Ok" {
                            return Ok(Type::Int);
                        }
                        if right == "Val" {
                            // Definite Check Rule
                            if !self.checked_results.contains(&left_str) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Semantic Error: Accessing the .Val payload of an unchecked result wrapper '{}'",
                                        left_str
                                    ),
                                    span: None,
                                });
                            }

                            let prefix = if clean_struct_name.starts_with("CastResult_") {
                                "CastResult_"
                            } else {
                                "LookupResult_"
                            };
                            let target_struct = clean_struct_name.strip_prefix(prefix).unwrap_or(&clean_struct_name).to_string();
                            if target_struct == "int" {
                                return Ok(Type::Int);
                            }
                            return Ok(Type::Struct(target_struct, None));
                        }
                    }
                    if let Some(layout) = self.struct_registry.get(struct_name) {
                        if let Some(field_type) = layout.fields.get(right) {
                            let returned_type =
                                self.substitute_field_brand(field_type, _brand, &left_str, layout);
                            let resolved_returned = self.resolve_type(&returned_type)?;
                            return Ok(resolved_returned);
                        }
                        return Err(TypeError {
                            kind: TypeErrorKind::FieldNotFound,
                            message: format!(
                                "Semantic Error: Field '{}' not found on struct layout '{}'",
                                right, struct_name
                            ),
                            span: None,
                        });
                    }
                }

                if left_type == Type::Arena {
                    if right == "Free" {
                        return Ok(Type::Void);
                    }
                    if right == "Offset" || right == "Capacity" {
                        return Ok(Type::Int);
                    }
                    return Err(TypeError {
                        kind: TypeErrorKind::MethodNotFound,
                        message: format!(
                            "Semantic Error: Method '{}' not found on Arena allocator",
                            right
                        ),
                        span: None,
                    });
                }

                Err(TypeError {
                    kind: TypeErrorKind::UnresolvedSelector,
                    message: "Semantic Error: Unresolved namespace selector".to_string(),
                    span: None,
                })
            }
            Expression::Call {
                function,
                arguments,
                ..
            } => {
                let raw_func_path = expression_to_string(function);
                let func_path = self
                    .resolve_namespaced_ident(&raw_func_path)
                    .unwrap_or_else(|_| raw_func_path.clone());

                tracing::debug!(
                    "👁️ Expression::Call Evaluation Start: Raw Function: '{}', Resolved: '{}', Registry Has Key: {}",
                    raw_func_path,
                    func_path,
                    self.function_registry.contains_key(&func_path)
                );

                if func_path == "std.Format" || func_path == "std_Format" {
                    self.resolved_names
                        .insert(function.span(), func_path.clone());
                    if arguments.is_empty() {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: std.Format expects at least 1 argument (the format string literal)".to_string(),
                            span: Some(function.span()),
                        });
                    }

                    let format_str = match &arguments[0] {
                        Expression::String(s, _) => s.clone(),
                        _ => {
                            return Err(TypeError {
                                kind: TypeErrorKind::TypeMismatch,
                                message: "Semantic Error: First argument to std.Format must be a string literal".to_string(),
                                span: Some(arguments[0].span()),
                            });
                        }
                    };

                    let mut specifier_types = Vec::new();
                    let chars: Vec<char> = format_str.chars().collect();
                    let mut i = 0;
                    while i < chars.len() {
                        if chars[i] == '%' && i + 1 < chars.len() {
                            let next_char = chars[i + 1];
                            if next_char == '%' {
                                i += 2;
                                continue;
                            } else if next_char == 's' {
                                specifier_types.push(Type::Str);
                                i += 2;
                            } else if next_char == 'd' {
                                specifier_types.push(Type::Int);
                                i += 2;
                            } else {
                                i += 1;
                            }
                        } else {
                            i += 1;
                        }
                    }

                    let expected_count = specifier_types.len();
                    let trailing_args_count = arguments.len() - 1;
                    if trailing_args_count != expected_count {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: format!(
                                "Semantic Error: std.Format template expected {} arguments, but got {}",
                                expected_count, trailing_args_count
                            ),
                            span: Some(function.span()),
                        });
                    }

                    for (idx, expected_t) in specifier_types.iter().enumerate() {
                        let arg_idx = idx + 1;
                        let arg_type = self.check_expression(&arguments[arg_idx])?;
                        let resolved_arg = self.resolve_type(&arg_type)?;

                        if *expected_t == Type::Str {
                            if resolved_arg != Type::Str {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Semantic Error: std.Format argument {} expected Str, but got {:?}",
                                        arg_idx, resolved_arg
                                    ),
                                    span: Some(arguments[arg_idx].span()),
                                });
                            }
                        } else if *expected_t == Type::Int {
                            let is_compatible = resolved_arg == Type::Int
                                || resolved_arg == Type::Byte
                                || resolved_arg == Type::Bool
                                || matches!(resolved_arg, Type::Index(_, _));
                            if !is_compatible {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Semantic Error: std.Format argument {} expected Int, Byte, Bool, or Index, but got {:?}",
                                        arg_idx, resolved_arg
                                    ),
                                    span: Some(arguments[arg_idx].span()),
                                });
                            }
                        }
                    }

                    return Ok(Type::Str);
                }

                if func_path == "len" {
                    if arguments.len() != 1 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: len expects exactly 1 argument".to_string(),
                            span: None,
                        });
                    }
                    let arg_type = self.check_expression(&arguments[0])?;
                    if let Type::Slice(_) = arg_type {
                        return Ok(Type::Int);
                    }
                    if arg_type == Type::Str {
                        return Ok(Type::Int);
                    }
                    if let Type::Struct(struct_name, _) = &arg_type
                        && (struct_name.starts_with("Vector_")
                            || struct_name.starts_with("std_Vector_")
                            || struct_name.starts_with("HashMap_")
                            || struct_name.starts_with("std_HashMap_")
                            || struct_name.starts_with("Pool_")
                            || struct_name.starts_with("std_Pool_"))
                    {
                        return Ok(Type::Int);
                    }
                    return Err(TypeError {
                        kind: TypeErrorKind::ArgumentMismatch,
                        message: format!(
                            "Semantic Error: len expects a Slice, Str, Vector, HashMap, or Pool argument, but got {:?}",
                            arg_type
                        ),
                        span: None,
                    });
                }

                if func_path == "std.Clone" || func_path == "std_Clone" {
                    if arguments.len() != 2 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: std.Clone expects exactly 2 arguments (destination_allocator, source_value)".to_string(),
                            span: None,
                        });
                    }
                    let dest_type = self.check_expression(&arguments[0])?;
                    if dest_type != Type::Arena
                        && !matches!(dest_type, Type::RawPointer(ref inner) if **inner == Type::Arena)
                    {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: "Semantic Error: std.Clone first argument must be an Arena allocator".to_string(),
                            span: None,
                        });
                    }
                    let src_type = self.check_expression(&arguments[1])?;
                    let dest_brand = expression_to_string(&arguments[0]);
                    let src_brand = self
                        .get_type_brand(&src_type)
                        .unwrap_or_else(|| "Any".to_string());

                    let mut brand_map = HashMap::new();
                    brand_map.insert(src_brand, dest_brand);

                    let cloned_type = self.substitute_brand_names(&src_type, &brand_map);
                    let cloned_type = self.resolve_type(&cloned_type)?;
                    return Ok(cloned_type);
                }

                if func_path == "std.GenerationalSwap" || func_path == "std_GenerationalSwap" {
                    if arguments.len() != 2 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: std.GenerationalSwap expects exactly 2 arguments (current_ctx, next_ctx)".to_string(),
                            span: None,
                        });
                    }
                    let current_type = self.check_expression(&arguments[0])?;
                    let next_type = self.check_expression(&arguments[1])?;
                    if current_type != Type::Arena || next_type != Type::Arena {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: "Semantic Error: std.GenerationalSwap arguments must be Arena allocators".to_string(),
                            span: None,
                        });
                    }

                    let current_brand = expression_to_string(&arguments[0]);
                    let next_brand = expression_to_string(&arguments[1]);

                    // 1. Invalidate all variables branded with `current_brand`
                    let mut to_invalidate = Vec::new();
                    for (var_name, var_type) in &self.symbol_table {
                        if self.get_type_brand(var_type) == Some(current_brand.clone()) {
                            to_invalidate.push(var_name.clone());
                        }
                    }
                    for var in to_invalidate {
                        self.moved_vars.insert(var);
                    }

                    // 2. Rebrand all variables branded with `next_brand` to `current_brand`
                    let mut brand_map = HashMap::new();
                    brand_map.insert(next_brand.clone(), current_brand.clone());

                    let mut updated_symbols = HashMap::new();
                    for (var_name, var_type) in &self.symbol_table {
                        if self.get_type_brand(var_type) == Some(next_brand.clone()) {
                            let updated_type = self.substitute_brand_names(var_type, &brand_map);
                            updated_symbols.insert(var_name.clone(), updated_type);
                        }
                    }
                    for (var_name, updated_type) in updated_symbols {
                        self.symbol_table
                            .insert(var_name.clone(), updated_type.clone());
                        self.variable_types.insert(var_name.clone(), updated_type);
                    }

                    return Ok(Type::Void);
                }

                if func_path == "os.VectorNew"
                    || func_path == "std.VectorNew"
                    || func_path == "os_VectorNew"
                    || func_path == "std_VectorNew"
                {
                    if arguments.len() != 1 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: VectorNew expects exactly 1 argument"
                                .to_string(),
                            span: None,
                        });
                    }
                    let arg_type = self.check_expression(&arguments[0])?;
                    if arg_type != Type::Arena
                        && !matches!(arg_type, Type::RawPointer(ref inner) if **inner == Type::Arena)
                    {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message:
                                "Semantic Error: VectorNew argument must be an Arena allocator"
                                    .to_string(),
                            span: None,
                        });
                    }
                    let brand_name = expression_to_string(&arguments[0]);
                    return Ok(Type::Struct("Vector_Any".to_string(), Some(brand_name)));
                }

                if func_path == "os.HashMapNew"
                    || func_path == "std.HashMapNew"
                    || func_path == "os_HashMapNew"
                    || func_path == "std_HashMapNew"
                {
                    if arguments.len() != 1 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: HashMapNew expects exactly 1 argument"
                                .to_string(),
                            span: None,
                        });
                    }
                    let arg_type = self.check_expression(&arguments[0])?;
                    if arg_type != Type::Arena
                        && !matches!(arg_type, Type::RawPointer(ref inner) if **inner == Type::Arena)
                    {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message:
                                "Semantic Error: HashMapNew argument must be an Arena allocator"
                                    .to_string(),
                            span: None,
                        });
                    }
                    let brand_name = expression_to_string(&arguments[0]);
                    return Ok(Type::Struct("HashMap_Any".to_string(), Some(brand_name)));
                }

                if func_path == "os.PoolNew"
                    || func_path == "std.PoolNew"
                    || func_path == "os_PoolNew"
                    || func_path == "std_PoolNew"
                {
                    if arguments.len() != 1 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "PoolNew expects exactly 1 argument".to_string(),
                            span: None,
                        });
                    }
                    let arg_type = self.check_expression(&arguments[0])?;
                    if arg_type != Type::Arena
                        && !matches!(arg_type, Type::RawPointer(ref inner) if **inner == Type::Arena)
                    {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: "Semantic Error: PoolNew argument must be an Arena allocator"
                                .to_string(),
                            span: None,
                        });
                    }
                    let brand_name = expression_to_string(&arguments[0]);
                    return Ok(Type::Struct("Pool_Any".to_string(), Some(brand_name)));
                }

                if func_path == "std.RcNew" || func_path == "std_RcNew" {
                    if arguments.len() != 2 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "RcNew expects exactly 2 arguments (pool, val)".to_string(),
                            span: None,
                        });
                    }
                    let pool_type = self.check_expression(&arguments[0])?;
                    let val_type = self.check_expression(&arguments[1])?;

                    let mut opt_ctx_name = None;
                    if let Type::RawPointer(pool_inner) = &pool_type {
                        match &**pool_inner {
                            Type::Struct(struct_name, Some(ctx_name))
                                if (struct_name.starts_with("Pool_")
                                    || struct_name.starts_with("std_Pool_")) =>
                            {
                                opt_ctx_name = Some(ctx_name.clone());
                            }
                            Type::Generic(pool_name, pool_args) => {
                                if (pool_name == "Pool" || pool_name == "std.Pool")
                                    && pool_args.len() == 2
                                    && let Type::Struct(ctx_name, _) = &pool_args[1]
                                {
                                    opt_ctx_name = Some(ctx_name.clone());
                                }
                            }
                            _ => {}
                        }
                    }

                    if let Some(ctx_name) = opt_ctx_name {
                        let concrete_rc =
                            format!("std_Rc_{}_{}", self.get_type_ident(&val_type), ctx_name);
                        return Ok(Type::Struct(concrete_rc, Some(ctx_name)));
                    }

                    return Err(TypeError {
                        kind: TypeErrorKind::TypeMismatch,
                        message: format!(
                            "Semantic Error: Invalid pool argument in RcNew: {:?}",
                            pool_type
                        ),
                        span: None,
                    });
                }

                if func_path == "std.GraphNew" || func_path == "std_GraphNew" {
                    if arguments.len() != 1 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "GraphNew expects exactly 1 argument (ctx)".to_string(),
                            span: None,
                        });
                    }
                    let arg_type = self.check_expression(&arguments[0])?;
                    if arg_type != Type::Arena
                        && !matches!(arg_type, Type::RawPointer(ref inner) if **inner == Type::Arena)
                    {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: "Semantic Error: GraphNew argument must be an Arena allocator"
                                .to_string(),
                            span: None,
                        });
                    }
                    let brand_name = expression_to_string(&arguments[0]);
                    return Ok(Type::Struct("std_Graph_Any".to_string(), Some(brand_name)));
                }

                if func_path == "std.Spawn" || func_path == "std_Spawn" {
                    if arguments.len() != 2 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message:
                                "Semantic Error: std.Spawn expects exactly 2 arguments (func, arg)"
                                    .to_string(),
                            span: None,
                        });
                    }

                    let func_name = expression_to_string(&arguments[0]);
                    let resolved_func_name = self
                        .resolve_namespaced_ident(&func_name)
                        .unwrap_or(func_name.clone());
                    self.resolved_names
                        .insert(arguments[0].span(), resolved_func_name.clone());

                    if let Some(sig) = self.function_registry.get(&resolved_func_name).cloned() {
                        if sig.params.len() != 1 {
                            return Err(TypeError {
                                kind: TypeErrorKind::ArgumentMismatch,
                                message: format!(
                                    "Semantic Error: Spawned function '{}' must accept exactly 1 parameter, but accepts {}",
                                    func_name,
                                    sig.params.len()
                                ),
                                span: Some(arguments[0].span()),
                            });
                        }

                        let arg_type = self.check_expression(&arguments[1])?;
                        let resolved_arg = self.resolve_type(&arg_type)?;

                        // Handoff isolation check for branded contexts
                        if let Type::Struct(ref name, Some(ref brand)) = resolved_arg
                            && (name.starts_with("std_ThreadLocalContext")
                                || name.starts_with("ThreadLocalContext"))
                            && let Some(ref local_vars) = self.current_function_local_vars
                        {
                            let arg_origins = self.get_expression_origins(&arguments[1]);
                            for origin in &arg_origins {
                                if local_vars.contains(origin) && origin != brand {
                                    return Err(TypeError {
                                        kind: TypeErrorKind::BrandLifetimeViolation,
                                        message: format!(
                                            "Semantic Error: Thread-safety violation. Branded context has origin tracing back to thread-local stack variable '{}', preventing safe handoff across thread-spawning boundaries",
                                            origin
                                        ),
                                        span: Some(arguments[1].span()),
                                    });
                                }
                            }
                        }

                        let is_tl_context = if let Type::Struct(ref n, _) = resolved_arg {
                            n.starts_with("std_ThreadLocalContext")
                                || n.starts_with("ThreadLocalContext")
                        } else {
                            false
                        };

                        let match_ok = if is_tl_context {
                            types_match(&sig.params[0], &resolved_arg)
                        } else {
                            self.types_match_modulo_brand(&sig.params[0], &resolved_arg)
                        };

                        if !match_ok {
                            return Err(TypeError {
                                kind: TypeErrorKind::TypeMismatch,
                                message: format!(
                                    "Semantic Error: Thread spawn argument type mismatch. Expected {:?} but got {:?}",
                                    sig.params[0], resolved_arg
                                ),
                                span: Some(arguments[1].span()),
                            });
                        }

                        return Ok(Type::Void);
                    } else {
                        return Err(TypeError {
                            kind: TypeErrorKind::UndefinedFunction,
                            message: format!(
                                "Semantic Error: Undefined function '{}' inside std.Spawn",
                                func_name
                            ),
                            span: Some(arguments[0].span()),
                        });
                    }
                }

                // os.ReadFile
                if func_path == "os.ReadFile" || func_path == "os_ReadFile" {
                    if arguments.len() != 2 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: os.ReadFile expects exactly 2 arguments (allocator, path)".to_string(),
                            span: None,
                        });
                    }
                    let alloc_type = self.check_expression(&arguments[0])?;
                    if alloc_type != Type::Arena
                        && !matches!(alloc_type, Type::RawPointer(ref inner) if **inner == Type::Arena)
                    {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: "Semantic Error: os.ReadFile first argument must be an Arena allocator".to_string(),
                            span: None,
                        });
                    }
                    let path_type = self.check_expression(&arguments[1])?;
                    if path_type != Type::Str {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: format!(
                                "Semantic Error: os.ReadFile path argument must be Str, but got {:?}",
                                path_type
                            ),
                            span: None,
                        });
                    }
                    return Ok(Type::Str);
                }

                if func_path == "os.OpenDir" || func_path == "os_OpenDir" {
                    if arguments.len() != 2 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: os.OpenDir expects exactly 2 arguments (allocator, path)".to_string(),
                            span: None,
                        });
                    }
                    let alloc_type = self.check_expression(&arguments[0])?;
                    if alloc_type != Type::Arena
                        && !matches!(alloc_type, Type::RawPointer(ref inner) if **inner == Type::Arena)
                    {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: "Semantic Error: os.OpenDir first argument must be an Arena allocator".to_string(),
                            span: None,
                        });
                    }
                    let path_type = self.check_expression(&arguments[1])?;
                    if path_type != Type::Str {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: format!(
                                "Semantic Error: os.OpenDir path argument must be Str, but got {:?}",
                                path_type
                            ),
                            span: None,
                        });
                    }
                    let brand_name = expression_to_string(&arguments[0]);

                    let concrete_dir_name = format!("os_Dir_{}", brand_name);
                    let lookup_name = format!("LookupResult_{}", concrete_dir_name);

                    let _ =
                        self.monomorphize("os_Dir", &[Type::Struct(brand_name.clone(), None)])?;

                    if !self.struct_registry.contains_key(&lookup_name) {
                        let mut fields = HashMap::new();
                        fields.insert("Ok".to_string(), Type::Int);
                        fields.insert(
                            "Val".to_string(),
                            Type::Struct(concrete_dir_name, Some(brand_name.clone())),
                        );
                        self.struct_registry.insert(
                            lookup_name.clone(),
                            StructLayout {
                                brand: Some(brand_name.clone()),
                                fields,
                            },
                        );
                    }

                    return Ok(Type::Struct(lookup_name, None));
                }

                if func_path == "os.ReadDir" || func_path == "os_ReadDir" {
                    if arguments.len() != 2 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: os.ReadDir expects exactly 2 arguments (allocator, directory_handle)".to_string(),
                            span: None,
                        });
                    }
                    let alloc_type = self.check_expression(&arguments[0])?;
                    if alloc_type != Type::Arena
                        && !matches!(alloc_type, Type::RawPointer(ref inner) if **inner == Type::Arena)
                    {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: "Semantic Error: os.ReadDir first argument must be an Arena allocator".to_string(),
                            span: None,
                        });
                    }
                    let dir_type = self.check_expression(&arguments[1])?;
                    let brand_name = expression_to_string(&arguments[0]);

                    let expected_dir_type =
                        Type::Struct(format!("os_Dir_{}", brand_name), Some(brand_name.clone()));
                    if !types_match(&expected_dir_type, &dir_type) {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: format!(
                                "Semantic Error: os_ReadDir directory handle brand mismatch. Expected {:?} but got {:?}",
                                expected_dir_type, dir_type
                            ),
                            span: None,
                        });
                    }

                    let _ = self
                        .monomorphize("os_DirEntry", &[Type::Struct(brand_name.clone(), None)])?;

                    let concrete_entry_name = format!("os_DirEntry_{}", brand_name);
                    let lookup_name = format!("LookupResult_{}", concrete_entry_name);

                    if !self.struct_registry.contains_key(&lookup_name) {
                        let mut fields = HashMap::new();
                        fields.insert("Ok".to_string(), Type::Int);
                        fields.insert(
                            "Val".to_string(),
                            Type::Struct(concrete_entry_name, Some(brand_name.clone())),
                        );
                        self.struct_registry.insert(
                            lookup_name.clone(),
                            StructLayout {
                                brand: Some(brand_name.clone()),
                                fields,
                            },
                        );
                    }

                    return Ok(Type::Struct(lookup_name, None));
                }

                if func_path == "os.CloseDir" || func_path == "os_CloseDir" {
                    if arguments.len() != 1 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: os.CloseDir expects exactly 1 argument (the directory handle)".to_string(),
                            span: None,
                        });
                    }
                    let arg_type = self.check_expression(&arguments[0])?;
                    if let Type::Struct(name, _) = &arg_type
                        && name.starts_with("os_Dir_")
                    {
                        let arg_name = expression_to_string(&arguments[0]);
                        self.open_directories.remove(&arg_name);
                        return Ok(Type::Void);
                    }
                    return Err(TypeError {
                        kind: TypeErrorKind::TypeMismatch,
                        message: format!(
                            "Semantic Error: os.CloseDir expects an os.Dir handle, but got {:?}",
                            arg_type
                        ),
                        span: None,
                    });
                }

                if func_path == "os.WriteFile" || func_path == "os_WriteFile" {
                    if arguments.len() != 2 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: os.WriteFile expects exactly 2 arguments (path, contents)".to_string(),
                            span: None,
                        });
                    }
                    let path_type = self.check_expression(&arguments[0])?;
                    if path_type != Type::Str {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: format!(
                                "Semantic Error: os.WriteFile path argument must be Str, but got {:?}",
                                path_type
                            ),
                            span: None,
                        });
                    }
                    let contents_type = self.check_expression(&arguments[1])?;
                    if contents_type != Type::Str {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: format!(
                                "Semantic Error: os.WriteFile contents argument must be Str, but got {:?}",
                                contents_type
                            ),
                            span: None,
                        });
                    }
                    return Ok(Type::Int);
                }

                if let Some(sig) = self.function_registry.get(&func_path).cloned() {
                    self.resolved_names
                        .insert(function.span(), func_path.clone());

                    // Evaluate arguments first for complete visibility and rich logging
                    let mut evaluated_args = Vec::new();
                    for arg in arguments {
                        let arg_type = self.check_expression(arg)?;
                        let resolved_arg = self.resolve_type(&arg_type)?;
                        evaluated_args.push((expression_to_string(arg), resolved_arg));
                    }

                    tracing::debug!(
                        "👁️ Call-Site Verification: Raw Function: '{}', Resolved: '{}', Expected Params Count: {}, Expected Params: {:?}, Actual Args: {:?}",
                        raw_func_path,
                        func_path,
                        sig.params.len(),
                        sig.params,
                        evaluated_args
                    );

                    if sig.params.len() != arguments.len() {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: format!(
                                "Semantic Error: Function '{}' expects {} arguments but got {}",
                                func_path,
                                sig.params.len(),
                                arguments.len()
                            ),
                            span: None,
                        });
                    }

                    let mut brand_map = HashMap::new();
                    let func_prefix = if let Some(pos) = func_path.rfind("__") {
                        &func_path[..pos + 2]
                    } else {
                        ""
                    };
                    for (i, (param_type, arg)) in
                        sig.params.iter().zip(arguments.iter()).enumerate()
                    {
                        let is_arena_ptr = if let Type::RawPointer(inner) = param_type {
                            **inner == Type::Arena
                        } else {
                            false
                        };
                        if *param_type == Type::Arena || is_arena_ptr {
                            let formal_name = &sig.param_names[i];
                            let actual_name = expression_to_string(arg);
                            brand_map.insert(formal_name.clone(), actual_name.clone());
                            
                            if !func_prefix.is_empty() {
                                let namespaced_formal = format!("{}{}", func_prefix, formal_name);
                                let namespaced_actual = if self.current_prefix.is_empty() {
                                    actual_name.clone()
                                } else {
                                    format!("{}{}", self.current_prefix, actual_name)
                                };
                                brand_map.insert(namespaced_formal, namespaced_actual);
                            }
                        }
                    }

                    for (i, (_arg_str, resolved_arg)) in evaluated_args.iter().enumerate() {
                        let substituted_expected =
                            self.substitute_brand_names(&sig.params[i], &brand_map);

                        if !types_match(&substituted_expected, resolved_arg) {
                            return Err(TypeError {
                                kind: TypeErrorKind::TypeMismatch,
                                message: format!(
                                    "Semantic Error: Argument type mismatch for function '{}'. Expected {:?} but got {:?}",
                                    func_path, substituted_expected, resolved_arg
                                ),
                                span: Some(arguments[i].span()), // Tier B: Point directly to offending argument
                            });
                        }
                    }
                    let resolved_return = self.substitute_brand_names(&sig.return_type, &brand_map);
                    let resolved_return = self.resolve_type(&resolved_return)?;
                    return Ok(resolved_return);
                }

                if func_path == "os.Arena.New"
                    || func_path == "os_Arena_New"
                    || func_path == "os_Arena.New"
                {
                    if !arguments.is_empty() {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: os.Arena.New() expects 0 arguments"
                                .to_string(),
                            span: None,
                        });
                    }
                    return Ok(Type::Arena);
                }

                if func_path == "os.MockPayload" || func_path == "os_MockPayload" {
                    if !arguments.is_empty() {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: os.MockPayload() expects 0 arguments"
                                .to_string(),
                            span: None,
                        });
                    }
                    return Ok(Type::Slice(Box::new(Type::Byte)));
                }

                if func_path == "os.ArenaAlloc" || func_path == "os_ArenaAlloc" {
                    // Compile-time resolution of os_ArenaAlloc [3]
                    if arguments.len() != 1 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: os_ArenaAlloc expects exactly 1 argument (the allocator variable)".to_string(),
                            span: None,
                        });
                    }
                    let arg_type = self.check_expression(&arguments[0])?;
                    if arg_type != Type::Arena
                        && !matches!(arg_type, Type::RawPointer(ref inner) if **inner == Type::Arena)
                    {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message:
                                "Semantic Error: ArenaAlloc argument must be an Arena allocator"
                                    .to_string(),
                            span: None,
                        });
                    }
                    let brand_name = expression_to_string(&arguments[0]);
                    return Ok(Type::Index("Any".to_string(), Some(brand_name)));
                }

                if func_path == "os.SetThreadScratch" || func_path == "os_SetThreadScratch" {
                    if arguments.len() != 1 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: os.SetThreadScratch expects exactly 1 argument (the allocator variable)".to_string(),
                            span: Some(expr.span()),
                        });
                    }
                    let arg_type = self.check_expression(&arguments[0])?;
                    if arg_type != Type::Arena
                        && !matches!(arg_type, Type::RawPointer(ref inner) if **inner == Type::Arena)
                    {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: format!(
                                "Semantic Error: os.SetThreadScratch argument must be an Arena allocator, but got {:?}",
                                arg_type
                            ),
                            span: Some(arguments[0].span()),
                        });
                    }
                    return Ok(Type::Void);
                }

                if func_path == "os.GetThreadScratch" || func_path == "os_GetThreadScratch" {
                    if !arguments.is_empty() {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: os.GetThreadScratch expects 0 arguments"
                                .to_string(),
                            span: Some(expr.span()),
                        });
                    }
                    let mut active_arena_name = "ctx".to_string();
                    for (name, ty) in &self.symbol_table {
                        if *ty == Type::Arena
                            || matches!(ty, Type::RawPointer(inner) if **inner == Type::Arena)
                        {
                            active_arena_name = name.clone();
                            break;
                        }
                    }
                    return Ok(Type::Struct(
                        "std_ThreadLocalContext".to_string(),
                        Some(active_arena_name),
                    ));
                }

                if func_path == "os.LogInt" || func_path == "os_LogInt" {
                    if arguments.len() != 1 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: os.LogInt expects exactly 1 argument"
                                .to_string(),
                            span: None,
                        });
                    }
                    let arg_type = self.check_expression(&arguments[0])?;
                    if arg_type != Type::Int
                        && arg_type != Type::Byte
                        && arg_type != Type::Bool
                        && !matches!(arg_type, Type::Index(_, _))
                    {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: format!(
                                "Semantic Error: os.LogInt expects an Int/Byte/Index argument, but got {:?}",
                                arg_type
                            ),
                            span: None,
                        });
                    }
                    return Ok(Type::Void);
                }

                if func_path == "os.LogStr" || func_path == "os_LogStr" {
                    if arguments.len() != 1 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: os.LogStr expects exactly 1 argument"
                                .to_string(),
                            span: None,
                        });
                    }
                    let arg_type = self.check_expression(&arguments[0])?;
                    if arg_type != Type::Str {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: format!(
                                "Semantic Error: os.LogStr expects a Str argument, but got {:?}",
                                arg_type
                            ),
                            span: None,
                        });
                    }
                    return Ok(Type::Void);
                }

                if let Some(pos) = raw_func_path.find('.') {
                    let alias = &raw_func_path[..pos];
                    if self.imports.contains_key(alias) {
                        return Err(TypeError {
                            kind: TypeErrorKind::UndefinedFunction,
                            message: format!(
                                "Semantic Error: Undefined function '{}'",
                                raw_func_path
                            ),
                            span: Some(function.span()),
                        });
                    }
                }

                if !matches!(**function, Expression::Selector { .. }) {
                    return Err(TypeError {
                        kind: TypeErrorKind::UndefinedFunction,
                        message: format!("Semantic Error: Undefined function '{}'", raw_func_path),
                        span: Some(function.span()),
                    });
                }

                if let Expression::Selector { left, right, .. } = &**function {
                    let mut left_type = self.check_expression(left)?;
                    if let Type::RawPointer(inner) = &left_type {
                        left_type = *inner.clone();
                    }
                    let left_str = expression_to_string(left);
                    if let Type::Struct(struct_name, _) = &left_type {
                        if (struct_name.starts_with("Vector_")
                            || struct_name.starts_with("std_Vector_"))
                            && right == "Push"
                        {
                            if arguments.len() != 1 {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "Vector.Push expects exactly 1 argument".to_string(),
                                    span: None,
                                });
                            }
                            let arg_type = self.check_expression(&arguments[0])?;
                            let elem_type =
                                self.get_vector_element_type(struct_name).ok_or_else(|| {
                                    TypeError {
                                        kind: TypeErrorKind::TypeMismatch,
                                        message: "Invalid Vector struct layout".to_string(),
                                        span: None,
                                    }
                                })?;
                            if !types_match(&elem_type, &arg_type) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Argument type mismatch for Vector.Push. Expected {:?} but got {:?}",
                                        elem_type, arg_type
                                    ),
                                    span: None,
                                });
                            }
                            return Ok(Type::Void);
                        }
                        if (struct_name.starts_with("Vector_")
                            || struct_name.starts_with("std_Vector_"))
                            && right == "Pop"
                        {
                            if !arguments.is_empty() {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "Vector.Pop expects exactly 0 arguments".to_string(),
                                    span: None,
                                });
                            }
                            let elem_type =
                                self.get_vector_element_type(struct_name).ok_or_else(|| {
                                    TypeError {
                                        kind: TypeErrorKind::TypeMismatch,
                                        message: "Invalid Vector struct layout".to_string(),
                                        span: None,
                                    }
                                })?;
                            return Ok(elem_type);
                        }
                        if (struct_name.starts_with("Vector_")
                            || struct_name.starts_with("std_Vector_"))
                            && right == "Clear"
                        {
                            if !arguments.is_empty() {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "Vector.Clear expects exactly 0 arguments".to_string(),
                                    span: None,
                                });
                            }
                            return Ok(Type::Void);
                        }
                        if (struct_name.starts_with("Vector_")
                            || struct_name.starts_with("std_Vector_"))
                            && right == "Back"
                        {
                            if !arguments.is_empty() {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "Vector.Back expects exactly 0 arguments".to_string(),
                                    span: None,
                                });
                            }
                            let elem_type =
                                self.get_vector_element_type(struct_name).ok_or_else(|| {
                                    TypeError {
                                        kind: TypeErrorKind::TypeMismatch,
                                        message: "Invalid Vector struct layout".to_string(),
                                        span: None,
                                    }
                                })?;
                            return Ok(Type::RawPointer(Box::new(elem_type)));
                        }
                        if (struct_name.starts_with("HashMap_")
                            || struct_name.starts_with("std_HashMap_"))
                            && right == "Insert"
                        {
                            if arguments.len() != 2 {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "HashMap.Insert expects exactly 2 arguments"
                                        .to_string(),
                                    span: None,
                                });
                            }
                            let k_arg = self.check_expression(&arguments[0])?;
                            let v_arg = self.check_expression(&arguments[1])?;
                            let (k_type, v_type) = self
                                .get_hashmap_key_value_types(struct_name)
                                .ok_or_else(|| TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: "Invalid HashMap struct layout".to_string(),
                                    span: None,
                                })?;
                            if !types_match(&k_type, &k_arg) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Key type mismatch for HashMap.Insert. Expected {:?} but got {:?}",
                                        k_type, k_arg
                                    ),
                                    span: None,
                                });
                            }
                            if !types_match(&v_type, &v_arg) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Value type mismatch for HashMap.Insert. Expected {:?} but got {:?}",
                                        v_type, v_arg
                                    ),
                                    span: None,
                                });
                            }
                            return Ok(Type::Void);
                        }
                        if (struct_name.starts_with("HashMap_")
                            || struct_name.starts_with("std_HashMap_"))
                            && right == "Get"
                        {
                            if arguments.len() != 1 {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "HashMap.Get expects exactly 1 argument".to_string(),
                                    span: None,
                                });
                            }
                            let k_arg = self.check_expression(&arguments[0])?;
                            let (k_type, v_type) = self
                                .get_hashmap_key_value_types(struct_name)
                                .ok_or_else(|| TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: "Invalid HashMap struct layout".to_string(),
                                    span: None,
                                })?;
                            if !types_match(&k_type, &k_arg) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Key type mismatch for HashMap.Get. Expected {:?} but got {:?}",
                                        k_type, k_arg
                                    ),
                                    span: None,
                                });
                            }
                            let lookup_struct_name =
                                format!("LookupResult_{}", self.get_type_ident(&v_type));
                            if !self.struct_registry.contains_key(&lookup_struct_name) {
                                let mut fields = HashMap::new();
                                fields.insert("Ok".to_string(), Type::Int);
                                fields.insert("Val".to_string(), v_type.clone());
                                self.struct_registry.insert(
                                    lookup_struct_name.clone(),
                                    StructLayout {
                                        brand: None,
                                        fields,
                                    },
                                );
                            }
                            return Ok(Type::Struct(lookup_struct_name, None));
                        }
                        if (struct_name.starts_with("HashMap_")
                            || struct_name.starts_with("std_HashMap_"))
                            && right == "Remove"
                        {
                            if arguments.len() != 1 {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "HashMap.Remove expects exactly 1 argument"
                                        .to_string(),
                                    span: None,
                                });
                            }
                            let k_arg = self.check_expression(&arguments[0])?;
                            let (k_type, _) = self
                                .get_hashmap_key_value_types(struct_name)
                                .ok_or_else(|| TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: "Invalid HashMap struct layout".to_string(),
                                    span: None,
                                })?;
                            if !types_match(&k_type, &k_arg) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Key type mismatch for HashMap.Remove. Expected {:?} but got {:?}",
                                        k_type, k_arg
                                    ),
                                    span: None,
                                });
                            }
                            return Ok(Type::Void);
                        }
                        if (struct_name.starts_with("HashMap_")
                            || struct_name.starts_with("std_HashMap_"))
                            && right == "Clear"
                        {
                            if !arguments.is_empty() {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "HashMap.Clear expects exactly 0 arguments"
                                        .to_string(),
                                    span: None,
                                });
                            }
                            return Ok(Type::Void);
                        }
                        if (struct_name.starts_with("HashMap_")
                            || struct_name.starts_with("std_HashMap_"))
                            && right == "Keys"
                        {
                            if arguments.len() != 1 {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "HashMap.Keys expects exactly 1 argument (the allocator/brand)".to_string(),
                                    span: None,
                                });
                            }
                            let arg_type = self.check_expression(&arguments[0])?;
                            if arg_type != Type::Arena
                                && !matches!(arg_type, Type::RawPointer(ref inner) if **inner == Type::Arena)
                            {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: "HashMap.Keys argument must be an Arena allocator"
                                        .to_string(),
                                    span: None,
                                });
                            }
                            let (k_type, _) = self
                                .get_hashmap_key_value_types(struct_name)
                                .ok_or_else(|| TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: "Invalid HashMap struct layout".to_string(),
                                    span: None,
                                })?;
                            let brand_name = expression_to_string(&arguments[0]);
                            return Ok(Type::Generic(
                                "std.Vector".to_string(),
                                vec![k_type, Type::Struct(brand_name, None)],
                            ));
                        }
                        if (struct_name.starts_with("Pool_")
                            || struct_name.starts_with("std_Pool_"))
                            && right == "Alloc"
                        {
                            if arguments.len() != 1 {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "Pool.Alloc expects exactly 1 argument".to_string(),
                                    span: None,
                                });
                            }
                            let arg_type = self.check_expression(&arguments[0])?;
                            let elem_type =
                                self.get_pool_element_type(struct_name).ok_or_else(|| {
                                    TypeError {
                                        kind: TypeErrorKind::TypeMismatch,
                                        message: "Invalid Pool struct layout".to_string(),
                                        span: None,
                                    }
                                })?;
                            if !types_match(&elem_type, &arg_type) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Argument type mismatch for Pool.Alloc. Expected {:?} but got {:?}",
                                        elem_type, arg_type
                                    ),
                                    span: None,
                                });
                            }
                            let brand_name = match &left_type {
                                Type::Struct(_, Some(b)) => Some(b.clone()),
                                _ => None,
                            };
                            let elem_struct_name = match &elem_type {
                                Type::Struct(n, _) => n.clone(),
                                _ => "SessionNode".to_string(),
                            };
                            return Ok(Type::Index(elem_struct_name, brand_name));
                        }
                        if (struct_name.starts_with("Pool_")
                            || struct_name.starts_with("std_Pool_"))
                            && right == "Free"
                        {
                            if arguments.len() != 1 {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "Pool.Free expects exactly 1 argument".to_string(),
                                    span: None,
                                });
                            }
                            let arg_type = self.check_expression(&arguments[0])?;
                            let elem_type =
                                self.get_pool_element_type(struct_name).ok_or_else(|| {
                                    TypeError {
                                        kind: TypeErrorKind::TypeMismatch,
                                        message: "Invalid Pool struct layout".to_string(),
                                        span: None,
                                    }
                                })?;
                            let brand_name = match &left_type {
                                Type::Struct(_, b) => b.clone(),
                                _ => None,
                            };
                            let elem_struct_name = match &elem_type {
                                Type::Struct(n, _) => n.clone(),
                                _ => "SessionNode".to_string(),
                            };
                            let expected_index_type = Type::Index(elem_struct_name, brand_name);
                            if !types_match(&expected_index_type, &arg_type) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Argument type mismatch for Pool.Free. Expected {:?} but got {:?}",
                                        expected_index_type, arg_type
                                    ),
                                    span: None,
                                });
                            }
                            return Ok(Type::Void);
                        }

                        let is_rc =
                            struct_name.starts_with("Rc_") || struct_name.starts_with("std_Rc_");
                        let is_graph = struct_name.starts_with("Graph_")
                            || struct_name.starts_with("std_Graph_");
                        let is_mutex = struct_name.starts_with("Mutex_")
                            || struct_name.starts_with("std_Mutex_");
                        let is_channel = struct_name.starts_with("Channel_")
                            || struct_name.starts_with("std_Channel_");
                        let is_gen_arena = struct_name.starts_with("std_GenerationalArena_")
                            || struct_name.starts_with("GenerationalArena_");

                        if is_gen_arena
                            && (right == "Step"
                                || right == "step"
                                || right == "Swap"
                                || right == "swap")
                        {
                            if !arguments.is_empty() {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: format!(
                                        "GenerationalArena.{} expects exactly 0 arguments",
                                        right
                                    ),
                                    span: None,
                                });
                            }
                            return Ok(Type::Void);
                        }

                        if is_mutex && right == "Lock" {
                            if !arguments.is_empty() {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "Mutex.Lock expects exactly 0 arguments".to_string(),
                                    span: None,
                                });
                            }
                            if let Some(layout) = self.struct_registry.get(struct_name)
                                && let Some(t_type) = layout.fields.get("value")
                            {
                                return Ok(Type::RawPointer(Box::new(t_type.clone())));
                            }
                            return Err(TypeError {
                                kind: TypeErrorKind::TypeMismatch,
                                message: format!(
                                    "Mutex.Lock: cannot find value type for Mutex struct {}",
                                    struct_name
                                ),
                                span: None,
                            });
                        }

                        if is_mutex && right == "Unlock" {
                            if !arguments.is_empty() {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "Mutex.Unlock expects exactly 0 arguments".to_string(),
                                    span: None,
                                });
                            }
                            return Ok(Type::Void);
                        }

                        if is_channel && right == "Send" {
                            if arguments.len() != 1 {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "Channel.Send expects exactly 1 argument".to_string(),
                                    span: None,
                                });
                            }
                            let arg_type = self.check_expression(&arguments[0])?;
                            let elem_type =
                                self.get_channel_element_type(struct_name).ok_or_else(|| {
                                    TypeError {
                                        kind: TypeErrorKind::TypeMismatch,
                                        message: "Invalid Channel struct layout".to_string(),
                                        span: None,
                                    }
                                })?;
                            if !types_match(&elem_type, &arg_type) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Argument type mismatch for Channel.Send. Expected {:?} but got {:?}",
                                        elem_type, arg_type
                                    ),
                                    span: None,
                                });
                            }

                            if self.is_linear(&elem_type)
                                && !matches!(arguments[0], Expression::Move(_, _))
                            {
                                return Err(TypeError {
                                    kind: TypeErrorKind::BrandLifetimeViolation,
                                    message: format!(
                                        "Semantic Error: Channel.Send for linear type {:?} must consume ownership using the 'move' operator",
                                        elem_type
                                    ),
                                    span: Some(arguments[0].span()),
                                });
                            }

                            return Ok(Type::Void);
                        }

                        if is_channel && right == "Recv" {
                            if !arguments.is_empty() {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "Channel.Recv expects exactly 0 arguments".to_string(),
                                    span: None,
                                });
                            }
                            let elem_type =
                                self.get_channel_element_type(struct_name).ok_or_else(|| {
                                    TypeError {
                                        kind: TypeErrorKind::TypeMismatch,
                                        message: "Invalid Channel struct layout".to_string(),
                                        span: None,
                                    }
                                })?;
                            return Ok(elem_type);
                        }

                        if is_rc && right == "Clone" {
                            if !arguments.is_empty() {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "Rc.Clone expects exactly 0 arguments".to_string(),
                                    span: None,
                                });
                            }
                            return Ok(left_type.clone());
                        }

                        if is_rc && right == "Release" {
                            if !arguments.is_empty() {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "Rc.Release expects exactly 0 arguments".to_string(),
                                    span: None,
                                });
                            }
                            return Ok(Type::Void);
                        }

                        if is_rc && right == "Get" {
                            if !arguments.is_empty() {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "Rc.Get expects exactly 0 arguments".to_string(),
                                    span: None,
                                });
                            }
                            if let Some(layout) = self.struct_registry.get(struct_name)
                                && let Some(Type::Index(rcnode_name, _)) =
                                    layout.fields.get("node_index")
                                && let Some(rcnode_layout) = self.struct_registry.get(rcnode_name)
                                && let Some(t_type) = rcnode_layout.fields.get("value")
                            {
                                return Ok(Type::RawPointer(Box::new(t_type.clone())));
                            }
                            return Err(TypeError {
                                kind: TypeErrorKind::TypeMismatch,
                                message: format!(
                                    "Rc.Get: cannot find value type for Rc struct {}",
                                    struct_name
                                ),
                                span: None,
                            });
                        }

                        if is_graph && right == "AddNode" {
                            if arguments.len() != 1 {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "Graph.AddNode expects exactly 1 argument (value)"
                                        .to_string(),
                                    span: None,
                                });
                            }
                            let arg_type = self.check_expression(&arguments[0])?;

                            let mut t_type = None;
                            if let Some(layout) = self.struct_registry.get(struct_name)
                                && let Some(Type::Struct(pool_name, _)) = layout.fields.get("nodes")
                                && let Some(pool_layout) = self.struct_registry.get(pool_name)
                                && let Some(Type::RawPointer(node_ptr)) =
                                    pool_layout.fields.get("data")
                                && let Type::Struct(gnode_name, _) = &**node_ptr
                                && let Some(gnode_layout) = self.struct_registry.get(gnode_name)
                                && let Some(val_type) = gnode_layout.fields.get("value")
                            {
                                t_type = Some(val_type.clone());
                            }

                            if let Some(expected_t) = t_type
                                && !types_match(&expected_t, &arg_type)
                            {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Semantic Error: Graph.AddNode value type mismatch. Expected {:?} but got {:?}",
                                        expected_t, arg_type
                                    ),
                                    span: None,
                                });
                            }
                            return Ok(Type::Int);
                        }

                        if is_graph && right == "AddEdge" {
                            if arguments.len() != 2 {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "Graph.AddEdge expects exactly 2 arguments (from, to)"
                                        .to_string(),
                                    span: None,
                                });
                            }
                            let from_type = self.check_expression(&arguments[0])?;
                            let to_type = self.check_expression(&arguments[1])?;

                            let graph_brand = match &left_type {
                                Type::Struct(_, b) => b.clone(),
                                _ => None,
                            };

                            if let Type::Index(_, Some(from_brand)) = &from_type {
                                if Some(from_brand) != graph_brand.as_ref() {
                                    return Err(TypeError {
                                        kind: TypeErrorKind::BrandLifetimeViolation,
                                        message: format!(
                                            "Semantic Error: Brand violation in Graph.AddEdge. Node 'from' index brand '{}' does not match graph brand '{:?}'",
                                            from_brand, graph_brand
                                        ),
                                        span: Some(arguments[0].span()),
                                    });
                                }
                            } else if from_type != Type::Int && from_type != Type::Byte {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: "Graph.AddEdge 'from' argument must be an Int, Byte or branded Index".to_string(),
                                    span: Some(arguments[0].span()),
                                });
                            }

                            if let Type::Index(_, Some(to_brand)) = &to_type {
                                if Some(to_brand) != graph_brand.as_ref() {
                                    return Err(TypeError {
                                        kind: TypeErrorKind::BrandLifetimeViolation,
                                        message: format!(
                                            "Semantic Error: Brand violation in Graph.AddEdge. Node 'to' index brand '{}' does not match graph brand '{:?}'",
                                            to_brand, graph_brand
                                        ),
                                        span: Some(arguments[1].span()),
                                    });
                                }
                            } else if to_type != Type::Int && to_type != Type::Byte {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: "Graph.AddEdge 'to' argument must be an Int, Byte or branded Index".to_string(),
                                    span: Some(arguments[1].span()),
                                });
                            }
                            return Ok(Type::Void);
                        }

                        if is_graph && right == "GetNode" {
                            if arguments.len() != 1 {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "Graph.GetNode expects exactly 1 argument (index)"
                                        .to_string(),
                                    span: None,
                                });
                            }
                            let index_type = self.check_expression(&arguments[0])?;

                            let graph_brand = match &left_type {
                                Type::Struct(_, b) => b.clone(),
                                _ => None,
                            };

                            if let Type::Index(_, Some(index_brand)) = &index_type {
                                if Some(index_brand) != graph_brand.as_ref() {
                                    return Err(TypeError {
                                        kind: TypeErrorKind::BrandLifetimeViolation,
                                        message: format!(
                                            "Semantic Error: Brand violation in Graph.GetNode. Index brand '{}' does not match graph brand '{:?}'",
                                            index_brand, graph_brand
                                        ),
                                        span: None,
                                    });
                                }
                            } else if index_type != Type::Int && index_type != Type::Byte {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message:
                                        "Graph.GetNode index must be an Int, Byte or branded Index"
                                            .to_string(),
                                    span: None,
                                });
                            }

                            let mut t_type = None;
                            if let Some(layout) = self.struct_registry.get(struct_name)
                                && let Some(Type::Struct(pool_name, _)) = layout.fields.get("nodes")
                                && let Some(pool_layout) = self.struct_registry.get(pool_name)
                                && let Some(Type::RawPointer(node_ptr)) =
                                    pool_layout.fields.get("data")
                                && let Type::Struct(gnode_name, _) = &**node_ptr
                                && let Some(gnode_layout) = self.struct_registry.get(gnode_name)
                                && let Some(val_type) = gnode_layout.fields.get("value")
                            {
                                t_type = Some(val_type.clone());
                            }

                            if let Some(expected_t) = t_type {
                                return Ok(Type::RawPointer(Box::new(expected_t)));
                            }
                            return Err(TypeError {
                                kind: TypeErrorKind::TypeMismatch,
                                message: format!(
                                    "Graph.GetNode: cannot find value type for Graph struct {}",
                                    struct_name
                                ),
                                span: None,
                            });
                        }
                    }
                    if left_type == Type::Arena && right == "Free" {
                        if !arguments.is_empty() {
                            return Err(TypeError {
                                kind: TypeErrorKind::ArgumentMismatch,
                                message: "Arena.Free() expects 0 arguments".to_string(),
                                span: None,
                            });
                        }

                        let mut to_invalidate = Vec::new();
                        for (v, v_type) in &self.symbol_table {
                            if self.get_type_brand(v_type) == Some(left_str.clone()) {
                                to_invalidate.push(v.clone());
                            }
                        }
                        for v in to_invalidate {
                            self.moved_vars.insert(v.clone());
                            self.open_directories.remove(&v);
                        }

                        return Ok(Type::Void);
                    }
                }

                Err(TypeError {
                    kind: TypeErrorKind::UnresolvedSelector,
                    message: "Semantic Error: Unresolved namespace selector".to_string(),
                    span: None,
                })
            }
            Expression::Empty(target_type, span) => {
                let resolved = self.resolve_type(target_type)?;
                let resolved = self.resolve_type_namespacing(&resolved)?;
                self.resolved_types.insert(*span, resolved.clone());
                Ok(resolved)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::super::TypeChecker;
    use crate::lexer::Lexer;
    use crate::parser::Parser;

    #[test]
    fn test_type_db_serialization() {
        let source = "
            type MyStruct struct {
                field_b: int,
                field_a: bool
            }
            func main() {
                mut x: int := 10;
            }
        ";
        let lexer = Lexer::new(source);
        let mut parser = Parser::new(lexer);
        let program = parser.parse_program();
        assert_eq!(parser.errors.len(), 0);

        let mut checker = TypeChecker::new();
        let res = checker.check_program(&program);
        assert!(res.is_ok());

        let serialized = checker.serialize();
        assert!(serialized.contains("MyStruct:\n    field_a : Bool\n    field_b : Int"));
        assert!(serialized.contains("x : Int"));
        assert!(serialized.contains("main() -> Void"));
    }
}
