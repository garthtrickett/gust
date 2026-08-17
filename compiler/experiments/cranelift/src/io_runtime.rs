//! Phase 17.11 I/O, filesystem, and resource contracts.
//!
//! The worker validates the compiler-produced Rust component request and emits a
//! witness that must match MIR-to-C byte for byte. It holds no view of which
//! Rust symbols exist or how they are spelled — that is the compiler's.

use std::collections::HashMap;
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_io_runtime.v1";
const WITNESS_FORMAT: &str = "gust.io_runtime_witness.v1";
const LINKAGE: &str = "io_operations_use_their_classified_explicit_runtime_path";

const IO_KINDS: [&str; 7] = [
    "standard_stream", "file_or_stream", "path_or_filesystem",
    "directory_resource", "environment_query", "target_query",
    "c_string_marshalling",
];
const RESOURCE_TRANSITIONS: [&str; 4] = [
    "not_a_resource", "acquires", "uses_borrowed", "closes",
];
const FILESYSTEM_EFFECTS: [&str; 4] = [
    "none", "reads_filesystem", "writes_filesystem", "removes_path",
];
const REQUIRED_SYMBOL_VERSION: &str = "gust-runtime-symbol-v1";

#[derive(Debug)]
pub struct IoRuntimeError {
    reason_code: &'static str,
    detail: String,
}

impl fmt::Display for IoRuntimeError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "gust_io_runtime_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for IoRuntimeError {}

fn error(reason: &'static str, detail: impl Into<String>) -> IoRuntimeError {
    IoRuntimeError { reason_code: reason, detail: detail.into() }
}

#[derive(Debug, Clone)]
pub struct IoContract {
    pub helper_id: String,
    pub io_kind: String,
    pub resource_kind: String,
    pub resource_transition: String,
    pub failure_form: String,
    pub filesystem_effect: String,
    pub close_operation_id: String,
}

fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, IoRuntimeError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("runtime_io_missing_symbol", format!("missing {key}")))
}

fn row(line: &str) -> Result<HashMap<String, String>, IoRuntimeError> {
    let body = line
        .strip_prefix("io_contract:")
        .ok_or_else(|| error("runtime_io_missing_symbol", "invalid row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|p| !p.is_empty()) {
        let Some((k, v)) = part.split_once('=') else {
            return Err(error("runtime_io_missing_symbol", format!("invalid field {part}")));
        };
        if fields.insert(k.to_owned(), v.to_owned()).is_some() {
            return Err(error("runtime_io_duplicate_close", format!("duplicate field {k}")));
        }
    }
    Ok(fields)
}

fn field<'a>(f: &'a HashMap<String, String>, k: &str) -> Result<&'a str, IoRuntimeError> {
    f.get(k)
        .map(String::as_str)
        .filter(|v| !v.is_empty())
        .ok_or_else(|| error("runtime_io_missing_symbol", format!("missing {k}")))
}

fn parse_row(f: &HashMap<String, String>, target: &str) -> Result<IoContract, IoRuntimeError> {
    for key in ["id", "helper", "symbol", "io_kind"] {
        if field(f, key).is_err() {
            return Err(error("runtime_io_missing_symbol", format!("missing {key}")));
        }
    }
    if field(f, "target")? != target {
        return Err(error("runtime_io_unsupported_target", "target disagrees with request"));
    }
    let io_kind = field(f, "io_kind")?;
    if !IO_KINDS.contains(&io_kind) {
        return Err(error(
            "runtime_io_unsupported_target",
            format!("unsupported io kind {io_kind}"),
        ));
    }
    let resource_transition = field(f, "transition")?;
    if !RESOURCE_TRANSITIONS.contains(&resource_transition) {
        return Err(error(
            "runtime_io_wrong_resource_kind",
            format!("unsupported resource transition {resource_transition}"),
        ));
    }
    let filesystem_effect = field(f, "fs_effect")?;
    if !FILESYSTEM_EFFECTS.contains(&filesystem_effect) {
        return Err(error(
            "runtime_io_unsupported_target",
            format!("unsupported filesystem effect {filesystem_effect}"),
        ));
    }
    let symbol = field(f, "symbol")?;
    if !symbol.contains(REQUIRED_SYMBOL_VERSION) {
        return Err(error(
            "runtime_io_missing_symbol",
            format!("{symbol} does not carry {REQUIRED_SYMBOL_VERSION}"),
        ));
    }

    // A non-resource helper may not claim a transition, and a resource-bearing
    // helper must name its kind.
    let resource_kind = field(f, "resource_kind")?;
    let is_resource = resource_kind != "none";
    if is_resource == (resource_transition == "not_a_resource") {
        return Err(error(
            "runtime_io_wrong_resource_kind",
            format!("{resource_kind} disagrees with transition {resource_transition}"),
        ));
    }
    Ok(IoContract {
        helper_id: field(f, "helper")?.to_owned(),
        io_kind: io_kind.to_owned(),
        resource_kind: resource_kind.to_owned(),
        resource_transition: resource_transition.to_owned(),
        failure_form: field(f, "failure")?.to_owned(),
        filesystem_effect: filesystem_effect.to_owned(),
        close_operation_id: f.get("close_operation").cloned().unwrap_or_default(),
    })
}

pub fn parse_io_runtime_request(
    request: &str,
) -> Result<(String, Vec<IoContract>), IoRuntimeError> {
    let lines: Vec<&str> = request.lines().collect();
    let format = header(&lines, "format")?;
    if format != FORMAT {
        return Err(error("runtime_io_missing_symbol", format!("unknown format {format}")));
    }
    let target = header(&lines, "target")?.to_owned();
    header(&lines, "triple")?;
    let mut components: Vec<IoContract> = Vec::new();
    for line in lines.iter().filter(|l| l.starts_with("io_contract:")) {
        let component = parse_row(&row(line)?, &target)?;
        // Two components providing the same export is a compiler-resolved
        // ambiguity, never something the linker gets to discover.
        for existing in &components {
            if existing.helper_id == component.helper_id {
                return Err(error(
                    "runtime_io_missing_symbol",
                    format!("{} is contracted twice", component.helper_id),
                ));
            }
        }
        components.push(component);
    }
    if components.is_empty() {
        return Err(error("runtime_io_missing_symbol", "no declared io contracts"));
    }
    // An acquired resource kind must have exactly one close, and manual close
    // and deferred cleanup must name the same runtime operation.
    for contract in &components {
        if contract.resource_transition == "acquires"
            || contract.resource_transition == "uses_borrowed"
        {
            let closed = components.iter().any(|other| {
                other.resource_transition == "closes"
                    && other.resource_kind == contract.resource_kind
                    && other.close_operation_id == contract.close_operation_id
            });
            if !closed {
                return Err(error(
                    "runtime_io_close_mismatch",
                    format!(
                        "{} acquires {} with no matching close operation",
                        contract.helper_id, contract.resource_kind
                    ),
                ));
            }
        }
        if contract.resource_transition == "closes" {
            let closers = components
                .iter()
                .filter(|other| {
                    other.resource_transition == "closes"
                        && other.resource_kind == contract.resource_kind
                })
                .count();
            if closers > 1 {
                return Err(error(
                    "runtime_io_duplicate_close",
                    format!("{} is closed by {closers} operations", contract.resource_kind),
                ));
            }
        }
    }
    Ok((target, components))
}

pub fn render_io_runtime_witness(target: &str, components: &[IoContract]) -> String {
    let mut out = format!("witness: {WITNESS_FORMAT}\ntarget: {target}\n");
    for c in components {
        out.push_str("contract:");
        out.push_str(&format!("helper={};", c.helper_id));
        out.push_str(&format!("io_kind={};", c.io_kind));
        out.push_str(&format!("resource_kind={};", c.resource_kind));
        out.push_str(&format!("transition={};", c.resource_transition));
        out.push_str(&format!("failure={};", c.failure_form));
        out.push_str(&format!("fs_effect={};", c.filesystem_effect));
        out.push_str(&format!("close_operation={};", c.close_operation_id));
        out.push_str(&format!("linkage={LINKAGE};"));
        out.push('\n');
    }
    out
}

pub fn lower_io_runtime_witness_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let request = fs::read_to_string(path)?;
    let (target, components) = parse_io_runtime_request(&request)?;
    Ok(render_io_runtime_witness(&target, &components))
}
