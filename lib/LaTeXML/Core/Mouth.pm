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
  $string               = q{}                unless defined $string;
  $options{source}      = "Anonymous String" unless defined $options{source};
  $options{shortsource} = "String"           unless defined $options{shortsource};
  my $self = bless { source => $options{source},
    shortsource    => $options{shortsource},
    fordefinitions => ($options{fordefinitions} ? 1 : 0),
    notes          => ($options{notes} ? 1 : 0),
  }, $class;
  $self->openString($string);
  $self->initialize;
  return $self; }

sub openString {
  my ($self, $string) = @_;
  $$self{string} = $string;
  $$self{buffer} = [(defined $string ? splitLines($string) : ())];
  return; }

sub initialize {
  my ($self) = @_;
  $$self{tongue} = LaTeXML::Core::Mouth::Tongue::new();
  if ($$self{notes}) {
    $$self{note_message} = "Processing " . ($$self{fordefinitions} ? "definitions" : "content")
      . " " . $$self{source};
    NoteBegin($$self{note_message}); }
  if ($$self{fordefinitions}) {
    $$self{saved_at_cc}            = $STATE->lookupCatcode('@');
    $$self{SAVED_INCLUDE_COMMENTS} = $STATE->lookupValue('INCLUDE_COMMENTS');
    $STATE->assignCatcode('@' => CC_LETTER);
    $STATE->assignValue(INCLUDE_COMMENTS => 0); }
  return; }

sub finish {
  my ($self) = @_;
  $$self{buffer} = [];
  $$self{tongue}->finish();
  if ($$self{fordefinitions}) {
    $STATE->assignCatcode('@' => $$self{saved_at_cc});
    $STATE->assignValue(INCLUDE_COMMENTS => $$self{SAVED_INCLUDE_COMMENTS}); }
  if ($$self{notes}) {
    NoteEnd($$self{note_message}); }
  return; }

# This is (hopefully) a platform independent way of splitting a string
# into "lines" ending with CRLF, CR or LF (DOS, Mac or Unix).
# Note that TeX considers newlines to be \r, ie CR, ie ^^M
sub splitLines {
  my ($string) = @_;
  $string =~ s/(?:\015\012|\015|\012)/\r/sg;    #  Normalize remaining
  return split("\r", $string); }                # And split.

sub getNextLine {
  my ($self) = @_;
  return unless scalar(@{ $$self{buffer} });
  my $line = shift(@{ $$self{buffer} });
  return (scalar(@{ $$self{buffer} }) ? $line . "\r" : $line); }    # No CR on last line!

sub hasMoreInput {
  my ($self) = @_;
  return $$self{tongue}->hasMoreInput() || scalar(@{ $$self{buffer} }); }

sub stringify {
  my ($self) = @_;
  my ($l, $c) = $self->getPosition;
  return 'Mouth[<string>@' . $l . 'x' . $c . ']'; }

#**********************************************************************
sub getLocator {
  my ($self, $length) = @_;
  my ($l,    $c)      = $self->getPosition;
  if ($length && ($length < 0)) {
    return "at $$self{shortsource}; line $l col $c"; }
  elsif ($length && (defined $l || defined $c)) {
    my $msg   = "at $$self{source}; line $l col $c";
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
    return "at $$self{source}; line $l col $c"; } }

sub getSource {
  my ($self) = @_;
  return $$self{source}; }

#**********************************************************************
# Read all tokens until a token equal to $until (if given), or until exhausted.
# Returns an empty Tokens list, if there is no input

sub readTokens {
  my ($self, $until) = @_;
  my @tokens = ();
  while (defined(my $token = $self->readToken())) {
    last if $until and $token->getString eq $until->getString;
    push(@tokens, $token); }
  while (@tokens && $tokens[-1]->getCatcode == CC_SPACE) {    # Remove trailing space
    pop(@tokens); }
  return Tokens(@tokens); }

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
