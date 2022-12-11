# /=====================================================================\ #
# |  LaTeXML::Post::MakeBibliography                                    | #
# | Make an bibliography from cited entries                             | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Post::MakeBibliography;
use strict;
use warnings;
use LaTeXML::Util::Pathname;
use LaTeXML::Common::XML;
use LaTeXML::Util::Radix;
use charnames qw(:full);
use LaTeXML::Post;
use base qw(LaTeXML::Post::Collector);

# These are really constant, but set at bottom, for readability
our %FMT_SPEC;      # CONSTANT
our @META_BLOCK;    # CONSTANT

# Options:
#   bibliographies : list of xml file names containing bibliographies (from bibtex)
#   split  : whether the split into separate pages by initial.
# NOTE:
#  Ultimately needs to respond to the desired bibligraphic style
#     Currently set up primarily for author-year
#     What about numerical citations? (how would we split the bib?)
#     But we should presumably encode a number anyway...
sub new {
  my ($class, %options) = @_;
  my $self = $class->SUPER::new(%options);
  $$self{split}          = $options{split};
  $$self{bibliographies} = $options{bibliographies};
  return $self; }

sub toProcess {
  my ($self, $doc) = @_;
  return $doc->findnodes('//ltx:bibliography'); }

# Whooo, this is turning into a confusing API!
# Potentially multiple biblist's in each document
# potentially each one split into multiple output documents (need that option!)
# Inevitably duplicates?
sub process {
  my ($self, $doc, @bibs) = @_;
  my @docs = ($doc);
  foreach my $bib (@bibs) {
    next if $doc->findnodes('.//ltx:bibitem', $bib);    # Already populated?

    local $LaTeXML::Post::MakeBibliography::NUMBER = 0;
    local %LaTeXML::Post::MakeBibliography::STYLE =
      (map { ($_ => $bib->getAttribute($_)) } qw(bibstyle citestyle sort));

    my $entries = $self->getBibEntries($doc, $bib);
    # Remove any bibentry's (these should have been converted to bibitems)
    $doc->removeNodes($doc->findnodes('//ltx:bibentry'));
    foreach my $biblist ($doc->findnodes('//ltx:biblist')) {
      $doc->removeNodes($biblist) unless element_nodes($biblist); }

    if ($$self{split}) {
      # Separate by initial.
      my $split = {};
      foreach my $sortkey (keys %$entries) {
        my $entry = $$entries{$sortkey};
        $$split{ $$entry{initial} }{$sortkey} = $entry; }
      @docs = map { $self->rescan($_) }
        $self->makeSubCollectionDocuments($doc, $bib,
        map { ($_ => $self->makeBibliographyList($doc, $bib, $_, $$split{$_})) }
          sort keys %$split); }
    else {
      $doc->addNodes($bib, $self->makeBibliographyList($doc, $bib, undef, $entries));
      #      @docs = ($self->rescan($doc)); }
      $self->rescan($doc); } }
  return @docs; }

# ================================================================================
# Bibliographies can be specified either
#  within the document (on ltx:bibliography, due to \bibliography{foo}
#  or from an option to new (typically coming from the command line).
# The commandline option OVERRIDES the internal list (to avoid clashes)
#
# In the fist case, we only get names, (no bib extension, let alone xml)
# but we should look for pre-compiled versions of the bib anyway (pref foo.bib.xml)
# In the latter case, we may get pathnames OR literals OR even an XML Document object.
# literals can be bibtex (but eventually serialized XML should be allowed).
# When XML is supplied, it is assumed to contain an ltx:bibliography containing a ltx:biblist.
# In principle, we ought to look for named files also in the file cache (eg. from {filecontents})
sub getBibliographies {
  my ($self, $doc) = @_;
  my @bibnames         = ();
  my $fromBibliography = 0;    # coming from an 'ltx:bibliography'
                               # use the commandline bibliographies, if explicitly given.
  if ($$self{bibliographies} && scalar(@{ $$self{bibliographies} })) {
    @bibnames = @{ $$self{bibliographies} }; }
  else {
    my $bibnode = $doc->findnode('//ltx:bibliography');
    if (my $files = $bibnode->getAttribute('files')
      || $bibnode->parentNode->getAttribute('files')    # !!!!!
    ) {
      $fromBibliography = 1;
      @bibnames         = split(',', $files); } }
  my @paths   = $doc->getSearchPaths;
  my @bibs    = ();
  my @rawbibs = ();
 # Collect the "ready" bibliographies, while accumulating all raw sources for a single conversion pass
  foreach my $bib (@bibnames) {
    my $ref = ref $bib;
    my $bibdoc;
    if ($ref && ($ref eq 'LaTeXML::Post::Document')) {    # It's already a Post::Document (somehow).
      $bibdoc = $bib; }
    elsif ($ref && ($ref eq 'XML::LibXML::Document')) {    # Or it's a raw XML document?
      $bibdoc = $doc->new($bib, sourceDirectory => '.'); }
    elsif ($ref) {
      Error('unexpected', $ref, $self,
        "Don't know how to convert '$bib' (a '$ref') into a Bibliography document"); }
    elsif (pathname_is_literaldata($bib)) {
      push(@rawbibs, $bib);
      next; }
    elsif ($bib =~ /\.xml$/) {
      $bibdoc = $doc->newFromFile($bib); }    # doc will do the searching...
    elsif ($bib =~ /\.bib(?:\.xml)?$/ || $fromBibliography) {
      # NOTE: We should also use kpsewhich to get the effects of $BIBINPUTS?
      # NOTE: When better integrated with Core, should also check for cached bib documents.
      my $xmlbib = $bib;
      $xmlbib .= '.bib' if $fromBibliography && !($xmlbib =~ /\.bib$/);
      if (my $xmlpath = pathname_find($xmlbib, paths => [@paths], types => ['xml'])) {
        $bibdoc = $doc->newFromFile($xmlpath); }    # doc will do the searching...
      elsif (my $bibpath = pathname_find($bib, paths => [@paths], types => ['bib'])
        || pathname_kpsewhich($bib)) {
        push(@rawbibs, $bibpath);
        next; }
      else {
        Error('missing_file', $bib, $self,
          "Couldn't find Bibliography '$bib'",
          "Searchpaths were " . join(',', @paths)); } }
    if ($bibdoc) {
      push(@bibs, $bibdoc); }
    else {
      Info('expected', $bib, $self,
        "Couldn't find usable Bibliography for '$bib'"); } }
  # Lastly, If we found any raw .bib files/literaldata, convert and include them.
  if (@rawbibs) {
    my $raw;
    if (scalar(@rawbibs) == 1) {    # Single, just convert as-is
      $raw = $rawbibs[0]; }
    else {
      $raw = 'literal:';
      for my $rawbib (@rawbibs) {    # Multiple, arrange into a single conversion payload
        if ($rawbib =~ s/literal\://) {
          $raw .= $rawbib; }
        else {
          # TODO: Is this a memory concern for large bib files?
          if (open(my $bibfh, '<', $rawbib)) {
            $raw .= join("", <$bibfh>);
            close $bibfh; }
          else {
            Info("open", $rawbib, $self, "Couldn't open file $rawbib"); } }
        $raw .= "%\n"; } }
    my $bibdoc = $self->convertBibliography($doc, $raw);
    push(@bibs, $bibdoc) if $bibdoc; }
  NoteLog("MakeBibliography: using bibliographies "
      . join(',', map { (length($_) > 100 ? substr($_, 100) . '...' : $_) } @bibnames)
      . "]");
  return @bibs; }

# This converts a bib into the corresponding XML
# $bib is either a filename or literal
# Note that for multiple bibliographies it is inefficient to prepare a session for EACH.
# However, we really shouldn't be preparing a new session anyway:
# In general, it should use the same STATE information as the main document,
# so IF that state is still around, we should use it!
# That's for future enhancement!!!
# Also, it probably doesn't make sense for the session to capture the log output;
# it should just continue dribbling out whereever it usually would go.
sub convertBibliography {
  my ($self, $doc, $bib) = @_;
  require LaTeXML;
  require LaTeXML::Common::Config;
  my @preload = ();    # custom macros often used in e.g. howpublished field
                       # need to preload all packages used by the main article
  my ($classdata, @packages)     = $self->find_documentclass_and_packages($doc);
  my ($class,     $classoptions) = @$classdata;
  if ($class) {

    if ($classoptions) {
      push(@preload, "[$classoptions]$class.cls"); }
    else {
      push(@preload, "$class.cls"); } }
  foreach my $po (@packages) {
    my ($pkg, $options) = @$po;
    if ($options) {
      push(@preload, "[$options]$pkg.sty"); }
    else {
      push(@preload, "$pkg.sty"); } }
  my $bibname = pathname_is_literaldata($bib) ? 'Anonymous Bib String' : $bib;
  my $stage   = "Recursive MakeBibliography $bibname";
  ProgressSpinup($stage);
  my $bib_config = LaTeXML::Common::Config->new(
    recursive      => 1,
    cache_key      => 'BibTeX',
    type           => "BibTeX",
    post           => 0,
    format         => 'dom',
    whatsin        => 'document',
    whatsout       => 'document',
    includestyles  => 1,
    bibliographies => [],
    paths          => $$doc{searchpaths},
    (@preload ? (preload => [@preload]) : ()));
  my $bib_converter = LaTeXML->get_converter($bib_config);
  # Tricky and HACKY, we need to release the log to capture the inner workings separately.
  # ->bind_log analog:
  my $biblog = '';
###  my $biblog_handle;
###  open($biblog_handle, ">>", \$biblog) or Error("Can't redirect STDERR to log for inner bibliography converter!");
###  *BIB_STDERR_SAVED = *STDERR;
###  *STDERR           = *$biblog_handle;
  # end ->bind_log

  $bib_converter->prepare_session($bib_config);
  my $response = $bib_converter->convert($bib);

  # ->flush_log analog:
###  close $biblog_handle;
###  *STDERR = *BIB_STDERR_SAVED;
  # end ->flush_log

  # Trim log to look internal and report.
###  $biblog =~ s/^.+?\(Digesting/\n\(Digesting/s;
###  $biblog =~ s/Conversion complete:.+$//s;
###  print STDERR $biblog;
  MergeStatus($$bib_converter{latexml}{state});

  ProgressSpindown($stage);
  if (my $bibdoc = $$response{result}) {
    return $doc->new($bibdoc, sourceDirectory => '.'); }
  return; }

# ================================================================================
# Get all cited bibentries from the requested bibliography files.
# Sort (cited) bibentries on author+year+title, [NOT on the key, or even proper BibTeX choices!!!]
# and then check whether author+year is unique!!!
# Returns a list of hashes containing:
#  bibkey : the bibliographic entry's key
#  citedkey : the key as cited (can be different in case)
#  bibentry : the bibentry node
#  citations : array of bib keys that are cited somewhere within this bibentry
#  referrers : array of ID's of places that refer to this bibentry
#  suffix    : a,b... if adjacent author/year are identical.
# NOTE: biblist's now have @lists to restrict to include ONLY
# those bibitems which have been referenced by bibref's for one of those lists!
# [If a bibref gives several lists, and entries for those lists end up in several bibliographies,
# first 'list' determines where the idref points]
sub getBibEntries {
  my ($self, $doc, $bib) = @_;

  # First, scan the bib files for all ltx:bibentry's,
  # %entries is  a hash with the key in lowercase!
  # Also, record the citations from each bibentry to others.
  my %entries = ();
  foreach my $bibdoc ($self->getBibliographies($doc)) {
    my @lists = split(/\s+/, $doc->findnode('//ltx:bibliography')->getAttribute('lists') || 'bibliography');
    foreach my $bibentry ($bibdoc->findnodes('//ltx:bibentry')) {
      my $bibkey   = $bibentry->getAttribute('key');
      my $lcbibkey = lc($bibkey);
      my $bibid    = $bibentry->getAttribute('xml:id');
      $entries{$lcbibkey}{bibkey}    = $bibkey;
      $entries{$lcbibkey}{bibentry}  = $bibentry;
      $entries{$lcbibkey}{citations} = [grep { $_ } map { split(',', $_->value) }
          $bibdoc->findnodes('.//@bibrefs', $bibentry)]; } }
  # Now, collect all bibkeys that were cited in other documents (NOT the bibliography)
  # And note any referrers to them (also only those outside the bib)
  my @lists    = split(/\s+/, $bib->getAttribute('lists') || 'bibliography');
  my $citestar = grep { $$self{db}->lookup("BIBLABEL:$_:*"); } @lists;
  my @queue    = ();
  foreach my $dbkey ($$self{db}->getKeys) {
    if ($dbkey =~ /^BIBLABEL:(.*?):(.*)$/) {
      my ($list, $bibkey) = ($1, $2);
      next unless grep { $_ eq $list; } @lists;
      my $lcbibkey   = lc($bibkey);
      my $bibdbentry = $$self{db}->lookup($dbkey);
      if (my $referrers = $bibdbentry->getValue('referrers')) {
        foreach my $refr (keys %$referrers) {
          my ($rid, $e, $t) = ($refr, undef, undef);
          while ($rid && ($e = $$self{db}->lookup("ID:$rid")) && (($t = ($e->getValue('type') || '')) ne 'ltx:bibitem')) {
            $rid = $e->getValue('parent'); }
          if (!$e) {
            Warn('expected', 'entry', undef,
              "Didn't find an entry for reference id=$rid"); }
          elsif ($t ne 'ltx:bibitem') {
            if (my $prevkey = $entries{$lcbibkey}{citedkey}) {
              Warn('unexpected', 'bibkey', undef,
                "Case mismatch in bib key '$prevkey' vs '$bibkey'") if $prevkey ne $bibkey; }
            $entries{$lcbibkey}{citedkey} = $bibkey;            # Store bibkey with case as CITED
            $entries{$lcbibkey}{referrers}{$refr} = 1; } }
        push(@queue, $bibkey) if keys %{ $entries{$lcbibkey}{referrers} }; }
      elsif ($citestar) {                                       # If \cite{*} include all of them.
        push(@queue, $bibkey); } } }
  # For each bibkey in the queue, complete and include the entry
  # And add any keys cited from within each include entry
  my %seen_keys    = ();
  my %missing_keys = ();
  my $included     = {};    # included entries (hash key is sortkey)
  while (my $bibkey = shift(@queue)) {
    next if $seen_keys{$bibkey};    # Done already.
    $seen_keys{$bibkey} = 1;
    next if $bibkey eq '*';
    my $lcbibkey = lc($bibkey);
    if (my $bibentry = $entries{$lcbibkey}{bibentry}) {
      my $entry = $entries{$lcbibkey};
      # Extract names, year and title from bibentry.
      my $names     = '';
      my $sortnames = '';
      my @names     = $doc->findnodes('ltx:bib-name[@role="author"]', $bibentry);
      @names = $doc->findnodes('ltx:bib-name[@role="editor"]', $bibentry) unless @names;
      if (my $n = $doc->findnode('ltx:bib-key', $bibentry)) {
        $sortnames = $names = $n->textContent; }
      elsif (scalar(@names)) {
        $sortnames = join(' ', map { getNameText($doc, $_) } @names);
        my @ns = map { $_ && $_->textContent } map { $doc->findnodes('ltx:surname', $_) } @names;
        if (@ns > 2)    { $names = $ns[0] . ' et al'; }
        elsif (@ns > 1) { $names = $ns[0] . ' and ' . $ns[1]; }
        else            { $names = $ns[0]; } }
      elsif (my $t = $doc->findnode('ltx:bib-title', $bibentry)) {
        $sortnames = $names = $t->textContent; }
      my $date  = $doc->findnode('ltx:bib-date[@role="publication"] | ltx:bib-type', $bibentry);
      my $title = $doc->findnode('ltx:bib-title',                                    $bibentry);
      $date            = ($date ? $date->textContent : '');
      $date            = $1 if $date && $date =~ /^(\d\d\d\d)/;
      $title           = ($title ? $title->textContent : '');
      $$entry{ay}      = "$names.$date";
      $$entry{initial} = $doc->initial($names, 1);
      # Include this entry keyed using a sortkey.
      $$included{ lc(join('.', $sortnames, $date, $title, $bibkey)) } = $entry;
      # And, since we're including this entry, we'll need to include any that it cites!
      push(@queue, @{ $$entry{citations} }) if $$entry{citations}; }
    else {
      $missing_keys{$bibkey} = 1; } }
  # Now that we know which entries will be included, note their citations as bibreferrers.
  foreach my $sortkey (keys %$included) {
    my $entry  = $$included{$sortkey};
    my $bibkey = $$entry{bibkey};
    map { $entries{ lc($_) }{bibreferrers}{$bibkey} = 1 } @{ $$entry{citations} }; }

  NoteLog("MakeBibliography: " . (scalar keys %entries) . " bibentries, " . (scalar keys %$included) . " cited");
  Warn('expected', 'bibkeys', undef,
    "Missing bibkeys " . join(', ', sort keys %missing_keys)) if keys %missing_keys;

  # Finally, sort the bibentries according to author+year+title+bibkey
  # If any neighboring entries have same author+year, set a suffix: a,b,...
  # Actually, it isn't so much if they are adjacent; if author+year isn't unique, need a suffix
  my @sortkeys = $doc->unisort(keys %$included);
  my %suffixes = ();
  while (my $sortkey = shift(@sortkeys)) {
    #    my $i=0;
    #    while(@sortkeys && ($$included{$sortkey}{ay} eq $$included{$sortkeys[0]}{ay})){
    #      $$included{$sortkey}{suffix}='a';
    #      $$included{$sortkeys[0]}{suffix} = chr(ord('a')+(++$i));
    #      shift(@sortkeys); }
    my $entry = $$included{$sortkey};
    my $ay    = $$entry{ay};
    if (defined $suffixes{$ay}) {
      my $prev = $suffixes{$ay};
      if (!$$prev{suffix}) {
        $$prev{suffix_counter} = 1;
        $$prev{suffix}         = radix_alpha($$prev{suffix_counter}); }
      $$entry{suffix_counter} = $$prev{suffix_counter} + 1;
      $$entry{suffix}         = radix_alpha($$entry{suffix_counter}); }
    $suffixes{$ay} = $entry;
    # HACKERY: AFTER all the sorting have been done, remove <ERROR role="sort"> nodes.
    # These may have been inserted to alter sorting, eg \NOOP{a}...
    foreach my $sortnode ($doc->findnodes('//ltx:ERROR[@class="sort"]', $$entry{bibentry})) {
      $sortnode->parentNode->removeChild($sortnode); }
  }
  return $included; }

sub getNameText {
  my ($doc, $namenode) = @_;
  my $surname   = $doc->findnodes('ltx:surname',   $namenode);
  my $givenname = $doc->findnodes('ltx:givenname', $namenode);
  return ($surname && $givenname ? $surname . ' ' . $givenname : $surname || $givenname); }

# ================================================================================
# Convert hash of bibentry(s) into biblist of bibitem(s)

sub makeBibliographyList {
  my ($self, $doc, $bib, $initial, $entries) = @_;
  my $id = $bib->getAttribute('xml:id')
    || $doc->getDocumentElement->getAttribute('xml:id') || 'bib';
  $id .= ".L1";
  $id .= ".$initial" if $initial;
  return ['ltx:biblist', { 'xml:id' => $id },
    map { $self->formatBibEntry($doc, $bib, $$entries{$_}) } $doc->unisort(keys %$entries)]; }

# ================================================================================
# NOTE: With multiple bibliographies, the ID of the bibentry isn't necessarily
# the ID in the "local" bibliography! (ie. bibentry can be repeated in the document!)
sub formatBibEntry {
  my ($self, $doc, $bib, $entry) = @_;
  my $bibentry   = $$entry{bibentry};
  my $citedkey   = $$entry{citedkey} || $$entry{bibkey};
  my $id         = $bibentry->getAttribute('xml:id');
  my $key        = $bibentry->getAttribute('key');
  my $type       = $bibentry->getAttribute('type');
  my @blockspecs = @{ $FMT_SPEC{$type} || [] };

  # Patch the entry's id in case there are multiple bibs.
  if (my $bibid = $bib->getAttribute('xml:id')
    || $doc->getDocumentElement->getAttribute('xml:id') || 'bib') {
    $id =~ s/^bib//; $id = $bibid . $id; }

  local $LaTeXML::Post::MakeBibliography::SUFFIX = $$entry{suffix};
  my $number = ++$LaTeXML::Post::MakeBibliography::NUMBER;

  Warn('unexpected', $type, undef,
    "No formatting specification for bibentry of type '$type'") unless @blockspecs;

  #------------------------------
  # Format the bibtag's
  my @tags = ();
  push(@tags, ['ltx:tag', { role => 'number', class => 'ltx_bib_number' }, $number]);    # number tag

  # Set up authors and fullauthors tags
  my @names = $doc->findnodes('ltx:bib-name[@role="author"]/ltx:surname', $bibentry);
  @names = $doc->findnodes('ltx:bib-name[@role="editor"]/ltx:surname', $bibentry) unless @names;
  my $etal = 0;
  if (@names && ($names[-1]->toString eq 'others')) {                                    # Magic!
    $etal = 1; }
  if (@names > 2) {
    push(@tags, ['ltx:tag', { role => 'authors', class => 'ltx_bib_author' },
        $doc->cloneNodes($names[0]->childNodes),
        ['ltx:text', { class => 'ltx_bib_etal' }, ' et al.']]);
    my @fnames = ();
    foreach my $n (@names[0 .. $#names - 1]) {
      push(@fnames, $n->childNodes, ', '); }
    push(@tags, ['ltx:tag', { role => 'fullauthors', class => 'ltx_bib_author' },
        $doc->cloneNodes(@fnames),
        ' and ', $doc->cloneNodes($names[-1]->childNodes)]); }
  elsif (@names > 1) {
    push(@tags, ['ltx:tag', { role => 'authors', class => 'ltx_bib_author' },
        $doc->cloneNodes($names[0]->childNodes),
        ' and ', $doc->cloneNodes($names[1]->childNodes)]); }
  elsif (@names) {
    push(@tags, ['ltx:tag', { role => 'authors', class => 'ltx_bib_author' },
        $doc->cloneNodes($names[0]->childNodes)]); }

  # Put a key tag, to use in place of authors if needed (esp for software, websites, etc)
  my $keytag;
  if ($keytag = $doc->findnode('ltx:bib-key', $bibentry)) {
    push(@tags, ['ltx:tag', { role => 'key', class => 'ltx_bib_key' },
        $doc->cloneNodes($keytag->childNodes)]); }

  my @year = ();
  if (my $date = $doc->findnode('ltx:bib-date[@role="publication"]', $bibentry)) {
    @year = $date->childNodes;
    if (my $datetext = $date->textContent) {
      if ($datetext =~ /^(\d\d\d\d)/) {    # Extract 4 digit year, if any
        @year = ($1); } }
    push(@tags, ['ltx:tag', { role => 'year', class => 'ltx_bib_year' },
        $doc->cloneNodes(@year), ($$entry{suffix} || '')]); }

  # Store a type tag, to use in place of year, if needed (esp for software, ...)
  my $typetag;
  if ($typetag = $doc->findnode('ltx:bib-type', $bibentry)) {
    push(@tags, ['ltx:tag', { role => 'bibtype', class => 'ltx_bib_type' },
        $doc->cloneNodes($typetag->childNodes)]); }

  # put in the title
  if (my $title = $doc->findnode('ltx:bib-title', $bibentry)) {
    push(@tags, ['ltx:tag', { role => 'title', class => 'ltx_bib_title' },
        $doc->cloneNodes($title->childNodes)]); }

  # And finally, the refnum; we need to know the desired citation style!
  # This is screwy!!!
  # AND OF COURSE, we need to know the key before we know the suffix!!!
  my $style = $LaTeXML::Post::MakeBibliography::STYLE{citestyle} || 'numbers';
  $style = 'numbers' unless (@names || $keytag) && (@year || $typetag);
  if ($style eq 'numbers') {
    push(@tags, ['ltx:tag', { role => 'refnum', class => 'ltx_bib_key', open => '[', close => ']' }, $number]); }
  elsif ($style eq 'AY') {
    my @rfnames;
    if (my @authors = $doc->findnodes('ltx:bib-name[@role="author"]/ltx:surname', $bibentry)) {
      @rfnames = @authors; }
    elsif (my @editors = $doc->findnodes('ltx:bib-name[@role="editor"]/ltx:surname', $bibentry)) {
      @rfnames = @editors; }
    else {
      @rfnames = $keytag->childNodes; }
    my $aa;
    if (scalar(@rfnames) > 1) {
      $aa = join('', map { substr($_->textContent, 0, 1); } @rfnames);
      if (length($aa) > 3) {
        $aa = substr($aa, 0, 3) . "+"; } }
    else {
      $aa = uc(substr($rfnames[0]->textContent, 0, 3)); }
    my $yrtext = (@year                ? join('', map { (ref $_ ? $_->textContent : $_); } @year) : '');
    my $yy     = (length($yrtext) >= 2 ? substr($yrtext, 2, 2) : $yrtext);
    push(@tags, ['ltx:tag', { role => 'refnum', class => 'ltx_bib_abbrv', open => '[', close => ']' },
        $aa . $yy . ($$entry{suffix} || '')]); }

  else {
    shift(@blockspecs);    # Skip redundant 1st block!!
    my @rfnames;
    if (my @authors = $doc->findnodes('ltx:bib-name[@role="author"]', $bibentry)) {
      @rfnames = do_authors(@authors); }
    elsif (my @editors = $doc->findnodes('ltx:bib-name[@role="editor"]', $bibentry)) {
      @rfnames = do_editorsA(@editors); }
    else {
      @rfnames = $keytag->childNodes; }
    my @rfyear = (@year ? (@year, ($$entry{suffix} || ''))
      : ($typetag ? $typetag->childNodes : ()));
    push(@tags, ['ltx:tag', { role => 'refnum', class => 'ltx_bib_author-year' },
        $doc->cloneNodes(@rfnames), ' (', $doc->cloneNodes(@rfyear), ')']); }

  #------------------------------
  # Format the data in blocks, with the first being bib-label, rest bibblock.
  my @blocks = ();
  foreach my $blockspec (@blockspecs) {
    my @x = ();
    foreach my $row (@$blockspec) {
      my ($xpath, $punct, $pre, $class, $op, $post) = @$row;
      my $negated = $xpath =~ s/^!\s*//;
      my @nodes   = ($xpath eq 'true' ? () : $doc->findnodes($xpath, $bibentry));
      next if ($xpath ne 'true') && ($negated ? @nodes : !@nodes);
      push(@x, $punct) if $punct && @x;
      push(@x, $pre)                                                                           if $pre;
      push(@x, ['ltx:text', { class => 'ltx_bib_' . $class }, &$op($doc->cloneNodes(@nodes))]) if $op;
      push(@x, $post)                                                                          if $post; }
    push(@blocks, ['ltx:bibblock', { 'xml:space' => 'preserve' }, @x]) if @x;
  }
  # Add a Cited by block.

  my @citedby = map { ['ltx:ref', { idref => $_, show => 'typerefnum' }] }
    sort keys %{ $$entry{referrers} };
  push(@citedby, ['ltx:bibref', { bibrefs => join(',', sort keys %{ $$entry{bibreferrers} }), show => 'refnum' }])
    if $$entry{bibreferrers};
  push(@blocks, ['ltx:bibblock', { class => 'ltx_bib_cited' },
      "Cited by: ", $doc->conjoin(",\n", @citedby), '.']) if @citedby;

  return ['ltx:bibitem', { 'xml:id' => $id, key => $citedkey, type => $type, class => "ltx_bib_$type" },
    (@tags ? (['ltx:tags', {}, @tags]) : ()),
    @blocks]; }

# ================================================================================
# Formatting aids.
sub do_any {
  my (@stuff) = @_;
  return @stuff; }

# Stuff for Author(s) & Editor(s)
sub do_name {
  my ($node) = @_;
  # NOTE: This should be a formatting option; use initials or full first names.
  my $first = $LaTeXML::Post::DOCUMENT->findnode('ltx:givenname', $node);
  if ($first) {    # && use initials
    $first = join('', map { (/\.$/ ? "$_ " : (/^(.)/ ? "$1. " : '')) }
        split(/\s/, $first->textContent)); }
  else {
    $first = (); }
  my $sur = $LaTeXML::Post::DOCUMENT->findnode('ltx:surname', $node);
  # Why, oh Why do we need the _extra_ cloneNode ???
  return ($first, $sur->cloneNode(1)->childNodes); }

sub do_names {
  my (@names) = @_;
  my @stuff   = ();
  my $sep     = (scalar(@names) > 2 ? ', ' : ' ');
  my $etal    = 0;
  if (@names && ($names[-1]->textContent eq 'others')) {    # Magic!
    pop(@names);
    $etal = 1; }
  my $n = scalar(@names);
  while (my $name = shift(@names)) {
    if (@stuff) {
      push(@stuff, $sep);
      push(@stuff, 'and ') if !$etal && !@names; }
    push(@stuff, do_name($name)); }
  if ($etal) {
    push(@stuff, $sep, ['ltx:text', { class => 'ltx_bib_etal' }, 'et al.']); }
  return @stuff; }

sub do_names_short {
  my (@names) = @_;
  if (@names > 2) {
    return ($names[0]->childNodes, ' ', ['ltx:text', { class => 'ltx_bib_etal' }, 'et al.']); }
  elsif (@names > 1) {
    return ($names[0]->childNodes, ' and ', $names[1]->childNodes); }
  elsif (@names) {
    return ($names[0]->childNodes); } }

sub do_authors {
  my (@stuff) = @_;
  return do_names(@stuff); }

sub do_editorsA {    # Should be used in citation tags?
  my (@stuff) = @_;
  my @n = do_names(@stuff);
  if    (scalar(@stuff) > 1) { push(@n, " (Eds.)"); }
  elsif (scalar(@stuff))     { push(@n, " (Ed.)"); }
  return @n; }

sub do_editorsB {
  my (@stuff) = @_;
  my @x = do_names(@stuff);
  if    (scalar(@stuff) > 1) { push(@x, " Eds."); }
  elsif (scalar(@stuff))     { push(@x, " Ed."); }
  return (@x ? ("(", @x, ")") : ()); }

sub do_year {
  my (@stuff) = @_;
  return (' (', @stuff, @LaTeXML::Post::MakeBibliography::SUFFIX, ')'); }

sub do_type {
  my (@stuff) = @_;
  return ('(', @stuff, ')'); }

# Other fields.
#### sub do_title { (['ltx:text',{font=>'italic'},@_]); }
sub do_title {
  my (@stuff) = @_;
  return (@stuff); }
###sub do_bold  { (['ltx:text',{font=>'bold'},@_]); }
sub do_edition {
  my (@stuff) = @_;
  return (@stuff, " edition"); }    # If a number, should convert to cardinal!

sub do_thesis_type {
  my (@stuff) = @_;
  return @stuff; }

sub do_pages {
  my (@stuff) = @_;
  return (" pp." . pack('U', 0xA0), @stuff); }    # Non breaking space

sub do_crossref {
  my ($node, @stuff) = @_;
  return (['ltx:cite', {},
      ['ltx:bibref', { bibrefs => $node->getAttribute('bibrefs'), show => 'title, author' }]]); }

my $LINKS =    # CONSTANT
  "ltx:bib-links | ltx:bib-review | ltx:bib-identifier | ltx:bib-url";

sub do_links {
  my (@nodes) = @_;
  my @links   = ();
  my $doc     = $LaTeXML::Post::DOCUMENT;
  foreach my $node (@nodes) {
    my $scheme = $node->getAttribute('scheme') || '';
    my $href   = $node->getAttribute('href');
    my $tag    = $doc->getQName($node);
    if (($tag eq 'ltx:bib-identifier') || ($tag eq 'ltx:bib-review')) {
      if ($href) {
        push(@links, ['ltx:ref', { href => $href, class => "$scheme ltx_bib_external" },
            $doc->cloneNodes($node->childNodes)]); }
      else {
        push(@links, ['ltx:text', { class => "$scheme ltx_bib_external" },
            $doc->cloneNodes($node->childNodes)]); } }
    elsif ($tag eq 'ltx:bib-links') {
      push(@links, ['ltx:text', { class => "ltx_bib_external" },
          $doc->cloneNodes($node->childNodes)]); }
    elsif ($tag eq 'ltx:bib-url') {
      push(@links, ['ltx:ref', { href => $href, class => 'ltx_bib_external' },
          $doc->cloneNodes($node->childNodes)]); } }

  @links = map { (",\n", $_) } @links;    # non-string join()
  return @links[1 .. $#links]; }

# ================================================================================
# Formatting specifications.
# Adpated from amsrefs.sty
#BEGIN{

# For each bibliographic type,
# the specification is an array representing each bibblock.
# Each biblock is an array of field specifications.
# Each field specification is:
#   [xpath, punct, prestring, operatorname, poststring]
# NOTE That the first block is only shown for numeric style,
# since otherwise athors will already be shown in the bibtag@refnum!!!
# Ugh...

#    [xpath                              punct  pre              class    formatter      post ]
@META_BLOCK =
  ([['ltx:bib-note', '', "Note: ", 'note', \&do_any, '']],
  [[$LINKS, '', 'External Links: ', 'links', \&do_links, '']]);

%FMT_SPEC =
  #    [xpath                              punct pre    class     formatter      post ]
  (article =>
    [[['ltx:bib-name[@role="author"]', '', '', 'author', \&do_authors, ''],
      ['ltx:bib-date[@role="publication"]', '', '', 'year', \&do_year, '']],
    [['ltx:bib-title',              '', '', 'title', \&do_title, '.']],
    [['ltx:bib-part[@role="part"]', '', '', 'part',  \&do_any,   ''],
      ['ltx:bib-related/ltx:bib-title', ', ', '',  'journal',  \&do_any,   ''],
      ['ltx:bib-part[@role="volume"]',  ' ',  '',  'volume',   \&do_any,   ''],
      ['ltx:bib-part[@role="number"]',  ' ',  '(', 'number',   \&do_any,   ')'],
      ['ltx:bib-status',                ', ', '(', 'status',   \&do_any,   ')'],
      ['ltx:bib-part[@role="pages"]',   ', ', '',  'pages',    \&do_pages, ''],
      ['ltx:bib-language',              ' ',  '(', 'language', \&do_any,   ')'],
      ['true',                          '.']],
    @META_BLOCK],
  book =>
    [[['ltx:bib-name[@role="author"]', '', '', 'author', \&do_authors, ''],
      ['ltx:bib-name[@role="editor"]',      '', '', 'editor', \&do_editorsA, ''],
      ['ltx:bib-date[@role="publication"]', '', '', 'year',   \&do_year,     '']],
    [['ltx:bib-title', '', '', 'title', \&do_title, '.']],
    [['ltx:bib-type',  '', '', 'type',  \&do_any,   ''],
      ['ltx:bib-edition',              ', ', '',      'edition',   \&do_edition, ''],
      ['ltx:bib-part[@role="series"]', ', ', '',      'series',    \&do_any,     ''],
      ['ltx:bib-part[@role="volume"]', ', ', 'Vol. ', 'volume',    \&do_any,     ''],
      ['ltx:bib-part[@role="part"]',   ', ', 'Part ', 'part',      \&do_any,     ''],
      ['ltx:bib-publisher',            ', ', ' ',     'publisher', \&do_any,     ''],
      ['ltx:bib-organization',         ', ', ' ',     'publisher', \&do_any,     ''],
      ['ltx:bib-place',                ', ', '',      'place',     \&do_any,     ''],
      ['ltx:bib-status',               ' ',  '(',     'status',    \&do_any,     ')'],
      ['ltx:bib-language',             ' ',  '(',     'language',  \&do_any,     ')'],
      ['true',                         '.']],
    @META_BLOCK],
  'incollection' =>
    [[['ltx:bib-name[@role="author"]', '', '', 'author', \&do_authors, ''],
      ['ltx:bib-date[@role="publication"]', '', '', 'year', \&do_year, '']],
    [['ltx:bib-title', '', '', 'title', \&do_title, '.']],
    [['ltx:bib-type',  '', '', 'type',  \&do_any,   ''],
      # Show crossref if any
      ['ltx:bib-related[@bibrefs]', ' ', 'See ', 'crossref', \&do_crossref, ','],
      # if NO crossref, used embedded editors & booktitle.
      #      ['ltx:bib-related[@type="book"]/ltx:bib-title', ' ', 'in ', 'inbook',   \&do_title,    ',']
      ['ltx:bib-related[@type][not(../ltx:bib-related[@bibrefs])]/ltx:bib-title',
        ' ', 'In ', 'inbook', \&do_title, ','],
      ['ltx:bib-related[@type][not(../ltx:bib-related[@bibrefs])]/ltx:bib-name[@role="editor"]',
        ' ', ' ', 'editor', \&do_editorsA, ','],
    ],
    [['ltx:bib-edition', '', '', 'edition', \&do_edition, ''],
      ['ltx:bib-name[@role="editor"]',                 ', ', '',      'editor',    \&do_editorsB, ''],
      ['ltx:bib-related/ltx:bib-part[@role="series"]', ', ', '',      'series',    \&do_any,      ''],
      ['ltx:bib-related/ltx:bib-part[@role="volume"]', ', ', 'Vol. ', 'volume',    \&do_any,      ''],
      ['ltx:bib-related/ltx:bib-part[@role="part"]',   ', ', 'Part ', 'part',      \&do_any,      ''],
      ['ltx:bib-publisher',                            ', ', ' ',     'publisher', \&do_any,      ''],
      ['ltx:bib-organization',                         ', ', '',      'publisher', \&do_any,      ''],
      ['ltx:bib-place',                                ', ', '',      'place',     \&do_any,      ''],
      ['ltx:bib-part[@role="pages"]',                  ', ', '',      'pages',     \&do_pages,    ''],
      ['ltx:bib-status',                               ' ',  '(',     'status',    \&do_any,      ')'],
      ['ltx:bib-language',                             ' ',  '(',     'language',  \&do_any,      ')'],
      ['true',                                         '.']],
    @META_BLOCK],
  report =>
    [[['ltx:bib-name[@role="author"]', '', '', 'author', \&do_authors, ''],
      ['ltx:bib-name[@role="editor"]',      '', '', 'editor', \&do_editorsA, ''],
      ['ltx:bib-date[@role="publication"]', '', '', 'year',   \&do_year,     '']],
    [['ltx:bib-title',                '', '',                  'title',  \&do_title, '.']],
    [['ltx:bib-type',                 '', '',                  'type',   \&do_any,   '']],
    [['ltx:bib-part[@role="number"]', '', 'Technical Report ', 'number', \&do_any,   ''],
      ['ltx:bib-part[@role="series"]', ', ', '',      'series',    \&do_any, ''],
      ['ltx:bib-part[@role="volume"]', ', ', 'Vol. ', 'volume',    \&do_any, ''],
      ['ltx:bib-part[@role="part"]',   ', ', 'Part ', 'part',      \&do_any, ''],
      ['ltx:bib-publisher',            ', ', ' ',     'publisher', \&do_any, ''],
      ['ltx:bib-organization',         ', ', ' ',     'publisher', \&do_any, ''],
      ['ltx:bib-place',                ', ', ' ',     'place',     \&do_any, ''],
      ['ltx:bib-status',               ', ', '(',     'status',    \&do_any, ')'],
      ['ltx:bib-language',             ' ',  '(',     'language',  \&do_any, ')'],
      ['true',                         '.']],
    @META_BLOCK],
  thesis =>
    [[['ltx:bib-name[@role="author"]', '', '', 'author', \&do_authors, ''],
      ['ltx:bib-name[@role="editor"]',      '', '', 'editor', \&do_editorsA, ''],
      ['ltx:bib-date[@role="publication"]', '', '', 'year',   \&do_year,     '']],
    [['ltx:bib-title', '',  '', 'title', \&do_title,       '.']],
    [['ltx:bib-type',  ' ', '', 'type',  \&do_thesis_type, ''],
      ['ltx:bib-part[@role="part"]', ', ', 'Part ', 'part',      \&do_any, ''],
      ['ltx:bib-publisher',          ', ', '',      'publisher', \&do_any, ''],
      ['ltx:bib-organization',       ', ', '',      'publisher', \&do_any, ''],
      ['ltx:bib-place',              ', ', '',      'place',     \&do_any, ''],
      ['ltx:bib-status',             ', ', '(',     'status',    \&do_any, ')'],
      ['ltx:bib-language',           ', ', '(',     'language',  \&do_any, ')'],
      ['true',                       '.']],
    @META_BLOCK],
  website =>
    [[['ltx:bib-name[@role="author"]', '', '', 'author', \&do_authors, ''],
      ['ltx:bib-name[@role="editor"]',      '', '', 'editor', \&do_editorsA,          ''],
      ['ltx:bib-date[@role="publication"]', '', '', 'year',   \&do_year,              ''],
      ['ltx:title',                         '', '', 'title',  \&do_any,               ''],
      ['ltx:bib-type',                      '', '', 'type',   \&do_any,               ''],
      ['! ltx:bib-type',                    '', '', 'type',   sub { ('(Website)'); }, '']],
    [['ltx:bib-organization', ', ', ' ', 'publisher', \&do_any, ''],
      ['ltx:bib-place', ', ', '', 'place', \&do_any, ''],
      ['true', '.']],
    @META_BLOCK],
  software =>
    [[['ltx:bib-key', '', '', 'key', \&do_any, ''],
      ['ltx:bib-type', '', '', 'type', \&do_type, '']],
    [['ltx:bib-title',        '',   '',  'title',     \&do_any, '']],
    [['ltx:bib-organization', ', ', ' ', 'publisher', \&do_any, ''],
      ['ltx:bib-place', ', ', '', 'place', \&do_any, ''],
      ['true', '.']],
    @META_BLOCK],
  );

$FMT_SPEC{periodical}            = $FMT_SPEC{book};
$FMT_SPEC{collection}            = $FMT_SPEC{book};
$FMT_SPEC{proceedings}           = $FMT_SPEC{book};
$FMT_SPEC{manual}                = $FMT_SPEC{book};
$FMT_SPEC{misc}                  = $FMT_SPEC{book};
$FMT_SPEC{unpublished}           = $FMT_SPEC{book};
$FMT_SPEC{booklet}               = $FMT_SPEC{book};
$FMT_SPEC{'collection.article'}  = $FMT_SPEC{incollection};
$FMT_SPEC{'proceedings.article'} = $FMT_SPEC{incollection};
$FMT_SPEC{inproceedings}         = $FMT_SPEC{incollection};
$FMT_SPEC{inbook}                = $FMT_SPEC{incollection};
$FMT_SPEC{techreport}            = $FMT_SPEC{report};

#}

# ================================================================================
1;
