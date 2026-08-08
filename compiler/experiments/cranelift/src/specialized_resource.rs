use std::collections::HashMap;
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

#[derive(Debug)]
pub struct SpecializedResourceError {
    reason: String,
}
impl SpecializedResourceError {
    fn new(reason: &str) -> Self {
        Self {
            reason: reason.to_string(),
        }
    }
    pub fn machine_line(&self) -> String {
        format!("specialized_resource_error: reason={}", self.reason)
    }
}
impl fmt::Display for SpecializedResourceError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.machine_line())
    }
}
impl Error for SpecializedResourceError {}

fn fields(text: &str) -> HashMap<String, String> {
    text.lines()
        .filter_map(|line| line.split_once(": "))
        .map(|(key, value)| (key.to_string(), value.to_string()))
        .collect()
}

fn required(map: &HashMap<String, String>, key: &str) -> Result<String, SpecializedResourceError> {
    map.get(key)
        .cloned()
        .ok_or_else(|| SpecializedResourceError::new("specialized_resource_unknown_format"))
}

fn number(map: &HashMap<String, String>, key: &str) -> Result<i64, SpecializedResourceError> {
    required(map, key)?
        .parse::<i64>()
        .map_err(|_| SpecializedResourceError::new("specialized_resource_unknown_format"))
}

pub fn lower_specialized_resource_witness_path(
    path: &Path,
) -> Result<String, SpecializedResourceError> {
    let text = fs::read_to_string(path)
        .map_err(|_| SpecializedResourceError::new("specialized_resource_unknown_format"))?;
    let map = fields(&text);
    if required(&map, "specialized_resource_format")? != "gust.compiler_specialized_resource.v1" {
        return Err(SpecializedResourceError::new(
            "specialized_resource_unknown_format",
        ));
    }
    if required(&map, "specialized_resource_semantic_authority")?
        != "compiler_owned_generic_resource_and_lifetime_authority"
        || required(&map, "specialized_resource_backend_policy")?
            != "no_specialized_backend_state_machine"
    {
        return Err(SpecializedResourceError::new(
            "specialized_resource_authority_mismatch",
        ));
    }
    if required(&map, "specialized_resource_selected_kinds")? != "os_Dir_ctx"
        || required(&map, "specialized_resource_non_resource_views")? != "os_DirEntry_ctx"
    {
        return Err(SpecializedResourceError::new(
            "specialized_resource_inventory_unfrozen",
        ));
    }

    let expected = [
        ("specialized_resource_kind_id", "directory"),
        ("specialized_resource_type_id", "os_Dir_ctx"),
        ("specialized_resource_constructor_id", "os.OpenDir"),
        (
            "specialized_resource_destructor_id",
            "destructor:os.CloseDir",
        ),
        (
            "specialized_resource_close_capability_id",
            "close:os.CloseDir",
        ),
        ("specialized_resource_copy_policy", "prohibited"),
        ("specialized_resource_move_policy", "immovable_while_open"),
        (
            "specialized_resource_close_policy",
            "manual_or_scope_exit_exactly_once",
        ),
        (
            "specialized_resource_cleanup_effect",
            "close_directory_handle",
        ),
        (
            "specialized_resource_constructor_runtime_symbol",
            "os_OpenDir",
        ),
        ("specialized_resource_close_runtime_symbol", "os_CloseDir"),
        (
            "specialized_resource_target_applicability",
            "all_declared_host_targets_from_phase14_target_authority",
        ),
        ("specialized_resource_layout_id", "layout:os_dir"),
    ];
    for (key, value) in expected {
        if required(&map, key)? != value {
            return Err(SpecializedResourceError::new(
                "specialized_resource_kind_contract_mismatch",
            ));
        }
    }

    let count = number(&map, "specialized_resource_instance_count")?;
    if count < 1 {
        return Err(SpecializedResourceError::new(
            "specialized_resource_instance_missing",
        ));
    }
    let mut instances = Vec::new();
    let mut total_close = 0;
    let mut total_destructor = 0;
    for index in 0..count {
        let prefix = format!("specialized_resource_instance_{index}");
        let resource_id = required(&map, &format!("{prefix}_resource_id"))?;
        let kind_id = required(&map, &format!("{prefix}_kind_id"))?;
        let final_state = required(&map, &format!("{prefix}_final_state"))?;
        let operation = required(&map, &format!("{prefix}_operation_sequence"))?;
        let entries = number(&map, &format!("{prefix}_observed_entry_count"))?;
        let close_count = number(&map, &format!("{prefix}_close_count"))?;
        let destructor_count = number(&map, &format!("{prefix}_destructor_count"))?;
        let effect = required(&map, &format!("{prefix}_filesystem_effect"))?;
        if resource_id.is_empty()
            || kind_id != "directory"
            || final_state != "manually_closed"
            || operation != "open_read_close"
            || entries < 1
            || close_count != 1
            || destructor_count != 0
            || effect != "directory_entry_observed"
        {
            return Err(SpecializedResourceError::new(
                "specialized_resource_effect_mismatch",
            ));
        }
        total_close += close_count;
        total_destructor += destructor_count;
        instances.push((
            resource_id,
            kind_id,
            final_state,
            operation,
            entries,
            close_count,
            destructor_count,
            effect,
        ));
    }

    let mut output = String::from("specialized_resource_policy: authority=compiler selected_kinds=os_Dir_ctx generic_state_machine=1 backend_local_state_machine=0 non_resource_views=os_DirEntry_ctx\n");
    output.push_str("specialized_resource_kind: kind=directory resource_type=os_Dir_ctx constructor=os.OpenDir destructor=os.CloseDir close=os.CloseDir copy=prohibited move=immovable_while_open cleanup=manual_or_scope_exit_exactly_once runtime_constructor=os_OpenDir runtime_close=os_CloseDir targets=all_declared_host_targets_from_phase14_target_authority layout=layout:os_dir\n");
    for (
        resource_id,
        kind_id,
        final_state,
        operation,
        entries,
        close_count,
        destructor_count,
        effect,
    ) in &instances
    {
        output.push_str(&format!("specialized_resource: resource={resource_id} kind={kind_id} state={final_state} operation={operation} entries_observed={entries} close_count={close_count} destructor_count={destructor_count} filesystem_effect={effect}\n"));
    }
    output.push_str(&format!("specialized_resource_witness: selected_kind_count=1 resource_count={} close_count={total_close} destructor_count={total_destructor} filesystem_effects_compared=1 generic_authority=1\n", instances.len()));
    Ok(output)
}
