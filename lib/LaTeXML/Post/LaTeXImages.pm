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
# dvips converts the dvi to eps, and ImageMagick can convert the eps to png;
# OR dvipng can convert the dvi to png MUCH quicker... if it's available.

# Options:
#   source         : (dir)
#   magnification  : typically something like 1.33333, but you may want bigger
#   maxwidth       : maximum page width, in pixels (whenever line breaking is possible)
#   dpi            : assumed DPI for the target medium (default 96)
#   background     : color of background (for anti-aliasing, since it is made transparent)
#   imagetype      : typically 'png' or 'gif'.
sub new {
  my ($class, %options) = @_;
  my $self = $class->SUPER::new(%options);
  $$self{magnification} = $options{magnification} || 1.33333;
  $$self{maxwidth}      = $options{maxwidth}      || 800;
  $$self{dpi}           = $options{dpi}           || 96;
  $$self{background}    = $options{background}    || "#FFFFFF";
  $$self{imagetype}     = $options{imagetype}     || 'png';

  # Parameters for separating the clipping box from the
  # desired padding between image edge and "ink"
  $$self{padding} = $options{padding} || 2;    # pixels
        # amount of extra space (+padding) to put between object & rules for clipping
  $$self{clippingfudge} = 3;       # px
  $$self{clippingrule}  = 0.90;    # pixels (< 1 to avoid antialiasing..?)

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
  my $mag = int($$self{magnification} * 1000);
  my $dpi = int($$self{dpi} * $$self{magnification});
  # Unfortunately, each command has incompatible -o option to name the output file.
  # Note that the formatting char used, '%', has to be doubled on Windows!!
  # Maybe that's only true when it looks like an environment variable?
  # Ie. %variable% ?
  #  my $fmt = ($^O eq 'MSWin32' ? '%%' : '%');
  my $fmt = '%';
  if ($$self{use_dvisvgm}) {
    # img name uses 2 digits for page; what happens at 100?
    $$self{dvicmd}             = "dvisvgm --page=1- --bbox=min --mag=$mag -o imgx-${fmt}p";
    $$self{dvicmd_output_name} = 'imgx-%02d.svg';
    $$self{dvicmd_output_type} = 'svg';
    $$self{frame_output}       = 0; }
  elsif ($$self{use_dvipng}) {
    $$self{dvicmd}             = "dvipng -bg Transparent -T tight -q -D$dpi -o imgx-${fmt}03d.png";
    $$self{dvicmd_output_name} = 'imgx-%03d.png';
    $$self{dvicmd_output_type} = 'png32';
    $$self{frame_output}       = 1; }
  else {
    # Useful DVIPS options:
    #  -q  : run quietly
    #  -x#  : magnification * 1000
    #  -S1 -i  : make a separate file for each `section' consisting of a single page.
    #       QUESTION: dvips' naming scheme allows for 999 pages... what happens at 1000?
    #  -E   :  crop each page close to the `ink'.
    #  -j0  : don't subset fonts; silly really, but some font tests are making problems!
    $$self{dvicmd}             = "dvips -q -S1 -i -E -j0 -x$mag -o imgx";
    $$self{dvicmd_output_name} = 'imgx%03d';
    $$self{dvicmd_output_type} = 'eps';
    $$self{frame_output}       = 1; }
  return $self; }

#**********************************************************************
# Check whether this processor actually has the resources it needs to process.
# I don't know if there's a general API implied here;
# It could, conceivably be use in planning post processing?
# But generally, before signalling an error, you'd want to know that the processor
# is even needed.
# This test is called once we know that, from within
#
# At any rate: To process LaTeX snippets into images, we will need
#  * latex (or related) from a TeX installation
#  * Image::Magick (or similar) [see LaTeXML::Util::Image]
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
  $node->setAttribute('imagesrc',    $path);
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
  $tex =~ s/(?:\\\s*,|\\!\s*|\\>\s*|\\;\s*|\\:\s*|\\ \s*|\\\/\s*)*$//; # and trailing spacing
  $tex =~ s/\%[^\n]*\n//gs;                                            # Strip comments
  $tex = $style . ' ' . $tex if $style;                                # Put back the style, if any
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
  local $ENV{TEXINPUTS} = join($sep, '.', $doc->getSearchPaths,
    pathname_concat(pathname_installation(), 'texmf'),
    ($ENV{TEXINPUTS} || $sep));

  my %table = ();

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

  NoteProgress(" [$nuniq unique; " . scalar(@pending) . " new]");
  if (@pending) {    # if any images need processing
        # Create working directory; note TMPDIR attempts to put it in standard place (like /tmp/)
    File::Temp->safe_level(File::Temp::HIGH);
    my $workdir = File::Temp->newdir("LaTeXMLXXXXXX", TMPDIR => 1);
    # === Generate the LaTeX file.
    my $texfile = pathname_make(dir => $workdir, name => $jobname, type => 'tex');
    my $TEX;
    if (!open($TEX, '>', $texfile)) {
      Error('I/O', $texfile, undef, "Cant write to '$texfile'", "Response was: $!");
      return $doc; }
    print $TEX $self->pre_preamble($doc);
    print $TEX "\\makeatletter\n";
    print $TEX $self->preamble($doc) . "\n";
    print $TEX "\\makeatother\n";
    print $TEX "\\begin{document}\n";
    foreach my $entry (@pending) {
##      print TEX "\\fbox{$$entry{tex}}\\clearpage\n"; }
      print $TEX "$$entry{tex}\\clearpage\n"; }
    print $TEX "\\end{document}\n";
    close($TEX);

    # === Run LaTeX on the file.
    # (keep the command simple so it works in Windows)
    pathname_chdir($workdir);
    my $ltxcommand = "$LATEXCMD $jobname > $jobname.ltxoutput";
    my $ltxerr     = system($ltxcommand);
    pathname_chdir($orig_cwd);

    # Sometimes latex returns non-zero code, even though it apparently succeeded.
    # And sometimes it doesn't produce a dvi, even with 0 return code?
    if (($ltxerr != 0) || (!-f "$workdir/$jobname.dvi")) {
      my $preserve = $$LaTeXML::POST{verbosity} > 0;    # preserve junk when verbosity high.
      $workdir->unlink_on_destroy(0) if $preserve;
      Error('shell', $LATEXCMD, undef,
        "LaTeX command '$ltxcommand' failed",
        ($ltxerr == 0 ? "No dvi file generated"     : "returned code $ltxerr (!= 0): $@"),
        ($preserve    ? "See $workdir/$jobname.log" : "Re-run with --verbose to see TeX log"));
      return $doc; }
    $workdir->unlink_on_destroy(0) if $$LaTeXML::POST{verbosity} > 2;

    # Extract dimensions (width x height+depth) from each image from log file.
    my @dimensions = ();
    my $LOG;
    if (open($LOG, '<', "$workdir/$jobname.log")) {
      while (<$LOG>) {
        if (/^\s*LXIMAGE\s*(\d+)\s*=\s*([\+\-\d\.]+)pt\s*x\s*([\+\-\d\.]+)pt\s*\+\s*([\+\-\d\.]+)pt\s*$/) {
          $dimensions[$1] = [$2, $3, $4]; } }
      close($LOG); }
    else {
      Warn('expected', 'dimensions', undef,
        "Couldn't read log file $workdir/$jobname.log to extract image dimensions",
        "Response was: $!"); }

    # === Run dvicmd to extract individual png|postscript files.
    pathname_chdir($workdir);
    my $dvicommand = "$$self{dvicmd} $jobname.dvi > $jobname.dvioutput";
    my $dvierr     = system($dvicommand);
    pathname_chdir($orig_cwd);

    if ($dvierr != 0) {
      Error('shell', $$self{dvicmd}, undef,
        "Shell command '$dvicommand' (for dvi conversion) failed (see $workdir for clues)",
        "Response was: $!");
      return $doc; }

    # === Convert each image to appropriate type and put in place.
    my $pixels_per_pt = $$self{magnification} * $$self{dpi} / 72.27;
    my ($index, $ndigits) = (0, 1 + int(log($doc->cacheLookup((ref $self) . ':_max_image_') || 1) / log(10)));
    foreach my $entry (@pending) {
      my $src = "$workdir/" . sprintf($$self{dvicmd_output_name}, ++$index);
      if (-f $src) {
        my @dests = @{ $$entry{dest} };
        push(@dests, $self->generateResourcePathname($doc, $$entry{nodes}[0], undef, $$self{imagetype}))
          unless @dests;
        foreach my $dest (@dests) {
          my $absdest = $doc->checkDestination($dest);
          my ($ww, $hh, $dd) = map { $_ * $pixels_per_pt } @{ $dimensions[$index] };
          my ($w, $h);
          if ($$self{frame_output}) {    # If framed, trim the frame
            ($w, $h) = $self->convert_image($doc, $src, $absdest);
            next unless defined $w && defined $h; }
          else {
            pathname_copy($src, $absdest);
            $w = int($ww + 0.5); $h = int($hh + $dd + 0.5); }
          my $d = int(0.5 + ($dd || 0) + $$self{padding});
          if ((($w == 1) && ($ww > 1)) || (($h == 1) && ($hh > 1))) {
            Warn('expected', 'image', undef, "Image for '$$entry{tex}' was cropped to nothing!"); }
#          print STDERR "\nFor key='$$entry{key}': Image[$index] '$dest' $$entry{tex} $ww x $hh + $dd ==> $w x $h \\ $d\n";
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

# Get a list blah, blah...
sub find_documentclass_and_packages {
  my ($self, $doc) = @_;
  my ($class, $classoptions, $oldstyle, @packages);
  foreach my $pi ($doc->findnodes(".//processing-instruction('latexml')")) {
    my $data  = $pi->textContent;
    my $entry = {};
    while ($data =~ s/\s*([\w\-\_]*)=([\"\'])(.*?)\2//) {
      $$entry{$1} = $3; }
    if ($$entry{class}) {
      $class        = $$entry{class};
      $classoptions = $$entry{options} || 'onecolumn';
      $oldstyle     = $$entry{oldstyle}; }
    elsif ($$entry{package}) {
      push(@packages, [$$entry{package}, $$entry{options} || '']); }
  }
  if (!$class) {
    Warn('expected', 'class', undef, "No document class found; using article");
    $class = 'article'; }

  return ([$class, $classoptions, $oldstyle], @packages); }

#======================================================================
# Generating & Processing the LaTeX source.
#======================================================================

sub pre_preamble {
  my ($self, $doc) = @_;
  my @classdata = $self->find_documentclass_and_packages($doc);
  my ($class, $class_options, $oldstyle) = @{ shift(@classdata) };
  $class_options = "[$class_options]" if $class_options && ($class_options !~ /^\[.*\]$/);
  $class_options = '' unless defined $class_options;
  my $documentcommand = ($oldstyle ? "\\documentstyle" : "\\documentclass");
  my $packages        = '';
  my $dest            = $doc->getDestination;
  my $description     = ($dest ? "% Destination $dest" : "");
  my $pts_per_pixel   = 72.27 / $$self{dpi} / $$self{magnification};
  foreach my $pkgdata (@classdata) {
    my ($package, $package_options) = @$pkgdata;
    $package_options = "[$package_options]" if $package_options && ($package_options !~ /^\[.*\]$/);
    $packages .= "\\usepackage$package_options\{$package\}\n"; }

  my $w   = ceil($$self{maxwidth} * $pts_per_pixel);                      # Page Width in points.
  my $gap = ($$self{padding} + $$self{clippingfudge}) * $pts_per_pixel;
  my $th  = ($$self{frame_output}
    ? $$self{clippingrule} * $pts_per_pixel    # clipping box thickness in points.
    : 0);                                      # NO clipping box!
                                               #  print STDERR "w=$w, gap=$gap, thickness=$th\n";
  return <<"EOPreamble";
\\batchmode
\\def\\inlatexml{true}
$documentcommand$class_options\{$class\}
$description
$packages
\\makeatletter
\\setlength{\\hoffset}{0pt}\\setlength{\\voffset}{0pt}
\\setlength{\\textwidth}{${w}pt}
\\thispagestyle{empty}\\pagestyle{empty}\\title{}\\author{}\\date{}
% Extra definitions for LaTeXML generated TeX
\\def\\FCN#1{#1}
\\def\\DUAL{\\\@ifnextchar[{\\\@DUAL}{\\\@DUAL[]}}
\\def\\\@DUAL[#1]#2#3{#3}% Use presentation form!!!
\\newcount\\lxImageNumber\\lxImageNumber=0\\relax
\\newbox\\lxImageBox
\\newdimen\\lxImageBoxSep
\\setlength\\lxImageBoxSep{${gap}\\p\@}
\\newdimen\\lxImageBoxRule
\\setlength\\lxImageBoxRule{${th}\\p\@}
\\def\\lxShowImage{%
  \\global\\advance\\lxImageNumber1\\relax
  \\\@tempdima\\wd\\lxImageBox
  \\advance\\\@tempdima-\\lxImageBoxSep
  \\advance\\\@tempdima-\\lxImageBoxSep
  \\typeout{LXIMAGE \\the\\lxImageNumber\\space= \\the\\\@tempdima\\space x \\the\\ht\\lxImageBox\\space + \\the\\dp\\lxImageBox}%
  \\\@tempdima\\lxImageBoxRule
  \\advance\\\@tempdima\\lxImageBoxSep
  \\advance\\\@tempdima\\dp\\lxImageBox
  \\hbox{%
    \\lower\\\@tempdima\\hbox{%
      \\vbox{%
        \\hrule\\\@height\\lxImageBoxRule%
        \\hbox{%
          \\vrule\\\@width\\lxImageBoxRule%
          \\vbox{%
           \\vskip\\lxImageBoxSep
          \\box\\lxImageBox
           \\vskip\\lxImageBoxSep
           }%
          \\vrule\\\@width\\lxImageBoxRule%
          }%
        \\hrule\\\@height\\lxImageBoxRule%
         }%
         }%
        }%
}%
\\def\\lxBeginImage{\\setbox\\lxImageBox\\hbox\\bgroup\\color\@begingroup\\kern\\lxImageBoxSep}
\\def\\lxEndImage{\\kern\\lxImageBoxSep\\color\@endgroup\\egroup}
\\makeatother
EOPreamble
}

#======================================================================
# Converting the postscript images to gif/png/whatever
# Note that properly trimming the clipping box (and keeping the right
# padding and dimensions) is harder than it seems!
#
# Note that this conversion is, indeed, quite slow.
# Profiling indicates that virtually ALL the time is taken in ->Read !!
# (not the various trimming/shaving).
#======================================================================

sub convert_image {
  my ($self, $doc, $src, $dest) = @_;
  my ($bg, $fg) = ($$self{background}, 'black');

  my $image = image_object(antialias => 'True', background => $bg, density => $$self{dpi});
  my $err = $image->Read($$self{dvicmd_output_type} . ':' . $src);
  if ($err) {
    Warn('imageprocessing', 'read', undef,
      "Image conversion failed to read '$src'",
      "Response was: $err"); return; }

  my ($ww, $hh) = $image->Get('width', 'height');    # Get final image size

  # We can't quite rely on the -E option to dvips; there may or may not be white outside the clipbox;
  # Moreover, rounding can leave (possibly gray) 'tabs' on the clipbox corners.
  # To be sure, add known white border, and trim away all white AND gray
  $image->Border(width => 1, height => 1, fill => $bg);
  $image->Trim(fuzz => '75%');    # Fuzzy, to trim the gray tabs, as well!!
  $image->Set(fuzz => '0%');      # But, be SURE to RESET fuzz!! (It is NOT an "argument"!!!)
       # [Also, be CAREFULL of ImageMagick's Floodfill variants, they sometimes go wild]

  # Finally, shave off the rule & fudge padding.
  my $fudge = int(0.5 + $$self{clippingfudge} + $$self{clippingrule});
  $image->Shave(width => $fudge, height => $fudge);

  my ($w, $h) = $image->Get('width', 'height');    # Get final image size
         # ImageMagick tries to manage a "virtual" image within the image data,
         # (whatever that means)
         # This resets it back to the origin which avoids confusion, all 'round!
  $image->Set(page => "${w}x${h}+0+0");

  # Ideally, we'd make the alpha exactly opposite the ink, rather than merely 1 bit
  # It would seem that this should do it, but currently just seems to turn off alpha completely!!!
  #  $image = $image->Fx(expression=>'(3.0-r+g+b)/3.0', channel=>'alpha');
  $image->Transparent(color => $bg);

  NoteProgressDetailed(" [Converting $src => $dest ($w x $h)]");

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
