# /=====================================================================\ #
# |  LaTeXML::Common::XML::XSLT                                         | #
# | wrapper for XML::LibXML                                             | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::XML::XSLT;
use strict;
use warnings;
use XML::LibXSLT;

sub new {
  my ($class, $stylesheet) = @_;
  LaTeXML::Common::XML::initialize_catalogs();
  if (!ref $stylesheet) {
    $stylesheet = LaTeXML::Common::XML::Parser->new()->parseFile($stylesheet); }
  if (ref $stylesheet eq 'XML::LibXML::Document') {
    $stylesheet = XML::LibXSLT->new()->parse_stylesheet($stylesheet); }
  return bless { stylesheet => $stylesheet }, $class; }

sub transform {
  my ($self, $document, %params) = @_;
  return $$self{stylesheet}->transform($document, %params); }

#======================================================================
1;
