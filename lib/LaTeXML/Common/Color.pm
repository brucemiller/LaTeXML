# /=====================================================================\ #
# |  LaTeXML::Common::Color             ,...                            | #
# | Representation of colors in various color models                    | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Color;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use base qw(LaTeXML::Common::Object);
use base qw(Exporter);
our @EXPORT = (    # Global STATE; This gets bound by LaTeXML.pm
  qw( &Color &Black &White),
);

#======================================================================
# Exported constructors
sub Color {
  my ($model, @components) = @_;
  return LaTeXML::Common::Color->new(ToString($model), map { ToString($_) } @components); }

use constant Black => bless ['rgb', 0, 0, 0], 'LaTeXML::Common::Color::rgb';
use constant White => bless ['rgb', 1, 1, 1], 'LaTeXML::Common::Color::rgb';

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Color objects; objects representing color in "arbitrary" color models
# We'd like to provide a set of "core" color models (rgb,cmy,cmyk,hsb)
# and allow derived color models (with scaled ranges, or whatever; see xcolor).
# There is some awkwardness in that we'd like to support the core models
# directly with built-in code, but support derived models that possibly
# are defined in terms of macros defined as part of a style file.
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# NOTE: This class is in Common since it could conceivably be useful
# in Postprocessing --- But the API, includes, etc haven't been tuned for that!
# They only use $STATE to get derived color information, Error, min & max.
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Color Objects

our %core_color_models = map { ($_ => 1) } qw(rgb cmy cmyk hsb gray);    # [CONSTANT]

# slightly contrived to avoid 'use'ing all the models in here
# (which causes compiler redefined issues, and preloads them all)
sub new {
  my ($class, @components) = @_;
  if (ref $class) {    # from $self->new(...)
    return bless [$$class[0], @components], ref $class; }
  else {               # Else, $model is the 1st element of @components;
    my $model = shift(@components);
    my $type  = ($core_color_models{$model} ? $model : 'Derived');
    my $class = 'LaTeXML::Common::Color::' . $type;
    if (($type eq 'Derived')
      && !$STATE->lookupValue('derived_color_model_' . $model)) {
      Error('unexpected', $model, undef, "Unrecognized color model '$model'"); }
    my $module = $class . '.pm';
    $module =~ s|::|/|g;
    require $module unless exists $INC{$module};    # Load if not already loaded
    return bless [$model, @components], $class; } }

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
  elsif ($core_color_models{$tomodel}) {    # target must be core model
    return $self->toCore->$tomodel; }
  elsif (my $data = $STATE->lookupValue('derived_color_model_' . $tomodel)) { # Ah, target is a derived color
    my $coremodel   = $$data[0];
    my $convertfrom = $$data[2];
    return &{$convertfrom}($self->$coremodel); }
  else {
    Error('unexpected', $tomodel, undef, "Unrecognized color model '$tomodel'");
    return $self; } }

sub toString {
  my ($self) = @_;
  my ($model, @comp) = @$self;
  return $model . "(" . join(',', @comp) . ")"; }

sub toHex {
  my ($self) = @_;
  return $self->rgb->toHex; }

sub toAttribute {
  my ($self) = @_;
  return $self->rgb->toHex; }

# Convert the color to a core model; Assume it already is!
# Color::Derived MUST override this...
sub toCore { my ($self) = @_; return $self; }

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

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Common::Color> - abstract class representating colors using various color models;
extends L<LaTeXML::Common::Object>.

=head2 Exported functions

=over 4

=item C<< $color = Color($model,@components); >>

Creates a Color object using the given color model, and with the given components.
The core color models are C<rgb>, C<hsv>, C<cmy>, C<cmyk> and C<gray>.
The components of colors using core color models are between 0 and 1 (inclusive)

=item C<< Black >>, C<< White >>

Constant color objects representing black and white, respectively.

=back

=head2 Methods

=over 4

=item C<< $model = $color->model; >>

Return the name of the color model.

=item C<< @components = $color->components; >>

Return the components of the color.

=item C<< $other = $color->convert($tomodel); >>

Converts the color to another color model.

=item C<< $string = $color->toString; >>

Returns a printed representation of the color.

=item C<< $hex = $color->toHex; >>

Returns a string representing the color as RGB in hexadecimal (6 digits).

=item C<< $other = $color->toCore(); >>

Converts the color to one of the core colors.

=item C<< $complement = $color->complement(); >>

Returns the complement color (works for colors in C<rgb>, C<cmy> and C<gray> color models).

=item C<< $new = $color->mix($other,$fraction); >>

Returns a new color which results from mixing a C<$fraction> of C<$color>
with C<(1-$fraction)> of color C<$other>.

=item C<< $new = $color->add($other); >>

Returns a new color made by adding the components of the two colors.

=item C<< $new = $color->scale($m); >>

Returns a new color made by mulitiplying the components by C<$n>.

=item C<< $new = $color->multiply(@m); >>

Returns a new color made by mulitiplying the components by the corresponding component from C<@n>.

=back

=head1 SEE ALSO

Supported color models:
L<LaTeXML::Common::Color::rgb>,
L<LaTeXML::Common::Color::hsb>,
L<LaTeXML::Common::Color::cmy>,
L<LaTeXML::Common::Color::cmyk>,
L<LaTeXML::Common::Color::gray> and
L<LaTeXML::Common::Color::Derived>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

