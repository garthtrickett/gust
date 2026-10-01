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
printf 'SUCCESS: checked direct-return zero summaries and excluded parameters and wrapped callees verified\n' >"$build_root/typechecker.expected"
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

bash scripts/phase26_empty_raw_zero_evidence.sh
echo 'Phase26.1E direct-call return, aliases, and terminal Take/Move argument zero evidence and no-fallback passed.'
