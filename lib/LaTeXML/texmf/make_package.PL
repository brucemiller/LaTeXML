# -*- mode: Perl -*-
# /=====================================================================\ #
# |  make file for latexml & lxRDFa sty and documentation               | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Tim Prescott <teepeemm@gmail.com>                           #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

# usage:
# From the LaTeXML root directory, running
# path/to/make_package.PL path/to/$basename.$ext
# will use lib/LaTeXML/Package/$basename.sty.ltxml to create
# path/to/$basename.$ext (this is how Makefile.PL uses this file)
# From this directory, running
# make_package.PL
# will create all possible $basename.$ext combinations in this directory
# This lets you generate the files without going through make

use strict;
use warnings;
use File::Basename;
use Pod::Html;
use Pod::Text;

my $target     = $ARGV[0];                 # [CONSTANT]
my @basenames  = ('latexml', 'lxRDFa');    # [CONSTANT]
my @extensions = ('sty',     'html');      # [CONSTANT]
my $sourceDir  = 'lib/LaTeXML/Package';

my @targets;

if ($target) {
  push @targets, $target; }
else {    # assume running in this directory
  $sourceDir = "../../../$sourceDir";
  foreach my $basename (@basenames) {
    foreach my $ext (@extensions) {
      push @targets, "$basename.$ext"; } } }

{

  package PodSty;
  use parent qw/Pod::Text/;
  sub item         { }
  sub cmd_para     { }
  sub cmd_verbatim { }
  sub heading      { } }

sub writestyfile {
  my ($source, $target) = @_;
  my $parserSty = PodSty->new(width => 1023);    # don't wrap lines
  $parserSty->accept_targets(qw/sty/);
  $parserSty->parse_from_file($source, $target); }

sub writehtmlfile {
  my ($source, $target) = @_;
  if ($ARGV[0]) {
    # pod2html creates pod2htmd.tmp in the directory in which it runs
    # this will hide that file in blib
    pod2html("--cachedir=blib", "--infile=$source", "--outfile=$target"); }
  else {
    pod2html("--infile=$source", "--outfile=$target"); } }

sub make {
  my ($target) = @_;
  my ($targetName, $targetDir, $targetSuffix) = fileparse($target, @extensions);
  # because @extensions doesn't have the ., it ends up in $targetName instead of
  # $targetSuffix (the default behavior)
  my $source = "$sourceDir/${targetName}sty.ltxml";
  # this invokes &write${targetSuffix}file($source,$target);
  *main::->{ 'write' . $targetSuffix . 'file' }->($source, $target); }

make($_) foreach (@targets);
