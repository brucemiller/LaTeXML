# /=====================================================================\ #
# |  LaTeXML::Post::MathML::Content                                     | #
# | MathML generator for LaTeXML                                        | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post::MathML::Content;
use strict;
use warnings;
use base qw(LaTeXML::Post::MathML);

sub convertNode {
  my ($self, $doc, $xmath, $style) = @_;
  return $self->cmml_top($xmath); }

sub getEncodingName {
  return 'MathML-Content'; }

sub rawIDSuffix {
  return '.cmml'; }

#================================================================================
1;
