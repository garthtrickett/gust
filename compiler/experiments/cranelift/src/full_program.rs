use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fs;
use std::io::{Error as IoError, ErrorKind};
use std::path::{Path, PathBuf};

use cranelift_codegen::ir::{
    condcodes::IntCC, types, AbiParam, ArgumentPurpose, Block, InstBuilder, MemFlags,
    StackSlotData, StackSlotKind, Type, Value,
};
use cranelift_codegen::settings::{self, Configurable};
use cranelift_frontend::{FunctionBuilder, FunctionBuilderContext};
use cranelift_module::{default_libcall_names, DataDescription, DataId, FuncId, Linkage, Module};
use cranelift_object::{ObjectBuilder, ObjectModule};

pub const FORMAT: &str = "gust.compiler_executable_mir.v1";

#[derive(Debug, Clone)]
pub struct LayoutField {
    pub name: String,
    pub ty: String,
}

#[derive(Debug, Clone)]
pub struct Layout {
    pub name: String,
    pub erased_name: String,
    pub brand: String,
    pub repr_c: bool,
    pub packed: bool,
    pub abi: String,
    pub fields: Vec<LayoutField>,
}

#[derive(Debug, Clone)]
pub struct Enumeration {
    pub name: String,
    pub erased_name: String,
    pub variants: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct Function {
    pub module_index: usize,
    pub source_name: String,
    pub qualified_name: String,
    pub is_extern: bool,
    pub extern_symbol: String,
    pub result_type: String,
    pub body_node: Option<usize>,
    pub parameters: Vec<(String, String)>,
}

#[derive(Debug, Clone)]
pub struct Node {
    pub kind: String,
    pub ty: String,
    pub text: String,
    pub second_text: String,
    pub integer: i32,
    pub second_integer: i32,
    pub source_line: usize,
    pub source_column: usize,
    pub source_start: usize,
    pub source_end: usize,
    pub children: Vec<usize>,
}

#[derive(Debug)]
pub struct Program {
    pub target_triple: String,
    pub object_format: String,
    pub modules: Vec<(String, String)>,
    pub layouts: Vec<Layout>,
    pub enumerations: Vec<Enumeration>,
    pub functions: Vec<Function>,
    pub nodes: Vec<Node>,
    pub entry_function: usize,
}

#[derive(Debug, Clone)]
struct FieldPlacement {
    offset: u32,
    ty: String,
}

#[derive(Debug, Clone)]
struct TypeLayout {
    size: u32,
    align: u32,
    fields: HashMap<String, FieldPlacement>,
}

fn align_to(value: u32, alignment: u32) -> Result<u32, Box<dyn Error>> {
    if alignment == 0 || !alignment.is_power_of_two() {
        return Err(invalid(
            "full-program layout has a non-power-of-two alignment",
        ));
    }
    value
        .checked_add(alignment - 1)
        .map(|sum| sum & !(alignment - 1))
        .ok_or_else(|| invalid("full-program layout size overflows u32"))
}

fn quoted_type_name(value: &str, prefix: &str) -> Option<String> {
    value
        .strip_prefix(prefix)
        .and_then(|tail| tail.split_once('"'))
        .map(|(name, _)| name.to_string())
}

fn struct_type_name(value: &str) -> Option<String> {
    quoted_type_name(value, "Struct(\"")
}

fn index_element_type_name(value: &str) -> Option<String> {
    quoted_type_name(value, "Index(\"")
}

fn index_element_layout_type(value: &str) -> Result<String, Box<dyn Error>> {
    let element = index_element_type_name(value)
        .ok_or_else(|| invalid(format!("full-program index type is malformed: {value}")))?;
    Ok(match element.as_str() {
        "int" => "Int".to_string(),
        "str" => "Str".to_string(),
        "byte" => "Byte".to_string(),
        other => format!("Struct(\"{other}\", None)"),
    })
}

fn pointer_inner_type(value: &str) -> Option<&str> {
    for prefix in ["RawPointer(", "Reference("] {
        if let Some(tail) = value.strip_prefix(prefix) {
            let mut nesting = 0usize;
            let mut in_string = false;
            let mut escaped = false;
            for (index, character) in tail.char_indices() {
                if in_string {
                    if escaped {
                        escaped = false;
                    } else if character == '\\' {
                        escaped = true;
                    } else if character == '"' {
                        in_string = false;
                    }
                    continue;
                }
                match character {
                    '"' => in_string = true,
                    '(' => nesting += 1,
                    ')' if nesting == 0 => return Some(&tail[..index]),
                    ')' => nesting -= 1,
                    ',' if prefix == "Reference(" && nesting == 0 => return Some(&tail[..index]),
                    _ => {}
                }
            }
        }
    }
    None
}

fn is_pointer_type(value: &str) -> bool {
    value.starts_with("RawPointer(") || value.starts_with("Reference(")
}

fn is_scalar_type(value: &str) -> bool {
    matches!(value, "Int" | "Byte" | "Bool")
        || value.starts_with("Index(\"")
        || is_pointer_type(value)
}

fn scalar_ir_type(value: &str, pointer_type: Type) -> Result<Type, Box<dyn Error>> {
    if value == "Int" || value.starts_with("Index(\"") {
        Ok(types::I32)
    } else if matches!(value, "Byte" | "Bool") {
        Ok(types::I8)
    } else if is_pointer_type(value) {
        Ok(pointer_type)
    } else {
        Err(invalid(format!("full-program type {value} is not scalar")))
    }
}

struct LayoutEngine<'a> {
    layouts: HashMap<&'a str, &'a Layout>,
    enums: HashMap<&'a str, &'a Enumeration>,
    cache: HashMap<String, TypeLayout>,
    active: HashSet<String>,
    pointer_size: u32,
}

impl<'a> LayoutEngine<'a> {
    fn new(program: &'a Program, pointer_size: u32) -> Self {
        Self {
            layouts: program
                .layouts
                .iter()
                .map(|layout| (layout.erased_name.as_str(), layout))
                .collect(),
            enums: program
                .enumerations
                .iter()
                .map(|enumeration| (enumeration.erased_name.as_str(), enumeration))
                .collect(),
            cache: HashMap::new(),
            active: HashSet::new(),
            pointer_size,
        }
    }

    fn layout(&mut self, ty: &str) -> Result<TypeLayout, Box<dyn Error>> {
        if let Some(cached) = self.cache.get(ty) {
            return Ok(cached.clone());
        }
        if !self.active.insert(ty.to_string()) {
            return Err(invalid(format!(
                "recursive by-value full-program type {ty}"
            )));
        }
        let result = self.layout_uncached(ty);
        self.active.remove(ty);
        let result = result?;
        self.cache.insert(ty.to_string(), result.clone());
        Ok(result)
    }

    fn layout_uncached(&mut self, ty: &str) -> Result<TypeLayout, Box<dyn Error>> {
        let scalar = |size, align| TypeLayout {
            size,
            align,
            fields: HashMap::new(),
        };
        match ty {
            "Void" => return Ok(scalar(0, 1)),
            "Int" => return Ok(scalar(4, 4)),
            "Byte" | "Bool" => return Ok(scalar(1, 1)),
            "Arena" => return Ok(scalar(self.pointer_size * 3, self.pointer_size)),
            "Str" => {
                return Ok(scalar(
                    align_to(self.pointer_size + 4, self.pointer_size)?,
                    self.pointer_size,
                ));
            }
            _ => {}
        }
        if ty.starts_with("Index(\"") {
            return Ok(scalar(4, 4));
        }
        if is_pointer_type(ty) {
            return Ok(scalar(self.pointer_size, self.pointer_size));
        }
        let Some(name) = struct_type_name(ty) else {
            return Err(invalid(format!(
                "full-program type has no layout authority: {ty}"
            )));
        };
        let Some(layout) = self.layouts.get(name.as_str()).copied() else {
            return Err(invalid(format!(
                "full-program struct lacks layout authority: {name}"
            )));
        };
        if let Some(enumeration) = self.enums.get(name.as_str()).copied() {
            return self.enum_layout(layout, enumeration);
        }
        self.struct_layout(layout)
    }

    fn struct_layout(&mut self, layout: &Layout) -> Result<TypeLayout, Box<dyn Error>> {
        let mut offset = 0u32;
        let mut aggregate_align = if layout.packed { 1 } else { 1u32 };
        let mut fields = HashMap::new();
        for field in &layout.fields {
            let field_layout = self.layout(&field.ty)?;
            let field_align = if layout.packed { 1 } else { field_layout.align };
            offset = align_to(offset, field_align)?;
            fields.insert(
                field.name.clone(),
                FieldPlacement {
                    offset,
                    ty: field.ty.clone(),
                },
            );
            offset = offset
                .checked_add(field_layout.size)
                .ok_or_else(|| invalid("full-program struct layout size overflows u32"))?;
            aggregate_align = aggregate_align.max(field_align);
        }
        let size = if layout.fields.is_empty() {
            1
        } else {
            align_to(offset, aggregate_align)?
        };
        Ok(TypeLayout {
            size,
            align: aggregate_align,
            fields,
        })
    }

    fn enum_layout(
        &mut self,
        layout: &Layout,
        enumeration: &Enumeration,
    ) -> Result<TypeLayout, Box<dyn Error>> {
        let mut payload_size = 0u32;
        let mut payload_align = 1u32;
        let mut variant_types = HashMap::new();
        for variant in &enumeration.variants {
            let field = layout
                .fields
                .iter()
                .find(|field| field.name == *variant)
                .ok_or_else(|| invalid("full-program enum variant lacks its payload type"))?;
            let variant_layout = self.layout(&field.ty)?;
            payload_size = payload_size.max(variant_layout.size);
            payload_align = payload_align.max(variant_layout.align);
            variant_types.insert(variant.clone(), field.ty.clone());
        }
        let aggregate_align = 4u32.max(payload_align);
        let payload_offset = align_to(4, payload_align)?;
        let size = align_to(
            payload_offset
                .checked_add(payload_size)
                .ok_or_else(|| invalid("full-program enum layout size overflows u32"))?,
            aggregate_align,
        )?;
        let mut fields = HashMap::new();
        fields.insert(
            "tag".to_string(),
            FieldPlacement {
                offset: 0,
                ty: "Int".to_string(),
            },
        );
        for (variant, ty) in variant_types {
            fields.insert(
                variant,
                FieldPlacement {
                    offset: payload_offset,
                    ty,
                },
            );
        }
        Ok(TypeLayout {
            size: size.max(4),
            align: aggregate_align,
            fields,
        })
    }
}

#[derive(Debug, Clone, Copy)]
enum AbiShape {
    Void,
    Scalar(Type),
    AggregateOne,
    AggregateTwo,
    AggregateMemory(u32),
    ArenaParameter,
}

fn abi_shape(
    ty: &str,
    parameter: bool,
    pointer_type: Type,
    layouts: &mut LayoutEngine<'_>,
) -> Result<AbiShape, Box<dyn Error>> {
    if ty == "Void" {
        return Ok(AbiShape::Void);
    }
    if parameter && ty == "Arena" {
        return Ok(AbiShape::ArenaParameter);
    }
    if is_scalar_type(ty) {
        return Ok(AbiShape::Scalar(scalar_ir_type(ty, pointer_type)?));
    }
    let layout = layouts.layout(ty)?;
    if layout.size <= 8 {
        Ok(AbiShape::AggregateOne)
    } else if layout.size <= 16 {
        Ok(AbiShape::AggregateTwo)
    } else {
        Ok(AbiShape::AggregateMemory(align_to(layout.size, 8)?))
    }
}

#[derive(Debug, Clone)]
struct FunctionAbi {
    result: AbiShape,
    parameters: Vec<AbiShape>,
}

fn function_signature(
    module: &ObjectModule,
    function: &Function,
    layouts: &mut LayoutEngine<'_>,
) -> Result<(cranelift_codegen::ir::Signature, FunctionAbi), Box<dyn Error>> {
    let pointer_type = module.target_config().pointer_type();
    let result = abi_shape(&function.result_type, false, pointer_type, layouts)?;
    let mut signature = module.make_signature();
    if let AbiShape::AggregateMemory(_) = result {
        signature.params.push(AbiParam::special(
            pointer_type,
            ArgumentPurpose::StructReturn,
        ));
    }
    let mut parameters = Vec::with_capacity(function.parameters.len());
    for (_, parameter_type) in &function.parameters {
        let shape = abi_shape(parameter_type, true, pointer_type, layouts)?;
        match shape {
            AbiShape::Void => {
                return Err(invalid("full-program function has a void parameter"));
            }
            AbiShape::Scalar(ty) => signature.params.push(AbiParam::new(ty)),
            AbiShape::ArenaParameter => signature.params.push(AbiParam::new(pointer_type)),
            AbiShape::AggregateOne => signature.params.push(AbiParam::new(types::I64)),
            AbiShape::AggregateTwo => {
                signature.params.push(AbiParam::new(types::I64));
                signature.params.push(AbiParam::new(types::I64));
            }
            AbiShape::AggregateMemory(size) => signature.params.push(AbiParam::special(
                pointer_type,
                ArgumentPurpose::StructArgument(size),
            )),
        }
        parameters.push(shape);
    }
    match result {
        AbiShape::Void | AbiShape::AggregateMemory(_) => {}
        AbiShape::Scalar(ty) => signature.returns.push(AbiParam::new(ty)),
        AbiShape::AggregateOne => signature.returns.push(AbiParam::new(types::I64)),
        AbiShape::AggregateTwo => {
            signature.returns.push(AbiParam::new(types::I64));
            signature.returns.push(AbiParam::new(types::I64));
        }
        AbiShape::ArenaParameter => unreachable!("ArenaParameter is parameter-only"),
    }
    Ok((signature, FunctionAbi { result, parameters }))
}

fn target_object_builder(program: &Program) -> Result<ObjectBuilder, Box<dyn Error>> {
    let mut flag_builder = settings::builder();
    flag_builder.set("is_pic", "true")?;
    let flags = settings::Flags::new(flag_builder);
    let isa_builder = cranelift_native::builder()
        .map_err(|message| IoError::new(ErrorKind::Unsupported, message))?;
    let isa = isa_builder.finish(flags)?;
    let actual_triple = isa.triple().to_string();
    let actual_format = format!("{:?}", isa.triple().binary_format);
    if actual_triple != program.target_triple || actual_format != program.object_format {
        return Err(invalid(format!(
            "full-program target authority mismatch: canonical={}/{} worker={actual_triple}/{actual_format}",
            program.target_triple, program.object_format
        )));
    }
    if isa.pointer_bits() != 64 || !actual_triple.starts_with("x86_64-") {
        return Err(invalid(
            "full-program Phase 14-16 aggregate ABI projection requires the registered x86_64 64-bit target",
        ));
    }
    Ok(ObjectBuilder::new(
        isa,
        "gust_phase21_full_compiler",
        default_libcall_names(),
    )?)
}

#[derive(Clone, Copy)]
struct Place {
    address: Value,
}

#[derive(Clone, Copy)]
enum Evaluated {
    Void,
    Scalar(Value),
    Aggregate(Place),
}

#[derive(Clone)]
struct Local {
    place: Place,
}

fn make_stack_place(
    builder: &mut FunctionBuilder<'_>,
    layout: &TypeLayout,
    pointer_type: Type,
) -> Result<Place, Box<dyn Error>> {
    let slot_size = align_to(layout.size.max(1), 8)?;
    let slot = builder.create_sized_stack_slot(StackSlotData::new(
        StackSlotKind::ExplicitSlot,
        slot_size,
        layout.align.trailing_zeros() as u8,
    ));
    Ok(Place {
        address: builder.ins().stack_addr(pointer_type, slot, 0),
    })
}

fn load_scalar(
    builder: &mut FunctionBuilder<'_>,
    address: Value,
    ty: &str,
    pointer_type: Type,
) -> Result<Value, Box<dyn Error>> {
    Ok(builder.ins().load(
        scalar_ir_type(ty, pointer_type)?,
        MemFlags::trusted(),
        address,
        0,
    ))
}

fn store_scalar(builder: &mut FunctionBuilder<'_>, address: Value, value: Value) {
    builder.ins().store(MemFlags::trusted(), value, address, 0);
}

fn add_offset(builder: &mut FunctionBuilder<'_>, address: Value, offset: u32) -> Value {
    if offset == 0 {
        address
    } else {
        builder.ins().iadd_imm(address, i64::from(offset))
    }
}

fn as_condition(builder: &mut FunctionBuilder<'_>, value: Value) -> Value {
    builder.ins().icmp_imm(IntCC::NotEqual, value, 0)
}

fn invalid(message: impl Into<String>) -> Box<dyn Error> {
    IoError::new(ErrorKind::InvalidData, message.into()).into()
}

fn decode_hex(value: &str, field: &str) -> Result<String, Box<dyn Error>> {
    if value.len() % 2 != 0 {
        return Err(invalid(format!("{field} has odd-length UTF-8 hex")));
    }
    let mut bytes = Vec::with_capacity(value.len() / 2);
    for pair in value.as_bytes().chunks_exact(2) {
        let digit = |byte: u8| -> Option<u8> {
            match byte {
                b'0'..=b'9' => Some(byte - b'0'),
                b'a'..=b'f' => Some(byte - b'a' + 10),
                _ => None,
            }
        };
        let high =
            digit(pair[0]).ok_or_else(|| invalid(format!("{field} is not lowercase hex")))?;
        let low = digit(pair[1]).ok_or_else(|| invalid(format!("{field} is not lowercase hex")))?;
        bytes.push((high << 4) | low);
    }
    String::from_utf8(bytes).map_err(|_| invalid(format!("{field} is not UTF-8")))
}

fn parse_usize(value: &str, field: &str) -> Result<usize, Box<dyn Error>> {
    value
        .parse::<usize>()
        .map_err(|_| invalid(format!("{field} is not a canonical non-negative integer")))
}

fn parse_i32(value: &str, field: &str) -> Result<i32, Box<dyn Error>> {
    value
        .parse::<i32>()
        .map_err(|_| invalid(format!("{field} is not a canonical i32")))
}

fn parse_bool(value: &str, field: &str) -> Result<bool, Box<dyn Error>> {
    match value {
        "0" => Ok(false),
        "1" => Ok(true),
        _ => Err(invalid(format!("{field} is not 0 or 1"))),
    }
}

fn field<'a>(line: &'a str, prefix: &str) -> Result<&'a str, Box<dyn Error>> {
    line.strip_prefix(prefix)
        .ok_or_else(|| invalid(format!("expected {prefix}")))
}

fn next_line<'a>(
    lines: &mut impl Iterator<Item = &'a str>,
    expected: &str,
) -> Result<&'a str, Box<dyn Error>> {
    lines
        .next()
        .ok_or_else(|| invalid(format!("missing {expected}")))
}

fn validate_type(value: &str, field_name: &str) -> Result<(), Box<dyn Error>> {
    if value.is_empty()
        || value == "Unknown"
        || value
            .chars()
            .any(|character| matches!(character, '\n' | '\r' | '\0'))
    {
        return Err(invalid(format!(
            "{field_name} has an invalid canonical type identity"
        )));
    }
    let primitive = matches!(value, "Int" | "Byte" | "Bool" | "Void" | "Arena" | "Str");
    if !primitive
        && !value.starts_with("Slice(")
        && !value.starts_with("Index(\"")
        && !value.starts_with("Struct(\"")
        && !value.starts_with("RawPointer(")
        && !value.starts_with("Reference(")
        && !value.starts_with("Generic(\"")
    {
        return Err(invalid(format!(
            "{field_name} uses an unknown canonical type form: {value}"
        )));
    }
    Ok(())
}

pub fn parse(contents: &str) -> Result<Program, Box<dyn Error>> {
    if contents.contains('\r') || contents.contains('\0') {
        return Err(invalid("full-program canonical MIR contains CR or NUL"));
    }
    let mut lines = contents.lines();
    let format = field(next_line(&mut lines, "format")?, "format: ")?;
    if format != FORMAT {
        return Err(invalid(format!("unsupported full-program format {format}")));
    }
    let target_triple = decode_hex(
        field(
            next_line(&mut lines, "target triple")?,
            "target_triple_utf8_hex: ",
        )?,
        "target_triple_utf8_hex",
    )?;
    let object_format = decode_hex(
        field(
            next_line(&mut lines, "object format")?,
            "object_format_utf8_hex: ",
        )?,
        "object_format_utf8_hex",
    )?;
    if target_triple.is_empty() || object_format.is_empty() {
        return Err(invalid("full-program target authority is empty"));
    }

    let module_count = parse_usize(
        field(next_line(&mut lines, "module count")?, "module_count: ")?,
        "module_count",
    )?;
    if module_count == 0 {
        return Err(invalid("full-program module_count is zero"));
    }
    let mut modules = Vec::with_capacity(module_count);
    for expected_index in 0..module_count {
        let values: Vec<_> = field(next_line(&mut lines, "module row")?, "module: ")?
            .split('|')
            .collect();
        if values.len() != 3 || parse_usize(values[0], "module index")? != expected_index {
            return Err(invalid("full-program module rows are not contiguous"));
        }
        let path = decode_hex(values[1], "module path")?;
        let prefix = decode_hex(values[2], "module prefix")?;
        if path.is_empty() {
            return Err(invalid("full-program module path is empty"));
        }
        modules.push((path, prefix));
    }

    let layout_count = parse_usize(
        field(next_line(&mut lines, "layout count")?, "layout_count: ")?,
        "layout_count",
    )?;
    let mut layouts = Vec::with_capacity(layout_count);
    let mut layout_names = HashSet::new();
    for expected_index in 0..layout_count {
        let values: Vec<_> = field(next_line(&mut lines, "layout row")?, "layout: ")?
            .split('|')
            .collect();
        if values.len() < 8 || parse_usize(values[0], "layout index")? != expected_index {
            return Err(invalid("full-program layout rows are not contiguous"));
        }
        let field_count = parse_usize(values[7], "layout field count")?;
        if values.len() != 8 + field_count * 2 {
            return Err(invalid(
                "full-program layout field count disagrees with row",
            ));
        }
        let name = decode_hex(values[1], "layout name")?;
        if name.is_empty() || !layout_names.insert(name.clone()) {
            return Err(invalid(format!(
                "duplicate or empty full-program layout {name}"
            )));
        }
        let mut fields = Vec::with_capacity(field_count);
        let mut names = HashSet::new();
        for field_index in 0..field_count {
            let name = decode_hex(values[8 + field_index * 2], "layout field name")?;
            let ty = decode_hex(values[9 + field_index * 2], "layout field type")?;
            if name.is_empty() || !names.insert(name.clone()) {
                return Err(invalid("duplicate or empty full-program layout field"));
            }
            validate_type(&ty, "layout field type")?;
            fields.push(LayoutField { name, ty });
        }
        let erased_name = decode_hex(values[2], "layout erased name")?;
        if erased_name.is_empty() {
            return Err(invalid("full-program layout has an empty erased identity"));
        }
        layouts.push(Layout {
            name,
            erased_name,
            brand: decode_hex(values[3], "layout brand")?,
            repr_c: parse_bool(values[4], "layout repr_c")?,
            packed: parse_bool(values[5], "layout packed")?,
            abi: decode_hex(values[6], "layout abi")?,
            fields,
        });
    }

    let enum_count = parse_usize(
        field(next_line(&mut lines, "enum count")?, "enum_count: ")?,
        "enum_count",
    )?;
    let mut enumerations = Vec::with_capacity(enum_count);
    let mut enum_names = HashSet::new();
    for expected_index in 0..enum_count {
        let values: Vec<_> = field(next_line(&mut lines, "enum row")?, "enum: ")?
            .split('|')
            .collect();
        if values.len() < 4 || parse_usize(values[0], "enum index")? != expected_index {
            return Err(invalid("full-program enum rows are not contiguous"));
        }
        let variant_count = parse_usize(values[3], "enum variant count")?;
        if variant_count == 0 || values.len() != 4 + variant_count {
            return Err(invalid(
                "full-program enum variant count disagrees with row",
            ));
        }
        let name = decode_hex(values[1], "enum name")?;
        if !layout_names.contains(&name) || !enum_names.insert(name.clone()) {
            return Err(invalid(format!(
                "full-program enum lacks one unique layout: {name}"
            )));
        }
        let mut variants = Vec::with_capacity(variant_count);
        let mut seen = HashSet::new();
        for value in &values[4..] {
            let variant = decode_hex(value, "enum variant")?;
            if variant.is_empty() || !seen.insert(variant.clone()) {
                return Err(invalid("duplicate or empty full-program enum variant"));
            }
            variants.push(variant);
        }
        let erased_name = decode_hex(values[2], "enum erased name")?;
        let owning_layout = layouts
            .iter()
            .find(|layout| layout.name == name)
            .ok_or_else(|| invalid("full-program enum lost its owning layout"))?;
        if erased_name.is_empty() || erased_name != owning_layout.erased_name {
            return Err(invalid(
                "full-program enum erased identity disagrees with its layout",
            ));
        }
        enumerations.push(Enumeration {
            name,
            erased_name,
            variants,
        });
    }

    let function_count = parse_usize(
        field(next_line(&mut lines, "function count")?, "function_count: ")?,
        "function_count",
    )?;
    if function_count == 0 {
        return Err(invalid("full-program function_count is zero"));
    }
    let mut functions = Vec::with_capacity(function_count);
    let mut qualified_names = HashSet::new();
    for expected_index in 0..function_count {
        let values: Vec<_> = field(next_line(&mut lines, "function row")?, "function: ")?
            .split('|')
            .collect();
        if values.len() < 9 || parse_usize(values[0], "function index")? != expected_index {
            return Err(invalid("full-program function rows are not contiguous"));
        }
        let parameter_count = parse_usize(values[8], "function parameter count")?;
        if values.len() != 9 + parameter_count * 2 {
            return Err(invalid(
                "full-program function parameter count disagrees with row",
            ));
        }
        let module_index = parse_usize(values[1], "function module index")?;
        if module_index >= modules.len() {
            return Err(invalid(
                "full-program function references an unknown module",
            ));
        }
        let source_name = decode_hex(values[2], "function source name")?;
        let qualified_name = decode_hex(values[3], "function qualified name")?;
        if source_name.is_empty()
            || qualified_name.is_empty()
            || !qualified_names.insert(qualified_name.clone())
        {
            return Err(invalid("duplicate or empty full-program function identity"));
        }
        let is_extern = parse_bool(values[4], "function is_extern")?;
        let extern_symbol = decode_hex(values[5], "function extern symbol")?;
        if is_extern && extern_symbol.is_empty() {
            return Err(invalid("full-program extern function has no link symbol"));
        }
        let result_type = decode_hex(values[6], "function result type")?;
        validate_type(&result_type, "function result type")?;
        let body_raw = parse_i32(values[7], "function body node")?;
        if is_extern != (body_raw < 0) {
            return Err(invalid(
                "full-program function body/extern classification disagrees",
            ));
        }
        let mut parameters = Vec::with_capacity(parameter_count);
        let mut parameter_names = HashSet::new();
        for parameter_index in 0..parameter_count {
            let name = decode_hex(values[9 + parameter_index * 2], "parameter name")?;
            let ty = decode_hex(values[10 + parameter_index * 2], "parameter type")?;
            if name.is_empty() || !parameter_names.insert(name.clone()) {
                return Err(invalid("duplicate or empty full-program parameter name"));
            }
            validate_type(&ty, "parameter type")?;
            parameters.push((name, ty));
        }
        functions.push(Function {
            module_index,
            source_name,
            qualified_name,
            is_extern,
            extern_symbol,
            result_type,
            body_node: (body_raw >= 0).then_some(body_raw as usize),
            parameters,
        });
    }

    let node_count = parse_usize(
        field(next_line(&mut lines, "node count")?, "node_count: ")?,
        "node_count",
    )?;
    let allowed_kinds: HashSet<_> = [
        "LocalRead",
        "IntegerLiteral",
        "StringLiteral",
        "BooleanLiteral",
        "MoveValue",
        "TakeValue",
        "AddressOf",
        "Dereference",
        "IndexRead",
        "ExplicitCast",
        "BinaryOperation",
        "FieldOrMethodSelect",
        "Call",
        "ZeroInitialize",
        "ResourceStorage",
        "ConditionalCleanup",
        "ScopeCleanup",
        "TypedQueryValue",
        "Block",
        "LocalDeclare",
        "Assign",
        "Loop",
        "Branch",
        "EnumMatch",
        "EnumMatchArm",
        "EnumPayloadBinding",
        "GuardUnwrap",
        "UnsafeScope",
        "ScheduleDefer",
        "Return",
        "Evaluate",
    ]
    .into_iter()
    .collect();
    let mut nodes = Vec::with_capacity(node_count);
    for expected_index in 0..node_count {
        let values: Vec<_> = field(next_line(&mut lines, "node row")?, "node: ")?
            .split('|')
            .collect();
        if values.len() < 12 || parse_usize(values[0], "node index")? != expected_index {
            return Err(invalid("full-program node rows are not contiguous"));
        }
        let child_count = parse_usize(values[11], "node child count")?;
        if values.len() != 12 + child_count {
            return Err(invalid("full-program node child count disagrees with row"));
        }
        let kind = decode_hex(values[1], "node kind")?;
        if !allowed_kinds.contains(kind.as_str()) {
            return Err(invalid(format!("unknown full-program operation {kind}")));
        }
        let ty = decode_hex(values[2], "node type")?;
        if kind != "EnumPayloadBinding" {
            validate_type(&ty, "node type")?;
        }
        let children: Vec<_> = values[12..]
            .iter()
            .map(|value| parse_usize(value, "node child"))
            .collect::<Result<_, _>>()?;
        if children.iter().any(|child| *child >= expected_index) {
            return Err(invalid("full-program node violates post-order ownership"));
        }
        let expected_arity = match kind.as_str() {
            "LocalRead" | "IntegerLiteral" | "StringLiteral" | "BooleanLiteral"
            | "ZeroInitialize" | "ResourceStorage" | "EnumPayloadBinding" => Some(0),
            "MoveValue"
            | "TakeValue"
            | "AddressOf"
            | "Dereference"
            | "ExplicitCast"
            | "FieldOrMethodSelect"
            | "UnsafeScope"
            | "ScheduleDefer"
            | "Evaluate" => Some(1),
            "IndexRead" | "Assign" | "Loop" | "GuardUnwrap" | "ConditionalCleanup" => {
                Some(2)
            }
            "Return" | "LocalDeclare" => None,
            _ => None,
        };
        if expected_arity.is_some_and(|arity| child_count != arity)
            || kind == "LocalDeclare" && child_count > 1
            || kind == "Call" && child_count == 0
            || kind == "Branch" && !(2..=3).contains(&child_count)
            || kind == "EnumMatch" && child_count < 2
            || kind == "EnumMatchArm" && child_count == 0
            || kind == "ScopeCleanup" && child_count == 0
            || kind == "TypedQueryValue" && child_count == 0
        {
            return Err(invalid(format!(
                "full-program operation {kind} has invalid arity {child_count}"
            )));
        }
        let source_line = parse_usize(values[7], "node source line")?;
        let source_column = parse_usize(values[8], "node source column")?;
        let source_start = parse_usize(values[9], "node source start")?;
        let source_end = parse_usize(values[10], "node source end")?;
        if source_end < source_start {
            return Err(invalid("full-program node source range is inverted"));
        }
        nodes.push(Node {
            kind,
            ty,
            text: decode_hex(values[3], "node text")?,
            second_text: decode_hex(values[4], "node second text")?,
            integer: parse_i32(values[5], "node integer")?,
            second_integer: parse_i32(values[6], "node second integer")?,
            source_line,
            source_column,
            source_start,
            source_end,
            children,
        });
    }

    let entry_function = parse_usize(
        field(
            next_line(&mut lines, "entry function")?,
            "entry_function_index: ",
        )?,
        "entry_function_index",
    )?;
    if lines.next().is_some() || entry_function >= functions.len() {
        return Err(invalid(
            "full-program canonical MIR has trailing rows or an invalid entry",
        ));
    }
    for function in &functions {
        if let Some(body) = function.body_node {
            if body >= nodes.len() || nodes[body].kind != "Block" {
                return Err(invalid(format!(
                    "function {} lacks one Block body root",
                    function.qualified_name
                )));
            }
        }
    }
    let entry = &functions[entry_function];
    if entry.qualified_name != "main" || entry.is_extern || !entry.parameters.is_empty() {
        return Err(invalid(
            "full-program entry is not the defined zero-parameter main",
        ));
    }

    let layout_by_name: HashMap<_, _> = layouts
        .iter()
        .map(|layout| (layout.name.as_str(), layout))
        .collect();
    let mut erased_layouts: HashMap<&str, &Layout> = HashMap::new();
    for layout in &layouts {
        if let Some(previous) = erased_layouts.insert(layout.erased_name.as_str(), layout) {
            let congruent = previous.repr_c == layout.repr_c
                && previous.packed == layout.packed
                && previous.abi == layout.abi
                && previous.fields.len() == layout.fields.len()
                && previous
                    .fields
                    .iter()
                    .zip(&layout.fields)
                    .all(|(left, right)| left.name == right.name && left.ty == right.ty);
            if !congruent {
                return Err(invalid(format!(
                    "full-program erased layout identity {} is incongruent",
                    layout.erased_name
                )));
            }
        }
    }
    for enumeration in &enumerations {
        let enum_layout = layout_by_name[enumeration.name.as_str()];
        for variant in &enumeration.variants {
            if !enum_layout
                .fields
                .iter()
                .any(|field| field.name == *variant)
            {
                return Err(invalid(format!(
                    "enum {} variant {variant} lacks a layout field",
                    enumeration.name
                )));
            }
        }
    }

    Ok(Program {
        target_triple,
        object_format,
        modules,
        layouts,
        enumerations,
        functions,
        nodes,
        entry_function,
    })
}

#[derive(Clone)]
struct Callable {
    id: FuncId,
    abi: FunctionAbi,
    parameters: Vec<String>,
    result: String,
}

fn inline_call_name(program: &Program, node: &Node) -> Option<String> {
    if node.kind != "Call" || node.children.is_empty() {
        return None;
    }
    let callee = &program.nodes[node.children[0]];
    if callee.kind == "FieldOrMethodSelect" {
        Some(callee.text.clone())
    } else if node.text == "len" || node.second_text == "len" {
        Some("len".to_string())
    } else if matches!(node.text.as_str(), "os_ArenaAlloc" | "os.ArenaAlloc") {
        Some("ArenaAlloc".to_string())
    } else {
        None
    }
}

fn is_inline_call(program: &Program, node: &Node) -> bool {
    let Some(name) = inline_call_name(program, node) else {
        return false;
    };
    matches!(
        name.as_str(),
        "Concat"
            | "Format"
            | "FormatInt"
            | "VectorNew"
            | "HashMapNew"
            | "PoolNew"
            | "GraphNew"
            | "len"
            | "Set"
            | "get_ref"
            | "Push"
            | "Pop"
            | "Clear"
            | "Get"
            | "get_opt"
            | "Insert"
            | "Remove"
            | "Keys"
            | "Contains"
            | "AddNode"
            | "AddEdge"
            | "GetNode"
            | "ArenaAlloc"
            | "New"
            | "Free"
    )
}

fn runtime_symbol(node: &Node) -> String {
    let candidate = if node.second_text.is_empty() {
        node.text.as_str()
    } else {
        node.second_text.as_str()
    };
    match candidate {
        "std_Clone" => "std_Clone_str".to_string(),
        "os_Exit" => "exit".to_string(),
        "os_ArenaValidate" => "os_Arena_Validate".to_string(),
        other => other.to_string(),
    }
}

fn snprintf_format(value: &str) -> String {
    value.replace("%s", "%.*s")
}

struct FullProgramCompiler<'a> {
    program: &'a Program,
    module: ObjectModule,
    layouts: LayoutEngine<'a>,
    functions: HashMap<String, Callable>,
    runtime: HashMap<String, Callable>,
    strings: HashMap<String, DataId>,
    user_main: Option<FuncId>,
    entry: Option<FuncId>,
    user_exit_status: Option<DataId>,
    os_argc: Option<DataId>,
    os_argv: Option<DataId>,
}

impl<'a> FullProgramCompiler<'a> {
    fn new(program: &'a Program) -> Result<Self, Box<dyn Error>> {
        let builder = target_object_builder(program)?;
        let module = ObjectModule::new(builder);
        Ok(Self {
            program,
            module,
            layouts: LayoutEngine::new(program, 8),
            functions: HashMap::new(),
            runtime: HashMap::new(),
            strings: HashMap::new(),
            user_main: None,
            entry: None,
            user_exit_status: None,
            os_argc: None,
            os_argv: None,
        })
    }

    fn declare_program(&mut self) -> Result<(), Box<dyn Error>> {
        for function in &self.program.functions {
            let (signature, abi) = function_signature(&self.module, function, &mut self.layouts)?;
            let symbol = if function.qualified_name == "main" {
                "gust_phase21_program_main"
            } else {
                function.qualified_name.as_str()
            };
            let id = self
                .module
                .declare_function(symbol, Linkage::Local, &signature)?;
            self.functions.insert(
                function.qualified_name.clone(),
                Callable {
                    id,
                    abi,
                    parameters: function
                        .parameters
                        .iter()
                        .map(|(_, ty)| ty.clone())
                        .collect(),
                    result: function.result_type.clone(),
                },
            );
        }
        self.declare_runtime_calls()?;
        self.declare_string_data()?;
        self.declare_entry_authority()?;
        Ok(())
    }

    fn declare_runtime_calls(&mut self) -> Result<(), Box<dyn Error>> {
        let internal: HashSet<_> = self.functions.keys().map(String::as_str).collect();
        let mut specs: HashMap<String, (Vec<String>, String)> = HashMap::new();
        for node in &self.program.nodes {
            if node.kind != "Call"
                || is_inline_call(self.program, node)
                || internal.contains(node.second_text.as_str())
            {
                continue;
            }
            let symbol = runtime_symbol(node);
            if symbol.is_empty() || symbol.ends_with("__") {
                return Err(invalid(format!(
                    "full-program call {} has neither generic inline nor function authority",
                    node.text
                )));
            }
            if symbol == "os_ScratchAlloc" || symbol == "os_ArenaAlloc" {
                continue;
            }
            let parameters: Vec<_> = node.children[1..]
                .iter()
                .map(|child| {
                    let ty = self.program.nodes[*child].ty.as_str();
                    if ty == "Arena" {
                        "Reference(Arena, None)".to_string()
                    } else {
                        ty.to_string()
                    }
                })
                .collect();
            let spec = (parameters, node.ty.clone());
            if specs.get(&symbol).is_some_and(|previous| previous != &spec) {
                return Err(invalid(format!(
                    "full-program runtime symbol {symbol} has inconsistent signatures"
                )));
            }
            specs.insert(symbol, spec);
        }
        for (symbol, (parameters, result)) in specs {
            let synthetic = Function {
                module_index: 0,
                source_name: symbol.clone(),
                qualified_name: symbol.clone(),
                is_extern: true,
                extern_symbol: symbol.clone(),
                result_type: result.clone(),
                body_node: None,
                parameters: parameters
                    .iter()
                    .enumerate()
                    .map(|(index, ty)| (format!("p{index}"), ty.clone()))
                    .collect(),
            };
            let (signature, abi) = function_signature(&self.module, &synthetic, &mut self.layouts)?;
            let id = self
                .module
                .declare_function(&symbol, Linkage::Import, &signature)?;
            self.runtime.insert(
                symbol,
                Callable {
                    id,
                    abi,
                    parameters,
                    result,
                },
            );
        }
        self.declare_helper("memcpy", &["Ptr", "Ptr", "I64"], "Ptr")?;
        self.declare_helper(
            "os_HashMapRef_impl",
            &["Ptr", "Ptr", "I32", "I64", "I64"],
            "Ptr",
        )?;
        self.declare_helper(
            "os_HashMapContains_impl",
            &["Ptr", "Ptr", "I32", "I64"],
            "I32",
        )?;
        self.declare_helper(
            "os_HashMapRemove_impl",
            &["Ptr", "Ptr", "I32", "I64", "I64"],
            "Void",
        )?;
        self.declare_helper("os_HashMapClear_impl", &["Ptr", "I64", "I64"], "Void")?;
        self.declare_helper("std_PoolAlloc_impl", &["Ptr", "I64"], "I32")?;
        self.declare_helper("std_PoolFree_impl", &["Ptr", "I32"], "Void")?;
        self.declare_helper("os_ScratchAlloc", &["I64"], "Ptr")?;
        self.declare_helper("os_ArenaAlloc", &["Ptr", "I64"], "I32")?;
        self.declare_helper("os_Arena_Free", &["Ptr"], "Void")?;
        self.declare_helper("get_num_threads_to_use", &[], "I32")?;
        self.declare_helper("gust_scheduler_init", &["I32"], "Void")?;
        self.declare_helper("gust_scheduler_spawn", &["I64", "Ptr", "Ptr"], "Void")?;
        self.declare_helper("gust_scheduler_destroy", &[], "Void")?;
        self.declare_helper(
            "snprintf",
            &[
                "Ptr", "I64", "Ptr", "I64", "I64", "I64", "I64", "I64", "I64", "I64", "I64",
            ],
            "I32",
        )?;
        let arena_new = Function {
            module_index: 0,
            source_name: "os_Arena_New".to_string(),
            qualified_name: "os_Arena_New".to_string(),
            is_extern: true,
            extern_symbol: "os_Arena_New".to_string(),
            result_type: "Arena".to_string(),
            body_node: None,
            parameters: Vec::new(),
        };
        let (signature, abi) = function_signature(&self.module, &arena_new, &mut self.layouts)?;
        let id = self
            .module
            .declare_function("os_Arena_New", Linkage::Import, &signature)?;
        self.runtime.insert(
            "os_Arena_New".to_string(),
            Callable {
                id,
                abi,
                parameters: Vec::new(),
                result: "Arena".to_string(),
            },
        );
        Ok(())
    }

    fn declare_entry_authority(&mut self) -> Result<(), Box<dyn Error>> {
        let pointer_type = self.module.target_config().pointer_type();
        let mut user_signature = self.module.make_signature();
        user_signature.params.push(AbiParam::new(pointer_type));
        self.user_main = Some(self.module.declare_function(
            "gust_user_main",
            Linkage::Export,
            &user_signature,
        )?);
        let mut entry_signature = self.module.make_signature();
        entry_signature.params.push(AbiParam::new(types::I32));
        entry_signature.params.push(AbiParam::new(pointer_type));
        entry_signature.returns.push(AbiParam::new(types::I32));
        self.entry = Some(self.module.declare_function(
            "main",
            Linkage::Export,
            &entry_signature,
        )?);
        if matches!(self.functions["main"].abi.result, AbiShape::Scalar(_)) {
            let status = self.module.declare_data(
                "gust_user_exit_status",
                Linkage::Local,
                true,
                false,
            )?;
            let mut description = DataDescription::new();
            description.define_zeroinit(4);
            self.module.define_data(status, &description)?;
            self.user_exit_status = Some(status);
        }
        self.os_argc = Some(
            self.module
                .declare_data("os_argc", Linkage::Import, true, false)?,
        );
        self.os_argv = Some(
            self.module
                .declare_data("os_argv", Linkage::Import, true, false)?,
        );
        Ok(())
    }

    fn declare_helper(
        &mut self,
        symbol: &str,
        parameter_types: &[&str],
        result_type: &str,
    ) -> Result<(), Box<dyn Error>> {
        if self.runtime.contains_key(symbol) {
            return Ok(());
        }
        let pointer_type = self.module.target_config().pointer_type();
        let mut signature = self.module.make_signature();
        let helper_type = |name: &str| -> Result<Type, Box<dyn Error>> {
            match name {
                "Ptr" => Ok(pointer_type),
                "I32" => Ok(types::I32),
                "I64" => Ok(types::I64),
                _ => Err(invalid("unknown full-program helper ABI type")),
            }
        };
        for parameter in parameter_types {
            let ty = helper_type(parameter)?;
            signature.params.push(AbiParam::new(ty));
        }
        if result_type != "Void" {
            signature
                .returns
                .push(AbiParam::new(helper_type(result_type)?));
        }
        let id = self
            .module
            .declare_function(symbol, Linkage::Import, &signature)?;
        self.runtime.insert(
            symbol.to_string(),
            Callable {
                id,
                abi: FunctionAbi {
                    result: if result_type == "Void" {
                        AbiShape::Void
                    } else {
                        AbiShape::Scalar(helper_type(result_type)?)
                    },
                    parameters: parameter_types
                        .iter()
                        .map(|parameter| AbiShape::Scalar(helper_type(parameter).unwrap()))
                        .collect(),
                },
                parameters: parameter_types
                    .iter()
                    .map(|value| (*value).to_string())
                    .collect(),
                result: result_type.to_string(),
            },
        );
        Ok(())
    }

    fn declare_string_data(&mut self) -> Result<(), Box<dyn Error>> {
        let mut values: Vec<_> = self
            .program
            .nodes
            .iter()
            .filter(|node| node.kind == "StringLiteral")
            .map(|node| node.text.clone())
            .collect();
        for node in &self.program.nodes {
            if node.kind == "Call"
                && inline_call_name(self.program, node).as_deref() == Some("Format")
                && node.children.len() >= 2
            {
                let format_node = &self.program.nodes[node.children[1]];
                if format_node.kind == "StringLiteral" {
                    values.push(snprintf_format(&format_node.text));
                }
            }
        }
        values.push("%d".to_string());
        values.sort();
        values.dedup();
        for (index, value) in values.into_iter().enumerate() {
            let id = self.module.declare_data(
                &format!("gust_phase21_string_{index}"),
                Linkage::Local,
                false,
                false,
            )?;
            let mut description = DataDescription::new();
            let mut bytes = value.as_bytes().to_vec();
            bytes.push(0);
            description.define(bytes.into_boxed_slice());
            self.module.define_data(id, &description)?;
            self.strings.insert(value, id);
        }
        Ok(())
    }

    fn finish(mut self, output_path: &Path) -> Result<String, Box<dyn Error>> {
        self.declare_program()?;
        for index in 0..self.program.functions.len() {
            self.define_function(index)?;
        }
        self.define_entry_functions()?;
        if let Some(parent) = output_path.parent() {
            fs::create_dir_all(parent)?;
        }
        let bytes = self.module.finish().emit()?;
        let temporary = PathBuf::from(format!("{}.tmp", output_path.display()));
        fs::write(&temporary, &bytes)?;
        fs::rename(&temporary, output_path)?;
        Ok(format!(
            "format={} functions={} bytes={} object={}\n",
            FORMAT,
            self.program.functions.len(),
            bytes.len(),
            output_path.display()
        ))
    }

    fn define_function(&mut self, function_index: usize) -> Result<(), Box<dyn Error>> {
        let function = &self.program.functions[function_index];
        let callable = self.functions[&function.qualified_name].clone();
        let mut context = self.module.make_context();
        context.func.signature = self
            .module
            .declarations()
            .get_function_decl(callable.id)
            .signature
            .clone();
        let mut builder_context = FunctionBuilderContext::new();
        let mut builder = FunctionBuilder::new(&mut context.func, &mut builder_context);
        let entry = builder.create_block();
        builder.append_block_params_for_function_params(entry);
        builder.switch_to_block(entry);
        let mut lowerer = FunctionLowerer::new(
            self.program,
            &mut self.module,
            &mut self.layouts,
            &self.functions,
            &self.runtime,
            &self.strings,
            function,
            callable.abi.clone(),
        );
        lowerer.bind_parameters(&mut builder).map_err(|error| {
            invalid(format!(
                "full-program function {} parameter lowering failed: {error}",
                function.qualified_name
            ))
        })?;
        let terminated = lowerer
            .lower_block(
                &mut builder,
                function
                    .body_node
                    .ok_or_else(|| invalid("defined function lacks body"))?,
            )
            .map_err(|error| {
                invalid(format!(
                    "full-program function {} body lowering failed: {error}",
                    function.qualified_name
                ))
            })?;
        if !terminated {
            lowerer.emit_implicit_return(&mut builder)?;
        }
        builder.seal_all_blocks();
        builder.finalize();
        if let Err(error) = cranelift_codegen::verify_function(&context.func, self.module.isa()) {
            return Err(invalid(format!(
                "full-program function {} failed Cranelift verification: {error:?}\n{}",
                function.qualified_name,
                context.func.display()
            )));
        }
        self.module.define_function(callable.id, &mut context)?;
        self.module.clear_context(&mut context);
        Ok(())
    }

    fn define_entry_functions(&mut self) -> Result<(), Box<dyn Error>> {
        let user_main = self.user_main.unwrap();
        let entry = self.entry.unwrap();
        let program_main = self.functions["main"].id;
        let mut context = self.module.make_context();
        context.func.signature = self
            .module
            .declarations()
            .get_function_decl(user_main)
            .signature
            .clone();
        let mut builder_context = FunctionBuilderContext::new();
        let mut builder = FunctionBuilder::new(&mut context.func, &mut builder_context);
        let block = builder.create_block();
        builder.append_block_params_for_function_params(block);
        builder.switch_to_block(block);
        let program_ref = self.module.declare_func_in_func(program_main, builder.func);
        let program_call = builder.ins().call(program_ref, &[]);
        if let Some(status) = self.user_exit_status {
            let mut value = builder.inst_results(program_call)[0];
            let value_type = builder.func.dfg.value_type(value);
            value = if value_type.bits() < types::I32.bits() {
                builder.ins().uextend(types::I32, value)
            } else if value_type.bits() > types::I32.bits() {
                builder.ins().ireduce(types::I32, value)
            } else {
                value
            };
            let status_ref = self.module.declare_data_in_func(status, builder.func);
            let status_address = builder
                .ins()
                .symbol_value(self.module.target_config().pointer_type(), status_ref);
            builder
                .ins()
                .store(MemFlags::trusted(), value, status_address, 0);
        }
        builder.ins().return_(&[]);
        builder.seal_all_blocks();
        builder.finalize();
        self.module.define_function(user_main, &mut context)?;
        self.module.clear_context(&mut context);

        let mut context = self.module.make_context();
        context.func.signature = self
            .module
            .declarations()
            .get_function_decl(entry)
            .signature
            .clone();
        let mut builder_context = FunctionBuilderContext::new();
        let mut builder = FunctionBuilder::new(&mut context.func, &mut builder_context);
        let block = builder.create_block();
        builder.append_block_params_for_function_params(block);
        builder.switch_to_block(block);
        let parameters = builder.block_params(block).to_vec();
        let argc_ref = self
            .module
            .declare_data_in_func(self.os_argc.unwrap(), builder.func);
        let argc_address = builder
            .ins()
            .symbol_value(self.module.target_config().pointer_type(), argc_ref);
        builder
            .ins()
            .store(MemFlags::trusted(), parameters[0], argc_address, 0);
        let argv_ref = self
            .module
            .declare_data_in_func(self.os_argv.unwrap(), builder.func);
        let argv_address = builder
            .ins()
            .symbol_value(self.module.target_config().pointer_type(), argv_ref);
        builder
            .ins()
            .store(MemFlags::trusted(), parameters[1], argv_address, 0);
        let threads = self.runtime["get_num_threads_to_use"].clone();
        let threads_ref = self.module.declare_func_in_func(threads.id, builder.func);
        let threads_call = builder.ins().call(threads_ref, &[]);
        let thread_count = builder.inst_results(threads_call)[0];
        let init = self.runtime["gust_scheduler_init"].clone();
        let init_ref = self.module.declare_func_in_func(init.id, builder.func);
        builder.ins().call(init_ref, &[thread_count]);
        let user_ref = self.module.declare_func_in_func(user_main, builder.func);
        let user_address = builder
            .ins()
            .func_addr(self.module.target_config().pointer_type(), user_ref);
        let stack_size = builder.ins().iconst(types::I64, 8_388_608);
        let null = builder
            .ins()
            .iconst(self.module.target_config().pointer_type(), 0);
        let spawn = self.runtime["gust_scheduler_spawn"].clone();
        let spawn_ref = self.module.declare_func_in_func(spawn.id, builder.func);
        builder
            .ins()
            .call(spawn_ref, &[stack_size, user_address, null]);
        let destroy = self.runtime["gust_scheduler_destroy"].clone();
        let destroy_ref = self.module.declare_func_in_func(destroy.id, builder.func);
        builder.ins().call(destroy_ref, &[]);
        let status = if let Some(status) = self.user_exit_status {
            let status_ref = self.module.declare_data_in_func(status, builder.func);
            let status_address = builder
                .ins()
                .symbol_value(self.module.target_config().pointer_type(), status_ref);
            builder
                .ins()
                .load(types::I32, MemFlags::trusted(), status_address, 0)
        } else {
            builder.ins().iconst(types::I32, 0)
        };
        builder.ins().return_(&[status]);
        builder.seal_all_blocks();
        builder.finalize();
        self.module.define_function(entry, &mut context)?;
        self.module.clear_context(&mut context);
        Ok(())
    }
}

struct FunctionLowerer<'a, 'm> {
    program: &'a Program,
    module: &'m mut ObjectModule,
    layouts: &'m mut LayoutEngine<'a>,
    functions: &'m HashMap<String, Callable>,
    runtime: &'m HashMap<String, Callable>,
    strings: &'m HashMap<String, DataId>,
    function: &'a Function,
    abi: FunctionAbi,
    scopes: Vec<HashMap<String, Local>>,
    defers: Vec<Vec<usize>>,
    loops: Vec<(Block, Block, usize)>,
    sret: Option<Value>,
}

impl<'a, 'm> FunctionLowerer<'a, 'm> {
    #[allow(clippy::too_many_arguments)]
    fn new(
        program: &'a Program,
        module: &'m mut ObjectModule,
        layouts: &'m mut LayoutEngine<'a>,
        functions: &'m HashMap<String, Callable>,
        runtime: &'m HashMap<String, Callable>,
        strings: &'m HashMap<String, DataId>,
        function: &'a Function,
        abi: FunctionAbi,
    ) -> Self {
        Self {
            program,
            module,
            layouts,
            functions,
            runtime,
            strings,
            function,
            abi,
            scopes: vec![HashMap::new()],
            defers: vec![Vec::new()],
            loops: Vec::new(),
            sret: None,
        }
    }

    fn pointer_type(&self) -> Type {
        self.module.target_config().pointer_type()
    }

    fn bind_parameters(&mut self, builder: &mut FunctionBuilder<'_>) -> Result<(), Box<dyn Error>> {
        let parameters = builder
            .block_params(builder.current_block().unwrap())
            .to_vec();
        let mut cursor = 0usize;
        if matches!(self.abi.result, AbiShape::AggregateMemory(_)) {
            self.sret = Some(parameters[cursor]);
            cursor += 1;
        }
        for (index, (name, ty)) in self.function.parameters.iter().enumerate() {
            let shape = self.abi.parameters[index];
            let layout = self.layouts.layout(ty)?;
            let place = match shape {
                AbiShape::ArenaParameter => {
                    let place = Place {
                        address: parameters[cursor],
                    };
                    cursor += 1;
                    place
                }
                AbiShape::Scalar(_) => {
                    let place = make_stack_place(builder, &layout, self.pointer_type())?;
                    store_scalar(builder, place.address, parameters[cursor]);
                    cursor += 1;
                    place
                }
                AbiShape::AggregateOne => {
                    let place = make_stack_place(builder, &layout, self.pointer_type())?;
                    self.zero_place(builder, place, &layout);
                    builder
                        .ins()
                        .store(MemFlags::trusted(), parameters[cursor], place.address, 0);
                    cursor += 1;
                    place
                }
                AbiShape::AggregateTwo => {
                    let place = make_stack_place(builder, &layout, self.pointer_type())?;
                    self.zero_place(builder, place, &layout);
                    builder
                        .ins()
                        .store(MemFlags::trusted(), parameters[cursor], place.address, 0);
                    builder.ins().store(
                        MemFlags::trusted(),
                        parameters[cursor + 1],
                        place.address,
                        8,
                    );
                    cursor += 2;
                    place
                }
                AbiShape::AggregateMemory(_) => {
                    let place = make_stack_place(builder, &layout, self.pointer_type())?;
                    self.copy_place(
                        builder,
                        place,
                        Place {
                            address: parameters[cursor],
                        },
                        layout.size,
                    )?;
                    cursor += 1;
                    place
                }
                AbiShape::Void => return Err(invalid("void function parameter reached lowering")),
            };
            self.scopes[0].insert(name.clone(), Local { place });
        }
        if cursor != parameters.len() {
            return Err(invalid(
                "full-program parameter ABI cursor disagrees with signature",
            ));
        }
        Ok(())
    }

    fn local(&self, name: &str) -> Result<Local, Box<dyn Error>> {
        self.scopes
            .iter()
            .rev()
            .find_map(|scope| scope.get(name).cloned())
            .ok_or_else(|| invalid(format!("full-program local {name} is not in lexical scope")))
    }

    fn zero_place(&self, builder: &mut FunctionBuilder<'_>, place: Place, layout: &TypeLayout) {
        let mut offset = 0u32;
        while offset + 8 <= layout.size {
            let zero = builder.ins().iconst(types::I64, 0);
            builder
                .ins()
                .store(MemFlags::trusted(), zero, place.address, offset as i32);
            offset += 8;
        }
        while offset < layout.size {
            let zero = builder.ins().iconst(types::I8, 0);
            builder
                .ins()
                .store(MemFlags::trusted(), zero, place.address, offset as i32);
            offset += 1;
        }
    }

    fn copy_place(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        destination: Place,
        source: Place,
        size: u32,
    ) -> Result<(), Box<dyn Error>> {
        if size == 0 {
            return Ok(());
        }
        let callable = self
            .runtime
            .get("memcpy")
            .ok_or_else(|| invalid("memcpy import missing"))?;
        let reference = self.module.declare_func_in_func(callable.id, builder.func);
        let size_value = builder.ins().iconst(types::I64, i64::from(size));
        builder.ins().call(
            reference,
            &[destination.address, source.address, size_value],
        );
        Ok(())
    }

    fn place_for_type(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        ty: &str,
    ) -> Result<Place, Box<dyn Error>> {
        let layout = self.layouts.layout(ty)?;
        let place = make_stack_place(builder, &layout, self.pointer_type())?;
        self.zero_place(builder, place, &layout);
        Ok(place)
    }

    fn evaluated_place(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        value: Evaluated,
        ty: &str,
    ) -> Result<Place, Box<dyn Error>> {
        match value {
            Evaluated::Aggregate(place) => Ok(place),
            Evaluated::Scalar(value) => {
                let place = self.place_for_type(builder, ty)?;
                store_scalar(builder, place.address, value);
                Ok(place)
            }
            Evaluated::Void => Err(invalid("void value used as a place")),
        }
    }

    fn evaluated_place_as(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        value: Evaluated,
        actual_type: &str,
        expected_type: &str,
    ) -> Result<Place, Box<dyn Error>> {
        if actual_type == expected_type {
            return self.evaluated_place(builder, value, actual_type);
        }
        if pointer_inner_type(actual_type).is_some_and(|inner| inner == expected_type) {
            return Ok(Place {
                address: self.scalar(builder, value, actual_type)?,
            });
        }
        Err(invalid(format!(
            "full-program value type {actual_type} cannot initialize {expected_type}"
        )))
    }

    fn store_evaluated_as(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        destination: Place,
        value: Evaluated,
        actual_type: &str,
        expected_type: &str,
    ) -> Result<(), Box<dyn Error>> {
        if actual_type == expected_type {
            return self.store_evaluated(builder, destination, value, expected_type);
        }
        let source = self.evaluated_place_as(builder, value, actual_type, expected_type)?;
        if is_scalar_type(expected_type) {
            let scalar = load_scalar(builder, source.address, expected_type, self.pointer_type())?;
            store_scalar(builder, destination.address, scalar);
        } else {
            let size = self.layouts.layout(expected_type)?.size;
            self.copy_place(builder, destination, source, size)?;
        }
        Ok(())
    }

    fn scalar(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        value: Evaluated,
        ty: &str,
    ) -> Result<Value, Box<dyn Error>> {
        match value {
            Evaluated::Scalar(value) => Ok(value),
            Evaluated::Aggregate(place) if is_scalar_type(ty) => {
                load_scalar(builder, place.address, ty, self.pointer_type())
            }
            _ => Err(invalid(format!("full-program {ty} value is not scalar"))),
        }
    }

    fn arena_address(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        value: Evaluated,
        ty: &str,
    ) -> Result<Value, Box<dyn Error>> {
        if is_pointer_type(ty) {
            self.scalar(builder, value, ty)
        } else if ty == "Arena" {
            Ok(self.evaluated_place(builder, value, ty)?.address)
        } else {
            Err(invalid(format!(
                "full-program arena operand has non-arena type {ty}"
            )))
        }
    }

    fn coerce_scalar(
        &self,
        builder: &mut FunctionBuilder<'_>,
        value: Value,
        target_type: Type,
    ) -> Value {
        let source_type = builder.func.dfg.value_type(value);
        if source_type == target_type {
            value
        } else if source_type.bits() < target_type.bits() {
            builder.ins().uextend(target_type, value)
        } else {
            builder.ins().ireduce(target_type, value)
        }
    }

    fn field_place(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        receiver: Place,
        receiver_type: &str,
        field: &str,
    ) -> Result<(Place, String), Box<dyn Error>> {
        let layout = self.layouts.layout(receiver_type)?;
        let placement = layout.fields.get(field).ok_or_else(|| {
            invalid(format!(
                "full-program type {receiver_type} has no field {field}"
            ))
        })?;
        Ok((
            Place {
                address: add_offset(builder, receiver.address, placement.offset),
            },
            placement.ty.clone(),
        ))
    }

    fn lower_place(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node_index: usize,
    ) -> Result<Place, Box<dyn Error>> {
        let node = &self.program.nodes[node_index];
        match node.kind.as_str() {
            "LocalRead" => Ok(self.local(&node.text)?.place),
            "Dereference" => {
                let child = &self.program.nodes[node.children[0]];
                let value = self.lower_expression(builder, node.children[0], None)?;
                Ok(Place {
                    address: self.scalar(builder, value, &child.ty)?,
                })
            }
            "FieldOrMethodSelect" => {
                let receiver_node = &self.program.nodes[node.children[0]];
                let (receiver, receiver_type) = if is_pointer_type(&receiver_node.ty) {
                    let evaluated = self.lower_expression(builder, node.children[0], None)?;
                    let address = self.scalar(builder, evaluated, &receiver_node.ty)?;
                    (
                        Place { address },
                        pointer_inner_type(&receiver_node.ty)
                            .ok_or_else(|| invalid("field receiver pointer has no inner type"))?
                            .to_string(),
                    )
                } else {
                    let evaluated = self.lower_expression(builder, node.children[0], None)?;
                    (
                        self.evaluated_place(builder, evaluated, &receiver_node.ty)?,
                        receiver_node.ty.clone(),
                    )
                };
                Ok(self
                    .field_place(builder, receiver, &receiver_type, &node.text)?
                    .0)
            }
            "IndexRead" => self.lower_index_place(builder, node),
            "ExplicitCast" if node.integer != 0 => {
                let child = &self.program.nodes[node.children[0]];
                let value = self.lower_expression(builder, node.children[0], None)?;
                Ok(Place {
                    address: self.scalar(builder, value, &child.ty)?,
                })
            }
            _ => Err(invalid(format!(
                "full-program operation {} is not assignable",
                node.kind
            ))),
        }
    }

    fn lower_index_place(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
    ) -> Result<Place, Box<dyn Error>> {
        let receiver_node = &self.program.nodes[node.children[0]];
        let index_node = &self.program.nodes[node.children[1]];
        let index_eval = self.lower_expression(builder, node.children[1], None)?;
        let index = self.scalar(builder, index_eval, &index_node.ty)?;
        let index64 = builder.ins().uextend(types::I64, index);
        if receiver_node.ty == "Arena" || receiver_node.ty.starts_with("Reference(Arena,") {
            let arena_address = if receiver_node.ty == "Arena" {
                self.lower_place(builder, node.children[0])?.address
            } else {
                let receiver_eval = self.lower_expression(builder, node.children[0], None)?;
                self.scalar(builder, receiver_eval, &receiver_node.ty)?
            };
            let base =
                builder
                    .ins()
                    .load(self.pointer_type(), MemFlags::trusted(), arena_address, 0);
            return Ok(Place {
                address: builder.ins().iadd(base, index64),
            });
        }
        if struct_type_name(&receiver_node.ty).is_some_and(|name| name.starts_with("std_Vector_")) {
            let receiver = self.lower_place(builder, node.children[0])?;
            let (data_place, _) = self.field_place(builder, receiver, &receiver_node.ty, "data")?;
            let data = builder.ins().load(
                self.pointer_type(),
                MemFlags::trusted(),
                data_place.address,
                0,
            );
            let element_size = self.layouts.layout(&node.ty)?.size;
            let scaled = builder.ins().imul_imm(index64, i64::from(element_size));
            return Ok(Place {
                address: builder.ins().iadd(data, scaled),
            });
        }
        if is_pointer_type(&receiver_node.ty) {
            let receiver_eval = self.lower_expression(builder, node.children[0], None)?;
            let data = self.scalar(builder, receiver_eval, &receiver_node.ty)?;
            let element_size = self.layouts.layout(&node.ty)?.size;
            let scaled = builder.ins().imul_imm(index64, i64::from(element_size));
            return Ok(Place {
                address: builder.ins().iadd(data, scaled),
            });
        }
        Err(invalid(format!(
            "full-program indexing lacks generic authority for {}",
            receiver_node.ty
        )))
    }

    fn place_expression_borrows_value(&mut self, node: &Node) -> Result<bool, Box<dyn Error>> {
        if !node.ty.starts_with("Reference(") {
            return Ok(false);
        }
        let borrowed = pointer_inner_type(&node.ty)
            .ok_or_else(|| invalid("reference expression lacks an inner type"))?;
        match node.kind.as_str() {
            "IndexRead" => {
                let receiver = &self.program.nodes[node.children[0]];
                if struct_type_name(&receiver.ty)
                    .is_some_and(|name| name.starts_with("std_Vector_"))
                {
                    let layout = self.layouts.layout(&receiver.ty)?;
                    let data_type = &layout
                        .fields
                        .get("data")
                        .ok_or_else(|| invalid("vector borrow lacks data field authority"))?
                        .ty;
                    return Ok(pointer_inner_type(data_type).is_some_and(|ty| ty == borrowed));
                }
                if is_pointer_type(&receiver.ty) {
                    return Ok(pointer_inner_type(&receiver.ty).is_some_and(|ty| ty == borrowed));
                }
                Ok(false)
            }
            "FieldOrMethodSelect" => {
                let receiver = &self.program.nodes[node.children[0]];
                let receiver_type = if is_pointer_type(&receiver.ty) {
                    pointer_inner_type(&receiver.ty)
                        .ok_or_else(|| invalid("field borrow receiver lacks an inner type"))?
                } else {
                    receiver.ty.as_str()
                };
                let layout = self.layouts.layout(receiver_type)?;
                Ok(layout
                    .fields
                    .get(&node.text)
                    .is_some_and(|field| field.ty == borrowed))
            }
            _ => Ok(false),
        }
    }

    fn lower_expression(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node_index: usize,
        expected_type: Option<&str>,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let node = &self.program.nodes[node_index];
        match node.kind.as_str() {
            "LocalRead" | "Dereference" | "FieldOrMethodSelect" | "IndexRead" => {
                let borrows_value = self.place_expression_borrows_value(node)?;
                let place = self.lower_place(builder, node_index)?;
                if borrows_value {
                    Ok(Evaluated::Scalar(place.address))
                } else if is_scalar_type(&node.ty) {
                    Ok(Evaluated::Scalar(load_scalar(
                        builder,
                        place.address,
                        &node.ty,
                        self.pointer_type(),
                    )?))
                } else {
                    Ok(Evaluated::Aggregate(place))
                }
            }
            "IntegerLiteral" => Ok(Evaluated::Scalar(
                builder.ins().iconst(types::I32, i64::from(node.integer)),
            )),
            "BooleanLiteral" => Ok(Evaluated::Scalar(
                builder.ins().iconst(types::I8, i64::from(node.integer)),
            )),
            "StringLiteral" => self.lower_string_literal(builder, node),
            "MoveValue" | "TakeValue" => {
                self.lower_expression(builder, node.children[0], expected_type)
            }
            "AddressOf" => Ok(Evaluated::Scalar(
                self.lower_place(builder, node.children[0])?.address,
            )),
            "ExplicitCast" => self.lower_cast(builder, node),
            "BinaryOperation" => self.lower_binary(builder, node),
            "ZeroInitialize" => {
                if is_scalar_type(&node.ty) {
                    let value = if index_element_layout_type(&node.ty).is_ok() {
                        -1
                    } else {
                        0
                    };
                    Ok(Evaluated::Scalar(builder.ins().iconst(
                        scalar_ir_type(&node.ty, self.pointer_type())?,
                        value,
                    )))
                } else {
                    Ok(Evaluated::Aggregate(
                        self.place_for_type(builder, &node.ty)?,
                    ))
                }
            }
            "ResourceStorage" => self.lower_resource_storage(builder, node),
            "ConditionalCleanup" => self.lower_conditional_cleanup(builder, node),
            "Call" => self.lower_call(builder, node, expected_type),
            "TypedQueryValue" => Err(invalid(
                "typed query unexpectedly reached the compiler executable cohort",
            )),
            other => Err(invalid(format!(
                "full-program executable expression {other} is unsupported"
            ))),
        }
    }

    fn lower_string_literal(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let place = self.place_for_type(builder, "Str")?;
        let data_id = self
            .strings
            .get(&node.text)
            .ok_or_else(|| invalid("full-program string data was not declared"))?;
        let reference = self.module.declare_data_in_func(*data_id, builder.func);
        let address = builder.ins().symbol_value(self.pointer_type(), reference);
        builder
            .ins()
            .store(MemFlags::trusted(), address, place.address, 0);
        let length = builder.ins().iconst(types::I32, node.text.len() as i64);
        builder
            .ins()
            .store(MemFlags::trusted(), length, place.address, 8);
        Ok(Evaluated::Aggregate(place))
    }

    fn lower_resource_storage(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let mut components = node.text.split('.');
        let root = components
            .next()
            .filter(|value| !value.is_empty())
            .ok_or_else(|| invalid("full-program resource storage lacks a root"))?;
        let mut place = self.local(root)?.place;
        let mut receiver_type = node.second_text.clone();
        for field in components {
            if field.is_empty() || field.contains('[') {
                return Err(invalid(
                    "full-program resource storage path is not a field chain",
                ));
            }
            let selected = self.field_place(builder, place, &receiver_type, field)?;
            place = selected.0;
            receiver_type = selected.1;
        }
        if receiver_type != node.ty {
            return Err(invalid(format!(
                "full-program resource storage type {} disagrees with {}",
                receiver_type, node.ty
            )));
        }
        if is_scalar_type(&node.ty) {
            Ok(Evaluated::Scalar(load_scalar(
                builder,
                place.address,
                &node.ty,
                self.pointer_type(),
            )?))
        } else {
            Ok(Evaluated::Aggregate(place))
        }
    }

    fn lower_conditional_cleanup(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let condition_node = &self.program.nodes[node.children[0]];
        let condition_eval = self.lower_expression(builder, node.children[0], None)?;
        let condition = self.scalar(builder, condition_eval, &condition_node.ty)?;
        let execute = builder.create_block();
        let done = builder.create_block();
        let condition = as_condition(builder, condition);
        builder.ins().brif(condition, execute, &[], done, &[]);
        builder.switch_to_block(execute);
        self.lower_expression(builder, node.children[1], None)?;
        builder.ins().jump(done, &[]);
        builder.switch_to_block(done);
        Ok(Evaluated::Void)
    }

    fn lower_cast(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let child = &self.program.nodes[node.children[0]];
        let child_eval = self.lower_expression(builder, node.children[0], Some(&node.ty))?;
        let value = self.scalar(builder, child_eval, &child.ty)?;
        let target = scalar_ir_type(&node.ty, self.pointer_type())?;
        let source = builder.func.dfg.value_type(value);
        let cast = if target == source {
            value
        } else if target.bits() < source.bits() {
            builder.ins().ireduce(target, value)
        } else {
            builder.ins().uextend(target, value)
        };
        Ok(Evaluated::Scalar(cast))
    }

    fn lower_binary(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let left_node = &self.program.nodes[node.children[0]];
        let right_node = &self.program.nodes[node.children[1]];
        let left_eval = self.lower_expression(builder, node.children[0], None)?;
        let mut left = self.scalar(builder, left_eval, &left_node.ty)?;
        if matches!(node.text.as_str(), "&&" | "||") {
            let evaluate_right = builder.create_block();
            let short_circuit = builder.create_block();
            let ready = builder.create_block();
            builder.append_block_param(ready, types::I8);
            let condition = as_condition(builder, left);
            if node.text == "&&" {
                builder
                    .ins()
                    .brif(condition, evaluate_right, &[], short_circuit, &[]);
            } else {
                builder
                    .ins()
                    .brif(condition, short_circuit, &[], evaluate_right, &[]);
            }
            builder.switch_to_block(short_circuit);
            let short_value = builder
                .ins()
                .iconst(types::I8, i64::from(node.text == "||"));
            builder.ins().jump(ready, &[short_value.into()]);
            builder.switch_to_block(evaluate_right);
            let right_eval = self.lower_expression(builder, node.children[1], None)?;
            let right = self.scalar(builder, right_eval, &right_node.ty)?;
            let right = as_condition(builder, right);
            builder.ins().jump(ready, &[right.into()]);
            builder.switch_to_block(ready);
            return Ok(Evaluated::Scalar(builder.block_params(ready)[0]));
        }
        let right_eval = self.lower_expression(builder, node.children[1], None)?;
        let mut right = self.scalar(builder, right_eval, &right_node.ty)?;
        let left_ir = builder.func.dfg.value_type(left);
        let right_ir = builder.func.dfg.value_type(right);
        if left_ir != right_ir {
            if left_ir.bits() < right_ir.bits() {
                left = builder.ins().uextend(right_ir, left);
            } else {
                right = builder.ins().uextend(left_ir, right);
            }
        }
        let value = match node.text.as_str() {
            "+" if is_pointer_type(&left_node.ty) => {
                let right = if builder.func.dfg.value_type(right) == types::I64 {
                    right
                } else {
                    builder.ins().uextend(types::I64, right)
                };
                let inner = pointer_inner_type(&left_node.ty)
                    .ok_or_else(|| invalid("pointer arithmetic lacks pointee type"))?;
                let size = self.layouts.layout(inner)?.size;
                let scaled = builder.ins().imul_imm(right, i64::from(size));
                builder.ins().iadd(left, scaled)
            }
            "+" => builder.ins().iadd(left, right),
            "-" => builder.ins().isub(left, right),
            "*" => builder.ins().imul(left, right),
            "/" => builder.ins().sdiv(left, right),
            "==" => builder.ins().icmp(IntCC::Equal, left, right),
            "!=" => builder.ins().icmp(IntCC::NotEqual, left, right),
            "<" => builder.ins().icmp(IntCC::SignedLessThan, left, right),
            "<=" => builder
                .ins()
                .icmp(IntCC::SignedLessThanOrEqual, left, right),
            ">" => builder.ins().icmp(IntCC::SignedGreaterThan, left, right),
            ">=" => builder
                .ins()
                .icmp(IntCC::SignedGreaterThanOrEqual, left, right),
            operator => {
                return Err(invalid(format!(
                    "unsupported full-program operator {operator}"
                )))
            }
        };
        Ok(Evaluated::Scalar(value))
    }

    fn lower_call(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
        expected_type: Option<&str>,
    ) -> Result<Evaluated, Box<dyn Error>> {
        if is_inline_call(self.program, node) {
            return self.lower_inline_call(builder, node, expected_type);
        }
        let callable = if let Some(callable) = self.functions.get(&node.second_text) {
            callable.clone()
        } else {
            let symbol = runtime_symbol(node);
            self.runtime.get(&symbol).cloned().ok_or_else(|| {
                invalid(format!(
                    "full-program runtime call {symbol} was not declared"
                ))
            })?
        };
        let arguments: Vec<_> = node.children[1..]
            .iter()
            .map(|child| (*child, self.program.nodes[*child].ty.clone()))
            .collect();
        self.emit_call(builder, &callable, &arguments)
    }

    fn emit_call(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        callable: &Callable,
        arguments: &[(usize, String)],
    ) -> Result<Evaluated, Box<dyn Error>> {
        if callable.parameters.len() != arguments.len() {
            return Err(invalid(
                "full-program call arity disagrees with callable ABI",
            ));
        }
        let mut values = Vec::new();
        let result_place = if let AbiShape::AggregateMemory(_) = callable.abi.result {
            let place = self.place_for_type(builder, &callable.result)?;
            values.push(place.address);
            Some(place)
        } else {
            None
        };
        for (index, (node_index, argument_type)) in arguments.iter().enumerate() {
            let parameter_type = &callable.parameters[index];
            let evaluated = self.lower_expression(builder, *node_index, Some(parameter_type))?;
            match callable.abi.parameters[index] {
                AbiShape::Scalar(expected) => {
                    let mut value = if argument_type == "Arena"
                        && is_pointer_type(parameter_type)
                        && pointer_inner_type(parameter_type) == Some("Arena")
                    {
                        self.arena_address(builder, evaluated, argument_type)?
                    } else if argument_type == parameter_type {
                        self.scalar(builder, evaluated, argument_type)?
                    } else if matches!(parameter_type.as_str(), "I8" | "I32" | "I64" | "Ptr") {
                        self.scalar(builder, evaluated, argument_type)?
                    } else if is_pointer_type(argument_type)
                        && is_pointer_type(parameter_type)
                        && pointer_inner_type(argument_type) == pointer_inner_type(parameter_type)
                    {
                        self.scalar(builder, evaluated, argument_type)?
                    } else if !is_pointer_type(argument_type)
                        && !is_pointer_type(parameter_type)
                        && is_scalar_type(argument_type)
                        && is_scalar_type(parameter_type)
                    {
                        self.scalar(builder, evaluated, argument_type)?
                    } else if pointer_inner_type(argument_type)
                        .is_some_and(|inner| inner == parameter_type)
                    {
                        let source = self.scalar(builder, evaluated, argument_type)?;
                        load_scalar(builder, source, parameter_type, self.pointer_type())?
                    } else {
                        return Err(invalid(format!(
                            "full-program call argument type {argument_type} cannot initialize {parameter_type}"
                        )));
                    };
                    let actual = builder.func.dfg.value_type(value);
                    if actual != expected {
                        value = if actual.bits() < expected.bits() {
                            builder.ins().uextend(expected, value)
                        } else {
                            builder.ins().ireduce(expected, value)
                        };
                    }
                    values.push(value);
                }
                AbiShape::ArenaParameter => {
                    values.push(self.arena_address(builder, evaluated, argument_type)?);
                }
                AbiShape::AggregateOne => {
                    let place =
                        self.evaluated_place_as(builder, evaluated, argument_type, parameter_type)?;
                    values.push(builder.ins().load(
                        types::I64,
                        MemFlags::trusted(),
                        place.address,
                        0,
                    ));
                }
                AbiShape::AggregateTwo => {
                    let place =
                        self.evaluated_place_as(builder, evaluated, argument_type, parameter_type)?;
                    values.push(builder.ins().load(
                        types::I64,
                        MemFlags::trusted(),
                        place.address,
                        0,
                    ));
                    values.push(builder.ins().load(
                        types::I64,
                        MemFlags::trusted(),
                        place.address,
                        8,
                    ));
                }
                AbiShape::AggregateMemory(_) => {
                    values.push(
                        self.evaluated_place_as(builder, evaluated, argument_type, parameter_type)?
                            .address,
                    );
                }
                AbiShape::Void => return Err(invalid("void call argument reached lowering")),
            }
        }
        let reference = self.module.declare_func_in_func(callable.id, builder.func);
        let instruction = builder.ins().call(reference, &values);
        let results = builder.inst_results(instruction).to_vec();
        match callable.abi.result {
            AbiShape::Void => Ok(Evaluated::Void),
            AbiShape::Scalar(_) => Ok(Evaluated::Scalar(results[0])),
            AbiShape::AggregateOne | AbiShape::AggregateTwo => {
                let place = self.place_for_type(builder, &callable.result)?;
                let layout = self.layouts.layout(&callable.result)?;
                self.zero_place(builder, place, &layout);
                builder
                    .ins()
                    .store(MemFlags::trusted(), results[0], place.address, 0);
                if matches!(callable.abi.result, AbiShape::AggregateTwo) {
                    builder
                        .ins()
                        .store(MemFlags::trusted(), results[1], place.address, 8);
                }
                Ok(Evaluated::Aggregate(place))
            }
            AbiShape::AggregateMemory(_) => Ok(Evaluated::Aggregate(result_place.unwrap())),
            AbiShape::ArenaParameter => unreachable!(),
        }
    }

    fn lower_inline_call(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
        expected_type: Option<&str>,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let name = inline_call_name(self.program, node)
            .ok_or_else(|| invalid("inline call lost its operation name"))?;
        match name.as_str() {
            "len" => self.lower_len(builder, node),
            "VectorNew" | "HashMapNew" | "PoolNew" | "GraphNew" => {
                self.lower_collection_new(builder, node)
            }
            "Concat" => self.lower_concat(builder, node),
            "FormatInt" => self.lower_format_int(builder, node),
            "Format" => self.lower_format(builder, node),
            "ArenaAlloc" => self.lower_arena_alloc(builder, node, expected_type),
            "New" => self.lower_arena_new(builder),
            "Free" => self.lower_arena_free(builder, node),
            "Set" | "get_ref"
                if self
                    .inline_receiver_type(node)
                    .is_some_and(|ty| ty == "Arena" || ty.starts_with("Reference(Arena,")) =>
            {
                self.lower_arena_method(builder, node, &name)
            }
            "Push" | "Pop" | "Clear" | "Set" => self.lower_vector_method(builder, node, &name),
            "Get" | "get_opt" | "Insert" | "Remove" | "Keys" | "Contains" => {
                self.lower_hashmap_method(builder, node, &name)
            }
            "AddNode" | "AddEdge" | "GetNode" => self.lower_graph_method(builder, node, &name),
            _ => Err(invalid(format!("inline call {name} lacks lowering"))),
        }
    }

    fn inline_receiver_index(&self, node: &Node) -> Option<usize> {
        let callee = &self.program.nodes[node.children[0]];
        (callee.kind == "FieldOrMethodSelect" && !callee.children.is_empty())
            .then_some(callee.children[0])
    }

    fn inline_receiver_type(&self, node: &Node) -> Option<&str> {
        self.inline_receiver_index(node)
            .map(|index| self.program.nodes[index].ty.as_str())
    }

    fn lower_len(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let argument = node.children[1];
        let ty = self.program.nodes[argument].ty.clone();
        let value = self.lower_expression(builder, argument, None)?;
        let place = self.evaluated_place(builder, value, &ty)?;
        let offset = if ty == "Str" {
            8
        } else {
            self.layouts
                .layout(&ty)?
                .fields
                .get("len")
                .ok_or_else(|| invalid(format!("len lacks field authority for {ty}")))?
                .offset
        };
        Ok(Evaluated::Scalar(builder.ins().load(
            types::I32,
            MemFlags::trusted(),
            place.address,
            offset as i32,
        )))
    }

    fn lower_collection_new(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let place = self.place_for_type(builder, &node.ty)?;
        let arena_node = node.children[1];
        let arena_type = self.program.nodes[arena_node].ty.clone();
        let arena_eval = self.lower_expression(builder, arena_node, None)?;
        let arena = self.arena_address(builder, arena_eval, &arena_type)?;
        let target_type = if inline_call_name(self.program, node).as_deref() == Some("GraphNew") {
            let (nodes, nodes_ty) = self.field_place(builder, place, &node.ty, "nodes")?;
            let (arena_field, _) = self.field_place(builder, nodes, &nodes_ty, "arena")?;
            arena_field
        } else {
            self.field_place(builder, place, &node.ty, "arena")?.0
        };
        builder
            .ins()
            .store(MemFlags::trusted(), arena, target_type.address, 0);
        Ok(Evaluated::Aggregate(place))
    }

    fn lower_concat(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let left_eval = self.lower_expression(builder, node.children[1], None)?;
        let left = self.evaluated_place(builder, left_eval, "Str")?;
        let right_eval = self.lower_expression(builder, node.children[2], None)?;
        let right = self.evaluated_place(builder, right_eval, "Str")?;
        let left_data =
            builder
                .ins()
                .load(self.pointer_type(), MemFlags::trusted(), left.address, 0);
        let left_len = builder
            .ins()
            .load(types::I32, MemFlags::trusted(), left.address, 8);
        let right_data =
            builder
                .ins()
                .load(self.pointer_type(), MemFlags::trusted(), right.address, 0);
        let right_len = builder
            .ins()
            .load(types::I32, MemFlags::trusted(), right.address, 8);
        let total = builder.ins().iadd(left_len, right_len);
        let allocation = builder.ins().iadd_imm(total, 1);
        let scratch = self
            .runtime
            .get("os_ScratchAlloc")
            .ok_or_else(|| invalid("os_ScratchAlloc import missing"))?
            .clone();
        let allocation64 = builder.ins().uextend(types::I64, allocation);
        let reference = self.module.declare_func_in_func(scratch.id, builder.func);
        let call = builder.ins().call(reference, &[allocation64]);
        let destination = builder.inst_results(call)[0];
        self.copy_dynamic(builder, destination, left_data, left_len)?;
        let left_len64 = builder.ins().uextend(types::I64, left_len);
        let right_destination = builder.ins().iadd(destination, left_len64);
        self.copy_dynamic(builder, right_destination, right_data, right_len)?;
        let total64 = builder.ins().uextend(types::I64, total);
        let terminator = builder.ins().iadd(destination, total64);
        let zero = builder.ins().iconst(types::I8, 0);
        builder
            .ins()
            .store(MemFlags::trusted(), zero, terminator, 0);
        let result = self.place_for_type(builder, "Str")?;
        builder
            .ins()
            .store(MemFlags::trusted(), destination, result.address, 0);
        builder
            .ins()
            .store(MemFlags::trusted(), total, result.address, 8);
        Ok(Evaluated::Aggregate(result))
    }

    fn copy_dynamic(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        destination: Value,
        source: Value,
        size_i32: Value,
    ) -> Result<(), Box<dyn Error>> {
        let callable = self
            .runtime
            .get("memcpy")
            .ok_or_else(|| invalid("memcpy import missing"))?;
        let size = builder.ins().uextend(types::I64, size_i32);
        let reference = self.module.declare_func_in_func(callable.id, builder.func);
        builder.ins().call(reference, &[destination, source, size]);
        Ok(())
    }

    fn lower_format_int(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let argument_node = &self.program.nodes[node.children[1]];
        let argument_eval = self.lower_expression(builder, node.children[1], None)?;
        let argument = self.scalar(builder, argument_eval, &argument_node.ty)?;
        let argument64 = builder.ins().sextend(types::I64, argument);
        let capacity = builder.ins().iconst(types::I64, 16);
        self.emit_snprintf(builder, "%d", &[argument64], capacity)
    }

    fn lower_format(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let format_node = &self.program.nodes[node.children[1]];
        if format_node.kind != "StringLiteral" {
            return Err(invalid(
                "std.Format requires its existing literal format authority",
            ));
        }
        let transformed = snprintf_format(&format_node.text);
        let mut arguments = Vec::new();
        let mut capacity = builder
            .ins()
            .iconst(types::I64, (transformed.len() + 1) as i64);
        for child in &node.children[2..] {
            let child_node = &self.program.nodes[*child];
            let evaluated = self.lower_expression(builder, *child, None)?;
            if child_node.ty == "Str" {
                let place = self.evaluated_place(builder, evaluated, "Str")?;
                let length = builder
                    .ins()
                    .load(types::I32, MemFlags::trusted(), place.address, 8);
                let data =
                    builder
                        .ins()
                        .load(self.pointer_type(), MemFlags::trusted(), place.address, 0);
                let length64 = builder.ins().uextend(types::I64, length);
                capacity = builder.ins().iadd(capacity, length64);
                arguments.push(length64);
                arguments.push(data);
            } else if child_node.ty == "Int" || child_node.ty.starts_with("Index(\"") {
                let value = self.scalar(builder, evaluated, &child_node.ty)?;
                arguments.push(builder.ins().sextend(types::I64, value));
                capacity = builder.ins().iadd_imm(capacity, 16);
            } else {
                return Err(invalid(format!(
                    "std.Format argument {} lacks the existing integer/string authority",
                    child_node.ty
                )));
            }
        }
        if arguments.len() > 8 {
            return Err(invalid(
                "std.Format exceeds the registered compiler format arity",
            ));
        }
        self.emit_snprintf(builder, &transformed, &arguments, capacity)
    }

    fn emit_snprintf(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        format: &str,
        arguments: &[Value],
        capacity: Value,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let scratch = self.runtime.get("os_ScratchAlloc").unwrap().clone();
        let scratch_ref = self.module.declare_func_in_func(scratch.id, builder.func);
        let allocation = builder.ins().call(scratch_ref, &[capacity]);
        let destination = builder.inst_results(allocation)[0];
        let format_id = self
            .strings
            .get(format)
            .ok_or_else(|| invalid("snprintf format data missing"))?;
        let format_ref = self.module.declare_data_in_func(*format_id, builder.func);
        let format_address = builder.ins().symbol_value(self.pointer_type(), format_ref);
        let mut call_arguments = vec![destination, capacity, format_address];
        call_arguments.extend_from_slice(arguments);
        let zero = builder.ins().iconst(types::I64, 0);
        while call_arguments.len() < 11 {
            call_arguments.push(zero);
        }
        let snprintf = self.runtime.get("snprintf").unwrap().clone();
        let snprintf_ref = self.module.declare_func_in_func(snprintf.id, builder.func);
        let call = builder.ins().call(snprintf_ref, &call_arguments);
        let length = builder.inst_results(call)[0];
        let result = self.place_for_type(builder, "Str")?;
        builder
            .ins()
            .store(MemFlags::trusted(), destination, result.address, 0);
        builder
            .ins()
            .store(MemFlags::trusted(), length, result.address, 8);
        Ok(Evaluated::Aggregate(result))
    }

    fn lower_arena_alloc(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
        expected_type: Option<&str>,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let expected =
            expected_type.ok_or_else(|| invalid("ArenaAlloc lacks contextual result type"))?;
        let element_type = index_element_layout_type(expected).map_err(|_| {
            invalid(format!(
                "ArenaAlloc context is not an Index type: {expected}"
            ))
        })?;
        let size = self.layouts.layout(&element_type)?.size;
        let arena_node = node.children[1];
        let arena_type = self.program.nodes[arena_node].ty.clone();
        let arena_eval = self.lower_expression(builder, arena_node, None)?;
        let arena = self.arena_address(builder, arena_eval, &arena_type)?;
        let size_value = builder.ins().iconst(types::I64, i64::from(size));
        let callable = self.runtime.get("os_ArenaAlloc").unwrap().clone();
        let reference = self.module.declare_func_in_func(callable.id, builder.func);
        let call = builder.ins().call(reference, &[arena, size_value]);
        Ok(Evaluated::Scalar(builder.inst_results(call)[0]))
    }

    fn lower_arena_new(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let callable = self.runtime.get("os_Arena_New").unwrap().clone();
        self.emit_call(builder, &callable, &[])
    }

    fn lower_arena_free(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let receiver = self
            .inline_receiver_index(node)
            .ok_or_else(|| invalid("Arena.Free lacks receiver"))?;
        let arena = self.lower_place(builder, receiver)?.address;
        let callable = self.runtime.get("os_Arena_Free").unwrap().clone();
        let reference = self.module.declare_func_in_func(callable.id, builder.func);
        builder.ins().call(reference, &[arena]);
        Ok(Evaluated::Void)
    }

    fn lower_arena_method(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
        name: &str,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let receiver_index = self
            .inline_receiver_index(node)
            .ok_or_else(|| invalid("Arena method lacks receiver"))?;
        let receiver_type = self.program.nodes[receiver_index].ty.clone();
        let receiver_eval = self.lower_expression(builder, receiver_index, None)?;
        let arena = self.arena_address(builder, receiver_eval, &receiver_type)?;
        let index_node = &self.program.nodes[node.children[1]];
        let index_eval = self.lower_expression(builder, node.children[1], None)?;
        let index = self.scalar(builder, index_eval, &index_node.ty)?;
        let base = builder
            .ins()
            .load(self.pointer_type(), MemFlags::trusted(), arena, 0);
        let index64 = builder.ins().uextend(types::I64, index);
        let address = builder.ins().iadd(base, index64);
        if name == "get_ref" {
            return Ok(Evaluated::Scalar(address));
        }
        let element_type = index_element_layout_type(&index_node.ty)?;
        let value_node = &self.program.nodes[node.children[2]];
        let value_eval = self.lower_expression(builder, node.children[2], Some(&element_type))?;
        self.store_evaluated_as(
            builder,
            Place { address },
            value_eval,
            &value_node.ty,
            &element_type,
        )?;
        Ok(Evaluated::Void)
    }

    fn lower_vector_method(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
        name: &str,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let receiver_index = self
            .inline_receiver_index(node)
            .ok_or_else(|| invalid("vector method lacks receiver"))?;
        let receiver_type = self.program.nodes[receiver_index].ty.clone();
        if !struct_type_name(&receiver_type).is_some_and(|value| value.starts_with("std_Vector_")) {
            return Err(invalid(format!(
                "{name} receiver is not a vector: {receiver_type}"
            )));
        }
        let receiver = self.lower_place(builder, receiver_index)?;
        let (data_field, data_type) =
            self.field_place(builder, receiver, &receiver_type, "data")?;
        let (len_field, _) = self.field_place(builder, receiver, &receiver_type, "len")?;
        let (capacity_field, _) =
            self.field_place(builder, receiver, &receiver_type, "capacity")?;
        let element_type = pointer_inner_type(&data_type)
            .ok_or_else(|| invalid("vector data field is not a pointer"))?
            .to_string();
        let element_size = self.layouts.layout(&element_type)?.size;
        if name == "Clear" {
            let zero = builder.ins().iconst(types::I32, 0);
            builder
                .ins()
                .store(MemFlags::trusted(), zero, len_field.address, 0);
            return Ok(Evaluated::Void);
        }
        if name == "Set" {
            let index_node = &self.program.nodes[node.children[1]];
            let index_eval = self.lower_expression(builder, node.children[1], None)?;
            let index = self.scalar(builder, index_eval, &index_node.ty)?;
            let data = builder.ins().load(
                self.pointer_type(),
                MemFlags::trusted(),
                data_field.address,
                0,
            );
            let index64 = builder.ins().uextend(types::I64, index);
            let offset = builder.ins().imul_imm(index64, i64::from(element_size));
            let destination = Place {
                address: builder.ins().iadd(data, offset),
            };
            let value_node = &self.program.nodes[node.children[2]];
            let value_eval =
                self.lower_expression(builder, node.children[2], Some(&element_type))?;
            self.store_evaluated_as(
                builder,
                destination,
                value_eval,
                &value_node.ty,
                &element_type,
            )?;
            return Ok(Evaluated::Void);
        }
        if name == "Pop" {
            let len = builder
                .ins()
                .load(types::I32, MemFlags::trusted(), len_field.address, 0);
            let new_len = builder.ins().iadd_imm(len, -1);
            builder
                .ins()
                .store(MemFlags::trusted(), new_len, len_field.address, 0);
            let data = builder.ins().load(
                self.pointer_type(),
                MemFlags::trusted(),
                data_field.address,
                0,
            );
            let index64 = builder.ins().uextend(types::I64, new_len);
            let offset = builder.ins().imul_imm(index64, i64::from(element_size));
            let source = Place {
                address: builder.ins().iadd(data, offset),
            };
            let result = self.place_for_type(builder, &element_type)?;
            self.copy_place(builder, result, source, element_size)?;
            let layout = self.layouts.layout(&element_type)?;
            self.zero_place(builder, source, &layout);
            return if is_scalar_type(&element_type) {
                Ok(Evaluated::Scalar(load_scalar(
                    builder,
                    result.address,
                    &element_type,
                    self.pointer_type(),
                )?))
            } else {
                Ok(Evaluated::Aggregate(result))
            };
        }
        if name != "Push" {
            return Err(invalid(format!("unsupported vector method {name}")));
        }
        let len = builder
            .ins()
            .load(types::I32, MemFlags::trusted(), len_field.address, 0);
        let capacity =
            builder
                .ins()
                .load(types::I32, MemFlags::trusted(), capacity_field.address, 0);
        let must_grow = builder
            .ins()
            .icmp(IntCC::SignedGreaterThanOrEqual, len, capacity);
        let grow = builder.create_block();
        let ready = builder.create_block();
        builder.ins().brif(must_grow, grow, &[], ready, &[]);
        builder.switch_to_block(grow);
        let capacity_zero = builder.ins().icmp_imm(IntCC::Equal, capacity, 0);
        let eight = builder.ins().iconst(types::I32, 8);
        let doubled = builder.ins().imul_imm(capacity, 2);
        let new_capacity = builder.ins().select(capacity_zero, eight, doubled);
        let (arena_field, _) = self.field_place(builder, receiver, &receiver_type, "arena")?;
        let arena = builder.ins().load(
            self.pointer_type(),
            MemFlags::trusted(),
            arena_field.address,
            0,
        );
        let bytes32 = builder
            .ins()
            .imul_imm(new_capacity, i64::from(element_size));
        let bytes = builder.ins().uextend(types::I64, bytes32);
        let allocate = self.runtime.get("os_ArenaAlloc").unwrap().clone();
        let allocate_ref = self.module.declare_func_in_func(allocate.id, builder.func);
        let allocation = builder.ins().call(allocate_ref, &[arena, bytes]);
        let allocation_result = builder.inst_results(allocation)[0];
        let offset = builder.ins().uextend(types::I64, allocation_result);
        let base = builder
            .ins()
            .load(self.pointer_type(), MemFlags::trusted(), arena, 0);
        let new_data = builder.ins().iadd(base, offset);
        let old_data = builder.ins().load(
            self.pointer_type(),
            MemFlags::trusted(),
            data_field.address,
            0,
        );
        let has_values = builder.ins().icmp_imm(IntCC::NotEqual, len, 0);
        let copy = builder.create_block();
        let grown = builder.create_block();
        builder.ins().brif(has_values, copy, &[], grown, &[]);
        builder.switch_to_block(copy);
        let used32 = builder.ins().imul_imm(len, i64::from(element_size));
        self.copy_dynamic(builder, new_data, old_data, used32)?;
        builder.ins().jump(grown, &[]);
        builder.switch_to_block(grown);
        builder
            .ins()
            .store(MemFlags::trusted(), new_data, data_field.address, 0);
        builder
            .ins()
            .store(MemFlags::trusted(), new_capacity, capacity_field.address, 0);
        builder.ins().jump(ready, &[]);
        builder.switch_to_block(ready);
        let data = builder.ins().load(
            self.pointer_type(),
            MemFlags::trusted(),
            data_field.address,
            0,
        );
        let index64 = builder.ins().uextend(types::I64, len);
        let value_offset = builder.ins().imul_imm(index64, i64::from(element_size));
        let destination = Place {
            address: builder.ins().iadd(data, value_offset),
        };
        let value_node = &self.program.nodes[node.children[1]];
        let value_eval = self.lower_expression(builder, node.children[1], Some(&element_type))?;
        self.store_evaluated_as(
            builder,
            destination,
            value_eval,
            &value_node.ty,
            &element_type,
        )?;
        let next_len = builder.ins().iadd_imm(len, 1);
        builder
            .ins()
            .store(MemFlags::trusted(), next_len, len_field.address, 0);
        Ok(Evaluated::Void)
    }

    fn store_evaluated(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        destination: Place,
        value: Evaluated,
        ty: &str,
    ) -> Result<(), Box<dyn Error>> {
        if is_scalar_type(ty) {
            let value = self.scalar(builder, value, ty)?;
            let value =
                self.coerce_scalar(builder, value, scalar_ir_type(ty, self.pointer_type())?);
            store_scalar(builder, destination.address, value);
        } else {
            let source = self.evaluated_place(builder, value, ty)?;
            let size = self.layouts.layout(ty)?.size;
            self.copy_place(builder, destination, source, size)?;
        }
        Ok(())
    }

    fn lower_hashmap_method(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
        name: &str,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let receiver_index = self
            .inline_receiver_index(node)
            .ok_or_else(|| invalid("hashmap method lacks receiver"))?;
        let receiver_type = self.program.nodes[receiver_index].ty.clone();
        if !struct_type_name(&receiver_type).is_some_and(|value| value.starts_with("std_HashMap_"))
        {
            return Err(invalid(format!(
                "{name} receiver is not a hashmap: {receiver_type}"
            )));
        }
        let map = self.lower_place(builder, receiver_index)?;
        let (_, keys_type) = self.field_place(builder, map, &receiver_type, "keys")?;
        let (_, values_type) = self.field_place(builder, map, &receiver_type, "values")?;
        let key_type = pointer_inner_type(&keys_type)
            .ok_or_else(|| invalid("hashmap key pointer is malformed"))?
            .to_string();
        let value_type = pointer_inner_type(&values_type)
            .ok_or_else(|| invalid("hashmap value pointer is malformed"))?
            .to_string();
        let key_size = self.layouts.layout(&key_type)?.size;
        let value_size = self.layouts.layout(&value_type)?.size;
        if name == "Clear" {
            let callable = self.runtime.get("os_HashMapClear_impl").unwrap().clone();
            let reference = self.module.declare_func_in_func(callable.id, builder.func);
            let key_size = builder.ins().iconst(types::I64, i64::from(key_size));
            let value_size = builder.ins().iconst(types::I64, i64::from(value_size));
            builder
                .ins()
                .call(reference, &[map.address, key_size, value_size]);
            return Ok(Evaluated::Void);
        }
        if name == "Keys" {
            return self.lower_hashmap_keys(
                builder,
                node,
                map,
                &receiver_type,
                &key_type,
                key_size,
            );
        }
        let key_node = &self.program.nodes[node.children[1]];
        let key_eval = self.lower_expression(builder, node.children[1], Some(&key_type))?;
        let key = self.evaluated_place_as(builder, key_eval, &key_node.ty, &key_type)?;
        let is_string = builder
            .ins()
            .iconst(types::I32, i64::from(key_type == "Str"));
        let key_size_value = builder.ins().iconst(types::I64, i64::from(key_size));
        if name == "Contains" {
            let callable = self.runtime.get("os_HashMapContains_impl").unwrap().clone();
            let reference = self.module.declare_func_in_func(callable.id, builder.func);
            let call = builder.ins().call(
                reference,
                &[map.address, key.address, is_string, key_size_value],
            );
            return Ok(Evaluated::Scalar(builder.inst_results(call)[0]));
        }
        if name == "Remove" {
            let callable = self.runtime.get("os_HashMapRemove_impl").unwrap().clone();
            let reference = self.module.declare_func_in_func(callable.id, builder.func);
            let value_size_value = builder.ins().iconst(types::I64, i64::from(value_size));
            builder.ins().call(
                reference,
                &[
                    map.address,
                    key.address,
                    is_string,
                    key_size_value,
                    value_size_value,
                ],
            );
            return Ok(Evaluated::Void);
        }
        let contains_callable = self.runtime.get("os_HashMapContains_impl").unwrap().clone();
        let contains_ref = self
            .module
            .declare_func_in_func(contains_callable.id, builder.func);
        let contains_call = builder.ins().call(
            contains_ref,
            &[map.address, key.address, is_string, key_size_value],
        );
        let contains = builder.inst_results(contains_call)[0];
        let ref_callable = self.runtime.get("os_HashMapRef_impl").unwrap().clone();
        let ref_ref = self
            .module
            .declare_func_in_func(ref_callable.id, builder.func);
        let value_size_value = builder.ins().iconst(types::I64, i64::from(value_size));
        if name == "Insert" {
            let call = builder.ins().call(
                ref_ref,
                &[
                    map.address,
                    key.address,
                    is_string,
                    key_size_value,
                    value_size_value,
                ],
            );
            let destination = Place {
                address: builder.inst_results(call)[0],
            };
            let value_node = &self.program.nodes[node.children[2]];
            let value_eval = self.lower_expression(builder, node.children[2], Some(&value_type))?;
            self.store_evaluated_as(
                builder,
                destination,
                value_eval,
                &value_node.ty,
                &value_type,
            )?;
            return Ok(Evaluated::Void);
        }
        if name != "Get" && name != "get_opt" {
            return Err(invalid(format!("unsupported hashmap method {name}")));
        }
        let result = self.place_for_type(builder, &node.ty)?;
        if name == "get_opt" {
            let (tag, _) = self.field_place(builder, result, &node.ty, "tag")?;
            let none_index = self.enum_variant_index(&node.ty, "None")?;
            let tag_value = builder.ins().iconst(types::I32, none_index as i64);
            builder
                .ins()
                .store(MemFlags::trusted(), tag_value, tag.address, 0);
        }
        let present = builder.create_block();
        let ready = builder.create_block();
        let contains_condition = as_condition(builder, contains);
        builder
            .ins()
            .brif(contains_condition, present, &[], ready, &[]);
        builder.switch_to_block(present);
        let call = builder.ins().call(
            ref_ref,
            &[
                map.address,
                key.address,
                is_string,
                key_size_value,
                value_size_value,
            ],
        );
        let source = Place {
            address: builder.inst_results(call)[0],
        };
        if name == "Get" {
            let (ok, _) = self.field_place(builder, result, &node.ty, "Ok")?;
            let one = builder.ins().iconst(types::I8, 1);
            builder.ins().store(MemFlags::trusted(), one, ok.address, 0);
            let (value, _) = self.field_place(builder, result, &node.ty, "Val")?;
            self.copy_place(builder, value, source, value_size)?;
        } else {
            let (tag, _) = self.field_place(builder, result, &node.ty, "tag")?;
            let some_index = self.enum_variant_index(&node.ty, "Some")?;
            let tag_value = builder.ins().iconst(types::I32, some_index as i64);
            builder
                .ins()
                .store(MemFlags::trusted(), tag_value, tag.address, 0);
            let (some, some_type) = self.field_place(builder, result, &node.ty, "Some")?;
            let (value, _) = self.field_place(builder, some, &some_type, "val")?;
            self.copy_place(builder, value, source, value_size)?;
        }
        builder.ins().jump(ready, &[]);
        builder.switch_to_block(ready);
        Ok(Evaluated::Aggregate(result))
    }

    fn enum_variant_index(&self, ty: &str, variant: &str) -> Result<usize, Box<dyn Error>> {
        let name =
            struct_type_name(ty).ok_or_else(|| invalid("enum type is not a struct identity"))?;
        let enumeration = self
            .layouts
            .enums
            .get(name.as_str())
            .ok_or_else(|| invalid(format!("{name} lacks enum authority")))?;
        enumeration
            .variants
            .iter()
            .position(|value| value == variant)
            .ok_or_else(|| invalid(format!("enum {name} has no variant {variant}")))
    }

    fn push_place_vector(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        vector: Place,
        vector_type: &str,
        source: Place,
        element_type: &str,
    ) -> Result<(), Box<dyn Error>> {
        let element_size = self.layouts.layout(element_type)?.size;
        let (data_field, _) = self.field_place(builder, vector, vector_type, "data")?;
        let (len_field, _) = self.field_place(builder, vector, vector_type, "len")?;
        let (capacity_field, _) = self.field_place(builder, vector, vector_type, "capacity")?;
        let len = builder
            .ins()
            .load(types::I32, MemFlags::trusted(), len_field.address, 0);
        let capacity =
            builder
                .ins()
                .load(types::I32, MemFlags::trusted(), capacity_field.address, 0);
        let must_grow = builder
            .ins()
            .icmp(IntCC::SignedGreaterThanOrEqual, len, capacity);
        let grow = builder.create_block();
        let ready = builder.create_block();
        builder.ins().brif(must_grow, grow, &[], ready, &[]);
        builder.switch_to_block(grow);
        let capacity_zero = builder.ins().icmp_imm(IntCC::Equal, capacity, 0);
        let eight = builder.ins().iconst(types::I32, 8);
        let doubled = builder.ins().imul_imm(capacity, 2);
        let new_capacity = builder.ins().select(capacity_zero, eight, doubled);
        let (arena_field, _) = self.field_place(builder, vector, vector_type, "arena")?;
        let arena = builder.ins().load(
            self.pointer_type(),
            MemFlags::trusted(),
            arena_field.address,
            0,
        );
        let bytes32 = builder
            .ins()
            .imul_imm(new_capacity, i64::from(element_size));
        let bytes = builder.ins().uextend(types::I64, bytes32);
        let allocate = self.runtime.get("os_ArenaAlloc").unwrap().clone();
        let allocate_ref = self.module.declare_func_in_func(allocate.id, builder.func);
        let allocation = builder.ins().call(allocate_ref, &[arena, bytes]);
        let allocation_result = builder.inst_results(allocation)[0];
        let allocation_offset = builder.ins().uextend(types::I64, allocation_result);
        let base = builder
            .ins()
            .load(self.pointer_type(), MemFlags::trusted(), arena, 0);
        let new_data = builder.ins().iadd(base, allocation_offset);
        let old_data = builder.ins().load(
            self.pointer_type(),
            MemFlags::trusted(),
            data_field.address,
            0,
        );
        let has_values = builder.ins().icmp_imm(IntCC::NotEqual, len, 0);
        let copy = builder.create_block();
        let grown = builder.create_block();
        builder.ins().brif(has_values, copy, &[], grown, &[]);
        builder.switch_to_block(copy);
        let used = builder.ins().imul_imm(len, i64::from(element_size));
        self.copy_dynamic(builder, new_data, old_data, used)?;
        builder.ins().jump(grown, &[]);
        builder.switch_to_block(grown);
        builder
            .ins()
            .store(MemFlags::trusted(), new_data, data_field.address, 0);
        builder
            .ins()
            .store(MemFlags::trusted(), new_capacity, capacity_field.address, 0);
        builder.ins().jump(ready, &[]);
        builder.switch_to_block(ready);
        let data = builder.ins().load(
            self.pointer_type(),
            MemFlags::trusted(),
            data_field.address,
            0,
        );
        let index = builder.ins().uextend(types::I64, len);
        let offset = builder.ins().imul_imm(index, i64::from(element_size));
        let destination = Place {
            address: builder.ins().iadd(data, offset),
        };
        self.copy_place(builder, destination, source, element_size)?;
        let next_len = builder.ins().iadd_imm(len, 1);
        builder
            .ins()
            .store(MemFlags::trusted(), next_len, len_field.address, 0);
        Ok(())
    }

    fn lower_hashmap_keys(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
        map: Place,
        map_type: &str,
        key_type: &str,
        key_size: u32,
    ) -> Result<Evaluated, Box<dyn Error>> {
        if key_type != "Str" {
            return Err(invalid(
                "compiler hashmap Keys requires its existing string-key authority",
            ));
        }
        let result = self.place_for_type(builder, &node.ty)?;
        let (map_arena_field, _) = self.field_place(builder, map, map_type, "arena")?;
        let arena = builder.ins().load(
            self.pointer_type(),
            MemFlags::trusted(),
            map_arena_field.address,
            0,
        );
        let (result_arena, _) = self.field_place(builder, result, &node.ty, "arena")?;
        builder
            .ins()
            .store(MemFlags::trusted(), arena, result_arena.address, 0);
        let (capacity_field, _) = self.field_place(builder, map, map_type, "capacity")?;
        let capacity =
            builder
                .ins()
                .load(types::I32, MemFlags::trusted(), capacity_field.address, 0);
        let (occupied_field, _) = self.field_place(builder, map, map_type, "occupied")?;
        let occupied = builder.ins().load(
            self.pointer_type(),
            MemFlags::trusted(),
            occupied_field.address,
            0,
        );
        let (keys_field, _) = self.field_place(builder, map, map_type, "keys")?;
        let keys = builder.ins().load(
            self.pointer_type(),
            MemFlags::trusted(),
            keys_field.address,
            0,
        );
        let loop_head = builder.create_block();
        let inspect = builder.create_block();
        let copy = builder.create_block();
        let advance = builder.create_block();
        let done = builder.create_block();
        builder.append_block_param(loop_head, types::I32);
        let zero = builder.ins().iconst(types::I32, 0);
        builder.ins().jump(loop_head, &[zero.into()]);
        builder.switch_to_block(loop_head);
        let index = builder.block_params(loop_head)[0];
        let in_range = builder.ins().icmp(IntCC::SignedLessThan, index, capacity);
        builder.ins().brif(in_range, inspect, &[], done, &[]);
        builder.switch_to_block(inspect);
        let index64 = builder.ins().uextend(types::I64, index);
        let occupied_offset = builder.ins().imul_imm(index64, 4);
        let occupied_address = builder.ins().iadd(occupied, occupied_offset);
        let is_occupied = builder
            .ins()
            .load(types::I32, MemFlags::trusted(), occupied_address, 0);
        let occupied_condition = as_condition(builder, is_occupied);
        builder
            .ins()
            .brif(occupied_condition, copy, &[], advance, &[]);
        builder.switch_to_block(copy);
        let key_offset = builder.ins().imul_imm(index64, i64::from(key_size));
        let source = builder.ins().iadd(keys, key_offset);
        self.push_place_vector(
            builder,
            result,
            &node.ty,
            Place { address: source },
            key_type,
        )?;
        builder.ins().jump(advance, &[]);
        builder.switch_to_block(advance);
        let next_index = builder.ins().iadd_imm(index, 1);
        builder.ins().jump(loop_head, &[next_index.into()]);
        builder.switch_to_block(done);
        Ok(Evaluated::Aggregate(result))
    }

    fn lower_graph_method(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
        name: &str,
    ) -> Result<Evaluated, Box<dyn Error>> {
        let receiver_index = self
            .inline_receiver_index(node)
            .ok_or_else(|| invalid("graph method lacks receiver"))?;
        let graph_type = self.program.nodes[receiver_index].ty.clone();
        let graph = self.lower_place(builder, receiver_index)?;
        let (pool, pool_type) = self.field_place(builder, graph, &graph_type, "nodes")?;
        let (data_field, data_type) = self.field_place(builder, pool, &pool_type, "data")?;
        let node_type = pointer_inner_type(&data_type)
            .ok_or_else(|| invalid("graph pool data is not a pointer"))?
            .to_string();
        let node_size = self.layouts.layout(&node_type)?.size;
        if name == "AddNode" {
            let graph_node = self.place_for_type(builder, &node_type)?;
            let (value, value_type) = self.field_place(builder, graph_node, &node_type, "value")?;
            let value_node = &self.program.nodes[node.children[1]];
            let value_eval = self.lower_expression(builder, node.children[1], Some(&value_type))?;
            self.store_evaluated_as(builder, value, value_eval, &value_node.ty, &value_type)?;
            let (edges, edges_type) = self.field_place(builder, graph_node, &node_type, "edges")?;
            let (pool_arena, _) = self.field_place(builder, pool, &pool_type, "arena")?;
            let arena = builder.ins().load(
                self.pointer_type(),
                MemFlags::trusted(),
                pool_arena.address,
                0,
            );
            let (edge_arena, _) = self.field_place(builder, edges, &edges_type, "arena")?;
            builder
                .ins()
                .store(MemFlags::trusted(), arena, edge_arena.address, 0);
            let allocate = self.runtime.get("std_PoolAlloc_impl").unwrap().clone();
            let reference = self.module.declare_func_in_func(allocate.id, builder.func);
            let size = builder.ins().iconst(types::I64, i64::from(node_size));
            let call = builder.ins().call(reference, &[pool.address, size]);
            let index = builder.inst_results(call)[0];
            let data = builder.ins().load(
                self.pointer_type(),
                MemFlags::trusted(),
                data_field.address,
                0,
            );
            let index64 = builder.ins().uextend(types::I64, index);
            let offset = builder.ins().imul_imm(index64, i64::from(node_size));
            let destination = Place {
                address: builder.ins().iadd(data, offset),
            };
            self.copy_place(builder, destination, graph_node, node_size)?;
            return Ok(Evaluated::Scalar(index));
        }
        let index_child = if name == "AddEdge" {
            node.children[1]
        } else {
            node.children[1]
        };
        let index_node = &self.program.nodes[index_child];
        let index_eval = self.lower_expression(builder, index_child, None)?;
        let index = self.scalar(builder, index_eval, &index_node.ty)?;
        let data = builder.ins().load(
            self.pointer_type(),
            MemFlags::trusted(),
            data_field.address,
            0,
        );
        let index64 = builder.ins().uextend(types::I64, index);
        let offset = builder.ins().imul_imm(index64, i64::from(node_size));
        let graph_node = Place {
            address: builder.ins().iadd(data, offset),
        };
        if name == "GetNode" {
            return Ok(Evaluated::Scalar(
                self.field_place(builder, graph_node, &node_type, "value")?
                    .0
                    .address,
            ));
        }
        if name != "AddEdge" {
            return Err(invalid(format!("unsupported graph method {name}")));
        }
        let (edges, edges_type) = self.field_place(builder, graph_node, &node_type, "edges")?;
        let to_node = &self.program.nodes[node.children[2]];
        let to_eval = self.lower_expression(builder, node.children[2], None)?;
        let to = self.scalar(builder, to_eval, &to_node.ty)?;
        self.push_scalar_vector(builder, edges, &edges_type, to, "Int")?;
        Ok(Evaluated::Void)
    }

    fn push_scalar_vector(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        vector: Place,
        vector_type: &str,
        value: Value,
        element_type: &str,
    ) -> Result<(), Box<dyn Error>> {
        let element_size = self.layouts.layout(element_type)?.size;
        let (data_field, _) = self.field_place(builder, vector, vector_type, "data")?;
        let (len_field, _) = self.field_place(builder, vector, vector_type, "len")?;
        let (capacity_field, _) = self.field_place(builder, vector, vector_type, "capacity")?;
        let len = builder
            .ins()
            .load(types::I32, MemFlags::trusted(), len_field.address, 0);
        let capacity =
            builder
                .ins()
                .load(types::I32, MemFlags::trusted(), capacity_field.address, 0);
        let must_grow = builder
            .ins()
            .icmp(IntCC::SignedGreaterThanOrEqual, len, capacity);
        let grow = builder.create_block();
        let ready = builder.create_block();
        builder.ins().brif(must_grow, grow, &[], ready, &[]);
        builder.switch_to_block(grow);
        let capacity_zero = builder.ins().icmp_imm(IntCC::Equal, capacity, 0);
        let eight = builder.ins().iconst(types::I32, 8);
        let doubled = builder.ins().imul_imm(capacity, 2);
        let new_capacity = builder.ins().select(capacity_zero, eight, doubled);
        let (arena_field, _) = self.field_place(builder, vector, vector_type, "arena")?;
        let arena = builder.ins().load(
            self.pointer_type(),
            MemFlags::trusted(),
            arena_field.address,
            0,
        );
        let bytes32 = builder
            .ins()
            .imul_imm(new_capacity, i64::from(element_size));
        let bytes = builder.ins().uextend(types::I64, bytes32);
        let allocate = self.runtime.get("os_ArenaAlloc").unwrap().clone();
        let allocate_ref = self.module.declare_func_in_func(allocate.id, builder.func);
        let allocation = builder.ins().call(allocate_ref, &[arena, bytes]);
        let allocation_result = builder.inst_results(allocation)[0];
        let offset = builder.ins().uextend(types::I64, allocation_result);
        let base = builder
            .ins()
            .load(self.pointer_type(), MemFlags::trusted(), arena, 0);
        let new_data = builder.ins().iadd(base, offset);
        let old_data = builder.ins().load(
            self.pointer_type(),
            MemFlags::trusted(),
            data_field.address,
            0,
        );
        let has_values = builder.ins().icmp_imm(IntCC::NotEqual, len, 0);
        let copy = builder.create_block();
        let grown = builder.create_block();
        builder.ins().brif(has_values, copy, &[], grown, &[]);
        builder.switch_to_block(copy);
        let used32 = builder.ins().imul_imm(len, i64::from(element_size));
        self.copy_dynamic(builder, new_data, old_data, used32)?;
        builder.ins().jump(grown, &[]);
        builder.switch_to_block(grown);
        builder
            .ins()
            .store(MemFlags::trusted(), new_data, data_field.address, 0);
        builder
            .ins()
            .store(MemFlags::trusted(), new_capacity, capacity_field.address, 0);
        builder.ins().jump(ready, &[]);
        builder.switch_to_block(ready);
        let data = builder.ins().load(
            self.pointer_type(),
            MemFlags::trusted(),
            data_field.address,
            0,
        );
        let index64 = builder.ins().uextend(types::I64, len);
        let offset = builder.ins().imul_imm(index64, i64::from(element_size));
        let destination = builder.ins().iadd(data, offset);
        store_scalar(builder, destination, value);
        let next = builder.ins().iadd_imm(len, 1);
        builder
            .ins()
            .store(MemFlags::trusted(), next, len_field.address, 0);
        Ok(())
    }

    fn lower_block(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node_index: usize,
    ) -> Result<bool, Box<dyn Error>> {
        let node = &self.program.nodes[node_index];
        if node.kind != "Block" {
            return Err(invalid(
                "full-program block lowering received a non-Block node",
            ));
        }
        self.scopes.push(HashMap::new());
        self.defers.push(Vec::new());
        let mut terminated = false;
        let mut scope_cleanup = None;
        for (child_index, child) in node.children.clone().into_iter().enumerate() {
            if self.program.nodes[child].kind == "ScopeCleanup" {
                if child_index + 1 != node.children.len() || scope_cleanup.is_some() {
                    return Err(invalid(
                        "full-program scope cleanup must be the final unique block operation",
                    ));
                }
                scope_cleanup = Some(child);
                continue;
            }
            if terminated {
                return Err(invalid(
                    "full-program canonical block contains execution after termination",
                ));
            }
            terminated = self.lower_statement(builder, child)?;
        }
        if !terminated {
            self.emit_scope_defers(builder, self.defers.len() - 1)?;
            if let Some(cleanup) = scope_cleanup {
                self.lower_scope_cleanup(builder, cleanup)?;
            }
        }
        self.defers.pop();
        self.scopes.pop();
        Ok(terminated)
    }

    fn lower_statement(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node_index: usize,
    ) -> Result<bool, Box<dyn Error>> {
        let node = self.program.nodes[node_index].clone();
        match node.kind.as_str() {
            "LocalDeclare" => {
                let place = self.place_for_type(builder, &node.ty)?;
                if let Some(value_index) = node.children.first() {
                    let value = self.lower_expression(builder, *value_index, Some(&node.ty))?;
                    self.store_evaluated(builder, place, value, &node.ty)?;
                }
                self.scopes
                    .last_mut()
                    .unwrap()
                    .insert(node.text, Local { place });
                Ok(false)
            }
            "Assign" => {
                let destination_type = self.program.nodes[node.children[0]].ty.clone();
                let destination = self.lower_place(builder, node.children[0])?;
                let value =
                    self.lower_expression(builder, node.children[1], Some(&destination_type))?;
                self.store_evaluated(builder, destination, value, &destination_type)?;
                Ok(false)
            }
            "Evaluate" => {
                let expression = &self.program.nodes[node.children[0]];
                if expression.kind == "LocalRead"
                    && expression.ty == "Void"
                    && matches!(expression.text.as_str(), "continue" | "break")
                {
                    let (head, done, scope_depth) = *self
                        .loops
                        .last()
                        .ok_or_else(|| invalid("loop control appears outside a loop"))?;
                    for scope in (scope_depth..self.defers.len()).rev() {
                        self.emit_scope_defers(builder, scope)?;
                    }
                    builder.ins().jump(
                        if expression.text == "continue" {
                            head
                        } else {
                            done
                        },
                        &[],
                    );
                    return Ok(true);
                }
                self.lower_expression(builder, node.children[0], None)?;
                Ok(false)
            }
            "UnsafeScope" => self.lower_block(builder, node.children[0]),
            "ScheduleDefer" => {
                self.defers.last_mut().unwrap().push(node.children[0]);
                Ok(false)
            }
            "Return" => {
                self.lower_return(builder, &node)?;
                Ok(true)
            }
            "Branch" => self.lower_branch(builder, &node),
            "Loop" => self.lower_loop(builder, &node),
            "GuardUnwrap" => self.lower_guard(builder, &node),
            "EnumMatch" => self.lower_enum_match(builder, &node),
            other => Err(invalid(format!(
                "unsupported full-program statement {other}"
            ))),
        }
    }

    fn emit_scope_defers(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        scope: usize,
    ) -> Result<(), Box<dyn Error>> {
        for deferred in self.defers[scope].clone().into_iter().rev() {
            self.lower_expression(builder, deferred, None)?;
        }
        Ok(())
    }

    fn lower_scope_cleanup(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node_index: usize,
    ) -> Result<(), Box<dyn Error>> {
        let node = self.program.nodes[node_index].clone();
        if node.kind != "ScopeCleanup" || node.children.is_empty() {
            return Err(invalid("full-program scope cleanup is malformed"));
        }
        for cleanup in node.children {
            self.lower_expression(builder, cleanup, None)?;
        }
        Ok(())
    }

    fn emit_all_defers(&mut self, builder: &mut FunctionBuilder<'_>) -> Result<(), Box<dyn Error>> {
        for scope in (0..self.defers.len()).rev() {
            self.emit_scope_defers(builder, scope)?;
        }
        Ok(())
    }

    fn lower_return(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
    ) -> Result<(), Box<dyn Error>> {
        if !matches!(node.integer, 0 | 1) || node.integer as usize > node.children.len() {
            return Err(invalid(
                "full-program return value marker disagrees with its children",
            ));
        }
        // Canonical v1 rows produced before resource-cleanup transport have a
        // zero marker and use their sole child as the scalar return value.
        // Keep accepting that representation while new rows use the marker to
        // separate an optional value from following cleanup expressions.
        let value_count = if node.integer == 1
            || node.integer == 0
                && self.function.result_type != "Void"
                && node.children.len() == 1
        {
            1
        } else {
            0
        };
        let result = if value_count == 1 {
            let value = node.children[0];
            Some(self.lower_expression(builder, value, Some(&self.function.result_type.clone()))?)
        } else {
            None
        };
        let aggregate_result = if let Some(value) = result {
            if is_scalar_type(&self.function.result_type) {
                None
            } else {
                Some(self.evaluated_place(builder, value, &self.function.result_type.clone())?)
            }
        } else {
            None
        };
        let scalar_result = if let Some(value) = result {
            if is_scalar_type(&self.function.result_type) {
                Some(self.scalar(builder, value, &self.function.result_type.clone())?)
            } else {
                None
            }
        } else {
            None
        };
        self.emit_all_defers(builder)?;
        for cleanup in node.children.iter().skip(value_count) {
            self.lower_expression(builder, *cleanup, None)?;
        }
        match self.abi.result {
            AbiShape::Void => builder.ins().return_(&[]),
            AbiShape::Scalar(result_type) => {
                let value = scalar_result.ok_or_else(|| invalid("scalar return lacks value"))?;
                let value = self.coerce_scalar(builder, value, result_type);
                builder.ins().return_(&[value])
            }
            AbiShape::AggregateOne => {
                let place =
                    aggregate_result.ok_or_else(|| invalid("aggregate return lacks value"))?;
                let first = builder
                    .ins()
                    .load(types::I64, MemFlags::trusted(), place.address, 0);
                builder.ins().return_(&[first])
            }
            AbiShape::AggregateTwo => {
                let place =
                    aggregate_result.ok_or_else(|| invalid("aggregate return lacks value"))?;
                let first = builder
                    .ins()
                    .load(types::I64, MemFlags::trusted(), place.address, 0);
                let second = builder
                    .ins()
                    .load(types::I64, MemFlags::trusted(), place.address, 8);
                builder.ins().return_(&[first, second])
            }
            AbiShape::AggregateMemory(_) => {
                let place = aggregate_result.ok_or_else(|| invalid("sret return lacks value"))?;
                let layout = self.layouts.layout(&self.function.result_type)?;
                self.copy_place(
                    builder,
                    Place {
                        address: self.sret.unwrap(),
                    },
                    place,
                    layout.size,
                )?;
                builder.ins().return_(&[])
            }
            AbiShape::ArenaParameter => unreachable!(),
        };
        Ok(())
    }

    fn lower_branch(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
    ) -> Result<bool, Box<dyn Error>> {
        let condition_node = &self.program.nodes[node.children[0]];
        let condition_eval = self.lower_expression(builder, node.children[0], None)?;
        let condition = self.scalar(builder, condition_eval, &condition_node.ty)?;
        let consequence = builder.create_block();
        let alternative = builder.create_block();
        let join = builder.create_block();
        let condition = as_condition(builder, condition);
        builder
            .ins()
            .brif(condition, consequence, &[], alternative, &[]);
        builder.switch_to_block(consequence);
        let consequence_terminated = self.lower_block(builder, node.children[1])?;
        if !consequence_terminated {
            builder.ins().jump(join, &[]);
        }
        builder.switch_to_block(alternative);
        let alternative_terminated = if node.children.len() == 3 {
            self.lower_block(builder, node.children[2])?
        } else {
            false
        };
        if !alternative_terminated {
            builder.ins().jump(join, &[]);
        }
        let all_terminated = consequence_terminated && alternative_terminated;
        if !all_terminated {
            builder.switch_to_block(join);
        }
        Ok(all_terminated)
    }

    fn lower_loop(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
    ) -> Result<bool, Box<dyn Error>> {
        let head = builder.create_block();
        let body = builder.create_block();
        let done = builder.create_block();
        builder.ins().jump(head, &[]);
        builder.switch_to_block(head);
        let condition_node = &self.program.nodes[node.children[0]];
        let condition_eval = self.lower_expression(builder, node.children[0], None)?;
        let condition = self.scalar(builder, condition_eval, &condition_node.ty)?;
        let condition = as_condition(builder, condition);
        builder.ins().brif(condition, body, &[], done, &[]);
        builder.switch_to_block(body);
        self.loops.push((head, done, self.defers.len()));
        let body_terminated = self.lower_block(builder, node.children[1])?;
        self.loops.pop();
        if !body_terminated {
            builder.ins().jump(head, &[]);
        }
        builder.switch_to_block(done);
        Ok(false)
    }

    fn lower_guard(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
    ) -> Result<bool, Box<dyn Error>> {
        let value_node = &self.program.nodes[node.children[0]];
        let value_eval = self.lower_expression(builder, node.children[0], None)?;
        let wrapper = self.evaluated_place(builder, value_eval, &value_node.ty)?;
        let (ok_place, _) = self.field_place(builder, wrapper, &value_node.ty, "Ok")?;
        let ok = builder
            .ins()
            .load(types::I8, MemFlags::trusted(), ok_place.address, 0);
        let success = builder.create_block();
        let failure = builder.create_block();
        let join = builder.create_block();
        let ok = as_condition(builder, ok);
        builder.ins().brif(ok, success, &[], failure, &[]);
        builder.switch_to_block(failure);
        let failure_terminated = self.lower_block(builder, node.children[1])?;
        if !failure_terminated {
            builder.ins().jump(join, &[]);
        }
        builder.switch_to_block(success);
        let (source, value_type) = self.field_place(builder, wrapper, &value_node.ty, "Val")?;
        let destination = self.place_for_type(builder, &value_type)?;
        let size = self.layouts.layout(&value_type)?.size;
        self.copy_place(builder, destination, source, size)?;
        self.scopes
            .last_mut()
            .unwrap()
            .insert(node.text.clone(), Local { place: destination });
        builder.ins().jump(join, &[]);
        builder.switch_to_block(join);
        Ok(false)
    }

    fn lower_enum_match(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
        node: &Node,
    ) -> Result<bool, Box<dyn Error>> {
        let subject_node = &self.program.nodes[node.children[0]];
        let subject_eval = self.lower_expression(builder, node.children[0], None)?;
        let subject = self.evaluated_place(builder, subject_eval, &subject_node.ty)?;
        let (tag_place, _) = self.field_place(builder, subject, &subject_node.ty, "tag")?;
        let tag = builder
            .ins()
            .load(types::I32, MemFlags::trusted(), tag_place.address, 0);
        let done = builder.create_block();
        let mut arm_termination = Vec::new();
        for (arm_position, arm_index) in node.children[1..].iter().enumerate() {
            let arm = self.program.nodes[*arm_index].clone();
            let arm_block = builder.create_block();
            let is_last = arm_position + 1 == node.children.len() - 1;
            let next = (!is_last).then(|| builder.create_block());
            if let Some(next) = next {
                let variant = self.enum_variant_index(&subject_node.ty, &arm.text)?;
                let matches = builder.ins().icmp_imm(IntCC::Equal, tag, variant as i64);
                builder.ins().brif(matches, arm_block, &[], next, &[]);
            } else {
                builder.ins().jump(arm_block, &[]);
            }
            builder.switch_to_block(arm_block);
            self.scopes.push(HashMap::new());
            let (payload, payload_type) =
                self.field_place(builder, subject, &subject_node.ty, &arm.text)?;
            let binding_count = arm.children.len() - 1;
            if binding_count > 1 {
                return Err(invalid(
                    "compiler enum cohort exceeds its observed single payload binding",
                ));
            }
            if binding_count == 1 {
                let binding = &self.program.nodes[arm.children[0]];
                let payload_layout = self.layouts.layout(&payload_type)?;
                let first = payload_layout
                    .fields
                    .values()
                    .min_by_key(|field| field.offset)
                    .ok_or_else(|| invalid("enum binding lacks payload field"))?
                    .clone();
                let source = Place {
                    address: add_offset(builder, payload.address, first.offset),
                };
                // Gust match bindings borrow the selected payload. The canonical
                // binding node carries its name and ordinal; the enum layout is
                // the authority for the addressed payload type.
                let pointer_layout = self.layouts.layout("RawPointer(Void)")?;
                let destination = make_stack_place(builder, &pointer_layout, self.pointer_type())?;
                builder
                    .ins()
                    .store(MemFlags::trusted(), source.address, destination.address, 0);
                self.scopes
                    .last_mut()
                    .unwrap()
                    .insert(binding.text.clone(), Local { place: destination });
            }
            let terminated = self.lower_block(builder, *arm.children.last().unwrap())?;
            self.scopes.pop();
            if !terminated {
                builder.ins().jump(done, &[]);
            }
            arm_termination.push(terminated);
            if let Some(next) = next {
                builder.switch_to_block(next);
            }
        }
        let all_terminated = arm_termination.iter().all(|value| *value);
        if !all_terminated {
            builder.switch_to_block(done);
        }
        Ok(all_terminated)
    }

    fn emit_implicit_return(
        &mut self,
        builder: &mut FunctionBuilder<'_>,
    ) -> Result<(), Box<dyn Error>> {
        if self.function.result_type != "Void" {
            return Err(invalid(format!(
                "function {} can fall through with non-void result",
                self.function.qualified_name
            )));
        }
        builder.ins().return_(&[]);
        Ok(())
    }
}

pub fn lower_path(canonical_path: &Path, object_path: &Path) -> Result<String, Box<dyn Error>> {
    let contents = fs::read_to_string(canonical_path)?;
    lower_contents(&contents, object_path)
}

pub fn lower_contents(contents: &str, object_path: &Path) -> Result<String, Box<dyn Error>> {
    let program = parse(contents)?;
    FullProgramCompiler::new(&program)?.finish(object_path)
}

pub fn validate_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let contents = fs::read_to_string(path)?;
    validate_contents(&contents)
}

pub fn validate_contents(contents: &str) -> Result<String, Box<dyn Error>> {
    let program = parse(contents)?;
    let mut layout_engine = LayoutEngine::new(&program, 8);
    for layout in &program.layouts {
        layout_engine.layout(&format!("Struct(\"{}\", None)", layout.erased_name))?;
    }
    for function in &program.functions {
        layout_engine.layout(&function.result_type)?;
        for (_, parameter_type) in &function.parameters {
            layout_engine.layout(parameter_type)?;
        }
    }
    for node in &program.nodes {
        if !node.ty.is_empty() {
            layout_engine.layout(&node.ty)?;
        }
    }
    Ok(format!(
        "format={} modules={} layouts={} enums={} functions={} nodes={} entry={}\n",
        FORMAT,
        program.modules.len(),
        program.layouts.len(),
        program.enumerations.len(),
        program.functions.len(),
        program.nodes.len(),
        program.functions[program.entry_function].qualified_name,
    ))
}
