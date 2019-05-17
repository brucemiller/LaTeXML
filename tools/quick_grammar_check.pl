#!/usr/bin/env perl
# /=====================================================================\ #
# |  quick_grammar_check                                                | #
# | convenience tool for checking grammar rules used in a formula parse | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

use warnings;
use strict;
use Test::More;
use Data::Dumper;

use LaTeXML;
use LaTeXML::MathParser;
use LaTeXML::Common::Config;

local $Data::Dumper::Sortkeys = 1;
local $::RD_TRACE             = 1;

my $opts = LaTeXML::Common::Config->new(post => 0, whatsout => "math", whatsin => "math", preload => ["latexml.sty"]);
my $converter = LaTeXML->get_converter($opts);
$converter->prepare_session($opts);

my $source          = "literal:" . $ARGV[0];
my $response        = $converter->convert($source);
my $regularized_log = $$response{log};
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
  'parent rule aimed to be covered by input formula' => {
    'child rule under parent'});

my %newly_covered       = ();
my %tested_dependencies = ();

my $prev_line = '';
for my $line (@log_lines) {
  if ($line =~ /(\w+)\s*\|(?:(?:\>\>(?:\.*)Matched(?:\(keep\))? (?:subrule|production))|(?:\(consumed))\:\s*\[\s*(\w+|\$arg\[\d+\])/) {
    my $parent = $1;
    my $child  = $2;
    if ($child =~ /^\$arg/) {
      if ($prev_line =~ /^\s*\d+\|\s*(\w+)\s*\|/) {
        $child = $1;
      }
    }
    if ($parent ne $child) {
      if ($aimed_to_cover{$parent}{$child}) {
        $newly_covered{$parent}{$child} = 1;
      } else {
        $tested_dependencies{$parent}{$child} = 1;
      }
    }
    $prev_line = $line;
  }
}

print STDERR "Known covered: \n", Dumper(\%tested_dependencies), "\n";
print STDERR "Newly covered: \n", Dumper(\%newly_covered);
print STDERR $$response{status}, "\n";

1;
