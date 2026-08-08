use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fs;
use std::io::{Error as IoError, ErrorKind};
use std::path::Path;

#[derive(Clone)]
struct Edge {
    id: String,
    kind: String,
    return_abi: String,
    evaluation: i64,
    cleanup_begin: i64,
    terminator: i64,
    exited_scopes: String,
    return_value: String,
}

#[derive(Clone)]
struct Entry {
    edge_id: String,
    scope_id: String,
    resource_id: String,
    cleanup_id: String,
    destructor_id: String,
    source: String,
    depth: i64,
    declaration: i64,
    order: i64,
    prior_state: String,
    effect: String,
}

fn err(reason: &str, detail: impl Into<String>) -> IoError {
    IoError::new(
        ErrorKind::InvalidData,
        format!("early_return_cleanup_error: reason={reason} detail={}", detail.into()),
    )
}

fn fields(path: &Path) -> Result<HashMap<String, String>, Box<dyn Error>> {
    let mut out = HashMap::new();
    for line in fs::read_to_string(path)?.lines() {
        if let Some((key, value)) = line.split_once(": ") {
            out.insert(key.to_string(), value.to_string());
        }
    }
    Ok(out)
}

fn required(map: &HashMap<String, String>, key: &str) -> Result<String, IoError> {
    map.get(key).cloned().ok_or_else(|| err("early_return_cleanup_metadata_missing", key))
}

fn integer(map: &HashMap<String, String>, key: &str) -> Result<i64, IoError> {
    required(map, key)?.parse().map_err(|_| err("early_return_cleanup_metadata_invalid", key))
}

fn parse(path: &Path) -> Result<(Vec<Edge>, Vec<Entry>), Box<dyn Error>> {
    let map = fields(path)?;
    if required(&map, "early_exit_cleanup_format")? != "gust.compiler_early_exit_cleanup.v1" {
        return Err(err("early_return_cleanup_format_invalid", "format").into());
    }
    let edge_count = integer(&map, "early_exit_cleanup_edge_count")?;
    let entry_count = integer(&map, "early_exit_cleanup_entry_count")?;
    let mut edges = Vec::new();
    for index in 0..edge_count {
        let p = format!("early_exit_cleanup_edge_{index}");
        edges.push(Edge {
            id: required(&map, &format!("{p}_id"))?,
            kind: required(&map, &format!("{p}_kind"))?,
            return_abi: required(&map, &format!("{p}_return_abi"))?,
            evaluation: integer(&map, &format!("{p}_return_evaluation_order"))?,
            cleanup_begin: integer(&map, &format!("{p}_cleanup_begin_order"))?,
            terminator: integer(&map, &format!("{p}_terminator_order"))?,
            exited_scopes: required(&map, &format!("{p}_exited_scope_chain"))?,
            return_value: required(&map, &format!("{p}_return_value_id"))?,
        });
    }
    let mut entries = Vec::new();
    for index in 0..entry_count {
        let p = format!("early_exit_cleanup_entry_{index}");
        entries.push(Entry {
            edge_id: required(&map, &format!("{p}_edge_id"))?,
            scope_id: required(&map, &format!("{p}_scope_id"))?,
            resource_id: required(&map, &format!("{p}_resource_id"))?,
            cleanup_id: required(&map, &format!("{p}_cleanup_operation_id"))?,
            destructor_id: required(&map, &format!("{p}_destructor_id"))?,
            source: required(&map, &format!("{p}_source_location"))?,
            depth: integer(&map, &format!("{p}_scope_depth"))?,
            declaration: integer(&map, &format!("{p}_declaration_order"))?,
            order: integer(&map, &format!("{p}_execution_order"))?,
            prior_state: required(&map, &format!("{p}_prior_state"))?,
            effect: required(&map, &format!("{p}_observable_effect"))?,
        });
    }
    Ok((edges, entries))
}

fn validate(edges: &[Edge], entries: &[Entry]) -> Result<(), IoError> {
    let selected = ["direct_return", "nested_conditional_return", "selected_loop_return", "selected_break", "selected_continue"];
    let mut cleanup_ids = HashSet::new();
    for entry in entries {
        if !cleanup_ids.insert(entry.cleanup_id.clone()) {
            return Err(err("early_return_cleanup_duplicate_shared_edge", &entry.cleanup_id));
        }
    }
    for edge in edges {
        if !selected.contains(&edge.kind.as_str()) {
            return Err(err("early_return_cleanup_exit_kind_unselected", &edge.kind));
        }
        if edge.return_abi == "aggregate" {
            return Err(err("early_return_cleanup_aggregate_return_deferred", &edge.id));
        }
        if !(edge.evaluation < edge.cleanup_begin && edge.cleanup_begin < edge.terminator) {
            return Err(err("early_return_cleanup_return_order_invalid", &edge.id));
        }
        let mut owned: Vec<_> = entries.iter().filter(|entry| entry.edge_id == edge.id).cloned().collect();
        if owned.is_empty() {
            return Err(err("early_return_cleanup_missing", &edge.id));
        }
        owned.sort_by_key(|entry| entry.order);
        let mut previous_depth = i64::MAX;
        let mut previous_declaration = i64::MAX;
        for (index, entry) in owned.iter().enumerate() {
            if entry.prior_state != "live" {
                return Err(err("early_return_cleanup_non_live_resource", &entry.resource_id));
            }
            if entry.order >= edge.terminator {
                return Err(err("early_return_cleanup_after_terminator", &edge.id));
            }
            if entry.order != index as i64 + 1 {
                return Err(err("early_return_cleanup_order_invalid", &edge.id));
            }
            if entry.depth > previous_depth {
                return Err(err("early_return_cleanup_inner_outer_order_invalid", &edge.id));
            }
            if entry.depth == previous_depth && entry.declaration >= previous_declaration {
                return Err(err("early_return_cleanup_order_invalid", &edge.id));
            }
            if !edge.exited_scopes.split('>').any(|scope| scope == entry.scope_id) {
                return Err(err("early_return_cleanup_resource_not_in_exited_scope", &entry.resource_id));
            }
            previous_depth = entry.depth;
            previous_declaration = entry.declaration;
        }
    }
    Ok(())
}

pub fn lower_early_return_cleanup_witness_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let (edges, entries) = parse(path)?;
    validate(&edges, &entries)?;
    let mut out = String::from("early_return_cleanup_witness: accepted order_policy=inner_before_outer return_semantics=preserved aggregate_return=deferred_to_phase16\n");
    for edge in &edges {
        out.push_str(&format!(
            "early_return_cleanup_edge: id={} kind={} exited_scopes={} return_value={} return_abi={}\n",
            edge.id, edge.kind, edge.exited_scopes, edge.return_value, edge.return_abi
        ));
    }
    for entry in &entries {
        out.push_str(&format!(
            "early_return_cleanup: edge={} scope={} resource={} order={} destructor={} source={} effect={}\n",
            entry.edge_id, entry.scope_id, entry.resource_id, entry.order, entry.destructor_id, entry.source, entry.effect
        ));
    }
    out.push_str("early_return_cleanup_lowering_witness: accepted return_value_evaluated_before_cleanup=1 cleanup_before_terminator=1 scalar_return_abi_preserved=1 output_preserved=1\n");
    Ok(out)
}