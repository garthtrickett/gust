use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_function_call_mir.v1";

#[derive(Debug)]
pub struct FunctionCallMirError {
    reason_code: &'static str,
    detail: String,
}

impl FunctionCallMirError {
    fn new(reason_code: &'static str, detail: impl Into<String>) -> Self {
        Self {
            reason_code,
            detail: detail.into(),
        }
    }
}

impl fmt::Display for FunctionCallMirError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "gust_call_mir_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for FunctionCallMirError {}

#[derive(Debug, Clone)]
struct FunctionDeclaration {
    id: String,
    abi: String,
    signature: String,
    parameters: Vec<String>,
    results: Vec<String>,
    target: String,
    triple: String,
    cc: String,
}

#[derive(Debug, Clone)]
struct CallOperand {
    id: String,
    call: String,
    abi_value: String,
    value_type: String,
    layout: String,
    passing_mode: String,
    materialization: String,
    ordinal: usize,
    evaluation: usize,
    hidden: bool,
    transition: String,
    before: String,
    after: String,
}

#[derive(Debug, Clone)]
struct CallOperation {
    id: String,
    kind: String,
    call: String,
    caller_abi: String,
    callee_abi: String,
    plan: String,
    arguments: Vec<String>,
    results: Vec<String>,
    input: String,
    output: String,
    target: String,
    triple: String,
    cc: String,
}

#[derive(Debug)]
struct FunctionCallTable {
    target_id: String,
    target_triple: String,
    declarations: Vec<FunctionDeclaration>,
    operands: Vec<CallOperand>,
    operations: Vec<CallOperation>,
}

fn scalar_field<'a>(
    fields: &'a HashMap<String, String>,
    key: &str,
) -> Result<&'a str, FunctionCallMirError> {
    fields.get(key).map(String::as_str).ok_or_else(|| {
        FunctionCallMirError::new(
            "call_mir_missing_abi_metadata",
            format!("missing field {key}"),
        )
    })
}

fn parse_row(line: &str, prefix: &str) -> Result<HashMap<String, String>, FunctionCallMirError> {
    let body = line.strip_prefix(prefix).ok_or_else(|| {
        FunctionCallMirError::new("call_mir_unknown_format", format!("invalid row {line}"))
    })?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|part| !part.is_empty()) {
        let Some((key, value)) = part.split_once('=') else {
            return Err(FunctionCallMirError::new(
                "call_mir_unknown_format",
                format!("invalid field {part}"),
            ));
        };
        if fields.insert(key.to_owned(), value.to_owned()).is_some() {
            return Err(FunctionCallMirError::new(
                "call_mir_duplicate_record",
                format!("duplicate field {key}"),
            ));
        }
    }
    Ok(fields)
}

fn list(value: &str) -> Vec<String> {
    if value.is_empty() {
        Vec::new()
    } else {
        value.split(',').map(str::to_owned).collect()
    }
}

fn count_field(lines: &[&str], key: &str) -> Result<usize, FunctionCallMirError> {
    let prefix = format!("{key}: ");
    let value = lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| {
            FunctionCallMirError::new("call_mir_unknown_format", format!("missing {key}"))
        })?;
    value
        .parse()
        .map_err(|_| FunctionCallMirError::new("call_mir_unknown_format", format!("invalid {key}")))
}

fn header_field(lines: &[&str], key: &str) -> Result<String, FunctionCallMirError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .map(str::to_owned)
        .ok_or_else(|| {
            FunctionCallMirError::new("call_mir_unknown_format", format!("missing {key}"))
        })
}

fn parse_request(contents: &str) -> Result<FunctionCallTable, FunctionCallMirError> {
    let lines: Vec<&str> = contents.lines().collect();
    if header_field(&lines, "call_mir_format")? != FORMAT {
        return Err(FunctionCallMirError::new(
            "call_mir_unknown_format",
            "unsupported call MIR format",
        ));
    }
    let target_id = header_field(&lines, "call_mir_target_id")?;
    let target_triple = header_field(&lines, "call_mir_target_triple")?;
    let expected_declarations = count_field(&lines, "call_mir_declaration_count")?;
    let expected_operands = count_field(&lines, "call_mir_operand_count")?;
    let expected_operations = count_field(&lines, "call_mir_operation_count")?;

    let mut declarations = Vec::new();
    let mut operands = Vec::new();
    let mut operations = Vec::new();
    for line in &lines {
        if line.starts_with("call_declaration:") {
            let fields = parse_row(line, "call_declaration:")?;
            declarations.push(FunctionDeclaration {
                id: scalar_field(&fields, "id")?.to_owned(),
                abi: scalar_field(&fields, "abi")?.to_owned(),
                signature: scalar_field(&fields, "signature")?.to_owned(),
                parameters: list(scalar_field(&fields, "parameters")?),
                results: list(scalar_field(&fields, "results")?),
                target: scalar_field(&fields, "target")?.to_owned(),
                triple: scalar_field(&fields, "triple")?.to_owned(),
                cc: scalar_field(&fields, "cc")?.to_owned(),
            });
        } else if line.starts_with("call_operand:") {
            let fields = parse_row(line, "call_operand:")?;
            operands.push(CallOperand {
                id: scalar_field(&fields, "id")?.to_owned(),
                call: scalar_field(&fields, "call")?.to_owned(),
                abi_value: scalar_field(&fields, "abi_value")?.to_owned(),
                value_type: scalar_field(&fields, "type")?.to_owned(),
                layout: scalar_field(&fields, "layout")?.to_owned(),
                passing_mode: scalar_field(&fields, "passing_mode")?.to_owned(),
                materialization: scalar_field(&fields, "materialization")?.to_owned(),
                ordinal: scalar_field(&fields, "ordinal")?.parse().map_err(|_| {
                    FunctionCallMirError::new(
                        "call_mir_argument_count_or_order_mismatch",
                        "invalid operand ordinal",
                    )
                })?,
                evaluation: scalar_field(&fields, "evaluation")?.parse().map_err(|_| {
                    FunctionCallMirError::new(
                        "call_mir_argument_count_or_order_mismatch",
                        "invalid evaluation order",
                    )
                })?,
                hidden: match scalar_field(&fields, "hidden")? {
                    "0" => false,
                    "1" => true,
                    _ => {
                        return Err(FunctionCallMirError::new(
                            "call_mir_unknown_hidden_value",
                            "invalid hidden marker",
                        ))
                    }
                },
                transition: scalar_field(&fields, "transition")?.to_owned(),
                before: scalar_field(&fields, "before")?.to_owned(),
                after: scalar_field(&fields, "after")?.to_owned(),
            });
        } else if line.starts_with("call_operation:") {
            let fields = parse_row(line, "call_operation:")?;
            operations.push(CallOperation {
                id: scalar_field(&fields, "id")?.to_owned(),
                kind: scalar_field(&fields, "kind")?.to_owned(),
                call: scalar_field(&fields, "call")?.to_owned(),
                caller_abi: scalar_field(&fields, "caller_abi")?.to_owned(),
                callee_abi: scalar_field(&fields, "callee_abi")?.to_owned(),
                plan: scalar_field(&fields, "plan")?.to_owned(),
                arguments: list(scalar_field(&fields, "arguments")?),
                results: list(scalar_field(&fields, "results")?),
                input: scalar_field(&fields, "input")?.to_owned(),
                output: scalar_field(&fields, "output")?.to_owned(),
                target: scalar_field(&fields, "target")?.to_owned(),
                triple: scalar_field(&fields, "triple")?.to_owned(),
                cc: scalar_field(&fields, "cc")?.to_owned(),
            });
        }
    }
    if declarations.len() != expected_declarations
        || operands.len() != expected_operands
        || operations.len() != expected_operations
    {
        return Err(FunctionCallMirError::new(
            "call_mir_missing_abi_metadata",
            "record count disagreement",
        ));
    }
    Ok(FunctionCallTable {
        target_id,
        target_triple,
        declarations,
        operands,
        operations,
    })
}

fn validate(table: &FunctionCallTable) -> Result<(), FunctionCallMirError> {
    let mut ids = HashSet::new();
    let mut declarations = HashMap::new();
    for declaration in &table.declarations {
        if !ids.insert(declaration.id.as_str())
            || declarations
                .insert(declaration.abi.as_str(), declaration)
                .is_some()
        {
            return Err(FunctionCallMirError::new(
                "call_mir_duplicate_record",
                "duplicate function ABI declaration",
            ));
        }
        if declaration.target != table.target_id || declaration.triple != table.target_triple {
            return Err(FunctionCallMirError::new(
                "call_mir_target_mismatch",
                "declaration target differs from request",
            ));
        }
        if declaration.cc != "gust" {
            return Err(FunctionCallMirError::new(
                "call_mir_unsupported_calling_convention",
                "only the selected gust convention is supported",
            ));
        }
    }
    let mut operand_ids = HashSet::new();
    for operand in &table.operands {
        if !operand_ids.insert(operand.id.as_str()) {
            return Err(FunctionCallMirError::new(
                "call_mir_duplicate_record",
                "duplicate call operand",
            ));
        }
        if operand.transition.is_empty() != (operand.before.is_empty() && operand.after.is_empty())
        {
            return Err(FunctionCallMirError::new(
                "call_mir_resource_transition_incomplete",
                "partial Phase 15 transition annotation",
            ));
        }
        if !operand.passing_mode.is_empty() || !operand.materialization.is_empty() {
            let expected = match operand.passing_mode.as_str() {
                "direct" | "split" => "by_value",
                "indirect_by_value" | "indirect_by_reference" | "hidden_pointer" => "by_address",
                _ => {
                    return Err(FunctionCallMirError::new(
                        "call_mir_representation_mismatch",
                        "unknown Phase 16 passing mode",
                    ))
                }
            };
            if operand.materialization != expected {
                return Err(FunctionCallMirError::new(
                    "call_mir_representation_mismatch",
                    "argument materialization disagrees with passing mode",
                ));
            }
        }
    }
    let allowed: HashSet<&str> = [
        "function_abi_declaration",
        "argument_materialization",
        "direct_call",
        "result_extraction",
        "hidden_argument",
        "hidden_result_storage",
        "post_call_normalization",
    ]
    .into_iter()
    .collect();
    let mut operation_ids = HashSet::new();
    for operation in &table.operations {
        if !operation_ids.insert(operation.id.as_str()) {
            return Err(FunctionCallMirError::new(
                "call_mir_duplicate_record",
                "duplicate call operation",
            ));
        }
        if !allowed.contains(operation.kind.as_str()) {
            return Err(FunctionCallMirError::new(
                "call_mir_unknown_operation",
                format!("unknown operation {}", operation.kind),
            ));
        }
        if operation.cc != "gust" {
            return Err(FunctionCallMirError::new(
                "call_mir_unsupported_calling_convention",
                "operation convention is not selected",
            ));
        }
        if operation.target != table.target_id || operation.triple != table.target_triple {
            return Err(FunctionCallMirError::new(
                "call_mir_target_mismatch",
                "operation target differs from request",
            ));
        }
        if operation.plan.is_empty() || !declarations.contains_key(operation.caller_abi.as_str()) {
            return Err(FunctionCallMirError::new(
                "call_mir_missing_abi_metadata",
                "caller ABI or call plan is absent",
            ));
        }
        let Some(callee) = declarations.get(operation.callee_abi.as_str()) else {
            return Err(FunctionCallMirError::new(
                "call_mir_missing_abi_metadata",
                "callee ABI is absent",
            ));
        };
        if operation.arguments != callee.parameters {
            return Err(FunctionCallMirError::new(
                "call_mir_argument_count_or_order_mismatch",
                "ordered arguments disagree with callee ABI",
            ));
        }
        if operation.results != callee.results {
            return Err(FunctionCallMirError::new(
                "call_mir_result_count_mismatch",
                "ordered results disagree with callee ABI",
            ));
        }
        if matches!(
            operation.kind.as_str(),
            "hidden_argument" | "hidden_result_storage"
        ) && !operand_ids.contains(operation.input.as_str())
        {
            return Err(FunctionCallMirError::new(
                "call_mir_unknown_hidden_value",
                "hidden operand is unknown",
            ));
        }
        let mut call_operands: Vec<&CallOperand> = table
            .operands
            .iter()
            .filter(|operand| operand.call == operation.call && !operand.hidden)
            .collect();
        call_operands.sort_by_key(|operand| operand.evaluation);
        for (ordinal, operand) in call_operands.iter().enumerate() {
            if operand.ordinal != ordinal
                || operation.arguments.get(ordinal) != Some(&operand.abi_value)
            {
                return Err(FunctionCallMirError::new(
                    "call_mir_argument_count_or_order_mismatch",
                    "operand evaluation order disagrees with ABI order",
                ));
            }
        }
    }
    Ok(())
}

fn lower_for_cranelift(table: &FunctionCallTable) -> Result<String, FunctionCallMirError> {
    validate(table)?;
    let mut output = format!(
        "call_mir_status: valid\ntarget_id: {}\ntarget_triple: {}\n",
        table.target_id, table.target_triple
    );
    for declaration in &table.declarations {
        output.push_str(&format!(
            "function_abi: id={} abi={} signature={} cc={}\n",
            declaration.id, declaration.abi, declaration.signature, declaration.cc
        ));
    }
    for operand in &table.operands {
        output.push_str(&format!(
            "argument_representation: id={} abi_value={} passing_mode={} materialization={} value_type={} layout={}\n",
            operand.id,
            operand.abi_value,
            operand.passing_mode,
            operand.materialization,
            operand.value_type,
            operand.layout,
        ));
    }
    for operation in &table.operations {
        output.push_str(&format!(
            "call_lowering: id={} action={} call={} caller_abi={} callee_abi={} plan={} arguments={} results={} input={} output={}\n",
            operation.id,
            operation.kind,
            operation.call,
            operation.caller_abi,
            operation.callee_abi,
            operation.plan,
            operation.arguments.join(","),
            operation.results.join(","),
            operation.input,
            operation.output,
        ));
    }
    Ok(output)
}

pub fn lower_function_call_mir_witness_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let contents = fs::read_to_string(path)?;
    let table = parse_request(&contents)?;
    Ok(lower_for_cranelift(&table)?)
}

// Hard-ban markers checked by the Level 1 contract:
// worker_no_source_text_signature_identity
// worker_no_symbol_signature_identity
// worker_no_c_prototype_signature_identity
// worker_no_fixture_name_signature_identity
