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
use warnings;
use LaTeXML::Util::Pathname;
use LaTeXML::Common::XML;
use LaTeXML::Post;
use base qw(LaTeXML::Post::Processor);

sub new {
  my ($class, %options) = @_;
  my $self = $class->SUPER::new(%options);
  $$self{split_xpath}   = $options{split_xpath};
  $$self{splitnaming}   = $options{splitnaming};
  $$self{no_navigation} = $options{no_navigation};
  return $self; }

# Could this actually just return the nodes that are to become pages?
# sub toProcess { ??? }

sub process {
  my ($self, $doc, $root) = @_;
  # RISKY and annoying; to split, we really need an id on the root.
  # Writer will remove it.
  $root->setAttribute('xml:id' => 'TEMPORARY_DOCUMENT_ID') unless $root->hasAttribute('xml:id');

  my @docs  = ($doc);
  my @pages = $self->getPages($doc);
  # Weird test: exclude the "whole document" from the list (?)
  @pages = grep { $_->parentNode->parentNode } @pages;    # Strip out the root node.
  if (@pages) {
    my @nav = $doc->findnodes("descendant::ltx:navigation");
    $doc->removeNodes(@nav) if @nav;
    my $tree = { node => $root, document => $doc,
      id => $root->getAttribute('xml:id'), name => $doc->getDestination,
      children => [] };
    # Group the pages into a tree, in case they are nested.
    my $haschildren = {};
    foreach my $page (@pages) {
      presortPages($tree, $haschildren, $page); }
    # Work out the destination paths for each page
    $self->prenamePages($doc, $tree, $haschildren);
    # Now, create remove and create documents for each page.
    push(@docs, $self->processPages($doc, @{ $$tree{children} }));

    $self->addNavigation($tree, @nav) if @nav;
  }
  return @docs; }

# Get the nodes in the document that WILL BECOME separate "pages".
# (they are not yet removed from the main document)
# Subclass can override, if needed.
sub getPages {
  my ($self, $doc) = @_;
  return $doc->findnodes($$self{split_xpath}); }

# Sort the pages into a tree, in case some pages are children of others
# If a page contains NOTHING BUT child pages (except frontmatter),
# we could just merge that page as a level in it's containing TOC instead of a document.???
sub presortPages {
  my ($tree, $haschildren, $page) = @_;
  my $nextlevel;    # if $page is a descendant of some othe page
####  if(($nextlevel = $$tree{children}[-1]) && (isDescendant($page, $$nextlevel{node}))){
  if (($nextlevel = $$tree{children}[-1]) && (isChild($page, $$nextlevel{node}))) {
    presortPages($nextlevel, $haschildren, $page); }
  else {
    $$haschildren{ $$tree{node}->localname } = 1;    # Wrong key for this!?!
    push(@{ $$tree{children} },
      { node => $page, upid => $$tree{id}, id => $page->getAttribute('xml:id'), parent => $tree, children => [] }); }
  return; }

# Get destination pathnames for each page.
sub prenamePages {
  my ($self, $doc, $tree, $haschildren) = @_;
  foreach my $entry (@{ $$tree{children} }) {
    $$entry{name} = $self->getPageName($doc, $$entry{node}, $$tree{node}, $$tree{name},
      $$haschildren{ $$entry{node}->localname });
    $self->prenamePages($doc, $entry, $haschildren); }
  return; }

# Process a sequence of page entries, removing them and generating documents for each.
sub processPages {
  my ($self, $doc, @entries) = @_;
  my $rootid = $doc->getDocumentElement->getAttribute('xml:id');
  my @docs   = ();
  while (@entries) {
    my $parent = $entries[0]->{node}->parentNode;
    # Remove $page & ALL following siblings (backwards).
    my @removed = ();
    while (my $sib = $parent->lastChild) {
      $parent->removeChild($sib);
      unshift(@removed, $sib);
      last if $$sib == ${ $entries[0]->{node} }; }
    # Build toc from adjacent nodes that are being extracted.
    my @toc = ();
    # Process a sequence of adjacent pages; these will go into the same TOC.
    while (@entries && @removed && ${ $entries[0]->{node} } == ${ $removed[0] }) {
      my $entry = shift(@entries);
      my $page  = $$entry{node};
      $doc->removeNodes(shift(@removed));
      my $id = $page->getAttribute('xml:id');
      my $tocentry = ['ltx:tocentry', {},
        ['ltx:ref', { idref => $id, show => 'fulltitle' }]];
      push(@toc, $tocentry);
      # Due to the way document building works, we remove & process children pages
      # BEFORE processing this page.
      my @childdocs = $self->processPages($doc, @{ $$entry{children} });
      my $subdoc = $doc->newDocument($page, destination => $$entry{name},
        parentDocument => $doc, parent_id => $$entry{upid});
      $$entry{document} = $subdoc;
      push(@docs, $subdoc, @childdocs); }
    # Finally, add the toc to reflect the consecutive, removed nodes, and add back the remainder
    my $type = $parent->localname;
    $doc->addNodes($parent, ['ltx:TOC', {}, ['ltx:toclist', { class => 'ltx_toc_' . $type }, @toc]])
      if @toc && !$doc->findnodes("descendant::ltx:TOC[\@role='contents']", $parent);
    map { $parent->addChild($_) } @removed; }
  return @docs; }

sub addNavigation {
  my ($self, $entry, @nav) = @_;
  my $doc = $$entry{document};
  $doc->addNodes($doc->getDocumentElement, @nav);    # cloning, as needed...
  foreach my $child (@{ $$entry{children} }) {
    my $childdoc = $$child{document};
    $self->addNavigation($child, @nav); }            # now, recurse
  return; }

# error situation: generate some kind of unique name for page
sub generateUnnamedPageName {
  my ($self) = @_;
  my $ctr = ++$$self{unnamed_page_counter};
  return "FOO" . $ctr; }

sub getPageName {
  my ($self, $doc, $page, $parent, $parentpath, $recursive) = @_;
  my $asdir;
  my $naming = $$self{splitnaming};
  my $attr = ($naming =~ /^id/ ? 'xml:id'
    : ($naming =~ /^label/ ? 'labels' : undef));
  my $name = $page->getAttribute($attr);
  $name =~ s/\s+.*//   if $name;    # Truncate in case multiple labels.
  $name =~ s/^LABEL:// if $name;
  if (!$name) {
    if (($attr eq 'labels') && ($name = $page->getAttribute('xml:id'))) {
      Info('expected', $attr, $doc->getQName($page),
        "Expected attribute '$attr' to create page pathname", "using id=$name");
      $attr = 'xml:id'; }
    else {
      $name = $self->generateUnnamedPageName;
      Info('expected', $attr, $doc->getQName($page),
        "Expected attribute '$attr' to create page pathname", "using id=$name"); } }
  if ($naming =~ /relative$/) {
    my $pname = $parent->getAttribute($attr);
    if ($pname && $name =~ /^\Q$pname\E(\.|_|:)+(.*)$/) {
      $name = $2; }
    $asdir = $recursive; }
  $name =~ s/:+/_/g;
  if ($asdir) {
    return pathname_make(dir => pathname_concat(pathname_directory($parentpath), $name),
      name => 'index',
      type => $doc->getDestinationExtension); }
  else {
    return pathname_make(dir => pathname_directory($parentpath),
      name => $name,
      type => $doc->getDestinationExtension); } }

# ================================================================================
1;

