#======================================================================
# Unit test for LaTeXML's optional image conversion capability
#======================================================================

use Test::More;
BEGIN { use_ok('LaTeXML::Util::Image'); }

my $image_converter = image_object();
my $is_image_magick = $image_converter && ((ref $image_converter) eq "Image::Magick");
if (!$is_image_magick) {
  diag("Skip: This unit test only examines basic Image::Magick conversion, when installed."); }
else {
  # try converting a sample PDF image
  my $pdf_image = "t/unit/triangle.pdf";
  my $png_target = "t/unit/triangle.png";
  my $conversion_ok = 0;
  if (image_type($pdf_image) eq "portable document format") {
    my ($loaded_image, $w, $h) = image_graphicx_complex($pdf_image, []);
    if (ref $loaded_image eq "Image::Magick" and $w > 0 and $h > 0) {
      image_write($loaded_image,$png_target);
      if (-f $png_target) {
        # if we *can* convert, make sure the PNG has some size
        ok((-s $png_target) > 0,
          "PDF to PNG conversion did not produce an image of non-zero size");
        unlink($png_target) if -f $png_target;
        $conversion_ok = 1; } } }
  if (!$conversion_ok) {
    # if we *can't* convert, and Image::Magick is installed, warn about the config issues.
    diag("Image::Magick is installed, but a simple PDF to PNG conversion fails.\n"
    . "\tConsider changing the policy.xml permissions to enable the feature.\n"
    . "\tFor details, see https://github.com/brucemiller/LaTeXML/issues/1216"); } }

done_testing();