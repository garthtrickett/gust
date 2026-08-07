use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_resource_mir.v1";
const SEMANTIC_AUTHORITY: &str = "compiler_owned_resource_identity_and_state";
const IDENTITY_POLICY: &str = "explicit_resource_id_only_no_backend_derivation";
const COPY_POLICY: &str = "non_copy_resources_move_only";
const EDGE_STATE_POLICY: &str = "explicit_state_on_every_selected_resource_edge";
const MOVE_STATE_POLICY: &str = "carrier_state_transitions_before_driver_discovery";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ResourceMirError {
    pub reason_code: &'static str,
    pub detail: String,
}

impl ResourceMirError {
    fn new(reason_code: &'static str, detail: impl Into<String>) -> Self {
        Self {
            reason_code,
            detail: detail.into(),
        }
    }
}

impl fmt::Display for ResourceMirError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "gust_resource_mir_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for ResourceMirError {}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum ResourceOperationKind {
    Declare,
    Initialize,
    Read,
    Move,
    Copy,
    ExplicitClose,
    ScheduleCleanup,
    InvokeDestructor,
    MarkDestroyed,
}

impl ResourceOperationKind {
    fn parse(value: &str) -> Result<Self, ResourceMirError> {
        match value {
            "declare" => Ok(Self::Declare),
            "initialize" => Ok(Self::Initialize),
            "read" => Ok(Self::Read),
            "move" => Ok(Self::Move),
            "copy" => Ok(Self::Copy),
            "explicit_close" => Ok(Self::ExplicitClose),
            "schedule_cleanup" => Ok(Self::ScheduleCleanup),
            "invoke_destructor" => Ok(Self::InvokeDestructor),
            "mark_destroyed" => Ok(Self::MarkDestroyed),
            _ => Err(ResourceMirError::new(
                "resource_mir_unknown_operation",
                format!("unknown canonical resource operation {value}"),
            )),
        }
    }

    fn as_str(self) -> &'static str {
        match self {
            Self::Declare => "declare",
            Self::Initialize => "initialize",
            Self::Read => "read",
            Self::Move => "move",
            Self::Copy => "copy",
            Self::ExplicitClose => "explicit_close",
            Self::ScheduleCleanup => "schedule_cleanup",
            Self::InvokeDestructor => "invoke_destructor",
            Self::MarkDestroyed => "mark_destroyed",
        }
    }

    fn authority_operation(self) -> Option<&'static str> {
        match self {
            Self::Declare => None,
            Self::Initialize => Some("initialize"),
            Self::Read => Some("use"),
            Self::Move => Some("move"),
            Self::Copy => Some("copy"),
            Self::ExplicitClose => Some("manual_close"),
            Self::ScheduleCleanup => Some("schedule_cleanup"),
            Self::InvokeDestructor => Some("invoke_destructor"),
            Self::MarkDestroyed => Some("mark_destroyed"),
        }
    }

    fn requires_source(self) -> bool {
        matches!(
            self,
            Self::Read
                | Self::Move
                | Self::Copy
                | Self::ExplicitClose
                | Self::ScheduleCleanup
                | Self::InvokeDestructor
                | Self::MarkDestroyed
        )
    }

    fn requires_destination(self) -> bool {
        matches!(self, Self::Declare | Self::Initialize | Self::Move)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct ResourceValue {
    value_id: String,
    resource_id: String,
    resource_type_id: String,
    layout_id: String,
    owning_scope: String,
    source_location: String,
    current_state: String,
    destructor_id: String,
    close_capability_id: String,
    cleanup_policy: String,
    copy_policy: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct ResourceCarrier {
    carrier_id: String,
    resource_id: String,
    value_id: String,
    kind: String,
    storage_id: String,
    backend_symbol: String,
    owning_scope: String,
    source_location: String,
    resource_type_id: String,
    layout_id: String,
    current_state: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct ResourceOperation {
    operation_id: String,
    kind: ResourceOperationKind,
    resource_id: String,
    value_id: String,
    source_carrier_id: String,
    destination_carrier_id: String,
    program_point: String,
    prior_state: String,
    resulting_state: String,
    cleanup_id: String,
    destructor_id: String,
    close_capability_id: String,
    source_location: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct ResourceStorageState {
    found: bool,
    state: String,
    resource_id: String,
    move_site: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct ResourceEdge {
    edge_id: String,
    from_block: String,
    to_block: String,
    resource_id: String,
    value_id: String,
    program_point: String,
    state: String,
    is_loop_backedge: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct AuthorityResource {
    value_id: String,
    resource_type_id: String,
    resource_kind: String,
    layout_id: String,
    destructor_id: String,
    close_capability_id: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct AuthorityTransition {
    prior_state: String,
    resulting_state: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct AuthorityDestructor {
    resource_type_id: String,
    runtime_symbol: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct AuthorityCloseCapability {
    resource_type_id: String,
    runtime_symbol: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
struct AuthorityTables {
    resources: HashMap<String, AuthorityResource>,
    states: HashMap<(String, String), String>,
    transitions: HashMap<(String, String, String), AuthorityTransition>,
    cleanup_ids: HashSet<String>,
    cleanup_resources: HashMap<String, String>,
    destructors: HashMap<String, AuthorityDestructor>,
    close_capabilities: HashMap<String, AuthorityCloseCapability>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct ResourceMirTable {
    values: Vec<ResourceValue>,
    carriers: Vec<ResourceCarrier>,
    operations: Vec<ResourceOperation>,
    edges: Vec<ResourceEdge>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
enum CraneliftResourceAction {
    Declare {
        resource_id: String,
        carrier_id: String,
    },
    Initialize {
        resource_id: String,
        carrier_id: String,
    },
    Read {
        resource_id: String,
        carrier_id: String,
    },
    Move {
        resource_id: String,
        source_carrier_id: String,
        destination_carrier_id: String,
    },
    ExplicitClose {
        resource_id: String,
        carrier_id: String,
        runtime_symbol: String,
    },
    ScheduleCleanup {
        resource_id: String,
        carrier_id: String,
        cleanup_id: String,
    },
    InvokeDestructor {
        resource_id: String,
        carrier_id: String,
        cleanup_id: String,
        destructor_id: String,
        runtime_symbol: String,
    },
    MarkDestroyed {
        resource_id: String,
        carrier_id: String,
    },
}

fn required_field<'a>(
    fields: &'a HashMap<String, String>,
    key: &str,
) -> Result<&'a str, ResourceMirError> {
    let value = fields.get(key).ok_or_else(|| {
        ResourceMirError::new(
            "resource_mir_value_metadata_missing",
            format!("missing field {key}"),
        )
    })?;
    if value.is_empty() || value.contains('\n') || value.contains('\r') {
        return Err(ResourceMirError::new(
            "resource_mir_value_metadata_missing",
            format!("invalid field {key}"),
        ));
    }
    Ok(value)
}

fn optional_field<'a>(
    fields: &'a HashMap<String, String>,
    key: &str,
) -> Result<&'a str, ResourceMirError> {
    let value = fields.get(key).ok_or_else(|| {
        ResourceMirError::new(
            "resource_mir_operation_metadata_missing",
            format!("missing field {key}"),
        )
    })?;
    if value.contains('\n') || value.contains('\r') {
        return Err(ResourceMirError::new(
            "resource_mir_operation_metadata_missing",
            format!("invalid field {key}"),
        ));
    }
    Ok(value)
}

fn parse_count(fields: &HashMap<String, String>, key: &str) -> Result<usize, ResourceMirError> {
    required_field(fields, key)?.parse::<usize>().map_err(|_| {
        ResourceMirError::new(
            "resource_mir_value_metadata_missing",
            format!("{key} is not a non-negative count"),
        )
    })
}

fn parse_fields(contents: &str) -> Result<HashMap<String, String>, ResourceMirError> {
    let mut fields = HashMap::new();
    for line in contents.lines() {
        let Some((key, value)) = line.split_once(": ") else {
            continue;
        };
        if (key.starts_with("resource_mir_") || key.starts_with("resource_reassignment_"))
            && fields.insert(key.to_string(), value.to_string()).is_some()
        {
            return Err(ResourceMirError::new(
                "resource_mir_duplicate_serialized_field",
                format!("duplicate field {key}"),
            ));
        }
    }
    Ok(fields)
}

fn parse_record<'a>(payload: &'a str) -> Result<HashMap<&'a str, &'a str>, ResourceMirError> {
    let mut parts = HashMap::new();
    for field in payload.split(';') {
        let Some((key, value)) = field.split_once('=') else {
            return Err(ResourceMirError::new(
                "resource_mir_authority_record_invalid",
                format!("invalid authority field {field}"),
            ));
        };
        if parts.insert(key, value).is_some() {
            return Err(ResourceMirError::new(
                "resource_mir_authority_record_invalid",
                format!("duplicate authority field {key}"),
            ));
        }
    }
    Ok(parts)
}

fn required_part<'a>(
    parts: &'a HashMap<&str, &str>,
    key: &str,
) -> Result<&'a str, ResourceMirError> {
    let value = parts.get(key).copied().unwrap_or_default();
    if value.is_empty() {
        return Err(ResourceMirError::new(
            "resource_mir_authority_record_invalid",
            format!("authority record is missing {key}"),
        ));
    }
    Ok(value)
}

fn parse_authority_tables(contents: &str) -> Result<AuthorityTables, ResourceMirError> {
    let mut tables = AuthorityTables::default();
    for line in contents.lines() {
        if let Some(payload) = line.strip_prefix("resource_record: ") {
            let parts = parse_record(payload)?;
            let resource_id = required_part(&parts, "id")?;
            let resource = AuthorityResource {
                value_id: required_part(&parts, "value")?.to_string(),
                resource_type_id: required_part(&parts, "type")?.to_string(),
                resource_kind: required_part(&parts, "kind")?.to_string(),
                layout_id: required_part(&parts, "layout")?.to_string(),
                destructor_id: parts.get("destructor").copied().unwrap_or_default().to_string(),
                close_capability_id: parts.get("close").copied().unwrap_or_default().to_string(),
            };
            if tables
                .resources
                .insert(resource_id.to_string(), resource)
                .is_some()
            {
                return Err(ResourceMirError::new(
                    "resource_mir_duplicate_resource_identity",
                    format!("duplicate authority resource id {resource_id}"),
                ));
            }
            continue;
        }
        if let Some(payload) = line.strip_prefix("resource_state: ") {
            let parts = parse_record(payload)?;
            let resource_id = required_part(&parts, "resource")?;
            let program_point = required_part(&parts, "point")?;
            let state = required_part(&parts, "state")?;
            if tables
                .states
                .insert(
                    (resource_id.to_string(), program_point.to_string()),
                    state.to_string(),
                )
                .is_some()
            {
                return Err(ResourceMirError::new(
                    "resource_mir_duplicate_edge_state",
                    format!("duplicate authority state {resource_id}@{program_point}"),
                ));
            }
            continue;
        }
        if let Some(payload) = line.strip_prefix("resource_transition: ") {
            let parts = parse_record(payload)?;
            let resource_id = required_part(&parts, "resource")?;
            let operation = required_part(&parts, "operation")?;
            let program_point = required_part(&parts, "point")?;
            let transition = AuthorityTransition {
                prior_state: required_part(&parts, "prior")?.to_string(),
                resulting_state: required_part(&parts, "result")?.to_string(),
            };
            if tables
                .transitions
                .insert(
                    (
                        resource_id.to_string(),
                        operation.to_string(),
                        program_point.to_string(),
                    ),
                    transition,
                )
                .is_some()
            {
                return Err(ResourceMirError::new(
                    "resource_mir_impossible_state_transition",
                    format!(
                        "duplicate authority transition {resource_id}:{operation}@{program_point}"
                    ),
                ));
            }
            continue;
        }
        if let Some(payload) = line.strip_prefix("cleanup_record: ") {
            let parts = parse_record(payload)?;
            let cleanup_id = required_part(&parts, "id")?;
            let cleanup_resource_id = required_part(&parts, "resource")?;
            if !tables.cleanup_ids.insert(cleanup_id.to_string()) {
                return Err(ResourceMirError::new(
                    "resource_mir_cleanup_metadata_missing",
                    format!("duplicate cleanup id {cleanup_id}"),
                ));
            }
            tables.cleanup_resources.insert(
                cleanup_id.to_string(),
                cleanup_resource_id.to_string(),
            );
            continue;
        }
        if let Some(payload) = line.strip_prefix("destructor_record: ") {
            let parts = parse_record(payload)?;
            let destructor_id = required_part(&parts, "id")?;
            let destructor = AuthorityDestructor {
                resource_type_id: required_part(&parts, "type")?.to_string(),
                runtime_symbol: required_part(&parts, "runtime_symbol")?.to_string(),
            };
            if tables
                .destructors
                .insert(destructor_id.to_string(), destructor)
                .is_some()
            {
                return Err(ResourceMirError::new(
                    "resource_mir_destructor_policy_missing",
                    format!("duplicate destructor id {destructor_id}"),
                ));
            }
            continue;
        }
        if let Some(payload) = line.strip_prefix("close_capability_record: ") {
            let parts = parse_record(payload)?;
            let close_id = required_part(&parts, "id")?;
            let close = AuthorityCloseCapability {
                resource_type_id: required_part(&parts, "type")?.to_string(),
                runtime_symbol: required_part(&parts, "runtime_symbol")?.to_string(),
            };
            if tables
                .close_capabilities
                .insert(close_id.to_string(), close)
                .is_some()
            {
                return Err(ResourceMirError::new(
                    "resource_mir_close_policy_missing",
                    format!("duplicate close capability id {close_id}"),
                ));
            }
        }
    }
    Ok(tables)
}

fn validate_value_policy(
    value: &ResourceValue,
    authority: &AuthorityTables,
) -> Result<(), ResourceMirError> {
    if value.destructor_id.is_empty() && value.close_capability_id.is_empty() {
        return Err(ResourceMirError::new(
            "resource_mir_value_metadata_missing",
            format!("resource {} has no destructor or close policy", value.resource_id),
        ));
    }
    if !value.destructor_id.is_empty() {
        let destructor = authority
            .destructors
            .get(&value.destructor_id)
            .ok_or_else(|| {
                ResourceMirError::new(
                    "resource_mir_destructor_policy_missing",
                    format!("resource {} has an unknown destructor", value.resource_id),
                )
            })?;
        if destructor.resource_type_id != value.resource_type_id {
            return Err(ResourceMirError::new(
                "resource_mir_type_layout_identity_mismatch",
                format!("resource {} destructor type disagrees", value.resource_id),
            ));
        }
    }
    if !value.close_capability_id.is_empty() {
        let close = authority
            .close_capabilities
            .get(&value.close_capability_id)
            .ok_or_else(|| {
                ResourceMirError::new(
                    "resource_mir_close_policy_missing",
                    format!("resource {} has an unknown close capability", value.resource_id),
                )
            })?;
        if close.resource_type_id != value.resource_type_id {
            return Err(ResourceMirError::new(
                "resource_mir_type_layout_identity_mismatch",
                format!("resource {} close policy type disagrees", value.resource_id),
            ));
        }
    }
    Ok(())
}

fn validate_operation_transition(
    operation: &ResourceOperation,
    authority: &AuthorityTables,
) -> Result<(), ResourceMirError> {
    if operation.kind == ResourceOperationKind::Declare {
        if operation.prior_state != "uninitialized"
            || operation.resulting_state != "uninitialized"
        {
            return Err(ResourceMirError::new(
                "resource_mir_declaration_state_invalid",
                format!("operation {} has an invalid declaration state", operation.operation_id),
            ));
        }
        let state = authority
            .states
            .get(&(operation.resource_id.clone(), operation.program_point.clone()))
            .ok_or_else(|| {
                ResourceMirError::new(
                    "resource_mir_state_missing_at_program_point",
                    format!("operation {} has no authority state", operation.operation_id),
                )
            })?;
        if state != "uninitialized" {
            return Err(ResourceMirError::new(
                "resource_mir_state_missing_at_program_point",
                format!("operation {} authority state disagrees", operation.operation_id),
            ));
        }
        return Ok(());
    }

    let authority_operation = operation.kind.authority_operation().ok_or_else(|| {
        ResourceMirError::new(
            "resource_mir_unknown_operation",
            format!("operation {} has no authority mapping", operation.operation_id),
        )
    })?;
    let transition = authority
        .transitions
        .get(&(
            operation.resource_id.clone(),
            authority_operation.to_string(),
            operation.program_point.clone(),
        ))
        .ok_or_else(|| {
            ResourceMirError::new(
                "resource_mir_state_missing_at_program_point",
                format!("operation {} has no authority transition", operation.operation_id),
            )
        })?;
    if transition.prior_state != operation.prior_state
        || transition.resulting_state != operation.resulting_state
    {
        return Err(ResourceMirError::new(
            "resource_mir_impossible_state_transition",
            format!("operation {} disagrees with compiler authority", operation.operation_id),
        ));
    }
    Ok(())
}

fn transition_from_state(
    prior: &str,
    operation: &str,
) -> Result<&'static str, &'static str> {
    match operation {
        "copy" => Err("resource_copy_of_move_only"),
        "initialize" => match prior {
            "uninitialized" => Ok("live"),
            "moved" => Err("resource_reinitialize_requires_fresh_identity"),
            "live" => Err("resource_reinitialize_live"),
            _ => Err("resource_reinitialize_terminal"),
        },
        "use" => match prior {
            "live" => Ok("live"),
            "moved" => Err("resource_use_after_move"),
            "uninitialized" => Err("resource_use_before_initialization"),
            _ => Err("resource_use_after_terminal_state"),
        },
        "move" => match prior {
            "live" => Ok("moved"),
            "moved" => Err("resource_second_move"),
            "uninitialized" => Err("resource_move_from_uninitialized"),
            _ => Err("resource_move_after_terminal_state"),
        },
        "manual_close" => match prior {
            "live" => Ok("manually_closed"),
            "moved" => Err("resource_close_after_move"),
            "uninitialized" => Err("resource_close_before_initialization"),
            _ => Err("resource_close_after_terminal_state"),
        },
        "schedule_cleanup" => match prior {
            "live" => Ok("cleanup_scheduled"),
            "moved" => Err("resource_cleanup_after_move"),
            _ => Err("resource_cleanup_after_terminal_state"),
        },
        "invoke_destructor" => match prior {
            "cleanup_scheduled" => Ok("destroyed"),
            "moved" => Err("resource_destructor_after_move"),
            _ => Err("resource_destructor_without_scheduled_cleanup"),
        },
        "mark_destroyed" => match prior {
            "cleanup_scheduled" | "manually_closed" => Ok("destroyed"),
            _ => Err("resource_destroy_without_close_or_cleanup"),
        },
        _ => Err("resource_impossible_state_transition"),
    }
}

fn carrier_state_before(
    operations: &[ResourceOperation],
    carrier_id: &str,
    operation_limit: usize,
) -> String {
    let mut state = "uninitialized".to_string();
    for operation in operations.iter().take(operation_limit) {
        if operation.destination_carrier_id == carrier_id {
            match operation.kind {
                ResourceOperationKind::Declare => state = "uninitialized".to_string(),
                ResourceOperationKind::Initialize => state = operation.resulting_state.clone(),
                ResourceOperationKind::Move => state = "live".to_string(),
                _ => {}
            }
        }
        if operation.source_carrier_id == carrier_id {
            match operation.kind {
                ResourceOperationKind::Move => state = "moved".to_string(),
                ResourceOperationKind::Read => {}
                _ => state = operation.resulting_state.clone(),
            }
        }
    }
    state
}

fn storage_state_before(
    operations: &[ResourceOperation],
    carriers_by_id: &HashMap<&str, &ResourceCarrier>,
    storage_id: &str,
    operation_limit: usize,
) -> ResourceStorageState {
    let mut result = ResourceStorageState {
        found: false,
        state: "uninitialized".to_string(),
        resource_id: String::new(),
        move_site: String::new(),
    };
    for operation in operations.iter().take(operation_limit) {
        if let Some(destination) = carriers_by_id.get(operation.destination_carrier_id.as_str()) {
            if destination.storage_id == storage_id {
                match operation.kind {
                    ResourceOperationKind::Declare => {
                        result.found = true;
                        result.state = "uninitialized".to_string();
                        result.resource_id = operation.resource_id.clone();
                        result.move_site.clear();
                    }
                    ResourceOperationKind::Initialize => {
                        result.found = true;
                        result.state = operation.resulting_state.clone();
                        result.resource_id = operation.resource_id.clone();
                        result.move_site.clear();
                    }
                    ResourceOperationKind::Move => {
                        result.found = true;
                        result.state = "live".to_string();
                        result.resource_id = operation.resource_id.clone();
                        result.move_site.clear();
                    }
                    _ => {}
                }
            }
        }
        if let Some(source) = carriers_by_id.get(operation.source_carrier_id.as_str()) {
            if source.storage_id == storage_id {
                result.found = true;
                result.resource_id = operation.resource_id.clone();
                match operation.kind {
                    ResourceOperationKind::Move => {
                        result.state = "moved".to_string();
                        result.move_site = operation.source_location.clone();
                    }
                    ResourceOperationKind::Read => {}
                    _ => result.state = operation.resulting_state.clone(),
                }
            }
        }
    }
    result
}

fn validate_reinitialization(
    previous_resource_id: &str,
    new_resource_id: &str,
    prior_storage_state: &str,
) -> Result<&'static str, &'static str> {
    if previous_resource_id.is_empty() || new_resource_id.is_empty() {
        return Err("resource_reinitialize_identity_missing");
    }
    if prior_storage_state != "moved" {
        return Err("resource_reinitialize_storage_not_moved");
    }
    if previous_resource_id == new_resource_id {
        return Err("resource_reinitialize_requires_fresh_identity");
    }
    Ok("live")
}

fn last_move_site(
    operations: &[ResourceOperation],
    carrier_id: &str,
    operation_limit: usize,
) -> String {
    let mut site = String::new();
    for operation in operations.iter().take(operation_limit) {
        if operation.kind == ResourceOperationKind::Move
            && operation.source_carrier_id == carrier_id
        {
            site = operation.source_location.clone();
        }
        if operation.kind == ResourceOperationKind::Initialize
            && operation.destination_carrier_id == carrier_id
        {
            site.clear();
        }
    }
    site
}

fn move_form_name(source: &str, destination: &str) -> &'static str {
    match (source, destination) {
        ("local", "local") => "local_to_local",
        ("local", "aggregate_field") => "local_to_aggregate_field",
        ("aggregate_field", "local") => "aggregate_field_to_local",
        ("local", "stack_slot") | ("stack_slot", "local") => "stack_slot_transport",
        _ if source == "loop_carry" || destination == "loop_carry" => {
            "selected_loop_carried_move"
        }
        _ if source == "branch_argument" || destination == "branch_argument" => {
            "branch_edge_move"
        }
        _ => "unsupported_move_form",
    }
}

fn move_form_is_supported(source: &str, destination: &str) -> bool {
    move_form_name(source, destination) != "unsupported_move_form"
}

fn move_state_error(
    reason_code: &'static str,
    operation: &ResourceOperation,
    operations: &[ResourceOperation],
    operation_index: usize,
    values_by_id: &HashMap<&str, &ResourceValue>,
    prior_state: &str,
    attempted_operation: &str,
) -> ResourceMirError {
    let declaration = values_by_id
        .get(operation.value_id.as_str())
        .map(|value| value.source_location.as_str())
        .unwrap_or_default();
    let move_site = last_move_site(
        operations,
        operation.source_carrier_id.as_str(),
        operation_index,
    );
    ResourceMirError::new(
        reason_code,
        format!(
            "resource_move_diagnostic: resource={} declaration={} move_site={} invalid_use_site={} prior_state={} attempted_operation={}",
            operation.resource_id,
            declaration,
            move_site,
            operation.source_location,
            prior_state,
            attempted_operation,
        ),
    )
}

fn validate_move_state(
    operations: &[ResourceOperation],
    carriers_by_id: &HashMap<&str, &ResourceCarrier>,
    values_by_id: &HashMap<&str, &ResourceValue>,
) -> Result<(), ResourceMirError> {
    for (index, operation) in operations.iter().enumerate() {
        match operation.kind {
            ResourceOperationKind::Declare => {
                let destination_state = carrier_state_before(
                    operations,
                    operation.destination_carrier_id.as_str(),
                    index,
                );
                if destination_state != "uninitialized" {
                    return Err(move_state_error(
                        "resource_declaration_overwrites_initialized_storage",
                        operation,
                        operations,
                        index,
                        values_by_id,
                        &destination_state,
                        "declare",
                    ));
                }
            }
            ResourceOperationKind::Initialize => {
                let destination = carriers_by_id
                    .get(operation.destination_carrier_id.as_str())
                    .ok_or_else(|| {
                        move_state_error(
                            "resource_move_carrier_missing",
                            operation,
                            operations,
                            index,
                            values_by_id,
                            "uninitialized",
                            "initialize",
                        )
                    })?;
                let destination_state = carrier_state_before(
                    operations,
                    operation.destination_carrier_id.as_str(),
                    index,
                );
                if destination_state != operation.prior_state {
                    return Err(move_state_error(
                        "resource_reinitialization_state_mismatch",
                        operation,
                        operations,
                        index,
                        values_by_id,
                        &destination_state,
                        "initialize",
                    ));
                }
                if let Err(reason) = transition_from_state(&destination_state, "initialize") {
                    return Err(move_state_error(
                        reason,
                        operation,
                        operations,
                        index,
                        values_by_id,
                        &destination_state,
                        "initialize",
                    ));
                }
                let storage_state = storage_state_before(
                    operations,
                    carriers_by_id,
                    destination.storage_id.as_str(),
                    index,
                );
                if storage_state.found && storage_state.state == "moved" {
                    if let Err(reason) = validate_reinitialization(
                        storage_state.resource_id.as_str(),
                        operation.resource_id.as_str(),
                        storage_state.state.as_str(),
                    ) {
                        let declaration = values_by_id
                            .get(operation.value_id.as_str())
                            .map(|value| value.source_location.as_str())
                            .unwrap_or_default();
                        return Err(ResourceMirError::new(
                            reason,
                            format!(
                                "resource_move_diagnostic: resource={} declaration={} move_site={} invalid_use_site={} prior_state={} attempted_operation=initialize",
                                operation.resource_id,
                                declaration,
                                storage_state.move_site,
                                operation.source_location,
                                storage_state.state,
                            ),
                        ));
                    }
                } else if storage_state.found
                    && storage_state.resource_id != operation.resource_id
                    && !matches!(storage_state.state.as_str(), "uninitialized" | "destroyed")
                {
                    return Err(move_state_error(
                        "resource_reinitialize_storage_not_moved",
                        operation,
                        operations,
                        index,
                        values_by_id,
                        &storage_state.state,
                        "initialize",
                    ));
                }
            }
            _ => {
                let source_state = carrier_state_before(
                    operations,
                    operation.source_carrier_id.as_str(),
                    index,
                );
                let attempted = operation.kind.authority_operation().unwrap_or("unknown");
                if source_state != operation.prior_state {
                    let reason = transition_from_state(&source_state, attempted)
                        .err()
                        .unwrap_or("resource_move_state_trace_disagreement");
                    return Err(move_state_error(
                        reason,
                        operation,
                        operations,
                        index,
                        values_by_id,
                        &source_state,
                        attempted,
                    ));
                }
                match transition_from_state(&source_state, attempted) {
                    Ok(result) if result == operation.resulting_state => {}
                    Ok(_) => {
                        return Err(move_state_error(
                            "resource_move_state_trace_disagreement",
                            operation,
                            operations,
                            index,
                            values_by_id,
                            &source_state,
                            attempted,
                        ));
                    }
                    Err(reason) => {
                        return Err(move_state_error(
                            reason,
                            operation,
                            operations,
                            index,
                            values_by_id,
                            &source_state,
                            attempted,
                        ));
                    }
                }
                if operation.kind == ResourceOperationKind::Move {
                    let source = carriers_by_id
                        .get(operation.source_carrier_id.as_str())
                        .ok_or_else(|| {
                            move_state_error(
                                "resource_move_carrier_missing",
                                operation,
                                operations,
                                index,
                                values_by_id,
                                &source_state,
                                "move",
                            )
                        })?;
                    let destination = carriers_by_id
                        .get(operation.destination_carrier_id.as_str())
                        .ok_or_else(|| {
                            move_state_error(
                                "resource_move_carrier_missing",
                                operation,
                                operations,
                                index,
                                values_by_id,
                                &source_state,
                                "move",
                            )
                        })?;
                    if !move_form_is_supported(&source.kind, &destination.kind) {
                        return Err(move_state_error(
                            "resource_move_form_unsupported",
                            operation,
                            operations,
                            index,
                            values_by_id,
                            &source_state,
                            "move",
                        ));
                    }
                    let destination_state = carrier_state_before(
                        operations,
                        operation.destination_carrier_id.as_str(),
                        index,
                    );
                    if !matches!(destination_state.as_str(), "uninitialized" | "moved" | "destroyed") {
                        return Err(move_state_error(
                            "resource_move_destination_not_empty",
                            operation,
                            operations,
                            index,
                            values_by_id,
                            &destination_state,
                            "move",
                        ));
                    }
                }
            }
        }
    }
    Ok(())
}

fn parse_resource_mir(
    contents: &str,
) -> Result<(ResourceMirTable, AuthorityTables), ResourceMirError> {
    let fields = parse_fields(contents)?;
    if required_field(&fields, "resource_mir_format")? != FORMAT
        || required_field(&fields, "resource_mir_semantic_authority")? != SEMANTIC_AUTHORITY
        || required_field(&fields, "resource_mir_identity_policy")? != IDENTITY_POLICY
        || required_field(&fields, "resource_mir_copy_policy")? != COPY_POLICY
        || required_field(&fields, "resource_mir_edge_state_policy")? != EDGE_STATE_POLICY
        || required_field(&fields, "resource_mir_move_state_policy")? != MOVE_STATE_POLICY
    {
        return Err(ResourceMirError::new(
            "resource_mir_unknown_format_or_policy",
            "resource MIR format or policy mismatch",
        ));
    }

    let authority = parse_authority_tables(contents)?;
    let value_count = parse_count(&fields, "resource_mir_value_count")?;
    let carrier_count = parse_count(&fields, "resource_mir_carrier_count")?;
    let operation_count = parse_count(&fields, "resource_mir_operation_count")?;
    let edge_count = parse_count(&fields, "resource_mir_edge_count")?;

    let mut values = Vec::with_capacity(value_count);
    let mut seen_resource_ids = HashSet::new();
    let mut seen_value_ids = HashSet::new();
    for index in 0..value_count {
        let prefix = format!("resource_mir_value_{index}");
        let value = ResourceValue {
            value_id: required_field(&fields, &format!("{prefix}_value_id"))?.to_string(),
            resource_id: required_field(&fields, &format!("{prefix}_resource_id"))?.to_string(),
            resource_type_id: required_field(&fields, &format!("{prefix}_resource_type_id"))?
                .to_string(),
            layout_id: required_field(&fields, &format!("{prefix}_layout_id"))?.to_string(),
            owning_scope: required_field(&fields, &format!("{prefix}_owning_scope"))?
                .to_string(),
            source_location: required_field(&fields, &format!("{prefix}_source_location"))?
                .to_string(),
            current_state: required_field(&fields, &format!("{prefix}_current_state"))?
                .to_string(),
            destructor_id: optional_field(&fields, &format!("{prefix}_destructor_id"))?
                .to_string(),
            close_capability_id: optional_field(
                &fields,
                &format!("{prefix}_close_capability_id"),
            )?
            .to_string(),
            cleanup_policy: required_field(&fields, &format!("{prefix}_cleanup_policy"))?
                .to_string(),
            copy_policy: required_field(&fields, &format!("{prefix}_copy_policy"))?.to_string(),
        };
        if value.copy_policy != "non_copy_resource" {
            return Err(ResourceMirError::new(
                "resource_mir_copy_forbidden",
                format!("resource {} is not marked non-copy", value.resource_id),
            ));
        }
        if !seen_resource_ids.insert(value.resource_id.clone())
            || !seen_value_ids.insert(value.value_id.clone())
        {
            return Err(ResourceMirError::new(
                "resource_mir_duplicate_resource_identity",
                format!("duplicate resource or value identity at index {index}"),
            ));
        }
        let authority_resource = authority.resources.get(&value.resource_id).ok_or_else(|| {
            ResourceMirError::new(
                "resource_mir_value_metadata_missing",
                format!("resource {} is absent from compiler authority", value.resource_id),
            )
        })?;
        if authority_resource.value_id != value.value_id
            || authority_resource.resource_type_id != value.resource_type_id
            || authority_resource.layout_id != value.layout_id
            || authority_resource.destructor_id != value.destructor_id
            || authority_resource.close_capability_id != value.close_capability_id
        {
            return Err(ResourceMirError::new(
                "resource_mir_type_layout_identity_mismatch",
                format!("resource {} disagrees with compiler authority", value.resource_id),
            ));
        }
        validate_value_policy(&value, &authority)?;
        values.push(value);
    }

    let values_by_id: HashMap<&str, &ResourceValue> = values
        .iter()
        .map(|value| (value.value_id.as_str(), value))
        .collect();
    let mut carriers = Vec::with_capacity(carrier_count);
    let mut seen_carrier_ids = HashSet::new();
    for index in 0..carrier_count {
        let prefix = format!("resource_mir_carrier_{index}");
        let carrier = ResourceCarrier {
            carrier_id: required_field(&fields, &format!("{prefix}_carrier_id"))?.to_string(),
            resource_id: required_field(&fields, &format!("{prefix}_resource_id"))?.to_string(),
            value_id: required_field(&fields, &format!("{prefix}_value_id"))?.to_string(),
            kind: required_field(&fields, &format!("{prefix}_kind"))?.to_string(),
            storage_id: required_field(&fields, &format!("{prefix}_storage_id"))?.to_string(),
            backend_symbol: required_field(&fields, &format!("{prefix}_backend_symbol"))?
                .to_string(),
            owning_scope: required_field(&fields, &format!("{prefix}_owning_scope"))?
                .to_string(),
            source_location: required_field(&fields, &format!("{prefix}_source_location"))?
                .to_string(),
            resource_type_id: required_field(&fields, &format!("{prefix}_resource_type_id"))?
                .to_string(),
            layout_id: required_field(&fields, &format!("{prefix}_layout_id"))?.to_string(),
            current_state: required_field(&fields, &format!("{prefix}_current_state"))?
                .to_string(),
        };
        if !matches!(
            carrier.kind.as_str(),
            "local" | "stack_slot" | "branch_argument" | "loop_carry" | "aggregate_field"
        ) {
            return Err(ResourceMirError::new(
                "resource_mir_carrier_metadata_missing",
                format!("unknown carrier kind {}", carrier.kind),
            ));
        }
        if !seen_carrier_ids.insert(carrier.carrier_id.clone()) {
            return Err(ResourceMirError::new(
                "resource_mir_duplicate_carrier_id",
                format!("duplicate carrier {}", carrier.carrier_id),
            ));
        }
        let value = values_by_id.get(carrier.value_id.as_str()).ok_or_else(|| {
            ResourceMirError::new(
                "resource_mir_carrier_identity_mismatch",
                format!("carrier {} has unknown value", carrier.carrier_id),
            )
        })?;
        if carrier.resource_id != value.resource_id
            || carrier.resource_type_id != value.resource_type_id
            || carrier.layout_id != value.layout_id
            || carrier.owning_scope != value.owning_scope
        {
            return Err(ResourceMirError::new(
                "resource_mir_carrier_identity_mismatch",
                format!("carrier {} changed resource identity", carrier.carrier_id),
            ));
        }
        carriers.push(carrier);
    }

    let carriers_by_id: HashMap<&str, &ResourceCarrier> = carriers
        .iter()
        .map(|carrier| (carrier.carrier_id.as_str(), carrier))
        .collect();
    let mut operations = Vec::with_capacity(operation_count);
    let mut seen_operation_ids = HashSet::new();
    for index in 0..operation_count {
        let prefix = format!("resource_mir_operation_{index}");
        let kind = ResourceOperationKind::parse(required_field(
            &fields,
            &format!("{prefix}_kind"),
        )?)?;
        let operation = ResourceOperation {
            operation_id: required_field(&fields, &format!("{prefix}_operation_id"))?
                .to_string(),
            kind,
            resource_id: required_field(&fields, &format!("{prefix}_resource_id"))?.to_string(),
            value_id: required_field(&fields, &format!("{prefix}_value_id"))?.to_string(),
            source_carrier_id: optional_field(
                &fields,
                &format!("{prefix}_source_carrier_id"),
            )?
            .to_string(),
            destination_carrier_id: optional_field(
                &fields,
                &format!("{prefix}_destination_carrier_id"),
            )?
            .to_string(),
            program_point: required_field(&fields, &format!("{prefix}_program_point"))?
                .to_string(),
            prior_state: required_field(&fields, &format!("{prefix}_prior_state"))?.to_string(),
            resulting_state: required_field(&fields, &format!("{prefix}_resulting_state"))?
                .to_string(),
            cleanup_id: optional_field(&fields, &format!("{prefix}_cleanup_id"))?.to_string(),
            destructor_id: optional_field(&fields, &format!("{prefix}_destructor_id"))?
                .to_string(),
            close_capability_id: optional_field(
                &fields,
                &format!("{prefix}_close_capability_id"),
            )?
            .to_string(),
            source_location: required_field(&fields, &format!("{prefix}_source_location"))?
                .to_string(),
        };
        if !seen_operation_ids.insert(operation.operation_id.clone()) {
            return Err(ResourceMirError::new(
                "resource_mir_duplicate_operation_id",
                format!("duplicate operation {}", operation.operation_id),
            ));
        }
        let value = values_by_id.get(operation.value_id.as_str()).ok_or_else(|| {
            ResourceMirError::new(
                "resource_mir_operation_identity_mismatch",
                format!("operation {} has unknown value", operation.operation_id),
            )
        })?;
        if operation.resource_id != value.resource_id {
            return Err(ResourceMirError::new(
                "resource_mir_operation_identity_mismatch",
                format!("operation {} changed resource id", operation.operation_id),
            ));
        }
        if kind.requires_source() {
            let source = carriers_by_id
                .get(operation.source_carrier_id.as_str())
                .ok_or_else(|| {
                    ResourceMirError::new(
                        "resource_mir_operation_source_missing",
                        format!("operation {} has no source carrier", operation.operation_id),
                    )
                })?;
            if source.resource_id != operation.resource_id {
                return Err(ResourceMirError::new(
                    "resource_mir_operation_identity_mismatch",
                    format!("operation {} source changed identity", operation.operation_id),
                ));
            }
        } else if !operation.source_carrier_id.is_empty() {
            return Err(ResourceMirError::new(
                "resource_mir_operation_source_invalid",
                format!("operation {} has an unexpected source", operation.operation_id),
            ));
        }
        if kind.requires_destination() {
            let destination = carriers_by_id
                .get(operation.destination_carrier_id.as_str())
                .ok_or_else(|| {
                    ResourceMirError::new(
                        "resource_mir_operation_destination_missing",
                        format!(
                            "operation {} has no destination carrier",
                            operation.operation_id
                        ),
                    )
                })?;
            if destination.resource_id != operation.resource_id {
                return Err(ResourceMirError::new(
                    "resource_mir_operation_identity_mismatch",
                    format!(
                        "operation {} destination changed identity",
                        operation.operation_id
                    ),
                ));
            }
        } else if !operation.destination_carrier_id.is_empty() {
            return Err(ResourceMirError::new(
                "resource_mir_operation_destination_invalid",
                format!("operation {} has an unexpected destination", operation.operation_id),
            ));
        }
        if kind == ResourceOperationKind::Move
            && operation.source_carrier_id == operation.destination_carrier_id
        {
            return Err(ResourceMirError::new(
                "resource_mir_move_requires_distinct_carriers",
                format!("operation {} moves to itself", operation.operation_id),
            ));
        }
        if matches!(
            kind,
            ResourceOperationKind::ScheduleCleanup | ResourceOperationKind::InvokeDestructor
        ) && (!authority.cleanup_ids.contains(&operation.cleanup_id)
            || operation.cleanup_id.is_empty())
        {
            return Err(ResourceMirError::new(
                "resource_mir_cleanup_metadata_missing",
                format!("operation {} has no known cleanup id", operation.operation_id),
            ));
        }
        if kind == ResourceOperationKind::ExplicitClose
            && (operation.close_capability_id.is_empty()
                || operation.close_capability_id != value.close_capability_id)
        {
            return Err(ResourceMirError::new(
                "resource_mir_close_policy_missing",
                format!("operation {} has no matching close capability", operation.operation_id),
            ));
        }
        if kind == ResourceOperationKind::InvokeDestructor
            && (operation.destructor_id.is_empty()
                || operation.destructor_id != value.destructor_id)
        {
            return Err(ResourceMirError::new(
                "resource_mir_destructor_policy_missing",
                format!("operation {} has no matching destructor", operation.operation_id),
            ));
        }
        operations.push(operation);
    }

    validate_move_state(&operations, &carriers_by_id, &values_by_id)?;
    for operation in &operations {
        validate_operation_transition(operation, &authority)?;
    }

    let mut final_states: HashMap<&str, &str> = HashMap::new();
    for operation in &operations {
        final_states.insert(&operation.resource_id, &operation.resulting_state);
    }
    for value in &values {
        if final_states.get(value.resource_id.as_str()).copied()
            != Some(value.current_state.as_str())
        {
            return Err(ResourceMirError::new(
                "resource_mir_current_state_mismatch",
                format!("resource {} final state disagrees", value.resource_id),
            ));
        }
    }

    let mut edges = Vec::with_capacity(edge_count);
    let mut seen_edges = HashSet::new();
    for index in 0..edge_count {
        let prefix = format!("resource_mir_edge_{index}");
        let state_key = format!("{prefix}_state");
        let state = fields.get(&state_key).cloned().ok_or_else(|| {
            ResourceMirError::new(
                "resource_mir_state_missing_at_control_flow_edge",
                format!("edge {index} has no resource state"),
            )
        })?;
        if state.is_empty() || state.contains('\n') || state.contains('\r') {
            return Err(ResourceMirError::new(
                "resource_mir_state_missing_at_control_flow_edge",
                format!("edge {index} has no resource state"),
            ));
        }
        let is_loop_backedge =
            match required_field(&fields, &format!("{prefix}_is_loop_backedge"))? {
                "0" => false,
                "1" => true,
                value => {
                    return Err(ResourceMirError::new(
                        "resource_mir_state_missing_at_control_flow_edge",
                        format!("invalid loop-backedge marker {value}"),
                    ));
                }
            };
        let edge = ResourceEdge {
            edge_id: required_field(&fields, &format!("{prefix}_edge_id"))?.to_string(),
            from_block: required_field(&fields, &format!("{prefix}_from_block"))?.to_string(),
            to_block: required_field(&fields, &format!("{prefix}_to_block"))?.to_string(),
            resource_id: required_field(&fields, &format!("{prefix}_resource_id"))?.to_string(),
            value_id: required_field(&fields, &format!("{prefix}_value_id"))?.to_string(),
            program_point: required_field(&fields, &format!("{prefix}_program_point"))?
                .to_string(),
            state,
            is_loop_backedge,
        };
        let value = values_by_id.get(edge.value_id.as_str()).ok_or_else(|| {
            ResourceMirError::new(
                "resource_mir_edge_identity_mismatch",
                format!("edge {} has unknown value", edge.edge_id),
            )
        })?;
        if edge.resource_id != value.resource_id {
            return Err(ResourceMirError::new(
                "resource_mir_edge_identity_mismatch",
                format!("edge {} changed resource identity", edge.edge_id),
            ));
        }
        let authority_state = authority
            .states
            .get(&(edge.resource_id.clone(), edge.program_point.clone()))
            .ok_or_else(|| {
                ResourceMirError::new(
                    "resource_mir_state_missing_at_control_flow_edge",
                    format!("edge {} has no compiler authority state", edge.edge_id),
                )
            })?;
        if authority_state != &edge.state {
            return Err(ResourceMirError::new(
                "resource_mir_state_missing_at_control_flow_edge",
                format!("edge {} state disagrees with compiler authority", edge.edge_id),
            ));
        }
        if !seen_edges.insert((edge.edge_id.clone(), edge.resource_id.clone())) {
            return Err(ResourceMirError::new(
                "resource_mir_duplicate_edge_state",
                format!("duplicate edge state {}", edge.edge_id),
            ));
        }
        edges.push(edge);
    }

    for (left_index, left) in edges.iter().enumerate() {
        for right in edges.iter().skip(left_index + 1) {
            if left.to_block == right.to_block
                && left.resource_id == right.resource_id
                && left.state != right.state
            {
                return Err(ResourceMirError::new(
                    "resource_move_join_state_inconsistent",
                    format!(
                        "resource_move_diagnostic: resource={} declaration={} move_site={} invalid_use_site={} prior_state={} attempted_operation=join_states",
                        right.resource_id,
                        values_by_id
                            .get(right.value_id.as_str())
                            .map(|value| value.source_location.as_str())
                            .unwrap_or_default(),
                        "",
                        right.program_point,
                        right.state,
                    ),
                ));
            }
        }
    }

    Ok((
        ResourceMirTable {
            values,
            carriers,
            operations,
            edges,
        },
        authority,
    ))
}

fn lower_for_cranelift(
    table: &ResourceMirTable,
    authority: &AuthorityTables,
) -> Result<Vec<CraneliftResourceAction>, ResourceMirError> {
    let mut actions = Vec::with_capacity(table.operations.len());
    for operation in &table.operations {
        let action = match operation.kind {
            ResourceOperationKind::Declare => CraneliftResourceAction::Declare {
                resource_id: operation.resource_id.clone(),
                carrier_id: operation.destination_carrier_id.clone(),
            },
            ResourceOperationKind::Initialize => CraneliftResourceAction::Initialize {
                resource_id: operation.resource_id.clone(),
                carrier_id: operation.destination_carrier_id.clone(),
            },
            ResourceOperationKind::Read => CraneliftResourceAction::Read {
                resource_id: operation.resource_id.clone(),
                carrier_id: operation.source_carrier_id.clone(),
            },
            ResourceOperationKind::Move => CraneliftResourceAction::Move {
                resource_id: operation.resource_id.clone(),
                source_carrier_id: operation.source_carrier_id.clone(),
                destination_carrier_id: operation.destination_carrier_id.clone(),
            },
            ResourceOperationKind::Copy => {
                return Err(ResourceMirError::new(
                    "resource_copy_of_move_only",
                    format!("copy operation {} reached Cranelift lowering", operation.operation_id),
                ));
            }
            ResourceOperationKind::ExplicitClose => {
                let close = authority
                    .close_capabilities
                    .get(&operation.close_capability_id)
                    .ok_or_else(|| {
                        ResourceMirError::new(
                            "resource_mir_close_policy_missing",
                            format!("operation {} has no close runtime symbol", operation.operation_id),
                        )
                    })?;
                CraneliftResourceAction::ExplicitClose {
                    resource_id: operation.resource_id.clone(),
                    carrier_id: operation.source_carrier_id.clone(),
                    runtime_symbol: close.runtime_symbol.clone(),
                }
            }
            ResourceOperationKind::ScheduleCleanup => {
                CraneliftResourceAction::ScheduleCleanup {
                    resource_id: operation.resource_id.clone(),
                    carrier_id: operation.source_carrier_id.clone(),
                    cleanup_id: operation.cleanup_id.clone(),
                }
            }
            ResourceOperationKind::InvokeDestructor => {
                let destructor = authority
                    .destructors
                    .get(&operation.destructor_id)
                    .ok_or_else(|| {
                        ResourceMirError::new(
                            "resource_mir_destructor_policy_missing",
                            format!(
                                "operation {} has no destructor runtime symbol",
                                operation.operation_id
                            ),
                        )
                    })?;
                CraneliftResourceAction::InvokeDestructor {
                    resource_id: operation.resource_id.clone(),
                    carrier_id: operation.source_carrier_id.clone(),
                    cleanup_id: operation.cleanup_id.clone(),
                    destructor_id: operation.destructor_id.clone(),
                    runtime_symbol: destructor.runtime_symbol.clone(),
                }
            }
            ResourceOperationKind::MarkDestroyed => CraneliftResourceAction::MarkDestroyed {
                resource_id: operation.resource_id.clone(),
                carrier_id: operation.source_carrier_id.clone(),
            },
        };
        actions.push(action);
    }
    Ok(actions)
}

fn witness(table: &ResourceMirTable, actions: &[CraneliftResourceAction]) -> String {
    let mut output = String::from("resource_mir_witness: accepted\n");
    for value in &table.values {
        output.push_str(&format!(
            "resource_value: value={} resource={} type={} layout={} scope={} state={}\n",
            value.value_id,
            value.resource_id,
            value.resource_type_id,
            value.layout_id,
            value.owning_scope,
            value.current_state,
        ));
    }
    for carrier in &table.carriers {
        output.push_str(&format!(
            "resource_carrier: id={} kind={} resource={} storage={} state={}\n",
            carrier.carrier_id,
            carrier.kind,
            carrier.resource_id,
            carrier.storage_id,
            carrier.current_state,
        ));
    }
    for operation in &table.operations {
        output.push_str(&format!(
            "resource_operation: id={} kind={} resource={} source={} destination={} prior={} result={}\n",
            operation.operation_id,
            operation.kind.as_str(),
            operation.resource_id,
            operation.source_carrier_id,
            operation.destination_carrier_id,
            operation.prior_state,
            operation.resulting_state,
        ));
    }
    for edge in &table.edges {
        output.push_str(&format!(
            "resource_edge: id={} from={} to={} resource={} state={} loop_backedge={}\n",
            edge.edge_id,
            edge.from_block,
            edge.to_block,
            edge.resource_id,
            edge.state,
            usize::from(edge.is_loop_backedge),
        ));
    }
    for (operation, action) in table.operations.iter().zip(actions) {
        let (action_name, resource_id, source, destination, runtime_symbol, cleanup_id) =
            match action {
                CraneliftResourceAction::Declare { resource_id, carrier_id } => (
                    "declare", resource_id.as_str(), "", carrier_id.as_str(), "", "",
                ),
                CraneliftResourceAction::Initialize { resource_id, carrier_id } => (
                    "initialize", resource_id.as_str(), "", carrier_id.as_str(), "", "",
                ),
                CraneliftResourceAction::Read { resource_id, carrier_id } => (
                    "read", resource_id.as_str(), carrier_id.as_str(), "", "", "",
                ),
                CraneliftResourceAction::Move {
                    resource_id,
                    source_carrier_id,
                    destination_carrier_id,
                } => (
                    "move",
                    resource_id.as_str(),
                    source_carrier_id.as_str(),
                    destination_carrier_id.as_str(),
                    "",
                    "",
                ),
                CraneliftResourceAction::ExplicitClose {
                    resource_id,
                    carrier_id,
                    runtime_symbol,
                } => (
                    "explicit_close",
                    resource_id.as_str(),
                    carrier_id.as_str(),
                    "",
                    runtime_symbol.as_str(),
                    "",
                ),
                CraneliftResourceAction::ScheduleCleanup {
                    resource_id,
                    carrier_id,
                    cleanup_id,
                } => (
                    "schedule_cleanup",
                    resource_id.as_str(),
                    carrier_id.as_str(),
                    "",
                    "gust_resource_schedule_cleanup",
                    cleanup_id.as_str(),
                ),
                CraneliftResourceAction::InvokeDestructor {
                    resource_id,
                    carrier_id,
                    cleanup_id,
                    destructor_id: _,
                    runtime_symbol,
                } => (
                    "invoke_destructor",
                    resource_id.as_str(),
                    carrier_id.as_str(),
                    "",
                    runtime_symbol.as_str(),
                    cleanup_id.as_str(),
                ),
                CraneliftResourceAction::MarkDestroyed { resource_id, carrier_id } => (
                    "mark_destroyed",
                    resource_id.as_str(),
                    carrier_id.as_str(),
                    "",
                    "",
                    "",
                ),
            };
        let move_form = if operation.kind == ResourceOperationKind::Move {
            let source_kind = table
                .carriers
                .iter()
                .find(|carrier| carrier.carrier_id == operation.source_carrier_id)
                .map(|carrier| carrier.kind.as_str())
                .unwrap_or_default();
            let destination_kind = table
                .carriers
                .iter()
                .find(|carrier| carrier.carrier_id == operation.destination_carrier_id)
                .map(|carrier| carrier.kind.as_str())
                .unwrap_or_default();
            move_form_name(source_kind, destination_kind)
        } else {
            ""
        };
        output.push_str(&format!(
            "resource_lowering: id={} action={} resource={} source={} destination={} move_form={} runtime_symbol={} cleanup={}\n",
            operation.operation_id,
            action_name,
            resource_id,
            source,
            destination,
            move_form,
            runtime_symbol,
            cleanup_id,
        ));
    }
    output
}


#[derive(Debug, Clone, PartialEq, Eq)]
struct ResourceReassignment {
    reassignment_id: String,
    form: String,
    resolution_policy: String,
    storage_id: String,
    old_resource_id: String,
    old_value_id: String,
    old_carrier_id: String,
    replacement_resource_id: String,
    replacement_value_id: String,
    replacement_carrier_id: String,
    predecessor_moved_resource_id: String,
    transfer_destination_carrier_id: String,
    cleanup_obligation_id: String,
    destructor_id: String,
    source_location: String,
    control_flow_region: String,
    destruction_order: usize,
    mutable_storage: bool,
    old_prior_state: String,
    old_resulting_state: String,
    replacement_prior_state: String,
    replacement_resulting_state: String,
    replacement_source_kind: String,
    observable_effect: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct CraneliftResourceReassignmentAction {
    reassignment_id: String,
    action_name: &'static str,
    old_resource_id: String,
    replacement_resource_id: String,
    storage_id: String,
    cleanup_obligation_id: String,
    runtime_symbol: String,
    destruction_order: usize,
    old_resulting_state: String,
    replacement_resulting_state: String,
    observable_effect: String,
}

fn reassignment_error(reason_code: &'static str, entry: &ResourceReassignment) -> ResourceMirError {
    ResourceMirError::new(
        reason_code,
        format!(
            "resource_reassignment_diagnostic: reassignment={} old={} replacement={} storage={} source={} policy={} order={}",
            entry.reassignment_id,
            entry.old_resource_id,
            entry.replacement_resource_id,
            entry.storage_id,
            entry.source_location,
            entry.resolution_policy,
            entry.destruction_order,
        ),
    )
}

fn has_moved_then_fresh_history(
    table: &ResourceMirTable,
    carriers_by_id: &HashMap<&str, &ResourceCarrier>,
    storage_id: &str,
    predecessor_resource_id: &str,
    fresh_resource_id: &str,
) -> bool {
    let mut predecessor_moved = false;
    for operation in &table.operations {
        if operation.kind == ResourceOperationKind::Move
            && operation.resource_id == predecessor_resource_id
            && carriers_by_id
                .get(operation.source_carrier_id.as_str())
                .map(|carrier| carrier.storage_id.as_str())
                == Some(storage_id)
        {
            predecessor_moved = true;
        }
        if predecessor_moved
            && operation.kind == ResourceOperationKind::Initialize
            && operation.resource_id == fresh_resource_id
            && carriers_by_id
                .get(operation.destination_carrier_id.as_str())
                .map(|carrier| carrier.storage_id.as_str())
                == Some(storage_id)
        {
            return true;
        }
    }
    false
}

fn replacement_source_exists(
    table: &ResourceMirTable,
    resource_id: &str,
    carrier_id: &str,
    source_kind: &str,
) -> bool {
    table.operations.iter().any(|operation| {
        operation.resource_id == resource_id
            && operation.destination_carrier_id == carrier_id
            && matches!(
                (source_kind, operation.kind),
                ("fresh_initialize", ResourceOperationKind::Initialize)
                    | ("move", ResourceOperationKind::Move)
            )
    })
}

fn old_resolution_exists(table: &ResourceMirTable, entry: &ResourceReassignment) -> bool {
    table.operations.iter().any(|operation| {
        if operation.resource_id != entry.old_resource_id {
            return false;
        }
        match entry.resolution_policy.as_str() {
            "immediate_destroy" => {
                operation.kind == ResourceOperationKind::InvokeDestructor
                    && operation.cleanup_id == entry.cleanup_obligation_id
                    && operation.resulting_state == "destroyed"
            }
            "scheduled_cleanup" => {
                operation.kind == ResourceOperationKind::ScheduleCleanup
                    && operation.cleanup_id == entry.cleanup_obligation_id
                    && operation.resulting_state == "cleanup_scheduled"
            }
            "transfer_before_replacement" => {
                operation.kind == ResourceOperationKind::Move
                    && operation.source_carrier_id == entry.old_carrier_id
                    && operation.destination_carrier_id == entry.transfer_destination_carrier_id
            }
            _ => false,
        }
    })
}

fn parse_resource_reassignments(
    contents: &str,
    table: &ResourceMirTable,
    authority: &AuthorityTables,
) -> Result<Vec<ResourceReassignment>, ResourceMirError> {
    let fields = parse_fields(contents)?;
    if !fields.contains_key("resource_reassignment_format") {
        return Ok(Vec::new());
    }
    if required_field(&fields, "resource_reassignment_format")?
        != "gust.compiler_resource_reassignment.v1"
        || required_field(&fields, "resource_reassignment_semantic_authority")?
            != "compiler_owned_replacement_transaction"
        || required_field(&fields, "resource_reassignment_order_policy")?
            != "explicit_monotonic_destruction_order"
    {
        return Err(ResourceMirError::new(
            "resource_reassignment_unknown_format",
            "resource reassignment format or policy mismatch",
        ));
    }
    let count = parse_count(&fields, "resource_reassignment_count")?;
    let values_by_id: HashMap<&str, &ResourceValue> = table
        .values
        .iter()
        .map(|value| (value.value_id.as_str(), value))
        .collect();
    let carriers_by_id: HashMap<&str, &ResourceCarrier> = table
        .carriers
        .iter()
        .map(|carrier| (carrier.carrier_id.as_str(), carrier))
        .collect();
    let mut entries = Vec::with_capacity(count);
    let mut seen_ids = HashSet::new();
    let mut seen_old = HashSet::new();
    let mut seen_replacements = HashSet::new();
    let mut seen_cleanups = HashSet::new();
    let mut previous_order = 0usize;
    for index in 0..count {
        let prefix = format!("resource_reassignment_{index}");
        let entry = ResourceReassignment {
            reassignment_id: required_field(&fields, &format!("{prefix}_id"))?.to_string(),
            form: required_field(&fields, &format!("{prefix}_form"))?.to_string(),
            resolution_policy: required_field(&fields, &format!("{prefix}_resolution_policy"))?.to_string(),
            storage_id: required_field(&fields, &format!("{prefix}_storage_id"))?.to_string(),
            old_resource_id: required_field(&fields, &format!("{prefix}_old_resource_id"))?.to_string(),
            old_value_id: required_field(&fields, &format!("{prefix}_old_value_id"))?.to_string(),
            old_carrier_id: required_field(&fields, &format!("{prefix}_old_carrier_id"))?.to_string(),
            replacement_resource_id: required_field(&fields, &format!("{prefix}_replacement_resource_id"))?.to_string(),
            replacement_value_id: required_field(&fields, &format!("{prefix}_replacement_value_id"))?.to_string(),
            replacement_carrier_id: required_field(&fields, &format!("{prefix}_replacement_carrier_id"))?.to_string(),
            predecessor_moved_resource_id: optional_field(&fields, &format!("{prefix}_predecessor_moved_resource_id"))?.to_string(),
            transfer_destination_carrier_id: optional_field(&fields, &format!("{prefix}_transfer_destination_carrier_id"))?.to_string(),
            cleanup_obligation_id: required_field(&fields, &format!("{prefix}_cleanup_obligation_id"))?.to_string(),
            destructor_id: optional_field(&fields, &format!("{prefix}_destructor_id"))?.to_string(),
            source_location: required_field(&fields, &format!("{prefix}_source_location"))?.to_string(),
            control_flow_region: optional_field(&fields, &format!("{prefix}_control_flow_region"))?.to_string(),
            destruction_order: required_field(&fields, &format!("{prefix}_destruction_order"))?
                .parse::<usize>()
                .map_err(|_| ResourceMirError::new("resource_reassignment_destruction_order_invalid", format!("invalid order at {index}")))?,
            mutable_storage: required_field(&fields, &format!("{prefix}_mutable_storage"))? == "1",
            old_prior_state: required_field(&fields, &format!("{prefix}_old_prior_state"))?.to_string(),
            old_resulting_state: required_field(&fields, &format!("{prefix}_old_resulting_state"))?.to_string(),
            replacement_prior_state: required_field(&fields, &format!("{prefix}_replacement_prior_state"))?.to_string(),
            replacement_resulting_state: required_field(&fields, &format!("{prefix}_replacement_resulting_state"))?.to_string(),
            replacement_source_kind: required_field(&fields, &format!("{prefix}_replacement_source_kind"))?.to_string(),
            observable_effect: required_field(&fields, &format!("{prefix}_observable_effect"))?.to_string(),
        };
        if !matches!(
            entry.form.as_str(),
            "live_local" | "reinitialized_moved_local" | "aggregate_field" | "conditional" | "selected_loop"
        ) {
            return Err(reassignment_error("resource_reassignment_form_unsupported", &entry));
        }
        if !matches!(
            entry.resolution_policy.as_str(),
            "immediate_destroy" | "scheduled_cleanup" | "transfer_before_replacement"
        ) {
            return Err(reassignment_error("resource_reassignment_old_live_unresolved", &entry));
        }
        if !entry.mutable_storage {
            return Err(reassignment_error("resource_reassignment_immutable_storage", &entry));
        }
        if entry.old_resource_id == entry.replacement_resource_id {
            return Err(reassignment_error("resource_reassignment_duplicate_live_identity", &entry));
        }
        if entry.old_prior_state == "destroyed" {
            return Err(reassignment_error("resource_reassignment_after_destroy_without_reinitialization", &entry));
        }
        if entry.old_prior_state != "live" {
            return Err(reassignment_error("resource_reassignment_old_not_live", &entry));
        }
        if entry.replacement_prior_state != "uninitialized"
            || entry.replacement_resulting_state != "live"
        {
            return Err(reassignment_error("resource_reassignment_replacement_state_invalid", &entry));
        }
        if entry.replacement_source_kind == "copy" {
            return Err(reassignment_error("resource_reassignment_copy_move_only", &entry));
        }
        if !matches!(entry.replacement_source_kind.as_str(), "fresh_initialize" | "move") {
            return Err(reassignment_error("resource_reassignment_replacement_source_invalid", &entry));
        }
        if !seen_ids.insert(entry.reassignment_id.clone()) {
            return Err(reassignment_error("resource_reassignment_duplicate_id", &entry));
        }
        if !seen_cleanups.insert(entry.cleanup_obligation_id.clone()) {
            return Err(reassignment_error("resource_reassignment_duplicate_old_cleanup", &entry));
        }
        if !seen_old.insert(entry.old_resource_id.clone()) {
            return Err(reassignment_error("resource_reassignment_old_resolved_more_than_once", &entry));
        }
        if !seen_replacements.insert(entry.replacement_resource_id.clone()) {
            return Err(reassignment_error("resource_reassignment_duplicate_replacement_identity", &entry));
        }
        if authority
            .cleanup_resources
            .get(&entry.cleanup_obligation_id)
            .map(String::as_str)
            != Some(entry.old_resource_id.as_str())
        {
            return Err(reassignment_error("resource_reassignment_cleanup_obligation_missing", &entry));
        }
        let old_authority = authority.resources.get(&entry.old_resource_id)
            .ok_or_else(|| reassignment_error("resource_reassignment_identity_missing", &entry))?;
        let replacement_authority = authority.resources.get(&entry.replacement_resource_id)
            .ok_or_else(|| reassignment_error("resource_reassignment_identity_missing", &entry))?;
        if old_authority.resource_type_id != replacement_authority.resource_type_id
            || old_authority.resource_kind != replacement_authority.resource_kind
            || old_authority.layout_id != replacement_authority.layout_id
        {
            return Err(reassignment_error("resource_reassignment_layout_or_kind_mismatch", &entry));
        }
        let old_value = values_by_id.get(entry.old_value_id.as_str())
            .ok_or_else(|| reassignment_error("resource_reassignment_value_identity_mismatch", &entry))?;
        let replacement_value = values_by_id.get(entry.replacement_value_id.as_str())
            .ok_or_else(|| reassignment_error("resource_reassignment_value_identity_mismatch", &entry))?;
        if old_value.resource_id != entry.old_resource_id
            || replacement_value.resource_id != entry.replacement_resource_id
        {
            return Err(reassignment_error("resource_reassignment_value_identity_mismatch", &entry));
        }
        let old_carrier = carriers_by_id.get(entry.old_carrier_id.as_str())
            .ok_or_else(|| reassignment_error("resource_reassignment_storage_identity_mismatch", &entry))?;
        let replacement_carrier = carriers_by_id.get(entry.replacement_carrier_id.as_str())
            .ok_or_else(|| reassignment_error("resource_reassignment_storage_identity_mismatch", &entry))?;
        if old_carrier.resource_id != entry.old_resource_id
            || replacement_carrier.resource_id != entry.replacement_resource_id
            || old_carrier.storage_id != entry.storage_id
            || replacement_carrier.storage_id != entry.storage_id
        {
            return Err(reassignment_error("resource_reassignment_storage_identity_mismatch", &entry));
        }
        if !replacement_source_exists(
            table,
            entry.replacement_resource_id.as_str(),
            entry.replacement_carrier_id.as_str(),
            entry.replacement_source_kind.as_str(),
        ) {
            return Err(reassignment_error("resource_reassignment_replacement_source_invalid", &entry));
        }
        if entry.form == "aggregate_field"
            && (old_carrier.kind != "aggregate_field" || replacement_carrier.kind != "aggregate_field")
        {
            return Err(reassignment_error("resource_reassignment_aggregate_field_not_selected", &entry));
        }
        if entry.form == "conditional"
            && (entry.control_flow_region.is_empty()
                || !table.edges.iter().any(|edge| {
                    edge.edge_id == entry.control_flow_region
                        && edge.resource_id == entry.replacement_resource_id
                        && edge.state == "live"
                        && !edge.is_loop_backedge
                }))
        {
            return Err(reassignment_error("resource_reassignment_control_flow_region_missing", &entry));
        }
        if entry.form == "selected_loop"
            && (entry.control_flow_region.is_empty()
                || !table.edges.iter().any(|edge| {
                    edge.edge_id == entry.control_flow_region
                        && edge.resource_id == entry.replacement_resource_id
                        && edge.state == "live"
                        && edge.is_loop_backedge
                }))
        {
            return Err(reassignment_error("resource_reassignment_control_flow_region_missing", &entry));
        }
        if entry.form == "reinitialized_moved_local"
            && (entry.predecessor_moved_resource_id.is_empty()
                || entry.predecessor_moved_resource_id == entry.old_resource_id
                || !authority.resources.contains_key(&entry.predecessor_moved_resource_id)
                || !has_moved_then_fresh_history(
                    table,
                    &carriers_by_id,
                    entry.storage_id.as_str(),
                    entry.predecessor_moved_resource_id.as_str(),
                    entry.old_resource_id.as_str(),
                ))
        {
            return Err(reassignment_error("resource_reassignment_reinitialization_history_missing", &entry));
        }
        match entry.resolution_policy.as_str() {
            "immediate_destroy" => {
                if entry.destructor_id.is_empty()
                    || entry.destructor_id != old_authority.destructor_id
                    || entry.old_resulting_state != "destroyed"
                {
                    return Err(reassignment_error("resource_reassignment_old_destroy_resolution_invalid", &entry));
                }
                if entry.destruction_order <= previous_order {
                    return Err(reassignment_error("resource_reassignment_destruction_order_invalid", &entry));
                }
                previous_order = entry.destruction_order;
            }
            "scheduled_cleanup" => {
                if entry.destructor_id.is_empty()
                    || entry.destructor_id != old_authority.destructor_id
                    || entry.old_resulting_state != "cleanup_scheduled"
                {
                    return Err(reassignment_error("resource_reassignment_old_schedule_resolution_invalid", &entry));
                }
                if entry.destruction_order <= previous_order {
                    return Err(reassignment_error("resource_reassignment_destruction_order_invalid", &entry));
                }
                previous_order = entry.destruction_order;
            }
            "transfer_before_replacement" => {
                let transfer_destination = carriers_by_id
                    .get(entry.transfer_destination_carrier_id.as_str());
                if transfer_destination
                    .map(|carrier| carrier.resource_id.as_str())
                    != Some(entry.old_resource_id.as_str())
                    || entry.old_resulting_state != "moved"
                    || entry.destruction_order != 0
                {
                    return Err(reassignment_error("resource_reassignment_transfer_resolution_invalid", &entry));
                }
            }
            _ => unreachable!(),
        }
        if !old_resolution_exists(table, &entry) {
            return Err(reassignment_error("resource_reassignment_old_resolution_not_in_canonical_mir", &entry));
        }
        entries.push(entry);
    }
    Ok(entries)
}

fn lower_resource_reassignments(
    entries: &[ResourceReassignment],
    authority: &AuthorityTables,
) -> Result<Vec<CraneliftResourceReassignmentAction>, ResourceMirError> {
    let mut actions = Vec::with_capacity(entries.len());
    for entry in entries {
        let (action_name, runtime_symbol) = match entry.resolution_policy.as_str() {
            "immediate_destroy" => {
                let old_authority = authority.resources.get(&entry.old_resource_id)
                    .ok_or_else(|| reassignment_error("resource_reassignment_identity_missing", entry))?;
                let destructor = authority.destructors.get(&old_authority.destructor_id)
                    .ok_or_else(|| reassignment_error("resource_reassignment_old_destroy_resolution_invalid", entry))?;
                ("destroy_then_replace", destructor.runtime_symbol.clone())
            }
            "scheduled_cleanup" => (
                "schedule_then_replace",
                "gust_resource_schedule_cleanup".to_string(),
            ),
            "transfer_before_replacement" => ("transfer_then_replace", String::new()),
            _ => return Err(reassignment_error("resource_reassignment_old_live_unresolved", entry)),
        };
        actions.push(CraneliftResourceReassignmentAction {
            reassignment_id: entry.reassignment_id.clone(),
            action_name,
            old_resource_id: entry.old_resource_id.clone(),
            replacement_resource_id: entry.replacement_resource_id.clone(),
            storage_id: entry.storage_id.clone(),
            cleanup_obligation_id: entry.cleanup_obligation_id.clone(),
            runtime_symbol,
            destruction_order: entry.destruction_order,
            old_resulting_state: entry.old_resulting_state.clone(),
            replacement_resulting_state: entry.replacement_resulting_state.clone(),
            observable_effect: entry.observable_effect.clone(),
        });
    }
    Ok(actions)
}

fn reassignment_witness(entries: &[ResourceReassignment]) -> String {
    let mut output = String::from("resource_reassignment_witness: accepted\n");
    for entry in entries {
        output.push_str(&format!(
            "resource_reassignment: id={} form={} policy={} old={} replacement={} storage={} cleanup={} destructor={} order={} old_result={} replacement_state={} effect={}\n",
            entry.reassignment_id,
            entry.form,
            entry.resolution_policy,
            entry.old_resource_id,
            entry.replacement_resource_id,
            entry.storage_id,
            entry.cleanup_obligation_id,
            entry.destructor_id,
            entry.destruction_order,
            entry.old_resulting_state,
            entry.replacement_resulting_state,
            entry.observable_effect,
        ));
    }
    output
}

fn reassignment_lowering_witness(actions: &[CraneliftResourceReassignmentAction]) -> String {
    let mut output = String::from("resource_reassignment_lowering_witness: accepted\n");
    for action in actions {
        output.push_str(&format!(
            "resource_reassignment_lowering: id={} action={} old={} replacement={} storage={} cleanup={} runtime_symbol={} order={} old_result={} replacement_state={} effect={}\n",
            action.reassignment_id,
            action.action_name,
            action.old_resource_id,
            action.replacement_resource_id,
            action.storage_id,
            action.cleanup_obligation_id,
            action.runtime_symbol,
            action.destruction_order,
            action.old_resulting_state,
            action.replacement_resulting_state,
            action.observable_effect,
        ));
    }
    output
}

pub fn lower_resource_mir_witness_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let contents = fs::read_to_string(path)?;
    let (table, authority) = parse_resource_mir(&contents)?;
    let actions = lower_for_cranelift(&table, &authority)?;
    let reassignments = parse_resource_reassignments(&contents, &table, &authority)?;
    let reassignment_actions = lower_resource_reassignments(&reassignments, &authority)?;
    let mut output = witness(&table, &actions);
    if !reassignments.is_empty() {
        output.push_str(&reassignment_witness(&reassignments));
        output.push_str(&reassignment_lowering_witness(&reassignment_actions));
    }
    Ok(output)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn copy_operation_is_rejected() {
        assert_eq!(
            transition_from_state("live", ResourceOperationKind::parse("copy").unwrap().authority_operation().unwrap()),
            Err("resource_copy_of_move_only")
        );
    }

    #[test]
    fn all_canonical_operations_lower() {
        for operation in [
            "declare",
            "initialize",
            "read",
            "move",
            "explicit_close",
            "schedule_cleanup",
            "invoke_destructor",
            "mark_destroyed",
        ] {
            assert_eq!(
                ResourceOperationKind::parse(operation).unwrap().as_str(),
                operation
            );
        }
    }
}
