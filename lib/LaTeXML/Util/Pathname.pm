# -*- CPERL -*-
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
our @ISA    = qw(Exporter);
our @EXPORT = qw( &pathname_find &pathname_findall
  &pathname_make &pathname_canonical
  &pathname_split &pathname_directory &pathname_name &pathname_type
  &pathname_timestamp
  &pathname_concat
  &pathname_relative &pathname_absolute
  &pathname_is_absolute &pathname_is_contained
  &pathname_is_url &pathname_is_literaldata
  &pathname_protocol
  &pathname_cwd &pathname_mkdir &pathname_copy);

# NOTE: For absolute pathnames, the directory component starts with
# whatever File::Spec considers to be the volume, or "/".
#======================================================================
# Ioan Sucan suggests switching this to '\\' for windows, but notes
# that it works as it is, so we'll leave it (for now).
our $SEP         = '/';
our $LITERAL_RE  = '(?:literal)(?=:)';
our $PROTOCOL_RE = '(?:https|http|ftp)(?=:)';

#======================================================================
# pathname_make(dir=>dir, name=>name, type=>type);
# Returns a pathname.  This will be an absolute path if
# dir (or the first, if dir is an array), is absolute.
sub pathname_make {
  my (%pieces) = @_;
  my $pathname = '';
  if (my $dir = $pieces{dir}) {
    my @dirs = (ref $dir eq 'ARRAY' ? @$dir : ($dir));
    $pathname = shift(@dirs);
    foreach my $d (@dirs) {
      $pathname =~ s|\Q$SEP\E$||; $dir =~ s|^\Q$SEP\E||;
      $pathname .= $SEP . $dir; } }
  $pathname .= $SEP if $pathname && $pieces{name} && $pathname !~ m|\Q$SEP\E$|;
  $pathname .= $pieces{name} if $pieces{name};
  $pathname .= '.' . $pieces{type} if $pieces{type};
  pathname_canonical($pathname); }

# Split the pathname into components (dir,name,type).
# If pathname is absolute, dir starts with volume or '/'
sub pathname_split {
  my ($pathname) = @_;
  $pathname = pathname_canonical($pathname);
  my ($vol, $dir, $name) = File::Spec->splitpath($pathname);
  # Hmm, for /, we get $dir = / but we want $vol='/'  ?????
  if ($vol) { $dir = $vol . $dir; }
  elsif (File::Spec->file_name_is_absolute($pathname) && !File::Spec->file_name_is_absolute($dir)) { $dir = $SEP . $dir; }
  # $dir shouldn't end with separator, unless it is root.
  $dir =~ s/\Q$SEP\E$// unless $dir eq $SEP;
  my $type = '';
  $type = $1 if $name =~ s/\.([^\.]+)$//;
  ($dir, $name, $type); }

use Carp;

sub pathname_canonical {
  my ($pathname) = @_;
  if ($pathname =~ /^($LITERAL_RE)/) {
    return $pathname; }
  # Don't call pathname_is_absolute, etc, here, cause THEY call US!
  confess "Undefined pathname!" unless defined $pathname;
  #  File::Spec->canonpath($pathname); }
  $pathname =~ s|^~|$ENV{HOME}|;
  # We CAN canonicalize urls, but we need to be careful about the // before host!
  my $urlprefix = undef;
  if ($pathname =~ s|^($PROTOCOL_RE//[^/]*)/|/|) {
    $urlprefix = $1; }

  if ($pathname =~ m|//+/|) {
    Carp::cluck "Recursive pathname? : $pathname\n"; }
##  $pathname =~ s|//+|/|g;
  $pathname =~ s|/\./|/|g;
  # Collapse any foo/.. patterns, but not ../..
  while ($pathname =~ s|/(?!\.\./)[^/]+/\.\.(/\|$)|$1|) { }
  $pathname =~ s|^\./||;
  (defined $urlprefix ? $urlprefix . $pathname : $pathname); }

# Convenient extractors;
sub pathname_directory {
  my ($dir, $name, $type) = pathname_split(@_);
  $dir; }

sub pathname_name {
  my ($dir, $name, $type) = pathname_split(@_);
  $name; }

sub pathname_type {
  my ($dir, $name, $type) = pathname_split(@_);
  $type; }

# Note that this returns ONLY recognized protocols!
sub pathname_protocol {
  my ($pathname) = @_;
  return ($pathname =~ /^($PROTOCOL_RE|$LITERAL_RE)/ ? $1 : 'file'); }

#======================================================================
sub pathname_concat {
  my ($dir, $file) = @_;
  return $file unless $dir;
  return $dir if !defined $file || ($file eq '.');
  pathname_canonical(File::Spec->catpath('', $dir || '', $file)); }

#======================================================================
# Is $pathname an absolute pathname ?
# pathname_is_absolute($pathname) => (0|1)
sub pathname_is_absolute {
  my ($pathname) = @_;
  $pathname && File::Spec->file_name_is_absolute(pathname_canonical($pathname)); }

sub pathname_is_url {
  my ($pathname) = @_;
  $pathname && $pathname =~ /^($PROTOCOL_RE)/ && $1; }    # Other protocols?

sub pathname_is_literaldata {
  my ($pathname) = @_;
  ($pathname =~ /^($LITERAL_RE)/) && $1; }

# Check whether $pathname is contained in (ie. underneath) $base
# Returns the relative pathname if it is underneath; undef otherwise.
sub pathname_is_contained {
  my ($pathname, $base) = @_;
  # after assuring that both paths are absolute,
  # get $pathname relative to $base
  my $rel = pathname_canonical(pathname_relative(pathname_absolute($pathname),
      pathname_absolute($base)));
  # If the relative pathname starts with "../" that it apparently is NOT underneath base!
  ($rel =~ m|^\.\./| ? undef : $rel); }

# pathname_relative($pathname,$base) => $relativepathname
# If $pathname is an absolute, non-URL pathname,
# return the pathname relative to $base,
# else just return its canonical form.
# Actually, if it's a url and $base is also url, to SAME host! & protocol...
# we _could_ make relative...
sub pathname_relative {
  my ($pathname, $base) = @_;
  $pathname = pathname_canonical($pathname);
  ($base && pathname_is_absolute($pathname) && !pathname_is_url($pathname)
    ? File::Spec->abs2rel($pathname, pathname_canonical($base))
    : $pathname); }

sub pathname_absolute {
  my ($pathname, $base) = @_;
  $pathname = pathname_canonical($pathname);
  (!pathname_is_absolute($pathname) && !pathname_is_url($pathname)
    ? File::Spec->rel2abs($pathname, ($base ? pathname_canonical($base) : pathname_cwd()))
    : $pathname); }

#======================================================================
# Actual file system operations.
sub pathname_timestamp {
  -f $_[0] ? (stat($_[0]))[9] : 0; }

our $Pathname_CWD = pathname_canonical(cwd());
sub pathname_cwd { $Pathname_CWD; }

sub pathname_mkdir {
  my ($directory) = @_;
  return unless $directory;
  $directory = pathname_canonical($directory);
  my ($volume, $dirs, $last) = File::Spec->splitpath($directory);
  my (@dirs) = (File::Spec->splitdir($dirs), $last);
  for (my $i = 0 ; $i <= $#dirs ; $i++) {
    my $dir = File::Spec->catpath($volume, File::Spec->catdir(@dirs[0 .. $i]), '');
    if (!-d $dir) {
      mkdir($dir) or return; } }
  return $directory; }

# copy a file, preserving attributes, if possible.
# Why doesn't File::Copy preserve attributes on Unix !?!?!?
sub pathname_copy {
  my ($source, $destination) = @_;
  # If it _needs_ to be copied:
  $source      = pathname_canonical($source);
  $destination = pathname_canonical($destination);
  if ((!-f $destination) || (pathname_timestamp($source) > pathname_timestamp($destination))) {
    if (my $destdir = pathname_directory($destination)) {
      pathname_mkdir($destdir) or return; }
###    if($^O =~ /^(MSWin32|NetWare)$/){ # Windows
###      # According to Ioan, this should work:
###      system("xcopy /P $source $destination")==0 or return; }
###    else {               # Unix
###      system("cp --preserve=timestamps $source $destination")==0 or return; }
    # Hopefully this portably copies, preserving timestamp.
    copy($source, $destination) or return;
    my ($atime, $mtime) = (stat($source))[8, 9];
    utime $atime, $mtime, $destination;    # And set the modification time
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

our @INSTALLDIRS = grep(-d $_, map(pathname_canonical("$_/LaTeXML"), @INC));

sub pathname_find {
  my ($pathname, %options) = @_;
  return unless $pathname;
  my @paths = candidate_pathnames($pathname, %options);
  foreach my $path (@paths) {
    return $path if -f $path; } }

sub pathname_findall {
  my ($pathname, %options) = @_;
  return unless $pathname;
  my @paths = candidate_pathnames($pathname, %options);
  grep(-f $_, @paths); }

# It's presumably cheep to concatinate all the pathnames,
# relative to the cost of testing for files,
# and this simplifies overall.
sub candidate_pathnames {
  my ($pathname, %options) = @_;
  my @dirs = ();
  $pathname = pathname_canonical($pathname);
  my ($pathdir, $name, $type) = pathname_split($pathname);
  $name .= '.' . $type if $type;
  if (pathname_is_absolute($pathname)) {
    push(@dirs, $pathdir); }
  else {
    my $cwd = pathname_cwd();
    if ($options{paths}) {
      foreach my $p (@{ $options{paths} }) {
        # Complete the search paths by prepending current dir to relative paths,
        my $pp = pathname_concat((pathname_is_absolute($p) ? pathname_canonical($p) : pathname_concat($cwd, $p)),
          $pathdir);
        push(@dirs, $pp) unless grep($pp eq $_, @dirs); } }    # but only include each dir ONCE
    push(@dirs, pathname_concat($cwd, $pathdir)) unless @dirs;    # At least have the current directory!
           # And, if installation dir specified, append it.
    if (my $subdir = $options{installation_subdir}) {
      push(@dirs, map(pathname_concat($_, $subdir), @INSTALLDIRS)); } }

  # extract the desired extensions.
  my @exts = ();
  if ($options{types}) {
    foreach my $ext (@{ $options{types} }) {
      if ($ext eq '') { push(@exts, ''); }
      elsif ($ext eq '*') {
        push(@exts, '.*', ''); }
      elsif ($pathname =~ /\.\Q$ext\E$/i) {
        push(@exts, ''); }
      else {
        push(@exts, '.' . $ext); } } }
  push(@exts, '') unless @exts;

  my @paths = ();
  # Now, combine; precedence to leading directories.
  foreach my $dir (@dirs) {
    foreach my $ext (@exts) {
      if ($ext eq '.*') {    # Unfortunately, we've got to test the file system NOW...
        opendir(DIR, $dir) or next;    # ???
        push(@paths, map(pathname_concat($dir, $_), grep(/^\Q$name\E\.\w+$/, readdir(DIR))));
        closedir(DIR); }
      else {
        push(@paths, pathname_concat($dir, $name . $ext)); } } }
  @paths; }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Util::Pathname>  - portable pathname and file-system utilities

=head1 DESCRIPTION

This module combines the functionality L<File::Spec> and L<File::Basename> to
give a consistent set of filename utilties for LaTeXML.
A pathname is represented by a simple string.

=head2 Pathname Manipulations

=over 4

=item C<< $path = pathname_make(%peices); >>

Constructs a pathname from the keywords in pieces
  dir   : directory
  name  : the filename (possibly with extension)
  type  : the filename extension

=item C<< ($dir,$name,$type) = pathname_split($path); >>

Splits the pathname C<$path> into the components: directory, name and type.

=item C<< $path = pathname_canonical($path); >>

Canonicallizes the pathname C<$path> by simplifying repeated slashes,
dots representing the current or parent directory, etc.

=item C<< $dir = pathname_directory($path); >>

Returns the directory component of the pathname C<$path>.

=item C<< $name = pathname_name($path); >>

Returns the name component of the pathname C<$path>.

=item C<< $type = pathname_type($path); >>

Returns the type component of the pathname C<$path>.

=item C<< $path = pathname_concat($dir,$file); >>

Returns the pathname resulting from concatenating
the directory C<$dir> and filename C<$file>.

=item C<< $boole = pathname_is_absolute($path); >>

Returns whether the pathname C<$path> appears to be an absolute pathname.

=item C<< $boole = pathname_is_url($path); >>

Returns whether the pathname C<$path> appears to be a url, rather than local file.

=item C<< $rel = pathname_is_contained($path,$base); >>

Checks whether C<$path> is underneath the directory C<$base>; if so
it returns the pathname C<$path> relative to C<$base>; otherwise returns undef.

=item C<< $path = pathname_relative($path,$base); >>

If C<$path> is an absolute, non-URL pathname,
returns the pathname relative to the directory C<$base>,
otherwise simply returns the canonical form of C<$path>.

=item C<< $path = pathname_absolute($path,$base); >>

Returns the absolute pathname resulting from interpretting
C<$path> relative to the directory C<$base>.  If C<$path>
is already absolute, it is returned unchanged.

=back

=head2 File System Operations

=over 4

=item C<< $modtime = pathname_timestamp($path); >>

Returns the modification time of the file named by C<$path>,
or undef if the file does not exist.

=item C<< $path = pathname_cwd(); >>

Returns the current working directory.

=item C<< $dir = pathname_mkdir($dir); >>

Creates the directory C<$dir> and all missing ancestors.
It returns C<$dir> if successful, else undef.

=item C<< $dest = pathname_copy($source,$dest); >>

Copies the file C<$source> to C<$dest> if needed;
ie. if C<$dest> is missing or older than C<$source>.
It preserves the timestamp of C<$source>.

=item C<< $path = pathname_find($name,%options); >>

Finds the first file named C<$name> that exists 
and that matches the specification
in the keywords C<%options>.  
An absolute pathname is returned.

If C<$name> is not already an absolute pathname, then
the option C<paths> determines directories to recursively search.
It should be a list of pathnames, any relative paths
are interpreted relative to the current directory.
If C<paths> is omitted, then the current directory is searched.

If the option C<installation_subdir> is given, it
indicates, in addition to the above, a directory relative
to the LaTeXML installation directory to search.
This allows files included with the distribution to be found.

The C<types> option specifies a list of filetypes to search for.
If not supplied, then the filename must match exactly.
The type C<*> matches any extension.

=item C<< @paths = pathname_findall($name,%options); >>

Like C<pathname_find>,
but returns I<all> matching (absolute) paths that exist.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

