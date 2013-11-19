# /=====================================================================\ #
# |  LaTeXML::Font                                                      | #
# | Representaion of Fonts                                              | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Font;
use strict;
use warnings;
use LaTeXML::Global;
use base qw(LaTeXML::Object);

my $DEFFAMILY     = 'serif';      # [CONSTANT]
my $DEFSERIES     = 'medium';     # [CONSTANT]
my $DEFSHAPE      = 'upright';    # [CONSTANT]
my $DEFSIZE       = 'normal';     # [CONSTANT]
my $DEFCOLOR      = 'black';      # [CONSTANT]
my $DEFBACKGROUND = 'white';      # [CONSTANT]
my $DEFOPACITY    = '1';          # [CONSTANT]
my $DEFENCODING   = 'OT1';        # [CONSTANT]

# NOTE:  Would it make sense to allow compnents to be `inherit' ??

sub new {
  my ($class, %options) = @_;
  my $family   = $options{family};
  my $series   = $options{series};
  my $shape    = $options{shape};
  my $size     = $options{size};
  my $color    = $options{color}; $color = $color->toHex if ref $color;
  my $bg       = $options{background}; $bg = $bg->toHex if ref $bg;
  my $opacity  = $options{opacity};
  my $encoding = $options{encoding};
  return $class->new_internal($family, $series, $shape, $size, $color, $bg, $opacity, $encoding); }

sub new_internal {
  my ($class, @components) = @_;
  return bless [@components], $class; }

sub default {
  my ($self) = @_;
  return $self->new_internal($DEFFAMILY, $DEFSERIES, $DEFSHAPE, $DEFSIZE,
    $DEFCOLOR, $DEFBACKGROUND, $DEFOPACITY,
    $DEFENCODING); }

# Accessors
sub getFamily     { my ($self) = @_; return $$self[0]; }
sub getSeries     { my ($self) = @_; return $$self[1]; }
sub getShape      { my ($self) = @_; return $$self[2]; }
sub getSize       { my ($self) = @_; return $$self[3]; }
sub getColor      { my ($self) = @_; return $$self[4]; }
sub getBackground { my ($self) = @_; return $$self[5]; }
sub getOpacity    { my ($self) = @_; return $$self[6]; }
sub getEncoding   { my ($self) = @_; return $$self[7]; }

sub toString {
  my ($self) = @_;
  return "Font[" . join(',', map { (defined $_ ? $_ : '*') } @{$self}) . "]"; }

sub stringify {
  my ($self) = @_;
  return $self->toString; }

sub equals {
  my ($self, $other) = @_;
  return (defined $other) && ((ref $self) eq (ref $other))
    && (join('|', map { (defined $_ ? $_ : '*') } @$self)
    eq join('|', map { (defined $_ ? $_ : '*') } @$other)); }

sub match {
  my ($self, $other) = @_;
  return 1 unless defined $other;
  return 0 unless (ref $self) eq (ref $other);
  my @comp  = @$self;
  my @ocomp = @$other;
  # If any components are defined in both fonts, they must be equal.
  while (@comp) {
    my $c  = shift @comp;
    my $oc = shift @ocomp;
    return 0 if (defined $c) && (defined $oc) && ($c ne $oc); }
  return 1; }

sub makeConcrete {
  my ($self, $concrete) = @_;
  my ($family,  $series,  $shape,  $size,  $color,  $bg,  $opacity,  $encoding)  = @$self;
  my ($ofamily, $oseries, $oshape, $osize, $ocolor, $obg, $oopacity, $oencoding) = @$concrete;
  return (ref $self)->new_internal(
    $family || $ofamily, $series || $oseries, $shape || $oshape, $size || $osize,
    $color || $ocolor, $bg || $obg, (defined $opacity ? $opacity : $oopacity),
    $encoding || $oencoding); }

sub merge {
  my ($self, %options) = @_;
  my $family   = $options{family}     // $$self[0];
  my $series   = $options{series}     // $$self[1];
  my $shape    = $options{shape}      // $$self[2];
  my $size     = $options{size}       // $$self[3];
  my $color    = $options{color}      // $$self[4];
  my $bg       = $options{background} // $$self[5];
  my $opacity  = $options{opacity}    // $$self[6];
  my $encoding = $options{encoding}   // $$self[7];
  $color = $color->toHex if ref $color;
  $bg    = $bg->toHex    if ref $bg;
  return (ref $self)->new_internal($family, $series, $shape, $size, $color, $bg, $opacity, $encoding); }

# Really only applies to Math Fonts, but that should be handled elsewhere; We punt here.
sub specialize {
  my ($self, $string) = @_;
  return $self; }

sub isDiff {
  my ($x, $y) = @_;
  return (defined $x) && (!(defined $y) || ($x ne $y)); }

# Return a hash of the differences in font, size and color
# [does encoding play a role here?]
# Note that this returns a hash of Fontable.attributes & Colorable.attributes,
# NOT the font keywords!!!
sub relativeTo {
  my ($self, $other) = @_;
  my ($fam,  $ser,  $shp,  $siz,  $col,  $bkg,  $opa,  $enc)  = @$self;
  my ($ofam, $oser, $oshp, $osiz, $ocol, $obkg, $oopa, $oenc) = @$other;
  $fam  = 'serif' if $fam  && ($fam eq 'math');
  $ofam = 'serif' if $ofam && ($ofam eq 'math');
  my @diffs = (
    (isDiff($fam, $ofam) ? ($fam) : ()),
    (isDiff($ser, $oser) ? ($ser) : ()),
    (isDiff($shp, $oshp) ? ($shp) : ()));
  return (
    (@diffs ? (font => join(' ', @diffs)) : ()),
    (isDiff($siz, $osiz) ? (fontsize        => $siz) : ()),
    (isDiff($col, $ocol) ? (color           => $col) : ()),
    (isDiff($bkg, $obkg) ? (backgroundcolor => $bkg) : ()),
    (isDiff($opa, $oopa) ? (opacity         => $opa) : ()),
    ); }

sub distance {
  my ($self, $other) = @_;
  my ($fam,  $ser,  $shp,  $siz,  $col,  $bkg,  $opa,  $enc)  = @$self;
  my ($ofam, $oser, $oshp, $osiz, $ocol, $obkg, $oopa, $oenc) = @$other;
  $fam  = 'serif' if $fam  && ($fam eq 'math');
  $ofam = 'serif' if $ofam && ($ofam eq 'math');
  return
    (isDiff($fam, $ofam) ? 1 : 0)
    + (isDiff($ser, $oser) ? 1 : 0)
    + (isDiff($shp, $oshp) ? 1 : 0)
    + (isDiff($siz, $osiz) ? 1 : 0)
    + (isDiff($col, $ocol) ? 1 : 0)
    + (isDiff($bkg, $obkg) ? 1 : 0)
    + (isDiff($opa, $oopa) ? 1 : 0)
##  + (isDiff($enc,$oenc)  ? 1 : 0)
    ; }

# This matches fonts when both are converted to strings (toString),
# such as when they are set as attributes.
# This accumulates regular expressions used by match_font
# (which, in turn, is used in various XPath searches!)
# It is NOT really Daemon safe....
# Need to work out how to do this and/or cache it in STATE????
our %FONT_REGEXP_CACHE = ();

sub match_font {
  my ($font1, $font2) = @_;
  my $regexp = $FONT_REGEXP_CACHE{$font1};
  if (!$regexp) {
    if ($font1 =~ /^Font\[(.*)\]$/) {
      my @comp = split(',', $1);
      my $re = '^Font\['
        . join(',', map { ($_ eq '*' ? "[^,]+" : "\Q$_\E") } @comp)
        . '\]$';
      print STDERR "\nCreating re for \"$font1\" => $re\n";
      $regexp = $FONT_REGEXP_CACHE{$font1} = qr/$re/; } }
  return $font2 =~ /$regexp/; }

sub font_match_xpaths {
  my ($font) = @_;
  if ($font =~ /^Font\[(.*)\]$/) {
    my @comps = split(',', $1);
    my ($frag, @frags) = ();
    for (my $i = 0 ; $i <= $#comps ; $i++) {
      my $comp = $comps[$i];
      if ($comp eq '*') {
        push(@frags, $frag) if $frag;
        $frag = undef; }
      else {
        my $post = ($i == $#comps ? ']' : ',');
        if ($frag) {
          $frag .= $comp . $post; }
        else {
          $frag = ($i == 0 ? 'Font[' : ',') . $comp . $post; } } }
    push(@frags, $frag) if $frag;
    return join(' and ', '@_font',
      map { "contains(\@_font,'$_')" } @frags); } }

# Presumably a text font is "sticky", if used in math?
sub isSticky { return 1; }

#**********************************************************************
package LaTeXML::MathFont;
use strict;
use LaTeXML::Global;
use base qw(LaTeXML::Font);

my $MDEFFAMILY     = 'serif';      # [CONSTANT]
my $MDEFSERIES     = 'medium';     # [CONSTANT]
my $MDEFSHAPE      = 'upright';    # [CONSTANT]
my $MDEFSIZE       = 'normal';     # [CONSTANT]
my $MDEFCOLOR      = 'black';      # [CONSTANT]
my $MDEFBACKGROUND = 'white';      # [CONSTANT]
my $MDEFOPACITY    = '1';          # [CONSTANT]

sub new {
  my ($class, %options) = @_;
  my $family   = $options{family};
  my $series   = $options{series};
  my $shape    = $options{shape};
  my $size     = $options{size};
  my $color    = $options{color}; $color = $color->toHex if ref $color;
  my $bg       = $options{background}; $bg = $bg->toHex if ref $bg;
  my $opacity  = $options{opacity};
  my $encoding = $options{encoding};
##  my $forcebold  = $options{forcebold} || 0;
##  my $forceshape = $options{forceshape} || 0;
  my $forcebold  = $options{forcebold};
  my $forceshape = $options{forceshape};
  return $class->new_internal(
    $family, $series, $shape, $size,
    $color, $bg, $opacity,
    $encoding, $forcebold, $forceshape); }

sub default {
  my ($self) = @_;
  return $self->new_internal('math', $MDEFSERIES, 'italic', $MDEFSIZE,
    $MDEFCOLOR, $MDEFBACKGROUND, $MDEFOPACITY,
    undef, undef, undef); }

sub isSticky {
  my ($self) = @_;
  return $$self[0] && ($$self[0] =~ /^(?:serif|sansserif|typewriter)$/); }

sub merge {
  my ($self, %options) = @_;
  my $family     = $options{family}     // $$self[0];
  my $series     = $options{series}     // $$self[1];
  my $shape      = $options{shape}      // $$self[2];
  my $size       = $options{size}       // $$self[3];
  my $color      = $options{color}      // $$self[4];
  my $bg         = $options{background} // $$self[5];
  my $opacity    = $options{opacity}    // $$self[6];
  my $encoding   = $options{encoding}   // $$self[7];
  my $forcebold  = $options{forcebold}  // $$self[8];
  my $forceshape = $options{forceshape} // $$self[9];
  $color = $color->toHex if ref $color;
  $bg    = $bg->toHex    if ref $bg;
  # In math, setting any one of these, resets the others to default.
  $family = $MDEFFAMILY if !$options{family} && ($options{series} || $options{shape});
  $series = $MDEFSERIES if !$options{series} && ($options{family} || $options{shape});
  $shape  = $MDEFSHAPE  if !$options{shape}  && ($options{family} || $options{series});
  return (ref $self)->new_internal($family, $series, $shape, $size,
    $color,    $bg,        $opacity,
    $encoding, $forcebold, $forceshape); }

# Instanciate the font for a particular class of symbols.
# NOTE: This works in `normal' latex, but probably needs some tunability.
# Depending on the fonts being used, the allowable combinations may be different.
# Getting the font right is important, since the author probably
# thinks of the identity of the symbols according to what they SEE in the printed
# document.  Even though the markup might seem to indicate something else...

# Use Unicode properties to determine font merging.
sub specialize {
  my ($self, $string) = @_;
  return $self unless defined $string;
  my ($family, $series, $shape, $size, $color, $bg, $opacity,
    $encoding, $forcebold, $forceshape) = @$self;
  $series = 'bold' if $forcebold;
  if (($string =~ /^\p{Latin}$/) && ($string =~ /^\p{L}$/)) {    # Latin Letter
##    print STDERR "Letter" if $LaTeXML::Font::DEBUG;
    $shape = 'italic' if !$shape && !$family; }
  elsif ($string =~ /^\p{Greek}$/) {                             # Single Greek character?
    if ($string =~ /^\p{Lu}$/) {                                 # Uppercase
##      print STDERR "Greek Upper" if $LaTeXML::Font::DEBUG;
      if (!$family || ($family eq 'math')) {
        $family = $MDEFFAMILY;
        $shape = $MDEFSHAPE if $shape && ($shape ne $MDEFSHAPE); } }    # if ANY shape, must be default
    else {    # Lowercase
##      print STDERR "Greek Lower" if $LaTeXML::Font::DEBUG;
      $family = $MDEFFAMILY if !$family || ($family ne $MDEFFAMILY);
      $shape  = 'italic'    if !$shape  || !$forceshape;               # always ?
      if ($forcebold) { $series = 'bold'; }
      elsif ($series && ($series ne $MDEFSERIES)) { $series = $MDEFSERIES; } } }
  elsif ($string =~ /^\p{N}$/) {                                       # Digit
##    print STDERR "Digit" if $LaTeXML::Font::DEBUG;
    if (!$family || ($family eq 'math')) {
      $family = $MDEFFAMILY;
      $shape  = $MDEFSHAPE; } }                                        # defaults, always.
  else {                                                               # Other Symbol
##    print STDERR "Symbol" if $LaTeXML::Font::DEBUG;
    $family = $MDEFFAMILY;
    $shape  = $MDEFSHAPE;                                              # defaults, always.
    if ($forcebold) { $series = 'bold'; }
    elsif ($series && ($series ne $MDEFSERIES)) { $series = $MDEFSERIES; } }

  return (ref $self)->new_internal($family, $series, $shape, $size,
    $color,    $bg,        $opacity,
    $encoding, $forcebold, $forceshape); }

#**********************************************************************
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Font> - representation of fonts,
along with the specialization C<LaTeXML::MathFont>.

=head1 DESCRIPTION

This module defines Font objects.
I'm not completely happy with the arrangement, or
maybe just the use of it, so I'm not going to document extensively at this point.

C<LaTeXML::Font> and C<LaTeXML::MathFont> represent fonts 
(the latter, fonts in math-mode, obviously) in LaTeXML. 

The attributes are

 family : serif, sansserif, typewriter, caligraphic,
          fraktur, script
 series : medium, bold
 shape  : upright, italic, slanted, smallcaps
 size   : tiny, footnote, small, normal, large,
          Large, LARGE, huge, Huge
 color  : any named color, default is black

They are usually merged against the current font, attempting to mimic the,
sometimes counter-intuitive, way that TeX does it,  particularly for math

=head2 C<LaTeXML::MathFont>

=begin latex

\label{LaTeXML::MathFont}

=end latex

C<LaTeXML::MathFont> supports C<$font->specialize($string);> for
computing a font reflecting how the specific C<$string> would be printed when
C<$font> is active; This (attempts to) handle the curious ways that lower case
greek often doesn't get a different font.  In particular, it recognizes the
following classes of strings: single latin letter, single uppercase greek character,
single lowercase greek character, digits, and others.


=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
