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
#======================================================================

our $OLD_LIBXML = grep { /OLD_LIBXML/ } @ARGV;
our $TEXMF;
my ($texmfspec) = grep { /^TEXMF/ } @ARGV;
if ($texmfspec && $texmfspec =~ /^TEXMF\s*=(.*)$/) {
  $TEXMF = $1;
  @ARGV = grep { $_ ne $texmfspec } @ARGV;    # Remove so MakeMaker doesn't fret.
}
our @EXCLUSIONS     = ();
our $MORE_MACROS    = {};
our $MORE_MAKERULES = '';

record_revision();
compile_MathGrammar();
install_TeXStyles();
extra_Tests();

WriteMakefile(NAME => 'LaTeXML',
  AUTHOR       => 'Bruce Miller <bruce.miller@nist.gov>',
  ABSTRACT     => "transforms TeX and LaTeX into XML",
  VERSION_FROM => 'lib/LaTeXML/Version.in',
  PREREQ_PM    => {
    'Archive::Zip'      => 0,
    'DB_File'           => 0,
    'File::Which'       => 0,
    'Getopt::Long'      => 2.37,
    'Image::Size'       => 0,
    'IO::String'        => 0,
    'JSON::XS'          => 0,
    'LWP'               => 0,
    'Parse::RecDescent' => 0,
    'URI'               => 0,
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
  macro => $MORE_MACROS,
);

print STDERR ('=' x 55), "\n",
  "| If you plan on developing code, please consider using\n",
  "| the git pre-commit hook to assure style compliant code.\n",
  "| To install:\n",
  "|    ln -s ../../tools/pre-commit .git/hooks\n",
  ('=' x 55), "\n" unless -x '.git/hooks/pre-commit';
#**********************************************************************
# Overriding ExtUtils::MM methods
#**********************************************************************
# Exclude the sources used to generate others from the build (See below).
sub MY::libscan {
  my ($self, $path) = @_;
  if (($path =~ /~$/) || grep { $path eq $_ } @EXCLUSIONS) {
    return ""; }
  return $self->MY::SUPER::libscan($path); }

# Append any additional Makefile rules added by the following.
sub MY::postamble {
  my ($self, @rules) = @_;
  return $self->MY::SUPER::postamble(@rules) . $MORE_MAKERULES; }

#**********************************************************************
# Special Cases
#**********************************************************************

#======================================================================
# Record the current (svn) repository revision number
sub record_revision {
  # Don't copy the Version template to the installation; it's not needed
  push(@EXCLUSIONS, 'blib/lib/LaTeXML/Version.in');
  # This should be the top-level directory, so it's revision should represent the whole project
  $$MORE_MACROS{REVISION_BASE} = $FindBin::RealBin;
  # This is where the REVISION gets stored (along with VERSION, etc)
  $$MORE_MACROS{REVISION_FILE} = '$(INST_LIBDIR)/LaTeXML/Version.pm';
  # Get the current revision
  # This should be done SAFELY; and work even if svnversion isn't available (esp, windows, mac...)
  # (When it isn't there's an error, but REVISION ends up "" ... exactly right, I think?)
  ## This command is appropriate for svn
  ##  $$MORE_MACROS{REVISION} = '$(shell svnversion $(REVISION_BASE))';
  ## This command is appropriate for git (I think)
  if (system("git --version") == 0) {    # can run git? if so, try to determine the revision
    $$MORE_MACROS{REVISION} = '$(shell git log --max-count=1 --abbrev-commit --pretty="%h")'; }
  # Extract the previously recorded revision from the revision file (awkward)
  $$MORE_MACROS{OLD_REVISION}
    = '`$(PERLRUN) -ne \'chomp;if(s/.*?REVISION\\s*=\\s*\\"// && s/\\".*//){print;}\' < $(REVISION_FILE)`';
  # Substitute the revision into the revision template
  $$MORE_MACROS{RECORD_REVISION} = '$(PERLRUN) -pe "s@__REVISION__@$(REVISION)@" ';

  # Have concerns about the $(noecho), but otherwise, it's annoying!
  # it prints _every_ time you make, even if it doesn't update!

  $MORE_MAKERULES .= <<'RecordRevision';

# Record the svn revision in the Version module, for more informative diagnostics
pure_all :: $(REVISION_FILE) update_revision

# Always set version if version module template is newer
$(REVISION_FILE): lib/LaTeXML/Version.in
	$(RECORD_REVISION) lib/LaTeXML/Version.in > $(REVISION_FILE)

# update version if stored revision if not current
update_revision:
	- $(NOECHO) test $(REVISION) = $(OLD_REVISION) \
	|| $(RECORD_REVISION) lib/LaTeXML/Version.in > $(REVISION_FILE)

RecordRevision
  return; }
#======================================================================
# We'll compile the RecDescent grammar during make; don't need to install grammar.
sub compile_MathGrammar {
  push(@EXCLUSIONS, 'blib/lib/LaTeXML/MathGrammar');
  $MORE_MAKERULES .= <<'MakeGrammar';

# Precompile the (Recursive Descent) MathGrammar
pure_all :: $(INST_LIBDIR)/LaTeXML/MathGrammar.pm

$(INST_LIBDIR)/LaTeXML/MathGrammar.pm: lib/LaTeXML/MathGrammar
	$(PERLRUN) -MParse::RecDescent - lib/LaTeXML/MathGrammar LaTeXML::MathGrammar
	$(NOECHO) $(MKPATH) $(INST_LIBDIR)/LaTeXML
	$(MV) MathGrammar.pm blib/lib/LaTeXML/MathGrammar.pm

MakeGrammar
  return; }

#======================================================================
# Install included TeX style file(s) into the standard TEXMFLOCAL,
# [note that this script has to handle the indirect installation for rpms!]
#
# FIGURE THIS OUT; We want to append
#      --prefix=$(DESTDIR)
# to install.PL so that it can "install" to staging directories
# but for manual $(DESTDIR) is empty, so install.PL complains...
#
# CURRENTLY: We want to attempt to install the TeX files
# IF there appears to be a TeX installation
# BUT still fail gracefully if we are unable to install there.
# This accommodates NOT making TeX a dependency
# AND in case we're doing a local install (like from CPAN)
# where we don't have permission to install into the TeX installation.
# Whew!!
#
# AND NOTE: That the tests involved are painful & contrived
# since they need to accomodate featureful gnu-make as well as
# fairly lame dmake on windows....
sub install_TeXStyles {
  if (!$TEXMF) {
    if (system("kpsewhich --expand-var='\$TEXMFLOCAL'") == 0) {    # can run kpsewhich?
      $TEXMF = `kpsewhich --expand-var='\$TEXMFLOCAL'`;
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
  # The installation directory of TeX may well have spaces which screws up Make.
  # we need to wrap any pathname that includes TEXMF with quotes in case of embedded spaces
  # The quotes apparently don't hurt, when they completely enclose the path.
  # ACTUALLY, (apparently) we must ONLY use double quotes to wrap with.
  # (at least in the stuff that gets evaluated at a shell(like) level)
  # It seems that single quotes cause some other oddness in windows(????)
  # Note the dance below with -w shift; this is to keep from nesting quotes!
  $MORE_MAKERULES .= <<'InstallTeXStyles';

# Install LaTeXML's LaTeX style files into the standard texmf location
pure_install ::
	$(NOECHO) (($(PERLRUN) -e "exit(1) unless -w shift;" -- "$(DESTINSTALLTEXMFBASEDIR)") && \
	$(MKPATH) "$(DESTINSTALLTEXMFDIR)" && \
	$(MOD_INSTALL) \
		read "$(INSTALLTEXMFDIR)/.packlist" \
		write "$(DESTINSTALLTEXMFDIR)/.packlist" \
		"$(INST_TEXMFDIR)" "$(DESTINSTALLTEXMFDIR)" && \
	($(PERLRUN) -e "exit(1) if -w shift;" -- "$(INSTALLTEXMFDIR)" || mktexlsr)) \
	|| echo "No write permission for $(DESTINSTALLTEXMFBASEDIR), skipping installing LaTeXML TeX packages"

uninstall ::
	$(NOECHO) (($(PERLRUN) -e "exit(1) unless -w shift;" -- "$(DESTINSTALLTEXMFBASEDIR)") && \
		$(UNINSTALL) "$(INSTALLTEXMFDIR)/.packlist" && \
		($(PERLRUN) -e "exit(1) if -w shift;" -- "$(INSTALLTEXMFDIR)" || mktexlsr)) \
	|| echo "No write permission for $(DESTINSTALLTEXMFBASEDIR), skipping uninstalling LaTeXML TeX packages"

InstallTeXStyles
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

#======================================================================
