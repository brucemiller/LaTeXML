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
  my $self = bless { source => $pathname, shortsource => "$name.$ext" }, $class;
  $$self{fordefinitions} = 1 if $options{fordefinitions};
  $$self{notes}          = 1 if $options{notes};
  $self->openFile($pathname);
  $self->initialize;
  return $self; }

sub openFile {
  my ($self, $pathname) = @_;
  my $IN;
  if (!-r $pathname) {
    Fatal('I/O', $pathname, $self, "File $pathname is not readable."); }
  elsif ((!-z $pathname) && (-B $pathname)) {
    Fatal('I/O', $pathname, $self, "Input file $pathname appears to be binary."); }
  open($IN, '<', $pathname)
    || Fatal('I/O', $pathname, $self, "Can't open $pathname for reading", $!);
  $$self{IN}     = $IN;
  $$self{buffer} = [];
  return; }

sub finish {
  my ($self) = @_;
  $self->SUPER::finish;
  if ($$self{IN}) {
    close(\*{ $$self{IN} }); $$self{IN} = undef; }
  return; }

sub hasMoreInput {
  my ($self) = @_;
  #  ($$self{colno} < $$self{nchars}) || $$self{IN}; }
  return ($$self{colno} < $$self{nchars}) || scalar(@{ $$self{buffer} }) || $$self{IN}; }

sub getNextLine {
  my ($self) = @_;
  if (!scalar(@{ $$self{buffer} })) {
    return unless $$self{IN};
    my $fh   = \*{ $$self{IN} };
    my $line = <$fh>;
    if (!defined $line) {
      close($fh); $$self{IN} = undef;
      return; }
    else {
      push(@{ $$self{buffer} }, LaTeXML::Core::Mouth::splitLines($line)); } }

  my $line = (shift(@{ $$self{buffer} }) || '');
  if ($line) {
    if (my $encoding = $STATE->lookupValue('PERL_INPUT_ENCODING')) {
     # Note that if chars in the input cannot be decoded, they are replaced by \x{FFFD}
     # I _think_ that for TeX's behaviour we actually should turn such un-decodeable chars in to space(?).
      $line = decode($encoding, $line, Encode::FB_DEFAULT);
      if ($line =~ s/\x{FFFD}/ /g) {    # Just remove the replacement chars, and warn (or Info?)
        Info('misdefined', $encoding, $self, "input isn't valid under encoding $encoding"); } } }
  $line .= "\r";                        # put line ending back!

  if (!($$self{lineno} % 25)) {
    NoteProgressDetailed("[#$$self{lineno}]"); }
  return $line; }

sub stringify {
  my ($self) = @_;
  return "Mouth[$$self{source}\@$$self{lineno}x$$self{colno}]"; }

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
