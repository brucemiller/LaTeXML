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
use LaTeXML::Common::XML;
use base qw(LaTeXML::Post);

# NOTE: This module is one that probably needs a lot of customizability.
sub new {
  my($class,%options)=@_;
  my $self = $class->SUPER::new(%options);
  $$self{db}=$options{db};
  $$self{handlers}={};
  $self->registerHandler('ltx:document'      => \&section_handler);
  $self->registerHandler('ltx:bibliography'  => \&section_handler);
  $self->registerHandler('ltx:index'         => \&section_handler);
  $self->registerHandler('ltx:part'          => \&section_handler);
  $self->registerHandler('ltx:chapter'       => \&section_handler);
  $self->registerHandler('ltx:section'       => \&section_handler);
  $self->registerHandler('ltx:appendix'      => \&section_handler);
  $self->registerHandler('ltx:subsection'    => \&section_handler);
  $self->registerHandler('ltx:subsubsection' => \&section_handler);
  $self->registerHandler('ltx:paragraph'     => \&section_handler);
  $self->registerHandler('ltx:subparagraph'  => \&section_handler);

  $self->registerHandler('ltx:table'         => \&captioned_handler);
  $self->registerHandler('ltx:figure'        => \&captioned_handler);
  $self->registerHandler('ltx:listing'       => \&captioned_handler);

  $self->registerHandler('ltx:equation'      => \&labelled_handler);
  $self->registerHandler('ltx:equationgroup' => \&labelled_handler);
  $self->registerHandler('ltx:theorem'       => \&labelled_handler);
  $self->registerHandler('ltx:anchor'        => \&anchor_handler);

  $self->registerHandler('ltx:bibitem'       => \&bibitem_handler);
  $self->registerHandler('ltx:bibentry'      => \&bibentry_handler);
  $self->registerHandler('ltx:indexmark'     => \&indexmark_handler);
  $self->registerHandler('ltx:ref'           => \&ref_handler);
  $self->registerHandler('ltx:bibref'        => \&bibref_handler);

  $self; }

sub registerHandler {
  my($self,$tag,$handler)=@_;
  $$self{handlers}{$tag} = $handler; }

sub process {
  my($self,$doc)=@_;
  my $root = $doc->getDocumentElement;

  # I think we really need an ID here to establish the root node in the DB,
  # even if the document didn't have one originally.
  # And for the common case of a single docucment, we'd like to be silent about it,
  # UNLESS there seem to be multiple documents which would lead to a conflict.
  my $id = $root->getAttribute('xml:id');
  if(! defined $id){
    $id = "Document";
    if(my $preventry = $$self{db}->lookup("ID:$id")){
      if(my $loc = $doc->siteRelativeDestination){
	my $prevloc = $preventry->getValue('location');
	if((defined $prevloc) && ($loc ne $prevloc)){
	  $self->Warn($doc,"Using default ID=\"$id\", "
		      ."but there's an apparent conflict with location $loc and previous $prevloc");}}}
    $root->setAttribute('xml:id'=>$id); }

  $self->scan($doc,$root, $$doc{parent_id});
  $self->Progress($doc,"Scanned; DBStatus: ".$$self{db}->status);
  $doc; }

sub scan {
  my($self,$doc,$node,$parent_id)=@_;
  my $tag = $doc->getQName($node);
  my $handler = $$self{handlers}{$tag} || \&default_handler;
  &$handler($self,$doc,$node,$tag,$parent_id); }

sub scanChildren {
  my($self,$doc,$node,$parent_id)=@_;
  foreach my $child ($node->childNodes){
    if($child->nodeType == XML_ELEMENT_NODE){
      $self->scan($doc,$child,$parent_id); }}}

sub addAsChild {
  my($self,$id,$parent_id)=@_;
  # Find the ancestor that maintains a children list
  while(my $parent = $parent_id && $$self{db}->lookup("ID:$parent_id")){
    if(my $siblings = $parent->getValue('children')){
      $parent->pushNew('children',$id);
      last; }
    else {
      $parent_id = $parent->getValue('parent'); }}}

sub pageID {
  my($self,$doc)=@_;
  $doc->getDocumentElement->getAttribute('xml:id'); }

# Compute a "Fragment ID", ie. an ID based on the given ID,
# but which is potentially shortened so that it need only be
# unique within the given page.
sub inPageID {
  my($self,$doc,$id)=@_;
  my $baseid = $doc->getDocumentElement->getAttribute('xml:id') || '';
  if($baseid eq $id){
    undef; }
  elsif($baseid && ($id =~ /^\Q$baseid\E\.(.*)$/)){
    $1; }
  elsif($$doc{split_from_id} && ($id =~ /^\Q$$doc{split_from_id}\E\.(.*)$/)){
    $1; }
  else {
    $id; }}

sub noteLabels {
  my($self,$node)=@_;
  if(my $id = $node->getAttribute('xml:id')){
    if(my $labels = $node->getAttribute('labels')){
      my @labels= split(' ',$node->getAttribute('labels'));
      foreach my $label (@labels){
	$$self{db}->register($label,id=>$id); }
      [@labels]; }}}

# Clean up a node before insertion into database.
sub cleanNode {
  my($self,$doc,$node)=@_;
  return undef unless $node;
  my $cleaned = $node->cloneNode(1);
  # Remove indexmark (anything else ?)
  map($_->parentNode->removeChild($_), $doc->findnodes('.//ltx:indexmark',$cleaned));
  $cleaned; }

sub default_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  my $id = $node->getAttribute('xml:id');
  if($id){
    $$self{db}->register("ID:$id", type=>$tag, parent=>$parent_id, labels=>$self->noteLabels($node),
			 location=>$doc->siteRelativeDestination,
			 pageid=>$self->pageID($doc), fragid=>$self->inPageID($doc,$id));
    $self->addAsChild($id,$parent_id);  }
  $self->scanChildren($doc,$node,$id || $parent_id); }

sub section_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  my $id = $node->getAttribute('xml:id');
  if($id){
    $$self{db}->register("ID:$id", type=>$tag, parent=>$parent_id,labels=>$self->noteLabels($node),
			 location=>$doc->siteRelativeDestination,
			 pageid=>$self->pageID($doc), fragid=>$self->inPageID($doc,$id),
			 refnum=>$node->getAttribute('refnum'),
			 frefnum=>$node->getAttribute('frefnum'),
			 title=>$self->cleanNode($doc,$doc->findnode('ltx:title',$node)),
			 toctitle=>$self->cleanNode($doc,$doc->findnode('ltx:toctitle',$node)),
			 children=>[],
			 stub=>$node->getAttribute('stub'));
    $self->addAsChild($id,$parent_id);  }
  $self->scanChildren($doc,$node,$id || $parent_id); }

sub captioned_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  my $id = $node->getAttribute('xml:id');
  if($id){
    $$self{db}->register("ID:$id", type=>$tag, parent=>$parent_id,labels=>$self->noteLabels($node),
			 location=>$doc->siteRelativeDestination,
			 pageid=>$self->pageID($doc), fragid=>$self->inPageID($doc,$id),
			 refnum=>$node->getAttribute('refnum'),
			 frefnum=>$node->getAttribute('frefnum'),
			 caption=>$self->cleanNode($doc,
					   $doc->findnode('descendant::ltx:caption',$node)),
			 toccaption=>$self->cleanNode($doc,
					   $doc->findnode('descendant::ltx:toccaption',$node)));
    $self->addAsChild($id,$parent_id);  }
  $self->scanChildren($doc,$node,$id || $parent_id); }

sub labelled_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  my $id = $node->getAttribute('xml:id');
  if($id){
    $$self{db}->register("ID:$id", type=>$tag, parent=>$parent_id,labels=>$self->noteLabels($node),
			 location=>$doc->siteRelativeDestination,
			 pageid=>$self->pageID($doc), fragid=>$self->inPageID($doc,$id),
			 refnum=>$node->getAttribute('refnum'),
			 frefnum=>$node->getAttribute('frefnum')); 
    $self->addAsChild($id,$parent_id); }
  $self->scanChildren($doc,$node,$id || $parent_id); }

sub anchor_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  my $id = $node->getAttribute('xml:id');
  if($id){
    $$self{db}->register("ID:$id", type=>$tag, parent=>$parent_id,labels=>$self->noteLabels($node),
			 location=>$doc->siteRelativeDestination,
			 pageid=>$self->pageID($doc), fragid=>$self->inPageID($doc,$id),
			 title=>$node->cloneNode(1)->childNodes, # document fragment?
			 refnum=>$node->getAttribute('refnum'),
			 frefnum=>$node->getAttribute('frefnum')); 
    $self->addAsChild($id,$parent_id); }
  $self->scanChildren($doc,$node,$id || $parent_id); }

sub ref_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  my $id = $node->getAttribute('xml:id');
  if(my $label = $node->getAttribute('labelref')){ # Only record refs of labels
    if( ($node->getAttribute('class')||'') !~ /\bcitedby\b/){ # and don't count citedby referencees either
      my $entry = $$self{db}->register($label);
      $entry->noteAssociation(referrers=>$parent_id); }}
  # Usually, a ref won't YET have content; but if it does, we should scan it.
  $self->default_handler($doc,$node,$tag,$parent_id); }

sub bibref_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  if( ($node->getAttribute('class')||'') !~ /\bcitedby\b/){
    my $keys = $node->getAttribute('bibrefs');
    foreach my $bibkey (split(',',$keys)){
      if($bibkey){
	my $entry = $$self{db}->register("BIBLABEL:$bibkey");
	$entry->noteAssociation(referrers=>$parent_id); }}}
  # Usually, a bibref will have, at most, some ltx:bibphrase's; should be scanned.
  $self->default_handler($doc,$node,$tag,$parent_id); }

# Note that index entries get stored in simple form; just the terms & location.
# They will be turned into a tree, sorted, possibly permuted, whatever, by MakeIndex.
# [the only content of indexmark should be un-marked up(?) don't recurse]
sub indexmark_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  # Get the actual phrases, and any see_also phrases (if any)
  my @phrases = $doc->findnodes('ltx:indexphrase',$node);
  my @seealso = $doc->findnodes('ltx:indexsee',$node);
  my $key = join(':','INDEX',map($_->getAttribute('key'),@phrases));
  my $entry = $$self{db}->lookup($key)
    || $$self{db}->register($key,phrases=>[@phrases],see_also=>[]);
  if(@seealso){
    $entry->pushNew('see_also', @seealso); }
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
  my $id = $node->getAttribute('xml:id');
  if($id){
    if(my $key = $node->getAttribute('key')){
      $$self{db}->register("BIBLABEL:$key",id=>$id); }
    $$self{db}->register("ID:$id", type=>$tag, parent=>$parent_id,
			 location=>$doc->siteRelativeDestination,
			 pageid=>$self->pageID($doc), fragid      =>$self->inPageID($doc,$id),
			 authors     =>$doc->findnode('ltx:bibtag[@role="authors"]',$node),
			 fullauthors =>$doc->findnode('ltx:bibtag[@role="fullauthors"]',$node),
			 year        =>$doc->findnode('ltx:bibtag[@role="year"]',$node),
			 number      =>$doc->findnode('ltx:bibtag[@role="number"]',$node),
			 refnum      =>$doc->findnode('ltx:bibtag[@role="refnum"]',$node),
			 title       =>$doc->findnode('ltx:bibtag[@role="title"]',$node),
			 keytag      =>$doc->findnode('ltx:bibtag[@role="key"]',$node),
			 typetag     =>$doc->findnode('ltx:bibtag[@role="bibtype"]',$node)); }
  $self->scanChildren($doc,$node,$id || $parent_id); }

# For a bibentry, we'll only store the citation key, so we know it's there.
sub bibentry_handler {
  my($self,$doc,$node,$tag,$parent_id)=@_;
  my $id = $node->getAttribute('xml:id');
  if($id){
    if(my $key = $node->getAttribute('key')){
      $$self{db}->register("BIBLABEL:$key",id=>$id); }}
## No, let's not scan the content of the bibentry
## until it gets formatted and re-scanned by MakeBibliography.
##  $self->scanChildren($doc,$node,$id || $parent_id); 

## HOWEVER; this ultimately requires formatting the bibliography twice (for complex sites).
## This needs to be reworked!
}


# ================================================================================
1;

