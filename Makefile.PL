#======================================================================
# Makefile Maker for LaTeXML
# Bruce.Miller@NIST.gov
#======================================================================
use ExtUtils::MakeMaker;
use strict;

our $DLMF = grep(/DLMF/,@ARGV);

our @EXCLUSIONS=();
our $MORE_MACROS = {};
our $MORE_MAKERULES='';

compile_MathGrammar();
compile_XSLTs();
install_TeXStyles();
add_rpm_support();
check_ImageMagick();

WriteMakefile(NAME => 'LaTeXML',
	      VERSION_FROM => 'lib/LaTeXML.pm',
	      AUTHOR => 'Bruce Miller <bruce.miller@nist.gov>',
	      ABSTRACT => "transforms TeX and LaTeX into XML",
	      PREREQ_PM => { 
			    'XML::LibXML'  => 1.61, # But > 1.62 is better
			    'XML::LibXSLT' => 1.58,
#			     'XML::LibXML::XPathContext' => 0,
			     'Parse::RecDescent' => 0,
#			     'Image::Magick'=> 0
			   },
	      EXE_FILES => [ 'bin/latexml', 'bin/latexmlpost', 'bin/latexmlfind',
			     ($DLMF ? ('bin/dlmfpost') : ())],
	      macro => $MORE_MACROS,
	      depend => {metafile=>'specfile'},
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
sub install_TeXStyles {
    $MORE_MAKERULES .= <<'InstallTeXStyles';

install::
	$(PERLRUN) blib/lib/LaTeXML/texmf/install.PL

InstallTeXStyles
}

#======================================================================
# Make an rpm specfile to include in the distribution.
# This only runs if cpan2rpm is available
# We need to patch the resulting specfile, since we can't add
# to %post, %postun directly from cpan2rpm,
# but we need to run texhash to include (or cleanup) our additional style files.
#
# This also adds an rpm target
sub add_rpm_support {
  my $cpan2rpm = `which cpan2rpm`; chomp($cpan2rpm);
  if($cpan2rpm){
    $$MORE_MACROS{CPAN2RPM}=$cpan2rpm;
    $MORE_MAKERULES .= <<'EndRPM'

specfile :
	$(CPAN2RPM) --spec-only --spec=$(DISTVNAME)/LaTeXML.spec .
	echo -e "\n%post\n" >> $(DISTVNAME)/LaTeXML.spec
	echo -e "\n[ -x /usr/bin/texhash ] && /usr/bin/texhash\n" >> $(DISTVNAME)/LaTeXML.spec
	echo -e "\n%postun\n" >> $(DISTVNAME)/LaTeXML.spec
	echo -e "\n[ -x /usr/bin/texhash ] && /usr/bin/texhash\n" >> $(DISTVNAME)/LaTeXML.spec

rpm : tardist
	rpmbuild -ta $(DISTVNAME).tar$(SUFFIX)

EndRPM
}
  else {
    $MORE_MAKERULES .= <<'EndRPM'

specfile :
	$(NOECHO) $(NOOP)

EndRPM
}}

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

