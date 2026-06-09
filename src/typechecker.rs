use crate::ast::{Expression, FieldDef, Program, Statement};
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

fn types_match(expected: &Type, actual: &Type) -> bool {
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
                return false;
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
}

pub struct TypeChecker {
    symbol_table: HashMap<String, Type>,
    pub variable_types: HashMap<String, Type>,
    pub moved_vars: HashSet<String>,
    pub in_unsafe_block: bool,
    pub struct_registry: HashMap<String, StructLayout>,
    pub struct_templates: HashMap<String, StructTemplate>,
    pub variable_origins: HashMap<String, String>, // Dynamic Origin Tracker [1]
    pub function_registry: HashMap<String, FunctionSignature>, // Function Registry [3]
    pub expected_return_type: Option<Type>,
}

impl Default for TypeChecker {
    fn default() -> Self {
        Self::new()
    }
}

impl TypeChecker {
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

        TypeChecker {
            symbol_table: HashMap::new(),
            variable_types: HashMap::new(),
            moved_vars: HashSet::new(),
            in_unsafe_block: false,
            struct_registry,
            struct_templates: HashMap::new(),
            variable_origins: HashMap::new(),
            function_registry: HashMap::new(),
            expected_return_type: None,
        }
    }

    pub fn check_program(&mut self, program: &Program) -> Result<(), TypeError> {
        // Pre-pass: Dynamically register structs, templates, and functions [3]
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
                        StructTemplate {
                            generics: generics.clone(),
                            fields: fields.clone(),
                        },
                    );
                }
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
                    FunctionSignature {
                        param_names,
                        params: resolved_params?,
                        return_type: resolved_return,
                    },
                );
            }
        }

        // Processing Pass
        for stmt in &program.statements {
            self.check_statement(stmt)?;
        }
        Ok(())
    }

    fn check_statement(&mut self, stmt: &Statement) -> Result<(), TypeError> {
        match stmt {
            Statement::StructDecl { .. } => {}
            Statement::FunctionDecl {
                name: _,
                params,
                return_type,
                body,
            } => {
                let parent_scope = self.symbol_table.clone();

                // Register all function parameters in the local symbol table [3]
                for param in params {
                    let resolved_param_type = self.resolve_type(&param.param_type)?;
                    self.symbol_table
                        .insert(param.name.clone(), resolved_param_type);
                }

                // Register and track expected return types inside local scope [3]
                let resolved_return_type = self.resolve_type(return_type)?;
                let old_expected = self.expected_return_type.clone();
                self.expected_return_type = Some(resolved_return_type);

                for s in &body.statements {
                    self.check_statement(s)?;
                }

                // Clean-up and restore parent scopes [3]
                self.symbol_table = parent_scope;
                self.expected_return_type = old_expected;
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

                    if let Some(orig) = self.get_expression_origin(val_expr) {
                        self.variable_origins.insert(name.clone(), orig);
                    } else {
                        self.variable_origins.insert(name.clone(), name.clone());
                    }
                    t
                } else {
                    if let Some(explicit_t) = var_type {
                        self.variable_origins.insert(name.clone(), name.clone());
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
            }
            Statement::Assignment { left, value } => {
                let left_type = self.check_expression(left)?;
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

                let parent_scope = self.symbol_table.clone();
                for s in &consequence.statements {
                    self.check_statement(s)?;
                }
                self.symbol_table = parent_scope;

                if let Some(alt_body) = alternative {
                    let parent_scope = self.symbol_table.clone();
                    for s in &alt_body.statements {
                        self.check_statement(s)?;
                    }
                    self.symbol_table = parent_scope;
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
                let actual_return = if let Some(expr) = maybe_expr {
                    let mut t = self.check_expression(expr)?;
                    t = self.resolve_type(&t)?;
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

    fn substitute_brand(&self, t: &Type, new_brand: &Option<String>) -> Type {
        match t {
            Type::Index(struct_name, _) => Type::Index(struct_name.clone(), new_brand.clone()),
            Type::Struct(struct_name, _) => Type::Struct(struct_name.clone(), new_brand.clone()),
            Type::RawPointer(inner) => {
                Type::RawPointer(Box::new(self.substitute_brand(inner, new_brand)))
            }
            _ => t.clone(),
        }
    }

    fn get_type_brand(&self, t: &Type) -> Option<String> {
        match t {
            Type::Index(_, Some(brand)) => Some(brand.clone()),
            Type::Struct(_, Some(brand)) => Some(brand.clone()),
            Type::RawPointer(inner) => self.get_type_brand(inner),
            Type::Slice(inner) => self.get_type_brand(inner),
            _ => None,
        }
    }

    fn get_expression_origin(&self, expr: &Expression) -> Option<String> {
        match expr {
            Expression::Identifier(name) => {
                if let Some(origin) = self.variable_origins.get(name) {
                    Some(origin.clone())
                } else {
                    Some(name.clone())
                }
            }
            Expression::AsCast { left, .. } => self.get_expression_origin(left),
            Expression::AddressOf(inner) => self.get_expression_origin(inner),
            Expression::Dereference(inner) => self.get_expression_origin(inner),
            Expression::Selector { left, .. } => self.get_expression_origin(left),
            Expression::IndexAccess { allocator, .. } => self.get_expression_origin(allocator),
            _ => None,
        }
    }

    pub fn resolve_type(&mut self, t: &Type) -> Result<Type, TypeError> {
        match t {
            Type::Generic(name, args) => {
                let resolved_args: Result<Vec<Type>, TypeError> =
                    args.iter().map(|arg| self.resolve_type(arg)).collect();
                self.monomorphize(name, &resolved_args?)
            }
            Type::Struct(name, Some(brand)) => {
                if self.struct_templates.contains_key(name) {
                    let args = vec![Type::Struct(brand.clone(), None)];
                    self.monomorphize(name, &args)
                } else {
                    Ok(t.clone())
                }
            }
            Type::Index(struct_name, Some(brand)) => {
                if self.struct_templates.contains_key(struct_name) {
                    let args = vec![Type::Struct(brand.clone(), None)];
                    let monomorphized_struct = self.monomorphize(struct_name, &args)?;
                    if let Type::Struct(concrete_name, _) = monomorphized_struct {
                        Ok(Type::Index(concrete_name, Some(brand.clone())))
                    } else {
                        Ok(t.clone())
                    }
                } else {
                    Ok(t.clone())
                }
            }
            Type::RawPointer(inner) => {
                let resolved = self.resolve_type(inner)?;
                Ok(Type::RawPointer(Box::new(resolved)))
            }
            Type::Slice(inner) => {
                let resolved = self.resolve_type(inner)?;
                Ok(Type::Slice(Box::new(resolved)))
            }
            _ => Ok(t.clone()),
        }
    }

    fn monomorphize(&mut self, template_name: &str, args: &[Type]) -> Result<Type, TypeError> {
        let template = self
            .struct_templates
            .get(template_name)
            .cloned()
            .ok_or_else(|| TypeError {
                kind: TypeErrorKind::TemplateNotFound,
                message: format!(
                    "Semantic Error: Generic template '{}' not found",
                    template_name
                ),
            })?;

        if template.generics.len() != args.len() {
            return Err(TypeError {
                kind: TypeErrorKind::TemplateArgumentMismatch,
                message: format!(
                    "Semantic Error: Template '{}' expects {} generic arguments but got {}",
                    template_name,
                    template.generics.len(),
                    args.len()
                ),
            });
        }

        let mut substitution_map = HashMap::new();
        for (generic, arg) in template.generics.iter().zip(args.iter()) {
            substitution_map.insert(generic.clone(), arg.clone());
        }

        let concrete_name = self.get_monomorphized_name(template_name, args);

        let mut brand = None;
        for arg in args {
            if let Type::Struct(brand_name, _) = arg {
                brand = Some(brand_name.clone());
            }
        }

        if !self.struct_registry.contains_key(&concrete_name) {
            let mut concrete_fields = HashMap::new();
            for field in &template.fields {
                let substituted_type =
                    self.substitute_generics(&field.field_type, &substitution_map);
                let resolved_field_type = self.resolve_type(&substituted_type)?;
                concrete_fields.insert(field.name.clone(), resolved_field_type);
            }

            self.struct_registry.insert(
                concrete_name.clone(),
                StructLayout {
                    brand: brand.clone(),
                    fields: concrete_fields,
                },
            );
        }

        Ok(Type::Struct(concrete_name, brand))
    }

    fn get_type_ident(&self, t: &Type) -> String {
        match t {
            Type::Int => "int".to_string(),
            Type::Byte => "byte".to_string(),
            Type::Arena => "Arena".to_string(),
            Type::Void => "void".to_string(),
            Type::Str => "str".to_string(), // Added for String Views
            Type::RawPointer(inner) => format!("{}_ptr", self.get_type_ident(inner)),
            Type::Slice(inner) => format!("Slice_{}", self.get_type_ident(inner)),
            Type::Struct(name, _) => name.clone(),
            Type::Index(name, _) => format!("Index_{}", name),
            _ => "unknown".to_string(),
        }
    }

    fn get_monomorphized_name(&self, template_name: &str, args: &[Type]) -> String {
        let arg_names: Vec<String> = args.iter().map(|arg| self.get_type_ident(arg)).collect();
        format!("{}_{}", template_name, arg_names.join("_"))
    }

    fn substitute_generics(&self, t: &Type, map: &HashMap<String, Type>) -> Type {
        match t {
            Type::Struct(name, brand) => {
                if let Some(substituted) = map.get(name) {
                    substituted.clone()
                } else {
                    let new_brand = if let Some(b) = brand {
                        if let Some(Type::Struct(b_name, _)) = map.get(b) {
                            Some(b_name.clone())
                        } else {
                            Some(b.clone())
                        }
                    } else {
                        None
                    };
                    Type::Struct(name.clone(), new_brand)
                }
            }
            Type::Index(struct_name, brand) => {
                let new_struct = if let Some(substituted) = map.get(struct_name) {
                    match substituted {
                        Type::Struct(name, _) => name.clone(),
                        _ => struct_name.clone(),
                    }
                } else {
                    struct_name.clone()
                };

                let new_brand = if let Some(b) = brand {
                    if let Some(Type::Struct(b_name, _)) = map.get(b) {
                        Some(b_name.clone())
                    } else {
                        Some(b.clone())
                    }
                } else {
                    None
                };
                Type::Index(new_struct, new_brand)
            }
            Type::RawPointer(inner) => {
                Type::RawPointer(Box::new(self.substitute_generics(inner, map)))
            }
            Type::Slice(inner) => Type::Slice(Box::new(self.substitute_generics(inner, map))),
            _ => t.clone(),
        }
    }

    fn substitute_brand_names(&self, t: &Type, map: &HashMap<String, String>) -> Type {
        match t {
            Type::Index(struct_name, Some(brand)) => {
                let new_brand = map.get(brand).cloned().unwrap_or_else(|| brand.clone());
                let mut new_struct_name = struct_name.clone();
                for (old_b, new_b) in map {
                    let suffix = format!("_{}", old_b);
                    let new_suffix = format!("_{}", new_b);
                    if new_struct_name.ends_with(&suffix) {
                        new_struct_name = format!(
                            "{}{}",
                            new_struct_name.trim_end_matches(&suffix),
                            new_suffix
                        );
                    }
                }
                Type::Index(new_struct_name, Some(new_brand))
            }
            Type::Struct(struct_name, Some(brand)) => {
                let new_brand = map.get(brand).cloned().unwrap_or_else(|| brand.clone());
                let mut new_struct_name = struct_name.clone();
                for (old_b, new_b) in map {
                    let suffix = format!("_{}", old_b);
                    let new_suffix = format!("_{}", new_b);
                    if new_struct_name.ends_with(&suffix) {
                        new_struct_name = format!(
                            "{}{}",
                            new_struct_name.trim_end_matches(&suffix),
                            new_suffix
                        );
                    }
                }
                Type::Struct(new_struct_name, Some(new_brand))
            }
            Type::RawPointer(inner) => {
                Type::RawPointer(Box::new(self.substitute_brand_names(inner, map)))
            }
            Type::Slice(inner) => Type::Slice(Box::new(self.substitute_brand_names(inner, map))),
            Type::Generic(name, args) => {
                let new_args = args
                    .iter()
                    .map(|arg| self.substitute_brand_names(arg, map))
                    .collect();
                Type::Generic(name.clone(), new_args)
            }
            _ => t.clone(),
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

                if let Some(origin) = self.variable_origins.get(name)
                    && self.moved_vars.contains(origin)
                {
                    return Err(TypeError {
                        kind: TypeErrorKind::VariableOriginInvalidated,
                        message: format!(
                            "Semantic Error: Variable '{}' cannot be used because its backing origin '{}' has been moved or invalidated",
                            name, origin
                        ),
                    });
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
                    if !self.symbol_table.contains_key(name) {
                        return Err(TypeError {
                            kind: TypeErrorKind::UndefinedVariable,
                            message: format!(
                                "Semantic Error: Cannot move undefined variable '{}'",
                                name
                            ),
                        });
                    }

                    self.moved_vars.insert(name.clone());
                    Ok(self.symbol_table.get(name).unwrap().clone())
                } else {
                    Err(TypeError {
                        kind: TypeErrorKind::InvalidMoveTarget,
                        message: "Semantic Error: Only variables can be moved".to_string(),
                    })
                }
            }
            Expression::Take(inner_expr) => {
                let expr_type = self.check_expression(inner_expr)?;
                if expr_type == Type::Int {
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
                } else if alloc_type == Type::Arena
                    || matches!(alloc_type, Type::RawPointer(ref inner) if **inner == Type::Arena)
                {
                    let alloc_name = self.expression_to_string(allocator);
                    if let Type::Index(struct_name, Some(brand_name)) = index_type {
                        if brand_name != alloc_name {
                            return Err(TypeError {
                                kind: TypeErrorKind::BrandLifetimeViolation,
                                message: format!(
                                    "Semantic Error: Value-Branded Lifetime Violation! Attempted to index allocator '{}' with index '{}' branded for '{}'",
                                    alloc_name,
                                    self.expression_to_string(index),
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
                            "Semantic Error: Subscript indexing is only valid on Arenas or Slices, but got {:?}",
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
                let left_str = self.expression_to_string(left);
                let path = format!("{}.{}", left_str, right);

                if path == "os.Arena" {
                    return Ok(Type::Void);
                }

                if let Type::Struct(struct_name, _brand) = &left_type {
                    if struct_name.starts_with("CastResult_") {
                        if right == "Ok" {
                            return Ok(Type::Int);
                        }
                        if right == "Val" {
                            let target_struct =
                                struct_name.trim_start_matches("CastResult_").to_string();
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

                let func_path = self.expression_to_string(function);

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
                    return Err(TypeError {
                        kind: TypeErrorKind::ArgumentMismatch,
                        message: format!(
                            "Semantic Error: len expects a Slice or Str argument, but got {:?}",
                            arg_type
                        ),
                    });
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
                            let actual_name = self.expression_to_string(arg);
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
                    let brand_name = self.expression_to_string(&arguments[0]);
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
                    if left_type == Type::Arena && right == "Free" {
                        if !arguments.is_empty() {
                            return Err(TypeError {
                                kind: TypeErrorKind::ArgumentMismatch,
                                message: "Semantic Error: Arena.Free() expects 0 arguments"
                                    .to_string(),
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
        }
    }

    fn expression_to_string(&self, expr: &Expression) -> String {
        match expr {
            Expression::Identifier(name) => name.clone(),
            Expression::Integer(val) => val.to_string(),
            Expression::String(val) => format!("\"{}\"", val), // Added for String Views
            Expression::Call {
                function,
                arguments,
            } => {
                let args_strs: Vec<String> = arguments
                    .iter()
                    .map(|arg| self.expression_to_string(arg))
                    .collect();
                format!(
                    "{}({})",
                    self.expression_to_string(function),
                    args_strs.join(", ")
                )
            }
            Expression::Selector { left, right } => {
                format!("{}.{}", self.expression_to_string(left), right)
            }
            Expression::IndexAccess { allocator, index } => {
                format!(
                    "{}[{}]",
                    self.expression_to_string(allocator),
                    self.expression_to_string(index)
                )
            }
            Expression::Move(inner) => self.expression_to_string(inner),
            Expression::Take(inner) => self.expression_to_string(inner),
            Expression::Binary { op, left, right } => {
                format!(
                    "{} {} {}",
                    self.expression_to_string(left),
                    op,
                    self.expression_to_string(right)
                )
            }
            Expression::AsCast { left, .. } => self.expression_to_string(left),
            Expression::AddressOf(inner) => format!("&{}", self.expression_to_string(inner)),
            Expression::Dereference(inner) => format!("*{}", self.expression_to_string(inner)),
        }
    }
}
