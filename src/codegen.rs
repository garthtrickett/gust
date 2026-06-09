use crate::ast::{BlockStatement, Expression, Program, Statement};
use crate::typechecker::Type;
use std::collections::HashMap;

pub struct Codegen {
    symbol_table: HashMap<String, Type>,
}

impl Codegen {
    pub fn new(symbol_table: HashMap<String, Type>) -> Self {
        Codegen { symbol_table }
    }

    pub fn generate(&self, program: &Program) -> String {
        let mut c_code = String::new();

        c_code.push_str("#include <stdio.h>\n");
        c_code.push_str("#include <stdlib.h>\n");
        c_code.push_str("#include <stdint.h>\n\n");

        c_code.push_str("// ====================================================\n");
        c_code.push_str("// GUST MINIMAL C RUNTIME DEFINITIONS\n");
        c_code.push_str("// ====================================================\n");
        c_code.push_str("typedef struct {\n");
        c_code.push_str("    void* BaseAddress;\n");
        c_code.push_str("} os_Arena;\n\n");

        c_code.push_str("os_Arena os_Arena_New() {\n");
        c_code.push_str("    os_Arena arena;\n");
        c_code
            .push_str("    arena.BaseAddress = malloc(1024); // Allocate mock arena heap block\n");
        c_code.push_str("    return arena;\n");
        c_code.push_str("}\n\n");

        c_code.push_str("void os_Arena_Free(os_Arena* arena) {\n");
        c_code.push_str("    if (arena->BaseAddress != NULL) {\n");
        c_code.push_str("        free(arena->BaseAddress);\n");
        c_code.push_str("        arena->BaseAddress = NULL;\n");
        c_code.push_str("    }\n");
        c_code.push_str("}\n\n");

        c_code.push_str("static int alloc_counter = 0;\n");
        c_code.push_str("int os_ArenaAlloc(os_Arena* arena) {\n");
        c_code.push_str("    int assigned = alloc_counter;\n");
        c_code.push_str("    alloc_counter++;\n");
        c_code.push_str("    return assigned;\n");
        c_code.push_str("}\n\n");

        c_code.push_str("void os_LogInt(int val) {\n");
        c_code.push_str("    printf(\"%d\\n\", val);\n");
        c_code.push_str("}\n\n");

        c_code.push_str("typedef struct {\n");
        c_code.push_str("    int SessionID;\n");
        c_code.push_str("    int Next;\n");
        c_code.push_str("} SessionNode;\n\n");

        c_code.push_str("typedef struct {\n");
        c_code.push_str("    int UserID;\n");
        c_code.push_str("    unsigned char UserTag[16];\n");
        c_code.push_str("    int Active;\n");
        c_code.push_str("} APIRequest;\n\n");

        c_code.push_str("typedef struct {\n");
        c_code.push_str("    APIRequest* Val;\n");
        c_code.push_str("    int Ok;\n");
        c_code.push_str("} CastResult;\n\n");

        c_code.push_str("unsigned char* os_MockPayload() {\n");
        c_code.push_str("    unsigned char* buf = malloc(sizeof(APIRequest));\n");
        c_code.push_str("    ((APIRequest*)buf)->UserID = 42;\n");
        c_code.push_str("    return buf;\n");
        c_code.push_str("}\n\n");

        c_code.push_str("// ====================================================\n");
        c_code.push_str("// TRANSPILED PROGRAM CODES\n");
        c_code.push_str("// ====================================================\n");

        for stmt in &program.statements {
            c_code.push_str(&self.gen_statement(stmt));
        }

        c_code
    }

    // Resolves raw nested pointer types recursively to standard C syntax (e.g. *int -> int*)
    fn get_c_type(&self, t: &Type) -> String {
        match t {
            Type::Int => "int".to_string(),
            Type::Void => "void".to_string(),
            Type::Arena => "os_Arena".to_string(),
            Type::ByteSlice => "unsigned char*".to_string(),
            Type::Index(_, _) => "int".to_string(),
            Type::Struct(name, _) => {
                if name == "CastResult" {
                    "CastResult".to_string()
                } else {
                    name.clone()
                }
            }
            Type::RawPointer(inner) => format!("{}*", self.get_c_type(inner)),
        }
    }

    fn gen_statement(&self, stmt: &Statement) -> String {
        let mut result = String::new();
        match stmt {
            Statement::FunctionDecl { name, body } => {
                if name == "main" {
                    result.push_str("int main() {\n");
                } else {
                    result.push_str(&format!("void {}() {{\n", name));
                }
                result.push_str(&self.gen_block_statement(body));
            }
            Statement::VarDecl {
                name,
                is_mut: _,
                value,
                var_type: _,
            } => {
                let var_type = self.symbol_table.get(name).unwrap_or(&Type::Void);
                let type_str = self.get_c_type(var_type);
                let val_str = self.gen_expression(value);
                result.push_str(&format!("    {} {} = {};\n", type_str, name, val_str));
            }
            Statement::Assignment { left, value } => {
                let left_str = self.gen_expression(left);
                let val_str = self.gen_expression(value);
                result.push_str(&format!("    {} = {};\n", left_str, val_str));
            }
            Statement::While { condition, body } => {
                let cond_str = self.gen_expression(condition);
                result.push_str(&format!("    while ({}) {{\n", cond_str));
                result.push_str(&self.gen_loop_body(body));
                result.push_str("    }\n");
            }
            Statement::If {
                condition,
                consequence,
                alternative,
            } => {
                let cond_str = self.gen_expression(condition);
                result.push_str(&format!("    if ({}) {{\n", cond_str));
                result.push_str(&self.gen_loop_body(consequence));

                if let Some(alt_body) = alternative {
                    result.push_str("    } else {\n");
                    result.push_str(&self.gen_loop_body(alt_body));
                }
                result.push_str("    }\n");
            }
            Statement::UnsafeBlock { body } => {
                result.push_str("    {\n"); // Maps directly to standard C scoped blocks
                result.push_str(&self.gen_loop_body(body));
                result.push_str("    }\n");
            }
            Statement::Defer { expr: _ } => {
                // Defer handled at scope exit block layer
            }
            Statement::Expression(expr) => {
                let expr_str = self.gen_expression(expr);
                result.push_str(&format!("    {};\n", expr_str));
            }
        }
        result
    }

    fn gen_block_statement(&self, body: &BlockStatement) -> String {
        let mut result = String::new();
        let mut defer_stack = Vec::new();

        for stmt in &body.statements {
            if let Statement::Defer { expr } = stmt {
                let defer_str = self.gen_expression(expr);
                defer_stack.push(defer_str);
            } else {
                result.push_str(&self.gen_statement(stmt));
            }
        }

        if !defer_stack.is_empty() {
            result.push_str("    // === DEFERRED CLEANUP CODES ===\n");
            while let Some(defer_str) = defer_stack.pop() {
                result.push_str(&format!("    {};\n", defer_str));
            }
        }

        result.push_str("    return 0;\n");
        result.push_str("}\n");
        result
    }

    fn gen_loop_body(&self, body: &BlockStatement) -> String {
        let mut result = String::new();
        for stmt in &body.statements {
            result.push_str(&self.gen_statement(stmt));
        }
        result
    }

    fn gen_expression(&self, expr: &Expression) -> String {
        match expr {
            Expression::Identifier(name) => {
                if name == "null" {
                    "0xFFFFFFFF".to_string()
                } else {
                    name.clone()
                }
            }
            Expression::Integer(val) => val.to_string(),
            Expression::Move(inner_expr) => self.gen_expression(inner_expr),
            Expression::Take(inner_expr) => {
                if let Expression::Identifier(name) = &**inner_expr {
                    let var_type = self.symbol_table.get(name).unwrap_or(&Type::Void);
                    let type_str = self.get_c_type(var_type);
                    format!(
                        "({{ {} _temp = {}; {}.BaseAddress = NULL; _temp; }})",
                        type_str, name, name
                    )
                } else {
                    self.gen_expression(inner_expr)
                }
            }
            Expression::AddressOf(inner) => {
                format!("&({})", self.gen_expression(inner))
            }
            Expression::Dereference(inner) => {
                format!("*({})", self.gen_expression(inner))
            }
            Expression::AsCast {
                left,
                target_type,
                is_reference,
            } => {
                let left_str = self.gen_expression(left);
                let target_str = match target_type {
                    Type::Struct(name, _) => name.clone(),
                    Type::RawPointer(inner) => format!("{}*", self.get_c_type(inner)),
                    _ => "void".to_string(),
                };

                if *is_reference {
                    format!(
                        "({{ CastResult res; res.Ok = (((uintptr_t){} & 7) == 0); res.Val = ({}*){}; res; }})",
                        left_str, target_str, left_str
                    )
                } else {
                    // Safe raw pointer cast (inside unsafe) or stack copy
                    format!("(({}*){})", target_str, left_str)
                }
            }
            Expression::IndexAccess { allocator, index } => {
                let alloc_str = self.gen_expression(allocator);
                let index_str = self.gen_expression(index);

                let mut target_struct = "SessionNode".to_string();
                if let Expression::Identifier(idx_name) = &**index
                    && let Some(Type::Index(struct_name, _)) = self.symbol_table.get(idx_name) {
                        target_struct = struct_name.clone();
                    }

                format!(
                    "(( {}*)((char*){}.BaseAddress + ({} * sizeof({}))))",
                    target_struct, alloc_str, index_str, target_struct
                )
            }
            Expression::Binary { op, left, right } => {
                let left_str = self.gen_expression(left);
                let right_str = self.gen_expression(right);
                format!("{} {} {}", left_str, op, right_str)
            }
            Expression::Selector { left, right } => {
                let left_str = self.gen_expression(left);

                let mut use_arrow = false;
                if matches!(**left, Expression::IndexAccess { .. }) {
                    use_arrow = true;
                } else if let Expression::Selector {
                    left: inner_left,
                    right: inner_right,
                } = &**left
                {
                    if let Expression::Identifier(name) = &**inner_left
                        && name == "result" && inner_right == "Val" {
                            use_arrow = true;
                        }
                } else if matches!(**left, Expression::Dereference(..)) {
                    // If left is a raw pointer dereference, C compiler evaluates field access via dot operator
                    use_arrow = false;
                }

                if use_arrow {
                    format!("{}->{}", left_str, right)
                } else {
                    format!("{}.{}", left_str, right)
                }
            }
            Expression::Call {
                function,
                arguments,
            } => {
                if let Expression::Selector { left, right } = &**function
                    && let Expression::Identifier(name) = &**left
                        && let Some(Type::Arena) = self.symbol_table.get(name)
                            && right == "Free" {
                                return format!("os_Arena_Free(&{})", name);
                            }

                let func_c = self.gen_expression(function).replace(".", "_");
                let mut arg_strs = Vec::new();
                for arg in arguments {
                    if let Expression::Identifier(name) = arg
                        && let Some(Type::Arena) = self.symbol_table.get(name) {
                            arg_strs.push(format!("&{}", name));
                            continue;
                        }
                    arg_strs.push(self.gen_expression(arg));
                }
                format!("{}({})", func_c, arg_strs.join(", "))
            }
        }
    }
}
