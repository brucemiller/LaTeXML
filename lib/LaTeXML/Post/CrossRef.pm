# /=====================================================================\ #
# |  LaTeXML::Post::CrossRef                                            | #
# | Scan for ID's etc                                                   | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post::CrossRef;
use strict;
use warnings;
use LaTeXML::Util::Pathname;
use LaTeXML::Common::XML;
use charnames qw(:full);
use LaTeXML::Post;
use base qw(LaTeXML::Post::Processor);

sub new {
  my ($class, %options) = @_;
  my $self = $class->SUPER::new(%options);
  $$self{db}       = $options{db};
  $$self{urlstyle} = $options{urlstyle};
##  $$self{toc_show} = ($options{number_sections} ? "typerefnum title" : "title");
  $$self{toc_show}       = 'toctitle';
  $$self{ref_show}       = ($options{number_sections} ? "typerefnum" : "title");
  $$self{min_ref_length} = (defined $options{min_ref_length} ? $options{min_ref_length} : 1);
  $$self{ref_join} = (defined $options{ref_join} ? $options{ref_join} : " \x{2023} "); # or " in " or ... ?
  $$self{navigation_toc} = $options{navigation_toc};
  return $self; }

sub process {
  my ($self, $doc, $root) = @_;
  local %LaTeXML::Post::CrossRef::MISSING = ();
  if (my $navtoc = $$self{navigation_toc}) { # If a navigation toc requested, put a toc in nav; will get filled in
    my $toc = ['ltx:TOC', { format => $navtoc }];
    if (my $nav = $doc->findnode('//ltx:navigation')) {
      $doc->addNodes($nav, $toc); }
    else {
      $doc->addNodes($doc->getDocumentElement, ['ltx:navigation', {}, $toc]); } }
  $self->fillInGlossaryRef($doc);
  $self->fill_in_relations($doc);
  $self->fill_in_tocs($doc);
  $self->fill_in_frags($doc);
  $self->fill_in_refs($doc);
  $self->fill_in_RDFa_refs($doc);
  $self->fill_in_bibrefs($doc);
  if (keys %LaTeXML::Post::CrossRef::MISSING) {
    my $tempid = 0;
    foreach my $severity (qw(error warn info)) {
      my @msgs = ();
      foreach my $type (sort keys %{ $LaTeXML::Post::CrossRef::MISSING{$severity} }) {
        my @items = keys %{ $LaTeXML::Post::CrossRef::MISSING{$severity}{$type} };
        $tempid ||= grep { $_ eq 'TEMPORARY_DOCUMENT_ID' } @items;
        push(@msgs, $type . ": " . join(', ', @items)); }
      if (@msgs) {
        my @args = ('expected', 'ids', undef,
          "Missing items:\n  " . join(";\n  ", @msgs),
          ($tempid ? "[Note TEMPORARY_DOCUMENT_ID is a stand-in ID for the main document.]" : ()));
        if    ($severity eq 'error') { Error(@args); }
        elsif ($severity eq 'warn')  { Warn(@args); }
        elsif ($severity eq 'info')  { Info(@args); } } } }
  return $doc; }

sub note_missing {
  my ($self, $severity, $type, $key) = @_;
  $LaTeXML::Post::CrossRef::MISSING{$severity}{$type}{$key}++;
  return; }

sub fill_in_relations {
  my ($self, $doc) = @_;
  my $db = $$self{db};
  if (my $id = $doc->getDocumentElement->getAttribute('xml:id')) {
    if (my $entry = $db->lookup("ID:" . $id)) {
      # First, add the basic relations
      my $x;
      # Apparently, "up", "up up", "up up up" is the desired form for html5
      my $xentry = $entry;
      my $rel    = 'up';
      while (($x = $xentry->getValue('parent')) && ($xentry = $db->lookup("ID:" . $x))) {
        if ($xentry->getValue('title')) {    # it's interesting if it has a title (INCONSISTENT!!!)
          ### NOT pageid, like the others, because of the sleasy link to \part in dlmf!!!
          $doc->addNavigation($rel => $xentry->getValue('id'));
          $rel .= ' up'; } }
      if ($xentry && ($id ne $xentry->getValue('pageid'))) {
        $doc->addNavigation(start => $xentry->getValue('pageid')); }
      if (my $prev = $self->findPreviousPage($entry)) {    # previous page
        $doc->addNavigation(prev => $prev->getValue('pageid')); }
      if (my $next = $self->findNextPage($entry)) {
        $doc->addNavigation(next => $next->getValue('pageid')); }

      # Now, dig around for other interesting related documents
      # Use the entry types themselves for the relations
      $xentry = $entry;
      # Firstly, look at siblings of this page, then at siblings of parent,
      # then those of grandparent, etc.
      # In a large/complex site, this gets way too much. But how to prune?
      while ($xentry = $self->getParentPage($xentry)) {
        # any siblings of (grand)parent are "interesting" structural elements
        # OR, even more interesting: the index, bibliography, glossary related to current page!
        foreach my $sib ($self->getChildPages($xentry)) {
          my $sib_id = $sib->getValue('pageid');
          next if $sib_id eq $id;
          if ($sib->getValue('primary')) {    # If a primary page
                                              # Use the element name (w/o prefix) as the relation !!!!
            my $sib_rel = $sib->getValue('type'); $sib_rel =~ s/^(\w+)://;
            $doc->addNavigation($sib_rel => $sib_id); }
          else {                              # Else, consider it as some sort of sidebar.
            $doc->addNavigation('sidebar' => $sib_id); } } }
      # Then Look at (only?) 1st level of pages below this one.
      foreach my $child ($self->getChildPages($entry)) {
        my $child_id = $child->getValue('pageid');
        if ($child->getValue('primary')) {    # If a primary page
                                              # Use the element name (w/o prefix) as the relation !!!!
          my $child_rel = $child->getValue('type'); $child_rel =~ s/^(\w+)://;
          $doc->addNavigation($child_rel => $child_id); }
        else {                                # Else, consider it as some sort of sidebar.
          $doc->addNavigation('sidebar' => $child_id); } }
    } }
  return; }

sub findPreviousPage {
  my ($self, $entry) = @_;
  my $page = $entry->getValue('pageid');
  # Look at parent's entry, and get the list of our siblings
  if (my $pentry = $self->getParentPage($entry)) {
    my @sibs = $self->getChildPages($pentry);
    while (@sibs && $sibs[-1]->getValue('pageid') ne $page) {    # peel off following sibs
      pop(@sibs); }
    return unless @sibs && $sibs[-1]->getValue('pageid') eq $page;    # Broken database?
    pop(@sibs);                                                       # Now skip our own entry ($id)
    @sibs = grep { $_->getValue('primary') } @sibs;
    # If there IS a preceding sibling, find it's rightmost descendant
    while (@sibs) {
      $pentry = $sibs[-1];
      @sibs = grep { $_->getValue('primary') } $self->getChildPages($pentry); }
    return $pentry; }                                                 # Return deepest page found
  return; }

sub findNextPage {
  my ($self, $entry) = @_;
  # Return first child page, if any
  my @ch = grep { $_->getValue('primary') } $self->getChildPages($entry);
  return $ch[0] if @ch;
  my $page = $entry->getValue('pageid');
  # Look at parent's entry, and get the list of siblings
  while ($entry = $self->getParentPage($entry)) {
    my @sibs = $self->getChildPages($entry);
    while (@sibs && $sibs[0]->getValue('pageid') ne $page) {    # peel off preceding sibs, till found,
      shift(@sibs); }
    return unless @sibs && ($sibs[0]->getValue('pageid') eq $page);    # Broken database?
    shift(@sibs);                                                      # remove our own entry ($id)
    @sibs = grep { $_->getValue('primary') } @sibs;                    # Skip uninteresting pages
    return $sibs[0] if @sibs;
    $page = $entry->getValue('pageid'); }
  return; }

sub getParentPage {
  my ($self, $entry) = @_;
  my $x;
  return ($x = $entry->getValue('pageid')) && ($x = $$self{db}->lookup("ID:" . $x))
    && ($x = $x->getValue('parent')) && ($x = $$self{db}->lookup("ID:" . $x))
    && ($x = $x->getValue('pageid')) && ($x = $$self{db}->lookup("ID:" . $x))
    && $x; }

# Assuming this entry is for a page, find the closest descendants that are (distinct) pages
sub getChildPages {
  my ($self, $entry) = @_;
  my $page = $entry->getValue('pageid');
  my @p    = ();
  foreach my $ch (@{ $entry->getValue('children') || [] }) {
    if (my $e = $$self{db}->lookup("ID:" . $ch)) {
      if (my $p = $e->getValue('pageid')) {    # if valid page
        push(@p, ($p ne $page ? ($e) : $self->getChildPages($e))); } } }
  return @p; }

# this is probably the same as "Interesting" for the above relations.
# To make it more extensible, it really should be integrated into the database?
# Eg. "sectional" things might mark their entries specially?
my $normaltoctypes = { map { ($_ => 1) }    # CONSTANT
    qw (ltx:document ltx:part ltx:chapter
    ltx:section ltx:subsection ltx:subsubsection
    ltx:paragraph ltx:subparagraph
    ltx:index ltx:bibliography ltx:glossary ltx:appendix) };

sub fill_in_tocs {
  my ($self, $doc) = @_;
  my $n = 0;
  foreach my $toc ($doc->findnodes('descendant::ltx:TOC[not(ltx:toclist)]')) {
    $n++;
    my $selector = $toc->getAttribute('select');
    my $types    = ($selector
      ? { map { ($_ => 1) } split(/\s*\|\s*/, $selector) }
      : $normaltoctypes);
    # global vs children of THIS or Document node?
    my $id     = $doc->getDocumentElement->getAttribute('xml:id');
    my $format = $toc->getAttribute('format');

    my @list = ();
    if (!$format || ($format eq 'normal')) {
      @list = $self->gentoc($id, $types); }
    elsif ($format eq 'context') {
      @list = $self->gentoc_context($id, $types); }
    $doc->addNodes($toc, ['ltx:toclist', {}, @list]) if @list; }
  NoteProgressDetailed(" [Filled in $n TOCs]");
  return; }

# generate TOC for $id & its children,
# providing that those objects are of appropriate type.
# Returns a list of 0 or more ltx:tocentry's (possibly containing ltx:toclist's)
# Note that parent/child relationships stored in ObjectDB can also reflect less
# `interesting' objects like para or p style paragraphs, and such.
#   $location: if defined (as a pathname), only include children that are on that page
#   $depth   : only to the specific depth
#
sub gentoc {
  my ($self, $id, $types, $localto, $selfid) = @_;
  if (my $entry = $$self{db}->lookup("ID:$id")) {
    my @kids = ();
    if ((!defined $localto) || (($entry->getValue('location') || '') eq $localto)) {
      @kids = map { $self->gentoc($_, $types, $localto, $selfid) }
        @{ $entry->getValue('children') || [] }; }
    my $type = $entry->getValue('type');
    if ($$types{$type}) {
      my $typename = $type; $typename =~ s/^ltx://;
      return (['ltx:tocentry', (defined $selfid && ($selfid eq $id) ? { class => 'ltx_ref_self' } : {}),
          ['ltx:ref', { show => 'toctitle', idref => $id }],
          (@kids ? (['ltx:toclist', { class => "ltx_toc_$typename" }, @kids]) : ())]); }
    else {
      return @kids; } }
  else {
    return (); } }

# Generate a "context" TOC, that shows what's on the current page,
# but also shows the page in the context of it's siblings & ancestors.
# This is useful for putting in a navigation bar.
sub gentoc_context {
  my ($self, $id, $types) = @_;
  if (my $entry = $$self{db}->lookup("ID:$id")) {
    # Generate Downward TOC covering items WITHIN the current page.
    my @navtoc = $self->gentoc($id, $types, $entry->getValue('location') || '', $id);
    # Then enclose it upwards along with siblings & ancestors
    my $p_id;
    while (($p_id = $entry->getValue('parent')) && ($entry = $$self{db}->lookup("ID:$p_id"))) {
      @navtoc = map { ($_ eq $id
          ? @navtoc
          : ['ltx:tocentry', {},
            ['ltx:ref', { idref => $_, show => 'toctitle' }]]) }
        grep { $$normaltoctypes{ $$self{db}->lookup("ID:$_")->getValue('type') } }
        @{ $entry->getValue('children') || [] };
      my $type = $entry->getValue('type');
      if ($$types{$type}) {
        my $typename = $type; $typename =~ s/^ltx://;
        @navtoc = (['ltx:tocentry', {},
            ['ltx:ref', { show => 'toctitle', idref => $p_id }],
            (@navtoc ? (['ltx:toclist', { class => "ltx_toc_$typename" }, @navtoc]) : ())]); }
      $id = $p_id; }
    return @navtoc; }
  else {
    return (); } }

sub fill_in_frags {
  my ($self, $doc) = @_;
  my $n  = 0;
  my $db = $$self{db};
  # Any nodes with an ID will get a fragid;
  # This is the id/name that will be used within xhtml/html.
  foreach my $node ($doc->findnodes('//@xml:id')) {
    if (my $entry = $db->lookup("ID:" . $node->value)) {
      if (my $fragid = $entry->getValue('fragid')) {
        $n++;
        $node->parentNode->setAttribute(fragid => $fragid); } } }
  NoteProgressDetailed(" [Filled in fragment $n ids]");
  return; }

# Fill in content text for any <... @idref..>'s or @labelref
sub fill_in_refs {
  my ($self, $doc) = @_;
  my $db = $$self{db};
  my $n  = 0;
  foreach my $ref ($doc->findnodes('descendant::*[@idref or @labelref]')) {
    my $tag = $doc->getQName($ref);
    next if $tag eq 'ltx:XMRef';    # Blech; list those TO fill-in, or list those to exclude?
    my $id   = $ref->getAttribute('idref');
    my $show = $ref->getAttribute('show');
    $show = $$self{ref_show} unless $show;
    $show = $$self{toc_show} if ($show eq 'fulltitle') || ($show =~ /.+title|title.+/);
    if (!$id) {
      if (my $label = $ref->getAttribute('labelref')) {
        my $entry;
        if (($entry = $db->lookup($label)) && ($id = $entry->getValue('id'))) {
          $show =~ s/^type//;       # Since author may have put explicit \S\ref... in!
        }
        else {
          $self->note_missing('warn', 'Target for Label', $label);
          if (!$ref->textContent) {
            $doc->addNodes($ref, $label);    # Just to reassure (?) readers.
            $ref->setAttribute(broken => 1); }
        } } }
    if ($id) {
      $n++;
      if (!$ref->getAttribute('href')) {
        if (my $url = $self->generateURL($doc, $id)) {
          $ref->setAttribute(href => $url); } }
      if (!$ref->getAttribute('title')) {
        if (my $titlestring = $self->generateTitle($doc, $id)) {
          $ref->setAttribute(title => $titlestring); } }
      if (!$ref->textContent && !element_nodes($ref)
        && !(($tag eq 'ltx:graphics') || ($tag eq 'ltx:picture'))) {
        $doc->addNodes($ref, $self->generateRef($doc, $id, $show)); }
      if (my $entry = $$self{db}->lookup("ID:$id")) {
        $ref->setAttribute(stub => 1) if $entry->getValue('stub'); }
    } }
  NoteProgressDetailed(" [Filled in $n refs]");
  return; }

# similar sorta thing for RDF about & resource labels & ids
sub fill_in_RDFa_refs {
  my ($self, $doc) = @_;
  my $db = $$self{db};
  my $n  = 0;
  foreach my $key (qw(about resource)) {
    foreach my $ref ($doc->findnodes('descendant::*[@' . $key . 'idref or @' . $key . 'labelref]')) {
      my $id = $ref->getAttribute($key . 'idref');
      if (!$id) {
        if (my $label = $ref->getAttribute($key . 'labelref')) {
          my $entry;
          if (($entry = $db->lookup($label)) && ($id = $entry->getValue('id'))) {
          }
          else {
            $self->note_missing('warn', "Target for $key Label", $label);
          } } }
      if ($id) {
        $n++;
        if (!$ref->getAttribute($key)) {
          if ($db->lookup("ID:" . $id)) {    # RDF "id" need not be real, valid, ids!!!
            if (my $url = $self->generateURL($doc, $id)) {
              $ref->setAttribute($key => $url); } }
          else {
            $ref->setAttribute($key => '#' . $id); } }
      } } }
  set_RDFa_prefixes($doc->getDocument, {});    # what prefixes??
  NoteProgressDetailed(" [Filled in $n RDFa refs]");
  return; }

# Needs to evolve into the combined stuff that we had in DLMF.
# (eg. concise author/year combinations for multiple bibrefs)
sub fill_in_bibrefs {
  my ($self, $doc) = @_;
  my $n = 0;
  foreach my $bibref ($doc->findnodes('descendant::ltx:bibref')) {
    $n++;
    $doc->replaceNode($bibref, $self->make_bibcite($doc, $bibref)); }
  NoteProgressDetailed(" [Filled in $n bibrefs]");
  return; }

# Given a list of bibkeys, construct links to them.
# Mostly tuned to author-year style.
# Combines when multiple bibitems share the same authors.
sub make_bibcite {
  my ($self, $doc, $bibref) = @_;

  # NOTE: bibkeys are downcased when we look them up!
  my @keys         = map { lc($_) } grep { $_ } split(/,/, $bibref->getAttribute('bibrefs'));
  my $show         = $bibref->getAttribute('show');
  my @preformatted = $bibref->childNodes();
  if ($show && ($show eq 'none') && !@preformatted) {
    $show = 'refnum'; }
  if (!$show) {
    map { $self->note_missing('info', "bibref 'show' parameter", $_) } @keys;
    $show = 'refnum'; }
  if ($show eq 'nothing') {    # Ad Hoc support for \nocite!t
    return (); }
  my $sep   = $bibref->getAttribute('separator')   || ',';
  my $yysep = $bibref->getAttribute('yyseparator') || ',';
  my @phrases = $bibref->getChildNodes();    # get the ltx;bibrefphrase's in the bibref!
                                             # Collect all the data from the bibliography
  my @data    = ();
  foreach my $key (@keys) {
    if (my $bentry = $$self{db}->lookup("BIBLABEL:$key")) {
      if (my $id = $bentry->getValue('id')) {
        if (my $entry = $$self{db}->lookup("ID:$id")) {
          my $authors  = $entry->getValue('authors');
          my $fauthors = $entry->getValue('fullauthors');
          my $keytag   = $entry->getValue('keytag');
          my $year     = $entry->getValue('year');
          my $typetag  = $entry->getValue('typetag');
          my $number   = $entry->getValue('number');
          my $title    = $entry->getValue('title');
          my $refnum   = $entry->getValue('refnum');        # This come's from the \bibitem, w/o BibTeX
          my ($rawyear, $suffix);

          if ($year && ($year->textContent) =~ /^(\d\d\d\d)(\w)$/) {
            ($rawyear, $suffix) = ($1, $2); }
          $show = 'refnum' unless ($show eq 'none') || $authors || $fauthors || $keytag; # Disable author-year format!
                                                                                         # fullnames ?
          push(@data, { authors => [$doc->trimChildNodes($authors || $fauthors || $keytag)],
              fullauthors => [$doc->trimChildNodes($fauthors || $authors || $keytag)],
              authortext => ($authors || $fauthors ? ($authors || $fauthors)->textContent : ''),
              year => [$doc->trimChildNodes($year || $typetag)],
              rawyear => $rawyear,
              suffix  => $suffix,
              number  => [$doc->trimChildNodes($number)],
              refnum  => [$doc->trimChildNodes($refnum)],
              title   => [$doc->trimChildNodes($title || $keytag)],
              attr    => { idref => $id,
                href => orNull($self->generateURL($doc, $id)),
                ($title ? (title => orNull($title->textContent)) : ()) } }); } } }
    else {
      $self->note_missing('warn', 'Entry for citation', $key); } }
  my $checkdups = ($show =~ /author/i) && ($show =~ /(year|number)/i);
  my @refs      = ();
  my $saveshow  = $show;
  while (@data) {
    my $datum  = shift(@data);
    my $didref = 0;
    my @stuff  = ();
    $show = $saveshow;
    if (($show eq 'none') && @preformatted) {
      @stuff = @preformatted; $show = ''; }
    while ($show) {
      if ($show =~ s/^authors?//i) {
        push(@stuff, $doc->cloneNodes(@{ $$datum{authors} })); }
      elsif ($show =~ s/^fullauthors?//i) {
        push(@stuff, $doc->cloneNodes(@{ $$datum{fullauthors} })); }
      elsif ($show =~ s/^title//i) {
        push(@stuff, $doc->cloneNodes(@{ $$datum{title} })); }
      elsif ($show =~ s/^refnum//i) {
        push(@stuff, $doc->cloneNodes(@{ $$datum{refnum} })); }
      elsif ($show =~ s/^phrase(\d)//i) {
        push(@stuff, $phrases[$1 - 1]->childNodes) if $phrases[$1 - 1]; }
      elsif ($show =~ s/^year//i) {
        if (@{ $$datum{year} }) {
          push(@stuff, ['ltx:ref', $$datum{attr}, @{ $$datum{year} }]);
          $didref = 1;
          while ($checkdups && @data && ($$datum{authortext} eq $data[0]{authortext})) {
            my $next = shift(@data);
            push(@stuff, $yysep, ' ');
            if ((($$datum{rawyear} || 'no_year_1') eq ($$next{rawyear} || 'no_year_2')) && $$next{suffix}) {
              push(@stuff, ['ltx:ref', $$next{attr}, $$next{suffix}]); }
            else {
              push(@stuff, ['ltx:ref', $$next{attr}, @{ $$next{year} }]); } } } }
      elsif ($show =~ s/^number//i) {
        push(@stuff, ['ltx:ref', $$datum{attr}, @{ $$datum{number} }]);
        $didref = 1;
        while ($checkdups && @data && ($$datum{authortext} eq $data[0]{authortext})) {
          my $next = shift(@data);
          push(@stuff, $yysep, ' ', ['ltx:ref', $$next{attr}, @{ $$next{number} }]); } }
      elsif ($show =~ s/^super//i) {
        my @r = ();
        push(@r, ['ltx:ref', $$datum{attr}, @{ $$datum{number} }]);
        $didref = 1;
        while ($checkdups && @data && ($$datum{authortext} eq $data[0]{authortext})) {
          my $next = shift(@data);
          push(@r, $yysep, ' ', ['ltx:ref', $$next{attr}, @{ $$next{number} }]); }
        push(@stuff, ['ltx:sup', {}, @r]); }
      elsif ($show =~ s/^(.)//) {
        push(@stuff, $1); } }
    push(@refs,
      (@refs ? ($sep, ' ') : ()),
      ($didref ? @stuff : (['ltx:ref', $$datum{attr}, @stuff]))); }
  return @refs; }

sub generateURL {
  my ($self, $doc, $id) = @_;
  my ($object, $location);
  if ($object = $$self{db}->lookup("ID:" . $id)) {
    if ($location = $object->getValue('location')) {
      my $doclocation = $doc->siteRelativeDestination;
      my $pathdir     = pathname_directory($doclocation);
      my $url         = pathname_relative(($location =~ m|^/| ? $location : '/' . $location),
        ($pathdir =~ m|^/| ? $pathdir : '/' . $pathdir));
      my $extension = $$self{extension} || 'xml';
      my $urlstyle  = $$self{urlstyle}  || 'file';
      if ($urlstyle eq 'server') {
        $url =~ s/(^|\/)index.\Q$extension\E$/$1/; }    # Remove trailing index.$extension
      elsif ($urlstyle eq 'negotiated') {
        $url =~ s/\.\Q$extension\E$//;                  # Remove trailing $extension
        $url =~ s/(^|\/)index$/$1/;                     # AND trailing index
      }
      $url = '.' unless $url;
      if (my $fragid = $object->getValue('fragid')) {
        $url = '' if ($url eq '.') or ($location eq $doclocation);
        $url .= '#' . $fragid; }
      elsif ($location eq $doclocation) {
        $url = ''; }
      return $url; }
    else {
      $self->note_missing('warn', 'File location for ID', $id); } }
  else {
    $self->note_missing('warn', 'DB Entry for ID', $id); }
  return; }

my $NBSP = pack('U', 0xA0);    # CONSTANT
# Generate the contents of a <ltx:ref> of the given id.
# show is a string containing substrings 'type', 'refnum' and 'title'
# (standing for the type prefix, refnum and title of the id'd object)
# and any other random characters; the
sub generateRef {
  my ($self, $doc, $reqid, $reqshow) = @_;
  my $pending = '';
  my @stuff;
  # Try the requested show pattern, and if it fails, try a fallback of just the title or refnum
  foreach my $show (($reqshow, ($reqshow !~ /title/ ? "title" : "refnum"))) {
    my $id = $reqid;
    # Start with requested ID, add some from parent(s), if needed/until to make "useful" link content
    while (my $entry = $id && $$self{db}->lookup("ID:$id")) {
      if (my @s = $self->generateRef_aux($doc, $entry, $show)) {
        push(@stuff, $pending) if $pending;
        push(@stuff, @s);
        return @stuff if $self->checkRefContent(@stuff);
        $pending = $$self{ref_join}; } # inside/outside this brace determines if text can START with the join.
      $id = $entry->getValue('parent'); } }
  if (@stuff) {
    return @stuff; }
  else {
    $self->note_missing('info', 'Usable title for ID', $reqid);
    return ($reqid); } }               # id is crummy, but better than "?"... or?

# Check if the proposed content of a <ltx:ref> is "Good Enough"
# (long enough, unique enough to give reader feedback,...)
sub checkRefContent {
  my ($self, @stuff) = @_;
  # Length? having _some_ actual text ?
  my $s = text_content(@stuff);
  # Could compare a minum length
  # But perhaps this is better: check that there's some "text", not just symbols!
  $s =~ s/\bin\s+//g;
  return ($s =~ /\w/ ? 1 : 0); }

sub text_content {
  my (@stuff) = @_;
  return join('', map { text_content_aux($_) } @stuff); }

sub text_content_aux {
  my ($n) = @_;
  my $r = ref $n;
  if (!$r) {
    return $n; }
  elsif ($r eq 'ARRAY') {
    my ($t, $a, @c) = @$n;
    return text_content(@c); }
  elsif ($r =~ /^XML::/) {
    return $n->textContent; }
  else {
    return $n; } }

# Interpret a "Show" pattern for a given DB entry.
# The pattern can contain substrings to be substituted
#   type   => the type prefix (eg Ch. or similar)
#   refnum => the reference number
#   title  => the title.
# and any other random characters which are preserved.
sub generateRef_aux {
  my ($self, $doc, $entry, $show) = @_;
  my @stuff = ();
  my $OK    = 0;
  $show =~ s/typerefnum\s*title/title/;    # Same thing NOW!!!
  while ($show) {
    if ($show =~ s/^type(\.?\s*)refnum(\.?\s*)//) {
      if (my $frefnum = $entry->getValue('frefnum') || $entry->getValue('refnum')) {
        $OK = 1;
        push(@stuff, ['ltx:text', { class => 'ltx_ref_tag' }, $self->prepRefText($doc, $frefnum)]); } }
    elsif ($show =~ s/^rrefnum(\.?\s*)//) {
      if (my $refnum = $entry->getValue('rrefnum') || $entry->getValue('refnum')) {
        $OK = 1;
        push(@stuff, ['ltx:text', { class => 'ltx_ref_tag' }, $self->prepRefText($doc, $refnum)]); } }
    elsif ($show =~ s/^refnum(\.?\s*)//) {
      if (my $refnum = $entry->getValue('refnum')) {
        $OK = 1;
        push(@stuff, ['ltx:text', { class => 'ltx_ref_tag' }, $self->prepRefText($doc, $refnum)]); } }
    elsif ($show =~ s/^toctitle//) {
      if (my $title = $entry->getValue('toctitle') || $entry->getValue('title')
        || $entry->getValue('toccaption')) {
        $OK = 1;
        push(@stuff, ['ltx:text', { class => 'ltx_ref_title' }, $self->prepRefText($doc, $title)]); } }
    elsif ($show =~ s/^title//) {
      if (my $title = $entry->getValue('title') || $entry->getValue('toccaption')) {    # !!!
        $OK = 1;
        push(@stuff, ['ltx:text', { class => 'ltx_ref_title' }, $self->prepRefText($doc, $title)]); } }
    elsif ($show =~ s/^(.)//) {
      push(@stuff, $1); } }
  return ($OK ? @stuff : ()); }

sub prepRefText {
  my ($self, $doc, $title) = @_;
  return $doc->cloneNodes($doc->trimChildNodes($self->fillInTitle($doc, $title))); }

# Generate a title string for ltx:ref
sub generateTitle {
  my ($self, $doc, $id) = @_;
  # Add author, if any ???
  my $string    = "";
  my $altstring = "";
  while (my $entry = $id && $$self{db}->lookup("ID:$id")) {
    my $title = $self->fillInTitle($doc,
      $entry->getValue('title') || $entry->getValue('rrefnum')
        || $entry->getValue('frefnum') || $entry->getValue('refnum'));
    #    $title = $title->textContent if $title && ref $title;
    $title = getTextContent($doc, $title) if $title && ref $title;
    $title =~ s/^\s+// if $title;
    $title =~ s/\s+$// if $title;
    if ($title) {
      $string .= $$self{ref_join} if $string;
      $string .= $title; }
    $id = $entry->getValue('parent'); }
  return $string || $altstring; }

sub getTextContent {
  my ($doc, $node) = @_;
  my $type = $node->nodeType;
  if ($type == XML_TEXT_NODE) {
    return $node->textContent; }
  elsif ($type == XML_ELEMENT_NODE) {
    my $tag = $doc->getQName($node);
    if ($tag eq 'ltx:tag') {
      return ($node->getAttribute('open') || '')
        . $node->textContent    # assuming no nested ltx:tag
        . ($node->getAttribute('close') || ''); }
    else {
      return join('', map { getTextContent($doc, $_); } $node->childNodes); } }
  elsif ($type == XML_DOCUMENT_FRAG_NODE) {
    return join('', map { getTextContent($doc, $_); } $node->childNodes); }
  else {
    return ''; } }

# Fill in any embedded ltx:ref's & ltx:cite's within a title
sub fillInTitle {
  my ($self, $doc, $title) = @_;
  return $title unless $title && ref $title;
  # Fill in any nested ref's!
  foreach my $ref ($doc->findnodes('descendant::ltx:ref[@idref or @labelref]', $title)) {
    next if $ref->textContent;
    my $show = $ref->getAttribute('show');
    $show = $$self{ref_show} unless $show;
    $show = $$self{toc_show} if $show eq 'fulltitle';
    my $refentry;
    if (my $id = $ref->getAttribute('idref')) {
      $refentry = $$self{db}->lookup("ID:$id"); }
    elsif (my $label = $ref->getAttribute('labelref')) {
      $refentry = $$self{db}->lookup($label);
      if ($id = $refentry->getValue('id')) {
        $refentry = $$self{db}->lookup("ID:$id"); }
      $show =~ s/^type//; }    # Since author may have put explicit \S\ref... in!
    if ($refentry) {
      $doc->replaceNode($ref, $self->generateRef_aux($doc, $refentry, $show)); } }
  # Fill in (replace, actually) any embedded citations.
  foreach my $bibref ($doc->findnodes('descendant::ltx:bibref', $title)) {
    $doc->replaceNode($bibref, $self->make_bibcite($doc, $bibref)); }
  foreach my $break ($doc->findnodes('descendant::ltx:break', $title)) {
    $doc->replaceNode($break, ['ltx:text', {}, " "]); }
  return $title; }

sub fillInGlossaryRef {
  my ($self, $doc) = @_;
  my $n = 0;
  foreach my $ref ($doc->findnodes('descendant::ltx:glossaryref')) {
    $n++;
    my $role = $ref->getAttribute('role') || '';
    my $key  = $ref->getAttribute('key');
    my $show = $ref->getAttribute('show');
    if (my $entry = $$self{db}->lookup(join(':', 'GLOSSARY', $role, $key))) {
      my $title = $entry->getValue('expansion');
      if (!$ref->getAttribute('title') && $title) {
        $ref->setAttribute(title => $title->textContent); }
      if (!$ref->textContent && !element_nodes($ref)) {
        $doc->addNodes($ref, $self->generateGlossaryRefTitle($doc, $entry, $show)); }
    } }
  NoteProgressDetailed(" [Filled in $n glossaryrefs]");
  return; }

sub generateGlossaryRefTitle {
  my ($self, $doc, $entry, $show) = @_;
  my @stuff = ();
  my $OK    = 0;
  while ($show) {
    if ($show =~ s/^short//) {
      if (my $phrase = $entry->getValue('phrase')) {
        $OK = 1;
        push(@stuff, ['ltx:text', { class => 'ltx_glossary_short' },
            $self->prepRefText($doc, $phrase)]); } }
    elsif ($show =~ s/^long//) {
      if (my $phrase = $entry->getValue('expansion')) {
        $OK = 1;
        push(@stuff, ['ltx:text', { class => 'ltx_glossary_long' },
            $self->prepRefText($doc, $phrase)]); } }
    elsif ($show =~ s/^(.)//) {
      push(@stuff, $1); } }
  return ($OK ? @stuff : ()); }

sub orNull {
  return (grep { defined } @_) ? @_ : undef; }
# ================================================================================
1;

