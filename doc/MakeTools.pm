package MakeTools;
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Some handy tools for building pages, pdf, etc.
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
use strict;
use warnings;
use LaTeXML::Util::Pathname;
use FindBin;
use base qw(Exporter);
our @EXPORT = (qw(&setVerbosity &heading &subheading &message
    &copy &pdflatex &latexml
    &slurpfile &saveData
    &getReleaseInfo));

our $DOCDIR     = $FindBin::RealBin;
our $LATEXMLDIR = "$DOCDIR/..";        # Assumed under top-level LaTeXML

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Noise.

our $VERBOSITY = 0;

sub setVerbosity {
  my ($v) = @_;
  $VERBOSITY = $v;
  return; }

sub message {
  my ($message) = @_;
  print $message, "\n" if $VERBOSITY > -1;
  return; }

sub heading {
  my ($message) = @_;
  print "\n" . ("=" x 50) . "\n" . $message, "\n" if $VERBOSITY > -1;
  return; }

sub subheading {
  my ($message) = @_;
  print "" . ("-" x 50) . "\n" . $message, "\n" if $VERBOSITY > -1;
  return; }

#======================================================================
# Copy, if needed.
sub copy {
  my ($source, $destination) = @_;
  if ((!-f $destination) || (pathname_timestamp($source) > pathname_timestamp($destination))) {
    message("Copying $source to $destination");
    pathname_copy($source, $destination)
      or die "Failed to copy $source to $destination: $!"; }
  return; }

# Run latexml and latexmlpost, if needed
# Options are:
#    force   : do it even if it doesn't seem needed
#    options : list of options to pass to latexml
#    postoptions : list of options to pass to latexmlpost
sub latexml {
  my ($source, $destination, %options) = @_;
  my $timestamp = pathname_timestamp($source);
  foreach my $dep (@{ $options{dependencies} }) {
    my $ts = pathname_timestamp($dep);
    $timestamp = $ts if $ts > $timestamp; }
  my ($srcdir, $name, $ignore) = pathname_split($source);
  my $xmlfile = pathname_make(dir => $srcdir, name => $name, type => 'xml');

  # If the resulting html is out-of-date...
  if ($options{force}
    || (!-f $destination)
    || ($timestamp > pathname_timestamp($destination))) {
    # Does latexml need to be run to (re)generate the xml?
    if ($options{force}
      || (!-f $xmlfile)
      || ($timestamp > pathname_timestamp($xmlfile))) {
      subheading("Running latexml on $source");
      System("latexml",
        "--dest=$xmlfile",
        "--path=$DOCDIR/sty",
        ($options{options} ? @{ $options{options} } : ()),
        (map { "--verbose" } 1 .. $VERBOSITY),
        $source) == 0
        or die "Failed to convert $source to $xmlfile"; }
    # Does latexmlpost need to be run to (re)generate the html?
    if ($options{force}
      || (!-f $destination)
      || (pathname_timestamp($xmlfile) > pathname_timestamp($destination))) {
      subheading("Running latexmlpost to $destination");
      System("latexmlpost",
        "--dest=$destination",
        ($options{postoptions} ? @{ $options{postoptions} } : ()),
        (map { "--verbose" } 1 .. $VERBOSITY),
        $xmlfile) == 0
        or die "Failed to convert $xmlfile to $destination"; } }
  return; }

#======================================================================
our $MAXPASS = 3;

# Run pdflatex on $source
# Options are
#    force   : do it even if it doesn't seem needed
#    indexoptions : options to pass to makeindex
#          Must be provided to run makeindex, but can be empty (ie. []).
#    bibtexoptions : options to pass to bibtex
#          Must be provided to run bibtex, but can be empty (ie. []).
sub pdflatex {
  my ($source, %options) = @_;
  my $timestamp = pathname_timestamp($source);
  foreach my $dep (@{ $options{dependencies} }) {
    my $ts = pathname_timestamp($dep);
    $timestamp = $ts if $ts > $timestamp; }
  my ($srcdir, $name, $ignore) = pathname_split($source);
  my $pdffile = pathname_make(dir => $srcdir, name => $name, type => 'pdf');
  if ($options{force}
    || (!-f $pdffile)
    || ($timestamp > pathname_timestamp($pdffile))) {
    my $cwd = pathname_cwd();
    pathname_chdir($srcdir);
    my ($pass, $changed, $error) = (0, 0, 0);
    do {
      $pass++; $changed = 0;
      subheading("Running pdflatex for $name (pass $pass)");
      $ENV{TEXINPUTS} = "$DOCDIR/sty::";
      monitor_command("pdflatex $name",
        qr{! Undefined control sequence.} => sub { $error = 1; },
        qr{<to be read again>}            => sub { $error = 1; },
        qr{LaTeX Error}                   => sub { $error = 1; },
        qr{Warning: (Label|Citation)\(s\) may have changed.}
          => sub { $changed = 1; },
        qr{Warning: (Reference|Citation)\s+\`([^\']*)\' on page \d* undefined on }
          => sub { $changed = 1; },
        qr{Warning: (Label|Citation)\s*\`([^\']*)\' multiply defined}
          => sub { $changed = 1; },
      );
      die "pdflatex had errors on $name" if $error;
      if ($options{indexoptions}) {
        message("Running makeindex on $name");
        System("makeindex", $name, @{ $options{indexoptions} }) == 0
          or die "Failed to run makeindex for $name";
        $changed = 1 if $pass < 2; }
      if ($options{bibtexoptions}) {
        message("Running bibtex on $name");
        System("bibtex", $name, @{ $options{bibtexoptions} }) == 0
          or die "Failed to run bibtex for $name";
        $changed = 1 if $pass < 2; }
    } while ($pass <= $MAXPASS) && $changed;
    pathname_chdir($cwd); }
  return; }

sub monitor_command {
  my ($command, %watches) = @_;
  # Now, run the command, watching for certain kinds of messages
  my $MSG;
  open($MSG, "$command 2>&1 |") or die "Cannot execute $command: $!\n";
  while (<$MSG>) {
    foreach my $pattern (keys %watches) {
      &{ $watches{$pattern} } if /$pattern/; }
    print "$_"; }
  close($MSG);
  return; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
sub slurpfile {
  my ($datafile) = @_;
  my $FH;
  open($FH, '<', $datafile) or die "Couldn't read file $datafile: $!";
  local $/ = undef;
  my $data = <$FH>;
  close($FH);
  return $data; }

# Save $data to $datafile if it is different from what's already there.
sub saveData {
  my ($datafile, $data) = @_;
  if ((!-f $datafile) || ($data ne slurpfile($datafile))) {
    my $FH;
    message("Writing datafile $datafile");
    open($FH, '>', $datafile) or die "Couldn't write datafile: $!";
    print $FH $data;
    close($FH); }
  return; }

sub System {
  my ($command, @args) = @_;
  print "\$  " . join(' ', $command, @args) . "\n" if $VERBOSITY;
  return system($command, @args); }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
sub getReleaseInfo {
  my ($releasedir) = @_;
  my $macros = '';
  # Get current executable's version
  my $version;
  { use LaTeXML;
    $macros .= "\\def\\CurrentVersion{" . sanitize($LaTeXML::VERSION) . "}\n"; }
  # Scan the releases directory (if any) for all released versions.
  if ((!defined $releasedir) || !(-d "$releasedir")) {    # If  a release directory available.
    warn "No archived releases found in " . ($releasedir || '<none-given>');
    $macros .= "\\let\\CurrentRelease\\CurrentVersion\n";
    $macros .= "\\let\\CurrentDownload\\CurrentVersion\n";
    $macros .= "\\def\\AllReleases{}\n"; }
  else {
    opendir(REL, "$releasedir") or die "Couldn't read directory $releasedir: $!";
    my @files = readdir(REL);
    closedir(REL);
    my %tarballs = ();
    foreach my $file (@files) {
      if ($file =~ /^LaTeXML-(.*?)\.tar\.gz$/) {
        $tarballs{$1} = "\\href{releases/$file}{" . sanitize($1) . "\\nobreakspace(tar.gz)}"; } }
    my @versions = reverse sort keys %tarballs;
    $macros .= "\\def\\CurrentRelease{$versions[0]}\n";
    $macros .= "\\def\\CurrentDownload{" . $tarballs{ $versions[0] } . "}\n";
    $macros .= "\\def\\AllReleases{" . join(";\n", map { $tarballs{$_}; } @versions) . "}\n";
  }

  # Collect all bindings for classes and packages.
  if (!-r "$LATEXMLDIR/MANIFEST") {
    warn "No MANIFEST found";
    $macros .= "\\def\\CurrentClasses{}\n";
    $macros .= "\\def\\CurrentPackages{}\n"; }
  else {
    my %bindings = ();
    my $MF;
    open($MF, '<', "$LATEXMLDIR/MANIFEST") or die "Couldn't read MANIFEST: $!";
    while (<$MF>) {
      if (m@^\s*lib/LaTeXML/Package/(.+?)\.(cls|sty)\.ltxml\s*$@) {
        $bindings{$2}{ sanitize($1) } = 1; } }
    close($MF);
    $macros .= "\\def\\CurrentClasses{" . join(', ', sort keys %{ $bindings{cls} }) . "}\n";
    $macros .= "\\def\\CurrentPackages{" . join(', ', sort keys %{ $bindings{sty} }) . "}\n"; }

  saveData("$DOCDIR/sty/latexmlreleases.tex", $macros);
  return; }

sub sanitize {
  my ($string) = @_;
  $string =~ s/\\/\\\\/g;
  $string =~ s/_/\\_/g;
  return $string; }
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
1;
