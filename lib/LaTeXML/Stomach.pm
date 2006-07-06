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
use LaTeXML::Global;
use LaTeXML::Token;
use LaTeXML::Box;
use LaTeXML::Object;
use LaTeXML::Mouth;
use LaTeXML::Font;
use LaTeXML::Definition;
use LaTeXML::Package;
use LaTeXML::Util::Pathname;

our @ISA = qw(LaTeXML::Object);

#**********************************************************************
sub new {
  my($class, %options)=@_;
  my $self= bless {symboltable=>{}, stackundo=>[{}],
		   boxingDepth=>0,
		   environments => [],
		   prefixes=>{},
		   idstore=>{},
		   includeComments=>1,
		   text_filters=>{}, math_filters=>{},
		   packagesLoaded=>{},
		   %options, 
		  }, $class;
  $$self{searchpath}=[] unless $$self{searchpath};
  push(@{$$self{searchpath}},'.', @INC);
  $self; }

#**********************************************************************
# Top level operation
#  to be invoked from LaTeXML
#**********************************************************************

# Read and digest the contents of a file, returning the digested list.
sub readAndDigestFile {
  my($self,$file)=@_;
  $self->initialize;

  my $pathname = pathname_find($file,types=>['tex']);
  Fatal("Cannot find TeX file $file") unless $pathname;
  my($dir,$name,$ext)=pathname_split($pathname);
  $self->addSearchPath($dir);	# Shouldn't permanently change!! ?
  $GULLET->openMouth(LaTeXML::FileMouth->new($pathname,includeComments=>$$self{includeComments}));
  $self->installDefinition(LaTeXML::Expandable->new(T_CS('\jobname'),undef,Tokens(Explode($name))));
  # Is this the best time for this? [Or do I need an AtDocumentBegin?]
  $self->input("$name.latexml") if $self->findInput("$name.latexml");

  NoteProgress("\n(Digesting file $file...");
  my $list = List($self->digestNextBody);
  NoteProgress(')');
  $list; }

# Read and digest a string, which should be a complete TeX document,
# returning the digested list.
sub readAndDigestString {
  my($self,$string)=@_;
  $self->initialize;

  $GULLET->openMouth(LaTeXML::Mouth->new($string,includeComments=>$$self{includeComments}));
  $self->installDefinition(LaTeXML::Expandable->new(T_CS('\jobname'),undef,Tokens(Explode("Unknown"))));
  NoteProgress("\n(Digesting from <string>...");

  my $list = List($self->digestNextBody); 
  NoteProgress(')');
  $list; }

#**********************************************************************
# Initialize various parameters, preload, etc.
sub initialize {
  my($self)=@_;
  $$self{symboltable}={};
  $$self{stackundo}=[{}];
  assign_internal($self,'internal_mode','text');
  assign_internal($self,'internal_math_mode',0);
  assign_internal($self,'value_preserveNewLines',1);
  assign_internal($self,'internal_cattable',{%{getStandardCattable()}});
  assign_internal($self,'internal_aftergroup',[]);
  # Setup default fonts.
  my $font = Font(family=>'serif',series=>'medium',shape=>'upright', size=>'normal',color=>'black');
  assign_internal($self,'value_default@textfont', $font);
  assign_internal($self,'value_current@font', $font);
  assign_internal($self,'value_default@mathfont', 
		  MathFont(family=>'math',series=>'medium',shape=>'italic',
			   size=>'normal',color=>'black',forcebold=>0));
  $self->input('TeX');
  map($self->input($_), @{$$self{preload}}) if $$self{preload};
}

#**********************************************************************
# Digestion
#**********************************************************************
# NOTE: Worry about whether the $autoflush thing is right?
# It puts a lot of cruft in Gullet; Should we just create a new Gullet?

sub digestNextBody {
  my($self)=@_;
  $self->applyFilters($self->digestNextChunk(1)); }

# Digest a list of tokens independent from any current Gullet.
# Typically used to digest arguments to primitives or constructors.
# If $nofilter is true, no filters will be applied to the list
# (eg. for literal type arguments)
# Returns a List or MathList containing the digested material.
sub digest {
  my($self,$tokens,$nofilter)=@_;
  $GULLET->openMouth((ref $tokens eq 'LaTeXML::Token' ? Tokens($tokens) : $tokens->clone));
  $self->clearPrefixes; # prefixes shouldn't apply here.
  my $ismath = $self->inMath;
  my @chunk = $self->digestNextChunk(0);
  @chunk = $self->applyFilters(@chunk) unless $nofilter;
  my $list = (scalar(@chunk) == 1 ? $chunk[0] 
	      : ($ismath ? MathList(@chunk) : List(@chunk)));
  $GULLET->closeMouth;
  $list; }

# Digest the next `chunk' of input, returning a list of digested
# Boxes, Lists, Whatsits.  Return a list of the digested material
# until the current mode is done.  Returns () when the source is exhausted.
# If $autoflush is true, when a source is exhausted, it gets flushed
# and we continue to read from the containing source.
sub digestNextChunk {
  my($self,$autoflush)=@_;
  my $depth  = $$self{boxingDepth};
  local @LaTeXML::LIST=();
  while(defined(my $token=$GULLET->readXToken($autoflush))){ # Done if we run out of tokens
    push(@LaTeXML::LIST,$self->invokeToken($token));
    last if $depth > $$self{boxingDepth}; } # if we've closed the initial mode.
  @LaTeXML::LIST; }

our @forbidden_cc = (1,0,0,0, 0,0,1,0, 0,1,0,0, 0,0,0,1, 0,1);

# Invoke a token; 
# If it is a primitive or constructor, it's definition will be invoked, 
# possibly arguments will be parsed from the Gullet.
# Otherwise, the token is simply digested: turned into an appropriate box.
# Returns a list of boxes/whatsits.
sub invokeToken {
  my($self,$token)=@_;
  my $meaning = $self->lookupMeaning($token);
  if(! defined $meaning){		# Supposedly executable token, but no definition!
    my $cs = $token->getCSName;
    Error("$cs is not defined.");
    DefConstructor($cs,"<ERROR type='undefined'>".$cs."</ERROR>",mode=>'text');
    $self->invokeToken($token); }
  elsif($meaning->isaDefinition){
    my @stuff = CheckBoxes($meaning->invoke);
    $self->clearPrefixes() unless $meaning->isPrefix; # Clear prefixes unless we just set one.
    @stuff; }
  elsif($meaning->isaToken) {
    my $cc = $meaning->getCatcode;
    $self->clearPrefixes; # prefixes shouldn't apply here.
    if(($cc == CC_SPACE) && ( ($self->inMath || $self->inPreamble) )){ 
      (); }
    elsif($cc == CC_COMMENT){
      LaTeXML::Comment->new($meaning->getString); }
    elsif($forbidden_cc[$cc]){
      Fatal("[Internal] ".Stringify($token)." should never reach Stomach!"); }
    elsif($self->inMath){
      my $string = $meaning->getString;
      MathBox($string,$self->getFont->specialize($string),$GULLET->getLocator); }
    else {
      Box($meaning->getString, $self->getFont,$GULLET->getLocator); }}
  else {
    Fatal("[Internal] ".Stringify($meaning)." should never reach Stomach!"); }}

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
# Note that filters act on Boxes, not Tokens!

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
#print STDERR "Apply filter to ".ToString($init)."\n";
      my $table = ($item->isMath ? $$self{math_filters} : $$self{text_filters});
      foreach my $pair (@{$$table{$init}||[]}){
	my($pattern,$replacement)=@$pair;
#print STDERR "Try ".ToString($pattern)." => ".ToString($replacement)."\n";
	if($np =(ref $pattern eq 'CODE' ? &$pattern(@list) : match($pattern,@list))){
	  my @match = map(shift(@list), 0..$np-1);
	  my @rep = ();
	  if(ref $replacement eq 'CODE'){
	    @rep = &$replacement(grep(ref $_ ne 'LaTeXML::Comment',@match)); }
	  else {
	    my $font = $item->getFont;
	    # Risky: set the replacement boxes to same font. 
	    # It's sometimes the right thing to do; make it optional somehow?
#	    @rep = map((ref $_ eq 'LaTeXML::Box' ? Box($_->getString,$font,$item->getLocator) : $_),@$replacement); }
	    @rep = map((ref $_ eq 'LaTeXML::Box' ? Box($_->getString,$font,$item->getLocator) : $_),
		       $replacement->unlist); }
	  CheckBoxes(@rep);
	  # Annoying, but we'd better check if the replacement is different
	  my @matchcopy=@match;
	  my @repcopy = @rep;
	  while(@matchcopy && @repcopy && ($matchcopy[0]->equals($repcopy[0]))){
	    shift(@matchcopy); shift(@repcopy); }
	  if(!(@matchcopy) && !(@repcopy)){ # Whoops, they're the same!
#	  my($mstring,$rstring);
#	  if(0 && ($np == scalar(@rep))
#	     && (    ($mstring = join('',map($_->untex,@match)))
#		  eq ($rstring = join('',map($_->untex,@rep)))   )){
#	    Warn("Filter match \"$mstring\" same as replacement \"$rstring\" !");
	    Warn("Filter match \"".ToString(List(@match))
		 ."\" same as replacement \"".ToString(List(@rep))."\" !");
	    unshift(@list,@match); $np=0; last; } # Just abort this position.
	  else {
#print STDERR "Replaced ".ToString(List(@list))." => ".ToString(List(@rep))."\n";
	    unshift(@list,@rep);
	    last; }}}}		# We'll try more filters at same pos.
    if(!$np){
      push(@out,shift(@list)); }} # Next starting position.
  @out; }

# Return number of boxes matched or 0 if failed.
sub match {
  my($pattern,@list)=@_;
#  my @pattern = @$pattern;
  my @pattern = $pattern->unlist;
  my $n=0;
  while(@list && @pattern && ($list[0]->equals($pattern[0]))){
    shift(@list); shift(@pattern);  $n++; }
  (@pattern ? 0 : $n); }

#**********************************************************************
# Maintaining State.
#**********************************************************************

#======================================================================
# Stack Frames: Internal support for context, lookup & assignment.  Non-methods.

# Assign a definition or variable (depending on table being bindings, values, resp).
# If $globally is non-0 or if $$self{globally} has been (temporarily) set by Stomach,
# remove all bound values and assign in lowest frame.  Otherwise assign in current frame.

# Dealing with TeX's bindings & grouping.
# Note that lookups happen more often than bgroup/egroup (which open/close frames).

sub pushStackFrame {
  my($self)=@_;
  # Easy: just push a new undo hash.
  unshift(@{$$self{stackundo}},{}); 
  assign_internal($self,'internal_aftergroup',[]); # ALWAYS bind this!
}

sub popStackFrame {
  my($self)=@_;
  my $undo = shift(@{$$self{stackundo}});
  foreach my $key (keys %$undo){
    shift(@{$$self{symboltable}{$key}}); }
}

# To Lookup a value, use
#   $$self{symboltable}{$prefixed_name}[0];

sub assign_internal {
  my($self,$key,$value,$globally)=@_;
  $globally ||= $$self{prefixes}{global};
  if($globally){
    foreach my $undo (@{$$self{stackundo}}){ # These no longer should get undone.
      delete $$undo{$key};}
    $$self{symboltable}{$key} = [$value]; } # And place single value in table.
  elsif($$self{stackundo}[0]{$key}){ # Already set for undo.
    $$self{symboltable}{$key}[0] = $value; } # so just change binding.
  else {
    $$self{stackundo}[0]{$key}=1; # Note that this value must be undone
    unshift(@{$$self{symboltable}{$key}},$value); }} # And push new binding.

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
  my $after = $$self{symboltable}{internal_aftergroup}[0];
  popStackFrame($self);
  $$self{boxingDepth}-- unless $nobox; # For begingroup/endgroup
  $GULLET->unread(@$after) if $after;
  return; }

# A list of boxes/whatsits output after the current group closes.
sub pushAfterGroup {
  my($self,@tokens)=@_;
  unshift(@{$$self{symboltable}{internal_aftergroup}[0]},@tokens);
  return; }

#======================================================================
# Mode (minimal so far; math vs text)
# Could (should?) be taken up by Stomach by building horizontal, vertical or math lists ?
sub inMath {
  my($self)=@_;
  $$self{symboltable}{internal_math_mode}[0]; }

sub getMode {
  my($self)=@_;
  $$self{symboltable}{internal_mode}[0]; }

sub beginMode {
  my($self,$mode)=@_;
  $self->bgroup;
  my $prevmode =  $$self{symboltable}{internal_mode}[0]; 
  my $ismath = $mode=~/math$/;
  assign_internal($self,'internal_mode',$mode);
  assign_internal($self,'internal_math_mode',$ismath);
  if($mode eq $prevmode){}
  elsif($mode =~ /math$/){
    # When entering math mode, we set the font to the default math font,
    # and save the text font for any embedded text.
    assign_internal($self,'value_saved@textfont',$$self{symboltable}{'value_current@font'}[0]);
    assign_internal($self,'value_current@font',  $$self{symboltable}{'value_default@mathfont'}[0]);
    assign_internal($self,'value_mathstyle', ($mode =~ /^display/ ? 'display' : 'text')); }
  else {
    # When entering text mode, we should set the font to the text font in use before the math.
    assign_internal($self,'value_current@font',$$self{symboltable}{'value_saved@textfont'}[0]); }
  return; }

sub endMode {
  my($self,$mode)=@_;
  my $prevmode =  $$self{symboltable}{internal_mode}[0];
  Fatal("Can't end mode $mode: Was in mode $prevmode!!") if $mode && !($mode eq $prevmode);
  $self->egroup; }		# Return whatever egroup returns.

#======================================================================
sub beginEnvironment {
  my($self,$environment)=@_;
  push(@{$$self{environments}},$environment); 
  return; }

sub endEnvironment {
  my($self,$environment)=@_;
  my $env = pop(@{$$self{environments}});
  Fatal("Can't close environment $environment: current is $env!") unless $env eq $environment;
  return; }

#======================================================================
# Whether we're in the Preamble (for LaTeX)

sub inPreamble { $_[0]->{inPreamble}; }
sub setInPreamble { $_[0]->{inPreamble} = $_[1]; return; }

#======================================================================
# Set/Get catcodes, or the current table of catcodes.
#======================================================================

sub getCattable {
  my($self)=@_;
  $$self{symboltable}{internal_cattable}[0]; }

sub setCattable {
  my($self,$cattable)=@_;
  assign_internal($self,'internal_cattable',$cattable); }

sub lookupCatcode {
  my($self,$char)=@_;
  my $cc =  $$self{symboltable}{internal_cattable}[0]{$char};
  (defined $cc ? $cc : CC_OTHER); }

sub assignCatcode {
  my($self,$catcode,@chars)=@_;
  if(! $$self{stackundo}[0]{'internal_cattable'}){ # Cattable has NOT been copied in this frame!
    my $old = $$self{symboltable}{internal_cattable}[0];
    assign_internal($self,'internal_cattable',{%{$old}}); }
  my $cattable = $$self{symboltable}{internal_cattable}[0];
  map($$cattable{$_}=$catcode, @chars); }

# Perverse means to handle \mathcode = "8000
# Ie. a char acts as if active in math mode.
sub setMathActive {
  my($self,@chars)=@_;
  map( assign_internal($self,'mathactive_'.$_,1), @chars); }

sub getMathActive {
  my($self,$char)=@_;
  $$self{symboltable}{internal_math_mode}[0]
    &&  $$self{symboltable}{'mathactive_'.$char}[0] }

#======================================================================
# Lookup or add the `meaning' (definition) of a token or control sequence.

our @executable_cc= (0,1,1,1, 1,0,0,1, 1,0,0,0, 0,1,0,0, 1,0);

# Get the `Meaning' of a token.  For a control sequence or otherwise active token,
# this may give the definition object or a regular token (if it was \let), or undef.
# Otherwise, the token itself is returned.
sub lookupMeaning {
  my($self,$token)=@_;
  # NOTE: Inlined token accessors!!!
  my $cs = $$token[0];
  my $cc = $$token[1];
  if($executable_cc[$cc]
     || ($$self{symboltable}{internal_math_mode}[0] &&  $$self{symboltable}{'mathactive_'.$cs}[0])){
    $$self{symboltable}{'binding_'.$token->getCSName}[0] }
  else {
    $token; }}

sub assignMeaning {
  my($self,$token,$defn,$globally)=@_;
  assign_internal($self,'binding_'.$token->getCSName, $defn,$globally); }

# This is similar to lookupMeaning, but when you are only interested in executable defns.
sub lookupDefinition {
  my($self,$token)=@_;
  my $cs = $$token[0];
  my $cc = $$token[1];
  if($executable_cc[$cc]
     || ($$self{symboltable}{internal_math_mode}[0] &&  $$self{symboltable}{'mathactive_'.$cs}[0])){
    my $defn = $$self{symboltable}{'binding_'.$token->getCSName}[0];
    (defined $defn && $defn->isaDefinition ? $defn : undef); }
  else { undef; }}

# And a shorthand for installing definitions
# It also supports `stashing' the definitions into lists (eg modules)
# that can be reinstalled later by invoking $self->useStash($stash);
sub installDefinition {
  my($self,$definition,%options)=@_;
  $self->assignMeaning($definition->getCS,$definition,($options{globally} ? 1 : 0));
  if(defined(my $stash = $options{stash})){
    my $stashname = 'value_'.ToString($stash);
    assign_internal($self,$stashname,[],1) unless $$self{symboltable}{$stashname}[0];
    push(@{ $$self{symboltable}{$stashname}[0] }, $definition); }}

sub useStash {
  my($self,$stash)=@_;
  if(defined (my $defns = $$self{symboltable}{'value_'.ToString($stash)}[0])){
    map( $self->assignMeaning($_->getCS,$_,0), @$defns); }}

#======================================================================
# Lookup or set the value of a parameter/register/whatever.
# (a register is simply named "\count1").

sub assignValue {
  my($self,$name,$value,$globally)=@_;
  assign_internal($self,'value_'.$name,$value,$globally);
  return; }

sub lookupValue {
  my($self,$name)=@_;
  $$self{symboltable}{'value_'.$name}[0] }

#======================================================================
sub recordID {
  my($self,$id,$object)=@_;
  $$self{idstore}{$id}=$object; }

sub lookupID {
  my($self,$id)=@_;
  $$self{idstore}{$id}; }

#======================================================================
# Fonts
# Generalized notion of `font' representing anything that affects the
# display of a glphy: family, series, shape, size and color.

sub setFont {
  my($self,%style)=@_;
  assign_internal($self,'value_current@font',$$self{symboltable}{'value_current@font'}[0]->merge(%style));
  return; }

# This modifies the default math font
sub setMathFont {
  my($self,%style)=@_;
  assign_internal($self,'value_default@mathfont',
		  $$self{symboltable}{'value_default@mathfont'}[0]->merge(%style));
  return; }

sub getFont {
  my($self)=@_;
  $$self{symboltable}{'value_current@font'}[0]; }

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
    if(!$sp){
      Warn("Unknown unit \"$unit\"; assuming pt.");
      $sp = $UNITS{'pt'}; }
    $sp; }}

#======================================================================
# MathStyle: Display, Text, Script or ScriptScript

# NOTE: Do something about font size, or scriptlevel?
sub setMathStyle { 
  my($self,$style)=@_;
  Warn("Unknown math style: \"$style\"") unless $style=~/^display|text|script|scriptscript$/;
  assign_internal($self,'value_mathstyle',$_[1]); 
  return; }

sub getMathStyle {
  my($self)=@_;
  $$self{symboltable}{value_mathstyle}[0]; }

#======================================================================
# Additional support for Counters (primarily LaTeX).
# See LaTeXML::Package for definition of the variables used in a counter.
sub stepCounter {
  my($self,$ctr)=@_;
  $ctr=$ctr->toString if ref $ctr;
  $self->assignValue("\\c\@$ctr",$self->lookupValue("\\c\@$ctr")->add(Number(1)),1);
  # and reset any within counters!
  foreach my $c ($self->lookupValue("\\cl\@$ctr")->unlist){
    $self->resetCounter($c); }
}

sub refStepCounter {
  my($self,$ctr)=@_;
  $ctr=$ctr->toString if ref $ctr;
  $self->stepCounter($ctr);
  my $v = $GULLET->expandTokens(Tokens(T_CS("\\the$ctr")));
  $self->assignMeaning(T_CS('\@currentlabel'),LaTeXML::Expandable->new(T_CS('\@currentlabel'),undef,$v));
  $v; }

sub resetCounter {
  my($self,$ctr)=@_;
  $ctr=$ctr->toString if ref $ctr;
  $self->assignValue('\c@'.$ctr,Number(0),1); }
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
# NOTE: options from usepackage, etc, get carried to here.
# For latexml implementations, the global $LaTeXML::PACKAGE_OPTIONS gets 
# bound to them, but NOTHING is done to pass them to TeX style files!

# HMM: the packageLoaded check only makes sense for style files, and
# is probably only important for latexml implementations?
sub input {
  my($self,$name,%options)=@_;
  $name = $name->toString if ref $name;
  if($$self{packagesLoaded}{$name}){
    Warn("Package $name already loaded");
    return; }
  # Try to find a Package implementing $name.
  local @LaTeXML::PACKAGE_OPTIONS = @{$options{options}||[]};
  $name = $1 if $name =~ /^\{(.*)\}$/; # just in case
  my $file=$self->findInput($name);
  if($file =~ /\.(ltxml|latexml)$/){		# Perl module.
    my($dir,$modname)=pathname_split($file);
    NoteProgress("\n(Loading $file");
    $GULLET->openMouth(LaTeXML::PerlMouth->new($file));
    do $file; 
#    $GULLET->closeMouth;
    Fatal("Package $name had an error:\n  $@") if $@;
  }
  # Hmm, very slightly different treatment needed for .sty and .tex ?
  elsif($file){
    my $isstyle = ($file =~ /\.sty$/);
    NoteProgress("\n(Loading Style $file");
    my $comments = $$self{includeComments} && !$isstyle;
    my $atcc = $self->lookupCatcode('@');
    $self->assignCatcode(CC_LETTER,'@') if $isstyle;
    $GULLET->openMouth(LaTeXML::FileMouth->new($file,includeComments=>$comments,
					      ($isstyle ? (after=>"\\catcode`\\\@=$atcc\\relax") :())
					     ));
  }
  else {
    Error("Cannot find LaTeXML implementation, style or tex file for $name."); }
  $$self{packagesLoaded}{$name}=1;
  NoteProgress(")");
}

#**********************************************************************
# A fake mouth provides a hook for getting the Locator of anything
# defined in a perl module (*.pm, *.ltxml, *.latexml...)
package LaTeXML::PerlMouth;

sub new {
  my($class,$file)=@_;
  bless {file=>$file},$class; }

# Evolve to figure out if this gets dynamic location!
sub getLocator {
  my($self)=@_;
  my $file = $$self{file};
  my $line = LaTeXML::Error::line_in_file($file);
#my $line = "Lost";
  $file.($line ? " line $line":''); }

sub hasMoreInput { 0; }
sub readToken { undef; }
#**********************************************************************
1;

__END__

=pod 

=head1 LaTeXML::Stomach

=head2 DESCRIPTION

C<LaTeXML::Stomach> digests tokens read from a L<LaTeXML::Gullet>
(they will have already been expanded).  The Stomach also 
maintains all of the state relevant during the overall process
of digestion (including tokenization and expansion;
see L<LaTeXML::Mouth> and L<LaTeXML::Gullet>)

=head2 Top-level Methods

=over 4

=item C<< $list = $STOMACH->readAndDigestFile($pathname); >>

Reads and digests the contents of the file, returning the
digested list.  This is a top-level method of C<LaTeXML::Stomach>,
but should be invoked from within a L<LaTeXML> object, which
binds the appropriate globals.


=item C<< $list = $STOMACH->readAndDigestString($string); >>

Reads and digests a string, which should contain a complete Tex
document returning the digested list.  This is a top-level 
method of C<LaTeXML::Stomach>, but should be invoked from within 
a L<LaTeXML> object, which binds the appropriate globals.

=head2 Methods dealing with digestion

=over 4

=item C<< $list = $STOMACH->digestNextBody; >>

Return the digested L<LaTeXML::List> after reading and digesting a `body'
from the current Gullet.  The body extends until the current
level of boxing or environment is closed.  This uses C<digestNextChunk>,
but applies filters to the resulting list.

=item C<< $list = $STOMACH->digest($tokens,$nofilter); >>

Return the L<LaTeXML::List> resuting from digesting the given tokens.
This is typically used to digest arguments to primitives or
constructors. If C<$nofilter> is true, filters will not be applied.

=item C<< $list = $STOMACH->digestNextChunk; >>

Return the digested L<LaTeXML::List> after reading and digesting a 
the next `chunk' (essentially an environment body or math mode list)
from the current Gullet.  The chunk extends until the current
level of boxing or environment is closed.

=item C<< @boxes = $STOMACH->invokeToken($token); >>

Invoke the given (expanded) token.  If it corresponds to a
Primitive or Constructor, the definition will be invoked,
reading any needed arguments fromt he current input source.
Otherwise, the token will be digested.
A List of Box's, Lists, Whatsit's is returned.

=item C<< @boxes = $STOMACH->regurgitate; >>

Removes and returns a list of the boxes already digested 
at the current level.  This peculiar beast is used
by things like \choose (which is a Primitive in TeX, but
a Constructor in LaTeXML).

=back

=head2 Methods dealing with grouping

=over 4

=item C<< $STOMACH->bgroup($nobox); >>

Begin a new level of binding by pushing a new stack frame.
If C<$nobox> is true, no new level of boxing will be created
(such as for \begingroup).

=item C<< $STOMACH->egroup($nobox); >>

End a level of binding by popping the last stack frame,
undoing whatever bindings appeared there.
If C<$nobox> is true, the level of boxing will not be decremented
(such as for \endgroup).

=item C<< $STOMACH->pushAfterGroup(@tokens); >>

Push the C<@tokens> onto a list to be inserted into the input stream
after the next level of grouping ends.  The tokens will
be used only once.

=back

=head2 Methods dealing with modes

=over 4

=item C<< $STOMACH->beginMode($mode); >>

Begin processing in C<$mode>; one of 'text', 'display-math' or 'inline-math'.
This also begins a new level of grouping and switches to a font
appropriate for the mode.

=item C<< $STOMACH->endMode($mode); >>

End processing in C<$mode>; an error is signalled if C<$STOMACH> is not
currently in C<$mode>.  This also ends a level of grouping.

=item C<< $mode = $STOMACH->getMode; >>

Returns the current mode.

=item C<< $boole = $STOMACH->inMath; >>

Returns true if the C<$STOMACH> is currently in a math mode.

=item C<< $STOMACH->beginEnvironment($environment); >>

Begin an environment. This does I<not> start a level of
grouping, but is only for error checking.

=item C<< $STOMACH->endEnvironment($environment); >>

End an environment; an error is signalled if C<$STOMACH> isn't currently
processessing $environment.

=item C<< $boole = $STOMACH->inPreamble; >>

Returns whether or not we are in the preamble of the document, in 
the LaTeX sense; spaces and such are ignored in the preamble.

=item C<< $STOMACH->setInPreamble($value); >>

Specifies whether or not we are in the preamble of the document, in 
the LaTeX sense.

=back

=head2 Methods dealing with assignment

=over 4

=item C<< $STOMACH->setPrefix($prefix); >>

Set the prefix (one of 'global', 'long' or 'outer') for the next
assignment operation. (only 'global' is used in LaTeXML).

=item C<< $cattable = $STOMACH->getCattable; >>

Return the current cattable (a reference to a hash).

=item C<< $STOMACH->setCattable($cattable); >>

Set the current cattable (a reference to a hash).

=item C<< $cc = $STOMACH->lookupCatcode($char); >>

Get the catcode currently associated with C<$char>.
(See L<LaTeXML::Token>)

=item C<< $STOMACH->assignCatcode($cc,@chars); >>

Set the catcode associated with the characters C<@chars> to C<$cc>.
(See L<LaTeXML::Token>)

=item C<< $boole = $STOMACH->getMathActive($char); >>

Returns whether this C<$char> would be considered active
in math mode, such as the prime character.

=item C<< $STOMACH->setMathActive(@chars); >>

Makes each of the C<@chars> active in math mode, such as the prime character.

=item C<< $defn = $STOMACH->lookupMeaning($token); >>

Get the "meaning" currently associated with C<$token>,
either the definition (if it is a control sequence or active character)
 or the token itself if it shouldn't be executable.
(See L<LaTeXML::Definition>)

=item C<< $STOMACH->assignMeaning($token,$defn,$globally); >>

Set the definition associated with C<$token> to C<$defn>.
If C<$globally> is true, it makes this the global definition
rather than bound within the current group.
(See L<LaTeXML::Definition>, and L<LaTeXML::Package>)

=item C<< $defn = $STOMACH->lookupDefinition($token); >>

Lookup the definition assocated with C<$token>, taking into account
characters that are only active in math mode.

=item C<< $STOMACH->installDefinition($definition, globally=>1, stash=>$stashname); >>

Install the definition into the current stack frame under its normal control sequence.

The stash option also stores the definition in a list named by C<$stashname>,
for later reuse by C<< $STOMACH->useStash($stashname); >>  This may be used
for supporting `modules' and other scoping mechanisms.

=item C<< $STOMACH->useStash($stashname); >>

Installs (reinstalls) the definitions that were previously stored in
the list named by C<$stashname>, but which may have gone out of scope
in the meantime.

=item C<< $STOMACH->assignValue($name,$value,$globally); >>

Set a value to be associated with the string C<$name>,
possibly globally. This value is stored in a table separate
from Meanings.

=item C<< $value = $STOMACH->lookupValue($name); >>

Return the value associated with C<$name>.

=item C<< $STOMACH->setFont(%style); >>

Set the current font by merging the font style attributes with the current font.
The attributes and likely values (the values aren't required to be in this set):

   family : serif, sansserif, typewriter, caligraphic, fraktur, script
   series : medium, bold
   shape  : upright, italic, slanted, smallcaps
   size   : tiny, footnote, small, normal, large, Large, LARGE, huge, Huge
   color  : any named color, default is black

Some families will only be used in math.

=item C<< $STOMACH->setMathFont(%style); >>

Set the font that will be used for the I<next> math.
It accepts the same style data as setFont and also C<forcebold> being 0 or 1
to force all symbols to get bold (like \boldmath).

=item C<< $font = $STOMACH->getFont; >>

Return the current C<$font>.
(See L<LaTeXML::Font>)

=item C<< $STOMACH->setMathStyle($style); >>

Sets the current math style to one of display, text, script or scriptscript.

=item C<< $style = $STOMACH->getMathStyle; >>

Return the current math style.

=item C<< $STOMACH->stepCounter($counter); >>

Increment the LaTeX-style counter associated with C<$counter>, resetting
any `within' counters.

=item C<< $value = $STOMACH->refStepCounter($counter); >>

Increment the LaTeX-style counter associated with C<$counter>, resetting any
`within' counters, set \@currentlabel to \the$counter, and
return that Tokens.

=back

=head2 Methods dealing with I/O

=over 4

=item C<< @paths = $STOMACH->getSearchPaths; >>

Return the list of paths that is currently used to search for files.

=item C<< $STOMACH->addSearchPath(@paths); >>

Add C<@paths> to the list of search paths.

=item C<< $filename = $STOMACH->findFile($name,$types); >>

Find a file with C<$name> and one of the types in C<$types> (an array ref)
somewhere in the list of search paths,
and return the filename if found or else undef.

=item C<< $filename = $STOMACH->findInput($name); >>

Find an input file of type [pm sty tex]

=item C<< $STOMACH->input($name); >>

Input the file with C<$name>, using findInput.  If the file found
with extension .ltxml, it should be an implementation Package,
otherwise it should be a style or TeX file and it's contents
will be interpreted (hopefully).

=back

=cut
