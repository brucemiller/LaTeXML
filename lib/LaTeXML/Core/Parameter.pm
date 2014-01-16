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
use base qw(LaTeXML::Object);

sub new {
  my ($class, $spec, %options) = @_;
  return bless { spec => $spec, %options }, $class; }

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
    StartSemiverbatim(); }
  my $value = &{ $$self{reader} }($gullet, @{ $$self{extra} || [] });
  $value = $value->neutralize if $$self{semiverbatim} && (ref $value)
    && $value->can('neutralize');
  if ($$self{semiverbatim}) {
    EndSemiverbatim(); }
  return $value; }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Parameter> - a formal parameter

=head1 DESCRIPTION

Provides a representation for a single formal parameter of L<LaTeXML::Core::Definition>s:


=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
