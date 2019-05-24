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
  $self->registerHandler('ltx:float'   => \&captioned_handler);
  $self->registerHandler('ltx:listing' => \&captioned_handler);
  $self->registerHandler('ltx:theorem' => \&section_handler);
  $self->registerHandler('ltx:proof'   => \&section_handler);

  $self->registerHandler('ltx:equation'      => \&labelled_handler);
  $self->registerHandler('ltx:equationgroup' => \&labelled_handler);
  $self->registerHandler('ltx:item'          => \&labelled_handler);
  $self->registerHandler('ltx:anchor'        => \&anchor_handler);
  $self->registerHandler('ltx:note'          => \&note_handler);

  $self->registerHandler('ltx:bibitem'            => \&bibitem_handler);
  $self->registerHandler('ltx:bibentry'           => \&bibentry_handler);
  $self->registerHandler('ltx:indexmark'          => \&indexmark_handler);
  $self->registerHandler('ltx:glossaryentry'      => \&glossaryentry_handler);
  $self->registerHandler('ltx:glossarydefinition' => \&glossaryentry_handler);
  $self->registerHandler('ltx:ref'                => \&ref_handler);
  $self->registerHandler('ltx:bibref'             => \&bibref_handler);

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
          Warn('unexpected', 'location', undef,
            "Using default ID='$id', "
              . "but there's an apparent conflict with location '$loc' and previous '$prevloc'"); } } }
    $root->setAttribute('xml:id' => $id); }

  $$self{db}->{document_id} = $id unless defined $$self{db}->{document_id};
  $self->scan($doc, $root, $$doc{parent_id});
  NoteProgressDetailed(" [DBStatus: " . $$self{db}->status . "]");
  return $doc; }

sub scan {
  my ($self, $doc, $node, $parent_id) = @_;
  my $tag     = $doc->getQName($node);
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
  my ($self, $doc, $node) = @_;
  my $id     = $node->getAttribute('xml:id');
  my $baseid = $doc->getDocumentElement->getAttribute('xml:id') || '';
  # And we're using label-based ids in the target document...
  if ($$self{labelids}) {
    if (my $labels = $node->getAttribute('labels')) {
      my ($l) = split(' ', $labels);
      $l =~ s/^LABEL://;
      $id = $l;
      if (my $baselabels = $doc->getDocumentElement->getAttribute('labels')) {
        my ($bl) = split(' ', $baselabels);
        $bl =~ s/^LABEL://;
        $baseid = $bl; } } }
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
  # Clone the node, and get the ID's unique (at least) within the originating document
  my $cleaned = $doc->cloneNode($node);
  # Remove indexmark (anything else ?)
  map { $_->parentNode->removeChild($_) } $doc->findnodes('.//ltx:indexmark', $cleaned);
  return $cleaned; }

# Assumes $node has been cloned, if needed.
# Set to something smallish (eg. 6) to forcibly truncate toctitle/toccaption
our $TOCTEXT_MAX_LENGTH = undef;

sub truncateNode {
  my ($self, $doc, $node) = @_;
  return $node if !$node || !defined $TOCTEXT_MAX_LENGTH;
  my @children = $node->childNodes;
  my $n        = $TOCTEXT_MAX_LENGTH;
  my $trunc    = 0;
  while ($n && @children) {
    my $c = shift(@children);
    if ($c->nodeType == XML_TEXT_NODE) {
      my $s = $c->textContent;
      my @w = split(/\s/, $s);
      if (scalar(@w) > $n) {
        $c->setData(join(' ', @w[0 .. $n]));
        $trunc = 1; $n = 0; }
      else {
        $n--; } }
    else {
      $n--; } }
  if ($trunc || (scalar(@children) > 1)) {
    map { $node->removeChild($_) } @children;    # Remove any remaining children.
    $node->appendText("\x{2026}"); }
  return $node; }

sub addCommon {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  my $id = $node->getAttribute('xml:id');
  my $inlist;
  if (my $listnames = $node->getAttribute('inlist')) {
    $inlist = { map { ($_ => 1) } split(/\s/, $listnames) }; }
  my %props = (
    id       => orNull($id),
    type     => orNull($tag),
    parent   => orNull($parent_id),
    labels   => orNull($self->noteLabels($node)),
    location => orNull($doc->siteRelativeDestination),
    pageid   => orNull($self->pageID($doc)),
    fragid   => orNull($self->inPageID($doc, $node)),
    inlist   => $inlist,
  );
  # Figure out sane, safe naming?
  foreach my $tagnode ($doc->findnodes('ltx:tags/ltx:tag', $node)) {
    my $key;
    if (my $role = $tagnode->getAttribute('role')) {
      if ($role =~ /.*refnum$/) {
        $key = $role; }
      else {
        $key = 'tag:' . $role; } }
    else {
      $key = 'frefnum'; }
    ###      $key = 'refnum'; }        # ???
    $props{$key} = $self->cleanNode($doc, $tagnode); }
  return %props; }

sub default_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  my $id = $node->getAttribute('xml:id');
  if ($id) {
    $$self{db}->register("ID:$id",
      $self->addCommon($doc, $node, $tag, $parent_id));
    $self->addAsChild($id, $parent_id); }
  $self->scanChildren($doc, $node, $id || $parent_id);
  return; }

sub section_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  my $id = $node->getAttribute('xml:id');
  if ($id) {
    $$self{db}->register("ID:$id",
      $self->addCommon($doc, $node, $tag, $parent_id),
      primary  => 1,
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
    # We're actually trying to find the shallowest caption
    # Not one nested in another figure/table/float/whoknowswhat !
    my ($caption) = ($doc->findnode('child::ltx:caption', $node),
      $doc->findnode('descendant::ltx:caption', $node));
    my ($toccaption) = ($doc->findnode('child::ltx:toccaption', $node),
      $doc->findnode('descendant::ltx:toccaption', $node));
    $$self{db}->register("ID:$id",
      $self->addCommon($doc, $node, $tag, $parent_id),
      role    => orNull($node->getAttribute('role')),
      caption => orNull($self->cleanNode($doc, $caption)),
###      toccaption => orNull($self->cleanNode($doc,
###          $doc->findnode('descendant::ltx:toccaption', $node))));
      toccaption => orNull($self->truncateNode($doc, $self->cleanNode($doc, $toccaption))));
    $self->addAsChild($id, $parent_id); }
  $self->scanChildren($doc, $node, $id || $parent_id);
  return; }

sub labelled_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  my $id = $node->getAttribute('xml:id');
  if ($id) {
    $$self{db}->register("ID:$id",
      $self->addCommon($doc, $node, $tag, $parent_id),
      role => orNull($node->getAttribute('role')),
    );
    $self->addAsChild($id, $parent_id); }
  $self->scanChildren($doc, $node, $id || $parent_id);
  return; }

# Maybe with some careful redesign of the schema, this would fall under labelled?
sub note_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  my $id = $node->getAttribute('xml:id');
  if ($id) {
    my $note = $self->cleanNode($doc, $node);
    map { $note->removeChild($_) } $doc->findnodes('.//ltx:tags', $note);
    $$self{db}->register("ID:$id",
      $self->addCommon($doc, $node, $tag, $parent_id),
      role => orNull($node->getAttribute('role')),
      note => $note,
    );
    $self->addAsChild($id, $parent_id); }
  $self->scanChildren($doc, $node, $id || $parent_id);
  return; }

sub anchor_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  my $id = $node->getAttribute('xml:id');
  if ($id) {
    $$self{db}->register("ID:$id",
      $self->addCommon($doc, $node, $tag, $parent_id),
      title => orNull($self->cleanNode($doc, $node)),
    );
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
    if (my $keys = $node->getAttribute('bibrefs')) {
      my @lists = split(/\s+/, $node->getAttribute('inlist') || 'bibliography');
      foreach my $bibkey (split(',', $keys)) {
        if ($bibkey) {
          $bibkey = lc($bibkey);    # NOW we downcase!
          my $entry = $$self{db}->register("BIBLABEL:$bibkey");
          map { $entry->noteAssociation(inlist => $_); } @lists;
          $entry->noteAssociation(referrers => $parent_id); } } } }
  # Usually, a bibref will have, at most, some ltx:bibphrase's; should be scanned.
  $self->default_handler($doc, $node, $tag, $parent_id);
  return; }

# Note that index entries get stored in simple form; just the terms & location.
# They will be turned into a tree, sorted, possibly permuted, whatever, by MakeIndex.
# [the only content of indexmark should be un-marked up(?) don't recurse]
sub indexmark_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  # Get the actual phrases, and any see_also phrases (if any)
  # Do these need ->cleanNode ???
  my @phrases = $doc->findnodes('ltx:indexphrase', $node);
  my @seealso = $doc->findnodes('ltx:indexsee',    $node);
  my $key = join(':', 'INDEX', map { $_->getAttribute('key') } @phrases);
  my $inlist;
  if (my $listnames = $node->getAttribute('inlist')) {
    $inlist = { map { ($_ => 1) } split(/\s/, $listnames) }; }
  my $entry = $$self{db}->lookup($key)
    || $$self{db}->register($key, phrases => [@phrases], see_also => [], inlist => $inlist);
  if (@seealso) {
    $entry->pushNew('see_also', @seealso); }
  else {
    $entry->noteAssociation(referrers => $parent_id => ($node->getAttribute('style') || 'normal')); }
  return; }

# This handles glossaryentry or glossarydefinition
sub glossaryentry_handler {
  my ($self, $doc, $node, $tag, $parent_id) = @_;
  my $id = $node->getAttribute('xml:id');
  my $p;
  my $lists = $node->getAttribute('inlist') ||
    (($p = $doc->findnode('ancestor::ltx:glossarylist[@lists] | ancestor::ltx:glossary[@lists]', $node))
    && $p->getAttribute('lists'))
    || 'glossary';
  my $key = $node->getAttribute('key');
  # Get the actual phrases, and any see_also phrases (if any)
  # Do these need ->cleanNode ???
  my @phrases    = $doc->findnodes('ltx:glossaryphrase', $node);
  my $definition = $doc->findnode('ltx:glossarydefinition', $node);
  # Create an entry for EACH list (they could be distinct definitions)
  foreach my $list (split(/\s+/, $lists)) {
    my $gkey  = join(':', 'GLOSSARY', $list, $key);
    my $entry = $$self{db}->lookup($gkey)
      || $$self{db}->register($gkey, definition => orNull($definition));
    $entry->setValues(map { ('phrase:' . ($_->getAttribute('role') || 'label') => $_) } @phrases);
    $entry->noteAssociation(referrers => $parent_id => ($node->getAttribute('style') || 'normal'));
    $entry->setValues(id => $id) if $id; }

  if ($id) {
    $$self{db}->register("ID:$id", id => orNull($id), type => orNull($tag), parent => orNull($parent_id),
      labels   => orNull($self->noteLabels($node)),
      location => orNull($doc->siteRelativeDestination),
      pageid   => orNull($self->pageID($doc)),
      fragid   => orNull($self->inPageID($doc, $node))); }
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
    # Do these need ->cleanNode ???
    $$self{db}->register("ID:$id", id => orNull($id), type => orNull($tag), parent => orNull($parent_id), bibkey => orNull($key),
      location    => orNull($doc->siteRelativeDestination),
      pageid      => orNull($self->pageID($doc)),
      fragid      => orNull($self->inPageID($doc, $node)),
      authors     => orNull($doc->findnode('ltx:tags/ltx:tag[@role="authors"]', $node)),
      fullauthors => orNull($doc->findnode('ltx:tags/ltx:tag[@role="fullauthors"]', $node)),
      year        => orNull($doc->findnode('ltx:tags/ltx:tag[@role="year"]', $node)),
      number      => orNull($doc->findnode('ltx:tags/ltx:tag[@role="number"]', $node)),
      refnum      => orNull($doc->findnode('ltx:tags/ltx:tag[@role="refnum"]', $node)),
      title       => orNull($doc->findnode('ltx:tags/ltx:tag[@role="title"]', $node)),
      keytag      => orNull($doc->findnode('ltx:tags/ltx:tag[@role="key"]', $node)),
      typetag     => orNull($doc->findnode('ltx:tags/ltx:tag[@role="bibtype"]', $node))); }
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
  my $value    = $node->getAttribute('resource') || $node->getAttribute('content');
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

