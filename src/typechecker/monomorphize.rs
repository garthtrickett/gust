use super::TypeChecker;
use super::types::{StructLayout, Type, TypeError, TypeErrorKind, strip_brand_prefix};
use std::collections::HashMap;

impl TypeChecker {
    pub(crate) fn substitute_brand(&self, t: &Type, new_brand: &Option<String>) -> Type {
        match t {
            Type::Index(struct_name, old_brand) => {
                let mut new_struct_name = struct_name.clone();
                if let (Some(old_b), Some(new_b)) = (old_brand, new_brand) {
                    let old_b_clean = strip_brand_prefix(old_b);
                    let new_b_clean = strip_brand_prefix(new_b);
                    let suffix = format!("_{}", old_b_clean);
                    let new_suffix = format!("_{}", new_b_clean);
                    if let Some(stripped) = new_struct_name.strip_suffix(&suffix) {
                        new_struct_name = format!("{}{}", stripped, new_suffix);
                    } else {
                        let suffix_full = format!("_{}", old_b);
                        let new_suffix_full = format!("_{}", new_b);
                        if let Some(stripped) = new_struct_name.strip_suffix(&suffix_full) {
                            new_struct_name = format!("{}{}", stripped, new_suffix_full);
                        }
                    }
                }
                Type::Index(new_struct_name, new_brand.clone())
            }
            Type::Struct(struct_name, old_brand) => {
                let mut new_struct_name = struct_name.clone();
                if let (Some(old_b), Some(new_b)) = (old_brand, new_brand) {
                    let old_b_clean = strip_brand_prefix(old_b);
                    let new_b_clean = strip_brand_prefix(new_b);
                    let suffix = format!("_{}", old_b_clean);
                    let new_suffix = format!("_{}", new_b_clean);
                    if let Some(stripped) = new_struct_name.strip_suffix(&suffix) {
                        new_struct_name = format!("{}{}", stripped, new_suffix);
                    } else {
                        let suffix_full = format!("_{}", old_b);
                        let new_suffix_full = format!("_{}", new_b);
                        if let Some(stripped) = new_struct_name.strip_suffix(&suffix_full) {
                            new_struct_name = format!("{}{}", stripped, new_suffix_full);
                        }
                    }
                }
                Type::Struct(new_struct_name, new_brand.clone())
            }
            Type::RawPointer(inner) => {
                Type::RawPointer(Box::new(self.substitute_brand(inner, new_brand)))
            }
            Type::Slice(inner) => Type::Slice(Box::new(self.substitute_brand(inner, new_brand))),
            Type::Generic(name, args) => {
                let new_args: Vec<Type> = args
                    .iter()
                    .map(|arg| self.substitute_brand(arg, new_brand))
                    .collect();
                Type::Generic(name.clone(), new_args)
            }
            _ => t.clone(),
        }
    }

    pub(crate) fn substitute_field_brand(
        &self,
        t: &Type,
        struct_brand: &Option<String>,
        parent_path: &str,
        layout: &StructLayout,
    ) -> Type {
        match t {
            Type::Index(struct_name, Some(original_brand)) => {
                if layout.fields.contains_key(original_brand) {
                    let mut res = parent_path.to_string();
                    res.push('.');
                    res.push_str(original_brand);
                    Type::Index(struct_name.clone(), Some(res))
                } else {
                    Type::Index(struct_name.clone(), struct_brand.clone())
                }
            }
            Type::Struct(struct_name, Some(original_brand)) => {
                if layout.fields.contains_key(original_brand) {
                    let mut res = parent_path.to_string();
                    res.push('.');
                    res.push_str(original_brand);
                    Type::Struct(struct_name.clone(), Some(res))
                } else {
                    Type::Struct(struct_name.clone(), struct_brand.clone())
                }
            }
            Type::RawPointer(inner) => Type::RawPointer(Box::new(self.substitute_field_brand(
                inner,
                struct_brand,
                parent_path,
                layout,
            ))),
            Type::Slice(inner) => Type::Slice(Box::new(self.substitute_field_brand(
                inner,
                struct_brand,
                parent_path,
                layout,
            ))),
            _ => self.substitute_brand(t, struct_brand),
        }
    }

    pub(crate) fn is_element_allowed_in_brand(&self, element: &Type, ob: &str) -> bool {
        if !self.is_linear(element) {
            return true;
        }
        if matches!(element, Type::Str | Type::Slice(_) | Type::ByteSlice) {
            return true;
        }
        if let Type::Struct(name, _) = element
            && name == "str" {
                return true;
            }
        if let Some(ib) = self.get_type_brand(element)
            && strip_brand_prefix(&ib) == strip_brand_prefix(ob)
        {
            return true;
        }
        false
    }

    pub(crate) fn check_brand_hierarchy(
        &self,
        t: &Type,
        outer_brand: &Option<String>,
    ) -> Result<(), TypeError> {
        if let Some(ob) = outer_brand {
            if let Type::Struct(name, _) = t
                && strip_brand_prefix(name) != strip_brand_prefix(ob)
                && !self.is_element_allowed_in_brand(t, ob)
            {
                return Err(TypeError {
                    kind: TypeErrorKind::BrandLifetimeViolation,
                    message: format!(
                        "Semantic Error: Brand Nesting Restriction violation. Element '{:?}' inside collection branded with '{}' must be copyable POD or branded with identical brand '{}'",
                        t, ob, ob
                    ),
                    span: None,
                });
            }
            if let Type::Index(_, _) = t
                && !self.is_element_allowed_in_brand(t, ob)
            {
                return Err(TypeError {
                    kind: TypeErrorKind::BrandLifetimeViolation,
                    message: format!(
                        "Semantic Error: Brand Nesting Restriction violation. Element '{:?}' inside collection branded with '{}' must be copyable POD or branded with identical brand '{}'",
                        t, ob, ob
                    ),
                    span: None,
                });
            }
        }

        match t {
            Type::Struct(name, inner_brand) => {
                if let Some(ib) = inner_brand
                    && let Some(ob) = outer_brand
                    && strip_brand_prefix(ib) != strip_brand_prefix(ob)
                {
                    return Err(TypeError {
                        kind: TypeErrorKind::BrandLifetimeViolation,
                        message: format!(
                            "Semantic Error: Mismatched nested brand. Outer brand is '{}', but nested type '{}' has brand '{}'",
                            ob, name, ib
                        ),
                        span: None,
                    });
                }
                if let Some(layout) = self.struct_registry.get(name) {
                    let current_brand = inner_brand.as_ref().or(outer_brand.as_ref()).cloned();
                    for field_type in layout.fields.values() {
                        self.check_brand_hierarchy(field_type, &current_brand)?;
                    }
                }
            }
            Type::Index(name, inner_brand) => {
                if let Some(ib) = inner_brand
                    && let Some(ob) = outer_brand
                    && ib != ob
                {
                    return Err(TypeError {
                        kind: TypeErrorKind::BrandLifetimeViolation,
                        message: format!(
                            "Semantic Error: Mismatched nested brand. Outer brand is '{}', but nested type 'Index[{}]' has brand '{}'",
                            ob, name, ib
                        ),
                        span: None,
                    });
                }
            }
            Type::Generic(_, args) => {
                for arg in args {
                    self.check_brand_hierarchy(arg, outer_brand)?;
                }
            }
            Type::RawPointer(inner) | Type::Slice(inner) => {
                self.check_brand_hierarchy(inner, outer_brand)?;
            }
            _ => {}
        }
        Ok(())
    }

    pub(crate) fn get_type_brand(&self, t: &Type) -> Option<String> {
        match t {
            Type::Index(name, brand) => {
                if let Some(b) = brand {
                    Some(b.clone())
                } else if name.ends_with("_ctx") || name.contains("_ctx_") {
                    Some("ctx".to_string())
                } else if name.ends_with("_connCtx") || name.contains("_connCtx_") {
                    Some("connCtx".to_string())
                } else if name.ends_with("_arena") || name.contains("_arena_") {
                    Some("arena".to_string())
                } else if name.ends_with("_a") || name.contains("_a_") {
                    Some("a".to_string())
                } else if name.ends_with("_Any") || name.contains("_Any_") {
                    Some("Any".to_string())
                } else {
                    None
                }
            }
            Type::Struct(name, brand) => {
                if let Some(b) = brand {
                    Some(b.clone())
                } else if let Some(layout) = self.struct_registry.get(name) {
                    if let Some(b) = &layout.brand {
                        Some(b.clone())
                    } else if name.ends_with("_ctx") || name.contains("_ctx_") {
                        Some("ctx".to_string())
                    } else if name.ends_with("_connCtx") || name.contains("_connCtx_") {
                        Some("connCtx".to_string())
                    } else if name.ends_with("_arena") || name.contains("_arena_") {
                        Some("arena".to_string())
                    } else if name.ends_with("_a") || name.contains("_a_") {
                        Some("a".to_string())
                    } else if name.ends_with("_Any") || name.contains("_Any_") {
                        Some("Any".to_string())
                    } else {
                        None
                    }
                } else {
                    if name.ends_with("_ctx") || name.contains("_ctx_") {
                        Some("ctx".to_string())
                    } else if name.ends_with("_connCtx") || name.contains("_connCtx_") {
                        Some("connCtx".to_string())
                    } else if name.ends_with("_arena") || name.contains("_arena_") {
                        Some("arena".to_string())
                    } else if name.ends_with("_a") || name.contains("_a_") {
                        Some("a".to_string())
                    } else if name.ends_with("_Any") || name.contains("_Any_") {
                        Some("Any".to_string())
                    } else {
                        None
                    }
                }
            }
            Type::RawPointer(inner) => self.get_type_brand(inner),
            Type::Slice(inner) => self.get_type_brand(inner),
            _ => None,
        }
    }

    pub(crate) fn resolve_type(&mut self, t: &Type) -> Result<Type, TypeError> {
        let t = self.resolve_type_namespacing(t)?;
        match &t {
            Type::Generic(name, args) => {
                let resolved_args: Result<Vec<Type>, TypeError> =
                    args.iter().map(|arg| self.resolve_type(arg)).collect();
                self.monomorphize(name, &resolved_args?)
            }
            Type::Struct(name, brand) => {
                if name.starts_with("LookupResult_") && !self.struct_registry.contains_key(name) {
                    let target_struct = name
                        .strip_prefix("LookupResult_")
                        .unwrap_or(name)
                        .to_string();
                    let v_type = if target_struct == "int" {
                        Type::Int
                    } else {
                        Type::Struct(target_struct, None)
                    };
                    let mut fields = HashMap::new();
                    fields.insert("Ok".to_string(), Type::Int);
                    fields.insert("Val".to_string(), v_type);
                    self.struct_registry.insert(
                        name.clone(),
                        StructLayout {
                            brand: None,
                            fields,
                        },
                    );
                }

                if name.starts_with("CastResult_") && !self.struct_registry.contains_key(name) {
                    let target_struct =
                        name.strip_prefix("CastResult_").unwrap_or(name).to_string();
                    let v_type = if target_struct == "int" {
                        Type::Int
                    } else {
                        Type::RawPointer(Box::new(Type::Struct(target_struct, None)))
                    };
                    let mut fields = HashMap::new();
                    fields.insert("Ok".to_string(), Type::Int);
                    fields.insert("Val".to_string(), v_type);
                    self.struct_registry.insert(
                        name.clone(),
                        StructLayout {
                            brand: None,
                            fields,
                        },
                    );
                }

                if !self.struct_registry.contains_key(name) {
                    let mut matched_template = None;
                    let mut matched_prefix = None;

                    let templates = self
                        .struct_templates
                        .keys()
                        .chain(self.enum_templates.keys())
                        .cloned()
                        .collect::<Vec<String>>();

                    for template_name in templates {
                        let prefix = format!("{}_", template_name.replace(".", "_"));
                        if name.starts_with(&prefix) {
                            matched_template = Some(template_name);
                            matched_prefix = Some(prefix);
                            break;
                        }
                    }

                    if let (Some(template), Some(prefix)) = (matched_template, matched_prefix) {
                        let suffix = name.strip_prefix(&prefix).unwrap_or(name);
                        let normalized = suffix.replace("__", "@");
                        let parts: Vec<&str> = normalized.split('_').collect();

                        let num_generics = if self.struct_templates.contains_key(&template) {
                            self.struct_templates.get(&template).unwrap().generics.len()
                        } else {
                            self.enum_templates.get(&template).unwrap().generics.len()
                        };

                        if parts.len() >= num_generics {
                            let mut args = Vec::new();
                            if parts.len() == 2 && num_generics == 2 { 
                                let first_part = parts[0].replace("@", "__");
                                let second_part = parts[1].replace("@", "__");
                                let is_generic_template =
                                    self.struct_templates.contains_key(&first_part)
                                        || self.enum_templates.contains_key(&first_part);
                                if is_generic_template {
                                    let reconstructed = format!("{}_{}", first_part, second_part);
                                    args.push(Type::Struct(reconstructed, None));
                                } else {
                                    if first_part == "int" {
                                        args.push(Type::Int);
                                    } else if first_part == "byte" {
                                        args.push(Type::Byte);
                                    } else if first_part == "bool" {
                                        args.push(Type::Bool);
                                    } else if first_part == "str" {
                                        args.push(Type::Str);
                                    } else {
                                        args.push(Type::Struct(first_part, None));
                                    }
                                }
                                if second_part == "int" {
                                    args.push(Type::Int);
                                } else if second_part == "byte" {
                                    args.push(Type::Byte);
                                } else if second_part == "bool" {
                                    args.push(Type::Bool);
                                } else if second_part == "str" {
                                    args.push(Type::Str);
                                } else { 
                                    args.push(Type::Struct(second_part, None));
                                }
                            } else if parts.len() > num_generics {
                                let num_to_join = parts.len() - num_generics + 1;
                                let joined_first_arg = 
                                    parts[..num_to_join].join("_").replace("@", "__");
                                args.push(Type::Struct(joined_first_arg, None));
                                for part in &parts[num_to_join..] {
                                    let clean_part = part.replace("@", "__");
                                    if clean_part == "int" {
                                        args.push(Type::Int);
                                    } else if clean_part == "byte" {
                                        args.push(Type::Byte);
                                    } else if clean_part == "bool" {
                                        args.push(Type::Bool);
                                    } else if clean_part == "str" {
                                        args.push(Type::Str);
                                    } else {
                                        args.push(Type::Struct(clean_part, None));
                                    }
                                }
                            } else {
                                for part in parts {
                                    let clean_part = part.replace("@", "__");
                                    if clean_part == "int" {
                                        args.push(Type::Int);
                                    } else if clean_part == "byte" {
                                        args.push(Type::Byte);
                                    } else if clean_part == "bool" {
                                        args.push(Type::Bool);
                                    } else if clean_part == "str" {
                                        args.push(Type::Str);
                                    } else {
                                        args.push(Type::Struct(clean_part, None));
                                    }
                                }
                            }

                            if let Err(ref err) = self.monomorphize(&template, &args) {
                                tracing::error!(
                                    "❌ Fallback monomorphization of '{}' failed: {:?}",
                                    template,
                                    err
                                );
                            }
                        }
                    }
                }

                if let Some(brand_name) = brand {
                    if self.struct_templates.contains_key(name)
                        || self.enum_templates.contains_key(name)
                    {
                        let args = vec![Type::Struct(brand_name.clone(), None)];
                        self.monomorphize(name, &args)
                    } else {
                        Ok(t.clone())
                    }
                } else {
                    Ok(t.clone())
                }
            }
            Type::Index(struct_name, brand) => {
                let resolved_inner =
                    self.resolve_type(&Type::Struct(struct_name.clone(), brand.clone()))?;
                let concrete_name = match resolved_inner {
                    Type::Struct(name, _) => name,
                    _ => struct_name.clone(),
                };
                Ok(Type::Index(concrete_name, brand.clone()))
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

    pub(crate) fn monomorphize(
        &mut self,
        template_name: &str,
        args: &[Type],
    ) -> Result<Type, TypeError> {
        let old_prefix = self.current_prefix.clone();
        let old_imports = self.imports.clone();

        let mut template_prefix = String::new();
        if let Some(pos) = template_name.rfind("__") {
            template_prefix = template_name[..pos + 2].to_string();
        }

        if !template_prefix.is_empty() {
            self.current_prefix = template_prefix.clone();
            if let Some(imports) = self.module_imports.get(&template_prefix) {
                self.imports = imports.clone();
            }
        }

        let result = self.monomorphize_impl(template_name, args);

        self.current_prefix = old_prefix;
        self.imports = old_imports;

        result
    }

    pub(crate) fn monomorphize_impl(
        &mut self,
        template_name: &str,
        args: &[Type],
    ) -> Result<Type, TypeError> {
        if self.enum_templates.contains_key(template_name) {
            let template = self.enum_templates.get(template_name).cloned().unwrap();

            if template.generics.len() != args.len() {
                return Err(TypeError {
                    kind: TypeErrorKind::TemplateArgumentMismatch,
                    message: format!(
                        "Semantic Error: Template '{}' expects {} generic arguments but got {}",
                        template_name,
                        template.generics.len(),
                        args.len()
                    ),
                    span: None,
                });
            }

            let mut substitution_map = HashMap::new();
            for (generic, arg) in template.generics.iter().zip(args.iter()) {
                substitution_map.insert(generic.clone(), arg.clone());
            }

            let concrete_name = self.get_monomorphized_name(template_name, args);

            let mut brand = None;
            for (generic_name, arg) in template.generics.iter().zip(args.iter()) {
                if (generic_name == "ctx"
                    || generic_name == "connCtx"
                    || generic_name == "arena"
                    || generic_name == "a")
                    && let Type::Struct(brand_name, _) = arg
                {
                    brand = Some(brand_name.clone());
                }
            }

            for arg in args {
                self.check_brand_hierarchy(arg, &brand)?;
            }

            if !self.struct_registry.contains_key(&concrete_name) {
                // Place empty/placeholder structural layout for cyclic definitions
                self.struct_registry.insert(
                    concrete_name.clone(),
                    StructLayout {
                        brand: brand.clone(),
                        fields: HashMap::new(),
                    },
                );

                let mut concrete_variants = Vec::new();
                for variant in &template.variants {
                    concrete_variants.push(variant.name.clone());
                }
                self.enum_registry
                    .insert(concrete_name.clone(), concrete_variants);

                let mut enum_fields = HashMap::new();
                enum_fields.insert("tag".to_string(), Type::Int);

                for variant in &template.variants {
                    let concrete_variant_struct_name =
                        format!("{}_{}", concrete_name, variant.name);
                    let mut variant_fields = HashMap::new();
                    for field in &variant.fields {
                        let substituted_type =
                            self.substitute_generics(&field.field_type, &substitution_map)?;
                        let resolved_field_type = self.resolve_type(&substituted_type)?;
                        let resolved_field_type =
                            self.resolve_type_namespacing(&resolved_field_type)?;

                        if let Type::Struct(ref struct_name, _) = resolved_field_type
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

                        variant_fields.insert(field.name.clone(), resolved_field_type);
                    }

                    self.struct_registry.insert(
                        concrete_variant_struct_name.clone(),
                        StructLayout {
                            brand: None,
                            fields: variant_fields,
                        },
                    );

                    enum_fields.insert(
                        variant.name.clone(),
                        Type::Struct(concrete_variant_struct_name, None),
                    );
                }

                if let Some(layout) = self.struct_registry.get_mut(&concrete_name) {
                    layout.fields = enum_fields;
                }
            }

            return Ok(Type::Struct(concrete_name, brand));
        }

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
                span: None,
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
                span: None,
            });
        }

        let mut substitution_map = HashMap::new();
        for (generic, arg) in template.generics.iter().zip(args.iter()) {
            substitution_map.insert(generic.clone(), arg.clone());
        }

        let concrete_name = self.get_monomorphized_name(template_name, args);

        let mut brand = None;
        for (generic_name, arg) in template.generics.iter().zip(args.iter()) {
            if (generic_name == "ctx"
                || generic_name == "connCtx"
                || generic_name == "arena"
                || generic_name == "a")
                && let Type::Struct(brand_name, _) = arg
            {
                brand = Some(brand_name.clone());
            }
        }

        for arg in args {
            self.check_brand_hierarchy(arg, &brand)?;
        }

        if !self.struct_registry.contains_key(&concrete_name) {
            // First insert a placeholder to short-circuit recursive structural self-references [1]
            self.struct_registry.insert(
                concrete_name.clone(),
                StructLayout {
                    brand: brand.clone(),
                    fields: HashMap::new(),
                },
            );

            let mut concrete_fields = HashMap::new();
            for field in &template.fields {
                let substituted_type =
                    self.substitute_generics(&field.field_type, &substitution_map)?;
                let resolved_field_type = self.resolve_type(&substituted_type)?;
                concrete_fields.insert(field.name.clone(), resolved_field_type);
            }

            // Populate resolved layout fields [3]
            if let Some(layout) = self.struct_registry.get_mut(&concrete_name) {
                layout.fields = concrete_fields;
            }

            if brand.is_none()
                && let Some(layout) = self.struct_registry.get(&concrete_name)
            {
                for (field_name, field_type) in &layout.fields {
                    if (matches!(field_type, Type::Slice(_))
                        || *field_type == Type::ByteSlice
                        || *field_type == Type::Str)
                        && concrete_name != "errors__CompilerError"
                    {
                        return Err(TypeError {
                            kind: TypeErrorKind::BrandLifetimeViolation,
                            message: format!(
                                "Semantic Error: Unbranded monomorphized struct '{}' cannot contain ephemeral slice or view field '{}' of type '{:?}'",
                                concrete_name, field_name, field_type
                            ),
                            span: None,
                        });
                    }
                }
            }
        }

        Ok(Type::Struct(concrete_name, brand))
    }

    pub(crate) fn get_type_ident(&self, t: &Type) -> String {
        let base = match t {
            Type::Int => "int".to_string(),
            Type::Byte => "byte".to_string(),
            Type::Bool => "bool".to_string(),
            Type::Arena => "Arena".to_string(),
            Type::Void => "void".to_string(),
            Type::Str => "str".to_string(), // Added for String Views
            Type::RawPointer(inner) => format!("{}_ptr", self.get_type_ident(inner)),
            Type::Slice(inner) => format!("Slice_{}", self.get_type_ident(inner)),
            Type::Struct(name, _) => name.clone(),
            Type::Index(name, _) => format!("Index_{}", name),
            _ => "unknown".to_string(),
        };
        base.replace(".", "_")
    }

    pub(crate) fn get_monomorphized_name(&self, template_name: &str, args: &[Type]) -> String {
        let arg_names: Vec<String> = args.iter().map(|arg| self.get_type_ident(arg)).collect();
        let name = format!("{}_{}", template_name, arg_names.join("_"));
        name.replace(".", "_")
    }

    pub(crate) fn substitute_generics(
        &mut self,
        t: &Type,
        map: &HashMap<String, Type>,
    ) -> Result<Type, TypeError> {
        let substituted = match t {
            Type::Struct(name, brand) => {
                if let Some(substituted) = map.get(name) {
                    return Ok(substituted.clone());
                }
                let mut new_name = name.clone();
                let mut parts: Vec<String> = new_name.split('_').map(|s| s.to_string()).collect();
                let mut changed = false;
                for part in &mut parts {
                    if let Some(substituted_type) = map.get(part) {
                        *part = self.get_type_ident(substituted_type);
                        changed = true;
                    }
                }
                if changed {
                    new_name = parts.join("_");
                }

                if let Some(substituted) = map.get(&new_name) {
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
                    Type::Struct(new_name, new_brand)
                }
            }
            Type::Index(struct_name, brand) => {
                let mut new_struct = struct_name.clone();
                if let Some(substituted) = map.get(&new_struct) {
                    match substituted {
                        Type::Struct(name, _) => {
                            new_struct = name.clone();
                        }
                        _ => {
                            new_struct = self.get_type_ident(substituted);
                        }
                    }
                } else {
                    let mut parts: Vec<String> =
                        new_struct.split('_').map(|s| s.to_string()).collect();
                    let mut changed = false;
                    for part in &mut parts {
                        if let Some(substituted_type) = map.get(part) {
                            *part = self.get_type_ident(substituted_type);
                            changed = true;
                        }
                    }
                    if changed {
                        new_struct = parts.join("_");
                    }
                }

                let final_struct = if let Some(substituted) = map.get(&new_struct) {
                    match substituted {
                        Type::Struct(name, _) => name.clone(),
                        _ => new_struct.clone(),
                    }
                } else {
                    new_struct
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
                Type::Index(final_struct, new_brand)
            }
            Type::RawPointer(inner) => {
                Type::RawPointer(Box::new(self.substitute_generics(inner, map)?))
            }
            Type::Slice(inner) => Type::Slice(Box::new(self.substitute_generics(inner, map)?)),
            Type::Generic(name, args) => {
                let mut new_args = Vec::new();
                for arg in args {
                    new_args.push(self.substitute_generics(arg, map)?);
                }
                Type::Generic(name.clone(), new_args)
            }
            _ => t.clone(),
        };

        let resolved_namespaced = self.resolve_type_namespacing(&substituted)?;
        let resolved = self.resolve_type(&resolved_namespaced)?;
        Ok(resolved)
    }

    pub(crate) fn substitute_brand_names(&self, t: &Type, map: &HashMap<String, String>) -> Type {
        match t {
            Type::Index(struct_name, Some(brand)) => {
                let new_brand = map.get(brand).cloned().unwrap_or_else(|| brand.clone());
                let mut new_struct_name = struct_name.clone();
                if let Some(new_b) = map.get(brand) {
                    let old_b_clean = strip_brand_prefix(brand);
                    let new_b_clean = strip_brand_prefix(new_b);
                    let suffix = format!("_{}", old_b_clean);
                    let new_suffix = format!("_{}", new_b_clean);
                    if let Some(stripped) = new_struct_name.strip_suffix(&suffix) {
                        new_struct_name = format!("{}{}", stripped, new_suffix);
                    } else {
                        let suffix_full = format!("_{}", brand);
                        let new_suffix_full = format!("_{}", new_b);
                        if let Some(stripped) = new_struct_name.strip_suffix(&suffix_full) {
                            new_struct_name = format!("{}{}", stripped, new_suffix_full);
                        }
                    }
                } else {
                    let mut sorted_keys: Vec<&String> = map.keys().collect();
                    sorted_keys.sort_by_key(|k| std::cmp::Reverse(k.len()));
                    for old_b in sorted_keys {
                        let new_b = &map[old_b];
                        let suffix = format!("_{}", strip_brand_prefix(old_b));
                        let new_suffix = format!("_{}", strip_brand_prefix(new_b));
                        if let Some(stripped) = new_struct_name.strip_suffix(&suffix) {
                            new_struct_name = format!("{}{}", stripped, new_suffix);
                            break;
                        } else {
                            let suffix_full = format!("_{}", old_b);
                            let new_suffix_full = format!("_{}", new_b);
                            if let Some(stripped) = new_struct_name.strip_suffix(&suffix_full) {
                                new_struct_name = format!("{}{}", stripped, new_suffix_full);
                                break;
                            }
                        }
                    }
                }
                Type::Index(new_struct_name, Some(new_brand))
            }
            Type::Struct(struct_name, Some(brand)) => {
                let new_brand = map.get(brand).cloned().unwrap_or_else(|| brand.clone());
                let mut new_struct_name = struct_name.clone();
                if let Some(new_b) = map.get(brand) {
                    let old_b_clean = strip_brand_prefix(brand);
                    let new_b_clean = strip_brand_prefix(new_b);
                    let suffix = format!("_{}", old_b_clean);
                    let new_suffix = format!("_{}", new_b_clean);
                    if let Some(stripped) = new_struct_name.strip_suffix(&suffix) {
                        new_struct_name = format!("{}{}", stripped, new_suffix);
                    } else {
                        let suffix_full = format!("_{}", brand);
                        let new_suffix_full = format!("_{}", new_b);
                        if let Some(stripped) = new_struct_name.strip_suffix(&suffix_full) {
                            new_struct_name = format!("{}{}", stripped, new_suffix_full);
                        }
                    }
                } else {
                    let mut sorted_keys: Vec<&String> = map.keys().collect();
                    sorted_keys.sort_by_key(|k| std::cmp::Reverse(k.len()));
                    for old_b in sorted_keys {
                        let new_b = &map[old_b];
                        let suffix = format!("_{}", strip_brand_prefix(old_b));
                        let new_suffix = format!("_{}", strip_brand_prefix(new_b));
                        if let Some(stripped) = new_struct_name.strip_suffix(&suffix) {
                            new_struct_name = format!("{}{}", stripped, new_suffix);
                            break;
                        } else {
                            let suffix_full = format!("_{}", old_b);
                            let new_suffix_full = format!("_{}", new_b);
                            if let Some(stripped) = new_struct_name.strip_suffix(&suffix_full) {
                                new_struct_name = format!("{}{}", stripped, new_suffix_full);
                                break;
                            }
                        }
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
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::typechecker::Type;
    use std::collections::HashMap;

    #[test]
    fn test_structural_namespacing_on_substitution() {
        let mut checker = TypeChecker::new();
        checker.current_prefix = "my_module__".to_string();
        checker
            .imports
            .insert("std".to_string(), "std_".to_string());

        checker.struct_registry.insert(
            "my_module__LocalStruct".to_string(),
            crate::typechecker::StructLayout {
                brand: None,
                fields: HashMap::new(),
            },
        );

        // Nested generic placeholder std.Vector[std.Vector[T, ctx], ctx]
        let t_placeholder = Type::Generic(
            "std.Vector".to_string(),
            vec![
                Type::Generic(
                    "std.Vector".to_string(),
                    vec![
                        Type::Struct("T".to_string(), None),
                        Type::Struct("ctx".to_string(), None),
                    ],
                ),
                Type::Struct("ctx".to_string(), None),
            ],
        );

        let mut map = HashMap::new();
        map.insert(
            "T".to_string(),
            Type::Struct("LocalStruct".to_string(), None),
        );
        map.insert("ctx".to_string(), Type::Struct("ctx".to_string(), None));

        let res = checker.substitute_generics(&t_placeholder, &map);
        if let Err(ref e) = res {
            println!("❌ TypeChecker Substitution Error: {:?}", e);
        }
        assert!(res.is_ok());
        let substituted = res.unwrap();

        assert_eq!(
            substituted,
            Type::Struct(
                "std_Vector_std_Vector_my_module__LocalStruct_ctx_ctx".to_string(),
                Some("ctx".to_string())
            )
        );
    }

    #[test]
    fn test_substitute_nested_generics() {
        let mut checker = TypeChecker::new();
        checker.current_prefix = "my_module__".to_string();
        checker
            .imports
            .insert("std".to_string(), "std_".to_string());

        checker.struct_registry.insert(
            "my_module__MyNode".to_string(),
            crate::typechecker::StructLayout {
                brand: None,
                fields: HashMap::new(),
            },
        );

        // std.Vector[T, ctx]
        let t_generic = Type::Generic(
            "std.Vector".to_string(),
            vec![
                Type::Struct("T".to_string(), None),
                Type::Struct("ctx".to_string(), None),
            ],
        );

        let mut map = HashMap::new();
        map.insert("T".to_string(), Type::Struct("MyNode".to_string(), None));
        map.insert("ctx".to_string(), Type::Struct("ctx".to_string(), None));

        let res = checker.substitute_generics(&t_generic, &map);
        if let Err(ref e) = res {
            println!("❌ TypeChecker Substitution Error: {:?}", e);
        }
        assert!(res.is_ok());
        let substituted = res.unwrap();

        assert_eq!(
            substituted,
            Type::Struct(
                "std_Vector_my_module__MyNode_ctx".to_string(),
                Some("ctx".to_string())
            )
        );
    }

    #[test]
    fn test_substitute_pointer_and_slice() {
        let mut checker = TypeChecker::new();
        checker.current_prefix = "my_module__".to_string();

        checker.struct_registry.insert(
            "my_module__Item".to_string(),
            crate::typechecker::StructLayout {
                brand: None,
                fields: HashMap::new(),
            },
        );

        // *[]T
        let t_ptr = Type::RawPointer(Box::new(Type::Slice(Box::new(Type::Struct(
            "T".to_string(),
            None,
        )))));

        let mut map = HashMap::new();
        map.insert("T".to_string(), Type::Struct("Item".to_string(), None));

        let res = checker.substitute_generics(&t_ptr, &map);
        assert!(res.is_ok());
        let substituted = res.unwrap();

        assert_eq!(
            substituted,
            Type::RawPointer(Box::new(Type::Slice(Box::new(Type::Struct(
                "my_module__Item".to_string(),
                None
            )))))
        );
    }

    #[test]
    fn test_substitute_brand_recursive_structures() {
        let checker = TypeChecker::new();

        // 1. Generic type with branded struct arg
        let t_gen = Type::Generic(
            "std.Vector".to_string(),
            vec![
                Type::Struct("MyNode_ctx".to_string(), Some("ctx".to_string())),
                Type::Struct("ctx".to_string(), None),
            ],
        );

        let substituted = checker.substitute_brand(&t_gen, &Some("connCtx".to_string()));

        assert_eq!(
            substituted,
            Type::Generic(
                "std.Vector".to_string(),
                vec![
                    Type::Struct("MyNode_connCtx".to_string(), Some("connCtx".to_string())),
                    Type::Struct("ctx".to_string(), Some("connCtx".to_string())),
                ],
            )
        );
    }

    #[test]
    fn test_substitute_brand_deep_nested_pointer_slice() {
        let checker = TypeChecker::new();

        // Type: *[]MyNode_ctx
        let t_deep = Type::RawPointer(Box::new(Type::Slice(Box::new(Type::Struct(
            "MyNode_ctx".to_string(),
            Some("ctx".to_string()),
        )))));

        let substituted = checker.substitute_brand(&t_deep, &Some("connCtx".to_string()));

        assert_eq!(
            substituted,
            Type::RawPointer(Box::new(Type::Slice(Box::new(Type::Struct(
                "MyNode_connCtx".to_string(),
                Some("connCtx".to_string()),
            )))))
        );
    }

    #[test]
    fn test_substitute_brand_multi_layer_slice() {
        let checker = TypeChecker::new();

        // Type: [][]Item_old
        let t_slices = Type::Slice(Box::new(Type::Slice(Box::new(Type::Struct(
            "Item_old".to_string(),
            Some("old".to_string()),
        )))));

        let substituted = checker.substitute_brand(&t_slices, &Some("new".to_string()));

        assert_eq!(
            substituted,
            Type::Slice(Box::new(Type::Slice(Box::new(Type::Struct(
                "Item_new".to_string(),
                Some("new".to_string()),
            )))))
        );
    }

    #[test]
    fn test_substitute_brand_idempotency_primitives() {
        let checker = TypeChecker::new();

        assert_eq!(
            checker.substitute_brand(&Type::Int, &Some("ctx".to_string())),
            Type::Int
        );
        assert_eq!(
            checker.substitute_brand(&Type::Str, &Some("ctx".to_string())),
            Type::Str
        );
        assert_eq!(
            checker.substitute_brand(&Type::Arena, &Some("ctx".to_string())),
            Type::Arena
        );
    }

    #[test]
    fn test_generic_monomorphization_without_hardcoding() {
        let mut checker = TypeChecker::new();
        checker.current_prefix = "my_module__".to_string();

        // std.RcNode[int] monomorphization check (previously hardcoded, now generic!)
        let resolved = checker.resolve_type(&Type::Struct("std_RcNode_int".to_string(), None));
        assert!(resolved.is_ok());
        let res_type = resolved.unwrap();
        assert_eq!(res_type, Type::Struct("std_RcNode_int".to_string(), None));
        assert!(checker.struct_registry.contains_key("std_RcNode_int"));
    }

    #[test]
    fn test_monomorphization_without_string_patching() {
        let mut checker = TypeChecker::new();
        checker.current_prefix = "caller__".to_string();

        // Register 'std' in active imports
        checker
            .imports
            .insert("std".to_string(), "std_".to_string());
        // Register 'lib' in active imports
        checker
            .imports
            .insert("lib".to_string(), "lib_module__".to_string());

        // Snapshot 'caller__' imports
        checker
            .module_imports
            .insert("caller__".to_string(), checker.imports.clone());

        // Configure library imports in module_imports
        let mut lib_imports = HashMap::new();
        lib_imports.insert("std".to_string(), "std_".to_string());
        checker
            .module_imports
            .insert("lib_module__".to_string(), lib_imports);

        // Define a multi-layered nested generic std.Vector[lib_module__MyNode[ctx], ctx]
        let t_nested = Type::Generic(
            "std.Vector".to_string(),
            vec![
                Type::Struct("lib_module__MyNode".to_string(), Some("ctx".to_string())),
                Type::Struct("ctx".to_string(), None),
            ],
        );

        let mut map = HashMap::new();
        map.insert("ctx".to_string(), Type::Struct("ctx".to_string(), None));

        // substitute and resolve without any legacy string patching!
        let res = checker.substitute_generics(&t_nested, &map);
        if let Err(ref e) = res {
            println!("❌ TypeChecker Substitution Error: {:?}", e);
        }
        assert!(res.is_ok());
        let substituted = res.unwrap();

        // Verify that the fully-qualified flat name std_Vector_lib_module__MyNode_ctx is natively generated!
        assert_eq!(
            substituted,
            Type::Struct(
                "std_Vector_lib_module__MyNode_ctx".to_string(),
                Some("ctx".to_string())
            )
        );
    }
}
