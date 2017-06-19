# /=====================================================================\ #
# |  LaTeXML::Core::Mouth::file                                         | #
# | Analog of TeX's Mouth: for reading from files                       | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Mouth::file;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Error;
use LaTeXML::Util::Pathname;
use Encode;
use base qw(LaTeXML::Core::Mouth);

sub new {
  my ($class, $pathname, %options) = @_;
  my ($dir,   $name,     $ext)     = pathname_split($pathname);
  my $IN;
  my $self = undef;    # ?!?!?!?!?!
  if (!-r $pathname) {
    Fatal('I/O', 'unreadable', $self, "File $pathname is not readable."); }
  elsif ((!-z $pathname) && (-B $pathname)) {
    Fatal('invalid', 'binary', $self, "Input file $pathname appears to be binary."); }
  open($IN, '<', $pathname)
    || Fatal('I/O', 'open', $self, "Can't open $pathname for reading", $!);
  local $/ = undef;
  my $content = <$IN>;
  close($IN);
  return $class->initialize(source => $pathname, shortsource => "$name.$ext", content => $content,
    fordefinitions => $options{fordefinitions}, notes => $options{notes}); }

sub getNextLine {
  return; }

sub stringify {
  my ($self) = @_;
  my ($l, $c) = $self->getPosition;
  return 'Mouth[' . $self->getSource . '@' . $l . 'x' . $c . ']'; }
#======================================================================
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Core::Mouth::file> - tokenize the input from a file

=head1 DESCRIPTION

A C<LaTeXML::Core::Mouth> (and subclasses) is responsible for I<tokenizing>, ie.
converting plain text and strings into L<LaTeXML::Core::Token>s according to the
current category codes (catcodes) stored in the C<LaTeXML::Core::State>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
