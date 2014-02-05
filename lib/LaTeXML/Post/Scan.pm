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
use warnings;
use LaTeXML::Util::Pathname;
use LaTeXML::Common::XML;
use LaTeXML::Post;
use base qw(LaTeXML::Post::Processor);

# NOTE: This module is one that probably needs a lot of customizability.
sub new {
  my ($class, %options) = @_;
  my $self = $class->SUPER::new(%options);
  $$self{db}       = $options{db};
  $$self{handlers} = {};
  $self->registerHandler('ltx:document'      => \&section_handler);
  $self->registerHandler('ltx:part'          => \&section_handler);
  $self->registerHandler('ltx:chapter'       => \&section_handler);
  $self->registerHandler('ltx:section'       => \&section_handler);
  $self->registerHandler('ltx:appendix'      => \&section_handler);
  $self->registerHandler('ltx:subsection'    => \&section_handler);
  $self->registerHandler('ltx:subsubsection' => \&section_handler);
  $self->registerHandler('ltx:paragraph'     => \&section_handler);
  $self->registerHandler('ltx:subparagraph'  => \&section_handler);
  $self->registerHandler('ltx:bibliography'  => \&section_handler);
  $self->registerHandler('ltx:index'         => \&section_handler);
  $self->registerHandler('ltx:glossary'      => \&section_handler);

  $self->registerHandler('ltx:table'   => \&captioned_handler);
  $self->registerHandler('ltx:figure'  => \&captioned_handler);
  $self->registerHandler('ltx:listing' => \&captioned_handler);
  $self->registerHandler('ltx:theorem' => \&section_handler);

  $self->registerHandler('ltx:equation'      => \&labelled_handler);
  $self->registerHandler('ltx:equationgroup' => \&labelled_handler);
  $self->registerHandler('ltx:item'          => \&labelled_handler);
  $self->registerHandler('ltx:anchor'        => \&anchor_handler);

  $self->registerHandler('ltx:bibitem'       => \&bibitem_handler);
  $self->registerHandler('ltx:bibentry'      => \&bibentry_handler);
  $self->registerHandler('ltx:indexmark'     => \&indexmark_handler);
  $self->registerHandler('ltx:glossarymark'  => \&glossarymark_handler);
  $self->registerHandler('ltx:glossaryentry' => \&glossarymark_handler);
  $self->registerHandler('ltx:ref'           => \&ref_handler);
  $self->registerHandler('ltx:bibref'        => \&bibref_handler);

  $self->registerHandler('ltx:navigation' => \&navigation_handler);

  $self->registerHandler('ltx:rdf' => \&rdf_handler);

  $self->registerHandler('ltx:rawhtml' => \&rawhtml_handler);

  return $self; }

sub registerHandler {
  my ($self, $tag, $handler) = @_;
  $$self{handlers}{$tag} = $handler;
  return; }

sub process {
  my ($self, $doc, $root) = @_;
  # I think we really need an ID here to establish the root node in the DB,
  # even if the document didn't have one originally.
  # And for the common case of a single docucment, we'd like to be silent about it,
  # UNLESS there seem to be multiple documents which would lead to a conflict.
  my $id = $root->getAttribute('xml:id');
  if (!defined $id) {
    $id = "Document";
    if (my $preventry = $$self{db}->lookup("ID:$id")) {
      if (my $loc = $doc->siteRelativeDestination) {
        my $prevloc = $preventry->getValue('location');
        if ((defined $prevloc) && ($loc ne $prevloc)) {
          Warn('unexpected', $id, undef,
            "Using default ID='$id', "
              . "but there's an apparent conflict with location '$loc' and previous '$prevloc'"); } } }
    $root->setAttribute('xml:id' => $id); }

  $$self{db}->{document_id} = $id unless defined $$self{db}->{document_id};
  $self->scan($doc, $root, $$doc{parent_id});
  NoteProgressDetailed(" [DBStatus: " . $$self{db}->status . "]");
  return $doc; }

sub scan {
  my ($self, $doc, $node, $parent_id) = @_;
  my $tag = $doc->getQName($node);
  my $handler = $$self{handlers}{$tag} || \&default_handler;
  &$handler($self, $doc, $node, $tag, $parent_id);
  return; }

sub scanChildren {
  my ($self, $doc, $node, $parent_id) = @_;
  foreach my $child ($node->childNodes) {
    if ($child->nodeType == XML_ELEMENT_NODE) {
      $self->scan($doc, $child, $parent_id); } }
  return; }

sub addAsChild {
  my ($self, $id, $parent_id) = @_;
  # Find the ancestor that maintains a children list
  while (my $parent = $parent_id && $$self{db}->lookup("ID:$parent_id")) {
    if ($parent->hasValue('children')) {
      $parent->pushNew('children', $id);
      last; }
    else {
      $parent_id = $parent->getValue('parent'); } }
  return; }

sub pageID {
  my ($self, $doc) = @_;
  return $doc->getDocumentElement->getAttribute('xml:id'); }

# Compute a "Fragment ID", ie. an ID based on the given ID,
# but which is potentially shortened so that it need only be
# unique within the given page.
sub inPageID {
  my ($self, $doc, $id) = @_;
  my $baseid = $doc->getDocumentElement->getAttribute('xml:id') || '';
  if ($baseid eq $id) {
    return; }
  elsif ($baseid && ($id =~ /^\Q$baseid\E\.(.*)$/)) {
    return $1; }
  elsif ($$doc{split_from_id} && ($id =~ /^\Q$$doc{split_from_id}\E\.(.*)$/)) {
    return $1; }
  else {
    return $id; } }

sub noteLabels {
  my ($self, $node) = @_;
  if (my $id = $node->getAttribute('xml:id')) {
    if (my $labels = $node->getAttribute('labels')) {
      my @labels = split(' ', $node->getAttribute('labels'));
      foreach my $label (@labels) {
        $$self{db}->register($label, id => orNull($id)); }
      return [@labels]; } }
  return; }

# Clean up a node before insertion into database.
sub cleanNode {
  my ($self, $doc, $node) = @_;
  return $node unless $node;
  my $cleaned = $node->cloneNode(1);
  # Remove indexmark (anything else ?)
  map { $_->parentNode->removeChild($_) } $doc->findnodes('.//ltx:indexmark', $cleaned);
  return $cleaned; }

sub default_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  my $id = $node->getAttribute('xml:id');
  if ($id) {
    $$self{db}->register("ID:$id", id => orNull($id), type => orNull($tag), parent => orNull($parent_id),
      labels   => orNull($self->noteLabels($node)),
      location => orNull($doc->siteRelativeDestination),
      pageid   => orNull($self->pageID($doc)),
      fragid   => orNull($self->inPageID($doc, $id)));
    $self->addAsChild($id, $parent_id); }
  $self->scanChildren($doc, $node, $id || $parent_id);
  return; }

sub section_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  my $id = $node->getAttribute('xml:id');
  if ($id) {
    $$self{db}->register("ID:$id", id => orNull($id), type => orNull($tag), parent => orNull($parent_id),
      labels   => orNull($self->noteLabels($node)),
      location => orNull($doc->siteRelativeDestination),
      primary  => 1,
      pageid   => orNull($self->pageID($doc)),
      fragid   => orNull($self->inPageID($doc, $id)),
      refnum   => orNull($node->getAttribute('refnum')),
      frefnum  => orNull($node->getAttribute('frefnum')),
      rrefnum  => orNull($node->getAttribute('rrefnum')),
      title    => orNull($self->cleanNode($doc, $doc->findnode('ltx:title', $node))),
      toctitle => orNull($self->cleanNode($doc, $doc->findnode('ltx:toctitle', $node))),
      children => [],
      stub     => orNull($node->getAttribute('stub')));
    $self->addAsChild($id, $parent_id); }
  $self->scanChildren($doc, $node, $id || $parent_id);
  return; }

sub captioned_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  my $id = $node->getAttribute('xml:id');
  if ($id) {
    $$self{db}->register("ID:$id", id => orNull($id), type => orNull($tag), parent => orNull($parent_id),
      labels   => orNull($self->noteLabels($node)),
      location => orNull($doc->siteRelativeDestination),
      pageid   => orNull($self->pageID($doc)),
      fragid   => orNull($self->inPageID($doc, $id)),
      refnum   => orNull($node->getAttribute('refnum')),
      frefnum  => orNull($node->getAttribute('frefnum')),
      rrefnum  => orNull($node->getAttribute('rrefnum')),
      caption  => orNull($self->cleanNode($doc,
          $doc->findnode('descendant::ltx:caption', $node))),
      toccaption => orNull($self->cleanNode($doc,
          $doc->findnode('descendant::ltx:toccaption', $node))));
    $self->addAsChild($id, $parent_id); }
  $self->scanChildren($doc, $node, $id || $parent_id);
  return; }

sub labelled_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  my $id = $node->getAttribute('xml:id');
  if ($id) {
    my $refnum  = $node->getAttribute('refnum');
    my $frefnum = $node->getAttribute('frefnum');
    my $rrefnum = $node->getAttribute('rrefnum');
    my $reftag  = $self->cleanNode($doc, $doc->findnode('ltx:tag', $node));
    # Rather annoying interpretation:
    # an <ltx:tag> might just be something like an itemization bullet that
    # doesn't make sense to use when referring to the object.
    # OTOH, it might be a more nicely formatted version of the frefnum
    # So, IF there is a refnum, use tag in place of the frefnum!
    $$self{db}->register("ID:$id", id => orNull($id), type => orNull($tag), parent => orNull($parent_id),
      labels   => orNull($self->noteLabels($node)),
      location => orNull($doc->siteRelativeDestination),
      pageid   => orNull($self->pageID($doc)),
      fragid   => orNull($self->inPageID($doc, $id)),
      refnum   => orNull($refnum),
      frefnum  => orNull(($refnum && $reftag ? $reftag : $frefnum)),
      rrefnum  => orNull(($refnum && $reftag ? $reftag : $rrefnum)));
    $self->addAsChild($id, $parent_id); }
  $self->scanChildren($doc, $node, $id || $parent_id);
  return; }

sub anchor_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  my $id = $node->getAttribute('xml:id');
  if ($id) {
    $$self{db}->register("ID:$id", id => orNull($id), type => orNull($tag), parent => orNull($parent_id),
      labels   => orNull($self->noteLabels($node)),
      location => orNull($doc->siteRelativeDestination),
      pageid   => orNull($self->pageID($doc)),
      fragid   => orNull($self->inPageID($doc, $id)),
      title    => orNull($self->cleanNode($doc, $node)),
      refnum   => orNull($node->getAttribute('refnum')),
      frefnum  => orNull($node->getAttribute('frefnum')),
      rrefnum  => orNull($node->getAttribute('rrefnum')));
    $self->addAsChild($id, $parent_id); }
  $self->scanChildren($doc, $node, $id || $parent_id);
  return; }

sub ref_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  my $id = $node->getAttribute('xml:id');
  if (my $label = $node->getAttribute('labelref')) {    # Only record refs of labels
                                                        # Don't scan refs from TOC or 'cited' bibblock
    if (!$doc->findnodes('ancestor::ltx:tocentry'
          . '| ancestor::ltx:bibblock[contains(@class,"ltx_bib_cited")]',
        $node)) {
      my $entry = $$self{db}->register($label);
      $entry->noteAssociation(referrers => $parent_id); } }
  # Usually, a ref won't YET have content; but if it does, we should scan it.
  $self->default_handler($doc, $node, $tag, $parent_id);
  return; }

sub bibref_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  # Don't scan refs from 'cited' bibblock
  if (!$doc->findnodes('ancestor::ltx:bibblock[contains(@class,"ltx_bib_cited")]', $node)) {
#####  if( ($node->getAttribute('class')||'') !~ /\bcitedby\b/){
    my $keys = $node->getAttribute('bibrefs');
    foreach my $bibkey (split(',', $keys)) {
      if ($bibkey) {
        $bibkey = lc($bibkey);    # NOW we downcase!
        my $entry = $$self{db}->register("BIBLABEL:$bibkey");
        $entry->noteAssociation(referrers => $parent_id); } } }
  # Usually, a bibref will have, at most, some ltx:bibphrase's; should be scanned.
  $self->default_handler($doc, $node, $tag, $parent_id);
  return; }

# Note that index entries get stored in simple form; just the terms & location.
# They will be turned into a tree, sorted, possibly permuted, whatever, by MakeIndex.
# [the only content of indexmark should be un-marked up(?) don't recurse]
sub indexmark_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  # Get the actual phrases, and any see_also phrases (if any)
  my @phrases = $doc->findnodes('ltx:indexphrase', $node);
  my @seealso = $doc->findnodes('ltx:indexsee',    $node);
  my $key = join(':', 'INDEX', map { $_->getAttribute('key') } @phrases);
  my $entry = $$self{db}->lookup($key)
    || $$self{db}->register($key, phrases => [@phrases], see_also => []);
  if (@seealso) {
    $entry->pushNew('see_also', @seealso); }
  else {
    $entry->noteAssociation(referrers => $parent_id => ($node->getAttribute('style') || 'normal')); }
  return; }

# This handles glossarymark and glossaryentry
sub glossarymark_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  my $id = $node->getAttribute('xml:id');
  my $role = $node->getAttribute('role') || '';
  # Get the actual phrases, and any see_also phrases (if any)
  my $phrase     = $doc->findnode('ltx:glossaryphrase',     $node);
  my $expansion  = $doc->findnode('ltx:glossaryexpansion',  $node);
  my $definition = $doc->findnode('ltx:glossarydefinition', $node);
  if (my $glosskey = $phrase->getAttribute('key')) {
    my $key = join(':', 'GLOSSARY', $role, $glosskey);
    my $entry = $$self{db}->lookup($key)
      || $$self{db}->register($key, phrase => orNull($phrase), expansion => orNull($expansion), definition => orNull($definition));
    $entry->noteAssociation(referrers => $parent_id => ($node->getAttribute('style') || 'normal')); }
  if ($id) {
    $$self{db}->register("ID:$id", id => orNull($id), type => orNull($tag), parent => orNull($parent_id),
      labels   => orNull($self->noteLabels($node)),
      location => orNull($doc->siteRelativeDestination),
      pageid   => orNull($self->pageID($doc)),
      fragid   => orNull($self->inPageID($doc, $id))); }
  # Scan content, since could contain other interesting stuff...
  $self->scanChildren($doc, $node, $id || $parent_id);
  return; }

# Note this bit of perversity:
#  <ltx:bibentry> is a semantic bibliographic entry,
#     as generated from a BibTeX file.
#  <ltx:bibitem> is a formatted bibliographic entry,
#     as generated from an explicit thebibliography environment,
#     or as formatted from a <ltx:bibentry> by MakeBibliography.
# For a bibitem, we'll store the usual info in the DB.
sub bibitem_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  my $id = $node->getAttribute('xml:id');
  if ($id) {
    # NOTE: We didn't downcase the key when we created the bib file
    # BUT, we're going to index it in the ObjectDB by the downcased name!!!
    my $key = $node->getAttribute('key');
    $key = lc($key) if $key;
    $$self{db}->register("BIBLABEL:$key", id => orNull($id)) if $key;
    $$self{db}->register("ID:$id", id => orNull($id), type => orNull($tag), parent => orNull($parent_id), bibkey => orNull($key),
      location    => orNull($doc->siteRelativeDestination),
      pageid      => orNull($self->pageID($doc)),
      fragid      => orNull($self->inPageID($doc, $id)),
      authors     => orNull($doc->findnode('ltx:bibtag[@role="authors"]', $node)),
      fullauthors => orNull($doc->findnode('ltx:bibtag[@role="fullauthors"]', $node)),
      year        => orNull($doc->findnode('ltx:bibtag[@role="year"]', $node)),
      number      => orNull($doc->findnode('ltx:bibtag[@role="number"]', $node)),
      refnum      => orNull($doc->findnode('ltx:bibtag[@role="refnum"]', $node)),
      title       => orNull($doc->findnode('ltx:bibtag[@role="title"]', $node)),
      keytag      => orNull($doc->findnode('ltx:bibtag[@role="key"]', $node)),
      typetag     => orNull($doc->findnode('ltx:bibtag[@role="bibtype"]', $node))); }
  $self->scanChildren($doc, $node, $id || $parent_id);
  return; }

# For a bibentry, we'll only store the citation key, so we know it's there.
sub bibentry_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  my $id = $node->getAttribute('xml:id');
  if ($id) {
    if (my $key = $node->getAttribute('key')) {
      $$self{db}->register('BIBLABEL:' . lc($key), id => orNull($id)); } }
## No, let's not scan the content of the bibentry
## until it gets formatted and re-scanned by MakeBibliography.
##  $self->scanChildren($doc,$node,$id || $parent_id);

## HOWEVER; this ultimately requires formatting the bibliography twice (for complex sites).
## This needs to be reworked!
  return; }

# I'm thinking we shouldn't acknowledge navigation data at all?
sub navigation_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  return; }

# RDF should be recorded with its "about" designation, or its immediate parent
sub rdf_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  my $id = $node->getAttribute('about');
  if (!($id && ($id =~ s/^#//))) {
    $id = $parent_id; }
  my $property = $node->getAttribute('property');
  my $value = $node->getAttribute('resource') || $node->getAttribute('content');
  return unless ($property && $value);
  $$self{db}->register("ID:$id", $property => orNull($value));
  return; }

# I'm thinking we shouldn't acknowledge rawhtml data at all?
sub rawhtml_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  return; }

sub orNull {
  return (grep { defined } @_) ? @_ : undef; }

# ================================================================================
1;

