# /=====================================================================\ #
# |  LaTeXML::BibTeX::Bibliography                                      | #
# | A Parser for .bib files                                             | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #
## no critic (Subroutines::ProhibitExplicitReturnUndef);

package LaTeXML::BibTeX::Bibliography;
use strict;
use warnings;
use LaTeXML::Common::Error;
use LaTeXML::BibTeX::Common::StreamReader;
use LaTeXML::BibTeX::Bibliography::BibString;
use LaTeXML::BibTeX::Bibliography::BibField;
use LaTeXML::BibTeX::Bibliography::BibEntry;

# ======================================================================= #
sub new {
  my ($class, $name, $pathname) = @_;
  my $reader = LaTeXML::BibTeX::Common::StreamReader->newFromLTXML($name, $pathname);
  if (!defined($reader)) {
    Fatal('missing_file', $name, undef, "Unable to open Bibliography file $pathname");
    return undef; }
  return bless {
    name   => $name, pathname => $pathname,
    reader => $reader }, $class; }

sub getName {
  my ($self) = @_;
  return $$self{name}; }

sub getPathname {
  my ($self) = @_;
  return $$self{pathname}; }

# ======================================================================= #
# Characters & General Stuff
# ======================================================================= #

# checks that a character is not a special literal
sub isNotSpecialLiteral {
  my ($char) = @_;
  return
    ($char ne '{')
    && ($char ne '}')
    && ($char ne '=')
    && ($char ne '#')
    && ($char ne ','); }

# checks that a character does not terminate a space character
# and is also not a space
sub isNotSpecialSpaceLiteral {
  my ($char) = @_;
  return
    ($char =~ /[^\s]/)
    && ($char ne '{')
    && ($char ne '}')
    && ($char ne '=')
    && ($char ne '#')
    && ($char ne ','); }

# ======================================================================= #
# Parsing a file
# ======================================================================= #

# reads an entire .bib file into a collection of entries.
# if $evaluate is true-ish, evaluates and substitutes all strings
# context is an initial context for abbreviations
# NOTE: The error handling was quite convoluted
# It isn't quite clear if there is an intention to keep trying to parse upon errors/warnings????
# NOTE: Error handling still messed up;
# are we returning [] cause we got errors, or because bib is empty?
# NOTE: Shouldn't we be able to DEFER the evaluation
# so that the collection of entries doesn't change
# and we don't have to re-read the bibliography repeatedly?
sub readFile {
  my ($self, $evaluate, %context) = @_;
  my $reader = $$self{reader};
  # values to be returned
  my @entries = ();
  while (my $entry = $self->readEntry()) {
    # evaluate if requested
    if ($evaluate) {
      $entry->evaluate(%context);
      if ($entry->getType->getValue eq 'string') {
        my ($content) = @{ $entry->getFields };
        $context{ $content->getName->getValue } =
          $content->getContent; } }
    # we successfully read it!
    push(@entries, $entry); }
  $reader->finalize;
  return [@entries]; }

# ======================================================================= #
# Parsing an entry
# ======================================================================= #

# reads the next bib entry from a source file and return it.
# may return a string in case of an error
sub readEntry {
  my ($self) = @_;
  my $reader = $$self{reader};
  # skip ahead until we have an '@' sign
  my $prev = ' ';
  my ($sr, $sc);
  ($prev, $sr, $sc) = $reader->readCharWhile(
    sub {
      # if the previous character was a space (perhaps linebreak)
      # then start an entry with an '@' sign.
      if ($prev =~ /\s/) {
        return !($_[0] eq '@'); }
      # else keep reading chars
      $prev = $_[0];
      return 1; });
  # read an @ sign
  my ($at) = $reader->readChar;
  return unless defined $at;
  my $locator = $reader->getLocator;
  return Warn('bibtex', 'bibparse', $reader->getLocator, 'expected to find an "@"')
    unless $at eq '@';
  # read the type
  my $type = $self->readLiteral();
  return unless defined $type;
  return Warn('bibtex', 'bibparse', $reader->getLocator, 'expected a non-empty name ')
    unless $type->getValue;
  # read opening brace (for fields)
  my ($obrace) = $reader->readChar;
  return Warn('bibtex', 'bibparse', $reader->getLocator, 'expected an "{"')
    unless defined($obrace) && $obrace eq '{';
  # iterate through the fields
  my @fields = ();
  while (1) {
    $reader->eatSpaces;
    my ($char) = $reader->peekChar;
    return Warn('bibtex', 'bibparse', $reader->getLocator,
      'unexpected end of input while reading entry')
      unless defined($char);
    # if we have a comma, we just need the next field
    # TODO: Ignores multiple following commas
    # TODO: What happens if we have a comma in the first position?
    if ($char eq ',') {
      $reader->eatChar; }
    # if we have a closing brace, we are done
    elsif ($char eq '}') {
      $reader->eatChar;
      last; }
    # else push a field (if we have one)
    else {
      my $field = $self->readField();
      return unless defined $field;
      push(@fields, $field) if defined($field); } }
  # and finish up
  return LaTeXML::BibTeX::Bibliography::BibEntry->new($type, [@fields],
    $locator->merge($reader->getLocator)); }

# ======================================================================= #
# Parsing a Field
# ======================================================================= #

# reads a single field from the input
# with an optional name and content
sub readField {
  my ($self) = @_;
  my $reader = $$self{reader};
  # skip spaces and start reading a field
  $reader->eatSpaces;
  my $locator = $reader->getLocator;
  # if we only have a closing brace
  # we may have tried to read a closing brace
  # so return undef and also no error.
  my ($char) = $reader->peekChar;
  return Warn('bibtex', 'bibparse', $reader->getLocator,
    'unexpected end of input while reading field',)
    unless defined($char);
  return if ($char eq '}' or $char eq ',');
  # STATE: What we are allowed to read next
  my $mayStringNext = 1;
  my $mayConcatNext = 0;
  my $mayEqualNext  = 0;
  # results and if we had an error
  my @content      = ();
  my $hadEqualSign = 0;
  # read until we encounter a , or a closing brace
  while ($char ne ',' && $char ne '}') {
    my $value;
    # if we have an equals sign, remember that we had one
    # and allow only strings next (i.e. the value)
    if ($char eq '=') {
      return Warn('bibtex', 'bibparse', $reader->getLocator, 'unexpected "="')
        unless $mayEqualNext;
      $reader->eatChar;
      $hadEqualSign  = 1;
      $mayStringNext = 1;
      $mayConcatNext = 0;
      $mayEqualNext  = 0; }
    # if we have a concat, allow only strings (i.e. the value) next
    elsif ($char eq '#') {
      return Warn('bibtex', 'bibparse', $reader->getLocator, 'unexpected "#"')
        unless $mayConcatNext;
      $reader->eatChar;
      $mayStringNext = 1;
      $mayConcatNext = 0;
      $mayEqualNext  = 0; }
    # if we had a quote, allow only a concat next
    elsif ($char eq '"') {
      return Warn('bibtex', 'bibparse', $reader->getLocator, 'unexpected \'"\'')
        unless $mayStringNext;
      $value = $self->readQuote();
      return unless defined $value;
      push(@content, $value);
      $mayStringNext = 0;
      $mayConcatNext = 1;
      $mayEqualNext  = 0; }
    # if we had a brace, allow only a concat next
    elsif ($char eq '{') {
      return Warn('bibtex', 'bibparse', $reader->getLocator, 'unexpected \'{\'')
        unless $mayStringNext;
      $value = $self->readBrace();
      return unless defined $value;
      push(@content, $value);
      $mayStringNext = 0;
      $mayConcatNext = 0;
      $mayEqualNext  = !$hadEqualSign; }
    # if we have a literal, allow concat and equals next (unless we already had)
    else {
      return Warn('bibtex', 'bibparse', $reader->getLocator, 'unexpected start of literal')
        unless $mayStringNext;
      $value = $self->readLiteral();
      return unless defined $value;
      push(@content, $value);
      $mayStringNext = 0;
      $mayConcatNext = 1;
      $mayEqualNext  = !$hadEqualSign; }
    $reader->eatSpaces;
    ($char) = $reader->peekChar;
    return Warn('bibtex', 'bibparse', $reader->getLocator,
      'unexpected end of input while reading field')
      unless defined($char); }
  # if we had an equal sign, shift that value
  my $name;
  $name = shift(@content) if ($hadEqualSign);
  return LaTeXML::BibTeX::Bibliography::BibField->new($name, [@content],
    $locator->merge($reader->getLocator)); }

# ======================================================================= #
# Parsing Literals, Quotes & Braces
# ======================================================================= #

# read a keyword until the next special character
# skips spaces at the end, but not at the beginning
sub readLiteral {
  my ($self) = @_;
  my $reader = $$self{reader};
  # get the starting position
  my $locator = $reader->getLocator;
  my $keyword = '';
  my $cache   = '';
  # look at the next character and break if it is a special
  my ($char, $line, $col, $eof) = $reader->readChar;
  return Warn('bibtex', 'bibparse', $reader->getLocator, 'unexpected end of input in literal')
    unless defined($char);
  my $isNotSpecialSpaceLiteral = \&isNotSpecialSpaceLiteral;
  # iterate over sequential non-space sequences
  while (isNotSpecialLiteral($char)) {
    # add spaces from the last round and then non-spaces
    $keyword .= $cache . $char;
    ($cache) = $reader->readCharWhile($isNotSpecialSpaceLiteral);
    $keyword .= $cache;
    # record possible end position and skip more spaces
    ($cache) = $reader->readSpaces;
    # look at the next character and break if it is a special
    ($char, $line, $col, $eof) = $reader->readChar;
    return Warn('bibtex', 'bibparse', $reader->getLocator, 'unexpected end of input in literal')
      unless defined($char); }
  # unread the character that isn't part of the special literal and return
  $reader->unreadChar($char, $line, $col, $eof);
  return LaTeXML::BibTeX::Bibliography::BibString->new('LITERAL', $keyword,
    $locator->merge($reader->getLocator)); }

# read a string of balanced braces from the input
# does not skip any spaces before or after
sub readBrace {
  my ($self) = @_;
  my $reader = $$self{reader};
  # read the first bracket, or die if we are at the end
  my ($char, $line, $col, $eof) = $reader->readChar;
  Warn('bibtex', 'bibparse', $reader->getLocator, 'expected to find an "{"')
    unless defined($char) && $char eq '{';
  # record the starting position of the bracket
  my $locator = $reader->getLocator;
  # setup where we are
  my $result = '';
  my $level  = 1;
  $char = '';
  while ($level) {
    # add the previous character, and read the next one.
    $result .= $char;
    ($char, $line, $col, $eof) = $reader->readChar;
    return Warn('bibtex', 'bibparse', $reader->getLocator, 'unexpected end of input in quote ')
      if $eof;
    # keep count of what level we are in
    if ($char eq '{') {
      $level++; }
    elsif ($char eq '}') {
      $level--; } }
  return LaTeXML::BibTeX::Bibliography::BibString->new('BRACKET', $result,
    $locator->merge($reader->getLocator)); }

# read a quoted quote from reader
# does not skip any spaces
sub readQuote {
  my ($self) = @_;
  my $reader = $$self{reader};
  # read the first quote, or die if we are at the end
  my ($char, $line, $col, $eof) = $reader->readChar;
  return Warn('bibtex', 'bibparse', $reader->getLocator, 'expected to find an \'"\'')
    unless defined($char) && $char eq '"';
  my $locator = $reader->getLocator;
  my $result  = '';
  my $level   = 0;
  while (1) {
    ($char, $line, $col, $eof) = $reader->readChar;
    return Warn('bibtex', 'bibparse', $reader->getLocator, 'unexpected end of input in quote')
      if $eof;
    # if we find a {, or a }, keep track of levels, and don't do anything inside
    if ($char eq '"') {
      last unless $level; }
    elsif ($char eq '{') {
      $level++; }
    elsif ($char eq '}') {
      $level--; }
    $result .= $char; }
  return LaTeXML::BibTeX::Bibliography::BibString->new('QUOTE', $result,
    $locator->merge($reader->getLocator)); }

1;
