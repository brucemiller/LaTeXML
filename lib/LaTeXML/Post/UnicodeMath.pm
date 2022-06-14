# /=====================================================================\ #
# |  LaTeXML::Post::UnicodeMath                                         | #
# | MathML generator for LaTeXML                                        | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post::UnicodeMath;
use strict;
use warnings;
use LaTeXML::Common::XML;
use LaTeXML::Post;
use List::Util qw(max);
use base qw(LaTeXML::Post::MathProcessor);

# ================================================================================
# LaTeXML::Post::UnicodeMath; A Math Postprocessor
# What we'd like to support is UnicodeMath as
#   (1) a single pure text format for math
#   (2) a secondary format within MathML as a m:semantic/m:annotation
#   (3) a utility for converting math to plain text within other post processors
#     (eg. for title attributes)
# Attempts to be compliant with
#    https://www.unicode.org/notes/tn28/UTN28-PlainTextMath-v3.1.pdf
# ================================================================================

#================================================================================
# Useful switches when creating a converter with special needs.
#  plane1  : use Unicode plane 1 characters for math letters
#  hackplane1 : use a hybrid of plane1 for script and fraktur,
#               otherwise regular chars with mathvariant
#  nestmath : allow m:math to be nested within m:mtext
#             otherwise flatten to m:mrow sequence of m:mtext and other math bits.
#  usemfenced : whether to use mfenced instead of mrow
#          this would be desired for MathML-CSS profile,
#          but (I think) mrow usually gets better handling in firefox,..?
#================================================================================

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Top level
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
our $lxMimeType = 'application/x-UnicodeMath';    # !?!?!?!?

sub convertNode {
  my ($self, $doc, $xmath, $style) = @_;
  my $math = $xmath->parentNode;
  my $uni  = $math && isElementNode($math) && unimath($math);
  return { processor => $self, encoding => $lxMimeType, mimetype => $lxMimeType,
    string => $uni }; }

sub rawIDSuffix {
  return '.muni'; }

sub getQName {
  my ($node) = @_;
  return $LaTeXML::Post::DOCUMENT->getQName($node); }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# General translation utilities.
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

sub realize {
  my ($node, $branch) = @_;
  return (ref $node) ? $LaTeXML::Post::DOCUMENT->realizeXMNode($node, $branch) : $node; }

# For a node that is a (possibly embellished) operator,
# find the underlying role.
my %EMBELLISHING_ROLE = (    # CONSTANT
  SUPERSCRIPTOP => 1, SUBSCRIPTOP => 1,
  OVERACCENT    => 1, UNDERACCENT => 1, MODIFIER => 1, MODIFIEROP => 1);

sub getOperatorRole {
  my ($node) = @_;
  if (!$node) {
    return; }
  elsif (my $role = $node->getAttribute('role')) {
    return $role; }
  elsif (getQName($node) eq 'ltx:XMApp') {
    my ($op, $base) = element_nodes($node);
    return ($EMBELLISHING_ROLE{ $op->getAttribute('role') || '' }
      ? getOperatorRole($base)
      : undef); } }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Table of Translators for presentation|content
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# All translators take XMath XML::LibXML nodes as arguments,
# and return an intermediate form (ie. array form) of MathML to be added.

# DANGER!!! These accumulate all the DefUnicodeMath declarations.
# They're fixed after the module has been loaded, so are Daemon Safe,
# but probably should be going into (post) STATE, so that they are extensible.
# IN FACT, I'm already taking baby-steps to export DefUnicodeMath (and needed helpers),
# in order to assist these extensions, so that will bring up daemon issues pretty quick.
our $MMLTable_P = {};
our $MMLTable_C = {};

sub DefUnicodeMath {
  my ($key, $presentation, $content) = @_;
  $$MMLTable_P{$key} = $presentation if $presentation;
  $$MMLTable_C{$key} = $content      if $content;
  return; }

sub lookupPresenter {
  my ($mode, $role, $name) = @_;
  $name = '?' unless $name;
  $role = '?' unless $role;
  return $$MMLTable_P{"$mode:$role:$name"} || $$MMLTable_P{"$mode:?:$name"}
    || $$MMLTable_P{"$mode:$role:?"} || $$MMLTable_P{"$mode:?:?"}; }

our $PREC_RELOP    = 1;
our $PREC_ADDOP    = 2;
our $PREC_MULOP    = 3;
our $PREC_SCRIPTOP = 4;
our $PREC_SYMBOL   = 10;
our $PREC_UNKNOWN  = 10;
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Various needed maps
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
my %stylestep = (    # CONSTANT
  display => 'text',         text         => 'script',
  script  => 'scriptscript', scriptscript => 'scriptscript');
my %stylesize = (    # CONSTANT
  display => '100%', text         => '100%',
  script  => '70%',  scriptscript => '50%');
my %style_script_step = (    # CONSTANT
  display => 'script',       text         => 'script',
  script  => 'scriptscript', scriptscript => 'scriptscript');
# Attributes for m:mstyle when changing between two mathstyles
my %stylemap = (             # CONSTANT
  display => { text => { displaystyle => 'false' },
    script       => { displaystyle => 'false', scriptlevel => '+1' },
    scriptscript => { displaystyle => 'false', scriptlevel => '+2' } },
  text => { display => { displaystyle => 'true' },
    script       => { scriptlevel => '+1' },
    scriptscript => { scriptlevel => '+2' } },
  script => { display => { displaystyle => 'true', scriptlevel => '-1' },
    text         => { scriptlevel => '-1' },
    scriptscript => { scriptlevel => '+1' } },
  scriptscript => { display => { displaystyle => 'true', scriptlevel => '-2' },
    text   => { scriptlevel => '-2' },
    script => { scriptlevel => '-1' } });
# Similar to above, but for use when there are no MathML structures used
# that NEED displaystyle to be set; presumably only to set a fontsize context
my %stylemap2 = (    # CONSTANT
  display => { text => {},
    script       => { scriptlevel => '+1' },
    scriptscript => { scriptlevel => '+2' } },
  text => { display => {},
    script       => { scriptlevel => '+1' },
    scriptscript => { scriptlevel => '+2' } },
  script => { display => { displaystyle => 'true', scriptlevel => '-1' },
    text         => { scriptlevel => '-1' },
    scriptscript => { scriptlevel => '+1' } },
  scriptscript => { display => { displaystyle => 'true', scriptlevel => '-2' },
    text   => { scriptlevel => '-2' },
    script => { scriptlevel => '-1' } });

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
  'blackboard bold'         => 'double-struck',    # all collapse
  'blackboard upright'      => 'double-struck',    # all collapse
  'blackboard bold upright' => 'double-struck',    # all collapse
  'fraktur'                 => 'fraktur',
  'fraktur italic'          => 'fraktur',          # all collapse
  'fraktur bold'            => 'bold-fraktur',
  'script'                  => 'script',
  'script italic'           => 'script',           # all collapse
  'script bold'             => 'bold-script',
  'caligraphic'      => 'script',              # all collapse; NOTE: In TeX caligraphic is NOT script!
  'caligraphic bold' => 'bold-script',
  'sansserif'        => 'sans-serif',
  'sansserif bold'   => 'bold-sans-serif',
  'sansserif italic' => 'sans-serif-italic',
  'sansserif bold italic'  => 'sans-serif-bold-italic',
  'typewriter'             => 'monospace',
  'typewriter bold'        => 'monospace',
  'typewriter italic'      => 'monospace',
  'typewriter bold italic' => 'monospace',
);

# The font differences (from the containing context) have been deciphered
# into font, size and color attributes.  The font should match
# one of the above... (?)

# Given a font string (joining the components)
# reduce it to a "sane" font.  Note that MathML uses a single mathvariant
# to name the font, and doesn't inherit font components like italic or bold.
# Thus the font should be "complete", but also we can ignore components with
#  default values like medium or upright (unless that is the only component).
sub mathvariantForFont {
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

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Support functions for Presentation MathML
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
sub unimath {
  my ($node) = @_;
  #  my ($uni, $prec) = unimath_map(element_nodes($node));
  my ($uni, $prec) = unimath_internal($node);
  #Debug("UnicodeMath: '$uni' (prec=$prec) from ".$node->toString);
  return $uni; }

# Strategy:
#   Convert to string, return string and multi
# where multi is some flag whether this is a multi char expression
# that may need parentheses or trailing space
# depending on the caller
sub unimath_internal {
  #   my ($node) = @_;
  #   my($uni,$prec)=unimath_internalX($node);
  #   Debug("=> '$uni' (prec=$prec)");
  #   return($uni,$prec); }

  # sub unimath_internalX {
  my ($node) = @_;
  return unimath_error("Missing Subexpression") unless $node;
  my $tag  = getQName($node);
  my $role = $node->getAttribute('role');
  #Debug("UnicodeMath tag=$tag, role=".($role||'<unknown>'));
  if (($tag eq 'ltx:Math') || ($tag eq 'ltx:XMath')) {
    return unimath_map(element_nodes($node)); }    # Really multiple nodes???
  elsif ($tag eq 'ltx:XMDual') {
    my ($content, $presentation) = element_nodes($node);
    return unimath_internal($presentation); }
  elsif (($tag eq 'ltx:XMWrap') || ($tag eq 'ltx:XMArg')) {    # Only present if parsing failed!
    return unimath_map(element_nodes($node)); }
  elsif ($tag eq 'ltx:XMApp') {
    my ($op, @args) = element_nodes($node);
    if (!$op) {
      return unimath_error("Missing Operator"); }
    elsif ($role && ($role =~ /^(FLOAT|POST)(SUB|SUPER)SCRIPT$/)) {
      # (FLOAT|POST)(SUB|SUPER)SCRIPT's should NOT remain in successfully parsed math.
      # This conversion creates something "presentable", though doubtfully correct (empty mi?)
      # Really should mark & make a fake parsing pass to & group open/close pairs & attach scripts
      return ($2 eq 'SUB' ? unimath_sub(undef, undef, $op) : unimath_sup(undef, undef, $op)); }
    else {
      my $rop = realize($op);
      return &{ lookupPresenter('Apply', getOperatorRole($rop), $rop->getAttribute('meaning'))
      }($op, @args); } }
  elsif ($tag eq 'ltx:XMTok') {
    my $m = $node->getAttribute('meaning') || 'none';
    return ($m eq 'absent' ? '' : stylizeContent($node), $PREC_SYMBOL); }
  elsif ($tag eq 'ltx:XMHint') {
    ## Presumably would output some space here, except that space is default end delimiter of expr.
    return ''; }
  elsif ($tag eq 'ltx:XMArray') {
    my @rows = ();
    foreach my $row (element_nodes($node)) {
      push(@rows, join('&', map { unimath_nested($_, 0); } element_nodes($row))); }
    return ("\x{25A0}(" . join('@', @rows) . ')', 0); }
  elsif ($tag eq 'ltx:XMText') {
    return unimath_text($node); }
  elsif ($tag eq 'ltx:ERROR') {
    return unimath_error($node); }
  else {
    return unimath_text($node); } }

# Convert $node, wrapping in braces if its precedence is lower than $prec
# Should this recognize already-fenced? (or XMWrap, above?)
sub unimath_nested {
  my ($node,   $prec)  = @_;
  my ($string, $iprec) = unimath_internal($node);
  return ($iprec >= $prec ? $string : '{' . $string . '}'); }

# Just combine the conversion of all the @args
sub unimath_map {
  #  my ($op, @args) = @_;
  my (@args) = @_;
  my $iprec  = 0;
  my $oprec  = 0;
  if ((scalar(@args) > 1)
    && (($args[0]->getAttribute('role')  || 'none') eq 'OPEN')
    && (($args[-1]->getAttribute('role') || 'none') eq 'CLOSE')) {
    $oprec = $PREC_SYMBOL; }
  return (join('', map { unimath_nested($_, $iprec); } @args), $oprec); }

sub unimath_args {
  my ($op, @args) = @_;
  my $iprec = 0;
  my $oprec = 0;
  if ((scalar(@args) > 1)
    && (($args[0]->getAttribute('role')  || 'none') eq 'OPEN')
    && (($args[-1]->getAttribute('role') || 'none') eq 'CLOSE')) {
    $oprec = $PREC_SYMBOL; }
  return (join('', map { unimath_nested($_, $iprec); } @args), $oprec); }

our %prefix_prec = ();

sub unimath_prefix {
  my ($op, @args) = @_;
  $op = realize($op) if ref $op;
  return ("", $PREC_SYMBOL) unless $op && @args;
  my $role = (ref $op                     ? getOperatorRole($op) : 'none') || 'none';
  my $prec = (defined $prefix_prec{$role} ? $prefix_prec{$role}  : $PREC_SYMBOL);
  return (join('', unimath_nested($op, 0),
      map { unimath_nested($_, $prec); } @args), $prec); }

# args are XMath nodes
# This is suitable for use as an Apply handler.
our %infix_prec = (
  ADDOP     => $PREC_ADDOP, BINOP      => $PREC_ADDOP,
  MULOP     => $PREC_MULOP, MIDDLE     => $PREC_MULOP,
  COMPOSEOP => $PREC_MULOP, MODIFIEROP => $PREC_MULOP,
  RELOP     => $PREC_RELOP, METARELOP  => $PREC_RELOP, ARROW => $PREC_RELOP,
);

sub unimath_infix {
  my ($op, @args) = @_;
  $op = realize($op) if ref $op;
  return ("", $PREC_SYMBOL) unless $op && @args;
  my $role  = (ref $op                    ? getOperatorRole($op) : 'none') || 'none';
  my $prec  = (defined $infix_prec{$role} ? $infix_prec{$role}   : $PREC_SYMBOL);
  my $opuni = unimath_nested($op, $prec);
  my @items = (unimath_nested(shift(@args), $prec));
  if (scalar(@args) == 0) {    # Infix with 1 arg is presumably Prefix!
    unshift(@items, $opuni); }
  else {
    while (@args) {
      push(@items, $opuni, unimath_nested(shift(@args), $prec)); } }
  return (join('', @items), $prec); }

sub UTF {
  my ($code) = @_;
  return pack('U', $code); }

sub makePlane1Map {
  my ($latin, $GREEK, $greek, $digits) = @_;
  return (
    (map { (UTF(ord('A') + $_) => UTF($latin + $_)) } 0 .. 25),
    (map { (UTF(ord('a') + $_) => UTF($latin + 26 + $_)) } 0 .. 25),
    ($GREEK  ? (map { (UTF(0x0391 + $_)   => UTF($GREEK + $_)) } 0 .. 24) : ()),
    ($greek  ? (map { (UTF(0x03B1 + $_)   => UTF($greek + $_)) } 0 .. 24) : ()),
    ($digits ? (map { (UTF(ord('0') + $_) => UTF($digits + $_)) } 0 .. 9) : ())); }

my %plane1map = (    # CONSTANT
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
    R => "\x{211D}", Z => "\x{2124}" }
);

my %symmetric_roles = (OPEN => 1, CLOSE => 1, MIDDLE => 1, VERTBAR => 1);
# operator content that's stretchy by default [fill-in from operator dictionary!]
# [ grep stretchy ~/src/firefox/res/fonts/mathfont.properties | cut -d . -f 2 ]
my %normally_stretchy = map { $_ => 1 }
  ("(", ")", "[", "]", "{", "}",
  "\x{27E8}", "\x{2308}", "\x{27E6}", "\x{230A}", "\x{27E9}", "\x{2309}", "\x{27E7}", "\x{230B}",
  "\x{2500}", "\x{007C}", "\x{2758}", "\x{21D2}", "\x{2A54}", "\x{2A53}", "\x{21D0}", "\x{21D4}",
  "\x{2950}", "\x{295E}", "\x{21BD}", "\x{2956}", "\x{295F}", "\x{21C1}", "\x{2957}", "\x{2190}",
  "\x{21E4}", "\x{21C6}", "\x{2194}", "\x{294E}", "\x{21A4}", "\x{295A}", "\x{21BC}", "\x{2952}",
  "\x{2199}", "\x{2198}", "\x{2192}", "\x{21E5}", "\x{21C4}", "\x{21A6}", "\x{295B}", "\x{21C0}",
  "\x{2953}", "\x{2196}", "\x{2197}", "\x{2225}", "\x{2016}", "\x{21CC}", "\x{21CB}", "\x{2223}",
  "\x{2294}", "\x{22C3}", "\x{228E}", "\x{22C2}", "\x{2293}", "\x{22C1}", "\x{2211}", "\x{22C3}",
  "\x{228E}", "\x{2A04}", "\x{2A06}", "\x{2232}", "\x{222E}", "\x{2233}", "\x{222F}", "\x{222B}",
  "\x{22C0}", "\x{2210}", "\x{220F}", "\x{22C2}", "\x{2216}", "\x{221A}", "\x{21D3}",
  "\x{27F8}", "\x{27FA}", "\x{27F9}", "\x{21D1}", "\x{21D5}", "\x{2193}", "\x{2913}", "\x{21F5}",
  "\x{21A7}", "\x{2961}", "\x{21C3}", "\x{2959}", "\x{2951}", "\x{2960}", "\x{21BF}", "\x{2958}",
  "\x{27F5}", "\x{27F7}", "\x{27F6}", "\x{296F}", "\x{295D}", "\x{21C2}", "\x{2955}", "\x{294F}",
  "\x{295C}", "\x{21BE}", "\x{2954}", "\x{2191}", "\x{2912}", "\x{21C5}", "\x{2195}", "\x{296E}",
  "\x{21A5}", "\x{02DC}", "\x{02C7}", "\x{005E}", "\x{00AF}", "\x{23DE}", "\x{FE37}", "\x{23B4}",
  "\x{23DC}", "\x{FE35}", "\x{0332}", "\x{23DF}", "\x{FE38}", "\x{23B5}", "\x{23DD}", "\x{FE36}",
  "\x{2225}", "\x{2225}", "\x{2016}", "\x{2016}", "\x{2223}", "\x{2223}", "\x{007C}", "\x{007C}",
  "\x{20D7}", "\x{20D6}", "\x{20E1}", "\x{20D1}", "\x{20D0}", "\x{21A9}", "\x{21AA}", "\x{23B0}",
  "\x{23B1}");
my %default_token_content = (
  MULOP => "\x{2062}", ADDOP => "\x{2064}", PUNCT => "\x{2063}");
# Given an item (string or token element w/attributes) and latexml attributes,
# convert the string to the appropriate unicode (possibly plane1)
# & MathML presentation attributes (mathvariant, mathsize, mathcolor, stretchy)
sub stylizeContent {
  my ($item, %attr) = @_;
  my $iselement = (ref $item) eq 'XML::LibXML::Element';
  my $role      = ($iselement ? $item->getAttribute('role') : 'ID');
  my $font      = ($iselement ? $item->getAttribute('font') : $attr{font})
    || $LaTeXML::MathML::FONT;
  my $text    = (ref $item ? $item->textContent        : $item);
  my $variant = ($font     ? mathvariantForFont($font) : '');
  if ((!defined $text) || ($text eq '')) {    # Failsafe for empty tokens?
    if (my $default = $role && $default_token_content{$role}) {
      $text = $default; }
    else {
      $text = ($iselement ? $item->getAttribute('name') || $item->getAttribute('meaning') || $role : '?');
  } }
  if (my $mapping = $variant && $plane1map{$variant}) {
    $text = join('', map { $$mapping{$_} // $_ } split(//, (defined $text ? $text : ''))); }
  return $text; }

# Some of these equivalences may not be correct,
# in particular, ignoring the "semantics" associated with IPA or Phonetic symbols

my %superscript = (
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
);
my %subscript = (
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
);
# Here's an interesting question:
# How much do we prefer sub/superscipt glyphs over ^{...}, or _{...} ?
# We COULD unmap plane 1 math chars down to plain letters, and then remap them to sub/superscript.
# (maybe only math italic?)
sub unimath_sub {
  my ($op, $base, $script) = @_;
  my $pos    = (ref $op && $op->getAttribute('scriptpos')) || 'post';
  my $pre    = $pos =~ /^pre/;
  my $mid    = $pos =~ /^mid/;
  my $mapped = 0;
  my $ubase  = ($base ? unimath_nested($base, $PREC_SCRIPTOP) : '');
  my ($uscript, $prec) = unimath_internal($script);
  # Possibly convert $uscript to subscript codepoints ??
  if ($mid) { }    # Could try for combining accents?
  else {
    my @scripted = map { $subscript{$_} } split(//, $uscript);
    if (!grep { !defined $_; } @scripted) {    # ALL were mapped?
      $uscript = join('', @scripted); $mapped = 1; } }
  $uscript = '{' . $uscript . '}' if !$mapped && $prec < $PREC_SCRIPTOP;    # Wrap if needed
  return (($pre ? ($mapped ? $uscript : '{_' . $uscript . '}') . $ubase
      : $ubase . ($mapped ? '' : ($mid ? "\x{252C}" : '_')) . $uscript), $PREC_SCRIPTOP); }

sub unimath_sup {
  my ($op, $base, $script) = @_;
  my $pos    = (ref $op && $op->getAttribute('scriptpos')) || 'post';
  my $pre    = $pos =~ /^pre/;
  my $mid    = $pos =~ /^mid/;
  my $mapped = 0;
  my $ubase  = ($base ? unimath_nested($base, $PREC_SCRIPTOP) : '');
  my ($uscript, $prec) = unimath_internal($script);
  # Possibly convert $uscript to superscript codepoints ??
  if ($mid) { }    # Could try for combining accents?
  else {
    my @scripted = map { $superscript{$_} } split(//, $uscript);
    if (!grep { !defined $_; } @scripted) {    # ALL were mapped?
      $uscript = join('', @scripted); $mapped = 1; } }
  $uscript = '{' . $uscript . '}' if !$mapped && $prec < $PREC_SCRIPTOP;    # Wrap if needed
  return (($pre ? ($mapped ? $uscript : '{^' . $uscript . '}') . $ubase
      : $ubase . ($mapped ? '' : ($mid ? "\x{2534}" : '^')) . $uscript), $PREC_SCRIPTOP); }

# The combining chars assciated with the accent chars over/under
our %overaccents = ('^' => "\x{0302}",                                      # \hat,
  UTF(0x5E)  => "\x{0302}",                                                 # \widehat
  "\x{02C7}" => "\x{030C}",                                                 # \check
  '~'        => "\x{303}",
  UTF(0x7E)  => "\x{0303}",                                                 # \tilde, \widetilde
  UTF(0x84)  => "\x{0301}",                                                 # \acute
  UTF(0x60)  => "\x{0300}",                                                 # \grave
  "\x{02D9}" => "\x{0307}",                                                 # \dot
  UTF(0xAB)  => "\x{0308}",                                                 # \ddot
  UTF(0xAF)  => "\x{0304}",                                                 # \bar, \overline
  "\x{2192}" => "\x{20D7}",                                                 # \vec
  "\x{02D8}" => "\x{0306}",                                                 # \breve
  "o"        => "\x{030A}",                                                 # \r
  "\x{02DD}" => "\x{030B}",                                                 # \H
);
our %underaccents = (
  UTF(0xB8) => "\x{0327}",                                                  # \c
  '.'       => "\x{0323}",                                                  # dot below
  UTF(0xAF) => "\x{0331}",                                                  # macron below
  "="       => "\x{0361}",                                                  # \t
  ","       => "\x{0361}",                                                  # lfhook
);
# \overbrace, \underbrace, \overleftarrow ??
sub unimath_overaccent {
  my ($op, $base) = @_;
  my $acc  = $op->textContent;
  my $cacc = $acc && $overaccents{$acc};
  my ($ubase, $uprec) = unimath_internal($base);
  $ubase = '(' . $ubase . ')' if length($ubase) > 1;
  return ($ubase . ($cacc ? $cacc : "\x{252C}" . $acc), $PREC_SCRIPTOP); }

sub unimath_underaccent {
  my ($op, $base) = @_;
  my $acc  = $op->textContent;
  my $cacc = $acc && $underaccents{$acc};
  my ($ubase, $uprec) = unimath_internal($base);
  $ubase = '(' . $ubase . ')' if length($ubase) > 1;    # maybe NBSP, too???
  return ($ubase . ($cacc ? $cacc : "\x{252C}" . $acc), $PREC_SCRIPTOP); }

# Handle text contents.
# We probably should pass this back to the same code used in CrossRef.
# But also, there's the question of what to do with nested math?
# Is that even allowable in UnicodeMath?
sub unimath_text {
  my (@nodes) = @_;
  return ('"' . join('', map { (ref $_ ? $_->textContent : $_); } @nodes) . '"', $PREC_SYMBOL); }

sub unimath_error {
  return unimath_text('ERROR ', @_); }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Tranlators
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

DefUnicodeMath('Apply:?:?',             \&unimath_prefix);
DefUnicodeMath('Apply:ADDOP:?',         \&unimath_infix);
DefUnicodeMath('Apply:MULOP:?',         \&unimath_infix);
DefUnicodeMath('Apply:BINOP:?',         \&unimath_infix);
DefUnicodeMath('Apply:RELOP:?',         \&unimath_infix);
DefUnicodeMath('Apply:METARELOP:?',     \&unimath_infix);
DefUnicodeMath('Apply:ARROW:?',         \&unimath_infix);
DefUnicodeMath('Apply:COMPOSEOP:?',     \&unimath_infix);
DefUnicodeMath("Apply:DIFFOP:?",        \&unimath_prefix);
DefUnicodeMath('Apply:BIGOP:?',         \&unimath_prefix);
DefUnicodeMath('Apply:INTOP:?',         \&unimath_prefix);
DefUnicodeMath('Apply:SUMOP:?',         \&unimath_prefix);
DefUnicodeMath('Apply:?:formulae',      \&unimath_map);
DefUnicodeMath('Apply:?:multirelation', \&unimath_args);
DefUnicodeMath('Apply:?:limit-from',    \&unimath_prefix);
DefUnicodeMath('Apply:?:annotated',     \&unimath_prefix);

DefUnicodeMath('Apply:FRACOP:?', sub {
    my ($op, $num, $den, @more) = @_;
    my $thickness = $op->getAttribute('thickness');
    if (defined $thickness) {    # Hmm? maybe not even a fraction?
      return ('(' . unimath_nested($num, 0) . UTF(0xA6) . unimath_nested($den, 0) . ')', $PREC_SYMBOL); }
    else {
      return (unimath_nested($num, $PREC_MULOP) . '/' . unimath_nested($den, $PREC_MULOP), 1); } });

DefUnicodeMath('Apply:MODIFIEROP:?',    \&unimath_infix);
DefUnicodeMath('Apply:MIDDLE:?',        \&unimath_infix);
DefUnicodeMath('Apply:SUPERSCRIPTOP:?', \&unimath_sup);
DefUnicodeMath('Apply:SUBSCRIPTOP:?',   \&unimath_sub);
# These could search for candidate combining chars?
DefUnicodeMath('Apply:OVERACCENT:?',  \&unimath_overaccent);
DefUnicodeMath('Apply:UNDERACCENT:?', \&unimath_underaccent);

DefUnicodeMath('Apply:POSTFIX:?', sub {    # Reverse presentation, no @apply
    my ($op) = unimath_internal($_[0]);
    return (unimath_nested($_[1], $PREC_MULOP) . $op, $PREC_MULOP); });

DefUnicodeMath('Apply:?:square-root', sub {
    return ("\x{221A}" . unimath_nested($_[1], $PREC_MULOP), $PREC_MULOP); });
DefUnicodeMath('Apply:?:nth-root', sub {
    # Could convert to \x{221B} for cube, \x{221C} for quartic
    my ($n) = unimath_innternal($_[2]);
    my $op = ($n eq '2' ? "\x{221A}"
      : ($n eq '3' ? "\x{221B}"
        : ($n eq '4' ? "\x{221C}"
          : "\\root " . $n . "\\of")));
    return ($op . unimath_nested($_[1], $PREC_MULOP), $PREC_MULOP); });
DefUnicodeMath('Apply:ENCLOSE:?', sub {
    my ($op, $base) = @_;
    return (unimath_nested($base, $PREC_SYMBOL), $PREC_SYMBOL); });

# ================================================================================
# cfrac! Ugh!
DefUnicodeMath('Apply:?:continued-fraction', sub {
    return unimath_error("continued fraction"); });

#================================================================================
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Post::UnicodeMath> - Post-Processing module for converting math to UnicodeMath.

=head1 SYNOPSIS

C<LaTeXML::Post::UnicodeMath> converts math into UnicodeMath.
It should be usable as a primary math format (alone), or as a secondary format.
This module can also be used to convert ltx:XMath expressions into plain Unicode strings
for use in attributes.

=head1 DESCRIPTION

To be done.

=cut
