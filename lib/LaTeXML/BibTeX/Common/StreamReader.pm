# /=====================================================================\ #
# |  LaTeXML::BibTeX::Common::StreamReader                              | #
# | A primitive reader for input streams                                | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #
## no critic (Subroutines::ProhibitExplicitReturnUndef);

package LaTeXML::BibTeX::Common::StreamReader;
use strict;
use warnings;
use LaTeXML::Common::Error;
use LaTeXML::Common::Locator;

use Encode;

# 'new' creates a new StreamReader
sub new {
  my ($class) = @_;
  return bless {
    # input and stuff
    IN => undef, encoding => undef, buffer => undef,
    # filename of this reader
    filename => undef,
    # current line information
    line   => '',
    nchars => 0,
    colno  => 0,
    lineno => 0,
    eof    => 0,
    # pushback, contains ($char, $line, $col, $eof)
    pushback => undef
  }, $class; }

# 'newFromFile' creates a new StreamReader from a file.
# Roughly equivalent to:
# my $reader = LaTeXML::BibTeX::Common::StreamReader->new();
# $reader->openFile(@_);
sub newFromFile {
  my ($class, $filename, $encoding) = @_;
  my $reader = $class->new();
  return undef unless $reader->openFile($filename, $encoding);
  return $reader; }

# 'newFromLTXML' creates a new StreamReader from a latexml path.
# Roughly equivalent to:
# my $reader = LaTeXML::BibTeX::Common::StreamReader->new();
# $reader->openLTXML(@_);
sub newFromLTXML {
  my ($class, $name, $path) = @_;
  my $reader = $class->new();
  return undef unless $reader->openLTXML($name, $path);
  return $reader; }

# ===================================================================== #
# Open / Close
# ===================================================================== #

# 'openFile' opens a filename using either either a provided encoding, or an auto-detected one.
sub openFile {
  my ($self, $pathname, $encoding) = @_;
  # make sure that the filename exists
  return 0 if (!-r $pathname);
  return 0 if (!-z $pathname) && (-B $pathname);
  # open filehandle and set encoding
  open($$self{IN}, '<', $pathname) || return 0;
  $$self{buffer}   = [];
  $$self{encoding} = find_encoding($encoding || 'utf-8');
  # reset the state
  $$self{filename} = $pathname;
  $$self{lineno}   = 0;
  $$self{colno}    = 0;
  $$self{line}     = '';
  $$self{nchars}   = 0;
  return 1; }

# 'openString' opens a raw string to be opened
sub openString {
  my ($self, $string) = @_;
  # in case of a string, we can buffer everythint at once
  $$self{buffer} = [splitLines($string)];
  $$self{IN}     = undef;
  # reset all the counters
  $$self{filename} = undef;
  $$self{lineno}   = 0;
  $$self{colno}    = 0;
  $$self{line}     = '';
  $$self{nchars}   = 0;
  return 1; }

# openLTXML opens a file using a latexml path that could either be a file or a 'literal:' path
sub openLTXML {
  my ($self, $name, $path) = @_;
  # if it is a file, open it
  if (-e $path) {
    $self->openFile($path); }
  elsif ($path =~ /^literal:(.*)$/) {
    my ($literal) = ($path =~ m/^literal:(.*)$/);
    $self->openString($literal); }
  else {
    return 0; }
  $$self{filename} = $name if defined($name);
  return 1; }

# 'finalize' closes whatever is still left open by this reader and resets the state.
sub finalize {
  my ($self) = @_;
  # close the input if it exists
  close(\*{ $$self{IN} }) if defined($$self{IN});
  $$self{IN} = undef;
  # reset the state so we can reuse this instance
  $$self{filename} = undef;
  $$self{buffer}   = [];
  $$self{lineno}   = 0;
  $$self{colno}    = 0;
  $$self{line}     = '';
  $$self{nchars}   = 0;
  return; }

# 'getFilename' returns the filename used by this reader or undef.
sub getFilename {
  my ($self) = @_;
  return $$self{filename}; }

# ===================================================================== #
# Reading Primitives
# ===================================================================== #

# 'readChar' reads the next character from this reader and returns a 4-tuple ($char, $lineNo, $colNo, $eof).
# - $char contains the current character or undef
# - $lineNo contains the line number the character came from
# - $colNo contains the column number the character came from
# - $eof contains a boolean indicating if the end of file was reached
sub readChar {
  my ($self) = @_;
  # read our current state
  my $lineNo = $$self{lineno};
  my $colNo  = $$self{colno};
  my $eof    = $$self{eof};
  # if we have some pushback, restore the state of it and return
  my $pushback = $$self{pushback};
  if (defined($pushback)) {
    my ($char, $lineno, $colno, $eofp) = @$pushback;
    $$self{pushback} = undef;
    $$self{lineno}   = $lineno;
    $$self{colno}    = $colno;
    $$self{eof}      = $eofp;
    return (wantarray ? ($char, $lineNo, $colNo, $eofp) : $char); }
  # if we reached the end of the file in a previous run
  # don't bother trying
  return (wantarray ? (undef, $lineNo, $colNo, $eof) : undef) if $$self{eof};
  # if we still have characters left in the line, return those.
  return (wantarray ? (substr($$self{line}, $$self{colno}++, 1), $lineNo, $colNo, $eof) : substr($$self{line}, $$self{colno}++, 1))
    if $colNo < $$self{nchars};
  my $line = $self->readNextLine;
  # no more lines ...
  unless (defined($line)) {
    $$self{eof}   = 1;
    $$self{colno} = 0;
    $$self{lineno}++;
    return (wantarray ? (undef, $lineNo, $colNo, $eof) : undef); }
  $$self{line}   = $line;
  $$self{nchars} = length $line;
  $$self{lineno}++;
  $$self{colno} = 1;
  return (wantarray ? (substr($line, 0, 1), $lineNo, $colNo, $eof) : substr($line, 0, 1)); }

# 'unreadChar' unreads a single read character from this reader so that the next call to readChar (and friends) returns it.
# At most a single unread character at the same time is supported.
sub unreadChar {
  my ($self, $char, $lineNo, $colNo, $eof) = @_;
  # if we did not change any lines, it is sufficient to revert the counter
  # and we do not need to use (potentially expensive) pushback
  my $nextLineNo = $$self{lineno};
  if ($nextLineNo eq $lineNo) {
    $$self{colno} = $colNo; }
  # else we need to revert the current state onto pushback
  # because we can not undo the ->readLine
  else {
    $$self{pushback} =
      [($char, $nextLineNo, $$self{colno}, $$self{eof})];
    $$self{lineno} = $lineNo;
    $$self{colno}  = $colNo;
    $$self{eof}    = $eof; }
  return; }

# 'peekChar' returns the next character that would be read using 'readChar', but does not actually read it.
# It returns a 4-tuple like 'readChar' would.
# This function is essentially equivalent to calling readChar, immediatly followed by an unreadChar.
sub peekChar {
  my ($self) = @_;
  # if we have some pushback, return that immediatly
  # and do not call anything else
  return (wantarray ? @{ $$self{pushback} } : $$self{pushback}[0]) if defined($$self{pushback});
  # read our current state
  my $lineNo = $$self{lineno};
  my $colNo  = $$self{colno};
  my $eof    = $$self{eof};
  # if we have reached the end of the line, we can return now
  # and don't even bother trying anything else
  return (wantarray ? (undef, $lineNo, $colNo, 1) : undef) if $eof;
  # if we still have enough characters on the current line
  # then we can just return the current character
  return (wantarray ? (substr($$self{line}, $colNo, 1), $lineNo, $colNo, $eof) : substr($$self{line}, $colNo, 1))
    if $colNo < $$self{nchars};
  # in all the other cases, we need to do a real readChar, unreadChar
  my @read = $self->readChar;
  $self->unreadChar(@read);
  return (wantarray ? @read : $read[0]); }

# 'readCharWhile' reads characters from the input as long as they match a given function and returns a 4-tuple ($chars, $lineNo, $colNo, $eof).
# - $chars contains the read characters
# - $lineNo contains the line number the last character came from
# - $colNo contains the column number the last character came from
# - $eof contains a boolean indicating if the end of file was reached
sub readCharWhile {
  my ($self, $pred) = @_;
  my ($char, $colno, $lineno, $eof) = $self->readChar;
  my $chars = '';
  # read while we are not at the end of the input
  # and are stil ok w.r.t the filter
  while (defined($char) && &{$pred}($char)) {
    $chars .= $char;
    ($char, $colno, $lineno, $eof) = $self->readChar; }
  # unread whatever is next and put it back on the stack
  $self->unreadChar($char, $colno, $lineno, $eof);
  # and return how many characters we skipped.
  #  return ($chars, $colno, $lineno, $eof); }
  return $chars; }

# 'skipSpaces' discards all spaces from the input.
sub skipSpaces {
  my ($self) = @_;
  # this code is an inline version of:
  # $self->eatCharWhile( sub { $_[0] =~ /\s/; } );
  # read the first character
  my ($char, $colno, $lineno, $eof) = $self->readChar;
  # keep reading while the filter matches
  ($char, $colno, $lineno, $eof) = $self->readChar
    while (defined($char) && $char =~ /\s/);
  # unread whatever is next and put it back on the stack
  $self->unreadChar($char, $colno, $lineno, $eof);
  return; }

# ===================================================================== #
# Reading state
# ===================================================================== #

sub getLocator {
  my ($self) = @_;
  return LaTeXML::Common::Locator->new($$self{filename}, $$self{lineno}, $$self{colno}); }

# ===================================================================== #
# Reading lines
# ===================================================================== #

# 'readNextLine' returns a line representing the next line read from the input.
# Returns either a string terminating with '\n' or undef (if no more lines exist).
sub readNextLine {
  my ($self) = @_;
  unless (@{ $$self{buffer} }) {
    return
      unless $$self{IN};    # if we did not have an open file, return undef
    my $fh   = \*{ $$self{IN} };
    my $line = <$fh>;
    return unless defined $line;
    $$self{buffer} = [splitLines($$self{encoding}->decode($line))]; }
  # add the '\n' to the end of the line
  return (shift(@{ $$self{buffer} }) || '') . "\n"; }

# This is (hopefully) a platform independent way of splitting a string
# into "lines" ending with CRLF, CR or LF (DOS, Mac or Unix).
sub splitLines {
  my ($string) = @_;
  $string =~ s/(?:\015\012|\015|\012)/\n/sg;
  return split("\n", $string); }

1;
