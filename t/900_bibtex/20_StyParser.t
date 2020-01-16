use LaTeXML::Post::BiBTeX::Common::Test;
use Test::More tests => 7;

subtest "requirements" => sub {
  plan tests => 2;

  use_ok("LaTeXML::Post::BiBTeX::Common::StreamReader");
  use_ok("LaTeXML::Post::BiBTeX::BibStyle");
};

subtest 'readLiteral' => sub {
  plan tests => 5;

  doesReadLiteral('simple literal', 'hello#world', StyString('LITERAL', 'hello#world', [(undef, 1, 1, 1, 12)]));
  doesReadLiteral('ends after first space', 'hello world', StyString('LITERAL', 'hello', [(undef, 1, 1, 1, 6)]));
  doesReadLiteral('ends after }', 'hello}world', StyString('LITERAL', 'hello', [(undef, 1, 1, 1, 6)]));
  doesReadLiteral('ends after {', 'hello{world', StyString('LITERAL', 'hello', [(undef, 1, 1, 1, 6)]));
  doesReadLiteral('ends after %', 'hello%world', StyString('LITERAL', 'hello', [(undef, 1, 1, 1, 6)]));

  sub doesReadLiteral {
    my ($name, $input, $expected) = @_;

    my $reader = makeStringReader($input, 1);
    my ($result) = LaTeXML::Post::BiBTeX::BibStyle::StyParser::readLiteral($reader);

    is_deeply($result, $expected, $name);

    $reader->finalize;
  }
};

subtest 'readNumber' => sub {
  plan tests => 6;

  doesReadNumber('simple number',          '#0',        StyString('NUMBER', 0,      [(undef, 1, 1, 1, 3)]));
  doesReadNumber('positive number',        '#+1',       StyString('NUMBER', 1,      [(undef, 1, 1, 1, 4)]));
  doesReadNumber('negative number',        '#-1',       StyString('NUMBER', -1,     [(undef, 1, 1, 1, 4)]));
  doesReadNumber('ends after first space', '#123456 ',  StyString('NUMBER', 123456, [(undef, 1, 1, 1, 8)]));
  doesReadNumber('ends after }',           '#123456}7', StyString('NUMBER', 123456, [(undef, 1, 1, 1, 8)]));
  doesReadNumber('ends after %',           '#123456%7', StyString('NUMBER', 123456, [(undef, 1, 1, 1, 8)]));

  sub doesReadNumber {
    my ($name, $input, $expected) = @_;

    my $reader = makeStringReader($input, 1);
    my ($result) = LaTeXML::Post::BiBTeX::BibStyle::StyParser::readNumber($reader);

    is_deeply($result, $expected, $name);

    $reader->finalize;
  }
};

subtest 'readReference' => sub {
  plan tests => 4;

  doesReadReference('simple reference', '\'hello@world', StyString('REFERENCE', 'hello@world', [(undef, 1, 1, 1, 13)]));
  doesReadReference('ends after first space', "'hello world", StyString('REFERENCE', 'hello', [(undef, 1, 1, 1, 7)]));
  doesReadReference('ends with }', "'hello}world", StyString('REFERENCE', 'hello', [(undef, 1, 1, 1, 7)]));
  doesReadReference('ends with %', "'hello\%world", StyString('REFERENCE', 'hello', [(undef, 1, 1, 1, 7)]));

  sub doesReadReference {
    my ($name, $input, $expected) = @_;

    my $reader = makeStringReader($input, 1);
    my ($result) = LaTeXML::Post::BiBTeX::BibStyle::StyParser::readReference($reader);

    is_deeply($result, $expected, $name);

    $reader->finalize;
  }
};

subtest 'readQuote' => sub {
  plan tests => 4;

  doesReadQuote('empty quotes', '""',      StyString('QUOTE', '',      [(undef, 1, 1, 1, 3)]));
  doesReadQuote('simple quote', '"hello"', StyString('QUOTE', 'hello', [(undef, 1, 1, 1, 8)]));
  doesReadQuote('no escapes',   '"{\"}"',  StyString('QUOTE', '{\\',   [(undef, 1, 1, 1, 5)]));
  doesReadQuote('quote with spaces', '"hello world"', StyString('QUOTE', 'hello world', [(undef, 1, 1, 1, 14)]));

  sub doesReadQuote {
    my ($name, $input, $expected) = @_;

    my $reader = makeStringReader($input, 1);
    my ($result) = LaTeXML::Post::BiBTeX::BibStyle::StyParser::readQuote($reader);

    is_deeply($result, $expected, $name);

    $reader->finalize;
  }
};

subtest 'readBlock' => sub {
  plan tests => 5;

  doesReadBlock('empty block', '{}', StyString('BLOCK', [], [(undef, 1, 1, 1, 3)]));
  doesReadBlock('whitespace block', '{   }', StyString('BLOCK', [], [(undef, 1, 1, 1, 6)]));
  doesReadBlock('block of literal', '{hello}', StyString('BLOCK', [StyString('LITERAL', 'hello', [(undef, 1, 2, 1, 7)])], [(undef, 1, 1, 1, 8)]));
  doesReadBlock('block of multiples', '{hello \'world #3}', StyString('BLOCK', [StyString('LITERAL', 'hello', [(undef, 1, 2, 1, 7)]), StyString('REFERENCE', 'world', [(undef, 1, 8, 1, 14)]), StyString('NUMBER', 3, [(undef, 1, 15, 1, 17)])], [(undef, 1, 1, 1, 18)]));
  doesReadBlock('nested blocks', '{outer {inner #1} outer}', StyString('BLOCK', [StyString('LITERAL', 'outer', [(undef, 1, 2, 1, 7)]), StyString('BLOCK', [StyString('LITERAL', 'inner', [(undef, 1, 9, 1, 14)]), StyString('NUMBER', 1, [(undef, 1, 15, 1, 17)])], [(undef, 1, 8, 1, 18)]), StyString('LITERAL', 'outer', [(undef, 1, 19, 1, 24)])], [(undef, 1, 1, 1, 25)]));

  sub doesReadBlock {
    my ($name, $input, $expected) = @_;

    my $reader = makeStringReader($input, 1);
    my ($result, $e) = LaTeXML::Post::BiBTeX::BibStyle::StyParser::readBlock($reader);

    is_deeply($result, $expected, $name);

    $reader->finalize;
  }
};

subtest 'readCommand' => sub {
  plan tests => 10;

  doesReadCommand('ENTRY', 'ENTRY    {a} {b} {c} {d}', StyCommand(StyString('LITERAL', 'ENTRY', [(undef, 1, 1, 1, 6)]), [(StyString('BLOCK', [StyString('LITERAL', 'a', [(undef, 1, 11, 1, 12)])], [(undef, 1, 10, 1, 13)]), StyString('BLOCK', [StyString('LITERAL', 'b', [(undef, 1, 15, 1, 16)])], [(undef, 1, 14, 1, 17)]), StyString('BLOCK', [StyString('LITERAL', 'c', [(undef, 1, 19, 1, 20)])], [(undef, 1, 18, 1, 21)]))], [(undef, 1, 1, 1, 21)]));
  doesReadCommand('EXECUTE', 'EXECUTE  {a} {b} {c} {d}', StyCommand(StyString('LITERAL', 'EXECUTE', [(undef, 1, 1, 1, 8)]), [(StyString('BLOCK', [StyString('LITERAL', 'a', [(undef, 1, 11, 1, 12)])], [(undef, 1, 10, 1, 13)]))], [(undef, 1, 1, 1, 13)]));
  doesReadCommand('FUNCTION', 'FUNCTION {a} {b} {c} {d}', StyCommand(StyString('LITERAL', 'FUNCTION', [(undef, 1, 1, 1, 9)]), [(StyString('BLOCK', [StyString('LITERAL', 'a', [(undef, 1, 11, 1, 12)])], [(undef, 1, 10, 1, 13)]), StyString('BLOCK', [StyString('LITERAL', 'b', [(undef, 1, 15, 1, 16)])], [(undef, 1, 14, 1, 17)]))], [(undef, 1, 1, 1, 17)]));
  doesReadCommand('INTEGERS', 'INTEGERS {a} {b} {c} {d}', StyCommand(StyString('LITERAL', 'INTEGERS', [(undef, 1, 1, 1, 9)]), [(StyString('BLOCK', [StyString('LITERAL', 'a', [(undef, 1, 11, 1, 12)])], [(undef, 1, 10, 1, 13)]))], [(undef, 1, 1, 1, 13)]));
  doesReadCommand('ITERATE', 'ITERATE  {a} {b} {c} {d}', StyCommand(StyString('LITERAL', 'ITERATE', [(undef, 1, 1, 1, 8)]), [(StyString('BLOCK', [StyString('LITERAL', 'a', [(undef, 1, 11, 1, 12)])], [(undef, 1, 10, 1, 13)]))], [(undef, 1, 1, 1, 13)]));
  doesReadCommand('MACRO', 'MACRO    {a} {b} {c} {d}', StyCommand(StyString('LITERAL', 'MACRO', [(undef, 1, 1, 1, 6)]), [(StyString('BLOCK', [StyString('LITERAL', 'a', [(undef, 1, 11, 1, 12)])], [(undef, 1, 10, 1, 13)]), StyString('BLOCK', [StyString('LITERAL', 'b', [(undef, 1, 15, 1, 16)])], [(undef, 1, 14, 1, 17)]))], [(undef, 1, 1, 1, 17)]));
  doesReadCommand('READ', 'READ     {a} {b} {c} {d}', StyCommand(StyString('LITERAL', 'READ', [(undef, 1, 1, 1, 5)]), [()], [(undef, 1, 1, 1, 5)]));
  doesReadCommand('REVERSE', 'REVERSE  {a} {b} {c} {d}', StyCommand(StyString('LITERAL', 'REVERSE', [(undef, 1, 1, 1, 8)]), [(StyString('BLOCK', [StyString('LITERAL', 'a', [(undef, 1, 11, 1, 12)])], [(undef, 1, 10, 1, 13)]))], [(undef, 1, 1, 1, 13)]));
  doesReadCommand('SORT', 'SORT     {a} {b} {c} {d}', StyCommand(StyString('LITERAL', 'SORT', [(undef, 1, 1, 1, 5)]), [()], [(undef, 1, 1, 1, 5)]));
  doesReadCommand('STRINGS', 'STRINGS  {a} {b} {c} {d}', StyCommand(StyString('LITERAL', 'STRINGS', [(undef, 1, 1, 1, 8)]), [(StyString('BLOCK', [StyString('LITERAL', 'a', [(undef, 1, 11, 1, 12)])], [(undef, 1, 10, 1, 13)]))], [(undef, 1, 1, 1, 13)]));

  sub doesReadCommand {
    my ($name, $input, $expected) = @_;

    my $reader = makeStringReader($input, 1);
    my ($result) = LaTeXML::Post::BiBTeX::BibStyle::StyParser::readCommand($reader);

    is_deeply($result, $expected, $name);

    $reader->finalize;
  }
};

1;
