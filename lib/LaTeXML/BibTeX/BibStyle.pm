# /=====================================================================\ #
# |  LaTeXML::BibTeX::BibStyle.                                         | #
# | A Parser for .bst files                                             | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #
## no critic (Subroutines::ProhibitExplicitReturnUndef);

package LaTeXML::BibTeX::BibStyle;
use strict;
use warnings;
use LaTeXML::Common::Error;
use LaTeXML::Util::Pathname;
use LaTeXML::BibTeX::Common::StreamReader;
use LaTeXML::BibTeX::BibStyle::StyString;
use LaTeXML::BibTeX::BibStyle::StyCommand;

# compiles the bst file or errors out
## sub compileBst {
##   my ($self, $doc, $style) = @_;
sub new {
  my ($class, $style, $searchpaths) = @_;
  # try to find the bst file, if not fallback to a precompiled one
  my $bstfile = pathname_find($style, paths => $searchpaths, types => ['bst'])
    || pathname_kpsewhich("$style.bst");
  Debug("BEAST $style => " . ($bstfile || '<notfound>'));
  my $bibstyle;
  if (defined($bstfile)) {
    # we found the file => open it
    eval {
      my $reader = LaTeXML::BibTeX::Common::StreamReader->newFromLTXML($style, $bstfile);
      Fatal('missing_file', $style, undef, "Unable to open Bibliography Style File $bstfile")
        unless (defined($reader));
      my $stage = "Reading bst file";
      ProgressSpinup($stage);
      $bibstyle = readFile($reader);
      $reader->finalize;
      ProgressSpindown($stage); }; }
  if (!defined $bibstyle) {
    # we did not find it => fallback to the default
    Warn('missing_file', $style, undef,
      "Can't find Bibliography Style '$style'; Using builtin default");
    require LaTeXML::BibTeX::BibStyle::Precompiled;
    $bibstyle = $LaTeXML::BibTeX::BibStyle::Precompiled::DEFAULT; }
  return bless {
    name    => $style, pathname => $bstfile,
    program => $bibstyle }, $class; }

sub getStyle {
  my ($self) = @_;
  return $$self{name}; }

sub getProgram {
  my ($self) = @_;
  return $$self{program}; }

# ======================================================================= #
# Parsing Commands
# ======================================================================= #

# read a .bst file and return the list of entries
# is not smart, and returns the first error if it can not understand the file
sub readFile {
  my ($reader) = @_;
  my @commands = ();
  # reads commands
  while (my $command = readCommand($reader)) {
    push(@commands, $command); }
  return [@commands]; }

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

# commands and how many arguments
our %COMMAND_ARGS = (
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
  return unless defined($char);
  # read the command name
  my $name = readLiteral($reader);
  return unless $name;
  # figure out how many argumeents the command takes
  my $command = $name->getValue;
  return Error('bibtex', 'bstparse', $reader->getLocator, 'unknown command ' . $command)
    unless exists($COMMAND_ARGS{$command});
  my $nargs = $COMMAND_ARGS{$command};
  # and read them
  my @arguments = ();
  my $argument;
  if ($nargs > 0) {
    foreach my $i (1 .. $nargs) {
      eatSpacesOrComments($reader);
      $argument = readBlock($reader);
      return unless $argument;
      push(@arguments, $argument); } }
  # get the ending position of the last arguments
  my $locator = $name->getLocator;
  $locator = $locator->merge($argument->getLocator) if defined($argument);
  return LaTeXML::BibTeX::BibStyle::StyCommand->new($command, [@arguments], $locator); }
# ======================================================================= #
# Parsing Blocks
# ======================================================================= #

# read any valid code from the sty file
sub readAny {
  my ($reader) = @_;
  # peek at the next char
  my ($char, $sr, $sc) = $reader->peekChar;
  return Error('bibtex', 'bstparse', $reader->getLocator, 'unexpected end of input while reading')
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
  return Error('bibtex', 'bstparse', $reader->getLocator, 'expected "{" while reading block')
    unless defined($char) && $char eq '{';
  my $locator = $reader->getLocator;
  my @values  = ();
  my $value;
  eatSpacesOrComments($reader);
  # if the next char is '}', finish
  ($char) = $reader->peekChar;
  return Error('bibtex', 'bstparse', $reader->getLocator,
    'unexpected end of input while reading block')
    unless defined($char);
  # read until we find a closing brace
  while ($char ne '}') {
    $value = readAny($reader);
    return unless $value;
    push(@values, $value);

    # skip all the spaces and read the next character
    eatSpacesOrComments($reader);
    ($char) = $reader->peekChar;
    return Error('bibtex', 'bstparse', $reader->getLocator,
      'unexpected end of input while reading block')
      unless defined($char); }
  $reader->eatChar;
  # we can add +1, because we did not read a \n
  my $fn = $reader->getFilename;
  return LaTeXML::BibTeX::BibStyle::StyString->new('BLOCK', [@values],
    $locator->merge($reader->getLocator)); }

# reads a number, consisting of numbers, from the input
sub readNumber {
  my ($reader) = @_;
  # read anything that's not a space
  my ($char) = $reader->readChar;
  return Error('bibtex', 'bstparse', $reader->getLocator,
    'expected "#" while reading number ')
    unless defined($char) && $char eq '#';
  my $locator = $reader->getLocator;
  my ($sign) = $reader->peekChar;
  return Error('bibtex', 'bstparse', $reader->getLocator,
    'unexpected end of input while reading number')
    unless defined($sign);

  if ($sign eq '-' or $sign eq '+') {
    $reader->eatChar; }
  else {
    $sign = ''; }
  my ($literal, $er, $ec) =
    $reader->readCharWhile(sub { $_[0] =~ /\d/; });
  return Error('bibtex', 'bstparse', $reader->getLocator, 'expected a non-empty number')
    if $literal eq "";
  my $fn = $reader->getFilename;
  return LaTeXML::BibTeX::BibStyle::StyString->new('NUMBER', ($sign . $literal) + 0,
    $locator->merge($reader->getLocator)); }

# Reads a reference, delimited by spaces, from the input
sub readReference {
  my ($reader) = @_;
  my ($char)   = $reader->readChar;
  return Error('bibtex', 'bstparse', $reader->getLocator,
    'expected "\'" while reading reference')
    unless defined($char) && $char eq "'";
  my $locator = $reader->getLocator;
  # read anything that's not a space and not the end of a block
  my ($reference, $er, $ec) =
    $reader->readCharWhile(sub { $_[0] =~ /[^%\s\}]/; });
  return Error('bibtex', 'bstparse', $reader->getLocator, 'expected a non-empty argument')
    if $reference eq "";
  my $fn = $reader->getFilename;
  return LaTeXML::BibTeX::BibStyle::StyString->new('REFERENCE', $reference,
    $locator->merge($reader->getLocator)); }

# Reads a literal, delimited by spaces, from the input
sub readLiteral {
  my ($reader) = @_;
  # read anything that's not a space or the boundary of a block
  my $locator = $reader->getLocator;
  my ($literal, $er, $ec) =
    $reader->readCharWhile(sub { $_[0] =~ /[^%\s\{\}]/; });
  return Error('bibtex', 'bstparse', $reader->getLocator, 'expected a non-empty literal')
    unless $literal;
  my $fn = $reader->getFilename;
  return LaTeXML::BibTeX::BibStyle::StyString->new('LITERAL', $literal,
    $locator->merge($reader->getLocator)); }

# read a quoted quote from reader
# does not skip any spaces
sub readQuote {
  my ($reader) = @_;
  # read the first quote, or die if we are at the end
  my ($char, $line, $col, $eof) = $reader->readChar;
  return Error('bibtex', 'bstparse', $reader->getLocator, 'expected to find an \'"\'')
    unless defined($char) && $char eq '"';
  my $locator = $reader->getLocator;
  # record the starting position and read until the next quote
  my ($result) = $reader->readCharWhile(sub { $_[0] =~ /[^"]/ });
  return Error('bibtex', 'bstparse', $reader->getLocator, 'unexpected end of input in quote')
    if $eof;
  # read the end quote, or die if we are at the end
  ($char, $line, $col, $eof) = $reader->readChar;
  return Error('bibtex', 'bstparse', $reader->getLocator, 'expected to find an \'"\'')
    unless defined($char) && $char eq '"';
  # we can add a +1 here, because we did not read a \n
  my $fn = $reader->getFilename;
  return LaTeXML::BibTeX::BibStyle::StyString->new('QUOTE', $result,
    $locator->merge($reader->getLocator)); }

#======================================================================

1;
