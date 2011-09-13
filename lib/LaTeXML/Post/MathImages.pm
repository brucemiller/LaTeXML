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
  my $tex = $self->cleanTeX($node->getAttribute('tex'));
  return undef unless defined $tex;
  $mode = 'DISPLAY' if $tex=~/^\s*\\displaystyle/;
  ($tex =~ /^\s*$/ ? undef : "\\begin$mode $tex\\end$mode"); }

# Definitions needed for processing inline & display math images
sub preamble {
  my($self,$doc)=@_;
return <<EOPreamble;
\\def\\beginINLINE{\\lxBeginImage\\(}
\\def\\endINLINE{\\)\\lxEndImage\\lxShowImage}
% For Display, same as inline, but set displaystyle.
\\def\\beginDISPLAY{\\lxBeginImage\\(\\displaystyle\\the\\everydisplay}
\\def\\endDISPLAY{\\)\\lxEndImage\\lxShowImage}
EOPreamble
}
#======================================================================
1;
