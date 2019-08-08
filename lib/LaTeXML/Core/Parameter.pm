# /=====================================================================\ #
# |  LaTeXML::Core::Parameter                                           | #
# | Representation of a single Parameter for Control Sequences          | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Core::Parameter;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Core::Token;
use LaTeXML::Core::Tokens;
use base qw(LaTeXML::Common::Object);

# sub new {
#   my ($class, $spec, %options) = @_;
#   return bless { spec => $spec, %options }, $class; }

# Create a parameter reading object for a specific type.
# If either a declared entry or a function Read<Type> accessible from LaTeXML::Package::Pool
# is defined.
sub new {
  my ($class, $type, $spec, %options) = @_;
  my $descriptor = $STATE->lookupMapping('PARAMETER_TYPES', $type);
  if (!defined $descriptor) {
    if ($type =~ /^Optional(.+)$/) {
      my $basetype = $1;
      if ($descriptor = $STATE->lookupMapping('PARAMETER_TYPES', $basetype)) { }
      elsif (my $reader = checkReaderFunction("Read$type") || checkReaderFunction("Read$basetype")) {
        $descriptor = { reader => $reader }; }
      $descriptor = { %$descriptor, optional => 1 } if $descriptor; }
    elsif ($type =~ /^Skip(.+)$/) {
      my $basetype = $1;
      if ($descriptor = $STATE->lookupMapping('PARAMETER_TYPES', $basetype)) { }
      elsif (my $reader = checkReaderFunction($type) || checkReaderFunction("Read$basetype")) {
        $descriptor = { reader => $reader }; }
      $descriptor = { %$descriptor, novalue => 1, optional => 1 } if $descriptor; }
    else {
      my $reader = checkReaderFunction("Read$type");
      $descriptor = { reader => $reader } if $reader; } }
  Fatal('misdefined', $type, undef, "Unrecognized parameter type in \"$spec\"") unless $descriptor;
  # Convert semiverbatim to list of extra SPECIALS.
  my %data = (%{$descriptor}, %options);
  $data{semiverbatim} = [] if $data{semiverbatim} && (ref $data{semiverbatim} ne 'ARRAY');
  return bless { spec => $spec, type => $type, %data }, $class; }

# Check whether a reader function is accessible within LaTeXML::Package::Pool
sub checkReaderFunction {
  my ($function) = @_;
  if (defined $LaTeXML::Package::Pool::{$function}) {
    local *reader = $LaTeXML::Package::Pool::{$function};
    if (defined &reader) {
      return \&reader; } } }

sub stringify {
  my ($self) = @_;
  return $$self{spec}; }

sub setupCatcodes {
  my ($self) = @_;
  if ($$self{semiverbatim}) {
    $STATE->beginSemiverbatim(@{ $$self{semiverbatim} }); }
  return; }

sub revertCatcodes {
  my ($self) = @_;
  if ($$self{semiverbatim}) {
    $STATE->endSemiverbatim(); }
  return; }

sub read {
  my ($self, $gullet, $fordefn) = @_;
  # For semiverbatim, I had messed with catcodes, but there are cases
  # (eg. \caption(...\label{badchars}}) where you really need to
  # cleanup after the fact!
  # Hmmm, seem to still need it...
  $self->setupCatcodes;
  my $value = &{ $$self{reader} }($gullet, @{ $$self{extra} || [] });
  $value = $value->neutralize(@{ $$self{semiverbatim} }) if $$self{semiverbatim} && (ref $value)
    && $value->can('neutralize');
  $self->revertCatcodes;
  if ((!defined $value) && !$$self{optional}) {
    Error('expected', $self, $gullet,
      "Missing argument " . Stringify($self) . " for " . Stringify($fordefn));
    $value = T_OTHER('missing'); }
  return $value; }

# This is needed by structured parameter types like KeyVals
# where the argument may already have been tokenized before the KeyVals
# (and the parameter types for the keys) had a chance to properly parse.
# Yuck!
sub reparse {
  my ($self, $gullet, $tokens) = @_;
  # Needs neutralization, since the keyvals may have been tokenized already???
  # perhaps a better test would involve whether $tokens is, in fact, Tokens?
  if (($$self{type} eq 'Plain') || $$self{undigested}) {    # Gack!
    return $tokens; }
  elsif ($$self{semiverbatim}) {                            # Needs neutralization
    return $tokens->neutralize(@{ $$self{semiverbatim} }); }    # but maybe specific to catcodes
  else {
    return $gullet->readingFromMouth(LaTeXML::Core::Mouth->new(), sub {    # start with empty mouth
        my ($gulletx) = @_;
        my @tokens = $tokens->unlist;
        if (@tokens    # Strip outer braces from dimensions & friends
          && ($$self{type} =~ /^(?:Number|Dimension|Glue|MuDimension|MuGlue)$/)
          && $tokens[0]->equals(T_BEGIN) && $tokens[-1]->equals(T_END)) {
          shift(@tokens); pop(@tokens); }
        $gulletx->unread(@tokens);    # but put back tokens to be read
        my $value = $self->read($gulletx);
        $gulletx->skipSpaces;
        return $value; }); } }

sub digest {
  my ($self, $stomach, $value, $fordefn) = @_;
  # If semiverbatim, Expand (before digest), so tokens can be neutralized; BLECH!!!!
  if ($$self{semiverbatim}) {
    $STATE->beginSemiverbatim(@{ $$self{semiverbatim} });
    if ((ref $value eq 'LaTeXML::Core::Token') || (ref $value eq 'LaTeXML::Core::Tokens')) {
      $stomach->getGullet->readingFromMouth(LaTeXML::Core::Mouth->new(), sub {
          my ($igullet) = @_;
          $igullet->unread($value);
          my @tokens = ();
          while (defined(my $token = $igullet->readXToken(1, 1))) {
            push(@tokens, $token); }
          $value = Tokens(@tokens);
          $value = $value->neutralize; }); } }
  if (my $pre = $$self{beforeDigest}) {    # Done for effect only.
    &$pre($stomach); }                     # maybe pass extras?
  $value = $value->beDigested($stomach) if (ref $value) && !$$self{undigested};
  if (my $post = $$self{afterDigest}) {    # Done for effect only.
    &$post($stomach); }                    # maybe pass extras?
  $STATE->endSemiverbatim() if $$self{semiverbatim};    # Corner case?
  return $value; }

sub revert {
  my ($self, $value) = @_;
  if (my $reverter = $$self{reversion}) {
    return &$reverter($value, @{ $$self{extra} || [] }); }
  else {
    return Revert($value); } }

#======================================================================
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Core::Parameter> - a formal parameter

=head1 DESCRIPTION

Provides a representation for a single formal parameter of L<LaTeXML::Core::Definition>s:
It extends L<LaTeXML::Common::Object>.

=head1 SEE ALSO

L<LaTeXML::Core::Parameters>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
