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
$regularized_log =~ s/\:\s+\|\n\s*\|\s+\|\[/\: \[/g;

my @log_lines = split("\n", $regularized_log);

my %aimed_to_cover = (
  'AnyOp' => {
    'OPERATOR'    => 1,
    'addScripts'  => 1,
    'preScripted' => 1
  },
  'Expression' => {
    'anyOpIsolator' => 1,
    'punctExpr'     => 1
  },
  'aBarearg' => {
    'addArgs'        => 1,
    'addTrigFunArgs' => 1
  },
  'aSuperscri' => {
    'AnyOp'      => 1,
    'Expression' => 1
  },
  'aTrigBarea' => {
    'addOpFunArgs' => 1
  },
  'addArgs' => {
    'APPLYOP' => 1,
    'barearg' => 1
  },
  'addExpress' => {
    'MODIFIER' => 1
  },
  'addScripts' => {
    'addScripts' => 1
  },
  'argPunct' => {
    'MIDDLE'  => 1,
    'VERTBAR' => 1
  },
  'bigop' => {
    'BIGOP'  => 1,
    'DIFFOP' => 1,
    'INTOP'  => 1
  },
  'doubtArgs' => {
    'forbidArgs' => 1
  },
  'extendArgu' => {
    'Formula'        => 1,
    'METARELOP'      => 1,
    'extendArgument' => 1,
    'relopExpr'      => 1
  },
  'factorOpen' => {
    'preScripted' => 1
  },
  'inpreScrip' => {
    'FLOATSUBSCRIPT' => 1
  },
  'makeCompos' => {
    'addOpFunArgs'   => 1,
    'addTrigFunArgs' => 1
  },
  'maybeArgs' => {
    'APPLYOP'     => 1,
    'requireArgs' => 1
  },
  'maybeEvalA' => {
    'POSTSUPERSCRIPT' => 1,
    'moreFactors'     => 1
  },
  'moreBarear' => {
    'MulOp' => 1
  },
  'moreIntOpA' => {
    'MulOp' => 1
  },
  'moreOpArgF' => {
    'MulOp' => 1
  },
  'nestOperat' => {
    'OPFUNCTION' => 1
  },
  'preScripte' => {
    'ATOM_OR_ID' => 1,
    'bigop'      => 1
  },
  'requireArg' => {
    'Argument'      => 1,
    'OPEN'          => 1,
    'balancedClose' => 1
  }
);

my %newly_covered       = ();
my %tested_dependencies = ();
for my $line (@log_lines) {
  if ($line =~ /(\w+)\s*\|(?:(?:\>\>Matched (?:subrule|production))|(?:\(consumed))\:\s*\[\s*(\w+)/) {
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
