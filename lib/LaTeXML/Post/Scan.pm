# /=====================================================================\ #
# |  LaTeXML::Post::Scan                                                | #
# | Scan for ID's etc                                                   | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Post::Scan;
use strict;
use LaTeXML::Util::Pathname;
use XML::LibXML;
use charnames qw(:full);
use base qw(LaTeXML::Post);

# NOTE: This module is one that probably needs a lot of customizability.

our $PILCROW = "\N{PILCROW SIGN}";
our $SECTION = "\N{SECTION SIGN}";
our %TYPEPREFIX = 
  (equation     =>'Eq.',
   equationmix  =>'Eq.',
   equationgroup=>'Eq.',
   figure       =>'Fig.',
   table        =>'Tab.',
   chapter      =>'Ch.',
   part         =>'Pt.',
   section      =>$SECTION,
   subsection   =>$SECTION,
   subsubsection=>$SECTION,
   paragraph    =>$PILCROW,
   subparagraph =>$PILCROW,
   para         =>'p'
 );

sub new {
  my($class,%options)=@_;
  my $self = $class->SUPER::new(%options);
  $$self{db}=$options{db};

  $$self{handlers}{mainpage}      = \&section_handler;
  $$self{handlers}{document}      = \&section_handler;
  $$self{handlers}{authorbio}     = \&section_handler;
  $$self{handlers}{bibliography}  = \&section_handler;
  $$self{handlers}{index}         = \&section_handler;
  $$self{handlers}{chapter}       = \&section_handler;
  $$self{handlers}{section}       = \&section_handler;
  $$self{handlers}{subsection}    = \&section_handler;
  $$self{handlers}{subsubsection} = \&section_handler;
  $$self{handlers}{paragraph}     = \&section_handler;
  $$self{handlers}{sidebar}       = \&section_handler;


#  elsif($tag =~ /^(para|itemize|enumerate|description|item)$/){ # Unnumbered, but ID'd nodes.
  $$self{handlers}{table}         = \&labelled_handler;
  $$self{handlers}{figure}        = \&labelled_handler;
  $$self{handlers}{equation}      = \&labelled_handler;
  $$self{handlers}{equationmix}   = \&labelled_handler;
  $$self{handlers}{equationgroup} = \&labelled_handler;
  $$self{handlers}{bibitem}       = \&bibitem_handler;
#  elsif($tag eq 'metadata'){
  $$self{handlers}{indexmark}     = \&index_handler;
  $$self{handlers}{ref}           = \&ref_handler;
  $$self{handlers}{cite}          = \&ref_handler;

#  elsif($tag eq 'declare'){
#  elsif($tag eq 'mark'){
#  elsif($tag eq 'origref'){ 
#  elsif($tag eq 'XMath'){
#  elsif($tag eq 'graphics'){	# Check if we need a Magnified figure page.
#  elsif($tag eq 'picture'){	# Check if we need a Magnified figure page.


  $self; }

sub process {
  my($self,$doc)=@_;
  my $root = $doc->getDocumentElement;
  $self->scan($doc,$root, $$doc{parent_id});
  $self->Progress("Scanned; DBStatus: ".$$self{db}->status);
  $doc; }


sub scan {
  my($self,$doc,$node,$parent_id)=@_;
  my $tag = $node->localname;
  my $handler = $$self{handlers}{$tag} || \&default_handler;
  my $id = &$handler($self,$doc,$node,$tag,$parent_id);
  local $::FOO = ($tag eq 'section' ? $id : $::FOO);
  foreach my $child ($node->childNodes){
    if($child->nodeType == XML_ELEMENT_NODE){
      $self->scan($doc,$child,$id || $parent_id); }}
}


sub inPageID {
  my($self,$doc,$id)=@_;
  my $baseid = $doc->getDocumentElement->getAttribute('id');
  my ($relid) = $id =~ /^\Q$baseid\E\.(.*)$/;
  ($relid || $id); }

sub default_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  if(my $id = $node->getAttribute('id')){
    if(my $label = $node->getAttribute('label')){
      $$self{db}->register("LABEL:$label",id=>$id); }
    # ($url,$store_page,$add_links) = $self->compute_location($node,$id,$parent);
    $$self{db}->register("ID:$id",
			 type=>$tag,
			 parent=>$parent_id,
			 url=>$doc->getURL, fragid=>$self->inPageID($doc,$id));
    $id; }
}

sub section_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  if(my $id = $node->getAttribute('id')){
    if(my $label = $node->getAttribute('label')){
      $$self{db}->register("LABEL:$label",id=>$id); }
    # ($url,$store_page,$add_links) = $self->compute_location($node,$id,$parent);
    my ($title)=$doc->findnodes('ltx:toctitle | ltx:title',$node);
    my $refnum = $node->getAttribute('refnum');
    my $titlestring;
    if($title){
      $titlestring = (ref $title ? $title->textContent : $title);
      $titlestring = $refnum.'. '.$titlestring if $refnum;
      $titlestring = $TYPEPREFIX{$tag}.$titlestring if $TYPEPREFIX{$tag};
      my ($p,$ps) = ($parent_id);
      while($p && ($p=$$self{db}->lookup("ID:$p")) && !($ps=$p->getValue('titlestring'))){
	$p = $p->getValue('parent'); }
      $titlestring .= ' in '.$ps if $ps; }

    $$self{db}->register("ID:$id",
			 type=>$tag,
			 parent=>$parent_id,
			 url=>$doc->getURL, fragid=>$self->inPageID($doc,$id),
			 refnum=>$refnum,
#		      in_toc=>1, toc_embedded=>($tag eq 'part'),
#		      stub=>($node->getAttribute('stub')? 1: undef),
			 title=>$title,
			 titlestring=>$titlestring);
    $id; }
}

sub labelled_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  if(my $id = $node->getAttribute('id')){
    if(my $label = $node->getAttribute('label')){
      $$self{db}->register("LABEL:$label",id=>$id); }
    # ($url,$store_page,$add_links) = $self->compute_location($node,$id,$parent);
    my $refnum = $node->getAttribute('refnum');
    my $titlestring;
    if($refnum){
      $titlestring = $refnum;
      $titlestring = $TYPEPREFIX{$tag}.$titlestring if $TYPEPREFIX{$tag};
      my ($p,$ps) = ($parent_id);
      while($p && ($p=$$self{db}->lookup("ID:$p")) && !($ps=$p->getValue('titlestring'))){
	$p = $p->getValue('parent'); }
      $titlestring .= ' in '.$ps if $ps; }

    $$self{db}->register("ID:$id",
			 type=>$tag,
			 parent=>$parent_id,
			 url=>$doc->getURL, fragid=>$self->inPageID($doc,$id),
			 refnum=>$refnum,
			 titlestring=>$titlestring);
    $id; }
}

sub ref_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
#  $$self{db}->register("LABEL:$label",?
  undef; }

sub index_handler {}

sub bibitem_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  if(my $id = $node->getAttribute('id')){
    if(my $key = $node->getAttribute('key')){
      $$self{db}->register("BIBLABEL:$key",id=>$id); }
    # ($url,$store_page,$add_links) = $self->compute_location($node,$id,$parent);
    my ($title)=$doc->findnodes('ltx:tag',$node);
    my $titlestring;
    if($title){
      $titlestring = (ref $title ? $title->textContent : $title);
      my ($p,$ps) = ($parent_id);
      while($p && ($p=$$self{db}->lookup("ID:$p")) && !($ps=$p->getValue('titlestring'))){
	$p = $p->getValue('parent'); }
      $titlestring .= ' in '.$ps if $ps; }

    $$self{db}->register("ID:$id",
			 type=>$tag,
			 parent=>$parent_id,
			 url=>$doc->getURL, fragid=>$self->inPageID($doc,$id),
			 title=>$title,
			 titlestring=>$titlestring);
    $id; }
}

# ================================================================================

## sub abbreviate {
##  my($string)=@_;
##  $string = $string->cloneNode(1)->toString if $string && ref $string;
##  $string =~ s/ and / &amp; /g if $string;
##  $XMLParser->parse_xml_chunk($string); }

sub cleanIndexKey {
  my($key)=@_;
  $key = $key->toString;
  $key =~ s/[^a-zA-Z0-9]//g;
  $key =~ tr|A-Z|a-z|;
  $key; }

# ================================================================================
#  if($tag =~ /^(mainpage|document|authorbio)$/){ # Arbitrary top-level documents
#  elsif($tag =~ /^(bibliography)$/){
#  elsif($tag =~ /^(chapter|part|section|subsection|subsubsection|paragraph)$/){
#  elsif($tag eq 'sidebar'){
#  elsif($tag =~ /^(para|itemize|enumerate|description|item)$/){ # Unnumbered, but ID'd nodes.
#  elsif($tag =~ /^(table|figure)$/){
#  elsif($tag =~ /^(equation|equationmix|equationgroup)$/){
#  elsif($tag eq 'metadata'){
#  elsif($tag eq 'bibitem'){
#  elsif($tag eq 'index'           ){
#  elsif($tag eq 'ref'){
#  elsif($tag eq 'cite'){
#  elsif($tag eq 'declare'){
#  elsif($tag eq 'mark'){
#  elsif($tag eq 'origref'){ 
#  elsif($tag eq 'XMath'){
#  elsif($tag eq 'graphics'){	# Check if we need a Magnified figure page.
#  elsif($tag eq 'picture'){	# Check if we need a Magnified figure page.
# ================================================================================
1;

