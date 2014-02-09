# /=====================================================================\ #
# |  LaTeXML::Util::Radix                                               | #
# | PostProcessing driver                                               | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Util::Radix;
use strict;
use warnings;
use base qw(Exporter);
our @EXPORT = (qw( &radix_format
    &radix_alpha &radix_Alpha &radix_greek &radix_Greek
    &radix_roman &radix_Roman));
#======================================================================
# This isn't really any sort of general purpose Radix module,
# probably the term "radix" is a misnomer here!
# It is used to primarily generate labels, or uniquifying suffixes to make ID's,
# Bibtex year tags like 2013a, etc  using alphabetic letters, or
# perhaps greek, or even from a set of symbols.
#
# The general idea is simply to generate labels in the sequence:
#   a,b,c,...y,z,aa,ab,ac,...az,ba,...zy,zz,aaa,aab,.... and so on.
# I would assume that the usual advise is that it is bad style to pass,
# or even approach "z";  However, this is an automaton, and things happen.
#======================================================================

sub radix_format {
  my ($number, @symbols) = @_;
  my $string = '';
  my $max    = scalar(@symbols);
  while ($number > 0) {
    $string = $symbols[($number - 1) % $max] . $string;
    $number = int(($number - 1) / $max); }
  return $string; }

my @letters = (qw(a b c d e f g h i j k l m n o p q r s t u v w x y z));
my @Letters = (qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z));
my @greek   = ("\x{03B1}", "\x{03B2}", "\x{03B3}",
  "\x{03B4}", "\x{03B5}", "\x{03B6}", "\x{03B7}",
  "\x{03B8}", "\x{03B9}", "\x{03BA}", "\x{03BB}",
  "\x{03BC}", "\x{03BD}", "\x{03BE}", "\x{03BF}",
  "\x{03C0}", "\x{03C1}", "\x{03C3}",
  "\x{03C4}", "\x{03C5}", "\x{03C6}", "\x{03C7}",
  "\x{03C8}", "\x{03C9}");
my @Greek = ("\x{0391}", "\x{0392}", "\x{0393}",
  "\x{0394}", "\x{0395}", "\x{0396}", "\x{0397}",
  "\x{0398}", "\x{0399}", "\x{039A}", "\x{039B}",
  "\x{039C}", "\x{039D}", "\x{039E}", "\x{039F}",
  "\x{03A0}", "\x{03A1}", "\x{03A3}",
  "\x{03A4}", "\x{03A5}", "\x{03A6}", "\x{03A7}",
  "\x{03A8}", "\x{03A9}");

sub radix_alpha {
  my ($n) = @_;
  return radix_format($n, @letters); }

sub radix_Alpha {
  my ($n) = @_;
  return radix_format($n, @Letters); }

sub radix_greek {
  my ($n) = @_;
  return radix_format($n, @greek); }

sub radix_Greek {
  my ($n) = @_;
  return radix_format($n, @Greek); }

# Dumb place for this, but where else...
# Note: This is one "The TeX Way"! (bah!! hint: try a large number)
# namely, it's very limited.... what happened to my much-improved version?
my @rmletters = ('i', 'v', 'x', 'l', 'c', 'd', 'm');    # [CONSTANT]

sub radix_roman {
  my ($n) = @_;
  my $div = 1000;
  my $s = ($n > $div ? ('m' x int($n / $div)) : '');
  my $p = 4;
  while ($n %= $div) {
    $div /= 10;
    my $d = int($n / $div);
    if ($d % 5 == 4) { $s .= $rmletters[$p]; $d++; }
    if ($d > 4) { $s .= $rmletters[$p + int($d / 5)]; $d %= 5; }
    if ($d) { $s .= $rmletters[$p] x $d; }
    $p -= 2; }
  return $s; }

# Convert the number to lower case roman numerals, returning a list of LaTeXML::Core::Token
sub radix_Roman {
  my ($n) = @_;
  return uc(radix_roman($n)); }

#======================================================================
1;
