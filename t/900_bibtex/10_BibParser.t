use LaTeXML::Post::BiBTeX::Common::Test;
use Test::More tests => 6;

subtest "requirements" => sub {
  plan tests => 4;

  use_ok("LaTeXML::Post::BiBTeX::Common::StreamReader");
  use_ok("LaTeXML::Post::BiBTeX::Bibliography::BibEntry");
  use_ok("LaTeXML::Post::BiBTeX::Bibliography::BibField");
  use_ok("LaTeXML::Post::BiBTeX::Bibliography::BibString");
};

# convenience functions
sub BibEntry  { LaTeXML::Post::BiBTeX::Bibliography::BibEntry->new(@_); }
sub BibField    { LaTeXML::Post::BiBTeX::Bibliography::BibField->new(@_); }
sub BibString { LaTeXML::Post::BiBTeX::Bibliography::BibString->new(@_); }

subtest 'readLiteral' => sub {
  plan tests => 5;

  doesReadLiteral('empty', ',',           BibString('LITERAL', '',            [(undef, 1, 1, 1, 1)]));
  doesReadLiteral('space', 'hello world', BibString('LITERAL', 'hello world', [(undef, 1, 1, 1, 12)]));
  doesReadLiteral('with an @ sign', 'hello@world', BibString('LITERAL', 'hello@world', [(undef, 1, 1, 1, 12)]));
  doesReadLiteral('with an " sign', 'hello"world', BibString('LITERAL', 'hello"world', [(undef, 1, 1, 1, 12)]));
  doesReadLiteral('surrounding space', 'hello  world     ', BibString('LITERAL', 'hello  world', [(undef, 1, 1, 1, 13)]));

  sub doesReadLiteral {
    my ($name, $input, $expected) = @_;

    my $reader = makeStringReader($input, 1, '}');
    my ($result) = LaTeXML::Post::BiBTeX::Bibliography::BibParser::readLiteral($reader);

    is_deeply($result, $expected, $name);

    $reader->finalize;
  }
};

subtest 'readBrace' => sub {
  plan tests => 5;

  doesReadBrace('empty braces',  '{}',      BibString('BRACKET', '',      [(undef, 1, 1, 1, 3)]));
  doesReadBrace('simple braces', '{hello}', BibString('BRACKET', 'hello', [(undef, 1, 1, 1, 8)]));
  doesReadBrace('nested braces', '{hello{world}}', BibString('BRACKET', 'hello{world}', [(undef, 1, 1, 1, 15)]));
  doesReadBrace('brace with open \\', '{hello \{world}}', BibString('BRACKET', 'hello \\{world}', [(undef, 1, 1, 1, 17)]));
  doesReadBrace('brace with close \\', '{hello world\}}', BibString('BRACKET', 'hello world\\', [(undef, 1, 1, 1, 15)]));

  sub doesReadBrace {
    my ($name, $input, $expected) = @_;

    # create a new string reader with some dummy input
    my $reader = makeStringReader($input, 1);
    my ($result) = LaTeXML::Post::BiBTeX::Bibliography::BibParser::readBrace($reader);

    is_deeply($result, $expected, $name);

    $reader->finalize;
  }
};

subtest 'readQuote' => sub {
  plan tests => 4;

  doesReadQuote('empty quotes', '""',      BibString('QUOTE', '',      [(undef, 1, 1, 1, 3)]));
  doesReadQuote('simple quote', '"hello"', BibString('QUOTE', 'hello', [(undef, 1, 1, 1, 8)]));
  doesReadQuote('with { s',     '"{\"}"',  BibString('QUOTE', '{\\"}', [(undef, 1, 1, 1, 7)]));
  doesReadQuote('quote with spaces', '"hello world"', BibString('QUOTE', 'hello world', [(undef, 1, 1, 1, 14)]));

  sub doesReadQuote {
    my ($name, $input, $expected) = @_;

    my $reader = makeStringReader($input, 1, ', ');
    my ($result) = LaTeXML::Post::BiBTeX::Bibliography::BibParser::readQuote($reader);

    is_deeply($result, $expected, $name);

    $reader->finalize;
  }
};

subtest 'readField' => sub {
  plan tests => 9;

  # value only
  doesReadField('empty tag', '', undef);
  doesReadField('literal value', 'value', BibField(undef, [(BibString('LITERAL', 'value', [(undef, 1, 1, 1, 6)]))], [(undef, 1, 1, 1, 6)]));
  doesReadField('quoted value', '"value"', BibField(undef, [(BibString('QUOTE', 'value', [(undef, 1, 1, 1, 8)]))], [(undef, 1, 1, 1, 8)]));
  doesReadField('braced value', '{value}', BibField(undef, [(BibString('BRACKET', 'value', [(undef, 1, 1, 1, 8)]))], [(undef, 1, 1, 1, 8)]));
  doesReadField('concated literals', 'value1 # value2', BibField(undef, [(BibString('LITERAL', 'value1', [(undef, 1, 1, 1, 7)]), BibString('LITERAL', 'value2', [(undef, 1, 10, 1, 16)]))], [(undef, 1, 1, 1, 16)]));
  doesReadField('concated quote and literal', '"value1" # value2', BibField(undef, [(BibString('QUOTE', 'value1', [(undef, 1, 1, 1, 9)]), BibString('LITERAL', 'value2', [(undef, 1, 12, 1, 18)]))], [(undef, 1, 1, 1, 18)]));

  # name = value
  doesReadField('simple name', 'name = value', BibField(BibString('LITERAL', 'name', [(undef, 1, 1, 1, 5)]), [(BibString('LITERAL', 'value', [(undef, 1, 8, 1, 13)]))], [(undef, 1, 1, 1, 13)]));
  doesReadField('simple name (compact)', 'name=value', BibField(BibString('LITERAL', 'name', [(undef, 1, 1, 1, 5)]), [(BibString('LITERAL', 'value', [(undef, 1, 6, 1, 11)]))], [(undef, 1, 1, 1, 11)]));
  doesReadField('name + concat value', 'name=a#"b"', BibField(BibString('LITERAL', 'name', [(undef, 1, 1, 1, 5)]), [(BibString('LITERAL', 'a', [(undef, 1, 6, 1, 7)]), BibString('QUOTE', 'b', [(undef, 1, 8, 1, 11)]))], [(undef, 1, 1, 1, 11)]));

  sub doesReadField {
    my ($name, $input, $expected) = @_;

    my $reader = makeStringReader($input, 1, ', ');
    my ($result) = LaTeXML::Post::BiBTeX::Bibliography::BibParser::readField($reader);

    if (defined($expected)) {
      is_deeply($result, $expected, $name);
    } else {
      ok(!defined($result), $name);
    }

    $reader->finalize;
  }
};

use Encode;

subtest 'readEntry' => sub {
  plan tests => 3;

  doesReadEntry('01_preamble');
  doesReadEntry('02_string');
  doesReadEntry('03_article');

  sub doesReadEntry {
    my ($input, $expected) = @_;

    # create a new string reader with some dummy input
    my ($reader, $path) = makeFixtureReader(__FILE__, 'bibparser', "$input.bib");

    my ($result) = LaTeXML::Post::BiBTeX::Bibliography::BibParser::readEntry($reader);
    # puts("$path.txt", $result->stringify); # to generate the test cases
    is($result->stringify, slurp("$path.txt"), $input);
    $reader->finalize;
  }
};

1;