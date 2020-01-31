use LaTeXML::Post::BiBTeX::Common::Test;
use Test::More tests => 2;

subtest "requirements" => sub {
  plan tests => 2;

  use_ok("LaTeXML::Post::BiBTeX::Common::StreamReader");
  use_ok("LaTeXML::Post::BiBTeX::BibStyle::StyParser");
};

doesParseFile("plain.bst", "19f2cf88686b86aaa8e65d5f0313a92499815761e04b42e84ea2c3dc3685ada9");

sub doesParseFile {
  my ($name, $sha256) = @_;

  subtest $name => sub {
    my ($file, $ferror) = findFileVersion($name, $sha256);
    unless (defined($file)) {
      plan skip_all => $ferror;
      return;
    }

    plan tests => 1;

    # create a new reader for the file and fake the path
    my $reader = LaTeXML::Post::BiBTeX::Common::StreamReader->newFromFile($file);
    $file = fixture(__FILE__, 'bstfiles', $name);
    $$reader{filename} = $file; 

    # parse file and measure the time it takes
    my $begin = measureBegin;
    my ($results, $error) = readFile($reader);
    measureEnd($begin, $name);

    # check that we did not make any errors
    isResult($results, $file, "evaluates $name correctly");
  };
}

1;
