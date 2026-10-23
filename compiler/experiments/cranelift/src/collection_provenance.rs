//! Closed caller provenance for the executable collection intrinsic cohort.
//! A typed layout or an untrusted scoped candidate does not establish live
//! backing storage. This module checks actual Create/Append histories and the
//! direct actual-to-formal substitution for every scoped callsite.

use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::io::{Error as IoError, ErrorKind};

use crate::full_program::{inline_call_name, is_inline_call,
    CollectionIntrinsicPlan, Function, Node, Program, ScopedBinding};
use crate::scoped_byte_copy::ScopedProof;

fn invalid(message: &str) -> Box<dyn Error> {
    Box::new(IoError::new(ErrorKind::InvalidData, message.to_owned()))
}

fn child<'a>(program: &'a Program, node: &Node, position: usize) -> Option<&'a Node> {
    node.children.get(position).and_then(|index| program.nodes.get(*index))
}

fn pure_scalar(program: &Program, index: usize,
    immutable: &HashMap<String, String>) -> bool {
    let Some(node) = program.nodes.get(index) else { return false; };
    match node.kind.as_str() {
        "IntegerLiteral" | "BooleanLiteral" => node.children.is_empty() &&
            matches!(node.ty.as_str(), "Int" | "Byte" | "Bool"),
        "LocalRead" => node.children.is_empty() &&
            immutable.get(&node.text).is_some_and(|ty| ty == &node.ty) &&
            matches!(node.ty.as_str(), "Int" | "Byte" | "Bool"),
        "ExplicitCast" => node.children.len() == 1 &&
            matches!(node.ty.as_str(), "Int" | "Byte" | "Bool") &&
            pure_scalar(program, node.children[0], immutable),
        "BinaryOperation" => node.ty == "Int" && node.children.len() == 2 &&
            matches!(node.text.as_str(), "+" | "-") &&
            pure_scalar(program, node.children[0], immutable) &&
            pure_scalar(program, node.children[1], immutable),
        _ => false,
    }
}

// The ordinary lowerer dispatches this exact zero-argument shape to
// os_Arena_New. It is an actual executable allocation, not a name on a value
// typed Arena. The pure module leaf cannot carry an effectful receiver.
fn arena_new(program: &Program, index: usize) -> bool {
    let Some(call) = program.nodes.get(index) else { return false; };
    if call.kind != "Call" || call.ty != "Arena" || call.children.len() != 1 ||
        call.second_integer != 0 || inline_call_name(program, call).as_deref() != Some("New") {
        return false;
    }
    let Some(method) = child(program, call, 0) else { return false; };
    let Some(namespace) = child(program, method, 0) else { return false; };
    let Some(module) = child(program, namespace, 0) else { return false; };
    method.kind == "FieldOrMethodSelect" && method.text == "New" &&
        method.ty == "Void" && method.children.len() == 1 &&
        namespace.kind == "FieldOrMethodSelect" && namespace.text == "Arena" &&
        namespace.ty == "Void" && namespace.children.len() == 1 &&
        module.kind == "LocalRead" && module.ty == "Void" &&
        !module.text.is_empty() && module.children.is_empty()
}

// This registration executes at the enclosing flat body's exit, after its
// Return value (and any scoped call within that value) has been evaluated.
// Nested scopes, an ordinary Free call, or an early ScopeCleanup are rejected.
fn deferred_arena_free(program: &Program, index: usize) -> Option<String> {
    let schedule = program.nodes.get(index)?;
    if schedule.kind != "ScheduleDefer" || schedule.children.len() != 1 { return None; }
    let call = child(program, schedule, 0)?;
    let method = child(program, call, 0)?;
    let receiver = child(program, method, 0)?;
    if call.kind != "Call" || call.ty != "Void" || call.second_integer != 0 ||
        call.children.len() != 1 ||
        inline_call_name(program, call).as_deref() != Some("Free") ||
        method.kind != "FieldOrMethodSelect" || method.text != "Free" ||
        method.ty != "Void" || method.children.len() != 1 ||
        receiver.kind != "LocalRead" || receiver.ty != "Arena" ||
        receiver.text.is_empty() || !receiver.children.is_empty() ||
        call.text != format!("{}.Free", receiver.text) ||
        call.second_text != call.text {
        return None;
    }
    Some(receiver.text.clone())
}

fn direct_call(program: &Program, call: &Node, target: &Function,
    facts: &DirectCallFacts) -> bool {
    if target.is_extern || call.kind != "Call" ||
        call.second_text != target.qualified_name ||
        call.ty != target.result_type ||
        call.children.len() != target.parameters.len() + 1 ||
        call.second_integer != 0 || is_inline_call(program, call) {
        return false;
    }
    let Some(callee) = child(program, call, 0) else { return false; };
    // Imported direct aliases remain valid. An effectful method receiver or
    // an inline selector cannot masquerade as this defined local function.
    if callee.kind == "LocalRead" {
        return callee.ty == "Void" && callee.children.is_empty() &&
            !callee.text.is_empty() && callee.text == call.text;
    }
    let Some(module) = child(program, callee, 0) else { return false; };
    callee.kind == "FieldOrMethodSelect" && callee.ty == "Void" &&
        callee.children.len() == 1 && !callee.text.is_empty() &&
        module.kind == "LocalRead" && module.ty == "Void" &&
        module.children.is_empty() && !module.text.is_empty() &&
        call.text == format!("{}.{}", module.text, callee.text) &&
        !facts.shadowed_module_names.contains(&module.text)
}

fn address_of_local(program: &Program, index: usize, ty: &str) -> Option<String> {
    let address = program.nodes.get(index)?;
    let value = child(program, address, 0)?;
    if address.kind != "AddressOf" || address.children.len() != 1 ||
        address.ty != format!("Reference({ty}, None)") ||
        value.kind != "LocalRead" || value.ty != ty ||
        value.children.len() != 0 || value.text.is_empty() {
        return None;
    }
    Some(value.text.clone())
}

fn operation<'a>(program: &'a Program, index: usize, opcode: &str)
    -> Result<(&'a Node, &'a CollectionIntrinsicPlan), Box<dyn Error>> {
    let node = program.nodes.get(index).ok_or_else(|| invalid(
        "collection history operation index is out of bounds"))?;
    let plan = node.collection_intrinsic.as_ref().ok_or_else(|| invalid(
        "collection history lacks its executable operation"))?;
    if node.kind != "CollectionIntrinsic" || plan.opcode != opcode ||
        plan.element_type != "Byte" {
        return Err(invalid("collection history operation or element disagrees"));
    }
    Ok((node, plan))
}

#[derive(Clone)]
struct Storage {
    arena: String,
    ty: String,
    layout: String,
    brand: String,
    count: usize,
}

// The global new-cohort body walk bounds graph size and depth. This separate
// budget bounds work spent resolving direct calls and substituting actuals;
// neither a large parameter list nor many imported aliases may multiply the
// graph bound without limit.
struct WorkBudget {
    remaining: usize,
}

impl WorkBudget {
    fn new() -> Self { Self { remaining: 1_000_000 } }

    fn charge(&mut self, amount: usize) -> Result<(), Box<dyn Error>> {
        self.remaining = self.remaining.checked_sub(amount).ok_or_else(|| invalid(
            "collection caller proof work budget exceeded"))?;
        Ok(())
    }
}

struct DirectCallFacts {
    shadowed_module_names: HashSet<String>,
}

impl DirectCallFacts {
    fn new(program: &Program, budget: &mut WorkBudget) -> Result<Self, Box<dyn Error>> {
        let mut shadowed_module_names = HashSet::new();
        for function in &program.functions {
            budget.charge(function.parameters.len())?;
            for (name, _) in &function.parameters {
                shadowed_module_names.insert(name.clone());
            }
        }
        budget.charge(program.nodes.len())?;
        for node in &program.nodes {
            if node.kind == "LocalDeclare" {
                shadowed_module_names.insert(node.text.clone());
            }
        }
        Ok(Self { shadowed_module_names })
    }
}

fn scoped_formals(program: &Program, function: &Function)
    -> Result<(usize, Option<usize>), Box<dyn Error>> {
    let candidate = function.scoped_byte_copy.as_ref().ok_or_else(|| invalid(
        "collection caller target lacks its scoped candidate"))?;
    let output_index = match candidate.output_backing.binding {
        ScopedBinding::Local(index) => index,
        ScopedBinding::Parameter(_) => return Err(invalid(
            "collection caller target has a shared output")),
    };
    let declaration = program.nodes.get(output_index).ok_or_else(|| invalid(
        "collection output declaration is absent"))?;
    let create_index = *declaration.children.first().ok_or_else(|| invalid(
        "collection output lacks Create"))?;
    let (create, _) = operation(program, create_index, "Create")?;
    let arena = child(program, create, 0).ok_or_else(|| invalid(
        "collection output Create lacks an Arena actual"))?;
    let arena_position = function.parameters.iter().position(|(name, ty)|
        arena.kind == "LocalRead" && arena.text == *name && arena.ty == *ty &&
        arena.children.is_empty() && ty.starts_with("Reference(Arena,"))
        .ok_or_else(|| invalid("collection output Arena formal is unbound"))?;
    let input_position = match candidate.input_backing.binding {
        ScopedBinding::Parameter(index) => Some(index),
        ScopedBinding::Local(_) => None,
    };
    if input_position.is_some_and(|index| index >= function.parameters.len() ||
        index == arena_position) {
        return Err(invalid("collection input formal is ambiguous"));
    }
    Ok((arena_position, input_position))
}

fn call_actuals(program: &Program, call: &Node, target: &Function,
    arenas: &HashSet<String>, storages: &HashMap<String, Storage>,
    immutable: &HashMap<String, String>, facts: &DirectCallFacts,
    shared_formal_brand: bool, budget: &mut WorkBudget)
    -> Result<(), Box<dyn Error>> {
    budget.charge(target.parameters.len() + 1)?;
    if !direct_call(program, call, target, facts) {
        return Err(invalid("collection caller has an alternate scoped dispatch"));
    }
    let (arena_position, input_position) = scoped_formals(program, target)?;
    let arena_actual = address_of_local(program, call.children[arena_position + 1], "Arena")
        .ok_or_else(|| invalid("collection caller has no actual Arena reference"))?;
    if !arenas.contains(&arena_actual) {
        return Err(invalid("collection caller Arena is not live"));
    }
    for (position, (_, ty)) in target.parameters.iter().enumerate() {
        let actual_index = call.children[position + 1];
        if program.nodes[actual_index].ty != *ty {
            return Err(invalid("collection caller actual/formal types disagree"));
        }
        if position == arena_position { continue; }
        if Some(position) == input_position {
            let value_ty = ty.strip_prefix("Reference(")
                .and_then(|tail| tail.strip_suffix(", None)"))
                .ok_or_else(|| invalid("collection input formal is not a borrow"))?;
            let storage_name = address_of_local(program, actual_index, value_ty)
                .ok_or_else(|| invalid("collection input actual is not a direct borrow"))?;
            let storage = storages.get(&storage_name).ok_or_else(|| invalid(
                "collection input has no executable Create history"))?;
            // The input borrow carries its own proven Create history. The
            // explicit Arena actual above owns fresh output storage; it need
            // not be the Arena that owns the borrowed input. Both must stay
            // live through this call, and erased-layout congruence was
            // checked when this same Program was parsed.
            if storage.ty != value_ty || !arenas.contains(&storage.arena) {
                return Err(invalid("collection input has no live created backing"));
            }
            // One formal brand is one substitution in the existing source
            // call rule. Distinct live Arenas are admissible only when the
            // checked input Read and output Create carry distinct formal
            // brands; physical storage liveness is proven independently.
            if shared_formal_brand && storage.arena != arena_actual {
                return Err(invalid("collection shared formal brand changes Arena actual"));
            }
            continue;
        }
        if !pure_scalar(program, actual_index, immutable) {
            return Err(invalid("collection caller has an effectful scalar actual"));
        }
    }
    Ok(())
}

fn check_caller(program: &Program, caller: &Function,
    scoped: &HashMap<String, (usize, bool)>, allowed: &mut HashSet<usize>,
    results: &HashMap<usize, &crate::ticket_result::TicketResult>,
    facts: &DirectCallFacts, budget: &mut WorkBudget)
    -> Result<usize, Box<dyn Error>> {
    if caller.is_extern || !caller.parameters.is_empty() {
        return Err(invalid("collection caller is not a closed local constructor"));
    }
    let root = caller.body_node.ok_or_else(|| invalid(
        "collection caller has no body"))?;
    let body = &program.nodes[root];
    if body.kind != "Block" || body.children.is_empty() {
        return Err(invalid("collection caller has no flat body"));
    }
    let mut declared = HashSet::new();
    let mut arenas = HashSet::new();
    let mut deferred = HashSet::new();
    let mut storages: HashMap<String, Storage> = HashMap::new();
    let mut immutable = HashMap::new();
    let mut tagged = HashMap::new();
    let mut calls = 0usize;
    let mut returned = false;
    for (position, index) in body.children.iter().enumerate() {
        budget.charge(1)?;
        let statement = &program.nodes[*index];
        if returned { return Err(invalid("collection caller has a step after Return")); }
        match statement.kind.as_str() {
            "LocalDeclare" if statement.children.len() == 1 &&
                !statement.text.is_empty() && declared.insert(statement.text.clone()) => {
                let value = statement.children[0];
                if statement.ty == "Arena" && arena_new(program, value) {
                    arenas.insert(statement.text.clone());
                    continue;
                }
                if statement.ty.starts_with("Struct(\"") &&
                    program.nodes[value].kind == "CollectionIntrinsic" {
                    let (create, plan) = operation(program, value, "Create")?;
                    let arena = address_of_local(program, create.children[0], "Arena")
                        .ok_or_else(|| invalid("collection Create lacks live Arena origin"))?;
                    if !arenas.contains(&arena) || plan.brand != arena ||
                        statement.ty != create.ty ||
                        statement.ty != plan.receiver_type || !allowed.insert(value) {
                        return Err(invalid("collection Create aliases or changes its Arena"));
                    }
                    storages.insert(statement.text.clone(), Storage {
                        arena, ty: statement.ty.clone(), layout: plan.layout_id.clone(),
                        brand: plan.brand.clone(), count: 0,
                    });
                    continue;
                }
                if matches!(statement.ty.as_str(), "Int" | "Byte" | "Bool") &&
                    pure_scalar(program, value, &immutable) {
                    immutable.insert(statement.text.clone(), statement.ty.clone());
                    continue;
                }
                if program.nodes[value].kind == "Call" {
                    let call = &program.nodes[value];
                    if let Some((target_index, shared_brand)) = scoped.get(&call.second_text) {
                        if let Some(contract) = results.get(target_index) {
                            if statement.ty != contract.result_type {
                                return Err(invalid("collection caller changes its tagged result type"));
                            }
                            let target = &program.functions[*target_index];
                            call_actuals(program, call, target, &arenas, &storages,
                                &immutable, facts, *shared_brand, budget)?;
                            let (arena_position, _) = scoped_formals(program, target)?;
                            let arena = address_of_local(program, call.children[arena_position + 1], "Arena")
                                .ok_or_else(|| invalid("ticket result loses its actual Arena"))?;
                            tagged.insert(statement.text.clone(), (*contract, arena));
                            calls += 1;
                            continue;
                        }
                    }
                }
                return Err(invalid("collection caller local has an unproved initializer"));
            }
            "ScheduleDefer" => {
                let arena = deferred_arena_free(program, *index).ok_or_else(|| invalid(
                    "collection caller has an unproved deferred effect"))?;
                if !arenas.contains(&arena) || !deferred.insert(arena) {
                    return Err(invalid("collection caller frees an unknown or repeated Arena"));
                }
            }
            "Evaluate" if statement.children.len() == 1 => {
                let expression_index = statement.children[0];
                let expression = &program.nodes[expression_index];
                if expression.kind == "CollectionIntrinsic" {
                    let (append, plan) = operation(program, expression_index, "Append")?;
                    let receiver = &program.nodes[append.children[0]];
                    let storage = storages.get_mut(&receiver.text).ok_or_else(|| invalid(
                        "collection Append has no fresh backing"))?;
                    if receiver.kind != "LocalRead" || !receiver.children.is_empty() ||
                        receiver.ty != storage.ty || plan.receiver_type != storage.ty ||
                        plan.layout_id != storage.layout || plan.brand != storage.brand ||
                        !pure_scalar(program, append.children[1], &immutable) ||
                        !allowed.insert(expression_index) {
                        return Err(invalid("collection Append changes backing or evaluates an effect"));
                    }
                    storage.count = storage.count.checked_add(1).ok_or_else(|| invalid(
                        "collection Append count overflows"))?;
                } else if expression.kind == "Call" {
                    let (target_index, shared_brand) = *scoped.get(&expression.second_text).ok_or_else(|| invalid(
                        "collection caller makes an extra call"))?;
                    call_actuals(program, expression, &program.functions[target_index],
                        &arenas, &storages, &immutable, facts, shared_brand, budget)?;
                    calls += 1;
                } else {
                    return Err(invalid("collection caller has an unproved statement effect"));
                }
            }
            "EnumMatch" if position + 1 == body.children.len() && caller.result_type == "Int" => {
                let subject = child(program, statement, 0).ok_or_else(|| invalid("ticket match has no subject"))?;
                let (contract, arena) = tagged.get(&subject.text).ok_or_else(|| invalid(
                    "ticket match subject lacks a scoped publication"))?;
                if !arenas.contains(arena) { return Err(invalid("ticket result Arena is not live")); }
                budget.charge(crate::ticket_result_use::validate(program, *index, contract,
                    &subject.text, arena, &immutable, &declared, allowed)?)?;
                returned = true;
            }
            "Return" if statement.children.len() == 1 &&
                position + 1 == body.children.len() => {
                let value = &program.nodes[statement.children[0]];
                if value.kind == "Call" {
                    // The scoped call must be evaluated before the deferred
                    // Arena Free. A Void Return with marker zero treats its
                    // child as cleanup and lowers it after emit_all_defers.
                    if statement.integer != 1 || caller.result_type == "Void" ||
                        value.ty != caller.result_type {
                        return Err(invalid(
                            "collection caller Return does not evaluate before Arena cleanup"));
                    }
                    let (target_index, shared_brand) = *scoped.get(&value.second_text).ok_or_else(|| invalid(
                        "collection caller returns an unknown Call"))?;
                    call_actuals(program, value, &program.functions[target_index],
                        &arenas, &storages, &immutable, facts, shared_brand, budget)?;
                    calls += 1;
                } else if !pure_scalar(program, statement.children[0], &immutable) {
                    return Err(invalid("collection caller returns an unproved value"));
                }
                returned = true;
            }
            _ => return Err(invalid("collection caller has unsupported control or aliasing")),
        }
    }
    if !returned || calls == 0 || arenas.is_empty() || deferred != arenas {
        return Err(invalid("collection caller has no complete live Arena exit"));
    }
    Ok(calls)
}

pub(crate) fn validate(program: &Program, scoped_proofs: &HashMap<usize, ScopedProof>,
    intrinsic_ids: &HashSet<usize>) -> Result<(), Box<dyn Error>> {
    if intrinsic_ids.is_empty() { return Ok(()); }
    let mut budget = WorkBudget::new();
    let facts = DirectCallFacts::new(program, &mut budget)?;
    let mut scoped = HashMap::new();
    let mut results = HashMap::new();
    let mut allowed = HashSet::new();
    for proof in scoped_proofs.values() {
        if let Some(result) = &proof.ticket_result {
            results.insert(proof.function_index, result);
        }
        let target = &program.functions[proof.function_index];
        let shared_brand = proof.input_collection_brand == proof.output_collection_brand;
        if scoped.insert(target.qualified_name.clone(),
            (proof.function_index, shared_brand)).is_some() ||
            proof.collection_operations.is_empty() {
            return Err(invalid("collection scoped proof is duplicate or empty"));
        }
        for index in &proof.collection_operations {
            if !allowed.insert(*index) {
                return Err(invalid("collection scoped proofs share an operation"));
            }
        }
    }
    if scoped.is_empty() { return Err(invalid(
        "collection intrinsic has no scoped activation")); }

    // Linkage::Local for every defined function means the complete Program has
    // all ordinary direct callers. Reject address escape and alternate call
    // routes for the scoped functions before issuing any storage proof.
    let defined: HashMap<&str, usize> = program.functions.iter().enumerate()
        .filter(|(_, function)| !function.is_extern)
        .map(|(index, function)| (function.qualified_name.as_str(), index))
        .collect();
    let mut edges = vec![HashSet::new(); program.functions.len()];
    let mut callers = HashSet::new();
    let mut call_counts: HashMap<String, usize> = scoped.keys()
        .map(|name| (name.clone(), 0)).collect();
    for (function_index, function) in program.functions.iter().enumerate() {
        if function.is_extern { continue; }
        let Some(root) = function.body_node else { continue; };
        let mut stack = vec![root];
        let mut seen = HashSet::new();
        while let Some(index) = stack.pop() {
            budget.charge(1)?;
            if !seen.insert(index) { continue; }
            let node = &program.nodes[index];
            if node.kind == "FunctionAddress" &&
                (scoped.contains_key(&node.text) ||
                 scoped.contains_key(&node.second_text)) {
                return Err(invalid("collection scoped function address escapes"));
            }
            if node.kind == "Call" {
                if let Some(target_index) = defined.get(node.second_text.as_str()) {
                    let target = &program.functions[*target_index];
                    if !direct_call(program, node, target, &facts) {
                        return Err(invalid("collection defined call has alternate dispatch"));
                    }
                    edges[function_index].insert(*target_index);
                }
            }
            if node.kind == "Call" && scoped.contains_key(&node.second_text) {
                let target = &program.functions[scoped[&node.second_text].0];
                if !direct_call(program, node, target, &facts) {
                    return Err(invalid("collection scoped call dispatch is altered"));
                }
                callers.insert(function_index);
                *call_counts.get_mut(&target.qualified_name).ok_or_else(|| invalid(
                    "collection call target has no proof"))? += 1;
            }
            stack.extend(node.children.iter().copied());
        }
    }
    if callers.is_empty() || call_counts.values().any(|count| *count == 0) {
        return Err(invalid(
        "collection scoped function has no direct caller")); }
    // Every scoped caller must be in the closed entry graph. An executable
    // recursive cycle has no finite storage history, even if one path looked
    // like the flat source fixture.
    let mut reachable = HashSet::new();
    let mut pending = vec![program.entry_function];
    while let Some(index) = pending.pop() {
        budget.charge(1)?;
        if reachable.insert(index) {
            pending.extend(edges[index].iter().copied());
        }
    }
    if callers.iter().any(|index| !reachable.contains(index)) ||
        scoped.values().any(|(index, _)| !reachable.contains(index)) {
        return Err(invalid("collection scoped call is outside the entry graph"));
    }
    let mut indegree = HashMap::new();
    for index in &reachable { indegree.insert(*index, 0usize); }
    for index in &reachable {
        budget.charge(edges[*index].len() + 1)?;
        for target in &edges[*index] {
            if reachable.contains(target) {
                *indegree.get_mut(target).ok_or_else(|| invalid(
                    "collection caller graph target disappeared"))? += 1;
            }
        }
    }
    let mut ready: Vec<_> = indegree.iter()
        .filter_map(|(index, count)| (*count == 0).then_some(*index)).collect();
    let mut ordered = 0usize;
    while let Some(index) = ready.pop() {
        budget.charge(edges[index].len() + 1)?;
        ordered += 1;
        for target in &edges[index] {
            if let Some(count) = indegree.get_mut(target) {
                *count -= 1;
                if *count == 0 { ready.push(*target); }
            }
        }
    }
    if ordered != reachable.len() {
        return Err(invalid("collection caller graph is recursive"));
    }
    for index in callers {
        check_caller(program, &program.functions[index], &scoped, &mut allowed,
            &results, &facts, &mut budget)?;
    }
    if allowed != *intrinsic_ids {
        return Err(invalid("collection intrinsic lacks complete caller and scoped coverage"));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    fn changed_node(canonical: &str, index: usize, field: usize, replacement: &str) -> String {
        let prefix = format!("node: {index}|");
        let rows: Vec<_> = canonical.lines().filter(|line| line.starts_with(&prefix)).collect();
        assert_eq!(rows.len(), 1, "the semantic node has one canonical row");
        let row = rows[0];
        let mut fields: Vec<_> = row.split('|').map(str::to_owned).collect();
        assert!(field < fields.len());
        fields[field] = replacement.to_owned();
        let changed = canonical.replacen(row, &fields.join("|"), 1);
        assert_ne!(changed, canonical, "the canonical mechanism must move");
        changed
    }

    fn hex(value: &str) -> String {
        value.as_bytes().iter().map(|byte| format!("{byte:02x}")).collect()
    }

    fn source_caller_body<'a>(canonical: &'a str) ->
        (std::collections::HashMap<usize, Vec<&'a str>>, Vec<usize>) {
        let rows: std::collections::HashMap<usize, Vec<&str>> = canonical.lines()
            .filter_map(|line| {
                let index = line.strip_prefix("node: ")?.split('|').next()?
                    .parse::<usize>().ok()?;
                Some((index, line.split('|').collect()))
            }).collect();
        let entry: usize = canonical.lines().find_map(|line|
            line.strip_prefix("entry_function_index: "))
            .expect("source-produced entry function").parse().unwrap();
        let prefix = format!("function: {entry}|");
        let function: Vec<_> = canonical.lines().find(|line|
            line.starts_with(&prefix)).expect("source-produced caller row")
            .split('|').collect();
        let body: usize = function[7].parse().expect("entry body node");
        let block = rows.get(&body).expect("entry Block row");
        assert_eq!(block[1], hex("Block"));
        let count: usize = block[11].parse().expect("Block child count");
        assert_eq!(block.len(), 12 + count);
        let children = block[12..].iter().map(|index|
            index.parse().expect("Block child node")).collect();
        (rows, children)
    }

    fn inserted_body_child(canonical: &str, body: usize, before: usize,
        child: usize) -> String {
        let prefix = format!("node: {body}|");
        let rows: Vec<_> = canonical.lines().filter(|line| line.starts_with(&prefix)).collect();
        assert_eq!(rows.len(), 1);
        let row = rows[0];
        let mut fields: Vec<_> = row.split('|').map(str::to_owned).collect();
        let count: usize = fields[11].parse().expect("body child count");
        assert_eq!(fields.len(), 12 + count);
        let position = fields[12..].iter().position(|index| index == &before.to_string())
            .expect("meaningful insertion point");
        fields.insert(12 + position, child.to_string());
        fields[11] = (count + 1).to_string();
        let changed = canonical.replacen(row, &fields.join("|"), 1);
        assert_ne!(changed, canonical);
        changed
    }

    fn changed_children(canonical: &str, index: usize, children: &[usize]) -> String {
        let prefix = format!("node: {index}|");
        let rows: Vec<_> = canonical.lines().filter(|line| line.starts_with(&prefix)).collect();
        assert_eq!(rows.len(), 1);
        let row = rows[0];
        let mut fields: Vec<_> = row.split('|').take(12).map(str::to_owned).collect();
        assert_eq!(fields.len(), 12);
        fields[11] = children.len().to_string();
        fields.extend(children.iter().map(ToString::to_string));
        let changed = canonical.replacen(row, &fields.join("|"), 1);
        assert_ne!(changed, canonical);
        changed
    }

    #[test]
    fn actual_source_produced_intrinsic_caller_has_closed_history() {
        let canonical = include_str!(
            "testdata/scoped_byte_copy_intrinsic_caller_five_arg_producer.canonical");
        let program = crate::full_program::parse(canonical)
            .expect("actual typed producer and caller history must parse");
        assert_eq!(program.functions.iter().filter(|function|
            function.scoped_byte_copy.is_some()).count(), 1);
        let mut operations = std::collections::HashMap::new();
        for node in &program.nodes {
            if let Some(plan) = &node.collection_intrinsic {
                assert_eq!(node.kind, "CollectionIntrinsic");
                *operations.entry(plan.opcode.as_str()).or_insert(0usize) += 1;
            }
        }
        assert_eq!(operations, std::collections::HashMap::from([
            ("Create", 2), ("Append", 4), ("Clear", 1), ("Read", 1)]));
    }

    #[test]
    fn caller_return_evaluates_scoped_call_before_deferred_arena_free() {
        let canonical = include_str!(
            "testdata/scoped_byte_copy_intrinsic_caller_five_arg_producer.canonical");
        let program = crate::full_program::parse(canonical)
            .expect("actual caller baseline");
        let caller = &program.functions[program.entry_function];
        let body = &program.nodes[caller.body_node.expect("caller body")];
        assert_eq!(body.kind, "Block");
        let return_index = *body.children.last().expect("final Return");
        let terminal = &program.nodes[return_index];
        assert_eq!(terminal.kind, "Return");
        assert_eq!(terminal.integer, 1);
        assert_eq!(terminal.children.len(), 1);
        assert_eq!(program.nodes[terminal.children[0]].kind, "Call");
        assert_eq!(caller.result_type, "Int");

        let zero_marker = changed_node(canonical, return_index, 5, "0");
        let prefix = format!("function: {}|", program.entry_function);
        let row = canonical.lines().find(|line| line.starts_with(&prefix))
            .expect("actual caller function row");
        assert_eq!(canonical.matches(row).count(), 1);
        let mut fields: Vec<_> = row.split('|').map(str::to_owned).collect();
        assert_eq!(fields[6], hex("Int"));
        fields[6] = hex("Void");
        let void_result = canonical.replacen(row, &fields.join("|"), 1);
        assert_ne!(void_result, canonical);
        let void_zero_marker = zero_marker.replacen(row, &fields.join("|"), 1);
        assert_ne!(void_zero_marker, zero_marker);
        for (name, mutant) in [
            ("Void zero-marker caller", void_zero_marker),
            ("zero marker", zero_marker),
            ("Void caller", void_result),
        ] {
            let error = crate::full_program::parse(&mutant)
                .expect_err("deferred Free could precede scoped Call")
                .to_string();
            assert!(error.contains(
                "collection caller Return does not evaluate before Arena cleanup"),
                "{name}: different rejection authority: {error}");
            println!("{name}: REJECTED expected assertion: {error}");
        }
    }

    #[test]
    fn source_produced_caller_metadata_write_and_copy_alias_refuse_at_provenance() {
        let forged = include_str!(
            "testdata/scoped_byte_copy_intrinsic_forged_len_producer.canonical");
        let (rows, body) = source_caller_body(forged);
        let writes: Vec<_> = body.iter().filter_map(|index| {
            let row = rows.get(index)?;
            (row[1] == hex("Assign") && row[11] == "2").then_some(row)
        }).filter(|row| {
            let left = rows.get(&row[12].parse::<usize>().unwrap()).unwrap();
            if left[1] != hex("FieldOrMethodSelect") ||
                left[3] != hex("len") || left[11] != "1" { return false; }
            let receiver = rows.get(&left[12].parse::<usize>().unwrap()).unwrap();
            receiver[1] == hex("LocalRead") && receiver[3] == hex("input")
        }).collect();
        assert_eq!(writes.len(), 1, "source must actually write input.len");
        let literal = rows.get(&writes[0][13].parse::<usize>().unwrap()).unwrap();
        assert_eq!((literal[1], literal[5]), (hex("IntegerLiteral").as_str(), "3"));
        assert_eq!(forged.matches("collection_intrinsic.v1").count(), 8);
        let error = crate::full_program::parse(forged)
            .expect_err("caller metadata write was admitted").to_string();
        assert!(error.contains("collection caller has unsupported control or aliasing"),
            "metadata write rejected at a different authority: {error}");

        let copied = include_str!(
            "testdata/scoped_byte_copy_intrinsic_copied_alias_producer.canonical");
        let (rows, body) = source_caller_body(copied);
        let aliases: Vec<_> = body.iter().enumerate().filter_map(|(position, index)| {
            let row = rows.get(index)?;
            (row[1] == hex("LocalDeclare") && row[3] == hex("alias") &&
                row[11] == "1").then_some((position, row))
        }).collect();
        assert_eq!(aliases.len(), 1, "source must actually copy the input value");
        let initial = rows.get(&aliases[0].1[12].parse::<usize>().unwrap()).unwrap();
        assert_eq!((initial[1], initial[3]),
            (hex("LocalRead").as_str(), hex("input").as_str()));
        let alias_append = body.iter().skip(aliases[0].0 + 1).any(|index| {
            let row = rows.get(index).unwrap();
            if row[1] != hex("Evaluate") || row[11] != "1" { return false; }
            let value = rows.get(&row[12].parse::<usize>().unwrap()).unwrap();
            if value[1] != hex("CollectionIntrinsic") ||
                value[11] != "2" ||
                !value.contains(&"collection_intrinsic.v1") ||
                !value.contains(&hex("Append").as_str()) { return false; }
            let receiver = rows.get(&value[12].parse::<usize>().unwrap()).unwrap();
            receiver[1] == hex("LocalRead") && receiver[3] == hex("alias")
        });
        assert!(alias_append, "source must actually append through the copied alias");
        assert_eq!(copied.matches("collection_intrinsic.v1").count(), 9);
        let error = crate::full_program::parse(copied)
            .expect_err("copied collection alias was admitted").to_string();
        assert!(error.contains("collection caller local has an unproved initializer"),
            "copied alias rejected at a different authority: {error}");
    }

    #[test]
    fn two_source_produced_callers_with_different_histories_are_both_checked() {
        let canonical = include_str!(
            "testdata/scoped_byte_copy_intrinsic_two_callers_producer.canonical");
        let program = crate::full_program::parse(canonical)
            .expect("both source-produced caller histories must parse");
        let target = program.functions.iter().find(|function|
            function.scoped_byte_copy.is_some()).expect("one scoped target");
        let arena_position = super::scoped_formals(&program, target)
            .expect("scoped output Arena formal").0;
        let mut callers = Vec::new();
        for function in &program.functions {
            let Some(body_index) = function.body_node else { continue; };
            let body = &program.nodes[body_index];
            if body.kind != "Block" { continue; }
            let calls: Vec<_> = body.children.iter().filter_map(|index| {
                let statement = &program.nodes[*index];
                (statement.kind == "Return" && statement.children.len() == 1)
                    .then(|| statement.children[0])
            }).filter(|index| program.nodes[*index].kind == "Call" &&
                program.nodes[*index].second_text == target.qualified_name).collect();
            if calls.is_empty() { continue; }
            assert_eq!(calls.len(), 1);
            let appends = body.children.iter().filter(|index| {
                let statement = &program.nodes[**index];
                statement.kind == "Evaluate" && statement.children.len() == 1 &&
                    program.nodes[statement.children[0]].collection_intrinsic.as_ref()
                        .is_some_and(|plan| plan.opcode == "Append")
            }).count();
            let call = &program.nodes[calls[0]];
            let address = &program.nodes[call.children[arena_position + 1]];
            assert_eq!(address.kind, "AddressOf");
            let local = address.children[0];
            let name = &program.nodes[local].text;
            assert_eq!(program.nodes[local].ty, "Arena");
            callers.push((appends, local, name.clone()));
        }
        callers.sort_by_key(|(appends, _, _)| *appends);
        assert_eq!(callers.len(), 2);
        assert_eq!((callers[0].0, callers[1].0), (2, 3));
        assert_ne!(callers[0].2, callers[1].2);
        for (which, other) in [(0, 1), (1, 0)] {
            let mutant = changed_node(canonical, callers[which].1, 3,
                &hex(&callers[other].2));
            let error = crate::full_program::parse(&mutant)
                .expect_err("one invalid caller among the two was accepted")
                .to_string();
            assert!(error.contains("collection caller Arena is not live"),
                "caller {which}: different rejection authority: {error}");
            println!("caller {which}: REJECTED expected assertion: {error}");
        }
    }

    #[test]
    fn orphan_executable_operation_has_no_caller_or_scoped_authority() {
        let baseline = include_str!(
            "testdata/scoped_byte_copy_intrinsic_caller_five_arg_producer.canonical");
        let program = crate::full_program::parse(baseline)
            .expect("source-produced caller baseline");
        let source_index = program.nodes.iter().position(|node|
            node.collection_intrinsic.as_ref().is_some_and(|plan|
                plan.opcode == "Create")).expect("actual Create");
        let new_index = program.nodes.len();
        let source_prefix = format!("node: {source_index}|");
        let row = baseline.lines().find(|line|
            line.starts_with(&source_prefix)).expect("Create row");
        assert_eq!(baseline.matches(row).count(), 1);
        let copy = row.replacen(&source_prefix,
            &format!("node: {new_index}|"), 1);
        assert_ne!(copy, *row);
        let mut lines: Vec<String> = baseline.lines().map(str::to_owned).collect();
        let count = lines.iter().position(|line|
            line == &format!("node_count: {new_index}"))
            .expect("actual node count");
        lines[count] = format!("node_count: {}", new_index + 1);
        let entry = lines.iter().position(|line|
            line.starts_with("entry_function_index: "))
            .expect("entry row after all nodes");
        lines.insert(entry, copy);
        let mutant = lines.join("\n") + "\n";
        let error = crate::full_program::parse(&mutant)
            .expect_err("unreachable executable Create was accepted")
            .to_string();
        // Whole-program reachability owns this refusal before caller-history
        // coverage runs; keep the earlier authority explicit.
        assert!(error.contains("collection intrinsic is outside every defined body"),
            "different orphan rejection authority: {error}");
    }

    #[test]
    fn source_produced_recursive_caller_graph_refuses_before_storage_substitution() {
        let canonical = include_str!(
            "testdata/scoped_byte_copy_intrinsic_recursive_caller_producer.canonical");
        let scoped_calls = canonical.lines().filter(|line|
            line.contains("collection_intrinsic.v1")).count();
        assert_eq!(scoped_calls, 12, "recursive source retained executable operations");
        let error = crate::full_program::parse(canonical)
            .expect_err("recursive caller graph was accepted")
            .to_string();
        assert!(error.contains("collection caller graph is recursive"),
            "different recursion rejection authority: {error}");
    }

    #[test]
    fn caller_field_alias_cannot_replace_the_direct_borrow() {
        let canonical = include_str!(
            "testdata/scoped_byte_copy_intrinsic_caller_five_arg_producer.canonical");
        let mut program = crate::full_program::parse(canonical)
            .expect("actual direct-borrow baseline");
        let proofs = crate::scoped_byte_copy::validate(&program)
            .expect("baseline scoped proof");
        let intrinsic_ids = program.nodes.iter().enumerate().filter_map(|(index, node)|
            node.collection_intrinsic.is_some().then_some(index)).collect();
        let target = program.functions.iter().find(|function|
            function.scoped_byte_copy.is_some()).expect("scoped target");
        let input_position = super::scoped_formals(&program, target)
            .expect("borrowed input formal").1.expect("input parameter");
        let entry = &program.functions[program.entry_function];
        let body = &program.nodes[entry.body_node.expect("entry body")];
        let call = body.children.iter().find_map(|index| {
            let statement = &program.nodes[*index];
            let value = statement.children.first().map(|child| &program.nodes[*child])?;
            (statement.kind == "Return" && value.kind == "Call" &&
                value.second_text == target.qualified_name).then_some(value)
        }).expect("direct scoped caller");
        let borrow = &program.nodes[call.children[input_position + 1]];
        assert_eq!(borrow.kind, "AddressOf");
        let value_index = borrow.children[0];
        let value = &program.nodes[value_index];
        assert_eq!(value.kind, "LocalRead");
        let earlier = program.nodes[..value_index].iter().enumerate()
            .find_map(|(index, node)| (node.kind == "LocalRead" &&
                node.ty == value.ty && node.text == value.text &&
                node.children.is_empty()).then_some(index))
            .expect("earlier same typed receiver");
        program.nodes[value_index].kind = "FieldOrMethodSelect".into();
        program.nodes[value_index].text = "data".into();
        program.nodes[value_index].children = vec![earlier];
        let error = super::validate(&program, &proofs, &intrinsic_ids)
            .expect_err("a field projection was treated as the owned input local")
            .to_string();
        assert!(error.contains("collection input actual is not a direct borrow"),
            "different field-alias rejection authority: {error}");
    }

    #[test]
    fn distinct_live_input_and_output_arenas_preserve_closed_history() {
        // Two physically live Arenas do not make a shared formal brand two
        // brands. The first synthetic successor changes only the caller
        // graph, so the source call's one-brand substitution must still deny
        // input A plus output B.
        let same_formal_brand = include_str!(
            "testdata/scoped_byte_copy_intrinsic_distinct_arenas_synthetic.canonical");
        let error = crate::full_program::parse(same_formal_brand)
            .unwrap_err().to_string();
        assert!(error.contains("collection shared formal brand changes Arena actual"),
            "{error}");
        // The second canonical was produced from a typechecked Gust source
        // that gives the borrowed input and explicit output Arena distinct
        // formal brands. The old worker captured it but refused the new
        // executable opcode; this current parser must prove its actual graph.
        let canonical = include_str!(
            "testdata/scoped_byte_copy_intrinsic_distinct_arenas_producer.canonical");
        let program = crate::full_program::parse(canonical)
            .expect("two independently live Arena histories must parse");
        let entry = &program.functions[program.entry_function];
        let body = &program.nodes[entry.body_node.expect("entry body")];
        let arena_names: Vec<_> = body.children.iter().filter_map(|index| {
            let declaration = &program.nodes[*index];
            (declaration.kind == "LocalDeclare" && declaration.ty == "Arena" &&
                declaration.children.len() == 1 &&
                super::arena_new(&program, declaration.children[0]))
                .then_some(declaration.text.as_str())
        }).collect();
        assert_eq!(arena_names.len(), 2);
        assert_ne!(arena_names[0], arena_names[1]);
        let deferred: Vec<_> = body.children.iter().filter_map(|index|
            super::deferred_arena_free(&program, *index)).collect();
        assert_eq!(deferred.len(), 2);
        assert!(arena_names.iter().all(|name| deferred.iter().any(|free| free == name)));
        let input_create = body.children.iter().filter_map(|index| {
            let declaration = &program.nodes[*index];
            let value = declaration.children.first().map(|child| &program.nodes[*child])?;
            (declaration.kind == "LocalDeclare" && value.collection_intrinsic.as_ref()
                .is_some_and(|plan| plan.opcode == "Create"))
                .then_some(value)
        }).collect::<Vec<_>>();
        assert_eq!(input_create.len(), 1);
        let input_arena = super::address_of_local(&program,
            input_create[0].children[0], "Arena").expect("input Create Arena");
        let scoped = program.functions.iter().find(|function|
            function.scoped_byte_copy.is_some()).expect("scoped target");
        let output_actual = body.children.iter().filter_map(|index| {
            let statement = &program.nodes[*index];
            let call = statement.children.first().map(|child| &program.nodes[*child])?;
            (statement.kind == "Return" && call.kind == "Call" &&
                call.second_text == scoped.qualified_name).then_some(call)
        }).collect::<Vec<_>>();
        assert_eq!(output_actual.len(), 1);
        let arena_parameter = super::scoped_formals(&program, scoped)
            .expect("output Arena formal").0;
        let output_arena = super::address_of_local(&program,
            output_actual[0].children[arena_parameter + 1], "Arena")
            .expect("output Arena actual");
        assert_ne!(input_arena, output_arena);
    }

    #[test]
    fn distinct_formal_brands_can_substitute_the_same_live_arena() {
        let canonical = include_str!(
            "testdata/scoped_byte_copy_intrinsic_distinct_formals_same_arena_producer.canonical");
        let program = crate::full_program::parse(canonical)
            .expect("typed source may substitute one live Arena for two formal brands");
        let target = program.functions.iter().find(|function|
            function.scoped_byte_copy.is_some()).expect("scoped target");
        let candidate = target.scoped_byte_copy.as_ref().unwrap();
        let crate::full_program::ScopedBinding::Local(output) =
            candidate.output_backing.binding else { panic!("fresh output local"); };
        let output_create = &program.nodes[program.nodes[output].children[0]];
        let output_brand = &output_create.collection_intrinsic.as_ref()
            .expect("output Create").brand;
        let input_brand = &program.nodes.iter().find_map(|node|
            node.collection_intrinsic.as_ref().filter(|plan|
                plan.opcode == "Read")).expect("borrowed input Read").brand;
        assert_ne!(input_brand, output_brand, "the source has two formal brands");
        let entry = &program.functions[program.entry_function];
        let body = &program.nodes[entry.body_node.expect("entry body")];
        let live_arenas: Vec<_> = body.children.iter().filter_map(|index| {
            let declaration = &program.nodes[*index];
            (declaration.kind == "LocalDeclare" && declaration.ty == "Arena" &&
                declaration.children.len() == 1 &&
                super::arena_new(&program, declaration.children[0]))
                .then_some(declaration.text.as_str())
        }).collect();
        assert_eq!(live_arenas.len(), 1);
        let caller_input = body.children.iter().find_map(|index| {
            let declaration = &program.nodes[*index];
            let create = declaration.children.first().map(|child| &program.nodes[*child])?;
            (declaration.kind == "LocalDeclare" && create.collection_intrinsic.as_ref()
                .is_some_and(|plan| plan.opcode == "Create"))
                .then_some(create)
        }).expect("caller input Create");
        assert_eq!(super::address_of_local(&program, caller_input.children[0], "Arena"),
            Some(live_arenas[0].to_owned()));
        let call = body.children.iter().find_map(|index| {
            let statement = &program.nodes[*index];
            let value = statement.children.first().map(|child| &program.nodes[*child])?;
            (statement.kind == "Return" && value.kind == "Call" &&
                value.second_text == target.qualified_name).then_some(value)
        }).expect("direct scoped call");
        let arena_formal = super::scoped_formals(&program, target)
            .expect("output Arena formal").0;
        assert_eq!(super::address_of_local(&program,
            call.children[arena_formal + 1], "Arena"),
            Some(live_arenas[0].to_owned()));
    }

    #[test]
    fn source_produced_collection_identities_bind_each_operation_and_arena() {
        let canonical = include_str!(
            "testdata/scoped_byte_copy_intrinsic_distinct_arenas_producer.canonical");
        let program = crate::full_program::parse(canonical)
            .expect("source-produced distinct-brand baseline must parse");
        let entry = &program.functions[program.entry_function];
        let body = &program.nodes[entry.body_node.expect("entry body")];
        let caller_create: Vec<_> = body.children.iter().filter_map(|index| {
            let declaration = &program.nodes[*index];
            let child = declaration.children.first().map(|child| &program.nodes[*child])?;
            (declaration.kind == "LocalDeclare" && declaration.children.len() == 1 && child.collection_intrinsic.as_ref()
                .is_some_and(|plan| plan.opcode == "Create"))
                .then(|| declaration.children[0])
        }).collect();
        assert_eq!(caller_create.len(), 1);
        let scoped = program.functions.iter().find(|function|
            function.scoped_byte_copy.is_some()).expect("scoped target");
        let candidate = scoped.scoped_byte_copy.as_ref().unwrap();
        let crate::full_program::ScopedBinding::Local(output_index) =
            candidate.output_backing.binding else { panic!("fresh output binding"); };
        let output_create = program.nodes[output_index].children[0];
        let output_plan = program.nodes[output_create].collection_intrinsic.as_ref()
            .expect("output Create operation");
        let input_read = program.nodes.iter().find_map(|node|
            node.collection_intrinsic.as_ref().filter(|plan|
                plan.opcode == "Read")).expect("input Read operation");
        assert_ne!(input_read.brand, output_plan.brand);
        let output_appends: Vec<_> = program.nodes.iter().enumerate().filter_map(|(index, node)|
            node.collection_intrinsic.as_ref().filter(|plan|
                plan.opcode == "Append" && plan.brand == output_plan.brand)
                .map(|_| index)).collect();
        assert_eq!(output_appends.len(), 2);

        // Both layout and brand are changed to a real, same-physical-layout
        // input record. This keeps each individual operation resolvable and
        // tests cross-operation identity rather than an unknown-layout gate.
        let append = output_appends[0];
        let prefix = format!("node: {append}|");
        let row = canonical.lines().find(|line| line.starts_with(&prefix)).unwrap();
        let arity = row.split('|').count();
        let mut mixed_output = changed_node(canonical, append, arity - 2,
            &hex(&input_read.layout_id));
        mixed_output = changed_node(&mixed_output, append, arity - 1,
            &hex(&input_read.brand));
        let error = crate::full_program::parse(&mixed_output)
            .unwrap_err().to_string();
        assert!(error.contains("scoped output operations change layout or brand"),
            "mixed output identity refused at a different stage: {error}");

        // The caller's Create cannot claim the output formal's brand while
        // its actual storage was allocated from the input Arena.
        let create = caller_create[0];
        let prefix = format!("node: {create}|");
        let row = canonical.lines().find(|line| line.starts_with(&prefix)).unwrap();
        let arity = row.split('|').count();
        let mut wrong_origin = changed_node(canonical, create, arity - 2,
            &hex(&output_plan.layout_id));
        wrong_origin = changed_node(&wrong_origin, create, arity - 1,
            &hex(&output_plan.brand));
        let error = crate::full_program::parse(&wrong_origin)
            .unwrap_err().to_string();
        assert!(error.contains("collection Create aliases or changes its Arena"),
            "forged creating Arena identity refused at a different stage: {error}");
    }

    #[test]
    fn actual_caller_rejects_early_free_and_alternate_callee() {
        let canonical = include_str!(
            "testdata/scoped_byte_copy_intrinsic_caller_five_arg_producer.canonical");
        let program = crate::full_program::parse(canonical)
            .expect("actual caller baseline must parse before mutation");
        let entry = &program.functions[program.entry_function];
        let body = &program.nodes[entry.body_node.expect("entry body")];
        let defers: Vec<_> = body.children.iter().copied().filter(|index|
            program.nodes[*index].kind == "ScheduleDefer").collect();
        assert_eq!(defers.len(), 1);
        let early_free = changed_node(canonical, defers[0], 1, &hex("Evaluate"));
        let error = crate::full_program::parse(&early_free).unwrap_err().to_string();
        assert!(error.contains("collection caller makes an extra call"), "{error}");

        let scoped = program.functions.iter().find(|function|
            function.scoped_byte_copy.is_some()).expect("scoped function");
        let calls: Vec<_> = body.children.iter().filter_map(|index| {
            let statement = &program.nodes[*index];
            (statement.kind == "Return" && statement.children.len() == 1)
                .then(|| statement.children[0])
        }).filter(|index| program.nodes[*index].kind == "Call" &&
            program.nodes[*index].second_text == scoped.qualified_name).collect();
        assert_eq!(calls.len(), 1);
        let callee = program.nodes[calls[0]].children[0];
        assert_eq!(program.nodes[callee].kind, "LocalRead");
        let alternate = changed_node(canonical, callee, 3, &hex("len"));
        let error = crate::full_program::parse(&alternate).unwrap_err().to_string();
        assert!(error.contains("alternate dispatch"), "{error}");
    }

    #[test]
    fn scoped_direct_callee_cannot_switch_to_inline_dispatch() {
        let canonical = include_str!(
            "testdata/scoped_byte_copy_intrinsic_caller_five_arg_producer.canonical");
        let mut baseline = crate::full_program::parse(canonical)
            .expect("actual caller baseline must parse before inline mutation");
        let entry = &baseline.functions[baseline.entry_function];
        let body = &baseline.nodes[entry.body_node.expect("entry body")];
        let target = baseline.functions.iter().find(|function|
            function.scoped_byte_copy.is_some()).expect("scoped target");
        let calls: Vec<_> = body.children.iter().filter_map(|index| {
            let statement = &baseline.nodes[*index];
            (statement.kind == "Return" && statement.children.len() == 1)
                .then(|| statement.children[0])
        }).filter(|index| baseline.nodes[*index].kind == "Call" &&
            baseline.nodes[*index].second_text == target.qualified_name).collect();
        assert_eq!(calls.len(), 1);
        let callee = baseline.nodes[calls[0]].children[0];
        assert_eq!(baseline.nodes[callee].kind, "LocalRead");
        let input_create_lines: Vec<_> = body.children.iter().filter_map(|index| {
            let declaration = &baseline.nodes[*index];
            let value = declaration.children.first().map(|child| &baseline.nodes[*child])?;
            (declaration.kind == "LocalDeclare" && value.collection_intrinsic.as_ref()
                .is_some_and(|plan| plan.opcode == "Create"))
                .then_some(value.source_line)
        }).collect();
        assert_eq!(input_create_lines.len(), 1);
        let pure_orphans: Vec<_> = baseline.nodes.iter().enumerate()
            .filter(|(index, node)| *index < callee && node.kind == "LocalRead" &&
                node.ty == "Void" && node.text == "std" &&
                node.children.is_empty() && node.source_line == input_create_lines[0])
            .map(|(index, _)| index).collect();
        assert_eq!(pure_orphans.len(), 1);
        let module = pure_orphans[0];
        baseline.nodes[callee].kind = "FieldOrMethodSelect".to_owned();
        baseline.nodes[callee].text = "len".to_owned();
        baseline.nodes[callee].children = vec![module];
        assert!(crate::full_program::is_inline_call(&baseline, &baseline.nodes[calls[0]]),
            "the mutant must actually select inline lowering");
        let mut mutant = changed_node(canonical, callee, 1,
            &hex("FieldOrMethodSelect"));
        mutant = changed_node(&mutant, callee, 3, &hex("len"));
        mutant = changed_children(&mutant, callee, &[module]);
        let error = crate::full_program::parse(&mutant).unwrap_err().to_string();
        assert!(error.contains("alternate dispatch"), "{error}");
    }

    #[test]
    fn caller_scalar_read_must_match_its_reaching_declaration_type() {
        let canonical = include_str!(
            "testdata/scoped_byte_copy_intrinsic_caller_five_arg_producer.canonical");
        let program = crate::full_program::parse(canonical)
            .expect("actual caller baseline must parse before type mutation");
        let entry = &program.functions[program.entry_function];
        let body_index = entry.body_node.expect("entry body");
        let body = &program.nodes[body_index];
        let input_declaration = body.children.iter().copied().find(|index| {
            let declaration = &program.nodes[*index];
            declaration.kind == "LocalDeclare" && declaration.children.len() == 1 &&
                program.nodes[declaration.children[0]].collection_intrinsic.as_ref()
                    .is_some_and(|plan| plan.opcode == "Create")
        }).expect("caller input Create declaration");
        let create = &program.nodes[program.nodes[input_declaration].children[0]];
        // The typed producer retained a now-orphaned VectorNew selector. Use
        // that source-positioned node and its module leaf as fresh scalar
        // declaration/value nodes, preserving canonical postorder throughout.
        let choices: Vec<_> = program.nodes.iter().enumerate().filter(|(index, node)|
            node.kind == "FieldOrMethodSelect" && node.text == "VectorNew" &&
            node.source_line == create.source_line &&
            !program.nodes.iter().any(|parent| parent.children.contains(index)))
            .map(|(index, _)| index).collect();
        assert_eq!(choices.len(), 1);
        let declaration_index = choices[0];
        let literal_index = program.nodes[declaration_index].children[0];
        assert_eq!(program.nodes[literal_index].kind, "LocalRead");
        let target = program.functions.iter().find(|function|
            function.scoped_byte_copy.is_some()).expect("scoped target");
        let capacity_index = match target.scoped_byte_copy.as_ref()
            .expect("candidate").output_capacity.binding {
            crate::full_program::ScopedBinding::Parameter(index) => index,
            _ => panic!("source-produced output capacity is a parameter"),
        };
        let return_call = body.children.iter().filter_map(|index| {
            let statement = &program.nodes[*index];
            (statement.kind == "Return" && statement.children.len() == 1)
                .then(|| &program.nodes[statement.children[0]])
        }).find(|call| call.kind == "Call" &&
            call.second_text == target.qualified_name).expect("direct scoped call");
        let actual_index = return_call.children[capacity_index + 1];
        assert_eq!(program.nodes[actual_index].kind, "IntegerLiteral");
        let mut mutant = changed_node(canonical, literal_index, 1, &hex("IntegerLiteral"));
        mutant = changed_node(&mutant, literal_index, 2, &hex("Byte"));
        mutant = changed_node(&mutant, literal_index, 3, "");
        mutant = changed_node(&mutant, literal_index, 5, "8");
        mutant = changed_node(&mutant, declaration_index, 1, &hex("LocalDeclare"));
        mutant = changed_node(&mutant, declaration_index, 2, &hex("Byte"));
        mutant = changed_node(&mutant, declaration_index, 3, &hex("cap"));
        mutant = changed_node(&mutant, actual_index, 1, &hex("LocalRead"));
        mutant = changed_node(&mutant, actual_index, 3, &hex("cap"));
        mutant = changed_node(&mutant, actual_index, 5, "0");
        mutant = inserted_body_child(&mutant, body_index, input_declaration,
            declaration_index);
        let error = crate::full_program::parse(&mutant).unwrap_err().to_string();
        assert!(error.contains("collection caller has an effectful scalar actual"), "{error}");
    }
}
