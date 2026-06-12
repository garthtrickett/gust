use crate::ast::{BlockStatement, Expression, Program, Statement};
use crate::codegen_runtime;
use crate::typechecker::{FunctionSignature, StructLayout, Type, expression_to_string};
use std::cell::RefCell;
use std::collections::HashMap;

pub struct Codegen {
    symbol_table: RefCell<HashMap<String, Type>>,
    original_symbol_table: HashMap<String, Type>,
    struct_registry: HashMap<String, StructLayout>,
    function_registry: HashMap<String, FunctionSignature>,
    enum_registry: HashMap<String, Vec<String>>, // Added enum registry to Codegen
    current_alloc_struct: RefCell<Option<String>>,
    current_function: RefCell<Option<String>>,
    pub resolved_names: HashMap<crate::token::Span, String>,
    pub resolved_types: HashMap<crate::token::Span, Type>,
}

// Brand Erasure Helpers
fn erase_struct_name_with_registry(
    name: &str,
    brand: &Option<String>,
    registry: &HashMap<String, StructLayout>,
) -> String {
    let mut actual_brand = brand.clone();
    if actual_brand.is_none()
        && let Some(layout) = registry.get(name)
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

fn erase_type_with_registry(t: &Type, registry: &HashMap<String, StructLayout>) -> Type {
    match t {
        Type::Struct(name, brand) => {
            let erased_name = erase_struct_name_with_registry(name, brand, registry);
            Type::Struct(erased_name, None)
        }
        Type::Index(struct_name, brand) => {
            let erased_struct = erase_struct_name_with_registry(struct_name, brand, registry);
            Type::Index(erased_struct, None)
        }
        Type::RawPointer(inner) => {
            Type::RawPointer(Box::new(erase_type_with_registry(inner, registry)))
        }
        Type::Slice(inner) => Type::Slice(Box::new(erase_type_with_registry(inner, registry))),
        Type::Generic(name, args) => {
            let erased_args: Vec<Type> = args
                .iter()
                .map(|arg| erase_type_with_registry(arg, registry))
                .collect();
            Type::Generic(name.clone(), erased_args)
        }
        _ => t.clone(),
    }
}

fn get_by_value_dependencies(
    t: &Type,
    deps: &mut std::collections::HashSet<String>,
    struct_registry: &HashMap<String, StructLayout>,
) {
    match t {
        Type::Struct(name, _) => {
            if struct_registry.contains_key(name)
                && deps.insert(name.clone())
                && let Some(layout) = struct_registry.get(name)
            {
                for field_type in layout.fields.values() {
                    get_by_value_dependencies(field_type, deps, struct_registry);
                }
            }
        }
        Type::Generic(_, args) => {
            for arg in args {
                get_by_value_dependencies(arg, deps, struct_registry);
            }
        }
        Type::Slice(inner) => {
            get_by_value_dependencies(inner, deps, struct_registry);
        }
        _ => {}
    }
}

impl Codegen {
    fn find_wrapper_type(&self, val_type: &Type) -> String {
        for (struct_name, layout) in &self.struct_registry {
            if let Some(ok_t) = layout.fields.get("Ok")
                && let Some(val_t) = layout.fields.get("Val")
                    && (*ok_t == Type::Int || *ok_t == Type::Bool) && self.get_c_type(val_t) == self.get_c_type(val_type) {
                        return struct_name.clone();
                    }
        }
        "LookupResult_int".to_string()
    }

    pub fn get_c_type(&self, t: &Type) -> String {
        let erased_t = erase_type_with_registry(t, &self.struct_registry);
        match erased_t {
            Type::Int => "int".to_string(),
            Type::Byte => "unsigned char".to_string(),
            Type::Bool => "unsigned char".to_string(),
            Type::Void => "void".to_string(),
            Type::Arena => "os_Arena".to_string(),
            Type::ByteSlice => "Slice_unsigned_char".to_string(),
            Type::Slice(inner) => format!("Slice_{}", self.get_c_type_ident(&inner)),
            Type::Index(_, _) => "int".to_string(),
            Type::Struct(name, _) => name.clone(),
            Type::RawPointer(inner) => format!("{}*", self.get_c_type(&inner)),
            Type::Generic(name, args) => self.get_monomorphized_name(&name, &args),
            Type::Str => "Slice_unsigned_char".to_string(),
        }
    }

    pub fn get_c_type_ident(&self, t: &Type) -> String {
        self.get_c_type(t).replace(" ", "_").replace("*", "_ptr")
    }

    pub(crate) fn get_monomorphized_name(&self, template_name: &str, args: &[Type]) -> String {
        let arg_names: Vec<String> = args.iter().map(|arg| self.get_type_ident(arg)).collect();
        let name = format!("{}_{}", template_name, arg_names.join("_"));
        name.replace(".", "_")
    }

    pub fn gen_type_aware_initializer(&self, t: &Type) -> String {
        let erased_t = erase_type_with_registry(t, &self.struct_registry);
        match erased_t {
            Type::Int | Type::Byte | Type::Bool => "0".to_string(),
            Type::Void => "".to_string(),
            Type::Arena => "{0}".to_string(),
            Type::RawPointer(_) => "NULL".to_string(),
            Type::Str | Type::Slice(_) | Type::ByteSlice => "{ NULL, 0 }".to_string(),
            Type::Index(_, _) => "0xFFFFFFFF".to_string(),
            Type::Struct(name, _) => {
                if self.enum_registry.contains_key(&name) {
                    // For enums, only initialize the tag field to avoid C union initialization warnings
                    format!("(({}){{ .tag = 0 }})", name)
                } else if let Some(layout) = self.struct_registry.get(&name) {
                    let mut fields_init = Vec::new();
                    let mut sorted_fields: Vec<(&String, &Type)> = layout.fields.iter().collect();
                    sorted_fields.sort_by(|a, b| a.0.cmp(b.0));
                    for (field_name, field_type) in sorted_fields {
                        fields_init.push(format!(
                            ".{} = {}",
                            field_name,
                            self.gen_type_aware_initializer(field_type)
                        ));
                    }
                    format!("(({}){{ {} }})", name, fields_init.join(", "))
                } else {
                    "{0}".to_string()
                }
            }
            Type::Generic(name, args) => {
                let concrete_name = self.get_monomorphized_name(&name, &args);
                self.gen_type_aware_initializer(&Type::Struct(concrete_name, None))
            }
        }
    }

    fn is_linear(&self, t: &Type) -> bool {
        let mut visited = std::collections::HashSet::new();
        self.is_linear_impl(t, &mut visited)
    }

    fn is_linear_impl(&self, t: &Type, visited: &mut std::collections::HashSet<String>) -> bool {
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

    pub fn new(
        symbol_table: HashMap<String, Type>,
        struct_registry: HashMap<String, StructLayout>,
        function_registry: HashMap<String, FunctionSignature>,
        enum_registry: HashMap<String, Vec<String>>, // Added enum_registry parameter
        resolved_names: HashMap<crate::token::Span, String>,
        resolved_types: HashMap<crate::token::Span, Type>,
    ) -> Self {
        // Step 1: Collapse struct layouts structurally via Brand Erasure
        let mut erased_struct_registry = HashMap::new();
        for (struct_name, layout) in &struct_registry {
            let erased_name =
                erase_struct_name_with_registry(struct_name, &layout.brand, &struct_registry);
            let mut erased_fields = HashMap::new();
            for (f_name, f_type) in &layout.fields {
                erased_fields.insert(
                    f_name.clone(),
                    erase_type_with_registry(f_type, &struct_registry),
                );
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
        let original_symbol_table = symbol_table.clone();
        for (var_name, var_type) in symbol_table {
            erased_symbol_table.insert(
                var_name.clone(),
                erase_type_with_registry(&var_type, &struct_registry),
            );
        }

        // Step 3: Align function boundaries
        let mut erased_function_registry = HashMap::new();
        for (func_name, sig) in &function_registry {
            let erased_params: Vec<Type> = sig
                .params
                .iter()
                .map(|param| erase_type_with_registry(param, &struct_registry))
                .collect();
            let erased_return = erase_type_with_registry(&sig.return_type, &struct_registry);
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
            original_symbol_table,
            struct_registry: erased_struct_registry,
            function_registry: erased_function_registry,
            enum_registry, // Saved here
            current_alloc_struct: RefCell::new(None),
            current_function: RefCell::new(None),
            resolved_names,
            resolved_types,
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
        let base = match t {
            Type::Int => "int".to_string(),
            Type::Byte => "byte".to_string(),
            Type::Bool => "bool".to_string(),
            Type::Arena => "Arena".to_string(),
            Type::Void => "void".to_string(),
            Type::Str => "str".to_string(),
            Type::RawPointer(inner) => format!("{}_ptr", self.get_type_ident(inner)),
            Type::Slice(inner) => format!("Slice_{}", self.get_type_ident(inner)),
            Type::Struct(name, _) => name.clone(),
            Type::Index(name, _) => format!("Index_{}", name),
            Type::Generic(name, args) => self.get_monomorphized_name(name, args),
            _ => "unknown".to_string(),
        };
        base.replace(".", "_")
    }

    fn get_expr_type(&self, expr: &Expression) -> Option<Type> {
        match expr {
            Expression::Identifier(name, _) => self.symbol_table.borrow().get(name).cloned(),
            Expression::Dereference(inner, _) => {
                let inner_type = self.get_expr_type(inner)?;
                if let Type::RawPointer(target_type) = inner_type {
                    Some(*target_type)
                } else {
                    None
                }
            }
            Expression::AddressOf(inner, _) => {
                let inner_type = self.get_expr_type(inner)?;
                Some(Type::RawPointer(Box::new(inner_type)))
            }
            Expression::AsCast { target_type, .. } => Some(target_type.clone()),
            Expression::Selector { left, right, .. } => {
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
                    if struct_name.starts_with("Vector_") || struct_name.starts_with("std_Vector_")
                    {
                        if let Some(layout) = self.struct_registry.get(&struct_name)
                            && let Some(Type::RawPointer(inner)) = layout.fields.get("data")
                        {
                            return Some((**inner).clone());
                        }
                    } else if (struct_name.starts_with("HashMap_")
                        || struct_name.starts_with("std_HashMap_"))
                        && let Some(layout) = self.struct_registry.get(&struct_name)
                        && let Some(Type::RawPointer(inner)) = layout.fields.get("values")
                    {
                        return Some((**inner).clone());
                    } else if (struct_name.starts_with("Pool_")
                        || struct_name.starts_with("std_Pool_"))
                        && let Some(layout) = self.struct_registry.get(&struct_name)
                        && let Some(Type::RawPointer(inner)) = layout.fields.get("data")
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
        c_code.push_str(codegen_runtime::SCRATCH_RUNTIME);

        c_code.push_str("// ====================================================\n");
        c_code.push_str("// FORWARD DECLARATIONS\n");
        c_code.push_str("// ====================================================\n");
        for struct_name in self.struct_registry.keys() {
            if struct_name == "std_Vector_str"
                || struct_name == "os_Dir"
                || struct_name == "os_DirEntry"
                || struct_name == "LookupResult_os_Dir"
                || struct_name == "LookupResult_os_DirEntry"
            {
                continue;
            }
            c_code.push_str(&format!(
                "typedef struct {} {};\n",
                struct_name, struct_name
            ));
        }
        c_code.push('\n');

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

        c_code.push_str("// ====================================================\n");
        c_code.push_str("// DYNAMICALLY GENERATED SLICE STRUCTURE FORWARD DECLARATIONS\n");
        c_code.push_str("// ====================================================\n");
        for elem_type in &slice_element_types {
            let elem_ident = self.get_c_type_ident(elem_type);
            c_code.push_str(&format!(
                "typedef struct Slice_{} Slice_{};\n",
                elem_ident, elem_ident
            ));
        }
        c_code.push('\n');

        c_code.push_str("// ====================================================\n");
        c_code.push_str("// DYNAMICALLY GENERATED SLICE STRUCTURES\n");
        c_code.push_str("// ====================================================\n");

        for elem_type in &slice_element_types {
            let elem_c = self.get_c_type(elem_type);
            let elem_ident = self.get_c_type_ident(elem_type);
            c_code.push_str(&format!("struct Slice_{} {{\n", elem_ident));
            c_code.push_str(&format!("    {}* data;\n", elem_c));
            c_code.push_str("    int len;\n");
            c_code.push_str("};\n\n");
        }

        c_code.push_str(codegen_runtime::MOCK_PAYLOAD_RUNTIME);
        c_code.push_str(codegen_runtime::FILE_IO_RUNTIME);
        c_code.push_str(codegen_runtime::COLLECTIONS_RUNTIME);

        c_code.push_str("// ====================================================\n");
        c_code.push_str("// FUNCTION FORWARD DECLARATIONS\n");
        c_code.push_str("// ====================================================\n");
        for (func_name, sig) in &self.function_registry {
            if func_name == "main" {
                continue;
            }
            // Skip forward declarations for compiler-intrinsic helper functions that are compiled to macros or inline initializers
            if func_name == "std.Clone"
                || func_name == "std_Clone"
                || func_name == "std.GenerationalSwap"
                || func_name == "std_GenerationalSwap"
                || func_name == "std.PoolNew"
                || func_name == "std_PoolNew"
                || func_name == "os.PoolNew"
                || func_name == "os_PoolNew"
                || func_name == "std.VectorNew"
                || func_name == "std_VectorNew"
                || func_name == "os.VectorNew"
                || func_name == "os_VectorNew"
                || func_name == "std.HashMapNew"
                || func_name == "std_HashMapNew"
                || func_name == "os.HashMapNew"
                || func_name == "os_HashMapNew"
                || func_name == "std.GraphNew"
                || func_name == "std_GraphNew"
                || func_name == "os.ArenaAlloc"
                || func_name == "os_ArenaAlloc"
                || func_name == "os.ScratchAlloc"
                || func_name == "os_ScratchAlloc"
                || func_name == "os.ScratchReset"
                || func_name == "os_ScratchReset"
                || func_name == "std.FormatInt"
                || func_name == "std_FormatInt"
                || func_name == "std.Concat"
                || func_name == "std_Concat"
                || func_name == "std.MutexNew"
                || func_name == "std_MutexNew"
                || func_name == "std.ChannelNew"
                || func_name == "std_ChannelNew"
                || func_name == "os.Args"
                || func_name == "os_Args"
                || func_name == "os.Exit"
                || func_name == "os_Exit"
                || func_name == "os.ReadFile"
                || func_name == "os_ReadFile"
                || func_name == "os.WriteFile"
                || func_name == "os_WriteFile"
                || func_name == "os.LogInt"
                || func_name == "os_LogInt"
                || func_name == "os.LogStr"
                || func_name == "os_LogStr"
                || func_name == "os.MockPayload"
                || func_name == "os_MockPayload"
                || func_name == "std.str_eq"
                || func_name == "std_str_eq"
                || func_name == "std.str_slice"
                || func_name == "std_str_slice"
                || func_name == "std.str_byte_at"
                || func_name == "std_str_byte_at"
                || func_name == "std.str_find"
                || func_name == "std_str_find"
                || func_name == "std.str_trim"
                || func_name == "std_str_trim"
                || func_name == "std.Spawn"
                || func_name == "std_Spawn"
                || func_name == "std.is_alpha"
                || func_name == "std_is_alpha"
                || func_name == "std.is_digit"
                || func_name == "std_is_digit"
                || func_name == "std.is_whitespace"
                || func_name == "std_is_whitespace"
                || func_name == "std.parse_int"
                || func_name == "std_parse_int"
            {
                continue;
            }
            let ret_str = self.get_c_type(&sig.return_type);
            let mut param_strs = Vec::new();
            for (i, param_type) in sig.params.iter().enumerate() {
                let param_type_str = self.get_c_type(param_type);
                let name = &sig.param_names[i];
                let is_arena_ptr = if let Type::RawPointer(inner) = param_type {
                    **inner == Type::Arena
                } else {
                    false
                };
                if is_arena_ptr || matches!(param_type, Type::Arena) {
                    param_strs.push(format!("os_Arena* {}", name));
                } else {
                    param_strs.push(format!("{} {}", param_type_str, name));
                }
            }
            let param_list = if param_strs.is_empty() {
                "void".to_string()
            } else {
                param_strs.join(", ")
            };
            let decl_name = func_name.replace(".", "_");
            c_code.push_str(&format!("{} {}({});\n", ret_str, decl_name, param_list));
            if sig.params.len() == 1 {
                c_code.push_str(&format!("void* {}_pthread_wrapper(void* arg);\n", decl_name));
            }
        }
        c_code.push('\n');
        c_code.push_str("// ====================================================\n");
        c_code.push_str("// DYNAMICALLY TRANSPILED USER STRUCTS\n");
        c_code.push_str("// ====================================================\n");

        // Topologically sort structs based on value-embedding dependency requirements
        let mut ordered_struct_names = Vec::new();
        let mut visited = std::collections::HashSet::new();
        let mut temp_visited = std::collections::HashSet::new();

        fn visit(
            name: &str,
            visited: &mut std::collections::HashSet<String>,
            temp_visited: &mut std::collections::HashSet<String>,
            ordered: &mut Vec<String>,
            registry: &HashMap<String, StructLayout>,
        ) {
            if visited.contains(name) {
                return;
            }
            if temp_visited.contains(name) {
                return; // Prevent infinite loop in case of cyclic structural dependencies
            }
            temp_visited.insert(name.to_string());

            if let Some(layout) = registry.get(name) {
                let mut deps = std::collections::HashSet::new();
                for field_type in layout.fields.values() {
                    get_by_value_dependencies(field_type, &mut deps, registry);
                }
                let mut sorted_deps: Vec<String> = deps.into_iter().collect();
                sorted_deps.sort();

                for dep in sorted_deps {
                    visit(&dep, visited, temp_visited, ordered, registry);
                }
            }

            temp_visited.remove(name);
            visited.insert(name.to_string());
            ordered.push(name.to_string());
        }

        let mut all_structs: Vec<String> = self.struct_registry.keys().cloned().collect();
        all_structs.sort();

        for name in &all_structs {
            visit(
                name,
                &mut visited,
                &mut temp_visited,
                &mut ordered_struct_names,
                &self.struct_registry,
            );
        }

        // Forward declare all CastResult structures first to prevent any ordering issues
        for struct_name in &ordered_struct_names {
            if struct_name == "os_Dir" || struct_name == "os_DirEntry" {
                continue;
            }
            if !struct_name.starts_with("LookupResult_") && !struct_name.starts_with("CastResult_") {
                c_code.push_str(&format!( 
                    "typedef struct CastResult_{} CastResult_{};\n",
                    struct_name, struct_name
                ));
            }
        }
        c_code.push('\n');

        for struct_name in &ordered_struct_names {
            if struct_name == "std_Vector_str"
                || struct_name == "os_Dir"
                || struct_name == "os_DirEntry"
                || struct_name == "LookupResult_os_Dir"
                || struct_name == "LookupResult_os_DirEntry"
                || struct_name.starts_with("CastResult_")
            {
                continue;
            }
            let layout = &self.struct_registry[struct_name];
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

                c_code.push_str(&format!("struct CastResult_{} {{\n", struct_name));
                c_code.push_str(&format!("    {}* Val;\n", struct_name));
                c_code.push_str("    int Ok;\n");
                c_code.push_str("};\n\n");
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

                if !struct_name.starts_with("LookupResult_") && !struct_name.starts_with("CastResult_") {
                    c_code.push_str(&format!("struct CastResult_{} {{\n", struct_name));
                    c_code.push_str(&format!("    {}* Val;\n", struct_name));
                    c_code.push_str("    int Ok;\n");
                    c_code.push_str("};\n\n");
                }
            }
        }

        c_code.push_str("// ====================================================\n");
        c_code.push_str("// INVARIANT VALIDATION HELPERS\n");
        c_code.push_str("// ====================================================\n");

        for (struct_name, layout) in &self.struct_registry {
            if struct_name == "os_Dir"
                || struct_name == "os_DirEntry"
                || struct_name == "LookupResult_os_Dir"
                || struct_name == "LookupResult_os_DirEntry"
                || struct_name.starts_with("CastResult_")
                || struct_name.starts_with("LookupResult_")
            {
                continue;
            }
            if self.has_boolean_fields(&Type::Struct(struct_name.clone(), None)) {
                c_code.push_str(&format!( 
                    "int {}_IsValid({}* req) {{\n",
                    struct_name, struct_name
                ));
                c_code.push_str("    if (req == NULL) return 0;\n"); // Safety check

                // Sort structural fields alphabetically for deterministic validation code
                let mut sorted_fields: Vec<(&String, &Type)> = layout.fields.iter().collect();
                sorted_fields.sort_by(|a, b| a.0.cmp(b.0));

                for (field_name, field_type) in sorted_fields {
                    match field_type {
                        Type::Byte | Type::Bool => {
                            c_code.push_str(&format!(
                                "    if (req->{} != 0x00 && req->{} != 0x01) return 0;\n",
                                field_name, field_name
                            ));
                        }
                        Type::Struct(nested_name, _) if self.has_boolean_fields(field_type) => {
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

    fn gen_statement(&self, stmt: &Statement) -> String {
        let mut result = String::new();
        match stmt {
            Statement::Import { .. } => {}
            Statement::StructDecl { .. } => {}
            Statement::EnumDecl { .. } => {}
            Statement::FunctionDecl {
                name,
                params,
                return_type: _,
                body,
                span,
                ..
            } => {
                let resolved_name = self
                    .resolved_names
                    .get(span)
                    .cloned()
                    .unwrap_or_else(|| name.clone());
                let sig = self.function_registry.get(&resolved_name).cloned();

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
                    *self.current_function.borrow_mut() = Some("main".to_string());
                    body_str.push_str("int main(int argc, char** argv) {\n");
                    body_str.push_str("    os_argc = argc;\n");
                    body_str.push_str("    os_argv = argv;\n");
                    body_str.push_str(&self.gen_block_statement(body));
                    body_str.push_str("    return 0;\n");
                    body_str.push_str("}\n\n");
                    *self.current_function.borrow_mut() = None;
                } else {
                    *self.current_function.borrow_mut() = Some(resolved_name.clone());
                    body_str.push_str(&format!( 
                        "{} {}({}) {{\n",
                        ret_str, resolved_name, param_list
                    ));
                    body_str.push_str(&self.gen_block_statement(body));
                    body_str.push_str("}\n\n");
                    *self.current_function.borrow_mut() = None;

                    if params.len() == 1 {
                        let param = &params[0];
                        let resolved_param_type = if let Some(ref s) = sig {
                            s.params[0].clone()
                        } else {
                            param.param_type.clone()
                        };
                        let param_type_str = self.get_c_type(&resolved_param_type);
                        let is_ptr = matches!(resolved_param_type, Type::RawPointer(_));
                        let is_struct = matches!(resolved_param_type, Type::Struct(_, _)) || matches!(resolved_param_type, Type::Generic(_, _));
                        let cast_str = if is_ptr {
                            format!("({})arg", param_type_str)
                        } else if is_struct {
                            format!("*({}*)arg", param_type_str)
                        } else {
                            format!("({})(uintptr_t)arg", param_type_str)
                        };

                        body_str.push_str(&format!( 
                            "void* {}_pthread_wrapper(void* arg) {{\n",
                            resolved_name
                        ));
                        body_str.push_str(&format!(
                            "    {}({});\n",
                            resolved_name, cast_str
                        ));
                        body_str.push_str("    return NULL;\n");
                        body_str.push_str("}\n\n");
                    }
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
                ..
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
                    self.gen_type_aware_initializer(&var_type)
                };

                *self.current_alloc_struct.borrow_mut() = None;
                result.push_str(&format!("    {} {} = {};\n", type_str, name, val_str));
            }
            Statement::Assignment { left, value, .. } => {
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
            Statement::While {
                condition, body, ..
            } => {
                let cond_str = self.gen_expression(condition);
                result.push_str(&format!("    while ({}) {{\n", cond_str));
                result.push_str(&self.gen_loop_body(body));
                result.push_str("    }\n");
            }
            Statement::If {
                condition,
                consequence,
                alternative,
                ..
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
            Statement::Guard {
                name,
                is_mut: _,
                value,
                else_body,
                span,
            } => {
                let val_type = self.symbol_table.borrow().get(name).cloned().unwrap_or(Type::Void);
                let val_type_c = self.get_c_type(&val_type);
                let wrapper_name = self.find_wrapper_type(&val_type);

                let line = span.start.line;
                let column = span.start.column;
                let guard_res_name = format!("_guard_res_{}_{}_{}", name, line, column);

                let val_expr_str = self.gen_expression(value);

                result.push_str(&format!("    const {} {} = {};\n", wrapper_name, guard_res_name, val_expr_str));
                result.push_str(&format!("    if (!{}.Ok) {{\n", guard_res_name));
                for stmt in &else_body.statements {
                    result.push_str(&format!("    {}", self.gen_statement(stmt).trim_start()));
                }
                result.push_str("    }\n");
                result.push_str(&format!("    {} {} = {}.Val;\n", val_type_c, name, guard_res_name));
            }
            Statement::Match {
                expression, cases, ..
            } => {
                let expr_str = self.gen_expression(expression);
                let expr_type = self.get_expr_type(expression).unwrap_or(Type::Void);

                let mut enum_name = "Shape".to_string();
                if let Type::Struct(name, _) = expr_type {
                    enum_name = name;
                }
                // Robustness: Always erase the brand suffix of enum_name to map to enum_registry correctly
                let erased_enum_name = erase_struct_name_with_registry(&enum_name, &None, &self.struct_registry);

                result.push_str(&format!("    switch ({}.tag) {{\n", expr_str));
                for case in cases {
                    // Generate the precise enum tag name instead of raw integer positions
                    let tag_name = format!("{}_Tag__{}", erased_enum_name, case.variant_name);

                    result.push_str(&format!("        case {}: {{\n", tag_name));
                    result.push_str(&self.gen_loop_body(&case.body));
                    result.push_str("            break;\n");
                    result.push_str("        }\n");
                }
                result.push_str("    }\n");
            }
            Statement::UnsafeBlock { body, .. } => {
                result.push_str("    {\n");
                result.push_str(&self.gen_loop_body(body));
                result.push_str("    }\n");
            }
            Statement::Defer { expr: _, .. } => {}
            Statement::Return(maybe_expr, _) => {
                if let Some(expr) = maybe_expr {
                    let expr_str = self.gen_expression(expr);
                    result.push_str(&format!("    return {};\n", expr_str));
                } else {
                    let is_main = self.current_function.borrow().as_deref() == Some("main");
                    if is_main {
                        result.push_str("    return 0;\n");
                    } else {
                        result.push_str("    return;\n");
                    }
                }
            }
            Statement::Expression(expr, _) => {
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
            if let Statement::Defer { expr, .. } = stmt {
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
            Expression::Identifier(name, span) => {
                if name == "null" {
                    "0xFFFFFFFF".to_string()
                } else {
                    self.resolved_names
                        .get(span)
                        .cloned()
                        .unwrap_or_else(|| name.clone())
                }
            }
            Expression::Integer(val, _) => val.to_string(),
            Expression::Bool(val, _) => {
                if *val {
                    "1".to_string()
                } else {
                    "0".to_string()
                }
            }
            Expression::String(val, _) => {
                format!(
                    "((Slice_unsigned_char){{ (unsigned char*)\"{}\", {} }})",
                    val,
                    val.len()
                )
            }
            Expression::Dereference(inner, _) => {
                let inner_str = self.gen_expression(inner);
                format!("(*({}))", inner_str)
            }
            Expression::Take(inner, _) => {
                let expr_str = self.gen_expression(inner);
                let mut is_lin = false;
                if let Some(t) = self.get_expr_type(inner) {
                    is_lin = self.is_linear(&t);
                }
                if is_lin {
                    format!(
                        "(({{\n        __typeof__({0}) _tmp = {0};\n        memset(&{0}, 0, sizeof({0}));\n        _tmp;\n    }}))",
                        expr_str
                    )
                } else {
                    expr_str
                }
            }
            Expression::AddressOf(inner, _) => {
                let inner_str = self.gen_expression(inner);
                if inner_str.ends_with(".Val") {
                    inner_str
                } else {
                    format!("&({})", inner_str)
                }
            }
            Expression::Move(inner, _) => {
                let expr_str = self.gen_expression(inner);
                let mut is_lin = false;
                if let Some(t) = self.get_expr_type(inner) {
                    is_lin = self.is_linear(&t);
                }
                if is_lin {
                    format!(
                        "(({{\n        __typeof__({0}) _tmp = {0};\n        memset(&{0}, 0, sizeof({0}));\n        _tmp;\n    }}))",
                        expr_str
                    )
                } else {
                    expr_str
                }
            }
            Expression::AsCast {
                left,
                target_type,
                is_reference,
                span,
                ..
            } => {
                let left_str = self.gen_expression(left);
                let resolved_target = self.resolved_types.get(span).unwrap_or(target_type);
                let target_str = self.get_c_type(resolved_target);

                if *is_reference {
                    let clean_target = target_str.trim_end_matches('*').trim();
                    format!(
                        "({{ CastResult_{} res; res.Ok = ((((uintptr_t){}.data) & (__alignof__({}) - 1)) == 0) && ({}.len >= sizeof({})); res.Val = ({}*){}.data; res; }})",
                        clean_target,
                        left_str,
                        clean_target,
                        left_str,
                        clean_target,
                        clean_target,
                        left_str
                    )
                } else {
                    if let Type::RawPointer(inner) = resolved_target {
                        format!(
                            "(({}){})",
                            self.get_c_type(&Type::RawPointer(inner.clone())),
                            left_str
                        )
                    } else if let Type::Struct(_, _) = resolved_target {
                        format!("(*(({}*){}.data))", target_str, left_str)
                    } else if *resolved_target == Type::Int
                        || *resolved_target == Type::Byte
                        || *resolved_target == Type::Bool
                        || matches!(resolved_target, Type::Index(_, _))
                    {
                        format!("(({}){})", target_str, left_str)
                    } else {
                        format!("(({}*){})", target_str, left_str)
                    }
                }
            }
            Expression::IndexAccess {
                allocator, index, ..
            } => {
                let alloc_str = self.gen_expression(allocator);
                let index_str = self.gen_expression(index);

                let alloc_type = self.get_expr_type(allocator).unwrap_or(Type::Void);
                let is_slice = matches!(alloc_type, Type::Slice(_)) || alloc_type == Type::Str;

                let mut is_vector = false;
                let mut is_hashmap = false;
                let mut is_pool = false;
                let mut is_str_key = false;

                if let Type::Struct(struct_name, _) = &alloc_type {
                    if struct_name.starts_with("Vector_") || struct_name.starts_with("std_Vector_")
                    {
                        is_vector = true;
                    } else if struct_name.starts_with("HashMap_")
                        || struct_name.starts_with("std_HashMap_")
                    {
                        is_hashmap = true;
                        if let Some(layout) = self.struct_registry.get(struct_name)
                            && let Some(Type::RawPointer(k_inner)) = layout.fields.get("keys")
                            && **k_inner == Type::Str
                        {
                            is_str_key = true;
                        }
                    } else if struct_name.starts_with("Pool_")
                        || struct_name.starts_with("std_Pool_")
                    {
                        is_pool = true;
                    }
                } else {
                    // Fallback to checking the allocator variable name in symbol table directly
                    let alloc_ident = expression_to_string(allocator);
                    if let Some(Type::Struct(struct_name, _)) =
                        self.symbol_table.borrow().get(&alloc_ident)
                    {
                        if struct_name.starts_with("Vector_")
                            || struct_name.starts_with("std_Vector_")
                        {
                            is_vector = true;
                        } else if struct_name.starts_with("HashMap_")
                            || struct_name.starts_with("std_HashMap_")
                        {
                            is_hashmap = true;
                            if let Some(layout) = self.struct_registry.get(struct_name)
                                && let Some(Type::RawPointer(k_inner)) = layout.fields.get("keys")
                                && **k_inner == Type::Str
                            {
                                is_str_key = true;
                            }
                        } else if struct_name.starts_with("Pool_")
                            || struct_name.starts_with("std_Pool_")
                        {
                            is_pool = true;
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
                } else if is_pool {
                    format!(
                        "(*({{ if ({} < 0 || {} >= {}.len) {{ printf(\"Pool bounds check failed at line %d\\n\", __LINE__); exit(1); }} &({}.data[{}]); }}))",
                        index_str, index_str, alloc_str, alloc_str, index_str
                    )
                } else {
                    // Arena indexing (Value-Branded)
                    let mut target_struct = "SessionNode".to_string();
                    if let Expression::Identifier(idx_name, _) = &**index
                        && let Some(Type::Index(struct_name, _)) =
                            self.symbol_table.borrow().get(idx_name)
                        && struct_name != "Any"
                    {
                        target_struct = struct_name.clone();
                    }

                    let mut use_arrow = false;
                    if let Expression::Identifier(name, _) = &**allocator
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
            Expression::Binary {
                op, left, right, ..
            } => {
                let left_str = self.gen_expression(left);
                let right_str = self.gen_expression(right);
                format!("{} {} {}", left_str, op, right_str)
            }
            Expression::Selector { left, right, .. } => {
                let left_str = self.gen_expression(left);

                let mut use_arrow = false;
                if let Some(left_type) = self.get_expr_type(left)
                    && matches!(left_type, Type::RawPointer(_)) {
                        use_arrow = true;
                    }
                if !use_arrow && matches!(**left, Expression::IndexAccess { .. }) {
                    if let Expression::IndexAccess { allocator, .. } = &**left
                        && let Expression::Identifier(name, _) = &**allocator
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
                    ..
                } = &**left
                    && let Expression::Identifier(name, _) = &**inner_left
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
                span,
                ..
            } => {
                let func_path = self.resolved_names.get(&function.span()).cloned()
                    .unwrap_or_else(|| self.gen_expression(function));

                if func_path == "len" {
                    let arg_str = self.gen_expression(&arguments[0]);
                    let mut is_coll = false;
                    let arg_type = self.get_expr_type(&arguments[0]).unwrap_or(Type::Void);
                    if let Type::Struct(struct_name, _) = &arg_type {
                        if struct_name.starts_with("Vector_")
                            || struct_name.starts_with("std_Vector_")
                            || struct_name.starts_with("HashMap_")
                            || struct_name.starts_with("std_HashMap_")
                        {
                            is_coll = true;
                        }
                    } else {
                        let arg_ident = expression_to_string(&arguments[0]);
                        if let Some(Type::Struct(struct_name, _)) =
                            self.symbol_table.borrow().get(&arg_ident)
                            && (struct_name.starts_with("Vector_")
                                || struct_name.starts_with("std_Vector_")
                                || struct_name.starts_with("HashMap_")
                                || struct_name.starts_with("std_HashMap_"))
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

                if func_path == "os_ScratchAlloc" || func_path == "os.ScratchAlloc" {
                    let size_str = if let Some(struct_name) = &*self.current_alloc_struct.borrow() {
                        format!("sizeof({})", struct_name)
                    } else if !arguments.is_empty() {
                        self.gen_expression(&arguments[0])
                    } else {
                        "sizeof(SessionNode)".to_string()
                    };
                    return format!("os_ScratchAlloc({})", size_str);
                }

                if func_path == "os_ScratchReset" || func_path == "os.ScratchReset" {
                    return "os_ScratchReset()".to_string();
                }

                if func_path == "std.Format" || func_path == "std_Format" {
                    let format_str = match &arguments[0] {
                        Expression::String(s, _) => s.clone(),
                        _ => "".to_string(),
                    };

                    let mut specifiers = Vec::new();
                    let mut c_format_string = String::new();
                    let chars: Vec<char> = format_str.chars().collect();
                    let mut i = 0;
                    while i < chars.len() {
                        if chars[i] == '%' && i + 1 < chars.len() {
                            let next_char = chars[i + 1];
                            if next_char == '%' {
                                c_format_string.push_str("%%");
                                i += 2;
                            } else if next_char == 's' {
                                specifiers.push('s');
                                c_format_string.push_str("%.*s");
                                i += 2;
                            } else if next_char == 'd' {
                                specifiers.push('d');
                                c_format_string.push_str("%d");
                                i += 2;
                            } else {
                                c_format_string.push('%');
                                i += 1;
                            }
                        } else {
                            c_format_string.push(chars[i]);
                            i += 1;
                        }
                    }

                    let mut size_expr = format!("{}", format_str.len());
                    let mut eval_statements = Vec::new();
                    let mut snprintf_args = Vec::new();

                    for (idx, spec) in specifiers.iter().enumerate() {
                        let arg_idx = idx + 1;
                        let arg_c = self.gen_expression(&arguments[arg_idx]);
                        if *spec == 's' {
                            eval_statements.push(format!("        Slice_unsigned_char _arg{} = {};", arg_idx, arg_c));
                            size_expr.push_str(&format!(" + _arg{}.len", arg_idx));
                            snprintf_args.push(format!("_arg{}.len, (char*)_arg{}.data", arg_idx, arg_idx));
                        } else {
                            eval_statements.push(format!("        __typeof__({0}) _arg{1} = {0};", arg_c, arg_idx));
                            size_expr.push_str(" + 20");
                            snprintf_args.push(format!("_arg{}", arg_idx));
                        }
                    }

                    let mut block = String::new();
                    block.push_str("(({");
                    if !eval_statements.is_empty() {
                        block.push('\n');
                        for stmt in &eval_statements {
                            block.push_str(stmt);
                            block.push('\n');
                        }
                    }
                    block.push_str(&format!("        int _alloc_size = {} + 1;\n", size_expr));
                    block.push_str("        char* _buf = (char*)os_ScratchAlloc(_alloc_size);\n");

                    let snprintf_args_str = if snprintf_args.is_empty() {
                        "".to_string()
                    } else {
                        format!(", {}", snprintf_args.join(", "))
                    };

                    block.push_str(&format!(
                        "        int _len = snprintf(_buf, _alloc_size, \"{}\"{});\n",
                        c_format_string, snprintf_args_str
                    ));
                    block.push_str("        ((Slice_unsigned_char){ (unsigned char*)_buf, _len });\n");
                    block.push_str("    }))");

                    return block;
                }

                if func_path == "std.FormatInt" || func_path == "std_FormatInt" {
                    let val_expr = self.gen_expression(&arguments[0]);
                    return format!(
                        "(({{ int _val = {}; char* _buf = (char*)os_ScratchAlloc(16); int _len = snprintf(_buf, 16, \"%d\", _val); ((Slice_unsigned_char){{ (unsigned char*)_buf, _len }}); }}))",
                        val_expr
                    );
                }

                if func_path == "std.Concat" || func_path == "std_Concat" {
                    let s1_expr = self.gen_expression(&arguments[0]);
                    let s2_expr = self.gen_expression(&arguments[1]);
                    return format!(
                        "(({{ Slice_unsigned_char _s1 = {}; Slice_unsigned_char _s2 = {}; char* _buf = (char*)os_ScratchAlloc(_s1.len + _s2.len + 1); memcpy(_buf, _s1.data, _s1.len); memcpy(_buf + _s1.len, _s2.data, _s2.len); _buf[_s1.len + _s2.len] = 0; ((Slice_unsigned_char){{ (unsigned char*)_buf, _s1.len + _s2.len }}); }}))",
                        s1_expr, s2_expr
                    );
                }

                if func_path == "std.Clone" || func_path == "std_Clone" {
                    let dest_arg_str = self.gen_expression(&arguments[0]);
                    let src_arg_str = self.gen_expression(&arguments[1]);

                    let mut dest_is_ptr = false;
                    if let Expression::Identifier(name, _) = &arguments[0]
                        && let Some(Type::RawPointer(inner)) = self.symbol_table.borrow().get(name)
                        && **inner == Type::Arena
                    {
                        dest_is_ptr = true;
                    }
                    let dest_arena_expr = if dest_is_ptr {
                        dest_arg_str.clone()
                    } else {
                        format!("&{}", dest_arg_str)
                    };
                    let dest_base = if dest_is_ptr {
                        format!("{}->BaseAddress", dest_arg_str)
                    } else {
                        format!("{}.BaseAddress", dest_arg_str)
                    };

                    let mut struct_name = "Node".to_string();
                    let mut src_brand = "current_ctx".to_string();
                    let mut found = false;

                    if let Expression::Identifier(name, _) = &arguments[1]
                        && let Some(Type::Index(s_name, Some(brand))) =
                            self.original_symbol_table.get(name).cloned()
                    {
                        struct_name = erase_struct_name_with_registry(
                            &s_name,
                            &Some(brand.clone()),
                            &self.struct_registry,
                        );
                        src_brand = brand;
                        found = true;
                    }

                    if found {
                        let mut src_is_ptr = false;
                        if let Some(Type::RawPointer(inner)) =
                            self.symbol_table.borrow().get(&src_brand)
                            && **inner == Type::Arena
                        {
                            src_is_ptr = true;
                        }
                        let src_base = if src_is_ptr {
                            format!("{}->BaseAddress", src_brand)
                        } else {
                            format!("{}.BaseAddress", src_brand)
                        };

                        return format!(
                            "({{ int _src_idx = {}; int _dest_idx = os_ArenaAlloc({}, sizeof({})); *(struct {}*)((char*){} + _dest_idx) = *(struct {}*)((char*){} + _src_idx); _dest_idx; }})",
                            src_arg_str,
                            dest_arena_expr,
                            struct_name,
                            struct_name,
                            dest_base,
                            struct_name,
                            src_base
                        );
                    } else {
                        return src_arg_str;
                    }
                }

                if func_path == "std.GenerationalSwap" || func_path == "std_GenerationalSwap" {
                    let arg0 = self.gen_expression(&arguments[0]);
                    let arg1 = self.gen_expression(&arguments[1]);
                    return format!("std_GenerationalSwap(&{}, &{})", arg0, arg1);
                }

                if func_path == "std.RcNew" || func_path == "std_RcNew" {
                    let pool_expr = self.gen_expression(&arguments[0]);
                    let val_expr = self.gen_expression(&arguments[1]);

                    let pool_type = self.get_expr_type(&arguments[0]).unwrap_or(Type::Void);
                    let val_type = self.get_expr_type(&arguments[1]).unwrap_or(Type::Void);

                    let mut opt_ctx_name = None;
                    let target_pool_type = if let Type::RawPointer(inner) = &pool_type {
                        (**inner).clone()
                    } else {
                        pool_type.clone()
                    };

                    match &target_pool_type {
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

                    let ctx_name = opt_ctx_name.unwrap_or_else(|| "ctx".to_string());
                    let rc_type = format!("std_Rc_{}_{}", self.get_type_ident(&val_type), ctx_name);
                    let erased_rc_type = erase_struct_name_with_registry(
                        &rc_type,
                        &Some(ctx_name.clone()),
                        &self.struct_registry,
                    );

                    let is_pool_ptr = matches!(pool_type, Type::RawPointer(_));

                    let pool_ptr_expr = if is_pool_ptr {
                        pool_expr
                    } else {
                        format!("&{}", pool_expr)
                    };

                    return format!(
                        "std_RcNew({}, {}, {})",
                        pool_ptr_expr, val_expr, erased_rc_type
                    );
                }

                // os.VectorNew / std.VectorNew
                if func_path == "os.VectorNew"
                    || func_path == "os_VectorNew"
                    || func_path == "std.VectorNew"
                    || func_path == "std_VectorNew"
                {
                    let arg_str = self.gen_expression(&arguments[0]);
                    let type_str = if let Some(struct_name) = &*self.current_alloc_struct.borrow() {
                        struct_name.clone()
                    } else {
                        "Vector_int".to_string()
                    };
                    let mut is_ptr = false;
                    if let Expression::Identifier(name, _) = &arguments[0]
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

                // os.HashMapNew / std.HashMapNew
                if func_path == "os.HashMapNew"
                    || func_path == "os_HashMapNew"
                    || func_path == "std.HashMapNew"
                    || func_path == "std_HashMapNew"
                {
                    let arg_str = self.gen_expression(&arguments[0]);
                    let type_str = if let Some(struct_name) = &*self.current_alloc_struct.borrow() {
                        struct_name.clone()
                    } else {
                        "HashMap_int_int".to_string()
                    };
                    let mut is_ptr = false;
                    if let Expression::Identifier(name, _) = &arguments[0]
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

                // os.PoolNew / std.PoolNew
                if func_path == "os.PoolNew"
                    || func_path == "os_PoolNew"
                    || func_path == "std.PoolNew"
                    || func_path == "std_PoolNew"
                {
                    let arg_str = self.gen_expression(&arguments[0]);
                    let type_str = if let Some(struct_name) = &*self.current_alloc_struct.borrow() {
                        struct_name.clone()
                    } else { 
                        "Pool_int".to_string()
                    };
                    let mut is_ptr = false;
                    if let Expression::Identifier(name, _) = &arguments[0]
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
                        "(struct {}){{ .arena = {}, .capacity = 0, .data = NULL, .free_len = 0, .free_list = NULL, .len = 0, .occupied = NULL }}",
                        type_str, arena_expr
                    );
                }

                if func_path == "std.MutexNew"
                    || func_path == "std_MutexNew"
                {
                    let type_str = if let Some(struct_name) = &*self.current_alloc_struct.borrow() {
                        struct_name.clone()
                    } else {
                        "Mutex_Any".to_string()
                    };
                    return format!(
                        "(struct {}){{ .lock_state = std_Mutex_Alloc() }}",
                        type_str
                    );
                }

                if func_path == "std.ChannelNew"
                    || func_path == "std_ChannelNew"
                {
                    let type_str = if let Some(struct_name) = &*self.current_alloc_struct.borrow() {
                        struct_name.clone()
                    } else {
                        "Channel_Any".to_string()
                    };
                    return format!(
                        "(struct {}){{ .capacity = std_Channel_Alloc(16, sizeof(*(((struct {}*)0)->_phantom))), .len = 0 }}",
                        type_str, type_str
                    );
                }

                if func_path == "std.Spawn" || func_path == "std_Spawn" {
                    let raw_func_name = expression_to_string(&arguments[0]);
                    let thread_func_name = self.resolved_names.get(&arguments[0].span()).cloned()
                        .unwrap_or(raw_func_name)
                        .replace(".", "_");
                    let arg_str = self.gen_expression(&arguments[1]);
                    let arg_type = self.get_expr_type(&arguments[1]).unwrap_or(Type::Void);
                    let is_ptr = matches!(arg_type, Type::RawPointer(_));
                    let cast_expr = if is_ptr {
                        format!("(void*){}", arg_str)
                    } else {
                        format!("(void*)(uintptr_t){}", arg_str)
                    };
                    return format!(
                        "(({{\n        pthread_t _thread;\n        pthread_create(&_thread, NULL, {}_pthread_wrapper, {});\n        pthread_detach(_thread);\n    }}))",
                        thread_func_name, cast_expr
                    );
                }

                // os.Exit / os_Exit
                if func_path == "os.Exit" || func_path == "os_Exit" {
                    let code_str = self.gen_expression(&arguments[0]);
                    return format!("exit({})", code_str);
                }

                // os.ReadFile
                if func_path == "os.ReadFile" || func_path == "os_ReadFile" {
                    let arg_arena = self.gen_expression(&arguments[0]);
                    let arg_path = self.gen_expression(&arguments[1]);

                    let mut is_ptr = false;
                    if let Expression::Identifier(name, _) = &arguments[0]
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

                if let Expression::Selector { left, right, .. } = &**function {
                    let left_str = self.gen_expression(left);

                    let mut is_vec = false;
                    let mut is_map = false;
                    let mut is_pool = false;
                    let mut is_rc = false;
                    let mut is_graph = false;
                    let left_type = self.get_expr_type(left).unwrap_or(Type::Void);

                    let mut is_mutex = false;
                    let mut is_channel = false;
                    if let Type::Struct(struct_name, _) = &left_type { 
                        if struct_name.starts_with("Vector_")
                            || struct_name.starts_with("std_Vector_")
                        {
                            is_vec = true;
                        } else if struct_name.starts_with("HashMap_")
                            || struct_name.starts_with("std_HashMap_")
                        {
                            is_map = true;
                        } else if struct_name.starts_with("Pool_")
                            || struct_name.starts_with("std_Pool_")
                        {
                            is_pool = true;
                        } else if struct_name.starts_with("Rc_")
                            || struct_name.starts_with("std_Rc_")
                        {
                            is_rc = true;
                        } else if struct_name.starts_with("Graph_")
                            || struct_name.starts_with("std_Graph_")
                        {
                            is_graph = true;
                        } else if struct_name.starts_with("Mutex_")
                            || struct_name.starts_with("std_Mutex_")
                        {
                            is_mutex = true;
                        } else if struct_name.starts_with("Channel_")
                            || struct_name.starts_with("std_Channel_")
                        {
                            is_channel = true;
                        }
                    } else { 
                        let left_ident = expression_to_string(left);
                        if let Some(Type::Struct(struct_name, _)) =
                            self.symbol_table.borrow().get(&left_ident)
                        {
                            if struct_name.starts_with("Vector_")
                                || struct_name.starts_with("std_Vector_")
                            {
                                is_vec = true;
                            } else if struct_name.starts_with("HashMap_")
                                || struct_name.starts_with("std_HashMap_")
                            {
                                is_map = true;
                            } else if struct_name.starts_with("Pool_")
                                || struct_name.starts_with("std_Pool_")
                            {
                                is_pool = true;
                            } else if struct_name.starts_with("Rc_")
                                || struct_name.starts_with("std_Rc_")
                            {
                                is_rc = true;
                            } else if struct_name.starts_with("Graph_")
                                || struct_name.starts_with("std_Graph_")
                            {
                                is_graph = true;
                            } else if struct_name.starts_with("Mutex_")
                                || struct_name.starts_with("std_Mutex_")
                            {
                                is_mutex = true;
                            } else if struct_name.starts_with("Channel_")
                                || struct_name.starts_with("std_Channel_")
                            {
                                is_channel = true;
                            }
                        }
                    }

                    if is_mutex && right == "Lock" {
                        return format!("std_Mutex_Lock_impl({}.lock_state, &({}.value))", left_str, left_str);
                    }
                    if is_mutex && right == "Unlock" {
                        return format!("std_Mutex_Unlock_impl({}.lock_state)", left_str);
                    }
                    if is_channel && right == "Send" {
                        let arg_str = self.gen_expression(&arguments[0]);
                        return format!(
                            "(({{\n        __typeof__({1}) _tmp = {1};\n        std_Channel_Send_impl({0}.capacity, &_tmp);\n    }}))",
                            left_str, arg_str
                        );
                    }
                    if is_channel && right == "Recv" {
                        let type_str = self.get_c_type(&left_type);
                        return format!(
                            "(({{\n        __typeof__(*(((struct {}*)0)->_phantom)) _val;\n        std_Channel_Recv_impl({}.capacity, &_val);\n        _val;\n    }}))",
                            type_str, left_str
                        );
                    }

                    if is_rc && right == "Clone" {
                        return format!("std_RcClone(&{})", left_str);
                    }
                    if is_rc && right == "Release" {
                        return format!("std_RcRelease(&{})", left_str);
                    }
                    if is_rc && right == "Get" {
                        return format!("std_RcGet(&{})", left_str);
                    }

                    if is_rc && right == "Clone" {
                        return format!("std_RcClone(&{})", left_str);
                    }
                    if is_rc && right == "Release" {
                        return format!("std_RcRelease(&{})", left_str);
                    }
                    if is_rc && right == "Get" {
                        return format!("std_RcGet(&{})", left_str);
                    }
                    if is_graph && right == "AddNode" {
                        let arg_str = self.gen_expression(&arguments[0]);
                        return format!("std_GraphAddNode(&{}, {})", left_str, arg_str);
                    }
                    if is_graph && right == "AddEdge" {
                        let arg0 = self.gen_expression(&arguments[0]);
                        let arg1 = self.gen_expression(&arguments[1]);
                        return format!("std_GraphAddEdge(&{}, {}, {})", left_str, arg0, arg1);
                    }
                    if is_graph && right == "GetNode" {
                        let arg_str = self.gen_expression(&arguments[0]);
                        return format!("std_GraphGetNode(&{}, {})", left_str, arg_str);
                    }

                    if is_vec && right == "Push" {
                        let arg_str = self.gen_expression(&arguments[0]);
                        return format!("os_VectorPush(&{}, {})", left_str, arg_str);
                    }
                    if is_vec && right == "Pop" {
                        return format!("os_VectorPop(&{})", left_str);
                    }
                    if is_vec && right == "Clear" {
                        return format!("os_VectorClear(&{})", left_str);
                    }
                    if is_vec && right == "Back" {
                        return format!("os_VectorBack(&{})", left_str);
                    }
                    if is_map && right == "Insert" {
                        let k_str = self.gen_expression(&arguments[0]);
                        let v_str = self.gen_expression(&arguments[1]);
                        let mut is_str_key = false;
                        let opt_struct_name = if let Type::Struct(struct_name, _) = &left_type {
                            Some(struct_name.clone())
                        } else {
                            let left_ident = expression_to_string(left);
                            if let Some(Type::Struct(struct_name, _)) =
                                self.symbol_table.borrow().get(&left_ident)
                            {
                                Some(struct_name.clone())
                            } else {
                                None
                            }
                        };
                        if let Some(struct_name) = opt_struct_name {
                            is_str_key = self
                                .get_hashmap_key_value_types(&struct_name)
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
                        let opt_struct_name = if let Type::Struct(struct_name, _) = &left_type {
                            Some(struct_name.clone())
                        } else {
                            let left_ident = expression_to_string(left);
                            if let Some(Type::Struct(struct_name, _)) = 
                                self.symbol_table.borrow().get(&left_ident)
                            {
                                Some(struct_name.clone())
                            } else {
                                None
                            }
                        };
                        if let Some(struct_name) = opt_struct_name
                            && let Some((k, v)) = self.get_hashmap_key_value_types(&struct_name)
                        {
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
                    if is_map && right == "Remove" {
                        let k_str = self.gen_expression(&arguments[0]);
                        let mut is_str_key = false;
                        let opt_struct_name = if let Type::Struct(struct_name, _) = &left_type {
                            Some(struct_name.clone())
                        } else {
                            let left_ident = expression_to_string(left);
                            if let Some(Type::Struct(struct_name, _)) = 
                                self.symbol_table.borrow().get(&left_ident)
                            {
                                Some(struct_name.clone())
                            } else {
                                None
                            }
                        };
                        if let Some(struct_name) = opt_struct_name {
                            is_str_key = self
                                .get_hashmap_key_value_types(&struct_name)
                                .map(|(k, _)| k == Type::Str)
                                .unwrap_or(false);
                        }
                        let is_str_key_str = if is_str_key { "1" } else { "0" };
                        return format!(
                            "os_HashMapRemove(&{}, {}, {})",
                            left_str, k_str, is_str_key_str
                        );
                    }
                    if is_map && right == "Clear" {
                        return format!("os_HashMapClear(&{})", left_str);
                    }
                    if is_map && right == "Keys" {
                        let ctx_str = self.gen_expression(&arguments[0]);
                        let expr_type = self.resolved_types.get(span).cloned().unwrap_or_else(|| {
                            Type::Struct("std_Vector_int".to_string(), None)
                        });
                        let vec_type_str = self.get_c_type(&expr_type);
                        let is_ctx_ptr = if let Expression::Identifier(name, _) = &arguments[0]
                            && let Some(Type::RawPointer(inner)) = self.symbol_table.borrow().get(name)
                            && **inner == Type::Arena
                        {
                            true
                        } else {
                            false
                        };
                        let arena_expr = if is_ctx_ptr {
                            ctx_str
                        } else {
                            format!("&{}", ctx_str)
                        };
                        return format!(
                            "(({{\n        {} _v = ({}){{ .data = NULL, .len = 0, .capacity = 0, .arena = {} }};\n        for (int _i = 0; _i < ({}).capacity; _i++) {{\n            if (({}).occupied[_i] == 1) {{\n                os_VectorPush(&_v, ({}).keys[_i]);\n            }}\n        }}\n        _v;\n    }}))",
                            vec_type_str, vec_type_str, arena_expr, left_str, left_str, left_str
                        );
                    }

                    if is_pool && right == "Alloc" {
                        let arg_str = self.gen_expression(&arguments[0]);
                        return format!("std_PoolAlloc(&{}, {})", left_str, arg_str);
                    }

                    if is_pool && right == "Free" {
                        let arg_str = self.gen_expression(&arguments[0]);
                        return format!("std_PoolFree(&{}, {})", left_str, arg_str);
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
                    if let Expression::Identifier(name, _) = arg
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
            Expression::Empty(target_type, span) => {
                let resolved_target = self.resolved_types.get(span).unwrap_or(target_type);
                self.gen_type_aware_initializer(resolved_target)
            }
        }
    }
}
