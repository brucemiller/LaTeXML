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

sub new {
  my($class,%options)=@_;
  $options{resourceDirectory}='pic' unless defined $options{resourceDirectory};
  $options{resourcePrefix}='pic'    unless defined $options{resourcePrefix};
  $class->SUPER::new(%options); }

#======================================================================

# Return the list of Picture nodes.
sub findTeXNodes { $_[1]->findnodes('//ltx:picture'); }

# Return the TeX string to format the image for this node.
sub extractTeX {
  my($self,$doc,$node)=@_;
  my $tex = $node->getAttribute('tex') || '';
  $tex =~ s/\%[^\n]*\n//gs;	# Strip comments
  $tex =~ s/\n//g;		# and stray CR's
  if(my $u = $node->getAttribute('unitlength')){
    $tex = "\\setlength{\\unitlength}{$u}".$tex; }
  # xunitlength, yunitlength for pstricks???
  "\\beginPICTURE $tex\\endPICTURE"; }

# Record the picture image's (relative) filename, width & height for this node.
sub setTeXImage {
  my($self,$doc,$node,$path,$width,$height)=@_;
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
