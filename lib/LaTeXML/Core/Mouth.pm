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
# options are quiet, atletter, content
sub create {
  my ($class, $source, %options) = @_;
  if ($options{content}) {    # we've cached the content of this source
    my ($dir, $name, $ext) = pathname_split($source);
    $options{source}      = $source;
    $options{shortsource} = "$name.$ext";
    return $class->new($options{content}, %options); }
  elsif ($source =~ s/^literal://) {    # we've supplied literal data
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
  $$self{lineno} = 0;
  $$self{colno}  = 0;
  $$self{chars}  = [];
  $$self{nchars} = 0;
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
  $$self{lineno} = 0;
  $$self{colno}  = 0;
  $$self{chars}  = [];
  $$self{nchars} = 0;
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

# This is (hopefully) a correct way to split a line into "chars",
# or what is probably more desired is "Grapheme clusters" (even "extended")
# These are unicode characters that include any following combining chars, accents & such.
# I am thinking that when we deal with unicode this may be the most correct way?
# If it's not the way XeTeX does it, perhaps, it must be that ALL combining chars
# have to be converted to the proper accent control sequences!
sub splitChars {
  my ($line) = @_;
  return $line =~ m/\X/g; }

sub getNextLine {
  my ($self) = @_;
  return unless scalar(@{ $$self{buffer} });
  my $line = shift(@{ $$self{buffer} });
  return (scalar(@{ $$self{buffer} }) ? $line . "\r" : $line); }    # No CR on last line!

sub hasMoreInput {
  my ($self) = @_;
  return ($$self{colno} < $$self{nchars}) || scalar(@{ $$self{buffer} }); }

# Get the next character & it's catcode from the input,
# handling TeX's "^^" encoding.
# Note that this is the only place where catcode lookup is done,
# and that it is somewhat `inlined'.
sub getNextChar {
  my ($self) = @_;
  if ($$self{colno} < $$self{nchars}) {
    my $ch = $$self{chars}[$$self{colno}++];
    my $cc = $$STATE{table}{catcode}{$ch}[0];    # $STATE->lookupCatcode($ch); OPEN CODED!
    if ((defined $cc) && ($cc == CC_SUPER)       # Possible convert ^^x
      && ($$self{colno} + 1 < $$self{nchars}) && ($ch eq $$self{chars}[$$self{colno}])) {
      my ($c1, $c2);
      if (($$self{colno} + 2 < $$self{nchars})    # ^^ followed by TWO LOWERCASE Hex digits???
        && (($c1 = $$self{chars}[$$self{colno} + 1]) =~ /^[0-9a-f]$/)
        && (($c2 = $$self{chars}[$$self{colno} + 2]) =~ /^[0-9a-f]$/)) {
        $ch = chr(hex($c1 . $c2));
        splice(@{ $$self{chars} }, $$self{colno} - 1, 4, $ch);
        $$self{nchars} -= 3; }
      else {                                      # OR ^^ followed by a SINGLE Control char type code???
        my $c  = $$self{chars}[$$self{colno} + 1];
        my $cn = ord($c);
        $ch = chr($cn + ($cn > 64 ? -64 : 64));
        splice(@{ $$self{chars} }, $$self{colno} - 1, 3, $ch);
        $$self{nchars} -= 2; }
      $cc = $STATE->lookupCatcode($ch); }
    $cc = CC_OTHER unless defined $cc;
    return ($ch, $cc); }
  else {
    return (undef, undef); } }

sub stringify {
  my ($self) = @_;
  return "Mouth[<string>\@$$self{lineno}x$$self{colno}]"; }

#**********************************************************************
sub getLocator {
  my ($self, $length) = @_;
  my ($l, $c) = ($$self{lineno}, $$self{colno});
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
# See The TeXBook, Chapter 8, The Characters You Type, pp.46--47.
#**********************************************************************

sub handle_escape {    # Read control sequence
  my ($self) = @_;
  # NOTE: We're using control sequences WITH the \ prepended!!!
  my $cs = "\\";       # I need this standardized to be able to lookup tokens (A better way???)
  my ($ch, $cc) = $self->getNextChar;
  # Knuth, p.46 says that Newlines are converted to spaces,
  # Bit I believe that he does NOT mean within control sequences
  $cs .= $ch;
  if ($cc == CC_LETTER) {    # For letter, read more letters for csname.
    while ((($ch, $cc) = $self->getNextChar) && $ch && ($cc == CC_LETTER)) {
      $cs .= $ch; }
    $$self{colno}--; }
  if (($cc == CC_SPACE) || ($cc == CC_EOL)) {    # We'll skip whitespace here.
                                                 # Now, skip spaces
    while ((($ch, $cc) = $self->getNextChar) && $ch && (($cc == CC_SPACE) || ($cc == CC_EOL))) { }
    $$self{colno}-- if ($$self{colno} < $$self{nchars}); }
  return T_CS($cs); }

sub handle_EOL {
  my ($self) = @_;
  # Note that newines should be converted to space (with " " for content)
  # but it makes nicer XML with occasional \n. Hopefully, this is harmless?
  my $token = ($$self{colno} == 1
    ? T_CS('\par')
    : ($STATE->lookupValue('PRESERVE_NEWLINES') ? Token("\n", CC_SPACE) : T_SPACE));
  $$self{colno} = $$self{nchars};    # Ignore any remaining characters after EOL
  return $token; }

sub handle_space {
  my ($self) = @_;
  my ($ch, $cc);
  # Skip any following spaces!
  while ((($ch, $cc) = $self->getNextChar) && $ch && (($cc == CC_SPACE) || ($cc == CC_EOL))) { }
  $$self{colno}-- if ($$self{colno} < $$self{nchars});
  return T_SPACE; }

sub handle_comment {
  my ($self) = @_;
  my $n = $$self{colno};
  $$self{colno} = $$self{nchars};
  my $comment = join('', @{ $$self{chars} }[$n .. $$self{nchars} - 1]);
  $comment =~ s/^\s+//; $comment =~ s/\s+$//;
  return ($comment && $STATE->lookupValue('INCLUDE_COMMENTS') ? T_COMMENT($comment) : undef); }

# These cache the (presumably small) set of distinct letters, etc
# converted to Tokens.
# Note that this gets filled during runtime and carries over to through Daemon frames.
# However, since the values don't depend on any particular document, bindings, etc,
# they should be safe.
my %LETTER = ();
my %OTHER  = ();
my %ACTIVE = ();

# Dispatch table for catcodes.
my @DISPATCH = (    # [CONSTANT]
  \&handle_escape,    # T_ESCAPE
  T_BEGIN,            # T_BEGIN
  T_END,              # T_END
  T_MATH,             # T_MATH
  T_ALIGN,            # T_ALIGN
  \&handle_EOL,       # T_EOL
  T_PARAM,            # T_PARAM
  T_SUPER,            # T_SUPER
  T_SUB,              # T_SUB
  sub { undef; },     # T_IGNORE (we'll read next token)
  \&handle_space,     # T_SPACE
  sub { $LETTER{ $_[1] } || ($LETTER{ $_[1] } = T_LETTER($_[1])); },    # T_LETTER
  sub { $OTHER{ $_[1] }  || ($OTHER{ $_[1] }  = T_OTHER($_[1])); },     # T_OTHER
  sub { $ACTIVE{ $_[1] } || ($ACTIVE{ $_[1] } = T_ACTIVE($_[1])); },    # T_ACTIVE
  \&handle_comment,                                                     # T_COMMENT
  sub { T_OTHER($_[1]); }    # T_INVALID (we could get unicode!)
);

# Read the next token, or undef if exhausted.
# Note that this also returns COMMENT tokens containing source comments,
# and also locator comments (file, line# info).
# LaTeXML::Core::Gullet intercepts them and passes them on at appropriate times.
sub readToken {
  my ($self) = @_;
  while (1) {    # Iterate till we find a token, or run out. (use return)
                 # ===== Get next line, if we need to.
    if ($$self{colno} >= $$self{nchars}) {
      $$self{lineno}++;
      $$self{colno} = 0;
      my $line = $self->getNextLine;
      if (!defined $line) {    # Exhausted the input.
        $$self{chars}  = [];
        $$self{nchars} = 0;
        return; }
      # Remove trailing space, but NOT a control space!  End with CR (not \n) since this gets tokenized!
      $line =~ s/((\\ )*)\s*$/$1\r/s;
      $$self{chars}  = [splitChars($line)];
      $$self{nchars} = scalar(@{ $$self{chars} });
      while (($$self{colno} < $$self{nchars})
        && (($$STATE{table}{catcode}{ $$self{chars}[$$self{colno}] }[0] || CC_OTHER) == CC_SPACE)) {
        $$self{colno}++; }

      # Sneak a comment out, every so often.
      if ((($$self{lineno} % 25) == 0) && $STATE->lookupValue('INCLUDE_COMMENTS')) {
        return T_COMMENT("**** $$self{shortsource} Line $$self{lineno} ****"); }
    }
    # ==== Extract next token from line.
    my ($ch, $cc) = $self->getNextChar;
    my $token = $DISPATCH[$cc];
    $token = &$token($self, $ch) if ref $token eq 'CODE';
    return $token if defined $token;    # Else, repeat till we get something or run out.
  }
  return; }

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

#**********************************************************************
# Read a raw lines; there are so many variants of how it should end,
# that the Mouth API is left as simple as possible.
sub readRawLine {
  my ($self) = @_;
  my $line;
  if ($$self{colno} < $$self{nchars}) {
    $line = join('', @{ $$self{chars} }[$$self{colno} .. $$self{nchars} - 1]);
    # End lines with \n, not CR, since the result will be treated as strings
    $$self{colno} = $$self{nchars}; }
  else {
    $line = $self->getNextLine;
    if (!defined $line) {
      $$self{chars} = []; $$self{nchars} = 0; $$self{colno} = 0; }
    else {
      $$self{lineno}++;
      $$self{chars}  = [splitChars($line)];
      $$self{nchars} = scalar(@{ $$self{chars} });
      $$self{colno}  = $$self{nchars}; } }
  $line =~ s/\s*$//s if defined $line;    # Is this right?
  return $line; }

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
