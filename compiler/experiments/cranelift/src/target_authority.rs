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

// ---- Patch 18.2: the complete target support tuple ----

const SUPPORT_FORMAT: &str = "gust.compiler_target_support.v1";
const SUPPORT_WITNESS_FORMAT: &str = "gust.target_support_witness.v1";

/// The frozen validation order. Position is the required slot, so a tuple whose
/// elements arrive in another order has not asked the same questions.
const TUPLE_ELEMENTS: [&str; 4] = ["compiler", "runtime_package", "linker", "abi"];

#[derive(Debug, Clone)]
pub struct SupportElement {
    pub kind: String,
    pub owner: String,
    pub evidence: String,
    pub present: bool,
    pub compatible: bool,
}

impl SupportElement {
    /// An element counts only when it is present, compatible, and carries both
    /// an owner and evidence. A claim with no owner is not support.
    fn supported(&self) -> bool {
        self.present && self.compatible && !self.owner.is_empty() && !self.evidence.is_empty()
    }
}

fn parse_element(f: &HashMap<String, String>) -> Result<SupportElement, TargetError> {
    let flag = |key: &str| -> Result<bool, TargetError> {
        match field(f, key)? {
            "0" => Ok(false),
            "1" => Ok(true),
            other => Err(error("target_support_malformed", format!("{key}={other}"))),
        }
    };
    Ok(SupportElement {
        kind: field(f, "kind")?.to_owned(),
        owner: field(f, "owner")?.to_owned(),
        evidence: f.get("evidence").cloned().unwrap_or_default(),
        present: flag("present")?,
        compatible: flag("compatible")?,
    })
}

pub fn lower_target_support_witness(request: &str) -> Result<String, TargetError> {
    let lines: Vec<&str> = request.lines().collect();
    if header(&lines, "format")? != SUPPORT_FORMAT {
        return Err(error("target_support_malformed", "unknown request format"));
    }
    if header(&lines, "authority")? != AUTHORITY {
        return Err(error("target_support_malformed", "unknown target authority"));
    }

    let tuple_line = lines
        .iter()
        .find(|l| l.starts_with("target_support:"))
        .ok_or_else(|| error("target_support_malformed", "request declares no support tuple"))?;
    let tuple = row(tuple_line, "target_support:")?;

    let mut elements = Vec::new();
    for line in lines.iter().filter(|l| l.starts_with("support_element:")) {
        elements.push(parse_element(&row(line, "support_element:")?)?);
    }

    // The four elements must arrive in the frozen order, exactly once each.
    let kinds: Vec<&str> = elements.iter().map(|e| e.kind.as_str()).collect();
    if kinds != TUPLE_ELEMENTS {
        return Err(error(
            "target_support_order_drift",
            format!("element order {kinds:?} is not the frozen order {TUPLE_ELEMENTS:?}"),
        ));
    }

    let complete = elements.iter().all(SupportElement::supported);
    let decision = field(&tuple, "decision")?;

    // The request states completeness; the worker recomputes it. A request
    // cannot declare itself complete.
    let claimed_complete = match field(&tuple, "complete")? {
        "0" => false,
        "1" => true,
        other => return Err(error("target_support_malformed", format!("complete={other}"))),
    };
    if claimed_complete != complete {
        return Err(error(
            "target_support_decision_drift",
            "claimed completeness disagrees with the tuple contents",
        ));
    }

    if decision == "supported" && !complete {
        return Err(error(
            "target_supported_without_complete_tuple",
            "supported requires all four elements present, compatible, and evidenced",
        ));
    }
    if decision != "supported" && complete {
        return Err(error(
            "target_support_decision_drift",
            "a complete tuple recorded as unsupported",
        ));
    }

    let mut witness = String::new();
    witness.push_str(&format!("format: {SUPPORT_WITNESS_FORMAT}\n"));
    witness.push_str(&format!("authority: {AUTHORITY}\n"));
    witness.push_str(&format!(
        "target_support:tuple_id={};target_id={};decision={};complete={};\n",
        field(&tuple, "tuple_id")?, field(&tuple, "target_id")?, decision, u8::from(complete),
    ));
    for element in &elements {
        witness.push_str(&format!(
            "support_element:kind={};owner={};evidence={};present={};compatible={};\n",
            element.kind, element.owner, element.evidence,
            u8::from(element.present), u8::from(element.compatible),
        ));
    }
    Ok(witness)
}

pub fn lower_target_support_witness_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let request = fs::read_to_string(path)?;
    Ok(lower_target_support_witness(&request)?)
}

// ---- Patch 18.3: object format, section, and symbol binding ----

const OBJECT_FORMAT_FORMAT: &str = "gust.compiler_object_format.v1";
const OBJECT_FORMAT_WITNESS_FORMAT: &str = "gust.object_format_witness.v1";

/// The format derivation. The worker recomputes the format from the operating
/// system rather than trusting the descriptor, so a host default cannot pass as
/// a target-derived decision.
fn object_format_for_os(operating_system: &str) -> Option<&'static str> {
    match operating_system {
        "linux" => Some("elf"),
        "darwin" => Some("macho"),
        _ => None,
    }
}

pub fn lower_object_format_witness(request: &str) -> Result<String, TargetError> {
    let lines: Vec<&str> = request.lines().collect();
    if header(&lines, "format")? != OBJECT_FORMAT_FORMAT {
        return Err(error("object_format_malformed", "unknown request format"));
    }
    if header(&lines, "authority")? != AUTHORITY {
        return Err(error("object_format_malformed", "unknown target authority"));
    }

    let format_line = lines
        .iter()
        .find(|l| l.starts_with("object_format:"))
        .ok_or_else(|| error("object_format_malformed", "request declares no object format"))?;
    let descriptor = row(format_line, "object_format:")?;

    let operating_system = field(&descriptor, "os")?;
    let claimed = field(&descriptor, "object_format")?;
    let Some(expected) = object_format_for_os(operating_system) else {
        return Err(error(
            "object_format_unknown_operating_system",
            format!("no object format derivation for {operating_system}"),
        ));
    };
    if claimed != expected {
        return Err(error(
            "object_format_disagrees_with_target_identity",
            format!("{operating_system} implies {expected}, descriptor claims {claimed}"),
        ));
    }
    if field(&descriptor, "derived_from")? != "operating_system_in_declared_target_identity" {
        return Err(error(
            "object_format_not_derived_from_target_identity",
            "descriptor does not declare a target-derived format",
        ));
    }

    let max_align: i64 = field(&descriptor, "max_align")?
        .parse()
        .map_err(|_| error("object_format_malformed", "max_align is not a number"))?;

    let mut sections = Vec::new();
    let mut seen_kinds = Vec::new();
    for line in lines.iter().filter(|l| l.starts_with("object_section:")) {
        let s = row(line, "object_section:")?;
        let kind = field(&s, "kind")?.to_owned();
        let name = field(&s, "name")?.to_owned();
        let align: i64 = field(&s, "align")?
            .parse()
            .map_err(|_| error("object_format_malformed", "align is not a number"))?;
        if align <= 0 || align > max_align {
            return Err(error(
                "object_section_misaligned",
                format!("{name} alignment {align} outside 1..{max_align}"),
            ));
        }
        if seen_kinds.contains(&kind) {
            return Err(error("object_section_kind_duplicated", format!("duplicate kind {kind}")));
        }
        // ELF and Mach-O spell sections differently. A descriptor using the
        // wrong spelling is describing a different object file.
        let spelling_ok = match expected {
            "elf" => name.starts_with('.'),
            _ => name.starts_with("__") && name.contains(','),
        };
        if !spelling_ok {
            return Err(error(
                "object_section_name_wrong_format",
                format!("{name} is not a valid {expected} section name"),
            ));
        }
        seen_kinds.push(kind.clone());
        sections.push((kind, name, align));
    }
    if sections.is_empty() {
        return Err(error("object_format_declares_no_sections", "descriptor declares no sections"));
    }

    let mut witness = String::new();
    witness.push_str(&format!("format: {OBJECT_FORMAT_WITNESS_FORMAT}\n"));
    witness.push_str(&format!("authority: {AUTHORITY}\n"));
    witness.push_str(&format!(
        "object_format:target_id={};object_format={};os={};derived_from={};max_align={};\n",
        field(&descriptor, "target_id")?, expected, operating_system,
        "operating_system_in_declared_target_identity", max_align,
    ));
    for (kind, name, align) in &sections {
        witness.push_str(&format!("object_section:kind={kind};name={name};align={align};\n"));
    }
    Ok(witness)
}

pub fn lower_object_format_witness_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let request = fs::read_to_string(path)?;
    Ok(lower_object_format_witness(&request)?)
}

// ---- Patch 18.4: relocation model and validation ----

const RELOCATION_FORMAT: &str = "gust.compiler_relocation.v1";
const RELOCATION_WITNESS_FORMAT: &str = "gust.relocation_witness.v1";

/// Zero-initialised data holds no bytes, so it can hold no relocation.
const PERMITTED_SECTIONS: [&str; 3] = ["text", "read_only_data", "data"];

/// Absolute kinds carry an explicit addend; relative kinds carry none. The
/// worker recomputes this rather than trusting the request's claim.
fn relocation_is_absolute(kind: &str) -> bool {
    matches!(kind,
        "R_X86_64_64" | "R_AARCH64_ABS64" | "R_386_32"
        | "X86_64_RELOC_UNSIGNED" | "ARM64_RELOC_UNSIGNED")
}

pub fn lower_relocation_witness(request: &str) -> Result<String, TargetError> {
    let lines: Vec<&str> = request.lines().collect();
    if header(&lines, "format")? != RELOCATION_FORMAT {
        return Err(error("relocation_malformed", "unknown request format"));
    }
    if header(&lines, "authority")? != AUTHORITY {
        return Err(error("relocation_malformed", "unknown target authority"));
    }

    let model_line = lines.iter().find(|l| l.starts_with("relocation_model:"))
        .ok_or_else(|| error("relocation_malformed", "request declares no relocation model"))?;
    let model = row(model_line, "relocation_model:")?;

    // A model validating after output could exist cannot preserve it.
    if field(&model, "stage")? != "before_object_publication_and_before_linker_invocation" {
        return Err(error("relocation_validated_too_late",
            "relocation validation must precede object publication and linker invocation"));
    }
    let object_format = field(&model, "object_format")?;
    let prefix_ok = |kind: &str| match object_format {
        "elf" => kind.starts_with("R_"),
        _ => kind.starts_with("X86_64_RELOC_") || kind.starts_with("ARM64_RELOC_"),
    };

    let reloc_line = lines.iter().find(|l| l.starts_with("relocation:"))
        .ok_or_else(|| error("relocation_malformed", "request declares no relocation"))?;
    let reloc = row(reloc_line, "relocation:")?;

    let kind = field(&reloc, "kind")?;
    if !prefix_ok(kind) {
        return Err(error("relocation_kind_unknown",
            format!("{kind} is not a {object_format} relocation kind")));
    }
    let section = field(&reloc, "section")?;
    if !PERMITTED_SECTIONS.contains(&section) {
        return Err(error("relocation_in_disallowed_section",
            format!("{section} holds no bytes and can hold no relocation")));
    }
    let offset: i64 = field(&reloc, "offset")?.parse()
        .map_err(|_| error("relocation_offset_malformed", "offset is not a number"))?;
    if offset < 0 {
        return Err(error("relocation_offset_malformed", "offset is negative"));
    }
    let addend: i64 = field(&reloc, "addend")?.parse()
        .map_err(|_| error("relocation_addend_malformed", "addend is not a number"))?;

    // The request states absoluteness; the worker recomputes it.
    let absolute = relocation_is_absolute(kind);
    let claimed_absolute = match field(&reloc, "absolute")? {
        "0" => false, "1" => true,
        other => return Err(error("relocation_malformed", format!("absolute={other}"))),
    };
    if claimed_absolute != absolute {
        return Err(error("relocation_addend_malformed",
            "claimed absoluteness disagrees with the relocation kind"));
    }
    if !absolute && addend != 0 {
        return Err(error("relocation_addend_malformed",
            format!("{kind} is relative and must carry no addend")));
    }
    let symbol = reloc.get("symbol").map(String::as_str).unwrap_or_default();
    if symbol.is_empty() {
        return Err(error("relocation_symbol_missing", "relocation names no symbol"));
    }

    let mut witness = String::new();
    witness.push_str(&format!("format: {RELOCATION_WITNESS_FORMAT}\n"));
    witness.push_str(&format!("authority: {AUTHORITY}\n"));
    witness.push_str(&format!(
        "relocation_model:target_id={};object_format={};arch={};stage={};\n",
        field(&model, "target_id")?, object_format, field(&model, "arch")?, field(&model, "stage")?,
    ));
    witness.push_str(&format!(
        "relocation:kind={};section={};offset={};addend={};symbol={};absolute={};\n",
        kind, section, offset, addend, symbol, u8::from(absolute),
    ));
    Ok(witness)
}

pub fn lower_relocation_witness_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let request = fs::read_to_string(path)?;
    Ok(lower_relocation_witness(&request)?)
}

// ---- Patch 18.5: target-specific ABI selection ----

const TARGET_ABI_FORMAT: &str = "gust.compiler_target_abi.v1";
const TARGET_ABI_WITNESS_FORMAT: &str = "gust.target_abi_witness.v1";

/// The only calling convention the Phase 16 authority accepts. The worker holds
/// this as the accepted set rather than deriving it, because widening it is
/// Phase 16's decision to make, not the backend's.
const ACCEPTED_ABI_IDS: [&str; 1] = ["gust_canonical_v1"];
const PLATFORM_CONVENTION_DEFERRED: &str = "deferred_to_a_later_abi_phase";

pub fn lower_target_abi_witness(request: &str) -> Result<String, TargetError> {
    let lines: Vec<&str> = request.lines().collect();
    if header(&lines, "format")? != TARGET_ABI_FORMAT {
        return Err(error("target_abi_malformed", "unknown request format"));
    }
    if header(&lines, "authority")? != AUTHORITY {
        return Err(error("target_abi_malformed", "unknown target authority"));
    }

    let abi_line = lines.iter().find(|l| l.starts_with("target_abi:"))
        .ok_or_else(|| error("target_abi_selection_missing", "request declares no ABI selection"))?;
    let selection = row(abi_line, "target_abi:")?;

    let abi_id = field(&selection, "abi_id")?;
    if !ACCEPTED_ABI_IDS.contains(&abi_id) {
        return Err(error("target_abi_undeclared_by_phase16",
            format!("{abi_id} is not an ABI the Phase 16 authority accepts")));
    }
    let compatibility = field(&selection, "compatibility")?;
    if compatibility != "compatible" && compatibility != "incompatible" {
        return Err(error("target_abi_incompatible",
            format!("{compatibility} is not a compatibility decision")));
    }
    // Selecting a platform convention would be Phase 18 defining ABI semantics.
    if field(&selection, "platform_convention")? != PLATFORM_CONVENTION_DEFERRED {
        return Err(error("target_abi_platform_convention_selected_without_phase16_support",
            "platform calling conventions are not Phase 16's to offer yet"));
    }

    let mut witness = String::new();
    witness.push_str(&format!("format: {TARGET_ABI_WITNESS_FORMAT}\n"));
    witness.push_str(&format!("authority: {AUTHORITY}\n"));
    witness.push_str(&format!(
        "target_abi:target_id={};abi_id={};owner={};compatibility={};platform_convention={};\n",
        field(&selection, "target_id")?, abi_id, field(&selection, "owner")?,
        compatibility, PLATFORM_CONVENTION_DEFERRED,
    ));
    Ok(witness)
}

pub fn lower_target_abi_witness_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let request = fs::read_to_string(path)?;
    Ok(lower_target_abi_witness(&request)?)
}
