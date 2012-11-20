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
  my($color)=@_;
  # Apply color mask, if any. (a bit too xcolor specific)
  if($STATE->lookupValue('Boolean:maskcolors')){
    if(my $mask = $STATE->lookupValue('color_mask')){
      $color = $color->convert($mask->model)->multiply($mask->components); }}
  $color->rgb->toHex; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Color Objects

sub new {
  my($class,@components)=@_;
  my $model;
  if(ref $class){ $model=$class->model; $class=ref $class; }
  else          { $model=$class; $model=~ s/^LaTeXML::Color:://; }
  if(('LaTeXML::Color::'.$model)->can('isCore')){ # All core models have components in interval [0...1] !!!!
    # Should we truncate to the interval?
##    @components = map( ($_ < 0 ? 0 : ($_ > 1 ? 1 : $_)), @components);
    # Should we avoid absurd "precisions" ?
##    @components = map( int($_*10000+0.5)/10000, @components);
  }
  elsif(! $STATE->lookupValue('derived_color_model_'.$model)){
    Error('unexpected',$model,undef,"Unrecognized color model '$model'"); }
  bless [$model,@components],$class; }

sub model { $_[0][0]; }
sub components { my($m,@comp)=@{$_[0]}; @comp; }

# Convert a color to another model
sub convert {
  my($self,$tomodel)=@_;
  if($self->model eq $tomodel){ # Already the correct model
    $self; }
  elsif(('LaTeXML::Color::'.$tomodel)->can('isCore')){		 # target must be core model
    $self->toCore->$tomodel; }
  elsif(my $data = $STATE->lookupValue('derived_color_model_'.$tomodel)){ # Ah, target is a derived color
    my $coremodel   = $$data[0];
    my $convertfrom = $$data[2];
    &{$convertfrom}($self->$coremodel); }
  else {
    Error('unexpected',$tomodel,undef,"Unrecognized color model '$tomodel'");
    $self; }}

sub toCore {
  my($self)=@_;
  my $model = $$self[0];
  if(my $data = $STATE->lookupValue('derived_color_model_'.$model)){
    my $convertto = $$data[1];
    &{ $convertto }($self); }
  else {
    Error('unexpected',$self->model,undef,"Color is not in valid model '$model'"); }}

sub toHex {
  $_[0]->rgb->toHex; }
#======================================================================
# By default, just complement components (works for rgb, cmy, gray)
sub complement {
  my($self)=@_;
  $self->new(map( 1-$_, $self->components)); }

# Mix $self*$fraction + $color*(1-$fraction)
sub mix {
  my($self,$color,$fraction)=@_;
  $color = $color->convert($self->model) unless $self->model eq $color->model;
  my @a = $self->components;
  my @b = $color->components;
  $self->new(map( $fraction*$a[$_]+(1-$fraction)*$b[$_], 0..$#a)); }

# The next 2 methods multiply the components of a color by some value(s)
# This assumes that such a thing makes sense in the given model, for some purpose.
# It may be that the components should be truncated to 1 (or some other max?)

# Multiply all components by a constant
sub scale {
  my($self,$m)=@_;
  $self->new(map( $m*$_, $self->components)); }

# Multiply by a vector (must have same number of components)
# This may or may not make sense for any given color model or purpose.
sub multiply {
  my($self,@m)=@_;
  my @c = $self->components;
  if(scalar(@m) != scalar(@c)){
    Error('misdefined','multiply',"Multiplying color components by wrong number of parts",
	  "The color is ".ToString($self)." while the multipliers are ".join(',',@m));
    $self; }
  else {
    $self->new(map( $c[$_]*$m[$_],0..$#c)); }}

sub toString {
  my($model,@comp)=@{$_[0]};
  $model."(".join(',',@comp).")"; }

#======================================================================
package LaTeXML::Color::CoreColor;
use base qw(LaTeXML::Color);
use LaTeXML::Global;

# Convert the color to a core model (it already is!)
sub toCore { $_[0]; }

sub isCore { 1; }

#======================================================================
# rgb: (red,green,blue) each in range [0,1]
package LaTeXML::Color::rgb;
use base qw(LaTeXML::Color::CoreColor);
use LaTeXML::Global;

sub rgb  { $_[0]; }
# Convert to cmy, cmyk, 
sub cmy  { LaTeXML::Color::cmy->new(1-$_[0][1],1-$_[0][2],1-$_[0][3]); }
sub cmyk { $_[0]->cmy->cmyk; }
sub gray { LaTeXML::Color::gray->new(0.3 * $_[0][1] + 0.59 * $_[0][2] + 0.11 * $_[0][3]); }

# See Section 6.3.1 in xcolor documentation Dr.Uwe Kern; xcolor.pdf
sub Phi {
  my($x,$y,$z,$u,$v)=@_;
  LaTeXML::Color::hsb->new(($u*($x - $z) + $v*($x - $y))/(6*($x - $z)), ($x - $z)/$x, $x); }

sub hsb  {
  my($m,$r,$g,$b)=@{$_[0]};
  my $i = 4 * ($r >= $g) + 2 * ($g >= $b) + ($b >= $r);
  if    ($i == 1) { Phi($b, $g, $r, 3, 1); }
  elsif ($i == 2) { Phi($g, $r, $b, 1, 1); }
  elsif ($i == 3) { Phi($g, $b, $r, 3, -1); }
  elsif ($i == 4) { Phi($r, $b, $g, 5, 1); }
  elsif ($i == 5) { Phi($b, $r, $g, 5, -1); }
  elsif ($i == 6) { Phi($r, $g, $b, 1, -1); }
  elsif ($i == 7) { LaTeXML::Color::hsb->new(0, 0, $b); }}

our @hex = qw(0 1 2 3 4 5 6 7 8 9 A B C D E F);
sub hex2 { $hex[int($_[0]/16)].$hex[$_[0]%16]; }
sub toHex {
  my($model,$r,$g,$b)=@{$_[0]};
  '#'.hex2(int($r*255+0.5)).hex2(int($g*255+0.5)).hex2(int($b*255+0.5)); }

#======================================================================
package LaTeXML::Color::cmy;
use base qw(LaTeXML::Color::CoreColor);
use LaTeXML::Global;

sub cmy  { $_[0]; }
sub rgb  { LaTeXML::Color::rgb->new(1-$_[0][1],1-$_[0][2],1-$_[0][3]); }
sub hsb  { $_[0]->rgb->hsb; }
sub gray { LaTeXML::Color::gray->new(1 - (0.3 * $_[0][1] + 0.59 * $_[1][2] + 0.11 * $_[2][3])); }
sub cmyk {
  my($model,$c,$m,$y)=@{$_[0]};
  # These beta parameters are linear coefficients for "undercolor-removal", and "black-generation"
  # In xcolor, they could come from \adjustUCRBG
  my ($bc, $bm, $by, $bk) = (1,1,1,1); 
  my $k = min($c, min($m, $y));
  LaTeXML::Color::cmyk->new(min(1, max(0, $c - $bc * $k)),
			    min(1, max(0, $m - $bm * $k)),
			    min(1, max(0, $y - $by * $k)),
			    $bk * $k); }

#======================================================================
package LaTeXML::Color::cmyk;
use base qw(LaTeXML::Color::CoreColor);
use LaTeXML::Global;

sub cmyk { $_[0]; }
sub cmy  {
  my($model,$c,$m,$y,$k)=@{$_[0]};
  LaTeXML::Color::cmy->new(min(1,$c+$k),min(1,$m+$k),min(1,$y+$k)); }
sub rgb  { $_[0]->cmy->rgb; }
sub hsb  { $_[0]->cmy->hsb; }
sub gray {
  my($model,$c,$m,$y,$k)=@{$_[0]};
  LaTeXML::Color::gray->new(1 - min(1, 0.3*$c + 0.59*$m + 0.11*$y + $k)); }

sub complement { $_[0]->cmy->complement->cmyk; }

#======================================================================
package LaTeXML::Color::hsb;
use base qw(LaTeXML::Color::CoreColor);
use LaTeXML::Global;

sub hsb  { $_[0]; }
sub XXXrgb {
  my($model,$h,$s,$b) = @{$_[0]};
  my $i = int(6 * $h);
  my $f = 6 * $h - $i;
  my @rgb;
  if    ($i == 0) { @rgb = (0, 1-$f, 1); }
  elsif ($i == 1) { @rgb = ($f, 0, 1); }
  elsif ($i == 2) { @rgb = (1, 0, 1-$f); }
  elsif ($i == 3) { @rgb = (1, $f, 0); }
  elsif ($i == 4) { @rgb = (1 - $f, 1, 0); }
  elsif ($i == 5) { @rgb = (0, 1, $f); }
  elsif ($i == 6) { @rgb = (0, 1, 1); }
  LaTeXML::Color::rgb->new(map($b * (1-$s*$_), @rgb)); }

sub rgb {
  my($model,$h,$s,$b) = @{$_[0]};
  my $i = int(6 * $h);
  my $f = 6 * $h - $i;
  my $u=$b*(1-$s*(1-$f));
  my $v=$b*(1-$s*$f);
  my $w=$b*(1-$s);
  if    ($i == 0) { LaTeXML::Color::rgb->new($b,$u,$w); }
  elsif ($i == 1) { LaTeXML::Color::rgb->new($v,$b,$w); }
  elsif ($i == 2) { LaTeXML::Color::rgb->new($w,$b,$u); }
  elsif ($i == 3) { LaTeXML::Color::rgb->new($w,$v,$b); }
  elsif ($i == 4) { LaTeXML::Color::rgb->new($u,$w,$b); }
  elsif ($i == 5) { LaTeXML::Color::rgb->new($b,$w,$v); }
  elsif ($i == 6) { LaTeXML::Color::rgb->new($b,$w,$w); }}

sub cmy  { $_[0]->rgb->cmy; }
sub cmyk { $_[0]->rgb->cmyk; }
sub gray { $_[0]->rgb->gray; }

sub complement {
  my($self)=@_;
  my($h,$s,$b)=$self->components;
  my $hp = ($h < 0.5 ? $h+0.5 : $h-0.5);
  my $bp = 1 - $b*(1-$s);
  my $sp = ($bp == 0 ? 0 : $b*$s/$bp);
  $self->new($hp,$sp,$bp); }

sub mix {
  my($self,$color,$fraction)=@_;
  # I don't quite follow what Kern's saying, on a quick read,
  # so we'll punt by doing the conversion in rgb space, then converting back.
  $self->rgb->mix($color,$fraction)->hsb; }

#======================================================================
package LaTeXML::Color::gray;
use base qw(LaTeXML::Color::CoreColor);
use LaTeXML::Global;

sub gray { $_[0]; }
sub rgb  { LaTeXML::Color::rgb->new($_[0][1], $_[0][1], $_[0][1]); }
sub cmy  { LaTeXML::Color::cmy->new(1 - $_[0][1], 1 - $_[0][1], 1 - $_[0][1]);}
sub cmyk { LaTeXML::Color::cmyk->new(0, 0, 0, 1-$_[0][1]); }
sub hsb  { LaTeXML::Color::hsb->new(0, 0, $_[0][1]); }

#======================================================================
package LaTeXML::Color::DerivedColor;
use base qw(LaTeXML::Color);
use LaTeXML::Global;

sub rgb  { $_[0]->convert('rgb'); }
sub cmy  { $_[0]->convert('cmy'); }
sub cmyk { $_[0]->convert('cmyk'); }
sub hsb  { $_[0]->convert('hsb'); }
sub gray { $_[0]->convert('gray'); }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
1;
