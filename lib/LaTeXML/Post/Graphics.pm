# /=====================================================================\ #
# |  LaTeXML::Post::Graphics                                            | #
# | Graphics postprocessing for LaTeXML                                 | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
#======================================================================
# Adapted from graphics-support.perl of LaTeX2HTML (which I had rewritten)
#======================================================================
package LaTeXML::Post::Graphics;
use strict;
use warnings;
use LaTeXML::Util::Pathname;
use POSIX;
use Image::Magick;
use LaTeXML::Post;
use base qw(LaTeXML::Post::Processor);

#======================================================================
# Options:
#   dpi : dots per inch for target medium.
#   ignore_options  : list of graphicx options to be ignored.
#   warn_options    : list of graphicx options to cause warning if used.
#   trivial_scaling : If true, web images that only need scaling will be used as-is
#                     assuming the user agent scale the image.
#   background      : background color when filling or transparency.
#   type_properties : hash of types=>hash.
#        The hash for each type can have the following
#           destination_type : the type to convert the file to if different.
#           transparent : if true, the background color will be made transparent.
#           quality     : the `quality' used for the image.
#           ncolors     : the image will be quantized to ncolors.
#           prescale    : If true, and there are leading (or only) scaling commands,
#                         compute the new image size and re-read the image into that size
#                         This is useful for getting the best antialiasing for postscript, eg.
#          unit= (pixel|point) :  What unit the image size is given in.
#          autocrop     : if the image should be cropped (trimmed) when loaded.
#          desirability : a number indicating how good of a mapping this entry is.
#                         This helps choose between two sources that can map to the
#                         same destination type.
#                         An entry whose source & destination types are the same
#                         has desirability=10.

sub new {
  my ($class, %options) = @_;
  my $self = $class->SUPER::new(%options);
  $$self{dppt} = (($options{dpi} || 90) / 72.0);    # Dots per point.
  $$self{ignore_options}  = $options{ignore_options}  || [];
  $$self{trivial_scaling} = $options{trivial_scaling} || 1;
  $$self{graphics_types}  = $options{graphics_types}
    || [qw(svg png gif jpg jpeg
      eps ps ai pdf)];
  $$self{type_properties} = $options{type_properties}
    || {
    ai => { destination_type => 'png',
      transparent => 1,
      prescale => 1, ncolors => '400%', quality => 90, unit => 'point' },
    pdf => { destination_type => 'png',
      transparent => 1,
      prescale => 1, ncolors => '400%', quality => 90, unit => 'point' },
    ps => { destination_type => 'png', transparent => 1,
      prescale => 1, ncolors => '400%', quality => 90, unit => 'point' },
    eps => { destination_type => 'png', transparent => 1,
      prescale => 1, ncolors => '400%', quality => 90, unit => 'point' },
    jpg => { destination_type => 'jpg',
      ncolors => '400%', unit => 'pixel' },
    jpeg => { destination_type => 'jpeg',
      ncolors => '400%', unit => 'pixel' },
    gif => { destination_type => 'gif', transparent => 1,
      ncolors => '400%', unit => 'pixel' },
    png => { destination_type => 'png', transparent => 1,
      ncolors => '400%', unit => 'pixel' },
    svg => { destination_type => 'svg',
      raster => 0, desirability => 11 },    # use these, as is
    };
  $$self{background} = $options{background} || "#FFFFFF";
  return $self; }

# Return a list of XML nodes which have graphics that need processing.
sub toProcess {
  my ($self, $doc) = @_;
  return $doc->findnodes('//ltx:graphics[not(@imagesrc)]'); }

sub process {
  my ($self, $doc, @nodes) = @_;
  local $LaTeXML::Post::Graphics::SEARCHPATHS
    = [map { pathname_canonical($_) } $self->findGraphicsPaths($doc), $doc->getSearchPaths];
  NoteProgressDetailed(" [Using graphicspaths: "
      . join(', ', @$LaTeXML::Post::Graphics::SEARCHPATHS) . "]");
  foreach my $node (@nodes) {
    $self->processGraphic($doc, $node); }
  $doc->closeCache;    # If opened.
  return $doc; }

#======================================================================
# Potentially customizable operations.
# find graphics file
#  Need to deal with source directory, as well as graphicspath.

# Extract any graphicspath PI's from the document and return a reference
# to a list of search paths.
sub findGraphicsPaths {
  my ($self, $doc) = @_;
  my @paths = ();
  foreach my $pi ($doc->findnodes('.//processing-instruction("latexml")')) {
    if ($pi->textContent =~ /^\s*graphicspath\s*=\s*([\"\'])(.*?)\1\s*$/) {
      push(@paths, $2); } }
  return @paths; }

sub getGraphicsSourceTypes {
  my ($self) = @_;
  return @{ $$self{graphics_types} }; }

# Return the pathname to an appropriate image.
sub findGraphicFile {
  my ($self, $doc, $node) = @_;
  if (my $name = $node->getAttribute('graphic')) {
    # Find all acceptable image files, in order of search paths
    my @paths = pathname_findall($name, paths => $LaTeXML::Post::Graphics::SEARCHPATHS,
      # accept empty type, incase bad type name, but actual file's content is known type.
      types => ['', $self->getGraphicsSourceTypes]);
    my ($best, $bestpath) = (-1, undef);
    # Now, find the first image that is either the correct type,
    # or has the most desirable type mapping
    foreach my $path (@paths) {
      my $type         = pathname_type($path);
      my $props        = $$self{type_properties}{$type};
      my $desirability = $$props{desirability} || ($type eq $$props{destination_type} ? 10 : 0);
      if ($desirability > $best) {
        $best     = $desirability;
        $bestpath = $path; } }
    return $bestpath; }
  else {
    return; } }

#======================================================================
# Return the Transform to be used for this node
# Default is based on parsing the graphicx options
sub getTransform {
  my ($self, $node) = @_;
  my $options = $node->getAttribute('options');
  return ($options ? $self->parseOptions($options) : []); }

# Get a hash of the image processing properties to be applied to this image.
sub getTypeProperties {
  my ($self, $source, $options) = @_;
  my ($dir,  $name,   $ext)     = pathname_split($source);
  my $props = $$self{type_properties}{$ext};
  if (!$props) {
    # If we don't have a known file type, load the image and see if we can extract it there.
    # This is probably grossly inefficient, maybe there's a better way to get image types...
    my ($image, $type);
    if (($image = $self->ImageRead(undef, $source)) && (($type) = $image->Get('magick'))) {
      $props = $$self{type_properties}{ lc($type) }; } }
  return ($props ? %$props : ()); }

# Set the attributes of the graphics node to record the image file name,
# width and height.
sub setGraphicSrc {
  my ($self, $node, $src, $width, $height) = @_;
  $node->setAttribute('imagesrc',    $src);
  $node->setAttribute('imagewidth',  $width);
  $node->setAttribute('imageheight', $height);
  return; }

sub processGraphic {
  my ($self, $doc, $node) = @_;
  my $source = $self->findGraphicFile($doc, $node);
  if (!$source) {
    Warn('expected', 'source', $node, "No graphic source specified; skipping"); return; }
  my $transform = $self->getTransform($node);
  my ($image, $width, $height) = $self->transformGraphic($doc, $node, $source, $transform);
  # $image should probably be relative already, except corner applications?
  # But definitely should be stored in doc relative to the doc itself!
  $self->setGraphicSrc($node, pathname_relative($image, $doc->getDestinationDirectory),
    $width, $height) if $image;
  return; }

#======================================================================

sub transformGraphic {
  my ($self, $doc, $node, $source, $transform) = @_;
  my $sourcedir = $doc->getSourceDirectory;
  ($sourcedir) = $doc->getSearchPaths unless $sourcedir;    # Fishing...
  my ($reldir, $name, $srctype)
    = pathname_split(pathname_relative($source, $sourcedir));
  my $key = (ref $self) . ':' . join('|', "$reldir$name.$srctype",
    map { join(' ', @$_) } @$transform);
  NoteProgressDetailed("\n[Processing $source as key=$key]");

  my %properties = $self->getTypeProperties($source, $transform);
  return Warn('unexpected', $source, undef,
    "Don't know what to do with graphics file format '$source'") unless %properties;
  my $type = $properties{destination_type} || $srctype;
  my $dest = $self->desiredResourcePathname($doc, $node, $source, $type);
  if (my $prev = $doc->cacheLookup($key)) {                 # Image was processed on previous run?
    if ($prev =~ /^(.*?)\|(\d+)\|(\d+)$/) {
      my ($cached, $width, $height) = ($1, $2, $3);
      # If so, check that it is still there, up to date, etc.
      if ((!defined $dest) || ($cached eq $dest)) {
        my $absdest = pathname_absolute($cached, $doc->getDestinationDirectory);
        if (pathname_timestamp($source) <= pathname_timestamp($absdest)) {
          NoteProgressDetailed(" [Reuse $cached @ $width x $height]");
          return ($cached, $width, $height); } } } }
  # Trivial scaling case: Use original image with (at most) different width & height.
  my $triv_scaling = $$self{trivial_scaling} && ($type eq $srctype)
    && !grep { !($_->[0] =~ /^scale/) } @$transform;
  if (!$triv_scaling && (defined $properties{raster}) && !$properties{raster}) {
    Warn("limitation", $source, undef,
      "Cannot (yet) apply complex transforms to non-raster images",
      join(',', map { join(' ', @$_) } grep { !($_->[0] =~ /^scale/) } @$transform));
    $triv_scaling = 1;
    $transform = [grep { ($_->[0] =~ /^scale/) } @$transform]; }
  my ($image, $width, $height);
  if ($triv_scaling) {
    # With a simple scaling transformation we can preserve path & file-names
    # But only if we can mimic the relative path in the site directory.
    # Get image source file relative to the document's source file
    $dest = pathname_relative($source, $doc->getSourceDirectory);
    # and it's (eventual) absolute path in the destination directory
    # assuming it had the same relative path from the destination file.
    my $absdest = pathname_absolute($dest, $doc->getDestinationDirectory);
    # Now IFF that is a valid relative path WITHIN the site directory, we'll use it.
    # Otherwise, we'd better fall back to a generated name.
    if (!pathname_is_contained($absdest, $doc->getSiteDirectory)) {
      $dest = $self->generateResourcePathname($doc, $node, $source, $type);
      $absdest = $doc->checkDestination($dest); }

    NoteProgressDetailed(" [Destination $absdest]");
    ($width, $height) = $self->trivial_scaling($doc, $source, $transform);
    return unless $width && $height;
    pathname_copy($source, $absdest)
      or Warn('I/O', $absdest, undef, "Couldn't copy $source to $absdest", "Response was: $!");
    NoteProgressDetailed(" [Copied to $dest for $width x $height]"); }
  else {
    # With a complex transformation, we really needs a new name (well, don't we?)
    $dest = $self->generateResourcePathname($doc, $node, $source, $type) unless $dest;
    my $absdest = $doc->checkDestination($dest);
    NoteProgressDetailed(" [Destination $absdest]");
    ($image, $width, $height) = $self->complex_transform($doc, $source, $transform, %properties);
    return unless $image && $width && $height;
    NoteProgressDetailed(" [Writing to $absdest]");
    $self->ImageWrite($doc, $image, $absdest) or return; }

  $doc->cacheStore($key, "$dest|$width|$height");
  NoteProgressDetailed(" [done with $key]");
  return ($dest, $width, $height); }

#======================================================================
# Compute the desired image size (width,height)
sub trivial_scaling {
  my ($self, $doc, $source, $transform) = @_;
  my $image = $self->ImageRead($doc, $source) or return;
  my ($w, $h) = $self->ImageGet($doc, $image, 'width', 'height');
  return unless $w && $h;
  foreach my $trans (@$transform) {
    my ($op, $a1, $a2, $a3, $a4) = @$trans;
    if ($op eq 'scale') {    # $a1 => scale
      ($w, $h) = (ceil($w * $a1), ceil($h * ($a2 || $a1))); }
    elsif ($op eq 'scale-to') {    # $a1 => width, $a2 => height, $a3 => preserve aspect ratio.
      if ($a3) {                   # If keeping aspect ratio, ignore the most extreme request
        if ($a1 / $w < $a2 / $h) { $a2 = $h * $a1 / $w; }
        else { $a1 = $w * $a2 / $h; } }
      ($w, $h) = (ceil($a1 * $$self{dppt}), ceil($a2 * $$self{dppt})); } }
  return ($w, $h); }

# Transform the image, returning (image,width,height);
sub complex_transform {
  my ($self, $doc, $source, $transform, %properties) = @_;
  my $image = $self->ImageRead($doc, $source, antialias => 1) or return;
  $self->ImageOp($doc, $image, 'Trim') or return if $properties{autocrop};
  my $orig_ncolors = $self->ImageGet($doc, $image, 'colors');
  return unless $orig_ncolors;
  my ($w, $h) = $self->ImageGet($doc, $image, 'width', 'height');
  return unless $w && $h;
  my @transform = @$transform;
  # If native unit is points, we at least need to scale by dots/point.
  # [tho' other scalings may override this]
  if (($properties{unit} || 'pixel') eq 'point') {
    push(@transform, ['scale', $$self{dppt}, $$self{dppt}]); }

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
        ($w, $h) = (ceil($a1 * $$self{dppt}), ceil($a2 * $$self{dppt})); } }
    my $X = 4;                 # Expansion factor
    my ($dx, $dy) = (int($X * 72 * $w / $w0), int($X * 72 * $h / $h0));
    NoteProgressDetailed(" [reloading to desired size $w x $h (density = $dx x $dy)]");
    $image = $self->ImageRead($doc, $source, antialias => 1, density => $dx . 'x' . $dy) or return;
    $self->ImageOp($doc, $image, 'Trim') or return if $properties{autocrop};
    $self->ImageSet($doc, $image, colorspace => 'RGB') or return;
    $self->ImageOp($doc, $image, 'Scale', geometry => int(100 / $X) . "%") or return;   # Now downscale.
    ($w, $h) = $self->ImageGet($doc, $image, 'width', 'height');
    return unless $w && $h; }

  my $notes = '';
  foreach my $trans (@transform) {
    my ($op, $a1, $a2, $a3, $a4) = @$trans;
    if ($op eq 'scale') {                                                               # $a1 => scale
      ($w, $h) = (ceil($w * $a1), ceil($h * ($a2 || $a1)));
      $notes .= " scale to $w x $h";
      $self->ImageOp($doc, $image, 'Scale', width => $w, height => $h) or return; }
    elsif ($op eq 'scale-to') {
      # $a1 => width (pts), $a2 => height (pts), $a3 => preserve aspect ratio.
      if ($a3) {    # If keeping aspect ratio, ignore the most extreme request
        if ($a1 / $w < $a2 / $h) { $a2 = $h * $a1 / $w; }
        else { $a1 = $w * $a2 / $h; } }
      ($w, $h) = (ceil($a1 * $$self{dppt}), ceil($a2 * $$self{dppt}));
      $notes .= " scale-to $w x $h";
      $self->ImageOp($doc, $image, 'Scale', width => $w, height => $h) or return; }
    elsif ($op eq 'rotate') {
      $self->ImageOp($doc, $image, 'Rotate', degrees => -$a1, color => $$self{background}) or return;
      ($w, $h) = $self->ImageGet($doc, $image, 'width', 'height');
      return unless $w && $h;
      $notes .= " rotate $a1 to $w x $h"; }
    elsif ($op eq 'reflect') {
      $self->ImageOp($doc, $image, 'Flop') or return;
      $notes .= " reflected"; }
    # In the following two, note that TeX's coordinates are relative to lower left corner,
    # but ImageMagick's coordinates are relative to upper left.
    elsif (($op eq 'trim') || ($op eq 'clip')) {
      my ($x0, $y0, $ww, $hh);
      if ($op eq 'trim') {    # Amount to trim: a1=left, a2=bottom, a3=right, a4=top
        ($x0, $y0, $ww, $hh) = (floor($a1 * $$self{dppt}), floor($a4 * $$self{dppt}),
          ceil($w - ($a1 + $a3) * $$self{dppt}), ceil($h - ($a4 + $a2) * $$self{dppt}));
        $notes .= " trim to $ww x $hh @ $x0,$y0"; }
      else {                  # BBox: a1=left, a2=bottom, a3=right, a4=top
        ($x0, $y0, $ww, $hh) = (floor($a1 * $$self{dppt}), floor($h - $a4 * $$self{dppt}),
          ceil(($a3 - $a1) * $$self{dppt}), ceil(($a4 - $a2) * $$self{dppt}));
        $notes .= " clip to $ww x $hh @ $x0,$y0"; }

      if (($x0 > 0) || ($y0 > 0) || ($x0 + $ww < $w) || ($y0 + $hh < $h)) {
        my $x0p = max($x0, 0); $x0 = min($x0, 0);
        my $y0p = max($y0, 0); $y0 = min($y0, 0);
        $self->ImageOp($doc, $image, 'Crop', x => $x0p, width => min($ww, $w - $x0p),
          y => $y0p, height => min($hh, $h - $y0p)) or return;
        $w = min($ww + $x0, $w - $x0p);
        $h = min($hh + $y0, $h - $y0p);
        $notes .= " crop $w x $h @ $x0p,$y0p"; }
      # No direct `padding' operation in ImageMagick
      my $nimage = $self->ImageRead($doc, "xc:$$self{background}", size => "$ww x $hh") or return;
      $self->ImageOp($doc, $nimage, 'Composite', image => $image, compose => 'over', x => -$x0, y => -$y0) or return;
      $image = $nimage;
      ($w, $h) = ($ww, $hh);
    } }
  if (my $trans = $properties{transparent}) {
    $notes .= " transparent=$$self{background}";
    $self->ImageOp($doc, $image, 'Transparent', $$self{background}) or return; }

  if (my $curr_ncolors = $self->ImageGet($doc, $image, 'colors')) {
    if (my $req_ncolors = $properties{ncolors}) {
      $req_ncolors = int($orig_ncolors * $1 / 100) if $req_ncolors =~ /^([\d]*)\%$/;
      if ($req_ncolors < $curr_ncolors) {
        $notes .= " quantize $orig_ncolors => $req_ncolors";
        $self->ImageOp($doc, $image, 'Quantize', colors => $req_ncolors) or return; } } }

  if (my $quality = $properties{quality}) {
    $notes .= " quality=$quality";
    $self->ImageSet($doc, $image, quality => $properties{quality}) or return; }

  NoteProgressDetailed(" [Transformed : $notes]") if $notes;
  return ($image, $w, $h); }

sub min {
  my ($x, $y) = @-;
  return ($x < $y ? $x : $y); }

sub max {
  my ($x, $y) = @-;
  return ($x > $y ? $x : $y); }

# Wrap up ImageMagick's methods to give more useful & consistent error handling.
# These all return non-zero on success!
# so, you generally want to do $self->ImageOp(...) or return;

# This reads a new image, setting the given properties BEFORE ingesting the image data.
sub ImageRead {
  my ($self, $doc, $source, @args) = @_;
  my $image = Image::Magick->new();
  $self->ImageOp($doc, $image, 'Set',  @args)   or return;
  $self->ImageOp($doc, $image, 'Read', $source) or return;
  return $image; }

sub ImageWrite {
  my ($self, $doc, $image, $destination) = @_;
  # In the perverse case that we've ended up with a sequence of images; flatten them.
  if (@$image > 1) {
    my $fimage = $image->Flatten();    # Just in case we ended up with pieces!?!?!?
    $image = $fimage if $fimage; }
  return $self->ImageOp($doc, $image, 'Write', filename => $destination) or return; }

sub ImageGet {
  my ($self, $doc, $image, @args) = @_;
  my @values = $image->Get(@args);
  return @values; }

sub ImageSet {
  my ($self, $doc, $image, @args) = @_;
  $self->ImageOp($doc, $image, 'Set', @args);
  return; }

sub ImageOp {
  my ($self, $doc, $image, $operation, @args) = @_;
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

#**********************************************************************
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

sub parseOptions {
  my ($self, $options) = @_;
  local $_;
  # --------------------------------------------------
  # Parse options
  my ($v, $clip, $trim, $width, $height, $xscale, $yscale, $aspect, $angle, $rotfirst, $mag, @bb, @vp,)
    = ('', '', '', 0, 0, 0, 0, '', 0, '', 1, 0);
  my @unknown = ();
  foreach (split(',', $options || '')) {
    if (/^\s*(\w+)(?:=\s*(.*))?\s*$/) {
      $_ = $1; $v = $2 || '';
      my $op = $_;
      if (grep { $op eq $_ } @{ $$self{ignore_options} }) { }    # Ignore this option
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

my %BP_conversions = (         # CONSTANT
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
1;
