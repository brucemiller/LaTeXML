# /=====================================================================\ #
# |  LaTeXML::Post                                                      | #
# | PostProcessing driver                                               | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post;
use strict;
use warnings;
use Time::HiRes;
use LaTeXML::Util::Radix;
use Encode;
use base qw(Exporter);
our @EXPORT = (qw( &NoteProgress &NoteProgressDetailed &NoteBegin &NoteEnd
    &Fatal &Error &Warn &Info));

sub new {
  my ($class, %options) = @_;
  my $self = bless { status => {}, %options }, $class;
  $$self{verbosity} = 0 unless defined $$self{verbosity};
  return $self; }

#======================================================================
sub ProcessChain {
  my ($self, $doc, @postprocessors) = @_;
  local $LaTeXML::POST = $self;
  local $SIG{__DIE__} = sub { Fatal('perl', 'die', undef, "Perl died", @_); };
  local $SIG{INT} = sub { Fatal('perl', 'interrupt', undef, "LaTeXML was interrupted", @_); };
  local $SIG{__WARN__} = sub { Warn('perl', 'warn', undef, "Perl warning", @_); };
  local $LaTeXML::Post::NOTEINFO = undef;
  local $LaTeXML::Post::DOCUMENT = $doc;
  my @docs = ($doc);
  NoteBegin("post-processing");

  foreach my $processor (@postprocessors) {
    local $LaTeXML::Post::PROCESSOR = $processor;
    my @newdocs = ();
    foreach my $doc (@docs) {
      local $LaTeXML::Post::DOCUMENT = $doc;
      if (my @nodes = grep { $_ } $processor->toProcess($doc)) {    # If there are nodes to process
        my $n = scalar(@nodes);
        my $msg = ($n > 1 ? "$n to process" : 'processing');
        NoteBegin($msg);
        push(@newdocs, $processor->process($doc, @nodes));
        NoteEnd($msg); }
      else {
        push(@newdocs, $doc); } }
    @docs = @newdocs; }
  NoteEnd("post-processing");
  return @docs; }

sub getStatusMessage {
  my ($self) = @_;
  my $status = $$self{status};
  my @report = ();
  push(@report, "$$status{warning} warning" . ($$status{warning} > 1 ? 's' : '')) if $$status{warning};
  push(@report, "$$status{error} error" .       ($$status{error} > 1 ? 's' : '')) if $$status{error};
  push(@report, "$$status{fatal} fatal error" . ($$status{fatal} > 1 ? 's' : '')) if $$status{fatal};
  return join('; ', @report) || 'No obvious problems'; }

#======================================================================
# Error & Progress reporting.
# Designed to mimic Behaviour & API in Conversion phase.
# [maybe will someday be (re)unified!]

sub NoteProgress {
  my (@messages) = @_;
  print STDERR @messages if getVerbosity() >= 0;
  return; }

sub NoteProgressDetailed {
  my (@messages) = @_;
  print STDERR @messages if getVerbosity() >= 1;
  return; }

our %note_timers = ();

sub NoteBegin {
  my ($op) = @_;
  if (getVerbosity() >= 0) {
    my $proc = ($LaTeXML::Post::PROCESSOR && (ref $LaTeXML::Post::PROCESSOR)) || '';
    $proc =~ s/^LaTeXML::Post:://;
    my $doc = ($LaTeXML::Post::DOCUMENT && $LaTeXML::Post::DOCUMENT->siteRelativeDestination) || '';
    # Note when this processor started on this document doing this operation.
    my $key = $proc . ' ' . $doc . ' ' . $op;
    $note_timers{$key} = [Time::HiRes::gettimeofday];
    my ($prevproc, $prevdoc, $prevop) = @{ $LaTeXML::NOTEINFO || ['', '', ''] };
    my $msg = join(' ', ($proc && ($proc ne $prevproc) ? ($proc) : ()),
      ($doc && ($doc ne $prevdoc) ? ($doc) : ()),
      ($op  && ($op ne $prevop)   ? ($op)  : ()));
    $LaTeXML::Post::NOTEINFO = [$proc, $doc, $op];
    print STDERR "\n($msg..."; }
  return; }

sub NoteEnd {
  my ($op) = @_;
  if (getVerbosity() >= 0) {
    my $p = ($LaTeXML::Post::PROCESSOR && (ref $LaTeXML::Post::PROCESSOR)) || '';
    my $d = ($LaTeXML::Post::DOCUMENT && $LaTeXML::Post::DOCUMENT->siteRelativeDestination) || '';
    my $key = $p . ' ' . $d . ' ' . $op;
    if (my $start = $note_timers{$key}) {
      undef $note_timers{$key};
      my $elapsed = Time::HiRes::tv_interval($start, [Time::HiRes::gettimeofday]);
      print STDERR sprintf(" %.2f sec)", $elapsed); } }
  return; }

sub Fatal {
  my ($category, $object, $where, $message, @details) = @_;
  my $verbosity = getVerbosity();
  if (!$LaTeXML::Common::Error::InHandler && defined($^S)) {    # Careful about recursive call!
    $LaTeXML::POST && $$LaTeXML::POST{status}{fatal}++;
    $message
      = generateMessage("Fatal:" . $category . ":" . ToString($object), $where, $message, 1,
      @details);
  }
  else {    # If we ARE in a recursive call, the actual message is $details[0]
    $message = $details[0] if $details[0]; }
  local $LaTeXML::Common::Error::InHandler = 1;
  if ($verbosity > 1) {
    require Carp;
    Carp::croak $message; }
  else {
    die $message; } }

# Note that "100" is hardwired into TeX, The Program!!!
our $MAXERRORS = 100;

# Should be fatal if strict is set, else warn.
sub Error {
  my ($category, $object, $where, $message, @details) = @_;
  $LaTeXML::POST && $$LaTeXML::POST{status}{error}++;
  print STDERR generateMessage("Error:" . $category . ":" . ToString($object), $where, $message, 1, @details)
    if getVerbosity() > -3;
  Fatal('too_many_errors', $MAXERRORS, $where, "Too many errors (> $MAXERRORS)!")
    if $LaTeXML::POST && ($$LaTeXML::POST{status}{error} > $MAXERRORS);
  return; }

# Warning message; results may be OK, but somewhat unlikely
sub Warn {
  my ($category, $object, $where, $message, @details) = @_;
  $LaTeXML::POST && $$LaTeXML::POST{status}{warning}++;
  print STDERR generateMessage("Warning:" . $category . ":" . ToString($object),
    $where, $message, 0, @details)
    if getVerbosity() > -2;
  return; }

# Informational message; results likely unaffected
# but the message may give clues about subsequent warnings or errors
sub Info {
  my ($category, $object, $where, $message, @details) = @_;
  $LaTeXML::POST && $$LaTeXML::POST{status}{info}++;
  print STDERR generateMessage("Info:" . $category . ":" . ToString($object), $where, $message, 0, @details)
    if getVerbosity() > -1;
  return; }

#----------------------------------------------------------------------
# Support for above.
our %NOBLESS = map { ($_ => 1) } qw( SCALAR HASH ARRAY CODE REF GLOB LVALUE);

sub ToString {
  my ($object) = @_;
  my $r = ref $object;
  return ($r && !$NOBLESS{$r} && $object->can('toString') ? $object->toString : "$object"); }

sub getVerbosity {
  return ($LaTeXML::POST && $$LaTeXML::POST{verbosity}) || 0; }

# mockup similar to the one in Error.pm
# We'll want to make that one do both, or maybe let this one do stack trace or...
sub generateMessage {
  my ($errorcode, $where, $message, $long, @extra) = @_;
  my $docloc = join(' ', grep { $_ }
      ($LaTeXML::Post::PROCESSOR
      ? ("Postprocessing " . (ref $LaTeXML::Post::PROCESSOR))
      : ()),
    ($LaTeXML::Post::DOCUMENT
      ? ($LaTeXML::Post::DOCUMENT->siteRelativeDestination)
      : ()),
    (defined $where ? (ToString($where)) : ()));
  ($message, @extra) = grep { $_ ne '' } map { split("\n", $_) } grep { defined $_ } $message, @extra;
  my @lines = ($errorcode . ' ' . $message,
    ($docloc ? ($docloc) : ()),
    @extra);
  return "\n" . join("\n\t", @lines) . "\n"; }

#======================================================================
# Given a base id, a counter (eg number of duplications of id) and a suffix,
# create a (hopefully) unique id
sub uniquifyID {
  my ($baseid, $counter, $suffix) = @_;
  return $baseid . radix_alpha($counter) . ($suffix || ''); }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
package LaTeXML::Post::Processor;
use strict;
use LaTeXML::Post;
LaTeXML::Post->import();    # but that doesn't work, so do this, until we REORGANIZE
use LaTeXML::Common::XML;
use LaTeXML::Util::Pathname;

# An Abstract Post Processor
sub new {
  my ($class, %options) = @_;
  my $self = bless {%options}, $class;
  $$self{verbosity}          = 0 unless defined $$self{verbosity};
  $$self{resource_directory} = $options{resource_directory};
  $$self{resource_prefix}    = $options{resource_prefix};
  return $self; }

# Return the nodes to be processed; by default the document element.
# This allows processors to focus on specific kinds of nodes,
# or to skip processing if there are none to process.
sub toProcess {
  my ($self, $doc) = @_;
  return $doc->getDocumentElement; }

# This must be defined to do whatever processing is needed to @toprocess nodes.
sub process {
  my ($self, $doc, @toprocess) = @_;
  Fatal("misdefined", $self, $doc, "This post-processor is abstract; does not implement ->process");
  return $doc; }

#======================================================================
# Some postprocessors will want to create a bunch of "resource"s,
# such as generated or transformed image files, or other data files.
# These should return a pathname, relative to the document's destination,
# for storing a resource associated with $node.
# Will use the Post option resource_directory
sub desiredResourcePathname {
  my ($self, $doc, $node, $source, $type) = @_;
  return; }

# Ideally this would return a pathname relative to the document
# but I think we've accommodated absolute ones.
sub generateResourcePathname {
  my ($self, $doc, $node, $source, $type) = @_;
  my $subdir = $$self{resource_directory} || '';
  my $prefix = $$self{resource_prefix}    || "x";
  my $counter = join('_', "_max", $subdir, $prefix, "counter_");
  my $n = $doc->cacheLookup($counter) || 0;
  my $name = $prefix . ++$n;
  $doc->cacheStore($counter, $n);
  return pathname_make(dir => $subdir, name => $name, type => $type); }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
package LaTeXML::Post::MathProcessor;
use strict;
use LaTeXML::Post;
LaTeXML::Post->import();    # but that doesn't work, so do this, until we REORGANIZE
use base qw(LaTeXML::Post::Processor);
use LaTeXML::Common::XML;

# This is an abstract class; A complete MathProcessor will need to define:
#    $self->convertNode($doc,$xmath)
#        to generate the converted math node
#    $self->combineParallel($doc,$math,$primary,@secondaries)
#        to combine the $primary (the result of $self's conversion of $math)
#        with the results of other math processors to create the
#        parallel markup appropriate for this processor's markup.
#    $self->rawIDSuffix returns a short string to append to id's for nodes
#        using this markup.

# Top level processing finds and converts all math nodes.
# Invokes preprocess on each before doing the conversion in case
# analysis is needed.
sub toProcess {
  my ($self, $doc) = @_;
  return $doc->findnodes('//ltx:Math'); }

sub process {
  my ($self, $doc, @maths) = @_;
  local $LaTeXML::Post::MATHPROCESSOR = $self;
  $doc->markXMNodeVisibility;
  $self->preprocess($doc, @maths);
  if ($$self{parallel}) {
    my @secondaries = @{ $$self{secondary_processors} };
    my $f;
    LaTeXML::Post::NoteProgressDetailed(" [parallel " .
        join(',', map { (($f = $_) =~ s/^LaTeXML::Post::// ? $f : $f) } map { ref $_ } @secondaries) . "]");
    foreach my $proc (@secondaries) {
      local $LaTeXML::Post::MATHPROCESSOR = $proc;
      $proc->preprocess($doc, @maths); } }
  # Re-Fetch the math nodes, in case preprocessing has messed them up!!!
  @maths = $self->toProcess($doc);

  ## Do in reverse, since (in LaTeXML) we allow math nested within text within math.
  ## So, we want to converted any nested expressions first, so they get carried along
  ## with the outer ones.
  foreach my $math (reverse(@maths)) {
    # If parent is MathBranch, which branch number is it?
    # (note: the MathBranch will be in a ltx:MathFork, with a ltx:Math being 1st child)
    my @preceding = $doc->findnodes("parent::ltx:MathBranch/preceding-sibling::*", $math);
    local $LaTeXML::Post::MathProcessor::FORK = scalar(@preceding);
    $self->processNode($doc, $math); }

  # Experimentally, cross reference ??? (or clearer name?)
  if ($$self{parallel}) {
    # There could be various strategies when there are more than 2 parallel conversions,
    # eg a cycle or something....
    # Here, we simply take the first two processors that know how to addCrossref
    # and connect their nodes to each other.
    my ($proc1, $proc2, @ignore)
      = grep { $_->can('addCrossref') } $self, @{ $$self{secondary_processors} };
    if ($proc1 && $proc2) {
      $proc1->addCrossrefs($doc, $proc2);
      $proc2->addCrossrefs($doc, $proc1); } }
  $doc->unmarkXMNodeVisibility;

  return $doc; }

# Make THIS MathProcessor the primary branch (of whatever parallel markup it supports),
# and make all of the @moreprocessors be secondary ones.
sub setParallel {
  my ($self, @moreprocessors) = @_;
  if (@moreprocessors) {
    $$self{parallel} = 1;
    map { $$_{is_secondary} = 1 } @moreprocessors;    # Mark the others as secondary
    $$self{secondary_processors} = [@moreprocessors]; }
  else {
    $$self{parallel} = 0; }
  return; }

# Optional; if you want to do anything before translation
sub preprocess {
  my ($self, $doc, @nodes) = @_;
  return; }

# $self->processNode($doc,$mathnode) is the top-level conversion
# It converts the XMath within $mathnode, and adds it to the $mathnode,
# This invokes $self->convertNode($doc,$xmath) to get the conversion.
sub processNode {
  my ($self, $doc, $math) = @_;
  my $xmath = $doc->findnode('ltx:XMath', $math);
  return unless $xmath;    # Nothing to convert if there's no XMath ... !
  local $LaTeXML::Post::MATHPROCESSOR = $self;
  my $conversion;
  if ($$self{parallel}) {
    my $primary = $self->convertNode($doc, $xmath);
    my @secondaries = ();
    foreach my $proc (@{ $$self{secondary_processors} }) {
      local $LaTeXML::Post::MATHPROCESSOR = $proc;
      my $secondary = $proc->convertNode($doc, $xmath);
      # IF it is (first) image, copy image attributes to ltx:Math ???
      $self->maybeSetMathImage($math, $secondary);
      push(@secondaries, $secondary); }
    $conversion = $self->combineParallel($doc, $xmath, $primary, @secondaries); }
  else {
    $conversion = $self->convertNode($doc, $xmath);
    $self->maybeSetMathImage($math, $conversion); }
  # we now REMOVE the ltx:XMath from the ltx:Math, and whitespace
  # (if there's an XMath PostProcessing module, it will add it back, with appropriate id's)
  if (my $xml = $$conversion{xml}) {
    $$conversion{xml} = $self->outerWrapper($doc, $xmath, $xml); }
  $doc->removeNodes($xmath);
  $doc->removeBlankNodes($math);
  if (my $new = $$conversion{xml}) {
    $doc->addNodes($math, $new); }
  # else ?
  return; }

sub maybeSetMathImage {
  my ($self, $math, $conversion) = @_;
  if ((($$conversion{mimetype} || '') =~ /^image\//)    # Got an image?
    && !$math->getAttribute('imagesrc')) {              # and it's the first one
    if (my $src = $$conversion{src}) {
      $math->setAttribute(imagesrc    => $src);
      $math->setAttribute(imagewidth  => $$conversion{width});
      $math->setAttribute(imageheight => $$conversion{height});
      $math->setAttribute(imagedepth  => $$conversion{depth}); } }
  return; }

# NOTE: Sort out how parallel & outerWrapper should work.
# It probably ought to be that if the conversion is being embedded in
# something from another namespace, it needs the wrapper.
# ie. when mixing parallel markups, NOT just at the top level, although certainly there too.
#
# This should wrap the resulting conversion with m:math or om:OMA or whatever appropriate?
sub outerWrapper {
  my ($self, $doc, $xmath, $conversion) = @_;
  return $conversion; }

# This should proably be from the core of the current ->processNode
sub convertNode {
  my ($self, $doc, $node) = @_;
  Fatal('misdefined', (ref $self), undef,
    "Abstract package: math conversion has not been defined for this MathProcessor");
  return; }

# This should be implemented by potential Primaries
# Maybe the caller of this should check the namespaces, and call wrapper if needed?
sub combineParallel {
  my ($self, $doc, $xmath, $primary, @secondaries) = @_;
  LaTeXML::Post::Error('misdefined', (ref $self), undef,
    "Abstract package: combining parallel markup has not been defined for this MathProcessor",
    "dropping the extra markup from: " . join(',', map { $$_{processor} } @secondaries));
  return $primary; }

# When converting an XMath node (with an id) to some other format,
# we will generate an id for the new node.
# This method returns a suffix to be added to the XMath id.
# The suffix comes from:
#  * When the node is in the n-th MathBranch of a MathFork, it gets ".fork<n>"
#  * When the format is not the primary format, it gets a suffix based on type (eg. ".pmml")
sub IDSuffix {
  my ($self) = @_;
####  ($LaTeXML::Post::MathProcessor::FORK ? ".fork".$LaTeXML::Post::MathProcessor::FORK : '') .
  return ($$self{is_secondary} ? $self->rawIDSuffix : ''); }

sub rawIDSuffix {
  return ''; }

# Given an array-represented XML $node, add an id attribute to the node
# and all children w/o id's (stopping when id encountered).
# The id will be derived from $sourceid using the appropriate IDSuffix,
# and bumping the id counter to avoid conflicts with any other node derived
# from that same source id.
# Moreover, unless $noxref, the new ids will be recorded as having been generated from $sourceid,
# so that cross-referencing in parallel markup can be effected.
sub associateID {
  my ($self, $node, $sourceid, $noxref) = @_;
  return $node unless $sourceid && ref $node;
  # or if already has an id (do we still need bookkeeping?)
  return if (ref $node eq 'ARRAY' ? $$node[1]{'xml:id'} : $node->getAttribute('xml:id'));
  my $id = $sourceid . $self->IDSuffix;
  if (my $ctr = $$self{convertedID_counter}{$sourceid}++) {
    $id = LaTeXML::Post::uniquifyID($sourceid, $ctr, $self->IDSuffix); }
  push(@{ $$self{convertedIDs}{$sourceid} }, $id) unless $noxref;
  if (ref $node eq 'ARRAY') {    # Array represented
    $$node[1]{'xml:id'} = $id;
    map { $self->associateID_aux($_, $sourceid, $noxref) } @$node[2 .. $#$node]; }
  else {                         # LibXML node
    $node->setAttribute('xml:id' => $id);
    map { $self->associateID_aux($_, $sourceid, $noxref) } $node->childNodes; }
  return $node; }

sub associateID_aux {
  my ($self, $node, $sourceid, $noxref) = @_;
  if (!ref $node) { }
  elsif (ref $node eq 'ARRAY') {    # Array represented
    $self->associateID($node, $sourceid, $noxref); }
  elsif ($node->nodeType == XML_ELEMENT_NODE) {
    $self->associateID($node, $sourceid, $noxref); }
  return; }

# Add backref linkages (eg. xref) onto the nodes that $self created (converted from XMath)
# to reference those that $otherprocessor created.
# NOTE: Subclass MUST define addCrossref($node,$xref_id) to add the
# id of the "Other Interesting Node" to the (array represented) xml $node
# in whatever fashion the markup for that processor uses.
sub addCrossrefs {
  my ($self, $doc, $otherprocessor) = @_;
  my $selfs_map  = $$self{convertedIDs};
  my $others_map = $$otherprocessor{convertedIDs};
  foreach my $xid (keys %$selfs_map) {    # For each XMath id that $self converted
    if (my $other_ids = $$others_map{$xid}) {    # Did $other also convert those ids?
      if (my $xref_id = $other_ids && $$other_ids[0]) {    # get (first) id $other created from $xid.
        foreach my $id (@{ $$selfs_map{$xid} }) {          # look at each node $self created from $xid
          if (my $node = $doc->findNodeByID($id)) {        # If we find a node,
            $self->addCrossref($node, $xref_id); } } } } }    # add a crossref from it to $others's node
  return; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

package LaTeXML::Post::Document;
use strict;
use LaTeXML::Common::XML;
use LaTeXML::Util::Pathname;
use DB_File;
use Unicode::Normalize;
use LaTeXML::Post;          # to import error handling...
LaTeXML::Post->import();    # but that doesn't work, so do this, until we REORGANIZE
our $NSURI = "http://dlmf.nist.gov/LaTeXML";
our $XPATH = LaTeXML::Common::XML::XPath->new(ltx => $NSURI);

# Useful options:
#   destination = the ultimate destination file for this document to be written.
#   destinationDirectory = the directory it will be stored in (derived from $destination)
#   siteDirectory = the root directory of where the entire site will be contained
#   namespaces = a hash of namespace prefix => namespace uri
#   namespaceURIs = reverse hash of above.
#   nocache = a boolean, disables storing of permanent LaTeXML.cache
#     the cache is used to remember things like image conversions from previous runs.
#   searchpaths = array of paths to search for other resources
sub new {
  my ($class, $xmldoc, %options) = @_;
  my %data = ();
  if (ref $class) {    # Cloning!
    map { $data{$_} = $$class{$_} } keys %$class;
    $class = ref $class; }
  map { $data{$_} = $options{$_} } keys %options;    # These override.
  if ((defined $options{destination}) && (!defined $options{destinationDirectory})) {
    my ($dir, $name, $ext) = pathname_split($data{destination});
    $data{destinationDirectory} = $dir || '.'; }
  # Check consistency of siteDirectory (providing there's a destinationDirectory)
  if ($data{destinationDirectory}) {
    if ($data{siteDirectory}) {
      Fatal('unexpected', $data{destinationDirectory}, undef,
        "The destination directory ($data{destinationDirectory})"
          . " must be within the siteDirectory ($data{siteDirectory})")
        unless pathname_is_contained($data{destinationDirectory}, $data{siteDirectory}); }
    else {
      $data{siteDirectory} = $data{destinationDirectory}; } }

  $data{document} = $xmldoc;
  if (!$xmldoc || !($xmldoc->documentElement)) {
    Fatal('expected', 'document', undef, "Document has no root element"); }
  $data{namespaces}    = { ltx    => $NSURI } unless $data{namespaces};
  $data{namespaceURIs} = { $NSURI => 'ltx' }  unless $data{namespaceURIs};

  # Fetch any additional namespaces
  foreach my $ns ($xmldoc->documentElement->getNamespaces) {
    my ($prefix, $uri) = ($ns->getLocalName, $ns->getData);
    if ($prefix) {
      $data{namespaces}{$prefix} = $uri    unless $data{namespaces}{$prefix};
      $data{namespaceURIs}{$uri} = $prefix unless $data{namespaceURIs}{$uri}; } }

  # Extract data from latexml's ProcessingInstructions
  # I'd like to provide structured access to the PI's for those modules that need them,
  # but it isn't quite clear what that api should be.
  $data{processingInstructions} =
    [map { $_->textContent } $XPATH->findnodes('.//processing-instruction("latexml")', $xmldoc)];

  # Combine specified paths with any from the PI's
  my @paths = ();
  @paths = @{ $data{searchpaths} } if $data{searchpaths};
  foreach my $pi (@{ $data{processingInstructions} }) {
    if ($pi =~ /^\s*searchpaths\s*=\s*([\"\'])(.*?)\1\s*$/) {
      push(@paths, split(',', $2)); } }
  push(@paths, pathname_absolute($data{sourceDirectory})) if $data{sourceDirectory};
  $data{searchpaths} = [@paths];

  my $self = bless {%data}, $class;
  $$self{idcache} = {};
  foreach my $node ($self->findnodes("//*[\@xml:id]")) {
###print STDERR "INIT $$self{destination} ID=".$node->getAttribute('xml:id')."\n";
    $$self{idcache}{ $node->getAttribute('xml:id') } = $node; }
  # Possibly disable permanent cache?
  ### NO this is NOT a safe way to do this....
  ### $$self{cache} = {} if $data{nocache};
  return $self; }

sub newFromFile {
  my ($class, $source, %options) = @_;
  $options{source} = $source;
  if (!$options{sourceDirectory}) {
    my ($dir, $name, $ext) = pathname_split($source);
    $options{sourceDirectory} = $dir || '.'; }
  my $doc = $class->new(LaTeXML::Common::XML::Parser->new()->parseFile($source), %options);
  $doc->validate if $$doc{validate};
  return $doc; }

sub newFromString {
  my ($class, $string, %options) = @_;
  $options{sourceDirectory} = '.' unless $options{sourceDirectory};
  my $doc = $class->new(LaTeXML::Common::XML::Parser->new()->parseString($string), %options);
  $doc->validate if $$doc{validate};
  return $doc; }

sub newFromSTDIN {
  my ($class, %options) = @_;
  my $string;
  { local $/ = undef; $string = <>; }
  $options{sourceDirectory} = '.' unless $options{sourceDirectory};
  my $doc = $class->new(LaTeXML::Common::XML::Parser->new()->parseString($string), %options);
  $doc->validate if $$doc{validate};
  return $doc; }

sub getDocument {
  my ($self) = @_;
  return $$self{document}; }

sub getDocumentElement {
  my ($self) = @_;
  return $$self{document}->documentElement; }

sub getSource {
  my ($self) = @_;
  return $$self{source}; }

sub getSourceDirectory {
  my ($self) = @_;
  return $$self{sourceDirectory} || '.'; }

sub getSearchPaths {
  my ($self) = @_;
  return @{ $$self{searchpaths} }; }

sub getDestination {
  my ($self) = @_;
  return $$self{destination}; }

sub getDestinationDirectory {
  my ($self) = @_;
  return $$self{destinationDirectory}; }

sub getSiteDirectory {
  my ($self) = @_;
  return $$self{siteDirectory}; }

# Given an absolute pathname in the document destination directory,
# return the corresponding pathname relative to the site directory (they maybe different!).
sub siteRelativePathname {
  my ($self, $pathname) = @_;
  return (defined $pathname ? pathname_relative($pathname, $$self{siteDirectory}) : undef); }

sub siteRelativeDestination {
  my ($self) = @_;
  return (defined $$self{destination}
    ? pathname_relative($$self{destination}, $$self{siteDirectory})
    : undef); }

sub getParentDocument {
  my ($self) = @_;
  return $$self{parentDocument}; }

sub getAncestorDocument {
  my ($self) = @_;
  my ($doc, $d) = $self;
  while ($d = $$doc{parentDocument}) {
    $doc = $d; }
  return $doc; }

sub toString {
  my ($self) = @_;
  return $$self{document}->toString(1); }

sub getDestinationExtension {
  my ($self) = @_;
  return ($$self{destination} =~ /\.([^\.\/]*)$/ ? $1 : undef); }

sub checkDestination {
  my ($self, $reldest) = @_;
  # make absolute (if not already absolute), hopefully in destination directory.
  my $dest = pathname_absolute($reldest, $self->getDestinationDirectory);
  if (my $destdir = pathname_directory($dest)) {
    pathname_mkdir($destdir)
      or return Fatal("I/O", $destdir, undef,
      "Could not create directory $destdir for $reldest: $!"); }
  return $dest; }

#======================================================================
sub validate {
  my ($self) = @_;
  # Check for a RelaxNGSchema PI
  my $schema;
  foreach my $pi (@{ $$self{processingInstructions} }) {
    if ($pi =~ /^\s*RelaxNGSchema\s*=\s*([\"\'])(.*?)\1\s*$/) {
      $schema = $2; } }
  if ($schema) {    # Validate using rng
    my $rng = LaTeXML::Common::XML::RelaxNG->new($schema, searchpaths => [$self->getSearchPaths]);
    LaTeXML::Post::Error('I/O', $schema, undef, "Failed to load RelaxNG schema $schema" . "Response was: $@")
      unless $rng;
    my $v = eval { $rng->validate($$self{document}); };
    LaTeXML::Post::Error("malformed", 'document', undef,
      "Document fails RelaxNG validation (" . $schema . ")",
      "Validation reports: " . $@) if $@ || !defined $v; }
  elsif (my $decldtd = $$self{document}->internalSubset) {    # Else look for DTD Declaration
    my $dtd = XML::LibXML::Dtd->new($decldtd->publicId, $decldtd->systemId);
    if (!$dtd) {
      LaTeXML::Post::Error("I/O", $decldtd->publicId, undef,
        "Failed to load DTD " . $decldtd->publicId . " at " . $decldtd->systemId,
        "skipping validation"); }
    else {
      my $v = eval { $$self{document}->validate($dtd); };
      LaTeXML::Post::Error("malformed", 'document', undef,
        "Document failed DTD validation (" . $decldtd->systemId . ")",
        "Validation reports: " . $@) if $@ || !defined $v; } }
  else {                                                      # Nothing found to validate with
    LaTeXML::Post::Warn("expected", 'schema', undef,
      "No Schema or DTD found for this document"); }
  return; }

sub idcheck {
  my ($self)  = @_;
  my %idcache = ();
  my %dups    = ();
  my %missing = ();
  foreach my $node ($self->findnodes("//*[\@xml:id]")) {
    my $id = $node->getAttribute('xml:id');
    $dups{$id} = 1 if $idcache{$id};
    $idcache{$id} = 1; }
  foreach my $id (keys %{ $$self{idcache} }) {
    $missing{$id} = 1 unless $idcache{$id}; }
  LaTeXML::Post::Warn("unexpected", 'ids', undef,
    "IDs were duplicated in cache for " . $self->siteRelativeDestination,
    join(',', keys %dups))
    if keys %dups;
  LaTeXML::Post::Warn("expected", 'ids', undef, "IDs were cached for " . $self->siteRelativeDestination
      . " but not in document",
    join(',', keys %missing))
    if keys %missing;
  return; }

#======================================================================
sub findnodes {
  my ($self, $path, $node) = @_;
  return $XPATH->findnodes($path, $node || $$self{document}); }

# Similar but returns only 1st node
sub findnode {
  my ($self, $path, $node) = @_;
  my ($first) = $XPATH->findnodes($path, $node || $$self{document});
  return $first; }

sub findvalue {
  my ($self, $path, $node) = @_;
  return $XPATH->findvalue($path, $node || $$self{document}); }

sub addNamespace {
  my ($self, $nsuri, $prefix) = @_;
  if (!$$self{namespaces}{$prefix} || ($$self{namespaces}{$prefix} ne $nsuri)
    || (($self->getDocumentElement->lookupNamespacePrefix($nsuri) || '') ne $prefix)) {
    $$self{namespaces}{$prefix}   = $nsuri;
    $$self{namespaceURIs}{$nsuri} = $prefix;
    $XPATH->registerNS($prefix => $nsuri);
    $self->getDocumentElement->setNamespace($nsuri, $prefix, 0); }
  return; }

use Carp;

sub getQName {
  my ($self, $node) = @_;
  if (ref $node eq 'ARRAY') {
    return $$node[0]; }
  elsif (ref $node eq 'XML::LibXML::Element') {
    my $nsuri = $node->namespaceURI;
    if (!$nsuri) {    # No namespace at all???
      if ($node->nodeType == XML_ELEMENT_NODE) {
        return $node->localname; }
      else {
        return; } }
    elsif (my $prefix = $$self{namespaceURIs}{$nsuri}) {
      return $prefix . ":" . $node->localname; }
    else {
      # Hasn't got one; we'll create a prefix for internal use.
      my $prefix = "_ns" . (1 + scalar(grep { /^_ns\d+$/ } keys %{ $$self{namespaces} }));
      # Register it, but Don't add it to the document!!! (or xpath, for that matter)
      $$self{namespaces}{$prefix}   = $nsuri;
      $$self{namespaceURIs}{$nsuri} = $prefix;
      return $prefix . ":" . $node->localname; } }
  else {
    #    confess "What's this? $node\n";
    return; } }

#======================================================================
# ADD nodes to $node in the document $self.
# This takes a convenient recursive reprsentation for xml:
# data = string |  [$tagname, {attr=>value,..}, @children...]
# The $tagname should have a namespace prefix whose URI has been
# registered with addNamespace.

# Note that we're currently ignoring duplicated ids.
# these should only happen from rearrangement and copying of document fragments
# with embedded bits of math in them, which have those XMTok/XMRef pairs.
# If those are the cases, we should end up finding the original id'd item, anyway, right?
#
# NOTE that only XML::LibXML's addNewChild deals cleanly with namespaces
# and since there is only an "add" (ie. append) version (not prepend, insert after, etc)
# we have to orient everything towards appending.
# In particular, see the perversity in the following few methods.
sub addNodes {
  my ($self, $node, @data) = @_;
  foreach my $child (@data) {
    if (ref $child eq 'ARRAY') {
      my ($tag, $attributes, @children) = @$child;
      if ($tag eq '_Fragment_') {
        my $indent;    # Derive indentation from indentation of $node
        if (my $pre = $node->previousSibling) {
          if (($pre->nodeType == XML_TEXT_NODE) && (($pre = $pre->textContent) =~ /^\s*$/)) {
            $indent = $pre . '  '; } }
        if ($indent) {
          $self->addNodes($node, map { ($indent, $_) } @children); }
        else {
          $self->addNodes($node, @children); } }
      else {
        my ($prefix, $localname) = $tag =~ /^(.*):(.*)$/;
        my $nsuri = $prefix && $$self{namespaces}{$prefix};
        LaTeXML::Post::Warn('expected', 'namespace', undef, "No namespace on '$tag'") unless $nsuri;
        my $new = $node->addNewChild($nsuri, $localname);
        if ($attributes) {
          foreach my $key (sort keys %$attributes) {
            next unless defined $$attributes{$key};
            my ($attrprefix, $attrname) = $key =~ /^(.*):(.*)$/;
            my $value = $$attributes{$key};
            if ($key eq 'xml:id') {
              if (defined $$self{idcache}{$value}) {    # Duplicated ID ?!?!
                my $newid = LaTeXML::Post::uniquifyID($value, ++$$self{idcache_clashes}{$value});
                print STDERR "Duplicated id=$value using $newid " . ($$self{destination} || '') . "\n";
                $value = $newid; }
              $$self{idcache}{$value} = $new;
              $new->setAttribute($key, $value); }
            elsif ($attrprefix && ($attrprefix ne 'xml')) {
              my $attrnsuri = $attrprefix && $$self{namespaces}{$attrprefix};
              $new->setAttributeNS($attrnsuri, $key, $$attributes{$key}); }
            else {
              $new->setAttribute($key, $$attributes{$key}); } } }
        $self->addNodes($new, @children); } }
    elsif ((ref $child) =~ /^XML::LibXML::/) {
      my $type = $child->nodeType;
      if ($type == XML_ELEMENT_NODE) {
        my $new = $node->addNewChild($child->namespaceURI, $child->localname);
        foreach my $attr ($child->attributes) {
          my $atype = $attr->nodeType;
          if ($atype == XML_ATTRIBUTE_NODE) {
            my $key = $attr->nodeName;
            if ($key eq 'xml:id') {
              my $value = $attr->getValue;
              my $old;
              if ((defined($old = $$self{idcache}{$value}))    # if xml:id was already used
                && !$old->isSameNode($child)) {                # and the node was a different one
                my $newid = LaTeXML::Post::uniquifyID($value, ++$$self{idcache_clashes}{$value});
                print STDERR "Duplicated id=$value using $newid " . ($$self{destination} || '') . "\n";
                $value = $newid; }
              $$self{idcache}{$value} = $new;
              $new->setAttribute($key, $value); }
            elsif (my $ns = $attr->namespaceURI) {
              $new->setAttributeNS($ns, $attr->name, $attr->getValue); }
            else {
              $new->setAttribute($attr->localname, $attr->getValue); } }
        }
        $self->addNodes($new, $child->childNodes); }
      elsif ($type == XML_DOCUMENT_FRAG_NODE) {
        $self->addNodes($node, $child->childNodes); }
      elsif ($type == XML_TEXT_NODE) {
        $node->appendTextNode($child->textContent); }
    }
    elsif (ref $child) {
      LaTeXML::Post::Warn('misdefined', $child, undef, "Dont know how to add $child to $node; ignoring"); }
    elsif (defined $child) {
      $node->appendTextNode($child); } }
  return; }

# Remove @nodes from the document
# Allow the nodes to be array form with possibly nested XML that needs to be removed.
sub removeNodes {
  my ($self, @nodes) = @_;
  foreach my $node (@nodes) {
    my $ref = ref $node;
    if (!$ref) { }
    elsif ($ref eq 'ARRAY') {
      my ($t, $a, @n) = @$node;
      if (my $id = $$a{'xml:id'}) {
        if ($$self{idcache}{$id}) {
          delete $$self{idcache}{$id}; } }
      $self->removeNodes(@n); }
    elsif (($ref =~ /^XML::LibXML::/) && ($node->nodeType == XML_ELEMENT_NODE)) {
      foreach my $idd ($self->findnodes("descendant-or-self::*[\@xml:id]", $node)) {
        my $id = $idd->getAttribute('xml:id');
        if ($$self{idcache}{$id}) {
          delete $$self{idcache}{$id}; } }
      $node->unlinkNode; } }
  return; }

sub removeBlankNodes {
  my ($self, $node) = @_;
  my $n = 0;
  foreach my $child ($node->childNodes) {
    if (($child->nodeType == XML_TEXT_NODE) && ($child->textContent =~ /^\s*$/)) {
      $node->removeChild($child); $n++; } }
  return $n; }

# Replace $node by @replacements in the document
sub replaceNode {
  my ($self, $node, @replacements) = @_;
  my ($parent, $following) = ($node->parentNode, undef);
  # Note that since we can only append new stuff, we've got to remove the following first.
  my @save = ();
  while (($following = $parent->lastChild) && ($$following != $$node)) { # Remove & Save following siblings.
    unshift(@save, $parent->removeChild($following)); }
  $self->removeNodes($node);
  $self->addNodes($parent, @replacements);
  map { $parent->appendChild($_) } @save;                                # Put these back.
  return; }

# Put @nodes at the beginning of $node.
sub prependNodes {
  my ($self, $node, @nodes) = @_;
  my @save = ();
  # Note that since we can only append new stuff, we've got to remove the following first.
  while (my $last = $node->lastChild) {    # Remove, but save, all children
    unshift(@save, $node->removeChild($last)); }
  $self->addNodes($node, @nodes);          # Now, add the new nodes.
  map { $node->appendChild($_) } @save;    # Put these back.
  return; }

# Clone a node, but adjusting it so that it has unique id's.
# $document->cloneNode($node) or ->cloneNode($node,$idsuffix)
# This clones the node and adjusts any xml:id's within it to be unique.
# Any idref's to those ids will be changed to the new id values.
# If $idsuffix is supplied, the ids will have that suffix appended to the ids.
# Then each $id is checked to see whether it is unique; If needed,
# one or more letters are appended, until a new id is found.
sub cloneNode {
  my ($self, $node, $idsuffix) = @_;
  return $node unless ref $node;
  my $copy = $node->cloneNode(1);
  $idsuffix = '' unless defined $idsuffix;
  # Find all id's defined in the copy and change the id.
  my %idmap = ();
  foreach my $n ($self->findnodes('descendant-or-self::*[@xml:id]', $copy)) {
    my $id    = $n->getAttribute('xml:id');
    my $newid = $id . $idsuffix;
    if (defined $$self{idcache}{$newid}) {    # Duplicated ID ?!?!
      $newid = LaTeXML::Post::uniquifyID($id, ++$$self{idcache_clashes}{$id}, $idsuffix); }
    $idmap{$id} = $newid;
    $$self{idcache}{$newid} = $n;
    $n->setAttribute('xml:id' => $newid);
    if (my $fragid = $n->getAttribute('fragid')) {    # GACK!!
      $n->setAttribute(fragid => substr($newid, length($id) - length($fragid))); } }

  # Now, replace all REFERENCES to those modified ids.
  foreach my $n ($self->findnodes('descendant-or-self::*[@idref]', $copy)) {
    if (my $id = $idmap{ $n->getAttribute('idref') }) {
      $n->setAttribute(idref => $id); } }             # use id or fragid?
  return $copy; }

sub cloneNodes {
  my ($self, @nodes) = @_;
  return map { $self->cloneNode($_) } @nodes; }

#======================================================================
# DUPLICATED from Core::Document...(see discussion there)
# Decorations on one side of an XMDual should be attributed to the
# parent node on the other side (see ->associateIDs)

sub markXMNodeVisibility {
  my ($self) = @_;
  foreach my $math ($self->findnodes('//ltx:XMath/*')) {
    $self->markXMNodeVisibility_aux($math, 1, 1); }
  return; }

sub markXMNodeVisibility_aux {
  my ($self, $node, $cvis, $pvis) = @_;
  my $qname = $self->getQName($node);
  return if (!$cvis || $node->getAttribute('_cvis')) && (!$pvis || $node->getAttribute('_pvis'));
  $node->setAttribute('_cvis' => 1) if $cvis;
  $node->setAttribute('_pvis' => 1) if $pvis;
  if ($qname eq 'ltx:XMDual') {
    my ($c, $p) = element_nodes($node);
    $self->markXMNodeVisibility_aux($c, 1, 0) if $cvis;
    $self->markXMNodeVisibility_aux($p, 0, 1) if $pvis; }
  elsif ($qname eq 'ltx:XMRef') {
    #    $self->markXMNodeVisibility_aux($self->realizeXMNode($node),$cvis,$pvis); }
    my $id = $node->getAttribute('idref');
    $self->markXMNodeVisibility_aux($self->findNodeByID($id), $cvis, $pvis); }
  else {
    foreach my $child (element_nodes($node)) {
      $self->markXMNodeVisibility_aux($child, $cvis, $pvis); } }
  return; }

sub unmarkXMNodeVisibility {
  my ($self) = @_;
  foreach my $math ($self->findnodes('//ltx:XMath')) {
    foreach my $node ($self->findnodes('descendant-or-self::*[@_pvis or //@_cvis]', $math)) {
      $node->removeAttribute('_pvis');
      $node->removeAttribute('_cvis'); } }
  return; }

#======================================================================

sub newDocument {
  my ($self, $root, %options) = @_;
  my $xmldoc = XML::LibXML::Document->new("1.0", "UTF-8");
  my ($public_id, $system_id);
  if (my $dtd = $$self{document}->internalSubset) {
    if ($dtd->toString
      =~ /^<!DOCTYPE\s+(\w+)\s+PUBLIC\s+(\"|\')([^\2]*)\2\s+(\"|\')([^\4]*)\4>$/) {
      ($public_id, $system_id) = ($3, $5); } }
  my $parent_id;
  # Build the document's XML
  if (ref $root eq 'ARRAY') {
    my ($tag, $attributes, @children) = @$root;
    my ($prefix, $localname) = $tag =~ /^(.*):(.*)$/;
    $xmldoc->createInternalSubset($localname, $public_id, $system_id) if $public_id;

    my $nsuri = $$self{namespaces}{$prefix};
    my $node = $xmldoc->createElementNS($nsuri, $localname);
    $xmldoc->setDocumentElement($node);
    map { $$attributes{$_} && $node->setAttribute($_ => $$attributes{$_}) } keys %$attributes
      if $attributes;
    # Note that $self is the "parent" document, not the document that we're about to make!
    # We don't yet want to deal with ID caches (it will be built later with ->new)
    my $savecache = $$self{idcache};
    $$self{idcache} = {};
    $self->addNodes($node, @children);
    $$self{idcache} = $savecache; }    # Restore the cache;
  elsif (ref $root eq 'XML::LibXML::Element') {
    $parent_id = $self->findnode('ancestor::*[@id]', $root);
    $parent_id = $parent_id->getAttribute('id') if $parent_id;
    my $localname = $root->localname;
    $xmldoc->createInternalSubset($localname, $public_id, $system_id) if $public_id;
    # Make a copy of $root be the new element node, carefully w.r.t. namespaces.
    # Seems that only importNode (not adopt) works correctly,
    # PROVIDED we also set the namespace.
    my $node = $xmldoc->importNode($root);
    $xmldoc->setDocumentElement($node);
    $xmldoc->documentElement->setNamespace($root->namespaceURI, $root->prefix, 1); }
  else {
    Fatal('unexpected', $root, undef, "Dont know how to use '$root' as document element"); }

  my $root_id = $self->getDocumentElement->getAttribute('xml:id');
  my $doc     = $self->new($xmldoc,
    ($parent_id ? (parent_id     => $parent_id) : ()),
    ($root_id   ? (split_from_id => $root_id)   : ()),
    %options);

  # Copy any processing instructions.
  foreach my $pi ($self->findnodes(".//processing-instruction('latexml')")) {
    $doc->getDocument->appendChild($pi->cloneNode); }

  # And any resource elements
  if (my @resources = $self->findnodes("descendant::ltx:resource")) {
    $doc->addNodes($doc->getDocumentElement, @resources); }    # cloning, as needed...

  # If new document has no date, try to add one
  $doc->addDate($self);

  # And copy class from the top-level document; This is risky...
  # We want to preserve global document style information
  # But some may refer specifically to the document, and NOT to the parts?
  if (my $class = $self->getDocumentElement->getAttribute('class')) {
    my $root   = $doc->getDocumentElement;
    my $oclass = $root->getAttribute('class');
    $root->setAttribute(class => ($oclass ? $oclass . ' ' . $class : $class)); }

  # Finally, return the new document.
  return $doc; }

our @MonthNames = (qw( January February March April May June
    July August September October November December));

sub addDate {
  my ($self, $fromdoc) = @_;
  if (!$self->findnodes('ltx:date', $self->getDocumentElement)) {
    my @dates;
    #  $fromdoc's document has some, so copy them.
    if ($fromdoc && (@dates = $fromdoc->findnodes('ltx:date', $fromdoc->getDocumentElement))) {
      $self->addNodes($self->getDocumentElement, @dates); }
    else {
      my ($sec, $min, $hour, $mday, $mon, $year) = localtime(time());
      $self->addNodes($self->getDocumentElement,
        ['ltx:date', { role => 'creation' },
          $MonthNames[$mon] . " " . $mday . ", " . (1900 + $year)]); } }
  return; }

#======================================================================
# Given a list of nodes (or node constructors [tag,attr,content...])
# conjoin given a conjunction like ',' or a pair like [',', ' and ']
sub conjoin {
  my ($self, $conjunction, @nodes) = @_;
  my ($comma, $and) = ($conjunction, $conjunction);
  ($comma, $and) = @$conjunction if ref $conjunction;
  my $n = scalar(@nodes);
  if ($n < 2) {
    return @nodes; }
  else {
    my @foo = ();
    push(@foo, shift(@nodes));
    while ($nodes[1]) {
      push(@foo, $comma, shift(@nodes)); }
    push(@foo, $and, shift(@nodes));
    return @foo; } }

# Find the initial letter in a string, or *.
# Uses unicode decomposition to reduce accented characters to A-Z
# If $force is true, skips any non-letter initials
sub initial {
  my ($self, $string, $force) = @_;
  $string = NFD($string);    # Decompose accents, etc.
  $string =~ s/^[^a-zA-Z]*// if $force;
  return ($string =~ /^([a-zA-Z])/ ? uc($1) : '*'); }

sub trimChildNodes {
  my ($self, $node) = @_;
  if (!$node) {
    return (); }
  elsif (!ref $node) {
    return ($node); }
  elsif (my @children = $node->childNodes) {
    if ($children[0]->nodeType == XML_TEXT_NODE) {
      my $s = $children[0]->data;
      $s =~ s/^\s+//;
      $children[0]->setData($s); }
    if ($children[-1]->nodeType == XML_TEXT_NODE) {
      my $s = $children[-1]->data;
      $s =~ s/\s+$//;
      $children[-1]->setData($s); }
    return @children; }
  else {
    return (); } }

#======================================================================

sub addNavigation {
  my ($self, $relation, $id) = @_;
  return if $self->findnode('//ltx:navigation/ltx:ref[@rel="' . $relation . '"][@idref="' . $id . '"]');
  my $ref = ['ltx:ref', { idref => $id, rel => $relation, show => 'fulltitle' }];
  if (my $nav = $self->findnode('//ltx:navigation')) {
    $self->addNodes($nav, $ref); }
  else {
    $self->addNodes($self->getDocumentElement, ['ltx:navigation', {}, $ref]); }
  return; }

#======================================================================
# Support for ID's

sub recordID {
  my ($self, $id, $node) = @_;
  # make an issue if already there?
###print STDERR "REGISTER $$self{destination} ID=".$id."\n";
  $$self{idcache}{$id} = $node;
  return; }

sub findNodeByID {
  my ($self, $id) = @_;
  return $$self{idcache}{$id}; }

sub realizeXMNode {
  my ($self, $node) = @_;
  if ($self->getQName($node) eq 'ltx:XMRef') {
    my $id = $node->getAttribute('idref');
    if (my $realnode = $self->findNodeByID($id)) {
      return $realnode; }
    else {
      Fatal("expected", $id, undef, "Cannot find a node with xml:id='$id'");
      return; } }
  else {
    return $node; } }

# Generate, add and register an xml:id for $node.
# Unless it already has an id, the created id will
# be "structured" relative to it's parent using $prefix
sub generateNodeID {
  my ($self, $node, $prefix) = @_;
  my $id = $node->getAttribute('xml:id');
  return $id if $id;
  # Find the closest parent with an ID
  my ($parent, $pid, $n) = ($node->parentNode, undef, undef);
  while ($parent && !($pid = $parent->getAttribute('xml:id'))) {
    $parent = $parent->parentNode; }
  # Now find the next unused id relative to the parent id, as "prefix<number>"
  $pid .= '.' if $pid;
  for ($n = 1 ; $$self{idcache}{ $id = $pid . $prefix . $n } ; $n++) { }
  $node->setAttribute('xml:id' => $id);
  $$self{idcache}{$id} = $node;
  # If we've already been scanned, and have fragid's, create one here, too.
  if (my $fragid = $parent && $parent->getAttribute('fragid')) {
    $node->setAttribute(fragid => $fragid . '.' . $prefix . $n); }
  return $id; }

#======================================================================
# adjust_latexml_doctype($doc,"Foo","Bar") =>
# <!DOCTYPE document PUBLIC "-//NIST LaTeXML//LaTeXML article + Foo + Bar"
#                 "http://dlmf.nist.gov/LaTeXML/LaTeXML-Foo-Bar.dtd">
sub adjust_latexml_doctype {
  my ($self, @additions) = @_;
  my $doc = $$self{document};
  if (my $dtd = $doc->internalSubset) {
    if ($dtd->toString
      =~ /^<!DOCTYPE\s+(\w+)\s+PUBLIC\s+(\"|\')-\/\/NIST LaTeXML\/\/LaTeXML\s+([^\"]*)\2\s+(\"|\')([^\"]*)\4>$/) {
      my ($root, $parts, $system) = ($1, $3, $5);
      my ($type, @addns) = split(/ \+ /, $parts);
      my %addns = ();
      map { $addns{$_} = 1 } @addns, @additions;
      @addns = sort keys %addns;
      my $publicid = join(' + ', "-//NIST LaTeXML//LaTeXML $type",       @addns);
      my $systemid = join('-',   "http://dlmf.nist.gov/LaTeXML/LaTeXML", @addns) . ".dtd";
      $doc->removeInternalSubset;    # Apparently we've got to remove it first.
      $doc->createInternalSubset($root, $publicid, $systemid); } }
  return; }

#======================================================================
# Cache support: storage of data from previous run.
# ?

# cacheFile as parameter ????

sub cacheLookup {
  my ($self, $key) = @_;
  $self->openCache;
  return $$self{cache}{$key}; }

sub cacheStore {
  my ($self, $key, $value) = @_;
  $self->openCache;
  if (defined $value) {
    $$self{cache}{$key} = $value; }
  else {
    delete $$self{cache}{$key}; }
  return; }

sub openCache {
  my ($self) = @_;
  if (!$$self{cache}) {
    $$self{cache} = {};
    my $dbfile = $self->checkDestination("LaTeXML.cache");
    tie %{ $$self{cache} }, 'DB_File', $dbfile, O_RDWR | O_CREAT
      or return Fatal('internal', 'db', undef,
      "Couldn't create DB cache for " . $self->getDestination,
      "Message was: " . $!,
      (-f $dbfile ? "\n(possibly incompatible db format?)" : ''));
  }
  return; }

sub closeCache {
  my ($self) = @_;
  if ($$self{cache}) {
    untie %{ $$self{cache} };
    $$self{cache} = undef; }
  return; }

1;
#======================================================================

__END__

=head1 NAME

C<LaTeXML::Post> - Postprocessing driver.

=head1 DESCRIPTION

C<LaTeXML::Post> is the driver for various postprocessing operations.
It has a complicated set of options that I'll document shortly.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
