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
use base qw(LaTeXML::Post);

# NOTE: This module is one that probably needs a lot of customizability.
sub new {
  my($class,%options)=@_;
  my $self = $class->SUPER::new(%options);
  $$self{db}=$options{db};
  $$self{handlers}={};
  $self->registerHandler(mainpage      => \&section_handler);
  $self->registerHandler(document      => \&section_handler);
  $self->registerHandler(bibliography  => \&section_handler);
  $self->registerHandler(index         => \&section_handler);
  $self->registerHandler(chapter       => \&section_handler);
  $self->registerHandler(section       => \&section_handler);
  $self->registerHandler(subsection    => \&section_handler);
  $self->registerHandler(subsubsection => \&section_handler);
  $self->registerHandler(paragraph     => \&section_handler);
  $self->registerHandler(sidebar       => \&section_handler);

  $self->registerHandler(table         => \&labelled_handler);
  $self->registerHandler(figure        => \&labelled_handler);
  $self->registerHandler(equation      => \&labelled_handler);
  $self->registerHandler(equationmix   => \&labelled_handler);
  $self->registerHandler(equationgroup => \&labelled_handler);

  $self->registerHandler(bibitem       => \&bibitem_handler);
  $self->registerHandler(bibentry      => \&bibentry_handler);
  $self->registerHandler(indexmark     => \&indexmark_handler);
  $self->registerHandler(ref           => \&ref_handler);
  $self->registerHandler(bibref        => \&bibref_handler);

  $self->registerHandler(XMath         => \&XMath_handler);
  $self; }

sub registerHandler {
  my($self,$tag,$handler)=@_;
  $$self{handlers}{$tag} = $handler; }

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
  &$handler($self,$doc,$node,$tag,$parent_id); }

sub scanChildren {
  my($self,$doc,$node,$parent_id)=@_;
  foreach my $child ($node->childNodes){
    if($child->nodeType == XML_ELEMENT_NODE){
      $self->scan($doc,$child,$parent_id); }}}

# Compute a "Fragment ID", ie. an ID based on the given ID,
# but which is potentially shortened so that it need only be
# unique within the given page.
sub inPageID {
  my($self,$doc,$id)=@_;
  my $baseid = $doc->getDocumentElement->getAttribute('id') || '';
  if($baseid eq $id){
    undef; }
  elsif($baseid && ($id =~ /^\Q$baseid\E\.(.*)$/)){
    $1; }
  elsif($$doc{split_from_id} && ($id =~ /^\Q$$doc{split_from_id}\E\.(.*)$/)){
    $1; }
  else {
    $id; }}

sub default_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  my $id = $node->getAttribute('id');
  if($id){
    my $label = $node->getAttribute('label');
    $$self{db}->register("LABEL:$label",id=>$id) if $label;
    $$self{db}->register("ID:$id", type=>$tag, parent=>$parent_id, label=>$label,
			 url=>$doc->getURL, fragid=>$self->inPageID($doc,$id)); }
  $self->scanChildren($doc,$node,$id || $parent_id); }

sub section_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  my $id = $node->getAttribute('id');
  if($id){
    my $label = $node->getAttribute('label');
    $$self{db}->register("LABEL:$label",id=>$id) if $label;
    $$self{db}->register("ID:$id", type=>$tag, parent=>$parent_id, label=>$label,
			 url=>$doc->getURL, fragid=>$self->inPageID($doc,$id),
			 refnum=>$node->getAttribute('refnum'),
			 title=>$doc->findnode('ltx:toctitle | ltx:title',$node),
			 stub=>$node->getAttribute('stub')); }
  $self->scanChildren($doc,$node,$id || $parent_id); }

sub labelled_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  my $id = $node->getAttribute('id');
  if($id){
    my $label = $node->getAttribute('label');
    $$self{db}->register("LABEL:$label",id=>$id) if $label;
    $$self{db}->register("ID:$id", type=>$tag, parent=>$parent_id, label=>$label,
			 url=>$doc->getURL, fragid=>$self->inPageID($doc,$id),
			 refnum=>$node->getAttribute('refnum')); }
  $self->scanChildren($doc,$node,$id || $parent_id); }

sub ref_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  if(my $label = $node->getAttribute('labelref')){ # Only record refs of labels
    my $entry = $$self{db}->register("LABEL:$label");
    $entry->noteAssociation(referrers=>$parent_id); }}

sub bibref_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  my $keys = $node->getAttribute('bibrefs');
  foreach my $bibkey (split(',',$keys)){
    my $entry = $$self{db}->register("BIBLABEL:$bibkey");
    $entry->noteAssociation(referrers=>$parent_id); }}

# Note that index entries get stored in simple form; just the terms & location.
# They will be turned into a tree, sorted, possibly permuted, get URL's, whatever,
# by MakeIndex.
sub indexmark_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  my $key = join(':','INDEX',map($_->getAttribute('key'),$doc->findnodes('ltx:indexphrase',$node)));
  my $entry = $$self{db}->register($key);
  $entry->setValues(phrases=>$node) unless $entry->getValue('phrases'); # No dueling
  if(my $seealso = $node->getAttribute('see_also')){
print STDERR "Index Seealso: $key => $seealso\n";
    $entry->noteAssociation(see_also=>$seealso); }
  else {
    $entry->noteAssociation(referrers=>$parent_id=>($node->getAttribute('style') || 'normal')); }}

# Note this bit of perversity:
#  <ltx:bibentry> is a semantic bibliographic entry,
#     as generated from a BibTeX file.
#  <ltx:bibitem> is a formatted bibliographic entry,
#     as generated from an explicit thebibliography environment,
#     or as formatted from a <ltx:bibentry> by MakeBibliography.
# For a bibitem, we'll store the usual info in the DB.
sub bibitem_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  my $id = $node->getAttribute('id');
  if($id){
    if(my $key = $node->getAttribute('key')){
      $$self{db}->register("BIBLABEL:$key",id=>$id); }
    $$self{db}->register("ID:$id", type=>$tag, parent=>$parent_id,
			 url=>$doc->getURL, fragid=>$self->inPageID($doc,$id),
			 names =>$doc->findnode('ltx:bib-citekeys/ltx:cite-names',$node),
			 year  =>$doc->findnode('ltx:bib-citekeys/ltx:cite-year',$node),
			 refnum=>$doc->findnode('ltx:tag',$node),
			 title=>$doc->findnode('ltx:bib-citekeys/ltx:cite-title',$node)); }
  $self->scanChildren($doc,$node,$id || $parent_id); }

# For a bibentry, we'll only store the citation key, so we know it's there.
sub bibentry_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  my $id = $node->getAttribute('id');
  if($id){
    if(my $key = $node->getAttribute('key')){
      $$self{db}->register("BIBLABEL:$key",id=>$id); }}
  $self->scanChildren($doc,$node,$id || $parent_id); }

# Do nothing (particularly, DO NOT note ids/idrefs!)
# Actually, what I want to do is avoid recursion!!!
sub XMath_handler {
}

# ================================================================================
1;

