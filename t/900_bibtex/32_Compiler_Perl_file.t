use LaTeXML::Post::BiBTeX::Common::Test;
use Test::More tests => 2;

my $base = fixture(__FILE__, "compiler", "");

sub doesCompileFile {
  my ($name, $sha256) = @_;

  subtest $name => sub {

    my ($file, $error) = findFileVersion($name, $sha256);
    unless (defined($file)) {
      plan skip_all => $error;
      return;
    }

    plan tests => 2;

    # create a new reader for the file and fake the path
    my $reader = LaTeXML::Post::BiBTeX::Common::StreamReader->newFromFile($file);
    $file = fixture(__FILE__, 'bstfiles', $name);
    $$reader{filename} = $file; 
    my $path = "${base}$name.txt";

    # read + parse the file
    my ($results, $error) = readFile($reader);

    diag($error) if $error;
    ok(!defined($error), "parses $name without error");

    # compile the parsed code
    my ($program, $perror) = compileProgram("LaTeXML::Post::BiBTeX::Compiler::Target", $results, '');
    diag($perror) if $perror;
    # puts($path, $program); # to generate test cases
    is($program, slurp($path), "evaluates $name correctly");
  };
}

subtest "requirements" => sub {
  plan tests => 4;

  use_ok("LaTeXML::Post::BiBTeX::Common::StreamReader");
  use_ok("LaTeXML::Post::BiBTeX::BibStyle");
  use_ok("LaTeXML::Post::BiBTeX::Compiler");
  use_ok("LaTeXML::Post::BiBTeX::Compiler::Target");
};

doesCompileFile("plain.bst", "19f2cf88686b86aaa8e65d5f0313a92499815761e04b42e84ea2c3dc3685ada9");

1;
