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
use base qw(LaTeXML::Common::Object);
use LaTeXML::Global;
use LaTeXML::Common::Error;
use LaTeXML::Core::State;
our @EXPORT = (@LaTeXML::Common::Error::EXPORT);

sub new {
  my ($class, %options) = @_;
  my $self = bless { status => {}, %options }, $class;
  $$self{verbosity} = 0 unless defined $$self{verbosity};
  # TEMPORARY HACK!!!!
  # Create a State object, essentially only to hold verbosity (for now)
  # so that Errors can be reported, managed and recorded
  # Eventually will be a "real" State (or other configuration object)
  $$self{state} = LaTeXML::Core::State->new();
  $$self{state}->assignValue(VERBOSITY => $$self{verbosity});
  return $self; }

#======================================================================
sub ProcessChain {
  my ($self, $doc, @postprocessors) = @_;
  return $self->withState(sub {
      return $self->ProcessChain_internal($doc, @postprocessors); }); }

sub ProcessChain_internal {
  my ($self, $doc, @postprocessors) = @_;
  local $LaTeXML::POST           = $self;
  local $LaTeXML::Post::NOTEINFO = undef;
  local $LaTeXML::Post::DOCUMENT = $doc;

  my @docs = ($doc);
  ProgressSpinup("post-processing");

  foreach my $processor (@postprocessors) {
    local $LaTeXML::Post::PROCESSOR = $processor;
    my @newdocs = ();
    foreach my $doc (@docs) {
      local $LaTeXML::Post::DOCUMENT = $doc;
      if (my @nodes = grep { $_ } $processor->toProcess($doc)) {    # If there are nodes to process
        my $n   = scalar(@nodes);
        my $msg = join(' ', $processor->getName || '',
          $doc->siteRelativeDestination || '',
          ($n > 1 ? "$n to process" : 'processing'));
        ProgressSpinup($msg);
        push(@newdocs, $processor->process($doc, @nodes));
        ProgressSpindown($msg); }
      else {
        push(@newdocs, $doc); } }
    @docs = @newdocs; }
  ProgressSpindown("post-processing");
  return @docs; }

## HACK!!!
## This is a copy of withState from LaTeXML::Core.pm
## This should eventually be in a higher level, common class
## using a common State or configuration object
## in order to wrap ALL processing.
sub withState {
  my ($self, $closure) = @_;
  local $STATE = $$self{state};
  # And, set fancy error handler for ANY die!
  local $SIG{__DIE__}  = \&LaTeXML::Common::Error::perl_die_handler;
  local $SIG{INT}      = \&LaTeXML::Common::Error::perl_interrupt_handler;
  local $SIG{__WARN__} = \&LaTeXML::Common::Error::perl_warn_handler;
  local $SIG{'ALRM'}   = \&LaTeXML::Common::Error::perl_timeout_handler;
  local $SIG{'TERM'}   = \&LaTeXML::Common::Error::perl_terminate_handler;

  local $LaTeXML::DUAL_BRANCH = '';

  return &$closure($STATE); }

sub getStatusCode {
  my ($self) = @_;
  return $$self{state}->getStatusCode; }

sub getStatusMessage {
  my ($self) = @_;
  return $$self{state}->getStatusMessage; }

#======================================================================
# "Global" Post processing services
#======================================================================

# Return a sorter appropriate for lang (if Unicode::Collate::Locale available),
# or an undifferentiated Unicode sorter (if only Unicode::Collate is available),
# or just a dumb stand-in for perl's sort
sub getsorter {
  my ($self, $lang) = @_;
  my $collator;
  if    ($collator = $$self{collatorcache}{$lang}) { }
  elsif ($collator = eval {
      local $LaTeXML::IGNORE_ERRORS = 1;
      require 'Unicode/Collate/Locale.pm';
      Unicode::Collate::Locale->new(
        locale             => $lang,
        variable           => 'non-ignorable',    # I think; at least space shouldn't be ignored
        upper_before_lower => 1); }) { }
  elsif ($collator = eval {
      local $LaTeXML::IGNORE_ERRORS = 1;
      require 'Unicode/Collate.pm';
      Unicode::Collate->new(
        variable           => 'non-ignorable',    # I think; at least space shouldn't be ignored
        upper_before_lower => 1); }) {
    Info('expected', 'Unicode::Collate::Locale', undef,
      "No Unicode::Collate::Locale found;",
      "using Unicode::Collate; ignoring language='$lang'"); }
  else {
    # Otherwise, just use primitive codepoint ordering.
    $collator = LaTeXML::Post::DumbCollator->new();
    Info('expected', 'Unicode::Collate::Locale', undef,
      "No Unicode::Collate::Locale or Unicode::Collate",
      "using perl's sort; ignoring language='$lang'"); }
  $$self{collatorcache}{$lang} = $collator;
  return $collator; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
package LaTeXML::Post::DumbCollator;
use strict;

sub new {
  my ($class) = @_;
  return bless {}, $class; }

sub sort {
  my ($self, @things) = @_;
  return (sort @things); }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
package LaTeXML::Post::Processor;
use strict;
use LaTeXML::Post;
use LaTeXML::Common::Error;
use LaTeXML::Common::XML;
use LaTeXML::Util::Pathname;
use base qw(LaTeXML::Common::Object);

# An Abstract Post Processor
sub new {
  my ($class, %options) = @_;
  my $self = bless {%options}, $class;
  $$self{verbosity}          = 0 unless defined $$self{verbosity};
  $$self{resource_directory} = $options{resource_directory};
  $$self{resource_prefix}    = $options{resource_prefix};
  my $name = $class; $name =~ s/^LaTeXML::Post:://;
  $$self{name} = $name;
  return $self; }

sub getName {
  my ($self) = @_;
  return $$self{name}; }

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
  my $subdir  = $$self{resource_directory} || '';
  my $prefix  = $$self{resource_prefix}    || "x";
  my $counter = join('_', "_max", $subdir, $prefix, "counter_");
  my $n       = $doc->cacheLookup($counter) || 0;
  my $name    = $prefix . ++$n;
  $doc->cacheStore($counter, $n);
  return pathname_make(dir => $subdir, name => $name, type => $type); }

# Returns a two-part list of the form:
#
# [class, classoptions, oldstyle], [package1,package1options], [package2,package2options], ...
#
# Where there first element is always the *class* (if none, "article" returned as a default)
# And all following elements are *packages*
#
sub find_documentclass_and_packages {
  my ($self, $doc) = @_;
  my ($class, $classoptions, $oldstyle, @packages);
  foreach my $pi ($doc->findnodes(".//processing-instruction('latexml')")) {
    my $data  = $pi->textContent;
    my $entry = {};
    while ($data =~ s/\s*([\w\-\_]*)=([\"\'])(.*?)\2//) {
      $$entry{$1} = $3; }
    if ($$entry{class}) {
      $class        = $$entry{class};
      $classoptions = $$entry{options} || 'onecolumn';
      $oldstyle     = $$entry{oldstyle}; }
    elsif ($$entry{package}) {
      my @p = grep { $_; } split(/\s*,\s*/, $$entry{package});
      foreach my $package (@p) {
        push(@packages, [$package, $$entry{options} || '']); } } }
  if (!$class) {
    Warn('expected', 'class', undef, "No document class found; using article");
    $class = 'article'; }
  return ([$class, $classoptions, $oldstyle], @packages); }

sub find_preambles {
  my ($self, $doc) = @_;
  my @preambles = ();
  foreach my $pi ($doc->findnodes(".//processing-instruction('latexml')")) {
    my $data = $pi->textContent;
    while ($data =~ s/\s*([\w\-\_]*)=([\"\'])(.*?)\2//) {
      if ($1 eq 'preamble') {
        push(@preambles, $3); } } }
  return join("\n", @preambles); }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
package LaTeXML::Post::MathProcessor;
use strict;
use LaTeXML::Post;
use LaTeXML::Common::Error;
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

# Top level processing finds and converts all top-level math nodes.
# Any nested mathnodes would only appear within ltx:XMText;
# postprocessors must handle nested math as appropriate (but see convertXMTextContent)
# Invokes preprocess on each before doing the conversion in case
# analysis is needed.
sub toProcess {
  my ($self, $doc) = @_;
  return $doc->findnodes('//ltx:Math[not(ancestor::ltx:Math)]'); }

sub process {
  my ($self, $doc, @maths) = @_;
  local $LaTeXML::Post::MATHPROCESSOR = $self;
  $doc->markXMNodeVisibility;
  $self->preprocess($doc, @maths);
  if ($$self{parallel}) {
    my @secondaries = @{ $$self{secondary_processors} };
    # What's the right test for when cross-referencing should be done?
    # For now: only when the primary and some secondary can cross-ref
    # (otherwise, end up with peculiar structures?)
    my ($proc1, @ignore) = grep { $_->can('addCrossref') } @secondaries;
    if ($self->can('addCrossref') && $proc1) {
      $$self{crossreferencing}  = 1;     # We'll need ID's!
      $$proc1{crossreferencing} = 1; }
    foreach my $proc (@secondaries) {
      local $LaTeXML::Post::MATHPROCESSOR = $proc;
      $proc->preprocess($doc, @maths); } }
  # Re-Fetch the math nodes, in case preprocessing has messed them up!!!
  @maths = $self->toProcess($doc);

  ## Do in reverse, since (in LaTeXML) we allow math nested within text within math.
  ## So, we want to converted any nested expressions first, so they get carried along
  ## with the outer ones.
  my $n = 0;
  foreach my $math (reverse(@maths)) {
    # If parent is MathBranch, which branch number is it?
    # (note: the MathBranch will be in a ltx:MathFork, with a ltx:Math being 1st child)
    my @preceding = $doc->findnodes("parent::ltx:MathBranch/preceding-sibling::*", $math);
    local $LaTeXML::Post::MathProcessor::FORK = scalar(@preceding);
    $self->processNode($doc, $math);
    $n++; }

  # Experimentally, cross reference ??? (or clearer name?)
  if ($$self{parallel}) {
    # There could be various strategies when there are more than 2 parallel conversions,
    # eg a cycle or something....
    # Here, we simply take the first two processors that know how to addCrossref
    # and connect their nodes to each other.
    my ($proc1, $proc2, @ignore)
      = grep { $_->can('addCrossref') } $self, @{ $$self{secondary_processors} };
    if ($proc1 && $proc2) {
      # First, prepare a list of all Math id's, in document order, to simplify crossreferencing
      my $ids = {};
      my $pos = 0;
      foreach my $n ($doc->findnodes('descendant-or-self::ltx:Math/descendant::*[@xml:id]')) {
        $$ids{ $n->getAttribute('xml:id') } = $pos++; }
      $$proc1{crossreferencing_ids} = $ids;
      $$proc2{crossreferencing_ids} = $ids;
      # Now do cross referencing
      $proc1->addCrossrefs($doc, $proc2);
      $proc2->addCrossrefs($doc, $proc1); } }
  ProgressDetailed("converted $n Maths");
  return $doc; }

# Make THIS MathProcessor the primary branch (of whatever parallel markup it supports),
# and make all of the @moreprocessors be secondary ones.
sub setParallel {
  my ($self, @moreprocessors) = @_;
  if (@moreprocessors) {
    $$self{parallel} = 1;
    map { $$_{is_secondary} = 1 } @moreprocessors;    # Mark the others as secondary
    $$self{secondary_processors} = [@moreprocessors];
    $$self{name} .= '[w/' . join('+', map { $_->getName } @moreprocessors) . ']'; }
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
  # XMath will be removed (LATER!), but mark its ids as reusable.
  $doc->preremoveNodes($xmath);
  if ($$self{parallel}) {
    my $primary     = $self->convertNode($doc, $xmath);
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
  # NOTE: Unless XMath is the primary, (preserving the XMath, w/no IDSuffix)
  # we've got to remove the id's from the XMath, since the primary will get same id's
  # and (some versions) of libxml2 complain!
  if ($$conversion{mimetype} && ($$conversion{mimetype} ne 'application/x-latexml')) {
    map { $_->removeAttribute('xml:id') }
      $doc->findnodes('descendant-or-self::*[@xml:id]', $xmath); }
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

# A helper for converting XMText
# ltx:XMText escapes back to general ltx markup; the only element within XMath that does.
# BUT it can contain nested ltx:Math!
# When converting to (potentially parallel markup, coarse-grained),
# the non-math needs to be duplicated, but with the ID's modified,
# AND the nested math needs to be converted to ONLY the current target's markup
# NOT parallel within each nested math, although it should still be cross-referencable to others!
# moreover, the math will need the outerWrapper.
my $NBSP = pack('U', 0xA0);    # CONSTANT

sub convertXMTextContent {
  my ($self, $doc, $convertspaces, @nodes) = @_;
  my @result = ();
  foreach my $node (@nodes) {
    if ($node->nodeType == XML_TEXT_NODE) {
      my $string = $node->textContent;
      if ($convertspaces) {
        $string =~ s/^\s+/$NBSP/; $string =~ s/\s+$/$NBSP/; }
      push(@result, $string); }
    else {
      my $tag = $doc->getQName($node);
      if ($tag eq 'ltx:XMath') {
        my $conversion = $self->convertNode($doc, $node);
        my $xml        = $$conversion{xml};
        # And if no xml ????
        push(@result, $self->outerWrapper($doc, $node, $xml)); }
      else {
        my %attr = ();
        foreach my $attr ($node->attributes) {
          my $atype = $attr->nodeType;
          if ($atype == XML_ATTRIBUTE_NODE) {
            my $key   = $attr->nodeName;
            my $value = $attr->getValue;
            if    ($key =~ /^_/)     { }    # don't copy internal attributes ???
            elsif ($key eq 'xml:id') { }    # ignore; we'll handle fragid???
            elsif ($key eq 'fragid') {
              my $id = $doc->uniquifyID($value, $self->IDSuffix);
              $attr{'xml:id'} = $id; }
            else {
              $attr{$key} = $attr->value; } } }
        # Probably should invoke associateNode ???
        push(@result,
          [$tag, {%attr}, $self->convertXMTextContent($doc, $convertspaces, $node->childNodes)]); } } }
  return @result; }

# When converting an XMath node (with an id) to some other format,
# we will generate an id for the new node.
# This method returns a suffix to be added to the XMath id.
# The primary format gets the id's unchanged, but secondary ones get a suffix (eg. ".pmml")
sub IDSuffix {
  my ($self) = @_;
  return ($$self{is_secondary} ? $self->rawIDSuffix : ''); }

sub rawIDSuffix {
  return ''; }

# In order to do cross-referencing betweeen formats, and to relate semantic/presentation
# information to content/presentation nodes (resp), we want to associate each
# generated node (MathML, OpenMath,...) with a "source" XMath node "responsible" for it's generation.
# This is often the "current" XMath node that was being converted, but sometimes
# * the containing XMDual (which makes more sense when we've generated a "container")
# * the containing XMDual's semantic operator (makes more sense when we're generating
#   tokens that are only visible from the presentation branch)
sub associateNode {
  my ($self, $node, $currentnode, $noxref) = @_;
  my $r = ref $node;
  return unless $currentnode && $r && ($r eq 'ARRAY' || $r eq 'XML::LibXML::Element');
  my $document = $LaTeXML::Post::DOCUMENT;
  # Check if already associated with a source node
  my $isarray = ref $node eq 'ARRAY';
  # What kind of branch are we generating?
  my $ispresentation = $self->rawIDSuffix eq '.pmml';    # TEMPORARY HACK: BAAAAD method!
  my $iscontainer    = 0;
  my $container;
  if ($isarray) {
    return if $$node[1]{'_sourced'};
    $$node[1]{'_sourced'} = 1;
    my ($tag, $attr, @children) = @$node;
    $iscontainer = grep { ref $_ } @children; }
  else {
    return if $node->getAttribute('_sourced');
    $node->setAttribute('_sourced' => 1);
    $iscontainer = scalar(element_nodes($node)); }
  my $sourcenode = $currentnode;
  # If the current node is declared, use it (but meaning is overridden)
  if ($currentnode->getAttribute('decl_id')) { }
  # If the generated node is a "container" (non-token!), use the containing XMDual as source
  elsif ($iscontainer) {
    my $sid = $sourcenode->getAttribute('xml:id');
    # But ONLY if that XMDual is the "direct" parent, or is parent of XRef that points to $current
    if ($container = $document->findnode('parent::ltx:XMDual[1]', $sourcenode)
      || ($sid &&
        $document->findnode("ancestor-or-self::ltx:XMDual[ltx:XMRef[\@idref='$sid']][1]",
          $sourcenode))) {
      $sourcenode = $container; } }
  # Parent App w/decl_id or meaning is source, unless current node has decl_id (but ignore meaning)
  elsif ($container = $document->findnode('ancestor::ltx:XMApp[@decl_id or @meaning][1]', $sourcenode)) {
    $sourcenode = $container; }
  # If the current node is appropriately visible, use it.
  elsif ($currentnode->getAttribute(($ispresentation ? '_cvis' : '_pvis'))) { }
  # Else (current node isn't visible); try to find content OPERATOR
  elsif ($container = $document->findnode('ancestor-or-self::ltx:XMDual[1]', $sourcenode)) {
    my ($op) = element_nodes($container);
    my $q = $document->getQName($op) || 'unknown';
    if ($container->hasAttribute('decl_id')) {
      $op = undef; }
    elsif ($q eq 'ltx:XMTok') { }
    elsif ($q eq 'ltx:XMApp') {
      while (($q eq 'ltx:XMApp') && !$op->hasAttribute('meaning')) {
        ($op) = element_nodes($op);
        $q = $document->getQName($op) || 'unknown'; } }    # get "real" operator
    if ($q eq 'ltx:XMRef') {
      $op = $document->realizeXMNode($op); }
    # Be a bit fuzzy about whether something is "visible"
    if ($op && !($op->getAttribute('_pvis')
        && (($op->getAttribute('thickness') || '<anything>') ne '0pt'))) {
      $sourcenode = $op; }
    else {
      $sourcenode = $container; } }
  # If we're intending to cross-reference, then source & generated nodes will need ID's
  if ($$self{crossreferencing}) {
    if (!$noxref && !$sourcenode->getAttribute('fragid')) {    # If no ID, but need one
      $document->generateNodeID($sourcenode, '', 1); }         # but the ID is reusable
    if (my $sourceid = $sourcenode->getAttribute('fragid')) {    # If source has ID
      my $nodeid = $currentnode->getAttribute('fragid') || $sourceid;
      my $id     = $document->uniquifyID($nodeid, $self->IDSuffix);
      if ($isarray) {
        $$node[1]{'xml:id'} = $id; }
      else {
        $node->setAttribute('xml:id' => $id); }
      push(@{ $$self{convertedIDs}{$sourceid} }, $id) unless $noxref; } }
  $self->associateNodeHook($node, $sourcenode, $noxref);
  if ($isarray) {                                                # Array represented
    map { $self->associateNode($_, $currentnode, $noxref) } @$node[2 .. $#$node]; }
  else {                                                         # LibXML node
    map { $self->associateNode($_, $currentnode, $noxref) } element_nodes($node); }
  return; }

# Customization hook for adding other attributes to the generated math nodes.
sub associateNodeHook {
  my ($self, $node, $sourcenode, $noxref) = @_;
  return; }

sub shownode {
  my ($node, $level) = @_;
  $level = 0 unless defined $level;
  my $ref = ref $node;
  if ($ref eq 'ARRAY') {
    my ($tag, $attr, @children) = @$node;
    return "\n" . ('  ' x $level)
      . '[' . $tag . ',{' . join(',', map { $_ . '=>' . ($$attr{$_} || '') } sort keys %$attr) . '},'
      . join(',', map { shownode($_, $level + 1) } @children) . ']'; }
  elsif ($ref =~ /^XML/) {
    return $node->toString; }
  else {
    return "$node"; } }

# Add backref linkages (eg. xref) onto the nodes that $self created (converted from XMath)
# to reference those that $otherprocessor created.
# NOTE: Subclass MUST define addCrossref($node,$xref_id) to add the
# id of the "Other Interesting Node" to the (array represented) xml $node
# in whatever fashion the markup for that processor uses.
#
# This may be another useful place to add a hook?
# It would provide the list of cross-refenced nodes in document order
# This would allow deciding whether or not to copy foreign attributes or other interesting things
sub addCrossrefs {
  my ($self, $doc, $otherprocessor) = @_;
  my $selfs_map  = $$self{convertedIDs};
  my $others_map = $$otherprocessor{convertedIDs};
  my $xrefids    = $$self{crossreferencing_ids};
  my $backref    = {};
  foreach my $id (keys %$selfs_map) {
    foreach my $t (@{ $$selfs_map{$id} }) {
      $$backref{$t} = $id; } }
  foreach my $xid (keys %$selfs_map) {    # For each XMath id that $self converted
    my $other_ids = $$others_map{$xid};    # the ids where $xid ended up in $other processor
    if (!$other_ids) {
      # But If this node didn't directly end up in $other, try to find alternative
      # Typically happens when a "visible" node doesn't have visible representation in other format!
      # So, see if an ancestor got mapped.
      if (my $mapped = $$selfs_map{$xid}) {
        foreach my $mid (@$mapped) {
          if (my $node = $doc->findNodeByID($mid)) {
            my ($parent, $pid, $xpid) = ($node, undef, undef);
            while (($parent = $parent->parentNode)
              && ($parent->nodeType == XML_ELEMENT_NODE)      # in case we hit Document
              && (!($pid = $parent->getAttribute('xml:id'))
                || !($xpid = $$backref{$pid})
                || !$$others_map{$xpid})) { }
            if ($xpid) {
              $other_ids = $$others_map{$xpid}; } } } } }
    if ($other_ids) {                                         # Hopefully, we've got the targets, now
      my $xref_id = $$other_ids[0];
      if (scalar(@$other_ids) > 1) {    # Find 1st in document order! (order is cached)
        ($xref_id) = sort { $$xrefids{$a} <=> $$xrefids{$b} } @$other_ids; }
      foreach my $id (@{ $$selfs_map{$xid} }) {    # look at each node $self created from $xid
        if (my $node = $doc->findNodeByID($id)) {    # If we find a node,
          $self->addCrossref($node, $xref_id); } } }    # }    # add a crossref from it to $others's nod
    else {
  } }
  return; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

package LaTeXML::Post::Document;
use strict;
use LaTeXML::Common::XML;
use LaTeXML::Util::Pathname;
use LaTeXML::Util::Radix;
use DB_File;
use Unicode::Normalize;
use LaTeXML::Post;    # to import error handling...
use LaTeXML::Common::Error;
use base qw(LaTeXML::Common::Object);
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
# Note that these may not be LaTeXML documents (maybe html or ....)
sub new {
  my ($class, $xmldoc, %options) = @_;
  my $self = $class->new_internal($xmldoc, %options);
  $self->setDocument_internal($xmldoc);
  return $self; }

sub new_internal {
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
  # Start, at least, with our own namespaces.
  $data{namespaces}       = { ltx    => $NSURI } unless $data{namespaces};
  $data{namespaceURIs}    = { $NSURI => 'ltx' }  unless $data{namespaceURIs};
  $data{idcache}          = {};
  $data{idcache_reusable} = {};
  $data{idcache_reserve}  = {};

  my $self = bless {%data}, $class;
  return $self; }

sub newFromFile {
  my ($class, $source, %options) = @_;
  $options{source} = $source;
  $source = pathname_find($source, paths => $$class{searchpaths}) if ref $class;
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

#======================================================================

# This is for creating essentially "sub documents"
# that are in some sense children of $self, possibly removed or cloned from it.
# And they are presumably LaTeXML documents
sub newDocument {
  my ($self, $root, %options) = @_;
  my $clone_suffix = $options{clone_suffix};
  delete $options{clone_suffix};
  my $doc = $self->new_internal(undef, %options);
  $doc->setDocument_internal($root, clone_suffix => $clone_suffix);

  if (my $root_id = $self->getDocumentElement->getAttribute('xml:id')) {
    $$doc{split_from_id} = $root_id; }

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

sub setDocument_internal {
  my ($self, $root, %options) = @_;
  # Build the document's XML
  my $roottype = ref $root;
  if ($roottype eq 'LaTeXML::Core::Document') {
    $root     = $root->getDocument;
    $roottype = ref $root; }
  if (my $clone_suffix = $options{clone_suffix}) {
    if ($roottype eq 'XML::LibXML::Document') {
      Fatal('internal', 'unimplemented', undef,
        "Have not yet implemented cloning for entire documents"); }
    # Just make a clone, and then insert that.
    $root = $self->cloneNode($root, $clone_suffix); }

  if ($roottype eq 'XML::LibXML::Document') {
    $$self{document} = $root;
    foreach my $node ($self->findnodes("//*[\@xml:id]")) {    # Now record all ID's
      $$self{idcache}{ $node->getAttribute('xml:id') } = $node; }
    # Fetch any additional namespaces from the root

    if (my $docroot = $root->documentElement) {
      foreach my $ns ($docroot->getNamespaces) {
        my ($prefix, $uri) = ($ns->getLocalName, $ns->getData);
        if ($prefix) {
          $$self{namespaces}{$prefix} = $uri    unless $$self{namespaces}{$prefix};
          $$self{namespaceURIs}{$uri} = $prefix unless $$self{namespaceURIs}{$uri}; } } }

    # Extract data from latexml's ProcessingInstructions
    # I'd like to provide structured access to the PI's for those modules that need them,
    # but it isn't quite clear what that api should be.
    $$self{processingInstructions} =
      [map { $_->textContent } $XPATH->findnodes('.//processing-instruction("latexml")', $root)];
    # Combine specified paths with any from the PI's
    my @paths = ();
    @paths = @{ $$self{searchpaths} } if $$self{searchpaths};
    foreach my $pi (@{ $$self{processingInstructions} }) {
      if ($pi =~ /^\s*searchpaths\s*=\s*([\"\'])(.*?)\1\s*$/) {
        push(@paths, split(',', $2)); } }
    ### No, this ultimately can be the xml source, which may be the destination;
    ### adding this gets the wrong graphics (already processed!)
    ### push(@paths, pathname_absolute($$self{sourceDirectory})) if $$self{sourceDirectory};
    $$self{searchpaths} = [@paths]; }
  elsif ($roottype eq 'XML::LibXML::Element') {
    $$self{document} = XML::LibXML::Document->new("1.0", "UTF-8");
    # Assume we've got any namespaces already ?
    if (my $parent = $self->findnode('ancestor::*[@id][1]', $root)) {
      $$self{parent_id} = $parent->getAttribute('xml:id'); }
    # if no cloning requested, we can just plug the node directly in.
    # (otherwise, we should use addNodes?)
    # Seems that only importNode (NOT adopt) works correctly,
    # PROVIDED we also set the namespace.
    $$self{document}->setDocumentElement($$self{document}->importNode($root));
    #    $$self{document}->documentElement->setNamespace($root->namespaceURI, $root->prefix, 1);
    $root->setNamespace($root->namespaceURI, $root->prefix, 1);
    foreach my $node ($self->findnodes("//*[\@xml:id]")) {    # Now record all ID's
      $$self{idcache}{ $node->getAttribute('xml:id') } = $node; } }
  elsif ($roottype eq 'ARRAY') {
    $$self{document} = XML::LibXML::Document->new("1.0", "UTF-8");
    my ($tag, $attributes, @children) = @$root;
    my ($prefix, $localname) = $tag =~ /^(.*):(.*)$/;
    my $nsuri = $$self{namespaces}{$prefix};
    my $node  = $$self{document}->createElementNS($nsuri, $localname);
    $$self{document}->setDocumentElement($node);
    map { $$attributes{$_} && $node->setAttribute($_ => $$attributes{$_}) } keys %$attributes
      if $attributes;

    if (my $id = $$attributes{'xml:id'}) {
      $self->recordID($id => $node); }
    $self->addNodes($node, @children); }
  else {
    Fatal('unexpected', $root, undef, "Dont know how to use '$root' as document element"); }
  return $self; }

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
# Accessors

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

sub stringify {
  my ($self) = @_;
  return 'Post::Document[' . $self->siteRelativeDestination . ']'; }

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
    my $v = eval {
      local $LaTeXML::IGNORE_ERRORS = 1;
      $rng->validate($$self{document}); };
    LaTeXML::Post::Error("malformed", 'document', undef,
      "Document fails RelaxNG validation (" . $schema . ")",
      "Validation reports: " . $@,
      "(Jing may provide a more precise report; https://relaxng.org/jclark/jing.html)")
      if $@ || !defined $v; }
  elsif (my $decldtd = $$self{document}->internalSubset) {    # Else look for DTD Declaration
    my $dtd = XML::LibXML::Dtd->new($decldtd->publicId, $decldtd->systemId);
    if (!$dtd) {
      LaTeXML::Post::Error("I/O", $decldtd->publicId, undef,
        "Failed to load DTD " . $decldtd->publicId . " at " . $decldtd->systemId,
        "skipping validation"); }
    else {
      my $v = eval {
        local $LaTeXML::IGNORE_ERRORS = 1;
        $$self{document}->validate($dtd); };
      LaTeXML::Post::Error("malformed", 'document', undef,
        "Document failed DTD validation (" . $decldtd->systemId . ")",
        "Validation reports: " . $@) if $@ || !defined $v; } }
  else {    # Nothing found to validate with
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
    $dups{$id}    = 1 if $idcache{$id};
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
        my $new;
        if (ref $node eq 'LibXML::XML::Document') {
          $new = $node->createElementNS($nsuri, $localname);
          $node->setDocumentElement($new); }
        else {
          $new = $node->addNewChild($nsuri, $localname); }
        if ($attributes) {
          foreach my $key (sort keys %$attributes) {
            next unless defined $$attributes{$key};
            next if $key =~ /^_/;    # Ignore internal attributes
            my ($attrprefix, $attrname) = $key =~ /^(.*):(.*)$/;
            my $value = $$attributes{$key};
            if ($key eq 'xml:id') {
              if (defined $$self{idcache}{$value}) {    # Duplicated ID ?!?!
                my $newid = $self->uniquifyID($value);
                Info('unexpected', 'duplicate_id', undef,
                  "Duplicated id=$value using $newid " . ($$self{destination} || ''));
                $value = $newid; }
              $self->recordID($value => $new);
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
        # Note: this isn't actually much slower than $node->appendChild($child) !
        my $nsuri     = $child->namespaceURI;
        my $localname = $child->localname;
        my $new;
        if (ref $node eq 'LibXML::XML::Document') {
          $new = $node->createElementNS($nsuri, $localname);
          $node->setDocumentElement($new); }
        else {
          $new = $node->addNewChild($nsuri, $localname); }
        foreach my $attr ($child->attributes) {
          my $atype = $attr->nodeType;
          if ($atype == XML_ATTRIBUTE_NODE) {
            my $key = $attr->nodeName;
            if    ($key =~ /^_/) { }     # don't copy internal attributes
            elsif ($key eq 'xml:id') {
              my $value = $attr->getValue;
              my $old;
              if ((defined($old = $$self{idcache}{$value}))    # if xml:id was already used
                && !$old->isSameNode($child)) {                # and the node was a different one
                my $newid = $self->uniquifyID($value);
                Info('unexpected', 'duplicate_id', undef,
                  "Duplicated id=$value using $newid " . ($$self{destination} || ''));
                $value = $newid; }
              $self->recordID($value => $new);
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
    if    (!$ref) { }
    elsif ($ref eq 'ARRAY') {
      my ($t, $a, @n) = @$node;
      if (my $id = $$a{'xml:id'}) {
        if ($$self{idcache}{$id}) {
          delete $$self{idcache}{$id}; } }
      $self->removeNodes(@n); }
    elsif ($ref =~ /^XML::LibXML::/) {
      if ($node->nodeType == XML_ELEMENT_NODE) {
        foreach my $idd ($self->findnodes("descendant-or-self::*[\@xml:id]", $node)) {
          my $id = $idd->getAttribute('xml:id');
          if ($$self{idcache}{$id}) {
            delete $$self{idcache}{$id}; } } }
      $node->unlinkNode; } }
  return; }

# These nodes will be removed, but later
# So mark all id's in these trees as reusable
sub preremoveNodes {
  my ($self, @nodes) = @_;
  foreach my $node (@nodes) {
    my $ref = ref $node;
    if    (!$ref) { }
    elsif ($ref eq 'ARRAY') {
      my ($t, $a, @n) = @$node;
      if (my $id = $$a{'xml:id'}) {
        $$self{idcache_reusable}{$id} = 1; }
      $self->preremoveNodes(@n); }
    elsif ($ref =~ /^XML::LibXML::/) {
      if ($node->nodeType == XML_ELEMENT_NODE) {
        foreach my $idd ($self->findnodes("descendant-or-self::*[\@xml:id]", $node)) {
          my $id = $idd->getAttribute('xml:id');
          $$self{idcache_reusable}{$id} = 1; } } } }
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
# If $idsuffix is supplied, it can be a simple string to append to the ids;
# else can be a function of the id to modify it.
# Then each $id is checked to see whether it is unique; If needed,
# one or more letters are appended, until a new id is found.
sub cloneNode {
  my ($self, $node, $idsuffix, %options) = @_;
  return $node unless ref $node;
  return $node if ref $node eq 'ARRAY'; # Should we deep clone if we get an array? Just return for now
  my $copy    = $node->cloneNode(1);
  my $nocache = $options{nocache};
####  $idsuffix = '' unless defined $idsuffix;
  # Find all id's defined in the copy and change the id.
  my %idmap = ();
  foreach my $n ($self->findnodes('descendant-or-self::*[@xml:id]', $copy)) {
    my $id    = $n->getAttribute('xml:id');
    my $newid = $self->uniquifyID($id, $idsuffix);
    $idmap{$id} = $newid;
    $self->recordID($newid => $n) unless $nocache;
    $n->setAttribute('xml:id' => $newid);
    if (my $fragid = $n->getAttribute('fragid')) {    # GACK!!
      $n->setAttribute(fragid => substr($newid, length($id) - length($fragid))); } }

  # Now, replace all REFERENCES to those modified ids.
  foreach my $n ($self->findnodes('descendant-or-self::*[@idref]', $copy)) {
    if (my $id = $idmap{ $n->getAttribute('idref') }) {
      $n->setAttribute(idref => $id); } }             # use id or fragid?
      # Finally, we probably shouldn't have any labels attributes in here either
  foreach my $n ($self->findnodes('descendant-or-self::*[@labels]', $copy)) {
    $n->removeAttribute('labels'); }
  # And, if we're relocating the node across documents,
  # we may need to patch relative pathnames!
  # ????? Something to think about in the future...
  #  if(my $base = $options{basepathname}){
  #    foreach my $n ($self->findnodes('descendant::*/@graphic or descendant::*/@href', $copy)) {
  #      $n->setvalue(relocate($n->value,$base)); }}
  return $copy; }

sub cloneNodes {
  my ($self, @nodes) = @_;
  return map { $self->cloneNode($_) } @nodes; }

sub addSSValues {
  my ($self, $node, $key, $values) = @_;
  $values = $values->toAttribute if ref $values;
  if ((defined $values) && ($values ne '')) {    # Skip if `empty'; but 0 is OK!
    my @values = split(/\s/, $values);
    if (my $oldvalues = $node->getAttribute($key)) {    # previous values?
      my @old = split(/\s/, $oldvalues);
      foreach my $new (@values) {
        push(@old, $new) unless grep { $_ eq $new } @old; }
      $node->setAttribute($key => join(' ', sort @old)); }
    else {
      $node->setAttribute($key => join(' ', sort @values)); } }
  return; }

sub addClass {
  my ($self, $node, $class) = @_;
  return $self->addSSValues($node, class => $class); }

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
  return unless $node;
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
  $string =~ s/^\s+//gs;
  $string =~ s/^[^a-zA-Z]*// if $force;
  return ($string =~ /^([a-zA-Z])/ ? uc($1) : '*'); }

# This would typically be called to normalize the leading/trailing whitespace of nodes
# that take mixed markup. WE SHOULDN'T BE DOING THIS. We need to NOT add "ignorable whitespace"
# to nodes that CAN HAVE mixed content. otherwise we don't know if it is ignorable!
sub trimChildNodes {
  my ($self, $node) = @_;
  if (!$node) {
    return (); }
  elsif (!ref $node) {
    return ($node); }
  elsif (my @children = $node->childNodes) {
    if ($children[0] && $children[0]->nodeType == XML_TEXT_NODE) {
      my $s = $children[0]->data;
      $s =~ s/^\s+//;
      if ($s) {
        $children[0]->setData($s); }
      else {
        shift(@children); } }
    if ($children[-1] && $children[-1]->nodeType == XML_TEXT_NODE) {
      my $s = $children[-1]->data;
      $s =~ s/\s+$//;
      if ($s) {
        $children[-1]->setData($s); }
      else {
        pop(@children); } }
    return @children; }
  else {
    return (); } }

sub unisort {
  my ($self, @keys) = @_;
  # Get a (possibly cached) sorter from POST appropriate for this document's language
  my $lang = $self->getDocumentElement->getAttribute('xml:lang') || 'en';
  return $LaTeXML::POST->getsorter($lang)->sort(@keys); }

#======================================================================

sub addNavigation {
  my ($self, $relation, $id) = @_;
  return if $self->findnode('//ltx:navigation/ltx:ref[@rel="' . $relation . '"][@idref="' . $id . '"]');
  my $ref = ['ltx:ref', { idref => $id, rel => $relation, show => 'toctitle' }];
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
  $$self{idcache}{$id} = $node;
  delete $$self{idcache_reserve}{$id};     # And no longer reserved
  delete $$self{idcache_reusable}{$id};    #  or reusable
  return; }

sub findNodeByID {
  my ($self, $id) = @_;
  my $node = $$self{idcache}{$id};
  return $$self{idcache}{$id}; }

# If $branch given, should be 'content' or 'presentation'
sub realizeXMNode {
  my ($self, $node, $branch) = @_;
  if ($branch) {
    while ($node) {
      my $qname = $self->getQName($node);
      if ($qname eq 'ltx:XMRef') {
        my $id = $node->getAttribute('idref');
        if (my $realnode = $self->findNodeByID($id)) {
          $node = $realnode; }
        else {
          Error('expected', 'id', undef, "Cannot find a node with xml:id='$id'");
          return; } }
      elsif ($qname eq 'ltx:XMDual') {
        my ($content, $presentation) = element_nodes($node);
        $node = ($branch eq 'content' ? $content : $presentation); }
      else {
        return $node; } } }
  elsif ($self->getQName($node) eq 'ltx:XMRef') {
    my $id = $node->getAttribute('idref');
    if (my $realnode = $self->findNodeByID($id)) {
      return $realnode; }
    else {
      Error('expected', 'id', undef, "Cannot find a node with xml:id='$id'");
      return; } }
  return $node; }

sub uniquifyID {
  my ($self, $baseid, $suffix) = @_;
  my $id = $baseid;
  $id = (ref $suffix eq 'CODE' ? &$suffix($id) : $id . $suffix) if defined $suffix;
  my $cachekey = $id;
  while (($$self{idcache}{$id} || $$self{idcache_reserve}{$id}) && !$$self{idcache_reusable}{$id}) {
    $id = $baseid . radix_alpha(++$$self{idcache_clashes}{$cachekey});
    $id = (ref $suffix eq 'CODE' ? &$suffix($id) : $id . $suffix) if defined $suffix; }
  delete $$self{idcache_reusable}{$id};    # $id is no longer reusable
  $$self{idcache_reserve}{$id} = 1;        # and we'll consider it reserved until recorded.
  return $id; }

# Generate, add and register an xml:id for $node.
# Unless it already has an id, the created id will
# be "structured" relative to it's parent using $prefix
sub generateNodeID {
  my ($self, $node, $prefix, $reusable) = @_;
  my $id = $node->getAttribute('xml:id');
  return $id if $id;
  # Find the closest parent with an ID
  my ($parent, $pid, $n) = ($node->parentNode, undef, undef);
  while ($parent && !($pid = $parent->getAttribute('xml:id'))) {
    $parent = $parent->parentNode; }
  # Now find the next unused id relative to the parent id, as "prefix<number>"
  $pid .= '.' if $pid;
  for ($n = 1 ; ($id = $pid . $prefix . $n)
      && ($$self{idcache}{$id} || $$self{idcache_reserved}{$id}) ; $n++) { }
  $node->setAttribute('xml:id' => $id);
  $$self{idcache}{$id}          = $node;
  $$self{idcache_reusable}{$id} = $reusable;
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
  $key = Encode::encode_utf8($key) if $key;
  return $$self{cache}{$key}; }

sub cacheStore {
  my ($self, $key, $value) = @_;
  $self->openCache;
  $key = Encode::encode_utf8($key) if $key;
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
