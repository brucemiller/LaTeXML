# /=====================================================================\ #
# |  LaTeXML::Util::Pathname                                            | #
# | Pathname Utilities for LaTeXML                                      | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
#======================================================================
# Sanely combine features of File::Spec and File::Basename
# Somehow, both modules tend to bite me at random times.
# eg. sometimes Basename's fileparse doesn't extract extension.
# sometimes File::Spec seems to do too many filesystem checks (gets slow!)
# File::Spec->splitpath "may or may not ... trailing '/'" ... Huh?
#======================================================================
# My first instinct is that this should bless the pathnames,
# but strings as pathnames come so naturally in perl;
# But I may still do it...
#======================================================================
# Some portability changes for Windows, thanks to Ioan Sucan.
#======================================================================
# Packages in the LaTeXML::Util package set have no dependence on LaTeXML
# objects or context.
#======================================================================
package LaTeXML::Util::Pathname;
use strict;
use File::Spec;
use File::Copy;
use Cwd;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw( &pathname_find &pathname_findall
		  &pathname_make &pathname_canonical
		  &pathname_split &pathname_directory &pathname_name &pathname_type
		  &pathname_concat
		  &pathname_relative &pathname_absolute
		  &pathname_is_absolute 
		  &pathname_cwd &pathname_mkdir &pathname_copy);

# NOTE: For absolute pathnames, the directory component starts with
# whatever File::Spec considers to be the volume, or "/".
#======================================================================
# Ioan Sucan suggests switching this to '\\' for windows, but notes
# that it works as it is, so we'll leave it (for now).
our $SEP = '/';

#======================================================================
# pathname_make(dir=>dir, name=>name, type=>type);
# Returns a pathname.  This will be an absolute path if
# dir (or the first, if dir is an array), is absolute.
sub pathname_make {
  my(%pieces)=@_;
  my $pathname= '';
  my $dir = $pieces{dir};
  $dir = join($SEP,@$dir) if $dir && (ref $dir eq 'ARRAY');
  $pathname .= $dir if $dir;
  $pathname .= $SEP if $pathname && $pieces{name};
  $pathname .= $pieces{name} if $pieces{name};
  $pathname .= '.'.$pieces{type} if $pieces{type};
  pathname_canonical($pathname); }

# Split the pathname into components (dir,name,type).
# If pathname is absolute, dir starts with volume or '/'
sub pathname_split {
  my($pathname)=@_;
  my($vol,$dir,$name)=File::Spec->splitpath($pathname);
  # Hmm, for /, we get $dir = / but we want $vol='/'  ?????
  if($vol) { $dir = $vol.$dir; }
  elsif(pathname_is_absolute($pathname)){ $dir = $SEP.$dir; }
  my $type = '';
  $type = $1 if $name =~ s/\.([^\.]+)$//;
  ($dir,$name,$type); }

sub pathname_canonical {
  my($pathname)=@_;
#  File::Spec->canonpath($pathname); }
  $pathname =~ s|//+|/|g;
  $pathname =~ s|/\./|/|g;
  while($pathname =~ s|/[^/]+/\.\./|/|){}
  $pathname =~ s|^\./||;
  $pathname; }

# Convenient extractors;
sub pathname_directory { 
  my($dir,$name,$type)=pathname_split(@_);
  $dir; }

sub pathname_name { 
  my($dir,$name,$type)=pathname_split(@_);
  $name; }

sub pathname_type { 
  my($dir,$name,$type)=pathname_split(@_);
  $type; }

#======================================================================
sub pathname_concat {
  my($dir,$file)=@_;
  File::Spec->catpath('',$dir || '',$file); }

#======================================================================
# Is $pathname an absolute pathname ?
# pathname_is_absolute($pathname) => (0|1)
sub pathname_is_absolute {
  my($pathname)=@_;
  $pathname && File::Spec->file_name_is_absolute($pathname); }

# pathname_relative($pathname,$base) => $relativepathname
# Return $pathname as a pathname relative to $base.
sub pathname_relative {
  my($pathname,$base)=@_;
  File::Spec->abs2rel(pathname_canonical($pathname),pathname_canonical($base)); }

sub pathname_absolute {
  my($pathname,$base)=@_;
  File::Spec->rel2abs($pathname,$base); }

#======================================================================
# Actual file system operations.
sub pathname_cwd { cwd(); }

sub pathname_mkdir {
  my($directory)=@_;
  return undef unless $directory;
  my($volume,$dirs,$last)=File::Spec->splitpath($directory);
  my(@dirs)=(File::Spec->splitdir($dirs),$last);
  for(my $i=0; $i <= $#dirs; $i++){
    my $dir = File::Spec->catpath($volume,File::Spec->catdir(@dirs[0..$i]),'');
    if(! -d $dir){
      mkdir($dir) or return undef; }}
  return $directory; }

# copy a file, preserving attributes, if possible.
# Why doesn't File::Copy preserve attributes on Unix !?!?!?
sub pathname_copy {
  my($source,$destination)=@_;
  # If it _needs_ to be copied:
  if((!-f $destination) || (-M $source < -M $destination)){
    pathname_mkdir(pathname_directory($destination)) or return undef;
###    if($^O =~ /^(MSWin32|NetWare)$/){ # Windows
###      # According to Ioan, this should work:
###      system("xcopy /P $source $destination")==0 or return undef; }
###    else {			# Unix
###      system("cp --preserve=timestamps $source $destination")==0 or return undef; }
    # Hopefully this portably copies, preserving timestamp.
    copy($source,$destination) or return undef; 
    my($atime,$mtime)= (stat($source))[8,9];
    utime $atime,$mtime,$destination; # And set the modification time
  }
  return $destination; }

#======================================================================
# pathname_find($pathname, paths=>[...], types=>[...])  => $absolute_pathname;
# Find a file corresponding to $pathname returning the absolute,
# completed pathname if found, else undef
#  * If $pathname is a not an absolute pathname 
#    (although it may still have directory components)
#    then if search $paths are given, search for it relative to
#    each of the directories in $paths,
#    else search for it relative to the current working directory.
#  * If types is given, then search (in each searched directory)
#    for the first file with the given extension. 
#    The extension "" (empty string) means to search for the exact name.
#  * If types is not given, search for the exact named file
#    without additional extension.
#  * If installation_subdir is given, look in that subdirectory of where LaTeXML
#    was installed, by appending it to the paths.

our @INSTALLDIRS = grep(-d $_, map("$_/LaTeXML", @INC));

sub pathname_find {
  my($pathname,%options)=@_;
  return undef unless $pathname;
  my @paths = candidate_pathnames($pathname,%options);
  foreach my $path (@paths){
    return $path if -f $path; }}

sub pathname_findall {
  my($pathname,%options)=@_;
  return undef unless $pathname;
  my @paths = candidate_pathnames($pathname,%options);
  grep(-f $_, @paths); }

# It's presumably cheep to concatinate all the pathnames,
# relative to the cost of testing for files,
# and this simplifies overall.
sub candidate_pathnames {
  my($pathname,%options)=@_;
  my @dirs=('');
  if(!pathname_is_absolute($pathname)){
    my $cwd = pathname_cwd();
    # Complete the search paths by prepending current dir to relative paths,
    # but have at least the current dir.
    @dirs = ($options{paths}
	     ? map( (pathname_is_absolute($_) ? $_ : pathname_concat($cwd,$_)),
		    @{$options{paths}})
	     : ($cwd));
    # And, if installation dir specified, append it.
    if(my $subdir = $options{installation_subdir}){
      push(@dirs,map(pathname_concat($_,$subdir),@INSTALLDIRS)); }}

  # extract the desired extensions.
  my @exts = ();
  if($options{types}){
    foreach my $ext (@{$options{types}}){
      if($ext eq ''){ push(@exts,''); }
      elsif($pathname =~ /\.\Q$ext\E$/i){
	push(@exts,''); }
      else {
	# Half attempt at case insensitivity; not actually correct, though.
## Disabled, since it screws up on the Mac's partially case-insensitive (?) filesystem.
##	push(@exts,'.'.lc($ext)) if $ext =~/[A-Z]/;
##	push(@exts,'.'.uc($ext)) if $ext =~/[a-z]/;
	push(@exts, '.'.$ext); }}}
    push(@exts,'') unless @exts;

  my @paths = ();
  # Now, combine; precedence to leading directories.
  foreach my $dir (@dirs){
    foreach my $ext (@exts){
      push(@paths,pathname_concat($dir,$pathname.$ext)); }}
  @paths; }

#======================================================================
1;
