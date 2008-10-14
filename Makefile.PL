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
#   CENTOS : sets OLD_LIBXML and specifies an appropriate rpm version

our $OLD_LIBXML = grep(/OLD_LIBXML/,@ARGV);
our $CENTOS     = grep(/CENTOS/,@ARGV);
$OLD_LIBXML = 1 if $CENTOS;
our @EXCLUSIONS=();
our $MORE_MACROS = {};
our $MORE_MAKERULES='';

compile_MathGrammar();
compile_XSLTs();
# Let's simplify and leave out installing the style file (for now?)
## add_rpm_support();
# Let's try again.
install_TeXStyles();
add_rpm_support_complex();

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
	      EXE_FILES => [ 'bin/latexml', 'bin/latexmlpost', 'bin/latexmlfind'],
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
# [note that this script has to handle the indirect installation for rpms!]
sub install_TeXStyles {
    $MORE_MAKERULES .= <<'InstallTeXStyles';

install::
	$(PERLRUN) blib/lib/LaTeXML/texmf/install.PL

InstallTeXStyles
}

#======================================================================
# Make an rpm specfile to include in the distribution.
# This only runs if cpan2rpm is available
# This also adds an rpm target
sub add_rpm_support {
  my $cpan2rpm = `which cpan2rpm`; chomp($cpan2rpm);
  my $cpan2rpmargs = join(' ',grep($_,
				   '--no-prfx',
				   '--packager="Bruce Miller <bruce.miller@nist.gov>"',
				   '--license="Public Domain"',
				   ($CENTOS ? "--release=1centos" : undef),
				   ($OLD_LIBXML ? '--make-maker="OLD_LIBXML"' : undef)));
  if($cpan2rpm){
    $$MORE_MACROS{CPAN2RPM}=$cpan2rpm;
    $$MORE_MACROS{CPAN2RPMARGS}=$cpan2rpmargs;
    $MORE_MAKERULES .= <<'EndRPM'

rpm : tardist
	$(CPAN2RPM) --no-sign $(CPAN2RPMARGS) $(DISTVNAME).tar$(SUFFIX)

EndRPM
}}

# Let's skip this complication (installing the style file) for now.
# We need to patch the resulting specfile, since we can't add
# to %post, %postun directly from cpan2rpm,
# but we need to run texhash to include (or cleanup) our additional style files.
sub add_rpm_support_complex {
  my $cpan2rpm = `which cpan2rpm`; chomp($cpan2rpm);
  my $cpan2rpmargs = join(' ',grep($_,
				   '--no-prfx',
				   '--packager="Bruce Miller <bruce.miller@nist.gov>"',
				   '--license="Public Domain"',
				   ($CENTOS ? "--release=1centos" : undef),
				   ($OLD_LIBXML ? '--make-maker="OLD_LIBXML"' : undef)));
  if($cpan2rpm){
    $$MORE_MACROS{CPAN2RPM}=$cpan2rpm;
    $$MORE_MACROS{CPAN2RPMARGS}=$cpan2rpmargs;
    $MORE_MAKERULES .= <<'EndRPM'

specfile :
	$(CPAN2RPM) --spec-only $(CPAN2RPMARGS) --spec=$(DISTVNAME)/LaTeXML.spec .
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

