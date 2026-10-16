# Test responsibilities

| File | Cases | Responsibility |
| --- | ---: | --- |
| `xmlan_test.erl` | 19 | Child append/order, Unicode text extraction, supported attribute values, exact/missing names, and first duplicate lookup. |
| `xmlan_parser_test.erl` | 138 | UTF-8/prologs, exact serialization, content/reference normalization, DTD/PI/encoding/trailing-input rejection, namespace validation/selection/scope, and 10,000-level parsing/export/projection. |
| `xmlan_SUITE.erl` | 2 | A fresh-VM consumer using only xmlan/OTP, and frozen pre-extraction parsed/exported-byte contracts. |
| `xmlan_xml_SUITE.erl` | 10 | File round trips/errors, unsupported file input, controlled external-file/HTTP entity rejection, and zero persistent atom growth in two fresh-name parse/export batches. |
| `xmlan_consumer.erl` | Consumer support | Construct/pattern-match public types; exercise every exported API through ordinary tuples and frozen XML fixtures. |

Total: 157 EUnit + 12 Common Test = 169 cases. No skipped required tests.
The pure XML cases are adapted from Signerl's completed XML foundation; signature
predicates, signing/verification probes, and C14N assertions stay in Signerl until
their corresponding extraction/integration issues. Namespace selectors use generic
example names/URIs. Parser content assertions compare exact exported bytes without
requiring a canonicalizer. The standalone atom probe warms code paths, then checks
two disjoint batches of fresh element, attribute, prefix, and local names. Both
batches must add zero persistent atoms, including rejected fresh-name input.
The HTTP canary first verifies a real loopback request, then rejects external
SYSTEM/PUBLIC subsets, general entities, and parameter entities without a request.
The file canary uses a generated test-only file and relative-path input.
See [NOTICE](../NOTICE) for provenance and
[frozen fixture ownership](examples/xmlan_migration/README.md).

`rebar3 test` resets coverage once, runs both frameworks with coverage, and
requires 100% combined production coverage. `rebar3 tall` additionally checks
lint, Xref, and Dialyzer; all six OTP 26/27/28 Ubuntu/Windows jobs must pass.
Only OTP/rebar3 are needed: xmerl is an OTP runtime dependency. No OpenSSL,
xmllint, Signerl source, certificates, or keys are needed by these tests.
Canonicalization and its existing xmllint cross-checks follow in #86.

`xmlan_consumer.erl` also compiles outside rebar's test profile. After
`rebar3 compile`, a POSIX-shell probe from the checkout root is:

```sh
xmlan_consumer_dir=$(mktemp -d)
erlc +debug_info -o "$xmlan_consumer_dir" test/xmlan_consumer.erl
erl -noshell -pa "$xmlan_consumer_dir" _build/default/lib/xmlan/ebin \
  -eval 'ok = xmlan_consumer:run("test/examples/xmlan_migration"), halt().'
```

Analyze the consumer alongside production BEAMs with the full dependency PLT
from `rebar3 dialyzer` to verify public type compatibility. An opaque-only copy
must reject tuple construction. The native bootstrap log records that type
control; parser extraction repeats the expanded external consumer and a clean
HTTPS/Git dependency consumer. Golden output mismatch must fail the consumer.

Run `scripts/check_failure_probe.sh` to prove `tall` catches a real Unicode
regression in a disposable copy. This diagnostic requires POSIX shell tools and
the pinned rebar3 on PATH (or `REBAR3=/absolute/path`). The ordinary library and
six-job CI test gate require OTP/rebar3 only.
