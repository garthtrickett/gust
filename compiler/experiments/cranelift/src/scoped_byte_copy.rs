//! Closed structural proof for the separately versioned scoped byte-copy
//! cohort. Function-row fields are candidates emitted by the typed producer;
//! none is authority until every referenced canonical edge and value version
//! is independently checked here. Signed package admission remains a later
//! check on the same parsed Program.

use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::io::{Error as IoError, ErrorKind};

use crate::full_program::{byte_span_contract, inline_call_name, is_inline_call,
    resolve_native_vector_layout, resolve_collection_intrinsic,
    Function, Node, Program, ScopedAnchor,
    ScopedBinding, ScopedByteCopyCandidate};

fn invalid(message: &str) -> Box<dyn Error> {
    Box::new(IoError::new(ErrorKind::InvalidData, message.to_string()))
}

#[derive(Debug)]
pub(crate) struct ScopedProof {
    pub(crate) function_index: usize,
    constructor_call: usize,
    guard: usize,
    owner_name: String,
    owner_type: String,
    destructor: String,
    cleanups: HashSet<usize>,
    operations: HashSet<usize>,
    pub(crate) collection_operations: HashSet<usize>,
    pub(crate) input_collection_brand: String,
    pub(crate) output_collection_brand: String,
}

impl ScopedProof {
    pub(crate) fn authorizes_constructor(&self, constructor_call: usize,
        owner_type: &str, destructor: &str) -> bool {
        self.constructor_call == constructor_call && self.owner_type == owner_type &&
            self.destructor == destructor && !self.owner_name.is_empty() &&
            !self.cleanups.is_empty() && !self.operations.is_empty()
    }
}

struct BodyTree {
    reachable: HashSet<usize>,
    parent: HashMap<usize, usize>,
}

impl BodyTree {
    fn contains(&self, index: usize) -> bool { self.reachable.contains(&index) }

    fn below(&self, child: usize, ancestor: usize) -> bool {
        let mut cursor = child;
        while let Some(parent) = self.parent.get(&cursor).copied() {
            if parent == ancestor { return true; }
            cursor = parent;
        }
        false
    }
}

fn body_tree(program: &Program, root: usize) -> Result<BodyTree, Box<dyn Error>> {
    const MAX_NODES: usize = 65_536;
    const MAX_EDGES: usize = 262_144;
    const MAX_DEPTH: usize = 1_024;
    let mut reachable = HashSet::new();
    let mut parent = HashMap::new();
    let mut stack = vec![(root, 1usize)];
    let mut edges = 0usize;
    while let Some((index, depth)) = stack.pop() {
        if index >= program.nodes.len() || depth > MAX_DEPTH || !reachable.insert(index) {
            return Err(invalid("scoped byte-copy body is invalid, deep, or shared"));
        }
        if reachable.len() > MAX_NODES { return Err(invalid("scoped byte-copy node budget exceeded")); }
        let node = &program.nodes[index];
        edges = edges.checked_add(node.children.len())
            .ok_or_else(|| invalid("scoped byte-copy edge count overflows"))?;
        if edges > MAX_EDGES { return Err(invalid("scoped byte-copy edge budget exceeded")); }
        for child in node.children.iter().rev() {
            if parent.insert(*child, index).is_some() {
                return Err(invalid("scoped byte-copy body shares a child"));
            }
            stack.push((*child, depth + 1));
        }
    }
    Ok(BodyTree { reachable, parent })
}

fn selected<'a>(program: &'a Program, call: &Node) -> Result<&'a Function, Box<dyn Error>> {
    program.functions.iter().find(|function|
        function.qualified_name == call.second_text && function.is_extern)
        .ok_or_else(|| invalid("scoped byte-copy Call lost its checked extern declaration"))
}

fn node<'a>(program: &'a Program, index: usize, kind: &str) -> Result<&'a Node, Box<dyn Error>> {
    let node = program.nodes.get(index).ok_or_else(|| invalid(
        "scoped byte-copy candidate index is out of bounds"))?;
    if node.kind != kind { return Err(invalid("scoped byte-copy candidate kind disagrees")); }
    Ok(node)
}

fn collection_node<'a>(program: &'a Program, index: usize, opcode: &str,
    receiver_type: &str) -> Result<&'a Node, Box<dyn Error>> {
    let value = node(program, index, "CollectionIntrinsic")?;
    resolve_collection_intrinsic(program, index)?;
    if !value.collection_intrinsic.as_ref().is_some_and(|plan|
        plan.opcode == opcode && plan.receiver_type == receiver_type &&
        plan.element_type == "Byte") {
        return Err(invalid("scoped collection operation, backing, or element disagrees"));
    }
    Ok(value)
}

fn same_collection_identity(first: &Node, later: &Node) -> bool {
    match (&first.collection_intrinsic, &later.collection_intrinsic) {
        (Some(left), Some(right)) => left.receiver_type == right.receiver_type &&
            left.element_type == right.element_type &&
            left.layout_id == right.layout_id && left.brand == right.brand,
        _ => false,
    }
}

fn anchor<'a>(program: &'a Program, function: &'a Function, tree: &BodyTree,
    anchor: &ScopedAnchor) -> Result<&'a str, Box<dyn Error>> {
    match anchor.binding {
        ScopedBinding::Local(index) => {
            if !tree.contains(index) { return Err(invalid("scoped local binding is outside body")); }
            let declaration = node(program, index, "LocalDeclare")?;
            if declaration.text.is_empty() || declaration.ty != anchor.ty {
                return Err(invalid("scoped local binding type or name disagrees"));
            }
            let duplicates = tree.reachable.iter().filter(|other|
                **other != index && program.nodes[**other].kind == "LocalDeclare" &&
                program.nodes[**other].text == declaration.text).count();
            if duplicates != 0 || function.parameters.iter().any(|(name, _)|
                name == &declaration.text) {
                return Err(invalid("scoped local binding is shadowed"));
            }
            Ok(&declaration.text)
        }
        ScopedBinding::Parameter(index) => {
            let (name, ty) = function.parameters.get(index).ok_or_else(|| invalid(
                "scoped parameter binding is out of bounds"))?;
            if name.is_empty() || ty != &anchor.ty || tree.reachable.iter().any(|other|
                program.nodes[*other].kind == "LocalDeclare" &&
                program.nodes[*other].text == *name) {
                return Err(invalid("scoped parameter identity or type disagrees"));
            }
            Ok(name)
        }
    }
}

#[cfg(test)]
fn checked_byte_vector(program: &Program, ty: &str) -> Result<(), Box<dyn Error>> {
    let layout = resolve_native_vector_layout(program, ty)?
        .ok_or_else(|| invalid("scoped backing has no typed container layout"))?;
    // The ordinary dispatch/layout decision does not prove backing validity.
    // Keep the Byte requirement and the source schedule independent below.
    if layout.element_type != "Byte" || layout.field_count != 4 ||
        HashSet::from([layout.data_offset, layout.len_offset,
            layout.capacity_offset, layout.arena_offset]).len() != 4 {
        return Err(invalid("scoped byte backing lacks the actual native collection layout"));
    }
    if layout.packed || layout.repr_c { return Err(invalid(
        "scoped byte backing has unsupported packed or C layout")); }
    Ok(())
}

fn local(program: &Program, index: usize, name: &str, ty: &str) -> bool {
    program.nodes.get(index).is_some_and(|value|
        value.kind == "LocalRead" && value.children.is_empty() &&
        value.text == name && value.ty == ty)
}

fn zero(program: &Program, index: usize) -> bool {
    program.nodes.get(index).is_some_and(|value|
        value.kind == "IntegerLiteral" && value.ty == "Int" &&
        value.integer == 0 && value.children.is_empty())
}

fn one(program: &Program, index: usize) -> bool {
    program.nodes.get(index).is_some_and(|value|
        value.kind == "IntegerLiteral" && value.ty == "Int" &&
        value.integer == 1 && value.children.is_empty())
}

fn prefill_capacity_exit(program: &Program, index: usize, capacity: &str,
    relation: &str, threshold: i32) -> bool {
    let Some(branch) = program.nodes.get(index) else { return false; };
    if branch.kind != "Branch" || branch.children.len() != 2 { return false; }
    let Some(test) = program.nodes.get(branch.children[0]) else { return false; };
    if test.kind != "BinaryOperation" || test.ty != "Int" ||
        test.text != relation || test.children.len() != 2 ||
        !local(program, test.children[0], capacity, "Int") { return false; }
    let Some(limit) = program.nodes.get(test.children[1]) else { return false; };
    if limit.kind != "IntegerLiteral" || limit.ty != "Int" ||
        !limit.children.is_empty() || limit.integer != threshold { return false; }
    let Some(body) = program.nodes.get(branch.children[1]) else { return false; };
    if body.kind != "Block" || body.children.len() != 1 { return false; }
    let Some(exit) = program.nodes.get(body.children[0]) else { return false; };
    if exit.kind != "Return" || exit.children.len() != 1 { return false; }
    program.nodes.get(exit.children[0]).is_some_and(|error| {
        if error.kind == "IntegerLiteral" && error.ty == "Int" &&
            error.children.is_empty() && error.integer < 0 {
            return true;
        }
        // The current source parser expresses a negative Int as `0 - n`.
        // Admit only this closed, pure arithmetic shape before allocating
        // the destination; no general expression or helper call can stand in
        // for the range-error exit.
        error.kind == "BinaryOperation" && error.ty == "Int" &&
            error.text == "-" && error.children.len() == 2 &&
            program.nodes.get(error.children[0]).is_some_and(|zero|
                zero.kind == "IntegerLiteral" && zero.ty == "Int" &&
                zero.children.is_empty() && zero.integer == 0) &&
            program.nodes.get(error.children[1]).is_some_and(|positive|
                positive.kind == "IntegerLiteral" && positive.ty == "Int" &&
                positive.children.is_empty() && positive.integer > 0)
    })
}

fn position(block: &Node, index: usize) -> Result<usize, Box<dyn Error>> {
    let mut positions = block.children.iter().enumerate()
        .filter(|(_, child)| **child == index);
    let first = positions.next().map(|(position, _)| position)
        .ok_or_else(|| invalid("scoped byte-copy node is absent from its block"))?;
    if positions.next().is_some() {
        return Err(invalid("scoped byte-copy block repeats a statement"));
    }
    Ok(first)
}

fn monotone_loop<'a>(program: &'a Program, block: &'a Node, loop_index: usize,
    count: &str, count_ty: &str) -> Result<(&'a Node, String), Box<dyn Error>> {
    let loop_position = position(block, loop_index)?;
    let initial_index = *block.children.get(loop_position.wrapping_sub(1))
        .ok_or_else(|| invalid("scoped byte-copy loop lacks its zero initializer"))?;
    if loop_position == 0 { return Err(invalid("scoped loop starts before initializer")); }
    let initial = node(program, initial_index, "LocalDeclare")?;
    if initial.ty != "Int" || initial.text.is_empty() || initial.children.len() != 1 ||
        !zero(program, initial.children[0]) {
        return Err(invalid("scoped byte-copy loop index does not start at zero"));
    }
    let loop_node = node(program, loop_index, "Loop")?;
    if loop_node.children.len() != 2 {
        return Err(invalid("scoped byte-copy loop has unsupported control flow"));
    }
    let condition = node(program, loop_node.children[0], "BinaryOperation")?;
    if condition.ty != "Int" || condition.text != "<" ||
        condition.children.len() != 2 ||
        !local(program, condition.children[0], &initial.text, "Int") ||
        !local(program, condition.children[1], count, count_ty) {
        return Err(invalid("scoped byte-copy loop does not compare its exact count"));
    }
    let body = node(program, loop_node.children[1], "Block")?;
    let last = *body.children.last().ok_or_else(|| invalid(
        "scoped byte-copy loop has an empty body"))?;
    let increment = node(program, last, "Assign")?;
    if increment.children.len() != 2 ||
        !local(program, increment.children[0], &initial.text, "Int") {
        return Err(invalid("scoped byte-copy loop does not increment its index"));
    }
    let add = node(program, increment.children[1], "BinaryOperation")?;
    if add.text != "+" || add.ty != "Int" || add.children.len() != 2 ||
        !local(program, add.children[0], &initial.text, "Int") ||
        !one(program, add.children[1]) {
        return Err(invalid("scoped byte-copy loop index does not advance by one"));
    }
    Ok((body, initial.text.clone()))
}

fn exact_owner_raw(program: &Program, index: usize, owner: &str,
    owner_type: &str, raw_field: &str) -> bool {
    let Some(raw) = program.nodes.get(index) else { return false; };
    raw.kind == "FieldOrMethodSelect" && raw.text == raw_field &&
        raw.ty == "RawPointer(Byte)" && raw.children.len() == 1 &&
        local(program, raw.children[0], owner, owner_type)
}

fn operation<'a>(program: &'a Program, index: usize, role: &str,
    owner: &str, owner_type: &str, raw_field: &str)
    -> Result<&'a Node, Box<dyn Error>> {
    let call = node(program, index, "Call")?;
    let function = selected(program, call)?;
    if call.second_integer != 11 ||
        function.extern_symbol != format!("os_FfiCallRegion{role}") ||
        call.children.len() != function.parameters.len() + 1 ||
        !exact_owner_raw(program, call.children[1], owner, owner_type, raw_field) {
        return Err(invalid("scoped region operation has wrong role or owner"));
    }
    Ok(call)
}

fn exact_cleanup(program: &Program, index: usize, owner: &str,
    owner_type: &str, destructor: &str) -> bool {
    let Some(call) = program.nodes.get(index) else { return false; };
    if call.kind != "Call" || call.second_integer != 0 ||
        call.text != destructor || call.second_text != destructor ||
        is_inline_call(program, call) || call.children.len() != 2 ||
        !local(program, call.children[0], destructor, "Void") { return false; }
    let Some(storage) = program.nodes.get(call.children[1]) else { return false; };
    storage.kind == "ResourceStorage" && storage.text == owner &&
        storage.ty == owner_type && storage.second_text == owner_type &&
        storage.children.is_empty()
}

fn owner_return(program: &Program, index: usize, owner: &str,
    owner_type: &str, destructor: &str, cleanups: &mut HashSet<usize>,
    output: &str, error_return: bool) -> Result<(), Box<dyn Error>> {
    let result = node(program, index, "Return")?;
    if result.children.len() != 2 || !exact_cleanup(program, result.children[1],
        owner, owner_type, destructor) || !cleanups.insert(result.children[1]) {
        return Err(invalid("scoped ordinary exit lacks one exact owner cleanup"));
    }
    // The value is evaluated before cleanup. Error paths may not publish a
    // partially filled destination; a success value may own the fresh output.
    let mut stack = vec![result.children[0]];
    while let Some(index) = stack.pop() {
        let value = &program.nodes[index];
        let pure = match value.kind.as_str() {
            "IntegerLiteral" | "BooleanLiteral" => value.children.is_empty(),
            "LocalRead" => value.children.is_empty() && value.text != owner &&
                (!error_return || value.text != output),
            "BinaryOperation" => value.children.len() == 2 &&
                matches!(value.text.as_str(), "+" | "-" | "==" | "!=" | "<" | ">"),
            "ExplicitCast" => value.children.len() == 1,
            "Call" => !error_return && value.second_integer == 0 &&
                value.text == "len" &&
                value.second_text == "len" && value.ty == "Int" &&
                value.children.len() == 2 &&
                local(program, value.children[1], output,
                    &program.nodes[value.children[1]].ty),
            _ => false,
        };
        if !pure { return Err(invalid(
            "scoped Return value has an effect or publishes partial state")); }
        if value.kind == "Call" {
            // This is the existing pure inline length operation; its callee
            // leaf is not an independently executed function.
            if !local(program, value.children[0], "len", "Void") {
                return Err(invalid("scoped success length has a forged callee"));
            }
            stack.push(value.children[1]);
        } else {
            stack.extend(value.children.iter().copied());
        }
    }
    Ok(())
}

fn failure_branch(program: &Program, index: usize, status: &str, owner: &str,
    owner_type: &str, destructor: &str, cleanups: &mut HashSet<usize>,
    output: &str) -> Result<(), Box<dyn Error>> {
    let branch = node(program, index, "Branch")?;
    if branch.children.len() != 2 { return Err(invalid("scoped status branch has an else arm")); }
    let comparison = node(program, branch.children[0], "BinaryOperation")?;
    if comparison.text != "!=" || comparison.ty != "Int" ||
        comparison.children.len() != 2 ||
        !local(program, comparison.children[0], status, "Int") ||
        !zero(program, comparison.children[1]) {
        return Err(invalid("scoped status branch does not reject nonzero"));
    }
    let block = node(program, branch.children[1], "Block")?;
    if block.children.len() != 1 {
        return Err(invalid("scoped status branch does not terminate"));
    }
    owner_return(program, block.children[0], owner, owner_type, destructor,
        cleanups, output, true)
}

pub(crate) fn validate(program: &Program) -> Result<HashMap<usize, ScopedProof>, Box<dyn Error>> {
    let mut proofs = HashMap::new();
    let mut scoped_functions = HashSet::new();
    for (function_index, function) in program.functions.iter().enumerate() {
        let Some(candidate) = function.scoped_byte_copy.as_ref() else { continue; };
        if function.is_extern || !scoped_functions.insert(function_index) {
            return Err(invalid("scoped byte-copy plan has no unique defined function"));
        }
        let proof = validate_one(program, function_index, function, candidate)?;
        if proofs.insert(proof.constructor_call, proof).is_some() {
            return Err(invalid("scoped byte-copy constructor has multiple plans"));
        }
    }
    for (index, call) in program.nodes.iter().enumerate() {
        if call.kind == "Call" && call.second_integer == 11 &&
            !proofs.values().any(|proof| proof.operations.contains(&index)) {
            return Err(invalid("region operation lacks a scoped byte-copy activation"));
        }
    }
    Ok(proofs)
}

fn validate_one(program: &Program, function_index: usize, function: &Function,
    candidate: &ScopedByteCopyCandidate) -> Result<ScopedProof, Box<dyn Error>> {
    let body = function.body_node.ok_or_else(|| invalid(
        "scoped byte-copy function has no body"))?;
    node(program, body, "Block")?;
    let tree = body_tree(program, body)?;
    let has_intrinsic = tree.reachable.iter().any(|index|
        program.nodes[*index].kind == "CollectionIntrinsic");
    // A scoped candidate does not authorize the historical name-dispatched
    // collection operations. The new executable intrinsic cohort must be
    // present and independently proven before this function can be admitted.
    if !has_intrinsic {
        return Err(invalid("scoped byte-copy lacks executable collection operations"));
    }
    let mut declared = HashSet::new();
    for (name, _) in &function.parameters {
        if !declared.insert(name.as_str()) { return Err(invalid(
            "scoped byte-copy parameter identity repeats")); }
    }
    for index in &tree.reachable {
        let value = &program.nodes[*index];
        if matches!(value.kind.as_str(), "LocalDeclare" | "GuardUnwrap") &&
            (value.text.is_empty() || !declared.insert(value.text.as_str())) {
            return Err(invalid("scoped byte-copy local or Guard binding is shadowed"));
        }
    }
    let scope = node(program, candidate.scope, "UnsafeScope")?;
    if scope.children.len() != 1 || !tree.below(candidate.scope, body) ||
        program.nodes[scope.children[0]].kind != "Block" {
        return Err(invalid("scoped byte-copy scope does not belong to its function"));
    }
    let constructor = node(program, candidate.constructor_call, "Call")?;
    let native = node(program, candidate.native_call, "Call")?;
    if constructor.second_integer != 9 || native.second_integer != 10 ||
        !tree.below(candidate.constructor_call, candidate.scope) ||
        !tree.below(candidate.native_call, candidate.scope) {
        return Err(invalid("scoped byte-copy constructor or native Call disagrees"));
    }
    let constructor_function = selected(program, constructor)?;
    let contract = constructor_function.ffi_contract.as_ref()
        .ok_or_else(|| invalid("scoped constructor lacks policy"))?;
    if contract.result_policy != "fallible_owned_out" || contract.destructor.is_empty() {
        return Err(invalid("scoped constructor lacks fallible owner policy"));
    }
    let result = node(program, candidate.result_declaration, "LocalDeclare")?;
    if result.children.as_slice() != [candidate.constructor_call] ||
        !tree.below(candidate.result_declaration, candidate.scope) {
        return Err(invalid("scoped constructor has no unique result binding"));
    }
    let guard = node(program, candidate.guard, "GuardUnwrap")?;
    if guard.text != candidate.owner_name || guard.text.is_empty() ||
        guard.children.len() != 2 || !tree.below(candidate.guard, candidate.scope) {
        return Err(invalid("scoped Guard owner identity disagrees"));
    }
    let moved = node(program, guard.children[0], "MoveValue")?;
    let source = moved.children.first().and_then(|index| program.nodes.get(*index))
        .ok_or_else(|| invalid("scoped Guard lacks moved result"))?;
    if moved.children.len() != 1 || source.kind != "LocalRead" ||
        source.text != result.text || source.ty != result.ty {
        return Err(invalid("scoped Guard does not consume its exact result"));
    }
    let failure = node(program, guard.children[1], "Block")?;
    if failure.children.len() != 1 ||
        program.nodes[failure.children[0]].kind != "Return" ||
        program.nodes[failure.children[0]].children.len() != 1 {
        return Err(invalid("scoped Guard failure must return without owner cleanup"));
    }
    let input_backing = anchor(program, function, &tree, &candidate.input_backing)?;
    let input_count = anchor(program, function, &tree, &candidate.input_count)?;
    let output_backing = anchor(program, function, &tree, &candidate.output_backing)?;
    let output_capacity = anchor(program, function, &tree, &candidate.output_capacity)?;
    if constructor.children.len() != 3 || constructor.ty != result.ty ||
        !local(program, constructor.children[1], input_count, "Int") ||
        !local(program, constructor.children[2], output_capacity, "Int") {
        return Err(invalid("scoped constructor does not receive the exact copied counts"));
    }
    if !matches!(candidate.output_backing.binding, ScopedBinding::Local(_)) ||
        input_backing == output_backing || input_count == output_capacity ||
        candidate.input_count.ty != "Int" || candidate.output_capacity.ty != "Int" {
        return Err(invalid("scoped byte-copy backing or count authority is ambiguous"));
    }
    let output_declare_index = match candidate.output_backing.binding {
        ScopedBinding::Local(index) => index,
        ScopedBinding::Parameter(_) => unreachable!("parameter output was rejected above"),
    };
    let declaration = node(program, output_declare_index, "LocalDeclare")?;
    if declaration.ty != candidate.output_backing.ty || declaration.children.len() != 1 {
        return Err(invalid("scoped output has no fresh intrinsic definition"));
    }
    let create = collection_node(program, declaration.children[0], "Create",
        &candidate.output_backing.ty)?;
    if create.children.len() != 1 || !function.parameters.iter().any(|(name, ty)|
        local(program, create.children[0], name, ty) &&
        create.collection_intrinsic.as_ref().is_some_and(|plan|
            plan.brand == *name) &&
        ty.starts_with("Reference(Arena,")) {
        return Err(invalid("scoped output intrinsic uses an unbound Arena"));
    }
    for index in [candidate.prefill_loop, candidate.input_loop, candidate.output_loop] {
        node(program, index, "Loop")?;
        if !tree.contains(index) { return Err(invalid("scoped byte-copy loop is outside body")); }
    }
    if tree.below(candidate.prefill_loop, candidate.scope) ||
        !tree.below(candidate.input_loop, candidate.scope) ||
        !tree.below(candidate.output_loop, candidate.scope) {
        return Err(invalid("scoped byte-copy loop placement disagrees"));
    }
    let native_result = node(program, candidate.native_result_declaration, "LocalDeclare")?;
    if native_result.children.as_slice() != [candidate.native_call] || native.ty != "Int" ||
        native_result.ty != "Int" || !tree.below(candidate.native_result_declaration, candidate.scope) {
        return Err(invalid("scoped byte-copy native result binding disagrees"));
    }
    let accept = node(program, candidate.accept_call, "Call")?;
    if accept.second_integer != 11 || !tree.below(candidate.accept_call, candidate.scope) ||
        selected(program, accept)?.extern_symbol != "os_FfiCallRegionAcceptResult" {
        return Err(invalid("scoped byte-copy AcceptResult binding disagrees"));
    }
    let wrapper_name = constructor.ty.strip_prefix("Struct(\"")
        .and_then(|tail| tail.split_once('"')).map(|(name, _)| name)
        .ok_or_else(|| invalid("scoped constructor result is not a struct"))?;
    let wrapper = program.layouts.iter().find(|layout|
        layout.erased_name == wrapper_name).ok_or_else(|| invalid(
        "scoped constructor wrapper layout is missing"))?;
    let owner_type = wrapper.fields.iter().find(|field| field.name == "Val")
        .ok_or_else(|| invalid("scoped constructor has no Val owner"))?.ty.clone();
    if output_backing == candidate.owner_name || input_backing == candidate.owner_name {
        return Err(invalid("scoped owner aliases a backing"));
    }
    let owner_layout_name = owner_type.strip_prefix("Struct(\"")
        .and_then(|tail| tail.split_once('"')).map(|(name, _)| name)
        .ok_or_else(|| invalid("scoped owner has no struct layout"))?;
    let owner_layout = program.layouts.iter().find(|layout|
        layout.erased_name == owner_layout_name && layout.brand.is_empty() &&
        layout.repr_c && !layout.packed && layout.abi == "C" &&
        layout.fields.len() == 1 && layout.fields[0].ty == "RawPointer(Byte)")
        .ok_or_else(|| invalid("scoped owner does not have the checked raw layout"))?;
    let raw_field = owner_layout.fields[0].name.as_str();
    let block = node(program, scope.children[0], "Block")?;
    if tree.parent.get(&candidate.result_declaration) != Some(&scope.children[0]) ||
        tree.parent.get(&candidate.guard) != Some(&scope.children[0]) ||
        tree.parent.get(&candidate.input_loop) != Some(&scope.children[0]) ||
        tree.parent.get(&candidate.native_result_declaration) != Some(&scope.children[0]) ||
        tree.parent.get(&candidate.output_loop) != Some(&scope.children[0]) {
        return Err(invalid("scoped byte-copy principal steps are not in one lexical block"));
    }
    let result_pos = position(block, candidate.result_declaration)?;
    let guard_pos = position(block, candidate.guard)?;
    let input_pos = position(block, candidate.input_loop)?;
    let native_pos = position(block, candidate.native_result_declaration)?;
    let output_pos = position(block, candidate.output_loop)?;
    if !(result_pos < guard_pos && guard_pos < input_pos && input_pos < native_pos &&
        native_pos < output_pos && output_pos + 1 == block.children.len() - 1) {
        return Err(invalid("scoped byte-copy stages are out of order or lack a final Return"));
    }
    let final_return = block.children[output_pos + 1];
    node(program, final_return, "Return")?;
    let body_block = node(program, body, "Block")?;
    if tree.parent.get(&candidate.scope) != Some(&body) ||
        tree.parent.get(&candidate.prefill_loop) != Some(&body) {
        return Err(invalid("scoped byte-copy prefill and activation are not direct body steps"));
    }
    let prefill_pos = position(body_block, candidate.prefill_loop)?;
    let scope_pos = position(body_block, candidate.scope)?;
    if prefill_pos + 2 != scope_pos ||
        scope_pos + 1 != body_block.children.len() {
        return Err(invalid("scoped byte-copy prefill/Clear does not precede activation"));
    }
    let clear_statement = node(program, body_block.children[prefill_pos + 1], "Evaluate")?;
    if clear_statement.children.len() != 1 { return Err(invalid(
        "scoped output Clear has no unique call")); }
    let clear = collection_node(program, clear_statement.children[0], "Clear",
        &candidate.output_backing.ty)?;
    if clear.children.len() != 1 || !local(program, clear.children[0],
        output_backing, &candidate.output_backing.ty) {
        return Err(invalid("scoped intrinsic Clear receiver disagrees"));
    }
    let (prefill_body, prefill_index) = monotone_loop(program, body_block,
        candidate.prefill_loop, output_capacity, "Int")?;
    if prefill_body.children.len() != 2 { return Err(invalid(
        "scoped prefill loop has an extra effect")); }
    let prefill_evaluate = node(program, prefill_body.children[0], "Evaluate")?;
    if prefill_evaluate.children.len() != 1 { return Err(invalid(
        "scoped prefill does not contain one Push")); }
    let prefill_push = collection_node(program, prefill_evaluate.children[0], "Append",
        &candidate.output_backing.ty)?;
    let prefill_value = node(program, prefill_push.children[1], "ExplicitCast")?;
    if !local(program, prefill_push.children[0], output_backing,
            &candidate.output_backing.ty) ||
        prefill_value.ty != "Byte" || prefill_value.children.len() != 1 ||
        !zero(program, prefill_value.children[0]) {
        return Err(invalid("scoped prefill is not a zero-byte Push"));
    }
    if prefill_index == output_backing || prefill_index == input_backing {
        return Err(invalid("scoped prefill index aliases a backing"));
    }

    // Only the checked typed candidate identifies where the counts originate;
    // the worker rechecks their actual reaching definition and every use.
    if let ScopedBinding::Local(count_index) = candidate.input_count.binding {
        let count_declare = node(program, count_index, "LocalDeclare")?;
        if count_declare.children.len() != 1 { return Err(invalid(
            "scoped input count has no unique definition")); }
        let len_call = node(program, count_declare.children[0], "Call")?;
        if len_call.second_integer != 0 || len_call.text != "len" ||
            inline_call_name(program, len_call).as_deref() != Some("len") ||
            len_call.second_text != "len" ||
            len_call.ty != "Int" || len_call.children.len() != 2 ||
            !local(program, len_call.children[0], "len", "Void") ||
            !local(program, len_call.children[1], input_backing,
                &candidate.input_backing.ty) {
            return Err(invalid("scoped input count is not the backing length"));
        }
    } else {
        return Err(invalid("scoped input parameter count lacks checked backing length"));
    }

    let mut cleanups = HashSet::new();
    let mut operations = HashSet::new();
    let (input_body, input_index) = monotone_loop(program, block,
        candidate.input_loop, input_count, "Int")?;
    if input_body.children.len() != 3 ||
        input_index == output_backing || input_index == input_backing ||
        input_index == prefill_index {
        return Err(invalid("scoped input loop has extra effects or aliased index"));
    }
    let write_status = node(program, input_body.children[0], "LocalDeclare")?;
    if write_status.ty != "Int" || write_status.children.len() != 1 ||
        write_status.text.is_empty() { return Err(invalid(
            "scoped input write has no status binding")); }
    let write_call_index = write_status.children[0];
    let write = operation(program, write_call_index, "WriteInput", &candidate.owner_name,
        &owner_type, raw_field)?;
    if write.children.len() != 4 ||
        !local(program, write.children[2], &input_index, "Int") ||
        !operations.insert(write_call_index) {
        return Err(invalid("scoped input write uses a different index"));
    }
    let source_byte = collection_node(program, write.children[3], "Read",
        &candidate.input_backing.ty)?;
    if source_byte.ty != "Byte" || source_byte.children.len() != 2 ||
        !local(program, source_byte.children[0], input_backing,
            &candidate.input_backing.ty) ||
        !local(program, source_byte.children[1], &input_index, "Int") {
        return Err(invalid("scoped input read is not from its checked backing and index"));
    }
    failure_branch(program, input_body.children[1], &write_status.text,
        &candidate.owner_name, &owner_type, &contract.destructor, &mut cleanups,
        output_backing)?;
    let native_function = selected(program, native)?;
    let spans = byte_span_contract(native_function)?;
    let native_plan = native.isolated_call_plan.as_ref().ok_or_else(|| invalid(
        "scoped native Call lacks its signed-pair candidate plan"))?;
    if input_pos + 1 != native_pos ||
        native.children.len() != native_function.parameters.len() + 1 ||
        spans.len() != 2 || native_plan.positions.len() != 2 {
        return Err(invalid("scoped native Call is not adjacent or has two byte spans"));
    }
    let mut paired_positions = HashSet::new();
    let mut paired_roles = HashSet::new();
    for (pointer, count, direction) in spans {
        if !paired_roles.insert(direction) {
            return Err(invalid("scoped native Call repeats a byte-span direction"));
        }
        let getter_role = if direction == "read" { "InputAddress" } else {
            "OutputAddress" };
        let expected_count = if direction == "read" { input_count } else {
            output_capacity };
        if !paired_positions.insert(pointer) || !paired_positions.insert(count) ||
            !local(program, native.children[count + 1], expected_count, "Int") {
            return Err(invalid("scoped native byte span has mismatched count or capacity"));
        }
        let getter_index = native.children[pointer + 1];
        let getter = operation(program, getter_index, getter_role,
            &candidate.owner_name, &owner_type, raw_field)?;
        if getter.children.len() != 2 || !operations.insert(getter_index) {
            return Err(invalid("scoped native pointer getter is stored or repeated"));
        }
    }
    if paired_roles.len() != 2 || !paired_roles.contains("read") ||
        !paired_roles.contains("write") {
        return Err(invalid("scoped native Call lacks both byte-span directions"));
    }
    for (position, (_, ty)) in native_function.parameters.iter().enumerate() {
        if paired_positions.contains(&position) { continue; }
        let value = &program.nodes[native.children[position + 1]];
        if !matches!(ty.as_str(), "Int" | "Byte" | "Bool") || value.ty != *ty ||
            !(value.kind == "IntegerLiteral" || value.kind == "BooleanLiteral" ||
                (value.kind == "LocalRead" && value.children.is_empty() &&
                    ![candidate.owner_name.as_str(), input_backing, output_backing]
                        .contains(&value.text.as_str()))) {
            return Err(invalid("scoped native extra value argument is not a pure scalar"));
        }
    }
    if native_result.text.is_empty() || native_result.text == output_capacity ||
        native_result.text == input_count {
        return Err(invalid("scoped native result aliases a count"));
    }
    let negative_branch = *block.children.get(native_pos + 1)
        .ok_or_else(|| invalid("scoped native result lacks negative check"))?;
    let overcap_branch = *block.children.get(native_pos + 2)
        .ok_or_else(|| invalid("scoped native result lacks capacity check"))?;
    for (branch_index, relation, right_name) in [
        (negative_branch, "<", None), (overcap_branch, ">", Some(output_capacity))
    ] {
        let branch = node(program, branch_index, "Branch")?;
        if branch.children.len() != 2 { return Err(invalid(
            "scoped result check has an unsupported else arm")); }
        let test = node(program, branch.children[0], "BinaryOperation")?;
        if test.text != relation || test.ty != "Int" || test.children.len() != 2 ||
            !local(program, test.children[0], &native_result.text, "Int") ||
            !right_name.map_or_else(|| zero(program, test.children[1]),
                |name| local(program, test.children[1], name, "Int")) {
            return Err(invalid("scoped native result check uses wrong value or cap"));
        }
        let failure = node(program, branch.children[1], "Block")?;
        if failure.children.len() != 1 { return Err(invalid(
            "scoped native result failure does not terminate")); }
        owner_return(program, failure.children[0], &candidate.owner_name,
            &owner_type, &contract.destructor, &mut cleanups, output_backing, true)?;
    }
    if position(block, candidate.accept_call).is_ok() {
        return Err(invalid("scoped AcceptResult must be bound by a unique status declaration"));
    }
    let accept_declaration_index = *block.children.get(native_pos + 3)
        .ok_or_else(|| invalid("scoped AcceptResult has no status declaration"))?;
    let accept_declaration = node(program, accept_declaration_index, "LocalDeclare")?;
    if accept_declaration.ty != "Int" || accept_declaration.text.is_empty() ||
        accept_declaration.children.as_slice() != [candidate.accept_call] ||
        accept.children.len() != 3 ||
        !exact_owner_raw(program, accept.children[1], &candidate.owner_name,
            &owner_type, raw_field) ||
        !local(program, accept.children[2], &native_result.text, "Int") ||
        !operations.insert(candidate.accept_call) {
        return Err(invalid("scoped AcceptResult is not bound to the checked count"));
    }
    failure_branch(program, *block.children.get(native_pos + 4).ok_or_else(||
        invalid("scoped AcceptResult lacks a checked status branch"))?,
        &accept_declaration.text, &candidate.owner_name, &owner_type,
        &contract.destructor, &mut cleanups, output_backing)?;
    if native_pos + 6 != output_pos {
        return Err(invalid("scoped output loop does not follow accepted result"));
    }
    let (output_body, output_index) = monotone_loop(program, block,
        candidate.output_loop, &native_result.text, "Int")?;
    if output_body.children.len() != 5 ||
        [prefill_index.as_str(), input_index.as_str(), input_backing,
            output_backing, input_count, output_capacity, &native_result.text]
            .contains(&output_index.as_str()) {
        return Err(invalid("scoped output loop has extra effects or aliased index"));
    }
    let byte_declaration = node(program, output_body.children[0], "LocalDeclare")?;
    if byte_declaration.ty != "Byte" || byte_declaration.text.is_empty() ||
        byte_declaration.children.len() != 1 {
        return Err(invalid("scoped output byte has no fresh local storage"));
    }
    let byte_initial = node(program, byte_declaration.children[0], "ExplicitCast")?;
    if byte_initial.ty != "Byte" || byte_initial.children.len() != 1 ||
        !zero(program, byte_initial.children[0]) {
        return Err(invalid("scoped output byte initializer has an unproved effect"));
    }
    let read_status = node(program, output_body.children[1], "LocalDeclare")?;
    if read_status.ty != "Int" || read_status.text.is_empty() ||
        read_status.children.len() != 1 {
        return Err(invalid("scoped output read has no status binding"));
    }
    let read_index = read_status.children[0];
    let read = operation(program, read_index, "ReadOutput",
        &candidate.owner_name, &owner_type, raw_field)?;
    if read.children.len() != 4 ||
        !local(program, read.children[2], &output_index, "Int") ||
        !operations.insert(read_index) {
        return Err(invalid("scoped output read uses a different index"));
    }
    let byte_cast = node(program, read.children[3], "ExplicitCast")?;
    if byte_cast.ty != "RawPointer(Byte)" || byte_cast.children.len() != 1 {
        return Err(invalid("scoped output byte address has wrong type"));
    }
    let byte_address = node(program, byte_cast.children[0], "AddressOf")?;
    if byte_address.children.len() != 1 ||
        !local(program, byte_address.children[0], &byte_declaration.text, "Byte") {
        return Err(invalid("scoped output byte address escapes its local"));
    }
    failure_branch(program, output_body.children[2], &read_status.text,
        &candidate.owner_name, &owner_type, &contract.destructor,
        &mut cleanups, output_backing)?;
    let publish = node(program, output_body.children[3], "Evaluate")?;
    if publish.children.len() != 1 { return Err(invalid(
        "scoped output byte is not published by one checked operation")); }
    let push = collection_node(program, publish.children[0], "Append",
        &candidate.output_backing.ty)?;
    if !local(program, push.children[1], &byte_declaration.text, "Byte") {
        return Err(invalid("scoped output Push does not use the checked byte"));
    }
    if !local(program, push.children[0], output_backing,
        &candidate.output_backing.ty) {
        return Err(invalid("scoped output intrinsic Append has a different destination"));
    }
    if ![clear, prefill_push, push].iter().all(|operation|
        same_collection_identity(create, operation)) {
        return Err(invalid("scoped output operations change layout or brand"));
    }
    owner_return(program, final_return, &candidate.owner_name,
        &owner_type, &contract.destructor, &mut cleanups, output_backing, false)?;
    let mut allowed_result_reads = HashSet::from([moved.children[0]]);
    let mut allowed_direct = HashSet::from([
        candidate.result_declaration, candidate.guard, candidate.input_loop,
        candidate.native_result_declaration, negative_branch, overcap_branch,
        accept_declaration_index, block.children[native_pos + 4],
        candidate.output_loop, final_return,
    ]);
    let mut code_name = None;
    for child in &block.children[result_pos + 1..guard_pos] {
        let declaration = node(program, *child, "LocalDeclare")?;
        if declaration.children.len() != 1 { return Err(invalid(
            "scoped result has an unsupported pre-Guard statement")); }
        let selection = node(program, declaration.children[0], "FieldOrMethodSelect")?;
        if !matches!(selection.text.as_str(), "Ok" | "Code") ||
            selection.children.len() != 1 ||
            !local(program, selection.children[0], &result.text, &result.ty) {
            return Err(invalid("scoped result has an untrusted pre-Guard read"));
        }
        if selection.text == "Code" {
            if declaration.ty != "Int" || code_name.replace(declaration.text.as_str()).is_some() {
                return Err(invalid("scoped result Code has an ambiguous binding"));
            }
        }
        allowed_direct.insert(*child);
        allowed_result_reads.insert(selection.children[0]);
    }
    let failure_return = &program.nodes[failure.children[0]];
    if failure_return.children.len() != 1 ||
        !code_name.is_some_and(|name|
            local(program, failure_return.children[0], name, "Int")) {
        return Err(invalid("scoped failed Guard has an effectful or unrelated return"));
    }
    // Existing diagnostic fixtures carry an unrelated scalar defer to reach
    // the old selector. It is not part of this new safe cohort: even a call
    // whose arguments omit the protected names could free the caller Arena.
    if guard_pos + 2 != input_pos {
        return Err(invalid("scoped activation has an unqualified deferred effect"));
    }
    allowed_direct.insert(block.children[input_pos - 1]);
    allowed_direct.insert(block.children[output_pos - 1]);
    if block.children.iter().any(|child| !allowed_direct.contains(child)) ||
        block.children.len() != allowed_direct.len() {
        return Err(invalid("scoped byte-copy activation has an unsupported statement"));
    }
    let protected = [input_backing, input_count, output_backing, output_capacity];
    let mut allowed_mutations = HashSet::from([
        prefill_body.children[1], input_body.children[2], output_body.children[4],
    ]);
    allowed_mutations.retain(|index| tree.contains(*index));
    let input_count_index = match candidate.input_count.binding {
        ScopedBinding::Local(index) => index,
        ScopedBinding::Parameter(_) => unreachable!("parameter count was rejected above"),
    };
    let count_pos = position(body_block, input_count_index)?;
    if count_pos >= prefill_pos { return Err(invalid(
        "scoped input count is not established before prefill")); }
    let parameter_capacity = match candidate.output_capacity.binding {
        ScopedBinding::Local(cap_index) => {
            let cap = node(program, cap_index, "LocalDeclare")?;
            if position(body_block, cap_index)? >= prefill_pos ||
                cap.children.len() != 1 ||
                program.nodes[cap.children[0]].kind != "IntegerLiteral" ||
                program.nodes[cap.children[0]].ty != "Int" ||
                !(0..=1_073_741_824).contains(&program.nodes[cap.children[0]].integer) {
                return Err(invalid("scoped prefill capacity lacks a safe checked bound"));
            }
            false
        }
        ScopedBinding::Parameter(_) => true,
    };
    let output_pos_in_body = position(body_block, output_declare_index)?;
    let cap_count = if parameter_capacity { 0 } else { 1 };
    if body_block.children.get(output_pos_in_body + 1) != Some(&input_count_index) ||
        (cap_count == 1 && !matches!(candidate.output_capacity.binding,
            ScopedBinding::Local(index) if
                body_block.children.get(output_pos_in_body + 2) == Some(&index))) ||
        output_pos_in_body + 3 + cap_count != prefill_pos ||
        prefill_pos + 2 != scope_pos {
        return Err(invalid(
            "scoped output setup has an unproved effect or a changed count"));
    }
    let prefix_start = if parameter_capacity {
        if body_block.children.len() < 2 ||
            !prefill_capacity_exit(program, body_block.children[0],
                output_capacity, "<", 0) ||
            !prefill_capacity_exit(program, body_block.children[1],
                output_capacity, ">", 1_073_741_824) {
            return Err(invalid(
                "scoped caller capacity lacks dominating range-error exits"));
        }
        2
    } else { 0 };
    match candidate.input_backing.binding {
        ScopedBinding::Local(input_index) => {
            let declaration = node(program, input_index, "LocalDeclare")?;
            if declaration.ty != candidate.input_backing.ty || declaration.children.len() != 1 {
                return Err(invalid("scoped local input has no fresh intrinsic definition"));
            }
            let create = collection_node(program, declaration.children[0], "Create",
                &candidate.input_backing.ty)?;
            if create.children.len() != 1 || !function.parameters.iter().any(|(name, ty)|
                local(program, create.children[0], name, ty) &&
                create.collection_intrinsic.as_ref().is_some_and(|plan|
                    plan.brand == *name) &&
                ty.starts_with("Reference(Arena,")) {
                return Err(invalid("scoped local input intrinsic uses an unbound Arena"));
            }
            let input_pos_in_body = position(body_block, input_index)?;
            if input_pos_in_body != prefix_start ||
                input_pos_in_body >= output_pos_in_body {
                return Err(invalid(
                    "scoped local input has an unproved setup predecessor"));
            }
            for statement in &body_block.children[input_pos_in_body + 1..output_pos_in_body] {
                let evaluated = node(program, *statement, "Evaluate")?;
                if evaluated.children.len() != 1 { return Err(invalid(
                    "scoped input setup has a nonlocal effect")); }
                let push = collection_node(program, evaluated.children[0], "Append",
                    &candidate.input_backing.ty)?;
                if !local(program, push.children[0], input_backing,
                    &candidate.input_backing.ty) {
                    return Err(invalid("scoped input intrinsic Append aliases backing"));
                }
                if !same_collection_identity(create, push) {
                    return Err(invalid("scoped local input operations change layout or brand"));
                }
                let byte = node(program, push.children[1], "ExplicitCast")?;
                if byte.ty != "Byte" || byte.children.len() != 1 ||
                    program.nodes[byte.children[0]].kind != "IntegerLiteral" ||
                    !(0..=255).contains(&program.nodes[byte.children[0]].integer) {
                    return Err(invalid("scoped input setup is not a constant byte"));
                }
            }
            if !same_collection_identity(create, source_byte) {
                return Err(invalid("scoped local input Read changes layout or brand"));
            }
        }
        ScopedBinding::Parameter(_) => {
            if output_pos_in_body != prefix_start {
                return Err(invalid(
                    "scoped caller input has an unproved effect before destination creation"));
            }
        }
    }
    let mut collection_operations = HashSet::new();
    let output_declaration = &program.nodes[output_declare_index];
    collection_operations.insert(output_declaration.children[0]);
    for index in [clear_statement.children[0], prefill_evaluate.children[0],
        write.children[3], publish.children[0]] {
        if !collection_operations.insert(index) {
            return Err(invalid("scoped intrinsic operation occurs more than once"));
        }
    }
    if let ScopedBinding::Local(input_index) = candidate.input_backing.binding {
        let input_declaration = &program.nodes[input_index];
        collection_operations.insert(input_declaration.children[0]);
        let input_pos_in_body = position(body_block, input_index)?;
        for statement in &body_block.children[input_pos_in_body + 1..output_pos_in_body] {
            let evaluated = node(program, *statement, "Evaluate")?;
            collection_operations.insert(evaluated.children[0]);
        }
    }
    for index in &tree.reachable {
        if program.nodes[*index].kind == "CollectionIntrinsic" &&
            !collection_operations.contains(index) {
            return Err(invalid("scoped body has an extra collection intrinsic"));
        }
    }
    let prefill_range = body_block.children[output_pos_in_body + 1..scope_pos].iter().copied();
    let scoped_range = std::iter::once(candidate.scope);
    let mut later_nodes = HashSet::new();
    for root in prefill_range.chain(scoped_range) {
        let mut stack = vec![root];
        while let Some(index) = stack.pop() {
            if !later_nodes.insert(index) { return Err(invalid(
                "scoped activation shares a protected value node")); }
            stack.extend(program.nodes[index].children.iter().copied());
        }
    }
    for index in &later_nodes {
        let value = &program.nodes[*index];
        if value.kind == "Assign" && !allowed_mutations.contains(index) {
            return Err(invalid("scoped activation changes a reaching value"));
        }
        if value.kind == "MoveValue" && *index != guard.children[0] {
            return Err(invalid("scoped activation moves another value"));
        }
        if value.kind == "AddressOf" && value.children.len() == 1 &&
            program.nodes[value.children[0]].kind == "LocalRead" &&
            protected.contains(&program.nodes[value.children[0]].text.as_str()) {
            return Err(invalid("scoped activation aliases a count or backing"));
        }
        if value.kind == "LocalDeclare" && value.children.len() == 1 &&
            program.nodes[value.children[0]].kind == "LocalRead" &&
            protected.contains(&program.nodes[value.children[0]].text.as_str()) {
            return Err(invalid("scoped activation copies a protected binding"));
        }
        if value.kind == "FieldOrMethodSelect" && value.children.len() == 1 &&
            program.nodes[value.children[0]].kind == "LocalRead" &&
            protected.contains(&program.nodes[value.children[0]].text.as_str()) &&
            ![prefill_push.children[0], clear.children[0], push.children[0]]
                .contains(index) {
            return Err(invalid("scoped activation selects an unproved backing field"));
        }
        if value.kind == "Call" && value.second_integer == 0 {
            if value.children.iter().any(|child| program.nodes[*child].kind == "LocalRead" &&
                protected.contains(&program.nodes[*child].text.as_str())) &&
                !(value.text == "len" && value.second_text == "len" &&
                    value.children.len() == 2 && (
                        (local(program, value.children[1], output_backing,
                            &candidate.output_backing.ty) &&
                            tree.below(*index, final_return)) ||
                        (local(program, value.children[1], input_backing,
                            &candidate.input_backing.ty) &&
                            tree.below(*index, input_count_index)))) {
                return Err(invalid("scoped activation passes protected state to an extra call"));
            }
            if value.children.first().is_some_and(|child| {
                let callee = &program.nodes[*child];
                callee.kind == "FieldOrMethodSelect" && callee.children.len() == 1 &&
                    program.nodes[callee.children[0]].kind == "LocalRead" &&
                    protected.contains(&program.nodes[callee.children[0]].text.as_str())
            }) && ![prefill_evaluate.children[0], clear_statement.children[0],
                publish.children[0]].contains(index) {
                return Err(invalid("scoped activation mutates a protected backing"));
            }
        }
    }
    // No other node may use the live raw owner or result wrapper. The exact
    // allowed uses are the Guard, the five plan-bound region operations, and
    // attached cleanup; all other aliases and extra calls fail closed.
    let allowed_owner_reads: HashSet<usize> = operations.iter()
        .flat_map(|index| program.nodes[*index].children.get(1).copied())
        .filter_map(|raw| program.nodes[raw].children.first().copied()).collect();
    for index in &tree.reachable {
        let value = &program.nodes[*index];
        if value.kind == "LocalRead" && value.text == candidate.owner_name &&
            !allowed_owner_reads.contains(index) {
            return Err(invalid("scoped owner is read outside its sealed operation"));
        }
        if value.kind == "ResourceStorage" && value.text == candidate.owner_name &&
            !cleanups.iter().any(|cleanup|
                program.nodes[*cleanup].children.get(1) == Some(index)) {
            return Err(invalid("scoped owner is stored outside exact cleanup"));
        }
        if value.kind == "LocalRead" && value.text == result.text &&
            !allowed_result_reads.contains(index) {
            return Err(invalid("scoped result wrapper is reused after Guard"));
        }
        if value.kind == "Call" && value.second_integer == 11 &&
            !operations.contains(index) {
            return Err(invalid("scoped body has an extra region operation"));
        }
        if value.kind == "Call" && value.second_integer == 10 &&
            *index != candidate.native_call {
            return Err(invalid("scoped body has an extra native call"));
        }
    }
    let input_collection_brand = source_byte.collection_intrinsic.as_ref()
        .ok_or_else(|| invalid("scoped input Read lost its checked brand"))?.brand.clone();
    let output_collection_brand = program.nodes[
        program.nodes[output_declare_index].children[0]]
        .collection_intrinsic.as_ref()
        .ok_or_else(|| invalid("scoped output Create lost its checked brand"))?.brand.clone();
    Ok(ScopedProof {
        function_index, constructor_call: candidate.constructor_call,
        guard: candidate.guard, owner_name: candidate.owner_name.clone(),
        owner_type, destructor: contract.destructor.clone(), cleanups,
        operations, collection_operations, input_collection_brand,
        output_collection_brand,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::full_program::{Layout, LayoutField};

    fn hex(value: &str) -> String {
        value.as_bytes().iter().map(|byte| format!("{byte:02x}")).collect()
    }

    fn change_intrinsic_field(canonical: &str, index: usize,
        field_after_version: usize, old: &str, replacement: &str) -> String {
        let prefix = format!("node: {index}|");
        let rows: Vec<_> = canonical.lines().filter(|line| line.starts_with(&prefix)).collect();
        assert_eq!(rows.len(), 1, "one executable operation row");
        let row = rows[0];
        let mut fields: Vec<_> = row.split('|').map(str::to_owned).collect();
        let version = fields.iter().position(|field| field == "collection_intrinsic.v1")
            .expect("executable versioned operation");
        let position = version + 1 + field_after_version;
        assert_eq!(fields[position], hex(old), "actual mechanism must match");
        fields[position] = hex(replacement);
        let changed = canonical.replacen(row, &fields.join("|"), 1);
        assert_ne!(changed, canonical);
        changed
    }

    fn inline_callee_mutation(canonical: &str, program: &Program,
        call_index: usize) -> String {
        let call = &program.nodes[call_index];
        assert_eq!(call.kind, "Call");
        let callee_index = call.children[0];
        let callee = &program.nodes[callee_index];
        assert_eq!(callee.kind, "LocalRead");
        assert_eq!(callee.ty, "Void");
        let module: Vec<_> = program.nodes[..callee_index].iter().enumerate()
            .filter_map(|(index, node)| (node.kind == "LocalRead" &&
                node.ty == "Void" && node.text == "std" &&
                node.children.is_empty()).then_some(index)).collect();
        assert!(!module.is_empty(), "source retained a pure module leaf");
        let module = module[0];
        let mut changed_program = crate::full_program::parse(canonical)
            .expect("unmutated source baseline remains valid");
        changed_program.nodes[callee_index].kind = "FieldOrMethodSelect".into();
        changed_program.nodes[callee_index].text = "len".into();
        changed_program.nodes[callee_index].children = vec![module];
        assert!(crate::full_program::is_inline_call(
            &changed_program, &changed_program.nodes[call_index]),
            "callee mutation must move actual lowering dispatch");

        let prefix = format!("node: {callee_index}|");
        let rows: Vec<_> = canonical.lines().filter(|line|
            line.starts_with(&prefix)).collect();
        assert_eq!(rows.len(), 1);
        let row = rows[0];
        let mut fields: Vec<_> = row.split('|').map(str::to_owned).collect();
        assert_eq!(fields[1], hex("LocalRead"));
        assert_eq!(fields[2], hex("Void"));
        assert_eq!(fields[11], "0");
        assert_eq!(fields.len(), 12);
        fields[1] = hex("FieldOrMethodSelect");
        fields[3] = hex("len");
        fields[11] = "1".into();
        fields.push(module.to_string());
        let mutated = canonical.replacen(row, &fields.join("|"), 1);
        assert_ne!(mutated, canonical);
        mutated
    }

    fn collection(name: &str) -> Program {
        Program {
            target_triple: "x86_64-unknown-linux-gnu".into(),
            object_format: "Elf".into(),
            modules: Vec::new(), enumerations: Vec::new(),
            functions: Vec::new(), nodes: Vec::new(), entry_function: 0,
            layouts: vec![Layout {
                name: name.into(), erased_name: name.into(), brand: String::new(),
                repr_c: false, packed: false, abi: String::new(),
                fields: vec![
                    LayoutField { name: "arena".into(),
                        ty: "RawPointer(Arena)".into() },
                    LayoutField { name: "capacity".into(), ty: "Int".into() },
                    LayoutField { name: "data".into(),
                        ty: "RawPointer(Byte)".into() },
                    LayoutField { name: "len".into(), ty: "Int".into() },
                ],
            }],
        }
    }

    #[test]
    fn typed_byte_collection_requires_the_existing_native_route_and_layout() {
        let vector = collection("std_Vector_byte");
        assert!(checked_byte_vector(&vector,
            "Struct(\"std_Vector_byte\", None)").is_ok());
        assert!(checked_byte_vector(&vector,
            "Reference(Struct(\"std_Vector_byte\", None), None)").is_ok());
        assert!(checked_byte_vector(&vector,
            "Reference(Reference(Struct(\"std_Vector_byte\", None), None), None)").is_err());
        assert!(checked_byte_vector(&vector,
            "RawPointer(Struct(\"std_Vector_byte\", None))").is_err());
        let lookalike = collection("UserBytes");
        assert!(checked_byte_vector(&lookalike,
            "Struct(\"UserBytes\", None)").is_err());
        let mut wrong_element = collection("std_Vector_byte");
        wrong_element.layouts[0].fields[2].ty = "RawPointer(Int)".into();
        assert!(checked_byte_vector(&wrong_element,
            "Struct(\"std_Vector_byte\", None)").is_err());
    }

    #[test]
    fn historical_scoped_candidate_cannot_skip_executable_collection_contract() {
        // The original structural witness predates collection_intrinsic.v1.
        // Its historical positive result remains frozen; a current scoped
        // candidate must now carry independently checked executable ops.
        let canonical = include_str!("testdata/scoped_byte_copy_int.canonical");
        let error = crate::full_program::parse(canonical).unwrap_err().to_string();
        assert!(error.contains("lacks executable collection operations"), "{error}");
    }

    #[test]
    fn typed_four_argument_scoped_candidate_passes_the_whole_parser() {
        // Exact canonical bytes from the typed source producer with eight
        // executable collection operations. Runtime remains a separate gate.
        let canonical = include_str!("testdata/scoped_byte_copy_intrinsic_four_arg_producer.canonical");
        if let Err(error) = crate::full_program::parse(canonical) {
            panic!("typed no-defer scoped candidate was rejected: {error}");
        }
    }

    #[test]
    fn typed_caller_borrowed_input_and_fifth_scalar_pass_the_whole_parser() {
        let canonical = include_str!(
            "testdata/scoped_byte_copy_intrinsic_caller_five_arg_producer.canonical");
        if let Err(error) = crate::full_program::parse(canonical) {
            panic!("caller-borrowed five-argument scoped candidate was rejected: {error}");
        }
    }

    #[test]
    fn actual_borrowed_collection_operation_and_byte_type_mutants_refuse() {
        let baseline = include_str!(
            "testdata/scoped_byte_copy_intrinsic_caller_five_arg_producer.canonical");
        let program = crate::full_program::parse(baseline)
            .expect("actual post-R4 borrowed canonical must pass before mutation");
        let candidate = program.functions.iter().find_map(|function|
            function.scoped_byte_copy.as_ref()).expect("actual scoped candidate");
        let ScopedBinding::Local(output) = candidate.output_backing.binding else {
            panic!("fresh scoped output");
        };
        let create = program.nodes[output].children[0];
        let output_brand = program.nodes[create].collection_intrinsic.as_ref()
            .expect("output Create").brand.as_str();
        let prefill: Vec<_> = program.nodes.iter().enumerate().filter_map(|(index, node)|
            node.collection_intrinsic.as_ref().filter(|plan|
                plan.opcode == "Append" && plan.brand == output_brand)
                .map(|_| index)).collect();
        assert_eq!(prefill.len(), 2);
        let read: Vec<_> = program.nodes.iter().enumerate().filter_map(|(index, node)|
            node.collection_intrinsic.as_ref().filter(|plan|
                plan.opcode == "Read").map(|_| index)).collect();
        assert_eq!(read.len(), 1);
        for (name, index, field, old, replacement, expected) in [
            ("Create opcode", create, 0, "Create", "Append",
             "collection intrinsic type or operand arity disagrees"),
            ("prefill opcode", prefill[0], 0, "Append", "Clear",
             "collection intrinsic type or operand arity disagrees"),
            ("borrowed Byte element mismatch", read[0], 2, "Byte", "Int",
             "collection intrinsic type or operand arity disagrees"),
        ] {
            let mutated = change_intrinsic_field(baseline, index, field, old, replacement);
            match crate::full_program::parse(&mutated) {
                Ok(_) => panic!("{name}: ACCEPTED"),
                Err(error) => {
                    let actual = error.to_string();
                    if actual.contains(expected) {
                        println!("{name}: REJECTED expected assertion: {actual}");
                    } else {
                        println!("{name}: REJECTED different assertion: {actual}");
                        panic!("{name}: wrong rejection authority");
                    }
                }
            }
        }
    }

    #[test]
    fn scoped_collection_opcode_cannot_be_replaced_by_name_dispatch() {
        let baseline = include_str!(
            "testdata/scoped_byte_copy_intrinsic_caller_five_arg_producer.canonical");
        let program = crate::full_program::parse(baseline)
            .expect("actual source-produced executable baseline");
        let candidate = program.functions.iter().find_map(|function|
            function.scoped_byte_copy.as_ref()).expect("one scoped candidate");
        let ScopedBinding::Local(output) = candidate.output_backing.binding else {
            panic!("output is a fresh local");
        };
        let create_index = program.nodes[output].children[0];
        let create = &program.nodes[create_index];
        assert_eq!(create.kind, "CollectionIntrinsic");
        assert_eq!(create.collection_intrinsic.as_ref().unwrap().opcode, "Create");
        let prefix = format!("node: {create_index}|");
        let row = baseline.lines().find(|line| line.starts_with(&prefix)).unwrap();
        assert_eq!(baseline.matches(row).count(), 1);
        let mut fields: Vec<_> = row.split('|').map(str::to_owned).collect();
        assert!(fields[3].is_empty() && fields[4].is_empty());
        // A familiar legacy Call spelling cannot become an alternate
        // authority for the executable collection operation.
        fields[3] = hex("std.VectorNew");
        let mutant = baseline.replacen(row, &fields.join("|"), 1);
        assert_ne!(mutant, baseline);
        let error = crate::full_program::parse(&mutant).unwrap_err().to_string();
        assert!(error.contains("collection intrinsic has an unknown version or payload"),
            "legacy name injection refused at a different stage: {error}");
    }

    #[test]
    fn current_intrinsic_unknown_version_and_opcode_fail_closed() {
        let baseline = include_str!(
            "testdata/scoped_byte_copy_intrinsic_caller_five_arg_producer.canonical");
        let program = crate::full_program::parse(baseline)
            .expect("source-produced executable baseline");
        let candidate = program.functions.iter().find_map(|function|
            function.scoped_byte_copy.as_ref()).expect("scoped candidate");
        let ScopedBinding::Local(output) = candidate.output_backing.binding else {
            panic!("fresh output binding");
        };
        let create = program.nodes[output].children[0];
        assert_eq!(program.nodes[create].collection_intrinsic.as_ref()
            .expect("output Create").opcode, "Create");
        let prefix = format!("node: {create}|");
        let row = baseline.lines().find(|line| line.starts_with(&prefix)).unwrap();
        assert_eq!(baseline.matches(row).count(), 1);
        let versioned = row.replacen("collection_intrinsic.v1",
            "collection_intrinsic.v2", 1);
        assert_ne!(versioned, row);
        let wrong_version = baseline.replacen(row, &versioned, 1);
        let error = crate::full_program::parse(&wrong_version)
            .expect_err("unknown executable operation version was accepted")
            .to_string();
        assert!(error.contains("collection intrinsic has an unknown version or payload"),
            "different version rejection authority: {error}");

        let wrong_opcode = change_intrinsic_field(baseline, create, 0,
            "Create", "UnknownOperation");
        let error = crate::full_program::parse(&wrong_opcode)
            .expect_err("unknown executable operation opcode was accepted")
            .to_string();
        assert!(error.contains("collection intrinsic has an unknown opcode"),
            "different opcode rejection authority: {error}");
    }

    #[test]
    fn typed_local_input_and_fifth_scalar_pass_the_whole_parser() {
        let canonical = include_str!(
            "testdata/scoped_byte_copy_intrinsic_local_five_arg_producer.canonical");
        if let Err(error) = crate::full_program::parse(canonical) {
            panic!("local-input five-argument scoped candidate was rejected: {error}");
        }
    }

    #[test]
    fn actual_scoped_owner_and_result_type_names_are_not_authority() {
        let canonical = include_str!(
            "testdata/scoped_byte_copy_intrinsic_local_five_arg_producer.canonical");
        let original_owner = "43616c6c526567696f6e"; // CallRegion in canonical UTF-8 hex
        let renamed_owner = "52656e616d6564526567696f6e"; // RenamedRegion
        let original_result = "526567696f6e526573756c74"; // RegionResult
        let renamed_result = "52656e616d6564526573756c74"; // RenamedResult
        assert!(canonical.matches(original_owner).count() >= 5);
        assert!(canonical.matches(original_result).count() >= 3);
        let mut renamed = canonical.replace(original_owner, renamed_owner)
            .replace(original_result, renamed_result);
        // Runtime symbol spelling is release authority, not a source type.
        // The hex substring for CallRegion also occurs inside those symbols;
        // restore only the exact registered extern names after changing all
        // owner/result type identities.
        for suffix in ["TryCreate", "Free", "WriteInput", "InputAddress",
                       "OutputAddress", "AcceptResult", "ReadOutput"] {
            let original = format!("os_FfiCallRegion{suffix}");
            let accidentally_renamed = format!("os_FfiRenamedRegion{suffix}");
            let encode = |text: &str| text.as_bytes().iter()
                .map(|byte| format!("{byte:02x}")).collect::<String>();
            renamed = renamed.replace(&encode(&accidentally_renamed), &encode(&original));
        }
        if let Err(error) = crate::full_program::parse(&renamed) {
            panic!("consistent owner/result renaming lost generic authority: {error}");
        }
    }

    #[test]
    fn source_produced_renamed_owner_and_result_have_the_same_scoped_proof() {
        let original = crate::full_program::parse(include_str!(
            "testdata/scoped_byte_copy_intrinsic_four_arg_producer.canonical")).unwrap();
        let renamed = crate::full_program::parse(include_str!(
            "testdata/scoped_byte_copy_intrinsic_renamed_types_producer.canonical")).unwrap();
        let original_proofs = validate(&original).unwrap();
        let renamed_proofs = validate(&renamed).unwrap();
        assert_eq!(original_proofs.len(), 1);
        assert_eq!(renamed_proofs.len(), 1);
        let original_proof = original_proofs.values().next().unwrap();
        let renamed_proof = renamed_proofs.values().next().unwrap();
        assert_eq!(original_proof.owner_type, "Struct(\"CallRegion\", None)");
        assert_eq!(renamed_proof.owner_type, "Struct(\"OpaqueLease\", None)");
        assert_eq!(original_proof.operations.len(), renamed_proof.operations.len());
        assert_eq!(original_proof.cleanups.len(), renamed_proof.cleanups.len());
    }

    #[test]
    fn actual_scoped_copy_rejects_wrong_write_read_and_publication_bindings() {
        let baseline = include_str!("testdata/scoped_byte_copy_intrinsic_four_arg_producer.canonical");
        let program = crate::full_program::parse(baseline)
            .expect("source-produced baseline");
        let operation_call = |role: &str| {
            let calls: Vec<_> = program.nodes.iter().enumerate().filter_map(|(index, node)|
                (node.kind == "Call" && node.isolated_call_plan.as_ref()
                    .is_some_and(|plan| plan.cleanup == role)).then_some(index))
                .collect();
            assert_eq!(calls.len(), 1, "one scoped {role} Call");
            calls[0]
        };
        let write = &program.nodes[operation_call("write_input")];
        let input_read = write.children[3];
        assert_eq!(program.nodes[input_read].collection_intrinsic.as_ref()
            .expect("actual input Read").opcode, "Read");
        let output_read = &program.nodes[operation_call("read_output")];
        let published: Vec<_> = program.nodes.iter().enumerate().filter_map(|(index, node)|
            (node.collection_intrinsic.as_ref().is_some_and(|plan|
                plan.opcode == "Append") && node.children.len() == 2 &&
                program.nodes[node.children[1]].kind == "LocalRead" &&
                program.nodes[node.children[1]].ty == "Byte")
                .then_some(index)).collect();
        assert_eq!(published.len(), 1, "one checked output publication Append");
        let published_byte = program.nodes[published[0]].children[1];
        for (index, old_name, new_name, expected) in [
            (write.children[2], "i", "j", "scoped input write uses a different index"),
            (program.nodes[input_read].children[1], "i", "j",
                "scoped input read is not from its checked backing and index"),
            (output_read.children[2], "j", "i",
                "scoped output read uses a different index"),
            (published_byte, "value", "input",
                "scoped output Push does not use the checked byte"),
        ] {
            let prefix = format!("node: {index}|");
            let mut changed = false;
            let mut lines = Vec::new();
            for line in baseline.lines() {
                if line.starts_with(&prefix) {
                    assert!(!changed, "canonical node {index} appears twice");
                    let mut fields: Vec<_> = line[6..].split('|').map(str::to_owned).collect();
                    let encoded = |name: &str| name.as_bytes().iter()
                        .map(|byte| format!("{byte:02x}")).collect::<String>();
                    assert_eq!(fields[3], encoded(old_name));
                    fields[3] = encoded(new_name);
                    lines.push(format!("node: {}", fields.join("|")));
                    changed = true;
                } else {
                    lines.push(line.to_owned());
                }
            }
            assert!(changed, "canonical node {index} is missing");
            let mutated = lines.join("\n") + "\n";
            let error = crate::full_program::parse(&mutated)
                .err().expect("changed scoped binding was accepted");
            assert!(error.to_string().contains(expected),
                "node {index} was rejected by a different owner: {error}");
        }
    }

    #[test]
    fn typed_no_defer_scoped_candidate_lowers_to_native_object() {
        // Object emission tests the current native lowering path only. Package
        // admission and execution require their separate signed test profile.
        let canonical = include_str!("testdata/scoped_byte_copy_intrinsic_four_arg_producer.canonical");
        let program = crate::full_program::parse(canonical).expect("typed scoped candidate");
        let unique = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH).expect("clock")
            .as_nanos();
        let directory = std::env::temp_dir().join(format!(
            "gust-r2-scoped-object-{}-{unique}", std::process::id()));
        std::fs::create_dir(&directory).expect("private object directory");
        let object = directory.join("scoped.o");
        if let Err(error) = crate::full_program::lower_program(&program, &object) {
            panic!("typed scoped candidate native lowering failed: {error}");
        }
        let bytes = std::fs::read(&object).expect("scoped native object");
        assert!(bytes.starts_with(b"\x7fELF"), "native object is not ELF");
        std::fs::remove_dir_all(directory).expect("remove private object directory");
    }

    #[test]
    fn actual_intrinsic_producer_mutations_reject_at_expected_owners() {
        let baseline = include_str!(
            "testdata/scoped_byte_copy_intrinsic_four_arg_producer.canonical");
        let program = crate::full_program::parse(baseline)
            .expect("actual eight-operation source baseline");
        let candidate = program.functions.iter().find_map(|function|
            function.scoped_byte_copy.as_ref()).expect("scoped source candidate");
        let scoped_block = &program.nodes[program.nodes[candidate.scope].children[0]];
        let output_cap = match candidate.output_capacity.binding {
            ScopedBinding::Local(index) => program.nodes[index].text.as_str(),
            ScopedBinding::Parameter(index) => program.functions.iter().find(|function|
                function.scoped_byte_copy.is_some()).unwrap().parameters[index].0.as_str(),
        };
        let input_count = match candidate.input_count.binding {
            ScopedBinding::Local(index) => program.nodes[index].text.as_str(),
            ScopedBinding::Parameter(index) => program.functions.iter().find(|function|
                function.scoped_byte_copy.is_some()).unwrap().parameters[index].0.as_str(),
        };
        let change_text = |source: &str, index: usize, old: &str, new: &str| {
            let prefix = format!("node: {index}|");
            let row = source.lines().find(|line| line.starts_with(&prefix)).unwrap();
            assert_eq!(source.matches(row).count(), 1);
            let mut fields: Vec<_> = row.split('|').map(str::to_owned).collect();
            assert_eq!(fields[3], hex(old));
            fields[3] = hex(new);
            let result = source.replacen(row, &fields.join("|"), 1);
            assert_ne!(result, source);
            result
        };
        let constructor = &program.nodes[candidate.constructor_call];
        assert_eq!(program.nodes[constructor.children[2]].text, output_cap);
        let constructor_bad = change_text(baseline, constructor.children[2],
            output_cap, input_count);
        let native = &program.nodes[candidate.native_call];
        let output_actuals: Vec<_> = native.children.iter().skip(1).copied().filter(|index|
            program.nodes[*index].kind == "LocalRead" &&
            program.nodes[*index].text == output_cap).collect();
        assert_eq!(output_actuals.len(), 1);
        let native_bad = change_text(baseline, output_actuals[0],
            output_cap, input_count);
        let result_position = scoped_block.children.iter().position(|index|
            *index == candidate.native_result_declaration).unwrap();
        let capacity_branch = &program.nodes[scoped_block.children[result_position + 2]];
        assert_eq!(capacity_branch.kind, "Branch");
        let capacity_test = &program.nodes[capacity_branch.children[0]];
        assert_eq!(capacity_test.kind, "BinaryOperation");
        assert_eq!(capacity_test.text, ">");
        let reversed_bad = change_text(baseline, capacity_branch.children[0], ">", "<");
        let final_return = *scoped_block.children.last().unwrap();
        let result = &program.nodes[final_return];
        assert_eq!(result.kind, "Return");
        assert_eq!(result.children.len(), 2);
        let prefix = format!("node: {final_return}|");
        let row = baseline.lines().find(|line| line.starts_with(&prefix)).unwrap();
        let mut fields: Vec<_> = row.split('|').map(str::to_owned).collect();
        assert_eq!(fields[11], "2");
        assert_eq!(fields.len(), 14);
        fields[11] = "1".into();
        fields.pop();
        let missing_cleanup = baseline.replacen(row, &fields.join("|"), 1);
        assert_ne!(missing_cleanup, baseline);
        for (name, mutant, expected) in [
            ("constructor capacity", constructor_bad,
             "scoped constructor does not receive the exact copied counts"),
            ("native capacity", native_bad,
             "scoped native byte span has mismatched count or capacity"),
            ("reversed capacity check", reversed_bad,
             "scoped native result check uses wrong value or cap"),
            ("missing ordinary cleanup", missing_cleanup,
             "scoped ordinary exit lacks one exact owner cleanup"),
        ] {
            match crate::full_program::parse(&mutant) {
                Ok(_) => panic!("{name}: ACCEPTED"),
                Err(error) => {
                    let message = error.to_string();
                    if message.contains(expected) {
                        println!("{name}: REJECTED expected assertion: {message}");
                    } else {
                        println!("{name}: REJECTED different assertion: {message}");
                        panic!("{name}: wrong rejection authority");
                    }
                }
            }
        }
    }

    #[test]
    fn current_intrinsic_scope_rejects_inline_native_and_cleanup_dispatch() {
        let baseline = include_str!(
            "testdata/scoped_byte_copy_intrinsic_four_arg_producer.canonical");
        let program = crate::full_program::parse(baseline)
            .expect("actual source-produced intrinsic baseline");
        let function = program.functions.iter().find(|function|
            function.scoped_byte_copy.is_some()).expect("scoped function");
        let candidate = function.scoped_byte_copy.as_ref().unwrap();
        let tree = body_tree(&program, function.body_node.expect("scoped body"))
            .expect("actual scoped function tree");
        let cleanup = tree.reachable.iter().filter_map(|index| {
            let statement = &program.nodes[*index];
            if statement.kind != "Return" || statement.children.len() != 2 {
                return None;
            }
            let call_index = statement.children[1];
            let call = &program.nodes[call_index];
            if call.kind != "Call" || call.children.len() != 2 {
                return None;
            }
            let storage = &program.nodes[call.children[1]];
            (storage.kind == "ResourceStorage" &&
                storage.text == candidate.owner_name).then_some(call_index)
        }).min().expect("one reachable ordinary owner cleanup");
        for (name, call, expected) in [
            ("native", candidate.native_call,
                "byte-span Call lacks its exact canonical positions"),
            ("cleanup", cleanup,
                "scoped ordinary exit lacks one exact owner cleanup"),
        ] {
            let mutant = inline_callee_mutation(baseline, &program, call);
            let error = crate::full_program::parse(&mutant)
                .expect_err("inline substitution was accepted").to_string();
            assert!(error.contains(expected), "{name}: different rejection authority: {error}");
            println!("{name}: REJECTED expected assertion: {error}");
        }
    }

    #[test]
    fn historical_preintrinsic_mutation_corpus_cannot_be_upgraded_by_metadata() {
        // Earlier whole-parser mutation evidence is immutable. Those rows do
        // not contain executable collection operations and must never become
        // R2 scoped authority solely because their Function plan is present.
        for (name, canonical) in [
            ("baseline", include_str!("testdata/scoped_byte_copy_no_defer_producer.canonical")),
            ("native inline", include_str!("testdata/scoped_mutations/native_inline_dispatch.canonical")),
            ("cleanup inline", include_str!("testdata/scoped_mutations/cleanup_inline_dispatch.canonical")),
            ("missing cleanup", include_str!("testdata/scoped_mutations/missing_success_cleanup.canonical")),
        ] {
            let error = crate::full_program::parse(canonical)
                .err().unwrap_or_else(|| panic!("{name}: legacy candidate ACCEPTED"));
            println!("{name}: legacy candidate REJECTED: {error}");
        }
    }

    #[test]
    fn current_intrinsic_scope_rejects_shared_native_call_before_recursive_walks() {
        let baseline = include_str!(
            "testdata/scoped_byte_copy_intrinsic_four_arg_producer.canonical");
        let program = crate::full_program::parse(baseline)
            .expect("actual eight-operation scoped source must pass");
        let candidate = program.functions.iter().find_map(|function|
            function.scoped_byte_copy.as_ref()).expect("scoped target");
        let block = program.nodes[candidate.scope].children[0];
        let prefix = format!("node: {block}|");
        let row = baseline.lines().find(|line| line.starts_with(&prefix)).unwrap();
        assert_eq!(baseline.matches(row).count(), 1);
        let mut fields: Vec<_> = row.split('|').map(str::to_owned).collect();
        let count: usize = fields[11].parse().expect("block child count");
        assert_eq!(fields.len(), 12 + count);
        let native = candidate.native_result_declaration.to_string();
        let position = fields[12..].iter().position(|index| index == &native)
            .expect("native result is an actual direct scope child");
        fields.insert(12 + position, native);
        fields[11] = (count + 1).to_string();
        let shared = baseline.replacen(row, &fields.join("|"), 1);
        assert_ne!(shared, baseline);
        let error = crate::full_program::parse(&shared).unwrap_err().to_string();
        assert!(error.contains("deep or shared canonical body"),
            "shared native occurrence refused at a different stage: {error}");
    }
}
