# /=====================================================================\ #
# |  LaTeXML::Pre::BibTeX                                               | #
# | Implements BibTeX for LaTeXML                                       | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Pre::BibTeX;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Error;
use LaTeXML::Util::Pathname;
use LaTeXML::Pre::BibTeX::Entry;
use Text::Balanced qw(extract_delimited extract_bracketed);

#**********************************************************************
# LaTeXML::Pre::BibTeX is responsible for the lowest level parsing of
# BibTeX files, collecting and storing a set of entries
# (along with any TeX code in @PREAMBLE).
# It doesn't analyze the entries or fields.
# See BibTeX.pool.ltxml for the processing.
#
# NOTE: This should be run from within a binding of $STATE.
#
# NOTE: It may be desirable to save the line (& column) numbers
# for the TeX fragments to assist in debugging message later.
# Column number is currently kinda flubbed up.
#**********************************************************************
my %default_macros = (    # [CONSTANT]
  jan => "January",   feb => "February", mar => "March",    apr => "April",
  may => "May",       jun => "June",     jul => "July",     aug => "August",
  sep => "September", oct => "October",  nov => "November", dec => "December",
  acmcs    => "ACM Computing Surveys",
  acta     => "Acta Informatica",
  cacm     => "Communications of the ACM",
  ibmjrd   => "IBM Journal of Research and Development",
  ibmsj    => "IBM Systems Journal",
  ieeese   => "IEEE Transactions on Software Engineering",
  ieeetc   => "IEEE Transactions on Computers",
  ieeetcad => "IEEE Transactions on Computer-Aided Design of Integrated Circuits",
  ipl      => "Information Processing Letters",
  jacm     => "Journal of the ACM",
  jcss     => "Journal of Computer and System Sciences",
  scp      => "Science of Computer Programming",
  sicomp   => "SIAM Journal on Computing",
  tocs     => "ACM Transactions on Computer Systems",
  tods     => "ACM Transactions on Database Systems",
  tog      => "ACM Transactions on Graphics",
  toms     => "ACM Transactions on Mathematical Software",
  toois    => "ACM Transactions on Office Information Systems",
  toplas   => "ACM Transactions on Programming Languages and Systems",
  tcs      => "Theoretical Computer Science");
#======================================================================

sub newFromFile {
  my ($class, $bibname) = @_;
  my $self = { source => $bibname, preamble => [], entries => [], macros => {%default_macros} };
  bless $self, $class;
  my $paths = $STATE->lookupValue('SEARCHPATHS');
  my $file = pathname_find($bibname, types => ['bib'], paths => $paths);
  Fatal('missing_file', $bibname, undef, "Can't find BibTeX file $bibname",
    "SEACHPATHS is " . join(', ', @$paths)) unless $file;
  my $BIB;
  $$self{file} = $bibname;
  open($BIB, '<', $file) or Fatal('I/O', $file, undef, "Can't open BibTeX $file for reading", $!);
  $$self{lines} = [<$BIB>];
  close($BIB);
  $$self{line} = shift(@{ $$self{lines} }) || '';
  $$self{lineno} = 1;
  return $self; }

sub newFromString {
  my ($class, $string) = @_;
  my $self = { source => "<Unknown>", preamble => [], entries => [], macros => {%default_macros} };
  bless $self, $class;

  $$self{file}   = "<anonymous>";
  $$self{lines}  = [split(/\n/, $string)];      # Uh, what about CR's?
  $$self{line}   = shift(@{ $$self{lines} });
  $$self{lineno} = 1;
  return $self; }

# Read all available lines from available Mouth's in the Gullet.
sub newFromGullet {
  my ($class, $name, $gullet) = @_;
  my $self = { source => $name, preamble => [], entries => [], macros => {%default_macros} };
  bless $self, $class;

  my @lines = ();
  while ($gullet->getMouth->hasMoreInput) {
    while (defined(my $line = $gullet->readRawLine)) {
      push(@lines, $line . "\n"); }
    $gullet->closeMouth; }

  $$self{file}   = $name;
  $$self{lines}  = [@lines];
  $$self{line}   = shift(@{ $$self{lines} });
  $$self{lineno} = 1;
  return $self; }

sub toString {
  my ($self) = @_;
  return "Bibliography[$$self{source}]"; }

sub toTeX {
  my ($self) = @_;
  $self->parseTopLevel unless $$self{parsed};
  # Store all entries into $STATE under BIBKEY@$key.
  # NOTE: The case in the key has been preserved, but we'll store it under the lowercase!
  foreach my $entry (@{ $$self{entries} }) {
    $STATE->assignValue('BIBENTRY@' . lc($entry->getKey) => $entry); }

  return join("\n",
    @{ $$self{preamble} },
    '\begin{bibtex@bibliography}',
    (map { '\ProcessBibTeXEntry{' . $_->getKey . '}' } @{ $$self{entries} }),
    '\end{bibtex@bibliography}'); }

# This lets Bib support formatted error messages.
sub getLocator {
  my ($self) = @_;
  return "at $$self{source}; line $$self{lineno}\n  $$self{line}"; }

#======================================================================
#  Greg Ward has a pretty good description of the BibTeX data format
#  as part of his btparser package (See CPAN)
#======================================================================
# Parse the Bibliography at the Top level
# consists of skipping till we find an @name
# and parse the body according to the type.
sub parseTopLevel {
  my ($self) = @_;
  NoteBegin("Preparsing Bibliography $$self{source}");
  while ($self->skipJunk) {
    my $type = $self->parseEntryType;
    if    ($type eq 'preamble') { $self->parsePreamble; }
    elsif ($type eq 'string')   { $self->parseMacro; }
    elsif ($type eq 'comment')  { $self->parseComment; }
    else                        { $self->parseEntry($type); }
  }
  NoteEnd("Preparsing Bibliography $$self{source}");
  $$self{parsed} = 1;
  return; }

#==============================
my %CLOSE = ("{" => "}", "(" => ")");    # [CONSTANT]

# @preamble open "rawtex" close
# open = { or (  close is balancing } or )
sub parsePreamble {
  my ($self) = @_;
  my $open = $self->parseMatch("({");
  my ($value, $rawvalue) = $self->parseValue();
  push(@{ $$self{preamble} }, $value);
  $self->parseMatch($CLOSE{$open});
  return; }

# @string open [name = value]* close
# open = { or (  close is balancing } or )
sub parseMacro {
  my ($self) = @_;
  my $open = $self->parseMatch("({");
  my ($fields, $rawfields) = $self->parseFields('@string', $open);
  foreach my $macro (@$fields) {
    $$self{macros}{ $$macro[0] } = $$macro[1]; }
  return; }

# @comment string
sub parseComment {
  my ($self)  = @_;
  my $comment = $self->parseString();    # Supposedly should accept () delimited strings, too?
                                         # store it?
  return; }

# @entryname open name, [name = value]* close
# open = { or (  close is balancing } or )
sub parseEntry {
  my ($self, $type) = @_;
  my $open = $self->parseMatch("({");
  my $key  = $self->parseEntryName();
  $self->parseMatch(',');
  # NOTE: actually, the entry should be ignored if there already is one for $key!
  my ($fields, $rawfields) = $self->parseFields('@string', $open);
  push(@{ $$self{entries} }, LaTeXML::Pre::BibTeX::Entry->new($type, $key, $fields, $rawfields));
  return; }

sub parseFields {
  my ($self, $for, $open) = @_;
  my @fields    = ();
  my @rawfields = ();
  do {
    my $name = $self->parseFieldName;
    $self->parseMatch('=');
    my ($value, $rawvalue) = $self->parseValue;
    push(@fields,    [$name, $value]);
    push(@rawfields, [$name, $rawvalue]);
    $self->skipWhite;
    } while (($$self{line} =~ s/^,//)    # like parseMatch, but we just end parsing fields if missing
    && $self->skipWhite && ($$self{line} !~ /^\Q$CLOSE{$open}\E/));
  $self->parseMatch($CLOSE{$open});
  return ([@fields], [@rawfields]); }

#==============================
# Low level parsing

# There are several kinds of names here, and they allow different stuff.
# Most of the odd stuff eventually will cause problems processing by LaTeX,
# Especially "\", which BibTeX allows, but it throws us off (semiverbatim vs verbatim)
# when we store the bibentries before digesting the key!

# Use strings for these, since they're character classes
# & inserted into qr/.../ which otherwise (sometimes) mangles them.
my $BIBNAME_re  = q/a-zA-Z0-9/;                                   # [CONSTANT]
my $BIBNOISE_re = q/\.\+\-\*\/\^\_\:\;\@\`\?\!\~\|\<\>\$\[\]/;    # [CONSTANT]

sub parseEntryType {
  my ($self) = @_;
  $self->skipWhite;
  return ($$self{line} =~ s/^([$BIBNAME_re$BIBNOISE_re]*)//x ? lc($1) : undef); }

sub parseEntryName {
  my ($self) = @_;
  $self->skipWhite;
  return (                                                        # Preserve case (at this point!)
    $$self{line} =~ s/^([\"\#\%\&\'\(\)\=\{$BIBNAME_re$BIBNOISE_re]*)//x ? $1 : undef); }

sub parseFieldName {
  my ($self) = @_;
  $self->skipWhite;
  return ($$self{line} =~ s/^([\&$BIBNAME_re$BIBNOISE_re]*)//x ? lc($1) : undef); }

sub parseMatch {
  my ($self, $delims) = @_;
  $self->skipWhite;
  if ($$self{line} =~ s/^([\Q$delims\E])//) {
    return $1; }
  else {
    Error('expected', $delims, undef, "Expected one of " . join(' ', split(//, $delims)));
    return; } }

# A string is delimited with balanced {}, or ""
sub parseString {
  my ($self) = @_;
  $self->skipWhite;
  my $string;
  if ($$self{line} =~ s/^\"//) {    # If opening " (and remove it!)
        # Note that BibTeX doesn't see a " if it is enclosed with {}, so can't use extract_delmited
    while ($$self{line} !~ s/^\"//) {    # Until we've found the closing "
      if (!$$self{line}) { $self->extendLine; }
      elsif ($$self{line} =~ /^\{/) {    # Starts with a brace! extract balanced {}
        $string .= $self->parseBalancedBraces; }
      elsif ($$self{line} =~ s/^([^"\{]*)//) {    # else pull off everything except a brace or "
        $string .= $1; } }
  }
  elsif ($$self{line} =~ /^\{/) {
    $string = $self->parseBalancedBraces;
    $string =~ s/^.//;                            # Remove the delimiters.
    $string =~ s/.$//; }
  else {
    Error('expected', '<delimitedstring>', undef,
      "Expected a string delimited by \"..\", (..) or {..}"); }
  $string =~ s/^\s+//;                            # and trim
  $string =~ s/\s+$//;
  return $string; }

sub parseBalancedBraces {
  my ($self) = @_;
  my $string;
  # minor optimization: make sure there's at least one closing }
  while (($$self{line} !~ /\}/) && $self->extendLine) { }
  # Now try to parse balanced {}, extending until we do get a balanced pair.
  while ((!defined($string = extract_bracketed($$self{line}, '{}'))) && $self->extendLine) { }
  return $string; }

sub extendLine {
  my ($self) = @_;
  my $nextline = shift(@{ $$self{lines} });
  if (defined $nextline) {
    $$self{line} .= $nextline;
    $$self{lineno}++;
    return 1; }
  else {
    Error('unexpected', '<EOF>', undef,
      "Input ended while parsing string");
    return; } }

# value : simple_value ( HASH simple_value)*
# simple_value : string | NAME
sub parseValue {
  my ($self) = @_;
  my $value = "";
  do {
    $self->skipWhite;
    if ($$self{line} =~ /^[\"\{]/) {
      $value .= $self->parseString; }
    elsif (my $name = $self->parseFieldName) {
      my $macro = ($name =~ /^\d+$/ ? $name : $$self{macros}{$name});
      if (!defined $macro) {
        Error('unexpected', $name, undef,
          "The BibTeX macro '$name' is not defined");
        $macro = $name; }    # Default error handling is leave the text in?
      $value .= $macro; }
    else {
      Error('expected', '<value>', undef,
        "Expected a BibTeX value"); }
    $self->skipWhite;
  } while ($$self{line} =~ s/^#//);
  return $value; }

sub skipWhite {
  my ($self) = @_;
  my $nextline;
  do {
    $$self{line} =~ s/^(\s+)//s;
    return 1 if $$self{line};
    $nextline = shift(@{ $$self{lines} });
    $$self{line} = $nextline || "";
    $$self{lineno}++;
  } while defined $nextline;
  return; }

# Although % officially starts comments, apparently BibTeX accepts
# anything until @ as an "implied comment"
# So, until an @ is encountered, pretty much skip anything
sub skipJunk {
  my ($self) = @_;
  while (1) {
    $$self{line} =~ s/^[^@%]*//;    # Skip till comment or @
    return '@' if $$self{line} =~ s/^@//;    # Found @
                                             # else line is empty, or a comment, so get next
    my $nextline = shift(@{ $$self{lines} });
    $$self{line} = $nextline || "";
    $$self{lineno}++;
    return unless defined $nextline; }
  return; }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Pre::BibTeX> - implements a BibTeX parser for LaTeXML.

=head1 DESCRIPTION

C<LaTeXML::Pre::BibTeX> serves as a low-level parser of BibTeX database files.
It parses and stores a C<LaTeXML::Pre::BibTeX::Entry> for each entry into the current STATE.
BibTeX C<string> macros are substituted into the field values, but no other
processing of the data is done.
See C<LaTeXML::Package::BibTeX.pool.ltxml> for how further processing
is carried out, and can be customized.

=head2 Creating a BibTeX

=over 4

=item C<< my $bib = LaTeXML::Pre::BibTeX->newFromFile($bibname); >>

Creates a C<LaTeXML::Pre::BibTeX> object representing a bibliography
from a BibTeX database file.

=item C<< my $bib = LaTeXML::Pre::BibTeX->newFromString($string); >>

Creates a C<LaTeXML::Pre::BibTeX> object representing a bibliography
from a string containing the BibTeX data.

=back

=head2 Methods

=over 4

=item C<< $string = $bib->toTeX; >>

Returns a string containing the TeX code to be digested
by a L<LaTeXML> object to process the bibliography.
The string contains all @PREAMBLE data
and invocations of C<\\ProcessBibTeXEntry{$key}> for each bibliographic
entry. The $key can be used to lookup the data from C<$STATE>
as C<LookupValue('BIBITEM@'.$key)>.
See C<BibTeX.pool> for how the processing is carried out.

=back

=head2 BibEntry objects

The representation of a BibTeX entry.

=over 4

=item C<< $type = $bibentry->getType; >>

Returns a string naming the entry type of the entry
(No aliasing is done here).

=item C<< $key = $bibentry->getKey; >>

Returns the bibliographic key for the entry.

=item C<< @fields = $bibentry->getFields; >>

Returns a list of pairs C<[$name,$value]> representing
all fields, in the order defined, for the entry.
Both the C<$name> and C<$value> are strings.
Field names may be repeated, if they are in the bibliography.

=item C<< $value = $bibentry->getField($name); >>

Returns the value (or C<undef>) associated with
the the given field name. If the field was repeated
in the bibliography, only the last one is returned.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

