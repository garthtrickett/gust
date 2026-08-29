# Cranelift Phase 22.8 — Historical Route Successor Correction

Generated from `scripts/cranelift_feature_registry.json`. Do not edit by hand.

- Contract: `phase22_historical_route_successor_v1`
- Status: `corrective_prerequisite_complete`
- Next action: `replacement_exact_main_historical_full_for_patch22_8`
- Predecessor: `phase22_postflip_qualification_v1`

## Failed qualification retained as diagnosis

- Workflow/run: `Cranelift Historical Full` / `33274538693`
- Event: `workflow_dispatch`
- Exact head: `e995b2a1eef5895c05858d8adfe359e77d24ee21`
- Conclusion: `failure`
- Successful jobs: `16/18`
- Owning failure: `Level 3 history / phase10`
- Dependent non-success: `Level 3 declared-target completion:skipped`

## Successor replay

- `guard-cranelift-phase22-default-route-flip-contract`
- `guard-cranelift-phase22-native-implicit-output-contract`
- `guard-cranelift-phase22-default-route-flip-evidence`
- `guard-cranelift-phase22-postflip-qualification-evidence`

The retired Phase 10 selection and output records remain historical.
Their live assertions follow the registered Phase 22 route/output
successors, and the Historical shard replays default-native, package,
explicit-C oracle/rollback, and no-fallback evidence. The failed run is
not stability evidence; Patch 22.8 remains pending a successful
replacement run on exact corrected main.
