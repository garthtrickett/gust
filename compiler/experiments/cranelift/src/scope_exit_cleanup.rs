use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

#[derive(Debug)]
pub struct ScopeExitCleanupError {
    reason: &'static str,
    detail: String,
}

impl ScopeExitCleanupError {
    fn new(reason: &'static str, detail: impl Into<String>) -> Self {
        Self {
            reason,
            detail: detail.into(),
        }
    }
}

impl fmt::Display for ScopeExitCleanupError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{}: {}", self.reason, self.detail)
    }
}

impl Error for ScopeExitCleanupError {}

#[derive(Debug, Clone)]
struct ScopeRecord {
    scope_id: String,
    parent_scope_id: String,
    scope_kind: String,
    source_location: String,
    scope_exit_id: String,
    exit_program_point: String,
    depth: usize,
    exit_sequence: usize,
}

#[derive(Debug, Clone)]
struct BindingRecord {
    scope_id: String,
    resource_id: String,
    value_id: String,
    carrier_id: String,
    declaration_id: String,
    declaration_order: usize,
    source_location: String,
}

#[derive(Debug, Clone)]
struct CleanupEntry {
    schedule_operation_id: String,
    cleanup_operation_id: String,
    scope_id: String,
    parent_scope_id: String,
    resource_id: String,
    value_id: String,
    carrier_id: String,
    cleanup_obligation_id: String,
    destructor_id: String,
    owning_declaration: String,
    source_location: String,
    scope_exit_id: String,
    exit_program_point: String,
    declaration_order: usize,
    execution_order: usize,
    prior_state: String,
    resulting_state: String,
    observable_effect: String,
}

#[derive(Debug, Clone)]
struct ExclusionRecord {
    scope_id: String,
    resource_id: String,
    value_id: String,
    carrier_id: String,
    state: String,
    reason: String,
    declaration_order: usize,
    source_location: String,
}

#[derive(Debug, Clone)]
struct ResourceValue {
    resource_id: String,
    current_state: String,
    destructor_id: String,
    owning_scope: String,
    source_location: String,
}

#[derive(Debug, Clone)]
struct ResourceCarrier {
    resource_id: String,
    backend_symbol: String,
    current_state: String,
    owning_scope: String,
}

#[derive(Debug, Clone)]
struct ResourceOperation {
    kind: String,
    resource_id: String,
    value_id: String,
    source_carrier_id: String,
    program_point: String,
    prior_state: String,
    resulting_state: String,
    cleanup_id: String,
    destructor_id: String,
    source_location: String,
}

#[derive(Debug, Clone)]
struct AuthorityResource {
    value_id: String,
    destructor_id: String,
    declaration_id: String,
}

#[derive(Debug, Clone)]
struct AuthorityCleanup {
    resource_id: String,
    destructor_id: String,
    scope_exit_id: String,
}

#[derive(Debug, Clone)]
struct ScopeExitCleanupRequest {
    scopes: Vec<ScopeRecord>,
    bindings: Vec<BindingRecord>,
    entries: Vec<CleanupEntry>,
    exclusions: Vec<ExclusionRecord>,
    values: HashMap<String, ResourceValue>,
    carriers: HashMap<String, ResourceCarrier>,
    operations: HashMap<String, ResourceOperation>,
    resources: HashMap<String, AuthorityResource>,
    cleanups: HashMap<String, AuthorityCleanup>,
    destructor_symbols: HashMap<String, String>,
}

fn reason(reason: &'static str, detail: impl Into<String>) -> ScopeExitCleanupError {
    ScopeExitCleanupError::new(reason, detail)
}

fn parse_fields(contents: &str) -> Result<HashMap<String, String>, ScopeExitCleanupError> {
    let mut fields = HashMap::new();
    for line in contents.lines() {
        let Some((key, value)) = line.split_once(": ") else {
            continue;
        };
        if (key.starts_with("scope_exit_cleanup_") || key.starts_with("resource_mir_"))
            && fields.insert(key.to_string(), value.to_string()).is_some()
        {
            return Err(reason(
                "scope_exit_cleanup_duplicate_insertion",
                format!("duplicate serialized field {key}"),
            ));
        }
    }
    Ok(fields)
}

fn required<'a>(
    fields: &'a HashMap<String, String>,
    key: &str,
) -> Result<&'a str, ScopeExitCleanupError> {
    fields
        .get(key)
        .map(String::as_str)
        .ok_or_else(|| reason("scope_exit_cleanup_unknown_format", format!("missing {key}")))
}

fn number(fields: &HashMap<String, String>, key: &str) -> Result<usize, ScopeExitCleanupError> {
    required(fields, key)?
        .parse::<usize>()
        .map_err(|_| reason("scope_exit_cleanup_unknown_format", format!("invalid {key}")))
}

fn record_parts(payload: &str) -> HashMap<&str, &str> {
    payload
        .split(';')
        .filter_map(|part| part.split_once('='))
        .collect()
}

fn selected_kind(kind: &str) -> bool {
    matches!(kind, "block_scope" | "function_body" | "selected_nested_scope")
}

fn exclusion_reason(state: &str) -> &'static str {
    match state {
        "moved" => "moved_resource",
        "manually_closed" => "manually_closed_resource",
        "destroyed" => "already_destroyed_resource",
        "cleanup_scheduled" => "already_scheduled_resource",
        _ => "invalid_non_live_state",
    }
}

fn parse_request(contents: &str) -> Result<ScopeExitCleanupRequest, ScopeExitCleanupError> {
    let fields = parse_fields(contents)?;
    if required(&fields, "scope_exit_cleanup_format")? != "gust.compiler_scope_exit_cleanup.v1"
        || required(&fields, "scope_exit_cleanup_semantic_authority")?
            != "compiler_owned_cleanup_insertion"
        || required(&fields, "scope_exit_cleanup_order_policy")?
            != "selected_scopes_by_exit_sequence_then_reverse_declaration_order"
    {
        return Err(reason(
            "scope_exit_cleanup_unknown_format",
            "scope cleanup format or policy mismatch",
        ));
    }

    let scope_count = number(&fields, "scope_exit_cleanup_scope_count")?;
    let binding_count = number(&fields, "scope_exit_cleanup_binding_count")?;
    let entry_count = number(&fields, "scope_exit_cleanup_entry_count")?;
    let exclusion_count = number(&fields, "scope_exit_cleanup_exclusion_count")?;

    let mut scopes = Vec::with_capacity(scope_count);
    for index in 0..scope_count {
        let prefix = format!("scope_exit_cleanup_scope_{index}");
        scopes.push(ScopeRecord {
            scope_id: required(&fields, &format!("{prefix}_scope_id"))?.to_string(),
            parent_scope_id: required(&fields, &format!("{prefix}_parent_scope_id"))?.to_string(),
            scope_kind: required(&fields, &format!("{prefix}_scope_kind"))?.to_string(),
            source_location: required(&fields, &format!("{prefix}_source_location"))?.to_string(),
            scope_exit_id: required(&fields, &format!("{prefix}_scope_exit_id"))?.to_string(),
            exit_program_point: required(&fields, &format!("{prefix}_exit_program_point"))?
                .to_string(),
            depth: number(&fields, &format!("{prefix}_depth"))?,
            exit_sequence: number(&fields, &format!("{prefix}_exit_sequence"))?,
        });
    }

    let mut bindings = Vec::with_capacity(binding_count);
    for index in 0..binding_count {
        let prefix = format!("scope_exit_cleanup_binding_{index}");
        bindings.push(BindingRecord {
            scope_id: required(&fields, &format!("{prefix}_scope_id"))?.to_string(),
            resource_id: required(&fields, &format!("{prefix}_resource_id"))?.to_string(),
            value_id: required(&fields, &format!("{prefix}_value_id"))?.to_string(),
            carrier_id: required(&fields, &format!("{prefix}_carrier_id"))?.to_string(),
            declaration_id: required(&fields, &format!("{prefix}_declaration_id"))?.to_string(),
            declaration_order: number(&fields, &format!("{prefix}_declaration_order"))?,
            source_location: required(&fields, &format!("{prefix}_source_location"))?.to_string(),
        });
    }

    let mut entries = Vec::with_capacity(entry_count);
    for index in 0..entry_count {
        let prefix = format!("scope_exit_cleanup_entry_{index}");
        entries.push(CleanupEntry {
            schedule_operation_id: required(
                &fields,
                &format!("{prefix}_schedule_operation_id"),
            )?
            .to_string(),
            cleanup_operation_id: required(
                &fields,
                &format!("{prefix}_cleanup_operation_id"),
            )?
            .to_string(),
            scope_id: required(&fields, &format!("{prefix}_scope_id"))?.to_string(),
            parent_scope_id: required(&fields, &format!("{prefix}_parent_scope_id"))?.to_string(),
            resource_id: required(&fields, &format!("{prefix}_resource_id"))?.to_string(),
            value_id: required(&fields, &format!("{prefix}_value_id"))?.to_string(),
            carrier_id: required(&fields, &format!("{prefix}_carrier_id"))?.to_string(),
            cleanup_obligation_id: required(
                &fields,
                &format!("{prefix}_cleanup_obligation_id"),
            )?
            .to_string(),
            destructor_id: required(&fields, &format!("{prefix}_destructor_id"))?.to_string(),
            owning_declaration: required(
                &fields,
                &format!("{prefix}_owning_declaration"),
            )?
            .to_string(),
            source_location: required(&fields, &format!("{prefix}_source_location"))?.to_string(),
            scope_exit_id: required(&fields, &format!("{prefix}_scope_exit_id"))?.to_string(),
            exit_program_point: required(
                &fields,
                &format!("{prefix}_exit_program_point"),
            )?
            .to_string(),
            declaration_order: number(&fields, &format!("{prefix}_declaration_order"))?,
            execution_order: number(&fields, &format!("{prefix}_execution_order"))?,
            prior_state: required(&fields, &format!("{prefix}_prior_state"))?.to_string(),
            resulting_state: required(&fields, &format!("{prefix}_resulting_state"))?.to_string(),
            observable_effect: required(
                &fields,
                &format!("{prefix}_observable_effect"),
            )?
            .to_string(),
        });
    }

    let mut exclusions = Vec::with_capacity(exclusion_count);
    for index in 0..exclusion_count {
        let prefix = format!("scope_exit_cleanup_exclusion_{index}");
        exclusions.push(ExclusionRecord {
            scope_id: required(&fields, &format!("{prefix}_scope_id"))?.to_string(),
            resource_id: required(&fields, &format!("{prefix}_resource_id"))?.to_string(),
            value_id: required(&fields, &format!("{prefix}_value_id"))?.to_string(),
            carrier_id: required(&fields, &format!("{prefix}_carrier_id"))?.to_string(),
            state: required(&fields, &format!("{prefix}_state"))?.to_string(),
            reason: required(&fields, &format!("{prefix}_reason"))?.to_string(),
            declaration_order: number(&fields, &format!("{prefix}_declaration_order"))?,
            source_location: required(&fields, &format!("{prefix}_source_location"))?.to_string(),
        });
    }

    let value_count = number(&fields, "resource_mir_value_count")?;
    let mut values = HashMap::new();
    for index in 0..value_count {
        let prefix = format!("resource_mir_value_{index}");
        let value_id = required(&fields, &format!("{prefix}_value_id"))?.to_string();
        let value = ResourceValue {
            resource_id: required(&fields, &format!("{prefix}_resource_id"))?.to_string(),
            current_state: required(&fields, &format!("{prefix}_current_state"))?.to_string(),
            destructor_id: required(&fields, &format!("{prefix}_destructor_id"))?.to_string(),
            owning_scope: required(&fields, &format!("{prefix}_owning_scope"))?.to_string(),
            source_location: required(&fields, &format!("{prefix}_source_location"))?.to_string(),
        };
        if values.insert(value_id.clone(), value).is_some() {
            return Err(reason(
                "scope_exit_cleanup_binding_identity_mismatch",
                format!("duplicate value {value_id}"),
            ));
        }
    }

    let carrier_count = number(&fields, "resource_mir_carrier_count")?;
    let mut carriers = HashMap::new();
    for index in 0..carrier_count {
        let prefix = format!("resource_mir_carrier_{index}");
        let carrier_id = required(&fields, &format!("{prefix}_carrier_id"))?.to_string();
        let carrier = ResourceCarrier {
            resource_id: required(&fields, &format!("{prefix}_resource_id"))?.to_string(),
            backend_symbol: required(&fields, &format!("{prefix}_backend_symbol"))?.to_string(),
            current_state: required(&fields, &format!("{prefix}_current_state"))?.to_string(),
            owning_scope: required(&fields, &format!("{prefix}_owning_scope"))?.to_string(),
        };
        if carriers.insert(carrier_id.clone(), carrier).is_some() {
            return Err(reason(
                "scope_exit_cleanup_binding_identity_mismatch",
                format!("duplicate carrier {carrier_id}"),
            ));
        }
    }

    let operation_count = number(&fields, "resource_mir_operation_count")?;
    let mut operations = HashMap::new();
    for index in 0..operation_count {
        let prefix = format!("resource_mir_operation_{index}");
        let operation_id = required(&fields, &format!("{prefix}_operation_id"))?.to_string();
        let operation = ResourceOperation {
            kind: required(&fields, &format!("{prefix}_kind"))?.to_string(),
            resource_id: required(&fields, &format!("{prefix}_resource_id"))?.to_string(),
            value_id: required(&fields, &format!("{prefix}_value_id"))?.to_string(),
            source_carrier_id: required(
                &fields,
                &format!("{prefix}_source_carrier_id"),
            )?
            .to_string(),
            program_point: required(&fields, &format!("{prefix}_program_point"))?.to_string(),
            prior_state: required(&fields, &format!("{prefix}_prior_state"))?.to_string(),
            resulting_state: required(&fields, &format!("{prefix}_resulting_state"))?.to_string(),
            cleanup_id: required(&fields, &format!("{prefix}_cleanup_id"))?.to_string(),
            destructor_id: required(&fields, &format!("{prefix}_destructor_id"))?.to_string(),
            source_location: required(&fields, &format!("{prefix}_source_location"))?.to_string(),
        };
        if operations.insert(operation_id.clone(), operation).is_some() {
            return Err(reason(
                "scope_exit_cleanup_duplicate_insertion",
                format!("duplicate operation {operation_id}"),
            ));
        }
    }

    let mut resources = HashMap::new();
    let mut cleanups = HashMap::new();
    let mut destructor_symbols = HashMap::new();
    for line in contents.lines() {
        if let Some(payload) = line.strip_prefix("resource_record: ") {
            let parts = record_parts(payload);
            let Some(resource_id) = parts.get("id") else {
                continue;
            };
            resources.insert(
                (*resource_id).to_string(),
                AuthorityResource {
                    value_id: parts.get("value").copied().unwrap_or_default().to_string(),
                    destructor_id: parts
                        .get("destructor")
                        .copied()
                        .unwrap_or_default()
                        .to_string(),
                    declaration_id: String::new(),
                },
            );
        } else if let Some(payload) = line.strip_prefix("cleanup_record: ") {
            let parts = record_parts(payload);
            let Some(cleanup_id) = parts.get("id") else {
                continue;
            };
            cleanups.insert(
                (*cleanup_id).to_string(),
                AuthorityCleanup {
                    resource_id: parts
                        .get("resource")
                        .copied()
                        .unwrap_or_default()
                        .to_string(),
                    destructor_id: parts
                        .get("destructor")
                        .copied()
                        .unwrap_or_default()
                        .to_string(),
                    scope_exit_id: parts
                        .get("scope_exit")
                        .copied()
                        .unwrap_or_default()
                        .to_string(),
                },
            );
        } else if let Some(payload) = line.strip_prefix("destructor_record: ") {
            let parts = record_parts(payload);
            if let (Some(id), Some(symbol)) = (parts.get("id"), parts.get("runtime_symbol")) {
                destructor_symbols.insert((*id).to_string(), (*symbol).to_string());
            }
        }
    }

    // The authority serialization does not repeat declaration IDs. Bindings are
    // compiler-owned and provide the declaration identity; copy it into the
    // authority projection only after resource/value identity agrees.
    for binding in &bindings {
        if let Some(resource) = resources.get_mut(&binding.resource_id) {
            if resource.value_id == binding.value_id {
                resource.declaration_id = binding.declaration_id.clone();
            }
        }
    }

    Ok(ScopeExitCleanupRequest {
        scopes,
        bindings,
        entries,
        exclusions,
        values,
        carriers,
        operations,
        resources,
        cleanups,
        destructor_symbols,
    })
}

fn validate(request: &ScopeExitCleanupRequest) -> Result<(), ScopeExitCleanupError> {
    let mut scope_ids = HashSet::new();
    let mut exit_sequences = HashSet::new();
    let scope_map: HashMap<&str, &ScopeRecord> = request
        .scopes
        .iter()
        .map(|scope| (scope.scope_id.as_str(), scope))
        .collect();

    for scope in &request.scopes {
        if scope.scope_id.is_empty()
            || scope.source_location.is_empty()
            || scope.scope_exit_id.is_empty()
            || scope.exit_program_point.is_empty()
            || scope.exit_sequence == 0
            || !selected_kind(&scope.scope_kind)
        {
            return Err(reason(
                "scope_exit_cleanup_scope_parent_invalid",
                format!("invalid scope {}", scope.scope_id),
            ));
        }
        if !scope_ids.insert(scope.scope_id.as_str())
            || !exit_sequences.insert(scope.exit_sequence)
        {
            return Err(reason(
                "scope_exit_cleanup_duplicate_scope",
                format!("duplicate scope {}", scope.scope_id),
            ));
        }
        if scope.depth == 0 {
            if !scope.parent_scope_id.is_empty() || scope.scope_kind != "function_body" {
                return Err(reason(
                    "scope_exit_cleanup_scope_parent_invalid",
                    format!("invalid root scope {}", scope.scope_id),
                ));
            }
        } else {
            let Some(parent) = scope_map.get(scope.parent_scope_id.as_str()) else {
                return Err(reason(
                    "scope_exit_cleanup_scope_parent_invalid",
                    format!("missing parent for {}", scope.scope_id),
                ));
            };
            if parent.depth + 1 != scope.depth {
                return Err(reason(
                    "scope_exit_cleanup_scope_parent_invalid",
                    format!("invalid depth for {}", scope.scope_id),
                ));
            }
        }
    }

    let mut binding_resources = HashSet::new();
    let mut binding_orders = HashSet::new();
    let binding_map: HashMap<&str, &BindingRecord> = request
        .bindings
        .iter()
        .map(|binding| (binding.resource_id.as_str(), binding))
        .collect();
    for binding in &request.bindings {
        if binding.scope_id.is_empty()
            || binding.resource_id.is_empty()
            || binding.value_id.is_empty()
            || binding.carrier_id.is_empty()
            || binding.declaration_id.is_empty()
            || binding.source_location.is_empty()
            || binding.declaration_order == 0
            || !scope_map.contains_key(binding.scope_id.as_str())
        {
            return Err(reason(
                "scope_exit_cleanup_binding_identity_mismatch",
                format!("invalid binding {}", binding.resource_id),
            ));
        }
        if !binding_resources.insert(binding.resource_id.as_str())
            || !binding_orders.insert((binding.scope_id.as_str(), binding.declaration_order))
        {
            return Err(reason(
                "scope_exit_cleanup_duplicate_binding",
                format!("duplicate binding {}", binding.resource_id),
            ));
        }
        let Some(value) = request.values.get(&binding.value_id) else {
            return Err(reason(
                "scope_exit_cleanup_binding_identity_mismatch",
                format!("missing value {}", binding.value_id),
            ));
        };
        let Some(carrier) = request.carriers.get(&binding.carrier_id) else {
            return Err(reason(
                "scope_exit_cleanup_binding_identity_mismatch",
                format!("missing carrier {}", binding.carrier_id),
            ));
        };
        let Some(resource) = request.resources.get(&binding.resource_id) else {
            return Err(reason(
                "scope_exit_cleanup_binding_identity_mismatch",
                format!("missing authority resource {}", binding.resource_id),
            ));
        };
        if value.resource_id != binding.resource_id
            || carrier.resource_id != binding.resource_id
            || resource.value_id != binding.value_id
            || resource.declaration_id != binding.declaration_id
        {
            return Err(reason(
                "scope_exit_cleanup_binding_identity_mismatch",
                format!("identity mismatch for {}", binding.resource_id),
            ));
        }
    }

    let mut cleanup_operations = HashSet::new();
    let mut cleanup_ids = HashSet::new();
    let mut entry_resources = HashSet::new();
    for entry in &request.entries {
        if !cleanup_operations.insert(entry.cleanup_operation_id.as_str())
            || !cleanup_ids.insert(entry.cleanup_obligation_id.as_str())
            || !entry_resources.insert(entry.resource_id.as_str())
        {
            return Err(reason(
                "scope_exit_cleanup_duplicate_insertion",
                format!("duplicate cleanup for {}", entry.resource_id),
            ));
        }
        if entry.prior_state == "moved" {
            return Err(reason(
                "scope_exit_cleanup_moved_resource",
                format!("cleanup for moved resource {}", entry.resource_id),
            ));
        }
        if entry.prior_state != "live" || entry.resulting_state != "destroyed" {
            return Err(reason(
                "scope_exit_cleanup_non_live_state_invalid",
                format!("invalid states for {}", entry.resource_id),
            ));
        }
        let Some(binding) = binding_map.get(entry.resource_id.as_str()) else {
            return Err(reason(
                "scope_exit_cleanup_wrong_scope",
                format!("missing binding for {}", entry.resource_id),
            ));
        };
        let Some(scope) = scope_map.get(entry.scope_id.as_str()) else {
            return Err(reason(
                "scope_exit_cleanup_wrong_scope",
                format!("missing scope {}", entry.scope_id),
            ));
        };
        if binding.scope_id != entry.scope_id
            || binding.value_id != entry.value_id
            || binding.carrier_id != entry.carrier_id
            || binding.declaration_order != entry.declaration_order
            || scope.parent_scope_id != entry.parent_scope_id
            || scope.scope_exit_id != entry.scope_exit_id
            || scope.exit_program_point != entry.exit_program_point
        {
            return Err(reason(
                "scope_exit_cleanup_wrong_scope",
                format!("scope mismatch for {}", entry.resource_id),
            ));
        }
        let Some(authority_cleanup) = request.cleanups.get(&entry.cleanup_obligation_id) else {
            return Err(reason(
                "scope_exit_cleanup_obligation_missing",
                format!("missing obligation {}", entry.cleanup_obligation_id),
            ));
        };
        if authority_cleanup.resource_id != entry.resource_id
            || authority_cleanup.scope_exit_id != entry.scope_exit_id
        {
            return Err(reason(
                "scope_exit_cleanup_wrong_scope",
                format!("obligation scope mismatch for {}", entry.resource_id),
            ));
        }
        let Some(authority_resource) = request.resources.get(&entry.resource_id) else {
            return Err(reason(
                "scope_exit_cleanup_binding_identity_mismatch",
                format!("missing resource {}", entry.resource_id),
            ));
        };
        if authority_resource.declaration_id != entry.owning_declaration {
            return Err(reason(
                "scope_exit_cleanup_owning_declaration_mismatch",
                format!("declaration mismatch for {}", entry.resource_id),
            ));
        }
        if binding.source_location != entry.source_location {
            return Err(reason(
                "scope_exit_cleanup_source_location_mismatch",
                format!("source mismatch for {}", entry.resource_id),
            ));
        }
        if authority_resource.destructor_id != entry.destructor_id
            || authority_cleanup.destructor_id != entry.destructor_id
            || !request.destructor_symbols.contains_key(&entry.destructor_id)
        {
            return Err(reason(
                "scope_exit_cleanup_destructor_mismatch",
                format!("destructor mismatch for {}", entry.resource_id),
            ));
        }
        let Some(schedule) = request.operations.get(&entry.schedule_operation_id) else {
            return Err(reason(
                "scope_exit_cleanup_operation_missing",
                format!("missing schedule {}", entry.schedule_operation_id),
            ));
        };
        let Some(cleanup) = request.operations.get(&entry.cleanup_operation_id) else {
            return Err(reason(
                "scope_exit_cleanup_operation_missing",
                format!("missing cleanup {}", entry.cleanup_operation_id),
            ));
        };
        if schedule.kind != "schedule_cleanup"
            || schedule.resource_id != entry.resource_id
            || schedule.value_id != entry.value_id
            || schedule.source_carrier_id != entry.carrier_id
            || schedule.prior_state != "live"
            || schedule.resulting_state != "cleanup_scheduled"
            || schedule.cleanup_id != entry.cleanup_obligation_id
            || cleanup.kind != "invoke_destructor"
            || cleanup.resource_id != entry.resource_id
            || cleanup.value_id != entry.value_id
            || cleanup.source_carrier_id != entry.carrier_id
            || cleanup.program_point != entry.exit_program_point
            || cleanup.prior_state != "cleanup_scheduled"
            || cleanup.resulting_state != "destroyed"
            || cleanup.cleanup_id != entry.cleanup_obligation_id
            || cleanup.destructor_id != entry.destructor_id
            || cleanup.source_location != entry.source_location
        {
            return Err(reason(
                "scope_exit_cleanup_operation_missing",
                format!("operation mismatch for {}", entry.resource_id),
            ));
        }
        let invoke_count = request
            .operations
            .values()
            .filter(|operation| {
                operation.kind == "invoke_destructor"
                    && operation.resource_id == entry.resource_id
                    && operation.cleanup_id == entry.cleanup_obligation_id
            })
            .count();
        if invoke_count != 1 {
            return Err(reason(
                "scope_exit_cleanup_duplicate_insertion",
                format!("cleanup count {invoke_count} for {}", entry.resource_id),
            ));
        }
    }

    let exclusion_map: HashMap<&str, &ExclusionRecord> = request
        .exclusions
        .iter()
        .map(|exclusion| (exclusion.resource_id.as_str(), exclusion))
        .collect();
    if exclusion_map.len() != request.exclusions.len() {
        return Err(reason(
            "scope_exit_cleanup_duplicate_insertion",
            "duplicate exclusion resource",
        ));
    }

    let mut ordered_scopes: Vec<&ScopeRecord> = request.scopes.iter().collect();
    ordered_scopes.sort_by_key(|scope| scope.exit_sequence);
    let mut expected_order = 1usize;
    for scope in ordered_scopes {
        let mut scope_bindings: Vec<&BindingRecord> = request
            .bindings
            .iter()
            .filter(|binding| binding.scope_id == scope.scope_id)
            .collect();
        scope_bindings.sort_by(|left, right| {
            right
                .declaration_order
                .cmp(&left.declaration_order)
        });
        for binding in scope_bindings {
            if let Some(entry) = request
                .entries
                .iter()
                .find(|entry| entry.resource_id == binding.resource_id)
            {
                if entry.execution_order != expected_order {
                    return Err(reason(
                        "scope_exit_cleanup_order_invalid",
                        format!(
                            "resource {} expected order {} got {}",
                            binding.resource_id, expected_order, entry.execution_order
                        ),
                    ));
                }
                expected_order += 1;
                continue;
            }
            if let Some(exclusion) = exclusion_map.get(binding.resource_id.as_str()) {
                let Some(value) = request.values.get(&exclusion.value_id) else {
                    return Err(reason(
                        "scope_exit_cleanup_binding_identity_mismatch",
                        format!("missing exclusion value {}", exclusion.value_id),
                    ));
                };
                let Some(carrier) = request.carriers.get(&exclusion.carrier_id) else {
                    return Err(reason(
                        "scope_exit_cleanup_binding_identity_mismatch",
                        format!("missing exclusion carrier {}", exclusion.carrier_id),
                    ));
                };
                if exclusion.scope_id != binding.scope_id
                    || exclusion.declaration_order != binding.declaration_order
                    || exclusion.source_location != binding.source_location
                    || value.current_state != exclusion.state
                    || carrier.current_state != exclusion.state
                    || exclusion.reason != exclusion_reason(&exclusion.state)
                {
                    return Err(reason(
                        "scope_exit_cleanup_non_live_state_invalid",
                        format!("invalid exclusion for {}", binding.resource_id),
                    ));
                }
                continue;
            }

            let selected_cleanup_exists = request.cleanups.values().any(|cleanup| {
                cleanup.resource_id == binding.resource_id
                    && cleanup.scope_exit_id == scope.scope_exit_id
            });
            if selected_cleanup_exists {
                return Err(reason(
                    "scope_exit_cleanup_live_resource_missing",
                    format!("missing cleanup for {}", binding.resource_id),
                ));
            }
            return Err(reason(
                "scope_exit_cleanup_binding_identity_mismatch",
                format!("binding {} has no classification", binding.resource_id),
            ));
        }
    }

    for exclusion in &request.exclusions {
        if entry_resources.contains(exclusion.resource_id.as_str()) {
            return Err(reason(
                "scope_exit_cleanup_duplicate_insertion",
                format!("resource {} is both cleanup and exclusion", exclusion.resource_id),
            ));
        }
        if exclusion.state == "moved"
            && request.entries.iter().any(|entry| entry.resource_id == exclusion.resource_id)
        {
            return Err(reason(
                "scope_exit_cleanup_moved_resource",
                format!("cleanup for moved resource {}", exclusion.resource_id),
            ));
        }
    }

    Ok(())
}

fn canonical_witness(request: &ScopeExitCleanupRequest) -> String {
    let mut output =
        "scope_exit_cleanup_witness: accepted order_policy=reverse_declaration_order\n"
            .to_string();
    for entry in &request.entries {
        output.push_str(&format!(
            "scope_exit_cleanup: scope={} resource={} order={} declaration_order={} destructor={} source={} operation={} effect={}\n",
            entry.scope_id,
            entry.resource_id,
            entry.execution_order,
            entry.declaration_order,
            entry.destructor_id,
            entry.source_location,
            entry.cleanup_operation_id,
            entry.observable_effect,
        ));
    }
    for exclusion in &request.exclusions {
        output.push_str(&format!(
            "scope_exit_cleanup_excluded: scope={} resource={} state={} reason={}\n",
            exclusion.scope_id, exclusion.resource_id, exclusion.state, exclusion.reason,
        ));
    }
    output
}

fn lowering_witness(request: &ScopeExitCleanupRequest) -> String {
    let mut output = "scope_exit_cleanup_lowering_witness: accepted\n".to_string();
    for entry in &request.entries {
        let runtime_symbol = request
            .destructor_symbols
            .get(&entry.destructor_id)
            .map(String::as_str)
            .unwrap_or_default();
        // Carrier lookup is part of validation; retaining it here documents that
        // lowering consumes the compiler-selected storage rather than deriving it.
        let _backend_symbol = request
            .carriers
            .get(&entry.carrier_id)
            .map(|carrier| carrier.backend_symbol.as_str())
            .unwrap_or_default();
        output.push_str(&format!(
            "scope_exit_cleanup_lowering: scope={} resource={} action=invoke_destructor runtime_symbol={} order={} destructor={} source={} effect={}\n",
            entry.scope_id,
            entry.resource_id,
            runtime_symbol,
            entry.execution_order,
            entry.destructor_id,
            entry.source_location,
            entry.observable_effect,
        ));
    }
    output
}

pub fn lower_scope_exit_cleanup_witness_path(
    path: &Path,
) -> Result<String, ScopeExitCleanupError> {
    let contents = fs::read_to_string(path).map_err(|error| {
        reason(
            "scope_exit_cleanup_request_read_failed",
            format!("{}: {error}", path.display()),
        )
    })?;
    let request = parse_request(&contents)?;
    validate(&request)?;
    let mut output = canonical_witness(&request);
    output.push_str(&lowering_witness(&request));
    Ok(output)
}