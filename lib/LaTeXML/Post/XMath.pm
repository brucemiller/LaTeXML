# /=====================================================================\ #
# |  LaTeXML::Post::XMath                                               | #
# | XMath pseudo-generator for LaTeXML                                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

# ================================================================================
# LaTeXML::XMath  Math Formatter for LaTeXML's Parsed Math.
#   LaTeXML's parallel math markup model is rather primitive;
# we just let the ltx:Math contain ltx:XMath and any other math representations.
# There isn't any intelligent selection or classification of them (yet?).
#
#   If XMath is going to be kept in the document either alone,
# or as the "primary" representation within a Parallel markup,
# then all we have to do is leave it alone --- it's fine where it is.
#
#   If it is NOT the primary representation, however, then we'll need
# to MOVE the XMath from where it is to whereever the primary representation
# wants it.  Since it has ID's within it that are already known to the document,
# it needs to move, rather than be copied. 
#
# AND, since any formatters that would follow this one would want to translate
# the XMath (which is now gone), this math formatter MUST be the last one....
# OR... Does it?????
# ================================================================================

package LaTeXML::Post::XMath;
use strict;
use LaTeXML::Common::XML;
use base qw(LaTeXML::Post);

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Top level
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
sub process {
  my($self,$doc)=@_;
  if(my @maths = $self->find_math_nodes($doc)){
    $self->Progress($doc,"Converting ".scalar(@maths)." formulae");
    foreach my $math (@maths){
      $self->processNode($doc,$math); }}
  $doc; }

sub setParallel {
  my($self,@moreprocessors)=@_;
  $$self{parallel}=1;
  $$self{math_processors} = [@moreprocessors]; }

sub find_math_nodes {  $_[1]->findnodes('//ltx:Math'); }

# $self->processNode($doc,$mathnode) is the top-level conversion
# It converts the XMath within $mathnode, and adds it to the $mathnode,
sub processNode {
  my($self,$doc,$math)=@_;
  my $mode = $math->getAttribute('mode')||'inline';
  my $xmath = $doc->findnode('ltx:XMath',$math);
  my $style = ($mode eq 'display' ? 'display' : 'text');
  if($$self{parallel}){
    $doc->addNodes($math,$self->translateParallel($doc,$xmath,$style,'ltx:Math')); }
  else {
    # Do nothing; the XMath is already where it belongs.
  }}

# Translate the XMath node keeping the XMath node as the "primary" in parallel
sub translateParallel {
  my($self,$doc,$xmath,$style,$embedding)=@_;
  # Simply return the translations from other processors to be added the ltx:Math.
  map($_->translateNode($doc,$xmath,$style,'m:annotation-xml'),
		   @{$$self{math_processors}}); }

# This one is called when XMath is secondary representation
sub translateNode {
  my($self,$doc,$xmath,$style,$embedding)=@_;
  # Unlink the ltx:XMath from it's parent ltx:Math
  $xmath->parentNode->removeChild($xmath);
  # And remove the record of ID's (they'll be remade, below).
  $doc->removeNodes($xmath);
  # Finally, return it to be inserted somewhere under the primary representation
  $xmath; }

sub getEncodingName { 'application/x-latexml'; }

#================================================================================

1;
