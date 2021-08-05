# Integration Tests

This directory contains integration tests. 
Each integration test is contained in a single directory and consists of the following files:

- `input_citations.spec`: Similar to the `.aux`, contains keys that should be cited. One per line, empty lines are ignored. 
- `input_macro.spec`: Name of the macro to wrap ouput in. When empty, no marco is assumed. 
- `input.bst`: Input .bst file
- `input.bib`: Input .bib file
- `output.bbl`: Expected output
- `output.bbl.org`: Output produced by BiBTeX
