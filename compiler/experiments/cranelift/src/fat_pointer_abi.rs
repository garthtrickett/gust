use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_fat_pointer_abi.v1";

#[derive(Debug)]
pub struct FatPointerAbiError {
    reason_code: &'static str,
    detail: String,
}

impl FatPointerAbiError {
    fn new(reason_code: &'static str, detail: impl Into<String>) -> Self {
        Self {
            reason_code,
            detail: detail.into(),
        }
    }
}

impl fmt::Display for FatPointerAbiError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "gust_fat_pointer_abi_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for FatPointerAbiError {}

fn error(reason: &'static str, detail: impl Into<String>) -> FatPointerAbiError {
    FatPointerAbiError::new(reason, detail)
}

fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, FatPointerAbiError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("fat_pointer_unknown_format", format!("missing {key}")))
}

fn row(line: &str) -> Result<HashMap<String, String>, FatPointerAbiError> {
    let body = line
        .strip_prefix("fat_pointer_call:")
        .ok_or_else(|| error("fat_pointer_unknown_format", "invalid row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|part| !part.is_empty()) {
        let Some((key, value)) = part.split_once('=') else {
            return Err(error("fat_pointer_unknown_format", part));
        };
        if fields.insert(key.into(), value.into()).is_some() {
            return Err(error("fat_pointer_duplicate_identity", key));
        }
    }
    Ok(fields)
}

fn field<'a>(
    fields: &'a HashMap<String, String>,
    key: &str,
) -> Result<&'a str, FatPointerAbiError> {
    fields
        .get(key)
        .map(String::as_str)
        .ok_or_else(|| error("fat_pointer_record_invalid", format!("missing {key}")))
}

fn same(
    fields: &HashMap<String, String>,
    left: &str,
    right: &str,
    reason: &'static str,
) -> Result<(), FatPointerAbiError> {
    if field(fields, left)? != field(fields, right)? {
        return Err(error(reason, format!("{left} disagrees with {right}")));
    }
    Ok(())
}

fn validate_row(
    fields: &HashMap<String, String>,
    target: &str,
    triple: &str,
) -> Result<(), FatPointerAbiError> {
    for key in ["id", "fat_pointer", "trait_object", "data", "source"] {
        if field(fields, key)?.is_empty() {
            return Err(error("fat_pointer_record_invalid", key));
        }
    }
    if field(fields, "form")? != "borrowed_trait_object_method_call" {
        return Err(error("fat_pointer_record_invalid", "form"));
    }
    if field(fields, "representation")? != "two_word_data_and_vtable"
        || target != "target:x86_64-unknown-linux-gnu"
        || triple != "x86_64-unknown-linux-gnu"
    {
        return Err(error(
            "fat_pointer_unsupported_target_representation",
            field(fields, "id")?,
        ));
    }
    if field(fields, "metadata_present")? != "1"
        || field(fields, "metadata")?.is_empty()
        || field(fields, "metadata_layout")?.is_empty()
        || field(fields, "vtable")?.is_empty()
    {
        return Err(error("fat_pointer_missing_metadata", field(fields, "id")?));
    }
    same(
        fields,
        "pair",
        "actual_pair",
        "fat_pointer_component_mismatch",
    )?;
    same(
        fields,
        "vtable",
        "actual_vtable",
        "fat_pointer_component_mismatch",
    )?;
    if field(fields, "data_layout")?.is_empty()
        || field(fields, "data_type")?.is_empty()
        || field(fields, "metadata_type")?.is_empty()
        || field(fields, "data_placement")? != "fat_pointer.word0.data"
        || field(fields, "metadata_placement")? != "fat_pointer.word1.vtable"
    {
        return Err(error(
            "fat_pointer_component_mismatch",
            field(fields, "id")?,
        ));
    }
    if field(fields, "required_alignment")? != "8" || field(fields, "actual_alignment")? != "8" {
        return Err(error(
            "fat_pointer_insufficient_alignment",
            field(fields, "id")?,
        ));
    }
    if field(fields, "signature")?.is_empty() || field(fields, "call_abi")?.is_empty() {
        return Err(error(
            "fat_pointer_unknown_method_signature",
            field(fields, "id")?,
        ));
    }
    same(
        fields,
        "signature",
        "actual_signature",
        "fat_pointer_unknown_method_signature",
    )?;
    same(
        fields,
        "call_abi",
        "actual_call_abi",
        "fat_pointer_unknown_method_signature",
    )?;
    if field(fields, "slot")?.is_empty()
        || field(fields, "slot_ordinal")? != "0"
        || field(fields, "slot")? != field(fields, "actual_slot")?
    {
        return Err(error(
            "fat_pointer_invalid_slot_identity",
            field(fields, "id")?,
        ));
    }
    let operations = field(fields, "operations")?;
    if !operations.contains("construct_fat_pointer")
        || !operations.contains("extract_vtable_method")
        || !operations.contains("typed_indirect_call")
    {
        return Err(error("fat_pointer_untyped_dispatch", field(fields, "id")?));
    }
    if field(fields, "resource")? != "borrowed_no_transfer_state_live" {
        return Err(error(
            "fat_pointer_resource_disposition_mismatch",
            field(fields, "id")?,
        ));
    }
    same(
        fields,
        "expected_result",
        "actual_result",
        "fat_pointer_method_result_mismatch",
    )?;
    if field(fields, "target")? != target
        || field(fields, "actual_target")? != target
        || field(fields, "triple")? != triple
        || field(fields, "actual_triple")? != triple
    {
        return Err(error(
            "fat_pointer_unsupported_target_representation",
            field(fields, "id")?,
        ));
    }
    Ok(())
}

fn validate(contents: &str) -> Result<(), FatPointerAbiError> {
    let lines: Vec<_> = contents.lines().collect();
    if header(&lines, "fat_pointer_format")? != FORMAT {
        return Err(error("fat_pointer_unknown_format", "unsupported format"));
    }
    let target = header(&lines, "fat_pointer_target_id")?;
    let triple = header(&lines, "fat_pointer_target_triple")?;
    let count: usize = header(&lines, "fat_pointer_call_count")?
        .parse()
        .map_err(|_| error("fat_pointer_unknown_format", "count"))?;
    let rows: Vec<_> = lines
        .iter()
        .filter(|line| line.starts_with("fat_pointer_call:"))
        .map(|line| row(line))
        .collect::<Result<_, _>>()?;
    if rows.len() != count || rows.is_empty() {
        return Err(error("fat_pointer_record_invalid", "count"));
    }
    let mut ids = HashSet::new();
    let mut fat_pointers = HashSet::new();
    for fields in &rows {
        if !ids.insert(field(fields, "id")?) || !fat_pointers.insert(field(fields, "fat_pointer")?)
        {
            return Err(error(
                "fat_pointer_duplicate_identity",
                field(fields, "id")?,
            ));
        }
        validate_row(fields, target, triple)?;
    }
    Ok(())
}

pub fn lower_fat_pointer_abi_witness_path(path: &Path) -> Result<String, FatPointerAbiError> {
    let contents = fs::read_to_string(path)
        .map_err(|cause| error("fat_pointer_request_read_failed", cause.to_string()))?;
    validate(&contents)?;
    let mut witness = contents;
    if !witness.ends_with('\n') {
        witness.push('\n');
    }
    Ok(witness)
}

const _WORKER_POLICY: &str = "worker_consumes_compiler_fat_pointer_components_layouts_vtable_slot_and_typed_call_abi_no_backend_vtable_interpretation";
