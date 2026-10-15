# xmlan

An ordinary Erlang library for transparent XML trees, extracted from
[Signerl](https://github.com/bormilan/signerl). This bootstrap implements pure
tree/value helpers. Parsing, serialization, namespace operations, and generic
canonicalization follow in Signerl issues #85/#86; Signerl integration is #87.

## Current API

```erlang
Tree = {<<"root">>, [{<<"id">>, "7"}], [<<"hello">>]},
{ok, <<"hello">>} = xmlan:single_text(Tree),
{ok, "7"} = xmlan:attr_value(<<"id">>, element(2, Tree)),
undefined = xmlan:attr_value_or_undefined(<<"missing">>, element(2, Tree)),
WithChild = xmlan:add_new_element({<<"child">>, [], []}, Tree).
```

`add_new_element/2` appends the new child after existing content. `single_text/1`
accepts exactly one binary or Unicode character-list text child and returns UTF-8
bytes; missing, multiple, or element children return `{error, not_found}`.
Attribute lookup uses exact binary names and the first matching entry.
`attr_value/2` returns `{error, missing_attribute}` when absent; the optional form
returns `undefined`. Existing values are returned unchanged, including an explicit
`undefined` attribute value. No helper validates XML names or mutates its input.

## Public values and supported scope

`xmlan:simplified_xml/0` is a transparent tuple type:
`{BinaryName, [{BinaryName, Value}], Children}`. Names and binary values are UTF-8;
character lists contain Unicode code points. Attribute values may be character
lists, binaries, integers, or atoms; children may be trees, lists, or binaries.
Callers can construct tuples and pattern-match them. `attribute_value/0`,
`expanded_name/0`, `expanded_xml/0`, and `namespace_context/0` are also public
transparent types, matching the approved extraction contract.

There is no parser or canonicalizer in this bootstrap. Later extraction retains
the existing supported profile: complete UTF-8 input, preserved content, DTD/PI
rejection, no external entity retrieval or XML-name atom creation, absolute
namespace URIs apart from default undeclaration, C14N 1.1/Exclusive C14N. These
are migration requirements, not capabilities provided by the current four helpers.
XMLDSig/XAdES rules, signature transforms, and cryptography belong to Signerl.

## Build and validate

Supported runtimes: OTP 26, 27, and 28. Development pins in `.tool-versions` are
OTP 28.5.0.7 and rebar3 3.25.1. Project plugins are erlfmt 1.8.0 and
rebar3_lint/Elvis 5.0.4. No runtime dependencies beyond OTP kernel/stdlib,
Signerl checkout, generated keys, or operation servers are needed.

```sh
rebar3 compile
rebar3 eunit
rebar3 ct
rebar3 test
rebar3 as test cover
rebar3 flint
rebar3 dialyzer
rebar3 tall
```

`test` checks formatting, resets coverage, runs EUnit and CT with coverage, and
requires 100% total production coverage. `flint` checks formatting/lint without
rewriting source; `tall` adds lint, Xref, and Dialyzer to the full test gate.
Run `rebar3 fmt` deliberately when formatting changes are needed. No required
tests or checks may be skipped. All six OTP/OS CI jobs run `rebar3 tall`.
CI isolates global rebar configuration and reports every matrix job.
See [test responsibilities](test/TESTS.md) and [AGENTS.md](AGENTS.md).

To isolate user-global plugins on a POSIX shell, run with an empty configuration:

```sh
xmlan_global_config=$(mktemp -d)
REBAR_GLOBAL_CONFIG_DIR="$xmlan_global_config" rebar3 tall
```

The executable negative probe injects a Unicode conversion defect into a
disposable copy and requires the real `tall` tests to reject it. It leaves this
checkout unchanged; a formatting/download failure is not accepted as proof.

```sh
scripts/check_failure_probe.sh
# Optional absolute rebar3 executable:
REBAR3=/absolute/path/to/rebar3 scripts/check_failure_probe.sh
```

## Consume the library

Pin a reviewed full Git commit in your application's `rebar.config` and commit
rebar's resulting lockfile:

```erlang
{deps, [{xmlan, {git, "https://github.com/bormilan/xmlan.git",
                     {ref, "<reviewed-full-commit-SHA>"}}}]}.
```

Replace the placeholder with the validated revision. Add `xmlan` to the consumer's
application dependencies. No local path override, sibling checkout, or Signerl
source is required. Bootstrap code is published through a PR targeting `dev`;
`main` remains the release branch. A release/tag or Hex publication is not part
of this bootstrap.

## Provenance

The types/helpers and adapted tests come from Signerl's XML foundation at
`5927e41bab8674b875c51df1a1ec956d42676992`. The migration boundary was approved in
[Signerl #83](https://github.com/bormilan/signerl/issues/83); this bootstrap tracks
[Signerl #84](https://github.com/bormilan/signerl/issues/84). See [NOTICE](NOTICE)
and the preserved [Apache-2.0 license](LICENSE.md).
