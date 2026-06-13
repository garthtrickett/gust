use super::TypeChecker;
use super::types::{StructLayout, Type, TypeError, TypeErrorKind, strip_brand_prefix};
use std::collections::HashMap;

impl TypeChecker {
    pub(crate) fn substitute_brand(&self, t: &Type, new_brand: &Option<String>) -> Type {
        match t {
            Type::Index(struct_name, _)
                => Type::Index(struct_name.clone(), new_brand.clone()),
            Type::Struct(struct_name, _)
                => Type::Struct(struct_name.clone(), new_brand.clone()),
            Type::RawPointer(inner) => {
                Type::RawPointer(Box::new(self.substitute_brand(inner, new_brand)))
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
            Type::RawPointer(inner) => {
                Type::RawPointer(Box::new(self.substitute_field_brand(inner, struct_brand, parent_path, layout)))
            }
            Type::Slice(inner) => {
                Type::Slice(Box::new(self.substitute_field_brand(inner, struct_brand, parent_path, layout)))
            }
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
        if let Some(ib) = self.get_type_brand(element)
            && strip_brand_prefix(&ib) == strip_brand_prefix(ob) {
                return true;
            }
        false
    }

    pub(crate) fn check_brand_hierarchy(&self, t: &Type, outer_brand: &Option<String>) -> Result<(), TypeError> {
        if let Some(ob) = outer_brand {
            if let Type::Struct(name, _) = t
                && strip_brand_prefix(name) != strip_brand_prefix(ob) && !self.is_element_allowed_in_brand(t, ob) {
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
                && !self.is_element_allowed_in_brand(t, ob) {
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
                        && strip_brand_prefix(ib) != strip_brand_prefix(ob) { 
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
                        && ib != ob {
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
                let clean_name = strip_brand_prefix(name);
                if clean_name.starts_with("LookupResult_")
                    && !self.struct_registry.contains_key(name) {
                        let target_struct = clean_name.strip_prefix("LookupResult_").unwrap_or(clean_name).to_string();
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

                if clean_name.starts_with("CastResult_")
                    && !self.struct_registry.contains_key(name) {
                        let target_struct = clean_name.strip_prefix("CastResult_").unwrap_or(clean_name).to_string();
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

                if (name.starts_with("RcNode_") || name.starts_with("std_RcNode_"))
                    && !self.struct_registry.contains_key(name) {
                        let inner_t_name = if let Some(stripped) = name.strip_prefix("RcNode_") {
                            stripped
                        } else {
                            name.strip_prefix("std_RcNode_").unwrap_or(name)
                        };
                        let inner_t = if inner_t_name == "int" {
                            Type::Int
                        } else if inner_t_name == "byte" {
                            Type::Byte
                        } else if inner_t_name == "bool" {
                            Type::Bool
                        } else {
                            Type::Struct(inner_t_name.to_string(), None)
                        };
                        let template = if name.starts_with("RcNode_") { "RcNode" } else { "std.RcNode" };
                        let _ = self.monomorphize(template, &[inner_t]);
                    }

                if (name.starts_with("GraphNode_") || name.starts_with("std_GraphNode_"))
                    && !self.struct_registry.contains_key(name) {
                        let suffix = if let Some(stripped) = name.strip_prefix("GraphNode_") {
                            stripped
                        } else {
                            name.strip_prefix("std_GraphNode_").unwrap_or(name)
                        };
                        let normalized = suffix.replace("__", "@");
                        let parts: Vec<&str> = normalized.split('_').collect();
                        if parts.len() == 2 {
                            let inner_t_name = parts[0].replace("@", "__");
                            let ctx_name = parts[1].replace("@", "__");
                            let inner_t = if inner_t_name == "int" {
                                Type::Int
                            } else if inner_t_name == "byte" {
                                Type::Byte
                            } else {
                                Type::Struct(inner_t_name, None)
                            };
                            let ctx_t = Type::Struct(ctx_name, None);
                            let template = if name.starts_with("GraphNode_") { "GraphNode" } else { "std.GraphNode" };
                            let _ = self.monomorphize(template, &[inner_t, ctx_t]);
                        }
                    }

                if (name.starts_with("ThreadLocalContext_") || name.starts_with("std_ThreadLocalContext_"))
                    && !self.struct_registry.contains_key(name) {
                        let suffix = if let Some(stripped) = name.strip_prefix("ThreadLocalContext_") {
                            stripped
                        } else {
                            name.strip_prefix("std_ThreadLocalContext_").unwrap_or(name)
                        };
                        let ctx_t = Type::Struct(suffix.to_string(), None);
                        let template = if name.starts_with("ThreadLocalContext_") { "ThreadLocalContext" } else { "std.ThreadLocalContext" };
                        let _ = self.monomorphize(template, &[ctx_t]);
                    }

                if let Some(brand_name) = brand {
                    if self.struct_templates.contains_key(name) || self.enum_templates.contains_key(name) {
                        let args = vec![Type::Struct(brand_name.clone(), None)];
                        self.monomorphize(name, &args)
                    } else {
                        Ok(t.clone())
                    }
                } else {
                    Ok(t.clone())
                }
            }
            Type::Index(struct_name, Some(brand)) => {
                if self.struct_templates.contains_key(struct_name) || self.enum_templates.contains_key(struct_name) {
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

    pub(crate) fn monomorphize(
        &mut self,
        template_name: &str,
        args: &[Type],
    ) -> Result<Type, TypeError> {
        if self.enum_templates.contains_key(template_name) {
            let template = self
                .enum_templates
                .get(template_name)
                .cloned()
                .unwrap();

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
                if (generic_name == "ctx" || generic_name == "connCtx" || generic_name == "arena" || generic_name == "a")
                    && let Type::Struct(brand_name, _) = arg {
                        brand = Some(brand_name.clone());
                    }
            }

            for arg in args {
                self.check_brand_hierarchy(arg, &brand)?;
            }

            if !self.struct_registry.contains_key(&concrete_name) {
                let old_prefix = self.current_prefix.clone();
                if let Some(pos) = template_name.rfind("__") {
                    self.current_prefix = template_name[..pos + 2].to_string();
                }

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
                self.enum_registry.insert(concrete_name.clone(), concrete_variants);

                let mut enum_fields = HashMap::new();
                enum_fields.insert("tag".to_string(), Type::Int);

                for variant in &template.variants {
                    let concrete_variant_struct_name = format!("{}_{}", concrete_name, variant.name);
                    let mut variant_fields = HashMap::new();
                    for field in &variant.fields {
                        let substituted_type =
                            self.substitute_generics(&field.field_type, &substitution_map);
                        let resolved_field_type = match self.resolve_type(&substituted_type) {
                            Ok(t) => t,
                            Err(e) => {
                                self.current_prefix = old_prefix;
                                return Err(e);
                            }
                        };
                        let resolved_field_type = match self.resolve_type_namespacing(&resolved_field_type) {
                            Ok(t) => t,
                            Err(e) => {
                                self.current_prefix = old_prefix;
                                return Err(e);
                            }
                        };

                        if let Type::Struct(ref struct_name, _) = resolved_field_type
                            && let Some(layout) = self.struct_registry.get(struct_name)
                            && layout.fields.len() > 2
                        { 
                            eprintln!("====================================================");
                            eprintln!("❌ LARGE ENUM VARIANT PAYLOAD DIAGNOSTIC DETECTED");
                            eprintln!("====================================================");
                            eprintln!("Concrete Enum Name:  {}", concrete_name);
                            eprintln!("Variant Name:       {}", variant.name);
                            eprintln!("Payload Struct:     {}", struct_name);
                            eprintln!("Total Fields Count: {}", layout.fields.len());
                            eprintln!("----------------------------------------------------");
                            eprintln!("Registered Fields:");
                            let mut sorted_fields: Vec<(&String, &Type)> = layout.fields.iter().collect();
                            sorted_fields.sort_by(|a, b| a.0.cmp(b.0));
                            for (f_name, f_type) in sorted_fields {
                                eprintln!("  - {}: {:?}", f_name, f_type);
                            }
                            eprintln!("====================================================");

                            self.current_prefix = old_prefix;
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

                self.current_prefix = old_prefix;

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
            if (generic_name == "ctx" || generic_name == "connCtx" || generic_name == "arena" || generic_name == "a")
                && let Type::Struct(brand_name, _) = arg {
                    brand = Some(brand_name.clone());
                }
        }

        for arg in args {
            self.check_brand_hierarchy(arg, &brand)?;
        }

        if !self.struct_registry.contains_key(&concrete_name) {
            // Temporarily override the current_prefix to the template's defining namespace.
            // This ensures that nested field types (such as module-local enum types) resolve
            // within the context where the template was defined, rather than the caller's context.
            let old_prefix = self.current_prefix.clone();
            if let Some(pos) = template_name.rfind("__") {
                self.current_prefix = template_name[..pos + 2].to_string();
            }

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
                    self.substitute_generics(&field.field_type, &substitution_map);
                let resolved_field_type = match self.resolve_type(&substituted_type) {
                    Ok(t) => t,
                    Err(e) => {
                        self.current_prefix = old_prefix;
                        return Err(e);
                    }
                };
                concrete_fields.insert(field.name.clone(), resolved_field_type);
            }

            self.current_prefix = old_prefix;

            // Populate resolved layout fields [3]
            if let Some(layout) = self.struct_registry.get_mut(&concrete_name) {
                layout.fields = concrete_fields;
            }

            if brand.is_none()
                && let Some(layout) = self.struct_registry.get(&concrete_name) {
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

    pub(crate) fn substitute_generics(&self, t: &Type, map: &HashMap<String, Type>) -> Type {
        match t {
            Type::Struct(name, brand) => {
                let mut new_name = name.clone();
                if new_name == "RcNode_T" || new_name == "std_RcNode_T" {
                    if let Some(substituted_t) = map.get("T") {
                        let t_ident = self.get_type_ident(substituted_t);
                        new_name = if name == "RcNode_T" {
                            format!("RcNode_{}", t_ident)
                        } else {
                            format!("std_RcNode_{}", t_ident)
            };
                    }
                } else if (new_name == "GraphNode_T_ctx" || new_name == "std_GraphNode_T_ctx")
                    && let Some(substituted_t) = map.get("T")
                        && let Some(substituted_ctx) = map.get("ctx") {
                            let t_ident = self.get_type_ident(substituted_t);
                            let ctx_ident = self.get_type_ident(substituted_ctx);
                            new_name = if name == "GraphNode_T_ctx" {
                                format!("GraphNode_{}_{}", t_ident, ctx_ident)
                            } else {
                                format!("std_GraphNode_{}_{}", t_ident, ctx_ident)
                            };
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
                if new_struct == "RcNode_T" || new_struct == "std_RcNode_T" {
                    if let Some(substituted_t) = map.get("T") {
                        let t_ident = self.get_type_ident(substituted_t);
                        new_struct = if struct_name == "RcNode_T" {
                            format!("RcNode_{}", t_ident)
                        } else {
                            format!("std_RcNode_{}", t_ident)
                        };
                    }
                } else if (new_struct == "GraphNode_T_ctx" || new_struct == "std_GraphNode_T_ctx")
                    && let Some(substituted_t) = map.get("T")
                        && let Some(substituted_ctx) = map.get("ctx") {
                            let t_ident = self.get_type_ident(substituted_t);
                            let ctx_ident = self.get_type_ident(substituted_ctx);
                            new_struct = if struct_name == "GraphNode_T_ctx" {
                                format!("GraphNode_{}_{}", t_ident, ctx_ident)
                            } else {
                                format!("std_GraphNode_{}_{}", t_ident, ctx_ident)
                            };
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
                Type::RawPointer(Box::new(self.substitute_generics(inner, map)))
            }
            Type::Slice(inner) => Type::Slice(Box::new(self.substitute_generics(inner, map))),
            Type::Generic(name, args) => {
                let new_args: Vec<Type> = args
                    .iter()
                    .map(|arg| self.substitute_generics(arg, map))
                    .collect();
                Type::Generic(name.clone(), new_args)
            }
            _ => t.clone(),
        }
    }

    pub(crate) fn substitute_brand_names(&self, t: &Type, map: &HashMap<String, String>) -> Type {
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
                    let suffix_2 = format!("_{}", new_b);
                    if new_struct_name.ends_with(&suffix) {
                        new_struct_name =
                            format!("{}{}", new_struct_name.trim_end_matches(&suffix), suffix_2);
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
