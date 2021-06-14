# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use strict;
use warnings;
use Test::More;
use LaTeXML;
use LaTeXML::MathParser;
local $::RD_TRACE = 1;
use LaTeXML::Common::Config;
use Data::Dumper;
local $Data::Dumper::Sortkeys = 1;

if (!$ENV{"CI"}) {
  plan skip_all => "Only checked in continuous integration.";
  done_testing();
  exit;
}

# Obtain the rule pairs from MathGrammar, which we want to exhaustively test:
my %grammar_dependencies = obtain_dependencies();

my $opts = LaTeXML::Common::Config->new(input_limit => 100, verbosity=>-2);

my $converter = LaTeXML->get_converter($opts);
$converter->prepare_session($opts);

my %tested_dependencies = ();

my @core_tests = parser_test_filenames();
for my $test (@core_tests) {
  note("grammar coverage $test...");
  my $regularized_log = '';
  my $response;
  my $log_handle;
  open($log_handle, ">>", \$regularized_log) or croak("Can't redirect STDERR to log! Dying...");
  {
    local *STDERR       = *$log_handle;
    binmode(STDERR, ':encoding(UTF-8)');
    $response = $converter->convert($test);
#  my $regularized_log = $response->{log};
    }
  # Preprocess split lines back to single lines, e.g.
  # 2|AnythingAn|>>Matched subrule:                    |
  #  |          |[modifierFormulae]<< (return value:   |
  # -- TO:
  # 2|AnythingAn|>>Matched subrule: [modifierFormulae]<< (return value:   |
  # Also:
  # 10|  bigop   |(consumed: [ SUMOP:sum:1])            |
  # 9|preScripte|>>Matched subrule: [$arg[0]]<< (return|
  #   |          |value: [<XMTok                        |

  $regularized_log =~ s/\:\s+\|\n\s*\|\s+\|\[/\: \[/g;
  note($response->{status});
  my @log_lines = split("\n", $regularized_log);
  my $prev_line = '';
  for my $line (@log_lines) {
    if ($line =~ /(\w+)\s*\|(?:(?:\>\>(?:\.*)Matched(?:\(keep\))? (?:subrule|production))|(?:\(consumed))\:\s*\[\s*(\w+|\$arg\[\d+\])/) {
      my $parent = $1;
      my $child = $2;
      if ($child =~ /^\$arg/) {
        if ($prev_line =~ /^\s*\d+\|\s*(\w+)\s*\|/) {
          $child = $1;
        }
      }
      if ($parent ne $child) {
        $tested_dependencies{$parent}{$child} = 1;
      }
    }
    $prev_line = $line;
  }
}

my $ok_count = 0;
my $missing_count = 0;
my $extra_count = 0;
my %missing = ();
my %extra = ();
delete $grammar_dependencies{'Start'}; # never reported in terse log
# Single lexeme top-level rules never parse, BECAUSE the grammar is never run on 1-lexeme formulae
delete $grammar_dependencies{'AnythingAn'}{"FLOATSUPERSCRIPT"};
delete $grammar_dependencies{'AnythingAn'}{"MODIFIER"};
# Reachable conceptually by an ambiguous grammar, but not in the RecDescent algorithm
# AnyOp variants are not reached as Formula variants take precedents (such as Factor's preScripted variants)
delete $grammar_dependencies{'AnyOp'}{"OPERATOR"};
delete $grammar_dependencies{'AnyOp'}{"addScripts"};
delete $grammar_dependencies{'AnyOp'}{"preScripted"};
delete $grammar_dependencies{'argPunct'}{'VERTBAR'};
delete $grammar_dependencies{'Expression'}{'punctExpr'}; # Unreachable, due to Formula -> punctExpr
delete $grammar_dependencies{'aSuperscri'}{'AnyOp'};
delete $grammar_dependencies{'aSuperscri'}{'Expression'};
# forbid rules should never match, don't check them here.
# TODO: We need tests for the always-failing productions!
delete $grammar_dependencies{'doubtArgs'}{'forbidArgs'};
delete $grammar_dependencies{'requireArg'};

# Needs regex enhancement

# preScripted -> bigop
# \sum ^2
# preScripted -> ATOM_OR_ID
# \frac12 _1$

for my $rule(grep {!/^_/} keys %tested_dependencies) {
  my $subrules = $tested_dependencies{$rule};
  for my $subrule(keys %$subrules) {
    if ($rule ne $subrule) {
      if ($grammar_dependencies{$rule}{$subrule}) {
        delete $grammar_dependencies{$rule}{$subrule};
        $ok_count += 1;
      } else {
        $extra_count += 1;
        $extra{$rule}{$subrule} = 1;
      }
    }
  }
}

for my $rule(keys %grammar_dependencies) {
  my $subrules = $grammar_dependencies{$rule} || ();
  for my $subrule (keys %$subrules) {
    if ($rule ne $subrule) {
      $missing_count += 1;
      $missing{$rule}{$subrule} = 1;
    }
  }
}

ok($ok_count > 100, "Tested a big subset of MathGrammar");
# print STDERR "Extra: \n", Dumper(\%extra);
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
  my $dir;
  if (!opendir($dir, $directory)) {
    # Can't read directory? Fail (assumed single) test.
    return do_fail($directory, "Couldn't read directory $directory:$!"); }
  else {
    my @dir_contents = sort readdir($dir);
    my $t;
    my @core_tests   = map { (($t = $_) =~ /\.tex$/      ? ("t/parse/$t") : ()); } @dir_contents;
    closedir($dir);
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
