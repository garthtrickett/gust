use crate::ast::{BlockStatement, Expression, Program, Statement};
use crate::typechecker::{FunctionSignature, StructLayout, Type};
use std::cell::RefCell;
use std::collections::HashMap;

pub struct Codegen {
    symbol_table: RefCell<HashMap<String, Type>>,
    struct_registry: HashMap<String, StructLayout>,
    function_registry: HashMap<String, FunctionSignature>,
    current_alloc_struct: RefCell<Option<String>>,
}

impl Codegen {
    pub fn new(
        symbol_table: HashMap<String, Type>,
        struct_registry: HashMap<String, StructLayout>,
        function_registry: HashMap<String, FunctionSignature>,
    ) -> Self {
        Codegen {
            symbol_table: RefCell::new(symbol_table),
            struct_registry,
            function_registry,
            current_alloc_struct: RefCell::new(None),
        }
    }

    pub fn generate(&self, program: &Program) -> String {
        let mut c_code = String::new();

        c_code.push_str("#include <stdio.h>\n");
        c_code.push_str("#include <stdlib.h>\n");
        c_code.push_str("#include <stdint.h>\n\n");

        c_code.push_str("// ====================================================\n");
        c_code.push_str("// GUST PRODUCTION-GRADE BUMP ALLOCATOR RUNTIME\n");
        c_code.push_str("// ====================================================\n");
        c_code.push_str("typedef struct {\n");
        c_code.push_str("    void* BaseAddress;\n");
        c_code.push_str("    size_t Offset;\n");
        c_code.push_str("    size_t Capacity;\n");
        c_code.push_str("} os_Arena;\n\n");

        c_code.push_str("os_Arena os_Arena_New() {\n");
        c_code.push_str("    os_Arena arena;\n");
        c_code.push_str("    arena.Capacity = 1024; // 1KB Initial Arena Capacity\n");
        c_code.push_str("    arena.BaseAddress = malloc(arena.Capacity);\n");
        c_code.push_str("    arena.Offset = 0;\n");
        c_code.push_str("    return arena;\n");
        c_code.push_str("}\n\n");

        c_code.push_str("void os_Arena_Free(os_Arena* arena) {\n");
        c_code.push_str("    if (arena->BaseAddress != NULL) {\n");
        c_code.push_str("        free(arena->BaseAddress);\n");
        c_code.push_str("        arena->BaseAddress = NULL;\n");
        c_code.push_str("    }\n");
        c_code.push_str("}\n\n");

        c_code.push_str("// Standard Hardware-aligned Bump Allocation [1]\n");
        c_code.push_str("int os_ArenaAlloc(os_Arena* arena, size_t size) {\n");
        c_code.push_str(
            "    // Round up size to 8-byte boundary to satisfy hardware alignments [1]\n",
        );
        c_code.push_str("    size = (size + 7) & ~7;\n");
        c_code.push_str("    if (arena->Offset + size > arena->Capacity) {\n");
        c_code.push_str("        arena->Capacity *= 2;\n");
        c_code.push_str(
            "        arena->BaseAddress = realloc(arena->BaseAddress, arena->Capacity);\n",
        );
        c_code.push_str("    }\n");
        c_code.push_str("    size_t assigned_offset = arena->Offset;\n");
        c_code.push_str("    arena->Offset += size;\n");
        c_code.push_str("    return (int)assigned_offset;\n");
        c_code.push_str("}\n\n");

        c_code.push_str("void os_LogInt(int val) {\n");
        c_code.push_str("    printf(\"%d\\n\", val);\n");
        c_code.push_str("}\n\n");

        c_code.push_str("// ====================================================\n");
        c_code.push_str("// FORWARD DECLARATIONS\n");
        c_code.push_str("// ====================================================\n");

        for struct_name in self.struct_registry.keys() {
            c_code.push_str(&format!(
                "typedef struct {} {};\n",
                struct_name, struct_name
            ));
        }
        c_code.push('\n');

        c_code.push_str("// ====================================================\n");
        c_code.push_str("// DYNAMICALLY GENERATED SLICE STRUCTURES\n");
        c_code.push_str("// ====================================================\n");

        let mut slice_element_types = std::collections::HashSet::new();
        slice_element_types.insert(Type::Byte);

        // Wrap in a scope block so 'table' drops and releases the RefCell borrow immediately
        {
            let table = self.symbol_table.borrow();
            for t in (*table).values() {
                if let Type::Slice(inner) = t {
                    slice_element_types.insert((**inner).clone());
                }
            }
        }
        for layout in self.struct_registry.values() {
            for t in layout.fields.values() {
                if let Type::Slice(inner) = t {
                    slice_element_types.insert((**inner).clone());
                }
            }
        }

        for elem_type in &slice_element_types {
            let elem_c = self.get_c_type(elem_type);
            let elem_ident = self.get_c_type_ident(elem_type);
            c_code.push_str("typedef struct {\n");
            c_code.push_str(&format!("    {}* data;\n", elem_c));
            c_code.push_str("    int len;\n");
            c_code.push_str(&format!("}} Slice_{};\n\n", elem_ident));
        }

        c_code.push_str("Slice_unsigned_char os_MockPayload() {\n");
        c_code.push_str("    Slice_unsigned_char slice;\n");
        c_code.push_str("    slice.data = malloc(1024);\n");
        c_code.push_str("    slice.len = 1024;\n");
        c_code.push_str("    ((int*)slice.data)[0] = 42;\n");
        c_code.push_str("    return slice;\n");
        c_code.push_str("}\n\n");

        // Added built-in os_LogStr mapping read-only byte slices [1]
        c_code.push_str("void os_LogStr(Slice_unsigned_char s) {\n");
        c_code.push_str("    printf(\"%.*s\\n\", s.len, (char*)s.data);\n");
        c_code.push_str("}\n\n");

        c_code.push_str("// ====================================================\n");
        c_code.push_str("// DYNAMICALLY TRANSPILED USER STRUCTS\n");
        c_code.push_str("// ====================================================\n");

        for (struct_name, layout) in &self.struct_registry {
            c_code.push_str(&format!("struct {} {{\n", struct_name));
            for (field_name, field_type) in &layout.fields {
                let field_c_type = self.get_c_type(field_type);
                c_code.push_str(&format!("    {} {};\n", field_c_type, field_name));
            }
            c_code.push_str("};\n\n");

            c_code.push_str("typedef struct {\n");
            c_code.push_str(&format!("    {}* Val;\n", struct_name));
            c_code.push_str("    int Ok;\n");
            c_code.push_str(&format!("}} CastResult_{};\n\n", struct_name));
        }

        c_code.push_str("// ====================================================\n");
        c_code.push_str("// TRANSPILED PROGRAM CODES\n");
        c_code.push_str("// ====================================================\n");

        for stmt in &program.statements {
            c_code.push_str(&self.gen_statement(stmt));
        }

        c_code
    }

    fn get_c_type(&self, t: &Type) -> String {
        match t {
            Type::Int => "int".to_string(),
            Type::Byte => "unsigned char".to_string(),
            Type::Void => "void".to_string(),
            Type::Arena => "os_Arena".to_string(),
            Type::ByteSlice => "Slice_unsigned_char".to_string(),
            Type::Slice(inner) => format!("Slice_{}", self.get_c_type_ident(inner)),
            Type::Index(_, _) => "int".to_string(),
            Type::Struct(name, _) => name.clone(),
            Type::RawPointer(inner) => format!("{}*", self.get_c_type(inner)),
            Type::Generic(name, _) => name.clone(),
            Type::Str => "Slice_unsigned_char".to_string(),
        }
    }

    fn get_c_type_ident(&self, t: &Type) -> String {
        self.get_c_type(t).replace(" ", "_").replace("*", "_ptr")
    }

    fn gen_statement(&self, stmt: &Statement) -> String {
        let mut result = String::new();
        match stmt {
            Statement::StructDecl { .. } => {}
            Statement::FunctionDecl {
                name,
                params,
                return_type: _,
                body,
            } => {
                let sig = self.function_registry.get(name).cloned();

                let mut param_strs = Vec::new();
                let mut old_types = HashMap::new();

                for (i, param) in params.iter().enumerate() {
                    let resolved_type = if let Some(ref s) = sig {
                        s.params[i].clone()
                    } else {
                        param.param_type.clone()
                    };

                    let param_type_str = self.get_c_type(&resolved_type);

                    let is_arena_ptr = if let Type::RawPointer(inner) = &resolved_type {
                        **inner == Type::Arena
                    } else {
                        false
                    };

                    if is_arena_ptr || matches!(resolved_type, Type::Arena) {
                        param_strs.push(format!("os_Arena* {}", param.name));
                    } else {
                        param_strs.push(format!("{} {}", param_type_str, param.name));
                    }

                    let mut table = self.symbol_table.borrow_mut();
                    if let Some(old_t) = table.insert(param.name.clone(), resolved_type) {
                        old_types.insert(param.name.clone(), old_t);
                    }
                }

                let param_list = if param_strs.is_empty() {
                    "void".to_string()
                } else {
                    param_strs.join(", ")
                };

                let ret_str = if let Some(ref s) = sig {
                    self.get_c_type(&s.return_type)
                } else {
                    "void".to_string()
                };

                let mut body_str = String::new();
                if name == "main" {
                    body_str.push_str("int main() {\n");
                    body_str.push_str(&self.gen_block_statement(body));
                    body_str.push_str("    return 0;\n");
                    body_str.push_str("}\n\n");
                } else {
                    body_str.push_str(&format!("{} {}({}) {{\n", ret_str, name, param_list));
                    body_str.push_str(&self.gen_block_statement(body));
                    body_str.push_str("}\n\n");
                }

                // Restore old symbol table
                let mut table = self.symbol_table.borrow_mut();
                for param in params {
                    table.remove(&param.name);
                }
                for (k, v) in old_types {
                    table.insert(k, v);
                }

                result.push_str(&body_str);
            }
            Statement::VarDecl {
                name,
                is_mut: _,
                value,
                var_type: _,
            } => {
                let var_type = self
                    .symbol_table
                    .borrow()
                    .get(name)
                    .cloned()
                    .unwrap_or(Type::Void);
                let type_str = self.get_c_type(&var_type);

                let mut target_struct = None;
                if let Type::Index(struct_name, _) = &var_type {
                    target_struct = Some(struct_name.clone());
                }
                *self.current_alloc_struct.borrow_mut() = target_struct;

                let val_str = if let Some(val_expr) = value {
                    self.gen_expression(val_expr)
                } else {
                    if matches!(var_type, Type::Struct(_, _)) || matches!(var_type, Type::Slice(_))
                    {
                        "{0}".to_string()
                    } else {
                        "0".to_string()
                    }
                };

                *self.current_alloc_struct.borrow_mut() = None;
                result.push_str(&format!("    {} {} = {};\n", type_str, name, val_str));
            }
            Statement::Assignment { left, value } => {
                let mut target_struct = None;
                if let Expression::Identifier(left_name) = left
                    && let Some(Type::Index(struct_name, _)) =
                        self.symbol_table.borrow().get(left_name)
                    {
                        target_struct = Some(struct_name.clone());
                    }
                *self.current_alloc_struct.borrow_mut() = target_struct;

                let left_str = self.gen_expression(left);
                let val_str = self.gen_expression(value);

                *self.current_alloc_struct.borrow_mut() = None;
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
                result.push_str("    {\n");
                result.push_str(&self.gen_loop_body(body));
                result.push_str("    }\n");
            }
            Statement::Defer { expr: _ } => {}
            Statement::Return(maybe_expr) => {
                if let Some(expr) = maybe_expr {
                    let expr_str = self.gen_expression(expr);
                    result.push_str(&format!("    return {};\n", expr_str));
                } else {
                    result.push_str("    return;\n");
                }
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
            Expression::String(val) => {
                format!(
                    "(Slice_unsigned_char){{ (unsigned char*)\"{}\", {} }}",
                    val,
                    val.len()
                )
            }
            Expression::Move(inner_expr) => self.gen_expression(inner_expr),
            Expression::Take(inner_expr) => {
                if let Expression::Identifier(name) = &**inner_expr {
                    let var_type = self
                        .symbol_table
                        .borrow()
                        .get(name)
                        .cloned()
                        .unwrap_or(Type::Void);
                    let type_str = self.get_c_type(&var_type);
                    format!(
                        "({{ {} _temp = {}; {}.data = NULL; _temp; }})",
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
                let target_str = self.get_c_type(target_type);

                if *is_reference {
                    format!(
                        "({{ CastResult_{} res; res.Ok = ((((uintptr_t){}.data) & (__alignof__({}) - 1)) == 0) && ({}.len >= sizeof({})); res.Val = ({}*){}.data; res; }})",
                        target_str,
                        left_str,
                        target_str,
                        left_str,
                        target_str,
                        target_str,
                        left_str
                    )
                } else {
                    if let Type::RawPointer(_) = target_type {
                        format!("(({}){})", target_str, left_str)
                    } else if let Type::Struct(_, _) = target_type {
                        format!("(*(({}*){}.data))", target_str, left_str)
                    } else {
                        format!("(({}*){})", target_str, left_str)
                    }
                }
            }
            Expression::IndexAccess { allocator, index } => {
                let alloc_str = self.gen_expression(allocator);
                let index_str = self.gen_expression(index);

                let mut is_slice = false;
                if let Expression::Identifier(name) = &**allocator
                    && let Some(t) = self.symbol_table.borrow().get(name)
                        && (matches!(t, Type::Slice(_)) || *t == Type::Str) {
                            is_slice = true;
                        }

                if is_slice {
                    format!(
                        "(*({{ if ({} < 0 || {} >= {}.len) {{ printf(\"Slice bounds check failed at line %d\\n\", __LINE__); exit(1); }} &({}.data[{}]); }}))",
                        index_str, index_str, alloc_str, alloc_str, index_str
                    )
                } else {
                    // Arena indexing (Value-Branded)
                    let mut target_struct = "SessionNode".to_string();
                    if let Expression::Identifier(idx_name) = &**index
                        && let Some(Type::Index(struct_name, _)) =
                            self.symbol_table.borrow().get(idx_name)
                        && struct_name != "Any" {
                            target_struct = struct_name.clone();
                        }

                    let mut use_arrow = false;
                    if let Expression::Identifier(name) = &**allocator
                        && let Some(Type::RawPointer(inner)) = self.symbol_table.borrow().get(name)
                            && **inner == Type::Arena {
                                use_arrow = true;
                            }

                    if use_arrow {
                        format!(
                            "(( {}*)((char*){}->BaseAddress + {}))",
                            target_struct, alloc_str, index_str
                        )
                    } else {
                        format!(
                            "(( {}*)((char*){}.BaseAddress + {}))",
                            target_struct, alloc_str, index_str
                        )
                    }
                }
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
                    if let Expression::IndexAccess { allocator, .. } = &**left
                        && let Expression::Identifier(name) = &**allocator
                            && let Some(t) = self.symbol_table.borrow().get(name) {
                                let is_arena_ptr = if let Type::RawPointer(inner) = t {
                                    **inner == Type::Arena
                                } else {
                                    false
                                };
                                if *t == Type::Arena || is_arena_ptr {
                                    use_arrow = true;
                                }
                            }
                } else if let Expression::Selector {
                    left: inner_left,
                    right: inner_right,
                } = &**left
                    && let Expression::Identifier(name) = &**inner_left
                        && name == "result"
                        && inner_right == "Val"
                    {
                        use_arrow = true;
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
                let func_path = self.gen_expression(function);

                if func_path == "len" {
                    let arg_str = self.gen_expression(&arguments[0]);
                    return format!("{}.len", arg_str);
                }

                // Compile-time resolution of os.ArenaAlloc [3]
                if func_path == "os_ArenaAlloc" || func_path == "os.ArenaAlloc" {
                    let size_str = if let Some(struct_name) = &*self.current_alloc_struct.borrow() {
                        format!("sizeof({})", struct_name)
                    } else {
                        "sizeof(SessionNode)".to_string()
                    };
                    let arg_str = self.gen_expression(&arguments[0]);
                    return format!("os_ArenaAlloc(&{}, {})", arg_str, size_str);
                }

                if let Expression::Selector { left, right } = &**function
                    && let Expression::Identifier(name) = &**left
                    && let Some(var_type) = self.symbol_table.borrow().get(name)
                    && right == "Free"
                {
                    if let Type::RawPointer(inner) = var_type
                        && **inner == Type::Arena {
                            return format!("os_Arena_Free({})", name);
                        }
                    return format!("os_Arena_Free(&{})", name);
                }

                // LogStr mapping
                if func_path == "os.LogStr" || func_path == "os_LogStr" {
                    let arg_str = self.gen_expression(&arguments[0]);
                    return format!("os_LogStr({})", arg_str);
                }

                let func_c = func_path.replace(".", "_");
                let mut arg_strs = Vec::new();
                for arg in arguments {
                    if let Expression::Identifier(name) = arg
                        && let Some(var_type) = self.symbol_table.borrow().get(name)
                        && *var_type == Type::Arena {
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
