# /=====================================================================\ #
# |  LaTeXML::Post::MakeIndex                                           | #
# | Make an index from scanned indexmark's                              | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Post::MakeIndex;
use strict;
use warnings;
use LaTeXML::Util::Pathname;
use LaTeXML::Common::XML;
use charnames qw(:full);
use LaTeXML::Post;
use base qw(LaTeXML::Post::Collector);

# Options:
#   permuted : Generates a permuted index
#              The phrases (separated by ! in LaTeX) within each \index entry
#              are permuted before adding to the index tree.
#   split  : whether the split into separate pages by initial.
sub new {
  my ($class, %options) = @_;
  my $self = $class->SUPER::new(%options);
  $$self{permuted} = $options{permuted};
  $$self{split}    = $options{split};
  return $self; }

sub toProcess {
  my ($self, $doc) = @_;
  return $doc->findnode('//ltx:index'); }

sub process {
  my ($self, $doc, $index) = @_;
  my @indices = ($doc);
  $doc->addDate();
  my ($allkeys, $allphrases, $tree) = $self->build_tree($doc, $index);
  if ($tree) {
    if ($$self{split}) {
      @indices = map { $self->rescan($_) }
        $self->makeSubCollectionDocuments($doc, $index,
        map { ($_ => $self->makeIndexList($doc, $allkeys, $allphrases, $$tree{subtrees}{$_})) }
          keys %{ $$tree{subtrees} }); }
    else {
      $doc->addNodes($index, $self->makeIndexList($doc, $allkeys, $allphrases, $tree));
      @indices = ($self->rescan($doc)); } }
  return @indices; }

# ================================================================================
# Data generated:
#  $tree : tree representation of the index.
#  $allphrases : used for inferring the connection from see-also phrases to normal index entries.
#  $allkeys :
# ================================================================================
# Extracting a tree of index entries from the database
sub build_tree {
  my ($self, $doc, $index) = @_;
  if (my @keys = grep { /^INDEX:/ } $$self{db}->getKeys) {
    NoteProgress(" [" . scalar(@keys) . " entries]");

    #    my $id = $doc->getDocumentElement->getAttribute('xml:id');
    my $id = $index->getAttribute('xml:id');
# The next 2 support finding see-also cross-references, and otherwise checking for defined-ness of terms.
    my $allkeys = { '' => { id => $id, phrases => [] } }; # Keep a hash of all phrase key's =>{data} encountered.
    my $allphrases = {};    # Keep a hash of all phrase textContent=>key encountered
    my $tree = { subtrees => {}, referrers => {}, id => $id, parent => undef };
    foreach my $key (@keys) {
      my $entry   = $$self{db}->lookup($key);
      my $phrases = $entry->getValue('phrases');
      my @phrases = @$phrases;
      if (!scalar(@phrases)) {
        Warn('expected', $key, undef, "Missing phrases in indexmark: '$key'");
        next; }

      if ($$self{permuted}) {
        map { $self->add_entry($doc, $allkeys, $allphrases, $tree, $entry, @{$_}) }
          cyclic_permute(@phrases); }
      else {
        $self->add_entry($doc, $allkeys, $allphrases, $tree, $entry, @phrases); } }
    return ($allkeys, $allphrases, $tree); }
  else {
    return (undef, undef, undef); } }

# NOTE: We're building ID's for each entry, of the form idx.key.key...
# I'd like to insert the initial in the case of split index: idx.A.key.key...
# But this makes it impossible to predict the id of a phrase key, w/o knowing
# whether the index has been split!
# OTOH, leaving it out risks that a single letter entry, say "A", will have the
# same id as the A page! (or maybe not if the key is downcased....)
sub add_entry {
  my ($self, $doc, $allkeys, $allphrases, $tree, $entry, @phrases) = @_;
  # NOTE: Still need option for splitting!
  # We'll just prefix a level for the initial...
  if ($$self{split}) {
    my $init    = $doc->initial($phrases[0]->getAttribute('key'));
    my $subtree = $$tree{subtrees}{$init};
    if (!$subtree) {
      $subtree = $$tree{subtrees}{$init}
        = { phrase => $init, subtrees => {}, referrers => {}, id => $$tree{id}, parent => $tree }; }
    add_rec($doc, $allkeys, $allphrases, $subtree, $entry, @phrases); }
  else {
    add_rec($doc, $allkeys, $allphrases, $tree, $entry, @phrases); }
  return; }

sub add_rec {
  my ($doc, $allkeys, $allphrases, $tree, $entry, @phrases) = @_;
  if (@phrases) {
    my $phrase  = shift(@phrases);
    my $key     = $phrase->getAttribute('key');
    my $subtree = $$tree{subtrees}{$key};
    if (!$subtree) {    # clone the phrase ??
      my $id         = $$tree{id} . '.' . $key;
      my $fullkey    = ($$tree{key} ? "$$tree{key}." : '') . $key;
      my $phrasetext = $phrase->textContent;
      $phrasetext =~ s/^\s*//; $phrasetext =~ s/\.\s*$//; $phrasetext =~ s/\s+/ /g;
      $$allphrases{$phrasetext}{$key} = 1;
      $$allphrases{ lc($phrasetext) }{$key} = 1;
      my $fullphrasetext = ($$tree{fullphrasetext} ? $$tree{fullphrasetext} . ' ' : '') . $phrasetext;
      $$allphrases{$fullphrasetext}{$fullkey} = 1;
      $$allphrases{ lc($fullphrasetext) }{$fullkey} = 1;
      my $phrasecopy = $doc->cloneNode($phrase);
      $subtree = $$tree{subtrees}{$key} = { key => $fullkey, id => $id,
        phrase         => $phrasecopy,
        phrasetext     => $phrasetext,
        fullphrasetext => $fullphrasetext,
        subtrees       => {}, referrers => {}, parent => $tree };
      $$allkeys{$fullkey} = { id => $id,
        phrases => [($$tree{key} ? @{ $$allkeys{ $$tree{key} }{phrases} } : ()), " ",
          $doc->trimChildNodes($phrasecopy)] };
    }
    add_rec($doc, $allkeys, $allphrases, $subtree, $entry, @phrases); }
  else {
    if (my $seealso = $entry->getValue('see_also')) {
      $$tree{see_also} = $seealso; }
    if (my $refs = $entry->getValue('referrers')) {
      map { $$tree{referrers}{$_} = $$refs{$_} } keys %$refs; } }
  return; }

# ================================================================================
# Generate permutations of indexing phrases.
sub permute {
  my (@l) = @_;
  if (scalar(@l) > 1) {
    return map { permute_aux($l[$_], @l[0 .. $_ - 1], @l[$_ + 1 .. $#l]) } 0 .. $#l; }
  else {
    return [@l]; } }

sub permute_aux {
  my ($first, @rest) = @_;
  return map { [$first, @$_] } permute(@rest); }

# Or would cyclic permutations be more appropriate?
#  We could get odd orderings, if authors aren't consistent,
# but would avoid silly redundancies in small top-level listings.
sub cyclic_permute {
  my (@l) = @_;
  if (scalar(@l) > 1) {
    return map { [@l[$_ .. $#l], @l[0 .. $_ - 1]] } 0 .. $#l; }
  else {
    return [@l]; } }

# ================================================================================
# Formatting the resulting index tree.

# Sorting comparison that puts different cases together
sub alphacmp {
  return (lc($a) cmp lc($b)) || ($a cmp $b); }

sub makeIndexList {
  my ($self, $doc, $allkeys, $allphrases, $tree) = @_;
  my $subtrees = $$tree{subtrees};
  if (my @keys = sort alphacmp keys %$subtrees) {
    return ['ltx:indexlist', {},
      map { $self->makeIndexEntry($doc, $allkeys, $allphrases, $$subtrees{$_}) } @keys]; }
  else {
    return (); } }

sub makeIndexEntry {
  my ($self, $doc, $allkeys, $allphrases, $tree) = @_;
  my $refs    = $$tree{referrers};
  my $seealso = $$tree{see_also};
  my @links   = ();
  # Note sort of keys here is questionable!
  if (keys %$refs) {
    push(@links, ['ltx:text', {}, ' '],
      conjoin(map { $self->makeIndexRefs($doc, $_, sort alphacmp keys %{ $$refs{$_} }) }
          sort alphacmp keys %$refs)); }
  if ($seealso) {
    my %saw = ();
    foreach my $see (@$seealso) {
      push(@links, ', ');    # if @links;
      if (my $name = $see->getAttribute('name')) {
        push(@links, ['ltx:text', { font => 'italic' }, $name, ' ']); }
      # There seem to be different usage idioms for where a seealso should actually point,
      # within a multi-level index.  We'll try to go up level by level till we hit "global"
      # until we find an actual entry.
      my $key    = $see->getAttribute('key');
      my $phrase = $see->textContent;
      $phrase =~ s/^\s*//; $phrase =~ s/\.\s*$//; $phrase =~ s/\s+/ /g;
      if (my $entry = $self->seealsoSearch($doc, $allkeys, $allphrases, $tree, $key, $phrase)) {
        push(@links, ['ltx:ref', { idref => $$entry{id} }, $see->childNodes]) unless $saw{ $$entry{id} };
        $saw{ $$entry{id} } = 1; }
      else {
        my @alt = sort keys %{ $$allphrases{$phrase} };
        Warn('expected', $phrase, undef,
          "Missing index see-also term $phrase", "(key=$key; seen under $$tree{key})",
          (@alt ? " Possible aliases: " . join(', ', @alt) : ""))
          unless $doc->findnodes("descendant-or-self::ltx:ref", $see);
        push(@links, ['ltx:text', {}, $see->childNodes]); } } }

  return ['ltx:indexentry', { 'xml:id' => $$tree{id} },
    ['ltx:indexphrase', {}, $doc->trimChildNodes($$tree{phrase})],
    (@links ? (['ltx:indexrefs', {}, @links]) : ()),
    $self->makeIndexList($doc, $allkeys, $allphrases, $tree)]; }

# Fishing expedition: Try to find what a See Also phrase might refer to
# [They don't necessarily match in obvious ways]
# See also terms can't use the sort_as@present_as formula, tho they sometimes need to.
# If we didn't find the see-as term, look to see if the text matches some other entry we've se
sub seealsoSearch {
  my ($self, $doc, $allkeys, $allphrases, $tree, $key, $phrase) = @_;
  # concoct various phrases to search for
  my $pnc  = $phrase; $pnc =~ s/,\s*/ /g;
  my $ps   = $phrase; $ps =~ s/(\w+)s\b/$1/g;
  my $psnc = $ps;     $psnc =~ s/,\s*/ /g;
  foreach my $trial ($phrase, $pnc, lc($pnc), $ps, lc($ps), $psnc, lc($psnc)
    ) {
    my $entry = $self->seealsoSearch_aux($doc, $allkeys, $allphrases, $tree, $key, $pnc);
    return $entry if $entry; }
  return; }

sub seealsoSearch_aux {
  my ($self, $doc, $allkeys, $allphrases, $tree, $key, $phr) = @_;
  my $t = $tree;
  my $entry;
  while ($t && !$entry) {
    my $pre = $$t{key} ? $$t{key} . "." : '';
    foreach my $k ($key, keys %{ $$allphrases{$phr} }) {
      last if $entry = $$allkeys{ $pre . $k }; }
    $t = $$t{parent}; }
  return $entry; }

# Given that sorted styles gives bold, italic, normal,
# let's just do the first.
sub makeIndexRefs {
  my ($self, $doc, $id, @styles) = @_;
  return ((($styles[0] || 'normal') ne 'normal')
    ? ['ltx:text', { font => $styles[0] }, ['ltx:ref', { idref => $id }]]
    : ['ltx:ref', { idref => $id }]); }

# ================================================================================
sub conjoin {
  my (@items) = @_;
  my @result = ();
  if (@items) {
    push(@result, shift(@items));
    while (@items) {
      push(@result, ", ", shift(@items)); } }
  return @result; }

# ================================================================================
1;

