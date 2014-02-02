# /=====================================================================\ #
# |  LaTeXML::Common::Color::Derived                                    | #
# | A representation of colors in color models derived from core        | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Color::Derived;
use strict;
use warnings;
use LaTeXML::Common::Color;
use base qw(LaTeXML::Common::Color);
use LaTeXML::Global;
use LaTeXML::Common::Error;

# Convert this derived color to one of the Core colors
# Subclasses of this color need to set the variable:
#   derived_color_model_<name>  => [$coremodel, &convertto($self), &convertfrom($core) ]
#   $coremodel is the core model class name associated with this color model
#   &convertto($self) converts an instance of the derived model to the core color
#   &convertfrom($core) converts an instance od the core model to the derived color
sub toCore {
  my ($self) = @_;
  my $model = $$self[0];
  if (my $data = $STATE->lookupValue('derived_color_model_' . $model)) {
    my $convertto = $$data[1];
    return &{$convertto}($self); }
  else {
    Error('unexpected', $self->model, undef, "Color is not in valid model '$model'");
    return Black; } }

sub rgb  { my ($self) = @_; return $self->convert('rgb'); }
sub cmy  { my ($self) = @_; return $self->convert('cmy'); }
sub cmyk { my ($self) = @_; return $self->convert('cmyk'); }
sub hsb  { my ($self) = @_; return $self->convert('hsb'); }
sub gray { my ($self) = @_; return $self->convert('gray'); }

#======================================================================
1;

__END__

=head1 NAME

C<LaTeXML::Common::Color::Derived> - represents colors in derived color models

=head1 SYNOPSIS

C<LaTeXML::Common::Color::Derived> represents colors in derived color models.
These are used to support various color models defined and definable via
the C<xcolor> package, such as colors where the components are in different ranges.
It extends L<LaTeXML::Common::Color>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
