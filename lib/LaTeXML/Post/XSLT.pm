# /=====================================================================\ #
# |  LaTeXML::Post::XSLT                                                | #
# | Postprocessor for XSL Transform                                     | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post::XSLT;
use strict;
use LaTeXML::Util::Pathname;
use LaTeXML::Common::XML;
###use XML::LibXSLT;
use base qw(LaTeXML::Post);

# Useful Options:
#    stylesheet : path to XSLT stylesheet.
#    parameters : hash of parameters to pass to stylesheet.
#         Among which:
#         CSS   is a '|' separated list of paths
#         ICON  a favicon
sub new {
  my($class,%options)=@_;
  my $self = $class->SUPER::new(%options);
  my $stylesheet = $options{stylesheet};
  $self->Error(undef,"No stylesheet specified!") unless $stylesheet;
  if(!ref $stylesheet){
    my $pathname = pathname_find($stylesheet,
				 types=>['xsl'],installation_subdir=>'style');
    $self->Error(undef,"No stylesheet \"$stylesheet\" found!")
      unless $pathname && -f $pathname;
    $stylesheet = $pathname; }
  $stylesheet = LaTeXML::Common::XML::XSLT->new($stylesheet);
  if((!ref $stylesheet) || !($stylesheet->can('transform'))){
    $self->Error(undef,"Stylesheet \"$stylesheet\" is not a usable stylesheet!"); }
  $$self{stylesheet}=$stylesheet;
  my %params = ();
  %params = %{$options{parameters}} if $options{parameters};
  $$self{parameters}={%params};
  $self; }

sub process {
  my($self,$doc)=@_;
  # Set up the Stylesheet parameters; making pathname parameters relative to document
  my %params = %{$$self{parameters}};
  my $dir = $doc->getDestinationDirectory;
  if(my $css = $params{CSS})      { $params{CSS} = pathnameParameter($dir,@$css); }
  if(my $js = $params{JAVASCRIPT}){ $params{JAVASCRIPT} = pathnameParameter($dir,@$js); }
  if(my $icon = $params{ICON})    { $params{ICON} = pathnameParameter($dir,$icon); }
  $doc->new($$self{stylesheet}->transform($doc->getDocument,  %params)); }

sub pathnameParameter {
  my($dir,@paths)=@_;
  '"'.join('|',map((pathname_is_url($_) ? $_
		    : (pathname_is_absolute($_) ? pathname_relative($_,$dir) : $_)),@paths)) .'"'; }
# ================================================================================
1;

