# /=====================================================================\ #
# |  LaTeXML::Stomach                                                   | #
# | Analog of TeX's Stomach: digests tokens, stores state               | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Stomach;
use strict;
use LaTeXML::Token;
use LaTeXML::Box;
use LaTeXML::Error;
use LaTeXML::Object;
use LaTeXML::Mouth;
use LaTeXML::Gullet;
use LaTeXML::Font;
use LaTeXML::Definition;
use LaTeXML::Model;
use LaTeXML::Util::Pathname;

our @ISA = qw(LaTeXML::Object);

#**********************************************************************
sub new {
  my($class, %options)=@_;
  my $stacktop = {mode=>'text', math_mode=>0, 
		  bindings=>{}, values=>{},
		  cattable=>getStandardCattable, cattable_copied=>0};
  my $self={stacktop => $stacktop, stack=>[$stacktop],
	    boxingDepth=>0,
	    environments => [],
	    prefixes=>{},
	    includeComments=>1,
	    text_filters=>{}, math_filters=>{},
	    %options, 
	    };
  $$self{searchpath}=[] unless $$self{searchpath};
  push(@{$$self{searchpath}},'.', @INC);
  bless $self,$class; }

#**********************************************************************
# Accessors
sub getGullet  { $_[0]->{gullet}; }
sub getModel   { $_[0]->{model}; }

sub getContext { 
  my($self)=@_;
  my $gullet = $self->getGullet;
  ($gullet ? $gullet->getContext($_[1]) : "Preloading"); }

#**********************************************************************
# Top level operation
#**********************************************************************
sub readAndDigestFile {
  my($self,$file)=@_;
  local $LaTeXML::STOMACH = $self;
  $self->initialize;
  $self->initializeFile($file);
  Message("Digesting file $file...") if Debugging();
  List($self->readAndDigestBody); }

sub initializeFile {
  my($self,$file)=@_;
  $file = pathname_find($file,types=>['tex']);
  my($dir,$name,$ext)=pathname_split($file);
  $self->addSearchPath($dir);	# Shouldn't permanently change!! ?
  my $mouth =  LaTeXML::FileMouth->new($self,$file,includeComments=>$$self{includeComments});
  $$self{gullet} = LaTeXML::Gullet->new($mouth,$self);
  $$self{model}  = LaTeXML::Model->new();
  $self->setMeaning(T_CS('\jobname'),LaTeXML::Expandable->new(T_CS('\jobname'),'',Tokens(Explode($name))));
  Message("***** Initializing *****") if Debugging();
  $self->input('TeX');
  my ($sec,$min,$hour,$mday,$mon,$year)=localtime();
  $self->setValue('\day',  Number($mday));
  $self->setValue('\month',Number($mon));
  $self->setValue('\year', Number(1900+$year));
  map($self->input($_), @{$$self{preload}}) if $$self{preload};
  # Is this the best time for this? [Or do I need an AtDocumentBegin?]
  $self->input("$name.latexml") if $self->findInput("$name.latexml");
}

# Initialize various parameters, etc.
sub initialize {
  my($self)=@_;
  # Setup default fonts.
  $self->setValue('default@textfont', Font('serif','medium','upright','normal','black'));
  $self->setValue('default@mathfont', MathFont('math','medium','italic','normal','black',0));
  $self->setValue('current@font', $self->getValue('default@textfont'));
}

#**********************************************************************
# Digestion
#**********************************************************************
# NOTE: Worry about whether the $autoflush thing is right?
# It puts a lot of cruft in Gullet; Should we just create a new Gullet?

sub readAndDigestBody {
  my($self)=@_;
  $self->applyFilters($self->readAndDigestChunk(1)); }

# Digest a list of tokens independent from any current Gullet.
# Typically used to digest arguments to primitives or constructors.
# If $nofilter is true, no filters will be applied to the list
# (eg. for literal type arguments)
# Returns a List or MathList containing the digested material.
sub digestTokens {
  my($self,$tokens,$nofilter)=@_;
#  $self->getGullet->openMouth((ref $tokens eq 'LaTeXML::Token' ? Tokens($tokens) : $tokens->clone));
  $self->getGullet->openMouth($tokens);
  $self->clearPrefixes; # prefixes shouldn't apply here.
  my $ismath = $self->inMath;
  my @chunk = $self->readAndDigestChunk(0);
  @chunk = $self->applyFilters(@chunk) unless $nofilter;
  my $list = (scalar(@chunk) == 1 ? $chunk[0] 
	      : ($ismath ? MathList(@chunk) : List(@chunk)));
  $self->getGullet->closeMouth;
  $list; }

# Digest the next `chunk' of input, returning a list of digested
# Boxes, Lists, Whatsits.  Return a list of the digested material
# until the current mode is done.  Returns () when the source is exhausted.
# If $autoflush is true, when a source is exhausted, it gets flushed
# and we continue to read from the containing source.
sub readAndDigestChunk {
  my($self,$autoflush)=@_;
  my $gullet = $self->getGullet;
  my $depth  = $$self{boxingDepth};
  local @LaTeXML::LIST=();
  while(defined(my $token=$gullet->readXToken($autoflush))){ # Done if we run out of tokens
    push(@LaTeXML::LIST,$self->digestToken($token));
    last if $depth > $$self{boxingDepth}; } # if we've closed the initial mode.
  @LaTeXML::LIST; }

our @forbidden_cc = (1,0,0,0, 0,0,1,0, 0,1,0,0, 0,0,0,1, 0,1);

# Digest a token; 
# If it is a primitive or constructor, arguments will be parsed from the Gullet.
# Returns a list of boxes/whatsits.
sub digestToken {
  my($self,$token)=@_;
  my $defn = $self->getMeaning($token);
  if(! defined $defn){
    Error("Executable token $token not defined."); }
  elsif($defn->isExecutable){
    my @stuff = $defn->digest($self);
    $self->clearPrefixes() unless $defn->isPrefix; # Clear prefixes unless we just set one.
    LaTeXML::List::typecheck(@stuff);
    @stuff; }
  else {
    $token = $defn;
    my $cc = $token->getCatcode;
    $self->clearPrefixes; # prefixes shouldn't apply here.
    if($cc == CC_SPACE){
      ($self->inMath() ? () : Box($token->getString, $self->getFont)); }
    elsif($cc == CC_COMMENT){
      LaTeXML::Comment->new($token->getString); }
    elsif($forbidden_cc[$cc]){
      Error("Internal error: Token $token should never reach Stomach!"); }
    elsif($self->inMath){
      my $string = $token->getString;
      my $class = 'symbol';
      $class = 'letter' if $string =~ /^\w$/;
      $class = 'number' if $string =~ /^\d$/;
      MathBox($string,$self->getFont->specialize($class)); }
    else {
      Box($token->getString, $self->getFont); }}}

# Regurgitate: steal the previously digested boxes from the current level.
sub regurgitate {
  my($self)=@_;
  my @stuff = @LaTeXML::LIST;
  @LaTeXML::LIST=();
  @stuff; }

#**********************************************************************
# Filtering
#**********************************************************************
# For each of text and math modes, the filters is a hash keyed on the initial
# item of the pattern (as a untex'd string).  Each entry is a list of pairs.
# Each pair is a list of pattern & replacement, each of which can be CODE or 
# an ARRAY of items to match.

sub addMathFilter {
  my($self,$init,$pattern,$replacement)=@_;
  push(@{$$self{math_filters}{$init}}, [$pattern,$replacement]); }

sub addTextFilter {
  my($self,$init,$pattern,$replacement)=@_;
    push(@{$$self{text_filters}{$init}}, [$pattern,$replacement]); }

sub applyFilters {
  my($self,@list)=@_;
  my @out=();
  while(@list){
    my $item = $list[0];
    my $np = 0;
    if(defined(my $init = $item->getInitial)){
      my $table = ($item->isMath ? $$self{math_filters} : $$self{text_filters});
      foreach my $pair (@{$$table{$init}||[]}){
	my($pattern,$replacement)=@$pair;
	if($np =(ref $pattern eq 'CODE' ? &$pattern(@list) : match($pattern,@list))){
	  my @match = map(shift(@list), 0..$np-1);
	  my @rep = ();
	  if(ref $replacement eq 'CODE'){
	    @rep = &$replacement(grep(ref $_ ne 'LaTeXML::Comment',@match)); }
	  else {
	    my $font = $item->getFont;
	    # Risky: set the replacement boxes to same font. 
	    # It's sometimes the right thing to do; make it optional somehow?
	    @rep = map((ref $_ eq 'LaTeXML::Box' ? Box($_->getString,$font) : $_),@$replacement); }
	  LaTeXML::List::typecheck(@rep);
	  unshift(@list,@rep);
	  last; }}}		# We'll try more filters at same pos.
    if(!$np){
      push(@out,shift(@list)); }} # Next starting position.
  @out; }

# Return number of boxes matched or 0 if failed.
sub match {
  my($pattern,@list)=@_;
  my @pattern = @$pattern;
  my $n=0;
  while(@list && @pattern && ($list[0] eq  $pattern[0])){
    shift(@list); shift(@pattern);  $n++; }
  (@pattern ? 0 : $n); }

#**********************************************************************
# Maintaining State.
#**********************************************************************

#======================================================================
# Stack Frames: Internal support for context, lookup & assignment.  Non-methods.

sub pushStackFrame {
  my($self)=@_;
  my $frame = {mode=>$$self{stacktop}->{mode},
	       math_mode=>$$self{stacktop}->{math_mode},
	       aftergroup=>[],
	       # Defer copying cattable till it's modified.
	       cattable=>$$self{stacktop}->{cattable}, cattable_copied=>0};
  $$self{stacktop} = $frame;
  unshift(@{$$self{stack}},$frame); }

sub popStackFrame {
  my($self,$token)=@_;
  shift(@{$$self{stack}});
  $$self{stacktop} = $$self{stack}->[0]; }

sub lookup_internal {
  my($self,$tablename,$key)=@_;
  my $value;
  foreach my $frame (@{$$self{stack}}){
    return $value if defined ($value=$$frame{$tablename}{$key}); }
  undef;}

# Assign a definition or variable (depending on table being bindings, values, resp).
# If $globally is non-0 or if $$self{globally} has been (temporarily) set by Stomach,
# remove all bound values and assign in lowest frame.  Otherwise assign in current frame.
sub assign_internal {
  my($self,$tablename,$key,$value,$globally)=@_;
  $globally ||= $$self{prefixes}{global};
  if(!$globally){
    $$self{stacktop}{$tablename}{$key}=$value; }
  else {
    foreach my $frame (@{$$self{stack}}){
      delete $$frame{$tablename}{$key}; }	# Remove all previous bindings
    $$self{stack}->[$#{$$self{stack}}]->{$tablename}{$key}=$value; # and put in first frame
  }}

#======================================================================
# Set the prefix (global, long, outer) for the NEXT assignment.
sub setPrefix {
  my($self,$prefix)=@_;
  $$self{prefixes}{$prefix}=1; 
  return; }

sub clearPrefixes {
  my($self)=@_;
  $$self{prefixes}={}; 
  return; }

#======================================================================
# Grouping pushes a new stack frame for binding definitions, etc.
#======================================================================

# if $nobox is true, inhibit incrementing the boxingLevel
sub bgroup {
  my($self,$nobox)=@_;
  pushStackFrame($self);
  $$self{boxingDepth}++ unless $nobox; # For begingroup/endgroup
  return; }

sub egroup {
  my($self,$nobox)=@_;
  my $after = $$self{stacktop}->{aftergroup};
  popStackFrame($self);
  $$self{boxingDepth}-- unless $nobox; # For begingroup/endgroup
  $self->getGullet->unread(@$after);
  return; }

# A list of boxes/whatsits output after the current group closes.
sub pushAfterGroup {
  my($self,@tokens)=@_;
  unshift(@{$$self{stacktop}->{aftergroup}},@tokens); 
  return; }

#======================================================================
# Mode (minimal so far; math vs text)
# Could (should?) be taken up by Stomach by building horizontal, vertical or math lists ?
sub inMath {
  my($self)=@_;
  $$self{stacktop}->{math_mode}; }

sub getMode {
  my($self)=@_;
  $$self{stacktop}->{mode}; }

sub beginMode {
  my($self,$mode)=@_;
  Message("Enter mode $mode") if Debugging('mode');
  $self->bgroup;
  my $prevmode = $$self{stacktop}->{mode};
  $$self{stacktop}->{mode} = $mode;
  if($mode eq $prevmode){}
  elsif($mode =~ /math$/){
    $$self{stacktop}->{math_mode} = 1;
    # When entering math mode, we set the font to the default math font,
    # and save the text font for any embedded text.
    $self->setValue('saved@textfont',$self->getValue('current@font'));
    $self->setValue('current@font',$self->getValue('default@mathfont')); 
    $self->setValue('@mathstyle', ($mode =~ /^display/ ? 'display' : 'text')); }
  else {
    $$self{stacktop}->{math_mode} = 0;
    # When entering text mode, we should set the font to the text font in use before the math.
    $self->setValue('current@font',$self->getValue('saved@textfont')); }
  return; }

sub endMode {
  my($self,$mode)=@_;
  my $m =   $$self{stacktop}->{mode};
  Message("Leave mode $mode") if Debugging('mode');
  Error("Was in mode $m, not mode $mode!!") if $mode && !($mode eq $m); 
  $self->egroup; }		# Return whatever egroup returns.

sub requireMath {
  Error("Current operation can only appear in math mode") unless $_[0]->{stacktop}->{math_mode}; 
  return; }

sub forbidMath {
  Error("Current operation can not appear in math mode") if $_[0]->{stacktop}->{math_mode};
  return; }
#======================================================================
sub beginEnvironment {
  my($self,$environment)=@_;
  push(@{$$self{environments}},$environment); 
  return; }

sub endEnvironment {
  my($self,$environment)=@_;
  my $env = pop(@{$$self{environments}});
  Error("Unbalanced environments: closing $environment when $env was open") unless $env eq $environment;
  return; }
#======================================================================
# Set/Get catcodes, or the current table of catcodes.
#======================================================================

sub getCattable {
  my($self)=@_;
  $$self{stacktop}->{cattable}; }

sub setCattable {
  my($self,$cattable)=@_;
  $$self{stacktop}->{cattable} = $cattable; }

sub getCatcode {
  my($self,$char)=@_;
  my $cc = $$self{stacktop}->{cattable}{$char}; 
  (defined $cc ? $cc : CC_OTHER); }

sub setCatcode {
  my($self,$catcode,@chars)=@_;
  Message("Catcode ".join(', ',map("\"$_\"",@chars))."=>$CC_NAME[$catcode]") if Debugging('catcodes');
  my $frame = $$self{stacktop};
  if(!$$frame{cattable_copied}){
    $$frame{cattable_copied}=1;
    $$frame{cattable}={%{$$frame{cattable}}}; }
  map($$frame{cattable}{$_}=$catcode,@chars); }

#======================================================================
# Lookup or add the `meaning' (definition) of a token or control sequence.
our @primitive_catcodes = (0,1,1,1, 1,0,0,1, 1,0,0,0, 0,0,0,0);
# GACK, this is horrid.
# Ultimately, I suppose I have to define \mathcode ...
our %mathcodes = ("'"=>1);
our @executable_cc= (0,1,1,1, 1,0,0,1, 1,0,0,0, 0,1,0,0, 1,0);

# Since the special executable catcodes may actually have different cs's,
# we store the meaning under CATCODE:type instead of the cs itself.
sub getMeaning {
  my($self,$token)=@_;
  # NOTE: Inlined token accessors!!!
  my $cs = $$token[0];
  my $cc = $$token[1];
  my $name = ($primitive_catcodes[$cc] ? "CATCODE:".$CC_NAME[$cc] : $cs);
  if($executable_cc[$cc] || ($$self{stacktop}->{math_mode} && $mathcodes{$cs})){
    lookup_internal($self,'bindings',$name); }
  else {
    $token; }}

sub setMeaning {
  my($self,$token,$defn,$globally)=@_;
  my $cs = $$token[0];
  my $cc = $$token[1];
  if((!defined $cs) || (!defined $cc)){
    print STDERR "Something wrong here $token\n";}
  my $name = ($primitive_catcodes[$cc] ? "CATCODE:".$CC_NAME[$cc] : $cs);
  assign_internal($self,'bindings',$name, $defn,$globally); }

#======================================================================
# Lookup or set the value of a parameter/register/whatever.
# (a register is simply named "\count1").

sub setValue {
  my($self,$name,$value,$globally)=@_;
  # allow passing a $defn for the $name
  # NOTE: Or should this work for tokens, defns, ... (eg. use untex ?)
  Message("Setting value \"$name\" to \"$value\"") if Debugging('values');
  assign_internal($self,'values',(ref $name ? $name->getCS : $name),$value,$globally); 
  return; }

sub getValue {
  my($self,$name)=@_;
  my $value = lookup_internal($self,'values',$name); 
#  Message("Getting value \"$name\" => \"$value\"") if Debugging('values');
  $value; }

#======================================================================
# Fonts
# Generalized notion of `font' representing anything that affects the
# display of a glphy: family, series, shape, size and color.

sub setFont {
  my($self,%style)=@_;
  $self->setValue('current@font',$self->getValue('current@font')->merge(%style));
  return; }

# This modifies the default math font
sub setMathFont {
  my($self,%style)=@_;
  $self->setValue('default@mathfont',$self->getValue('default@mathfont')->merge(%style));
  return; }

sub getFont {
  my($self)=@_;
  $self->getValue('current@font'); }

# Conversion to scaled points
our %UNITS= (pt=>65536, pc=>12*65536, in=>72.27*65536, bp=>72.27*65536/72, 
	     cm=>72.27*65536/2.54, mm=>72.27*65536/2.54/10, dd=>1238*65536/1157,
	     cc=>12*1238*65536/1157, sp=>1);

sub convertUnit {
  my($self,$unit)=@_;
  $unit = lc($unit);
  # Eventually try to track font size?
  if   ($unit eq 'em'){ 10.0 * 65536; }
  elsif($unit eq 'ex'){  4.3 * 65536; }
  elsif($unit eq 'mu'){ 10.0 * 65536 / 18; }
  else{
    my $sp = $UNITS{$unit}; 
    Warn("Unknown unit \"$unit\"") unless $sp;
    $sp; }}

#======================================================================
# MathStyle: Display, Text, Script or ScriptScript

# NOTE: Do something about font size, or scriptlevel?
sub setMathStyle { 
  my($self,$style)=@_;
  Warn("Unknown math style: \"$style\"") unless $style=~/^display|text|script|scriptscript$/;
  $_[0]->setValue('@mathstyle',$_[1]); }
sub getMathStyle {
  $_[0]->getValue('@mathstyle'); }

#======================================================================
# Additional support for Counters (primarily LaTeX).
# See LaTeXML::Package for definition of the variables used in a counter.
sub stepCounter {
  my($self,$ctr)=@_;
  $ctr=$ctr->untex if ref $ctr;
  $self->setValue("\\c\@$ctr",$self->getValue("\\c\@$ctr")->add(Number(1)),1);
  # and reset any within counters!
  foreach my $c ($self->getValue("\\cl\@$ctr")->unlist){
    $self->resetCounter($c); }
}

sub refStepCounter {
  my($self,$ctr)=@_;
  $ctr=$ctr->untex if ref $ctr;
  $self->stepCounter($ctr);
  my $v = $self->getGullet->expandTokens(Tokens(T_CS("\\the$ctr")));
  $self->setMeaning(T_CS('\@currentlabel'),LaTeXML::Expandable->new(T_CS('\@currentlabel'),'',$v));
  $v; }

sub resetCounter {
  my($self,$ctr)=@_;
  $ctr=$ctr->untex if ref $ctr;
  $self->setValue('\c@'.$ctr,Number(0),1); }
#**********************************************************************
# File I/O
#**********************************************************************
# input of tex or style files, or, better yet, perl implementations of
# them. Perhaps ought to look for the tex files under $TEXINPUTS?
# OTOH, although we eventually want to be able to handle most TeX code,
# it probably isn't worth trying to input files from texmf!

sub getSearchPaths { @{$_[0]->{searchpath}}; }

sub addSearchPath {
  my($self,@paths)=@_;
  unshift(@{$$self{searchpath}}, @paths); }

sub findFile {
  my($self,$name,$types)=@_;
  my @paths=@{$$self{searchpath}};
  @paths = (map("$_/LaTeXML/Package",@paths),@paths);
  pathname_find($name,paths=>[@paths], types=>$types); }

sub findInput {
  my($self,$name)=@_;
  $self->findFile($name,[qw (ltxml sty tex)]); }

# Hmm, we should record in the output which files were included/required/etc.
# This is for the benefit of anything wanting to interpret the Math/TeX ???
# In which case, *.tex files that are included should probably be ignored
# (they're output will already be incorporated),
# But *.sty, *.cls etc, (or the *.pm equivalents) should be noted.
# However, if things are included via some other `package', presumably
# that package will be responsible for loading those extra pacakges, so
# they should be ignored too, right?
sub input {
  my($self,$name)=@_;
  # Try to find a Package implementing $name.

  $name = $name->untex if ref $name;
  $name = $1 if $name =~ /^\{(.*)\}$/; # just in case
  my $file=$self->findInput($name);
  if($file =~ /\.(ltxml|latexml)$/){		# Perl module.
    my($dir,$modname)=pathname_split($file);
    Message("Loading $name") if Debugging();
    do $file;
    Error("Package $name had an error:\n  $@") if $@;
  }
  # Hmm, very slightly different treatment needed for .sty and .tex ?
  elsif($file){
    my $isstyle = ($file =~ /\.sty$/);
    Message("Loading Style $file") if Debugging();
    my $comments = $$self{includeComments} && !$isstyle;
    my $atcc = $self->getCatcode('@');
    $self->setCatcode(CC_LETTER,'@') if $isstyle;
    $self->getGullet->openMouth(LaTeXML::FileMouth->new($self,$file,includeComments=>$comments,
							($isstyle ? (after=>"\\catcode`\\\@=$atcc\\relax") :())
						       ));
  }
  else {
    Error("Cannot find LaTeXML implementation, style or tex file for $name"); }
}

#**********************************************************************
1;

__END__

=pod 

=head1 LaTeXML::Stomach

=head2 DESCRIPTION

LaTeXML::Stomach digests tokens read from a L<LaTeXML::Gullet>
(they will have already been expanded).  The Stomach also 
maintains all of the state relevant during the overall process
of digestion (including tokenization and expansion;
see L<LaTeXML::Mouth> and L<LaTeXML::Gullet>)

=head2 Top-level Methods

=over 4

=item C<< $list = $stomach->readAndDigestFile($file); >>

Return the digested L<LaTeXML::List> after reading and digesting the
contents of the $file.  This is the most useful top-level method,
and pretty much all you need to I<use> LaTeXML.  

A typical program for converting a TeX file would look like:
   use LaTeXML::Stomach;
   use LaTeXML::Intestine;
   my $stomach = LaTeXML::Stomach->new();
   my $digested = $stomach->readAndDigestFile($source);
   my $document = LaTeXML::Intestine->new($stomach)->buildDOM($digested);
   binmode(STDOUT,":utf8");
   $document->serialize(*STDOUT);

In fact, this is the essence of the script C<latexml>.
All the hard stuff is in the Packages implementing LaTeX packages
for LaTeXML; the remaining methods documented here are useful for
those purposes.

=back

=head2 Methods dealing with digestion

=over 4

=item C<< $gullet = $stomach->getGullet; >>

Returns the current LaTeXML::Gullet used by this $stomach

=item C<< $model = $stomach->getModel; >>

Returns the current LaTeXML::Model used by this $stomach

=item C<< $model = $stomach->getContext($short); >>

Returns a string describing the current position within the source.

=item C<< $list = $stomach->readAndDigestBody; >>

Return the digested L<LaTeXML::List> after reading and digesting a `body'
from the current Gullet.  The body extends until the current
level of boxing or environment is closed.

=item C<< $list = $stomach->digestTokens($tokens,$nofilter); >>

Return the L<LaTeXML::List> resuting from digesting the given tokens.
This is typically used to digest arguments to primitives or
constructors.
If $nofilter is true, filters will not be applied.

=item C<< @boxes = $stomach->digestToken($token); >>

Digest the given $token, returning a list of boxes resulting.
If the $token represents a control sequence whose definition
requires arguments, those arguments will be read from the
current input source.

=item C<< @boxes = $stomach->regurgitate; >>

Removes and returns a list of the boxes already digested 
at the current level.  This peculiar beast is used
by things like \choose (which is a Primitive in TeX, but
a Constructor in LaTeXML).

=back

=head2 Methods dealing with grouping

=over 4

=item C<< $stomach->bgroup($nobox); >>

Begin a new level of binding by pushing a new stack frame.
If $nobox is true, no new level of boxing will be created
(such as for \begingroup).

=item C<< $stomach->egroup($nobox); >>

End a level of binding by popping the last stack frame,
undoing whatever bindings appeared there.
If $nobox is true, the level of boxing will not be decremented
(such as for \endgroup).

=item C<< $stomach->pushAfterGroup(@tokens); >>

Push the @tokens onto a list to be inserted into the input stream
after the next level of grouping ends.  The tokens will
be used only once.

=back

=head2 Methods dealing with modes

=over 4

=item C<< $stomach->beginMode($mode); >>

Begin processing in $mode; one of 'text', 'display-math' or 'inline-math'.
This also begins a new level of grouping and switches to a font
appropriate for the mode.

=item C<< $stomach->endMode($mode); >>

End processing in $mode; an error is signalled if $stomach is not
currently in $mode.  This also ends a level of grouping.

=item C<< $mode = $stomach->getMode; >>

Returns the current mode.

=item C<< $boole = $stomach->inMath; >>

Returns true if the $stomach is currently in a math mode.

=item C<< $stomach->requireMath; >>

Signal an error unless $stomach is in math mode.
(See L<LaTeXML::Error>)

=item C<< $stomach->forbidMath; >>

Signal an error if $stomach is in math mode.
(See L<LaTeXML::Error>)

=item C<< $stomach->beginEnvironment($environment); >>

Begin an environment. This does I<not> start a level of
grouping, but is only for error checking.

=item C<< $stomach->endEnvironment($environment); >>

End an environment; an error is signalled if $stomach isn't currently
processessing $environment.

=back

=head2 Methods dealing with assignment

=over 4

=item C<< $stomach->setPrefix($prefix); >>

Set the prefix (one of 'global', 'long' or 'outer') for the next
assignment operation. (only 'global' is used in LaTeXML).

=item C<< $cattable = $stomach->getCattable; >>

Return the current cattable (a reference to a hash).

=item C<< $stomach->setCattable($cattable); >>

Set the current cattable (a reference to a hash).

=item C<< $cc = $stomach->getCatcode($char); >>

Get the catcode currently associated with $char.
(See L<LaTeXML::Token>)

=item C<< $stomach->setCatcode($cc,@chars); >>

Set the catcode associated with the characters @chars to $cc.
(See L<LaTeXML::Token>)

=item C<< $defn = $stomach->getMeaning($token); >>

Get the definition currently associated with $token, or the token
itself if it shouldn't be executable.
(See L<LaTeXML::Definition>)

=item C<< $stomach->setMeaning($token,$defn,$globally); >>

Set the definition associated with $token to $defn.
If $globally is true, clears $token from all stack frames and
set the definition in the base frame.
(See L<LaTeXML::Definition>, and L<LaTeXML::Package>)

=item C<< $stomach->setValue($name,$value,$globally); >>

Set a value to be associated with the string $name,
possibly globally. This value is stored in a table separate
from Meanings.

=item C<< $value = $stomach->getValue($name); >>

Return the value associated with $name.

=item C<< $stomach->setFont(%style); >>

Set the current font by merging the font style attributes with the current font.
The attributes and likely values (the values aren't required to be in this set):
   family : serif, sansserif, typewriter, caligraphic, fraktur, script
   series : medium, bold
   shape  : upright, italic, slanted, smallcaps
   size   : tiny, footnote, small, normal, large, Large, LARGE, huge, Huge
   color  : any named color, default is black

Some families will only be used in math.

=item C<< $stomach->setMathFont(%style); >>

Set the font that will be used for the I<next> math.
It accepts the same style data as setFont and also C<forcebold> being 0 or 1
to force all symbols to get bold (like \boldmath).

=item C<< $font = $stomach->getFont; >>

Return the current $font.
(See L<LaTeXML::Font>)

=item C<< $stomach->setMathStyle($style); >>

Sets the current math style to one of displa, text, script or scriptscript.

=item C<< $style = $stomach->getMathStyle; >>

Return the current math style.

=item C<< $stomach->stepCounter($counter); >>

Increment the LaTeX-style counter associated with $counter, resetting
any `within' counters.

=item C<< $value = $stomach->refStepCounter($counter); >>

Increment the LaTeX-style counter associated with $counter, resetting any
`within' counters, set \@currentlabel to \the$counter, and
return that Tokens.

=back

=head2 Methods dealing with I/O

=over 4

=item C<< @paths = $stomach->getSearchPaths; >>

Return the list of paths that is currently used to search for files.

=item C<< $stomach->addSearchPath(@paths); >>

Add @paths to the list of search paths.

=item C<< $filename = $stomach->findFile($name,$types); >>

Find a file with $name and one of the types in $types (an array ref)
somewhere in the list of search paths,
and return the filename if found or else undef.

=item C<< $filename = $stomach->findInput($name); >>

Find an input file of type [pm sty tex]

=item C<< $stomach->input($name); >>

Input the file with $name, using findInput.  If the file found
with extension .ltxml, it should be an implementation Package,
otherwise it should be a style or TeX file and it's contents
will be interpreted (hopefully).

=back

=cut
