#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_call_return_zero_evidence"
mkdir -p "$build_root"
make build/gust-runtime-package.a
test -x ./gust
test -f build/gust-native-backend
driver="$PWD/build/gust-native-backend"

GUST_TEST_MIR_TO_C_UNAVAILABLE=1 GUST_NATIVE_BACKEND_DRIVER="$driver" \
  ./gust --backend cranelift -o "$build_root/typechecker" \
    compiler/phase26_call_return_zero_test_entry.gst \
    >"$build_root/typechecker.compile.stdout" 2>"$build_root/typechecker.compile.stderr"
test ! -s "$build_root/typechecker.compile.stdout"
test ! -s "$build_root/typechecker.compile.stderr"
"$build_root/typechecker" >"$build_root/typechecker.stdout" 2>"$build_root/typechecker.stderr"
test ! -s "$build_root/typechecker.stderr"
printf 'SUCCESS: checked direct-return zero summaries, RawPointer AsCast chains, mixed Move/Take cast chains, and exclusions verified\n' >"$build_root/typechecker.expected"
cmp -s "$build_root/typechecker.expected" "$build_root/typechecker.stdout"

poison="$build_root/poison-driver"
marker="$build_root/poison-driver.invoked"
cat >"$poison" <<'POISON'
#!/usr/bin/env bash
printf 'invoked\n' >"$GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER"
exit 97
POISON
chmod +x "$poison"

for case_name in caller_first callee_first safe_return mayzero nonzero unknown unsafe_target prior_error; do
  fixture="compiler/phase26_call_return_zero_${case_name}_source.gst"
  output="$build_root/$case_name"
  rm -f "$output" "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" "$fixture" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  case "$case_name" in
    caller_first) line=3; boundary='argument' ;;
    callee_first) line=4; boundary='argument' ;;
    safe_return) line=3; boundary='return' ;;
    mayzero) line=3; boundary='argument' ;;
    prior_error)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got Str' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    *)
      rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
      rg -F 'reason_code=deferred_p13_parameter_argument_target_dependent_abi' "$output.stdout" >/dev/null
      if rg -F 'TypeError' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
  esac
  if [[ "$case_name" == caller_first || "$case_name" == callee_first || "$case_name" == safe_return || "$case_name" == mayzero ]]; then
    rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
    rg -F "[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function $boundary" "$output.stdout" >/dev/null
  fi
  if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null &&
     [[ "$case_name" == caller_first || "$case_name" == callee_first || "$case_name" == safe_return || "$case_name" == mayzero || "$case_name" == prior_error ]]; then
    exit 1
  fi
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

for case_name in caller_first callee_first mayzero overwrite nonzero unknown unsafe_target alias branch loop prior_error; do
  fixture="compiler/phase26_call_local_zero_${case_name}_source.gst"
  output="$build_root/local_${case_name}"
  rm -f "$output" "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" "$fixture" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  case "$case_name" in
    caller_first|callee_first|mayzero|alias)
      case "$case_name" in caller_first) line=3 ;; *) line=4 ;; esac
      rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function argument' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    prior_error)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got Str' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    *)
      rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
      rg -F 'reason_code=deferred_p13_parameter_argument_target_dependent_abi' "$output.stdout" >/dev/null
      if rg -F 'TypeError' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
  esac
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

for case_name in caller_first mayzero nonzero unknown unsafe_target overwrite intervening chain nested prior_error; do
  fixture="compiler/phase26_call_alias_zero_${case_name}_source.gst"
  output="$build_root/alias_${case_name}"
  rm -f "$output" "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" "$fixture" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  case "$case_name" in
    caller_first|mayzero|chain)
      case "$case_name" in caller_first) line=3 ;; *) line=4 ;; esac
      rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function argument' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    prior_error)
      rg -F "TypeError in $fixture at line 5:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got Str' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    *)
      rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
      rg -F 'reason_code=deferred_p13_parameter_argument_target_dependent_abi' "$output.stdout" >/dev/null
      if rg -F 'TypeError' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
  esac
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

for case_name in caller_first callee_first mayzero_caller_first mayzero_callee_first nonzero unknown unsafe_target overwrite intervening nested prior_error; do
  fixture="compiler/phase26_call_chain_zero_${case_name}_source.gst"
  output="$build_root/chain_${case_name}"
  rm -f "$output" "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" "$fixture" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  case "$case_name" in
    caller_first|callee_first|mayzero_caller_first|mayzero_callee_first)
      case "$case_name" in caller_first|mayzero_caller_first) line=3 ;; *) line=4 ;; esac
      rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function argument' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    prior_error)
      rg -F "TypeError in $fixture at line 5:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got Str' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    *)
      rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
      rg -F 'reason_code=deferred_p13_parameter_argument_target_dependent_abi' "$output.stdout" >/dev/null
      if rg -F 'TypeError' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
  esac
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

for case_name in caller_first callee_first mayzero_caller_first mayzero_callee_first nonzero unknown unsafe_target overwrite intervening nested chained_after_take prior_error direct_take_argument safe_return literal_take; do
  fixture="compiler/phase26_call_take_alias_zero_${case_name}_source.gst"
  output="$build_root/take_alias_${case_name}"
  rm -f "$output" "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" "$fixture" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  case "$case_name" in
    caller_first|callee_first|mayzero_caller_first|mayzero_callee_first|literal_take|direct_take_argument)
      case "$case_name" in caller_first|mayzero_caller_first|literal_take) line=3 ;; *) line=4 ;; esac
      rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function argument' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    prior_error)
      rg -F "TypeError in $fixture at line 5:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got Str' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    safe_return)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F 'Returning ephemeral view' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    *)
      rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
      rg -F 'reason_code=deferred_p13_parameter_argument_target_dependent_abi' "$output.stdout" >/dev/null
      if rg -F 'TypeError' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
  esac
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

for case_name in caller_first mayzero_caller_first mayzero_callee_first plain_chain literal_take nonzero unknown unsafe_target overwrite intervening nested nested_take second_take prior_error type_mismatch; do
  fixture="compiler/phase26_call_direct_take_zero_${case_name}_source.gst"
  output="$build_root/direct_take_${case_name}"
  rm -f "$output" "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" "$fixture" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  case "$case_name" in
    caller_first|mayzero_caller_first|mayzero_callee_first|plain_chain|literal_take)
      case "$case_name" in mayzero_callee_first) line=4 ;; *) line=3 ;; esac
      rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function argument' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    prior_error)
      rg -F "TypeError in $fixture at line 5:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got Str' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    type_mismatch)
      rg -F "TypeError in $fixture at line 4:" "$output.stdout" >/dev/null
      rg -F "Argument type mismatch for function 'accept_raw'. Expected Int but got RawPointer(Int)" "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    *)
      rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
      rg -F 'reason_code=deferred_p13_parameter_argument_target_dependent_abi' "$output.stdout" >/dev/null
      if rg -F 'TypeError' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
  esac
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

for case_name in caller_first mayzero_caller_first mayzero_callee_first plain_chain literal_move nonzero unknown unsafe_target overwrite intervening nested nested_move second_move prior_take_alias move_alias prior_error type_mismatch; do
  fixture="compiler/phase26_call_direct_move_zero_${case_name}_source.gst"
  output="$build_root/direct_move_${case_name}"
  rm -f "$output" "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" "$fixture" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  case "$case_name" in
    caller_first|mayzero_caller_first|mayzero_callee_first|plain_chain|literal_move)
      case "$case_name" in mayzero_callee_first) line=4 ;; *) line=3 ;; esac
      rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function argument' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    prior_error)
      rg -F "TypeError in $fixture at line 5:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got Str' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    type_mismatch)
      rg -F "TypeError in $fixture at line 4:" "$output.stdout" >/dev/null
      rg -F "Argument type mismatch for function 'accept_raw'. Expected Int but got RawPointer(Int)" "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    second_move|move_alias)
      rg -F "TypeError in $fixture at line 4:" "$output.stdout" >/dev/null
      rg -F "Variable 'alias' cannot be used because its backing origin 'ptr' has been moved or invalidated" "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    *)
      rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
      rg -F 'reason_code=deferred_p13_parameter_argument_target_dependent_abi' "$output.stdout" >/dev/null
      if rg -F 'TypeError' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
  esac
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

for case_name in argument_caller_first argument_callee_first argument_mayzero_caller_first argument_mayzero_callee_first return_caller_first return_callee_first return_mayzero_caller_first return_mayzero_callee_first nonzero unknown unsafe_target prior_error nested_move take type_mismatch; do
  fixture="compiler/phase26_call_move_wrapper_zero_${case_name}_source.gst"
  output="$build_root/move_call_${case_name}"
  rm -f "$output" "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" "$fixture" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  case "$case_name" in
    argument_caller_first|argument_mayzero_caller_first) line=3; boundary=argument ;;
    argument_callee_first|argument_mayzero_callee_first) line=4; boundary=argument ;;
    return_caller_first|return_mayzero_caller_first) line=2; boundary=return ;;
    return_callee_first|return_mayzero_callee_first) line=3; boundary=return ;;
    take|nested_move) line=4; boundary=argument ;;
    prior_error)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got Str' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    type_mismatch)
      rg -F "TypeError in $fixture at line 4:" "$output.stdout" >/dev/null
      rg -F "Argument type mismatch for function 'accept_raw'. Expected Int but got RawPointer(Int)" "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    *)
      rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
      rg -F 'reason_code=deferred_p13_parameter_argument_target_dependent_abi' "$output.stdout" >/dev/null
      if rg -F 'TypeError' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
  esac
  if [[ -n "${boundary:-}" ]]; then
    rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
    rg -F "[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function $boundary" "$output.stdout" >/dev/null
    if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
    boundary=
  fi
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

for case_name in argument_caller_first argument_callee_first argument_mayzero_caller_first argument_mayzero_callee_first return_caller_first return_callee_first return_mayzero_caller_first return_mayzero_callee_first nonzero unknown unsafe_target prior_error nested_take move_take type_mismatch; do
  fixture="compiler/phase26_call_take_wrapper_zero_${case_name}_source.gst"
  output="$build_root/take_call_${case_name}"
  rm -f "$output" "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" "$fixture" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  case "$case_name" in
    argument_caller_first|argument_mayzero_caller_first) line=3; boundary=argument ;;
    argument_callee_first|argument_mayzero_callee_first) line=4; boundary=argument ;;
    return_caller_first|return_mayzero_caller_first) line=2; boundary=return ;;
    return_callee_first|return_mayzero_callee_first) line=3; boundary=return ;;
    nested_take|move_take) line=4; boundary=argument ;;
    prior_error)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got Str' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    type_mismatch)
      rg -F "TypeError in $fixture at line 4:" "$output.stdout" >/dev/null
      rg -F "Argument type mismatch for function 'accept_raw'. Expected Int but got RawPointer(Int)" "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    *)
      rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
      rg -F 'reason_code=deferred_p13_parameter_argument_target_dependent_abi' "$output.stdout" >/dev/null
      if rg -F 'TypeError' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
  esac
  if [[ -n "${boundary:-}" ]]; then
    rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
    rg -F "[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function $boundary" "$output.stdout" >/dev/null
    if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
    boundary=
  fi
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

two_wrapper_cases=()
for pair in move_take take_move move_move take_take; do
  for boundary_kind in argument return; do
    for declaration_order in caller_first callee_first; do
      two_wrapper_cases+=("${pair}_${boundary_kind}_${declaration_order}")
    done
  done
done
two_wrapper_cases+=(mayzero nonzero unsafe_target prior_error type_mismatch depth3)
for case_name in "${two_wrapper_cases[@]}"; do
  fixture="compiler/phase26_call_two_wrapper_zero_${case_name}_source.gst"
  output="$build_root/two_wrapper_${case_name}"
  boundary=
  rm -f "$output" "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" "$fixture" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  case "$case_name" in
    *_argument_caller_first) line=3; boundary=argument ;;
    *_argument_callee_first) line=4; boundary=argument ;;
    *_return_caller_first) line=2; boundary=return ;;
    *_return_callee_first) line=3; boundary=return ;;
    mayzero) line=3; boundary=argument ;;
    depth3) line=3; boundary=argument ;;
    prior_error)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got Str' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    type_mismatch)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F "Argument type mismatch for function 'accept_int'. Expected Int but got RawPointer(Int)" "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    *)
      rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
      rg -F 'reason_code=deferred_p13_parameter_argument_target_dependent_abi' "$output.stdout" >/dev/null
      if rg -F 'TypeError' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
  esac
  if [[ -n "${boundary:-}" ]]; then
    rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
    rg -F "[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function $boundary" "$output.stdout" >/dev/null
    if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
    boundary=
  fi
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

wrapper_chain_cases=()
for outer in move take; do
  for middle in move take; do
    for inner in move take; do
      for boundary_kind in argument return; do
        for declaration_order in caller_first callee_first; do
          wrapper_chain_cases+=("${outer}_${middle}_${inner}_${boundary_kind}_${declaration_order}")
        done
      done
    done
  done
done
wrapper_chain_cases+=(depth4_zero mayzero_argument mayzero_return nonzero unknown unsafe_target prior_error type_mismatch)
for case_name in "${wrapper_chain_cases[@]}"; do
  fixture="compiler/phase26_call_wrapper_chain_zero_${case_name}_source.gst"
  output="$build_root/wrapper_chain_${case_name}"
  boundary=
  rm -f "$output" "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" "$fixture" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  case "$case_name" in
    *_argument_caller_first) line=3; boundary=argument ;;
    *_argument_callee_first) line=4; boundary=argument ;;
    *_return_caller_first) line=2; boundary=return ;;
    *_return_callee_first) line=3; boundary=return ;;
    depth4_zero|mayzero_argument) line=3; boundary=argument ;;
    mayzero_return) line=2; boundary=return ;;
    prior_error)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got Str' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    type_mismatch)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F "Argument type mismatch for function 'accept_int'. Expected Int but got RawPointer(Int)" "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    *)
      rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
      rg -F 'reason_code=deferred_p13_parameter_argument_target_dependent_abi' "$output.stdout" >/dev/null
      if rg -F 'TypeError' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
  esac
  if [[ -n "$boundary" ]]; then
    rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
    rg -F "[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function $boundary" "$output.stdout" >/dev/null
    if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
  fi
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

for case_name in argument_caller_first argument_callee_first other_pointer return_caller_first return_callee_first mayzero_argument mayzero_return \
                 nonzero unknown unsafe_target type_mismatch nested move_cast cast_move take_cast cast_take \
                 chain_argument_caller_first chain_argument_callee_first chain_return_caller_first chain_return_callee_first chain_mayzero_argument chain_depth3_argument chain_depth3_mayzero_return \
                 chain_nonzero chain_unknown chain_unsafe_target chain_type_mismatch chain_scalar_inner chain_move_cast chain_cast_move chain_take_cast chain_cast_take; do
  fixture="compiler/phase26_call_cast_zero_${case_name}_source.gst"; if [[ "$case_name" == chain_* ]]; then fixture="compiler/phase26_call_cast_chain_zero_${case_name#chain_}_source.gst"; fi
  output="$build_root/cast_${case_name}"
  boundary=
  rm -f "$output" "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" "$fixture" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  case "$case_name" in
    argument_caller_first|chain_argument_caller_first) line=1; boundary=argument ;;
    argument_callee_first|other_pointer|mayzero_argument|nested|chain_argument_callee_first|chain_mayzero_argument|chain_depth3_argument) line=3; boundary=argument ;;
    return_caller_first|chain_return_caller_first) line=1; boundary=return ;;
    return_callee_first|mayzero_return|chain_return_callee_first|chain_depth3_mayzero_return) line=2; boundary=return ;;
    move_cast|cast_move|take_cast|cast_take|chain_move_cast|chain_cast_move|chain_take_cast|chain_cast_take) line=3; boundary=argument ;;
    type_mismatch|chain_type_mismatch)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F "Argument type mismatch for function 'accept_int'. Expected Int but got RawPointer(Int)" "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    *)
      rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
      rg -F 'reason_code=deferred_p13_parameter_argument_target_dependent_abi' "$output.stdout" >/dev/null
      if rg -F 'TypeError' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
  esac
  if [[ -n "$boundary" ]]; then
    rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
    rg -F "[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function $boundary" "$output.stdout" >/dev/null
    if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
  fi
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

for shape in move_cast cast_move take_cast cast_take; do
  for state in zero mayzero; do
    for boundary_kind in argument return; do
      for order in caller_first callee_first; do
        case_name="${shape}_${state}_${boundary_kind}_${order}"
        fixture="compiler/phase26_call_mixed_cast_zero_${case_name}_source.gst"
        output="$build_root/mixed_${case_name}"
        rm -f "$output" "$marker"
        set +e
        GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
        GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER="$PWD/$marker" \
        GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
          ./gust --backend cranelift -o "$output" "$fixture" \
            >"$output.stdout" 2>"$output.stderr"
        status=$?
        set -e
        test "$status" -ne 0
        line=3
        if [[ "$order" == caller_first ]]; then line=1; fi
        rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
        rg -F "[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function $boundary_kind" "$output.stdout" >/dev/null
        if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
        test ! -s "$output.stderr"
        test ! -e "$output"
        test ! -e "$marker"
      done
    done
  done
done

for case_name in nonzero unknown unsafe_target type_mismatch scalar_cast indirect; do
  fixture="compiler/phase26_call_mixed_cast_zero_${case_name}_source.gst"
  output="$build_root/mixed_${case_name}"
  rm -f "$output" "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" "$fixture" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  if [[ "$case_name" == type_mismatch ]]; then
    rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
    rg -F "Argument type mismatch for function 'accept_int'. Expected Int but got RawPointer(Int)" "$output.stdout" >/dev/null
    if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
    if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
  elif [[ "$case_name" == indirect ]]; then
    rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
    rg -F "Semantic Error: Undefined function 'f'" "$output.stdout" >/dev/null
    if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
    if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
  else
    rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
    rg -F 'reason_code=deferred_p13_parameter_argument_target_dependent_abi' "$output.stdout" >/dev/null
    if rg -F 'TypeError' "$output.stdout" >/dev/null; then exit 1; fi
  fi
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

for case_name in two_casts two_wrappers; do
  fixture="compiler/phase26_call_mixed_cast_zero_${case_name}_source.gst"
  output="$build_root/mixed_$case_name"
  rm -f "$output" "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" "$fixture" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
  rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function argument' "$output.stdout" >/dev/null
  if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

for state in zero mayzero; do
  for boundary_kind in argument return; do
    for order in caller_first callee_first; do
      case_name="${state}_${boundary_kind}_${order}"
      fixture="compiler/phase26_call_mixed_chain_${case_name}_source.gst"
      output="$build_root/mixed_chain_$case_name"
      rm -f "$output" "$marker"
      set +e
      GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
      GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER="$PWD/$marker" \
      GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
        ./gust --backend cranelift -o "$output" "$fixture" \
          >"$output.stdout" 2>"$output.stderr"
      status=$?
      set -e
      test "$status" -ne 0
      line=1
      if [[ "$order" == callee_first && "$boundary_kind" == argument ]]; then line=3; fi
      if [[ "$order" == callee_first && "$boundary_kind" == return ]]; then line=2; fi
      rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
      rg -F "[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function $boundary_kind" "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      test ! -s "$output.stderr"
      test ! -e "$output"
      test ! -e "$marker"
    done
  done
done

for case_name in nonzero unknown unsafe_target type_mismatch scalar_cast; do
  fixture="compiler/phase26_call_mixed_chain_${case_name}_source.gst"
  output="$build_root/mixed_chain_$case_name"
  rm -f "$output" "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" "$fixture" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  if [[ "$case_name" == type_mismatch ]]; then
    rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
    rg -F "Argument type mismatch for function 'accept_int'. Expected Int but got RawPointer(Int)" "$output.stdout" >/dev/null
    if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
    if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
  else
    rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
    rg -F 'reason_code=deferred_p13_parameter_argument_target_dependent_abi' "$output.stdout" >/dev/null
    if rg -F 'TypeError' "$output.stdout" >/dev/null; then exit 1; fi
  fi
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

for case_name in cast_zero_caller_first cast_zero_callee_first cast_mayzero cast_nonzero cast_unknown cast_zero_unsafe_target cast_zero_intervening cast_zero_alias cast_zero_nested cast_zero_move cast_zero_scalar_mismatch cast_chain_zero_callee_first cast_chain_mayzero cast_chain_zero_depth3 cast_chain_nonzero cast_chain_unknown cast_chain_zero_unsafe_target cast_chain_zero_alias; do
  fixture="compiler/phase26_call_local_${case_name}_source.gst"
  output="$build_root/local_$case_name"
  rm -f "$output" "$marker"
  set +e
  GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
  GUST_PHASE26_CALL_RETURN_ZERO_POISON_MARKER="$PWD/$marker" \
  GUST_NATIVE_BACKEND_DRIVER="$PWD/$poison" \
    ./gust --backend cranelift -o "$output" "$fixture" \
      >"$output.stdout" 2>"$output.stderr"
  status=$?
  set -e
  test "$status" -ne 0
  case "$case_name" in
    cast_zero_caller_first|cast_zero_callee_first|cast_mayzero|cast_zero_nested|cast_chain_zero_callee_first|cast_chain_mayzero|cast_chain_zero_depth3)
      if [[ "$case_name" == cast_zero_caller_first || "$case_name" == cast_zero_nested || "$case_name" == cast_chain_zero_depth3 ]]; then line=3; else line=4; fi
      rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function argument' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    cast_zero_move)
      rg -F 'Use of moved variable ptr' "$output.stdout" >/dev/null
      rg -F "Variable 'ptr' has already been moved" "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    cast_zero_scalar_mismatch)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F "Argument type mismatch for function 'accept_raw'. Expected RawPointer(Int) but got Int" "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    *)
      rg -F 'decision=deferred capability=phase13_generic_source_to_mir' "$output.stdout" >/dev/null
      rg -F 'reason_code=deferred_p13_parameter_argument_target_dependent_abi' "$output.stdout" >/dev/null
      if rg -F 'TypeError' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
  esac
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

bash scripts/phase26_empty_raw_zero_evidence.sh
echo 'Phase26.1E direct-call return, aliases, checked wrappers, mixed chains, and checked casted local argument chains zero evidence and no-fallback passed.'
