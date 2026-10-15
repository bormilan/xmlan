# Test responsibilities

| File | Cases | Responsibility |
| --- | ---: | --- |
| `xmlan_test.erl` | 19 | Child append/order, Unicode text extraction, supported attribute values, exact/missing names, and first duplicate lookup. |
| `xmlan_SUITE.erl` | 1 | Start the library and exercise a transparent-tuple consumer in a fresh VM using only xmlan and OTP. |
| `xmlan_consumer.erl` | Consumer support | Construct/pattern-match public tuple types and exercise all four public helpers. |

Total: 19 EUnit + 1 Common Test = 20 cases. These are real migrated tree/value
contracts, not placeholder functions for bootstrap coverage. Signerl's original
`single_text_test_` and child-insertion/value assertions are adapted to standalone
tuples because the parser/exporter are extracted later. Added cases retain Unicode
code points, empty values, missing attributes, duplicate-first behavior, and
multiple/non-text children. See [NOTICE](../NOTICE) for provenance.

`rebar3 test` resets coverage once, runs both frameworks with coverage, and
requires 100% combined production coverage. `rebar3 tall` additionally checks
lint, Xref, and Dialyzer; all six OTP 26/27/28 Ubuntu/Windows jobs must pass.
No OpenSSL, xmllint, Signerl source, or generated fixtures are required here.
Later parser/canonicalization issues add their own tests and prerequisites.

`xmlan_consumer.erl` also compiles outside rebar's test profile. After
`rebar3 compile`, a POSIX-shell probe is:

```sh
xmlan_consumer_dir=$(mktemp -d)
erlc +debug_info -o "$xmlan_consumer_dir" test/xmlan_consumer.erl
erl -noshell -pa "$xmlan_consumer_dir" _build/default/lib/xmlan/ebin \
  -eval 'xmlan_consumer:run(), halt().'
```

Analyze this consumer alongside the production BEAM with the full dependency PLT
from `rebar3 dialyzer` to verify public type compatibility. An opaque-only copy
must reject tuple construction. The native bootstrap validation records this
control and a clean HTTPS/Git dependency consumer in its implementation log.

Run `scripts/check_failure_probe.sh` to prove `tall` catches a real Unicode
regression in a disposable copy. This diagnostic requires POSIX shell tools and
the pinned rebar3 on PATH (or `REBAR3=/absolute/path`). The ordinary library and
six-job CI test gate require OTP/rebar3 only.
