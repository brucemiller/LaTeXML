# /=====================================================================\ #
# |  LaTeXML::Post::Split                                               | #
# | Split documents                                                     | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post::Split;
use strict;
use LaTeXML::Util::Pathname;
use XML::LibXML;
use base qw(LaTeXML::Post);

sub new {
  my($class,%options)=@_;
  my $self = $class->SUPER::new(%options);
  $$self{split_xpath} = $options{split_xpath};
  $self; }

sub process {
  my($self,$doc)=@_;
  my $root = $doc->getDocumentElement;
  my @docs = ($doc);
  my @parts = $self->getSubdocuments($doc);
  @parts = grep($_->parentNode->parentNode,@parts); # Strip out the root node.
  if(@parts){
    $self->Progress("Splitting into ".scalar(@parts)." parts");
    while(@parts){
      my $parent = $parts[0]->parentNode;
      # Remove $part & following siblings.
      my @removed =  ();
      while(my $sib = $parent->lastChild){
	$parent->removeChild($sib);
	unshift(@removed,$sib);
	last if $$sib == ${$parts[0]}; }
      # Build toc from adjacent nodes that are being extracted.
      my @toc = ();
      my $prev = undef;
      while(@parts && @removed && ${$parts[0]} == ${$removed[0]}){
	my $part = shift(@parts);
	shift(@removed);
	my $id = $part->getAttribute('id');
	push(@toc,['ltx:tocentry',{},['ltx:ref',{class=>'toc',show=>'typerefnum title', idref=>$id}]]);
	my $subdoc = $doc->newDocument($part,
				       destination=>$self->getSubdocumentName($doc,$part),
				       url=>$self->getSubdocumentURL($doc,$part));
	push(@docs,$subdoc);
	$subdoc->addNavigation(up      =>$root->getAttribute('id'));
	$subdoc->addNavigation(previous=>$prev->getDocumentElement->getAttribute('id')) if $prev;
	$prev->addNavigation(next=>$id) if $prev;
	$prev = $subdoc; }
      # Finally, add the toc to reflect the consecutive, removed nodes, and add back the remainder
      $doc->addNodes($parent,['ltx:TOC',{},['ltx:toclist',{},@toc]]);
      map($parent->addChild($_),@removed); }}
  @docs; }

sub getSubdocuments {
  my($self,$doc)=@_;
  $doc->findnodes($$self{split_xpath}); }

our $COUNTER=0;

sub getSubdocumentName {
  my($self,$doc,$part)=@_;
  my $name;
  my $baseid = $doc->getDocumentElement->getAttribute('id');
  my $id = $part->getAttribute('id');
  if(my ($relid) = $id =~ /^\Q$baseid\E\.(.*)$/){
    $name = $relid;}
  else {
    $name = "FOO".(++$COUNTER); }
  pathname_make(dir=>$doc->getDestinationDirectory,name=>$name,
		type=>$doc->getDestinationExtension); }

sub getSubdocumentURL {
  my($self,$doc,$part)=@_;
  my $name;
  my $baseid = $doc->getDocumentElement->getAttribute('id');
  my $id = $part->getAttribute('id');
  if(my ($relid) = $id =~ /^\Q$baseid\E\.(.*)$/){
    $name = $relid;}
  else {
    $name = "FOO".(++$COUNTER); }

  my $url = $doc->getURL;
  my($vol,$dir,$fname)=File::Spec->splitpath($url);
  my $ext = ($url =~ /\.([^\.\/]*)$/ ? $1 : undef);

  pathname_make(dir=>($dir||'.'),name=>$name,type=>$ext); }


# ================================================================================
1;

