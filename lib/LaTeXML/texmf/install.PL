#!/usr/bin/perl -w

#======================================================================
# This script installs the LaTeXML's companion style files for LaTeX.
#======================================================================
# It installs the style files (all *.sty in the same directory as
# this script) to TeX's $TEXMFLOCAL directory, and invokes texhash,
# so that TeX can find the new styles.
#
# It can be used 
#   * directly during make,
#   * manually, eg. after TeX has been installed.
#
# With the option: --prefix=<stagingdirectory>
# it "stages" the installation to the staging directory, but does not run texhash.
# This option is useful for creating rpms, macports,...
# The specfile/portfile/... must arrange for texhash to be run
# after the _real_ installation, so that TeX can find the style files.
#======================================================================
# NOTE that this expects to find TeX's utilities (kpsewhich and texhash)
# in the current command paths.
# Failure to install styles does NOT cause failure of the make/build.
#======================================================================
use strict;
use FindBin;
use Getopt::Long qw(:config no_ignore_case);

my $PREFIX = '';
GetOptions("prefix=s" => \$PREFIX);

#----------------------------------------------------------------------
# Locations
#----------------------------------------------------------------------
# Find the stylefiles located in the SAME directory as this script!
my $SOURCEDIR = $FindBin::RealBin;

# Find the local texmf; typically /usr/local/share/texmf
my $texmflocal = `kpsewhich --expand-var='\$TEXMFLOCAL'`;
fail("No TeX installation found.") unless $texmflocal;
chomp($texmflocal);

my $DESTDIR   = "$PREFIX$texmflocal/tex/latex/latexml";

#----------------------------------------------------------------------
# Installation
#----------------------------------------------------------------------
# Use ExtUtils::Command for the filesystem operations,
# in the hope that it will do the Right Thing portably(?)

# Create the appropriate temxf subdirectory
system('perl', "-MExtUtils::Command","-e mkpath",$DESTDIR) == 0
  or fail("Couldn't create texmf directory $DESTDIR");

# And copy the styles there.
system('perl',"-MExtUtils::Command","-e cp","$SOURCEDIR/*.sty",$DESTDIR) == 0
  or fail("Couldn't copy the styles to $DESTDIR");

#----------------------------------------------------------------------
# Updating TeX
#----------------------------------------------------------------------
# If we're NOT staging the installation, update TeX's search paths.
# If we ARE staging, this will have to be handled in the specfile/portfile/whatever!
if(! $PREFIX){
  system('texhash')==0
    or fail("Couldn't run texhash to update TeX's search paths: $!"); }

#----------------------------------------------------------------------
# We print a warning message, but return 0,
# so that this doesn't stop installation.
sub fail {
  my($msg)=@_;
  print STDERR "Cannot install LaTeXML's LaTeX style files:\n$msg\n";
  exit(0); }
