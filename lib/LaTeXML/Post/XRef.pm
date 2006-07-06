# /=====================================================================\ #
# |  LaTeXML::Post::Xref                                                | #
# | Postprocessor for adding text to references                         | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post::XRef;
use strict;
use XML::LibXML;
use XML::LibXSLT;

sub new {
  my($class,%options)=@_;
  bless {},$class; }

sub process {
  my($self,$doc,%options)=@_;
  my %xref=();
  foreach my $node ($doc->findnodes('.//*[@label]')){
    my $label  = $node->getAttribute('label');
    my $refnum = $node->getAttribute('refnum');
    $xref{$label}=$refnum if $label && $refnum; }
  foreach my $node ($doc->findnodes('.//*[@labelref]')){
    my $label  = $node->getAttribute('labelref');
    if(!$node->textContent){
      my $refnum = $xref{$label};
      $node->appendText($refnum) if $refnum; }}
  $doc; }
# ================================================================================
1;

