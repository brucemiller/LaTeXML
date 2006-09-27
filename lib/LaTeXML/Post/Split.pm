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

# NOTE:
#   * how to specify the split? Providing an xpath expression?
#   * How to generate names for the parts?
#   * We need to leave something where we've removed the part?
#     (that can be turned into a TOC?)
#     In particular, any sequence of adjacent nodes.
#   * Need to record up,prev,next!
sub new {
  my($class,%options)=@_;
  my $self = $class->SUPER::new(%options);
  $$self{split_xpath} = $options{split_xpath};
  $self; }

sub process {
  my($self,$doc)=@_;
  my $root = $doc->getDocumentElement;
  my @docs = ($doc);
  my @dates = $doc->findnodes('ltx:date',$root);
  if(my @parts = $self->getSubdocuments($doc)){
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
	push(@toc,['ltx:tocentry',{},['ltx:ref',{class=>'toc',idref=>$part->getAttribute('id')}]]);
	my $idparent = $doc->findnode('ancestor::*[@id]',$part);
	my $dest = $self->getSubdocumentName($doc,$part);
	my $url  = $self->getSubdocumentURL($doc,$part);
	my $next = ( (@parts && @removed && ${$parts[0]} == ${$removed[0]})  ? $parts[0] : undef);
	$doc->addNodes($part,
		       ['ltx:navigation',{},
			['ltx:ref',{class=>'up',idref=>$root->getAttribute('id')}],
			($prev
			 ? (['ltx:ref',{class=>'previous',idref=>$prev->getAttribute('id')}])
			 : ()),
			($next
			 ? (['ltx:ref',{class=>'next',idref=>$next->getAttribute('id')}])
			 : ())],
		       @dates);
	push(@docs,$doc->newFromNode($part, destination=>$dest, url=>$url,
				     parent_id=>($idparent ? $idparent->getAttribute('id'):undef)
				    ));
	$prev = $part; }
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

