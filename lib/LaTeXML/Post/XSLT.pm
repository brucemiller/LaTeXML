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
use base qw(LaTeXML::Post::Processor);

our @SEARCH_SUBDIRS = qw(LaTeXML/dtd dtd .);

sub new {
  my($class,%options)=@_;
  my $stylesheet = $options{stylesheet};
  my $self = bless {%options},$class;
  $self->Error("No stylesheet specified!") unless $stylesheet;
  if(!ref $stylesheet){
    my $pathname = pathname_find($stylesheet,
				 types=>['xsl'],installation_subdir=>'dtd');
    $self->Error("No stylesheet \"$stylesheet\" found!")
      unless $pathname && -f $pathname;
    $stylesheet = XML::LibXML->new()->parse_file($pathname); }
  if(ref $stylesheet eq 'XML::LibXML::Document'){
    $stylesheet = XML::LibXSLT->new()->parse_stylesheet($stylesheet); }
  if(ref $stylesheet ne 'XML::LibXSLT::Stylesheet'){
    $self->Error("Stylesheet \"$stylesheet\" is not a usable stylesheet!"); }
  $$self{stylesheet} = $stylesheet;
  $self; }

sub process {
  my($self,$doc,%options)=@_;
  my $css = $self->getOption('CSS');
  $$self{stylesheet}->transform($doc, ($css ? (CSS=>"'$css'") :())); }

# ================================================================================
1;

