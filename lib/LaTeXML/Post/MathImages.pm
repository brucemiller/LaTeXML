# /=====================================================================\ #
# |  LaTeXML::Post::MathImages                                          | #
# | Postprocessor to create images for math                             | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post::MathImages;
use strict;
use base qw(LaTeXML::Post::LaTeXImages);

sub new {
  my($class,%options)=@_;
  $options{resourceDirectory}='mi' unless defined $options{resourceDirectory};
  $options{resourcePrefix}='mi'    unless defined $options{resourcePrefix};
  $class->SUPER::new(%options); }

#======================================================================

# Return the list of Math nodes.
sub findTeXNodes { $_[1]->findnodes('//ltx:Math'); }

# Return the TeX string to format the image for this node.
sub extractTeX {
  my($self,$doc,$node)=@_;
  my $mode = uc($node->getAttribute('mode')||'INLINE');
  my $tex = $node->getAttribute('tex') || '';
  $tex =~ s/\%[^\n]*\n//gs;	# Strip comments
  $tex =~ s/\n//g;		# and stray CR's
  "\\begin$mode $tex\\end$mode"; }

# Record the math image's (relative) filename, width & height for this node.
sub setTeXImage {
  my($self,$doc,$node,$path,$width,$height)=@_;
  $node->setAttribute('imagesrc',$path);
  $node->setAttribute('imagewidth',$width);
  $node->setAttribute('imageheight',$height); }

# Definitions needed for processing inline & display math images
sub preamble {
  my($self,$doc)=@_;
  # To align the baseline of math images, align=middle is necessary.  
  # It aligns the middle of the image to the baseline + half the xheight.
  # We pad either the height or depth of the formula as such:
  #  let delta = height - xheight + depth;
  #  if(delta > 0) increment the depth by delta
  #  if(delta < 0) increment the height by |delta|
  # We'll assume the xheight is 6pts?

return <<EOPreamble;
\\newbox\\sizebox
\\def\\AdjustInline{%
  \\\@tempdima=\\ht\\sizebox\\advance\\\@tempdima-6pt\\advance\\\@tempdima-\\dp\\sizebox
  \\ifdim\\\@tempdima>0pt
    \\advance\\\@tempdima\\dp\\sizebox\\dp\\sizebox=\\\@tempdima
  \\else\\ifdim\\\@tempdima>0pt
     \\advance\\\@tempdima-\\ht\\sizebox\\ht\\sizebox=-\\\@tempdima
  \\fi\\fi}
% For Inline, typeset in box, then extend box so height=depth; then we can center it
\\def\\beginINLINE{\\setbox\\sizebox\\hbox\\bgroup\\(}
\\def\\endINLINE{\\)\\egroup\\AdjustInline\\fbox{\\copy\\sizebox}}
% For Display, same as inline, but set displaystyle.
\\def\\beginDISPLAY{\\setbox\\sizebox\\hbox\\bgroup\\(\\displaystyle}
\\def\\endDISPLAY{\\)\\egroup\\AdjustInline\\fbox{\\copy\\sizebox}}
EOPreamble
}
#======================================================================
1;
