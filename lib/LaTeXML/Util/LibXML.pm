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
our @EXPORT= (qw(&element_nodes &new_node &append_nodes &clear_node &maybe_clone));

#======================================================================
# XML Utilities
sub element_nodes {
  my($node)=@_;
  grep( $_->nodeType == XML_ELEMENT_NODE, $node->childNodes); }

sub new_node {
  my($nsURI,$tag,$children,%attributes)=@_;
  my $node=XML::LibXML::Element->new($tag);
#  my $node=$LaTeXML::Post::DOC->createElement($tag);
#  my $node=$LaTeXML::Post::DOC->createElementNS($nsURI,$tag);
  $node->setNamespace($nsURI);
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
    elsif(ref $child eq 'XML::LibXML::Element'){ 
#      $node->appendChild(maybe_clone($child)); }
      my $new = maybe_clone($child);
      $node->appendChild($new);
#      normalize_node($new);
    }
    elsif(ref $child){
      die "Attept to append $child to $node\n"; }
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


sub normalize_node {
  my($node)=@_;
  return unless defined $node->namespaceURI; # ???
  my $parent = $node->parentNode;
  my $parentNS =  $parent->namespaceURI;
  if($node->namespaceURI eq $parentNS){ # If they should be equal
    print STDERR "May need normalizing of ".$node->nodeName."\n";
#    my ($decl) = grep( ($_->nodeType == XML_NAMESPACE_DECL) && ($_->getData eq $parentNS) ,
#		       $node->childNodes);
    my ($decl) = grep($_->getData eq $parentNS, $node->getNamespaces);

    print STDERR "Found unneeded declaration ".$decl->getData."\n" if $decl; 
    $node->removeAttribute('xmlns');
#    $node->setNamespace($parentNS);
#    $node->removeChild($decl);
  }}

#**********************************************************************
1;
