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
use warnings;
use XML::LibXML qw(:all);
use XML::LibXML::XPathContext;
use LaTeXML::Util::Pathname;
use Encode;
use Carp;
# ?
require LaTeXML::Common::XML::Parser;
require LaTeXML::Common::XML::XPath;
require LaTeXML::Common::XML::XSLT;
require LaTeXML::Common::XML::RelaxNG;

# we're too low-level to use LaTeXML's error handling, but at least use Carp....(?)

use base qw(Exporter);
our @EXPORT = (
  # Export just these symbols from XML::LibXML
  # Possibly (if/when we abstract away from XML::LibXML), we should be selective?
  qw( XML_ELEMENT_NODE
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
    decodeFromUTF8  ),
  @XML::LibXML::EXPORT,
  # Possibly (later) export these utility functions
  qw(&element_nodes &text_in_node &new_node
    &append_nodes &clear_node &maybe_clone
    &valid_attributes &copy_attributes &rename_attribute &remove_attr
    &get_attr &isTextNode &isElementNode &isChild &isDescendant &isDescendantOrSelf
    &set_RDFa_prefixes
    &initialize_catalogs)
);

# These really should be constant, but visible outside!
our $XMLNS_NS = 'http://www.w3.org/2000/xmlns/';           # [CONSTANT]
our $XML_NS   = 'http://www.w3.org/XML/1998/namespace';    # [CONSTANT]

#======================================================================
# XML Utilities
sub element_nodes {
  my ($node) = @_;
  return grep { $_->nodeType == XML_ELEMENT_NODE } $node->childNodes; }

sub text_in_node {
  my ($node) = @_;
  return join("\n", map { $_->data } grep { $_->nodeType == XML_TEXT_NODE } $node->childNodes); }

sub isTextNode {
  my ($node) = @_;
  return $node->nodeType == XML_TEXT_NODE; }

sub isElementNode {
  my ($node) = @_;
  return $node->nodeType == XML_ELEMENT_NODE; }

# Is $child a child of $parent?
sub isChild {
  my ($child, $parent) = @_;
  my $p = $child && $child->parentNode;
  return 1 if $p && $p->isSameNode($parent);
  return 0; }

# Is $child a descendant of $parent?
sub isDescendant {
  my ($child, $parent) = @_;
  my $p = $child && $child->parentNode;
  while ($p) {
    return 1 if $p->isSameNode($parent);
    $p = $p->parentNode; }
  return 0; }

# Is $child the same as $parent, or a descendent of $parent?
sub isDescendantOrSelf {
  my ($child, $parent) = @_;
  my $p = $child;
  while ($p) {
    return 1 if $p->isSameNode($parent);
    $p = $p->parentNode; }
  return 0; }

sub new_node {
  my ($nsURI, $tag, $children, %attributes) = @_;
  #  print "\n\n\nnsURI: $nsURI, tag: $tag, children: $children\n";
  my ($nspre, $rawtag) = (undef, $tag);
  if ($tag =~ /^(\w+):(.*)$/) { ($nspre, $rawtag) = ($1, $2 || $tag); }
  my $node = XML::LibXML::Element->new($rawtag);
  #  my $node=$LaTeXML::Post::DOC->createElement($tag);
  #  my $node=$LaTeXML::Post::DOC->createElementNS($nsURI,$tag);
  if ($nspre) {
    $node->setNamespace($nsURI, $nspre, 1); }
  else {
    $node->setNamespace($nsURI); }
  append_nodes($node, $children);
  foreach my $key (sort keys %attributes) {
    $node->setAttribute($key, $attributes{$key}) if defined $attributes{$key}; }
  return $node; }

# Append the given nodes (which might also be array ref's of nodes, or even strings)
# to $node.  This takes care to clone any node that already has a parent.
sub append_nodes {
  my ($node, @children) = @_;
  foreach my $child (@children) {
    if (ref $child eq 'ARRAY') {
      append_nodes($node, @$child); }
    elsif (ref $child) {    #eq 'XML::LibXML::Element'){
      $node->appendChild(maybe_clone($child)); }
    elsif (defined $child) {
      $node->appendText($child); } }
  return $node; }

sub clear_node {
  my ($node) = @_;
  return map { $node->removeChild($_) }
    grep { ($_->nodeType == XML_ELEMENT_NODE) || ($_->nodeType == XML_TEXT_NODE) }
    $node->childNodes; }

# We have to be _extremely_ careful when rearranging trees when using XML::LibXML!!!
# If we add one node to another, it is _silently_ removed from it's previous
# parent, if any!
# Hopefully, this test is sufficient?
sub maybe_clone {
  my ($node) = @_;
  return ($node->parentNode ? $node->cloneNode(1) : $node); }

# the attributes list may contain undefined values
# and attributes with no name (?)
sub valid_attributes {
  my ($node) = @_;
  return grep { $_ && $_->getName } $node->attributes; }

# copy @attr attributes from $from to $to
sub copy_attributes {
  my ($to, $from) = @_;
  foreach my $attr ($from->attributes) {
    my $key = $attr->getName;
    $to->setAttribute($key, $from->getAttribute($key)); }
  return; }

sub rename_attribute {
  my ($node, $from, $to) = @_;
  $node->setAttribute($to, $node->getAttribute($from));
  $node->removeAttribute($from);
  return; }

sub remove_attr {
  my ($node, @attr) = @_;
  map { $node->removeAttribute($_) } @attr;
  return; }

sub get_attr {
  my ($node, @attr) = @_;
  return map { $node->getAttribute($_) } @attr; }

# NOTE: This really should be part of some top-level 'common' initialization
# and probably should accommodate catalogs being given as configuration options!
# However, it presumably sets some global state in XML::LibXML,
# so it's safe to do ( record! ) once, even across Daemon calls.
my $catalogs_initialized = 0;    # [CONFIGURATION]

sub initialize_catalogs {
  return if $catalogs_initialized;
  $catalogs_initialized = 1;
  foreach my $catalog (pathname_findall('LaTeXML.catalog', installation_subdir => '.')) {
    XML::LibXML->load_catalog($catalog); }
  return; }

# FINISH THIS EXPERIMENT LATER....

# We need to be able to find various XML resources: XSLT, RelaxNG and other random xml.
# Catalogs provide one means to provide a level of abstraction in pathname location.
# But at least at the top level, files ought to be searched for according to the current
# search paths (being command line arguments, relative to source files, etc);
# Possibly files might be referred to within XML files that libxml is already parsing
# and these could benefit from the searchpath approach?
#
# We can also provide InputCallbacks to the various XML::LibXML objects that allow
# us to programatically find & read these XML items according to the searchpaths.
# One problem is that we don't have (from this level of the API)
# a clean method of accessing the current search paths!
# Another problem is that embedded references to oddly-located relative files will usually
# get turned into paths relative to the top-level document that libxml is currently reading!
# So, we'll be given an absolute path before we have a chance to search the searchpaths for it!
#
# Perhaps we should even handle the catalog functionality here?
#
# How should we find the searchpaths?????
# Note also that if you use relative pathnames to refer to xml objects from within another,
# that libxml2 will already have _assumed_ that it is relative to the base document!
# That is, we're getting an absolute path, here.  Of course, the original request
# could have been an absolute path, so we probably shouldn't be blithely rewriting abs paths!!!
# We could take over the whole catalog business, however...
# sub initialize_input_callbacks {
#   my($object,%options) = @_;
# #  return;
#   # THIS IS TOTALLY WRONG!!!! Figure out how we'll find out about search paths!
#   my $paths = $LaTeXML::SEARCHPATHS;
#   # options might be installation_subdirs, or such pathname_find things.
#   my $cb = XML::LibXML::InputCallback->new();
#   $cb->register_callbacks([
#      sub {                      # Matcher
#        my($uri)=@_;
#        print STDERR "INPUT CHECK: $uri\n";
#        # We don't want to do the search here, 'cause we'll have to do it again in open!
#        return 0 if $uri =~ m|^file://|;                 # pass on absolute pathnames
#        return 0 if pathname_is_absolute($uri);          # a
# #       if($uri =~ /^urn:x-LaTeXML:([^:]*):(.*)$/){
#        print STDERR "INPUT ACCEPT: $uri\n";
#        return 1; },
#      sub {                      # Opener
#        my($uri)=@_;
#        my $handle;
#        $uri =~ s|^file://||;
#        # WARNING!!! Kludge alert!
#        my @paths = ('.');
#        push(@paths, @$LaTeXML::SEARCHPATHS) if $LaTeXML::SEARCHPATHS;
#        push(@paths, @{$LaTeXML::POST{searchpaths}}) if $LaTeXML::POST;
#        push(@paths, $LaTeXML::DOCUMENT->getSearchPaths) if $LaTeXML::DOCUMENT;
#        if(my $pathname =  pathname_find($uri,
#                                         # types => ['xsl'], installation_subdir => 'resources/XSLT',
#                                         paths=>[@paths])){
#          open($handle,$pathname);
#          return $handle; }
#        else {
#          Error('missing-file',$uri,undef,
#                "Couldn't find file '$uri' in search paths",
#                "Search paths were ".join(',',@paths));
#          return; }},
#      sub {                      # Reader
#        my($handle,$length)=@_;
#        my $buffer;
#        read($handle,$buffer,$length);
#        return $buffer; },
#      sub {                      # Closer
#        my($handle)=@_;
#        close($handle);
#        return; }]);
#   $object->input_callbacks($cb);
#   return; }

#======================================================================
# Odd place for this utility, but it is needed in both conversion & post
# ALSO needs error reporting capability.

my @RDF_TERM_ATTRIBUTES = (    # [CONSTANT]
  qw(about resource property typeof rel rev datatype));
my %NON_RDF_PREFIXES = map { ($_ => 1) } qw(http https ftp);    # [CONSTANT]

sub set_RDFa_prefixes {
  my ($document, $map) = @_;
  my $root     = $document->documentElement;
  my %prefixes = ();
  my %localmap = map { ($_ => $$map{$_}) } keys %$map;
  if (my $prefixes = $root->getAttribute('prefix')) {
    my @x = split(/\s/, $prefixes);
    while (@x) {
      my ($prefix, $uri) = (shift(@x), shift(@x));
      $prefix =~ s/:$//;
      $prefixes{$prefix} = 1;
      if (!$localmap{$prefix}) {
        $localmap{$prefix} = $uri; }
      elsif ($localmap{$prefix} ne $uri) {
        carp "Clash of RDFa prefix '$prefix' ('$uri' vs '$localmap{$prefix}'); "
          . "Skipping RDFa prefix management";
        return; } } }
  if (my @n = $document->findnodes('descendant::*[@prefix]')) {
    if ((scalar(@n) > 1) || !$root->isSameNode($n[0])) {
      carp "RDFa attribute 'prefix' on non-root node; "
        . "Skipping RDFa prefix management";
      return; } }
  if (my @n = $document->findnodes('descendant::*[@vocab]')) {
    carp "RDFa attribute 'vocab' on non-root node; "
      . "Skipping RDFa prefix management";
    return; }
  my $xpath = 'descendant::*[' . join(' or ', map { '@' . $_ } @RDF_TERM_ATTRIBUTES) . ']';
  foreach my $node ($document->findnodes($xpath)) {
    foreach my $k (@RDF_TERM_ATTRIBUTES) {
      if (my $v = $node->getAttribute($k)) {
        foreach my $term (split(/\s/, $v)) {
          if (($term =~ /^(\w+):/) && !$NON_RDF_PREFIXES{$1}) {
            $prefixes{$1} = 1 if $localmap{$1}; } } } } }    # A prefix is a prefix IFF there is a mapping!!
  if (my $prefixes = join(' ', map { $_ . ": " . $localmap{$_} } sort keys %prefixes)) {
    $root->setAttribute(prefix => $prefixes); }
  return; }

######################################################################
# PATCH Section
######################################################################
# Various versions of XML::LibXML have introduced incompatable improvements
# We can run using older versions, but have to patch things up to
# a consistent level.

our $original_XML_LibXML_Document_toString;       # [CONFIGURATION]
our $original_XML_LibXML_Element_getAttribute;    # [CONFIGURATION]
our $original_XML_LibXML_Element_hasAttribute;    # [CONFIGURATION]
our $original_XML_LibXML_Element_setAttribute;    # [CONFIGURATION]

BEGIN {
  *original_XML_LibXML_Document_toString    = *XML::LibXML::Document::toString;
  *original_XML_LibXML_Element_getAttribute = *XML::LibXML::Element::getAttribute;
  *original_XML_LibXML_Element_hasAttribute = *XML::LibXML::Element::hasAttribute;
  *original_XML_LibXML_Element_setAttribute = *XML::LibXML::Element::setAttribute;
}

# As of 1.63, LibXML converts a document "to String" as bytes, not characters (?)
sub encoding_XML_LibXML_Document_toString {
  my ($self, $depth) = @_;
  #  Encode::encode("utf-8", $self->original_XML_LibXML_Document_toString($depth)); }
  return Encode::encode("utf-8", original_XML_LibXML_Document_toString($self, $depth)); }

# As of 1.59, element attribute methods accept attributes names as "xml:foo"
# (in particular, xml:id), without explicitly calling the NS versions.
# The new form is considerably more convenient.
sub xmlns_XML_LibXML_Element_getAttribute {
  my ($self, $name) = @_;
  if ($name =~ /^xml:(.*)$/) {
    my $attr = $1;
    return $self->getAttributeNS($LaTeXML::Common::XML::XML_NS, $attr); }
  else {
    return original_XML_LibXML_Element_getAttribute($self, $name); } }

sub xmlns_XML_LibXML_Element_hasAttribute {
  my ($self, $name) = @_;
  if ($name =~ /^xml:(.*)$/) {
    my $attr = $1;
    return $self->hasAttributeNS($LaTeXML::Common::XML::XML_NS, $attr); }
  else {
    return original_XML_LibXML_Element_hasAttribute($self, $name); } }

sub xmlns_XML_LibXML_Element_setAttribute {
  my ($self, $name, $value) = @_;
  if ($name =~ /^xml:(.*)$/) {
    my $attr = $1;
    return $self->setAttributeNS($LaTeXML::Common::XML::XML_NS, $attr, $value); }
  else {
    return original_XML_LibXML_Element_setAttribute($self, $name, $value); } }

our $xml_libxml_version;    # [CONFIGURATION]

BEGIN {
  $xml_libxml_version = $XML::LibXML::VERSION;
  $xml_libxml_version =~ s/_\d+$//;
###  print STDERR "XML::LibXML Version $XML::LibXML::VERSION => $xml_libxml_version\n";

  if ($xml_libxml_version < 1.63) {
    *XML::LibXML::Document::toString = *encoding_XML_LibXML_Document_toString; }
  if ($xml_libxml_version < 1.59) {
    *XML::LibXML::Element::getAttribute = *xmlns_XML_LibXML_Element_getAttribute;
    *XML::LibXML::Element::hasAttribute = *xmlns_XML_LibXML_Element_hasAttribute;
    *XML::LibXML::Element::setAttribute = *xmlns_XML_LibXML_Element_setAttribute; }
}

#======================================================================
1;
