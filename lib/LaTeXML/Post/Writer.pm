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
use LaTeXML::Util::Pathname;
use XML::LibXML;
use base qw(LaTeXML::Post);
use Encode;

sub new {
  my($class,%options)=@_;
  my $self = $class->SUPER::new(%options);
  $$self{format} = ($options{format}||'xml');
  $$self{omit_doctype}=1 if $options{omit_doctype};
  $self; }

sub process {
  my($self,$doc)=@_;

  my $xmldoc = $doc->getDocument;
  $doc->getDocument->removeInternalSubset if $$self{omit_doctype};

  my $root = $xmldoc->documentElement;
  $root->removeAttribute('id')
    if ($root->getAttribute('id')||'') eq  'TEMPORARY_DOCUMENT_ID';

#  my $string = ($$self{format} eq 'html' ? $xmldoc->toStringHTML : $xmldoc->toString(1));
  my $string;
  if($$self{format} eq 'html'){
    $string = $xmldoc->toStringHTML;
#    # Bug in LibXML?  This is probably even dangerous ??
#    if($doc->getDocument->encoding =~ /utf-?8/i){
#      $string = Encode::decode_utf8($string); }
  }
  else {
    $string =  $xmldoc->toString;}

  if(my $destination = $doc->getDestination){
    $self->Progress("Writing $destination");
    pathname_mkdir($doc->getDestinationDirectory)
      or return die("Couldn't create directory ".$doc->getDestinationDirectory.": $!");
#    open(OUT,">:utf8",$destination)
    open(OUT,">",$destination)
      or return die("Couldn't write $destination: $!");
    print OUT $string;
    close(OUT); }
  else {
    print $string; }
  $doc; }

# NOT USED, but would go something like this...

# Returns a new document with namespaces normalized.
# Should ultimately be incorporated in libxml2
# (and of course, done correctly), and bound in XML::LibXML
sub normalizeNS {
  my($doc)=@_;
return $doc;
  my $XMLParser = XML::LibXML->new();
  # KLUDGE: The only namespace cleanup available right now
  # in libxml2 is during parsing!! So, we write to string & reparse!
  # (C14N is a bit too extreme for our purposes)
  # Obviously inefficent (but amazingly fast!)
  $XMLParser->clean_namespaces(1);
  $XMLParser->parse_string($doc->toString);
}
# ================================================================================
1;

