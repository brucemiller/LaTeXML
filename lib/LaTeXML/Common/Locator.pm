# /=====================================================================\ #
# |  LaTeXML::Common::Locator                                           | #
# | Locators                                                            | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Locator;
use LaTeXML::Global;
use strict;
use warnings;

use base qw(LaTeXML::Common::Object);

sub new {
    my ($class, $source, $line, $col) = @_;
    return bless { source => $source, line => $line, col => $col}, $class; }

sub toString {
  my ($self) = @_;
  my $loc = defined $$self{source} ? $$self{source} : 'Anonymous String';
  $loc .= "; line $$self{line}" if defined($$self{line});
  $loc .= " col $$self{col}" if defined($$self{line}) && defined($$self{col});
  return $loc; }

sub stringify {
    # TODO: Do we want an 'at' here?
    my ($self) = @_;
    return $self->toString; }

sub getLocator {
    # getting the locator of a locator should return itself
    my $self = @_;
    return $self; }



#**********************************************************************
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Common::Locator> - represents a reference to a single point in a source file

=head1 DESCRIPTION

C<LaTeXML::Common::Locator> contains a reference to a single point within a source file. 
This data structure is intended to be used both programtically (for "source references")
and to display error messages to the user. 

It extends L<LaTeXML::Common::Object>.

=head2 Locator Creation

=over 4

=item C<< $locator = LaTeXML::Common::Locator->new($source, $line, $col); >>

Creates a new locator. C<$source> should be a string containing the full path
of the source file, or undef in case of an anonymous string. C<$line> and
C<$col> should be integers containing the line and column numbers of the
point in the source file, or undef if unknown. 

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>
Tom Wiesing <tom.wiesing@gmail.com>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
