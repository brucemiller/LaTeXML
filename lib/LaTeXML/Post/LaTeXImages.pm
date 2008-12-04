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
use Image::Magick;
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
#   magnification  : typically something like 1.5 or 1.75
#   maxwidth       : maximum page width, in pixels (whenever line breaking is possible)
#   dpi            : assumed DPI for the target medium (default 90)
#   background     : color of background (for anti-aliasing, since it is made transparent)
#   imagetype      : typically 'png' or 'gif'.
sub new {
  my($class,%options)=@_;
  my $self = $class->SUPER::new(%options);
  $$self{magnification} = $options{magnification} || 1.75;
  $$self{maxwidth}      = $options{maxwidth} || 800;
  $$self{dpi}           = $options{dpi} || 90;
  $$self{background}    = $options{background} || "#FFFFFF";
  $$self{imagetype}     = $options{imagetype} || 'png';
  $self; }

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
  my($self,$doc,$node,$path,$width,$height)=@_;
  $node->setAttribute('imagesrc',$path);
  $node->setAttribute('imagewidth',$width);
  $node->setAttribute('imageheight',$height); }

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
  foreach my $entry (values %table){
    my $store = $doc->cacheLookup($$entry{key});
    if($store && ($store =~ /^(.*);(\d+);(\d+)$/)){
      next if -f pathname_concat($destdir,$1); }
    push(@pending,$entry); }

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

    # === Run dvips to extract individual postscript files.
    my $mag = int($$self{magnification}*1000);
    system("cd $workdir ; TEXINPUTS=$texinputs $DVIPSCMD -x$mag -o imgx $jobname.dvi") == 0 
      or return $self->Error($doc,"Couldn't execute dvips (see $workdir for clues): $!");

    # === Convert each image to appropriate type and put in place.
    my ($index,$ndigits)= (0,1+int(log( $doc->cacheLookup((ref $self).':_max_image_')||1)/log(10)));
    foreach my $entry (@pending){
      my $src   = "$workdir/imgx".sprintf("%03d",++$index);
      if(-f $src){
	my $reldest = $$entry{reldest} 
	  ||  $self->generateResourcePathname($doc,$$entry{nodes}[0],undef,$$self{imagetype});
	my $dest = $doc->checkDestination($reldest);
	my($w,$h) = $self->convert_image($doc,$src,$dest);
	$doc->cacheStore($$entry{key},"$reldest;$w;$h"); }
      else {
	$self->Warn($doc,"Missing image $src; See $workdir/$jobname.log"); }}
    # Cleanup
##    (system("rm -rf $workdir")==0) or 
##      warn "Couldn't cleanup LaTeXImages workingdirectory $workdir: $!";
    rmtree($workdir) unless $preserve_tmpdir;
  }

  # Finally, modify the original document to record the associated images.
  foreach my $entry (values %table){
    next unless $doc->cacheLookup($$entry{key}) =~ /^(.*);(\d+);(\d+)$/;
    my($image,$width,$height)=($1,$2,$3);
    foreach my $node (@{$$entry{nodes}}){
      $self->setTeXImage($doc,$node,$image,$width,$height); }}
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
  my $documentcommand = ($oldstyle ? "\\documentstyle" : "\\documentclass");
  my $packages='';
  my $dest = $doc->getDestination;
  my $description = ($dest ? "% Destination $dest" : "");
  foreach my $pkgdata (@classdata){
    my($package,$options)=@$pkgdata;
    $options = "[$options]" if $options && ($options !~ /^\[.*\]$/);
    $packages .= "\\usepackage$options\{$package\}\n"; }
  my $w = int(($$self{maxwidth}/$$self{dpi})*72/$$self{magnification});	# Page Width in points.

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
\\newbox\\lxImageBox
\\newdimen\\lxImageBoxSep
\\setlength\\lxImageBoxSep{3\\p\@}
\\newdimen\\lxImageBoxRule
\\setlength\\lxImageBoxRule{0.4\\p\@}
\\def\\XXXXXlxShowImage{%
  \\\@tempdima\\lxImageBoxRule
  \\advance\\\@tempdima\\lxImageBoxSep
  \\advance\\\@tempdima\\dp\\lxImageBox
  \\hbox{%
    \\lower\\\@tempdima\\hbox{%
      \\vbox{%
        \\hrule\\\@height\\lxImageBoxRule
        \\hbox{%
          \\vrule\\\@width\\lxImageBoxRule
          \\vbox{%
            \\vskip\\lxImageBoxSep
            \\box\\lxImageBox
            \\vskip\\lxImageBoxSep}%
          \\vrule\\\@width\\lxImageBoxRule}%
        \\hrule\\\@height\\lxImageBoxRule}%
         }%
        }%
}%
\\def\\lxShowImage{%
  \\\@tempdima\\lxImageBoxRule
  \\advance\\\@tempdima\\lxImageBoxSep
  \\advance\\\@tempdima\\dp\\lxImageBox
  \\hbox{%
    \\lower\\\@tempdima\\hbox{%
      \\vbox{%
        \\hrule\\\@height\\lxImageBoxRule%\\\@width\\lxImageBoxRule
        \\hbox{%
          \\vrule\\\@width\\lxImageBoxRule%\\\@height\\lxImageBoxRule
          \\vbox{%
           \\vskip\\lxImageBoxSep
          \\box\\lxImageBox
           \\vskip\\lxImageBoxSep
           }%
          \\vrule\\\@width\\lxImageBoxRule%\\\@height\\lxImageBoxRule
          }%
        \\hrule\\\@height\\lxImageBoxRule%\\\@width\\lxImageBoxRule
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
# Converting the postscript images to gif.
#======================================================================

sub convert_image {
  my($self,$doc,$src,$dest)=@_;
  my $image = Image::Magick->new(antialias=>'True', background=>$$self{background}); 
  my $ncolors=16;
  my $err = $image->Read($src);
  if($err){
    warn "Image conversion failed to read $src: $err"; return; }
  $image->Transparent(color=>$$self{background});

  $image->Trim;
  $image->Shave(width=>3,height=>3);
# Quantizing PNG's messes up transparency!
# And it doesn't really seem to reduce the image size much anyway.
#  $image->Quantize(colors=>$ncolors);	#  Don't really need much for straight BW text (even aa'd)

  my ($w,$h) = $image->Get('width','height');
  $image->Transparent(color=>$$self{background});

  $self->ProgressDetailed($doc,"Converting $src => $dest ($w x $h)");
  
  $image->Write(filename=>$dest);
  ($w,$h); }

#======================================================================
1;
