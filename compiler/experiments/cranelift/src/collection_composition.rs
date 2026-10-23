//! Bounded lexical continuation of an already proved ticket publication.
use super::{address_of_local, call_actuals, invalid, scoped_formals, DirectCallFacts,
    PublishedInput, Storage, WorkBudget};
use crate::full_program::Program;
use std::collections::{HashMap, HashSet};
use std::error::Error;

// A nested success may make one further proved scoped call and finish with an
// exhaustive match. There are no assignments, allocation, arbitrary calls or
// cleanup in this continuation. Each recursion receives lexical copies, so a
// shadowing binding cannot inherit an outer local's provenance.
pub(super) struct CompositionContext<'a> {
    pub(super) program: &'a Program,
    pub(super) scoped: &'a HashMap<String, (usize, bool)>,
    pub(super) results: &'a HashMap<usize, &'a crate::ticket_result::TicketResult>,
    pub(super) facts: &'a DirectCallFacts,
    pub(super) arenas: &'a HashSet<String>,
    pub(super) storages: &'a HashMap<String, Storage>,
}

pub(super) fn check_ticket_match(context: &CompositionContext<'_>, index: usize,
    contract: &crate::ticket_result::TicketResult, result: &str, arena: &str,
    immutable: &HashMap<String, String>, published: &HashMap<String, PublishedInput>,
    allowed: &mut HashSet<usize>, budget: &mut WorkBudget, depth: usize,
) -> Result<(), Box<dyn Error>> {
    if depth >= 64 { return Err(invalid("ticket composition depth exceeds proof budget")); }
    budget.charge(immutable.len() + published.len() + context.arenas.len() + context.storages.len() + 1)?;
    let program = context.program;
    let mut continuation = |use_: crate::ticket_result_use::PublishedUse<'_>,
        allowed: &mut HashSet<usize>| -> Result<usize, Box<dyn Error>> {
        if use_.tail.len() != 2 {
            return Err(invalid("ticket success use has extra effects"));
        }
        let declaration = &program.nodes[use_.tail[0]];
        if declaration.kind != "LocalDeclare" || declaration.children.len() != 1 ||
            declaration.text.is_empty() ||
            [use_.binding, use_.copied, use_.bytes, arena].contains(&declaration.text.as_str()) {
            return Err(invalid("ticket continuation does not bind one fresh result"));
        }
        let mut arenas = context.arenas.clone();
        let mut storages = context.storages.clone();
        let mut scalars = immutable.clone();
        let mut inputs = published.clone();
        for name in [use_.binding, use_.copied, use_.bytes, declaration.text.as_str()] {
            arenas.remove(name); storages.remove(name); scalars.remove(name); inputs.remove(name);
        }
        if !arenas.contains(arena) { return Err(invalid("ticket continuation shadows its live Arena")); }
        if use_.reference_type != format!("Reference({}, None)", contract.output_type) {
            return Err(invalid("ticket continuation changes published reference type"));
        }
        inputs.insert(use_.bytes.to_owned(), PublishedInput {
            ty: contract.output_type.clone(), arena: arena.to_owned() });
        let call = &program.nodes[declaration.children[0]];
        let (target_index, shared_brand) = context.scoped.get(&call.second_text)
            .ok_or_else(|| invalid("ticket continuation calls an unproved producer"))?;
        let next = context.results.get(target_index)
            .ok_or_else(|| invalid("ticket continuation loses its tagged result"))?;
        if declaration.ty != next.result_type {
            return Err(invalid("ticket continuation changes result type"));
        }
        let target = &program.functions[*target_index];
        call_actuals(program, call, target, &arenas, &storages, &scalars,
            context.facts, *shared_brand, &inputs, budget)?;
        let (position, _) = scoped_formals(program, target)?;
        let next_arena = address_of_local(program, call.children[position + 1], "Arena")
            .ok_or_else(|| invalid("ticket continuation loses output Arena"))?;
        let nested = CompositionContext { program, scoped: context.scoped,
            results: context.results, facts: context.facts, arenas: &arenas, storages: &storages };
        check_ticket_match(&nested, use_.tail[1], next, &declaration.text,
            &next_arena, &scalars, &inputs, allowed, budget, depth + 1)?;
        Ok(1)
    };
    let count = crate::ticket_result_use::validate(program, index, contract, result,
        arena, immutable, allowed, &mut continuation)?;
    budget.charge(count)
}
