# /=====================================================================\ #
# |  LaTeXML::Post::MathImages                                          | #
# | Postprocessor to create images for math                             | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post::MathImages;
use strict;
use DB_File;
use Image::Magick;
use LaTeXML::Util::Pathname;
use LaTeXML::Post;
our @ISA = (qw(LaTeXML::Post::Processor));

#======================================================================

# Should evolve into options, or something
our $MATHIMAGE_SUBDIR = 'math';
# Other silly constants that might want changing?
our $TMP = '/tmp';
our $LATEXCMD='latex';

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
#   dpi            : assumed DPI for the target medium (default 100)
#   background     : color of background (for anti-aliasing, since it is made transparent)
#   imagetype      : typically 'png' or 'gif'.
#  Make the math subdirectory an option!
sub new {
  my($class,%options)=@_;
  my $self= bless {magnification => $options{magnification} || 1.75,
		   maxwidth      => $options{maxwidth} || 800,
		   dpi           => $options{dpi} || 100, 
		   background    => $options{background} || "#FFFFFF",
		   imagetype     => $options{imagetype} || 'png'}, $class; 
  $self->init(%options);
  $self; }

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
  my($self,$doc,%options)=@_;

  my $jobname = 'mathimages';
  my $destdir = $self->getDestinationDirectory;
  my $relpath = $options{mathImagesRelative} || 'math';

  my %table=();

  # === Get the desired math nodes, extract the set of unique tex strings, noting which need processing.
  my($ntotal,$nuniq)=(0,0);
  foreach my $node ($self->find_math_nodes($doc)){
    my($mode,$tex)=$self->extract_tex($node);
    next if !(defined $tex) or ($tex eq '');
    $ntotal++;
    my $key = "$mode:$tex";
    my $entry = $table{$key};
    if(!$entry){
      $nuniq++; $entry = $table{$key} = {key=>$key, tex=>$tex, mode=>$mode, nodes=>[]}; }
    push(@{$$entry{nodes}},$node); }
  $self->Progress("Found $nuniq unique formula (of $ntotal)");
  return $doc unless $nuniq;	# No formula to process!

  pathname_mkdir(pathname_concat($destdir,$relpath)) 
    or return $self->Error("Couldn't create destination dir $destdir/$relpath: $!");

  # === Check which formula still need processing.
  my @pending=();
  foreach my $entry (values %table){
    push(@pending,$entry) unless $self->cacheLookup($$entry{key}); }

  $self->Progress(scalar(@pending)." images to generate");
  if(@pending){			# if any images need processing
    my $workdir=pathname_concat($TMP,"LaTeXML$$");
    pathname_mkdir($workdir) or return $self->Error("Couldn't create MathImage working dir $workdir: $!");

    # === Generate the LaTeX file.
    my $texfile = pathname_make(dir=>$workdir,name=>$jobname,type=>'tex');
    open(TEX,">$texfile") or return $self->Error("Cant write to $texfile: $!");
    print TEX $self->preamble($doc);
    print TEX "\\begin{document}\n";
    foreach my $entry (@pending){
      my $mode = uc($$entry{mode});
      print TEX  "\\begin$mode\n$$entry{tex}\n\\end$mode\n"; }
    print TEX "\\end{document}\n";
    close(TEX);

    # === Run LaTeX on the file.
    system("cd $workdir ; $LATEXCMD $jobname > $jobname.output") == 0
      or return $self->Error("Couldn't execute latex for math images: See $workdir/$jobname.log");
    if(! -f "$workdir/$jobname.dvi"){
      return $self->Error("LaTeX somehow failed: See $workdir/$jobname.log"); }
    # === Run dvips to extract individual postscript files.
    my $mag = int($$self{magnification}*1000);
    system("cd $workdir ; $DVIPSCMD -x$mag -o mix $jobname.dvi") == 0 
      or return $self->Error("Couldn't execute dvips: $!");

    # === Convert each image to appropriate type and put in place.
    my ($index,$ndigits)= (0,1+int(log( $self->cacheLookup('_max_image_')||1)/log(10)));
    foreach my $entry (@pending){
      my $src   = sprintf("mix%03d",++$index);
      my $N = $self->cacheLookup('_max_image_')||0;
      my $dest  = pathname_make(dir=>$relpath,name=>sprintf("mi%0*d",$ndigits,++$N),type=>$$self{imagetype});
      $self->cacheStore('_max_image_',$N);
      my($w,$h) = $self->convert_mathimage("$workdir/$src",pathname_concat($destdir,$dest));
      $self->cacheStore($$entry{key},"$dest;$w;$h"); }
    # Cleanup
    (system("rm -rf $workdir")==0) or warn "Couldn't cleanup MathImages workingdirectory $workdir: $!";
  }

  # Finally, modify the original document to record the associated images.
  foreach my $entry (values %table){
    next unless $self->cacheLookup($$entry{key}) =~ /^(.*);(\d+);(\d+)$/;
    my($image,$width,$height)=($1,$2,$3);
    foreach my $node (@{$$entry{nodes}}){
      $self->set_math_image($node,$image,$width,$height); }}
  $doc;}

#**********************************************************************
# Potentially customizable
#**********************************************************************
# If you've got a different XML document model, or even not an XML
# document at all, subclassing MathImages and overriding these methods
# will allow generation of a set of math images.

# Return the list of nodes that have math in them.
# Default is look for XMath elements with a tex attribute.
sub find_math_nodes {
  my($self,$doc)=@_;
  $doc->getElementsByTagNameNS($self->getNamespace,'Math'); }

# Given a node such as selected by select_math_nodes,
# return a list of mode (inline|display) and the TeX string.
# Default is get the mode and tex attributes.
sub extract_tex {
  my($self,$node)=@_;
  my $mode = $node->getAttribute('mode')||'inline';
  my $tex = $node->getAttribute('tex');
  $tex =~ s/\%[^\n]*\n//gs;	# Strip comments
  $tex =~ s/\n//g;		# and stray CR's
  ($mode, $tex); }

# Given a node and the math image's (relative) filename, width & height, 
# record the information in the node (or replace or whatever).
# Default is to assign image, imagewidth and imageheight attributes to the XMath element.
sub set_math_image {
  my($self,$node,$path,$width,$height)=@_;
  $node->setAttribute('imagesrc',$path);
  $node->setAttribute('imagewidth',$width);
  $node->setAttribute('imageheight',$height);
}

# Get a list blah, blah...
sub find_documentclass_and_packages {
  my($self,$doc)=@_;
  my ($class,$classoptions,@packages);
  foreach my $pi ($doc->findnodes(".//processing-instruction('latexml')")){
    my $data = $pi->textContent;
    my $entry={};
    while($data=~ s/\s*([\w\-\_]*)=([\"\'])(.*?)\2//){
      $$entry{$1}=$3; }
    if($$entry{class}){
      $class=$$entry{class}; $classoptions=$$entry{options}||'onecolumn'; }
    elsif($$entry{package}){
      push(@packages,[$$entry{package},$$entry{options}||'']); }
  }
  $self->Error("No document class found") unless $class;
  ([$class,$classoptions],@packages); }

#======================================================================
# Generating & Processing the LaTeX source.
#======================================================================

sub preamble {
  my($self,$doc)=@_;
  my @classdata = $self->find_documentclass_and_packages($doc);
  my ($class,$options) = @{shift(@classdata)};
  $options = "[$options]" if $options && ($options !~ /^\[.*\]$/);
  
  my $packages='';
  foreach my $pkgdata (@classdata){
    my($package,$options)=@$pkgdata;
    $options = "[$options]" if $options && ($options !~ /^\[.*\]$/);
    $packages .= "\\usepackage$options\{$package\}\n"; }

  my $w = int(($$self{maxwidth}/$$self{dpi})*72/$$self{magnification});	# Page Width in points.

  # To align the baseline of math images, align=middle is necessary.  
  # It aligns the middle of the image to the baseline + half the xheight.
  # We pad either the height or depth of the formula as such:
  #  let delta = height - xheight + depth;
  #  if(delta > 0) increment the depth by delta
  #  if(delta < 0) increment the height by |delta|
  # We'll assume the xheight is 6pts?

return <<EOPreamble;
\\batchmode
\\def\\inlatexml{true}
\\documentclass$options\{$class\}
$packages
\\setlength{\\hoffset}{0pt}\\setlength{\\voffset}{0pt}
\\setlength{\\textwidth}{${w}pt}
\\pagestyle{empty}\\title{}\\author{}\\date{}
\\makeatletter
\\newbox\\sizebox
\\def\\AdjustInline{%
  \\\@tempdima=\\ht\\sizebox\\advance\\\@tempdima-6pt\\advance\\\@tempdima-\\dp\\sizebox
  \\ifdim\\\@tempdima>0pt
    \\advance\\\@tempdima\\dp\\sizebox\\dp\\sizebox=\\\@tempdima
  \\else\\ifdim\\\@tempdima>0pt
     \\advance\\\@tempdima-\\ht\\sizebox\\ht\\sizebox=-\\\@tempdima
  \\fi\\fi}
% For Inline, typeset in box, then extend box so height=depth; then we can center it
\\def\\beginINLINE{\\setbox\\sizebox\\hbox\\bgroup\\(}
\\def\\endINLINE{\\)\\egroup\\AdjustInline\\fbox{\\copy\\sizebox}\\clearpage}
% For Display, same as inline, but set displaystyle.
\\def\\beginDISPLAY{\\setbox\\sizebox\\hbox\\bgroup\\(\\displaystyle}
\\def\\endDISPLAY{\\)\\egroup\\AdjustInline\\fbox{\\copy\\sizebox}\\clearpage}
% Extra definitions for LaTeXML generated TeX
\\def\\FCN#1{#1}
\\newcommand{\\DUAL}[3][]{#3}% Use presentation form!!!
\\makeatother
EOPreamble
}

#======================================================================
# Converting the postscript images to gif.
#======================================================================

sub convert_mathimage {
  my($self,$src,$dest)=@_;
  my $image = Image::Magick->new(antialias=>'True', background=>$$self{background}); 
  my $ncolors=16;
  my $err = $image->Read($src);
  if($err){
    warn "Image conversion failed to read $src: $err"; return; }
  $image->Transparent(color=>$$self{background});

  $image->Shave(width=>3,height=>3);
# Quantizing PNG's messes up transparency!
# And it doesn't really seem to reduce the image size much anyway.
#  $image->Quantize(colors=>$ncolors);	#  Don't really need much for straight BW text (even aa'd)

  my ($w,$h) = $image->Get('width','height');
  $image->Transparent(color=>$$self{background});

  $self->ProgressDetailed("Converting $src => $dest ($w x $h)");

  $image->Write(filename=>$dest);
  ($w,$h); }

#======================================================================
1;
