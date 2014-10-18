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
use warnings;
use LaTeXML::Post;
use LaTeXML::Util::Pathname;
use base qw(LaTeXML::Post::MathProcessor LaTeXML::Post::LaTeXImages);

sub new {
  my ($class, %options) = @_;
  $options{resource_directory} = 'mi' unless defined $options{resource_directory};
  $options{resource_prefix}    = 'mi' unless defined $options{resource_prefix};
  #  return $class->SUPER::new(%options); }
  # Dangerous, since multiple inheritance!
  return $class->LaTeXML::Post::LaTeXImages::new(%options); }

#======================================================================

# Return the list of Math nodes.
sub toProcess {
  my ($self, $doc) = @_;
  return $doc->findnodes('//ltx:Math'); }

# Return the TeX string to format the image for this node.
sub extractTeX {
  my ($self, $doc, $node) = @_;
  my $mode = uc($node->getAttribute('mode') || 'INLINE');
  my $tex = $self->cleanTeX($node->getAttribute('tex'));
  return unless defined $tex;
  $mode = 'DISPLAY' if $tex =~ s/^\s*\\displaystyle\s+//;    # Strip leading displaystyle
  return ($tex =~ /^\s*$/ ? undef : "\\begin$mode $tex\\end$mode"); }

my $MML_NAMESPACE = "http://www.w3.org/1998/Math/MathML";    # [CONSTANT]

# Don't set the image attributes, will be handled by math postprocessing.
sub setTeXImage {
  return; }

our %MIMETYPES = (gif => 'image/gif', jpeg => 'image/jpeg', png => 'image/png', svg => 'image/svg+xml');

sub preprocess {
  my ($self, $doc, @nodes) = @_;
  return $self->generateImages($doc, @nodes); }

# RIDICULOUS amount of work to look up the image that was previously generated!!!
sub convertNode {
  my ($self, $doc, $xmath, $style) = @_;
  my $math = $xmath->parentNode;
  my $tex  = $self->extractTeX($doc, $math);
  my $type = $$self{imagetype};
  #  next if !(defined $tex) || ($tex =~ /^\s*$/);
  my $key = (ref $self) . ':' . $type . ':' . $tex;
  if (($doc->cacheLookup($key) || '') =~ /^(.*);(\d+);(\d+);(\d+)$/) {
    my ($image, $width, $height, $depth) = ($1, $2, $3, $4);
    # Ideally, $image is already relative, but if not, make relative to document
    my $reldest = pathname_relative($image, $doc->getDestinationDirectory);
    return { processor => $self, mimetype => $MIMETYPES{$type},
      src => $reldest, width => $width, height => $height, depth => $depth }; }
  else {
    print STDERR "Couldn't find image for '$key'\n";
    return {}; } }

# Definitions needed for processing inline & display math images
sub preamble {
  my ($self, $doc) = @_;
  return <<'EOPreamble';
\def\beginINLINE{\lxBeginImage\(}
\def\endINLINE{\)\lxEndImage\lxShowImage}
% For Display, same as inline, but set displaystyle.
\def\beginDISPLAY{\lxBeginImage\(\displaystyle\the\everydisplay}
\def\endDISPLAY{\)\lxEndImage\lxShowImage}
EOPreamble
}
#======================================================================
1;
