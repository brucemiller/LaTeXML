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
use DB_File;
#use Image::Magick;
#use Graphics::Magick;
use POSIX;
use LaTeXML::Util::Pathname;
use File::Temp qw(tempdir);
use File::Path;
use base qw(LaTeXML::Post);

#======================================================================

# Other silly constants that might want changing?
##our $TMP = '/tmp';
our $LATEXCMD='latex'; #(or elatex)

# Usefull DVIPS options:
#  -q  : run quietly
#  -x#  : magnification * 1000
#  -S1 -i  : make a separate file for each `section' consisting of a single page.
#       QUESTION: dvips' naming scheme allows for 999 pages... what happens at 1000?
#  -E   :  crop each page close to the `ink'.
#  -j0  : don't subset fonts; silly really, but some font tests are making problems!
our $DVIPSCMD='dvips -q -S1 -i -E -j0';

# Options:
#   source         : (dir)
#   magnification  : typically something like 1.33333, but you may want bigger
#   maxwidth       : maximum page width, in pixels (whenever line breaking is possible)
#   dpi            : assumed DPI for the target medium (default 96)
#   background     : color of background (for anti-aliasing, since it is made transparent)
#   imagetype      : typically 'png' or 'gif'.
sub new {
  my($class,%options)=@_;
  my $self = $class->SUPER::new(%options);
  $$self{magnification} = $options{magnification} || 1.33333;
  $$self{magnification} = 1.3333333;
  $$self{maxwidth}      = $options{maxwidth} || 800;
  $$self{dpi}           = $options{dpi} || 96;
  $$self{background}    = $options{background} || "#FFFFFF";
  $$self{imagetype}     = $options{imagetype} || 'png';
#    $$self{imagetype}     = 'gif';

  # Parameters for separating the clipping box from the 
  # desired padding between image edge and "ink"
  $$self{padding}          = $options{padding} || 2; # pixels
  # amount of extra space (+padding) to put between object & rules for clipping
  $$self{clippingfudge}    = 3; # px
  $$self{clippingrule}     = 0.90; # pixels (< 1 to avoid antialiasing..?)
  $self; }

#**********************************************************************

# NOTE that Image::Magick version 6.6.5.10 is erratic about making png's transparent!
# version 5.6.1.2 seems to work....
# Graphics::Magick seems to be working;
our @MagickClasses = (qw(Foo::Bar  Image::Magick Graphics::Magick));
# We could _prefer_ Graphics::Magick over Image::Magick, if available...
#our @MagickClasses = (qw(Foo::Bar  Graphics::Magick Image::Magick));

sub createMagickImage {
  my($sel,%props)=@_;
  foreach my $class (@MagickClasses){
    my $object = createMagickObject($class,%props);
#    print STDERR "Magick class $class ".($object ? "succeeded" : "failed")."\n";
    return $object if $object; }}

sub createMagickObject {
  my($class,%props)=@_;
  my $module = $class.".pm";
  $module =~ s/::/\//g;
  eval {require $module; $class->new(%props); }; }

#**********************************************************************
# Methods that must be defined;

# $self->findTeXNodes($doc) => @nodes;
sub findTeXNodes { (); }

# $self->extractTeX($doc,$node)=>$texstring;
sub extractTeX { ""; }

# $self->format_tex($texstring)
sub format_tex { ""; }

# $self->setTeXImage($doc,$node,$imagepath,$width,$height);
# This is the default
sub setTeXImage {
  my($self,$doc,$node,$path,$width,$height,$depth)=@_;
  $node->setAttribute('imagesrc',$path);
  $node->setAttribute('imagewidth',$width);
  $node->setAttribute('imageheight',$height);
  $node->setAttribute('imagedepth',$depth) if defined $depth; }

#======================================================================
# Methods that could be wrapped, overridden.

# Should be called by extractTeX
sub cleanTeX {
  my($self,$tex)=@_;
  return unless defined $tex;
  my $style = '';
  $style = $1 if
    $tex =~ s/^\s*(\\displaystyle|\\textstyle|\\scriptstyle|\\scriptscriptstyle)\s*//; # Save any leading style
  $tex =~ s/^(?:\\\s*,|\\!\s*|\\>\s*|\\;\s*|\\:\s*|\\ \s*|\\\/\s*)*//; # Trim leading spacing (especially negative!)
  $tex =~ s/(?:\\\s*,|\\!\s*|\\>\s*|\\;\s*|\\:\s*|\\ \s*|\\\/\s*)*$//; # and trailing spacing
  $tex =~ s/\%[^\n]*\n//gs;	# Strip comments
  $tex = $style.' '.$tex if $style; # Put back the style, if any
  $tex; }

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
sub process {
  my($self,$doc)=@_;

  my $jobname = "ltxmlimg";

  my %table=();

  # === Get the desired nodes, extract the set of unique tex strings,
  #     noting which need processing.
  # Note that if desiredResourcePathname is implemented, we might get
  # several desired names for the same chunk of tex!!!
  my($ntotal,$nuniq)=(0,0);
  foreach my $node ($self->findTeXNodes($doc)){
    my $tex = $self->extractTeX($doc,$node);
    next if !(defined $tex) or ($tex =~/^\s*$/);
    $ntotal++;

    my $reldest = $self->desiredResourcePathname($doc,$node,undef,$$self{imagetype});
    my $key = (ref $self).":".$tex . ($reldest ? ":$reldest" : '');
    my $entry = $table{$key};
    if(!$entry){
      $nuniq++;
      $entry = $table{$key} = {tex=>$tex, key=>$key, nodes=>[], reldest=>$reldest}; }
    push(@{$$entry{nodes}},$node); }

  return $doc unless $nuniq;	# No strings to process!

  # === Check which objects still need processing.
  my $destdir = $doc->getDestinationDirectory;
  my @pending=();
  foreach my $key (sort keys %table){
    my $store = $doc->cacheLookup($key);
    if($store && ($store =~ /^(.*);(\d+);(\d+);(\d+)$/)){
      next if -f pathname_concat($destdir,$1); }
    push(@pending,$table{$key}); }

  $self->Progress($doc,"Found $nuniq unique tex strings (of $ntotal); "
		  .scalar(@pending)." to generate");
  if(@pending){			# if any images need processing
##    my $workdir=pathname_concat($TMP,"LaTeXML$$");
##    pathname_mkdir($workdir) or 
##      return $self->Error($doc,"Couldn't create LaTeXImages working dir $workdir: $!");
    my $workdir=tempdir("LaTeXMLXXXXXX", CLEANUP=>0);
    my $preserve_tmpdir = 0;

    # === Generate the LaTeX file.
    my $texfile = pathname_make(dir=>$workdir,name=>$jobname,type=>'tex');
    open(TEX,">$texfile") or return $self->Error($doc,"Cant write to $texfile: $!");
    print TEX $self->pre_preamble($doc);
    print TEX "\\makeatletter\n";
    print TEX $self->preamble($doc)."\n";
    print TEX "\\makeatother\n";
    print TEX "\\begin{document}\n";
    foreach my $entry (@pending){
##      print TEX "\\fbox{$$entry{tex}}\\clearpage\n"; }
      print TEX "$$entry{tex}\\clearpage\n"; }
    print TEX "\\end{document}\n";
    close(TEX);

    # === Run LaTeX on the file.
    my $texinputs = ".:".join(':',$doc->getSearchPaths) .":".($ENV{TEXINPUTS} ||'');
    my $command = "cd $workdir ; TEXINPUTS=$texinputs $LATEXCMD $jobname > $jobname.output";
    my $err = system($command);

    # Sometimes latex returns non-zero code, even though it apparently succeeded.
    if($err != 0){
      $preserve_tmpdir = 1;
      $self->Warn($doc,"latex ($command) returned code $err (!= 0) for image generation: $@\n See $workdir/$jobname.log"); }
    if(! -f "$workdir/$jobname.dvi"){
      $preserve_tmpdir = 1;
      return $self->Error($doc,"LaTeX ($command) somehow failed: See $workdir/$jobname.log"); }

    $preserve_tmpdir=1 if $$self{verbosity} > 2;

    # Extract dimensions (width x height+depth) from each image from log file.
    my @dimensions=();
    if(open(LOG,"$workdir/$jobname.log")){
	while(<LOG>){
	    if(/^\s*LXIMAGE\s*(\d+)\s*=\s*([\+\-\d\.]+)pt\s*x\s*([\+\-\d\.]+)pt\s*\+\s*([\+\-\d\.]+)pt\s*$/){
		$dimensions[$1]=[$2,$3,$4]; }}
	close(LOG); }
    else {
	$self->Warn($doc,"Couldn't read log file $workdir/$jobname.log to extract image dimensions: $!"); }

    # === Run dvips to extract individual postscript files.
    my $mag = int($$self{magnification}*1000);
    system("cd $workdir ; TEXINPUTS=$texinputs $DVIPSCMD -x$mag -o imgx $jobname.dvi") == 0 
      or return $self->Error($doc,"Couldn't execute dvips (see $workdir for clues): $!");

    my $pixels_per_pt = $$self{magnification}*$$self{dpi}/72.27;

    # === Convert each image to appropriate type and put in place.
    my ($index,$ndigits)= (0,1+int(log( $doc->cacheLookup((ref $self).':_max_image_')||1)/log(10)));
    foreach my $entry (@pending){
      my $src   = "$workdir/imgx".sprintf("%03d",++$index);
      if(-f $src){
	my $reldest = $$entry{reldest} 
	  ||  $self->generateResourcePathname($doc,$$entry{nodes}[0],undef,$$self{imagetype});
	my $dest = $doc->checkDestination($reldest);
	my($w,$h) = $self->convert_image($doc,$src,$dest);
	my($ww,$hh,$dd)= map($_*$pixels_per_pt, @{$dimensions[$index]});
	my $d = int(0.5+$dd + $$self{padding});
	if( (($w==1) && ($ww > 1)) || (($h==1) && ($hh > 1)) ){
	  $self->Warn($doc,"Image for $$entry{tex} was cropped to nothing!"); }
	# print STDERR "\nImage[$index] $$entry{tex} $ww x $hh + $dd ==> $w x $h \\ $d\n";
	$doc->cacheStore($$entry{key},"$reldest;$w;$h;$d"); }
      else {
	$self->Warn($doc,"Missing image $src; See $workdir/$jobname.log"); }}
    # Cleanup
    rmtree($workdir) unless $preserve_tmpdir;
  }

  # Finally, modify the original document to record the associated images.
  foreach my $entry (values %table){
    next unless $doc->cacheLookup($$entry{key}) =~ /^(.*);(\d+);(\d+);(\d+)$/;
    my($image,$width,$height,$depth)=($1,$2,$3,$4);
    foreach my $node (@{$$entry{nodes}}){
      $self->setTeXImage($doc,$node,$image,$width,$height,$depth); }}
  $doc->closeCache;		# If opened.
  $doc;}

# Get a list blah, blah...
sub find_documentclass_and_packages {
  my($self,$doc)=@_;
  my ($class,$classoptions,$oldstyle,@packages);
  foreach my $pi ($doc->findnodes(".//processing-instruction('latexml')")){
    my $data = $pi->textContent;
    my $entry={};
    while($data=~ s/\s*([\w\-\_]*)=([\"\'])(.*?)\2//){
      $$entry{$1}=$3; }
    if($$entry{class}){
      $class=$$entry{class}; 
      $classoptions=$$entry{options}||'onecolumn';
      $oldstyle=$$entry{oldstyle}; }
    elsif($$entry{package}){
      push(@packages,[$$entry{package},$$entry{options}||'']); }
  }
  if(!$class){
    $self->Warn($doc,"No document class found; using article");
    $class = 'article'; }

  ([$class,$classoptions,$oldstyle],@packages); }

#======================================================================
# Generating & Processing the LaTeX source.
#======================================================================

sub pre_preamble {
  my($self,$doc)=@_;
  my @classdata = $self->find_documentclass_and_packages($doc);
  my ($class,$options,$oldstyle) = @{shift(@classdata)};
  $options = "[$options]" if $options && ($options !~ /^\[.*\]$/);
  $options = '' unless defined $options;
  my $documentcommand = ($oldstyle ? "\\documentstyle" : "\\documentclass");
  my $packages='';
  my $dest = $doc->getDestination;
  my $description = ($dest ? "% Destination $dest" : "");
  my $pts_per_pixel = 72.27/$$self{dpi}/$$self{magnification};
  foreach my $pkgdata (@classdata){
    my($package,$options)=@$pkgdata;
    $options = "[$options]" if $options && ($options !~ /^\[.*\]$/);
    $packages .= "\\usepackage$options\{$package\}\n"; }

  my $w   = ceil($$self{maxwidth} * $pts_per_pixel);	# Page Width in points.
  my $gap = ($$self{padding}+$$self{clippingfudge})*$pts_per_pixel;
  my $th  = $$self{clippingrule}*$pts_per_pixel;	# clipping box thickness in points.
#  print STDERR "w=$w, gap=$gap, thickness=$th\n";
return <<EOPreamble;
\\batchmode
\\def\\inlatexml{true}
$documentcommand$options\{$class\}
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
#======================================================================

sub convert_image {
  my($self,$doc,$src,$dest)=@_;
  my($bg,$fg)=($$self{background},'black');

  my $image = $self->createMagickImage(antialias=>'True',background=>$bg,density=>$$self{dpi});
#				       verbose=>'True');
  my $err = $image->Read("eps:$src");
  if($err){
    warn "Image conversion failed to read $src: $err"; return; }

  my ($ww,$hh) = $image->Get('width','height'); # Get final image size

  # We can't quite rely on the -E option to dvips; there may or may not be white outside the clipbox;
  # Moreover, rounding can leave (possibly gray) 'tabs' on the clipbox corners.
  # To be sure, add known white border, and trim away all white AND gray
  $image->Border(width=>1,height=>1,fill=>$bg);
  $image->Trim(fuzz=>'75%');	# Fuzzy, to trim the gray tabs, as well!!
  $image->Set(fuzz=>'0%');	# But, be SURE to RESET fuzz!! (It is NOT an "argument"!!!)
  # [Also, be CAREFULL of ImageMagick's Floodfill variants, they sometimes go wild]

  # Finally, shave off the rule & fudge padding.
  my $fudge=int(0.5+$$self{clippingfudge}+$$self{clippingrule});
  $image->Shave(width=>$fudge,height=>$fudge);

  my ($w,$h) = $image->Get('width','height'); # Get final image size
  # ImageMagick tries to manage a "virtual" image within the image data,
  # (whatever that means)
  # This resets it back to the origin which avoids confusion, all 'round!
  $image->Set(page=>"${w}x${h}+0+0");

  # Ideally, we'd make the alpha exactly opposite the ink, rather than merely 1 bit
  # It would seem that this should do it, but currently just seems to turn off alpha completely!!!
#  $image = $image->Fx(expression=>'(3.0-r+g+b)/3.0', channel=>'alpha');
  $image->Transparent(color=>$bg);

  $self->ProgressDetailed($doc,"Converting $src => $dest ($w x $h)");

  # Workaround bad png detection(?) in ImageMagick 6.6.5 (???)
  if($$self{imagetype} eq 'png'){
    $dest = "png32:$dest"; }

  $image->Write(filename=>$dest);
  ($w,$h); }

#======================================================================
1;
