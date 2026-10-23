//! Closed proof for local tagged Index/Int constructors. These helpers only
//! initialize a fresh enum; passing an Arena does not grant them any effects.
use std::error::Error;
use std::io::{Error as IoError, ErrorKind};

use crate::full_program::{is_inline_call, struct_type_name, Layout, Node, Program};

fn invalid(message: &str) -> Box<dyn Error> {
    Box::new(IoError::new(ErrorKind::InvalidData, message.to_owned()))
}

fn node<'a>(program: &'a Program, index: usize, kind: &str) -> Result<&'a Node, Box<dyn Error>> {
    let value = program.nodes.get(index).ok_or_else(|| invalid("ticket result node is absent"))?;
    if value.kind != kind { return Err(invalid("ticket result node kind disagrees")); }
    Ok(value)
}

fn local(program: &Program, index: usize, name: &str, ty: &str) -> bool {
    program.nodes.get(index).is_some_and(|value| value.kind == "LocalRead" &&
        value.children.is_empty() && value.text == name && value.ty == ty)
}

fn layout<'a>(program: &'a Program, ty: &str, brand: &str) -> Result<&'a Layout, Box<dyn Error>> {
    let name = struct_type_name(ty).ok_or_else(|| invalid("ticket payload is not a struct"))?;
    let mut matches = program.layouts.iter().filter(|value|
        value.erased_name == name && value.brand == brand);
    let value = matches.next().ok_or_else(|| invalid("ticket payload brand/layout is absent"))?;
    if matches.next().is_some() || value.repr_c || value.packed || !value.abi.is_empty() {
        return Err(invalid("ticket payload layout is ambiguous or foreign"));
    }
    Ok(value)
}

#[derive(Clone, Debug)]
struct Variant {
    ordinal: i32,
    name: String,
    payload_type: String,
    field: String,
    field_type: String,
}

#[derive(Debug)]
pub(crate) struct TicketResult {
    pub(crate) result_type: String,
    pub(crate) ticket_type: String,
    pub(crate) output_type: String,
    pub(crate) output_brand: String,
    success: Variant,
    failure: Variant,
}

impl TicketResult {
    pub(crate) fn resolve(program: &Program, result_type: &str,
        output_type: &str, output_brand: &str) -> Result<Self, Box<dyn Error>> {
        let name = struct_type_name(result_type).ok_or_else(|| invalid("ticket result lacks enum type"))?;
        let outer = layout(program, result_type, output_brand)?;
        let mut matches = program.enumerations.iter().filter(|value|
            value.erased_name == name && value.name == outer.name);
        let enumeration = matches.next().ok_or_else(|| invalid("ticket result lacks enum authority"))?;
        if matches.next().is_some() || enumeration.repr_int || enumeration.variants.len() != 2 {
            return Err(invalid("ticket result is not one success/error pair"));
        }
        if outer.name != enumeration.name || output_brand.is_empty() || outer.fields.len() != 3 ||
            !outer.fields.iter().any(|field| field.name == "tag" && field.ty == "Int") {
            return Err(invalid("ticket result tag/layout/brand disagrees"));
        }
        let output_name = struct_type_name(output_type).ok_or_else(|| invalid("ticket output type is absent"))?;
        let ticket_type = format!("Index(\"{output_name}\", None)");
        let mut success = None;
        let mut failure = None;
        for (ordinal, name) in enumeration.variants.iter().enumerate() {
            let field = outer.fields.iter().find(|field| field.name == *name)
                .ok_or_else(|| invalid("ticket result variant layout is absent"))?;
            let payload = layout(program, &field.ty, output_brand)?;
            if payload.fields.len() != 1 { return Err(invalid("ticket variant has extra fields")); }
            let member = &payload.fields[0];
            let variant = Variant { ordinal: ordinal as i32, name: name.clone(),
                payload_type: field.ty.clone(), field: member.name.clone(), field_type: member.ty.clone() };
            if member.ty == ticket_type && success.is_none() { success = Some(variant); }
            else if member.ty == "Int" && failure.is_none() { failure = Some(variant); }
            else { return Err(invalid("ticket result payload is not the output Index or Int")); }
        }
        Ok(Self { result_type: result_type.to_owned(), ticket_type,
            output_type: output_type.to_owned(),
            output_brand: output_brand.to_owned(),
            success: success.ok_or_else(|| invalid("ticket success is absent"))?,
            failure: failure.ok_or_else(|| invalid("ticket failure is absent"))? })
    }

    pub(crate) fn variant(&self, success: bool) -> (&str, i32) {
        let variant = if success { &self.success } else { &self.failure };
        (&variant.name, variant.ordinal)
    }

    // A constructor has exactly three body statements and two writes. Checking
    // every edge directly leaves no place for allocation, calls, aliases,
    // callbacks, Arena mutation, nested control or recursive helper effects.
    fn constructor<'a>(&self, program: &'a Program, index: usize,
        arena: &str, success: bool) -> Result<&'a Node, Box<dyn Error>> {
        let call = node(program, index, "Call")?;
        if call.ty != self.result_type || call.second_integer != 0 ||
            call.children.len() != 3 || is_inline_call(program, call) ||
            !local(program, call.children[1], arena, "Reference(Arena, None)") {
            return Err(invalid("ticket constructor actuals or dispatch disagree"));
        }
        let callee = node(program, call.children[0], "LocalRead")?;
        if callee.ty != "Void" || !callee.children.is_empty() || callee.text != call.text {
            return Err(invalid("ticket constructor has an effectful callee"));
        }
        let mut matches = program.functions.iter().filter(|function|
            function.qualified_name == call.second_text);
        let function = matches.next().ok_or_else(|| invalid("ticket constructor body is absent"))?;
        let variant = if success { &self.success } else { &self.failure };
        if program.nodes[call.children[2]].ty != variant.field_type {
            return Err(invalid("ticket constructor argument type disagrees"));
        }
        if matches.next().is_some() || function.is_extern || function.ffi_contract.is_some() ||
            function.scoped_byte_copy.is_some() || function.result_type != self.result_type ||
            function.parameters.len() != 2 || function.parameters[0].1 != "Reference(Arena, None)" ||
            function.parameters[1].1 != variant.field_type ||
            function.parameters.iter().any(|(name, _)| name.is_empty()) ||
            function.parameters[0].0 == function.parameters[1].0 {
            return Err(invalid("ticket constructor signature is not pure local construction"));
        }
        let body = node(program, function.body_node.ok_or_else(|| invalid("ticket constructor has no body"))?, "Block")?;
        if body.children.len() != 3 { return Err(invalid("ticket constructor has extra statements")); }
        let declaration = node(program, body.children[0], "LocalDeclare")?;
        if declaration.ty != self.result_type || !declaration.children.is_empty() ||
            declaration.text.is_empty() || function.parameters.iter().any(|(name, _)| *name == declaration.text) {
            return Err(invalid("ticket constructor result is not fresh"));
        }
        let scope = node(program, body.children[1], "UnsafeScope")?;
        if scope.children.len() != 1 { return Err(invalid("ticket constructor scope disagrees")); }
        let writes = node(program, scope.children[0], "Block")?;
        if writes.children.len() != 2 { return Err(invalid("ticket constructor has extra effects")); }
        let tag_write = node(program, writes.children[0], "Assign")?;
        let payload_write = node(program, writes.children[1], "Assign")?;
        if tag_write.children.len() != 2 || payload_write.children.len() != 2 {
            return Err(invalid("ticket constructor write edges disagree"));
        }
        let tag = node(program, tag_write.children[0], "FieldOrMethodSelect")?;
        let ordinal = node(program, tag_write.children[1], "IntegerLiteral")?;
        if tag.text != "tag" || tag.ty != "Int" || tag.children.len() != 1 ||
            !local(program, tag.children[0], &declaration.text, &self.result_type) ||
            ordinal.ty != "Int" || !ordinal.children.is_empty() || ordinal.integer != variant.ordinal {
            return Err(invalid("ticket constructor tag disagrees with payload"));
        }
        let field = node(program, payload_write.children[0], "FieldOrMethodSelect")?;
        if field.text != variant.field || field.ty != variant.field_type || field.children.len() != 1 {
            return Err(invalid("ticket constructor payload field disagrees"));
        }
        let selection = node(program, field.children[0], "FieldOrMethodSelect")?;
        if selection.text != variant.name || selection.ty != variant.payload_type ||
            selection.children.len() != 1 ||
            !local(program, selection.children[0], &declaration.text, &self.result_type) ||
            !local(program, payload_write.children[1], &function.parameters[1].0, &variant.field_type) {
            return Err(invalid("ticket constructor publishes another value or variant"));
        }
        let exit = node(program, body.children[2], "Return")?;
        if exit.integer != 1 || exit.children.len() != 1 ||
            !local(program, exit.children[0], &declaration.text, &self.result_type) {
            return Err(invalid("ticket constructor does not return its exact local"));
        }
        Ok(call)
    }

    pub(crate) fn error_argument(&self, program: &Program, index: usize,
        arena: &str) -> Result<usize, Box<dyn Error>> {
        Ok(self.constructor(program, index, arena, false)?.children[2])
    }

    pub(crate) fn success(&self, program: &Program, index: usize,
        arena: &str, ticket: &str) -> Result<(), Box<dyn Error>> {
        let call = self.constructor(program, index, arena, true)?;
        if !local(program, call.children[2], ticket, &self.ticket_type) {
            return Err(invalid("ticket success does not use the completed published ticket"));
        }
        Ok(())
    }

    pub(crate) fn publication(&self, program: &Program, tail: &[usize],
        arena: &str, output: &str, output_type: &str) -> Result<(), Box<dyn Error>> {
        if tail.len() != 3 { return Err(invalid("ticket publication has extra steps")); }
        let declaration = node(program, tail[0], "LocalDeclare")?;
        if declaration.text.is_empty() || declaration.ty != self.ticket_type ||
            declaration.children.len() != 1 {
            return Err(invalid("ticket publication lacks one fresh Index local"));
        }
        let allocate = node(program, declaration.children[0], "Call")?;
        if allocate.text != "os.ArenaAlloc" || allocate.second_text != "os_ArenaAlloc" ||
            allocate.second_integer != 0 || allocate.ty != "Index(\"Any\", None)" ||
            allocate.children.len() != 2 ||
            !local(program, allocate.children[1], arena, "Reference(Arena, None)") {
            return Err(invalid("ticket allocation uses another Arena or operation"));
        }
        let selector = node(program, allocate.children[0], "FieldOrMethodSelect")?;
        if selector.text != "ArenaAlloc" || selector.ty != "Void" || selector.children.len() != 1 ||
            !local(program, selector.children[0], "os", "Void") {
            return Err(invalid("ticket allocation has an effectful intrinsic receiver"));
        }
        let statement = node(program, tail[1], "Evaluate")?;
        if statement.children.len() != 1 { return Err(invalid("ticket publication store is not unique")); }
        let store = node(program, statement.children[0], "Call")?;
        if store.text != format!("{arena}.Set") || store.second_text != store.text ||
            store.second_integer != 0 || store.ty != "Void" || store.children.len() != 3 ||
            !local(program, store.children[1], &declaration.text, &self.ticket_type) ||
            !local(program, store.children[2], output, output_type) {
            return Err(invalid("ticket store does not publish the exact completed output"));
        }
        let receiver = node(program, store.children[0], "FieldOrMethodSelect")?;
        if receiver.text != "Set" || receiver.ty != "Void" || receiver.children.len() != 1 ||
            !local(program, receiver.children[0], arena, "Reference(Arena, None)") {
            return Err(invalid("ticket publication uses another Arena receiver"));
        }
        let exit = node(program, tail[2], "Return")?;
        if exit.integer != 1 || exit.children.len() != 1 {
            return Err(invalid("ticket publication has cleanup or lacks one success return"));
        }
        self.success(program, exit.children[0], arena, &declaration.text)
    }
}
