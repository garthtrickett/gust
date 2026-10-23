use crate::full_program::{self, Node, Program};

const SOURCE: &str = include_str!("testdata/scoped_ticket_publication_producer.canonical");
const COMPOSITION: &str = include_str!("testdata/scoped_ticket_composition_producer.canonical");

fn within(program: &Program, name: &str, predicate: impl Fn(&Node) -> bool) -> usize {
    let function = program.functions.iter().find(|function| function.source_name == name).unwrap();
    let mut stack = vec![function.body_node.unwrap()];
    while let Some(index) = stack.pop() {
        if predicate(&program.nodes[index]) { return index; }
        stack.extend(program.nodes[index].children.iter().rev().copied());
    }
    panic!("source mechanism absent in {name}");
}

fn hex(value: &str) -> String {
    value.as_bytes().iter().map(|byte| format!("{byte:02x}")).collect()
}

fn rejected(change: impl FnOnce(&mut Program), expected: &str) {
    rejected_from(SOURCE, change, expected)
}

fn rejected_from(source: &str, change: impl FnOnce(&mut Program), expected: &str) {
    let mut program = full_program::parse(source).expect("actual source baseline must parse");
    change(&mut program);
    let changed = source.lines().map(|line| {
        let Some(tail) = line.strip_prefix("node: ") else { return line.to_owned(); };
        let index: usize = tail.split('|').next().unwrap().parse().unwrap();
        let node = &program.nodes[index];
        let mut fields: Vec<String> = line.split('|').map(str::to_owned).collect();
        let old_count: usize = fields[11].parse().unwrap();
        let metadata = fields[12 + old_count..].to_vec();
        fields.truncate(12);
        fields[1] = hex(&node.kind); fields[2] = hex(&node.ty);
        fields[3] = hex(&node.text); fields[4] = hex(&node.second_text);
        fields[5] = node.integer.to_string(); fields[6] = node.second_integer.to_string();
        fields[11] = node.children.len().to_string();
        fields.extend(node.children.iter().map(usize::to_string));
        fields.extend(metadata);
        if let Some(plan) = &node.collection_intrinsic {
            let start = fields.iter().position(|field| field == "collection_intrinsic.v1").unwrap();
            for (offset, value) in [&plan.opcode, &plan.receiver_type, &plan.element_type,
                &plan.layout_id, &plan.brand].into_iter().enumerate() {
                fields[start + offset + 1] = hex(value);
            }
        }
        fields.join("|")
    }).collect::<Vec<_>>().join("\n") + "\n";
    assert_ne!(changed, source, "mutation must move the source-produced mechanism");
    match full_program::parse(&changed) {
        Ok(_) => panic!("ACCEPTED hostile ticket mutation: {expected}"),
        Err(error) => assert!(error.to_string().contains(expected),
            "REJECTED (different assertion): {error}; expected {expected}"),
    }
}

#[test]
fn ticket_read_uses_formal_brand_substitution_and_exact_receiver() {
    let content = include_str!("testdata/scoped_ticket_content_producer.canonical");
    rejected_from(content, |program| {
        let index = within(program, "main", |node| node.collection_intrinsic.as_ref()
            .is_some_and(|plan| plan.opcode == "Read"));
        let plan = program.nodes[index].collection_intrinsic.as_mut().unwrap();
        assert_eq!(plan.brand, "pool");
        assert_eq!(plan.layout_id, "std_Vector_byte_pool");
        plan.brand = "destination".into();
        plan.layout_id = "std_Vector_byte_destination".into();
    }, "ticket byte read changes its published origin");
    rejected_from(content, |program| {
        let index = within(program, "main", |node| node.collection_intrinsic.as_ref()
            .is_some_and(|plan| plan.opcode == "Read"));
        let receiver = program.nodes[index].children[0];
        assert_eq!(program.nodes[receiver].text, "bytes");
        program.nodes[receiver].text = "input".into();
    }, "ticket byte read changes its published origin");
}

#[test]
fn ticket_source_program_has_complete_proof() {
    let program = full_program::parse(SOURCE).unwrap();
    let proofs = crate::scoped_byte_copy::validate(&program).unwrap();
    assert_eq!(proofs.len(), 1);
    assert!(proofs.values().next().unwrap().ticket_result.is_some());
}

#[test]
fn ticket_constructors_bind_tag_payload_and_exact_parameter() {
    for function in ["complete_copy", "reject_copy"] {
        rejected(|program| {
            let index = within(program, function, |node| node.kind == "IntegerLiteral");
            assert!(matches!(program.nodes[index].integer, 0 | 1));
            program.nodes[index].integer = 1 - program.nodes[index].integer;
        }, "ticket constructor tag disagrees with payload");
        rejected(|program| {
            let function_row = program.functions.iter().find(|f| f.source_name == function).unwrap();
            let parameter = function_row.parameters[1].0.clone();
            let index = within(program, function, |node| node.kind == "LocalRead" && node.text == parameter);
            program.nodes[index].text = "unbound_payload".into();
        }, "ticket constructor publishes another value or variant");
    }
}

#[test]
fn ticket_constructors_cannot_return_before_initialization() {
    rejected(|program| {
        let index = within(program, "complete_copy", |node| node.kind == "Return");
        let read = program.nodes[index].children[0];
        assert_eq!(program.nodes[read].text, "result");
        program.nodes[read].text = "unbound_result".into();
    }, "ticket constructor does not return its exact local");
}

#[test]
fn ticket_publication_requires_exact_output_and_arena() {
    rejected(|program| {
        let index = within(program, "copy_bytes", |node| node.kind == "Call" && node.text == "pool.Set");
        let output = program.nodes[index].children[2];
        assert_eq!(program.nodes[output].text, "collected");
        program.nodes[output].text = "input".into();
    }, "ticket store does not publish the exact completed output");
    rejected(|program| {
        let index = within(program, "copy_bytes", |node| node.kind == "Call" && node.text == "pool.Set");
        let receiver = program.nodes[program.nodes[index].children[0]].children[0];
        assert_eq!(program.nodes[receiver].text, "pool");
        program.nodes[receiver].text = "other_pool".into();
    }, "ticket publication uses another Arena receiver");
    rejected(|program| {
        let index = within(program, "copy_bytes", |node| node.kind == "Call" && node.second_text == "complete_copy");
        let ticket = program.nodes[index].children[2];
        assert_eq!(program.nodes[ticket].text, "handle");
        program.nodes[ticket].text = "old_ticket".into();
    }, "ticket success does not use the completed published ticket");
}

#[test]
fn ticket_normal_and_error_cleanup_are_not_interchangeable() {
    rejected(|program| {
        let index = within(program, "copy_bytes", |node| node.kind == "ScopeCleanup");
        assert_eq!(program.nodes[index].children.len(), 1);
        program.nodes[index].children.clear();
    }, "full-program operation ScopeCleanup has invalid arity 0");
    rejected(|program| {
        let index = within(program, "copy_bytes", |node| node.kind == "Return" && node.children.len() == 2);
        program.nodes[index].children.pop();
    }, "scoped ordinary exit lacks one exact owner cleanup");
}

#[test]
fn ticket_caller_must_use_its_exact_index_and_live_arena() {
    rejected(|program| {
        let index = within(program, "main", |node| node.kind == "Call" && node.text == "destination.get_ref");
        let receiver = program.nodes[program.nodes[index].children[0]].children[0];
        assert_eq!(program.nodes[receiver].text, "destination");
        program.nodes[receiver].text = "other_pool".into();
    }, "ticket output access changes its live Arena");
    rejected(|program| {
        let index = within(program, "main", |node| node.kind == "Dereference" && node.ty.starts_with("Index("));
        let binding = program.nodes[index].children[0];
        assert_eq!(program.nodes[binding].text, "handle");
        program.nodes[binding].text = "other_handle".into();
    }, "ticket match does not copy its exact bound Index");
    rejected(|program| {
        let index = within(program, "main", |node| node.kind == "LocalDeclare" && node.text == "copied");
        program.nodes[index].text = "destination".into();
    }, "ticket match copy is not fresh");
}

#[test]
fn ticket_caller_return_evaluates_before_arena_cleanup() {
    rejected(|program| {
        let index = within(program, "main", |node| node.kind == "Return");
        assert_eq!(program.nodes[index].integer, 1);
        program.nodes[index].integer = 0;
    }, "ticket success does not evaluate before caller cleanup");
    rejected(|program| {
        let index = within(program, "main", |node| node.kind == "EnumMatchArm");
        program.nodes[index].integer = 1 - program.nodes[index].integer;
    }, "ticket match is not exact and exhaustive");
}

#[test]
fn source_produced_composition_has_two_scoped_producers() {
    let program = full_program::parse(COMPOSITION).expect("source-produced nested baseline");
    let proofs = crate::scoped_byte_copy::validate(&program).unwrap();
    assert_eq!(proofs.len(), 2);
    assert!(proofs.values().all(|proof| proof.ticket_result.is_some()));
}

#[test]
fn normalized_failure_still_has_bounded_pure_payload_and_actual_status() {
    rejected_from(COMPOSITION, |program| {
        let index = within(program, "classify_failure", |node| node.kind == "BinaryOperation");
        assert_eq!(program.nodes[index].text, "-");
        program.nodes[index].text = "*".into();
    }, "ticket constructor publishes another value or variant");
    rejected_from(COMPOSITION, |program| {
        let index = within(program, "copy_bytes", |node| node.kind == "Call" &&
            node.text == "classify_failure");
        let status = program.nodes[index].children[2];
        assert_eq!(program.nodes[status].text, "status");
        program.nodes[status].text = "input_count".into();
    }, "scoped failed Guard has an effectful or unrelated return");
}

#[test]
fn composed_input_reference_requires_its_exact_publication() {
    rejected_from(COMPOSITION, |program| {
        let index = within(program, "main", |node| node.kind == "Call" &&
            node.text == "restore_bytes");
        let input = program.nodes[index].children[2];
        assert_eq!(program.nodes[input].text, "bytes");
        program.nodes[input].text = "input".into();
    }, "collection input actual is not a direct borrow");
    rejected_from(COMPOSITION, |program| {
        let index = within(program, "main", |node| node.kind == "Call" &&
            node.text == "destination.get_ref" &&
            program.nodes[node.children[1]].text == "decoded");
        let receiver = program.nodes[program.nodes[index].children[0]].children[0];
        program.nodes[receiver].text = "other_arena".into();
    }, "ticket output access changes its live Arena");
}
