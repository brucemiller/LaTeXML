# /=====================================================================\ #
# |  LaTeXML::Model::DTD                                                | #
# | Extract Model information from a DTD                                | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Model::DTD;
use strict;
use LaTeXML::Util::Pathname;
use XML::LibXML;
use XML::LibXML::Common qw(:libxml);
use LaTeXML::Global;
use base qw(LaTeXML::Model::Schema);

#**********************************************************************
# NOTE: Arglist is DTD specific.
# Effectively asks for DTD submodel.
sub new {
  my($class,$model,$roottag,$publicid,$systemid,%namespaces)=@_;
  my $self = {model=>$model,roottag=>$roottag,public_id=>$publicid,system_id=>$systemid};
  bless $self,$class;
  # Eventually, this needs to be derived from DTD!!!
  foreach my $prefix (keys %namespaces){
    $$self{model}->registerDocumentNamespace($prefix=>$namespaces{$prefix}); }
  $self; }

# Question: if we don't have a doctype, can we rig the queries to
# let it build a `reasonable' document?

# This is responsible for setting any DocType, and adding any
# required namespace declarations to the root element.
sub addSchemaDeclaration {
  my($self,$document,$tag)=@_;
  $document->getDocument->createInternalSubset($tag,$$self{public_id},$$self{system_id}); }

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

sub loadSchema {
  my($self)=@_;
  $$self{schema_loaded}=1;
  NoteBegin("Loading DTD ".$$self{public_id}||$$self{system_id});
  my $model = $$self{model};
  $model->setTagProperty('#Document','model',{$$self{roottag}=>1}) if $$self{roottag};
  # Parse the DTD
  my $dtd = $self->readDTD;
  return unless $dtd;

  NoteBegin("Analyzing DTD");
  # Extract all possible namespace attributes
  foreach my $node ($dtd->childNodes()){
    if($node->nodeType() == XML_ATTRIBUTE_DECL){
      if($node->toString =~ /^<!ATTLIST\s+([a-zA-Z0-9\-\_\:]+)\s+([a-zA-Z0-9\-\_\:]+)\s+(.*)>$/){
	my($tag,$attr,$extra)=($1,$2,$3);
	if($attr =~ /^xmlns(:([a-zA-Z0-9-]+))?$/){
	  my $prefix = ($1 ? $2 : '#default');
	  $extra =~ /^CDATA\s+#FIXED\s+(\'|\")(.*)\1\s*$/;
	  my $ns = $2;
	  # Just record prefix, not element??
	  $model->registerDocumentNamespace($prefix,$ns); }}}}

  # Extract all possible children for each tag.
  foreach my $node ($dtd->childNodes()){
    if($node->nodeType() == XML_ELEMENT_DECL){
      my $decl = $node->toString();
      chomp($decl);
      if($decl =~ /^<!ELEMENT\s+([a-zA-Z0-9\-\_\:]+)\s+(.*)>$/){
	my($tag,$content)=($1,$2);
##	$$self{tagprop}{$tag}{preferred_prefix} = $1 	if $tag =~ /^([^:]+):(.+)/;
	$tag = $model->recodeDocumentQName($tag);
	$content=~ s/[\+\*\?\,\(\)\|]/ /g;
	$content=~ s/\s+/ /g; $content=~ s/^\s+//; $content=~ s/\s+$//;
	if($content eq 'EMPTY'){
	  $model->setTagProperty($tag,'model',{}); }
	else {
	  my @content = map($model->recodeDocumentQName($_),split(/ /,$content));
	  $model->setTagProperty($tag,'model',{ map(($_ => 1), @content)});
	}}
      else { warn("Warning: got \"$decl\" from DTD");}
    }
    elsif($node->nodeType() == XML_ATTRIBUTE_DECL){
      if($node->toString =~ /^<!ATTLIST\s+([a-zA-Z0-9-]+)\s+([a-zA-Z0-9-]+)\s+(.*)>$/){
	my($tag,$attr,$extra)=($1,$2,$3);
	if($attr !~ /^xmlns/){
	  $tag = $model->recodeDocumentQName($tag);
	  my $attrlist = $model->getTagProperty($tag,'attributes');
	  $model->setTagProperty($tag,'attributes', $attrlist={}) unless $attrlist;
	  if($attr =~ /:/){
	    $attr = $model->recodeDocumentQName($attr); }
	  $$attrlist{$attr}=1; }}}
    }
  NoteEnd("Analyzing DTD");		# Done analyzing
  NoteEnd("Loading DTD ".$$self{public_id}||$$self{system_id});
}

sub readDTD {
  my($self)=@_;
  NoteBegin("Loading XML catalogs");
  foreach my $catalog (	pathname_findall('catalog',
					 paths=>$STATE->lookupValue('SEARCHPATHS'),
					 installation_subdir=>'schema')){
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
  $dtd; }

#**********************************************************************
1;
