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
use LaTeXML::Common::Error;
use LaTeXML::Common::Locator;
use LaTeXML::BibTeX;
use LaTeXML::BibTeX::BibStyle;
use charnames qw(:full);
use LaTeXML::Post;
use base qw(LaTeXML::Post::Collector);

our $BIBTEX_RERUN_DEFAULT = 5;

# Options:
#   bibliographies : list of bib files containing bibliographies (from bibtex, may be omitted)
#   split  : whether the split into separate pages by initial.
#   reruns : maximum number of re-runs of BibTeX if we get additional \cite{}s, negative value means run forever.
sub new {
  my ($class, %options) = @_;
  my $self = $class->SUPER::new(%options);
  $$self{split}          = $options{split};
  $$self{bibliographies} = $options{bibliographies};
  $$self{reruns}         = $options{reruns} || $BIBTEX_RERUN_DEFAULT;
  return $self; }

# toProcess: Find which items should be processed
sub toProcess {
  my ($self, $doc) = @_;
  return $doc->findnodes('//ltx:bibliography'); }

# process: populate 'ltx:bibliography' with the right kind of bibitems
# This is the main entry point for the MakeBibliography postprocessor.
# NOTE: Weirdly carrying around $config to get $context to get $entry's to get sortkey!
# (for use by split!!!)
sub process {
  my ($self, $doc, @bibs) = @_;
  my @docs = ($doc);
  my ($lstdoc, $lst, $config);
  foreach my $bib (@bibs) {
    next if $doc->findnodes('.//ltx:bibitem', $bib);    # already populated
    ($lstdoc, $lst, $config) = $self->getBibliographyList($doc, $bib);
    next unless defined($lst);
    # remove any previous biblist's from the document
    foreach my $biblist ($doc->findnodes('//ltx:biblist')) {
      $doc->removeNodes($biblist) unless element_nodes($biblist); }
    # insert either a single or a split bibliography
    if ($$self{split}) {
      @docs = $self->insertSplit($doc, $bib, $lstdoc, $lst, $config); }
    else {
      $self->insertSingle($doc, $bib, $lstdoc, $lst, $config); } }
  return @docs; }

# inserts a single <ltx:biblist> into a document
# this is rather straightforward and doesn't really do anything special
sub insertSingle {
  my ($self, $doc, $bib, $lstdoc, $lst, $config) = @_;
  $doc->addNodes($bib, $lst);
  $self->rescan($doc);
  return; }

# split and create document for a single <ltx:biblist> from a single original document
# This roughly works as follows:
# - find all <ltx:bibitem>s in the biblist
# - find the corresponding original .bib entries (from the context of the bbl run)
# - split them into groups based on initial of the first author
# - create a new <ltx:biblist> for each group, with appropriate ids
sub insertSplit {
  my ($self, $doc, $bib, $lstdoc, $lst, $config) = @_;
  my $context = $config->getContext;
  my $split   = {};
  foreach my $node (@{ $lstdoc->findnodes('.//ltx:bibitem', $lst) }) {
    # find the key of this entry
    my $key = $node->getAttribute('key');
    unless (defined($key)) {
      Error('bibtex', $self, undef, "Found an <ltx:bibitem /> without a key. Can't insert it anywhere. ");
      next; }
    # find the entry itself
    my $entry = $context->findEntry($key);
    unless (defined($entry)) {
      Error('bibtex', $self, undef, "Found an <ltx:bibitem /> without an underlying entry. Is the bbl broken? ");
      next; }
    # put this entry into the right split
    my $initial = $self->getSortKey($entry) || '_';
    $$split{$initial} = [] unless defined($$split{$initial});
    push(@{ $$split{$initial} }, $node); }
  # and make new biblists for all the entries
  return map { $self->rescan($_) }
    $self->makeSubCollectionDocuments($doc, $bib,
    map { ($_ => $self->makeSplitBiblist($doc, $bib, $lstdoc, $_, $$split{$_})) }
      sort keys %$split);
}

# makeSplitBiblist creates a new <ltx:biblist> for a given initial with a given list of nodes
sub makeSplitBiblist {
  my ($self, $doc, $bib, $lstdoc, $initial, $nodes) = @_;
  # find the old and new ids
  my $oldlength = length($self->getBibliographyID($doc, $bib, undef));
  my $id        = $self->getBibliographyID($doc, $bib, $initial);
  # replace the old ids with the new ones
  foreach my $node (@$nodes) {
    foreach my $subnode ($lstdoc->findnodes('(.|.//*)[@xml:id]', $node)) {
      $subnode->setAttribute('xml:id', $id . substr($subnode->getAttribute('xml:id'), $oldlength)); } }
  # and return the new element
  return ['ltx:biblist', { 'xml:id' => $id }, @$nodes];
}

# getSortKey gets the key that determines which group a particular .bib entry is placed in.
# The key is either an lowercase letter, a digit, or the empty string.
# TODO: This is based on the sort.key$ at the moment which may not be meaningful (or even empty)
sub getSortKey {
  my ($real) = ((getSortKeyImpl(@_) || '') =~ m/([a-z0-9])/i);
  return lc($real || ''); }

sub getSortKeyImpl {
  my ($self, $entry) = @_;
  # get the entry variable 'sort.key$'
  my ($tp, $value) = $entry->getVariable('sort.key$');
  return unless defined($value) && $tp eq 'STRING';
  # make sure it's a perl string and not an internal string represention
  my ($simple) = simplifyString($value);
  return $simple; }

# given a document and a bibliography, create an appropriate <ltx:biblist> element (and also return the run config)
# This function works roughly as follows:
# - gather context (bibstyle, bibliographies, citations)
# - find the matching bst and compile it
# - generate bbl output, and run it through ltxml
# - re-generate the bbl while there are additional citations in ltxml
sub getBibliographyList {
  my ($self, $doc, $bib) = @_;
  my $bibtex = LaTeXML::BibTeX->new(searchpaths => [$doc->getSearchPaths]);
##  my $style = $bibtex->compileBst($doc, $bib->getAttribute('bibstyle'));
  my $style = LaTeXML::BibTeX::BibStyle->new($bib->getAttribute('bibstyle'), [$doc->getSearchPaths]);
  return unless defined($style);
  my @files = split(',', $bib->getAttribute('files')); # the files that were used in this bibliography
                                                       # find all the referenced citations and flatten
  my @cites = $self->findCites($doc);
  # produce a bbl by emulating bibtex
  my ($bbl, $config) = $bibtex->emulateBibTeX($doc, $style, [@files], [@cites]);
  return unless defined($bbl);                         # Something went wrong => we can't insert it!
###Debug("BBL: ".$bbl);
  # iterate to check for cross-refs
  my $runsLeft = $$self{reruns} == -1 ? -1 : $$self{reruns} + 1;
  my ($lst, $lstdoc, @newCites, $newBBL, $newConfig);
  while (1) {
    $runsLeft--;
    # convert the bbl to an acutal biblist
    ($lstdoc, $lst) = $self->convertBBL($doc, $bib, $bbl);
    return unless defined($lst);    # Something went wrong => we can't insert it!
    last if $runsLeft == 0;         # no runs left => that's it
                                    # check if we had any new cites
    @newCites = $self->findCites($lstdoc, $lst);
    last unless $self->hasNewCites([@cites], [@newCites]);
    Info('bibtex', $self, undef, "Found new citations in BibTeX output, re-running BibTeX ($runsLeft re-runs left)");
    # create the new bbl, and bail out if there is no difference
    ($newBBL, $newConfig) = $bibtex->emulateBibTeX($doc, $style, [@files], [(@cites, @newCites)]);
    if ($newBBL eq $bbl) {
      Info('bibtex', $self, undef, "BibTeX output did not change, will not re-run BibTeX");
      last; }
    # prepare the next iteration for a re-run
    $bbl    = $newBBL;
    $config = $newConfig; }
  # return the last output we got
  return $lstdoc, $lst, $config; }

# findCites finds everything that is cited in a given node
sub findCites {
  my ($self, $doc, $node) = @_;
  $node = $doc->getDocumentElement unless defined($node);
  my @cites = grep { defined($_) && $_ } map { $_->getAttribute('bibrefs') } $doc->findnodes('.//ltx:bibref', $node);
  return split(',', join(',', @cites)); }

# hasNewCites checks if we got a new citation that hasn't been cited before
sub hasNewCites {
  my ($self, $cites, $newCites) = @_;
  # if we have something that didn't exist before, return 1
  my %oldcites = map { $_ => 1 } @$cites;
  foreach my $new (@$newCites) {
    return 1 unless defined($oldcites{$new}); }
  # else there is nothing new
  return 0; }

# This converts the bbl output into a new Document
sub convertBBL {
  my ($self, $doc, $bib, $bbl) = @_;
  # imports
  require LaTeXML;
  require LaTeXML::Common::Config;
  # load the documentclass and packages of the parent document
  my @preload = ();
  my ($classdata, @packages)     = $self->find_documentclass_and_packages($doc);
  my ($class,     $classoptions) = @$classdata;
  if ($class) {
    push(@preload, ($classoptions ? "[$classoptions]$class.cls" : "$class.cls")); }
  foreach my $po (@packages) {
    my ($pkg, $options) = @$po;
    push(@preload, ($options ? "[$options]$pkg.sty" : "$pkg.sty")); }
  # convert the bibliography
  my $stage = "Recursive MakeBibliography";
  ProgressSpinup($stage);
  my $config = LaTeXML::Common::Config->new(
    recursive => 1,
    cache_key => 'BibTeX',
    post      => 0,
    format    => 'dom',
    whatsin   => 'tex',
    whatsout  => 'document',
    #    documentid     => $self->getBibliographyID($doc, $bib, undef),
###    documentid     => $doc->getDocumentElement->getAttribute('xml:id'),
    bibliographies => [],
    (@preload ? (preload => [@preload]) : ()));
  my $converter = LaTeXML->get_converter($config);
  # Tricky and HACKY, we need to release the log to capture the inner workings separately.
  # ->bind_log analog:
  my $biblog = '';

  $converter->prepare_session($config);
  my $response = $converter->convert("literal:\\begin{document}$bbl\\end{document}");

  # Trim log to look internal and report.
  $biblog =~ s/^.+?\(Digesting/\n\(Digesting/s;
  $biblog =~ s/Conversion complete:.+$//s;
  MergeStatus($$converter{latexml}{state});

  ProgressSpindown($stage);
  if (my $xml = $$response{result}) {
    # Do we really need a new Document?
###Debug("CONVERT yeilded doc:".$xml->toString);
    my $bibdoc = $doc->new($xml, sourceDirectory => '.');
    # find the biblist
    my $biblist = $bibdoc->findnode('//ltx:biblist');
    Fatal('bibtex', $self, undef, "BBL did not produce a biblist") unless (defined($biblist));
    # and return it!
    return ($bibdoc, $biblist); }
  else {
    Debug("... Failed!)");
    return; } }

# gets the id of a bibliography element
sub getBibliographyID {
  my ($self, $doc, $bib, $inital) = @_;
  my $id = $bib->getAttribute('xml:id')
    || $doc->getDocumentElement->getAttribute('xml:id') || 'bib';
###  $id .= ".L1";
###  $id .= ".$inital" if defined($inital);
  #Debug("ID=>$id");
  return $id; }

# ================================================================================
1;
