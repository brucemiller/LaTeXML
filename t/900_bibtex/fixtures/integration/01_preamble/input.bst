% This file is intended to test preamble handling

ENTRY { nothing } { } { }

FUNCTION {print.preamble} {
  "^" preamble$ "$" * *
  write$ newline$
}

READ

EXECUTE {print.preamble}

ITERATE { skip$ }

