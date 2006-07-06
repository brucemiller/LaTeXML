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
use LaTeXML::State;
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
  my $self= bless {boxing=>[],
		   idstore=>{},
		   includeComments=>1,
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
  $STATE->installDefinition(LaTeXML::Expandable->new(T_CS('\jobname'),undef,Tokens(Explode($name))));
  # Is this the best time for this? [Or do I need an AtDocumentBegin?]
  $self->input("$name.latexml") if $self->findInput("$name.latexml");

  NoteProgress("\n(Digesting file $file...");
  local $LaTeXML::CURRENT_TOKEN = undef;
  my $list = LaTeXML::List->new($self->digestNextBody);
  $GULLET->closeMouth;
  NoteProgress(')');
  $list; }

# Read and digest a string, which should be a complete TeX document,
# returning the digested list.
sub readAndDigestString {
  my($self,$string)=@_;
  $self->initialize;

  $GULLET->openMouth(LaTeXML::Mouth->new($string,includeComments=>$$self{includeComments}));
  $STATE->installDefinition(LaTeXML::Expandable->new(T_CS('\jobname'),undef,Tokens(Explode("Unknown"))));
  NoteProgress("\n(Digesting from <string>...");
  local $LaTeXML::CURRENT_TOKEN = undef;
  my $list = LaTeXML::List->new($self->digestNextBody); 
  $GULLET->closeMouth;
  NoteProgress(')');
  $list; }

#**********************************************************************
# Initialize various parameters, preload, etc.
sub initialize {
  my($self)=@_;
  $$self{boxing} = [];
  $STATE->assign('internal', mode=>'text','global');
  $STATE->assign('internal', math_mode=>0,'global');
  $STATE->assign('value',    preserveNewLines=>1,'global');
  $STATE->assign('value',    includeComments=>$$self{includeComments},'global');
  $STATE->assign('internal', aftergroup=>[],'global');
  # Setup default fonts.
  $STATE->assign('value', font=>LaTeXML::Font->default(),'global');
  $STATE->assign('value', mathfont=>LaTeXML::MathFont->default(),'global');
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
  $self->digestNextChunk(1,0); }

# Digest a list of tokens independent from any current Gullet.
# Typically used to digest arguments to primitives or constructors.
# If $nofilter is true, no filters will be applied to the list
# (eg. for literal type arguments)
# Returns a List or MathList containing the digested material.
sub digest {
  my($self,$tokens,$nofilter)=@_;
  $GULLET->openMouth((ref $tokens eq 'LaTeXML::Token' ? Tokens($tokens) : $tokens->clone));
  $STATE->clearPrefixes; # prefixes shouldn't apply here.
  my $ismath = $self->inMath;
  my @chunk = $self->digestNextChunk(0,$nofilter);
  my $list = (scalar(@chunk) == 1 ? $chunk[0] 
	      : ($ismath ? LaTeXML::MathList->new(@chunk) : LaTeXML::List->new(@chunk)));
  $GULLET->closeMouth;
  $list; }

# Digest the next `chunk' of input, returning a list of digested
# Boxes, Lists, Whatsits.  Return a list of the digested material
# until the level of boxing (eg grouping or mode) is done.  
# Returns () when the source is exhausted.
# If $autoflush is true, when a source is exhausted, it gets flushed
# and we continue to read from the containing source.
sub digestNextChunk {
  my($self,$autoflush)=@_;
  my $initdepth  = scalar(@{$$self{boxing}});
  my $depth=$initdepth;
  local @LaTeXML::LIST=();
  while(defined(my $token=$GULLET->readXToken($autoflush))){ # Done if we run out of tokens
    push(@LaTeXML::LIST, $self->invokeToken($token));
    my $depth  = scalar(@{$$self{boxing}});
    last if $initdepth > $depth; } # if we've closed the initial mode.
  Fatal("We've fallen off the end, somehow!?!?!\n Last token ".ToString($LaTeXML::CURRENT_TOKEN)
	." (Boxing depth was $initdepth, now $depth: Boxing generated by "
	.join(', ',map(ToString($_),@{$$self{boxing}})))
    if $initdepth < $depth;
  @LaTeXML::LIST; }

our @forbidden_cc = (1,0,0,0, 0,0,1,0, 0,1,0,0, 0,0,0,1, 0,1);

# Invoke a token; 
# If it is a primitive or constructor, the definition will be invoked,
# possibly arguments will be parsed from the Gullet.
# Otherwise, the token is simply digested: turned into an appropriate box.
# Returns a list of boxes/whatsits.
sub invokeToken {
  my($self,$token)=@_;
 $LaTeXML::CURRENT_TOKEN = $token;
  my $meaning = $STATE->lookupMeaning($token);
  if(! defined $meaning){		# Supposedly executable token, but no definition!
    my $cs = $token->getCSName;
    Error("$cs is not defined.");
    DefConstructor($cs,"<ERROR type='undefined'>".$cs."</ERROR>",mode=>'text');
    $self->invokeToken($token); }
  elsif($meaning->isaDefinition){
    my @boxes = $meaning->invoke;
    my @err = grep( ! $_->isaBox, @boxes);
    Fatal("Execution of ".ToString($token)." yielded non boxes: ".join(',',map(Stringify($_),@err))) if @err;
    $STATE->clearPrefixes unless $meaning->isPrefix; # Clear prefixes unless we just set one.
    @boxes; }
  elsif($meaning->isaToken) {
    my $cc = $meaning->getCatcode;
    $STATE->clearPrefixes; # prefixes shouldn't apply here.
    if(($cc == CC_SPACE) && ( ($self->inMath || $self->inPreamble) )){ 
      (); }
    elsif($cc == CC_COMMENT){
      LaTeXML::Comment->new($meaning->getString); }
    elsif($forbidden_cc[$cc]){
      Fatal("[Internal] ".Stringify($token)." should never reach Stomach!"); }
    elsif($self->inMath){
      my $string = $meaning->getString;
      LaTeXML::MathBox->new($string,$STATE->lookup('value','font')->specialize($string),$GULLET->getLocator); }
    else {
      LaTeXML::Box->new($meaning->getString, $STATE->lookup('value','font'),$GULLET->getLocator); }}
  else {
    Fatal("[Internal] ".Stringify($meaning)." should never reach Stomach!"); }}

# Regurgitate: steal the previously digested boxes from the current level.
sub regurgitate {
  my($self)=@_;
  my @stuff = @LaTeXML::LIST;
  @LaTeXML::LIST=();
  @stuff; }

#**********************************************************************
# Maintaining State.
#**********************************************************************
# State changes that the Stomach needs to moderate and know about (?)

#======================================================================
# Stack Frames: Internal support for context, lookup & assignment.  Non-methods.

# Assign a definition or variable (depending on table being bindings, values, resp).
# If $globally is non-0 or if $$self{globally} has been (temporarily) set by Stomach,
# remove all bound values and assign in lowest frame.  Otherwise assign in current frame.

# Dealing with TeX's bindings & grouping.
# Note that lookups happen more often than bgroup/egroup (which open/close frames).

sub pushStackFrame {
  my($self,$nobox)=@_;
  $STATE->pushFrame;
  $STATE->assign('internal', aftergroup=>[],'local'); # ALWAYS bind this!
  push(@{$$self{boxing}},$LaTeXML::CURRENT_TOKEN) unless $nobox; # For begingroup/endgroup
}

sub popStackFrame {
  my($self,$nobox)=@_;
  my $after = $STATE->lookup('internal','aftergroup');
  $STATE->popFrame;
  pop(@{$$self{boxing}}) unless $nobox; # For begingroup/endgroup
  $GULLET->unread(@$after) if $after;
}

#======================================================================
# Grouping pushes a new stack frame for binding definitions, etc.
#======================================================================

# if $nobox is true, inhibit incrementing the boxingLevel
sub bgroup {
  my($self,$nobox)=@_;
  pushStackFrame($self,$nobox);
  return; }

sub egroup {
  my($self,$nobox)=@_;
  if($STATE->boundInFrame('internal','mode')){ # Last stack frame was a mode switch!?!?!
    Fatal("Unbalanced \$ or \} while ending group for ".$LaTeXML::CURRENT_TOKEN->getCSName); }
  popStackFrame($self,$nobox);
  return; }

# A list of boxes/whatsits output after the current group closes.
sub pushAfterGroup {
  my($self,@tokens)=@_;
  $STATE->push('internal','aftergroup',@tokens);
  return; }

#======================================================================
# Mode (minimal so far; math vs text)
# Could (should?) be taken up by Stomach by building horizontal, vertical or math lists ?
sub inMath {
  my($self)=@_;
  $STATE->lookup('internal','math_mode'); }

sub getMode {
  my($self)=@_;
  $STATE->lookup('internal','mode'); }

sub beginMode {
  my($self,$mode)=@_;
  $self->pushStackFrame;	# Effectively bgroup
  my $prevmode =  $STATE->lookup('internal','mode');
  my $ismath = $mode=~/math$/;
  $STATE->assign('internal', mode=>$mode,'local');
  $STATE->assign('internal', math_mode=>$ismath,'local');
  unshift(@{$$self{modes}},$mode);
  if($mode eq $prevmode){}
  elsif($ismath){
    # When entering math mode, we set the font to the default math font,
    # and save the text font for any embedded text.
    $STATE->assign('internal', savedfont=>$STATE->lookup('value','font'),'local');
    $STATE->assign('value',    font     =>$STATE->lookup('value','mathfont'),'local');
    $STATE->assign('value',    mathstyle=>($mode =~ /^display/ ? 'display' : 'text'),'local'); }
  else {
    # When entering text mode, we should set the font to the text font in use before the math.
    $STATE->assign('value', font=>$STATE->lookup('internal','savedfont'),'local'); }
  return; }

sub endMode {
  my($self,$mode)=@_;
  if(! $STATE->boundInFrame('internal','mode')){ # Last stack frame was NOT a mode switch!?!?!
    Fatal("Unbalanced \$ or \} while ending mode $mode for ".$LaTeXML::CURRENT_TOKEN->getCSName); }
  elsif($STATE->lookup('internal','mode') ne $mode){
    Fatal("Can't end mode $mode: Was in mode ".$STATE->lookup('internal','mode')."!!"); }
  $self->popStackFrame;		# Effectively egroup.
 return; }

#======================================================================
# Whether we're in the Preamble (for LaTeX)

sub inPreamble { $_[0]->{inPreamble}; }
sub setInPreamble { $_[0]->{inPreamble} = $_[1]; return; }

#======================================================================
sub recordID {
  my($self,$id,$object)=@_;
  $$self{idstore}{$id}=$object; }

sub lookupID {
  my($self,$id)=@_;
  $$self{idstore}{$id}; }

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
  $self->findFile($name,[qw (ltxml sty tex cls)]); }

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
#    Warn("Package $name already loaded");
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
# No, can't close, cause perl may have opened a file for reading!?!?!
# So, how to close the right one?
#    $GULLET->closeMouth;
    Fatal("Package $name had an error:\n  $@") if $@;
  }
  # Hmm, very slightly different treatment needed for .sty and .tex ?
  elsif($file){
    my $isstyle = ($file =~ /\.sty$/);
    NoteProgress("\n(Loading Style $file");
    my $comments = $$self{includeComments} && !$isstyle;
    my $atcc = $STATE->lookup('catcode','@');
    $atcc = CC_OTHER unless defined $atcc;
    $STATE->assign('catcode','@'=>CC_LETTER,'local') if $isstyle;
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

=item C<< $list = $STOMACH->digestNextChunk($autoflush,$nofilter); >>

Return the digested L<LaTeXML::List> after reading and digesting a 
the next `chunk' (essentially an environment body or math mode list)
from the current Gullet.  The chunk extends until the current
level of boxing or environment is closed.

If C<$autoflush> is true, then if the current input source is
exhausted, it will be flushed and processing will continue.
If C<$nofilter> is true, filters will not be applied to the result.

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

=item C<< $boole = $STOMACH->inPreamble; >>

Returns whether or not we are in the preamble of the document, in 
the LaTeX sense; spaces and such are ignored in the preamble.

=item C<< $STOMACH->setInPreamble($value); >>

Specifies whether or not we are in the preamble of the document, in 
the LaTeX sense.

=back

=head2 Methods dealing with assignment

Most assignment operations accept a C<$scope> argument
that determines how the assignment is made:

   global   : global assignment.
   local    : local assignment, within the current grouping.
   undef    : (or if omitted) global if \global preceded, else local
   <name>   : stores the assignment in a `scope' which
               can be loaded later.

If no scoping is specified, then it will be global if a preceding
\global has set the global flag, else local.


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
