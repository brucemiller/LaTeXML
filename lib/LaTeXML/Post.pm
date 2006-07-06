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
  my($class,%options)=@_;
  bless { options=>{%options} },$class; }

sub process {
  my($self,$doc,%options)=@_;
  # Read in the XM
  if(! ref $doc){
    $doc .= ".xml" unless $doc=~/\.xml$/;
    $options{source} = $doc unless $options{source};
    my $XMLParser = XML::LibXML->new();
    $XMLParser->keep_blanks(0);	# This allows formatting the output.
    $doc = $XMLParser->parse_file($doc); }
  %options = $self->completeOptions(%options);

  if($options{destinationDirectory} && !-d $options{destinationDirectory}){
    (mkdir $options{destinationDirectory} 
     or die "Couldn't create destination dir \"$options{destinationDirectory}\": $!"); }

  foreach my $processor (@{$options{processors}}){
    if(!ref $processor){
      my $module = $processor.".pm";
      $module =~ s|::|/|g;
      require $module;
      $processor = $processor->new(%options); }
    $doc = $processor->process($doc,%options); }
  if($options{destination}){
    $doc->toFile($options{destination},1) || die "Couldn't write $options{destination}: $!"; }
  $doc; }

sub completeOptions {
  my($self,%options)=@_;
  if($options{destination} && !$options{format}){
    $options{format} = 'html' if $options{destination} =~ /\.html$/;
    $options{format} = 'xhtml' if $options{destination} =~ /\.xhtml$/; }
  if($options{processors}){}
  elsif($options{format}){
    my $format = $options{format};
    if($format eq 'html'){
      $options{processors} = [qw(LaTeXML::Post::MathImages
				 LaTeXML::Post::Graphics
				 LaTeXML::Post::HTMLTable
				 LaTeXML::Post::XRef
				 LaTeXML::Post::XSLT)]; }
    elsif($format eq 'xhtml'){
      $options{processors} = [qw(LaTeXML::Post::MathParser
				 LaTeXML::Post::PresentationMathML
				 LaTeXML::Post::Graphics
				 LaTeXML::Post::HTMLTable
				 LaTeXML::Post::XRef
				 LaTeXML::Post::XSLT)]; }
    if(!$options{stylesheet}){
      foreach my $dir (@INC){
	my $xsl = "$dir/LaTeXML/dtd/LaTeXML.xsl";
	if(-f $xsl){ $options{stylesheet}=$xsl; last; }}}
    die "No Stylesheet specified or found!" unless $options{stylesheet};
  }
  else {			# Else do sensible minimal XML stuff?
      $options{processors} = [qw(LaTeXML::Post::MathParser
				 LaTeXML::Post::PresentationMathML)]; }
  # Get complete source, destination and corresponding directories.
  if($options{source} && !$options{sourceDirectory}){
    my($vol,$dir,$name)=File::Spec->splitpath($options{source});
    $options{sourceDirectory} = $dir || '.'; }
  if($options{destination} && !$options{destinationDirectory}){
    my($vol,$dir,$name)=File::Spec->splitpath($options{destination});
    $options{destinationDirectory} = $dir; }
  $options{sourceDirectory} = '.' unless $options{sourceDirectory};
  $options{destinationDirectory} = '.' unless $options{destinationDirectory};
  %options; }

#**********************************************************************
1;

__END__

=head1 LaTeXML::Post

LaTeXML::Post is the driver for various postprocessing operations.
It has a complicated set of options that I'll document shortly.

=cut
#**********************************************************************

