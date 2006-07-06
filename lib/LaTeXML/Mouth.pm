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
use LaTeXML::Object;
our @ISA = qw(LaTeXML::Object);

sub new {
  my($class,$string)=@_;
  my $self = {string=>$string,source=>"Anonmymous String"};
  $$self{buffer}=[split("\n",$string)];
  bless $self,$class;
  $self->initialize;
  $self; }

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
    my $cc = $STATE->lookupCatcode($ch);
    if((defined $cc) && ($cc == CC_SUPER)	# Possible convert ^^x
       && ($$self{colno}+1 < $$self{nchars}) && ($ch eq $$self{chars}->[$$self{colno}])){
      my $c=ord($$self{chars}->[$$self{colno}+1]);
      $ch = chr($c + ($c > 64 ? -64 : 64));
      splice(@{$$self{chars}},$$self{colno}-1,3,$ch);
      $$self{nchars} -= 2;
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
    my $p1 = join('',@$chars[0..$c-1])||''; chomp($p1);
    my $p2 = join('',@$chars[$c..$n-1])||''; chomp($p2);
    $msg .="\n  ".$p1."\n  ".(' ' x $c).'^'.' '.$p2; }
  $msg; }

#**********************************************************************
# See The TeXBook, Chapter 8, The Characters You Type, pp.46--47.
#**********************************************************************

sub handle_escape {		# Read control sequence
  my($self)=@_;
  # NOTE: We're using control sequences WITH the \ prepended!!!
  my $cs = "\\";		# I need this standardized to be able to lookup tokens (A better way???)
  my($ch,$cc)=$self->getNextChar;
  if($cc == CC_EOL){	# I _think_ this is what Knuth is sayin' !?!?
    ($ch,$cc)=(' ',CC_SPACE); }
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
  ($$self{colno}==1 ? T_CS('\par') 
   : ($STATE->lookupValue('PRESERVE_NEWLINES') ? Token("\n",CC_SPACE) : T_SPACE)); 
}

sub handle_comment {
  my($self)=@_;
  my $n = $$self{colno};
  $$self{colno} = $$self{nchars};
  my $comment = join('',@{$$self{chars}}[$n..$$self{nchars}-1]);
  $comment =~ s/^\s+//; $comment =~ s/\s+$//;
  ($comment && $STATE->lookupValue('INCLUDE_COMMENTS') ? T_COMMENT($comment) : $self->readToken); }

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
      sub { $_[0]->readToken; }, # T_IGNORE
      T_SPACE,			 # T_SPACE
      sub { $LETTER{$_[1]} || ($LETTER{$_[1]}=Token($_[1],$_[2])); }, # T_LETTER
      sub { $OTHER{$_[1]}  || ($OTHER{$_[1]} =Token($_[1],$_[2])); }, # T_OTHER
      sub { $ACTIVE{$_[1]} || ($ACTIVE{$_[1]}=Token($_[1],$_[2])); }, # T_ACTIVE
      \&handle_comment,		# T_COMMENT
      sub { Token($_[1],CC_OTHER); } # T_INVALID (we could get unicode!)
);

# Read the next token, or undef if exhausted.
# Note that this also returns COMMENT tokens containing source comments,
# and also locator comments (file, line# info).
# LaTeXML::Gullet intercepts them and passes them on at appropriate times.
sub readToken {
  my($self)=@_;
  # ===== Get next line, if we need to.
  if ($$self{colno} >= $$self{nchars}) {
    $$self{lineno}++;
    $$self{colno}=0;
    my $line = $self->getNextLine; 
    if (!defined $line) {	# Exhausted the input.
      $$self{chars}=[];
      $$self{nchars}=0;
      return undef;  }
    $line =~ s/\s*$/\n/s;
    $$self{chars}=[split('',$line)];
    $$self{nchars} = scalar(@{$$self{chars}});
    while(($$self{colno} < $$self{nchars})
	  && (($STATE->lookupCatcode($$self{chars}->[$$self{colno}])||CC_OTHER)==CC_SPACE)){
      $$self{colno}++; }

    # Sneak a comment out, every so often.
    if(!($$self{lineno} % 25)){
      NoteProgress("[#$$self{lineno}]");
      return T_COMMENT("**** $$self{source} Line $$self{lineno} ****")
	if $STATE->lookupValue('INCLUDE_COMMENTS'); }
  }
  # ==== Extract next token from line.
  my($ch,$cc)=$self->getNextChar;
  my $dispatch = $DISPATCH[$cc];
  (ref $dispatch eq 'CODE' ? &$dispatch($self,$ch,$cc) : $dispatch);
}

#**********************************************************************
sub readLine {
  my($self)=@_;
  if($$self{colno} < $$self{nchars}){
    my $line = join('',@{$$self{chars}}[$$self{colno}..$$self{nchars}-1]);
    $$self{colno}=$$self{nchars}; 
    $line; }
  else {
    my $line = $self->getNextLine; 
    $line =~ s/\s*$/\n/s if defined $line;	# Is this right? 
    $$self{lineno}++;
    $$self{chars}=[]; $$self{nchars}=0;  $$self{colno}=0;
    $line; }}

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
# LaTeXML::FileMouth
#    Read TeX Tokens from a file.
#**********************************************************************
package LaTeXML::FileMouth;
use strict;
use LaTeXML::Global;
our @ISA = qw(LaTeXML::Mouth);

sub new {
  my($class,$pathname)=@_;
  local *IN;
  open(IN,$pathname) || Fatal("Can't read from $pathname");
  my $self = {pathname=>$pathname, source=>$pathname, IN => *IN};
  bless $self,$class;
  $self->initialize;
  NoteProgress("\n(Processing $pathname");
  $self;  }

sub finish {
  my($self)=@_;
  $self->SUPER::finish;
  if($$self{IN}){
    close( \*{$$self{IN}}); $$self{IN}=undef; }
  NoteProgress(")");}

sub hasMoreInput {
  my($self)=@_;
  ($$self{colno} < $$self{nchars}) || $$self{IN}; }

sub getNextLine {
  my($self)=@_;
  return undef unless $$self{IN};
  my $fh = \*{$$self{IN}};
  my $line = <$fh>;
  if(! defined $line){
    close($fh); $$self{IN}=undef; }
  $line; }

sub stringify {
  my($self)=@_;
  "FileMouth[$$self{pathname}\@$$self{lineno}x$$self{colno}]"; }

#**********************************************************************
# LaTeXML::StyleMouth
#    Read TeX Tokens from a style file.
#**********************************************************************

package LaTeXML::StyleMouth;
use strict;
use LaTeXML::Global;
our @ISA = qw(LaTeXML::FileMouth);

sub new {
  my($class,$pathname)=@_;
  local *IN;
  open(IN,$pathname) || Fatal("Can't read from $pathname");
  my $self = {pathname=>$pathname, source=>$pathname, IN => *IN};
  bless $self,$class;
  $self->initialize;
  NoteProgress("\n(Style $pathname");
  $$self{saved_at_cc} = $STATE->lookupCatcode('@');
  $$self{SAVED_INCLUDE_COMMENTS} = $STATE->lookupValue('INCLUDE_COMMENTS');
  $STATE->assignCatcode('@'=>CC_LETTER);
  $STATE->assignValue(INCLUDE_COMMENTS=>0);
  $self;  }

sub finish {
  my($self)=@_;
  $STATE->assignCatcode('@'=> $$self{saved_at_cc});
  $STATE->assignValue(INCLUDE_COMMENTS=>$$self{SAVED_INCLUDE_COMMENTS});
  $self->SUPER::finish; }

#**********************************************************************
# A fake mouth provides a hook for getting the Locator of anything
# defined in a perl module (*.pm, *.ltxml, *.latexml...)
package LaTeXML::PerlMouth;
use strict;
use LaTeXML::Global;

sub new {
  my($class,$file)=@_;
  my $self = bless {file=>$file},$class;
  NoteProgress("\n(Loading $file");
  $self; }

sub finish {
  NoteProgress(")"); }

# Evolve to figure out if this gets dynamic location!
sub getLocator {
  my($self)=@_;
  my $file = $$self{file};
  my $line = LaTeXML::Error::line_in_file($file);
  $file.($line ? " line $line":''); }

sub hasMoreInput { 0; }
sub readToken { undef; }

#**********************************************************************
1;


__END__

=pod 

=head1 NAME

C<LaTeXML::Mouth>, C<LaTeXML::FileMouth> and C<LaTeXML::StyleMouth> -- tokenize
the input.

=head1 DESCRIPTION

A C<LaTeXML::Mouth> (and subclasses) is responsible for I<tokenizing>, ie.
converting plain text and strings into L<LaTeXML::Token>s according to the
current category codes (catcodes) stored in the C<LaTeXML::State>.
C<LaTeXML::FileMouth> specializes C<LaTeXML::Mouth> to tokenize from a file.
C<LaTeXML::StyleMouth> further specializes C<LaTeXML::FileMouth> for processing
style files, setting the catcode for C<@> and ignoring comments.

C<LaTeXML::PerlMouth> is not really a Mouth in the above sense, but is used
to definitions from perl modules with exensions C<.ltxml> and C<.latexml>.

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

=item C<< $string = $mouth->readLine; >>

Reads the next line of input, without tokenizing.  This is useful for
verbatim or comment environments.

=item C<< $tokens = $mouth->readTokens($until); >>

Reads tokens until one matches $until (comparing the character, but not catcode).
This is useful for the C<\verb> command.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
