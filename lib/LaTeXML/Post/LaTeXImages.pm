# /=====================================================================\ #
# |  LaTeXML::Post::LaTeXImages                                         | #
# | Abstract Postprocessor to create images from LaTeX code             | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post::LaTeXImages;
use strict;
use warnings;
use DB_File;
use Config;
use LaTeXML::Util::Image;
use POSIX qw(ceil);
use LaTeXML::Util::Pathname;
use File::Temp;
use File::Which;
use LaTeXML::Post;
use base qw(LaTeXML::Post::Processor);

#======================================================================

# Other silly constants that might want changing?
##our $TMP = '/tmp';
our $LATEXCMD = 'latex';    #(or elatex) [ CONFIGURABLE? Encoded in PI?]

# The purpose of this module is to convert TeX fragments into png (or similar),
# typically via dvi and other intermediate formats.
# LaTeX converts the TeX stuff to dvi;
# dvips converts the dvi to ps, and ghostscript converts to png
# then ImageMagick extracts the dimensions and converts from png if necessary
# OR dvipng can convert the dvi to png MUCH quicker... if it's available.
# OR dvisvgm for high quality SVG output, if available

# preview.sty is used to inform gs/dvipng/dvisvgm how to clip the image
# and recover the depth for vertical alignment

# Options:
#   source         : (dir)
#   magnification  : typically something like 1.33333, but you may want bigger
#   maxwidth       : maximum page width, in pixels (whenever line breaking is possible)
#   DPI            : assumed DPI for the target medium (default 96)
#   background     : color of background (for anti-aliasing, since it is made transparent)
#   imagetype      : typically 'png' or 'gif'.
sub new {
  my ($class, %options) = @_;
  my $self = $class->SUPER::new(%options);
  $$self{magnification} = $options{magnification} || 1.33333;
  $$self{maxwidth}      = $options{maxwidth}      || 800;
  $$self{DPI}           = $options{DPI}           || 96;
  $$self{background}    = $options{background}    || "#FFFFFF";
  $$self{imagetype}     = $options{imagetype}     || 'png';

  # desired padding between image edge and "ink"
  $$self{padding} = $options{padding} || 2;    # pixels
      # amount of extra space (+padding) to put between object & bounding box

  # Sanity check of dvi processing...
  # If trying to create svg...
  if (($$self{imagetype} eq 'svg') && (!defined $options{use_dvisvgm}) && which('dvisvgm')) {
    $$self{use_dvisvgm} = 1; }
  elsif ($$self{use_dvisvgm} && (($$self{imagetype} ne 'svg') || !which('dvisvgm'))) {
    $$self{use_dvisvgm} = 0; }    # but disable if inappropriate or unavailable
      # We'll use dvipng (MUCH faster) if requested or not forbidden & available.
      # But be careful: it can't handle much postscript, so better NOT for graphics!
  if (($$self{imagetype} eq 'png') && (!defined $options{use_dvipng}) && which('dvipng')) {
    $$self{use_dvipng} = 1; }
  elsif ($$self{use_dvipng} && (($$self{imagetype} ne 'png') || !which('dvipng'))) {
    $$self{use_dvipng} = 0; }    # but disable if inappropriate or unavailable.

  # Parameterize according to the selected dvi-to-whatever processor.
  my $dpi = int($$self{DPI} * $$self{magnification});
  # Unfortunately, each command has incompatible -o option to name the output file.
  # Note that the formatting char used, '%', has to be doubled on Windows!!
  # Maybe that's only true when it looks like an environment variable?
  # Ie. %variable% ?
  #  my $fmt = ($^O eq 'MSWin32' ? '%%' : '%');
  my $fmt = '%';
  if ($$self{use_dvisvgm}) {
    # dvisvgm currently creates glyph descriptions w/ unicode attribute having the wrong codepoint
    # firefox, chromium use this codepoint instead of the glyph "drawing"
    # a later version of dvisvgm should do better at synthesizing the unicode?
    # but for now, we'll use --no-fonts, which creates glyph drawings rather than "glyphs"
    # DVISVGM options:
    # --bbox=preview : use bounding box data computed by the preview package
    # --scale        : scale the page content (equivalent to -TS)
    # --exact-bbox   : compute the precise bounding box of each character
    # --no-fonts     : do not create SVG font elements but use paths instead
    $$self{dvicmd} = "dvisvgm --page=1- --bbox=preview --scale=$$self{magnification} --exact-bbox --no-fonts -o imgx-${fmt}3p";
    $$self{dvicmd_output_name} = 'imgx-%03d.svg';
    $$self{dvicmd_output_type} = 'svg'; }
  elsif ($$self{use_dvipng}) {
    # DVIPNG options:
    # -bg      : Background color
    # -D       : Output resolution
    # -q       : Quiet operation
    # --width  : Output the image width on stdout (in pixels)
    # --height : Output the image height on stdout (in pixels)
    # --depth  : Output the image depth on stdout (in pixels)
    $$self{dvicmd} = "dvipng -bg Transparent -D$dpi -q --width --height --depth -o imgx-${fmt}03d.png";
    $$self{dvicmd_output_name} = 'imgx-%03d.png';
    $$self{dvicmd_output_type} = 'png32'; }
  else {
    # will run dvips before $$self{dvicmd}
    $$self{use_dvips} = 1;
    # GS options:
    #  -q                   : quiet
    #  -sDEVICE=pngalpha    : set output to 32-bit RGBA PNG
    #  -r                   : resolution
    #  -dGraphicAlphaBits=4 : subsample antialiasing
    #  -dTextAlphaBits=4    : subsample antialiasing
    #  -dSAFER -dBATCH ...  : suppress interactivity and enable security checks
    # dvicmd will be filled by canProcess with the available ghostscript executable
    $$self{dvicmd_opts} = "-q -sDEVICE=pngalpha -r$$self{DPI}" .
      " -dGraphicsAlphaBits=4 -dTextAlphaBits=4 -dSAFER -dBATCH -dNOPAUSE" .
      " -sOutputFile=imgx-%03d.png";
    $$self{dvicmd_output_name} = 'imgx-%03d.png';
    $$self{dvicmd_output_type} = 'png32'; }
  return $self; }

#**********************************************************************
# Check whether this processor actually has the resources it needs to process.
# I don't know if there's a general API implied here;
# It could, conceivably be use in planning post processing?
# But generally, before signalling an error, you'd want to know that the processor
# is even needed.
# This test is called once we know that, from within
#
# NOTE: the test MUST be called if using ghostscript in order to find the
# correct executable on Windows.
#
# At any rate: To process LaTeX snippets into images, we will need
#  * latex (or related) from a TeX installation
#  * Image::Magick (or similar) [see LaTeXML::Util::Image]
#  * dvips and ghostscript if not using dvipng, dvisvgm
sub canProcess {
  my ($self) = @_;
  # Check if we have Image::Magick (or similar)
  if (!image_can_image()) {
    Error('expected', 'Image::Magick', undef,
      "No available image processing module found; Skipping.",
      "Please install one of: " . join(',', image_classes()));
    return; }
  # AND check if we have an approriprate latex!!!
  if (($LATEXCMD =~ /^(\S+)/) && !which($1)) {    # does the command seem to be available?
    Error('expected', $LATEXCMD, undef,
      "No latex command ($LATEXCMD) found; Skipping.",
      "Please install TeX to generate images from LaTeX");
    return; }
  # likewise for dvips and gs, if necessary
  if ($$self{use_dvips}) {
    if (!which('dvips')) {
      Error('expected', 'dvips', undef,
        "No dvips command found; Skipping.",
        "Please install dvisvgm, dvipng, or dvips and ghostscript to generate images from LaTeX");
      return; }
    else {
      # find ghostscript executable
      my @gscmd = grep { which $_ } ($^O eq 'MSWin32' ? ('gswin64c', 'gswin64', 'gswin32c', 'gswin32', 'mgs') : ('gs'));
      if (@gscmd) {
        $$self{dvicmd} = $gscmd[0] . ' ' . $$self{dvicmd_opts}; }
      else {
        Error('expected', 'gs', undef, "No ghostscript executable ("
            . ($^O eq 'MSWin32' ? 'gswin64c, gswin64, gswin32c, gswin32, mgs' : 'gs')
            . ") found; Skipping.", "Please install ghostscript to generate images from LaTeX");
        return; } } }
  return 1; }

#**********************************************************************
# Methods that must be defined;

# This is an abstract class; concrete classes must select the nodes to process.
# We'll still need to use $proc->extractTeX($doc,$node)
#  to extract the actual TeX string!
sub toProcess {
  return (); }

# $self->extractTeX($doc,$node)=>$texstring;
sub extractTeX {
  return ""; }

# $self->format_tex($texstring)
sub format_tex {
  return ""; }

# $self->setTeXImage($doc,$node,$imagepath,$width,$height);
# This is the default
sub setTeXImage {
  my ($self, $doc, $node, $path, $width, $height, $depth) = @_;
  $node->setAttribute('imagesrc',    pathname_to_url($path));
  $node->setAttribute('imagewidth',  $width);
  $node->setAttribute('imageheight', $height);
  $node->setAttribute('imagedepth',  $depth) if defined $depth;
  return; }

#======================================================================
# Methods that could be wrapped, overridden.

# Should be called by extractTeX
sub cleanTeX {
  my ($self, $tex) = @_;
  return unless defined $tex;
  my $style = '';
  # Save any leading style
  if ($tex =~ s/^\s*(\\displaystyle|\\textstyle|\\scriptstyle|\\scriptscriptstyle)\s*//) {
    $style = $1; }
  $tex =~ s/^(?:\\\s*,|\\!\s*|\\>\s*|\\;\s*|\\:\s*|\\ \s*|\\\/\s*)*//; # Trim leading spacing (especially negative!)
  $tex =~ s/(?:\\\s*,|\\!\s*|\\>\s*|\\;\s*|\\:\s*|\\ \s*|\\\/\s*)*$//;    # and trailing spacing
      # Strip comments, but watchout for \% (or more exactly, an ODD number of \)
  $tex =~ s/(?<!\\)((?:\\\\)*)\%[^\n]*\n/$1/gs;
  $tex = $style . ' ' . $tex if $style;    # Put back the style, if any
  return $tex; }

#**********************************************************************

#**********************************************************************
# Generating & Processing the LaTeX source.
#**********************************************************************
# Need the destination directory AND (optionally?) a subdir for the images.
# both are only used here.
# Alternatively, a dest for doc & dest for images ?
# What we really need to know is:
#   (1) where to write the images.
#   (2) relative path from doc to images.

# sub process {
#   my ($self, $doc, @nodes) = @_;
#   return $self->generateImages($doc, @nodes); }

sub generateImages {
  my ($self, $doc, @nodes) = @_;

  my $jobname  = "ltxmlimg";
  my $orig_cwd = pathname_cwd();
  my $sep      = $Config::Config{path_sep};
  my %table    = ();

  # === Get the desired nodes, extract the set of unique tex strings,
  #     noting which need processing.
  # Note that if desiredResourcePathname is implemented, we might get
  # several desired names for the same chunk of tex!!!
  my ($ntotal, $nuniq) = (0, 0);
  foreach my $node (@nodes) {
    my $tex = $self->extractTeX($doc, $node);
    next if !(defined $tex) || ($tex =~ /^\s*$/);
    $ntotal++;

    # Ideally, $dest is relative to document..
    my $dest = $self->desiredResourcePathname($doc, $node, undef, $$self{imagetype});
    #    my $key = (ref $self) . ":" . $tex . ($dest ? ":$dest" : '');
    my $key   = (ref $self) . ':' . $$self{imagetype} . ':' . $tex;
    my $entry = $table{$key};
    if (!$entry) {
      $nuniq++;
      $entry = $table{$key} = { tex => $tex, key => $key, nodes => [], dest => [] }; }
    # Why do I need to make things so complicated?!?!
    # It may be desired that a particular image gets a specific name.
    # AND, the same TeX may get different names, or some with & without names!!
    if ($dest && (!grep { $dest eq $_ } @{ $$entry{dest} })) {
      push(@{ $$entry{dest} }, $dest); }
    push(@{ $$entry{nodes} }, $node); }

  return $doc unless $nuniq;    # No strings to process!

  return unless $self->canProcess;

  # === Check which objects still need processing.
  my $destdir = $doc->getDestinationDirectory;
  my @pending = ();
  foreach my $key (sort keys %table) {
    my $store = $doc->cacheLookup($key);
    if ($store && ($store =~ /^(.*);(\d+);(\d+);(\d+)$/)) {
      next if -f pathname_absolute($1, $destdir); }
    push(@pending, $table{$key}); }

  Debug("LaTeXImages: $nuniq unique; " . scalar(@pending) . " new") if $LaTeXML::DEBUG{images};
  if (@pending) {    # if any images need processing
        # Create working directory; note TMPDIR attempts to put it in standard place (like /tmp/)
    File::Temp->safe_level(File::Temp::MEDIUM);
    my $workdir = File::Temp->newdir("LaTeXMLXXXXXX", TMPDIR => 1);
    # Obtain the search paths
    my @searchpaths       = $doc->getSearchPaths;
    my $installation_path = pathname_installation();
    # === Generate the LaTeX file.
    my $texfile = pathname_make(dir => $workdir, name => $jobname, type => 'tex');
    my $TEX;
    if (!open($TEX, '>', $texfile)) {
      Error('I/O', $texfile, undef, "Cant write to '$texfile'", "Response was: $!");
      return $doc; }
    my ($pre_preamble, $add_to_body) = $self->pre_preamble($doc);
    binmode $TEX, ':encoding(UTF-8)';
    print $TEX $pre_preamble if $pre_preamble;
    print $TEX "\\makeatletter\n";
    print $TEX $self->preamble($doc) . "\n";
    print $TEX "\\makeatother\n";
    print $TEX "\\begin{document}\n";
    print $TEX $add_to_body if $add_to_body;

    foreach my $entry (@pending) {
##      print TEX "\\fbox{$$entry{tex}}\\clearpage\n"; }
      print $TEX "$$entry{tex}\\clearpage\n"; }
    print $TEX "\\end{document}\n";
    close($TEX);

    # === Run LaTeX on the file.
    # (keep the command simple so it works in Windows)
    pathname_chdir($workdir);
    my $ltxcommand = "$LATEXCMD $jobname > $jobname.ltxoutput";
    my $ltxerr;
    {
      local $ENV{TEXINPUTS} = join($sep, '.', @searchpaths,
        pathname_concat($installation_path, 'texmf'),
        ($ENV{TEXINPUTS} || $sep));
      $ltxerr = system($ltxcommand);
    }
    pathname_chdir($orig_cwd);

    # Sometimes latex returns non-zero code, even though it apparently succeeded.
    # And sometimes it doesn't produce a dvi, even with 0 return code?
    if (($ltxerr != 0) || (!-f "$workdir/$jobname.dvi")) {
      $workdir->unlink_on_destroy(0) if $LaTeXML::DEBUG{images};    # Preserve junk
      Error('shell', $LATEXCMD, undef,
        "LaTeX command '$ltxcommand' failed",
        ($ltxerr == 0 ? "No dvi file generated" : "returned code $ltxerr (!= 0): $@"),
        ($LaTeXML::DEBUG{images}
          ? "See $workdir/$jobname.log"
          : "Re-run with --debug=images to see TeX log"));
      return $doc; }
    ### $workdir->unlink_on_destroy(0) if $LaTeXML::DEBUG{images}; # preserve ALL junk!?!?!

    if ($$self{use_dvips}) {
      # Useful DVIPS options:
      #  -q  : run quietly
      #  -x#  : magnification * 1000
      #  -j0  : don't subset fonts; silly really, but some font tests are making problems!
      my $mag          = int($$self{magnification} * 1000);
      my $dvipscommand = "dvips -q -j0 -x$mag -o $jobname.ps $jobname.dvi > $jobname.dvipsoutput";
      my $dvipserr     = 0;

      pathname_chdir($workdir);
      {
        local $ENV{TEXINPUTS} = join($sep, '.', @searchpaths,
          pathname_concat($installation_path, 'texmf'),
          ($ENV{TEXINPUTS} || $sep));
        $dvipserr = system($dvipscommand);
      }
      pathname_chdir($orig_cwd);

      if (($dvipserr != 0) || (!-f "$workdir/$jobname.ps")) {
        $workdir->unlink_on_destroy(0) if $LaTeXML::DEBUG{images};    # Preserve junk
        Error('shell', $dvipscommand, undef,
          "dvips command '$dvipscommand' failed",
          ($dvipserr == 0 ? "No ps file generated" : "returned code $dvipserr (!= 0): $@"),
          ($LaTeXML::DEBUG{images}
            ? "See $workdir/$jobname.log"
            : "Re-run with --debug=images to see TeX log"));
        return $doc; }
    }

    # Extract dimensions (width x height+depth) from each image from log file.
    my @dimensions = ();
    # Extract tightpage adjustments from preview.sty (left bottom right top)
    my @adjustments = (0, 0, 0, 0);
    my $LOG;
    if (open($LOG, '<', "$workdir/$jobname.log")) {
      while (<$LOG>) {
        # "Preview: Tightpage left bottom right top" (dimensions in sp)
        if (/^Preview: Tightpage (-?\d+) (-?\d+) (-?\d+) (-?\d+)$/) {
          @adjustments = ($1, $2, $3, $4); }
        # "Preview: Snippet count height depth width" (dimensions in sp)
        if (/^Preview: Snippet (\d+) (\d+) (\d+) (\d+)/) {
          # dimensions = bounding box + adjustments
          $dimensions[$1] = [($4 - $adjustments[0] + $adjustments[2]) / 65536,
            ($2 + $adjustments[3]) / 65536,
            ($3 - $adjustments[1]) / 65536]; } }
      close($LOG); }
    else {
      Warn('expected', 'dimensions', undef,
        "Couldn't read log file $workdir/$jobname.log to extract image dimensions",
        "Response was: $!"); }

    # === Run dvicmd to extract individual png|svg files.
    pathname_chdir($workdir);
    my $dvicommand = "$$self{dvicmd} $jobname." . ($$self{use_dvips} ? "ps" : "dvi") . " > $jobname.dvioutput 2>&1";
    my $dvierr;
    {
      local $ENV{TEXINPUTS} = join($sep, '.', @searchpaths,
        pathname_concat($installation_path, 'texmf'),
        ($ENV{TEXINPUTS} || $sep));
      $dvierr = system($dvicommand);
    }
    pathname_chdir($orig_cwd);

    if ($dvierr != 0) {
      Error('shell', $$self{dvicmd}, undef,
"Shell command '$dvicommand' (for " . ($$self{use_dvips} ? "ps" : "dvi") . " conversion) failed (see $workdir for clues)",
        "Response was: $!");
      return $doc; }

    # extract dimensions from command output
    if ($$self{use_dvipng} || $$self{use_dvisvgm}) {
      my $LOG;
      if (open($LOG, '<', "$workdir/$jobname.dvioutput")) {
        my $i = 0;    # image counter
        if ($$self{use_dvipng}) {
          # DVIPNG output:
          # This is /path/to/dvipng [...]
          #  depth=DD height=HH width=WW depth=DD height=HH width=WW [...]
          while (<$LOG>) {
            next if $. == 1;    # skip first line
            foreach (split(/depth=/)) {
              if (m/^(\d+) height=(\d+) width=(\d+)\s*$/) {
                $i++;
                $dimensions[$i] = [$3, $2, $1]; }
              else {
                Warn('unexpected', 'dvipng', undef, "Unrecognised entry in log file $workdir/$jobname.dvioutput while extracting image dimensions", $_) unless m/^\s*$/; } } } }
        else {
          while (<$LOG>) {
            # DVISVGM output:
            #  pre-processing DVI [...]
            #  processing page N
            #    applying bounding box set by preview package [...]
            #    width=W.WWpt, height=H.HHpt, depth=D.DDpt
            #    output written to [...]
            #  N of N page converted [...]
            next if $. == 1;
            if (m/^processing page (\d+)$/) {
              $i = $1; }
            elsif (m/^\s+width=(\d*(?:\.\d*)?)pt,\s+height=(\d*(?:\.\d*)?)pt,\s+depth=(\d*(?:\.\d*)?)pt$/) {
              $dimensions[$i] = [$1, $2, $3]; }
            elsif (!m/^\s+(?:applying bounding box|graphic size:|output written to)/) {
              Warn('unexpected', 'dvisvgm', undef, "Unrecognised entry in log file $workdir/$jobname.dvioutput while extracting image dimensions", $_) unless eof; } } }
        close($LOG); }
      else {
        Warn('expected', 'dimensions', undef,
          "Couldn't read log file $workdir/$jobname.dvioutput to extract image dimensions",
          "Response was: $!"); } }

    # === Convert each image to appropriate type and put in place.
    my $pixels_per_pt = $$self{magnification} * $$self{DPI} / 72.27;
    my ($index, $ndigits) = (0, 1 + int(log($doc->cacheLookup((ref $self) . ':_max_image_') || 1) / log(10)));
    foreach my $entry (@pending) {
      my $src = "$workdir/" . sprintf($$self{dvicmd_output_name}, ++$index);
      if (-f $src) {
        my @dests = @{ $$entry{dest} };
        push(@dests, $self->generateResourcePathname($doc, $$entry{nodes}[0], undef, $$self{imagetype}))
          unless @dests;
        foreach my $dest (@dests) {
          my $absdest = $doc->checkDestination($dest);
          my ($ww, $hh, $dd, $w, $h, $d);

          ($ww, $hh, $dd) = @{ $dimensions[$index] };
          if ($$self{use_dvipng}) {
            # dimensions are in (integer) pixel, already magnified
            ($w, $h, $d) = ($ww, $hh + $dd, $dd); }
          elsif ($$self{use_dvisvgm}) {
            # dimensions are in (TeX) points, already magnified
            ($ww, $hh, $dd) = map { $_ * 96 / 72.27 } ($ww, $hh, $dd);
            ($w,  $h,  $d)  = (int($ww + 0.5), int($hh + $dd + 0.5), int($dd + 0.5)); }
          else {
            # dimensions are in (TeX) points, not magnified yet
            ($ww, $hh, $dd) = map { $_ * $pixels_per_pt } ($ww, $hh, $dd);
            ($w,  $h,  $d)  = (int($ww + 0.5), int($hh + $dd + 0.5), int(0.5 + ($dd || 0))); }

          if ($$self{use_dvips}) {    # If using dvips, convert (if necessary) and recover final image size
            ($w, $h) = $self->convert_image($doc, $src, $absdest);
            next unless defined $w && defined $h; }
          else {
            pathname_copy($src, $absdest); }
          if ((($w == 1) && ($ww > 1)) || (($h == 1) && ($hh > 1))) {
            Warn('expected', 'image', undef, "Image for '$$entry{tex}' was cropped to nothing!"); }
          $doc->cacheStore($$entry{key}, "$dest;$w;$h;$d"); }
      }
      else {
        Warn('expected', 'image', undef, "Missing image '$src'; See $workdir/$jobname.log"); } } }

  # Finally, modify the original document to record the associated images.
  foreach my $entry (values %table) {
    next unless ($doc->cacheLookup($$entry{key}) || '') =~ /^(.*);(\d+);(\d+);(\d+)$/;
    my ($image, $width, $height, $depth) = ($1, $2, $3, $4);
    # Ideally, $image is already relative, but if not, make relative to document
    my $reldest = pathname_relative($image, $doc->getDestinationDirectory);
    foreach my $node (@{ $$entry{nodes} }) {
      $self->setTeXImage($doc, $node, $reldest, $width, $height, $depth); } }

  $doc->closeCache;    # If opened.
  return $doc; }

#======================================================================
# Generating & Processing the LaTeX source.
#======================================================================

sub pre_preamble {
  my ($self, $doc) = @_;
  my @classdata = $self->find_documentclass_and_packages($doc);
  my ($class, $class_options, $oldstyle) = @{ shift(@classdata) };
  $class_options = '' unless defined $class_options;
  $class_options = "[$class_options]" if $class_options && ($class_options !~ /^\[.*\]$/);

  if ($$self{use_dvisvgm}) {
    # activate dvisvgm driver (e.g. for TikZ)
    $class_options =~ s/\]$/,dvisvgm]/;
    $class_options =~ s/^$/[dvisvgm]/; }

  my $documentcommand = ($oldstyle ? "\\documentstyle" : "\\documentclass");
  my $packages        = '';
  my $dest            = $doc->getDestination;
  my $description     = ($dest ? "% Destination $dest" : "");
  my $pts_per_pixel   = 72.27 / $$self{DPI} / $$self{magnification};
  my %loaded_check    = ();

  foreach my $pkgdata (@classdata) {
    my ($package, $package_options) = @$pkgdata;
    next if $loaded_check{$package};
    $loaded_check{$package} = 1;
    if ($oldstyle) {
      next if $package =~ /latexml|preview/;    # some packages are incompatible.
      $packages .= "\\RequirePackage{$package}\n"; }
    else {
      if ($package eq 'english') {
        $packages .= "\\usepackage[english]{babel}\n"; }
      else {
        $package_options = "[$package_options]" if $package_options && ($package_options !~ /^\[.*\]$/);
        $packages .= "\\usepackage$package_options\{$package}\n"; } } }

  # PREVIEW.STY options
  # active    : output only content of preview environments in separate pages
  # tightpage : restrict each page to a tight box around the content
  # lyx       : output page dimensions in sp
  $packages .= ($oldstyle ? "\\RequirePackage" : "\\usepackage") . "[active,tightpage,lyx]{preview}\n";

  my $w         = ceil($$self{maxwidth} * $pts_per_pixel);    # Page Width in points.
  my $gap       = $$self{padding} * $pts_per_pixel;
  my $preambles = $self->find_preambles($doc);
  # Some classes are too picky: thanks but no thanks
  my $result_add_to_body = "\\makeatletter\\thispagestyle{empty}\\pagestyle{empty}\n";
  # neutralize caption macros
  $result_add_to_body .= "\\let\\\@\@toccaption\\\@gobble\n\\let\\\@\@caption\\\@gobble\n"
    . "\\let\\cite\\\@gobble\n\\def\\\@\@bibref#1#2#3#4{}\n";
  $result_add_to_body .= "\\renewcommand{\\cite}[2][]{}\n" unless $oldstyle;
  # class-specific conditions:
  if ($class =~ /^JHEP$/i) {
    $class = 'article'; }
  elsif ($class =~ /revtex/) {
    # Careful with revtex4
    $result_add_to_body .= "\\\@ifundefined{\@author\@def}{\\author{}}{}\n"; }
  # when are the empty defaults needed?
  if ($class ne 'article') {
    $result_add_to_body .= "\\title{}\\date{}\n"; }
  $result_add_to_body .= "\\makeatother\n";

  my $result_preamble = <<"EOPreamble";
\\batchmode
\\def\\inlatexml{true}
$documentcommand$class_options\{$class}
$description
$packages
\\makeatletter
\\setlength{\\textwidth}{${w}pt}
\\setlength\\PreviewBorder{${gap}\\p\@}
\\def\\lxBeginImage{\\begin{preview}}
\\def\\lxEndImage{\\end{preview}}
$preambles
\\makeatother
EOPreamble

  return ($result_preamble, $result_add_to_body); }

#======================================================================
# Converting the png images to gif/png/whatever and return the size

# Note that this conversion is, indeed, quite slow.
# Profiling indicates that virtually ALL the time is taken in ->Read !!
#======================================================================

sub convert_image {
  my ($self, $doc, $src, $dest) = @_;
  my ($bg, $fg) = ($$self{background}, 'black');

  my $image = image_object(antialias => 'True', background => $bg, density => $$self{DPI});

  if ($$self{imagetype} eq 'png' && $$self{dvicmd_output_type} =~ /^png/) {
    my ($w, $h, $s, $f) = $image->Ping($$self{dvicmd_output_type} . ':' . $src);
    pathname_copy($src, $dest);
    return ($w, $h); }

  my $err = $image->Read($$self{dvicmd_output_type} . ':' . $src);
  if ($err) {
    Warn('imageprocessing', 'read', undef,
      "Image conversion failed to read '$src'",
      "Response was: $err"); return; }

  my ($w, $h) = $image->Get('width', 'height');    # Get final image size
      # ImageMagick tries to manage a "virtual" image within the image data,
      # (whatever that means)
      # This resets it back to the origin which avoids confusion, all 'round!
  $image->Set(page => "${w}x${h}+0+0");

  # Ideally, we'd make the alpha exactly opposite the ink, rather than merely 1 bit
  # It would seem that this should do it, but currently just seems to turn off alpha completely!!!
  #  $image = $image->Fx(expression=>'(3.0-r+g+b)/3.0', channel=>'alpha');
  $image->Transparent(color => $bg);

  Debug("LaTeXImages: Converting $src => $dest ($w x $h)") if $LaTeXML::DEBUG{images};
  # Workaround bad png detection(?) in ImageMagick 6.6.5 (???)
  if ($$self{imagetype} eq 'png') {
    $dest = "png32:$dest"; }

  $image->Write(filename => $dest);
  return ($w, $h); }

sub DESTROY {
  if (my $tmpdir = File::Spec->tmpdir()) {
    if (-d $tmpdir && opendir(my $tmpdir_fh, $tmpdir)) {
      my @empty_magick = grep { -z $_ } map { "$tmpdir/$_" } readdir($tmpdir_fh);
      closedir($tmpdir_fh);
      unlink $_ foreach @empty_magick;
  } }
  return; }

#======================================================================
1;
