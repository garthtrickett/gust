import json
import os
import sys
import re
import math
from difflib import SequenceMatcher

# --- Aider-style Regexes for Block Parsing ---
HEAD_RE = re.compile(r"^<{5,9} SEARCH>?\s*$")
DIVIDER_RE = re.compile(r"^={5,9}\s*$")
UPDATED_RE = re.compile(r"^>{5,9} REPLACE\s*$")

# --- Aider Matching & Replacement Strategies ---

def prep(content):
    """Ensures content ends with newline and splits into lines keeping line endings."""
    if content and not content.endswith("\n"):
        content += "\n"
    lines = content.splitlines(keepends=True)
    return content, lines

def perfect_replace(whole_lines, part_lines, replace_lines):
    """Strategy 1: Exact matching."""
    part_tup = tuple(part_lines)
    part_len = len(part_lines)

    if part_len == 0:
        return "".join(replace_lines + whole_lines)

    for i in range(len(whole_lines) - part_len + 1):
        if tuple(whole_lines[i : i + part_len]) == part_tup:
            res = whole_lines[:i] + replace_lines + whole_lines[i + part_len :]
            return "".join(res)
    return None

def match_but_for_leading_whitespace(whole_lines, part_lines):
    num = len(whole_lines)
    if not all(whole_lines[i].lstrip() == part_lines[i].lstrip() for i in range(num)):
        return None

    add = set(
        whole_lines[i][: len(whole_lines[i]) - len(part_lines[i])]
        for i in range(num)
        if whole_lines[i].strip()
    )

    if len(add) != 1:
        return None
    return add.pop()

def replace_part_with_missing_leading_whitespace(whole_lines, part_lines, replace_lines):
    """Strategy 2: Handles uniformly indented/outdented blocks."""
    if not part_lines:
        return None

    leading = [len(p) - len(p.lstrip()) for p in part_lines if p.strip()] + [
        len(p) - len(p.lstrip()) for p in replace_lines if p.strip()
    ]

    if leading and min(leading):
        num_leading = min(leading)
        part_lines = [p[num_leading:] if p.strip() else p for p in part_lines]
        replace_lines = [p[num_leading:] if p.strip() else p for p in replace_lines]

    num_part_lines = len(part_lines)
    for i in range(len(whole_lines) - num_part_lines + 1):
        add_leading = match_but_for_leading_whitespace(
            whole_lines[i : i + num_part_lines], part_lines
        )
        if add_leading is None:
            continue

        adjusted_replace = [add_leading + rline if rline.strip() else rline for rline in replace_lines]
        res = whole_lines[:i] + adjusted_replace + whole_lines[i + num_part_lines :]
        return "".join(res)
    return None

def try_dotdotdots(whole, part, replace):
    """Strategy 4: Handles blocks where the LLM used '...' to skip lines."""
    dots_re = re.compile(r"(^\s*\.\.\.\n)", re.MULTILINE | re.DOTALL)
    part_pieces = re.split(dots_re, part)
    replace_pieces = re.split(dots_re, replace)

    if len(part_pieces) != len(replace_pieces) or len(part_pieces) == 1:
        return None

    all_dots_match = all(part_pieces[i] == replace_pieces[i] for i in range(1, len(part_pieces), 2))
    if not all_dots_match:
        return None

    part_pieces = [part_pieces[i] for i in range(0, len(part_pieces), 2)]
    replace_pieces = [replace_pieces[i] for i in range(0, len(replace_pieces), 2)]

    for p, r in zip(part_pieces, replace_pieces):
        if not p and not r: continue
        if not p and r:
            if not whole.endswith("\n"): whole += "\n"
            whole += r
            continue
        if whole.count(p) == 0 or whole.count(p) > 1:
            return None
        whole = whole.replace(p, r, 1)
    
    return whole

def replace_closest_edit_distance(whole_lines, part, part_lines, replace_lines):
    """Strategy 5: Fuzzy matching using Levenshtein distance fallback."""
    if not part_lines:
        return None

    # --- SAFETY CATCH: Prevent O(N^2) infinite stalling on massive blocks ---
    if len(part_lines) > 50:
        print(f"    ⚠️  Block is too large for fuzzy matching ({len(part_lines)} lines). Skipping to prevent stall.", flush=True)
        return None

    print(f"    🔍 Strict match failed. Falling back to fuzzy matching (target: {len(part_lines)} lines)...", flush=True)

    similarity_thresh = 0.55
    max_similarity = 0
    most_similar_chunk_start = -1
    most_similar_chunk_end = -1

    scale = 0.1
    min_len = math.floor(len(part_lines) * (1 - scale))
    max_len = math.ceil(len(part_lines) * (1 + scale))

    for length in range(min_len, max_len):
        for i in range(len(whole_lines) - length + 1):
            chunk = whole_lines[i : i + length]
            chunk_str = "".join(chunk)

            similarity = SequenceMatcher(None, chunk_str, part).ratio()

            if similarity > max_similarity and similarity:
                max_similarity = similarity
                most_similar_chunk_start = i
                most_similar_chunk_end = i + length

    if max_similarity < similarity_thresh:
        print(f"    ❌ Fuzzy match failed. Best similarity found: {max_similarity*100:.1f}% (requires {similarity_thresh*100:.1f}%)", flush=True)
        return None

    print(f"    ✅ Fuzzy match succeeded with {max_similarity*100:.1f}% similarity.", flush=True)
    modified_whole = (
        whole_lines[:most_similar_chunk_start]
        + replace_lines
        + whole_lines[most_similar_chunk_end:]
    )
    return "".join(modified_whole)

def perfect_or_whitespace(whole_lines, part_lines, replace_lines):
    """Orchestrates strict matching strategies."""
    res = perfect_replace(whole_lines, part_lines, replace_lines)
    if res: return res, "Exact match"

    res = replace_part_with_missing_leading_whitespace(whole_lines, part_lines, replace_lines)
    if res: return res, "Indentation-adjusted match"
    
    return None, None

def replace_most_similar_chunk(whole, part, replace):
    """Aider orchestrator: Passes the blocks through the fallback waterfall."""
    whole, whole_lines = prep(whole)
    part, part_lines = prep(part)
    replace, replace_lines = prep(replace)

    # 1 & 2. Try perfect match or whitespace-adjusted match
    res, strategy = perfect_or_whitespace(whole_lines, part_lines, replace_lines)
    if res: return res, strategy

    # 3. Try dropping a spuriously generated leading blank line
    if len(part_lines) > 2 and not part_lines[0].strip():
        res, strategy = perfect_or_whitespace(whole_lines, part_lines[1:], replace_lines)
        if res: return res, "Skipped leading blank line match"

    # 4. Try matching with ...
    res = try_dotdotdots(whole, part, replace)
    if res: return res, "Elision (...) match"

    # 5. Try fuzzy matching (will safely exit if block is too large)
    res = replace_closest_edit_distance(whole_lines, part, part_lines, replace_lines)
    if res: return res, "Fuzzy sequence match (>80% similarity)"

    return None, "Failed to match"

# --- File Parsing & Application ---

def parse_diff_blocks(diff_text):
    """Parses SEARCH/REPLACE blocks using robust Aider regexes."""
    lines = diff_text.splitlines(keepends=True)
    blocks = []
    i = 0
    while i < len(lines):
        if HEAD_RE.match(lines[i].strip()):
            search_lines = []
            i += 1
            while i < len(lines) and not DIVIDER_RE.match(lines[i].strip()):
                search_lines.append(lines[i])
                i += 1
            
            if i >= len(lines): break # Malformed block
            
            replace_lines = []
            i += 1
            while i < len(lines) and not UPDATED_RE.match(lines[i].strip()):
                replace_lines.append(lines[i])
                i += 1
            
            blocks.append(("".join(search_lines), "".join(replace_lines)))
        i += 1
    return blocks

def apply_diffs(json_str):
    if not json_str.strip(): return False
    
    clean_json = json_str.strip()

    # Robustly extract JSON block using regex
    json_match = re.search(r"```(?:json)?\s*\n(.*?)\n```", clean_json, re.DOTALL)
    if json_match:
        clean_json = json_match.group(1)
    else:
        # Fallback: strip leading text until the first '{' or '['
        start_idx = clean_json.find('{')
        alt_start = clean_json.find('[')
        if start_idx == -1 or (alt_start != -1 and alt_start < start_idx):
            start_idx = alt_start
        
        if start_idx != -1:
            clean_json = clean_json[start_idx:]
            end_idx = max(clean_json.rfind('}'), clean_json.rfind(']'))
            if end_idx != -1:
                clean_json = clean_json[:end_idx+1]

    try:
        data = json.loads(clean_json.strip())
    except json.JSONDecodeError as e:
        print(f"❌ Failed to decode JSON: {e}", flush=True)
        return False

    print(f"🤖 Summary: {data.get('summary', 'No summary provided')}", flush=True)
    planned_updates = {}

    for file_entry in data.get("files", []):
        path = file_entry.get("file_path")
        diff_text = file_entry.get("code_diff", "")
        
        if not os.path.exists(path):
            print(f"⚠️  File not found, creating new file: {path}", flush=True)
            content = ""
        else:
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()

        blocks = parse_diff_blocks(diff_text)
        if not blocks:
            print(f"⚠️  Warning: No valid SEARCH/REPLACE blocks found for {path}", flush=True)
            continue

        print(f"📄 Processing {path} ({len(blocks)} blocks)...", flush=True)

        for i, (search_part, replacement) in enumerate(blocks, 1):
            new_content, strategy = replace_most_similar_chunk(content, search_part, replacement)
            
            if new_content:
                content = new_content
                print(f"  ✨ [SUCCESS] Block {i} ({strategy})", flush=True)
            else:
                print(f"  ❌ [FAIL] Block {i} failed to match.", flush=True)
                print(f"     Target snippet could not be matched safely.", flush=True)
                return False

        planned_updates[path] = content

    # Transactional Commit: Only write if EVERY block in EVERY file matched
    for path, new_content in planned_updates.items():
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"✅ Applied all changes to {path}", flush=True)
        
    return True

if __name__ == "__main__":
    target_file = sys.argv[1] if len(sys.argv) > 1 else "response.json"
    if os.path.exists(target_file):
        with open(target_file, "r", encoding="utf-8") as f:
            success = apply_diffs(f.read())
            sys.exit(0 if success else 1)
    else:
        print(f"❌ File not found: {target_file}", flush=True)
        sys.exit(1)
