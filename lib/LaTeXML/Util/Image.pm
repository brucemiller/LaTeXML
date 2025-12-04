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
use LaTeXML::Global;
use LaTeXML::Common::Error;
use LaTeXML::Common::Dimension;
use LaTeXML::Util::Pathname;
use List::Util qw(first min max pairfirst pairgrep);
use Image::Size;
use POSIX;
use base qw(Exporter);
our @EXPORT = (
  qw( &image_candidates &image_type &image_size ),
  qw( &image_classes &image_can_image &image_object ),
  qw( &image_write ),
  qw( &image_graphicx_parse &image_graphicx_is_trivial &image_graphicx_trivialize
    &image_graphicx_size &image_graphicx_trivial &image_graphicx_complex),
  qw( &image_graphicx_sizer),
);
# The initial idea here is to form a minimal interface to image operations
# and to shield LaTeXML from the 'unreliable' Image::Magick;
# Namely, it is hard to rely on as a dependency, since it is often
# difficult to port, or has mismatched versions or whatever.
# We do, at least, need to be able to get image size.....

our $DPI        = 100;          # [CONSTANT]
our $BACKGROUND = "#FFFFFF";    # [CONSTANT]

# Return cleaned-up path and list of candidate image files
# {We could, but dont, filter out non-image types, since extensions are so inconsistent.
# although we could query image_type which is more thorough)
sub image_candidates {
  my ($path) = @_;
  $path =~ s/^\s+//; $path =~ s/\s+$//;
  $path =~ s/^("+)(.+)\g1$/$2/;    # unwrap if in quotes
  my $searchpaths = [@{ $STATE->lookupValue('GRAPHICSPATHS') || [] },
    @{ $STATE->lookupValue('SEARCHPATHS') || [] }];
  my @candidates = pathname_findall($path, types => ['*'], paths => $searchpaths);
  if (!@candidates) {
    # if we have no candidates, also consult kpsewhich,
    # e.g. for "example-image-a"
    if (my $kpse_found = pathname_kpsewhich("$path.png", "$path.pdf")) {
      @candidates = ($kpse_found); } }
  if (my $base = $STATE->lookupValue('SOURCEDIRECTORY')) {
    @candidates = map { pathname_relative($_, $base) } @candidates; }
  return ($path, @candidates); }

# These environment variables can be used to limit the amount
# of time & space used by ImageMagick.  They are particularly useful
# when ghostscript becomes involved in converting postscript or pdf.
# HOWEVER, there are indications that the time limit (at least)
# is being measured against the whole latexml process, not just image processing.
# Thus they aren't really that useful here.
# They probably are useful in a server context, however, so I'll leave the comments.
# $ENV{MAGICK_DISK_LIMIT} = "2GiB" unless defined $ENV{MAGICK_DISK_LIMIT};
# $ENV{MAGICK_MEMORY_LIMIT} = "512MiB" unless defined $ENV{MAGICK_MEMORY_LIMIT};
# $ENV{MAGICK_MAP_LIMIT} = "1GiB" unless defined $ENV{MAGICK_MAP_LIMIT};
# $ENV{MAGICK_TIME_LIMIT} = "300" unless defined $ENV{MAGICK_TIME_LIMIT};

# Note that Image::Size may, itself, use Image::Magick, if available,
# as a fallback for getting image size & type!!!
# However, it seems not to recognize file types with extension .EPS (uppercase), eg!
sub image_type {
  my ($pathname) = @_;
  my ($w, $h, $t) = imgsize($pathname);
  # even though Image::Size CLAIMS to use Image::Magick as fallback... needs tickling?
  if (!(defined $w) && !(defined $h) && image_can_image()) {    # try harder!
    my $image = image_read($pathname) or return;
    ($t) = image_getvalue($image, 'format'); }
  # Note that Image::Magick (sometimes) returns "descriptive" types
  # (but I can't find a list anywhere!)
  $t = 'eps' if $t && $t =~ /postscript/i;
  return (defined $t ? lc($t) : undef); }

sub image_size {
  my ($pathname, $page) = @_;
  # Annoyingly, ImageMagick uses the MediaBox instead of CropBox (as does graphics.sty) for pdfs.
  # Worse, imgsize delegates to ImageMagick, w/o ability to add options
  if (($pathname =~ /\.pdf$/i) && image_can_image()) {
    my $image = image_read($pathname, page => $page) or return;
    return image_getvalue($image, 'width', 'height'); }
  my ($w, $h, $t) = imgsize($pathname) unless defined $page;
  return ($w, $h) if $w && $h;
  if (image_can_image()) {    # try harder!
    my $image = image_read($pathname, page => $page) or return;
    return image_getvalue($image, 'width', 'height'); } }

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
      my $object = eval {
        local $LaTeXML::IGNORE_ERRORS = 1;
        require $module; $class->new(); };
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

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Working with Image transformation options from the graphic(s|x) packages
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Note that viewport is supposed to be relative to bounding box,
# and EITHER ONE can cause clipping, if clip=true.
# However, apparently the INTENT of bounding box is simply to
# supply one, if one can't be found, in order to determine the image size.
# In our case, we may end up getting a gif, jpeg, etc, whose origin is always 0,0,
# and whose size is clear; also postscript figures sizes will be determined
# by ghostview(?).  Another use of setting a bounding box, when clip=false,
# is to make the image lay ontop of neighboring text.  This isn't quite
# possible in HTML, other than possibly through some tricky CSS.
# Besides, I'd like to avoid reading the bb file, if I can.
# --- So, for all these reasons, we simply ignore bounding box here.

sub image_graphicx_parse {
  my ($transformstring, %options) = @_;
  return [] unless $transformstring;
  local $_ = $_;
  my ($v, $clip, $trim, $width, $height, $xscale, $yscale,
    $aspect, $angle, $rotfirst, $mag, @bb, @vp, $page,) = ('', '', '', 0, 0, 0, 0, '', 0, '', 1, 0);
  my @unknown = ();
  my @ignore  = @{ $options{ignore_options} || [] };
  foreach (split(/(?<!\\),/, $transformstring || '')) {
    if (/^\s*(\w+)(?:=\s*(.*))?\s*$/) {
      $_ = $1; $v = $2 || ''; $v =~ s/\\,/,/g;
      my $op = $_;
      if (grep { $op eq $_ } @ignore) { }                          # Ignore this option
      elsif (/^bb$/)                  { @bb                 = map { to_bp($_) } split(' ', $v); }
      elsif (/^bb(?:ll|ur)(?:x|y)$/)  { $bb[2 * /ur/ + /y/] = to_bp($v); }
      elsif (/^nat(?:width|height)$/) { $bb[2 + /width/]    = to_bp($v); }
      elsif (/^viewport$/)            { @vp = map { to_bp($_) } split(' ', $v); $trim = 0; }
      elsif (/^trim$/)                { @vp = map { to_bp($_) } split(' ', $v); $trim = 1; }
      elsif (/^clip$/)                { $clip   = !($v eq 'false'); }
      elsif (/^keepaspectratio$/)     { $aspect = !($v eq 'false'); }
      elsif (/^width$/)               { $width  = to_bp($v); }
      elsif (/^(?:total)?height$/)    { $height = to_bp($v); }
      elsif (/^page$/)                { $page   = $v; }
      elsif (/^scale$/)               { $xscale = $yscale = $v; }
      elsif (/^xscale$/)              { $xscale = $v; }
      elsif (/^yscale$/)              { $yscale = $v; }
      elsif (/^angle$/)         { $angle = $v; $rotfirst = !($width || $height || $xscale || $yscale); }
      elsif (/^origin$/)        { }                                # ??
                                                                   # Non-standard option
      elsif (/^magnification$/) { $mag = $v; }
      else                      { push(@unknown, [$op, $v]); } }
    else { } }                                                     # ?
      # --------------------------------------------------
      # Now, compile the options into a sequence of `transformations'.
      # Note: the order of rotation & scaling is significant,
      # but the order of various clipping options w.r.t rotation or scaling is not.
  my @transform = ();
  push(@transform, ['page', $page]) if $page;
  # If clip is set, viewport and trim will clip the image to that box,
  # but if not, they should ONLY affect the apparent size of the image.
  # Anything outside the box will *overlap* any adjacent material.
  # That's tricky to do in html, but possible with some fancy, brittle, CSS ....
  # For now, I guess we'll just clip in all cases.
  push(@transform, [($trim ? 'trim' : 'clip'), @vp]) if @vp;
  push(@transform, ['rotate', $angle]) if ($rotfirst && $angle);     # Rotate before scaling?
  if ($width && $height) { push(@transform, ['scale-to', $mag * $width, $mag * $height, $aspect]); }
  elsif ($width)         { push(@transform, ['scale-to', $mag * $width, 999999, 1]); }
  elsif ($height)        { push(@transform, ['scale-to', 999999, $mag * $height, 1]); }
  elsif ($xscale && $yscale) { push(@transform, ['scale', $mag * $xscale, $mag * $yscale]); }
  elsif ($xscale)            { push(@transform, ['scale', $mag * $xscale, $mag]); }
  elsif ($yscale)            { push(@transform, ['scale', $mag, $mag * $yscale]); }
  elsif ($mag != 1)          { push(@transform, ['scale', $mag, $mag]); }
  push(@transform, ['rotate', $angle]) if (!$rotfirst && $angle);    # Rotate after scaling?
                                                                     #  ----------------------
  return [@transform, @unknown]; }

my %BP_conversions = (                                               # CONSTANT
  pt => 72 / 72.27, pc => 12 / 72.27, in => 72, bp => 1,
  cm => 72 / 2.54,  mm => 72 / 25.4,  dd => (72 / 72.27) * (1238 / 1157),
  cc => 12 * (72 / 72.27) * (1238 / 1157), sp => 72 / 72.27 / 65536);

sub to_bp {
  my ($x) = @_;
  if ($x =~ /^\s*([+-]?[\d\.]+)(\w*)\s*$/) {
    my ($v, $u) = ($1, $2);
    $u =~ s/^true//;
    return $v * (($u && $BP_conversions{$u}) || 1); }
  else {
    return 1; } }

sub image_graphicx_page {
  my ($transform) = @_;
  my $page = first { $_->[0] eq 'page' } @$transform;
  return defined $page ? $page->[1] : undef; }

#======================================================================
# Compute the effective size of a graphic transformed in graphicx style.
# [this is a simplification of image_graphicx_complex]
# Note: This is not (yet) using any of the magnify/upscale parameters; Should it?
sub image_graphicx_size {
  my ($source, $transform, %properties) = @_;
  my $dppt = ($properties{DPI} || $DPI) / 72.27;
  my $page = image_graphicx_page($transform);
  my ($w, $h) = image_size($source, $page);
  return unless $w && $h;
  foreach my $trans (@$transform) {
    my ($op, $a1, $a2, $a3, $a4) = @$trans;
    if ($op eq 'scale') {    # $a1 => scale
      ($w, $h) = (ceil($w * $a1), ceil($h * ($a2 || $a1))); }
    elsif ($op eq 'scale-to') {
      # $a1 => width (pts), $a2 => height (pts), $a3 => preserve aspect ratio.
      if ($a3) {             # If keeping aspect ratio, ignore the most extreme request
        return unless $w && $h;
        if ($a1 / $w < $a2 / $h) { $a2 = $h * $a1 / $w; }
        else                     { $a1 = $w * $a2 / $h; } }
      ($w, $h) = (ceil($a1 * $dppt), ceil($a2 * $dppt)); }
    elsif ($op eq 'rotate') {
      my $rad = -$a1 * 3.1415926 / 180;    # close enough
      my $s   = sin($rad);
      my $c   = cos($rad);
      ($w, $h) = (abs($w * $c) + abs($h * $s), abs($w * $s) + abs($h * $c)); }
    elsif ($op eq 'reflect') { }
    # In the following two, note that TeX's coordinates are relative to lower left corner,
    # but ImageMagick's coordinates are relative to upper left.
    elsif (($op eq 'trim') || ($op eq 'clip')) {
      my ($x0, $y0, $ww, $hh);
      if ($op eq 'trim') {    # Amount to trim: a1=left, a2=bottom, a3=right, a4=top
        ($x0, $y0, $ww, $hh) = (floor($a1 * $dppt), floor($a4 * $dppt),
          ceil($w - ($a1 + $a3) * $dppt), ceil($h - ($a4 + $a2) * $dppt)); }
      else {                  # BBox: a1=left, a2=bottom, a3=right, a4=top
        ($x0, $y0, $ww, $hh) = (floor($a1 * $dppt), floor($h - $a4 * $dppt),
          ceil(($a3 - $a1) * $dppt), ceil(($a4 - $a2) * $dppt)); }
      ($w, $h) = ($ww, $hh);
    } }
  return ($w, $h); }

# Totally doesn't belong here, but want to share...
sub image_graphicx_sizer {
  my ($whatsit) = @_;
  if (my $candidates = $whatsit->getProperty('candidates')) {
    my $dpi = ($STATE && $STATE->lookupValue('DPI')) || $DPI;
    foreach my $source (split(/,/, $candidates)) {
      if (!pathname_is_absolute($source)) {
        if (my $base = $STATE->lookupValue('SOURCEDIRECTORY')) {
          $source = pathname_concat($base, $source); } }
      # Skip anything that a lower level imgsize can't understand
      my $options = $whatsit->getProperty('options');
      local $LaTeXML::IGNORE_ERRORS = 1;
      my ($w, $h) = image_graphicx_size($source, image_graphicx_parse($options), DPI => $dpi);
      return (Dimension($w * 72.27 / $dpi . 'pt'), Dimension($h * 72.27 / $dpi . 'pt'), Dimension(0)) if $w; } }
  return (Dimension(0), Dimension(0), Dimension(0)); }

#======================================================================
# Trivial scaling.
# When an image can be dealt with by simple scaling without "editing" the image.
# Compute the desired image size (width,height)
# No need to necessarily read the image!

# Check if the transform (parsed from above) is trivial
# at most scaling; no rotations, reflections, clipping or page selection.
sub image_graphicx_is_trivial {
  my ($transform) = @_;
  return !grep { ($_->[0] =~ /^(?:rotate|reflect|trim|clip|page)$/) } @$transform; }

# Make the transform (parsed from above) trivial
# by removing any non-scaling operations!
sub image_graphicx_trivialize {
  my ($transform) = @_;
  return [grep { ($_->[0] =~ /^scale/) } @$transform]; }

# trivial_scaling: for transforms containing ONLY scale, scale-to
sub image_graphicx_trivial {
  my ($source, $transform, %properties) = @_;
  my $page = image_graphicx_page($transform);
  my ($w, $h) = image_size($source, $page);
  return unless $w && $h;
  my $dppt = ($properties{DPI} || $DPI) / 72.27;
  foreach my $trans (@$transform) {
    my ($op, $a1, $a2, $a3, $a4) = @$trans;
    if ($op eq 'scale') {    # $a1 => scale
      ($w, $h) = (ceil($w * $a1), ceil($h * ($a2 || $a1))); }
    elsif ($op eq 'scale-to') {    # $a1 => width, $a2 => height, $a3 => preserve aspect ratio.
      if ($a3) {                   # If keeping aspect ratio, ignore the most extreme request
        if ($a1 / $w < $a2 / $h) { $a2 = $h * $a1 / $w; }
        else                     { $a1 = $w * $a2 / $h; } }
      ($w, $h) = (ceil($a1 * $dppt), ceil($a2 * $dppt)); } }
  return ($w, $h); }

#======================================================================
# Transform the image, returning (image,width,height);
# complex transform for transforms containing ONLY
#   scale, scale-to, rotate, reflect, trim, clip.
sub image_graphicx_complex {
  my ($source, $transform, %properties) = @_;
  my $dpi      = ($properties{DPI} || $DPI);
  my $magnify  = $properties{magnify}  || 1;
  my $upsample = $properties{upsample} || 2;
  my $zoomout  = $properties{zoomout}  || 1;
  my ($xprescale, $yprescale) = (1, 1);

  # # Wastefully preread the image to get it's initial size
  my $page = image_graphicx_page($transform);
  my ($w0, $h0) = image_size($source, $page);
  return unless $w0 && $h0;
  Debug("Processing $source initially $w0 x $h0,"
      . "w/ DPI=$dpi, magnify=$magnify, upsample=$upsample, zoomout=$zoomout") if $LaTeXML::DEBUG{images};
  my @transform = @$transform;
  # Establish the scaling necessary to carry out the transformation w/o loosing resolution
  # This is particularly for vector formats before rasterizing.
  # If image is vector & transform starts with scaling, rasterize at at least desired size
  # We REALLY should go through the ENTIRE transformation detecting the scaling,
  # but it's tricky to account for the prescale when carrying out the actual transformation!
  if ($properties{prescale}) {
    while (@transform && ($transform[0]->[0] =~ /^scale/)) {
      my ($op, $a1, $a2, $a3, $a4) = @{ shift(@transform) };
      if ($op eq 'scale') {    # $a1 => scale
        $xprescale *= $a1; $yprescale *= ($a2 || $a1); }
      elsif ($op eq 'scale-to') {
        # $a1 => width (pts), $a2 => height (pts), $a3 => preserve aspect ratio.
        if ($a3) {             # If keeping aspect ratio, ignore the most extreme request
          if ($a1 / $w0 < $a2 / $h0) { $a2 = $h0 * $a1 / $w0; }
          else                       { $a1 = $w0 * $a2 / $h0; } }
        $xprescale *= $a1 * $dpi / $w0 / 72.27; $yprescale *= $a2 * $dpi / $h0 / 72.27; } }
    Debug("Prescaling factors $xprescale x $yprescale") if $LaTeXML::DEBUG{images}; }
  # At this point, we conceivably could clamp the resolution to limit
  # to a maximum (or minimum) size, either for display or to reduce needed resources.
  # We'd presumably want to adjust (one of) the scaling factors.
  $dpi *= $magnify * $upsample;
  my $background = $properties{background} || $BACKGROUND;
  my $image      = image_read($source, (defined $page ? (page => $page) : ()), antialias => 1,
    density => $dpi * $xprescale . 'x' . $dpi * $yprescale,
  ) or return;
  my ($w, $h) = image_getvalue($image, 'width', 'height');
  # Get some defaults from the read-in image.
  my ($imagedpi) = image_getvalue($image, 'x-resolution');
  # image_setvalue($image,debug=>'exception');
  my ($bg) = image_getvalue($image, 'mattecolor');
  $background = "rgba($bg)" if $bg;    # Use background from image, if any.
  my ($hasalpha) = image_getvalue($image, 'matte');
  Debug("Read $source to $w x $h") if $LaTeXML::DEBUG{images};

  if ($properties{autocrop}) {
    image_internalop($image, 'Trim') or return;
    ($w, $h) = image_getvalue($image, 'width', 'height');
    Debug("  Autocrop to $w x $h") if $LaTeXML::DEBUG{images}; }

  my $orig_ncolors = image_getvalue($image, 'colors');

  if (!$orig_ncolors || !($w && $h)) {
    Debug("  Image is now empty; skipping") if $LaTeXML::DEBUG{images};
    return; }

  foreach my $trans (@transform) {
    my ($op, $a1, $a2, $a3, $a4) = @$trans;
    return unless $w && $h;
    if ($op eq 'scale') {    # $a1 => scale
      ($w, $h) = (ceil($w * $a1), ceil($h * ($a2 || $a1)));
      return unless $w && $h;
      image_internalop($image, 'Scale', width => $w, height => $h) or return;
      Debug("  Scale by $a1 " . ($a2 ? " x $a2" : '') . " => $w x $h") if $LaTeXML::DEBUG{images}; }
    elsif ($op eq 'scale-to') {
      # $a1 => width (pts), $a2 => height (pts), $a3 => preserve aspect ratio.
      if ($a3) {    # If keeping aspect ratio, ignore the most extreme request
        if ($a1 / $w < $a2 / $h) { $a2 = $h * $a1 / $w; }
        else                     { $a1 = $w * $a2 / $h; } }
      ($w, $h) = (ceil($a1 * $dpi / 72.27), ceil($a2 * $dpi / 72.27));
      image_internalop($image, 'Scale', width => $w, height => $h) or return;
      Debug("  Scale to $w x $h") if $LaTeXML::DEBUG{images}; }
    elsif ($op eq 'rotate') {
      image_internalop($image, 'Rotate', degrees => -$a1, background => $background) or return;
      ($w, $h) = image_getvalue($image, 'width', 'height');
      return unless $w && $h;
      Debug("  Rotate by $a1 => $w x $h") if $LaTeXML::DEBUG{images}; }
    elsif ($op eq 'reflect') {
      image_internalop($image, 'Flop') or return;
      Debug("  Reflext image => $w x $h") if $LaTeXML::DEBUG{images}; }
    # In the following two, note that TeX's coordinates are relative to lower left corner,
    # but ImageMagick's coordinates are relative to upper left.
    elsif (($op eq 'trim') || ($op eq 'clip')) {
      my ($x0, $y0, $ww, $hh);
      # Use the image's dpi for trim & clip!
      my $idppt = (defined $imagedpi ? $imagedpi : $dpi) / 72.27;
      if ($op eq 'trim') {    # Amount to trim: a1=left, a2=bottom, a3=right, a4=top
        ($x0, $y0, $ww, $hh) = (floor($a1 * $idppt), floor($a4 * $idppt),
          ceil($w - ($a1 + $a3) * $idppt), ceil($h - ($a4 + $a2) * $idppt)); }
      else {                  # BBox: a1=left, a2=bottom, a3=right, a4=top
        ($x0, $y0, $ww, $hh) = (floor($a1 * $idppt), floor($h - $a4 * $idppt),
          ceil(($a3 - $a1) * $idppt), ceil(($a4 - $a2) * $idppt)); }

      if (($x0 > 0) || ($y0 > 0) || ($x0 + $ww < $w) || ($y0 + $hh < $h)) {
        my $x0p = max($x0, 0); $x0 = min($x0, 0);
        my $y0p = max($y0, 0); $y0 = min($y0, 0);
        image_internalop($image, 'Crop', x => $x0p, width => min($ww, $w - $x0p),
          y => $y0p, height => min($hh, $h - $y0p)) or return;
        $w = min($ww + $x0, $w - $x0p);
        $h = min($hh + $y0, $h - $y0p);
        Debug("  Trim/Clip to $w x $h @ $x0p, $y0p") if $LaTeXML::DEBUG{images}; }
      # No direct `padding' operation in ImageMagick
      # BUT, trim & clip really shouldn't need to pad???
      # And besides, this composition seems to mangle the colormap (depending on background)
      # my $nimage = image_read("xc:$background", size => "$ww x $hh") or return;
      # image_internalop($nimage, 'Composite', image => $image, compose => 'over',
      #                  x => -$x0, y => -$y0) or return;
      # $notes .= " compose to $ww x $hh at $x0,$y0";
      # $image = $nimage;
      # ($w, $h) = ($ww, $hh);
    } }

  if ($properties{transparent} && !$hasalpha) {
    image_internalop($image, 'Transparent', $background) or return; }

  if (my $curr_ncolors = image_getvalue($image, 'colors')) {
    if (my $req_ncolors = $properties{ncolors}) {
      $req_ncolors = int($orig_ncolors * $1 / 100) if $req_ncolors =~ /^([\d]*)\%$/;
      if ($req_ncolors < $curr_ncolors) {
        image_internalop($image, 'Quantize', colors => $req_ncolors) or return; } } }

  if (my $quality = $properties{quality}) {
    image_setvalue($image, quality => $properties{quality}) or return; }

  if ($properties{prescale} && ($upsample != 1)) {    # Now downsample IF actually upsampled!
    image_internalop($image, 'Scale', geometry => $w / $upsample . 'x' . $h / $upsample) or return;
    ($w, $h) = image_getvalue($image, 'width', 'height');
    Debug("  Downsampled to $w x $h") if $LaTeXML::DEBUG{images}; }

  my ($watt, $hatt) = ($w / $zoomout, $h / $zoomout);
  Debug("Transformed $source final size $w x $h, displayed as $watt x $hatt") if $LaTeXML::DEBUG{images};
  return ($image, $watt, $hatt); }

# Wrap up ImageMagick's methods to give more useful & consistent error handling.
# These all return non-zero on success!
# so, you generally want to do image_internalop(...) or return;

# This reads a new image, setting the given properties BEFORE ingesting the image data.
sub image_read {
  my ($source, @args) = @_;
  if (!$source) {
    Error('imageprocessing', 'read', undef, "No image source given"); return; }
  return unless $source;
  my ($page_key, $page) = pairfirst { $a eq 'page' } @args;
  @args = pairgrep { $a ne 'page' } @args if defined $page_key;
  $page = ($page // 1) - 1;    # graphicx counts pages from 1, ImageMagick from 0
  my $image = image_object();
  # Just in case this is pdf, set this option; ImageMagick defaults to MediaBox (Wrong!!!)
  image_internalop($image, 'Set',  option => 'pdf:use-cropbox=true') or return;
  image_internalop($image, 'Set',  @args)                            or return;
  image_internalop($image, 'Read', $source . "[$page]")              or return;
  return $image; }

sub image_write {
  my ($image, $destination) = @_;
  if (!$image) {
    Error('imageprocessing', 'write', undef, "No image object!"); return; }
  if (!$destination) {
    Error('imageprocessing', 'write', undef, "No image destination!"); return; }
  # In the perverse case that we've ended up with a sequence of images; flatten them.
  if (@$image > 1) {
    my $fimage = $image->Flatten();    # Just in case we ended up with pieces!?!?!?
    $image = $fimage if $fimage; }
  return image_internalop($image, 'Write', filename => $destination); }

sub image_getvalue {
  my ($image, @args) = @_;
  if (!$image) {
    Error('imageprocessing', 'getvalue', undef, "No image object!"); return; }
  my @values = $image->Get(@args);
  return @values; }

sub image_setvalue {
  my ($image, @args) = @_;
  if (!$image) {
    Error('imageprocessing', 'setvalue', undef, "No image object!"); return; }
  return image_internalop($image, 'Set', @args); }

# Apparently ignorable warnings from Image::Magick
our %ignorable = map { $_ => 1; } (
  350,    # profile 'icc' not permitted on grayscale PNG
);

sub image_internalop {
  my ($image, $operation, @args) = @_;
  if (!$image) {
    Error('imageprocessing', 'internal', undef, "No image object!"); return; }
  my $retval = $image->$operation(@args);
  return 1 unless $retval;
  my $retcode = 999;
  if ($retval =~ /(\d+)/) {
    $retcode = $1; }
  if ($retcode < 400) {    # Warning
    Warn('imageprocessing', $operation, undef,
      "Image processing operation $operation (" . join(', ', @args) . ") returned $retval")
      unless $ignorable{$retcode};
    return 1; }
  else {                   # Error
    Error('imageprocessing', $operation, undef,
      "Image processing operation $operation (" . join(', ', @args) . ") returned $retval");
    return 0; } }

#======================================================================
1;
