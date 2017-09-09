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
sub XXXTokens {
  my (@tokens) = @_;
  my $r;
   return bless [map { (($r = ref $_) eq 'LaTeXML::Core::Token' ? $_
         : ($r eq 'LaTeXML::Core::Tokens' ? @$_
          : Fatal('misdefined', $r, undef, "Expected a Token, got " . Stringify($_)))) }
      @tokens], 'LaTeXML::Core::Tokens'; }

sub ZZTokens {
  my (@tokens) = @_;
  print STDERR "Creating tokens from: ".join(',',@tokens)." = ".join(',',map { Stringify($_) } @tokens)."\n";
  my $t = XXTokens(@tokens);
  print STDERR "GOT $t\n";
  print STDERR " ==> ".Stringify($t)."\n";
  return $t; }
#======================================================================
sub stringify {
  my ($self) = @_;
  return "Tokens[" . join(',', map { $_->toString } $self->unlist) . "]"; }

sub beDigested {
  my ($self, $stomach) = @_;
  return $stomach->digest($self); }

sub neutralize {
  my ($self, @extraspecials) = @_;
  return Tokens(map { $_->neutralize(@extraspecials) } $self->unlist); }

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

