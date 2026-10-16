# Canonicalization interoperability fixtures

All nine XML files are copied byte-for-byte from Signerl's `test/examples/c14n/`
at baseline `5927e41bab8674b875c51df1a1ec956d42676992` under Apache-2.0.
They cover namespace/attribute sorting, nested/default bindings, escaping, mixed
content, Unicode, and preserved whitespace/references. Git text conversion is
disabled for XML fixtures on all platforms.

`xmlan_c14n_interop_SUITE` parses each original fixture and compares canonical
bytes against real `xmllint --c14n11` and `--exc-c14n` output. Preserved-content
cases also canonicalize re-exported XML with xmllint. Only Windows stdout's
C-stdio LF-to-CRLF transport is undone; fixtures and production bytes are untouched.
Missing xmllint fails the suite rather than skipping it.

`dsig_like.xml` is a generic structured-XML fixture. Its names and URI attributes
are ordinary XML data for the canonicalizer; no signature transforms, algorithm
selection, certificate, digest, or signature processing moves into xmlan.
Independently signed protocol fixtures remain in Signerl.

The separately frozen `../xmlan_migration/c14n11.xml` and `exclusive.xml` preserve
pre-extraction Signerl output and original SHA256 hashes. Do not regenerate them
to hide a behavior difference. See [NOTICE](../../../NOTICE) for provenance.
