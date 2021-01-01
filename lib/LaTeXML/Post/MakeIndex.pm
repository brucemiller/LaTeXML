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
use Unicode::Normalize;
use LaTeXML::Post;
use Text::Unidecode;
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
  my ($tree, $allphrases) = $self->build_tree($doc, $index);
  if ($tree) {
    if ($$self{split}) {
      @indices = map { $self->rescan($_) }
        $self->makeSubCollectionDocuments($doc, $index,
        map { ($_ => $self->makeIndexList($doc, $allphrases, $$tree{subtrees}{$_})) }
          keys %{ $$tree{subtrees} }); }
    else {
      $doc->addNodes($index, $self->makeIndexList($doc, $allphrases, $tree));
      @indices = ($self->rescan($doc)); } }
  return @indices; }

# ================================================================================
# Data generated:
#  $tree : tree representation of the index.
#  $allphrases : used for inferring the connection from see-also phrases to normal index entries.
# ================================================================================
# Extracting a tree of index entries from the database
sub build_tree {
  my ($self, $doc, $index) = @_;
  my $defaultlistname = 'idx';
  my $listname        = 'idx';    # Eventually customizable for different indices?
  if (my @keys = grep { /^INDEX:/ } $$self{db}->getKeys) {
    NoteStatus(2, "MakeIndex: " . scalar(@keys) . " entries");

    my $id         = $index->getAttribute('xml:id');
    my $allphrases = {};          # Keep a hash of all phrase textContent=>id encountered (for seealso)
    my $tree       = { subtrees => {}, referrers => {}, id => $id, parent => undef };
    foreach my $key (@keys) {
      my $entry   = $$self{db}->lookup($key);
      my $phrases = $entry->getValue('phrases');
      my @phrases = @$phrases;
      if (($entry->getValue('inlist') || $defaultlistname) ne $listname) {
        next; }                   # Skip any not in this list
      if (!scalar(@phrases)) {
        Warn('expected', $key, undef, "Missing phrases in indexmark: '$key'");
        next; }

      if ($$self{permuted}) {
        map { $self->add_entry($doc, $allphrases, $tree, $entry, @{$_}) }
          cyclic_permute(@phrases); }
      else {
        $self->add_entry($doc, $allphrases, $tree, $entry, @phrases); } }
    return ($tree, $allphrases); }
  else {
    return (undef, undef); } }

# NOTE: We're building ID's for each entry, of the form idx.key.key...
# I'd like to insert the initial in the case of split index: idx.A.key.key...
# But this makes it impossible to predict the id of a phrase key, w/o knowing
# whether the index has been split!
# OTOH, leaving it out risks that a single letter entry, say "A", will have the
# same id as the A page! (or maybe not if the key is downcased....)
sub add_entry {
  my ($self, $doc, $allphrases, $tree, $entry, @phrases) = @_;
  # NOTE: Still need option for splitting!
  # We'll just prefix a level for the initial...
  if ($$self{split}) {
    my $init    = $doc->initial($phrases[0]->getAttribute('key'));
    my $subtree = $$tree{subtrees}{$init};
    if (!$subtree) {
      $subtree = $$tree{subtrees}{$init}
        = { phrase => $init, subtrees => {}, referrers => {}, id => $$tree{id}, parent => $tree }; }
    add_rec($doc, $allphrases, $subtree, $entry, @phrases); }
  else {
    add_rec($doc, $allphrases, $tree, $entry, @phrases); }
  return; }

sub add_rec {
  my ($doc, $allphrases, $tree, $entry, @phrases) = @_;
  if (@phrases) {
    my $phrase  = shift(@phrases);
    my $key     = $phrase->getAttribute('key');
    my $keyid   = getIndexKeyID($key);
    my $subtree = $$tree{subtrees}{$key};
    if (!$subtree) {
      my $id      = $$tree{id} . '.' . $keyid;
      my $fullkey = ($$tree{key} ? "$$tree{key}." : '') . $key;
      # phrasetext is for see & seealso lookup
      my $phrasetext = getIndexContentKey($phrase);
      # Store multi-level phrase as well, using space to separate levels
      my $fullphrasetext = ($$tree{fullphrasetext} ? $$tree{fullphrasetext} . ' ' : '')
        . $phrasetext;
      $$allphrases{$fullkey}              = $id;
      $$allphrases{ lc($fullkey) }        = $id;
      $$allphrases{$fullphrasetext}       = $id;
      $$allphrases{ lc($fullphrasetext) } = $id;

      my $phrasecopy = $doc->cloneNode($phrase);
      $subtree = $$tree{subtrees}{$key} = { key => $fullkey, id => $id,
        phrase         => $phrasecopy,
        phrasetext     => $phrasetext,
        fullphrasetext => $fullphrasetext,
        subtrees       => {}, referrers => {}, parent => $tree };
    }
    add_rec($doc, $allphrases, $subtree, $entry, @phrases); }
  else {
    if (my $seealso = $entry->getValue('see_also')) {
      $$tree{see_also} = $seealso; }
    if (my $refs = $entry->getValue('referrers')) {
      map { $$tree{referrers}{$_} = $$refs{$_} } keys %$refs; } }
  return; }

# Extract the text from the (xml) phrase node, with some normalization.
sub getIndexContentKey {
  my ($node) = @_;
  my $string = (ref $node ? $node->textContent : $node);
  $string =~ s/^\s+//s;
  $string =~ s/\s+$//s;
  $string =~ s/\s+/ /gs;
  $string =~ s/\s*[\.\,\;]+$//s;    # Remove trailing punctuation
  return $string; }

# This generates the ID from the node
# By stripping non-letters, this strips out TOO MUCH; esp. greek etc, in math disappears
# Should we keep unicode? (any compatibility issues there?0
# Should we just strip to rfc spec?
# Should we get the TeX for math?
my %GREEK_ASCII_MAP = (
  "\x{03B1}" => 'alpha',   "\x{03B2}" => 'beta',       "\x{03B3}" => 'gamma', "\x{03B4}" => 'delta',
  "\x{03F5}" => 'epsilon', "\x{03B5}" => 'varepsilon', "\x{03B6}" => 'zeta',  "\x{03B7}" => 'eta',
  "\x{03B8}" => 'theta',   "\x{03D1}" => 'vartheta',   "\x{03B9}" => 'iota',  "\x{03BA}" => 'kappa',
  "\x{03BB}" => 'lambda',  "\x{03BC}" => 'mu',         "\x{03BD}" => 'nu',    "\x{03BE}" => 'xi',
  "\x{03C0}" => 'pi',      "\x{03D6}" => 'varpi',      "\x{03C1}" => 'rho',   "\x{03F1}" => 'varrho',
  "\x{03C3}" => 'sigma',   "\x{03C2}" => 'varsigma',   "\x{03C4}" => 'tau',   "\x{03C5}" => 'upsilon',
  "\x{03D5}" => 'phi',     "\x{03C6}" => 'varphi',     "\x{03C7}" => 'chi',   "\x{03C8}" => 'psi',
  "\x{03C9}" => 'omega',   "\x{0393}" => 'Gamma',      "\x{0394}" => 'Delta', "\x{0398}" => 'Theta',
  "\x{039B}" => 'Lambda',  "\x{039E}" => 'Xi',         "\x{03A0}" => 'Pi',    "\x{03A3}" => 'Sigma',
  "\x{03A5}" => 'Upsilon', "\x{03A6}" => 'Phi',        "\x{03A8}" => 'Psi',   "\x{03A9}" => 'Omega');
my $GREEK_RE = '(' . join('|', sort keys %GREEK_ASCII_MAP) . ')';

sub getIndexKeyID {
  my ($key) = @_;
  $key =~ s/^\s+//s; $key =~ s/\s+$//s;    # Trim leading/trailing, in any case
      # We don't want accented chars (do we?) but we need to decompose the accents!
  $key = NFD($key);
  $key =~ s/$GREEK_RE/$GREEK_ASCII_MAP{$1}/eg;
  $key = unidecode($key);
  $key =~ s/[^a-zA-Z0-9]//g;
## Shouldn't be case insensitive?
##  $key =~ tr|A-Z|a-z|;
  return $key; }

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

sub makeIndexList {
  my ($self, $doc, $allphrases, $tree) = @_;
  my $subtrees = $$tree{subtrees};
  if (my @keys = $doc->unisort(keys %$subtrees)) {
    return ['ltx:indexlist', {},
      map { $self->makeIndexEntry($doc, $allphrases, $$subtrees{$_}) } @keys]; }
  else {
    return (); } }

sub makeIndexEntry {
  my ($self, $doc, $allphrases, $tree) = @_;
  my $refs    = $$tree{referrers};
  my $seealso = $$tree{see_also};
  my @links   = ();
  if (keys %$refs) {
    push(@links, ['ltx:text', {}, ' '], $self->combineIndexEntries($doc, $refs)); }
  if ($seealso) {
    my %saw = ();
    foreach my $see (@$seealso) {
      push(@links, ', ');    # if @links;
      if (my $name = $see->getAttribute('name')) {
        push(@links, ['ltx:text', { font => 'italic' }, $name, ' ']); }
      my $phrase = getIndexContentKey($see);
      if (my @seelinks = $self->seealsoSearch($doc, $allphrases, $tree, $see)) {
        push(@links, @seelinks); }
      else {
        Warn('expected', $phrase, undef,
          "Missing index see-also term '$phrase'", "(seen under $$tree{key})")
          unless $doc->findnodes("descendant-or-self::ltx:ref", $see);
        push(@links, ['ltx:text', {}, $see->childNodes]); } } }

  return ['ltx:indexentry', { 'xml:id' => $$tree{id} },
    ['ltx:indexphrase', {}, $doc->trimChildNodes($$tree{phrase})],
    (@links ? (['ltx:indexrefs', {}, @links]) : ()),
    $self->makeIndexList($doc, $allphrases, $tree)]; }

# Sorting comparison that puts different cases together
# Really, it's only used for id's... (would like an id-sort!)
sub alphacmp {
  return (lc($a) cmp lc($b)) || ($a cmp $b); }

# combine a set of links into the document; this corresponds to the list of page numbers.
# we want them sorted in document order, but also want to combine the end points of ranges.
sub combineIndexEntries {
  my ($self, $doc, $refs) = @_;
  my @ids = sort alphacmp keys %$refs;
  #   my @ids = $doc->unisort(keys %$refs);
  my @links = ();
  while (@ids) {
    my $id    = shift(@ids);
    my $entry = $$refs{$id};
    if ($$entry{rangestart}) {
      my $startid = $id;
      my $endid   = $id;
      my $lvl     = 1;
      while (@ids) {
        $endid = shift(@ids);
        $lvl-- if $$refs{$endid}{rangestart};
        $lvl-- if $$refs{$endid}{rangeend};
        last unless $lvl; }
      push(@links,
        ['ltx:text', {},
          $self->makeIndexRefs($doc, $startid,
            grep { $_ ne 'rangestart' } sort keys %$entry),
          "\x{2014}",
          $self->makeIndexRefs($doc, $endid,
            grep { $_ ne 'rangeend' } sort keys %{ $$refs{$endid} })]); }
    else {
      push(@links, $self->makeIndexRefs($doc, $id, sort keys %$entry)); } }
  return conjoin(@links); }

# Make a single ref to a "page", in a particular style.
# Given that sorted styles gives bold, italic, normal,
# let's just do the first.
sub makeIndexRefs {
  my ($self, $doc, $id, @styles) = @_;
  return ((($styles[0] || 'normal') ne 'normal')
    ? ['ltx:text', { font => $styles[0] }, ['ltx:ref', { idref => $id, show => 'typerefnum' }]]
    : ['ltx:ref', { idref => $id, show => 'typerefnum' }]); }

#======================================================================
# Dealing with See & Seealso entries.
# A LOTTA work, for such a little thing!

# Regular index entries, possibly with several levels, are somewhat
# structured & formalized: they need to match so that entries can be combined;
# they also optionally allow for a sort (& comparison) key.
# Seealso entries, are not so structured; there's no provision for a sort key.
# They USUALLY will refer to another regular index entry, but aren't required to.
# It is nice to LINK such a seealso entry to the corresponding regular entry, if possible!

# So, we go on a fishing expedition to find possible phrases.
# I find several idioms in use (but perhaps biased by DLMF):
# (1) "topic" may refer to top-level "topic", or one within the current subtree
# (2) "topic1, topic2 and topic3" may refer to a single entry, or may refer to 3 separate entries.
# (3) "topic1 topic2" or "topic1, topic2" may refer to a single entry, or may refer
#     to a 2 level entry like \index(topic1|topic2)
# And finally, case & plural differences may indicate distinct top-level concepts,
# or may simply be insignificant variations in phrasing!

sub seealsoSearch {
  my ($self, $doc, $allphrases, $contexttree, $see) = @_;
  return seealsoSearch_rec($doc, $allphrases, $contexttree, seealsoPartition($doc, $see)); }

# @parts are alternating (potential) term, (potential) delimiter, ...
sub seealsoSearch_rec {
  my ($doc, $allphrases, $contexttree, @parts) = @_;
  my ($link, @links);
  if    (scalar(@parts) < 1) { return (); }
  elsif (scalar(@parts) < 3) {
    # Single term? (w/ possible trailing punct) just look it up
    if ($link = lookupSeealsoPhrase($doc, $allphrases, $contexttree, $parts[0])) {
      return ($link, ($parts[1] ? cdr($parts[1]) : ())); } }
  # try first delimiter "literally" (possibly reiterpretedy by lookupSeealsoPhrase)
  # recurse, so that all alternatives of next delimiter will be considered.
  elsif (@links = seealsoSearch_rec($doc, $allphrases, $contexttree,
      seealsoJoin(@parts[0 .. 2]), @parts[3 .. $#parts])) {
    return @links; }
  # try any delimiter as possibly a separator between individual entries;
  # and recurse to handle next delimiter
  elsif (($link = lookupSeealsoPhrase($doc, $allphrases, $contexttree, $parts[0]))
    && (@links = seealsoSearch_rec($doc, $allphrases, $contexttree,
        @parts[2 .. $#parts]))) {
    return ($link, cdr($parts[1]), @links); }
  return; }

sub car { return $$_[0][0]; }

sub cdr {
  my ($key, @xml) = @{ $_[0] };
  return @xml; }

# Reassemble a partition (list of [key,xml] pairs) into a single such pair.
sub seealsoJoin {
  my (@parts) = @_;
  return [getIndexContentKey(join('', map { $$_[0] } @parts)), map { cdr($_) } @parts]; }

# Look for single phrase either within one of the levels of the current $contexttree,
# or at top-level. Try it as-is, or ignoring commas, and/or case-differences.
sub lookupSeealsoPhrase {
  my ($doc, $allphrases, $contexttree, $pair) = @_;
  my ($phrase, @xml) = @$pair;
  # concoct various phrases to search for
  my $pnc   = $phrase; $pnc   =~ s/,\s*/ /sg;         # Ignore punct?
  my $ps    = $phrase; $ps    =~ s/(\w+)s\b/$1/sg;    # Ignore plurals?
  my $psnc  = $ps;     $psnc  =~ s/,\s*/ /sg;         # Ignore punct AND plurals?
  my $pnlvl = $phrase; $pnlvl =~ s/,\s*/./sg;         # Convert punct to levels?
  foreach my $trial ($phrase, lc($phrase),
    $pnc,   lc($pnc),
    $ps,    lc($ps),
    $psnc,  lc($psnc),
    $pnlvl, lc($pnlvl),
  ) {
    my $t = $contexttree;
    while ($t) {
      if (my $id = $$allphrases{ ($$t{fullphrasetext} ? $$t{fullphrasetext} . " " : '') . $trial }) {
        return ['ltx:ref', { idref => $id }, @xml]; }
      $t = $$t{parent}; } }
  return; }

# Partition a seealso (xml) phrase into a sequence of alternating
#   candidate index phrases (which will be looked up)
#   candidate delimiters (which potentially split the phrase or not;
#      see discussion above about delimiters).
# This is analogous to a simple split, but that
# (a) the argument is XML, with the pieces of delimiter ("," space, "and"...)
#    potentially distributed amongst distinct xml elements, due to styling.
# (b) we want to preserve the XML associated with each phrase & delimiter
#    in order to fill-in and separate the resulting ltx:ref's
# Messy!
sub seealsoPartition {
  my ($doc, $see) = @_;
  my @parts = seealsoPartition_aux($doc, $see);
  # Combine adjacent conjunctions & punctuation chunks
  my @result = (shift(@parts));
  while (@parts) {
    my $next    = shift(@parts);
    my $prev_is = ($result[-1][0] =~ /^,?\s*(?:,|\.|\s+|\band\s+also|\band|\bor)\s*$/);
    my $next_is = ($$next[0]      =~ /^(?:,|\.|\s+|and\b|or\b)/);
    # If either BOTH or NEITHER prev & next are delimiters, combine them.
    if (!($prev_is xor $next_is)) {
      my ($k, @x) = @$next;
      $result[-1][0] .= $k;
      push(@{ $result[-1] }, @x); }
    else {
      push(@result, $next); } }
  # Now merge any adjacent phrase and/or space chunks into candidate phrase
  @parts = @result; @result = (shift(@parts));
  while (@parts) {
    my $next = shift(@parts);
    # If next is pure space, combine with prev AND following!
    if (($$next[0] =~ /^\s+$/s) && scalar(@parts)) {
      my ($k1, @x1) = @$next;
      my ($k2, @x2) = @{ shift(@parts) };
      $result[-1][0] .= $k1 . $k2;
      push(@{ $result[-1] }, @x1, @x2); }
    else {
      push(@result, $next); } }
  return @result; }

# Recursively split the XML $see into pure phrase or delimiter chunks.
# we'll still need to combine adjacent chunks appropriately (see above).
sub seealsoPartition_aux {
  my ($doc, $see) = @_;
  my @result = ();
  foreach my $ch ($see->childNodes) {
    my $t = $ch->nodeType;
    if ($t == XML_TEXT_NODE) {
      my $string = $ch->textContent;
      while ($string) {
        if ($string =~ s/^(,|\.|\s+|and\s+also\b|and\b|or\b)//) {
          push(@result, [$1, $1]); }
        elsif ($string =~ s/^([^,\.\s]+)//) {
          push(@result, [getIndexContentKey($1), $1]); } }
      push(@result, [getIndexContentKey($string), $string]) if $string; }
    elsif ($t != XML_ELEMENT_NODE) { }
    else {
      my $tag = $doc->getQName($ch);
      if ($tag =~ /^(ltx:text|ltx:emph)$/) {
        my $attr = { map { ($_ => $ch->getAttribute($_)) } $ch->attributes };
        push(@result, map { [$$_[0], [$tag, $attr, cdr($_)]] } seealsoPartition_aux($doc, $ch)); }
      else {
        push(@result, [getIndexContentKey($ch), $ch]); }
  } }
  return @result; }

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

