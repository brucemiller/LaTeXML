# /=====================================================================\ #
# |  LaTeXML::Core::Mouth                                               | #
# | Analog of TeX's Mouth: Tokenizes strings & files                    | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Mouth;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Core::Token;
use LaTeXML::Core::Tokens;
use LaTeXML::Util::Pathname;
use base qw(LaTeXML::Common::Object);

# Factory method;
# Create an appropriate Mouth
# options are
#  quiet,
#  atletter,
#  content
sub create {
  my ($class, $source, %options) = @_;
  if ($options{content}) {    # we've cached the content of this source
    my ($dir, $name, $ext) = pathname_split($source);
    $options{source}      = $source;
    $options{shortsource} = "$name.$ext";
    return $class->new($options{content}, %options); }
  elsif ($source =~ s/^literal://) {    # we've supplied literal data
    $options{source} = "Literal String " . substr($source, 0, 10) unless defined $options{source};
    return $class->new($source, %options); }
  elsif (!defined $source) {
    return $class->new('', %options); }
  else {
    my $type     = pathname_protocol($source);
    my $newclass = "LaTeXML::Core::Mouth::$type";
    if (!$newclass->can('new')) {       # not already defined somewhere?
      require "LaTeXML/Core/Mouth/$type.pm"; }    # Load it!
    return $newclass->new($source, %options); } }

sub new {
  my ($class, $string, %options) = @_;
  $string = q{} unless defined $string;
  my $source      = (defined $options{source}      ? $options{source}      : "Anonymous String");
  my $shortsource = (defined $options{shortsource} ? $options{shortsource} : "String");
  return $class->initialize(source => $source, shortsource => $shortsource, content => $string,
    fordefinitions => ($options{fordefinitions} ? 1 : 0),
    notes          => ($options{notes}          ? 1 : 0)); }

sub initialize {
  my ($class, %options) = @_;
  my $saved_state = ($options{fordefinitions}
    ? [$STATE->lookupCatcode('@'), $STATE->lookupValue('INCLUDE_COMMENTS')]
    : undef);
  my $note_message = ($options{notes}
    ? "Processing " . ($options{fordefinitions} ? "definitions" : "content")
      . " " . $options{source}
    : '');
  my $self = LaTeXML::Core::Mouth::new_internal(
    (defined $options{source}      ? $options{source}      : ''),
    (defined $options{shortsource} ? $options{shortsource} : ''),
    (defined $options{content}     ? $options{content}     : ''),
    $saved_state, $note_message);
  NoteBegin($note_message) if $note_message;
  if ($options{fordefinitions}) {
    $STATE->assignCatcode('@' => CC_LETTER);
    $STATE->assignValue(INCLUDE_COMMENTS => 0); }
  return $self; }

sub finish {
  my ($self) = @_;
  if (my $saved_state = $self->getSavedState) {
    my ($atcc, $comments) = @$saved_state;
    $STATE->assignCatcode('@' => $atcc);
    $STATE->assignValue(INCLUDE_COMMENTS => $comments); }
  if (my $message = $self->getNoteMessage) {
    NoteEnd($message); }
  $self->finish_internal();
  return; }

sub getNextLine {
  return; }

sub stringify {
  my ($self) = @_;
  my ($l, $c) = $self->getPosition;
  return 'Mouth[<string>@' . $l . 'x' . $c . ']'; }

#**********************************************************************
sub getLocator {
  my ($self, $length) = @_;
  my ($l,    $c)      = $self->getPosition;
  if ($length && ($length < 0)) {
    return "at " . $self->getShortSource . "; line $l col $c"; }
  elsif ($length && (defined $l || defined $c)) {
    my $msg   = "at " . $self->getSource . "; line $l col $c";
    my $chars = $$self{chars};
    if (my $n = $$self{nchars}) {
      $c = $n - 1 if $c >= $n;
      my $c0 = ($c > 50      ? $c - 40 : 0);
      my $cm = ($c < 1       ? 0       : $c - 1);
      my $cn = ($n - $c > 50 ? $c + 40 : $n - 1);
      my $p1 = ($c0 <= $cm ? join('', @$chars[$c0 .. $cm]) : ''); chomp($p1);
      my $p2 = ($c <= $cn  ? join('', @$chars[$c .. $cn])  : ''); chomp($p2);
      $msg .= "\n  " . $p1 . "\n  " . (' ' x ($c - $c0)) . '^' . ' ' . $p2; }
    return $msg; }
  else {
    return "at " . $self->getSource . "; line $l col $c"; } }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Mouth> - tokenize the input.

=head1 DESCRIPTION

A C<LaTeXML::Core::Mouth> (and subclasses) is responsible for I<tokenizing>, ie.
converting plain text and strings into L<LaTeXML::Core::Token>s according to the
current category codes (catcodes) stored in the C<LaTeXML::Core::State>.

It extends L<LaTeXML::Common::Object>.

=head2 Creating Mouths

=over 4

=item C<< $mouth = LaTeXML::Core::Mouth->create($source, %options); >>

Creates a new Mouth of the appropriate class for reading from C<$source>.

=item C<< $mouth = LaTeXML::Core::Mouth->new($string, %options); >>

Creates a new Mouth reading from C<$string>.

=back

=head2 Methods

=over 4

=item C<< $token = $mouth->readToken; >>

Returns the next L<LaTeXML::Core::Token> from the source.

=item C<< $boole = $mouth->hasMoreInput; >>

Returns whether there is more data to read.

=item C<< $string = $mouth->getLocator($long); >>

Return a description of current position in the source, for reporting errors.

=item C<< $tokens = $mouth->readTokens($until); >>

Reads tokens until one matches C<$until> (comparing the character, but not catcode).
This is useful for the C<\verb> command.

=item C<< $lines = $mouth->readRawLine; >>

Reads a raw (untokenized) line from C<$mouth>, or undef if none is found.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
