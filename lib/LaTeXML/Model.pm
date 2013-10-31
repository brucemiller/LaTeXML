# /=====================================================================\ #
# |  LaTeXML::Model                                                     | #
# | Stores representation of Document Type for use by Document          | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Model;
use strict;
use LaTeXML::Global;
use LaTeXML::Font;
use LaTeXML::Rewrite;
use LaTeXML::Common::XML;
use LaTeXML::Util::Pathname;
use base qw(LaTeXML::Object);

#**********************************************************************
our($STD_PUBLIC_ID,$STD_SYSTEM_ID)=("-//NIST LaTeXML//LaTeXML article",'LaTeXML.dtd');
our $LTX_NAMESPACE = "http://dlmf.nist.gov/LaTeXML";
sub new {
  my($class,%options)=@_;
  my $self = bless {xpath=> LaTeXML::Common::XML::XPath->new(),
		    code_namespace_prefixes=>{}, code_namespaces=>{}, 
		    doctype_namespaces=>{},
		    rewrites=>[], ligatures=>[], mathligatures=>[],
		    %options},$class;
  $$self{xpath}->registerFunction('match-font',\&LaTeXML::Font::match_font);
  $self->registerNamespace('xml',"http://www.w3.org/XML/1998/namespace");
  $self; }

sub setDocType {
  my($self,$roottag,$publicid,$systemid)=@_;
  $$self{schemadata}=['DTD',$roottag,$publicid,$systemid]; }

sub setRelaxNGSchema {
  my($self,$schema)=@_;
  $$self{schemadata}=['RelaxNG',$schema]; }

sub loadSchema {
  my($self)=@_;
  return $$self{schema} if $$self{schema_loaded};
  my $name;

  if(!$$self{schemadata}){
    Warn('expected','<model>',undef,"No Schema Model has been declared; assuming LaTeXML");
    # article ??? or what ? undef gives problems!
    $self->setRelaxNGSchema("LaTeXML");
    $self->registerNamespace(ltx=>$LTX_NAMESPACE);
    $self->registerNamespace(svg=>"http://www.w3.org/2000/svg");
    $self->registerNamespace(xlink=>"http://www.w3.org/1999/xlink"); # Needed for SVG
    $self->registerNamespace(m=>"http://www.w3.org/1998/Math/MathML");
    $self->registerNamespace(xhtml=>"http://www.w3.org/1999/xhtml");
    $$self{permissive}=1; }	# Actually, they could have declared all sorts of Tags....

  my($type,@data)=@{$$self{schemadata}};
  if($type eq 'DTD'){
    my($roottag,$publicid,$systemid)=@data;
    require LaTeXML::Model::DTD;
    $name = $systemid;
    $$self{schema} = LaTeXML::Model::DTD->new($self,$roottag,$publicid,$systemid); }
  elsif($type eq 'RelaxNG'){
    ($name)=@data;
    require LaTeXML::Model::RelaxNG;
    $$self{schema} = LaTeXML::Model::RelaxNG->new($self,$name); }

  if(my $compiled = !$$self{no_compiled}
     && pathname_find($name, paths=>$STATE->lookupValue('SEARCHPATHS'),
		      types=>['model'], installation_subdir=>"resources/$type")){
    $self->loadCompiledSchema($compiled); }
  else {
    $$self{schema}->loadSchema; }
  $self->computeIndirect;
  $self->describeModel if $LaTeXML::Model::DEBUG;
  $$self{schema_loaded}=1;
  $$self{schema}; }

sub addSchemaDeclaration {
  my($self,$document,$tag)=@_;
  $$self{schema}->addSchemaDeclaration($document,$tag); }

#=====================================================================
# Make provision to precompile the schema.
sub compileSchema {
  my($self)=@_;
  $$self{no_compiled}=1;
  $self->loadSchema;
  foreach my $prefix (keys %{$$self{document_namespaces}}){
    print $prefix.'='.$$self{document_namespaces}{$prefix}."\n"; }
  if(my $defs = $$self{schemaclass}){
    foreach my $classname (keys %$defs){
      print $classname.':=('.join(',', sort keys %{$$self{schemaclass}{$classname}}).')'."\n"; }}
  foreach my $tag (keys %{$$self{tagprop}}){
    print $tag
      .'{'.join(',',sort keys %{$$self{tagprop}{$tag}{attributes}}).'}'
      .'('.join(',',sort keys %{$$self{tagprop}{$tag}{model}}).')'."\n"; }}

sub loadCompiledSchema {
  my($self,$file)=@_;
  NoteBegin("Loading compiled schema $file");
  my $MODEL;
  open($MODEL,'<',$file) or Fatal('I/O',$file,undef,"Cannot open Compiled Model $file for reading",$!);
  my $line;
  while($line = <$MODEL>){
    if($line =~ /^([^\{]+)\{(.*?)\}\((.*?)\)$/){
      my($tag,$attr,$children)=($1,$2,$3);
      $self->setTagProperty($tag,'attributes',{map(($_=>1),split(/,/,$attr))});
      $self->setTagProperty($tag,'model',{map(($_=>1),split(/,/,$children))}); }
    elsif($line =~ /^([^:=]+):=(.*?)$/){
      my($classname,$elements)=($1,$2);
      $self->setSchemaClass($classname,{map(($_=>1),split(/,/,$elements))}); }
    elsif($line =~ /^([^=]+)=(.*?)$/){
      my($prefix,$namespace)=($1,$2);
      $self->registerDocumentNamespace($prefix,$namespace); }
    else {
      Fatal('internal',$file,undef,"Compiled model '$file' is malformatted at \"$line\""); }
  }
  close($MODEL);
  NoteEnd("Loading compiled schema $file"); }


#**********************************************************************
# Namespaces
#**********************************************************************
# There are TWO namespace mappings!!!
# One for coding, one for the DocType.
#
# Coding: this namespace mapping associates prefixes to namespace URIs for
#   use in the latexml code, constructors and such.
#   This must be a one to one mapping and there are no default namespaces.
# Document: this namespace mapping associates prefixes to namespace URIs
#   as used in the generated document, and will be the
#   set of prefixes used in the generated output.
#   This mapping may also use a prefix of "#default" which is for
#   the unprefixed form of elements (not used for attributes!)
sub registerNamespace {
  my($self,$codeprefix,$namespace)=@_;
  if($namespace){
    $$self{code_namespace_prefixes}{$namespace}=$codeprefix;
    $$self{code_namespaces}{$codeprefix}=$namespace;
    $$self{xpath}->registerNS($codeprefix,$namespace); }
  else {
    my $prev = $$self{code_namespaces}{$codeprefix};
    delete $$self{code_namespace_prefixes}{$prev} if $prev;
    delete $$self{code_namespaces}{$codeprefix}; }}

our $NAMESPACE_ERROR=0;

# In the following:
#    $forattribute is 1 if the namespace is for an attribute (in which case, there must be a non-empty prefix)
#    $probe, if non 0, just test for namespace, without creating an entry if missing.
# Get the (code) prefix associated with $namespace,
# creating a dummy prefix and signalling an error if none has been registered.
sub getNamespacePrefix {
  my($self,$namespace,$forattribute,$probe)=@_;
  if($namespace){
    my $codeprefix = $$self{code_namespace_prefixes}{$namespace};
    if((! defined $codeprefix) && !$probe){
      $self->registerNamespace($codeprefix = "namespace".(++$NAMESPACE_ERROR), $namespace);
      Warn('malformed',$namespace,undef,
	   "No prefix has been registered for namespace '$namespace' (in code)",
	   "Using '$codeprefix' instead"); }
    $codeprefix; }}

sub getNamespace {
  my($self,$codeprefix,$probe)=@_;
  my $ns = $$self{code_namespaces}{$codeprefix};
  if((! defined $ns) && !$probe){
    $self->registerNamespace($codeprefix,
			     $ns = "http://example.com/namespace".(++$NAMESPACE_ERROR));
    Error('malformed',$codeprefix,undef,
	  "No namespace has been registered for prefix '$codeprefix' (in code)",
	  "Using '$ns' isntead"); }
  $ns; }

sub registerDocumentNamespace {
  my($self,$docprefix,$namespace)=@_;
  $docprefix = '#default' unless defined $docprefix;
  if($namespace){
    # Since the default namespace url can still ALSO have a prefix associated,
    # we prepend "DEFAULT#url" when using as a hash key in the prefixes table.
    my $regnamespace = ($docprefix eq '#default' ? "DEFAULT#".$namespace : $namespace);
    $$self{document_namespace_prefixes}{$regnamespace}=$docprefix;
    $$self{document_namespaces}{$docprefix}=$namespace; }
  else {
    my $prev = $$self{document_namespaces}{$docprefix};
    delete $$self{document_namespace_prefixes}{$prev} if $prev;
    delete $$self{document_namespaces}{$docprefix}; }}

sub getDocumentNamespacePrefix {
  my($self,$namespace,$forattribute,$probe)=@_;
  if($namespace){
    # Get the prefix associated with the namespace url, noting that for elements, it might by "#default",
    # but for attributes would never be.
    my $docprefix = (!$forattribute && $$self{document_namespace_prefixes}{"DEFAULT#".$namespace})
      || $$self{document_namespace_prefixes}{$namespace};
    if((! defined $docprefix) && !$probe){
      $self->registerDocumentNamespace($docprefix = "namespace".(++$NAMESPACE_ERROR), $namespace);
      Warn('malformed',$namespace,undef,
	   "No prefix has been registered for namespace '$namespace' (in document)",
	   "Using '$docprefix' instead"); }
    (($docprefix||'#default') eq '#default' ? '' : $docprefix); }}

sub getDocumentNamespace {
  my($self,$docprefix,$probe)=@_;
  $docprefix = '#default' unless defined $docprefix;
  my $ns = $$self{document_namespaces}{$docprefix};
  $ns =~ s/^DEFAULT#// if $ns;		# Remove the default hack, if present!
  if(($docprefix ne '#default') && (! defined $ns) && !$probe){
    $self->registerDocumentNamespace($docprefix,
				     $ns = "http://example.com/namespace".(++$NAMESPACE_ERROR));
    Error('malformed',$docprefix,undef,
	  "No namespace has been registered for prefix '$docprefix' (in document)",
	  "Using '$ns' instead"); }
  $ns; }

# Given a Qualified name, possibly prefixed with a namespace prefix,
# as defined by the code namespace mapping,
# return the NamespaceURI and localname.
sub decodeQName {
  my($self,$codetag)=@_;
  if($codetag =~ /^([^:]+):(.+)$/){
    my($prefix,$localname)=($1,$2);
    return (undef, $codetag) if $prefix eq 'xml';
    ($self->getNamespace($prefix), $localname); }
  else {
    (undef, $codetag); }}

sub encodeQName {
  my($self,$ns,$name)=@_;
  my $codeprefix = $ns && $self->getNamespacePrefix($ns);
  ($codeprefix ? "$codeprefix:$name" : $name); }

# Get the node's qualified name in standard form
# Ie. using the registered (code) prefix for that namespace.
# NOTE: Reconsider how _Capture_ & _WildCard_ should be integrated!?!
sub getNodeQName {
  my($self,$node)=@_;
  my $type = $node->nodeType;
  if($type == XML_TEXT_NODE){
    '#PCDATA'; }
  elsif($type == XML_DOCUMENT_NODE){
    '#Document'; }
  elsif($type == XML_COMMENT_NODE){
    '#Comment'; }
  elsif($type == XML_PI_NODE){
    '#ProcessingInstruction'; }
  elsif($type == XML_DTD_NODE){
    '#DTD'; }
  # Need others?
  elsif(($type != XML_ELEMENT_NODE) && ($type != XML_ATTRIBUTE_NODE)){
    Fatal('misdefined','<caller>',undef,
	  "Should not ask for Qualified Name for node of type $type: ".Stringify($node)); }
  elsif(my $ns = $node->namespaceURI){
    $self->getNamespacePrefix($ns) .":". $node->localname; }
  else {
    $node->localname; }}

# Given a Document QName, convert to "code" form
# Used to convert a possibly prefixed name from the DTD
# (using the DTD's prefixes)
# into a prefixed name using the Code's prefixes
# NOTE: Used only for DTD
sub recodeDocumentQName {
  my($self,$docQName)=@_;
  my($docprefix,$name)=(undef,$docQName);
  if($docQName =~ /^(#PCDATA|#Comment|ANY|#ProcessingInstruction|#Document)$/){
    $docQName; }
  else {
    ($docprefix,$name) = ($1,$2)  if $docQName =~ /^([^:]+):(.+)/;
    $self->encodeQName($self->getDocumentNamespace($docprefix),$name); }}

# Get an XPath context that knows about our namespace mappings.
sub getXPath { $_[0]->{xpath}; }

#**********************************************************************
# Accessors
#**********************************************************************

sub setTagProperty {
  my($self,$tag,$property,$value)=@_;
  $$self{tagprop}{$tag}{$property}=$value; }

sub getTagProperty {
  my($self,$tag,$prop)=@_;
  $tag = $self->getNodeQName($tag) if ref $tag; # In case tag is a node.
####  $$self{tagprop}{$tag}{$prop}; }
  my($p,$n)=$self->decodeQName($tag);
  my $v;
  (defined ($v=$$self{tagprop}{$tag}{$prop}) ? $v
   : (defined $p && defined ($v=$$self{tagprop}{$p.":*"}{$prop}) ? $v
      : (defined ($v=$$self{tagprop}{"*"}{$prop}) ? $v
	 : undef))); }

sub getTagPropertyList {
  my($self,$tag,$prop)=@_;
  $tag = $self->getNodeQName($tag) if ref $tag; # In case tag is a node.
  my($p,$n)=(undef,$tag);
  if($tag =~ /^([^:]+):(.+)$/){
    ($p,$n)=($1,$2); }
  my $prop0 = $prop.':early';
  my $prop1 = $prop.':late';
  my $taghash = $$self{tagprop}{$tag};
  my $nshash = (defined $p) && $$self{tagprop}{$p.":*"};
  my $allhash = $$self{tagprop}{"*"};
  my $v;
  (
   ($taghash && defined ($v=$$taghash{$prop0}) ? @$v : ()),
   ($nshash  && defined ($v=$$nshash{$prop0}) ? @$v : ()),
   ($allhash && defined ($v=$$allhash{$prop0}) ? @$v : ()),
   ($taghash && defined ($v=$$taghash{$prop}) ? @$v : ()),
   ($nshash  && defined ($v=$$nshash{$prop}) ? @$v : ()),
   ($allhash && defined ($v=$$allhash{$prop}) ? @$v : ()),
   ($taghash && defined ($v=$$taghash{$prop1}) ? @$v : ()),
   ($nshash  && defined ($v=$$nshash{$prop1}) ? @$v : ()),
   ($allhash && defined ($v=$$allhash{$prop1}) ? @$v : ()),
  ); }

sub setSchemaClass {
  my($self,$classname,$content)=@_;
  $$self{schemaclass}{$classname}=$content; }

#**********************************************************************
# Document Structure Queries
#**********************************************************************
# NOTE: These are public, but perhaps should be passed
# to submodel, in case it can evolve to more precision?
# However, it would need more context to do that.

# Can an element with (qualified name) $tag contain a $childtag element?
sub canContain {
  my($self,$tag,$childtag)=@_;
  $self->loadSchema unless $$self{schema_loaded};
  $tag      = $self->getNodeQName($tag)      if ref $tag; # In case tag is a node.
  $childtag = $self->getNodeQName($childtag) if ref $childtag; # In case tag is a node.
  # Handle obvious cases explicitly.
  return 0 if $tag eq '#PCDATA';
  return 0 if $tag eq '#Comment';
  return 1 if $tag =~ /(.*?:)?_Capture_$/; # with or without namespace prefix
  return 1 if $tag eq '_WildCard_';
  return 1 if $childtag =~ /(.*?:)?_Capture_$/;
  return 1 if $childtag eq '_WildCard_';
  return 1 if $childtag eq '#Comment';
  return 1 if $childtag eq '#ProcessingInstruction';
  return 1 if $childtag eq '#DTD';
#  return 1 if $$self{permissive}; # No DTD? Punt!
  return 1 if $$self{permissive} && ($tag eq '#Document') && ($childtag ne '#PCDATA'); # No DTD? Punt!
  # Else query tag properties.
  my $model = $$self{tagprop}{$tag}{model};
  $$model{ANY} || $$model{$childtag}; }

# Can an element with (qualified name) $tag contain a $childtag element indirectly?
# That is, by openning some number of autoOpen'able tags?
# And if so, return the tag to open.
sub canContainIndirect {
  my($self,$tag,$childtag)=@_;
  $self->loadSchema unless $$self{schema_loaded};
  $tag      = $self->getNodeQName($tag)      if ref $tag; # In case tag is a node.
  $childtag = $self->getNodeQName($childtag) if ref $childtag; # In case tag is a node.
  $$self{tagprop}{$tag}{indirect_model}{$childtag}; }

sub canContainSomehow {
  my($self,$tag,$childtag)=@_;
  $tag      = $self->getNodeQName($tag)      if ref $tag; # In case tag is a node.
  $childtag = $self->getNodeQName($childtag) if ref $childtag; # In case tag is a node.
  $self->canContain($tag,$childtag) ||  $self->canContainIndirect($tag,$childtag); }

# Can this node be automatically closed, if needed?
sub canAutoClose {
  my($self,$tag)=@_;
  $self->loadSchema unless $$self{schema_loaded};
  $tag = $self->getNodeQName($tag) if ref $tag; # In case tag is a node.
  return 1 if $tag eq '#PCDATA';
  return 1 if $tag eq '#Comment';
  $$self{tagprop}{$tag}{autoClose}; }

sub canHaveAttribute {
  my($self,$tag,$attrib)=@_;
  $self->loadSchema unless $$self{schema_loaded};
  $tag = $self->getNodeQName($tag) if ref $tag; # In case tag is a node.
  return 0 if $tag eq '#PCDATA';
  return 0 if $tag eq '#Comment';
  return 0 if $tag eq '#Document';
  return 0 if $tag eq '#ProcessingInstruction';
  return 0 if $tag eq '#DTD';
  return 1 if $$self{permissive};
  $$self{tagprop}{$tag}{attributes}{$attrib}; }

sub isInSchemaClass {
  my($self,$classname,$tag)=@_;
  $tag = $self->getNodeQName($tag) if ref $tag; # In case tag is a node.
  my $class = $$self{schemaclass}{$classname};
  $class && $$class{$tag}; }

#**********************************************************************
# Support for filling in the model from a Schema.
sub computeIndirect {
  my($self)=@_;
  # Determine any indirect paths to each descendent via an `autoOpen-able' tag.
  foreach my $tag (keys %{$$self{tagprop}}){
    if($$self{tagprop}{$tag}{model}){
      local %::DESC=();
      computeDescendents($self,$tag,''); 
      $$self{tagprop}{$tag}{indirect_model}={%::DESC}; }}
  # PATCHUP
  if($$self{permissive}){
    $$self{tagprop}{'#Document'}{indirect_model}{'#PCDATA'}='ltx:p'; }
}

sub computeDescendents {
  my($self,$tag,$start)=@_;
  foreach my $kid (keys %{$$self{tagprop}{$tag}{model}}){
    next if $::DESC{$kid};
    $::DESC{$kid}=$start if $start;
    if(($kid ne '#PCDATA') && $$self{tagprop}{$kid}{autoOpen}){
      computeDescendents($self,$kid,$start||$kid); }
  }
}

sub describeModel {
  my($self)=@_;
  print STDERR "Doctype\n";
  foreach my $tag (sort keys %{$$self{tagprop}}){
    if(my $model = $$self{tagprop}{$tag}{model}){
      if(keys %$model){
	print STDERR "$tag can contain ".join(', ',sort keys %{$$self{tagprop}{$tag}{model}})."\n";}
      if(my $indirect = $$self{tagprop}{$tag}{indirect_model}){
	print STDERR "$tag can indirectly contain ". join(', ',sort keys %$indirect)."\n"
	  if keys %$indirect; }}
      else {
	print STDERR "$tag is empty\n"; }
  }}

#**********************************************************************
sub addLigature {
  my($self,$regexp,%options)=@_;
  my $code =  "sub { \$_[0] =~ s${regexp}g; }";
  my $fcn = eval $code;
  Error('misdefined',$regexp,undef,
	"Failed to compile regexp pattern '$regexp' into \"$code\"",$!) if $@;
  unshift(@{$$self{ligatures}}, { regexp=>$regexp, code=>$fcn, %options}); }

sub getLigatures {
  my($self)=@_;
  @{$$self{ligatures}}; }

sub addMathLigature {
  my($self,$matcher,%options)=@_;
  unshift(@{$$self{mathligatures}}, { matcher=>$matcher,%options}); }

sub getMathLigatures {
  my($self)=@_;
  @{$$self{mathligatures}}; }

#**********************************************************************
# Rewrite Rules

sub addRewriteRule {
  my($self,$mode,@specs)=@_;
  push(@{$$self{rewrites}},LaTeXML::Rewrite->new($mode,@specs)); }

# This adds the rule to the front.
# We probably need a more powerful ordering scheme?
sub prependRewriteRule {
  my($self,$mode,@specs)=@_;
  unshift(@{$$self{rewrites}},LaTeXML::Rewrite->new($mode,@specs)); }

# Why is this in this class?
sub applyRewrites {
  my($self,$document,$node, $until_rule)=@_;
  foreach my $rule (@{$$self{rewrites}}){
    last if $until_rule && ($rule eq $until_rule);
    $rule->rewrite($document,$node); }}


#**********************************************************************
package LaTeXML::Model::Schema;

sub new {
  my($class)=@_;
  bless {},$class; }

sub addSchemaDeclaration {
  my($self,$xmldocument,$tag)=@_;
}

#**********************************************************************
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Model> - represents the Document Model

=head1 DESCRIPTION

C<LaTeXML::Model> encapsulates information about the document model to be used
in converting a digested document into XML by the L<LaTeXML::Document>.
This information is based on the document schema (eg, DTD, RelaxNG),
but is also modified by package modules; thus the model may not be
complete until digestion is completed.

The kinds of information that is relevant is not only the content model
(what each element can contain contain), but also SGML-like information
such as whether an element can be implicitly opened or closed, if needed
to insert a new element into the document.

Currently, only an approximation to the schema is understood and used.
For example, we only record that certain elements can appear within another;
we don't preserve any information about required order or number of instances.

=head2 Model Creation

=over 4

=item C<< $model = LaTeXML::Model->new(%options); >>

Creates a new model.  The only useful option is
C<< permissive=>1 >> which ignores any DTD and allows the
document to be built without following any particular content model.

=back

=head2 Document Type

=over 4

=item C<< $model->setDocType($rootname,$publicid,$systemid,%namespaces); >>

Declares the expected rootelement, the public and system ID's of the document type
to be used in the final document.  The hash C<%namespaces> specifies
the namespace prefixes that are expected to be found in the DTD, along with
the associated namespace URI.  These prefixes may be different from
the prefixes used in implementation code (eg. in ltxml files; see RegisterNamespace).
The generated document will use the namespaces and prefixes defined here.

=back

=head2 Namespaces

Note that there are I<two> namespace mappings between namespace URIs and prefixes
that are relevant to L<LaTeXML>.
The `code' mapping is the one used in code implementing packages, and in
particular, constructors defined within those packages.  The prefix C<ltx>
is used consistently to refer to L<LaTeXML>'s own namespace
(C<http://dlmf.nist.gov/LaTeXML)>. 

The other mapping, the `document' mapping, is used in the created document;
this may be different from the `code' mapping in order to accommodate
DTDs, for example, or for use by other applications that expect
a rigid namespace mapping.

=over 4

=item C<< $model->registerNamespace($prefix,$namespace_url); >>

Register C<$prefix> to stand for the namespace C<$namespace_url>.
This prefix can then be used to create nodes in constructors and Document methods.
It will also be recognized in XPath expressions.

=item C<< $model->getNamespacePrefix($namespace,$forattribute,$probe); >>

Return the prefix to use for the given C<$namespace>.
If C<$forattribute> is nonzero, then it looks up the prefix as appropriate for attributes.
If C<$probe> is nonzero, it only probes for the prefix, without creating a missing entry.

=item C<< $model->getNamespace($prefix,$probe); >>

Return the namespace url for the given C<$prefix>.

=back

=head2 Model queries

=over 2

=item C<< $boole = $model->canContain($tag,$childtag); >>

Returns whether an element with qualified name C<$tag> can contain an element 
with qualified name C<$childtag>.
The tag names #PCDATA, #Document, #Comment and #ProcessingInstruction
are specially recognized.

=item C<< $auto = $model->canContainIndirect($tag,$childtag); >>

Checks whether an element with qualified name C<$tag> could contain an element
with qualified name C<$childtag>, provided an `autoOpen'able element C<$auto> 
were inserted in C<$tag>.

=item C<< $boole = $model->canContainSomehow($tag,$childtag); >>

Returns whether an element with qualified name C<$tag> could contain an element
with qualified name C<$childtag>, either directly or indirectly.

=item C<< $boole = $model->canAutoClose($tag); >>

Returns whether an element with qualified name C<$tag> is allowed to be closed automatically,
if needed.

=item C<< $boole = $model->canHaveAttribute($tag,$attribute); >>

Returns whether an element with qualified name C<$tag> is allowed to have an attribute
with the given name.

=back

=head2 Tag Properties

=over 2

=item C<< $value = $model->getTagProperty($tag,$property); >>

Gets the value of the $property associated with the qualified name C<$tag>
Known properties are:

 autoOpen   : This asserts that the tag is allowed to
              be opened automatically if needed to
              insert some other element.  If not set,
              the tag can only be opened explicitly.
 autoClose  : This asserts that the $tag is allowed to
              be closed automatically if needed to
              insert some other element.  If not set,
              the tag can only be closed explicitly.
 afterOpen  : supplies code to be executed whenever
              an element of this type is opened. It
              is called with the created node and the
              responsible digested object as arguments.
 afterClose : supplies code to be executed whenever
              an element of this type is closed.  It
              is called with the created node and the
              responsible digested object as arguments.

=item C<< $model->setTagProperty($tag,$property,$value); >>

sets the value of the C<$property> associated with the qualified name C<$tag> to C<$value>.

=back

=head2 Rewrite Rules

=over 2

=item C<< $model->addRewriteRule($mode,@specs); >>

Install a new rewrite rule with the given C<@specs> to be used 
in C<$mode> (being either C<math> or C<text>).
See L<LaTeXML::Rewrite> for a description of the specifications.

=item C<< $model->applyRewrites($document,$node,$until_rule); >>

Apply all matching rewrite rules to C<$node> in the given document.
If C<$until_rule> is define, apply all those rules that were defined
before it, otherwise, all rules

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
