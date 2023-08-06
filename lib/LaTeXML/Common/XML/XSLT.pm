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
  my $xslt = XML::LibXSLT->new();
  LaTeXML::Common::XML::initialize_catalogs();
  #  LaTeXML::Common::XML::initialize_input_callbacks($xslt,installation_subdir => 'resources/XSLT');
  # Do we still need this logic, if callbacks work?
  if (!ref $stylesheet) {
    $stylesheet = LaTeXML::Common::XML::Parser->new()->parseFile($stylesheet); }
  #    $stylesheet = $xslt->parse_stylesheet_file($stylesheet); }
  if (ref $stylesheet eq 'XML::LibXML::Document') {
    $stylesheet = $xslt->parse_stylesheet($stylesheet); }
  return bless { stylesheet => $stylesheet }, $class; }

sub transform {
  my ($self, $document, %params) = @_;
  return $$self{stylesheet}->transform($document, %params); }

sub register_function {
  my ($self, $uri, $name, $subref) = @_;
  return $$self{stylesheet}->register_function($uri, $name, $subref); }

#======================================================================
1;
