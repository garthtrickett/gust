use super::TypeChecker;
use super::types::{StructLayout, Type, TypeError, TypeErrorKind};
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

    pub(crate) fn is_element_allowed_in_brand(&self, element: &Type, ob: &str) -> bool {
        if !self.is_linear(element) {
            return true;
        }
        if matches!(element, Type::Str | Type::Slice(_) | Type::ByteSlice) {
            return true;
        }
        if let Some(ib) = self.get_type_brand(element)
            && ib == ob {
                return true;
            }
        false
    }

    pub(crate) fn check_brand_hierarchy(&self, t: &Type, outer_brand: &Option<String>) -> Result<(), TypeError> {
        if let Some(ob) = outer_brand {
            if let Type::Struct(name, _) = t {
                if name != ob && !self.is_element_allowed_in_brand(t, ob) {
                    return Err(TypeError {
                        kind: TypeErrorKind::BrandLifetimeViolation,
                        message: format!( 
                            "Semantic Error: Brand Nesting Restriction violation. Element '{:?}' inside collection branded with '{}' must be copyable POD or branded with identical brand '{}'",
                            t, ob, ob
                        ),
                    });
                }
            }
            if let Type::Index(_, _) = t { 
                if !self.is_element_allowed_in_brand(t, ob) {
                    return Err(TypeError {
                        kind: TypeErrorKind::BrandLifetimeViolation,
                        message: format!( 
                            "Semantic Error: Brand Nesting Restriction violation. Element '{:?}' inside collection branded with '{}' must be copyable POD or branded with identical brand '{}'",
                            t, ob, ob
                        ),
                    });
                }
            }
        }

        match t {
            Type::Struct(name, inner_brand) => {
                if let Some(ib) = inner_brand
                    && let Some(ob) = outer_brand
                        && ib != ob {
                            return Err(TypeError {
                                kind: TypeErrorKind::BrandLifetimeViolation,
                                message: format!( 
                                    "Semantic Error: Mismatched nested brand. Outer brand is '{}', but nested type '{}' has brand '{}'",
                                    ob, name, ib
                                ),
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
            Type::Index(_, Some(brand)) => Some(brand.clone()),
            Type::Struct(_, Some(brand)) => Some(brand.clone()),
            Type::RawPointer(inner) => self.get_type_brand(inner),
            Type::Slice(inner) => self.get_type_brand(inner),
            _ => None,
        }
    }

    pub(crate) fn resolve_type(&mut self, t: &Type) -> Result<Type, TypeError> {
        match t {
            Type::Generic(name, args) => {
                let resolved_args: Result<Vec<Type>, TypeError> = 
                    args.iter().map(|arg| self.resolve_type(arg)).collect();
                self.monomorphize(name, &resolved_args?)
            }
            Type::Struct(name, brand) => {
                if name.starts_with("LookupResult_")
                    && !self.struct_registry.contains_key(name) {
                        let target_struct = name.trim_start_matches("LookupResult_").to_string();
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
                if let Some(brand_name) = brand {
                    if self.struct_templates.contains_key(name) {
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

    pub(crate) fn monomorphize(
        &mut self,
        template_name: &str,
        args: &[Type],
    ) -> Result<Type, TypeError> {
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
                    self.substitute_generics(&field.field_type, &substitution_map);
                let resolved_field_type = self.resolve_type(&substituted_type)?;
                concrete_fields.insert(field.name.clone(), resolved_field_type);
            }

            // Populate resolved layout fields [3]
            if let Some(layout) = self.struct_registry.get_mut(&concrete_name) {
                layout.fields = concrete_fields;
            }

            if brand.is_none()
                && let Some(layout) = self.struct_registry.get(&concrete_name) {
                    for (field_name, field_type) in &layout.fields {
                        if matches!(field_type, Type::Slice(_))
                            || *field_type == Type::ByteSlice
                            || *field_type == Type::Str
                        {
                            return Err(TypeError {
                                kind: TypeErrorKind::BrandLifetimeViolation,
                                message: format!( 
                                    "Semantic Error: Unbranded monomorphized struct '{}' cannot contain ephemeral slice or view field '{}' of type '{:?}'",
                                    concrete_name, field_name, field_type
                                ),
                            });
                        }
                    }
                }
        }

        Ok(Type::Struct(concrete_name, brand))
    }

    pub(crate) fn get_type_ident(&self, t: &Type) -> String {
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

    pub(crate) fn get_monomorphized_name(&self, template_name: &str, args: &[Type]) -> String {
        let arg_names: Vec<String> = args.iter().map(|arg| self.get_type_ident(arg)).collect();
        format!("{}_{}", template_name, arg_names.join("_"))
    }

    pub(crate) fn substitute_generics(&self, t: &Type, map: &HashMap<String, Type>) -> Type {
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
