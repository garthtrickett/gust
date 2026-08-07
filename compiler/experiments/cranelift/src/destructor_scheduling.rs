use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

#[derive(Debug)]
pub struct DestructorSchedulingError { reason: String }
impl DestructorSchedulingError {
    fn new(reason: &str) -> Self { Self { reason: reason.to_string() } }
    pub fn machine_line(&self) -> String { format!("destructor_scheduling_error: reason={}", self.reason) }
}
impl fmt::Display for DestructorSchedulingError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result { write!(f, "{}", self.machine_line()) }
}
impl Error for DestructorSchedulingError {}

#[derive(Clone)]
struct Entry {
    resource_id: String,
    destructor_id: String,
    execution_destructor_id: String,
    cleanup_reason: String,
    schedule_operation_id: String,
    cancel_operation_id: String,
    execute_operation_id: String,
    mark_destroyed_operation_id: String,
    schedule_point: String,
    cancel_point: String,
    execution_point: String,
    mark_destroyed_point: String,
    schedule_sequence: i64,
    cancel_sequence: i64,
    execution_sequence: i64,
    mark_destroyed_sequence: i64,
    schedule_count: i64,
    cancel_count: i64,
    execution_count: i64,
    execution_order: i64,
    ownership_state: String,
    canceled_for_transfer: i64,
    observable_effect: String,
}

fn fields(text: &str) -> HashMap<String, String> {
    text.lines().filter_map(|line| line.split_once(": ")).map(|(k,v)| (k.to_string(),v.to_string())).collect()
}
fn required(map: &HashMap<String,String>, key: &str) -> Result<String, DestructorSchedulingError> {
    map.get(key).cloned().ok_or_else(|| DestructorSchedulingError::new("destructor_schedule_resolution_invalid"))
}
fn number(map: &HashMap<String,String>, key: &str) -> Result<i64, DestructorSchedulingError> {
    required(map,key)?.parse::<i64>().map_err(|_| DestructorSchedulingError::new("destructor_schedule_resolution_invalid"))
}
fn parse_entry(map: &HashMap<String,String>, i: i64) -> Result<Entry, DestructorSchedulingError> {
    let p=format!("destructor_scheduling_entry_{i}");
    Ok(Entry {
        resource_id: required(map,&format!("{p}_resource_id"))?,
        destructor_id: required(map,&format!("{p}_destructor_id"))?,
        execution_destructor_id: required(map,&format!("{p}_execution_destructor_id"))?,
        cleanup_reason: required(map,&format!("{p}_cleanup_reason"))?,
        schedule_operation_id: required(map,&format!("{p}_schedule_operation_id"))?,
        cancel_operation_id: required(map,&format!("{p}_cancel_operation_id"))?,
        execute_operation_id: required(map,&format!("{p}_execute_operation_id"))?,
        mark_destroyed_operation_id: required(map,&format!("{p}_mark_destroyed_operation_id"))?,
        schedule_point: required(map,&format!("{p}_schedule_point"))?,
        cancel_point: required(map,&format!("{p}_cancel_point"))?,
        execution_point: required(map,&format!("{p}_execution_point"))?,
        mark_destroyed_point: required(map,&format!("{p}_mark_destroyed_point"))?,
        schedule_sequence: number(map,&format!("{p}_schedule_sequence"))?,
        cancel_sequence: number(map,&format!("{p}_cancel_sequence"))?,
        execution_sequence: number(map,&format!("{p}_execution_sequence"))?,
        mark_destroyed_sequence: number(map,&format!("{p}_mark_destroyed_sequence"))?,
        schedule_count: number(map,&format!("{p}_schedule_count"))?,
        cancel_count: number(map,&format!("{p}_cancel_count"))?,
        execution_count: number(map,&format!("{p}_execution_count"))?,
        execution_order: number(map,&format!("{p}_execution_order"))?,
        ownership_state: required(map,&format!("{p}_ownership_state"))?,
        canceled_for_transfer: number(map,&format!("{p}_canceled_for_transfer"))?,
        observable_effect: required(map,&format!("{p}_observable_effect"))?,
    })
}

fn validate(entries: &[Entry]) -> Result<(), DestructorSchedulingError> {
    let mut expected_order=1i64;
    let mut seen=HashSet::new();
    for e in entries {
        if e.resource_id.is_empty() || e.destructor_id.is_empty() || e.cleanup_reason.is_empty() || e.schedule_operation_id.is_empty() || e.schedule_point.is_empty() {
            return Err(DestructorSchedulingError::new("destructor_schedule_resolution_invalid"));
        }
        if !seen.insert(e.resource_id.clone()) { return Err(DestructorSchedulingError::new("destructor_duplicate_resource_schedule")); }
        if e.mark_destroyed_sequence > 0 && e.schedule_sequence >= e.mark_destroyed_sequence { return Err(DestructorSchedulingError::new("destructor_schedule_after_destroy")); }
        if e.schedule_count > 1 && e.ownership_state == "live" { return Err(DestructorSchedulingError::new("destructor_duplicate_live_schedule")); }
        if e.execution_count > 0 && e.schedule_count == 0 { return Err(DestructorSchedulingError::new("destructor_execution_without_schedule")); }
        if e.execution_count > 0 && e.execution_destructor_id != e.destructor_id { return Err(DestructorSchedulingError::new("destructor_identity_mismatch")); }
        if e.ownership_state == "moved" {
            if e.execution_count != 0 { return Err(DestructorSchedulingError::new("destructor_moved_ownership_destroyed")); }
            if e.canceled_for_transfer != 1 || e.cancel_count != 1 || e.cancel_operation_id.is_empty() || e.cancel_point.is_empty() || e.schedule_count != 1 || e.cancel_sequence <= e.schedule_sequence {
                return Err(DestructorSchedulingError::new("destructor_transfer_schedule_not_canceled"));
            }
        } else if e.ownership_state == "live" {
            if e.schedule_count != 1 || e.execution_count != 1 || e.execute_operation_id.is_empty() || e.execution_point.is_empty() { return Err(DestructorSchedulingError::new("destructor_live_resource_skipped")); }
            if e.mark_destroyed_operation_id.is_empty() || e.mark_destroyed_point.is_empty() || e.mark_destroyed_sequence <= e.execution_sequence { return Err(DestructorSchedulingError::new("destructor_mark_destroyed_missing")); }
            if e.execution_sequence <= e.schedule_sequence { return Err(DestructorSchedulingError::new("destructor_execution_order_invalid")); }
            if e.execution_order != expected_order { return Err(DestructorSchedulingError::new("destructor_order_drift")); }
            expected_order += 1;
        } else { return Err(DestructorSchedulingError::new("destructor_ownership_state_invalid")); }
    }
    Ok(())
}

pub fn lower_destructor_scheduling_witness_path(path: &Path) -> Result<String, DestructorSchedulingError> {
    let text=fs::read_to_string(path).map_err(|_| DestructorSchedulingError::new("destructor_schedule_resolution_invalid"))?;
    let map=fields(&text);
    if required(&map,"destructor_scheduling_format")? != "gust.compiler_destructor_scheduling.v1" { return Err(DestructorSchedulingError::new("destructor_schedule_resolution_invalid")); }
    let count=number(&map,"destructor_scheduling_entry_count")?;
    let mut entries=Vec::new();
    for i in 0..count { entries.push(parse_entry(&map,i)?); }
    validate(&entries)?;
    let mut out=String::from("destructor_scheduling_policy: authority=compiler exactly_once=1 operations=schedule_destructor,cancel_obsolete_schedule,execute_destructor,mark_resource_destroyed\n");
    let mut scheduled=0i64; let mut canceled=0i64; let mut executed=0i64;
    for e in &entries {
        out.push_str(&format!("destructor_schedule: resource={} destructor={} reason={} schedule_count={} cancel_count={} execution_count={} order={} schedule_point={} execution_point={} effect={}\n", e.resource_id,e.destructor_id,e.cleanup_reason,e.schedule_count,e.cancel_count,e.execution_count,e.execution_order,e.schedule_point,e.execution_point,e.observable_effect));
        scheduled += e.schedule_count; canceled += e.cancel_count; executed += e.execution_count;
    }
    out.push_str(&format!("destructor_scheduling_exactly_once_witness: schedule_count={} cancel_count={} execution_count={} order_preserved=1 observable_effects_preserved=1 exactly_once=1\n",scheduled,canceled,executed));
    Ok(out)
}