# /=====================================================================\ #
# |  LaTeXML::Core::MathList                                            | #
# | Digested objects produced in the Stomach                            | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Core::MathList;
use strict;
use warnings;
use LaTeXML::Global;
use base qw(LaTeXML::Core::List);

sub isMath {
  return 1; }    # MathList's are math mode.

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::MathList> - Representations of digested objects.

=head1 DESCRIPTION

represents a sequence of digested things in math;

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
