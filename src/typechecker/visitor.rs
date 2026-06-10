use super::TypeChecker;
use super::types::{
    StructLayout, Type, TypeError, TypeErrorKind, expression_to_string, types_match,
};
use crate::ast::{Expression, Program, Statement};
use std::collections::{HashMap, HashSet};

fn get_root_variable(expr: &Expression) -> Option<String> {
    match expr {
        Expression::Identifier(name) => Some(name.clone()),
        Expression::Selector { left, .. } => get_root_variable(left),
        Expression::IndexAccess { allocator, .. } => get_root_variable(allocator),
        Expression::Dereference(inner) => get_root_variable(inner),
        Expression::AddressOf(inner) => get_root_variable(inner),
        Expression::AsCast { left, .. } => get_root_variable(left),
        Expression::Move(inner) => get_root_variable(inner),
        Expression::Take(inner) => get_root_variable(inner),
        _ => None,
    }
}

fn is_ephemeral_view(t: &Type) -> bool {
    match t {
        Type::Str | Type::Slice(_) | Type::ByteSlice | Type::RawPointer(_) => true,
        Type::Struct(name, _) => name.starts_with("CastResult_") || name.starts_with("LookupResult_"),
        _ => false,
    }
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
            Type::Byte => true,
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
            Expression::Selector { left, right } => {
                if right == "Ok" {
                    return Some(expression_to_string(left));
                }
                None
            }
            Expression::Binary { op, left, right } => {
                if op == "==" {
                    // Case: path.Ok == 1
                    if let Expression::Selector {
                        left: sel_left,
                        right: sel_right,
                    } = &**left
                        && sel_right == "Ok"
                            && let Expression::Integer(1) = &**right {
                                return Some(expression_to_string(sel_left));
                            }
                    // Case: 1 == path.Ok
                    if let Expression::Selector {
                        left: sel_left,
                        right: sel_right,
                    } = &**right
                        && sel_right == "Ok"
                            && let Expression::Integer(1) = &**left {
                                return Some(expression_to_string(sel_left));
                            }
                }
                None
            }
            _ => None,
        }
    }

    pub fn check_program(&mut self, program: &Program) -> Result<(), TypeError> {
        // Pre-pass: Dynamically register structs, templates, enums, and functions [3]
        for stmt in &program.statements {
            if let Statement::StructDecl {
                name,
                generics,
                fields,
            } = stmt
            {
                if generics.is_empty() {
                    let mut layout_fields = HashMap::new();
                    for field in fields {
                        let resolved_field_type = self.resolve_type(&field.field_type)?;
                        if matches!(resolved_field_type, Type::Slice(_))
                            || resolved_field_type == Type::ByteSlice
                            || resolved_field_type == Type::Str
                        {
                            return Err(TypeError {
                                kind: TypeErrorKind::BrandLifetimeViolation,
                                message: format!(
                                    "Semantic Error: Unbranded struct '{}' cannot contain ephemeral slice or view field '{}' of type '{:?}'",
                                    name, field.name, resolved_field_type
                                ),
                            });
                        }
                        layout_fields.insert(field.name.clone(), field.field_type.clone());
                    }
                    self.struct_registry.insert(
                        name.clone(),
                        StructLayout {
                            brand: None,
                            fields: layout_fields,
                        },
                    );
                } else {
                    self.struct_templates.insert(
                        name.clone(),
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
            } = stmt
            {
                // Register the enum in the enum registry
                let variant_names: Vec<String> = variants.iter().map(|v| v.name.clone()).collect();
                self.enum_registry.insert(name.clone(), variant_names);

                // Register nested variant structs in struct_registry
                let mut enum_fields = HashMap::new();
                enum_fields.insert("tag".to_string(), Type::Int);

                for variant in variants {
                    let concrete_variant_struct_name = format!("{}_{}", name, variant.name);

                    // Register the variant struct fields in struct_registry
                    let mut variant_fields = HashMap::new();
                    for field in &variant.fields {
                        let resolved_t = self.resolve_type(&field.field_type)?;
                        if let Type::Struct(ref struct_name, _) = resolved_t
                            && let Some(layout) = self.struct_registry.get(struct_name)
                                && layout.fields.len() > 2 {
                                    return Err(TypeError {
                                        kind: TypeErrorKind::LargeEnumVariantPayload,
                                        message: format!(
                                            "Semantic Error: Variant '{}' contains a large enum variant payload struct '{}' ({} fields). Use Index[{}] or pointer indirection to avoid memory bloat.",
                                            variant.name, struct_name, layout.fields.len(), struct_name
                                        ),
                                    });
                                }
                        variant_fields.insert(field.name.clone(), field.field_type.clone());
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
                    name.clone(),
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
                ..
            } = stmt
            {
                let resolved_params: Result<Vec<Type>, TypeError> = params
                    .iter()
                    .map(|p| self.resolve_type(&p.param_type))
                    .collect();
                let resolved_return = self.resolve_type(return_type)?;
                let param_names = params.iter().map(|p| p.name.clone()).collect();

                self.function_registry.insert(
                    name.clone(),
                    super::types::FunctionSignature {
                        param_names,
                        params: resolved_params?,
                        return_type: resolved_return,
                        return_origins: HashSet::new(), // Populated in the actual pass
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

    pub fn check_statement(&mut self, stmt: &Statement) -> Result<(), TypeError> {
        match stmt {
            Statement::StructDecl { .. } => {}
            Statement::EnumDecl { .. } => {}
            Statement::FunctionDecl {
                name,
                params,
                return_type,
                body,
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
            } => {
                let val_type = if let Some(val_expr) = value {
                    let mut t = self.check_expression(val_expr)?;
                    t = self.resolve_type(&t)?;

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
                        self.resolve_type(explicit_t)?
                    } else {
                        return Err(TypeError {
                            kind: TypeErrorKind::UninitializedVariable,
                            message: format!(
                                "Semantic Error: Uninitialized variable '{}' must have an explicit type annotation",
                                name
                            ),
                        });
                    }
                };

                if let Some(explicit_t) = var_type {
                    let resolved_explicit = self.resolve_type(explicit_t)?;
                    if !types_match(&resolved_explicit, &val_type) {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: format!(
                                "Semantic Error: Explicit Type Annotation Mismatch. Declared {:?} but got value {:?}",
                                resolved_explicit, val_type
                            ),
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
            Statement::Assignment { left, value } => {
                let left_type = match left {
                    Expression::Identifier(name) => {
                        if let Some(t) = self.symbol_table.get(name) {
                            Ok(t.clone())
                        } else {
                            Err(TypeError {
                                kind: TypeErrorKind::UndefinedVariable,
                                message: format!("Semantic Error: Undefined variable '{}' in assignment LHS", name),
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
                if let Expression::Identifier(left_name) = left {
                    let mut origs = if is_ephemeral_view(&left_type) {
                        self.get_expression_origins(value)
                    } else {
                        HashSet::new()
                    };
                    // Fallback to itself as a root origin if assignment expression has no origins
                    if origs.is_empty() { 
                        origs.insert(left_name.clone());
                    }
                    self.variable_origins.insert(left_name.clone(), origs);
                    self.moved_vars.remove(left_name); // Re-initialized!
                }
            }
            Statement::While { condition, body } => {
                let cond_type = self.check_expression(condition)?;
                if cond_type != Type::Int {
                    return Err(TypeError {
                        kind: TypeErrorKind::LoopConditionInvalid,
                        message: "Semantic Error: Loop condition must evaluate to an Int (binary comparison)".to_string(),
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
            } => {
                let cond_type = self.check_expression(condition)?;
                if cond_type != Type::Int {
                    return Err(TypeError {
                        kind: TypeErrorKind::IfConditionInvalid,
                        message: "Semantic Error: If condition must evaluate to an Int (binary comparison)".to_string(),
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
            Statement::Match { expression, cases } => {
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
                                });
                            }

                            if matched_variants.contains(&case.variant_name) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Semantic Error: Duplicate match case for variant '{}' of enum '{}'",
                                        case.variant_name, enum_name
                                    ),
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
                        });
                    }
                } else {
                    return Err(TypeError {
                        kind: TypeErrorKind::TypeMismatch,
                        message: format!(
                            "Semantic Error: Match target type '{:?}' is not an enum struct",
                            expr_type
                        ),
                    });
                }
            }
            Statement::UnsafeBlock { body } => {
                let was_unsafe = self.in_unsafe_block;
                self.in_unsafe_block = true;

                let parent_scope = self.symbol_table.clone();
                for s in &body.statements {
                    self.check_statement(s)?;
                }
                self.symbol_table = parent_scope;

                self.in_unsafe_block = was_unsafe;
            }
            Statement::Defer { expr } => {
                self.check_expression(expr)?;
            }
            Statement::Return(maybe_expr) => {
                if let Some(ref inout_params) = self.current_function_inout_params {
                    for inout_p in inout_params {
                        if self.moved_vars.contains(inout_p) {
                            return Err(TypeError {
                                kind: TypeErrorKind::UseOfMovedVariable,
                                message: format!(
                                    "Semantic Error: Inout reference parameter '{}' was moved but never re-initialized before return",
                                    inout_p
                                ),
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
                        && let Some(ref local_vars) = self.current_function_local_vars {
                            for origin in &expr_origins {
                                if local_vars.contains(origin) {
                                    return Err(TypeError {
                                        kind: TypeErrorKind::BrandLifetimeViolation,
                                        message: format!(
                                            "Semantic Error: Escape analysis violation. Returning ephemeral view of type {:?} whose origin traces back to local stack variable '{}'",
                                            t, origin
                                        ),
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
                        });
                    }
                } else {
                    return Err(TypeError {
                        kind: TypeErrorKind::ReturnOutsideFunction,
                        message: "Semantic Error: Return statement used outside function body"
                            .to_string(),
                    });
                }
            }
            Statement::Expression(expr) => {
                self.check_expression(expr)?;
            }
        }
        Ok(())
    }

    // Dynamic, recursive Set-Based memory origin extractor
    pub fn get_expression_origins(&self, expr: &Expression) -> HashSet<String> {
        match expr {
            Expression::Identifier(name) => {
                if let Some(t) = self.symbol_table.get(name) {
                    // Value-types do not borrow/carry origins
                    if matches!(t, Type::Struct(_, None)) || *t == Type::Int || *t == Type::Byte {
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
            Expression::AddressOf(inner) => self.get_expression_origins(inner),
            Expression::Dereference(inner) => self.get_expression_origins(inner),
            Expression::Selector { left, .. } => self.get_expression_origins(left),
            Expression::IndexAccess { allocator, .. } => self.get_expression_origins(allocator),
            Expression::Move(inner) => {
                if let Expression::Identifier(name) = &**inner
                    && let Some(t) = self.symbol_table.get(name)
                    && !self.is_linear(t)
                {
                    return HashSet::new();
                }
                self.get_expression_origins(inner)
            }
            Expression::Take(inner) => {
                if let Expression::Identifier(name) = &**inner
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

    pub fn check_expression(&mut self, expr: &Expression) -> Result<Type, TypeError> {
        match expr {
            Expression::Identifier(name) => {
                if self.moved_vars.contains(name) {
                    return Err(TypeError {
                        kind: TypeErrorKind::UseOfMovedVariable,
                        message: format!("Semantic Error: Use of moved variable '{}'", name),
                    });
                }

                // Union evaluation: Reject reading if ANY of the potential origins are moved/invalid
                if let Some(origins) = self.variable_origins.get(name) {
                    for origin in origins {
                        if self.moved_vars.contains(origin) {
                            return Err(TypeError {
                                kind: TypeErrorKind::VariableOriginInvalidated,
                                message: format!(
                                    "Semantic Error: Variable '{}' cannot be used because its backing origin '{}' has been moved or invalidated",
                                    name, origin
                                ),
                            });
                        }
                    }
                }

                if let Some(t) = self.symbol_table.get(name) {
                    if let Some(brand) = self.get_type_brand(t)
                        && self.moved_vars.contains(&brand)
                    {
                        return Err(TypeError {
                            kind: TypeErrorKind::AllocatorMovedOrFreed,
                            message: format!(
                                "Semantic Error: Variable '{}' cannot be used because its branding allocator '{}' has been moved or freed",
                                name, brand
                            ),
                        });
                    }
                    Ok(t.clone())
                } else {
                    if name == "null" {
                        return Ok(Type::Index("SessionNode".to_string(), None));
                    }
                    Err(TypeError {
                        kind: TypeErrorKind::UndefinedVariable,
                        message: format!("Semantic Error: Undefined variable '{}'", name),
                    })
                }
            }
            Expression::Integer(_) => Ok(Type::Int),
            Expression::String(_) => Ok(Type::Str), // Added for String Views Option 2
            Expression::Move(inner_expr) => {
                if let Expression::Identifier(name) = &**inner_expr {
                    if self.moved_vars.contains(name) {
                        return Err(TypeError {
                            kind: TypeErrorKind::UseOfMovedVariable,
                            message: format!(
                                "Semantic Error: Variable '{}' has already been moved",
                                name
                            ),
                        });
                    }
                    let Some(var_type) = self.symbol_table.get(name).cloned() else {
                        return Err(TypeError {
                            kind: TypeErrorKind::UndefinedVariable,
                            message: format!(
                                "Semantic Error: Cannot move undefined variable '{}'",
                                name
                            ),
                        });
                    };

                    if let Some(origins) = self.variable_origins.get(name) {
                        for origin in origins {
                            if self.moved_vars.contains(origin) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::VariableOriginInvalidated,
                                    message: format!(
                                        "Semantic Error: Variable '{}' cannot be moved because its backing origin '{}' has been moved or invalidated",
                                        name,
                                        origin
                                    ),
                                });
                            } 
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
                    })
                }
            }
            Expression::Take(inner_expr) => {
                let expr_type = self.check_expression(inner_expr)?;
                if expr_type == Type::Int || expr_type == Type::Byte {
                    return Err(TypeError {
                        kind: TypeErrorKind::TakePrimitiveBanned,
                        message: "Semantic Error: The 'take' operator is strictly banned on primitive POD types (like Int)".to_string(),
                    });
                }
                Ok(expr_type)
            }
            Expression::AddressOf(inner) => {
                let inner_type = self.check_expression(inner)?;
                Ok(Type::RawPointer(Box::new(inner_type)))
            }
            Expression::Dereference(inner) => {
                if !self.in_unsafe_block {
                    return Err(TypeError {
                        kind: TypeErrorKind::UnsafeProhibited,
                        message: "Semantic Error: Dereferencing raw pointers is strictly prohibited outside 'unsafe' blocks".to_string(),
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
                    })
                }
            }
            Expression::AsCast {
                left,
                target_type,
                is_reference: _,
            } => {
                let left_type = self.check_expression(left)?;
                let resolved_target = self.resolve_type(target_type)?;

                if let Type::RawPointer(_) = left_type {
                    if !self.in_unsafe_block {
                        return Err(TypeError {
                            kind: TypeErrorKind::UnsafeProhibited,
                            message: "Semantic Error: Casting pointers is strictly prohibited outside 'unsafe' blocks".to_string(),
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
                        });
                }

                if !matches!(left_type, Type::Slice(_)) && left_type != Type::ByteSlice {
                    return Err(TypeError {
                        kind: TypeErrorKind::InvalidCast,
                        message: format!(
                            "Semantic Error: Casting source must be a Slice, but got {:?}",
                            left_type
                        ),
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
                })
            }
            Expression::IndexAccess { allocator, index } => {
                let alloc_type = self.check_expression(allocator)?;
                let index_type = self.check_expression(index)?;

                if let Type::Slice(elem_type) = &alloc_type {
                    if index_type != Type::Int && index_type != Type::Byte {
                        return Err(TypeError {
                            kind: TypeErrorKind::InvalidIndexType,
                            message: "Semantic Error: Slice index must resolve to an Int or Byte"
                                .to_string(),
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
                        });
                    }
                    Ok(Type::Byte)
                } else if let Type::Struct(struct_name, _) = &alloc_type {
                    if struct_name.starts_with("Vector_") {
                        if index_type != Type::Int && index_type != Type::Byte {
                            return Err(TypeError {
                                kind: TypeErrorKind::InvalidIndexType,
                                message: "Vector index must resolve to an Int or Byte".to_string(),
                            });
                        }
                        let elem_type =
                            self.get_vector_element_type(struct_name)
                                .ok_or_else(|| TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: "Invalid Vector struct layout".to_string(),
                                })?;
                        Ok(elem_type)
                    } else if struct_name.starts_with("HashMap_") {
                        let (k_type, v_type) = self
                            .get_hashmap_key_value_types(struct_name)
                            .ok_or_else(|| TypeError {
                                kind: TypeErrorKind::TypeMismatch,
                                message: "Invalid HashMap struct layout".to_string(),
                            })?;
                        if !types_match(&k_type, &index_type) {
                            return Err(TypeError {
                                kind: TypeErrorKind::InvalidIndexType,
                                message: format!(
                                    "HashMap index type mismatch. Expected {:?} but got {:?}",
                                    k_type, index_type
                                ),
                            });
                        }
                        Ok(v_type)
                    } else {
                        Err(TypeError {
                            kind: TypeErrorKind::InvalidIndexTarget,
                            message: format!(
                                "Semantic Error: Subscript indexing is only valid on Arenas, Slices, Vectors, or HashMaps, but got {:?}",
                                alloc_type
                            ),
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
                        })
                    }
                } else {
                    Err(TypeError {
                        kind: TypeErrorKind::InvalidIndexTarget,
                        message: format!(
                            "Semantic Error: Subscript indexing is only valid on Arenas, Slices, Vectors, or HashMaps, but got {:?}",
                            alloc_type
                        ),
                    })
                }
            }
            Expression::Binary { op, left, right } => {
                let left_type = self.check_expression(left)?;
                let right_type = self.check_expression(right)?;

                if op == "==" || op == "!=" {
                    if let Type::Index(_, _) = left_type
                        && let Expression::Identifier(name) = &**right
                        && name == "null"
                    {
                        return Ok(Type::Int);
                    }
                    if let Type::Index(_, _) = right_type
                        && let Expression::Identifier(name) = &**left
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
                    });
                }

                Ok(Type::Int)
            }
            Expression::Selector { left, right } => {
                let left_type = self.check_expression(left)?;
                let left_str = expression_to_string(left);
                let path = format!("{}.{}", left_str, right);

                if path == "os.Arena" {
                    return Ok(Type::Void);
                }

                if let Type::Struct(struct_name, _brand) = &left_type {
                    if struct_name.starts_with("CastResult_") || struct_name.starts_with("LookupResult_") {
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
                                });
                            }

                            let prefix = if struct_name.starts_with("CastResult_") {
                                "CastResult_"
                            } else {
                                "LookupResult_"
                            };
                            let target_struct = 
                                struct_name.trim_start_matches(prefix).to_string();
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
                    });
                }

                Err(TypeError {
                    kind: TypeErrorKind::UnresolvedSelector,
                    message: format!("Semantic Error: Unresolved namespace selector '{}'", path),
                })
            }
            Expression::Call {
                function,
                arguments,
            } => {
                for arg in arguments {
                    self.check_expression(arg)?;
                }

                let func_path = expression_to_string(function);

                if func_path == "len" {
                    if arguments.len() != 1 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: len expects exactly 1 argument".to_string(),
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
                            || struct_name.starts_with("HashMap_"))
                    {
                        return Ok(Type::Int);
                    }
                    return Err(TypeError {
                        kind: TypeErrorKind::ArgumentMismatch,
                        message: format!(
                            "Semantic Error: len expects a Slice, Str, Vector, or HashMap argument, but got {:?}",
                            arg_type
                        ),
                    });
                }

                if func_path == "os.VectorNew" {
                    if arguments.len() != 1 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: os.VectorNew expects exactly 1 argument"
                                .to_string(),
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
                        });
                    }
                    let brand_name = expression_to_string(&arguments[0]);
                    return Ok(Type::Struct("Vector_Any".to_string(), Some(brand_name)));
                }

                if func_path == "os.HashMapNew" {
                    if arguments.len() != 1 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: os.HashMapNew expects exactly 1 argument"
                                .to_string(),
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
                        });
                    }
                    let brand_name = expression_to_string(&arguments[0]);
                    return Ok(Type::Struct("HashMap_Any".to_string(), Some(brand_name)));
                }

                if func_path == "os.ReadFile" {
                    if arguments.len() != 2 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: os.ReadFile expects exactly 2 arguments (allocator, path)".to_string(),
                        });
                    }
                    let alloc_type = self.check_expression(&arguments[0])?;
                    if alloc_type != Type::Arena
                        && !matches!(alloc_type, Type::RawPointer(ref inner) if **inner == Type::Arena)
                    {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: "Semantic Error: os.ReadFile first argument must be an Arena allocator".to_string(),
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
                        });
                    }
                    return Ok(Type::Str);
                }

                if func_path == "os.WriteFile" {
                    if arguments.len() != 2 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: os.WriteFile expects exactly 2 arguments (path, contents)".to_string(),
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
                        });
                    }
                    return Ok(Type::Slice(Box::new(Type::Byte)));
                }

                if func_path == "os.ArenaAlloc" {
                    if arguments.len() != 1 {
                        return Err(TypeError {
                            kind: TypeErrorKind::ArgumentMismatch,
                            message: "Semantic Error: os.ArenaAlloc expects exactly 1 argument (the allocator variable)".to_string(),
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
                        });
                    }
                    let arg_type = self.check_expression(&arguments[0])?;
                    if arg_type != Type::Int && arg_type != Type::Byte {
                        return Err(TypeError {
                            kind: TypeErrorKind::TypeMismatch,
                            message: format!(
                                "Semantic Error: os.LogInt expects an Int/Byte argument, but got {:?}",
                                arg_type
                            ),
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
                        });
                    }
                    return Ok(Type::Void);
                }

                if let Expression::Selector { left, right } = &**function {
                    let left_type = self.check_expression(left)?;
                    if let Type::Struct(struct_name, _) = &left_type {
                        if struct_name.starts_with("Vector_") && right == "Push" {
                            if arguments.len() != 1 {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "Vector.Push expects exactly 1 argument".to_string(),
                                });
                            }
                            let arg_type = self.check_expression(&arguments[0])?;
                            let elem_type =
                                self.get_vector_element_type(struct_name).ok_or_else(|| {
                                    TypeError {
                                        kind: TypeErrorKind::TypeMismatch,
                                        message: "Invalid Vector struct layout".to_string(),
                                    }
                                })?;
                            if !types_match(&elem_type, &arg_type) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Argument type mismatch for Vector.Push. Expected {:?} but got {:?}",
                                        elem_type, arg_type
                                    ),
                                });
                            }
                            return Ok(Type::Void);
                        }
                        if struct_name.starts_with("HashMap_") && right == "Insert" {
                            if arguments.len() != 2 {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "HashMap.Insert expects exactly 2 arguments"
                                        .to_string(),
                                });
                            }
                            let k_arg = self.check_expression(&arguments[0])?;
                            let v_arg = self.check_expression(&arguments[1])?;
                            let (k_type, v_type) = self
                                .get_hashmap_key_value_types(struct_name)
                                .ok_or_else(|| TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: "Invalid HashMap struct layout".to_string(),
                                })?;
                            if !types_match(&k_type, &k_arg) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Key type mismatch for HashMap.Insert. Expected {:?} but got {:?}",
                                        k_type, k_arg
                                    ),
                                });
                            }
                            if !types_match(&v_type, &v_arg) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Value type mismatch for HashMap.Insert. Expected {:?} but got {:?}",
                                        v_type, v_arg
                                    ),
                                });
                            }
                            return Ok(Type::Void);
                        }
                        if struct_name.starts_with("HashMap_") && right == "Get" {
                            if arguments.len() != 1 {
                                return Err(TypeError {
                                    kind: TypeErrorKind::ArgumentMismatch,
                                    message: "HashMap.Get expects exactly 1 argument".to_string(),
                                });
                            }
                            let k_arg = self.check_expression(&arguments[0])?;
                            let (k_type, v_type) = self
                                .get_hashmap_key_value_types(struct_name)
                                .ok_or_else(|| TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: "Invalid HashMap struct layout".to_string(),
                                })?;
                            if !types_match(&k_type, &k_arg) {
                                return Err(TypeError {
                                    kind: TypeErrorKind::TypeMismatch,
                                    message: format!(
                                        "Key type mismatch for HashMap.Get. Expected {:?} but got {:?}",
                                        k_type, k_arg
                                    ),
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
                    }
                    if left_type == Type::Arena && right == "Free" {
                        if !arguments.is_empty() {
                            return Err(TypeError {
                                kind: TypeErrorKind::ArgumentMismatch,
                                message: "Arena.Free() expects 0 arguments".to_string(),
                            });
                        }
                        return Ok(Type::Void);
                    }
                }

                Err(TypeError {
                    kind: TypeErrorKind::UndefinedFunction,
                    message: format!(
                        "Semantic Error: Call to unresolved function '{}'",
                        func_path
                    ),
                })
            }
            Expression::Empty(target_type) => {
                let resolved = self.resolve_type(target_type)?;
                Ok(resolved)
            }
        }
    }
}
