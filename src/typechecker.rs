use crate::ast::{Expression, Program, Statement};
use std::collections::{HashMap, HashSet};

#[derive(Debug, Clone, PartialEq)]
pub enum Type {
    Int,
    Void,
    Arena,
    ByteSlice,
    Index(String, Option<String>),
    Struct(String, Option<String>),
    RawPointer(Box<Type>),
}

fn types_match(expected: &Type, actual: &Type) -> bool {
    match (expected, actual) {
        (Type::Index(e_struct, e_brand), Type::Index(a_struct, a_brand)) => {
            if e_struct != a_struct {
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
        (Type::RawPointer(e_inner), Type::RawPointer(a_inner)) => types_match(e_inner, a_inner),
        _ => expected == actual,
    }
}

pub struct TypeChecker {
    symbol_table: HashMap<String, Type>,
    pub variable_types: HashMap<String, Type>,
    pub moved_vars: HashSet<String>,
    pub in_unsafe_block: bool,
}

impl Default for TypeChecker {
    fn default() -> Self {
        Self::new()
    }
}

impl TypeChecker {
    pub fn new() -> Self {
        TypeChecker {
            symbol_table: HashMap::new(),
            variable_types: HashMap::new(),
            moved_vars: HashSet::new(),
            in_unsafe_block: false,
        }
    }

    pub fn check_program(&mut self, program: &Program) -> Result<(), String> {
        for stmt in &program.statements {
            self.check_statement(stmt)?;
        }
        Ok(())
    }

    fn check_statement(&mut self, stmt: &Statement) -> Result<(), String> {
        match stmt {
            Statement::FunctionDecl { name: _, body } => {
                let parent_scope = self.symbol_table.clone();
                for s in &body.statements {
                    self.check_statement(s)?;
                }
                self.symbol_table = parent_scope;
            }
            Statement::VarDecl {
                name,
                is_mut: _,
                value,
                var_type,
            } => {
                let val_type = self.check_expression(value)?;

                if let Some(explicit_t) = var_type
                    && !types_match(explicit_t, &val_type) {
                        return Err(format!(
                            "Semantic Error: Explicit Type Annotation Mismatch. Declared {:?} but got value {:?}",
                            explicit_t, val_type
                        ));
                    }

                self.symbol_table.insert(name.clone(), val_type.clone());
                self.variable_types.insert(name.clone(), val_type);
            }
            Statement::Assignment { left, value } => {
                let left_type = self.check_expression(left)?;
                let val_type = self.check_expression(value)?;
                if !types_match(&left_type, &val_type) {
                    return Err(format!(
                        "Semantic Error: Mismatched types in assignment. Cannot assign {:?} to {:?}",
                        val_type, left_type
                    ));
                }
            }
            Statement::While { condition, body } => {
                let cond_type = self.check_expression(condition)?;
                if cond_type != Type::Int {
                    return Err("Semantic Error: Loop condition must evaluate to an Int (binary comparison)".to_string());
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
                    return Err(
                        "Semantic Error: If condition must evaluate to an Int (binary comparison)"
                            .to_string(),
                    );
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
            Statement::Expression(expr) => {
                self.check_expression(expr)?;
            }
        }
        Ok(())
    }

    fn check_expression(&mut self, expr: &Expression) -> Result<Type, String> {
        match expr {
            Expression::Identifier(name) => {
                if self.moved_vars.contains(name) {
                    return Err(format!("Semantic Error: Use of moved variable '{}'", name));
                }

                if name == "null" {
                    return Ok(Type::Index("SessionNode".to_string(), None));
                }

                if let Some(t) = self.symbol_table.get(name) {
                    Ok(t.clone())
                } else {
                    Err(format!("Semantic Error: Undefined variable '{}'", name))
                }
            }
            Expression::Integer(_) => Ok(Type::Int),
            Expression::Move(inner_expr) => {
                if let Expression::Identifier(name) = &**inner_expr {
                    if self.moved_vars.contains(name) {
                        return Err(format!(
                            "Semantic Error: Variable '{}' has already been moved",
                            name
                        ));
                    }
                    if !self.symbol_table.contains_key(name) {
                        return Err(format!(
                            "Semantic Error: Cannot move undefined variable '{}'",
                            name
                        ));
                    }

                    self.moved_vars.insert(name.clone());
                    Ok(self.symbol_table.get(name).unwrap().clone())
                } else {
                    Err("Semantic Error: Only variables can be moved".to_string())
                }
            }
            Expression::Take(inner_expr) => {
                let expr_type = self.check_expression(inner_expr)?;
                if expr_type == Type::Int {
                    return Err("Semantic Error: The 'take' operator is strictly banned on primitive POD types (like Int)".to_string());
                }
                Ok(expr_type)
            }
            Expression::AddressOf(inner) => {
                let inner_type = self.check_expression(inner)?;
                Ok(Type::RawPointer(Box::new(inner_type)))
            }
            Expression::Dereference(inner) => {
                if !self.in_unsafe_block {
                    return Err("Semantic Error: Dereferencing raw pointers is strictly prohibited outside 'unsafe' blocks".to_string());
                }

                let inner_type = self.check_expression(inner)?;
                if let Type::RawPointer(target_type) = inner_type {
                    Ok((*target_type).clone())
                } else {
                    Err(format!(
                        "Semantic Error: Cannot dereference non-pointer type {:?}",
                        inner_type
                    ))
                }
            }
            Expression::AsCast {
                left,
                target_type,
                is_reference: _,
            } => {
                let left_type = self.check_expression(left)?;

                if self.in_unsafe_block
                    && let Type::RawPointer(_) = left_type
                        && let Type::RawPointer(_) = target_type {
                            return Ok(target_type.clone());
                        }

                if left_type != Type::ByteSlice {
                    return Err(format!(
                        "Semantic Error: Casting source must be a byte slice '[]byte', but got {:?}",
                        left_type
                    ));
                }

                if let Type::Struct(struct_name, _) = target_type
                    && struct_name == "APIRequest" {
                        return Ok(Type::Struct("CastResult".to_string(), None));
                    }

                Err(format!(
                    "Semantic Error: Unsupported cast target type {:?}",
                    target_type
                ))
            }
            Expression::IndexAccess { allocator, index } => {
                let alloc_type = self.check_expression(allocator)?;
                if alloc_type != Type::Arena {
                    return Err(format!(
                        "Semantic Error: Subscript indexing is only valid on Arena allocators, but got {:?}",
                        alloc_type
                    ));
                }
                let alloc_name = self.expression_to_string(allocator);

                let index_type = self.check_expression(index)?;
                if let Type::Index(struct_name, Some(brand_name)) = index_type {
                    if brand_name != alloc_name {
                        return Err(format!(
                            "Semantic Error: Value-Branded Lifetime Violation! Attempted to index allocator '{}' with index '{}' branded for '{}'",
                            alloc_name,
                            self.expression_to_string(index),
                            brand_name
                        ));
                    }
                    Ok(Type::Struct(struct_name, Some(brand_name)))
                } else {
                    Err(format!(
                        "Semantic Error: Expected a branded Index offset for subscript indexing, but got {:?}",
                        index_type
                    ))
                }
            }
            Expression::Binary { op, left, right } => {
                let left_type = self.check_expression(left)?;
                let right_type = self.check_expression(right)?;

                if op == "==" || op == "!=" {
                    if let Type::Index(_, _) = left_type
                        && let Expression::Identifier(name) = &**right
                            && name == "null" {
                                return Ok(Type::Int);
                            }
                    if let Type::Index(_, _) = right_type
                        && let Expression::Identifier(name) = &**left
                            && name == "null" {
                                return Ok(Type::Int);
                            }
                }

                if !types_match(&left_type, &right_type) {
                    return Err(format!(
                        "Semantic Error: Mismatched types in binary operation '{}'. Left: {:?}, Right: {:?}",
                        op, left_type, right_type
                    ));
                }

                if (op == "+" || op == "-" || op == "*" || op == "/")
                    && left_type != Type::Int {
                        return Err(format!(
                            "Semantic Error: Math operation '{}' is only allowed on Int, but got {:?}",
                            op, left_type
                        ));
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

                if let Type::Struct(struct_name, _brand) = left_type {
                    if struct_name == "APIRequest" && right == "UserID" {
                        return Ok(Type::Int);
                    }
                    if struct_name == "APIRequest" && right == "SessionID" {
                        return Ok(Type::Int);
                    }
                    if struct_name == "CastResult" {
                        if right == "Ok" {
                            return Ok(Type::Int);
                        }
                        if right == "Val" {
                            return Ok(Type::Struct("APIRequest".to_string(), None));
                        }
                    }
                    if struct_name == "SessionNode" && right == "SessionID" {
                        return Ok(Type::Int);
                    }
                    if struct_name == "SessionNode" && right == "Next"
                        && let Some(brand) = _brand {
                            return Ok(Type::Index("SessionNode".to_string(), Some(brand)));
                        }
                    return Err(format!(
                        "Semantic Error: Field '{}' not found on struct layout '{}'",
                        right, struct_name
                    ));
                }

                if left_type == Type::Arena {
                    if right == "Free" {
                        return Ok(Type::Void);
                    }
                    return Err(format!(
                        "Semantic Error: Method '{}' not found on Arena allocator",
                        right
                    ));
                }

                Err(format!(
                    "Semantic Error: Unresolved namespace selector '{}'",
                    path
                ))
            }
            Expression::Call {
                function,
                arguments,
            } => {
                for arg in arguments {
                    self.check_expression(arg)?;
                }

                let func_path = self.expression_to_string(function);

                if func_path == "os.Arena.New" {
                    if !arguments.is_empty() {
                        return Err(
                            "Semantic Error: os.Arena.New() expects 0 arguments".to_string()
                        );
                    }
                    return Ok(Type::Arena);
                }

                if func_path == "os.MockPayload" {
                    if !arguments.is_empty() {
                        return Err(
                            "Semantic Error: os.MockPayload() expects 0 arguments".to_string()
                        );
                    }
                    return Ok(Type::ByteSlice);
                }

                if func_path == "os.ArenaAlloc" {
                    if arguments.len() != 1 {
                        return Err("Semantic Error: os.ArenaAlloc expects exactly 1 argument (the allocator variable)".to_string());
                    }
                    let arg_type = self.check_expression(&arguments[0])?;
                    if arg_type != Type::Arena {
                        return Err(
                            "Semantic Error: ArenaAlloc argument must be an Arena allocator"
                                .to_string(),
                        );
                    }
                    let brand_name = self.expression_to_string(&arguments[0]);
                    return Ok(Type::Index("SessionNode".to_string(), Some(brand_name)));
                }

                if func_path == "os.LogInt" {
                    if arguments.len() != 1 {
                        return Err(
                            "Semantic Error: os.LogInt expects exactly 1 argument".to_string()
                        );
                    }
                    let arg_type = self.check_expression(&arguments[0])?;
                    if arg_type != Type::Int {
                        return Err(format!(
                            "Semantic Error: os.LogInt expects an Int argument, but got {:?}",
                            arg_type
                        ));
                    }
                    return Ok(Type::Void);
                }

                if let Expression::Selector { left, right } = &**function {
                    let left_type = self.check_expression(left)?;
                    if left_type == Type::Arena && right == "Free" {
                        if !arguments.is_empty() {
                            return Err(
                                "Semantic Error: Arena.Free() expects 0 arguments".to_string()
                            );
                        }
                        return Ok(Type::Void);
                    }
                }

                Err(format!(
                    "Semantic Error: Call to unresolved function '{}'",
                    func_path
                ))
            }
        }
    }

    fn expression_to_string(&self, expr: &Expression) -> String {
        match expr {
            Expression::Identifier(name) => name.clone(),
            Expression::Integer(val) => val.to_string(),
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
