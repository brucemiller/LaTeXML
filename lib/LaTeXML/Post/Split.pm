# /=====================================================================\ #
# |  LaTeXML::Post::Split                                               | #
# | Split documents into pages                                          | #
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
use LaTeXML::Common::XML;
use base qw(LaTeXML::Post);

sub new {
  my($class,%options)=@_;
  my $self = $class->SUPER::new(%options);
  $$self{split_xpath} = $options{split_xpath};
  $$self{splitnaming} = $options{splitnaming};
  $$self{no_navigation} = $options{no_navigation};
  $self; }

sub process {
  my($self,$doc)=@_;
  my $root = $doc->getDocumentElement;
  # RISKY and annoying; to split, we really need an id on the root.
  # Writer will remove it.
  $root->setAttribute('xml:id'=>'TEMPORARY_DOCUMENT_ID') unless $root->hasAttribute('xml:id');

  my @docs = ($doc);
  my @pages = $self->getPages($doc);
  # Weird test: exclude the "whole document" from the list (?)
  @pages = grep($_->parentNode->parentNode,@pages); # Strip out the root node.
  if(@pages){
    $self->Progress($doc,"Splitting into ".scalar(@pages)." pages");
    my $tree = {node=>$root,id=>$root->getAttribute('xml:id'),name=>$doc->getDestination,children=>[]};
    # Group the pages into a tree, in case they are nested.
    my $haschildren={};
    foreach my $page (@pages){
      presortPages($tree,$haschildren,$page); }
    # Work out the destination paths for each page
    $self->prenamePages($doc,$tree,$haschildren);
    # Now, create remove and create documents for each page.
    push(@docs,$self->processPages($doc,@{$$tree{children}}));
    # Add navigation to the sequence.
    if(!$$self{no_navigation}){
      my $rootid = $doc->getDocumentElement->getAttribute('xml:id');
      $doc->addNavigation(start=>$rootid) if $rootid;
      for(my $i=0; $i<$#docs; $i++){
	$docs[$i]->addNavigation(next=>$docs[$i+1]->getDocumentElement->getAttribute('xml:id'));
	$docs[$i+1]->addNavigation(previous=>$docs[$i]->getDocumentElement->getAttribute('xml:id')); }}
  }
  @docs; }

# Get the nodes in the document that will be separate "pages".
# Subclass can override, if needed.
sub getPages {
  my($self,$doc)=@_;
  $doc->findnodes($$self{split_xpath}); }

# Sort the pages into a tree, in case some pages are children of others
# If a page contains NOTHING BUT child pages (except frontmatter),
# we could just merge that page as a level in it's containing TOC instead of a document.???
sub presortPages {
  my($tree,$haschildren,$page)=@_;
  my $nextlevel;
  if(($nextlevel = $$tree{children}[-1]) && (isDescendant($page, $$nextlevel{node}))){
    presortPages($nextlevel,$haschildren,$page); }
  else {
    $$haschildren{$$tree{node}->localname}=1; # Wrong key for this!?!
    push(@{$$tree{children}},
	 {node=>$page,upid=>$$tree{id}, id=>$page->getAttribute('xml:id'),parent=>$tree,children=>[]}); }}

# Is $node an descendant of $possibleparent?
# Probably even belongs somewhere else??
sub isDescendant {
  my($node,$possibleparent)=@_;
  do {
    $node = $node->parentNode;
    return 1 if $node && ($$node == $$possibleparent); }}

# Get destination pathnames for each page.
sub prenamePages {
  my($self,$doc,$tree,$haschildren)=@_;
  foreach my $entry (@{$$tree{children}}){
    $$entry{name}=$self->getPageName($doc,$$entry{node},$$tree{node},$$tree{name},
					   $$haschildren{$$entry{node}->localname});
    $self->prenamePages($doc,$entry,$haschildren); }
}

# Process a sequence of page entries, removing them and generating documents for each.
sub processPages {
  my($self,$doc,@entries)=@_;
  my $rootid = $doc->getDocumentElement->getAttribute('xml:id');
  my @docs=();
  while(@entries){
    my $parent = $entries[0]->{node}->parentNode;
    # Remove $page & ALL following siblings (backwards).
    my @removed =  ();
    while(my $sib = $parent->lastChild){
      $parent->removeChild($sib);
      unshift(@removed,$sib);
      last if $$sib == ${$entries[0]->{node}}; }
    # Build toc from adjacent nodes that are being extracted.
    my $hit_appendices=0;
    my @toc = ();
    my @apptoc = ();
    # Process a sequence of adjacent pages; these will go into the same TOC.
    while(@entries && @removed && ${$entries[0]->{node}} == ${$removed[0]}){
      my $entry = shift(@entries);
      my $page = $$entry{node};
      $doc->removeNodes(shift(@removed));
      my $id = $page->getAttribute('xml:id');
      my $tocentry =['ltx:tocentry',{},
		     ['ltx:ref',{class=>'toc', idref=>$id, show=>'fulltitle'}]];
      $hit_appendices |= $page->localname =~ /^appendix/;
      if($hit_appendices){
	push(@apptoc,$tocentry); }
      else {
	push(@toc,$tocentry); }
      # Due to the way document building works, we remove & process children pages
      # BEFORE processing this page.
      my @childdocs = $self->processPages($doc,@{$$entry{children}});
      my $subdoc = $doc->newDocument($page,destination=>$$entry{name},
				     parentDocument=>$doc,parent_id=>$$entry{upid});
      $subdoc->addNavigation(start=>$rootid) if $rootid;
      $subdoc->addNavigation(up=>$$entry{upid});
      push(@docs,$subdoc,@childdocs); }
    # Finally, add the toc to reflect the consecutive, removed nodes, and add back the remainder
    $doc->addNodes($parent,['ltx:TOC',{},['ltx:toclist',{},@toc]]) if @toc;
    $doc->addNodes($parent,['ltx:TOC',{class=>'appendixtoc'},['ltx:toclist',{},@apptoc]])
      if @apptoc; 
    map($parent->addChild($_),@removed); }
  @docs; }

our $COUNTER=0;
sub getPageName {
  my($self,$doc,$page,$parent,$parentpath,$recursive)=@_;
  my $asdir;
  my $naming = $$self{splitnaming};
  my $attr = ($naming =~ /^id/ ? 'xml:id'
	      : ($naming =~ /^label/ ? 'labels' : undef));
  my $name  = $page->getAttribute($attr);
  $name =~ s/\s+.*// if $name;		# Truncate in case multiple labels.
  $name =~ s/^LABEL:// if $name;
  if(!$name){
    if(($attr eq 'labels') && ($name=$page->getAttribute('xml:id'))){
      $self->Warn($doc,$doc->getQName($page)." has no $attr attribute for pathname; using id=$name"); 
      $attr='xml:id'; }
    else {
      $self->Warn($doc,$doc->getQName($page)." has no $attr attribute for pathname");
      $name="FOO".++$COUNTER; }}
  if($naming =~ /relative$/){
    my $pname = $parent->getAttribute($attr);
    if($pname && $name =~ /^\Q$pname\E(\.|_|:)+(.*)$/){
      $name = $2; }
    $asdir=$recursive; }
  $name =~ s/:+/_/g;
  if($asdir){
    pathname_make(dir=>pathname_concat(pathname_directory($parentpath),$name),
		  name=>'index',
		  type=>$doc->getDestinationExtension); }
  else {
    pathname_make(dir=>pathname_directory($parentpath),
		  name=>$name,
		  type=>$doc->getDestinationExtension); }}

# ================================================================================
1;

