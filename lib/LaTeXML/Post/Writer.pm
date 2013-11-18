# /=====================================================================\ #
# |  LaTeXML::Post::Writer                                              | #
# | Write file to output                                                | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post::Writer;
use strict;
use warnings;
use LaTeXML::Util::Pathname;
use LaTeXML::Common::XML;
use LaTeXML::Post;
use base qw(LaTeXML::Post::Processor);
use Encode;

sub new {
  my ($class, %options) = @_;
  my $self = $class->SUPER::new(%options);
  $$self{format} = ($options{format} || 'xml');
  $$self{omit_doctype} = 1 if $options{omit_doctype};
  $$self{is_html}      = 1 if $options{is_html};
  return $self; }

sub process {
  my ($self, $doc, $root) = @_;

  my $xmldoc = $doc->getDocument;
  $doc->getDocument->removeInternalSubset if $$self{omit_doctype};

  $root->removeAttribute('xml:id')
    if ($root->getAttribute('xml:id') || '') eq 'TEMPORARY_DOCUMENT_ID';

  my $string = ($$self{is_html} ? $xmldoc->toStringHTML : $xmldoc->toString(1));

  if (my $destination = $doc->getDestination) {
    my $destdir = $doc->getDestinationDirectory;
    pathname_mkdir($destdir)
      or return Fatal('I/O', $destdir, undef, "Couldn't create directory '$destdir'",
      "Response was: $!");
    my $OUT;
    open($OUT, '>', $destination)
      or return Fatal('I/O', $destdir, undef, "Couldn't write '$destination'", "Response was: $!");
    print $OUT $string;
    close($OUT); }
  else {
    print $string; }
  return $doc; }

# ================================================================================
1;

