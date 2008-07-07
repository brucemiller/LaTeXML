# /=====================================================================\ #
# |  LaTeXML::Common::XML                                               | #
# | XML representation common to LaTeXML & Post                         | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

######################################################################
# This is (the beginnings of) a common interface to XML,
# specifically XML::LibXML, used in LaTeXML and also Post processing.
# Collecting this here will hopefully allow us to
#  * (eventually) make useful extensions to the DOM api.
#  * hide any version specific patches that have become necessary
#   Convenience Utilities to simplify using XML::LibXML
#
#======================================================================
# An eventual possibility which would be to wrap all XML::LibXML objects
# in our own classes. This would give a cleaner way to extend the API,
# [the extensions _should_ be methods, not random exported functions!!!]
# and also to implement patches [currently kinda worrisome].
#
#  However, it would require some clumsy (& probably expensive) 
# re-blessing or wrapping of all # common LibXML accessors
# [ie. nodeChildren would need to convert all children to the new type].
#
######################################################################
# One concern is to clone any nodes .....

package LaTeXML::Common::XML;
use strict;
use XML::LibXML qw(:all);
use XML::LibXML::XPathContext;
use Encode;

use base qw(Exporter);
our @EXPORT = (
	       # Export just these symbols from XML::LibXML
	       # Possibly (if/when we abstract away from XML::LibXML), we should be selective?
  	       qw(
  		   XML_ELEMENT_NODE
  		   XML_ATTRIBUTE_NODE
  		   XML_TEXT_NODE
  		   XML_CDATA_SECTION_NODE
  		   XML_ENTITY_REF_NODE
  		   XML_ENTITY_NODE
  		   XML_PI_NODE
  		   XML_COMMENT_NODE
  		   XML_DOCUMENT_NODE
  		   XML_DOCUMENT_TYPE_NODE
  		   XML_DOCUMENT_FRAG_NODE
  		   XML_NOTATION_NODE
  		   XML_HTML_DOCUMENT_NODE
  		   XML_DTD_NODE
  		   XML_ELEMENT_DECL
  		   XML_ATTRIBUTE_DECL
  		   XML_ENTITY_DECL
  		   XML_NAMESPACE_DECL
  		   XML_XINCLUDE_END
  		   XML_XINCLUDE_START
  		   encodeToUTF8
  		   decodeFromUTF8),
	       @XML::LibXML::EXPORT,
	       # Possibly (later) export these utility functions
	       qw(&element_nodes &text_in_node &new_node &append_nodes &clear_node &maybe_clone 
		  &valid_attributes &copy_attributes &rename_attribute &remove_attr
		  &get_attr &isTextNode &isElementNode
		  &CA_KEEP &CA_OVERWRITE &CA_MERGE &CA_EXCEPT)
	      );

# attribute copying modes
use constant CA_KEEP => 1;
use constant CA_OVERWRITE => 2;
use constant CA_MERGE => 4;
use constant CA_EXCEPT => 128;

# We won't export XML_XMLNS_NS and XML_XML_NS, since
#  1. They were added after XML::LibXML 1.58, and
#  2. we'd be better off keeping their use local, anyway.
local $LaTeXML::Common::XML::XMLNS_NS;
local $LaTeXML::Common::XML::XML_NS;
BEGIN {
    $LaTeXML::Common::XML::XMLNS_NS = 'http://www.w3.org/2000/xmlns/';
    $LaTeXML::Common::XML::XML_NS   = 'http://www.w3.org/XML/1998/namespace';
}
#======================================================================
# XML Utilities
sub element_nodes {
  my($node)=@_;
  grep( $_->nodeType == XML_ELEMENT_NODE, $node->childNodes); }

sub text_in_node {
  my($node)=@_;
  join("\n", map($_->data, grep($_->nodeType == XML_TEXT_NODE, $node->childNodes))); }

sub isTextNode { $_[0]->nodeType == XML_TEXT_NODE; }
sub isElementNode { $_[0]->nodeType == XML_ELEMENT_NODE; }

sub new_node {
  my($nsURI,$tag,$children,%attributes)=@_;
#  print "\n\n\nnsURI: $nsURI, tag: $tag, children: $children\n";
  my ($nspre,$rawtag) = (undef, $tag);
  if ($tag =~ /^(\w+):(.*)$/) { ($nspre,$rawtag)=($1,$2 || $tag); }
  my $node=XML::LibXML::Element->new($rawtag);
#  my $node=$LaTeXML::Post::DOC->createElement($tag);
#  my $node=$LaTeXML::Post::DOC->createElementNS($nsURI,$tag);
  if($nspre){
    $node->setNamespace($nsURI,$nspre,1); }
  else {
    $node->setNamespace($nsURI); }
  append_nodes($node,$children);
  foreach my $key (sort keys %attributes){
    $node->setAttribute($key, $attributes{$key}) if defined $attributes{$key}; }
  $node; }

# Append the given nodes (which might also be array ref's of nodes, or even strings)
# to $node.  This takes care to clone any node that already has a parent.
sub append_nodes {
  my($node,@children)=@_;
  foreach my $child (@children){
    if(ref $child eq 'ARRAY'){ 
      append_nodes($node,@$child); }
    elsif(ref $child ){#eq 'XML::LibXML::Element'){ 
      $node->appendChild(maybe_clone($child));   }
    elsif(defined $child){ 
      $node->appendText($child); }}
  $node; }

sub clear_node {
  my($node)=@_;
  map($node->removeChild($_), 
      grep(($_->nodeType == XML_ELEMENT_NODE) || ($_->nodeType == XML_TEXT_NODE),
	   $node->childNodes)); }

# We have to be _extremely_ careful when rearranging trees when using XML::LibXML!!!
# If we add one node to another, it is _silently_ removed from it's previous
# parent, if any!
# Hopefully, this test is sufficient?
sub maybe_clone {
  my($node)=@_;
  ($node->parentNode ? $node->cloneNode(1) : $node); }

# the attributes list may contain undefined values
# and attributes with no name (?)
sub valid_attributes {    
    my($node)=@_;
    grep($_ && $_->getName, $node->attributes); }

# copy @attr attributes from $from to $to
sub copy_attributes {
    my ($to, $from, $mode, @attr) = @_;
    $mode = CA_OVERWRITE unless defined $mode;
    if ($mode & CA_EXCEPT) {
	my %ex; map($ex{$_}=1, @attr); $mode &= !CA_EXCEPT; $mode = CA_OVERWRITE unless $mode;
	@attr = map($_->getName, grep(!$ex{$_->getName}, valid_attributes($from))); }
    else { @attr = map($_->getName, valid_attributes($from)) unless @attr; }
    foreach my $attr(@attr){
	my $at = $from->getAttribute($attr);
	next if ((!defined $at) || (($mode == CA_KEEP) && $to->hasAttribute($attr)));
	if ($mode == CA_MERGE) {
	    my $old = $to->getAttribute($attr);
	    $at = "$old $at" if $old; }
	$to->setAttribute($attr, $at); }
}

sub rename_attribute {
    my ($node, $from, $to) = @_;
    $node->setAttribute($to, $node->getAttribute($from));
    $node->removeAttribute($from); }

sub remove_attr {
    my ($node, @attr) = @_;
    map($node->removeAttribute($_), @attr); }

sub get_attr {
    my ($node, @attr) = @_;
    map($node->getAttribute($_), @attr); }

######################################################################
# PATCH Section
######################################################################
# Various versions of XML::LibXML have introduced incompatable improvements
# We can run using older versions, but have to patch things up to
# a consistent level.

our $original_XML_LibXML_Document_toString;
our $original_XML_LibXML_Element_getAttribute;
our $original_XML_LibXML_Element_hasAttribute;
our $original_XML_LibXML_Element_setAttribute;

BEGIN {
  *original_XML_LibXML_Document_toString    = *XML::LibXML::Document::toString;
  *original_XML_LibXML_Element_getAttribute = *XML::LibXML::Element::getAttribute;
  *original_XML_LibXML_Element_hasAttribute = *XML::LibXML::Element::hasAttribute;
  *original_XML_LibXML_Element_setAttribute = *XML::LibXML::Element::setAttribute;
}

# As of 1.63, LibXML converts a document "to String" as bytes, not characters (?)
sub encoding_XML_LibXML_Document_toString {
  my($self,$depth)=@_;
#  Encode::encode("utf-8", $self->original_XML_LibXML_Document_toString($depth)); }
  Encode::encode("utf-8", original_XML_LibXML_Document_toString($self,$depth)); }

# As of 1.59, element attribute methods accept attributes names as "xml:foo"
# (in particular, xml:id), without explicitly calling the NS versions.
# The new form is considerably more convenient.
sub xmlns_XML_LibXML_Element_getAttribute {
    my($self,$name)=@_;
    if($name =~ /^xml:(.*)$/){
	my $attr = $1;
	$self->getAttributeNS($LaTeXML::Common::XML::XML_NS,$attr); }
    else {
	original_XML_LibXML_Element_getAttribute($self,$name); }}

sub xmlns_XML_LibXML_Element_hasAttribute {
    my($self,$name)=@_;
    if($name =~ /^xml:(.*)$/){
	my $attr = $1;
	$self->hasAttributeNS($LaTeXML::Common::XML::XML_NS,$attr); }
    else {
	original_XML_LibXML_Element_hasAttribute($self,$name); }}

sub xmlns_XML_LibXML_Element_setAttribute {
    my($self,$name,$value)=@_;
    if($name =~ /^xml:(.*)$/){
	my $attr = $1;
	$self->setAttributeNS($LaTeXML::Common::XML::XML_NS,$attr,$value); }
    else {
	original_XML_LibXML_Element_setAttribute($self,$name,$value); }}

BEGIN {
   if($XML::LibXML::VERSION < 1.63){
     *XML::LibXML::Document::toString =   *encoding_XML_LibXML_Document_toString; }
   if($XML::LibXML::VERSION < 1.59){
     *XML::LibXML::Element::getAttribute =   *xmlns_XML_LibXML_Element_getAttribute;
     *XML::LibXML::Element::hasAttribute =   *xmlns_XML_LibXML_Element_hasAttribute;
     *XML::LibXML::Element::setAttribute =   *xmlns_XML_LibXML_Element_setAttribute; }
}
######################################################################
# Subclasses
######################################################################
package LaTeXML::Common::XML::Parser;

sub new {
  my($class)=@_;
  my $parser = XML::LibXML->new();
###  $parser->clean_namespaces(1);
  $parser->validation(0);
  $parser->keep_blanks(0);	# This allows formatting the output.
  bless {parser=>$parser}, $class; }

sub parseFile {
  my($self,$file)=@_;
  $$self{parser}->parse_file($file); }

sub parseString {
  my($self,$string)=@_;
  $$self{parser}->parse_string($string); }

sub parseChunk {
  my($self,$string)=@_;
  my $hasxmlns = $string =~/\Wxml:id\W/;
# print STDERR "\nFISHY!!\n" if $hasxmlns;
  my $xml = $$self{parser}->parse_xml_chunk($string);
  # Simplify, if we get a single node Document Fragment.
  #[which we, apparently, always do]
  if($xml && (ref $xml eq 'XML::LibXML::DocumentFragment')) {
    my @k = $xml->childNodes;
    $xml = $k[0] if(scalar(@k) == 1); }
#  $xml = $xml->cloneNode(1);
  ####
  # In 1.58, the prefix for the XML_NS, which should be DEFINED to be "xml"
  # is sometimes unbound, leading to mysterious segfaults!!!
  if(($XML::LibXML::VERSION < 1.59) && $hasxmlns){
#print STDERR "Patchup...\n";
    # Re-create all xml:id entrys, hopefully with correct NS!
    # We assume all id are, in fact, xml:id,
    # because we seemingly can't probe the namespace!
    foreach my $attr ($xml->findnodes("descendant-or-self::*/attribute::*[local-name()='id']")){
      my $element = $attr->parentNode;
      my $id = $attr->getValue();
#print STDERR "RESET ID: $id\n";
      $attr->unbindNode();
      $element->setAttributeNS($LaTeXML::Common::XML::XML_NS,'id',$id); 
    }
#    print STDERR "\nXML: ".$xml->toString."\n";
    }
  $xml; }

######################################################################
package LaTeXML::Common::XML::XPath;
use XML::LibXML::XPathContext;

sub new {
  my($class,%mappings)=@_;
  my $context = XML::LibXML::XPathContext->new();
  foreach my $prefix (keys %mappings){
    $context->registerNs($prefix=>$mappings{$prefix}); }
  bless {context=>$context}, $class; }

sub registerNS {
  my($self,$prefix,$url)=@_;
  $$self{context}->registerNs($prefix=>$url); }

sub registerFunction {
  my($self,$name,$function)=@_;
  $$self{context}->registerFunction($name=>$function); }

sub findnodes {
  my($self,$xpath,$node)=@_;
  $$self{context}->findnodes($xpath,$node); }


######################################################################
package LaTeXML::Common::XML::XSLT;
use XML::LibXSLT;

sub new {
  my($class,$stylesheet)=@_;
  if(!ref $stylesheet){
    $stylesheet = LaTeXML::Common::XML::Parser->new()->parseFile($stylesheet); }
  if(ref $stylesheet eq 'XML::LibXML::Document'){
    $stylesheet = XML::LibXSLT->new()->parse_stylesheet($stylesheet); }
  bless {stylesheet=>$stylesheet}, $class; }

sub transform {
  my($self,$document,%params)=@_;
  $$self{stylesheet}->transform($document,%params); }

#**********************************************************************
1;
