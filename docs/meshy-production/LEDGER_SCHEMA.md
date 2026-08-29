# Coverage ledger field mapping

`COVERAGE_LEDGER.json.fieldContract` is the canonical ordered 46-field schema.
`COVERAGE_LEDGER.csv` carries the same fields and values in snake_case, in the
same column order. Mechanical comparison converts each CSV header from
snake_case to lower camelCase; the one non-mechanical historical exception is:

- JSON `referenceInputPathsAndChecksums`
- CSV `reference_input_paths_checksums`

VISUAL-001-R5 compared all 208 rows × all 46 fields under this mapping and found
zero value mismatches. Any later schema change requires synchronized JSON/CSV
updates, a versioned decision, fresh checksums, and independent review.
