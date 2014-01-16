# /=====================================================================\ #
# |  LaTeXML::Core::Comment                                             | #
# | Digested objects produced in the Stomach                            | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Core::Comment;
use strict;
use warnings;
use LaTeXML::Global;
use base qw(LaTeXML::Core::Box);

sub revert   { return (); }
sub toString { return ''; }

sub beAbsorbed {
  my ($self, $document) = @_;
  return $document->insertComment($$self[0]); }

sub getWidth  { return Dimension(0); }
sub getHeight { return Dimension(0); }
sub getDepth  { return Dimension(0); }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Comment> - Representations of digested objects.

=head1 DESCRIPTION

=begin latex

\label{LaTeXML::Core::Comment}

=end latex

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
