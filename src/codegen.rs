use crate::ast::{BlockStatement, Expression, Program, Statement};
use crate::codegen_runtime;
use crate::typechecker::{FunctionSignature, StructLayout, Type, expression_to_string};
use std::cell::RefCell;
use std::collections::HashMap;

pub struct Codegen {
    symbol_table: RefCell<HashMap<String, Type>>,
    struct_registry: HashMap<String, StructLayout>,
    function_registry: HashMap<String, FunctionSignature>,
    enum_registry: HashMap<String, Vec<String>>, // Added enum registry to Codegen
    current_alloc_struct: RefCell<Option<String>>,
}

// Brand Erasure Helpers
fn erase_struct_name(name: &str, brand: &Option<String>) -> String {
    if let Some(b) = brand {
        let suffix = format!("_{}", b);
        if name.ends_with(&suffix) {
            return name[..name.len() - suffix.len()].to_string();
        }
    }
    name.to_string()
}

fn erase_type(t: &Type) -> Type {
    match t {
        Type::Struct(name, brand) => {
            let erased_name = erase_struct_name(name, brand);
            Type::Struct(erased_name, None)
        }
        Type::Index(struct_name, brand) => {
            let erased_struct = erase_struct_name(struct_name, brand);
            Type::Index(erased_struct, None)
        }
        Type::RawPointer(inner) => Type::RawPointer(Box::new(erase_type(inner))),
        Type::Slice(inner) => Type::Slice(Box::new(erase_type(inner))),
        Type::Generic(name, args) => {
            let erased_args: Vec<Type> = args.iter().map(erase_type).collect();
            Type::Generic(name.clone(), erased_args)
        }
        _ => t.clone(),
    }
}

impl Codegen {
    pub fn new(
        symbol_table: HashMap<String, Type>,
        struct_registry: HashMap<String, StructLayout>,
        function_registry: HashMap<String, FunctionSignature>,
        enum_registry: HashMap<String, Vec<String>>, // Added enum_registry parameter
    ) -> Self {
        // Step 1: Collapse struct layouts structurally via Brand Erasure
        let mut erased_struct_registry = HashMap::new();
        for (struct_name, layout) in &struct_registry {
            let erased_name = erase_struct_name(struct_name, &layout.brand);
            let mut erased_fields = HashMap::new();
            for (f_name, f_type) in &layout.fields {
                erased_fields.insert(f_name.clone(), erase_type(f_type));
            }
            erased_struct_registry.insert(
                erased_name,
                StructLayout {
                    brand: None,
                    fields: erased_fields,
                },
            );
        }

        // Step 2: Normalize variable typing boundaries
        let mut erased_symbol_table = HashMap::new();
        for (var_name, var_type) in symbol_table {
            erased_symbol_table.insert(var_name.clone(), erase_type(&var_type));
        }

        // Step 3: Align function boundaries
        let mut erased_function_registry = HashMap::new();
        for (func_name, sig) in &function_registry {
            let erased_params: Vec<Type> = sig.params.iter().map(erase_type).collect();
            let erased_return = erase_type(&sig.return_type);
            erased_function_registry.insert(
                func_name.clone(),
                FunctionSignature {
                    param_names: sig.param_names.clone(),
                    params: erased_params,
                    return_type: erased_return,
                    return_origins: sig.return_origins.clone(),
                },
            );
        }

        Codegen {
            symbol_table: RefCell::new(erased_symbol_table),
            struct_registry: erased_struct_registry,
            function_registry: erased_function_registry,
            enum_registry, // Saved here
            current_alloc_struct: RefCell::new(None),
        }
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

    fn get_type_ident(&self, t: &Type) -> String {
        match t {
            Type::Int => "int".to_string(),
            Type::Byte => "byte".to_string(),
            Type::Arena => "Arena".to_string(),
            Type::Void => "void".to_string(),
            Type::Str => "str".to_string(),
            Type::RawPointer(inner) => format!("{}_ptr", self.get_type_ident(inner)),
            Type::Slice(inner) => format!("Slice_{}", self.get_type_ident(inner)),
            Type::Struct(name, _) => name.clone(),
            Type::Index(name, _) => format!("Index_{}", name),
            _ => "unknown".to_string(),
        }
    }

    fn get_expr_type(&self, expr: &Expression) -> Option<Type> {
        match expr {
            Expression::Identifier(name) => self.symbol_table.borrow().get(name).cloned(),
            Expression::Selector { left, right } => {
                let left_type = self.get_expr_type(left)?;
                if let Type::Struct(struct_name, _) = left_type
                    && let Some(layout) = self.struct_registry.get(&struct_name)
                {
                    return layout.fields.get(right).cloned();
                }
                None
            }
            Expression::IndexAccess { allocator, .. } => {
                let alloc_type = self.get_expr_type(allocator)?;
                if let Type::Slice(elem_type) = alloc_type {
                    return Some(*elem_type);
                }
                if let Type::Struct(struct_name, _) = alloc_type {
                    if struct_name.starts_with("Vector_") {
                        if let Some(layout) = self.struct_registry.get(&struct_name)
                            && let Some(Type::RawPointer(inner)) = layout.fields.get("data")
                        {
                            return Some((**inner).clone());
                        }
                    } else if struct_name.starts_with("HashMap_")
                        && let Some(layout) = self.struct_registry.get(&struct_name)
                        && let Some(Type::RawPointer(inner)) = layout.fields.get("values")
                    {
                        return Some((**inner).clone());
                    }
                }
                None
            }
            _ => None,
        }
    }

    fn has_boolean_fields_recursive(
        &self,
        t: &Type,
        visited: &mut std::collections::HashSet<String>,
    ) -> bool {
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
            Type::Generic(_, args) => {
                for arg in args {
                    if self.has_boolean_fields_recursive(arg, visited) {
                        return true;
                    }
                }
                false
            }
            _ => false,
        }
    }

    fn has_boolean_fields(&self, t: &Type) -> bool {
        let mut visited = std::collections::HashSet::new();
        self.has_boolean_fields_recursive(t, &mut visited)
    }

    pub fn generate(&self, program: &Program) -> String {
        let mut c_code = String::new();

        c_code.push_str(codegen_runtime::CORE_HEADERS);
        c_code.push_str(codegen_runtime::ARENA_RUNTIME);

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

        c_code.push_str(codegen_runtime::MOCK_PAYLOAD_RUNTIME);
        c_code.push_str(codegen_runtime::FILE_IO_RUNTIME);
        c_code.push_str(codegen_runtime::COLLECTIONS_RUNTIME);

        c_code.push_str("// ====================================================\n");
        c_code.push_str("// DYNAMICALLY TRANSPILED USER STRUCTS\n");
        c_code.push_str("// ====================================================\n");

        // Sort structures: variants structs containing '_' must be output before Enums to satisfy C value-embedding complete-type rules
        let mut sorted_structs: Vec<(&String, &StructLayout)> =
            self.struct_registry.iter().collect();
        sorted_structs.sort_by(|a, b| {
            let a_has_underscore = a.0.contains('_');
            let b_has_underscore = b.0.contains('_');
            if a_has_underscore && !b_has_underscore {
                std::cmp::Ordering::Less
            } else if !a_has_underscore && b_has_underscore {
                std::cmp::Ordering::Greater
            } else {
                a.0.cmp(b.0)
            }
        });

        for (struct_name, layout) in sorted_structs {
            if let Some(variants) = self.enum_registry.get(struct_name) {
                // 1. Generate typedef enum for variant tags
                c_code.push_str("typedef enum {\n");
                for (idx, variant) in variants.iter().enumerate() {
                    c_code.push_str(&format!(
                        "    {}_Tag__{} = {},\n",
                        struct_name, variant, idx
                    ));
                }
                c_code.push_str(&format!("}} {}_Tag;\n\n", struct_name));

                // 2. Generate struct with anonymous union
                c_code.push_str(&format!("struct {} {{\n", struct_name));
                c_code.push_str("    int tag; \n");
                c_code.push_str("    union {\n");

                let mut sorted_variants = variants.clone();
                sorted_variants.sort();
                for variant in sorted_variants {
                    let field_type_name = format!("{}_{}", struct_name, variant);
                    c_code.push_str(&format!(
                        "        struct {} {};\n",
                        field_type_name, variant
                    ));
                }

                c_code.push_str("    };\n");
                c_code.push_str("};\n\n");

                c_code.push_str("typedef struct {\n");
                c_code.push_str(&format!("    {}* Val;\n", struct_name));
                c_code.push_str("    int Ok;\n");
                c_code.push_str(&format!("}} CastResult_{};\n\n", struct_name));
            } else {
                c_code.push_str(&format!("struct {} {{\n", struct_name));

                // Sort structural fields alphabetically for stable alignments
                let mut sorted_fields: Vec<(&String, &Type)> = layout.fields.iter().collect();
                sorted_fields.sort_by(|a, b| a.0.cmp(b.0));

                if sorted_fields.is_empty() {
                    c_code.push_str("    char dummy;\n"); // Standard portable dummy C99 member
                } else {
                    for (field_name, field_type) in sorted_fields {
                        let field_c_type = self.get_c_type(field_type);
                        c_code.push_str(&format!("    {} {};\n", field_c_type, field_name));
                    }
                }
                c_code.push_str("};\n\n");

                if !struct_name.starts_with("LookupResult_") {
                    c_code.push_str("typedef struct {\n");
                    c_code.push_str(&format!("    {}* Val;\n", struct_name));
                    c_code.push_str("    int Ok;\n");
                    c_code.push_str(&format!("}} CastResult_{};\n\n", struct_name));
                }
            }
        }

        c_code.push_str("// ====================================================\n");
        c_code.push_str("// INVARIANT VALIDATION HELPERS\n");
        c_code.push_str("// ====================================================\n");

        for (struct_name, layout) in &self.struct_registry {
            if self.has_boolean_fields(&Type::Struct(struct_name.clone(), None)) {
                c_code.push_str(&format!(
                    "int {}_IsValid(const {}* req) {{\n",
                    struct_name, struct_name
                ));
                c_code.push_str("    if (req == NULL) return 0;\n"); // Safety check

                // Sort structural fields alphabetically for deterministic validation code
                let mut sorted_fields: Vec<(&String, &Type)> = layout.fields.iter().collect();
                sorted_fields.sort_by(|a, b| a.0.cmp(b.0));

                for (field_name, field_type) in sorted_fields {
                    match field_type {
                        Type::Byte => {
                            c_code.push_str(&format!(
                                "    if (req->{} != 0x00 && req->{} != 0x01) return 0;\n",
                                field_name, field_name
                            ));
                        }
                        Type::Struct(nested_name, _)
                            if self.has_boolean_fields(field_type) => {
                                c_code.push_str(&format!(
                                    "    if (!{}_IsValid(&req->{})) return 0;\n",
                                    nested_name, field_name
                                ));
                            }
                        _ => {}
                    }
                }
                c_code.push_str("    return 1;\n");
                c_code.push_str("}\n\n");
            }
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
        let erased_t = erase_type(t);
        match erased_t {
            Type::Int => "int".to_string(),
            Type::Byte => "unsigned char".to_string(),
            Type::Void => "void".to_string(),
            Type::Arena => "os_Arena".to_string(),
            Type::ByteSlice => "Slice_unsigned_char".to_string(),
            Type::Slice(inner) => format!("Slice_{}", self.get_c_type_ident(&inner)),
            Type::Index(_, _) => "int".to_string(),
            Type::Struct(name, _) => name.clone(),
            Type::RawPointer(inner) => format!("{}*", self.get_c_type(&inner)),
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
            Statement::EnumDecl { .. } => {}
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
                } else if let Type::Struct(struct_name, _) = &var_type {
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
                let left_type = self.get_expr_type(left).unwrap_or(Type::Void);
                if let Type::Index(struct_name, _) = &left_type {
                    target_struct = Some(struct_name.clone());
                } else if let Type::Struct(struct_name, _) = &left_type {
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
            Statement::Match { expression, cases } => {
                let expr_str = self.gen_expression(expression);
                let expr_type = self.get_expr_type(expression).unwrap_or(Type::Void);

                let mut enum_name = "Shape".to_string();
                if let Type::Struct(name, _) = expr_type {
                    enum_name = name;
                }

                result.push_str(&format!("    switch ({}.tag) {{\n", expr_str));
                for case in cases {
                    // Look up the unique enum tag integer for this variant
                    let tag_val = if let Some(variants) = self.enum_registry.get(&enum_name) {
                        variants
                            .iter()
                            .position(|v| *v == case.variant_name)
                            .unwrap_or(0)
                    } else {
                        0
                    };

                    result.push_str(&format!("        case {}: {{\n", tag_val));
                    result.push_str(&self.gen_loop_body(&case.body));
                    result.push_str("            break;\n");
                    result.push_str("        }\n");
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
                let inner_str = self.gen_expression(inner);
                if inner_str.ends_with(".Val") {
                    inner_str
                } else {
                    format!("&({})", inner_str)
                }
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
                    if let Type::RawPointer(inner) = target_type {
                        format!(
                            "(({}){})",
                            self.get_c_type(&Type::RawPointer(inner.clone())),
                            left_str
                        )
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

                let alloc_type = self.get_expr_type(allocator).unwrap_or(Type::Void);
                let is_slice = matches!(alloc_type, Type::Slice(_)) || alloc_type == Type::Str;

                let mut is_vector = false;
                let mut is_hashmap = false;
                let mut is_str_key = false;

                if let Type::Struct(struct_name, _) = &alloc_type {
                    if struct_name.starts_with("Vector_") {
                        is_vector = true;
                    } else if struct_name.starts_with("HashMap_") {
                        is_hashmap = true;
                        if let Some(layout) = self.struct_registry.get(struct_name)
                            && let Some(Type::RawPointer(k_inner)) = layout.fields.get("keys")
                            && **k_inner == Type::Str
                        {
                            is_str_key = true;
                        }
                    }
                } else {
                    // Fallback to checking the allocator variable name in symbol table directly
                    let alloc_ident = expression_to_string(allocator);
                    if let Some(Type::Struct(struct_name, _)) =
                        self.symbol_table.borrow().get(&alloc_ident)
                    {
                        if struct_name.starts_with("Vector_") {
                            is_vector = true;
                        } else if struct_name.starts_with("HashMap_") {
                            is_hashmap = true;
                            if let Some(layout) = self.struct_registry.get(struct_name)
                                && let Some(Type::RawPointer(k_inner)) = layout.fields.get("keys")
                                && **k_inner == Type::Str
                            {
                                is_str_key = true;
                            }
                        }
                    }
                }

                if is_slice {
                    format!(
                        "(*({{ if ({} < 0 || {} >= {}.len) {{ printf(\"Slice bounds check failed at line %d\\n\", __LINE__); exit(1); }} &({}.data[{}]); }}))",
                        index_str, index_str, alloc_str, alloc_str, index_str
                    )
                } else if is_vector {
                    format!(
                        "(*({{ if ({} < 0 || {} >= {}.len) {{ printf(\"Vector bounds check failed at line %d\\n\", __LINE__); exit(1); }} &({}.data[{}]); }}))",
                        index_str, index_str, alloc_str, alloc_str, index_str
                    )
                } else if is_hashmap {
                    let is_str_key_str = if is_str_key { "1" } else { "0" };
                    format!(
                        "(*os_HashMapRef(&{}, {}, {}))",
                        alloc_str, index_str, is_str_key_str
                    )
                } else {
                    // Arena indexing (Value-Branded)
                    let mut target_struct = "SessionNode".to_string();
                    if let Expression::Identifier(idx_name) = &**index
                        && let Some(Type::Index(struct_name, _)) =
                            self.symbol_table.borrow().get(idx_name)
                        && struct_name != "Any"
                    {
                        target_struct = struct_name.clone();
                    }

                    let mut use_arrow = false;
                    if let Expression::Identifier(name) = &**allocator
                        && let Some(Type::RawPointer(inner)) = self.symbol_table.borrow().get(name)
                        && **inner == Type::Arena
                    {
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
                        && let Some(t) = self.symbol_table.borrow().get(name)
                    {
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
                    let mut is_coll = false;
                    let arg_type = self.get_expr_type(&arguments[0]).unwrap_or(Type::Void);
                    if let Type::Struct(struct_name, _) = &arg_type {
                        if struct_name.starts_with("Vector_") || struct_name.starts_with("HashMap_")
                        {
                            is_coll = true;
                        }
                    } else {
                        let arg_ident = expression_to_string(&arguments[0]);
                        if let Some(Type::Struct(struct_name, _)) =
                            self.symbol_table.borrow().get(&arg_ident)
                            && (struct_name.starts_with("Vector_")
                                || struct_name.starts_with("HashMap_"))
                        {
                            is_coll = true;
                        }
                    }
                    if is_coll {
                        return format!("{}.len", arg_str);
                    }
                    return format!("{}.len", arg_str);
                }

                // Compile-time resolution of os_ArenaAlloc [3]
                if func_path == "os_ArenaAlloc" || func_path == "os.ArenaAlloc" {
                    let size_str = if let Some(struct_name) = &*self.current_alloc_struct.borrow() {
                        struct_name.clone()
                    } else {
                        "sizeof(SessionNode)".to_string()
                    };
                    let arg_str = self.gen_expression(&arguments[0]);
                    return format!("os_ArenaAlloc(&{}, sizeof({}))", arg_str, size_str);
                }

                // os.VectorNew
                if func_path == "os.VectorNew" || func_path == "os_VectorNew" {
                    let arg_str = self.gen_expression(&arguments[0]);
                    let type_str = if let Some(struct_name) = &*self.current_alloc_struct.borrow() {
                        struct_name.clone()
                    } else {
                        "Vector_int".to_string()
                    };
                    let mut is_ptr = false;
                    if let Expression::Identifier(name) = &arguments[0]
                        && let Some(Type::RawPointer(inner)) = self.symbol_table.borrow().get(name)
                        && **inner == Type::Arena
                    {
                        is_ptr = true;
                    }
                    let arena_expr = if is_ptr {
                        arg_str
                    } else {
                        format!("&{}", arg_str)
                    };
                    return format!(
                        "(struct {}){{ .data = NULL, .len = 0, .capacity = 0, .arena = {} }}",
                        type_str, arena_expr
                    );
                }

                // os.HashMapNew
                if func_path == "os.HashMapNew" || func_path == "os_HashMapNew" {
                    let arg_str = self.gen_expression(&arguments[0]);
                    let type_str = if let Some(struct_name) = &*self.current_alloc_struct.borrow() {
                        struct_name.clone()
                    } else {
                        "HashMap_int_int".to_string()
                    };
                    let mut is_ptr = false;
                    if let Expression::Identifier(name) = &arguments[0]
                        && let Some(Type::RawPointer(inner)) = self.symbol_table.borrow().get(name)
                        && **inner == Type::Arena
                    {
                        is_ptr = true;
                    }
                    let arena_expr = if is_ptr {
                        arg_str
                    } else {
                        format!("&{}", arg_str)
                    };
                    return format!(
                        "(struct {}){{ .keys = NULL, .values = NULL, .occupied = NULL, .len = 0, .capacity = 0, .arena = {} }}",
                        type_str, arena_expr
                    );
                }

                // os.ReadFile
                if func_path == "os.ReadFile" || func_path == "os_ReadFile" {
                    let arg_arena = self.gen_expression(&arguments[0]);
                    let arg_path = self.gen_expression(&arguments[1]);

                    let mut is_ptr = false;
                    if let Expression::Identifier(name) = &arguments[0]
                        && let Some(Type::RawPointer(inner)) = self.symbol_table.borrow().get(name)
                        && **inner == Type::Arena
                    {
                        is_ptr = true;
                    }
                    let arena_expr = if is_ptr {
                        arg_arena
                    } else {
                        format!("&{}", arg_arena)
                    };
                    return format!("os_ReadFile({}, {})", arena_expr, arg_path);
                }

                // os.WriteFile
                if func_path == "os.WriteFile" || func_path == "os_WriteFile" {
                    let arg_path = self.gen_expression(&arguments[0]);
                    let arg_contents = self.gen_expression(&arguments[1]);
                    return format!("os_WriteFile({}, {})", arg_path, arg_contents);
                }

                if let Expression::Selector { left, right } = &**function {
                    let left_str = self.gen_expression(left);

                    let mut is_vec = false;
                    let mut is_map = false;
                    let left_type = self.get_expr_type(left).unwrap_or(Type::Void);

                    if let Type::Struct(struct_name, _) = &left_type {
                        if struct_name.starts_with("Vector_") {
                            is_vec = true;
                        } else if struct_name.starts_with("HashMap_") {
                            is_map = true;
                        }
                    } else {
                        let left_ident = expression_to_string(left);
                        if let Some(Type::Struct(struct_name, _)) =
                            self.symbol_table.borrow().get(&left_ident)
                        {
                            if struct_name.starts_with("Vector_") {
                                is_vec = true;
                            } else if struct_name.starts_with("HashMap_") {
                                is_map = true;
                            }
                        }
                    }

                    if is_vec && right == "Push" {
                        let arg_str = self.gen_expression(&arguments[0]);
                        return format!("os_VectorPush(&{}, {})", left_str, arg_str);
                    }
                    if is_map && right == "Insert" {
                        let k_str = self.gen_expression(&arguments[0]);
                        let v_str = self.gen_expression(&arguments[1]);
                        let mut is_str_key = false;
                        let left_ident = expression_to_string(left);
                        if let Some(Type::Struct(struct_name, _)) =
                            self.symbol_table.borrow().get(&left_ident)
                        {
                            is_str_key = self
                                .get_hashmap_key_value_types(struct_name)
                                .map(|(k, _)| k == Type::Str)
                                .unwrap_or(false);
                        }
                        let is_str_key_str = if is_str_key { "1" } else { "0" };
                        return format!(
                            "*os_HashMapRef(&{}, {}, {}) = {}",
                            left_str, k_str, is_str_key_str, v_str
                        );
                    }
                    if is_map && right == "Get" {
                        let k_str = self.gen_expression(&arguments[0]);
                        let mut is_str_key = false;
                        let mut lookup_struct = "LookupResult_int".to_string();
                        let left_ident = expression_to_string(left);
                        if let Some(Type::Struct(struct_name, _)) =
                            self.symbol_table.borrow().get(&left_ident)
                            && let Some((k, v)) = self.get_hashmap_key_value_types(struct_name) {
                                is_str_key = k == Type::Str;
                                lookup_struct = format!("LookupResult_{}", self.get_type_ident(&v));
                            }
                        let is_str_key_str = if is_str_key { "1" } else { "0" };
                        return format!(
                            "({{ {} res = {{0}}; res.Ok = os_HashMapContains(&{}, {}, {}); if (res.Ok) {{ res.Val = *os_HashMapRef(&{}, {}, {}); }} res; }})",
                            lookup_struct,
                            left_str,
                            k_str,
                            is_str_key_str,
                            left_str,
                            k_str,
                            is_str_key_str
                        );
                    }

                    let left_type_str = expression_to_string(left);
                    if let Some(var_type) = self.symbol_table.borrow().get(&left_type_str)
                        && *var_type == Type::Arena
                        && right == "Free"
                    {
                        return format!("os_Arena_Free(&{})", left_type_str);
                    }
                }

                let func_c = func_path.replace(".", "_");
                let mut arg_strs = Vec::new();
                for arg in arguments {
                    if let Expression::Identifier(name) = arg
                        && let Some(var_type) = self.symbol_table.borrow().get(name)
                        && *var_type == Type::Arena
                    {
                        arg_strs.push(format!("&{}", name));
                        continue;
                    }
                    arg_strs.push(self.gen_expression(arg));
                }
                format!("{}({})", func_c, arg_strs.join(", "))
            }
            Expression::Empty(target_type) => {
                let c_type = self.get_c_type(target_type);
                // Lower to standard (T){0} compound literal for standard initialization
                format!("(({}){{0}})", c_type)
            }
        }
    }
}
