# -*- mode: Perl -*-
# /=====================================================================\ #
# |  make file for latexml & lxRDFa sty, sty.ltxml, and documentation   | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Tim Prescott <teepeemm@gmail.com>                           #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
use strict;
use warnings;
use File::Basename;
use Pod::Simple;
use Pod::Text;

my $sourceDir = dirname(__FILE__);        # [CONSTANT]
my $target    = $ARGV[0];                 # [CONSTANT]
my @basenames = ('latexml', 'lxRDFa');    # [CONSTANT]

my @targets;

if ($target) {
  push @targets, $target; }
else {
  # assume running in this directory
  foreach my $basename (@basenames) {
    push @targets, "$basename.sty";
    push @targets, "../Package/$basename.sty.ltxml"; } }

# this is surpassed by
# LaTeXML//texmf// latexml.3 & lxRDFa.3 (made by make)
# and
# doc/manual/pods/ package-latexml.tex & package-lxRDFa.tex (made by genpods)
# so we probably don't need this
sub writetxtfile {
  my ($source, $target) = @_;
  my $parserTeX = Pod::Text->new();
  $parserTeX->parse_from_file($source, $target); }

{

  package PodSty;
  use parent qw/Pod::Text/;
  sub item         { }
  sub cmd_para     { }
  sub cmd_verbatim { }
  sub heading      { } }

sub writestyfile {
  my ($source, $target) = @_;
  my $parserSty = PodSty->new(width => 255);    # don't wrap lines
  $parserSty->accept_targets(qw/sty/);
  $parserSty->parse_from_file($source, $target); }

# the ltxml file is just the original pm, without any of the POD
# so we echo code lines, and nothing else
sub writeltxmlfile {
  my ($source, $target) = @_;
  my $nocomments = Pod::Simple->new();
  $nocomments->code_handler(\&echo_line);
  $nocomments->parse_from_file($source, $target); }

sub echo_line {
  my ($line, $number, $parser) = @_;
  print { $parser->{output_fh} } "$line\n"; }

sub make {
  my ($target) = @_;
  my ($targetName, $targetDir, $targetSuffix) = fileparse($target, qr/\.sty(\.ltxml)?/);
  my $source = "$sourceDir/$targetName.pm";
  $targetSuffix =~ s/^\.//;
  $targetSuffix = 'ltxml' if $targetSuffix eq 'sty.ltxml';
  # this invokes &write${targetSuffix}file($source,$target);
  *main::->{ 'write' . $targetSuffix . 'file' }->($source, $target); }

make($_) foreach (@targets);
