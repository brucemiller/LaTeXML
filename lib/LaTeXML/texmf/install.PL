#!/usr/bin/perl -w

#======================================================================
# This script can be run at install time (or later)
# to install LaTeX style files accompanying LaTeXML in TeX's texmf directory
#
# This is
#======================================================================
use strict;
use FindBin;

#----------------------------------------------------------------------
# Locations
#----------------------------------------------------------------------
# Find the stylefiles located in the SAME directory as this script!
my $sourcedir = $FindBin::RealBin;

# Find the local texmf; typically /usr/local/share/texmf
my $texmflocal = `kpsewhich --expand-var='\$TEXMFLOCAL'`;
fail("No usable TeX installation found.") unless $texmflocal;
chomp($texmflocal);

my $destdir   = "$texmflocal/tex/latex/latexml";

# IF $RPM_BUILD_ROOT environment variable is set,
# we're presumably building an RPM??
# Then be sure to install to that dir!
# The files will get put in the right place later... (or ?)
# We still need to run texhash after the REAL install!!!
if($ENV{RPM_BUILD_ROOT}){
  $destdir = $ENV{RPM_BUILD_ROOT}.$destdir; }

#----------------------------------------------------------------------
# Installation
#----------------------------------------------------------------------
# Use ExtUtils::Command for the filesystem operations,
# in the hope that it will do the Right Thing(?)

# Now create the appropriate temxf subdirectory
system('perl', "-MExtUtils::Command","-e mkpath",$destdir) == 0
  or fail("Couldn't create texmf directory $destdir");

# And copy the styles there.
system('perl',"-MExtUtils::Command","-e cp","$sourcedir/*.sty",$destdir) == 0
  or fail("Couldn't copy the styles to $destdir");

#----------------------------------------------------------------------
# Updating TeX
#----------------------------------------------------------------------
# If we're NOT building an rpm, we tell TeX to update it's search path tables.
# If we ARE building an rpm, this will have to be handled in the specfile.
if(! $ENV{RPM_BUILD_ROOT}){
  system('texhash')==0
    or fail("Couldn't run texhash to update TeX's search paths: $!"); }

#----------------------------------------------------------------------
# We print a warning message, but return 0,
# so that this doesn't stop installation.
sub fail {
  my($msg)=@_;
  print STDERR "Cannot install LaTeXML's LaTeX style files:\n$msg\n";
  exit(0); }
