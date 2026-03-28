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
use LaTeXML::Util::Image;
use LaTeXML::Post;
use base qw(LaTeXML::Post::Processor);

#======================================================================
# Options:
#   DPI : dots per inch for target medium.
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
  $$self{DPI}             = $options{DPI};
  $$self{ignore_options}  = $options{ignore_options}  || [];
  $$self{trivial_scaling} = $options{trivial_scaling} || 1;
  $$self{graphics_types}  = $options{graphics_types}
    || [qw(svg png gif jpg jpeg
      eps ps postscript ai pdf)];
  $$self{type_properties} = $options{type_properties}
    || {
    ai => { destination_type => 'png',
      transparent => 1,
      prescale    => 1, ncolors => '400%', quality => 90, unit => 'point' },
    pdf => { destination_type => 'png',
      transparent => 1,
      prescale    => 1, ncolors => '400%', quality => 90, unit => 'point' },
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
  Debug(" [Using graphicspaths: "
      . join(', ', @$LaTeXML::Post::Graphics::SEARCHPATHS) . "]") if $LaTeXML::DEBUG{images};
  foreach my $node (@nodes) {
    $self->processGraphic($doc, $node); }
  $doc->closeCache;    # If opened.
  return $doc; }

# Need a proper API to query PI's, probably in Post
# But Core isn't respecting @at@document@begin from preloaded packages,
# so here we're testing BOTH a straight DPI PI and the options from latexml.sty (ugh)
sub getParameter {
  my ($self, $doc, $parameter) = @_;
  my $value;
  foreach my $pi (@{ $$doc{processingInstructions} }) {
    if ($pi =~ /^\s*$parameter\s*=\s*([\"\'])(.*?)\1\s*$/) {
      $value = $2; }
    elsif ($pi =~ /^\s*package\s*=\s*([\"\'])latexml\1\s*options\s*=\s*([\"\'])(.*?)\2\s*$/i) {
      my $options = $3;
      if ($options =~ /\b$parameter\s*=\s*(\d+)\b/i) {
        $value = $1; } } }
  return $value || $$self{$parameter}; }

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
  return @{ $$self{graphics_types} }, map { uc($_); } @{ $$self{graphics_types} }; }

# Return the pathname to an appropriate image.
sub findGraphicFile {
  my ($self, $doc, $node) = @_;
  if (my $source = $node->getAttribute('graphic')) {
    # if we already have a usable candidate, save ourselves the work
    my @paths = grep { pathname_test_e($_) } split(',', $node->getAttribute('candidates') || '');
    if (!scalar(@paths)) {
      # Find all acceptable image files, in order of search paths
      my ($dir, $name, $reqtype) = pathname_split($source);
      # Ignore the requested type? Or should it increase desirability?
      #
      # If this is *NOT* a known graphics type, it would be best to treat it as
      # a name suffix (e.g. name.1 from name.1.png)
      if ((length($reqtype) > 0) && !(grep { $_ eq lc($reqtype) } $$self{graphics_types})) {
        $name .= ".$reqtype"; }
      my $file = pathname_concat($dir, $name);
      @paths = pathname_findall($file, paths => $LaTeXML::Post::Graphics::SEARCHPATHS,
        # accept empty type, incase bad type name, but actual file's content is known type.
        types => ['', $self->getGraphicsSourceTypes]);
    }
    my ($best, $bestpath) = (-1, undef);
    # Now, find the first image that is either the correct type,
    # or has the most desirable type mapping
    foreach my $path (@paths) {
      my $type         = pathname_type($path);
      my $props        = $$self{type_properties}{$type};
      my $desirability = $$props{desirability} || ($type eq ($$props{destination_type} || 'notype') ? 10 : 0);
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
  return ($options ? image_graphicx_parse($options) : []); }

# Get a hash of the image processing properties to be applied to this image.
sub getTypeProperties {
  my ($self, $source, $options) = @_;
  my ($dir,  $name,   $ext)     = pathname_split($source);
  my $props = $$self{type_properties}{ lc($ext) };
  if (!$props) {
    # If we don't have a known file type, try a bit harder (maybe less efficient)
    if (my $type = image_type($source)) {
      $props = $$self{type_properties}{ lc($type) }; } }
  return ($props ? %$props : ()); }

# Set the attributes of the graphics node to record the image file name,
# width and height.
sub setGraphicSrc {
  my ($self, $node, $src, $width, $height) = @_;
  # If we are on windows, the $src path will be used for a URI context from the 'imagesrc' attribute,
  # so we can already switch it to the canonical slashified form
  $node->setAttribute('imagesrc', pathname_to_url($src));
  if (defined $width) {
    # final formats mostly expect numeric literals to be integers
    $width = int($width) if ($width =~ /^\d*\.\d*$/);
    $node->setAttribute('imagewidth', $width); }
  if (defined $height) {
    # final formats mostly expect numeric literals to be integers
    $height = int($height) if ($height =~ /^\d*\.\d*$/);
    $node->setAttribute('imageheight', $height); }
  if ($width and $height) {
    my $aspect_class = "ltx_img_square";
    if ($width > 1.24 * $height) {
      $aspect_class = "ltx_img_landscape"; }
    elsif ($height > 1.24 * $width) {
      $aspect_class = "ltx_img_portrait" }
    my $class = $node->getAttribute('class');
    $class = ($class ? $class . ' ' : '') . $aspect_class;
    $node->setAttribute('class', $class); }
  return; }

sub processGraphic {
  my ($self, $doc, $node) = @_;
  my $source = $self->findGraphicFile($doc, $node);
  if (!$source) {
    Warn('expected', 'source', $node, "No graphic source found; skipping",
      "source was " . ($node->getAttribute('graphic') || 'none'));
    $node->setAttribute('imagesrc', $node->getAttribute('graphic'));
    return; }
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
  my @parameters = (
    DPI      => $self->getParameter($doc, 'DPI') || $LaTeXML::Util::Image::DPI,
    magnify  => $self->getParameter($doc, 'magnify'),
    upsample => $self->getParameter($doc, 'upsample'),
    zoomout  => $self->getParameter($doc, 'zoomout'));
  my $sourcedir = $doc->getSourceDirectory;
  ($sourcedir) = $doc->getSearchPaths unless $sourcedir;    # Fishing...
  my ($reldir, $name, $srctype)
    = pathname_split(pathname_relative($source, $sourcedir));
  my %properties = $self->getTypeProperties($source, $transform);
  return Warn('unexpected', 'graphics_format', undef,
    "Don't know what to do with graphics file format '$source'") unless %properties;
  my $type = $properties{destination_type} || $srctype;
  my $key  = (ref $self) . ':' . join('|', "$reldir$name.$srctype.$type",
    map { join(' ', @$_) } @$transform);
  Debug("Processing $source as key=$key") if $LaTeXML::DEBUG{images};

  my $dest = $self->desiredResourcePathname($doc, $node, $source, $type);
  if (my $prev = $doc->cacheLookup($key)) {                 # Image was processed on previous run?
    if ($prev =~ /^(.*?)\|(\d*)\|(\d*)$/) {
      my ($cached, $width, $height) = ($1, $2, $3);
      $width  = undef unless $width;
      $height = undef unless $height;
      # If so, check that it is still there, up to date, etc.
      if ((!defined $dest) || ($cached eq $dest)) {
        my $absdest = pathname_absolute($cached, $doc->getDestinationDirectory);
        if (pathname_timestamp($source) <= pathname_timestamp($absdest)) {
          Debug(" [Reuse $cached @ " . ($width || '?') . " x " . ($height || '?') . "]")
            if $LaTeXML::DEBUG{images};
          return ($cached, $width, $height); } } } }
  # Trivial scaling case: Use original image with (at most) different width & height.
  my $triv_scaling = $$self{trivial_scaling} && ($type eq $srctype)
    && image_graphicx_is_trivial($transform);
  # But first check if we have the capabilities to do complex scaling!
  if (!$triv_scaling && (defined $properties{raster}) && !$properties{raster}) {
    Warn("limitation", $source, undef,
      "Cannot (yet) apply complex transforms to non-raster images",
      join(',', map { join(' ', @$_) } grep { !($_->[0] =~ /^scale/) } @$transform));
    $triv_scaling = 1;
    $transform    = image_graphicx_trivialize($transform); }
  if (!image_can_image()) {
    if ($type ne $srctype) {
      Error('imageprocessing', 'imageclass', undef,
        "No image processing module found to convert types",
        "Skipping $source=>$type.",
        "Please install one of: " . join(',', image_classes()));
      return; }
    elsif (!$triv_scaling) {
      Error('imageprocessing', 'imageclass', undef,
        "No image processing module found for complex transformations",
        "Simplifying transformation of $source.",
        "Please install one of: " . join(',', image_classes()));
      $triv_scaling = 1;
      $transform    = image_graphicx_trivialize($transform); }
  }
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
      $dest    = $self->generateResourcePathname($doc, $node, $source, $type);
      $absdest = $doc->checkDestination($dest); }

    Debug(" [Destination $absdest]") if $LaTeXML::DEBUG{images};
    ($width, $height) = image_graphicx_trivial($source, $transform, @parameters);
    if (!($width && $height)) {
      if (!image_can_image()) {
        Warn('imageprocessing', 'imagesize', undef,
          "No image processing module found for image sizing",
          "Will omit image size for $source",
          "Please install one of: " . join(',', image_classes())); }
      else {
        Warn('expected', 'image', undef,
          "Couldn't get usable image size for $source"); } }
    pathname_copy($source, $absdest)
      or Warn('I/O', $absdest, undef, "Couldn't copy $source to $absdest", "Response was: $!");
    Debug(" [Copied to $dest @ " . ($width || '?') . " x " . ($height || '?') . "]")
      if $LaTeXML::DEBUG{images}; }
  else {
    # With a complex transformation, we really needs a new name (well, don't we?)
    $dest = $self->generateResourcePathname($doc, $node, $source, $type) unless $dest;
    my $absdest = $doc->checkDestination($dest);
    Debug(" [Destination $absdest]") if $LaTeXML::DEBUG{images};
    ($image, $width, $height) = image_graphicx_complex($source, $transform,
      @parameters, background => $$self{background}, %properties);
    if (!($image && $width && $height)) {
      Warn('expected', 'image', undef,
        "Couldn't get usable image for $source");
      return; }
    Debug(" [Writing to $absdest]") if $LaTeXML::DEBUG{images};
    image_write($image, $absdest) or return; }

  $doc->cacheStore($key, "$dest|" . ($width || '') . '|' . ($height || ''));
  Debug(" [done with $key]") if $LaTeXML::DEBUG{images};
  return ($dest, $width, $height); }

#======================================================================
1;
