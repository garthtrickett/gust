use super::TypeChecker;
use super::types::{
    StructLayout, Type, TypeError, TypeErrorKind, expression_to_string, types_match,
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

fn is_ephemeral_view(t: &Type) -> bool {
    match t {
        Type::Str | Type::Slice(_) | Type::ByteSlice | Type::RawPointer(_) => true,
        Type::Struct(name, _) => {
            name.starts_with("CastResult_") || name.starts_with("LookupResult_")
        }
        _ => false,
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
            "std.str_slice".to_string(),
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
    }

    pub fn check_program(&mut self, program: &Program) -> Result<(), TypeError> { 
        self.current_prefix = "".to_string();
        self.check_module(program, "")
    }

    pub fn check_module(&mut self, program: &Program, prefix: &str) -> Result<(), TypeError> { 
        self.current_prefix = prefix.to_string();
        self.symbol_table.clear();
        self.variable_origins.clear();
        self.moved_vars.clear();
        self.checked_results.clear();

        // 1. Pre-register std library namespaces
        self.imports.insert("os".to_string(), "os_".to_string());
        self.imports.insert("std".to_string(), "std_".to_string());
        self.pre_register_std_functions();

        // Pre-pass: Dynamically register structs, templates, enums, and functions [3]
        for stmt in &program.statements { 
            if let Statement::Import { path, alias, .. } = stmt { 
                let stem = get_file_stem(path);
                let pfx = format!("{}__", stem);
                let alias_name = alias.clone().unwrap_or(stem);
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
                        let resolved_field_type = self.resolve_type_namespacing(&resolved_field_type);
                        if matches!(resolved_field_type, Type::Slice(_))
                            || resolved_field_type == Type::ByteSlice
                            || resolved_field_type == Type::Str
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
                generics: _,
                variants,
                span,
                ..
            } = stmt
            {
                let namespaced_name = format!("{}{}", self.current_prefix, name);
                self.resolved_names.insert(*span, namespaced_name.clone());

                // Register the enum in the enum registry
                let variant_names: Vec<String> = variants.iter().map(|v| v.name.clone()).collect();
                self.enum_registry.insert(namespaced_name.clone(), variant_names);

                // Register nested variant structs in struct_registry
                let mut enum_fields = HashMap::new();
                enum_fields.insert("tag".to_string(), Type::Int);

                for variant in variants { 
                    let concrete_variant_struct_name = format!("{}_{}", namespaced_name, variant.name);

                    // Register the variant struct fields in struct_registry
                    let mut variant_fields = HashMap::new();
                    for field in &variant.fields { 
                        let resolved_t = self.resolve_type(&field.field_type)?;
                        let resolved_t = self.resolve_type_namespacing(&resolved_t);
                        if let Type::Struct(ref struct_name, _) = resolved_t
                            && let Some(layout) = self.struct_registry.get(struct_name)
                            && layout.fields.len() > 2
                        { 
                            return Err(TypeError {
                                kind: TypeErrorKind::LargeEnumVariantPayload,
                                message: format!(
                                    "Semantic Error: Variant '{}' contains a large enum variant payload struct '{}' ({} fields). Use Index[{}] or pointer indirection to avoid memory bloat.",
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
                        Ok(self.resolve_type_namespacing(&resolved))
                    })
                    .collect();
                let resolved_return = self.resolve_type(return_type)?;
                let resolved_return = self.resolve_type_namespacing(&resolved_return);
                let param_names = params.iter().map(|p| p.name.clone()).collect();

                self.function_registry.insert(
                    namespaced_name.clone(),
                    super::types::FunctionSignature {
                        param_names,
                        params: resolved_params?,
                        return_type: resolved_return,
                        return_origins: HashSet::new(),
                    },
                );
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
            Statement::Import { path, alias, span: _ } => { 
                let stem = get_file_stem(path);
                let prefix = format!("{}__", stem);
                let alias_name = alias.clone().unwrap_or(stem);
                self.imports.insert(alias_name, prefix);
            }
            Statement::StructDecl { .. } => {}
            Statement::EnumDecl { .. } => {}
            Statement::FunctionDecl {
                name,
                params,
                return_type,
                body,
                ..
            } => {
                let parent_scope = self.symbol_table.clone();
                let parent_origins = self.variable_origins.clone();

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

                // Populate formal return origins on signature for propagation
                if let Some(sig) = self.function_registry.get_mut(name) {
                    sig.return_origins = formal_return_origins;
                }

                // Clean-up and restore parent scopes [3]
                self.symbol_table = parent_scope;
                self.variable_origins = parent_origins;
                self.expected_return_type = old_expected;
                self.current_function_return_origins = old_return_origins;
                self.current_function_inout_params = old_inout_params;
                self.current_function_local_vars = old_local_vars;
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

                    let mut origs = if is_ephemeral_view(&t) {
                        self.get_expression_origins(val_expr)
                    } else {
                        HashSet::new()
                    };
                    // Fallback to itself as a root origin if expression contains no active origins
                    if origs.is_empty() {
                        origs.insert(name.clone());
                    }
                    self.variable_origins.insert(name.clone(), origs);
                    t
                } else {
                    if let Some(explicit_t) = var_type {
                        let mut origs = HashSet::new();
                        origs.insert(name.clone());
                        self.variable_origins.insert(name.clone(), origs);
                        let resolved = self.resolve_type(explicit_t)?;
                        let resolved = self.resolve_type_namespacing(&resolved);
                        resolved
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
                    let resolved_explicit = self.resolve_type_namespacing(&resolved_explicit);
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
                    self.variable_types.insert(name.clone(), val_type);
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
                    let mut origs = if is_ephemeral_view(&left_type) {
                        self.get_expression_origins(value)
                    } else {
                        HashSet::new()
                    };
                    if matches!(left, Expression::Identifier(_, _)) {
                        if origs.is_empty() {
                            origs.insert(root_name.clone());
                        }
                        self.variable_origins.insert(root_name.clone(), origs);
                    } else {
                        if !origs.is_empty() {
                            if let Some(existing) = self.variable_origins.get_mut(&root_name) {
                                existing.extend(origs);
                            } else {
                                self.variable_origins.insert(root_name.clone(), origs);
                            }
                        }
                    }
                    self.moved_vars.remove(&root_name); // Re-initialized!
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
                            for s in &case.body.statements {
                                self.check_statement(s)?;
                            }
                            self.symbol_table = parent_scope;
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

    // Dynamic, recursive Set-Based memory origin extractor
    pub fn get_expression_origins(&self, expr: &Expression) -> HashSet<String> {
        match expr {
            Expression::Identifier(name, _) => {
                if let Some(t) = self.symbol_table.get(name) {
                    // Value-types do not borrow/carry origins
                    if matches!(t, Type::Struct(_, None)) || *t == Type::Int || *t == Type::Byte || *t == Type::Bool {
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
                let func_path = expression_to_string(function);
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
            Ok(t) => Ok(t),
        }
    }

    fn check_expression_internal(&mut self, expr: &Expression) -> Result<Type, TypeError> {
        match expr {
            Expression::Identifier(name, span) => {
                let resolved_name = self.resolve_namespaced_ident(name);
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
                            self.moved_vars.insert(v);
                        }
                    }

                    if self.is_linear(&var_type) {
                        self.moved_vars.insert(name.clone());
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
                let resolved_target = self.resolve_type_namespacing(&resolved_target);
                self.resolved_types.insert(*span, resolved_target.clone());

                if (left_type == Type::Int || left_type == Type::Byte || left_type == Type::Bool)
                    && (resolved_target == Type::Int || resolved_target == Type::Byte || resolved_target == Type::Bool)
                { 
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
                        if brand_name != alloc_name {
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
                let left_type = self.check_expression(left)?;
                let left_str = expression_to_string(left);
                let path = format!("{}.{}", left_str, right);

                if path == "os.Arena" {
                    return Ok(Type::Void);
                }

                if let Type::Struct(struct_name, _brand) = &left_type {
                    if struct_name.starts_with("CastResult_")
                        || struct_name.starts_with("LookupResult_")
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

                            let prefix = if struct_name.starts_with("CastResult_") {
                                "CastResult_"
                            } else {
                                "LookupResult_"
                            };
                            let target_struct = struct_name.trim_start_matches(prefix).to_string();
                            if target_struct == "int" {
                                return Ok(Type::Int);
                            }
                            return Ok(Type::Struct(target_struct, None));
                        }
                    }
                    if let Some(layout) = self.struct_registry.get(struct_name) {
                        if let Some(field_type) = layout.fields.get(right) {
                            let returned_type = self.substitute_brand(field_type, _brand);
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
                for arg in arguments {
                    self.check_expression(arg)?;
                }

                let func_path = expression_to_string(function); // Using expression_to_string to safely resolve namespaces

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

                if func_path == "os.VectorNew" || func_path == "std.VectorNew" {
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

                if func_path == "os.HashMapNew" || func_path == "std.HashMapNew" {
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

                if func_path == "os.PoolNew" || func_path == "std.PoolNew" {
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

                if func_path == "os.ReadFile" {
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

                if func_path == "os.WriteFile" {
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
                            brand_map.insert(formal_name.clone(), actual_name);
                        }
                    }

                    for (i, arg) in arguments.iter().enumerate() {
                        let arg_type = self.check_expression(arg)?;
                        let resolved_arg = self.resolve_type(&arg_type)?;

                        let substituted_expected =
                            self.substitute_brand_names(&sig.params[i], &brand_map);

                        if !types_match(&substituted_expected, &resolved_arg) {
                            return Err(TypeError {
                                kind: TypeErrorKind::TypeMismatch,
                                message: format!(
                                    "Semantic Error: Argument type mismatch for function '{}'. Expected {:?} but got {:?}",
                                    func_path, substituted_expected, resolved_arg
                                ),
                                span: Some(arg.span()), // Tier B: Point directly to offending argument
                            });
                        }
                    }
                    return Ok(sig.return_type);
                }

                if func_path == "os.Arena.New" {
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

                if func_path == "os.MockPayload" {
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

                if func_path == "os.ArenaAlloc" {
                    if arguments.len() != 1 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: os.ArenaAlloc expects exactly 1 argument (the allocator variable)".to_string(),
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

                if func_path == "os.LogInt" {
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

                if func_path == "os.LogStr" {
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

                if let Expression::Selector { left, right, .. } = &**function {
                    let left_type = self.check_expression(left)?;
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
                let resolved = self.resolve_type_namespacing(&resolved);
                self.resolved_types.insert(*span, resolved.clone());
                Ok(resolved)
            }
        }
    }
}
