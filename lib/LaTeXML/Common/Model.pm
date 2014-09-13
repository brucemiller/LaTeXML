# /=====================================================================\ #
# |  LaTeXML::Common::Model                                             | #
# | Stores representation of Document Type for use by Document          | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Model;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Common::Font;
use LaTeXML::Common::XML;
use LaTeXML::Util::Pathname;
use base qw(LaTeXML::Common::Object);

#**********************************************************************
my $LTX_NAMESPACE = "http://dlmf.nist.gov/LaTeXML";    # [CONSTANT]

sub new {
  my ($class, %options) = @_;
  my $self = bless { xpath => LaTeXML::Common::XML::XPath->new(),
    code_namespace_prefixes => {}, code_namespaces => {},
    doctype_namespaces      => {},
    namespace_errors        => 0,
    %options }, $class;
  $$self{xpath}->registerFunction('match-font', \&LaTeXML::Common::Font::match_font);
  $self->registerNamespace('xml', "http://www.w3.org/XML/1998/namespace");
  return $self; }

sub setDocType {
  my ($self, $roottag, $publicid, $systemid) = @_;
  $$self{schemadata} = ['DTD', $roottag, $publicid, $systemid];
  return; }

sub setRelaxNGSchema {
  my ($self, $schema) = @_;
  $$self{schemadata} = ['RelaxNG', $schema];
  return; }

sub loadSchema {
  my ($self) = @_;
  return $$self{schema} if $$self{schema_loaded};
  my $name;

  if (!$$self{schemadata}) {
    Warn('expected', '<model>', undef, "No Schema Model has been declared; assuming LaTeXML");
    # article ??? or what ? undef gives problems!
    $self->setRelaxNGSchema("LaTeXML");
    $self->registerNamespace(ltx   => $LTX_NAMESPACE);
    $self->registerNamespace(svg   => "http://www.w3.org/2000/svg");
    $self->registerNamespace(xlink => "http://www.w3.org/1999/xlink");         # Needed for SVG
    $self->registerNamespace(m     => "http://www.w3.org/1998/Math/MathML");
    $self->registerNamespace(xhtml => "http://www.w3.org/1999/xhtml");
    $$self{permissive} = 1; }    # Actually, they could have declared all sorts of Tags....

  my ($type, @data) = @{ $$self{schemadata} };
  if ($type eq 'DTD') {
    my ($roottag, $publicid, $systemid) = @data;
    require LaTeXML::Common::Model::DTD;
    $name = $systemid;
    $$self{schema} = LaTeXML::Common::Model::DTD->new($self, $roottag, $publicid, $systemid); }
  elsif ($type eq 'RelaxNG') {
    ($name) = @data;
    require LaTeXML::Common::Model::RelaxNG;
    $$self{schema} = LaTeXML::Common::Model::RelaxNG->new($self, $name); }

  if (my $compiled = !$$self{no_compiled}
    && pathname_find($name, paths => $STATE->lookupValue('SEARCHPATHS'),
      types => ['model'], installation_subdir => "resources/$type")) {
    $self->loadCompiledSchema($compiled); }
  else {
    $$self{schema}->loadSchema; }
  $self->describeModel if $LaTeXML::Common::Model::DEBUG;
  $$self{schema_loaded} = 1;
  return $$self{schema}; }

sub addSchemaDeclaration {
  my ($self, $document, $tag) = @_;
  $$self{schema}->addSchemaDeclaration($document, $tag);
  return; }

#=====================================================================
# Make provision to precompile the schema.
sub compileSchema {
  my ($self) = @_;
  $$self{no_compiled} = 1;
  $self->loadSchema;
  foreach my $prefix (sort keys %{ $$self{document_namespaces} }) {
    print $prefix. '=' . $$self{document_namespaces}{$prefix} . "\n"; }
  if (my $defs = $$self{schemaclass}) {
    foreach my $classname (sort keys %$defs) {
      print $classname. ':=(' . join(',', sort keys %{ $$self{schemaclass}{$classname} }) . ')' . "\n"; } }
  foreach my $tag (sort keys %{ $$self{tagprop} }) {
    print $tag
      . '{' . join(',', sort keys %{ $$self{tagprop}{$tag}{attributes} }) . '}'
      . '(' . join(',', sort keys %{ $$self{tagprop}{$tag}{model} }) . ')' . "\n"; }
  return; }

sub loadCompiledSchema {
  my ($self, $file) = @_;
  NoteBegin("Loading compiled schema $file");
  my $MODEL;
  open($MODEL, '<', $file) or Fatal('I/O', $file, undef, "Cannot open Compiled Model $file for reading", $!);
  my $line;
  while ($line = <$MODEL>) {
    if ($line =~ /^([^\{]+)\{(.*?)\}\((.*?)\)$/) {
      my ($tag, $attr, $children) = ($1, $2, $3);
      $self->addTagAttribute($tag, split(/,/, $attr));
      $self->addTagContent($tag, split(/,/, $children)); }

    elsif ($line =~ /^([^:=]+):=(.*?)$/) {
      my ($classname, $elements) = ($1, $2);
      $self->setSchemaClass($classname, { map { ($_ => 1) } split(/,/, $elements) }); }
    elsif ($line =~ /^([^=]+)=(.*?)$/) {
      my ($prefix, $namespace) = ($1, $2);
      $self->registerDocumentNamespace($prefix, $namespace); }
    else {
      Fatal('internal', $file, undef, "Compiled model '$file' is malformatted at \"$line\""); }
  }
  close($MODEL);
  NoteEnd("Loading compiled schema $file");
  return; }

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
  my ($self, $codeprefix, $namespace) = @_;
  if ($namespace) {
    $$self{code_namespace_prefixes}{$namespace} = $codeprefix;
    $$self{code_namespaces}{$codeprefix}        = $namespace;
    $$self{xpath}->registerNS($codeprefix, $namespace); }
  else {
    my $prev = $$self{code_namespaces}{$codeprefix};
    delete $$self{code_namespace_prefixes}{$prev} if $prev;
    delete $$self{code_namespaces}{$codeprefix}; }
  return; }

# In the following:
#    $forattribute is 1 if the namespace is for an attribute (in which case, there must be a non-empty prefix)
#    $probe, if non 0, just test for namespace, without creating an entry if missing.
# Get the (code) prefix associated with $namespace,
# creating a dummy prefix and signalling an error if none has been registered.
sub getNamespacePrefix {
  my ($self, $namespace, $forattribute, $probe) = @_;
  if ($namespace) {
    my $codeprefix = $$self{code_namespace_prefixes}{$namespace};
    if ((!defined $codeprefix) && !$probe) {
      my $docprefix = $$self{document_namespace_prefixes}{$namespace};
      # if there's a doc prefix and it's NOT already used in code namespace mapping
      if ($docprefix && !$$self{code_namespaces}{$docprefix}) {
        $codeprefix = $docprefix; }
      else {    # Else synthesize one
        $codeprefix = "namespace" . (++$$self{namespace_errors}); }
      $self->registerNamespace($codeprefix, $namespace);
      Warn('malformed', $namespace, undef,
        "No prefix has been registered for namespace '$namespace' (in code)",
        "Using '$codeprefix' instead"); }
    return $codeprefix; } }

sub getNamespace {
  my ($self, $codeprefix, $probe) = @_;
  my $ns = $$self{code_namespaces}{$codeprefix};
  if ((!defined $ns) && !$probe) {
    $self->registerNamespace($codeprefix,
      $ns = "http://example.com/namespace" . (++$$self{namespace_errors}));
    Error('malformed', $codeprefix, undef,
      "No namespace has been registered for prefix '$codeprefix' (in code)",
      "Using '$ns' isntead"); }
  return $ns; }

sub registerDocumentNamespace {
  my ($self, $docprefix, $namespace) = @_;
  $docprefix = '#default' unless defined $docprefix;
  if ($namespace) {
    # Since the default namespace url can still ALSO have a prefix associated,
    # we prepend "DEFAULT#url" when using as a hash key in the prefixes table.
    my $regnamespace = ($docprefix eq '#default' ? "DEFAULT#" . $namespace : $namespace);
    $$self{document_namespace_prefixes}{$regnamespace} = $docprefix;
    $$self{document_namespaces}{$docprefix}            = $namespace; }
  else {
    my $prev = $$self{document_namespaces}{$docprefix};
    delete $$self{document_namespace_prefixes}{$prev} if $prev;
    delete $$self{document_namespaces}{$docprefix}; }
  return; }

sub getDocumentNamespacePrefix {
  my ($self, $namespace, $forattribute, $probe) = @_;
  if ($namespace) {
   # Get the prefix associated with the namespace url, noting that for elements, it might by "#default",
   # but for attributes would never be.
    my $docprefix = (!$forattribute && $$self{document_namespace_prefixes}{ "DEFAULT#" . $namespace })
      || $$self{document_namespace_prefixes}{$namespace};
    if ((!defined $docprefix) && !$probe) {
      $self->registerDocumentNamespace($docprefix = "namespace" . (++$$self{namespace_errors}), $namespace);
      Warn('malformed', $namespace, undef,
        "No prefix has been registered for namespace '$namespace' (in document)",
        "Using '$docprefix' instead"); }
    return (($docprefix || '#default') eq '#default' ? '' : $docprefix); } }

sub getDocumentNamespace {
  my ($self, $docprefix, $probe) = @_;
  $docprefix = '#default' unless defined $docprefix;
  my $ns = $$self{document_namespaces}{$docprefix};
  $ns =~ s/^DEFAULT#// if $ns;    # Remove the default hack, if present!
  if (($docprefix ne '#default') && (!defined $ns) && !$probe) {
    $self->registerDocumentNamespace($docprefix,
      $ns = "http://example.com/namespace" . (++$$self{namespace_errors}));
    Error('malformed', $docprefix, undef,
      "No namespace has been registered for prefix '$docprefix' (in document)",
      "Using '$ns' instead"); }
  return $ns; }

# Given a Qualified name, possibly prefixed with a namespace prefix,
# as defined by the code namespace mapping,
# return the NamespaceURI and localname.
sub decodeQName {
  my ($self, $codetag) = @_;
  if ($codetag =~ /^([^:]+):(.+)$/) {
    my ($prefix, $localname) = ($1, $2);
    return (undef, $codetag) if $prefix eq 'xml';
    return ($self->getNamespace($prefix), $localname); }
  else {
    return (undef, $codetag); } }

sub encodeQName {
  my ($self, $ns, $name) = @_;
  my $codeprefix = $ns && $self->getNamespacePrefix($ns);
  return ($codeprefix ? "$codeprefix:$name" : $name); }

# Get the node's qualified name in standard form
# Ie. using the registered (code) prefix for that namespace.
# NOTE: Reconsider how _Capture_ & _WildCard_ should be integrated!?!
sub getNodeQName {
  my ($self, $node) = @_;
  my $type = $node->nodeType;
  if ($type == XML_TEXT_NODE) {
    return '#PCDATA'; }
  elsif ($type == XML_DOCUMENT_NODE) {
    return '#Document'; }
  elsif ($type == XML_COMMENT_NODE) {
    return '#Comment'; }
  elsif ($type == XML_PI_NODE) {
    return '#ProcessingInstruction'; }
  elsif ($type == XML_DTD_NODE) {
    return '#DTD'; }
  # Need others?
  elsif (($type != XML_ELEMENT_NODE) && ($type != XML_ATTRIBUTE_NODE)) {
    Fatal('misdefined', '<caller>', undef,
      "Should not ask for Qualified Name for node of type $type: " . Stringify($node));
    return; }
  elsif (my $ns = $node->namespaceURI) {
    return $self->getNamespacePrefix($ns) . ":" . $node->localname; }
  else {
    return $node->localname; } }

# Given a Document QName, convert to "code" form
# Used to convert a possibly prefixed name from the DTD
# (using the DTD's prefixes)
# into a prefixed name using the Code's prefixes
# NOTE: Used only for DTD
sub recodeDocumentQName {
  my ($self, $docQName) = @_;
  my ($docprefix, $name) = (undef, $docQName);
  if ($docQName =~ /^(#PCDATA|#Comment|ANY|#ProcessingInstruction|#Document)$/) {
    return $docQName; }
  else {
    ($docprefix, $name) = ($1, $2) if $docQName =~ /^([^:]+):(.+)/;
    return $self->encodeQName($self->getDocumentNamespace($docprefix), $name); } }

# Get an XPath context that knows about our namespace mappings.
sub getXPath {
  my ($self) = @_;
  return $$self{xpath}; }

#**********************************************************************
# Accessors
#**********************************************************************

sub getTags {
  my ($self) = @_;
  return keys %{ $$self{tagprop} }; }

sub getTagContents {
  my ($self, $tag) = @_;
  my $h = $$self{tagprop}{$tag}{model};
  return $h ? keys %$h : (); }

sub addTagContent {
  my ($self, $tag, @elements) = @_;
  $$self{tagprop}{$tag}{model} = {} unless $$self{tagprop}{$tag}{model};
  map { $$self{tagprop}{$tag}{model}{$_} = 1 } @elements;
  return; }

sub getTagAttributes {
  my ($self, $tag) = @_;
  my $h = $$self{tagprop}{$tag}{attributes};
  return $h ? keys %$h : (); }

sub addTagAttribute {
  my ($self, $tag, @attributes) = @_;
  $$self{tagprop}{$tag}{attributes} = {} unless $$self{tagprop}{$tag}{attributes};
  map { $$self{tagprop}{$tag}{attributes}{$_} = 1 } @attributes;
  return; }

sub setSchemaClass {
  my ($self, $classname, $content) = @_;
  $$self{schemaclass}{$classname} = $content;
  return; }

#**********************************************************************
# Document Structure Queries
#**********************************************************************
# NOTE: These are public, but perhaps should be passed
# to submodel, in case it can evolve to more precision?
# However, it would need more context to do that.

# Can an element with (qualified name) $tag contain a $childtag element?
sub canContain {
  my ($self, $tag, $childtag) = @_;
  $self->loadSchema unless $$self{schema_loaded};
  # Handle obvious cases explicitly.
  return 0 if $tag eq '#PCDATA';
  return 0 if $tag eq '#Comment';
  return 1 if $tag =~ /(.*?:)?_Capture_$/;             # with or without namespace prefix
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
  return $$model{ANY} || $$model{$childtag}; }

sub canHaveAttribute {
  my ($self, $tag, $attrib) = @_;
  $self->loadSchema unless $$self{schema_loaded};
  return 0 if $tag eq '#PCDATA';
  return 0 if $tag eq '#Comment';
  return 0 if $tag eq '#Document';
  return 0 if $tag eq '#ProcessingInstruction';
  return 0 if $tag eq '#DTD';
  return 1 if $tag =~ /(.*?:)?_Capture_$/;
  return 1 if $$self{permissive};
  return $$self{tagprop}{$tag}{attributes}{$attrib}; }

sub isInSchemaClass {
  my ($self, $classname, $tag) = @_;
  $tag = $self->getNodeQName($tag) if ref $tag;    # In case tag is a node.
  my $class = $$self{schemaclass}{$classname};
  return $class && $$class{$tag}; }

#**********************************************************************
sub describeModel {
  my ($self) = @_;
  print STDERR "Doctype\n";
  foreach my $tag (sort keys %{ $$self{tagprop} }) {
    if (my $model = $$self{tagprop}{$tag}{model}) {
      if (keys %$model) {
        print STDERR "$tag can contain " . join(', ', sort keys %{ $$self{tagprop}{$tag}{model} }) . "\n"; } }
    else {
      print STDERR "$tag is empty\n"; }
  }
  return; }

#**********************************************************************
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Common::Model> - represents the Document Model

=head1 DESCRIPTION

C<LaTeXML::Common::Model> encapsulates information about the document model to be used
in converting a digested document into XML by the L<LaTeXML::Core::Document>.
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

It extends L<LaTeXML::Common::Object>.

=head2 Model Creation

=over 4

=item C<< $model = LaTeXML::Common::Model->new(%options); >>

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

=item C<< $boole = $model->canHaveAttribute($tag,$attribute); >>

Returns whether an element with qualified name C<$tag> is allowed to have an attribute
with the given name.

=back

=head1 SEE ALSO

L<LaTeXML::Common::Model::DTD>,
L<LaTeXML::Common::Model::RelaxNG>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
