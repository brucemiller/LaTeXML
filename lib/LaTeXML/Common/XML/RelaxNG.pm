# /=====================================================================\ #
# |  LaTeXML::Common::XML::RelaxNG                                      | #
# | wrapper for XML::LibXML                                             | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::XML::RelaxNG;
use strict;
use warnings;
use XML::LibXML;
use LaTeXML::Util::Pathname;

# Note: XML::LibXML::RelaxNG->new(...) takes
#  location=>$filename_or_url;
#  string=>$schemastring
#  DOM=>$doc

# options: nocatalogs, searchpaths

# Create a Wrapper for a RelaxNG,
# containing the XML document representing the schema
# defering converting it to an actual RelaxNG object.
sub new {
  my ($class, $name, %options) = @_;
  LaTeXML::Common::XML::initialize_catalogs();
  my $xmlparser = LaTeXML::Common::XML::Parser->new();
  my $schemadoc;
  $name .= ".rng" unless $name =~ /\.rng$/;
  # First, try to load directly, in case it's found via libxml's catalogs...
  # But be careful calling C library; its failures are harder to trap w/eval
  if (!$options{nocatalogs}) {
    $schemadoc = eval {
      no warnings 'all';
      local $SIG{'__DIE__'} = undef;
      $xmlparser->parseFile($name); }; }

  if (!$schemadoc) {
    if (my $path = pathname_find($name, paths => $options{searchpaths} || ['.'],
        types               => ['rng'],                  # Eventually, rnc?
        installation_subdir => 'resources/RelaxNG')) {
      #  Hopefully, just a file, not a URL?
      $schemadoc = $xmlparser->parseFile($path); }
    else {
      return;                                            # ???
    } }
  return bless { schemadoc => $schemadoc }, $class; }

sub validate {
  my ($self, $document) = @_;
  # Lazy conversion of the Schema's XML doc into an actual RelaxNG object.
  if (!$$self{schema} && $$self{schemadoc}) {
    $$self{schema} = XML::LibXML::RelaxNG->new(DOM => $$self{schemadoc}); }
  return $$self{schema}->validate($document); }

# This returns the root element of the XML document representing the schema!
sub documentElement {
  my ($self) = @_;
  return $$self{schemadoc}->documentElement; }

sub URI {
  my ($self) = @_;
  return $$self{schemadoc}->URI; }

#======================================================================
1;
