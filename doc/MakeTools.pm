package MakeTools;
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Some handy tools for building pages, pdf, etc.
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
use strict;
use LaTeXML::Util::Pathname;
use base qw(Exporter);
our @EXPORT = (qw(&setVerbosity &heading &subheading &message
		  &copy &pdflatex &latexml
		  &slurpfile &saveData));

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Noise.

our $VERBOSITY=0;

sub setVerbosity { $VERBOSITY = $_[0]; }

sub message {
  my($message)=@_;
  print $message,"\n" unless $VERBOSITY < 0;
}

sub heading {
  my($message)=@_;
  print "".("="x50)."\n".$message,"\n" unless $VERBOSITY < 0; }

sub subheading {
  my($message)=@_;
  print "".("-"x50)."\n".$message,"\n" unless $VERBOSITY < 0; }

#======================================================================
# Copy, if needed.
sub copy {
  my($source,$destination)=@_;
  if((!-f $destination) || (pathname_timestamp($source) > pathname_timestamp($destination))){
    message("Copying $source to $destination");
    pathname_copy($source, $destination)
      or die "Failed to copy $source to $destination: $!"; }}

# Run latexml and latexmlpost, if needed
# Options are:
#    force   : do it even if it doesn't seem needed
#    options : list of options to pass to latexml
#    postoptions : list of options to pass to latexmlpost
sub latexml {
  my($source,$destination,%options)=@_;
  my $timestamp = pathname_timestamp($source);
  foreach my $dep (@{$options{dependencies}}){
    my $ts = pathname_timestamp($dep);
    $timestamp = $ts if $ts > $timestamp; }
  my($srcdir,$name,$ignore)=pathname_split($source);
  my $xmlfile = pathname_make(dir=>$srcdir, name=>$name, type=>'xml');

  # If the resulting html is out-of-date...
  if($options{force}
     || (! -f $destination)
     || ($timestamp > pathname_timestamp($destination))){
    # Does latexml need to be run to (re)generate the xml?
    if($options{force}
       || (! -f $xmlfile)
       || ($timestamp > pathname_timestamp($xmlfile))){
      subheading("Running latexml on $source");
      system("latexml",
	     "--dest=$xmlfile",
	     ($options{options} ? @{$options{options}} : ()),
	     map("--verbose",1..$VERBOSITY),
	     $source) == 0
	or die "Failed to convert $source to $xmlfile"; }
    # Does latexmlpost need to be run to (re)generate the html?
    if($options{force}
       || (! -f $destination)
       || (pathname_timestamp($xmlfile) > pathname_timestamp($destination))){
      subheading("Running latexmlpost to $destination");
      system("latexmlpost",
	     "--dest=$destination",
	     ($options{postoptions} ? @{$options{postoptions}} : ()),
	     map("--verbose",1..$VERBOSITY),
	     $xmlfile)  == 0
	or die "Failed to convert $xmlfile to $destination"; }}
}

#======================================================================
our $MAXPASS=3;

# Run pdflatex on $source
# Options are
#    force   : do it even if it doesn't seem needed
#    indexoptions : options to pass to makeindex
#          Must be provided to run makeindex, but can be empty (ie. []).
#    bibtexoptions : options to pass to bibtex
#          Must be provided to run bibtex, but can be empty (ie. []).
sub pdflatex {
  my($source,%options)=@_;
  my $timestamp = pathname_timestamp($source);
  foreach my $dep (@{$options{dependencies}}){
    my $ts = pathname_timestamp($dep);
    $timestamp = $ts if $ts > $timestamp; }
  my($srcdir,$name,$ignore)=pathname_split($source);
  my $pdffile = pathname_make(dir=>$srcdir, name=>$name, type=>'pdf');
  if($options{force}
     || (! -f $pdffile)
     || ($timestamp > pathname_timestamp($pdffile))){
    my $cwd = pathname_cwd();
    chdir($srcdir);
    my($pass,$changed,$error)=(0,0,0);
    subheading("Generating pdf for $name");
    do {
      $pass++; $changed = 0;
      message("Running pdflatex on $name");
      monitor_command("pdflatex $name",
		      qr{! Undefined control sequence.} => sub { $error=1; },
		      qr{<to be read again>} => sub { $error=1; },
		      qr{LaTeX Error} => sub { $error=1; },
		      qr{Warning: (Label|Citation)\(s\) may have changed.}
		      =>sub{ $changed=1;},
		      qr{Warning: (Reference|Citation)\s+\`([^\']*)\' on page \d* undefined on }
		      =>sub{ $changed=1; },
		      qr{Warning: (Label|Citation)\s*\`([^\']*)\' multiply defined}
		      =>sub{ $changed=1; },
		 );
      die "pdflatex had errors on $name" if $error;
      if($options{indexoptions}){
	message("Running makeindex on $name");
	system("makeindex",$name, @{$options{indexoptions}}) == 0
	  or die "Failed to run makeindex for $name"; 
	$changed = 1 if $pass < 2; }
      if($options{bibtexoptions}){
	message("Running bibtex on $name");
	system("bibtex",$name, @{$options{bibtexoptions}}) == 0
	  or die "Failed to run bibtex for $name";
	$changed = 1 if $pass < 2; }
      } while ($pass <= $MAXPASS) && $changed;
    chdir($cwd);  }}

sub monitor_command {
  my($command,%watches)=@_;
  # Now, run the command, watching for certain kinds of messages
  open(MSG, "$command 2>&1 |") or die "Cannot execute $command: $!\n";
  while(<MSG>){
    foreach my $pattern (keys %watches){
      &{$watches{$pattern}} if /$pattern/; }
    print "$_"; }
  close(MSG); }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
sub slurpfile {
  my($datafile)=@_;
  open(OLD,$datafile) or die "Couldn't read file $datafile: $!";
  local $/=undef;
  my $data = <OLD>;
  close(OLD);
  $data; }

# Save $data to $datafile if it is different from what's already there.
sub saveData {
  my($datafile,$data)=@_;
  if((! -f $datafile) || ($data ne slurpfile($datafile))){
    message("Writing datafile $datafile");
    open(OUT,">$datafile") or die "Couldn't write datafile: $!";
    print OUT $data;
    close(OUT); }}

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
1;
