# /=====================================================================\ #
# |  LaTeXML::Core::Tokens                                              | #
# | A list of Token(s)                                                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Tokens;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Core::Token;
use base qw(LaTeXML::Common::Object);
use base qw(Exporter);
our @EXPORT = (    # Global STATE; This gets bound by LaTeXML.pm
  qw(&Tokens)
);

#======================================================================
# Token List constructors.

# Return a LaTeXML::Core::Tokens made from the arguments (tokens)
sub Tokens {
  my (@tokens) = @_;
  return LaTeXML::Core::Tokens->new(@tokens); }

#======================================================================

# Form a Tokens list of Token's
# Flatten the arguments Token's and Tokens's into plain Token's
# .... Efficiently! since this seems to be called MANY times.
sub new {
  my ($class, @tokens) = @_;
  my $r;
  return bless [map { (($r = ref $_) eq 'LaTeXML::Core::Token' ? $_
        : ($r eq 'LaTeXML::Core::Tokens' ? @$_
          : Fatal('misdefined', $r, undef, "Expected a Token, got " . Stringify($_)))) }
      @tokens], $class; }

# Return a list of the tokens making up this Tokens
sub unlist {
  my ($self) = @_;
  return @$self; }

# Return a shallow copy of the Tokens
sub clone {
  my ($self) = @_;
  return bless [@$self], ref $self; }

# Return a string containing the TeX form of the Tokens
sub revert {
  my ($self) = @_;
  return @$self; }

# toString is used often, and for more keyword-like reasons,
# NOT for creating valid TeX (use revert or UnTeX for that!)
sub toString {
  my ($self) = @_;
  return join('', map { $$_[0] } @$self); }

# Methods for overloaded ops.
sub equals {
  my ($a, $b) = @_;
  return 0 unless defined $b && (ref $a) eq (ref $b);
  my @a = @$a;
  my @b = @$b;
  while (@a && @b && ($a[0]->equals($b[0]))) {
    shift(@a); shift(@b); }
  return !(@a || @b); }

sub stringify {
  my ($self) = @_;
  return "Tokens[" . join(',', map { $_->toString } @$self) . "]"; }

sub beDigested {
  my ($self, $stomach) = @_;
  return $stomach->digest($self); }

sub neutralize {
  my ($self, @extraspecials) = @_;
  return Tokens(map { $_->neutralize(@extraspecials) } $self->unlist); }

sub without_dont_expand {
  my ($self) = @_;
  return Tokens(map { $_->without_dont_expand } $self->unlist); }

sub isBalanced {
  my ($self) = @_;
  my $level = 0;
  foreach my $t (@$self) {
    my $cc = $$t[1];    # INLINE
    $level++ if $cc == CC_BEGIN;
    $level-- if $cc == CC_END; }
  return $level == 0; }

# NOTE: Assumes each arg either undef or also Tokens
# Using inline accessors on those assumptions
sub substituteParameters {
  my ($self, @args) = @_;
  my @in     = @{$self};    # ->unlist
  my @result = ();
  while (@in) {
    my $token;
    if (($token = shift(@in))->[1] != CC_PARAM) {    # Non '#'; copy it
      push(@result, $token); }
    elsif (($token = shift(@in))->[1] != CC_PARAM) {    # Not multiple '#'; read arg.
      if (my $arg = $args[ord($$token[0]) - ord('0') - 1]) {
        push(@result, (ref $arg eq 'LaTeXML::Core::Token' ? $arg : @$arg)); } }    # ->unlist
    else {    # Duplicated '#', copy 2nd '#'
      push(@result, $token); } }
  return LaTeXML::Core::Tokens->new(@result); }

# Trims outer braces (if they balance each other)
# Should this also trim whitespace? or only if there are braces?
sub stripBraces {
  my ($self) = @_;
  my $n      = 1 + $#$self;
  my $i0     = 0;
  my $i1     = $n;
  # skip past spaces at ends.
  while (($i0 < $n) && ($$self[$i0]->getCatcode == CC_SPACE))     { $i0++; }
  while (($i1 > 0)  && ($$self[$i1 - 1]->getCatcode == CC_SPACE)) { $i1--; }
  my (@o, @p);
  # Collect balanced pairs.
  for (my $i = $i0 ; $i < $i1 ; $i++) {
    my $cc = $$self[$i]->getCatcode;
    if ($cc == CC_BEGIN) {
      push(@o, $i); }
    elsif ($cc == CC_END) {
      if (@o) {
        push(@p, pop(@o), $i); }
      else {
        return $self; } } }    # Unbalanced: Too many }
  return $self if @o;          # Unbalanced: Too many {
  ## COULD strip multiple pairs of braces by checking more @p pairs
  if (@p) {
    my $j1 = pop(@p);
    my $j0 = pop(@p);
    if (($j0 == $i0) && ($j1 == $i1 - 1)) {
      $i0++; $i1--; } }
  return (($i0 < $i1) && (($i0 > 0) || ($i1 < $n)) ? Tokens(@$self[$i0 .. $i1 - 1]) : $self); }

#======================================================================

1;

__END__

=pod

=head1 NAME

C<LaTeXML::Core::Tokens> - represents lists of L<LaTeXML::Core::Token>'s;
extends L<LaTeXML::Common::Object>.

=head2 Exported functions

=over 4

=item C<< $tokens = Tokens(@token); >>

Creates a L<LaTeXML::Core::Tokens> from a list of L<LaTeXML::Core::Token>'s

=back

=head2 Tokens methods

The following method is specific to C<LaTeXML::Core::Tokens>.

=over 4

=item C<< $tokenscopy = $tokens->clone; >>

Return a shallow copy of the $tokens.  This is useful before reading from a C<LaTeXML::Core::Tokens>.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
