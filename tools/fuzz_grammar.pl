#!/usr/bin/env perl
# /=====================================================================\ #
# |  fuzz_grammar                                                       | #
# | enumerate math expressions and test against LaTeXML's MathGrammar   | #
# |=====================================================================| #
# | support tools for LaTeXML:                                          | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

use strict;
use warnings;
use LaTeXML::Common::Config;
use LaTeXML;

my $preamble = "literal:" . <<'EOL';
\documentclass{article}
\usepackage{latexml}
\usepackage{amsmath}

\def\mockarray{\begin{array}{cc} 
  a & b \\
  c & d \end{array}}
\def\mockcases{\begin{cases}{cc} 
  a & b \\
  c & d \end{cases}}
\lxDeclare[role=COMPOSEOP,meaning=compose]{$*$} % no apriori known ?
\def\ATOM{\frac{1}{2}}
\def\UNKNOWN{x}
\def\ID{\infty}
\def\ARRAY{\mockarray}
\def\NUMBER{\pi}
\def\PUNCT{,}
\def\PERIOD{.}
\def\RELOP{<}
\def\LANGLE{\langle}
\def\RANGLE{\rangle}
\def\MIDBAR{\bigm{|}}
\def\LBRACE{\{}
\def\RBRACE{\}}
\def\METARELOP{=}
\def\MODIFIEROP{\mod}
\def\MODIFIER{\pod{3}}
\def\ARROW{\uparrow}
\def\ADDOP{+}
\def\MULOP{\times}
\def\FRACOP{/}
\def\BINOP{\mathbin{@}}
\def\POSTFIX{!}
\def\FUNCTION{\neg}
\def\OPFUNCTION{\arcsin}
\def\TRIGFUNCTION{\sin}
% \def\APPLYOP{\lx@ApplyFunction} % internal mechanism?
\def\COMPOSEOP{*}
\def\SUPOP{\prime}
\def\OPEN{(}
\def\CLOSE{)}
\def\SCRIPTOPEN{\{}
\def\MIDDLE{\bigm{m}}
\def\VERTBAR{||}
\def\SINGLEVERTBAR{|}
\def\BIGOP{\forall}
\def\SUMOP{\sum}
\def\INTOP{\int}
\def\LIMITOP{\lim}
\def\DIFFOP{d}
\def\OPERATOR{\partial}
\def\POSTSUBSCRIPT{_}
\def\POSTSUPERSCRIPT{^}
%\def\FLOATSUBSCRIPT{_} % how do we emulate these? 
%\def\FLOATSUPERSCRIPT{^} % how do we emulate these?
\begin{document}\ensuremathfollows
EOL
my $postamble = "literal:" . '\ensuremathpreceeds\end{document}';
my $config = LaTeXML::Common::Config->new(input_limit => 100, preamble => $preamble, postamble => $postamble, whatsin => 'fragment', post => 0);
my $converter = LaTeXML->new($config);

sub convert_ok {
  my ($source) = @_;
  my $result = $converter->convert("literal:$source");
  return $result && (!$$result{status_code}); }

my @keep   = ();
my $viable = 0;

# DROPPED: APPLYOP
my @terminals = sort qw(ATOM UNKNOWN ID ARRAY NUMBER PUNCT PERIOD RELOP LANGLE RANGLE MIDBAR LBRACE RBRACE METARELOP MODIFIEROP MODIFIER ARROW ADDOP MULOP FRACOP BINOP POSTFIX FUNCTION OPFUNCTION TRIGFUNCTION  COMPOSEOP SUPOP OPEN CLOSE SCRIPTOPEN MIDDLE VERTBAR SINGLEVERTBAR BIGOP SUMOP INTOP LIMITOP DIFFOP OPERATOR POSTSUBSCRIPT POSTSUPERSCRIPT);

# Lexicographically enumerate all formula variants with length 1-10
# turns out the ones at length 10 are 42^10 , aka 17 quadrillion (10^15), we're not holding those into memory or enumerating them in practice....
my $max_len = 5;
# @terminals are global, so is $max_len

open(my $out_fh, ">", "grammatical_expressions.txt") or die "Can't open output file!";

sub enumerate_expressions {
  my ($length, $expression, %used) = @_;
  return if ($length > $max_len);
  for my $terminal (@terminals) {
    next if (($terminal ne 'UNKNOWN') && $used{$terminal});
    my $source    = $expression . ' \\' . $terminal;
    my $printable = $source;
    $printable =~ s/\\//g;
    if (convert_ok($source)) {    # if parsing ok, keep
      $viable++;
      print STDERR "OK $viable: $printable\n";
      print $out_fh $source . "\n"; }
    else {
      print STDERR "FAIL\t: $printable\n";
    }
    # DFS recurse into this example
    $used{$terminal} = 1;
    enumerate_expressions($length + 1, $source, %used);
    $used{$terminal} = 0; }
  return; }

enumerate_expressions(1, '', ());
close($out_fh);

1;
