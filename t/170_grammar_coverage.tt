# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use Test::More;
use LaTeXML;
use LaTeXML::MathParser;
local $::RD_TRACE = 1;
use LaTeXML::Common::Config;
use Data::Dumper;
local $Data::Dumper::Sortkeys = 1;


# Obtain the rule pairs from MathGrammar, which we want to exhaustively test:
my %grammar_dependencies = obtain_dependencies();

my $opts = LaTeXML::Common::Config->new(input_limit => 100);


my $converter = LaTeXML->get_converter($opts);
$converter->prepare_session($opts);

my %tested_dependencies = ();

my @core_tests = parser_test_filenames();
for my $test (@core_tests) {
  my $response = $converter->convert($test);
  my @log_lines = split("\n", $response->{log});
  for my $line (@log_lines) {
    if ($line =~ /(\w+)\s*\|\>\>Matched (?:subrule|production)\: \[(\w+)/) {
      $tested_dependencies{$1}{$2} = 1;
    }
  }
}

my $ok_count = 0;
my $missing_count = 0;
my $extra_count = 0;
my %missing = ();
my %extra = ();

for my $rule(grep {!/^_/} keys %tested_dependencies) {
  my $subrules = $tested_dependencies{$rule};
  for my $subrule(keys %$subrules) {
    if ($grammar_dependencies{$rule}{$subrule}) {
      delete $grammar_dependencies{$rule}{$subrule};
      $ok_count += 1;
    } else {
      $extra_count += 1;
      $extra{$rule}{$subrule} = 1;
    }
  }
}

for my $rule(keys %grammar_dependencies) {
  my $subrules = $grammar_dependencies{$rule} || ();
  for my $subrule (keys %$subrules) {
    $missing_count += 1;
    $missing{$rule}{$subrule} = 1;
  }
}

ok($ok_count > 100, "Tested a big subset of MathGrammar");
is($missing_count, 0, "MathGrammar dependencies (currently tested in $ok_count cases), were not matched in the following cases: \n".Dumper(\%missing));

# Allow these for now, until we figure out how to check for the (s) variant rules
# for example: (endPunct Formula { [$item[1],$item[2]]; })(s)
# is($extra_count, 0, "Tests had rules which were matched, but not recorded in grammar metadata: \n".Dumper(\%extra));

done_testing();

























#**********************************************************************
# Auxiliary functions, should these be in a utility module?
#**********************************************************************
sub parser_test_filenames {
  my $directory = "t/parse";
  if (!opendir($DIR, $directory)) {
    # Can't read directory? Fail (assumed single) test.
    return do_fail($directory, "Couldn't read directory $directory:$!"); }
  else {
    my @dir_contents = sort readdir($DIR);
    my $t;
    my @core_tests   = map { (($t = $_) =~ /\.tex$/      ? ("t/parse/$t") : ()); } @dir_contents;
    closedir($DIR);
    @core_tests;
  }
}

use LaTeXML::MathGrammar;
sub obtain_dependencies {
  my $internalparser = LaTeXML::MathGrammar->new();
  my %dependencies = ();
  my @rule_names = grep {!/^_/} keys %{$$internalparser{rules}};
  for my $rule (@rule_names) {
    # Direct calls are edges,
    my $calls = $$internalparser{rules}{$rule}{"calls"} || [];
    for my $call(@$calls) {
      if ($call !~ /^_/) {
        $dependencies{c14n($rule)}{$call} = 1;
      }
    }
    # Also! argcode are edges from their subrule (e.g. preScripted[bigop] is an edge preScripted -> bigop)
    my $prods = $$internalparser{rules}{$rule}{"prods"} || [];
    for my $prod (@$prods) { 
      my $items = $$prod{items} || [];
      for my $item (@$items) {
        if ($$item{argcode} && $$item{subrule}) {
          if ($$item{argcode} =~/^\['(.+)'\]$/) {
            $dependencies{c14n($$item{subrule})}{$1} = 1;
          }
        }
      }
    }
  }
  %dependencies
}

sub c14n {
  my $rule = shift;
  # RD_TRACE only gives us upto 10 characters of the leading rule name, 
  # so we're forced to trim the top
  return substr($rule, 0,10);
}

1;