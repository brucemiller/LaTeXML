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
use LaTeXML::Util::Unicode;
use LaTeXML::Post;
use List::Util qw(max);
use base qw(LaTeXML::Post::MathProcessor);
use base qw(Exporter);
our @EXPORT = qw( &unicodemath);

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

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Top level
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
our $lxMimeType = 'application/x-unicodemath';    # !?!?!?!?

sub convertNode {
  my ($self, $doc, $xmath, $style) = @_;
  my $math = $xmath->parentNode;
  my $uni  = $math && isElementNode($math) && unicodemath($doc, $math);
  return { processor => $self, encoding => $lxMimeType, mimetype => $lxMimeType,
    string => $uni }; }

sub rawIDSuffix {
  return '.muni'; }

sub getQName {
  my ($node) = @_;
  return $LaTeXML::Post::DOCUMENT->getQName($node); }

# Separate interface to convert single Math element to Unicode
sub unicodemath {
  my ($doc, $node) = @_;
  local $LaTeXML::Post::DOCUMENT = $doc;
  my ($uni, $prec) = unimath_internal($node);
  return $uni; }

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
# and return an unicode string & precedence

our $unimath_converters = {};

sub DefUnicodeMath {
  my ($key, $converter) = @_;
  $$unimath_converters{$key} = $converter if $converter;
  return; }

sub lookupConverter {
  my ($mode, $role, $name) = @_;
  $name = '?' unless $name;
  $role = '?' unless $role;
  return $$unimath_converters{"$mode:$role:$name"}
    || $$unimath_converters{"$mode:?:$name"}
    || $$unimath_converters{"$mode:$role:?"}
    || $$unimath_converters{"$mode:?:?"}; }

our $PREC_RELOP    = 1;
our $PREC_ADDOP    = 2;
our $PREC_MULOP    = 3;
our $PREC_SCRIPTOP = 4;
our $PREC_SYMBOL   = 10;
our $PREC_UNKNOWN  = 10;

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Support functions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Convert to string, return string and precedence
sub unimath_internal {
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
      return &{ lookupConverter('Apply', getOperatorRole($rop), $rop->getAttribute('meaning'))
      }($op, @args); } }
  elsif ($tag eq 'ltx:XMTok') {
    my $m = $node->getAttribute('meaning') || 'none';
    return ($m eq 'absent' ? '' : stylizeContent($node), $PREC_SYMBOL); }
  elsif ($tag eq 'ltx:XMHint') {
    ## Presumably would output some space here, except that space is default end delimiter of expr.
    return ('', 0); }
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
  my $text    = (ref $item ? $item->textContent         : $item);
  my $variant = ($font     ? unicode_mathvariant($font) : '');
  if ((!defined $text) || ($text eq '')) {    # Failsafe for empty tokens?
    if (my $default = $role && $default_token_content{$role}) {
      $text = $default; }
    else {
      $text = ($iselement ? $item->getAttribute('name') || $item->getAttribute('meaning') || $role : '?');
  } }
  my $u_text = $variant && unicode_convert($text, $variant);
  if ((defined $u_text) && ($u_text ne '')) {    # didn't remap the text ? Keep text & variant
    $text = $u_text; }
  return $text; }

# Some of these equivalences may not be correct,
# in particular, ignoring the "semantics" associated with IPA or Phonetic symbols
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
    my $u_uscript = unicode_convert($uscript, 'subscript');
    if (defined $u_uscript) {
      $uscript = $u_uscript; $mapped = 1; } }
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
    my $u_uscript = unicode_convert($uscript, 'superscript');
    if (defined $u_uscript) {
      $uscript = $u_uscript; $mapped = 1; } }
  $uscript = '{' . $uscript . '}' if !$mapped && $prec < $PREC_SCRIPTOP;    # Wrap if needed
  return (($pre ? ($mapped ? $uscript : '{^' . $uscript . '}') . $ubase
      : $ubase . ($mapped ? '' : ($mid ? "\x{2534}" : '^')) . $uscript), $PREC_SCRIPTOP); }

# The combining chars assciated with the accent chars over/under
# Perhaps these tables should be moved to LaTeXML::Util::Unicode? (later...)
our %overaccents = ('^' => "\x{0302}",    # \hat,
  UTF(0x5E)  => "\x{0302}",               # \widehat
  "\x{02C7}" => "\x{030C}",               # \check
  '~'        => "\x{303}",
  UTF(0x7E)  => "\x{0303}",               # \tilde, \widetilde
  UTF(0x84)  => "\x{0301}",               # \acute
  UTF(0x60)  => "\x{0300}",               # \grave
  "\x{02D9}" => "\x{0307}",               # \dot
  UTF(0xAB)  => "\x{0308}",               # \ddot
  UTF(0xAF)  => "\x{0304}",               # \bar, \overline
  "\x{2192}" => "\x{20D7}",               # \vec
  "\x{02D8}" => "\x{0306}",               # \breve
  "o"        => "\x{030A}",               # \r
  "\x{02DD}" => "\x{030B}",               # \H
);
our %underaccents = (
  UTF(0xB8) => "\x{0327}",                # \c
  '.'       => "\x{0323}",                # dot below
  UTF(0xAF) => "\x{0331}",                # macron below
  "="       => "\x{0361}",                # \t
  ","       => "\x{0361}",                # lfhook
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
    my ($n) = unimath_internal($_[2]);
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

=over 4

=item C<< $string = unicodemath($document,$mathnode); >>

Convert the given math node into UnicodeMath.

=back

=cut
