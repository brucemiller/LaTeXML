# /=====================================================================\ #
# |  LaTeXML::Common::Glue                                              | #
# | Representation of Stretchy dimensions                               | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Glue;
use LaTeXML::Global;
use strict;
use warnings;
use base qw(LaTeXML::Common::Dimension);
use base qw(Exporter);
our @EXPORT = (qw(&Glue));

#======================================================================
# Exported constructor.

sub Glue {
  my ($scaledpoints, $plus, $pfill, $minus, $mfill) = @_;
  return LaTeXML::Common::Glue->new($scaledpoints, $plus, $pfill, $minus, $mfill); }

#======================================================================

my %fillcode = (fil => 1, fill => 2, filll => 3);    # [CONSTANT]
my @FILL = ('', 'fil', 'fill', 'filll');             # [CONSTANT]

my $num_re   = qr/\d*\.?\d*/;                        # [CONSTANT]
my $unit_re  = qr/[a-zA-Z][a-zA-Z]/;                 # [CONSTANT]
my $fill_re  = qr/fil|fill|filll|[a-zA-Z][a-zA-Z]/;  # [CONSTANT]
my $plus_re  = qr/\s+plus\s*($num_re)($fill_re)/;    # [CONSTANT]
my $minus_re = qr/\s+minus\s*($num_re)($fill_re)/;   # [CONSTANT]
our $GLUE_re = qr/(\+?\-?$num_re)($unit_re)($plus_re)?($minus_re)?/;    # [CONSTANT]

sub new {
  my ($class, $sp, $plus, $pfill, $minus, $mfill) = @_;
  if ((!defined $plus) && (!defined $pfill) && (!defined $minus) && (!defined $mfill)) {
    if ($sp =~ /^(\d*\.?\d*)$/) { }
    elsif ($sp =~ /^$GLUE_re$/) {
      my ($f, $u, $p, $pu, $m, $mu) = ($1, $2, $4, $5, $7, $8);
      $sp = $f * $STATE->convertUnit($u);
      if (!$pu) { }
      elsif ($fillcode{$pu}) { $plus = $p;                            $pfill = $pu; }
      else                   { $plus = $p * $STATE->convertUnit($pu); $pfill = 0; }
      if (!$mu) { }
      elsif ($fillcode{$mu}) { $minus = $m;                            $mfill = $mu; }
      else                   { $minus = $m * $STATE->convertUnit($mu); $mfill = 0; }
    } }
  return bless [$sp || "0", $plus || "0", $pfill || 0, $minus || "0", $mfill || 0], $class; }

#sub getStretch { $_[0]->[1]; }
#sub getShrink  { $_[0]->[2]; }

sub toString {
  my ($self) = @_;
  my ($sp, $plus, $pfill, $minus, $mfill) = @$self;
  my $string = LaTeXML::Common::Dimension::pointformat($sp);
  $string .= ' plus ' . ($pfill
    ? $plus . $FILL[$pfill]
    : LaTeXML::Common::Dimension::pointformat($plus))
    if $plus != 0;
  $string .= ' minus ' . ($mfill
    ? $minus . $FILL[$mfill]
    : LaTeXML::Common::Dimension::pointformat($minus))
    if $minus != 0;
  return $string; }

sub toAttribute {
  my ($self) = @_;
  my ($sp, $plus, $pfill, $minus, $mfill) = @$self;
  my $string = LaTeXML::Common::Dimension::attributeformat($sp);
  $string .= ' plus ' . ($pfill
    ? $plus . $FILL[$pfill]
    : LaTeXML::Common::Dimension::attributeformat($plus))
    if $plus != 0;
  $string .= ' minus ' . ($mfill
    ? $minus . $FILL[$mfill]
    : LaTeXML::Common::Dimension::attributeformat($minus))
    if $minus != 0;
  return $string; }

sub negate {
  my ($self) = @_;
  my ($pts, $p, $pf, $m, $mf) = @$self;
  return (ref $self)->new(-$pts, -$p, $pf, -$m, $mf); }

sub add {
  my ($self, $other) = @_;
  my ($pts, $p, $pf, $m, $mf) = @$self;
  if (ref $other eq 'LaTeXML::Common::Glue') {
    my ($pts2, $p2, $pf2, $m2, $mf2) = @$other;
    $pts += $pts2;
    if ($pf == $pf2) { $p += $p2; }
    elsif ($pf < $pf2) { $p = $p2; $pf = $pf2; }
    if ($mf == $mf2) { $m += $m2; }
    elsif ($mf < $mf2) { $m = $m2; $mf = $mf2; }
    return (ref $self)->new($pts, $p, $pf, $m, $mf); }
  else {
    return (ref $self)->new($pts + $other->valueOf, $p, $pf, $m, $mf); } }

sub multiply {
  my ($self, $other) = @_;
  my ($pts, $p, $pf, $m, $mf) = @$self;
  $other = $other->valueOf if ref $other;
  return (ref $self)->new($pts * $other, $p * $other, $pf, $m * $other, $mf); }

sub stringify {
  my ($self) = @_;
  return "Glue[" . join(',', @$self) . "]"; }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Common::Glue> - representation of glue, skips, stretchy dimensions;
extends L<LaTeXML::Common::Dimension>.

=head2 Exported functions

=over 4

=item C<< $glue = Glue($gluespec); >>

=item C<< $glue = Glue($sp,$plus,$pfill,$minus,$mfill); >>

Creates a Glue object.  C<$gluespec> can be a string in the
form that TeX recognizes (number units optional plus and minus parts).
Alternatively, the dimension, plus and minus parts can be given separately:
C<$pfill> and C<$mfill> are 0 (when the C<$plus> or C<$minus> part is in sp)
or 1,2,3 for fil, fill or filll.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

