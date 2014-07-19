# /=====================================================================\ #
# |  LaTeXML::Common::XML::Parser                                       | #
# | XML Parser (wrapper for XML::LibXML                                 | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::XML::Parser;
use strict;
use warnings;
use XML::LibXML;

sub new {
  my ($class) = @_;
  my $parser = XML::LibXML->new();
  $parser->validation(0);
  return bless { parser => $parser }, $class; }

sub parseFile {
  my ($self, $file) = @_;
  LaTeXML::Common::XML::initialize_catalogs();
  #  LaTeXML::Common::XML::initialize_input_callbacks($$self{parser});
  return $$self{parser}->parse_file($file); }

sub parseString {
  my ($self, $string) = @_;
  return $$self{parser}->parse_string($string); }

sub parseChunk {
  my ($self, $string) = @_;
  my $hasxmlns = $string =~ /\Wxml:id\W/;
  # print STDERR "\nFISHY!!\n" if $hasxmlns;
  my $xml = $$self{parser}->parse_xml_chunk($string);
  # Simplify, if we get a single node Document Fragment.
  #[which we, apparently, always do]
  if ($xml && (ref $xml eq 'XML::LibXML::DocumentFragment')) {
    my @k = $xml->childNodes;
    $xml = $k[0] if (scalar(@k) == 1); }
  #  $xml = $xml->cloneNode(1);
  ####
  # In 1.58, the prefix for the XML_NS, which should be DEFINED to be "xml"
  # is sometimes unbound, leading to mysterious segfaults!!!
###  if (($xml_libxml_version < 1.59) && $hasxmlns) {
  if (($LaTeXML::Common::XML::xml_libxml_version < 1.59) && $hasxmlns) {
    #print STDERR "Patchup...\n";
    # Re-create all xml:id entrys, hopefully with correct NS!
    # We assume all id are, in fact, xml:id,
    # because we seemingly can't probe the namespace!
    foreach my $attr ($xml->findnodes("descendant-or-self::*/attribute::*[local-name()='id']")) {
      my $element = $attr->parentNode;
      my $id      = $attr->getValue();
      #print STDERR "RESET ID: $id\n";
      $attr->unbindNode();
      $element->setAttributeNS($LaTeXML::Common::XML::XML_NS, 'id', $id); }
    #    print STDERR "\nXML: ".$xml->toString."\n";
  }
  return $xml; }

#======================================================================
1;
