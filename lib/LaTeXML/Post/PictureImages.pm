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

# Options:
#  resource_directory
#  resource_prefix
#  use_dvipng
#  empty_only : process only ltx:picture w/o children (but with tex attribute)
sub new {
  my ($class, %options) = @_;
  $options{resource_directory} = 'pic' unless defined $options{resource_directory};
  $options{resource_prefix}    = 'pic' unless defined $options{resource_prefix};
  $options{use_dvipng}         = 0     unless defined $options{use_dvipng};
  return $class->SUPER::new(%options); }

#======================================================================

sub find_documentclass_and_packages {
  my ($self,      $doc)      = @_;
  my ($classdata, @packages) = $self->SUPER::find_documentclass_and_packages($doc);
  # If we haven't already included graphics or graphicx
  if (!grep { /graphic(:?s|x)/ } @packages) {
    # and if a picture has @scale
    if ($doc->findnodes('//ltx:picture[@scale]')) {
      # Then load graphicx as well
      push(@packages, ['graphicx', '']); } }
  return ($classdata, @packages); }

# Return the list of Picture nodes.
sub toProcess {
  my ($self, $doc) = @_;
  my @nodes = $doc->findnodes('//ltx:picture');
  if ($$self{empty_only}) {
    @nodes = grep { !$_->hasChildNodes; } @nodes; }
  return @nodes; }

# Return the TeX string to format the image for this node.
sub extractTeX {
  my ($self, $doc, $node) = @_;
  my $tex = $self->cleanTeX($node->getAttribute('tex') || '');
  $tex =~ s/\n//gs;    # trim stray CR's
  if (my $u = $node->getAttribute('unitlength')) {
    $tex = "\\setlength{\\unitlength}{$u}" . $tex; }
  # xunitlength, yunitlength for pstricks???
  if (my $s = $node->getAttribute('scale')) {
    $tex = "\\scalebox{$s}{$tex}"; }
  return "\\beginPICTURE $tex\\endPICTURE"; }

sub process {
  my ($self, $doc, @nodes) = @_;
  return $self->generateImages($doc, @nodes); }

sub setTeXImage {
  my ($self, $doc, $node, $path, $width, $height, $depth) = @_;
  $self->SUPER::setTeXImage($doc, $node, $path, $width, $height, $depth);
  # Since the width & height attributes can get exposed in the XSLT (CSS)
  # adjust them to match the size actually computed
  #  $node->setAttribute(width  => $width . "pt");
  #  $node->setAttribute(height => $height . "pt");
  # But, since the inner image (of whatever format) will already get a size,
  # it's probably safer to just remove those attributes?
  #  $node->removeAttribute('width');
  #  $node->removeAttribute('height');
  return; }

# Definitions needed for processing inline & display picture images
sub preamble {
  my ($self, $doc) = @_;
  return <<'EOPreamble';
\def\scalePicture#1{\setlength{\unitlength}{#1 \unitlength}
\@tempdimb\f@size\p@ \@tempdimb#1\@tempdimb
   \fontsize{\strip@pt\@tempdimb}{\strip@pt\@tempdimb}\selectfont}
\def\beginPICTURE{\lxBeginImage}
\def\endPICTURE{\lxEndImage}
EOPreamble
}
#======================================================================
1;
