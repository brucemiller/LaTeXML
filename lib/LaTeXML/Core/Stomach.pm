# /=====================================================================\ #
# |  LaTeXML::Core::Stomach                                                   | #
# | Analog of TeX's Stomach: digests tokens, stores state               | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Core::Stomach;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Core::Token;
use LaTeXML::Core::Tokens;
use LaTeXML::Core::Gullet;
use LaTeXML::Core::Box;
use LaTeXML::Core::Comment;
use LaTeXML::Core::List;
use LaTeXML::Core::Mouth;
use LaTeXML::Common::Font;
# Silly place to import these....?
use LaTeXML::Common::Color;
use LaTeXML::Core::Definition;
use base qw(LaTeXML::Common::Object);

#**********************************************************************
sub new {
  my ($class, %options) = @_;
  return bless { gullet => LaTeXML::Core::Gullet->new(),
    boxing => [], token_stack => [] }, $class; }

#**********************************************************************
# Initialize various parameters, preload, etc.
sub initialize {
  my ($self) = @_;
  $$self{boxing}      = [];
  $$self{token_stack} = [];
  $STATE->assignValue(MODE              => 'text',           'global');
  $STATE->assignValue(IN_MATH           => 0,                'global');
  $STATE->assignValue(PRESERVE_NEWLINES => 1,                'global');
  $STATE->assignValue(afterGroup        => [],               'global');
  $STATE->assignValue(afterAssignment   => undef,            'global');
  $STATE->assignValue(groupInitiator    => 'Initialization', 'global');
  # Setup default fonts.
  $STATE->assignValue(font     => LaTeXML::Common::Font->textDefault(), 'global');
  $STATE->assignValue(mathfont => LaTeXML::Common::Font->mathDefault(), 'global');
  return; }

#**********************************************************************
sub getGullet {
  my ($self) = @_;
  return $$self{gullet}; }

sub getLocator {
  my ($self) = @_;
  return $$self{gullet}->getLocator; }

sub getBoxingLevel {
  my ($self) = @_;
  return scalar(@{ $$self{boxing} }); }

# ScriptLevel is similar to boxing level, but relative to current Math mode's level
# This is used for the scriptpos attribute to recognize overlapping sccripts.
# Making it relative to the math's level avoids unnecessary changes
sub getScriptLevel {
  my ($self) = @_;
  my $boxlevel = scalar(@{ $$self{boxing} });
  if (my $prevlevel = $STATE->lookupValue('script_base_level')) {
    return $boxlevel - $prevlevel + 1; }
  else {
    return $boxlevel; } }

#**********************************************************************
# Digestion
#**********************************************************************
# NOTE: Worry about whether the $autoflush thing is right?
# It puts a lot of cruft in Gullet; Should we just create a new Gullet?

sub digestNextBody {
  my ($self, $terminal) = @_;
  no warnings 'recursion';
  my $startloc  = $self->getLocator;
  my $initdepth = scalar(@{ $$self{boxing} });
  my $token;
  local @LaTeXML::LIST = ();
  while (defined($token = $$self{gullet}->readXToken(1, 1))) {    # Done if we run out of tokens
    push(@LaTeXML::LIST, $self->invokeToken($token));
    last if $terminal and Equals($token, $terminal);
    last if $initdepth > scalar(@{ $$self{boxing} }); }           # if we've closed the initial mode.
  Warn('expected', $terminal, $self, "body should have ended with '" . ToString($terminal) . "'",
    "current body started at " . ToString($startloc))
    if $terminal && !Equals($token, $terminal);
  push(@LaTeXML::LIST, Box()) unless $token;                      # Dummy `trailer' if none explicit.
  return @LaTeXML::LIST; }

# Digest a list of tokens independent from any current Gullet.
# Typically used to digest arguments to primitives or constructors.
# Returns a List containing the digested material.
sub digest {
  my ($self, $tokens) = @_;
  no warnings 'recursion';
  return unless defined $tokens;
  return
    $$self{gullet}->readingFromMouth(LaTeXML::Core::Mouth->new(), sub {
      my ($gullet) = @_;
      $gullet->unread($tokens);
      $STATE->clearPrefixes;    # prefixes shouldn't apply here.
      my $ismath    = $STATE->lookupValue('IN_MATH');
      my $initdepth = scalar(@{ $$self{boxing} });
      my $depth     = $initdepth;
      local @LaTeXML::LIST = ();
      while (defined(my $token = $$self{gullet}->readXToken(1, 1))) {    # Done if we run out of tokens
        push(@LaTeXML::LIST, $self->invokeToken($token));
        last if $initdepth > scalar(@{ $$self{boxing} }); }              # if we've closed the initial mode.
      Fatal('internal', '<EOF>', $self,
        "We've fallen off the end, somehow!?!?!",
        "Last token " . ToString($LaTeXML::CURRENT_TOKEN)
          . " (Boxing depth was $initdepth, now $depth: Boxing generated by "
          . join(', ', map { ToString($_) } @{ $$self{boxing} }))
        if $initdepth < $depth;

      List(@LaTeXML::LIST, mode => ($ismath ? 'math' : 'text'));
    }); }

# Invoke a token;
# If it is a primitive or constructor, the definition will be invoked,
# possibly arguments will be parsed from the Gullet.
# Otherwise, the token is simply digested: turned into an appropriate box.
# Returns a list of boxes/whatsits.
my $MAXSTACK = 200;    # [CONSTANT]

# Overly complex, but want to avoid recursion/stack
my @absorbable_cc = (    # [CONSTANT]
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0);

sub invokeToken {
  my ($self, $token) = @_;
  no warnings 'recursion';
INVOKE:
  push(@{ $$self{token_stack} }, $token);
  if (scalar(@{ $$self{token_stack} }) > $MAXSTACK) {
    Fatal('internal', '<recursion>', $self,
      "Excessive recursion(?): ",
      "Tokens on stack: " . join(', ', map { ToString($_) } @{ $$self{token_stack} })); }
  local $LaTeXML::CURRENT_TOKEN = $token;
  my @result  = ();
  my $meaning = $STATE->lookupDigestableDefinition($token);

  if ($meaning->isaToken) {    # Common case
    my $cc = $meaning->getCatcode;
    if ($cc == CC_CS) {
      @result = $self->invokeToken_undefined($token); }
    elsif ($absorbable_cc[$cc]) {
      @result = $self->invokeToken_simple($token, $meaning); }
    else {
      Error('misdefined', $token, $self,
        "The token " . Stringify($token) . " should never reach Stomach!");
      @result = $self->invokeToken_simple($token, $meaning); } }
  # A math-active character will (typically) be a macro,
  # but it isn't expanded in the gullet, but later when digesting, in math mode (? I think)
  elsif ($meaning->isExpandable) {
    my $gullet = $$self{gullet};
    $gullet->unread(@{ $meaning->invoke($gullet) || [] });
    $token = $gullet->readXToken();    # replace the token by it's expansion!!!
    pop(@{ $$self{token_stack} });
    goto INVOKE; }
  elsif ($meaning->isaDefinition) {    # Otherwise, a normal primitive or constructor
    @result = $meaning->invoke($self);
    $STATE->clearPrefixes unless $meaning->isPrefix; }    # Clear prefixes unless we just set one.
  else {
    Fatal('misdefined', $meaning, $self,
      "The object " . Stringify($meaning) . " should never reach Stomach!"); }
  if ((scalar(@result) == 1) && (!defined $result[0])) {
    @result = (); }                                       # Just paper over the obvious thing.
  Fatal('misdefined', $token, $self,
    "Execution yielded non boxes",
    "Returned " . join(',', map { "'" . Stringify($_) . "'" }
        grep { (!ref $_) || (!$_->isaBox) } @result))
    if grep { (!ref $_) || (!$_->isaBox) } @result;

  pop(@{ $$self{token_stack} });
  return @result; }

sub makeError {
  my ($document, $type, $content) = @_;
  my $savenode = undef;
  $savenode = $document->floatToElement('ltx:ERROR')
    unless $document->isOpenable('ltx:ERROR');
  $document->openElement('ltx:ERROR', class => ToString($type));
  $document->openText_internal(ToString($content));
  $document->closeElement('ltx:ERROR');
  $document->setNode($savenode) if $savenode;
  return; }

sub invokeToken_undefined {
  my ($self, $token) = @_;
  my $cs = $token->getCSName;
  $STATE->noteStatus(undefined => $cs);
  # To minimize chatter, go ahead and define it...
  if ($cs =~ /^\\if(.*)$/) {    # Apparently an \ifsomething ???
    my $name = $1;
    Error('undefined', $token, $self, "The token " . Stringify($token) . " is not defined.",
      "Defining it now as with \\newif");
    $STATE->installDefinition(LaTeXML::Core::Definition::Expandable->new(
        T_CS('\\' . $name . 'true'), undef, '\let' . $cs . '\iftrue'));
    $STATE->installDefinition(LaTeXML::Core::Definition::Expandable->new(
        T_CS('\\' . $name . 'false'), undef, '\let' . $cs . '\iffalse'));
    LaTeXML::Package::Let($token, T_CS('\iffalse'));
    $self->getGullet->unread($token);    # Retry
    return; }
  else {
    Error('undefined', $token, $self, "The token " . Stringify($token) . " is not defined.",
      "Defining it now as <ltx:ERROR/>");
    $STATE->installDefinition(LaTeXML::Core::Definition::Constructor->new($token, undef,
        sub { makeError($_[0], 'undefined', $cs); }),
      'global');
    # and then invoke it.
    return $self->invokeToken($token); } }

sub invokeToken_simple {
  my ($self, $token, $meaning) = @_;
  my $cc   = $meaning->getCatcode;
  my $font = $STATE->lookupValue('font');
  $STATE->clearPrefixes;    # prefixes shouldn't apply here.
  if ($cc == CC_SPACE) {
    if ($STATE->lookupValue('IN_MATH')) {    # (but in Preamble, OK ?)
      return (); }
    else {
      return Box($meaning->getString, $font, $self->getGullet->getLocator, $meaning); } }
  elsif ($cc == CC_COMMENT) {                # Note: Comments need char decoding as well!
    my $comment = LaTeXML::Package::FontDecodeString($meaning->getString, undef, 1);
    # However, spaces normally would have be digested away as positioning...
    my $badspace = pack('U', 0xA0) . "\x{0335}";    # This is at space's pos in OT1
    $comment =~ s/\Q$badspace\E/ /g;
    return LaTeXML::Core::Comment->new($comment); }
  else {
    return Box(LaTeXML::Package::FontDecodeString($meaning->getString, undef, 1),
      undef, undef, $meaning); } }

# Regurgitate: steal the previously digested boxes from the current level.
sub regurgitate {
  my ($self) = @_;
  my @stuff = @LaTeXML::LIST;
  @LaTeXML::LIST = ();
  return @stuff; }

#**********************************************************************
# Maintaining State.
#**********************************************************************
# State changes that the Stomach needs to moderate and know about (?)

#======================================================================
# Dealing with TeX's bindings & grouping.
# Note that lookups happen more often than bgroup/egroup (which open/close frames).

sub pushStackFrame {
  my ($self, $nobox) = @_;
  $STATE->pushFrame;
  $STATE->assignValue(beforeAfterGroup      => [],                      'local');  # ALWAYS bind this!
  $STATE->assignValue(afterGroup            => [],                      'local');  # ALWAYS bind this!
  $STATE->assignValue(afterAssignment       => undef,                   'local');  # ALWAYS bind this!
  $STATE->assignValue(groupNonBoxing        => $nobox,                  'local');  # ALWAYS bind this!
  $STATE->assignValue(groupInitiator        => $LaTeXML::CURRENT_TOKEN, 'local');
  $STATE->assignValue(groupInitiatorLocator => $self->getLocator,       'local');
  push(@{ $$self{boxing} }, $LaTeXML::CURRENT_TOKEN) unless $nobox;    # For begingroup/endgroup
  return; }

sub popStackFrame {
  my ($self, $nobox) = @_;
  if (my $beforeafter = $STATE->lookupValue('beforeAfterGroup')) {
    if (@$beforeafter) {
      my @result = map { $_->beDigested($self) } @$beforeafter;
      if (my ($x) = grep { !$_->isaBox } @result) {
        Fatal('misdefined', $x, $self, "Expected a Box|List|Whatsit, but got '" . Stringify($x) . "'"); }
      push(@LaTeXML::LIST, @result); } }
  my $after = $STATE->lookupValue('afterGroup');
  $STATE->popFrame;
  pop(@{ $$self{boxing} }) unless $nobox;    # For begingroup/endgroup
  $$self{gullet}->unread(@$after) if $after;
  return; }

sub currentFrameMessage {
  my ($self) = @_;
  return "current frame is "
    . ($STATE->isValueBound('MODE', 0)       # SET mode in CURRENT frame ?
    ? "mode-switch to " . $STATE->lookupValue('MODE')
    : ($STATE->lookupValue('groupNonBoxing')    # Current frame is a non-boxing group?
      ? "non-boxing" : "boxing") . " group")
    . " due to " . Stringify($STATE->lookupValue('groupInitiator'))
    . " " . ToString($STATE->lookupValue('groupInitiatorLocator')); }

#======================================================================
# Grouping pushes a new stack frame for binding definitions, etc.
#======================================================================
# Originally, we only treated math vs text "modes", which are correlated
# to grouping (somehow). But we'll gradually need to incorporate all
# the horizontal/vertical modes, which are NOT correlated to grouping,
# although they do operate on a stack.
# So, we should NOT generate errors when the grouping clashes with modes
# (until we can get it properly sorted).

# if $nobox is true, inhibit incrementing the boxingLevel
sub bgroup {
  my ($self) = @_;
  pushStackFrame($self, 0);
  return; }

sub egroup {
  my ($self) = @_;
  if (    ##$STATE->isValueBound('MODE', 0) ||    # Last stack frame was a mode switch!?!?!
    $STATE->lookupValue('groupNonBoxing')) {    # or group was opened with \begingroup
    Error('unexpected', $LaTeXML::CURRENT_TOKEN, $self, "Attempt to close boxing group",
      $self->currentFrameMessage); }
  else {                                        # Don't pop if there's an error; maybe we'll recover?
    popStackFrame($self, 0); }
  return; }

sub begingroup {
  my ($self) = @_;
  pushStackFrame($self, 1);
  return; }

sub endgroup {
  my ($self) = @_;
  if (    ##$STATE->isValueBound('MODE', 0) ||    # Last stack frame was a mode switch!?!?!
    !$STATE->lookupValue('groupNonBoxing')) {    # or group was opened with \bgroup
    Error('unexpected', $LaTeXML::CURRENT_TOKEN, $self, "Attempt to close non-boxing group",
      $self->currentFrameMessage); }
  else {                                         # Don't pop if there's an error; maybe we'll recover?
    popStackFrame($self, 1); }
  return; }

#======================================================================
# Mode (minimal so far; math vs text)
# Could (should?) be taken up by Stomach by building horizontal, vertical or math lists ?

# This sets the mode without doing any grouping (NOR does it stack the modes!!)
# Useful for environments, where the group has already been established.
# (presumably, in the long run, modes & groups should be much less coupled)
sub setMode {
  my ($self, $mode) = @_;
  my $prevmode = $STATE->lookupValue('MODE');
  my $ismath   = $mode =~ /math$/;
  $STATE->assignValue(MODE    => $mode,   'local');
  $STATE->assignValue(IN_MATH => $ismath, 'local');
  my $curfont = $STATE->lookupValue('font');
  if ($mode eq $prevmode) { }
  elsif ($ismath) {
    # When entering math mode, we set the font to the default math font,
    # and save the text font for any embedded text.
    $STATE->assignValue(savedfont => $curfont, 'local');
    $STATE->assignValue(script_base_level => scalar(@{ $$self{boxing} }));    # See getScriptLevel
    $STATE->assignValue(font => $STATE->lookupValue('mathfont')->merge(
        color     => $curfont->getColor, background => $curfont->getBackground,
        size      => $curfont->getSize,
        mathstyle => ($mode =~ /^display/ ? 'display' : 'text')), 'local'); }
  else {
    # When entering text mode, we should set the font to the text font in use before the math
    # but inherit color and size
    $STATE->assignValue(font => $STATE->lookupValue('savedfont')->merge(
        color => $curfont->getColor, background => $curfont->getBackground,
        size  => $curfont->getSize), 'local'); }
  return; }

sub beginMode {
  my ($self, $mode) = @_;
  $self->pushStackFrame;    # Effectively bgroup
  $self->setMode($mode);
  return; }

sub endMode {
  my ($self, $mode) = @_;
  if ((!$STATE->isValueBound('MODE', 0))    # Last stack frame was NOT a mode switch!?!?!
    || ($STATE->lookupValue('MODE') ne $mode)) {    # Or was a mode switch to a different mode
    Error('unexpected', $LaTeXML::CURRENT_TOKEN, $self, "Attempt to end mode $mode",
      $self->currentFrameMessage); }
  else {    # Don't pop if there's an error; maybe we'll recover?
    $self->popStackFrame; }    # Effectively egroup.
  return; }

#**********************************************************************
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Stomach> - digests tokens into boxes, lists, etc.

=head1 DESCRIPTION

C<LaTeXML::Core::Stomach> digests tokens read from a L<LaTeXML::Core::Gullet>
(they will have already been expanded).

It extends L<LaTeXML::Common::Object>.

There are basically four cases when digesting a L<LaTeXML::Core::Token>:

=over 4

=item A plain character

is simply converted to a L<LaTeXML::Core::Box>
recording the current L<LaTeXML::Common::Font>.

=item A primitive

If a control sequence represents L<LaTeXML::Core::Definition::Primitive>, the primitive is invoked, executing its
stored subroutine.  This is typically done for side effect (changing the state in the L<LaTeXML::Core::State>),
although they may also contribute digested material.
As with macros, any arguments to the primitive are read from the L<LaTeXML::Core::Gullet>.

=item Grouping (or environment bodies)

are collected into a L<LaTeXML::Core::List>.

=item Constructors

A special class of control sequence, called a L<LaTeXML::Core::Definition::Constructor> produces a 
L<LaTeXML::Core::Whatsit> which remembers the control sequence and arguments that
created it, and defines its own translation into C<XML> elements, attributes and data.
Arguments to a constructor are read from the gullet and also digested.

=back

=head2 Digestion

=over 4

=item C<< $list = $stomach->digestNextBody; >>

Return the digested L<LaTeXML::Core::List> after reading and digesting a `body'
from the its Gullet.  The body extends until the current
level of boxing or environment is closed.  

=item C<< $list = $stomach->digest($tokens); >>

Return the L<LaTeXML::Core::List> resuting from digesting the given tokens.
This is typically used to digest arguments to primitives or
constructors.

=item C<< @boxes = $stomach->invokeToken($token); >>

Invoke the given (expanded) token.  If it corresponds to a
Primitive or Constructor, the definition will be invoked,
reading any needed arguments fromt he current input source.
Otherwise, the token will be digested.
A List of Box's, Lists, Whatsit's is returned.

=item C<< @boxes = $stomach->regurgitate; >>

Removes and returns a list of the boxes already digested 
at the current level.  This peculiar beast is used
by things like \choose (which is a Primitive in TeX, but
a Constructor in LaTeXML).

=back

=head2 Grouping

=over 4

=item C<< $stomach->bgroup; >>

Begin a new level of binding by pushing a new stack frame,
and a new level of boxing the digested output.

=item C<< $stomach->egroup; >>

End a level of binding by popping the last stack frame,
undoing whatever bindings appeared there, and also
decrementing the level of boxing.

=item C<< $stomach->begingroup; >>

Begin a new level of binding by pushing a new stack frame.

=item C<< $stomach->endgroup; >>

End a level of binding by popping the last stack frame,
undoing whatever bindings appeared there.

=back

=head2 Modes

=over 4

=item C<< $stomach->beginMode($mode); >>

Begin processing in C<$mode>; one of 'text', 'display-math' or 'inline-math'.
This also begins a new level of grouping and switches to a font
appropriate for the mode.

=item C<< $stomach->endMode($mode); >>

End processing in C<$mode>; an error is signalled if C<$stomach> is not
currently in C<$mode>.  This also ends a level of grouping.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
