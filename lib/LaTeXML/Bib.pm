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
our %default_macros =(jan=>"January",   feb=>"February", mar=>"March",    apr=>"April",
		      may=>"May",       jun=>"June",     jul=>"July",     aug=>"August",
		      sep=>"September", oct=>"October",  nov=>"November", dec=>"December",
		      acmcs=>"ACM Computing Surveys",
		      acta=>"Acta Informatica",
		      cacm=>"Communications of the ACM",
		      ibmjrd=>"IBM Journal of Research and Development",
		      ibmsj=>"IBM Systems Journal",
		      ieeese=>"IEEE Transactions on Software Engineering",
		      ieeetc=>"IEEE Transactions on Computers",
		      ieeetcad=>"IEEE Transactions on Computer-Aided Design of Integrated Circuits",
		      ipl=>"Information Processing Letters",
		      jacm=>"Journal of the ACM",
		      jcss=>"Journal of Computer and System Sciences",
		      scp=>"Science of Computer Programming",
		      sicomp=>"SIAM Journal on Computing",
		      tocs=>"ACM Transactions on Computer Systems",
		      tods=>"ACM Transactions on Database Systems",
		      tog=>"ACM Transactions on Graphics",
		      toms=>"ACM Transactions on Mathematical Software",
		      toois=>"ACM Transactions on Office Information Systems",
		      toplas=>"ACM Transactions on Programming Languages and Systems",
		      tcs=>"Theoretical Computer Science");
#======================================================================

sub newFromFile {
  my($class,$bibname)=@_;
  my $self = {source=>$bibname, preamble=>[], entries=>[], macros=>{%default_macros}};
  bless $self,$class;
  my $paths = $STATE->lookupValue('SEARCHPATHS');
  my $file = pathname_find($bibname,types=>['bib'],paths=>$paths);
  Fatal(":missing_file:$file Couldn't find file $bibname in ".join(', ',@$paths)) unless $file;
  open(BIB,$file) or Fatal(":missing_file:$file Couldn't open: $!");
  $$self{file} = $bibname;
  $$self{lines} = [<BIB>];
  $$self{line} = shift(@{$$self{lines}});
  $$self{lineno} = 1;
  close(BIB);
  $self; }

sub newFromString {
  my($class,$string)=@_;
  my $self = {source=>"<Unknown>", preamble=>[], entries=>[], macros=>{%default_macros}};
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

# This lets Bib support formatted error messages.
sub getLocator {
  my($self)=@_;
  "at $$self{source}; line $$self{lineno}\n  $$self{line}"; }

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
    Warn(":unexpected:$type BibTeX type \"\@$type\" is nasty!") unless $type =~ /^[a-z]+$/;
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
  my $open = $self->parseMatch("({");
  my($value,$rawvalue)=  $self->parseValue();
  push(@{$$self{preamble}}, $value);
  $self->parseMatch($CLOSE{$open}); }

# @string open [name = value]* close
# open = { or (  close is balancing } or )
sub parseMacro {
  my($self)=@_;
  my $open = $self->parseMatch("({");
  my($fields,$rawfields)= $self->parseFields('@string',$open);
  foreach my $macro (@$fields){
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
  my $open = $self->parseMatch("({");
  my $key = $self->parseName();
  $self->parseMatch(',');
  # NOTE: actually, the entry should be ignored if there already is one for $key!
  my($fields,$rawfields)= $self->parseFields('@string',$open);
  push(@{$$self{entries}},LaTeXML::Bib::BibEntry->new($type,$key,$fields,$rawfields)); }

sub parseFields {
  my($self,$for,$open)=@_;
  my @fields=();
  my @rawfields=();
  my $closed;
  do {
    my $name = $self->parseName;
    Warn(":unexpected:$name BibTeX field name \"$name\" has awkward characters in $for at $$self{line}") unless $name =~ /^[a-z_].*$/;
    $self->parseMatch('=');
    my($value,$rawvalue)= $self->parseValue;
    push(@fields,[$name,$value]);
    push(@rawfields,[$name,$rawvalue]);
    $self->skipWhite;
  } while( ($$self{line}=~ s/^,//) # like parseMatch, but NOT fatal if missing
	   && $self->skipWhite && ($$self{line} !~ /^\Q$CLOSE{$open}\E/));
  $self->parseMatch($CLOSE{$open});
  ([@fields],[@rawfields]); }

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

sub parseMatch {
  my($self,$delims)=@_;
  $self->skipWhite;
  ($$self{line}=~ s/^([\Q$delims\E])//) or Fatal(":expected:$delims Expected one of ".join(' ',split(//,$delims)));
  $1; }

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
    Fatal(":expected:string Expected a string delimited by \"..\", (..) or {..}"); }
  $string =~ s/^.//;		# Remove the delimiters.
  $string =~ s/.$//;
  $string; }

sub extendLine {
  my($self)=@_;
  my $nextline = shift(@{$$self{lines}});
  Fatal(":unexpected:EOF Input ended while parsing string") unless defined $nextline;
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
      my $macro = ($name =~ /^\d+$/ ? $name : $$self{macros}{$name});
      if(!defined $macro){
	Error(":unexpected:$name The macro $name is not defined");
	$macro=''; }
      $value .= $macro; }
    else { 
      Error(":expected:value a value"); }
    $self->skipWhite;
  } while ($$self{line} =~ s/^#//);
  $value; }

sub skipWhite{
  my($self)=@_;
  my $nextline;
  do {
    $$self{line} =~ s/^(\s+)//s;
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

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
package LaTeXML::Bib::BibEntry;

sub new {
  my($class,$type,$key,$fields,$rawfields)=@_;
  my $self = {type=>$type,key=>$key,
	      fieldlist=>$fields, rawfieldlist=>$rawfields,
	      fieldmap=>{   map( ($$_[0] => $$_[1]),   @$fields) },
	      rawfieldmap=>{   map( ($$_[0] => $$_[1]), @$rawfields) }};
  bless $self,$class;
  $self; }

sub getType   { $_[0]->{type}; }
sub getKey    { $_[0]->{key}; }
sub getFields { @{$_[0]->{fieldlist}}; }
sub getField  { $_[0]->{fieldmap}{$_[1]}; }
sub getRawField { $_[0]->{rawfieldmap}{$_[1]}; }

sub addField  {
  my($self,$field,$value)=@_;
  push(@{ $$self{fieldlist}},[$field,$value]);
  $$self{fieldmap}{$field} = $value; }

sub addRawField  {
  my($self,$field,$value)=@_;
  push(@{ $$self{rawfieldlist}},[$field,$value]);
  $$self{rawfieldmap}{$field} = $value; }

sub prettyPrint {
  my($self)=@_;
  join(",\n",
       "@".$$self{type}."{".$$self{key},
       map(  (" "x(10-length($$_[0]))).$$_[0]." = {".$$_[1]."}",   @{$$self{fieldlist}})
      )."}\n"; }

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
from a BibTeX database file.

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

