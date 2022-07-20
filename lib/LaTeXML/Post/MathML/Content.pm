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
  my ($self, $doc, $xmath) = @_;
  return { processor => $self, xml => $self->cmml_top($xmath),
    mimetype => 'application/mathml-content+xml' }; }

sub rawIDSuffix {
  return '.cmml'; }

sub canConvert {
  my ($self, $doc, $math) = @_;
  return LaTeXML::Post::MathProcessor::mathIsParsed($doc, $math); }

#================================================================================
1;
