# /=====================================================================\ #
# |  LaTeXML::Core::List                                                | #
# | Digested objects produced in the Stomach                            | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

#**********************************************************************
# A list of boxes or Whatsits
# (possibly evolve into HList, VList, MList)
#**********************************************************************
package LaTeXML::Core::List;
use strict;
use warnings;
use LaTeXML::Global;
use base qw(LaTeXML::Core::Box);

sub new {
  my ($class, @boxes) = @_;
  my ($bx, $font, $locator);
  my @bxs = @boxes;
  while (defined($bx = shift(@bxs)) && (!defined $locator)) {
    $locator = $bx->getLocator unless defined $locator; }
  @bxs = @boxes;
  # Maybe the most representative font for a List is the font of the LAST box (that _has_ a font!) ???
  while (defined($bx = pop(@bxs)) && (!defined $font)) {
    $font = $bx->getFont unless defined $font; }
  return bless [[@boxes], $font, $locator || '', undef, {}], $class; }

sub isMath {
  return 0; }    # List's are text mode

sub unlist {
  my ($self) = @_;
  return @{ $$self[0] }; }

sub revert {
  my ($self) = @_;
  return map { Revert($_) } $self->unlist; }

sub toString {
  my ($self) = @_;
  return join('', grep { defined $_ } map { $_->toString } $self->unlist); }

# Methods for overloaded operators
sub stringify {
  my ($self) = @_;
  my $type = ref $self;
  $type =~ s/^LaTeXML:://;
  return $type . '[' . join(',', map { Stringify($_) } $self->unlist) . ']'; }    # Not ideal, but....

sub equals {
  my ($a, $b) = @_;
  return 0 unless (defined $b) && ((ref $a) eq (ref $b));
  my @a = $a->unlist;
  my @b = $b->unlist;
  while (@a && @b && ($a[0]->equals($b[0]))) {
    shift(@a); shift(@b); }
  return !(@a || @b); }

sub beAbsorbed {
  my ($self, $document) = @_;
  return map { $document->absorb($_) } $self->unlist; }

sub computeSize {
  my ($self) = @_;
  my ($wd, $ht, $dp) = (0, 0, 0);
  foreach my $box (@{ $$self[0] }) {
    my $w = $box->getWidth;
    my $h = $box->getHeight;
    my $d = $box->getDepth;
    if (ref $w) {
      $wd += $w->valueOf; }
    else {
      Warn('expected', 'Dimension', undef,
        "Width of " . Stringify($box) . " yeilded a non-dimension: " . Stringify($w)); }
    if (ref $h) {
      $ht = max($ht, $h->valueOf); }
    else {
      Warn('expected', 'Dimension', undef,
        "Height of " . Stringify($box) . " yeilded a non-dimension: " . Stringify($h)); }
    if (ref $d) {
      $dp = max($dp, $d->valueOf); }
    else {
      Warn('expected', 'Dimension', undef,
        "Width of " . Stringify($box) . " yeilded a non-dimension: " . Stringify($d)); }
  }
  $$self[4]{width}  = Dimension($wd) unless defined $$self[4]{width};
  $$self[4]{height} = Dimension($ht) unless defined $$self[4]{height};
  $$self[4]{depth}  = Dimension($dp) unless defined $$self[4]{depth};
  return; }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::List> - Representations of digested objects.

=head1 DESCRIPTION

represents a sequence of digested things in text;

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
