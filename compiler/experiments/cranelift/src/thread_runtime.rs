//! Phase 17.12 threading and synchronization contracts.
//!
//! The worker validates the compiler-produced Rust component request and emits a
//! witness that must match MIR-to-C byte for byte. It holds no view of which
//! Rust symbols exist or how they are spelled — that is the compiler's.

use std::collections::HashMap;
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_thread_runtime.v1";
const WITNESS_FORMAT: &str = "gust.thread_runtime_witness.v1";
const LINKAGE: &str = "thread_operations_use_their_classified_explicit_runtime_path";

const THREAD_OPERATIONS: [&str; 11] = [
    "mutex_create", "mutex_lock", "mutex_unlock", "channel_create",
    "channel_send", "channel_receive", "fiber_create", "fiber_destroy",
    "scheduler_init", "scheduler_destroy", "thread_count_query",
];
const LIFETIME_CONSTRAINTS: [&str; 3] = [
    "caller_scoped", "scheduler_owned", "process_lifetime",
];
const CANCELLATION_POLICIES: [&str; 2] = [
    "no_cancellation_supported", "cooperative_yield_point",
];
const PERMITTED_SYSTEM_LIBRARIES: [&str; 2] = ["none", "pthread"];
const REQUIRED_SYMBOL_VERSION: &str = "gust-runtime-symbol-v1";

#[derive(Debug)]
pub struct ThreadRuntimeError {
    reason_code: &'static str,
    detail: String,
}

impl fmt::Display for ThreadRuntimeError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "gust_thread_runtime_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for ThreadRuntimeError {}

fn error(reason: &'static str, detail: impl Into<String>) -> ThreadRuntimeError {
    ThreadRuntimeError { reason_code: reason, detail: detail.into() }
}

#[derive(Debug, Clone)]
pub struct ThreadContract {
    pub helper_id: String,
    pub thread_operation: String,
    pub system_library_dependency: String,
    pub lifetime_constraint: String,
    pub cancellation_policy: String,
    pub failure_form: String,
}

fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, ThreadRuntimeError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("runtime_thread_missing_component", format!("missing {key}")))
}

fn row(line: &str) -> Result<HashMap<String, String>, ThreadRuntimeError> {
    let body = line
        .strip_prefix("thread_contract:")
        .ok_or_else(|| error("runtime_thread_missing_component", "invalid row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|p| !p.is_empty()) {
        let Some((k, v)) = part.split_once('=') else {
            return Err(error("runtime_thread_missing_component", format!("invalid field {part}")));
        };
        if fields.insert(k.to_owned(), v.to_owned()).is_some() {
            return Err(error("runtime_thread_unsupported_cancellation", format!("duplicate field {k}")));
        }
    }
    Ok(fields)
}

fn field<'a>(f: &'a HashMap<String, String>, k: &str) -> Result<&'a str, ThreadRuntimeError> {
    f.get(k)
        .map(String::as_str)
        .filter(|v| !v.is_empty())
        .ok_or_else(|| error("runtime_thread_missing_component", format!("missing {k}")))
}

fn parse_row(f: &HashMap<String, String>, target: &str) -> Result<ThreadContract, ThreadRuntimeError> {
    for key in ["id", "helper", "symbol", "operation"] {
        if field(f, key).is_err() {
            return Err(error("runtime_thread_missing_component", format!("missing {key}")));
        }
    }
    if field(f, "target")? != target {
        return Err(error("runtime_thread_unsupported_target", "target disagrees with request"));
    }
    let thread_operation = field(f, "operation")?;
    if !THREAD_OPERATIONS.contains(&thread_operation) {
        return Err(error(
            "runtime_thread_unsupported_target",
            format!("operation {thread_operation} is outside the bounded inventory"),
        ));
    }
    let lifetime_constraint = field(f, "lifetime")?;
    if !LIFETIME_CONSTRAINTS.contains(&lifetime_constraint) {
        return Err(error(
            "runtime_thread_missing_component",
            format!("unsupported lifetime constraint {lifetime_constraint}"),
        ));
    }

    // Cancellation and unwind behaviour are explicitly not claimed here, so
    // only the policies the current runtime provides are accepted.
    let cancellation_policy = field(f, "cancellation")?;
    if !CANCELLATION_POLICIES.contains(&cancellation_policy) {
        return Err(error(
            "runtime_thread_unsupported_cancellation",
            format!("unsupported cancellation policy {cancellation_policy}"),
        ));
    }

    // A platform thread library must be one the package is permitted to import.
    let system_library_dependency = field(f, "system_library")?;
    if !PERMITTED_SYSTEM_LIBRARIES.contains(&system_library_dependency) {
        return Err(error(
            "runtime_thread_undeclared_system_library",
            format!("{system_library_dependency} is not a permitted system library"),
        ));
    }
    let symbol = field(f, "symbol")?;
    if !symbol.contains(REQUIRED_SYMBOL_VERSION) {
        return Err(error(
            "runtime_thread_abi_or_version_mismatch",
            format!("{symbol} does not carry {REQUIRED_SYMBOL_VERSION}"),
        ));
    }
    Ok(ThreadContract {
        helper_id: field(f, "helper")?.to_owned(),
        thread_operation: thread_operation.to_owned(),
        system_library_dependency: system_library_dependency.to_owned(),
        lifetime_constraint: lifetime_constraint.to_owned(),
        cancellation_policy: cancellation_policy.to_owned(),
        failure_form: field(f, "failure")?.to_owned(),
    })
}

pub fn parse_thread_runtime_request(
    request: &str,
) -> Result<(String, Vec<ThreadContract>), ThreadRuntimeError> {
    let lines: Vec<&str> = request.lines().collect();
    let format = header(&lines, "format")?;
    if format != FORMAT {
        return Err(error("runtime_thread_missing_component", format!("unknown format {format}")));
    }
    let target = header(&lines, "target")?.to_owned();
    header(&lines, "triple")?;
    let mut components: Vec<ThreadContract> = Vec::new();
    for line in lines.iter().filter(|l| l.starts_with("thread_contract:")) {
        let component = parse_row(&row(line)?, &target)?;
        // Two components providing the same export is a compiler-resolved
        // ambiguity, never something the linker gets to discover.
        for existing in &components {
            if existing.helper_id == component.helper_id {
                return Err(error(
                    "runtime_thread_missing_component",
                    format!("{} is contracted twice", component.helper_id),
                ));
            }
        }
        components.push(component);
    }
    if components.is_empty() {
        return Err(error("runtime_thread_missing_component", "no declared thread contracts"));
    }
    Ok((target, components))
}

pub fn render_thread_runtime_witness(target: &str, components: &[ThreadContract]) -> String {
    let mut out = format!("witness: {WITNESS_FORMAT}\ntarget: {target}\n");
    for c in components {
        out.push_str("contract:");
        out.push_str(&format!("helper={};", c.helper_id));
        out.push_str(&format!("operation={};", c.thread_operation));
        out.push_str(&format!("system_library={};", c.system_library_dependency));
        out.push_str(&format!("lifetime={};", c.lifetime_constraint));
        out.push_str(&format!("cancellation={};", c.cancellation_policy));
        out.push_str(&format!("failure={};", c.failure_form));
        out.push_str(&format!("linkage={LINKAGE};"));
        out.push('\n');
    }
    out
}

pub fn lower_thread_runtime_witness_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let request = fs::read_to_string(path)?;
    let (target, components) = parse_thread_runtime_request(&request)?;
    Ok(render_thread_runtime_witness(&target, &components))
}
