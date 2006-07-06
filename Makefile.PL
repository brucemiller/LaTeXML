#======================================================================
# Makefile Maker for LaTeXML
# Bruce.Miller@NIST.gov
#======================================================================
use ExtUtils::MakeMaker;
use strict;

our $DLMF = grep(/DLMF/,@ARGV);

our @TEXSTYLES = ('texmf/latexml.sty');
our @EXCLUSIONS=();
our $MORE_MACROS = {CAT=>'$(PERLRUN) -MExtUtils::Command -e cat'};
our $MORE_MAKERULES='';

compile_MathGrammar();
compile_XSLTs();
install_TeXStyles();
check_ImageMagick();

WriteMakefile(NAME => 'LaTeXML',
	      VERSION_FROM => 'lib/LaTeXML.pm',
	      AUTHOR => 'Bruce Miller <bruce.miller@nist.gov>',
	      ABSTRACT => "transforms TeX and LaTeX into XML",
	      PREREQ_PM => { 'XML::LibXML'  => 1.57,
			     'XML::LibXSLT' => 1.57,
			     'XML::LibXML::XPathContext' => 0,
			     'Parse::RecDescent' => 0,
#			     'Image::Magick'=> 0
			   },
	      EXE_FILES => [ 'bin/latexml', 'bin/latexmlpost', 'bin/latexmlfind',
			     ($DLMF ? ('bin/dlmfpost') : ())],
	      macro => $MORE_MACROS,
	      );

#**********************************************************************
# Overriding ExtUtils::MM methods
#**********************************************************************
# Exclude the sources used to generate others from the build (See below).
sub MY::libscan {
  my($self,$path)=@_;
  if(($path =~ /~$/) || grep($path eq $_, @EXCLUSIONS)){
    return ""; }
  $self->MY::SUPER::libscan($path); }

# Additional Makefile rules.
sub MY::postamble {
  shift->MY::SUPER::postamble(@_) . $MORE_MAKERULES; }

#**********************************************************************
# Special Cases
#**********************************************************************

#======================================================================
# We'll compile the RecDescent grammar during make; don't need to install grammar.
sub compile_MathGrammar {
  push(@EXCLUSIONS,'blib/lib/LaTeXML/MathGrammar');
  $MORE_MAKERULES .= <<'MakeGrammar';
pure_all :: blib/lib/LaTeXML/MathGrammar.pm

blib/lib/LaTeXML/MathGrammar.pm: lib/LaTeXML/MathGrammar
	$(PERLRUN) -MParse::RecDescent - lib/LaTeXML/MathGrammar LaTeXML::MathGrammar
	$(NOECHO) $(MKPATH) $(INST_LIBDIR)/LaTeXML
	$(MV) MathGrammar.pm blib/lib/LaTeXML/MathGrammar.pm

MakeGrammar
}

#======================================================================
# Add rules to generate XSLT files for html & xhtml.
# We concatenate separate head & tail files, rather than use xslt's include, due to namespace issues:
# html must be in null namespace, xhtml must be in a specific namespace.
sub compile_XSLTs {
  push(@EXCLUSIONS,
       'blib/lib/LaTeXML/dtd/html.xsl.head', 'blib/lib/LaTeXML/dtd/xhtml.xsl.head',
       'blib/lib/LaTeXML/dtd/core.xsl.tail');
  $MORE_MAKERULES .= << 'MakeXSLT';
all :: blib/lib/LaTeXML/dtd/LaTeXML-html.xsl

all :: blib/lib/LaTeXML/dtd/LaTeXML-xhtml.xsl

blib/lib/LaTeXML/dtd/LaTeXML-html.xsl: lib/LaTeXML/dtd/html.xsl.head lib/LaTeXML/dtd/core.xsl.tail
	$(CAT) lib/LaTeXML/dtd/html.xsl.head lib/LaTeXML/dtd/core.xsl.tail > $(INST_LIB)/LaTeXML/dtd/LaTeXML-html.xsl

blib/lib/LaTeXML/dtd/LaTeXML-xhtml.xsl: lib/LaTeXML/dtd/xhtml.xsl.head lib/LaTeXML/dtd/core.xsl.tail
	$(CAT) lib/LaTeXML/dtd/xhtml.xsl.head lib/LaTeXML/dtd/core.xsl.tail > $(INST_LIB)/LaTeXML/dtd/LaTeXML-xhtml.xsl

MakeXSLT
}

#======================================================================
# Install included TeX style file(s) into the standard TEXMFLOCAL,
# Iff there seems to be one!
sub install_TeXStyles {
  # Find the texhash program
  my($texhash,$texmflocal);
  if(($texhash = `which texhash`)
     && ($texmflocal = `kpsewhich --expand-var=\'\$TEXMFLOCAL\'`)){
    chomp($texhash); chomp($texmflocal);

    $$MORE_MACROS{TEXHASH}=$texhash;
    $$MORE_MACROS{TEXMFLOCAL}=$texmflocal;
    $$MORE_MACROS{TEXSTYLES} = join(' ',@TEXSTYLES);

    $MORE_MAKERULES .= <<'InstallTeXStyles';
install::
	$(MKPATH) $(TEXMFLOCAL)/tex/latex/latexml/
	$(CP) $(TEXSTYLES) $(TEXMFLOCAL)/tex/latex/latexml/
	$(TEXHASH)

InstallTeXStyles
  }
  else {
    warn "Could not find TeX installation\n"
      ."Skipping install of LaTeXML's TeX style files: ".join(', ',@TEXSTYLES)."\n"; }}

#======================================================================
# ImageMagick is only used in postprocessing, and is somewhat optional.
# Also, it's trickier to install, so let's not require it.
sub check_ImageMagick {
  eval "require Image::Magick; 0";
  if ($@) {
    warn "Warning: Image::Magick not found.\n", 
      "  This module is NOT required, but you will not be able to process images\n",
	"  to convert math or graphics to images files for use on the web.\n"; }}

#======================================================================

