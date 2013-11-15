# /=====================================================================\ #
# |  LaTeXML::Color, LaTeXML::Color::rgb,...                            | #
# | Digested objects produced in the Stomack                            | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Color;
use strict;
use warnings;
use LaTeXML::Global;
use base qw(LaTeXML::Object);

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Color objects; objects representing color in "arbitrary" color models
# We'd like to provide a set of "core" color models (rgb,cmy,cmyk,hsb)
# and allow derived color models (with scaled ranges, or whatever; see xcolor).
# There is some awkwardness in that we'd like to support the core models
# directly with built-in code, but support derived models that possibly
# are defined in terms of macros defined as part of a style file.
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Publicly exported interface?

# This should go away...
# Convert a Color this to LaTeXML's usable final color.
# This could evolve into the "standard" method for converting colors
# to the target, and might allow XML with an alternate color encoding
# besides the hex form.  Perhaps also could deal with svg, better?
sub UseColor {
  my ($color) = @_;
  # Apply color mask, if any. (a bit too xcolor specific)
  if ($STATE->lookupValue('Boolean:maskcolors')) {
    if (my $mask = $STATE->lookupValue('color_mask')) {
      $color = $color->convert($mask->model)->multiply($mask->components); } }
  return $color->rgb->toHex; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Color Objects

sub new {
  my ($class, @components) = @_;
  my $model;
  if (ref $class) { $model = $class->model; $class = ref $class; }
  else            { $model = $class; $model =~ s/^LaTeXML::Color:://; }
  if (('LaTeXML::Color::' . $model)->can('isCore')) { # All core models have components in interval [0...1] !!!!
                                                      # Should we truncate to the interval?
##    @components = map( ($_ < 0 ? 0 : ($_ > 1 ? 1 : $_)), @components);
    # Should we avoid absurd "precisions" ?
##    @components = map( int($_*10000+0.5)/10000, @components);
  }
  elsif (!$STATE->lookupValue('derived_color_model_' . $model)) {
    Error('unexpected', $model, undef, "Unrecognized color model '$model'"); }
  return bless [$model, @components], $class; }

sub model {
  my ($self) = @_;
  return $$self[0]; }

sub components {
  my ($self) = @_;
  my ($m, @comp) = @$self;
  return @comp; }

# Convert a color to another model
sub convert {
  my ($self, $tomodel) = @_;
  if ($self->model eq $tomodel) {    # Already the correct model
    return $self; }
  elsif (('LaTeXML::Color::' . $tomodel)->can('isCore')) {    # target must be core model
    return $self->toCore->$tomodel; }
  elsif (my $data = $STATE->lookupValue('derived_color_model_' . $tomodel)) { # Ah, target is a derived color
    my $coremodel   = $$data[0];
    my $convertfrom = $$data[2];
    return &{$convertfrom}($self->$coremodel); }
  else {
    Error('unexpected', $tomodel, undef, "Unrecognized color model '$tomodel'");
    return $self; } }

sub toCore {
  my ($self) = @_;
  my $model = $$self[0];
  if (my $data = $STATE->lookupValue('derived_color_model_' . $model)) {
    my $convertto = $$data[1];
    return &{$convertto}($self); }
  else {
    Error('unexpected', $self->model, undef, "Color is not in valid model '$model'");
    return Black; } }

sub toHex {
  my ($self) = @_;
  return $self->rgb->toHex; }

#======================================================================
# By default, just complement components (works for rgb, cmy, gray)
sub complement {
  my ($self) = @_;
  return $self->new(map { 1 - $_ } $self->components); }

# Mix $self*$fraction + $color*(1-$fraction)
sub mix {
  my ($self, $color, $fraction) = @_;
  $color = $color->convert($self->model) unless $self->model eq $color->model;
  my @a = $self->components;
  my @b = $color->components;
  return $self->new(map { $fraction * $a[$_] + (1 - $fraction) * $b[$_] } 0 .. $#a); }

sub add {
  my ($self, $color) = @_;
  $color = $color->convert($self->model) unless $self->model eq $color->model;
  my @a = $self->components;
  my @b = $color->components;
  return $self->new(map { $a[$_] + $b[$_] } 0 .. $#a); }

# The next 2 methods multiply the components of a color by some value(s)
# This assumes that such a thing makes sense in the given model, for some purpose.
# It may be that the components should be truncated to 1 (or some other max?)

# Multiply all components by a constant
sub scale {
  my ($self, $m) = @_;
  return $self->new(map { $m * $_ } $self->components); }

# Multiply by a vector (must have same number of components)
# This may or may not make sense for any given color model or purpose.
sub multiply {
  my ($self, @m) = @_;
  my @c = $self->components;
  if (scalar(@m) != scalar(@c)) {
    Error('misdefined', 'multiply', "Multiplying color components by wrong number of parts",
      "The color is " . ToString($self) . " while the multipliers are " . join(',', @m));
    return $self; }
  else {
    return $self->new(map { $c[$_] * $m[$_] } 0 .. $#c); } }

sub toString {
  my ($self) = @_;
  my ($model, @comp) = @$self;
  return $model . "(" . join(',', @comp) . ")"; }

#======================================================================
package LaTeXML::Color::CoreColor;
use base qw(LaTeXML::Color);
use LaTeXML::Global;

# Convert the color to a core model (it already is!)
sub toCore { my ($self) = @_; return $self; }
sub isCore { return 1; }

#======================================================================
# rgb: (red,green,blue) each in range [0,1]
package LaTeXML::Color::rgb;
use base qw(LaTeXML::Color::CoreColor);
use LaTeXML::Global;

sub rgb { my ($self) = @_; return $self; }
# Convert to cmy, cmyk,
sub cmy { my ($self) = @_; return LaTeXML::Color::cmy->new(1 - $$self[1], 1 - $$self[2], 1 - $$self[3]); }
sub cmyk { my ($self) = @_; return $self->cmy->cmyk; }

sub gray {
  my ($self) = @_;
  return LaTeXML::Color::gray->new(0.3 * $$self[1] + 0.59 * $$self[2] + 0.11 * $$self[3]); }

# See Section 6.3.1 in xcolor documentation Dr.Uwe Kern; xcolor.pdf
sub Phi {
  my ($x, $y, $z, $u, $v) = @_;
  return LaTeXML::Color::hsb->new(($u * ($x - $z) + $v * ($x - $y)) / (6 * ($x - $z)), ($x - $z) / $x, $x); }

sub hsb {
  my ($self) = @_;
  my ($m, $r, $g, $b) = @$self;
  my $i = 4 * ($r >= $g) + 2 * ($g >= $b) + ($b >= $r);
  if    ($i == 1) { return Phi($b, $g, $r, 3, 1); }
  elsif ($i == 2) { return Phi($g, $r, $b, 1, 1); }
  elsif ($i == 3) { return Phi($g, $b, $r, 3, -1); }
  elsif ($i == 4) { return Phi($r, $b, $g, 5, 1); }
  elsif ($i == 5) { return Phi($b, $r, $g, 5, -1); }
  elsif ($i == 6) { return Phi($r, $g, $b, 1, -1); }
  elsif ($i == 7) { return LaTeXML::Color::hsb->new(0, 0, $b); } }

my @hex = qw(0 1 2 3 4 5 6 7 8 9 A B C D E F);
sub hex2 { my ($n) = @_; return $hex[int($n / 16)] . $hex[$n % 16]; }

sub toHex {
  my ($self) = @_;
  my ($model, $r, $g, $b) = @$self;
  return '#' . hex2(int($r * 255 + 0.5)) . hex2(int($g * 255 + 0.5)) . hex2(int($b * 255 + 0.5)); }

#======================================================================
package LaTeXML::Color::cmy;
use base qw(LaTeXML::Color::CoreColor);
use LaTeXML::Global;

sub cmy { my ($self) = @_; return $self; }
sub rgb { my ($self) = @_; return LaTeXML::Color::rgb->new(1 - $$self[1], 1 - $$self[2], 1 - $$self[3]); }
sub hsb { my ($self) = @_; return $self->rgb->hsb; }

sub gray {
  my ($self) = @_;
  return LaTeXML::Color::gray->new(1 - (0.3 * $$self[1] + 0.59 * $$self[2] + 0.11 * $$self[3])); }

sub cmyk {
  my ($self) = @_;
  my ($model, $c, $m, $y) = @$self;
  # These beta parameters are linear coefficients for "undercolor-removal", and "black-generation"
  # In xcolor, they could come from \adjustUCRBG
  my ($bc, $bm, $by, $bk) = (1, 1, 1, 1);
  my $k = min($c, min($m, $y));
  return LaTeXML::Color::cmyk->new(min(1, max(0, $c - $bc * $k)),
    min(1, max(0, $m - $bm * $k)),
    min(1, max(0, $y - $by * $k)),
    $bk * $k); }

#======================================================================
package LaTeXML::Color::cmyk;
use base qw(LaTeXML::Color::CoreColor);
use LaTeXML::Global;

sub cmyk { my ($self) = @_; return $self; }

sub cmy {
  my ($self) = @_;
  my ($model, $c, $m, $y, $k) = @$self;
  return LaTeXML::Color::cmy->new(min(1, $c + $k), min(1, $m + $k), min(1, $y + $k)); }
sub rgb { my ($self) = @_; return $self->cmy->rgb; }
sub hsb { my ($self) = @_; return $self->cmy->hsb; }

sub gray {
  my ($self) = @_;
  my ($model, $c, $m, $y, $k) = @$self;
  return LaTeXML::Color::gray->new(1 - min(1, 0.3 * $c + 0.59 * $m + 0.11 * $y + $k)); }

sub complement { my ($self) = @_; return $self->cmy->complement->cmyk; }

#======================================================================
package LaTeXML::Color::hsb;
use base qw(LaTeXML::Color::CoreColor);
use LaTeXML::Global;

sub hsb { my ($self) = @_; return $self; }

sub rgb {
  my ($self) = @_;
  my ($model, $h, $s, $b) = @$self;
  my $i = int(6 * $h);
  my $f = 6 * $h - $i;
  my $u = $b * (1 - $s * (1 - $f));
  my $v = $b * (1 - $s * $f);
  my $w = $b * (1 - $s);
  if    ($i == 0) { return LaTeXML::Color::rgb->new($b, $u, $w); }
  elsif ($i == 1) { return LaTeXML::Color::rgb->new($v, $b, $w); }
  elsif ($i == 2) { return LaTeXML::Color::rgb->new($w, $b, $u); }
  elsif ($i == 3) { return LaTeXML::Color::rgb->new($w, $v, $b); }
  elsif ($i == 4) { return LaTeXML::Color::rgb->new($u, $w, $b); }
  elsif ($i == 5) { return LaTeXML::Color::rgb->new($b, $w, $v); }
  elsif ($i == 6) { return LaTeXML::Color::rgb->new($b, $w, $w); } }

sub cmy  { my ($self) = @_; return $self->rgb->cmy; }
sub cmyk { my ($self) = @_; return $self->rgb->cmyk; }
sub gray { my ($self) = @_; return $self->rgb->gray; }

sub complement {
  my ($self) = @_;
  my ($h, $s, $b) = $self->components;
  my $hp = ($h < 0.5 ? $h + 0.5 : $h - 0.5);
  my $bp = 1 - $b * (1 - $s);
  my $sp = ($bp == 0 ? 0 : $b * $s / $bp);
  return $self->new($hp, $sp, $bp); }

sub mix {
  my ($self, $color, $fraction) = @_;
  # I don't quite follow what Kern's saying, on a quick read,
  # so we'll punt by doing the conversion in rgb space, then converting back.
  return $self->rgb->mix($color, $fraction)->hsb; }

#======================================================================
package LaTeXML::Color::gray;
use base qw(LaTeXML::Color::CoreColor);
use LaTeXML::Global;

sub gray { my ($self) = @_; return $self; }
sub rgb { my ($self) = @_; return LaTeXML::Color::rgb->new($$self[1], $$self[1], $$self[1]); }
sub cmy { my ($self) = @_; return LaTeXML::Color::cmy->new(1 - $$self[1], 1 - $$self[1], 1 - $$self[1]); }
sub cmyk { my ($self) = @_; return LaTeXML::Color::cmyk->new(0, 0, 0, 1 - $$self[1]); }
sub hsb { my ($self) = @_; return LaTeXML::Color::hsb->new(0, 0, $$self[1]); }

#======================================================================
package LaTeXML::Color::DerivedColor;
use base qw(LaTeXML::Color);
use LaTeXML::Global;

sub rgb  { my ($self) = @_; return $self->convert('rgb'); }
sub cmy  { my ($self) = @_; return $self->convert('cmy'); }
sub cmyk { my ($self) = @_; return $self->convert('cmyk'); }
sub hsb  { my ($self) = @_; return $self->convert('hsb'); }
sub gray { my ($self) = @_; return $self->convert('gray'); }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
1;
