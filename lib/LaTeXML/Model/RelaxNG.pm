# /=====================================================================\ #
# |  LaTeXML::Model::RelaxNG                                            | #
# | Extract Model information from a RelaxNG schema                     | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Model::RelaxNG;
use strict;
use LaTeXML::Util::Pathname;
use LaTeXML::Common::XML;
use LaTeXML::Global;
use base qw(LaTeXML::Model::Schema);

our $XMLPARSER = LaTeXML::Common::XML::Parser->new();

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
  my($class,$model,$name)=@_;
  my $self = {name=>$name, model=>$model,
	      modules=>[],elementdefs=>{},defs=>{}, elements=>{}};
  bless $self,$class;
  $self; }

sub addSchemaDeclaration {
  my($self,$document,$tag)=@_;
  $document->insertPI('latexml',RelaxNGSchema=>$$self{name});
}

sub loadSchema {
  my($self)=@_;
  NoteBegin("Loading RelaxNG $$self{name}");
  # Scan the schema file(s), and extract the info

  my @schema = $self->scanExternal($$self{name});
  if($LaTeXML::Model::RelaxNG::DEBUG){
    print "========================\nRaw Schema\n";
    map(showSchema($_),@schema); }
  @schema = map($self->simplify($_),@schema);
  if($LaTeXML::Model::RelaxNG::DEBUG){
    print "========================\nSimplified Schema\n";
    map(showSchema($_),@schema);
    print "========================\nElements\n";
    foreach my $tag (sort keys %{$$self{elements}}){
      showSchema(['element',$tag,@{$$self{elements}{$tag}}]); }
    print "========================\nModules\n";
    foreach my $mod (@{$$self{modules}}){
      showSchema($mod); }}

  # The resulting @schema should contain the "start" of the grammar.
  my($startcontent)=$self->extractContent('#Document',@schema);
  $$self{model}->setTagProperty('#Document','model',$startcontent);
  if($LaTeXML::Model::RelaxNG::DEBUG){
    print "========================\nStart\n".join(', ',keys %$startcontent)."\n"; }

  # NOTE: Do something automatic about this too!?!
  # We'll need to generate namespace prefixes for all namespaces found in the doc!
  $$self{model}->registerDocumentNamespace(undef,"http://dlmf.nist.gov/LaTeXML");

  # Distill the info into allowed children & attributes for each element.
  foreach my $tag (sort keys %{$$self{elements}}){
    if($tag eq 'ANY'){
      # Ignore any internal structure (side effect of restricted names)
      $$self{model}->setTagProperty($tag,'model',{ANY=>1});
      next; }
    my @body = @{$$self{elements}{$tag}};
    my($content,$attributes) = $self->extractContent($tag,@body);
    $$self{model}->setTagProperty($tag,'model',$content);
    $$self{model}->setTagProperty($tag,'attributes',$attributes); }
  NoteEnd("Loading RelaxNG $$self{name}"); }

# Return two hashrefs for content & attributes
sub extractContent {
  my($self,$tag,@body)=@_;
  my(%attr,%child);
  while(@body){
    my $item = shift(@body);
    if(ref $item eq 'ARRAY'){
      my($op,$name,@args)=@$item;
      if($op eq 'attribute'){ $attr{$name}=1; }
      elsif($op eq 'elementref'){ $child{$name}=1; }
      elsif($op eq 'doc'){}
      elsif($op eq 'combination'){ push(@body,@args); }
      elsif($op eq 'grammar'){     push(@body,$self->extractStart(@args)); }
      elsif($op eq 'module'){      push(@body,$self->extractStart(@args)); }
      elsif(($op eq 'ref') || ($op eq 'parentref')){
	if(my $el = $$self{elementdefs}{$name}){
	  push(@body,['elementref',$el]); }
	elsif(my $expansion = $$self{defs}{$name}){
	  push(@body,$expansion); }
      }
      elsif($op eq 'element'){
	$child{$name}=1; }	# ???
      elsif(($op eq 'value') || ($op eq 'data')){
	$child{'#PCDATA'} = 1; }
      else { print STDERR "Unknown child $op [$name] of element $tag in extractContent\n"; }}
    elsif($item eq '#PCDATA'){  $child{'#PCDATA'}=1; }}
  ({%child},{%attr}); }

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
our %RNGNSMAP = ("http://relaxng.org/ns/structure/1.0"=>'rng',
		 "http://relaxng.org/ns/compatibility/annotations/1.0"=>'rnga');

local @LaTeXML::Model::RelaxNG::PATHS=();

sub scanExternal {
  my($self,$name,$inherit_ns)=@_;
  my $mod = $name; $mod =~ s/\.rn(g|c)$//;
  if(my $path = findSchema($name)){
    #  Hopefully, just a file, not a URL?
    local @LaTeXML::Model::RelaxNG::PATHS
      = (pathname_directory($path),@LaTeXML::Model::RelaxNG::PATHS);
    my $node = $XMLPARSER->parseFile($path)->documentElement;
    # Fetch any additional namespaces
    foreach my $ns ($node->getNamespaces){
	my($prefix,$uri)=($ns->getLocalName,$ns->getData);
	next if $uri =~ m|^http://relaxng.org|; # Ignore RelaxNG namespaces(!!)
	$$self{model}->registerDocumentNamespace($prefix,$uri); }
    (['module',$mod,$self->scanPattern($node,$inherit_ns)]); }
  else {
    Error(":missing_file:$name Couldn't find RelaxNG schema $name"); 
    (); }}

sub getRelaxOp {
  my($node)=@_;
  return unless $node->nodeType == XML_ELEMENT_NODE;
  my $ns = $node->namespaceURI;
  my $prefix = $ns && $RNGNSMAP{$ns};
  ($prefix ? $prefix : "{$ns}").":".$node->localname; }

sub findSchema {
  my($name)=@_;
  pathname_find($name, paths=>[@LaTeXML::Model::RelaxNG::PATHS,
			       @{$STATE->lookupValue('SEARCHPATHS')}],
		types=>['rng'],	# Eventually, rnc?
		installation_subdir=>'schema/RelaxNG'); }

our $GRAMMAR=0;

sub getElements {
  my($node)=@_;
  grep($_->nodeType == XML_ELEMENT_NODE, $node->childNodes); }

sub scanPattern {
  my($self,$node,$inherit_ns)=@_;
  if(my $relaxop = getRelaxOp($node)){
    my @children = getElements($node);
    my $ns = $node->getAttribute('ns') || $inherit_ns; # Possibly bind new namespace

    # Element description
    if($relaxop eq 'rng:element'){
      if(my $name = $node->getAttribute('name')){
	(['element',$$self{model}->encodeQName($ns,$name),
	  map($self->scanPattern($_,$ns),@children)]); }
      else {
	my $namenode = shift(@children);
	my @names = $self->scanNameClass($namenode,$ns);
	map(['element',$_,map($self->scanPattern($_,$ns),@children)], @names); }}
    # Attribute description
    elsif($relaxop eq 'rng:attribute'){
      $ns = $node->getAttribute('ns'); # ONLY explicit declaration!
      if(my $name = $node->getAttribute('name')){
	(['attribute',$$self{model}->encodeQName($ns,$name),
	  map($self->scanPattern($_,$ns),@children)]); }
      else {
	my $namenode = shift(@children);
	my @names = $self->scanNameClass($namenode,$ns);
	map(['attribute',$_,map($self->scanPattern($_,$ns),@children)], @names); }}
    # Various combiners
    elsif($relaxop =~ /^rng:(group|interleave|choice|optional|zeroOrMore|oneOrMore|list)$/){
      my $op = $1;
      (['combination',$op,map($self->scanPattern($_,$ns), @children)]); }
    # Mixed is a combiner but includes #PCDATA
    elsif($relaxop eq 'rng:mixed'){
      (['combination','interleave','#PCDATA',map($self->scanPattern($_,$ns), @children)]); }
    # Reference to a defined symbol.
    elsif($relaxop eq 'rng:ref'){
      (['ref',$node->getAttribute('name')]); }
    # Reference to parent grammar's defined symbol
    elsif($relaxop eq 'rng:parentRef'){
      (['parentref',$node->getAttribute('name')]); }
    elsif($relaxop =~ /^rng:(empty|notAllowed)$/){ # Ignorable here
      (); }
    elsif($relaxop eq 'rng:text'){ 
      ('#PCDATA'); }
    elsif($relaxop eq 'rng:value'){ # Not interested in details here.
      (['value', undef, $node->textContent]); }
    elsif($relaxop eq 'rng:data'){ # Not interested in details here.
      (['data', undef, $node->getAttribute('type')]); }
    # Include an external grammar
    elsif($relaxop eq 'rng:externalRef'){
      $self->scanExternal($node->getAttribute('href'),$ns); }
    # Include an internal grammar
    elsif($relaxop eq 'rng:grammar'){
      my $name = "grammar".(++$GRAMMAR);
      (['grammar',$name, map($self->scanGrammarContent($_,$ns),@children)]); }
    elsif($relaxop =~ /^rnga:documentation$/){
      (['doc',undef,$node->textContent]); }
    else {
      Warn(":model Didn't expect $relaxop in RelaxNG Schema (scanPattern)");
      (); }}
  else {
    (); }}

sub scanGrammarContent {
  my($self,$node,$inherit_ns)=@_;
  if(my $relaxop = getRelaxOp($node)){
    my @children = getElements($node);
    my $ns = $node->getAttribute('ns') || $inherit_ns; # Possibly bind new namespace
    # The start element's content is returned
    if($relaxop eq 'rng:start'){
      (['start',undef,map($self->scanPattern($_,$ns), @children)]); }
    elsif($relaxop eq 'rng:define'){
      my $name = $node->getAttribute('name');
      my $op = $node->getAttribute('combine')||'';
      (['def'.$op, $name, map($self->scanPattern($_,$ns),@children)]); }
    elsif($relaxop eq 'rng:div'){
      map($self->scanGrammarContent($_,$ns), @children); }
    elsif($relaxop eq 'rng:include'){
      my $name = $node->getAttribute('href');
      if(my $path = findSchema($name)){
	local @LaTeXML::Model::RelaxNG::PATHS
	  = (pathname_directory($path),@LaTeXML::Model::RelaxNG::PATHS);
	#  Hopefully, just a file, not a URL?
	my $doc = $XMLPARSER->parseFile($path)->documentElement;
	my @patterns;
	# Ignore the grammar level, if any, since we do NOT establish a binding with include
	if(getRelaxOp($doc) eq 'rng:grammar'){
	  my $ns = $doc->getAttribute('ns') || $inherit_ns; # Possibly bind new namespace
	  @patterns = map($self->scanGrammarContent($_,$ns),  getElements($doc)); }
	else {
	  @patterns = $self->scanPattern($doc,undef); }
	# The rule is "includeContent", same as grammarContent
	# except that it shouldn't have nested rng:include;
	# we'll just assume there aren't any.
	my $mod = $name; $mod =~ s/\.rn(g|c)$//;
	if(my @replacements = map($self->scanGrammarContent($_,$ns),@children)){
	  (['override',undef,['module',$mod,@patterns],@replacements]); }
	else {
	  (['module',$mod,@patterns]); }}
      else {
	Error(":missing_file:$name Couldn't find RelaxNG schema $name"); 
	(); }}}
  else {
    (); }}

sub scanNameClass {
  my($self,$node,$ns)=@_;
  my $relaxop = getRelaxOp($node);
  if($relaxop eq 'rng:name'){
    ($$self{model}->encodeQName($ns,$node->textContent)); }
  elsif($relaxop eq 'rng:anyName'){
    warn "RelaxNG: treating ".$node->toString." as ANY"
      if $node->hasChildNodes;
    ('ANY'); }
  elsif($relaxop eq 'rng:nsName'){
    warn "RelaxNG: treating ".$node->toString." as ANY";
    # NOTE: We _could_ conceivably use a namespace predicate,
    # but Model has to be extended to support it!
    ('ANY'); }
  elsif($relaxop eq 'rng:choice'){
    my %names=();
    foreach my $choice ($node->childNodes){
      map($names{$_}=1, $self->scanNameClass($choice,$ns)); }
    ($names{ANY} ? ('ANY') : keys %names); }
  else {
    die "Expected a name element (rng:name|rng:anyName|rng:nsName|rng:choice), got "
      .$node->nodeName; }}

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
  my($form,$op)=@_;
  (ref $form eq 'ARRAY') && ($$form[0] eq $op); }

sub extractStart {
  my($self,@items)=@_;
  my @starts = ();
  foreach my $item (@items){
    if(ref $item eq 'ARRAY'){
      my($op,$name,@args)=@$item;
      if($op eq 'start'){ push(@starts,@args); }
      elsif($op eq 'module'){ push(@starts,$self->extractStart(@args)); }
      elsif($op eq 'grammar'){ push(@starts,$self->extractStart(@args)); }
    }}
  @starts; }

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
  my($self,$form,$binding,$parentbinding,$container)=@_;
  if(ref $form eq 'ARRAY'){
    my($op,$name,@args)=@$form;
    if($op eq 'grammar'){
      # Simplify, for side-effect
      my @patterns = map($self->simplify($_,$name,$binding,$container),@args);
      # and return the start
###      extractStart(@patterns); 
      ## OR maybe later?
      (['grammar',$name,@patterns]);
    }
    elsif($op eq 'override'){
      # Note that we do NOT simplify till we've made the replacements!
      my($module,@replacements)=@args;
      my($modop,$modname,@patterns)=@$module;
      # Replace any start from @patterns by that from @replacement, if any.
      if(my @replacement_start = grep(eqOp($_,'start'),@replacements)){
	@patterns = grep(!eqOp($_,'start'),@patterns); }
      # NOTE: WRONG; need to handle ALL def forms !?!?!?
##      foreach my $def (grep(eqOp($_,'def'),@replacements)){
##	my $symbol = $$def[1];
##	@patterns = grep(!(eqOp($_,'def') && ($$_[1] eq $symbol)),@patterns); }
      foreach my $def (grep( (ref $_ eq 'ARRAY') && ($$_[0] =~ /^def/),@replacements)){
	my($defop,$symbol) = @$def;
	@patterns = grep(!(eqOp($_,$defop) && ($$_[1] eq $symbol)),@patterns); }
      # Recurse on the overridden module
      $self->simplify(['module',"$modname (overridden)",@patterns,@replacements],
		      $binding,$parentbinding,$container); }
    elsif($op eq 'module'){
      my $module = ['module',$name];
      push(@{$$self{modules}},$module);
      push(@$module,map($self->simplify($_,$binding,$parentbinding,$container),@args));
      $module; }
      #	@args; }
    elsif($op eq 'element'){
      @args = map($self->simplify($_,$binding,$parentbinding,"element:$name"),@args);
      my $prev = $$self{elements}{$name};
      $$self{elements}{$name} = ($prev ? [@$prev,@args] : [@args]);
      (['element',$name,@args]); }
    elsif($op eq 'ref'){
      my $qname = $binding.":".$name;
      @args = map($self->simplify($_,$binding,$parentbinding,$container),@args);
      $$self{usesname}{$qname}{$container}=1 if $container;
      (['ref',$qname]); }
    elsif($op eq 'parentref'){
      my $qname = $parentbinding.":".$name;
      @args = map($self->simplify($_,$binding,$parentbinding,$container),@args);
      $$self{usesname}{$qname}{$container}=1 if $container;
      (['ref',$qname]); }
    elsif($op eq 'defchoice'){
      my $qname = $binding.":".$name;
      $$self{usesname}{$qname}{$container}=1 if $container;
      @args = map($self->simplify($_,$binding,$parentbinding,"pattern:$qname"),@args);
      my $prev = $$self{defs}{$qname};
      my @xargs = grep(!eqOp($_,'doc'),@args); # Remove annotations
      $$self{defs}{$qname} = simplifyCombination(['combination','choice',($prev ? $prev : ()),@xargs]);
      ([$op,$qname,@args]); }
    elsif($op eq 'definterleave'){
      my $qname = $binding.":".$name;
      $$self{usesname}{$qname}{$container}=1 if $container;
      @args = map($self->simplify($_,$binding,$parentbinding,"pattern:$qname"),@args);
      my $prev = $$self{defs}{$qname};
      my @xargs = grep(!eqOp($_,'doc'),@args); # Remove annotations
      $$self{defs}{$qname} = simplifyCombination(['combination','interleave',($prev ? $prev : ()),@xargs]);
      ([$op,$qname,@args]); }
    elsif($op eq 'def'){
      my $qname = $binding.":".$name;
      $$self{usesname}{$qname}{$container}=1 if $container;
      @args = map($self->simplify($_,$binding,$parentbinding,"pattern:$qname"),@args);
      if((scalar(@args)==1) && eqOp($args[0],'element')){
	$$self{elementdefs}{$qname} = $args[0][1];
	$$self{elementreversedefs}{$args[0][1]} = $qname;
	@args; }
      else {
	my @xargs = grep(!eqOp($_,'doc'),@args); # Remove annotations
	$$self{defs}{$qname} = (scalar(@xargs) > 1 ? ['combination','group',@xargs] : $xargs[0]);
	([$op,$qname,@args]); }}
    else {
      @args = map($self->simplify($_,$binding,$parentbinding,$container),@args);
      ([$op,$name,@args]); }}
  else {
    $form; }}

sub simplifyCombination {
  my($combination)=@_;
  if((ref $combination) && ($$combination[0] eq 'combination')){
    my($c,$op,@stuff)=@$combination;
    @stuff = map(simplifyCombination($_),@stuff);
    if($op =~ /^(group|choice)$/){ # These can be flattened.
      @stuff=map( ( (ref $_) && ($$_[0] eq 'combination') && ($$_[1] eq $op)
		    ? @$_[2..$#$_] : ($_)),
		  @stuff); }
    [$c,$op,@stuff]; }
  else {
    $combination;}}


#======================================================================
# For debugging...
sub showSchema {
  my($item,$level)=@_;
  $level = 0 unless defined $level;
  if(ref $item eq 'ARRAY'){
    my($op,$name,@args) = @$item;
    if($op eq 'doc'){ $name ="..."; @args = (); }
    print "".(' 'x (2*$level)).$op.($name ? " ".$name :'')."\n";

    foreach my $arg (@args){
      showSchema($arg,$level+1); }}
  else {
    print "".(' 'x (2*$level)).$item."\n"; }}

#======================================================================
# Generate TeX documentation for a Schema
#======================================================================
sub documentModules {
  my($self)=@_;
  my $docs="";
  foreach my $module (@{$$self{modules}}){
    my($op,$name,@content)=@$module;
    $docs = join("\n",$docs,
		 "\\begin{schemamodule}{$name}",
		 map($self->toTeX($_),@content),
		 "\\end{schemamodule}"); }
  $docs; }

sub cleanTeX {
  my($string)=@_;
  return '\typename{text}' if $string eq '#PCDATA';
  $string =~ s/\#/\\#/g;
  $string =~ s/_/\\_/g;
  $string; }

sub toTeX {
  my($self,$object)=@_;
  if(ref $object eq 'HASH'){
    join(', ',map("$_=".$self->toTeX($$object{$_}), sort keys %$object)); }
  elsif(ref $object eq 'ARRAY'){ # an object?
    my($op,$name,@data)=@$object;
    if($op eq 'doc'){
      join(' ',map(cleanTeX($_),@data))."\n"; }
    elsif($op eq 'ref'){
      if(my $el = $$self{elementdefs}{$name}){
	$el =~ s/^ltx://;
	$el = cleanTeX($el);
      "\\elementref{$el}"; }
      else {
	$name =~ s/^\w+://;	# Strip off qualifier!!!! (watch for clash in docs?)
	"\\patternref{".cleanTeX($name)."}"; }}
    elsif($op =~ /^def(choice|interleave|)$/){
      my $combiner   = $1;
      my $qname = $name;
      $name =~ s/^\w+://;	# Strip off qualifier!!!! (watch for clash in docs?)
      $name = cleanTeX($name);
      my($docs,@spec)=$self->toTeXExtractDocs(@data);
      my ($attr,$content) = $self->toTeXBody(@spec);
      if($combiner){
	my $body = $attr;
	$body .= '\item['.($combiner eq 'choice' ? '\textbar=' : '\&=').'] '.$content if $content;
	"\\patternadd{$name}{$docs}{$body}\n";  }
      else {
	$attr = '\item[\textit{Attributes:}] \textit{empty}' if !$attr && ($name =~ /\\_attributes/);
	$content = '\textit{empty}' if !$content && ($name =~ /\\_model/);
	my $body = $attr;
	$body .= '\item[\textit{Content}:] '.$content if $content;
	my($xattr,$xcontent) = $self->toTeXBody($$self{defs}{$qname});
	$body .= '\item[\textit{Expansion}:] '.$xcontent
	  if !$attr && !$xattr && $xcontent && ($xcontent ne $content);
	if($name !~ /_(attributes|model)$/){ # Skip the "used by" if element-specific attributes or moel.
	  if(my $uses = $self->getSymbolUses($qname)){
	    $body .= '\item[\textit{Used by}:] '.$uses; }}
	"\\patterndef{$name}{$docs}{$body}\n"; }}
    elsif($op eq 'element'){
      my $qname = $name;
      $name =~ s/^ltx://;
      $name = cleanTeX($name);
      my($docs,@spec)=$self->toTeXExtractDocs(@data);
      my($attr,$content) = $self->toTeXBody(@spec);
      $content = "\\typename{empty}" unless $content;
      # Shorten display for element-specific attributes & model, ASSUMING they immediately folllow!
      $attr    = '' if $attr    eq '\item[\textit{Attributes}:] \patternref{'.$name.'\\_attributes}';
      $content = '' if $content eq '\patternref{'.$name.'\\_model}';
      my $body = $attr;
      $body .= '\item[\textit{Content}:] '.$content if $content;
      if(my $ename = $$self{elementreversedefs}{$qname}){
	if(my $uses = $self->getSymbolUses($ename)){
	  $body .= '\item[\textit{Used by}:] '.$uses; }}
      "\\elementdef{$name}{$docs}{$body}\n"; }
    elsif($op eq 'attribute'){
      $name = cleanTeX($name);
      my($docs,@spec)=$self->toTeXExtractDocs(@data);
      my $content = join(' ',map($self->toTeX($_),@spec)) || '\typename{text}';
      "\\attrdef{$name}{$docs}{$content}"; }
    elsif($op eq 'combination'){
      if   ($name eq 'group'     ){ "(".join(', ',map($self->toTeX($_),@data)).")"; }
      elsif($name eq 'interleave'){ "(".join(' ~\&~ ',map($self->toTeX($_),@data)).")"; } # ?
      elsif($name eq 'choice'    ){ "(".join(' ~\textbar~ ',map($self->toTeX($_),@data)).")"; }
      elsif($name eq 'optional'  ){
	if((@data == 1) && eqOp($data[0],'attribute')){ $self->toTeX($data[0]); }
	else { $self->toTeX($data[0])."?"; }}
      elsif($name eq 'zeroOrMore'){ $self->toTeX($data[0])."*"; }
      elsif($name eq 'oneOrMore' ){ $self->toTeX($data[0])."+"; }
      elsif($name eq 'list'      ){ "(".join(', ',map($self->toTeX($_),@data)).")"; }} # ?
    elsif($op eq 'data'){ "\\typename{".cleanTeX($data[0])."}"; }
    elsif($op eq 'value'){ '\attrval{'.cleanTeX($data[0])."}"; }
    elsif($op eq 'start'){ 
      my($docs,@spec) = $self->toTeXExtractDocs(@data);
      my $content = join(' ',map($self->toTeX($_),@spec));
      "\\item[\\textit{Start}]\\textbf{==}\\ $content".($docs ? " \\par$docs" :''); }
    elsif($op eq 'grammar'){	# Don't otherwise mention it?
      join("\n",map($self->toTeX($_),@data)); }
    elsif($op eq 'module'){
      '\item[\textit{Module }\moduleref{'.cleanTeX($name).'}] included.'; }
    else {
      warn "RelaxNG->toTeX: Unrecognized item $op";
      "[$op: ".join(', ',map($self->toTeX($_),@data))."]"; }}
  else {
    cleanTeX($object);}}

sub getSymbolUses {
  my($self,$qname)=@_;
  if(my $uses = $$self{usesname}{$qname}){
    my @uses = sort keys %$uses;
    join(', ',
	 map(/^pattern:[^:]*:(.*)$/ ? ('\patternref{'.cleanTeX($1).'}'):(), @uses),
	 map(/^element:[^:]*:(.*)$/ ? ('\elementref{'.cleanTeX($1).'}'):(), @uses)); }
  else { ''; }}

# Extract any documentation nodes from @data
sub toTeXExtractDocs {
  my($self,@data)=@_;
  my $docs="";
  my @rest=();
  while(my $item = shift(@data)){
    if((ref $item eq 'ARRAY') && ($$item[0] eq 'doc')){
      $docs .= $self->toTeX($item); }
    else {
      push(@rest,$item); }}
  ($docs,@rest); }

# Format the attributes & content model of a named pattern or element.
# This generates a sequence of \item's to be put in a definition list.
sub toTeXBody {
  my($self,@data)=@_;
  my(@attributes,@content,@patterns);
  while(my $item = shift(@data)){
    if(ref $item eq 'ARRAY'){
      my($op,$name,@args)=@$item;
      # NOTE: W/o the simplification of optional(attribute), above,
      # we've got to do some extra work here!
      if($op eq 'attribute'){ 
	push(@attributes, $self->toTeX($item)); }
      elsif(($op eq 'combination') && ($name eq 'optional')
	    && (@args == 1) && eqOp($args[0],'attribute')){
	unshift(@data,$args[0]); }
      # Note dubious assumption about naming convention!
      elsif(($op eq 'ref') && ($name =~ /[^a-zA-Z]attributes$/)){
	push(@patterns, $self->toTeX($item)); }
      else { 
	push(@content, $self->toTeX($item)); }}
    else {
      push(@content, $self->toTeX($item)); }}
  (join('',(@patterns
	    ? '\item[\textit{'.(grep($_ !~ /[^a-zA-Z]attributes\}*?$/, @patterns) ? 'Includes' : 'Attributes').'}:] '
	    .   join(', ',@patterns)
	    : ''),
	@attributes),
   join(', ',@content)); }

#======================================================================

#**********************************************************************
1;
