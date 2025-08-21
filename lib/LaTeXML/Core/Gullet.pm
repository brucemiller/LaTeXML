# /=====================================================================\ #
# |  LaTeXML::Core::Gullet                                              | #
# | Analog of TeX's Gullet; deals with expansion and arg parsing        | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Core::Gullet;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Core::Token;
use LaTeXML::Core::Tokens;
use LaTeXML::Core::Mouth;
use LaTeXML::Util::Pathname;
use LaTeXML::Common::Number;
use LaTeXML::Common::Float;
use LaTeXML::Common::Dimension;
use LaTeXML::Common::Glue;
use LaTeXML::Core::MuDimension;
use LaTeXML::Core::MuGlue;
use base qw(LaTeXML::Common::Object);
#**********************************************************************
sub new {
  my ($class, %options) = @_;
  return bless {
    mouth     => undef, mouthstack => [], pushback => [], autoclose => 1, pending_comments => [],
    verbosity => $options{verbosity} || 0,
    progress  => 0,
  }, $class; }

our $TOKEN_PROGRESS_QUANTUM = 30000;

#**********************************************************************
# Start reading tokens from a new Mouth.
# This pushes the mouth as the current source that $gullet->readToken (etc) will read from.
# Once this Mouth has been exhausted, readToken, etc, will return undef,
# until you call $gullet->closeMouth to clear the source.
# Exception: if $toplevel=1, readXToken will step to next source
# Note that a Tokens can act as a Mouth.
sub openMouth {
  my ($self, $mouth, $noautoclose) = @_;
  return unless $mouth;
  unshift(@{ $$self{mouthstack} }, [$$self{mouth}, $$self{pushback}, $$self{autoclose}]) if $$self{mouth};
  $$self{mouth}     = $mouth;
  $$self{pushback}  = [];
  $$self{autoclose} = !$noautoclose;
  return; }

sub closeMouth {
  my ($self, $forced) = @_;
  if (!$forced && (@{ $$self{pushback} } || $$self{mouth}->hasMoreInput)) {
    my $next = Stringify(readToken($self));
    Error('unexpected', $next, $self, "Closing mouth with input remaining '$next'"); }
  $$self{mouth}->finish;
  if (@{ $$self{mouthstack} }) {
    ($$self{mouth}, $$self{pushback}, $$self{autoclose}) = @{ shift(@{ $$self{mouthstack} }) }; }
  else {
    $$self{pushback}  = [];
    $$self{mouth}     = LaTeXML::Core::Mouth->new();
    $$self{autoclose} = 1; }
  return; }

sub getMouth {
  my ($self) = @_;
  return $$self{mouth}; }

sub mouthIsOpen {
  my ($self, $mouth) = @_;
  return ($$self{mouth} eq $mouth)
    || grep { $_ && ($$_[0] eq $mouth) } @{ $$self{mouthstack} }; }

# This flushes a mouth so that it will be automatically closed, next time it's read
# Corresponds to TeX's \endinput
sub flushMouth {
  my ($self) = @_;
  my $mouth = $$self{mouth};
  # Put the remainder of Mouth's current line at the END of the pushback stack, to be read
  while (!$mouth->isEOL) {
    push(@{ $$self{pushback} }, $mouth->readToken); }
  $mouth->finish;    # then finish the mouth (it'll get closed on next read)
  return; }

# Obscure, but the only way I can think of to End!! (see \bye or \end{document})
# Flush all sources (close all pending mouth's)
sub flush {
  my ($self) = @_;
  $$self{mouth}->finish;
  while (@{ $$self{mouthstack} }) {
    my $entry = shift @{ $$self{mouthstack} };
    $$entry[0]->finish; }
  $$self{pushback}   = [];
  $$self{mouth}      = LaTeXML::Core::Mouth->new();
  $$self{mouthstack} = [];
  return; }

# Do something, while reading stuff from a specific Mouth.
# This reads ONLY from that mouth (or any mouth openned by code in that source),
# and the mouth should end up empty afterwards, and only be closed here.
sub readingFromMouth {
  my ($self, $mouth, $closure) = @_;
  openMouth($self, $mouth, 1);    # only allow mouth to be explicitly closed here.
  my ($result, @result);
  if (wantarray) {
    @result = &$closure($self); }
  else {
    $result = &$closure($self); }
  # $mouth must still be open, with (at worst) empty autoclosable mouths in front of it
  while (1) {
    if ($$self{mouth} eq $mouth) {
      closeMouth($self, 1); last; }
    elsif (!@{ $$self{mouthstack} }) {
      Error('unexpected', '<closed>', $self, "Mouth is unexpectedly already closed",
        "Reading from " . Stringify($mouth) . ", but it has already been closed."); last; }
    elsif (!$$self{autoclose} || @{ $$self{pushback} } || $$self{mouth}->hasMoreInput) {
      my $next = Stringify(readToken($self));
      Error('unexpected', $next, $self, "Unexpected input remaining: '$next'",
        "Finished reading from " . Stringify($mouth) . ", but it still has input.");
      $$self{mouth}->finish;
      closeMouth($self, 1); }    # ?? if we continue?
    else {
      closeMouth($self); } }
  return (wantarray ? @result : $result); }

# User feedback for where something (error?) occurred.
sub getLocator {
  my ($self) = @_;
  my $mouth  = $$self{mouth};
  my $i      = 0;
  while ((defined $mouth) && (!defined $$mouth{source})
    && ($i < scalar(@{ $$self{mouthstack} }))) {
    $mouth = $$self{mouthstack}[$i++][0]; }
  my $loc = (defined $mouth ? $mouth->getLocator : undef);
  return $loc if defined $loc;
  foreach my $frame (@{ $$self{mouthstack} }) {
    my $ml = $$frame[0]->getLocator;
    return $ml if defined $ml; }
  return; }

sub getSource {
  my ($self) = @_;
  my $source = defined $$self{mouth} && $$self{mouth}->getSource;
  if (!defined($source)) {
    foreach my $frame (@{ $$self{mouthstack} }) {
      $source = $$frame[0]->getSource;
      last if defined($source); } }
  return $source; }

sub getSourceMouth {
  my ($self) = @_;
  my $mouth  = $$self{mouth};
  my $source = defined $mouth && $mouth->getSource;
  if (!defined($source)) {
    foreach my $frame (@{ $$self{mouthstack} }) {
      $mouth  = $$frame[0];
      $source = $mouth->getSource;
      last if defined($source); } }
  return $mouth; }

# Handy message generator when we didn't get something expected.
sub showUnexpected {
  my ($self) = @_;
  my $message = "Input is empty";
  if (my $token = peekToken($self)) {
    my @pb = @{ $$self{pushback} }[1..-1];
    $message = "Next token is " . Stringify($token)
      . " ( == " . Stringify($STATE->lookupMeaning($token)) . ")"
        . (@pb ? " more: " . ToString(TokensI(@pb)) : ''); }
  return $message; }

sub show_pushback {
  my ($pb) = @_;
  my @pb = @$pb;
  @pb = (@pb[0 .. 50], T_OTHER('...')) if scalar(@pb) > 55;
  return (@pb ? "\n  To be read again " . ToString(Tokens(@pb)) : ''); }

#**********************************************************************
# Low-level readers: read token, read expanded token
#**********************************************************************
# Get the next pending comment token (if any)
sub getPendingComment {
  my ($self) = @_;
  return shift @{ $$self{pending_comments} } }

# Note that every char (token) comes through here (maybe even twice, through args parsing),
# So, be Fast & Clean!  This method only reads from the current input stream (Mouth).
our @CATCODE_HOLD = (
  0, 0, 0, 0,
  0, 0, 0, 0,
  0, 0, 0, 0,
  0, 0, 1, 0,
  0, 1, 0, 0);

sub handleMarker {
  my ($self, $markertoken) = @_;
  my $arg = $$markertoken[0];
  if (ref $arg) {
    LaTeXML::Core::Definition::stopProfiling($markertoken, 'expand'); }
  elsif ($arg eq 'before-column') {    # Were in before-column template
    my $alignment = $STATE->lookupValue('Alignment');
    Debug("Halign $alignment: alignment state => 0") if $LaTeXML::DEBUG{halign};
    $LaTeXML::ALIGN_STATE = 0; }       # switch to column proper!
  elsif ($arg eq 'after-column') {     # Were in before-column template
    my $alignment = $STATE->lookupValue('Alignment');
    Debug("Halign $alignment: alignment state: after column") if $LaTeXML::DEBUG{halign};
  }
  return; }

sub handleTemplate {
  my ($self, $alignment, $token, $type, $hidden) = @_;
  Debug("Halign $alignment: ALIGNMENT Column ended at " . Stringify($token)
      . " type $type [" . Stringify($STATE->lookupMeaning($token)) . "]"
      . "@ " . ToString(getLocator($self)))
    if $LaTeXML::DEBUG{halign};
  #  Append expansion to end!?!?!?!
  local $LaTeXML::CURRENT_TOKEN = $token;
  my $post = $alignment->getColumnAfter;
  $LaTeXML::ALIGN_STATE = 1000000;
  ### NOTE: Truly fishy smuggling w/ \lx@hidden@cr
  my $arg;
  if (($type eq 'cr') && $hidden) {    # \lx@hidden@cr gets an argument as payload!!!!!
    $arg = readArg($self); }
  Debug("Halign $alignment: column after " . ToString($post)) if $LaTeXML::DEBUG{halign};
  if ((($type eq 'cr') || ($type eq 'crcr'))
    && $$alignment{in_row} && !$alignment->currentRow->{pseudorow}) {
    unshift(@{ $$self{pushback} }, T_CS('\lx@alignment@row@after')); }
  if ($arg) {
    unshift(@{ $$self{pushback} }, T_BEGIN, $arg->unlist, T_END); }
  unshift(@{ $$self{pushback} }, $token);
  unshift(@{ $$self{pushback} }, $post->unlist);
  return; }

# If it is a column ending token, Returns the token, a keyword and whether it is "hidden"
our @column_ends = (    # besides T_ALIGN
  [T_CS('\cr'),              'cr',     0],
  [T_CS('\crcr'),            'crcr',   0],
  [T_CS('\lx@hidden@cr'),    'cr',     1],
  [T_CS('\lx@hidden@crcr'),  'crcr',   1],
  [T_CS('\lx@hidden@align'), 'insert', 1],
  [T_CS('\span'),            'span',   0]);

sub isColumnEnd {
  my ($self, $token) = @_;
  my $cc = $$token[1];
  return ($token, 'align', 0) if $cc == CC_ALIGN;
  return unless ($cc == CC_CS) || ($cc == CC_ACTIVE);
  # Embedded version of Equals, knowing both are tokens
  my $defn = $STATE->lookupMeaning($token) || $token;
  return ($token, 'align', 0) if (ref $defn eq 'LaTeXML::Core::Token') && ($$defn[1] == CC_ALIGN);
  foreach my $end (@column_ends) {
    my $e = $$end[0];
    # Would be nice to cache the defns, but don't know when they're present & constant!
    return @$end if $defn->equals($STATE->lookupMeaning($e) || $e); }
  return; }

sub readToken {
  my ($self) = @_;
  #  my $token = shift(@{$$self{pushback}});
  my ($token, $cc, $atoken, $atype, $ahidden);
  while (1) {
    while (($token = shift(@{ $$self{pushback} }))
      && $CATCODE_HOLD[$cc = $$token[1]]) {
      if ($cc == CC_COMMENT) {
        push(@{ $$self{pending_comments} }, $token); }
      elsif ($cc == CC_MARKER) {
        handleMarker($self, $token); } }
    # Not in pushback, use the current mouth
    if (!defined $token) {
      while (($token = $$self{mouth}->readToken()) && $CATCODE_HOLD[$cc = $$token[1]]) {
        if ($cc == CC_COMMENT) {
          push(@{ $$self{pending_comments} }, $token); }    # What to do with comments???
        elsif ($cc == CC_MARKER) {
          handleMarker($self, $token); } } }
    ProgressStep() if ($$self{progress}++ % $TOKEN_PROGRESS_QUANTUM) == 0;
    # some infinite loops are hard to predict and may be
    # better guarded against via a global token limit.
    if ($LaTeXML::TOKEN_LIMIT and $$self{progress} > $LaTeXML::TOKEN_LIMIT) {
      Fatal('timeout', 'token_limit', $self,
        "Token limit of $LaTeXML::TOKEN_LIMIT exceeded, infinite loop?"); }
    if ($LaTeXML::PUSHBACK_LIMIT and scalar(@{ $$self{pushback} }) > $LaTeXML::PUSHBACK_LIMIT) {
      Fatal('timeout', 'pushback_limit', $self,
        "Pushback limit of $LaTeXML::PUSHBACK_LIMIT exceeded, infinite loop?"); }
    # Wow!!!!! See TeX the Program \S 309
    if ((defined $token)
      && !$LaTeXML::ALIGN_STATE    # SHOULD count nesting of { }!!! when SCANNED (not digested)
      && $LaTeXML::READING_ALIGNMENT
      && (($atoken, $atype, $ahidden) = isColumnEnd($self, $token))) {
      handleTemplate($self, $LaTeXML::READING_ALIGNMENT, $token, $atype, $ahidden); }
    elsif ((defined $token) && ($$token[1] == CC_CS) && ($$token[0] eq '\dont_expand')) {
      my $unexpanded = readToken($self);    # Replace next token with a special \relax
      return T_CS('\special_relax'); }
    else {
      last; } }
  if ($token) {
    $cc = $$token[1];
    if    ($cc == CC_BEGIN) { $LaTeXML::ALIGN_STATE++; }
    elsif ($cc == CC_END)   { $LaTeXML::ALIGN_STATE--; }
  }
  return $token; }

# This is useful when you want to see what the next available token is,
# BUT you don't want it to trigger any Alignment behaviours;
# ESPECIALLY if it sees a T_BEGIN within an alignment.
# This might be needed in more places?
sub peekToken {
  my ($self) = @_;
  local $LaTeXML::ALIGN_STATE = 1000000; # Inhibit readToken from processing {}!!!
  if (my $token = readToken($self)) {
    unshift(@{ $$self{pushback} }, $token);
    return $token; }
  return; }

# Unread tokens are assumed to be not-yet expanded.
sub unread {
  my ($self, @tokens) = @_;
  my $level = 0;
  my $pb    = $$self{pushback};
  while (@tokens) {
    my $token = pop(@tokens);
    my $r     = ref $token;
    if    (!defined $token) { }
    elsif ($r eq 'LaTeXML::Core::Tokens') {
      push(@tokens, @$token); }
    elsif ($r eq 'LaTeXML::Core::Token') {
      my $cc = $$token[1];
      if    ($cc == CC_BEGIN) { $level--; }    # Retract scanned braces
      elsif ($cc == CC_END)   { $level++; }
      unshift(@$pb, $token); }
    else {
      Error('misdefined', $r, undef, "Expected a Token, got " . Stringify($_));
      unshift(@$pb, T_OTHER($token)); } }
  $LaTeXML::ALIGN_STATE += $level;
  return; }

# Read the next non-expandable token (expanding tokens until there's a non-expandable one).
# Note that most tokens pass through here, so be Fast & Clean! readToken is folded in.
# `Toplevel' processing, (if $toplevel is true), used at the toplevel processing by Stomach,
#  will step to the next input stream (Mouth) if one is available,
# $toplevel when true:
#  * If a mouth is exhausted, move on to the containing mouth to continue reading
# $fully_expand when true, OR when undef but $toplevel is true
#  * expand even protected defns, essentially this means expand "for execution"
# Note that, unlike readBalanced, this does NOT defer expansion of \the & friends.
# Also, \noexpand'd tokens effectively act ilke \relax
# For arguments to \if,\ifx, etc use $for_conditional true,
# which handles \noexpand and CS which have been \let to tokens specially.
sub readXToken {
  my ($self, $toplevel, $for_conditional, $fully_expand) = @_;
  $toplevel = 1 unless defined $toplevel;
  my $autoclose = $toplevel;    # Potentially, these should have distinct controls?
  $fully_expand = $toplevel unless defined $fully_expand;
  my ($token, $cc, $defn, $atoken, $atype, $ahidden);
  while (1) {
    while (($token = shift(@{ $$self{pushback} })) && $CATCODE_HOLD[$cc = $$token[1]]) {
      if ($cc == CC_COMMENT) {
        push(@{ $$self{pending_comments} }, $token); }
      elsif ($cc == CC_MARKER) {
        handleMarker($self, $token); } }
    if (!defined $token) {    # Else read from current mouth
      while (($token = $$self{mouth}->readToken()) && $CATCODE_HOLD[$cc = $$token[1]]) {
        if ($cc == CC_COMMENT) {
          push(@{ $$self{pending_comments} }, $token); }
        elsif ($cc == CC_MARKER) {
          handleMarker($self, $token); } } }
    ProgressStep() if ($$self{progress}++ % $TOKEN_PROGRESS_QUANTUM) == 0;
    if (!defined $token) {
      return unless $autoclose && $$self{autoclose} && @{ $$self{mouthstack} };
      closeMouth($self); }    # Next input stream.
    elsif (($cc == CC_CS) && ($$token[0] eq '\dont_expand')) {
      my $unexpanded = readToken($self);
      return ($for_conditional && ($$unexpanded[1] == CC_ACTIVE) ? $unexpanded : T_CS('\special_relax')); }
    ## Wow!!!!! See TeX the Program \S 309
    elsif (!$LaTeXML::ALIGN_STATE    # SHOULD count nesting of { }!!! when SCANNED (not digested)
      && $LaTeXML::READING_ALIGNMENT
      && (($atoken, $atype, $ahidden) = isColumnEnd($self, $token))) {
      handleTemplate($self, $LaTeXML::READING_ALIGNMENT, $token, $atype, $ahidden); }
    ## Note: use general-purpose lookup, since we may reexamine $defn below
    elsif ($LaTeXML::Core::State::CATCODE_ACTIVE_OR_CS[$cc]
      && defined($defn = $STATE->lookupMeaning($token))) {
      if ((ref $defn) eq 'LaTeXML::Core::Token') {    # \let to a token? Return it!
        return ($for_conditional ? $defn : $token); }
      elsif (!$defn->isExpandable                     # Not expandable or is protected
        || ($$defn{isProtected} && !$fully_expand)) {
        return $token; }
      else {
        local $LaTeXML::CURRENT_TOKEN = $token;
        no warnings 'recursion';
        my $expansion = $defn->invoke($self);
        # add the newly expanded tokens back into the gullet stream, in the ordinary case.
        unread($self, $expansion) if $expansion; } }
    elsif ($$token[1] == CC_CS && !(defined $defn)) {
      $STATE->generateErrorStub($self, $token);       # cs SHOULD have defn by now; report early!
      return $token; }
    else {
      if    ($cc == CC_BEGIN) { $LaTeXML::ALIGN_STATE++; }
      elsif ($cc == CC_END)   { $LaTeXML::ALIGN_STATE--; }
      return $token; }                                # just return it
  }
  return; }                                           # never get here.

# readBalanced approximates TeX's scan_toks (but doesn't parse \def parameter lists)
# and only optionally requires the openning "{".
# It may return comments in the token lists.
# If $expanded is true, it expands while reading, but deferring \the and related
# & \protected, unless $expanded is > 1.
# The $macrodef flag affects whether # parameters are "packed" for macro bodies.
# If $require_open is true, the opening T_BEGIN has not yet been read, and is required.
our $DEFERRED_COMMANDS = {
  '\the'        => 1,
  '\showthe'    => 1,
  '\unexpanded' => 1,
  '\detokenize' => 1
};

sub readBalanced {
  my ($self, $expanded, $macrodef, $require_open) = @_;
  $LaTeXML::ALIGN_STATE-- unless $require_open;    # assume matching } [BEFORE masking ALIGN_STATE]
  local $LaTeXML::ALIGN_STATE = 1000000;
  my $fully_expand = (defined $expanded)     && ($expanded > 1);
  my $startloc     = ($$self{verbosity} > 0) && getLocator($self);
  # Does we need to expand to get the { ???
  if ($require_open) {
    my $token = ($expanded ? readXToken($self, 0) : readToken($self));
    if ((!$token) || ($$token[1] != CC_BEGIN && !Equals($STATE->lookupMeaning($token), T_BEGIN))) {
      Error('expected', '{', $self, "Expected opening '{'");
      return TokensI(); } }
  my @tokens = ();
  my $level  = 1;
  my ($token, $cc, $defn, $atoken, $atype, $ahidden);
  # Inlined readToken (we'll keep comments in the result)
  while (1) {
    if (@{ $$self{pending_comments} }) {
      push(@tokens, @{ $$self{pending_comments} });
      $$self{pending_comments} = []; }
    # Examine pushback first
    while (($token = shift(@{ $$self{pushback} })) && $CATCODE_HOLD[$cc = $$token[1]]) {
      if    ($cc == CC_COMMENT) { push(@tokens, $token); }
      elsif ($cc == CC_MARKER)  { handleMarker($self, $token); } }
    if (!defined $token) {    # Else read from current mouth
      while (($token = $$self{mouth}->readToken()) && $CATCODE_HOLD[$cc = $$token[1]]) {
        if    ($cc == CC_COMMENT) { push(@tokens, $token); }
        elsif ($cc == CC_MARKER)  { handleMarker($self, $token); } } }
    ProgressStep() if ($$self{progress}++ % $TOKEN_PROGRESS_QUANTUM) == 0;
    if (!defined $token) {
      # What's the right error handling now?
      last; }
    elsif (($cc == CC_CS) && ($$token[0] eq '\dont_expand')) {
      push(@tokens, readToken($self)); }    # Pass on NEXT token, unchanged.
    elsif ($cc == CC_END) {
      $LaTeXML::ALIGN_STATE--;
      $level--;
      if (!$level) {
        last; }
      push(@tokens, $token); }
    elsif ($cc == CC_BEGIN) {
      $LaTeXML::ALIGN_STATE++;
      $level++;
      push(@tokens, $token); }
    ## Wow!!!!! See TeX the Program \S 309
    # Not sure if this code still applies within scan_toks???
    elsif (!$LaTeXML::ALIGN_STATE    # SHOULD count nesting of { }!!! when SCANNED (not digested)
      && $LaTeXML::READING_ALIGNMENT
      && (($atoken, $atype, $ahidden) = isColumnEnd($self, $token))) {
      handleTemplate($self, $LaTeXML::READING_ALIGNMENT, $token, $atype, $ahidden); }
    ## Note: use general-purpose lookup, since we may reexamine $defn below
    elsif ($expanded &&
      $LaTeXML::Core::State::CATCODE_ACTIVE_OR_CS[$cc]
      && defined($defn = $STATE->lookupMeaning($token))
      && ((ref $defn) ne 'LaTeXML::Core::Token')    # an actual definition
      && $defn->isExpandable
      && (!$$defn{isProtected} || $fully_expand)) { # is this the right logic here? don't expand unless di
      local $LaTeXML::CURRENT_TOKEN = $token;
      my $r;
      no warnings 'recursion';
      my $expansion = $defn->invoke($self);
      next unless $expansion;
      # If a special \the type command, push the expansion directly into the result
      # Well, almost directly: handle any MARKER tokens now, and possibly un-pack T_PARAM
      if (!$fully_expand && $$DEFERRED_COMMANDS{ $$defn{cs}[0] }) {
        foreach my $t (@$expansion) {
          my $cc = $$t[1];
          if    ($cc == CC_MARKER) { handleMarker($self, $t); }
          elsif (($cc == CC_PARAM) && $macrodef) {
            push(@tokens, $t, $t); }    # "unpack" to cover the packParameters at end!
          else {
            push(@tokens, $t); } }
      }
      else {    # otherwise, prepend to pushback to be expanded further.
        unread($self, $expansion) if $expansion; } }
    else {
      if ($expanded && ($$token[1] == CC_CS) && !(defined $defn)) {
        $STATE->generateErrorStub($self, $token); }    # cs SHOULD have defn by now; report early!
      push(@tokens, $token); }                         # just return it
  }
  if ($level > 0) {
 # TODO: The current implementation has a limitation where if the balancing end is in a different mouth,
 #       it will not be recognized.
    my $loc_message = $startloc ? ("Started at " . ToString($startloc)) : ("Ended at " . ToString(getLocator($self)));
    Error('expected', "}", $self, "Gullet->readBalanced ran out of input in an unbalanced state.",
      $loc_message); }
  return ($macrodef ? TokensI(@tokens)->packParameters : TokensI(@tokens)); }

#======================================================================

# Read the next raw line (string);
# primarily to read from the Mouth, but keep any unread input!
sub readRawLine {
  my ($self) = @_;
  # If we've got unread tokens, they presumably should come before the Mouth's raw data
  # but we'll convert them back to string.
  my @tokens  = @{ $$self{pushback} };
  my @markers = grep { $_->getCatcode == CC_MARKER } @tokens;
  if (@markers) {    # Whoops, profiling markers!
    @tokens = grep { $_->getCatcode != CC_MARKER } @tokens;    # Remove
    map { LaTeXML::Core::Definition::stopProfiling($_, 'expand') } @markers; }
  $$self{pushback} = [];
  # If we still have peeked tokens, we ONLY want to combine it with the remainder
  # of the current line from the Mouth (NOT reading a new line)
  if (@tokens) {
    return ToString(TokensI(@tokens)) . $$self{mouth}->readRawLine(1); }
  # Otherwise, read the next line from the Mouth.
  else {
    return $$self{mouth}->readRawLine; } }

#**********************************************************************
# Mid-level readers: checking and matching tokens, strings etc.
#**********************************************************************
# General note: TeX uses different tests for Space tokens in different places
# (possibilities: catcode equality, ->equals, Equals and XEquals)

# The following higher-level parsing methods are built upon readToken & unread.
sub readNonSpace {
  my ($self) = @_;
  my $token;
  do { $token = readToken($self);
  } while (defined $token && $$token[1] == CC_SPACE);    # Inline ->getCatcode!
  return $token; }

sub readXNonSpace {
  my ($self) = @_;
  my $token;
  do { $token = readXToken($self, 0);
  } while (defined $token && $$token[1] == CC_SPACE);    # Inline ->getCatcode!
  return $token; }

sub skipSpaces {
  my ($self) = @_;
  my $tok = readNonSpace($self);
  unread($self, $tok) if defined $tok;
  return; }

# Skip one space
# if $expanded is true, it acts like <one optional space>, expanding the next token.
sub skip1Space {
  my ($self, $expanded) = @_;
  my $token = ($expanded ? readXToken($self) : readToken($self));
  unread($self, $token) if $token && !$token->defined_as(T_SPACE);
  return; }

# <filler> = <optional spaces> | <filler>\relax<optional spaces>
# TeX Book p.276 "<left brace> can be implicit", and experimentation, indicate Expansion!!!
sub skipFiller {
  my ($self) = @_;
  while (my $tok = readXNonSpace($self)) {
    if (!$tok->defined_as(T_CS('\relax'))) {
      unread($self, $tok);
      return; } }
  return; }

sub ifNext {
  my ($self, $token) = @_;
  if (my $tok = readToken($self)) {
    unread($self, $tok);
    return $tok->equals($token); }
  else { return 0; } }

# Match the input against one of the Token or Tokens in @choices; return the matching one or undef.
sub readMatch {
  my ($self, @choices) = @_;
  foreach my $choice (@choices) {
    my @tomatch = $choice->unlist;
    my @matched = ();
    my $token;
    while (@tomatch && defined($token = readToken($self))
      && push(@matched, $token) && ($token->equals($tomatch[0]))) {
      shift(@tomatch);
      if ($$token[1] == CC_SPACE) {    # If this was space, SKIP any following!!!
        while (defined($token = readToken($self)) && ($$token[1] == CC_SPACE)) {
          push(@matched, $token); }
        unread($self, $token) if defined $token; } }
    return $choice unless @tomatch;    # All matched!!!
    unread($self, @matched);           # Put 'em back and try next!
  }
  return; }

# Match the input against a set of keywords; Similar to readMatch, but the keywords are strings,
# and Case and catcodes are ignored; additionally, leading spaces are skipped.
# AND, macros are expanded.
sub readKeyword {
  my ($self, @keywords) = @_;
  skipSpaces($self);
  foreach my $keyword (@keywords) {
    $keyword = ToString($keyword) if ref $keyword;
    my @tomatch = split('', uc($keyword));
    my @matched = ();
    my $tok;
    while (@tomatch && defined($tok = readXToken($self, 0)) && push(@matched, $tok)
      && (uc($$tok[0]) eq $tomatch[0])) {
      shift(@tomatch); }
    return $keyword unless @tomatch;    # All matched!!!
    unread($self, @matched); }          # Put 'em back tand try next!
  return; }

# Return a (balanced) sequence tokens until a match against one of the Tokens in @delims.
# Note that Braces on input hides the contents from matching,
# so this assumes there wont be braces in $delim!
# But, see readUntilBrace for that case.
sub readUntil {
  my ($self, $delim) = @_;
  my @tokens = ();
  my $token;
  my $nbraces  = 0;
  my @want     = $delim->unlist;
  my $ntomatch = scalar(@want);
  if ($ntomatch == 1) {    # Common, easy case: read till we match a single token
    my $want = $want[0];
    while (($token = readToken($self)) && !$token->equals($want)) {
      my $cc = $$token[1];
      if ($cc == CC_MARKER) {    # would have been handled by readToken, but we're bypassing
        handleMarker($self, $token); }
      elsif ($$token[1] == CC_BEGIN) {    # And if it's a BEGIN, copy till balanced END
        push(@tokens, $token);
        $nbraces++;
        push(@tokens, readBalanced($self)->unlist, T_END); }
      else {
        push(@tokens, $token); } } }
  else {

    my @ring = ();
    while (1) {
      # prefill the required number of tokens
      while ((scalar(@ring) < $ntomatch) && ($token = readToken($self))) {
        if ($$token[1] == CC_BEGIN) {    # read balanced, and refill ring.
          $nbraces++;
          push(@tokens, @ring, $token, readBalanced($self)->unlist, T_END);    # Copy directly to result
          @ring = (); }                                                        # and retry
        else {
          push(@ring, $token); } }
      my $i;
      for ($i = 0 ; ($i < $ntomatch) && $ring[$i] && ($ring[$i]->equals($want[$i])) ; $i++) { } # Test match
      last if $i >= $ntomatch;    # Matched all!
      last unless $token;
      push(@tokens, shift(@ring)); } }
  if (!defined $token) {          # Ran out!
    unread($self, @tokens);       # Not more correct, but maybe less confusing?
    return; }
  # Notice that IFF the arg looks like {balanced}, the outer braces are stripped
  # so that delimited arguments behave more similarly to simple, undelimited arguments.
  if (($nbraces == 1) && ($tokens[0][1] == CC_BEGIN) && ($tokens[-1][1] == CC_END)) {
    shift(@tokens); pop(@tokens); }
  return TokensI(@tokens); }

sub readUntilBrace {
  my ($self) = @_;
  my @tokens = ();
  my $token;
  while (defined($token = readToken($self))) {
    if ($$token[1] == CC_BEGIN) {    # INLINE Catcode
      $LaTeXML::ALIGN_STATE--;
      unshift(@{ $$self{pushback} }, $token);    # Unread
      last; }
    push(@tokens, $token); }
  return TokensI(@tokens); }

use constant T_csname    => T_CS('\csname');
use constant T_endcsname => T_CS('\endcsname');

sub readCSName {
  my ($self) = @_;
  my $token;
  # Deyan Ginev & Dennis Mueller were right! Or partly so.
  # TeX does NOT store the csname with the leading `\`, BUT stores active chars with a flag
  # However, so long as the Mouth's CS and \string properly respect \escapechar, all's well!
  my $cs = '\\';
  while (($token = readXToken($self, 1)) && (!$token->defined_as(T_endcsname))) {
    my $cc = $$token[1];
    if ($cc == CC_CS) {
      if (defined $STATE->lookupDefinition($token)) {
        Error('unexpected', $token, $self,
          "The control sequence " . ToString($token)
            . " should not appear between \\csname and \\endcsname"); }
      else {
        Error('undefined', $token, $self,
          "The token " . Stringify($token) . " is not defined"); } }
    elsif ($cc == CC_SPACE) { $cs .= ' '; }            # Keep newlines from having \n!
    else                    { $cs .= $$token[0]; } }
  return T_CS($cs); }

#**********************************************************************
# Higher-level readers: Read various types of things from the input:
#  tokens, non-expandable tokens, args, Numbers, ...
#**********************************************************************
sub readArg {
  my ($self, $expanded) = @_;
  my $token = readNonSpace($self);
  if (!defined $token) {
    return; }
  elsif ($$token[1] == CC_BEGIN) {    # Inline ->getCatcode!
    return readBalanced($self, $expanded, 0, 0); }
  else {
    if ($expanded) {
      return $self->readingFromMouth(LaTeXML::Core::Mouth->new(), sub {
          $self->unread(T_BEGIN, $token, T_END);
          return $self->readBalanced($expanded, 0, 1); }); }
    else {
      return Tokens($token); } } }

# Note that this returns an empty array if [] is present,
# otherwise $default or undef.
sub readOptional {
  my ($self, $default) = @_;
  my $tok = readNonSpace($self);
  if (!defined $tok) {
    return; }
  elsif (($tok->equals(T_OTHER('[')))) {
    return readUntil($self, T_OTHER(']')); }
  else {
    unread($self, $tok);
    return $default; } }

#**********************************************************************
#  Numbers, Dimensions, Glue
# See TeXBook, Ch.24, pp.269-271.
#**********************************************************************
sub readValue {
  my ($self, $type) = @_;
  if    ($type eq 'Number')    { return readNumber($self); }
  elsif ($type eq 'Dimension') { return readDimension($self); }
  elsif ($type eq 'Glue')      { return readGlue($self); }
  elsif ($type eq 'MuGlue')    { return readMuGlue($self); }
  elsif ($type eq 'Tokens')    { return readTokensValue($self); }
  elsif ($type eq 'Token') {
    my $token = readNonSpace($self);
    if ($token->defined_as(T_csname)) {
      return readCSName($self); }
    else {
      return $token; } }
  elsif ($type eq 'any') { return readArg($self); }
  else {
    Error('unexpected', $type, $self,
      "Gullet->readValue Didn't expect this type: $type");
    return; }
}

# Read a value from a numeric register, possibly changing sign,
# possibly coercing from a bigger type (eg. a Number from a Dimension)
our %RegisterCoercionTypes = (
  Number      => { Dimension => \&Number, Glue => \&Number },
  Dimension   => { Glue      => \&Dimension },
  MuDimension => { MuGlue    => \&MuDimension },
);

sub readRegisterValue {
  my ($self, $type, $sign, $coerce) = @_;
  my $token = readXToken($self);
  return unless defined $token;
  my ($defn, $rtype, $coercer);
  if (($defn = $STATE->lookupDefinition($token))
    && ($rtype = $defn->isRegister)    # Got a register?
    && (($rtype eq $type) || ($coerce && ($coercer = $RegisterCoercionTypes{$type}{$rtype})))) {
    $sign = +1 unless defined $sign;
    local $LaTeXML::CURRENT_TOKEN = $token;
    my $parms = $$defn{parameters};
    my $value = $defn->valueOf(($parms ? $parms->readArguments($self) : ()));
    if ($type eq $rtype) {
      return ($sign < 0 ? $value->negate : $value); }
    else {
      return &$coercer($sign * $value->valueOf); } }
  else {
    unread($self, $token);
    return; } }

# Apparent behaviour of a token value (ie \toks#=<arg>)
# Expand except within braces?
sub readTokensValue {
  my ($self) = @_;
  my $token = readNonSpace($self);
  if (!defined $token) {
    return; }
  elsif ($$token[1] == CC_BEGIN) {    # Inline ->getCatcode!
    return readBalanced($self); }
  elsif (my $defn = $STATE->lookupDefinition($token)) {
    if ($defn->isRegister eq 'Tokens') {
      my $parms = $$defn{parameters};
      return $defn->valueOf(($parms ? $parms->readArguments($self) : ())); }
    elsif ($defn->isExpandable) {
      if (my $x = $defn->invoke($self)) {
        unread($self, $x->unlist); }
      return readTokensValue($self); }
    else {
      return $token; } }    # ?
  else {
    return $token; } }

#======================================================================
# some helpers...
# Note that <one optional space> is kinda special:
# The following Token(s) are expanded until an unexpandable token is found;
# it is discarded if it is a space, but with an Equals() equality test!

# <optional signs> = <optional spaces> | <optional signs><plus or minus><optional spaces>
# return +1 or -1
sub readOptionalSigns {
  my ($self) = @_;
  my ($sign, $t) = ("+1", '');
  while (defined($t = readXToken($self))
    && (($$t[0] eq '+') || ($$t[0] eq '-') || $t->defined_as(T_SPACE))) {
    $sign = -$sign if ($$t[0] eq '-'); }
  unread($self, $t) if $t;
  return $sign; }

# Read digits (within $range), while expanding and if $skip, skip <one optional space> (expanded!)
sub readDigits {
  my ($self, $range, $skip) = @_;
  my $string = '';
  my ($token, $digit);
  while (($token = readXToken($self)) && (($digit = $$token[0]) =~ /^[$range]$/)) {
    $string .= $digit; }
  unread($self, $token) if $token && !($skip && $token->defined_as(T_SPACE));    #Inline
  return $string; }

# <factor> = <normal integer> | <decimal constant>
# <decimal constant> = . | , | <digit><decimal constant> | <decimal constant><digit>
# Return a number (perl number)
sub readFactor {
  my ($self) = @_;
  my $string = readDigits($self, '0-9');
  my $token  = readXToken($self);
  if ($token && $$token[0] =~ /^[\.\,]$/) {
    $string .= '.' . readDigits($self, '0-9');
    $token = readXToken($self); }
  if (length($string) > 0) {
    unread($self, $token) if $token && $$token[1] != CC_SPACE;
    return $string; }
  else {
    unread($self, $token);
    my $n = readNormalInteger($self);
    return (defined $n ? $n->valueOf : undef); } }

#======================================================================
# Integer, Number
#======================================================================
# <number> = <optional signs><unsigned number>
# <unsigned number> = <normal integer> | <coerced integer>
# <coerced integer> = <internal dimen> | <internal glue>

sub readNumber {
  my ($self) = @_;
  my $s = readOptionalSigns($self);
  if    (defined(my $n = readNormalInteger($self))) { return ($s < 0 ? $n->negate : $n); }
  elsif (defined($n = readRegisterValue($self, 'Number', $s, 1))) { return $n; }
  else {
    my $next = readToken($self);
    unread($self, $next);
    Warn('expected', '<number>', $self, "Missing number, treated as zero",
      "while processing " . ToString($LaTeXML::CURRENT_TOKEN), showUnexpected($self));
    return Number(0); } }

# <normal integer> = <internal integer> | <integer constant>
#   | '<octal constant><one optional space> | "<hexadecimal constant><one optional space>
#   | `<character token><one optional space>
# Return a Number or undef
sub readNormalInteger {
  my ($self) = @_;
  my $token = readXToken($self);     # expand more
  if (!defined $token) {
    return; }
  elsif (($$token[1] == CC_OTHER) && ($$token[0] =~ /^[0-9]$/)) {    # Read decimal literal
    return Number(int($$token[0] . readDigits($self, '0-9', 1))); }
  elsif ($token->equals(T_OTHER("'"))) {                             # Read Octal literal
    return Number(oct(readDigits($self, '0-7', 1))); }
  elsif ($token->equals(T_OTHER("\""))) {                            # Read Hex literal
    return Number(hex(readDigits($self, '0-9A-F', 1))); }
  elsif ($token->equals(T_OTHER("`"))) {                             # Read Charcode
    my $next = readToken($self);
    my $s    = ($next && $$next[0]) || '';
    $s =~ s/^\\//;
    skip1Space($self, 1);
    return Number(ord($s)); }    # Only a character token!!! NOT expanded!!!!
  else {
    unread($self, $token);
    return readRegisterValue($self, 'Number'); } }

#======================================================================
# Float, a floating point number.
# Similar to factor, but does NOT accept comma!
# This is NOT part of TeX, but is convenient.
sub readFloat {
  my ($self) = @_;
  my $s      = readOptionalSigns($self);
  my $string = readDigits($self, '0-9');
  my $token  = readXToken($self);
  if ($token && $$token[0] =~ /^[\.]$/) {
    $string .= '.' . readDigits($self, '0-9');
    $token = readXToken($self); }
  my $n;
  if (length($string) > 0) {
    unread($self, $token) if $token && $$token[1] != CC_SPACE;
    $n = $string; }
  else {
    unread($self, $token) if $token;
    $n = readNormalInteger($self);
    $n = $n->valueOf if defined $n; }
  return (defined $n ? Float($s * $n) : undef); }

#======================================================================
# Dimensions
#======================================================================
# <dimen> = <optional signs><unsigned dimen>
# <unsigned dimen> = <normal dimen> | <coerced dimen>
# <coerced dimen> = <internal glue>
sub readDimension {
  my ($self) = @_;
  my $s = readOptionalSigns($self);
  if (defined(my $d = readRegisterValue($self, 'Dimension', $s, 1))) {
    return $d; }
  elsif (defined($d = readFactor($self))) {
    my $unit = readUnit($self);
    if (!defined $unit) {    # but leave undefined (effectively not rescaled)
      Warn('expected', '<unit>', $self, "Illegal unit of measure (pt inserted)."); }
    return Dimension(fixpoint($s * $d, $unit)); }
  else {
    Warn('expected', '<number>', $self, "Missing number (Dimension), treated as zero.",
      "while processing " . ToString($LaTeXML::CURRENT_TOKEN), showUnexpected($self));
    return Dimension(0); } }

# <unit of measure> = <optional spaces><internal unit>
#     | <optional true><physical unit><one optional space>
# <internal unit> = em <one optional space> | ex <one optional space>
#     | <internal integer> | <internal dimen> | <internal glue>
# <physical unit> = pt | pc | in | bp | cm | mm | dd | cc | sp

# Read a unit, returning the equivalent number of scaled points,
sub readUnit {
  my ($self) = @_;
  if (defined(my $u = readKeyword($self, 'ex', 'em'))) {
    skip1Space($self, 1);
    return $STATE->convertUnit($u); }
  elsif (defined($u = readRegisterValue($self, 'Number', +1, 1))) {
    return $u->valueOf; }    # These are coerced to number=>sp
  else {
    readKeyword($self, 'true');    # But ignore, we're not bothering with mag...
    my $units = $STATE->lookupValue('UNITS');
    $u = readKeyword($self, keys %$units);
    if ($u) {
      skip1Space($self, 1);
      return $STATE->convertUnit($u); }
    else {
      return; } } }

#======================================================================
# Mu Dimensions
#======================================================================
# <mudimen> = <optional signs><unsigned mudimem>
# <unsigned mudimen> = <normal mudimen> | <coerced mudimen>
# <normal mudimen> = <factor><mu unit>
# <mu unit> = <optional spaces><internal muglue> | mu <one optional space>
# <coerced mudimen> = <internal muglue>
sub readMuDimension {
  my ($self) = @_;
  my $s = readOptionalSigns($self);
  if (defined(my $m = readFactor($self))) {
    my $munit = readMuUnit($self);
    if (!defined $munit) {
      Warn('expected', '<unit>', $self, "Illegal unit of measure (mu inserted)."); }
    return MuDimension(fixpoint($s * $m, $munit)); }
  elsif (defined($m = readRegisterValue($self, 'MuDimension', $s, 1))) {
    return $m; }
  else {
    Warn('expected', '<mudimen>', $self, "Expecting mudimen; assuming 0");
    return MuDimension(0); } }

sub readMuUnit {
  my ($self) = @_;
  if (my $m = readKeyword($self, 'mu')) {
    skip1Space($self, 1);
    return $UNITY; }    # effectively, scaled mu
  elsif ($m = readRegisterValue($self, 'MuGlue')) {
    return $m->valueOf; }
  else {
    return; } }

#======================================================================
# Glue
#======================================================================
# <glue> = <optional signs><internal glue> | <dimen><stretch><shrink>
# <stretch> = plus <dimen> | plus <fil dimen> | <optional spaces>
# <shrink>  = minus <dimen> | minus <fil dimen> | <optional spaces>
sub readGlue {
  my ($self) = @_;
  my $s = readOptionalSigns($self);
  my $n;
  if (defined($n = readRegisterValue($self, 'Glue', $s))) {
    return $n; }
  else {
    my $d = readDimension($self);
    if (!$d) {
      Warn('expected', '<number>', $self, "Missing number (Glue), treated as zero.",
        "while processing " . ToString($LaTeXML::CURRENT_TOKEN), showUnexpected($self));
      return Glue(0); }
    $d = $d->negate if $s < 0;
    my ($r1, $f1, $r2, $f2);
    ($r1, $f1) = readRubber($self) if readKeyword($self, 'plus');
    ($r2, $f2) = readRubber($self) if readKeyword($self, 'minus');
    return Glue($d->valueOf, $r1, $f1, $r2, $f2); } }

my %FILLS = (fil => 1, fill => 2, filll => 3);    # [CONSTANT]

sub readRubber {
  my ($self, $mu) = @_;
  my $s = readOptionalSigns($self);
  my $f = readFactor($self);
  if (!defined $f) {
    $f = ($mu ? readMuDimension($self) : readDimension($self));
    return ($f->valueOf * $s, 0); }
  elsif (defined(my $fil = readKeyword($self, 'filll', 'fill', 'fil'))) {
    return (fixpoint($s * $f), $FILLS{$fil}); }
  else {
    my $u = ($mu ? readMuUnit($self) : readUnit($self));
    if (!defined $u) {
      Warn('expected', '<unit>', $self,
        "Illegal unit of measure (" . ($mu ? 'mu' : 'pt') . " inserted)."); }
    return (fixpoint($s * $f, $u), 0); } }

#======================================================================
# Mu Glue
#======================================================================
# <muglue> = <optional signs><internal muglue> | <mudimen><mustretch><mushrink>
# <mustretch> = plus <mudimen> | plus <fil dimen> | <optional spaces>
# <mushrink> = minus <mudimen> | minus <fil dimen> | <optional spaces>
sub readMuGlue {
  my ($self) = @_;
  my $s = readOptionalSigns($self);
  my $n;
  if (defined($n = readRegisterValue($self, 'MuGlue'))) {
    return ($s < 0 ? $n->negate : $n); }
  else {
    my $d = readMuDimension($self);
    if (!$d) {
      Warn('expected', '<number>', $self, "Missing number (MuGlue), treated as zero.",
        "while processing " . ToString($LaTeXML::CURRENT_TOKEN), showUnexpected($self));
      return MuGlue(0); }
    $d = $d->negate if $s < 0;
    my ($r1, $f1, $r2, $f2);
    ($r1, $f1) = readRubber($self, 1) if readKeyword($self, 'plus');
    ($r2, $f2) = readRubber($self, 1) if readKeyword($self, 'minus');
    return MuGlue($d->valueOf, $r1, $f1, $r2, $f2); } }

#======================================================================
# See pp 272-275 for lists of the various registers.
# These are implemented in Primitive.pm

#**********************************************************************
# Deprecated
sub readInternalInteger {
  my ($self) = @_;
  Deprecated('readInternalInteger', '0.8.8',
    "Please use \$gullet->readRegisterValue('Number')");
  return readRegisterValue($self, 'Number'); }

sub readInternalDimension {
  my ($self) = @_;
  Deprecated('readInternalDimension', '0.8.8',
    "Please use \$gullet->readRegisterValue('Dimension')");
  return readRegisterValue($self, 'Dimension'); }

sub readInternalGlue {
  my ($self) = @_;
  Deprecated('readInternalGlue', '0.8.8',
    "Please use \$gullet->readRegisterValue('Glue')");
  return readRegisterValue($self, 'Glue'); }

sub readInternalMuGlue {
  my ($self) = @_;
  Deprecated('readInternalMuGlue', '0.8.8',
    "Please use \$gullet->readRegisterValue('MuGlue')");
  return readRegisterValue($self, 'MuGlue'); }

1;

__END__

=pod

=head1 NAME

C<LaTeXML::Core::Gullet> - expands expandable tokens and parses common token sequences.

=head1 DESCRIPTION

A C<LaTeXML::Core::Gullet> reads tokens (L<LaTeXML::Core::Token>) from a L<LaTeXML::Core::Mouth>.
It is responsible for expanding macros and expandable control sequences,
if the current definition associated with the token in the L<LaTeXML::Core::State>
is an L<LaTeXML::Core::Definition::Expandable> definition. The C<LaTeXML::Core::Gullet> also provides a
variety of methods for reading  various types of input such as arguments, optional arguments,
as well as for parsing L<LaTeXML::Common::Number>, L<LaTeXML::Common::Dimension>, etc, according
to TeX's rules.

It extends L<LaTeXML::Common::Object>.

=head2 Managing Input

=over 4

=item C<< $gullet->openMouth($mouth, $noautoclose); >>

Is this public? Prepares to read tokens from C<$mouth>.
If $noautoclose is true, the Mouth will not be automatically closed
when it is exhausted.

=item C<< $gullet->closeMouth; >>

Is this public? Finishes reading from the current mouth, and
reverts to the one in effect before the last openMouth.

=item C<< $gullet->flush; >>

Is this public? Clears all inputs.

=item C<< $gullet->getLocator; >>

Returns an object describing the current location in the input stream.

=back

=head2 Low-level methods

=over 4

=item C<< $token = $gullet->readToken; >>

Return the next token from the input source, or undef if there is no more input.

=item C<< $token = $gullet->readXToken($toplevel,$for_conditional, $fully_expand); >>

Return the next unexpandable token from the input source, or undef if there is no more input.
If the next token is expandable, it is expanded, and its expansion is reinserted into the input,
and reading continues.
If C<$toplevel> is true, it will automatically close empty mouths as it reads, and will also fully expand macros (unless overridden by C<$fully_expand> being explicitly false). Full expansion expands protected macros as well as the results of L<\the> (and similar).
If C<$for_conditional> is true, handle L<\noexpand> appropriately for the arguments to L<\if>.

=item C<< $tokens = $gullet->readBalanced($expanded, $macrodef, $require_open); >>

Read a sequence of tokens from the input until the balancing '}'.
By default assumes the '{' has already been read.

No expansion takes place if C<$expand> is 0 or undef; partial expansion (deferring protected and C<\the>) of C<$expand> is 1; full expansion if it is > 1.
The C<$macrodef> flag affects whether # parameters are "packed" for macro bodies.
If C<$require_open> is true, the opening C<T_BEGIN> has not yet been read, and is required.
Returns a L<LaTeXML::Core::Tokens>.

=item C<< $gullet->unread(@tokens); >>

Push the C<@tokens> back into the input stream to be re-read.

=back

=head2 Mid-level methods

=over 4

=item C<< $token = $gullet->readNonSpace; >>

Read and return the next non-space token from the input after discarding any spaces.

=item C<< $token = $gullet->readXNonSpace; >>

Read and return the next non-space token from the input after discarding any spaces,
partially expanding as it goes.

=item C<< $gullet->skipSpaces; >>

Skip the next spaces from the input.

=item C<< $gullet->skip1Space($expanded); >>

Skip the next token from the input if it is a space.
If C($expanded> is true, expands ( like C< <one optional space> > ).

=item C<< $boole = $gullet->ifNext($token); >>

Returns true if the next token in the input matches C<$token>;
the possibly matching token remains in the input.

=item C<< $tokens = $gullet->readMatch(@choices); >>

Read and return whichever of C<@choices>
matches the input, or undef if none do.
Each of the choices is an L<LaTeXML::Core::Tokens>.

=item C<< $keyword = $gullet->readKeyword(@keywords); >>

Read and return whichever of C<@keywords> (each a string) matches the input, or undef
if none do.  This is similar to readMatch, but case and catcodes are ignored.
Also, leading spaces are skipped.

=item C<< $tokens = $gullet->readUntil(@delims); >>

Read and return a (balanced) sequence of L<LaTeXML::Core::Tokens> until  matching one of the tokens
in C<@delims>.  In a list context, it also returns which of the delimiters ended the sequence.

=back

=head2 High-level methods

=over 4

=item C<< $tokens = $gullet->readArg($expanded); >>

Read and return a "normal" TeX argument; the next Token or Tokens (if surrounded by braces).
C<$expanded> controls expansion as if the argument were read and then expanded in isolation:
0,undef or missing gives no expansion; 1 gives partial expansion; > 1 gives full expansion.
In the case of a single unbraced expandable token, it will I<not> read any macro arguments from the following input!

=item C<< $tokens = $gullet->readOptional($default); >>

Read and return a LaTeX optional argument; returns C<$default> if there is no '[',
otherwise the contents of the [].

=item C<< $thing = $gullet->readValue($type); >>

Reads an argument of a given type: one of 'Number', 'Dimension', 'Glue', 'MuGlue' or 'any'.

=item C<< $value = $gullet->readRegisterValue($type); >>

Read a control sequence token (and possibly it's arguments) that names a register,
and return the value.  Returns undef if the next token isn't such a register.

=item C<< $number = $gullet->readNumber; >>

Read a L<LaTeXML::Common::Number> according to TeX's rules of the various things that
can be used as a numerical value.

=item C<< $dimension = $gullet->readDimension; >>

Read a L<LaTeXML::Common::Dimension> according to TeX's rules of the various things that
can be used as a dimension value.

=item C<< $mudimension = $gullet->readMuDimension; >>

Read a L<LaTeXML::Core::MuDimension> according to TeX's rules of the various things that
can be used as a mudimension value.

=item C<< $glue = $gullet->readGlue; >>

Read a  L<LaTeXML::Common::Glue> according to TeX's rules of the various things that
can be used as a glue value.

=item C<< $muglue = $gullet->readMuGlue; >>

Read a L<LaTeXML::Core::MuGlue> according to TeX's rules of the various things that
can be used as a muglue value.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
