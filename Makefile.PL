#======================================================================
# Makefile Maker for LaTeXML
# Bruce.Miller@NIST.gov
#======================================================================
use ExtUtils::MakeMaker;

my $DLMF = grep(/DLMF/,@ARGV);

# Our own LaTeX style files (explicitly listed, auto???)
my @STYLE_FILES = ('texmf/latexml.sty');

WriteMakefile(
	      NAME => 'LaTeXML',
	      VERSION_FROM => 'lib/LaTeXML.pm',
	      AUTHOR => 'Bruce Miller <bruce.miller@nist.gov>',
	      PREREQ_PM => { 'XML::LibXML'  => 1.57,
			     'XML::LibXSLT' => 1.57,
			     'XML::LibXML::XPathContext' => 0,
			     'Parse::RecDescent' => 0,
			     'Image::Magick'=> 0},
	      EXE_FILES => [ 'bin/latexml', 'bin/latexmlpost', 'bin/latexmlfind',
			     ($DLMF ? ('bin/dlmfpost') : ())],
	      );

# Handling special cases.
#  * MathGrammar should be compiled by Parse::RecDescent
#     the *.pm goes into blib/lib/.. ; 
#     make install will automatically install it.
#  * Installing the style files where LaTeX will find them.

# Questions
#  * Should we make/install documentation?
#     How do we run latexml/post at make time?
#  * Where should dtd's be installed? 
#     blib/dtd vs blib/lib/LaTeXML/dtd ? 
#     .../LaTeXML/dtd or /usr/share/LaTeXML/dtd ?
#   Should we keep a separate catalog
#     (installed where? linked into global catalog?)
#   Or should we simply add our stuff to the global catalog?
#   This should let testing from blib work!

{ package MY;

# Additions here to variables in the Makefile.
# Addition to find TeX's installation directory
# Then we're going to want to install style file(s) to
#   $TEXMF/tex/latex/latexml/
sub pasthru {
  my $inherited = shift->SUPER::pasthru(@_); chomp($inherited);
  # Find the texhash program
  my $texhash = `which texhash`; chomp($texhash);
  # Find where `local' style files should go.
  my $dir = `kpsewhich --expand-var=\'\$TEXMFLOCAL\'`; chomp($dir);
  $inherited ."\n"
    . "TEXHASH=$texhash\n"
      . "TEXMF=$dir\n" 
	."STYLE_FILES=".join(' ',@STYLE_FILES)."\n";
}

# Additions here add extra rules to the Makefile.
sub postamble {
  my $inst = shift->SUPER::postamble(@_);

  # Generate a makefile block to compile the grammar
  my $makeGrammar = <<'MakeGrammar';
all :: blib/lib/LaTeXML/MathGrammar.pm

blib/lib/LaTeXML/MathGrammar.pm: lib/LaTeXML/MathGrammar
	$(PERLRUN) -MParse::RecDescent - lib/LaTeXML/MathGrammar LaTeXML::MathGrammar
	$(NOECHO) $(MKPATH) $(INST_LIBDIR)/LaTeXML
	$(MV) MathGrammar.pm blib/lib/LaTeXML/MathGrammar.pm

MakeGrammar

  # Generate a makefile block to concatenate the style files.
  my $makeXSLTs = << 'MakeXSLT';
all :: blib/lib/LaTeXML/dtd/LaTeXML-html.xsl

all :: blib/lib/LaTeXML/dtd/LaTeXML-xhtml.xsl

blib/lib/LaTeXML/dtd/LaTeXML-html.xsl: lib/LaTeXML/dtd/html.xsl.head lib/LaTeXML/dtd/core.xsl.tail
	$(PERLRUN) -e 'while(<>){print;}' lib/LaTeXML/dtd/html.xsl.head lib/LaTeXML/dtd/core.xsl.tail \
	> blib/lib/LaTeXML/dtd/LaTeXML-html.xsl

blib/lib/LaTeXML/dtd/LaTeXML-xhtml.xsl: lib/LaTeXML/dtd/xhtml.xsl.head lib/LaTeXML/dtd/core.xsl.tail
	$(PERLRUN) -e 'while(<>){print;}' lib/LaTeXML/dtd/xhtml.xsl.head lib/LaTeXML/dtd/core.xsl.tail \
	> blib/lib/LaTeXML/dtd/LaTeXML-xhtml.xsl

MakeXSLT

  # Generate a makefile block to install the TeX sytle files
  my $installTeXStyles = <<'InstallTeXStyles';
install::
	$(MKPATH) $(TEXMF)/tex/latex/latexml/
	$(CP) $(STYLE_FILES) $(TEXMF)/tex/latex/latexml/
	$(TEXHASH)

InstallTeXStyles

$inst . $makeGrammar . $makeXSLTs . $installTeXStyles; }

# To strip FindBin stuff from scripts.
# BUT, I want to do it when installing to final dest, NOT when copying to blib/bin !!!!!
# blib/bin is exactly when I WANT it, for testing!
sub XXinstallbin {
  my $inst = shift->SUPER::installbin(@_);
  my $morefixin =  ' | grep -v \\"^use.\*FindBin\\"';
  $inst =~ s/^\t\$\(CP\)\s+(\S*)\s*(\S*)$/\tgrep -v \'^use .\*FindBin\' \1 > \2/gm;
  $inst; }

}

