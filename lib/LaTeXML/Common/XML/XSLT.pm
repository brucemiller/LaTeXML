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
use LaTeXML::Common::Error;
use URI;
use URI::Escape;
use XML::LibXSLT;

sub new {
  my ($class, $stylesheet) = @_;
  my $xslt = XML::LibXSLT->new();
  LaTeXML::Common::XML::initialize_catalogs();
  #  LaTeXML::Common::XML::initialize_input_callbacks($xslt,installation_subdir => 'resources/XSLT');
  # Do we still need this logic, if callbacks work?
  my $input_callbacks = XML::LibXML::InputCallback->new();
  $input_callbacks->register_callbacks([sub { RecordInput($_[0] =~ m/^file:/i ? URI->new($_[0])->file : $_[0]); return 0; }, undef, undef, undef]);
  $xslt->input_callbacks($input_callbacks);

  if (!ref $stylesheet) {
    $stylesheet = LaTeXML::Common::XML::Parser->new()->parseFile($stylesheet); }
  #    $stylesheet = $xslt->parse_stylesheet_file($stylesheet); }
  if (ref $stylesheet eq 'XML::LibXML::Document') {
    $stylesheet = $xslt->parse_stylesheet($stylesheet); }
  return bless { stylesheet => $stylesheet }, $class; }

sub transform {
  my ($self, $document, %params) = @_;
  return $$self{stylesheet}->transform($document, %params); }

sub security_callbacks {
  my ($self, $security) = @_;
  return $$self{stylesheet}->security_callbacks($security); }

#======================================================================
1;
