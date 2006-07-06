# /=====================================================================\ #
# |  LaTeXML::Model                                                     | #
# | Stores representation of Document Type for use by Intestine         | #
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
use LaTeXML::Global;
use LaTeXML::Object;
use LaTeXML::Util::Pathname;
our @ISA = qw(LaTeXML::Object);

#**********************************************************************
sub new {
  my($class,%options)=@_;
  bless {%options},$class; }

sub getRootName { $_[0]->{roottag}; }
sub getPublicID { $_[0]->{public_id}; }
sub getSystemID { $_[0]->{system_id}; }
sub getDefaultNamespace { $_[0]->{defaultNamespace}; }

#**********************************************************************
# DocType
#**********************************************************************

sub setDocType {
  my($self,$roottag,$publicid,$systemid,$namespace)=@_;
  $$self{roottag}=$roottag;
  $self->setTagProperty('_Document_','model',{$roottag=>1});
  $$self{public_id}   =$publicid;
  $$self{system_id}   =$systemid;
  $$self{defaultNamespace}=$namespace;
}
# Hmm, rather than messing with roottag, we could extract all
# possible root tags from the doctype, then put the tag of the
# document root in the doctype declaration.
# Well, ANY element could conceivably be a root element....
# but is that desirable? Not really, ....

# Question: if we don't have a doctype, can we rig the queries to
# let it build a `reasonable' document?

#**********************************************************************
# Accessors
#**********************************************************************

sub getTagProperty {
  my($self,$tag,$prop)=@_;
  $$self{tagprop}{$tag}{$prop}; }

sub setTagProperty {
  my($self,$tag,$property,$value)=@_;
  $$self{tagprop}{$tag}{$property}=$value; }

#**********************************************************************
# Document Structure Queries
#**********************************************************************

# Can the element $node contain a $childtag element?
sub canContain {
  my($self,$tag,$childtag)=@_;
  $self->loadDocType unless $$self{doctype_loaded};
  # Handle obvious cases explicitly.
  return 0 if $tag eq '#PCDATA';
  return 0 if $tag eq '_Comment_';
  return 1 if $childtag eq '_Comment_';
  return 1 if $childtag eq '_ProcessingInstruction_';
  return 1 if $$self{permissive}; # No DTD? Punt!
  # Else query tag properties.
  my $model = $$self{tagprop}{$tag}{model};
  $$model{ANY} || $$model{$childtag}; }

# Can the element $node contain a $childtag element indirectly,
# via openning some number of autoOpen'able tags?
sub canContainVia {
  my($self,$tag,$childtag)=@_;
  $self->loadDocType unless $$self{doctype_loaded};
  $$self{tagprop}{$tag}{indirect_model}{$childtag}; }

# Can this node be automatically closed, if needed?
sub canAutoClose {
  my($self,$tag)=@_;
  $self->loadDocType unless $$self{doctype_loaded};
  return 1 if $tag eq '#PCDATA';
  return 1 if $tag eq '_Comment_';
  $$self{tagprop}{$tag}{autoClose}; }

sub canHaveAttribute {
  my($self,$tag,$attrib)=@_;
  $self->loadDocType unless $$self{doctype_loaded};
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
  my($self,$searchpaths)=@_;
  $$self{doctype_loaded}=1;
  if(!$$self{system_id}){
    Warn("No DTD declared...punting!");
    $$self{permissive}=1;	# Actually, they could have declared all sorts of Tags....
    return; }
  # Parse the DTD
  foreach my $dir (@INC){	# Load catalog (all, 1st only ???)
    next unless -f "$dir/LaTeXML/dtd/catalog";
    NoteProgress("\n(Loading XML Catalog $dir/LaTeXML/dtd/catalog)");
    XML::LibXML->load_catalog("$dir/LaTeXML/dtd/catalog"); 
    last; }
  my $dtd = XML::LibXML::Dtd->new($$self{public_id},$$self{system_id});
  if($dtd){
    NoteProgress("\n(Loaded DTD for $$self{public_id} $$self{system_id})"); }
  else { # Couldn't find dtd in catalog, try finding the file. (search path?)
    my @paths = @$searchpaths;
    @paths = (map("$_/dtd",@paths),@paths);
    my $dtdfile = pathname_find($$self{system_id},paths=>[@paths]);
    if($dtdfile){
      { local $/=undef;
	NoteProgress("\n(Loading DTD from $dtdfile");
	open(DTD,$dtdfile) || Error("Couldn't read DTD from $dtdfile");
	my $dtdtext = <DTD>;
	close(DTD);
	$dtd = XML::LibXML::Dtd->parse_string($dtdtext); 
	Error("Parsing of DTD \"$$self{public_id}\" \"$$self{system_id}\" failed") unless $dtd;
	NoteProgress(")"); }}}
  Error("Couldn't find DTD \"$$self{public_id}\" \"$$self{system_id}\" failed") unless $dtd;
  Message("Analyzing DTD \"$$self{public_id}\" \"$$self{system_id}\"") if Debugging();
  # Extract all possible children for each tag.
  foreach my $node ($dtd->childNodes()){
    if($node->nodeType() == XML_ELEMENT_DECL()){
      my $decl = $node->toString();
      chomp($decl);
      if($decl =~ /^<!ELEMENT\s+([a-zA-Z0-9\-\_\:]+)\s+(.*)>$/){
	my($tag,$model)=($1,$2);
	$model=~ s/[\*\?\,\(\)\|]/ /g;
	$model=~ s/\s+/ /g; $model=~ s/^\s+//; $model=~ s/\s+$//;
	$$self{tagprop}{$tag}{model}={ map(($_ => 1), split(/ /,$model))};
      }
      else { warn("Warning: got \"$decl\" from DTD");}
    }
    elsif($node->nodeType() == XML_ATTRIBUTE_DECL()){
      $$self{tagprop}{$1}{attributes}{$2}=1
	if($node->toString =~ /^<!ATTLIST\s+([a-zA-Z0-0-+]+)\s+([a-zA-Z0-0-+]+)\s+(.*)>$/) }
    }
  # Determine a path to each descendent via an `autoOpen-able' tag.
  foreach my $tag (keys %{$$self{tagprop}}){
    local %::DESC=();
    computeDescendents($self,$tag,''); 
    $$self{tagprop}{$tag}{indirect_model}={%::DESC}; }
  if(Debugging('DOCTYPE')){
    Message("Doctype");
    foreach my $tag (sort keys %{$$self{tagprop}}){
      Message("$tag can contain ".join(', ',sort keys %{$$self{tagprop}{$tag}{model}})); 
      Message("$tag can be inserted via ".
	      join(', ',sort keys %{$$self{tagprop}{$tag}{indirect_model}}));  }}
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
1;

__END__

=pod 

=head1 LaTeXML::Model

=head2 DESCRIPTION

LaTeXML::Model encapsulates information about the document model to be used
in converting a digested document into XML by the L<LaTeXML::Intestine>.
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

=head2 Methods of LaTeXML::Model

=over 4

=item C<< $model = LaTeXML::Model->new(%options); >>

Creates a new model.  The only useful option is
C<< permissive=>1 >> which ignores any DTD and allows the
document to be built without following any particular content model.

=item C<< $name = $model->getRootName; >>

Return the name of the root element.

=item C<< $publicid = $model->getPublicID; >>

Return the public identifier for the document type.

=item C<< $systemid = $model->getSystemID; >>

Return the system identifier for the document type
(typically a filename for the DTD).

=item C<< $model->setDocType($rootname,$publicid,$systemid,$namespace); >>

Sets the root element name and the public and system identifiers
for the desired document type, as well as the default namespace URI.

=item C<< $value = $model->getTagProperty($tag,$property); >>

Gets the value of the $property associated with the element name $tag.
Known properties are:
   autoOpen   : This asserts that the $tag is allowed to be opened automatically
                if needed to insert some other element.  If not set
                this tag will need to be explicitly opened.
   autoClose  : This asserts that the $tag is allowed to be closed automatically
                if needed to insert some other element.  If not set
                this tag will need to be explicitly closed.
   afterOpen  : supplies code to be executed whenever an element of this type is
                opened.  It is called with the created node and the responsible
                digested object as arguments.
   afterClose : supplies code to be executed whenever an element of this type is
                closed.  It is called with the created node and the responsible
                digested object as arguments.

=item C<< $model->setTagProperty($tag,$property,$value); >>

sets the value of the $property associated with the element name $tag to $value.

=item C<< $boole = $model->canContain($tag,$childtag); >>

Returns whether an element $tag can contain an element $childtag.
The element names #PCDATA, _Comment_ and _ProcessingInstruction_
are specially recognized.

=item C<< $auto = $model->canContainVia($tag,$childtag); >>

Checks whether an element $tag could contain an element $childtag,
provided an `autoOpen'able element $auto were inserted in $tag.

=item C<< $boole = $model->canAutoClose($tag); >>

Returns whether an element $tag is allowed to be closed automatically,
if needed.

=item C<< $boole = $model->canHaveAttribute($tag,$attribute); >>

Returns whether an element $tag is allowed to have an attribute
with the given name.

=back

=cut
