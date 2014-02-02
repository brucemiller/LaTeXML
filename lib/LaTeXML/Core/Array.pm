# -*- CPERL -*-
# /=====================================================================\ #
# |  LaTeXML::Core::Array                                               | #
# | Support for Lists or Arrays of digestable stuff for LaTeXML         | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Array;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use base qw(LaTeXML::Common::Object);

# The following tokens (individual Token's or Tokens') describe how to revert the Array
#   open,close and separator are the outermost delimiter and separator between items
#   itemopen,itemclose are delimiters for each item
sub new {
  my ($class, %options) = @_;
  return bless { type => $options{type},
    open => $options{open}, close => $options{close}, separator => $options{separator},
    itemopen => $options{itemopen}, itemclose => $options{itemclose},
    values => $options{values} }, $class; }

sub getValue {
  my ($self, $n) = @_;
  return $$self{values}[$n]; }

sub setValue {
  my ($self, $n, $value) = @_;
  return $$self{values}[$n] = $value; }

sub getValues {
  my ($self) = @_;
  return @{ $$self{values} }; }

sub beDigested {
  my ($self, $stomach) = @_;
  my @v = ();
  foreach my $item (@{ $$self{values} }) {
    # Yuck
    my $typedef = $$self{type} && $STATE->lookupMapping('PARAMETER_TYPE', $$self{type});
    my $dodigest = (ref $item) && (!$typedef || !$$typedef{undigested});
    my $semiverb = $dodigest && $typedef && $$typedef{semiverbatim};
    $STATE->beginSemiverbatim() if $semiverb;
    push(@v, ($dodigest ? $item->beDigested($stomach) : $item));
    $STATE->endSemiverbatim() if $semiverb;
  }
  return (ref $self)->new(open => $$self{open}, close => $$self{close}, separator => $$self{separator},
    itemopen => $$self{itemopen}, itemclose => $$self{itemclose},
    type     => $$self{type},     values    => [@v]); }

sub revert {
  my ($self) = @_;
  my @tokens = ();
  foreach my $item (@{ $$self{values} }) {
    push(@tokens, $$self{separator}->unlist) if $$self{separator} && @tokens;
    push(@tokens, $$self{itemopen}->unlist)  if $$self{itemopen};
    push(@tokens, Revert($item));
    push(@tokens, $$self{itemclose}->unlist) if $$self{itemclose}; }
  unshift(@tokens, $$self{open}->unlist) if $$self{open};
  push(@tokens, $$self{close}->unlist) if $$self{close};
  return @tokens; }

sub unlist {
  my ($self) = @_;
  return @{ $$self{values} }; }    # ????

sub toString {
  my ($self) = @_;
  my $string = '';
  foreach my $item (@{ $$self{values} }) {
    $string .= ', ' if $string;
    $string .= ToString($item); }
  return '[[' . $string . ']]'; }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Array> - support for Arrays of objects

=head1 DESCRIPTION

Provides a representation of arrays  of digested objects.
It extends L<LaTeXML::Common::Object>.

=head2 Methods

=over 4

=item C<< LaTeXML::Core::Array->new(%options); >>

Creates an Array object
Options are
  values  List of values; typically Tokens, initially.
  type    The type of objects (as a ParameterType)

The following are Tokens lists that are used for reverting to raw TeX,
each can be undef
  open      the opening delimiter eg "{"
  close     the closing delimiter eg "}"
  separator the separator between items, eg ","
  itemopen  the opening delimiter for each item
  itemclose the closeing delimiter for each item

=back

=head2 Accessors

=over 4

=item C<< $value = $array->getValue($n) >>

Return the C<$n>-th item in the list.

=item C<< $array->setValue($n,$value) >>

Sets the C<$n>-th value to C<$value>.


=item C<< @values = $keyval->getValues(); >>

Return the list of values.


=item C<< $keyval->beDigested; >>

Return a new C<LaTeXML::Core::Array> object with all values digested as appropriate.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
