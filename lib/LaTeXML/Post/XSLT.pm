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
use XML::LibXML;
use XML::LibXSLT;
use base qw(LaTeXML::Post);

# Useful Options:
#    stylesheet : path to XSLT stylesheet.
#    css        : path to CSS stylesheet.
sub new {
  my($class,%options)=@_;
  my $self = $class->SUPER::new(%options);
  $$self{css} = $options{css};
  my $stylesheet = $options{stylesheet};
  $self->Error("No stylesheet specified!") unless $stylesheet;
  if(!ref $stylesheet){
    my $pathname = pathname_find($stylesheet,
				 types=>['xsl'],installation_subdir=>'dtd');
    $self->Error("No stylesheet \"$stylesheet\" found!")
      unless $pathname && -f $pathname;
    $stylesheet = XML::LibXML->new()->parse_file($pathname); }
  if(ref $stylesheet eq 'XML::LibXML::Document'){
    $stylesheet = XML::LibXSLT->new()->parse_stylesheet($stylesheet); }
  if((!ref $stylesheet) || !($stylesheet->can('transform'))){
    $self->Error("Stylesheet \"$stylesheet\" is not a usable stylesheet!"); }
  $$self{stylesheet}=$stylesheet;
  $self; }

sub process {
  my($self,$doc)=@_;
  my $css = $$self{css};
  $css = pathname_relative($css,$doc->getDestinationDirectory) if $css;
  # Copy the CSS file to the destination. if found & needed.
  $doc->new($$self{stylesheet}->transform($doc->getDocument,
					  ($css ? (CSS=>"'$css'") :()))); }

# ================================================================================
1;

