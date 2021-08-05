# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Bibliography::BibParser                     | #
# | A Parser for .bib files                                             | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #
## no critic (Subroutines::ProhibitExplicitReturnUndef);

package LaTeXML::Post::BiBTeX::BibStyle::StyParser;
use strict;
use warnings;

use LaTeXML::Post::BiBTeX::BibStyle::StyString;
use LaTeXML::Post::BiBTeX::BibStyle::StyCommand;

use base qw(Exporter);
our @EXPORT = (
  qw( &readFile &readCommand ),
  qw( &readAny &readBlock ),
  qw( &readNumber &readReference &readLiteral &readQuote ),
);

# eats all spaces or comments
sub eatSpacesOrComments {
  my ($reader) = @_;
  my ($char);
  while (1) {
    # eat spaces and check if there is a % comment char
    $reader->eatSpaces;
    ($char) = $reader->peekChar;
    # return if we are not '%'
    last unless defined($char);
    last unless $char eq '%';
    # skip until a new line happens
    $reader->eatCharWhile(sub { $_[0] ne "\n" }); }
  return; }

# ======================================================================= #
# Parsing Commands
# ======================================================================= #

# read a .bst file and return the list of entries
# is not smart, and returns the first error if it can not understand the file
sub readFile {
  my ($reader) = @_;
  my @commands = ();
  my ($command, $commandError, $commandLocation);
  # reads commands
  while (1) {
    ($command, $commandError, $commandLocation) = readCommand($reader);
    return $command, $commandError, $commandLocation
      if defined($commandError);
    last unless defined($command);
    push(@commands, $command); }
  # and return them
  return [@commands]; }

# commands and how many arguments
our %COMMANDS = (
  ENTRY    => 3,
  EXECUTE  => 1,
  FUNCTION => 2,
  INTEGERS => 1,
  ITERATE  => 1,
  MACRO    => 2,
  READ     => 0,
  REVERSE  => 1,
  SORT     => 0,
  STRINGS  => 1);

# read a single command from the input
# if it exists
sub readCommand {
  my ($reader) = @_;
  # skip spaces, and check that we have something left to read
  eatSpacesOrComments($reader);
  my ($char) = $reader->peekChar;
  return undef, undef, undef unless defined($char);
  # read the command name
  my ($name, $nameError, $nameLocation) = readLiteral($reader);
  return $name, $nameError, $nameLocation if defined($nameError);
  # figure out how many argumeents the command takes
  my $command = $name->getValue;
  return undef, 'unknown command ' . $command, $reader->getPosition
    unless exists($COMMANDS{$command});
  $command = $COMMANDS{$command};
  # and read them
  my @arguments = ();
  my ($argument, $argumentError, $argumentLocation);
  if ($command > 0) {
    foreach my $i (1 .. $command) {
      eatSpacesOrComments($reader);
      ($argument, $argumentError, $argumentLocation) =
        readBlock($reader);
      return $argument, $argumentError, $argumentLocation
        if defined($argumentError);
      push(@arguments, $argument); } }
  # get the ending position of the last arguments
  my ($uua, $uub, $uuc);
  my ($fn, $sr, $sc, $er, $ec) = @{ $name->getSource };
  ($uua, $uub, $uuc, $er, $ec) = @{ $argument->getSource } if defined($argument);
  return LaTeXML::Post::BiBTeX::BibStyle::StyCommand->new($name, [@arguments],
    [($fn, $sr, $sc, $er, $ec)]); }

# ======================================================================= #
# Parsing Blocks
# ======================================================================= #

# read any valid code from the sty file
sub readAny {
  my ($reader) = @_;
  # peek at the next char
  my ($char, $sr, $sc) = $reader->peekChar;
  return undef, 'unexpected end of input while reading', $reader->getPosition
    unless defined($char);
  # check what it is
  if ($char eq '#') {
    return readNumber($reader); }
  elsif ($char eq "'") {
    return readReference($reader); }
  elsif ($char eq '"') {
    return readQuote($reader); }
  elsif ($char eq '{') {
    return readBlock($reader); }
  else {
    return readLiteral($reader); } }

sub readBlock {
  my ($reader) = @_;
  # read the opening brace
  my ($char, $sr, $sc) = $reader->readChar;
  return undef, 'expected "{" while reading block', $reader->getPosition
    unless defined($char) && $char eq '{';
  my @values = ();
  my ($value, $valueError, $er, $ec);
  eatSpacesOrComments($reader);
  # if the next char is '}', finish
  ($char, $er, $ec) = $reader->peekChar;
  return undef, 'unexpected end of input while reading block',
    $reader->getPosition
    unless defined($char);
  # read until we find a closing brace
  while ($char ne '}') {
    ($value, $valueError) = readAny($reader);
    return $value, $valueError if defined($valueError);
    push(@values, $value);

    # skip all the spaces and read the next character
    eatSpacesOrComments($reader);
    ($char, $er, $ec) = $reader->peekChar;
    return undef, 'unexpected end of input while reading block',
      $reader->getPosition
      unless defined($char); }
  $reader->eatChar;
  # we can add +1, because we did not read a \n
  my $fn = $reader->getFilename;
  return LaTeXML::Post::BiBTeX::BibStyle::StyString->new('BLOCK', [@values],
    [($fn, $sr, $sc, $er, $ec + 1)]); }

# reads a number, consisting of numbers, from the input
sub readNumber {
  my ($reader) = @_;
  # read anything that's not a space
  my ($char, $sr, $sc) = $reader->readChar;
  return undef, 'expected "#" while reading number ', $reader->getPosition
    unless defined($char) && $char eq '#';
  my ($sign) = $reader->peekChar;
  return undef, 'unexpected end of input while reading number',
    $reader->getPosition
    unless defined($sign);

  if ($sign eq '-' or $sign eq '+') {
    $reader->eatChar; }
  else {
    $sign = ''; }
  my ($literal, $er, $ec) =
    $reader->readCharWhile(sub { $_[0] =~ /\d/; });
  return undef, 'expected a non-empty number', $reader->getPosition
    if $literal eq "";
  my $fn = $reader->getFilename;
  return LaTeXML::Post::BiBTeX::BibStyle::StyString->new(
    'NUMBER',
    ($sign . $literal) + 0,
    [($fn, $sr, $sc, $er, $ec)]
    ); }

# Reads a reference, delimited by spaces, from the input
sub readReference {
  my ($reader) = @_;
  my ($char, $sr, $sc) = $reader->readChar;
  return undef, 'expected "\'" while reading reference', $reader->getPosition
    unless defined($char) && $char eq "'";
  # read anything that's not a space and not the end of a block
  my ($reference, $er, $ec) =
    $reader->readCharWhile(sub { $_[0] =~ /[^%\s\}]/; });
  return undef, 'expected a non-empty argument', $reader->getPosition
    if $reference eq "";
  my $fn = $reader->getFilename;
  return LaTeXML::Post::BiBTeX::BibStyle::StyString->new('REFERENCE', $reference,
    [($fn, $sr, $sc, $er, $ec)]); }

# Reads a literal, delimited by spaces, from the input
sub readLiteral {
  my ($reader) = @_;
  # read anything that's not a space or the boundary of a block
  my ($sr, $sc) = $reader->getPosition;
  my ($literal, $er, $ec) =
    $reader->readCharWhile(sub { $_[0] =~ /[^%\s\{\}]/; });
  return undef, 'expected a non-empty literal', $reader->getPosition
    unless $literal;
  my $fn = $reader->getFilename;
  return LaTeXML::Post::BiBTeX::BibStyle::StyString->new('LITERAL', $literal,
    [($fn, $sr, $sc, $er, $ec)]); }

# read a quoted quote from reader
# does not skip any spaces
sub readQuote {
  my ($reader) = @_;
  # read the first quote, or die if we are at the end
  my ($char, $line, $col, $eof) = $reader->readChar;
  return undef, 'expected to find an \'"\'', $reader->getPosition
    unless defined($char) && $char eq '"';
  # record the starting position and read until the next quote
  my ($sr, $sc) = ($line, $col);
  my ($result) = $reader->readCharWhile(sub { $_[0] =~ /[^"]/ });
  return undef, 'unexpected end of input in quote', $reader->getPosition
    if $eof;
  # read the end quote, or die if we are at the end
  ($char, $line, $col, $eof) = $reader->readChar;
  return undef, 'expected to find an \'"\'', $reader->getPosition
    unless defined($char) && $char eq '"';
  # we can add a +1 here, because we did not read a \n
  my $fn = $reader->getFilename;
  return LaTeXML::Post::BiBTeX::BibStyle::StyString->new('QUOTE', $result,
    [($fn, $sr, $sc, $line, $col + 1)]); }

1;
