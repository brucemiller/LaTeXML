# /=====================================================================\ #
# |  LaTeXML::Common::XML::XPath                                        | #
# | XML Parser (wrapper for XML::LibXML                                 | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::XML::XPath;
use strict;
use warnings;
use XML::LibXML::XPathContext;

sub new {
  my ($class, %mappings) = @_;
  my $context = XML::LibXML::XPathContext->new();
  foreach my $prefix (keys %mappings) {
    $context->registerNs($prefix => $mappings{$prefix}); }
  return bless { context => $context }, $class; }

sub registerNS {
  my ($self, $prefix, $url) = @_;
  $$self{context}->registerNs($prefix => $url);
  return; }

sub registerFunction {
  my ($self, $name, $function) = @_;
  $$self{context}->registerFunction($name => $function);
  return; }

sub findnodes {
  my ($self, $xpath, $node) = @_;
  return $$self{context}->findnodes($xpath, $node); }

sub findvalue {
  my ($self, $xpath, $node) = @_;
  return $$self{context}->findvalue($xpath, $node); }

#======================================================================
1;
