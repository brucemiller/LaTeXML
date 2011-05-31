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

WriteMakefile(NAME => 'LaTeXML',
	      VERSION_FROM => 'lib/LaTeXML.pm',
	      AUTHOR => 'Bruce Miller <bruce.miller@nist.gov>',
	      ABSTRACT => "transforms TeX and LaTeX into XML",
	      PREREQ_PM => { 
			    'Test::Simple'=>0,
			    'DB_File'=>0,
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
			    'Image::Magick'=> 0,
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

pure_all :: $(INST_LIBDIR)/LaTeXML/MathGrammar.pm

$(INST_LIBDIR)/LaTeXML/MathGrammar.pm: lib/LaTeXML/MathGrammar
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
  my $styledir = 'LaTeXML/style';
  # The (.) is supposed to match an open single or double quote;
  # unfortunately, quoting the quote and having it work in all shells, windows,.....
  # Let's just hope that whatever's matched is a quote!
  $$MORE_MACROS{XSLTTOHTML}
    = '$(PERLRUN) -p -e \'s@\s*xmlns\s*=\s*(.)http://www.w3.org/1999/xhtml\1@@\' ';
  opendir(DIR,"lib/$styledir");
  my @xhtmls = grep(/^LaTeXML-(.*)-xhtml.xsl$/,readdir(DIR));
  closedir(DIR);
  my @conversions=();
  foreach my $xhtml (@xhtmls){
    my $html = $xhtml; $html =~ s/-xhtml.xsl$/-html.xsl/;
    $MORE_MAKERULES .= <<"MakeXSLT";

pure_all :: \$(INST_LIBDIR)/LaTeXML/style/$html

\$(INST_LIBDIR)/$styledir/$html: lib/$styledir/$xhtml
	\$(NOECHO) \$(MKPATH) \$(INST_LIBDIR)/$styledir
	\$(XSLTTOHTML) lib/$styledir/$xhtml > \$(INST_LIBDIR)/$styledir/$html

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
    if(system("kpsewhich --expand-var='\$TEXMFLOCAL'")==0){ # can run kpsewhich?
      $TEXMF = `kpsewhich --expand-var='\$TEXMFLOCAL'`; 
      # Strip the quotes (windows? or spaces in pathnames?)
      # The pathnames won't combine right, but we DO need to wrap quotes around all completed paths!!
      chomp($TEXMF); $TEXMF =~ s/^'//; $TEXMF=~ s/'$//; }}
  if(! $TEXMF){
    warn "Warning: no TeX installation found.\n", 
      "  TeX is NOT required, but LaTeXML will have limited functionality.\n";
    return; }

  $$MORE_MACROS{INST_TEXMFDIR}       = '$(INST_LIB)/LaTeXML/texmf';
  $$MORE_MACROS{INSTALLTEXMFDIR}     = "$TEXMF/tex/latex/latexml";
  $$MORE_MACROS{DESTINSTALLTEXMFDIR} = '$(DESTDIR)$(INSTALLTEXMFDIR)';

  # The installation directory of TeX may well have spaces which screws up Make.
  # we need to wrap any pathname that includes TEXMF with quotes in case of embedded spaces
  # The quotes apparently don't hurt, when they completely enclose the path.
  $MORE_MAKERULES .= <<'InstallTeXStyles';

pure_install ::
	$(NOECHO) $(MKPATH) '$(DESTINSTALLTEXMFDIR)'
	$(NOECHO) $(MOD_INSTALL) \
		read '$(INSTALLTEXMFDIR)/.packlist' \
		write '$(DESTINSTALLTEXMFDIR)/.packlist' \
		'$(INST_TEXMFDIR)' '$(DESTINSTALLTEXMFDIR)'
	- perl -e "exit(1) unless -w '$(INSTALLTEXMFDIR)'" && mktexlsr

uninstall ::
	$(NOECHO) $(UNINSTALL) '$(INSTALLTEXMFDIR)/.packlist'
	- perl -e "exit(1) unless -w '$(INSTALLTEXMFDIR)'" && mktexlsr

InstallTeXStyles
}

#======================================================================

