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

# If options include cattable=>$cattable, that table will be used
# instead of one from $stomach.
sub new {
  my($class,$stomach,$string,%options)=@_;
  my $self = {stomach=>$stomach, string=>$string, source=>"Anonmymous String", includeComments=>0, %options};
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

sub getNextLine {
  my($self)=@_;
  return undef unless scalar(@{$$self{buffer}});
  my $line = shift(@{$$self{buffer}});
  (scalar(@{$$self{buffer}}) ? $line . "\n" : $line); }	# No cr on last line!

sub hasMoreInput {
  my($self)=@_;
  ($$self{colno} < $$self{nchars}) || scalar(@{$$self{buffer}}); }

sub stringify {
  my($self)=@_;
  "Mouth[<string>\@$$self{lineno}x$$self{colno}]"; }

#**********************************************************************
sub getContext {
  my($self,$short)=@_;
  my($l,$c)=($$self{lineno},$$self{colno});
  my $chars=$$self{chars};
  my $msg =  "at $$self{source}; line $l, column $c";
  my $n = scalar(@$chars);
  if(!$short && (defined $l || defined $c)){
    my $p1 = join('',@$chars[0..$c-1]); chomp($p1);
    my $p2 = join('',@$chars[$c..$n-1]);
    $msg .="\n  ".$p1."\n  ".(' ' x $c).'^'.' '.$p2; }
  $msg; }

sub getPathname { $_[0]->{pathname}; }
sub getLinenumber { $_[0]->{lineno}; }

#**********************************************************************
# See The TeXBook, Chapter 8, The Characters You Type, pp.46--47.
#**********************************************************************
my @trivcatcodes=(0,1,1,1, 1,0,1,1, 1,0,1,1, 1,1,0,0);

# Read the next token, or undef if exhausted.
# Yes, this is _really_ ugly. I'm trying to emulate TeX's mouth; 
# this has been slightly optimized, so it's even worse.
# Note that this also returns COMMENT tokens containing source comments,
# and also locator comments (file, line# info).
# LaTeXML::Gullet intercepts them and passes them on at appropriate times.
sub readToken {
  my($self)=@_;
  my $cattable = $$self{cattable} || $$self{stomach}->getCattable;
  # ===== Get next line, if we need to.
  if ($$self{colno} >= $$self{nchars}) {
    $$self{lineno}++;
    $$self{colno}=0;
    my $line = $self->getNextLine; 
    if (!defined $line) {	# Exhausted the input.
      $$self{chars}=[];
      $$self{nchars}=0;
      return undef;
    }
    $line =~ s/^\s+//; $line =~ s/\s*$/\n/s;
    $$self{chars}=[split('',$line)];
#    $$self{chars}=[split('',$line),chr(0),chr(0)]; # Padding, so we don't have to check nchars so much.
    $$self{nchars} = scalar(@{$$self{chars}});
    # Sneak a comment out, every so often.
    if(!($$self{lineno} % 25)){
      NoteProgress("[#$$self{lineno}]");
      return T_COMMENT("**** $$self{source} Line $$self{lineno} ****")
	if $$self{includeComments};
    }
  }
  # ==== Extract next token from line.
  my $ch = $$self{chars}->[$$self{colno}++];
  my $cc = $$cattable{$ch}; $cc=CC_OTHER unless defined $cc;
  if ($cc == CC_SUPER) {	# Possible convert ^^x
    ($ch,$cc)=super_kludge($self,$cattable,$ch); }
  # ==== Special treatment for some catcodes.
  if ($trivcatcodes[$cc]) {	# Straightforward cases first.
    Token($ch,$cc); }
  elsif ($cc == CC_ESCAPE) { # Read command sequence
    # NOTE: We're using control sequences WITH the \ prepended!!!
    my $cs = "\\";		# I need this standardized to be able to lookup tokens (A better way???)
    $ch = $$self{chars}->[$$self{colno}++];
    $cc = $$cattable{$ch};  $cc=CC_OTHER unless defined $cc;
    if ($cc == CC_SUPER) {
      ($ch,$cc)=super_kludge($self,$cattable,$ch); }
    elsif($cc == CC_EOL){	# I _think_ this is what Knuth is sayin' !?!?
      ($ch,$cc)=(' ',CC_SPACE); }
    $cs .= $ch;
    if(($cc == CC_LETTER) || ($cc == CC_SPACE)){ # We'll skip whitespace here.
      if ($cc == CC_LETTER) {	# For letter, read more letters for csname.
	while (($$self{colno} < $$self{nchars}) 
	       && defined($cc=$$cattable{$ch=$$self{chars}->[$$self{colno}++]})
	       && (($cc == CC_LETTER) || ($cc==CC_SUPER))){
	  if($cc == CC_SUPER){ 
	    ($ch,$cc)=super_kludge($self,$cattable,$ch);
	    last if ($cc != CC_LETTER); }
	  $cs .= $ch; }
	$$self{colno}--; }
      # Now, skip spaces
      while ( ($$self{colno} < $$self{nchars})
	     && defined($cc=$$cattable{$$self{chars}->[$$self{colno}++]})
	      && (($cc == CC_SPACE) || ($cc == CC_EOL) || ($cc == CC_SUPER))) {
	if ($cc == CC_SUPER) {
	  ($ch,$cc)=super_kludge($self,$cattable,$ch); 
	  last if ($cc != CC_SPACE) && ($cc != CC_EOL); }
      }
      $$self{colno}-- if ($$self{colno} < $$self{nchars});
    }
    T_CS($cs); }
  elsif ($cc == CC_IGNORE) {	# Ignore this char, get next token.
    $self->readToken; } 
  elsif ($cc == CC_EOL) {	# End of Line
    ($$self{colno}==1
     ? T_CS('\par') 
     : ($$self{stomach} && $$self{stomach}->getValue('preserveNewLines') 
	? Token("\n",CC_SPACE)
	: T_SPACE)); }
  elsif ($cc == CC_COMMENT) { 
    my $n = $$self{colno};
    $$self{colno} = $$self{nchars};
    my $comment = join('',@{$$self{chars}}[$n..$$self{nchars}-1]);
    $comment =~ s/^\s+//; $comment =~ s/\s+$//;
    ($$self{includeComments} && $comment ? T_COMMENT($comment) : $self->readToken); }
  else {
#    Error("Invalid character $ch"); }
    T_OTHER($ch); }		# Should this warn? (we're could be getting unicode!)
}

# If $ch is a superscript, peek at next chars; if another superscript, convert the
# char. In either case, return a $ch & catcode
sub super_kludge {
  my($self,$cattable,$ch)=@_;
  if(($$self{colno}+1 < $$self{nchars})
     && ($ch eq $$self{chars}->[$$self{colno}])){
    my $c=ord($$self{chars}->[$$self{colno}+1]);
    my $ch = chr($c + ($c > 64 ? -64 : 64));
    splice(@{$$self{chars}},$$self{colno}-1,3,$ch);
    $$self{nchars} -= 2;
    my $cc =  $$cattable{$ch};
    ($ch, (defined $cc ? $cc : CC_OTHER)); }
  else {
    ($ch, CC_SUPER); }}

#**********************************************************************
sub readLine {
  my($self)=@_;
  if($$self{colno} < $$self{nchars}){
    my $line = join('',@{$$self{chars}}[$$self{colno}..$$self{nchars}-1]);
    $$self{colno}=$$self{nchars}; 
    $line; }
  else {
    $self->getNextLine; }}

#**********************************************************************
# Read all tokens, until exhausted.
# Returns an empty Tokens list, if there is no input
# [But shouldn't it return undef?]
sub readTokens {
  my($self)=@_;
  my @tokens=();
  while(defined(my $token = $self->readToken())){
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
  my($class,$stomach,$pathname, %options)=@_;
  local *IN;
  open(IN,$pathname) || Error("Can't read from $pathname");
  my $self = {stomach=>$stomach,pathname=>$pathname, source=>"File $pathname", 
	      IN => *IN, includeComments=>1, %options};
  bless $self,$class;
  $self->initialize;
  $self;  }

sub hasMoreInput {
  my($self)=@_;
  ($$self{colno} < $$self{nchars}) || $$self{IN}; }

sub getNextLine {
  my($self)=@_;
  return undef unless $$self{IN};
  my $fh = \*{$$self{IN}};
  my $line = <$fh>;
  if(! defined $line){
    close($fh); $$self{IN}=undef;
    $line = $$self{after}; $$self{after}=undef; }
#  close(IN) unless defined $l;
#  $l || "\\endinput"; }
  $line; }

sub stringify {
  my($self)=@_;
  "FileMouth[$$self{pathname}\@$$self{lineno}x$$self{colno}]"; }

#**********************************************************************
1;


__END__

=pod 

=head1 LaTeXML::Mouth and LaTeXML::FileMouth

=head2 DESCRIPTION

 LaTeXML::Mouth tokenizes a string according to the current cattable in the LaTeXML::Stomach.
 LaTeXML::FileMouth specializes LaTeXML::Mouth to tokenize from a file.

=head2 Methods of LaTeXML::Mouth

=over 4

=item C<< $mouth = LaTeXML::Mouth->new($stomach,$string,%options); >>

Creates a new Mouth; $stomach can be undef, in which case, there should
be a cattable provided in the options.

=item C<< $mouth = LaTeXML::FileMouth->new($stomach,$pathname,%options); >>

Creates a new FileMouth to read from the given file.

=item C<< $token = $tokens->readToken; >>

Returns the next L<LaTeXML::Token> from the source.

=item C<< $string = $tokens->getContext; >>

Return a description of current position in the source, for reporting errors.

=back

