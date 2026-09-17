#======================================================================
# Unit test for selecting the image processing class via LATEXML_IMAGECLASS
# (does not require any image processing library to be installed)
#======================================================================

use Test::More;
BEGIN { use_ok('LaTeXML::Util::Image'); }

my @known = qw(Graphics::Magick Image::Magick);

# Without the environment variable, all known classes are candidates.
delete $ENV{LATEXML_IMAGECLASS};
is_deeply([image_classes()], \@known, "All known classes are candidates by default");

# Recognized values are normalized to the canonical class name.
foreach my $pair (['Image::Magick', 'Image::Magick'], ['imagemagick', 'Image::Magick'],
  [' ImageMagick ', 'Image::Magick'], ['Graphics::Magick', 'Graphics::Magick'],
  ['GRAPHICSMAGICK', 'Graphics::Magick']) {
  my ($value, $expected) = @$pair;
  local $ENV{LATEXML_IMAGECLASS} = $value;
  is_deeply([image_classes()], [$expected], "LATEXML_IMAGECLASS='$value' selects $expected"); }

# An unrecognized value disables image processing entirely (no fallback).
{
  local $ENV{LATEXML_IMAGECLASS} = 'Nonsense::Class';
  local $LaTeXML::Util::Image::IMAGECLASS = undef;
  is_deeply([image_classes()], \@known, "Unrecognized value leaves the list of installable classes");
  is(image_can_image(), undef, "Unrecognized LATEXML_IMAGECLASS disables image processing");
  is(image_object(),    undef, "No image object with unrecognized LATEXML_IMAGECLASS"); }

# A requested class is honored (if it can be loaded), and only that class is tried.
{
  local $ENV{LATEXML_IMAGECLASS} = 'imagemagick';
  local $LaTeXML::Util::Image::IMAGECLASS = undef;
  my $class = image_can_image();
  if ($class) {
    is($class, 'Image::Magick', "Requested class is used when available"); }
  else {
    diag("Skip: Image::Magick is not installed");
    ok(!eval { require Image::Magick; 1 }, "No class when the requested class can't be loaded"); } }

done_testing();
