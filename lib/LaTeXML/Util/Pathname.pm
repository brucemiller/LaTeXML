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
use warnings;
use File::Spec;
use File::Copy;
use File::Which;
use Cwd;
use base qw(Exporter);
our @EXPORT = qw( &pathname_find &pathname_findall &pathname_kpsewhich
  &pathname_make &pathname_canonical
  &pathname_split &pathname_directory &pathname_name &pathname_type
  &pathname_timestamp
  &pathname_concat
  &pathname_relative &pathname_absolute &pathname_to_url
  &pathname_is_absolute &pathname_is_contained
  &pathname_is_url &pathname_is_literaldata
  &pathname_is_raw &pathname_is_reloadable
  &pathname_protocol
  &pathname_cwd &pathname_chdir &pathname_mkdir &pathname_copy
  &pathname_installation);

# NOTE: For absolute pathnames, the directory component starts with
# whatever File::Spec considers to be the volume, or "/".
#======================================================================
# Ioan Sucan suggests switching this to '\\' for windows, but notes
# that it works as it is, so we'll leave it (for now).
### my $SEP         = '/';                          # [CONSTANT]
# Some indicators that this is not sufficient? (calls to libraries/externals???)
# PRELIMINARY test, probably need to be even more careful
my $ISWINDOWS   = $^O =~ /^(MSWin|NetWare|cygwin)/i;
my $SEP         = ($ISWINDOWS ? '\\' : '/');    # [CONSTANT]
my $KPATHSEP    = ($ISWINDOWS ? ';'  : ':');    # [CONSTANT]
my $LITERAL_RE  = '(?:literal)(?=:)';           # [CONSTANT]
my $PROTOCOL_RE = '(?:https|http|ftp)(?=:)';    # [CONSTANT]

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
  $pathname .= $SEP                if $pathname && $pieces{name} && $pathname !~ m|\Q$SEP\E$|;
  $pathname .= $pieces{name}       if $pieces{name};
  $pathname .= '.' . $pieces{type} if $pieces{type};
  return pathname_canonical($pathname); }

# Split the pathname into components (dir,name,type).
# If pathname is absolute, dir starts with volume or '/'
sub pathname_split {
  my ($pathname) = @_;
  return unless defined $pathname;
  $pathname = pathname_canonical($pathname);
  my ($vol, $dir, $name) = File::Spec->splitpath($pathname);
  # Hmm, for /, we get $dir = / but we want $vol='/'  ?????
  if ($vol) { $dir = $vol . $dir; }
  elsif (File::Spec->file_name_is_absolute($pathname) && !File::Spec->file_name_is_absolute($dir)) { $dir = $SEP . $dir; }
  # $dir shouldn't end with separator, unless it is root.
  $dir =~ s/\Q$SEP\E$// unless $dir eq $SEP;
  my $type = '';
  if ($name =~ s/\.([^\.]+)$//) { $type = $1; }
  return ($dir, $name, $type); }

use Carp;

# This likely needs portability work!!! (particularly regarding urls, separators, ...)
# AND, care about symbolic links and collapsing ../ !!!
sub pathname_canonical {
  my ($pathname) = @_;
  return unless defined $pathname;
  if ($pathname =~ /^($LITERAL_RE)/) {
    return $pathname; }
  # Don't call pathname_is_absolute, etc, here, cause THEY call US!
  confess "Undefined pathname!" unless defined $pathname;
  #  File::Spec->canonpath($pathname); }
  $pathname =~ s|^~|$ENV{HOME}|;
  # We CAN canonicalize urls, but we need to be careful about the // before host!
  # OHHH, but we DON'T want \ for separator!
  my $urlprefix = undef;
  if ($pathname =~ s|^($PROTOCOL_RE//[^/]*)/|/|) {
    $urlprefix = $1; }

  if ($pathname =~ m|//+/|) {
    Carp::cluck "Recursive pathname? : $pathname\n"; }
##  $pathname =~ s|//+|/|g;
  $pathname =~ s|/\./|/|g;
  # Collapse any foo/.. patterns, but not ../..
  while ($pathname =~ s|/(?!\.\./)[^/]+/\.\.(/\|$)|$1|) { }
  # Reduce ./foo to foo, but preserve ./
  $pathname =~ s|^\./(.)|$1|;
  return (defined $urlprefix ? $urlprefix . $pathname : $pathname); }

# Convenient extractors;
sub pathname_directory {
  my ($pathname) = @_;
  my ($dir, $name, $type) = pathname_split($pathname);
  return $dir; }

sub pathname_name {
  my ($pathname) = @_;
  my ($dir, $name, $type) = pathname_split($pathname);
  return $name; }

sub pathname_type {
  my ($pathname) = @_;
  my ($dir, $name, $type) = pathname_split($pathname);
  return $type; }

# Note that this returns ONLY recognized protocols!
sub pathname_protocol {
  my ($pathname) = @_;
  return unless defined $pathname;
  return ($pathname =~ /^($PROTOCOL_RE|$LITERAL_RE)/ ? $1 : 'file'); }

#======================================================================
sub pathname_concat {
  my ($dir, $file) = @_;
  return $file unless $dir;
  return $dir if !defined $file || ($file eq '.');
  return pathname_canonical(File::Spec->catpath('', $dir || '', $file)); }

#======================================================================
# Is $pathname an absolute pathname ?
# pathname_is_absolute($pathname) => (0|1)
sub pathname_is_absolute {
  my ($pathname) = @_;
  return $pathname && File::Spec->file_name_is_absolute(pathname_canonical($pathname)); }

sub pathname_is_url {
  my ($pathname) = @_;
  return $pathname && $pathname =~ /^($PROTOCOL_RE)/ && $1; }    # Other protocols?

sub pathname_is_literaldata {
  my ($pathname) = @_;
  if ($pathname =~ /^($LITERAL_RE)/) { return $1; } else { return; } }

# Check whether $pathname is contained in (ie. underneath) $base
# Returns the relative pathname if it is underneath; undef otherwise.
sub pathname_is_contained {
  my ($pathname, $base) = @_;
  # after assuring that both paths are absolute,
  # get $pathname relative to $base
  my $rel = pathname_canonical(pathname_relative(pathname_absolute($pathname),
      pathname_absolute($base)));
  # If the relative pathname starts with "../" that it apparently is NOT underneath base!
  return ($rel =~ m|^\.\.(?:/\|\Q$SEP\E)| ? undef : $rel); }

# Check whether a pathname is a raw TeX source or definition
sub pathname_is_raw {
  my ($pathname) = @_;
  return ($pathname =~ /\.(tex|pool|sty|cls|clo|cnf|cfg|ldf|def|dfu)$/); }

# Check whether a pathname is reloadable as a TeX definition
sub pathname_is_reloadable {
  my ($pathname) = @_;
  my ($dir, $name, $type) = pathname_split($pathname);
  # babel.sty exception:
  # we know the same .ldf file may be reloaded with a different option,
  # to load an adjacently defined language, so allow that.
  return $type eq 'ldf'; }

# pathname_relative($pathname,$base) => $relativepathname
# If $pathname is an absolute, non-URL pathname,
# return the pathname relative to $base,
# else just return its canonical form.
# Actually, if it's a url and $base is also url, to SAME host! & protocol...
# we _could_ make relative...
sub pathname_relative {
  my ($pathname, $base) = @_;
  return unless defined $pathname;
  $pathname = pathname_canonical($pathname);
  return ($base && pathname_is_absolute($pathname) && !pathname_is_url($pathname)
    ? File::Spec->abs2rel($pathname, pathname_canonical($base))
    : $pathname); }

sub pathname_absolute {
  my ($pathname, $base) = @_;
  return unless defined $pathname;
  $pathname = pathname_canonical($pathname);
  return (!pathname_is_absolute($pathname) && !pathname_is_url($pathname)
    ? File::Spec->rel2abs($pathname, ($base ? pathname_canonical($base) : pathname_cwd()))
    : $pathname); }

sub pathname_to_url {
  my ($pathname) = @_;
  return unless defined $pathname;
  my $relative_pathname = pathname_relative($pathname);
  if ($SEP ne '/') {
    $relative_pathname = join('/', split(/\Q$SEP\E/, $relative_pathname)); }
  return $relative_pathname; }

#======================================================================
# Actual file system operations.
sub pathname_timestamp {
  my ($pathname) = @_;
  return -f $pathname ? (stat($pathname))[9] : 0; }

our $CWD = undef;
# DO NOT use pathname_cwd, unless you also use pathname_chdir to change dirs!!!
sub pathname_cwd {
  if (!defined $CWD) {
    if (my $cwd = cwd()) {
      $CWD = pathname_canonical($cwd); }
    else {
      # Fatal not imported
      die "INTERNAL: Could not determine current working directory (cwd)"
        . "Perhaps a problem with Perl's locale settings?"; } }
  return $CWD; }

sub pathname_chdir {
  my ($directory) = @_;
  chdir($directory);
  pathname_cwd();    # RE-cache $CWD!
  return; }

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

# This is presumably daemon safe...
my @INSTALLDIRS = grep { (-f "$_.pm") && (-d $_) }
  map { pathname_canonical($_ . $SEP . 'LaTeXML') } @INC;    # [CONSTANT]

sub pathname_installation {
  return $INSTALLDIRS[0]; }

sub pathname_find {
  my ($pathname, %options) = @_;
  return unless $pathname;
  $options{findfirst} = 1;
  my @paths = candidate_pathnames($pathname, %options);
  return $paths[0]; }

sub pathname_findall {
  my ($pathname, %options) = @_;
  return unless $pathname;
  $options{findfirst} = undef;
  return candidate_pathnames($pathname, %options); }

# It's presumably cheap to concatinate all the pathnames,
# relative to the cost of testing for files,
# and this simplifies overall.
sub candidate_pathnames {
  my ($pathname, %options) = @_;
  my @dirs = ();
  $pathname = pathname_canonical($pathname) unless $pathname eq '*';
  my ($pathdir, $name, $type) = ($pathname eq '*' ? (undef, '*', undef) : pathname_split($pathname));
  $name .= '.' . $type if (defined $type) && ($type ne '');
  # generate the set of search paths we'll use.
  if (pathname_is_absolute($pathname)) {
    push(@dirs, $pathdir); }
  else {
    my $cwd = pathname_cwd();
    if ($options{paths}) {
      foreach my $p (@{ $options{paths} }) {
        # Complete the search paths by prepending current dir to relative paths,
        my $pp = pathname_concat((pathname_is_absolute($p) ? pathname_canonical($p) : pathname_concat($cwd, $p)),
          $pathdir);
        push(@dirs, $pp) unless grep { $pp eq $_ } @dirs; } }    # but only include each dir ONCE
    push(@dirs, pathname_concat($cwd, $pathdir)) unless @dirs;    # At least have the current directory!
        # And, if installation dir specified, append it.
    if (my $subdir = $options{installation_subdir}) {
      push(@dirs, map { pathname_concat($_, $subdir) } @INSTALLDIRS); } }

  # extract the desired extensions.
  my @exts = ();
  if ($options{type}) {
    push(@exts, '.' . $options{type}); }
  if ($options{types}) {
    foreach my $ext (@{ $options{types} }) {
      if    ($ext eq '') { push(@exts, ''); }
      elsif ($ext eq '*') {
        push(@exts, '.*', ''); }
      else {
        if ($pathname =~ /\.\Q$ext\E$/i) {
          push(@exts, ''); }
        push(@exts, '.' . $ext); } } }
  push(@exts, '') unless @exts;

  my @paths        = ();
  my @nocase_paths = ();
  # Precompute the intended regexes to apply
  my @regexes = ();
  foreach my $ext (@exts) {
    if ($name eq '*') {    # Unfortunately, we've got to test the file system NOW...
      if ($ext eq '.*') {    # everything, except hidden files
        push(@regexes, [qr/^[^.]/, qr/^[^.]/]); }
      else {
        push(@regexes, [qr/\Q$ext\E$/i,
            qr/\Q$ext\E$/]); } }
    elsif ($ext eq '.*') {
      push(@regexes, [qr/^\Q$name\E\.\w+$/i,
          qr/^\Q$name\E\.\w+$/]); }
    else {
      push(@regexes, [qr/^\Q$name\E\Q$ext\E$/i,
          qr/^\Q$name\E\Q$ext\E$/]); } }
  # Now, combine; precedence to leading directories.
  foreach my $dir (@dirs) {
    opendir(DIR, $dir) or next;
    my @dir_files = readdir(DIR);
    closedir(DIR);
    for my $local_file (@dir_files) {
      for my $regex_pair (@regexes) {
        my ($i_regex, $regex) = @$regex_pair;
        if ($local_file =~ m/$i_regex/) {
          my $full_file = pathname_concat($dir, $local_file);
          push(@nocase_paths, $full_file);
          if ($local_file =~ m/$regex/) {
            # if we are only interested in the first match, return it:
            return ($full_file) if $options{findfirst};
            push(@paths, $full_file); } } } } }
  # Fallback: if no strict matches were found, return any existing case-insensitive matches
  # Defer the -f check until we are sure we need it, to keep the usual cases fast.
  return @paths ? @paths : @nocase_paths; }

#======================================================================
our $kpsewhich      = which($ENV{LATEXML_KPSEWHICH} || 'kpsewhich');
our $kpse_cache     = undef;
our $kpse_toolchain = "";

sub pathname_kpsewhich {
  my (@candidates) = @_;
  return             unless $kpsewhich && @candidates;
  build_kpse_cache() unless $kpse_cache;
  foreach my $file (@candidates) {
    if (my $result = $$kpse_cache{$file}) {
      return $result; } }
  # If we've failed to read the cache, try directly calling kpsewhich
  # For multiple calls, this is slower in general. But MiKTeX, eg., doesn't use texmf ls-R files!
  if ($kpse_toolchain) {
    push(@candidates, $kpse_toolchain); }
  if ($kpsewhich && open(my $resfh, '-|', $kpsewhich, @candidates)) {
    my $result = <$resfh>;     # we only need the first line
    { local $/; <$resfh>; }    # discard the rest of the output
    close($resfh);             # ignore exit status (only one of @candidates exists, usually)
    if ($result) {
      chomp $result;
      return $result; } }
  return; }

sub build_kpse_cache {
  $kpse_cache = {};    # At least we've tried.
  return unless $kpsewhich;
  # This finds ALL the directories looked for for any purposes, including docs, fonts, etc
  $kpse_toolchain = "--miktex-admin" if ($ENV{"LATEXML_KPSEWHICH_MIKTEX_ADMIN"});
  my $texmf = `"$kpsewhich" --expand-var \'\\\$TEXMF\' $kpse_toolchain`; chomp($texmf);
  # These are directories which contain the tex related files we're interested in.
  # (but they're typically below where the ls-R indexes are!)
  my $texpaths = `"$kpsewhich" --show-path tex $kpse_toolchain`; chomp($texpaths);
  my @filters  = ();
  foreach my $path (split(/$KPATHSEP/, $texpaths)) {
    $path =~ s/^!!//; $path =~ s|//+$|/|;
    push(@filters, $path) if -d $path; }
  $texmf =~ s/^["']//; $texmf =~ s/["']$//;
  $texmf =~ s/^\s*\\\{(.+?)}\s*$/$1/s;
  $texmf =~ s/\{\}//g;
  my @dirs = split(/,/, $texmf);
  foreach my $dir (@dirs) {
    $dir =~ s/^!!//;
    # Presumably if no ls-R, we can ignore the directory?
    if (-f "$dir/ls-R") {
      my $LSR;
      my $subdir;
      my $skip = 0;    # whether to skip entries in the current subdirectory.
      open($LSR, '<', "$dir/ls-R") or die "Cannot read $dir/ls-R: $!";
      while (<$LSR>) {
        chop;
        next unless $_;
        if    (/^%/) { }
        elsif (/^(.*?):$/) {    # Move to a new subdirectory
          $subdir = $1;
          $subdir =~ s|^\./||;                             # remove prefix
          my $d = $dir . '/' . $subdir;                    # Hopefully OS safe, for comparison?
          $skip = !grep { $d =~ /^\Q$_\E/ } @filters; }    # check if one of the TeX paths
        elsif (!$skip) {
          # Is it safe to use '/' here?
          my $sep = '/';
          $$kpse_cache{$_} = join($sep, $dir, $subdir, $_); } }
      close($LSR); } }
  return; }

#======================================================================
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Util::Pathname>  - portable pathname and file-system utilities

=head1 DESCRIPTION

This module combines the functionality L<File::Spec> and L<File::Basename> to
give a consistent set of filename utilities for LaTeXML.
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

=item C<< $boole = pathname_is_literaldata($path); >>

Returns whether the pathname C<$path> is actually a blob of literal data,
with a leading "literal:" protocol.

=item C<< $boole = pathname_is_raw($path); >>

Check if pathname indicates a raw TeX source or definition file.

=item C<< $boole = pathname_is_reloadable($path); >>

Check for pathname exceptions where the same TeX definition file
can be meaningfully reloaded. For example, babel.sty ".ldf" files

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

=item C<< $relative_url = pathname_to_url($path); >>

Creates a local, relative URL for a given pathname,
also ensuring proper path separators on non-Unix systems.

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

=item C<< $path = pathname_kpsewhich(@names); >>

Attempt to find a candidate name via the external C<kpsewhich>
capability of the system's TeX toolchain. If C<kpsewhich> is
not available, or the file is not found, returns a
Perl undefined value.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
