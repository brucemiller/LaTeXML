# /=====================================================================\ #
# |  LaTeXML::Util::Unicode                                             | #
# | Unicode Utilities for LaTeXML                                       | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Util::Unicode;
use strict;
use warnings;
use base qw(Exporter);
our @EXPORT = qw( &UTF &unicode_mathvariant &unicode_convert);

#======================================================================
# Unicode manipulation utilities useful for LaTeXML
# Mostly, but not exclusively, about Mathematics
#======================================================================

sub UTF {
  my ($code) = @_;
  return pack('U', $code); }

#======================================================================
# Unicode Math Codepoints
# The basic latin and greek alphabets, as well as numbers appear in several
# (virtual) blocks.
# normal
#  bold, italic, bold-italic
#  sans-serif, bold-sans-serif, sans-serif-italic
#  monospace
#  script, bold-script
#  fraktur, bold-fraktur
#  double-struck

# Create mapping sequences of
#   latin (uppercase & lowercase), greek (uppercase & lowercase) and digits
# to blocks at the given positions within
sub makePlane1Map {
  my ($latin, $GREEK, $greek, $digits) = @_;
  return (
    (map { (UTF(ord('A') + $_) => UTF($latin + $_)) } 0 .. 25),
    (map { (UTF(ord('a') + $_) => UTF($latin + 26 + $_)) } 0 .. 25),
    ($GREEK  ? (map { (UTF(0x0391 + $_)   => UTF($GREEK + $_)) } 0 .. 24) : ()),
    ($greek  ? (map { (UTF(0x03B1 + $_)   => UTF($greek + $_)) } 0 .. 24) : ()),
    ($digits ? (map { (UTF(ord('0') + $_) => UTF($digits + $_)) } 0 .. 9) : ())); }

my %unicode_map = (    # CONSTANT
  'bold'   => { makePlane1Map(0x1D400, 0x1D6A8, 0x1D6C2, 0x1D7CE) },
  'italic' => { makePlane1Map(0x1D434, 0x1D6E2, 0x1D6FC, undef),
    h => "\x{210E}" },
  'bold-italic'            => { makePlane1Map(0x1D468, 0x1D71C, 0x1D736, undef) },
  'sans-serif'             => { makePlane1Map(0x1D5A0, undef,   undef,   0x1D7E2) },
  'bold-sans-serif'        => { makePlane1Map(0x1D5D4, 0x1D756, 0x1D770, 0x1D7EC) },
  'sans-serif-italic'      => { makePlane1Map(0x1D608, undef,   undef,   undef) },
  'sans-serif-bold-italic' => { makePlane1Map(0x1D63C, 0x1D790, 0x1D7AA, undef) },
  'monospace'              => { makePlane1Map(0x1D670, undef,   undef,   0x1D7F6) },
  'script'                 => { makePlane1Map(0x1D49C, undef,   undef,   undef),
    B => "\x{212C}", E => "\x{2130}", F => "\x{2131}", H => "\x{210B}", I => "\x{2110}",
    L => "\x{2112}", M => "\x{2133}", R => "\x{211B}",
    e => "\x{212F}", g => "\x{210A}", o => "\x{2134}" },
  'bold-script' => { makePlane1Map(0x1D4D0, undef, undef, undef) },
  'fraktur'     => { makePlane1Map(0x1D504, undef, undef, undef),
    C => "\x{212D}", H => "\x{210C}", I => "\x{2111}", R => "\x{211C}", Z => "\x{2128}" },
  'bold-fraktur'  => { makePlane1Map(0x1D56C, undef, undef, undef) },
  'double-struck' => { makePlane1Map(0x1D538, undef, undef, 0x1D7D8),
    C => "\x{2102}", H => "\x{210D}", N => "\x{2115}", P => "\x{2119}", Q => "\x{211A}",
    R => "\x{211D}", Z => "\x{2124}" },
  superscript => {
    "\x{2032}" => "'",           # \prime
    0          => "\x{2070}",
    1          => UTF(0xB9),
    2          => UTF(0xB2),
    3          => UTF(0xB3),
    4          => "\x{2074}",
    5          => "\x{2075}",
    6          => "\x{2076}",
    7          => "\x{2077}",
    8          => "\x{2078}",
    9          => "\x{2079}",
    '+'        => "\x{207A}",
    '-'        => "\x{207B}",
    '='        => "\x{207C}",
    '('        => "\x{207D}",
    ')'        => "\x{207E}",
    'n'        => "\x{207F}",
    'i'        => "\x{2071}",
    'V'        => "\x{2C7D}",
    'h'        => "\x{02B0}",    # aspirated!?
    'j'        => "\x{02B2}",
    'r'        => "\x{02B3}",
    'W'        => "\x{02B7}",
    'y'        => "\x{02B8}",
    's'        => "\x{02E2}",
    'x'        => "\x{02E3}",
    'A'        => "\x{1D2C}",
    UTF(0xC6)  => "\x{1D2D}",
    'B'        => "\x{1D2E}",
    'D'        => "\x{1D30}",
    'E'        => "\x{1D31}",
    'G'        => "\x{1D33}",
    'H'        => "\x{1D34}",
    'I'        => "\x{1D35}",
    'J'        => "\x{1D36}",
    'K'        => "\x{1D37}",
    'L'        => "\x{1D38}",
    'M'        => "\x{1D39}",
    'N'        => "\x{1D3A}",
    'O'        => "\x{1D3C}",
    'P'        => "\x{1D3E}",
    'R'        => "\x{1D3F}",
    'T'        => "\x{1D40}",
    'U'        => "\x{1D41}",
    'W'        => "\x{1D42}",
    'a'        => "\x{1D43}",
    "\x{03B1}" => "\x{1D45}",    # \alpha
    UTF(0xE6)  => "\x{1D46}",
    'b'        => "\x{1D47}",
    'd'        => "\x{1D48}",
    'e'        => "\x{1D49}",
    "\x{03B5}" => "\x{1D4B}",    # \varepsilon
    "\x{03F5}" => "\x{1D4B}",    # \epsilon ??? Close enough?
    'g'        => "\x{1D4D}",
    '!'        => "\x{1D4E}",
    'k'        => "\x{1D4F}",
    'm'        => "\x{1D50}",
    'o'        => "\x{1D52}",
    'p'        => "\x{1D56}",
    't'        => "\x{1D57}",
    'u'        => "\x{1D58}",
    'v'        => "\x{1D5B}",
    "\x{03B2}" => "\x{1D5D}",    # \beta
    "\x{03B3}" => "\x{1D5E}",    # \gamma
    "\x{03B4}" => "\x{1D5F}",    # \delta
    "\x{03C6}" => "\x{1D60}",    # \varphi
    "\x{03D5}" => "\x{1D60}",    # \phi; close enough?
    "\x{03BE}" => "\x{1D61}",    # \xi
    'H'        => "\x{1D78}",
    'c'        => "\x{1D9C}",
    'f'        => "\x{1DA0}",
    'g'        => "\x{1DA2}",
    "\x{03A6}" => "\x{1DB2}",    # \Phi?
    "\x{03C5}" => "\x{1DB7}",    # \upsilon
    'z'        => "\x{1DBB}",
    "\x{03B8}" => "\x{1DBF}",    # \theta
  },
  subscript => {
    0             => "\x{2080}",
    1             => "\x{2081}",
    2             => "\x{2082}",
    3             => "\x{2083}",
    4             => "\x{2084}",
    5             => "\x{2085}",
    6             => "\x{2086}",
    7             => "\x{2087}",
    8             => "\x{2088}",
    9             => "\x{2089}",
    '+'           => "\x{208A}",
    '-'           => "\x{208B}",
    '='           => "\x{208C}",
    '('           => "\x{208D}",
    ')'           => "\x{208E}",
    'a'           => "\x{2090}",
    'e'           => "\x{2091}",
    'o'           => "\x{2092}",
    'x'           => "\x{2093}",
    'upsidedowne' => "\x{2094}",
    'h'           => "\x{2095}",
    'k'           => "\x{2096}",
    'l'           => "\x{2097}",
    'm'           => "\x{2098}",
    'n'           => "\x{2099}",
    'p'           => "\x{209A}",
    's'           => "\x{209B}",
    't'           => "\x{209C}",
    'j'           => "\x{2C7C}",
    'i'           => "\x{1D62}",
    'r'           => "\x{1D63}",
    'u'           => "\x{1D64}",
    'v'           => "\x{1D65}",
    "\x{03B2}"    => "\x{1D66}",    # \beta
    "\x{03B3}"    => "\x{1D67}",    # \gamma
    "\x{03C1}"    => "\x{1D68}",    # \rho
    "\x{03C6}"    => "\x{1D69}",    # \varphi
    "\x{03D5}"    => "\x{1D69}",    # \phi; close enough?
    "\x{03BE}"    => "\x{1D6A}",    # \xi
  },
);

# Return the re-mapping of the codepoints in $string to the codepoints corresponding
# to the given $style.
# Returns undef if not all chars have a known mapping.
sub unicode_convert {
  my ($string, $style) = @_;
  if (my $mapping = $unicode_map{$style}) {
    my @c = map { $$mapping{$_} } split(//, (defined $string ? $string : ''));
    if (!grep { !defined $_ } @c) {    # Only if ALL chars in the token could be mapped... ?????
      return join('', @c); } }
  return; }

#======================================================================
# Normalizing a Math Font for lookup in Unicode.
# Basically, this results in MathML's mathvariant
# which corresponds to the major blocks of "styled" characters in Unicode:
# Mappings between (normalized) internal fonts & sizes.
# Default math font is roman|medium|upright.
my %mathvariants = (    # CONSTANT
  'upright'                 => 'normal',
  'serif'                   => 'normal',
  'medium'                  => 'normal',
  'bold'                    => 'bold',
  'italic'                  => 'italic',
  'medium italic'           => 'italic',
  'bold italic'             => 'bold-italic',
  'doublestruck'            => 'double-struck',
  'blackboard'              => 'double-struck',
  'blackboard bold'         => 'double-struck',            # all collapse
  'blackboard upright'      => 'double-struck',            # all collapse
  'blackboard bold upright' => 'double-struck',            # all collapse
  'fraktur'                 => 'fraktur',
  'fraktur italic'          => 'fraktur',                  # all collapse
  'fraktur bold'            => 'bold-fraktur',
  'script'                  => 'script',
  'script italic'           => 'script',                   # all collapse
  'script bold'             => 'bold-script',
  'caligraphic'             => 'script',                   # NOTE: TeX caligraphic is NOT script!
  'caligraphic bold'        => 'bold-script',              # collapse
  'sansserif'               => 'sans-serif',
  'sansserif bold'          => 'bold-sans-serif',
  'sansserif italic'        => 'sans-serif-italic',
  'sansserif bold italic'   => 'sans-serif-bold-italic',
  'typewriter'              => 'monospace',
  'typewriter bold'         => 'monospace',
  'typewriter italic'       => 'monospace',
  'typewriter bold italic'  => 'monospace',
);

# The font differences (from the containing context) have been deciphered
# into font, size and color attributes.  The font should match
# one of the above... (?)

# Given a font string (joining the components)
# reduce it to a "sane" font.  Note that MathML uses a single mathvariant
# to name the font, and doesn't inherit font components like italic or bold.
# Thus the font should be "complete", but also we can ignore components with
#  default values like medium or upright (unless that is the only component).
sub unicode_mathvariant {
  my ($font) = @_;
  $font =~ s/slanted/italic/;                           # equivalent in math
  $font =~ s/(?<!\w)serif// unless $font eq 'serif';    # Not needed (unless alone)
  $font =~ s/(?<!^)upright//;                           # Not needed (unless 1st element)
  $font =~ s/(?<!^)medium//;                            # Not needed (unless 1st element)
  $font =~ s/^\s+//; $font =~ s/\s+$//;
  my $variant;
  return $variant if $variant = $mathvariants{$font};
  #  $font =~ s/\sitalic//;          # try w/o italic ?
  #  return $variant if $variant = $mathvariants{$font};
  #  $font =~ s/\sbold//;          # try w/o bold ?
  #  return $variant if $variant = $mathvariants{$font};
  return 'normal'; }

#======================================================================
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Util::Unicode> - Unicode Utilities.

=head1 SYNOPSIS

C<LaTeXML::Util::Unicode> provides several useful utilities for manipulating Unicode for LaTeXML,
mostly to assist with mathematics.

=head1 DESCRIPTION

=over 4

=item C<< $string = UTF($codepoint); >>

Converts the given numeric codepoint to unicode.
This is useful for codepoints under 255,
such as C<UTF(0xA0)> for non-breaking space,
which perl does not reliably handle.

=item C<< $mathvariant = unicode_mathvariant($font); >>

Converts the font to a Unicode-appropriate mathvariant.
The font should be in the string form generally found during post-processing,
eg "bold italic".  The mathvariant returned can be used in MathML, or passed
to C<unicode_convert> to convert strings into the given style.

=item C<< $unicode = unicode_convert($string,$style); >>

Converts the given string to the codepoints correspinding to the requested style.
Returns undef if not all characters in the string can be converted.
The recognized styles are
C<bold>,
C<italic>,
C<bold-italic>,
C<sans-serif>,
C<bold-sans-serif>,
C<sans-serif-italic>,
C<sans-serif-bold-italic>,
C<monospace>,
C<script>,
C<bold-script>,
C<fraktur>,
C<bold-fraktur>,
C<double-struck>,
as well as
C<superscript>
and
C<subscript>.

=back

=cut
