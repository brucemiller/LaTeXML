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
use LaTeXML::Util::Pathname;
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
  if ((pathname_test_s($file) || 0) > 20_000_000) {
    $$self{parser}->set_option('huge', 1); }
  return $$self{parser}->parse_file($file); }

sub parseString {
  my ($self, $string) = @_;
  return $$self{parser}->parse_string($string); }

# Note: This expects only a single node, not a document fragment.
sub parseChunk {
  my ($self, $string) = @_;
  my $xml = $$self{parser}->parse_string($string);
  return $xml && $xml->documentElement; }

#======================================================================
1;
