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
use LaTeXML::Common::Error;
use LaTeXML::Common::Number;
use LaTeXML::Common::Dimension;
use base qw(LaTeXML::Common::Dimension);
use base qw(Exporter);
our @EXPORT = (qw(&Glue));

#======================================================================
# Exported constructor.

# Create a new Glue, given EITHER a string with units, fills,etc,
# OR separate args, wiith $spec, $plus, $minus being fixed point,
# and $pfill, $mfill being 0 (sp) or a fillcode
sub Glue {
  my ($spec, $plus, $pfill, $minus, $mfill) = @_;
  return LaTeXML::Common::Glue->new($spec, $plus, $pfill, $minus, $mfill); }

# ======================================================================
sub _unit { return 'pt'; }

my %fillcode = (fil => 1, fill => 2, filll => 3);    # [CONSTANT]
my @FILL     = ('', 'fil', 'fill', 'filll');         # [CONSTANT]

my $num_re   = qr/\d*\.?\d*/;                                           # [CONSTANT]
my $unit_re  = qr/[a-zA-Z][a-zA-Z]/;                                    # [CONSTANT]
my $fill_re  = qr/fil|fill|filll|[a-zA-Z][a-zA-Z]/;                     # [CONSTANT]
my $plus_re  = qr/\s+plus\s*($num_re)($fill_re)/;                       # [CONSTANT]
my $minus_re = qr/\s+minus\s*($num_re)($fill_re)/;                      # [CONSTANT]
our $GLUE_re = qr/(\+?\-?$num_re)($unit_re)($plus_re)?($minus_re)?/;    # [CONSTANT]

# Create a new Glue, given $sp, $plus, $minus being fixed point,
# and $pfill, $mfill being 0 (sp) or a fillcode
# OR, with spec being a string with units, plus, minus, etc.
sub new {
  my ($class, $spec, $plus, $pfill, $minus, $mfill) = @_;
  $spec = ToString($spec) if ref $spec;
  if ($spec !~ /[a-zA-Z][a-zA-Z]+/) {    # If no units, expect fixedpoint values
    $plus  = ToString($plus)  if ref $plus;
    $pfill = ToString($pfill) if ref $pfill;
    $minus = ToString($minus) if ref $minus;
    $mfill = ToString($mfill) if ref $mfill;
    # See comment in Dimension for why kround rather than int
    return bless [kround($spec) || "0",
      kround($plus  || 0), $pfill || 0,
      kround($minus || 0), $mfill || 0], $class; }
  else {
    my $mu = $class->_unit eq 'mu';
    if ((defined $plus) || (defined $pfill) || (defined $minus) || (defined $mfill)) {
      Warn('unexpected', 'fill', undef,
        "You should not create " . ($mu ? "MuGlue" : "Glue") . " with both units and stretch"); }
    if ($spec =~ /^$GLUE_re$/) {
      my ($f, $unit, $p, $punit, $m, $munit) = ($1, $2, $4, $5, $7, $8);
      if    (!$unit) { $f = int($f); }
      elsif ($mu)    { $f = fixpoint($f);    # in mu
        Warn('unexpected', $unit, undef, "Assumed mu") unless $unit eq 'mu'; }
      else                      { $f    = fixpoint($f, $STATE->convertUnit($unit)); }
      if (!$punit)              { $plus = $punit = $pfill = 0; }
      elsif ($fillcode{$punit}) { $plus = fixpoint($p); $pfill = $punit; }
      elsif ($mu)               { $plus = fixpoint($p); $pfill = 0;
        Warn('unexpected', $punit, undef, "Assumed mu") unless $punit eq 'mu'; }
      else                      { $plus  = fixpoint($p, $STATE->convertUnit($punit)); $pfill = 0; }
      if (!$munit)              { $minus = $munit               = $mfill = 0; }
      elsif ($fillcode{$munit}) { $minus = fixpoint($m); $mfill = $munit; }
      elsif ($mu)               { $minus = fixpoint($m); $mfill = 0;
        Warn('unexpected', $munit, undef, "Assumed mu") unless $munit eq 'mu'; }
      else { $minus = fixpoint($m, $STATE->convertUnit($munit)); $mfill = 0; }
      return bless [$f, $plus, $pfill, $minus, $mfill], $class; }
    else {
      Warn('unexpected', $spec, undef,
        "Missing " . ($mu ? "MuGlue" : "Glue") . " specification assuming 0pt"); }
    return bless [0, 0, 0, 0, 0], $class; } }

#sub getStretch { $_[0]->[1]; }
#sub getShrink  { $_[0]->[2]; }

sub toString {
  my ($self) = @_;
  my ($sp, $plus, $pfill, $minus, $mfill) = @$self;
  my $u      = $self->_unit;
  my $string = fixedformat($sp, $u);
  $string .= ' plus ' . fixedformat($plus, ($pfill ? $FILL[$pfill] : $u))   if $plus != 0;
  $string .= ' minus ' . fixedformat($minus, ($mfill ? $FILL[$mfill] : $u)) if $minus != 0;
  return $string; }

sub toAttribute {
  my ($self) = @_;
  my ($sp, $plus, $pfill, $minus, $mfill) = @$self;
  my $u      = $self->_unit;
  my $string = LaTeXML::Common::Dimension::attributeformat($sp, $u);
  $string .= ' plus '
    . LaTeXML::Common::Dimension::attributeformat($plus, ($pfill ? $FILL[$pfill] : $u))
    if $plus != 0;
  $string .= ' minus '
    . LaTeXML::Common::Dimension::attributeformat($minus, ($mfill ? $FILL[$mfill] : $u))

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
    if    ($pf == $pf2) { $p += $p2; }
    elsif ($pf < $pf2)  { $p = $p2; $pf = $pf2; }
    if    ($mf == $mf2) { $m += $m2; }
    elsif ($mf < $mf2)  { $m = $m2; $mf = $mf2; }
    return (ref $self)->new($pts, $p, $pf, $m, $mf); }
  else {
    return (ref $self)->new($pts + $other->valueOf, $p, $pf, $m, $mf); } }

sub multiply {
  my ($self, $other) = @_;
  my ($pts, $p, $pf, $m, $mf) = @$self;
  $other = $other->valueOf if ref $other;
  return (ref $self)->new($pts * $other, $p * $other, $pf, $m * $other, $mf); }

sub divide {
  my ($self, $other) = @_;
  my ($pts, $p, $pf, $m, $mf) = @$self;
  $other = $other->valueOf if ref $other;
  return (ref $self)->new($pts / $other, $p / $other, $pf, $m / $other, $mf); }

sub divideround {
  my ($self, $other) = @_;
  my ($pts, $p, $pf, $m, $mf) = @$self;
  $other = $other->valueOf if ref $other;
  return (ref $self)->new($pts / $other, $p / $other, $pf, $m / $other, $mf); }

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

=item C<< $glue = Glue($spec); >>

=item C<< $glue = Glue($sp,$plus,$pfill,$minus,$mfill); >>

Creates a Glue object.  C<$spec> can be a string in the
form that TeX recognizes (number units optional plus and minus parts).
Alternatively, the dimension, plus and minus parts can be given separately
as scaled points (fixpoint),
while C<$pfill> and C<$mfill> are 0 (when the C<$plus> or C<$minus> part is in scaledpoints)
or 1,2,3 for fil, fill or filll, respectively.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

