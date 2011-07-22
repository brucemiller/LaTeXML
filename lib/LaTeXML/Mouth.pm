# /=====================================================================\ #
# |  LaTeXML::Mouth                                                     | #
# | Analog of TeX's Mouth: Tokenizes strings & files                    | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

#**********************************************************************
# LaTeXML::Mouth
#    Read TeX Tokens from a String.
#**********************************************************************
package LaTeXML::Mouth;
use strict;
use LaTeXML::Global;
use LaTeXML::Token;
use base qw(LaTeXML::Object);

sub new {
  my($class,$string)=@_;
  my $self =  bless {source=>"Anonymous String"}, $class;
  $self->openString($string);
  $self->initialize;
  $self; }

sub openString {
  my($self,$string)=@_;
  $$self{string} = $string;
  $$self{buffer} = [(defined $string ? $self->splitString($string) : ())];
}

sub initialize {
  my($self)=@_;
  $$self{lineno}=0;
  $$self{colno}=0;
  $$self{chars}=[];
  $$self{nchars}=0;
}

sub finish {
  my($self)=@_;
  $$self{buffer}=[];
  $$self{lineno}=0;
  $$self{colno}=0;
  $$self{chars}=[];
  $$self{nchars}=0;
}

# This is (hopefully) a platform independent way of splitting a string
# into "lines" ending with CRLF, CR or LF (DOS, Mac or Unix).
sub splitString {
  my($self,$string)=@_;
#  $string =~ s/(?:\015\012|\015|\012)$//; # Remove trailing lineend, if any
#  $string =~ s/(?:\015\012|\015|\012)/\n/sg; #  Normalize remaining
#  ($string ? split("\n",$string) : ("")); }		  # And split.
  $string =~ s/(?:\015\012|\015|\012)/\n/sg; #  Normalize remaining
  split("\n",$string); }		  # And split.

sub getNextLine {
  my($self)=@_;
  return undef unless scalar(@{$$self{buffer}});
  my $line = shift(@{$$self{buffer}});
  (scalar(@{$$self{buffer}}) ? $line . "\n" : $line); }	# No cr on last line!

sub hasMoreInput {
  my($self)=@_;
  ($$self{colno} < $$self{nchars}) || scalar(@{$$self{buffer}}); }

# Get the next character & it's catcode from the input,
# handling TeX's "^^" encoding.
# Note that this is the only place where catcode lookup is done,
# and that it is somewhat `inlined'.
sub getNextChar {
  my($self)=@_;
  if($$self{colno} < $$self{nchars}){
    my $ch = $$self{chars}->[$$self{colno}++];
    my $cc = $$STATE{table}{catcode}{$ch}[0]; # $STATE->lookupCatcode($ch); OPEN CODED!
    if((defined $cc) && ($cc == CC_SUPER)	# Possible convert ^^x
       && ($$self{colno}+1 < $$self{nchars}) && ($ch eq $$self{chars}->[$$self{colno}])){
      my($c1,$c2);
      if(($$self{colno}+2 < $$self{nchars}) # ^^ followed by TWO LOWERCASE Hex digits???
	 && (($c1=$$self{chars}->[$$self{colno}+1]) =~/^[0-9a-f]$/)
	 && (($c2=$$self{chars}->[$$self{colno}+2]) =~/^[0-9a-f]$/)){
	$ch = chr(hex($c1.$c2));
	splice(@{$$self{chars}},$$self{colno}-1,4,$ch);
	$$self{nchars} -= 3; }
      else {			# OR ^^ followed by a SINGLE Control char type code???
	my $c=$$self{chars}->[$$self{colno}+1];
	# Knuth sets ^^M (CR) as the EOL char, but we're going to work
	# with \n which is LF here.
	if($c eq 'M'){
	  $ch = "\n"; }
	else {
	  my $cn = ord($c);
	  $ch = chr($cn + ($cn > 64 ? -64 : 64));  }
	splice(@{$$self{chars}},$$self{colno}-1,3,$ch);
	$$self{nchars} -= 2; }
      $cc = $STATE->lookupCatcode($ch); }
    $cc=CC_OTHER unless defined $cc;
    ($ch,$cc); }
  else {
    (undef,undef); }}

sub stringify {
  my($self)=@_;
  "Mouth[<string>\@$$self{lineno}x$$self{colno}]"; }

#**********************************************************************
sub getLocator {
  my($self,$long)=@_;
  my($l,$c)=($$self{lineno},$$self{colno});
  my $msg =  "at $$self{source}; line $l col $c";
  if($long && (defined $l || defined $c)){
    my $chars=$$self{chars};
    my $n = $$self{nchars}; 
    $c=$n-1 if $c >=$n;
    my $c0 = ($c > 50 ? $c-40 : 0);
    my $cn = ($n-$c > 50 ? $c+40 : $n-1);
    my $p1 = join('',@$chars[$c0..$c-1])||''; chomp($p1);
    my $p2 = join('',@$chars[$c..$cn])||''; chomp($p2);
    $msg .="\n  ".$p1."\n  ".(' ' x ($c-$c0)).'^'.' '.$p2; }
  $msg; }

sub getSource {
  my($self)=@_;
  $$self{source}; }

#**********************************************************************
# See The TeXBook, Chapter 8, The Characters You Type, pp.46--47.
#**********************************************************************

sub handle_escape {		# Read control sequence
  my($self)=@_;
  # NOTE: We're using control sequences WITH the \ prepended!!!
  my $cs = "\\";		# I need this standardized to be able to lookup tokens (A better way???)
  my($ch,$cc)=$self->getNextChar;
  # Knuth, p.46 says that Newlines are converted to spaces,
  # Bit I believe that he does NOT mean within control sequences
  $cs .= $ch;
  if ($cc == CC_LETTER) {	# For letter, read more letters for csname.
    while ((($ch,$cc)=$self->getNextChar) && $ch && ($cc == CC_LETTER)){
      $cs .= $ch; }
    $$self{colno}--; }
  if(($cc == CC_SPACE) || ($cc == CC_EOL)){ # We'll skip whitespace here.
    # Now, skip spaces
    while ((($ch,$cc)=$self->getNextChar) && $ch && (($cc == CC_SPACE) || ($cc == CC_EOL))) {}
    $$self{colno}-- if ($$self{colno} < $$self{nchars}); }
  T_CS($cs); }

sub handle_EOL {
  my($self)=@_;
  # Note that newines should be converted to space (with " " for content)
  # but it makes nicer XML with occasional \n. Hopefully, this is harmless?
  my $token = ($$self{colno}==1
	       ? T_CS('\par')
	       : ($STATE->lookupValue('PRESERVE_NEWLINES') ? Token("\n",CC_SPACE) : T_SPACE));
  $$self{colno} = $$self{nchars}; # Ignore any remaining characters after EOL
  $token; }

sub handle_comment {
  my($self)=@_;
  my $n = $$self{colno};
  $$self{colno} = $$self{nchars};
  my $comment = join('',@{$$self{chars}}[$n..$$self{nchars}-1]);
  $comment =~ s/^\s+//; $comment =~ s/\s+$//;
  ($comment && $STATE->lookupValue('INCLUDE_COMMENTS') ? T_COMMENT($comment) : undef); }

# Some caches
my %LETTER =();
my %OTHER =();
my %ACTIVE =();

my @DISPATCH
  = ( \&handle_escape,		# T_ESCAPE
      T_BEGIN,			# T_BEGIN
      T_END,			# T_END
      T_MATH,			# T_MATH
      T_ALIGN,			# T_ALIGN
      \&handle_EOL,		# T_EOL
      T_PARAM,			# T_PARAM
      T_SUPER,			# T_SUPER
      T_SUB,			# T_SUB
      sub { undef; },		# T_IGNORE (we'll read next token)
      T_SPACE,		        # T_SPACE
      sub { $LETTER{$_[1]} || ($LETTER{$_[1]}=T_LETTER($_[1])); }, # T_LETTER
      sub { $OTHER{$_[1]}  || ($OTHER{$_[1]} =T_OTHER($_[1])); }, # T_OTHER
      sub { $ACTIVE{$_[1]} || ($ACTIVE{$_[1]}=T_ACTIVE($_[1])); }, # T_ACTIVE
      \&handle_comment,		# T_COMMENT
      sub { T_OTHER($_[1]); } # T_INVALID (we could get unicode!)
);

# Read the next token, or undef if exhausted.
# Note that this also returns COMMENT tokens containing source comments,
# and also locator comments (file, line# info).
# LaTeXML::Gullet intercepts them and passes them on at appropriate times.
sub readToken {
  my($self)=@_;
  while(1){			# Iterate till we find a token, or run out. (use return)
    # ===== Get next line, if we need to.
    if ($$self{colno} >= $$self{nchars}) {
      $$self{lineno}++;
      $$self{colno}=0;
      my $line = $self->getNextLine; 
      if (!defined $line) {	# Exhausted the input.
	$$self{chars}=[];
	$$self{nchars}=0;
	return undef;  }
      # Remove trailing space, but NOT a control space!
      $line =~ s/((\\ )*)\s*$/$1\n/s;
      $$self{chars}=[split('',$line)];
      $$self{nchars} = scalar(@{$$self{chars}});
      while(($$self{colno} < $$self{nchars})
	    && (($$STATE{table}{catcode}{$$self{chars}->[$$self{colno}]}[0]||CC_OTHER)==CC_SPACE)){
	$$self{colno}++; }

      # Sneak a comment out, every so often.
      if((($$self{lineno} % 25)==0) && $STATE->lookupValue('INCLUDE_COMMENTS')){
	return T_COMMENT("**** $$self{source} Line $$self{lineno} ****"); }
    }
    # ==== Extract next token from line.
    my($ch,$cc)=$self->getNextChar;
    my $token = $DISPATCH[$cc];
    $token = &$token($self,$ch) if ref $token eq 'CODE';
    return $token if defined $token; # Else, repeat till we get something or run out.
}}

#**********************************************************************
# Read all tokens until a token equal to $until (if given), or until exhausted.
# Returns an empty Tokens list, if there is no input

sub readTokens {
  my($self,$until)=@_;
  my @tokens=();
  while(defined(my $token = $self->readToken())){
    last if $until and $token->getString eq $until->getString;
    push(@tokens,$token); }
  while(@tokens && $tokens[$#tokens]->getCatcode == CC_SPACE){ # Remove trailing space
    pop(@tokens); }
  Tokens(@tokens); }

#**********************************************************************
# Read raw lines, until a line matches $endline.
# If $exact is true, the line must match $endline exactly (like comment.sty)
# Otherwise, it $endline can be anywhere in the line (like verbatim),
# in which case the part (if any) preceding $endline is included,
# and any part after, remains in the input.
sub readRawLines {
  my($self,$endline,$exact)=@_;
  my @lines = ();
  while(1){
    my $line;
    if($$self{colno} < $$self{nchars}){
      $line = join('',@{$$self{chars}}[$$self{colno}..$$self{nchars}-1]);
      $$self{colno}=$$self{nchars}; }
    else {
      $line = $self->getNextLine; 
      if(!defined $line){
	Error(":expected:$endline Fell off end trying to match a lines to \"$endline\" from ".Stringify($self));
	last; }
      $line =~ s/\s*$/\n/s if defined $line;	# Is this right? 
      $$self{lineno}++;
      $$self{chars}=[]; $$self{nchars}=0;  $$self{colno}=0; }
    if($exact && ($line eq $endline)){ 
      last; }
    elsif(!$exact && ($line =~ /^(.*?)\Q$endline\E(.*)$/)){
      my($pre,$post)=($1,$2);
      push(@lines,$pre."\n") if $pre;
      $$self{chars}=[split('',$line)];
      $$self{nchars} = scalar(@{$$self{chars}});
      $$self{colno} = length($pre)+length($endline);
      last; }
    else {
      push(@lines,$line); }}
  @lines; }

#**********************************************************************
# LaTeXML::FileMouth
#    Read TeX Tokens from a file.
#**********************************************************************
package LaTeXML::FileMouth;
use strict;
use LaTeXML::Global;
use LaTeXML::Util::Pathname;
use base qw(LaTeXML::Mouth);
use Encode;

sub new {
  my($class,$pathname)=@_;
  my $self =  bless {source=>pathname_relative($pathname,pathname_cwd)}, $class;
  $self->openFile($pathname);
  $self->initialize;
  NoteBegin("Processing $$self{source}");
  $self;  }

sub openFile {
  my($self,$pathname)=@_;
  local *IN;
  if(! -r $pathname){ Fatal(":missing_file:$pathname Input file is not readable."); }
  elsif((!-z $pathname) && (-B $pathname)){Fatal(":missing_file:$pathname Input file appears to be binary."); }
  open(IN,$pathname) || Fatal(":missing_file:$pathname Can't read: ",$!);
  $$self{IN} = *IN;
  $$self{buffer}=[];
}

sub finish {
  my($self)=@_;
  $self->SUPER::finish;
  if($$self{IN}){
    close( \*{$$self{IN}}); $$self{IN}=undef; }
  NoteEnd("Processing $$self{source}");}

sub hasMoreInput {
  my($self)=@_;
#  ($$self{colno} < $$self{nchars}) || $$self{IN}; }
  ($$self{colno} < $$self{nchars}) || scalar(@{$$self{buffer}}) || $$self{IN}; }
our $WARNED_8BIT=0;

sub getNextLine {
  my($self)=@_;
  if(! scalar(@{$$self{buffer}})){
    return undef unless $$self{IN};
    my $fh = \*{$$self{IN}};
    my $line = <$fh>;
    if(! defined $line){
      close($fh); $$self{IN}=undef;
      return; }
    else {
      push(@{$$self{buffer}}, $self->splitString($line)); }}

  my $line = (shift(@{$$self{buffer}})||'');
  if($line){
    if(my $encoding = $STATE->lookupValue('PERL_INPUT_ENCODING')){
      # Note that if chars in the input cannot be decoded, they are replaced by \x{FFFD}
      # I _think_ that for TeX's behaviour we actually should turn such un-decodeable chars in to space(?).
      $line = decode($encoding, $line, Encode::FB_DEFAULT);
      if($line =~ s/\x{FFFD}/ /g){	# Just remove the replacement chars, and warn (or Info?)
	Info(":unexpected input isn't valid under encoding $encoding"); }}}
  $line .= "\n"; # put line ending back!

  if(!($$self{lineno} % 25)){
    NoteProgress("[#$$self{lineno}]"); }
  $line; }

sub stringify {
  my($self)=@_;
  "FileMouth[$$self{source}\@$$self{lineno}x$$self{colno}]"; }

#**********************************************************************
# LaTeXML::StyleMixin
#    Mixin for Mouth's that serve as source for style/package/class/whatever
#**********************************************************************
package LaTeXML::StyleMixin;
use strict;
use LaTeXML::Global;

sub postInitialize {
  my($self)=@_;
  NoteBegin("Style $$self{source}");
  $$self{saved_at_cc} = $STATE->lookupCatcode('@');
  $$self{SAVED_INCLUDE_COMMENTS} = $STATE->lookupValue('INCLUDE_COMMENTS');
  $$self{SAVED_INSIDE_STYLE} = $STATE->lookupValue('INSIDE_STYLE');
  $STATE->assignCatcode('@'=>CC_LETTER);
  $STATE->assignValue(INCLUDE_COMMENTS=>0);
  $STATE->assignValue(INSIDE_STYLE=>1);
  $self;  }

sub preFinish {
  my($self)=@_;
  $STATE->assignCatcode('@'=> $$self{saved_at_cc});
  $STATE->assignValue(INCLUDE_COMMENTS=>$$self{SAVED_INCLUDE_COMMENTS});
  $STATE->assignValue(INSIDE_STYLE=>$$self{SAVED_INSIDE_STYLE});
  NoteEnd("Style $$self{source}"); }

#**********************************************************************
# LaTeXML::StyleMouth
#    Read TeX Tokens from a style file.
#**********************************************************************

package LaTeXML::StyleMouth;
use strict;
use LaTeXML::Global;
use LaTeXML::Util::Pathname;
use base qw(LaTeXML::FileMouth LaTeXML::StyleMixin);

sub new {
  my($class,$pathname)=@_;
  my $self = bless {source=>pathname_relative($pathname,pathname_cwd)}, $class;
  $self->openFile($pathname);
  $self->initialize;
  $self->postInitialize;
  $self;  }

sub finish {
  my($self)=@_;
  $self->preFinish; $self->SUPER::finish; }
#**********************************************************************
# LaTeXML::StyleMouth
#    Read TeX Tokens from a style file.
#**********************************************************************

package LaTeXML::StyleStringMouth;
use strict;
use LaTeXML::Global;
use base qw(LaTeXML::Mouth LaTeXML::StyleMixin);

sub new {
  my($class,$pathname,$string)=@_;
  my $self = bless {source=>$pathname}, $class;
  $self->openString($string);
  $self->initialize;
  $self->postInitialize;
  $self;  }

sub finish {
  my($self)=@_;
  $self->preFinish; $self->SUPER::finish; }

#**********************************************************************
# A fake mouth provides a hook for getting the Locator of anything
# defined in a perl module (*.pm, *.ltxml, *.latexml...)
package LaTeXML::PerlMouth;
use strict;
use LaTeXML::Global;
use LaTeXML::Util::Pathname;

sub new {
  my($class,$pathname)=@_;
  my $shortpath=pathname_relative($pathname,pathname_cwd);
  my $self = bless {source=>(length($pathname) < length($shortpath) ? $pathname : $shortpath)},$class;
  NoteBegin("Loading $$self{source}");
  $self; }

sub finish {
  my($self)=@_;
  NoteEnd("Loading $$self{source}"); }

# Evolve to figure out if this gets dynamic location!
sub getLocator {
  my($self)=@_;
  my $path = $$self{source};
  my $frame=2;
  my($pkg,$file,$line);
  while(($pkg,$file,$line) = caller($frame++)){
    last if $file eq $path; }
  $path.($line ? " line $line":''); }

sub getSource {
  my($self)=@_;
  $$self{source}; }

sub hasMoreInput { 0; }
sub readToken { undef; }

sub stringify {
  my($self)=@_;
  "PerlMouth[$$self{source}]"; }

#**********************************************************************
1;


__END__

=pod 

=head1 NAME

C<LaTeXML::Mouth> - tokenize the input.

=head1 DESCRIPTION

A C<LaTeXML::Mouth> (and subclasses) is responsible for I<tokenizing>, ie.
converting plain text and strings into L<LaTeXML::Token>s according to the
current category codes (catcodes) stored in the C<LaTeXML::State>.

=over 4

=item C<LaTeXML::FileMouth>

=begin latex

\label{LaTeXML::FileMouth}

=end latex

specializes C<LaTeXML::Mouth> to tokenize from a file.

=item C<LaTeXML::StyleMouth>

=begin latex

\label{LaTeXML::StyleMouth}

=end latex

further specializes C<LaTeXML::FileMouth> for processing
style files, setting the catcode for C<@> and ignoring comments.

=item C<LaTeXML::PerlMouth>

=begin latex

\label{LaTeXML::PerlMouth}

=end latex

is not really a Mouth in the above sense, but is used
to definitions from perl modules with exensions C<.ltxml> and C<.latexml>.

=back

=head2 Creating Mouths

=over 4

=item C<< $mouth = LaTeXML::Mouth->new($string); >>

Creates a new Mouth reading from C<$string>.

=item C<< $mouth = LaTeXML::FileMouth->new($pathname); >>

Creates a new FileMouth to read from the given file.

=item C<< $mouth = LaTeXML::StyleMouth->new($pathname); >>

Creates a new StyleMouth to read from the given style file.

=back

=head2 Methods

=over 4

=item C<< $token = $mouth->readToken; >>

Returns the next L<LaTeXML::Token> from the source.

=item C<< $boole = $mouth->hasMoreInput; >>

Returns whether there is more data to read.

=item C<< $string = $mouth->getLocator($long); >>

Return a description of current position in the source, for reporting errors.

=item C<< $tokens = $mouth->readTokens($until); >>

Reads tokens until one matches C<$until> (comparing the character, but not catcode).
This is useful for the C<\verb> command.

=item C<< $lines = $mouth->readRawLines($endline,$exact); >>

Reads raw (untokenized) lines from C<$mouth> until a line matching C<$endline>
is found.
If C<$exact> is true, C<$endline> is matched exactly, with no leading or trailing
data (like in the c<comment> package).
Otherwise, the match is done like with the c<verbatim> environment;
any text preceding C<$endline> is returned as the last line, and any characters
after C<$endline> remains in the mouth to be tokenized.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
