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
use warnings;
use LaTeXML::Post;
use base qw(LaTeXML::Post::LaTeXImages);

sub new {
  my ($class, %options) = @_;
  $options{resource_directory} = 'pic' unless defined $options{resource_directory};
  $options{resource_prefix}    = 'pic' unless defined $options{resource_prefix};
  $options{use_dvipng}         = 0     unless defined $options{use_dvipng};
  return $class->SUPER::new(%options); }

#======================================================================

# Return the list of Picture nodes.
sub toProcess {
  my ($self, $doc) = @_;
  return $doc->findnodes('//ltx:picture'); }

# Return the TeX string to format the image for this node.
sub extractTeX {
  my ($self, $doc, $node) = @_;
  my $tex = $self->cleanTeX($node->getAttribute('tex') || '');
  $tex =~ s/\n//gs;    # trim stray CR's
  my $adjustments = '';
  if (my $u = $node->getAttribute('unitlength')) {
    $adjustments .= "\\setlength{\\unitlength}{$u}"; }
  # xunitlength, yunitlength for pstricks???
  if (my $s = $node->getAttribute('scale')) {
    $adjustments .= "\\scalePicture{$s}"; }
  return "\\beginPICTURE $adjustments $tex\\endPICTURE"; }

sub process {
  my ($self, $doc, @nodes) = @_;
  return $self->generateImages($doc, @nodes); }

sub setTeXImage {
  my ($self, $doc, $node, $path, $width, $height, $depth) = @_;
  $self->SUPER::setTeXImage($doc, $node, $path, $width, $height, $depth);
  # Since the width & height attributes can get exposed in the XSLT (CSS)
  # adjust them to match the size actually computed
  $node->setAttribute(width  => $width . "pt");
  $node->setAttribute(height => $height . "pt");
  return; }

# Definitions needed for processing inline & display picture images
sub preamble {
  my ($self, $doc) = @_;
  return <<'EOPreamble';
\def\scalePicture#1{\setlength{\unitlength}{#1 \unitlength}
\@tempdimb\f@size\p@ \@tempdimb#1\@tempdimb
   \fontsize{\strip@pt\@tempdimb}{\strip@pt\@tempdimb}\selectfont}
\def\beginPICTURE{\lxBeginImage}
\def\endPICTURE{\lxEndImage\lxShowImage}
EOPreamble
}
#======================================================================
1;
