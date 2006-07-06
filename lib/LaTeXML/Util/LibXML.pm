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
  my($tag,$children,%attributes)=@_;
  my $node=XML::LibXML::Element->new($tag);
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
      $node->appendChild(maybe_clone($child)); }
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

# We have to be _extremely_ careful when rearranging trees when using 
# addXML::LibXML!!! If we add one node to another, it is _silently_ removed 
# from any parent it may have had!
# Hopefully, this test is sufficient?

sub maybe_clone {
  my($node)=@_;
  ($node->parentNode ? $node->cloneNode(1) : $node); }

#**********************************************************************
1;
