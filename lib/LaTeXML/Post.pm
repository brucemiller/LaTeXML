# /=====================================================================\ #
# |  LaTeXML::Post                                                      | #
# | PostProcessing driver                                               | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post;
use strict;
use XML::LibXML;
use File::Spec;

#**********************************************************************
sub new {
  my($class)=@_;
  bless { },$class; }

sub process {
  my($self,$doc,%options)=@_;
  # Read in the XML, unless it already is a Doc.
  if(! ref $doc){
    $doc .= ".xml" unless $doc=~/\.xml$/;
    $options{source} = $doc unless $options{source};
    my $XMLParser = XML::LibXML->new();
    $XMLParser->keep_blanks(0);	# This allows formatting the output.
    $doc = $XMLParser->parse_file($doc); }
  %options = $self->completeOptions(%options);

  $options{namespaceURI} = "http://dlmf.nist.gov/LaTeXML";

  if($options{destinationDirectory} && !-d $options{destinationDirectory}){
    (mkdir $options{destinationDirectory} 
     or die "Couldn't create destination dir \"$options{destinationDirectory}\": $!"); }

  foreach my $processor (@{$options{processors}}){
    if(!ref $processor){
      my $module = $processor.".pm";
      $module =~ s|::|/|g;
      require $module;
      $processor = $processor->new(%options); }
    else {
      $processor->init(%options); }

    $doc = $processor->process($doc); 
    $processor->closeCache;		# If opened.
  }


  # Should this be a `writer' filter?
  if($options{destination} || $options{toString}){
    $doc = (($options{format} || '') eq 'html' ? $doc->toStringHTML : $doc->toString(1)); }

  if($options{destination}){
    open(OUT,">:utf8",$options{destination}) || return die("Couldn't write $options{destination}: $!");
    print OUT $doc;
    close(OUT); }
  $doc; }

sub completeOptions {
  my($self,%options)=@_;
  # Guess the output format (html|xhtml|xml), if not given
  if(!$options{format}){
    if($options{destination}){
      $options{format} = 'html' if $options{destination} =~ /\.html$/;
      $options{format} = 'xhtml' if $options{destination} =~ /\.xhtml$/; }
    else {
      $options{format} = 'xml'; }}

  # Determine the set of post processors to apply, based on format.
  if($options{processors}){	# Explicitly requested list.
  }
  elsif($options{format} eq 'html'){
    $options{processors} = [qw(LaTeXML::Post::MathImages
			       LaTeXML::Post::Graphics
			       LaTeXML::Post::HTMLTable
			       LaTeXML::Post::XSLT)];  }
  elsif($options{format} eq 'xhtml'){
    $options{processors} = [qw(LaTeXML::Post::MathParser
			       LaTeXML::Post::PresentationMathML
			       LaTeXML::Post::Graphics
			       LaTeXML::Post::HTMLTable
			       LaTeXML::Post::XSLT)];  }
  else {			# Else do sensible minimal XML stuff?
    $options{processors} = [qw(LaTeXML::Post::MathParser
			       LaTeXML::Post::PresentationMathML)];
    push(@{$options{processors}},'LaTeXML::Post::XSLT') if $options{stylesheet}; }

  # Get complete source, destination and corresponding directories.
  if($options{source} && !$options{sourceDirectory}){
    my($vol,$dir,$name)=File::Spec->splitpath($options{source});
    $options{sourceName}      = $name || '';
    $options{sourceDirectory} = $dir || '.'; }

  if($options{destination} && !$options{destinationDirectory}){
    my($vol,$dir,$name)=File::Spec->splitpath($options{destination});
    $options{destinationDirectory} = $dir; }

  # Is this what we want?
  $options{sourceDirectory} = '.' unless $options{sourceDirectory};
  $options{destinationDirectory} = '.' unless $options{destinationDirectory};
  %options; }

#**********************************************************************
package LaTeXML::Post::Processor;
use strict;
use LaTeXML::Util::Pathname;
use DB_File;

sub new {
  my($class,%options)=@_;
  my $self = bless {%options}, $class;
  $self->init(%options);
  $self; }

sub init {
  my($self,%options)=@_;
  $$self{options}              = {%options};
  $$self{verbosity}            = $options{verbosity} || 0;
  $$self{format}               = $options{format} || 'xml';
  $$self{source}               = $options{source};
  $$self{sourceName}           = $options{sourceName};
  $$self{sourceDirectory}      = $options{sourceDirectory};
  $$self{destination}          = $options{destination};
  $$self{destinationDirectory} = $options{destinationDirectory};
  $$self{searchPaths}          = $options{searchPaths} || [$$self{sourceDirectory}];
}

sub getSource               { $_[0]->{source}; }
sub getSourceName           { $_[0]->{sourceName}; }
sub getSourceDirectory      { $_[0]->{sourceDirectory}; }
sub getDestination          { $_[0]->{destination}; }
sub getDestinationDirectory { $_[0]->{destinationDirectory}; }
sub getSearchPaths          { $_[0]->{searchPaths}; }
sub getNamespace            { $_[0]->{namespace} || "http://dlmf.nist.gov/LaTeXML"; }

sub getOption { $_[0]->{options}->{$_[1]}; }

#======================================================================
sub Error {
  my($self,$msg)=@_;
  die "".(ref $self)." Error: $msg"; }

sub Warn {
  my($self,$msg)=@_;
  warn "".(ref $self)." Warning: $msg"; }

sub Progress {
  my($self,$msg)=@_;
  print STDERR "".(ref $self).": $msg\n" if $$self{verbosity}>0; }

sub ProgressDetailed {
  my($self,$msg)=@_;
  print STDERR "".(ref $self).": $msg\n" if $$self{verbosity}>1; }

#======================================================================
# I/O support
sub addSearchPath {
  my($self,$path)=@_;
  $path = pathname_absolute($path,$$self{sourceDirectory})
    unless pathname_is_absolute($path);
  push(@{$$self{searchPaths}}, $path); }

# Find a file in, or relative to, the source directory or any additional search paths.
sub findFile {
  my($self,$name,$types)=@_;
  pathname_find($name,paths=>$$self{searchPaths},types=>$types); }

# Copy a source file, presumably relative to the source document's directory,
# to a corresponding sub-directory in the destination directory.
# Return the path to the copy, relative to the destination.
sub copyFile {
  my($self,$source)=@_;
  my ($reldir,$name,$type) = pathname_split(pathname_relative($source,$$self{sourceDirectory}));
  my $destdir = pathname_concat($$self{destinationDirectory},$reldir);
  pathname_mkdir($destdir) 
    or return $self->Error("Could not create relative directory $destdir: $!");
  my $dest = pathname_make(dir=>$destdir,name=>$name,type=>$type);
  pathname_copy($source, $dest) or warn("Couldn't copy $source to $dest: $!");
  pathname_make(dir=>$reldir,name=>$name,type=>$type); }

#======================================================================
# Cache support: storage of data from previous run.
# ?

sub cacheLookup {
  my($self,$key)=@_;
  $self->openCache;
  my $skey = (ref $self).":".$key;
  $$self{cache}{$skey}; }

sub cacheStore {
  my($self,$key,$value)=@_;
  $self->openCache;
  my $skey = (ref $self).":".$key;
  $$self{cache}{$skey} = $value; }

sub openCache {
  my($self)=@_;
  if(!$$self{cache}){
    $$self{cache}={};
    my $dbfile = pathname_make(dir=>$self->getDestinationDirectory, name=>'LaTeXML', type=>'cache');
    tie %{$$self{cache}}, 'DB_File', $dbfile,  O_RDWR|O_CREAT
      or return $self->Error("Couldn't create DB cache for ".$self->getSource.": $!");
  }}

sub closeCache {
  my($self)=@_;
  untie %{$$self{cache}} if $$self{cache}; }

#**********************************************************************
1;

__END__

=head1 LaTeXML::Post

LaTeXML::Post is the driver for various postprocessing operations.
It has a complicated set of options that I'll document shortly.

=cut
#**********************************************************************

