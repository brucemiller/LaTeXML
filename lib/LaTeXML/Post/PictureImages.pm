# /=====================================================================\ #
# |  LaTeXML::Post::PictureImages                                          | #
# | Postprocessor to create images for picture                             | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post::PictureImages;
use strict;
use base qw(LaTeXML::Post::LaTeXImages);

#======================================================================
sub image_prefix { 'pic'; }

# Return the list of Picture nodes.
sub find_nodes { $_[1]->findnodes('//ltx:picture'); }

# Return the TeX string to format the image for this node.
sub extract_tex {
  my($self,$node)=@_;
  my $tex = $node->getAttribute('tex') || '';
  $tex =~ s/\%[^\n]*\n//gs;	# Strip comments
  $tex =~ s/\n//g;		# and stray CR's
  "\\beginPICTURE $tex\\endPICTURE"; }

# Record the picture image's (relative) filename, width & height for this node.
sub set_image {
  my($self,$node,$path,$width,$height)=@_;
  $node->setAttribute('imagesrc',$path);
  $node->setAttribute('imagewidth',$width);
  $node->setAttribute('imageheight',$height); }

# Definitions needed for processing inline & display picture images
sub preamble {
  my($self,$doc)=@_;
return <<EOPreamble;
\\newbox\\sizebox
\\def\\beginPICTURE{\\setbox\\sizebox\\hbox\\bgroup}
\\def\\endPICTURE{\\egroup\\fbox{\\copy\\sizebox}}
EOPreamble
}
#======================================================================
1;
