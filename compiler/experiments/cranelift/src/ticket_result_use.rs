//! Read-only use of a proved post-cleanup ticket in a closed caller. The
//! originating Arena must remain live until each scalar result is evaluated.
use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::io::{Error as IoError, ErrorKind};
use crate::full_program::{resolve_collection_intrinsic, Node, Program};
use crate::ticket_result::TicketResult;

fn invalid(message: &str) -> Box<dyn Error> {
    Box::new(IoError::new(ErrorKind::InvalidData, message.to_owned()))
}
fn node<'a>(program: &'a Program, index: usize, kind: &str) -> Result<&'a Node, Box<dyn Error>> {
    let value = program.nodes.get(index).ok_or_else(|| invalid("ticket use node is absent"))?;
    if value.kind != kind { return Err(invalid("ticket use node kind disagrees")); }
    Ok(value)
}
fn local(program: &Program, index: usize, name: &str, ty: &str) -> bool {
    program.nodes.get(index).is_some_and(|value| value.kind == "LocalRead" &&
        value.children.is_empty() && value.text == name && value.ty == ty)
}

struct ReadProof<'a> {
    program: &'a Program,
    published_brand: &'a str,
    immutable: &'a HashMap<String, String>,
    allowed: &'a mut HashSet<usize>,
    seen: HashSet<usize>,
}

impl ReadProof<'_> {
    fn scalar(&mut self, root: usize, error: Option<&str>, bytes: Option<(&str, &str)>)
        -> Result<(), Box<dyn Error>> {
        let mut stack = vec![root];
        while let Some(index) = stack.pop() {
            if !self.seen.insert(index) || self.seen.len() > 65_536 {
                return Err(invalid("ticket scalar use is shared, cyclic or over budget"));
            }
            let value = &self.program.nodes[index];
            if !matches!(value.ty.as_str(), "Int" | "Byte" | "Bool") {
                return Err(invalid("ticket use escapes a scalar result"));
            }
            match value.kind.as_str() {
                "IntegerLiteral" | "BooleanLiteral" if value.children.is_empty() => {}
                "LocalRead" if value.children.is_empty() &&
                    self.immutable.get(&value.text) == Some(&value.ty) => {}
                "BinaryOperation" if value.children.len() == 2 &&
                    matches!(value.text.as_str(), "+" | "-" | "*" | "==" | "!=" | "<" | ">" | "<=" | ">=" | "&&" | "||") => {
                    stack.extend(value.children.iter().copied());
                }
                "ExplicitCast" if value.children.len() == 1 => stack.push(value.children[0]),
                "Dereference" if value.ty == "Int" && value.children.len() == 1 &&
                    error.is_some_and(|name| local(self.program, value.children[0], name, "Reference(Int, None)")) => {}
                "Call" if value.text == "len" && value.second_text == "len" &&
                    value.second_integer == 0 && value.ty == "Int" && value.children.len() == 2 &&
                    local(self.program, value.children[0], "len", "Void") &&
                    bytes.is_some_and(|(name, ty)| local(self.program, value.children[1], name, ty)) => {}
                "CollectionIntrinsic" if value.children.len() == 2 && bytes.is_some() => {
                    let (name, ty) = bytes.unwrap();
                    resolve_collection_intrinsic(self.program, index)?;
                    let plan = value.collection_intrinsic.as_ref()
                        .ok_or_else(|| invalid("ticket byte read has no executable plan"))?;
                    // The returned generic value retains its formal layout
                    // brand. The caller's actual Arena was independently
                    // substituted and checked at the originating scoped call;
                    // get_ref below must use that same actual Arena.
                    if plan.opcode != "Read" || plan.brand != self.published_brand ||
                        plan.receiver_type != ty || value.ty != "Byte" ||
                        self.program.nodes[value.children[1]].ty != "Int" ||
                        !local(self.program, value.children[0], name, ty) || !self.allowed.insert(index) {
                        return Err(invalid("ticket byte read changes its published origin"));
                    }
                    stack.push(value.children[1]);
                }
                _ => return Err(invalid("ticket scalar use has an effect or unproved read")),
            }
        }
        Ok(())
    }
}

pub(crate) struct PublishedUse<'a> {
    pub(crate) binding: &'a str,
    pub(crate) copied: &'a str,
    pub(crate) bytes: &'a str,
    pub(crate) reference_type: String,
    pub(crate) tail: &'a [usize],
}

pub(crate) fn validate(program: &Program, index: usize, contract: &TicketResult,
    result: &str, arena: &str, immutable: &HashMap<String, String>,
    allowed: &mut HashSet<usize>,
    continuation: &mut dyn FnMut(PublishedUse<'_>, &mut HashSet<usize>) -> Result<usize, Box<dyn Error>>,
) -> Result<usize, Box<dyn Error>> {
    let selection = node(program, index, "EnumMatch")?;
    if selection.children.len() != 3 || !local(program, selection.children[0], result, &contract.result_type) {
        return Err(invalid("ticket match does not use its proved result"));
    }
    let mut total = 0;
    let mut observed = HashSet::new();
    for arm_index in &selection.children[1..] {
        let arm = node(program, *arm_index, "EnumMatchArm")?;
        let success = arm.text == contract.variant(true).0;
        let (name, ordinal) = contract.variant(success);
        if arm.text != name || arm.integer != ordinal || !observed.insert(ordinal) || arm.children.len() != 2 {
            return Err(invalid("ticket match is not exact and exhaustive"));
        }
        let binding = node(program, arm.children[0], "EnumPayloadBinding")?;
        if binding.text.is_empty() || binding.text == arena ||
            binding.second_text != name || binding.integer != 0 ||
            !binding.children.is_empty() {
            return Err(invalid("ticket match payload binding disagrees"));
        }
        let body = node(program, arm.children[1], "Block")?;
        // Match arms have their own lexical bindings. Mask parent scalar names
        // before checking reads; a parent binding is never authority for a
        // shadowing payload, ticket or published reference.
        let mut scalars = immutable.clone();
        scalars.remove(&binding.text);
        let value = if success {
            if body.children.len() < 3 { return Err(invalid("ticket success use has extra effects")); }
            let copied = node(program, body.children[0], "LocalDeclare")?;
            if copied.text.is_empty() || copied.text == binding.text || copied.text == arena ||
                copied.ty != contract.ticket_type || copied.children.len() != 1 {
                return Err(invalid("ticket match copy is not fresh"));
            }
            let read = node(program, copied.children[0], "Dereference")?;
            if read.ty != contract.ticket_type || read.children.len() != 1 ||
                !local(program, read.children[0], &binding.text, &format!("Reference({}, None)", contract.ticket_type)) {
                return Err(invalid("ticket match does not copy its exact bound Index"));
            }
            let bytes = node(program, body.children[1], "LocalDeclare")?;
            let reference_type = format!("Reference({}, None)", contract.output_type);
            if bytes.text.is_empty() || bytes.text == copied.text || bytes.text == binding.text ||
                bytes.text == arena || bytes.ty != reference_type || bytes.children.len() != 1 {
                return Err(invalid("ticket output reference is not fresh"));
            }
            let get = node(program, bytes.children[0], "Call")?;
            if get.text != format!("{arena}.get_ref") || get.second_text != get.text ||
                get.second_integer != 0 || get.ty != reference_type || get.children.len() != 2 ||
                !local(program, get.children[1], &copied.text, &contract.ticket_type) {
                return Err(invalid("ticket output access changes its Index"));
            }
            let receiver = node(program, get.children[0], "FieldOrMethodSelect")?;
            if receiver.text != "get_ref" || receiver.ty != "Void" || receiver.children.len() != 1 ||
                !local(program, receiver.children[0], arena, "Arena") {
                return Err(invalid("ticket output access changes its live Arena"));
            }
            scalars.remove(&copied.text);
            scalars.remove(&bytes.text);
            if body.children.len() != 3 || program.nodes[body.children[2]].kind != "Return" {
                total += continuation(PublishedUse { binding: &binding.text,
                    copied: &copied.text, bytes: &bytes.text,
                    reference_type, tail: &body.children[2..] }, allowed)?;
                continue;
            }
            let exit = node(program, body.children[2], "Return")?;
            if exit.integer != 1 || exit.children.len() != 1 {
                return Err(invalid("ticket success does not evaluate before caller cleanup"));
            }
            let mut proof = ReadProof { program, published_brand: &contract.output_brand,
                immutable: &scalars, allowed, seen: HashSet::new() };
            proof.scalar(exit.children[0], None, Some((&bytes.text, &reference_type)))?;
            total += proof.seen.len();
            exit.children[0]
        } else {
            if body.children.len() != 1 { return Err(invalid("ticket error use has extra effects")); }
            let exit = node(program, body.children[0], "Return")?;
            if exit.integer != 1 || exit.children.len() != 1 {
                return Err(invalid("ticket failure does not evaluate before caller cleanup"));
            }
            let mut proof = ReadProof { program, published_brand: &contract.output_brand,
                immutable: &scalars, allowed, seen: HashSet::new() };
            proof.scalar(exit.children[0], Some(&binding.text), None)?;
            total += proof.seen.len();
            exit.children[0]
        };
        if program.nodes[value].ty != "Int" { return Err(invalid("ticket caller result is not Int")); }
    }
    Ok(total)
}
