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
  qw(&Tokens &TokensI),
);

#======================================================================
# Token List constructors.

# Return a LaTeXML::Core::Tokens made from the arguments (tokens)
sub Tokens {
  my (@tokens) = @_;
  my $r;
  # faster than foreach
  @tokens = map { (($r = ref $_) eq 'LaTeXML::Core::Token' ? $_
      : ($r eq 'LaTeXML::Core::Tokens' ? @$_
        : Error('misdefined', $r, undef, "Expected a Token, got " . Stringify($_)) || T_OTHER(Stringify($_)))) }
    @tokens;
  return bless [@tokens], 'LaTeXML::Core::Tokens'; }

sub TokensI {
  my (@tokens) = @_;
  return bless [@tokens], 'LaTeXML::Core::Tokens'; }

#======================================================================
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
  return join('', map { ($$_[1] == CC_COMMENT ? '' : $_->toString) } @$self); }

# Methods for overloaded ops.

# Compare two Tokens lists, ignoring comments & markers
sub equals {
  my ($a, $b) = @_;
  return 0 unless defined $b && (ref $a) eq (ref $b);
  my @a = @$a;
  my @b = @$b;
  while (@a || @b) {
    if (@a && (($a[0]->[1] == CC_COMMENT) || ($a[0]->[1] == CC_MARKER))) { shift(@a); next; }
    if (@b && (($b[0]->[1] == CC_COMMENT) || ($b[0]->[1] == CC_MARKER))) { shift(@b); next; }
    return unless @a && @b && shift(@a)->equals(shift(@b)); }
  return 1; }

sub stringify {
  my ($self) = @_;
  return "Tokens[" . join(',', map { $_->toString } @$self) . "]"; }

sub beDigested {
  no warnings 'recursion';
  my ($self, $stomach) = @_;
  return $stomach->digest($self); }

sub neutralize {
  my ($self, @extraspecials) = @_;
  return Tokens(map { $_->neutralize(@extraspecials) } @$self); }

sub isBalanced {
  my ($self) = @_;
  my $level = 0;
  foreach my $t (@$self) {
    my $cc = $$t[1];    # INLINE
    $level++ if $cc == CC_BEGIN;
    if ($cc == CC_END) {
      $level--;
      # Note that '{ }} {' is still unbalanced
      # even though the left and right braces match in count.
      last if $level < 0; } }
  return $level == 0; }

# NOTE: Assumes each arg either undef or also Tokens
# Using inline accessors on those assumptions
sub substituteParameters {
  my ($self, @args) = @_;
  my @in     = @{$self};    # ->unlist
  my @result = ();
  while (my $token = shift(@in)) {
    if ($$token[1] != CC_ARG) {    # Non-match; copy it
      push(@result, $token); }
    else {
      if (my $arg = $args[ord($$token[0]) - ord("0") - 1]) {
        push(@result, (ref $arg eq 'LaTeXML::Core::Token' ? $arg : @$arg)); } } }    # ->unlist
  return bless [@result], 'LaTeXML::Core::Tokens'; }

# Packs repeated CC_PARAM tokens into CC_ARG tokens for use as a macro body (and other token lists)
# Also unwraps \noexpand tokens, since that is also needed for macro bodies
# (but not strictly part of packing parameters)
sub packParameters {
  my ($self)    = @_;
  my @rescanned = ();
  my @toks      = @$self;
  my $repacked  = 0;
  while (my $t = shift @toks) {
    if ($$t[1] == CC_PARAM && @toks) {
      $repacked = 1;
      my $next_t  = shift @toks;
      my $next_cc = $next_t && $$next_t[1];
      if ($next_cc == CC_OTHER) {
        # only group clear match token cases
        push(@rescanned, T_ARG($next_t)); }
      elsif ($next_cc == CC_PARAM) {
        push(@rescanned, $t); }
      else {    # any other case, preserve as-is, let the higher level call resolve any errors
                # e.g. \detokenize{#,} is legal, while \textbf{#,} is not
        Error('misdefined', 'expansion', undef, "Parameter has a malformed arg, should be #1-#9 or ##. ",
          "In expansion " . ToString($self)); } }
    else {
      push(@rescanned, $t); } }
  return ($repacked ? bless [@rescanned], 'LaTeXML::Core::Tokens' : $self); }

# Trims outer braces (if they balance each other)
# Should this also trim whitespace? or only if there are braces?
sub stripBraces {
  my ($self, $layers) = @_;
  $layers = 1 unless $layers;
  my $n = 1 + $#$self;
  return $self unless $n > 1;    # short-circuit on empty tokens.
  my $i0 = 0;
  my $i1 = $n;
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
  while ($layers > 0) {
    $layers--;
    if (@p) {
      my $j1 = pop(@p);
      my $j0 = pop(@p);
      if (($j0 == $i0) && ($j1 == $i1 - 1)) {
        $i0++; $i1--; } } }
  # Empty, truncate
  if ($i0 == $i1) {
    return bless [], 'LaTeXML::Core::Tokens';
  }
  return (($i0 < $i1) && (($i0 > 0) || ($i1 < $n))
    ? bless [@$self[$i0 .. $i1 - 1]], 'LaTeXML::Core::Tokens'
    : $self); }

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
