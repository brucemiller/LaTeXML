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
use charnames ':full';
our @EXPORT = qw( &UTF &unicode_accent &unicode_mathvariant &unicode_convert &unicode_math_properties);
#======================================================================
# Unicode manipulation utilities useful for LaTeXML
# Mostly, but not exclusively, about Mathematics
#======================================================================

sub UTF {
  my ($code) = @_;
  return pack('U', $code); }

#======================================================================
# Accents
# There are potentially several Unicode codepoints that characterize a given accent:
#  combiner   : unicode combining character that effects the accent when following a base char.
#       generally in Combining block
#  standalone : form that shows accent w/o base, but small(ish) and already raised/lowered!
#       sometimes called "isolated". Usually a "spacing" form, else NBSP followed by combiner.
#  unwrapped + role : form that shows the accent itself, typically larger and on baseline;
#        Used in operand for eg. MathML mover/munder
#  name       : arbitrary short descriptive, for good measure
# The ideal glyphs for each of these don't necessarily exist in Unicode,
# nor are the best choices always clear.
# Ideally, we would cover ALL accents that might appear in TeX!
our @accent_data = (
  { name => 'grave', combiner => "\x{0300}", standalone => UTF(0x60),    # \'
    unwrapped => "`", role => 'OVERACCENT' },                            #  (OR \x{2035} or UTF(0x60) ?)
  { name => 'acute', combiner => "\x{0301}", standalone => UTF(0xB4),    # \\'
    unwrapped => UTF(0xB4), role => 'OVERACCENT' },                      # (OR \x{2032} or UTF(0xB4)?)
  { name => 'hat', combiner => "\x{0302}", standalone => "\x{02C6}",     # \^
    unwrapped => UTF(0x5E), role => 'OVERACCENT' },
  { name => 'ddot', combiner => "\x{0308}", standalone => UTF(0xA8),     # \"
    unwrapped => UTF(0xA8), role => 'OVERACCENT' },                      # (or \x{22C5})
  { name => 'tilde', combiner => "\x{0303}", standalone => "\x{02DC}",    # \~
    unwrapped => UTF(0x7E), role => 'OVERACCENT' },
  { name => 'bar', combiner => "\x{0304}", standalone => UTF(0xAF),       # \=
    unwrapped => UTF(0xAF), role => 'OVERACCENT' },
  { name => 'dot', combiner => "\x{0307}", standalone => "\x{02D9}",      # \.
    unwrapped => "\x{02D9}", role => 'OVERACCENT' },                      # (OR \x{22C5} or \x{0209} ?
  { name => 'dtick', combiner => "\x{030B}", standalone => "\x{02DD}",    # \H
    unwrapped => "\x{2032}\x{2032}", role => 'OVERACCENT' },              # (Or UTF(0xA8) or " ?)
  { name => 'breve', combiner => "\x{0306}", standalone => "\x{02D8}",    # \u
    unwrapped => "\x{02D8}", role => 'OVERACCENT' },
  { name => 'check', combiner => "\x{030C}", standalone => "\x{02C7}",    # \v
    unwrapped => "\x{02C7}", role => 'OVERACCENT' },
  { name => 'ring', combiner => "\x{030A}", standalone => "\x{02DA}",     # \r
    unwrapped => "\x{02DA}", role => 'OVERACCENT' },                      # (or \x{2218} ?)
  { name => 'vec', combiner => "\x{20D7}", standalone => "\N{NBSP}\x{20D7}",    # \vec
    unwrapped => "\x{2192}", role => 'OVERACCENT' },
  { name => 'tie', combiner => "\x{0361}", standalone => "\N{NBSP}\x{0361}",    # \t
    unwrapped => "u", role => 'OVERACCENT' },
  ## UNDERACCENT accents
  { name => 'cedilla', combiner => "\x{0327}", standalone => UTF(0xB8),         # \c
    unwrapped => UTF(0xB8), role => 'UNDERACCENT' },                            # not even math?
  { name => 'underdot', combiner => "\x{0323}", standalone => '.',              #  \@text@daccent
    unwrapped => "\x{22C5}", role => 'UNDERACCENT' },                           # (Or \x{02D9} ?)
  { name => 'underbar', combiner => "\x{0331}", standalone => '_',
    unwrapped => UTF(0xAF), role => 'UNDERACCENT' },
  { name => 'lfhook', combiner => "\x{0326}", standalone => ",",                # '\lfhook'
    unwrapped => ',', role => 'UNDERACCENT' },
  { name => 'ogonek', combiner => "\x{0328}", standalone => "\x{02DB}",
    unwrapped => "\x{02DB}", role => 'UNDERACCENT' },                           # not even math???
);
# Set up a hash keyed on both standalone & combiner chars
our %accent_data_lookup = ();
foreach my $entry (@accent_data) {
  $accent_data_lookup{ $$entry{standalone} } = $entry;
  $accent_data_lookup{ $$entry{combiner} }   = $entry;
}

# Lookup accent data keyed by either combiner or standalone unicode.
sub unicode_accent {
  my ($char) = @_;
  return (defined $char) && $accent_data_lookup{$char}; }

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
    'w'        => "\x{02B7}",
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
    'c'        => "\x{1D9C}",
    'f'        => "\x{1DA0}",
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
our %math_props = (
  #======================================================================
  "0" => { role => 'NUMBER', meaning => 0 },
  "1" => { role => 'NUMBER', meaning => 1 },
  "2" => { role => 'NUMBER', meaning => 2 },
  "3" => { role => 'NUMBER', meaning => 3 },
  "4" => { role => 'NUMBER', meaning => 4 },
  "5" => { role => 'NUMBER', meaning => 5 },
  "6" => { role => 'NUMBER', meaning => 6 },
  "7" => { role => 'NUMBER', meaning => 7 },
  "8" => { role => 'NUMBER', meaning => 8 },
  "9" => { role => 'NUMBER', meaning => 9 },
  #======================================================================
  '=' => { role => 'RELOP',   meaning => 'equals' },
  '+' => { role => 'ADDOP',   meaning => 'plus' },
  '-' => { role => 'ADDOP',   meaning => 'minus' },
  '*' => { role => 'MULOP',   meaning => 'times' },
  '/' => { role => 'MULOP',   meaning => 'divide' },
  '!' => { role => 'POSTFIX', meaning => 'factorial' },
  ',' => { role => 'PUNCT' },
  '.' => { role => 'PERIOD' },
  ';' => { role => 'PUNCT' },
  ':' => { role => 'METARELOP', name     => 'colon' },          # plausible default?
  '|' => { role => 'VERTBAR',   stretchy => 'false' },
  '<' => { role => 'RELOP',     meaning  => 'less-than' },
  '>' => { role => 'RELOP',     meaning  => 'greater-than' },
  '(' => { role => 'OPEN',      stretchy => 'false' },
  ')' => { role => 'CLOSE',     stretchy => 'false' },
  '[' => { role => 'OPEN',      stretchy => 'false' },
  ']' => { role => 'CLOSE',     stretchy => 'false' },
  '{' => { role => 'OPEN',      stretchy => 'false' },
  '}' => { role => 'CLOSE',     stretchy => 'false' },

##  ':'        => { role => 'METARELOP' },    # \colon # Seems like good default role

  #======================================================================
  UTF(0x5C) => { role => 'ADDOP', meaning => 'set-minus' },        # \backslash
  UTF(0xAC) => { role => 'BIGOP', meaning => 'not' },              # \neg, \lnot
  UTF(0xAC) => { role => 'BIGOP', meaning => 'not' },              # \neg
  UTF(0xB1) => { role => 'ADDOP', meaning => 'plus-or-minus' },    # \pm
  UTF(0xD7) => { role => 'MULOP', meaning => 'times' },            # \times
  UTF(0xF7) => { role => 'MULOP', meaning => 'divide' },           # \div

  #======================================================================
  "\x{2020}" => { role => 'MULOP' },                                                     # \dagger
  "\x{2021}" => { role => 'MULOP' },                                                     # \ddagger
  "\x{2032}" => { role => 'SUPOP', },                                                    # \prime
  "\x{2061}" => { role => 'APPLYOP',    name    => '',      reversion => '' },
  "\x{2062}" => { role => 'MULOP',      meaning => 'times', name      => '', reversion => '' },
  "\x{2063}" => { role => 'PUNCT',      name    => '',      reversion => '' },
  "\x{2064}" => { role => 'ADDOP',      meaning => 'plus',  name      => '', reversion => '' },
  "\x{210F}" => { role => 'ID',         meaning => 'Planck-constant-over-2-pi' },        # \hbar
  "\x{2111}" => { role => 'OPFUNCTION', meaning => 'imaginary-part' },                   # \Im
  "\x{2118}" => { role => 'OPFUNCTION', meaning => 'Weierstrass-p' },                    # \wp
  "\x{211C}" => { role => 'OPFUNCTION', meaning => 'real-part' },                        # \Re
  "\x{2190}" => { role => 'ARROW' },                           # \leftarrow # LEFTWARDS ARROW
  "\x{2191}" => { role => 'ARROW', name => 'uparrow' },        # \uparrow # UPWARDS ARROW
  "\x{2192}" => { role => 'ARROW' },                           # \to, \rightarrow # RIGHTWARDS ARROW
  "\x{2193}" => { role => 'ARROW', name => 'downarrow' },      # \downarrow # DOWNWARDS ARROW
  "\x{2194}" => { role => 'METARELOP' },                       # \leftrightarrow # LEFT RIGHT ARROW
  "\x{2195}" => { role => 'ARROW', name => 'updownarrow' },    # \updownarrow # UP DOWN ARROW
  "\x{2196}" => { role => 'ARROW' },                           # \nwarrow # NORTH WEST ARROW
  "\x{2197}" => { role => 'ARROW' },                           # \nearrow # NORTH EAST ARROW
  "\x{2198}" => { role => 'ARROW' },                           # \searrow # SOUTH EAST ARROW
  "\x{2199}" => { role => 'ARROW' },                           # \swarrow # SOUTH WEST ARROW
  "\x{219D}" => { role => 'ARROW', meaning => 'leads-to' },    # \leadsto #
  "\x{21A6}" => { role => 'ARROW', meaning => 'maps-to' },     # \mapsto #
  "\x{21A9}" => { role => 'ARROW' },    # \hookleftarrow # LEFTWARDS ARROW WITH HOOK
  "\x{21AA}" => { role => 'ARROW' },    # \hookrightarrow # RIGHTWARDS ARROW WITH HO},
  "\x{21BC}" => { role => 'ARROW' },    # \leftharpoonup # LEFTWARDS HARPOON WITH BARB UPWARDS
  "\x{21BD}" => { role => 'ARROW' },    # \leftharpoondown # LEFTWARDS HARPOON WITH BARB DOWNWARDS,
  "\x{21C0}" => { role => 'ARROW' },    # \rightharpoonup # RIGHTWARDS HARPOON WITH BARB UPWARDS
  "\x{21C1}" => { role => 'ARROW' },    # \rightharpoondown # RIGHTWARDS HARPOON WITH BARB DOWNWARDS
  "\x{21CC}" => { role => 'METARELOP' }, # \rightleftharpoons # RIGHTWARDS HARPOON OVER LEFTWARDS HARPOON
  "\x{21D0}" => { role => 'ARROW' },                       # \Leftarrow # LEFTWARDS DOUBLE ARROW
  "\x{21D1}" => { role => 'ARROW', name => 'Uparrow' },    # \Uparrow # UPWARDS DOUBLE ARROW
  "\x{21D2}" => { role => 'ARROW' },                       # \Rightarrow # RIGHTWARDS DOUBLE ARROW
  "\x{21D3}" => { role => 'ARROW', name => 'Downarrow' },    # \Downarrow # DOWNWARDS DOUBLE ARROW
  "\x{21D4}" => { role => 'METARELOP', meaning => 'iff' }, # ,\Leftrightarrow, \iff # LEFT RIGHT DOUBLE ARROW
  "\x{21D5}" => { role => 'ARROW',  name    => 'Updownarror' },  # \Updownarrow # UP DOWN DOUBLE ARROW
  "\x{2200}" => { role => 'BIGOP',  meaning => 'for-all' },      # \forall
  "\x{2202}" => { role => 'DIFFOP', meaning => 'partial-differential' },    # \partial
  "\x{2203}" => { role => 'BIGOP',  meaning => 'exists' },                  # \exists
  "\x{2205}" => { role => 'ID',     meaning => 'empty-set' },               # \emptyset
  "\x{2207}" => { role => 'OPERATOR' },                                     # \nabla
  "\x{2208}" => { role => 'RELOP', meaning => 'element-of' },               # \in
  "\x{2209}" => { role => 'RELOP', meaning => 'not-element-of' },           # \notin
  "\x{220B}" => { role => 'RELOP', meaning => 'contains' },                 # \ni
  "\x{220F}" => { role => 'SUMOP', meaning => 'product', need_scriptpos => 1, need_mathstyle => 1 }, # \prod
"\x{2210}" => { role => 'SUMOP', meaning => 'coproduct', need_scriptpos => 1, need_mathstyle => 1 }, # \amalg, \coprod
  "\x{2211}" => { role => 'SUMOP', meaning => 'sum', need_scriptpos => 1, need_mathstyle => 1 }, # \sum
  "\x{2213}" => { role => 'ADDOP', meaning => 'minus-or-plus' },    # \mp
  "\x{2216}" => { role => 'ADDOP', meaning => 'set-minus' },        # \setminus
  "\x{2217}" => { role => 'MULOP', meaning => 'times' },            # \ast
  "\x{2218}" => { role => 'MULOP', meaning => 'compose' },          # \circ
  "\x{2219}" => { role => 'MULOP' },                                # \bullet
  "\x{221A}" => { role => 'OPERATOR', meaning => 'square-root' },        # \surd
  "\x{221D}" => { role => 'RELOP',    meaning => 'proportional-to' },    # \propto
  "\x{221E}" => { role => 'ID',       meaning => 'infinity' },           # \infty
  "\x{2223}" => { role => 'VERTBAR' },    # \midDIVIDES (RELOP?) ?? well, sometimes.},
  "\x{2225}" => { role => 'VERTBAR', meaning => 'parallel-to', name => '||' },    # \parallel
  "\x{2227}" => { role => 'ADDOP',   meaning => 'and' },                          # \land, \wedge
  "\x{2228}" => { role => 'ADDOP',   meaning => 'or' },                           # \lor, \vee
  "\x{2229}" => { role => 'ADDOP',   meaning => 'intersection' },                 # \cap
  "\x{222A}" => { role => 'ADDOP',   meaning => 'union' },                        # \cup
  "\x{222B}" => { role => 'INTOP', meaning => 'integral', need_mathstyle => 1 }, # \int, (\smallint ?)
  "\x{222E}" => { role => 'INTOP', meaning => 'contour-integral', need_mathstyle => 1 },    # \oint
  "\x{223C}" => { role => 'RELOP', meaning => 'similar-to' },                               # \sim
  "\x{2240}" => { role => 'MULOP' },                                                        # \wr
  "\x{2243}" => { role => 'RELOP', meaning => 'similar-to-or-equals' },      # \simeq
  "\x{2245}" => { role => 'RELOP', meaning => 'approximately-equals' },      # \cong
  "\x{2248}" => { role => 'RELOP', meaning => 'approximately-equals' },      # \approx
  "\x{224D}" => { role => 'RELOP', meaning => 'asymptotically-equals' },     # \asymp
  "\x{2250}" => { role => 'RELOP', meaning => 'approaches-limit' },          # \doteq
  "\x{2260}" => { role => 'RELOP', meaning => 'not-equals' },                # \neq
  "\x{2261}" => { role => 'RELOP', meaning => 'equivalent-to' },             # \equiv
  "\x{2264}" => { role => 'RELOP', meaning => 'less-than-or-equals' },       # \leq
  "\x{2265}" => { role => 'RELOP', meaning => 'greater-than-or-equals' },    # \geq
  "\x{226A}" => { role => 'RELOP', meaning => 'much-less-than' },            # \ll
  "\x{226B}" => { role => 'RELOP', meaning => 'much-greater-than' },         # \gg
  "\x{227A}" => { role => 'RELOP', meaning => 'precedes' },                  # \prec
  "\x{227B}" => { role => 'RELOP', meaning => 'succeeds' },                  # \succ
  "\x{2282}" => { role => 'RELOP', meaning => 'subset-of' },                 # \subset
  "\x{2283}" => { role => 'RELOP', meaning => 'superset-of' },               # \supset
  "\x{2286}" => { role => 'RELOP', meaning => 'subset-of-or-equals' },       # \subseteq
  "\x{2287}" => { role => 'RELOP', meaning => 'superset-of-or-equals' },     # \supseteq
  "\x{228E}" => { role => 'ADDOP' },                                         # \uplus
  "\x{228F}" => { role => 'RELOP', meaning => 'square-image-of' },                 # \sqsubset
  "\x{2290}" => { role => 'RELOP', meaning => 'square-original-of' },              # \sqsupset
  "\x{2291}" => { role => 'RELOP', meaning => 'square-image-of-or-equals' },       # \sqsubseteq
  "\x{2292}" => { role => 'RELOP', meaning => 'square-original-of-or-equals' },    # \sqsupseteq
  "\x{2293}" => { role => 'ADDOP', meaning => 'square-intersection' },             # \sqcap
  "\x{2294}" => { role => 'ADDOP', meaning => 'square-union' },                    # \sqcup
  "\x{2295}" => { role => 'ADDOP', meaning => 'direct-sum' },                      # \oplus
  "\x{2296}" => { role => 'ADDOP', meaning => 'symmetric-difference' },            # \ominus
  "\x{2297}" => { role => 'MULOP', meaning => 'tensor-product' },                  # \otimes
  "\x{2298}" => { role => 'MULOP' },                                               # \oslash
  "\x{2299}" => { role => 'MULOP',     meaning => 'direct-product' },                    # \odot
  "\x{22A2}" => { role => 'METARELOP', meaning => 'proves' },                            # \vdash
  "\x{22A3}" => { role => 'METARELOP', meaning => 'does-not-prove' },                    # \dashv
  "\x{22A4}" => { role => 'ADDOP',     meaning => 'top' },                               # \top
  "\x{22A5}" => { role => 'ADDOP',     meaning => 'bottom' },                            # \bot
  "\x{22A7}" => { role => 'RELOP',     meaning => 'models' },                            # \models
  "\x{22B2}" => { role => 'ADDOP',     meaning => 'subgroup-of' },                       # \lhd
  "\x{22B3}" => { role => 'ADDOP',     meaning => 'contains-as-subgroup' },              # \rhd
  "\x{22B4}" => { role => 'ADDOP',     meaning => 'subgroup-of-or-equals' },             # \unlhd
  "\x{22B5}" => { role => 'ADDOP',     meaning => 'contains-as-subgroup-or-equals' },    # \unrhd
  "\x{22C0}" => { role => 'SUMOP', meaning => 'and', need_scriptpos => 1, need_mathstyle => 1 }, # \bigwedge
  "\x{22C1}" => { role => 'SUMOP', meaning => 'or', need_scriptpos => 1, need_mathstyle => 1 }, # \bigvee
"\x{22C2}" => { role => 'SUMOP', meaning => 'intersection', need_scriptpos => 1, need_mathstyle => 1 }, # \bigcap
  "\x{22C3}" => { role => 'SUMOP', meaning => 'union', need_scriptpos => 1, need_mathstyle => 1 }, # \bigcup
  "\x{22C4}" => { role => 'ADDOP' },    # \diamond
  "\x{22C5}" => { role => 'MULOP' },    # \cdot
  "\x{22C6}" => { role => 'MULOP' },    # \star
  "\x{22C8}" => { role => 'RELOP' },    # \bowtieBOWTIE
  "\x{22EF}" => { role => 'ID' },       # \cdots # MIDLINE HORIZONTAL ELLIPSIS
  "\x{22F1}" => { role => 'ID' },       # \ddots # DOWN RIGHT DIAGONAL ELLIPSIS
  "\x{2308}" => { role => 'OPEN',  name => 'lceil',  stretchy => 'false' },   # \lceil # LEFT CEILING
  "\x{2309}" => { role => 'CLOSE', name => 'rceil',  stretchy => 'false' },   # \rceil # RIGHT CEILING
  "\x{230A}" => { role => 'OPEN',  name => 'lfloor', stretchy => 'false' },   # \lfloor # LEFT FLOOR
  "\x{230B}" => { role => 'CLOSE', name => 'rfloor', stretchy => 'false' },   # \rfloor # RIGHT FLOOR
  "\x{2322}" => { role => 'RELOP' },                                          # \frownFRO},
  "\x{2323}" => { role => 'RELOP' },                                          # \smileSMI},
  "\x{25B3}" => { role => 'ADDOP' },                                          # \bigtriangleup
  "\x{25B7}" => { role => 'ADDOP' },                                          # \triangleright
  "\x{25BD}" => { role => 'ADDOP' },                                          # \bigtriangledown
  "\x{25C1}" => { role => 'ADDOP' },                                          # \triangleleft
  "\x{25CB}" => { role => 'MULOP' },                                          # \bigcirc
  "\x{27C2}" => { role => 'RELOP', meaning => 'perpendicular-to' },           # \perp
  "\x{27E8}" => { role => 'OPEN', name => 'langle', stretchy => 'false' }, # \langle # LEFT-POINTING ANGLE BRACKET
  "\x{27E9}" => { role => 'CLOSE', name => 'rangle', stretchy => 'false' }, # \rangle # RIGHT-POINTING ANGLE BRACKET
  "\x{27F5}" => { role => 'ARROW' },        # \longleftarrow # LONG LEFTWARDS ARROW
  "\x{27F6}" => { role => 'ARROW' },        # \longrightarrow # LONG RIGHTWARDS ARROW
  "\x{27F7}" => { role => 'METARELOP' },    # \longleftrightarrow # LONG LEFT RIGHT ARROW
  "\x{27F8}" => { role => 'ARROW' },        # \Longleftarrow # LONG LEFTWARDS DOUBLE ARROW
  "\x{27F9}" => { role => 'ARROW' },        # \Longrightarrow # LONG RIGHTWARDS DOUBLE ARROW
  "\x{27FA}" => { role => 'METARELOP' },    # \Longleftrightarrow # LONG LEFT RIGHT DOUBLE ARROW
  "\x{27FC}" => { role => 'ARROW' },        # \longmapsto # LONG RIGHTWARDS ARROW FROM B},
  "\x{2A00}" => { role => 'SUMOP', need_scriptpos => 1, need_mathstyle => 1 },   # \bigodotmeaning=> ?
"\x{2A01}" => { role => 'SUMOP', meaning => 'direct-sum', need_scriptpos => 1, need_mathstyle => 1 }, # \bigoplus
"\x{2A02}" => { role => 'SUMOP', meaning => 'tensor-product', need_scriptpos => 1, need_mathstyle => 1 }, # \bigotimes
"\x{2A04}" => { role => 'SUMOP', meaning => 'symmetric-difference', need_scriptpos => 1, need_mathstyle => 1 }, # \biguplus
"\x{2A06}" => { role => 'SUMOP', meaning => 'square-union', need_scriptpos => 1, need_mathstyle => 1 }, # \bigsqcup
  "\x{2A1D}" => { role => 'RELOP',      meaning => 'join' },                  # \Join
  "\x{2AAF}" => { role => 'RELOP',      meaning => 'precedes-or-equals' },    # \preceq
  "\x{2AB0}" => { role => 'RELOP',      meaning => 'succeeds-or-equals' },    # \succeq
  "\x{FF0F}" => { role => 'OPFUNCTION', meaning => 'not' },                   # \not
      #======================================================================
  "arccos"  => { role => 'OPFUNCTION',   meaning => 'inverse-cosine' },          # \arccos #
  "arcsin"  => { role => 'OPFUNCTION',   meaning => 'inverse-sine' },            # \arcsin #
  "arctan"  => { role => 'OPFUNCTION',   meaning => 'inverse-tangent' },         # \arctan #
  "arg"     => { role => 'OPFUNCTION',   meaning => 'argument' },                # \arg #
  "cos"     => { role => 'TRIGFUNCTION', meaning => 'cosine' },                  # \cos #
  "cosh"    => { role => 'TRIGFUNCTION', meaning => 'hyperbolic-cosine' },       # \cosh #
  "cot"     => { role => 'TRIGFUNCTION', meaning => 'cotangent' },               # \cot #
  "coth"    => { role => 'TRIGFUNCTION', meaning => 'hyperbolic-cotangent' },    # \coth #
  "csc"     => { role => 'TRIGFUNCTION', meaning => 'cosecant' },                # \csc #
  "deg"     => { role => 'OPFUNCTION',   meaning => 'degree' },                  # \deg #
  "det"     => { role => 'LIMITOP',      meaning => 'determinant', need_scriptpos => 1 },    # \det #
  "dim"     => { role => 'LIMITOP',      meaning => 'dimension' },                           # \dim #
  "exp"     => { role => 'OPFUNCTION',   meaning => 'exponential' },                         # \exp #
  "gcd"     => { role => 'OPFUNCTION',   meaning => 'gcd', need_scriptpos => 1 },            # \gcd #
  "hom"     => { role => 'OPFUNCTION',   need_scriptpos => 1 },                              # \hom #
  "inf"     => { role => 'LIMITOP',      meaning        => 'infimum', need_scriptpos => 1 },  # \inf #
  "ker"     => { role => 'OPFUNCTION',   meaning        => 'kernel' },                        # \ker #
  "lg"      => { role => 'OPFUNCTION' },                                                      # \lg #
  "lim"     => { role => 'LIMITOP',    meaning => 'limit',          need_scriptpos => 1 }, # \lim #
  "lim inf" => { role => 'LIMITOP',    meaning => 'limit-infimum',  need_scriptpos => 1 }, # \liminf #
  "lim sup" => { role => 'LIMITOP',    meaning => 'limit-supremum', need_scriptpos => 1 }, # \limsup #
  "ln"      => { role => 'OPFUNCTION', meaning => 'natural-logarithm' },                   # \ln #
  "log"     => { role => 'OPFUNCTION', meaning => 'logarithm' },                           # \log #
  "max"     => { role => 'OPFUNCTION', meaning => 'maximum', need_scriptpos => 1 },        # \max #
  "min"     => { role => 'OPFUNCTION', meaning => 'minimum', need_scriptpos => 1 },        # \min #
  "Pr"      => { role => 'OPFUNCTION',   need_scriptpos => 1 },                            # \Pr #
  "sec"     => { role => 'TRIGFUNCTION', meaning        => 'secant' },                     # \sec #
  "sin"     => { role => 'TRIGFUNCTION', meaning        => 'sine' },                       # \sin #
  "sinh"    => { role => 'TRIGFUNCTION', meaning        => 'hyperbolic-sine' },            # \sinh #
  "sup"     => { role => 'LIMITOP',      meaning        => 'supremum', need_scriptpos => 1 }, # \sup #
  "tan"     => { role => 'TRIGFUNCTION', meaning        => 'tangent' },               # \tan #
  "tanh"    => { role => 'TRIGFUNCTION', meaning        => 'hyperbolic-tangent' },    # \tanh #
);

sub unicode_math_properties {
  my ($char) = @_;
  return (defined $char) && $math_props{$char}; }

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
