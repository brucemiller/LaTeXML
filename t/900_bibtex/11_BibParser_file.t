use LaTeXML::Post::BiBTeX::Common::Test;
use Test::More tests => 5;

subtest "requirements" => sub {
  plan tests => 2;

  use_ok("LaTeXML::Post::BiBTeX::Common::StreamReader");
  use_ok("LaTeXML::Post::BiBTeX::Bibliography::BibParser");
};

doesParseFile("complicated.bib", 6);
doesEvalFile("complicated.bib");

doesParseFile("kwarc.bib", 6994);
doesEvalFile("kwarc.bib");

sub doesParseFile {
  my ($name, $expectEntries) = @_;

  subtest $name => sub {
    plan tests => 2;

    # create an input file
    my ($reader) = makeFixtureReader(__FILE__, 'bibfiles', $name);

    # parse file and measure the time it takes
    my $begin = measureBegin;
    my ($results, $errors) = readFile($reader, 0);
    measureEnd($begin, $name);

    # check that we did not make any errors
    is(scalar(@$results), $expectEntries, 'parses correct number of entries from ' . $name);
    is(scalar(@$errors), 0, 'does not produce any errors parsing ' . $name);
  };
}

sub doesEvalFile {
  my ($name, $expectEntries) = @_;

  subtest $name => sub {
    plan tests => 2;

    # create an input file
    my ($reader, $path) = makeFixtureReader(__FILE__, 'bibfiles', $name);

    my $begin = measureBegin;
    my ($results, $errors) = LaTeXML::Post::BiBTeX::Bibliography::BibParser::readFile($reader, 1);
    measureEnd($begin, $name);

    # check that the result is correct
    isResult($results, $path, "evaluates $name correctly");
    is(scalar(@$errors), 0, 'does not produce any errors parsing ' . $name);
  };
}

1;
