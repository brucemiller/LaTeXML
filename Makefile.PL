#======================================================================
# Makefile Maker for LaTeXML
# Bruce.Miller@NIST.gov
#======================================================================
use ExtUtils::MakeMaker;
use strict;

#======================================================================
# Use "perl Makefile.PL <options>"
# Build options are:
#   OLD_LIBXML  : if you only have access to an old version of XML::LibXML (ie. before 1.61).
#     This is necessary because we will have an additional dependency
#     (XML::LibXML::XPathContext), and it would be too late to add that
#     dependence when we discover which version of XML::LibXML we end up with.
#     "Enterprise" Linuxes, like Centos and RedHat Enterprise are likely
#     to be stuck with such older versions (till now).
#   TEXMF=<texmfdir> : Installs the tex style files to this texmf tree,
#     rather than where kpsewhich says TEXMFLOCAL is (useful for spec files?)
#======================================================================

our $OLD_LIBXML = grep(/OLD_LIBXML/,@ARGV);

our $TEXMF;
my ($texmfspec) = grep(/^TEXMF/,@ARGV);
if($texmfspec &&  $texmfspec =~ /^TEXMF\s*=(.*)$/){
  $TEXMF=$1;
  @ARGV = grep($_ ne $texmfspec,@ARGV); # Remove so MakeMaker doesn't fret.
}
our @EXCLUSIONS=();
our $MORE_MACROS = {};
our $MORE_MAKERULES='';

compile_MathGrammar();
compile_XSLTs();
install_TeXStyles();

check_ImageMagick();

WriteMakefile(NAME => 'LaTeXML',
	      VERSION_FROM => 'lib/LaTeXML.pm',
	      AUTHOR => 'Bruce Miller <bruce.miller@nist.gov>',
	      ABSTRACT => "transforms TeX and LaTeX into XML",
	      PREREQ_PM => { 
			    'Test::Simple'=>0,
			    # If we have an "old" version of XML::LibXML,
			    # we also need XPathContext.
			    # But we can't determine that additional dependence
			    # after we've already started resolving dependences!
			    ($OLD_LIBXML
			     ? ( 'XML::LibXML'  => 1.58,
				 'XML::LibXML::XPathContext' => 0)
			     : ( 'XML::LibXML'  => 1.61)), # But > 1.62 is better
			    'XML::LibXSLT' => 1.58,
			     'Parse::RecDescent' => 0,
#			     'Image::Magick'=> 0
			   },
	      EXE_FILES => [ 'bin/latexml','bin/latexmlpost','bin/latexmlfind','bin/latexmlmath'],
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

# Append any additional Makefile rules added by the following.
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
# Generally, we've only written XHTML versions (clean xml) of XSLT,
# but these need to be converted to HTML by (at least) removing 
# the namespace declaration since HTML must be in null namespace,
# whereas XHTML must be in a specific namespace.
sub compile_XSLTs {
  my $styledir = 'lib/LaTeXML/style';
  $$MORE_MACROS{XSLTTOHTML}
    = '$(PERLRUN) -p -e \'s@\s*xmlns\s*=\s*(\"|\'\\\'\')http://www.w3.org/1999/xhtml\1@@\' ';
  opendir(DIR,$styledir);
  my @xhtmls = grep(/^LaTeXML-(.*)-xhtml.xsl$/,readdir(DIR));
  closedir(DIR);
  foreach my $xhtml (@xhtmls){
    my $html = $xhtml; $html =~ s/-xhtml.xsl$/-html.xsl/;
    $MORE_MAKERULES .= <<"MakeXSLT";

all :: blib/$styledir/$html

blib/$styledir/$html : $styledir/$xhtml
	\$(XSLTTOHTML) $styledir/$xhtml > blib/$styledir/$html

MakeXSLT
}}

#======================================================================
# Install included TeX style file(s) into the standard TEXMFLOCAL,
# [note that this script has to handle the indirect installation for rpms!]
#
# FIGURE THIS OUT; We want to append
#      --prefix=$(DESTDIR)
# to install.PL so that it can "install" to staging directories
# but for manual $(DESTDIR) is empty, so install.PL complains...
sub install_TeXStyles {
  if(! $TEXMF){
    my $kpsewhich = `which kpsewhich`; chomp($kpsewhich);
    $TEXMF = $kpsewhich && `$kpsewhich --expand-var='\$TEXMFLOCAL'`;
    chomp($TEXMF);
    if(! $TEXMF){
      warn "Warning: no TeX installation found.\n", 
	"  TeX is NOT required, but LaTeXML will have limited functionality.\n";
      return; }}

  $$MORE_MACROS{INST_TEXMFDIR}       = '$(INST_LIB)/LaTeXML/texmf';
  $$MORE_MACROS{INSTALLTEXMFDIR}     = "$TEXMF/tex/latex/latexml";
  $$MORE_MACROS{DESTINSTALLTEXMFDIR} = '$(DESTDIR)$(INSTALLTEXMFDIR)';

  $MORE_MAKERULES .= <<'InstallTeXStyles';

pure_install ::
	$(NOECHO) $(MKPATH) $(DESTINSTALLTEXMFDIR)
	$(NOECHO) $(MOD_INSTALL) \
		read $(INSTALLTEXMFDIR)/.packlist \
		write $(DESTINSTALLTEXMFDIR)/.packlist \
		$(INST_TEXMFDIR) $(DESTINSTALLTEXMFDIR)
	- test -w $(INSTALLTEXMFDIR) && mktexlsr

uninstall ::
	$(NOECHO) $(UNINSTALL) $(INSTALLTEXMFDIR)/.packlist
	- test -w $(INSTALLTEXMFDIR) && mktexlsr

InstallTeXStyles
}

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

