# /=====================================================================\ #
# |  LaTeXML::Core::PairList                                            | #
# | Representation of lists of pairs of numbers or dimensions           | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::PairList;
use LaTeXML::Global;
use strict;
use warnings;
use base qw(LaTeXML::Object);

# Note: This is candiate to be absorbed into Array perhaps...

sub new {
  my ($class, @pairs) = @_;
  return bless [@pairs], $class; }

sub getCount {
  my ($self) = @_;
  return $#{$self} + 1; }

sub getPair {
  my ($self, $n) = @_;
  return $$self[$n]; }

sub getPairs {
  my ($self) = @_;
  return @$self; }

sub ptValue {
  my ($self) = @_;
  return join(' ', map { $_->ptValue } @$self); }

sub pxValue {
  my ($self) = @_;
  return join(' ', map { $_->pxValue } @$self); }

sub toString {
  my ($self) = @_;
  return join(' ', map { $_->toString } @$self); }

sub toAttribute {
  my ($self) = @_;
  return join(' ', map { $_->toAttribute } @$self); }

sub stringify {
  my ($self) = @_;
  return "PairList[" . join(',', map { $_->stringify } @$self) . "]"; }

sub revert {
  my ($self) = @_;
  my @rev = ();
  map { push(@rev, Revert($_)) } @$self;
  return @rev; }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::PairList> - representation of lists of pairs of numerical things

=head1 DESCRIPTION

represents lists of pairs of numerical things, coordinates or such.
Candidate for removal!

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

