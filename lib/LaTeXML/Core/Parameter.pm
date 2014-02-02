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
  my ($self, $gullet) = @_;
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
