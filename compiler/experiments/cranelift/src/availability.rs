//! Phase 17.13 availability and compatibility decisions.
//!
//! The worker validates the compiler-produced Rust component request and emits a
//! witness that must match MIR-to-C byte for byte. It holds no view of which
//! Rust symbols exist or how they are spelled — that is the compiler's.

use std::collections::HashMap;
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_availability.v1";
const WITNESS_FORMAT: &str = "gust.availability_witness.v1";
const LINKAGE: &str = "all_compatibility_decisions_complete_before_any_output_could_exist";

/// The frozen decision order. Position in this array is the required
/// decision_order value, so a reordered request cannot pass as the frozen one.
const VALIDATION_STEPS: [&str; 8] = [
    "package_manifest_format",
    "runtime_abi_identity_and_version",
    "target_identity",
    "required_component_presence",
    "required_symbol_presence_and_version",
    "function_abi_layout_and_resource_compatibility",
    "declared_system_library_requirements",
    "deterministic_component_and_link_ordering",
];
const STAGE_BOUNDARIES: [&str; 2] = [
    "before_worker_execution",
    "after_target_selection_before_linker_invocation",
];
const REJECTION_CLASSES: [&str; 9] = [
    "runtime_package_missing", "runtime_manifest_malformed",
    "runtime_wrong_target", "runtime_abi_incompatible",
    "runtime_component_missing", "runtime_symbol_missing",
    "runtime_symbol_version_incompatible",
    "runtime_classification_inconsistent",
    "runtime_link_plan_dependency_undeclared",
];

#[derive(Debug)]
pub struct AvailabilityError {
    reason_code: &'static str,
    detail: String,
}

impl fmt::Display for AvailabilityError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "gust_availability_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for AvailabilityError {}

fn error(reason: &'static str, detail: impl Into<String>) -> AvailabilityError {
    AvailabilityError { reason_code: reason, detail: detail.into() }
}

#[derive(Debug, Clone)]
pub struct AvailabilityDecision {
    pub decision_order: usize,
    pub validation_step: String,
    pub rejection_class: String,
    pub stage_boundary: String,
}

fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, AvailabilityError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("runtime_availability_malformed_decision", format!("missing {key}")))
}

fn row(line: &str) -> Result<HashMap<String, String>, AvailabilityError> {
    let body = line
        .strip_prefix("availability_decision:")
        .ok_or_else(|| error("runtime_availability_malformed_decision", "invalid row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|p| !p.is_empty()) {
        let Some((k, v)) = part.split_once('=') else {
            return Err(error("runtime_availability_malformed_decision", format!("invalid field {part}")));
        };
        if fields.insert(k.to_owned(), v.to_owned()).is_some() {
            return Err(error("runtime_availability_late_decision", format!("duplicate field {k}")));
        }
    }
    Ok(fields)
}

fn field<'a>(f: &'a HashMap<String, String>, k: &str) -> Result<&'a str, AvailabilityError> {
    f.get(k)
        .map(String::as_str)
        .filter(|v| !v.is_empty())
        .ok_or_else(|| error("runtime_availability_malformed_decision", format!("missing {k}")))
}

fn parse_row(f: &HashMap<String, String>, target: &str) -> Result<AvailabilityDecision, AvailabilityError> {
    for key in ["id", "order", "step"] {
        if field(f, key).is_err() {
            return Err(error("runtime_availability_malformed_decision", format!("missing {key}")));
        }
    }
    if field(f, "target")? != target {
        return Err(error("runtime_availability_malformed_decision", "target disagrees with request"));
    }
    let validation_step = field(f, "step")?;
    let Some(expected_order) = VALIDATION_STEPS.iter().position(|s| *s == validation_step) else {
        return Err(error(
            "runtime_availability_malformed_decision",
            format!("unknown validation step {validation_step}"),
        ));
    };

    // Position in the frozen order is not advisory: a decision claiming a
    // different slot is a reordered sequence, not the frozen one.
    let decision_order: usize = field(f, "order")?
        .parse()
        .map_err(|_| error("runtime_availability_decision_order_drift", "order is not a number"))?;
    if decision_order != expected_order {
        return Err(error(
            "runtime_availability_decision_order_drift",
            format!("{validation_step} claims order {decision_order}, frozen order is {expected_order}"),
        ));
    }

    // A decision deferred past the point output could exist is not a decision.
    let stage_boundary = field(f, "stage")?;
    if !STAGE_BOUNDARIES.contains(&stage_boundary) {
        return Err(error(
            "runtime_availability_late_decision",
            format!("{stage_boundary} is after output could already exist"),
        ));
    }
    let rejection_class = field(f, "rejection")?;
    if !REJECTION_CLASSES.contains(&rejection_class) {
        return Err(error(
            "runtime_availability_unclassified_rejection",
            format!("{rejection_class} is not a stable rejection class"),
        ));
    }
    Ok(AvailabilityDecision {
        decision_order,
        validation_step: validation_step.to_owned(),
        rejection_class: rejection_class.to_owned(),
        stage_boundary: stage_boundary.to_owned(),
    })
}

pub fn parse_availability_request(
    request: &str,
) -> Result<(String, Vec<AvailabilityDecision>), AvailabilityError> {
    let lines: Vec<&str> = request.lines().collect();
    let format = header(&lines, "format")?;
    if format != FORMAT {
        return Err(error("runtime_availability_malformed_decision", format!("unknown format {format}")));
    }
    let target = header(&lines, "target")?.to_owned();
    header(&lines, "triple")?;
    let mut components: Vec<AvailabilityDecision> = Vec::new();
    for line in lines.iter().filter(|l| l.starts_with("availability_decision:")) {
        let component = parse_row(&row(line)?, &target)?;
        // Two components providing the same export is a compiler-resolved
        // ambiguity, never something the linker gets to discover.
        for existing in &components {
            if existing.validation_step == component.validation_step {
                return Err(error(
                    "runtime_availability_malformed_decision",
                    format!("{} is decided twice", component.validation_step),
                ));
            }
        }
        components.push(component);
    }
    if components.is_empty() {
        return Err(error("runtime_availability_malformed_decision", "no declared decisions"));
    }
    // A partial order means some compatibility question went unasked.
    if components.len() != VALIDATION_STEPS.len() {
        return Err(error(
            "runtime_availability_incomplete_order",
            format!("{} of {} decisions declared", components.len(), VALIDATION_STEPS.len()),
        ));
    }
    Ok((target, components))
}

pub fn render_availability_witness(target: &str, components: &[AvailabilityDecision]) -> String {
    let mut out = format!("witness: {WITNESS_FORMAT}\ntarget: {target}\n");
    for c in components {
        out.push_str("decision:");
        out.push_str(&format!("order={};", c.decision_order));
        out.push_str(&format!("step={};", c.validation_step));
        out.push_str(&format!("rejection={};", c.rejection_class));
        out.push_str(&format!("stage={};", c.stage_boundary));
        out.push_str(&format!("linkage={LINKAGE};"));
        out.push('\n');
    }
    out
}

pub fn lower_availability_witness_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let request = fs::read_to_string(path)?;
    let (target, components) = parse_availability_request(&request)?;
    Ok(render_availability_witness(&target, &components))
}
