#!/usr/bin/perl -w

#======================================================================
# This script can be run at install time (or later)
# to install LaTeX style in the standard texmf directory
#======================================================================
use strict;
use FindBin;


# Find the local texmf; typically /usr/local/share/texmf
my $texmflocal = `kpsewhich --expand-var='\$TEXMFLOCAL'`;
fail("No usable TeX installation found.") unless $texmflocal;
chomp($texmflocal);

# IF this environment variable is set, we're presumably building an RPM?
# Then we need to install to the temporary installation.
# They'll get put in the right place later... (or ?)
# AND, we'll still need to run texhash after the REAL install!!!
if($ENV{RPM_BUILD_ROOT}){
  $texmflocal = $ENV{RPM_BUILD_ROOT}.$texmflocal; }

# Check that the current user can actually write there.
## fail("The texmf directory is not writable by the current user.")
##   unless  -w $texmflocal;

# Find the stylefiles located in the same directory as this script!
my $sourcedir = $FindBin::RealBin;
my $destdir   = "$texmflocal/tex/latex/latexml";

# Use ExtUtils::Command for the filesystem operations,
# in the hope that it will do the Right Thing(?)

# Now create the appropriate temxf subdirectory
system('perl', "-MExtUtils::Command","-e mkpath",$destdir) == 0
  or fail("Couldn't create texmf directory $destdir");

### opendir(STYLES,$sourcedir) or fail("Couldn't read style directory $sourcedir");
### my @styles = map("$sourcedir/$_",grep(/\.sty$/,readdir(STYLES)));
### closedir(STYLES);

# And copy the styles there.
### system('perl',"-MExtUtils::Command","-e cp",@styles,$destdir) == 0
system('perl',"-MExtUtils::Command","-e cp","$sourcedir/*.sty",$destdir) == 0
  or fail("Couldn't copy the styles to $destdir");

# Finally, tell TeX to update it's search path hash tables.
# But note that if we're building an RPM, we want to do it when the
# package REALLY gets installed.
# ??? Use the cpan2rpm otion:  --epilogue="post:texhash"

if(! $ENV{RPM_BUILD_ROOT}){
  system('texhash')==0
    or fail("Couldn't run texhash to update TeX's search paths: $!");
}

# We print a warning message, but return 0,
# so that this doesn't stop installation.
sub fail {
  my($msg)=@_;
  print STDERR "Cannot install LaTeXML's LaTeX style files:\n$msg\n";
  exit(0); }
