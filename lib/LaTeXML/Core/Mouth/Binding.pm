# /=====================================================================\ #
# |  LaTeXML::Core::Mouth::Binding                                      | #
# | Analog of TeX's Mouth: Tokenizes strings & files                    | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Mouth::Binding;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Error;
use LaTeXML::Util::Pathname;
use base qw(LaTeXML::Core::Mouth);

# This is a fake mouth, used for processing *.ltxml, *.latexml files
# It exists primarily for the purposes of
#  * getting a locator on anything defined in the file
#  * serving as a placekeeper in the chain of Mouth's in a Gullet,
#    when the binding reads in a proper TeX file.

sub new {
  my ($class, $pathname) = @_;
  my ($dir, $name, $ext) = pathname_split($pathname);
  return $class->initialize(source => $pathname, shortsource => "$name.$ext", notes => 1); }

# Evolve to figure out if this gets dynamic location!
sub getLocator {
  my ($self, $length) = @_;
  return "I'm Lost!";
  my $path  = $self->getSource;
  my $loc   = ($length && $length < 0 ? $self->getShortSource : $self->getSource);
  my $frame = 2;
  my ($pkg, $file, $line);
  while (($pkg, $file, $line) = caller($frame++)) {
    last if $file eq $path; }
  return $loc . ($line ? " line $line" : ''); }

sub hasMoreInput {
  return 0; }

sub stringify {
  my ($self) = @_;
  return "Mouth::Binding[" . $self->getSource . "]"; }
#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Mouth::Binding> - a fake Mouth for processing a Binding file

=head1 DESCRIPTION

This is a fake mouth, used for processing binding files
(ie. C<*.ltxml> and C<*.latexml>). It exists primarily for the purposes of
(1) getting a locator on anything defined in the file
and (2) serving as a placekeeper in the chain of Mouth's in a Gullet,
when the binding reads in a proper TeX file.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
