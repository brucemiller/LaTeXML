# /=====================================================================\ #
# |  LaTeXML::Util::Image                                               | #
# | Image support for LaTeXML                                           | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Util::Image;
use strict;
use warnings;
use Image::Size;
use base qw(Exporter);
our @EXPORT = (
  qw( &image_type &image_size ),
  qw( &image_classes &image_can_image &image_object ),
);
# The initial idea here is to form a minimal interface to image operations
# and to shield LaTeXML from the 'unreliable' Image::Magick;
# Namely, it is hard to rely on as a dependency, since it is often
# difficult to port, or has mismatched versions or whatever.
# We do, at least, need to be able to get image size.....

# Note that Image::Size my, itself, use Image::Magick, if available,
# as a fallback for getting image size & type!!!
sub image_type {
  my ($pathname) = @_;
  my ($w, $h, $t) = imgsize($pathname);
  return lc($t); }

sub image_size {
  my ($pathname) = @_;
  my ($w, $h, $t) = imgsize($pathname);
  return ($w, $h); }

# This will be set once we've found an Image processing library to use [Daemon safe]
our $IMAGECLASS;    # cached class if we found one that works. [CONFIGURABLE?]
my @MagickClasses = (qw(Graphics::Magick Image::Magick));    # CONSTANT

sub image_classes {
  return @MagickClasses; }

sub image_can_image {
  my ($pathname) = @_;
  if (!$IMAGECLASS) {
    foreach my $class (@MagickClasses) {
      my $module = $class . ".pm";
      $module =~ s/::/\//g;
      my $object = eval { local $SIG{__DIE__} = undef; require $module; $class->new(); };
      if ($object) {
        $IMAGECLASS = $class;
        last; } } }
  return $IMAGECLASS; }

# return an image object (into which you can read), if possible.
sub image_object {
  my (%properties) = @_;
  return unless image_can_image();
  my $image = $IMAGECLASS->new(%properties);
  return $image; }

#======================================================================
1;
