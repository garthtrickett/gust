#!/usr/bin/env bash

phase14_select_targets() {
  if [ "$#" -ne 4 ]; then
    echo "phase14_select_targets requires validator, target command, primary command, and all-target flag" >&2
    return 2
  fi

  local validator="$1"
  local targets_command="$2"
  local primary_command="$3"
  local feature_all_targets="$4"
  local global_all_targets="${PHASE14_ALL_TARGETS:-0}"
  local target_filter="${PHASE14_TARGET:-}"
  local declared

  case "$feature_all_targets:$global_all_targets" in
    0:0|0:1|1:0|1:1)
      ;;
    *)
      echo "Phase 14 all-target flags must be 0 or 1." >&2
      return 2
      ;;
  esac

  primary_target="$(python3 "$validator" "$primary_command")"
  mapfile -t declared < <(python3 "$validator" "$targets_command")
  if [ "${#declared[@]}" -eq 0 ]; then
    echo "Phase 14 target authority selected no declared targets." >&2
    return 1
  fi
  if ! printf '%s\n' "${declared[@]}" | grep -F -x "$primary_target" >/dev/null; then
    echo "Phase 14 primary target is not in the declared target authority: $primary_target" >&2
    return 1
  fi

  if [ -n "$target_filter" ]; then
    if ! printf '%s\n' "${declared[@]}" | grep -F -x "$target_filter" >/dev/null; then
      echo "Requested Phase 14 target is not declared: $target_filter" >&2
      return 1
    fi
    targets=("$target_filter")
  elif [ "$feature_all_targets" = "1" ] || [ "$global_all_targets" = "1" ]; then
    targets=("${declared[@]}")
  else
    targets=("$primary_target")
  fi
}