# /=====================================================================\ #
# |  LaTeXML::Util::LibXML                                              | #
# | Helpful wrappers of XML::LibXML                                     | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

#   Convenience Utilities to simplify using XML::LibXML
# One concern is to clone any nodes .....

package LaTeXML::Util::LibXML;
use strict;
use XML::LibXML;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT= (qw(&element_nodes &text_in_node &new_node &append_nodes &clear_node &maybe_clone 
		 &valid_attributes &copy_attributes &rename_attribute &remove_attr
		 &get_attr &isTextNode &isElementNode
		 &CA_KEEP &CA_OVERWRITE &CA_MERGE &CA_EXCEPT));

# attribute copying modes
use constant CA_KEEP => 1;
use constant CA_OVERWRITE => 2;
use constant CA_MERGE => 4;
use constant CA_EXCEPT => 128;

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

#**********************************************************************
1;
