# -*- CPERL -*-
#======================================================================
# Makefile Maker for LaTeXML
# Bruce.Miller@NIST.gov
#======================================================================
use ExtUtils::MakeMaker;
use strict;
use warnings;
use FindBin;

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
#   NOMKTEXLSR : disables running mktexlsr (to re-index the texmf directories
#     after installing our style files).  This is to be used when Makefile.PL
#     is invoked within a staged installation system like rpm, macports, etc.
#     In those cases you'll need to run "mktexlsr" within the post-install
#     and post-uninstall stages of the build.
#======================================================================

our $OLD_LIBXML     = grep { /OLD_LIBXML/ } @ARGV;
our $NOMKTEXLSR     = grep { /NOMKTEXLSR/ } @ARGV;
our $KPSE_TOOLCHAIN = "";
our ($KPSEV, $TEXMF);
my ($texmfspec) = grep { /^TEXMF/ } @ARGV;
if ($texmfspec && $texmfspec =~ /^TEXMF\s*=(.*)$/) {
  $TEXMF = $1;
  local @ARGV = grep { $_ ne $texmfspec } @ARGV; }    # Remove so MakeMaker doesn't fret.
our @EXCLUSIONS     = ();
our $MORE_MACROS    = {};
our $MORE_MAKERULES = '';

record_revision();
compile_MathGrammar();
install_TeXStyles();
dump_formats();
extra_Tests();

WriteMakefile(NAME => 'LaTeXML',
  AUTHOR => ['Bruce Miller <bruce.miller@nist.gov>',
    'Deyan Ginev <deyan.ginev@gmail.com>'],
  ABSTRACT         => "transforms TeX and LaTeX into XML/HTML/MathML",
  VERSION_FROM     => 'lib/LaTeXML.pm',
  MIN_PERL_VERSION => 5.010001,
  # A very restricted set of licenses are allowed here. No Creative Commons, eg.!
  # The tag open_source should be an Open Source Initiative approved license;
  # public domain is sorta included. See http://opensource.org/faq#public-domain
  LICENSE            => 'open_source',
  CONFIGURE_REQUIRES => {
    'version' => 0.77,
  },
  PREREQ_PM => {
    'Archive::Zip'      => 0,
    'DB_File'           => 0,
    'File::Which'       => 0,
    'Getopt::Long'      => 2.37,
    'Image::Size'       => 0,
    'IO::String'        => 0,
    'IO::Handle'        => 0,
    'IO::Socket'        => 0,
    'JSON::XS'          => 0,
    'LWP'               => 0,
    'MIME::Base64'      => 0,      # Core
    'Parse::RecDescent' => 0,
    'Pod::Parser'       => 0,      # for Pod::Find
    'Text::Unidecode'   => 0,
    'Test::More'        => 0,      # part of Test::Simple
    'Time::HiRes'       => 0,
    'URI'               => 0,
    'version'           => 0,
    # Windows terminal handling (see Common::Error)
    # Windows argument escaping (see Util::Pathname)
    ($^O eq 'MSWin32'
      ? ('Win32::Console' => 0,
        'Win32::Console::ANSI' => 0,
        'Win32::ShellQuote'    => 0)
      : ()),
    # If we have an "old" version of XML::LibXML,
    # we also need XPathContext.
    # But we can't determine that additional dependence
    # after we've already started resolving dependences!
    ($OLD_LIBXML
      ? ('XML::LibXML' => 1.58,
        'XML::LibXML::XPathContext' => 0)
      : ('XML::LibXML' => 1.61)),    # But > 1.62 is better
    'XML::LibXSLT' => 1.58,
  },
  EXE_FILES => ['bin/latexml', 'bin/latexmlpost', 'bin/latexmlfind', 'bin/latexmlmath', 'bin/latexmlc'],
  macro     => $MORE_MACROS,
  # link to  github location to newer MakeMaker
  (eval { ExtUtils::MakeMaker->VERSION(6.46) } ? (META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
          repository => {
            type => 'git',
            url  => 'https://github.com/brucemiller/LaTeXML.git',
            web  => 'https://github.com/brucemiller/LaTeXML' },
          bugtracker => {
            web => 'https://github.com/brucemiller/LaTeXML/issues' } } })
    : ()),
);

print STDERR ('=' x 55), "\n",
  "| If you plan on developing code, please consider using\n",
  "| the git pre-commit hook to assure style compliant code.\n",
  "| To install:\n",
  "|    ln -s ../../tools/pre-commit .git/hooks\n",
  ('=' x 55), "\n" unless -x '.git/hooks/pre-commit';
#**********************************************************************
# Special Cases
#**********************************************************************

#======================================================================
# Record the current git revision (last commit)
sub record_revision {
  # Don't copy the Version template to the installation; it's not needed
  push(@EXCLUSIONS, 'blib/lib/LaTeXML/Version.in');
  # This should be the top-level directory, so it's revision should represent the whole project
  $$MORE_MACROS{REVISION_BASE} = $FindBin::RealBin;
  # This is where the REVISION gets stored (along with VERSION, etc)
  $$MORE_MACROS{REVISION_FILE} = '$(INST_LIBDIR)/LaTeXML/Version.pm';
  # Get the current revision --- SAFELY !!!!
  # Don't do anything extra unless we appear to be a git clone.
  # We'll assume such systems have a better make supporting $(shell ... ????
  my $is_gitclone = (-e '.git') && (system("git --version") == 0);
  if ($is_gitclone) {    # If a git checkout & can run git?
    print STDERR "\n";    # space out messages
    $$MORE_MACROS{REVISION} = '$(shell git log --max-count=1 --abbrev-commit --pretty="%h")';
    # Extract the previously recorded revision from the revision file (awkward)
    $$MORE_MACROS{OLD_REVISION}
      = '$(shell $(PERLRUN) -ne "chomp;if(s/.*?REVISION\s*=\s*\'// && s/\s*\'.*//){print;}" < $(REVISION_FILE))'; }
  # Substitute the revision into the revision template
  $$MORE_MACROS{RECORD_REVISION} = '$(PERLRUN) -pe "s@__REVISION__@$(REVISION)@" ';

  # This is for all systems, copies Version.in to Version.pm
  $MORE_MAKERULES .= <<'RecordRevision';

# Always set revision if version module template is newer

pure_all :: $(REVISION_FILE)

$(REVISION_FILE): lib/LaTeXML/Version.in
	$(NOECHO) $(MKPATH) $(INST_LIBDIR)/LaTeXML
	$(RECORD_REVISION) lib/LaTeXML/Version.in > $(REVISION_FILE)

RecordRevision

  # This is for git clones only, and updates revision to last commit
  if ($is_gitclone) {
    $MORE_MAKERULES .= <<'UpdateRevision';

# For git clones, record the git revision in the Version module

pure_all :: update_revision

update_revision:
	$(NOECHO) $(MKPATH) $(INST_LIBDIR)/LaTeXML
	- $(NOECHO) $(PERLRUN) -e "exit(1) unless '$(REVISION)' eq '$(OLD_REVISION)';" \
	|| $(RECORD_REVISION) lib/LaTeXML/Version.in > $(REVISION_FILE)

UpdateRevision
  }
  return; }

#======================================================================
# We'll compile the RecDescent grammar during make; don't need to install grammar.
sub compile_MathGrammar {
  push(@EXCLUSIONS, 'README.pod', 'blib/lib/LaTeXML/MathGrammar');
  $MORE_MAKERULES .= <<'MakeGrammar';

# Precompile the (Recursive Descent) MathGrammar
pure_all :: $(INST_LIBDIR)/LaTeXML/MathGrammar.pm

$(INST_LIBDIR)/LaTeXML/MathGrammar.pm: lib/LaTeXML/MathGrammar
	$(PERLRUN) -MParse::RecDescent - lib/LaTeXML/MathGrammar LaTeXML::MathGrammar Parse::RecDescent
	@$(PERLRUN) -e "exit(1) unless -e 'MathGrammar.pm';" || \
		(echo "Parse::RecDescent failed to created parser, trying to use old implementation. " && \
		$(PERLRUN) -MParse::RecDescent - lib/LaTeXML/MathGrammar LaTeXML::MathGrammar)
	$(NOECHO) $(MKPATH) $(INST_LIBDIR)/LaTeXML
	$(MV) MathGrammar.pm blib/lib/LaTeXML/MathGrammar.pm

MakeGrammar
  return; }

#======================================================================
# If there appears to be a TeX installation, install our included TeX style
# file(s) into the standard TEXMFLOCAL, so that tex/latex can find & use them.
#
# Note the following complications:
#  * MakeMaker doesn't natively know how to install TeX styles,
#    so we have to add explicit rules to the Makefile.
#  * "staged builds", such as when building & installing rpms
#    install files to a temporary root directory $(DESTDIR).
#    (DESTDIR is generally empty for manual make)
#  * We'll need to run mktexlsr once the files are installed in
#    their _final_ location, so that they are indexed for tex.
#  * We need to be careful constructing pathnames to avoid fouling
#    Windows installations where the pathnames may have spaces.
#    Not to mention working around dmake's limitations.
#
# Strategy:
#  * During "perl Makefile.PL", tentatively use kpsewhich to find
#    if kpsewhich exists, and if so, where the style files should go.
#    This directory is stored in the Makefile (hopefully doesn't change later?)
#  * During "make pure_install", including staged builds,
#    if we've been supplied with a texmf directory, create the appropriate
#    subdirectories and install the style files there (but under $(DESTDIR))
#  * During "make pure_install", but NOT during staged builds, run mktexlsr.
#    We test this simply by checking if texmf is writable.
#  * Add "post install" operations to staged build specfiles
#    to run mktexlsr.
#  * Wrap each entire TeX-related pathname in ONE set of double quotes to protect
#    embedded spaces.
sub install_TeXStyles {
  if (!$TEXMF) {
    $KPSE_TOOLCHAIN = "--miktex-admin" if ($ENV{"LATEXML_KPSEWHICH_MIKTEX_ADMIN"}); # assume miktex admin on windows CI
    if (system("kpsewhich --version $KPSE_TOOLCHAIN") == 0) {                       # can run kpsewhich?
      $TEXMF = `kpsewhich --expand-var='\$TEXMFLOCAL' $KPSE_TOOLCHAIN`;
      # Strip the quotes (they appear in windows, when spaces in pathnames(?))
      # These quotes inhibit pasting pathnames togheter,
      # but we DO need to wrap quotes around all completed paths!!
      chomp($TEXMF); $TEXMF =~ s/^'//; $TEXMF =~ s/'$//; } }
  if (!$TEXMF) {
    warn "Warning: no TeX installation found.\n",
      "  TeX is NOT required, but LaTeXML will have limited functionality.\n";
    return; }

  $$MORE_MACROS{INST_TEXMFDIR}           = '$(INST_LIB)/LaTeXML/texmf';
  $$MORE_MACROS{INSTALLTEXMFDIR}         = "$TEXMF/tex/latex/latexml";
  $$MORE_MACROS{DESTINSTALLTEXMFDIR}     = '$(DESTDIR)$(INSTALLTEXMFDIR)';
  $$MORE_MACROS{INSTALLTEXMFBASEDIR}     = "$TEXMF";
  $$MORE_MACROS{DESTINSTALLTEXMFBASEDIR} = '$(DESTDIR)$(INSTALLTEXMFBASEDIR)';
  $MORE_MAKERULES .= <<'InstallTeXStyles';
pure_install ::
	$(NOECHO) (($(PERLRUN) -e "exit(1) unless shift;" -- "$(INSTALLTEXMFBASEDIR)") && \
	$(MKPATH) "$(DESTINSTALLTEXMFDIR)" && \
	$(MOD_INSTALL) \
		read "$(INSTALLTEXMFDIR)/.packlist" \
		write "$(DESTINSTALLTEXMFDIR)/.packlist" \
		"$(INST_TEXMFDIR)" "$(DESTINSTALLTEXMFDIR)" ) \
	||   echo "No TeX installation, skipping installing LaTeXML TeX packages"

uninstall ::
	$(NOECHO) (($(PERLRUN) -e "exit(1) unless -w shift;" -- "$(DESTINSTALLTEXMFBASEDIR)") && \
		$(UNINSTALL) "$(INSTALLTEXMFDIR)/.packlist") \
	|| echo "No write permission for $(INSTALLTEXMFBASEDIR), skipping uninstalling LaTeXML TeX packages"

InstallTeXStyles

  if (!$NOMKTEXLSR) {
    $MORE_MAKERULES .= <<'InstallTeXStyles';
pure_install ::
	$(NOECHO) ($(PERLRUN) -e "exit(1) if -w shift;" -- "$(INSTALLTEXMFBASEDIR)" || mktexlsr) \
	||   echo "No write permission for $(INSTALLTEXMFBASEDIR), skipping mktexlsr"

uninstall ::
	$(NOECHO) ($(PERLRUN) -e "exit(1) if -w shift;" -- "$(INSTALLTEXMFBASEDIR)" || mktexlsr) \
	||   echo "No write permission for $(INSTALLTEXMFBASEDIR), skipping mktexlsr"

InstallTeXStyles
  }
  return; }

#======================================================================
# Create dumps of plain.tex & latex.ltx
# Ideally, would depend on /<system>/texmf-dist/.../plain.tex & latex.ltx
# This is still experimental/optional, otherwise should add formats to pure_all target!
sub dump_formats {
  $$MORE_MACROS{INST_FMTDIR}  = '$(INST_LIB)/LaTeXML/Engine';
  $$MORE_MACROS{STRICT_IN_CI} = $ENV{CI} ? "--strict" : "";
  $MORE_MAKERULES .= <<'DumpFormats';

# Create dump file for format plain.tex, latex.ltx
formats :: all formats-clean

formats :: $(INST_FMTDIR)/plain_dump.pool.ltxml

$(INST_FMTDIR)/plain_dump.pool.ltxml:
	$(PERLRUN) $(INST_SCRIPT)/latexml --init=plain.tex $(STRICT_IN_CI) --dest=$(INST_FMTDIR)/plain_dump.pool.ltxml
	$(NOECHO) $(PERLRUN) -e "exit(1) unless -e '$(INST_FMTDIR)/plain_dump.pool.ltxml'" \
	|| (echo "LaTeXML FAILED to dump format for plain.tex" && exit 1)

formats :: $(INST_FMTDIR)/latex_dump.pool.ltxml

$(INST_FMTDIR)/latex_dump.pool.ltxml:
	$(PERLRUN) $(INST_SCRIPT)/latexml --init=latex.ltx $(STRICT_IN_CI) --dest=$(INST_FMTDIR)/latex_dump.pool.ltxml
	$(NOECHO) $(PERLRUN) -e "exit(1) unless -e '$(INST_FMTDIR)/latex_dump.pool.ltxml'" \
	|| (echo "LaTeXML FAILED to dump format for latex.ltx" && exit 1)

formats-clean ::
	$(RM_F) \
	$(INST_FMTDIR)/plain_dump.pool.ltxml \
	$(INST_FMTDIR)/latex_dump.pool.ltxml

DumpFormats
  return; }

#======================================================================
# Extra tests for Tikz; too slow for everyday tests.
sub extra_Tests {
  $MORE_MAKERULES .= <<'ExtraTests';

EXTRA_TEST_FILES = t/*.tt

fulltest : test extratest

extratest ::
	PERL_DL_NONLAZY=1 $(FULLPERLRUN) "-MExtUtils::Command::MM" "-e" "test_harness($(TEST_VERBOSE), '$(INST_LIB)', '$(INST_ARCHLIB)')" $(EXTRA_TEST_FILES)

ExtraTests
  return; }

#**********************************************************************
# Overriding ExtUtils::MM methods
#**********************************************************************
package MY;
# Exclude the sources used to generate others from the build (See below).
sub libscan {
  my ($self, $path) = @_;
  if (($path =~ /~$/) || grep { $path eq $_ } @EXCLUSIONS) {
    return ""; }
  return $self->MY::SUPER::libscan($path); }

# Append any additional Makefile rules added by the following.
sub postamble {
  my ($self, @rules) = @_;
  return $self->MY::SUPER::postamble(@rules) . $MORE_MAKERULES; }

1;
#======================================================================
