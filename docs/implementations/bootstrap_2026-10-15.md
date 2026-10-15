# Standalone xmlan bootstrap (Signerl #84)

## Scope and changes

PR #90 is merged into Signerl `dev` at
`2f7d08db5bfd88f8f907c9dde15121a80b1ef9ee`; #83 is closed. This task bootstraps
the initially empty xmlan repository according to that approved contract.

`src/xmlan.erl` ports the public transparent XML types and four existing helpers
unchanged from Signerl's XML foundation: `add_new_element/2`, `single_text/1`,
`attr_value/2`, and `attr_value_or_undefined/2`. The ordinary library application
uses kernel/stdlib only and no per-operation process. Parser, namespace, export,
and canonicalization implementation remains #85/#86; Signerl dependency/removal
is #87. No Signerl production code or behavior changes in this bootstrap.

Rebar configuration pins erlfmt 1.8.0 and rebar3_lint/Elvis 5.0.4; the toolchain
pins OTP 28.5.0.7 and rebar3 3.25.1. Aliases require the complete test suite, 100%
coverage, formatting/lint, Xref, and Dialyzer through native `tall`. The sole lint
exception preserves the intentionally transparent public types. Six OTP/OS CI
jobs isolate global configuration and use `fail-fast: false`. No dummy production
functions or empty-code coverage waiver is used.

Nineteen EUnit cases adapt existing pure tree/value contracts and cover Unicode,
empty/multiple/element children, exact/missing names, all supported attribute
representations, duplicate-first behavior, and child order. A CT case starts
xmlan and runs an external tuple consumer in a fresh VM. README, test docs, and
AGENTS document public scope, commands, pinned consumption, and review gates.
NOTICE and Signerl's LICENSE.md preserve attribution/licensing.

The empty remote needs base branches before GitHub can host a reviewable PR.
Only the preserved license will initialize `main` and `dev`; all library code,
configuration, tests, CI, and docs remain in the focused bootstrap PR to `dev`.
Native implementation gates run before either initialization or publication.
No PR is automatically merged. Cross-repository closure uses
`Closes bormilan/signerl#84`, then verifies actual issue state after merge.

## Validation-first evidence

Before implementation, all 19 EUnit cases failed with missing API (`undef`).
After extracting the unchanged helpers, all 19 pass, and the standalone CT
consumer passes. `scripts/check_failure_probe.sh` injects the realistic
`list_to_binary` Unicode defect in a disposable source copy; `tall` must fail its
real Unicode test rather than fail earlier or silently pass.

Final gates, clean-source/dependency consumption, type controls, and six-job
CI validation will be recorded after they run.

## Persistence

Persistent source checkout: `/Users/milanbor/projects/xmlan`.
Recovery snapshots, mutation/type/consumer probes, and logs:
`/Users/milanbor/projects/signerl/.recovery/issue-84/`.
The original Signerl checkout/local work and prior recovery copies are preserved.
No xmlan CodeGraph index exists; none was created. Native validation uses installed
OTP 28.4.2 and pinned rebar3 3.25.1 with an isolated empty global configuration.
CI validates the pinned OTP 28 patch plus OTP 26/27 on both supported OSes.

## Native validation before initialization

- Focused EUnit: 19 cases passed; standalone CT: 1 case passed.
- `test`, `as test cover`, `flint`, `dialyzer`, and final `tall` passed:
  19 EUnit + 1 CT = 20 cases, no skips, 100% production coverage.
- Executable mutation probe: `tall` rejected the real Unicode defect through
  the existing Unicode contract, not through formatting/setup failure.
- Standalone consumer compiled/ran outside rebar's test VM; full-PLT Dialyzer
  passed. Opaque-only construction and invalid atom-name/float-value controls
  produced their intended warnings. All four helper bodies match the baseline
  Erlang AST after removing source annotations.
- Preserved license bytes, document links/whitespace, and the six-job workflow
  configuration passed validation. The full unfinished source was archived before
  branch setup. Fresh-checkout and HTTPS dependency probes follow below.

## Clean checkout validation

An independent Git clone of the bootstrap commit (without `_build` or source
symlinks) passed native `tall`: all 20 tests, 100% coverage, lint, Xref, and
Dialyzer. It rebuilt the pinned plugins with isolated global configuration.
No Signerl source, local dependency override, generated fixture, or runtime
server is required. HTTPS/Git dependency consumption and latest-head CI results
are recorded in the PR and persistent recovery manifest after publication.

## Initial workflow correction

GitHub rejected the first workflow before any jobs started because `runner`
is unavailable in job-level `env`. Its temporary directory is now resolved in
step-level `env` and exported through GITHUB_ENV after the runner starts. See
[GitHub context availability](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#context-availability).
The failed startup is not counted as a passing check. Native `tall` is rerun
before publishing the correction; all six jobs must pass on the corrected SHA.

The first real HTTPS/Git dependency consumer independently compiled, started,
ran, and passed Dialyzer with an immutable xmlan ref and generated lockfile.
That probe is repeated against the corrected publication SHA.
