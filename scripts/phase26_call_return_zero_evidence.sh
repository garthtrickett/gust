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
printf 'SUCCESS: checked direct-return zero summaries, RawPointer AsCast chains, mixed Move/Take cast chains, consecutive outer Take chains, interleaved Take/cast chains, local safe returns and plain-alias safe returns and Take-alias safe returns, and exclusions verified\n' >"$build_root/typechecker.expected"
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

for case_name in caller_first callee_first mayzero_caller_first mayzero_callee_first nonzero unknown unsafe_target overwrite intervening nested chained_after_take after_take_mayzero after_take_two_suffixes after_take_nonzero after_take_unknown after_take_unsafe after_take_second_take repeated_take_zero_callee_first repeated_take_mayzero repeated_take_cast_zero repeated_take_cast_mayzero repeated_take_interleaved_zero repeated_take_nonzero repeated_take_unknown repeated_take_unsafe_target repeated_take_wrong_type repeated_take_gap terminal_zero_second_take_call terminal_mayzero_second_take_call terminal_zero_caller_first_take_call terminal_mayzero_caller_first_take_call terminal_zero_plain_take_call terminal_nonzero_second_take_call terminal_unknown_second_take_call terminal_unsafe_second_take_call terminal_gap_second_take_call terminal_move_second_take_call terminal_nested_take_call terminal_zero_second_take_cast_call terminal_cast_zero_callee_first_depth1 terminal_cast_zero_callee_first_depth2 terminal_cast_zero_callee_first_depth3 terminal_cast_zero_caller_first_depth1 terminal_cast_zero_caller_first_depth2 terminal_cast_zero_caller_first_depth3 terminal_cast_mayzero_callee_first_depth1 terminal_cast_mayzero_callee_first_depth2 terminal_cast_mayzero_callee_first_depth3 terminal_cast_mayzero_caller_first_depth1 terminal_cast_mayzero_caller_first_depth2 terminal_cast_mayzero_caller_first_depth3 terminal_cast_control_nonzero terminal_cast_control_unknown terminal_cast_control_unsafe terminal_cast_control_gap terminal_cast_control_wrong_type terminal_cast_control_scalar_inner terminal_cast_control_nested_take terminal_cast_control_move terminal_cast_control_take_inner_cast inner_cast_zero_callee_first_depth1 inner_cast_zero_callee_first_depth2 inner_cast_zero_callee_first_depth3 inner_cast_zero_caller_first_depth1 inner_cast_zero_caller_first_depth2 inner_cast_zero_caller_first_depth3 inner_cast_mayzero_callee_first_depth1 inner_cast_mayzero_callee_first_depth2 inner_cast_mayzero_callee_first_depth3 inner_cast_mayzero_caller_first_depth1 inner_cast_mayzero_caller_first_depth2 inner_cast_mayzero_caller_first_depth3 inner_cast_control_nonzero inner_cast_control_unknown inner_cast_control_unsafe inner_cast_control_gap inner_cast_control_nested_take inner_cast_control_move_outer inner_cast_control_scalar_inner inner_cast_control_wrong_type terminal_wrong_type_second_take_call prior_error direct_take_argument safe_return literal_take outer_take_chain_{zero,mayzero}_{callee_first,caller_first}_depth{2,3}_{plain,cast} outer_take_chain_control_{nonzero,unknown,unsafe,wrong_type,move_outer,interleaved} interleaved_{zero,mayzero}_{callee_first,caller_first}_depth{2,3} interleaved_zero_callee_first_cast_outer interleaved_control_{nonzero,unknown,unsafe,wrong_type,move_outer,gap,scalar_inner}; do
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
    caller_first|callee_first|mayzero_caller_first|mayzero_callee_first|chained_after_take|after_take_mayzero|after_take_two_suffixes|after_take_second_take|repeated_take_zero_callee_first|repeated_take_mayzero|repeated_take_cast_zero|repeated_take_cast_mayzero|repeated_take_interleaved_zero|terminal_zero_second_take_call|terminal_mayzero_second_take_call|terminal_zero_caller_first_take_call|terminal_mayzero_caller_first_take_call|terminal_zero_plain_take_call|terminal_nested_take_call|terminal_zero_second_take_cast_call|terminal_cast_zero_*|terminal_cast_mayzero_*|terminal_cast_control_take_inner_cast|inner_cast_zero_*|inner_cast_mayzero_*|inner_cast_control_nested_take|outer_take_chain_zero_*|outer_take_chain_mayzero_*|outer_take_chain_control_interleaved|interleaved_zero_*|interleaved_mayzero_*|literal_take|direct_take_argument)
      case "$case_name" in terminal_zero_caller_first_take_call|terminal_mayzero_caller_first_take_call|terminal_cast_*_caller_first_*|inner_cast_*_caller_first_*|outer_take_chain_*_caller_first_*|interleaved_*_caller_first_*) line=2 ;; caller_first|mayzero_caller_first|literal_take) line=3 ;; *) line=4 ;; esac
      rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function argument' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    prior_error|repeated_take_wrong_type|terminal_wrong_type_second_take_call|terminal_cast_control_wrong_type|terminal_cast_control_move|inner_cast_control_wrong_type|outer_take_chain_control_wrong_type|interleaved_control_wrong_type|interleaved_control_scalar_inner)
      if [[ "$case_name" == prior_error ]]; then line=5; message='[TypeMismatch] Return type mismatch. Expected Int but got Str'; elif [[ "$case_name" == interleaved_control_scalar_inner ]]; then line=4; message="The 'take' operator is strictly banned on primitive POD types (like Int)"; elif [[ "$case_name" == terminal_wrong_type_second_take_call || "$case_name" == terminal_cast_control_wrong_type || "$case_name" == inner_cast_control_wrong_type || "$case_name" == outer_take_chain_control_wrong_type || "$case_name" == interleaved_control_wrong_type ]]; then line=4; message="Argument type mismatch for function 'accept_int'. Expected Int but got RawPointer(Int)"; elif [[ "$case_name" == terminal_cast_control_move ]]; then line=4; message="Use of moved variable second"; else line=4; message="Argument type mismatch for function 'accept_raw'. Expected RawPointer(Int) but got Int"; fi
      rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
      rg -F "$message" "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null || rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
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
    caller_first|mayzero_caller_first|mayzero_callee_first|plain_chain|literal_take|second_take)
      case "$case_name" in mayzero_callee_first|second_take) line=4 ;; *) line=3 ;; esac
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

for case_name in cast_zero_caller_first cast_zero_callee_first cast_mayzero cast_nonzero cast_unknown cast_zero_unsafe_target cast_zero_intervening cast_zero_alias cast_zero_nested cast_zero_move cast_zero_scalar_mismatch cast_chain_zero_callee_first cast_chain_mayzero cast_chain_zero_depth3 cast_chain_nonzero cast_chain_unknown cast_chain_zero_unsafe_target cast_chain_zero_alias cast_take_zero_caller_first cast_take_zero_callee_first take_cast_zero_caller_first take_cast_zero_callee_first cast_take_mayzero take_cast_mayzero cast_take_nonzero take_cast_nonzero take_cast_unknown take_cast_unsafe_target take_cast_alias take_cast_intervening take_cast_nested cast_take_nested take_cast_second_take take_cast_move take_cast_type_mismatch cast_take_chain_zero_callee_first take_cast_chain_zero_callee_first cast_take_chain_mayzero take_cast_chain_mayzero cast_take_chain_depth3 take_cast_chain_depth3 cast_take_chain_nonzero take_cast_chain_unknown take_cast_chain_unsafe_target cast_take_chain_type_mismatch take_cast_chain_second_take take_cast_chain_scalar_inner cast_take_chain_alias take_cast_chain_intervening move_cast_chain_zero_caller_first move_cast_chain_zero_callee_first move_cast_chain_mayzero move_cast_chain_nonzero move_cast_chain_unknown move_cast_chain_unsafe_target move_cast_chain_type_mismatch move_cast_chain_second_move move_cast_chain_take_combo move_cast_chain_alias move_cast_chain_intervening move_cast_chain_scalar_inner alias_cast_zero_callee_first alias_cast_mayzero alias_cast_nonzero alias_cast_unknown alias_cast_unsafe_target alias_cast_overwrite alias_cast_intervening alias_cast_second_alias alias_cast_type_mismatch alias_cast_chain_zero_callee_first alias_cast_chain_mayzero alias_cast_chain_nonzero alias_cast_chain_unknown alias_cast_chain_unsafe_target alias_cast_chain_second_alias alias_cast_chain_second_alias_caller_first alias_cast_chain_second_alias_mayzero alias_cast_chain_third_alias_zero alias_cast_chain_second_alias_nonzero alias_cast_chain_second_alias_unknown alias_cast_chain_second_alias_unsafe_target alias_cast_chain_scalar_inner alias_cast_chain_type_mismatch take_alias_cast_zero_caller_first take_alias_cast_zero_callee_first take_alias_cast_mayzero take_alias_cast_nonzero take_alias_cast_unknown take_alias_cast_unsafe_target take_alias_cast_wrong_type take_alias_cast_intervening take_alias_cast_second_alias take_alias_cast_plain_prefix take_alias_cast_after_take_mayzero take_alias_cast_after_take_two_suffixes take_alias_cast_after_take_wrong_type take_alias_cast_plain_prefix_callee_first take_alias_cast_plain_prefix_mayzero take_alias_cast_plain_prefix_direct take_alias_cast_plain_prefix_two_plains take_alias_cast_two_plains_mayzero take_alias_cast_three_plains_zero take_alias_cast_two_plains_callee_first take_alias_cast_two_plains_nonzero take_alias_cast_two_plains_unknown take_alias_cast_plain_prefix_nonzero take_alias_cast_plain_prefix_unknown take_alias_cast_plain_prefix_unsafe_target take_alias_cast_plain_prefix_wrong_type take_alias_cast_plain_prefix_intervening local_return_zero local_return_mayzero local_return_nonzero local_return_unknown local_return_unsafe local_return_gap local_return_alias local_return_cast local_return_wrong_type plain_alias_return_zero_two plain_alias_return_mayzero_two plain_alias_return_nonzero plain_alias_return_unknown plain_alias_return_unsafe plain_alias_return_gap plain_alias_return_overwrite plain_alias_return_take plain_alias_return_cast plain_alias_return_wrong_type plain_alias_return_prior_escape plain_alias_return_cast_chain_mayzero_two plain_alias_return_cast_chain_zero_two plain_alias_return_cast_chain_nonzero plain_alias_return_cast_chain_unknown plain_alias_return_cast_chain_unsafe plain_alias_return_cast_chain_gap plain_alias_return_cast_chain_overwrite plain_alias_return_cast_chain_take plain_alias_return_cast_chain_wrong_type plain_alias_return_cast_chain_scalar_inner plain_alias_return_cast_chain_prior_escape; do
  fixture="compiler/phase26_call_local_${case_name}_source.gst"; if [[ "$case_name" == take_alias_cast_* || "$case_name" == local_return_* ]]; then fixture="compiler/phase26_call_${case_name}_source.gst"; fi; if [[ "$case_name" == plain_alias_return_* ]]; then fixture="compiler/phase26_call_local_return_plain_alias_${case_name#plain_alias_return_}_source.gst"; fi
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
    local_return_zero|local_return_mayzero|local_return_alias)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function return' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    local_return_wrong_type)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got RawPointer(Int)' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    plain_alias_return_zero_two|plain_alias_return_mayzero_two|plain_alias_return_cast|plain_alias_return_cast_chain_mayzero_two|plain_alias_return_cast_chain_zero_two|plain_alias_return_take|plain_alias_return_cast_chain_take)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function return' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    plain_alias_return_wrong_type)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got RawPointer(Int)' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    plain_alias_return_cast_chain_wrong_type)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got RawPointer(Byte)' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    plain_alias_return_prior_escape|plain_alias_return_cast_chain_prior_escape)
      rg -F "TypeError in $fixture at line 2:" "$output.stdout" >/dev/null
      rg -F "Escape analysis violation. Returning ephemeral view of type RawPointer(Int) whose origin traces back to local stack variable 'ptr'" "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    cast_zero_caller_first|cast_zero_callee_first|cast_mayzero|cast_zero_alias|cast_zero_nested|cast_chain_zero_callee_first|cast_chain_mayzero|cast_chain_zero_depth3|cast_chain_zero_alias|alias_cast_zero_callee_first|alias_cast_mayzero|alias_cast_second_alias|alias_cast_chain_zero_callee_first|alias_cast_chain_mayzero|alias_cast_chain_second_alias|alias_cast_chain_second_alias_caller_first|alias_cast_chain_second_alias_mayzero|alias_cast_chain_third_alias_zero|take_alias_cast_zero_caller_first|take_alias_cast_zero_callee_first|take_alias_cast_mayzero|take_alias_cast_second_alias|take_alias_cast_after_take_mayzero|take_alias_cast_after_take_two_suffixes|take_alias_cast_plain_prefix|take_alias_cast_plain_prefix_callee_first|take_alias_cast_plain_prefix_mayzero|take_alias_cast_plain_prefix_direct|take_alias_cast_plain_prefix_two_plains|take_alias_cast_two_plains_mayzero|take_alias_cast_three_plains_zero|take_alias_cast_two_plains_callee_first)
      if [[ "$case_name" == alias_cast_chain_second_alias_caller_first ]]; then line=2
      elif [[ "$case_name" == cast_zero_caller_first || "$case_name" == cast_zero_alias || "$case_name" == cast_zero_nested || "$case_name" == cast_chain_zero_depth3 || "$case_name" == cast_chain_zero_alias || "$case_name" == take_alias_cast_zero_caller_first || "$case_name" == take_alias_cast_mayzero || "$case_name" == take_alias_cast_second_alias || "$case_name" == take_alias_cast_plain_prefix || "$case_name" == take_alias_cast_plain_prefix_mayzero || "$case_name" == take_alias_cast_plain_prefix_direct || "$case_name" == take_alias_cast_plain_prefix_two_plains || "$case_name" == take_alias_cast_two_plains_mayzero || "$case_name" == take_alias_cast_three_plains_zero ]]; then line=3
      else line=4; fi
      rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function argument' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    cast_take_zero_caller_first|cast_take_zero_callee_first|take_cast_zero_caller_first|take_cast_zero_callee_first|cast_take_mayzero|take_cast_mayzero|cast_take_nested|take_cast_nested|cast_take_chain_zero_callee_first|take_cast_chain_zero_callee_first|cast_take_chain_mayzero|take_cast_chain_mayzero|cast_take_chain_depth3|take_cast_chain_depth3|take_cast_move|move_cast_chain_zero_caller_first|move_cast_chain_zero_callee_first|move_cast_chain_mayzero)
      line=4
      if [[ "$case_name" == *_callee_first ]]; then line=3; fi
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
    cast_zero_scalar_mismatch|alias_cast_type_mismatch|alias_cast_chain_type_mismatch|take_alias_cast_wrong_type|take_alias_cast_after_take_wrong_type|take_alias_cast_plain_prefix_wrong_type)
      if [[ "$case_name" == alias_cast_type_mismatch || "$case_name" == alias_cast_chain_type_mismatch || "$case_name" == take_alias_cast_after_take_wrong_type ]]; then line=4; else line=3; fi
      rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
      rg -F "Argument type mismatch for function 'accept_raw'. Expected RawPointer(Int) but got Int" "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    take_cast_type_mismatch|cast_take_chain_type_mismatch|move_cast_chain_type_mismatch)
      rg -F "TypeError in $fixture at line 4:" "$output.stdout" >/dev/null
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
  test ! -s "$output.stderr"
  test ! -e "$output"
  test ! -e "$marker"
done

for case_name in mayzero_direct mayzero_cast_depth2 mayzero_plain_prefix mayzero_repeated_take mayzero_plain_suffix_cast zero_direct nonzero unknown unsafe gap overwrite wrong_type prior_escape return_take move_alias scalar_inner wrapper_mayzero_direct_take wrapper_mayzero_direct_take_callee_first wrapper_mayzero_plain_alias_take wrapper_mayzero_take_alias_take wrapper_mayzero_take_cast_depth2 wrapper_mayzero_cast_take_depth2 wrapper_mayzero_interleaved_depth2 wrapper_nonzero_take wrapper_unknown_take wrapper_unsafe_take wrapper_gap_take wrapper_overwrite_take wrapper_nested_take wrapper_move_take wrapper_wrong_type_take wrapper_zero_direct_take wrapper_scalar_inner_take outer_move_alias_cast_mayzero outer_move_cast_outside_take_mayzero outer_move_zero outer_move_nonzero outer_move_unknown outer_move_unsafe outer_move_double_move outer_move_wrong_type two_take_zero two_take_outer_cast_mayzero two_take_inner_cast_mayzero two_take_interleaved_cast_mayzero two_take_nonzero two_take_unknown two_take_unsafe two_take_gap two_take_overwrite two_take_wrong_type two_take_callee_first two_take_third_take two_take_move outer_move_two_take_zero outer_move_two_take_outer_cast_mayzero outer_move_two_take_inner_cast_mayzero outer_move_two_take_interleaved_cast_mayzero outer_move_two_take_nonzero outer_move_two_take_unknown outer_move_two_take_unsafe outer_move_two_take_gap outer_move_two_take_overwrite outer_move_two_take_wrong_type outer_move_two_take_callee_first outer_move_two_take_third_take outer_move_two_take_inner_move outer_move_two_take_second_move outer_move_two_take_cast_outside_move outer_move_two_take_cast_outside_inner_move inner_move_two_take_zero inner_move_two_take_mayzero inner_move_two_take_outer_cast_mayzero inner_move_two_take_between_outer_take_move_mayzero inner_move_two_take_between_move_inner_take_mayzero inner_move_two_take_inner_cast_mayzero inner_move_two_take_interleaved_cast_mayzero inner_move_two_take_nonzero inner_move_two_take_unknown inner_move_two_take_unsafe inner_move_two_take_gap inner_move_two_take_overwrite inner_move_two_take_wrong_type inner_move_two_take_callee_first inner_move_two_take_third_take inner_move_two_take_outer_and_inner_move inner_move_two_take_move_under_both_takes inner_move_two_take_lone_take_inner_move inner_move_two_take_move_without_take inner_move_two_take_scalar_cast inner_move_two_take_both_zero inner_move_two_take_both_outer_cast_mayzero inner_move_two_take_both_between_takes_cast_mayzero inner_move_two_take_both_before_move_cast_mayzero inner_move_two_take_both_inside_move_cast_mayzero inner_move_two_take_both_interleaved_cast_mayzero inner_move_two_take_both_nonzero inner_move_two_take_both_unknown inner_move_two_take_both_unsafe inner_move_two_take_both_gap inner_move_two_take_both_overwrite inner_move_two_take_both_wrong_type inner_move_two_take_both_callee_first inner_move_two_take_both_third_take inner_move_two_take_both_outer_and_inner_move inner_move_two_take_both_double_inner_move inner_move_two_take_both_lone_take_move inner_move_two_take_both_move_without_take inner_move_two_take_both_scalar_cast inner_move_two_take_both_bare_move_outer_cast_priority; do
  fixture="compiler/phase26_call_local_return_take_alias_${case_name}_source.gst"; if [[ "$case_name" == wrapper_* ]]; then fixture="compiler/phase26_call_local_return_take_${case_name}_source.gst"; fi
  if [[ "$case_name" == outer_move_* ]]; then fixture="compiler/phase26_call_local_return_outer_move_take_${case_name#outer_move_}_source.gst"; fi
  if [[ "$case_name" == two_take_* ]]; then fixture="compiler/phase26_call_local_return_two_take_${case_name#two_take_}_source.gst"; fi
  if [[ "$case_name" == outer_move_two_take_* ]]; then fixture="compiler/phase26_call_local_return_outer_move_two_take_${case_name#outer_move_two_take_}_source.gst"; fi
  if [[ "$case_name" == inner_move_two_take_* ]]; then fixture="compiler/phase26_call_local_return_inner_move_two_take_${case_name#inner_move_two_take_}_source.gst"; fi
  output="$build_root/take_return_${case_name}"
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
    mayzero_direct|mayzero_cast_depth2|mayzero_plain_prefix|mayzero_repeated_take|mayzero_plain_suffix_cast|zero_direct|return_take|wrapper_mayzero_direct_take|wrapper_mayzero_plain_alias_take|wrapper_mayzero_take_alias_take|wrapper_mayzero_take_cast_depth2|wrapper_mayzero_cast_take_depth2|wrapper_mayzero_interleaved_depth2|wrapper_zero_direct_take|wrapper_move_take|outer_move_alias_cast_mayzero|outer_move_cast_outside_take_mayzero|outer_move_zero|wrapper_nested_take|two_take_zero|two_take_third_take|two_take_outer_cast_mayzero|two_take_inner_cast_mayzero|two_take_interleaved_cast_mayzero|two_take_move|outer_move_two_take_zero|outer_move_two_take_third_take|outer_move_two_take_outer_cast_mayzero|outer_move_two_take_inner_cast_mayzero|outer_move_two_take_interleaved_cast_mayzero|outer_move_two_take_cast_outside_move|inner_move_two_take_zero|inner_move_two_take_mayzero|inner_move_two_take_outer_cast_mayzero|inner_move_two_take_between_outer_take_move_mayzero|inner_move_two_take_between_move_inner_take_mayzero|inner_move_two_take_inner_cast_mayzero|inner_move_two_take_interleaved_cast_mayzero|inner_move_two_take_third_take|inner_move_two_take_move_under_both_takes|inner_move_two_take_both_zero|inner_move_two_take_both_outer_cast_mayzero|inner_move_two_take_both_between_takes_cast_mayzero|inner_move_two_take_both_before_move_cast_mayzero|inner_move_two_take_both_inside_move_cast_mayzero|inner_move_two_take_both_interleaved_cast_mayzero|inner_move_two_take_both_third_take)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function return' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    inner_move_two_take_both_bare_move_outer_cast_priority)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F 'Semantic Error: Use of moved variable alias' "$output.stdout" >/dev/null
      rg -F "Variable 'alias' has already been moved" "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    wrong_type|wrapper_wrong_type_take|outer_move_wrong_type|two_take_wrong_type|outer_move_two_take_wrong_type|inner_move_two_take_wrong_type|inner_move_two_take_both_wrong_type)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      if [[ "$case_name" == wrapper_wrong_type_take || "$case_name" == outer_move_wrong_type || "$case_name" == two_take_wrong_type || "$case_name" == outer_move_two_take_wrong_type || "$case_name" == inner_move_two_take_wrong_type || "$case_name" == inner_move_two_take_both_wrong_type ]]; then
        rg -F '[TypeMismatch] Return type mismatch. Expected Int but got RawPointer(Int)' "$output.stdout" >/dev/null
      else
        rg -F '[TypeMismatch] Return type mismatch. Expected Int but got RawPointer(Byte)' "$output.stdout" >/dev/null
      fi
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    prior_escape|wrapper_mayzero_direct_take_callee_first|two_take_callee_first|outer_move_two_take_callee_first|inner_move_two_take_callee_first|inner_move_two_take_both_callee_first)
      line=2
      if [[ "$case_name" == prior_escape ]]; then line=2; fi
      rg -F "TypeError in $fixture at line $line:" "$output.stdout" >/dev/null
      rg -F 'Escape analysis violation. Returning ephemeral view' "$output.stdout" >/dev/null
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

for case_name in zero mayzero_three mayzero_four outer_cast_mayzero inner_cast_mayzero interleaved_cast_mayzero nonzero unknown unsafe gap overwrite wrong_type callee_first scalar_cast; do
  fixture="compiler/phase26_call_local_return_finite_take_${case_name}_source.gst"
  output="$build_root/finite_take_return_${case_name}"
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
    zero|mayzero_three|mayzero_four|outer_cast_mayzero|inner_cast_mayzero|interleaved_cast_mayzero)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function return' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    wrong_type)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got RawPointer(Int)' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    callee_first)
      rg -F "TypeError in $fixture at line 2:" "$output.stdout" >/dev/null
      rg -F 'Escape analysis violation. Returning ephemeral view' "$output.stdout" >/dev/null
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

for case_name in zero mayzero_three mayzero_four outer_cast_mayzero inner_cast_mayzero interleaved_cast_mayzero nonzero unknown unsafe gap overwrite wrong_type callee_first scalar_cast second_move inner_move cast_outside_move cast_without_alias prior_move; do
  fixture="compiler/phase26_call_local_return_outer_move_finite_take_${case_name}_source.gst"
  output="$build_root/outer_move_finite_take_return_${case_name}"
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
    zero|mayzero_three|mayzero_four|outer_cast_mayzero|inner_cast_mayzero|interleaved_cast_mayzero|inner_move|cast_outside_move)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function return' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    wrong_type)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got RawPointer(Int)' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    callee_first)
      rg -F "TypeError in $fixture at line 2:" "$output.stdout" >/dev/null
      rg -F 'Escape analysis violation. Returning ephemeral view' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    prior_move)
      rg -F 'Semantic Error: Use of moved variable ptr' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
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

for case_name in zero outer_cast_mayzero between_outer_middle_cast_mayzero between_middle_inner_cast_mayzero before_move_cast_mayzero inside_move_cast_mayzero interleaved_cast_mayzero nonzero unknown unsafe gap overwrite wrong_type callee_first fourth_take move_between outer_and_inner_move double_inner_move scalar_cast cast_without_alias prior_move later_take; do
  fixture="compiler/phase26_call_local_return_innermost_move_three_take_${case_name}_source.gst"
  output="$build_root/innermost_move_three_take_return_${case_name}"
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
    zero|outer_cast_mayzero|between_outer_middle_cast_mayzero|between_middle_inner_cast_mayzero|before_move_cast_mayzero|inside_move_cast_mayzero|interleaved_cast_mayzero|fourth_take|move_between|later_take)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function return' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    wrong_type)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got RawPointer(Int)' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    callee_first)
      rg -F "TypeError in $fixture at line 2:" "$output.stdout" >/dev/null
      rg -F 'Escape analysis violation. Returning ephemeral view' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    prior_move)
      rg -F 'Semantic Error: Use of moved variable ptr' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
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

for case_name in zero fifth_take outer_cast_mayzero between_outer_middle_cast_mayzero between_middle_inner_cast_mayzero before_move_cast_mayzero inside_move_cast_mayzero interleaved_cast_mayzero nonzero unknown unsafe gap overwrite wrong_type callee_first later_take move_between outer_and_inner_move double_inner_move scalar_cast cast_without_alias prior_move; do
  fixture="compiler/phase26_call_local_return_innermost_move_finite_take_${case_name}_source.gst"
  output="$build_root/innermost_move_finite_take_return_${case_name}"
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
    zero|fifth_take|outer_cast_mayzero|between_outer_middle_cast_mayzero|between_middle_inner_cast_mayzero|before_move_cast_mayzero|inside_move_cast_mayzero|interleaved_cast_mayzero|move_between|later_take)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function return' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    wrong_type)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got RawPointer(Int)' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    callee_first)
      rg -F "TypeError in $fixture at line 2:" "$output.stdout" >/dev/null
      rg -F 'Escape analysis violation. Returning ephemeral view' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    prior_move)
      rg -F 'Semantic Error: Use of moved variable ptr' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
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

for case_name in zero mayzero_three mayzero_four outer_cast_mayzero after_outer_take_cast_mayzero after_move_cast_mayzero between_inner_takes_cast_mayzero innermost_cast_mayzero interleaved_cast_mayzero nonzero unknown unsafe gap overwrite wrong_type callee_first other_position_three other_position_four second_move later_move outer_and_inner_move scalar_cast cast_without_alias prior_move; do
  fixture="compiler/phase26_call_local_return_between_move_finite_inner_take_${case_name}_source.gst"
  output="$build_root/between_move_finite_inner_take_return_${case_name}"
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
    zero|mayzero_three|mayzero_four|outer_cast_mayzero|after_outer_take_cast_mayzero|after_move_cast_mayzero|between_inner_takes_cast_mayzero|innermost_cast_mayzero|interleaved_cast_mayzero|other_position_three|other_position_four)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function return' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    wrong_type)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got RawPointer(Int)' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    callee_first)
      rg -F "TypeError in $fixture at line 2:" "$output.stdout" >/dev/null
      rg -F 'Escape analysis violation. Returning ephemeral view' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    prior_move)
      rg -F 'Semantic Error: Use of moved variable ptr' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
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

for case_name in zero mayzero_three mayzero_four mayzero_six outer_cast_mayzero between_outer_takes_cast_mayzero before_move_cast_mayzero after_move_cast_mayzero between_inner_takes_cast_mayzero innermost_cast_mayzero interleaved_cast_mayzero nonzero unknown unsafe gap overwrite wrong_type callee_first three_outer_one_inner second_move outer_and_inner_move scalar_cast cast_without_alias prior_move; do
  fixture="compiler/phase26_call_local_return_two_outer_move_finite_inner_take_${case_name}_source.gst"
  output="$build_root/two_outer_move_finite_inner_take_return_${case_name}"
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
    zero|mayzero_three|mayzero_four|mayzero_six|outer_cast_mayzero|between_outer_takes_cast_mayzero|before_move_cast_mayzero|after_move_cast_mayzero|between_inner_takes_cast_mayzero|innermost_cast_mayzero|interleaved_cast_mayzero|three_outer_one_inner)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function return' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    wrong_type)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got RawPointer(Int)' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    callee_first)
      rg -F "TypeError in $fixture at line 2:" "$output.stdout" >/dev/null
      rg -F 'Escape analysis violation. Returning ephemeral view' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    prior_move)
      rg -F 'Semantic Error: Use of moved variable ptr' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
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

for case_name in zero mayzero_four mayzero_five mayzero_seven mayzero_eight outer_cast_mayzero between_outer_takes_cast_mayzero before_move_cast_mayzero after_move_cast_mayzero between_inner_takes_cast_mayzero innermost_cast_mayzero interleaved_cast_mayzero nonzero unknown unsafe gap overwrite wrong_type callee_first four_outer_one_inner second_move outer_and_inner_move scalar_cast cast_without_alias prior_move; do
  fixture="compiler/phase26_call_local_return_finite_outer_move_finite_inner_take_${case_name}_source.gst"
  output="$build_root/finite_outer_move_finite_inner_take_return_${case_name}"
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
    zero|mayzero_four|mayzero_five|mayzero_seven|mayzero_eight|outer_cast_mayzero|between_outer_takes_cast_mayzero|before_move_cast_mayzero|after_move_cast_mayzero|between_inner_takes_cast_mayzero|innermost_cast_mayzero|interleaved_cast_mayzero|four_outer_one_inner)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function return' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    wrong_type)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got RawPointer(Int)' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    callee_first)
      rg -F "TypeError in $fixture at line 2:" "$output.stdout" >/dev/null
      rg -F 'Escape analysis violation. Returning ephemeral view' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    prior_move)
      rg -F 'Semantic Error: Use of moved variable ptr' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
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
for case_name in zero mayzero_one mayzero_four prefix_depth2 interleaved nonzero unknown unsafe gap overwrite wrong_type callee_first second_move move_without_take scalar_cast cast_without_alias prior_move; do
  fixture="compiler/phase26_call_local_return_outer_move_cast_prefix_${case_name}_source.gst"
  output="$build_root/outer_move_cast_prefix_return_${case_name}"
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
    zero|mayzero_one|mayzero_four|prefix_depth2|interleaved)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function return' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    wrong_type)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got RawPointer(Int)' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    callee_first)
      rg -F "TypeError in $fixture at line 2:" "$output.stdout" >/dev/null
      rg -F 'Escape analysis violation. Returning ephemeral view' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    prior_move|move_without_take)
      rg -F 'Semantic Error: Use of moved variable alias' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
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
for case_name in zero mayzero depth3 nonzero unknown unsafe second_alias plain_prefix plain_suffix take_inner move_inner return_cast return_take return_move gap overwrite wrong_type prior_escape scalar_cast no_alias_cast prior_move return_zero return_depth3 return_nonzero return_unknown return_unsafe return_scalar return_take_cast return_move_cast return_wrong_type return_prior_escape return_prior_move return_second_alias return_gap return_overwrite take_zero take_mayzero take_two_take_mayzero take_four_take_mayzero take_cast_outside_mayzero take_cast_inside_mayzero take_interleaved_mayzero take_nonzero take_unknown take_unsafe take_wrong_type take_prior_escape take_prior_move take_second_alias take_gap take_overwrite take_scalar_inner take_move_mixed take_no_alias_cast take_plain_prefix take_plain_suffix second_plain_zero second_plain_zero_move second_plain_depth3 second_plain_depth3_move second_plain_nonzero second_plain_unknown second_plain_unsafe second_plain_third_alias second_plain_second_cast second_plain_second_take second_plain_second_move second_plain_return_cast second_plain_return_take second_plain_return_move_cast second_plain_return_take_move second_plain_return_move_take second_plain_double_move second_plain_gap second_plain_overwrite second_plain_scalar_cast second_plain_prior_move second_plain_prior_move_return_move second_plain_wrong_type second_plain_prior_escape second_plain_plain_prefix finite_plain_third_zero finite_plain_third_mayzero finite_plain_third_zero_move finite_plain_third_mayzero_move finite_plain_fourth_depth3 finite_plain_fourth_depth3_move finite_plain_sixth_mayzero finite_plain_sixth_mayzero_move finite_plain_fourth_nonzero finite_plain_fourth_unknown finite_plain_fourth_unsafe finite_plain_third_cast_initializer finite_plain_third_take_initializer finite_plain_third_move_initializer finite_plain_third_return_cast finite_plain_third_return_take finite_plain_third_return_move_cast finite_plain_third_return_take_move finite_plain_third_return_move_take finite_plain_third_double_move finite_plain_third_gap finite_plain_third_overwrite finite_plain_third_scalar_cast finite_plain_third_plain_prefix finite_plain_third_wrong_type finite_plain_third_prior_escape finite_plain_third_prior_move finite_plain_third_prior_move_return_move second_cast_zero second_cast_zero_move second_cast_mayzero_move second_cast_interleaved_mayzero second_cast_interleaved_mayzero_move second_cast_nonzero second_cast_unknown second_cast_unsafe second_cast_third_plain second_cast_third_cast second_cast_plain_prefix second_cast_plain_interleave second_cast_take_initializer second_cast_move_initializer second_cast_return_cast second_cast_return_take second_cast_return_move_cast second_cast_double_move second_cast_gap second_cast_overwrite second_cast_scalar_cast second_cast_wrong_type second_cast_prior_escape second_cast_prior_move second_cast_prior_move_return_move direct_move_zero direct_move_mayzero direct_move_depth3 direct_move_nonzero direct_move_unknown direct_move_unsafe direct_move_cast_wrapped direct_move_mixed_take direct_move_move_take direct_move_double_move direct_move_wrong_type direct_move_prior_escape direct_move_prior_move direct_move_second_alias direct_move_gap direct_move_overwrite direct_move_scalar_cast direct_move_no_alias; do
  fixture="compiler/phase26_call_local_return_cast_alias_${case_name}_source.gst"
  output="$build_root/cast_initialized_alias_return_${case_name}"
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
    second_plain_zero|second_plain_zero_move|second_plain_depth3|second_plain_depth3_move|second_plain_third_alias|second_plain_second_cast|second_cast_zero|second_cast_zero_move|second_cast_mayzero_move|second_cast_interleaved_mayzero|second_cast_interleaved_mayzero_move|finite_plain_third_zero|finite_plain_third_mayzero|finite_plain_third_zero_move|finite_plain_third_mayzero_move|finite_plain_fourth_depth3|finite_plain_fourth_depth3_move|finite_plain_sixth_mayzero|finite_plain_sixth_mayzero_move)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function return' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    second_plain_wrong_type|second_cast_wrong_type|finite_plain_third_wrong_type)
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got RawPointer(Int)' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    second_plain_prior_escape|second_cast_prior_escape|finite_plain_third_prior_escape)
      rg -F 'Escape analysis violation. Returning ephemeral view' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    second_plain_prior_move|second_plain_prior_move_return_move|second_plain_return_move_cast|second_cast_prior_move|second_cast_prior_move_return_move|second_cast_return_move_cast)
      rg -F 'Semantic Error: Use of moved variable second' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    finite_plain_third_prior_move|finite_plain_third_prior_move_return_move|finite_plain_third_return_move_cast)
      rg -F 'Semantic Error: Use of moved variable third' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    zero|mayzero|depth3|second_alias|plain_suffix|direct_move_second_alias|return_cast|return_zero|return_depth3|return_take|return_take_cast|take_zero|take_mayzero|take_two_take_mayzero|take_four_take_mayzero|take_cast_outside_mayzero|take_cast_inside_mayzero|take_interleaved_mayzero|return_move|direct_move_zero|direct_move_mayzero|direct_move_depth3)
      rg -F "TypeError in $fixture at line 3:" "$output.stdout" >/dev/null
      rg -F '[RawNullSafeBoundary] Known zero-derived raw pointer cannot cross a declared-safe function return' "$output.stdout" >/dev/null
      if rg -F 'gust_native_capability_decision' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    wrong_type|return_wrong_type|take_wrong_type|direct_move_wrong_type)
      rg -F '[TypeMismatch] Return type mismatch. Expected Int but got RawPointer(Int)' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    prior_escape|return_prior_escape|take_prior_escape|direct_move_prior_escape)
      rg -F 'Escape analysis violation. Returning ephemeral view' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    prior_move|move_inner|return_prior_move|take_prior_move)
      rg -F 'Semantic Error: Use of moved variable ptr' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    direct_move_prior_move)
      rg -F 'Semantic Error: Use of moved variable alias' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    return_move_cast|direct_move_cast_wrapped)
      rg -F 'Semantic Error: Use of moved variable alias' "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
      ;;
    take_scalar_inner)
      rg -F "The 'take' operator is strictly banned on primitive POD types" "$output.stdout" >/dev/null
      if rg -F '[RawNullSafeBoundary]' "$output.stdout" >/dev/null; then exit 1; fi
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
echo 'Phase26.1E direct-call return, aliases, checked wrappers, mixed chains, finite Take-only, outer-Move finite-Take, innermost-Move finite-Take, and between-Move finite-inner-Take safe returns with finite outer and inner Takes, and no-fallback passed.'
