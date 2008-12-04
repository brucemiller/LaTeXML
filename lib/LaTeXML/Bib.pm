# /=====================================================================\ #
# |  LaTeXML::Bib                                                       | #
# | Implements BibTeX for LaTeXML                                       | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Bib;
use LaTeXML;
use LaTeXML::Global;
use LaTeXML::Util::Pathname;
use Text::Balanced qw(extract_delimited extract_bracketed);
use strict;

#**********************************************************************
# LaTeXML::Bib is responsible for the lowest level parsing of
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

sub newFromFile {
  my($class,$bibname)=@_;
  my $self = {source=>$bibname, preamble=>[], entries=>[], macros=>{}};
  bless $self,$class;
  my $paths = $STATE->lookupValue('SEARCHPATHS');
  my $file = pathname_find($bibname,types=>['bib'],paths=>$paths);
  die "Couldn't find file $bibname in ".join(', ',@$paths) unless $file;
  open(BIB,$file) or die "Couldn't open $file: $!";
  $$self{file} = $bibname;
  $$self{lines} = [<BIB>];
  $$self{line} = shift(@{$$self{lines}});
  $$self{lineno} = 1;
  close(BIB);
  $self; }

sub newFromString {
  my($class,$string)=@_;
  my $self = {source=>"<Unknown>", preamble=>[], entries=>[], macros=>{}};
  bless $self,$class;

  $$self{file} = "<anonymous>";
  $$self{lines} = [split(/\n/,$string)]; # Uh, what about CR's?
  $$self{line} = shift(@{$$self{lines}});
  $$self{lineno} = 1;
  $self; }

sub toTeX {
  my($self)=@_;
  $self->parseTopLevel unless $$self{parsed};
  # Store all entries into $STATE under BIBKEY@$key.
   foreach my $entry (@{$$self{entries}}){
     $STATE->assignValue('BIBENTRY@'.$entry->getKey => $entry); }

  join("\n",
       @{$$self{preamble}},
       '\begin{bibtex@bibliography}',
       map('\ProcessBibTeXEntry{'.$_->getKey.'}',@{$$self{entries}}),
       '\end{bibtex@bibliography}'); }

#======================================================================
#  Greg Ward has a pretty good description of the BibTeX data format
#  as part of his btparser package (See CPAN)
#======================================================================
# Parse the Bibliography at the Top level
# consists of skipping till we find an @name
# and parse the body according to the type.
sub parseTopLevel {
  my($self)=@_;
  NoteBegin("Preparsing Bibliography $$self{source}");
  while($self->skipJunk){
    my $type = $self->parseName;
    $self->parseWarning("BibTeX \"\@$type\" is nasty!") unless $type =~ /^[a-z]+$/;
    if   ($type eq 'preamble'){ $self->parsePreamble; }
    elsif($type eq 'string')  { $self->parseMacro; }
    elsif($type eq 'comment') { $self->parseComment; }
    else {                      $self->parseEntry($type); }
  }
  NoteEnd("Preparsing Bibliography $$self{source}");
  $$self{parsed}=1; }

#==============================
our %CLOSE=("{"=>"}","("=>")");

# @preamble open "rawtex" close
# open = { or (  close is balancing } or )
sub parsePreamble{
  my($self)=@_;
  $self->skipWhite;
  ($$self{line}=~ s/^([\(\{])//) or $self->parseError("Expected ( or {");
  my $open = $1;
  push(@{$$self{preamble}}, $self->parseValue());
  $self->skipWhite;
  ($$self{line}=~ s/^(\Q$CLOSE{$open}\E)//) or $self->parseError("Expected $CLOSE{$open}");
}

# @string open [name = value]* close
# open = { or (  close is balancing } or )
sub parseMacro {
  my($self)=@_;
  $self->skipWhite;
  ($$self{line}=~ s/^([\(\{])//) or $self->parseError("Expected ( or {");
  my $open = $1;
  foreach my $macro ($self->parseFields($open)){
    $$self{macros}{$$macro[0]} = $$macro[1]; }}

# @comment string
sub parseComment {
  my($self)=@_;
  my $comment = $self->parseString(); # Supposedly should accept () delimited strings, too?
  # store it?
}

# @entryname open name, [name = value]* close
# open = { or (  close is balancing } or )
sub parseEntry{
  my($self,$type)=@_;
  $self->skipWhite;
  ($$self{line}=~ s/^([\(\{])//) or $self->parseError("Expected ( or {");
  my $open = $1;
  my $key = $self->parseName();
  $self->skipWhite;
  $$self{line} =~ s/^,//;
  # NOTE: actually, the entry should be ignored if there already is one for $key!
  push(@{$$self{entries}},LaTeXML::Bib::BibEntry->new($type,$key,$self->parseFields($open))); }

sub parseFields {
  my($self,$open)=@_;
  my @fields=();
  my $closed;
  do {
    my $name = $self->parseName;
    $self->parseWarning("BibTeX field name \"$name\" has awkward characters") unless $name =~ /^[a-z_].*$/;
    $self->skipWhite;
    ($$self{line}=~ s/^=//) or $self->parseError("Expected =");
    push(@fields,[$name,$self->parseValue]);
    $self->skipWhite;
  } while ($$self{line} =~ s/^,//) && $self->skipWhite
    && ! ($closed=($$self{line} =~ s/^(\Q$CLOSE{$open}\E)//));
  if(!$closed){
    $self->skipWhite;
    ($$self{line}=~ s/^(\Q$CLOSE{$open}\E)//) or $self->parseError("Expected $CLOSE{$open}"); }
  @fields; }

#==============================
# Low level parsing

# Actually, there are several kinds of names here:
# type name, field name, macro name.
# they perhaps have different constraints?
sub parseName {
  my($self)=@_;
  $self->skipWhite;
  $$self{line} =~ s/^([a-zA-Z0-9\_\!\$&\*\+\-\.\/\:\;\<\>\?\[\]\^\`\|]*)//;
  lc($1); }

# A string is delimited with balanced {}, or ""
sub parseString {
  my($self)=@_;
  $self->skipWhite;
  my $string;
  if   ($$self{line} =~ /^\"/){
    while($$self{line} !~ /\".*\"/){ # minor optimization: make sure there's at least two ""
      $self->extendLine; }
    # Hmmm.. apparently " is effectively quoted within the string as {"} ?
    while(! defined($string = extract_delimited($$self{line},'\"'))){
      $self->extendLine; }}	# Fetch another line if we haven't balanced, yet.
  elsif($$self{line} =~ /^\{/){
    while($$self{line} !~ /\}/){ # minor optimization: make sure there's at least a closing }
      $self->extendLine; }
    while(! defined($string = extract_bracketed($$self{line},'{}'))){
      $self->extendLine; }}	# Fetch another line if we haven't balanced, yet.
  else {
    $self->parseError("Expected a string delimited by \"..\", (..) or {..}"); }
  $string =~ s/^.//;		# Remove the delimiters.
  $string =~ s/.$//;
  $string; }

sub extendLine {
  my($self)=@_;
  my $nextline = shift(@{$$self{lines}});
  $self->parserError("Input ended while parsing string") unless defined $nextline;
  $$self{line} .= $nextline;
  $$self{lineno} ++; }

# value : simple_value ( HASH simple_value)*
# simple_value : string | NAME
sub parseValue {
  my($self)=@_;
  my $value = "";
  do {
    $self->skipWhite;
    if($$self{line} =~ /^[\"\{]/){
      $value .= $self->parseString; }
    elsif(my $name = $self->parseName){
      my $macro = $$self{macros}{$name};
      $self->parseError("The macro $name is not defined") unless defined $macro;
      $value .= $macro; }
    else { 
      $self->parseError("Expected a value"); }
    $self->skipWhite;
  } while $$self{line} =~ s/^#//;
  $value; }

sub skipWhite{
  my($self)=@_;
  my $nextline;
  do {
    $$self{line} =~ s/^\s+//s;
    return 1 if $$self{line};
    $nextline = shift(@{$$self{lines}});
    $$self{line} = $nextline || "";
    $$self{lineno}++;
  } while defined $nextline; }

# Although % officially starts comments, apparently BibTeX accepts
# anything until @ as an "implied comment"
# So, until an @ is encountered, pretty much skip anything
sub skipJunk {
  my($self)=@_;
  while(1){
    $$self{line} =~ s/^[^@%]*//; # Skip till comment or @
    return '@' if $$self{line} =~ s/^@//; # Found @
    # else line is empty, or a comment, so get next
    my $nextline = shift(@{$$self{lines}});
    $$self{line} = $nextline || "";
    $$self{lineno}++;
    return unless defined $nextline; }}

sub parseError {
  my($self,$message)=@_;
  die "Error: $message\n at $$self{file}, line $$self{lineno} : $$self{line}"; }

sub parseWarning {
  my($self,$message)=@_;
  print STDERR "Warning: $message\n at $$self{file}, line $$self{lineno} : $$self{line}\n"; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
package LaTeXML::Bib::BibEntry;

sub new {
  my($class,$type,$key,@fields)=@_;
  my %hash;
  map( $hash{$$_[0]} = $$_[1], @fields);
  my $self = {type=>$type,key=>$key, fieldlist=>[@fields], fieldmap=>{%hash}};
  bless $self,$class;
  $self; }

sub getType   { $_[0]->{type}; }
sub getKey    { $_[0]->{key}; }
sub getFields { @{$_[0]->{fieldlist}}; }
sub getField  { $_[0]->{fieldmap}{$_[1]}; }

#**********************************************************************
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Bib> - implements a BibTeX parser for LaTeXML.

=head1 DESCRIPTION

C<LaTeXML::Bib> serves as a low-level parser of BibTeX database files.
It parses and stores a C<LaTeXML::Bib::BibEntry> for each entry into the current STATE.
BibTeX C<string> macros are substituted into the field values, but no other
processing of the data is done.
See C<LaTeXML::Package::BibTeX.pool.ltxml> for how further processing
is carried out, and can be customized.

=head2 Creating a Bib

=over 4

=item C<< my $bib = LaTeXML::Bib->newFromFile($bibname); >>

Creates a C<LaTeXML::Bib> object representing a bibliography
from a database file.

=item C<< my $bib = LaTeXML::Bib->newFromString($string); >>

Creates a C<LaTeXML::Bib> object representing a bibliography
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

