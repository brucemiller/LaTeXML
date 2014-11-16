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
use List::Util qw(min max);
use Image::Size;
use POSIX;
use base qw(Exporter);
our @EXPORT = (
  qw( &image_type &image_size ),
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

our $DPI            = 90;               # [CONSTANT]
our $DOTS_PER_POINT = ($DPI / 72.0);    # [CONSTANT] Dots per point.
our $BACKGROUND     = "#FFFFFF";        # [CONSTANT]

# Note that Image::Size my, itself, use Image::Magick, if available,
# as a fallback for getting image size & type!!!
sub image_type {
  my ($pathname) = @_;
  my ($w, $h, $t) = imgsize($pathname);
  return lc($t); }

sub image_size {
  my ($pathname) = @_;
  my ($w, $h, $t) = imgsize($pathname);
  return ($w, $h) if $w && $h;
  if (image_can_image()) {    # try harder!
    my $image = image_read($pathname) or return;
    return image_getvalue($image, 'width', 'height'); } }

# This will be set once we've found an Image processing library to use [Daemon safe]
our $IMAGECLASS;              # cached class if we found one that works. [CONFIGURABLE?]
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
    $aspect, $angle, $rotfirst, $mag, @bb, @vp,) = ('', '', '', 0, 0, 0, 0, '', 0, '', 1, 0);
  my @unknown = ();
  my @ignore = @{ $options{ignore_options} || [] };
  foreach (split(',', $transformstring || '')) {
    if (/^\s*(\w+)(?:=\s*(.*))?\s*$/) {
      $_ = $1; $v = $2 || '';
      my $op = $_;
      if (grep { $op eq $_ } @ignore) { }    # Ignore this option
      elsif (/^bb$/) { @bb = map { to_bp($_) } split(' ', $v); }
      elsif (/^bb(?:ll|ur)(?:x|y)$/) { $bb[2 * /ur/ + /y/] = to_bp($v); }
      elsif (/^nat(?:width|height)$/) { $bb[2 + /width/] = to_bp($v); }
      elsif (/^viewport$/) { @vp = map { to_bp($_) } split(' ', $v); $trim = 0; }
      elsif (/^trim$/)     { @vp = map { to_bp($_) } split(' ', $v); $trim = 1; }
      elsif (/^clip$/)             { $clip   = !($v eq 'false'); }
      elsif (/^keepaspectratio$/)  { $aspect = !($v eq 'false'); }
      elsif (/^width$/)            { $width  = to_bp($v); }
      elsif (/^(?:total)?height$/) { $height = to_bp($v); }
      elsif (/^scale$/)            { $xscale = $yscale = $v; }
      elsif (/^xscale$/)           { $xscale = $v; }
      elsif (/^yscale$/)           { $yscale = $v; }
      elsif (/^angle$/) { $angle = $v; $rotfirst = !($width || $height || $xscale || $yscale); }
      elsif (/^origin$/)        { }              # ??
                                                 # Non-standard option
      elsif (/^magnification$/) { $mag = $v; }
      else { push(@unknown, [$op, $v]); } }
    else { } }                                   # ?
      # --------------------------------------------------
      # Now, compile the options into a sequence of `transformations'.
      # Note: the order of rotation & scaling is significant,
      # but the order of various clipping options w.r.t rotation or scaling is not.
  my @transform = ();
  # We ignore viewport & trim if clip isn't set, since in that case we shouldn't
  # actually remove anything from the image (and there's no way to have the image
  # overlap neighboring text, etc, in current HTML).
  push(@transform, [($trim ? 'trim' : 'clip'), @vp]) if (@vp && $clip);
  push(@transform, ['rotate', $angle]) if ($rotfirst && $angle);    # Rotate before scaling?
  if ($width && $height) { push(@transform, ['scale-to', $mag * $width, $mag * $height, $aspect]); }
  elsif ($width)  { push(@transform, ['scale-to', $mag * $width, 999999,         1]); }
  elsif ($height) { push(@transform, ['scale-to', 999999,        $mag * $height, 1]); }
  elsif ($xscale && $yscale) { push(@transform, ['scale', $mag * $xscale, $mag * $yscale]); }
  elsif ($xscale)   { push(@transform, ['scale', $mag * $xscale, $mag]); }
  elsif ($yscale)   { push(@transform, ['scale', $mag,           $mag * $yscale]); }
  elsif ($mag != 1) { push(@transform, ['scale', $mag,           $mag]); }
  push(@transform, ['rotate', $angle]) if (!$rotfirst && $angle);    # Rotate after scaling?
                                                                     #  ----------------------
  return [@transform, @unknown]; }

my %BP_conversions = (                                               # CONSTANT
  pt => 72 / 72.27, pc => 12 / 72.27, in => 72, bp => 1,
  cm => 72 / 2.54, mm => 72 / 25.4, dd => (72 / 72.27) * (1238 / 1157),
  cc => 12 * (72 / 72.27) * (1238 / 1157), sp => 72 / 72.27 / 65536);

sub to_bp {
  my ($x) = @_;
  if ($x =~ /^\s*([+-]?[\d\.]+)(\w*)\s*$/) {
    my ($v, $u) = ($1, $2);
    return $v * ($u ? $BP_conversions{$u} : 1); }
  else {
    return 1; } }

#======================================================================
# Compute the effective size of a graphic transformed in graphicx style.
# [this is a simplification of image_graphicx_complex]
sub image_graphicx_size {
  my ($source, $transform, %properties) = @_;
  my $dppt = $properties{dppt} || $DOTS_PER_POINT;
  my ($w, $h) = image_size($source);
  return unless $w && $h;
  foreach my $trans (@$transform) {
    my ($op, $a1, $a2, $a3, $a4) = @$trans;
    if ($op eq 'scale') {    # $a1 => scale
      ($w, $h) = (ceil($w * $a1), ceil($h * ($a2 || $a1))); }
    elsif ($op eq 'scale-to') {
      # $a1 => width (pts), $a2 => height (pts), $a3 => preserve aspect ratio.
      if ($a3) {             # If keeping aspect ratio, ignore the most extreme request
        if ($a1 / $w < $a2 / $h) { $a2 = $h * $a1 / $w; }
        else { $a1 = $w * $a2 / $h; } }
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
    my ($source) = split(/,/, $candidates);
    if (!pathname_is_absolute($source)) {
      if (my $base = $STATE->lookupValue('SOURCEDIRECTORY')) {
        $source = pathname_concat($base, $source); } }
    my $options = $whatsit->getProperty('options');
    my ($w, $h) = image_graphicx_size($source, image_graphicx_parse($options));
    return (Dimension($w / $DOTS_PER_POINT . 'pt'), Dimension($h / $DOTS_PER_POINT . 'pt'), Dimension(0)) if $w; }
  return (Dimension(0), Dimension(0), Dimension(0)); }

#======================================================================
# Trivial scaling.
# When an image can be dealt with by simple scaling without "editting" the image.
# Compute the desired image size (width,height)
# No need to necessarily read the image!

# Check if the transform (parsed from above) is trivial
sub image_graphicx_is_trivial {
  my ($transform) = @_;
  return !grep { !($_->[0] =~ /^scale/) } @$transform; }

# Make the transform (parsed from above) trivial
# by removing any non-scaling operations!
sub image_graphicx_trivialize {
  my ($transform) = @_;
  return [grep { ($_->[0] =~ /^scale/) } @$transform]; }

# sub trivial_scaling {
sub image_graphicx_trivial {
  my ($source, $transform, %properties) = @_;
  my ($w, $h) = image_size($source);
  return unless $w && $h;
  my $dppt = $properties{dppt} || $DOTS_PER_POINT;
  foreach my $trans (@$transform) {
    my ($op, $a1, $a2, $a3, $a4) = @$trans;
    if ($op eq 'scale') {    # $a1 => scale
      ($w, $h) = (ceil($w * $a1), ceil($h * ($a2 || $a1))); }
    elsif ($op eq 'scale-to') {    # $a1 => width, $a2 => height, $a3 => preserve aspect ratio.
      if ($a3) {                   # If keeping aspect ratio, ignore the most extreme request
        if ($a1 / $w < $a2 / $h) { $a2 = $h * $a1 / $w; }
        else { $a1 = $w * $a2 / $h; } }
      ($w, $h) = (ceil($a1 * $dppt), ceil($a2 * $dppt)); } }
  return ($w, $h); }

#======================================================================
# Transform the image, returning (image,width,height);
# sub complex_transform {
sub image_graphicx_complex {
  my ($source, $transform, %properties) = @_;
  my $dppt       = $properties{dppt}       || $DOTS_PER_POINT;
  my $background = $properties{background} || $BACKGROUND;
  my $image = image_read($source, antialias => 1) or return;
  image_internalop($image, 'Trim') or return if $properties{autocrop};
  my $orig_ncolors = image_getvalue($image, 'colors');
  return unless $orig_ncolors;
  my ($w, $h) = image_getvalue($image, 'width', 'height');
  return unless $w && $h;
  my @transform = @$transform;
  # If native unit is points, we at least need to scale by dots/point.
  # [tho' other scalings may override this]
  if (($properties{unit} || 'pixel') eq 'point') {
    push(@transform, ['scale', $dppt, $dppt]); }

  # For prescaling, compute the desired size and re-read the image into that size,
  # with an appropriate density set.  This will give much better anti-aliasing.
  # Actually, we'll set the density & size up a further factor of $F, and then downscale.
  if ($properties{prescale}) {
    my ($w0, $h0) = ($w, $h);
    while (@transform && ($transform[0]->[0] =~ /^scale/)) {
      my ($op, $a1, $a2, $a3, $a4) = @{ shift(@transform) };
      if ($op eq 'scale') {    # $a1 => scale
        ($w, $h) = (ceil($w * $a1), ceil($h * ($a2 || $a1))); }
      elsif ($op eq 'scale-to') {
        # $a1 => width (pts), $a2 => height (pts), $a3 => preserve aspect ratio.
        if ($a3) {             # If keeping aspect ratio, ignore the most extreme request
          if ($a1 / $w < $a2 / $h) { $a2 = $h * $a1 / $w; }
          else { $a1 = $w * $a2 / $h; } }
        ($w, $h) = (ceil($a1 * $dppt), ceil($a2 * $dppt)); } }
    my $X = 4;                 # Expansion factor
    my ($dx, $dy) = (int($X * 72 * $w / $w0), int($X * 72 * $h / $h0));
    NoteProgressDetailed(" [reloading to desired size $w x $h (density = $dx x $dy)]");
    $image = image_read($source, antialias => 1, density => $dx . 'x' . $dy) or return;
    image_internalop($image, 'Trim') or return if $properties{autocrop};
    image_setvalue($image, colorspace => 'RGB') or return;
    image_internalop($image, 'Scale', geometry => int(100 / $X) . "%") or return;    # Now downscale.
    ($w, $h) = image_getvalue($image, 'width', 'height');
    return unless $w && $h; }

  my $notes = '';
  foreach my $trans (@transform) {
    my ($op, $a1, $a2, $a3, $a4) = @$trans;
    if ($op eq 'scale') {                                                            # $a1 => scale
      ($w, $h) = (ceil($w * $a1), ceil($h * ($a2 || $a1)));
      $notes .= " scale to $w x $h";
      image_internalop($image, 'Scale', width => $w, height => $h) or return; }
    elsif ($op eq 'scale-to') {
      # $a1 => width (pts), $a2 => height (pts), $a3 => preserve aspect ratio.
      if ($a3) {    # If keeping aspect ratio, ignore the most extreme request
        if ($a1 / $w < $a2 / $h) { $a2 = $h * $a1 / $w; }
        else { $a1 = $w * $a2 / $h; } }
      ($w, $h) = (ceil($a1 * $dppt), ceil($a2 * $dppt));
      $notes .= " scale-to $w x $h";
      image_internalop($image, 'Scale', width => $w, height => $h) or return; }
    elsif ($op eq 'rotate') {
      image_internalop($image, 'Rotate', degrees => -$a1, color => $background) or return;
      ($w, $h) = image_getvalue($image, 'width', 'height');
      return unless $w && $h;
      $notes .= " rotate $a1 to $w x $h"; }
    elsif ($op eq 'reflect') {
      image_internalop($image, 'Flop') or return;
      $notes .= " reflected"; }
    # In the following two, note that TeX's coordinates are relative to lower left corner,
    # but ImageMagick's coordinates are relative to upper left.
    elsif (($op eq 'trim') || ($op eq 'clip')) {
      my ($x0, $y0, $ww, $hh);
      if ($op eq 'trim') {    # Amount to trim: a1=left, a2=bottom, a3=right, a4=top
        ($x0, $y0, $ww, $hh) = (floor($a1 * $dppt), floor($a4 * $dppt),
          ceil($w - ($a1 + $a3) * $dppt), ceil($h - ($a4 + $a2) * $dppt));
        $notes .= " trim to $ww x $hh @ $x0,$y0"; }
      else {                  # BBox: a1=left, a2=bottom, a3=right, a4=top
        ($x0, $y0, $ww, $hh) = (floor($a1 * $dppt), floor($h - $a4 * $dppt),
          ceil(($a3 - $a1) * $dppt), ceil(($a4 - $a2) * $dppt));
        $notes .= " clip to $ww x $hh @ $x0,$y0"; }

      if (($x0 > 0) || ($y0 > 0) || ($x0 + $ww < $w) || ($y0 + $hh < $h)) {
        my $x0p = max($x0, 0); $x0 = min($x0, 0);
        my $y0p = max($y0, 0); $y0 = min($y0, 0);
        image_internalop($image, 'Crop', x => $x0p, width => min($ww, $w - $x0p),
          y => $y0p, height => min($hh, $h - $y0p)) or return;
        $w = min($ww + $x0, $w - $x0p);
        $h = min($hh + $y0, $h - $y0p);
        $notes .= " crop $w x $h @ $x0p,$y0p"; }
      # No direct `padding' operation in ImageMagick
      my $nimage = image_read("xc:$background", size => "$ww x $hh") or return;
      image_internalop($nimage, 'Composite', image => $image, compose => 'over', x => -$x0, y => -$y0) or return;
      $image = $nimage;
      ($w, $h) = ($ww, $hh);
    } }
  if (my $trans = $properties{transparent}) {
    $notes .= " transparent=$background";
    image_internalop($image, 'Transparent', $background) or return; }

  if (my $curr_ncolors = image_getvalue($image, 'colors')) {
    if (my $req_ncolors = $properties{ncolors}) {
      $req_ncolors = int($orig_ncolors * $1 / 100) if $req_ncolors =~ /^([\d]*)\%$/;
      if ($req_ncolors < $curr_ncolors) {
        $notes .= " quantize $orig_ncolors => $req_ncolors";
        image_internalop($image, 'Quantize', colors => $req_ncolors) or return; } } }

  if (my $quality = $properties{quality}) {
    $notes .= " quality=$quality";
    image_setvalue($image, quality => $properties{quality}) or return; }

  NoteProgressDetailed(" [Transformed : $notes]") if $notes;
  return ($image, $w, $h); }

# Wrap up ImageMagick's methods to give more useful & consistent error handling.
# These all return non-zero on success!
# so, you generally want to do image_internalop(...) or return;

# This reads a new image, setting the given properties BEFORE ingesting the image data.
sub image_read {
  my ($source, @args) = @_;
  if (!$source) {
    Error('imageprocessing', 'read', undef, "No image source given"); return; }
  return unless $source;
  my $image = image_object();
  image_internalop($image, 'Set',  @args)   or return;
  image_internalop($image, 'Read', $source) or return;
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
      "Image processing operation $operation (" . join(', ', @args) . ") returned $retval");
    return 1; }
  else {                   # Error
    Error('imageprocessing', $operation, undef,
      "Image processing operation $operation (" . join(', ', @args) . ") returned $retval");
    return 0; } }

#======================================================================
1;
