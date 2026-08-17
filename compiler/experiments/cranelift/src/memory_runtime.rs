//! Phase 17.10 allocation, core-memory, and string contracts.
//!
//! The worker validates the compiler-produced Rust component request and emits a
//! witness that must match MIR-to-C byte for byte. It holds no view of which
//! Rust symbols exist or how they are spelled — that is the compiler's.

use std::collections::HashMap;
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_memory_runtime.v1";
const WITNESS_FORMAT: &str = "gust.memory_runtime_witness.v1";
const LINKAGE: &str = "memory_operations_use_their_classified_explicit_runtime_path";

const OPERATION_KINDS: [&str; 13] = [
    "allocate", "deallocate", "reallocate", "memory_copy", "memory_move",
    "memory_set", "memory_compare", "bounds_or_failure_report",
    "string_create", "string_length", "string_compare", "string_convert",
    "string_destroy",
];
const ALLOCATION_DOMAINS: [&str; 4] = [
    "host_process_allocator", "caller_owned_arena", "thread_local_scratch",
    "no_allocation",
];
const OWNERSHIP_TRANSFERS: [&str; 3] = [
    "caller_retains_ownership", "ownership_transfers_to_caller",
    "borrowed_for_call_duration",
];
const REQUIRED_SYMBOL_VERSION: &str = "gust-runtime-symbol-v1";

#[derive(Debug)]
pub struct MemoryRuntimeError {
    reason_code: &'static str,
    detail: String,
}

impl fmt::Display for MemoryRuntimeError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "gust_memory_runtime_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for MemoryRuntimeError {}

fn error(reason: &'static str, detail: impl Into<String>) -> MemoryRuntimeError {
    MemoryRuntimeError { reason_code: reason, detail: detail.into() }
}

#[derive(Debug, Clone)]
pub struct MemoryContract {
    pub helper_id: String,
    pub operation_kind: String,
    pub allocation_domain: String,
    pub ownership_transfer: String,
    pub failure_reporting: String,
    pub layout_id: String,
}

fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, MemoryRuntimeError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("runtime_memory_missing_allocation_helper", format!("missing {key}")))
}

fn row(line: &str) -> Result<HashMap<String, String>, MemoryRuntimeError> {
    let body = line
        .strip_prefix("memory_contract:")
        .ok_or_else(|| error("runtime_memory_missing_allocation_helper", "invalid row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|p| !p.is_empty()) {
        let Some((k, v)) = part.split_once('=') else {
            return Err(error("runtime_memory_missing_allocation_helper", format!("invalid field {part}")));
        };
        if fields.insert(k.to_owned(), v.to_owned()).is_some() {
            return Err(error("runtime_memory_wrong_symbol_version", format!("duplicate field {k}")));
        }
    }
    Ok(fields)
}

fn field<'a>(f: &'a HashMap<String, String>, k: &str) -> Result<&'a str, MemoryRuntimeError> {
    f.get(k)
        .map(String::as_str)
        .filter(|v| !v.is_empty())
        .ok_or_else(|| error("runtime_memory_missing_allocation_helper", format!("missing {k}")))
}

fn parse_row(f: &HashMap<String, String>, target: &str) -> Result<MemoryContract, MemoryRuntimeError> {
    for key in ["id", "helper", "symbol", "operation"] {
        if field(f, key).is_err() {
            return Err(error("runtime_memory_missing_allocation_helper", format!("missing {key}")));
        }
    }
    if field(f, "target")? != target {
        return Err(error(
            "runtime_memory_unsupported_target_operation",
            "target disagrees with request",
        ));
    }
    let operation_kind = field(f, "operation")?;
    if !OPERATION_KINDS.contains(&operation_kind) {
        return Err(error(
            "runtime_memory_unsupported_target_operation",
            format!("unsupported operation {operation_kind}"),
        ));
    }
    let allocation_domain = field(f, "domain")?;
    if !ALLOCATION_DOMAINS.contains(&allocation_domain) {
        return Err(error(
            "runtime_memory_incompatible_allocator_domain",
            format!("unsupported allocation domain {allocation_domain}"),
        ));
    }
    let ownership_transfer = field(f, "ownership")?;
    if !OWNERSHIP_TRANSFERS.contains(&ownership_transfer) {
        return Err(error(
            "runtime_memory_incompatible_allocator_domain",
            format!("unsupported ownership transfer {ownership_transfer}"),
        ));
    }

    // Phase 14 layout is carried, not re-derived.
    let layout_id = field(f, "layout")?;
    if !layout_id.starts_with("layout:") {
        return Err(error(
            "runtime_memory_invalid_string_layout",
            format!("{layout_id} is not a Phase 14 layout identity"),
        ));
    }
    let symbol = field(f, "symbol")?;
    if !symbol.contains(REQUIRED_SYMBOL_VERSION) {
        return Err(error(
            "runtime_memory_wrong_symbol_version",
            format!("{symbol} does not carry {REQUIRED_SYMBOL_VERSION}"),
        ));
    }
    Ok(MemoryContract {
        helper_id: field(f, "helper")?.to_owned(),
        operation_kind: operation_kind.to_owned(),
        allocation_domain: allocation_domain.to_owned(),
        ownership_transfer: ownership_transfer.to_owned(),
        failure_reporting: field(f, "failure")?.to_owned(),
        layout_id: layout_id.to_owned(),
    })
}

pub fn parse_memory_runtime_request(
    request: &str,
) -> Result<(String, Vec<MemoryContract>), MemoryRuntimeError> {
    let lines: Vec<&str> = request.lines().collect();
    let format = header(&lines, "format")?;
    if format != FORMAT {
        return Err(error("runtime_memory_missing_allocation_helper", format!("unknown format {format}")));
    }
    let target = header(&lines, "target")?.to_owned();
    header(&lines, "triple")?;
    let mut components: Vec<MemoryContract> = Vec::new();
    for line in lines.iter().filter(|l| l.starts_with("memory_contract:")) {
        let component = parse_row(&row(line)?, &target)?;
        // Two components providing the same export is a compiler-resolved
        // ambiguity, never something the linker gets to discover.
        for existing in &components {
            if existing.helper_id == component.helper_id {
                return Err(error(
                    "runtime_memory_missing_allocation_helper",
                    format!("{} is contracted twice", component.helper_id),
                ));
            }
        }
        components.push(component);
    }
    if components.is_empty() {
        return Err(error("runtime_memory_missing_allocation_helper", "no declared memory contracts"));
    }
    // Memory obtained from one domain may only be released through the same
    // domain, so every release needs an acquisition beside it.
    for contract in &components {
        let releases = contract.operation_kind == "deallocate"
            || contract.operation_kind == "string_destroy";
        if !releases {
            continue;
        }
        let paired = components.iter().any(|other| {
            other.allocation_domain == contract.allocation_domain
                && (other.operation_kind == "allocate"
                    || other.operation_kind == "string_create")
        });
        if !paired {
            return Err(error(
                "runtime_memory_incompatible_allocator_domain",
                format!(
                    "{} releases {} with no acquisition in that domain",
                    contract.helper_id, contract.allocation_domain
                ),
            ));
        }
    }
    Ok((target, components))
}

pub fn render_memory_runtime_witness(target: &str, components: &[MemoryContract]) -> String {
    let mut out = format!("witness: {WITNESS_FORMAT}\ntarget: {target}\n");
    for c in components {
        out.push_str("contract:");
        out.push_str(&format!("helper={};", c.helper_id));
        out.push_str(&format!("operation={};", c.operation_kind));
        out.push_str(&format!("domain={};", c.allocation_domain));
        out.push_str(&format!("ownership={};", c.ownership_transfer));
        out.push_str(&format!("failure={};", c.failure_reporting));
        out.push_str(&format!("layout={};", c.layout_id));
        out.push_str(&format!("linkage={LINKAGE};"));
        out.push('\n');
    }
    out
}

pub fn lower_memory_runtime_witness_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let request = fs::read_to_string(path)?;
    let (target, components) = parse_memory_runtime_request(&request)?;
    Ok(render_memory_runtime_witness(&target, &components))
}
