# /=====================================================================\ #
# |  LaTeXML::Common::Model::RelaxNG                                    | #
# | Extract Model information from a RelaxNG schema                     | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Model::RelaxNG;
use strict;
use warnings;
use LaTeXML::Util::Pathname;
use LaTeXML::Common::XML;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use Scalar::Util qw(weaken);

my $XMLPARSER = LaTeXML::Common::XML::Parser->new();    # [CONSTANT]

#  $schema->documentModules;

# NOTE: Pending problem;
# Once we've got multiple namespaces in the schema,
# we haven't provided a means to specify the namespace <=> prefix mapping!
# It may be that rnc supplies that info, however!
# Alternatively, we could extract a symbol from the url,
# but it needs a sanity/collision check!

# NOTE: When a schema is composed from various modules,
# some elements may not be "reachable" and (perhaps) should be removed

# Scan a RelaxNG schema into an internal summary of modules.
sub new {
  my ($class, $model, $name) = @_;
  my $self = { name => $name, model => $model,
    modules => [], elementdefs => {}, defs => {}, elements => {},
    internal_grammars => 0 };
  weaken($$self{model});    # circular back ref; weaked so can be garbage collected.
  bless $self, $class;
  return $self; }

sub addSchemaDeclaration {
  my ($self, $document, $tag) = @_;
  $document->insertPI('latexml', RelaxNGSchema => $$self{name});
  return; }

sub loadSchema {
  my ($self) = @_;
  NoteBegin("Loading RelaxNG $$self{name}");
  # Scan the schema file(s), and extract the info
  my @schema = $self->scanExternal($$self{name});
  if ($LaTeXML::Common::Model::RelaxNG::DEBUG) {
    print STDERR "========================\nRaw Schema\n";
    map { showSchema($_) } @schema; }
  @schema = map { $self->simplify($_) } @schema;
  if ($LaTeXML::Common::Model::RelaxNG::DEBUG) {
    print STDERR "========================\nSimplified Schema\n";
    map { showSchema($_) } @schema;
    print STDERR "========================\nElements\n";
    foreach my $tag (sort keys %{ $$self{elements} }) {
      showSchema(['element', $tag, @{ $$self{elements}{$tag} }]); }
    print STDERR "========================\nModules\n";
    foreach my $mod (@{ $$self{modules} }) {
      showSchema($mod); } }

  # The resulting @schema should contain the "start" of the grammar.
  my ($startcontent) = $self->extractContent('#Document', @schema);
  $$self{model}->addTagContent('#Document', keys %$startcontent);
  if ($LaTeXML::Common::Model::RelaxNG::DEBUG) {
    print STDERR "========================\nStart\n" . join(', ', keys %$startcontent) . "\n"; }

  # NOTE: Do something automatic about this too!?!
  # We'll need to generate namespace prefixes for all namespaces found in the doc!
  $$self{model}->registerDocumentNamespace(undef, "http://dlmf.nist.gov/LaTeXML");

  # Distill the info into allowed children & attributes for each element.
  foreach my $tag (sort keys %{ $$self{elements} }) {
    if ($tag eq 'ANY') {
      # Ignore any internal structure (side effect of restricted names)
      $$self{model}->addTagContent($tag, 'ANY');
      next; }
    my @body = @{ $$self{elements}{$tag} };
    my ($content, $attributes) = $self->extractContent($tag, @body);
    $$self{model}->addTagContent($tag, keys %$content);
    $$self{model}->addTagAttribute($tag, keys %$attributes); }
  # Extract definitions of symbols that define Schema Classes, too
  foreach my $symbol (sort keys %{ $$self{defs} }) {
    if ($symbol =~ /^grammar\d+:(.+?)\.class$/) {
      my $name = $1;
      my ($content, $attributes) = $self->extractContent($symbol, $$self{defs}{$symbol});
      $$self{model}->setSchemaClass($name, $content); } }
  NoteEnd("Loading RelaxNG $$self{name}");
  return; }

# Return two hashrefs for content & attributes
sub extractContent {
  my ($self, $tag, @body) = @_;
  my (%attr, %child);
  my @savebody = @body;
  while (@body) {
    my $item = shift(@body);
    if (ref $item eq 'ARRAY') {
      my ($op, $name, @args) = @$item;
      if    ($op eq 'attribute')  { $attr{$name}  = 1; }
      elsif ($op eq 'elementref') { $child{$name} = 1; }
      elsif ($op eq 'doc')        { }
      elsif ($op eq 'combination') { push(@body, @args); }
      elsif ($op eq 'grammar')     { push(@body, $self->extractStart(@args)); }
      elsif ($op eq 'module')      { push(@body, $self->extractStart(@args)); }
      elsif (($op eq 'ref') || ($op eq 'parentref')) {

        if (my $el = $$self{elementdefs}{$name}) {
          push(@body, ['elementref', $el]); }
        elsif (my $expansion = $$self{defs}{$name}) {
          push(@body, $expansion); }
      }
      elsif ($op eq 'element') {
        $child{$name} = 1; }    # ???
      elsif (($op eq 'value') || ($op eq 'data')) {
        $child{'#PCDATA'} = 1; }
      else { print STDERR "Unknown child $op [$name] of element $tag in extractContent\n"; } }
    elsif ($item eq '#PCDATA') { $child{'#PCDATA'} = 1; } }
  return ({%child}, {%attr}); }

#======================================================================
# Internal Representation of a RelaxNG Schema

# This should build a usable intermediate structure
# WITHOUT side effects so that an (eventual) rnc parser
# can create the same intermediate!

# Intermediate structure is a list of
#    strings (representing the raw leave data)
# and recursive items of the following form:
#     [$op, $name, @forms]
# where $op is one of:
#   ref        : defines or references a symbol
#   parentref  : references a symbol in parent's context [converted to ref by simplify]
#   def,defchoice,definterleave : defines $name to be @forms.
#                the last 2 combine w/existing values.
#   elementref : references an element [Added by expand]
#   grammar    : Collects the a grammar's specifications; defined names are scoped (to $name),
#                and the start is the effective pattern.
#                (due to <grammar> or <externalRef> [Replaced by it's start by simplify]
#   override   : The @forms consist of a module, and the rest are replacement rules.
#                (due to <include>) [Reduced to 'module' by simplify]
#   element    : $name is the tag QName, @forms are the content/attribute patterns
#   attribute  : $name is the attribute's QName, @forms are the patterns for the value.
#   start      : the grammar's start pattern ($name is undef)
#   value      : a literal value (typically for attributes)
#   data       : a data type
#   doc        : An annotation ($name is undef), the @forms are documentation strings.
#   combination: combines various other patterns in @forms,
#                $name is one of group, interleave, choice, optional, zeroOrMore, oneOrMore, list
#   module     : collects the specifications coming from a separate schema file
#                for documentation purposes;  $name is the name of the file
#                [Recored in the modules list and replaced by its content in simplify]

# Tricky is getting the thing scanned and creating blocks
# that should be separately documentable.
# Each external schema (whether include or external)?

#======================================================================
# SCAN: Walk through the XML Representation compiling information about
# modules, definitions and elements.
#
# The representation built here has minimal processing done,
# so that hopefully it will be feasable to generate the same structure
# from a parsed RelaxNG Compact, without duplicating the processing.
#======================================================================
my %RNGNSMAP = (    # [CONSTANT]
  "http://relaxng.org/ns/structure/1.0"                 => 'rng',
  "http://relaxng.org/ns/compatibility/annotations/1.0" => 'rnga');

local @LaTeXML::Common::Model::RelaxNG::PATHS = ();

sub scanExternal {
  my ($self, $name, $inherit_ns) = @_;
  my $modname = $name; $modname =~ s/\.rn(g|c)$//;
  my $paths = [@LaTeXML::Common::Model::RelaxNG::PATHS, @{ $STATE->lookupValue('SEARCHPATHS') }];
  if (my $schemadoc = LaTeXML::Common::XML::RelaxNG->new($name, searchpaths => $paths)) {
    my $uri = $schemadoc->URI;
    NoteBegin("Loading RelaxNG schema from $uri");
    local @LaTeXML::Common::Model::RelaxNG::PATHS
      = (pathname_directory($schemadoc->URI), @LaTeXML::Common::Model::RelaxNG::PATHS);
    my $node = $schemadoc->documentElement;
    # Fetch any additional namespaces
    foreach my $ns ($node->getNamespaces) {
      my ($prefix, $nsuri) = ($ns->getLocalName, $ns->getData);
      next if $nsuri =~ m|^http://relaxng.org|;    # Ignore RelaxNG namespaces(!!)
      $$self{model}->registerDocumentNamespace($prefix, $nsuri); }
    my $mod = (['module', $modname, $self->scanPattern($node, $inherit_ns)]);
    NoteEnd("Loading RelaxNG schema from $uri");
    return $mod; }
  else {
    Warn('expected', $name, undef, "Failed to find RelaxNG schema for name '$name'");
    return (); } }

sub getRelaxOp {
  my ($node) = @_;
  return unless $node->nodeType == XML_ELEMENT_NODE;
  my $ns = $node->namespaceURI;
  my $prefix = $ns && $RNGNSMAP{$ns};
  return ($prefix ? $prefix : "{$ns}") . ":" . $node->localname; }

sub getElements {
  my ($node) = @_;
  return grep { $_->nodeType == XML_ELEMENT_NODE } $node->childNodes; }

my $COMBINER_re =    # [CONSTANT]
  qr/group|interleave|choice|optional|zeroOrMore|oneOrMore|list/;

sub scanPattern {
  my ($self, $node, $inherit_ns) = @_;
  if (my $relaxop = getRelaxOp($node)) {
    my $ns = $node->getAttribute('ns') || $inherit_ns;    # Possibly bind new namespace
                                                          # Element description
    if ($relaxop eq 'rng:element') {
      return $self->scanPattern_element($ns, $node); }
    # Attribute description
    elsif ($relaxop eq 'rng:attribute') {
      return $self->scanPattern_attribute($ns, $node); }
    # Various combiners
    elsif ($relaxop =~ /^rng:($COMBINER_re)$/) {
      my $op = $1;
      return (['combination', $op, $self->scanChildren($ns, getElements($node))]); }
    # Mixed is a combiner but includes #PCDATA
    elsif ($relaxop eq 'rng:mixed') {
      return (['combination', 'interleave', '#PCDATA', $self->scanChildren($ns, getElements($node))]); }
    # Reference to a defined symbol, or parent grammar's defined symbol
    elsif ($relaxop =~ /^rng:(ref|parentRef)$/) {
      my $op = lc($1);
      return ([$op, $node->getAttribute('name')]); }
    elsif ($relaxop =~ /^rng:(empty|notAllowed)$/) {    # Ignorable here
      return (); }
    elsif ($relaxop eq 'rng:text') {
      return ('#PCDATA'); }
    elsif ($relaxop eq 'rng:value') {                   # Not interested in details here.
      return (['value', undef, $node->textContent]); }
    elsif ($relaxop eq 'rng:data') {                    # Not interested in details here.
      return (['data', undef, $node->getAttribute('type')]); }
    # Include an external grammar
    elsif ($relaxop eq 'rng:externalRef') {
      return $self->scanExternal($node->getAttribute('href'), $ns); }
    # Include an internal grammar
    elsif ($relaxop eq 'rng:grammar') {
      return (['grammar', "grammar" . (++$$self{internal_grammars}),
          $self->scanGrammarContent($ns, getElements($node))]); }
    elsif ($relaxop =~ /^rnga:documentation$/) {
      return (['doc', undef, $node->textContent]); }
    else {
      Warn('misdefined', $relaxop, undef, "Didn't expect '$relaxop' in RelaxNG Schema (scanPattern)");
      return (); } }
  else {
    return (); } }

sub scanPattern_element {
  my ($self, $ns, $node) = @_;
  my @children = getElements($node);
  if (my $name = $node->getAttribute('name')) {
    return (['element', $$self{model}->encodeQName($ns, $name),
        $self->scanChildren($ns, @children)]); }
  else {
    my $namenode = shift(@children);
    my @names = $self->scanNameClass($namenode, $ns);
    return map { ['element', $_, $self->scanChildren($ns, @children)] } @names; } }

sub scanPattern_attribute {
  my ($self, $ns, $node) = @_;
  $ns = $node->getAttribute('ns');    # ONLY explicit declaration!
  my @children = getElements($node);
  if (my $name = $node->getAttribute('name')) {
    return (['attribute', $$self{model}->encodeQName($ns, $name),
        $self->scanChildren($ns, @children)]); }
  else {
    my $namenode = shift(@children);
    my @names = $self->scanNameClass($namenode, $ns);
    return map { ['attribute', $_, $self->scanChildren($ns, @children)] } @names; } }

sub scanChildren {
  my ($self, $ns, @children) = @_;
  return grep { $_ } map { ($self->scanPattern($_, $ns)) } @children; }

sub scanGrammarContent {
  my ($self, $ns, @content) = @_;
  return map { $self->scanGrammarItem($_, $ns) } @content; }

sub scanGrammarItem {
  my ($self, $node, $inherit_ns) = @_;
  if (my $relaxop = getRelaxOp($node)) {
    my @children = getElements($node);
    my $ns       = $node->getAttribute('ns') || $inherit_ns;   # Possibly bind new namespace
                                                               # The start element's content is returned
    if ($relaxop eq 'rng:start') {
      return (['start', undef, $self->scanChildren($ns, @children)]); }
    elsif ($relaxop eq 'rng:define') {
      my $name = $node->getAttribute('name');
      my $op = $node->getAttribute('combine') || '';
      return (['def' . $op, $name, $self->scanChildren($ns, @children)]); }
    elsif ($relaxop eq 'rng:div') {
      return $self->scanGrammarContent($ns, @children); }
    elsif ($relaxop eq 'rng:include') {
      my $name = $node->getAttribute('href');
      my $paths = [@LaTeXML::Common::Model::RelaxNG::PATHS, @{ $STATE->lookupValue('SEARCHPATHS') }];
      if (my $schemadoc = LaTeXML::Common::XML::RelaxNG->new($name, searchpaths => $paths)) {
        local @LaTeXML::Common::Model::RelaxNG::PATHS
          = (pathname_directory($schemadoc->URI), @LaTeXML::Common::Model::RelaxNG::PATHS);
        my @patterns;
        #  Hopefully, just a file, not a URL?
        my $doc = $schemadoc->documentElement;
        # Ignore the grammar level, if any, since we do NOT establish a binding with include
        if (getRelaxOp($doc) eq 'rng:grammar') {
          my $nns = $doc->getAttribute('ns') || $inherit_ns;    # Possibly bind new namespace
          @patterns = $self->scanGrammarContent($nns, getElements($doc)); }
        else {
          @patterns = $self->scanPattern($doc, undef); }
        # The rule is "includeContent", same as grammarContent
        # except that it shouldn't have nested rng:include;
        # we'll just assume there aren't any.
        my $mod = $name; $mod =~ s/\.rn(g|c)$//;
        if (my @replacements = $self->scanGrammarContent($ns, @children)) {
          return (['override', undef, ['module', $mod, @patterns], @replacements]); }
        else {
          return (['module', $mod, @patterns]); } }
      else {
        return (); } } }
  else {
    return (); } }

sub scanNameClass {
  my ($self, $node, $ns) = @_;
  my $relaxop = getRelaxOp($node);
  if ($relaxop eq 'rng:name') {
    return ($$self{model}->encodeQName($ns, $node->textContent)); }
  elsif ($relaxop eq 'rng:anyName') {
    Info('unexpected', $relaxop, undef, "Can't handle RelaxNG operation '$relaxop'",
      "Treating " . ToString($node) . " as ANY")
      if $node->hasChildNodes;
    return ('ANY'); }
  elsif ($relaxop eq 'rng:nsName') {
    Info('unexpected', $relaxop, undef, "Can't handle RelaxNG operation '$relaxop'",
      "Treating " . ToString($node) . " as ANY");
    # NOTE: We _could_ conceivably use a namespace predicate,
    # but Model has to be extended to support it!
    return ('ANY'); }
  elsif ($relaxop eq 'rng:choice') {
    my %names = ();
    foreach my $choice ($node->childNodes) {
      map { $names{$_} = 1 } $self->scanNameClass($choice, $ns); }
    return ($names{ANY} ? ('ANY') : keys %names); }
  else {
    my $op = $node->nodeName;
    Fatal('misdefined', $op, undef,
      "Expected a RelaxNG name element (rng:name|rng:anyName|rng:nsName|rng:choice), got '$op'");
    return; } }

#======================================================================
# Simplify
#   Various simplifications:
#     grammar : the binding of the separate space of defines is applied.
#               and the result is simplified, and replaced by the start.
#     module  : stored for any documentation purposes, and simplified content returned.
#     ref, parentref : replaced by a ref of appropriately scoped symbol.
#     def     : store the combined (but unexpanded) definitions

#   and
#     symbols, elements are recorded.

sub eqOp {
  my ($form, $op) = @_;
  return (ref $form eq 'ARRAY') && ($$form[0] eq $op); }

sub extractStart {
  my ($self, @items) = @_;
  my @starts = ();
  foreach my $item (@items) {
    if (ref $item eq 'ARRAY') {
      my ($op, $name, @args) = @$item;
      if    ($op eq 'start')   { push(@starts, @args); }
      elsif ($op eq 'module')  { push(@starts, $self->extractStart(@args)); }
      elsif ($op eq 'grammar') { push(@starts, $self->extractStart(@args)); }
    } }
  return @starts; }

# NOTE: Reconsider this process.
# In particular, how we're returning throwing away stuff (after it gets recorded).
# Mainly it's an issue for being able to document a schema,
# having separate sections for each "module".

# What order should we be simplifing and expanding?
# For documentable modules we want:
#    the content, grammars NOT yet replaced by start,
#    elementdef's sorted out
# For model extraction we also want
#   models flattened, grammars replaced by start, all symbols joined & expanded
#####
# In Simplify
# grammar: extract & return start
#          [for doc of a module, shouldn't do this, but for doc of an element, should!]
#          [Actually, I'm not even sure how to document an embedded grammar]
# override: make replacements in module, return module
#          [this should always happen]
# element : store in elements table
#         [OK]
# ref     : adjust name
#         [OK]
# parentref : adjust name, convert to ref
#         [OK]
# defchoice, definterleave, def: add to defns table, possibly combining with existing
#         [OK]
# module    : store in modules list, return contents
#             [for doc,we'd like to return nothing? but for getting grammar start we want content?]

sub simplify {
  my ($self, $form, $binding, $parentbinding, $container) = @_;
  if (ref $form eq 'ARRAY') {
    my ($op, $name, @args) = @$form;
    if ($op eq 'grammar') {
      return (['grammar', $name, $self->simplify_args($name, $binding, $container, @args)]); }
    elsif ($op eq 'override') {
      return $self->simplify_override($binding, $parentbinding, $container, @args); }
    elsif ($op eq 'module') {
      my $module = ['module', $name];
      push(@{ $$self{modules} }, $module);    # Keep in order: push first, then scan contents
      push(@$module, $self->simplify_args($binding, $parentbinding, $container, @args));
      return ($module); }
    elsif ($op eq 'element') {
      @args = $self->simplify_args($binding, $parentbinding, "element:$name", @args);
      push(@{ $$self{elements}{$name} }, @args);
      return (['element', $name, @args]); }
    elsif ($op =~ /^(ref|parentref)$/) {
      my $qname = ($1 eq 'parentref' ? $parentbinding : $binding) . ":" . $name;
      @args = $self->simplify_args($binding, $parentbinding, $container, @args);
      $$self{usesname}{$qname}{$container} = 1 if $container;
      return (['ref', $qname]); }
    elsif ($op =~ /^def(choice|interleave|)$/) {
      my $combination = $1 || 'group';
      my $qname = $binding . ":" . $name;
      $$self{usesname}{$qname}{$container} = 1 if $container;
      @args = $self->simplify_args($binding, $parentbinding, "pattern:$qname", @args);

      # Special case: simple definition of an element
      if (($combination eq 'group') && (scalar(@args) == 1) && eqOp($args[0], 'element')) {
        $$self{elementdefs}{$qname} = $args[0][1];
        $$self{elementreversedefs}{ $args[0][1] } = $qname;
        return @args; }
      else {
        my $prev  = $$self{defs}{$qname};
        my $prevc = $$self{def_combiner}{$qname};
        my @xargs = grep { !eqOp($_, 'doc') } @args;    # Remove annotations
        if ($prev) {                                    # Previoud definition?
          if (($combination eq 'group') && ($prevc eq 'group')) {    # apparently RE-defining $qname?
            $prev = undef; }
          elsif (($combination eq 'group') && ($prevc ne 'group')) {    # Use old combination!?!?!?!?
            $combination = $prevc; } }
        $$self{defs}{$qname} = simplifyCombination(['combination', $combination,
            ($prev ? @$prev : ()), @xargs]);
        $$self{def_combiner}{$qname} = $combination;
        return ([$op, $qname, @args]); } }
    else {
      return ([$op, $name, $self->simplify_args($binding, $parentbinding, $container, @args)]); } }
  else {
    return ($form); } }

sub simplify_args {
  my ($self, $binding, $parentbinding, $container, @forms) = @_;
  return map { $self->simplify($_, $binding, $parentbinding, $container) } @forms; }

sub simplify_override {
  my ($self, $binding, $parentbinding, $container, @args) = @_;
  # Note that we do NOT simplify till we've made the replacements!
  my ($module, @replacements) = @args;
  my ($modop, $modname, @patterns) = @$module;
  # Replace any start from @patterns by that from @replacement, if any.
  if (my @replacement_start = grep { eqOp($_, 'start') } @replacements) {
    @patterns = grep { !eqOp($_, 'start') } @patterns; }
  foreach my $def (grep { (ref $_ eq 'ARRAY') && ($$_[0] =~ /^def/) } @replacements) {
    my ($defop, $symbol) = @$def;
    @patterns = grep { !(eqOp($_, $defop) && ($$_[1] eq $symbol)) } @patterns; }
  # Recurse on the overridden module
  return $self->simplify(['module', "$modname (overridden)", @patterns, @replacements],
    $binding, $parentbinding, $container); }

sub simplifyCombination {
  my ($combination) = @_;
  if ((ref $combination) && ($$combination[0] eq 'combination')) {
    my ($c, $op, @stuff) = @$combination;
    @stuff = map { simplifyCombination($_) } @stuff;
    if ($op =~ /^(group|choice)$/) {    # These can be flattened.
      @stuff = map { ((ref $_) && ($$_[0] eq 'combination') && ($$_[1] eq $op)
          ? @$_[2 .. $#$_] : ($_)) }
        @stuff; }
    return [$c, $op, @stuff]; }
  else {
    return $combination; } }

#======================================================================
# For debugging...
sub showSchema {
  my ($item, $level) = @_;
  $level = 0 unless defined $level;
  if (ref $item eq 'ARRAY') {
    my ($op, $name, @args) = @$item;
    if ($op eq 'doc') { $name = "..."; @args = (); }
    print STDERR "" . (' ' x (2 * $level)) . $op . ($name ? " " . $name : '') . "\n";

    foreach my $arg (@args) {
      showSchema($arg, $level + 1); } }
  else {
    print STDERR "" . (' ' x (2 * $level)) . $item . "\n"; }
  return; }

#======================================================================
# Generate TeX documentation for a Schema
#======================================================================
# The svg schema can only just barely be read in and recognized,
# but it is structured in a way that makes a joke of our attempt at automatic documentation
my $SKIP_SVG = 1;    # [CONFIGURABLE?]

sub documentModules {
  my ($self) = @_;
  my $docs = "";
  $$self{defined_patterns} = {};
  foreach my $module (@{ $$self{modules} }) {
    my ($op, $name, @content) = @$module;
    next if $SKIP_SVG && $name =~ /:svg:/;    # !!!!
    $name =~ s/^urn:x-LaTeXML:RelaxNG://;     # Remove the urn part.
    $docs = join("\n", $docs,
      "\\begin{schemamodule}{$name}",
      (map { $self->toTeX($_) } @content),
      "\\end{schemamodule}"); }
  foreach my $name (keys %{ $$self{defined_patterns} }) {
    if ($$self{defined_patterns}{$name} < 0) {
      $docs =~ s/\\patternadd\{$name\}/\\patterndefadd{$name}/s; } }
  return $docs; }

sub cleanTeX {
  my ($string) = @_;
  return '\typename{text}' if $string eq '#PCDATA';
  $string =~ s/\#/\\#/g;
  $string =~ s/<([^>]*)>/\\texttt{$1}/g;    # An apparent convention <sometext> == ttfont?
  $string =~ s/_/\\_/g;
  return $string; }

sub cleanTeXName {
  my ($string) = @_;
  $string = cleanTeX($string);
  $string =~ s/^ltx://;
  #  $string =~ s/:/../;
  return $string; }

sub toTeX {
  my ($self, $object) = @_;
  if (ref $object eq 'HASH') {
    return join(', ', map { "$_=" . $self->toTeX($$object{$_}) } sort keys %$object); }
  elsif (ref $object eq 'ARRAY') {    # an object?
    my ($op, $name, @data) = @$object;
    if ($op eq 'doc') {
      return join(' ', map { cleanTeX($_) } @data) . "\n"; }
    elsif ($op eq 'ref') {
      return $self->toTeX_ref($op, $name); }
    elsif ($op =~ /^def(choice|interleave|)$/) {
      return $self->toTeX_def($1, $name, @data); }
    elsif ($op eq 'element') {
      return $self->toTeX_element($name, @data); }
    elsif ($op eq 'attribute') {
      return $self->toTeX_attribute($name, @data); }
    elsif ($op eq 'combination') {
      return $self->toTeX_combination($name, @data); }
    elsif ($op eq 'data') {
      return "\\typename{" . cleanTeX($data[0]) . "}"; }
    elsif ($op eq 'value') {
      return '\attrval{' . cleanTeX($data[0]) . "}"; }
    elsif ($op eq 'start') {
      my ($docs, @spec) = $self->toTeXExtractDocs(@data);
      my $content = join(' ', map { $self->toTeX($_) } @spec);
      return "\\item[\\textit{Start}]\\textbf{==}\\ $content" . ($docs ? " \\par$docs" : ''); }
    elsif ($op eq 'grammar') {    # Don't otherwise mention it?
##      join("\n",'\item[\textit{Grammar}:] '.$name,
      return join("\n", map { $self->toTeX($_) } @data); }
    elsif ($op eq 'module') {
      $name =~ s/^urn:x-LaTeXML:RelaxNG://;    # Remove the urn part.
      if (($name =~ /^svg/) && $SKIP_SVG) {
        return '\item[\textit{Module }' . cleanTeX($name) . '] included.'; }
      else {
        return '\item[\textit{Module }\moduleref{' . cleanTeX($name) . '}] included.'; } }
    else {
      Warn('unexpected', $op, undef, "RelaxNG->toTeX: Unrecognized item $op");
      return "[$op: " . join(', ', map { $self->toTeX($_) } @data) . "]"; } }
  else {
    return cleanTeX($object); } }

sub toTeX_ref {
  my ($self, $op, $name) = @_;
  if (my $el = $$self{elementdefs}{$name}) {
    $el = cleanTeXName($el);
    return "\\elementref{$el}"; }
  else {
    $name =~ s/^\w+://;    # Strip off qualifier!!!! (watch for clash in docs?)
    return "\\patternref{" . cleanTeX($name) . "}"; } }

sub toTeX_def {
  my ($self, $combiner, $name, @data) = @_;
  my $qname = $name;
  $name =~ s/^\w+://;      # Strip off qualifier!!!! (watch for clash in docs?)
  $name = cleanTeX($name);
  my ($docs, @spec)    = $self->toTeXExtractDocs(@data);
  my ($attr, $content) = $self->toTeXBody(@spec);
  if ($combiner) {
    my $body = $attr;
    $body .= '\item[' . ($combiner eq 'choice' ? '\textbar=' : '\&=') . '] ' . $content if $content;
    $$self{defined_patterns}{$name} = -1 unless defined $$self{defined_patterns}{$name};
    return "\\patternadd{$name}{$docs}{$body}\n"; }
  #      elsif((scalar(@data)==1) && (ref $data[0] eq 'ARRAY') && ($data[0][0] eq 'grammar')){
  else {
    $attr = '\item[\textit{Attributes:}] \textit{empty}' if !$attr && ($name =~ /\\_attributes/);
    $content = '\textit{empty}' if !$content && ($name =~ /\\_model/);
    my $body = $attr;
    $body .= '\item[\textit{Content}:] ' . $content if $content;
    my ($xattr, $xcontent) = $self->toTeXBody($$self{defs}{$qname});
    $body .= '\item[\textit{Expansion}:] ' . $xcontent
      if !$attr && !$xattr && $xcontent && ($xcontent ne $content);
    if ($name !~ /_(?:attributes|model)$/) { # Skip the "used by" if element-specific attributes or moel.

      if (my $uses = $self->getSymbolUses($qname)) {
        $body .= '\item[\textit{Used by}:] ' . $uses; } }
    if ((defined $$self{defined_patterns}{$name}) && ($$self{defined_patterns}{$name} > 0)) { # Already been defined???
      return ''; }
    else {
      $$self{defined_patterns}{$name} = 1;
      return "\\patterndef{$name}{$docs}{$body}\n"; } } }

sub toTeX_element {
  my ($self, $name, @data) = @_;
  my $qname = $name;
  $name =~ s/^ltx://;
  $name = cleanTeXName($name);
  my ($docs, @spec)    = $self->toTeXExtractDocs(@data);
  my ($attr, $content) = $self->toTeXBody(@spec);
  $content = "\\typename{empty}" unless $content;
  # Shorten display for element-specific attributes & model, ASSUMING they immediately folllow!
  $attr    = '' if $attr eq '\item[\textit{Attributes}:] \patternref{' . $name . '\\_attributes}';
  $content = '' if $content eq '\patternref{' . $name . '\\_model}';
  my $body = $attr;
  $body .= '\item[\textit{Content}:] ' . $content if $content;
  if (my $ename = $$self{elementreversedefs}{$qname}) {
    if (my $uses = $self->getSymbolUses($ename)) {
      $body .= '\item[\textit{Used by}:] ' . $uses; } }
  return "\\elementdef{$name}{$docs}{$body}\n"; }

sub toTeX_attribute {
  my ($self, $name, @data) = @_;
  $name = cleanTeXName($name);
  my ($docs, @spec) = $self->toTeXExtractDocs(@data);
  my $content = join(' ', map { $self->toTeX($_) } @spec) || '\typename{text}';
  return "\\attrdef{$name}{$docs}{$content}"; }

sub toTeX_combination {
  my ($self, $name, @data) = @_;
  if ($name eq 'group') {
    return "(" . join(', ', map { $self->toTeX($_) } @data) . ")"; }
  elsif ($name eq 'interleave') {
    return "(" . join(' ~\&~ ', map { $self->toTeX($_) } @data) . ")"; }    # ?
  elsif ($name eq 'choice') {
    return "(" . join(' ~\textbar~ ', map { $self->toTeX($_) } @data) . ")"; }
  elsif ($name eq 'optional') {
    if ((@data == 1) && eqOp($data[0], 'attribute')) {
      return $self->toTeX($data[0]); }
    else {
      return $self->toTeX($data[0]) . "?"; } }
  elsif ($name eq 'zeroOrMore') {
    return $self->toTeX($data[0]) . "*"; }
  elsif ($name eq 'oneOrMore') {
    return $self->toTeX($data[0]) . "+"; }
  elsif ($name eq 'list') {
    return "(" . join(', ', map { $self->toTeX($_) } @data) . ")"; }    # ?
  else {
    Warn('unexpected', $name, undef, "RelaxNG->toTeX: Unrecognized combination $name");
    return; } }

sub getSymbolUses {
  my ($self, $qname) = @_;
  if (my $uses = $$self{usesname}{$qname}) {
    my @uses = sort keys %$uses;
    @uses = grep { !/\bSVG./ } @uses if $SKIP_SVG;                      # !!!
    return join(', ',
      (map { /^pattern:[^:]*:(.*)$/ ? ('\patternref{' . cleanTeX($1) . '}')     : () } @uses),
      (map { /^pattern:[^:]*:(.*)$/ ? ('\patternref{' . cleanTeX($1) . '}')     : () } @uses),
      (map { /^element:(.*)$/       ? ('\elementref{' . cleanTeXName($1) . '}') : () } @uses)); }
  else {
    return ''; } }

# Extract any documentation nodes from @data
sub toTeXExtractDocs {
  my ($self, @data) = @_;
  my $docs = "";
  my @rest = ();
  while (my $item = shift(@data)) {
    if ((ref $item eq 'ARRAY') && ($$item[0] eq 'doc')) {
      $docs .= $self->toTeX($item); }
    else {
      push(@rest, $item); } }
  return ($docs, @rest); }

# Format the attributes & content model of a named pattern or element.
# This generates a sequence of \item's to be put in a definition list.
sub toTeXBody {
  my ($self, @data) = @_;
  my (@attributes, @content, @patterns);
  while (my $item = shift(@data)) {
    if (ref $item eq 'ARRAY') {
      my ($op, $name, @args) = @$item;
      # NOTE: W/o the simplification of optional(attribute), above,
      # we've got to do some extra work here!
      if ($op eq 'attribute') {
        push(@attributes, $self->toTeX($item)); }
      elsif (($op eq 'combination') && ($name eq 'optional')
        && (@args == 1) && eqOp($args[0], 'attribute')) {
        unshift(@data, $args[0]); }
      # Note dubious assumption about naming convention!
      elsif (($op eq 'ref') && ($name =~ /[^a-zA-Z]attributes$/)) {
        push(@patterns, $self->toTeX($item)); }
      else {
        push(@content, $self->toTeX($item)); } }
    else {
      push(@content, $self->toTeX($item)); } }
  return
    (join('', (@patterns
        ? '\item[\textit{'
          . ((grep { $_ !~ /[^a-zA-Z]attributes\}*?$/ } @patterns) ? 'Includes' : 'Attributes')
          . '}:] '
          . join(', ', @patterns)
        : ''),
      @attributes),
    join(', ', @content)); }

#======================================================================
1;

__END__

=head1 NAME

C<LaTeXML::Common::Model::RelaxNG> - represents RelaxNG document models;
extends L<LaTeXML::Common::Model>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
