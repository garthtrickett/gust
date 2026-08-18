//! Phase 18.1 compiler-owned target identity.
//!
//! The worker validates the compiler-produced target identity and emits a
//! witness that must match MIR-to-C byte for byte. It holds no view of which
//! targets exist, how a triple is spelled, or which target should be selected —
//! all of that is the compiler's. In particular the worker never consults a
//! native ISA builder, the host environment, or an output probe to decide what
//! it is compiling for.

use std::collections::HashMap;
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_target_identity.v1";
const WITNESS_FORMAT: &str = "gust.target_identity_witness.v1";
const AUTHORITY: &str = "compiler/mir_target_authority.gst";

/// The only two ways a target may be selected. A third mode would mean some
/// consumer decided for itself.
const SELECTION_MODES: [&str; 2] = ["explicit_requested_target", "declared_default_target"];
const LAYOUT_AGREEMENT: &str = "agrees_with_phase14_target_layout_authority";

#[derive(Debug)]
pub struct TargetError {
    reason_code: &'static str,
    detail: String,
}

impl fmt::Display for TargetError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "gust_target_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for TargetError {}

fn error(reason: &'static str, detail: impl Into<String>) -> TargetError {
    TargetError { reason_code: reason, detail: detail.into() }
}

#[derive(Debug, Clone)]
pub struct TargetIdentity {
    pub target_id: String,
    pub triple: String,
    pub architecture: String,
    pub vendor: String,
    pub operating_system: String,
    pub environment: String,
    pub pointer_width_bits: u32,
    pub endianness: String,
    pub selection_id: String,
}

#[derive(Debug, Clone)]
pub struct TargetSelection {
    pub selection_id: String,
    pub mode: String,
    pub requested: String,
    pub consulted_host: bool,
}

fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, TargetError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("target_request_malformed", format!("missing {key}")))
}

fn row(line: &str, prefix: &str) -> Result<HashMap<String, String>, TargetError> {
    let body = line
        .strip_prefix(prefix)
        .ok_or_else(|| error("target_request_malformed", "invalid row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|p| !p.is_empty()) {
        let Some((k, v)) = part.split_once('=') else {
            return Err(error("target_request_malformed", format!("invalid field {part}")));
        };
        if fields.insert(k.to_owned(), v.to_owned()).is_some() {
            return Err(error("target_request_malformed", format!("duplicate field {k}")));
        }
    }
    Ok(fields)
}

fn field<'a>(f: &'a HashMap<String, String>, k: &str) -> Result<&'a str, TargetError> {
    f.get(k)
        .map(String::as_str)
        .filter(|v| !v.is_empty())
        .ok_or_else(|| error("target_request_malformed", format!("missing {k}")))
}

/// The target id carries the Phase 14 layout decision, so agreement is checked
/// against the id rather than trusted from a claim field.
fn layout_fields(target_id: &str) -> Result<HashMap<String, String>, TargetError> {
    let mut fields = HashMap::new();
    for part in target_id.split(':').skip(2) {
        if let Some((k, v)) = part.split_once('=') {
            fields.insert(k.to_owned(), v.to_owned());
        }
    }
    if !fields.contains_key("ptr_size") || !fields.contains_key("endian") || !fields.contains_key("triple") {
        return Err(error("target_layout_disagreement", "target id does not carry layout fields"));
    }
    Ok(fields)
}

fn parse_identity(f: &HashMap<String, String>) -> Result<TargetIdentity, TargetError> {
    let target_id = field(f, "target_id")?.to_owned();
    let triple = field(f, "triple")?.to_owned();
    let layout = layout_fields(&target_id)?;

    if layout["triple"] != triple {
        return Err(error("target_layout_disagreement", "target id spelling disagrees with the triple"));
    }

    let pointer_width_bits: u32 = field(f, "ptr_bits")?
        .parse()
        .map_err(|_| error("target_request_malformed", "ptr_bits is not a number"))?;
    let expected: u32 = layout["ptr_size"]
        .parse::<u32>()
        .map_err(|_| error("target_layout_disagreement", "ptr_size is not a number"))?
        * 8;
    if pointer_width_bits != expected {
        return Err(error(
            "target_layout_disagreement",
            format!("{triple} claims {pointer_width_bits}-bit pointers, layout authority says {expected}"),
        ));
    }

    let endianness = field(f, "endian")?.to_owned();
    if endianness != layout["endian"] {
        return Err(error(
            "target_layout_disagreement",
            format!("{triple} claims {endianness} endian, layout authority says {}", layout["endian"]),
        ));
    }

    if field(f, "layout_agreement")? != LAYOUT_AGREEMENT {
        return Err(error("target_layout_disagreement", "identity does not claim layout agreement"));
    }

    let architecture = field(f, "arch")?.to_owned();
    if !triple.starts_with(&architecture) {
        return Err(error("target_request_malformed", "architecture disagrees with the triple"));
    }

    Ok(TargetIdentity {
        target_id,
        triple,
        architecture,
        vendor: field(f, "vendor")?.to_owned(),
        operating_system: field(f, "os")?.to_owned(),
        environment: field(f, "env")?.to_owned(),
        pointer_width_bits,
        endianness,
        selection_id: field(f, "selection")?.to_owned(),
    })
}

fn parse_selection(f: &HashMap<String, String>) -> Result<TargetSelection, TargetError> {
    let mode = field(f, "mode")?.to_owned();
    if !SELECTION_MODES.contains(&mode.as_str()) {
        return Err(error("target_selection_mode_unknown", format!("unknown selection mode {mode}")));
    }
    let consulted_host = match field(f, "consulted_host")? {
        "0" => false,
        "1" => true,
        other => return Err(error("target_request_malformed", format!("consulted_host {other}"))),
    };
    // An explicit request that consulted the host is host inference wearing a
    // request's clothes.
    if mode == "explicit_requested_target" && consulted_host {
        return Err(error(
            "host_inference_under_explicit_target",
            "an explicitly requested target consulted the host",
        ));
    }
    Ok(TargetSelection {
        selection_id: field(f, "selection_id")?.to_owned(),
        mode,
        requested: field(f, "requested")?.to_owned(),
        consulted_host,
    })
}

pub fn lower_target_witness(request: &str) -> Result<String, TargetError> {
    let lines: Vec<&str> = request.lines().collect();
    if header(&lines, "format")? != FORMAT {
        return Err(error("target_request_malformed", "unknown request format"));
    }
    if header(&lines, "authority")? != AUTHORITY {
        return Err(error("target_request_malformed", "unknown target authority"));
    }

    let mut identities = Vec::new();
    for line in lines.iter().filter(|l| l.starts_with("target_identity:")) {
        identities.push(parse_identity(&row(line, "target_identity:")?)?);
    }
    let mut selections = Vec::new();
    for line in lines.iter().filter(|l| l.starts_with("target_selection:")) {
        selections.push(parse_selection(&row(line, "target_selection:")?)?);
    }
    if identities.is_empty() {
        return Err(error("missing_target_identity_in_request", "request declares no target identity"));
    }

    // Every identity must name a selection that exists. An identity with no
    // selection would be a target nobody chose.
    for identity in &identities {
        if !selections.iter().any(|s| s.selection_id == identity.selection_id) {
            return Err(error(
                "missing_target_identity_in_request",
                format!("{} names selection {} which is absent", identity.triple, identity.selection_id),
            ));
        }
    }

    let mut witness = String::new();
    witness.push_str(&format!("format: {WITNESS_FORMAT}\n"));
    witness.push_str(&format!("authority: {AUTHORITY}\n"));
    for identity in &identities {
        witness.push_str(&format!(
            "target_identity:target_id={};triple={};arch={};vendor={};os={};env={};ptr_bits={};endian={};layout_agreement={};selection={};\n",
            identity.target_id, identity.triple, identity.architecture, identity.vendor,
            identity.operating_system, identity.environment, identity.pointer_width_bits,
            identity.endianness, LAYOUT_AGREEMENT, identity.selection_id,
        ));
    }
    for selection in &selections {
        witness.push_str(&format!(
            "target_selection:selection_id={};mode={};requested={};consulted_host={};\n",
            selection.selection_id, selection.mode, selection.requested,
            u8::from(selection.consulted_host),
        ));
    }
    Ok(witness)
}

pub fn lower_target_witness_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let request = fs::read_to_string(path)?;
    Ok(lower_target_witness(&request)?)
}
