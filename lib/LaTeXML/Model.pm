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
use XML::LibXML;
use XML::LibXML::Common qw(:libxml);
use XML::LibXML::XPathContext;
use LaTeXML::Global;
use LaTeXML::Font;
use LaTeXML::Util::Pathname;
use LaTeXML::Rewrite;
use base qw(LaTeXML::Object);

#**********************************************************************
sub new {
  my($class,%options)=@_;
  my $self = bless {xpath=> XML::LibXML::XPathContext->new(),
		    namespace_prefixes=>{}, namespaces=>{}, 
		    doctype_namespaces=>{},
		    rewrites=>[], ligatures=>[], mathligatures=>[],
		    %options},$class;
  $$self{xpath}->registerFunction('match-font',\&LaTeXML::Font::match_font);
  $self->registerNamespace('xml',"http://www.w3.org/XML/1998/namespace");
  $self; }

sub getRootName { $_[0]->{roottag}; }
sub getPublicID { $_[0]->{public_id}; }
sub getSystemID { $_[0]->{system_id}; }

sub getDTD {
  my($self)=@_;
  $self->loadDocType unless $$self{doctype_loaded};
  $$self{dtd}; }

sub getXPath { $_[0]->{xpath}; }

#**********************************************************************
# DocType
#**********************************************************************

sub setDocType {
  my($self,$roottag,$publicid,$systemid,%namespaces)=@_;
  $$self{roottag}=$roottag;
  $self->setTagProperty('#Document','model',{$roottag=>1}) if $roottag;
  $$self{public_id}   =$publicid;
  $$self{system_id}   =$systemid;
  foreach my $prefix (keys %namespaces){
    $self->registerDocTypeNamespace($prefix=>$namespaces{$prefix}); }
}
# Hmm, rather than messing with roottag, we could extract all
# possible root tags from the doctype, then put the tag of the
# document root in the doctype declaration.
# Well, ANY element could conceivably be a root element....
# but is that desirable? Not really, ....

# Question: if we don't have a doctype, can we rig the queries to
# let it build a `reasonable' document?

#**********************************************************************
# Namespaces
#**********************************************************************
# There are TWO namespace mappings!!!
# One for coding, one for the DocType.
#
# Coding: this namespace mapping associates prefixes to namespace URIs for
#   use in the latexml code, constructors and such.
#   This must be a one to one mapping
# DocType: this namespace mapping associates prefixes to namespace URIs
#   as used in the Document Type description (DTD), and will be the
#   set of prefixes used in the generated output.
sub registerNamespace {
  my($self,$prefix,$namespace)=@_;
  if($prefix && $namespace){
    $$self{namespace_prefixes}{$namespace}=$prefix;
    $$self{namespaces}{$prefix}=$namespace;
    $$self{xpath}->registerNs($prefix,$namespace);  
  }}

sub getNamespacePrefix {
  my($self,$namespace)=@_;
  $$self{namespace_prefixes}{$namespace}; }

sub getNamespace {
  my($self,$prefix)=@_;
  $$self{namespaces}{$prefix}; }

#sub getRegisteredNamespaces {
#    my($self)=@_;
#    keys %{$$self{namespace_prefixes}}; }

# This registers a prefix & namespace as used in the DTD.
# The prefix may be different from the one used in latexml code,
# HOWEVER, the namespace must have a corresponding prefix.
# use "#default" for non-prefixed namespaces.
sub registerDocTypeNamespace {
  my($self,$prefix,$namespace)=@_;
  if($prefix && $namespace){
    $$self{doctype_namespaces}{$prefix}=$namespace; }}

sub getDocTypeNamespace {
  my($self,$prefix)=@_;
  $$self{doctype_namespaces}{$prefix}; }

sub getDocTypeNamespaces {
    my($self)=@_;
    %{$$self{doctype_namespaces}}; }

sub normalizeDocTypeName {
  my($self,$dtdname)=@_;
  if($dtdname =~ /^#PCDATA|ANY$/){
    $dtdname; }
  elsif($dtdname =~ /^([^:]+):(.+)/){
    my($dtd_prefix,$name) = ($1,$2);
    if(my $ns = $$self{doctype_namespaces}{$dtd_prefix}){
      if(my $code_prefix = $$self{namespace_prefixes}{$ns}){
	$code_prefix.":".$name; }
      else {
	Error("No prefix has been registered for the DTD namespace \"$ns\"");
	$name; }}
    else {
      Error("No namespace has been registered for the DTD prefix \"$dtd_prefix\"");
      $name; }}
  elsif(my $ns = $$self{doctype_namespaces}{'#default'}){
    if(my $code_prefix = $$self{namespace_prefixes}{$ns}){
      $code_prefix.":".$dtdname; }
    else {
      Error("No prefix has been registered for the DTD namespace \"$ns\"");
      $dtdname; }}
  else {
    $dtdname; }}

#**********************************************************************
# Accessors
#**********************************************************************

sub setTagProperty {
  my($self,$tag,$property,$value)=@_;
  $$self{tagprop}{$tag}{$property}=$value; }

sub getTagProperty {
  my($self,$tag,$prop)=@_;
  $$self{tagprop}{$tag}{$prop}; }

#**********************************************************************
# Document Structure Queries
#**********************************************************************

# Can an element with (qualified name) $tag contain a $childtag element?
sub canContain {
  my($self,$tag,$childtag)=@_;
  $self->loadDocType unless $$self{doctype_loaded};
  # Handle obvious cases explicitly.
  return 0 if $tag eq '#PCDATA';
  return 0 if $tag eq '#Comment';
  return 1 if $tag eq '_Capture_';
  return 1 if $tag eq '_WildCard_';
  return 1 if $childtag eq '_Capture_';
  return 1 if $childtag eq '_WildCard_';
  return 1 if $childtag eq '#Comment';
  return 1 if $childtag eq '#ProcessingInstruction';
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
  $self->loadDocType unless $$self{doctype_loaded};
  $$self{tagprop}{$tag}{indirect_model}{$childtag}; }

sub canContainSomehow {
  my($self,$tag,$childtag)=@_;
  $self->canContain($tag,$childtag) ||  $self->canContainIndirect($tag,$childtag); }

# Can this node be automatically closed, if needed?
sub canAutoClose {
  my($self,$tag)=@_;
  $self->loadDocType unless $$self{doctype_loaded};
  return 1 if $tag eq '#PCDATA';
  return 1 if $tag eq '#Comment';
  $$self{tagprop}{$tag}{autoClose}; }

sub canHaveAttribute {
  my($self,$tag,$attrib)=@_;
  $self->loadDocType unless $$self{doctype_loaded};
  return 1 if $attrib eq 'xml:id';
  return 1 if $$self{permissive};
  $$self{tagprop}{$tag}{attributes}{$attrib}; }

#**********************************************************************
# DTD Analysis
#**********************************************************************
# Uses XML::LibXML to read in the DTD. Then extracts a simplified
# model: which elements can appear within each element, ignoring
# (for now) the ordering, repeat, etc, of the elements.
# From this, and the Tag declarations of autoOpen (that an
# element can be opened automatically, if needed) we derive an implicit model.
# Thus, if we want to insert an element (or, say #PCDATA) into an
# element that doesn't allow it, we may find an implied element
# to create & insert, and insert the #PCDATA into it.

sub loadDocType {
  my($self)=@_;
  $$self{doctype_loaded}=1;
  NoteBegin("Loading DocType");
  if(!$$self{system_id}){
    Warn("No DTD declared...assuming LaTeXML!");
    # article ??? or what ? undef gives problems!
    $self->setDocType(undef,"-//NIST LaTeXML//LaTeXML article",'LaTeXML.dtd',
		      '#default'=>"http://dlmf.nist.gov/LaTeXML");
    $$self{permissive}=1;	# Actually, they could have declared all sorts of Tags....
#    return; 
  }
  # Parse the DTD
  NoteBegin("Loading XML catalogs");
  foreach my $catalog (	pathname_findall('catalog',
					 paths=>$STATE->lookupValue('SEARCHPATHS'),
					 installation_subdir=>'dtd')){
    NoteProgress("Loading catalog $catalog. ");
    XML::LibXML->load_catalog($catalog); }
  NoteEnd("Loading XML catalogs");

  NoteBegin("Loading DTD for $$self{public_id} $$self{system_id}");
  # NOTE: setting XML_DEBUG_CATALOG makes this Fail!!!
  my $dtd = XML::LibXML::Dtd->new($$self{public_id},$$self{system_id});
  if($dtd){
    NoteProgress(" via catalog "); }
  else { # Couldn't find dtd in catalog, try finding the file. (search path?)
    my $dtdfile = pathname_find($$self{system_id},
				paths=>$STATE->lookupValue('SEARCHPATHS'),
				installation_subdir=>'dtd');
    if($dtdfile){
      NoteProgress(" from $dtdfile ");
      $dtd = XML::LibXML::Dtd->new($$self{public_id},$dtdfile);
      NoteProgress(" from $dtdfile ") if $dtd;
      Error("Parsing of DTD \"$$self{public_id}\" \"$$self{system_id}\" failed")
	unless $dtd;
      }
    else {
      Error("Couldn't find DTD \"$$self{public_id}\" \"$$self{system_id}\" failed"); }}
#  NoteEnd("Loading DTD for $$self{public_id} $$self{system_id}");		# Done reading DTD
  return unless $dtd;

  $$self{dtd}=$dtd;
  NoteBegin("Analyzing DTD");
  # Extract all possible children for each tag.
  foreach my $node ($dtd->childNodes()){
    if($node->nodeType() == XML_ELEMENT_DECL()){
      my $decl = $node->toString();
      chomp($decl);
      if($decl =~ /^<!ELEMENT\s+([a-zA-Z0-9\-\_\:]+)\s+(.*)>$/){
	my($tag,$model)=($1,$2);
	$$self{tagprop}{$tag}{preferred_prefix} = $1 	if $tag =~ /^([^:]+):(.+)/;
	$tag = $self->normalizeDocTypeName($tag);
	$model=~ s/[\+\*\?\,\(\)\|]/ /g;
	$model=~ s/\s+/ /g; $model=~ s/^\s+//; $model=~ s/\s+$//;
	my @model = map($self->normalizeDocTypeName($_),split(/ /,$model));
	$$self{tagprop}{$tag}{model}={ map(($_ => 1), @model)};
      }
      else { warn("Warning: got \"$decl\" from DTD");}
    }
    elsif($node->nodeType() == XML_ATTRIBUTE_DECL()){
      if($node->toString =~ /^<!ATTLIST\s+([a-zA-Z0-9-]+)\s+([a-zA-Z0-9-]+)\s+(.*)>$/){
	my($tag,$attr)=($1,$2);
	$tag = $self->normalizeDocTypeName($tag);
	$$self{tagprop}{$tag}{attributes}{$attr}=1; }}
    }
  # Determine any indirect paths to each descendent via an `autoOpen-able' tag.
  foreach my $tag (keys %{$$self{tagprop}}){
    local %::DESC=();
    computeDescendents($self,$tag,''); 
    $$self{tagprop}{$tag}{indirect_model}={%::DESC}; }
  # PATCHUP
  if($$self{permissive}){
    $$self{tagprop}{'#Document'}{indirect_model}{'#PCDATA'}='ltx:p'; }
  NoteEnd("Analyzing DTD");		# Done analyzing

  if($LaTeXML::Model::DEBUG){
    print STDERR "Doctype\n";
    foreach my $tag (sort keys %{$$self{tagprop}}){
      print STDERR "$tag can contain ".join(', ',sort keys %{$$self{tagprop}{$tag}{model}})."\n"
	if keys %{$$self{tagprop}{$tag}{model}};
      print STDERR "$tag can indirectly contain ".
	join(', ',sort keys %{$$self{tagprop}{$tag}{indirect_model}})."\n"
	  if keys %{$$self{tagprop}{$tag}{indirect_model}};
    }}
  NoteEnd("Loading DocType");		# done Loading
}

sub computeDescendents {
  my($self,$tag,$start)=@_;
  foreach my $kid (keys %{$$self{tagprop}{$tag}{model}}){
    next if $::DESC{$kid};
    $::DESC{$kid}=$start if $start;
    if($$self{tagprop}{$kid}{autoOpen}){
      computeDescendents($self,$kid,$start||$kid); }
  }
}


#**********************************************************************
sub addLigature {
  my($self,$regexp,%options)=@_;
  my $code =  "sub { \$_[0] =~ s${regexp}g; }";
  my $fcn = eval $code;
  Error("Failed to compile regexp pattern \"$regexp\" into \"$code\": $!") if $@;
  unshift(@{$$self{ligatures}}, { regexp=>$regexp, code=>$fcn, %options}); }

sub getLigatures {
  my($self)=@_;
  @{$$self{ligatures}}; }

sub addMathLigature {
  my($self,$matcher)=@_;
  unshift(@{$$self{mathligatures}}, { matcher=>$matcher}); }

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
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Model> -- represents the Document Model

=head1 DESCRIPTION

C<LaTeXML::Model> encapsulates information about the document model to be used
in converting a digested document into XML by the L<LaTeXML::Document>.
This information is based on the DTD, but may also be modified by
modules implementing various macro packages; thus the model may not be
complete until digestion is completed.

The kinds of information that is relevant is not only the content model
(what each element can contain contain), but also SGML-like information
such as whether an element can be implicitly opened or closed, if needed
to insert a new element into the document.

Currently, only a DTD is understood (no schema yet), and even there, the 
stored model is only approximate.  For example, we only record that
certain elements can appear within another; we don't preserve any
information about required order or number of instances.

=head2 Model Creation

=over 4

=item C<< $model = LaTeXML::Model->new(%options); >>

Creates a new model.  The only useful option is
C<< permissive=>1 >> which ignores any DTD and allows the
document to be built without following any particular content model.

=back

=head2 Document Type

=over 4

=item C<< $name = $model->getRootName; >>

Return the name of the expected root element.

=item C<< $publicid = $model->getPublicID; >>

Return the public identifier for the document type.

=item C<< $systemid = $model->getSystemID; >>

Return the system identifier for the document type
(typically a filename for the DTD).

=item C<< $model->setDocType($rootname,$publicid,$systemid,%namespaces); >>

Declares the expected rootelement, the public and system ID's of the document type
to be used in the final document.  The hash C<%namespaces> specifies
the namespace prefixes that are expected to be found in the DTD, along with
the associated namespace URI.  These prefixes may be different from
the prefixes used in implementation code (eg. in ltxml files; see RegisterNamespace).
The generated document will use the namespaces and prefixes defined here.

=back

=head2 Namespaces

=over 4

=item C<< $model->registerNamespace($prefix,$namespace_url); >>

Register C<$prefix> to stand for the namespace C<$namespace_url>.
This prefix can then be used to create nodes in constructors and Document methods.
It will also be recognized in XPath expressions.

=item C<< $model->getNamespacePrefix($namespace); >>

Return the prefix to use for the given C<$namespace>.

=item C<< $model->getNamespace($prefix); >>

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

   autoOpen   : This asserts that the tag is allowed to be
                opened automatically if needed to insert some 
                other element.  If not set this tag will need to
                be explicitly opened.
   autoClose  : This asserts that the $tag is allowed to be 
                closed automatically if needed to insert some
                other element.  If not set this tag will need 
                to be explicitly closed.
   afterOpen  : supplies code to be executed whenever an element
                of this type is opened.  It is called with the
                created node and the responsible digested object
                as arguments.
   afterClose : supplies code to be executed whenever an element
                of this type is closed.  It is called with the
                created node and the responsible digested object
                as arguments.

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
