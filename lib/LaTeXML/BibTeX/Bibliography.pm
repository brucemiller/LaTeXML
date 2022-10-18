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
  my $bibliography = bless {
    name     => $name, pathname => $pathname,
    reader   => $reader,
    preamble => [], strings => {} }, $class;
  $bibliography->readFile;
  return $bibliography; }

sub getName {
  my ($self) = @_;
  return $$self{name}; }

sub getPathname {
  my ($self) = @_;
  return $$self{pathname}; }

sub getPreamble {
  my ($self) = @_;
  return @{ $$self{preamble} }; }

sub getEntries {
  my ($self) = @_;
  return @{ $$self{entries} }; }

# ======================================================================= #
# Parsing a file
# ======================================================================= #
# Read the bib file
# makes substitutions of @STRING's within the bib file, but defers .bst macros
sub readFile {
  my ($self) = @_;
  my $reader = $$self{reader};
  # values to be returned
  my @entries = ();
  while (my $type = $self->readEntryType()) {
    my $locator = $reader->getLocator;              # WRONG! should be before type!
    my $begin   = $self->readDelimiter('{', '(');
    if ($type eq 'comment') {
      my $ignore = $self->readValue; }
    elsif ($type eq 'preamble') {                   # just a string (possibly interpolated)
      my $pre = $self->readValue;
      push(@{ $$self{preamble} }, (ref $pre eq 'ARRAY' ? @$pre : $pre)); }
    elsif ($type eq 'string') {
      my $name = $self->readKeyword;
      $self->readDelimiter('=');
      my $value = $self->readValue;
      $$self{strings}{ lc $name } = $value; }
    else {                                          # Random bibliographic entry
      my $key    = $self->readKeyword;
      my @fields = ();                              # !!!! key is 1st field!!!!! Bad!
      while (defined(my $char = $reader->peekChar)) {
        last if ($char ne ',');
        $reader->readChar;
        $reader->skipSpaces;
        my $name = $self->readKeyword;
        next unless $name;
        last unless $self->readDelimiter('=');
        my $value = $self->readValue();
        push(@fields, LaTeXML::BibTeX::Bibliography::BibField->new(lc($name), $value,
            $locator->merge($reader->getLocator))); }
      push(@entries, LaTeXML::BibTeX::Bibliography::BibEntry->new(lc($type), $key, [@fields],
          $locator->merge($reader->getLocator))); }
    $self->readDelimiter(($begin eq '{' ? '}' : ')')); }    # closing } or ) of entry
  $reader->finalize;
  $$self{entries} = [@entries];
  return $self; }

sub readDelimiter {
  my ($self, @expected) = @_;
  my $reader = $$self{reader};
  $reader->skipSpaces;
  my $char = $reader->peekChar;
  if ((defined $char) && grep { $char eq $_; } @expected) {
    $reader->readChar;
    return $char; }
  Warn('bibtex', 'bibparse', $reader->getLocator,
    'unexpected ' . (scalar(@expected) > 1 ? 'one of ' : '') . join(' ', map { "'$_'"; } @expected));
  return; }

# ======================================================================= #
# Parsing an entry
# ======================================================================= #

# reads the next @command name from the bib file
sub readEntryType {
  my ($self) = @_;
  my $reader = $$self{reader};
  my $char;
  do {    # Skip till '@'
    $char = $reader->readChar;
  } while (defined $char) && ($char ne '@');
  return unless defined $char;
  my $type = $self->readKeyword();
  return Warn('bibtex', 'bibparse', $reader->getLocator, 'expected a non-empty name ')
    unless $type;
  return lc($type); }

# ======================================================================= #
# Parsing a Value
# ======================================================================= #

# reads a string-like value, possibly concatenated and with literals for @strings or macros
# returns an ARRAY !!!
# Needs a lot of cleanup, & folding...
sub readValue {
  my ($self) = @_;
  my $reader = $$self{reader};
  # skip spaces and start reading a field
  $reader->skipSpaces;
  my $locator = $reader->getLocator;
  # if we only have a closing brace
  # we may have tried to read a closing brace
  # so return undef and also no error.
  my $char = $reader->peekChar;
  return Warn('bibtex', 'bibparse', $reader->getLocator,
    'unexpected end of input while reading field',)
    unless defined($char);
  return if ($char eq '}' or $char eq ',');
  # results and if we had an error
  my @content = ();
  # read until we encounter a , or a closing brace
  while ($char ne ',' && $char ne '}') {
    # Read some kind of value (quoted, braced, literal)
    if ($char eq '"') {
      my $value = $self->readQuoted();
      return unless defined $value;
      push(@content, $value); }
    # if we had a brace, allow only a concat next
    elsif ($char eq '{') {
      my $value = $self->readBraced();
      return unless defined $value;
      push(@content, $value); }
    else {
      my $value = $self->readLiteral();
      return unless defined $value;
      if (my $s = $value && $$self{strings}{ lc $value->getValue }) {    # Maybe substitute @STRING
        $value = $s; }
      push(@content, (ref $value eq 'ARRAY' ? @$value : $value)); }
    # Now look next for possible concatenation
    $reader->skipSpaces;
    $char = $reader->peekChar;
    last unless $char eq '#';
    $reader->readChar;
    $reader->skipSpaces;
    $char = $reader->peekChar; }
  return [@content]; }

# ======================================================================= #
# Parsing Literals, Quotes & Braces
# ======================================================================= #
our %literal_specials = ('{' => 1, '}' => 1, '=' => 1, '#' => 1, ',' => 1);

sub readKeyword {
  my ($self) = @_;
  my $reader = $$self{reader};
  # get the starting position
  my @chars = ();
  while (defined(my $char = $reader->peekChar)) {
    last if $literal_specials{$char};
    push(@chars, $char);
    $reader->readChar; }
  return unless @chars;
  my $keyword = join('', @chars);
  $keyword =~ s/^\s+//;    # Trim
  $keyword =~ s/\s+$//;
  return $keyword; }

sub readLiteral {
  my ($self) = @_;
  my $reader = $$self{reader};
  # get the starting position
  my $locator = $reader->getLocator;
  my $keyword = $self->readKeyword;
  return LaTeXML::BibTeX::Bibliography::BibString->new('LITERAL', $keyword,
    $locator->merge($reader->getLocator)); }

# read a string of balanced braces from the input
# does not skip any spaces before or after
sub readBraced {
  my ($self) = @_;
  my $reader = $$self{reader};
  # read the first bracket, or die if we are at the end
  my $char = $reader->readChar;
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
    $char = $reader->readChar;
    return Warn('bibtex', 'bibparse', $reader->getLocator, 'unexpected end of input in quote ')
      if !defined $char;
    # keep count of what level we are in
    if ($char eq '{') {
      $level++; }
    elsif ($char eq '}') {
      $level--; } }
  return LaTeXML::BibTeX::Bibliography::BibString->new('BRACKET', $result,
    $locator->merge($reader->getLocator)); }

# read a quoted quote from reader
# does not skip any spaces
sub readQuoted {
  my ($self) = @_;
  my $reader = $$self{reader};
  # read the first quote, or die if we are at the end
  my $char = $reader->readChar;
  return Warn('bibtex', 'bibparse', $reader->getLocator, 'expected to find an \'"\'')
    unless defined($char) && $char eq '"';
  my $locator = $reader->getLocator;
  my $result  = '';
  my $level   = 0;
  while (1) {
    $char = $reader->readChar;
    return Warn('bibtex', 'bibparse', $reader->getLocator, 'unexpected end of input in quote')
      if !defined $char;
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
