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
  return bless { spec => $spec, type => $type, %{$descriptor}, %options }, $class; }

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

sub read {
  my ($self, $gullet, $fordefn) = @_;
  # For semiverbatim, I had messed with catcodes, but there are cases
  # (eg. \caption(...\label{badchars}}) where you really need to
  # cleanup after the fact!
  # Hmmm, seem to still need it...
  if ($$self{semiverbatim}) {
    # Nasty Hack: If immediately followed by %, should discard the comment
    # EVEN if semiverbatim makes % into other!
    if (my $peek = $gullet->readToken) { $gullet->unread($peek); }
    $STATE->beginSemiverbatim(); }
  my $value = &{ $$self{reader} }($gullet, @{ $$self{extra} || [] });
  $value = $value->neutralize if $$self{semiverbatim} && (ref $value)
    && $value->can('neutralize');
  if ($$self{semiverbatim}) {
    $STATE->endSemiverbatim(); }
  if ((!defined $value) && !$$self{optional}) {
    Error('expected', $self, $gullet,
      "Missing argument " . Stringify($self) . " for " . Stringify($fordefn),
      $gullet->showUnexpected);
    $value = T_OTHER('missing'); }
  return $value; }

sub digest {
  my ($self, $stomach, $value, $fordefn) = @_;
  # If semiverbatim, Expand (before digest), so tokens can be neutralized; BLECH!!!!
  if ($$self{semiverbatim}) {
    $STATE->beginSemiverbatim();
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
