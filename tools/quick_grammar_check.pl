# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use warnings;
use strict;
use Test::More;
use LaTeXML;
use LaTeXML::MathParser;
local $::RD_TRACE = 1;
use LaTeXML::Common::Config;
use Data::Dumper;
local $Data::Dumper::Sortkeys = 1;

my $opts = LaTeXML::Common::Config->new(post => 0, whatsout => "math", whatsin => "math", preload => ["latexml.sty"]);
my $converter = LaTeXML->get_converter($opts);
$converter->prepare_session($opts);

my $source          = "literal:" . $ARGV[0];
my $response        = $converter->convert($source);
my $regularized_log = $response->{log};
# Preprocess split lines back to single lines, e.g.
# 2|AnythingAn|>>Matched subrule:                    |
#  |          |[modifierFormulae]<< (return value:   |
# -- TO:
# 2|AnythingAn|>>Matched subrule: [modifierFormulae]<< (return value:   |

# Also:
# 13|Expression|>>...Matched(keep) subrule:           |
#   |          |[anyOpIsolator]<< (return value: [0]  |


$regularized_log =~ s/\:\s+\|\n\s*\|\s+\|\[/\: \[/g;

my @log_lines = split("\n", $regularized_log);

my %aimed_to_cover = (
          'AnyOp' => {
                       'preScripted' => 1
                     },
          'maybeArgs' => {
                           'APPLYOP' => 1,
                           'requireArgs' => 1
                         },
          'maybeEvalA' => {
                            'POSTSUPERSCRIPT' => 1,
                            'moreFactors' => 1
                          },
          'moreIntOpA' => {
                            'MulOp' => 1
                          },
          'moreOpArgF' => {
                            'MulOp' => 1
                          },
          'preScripte' => {
                            'ATOM_OR_ID' => 1,
                            'bigop' => 1
                          },
          'requireArg' => {
                            'Argument' => 1,
                            'OPEN' => 1,
                            'balancedClose' => 1
                          }
);

my %newly_covered       = ();
my %tested_dependencies = ();
for my $line (@log_lines) {
  if ($line =~ /(\w+)\s*\|(?:(?:\>\>(?:\.*)Matched(?:\(keep\))? (?:subrule|production))|(?:\(consumed))\:\s*\[\s*(\w+)/) {
    if ($1 ne $2) {
      if ($aimed_to_cover{$1}{$2}) {
        $newly_covered{$1}{$2} = 1;
      } else {
        $tested_dependencies{$1}{$2} = 1;
      }
    }
  }
}
print STDERR "Known covered: \n", Dumper(\%tested_dependencies), "\n";
print STDERR "Newly covered: \n", Dumper(\%newly_covered);
print STDERR $response->{status}, "\n";
