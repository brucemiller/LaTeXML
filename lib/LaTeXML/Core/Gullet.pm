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
    my $next = Stringify($self->readToken);
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

sub setup_scan {
  my ($self) = @_;
  if ($$self{pushback_has_smuggled_the}) {
    $$self{pushback_has_smuggled_the} = 0;
    # setup new scan by removing any smuggle CCs
    for my $token (@{ $$self{pushback} }) {
      if ($$token[1] == CC_SMUGGLE_THE) {
        $token = $$token[2]; } } }
  return; }

# Do something, while reading stuff from a specific Mouth.
# This reads ONLY from that mouth (or any mouth openned by code in that source),
# and the mouth should end up empty afterwards, and only be closed here.
sub readingFromMouth {
  my ($self, $mouth, $closure) = @_;
  $self->openMouth($mouth, 1);    # only allow mouth to be explicitly closed here.
  my ($result, @result);
  if (wantarray) {
    @result = &$closure($self); }
  else {
    $result = &$closure($self); }
  # $mouth must still be open, with (at worst) empty autoclosable mouths in front of it
  while (1) {
    if ($$self{mouth} eq $mouth) {
      $self->closeMouth(1); last; }
    elsif (!@{ $$self{mouthstack} }) {
      Error('unexpected', '<closed>', $self, "Mouth is unexpectedly already closed",
        "Reading from " . Stringify($mouth) . ", but it has already been closed."); last; }
    elsif (!$$self{autoclose} || @{ $$self{pushback} } || $$self{mouth}->hasMoreInput) {
      my $next = Stringify($self->readToken);
      Error('unexpected', $next, $self, "Unexpected input remaining: '$next'",
        "Finished reading from " . Stringify($mouth) . ", but it still has input.");
      $$self{mouth}->finish;
      $self->closeMouth(1); }    # ?? if we continue?
    else {
      $self->closeMouth; } }
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
  if (my $token = $self->readToken) {
    my @pb = @{ $$self{pushback} };
    $message = "Next token is " . Stringify($token)
      . " ( == " . Stringify($STATE->lookupMeaning($token)) . ")"
      . (@pb ? " more: " . ToString(Tokens(@pb)) : '');
    unshift(@{ $$self{pushback} }, $token);
  }
  return $message; }

sub show_pushback {
  my ($pb) = @_;
  my @pb = @$pb;
  @pb = (@pb[0 .. 50], T_OTHER('...')) if scalar(@pb) > 55;
  return (@pb ? "\n  To be read again " . ToString(Tokens(@pb)) : ''); }

#**********************************************************************
# Low-level readers: read token, read expanded token
#**********************************************************************
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
      . "@ " . ToString($self->getLocator))
    if $LaTeXML::DEBUG{halign};
  #  Append expansion to end!?!?!?!
  local $LaTeXML::CURRENT_TOKEN = $token;
  my $post = $alignment->getColumnAfter;
  $LaTeXML::ALIGN_STATE = 1000000;
  ### NOTE: Truly fishy smuggling w/ \hidden@cr
  my $arg;
  if (($type eq 'cr') && $hidden) {    # \hidden@cr gets an argument as payload!!!!!
    $arg = $self->readArg(); }
  Debug("Halign $alignment: column after " . ToString($post)) if $LaTeXML::DEBUG{halign};
  if ((($type eq 'cr') || ($type eq 'crcr'))
    && $$alignment{in_row} && !$alignment->currentRow->{pseudorow}) {
    unshift(@{ $$self{pushback} }, T_CS('\@row@after')); }
  if ($arg) {
    unshift(@{ $$self{pushback} }, T_BEGIN, $arg->unlist, T_END); }
  unshift(@{ $$self{pushback} }, $token);
  unshift(@{ $$self{pushback} }, $post->unlist);
  return; }

# If it is a column ending token, Returns the token, a keyword and whether it is "hidden"
our @column_ends = (
  [T_ALIGN,               'align',  0],
  [T_CS('\cr'),           'cr',     0],
  [T_CS('\crcr'),         'crcr',   0],
  [T_CS('\hidden@cr'),    'cr',     1],
  [T_CS('\hidden@crcr'),  'crcr',   1],
  [T_CS('\hidden@align'), 'insert', 1],
  [T_CS('\span'),         'span',   0]);

sub isColumnEnd {
  my ($self, $token) = @_;
  my $cc = $$token[1];
  return unless ($cc == CC_ALIGN) || ($cc == CC_CS);
  # Embedded version of Equals, knowing both are tokens
  my $defn = $STATE->lookupMeaning($token) || $token;
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
      && (($$token[1] != CC_SMUGGLE_THE) || ($token = $$token[2]))
      && $CATCODE_HOLD[$cc = $$token[1]]) {
      if ($cc == CC_COMMENT) {
        push(@{ $$self{pending_comments} }, $token); }
      elsif ($cc == CC_MARKER) {
        $self->handleMarker($token); } }
    # Not in pushback, use the current mouth
    if (!defined $token) {
      while (($token = $$self{mouth}->readToken()) && $CATCODE_HOLD[$cc = $$token[1]]) {
        if ($cc == CC_COMMENT) {
          push(@{ $$self{pending_comments} }, $token); }    # What to do with comments???
        elsif ($cc == CC_MARKER) {
          $self->handleMarker($token); } } }
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
      && (($atoken, $atype, $ahidden) = $self->isColumnEnd($token))) {
      $self->handleTemplate($LaTeXML::READING_ALIGNMENT, $token, $atype, $ahidden); }
    else {
      last; } }
  return $token; }

# Unread tokens are assumed to be not-yet expanded.
sub unread {
  my ($self, @tokens) = @_;
  my $r;
  unshift(@{ $$self{pushback} },
    map { (!defined $_ ? ()
        : (($r = ref $_) eq 'LaTeXML::Core::Token' ? $_
          : ($r eq 'LaTeXML::Core::Tokens' ? @$_
            : Error('misdefined', $r, undef, "Expected a Token, got " . Stringify($_)) || T_OTHER(Stringify($_))))) }
      @tokens);
  return; }

# Read the next non-expandable token (expanding tokens until there's a non-expandable one).
# Note that most tokens pass through here, so be Fast & Clean! readToken is folded in.
# `Toplevel' processing, (if $toplevel is true), used at the toplevel processing by Stomach,
#  will step to the next input stream (Mouth) if one is available,
# If $commentsok is true, will also pass comments.
# $toplevel is doing TWO distinct things. When true:
#  * If a mouth is exhausted, move on to the containing mouth to continue reading
#  * expand even protected defns, essentially this means expand "for execution"
sub readXToken {
  my ($self, $toplevel, $commentsok) = @_;
  $toplevel = 1 unless defined $toplevel;
  my $autoclose      = $toplevel;    # Potentially, these should have distinct controls?
  my $for_evaluation = $toplevel;
  return shift(@{ $$self{pending_comments} }) if $commentsok && @{ $$self{pending_comments} };
  my ($token, $cc, $defn, $atoken, $atype, $ahidden);
  while (1) {
    # NOTE: CC_SMUGGLE_THE should ONLY appear in pushback!
    while (($token = shift(@{ $$self{pushback} })) && $CATCODE_HOLD[$cc = $$token[1]]) {
      if ($cc == CC_COMMENT) {
        return $token if $commentsok;
        push(@{ $$self{pending_comments} }, $token); }
      elsif ($cc == CC_MARKER) {
        $self->handleMarker($token); } }
    if (!defined $token) {    # Else read from current mouth
      while (($token = $$self{mouth}->readToken()) && $CATCODE_HOLD[$cc = $$token[1]]) {
        if ($cc == CC_COMMENT) {
          return $token if $commentsok;
          push(@{ $$self{pending_comments} }, $token); }
        elsif ($cc == CC_MARKER) {
          $self->handleMarker($token); } } }
    ProgressStep() if ($$self{progress}++ % $TOKEN_PROGRESS_QUANTUM) == 0;
    if (!defined $token) {
      return unless $autoclose && $$self{autoclose} && @{ $$self{mouthstack} };
      $self->closeMouth; }    # Next input stream.
        # Handle \noexpand and  smuggled tokens; either expand to $$token[2] or defer till later
    elsif (my $unexpanded = $$token[2]) {    # Inline get_dont_expand
      return ($cc != CC_SMUGGLE_THE) || $LaTeXML::SMUGGLE_THE ? $token : $unexpanded; }
    ## Wow!!!!! See TeX the Program \S 309
    elsif (!$LaTeXML::ALIGN_STATE    # SHOULD count nesting of { }!!! when SCANNED (not digested)
      && $LaTeXML::READING_ALIGNMENT
      && (($atoken, $atype, $ahidden) = $self->isColumnEnd($token))) {
      $self->handleTemplate($LaTeXML::READING_ALIGNMENT, $token, $atype, $ahidden); }
    ## Note: use general-purpose lookup, since we may reexamine $defn below
    elsif ($LaTeXML::Core::State::CATCODE_ACTIVE_OR_CS[$cc]
      && defined($defn = $STATE->lookupMeaning($token))
      && ((ref $defn) ne 'LaTeXML::Core::Token')    # an actual definition
      && $$defn{isExpandable}
      && ($for_evaluation || !$$defn{isProtected})) { # is this the right logic here? don't expand unless di
      local $LaTeXML::CURRENT_TOKEN = $token;
      my $r;
      my @expansion = map { (($r = ref $_) eq 'LaTeXML::Core::Token' ? $_
          : ($r eq 'LaTeXML::Core::Tokens' ? @$_
            : Error('misdefined', $r, undef, "Expected a Token, got " . Stringify($_),
              "in " . ToString($defn)) || T_OTHER(Stringify($_)))) }
        $defn->invoke($self);
      next unless @expansion;
      if ($$LaTeXML::Core::Token::SMUGGLE_THE_COMMANDS{ $$defn{cs}[0] }) {
        # magic THE_TOKS handling, add to pushback with a single-use noexpand flag only valid
        # at the exact time the token leaves the pushback.
        # This is *required to be different* from the noexpand flag, as per the B Book
        @expansion = map { ($LaTeXML::Core::Token::CATCODE_CAN_SMUGGLE_THE[$$_[1]] ? bless ["SMUGGLE_THE", CC_SMUGGLE_THE, $_], 'LaTeXML::Core::Token' : $_) } @expansion;
        # PERFORMANCE:
        #   explicitly flag that we've seen this case, so that higher levels know to
        #   unset the flag from the entire {pushback}
        $$self{pushback_has_smuggled_the} = 1; }
      # add the newly expanded tokens back into the gullet stream, in the ordinary case.
      unshift(@{ $$self{pushback} }, @expansion); }
    elsif ($$token[1] == CC_CS && !(defined $defn)) {
      $STATE->generateErrorStub($self, $token);    # cs SHOULD have defn by now; report early!
      return $token; }
    else {
      return $token; }                             # just return it
  }
  return; }                                        # never get here.

# Read the next raw line (string);
# primarily to read from the Mouth, but keep any unread input!
sub readRawLine {
  my ($self) = @_;
  # If we've got unread tokens, they presumably should come before the Mouth's raw data
  # but we'll convert them back to string.
  my @tokens  = map  { ($$_[1] == CC_SMUGGLE_THE ? $$_[2] : $_) } @{ $$self{pushback} };
  my @markers = grep { $_->getCatcode == CC_MARKER } @tokens;
  if (@markers) {    # Whoops, profiling markers!
    @tokens = grep { $_->getCatcode != CC_MARKER } @tokens;    # Remove
    map { LaTeXML::Core::Definition::stopProfiling($_, 'expand') } @markers; }
  $$self{pushback} = [];
  # If we still have peeked tokens, we ONLY want to combine it with the remainder
  # of the current line from the Mouth (NOT reading a new line)
  if (@tokens) {
    return ToString(Tokens(@tokens)) . $$self{mouth}->readRawLine(1); }
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
  do { $token = $self->readToken();
  } while (defined $token && $$token[1] == CC_SPACE);    # Inline ->getCatcode!
  return $token; }

sub readXNonSpace {
  my ($self) = @_;
  my $token;
  do { $token = $self->readXToken(0);
  } while (defined $token && $$token[1] == CC_SPACE);    # Inline ->getCatcode!
  return $token; }

sub skipSpaces {
  my ($self) = @_;
  my $tok = $self->readNonSpace;
  unshift(@{ $$self{pushback} }, $tok) if defined $tok;    # Unread
  return; }

# Skip one space
# if $expanded is true, it acts like <one optional space>, expanding the next token.
sub skip1Space {
  my ($self, $expanded) = @_;
  my $token = ($expanded ? $self->readXToken : $self->readToken);
  unshift(@{ $$self{pushback} }, $token) if $token && !Equals($token, T_SPACE);
  return; }

# <filler> = <optional spaces> | <filler>\relax<optional spaces>
sub skipFiller {
  my ($self) = @_;
  while (1) {
    my $tok = $self->readNonSpace;
    return unless defined $tok;
    # Should \foo work too (where \let\foo\relax) ??
    if (!$tok->equals(T_CS('\relax'))) {
      unshift(@{ $$self{pushback} }, $tok);    # Unread
      return; }
  }
  return; }

# Read a sequence of tokens balanced in {}
# assuming the { has already been read.
# Returns a Tokens list of the balanced sequence, omitting the closing }
our @CATCODE_BALANCED_INTERESTING = (
  0, 1, 1, 0,
  0, 0, 0, 0,
  0, 0, 0, 0,
  0, 0, 0, 0,
  0, 1, 0, 0);

sub readBalanced {
  my ($self, $expanded) = @_;
  local $LaTeXML::ALIGN_STATE = 1000000;
  my @tokens = ();
  my ($token, $level) = (undef, 1);
  my $startloc = ($$self{verbosity} > 0) && $self->getLocator;
  # Inlined readToken (we'll keep comments in the result)
  while ($token = ($expanded ? $self->readXToken(0, 1) : $self->readToken())) {
    my $cc = $$token[1];
    if (!$CATCODE_BALANCED_INTERESTING[$cc]) {
      push(@tokens, $token); }
    elsif ($cc == CC_END) {
      $level--;
      if (!$level) {
        last; }
      push(@tokens, $token); }
    elsif ($cc == CC_BEGIN) {
      $level++;
      push(@tokens, $token); }
    elsif ($cc == CC_MARKER) {
      LaTeXML::Core::Definition::stopProfiling($token, 'expand'); } }
  if ($level > 0) {
 # TODO: The current implementation has a limitation where if the balancing end is in a different mouth,
 #       it will not be recognized.
    my $loc_message = $startloc ? ("Started at " . ToString($startloc)) : ("Ended at " . ToString($self->getLocator));
    Error('expected', "}", $self, "Gullet->readBalanced ran out of input in an unbalanced state.",
      $loc_message); }
  return Tokens(@tokens); }

sub ifNext {
  my ($self, $token) = @_;
  if (my $tok = $self->readToken()) {
    unshift(@{ $$self{pushback} }, $tok);    # Unread
    return $tok->equals($token); }
  else { return 0; } }

# Match the input against one of the Token or Tokens in @choices; return the matching one or undef.
sub readMatch {
  my ($self, @choices) = @_;
  foreach my $choice (@choices) {
    my @tomatch = $choice->unlist;
    my @matched = ();
    my $token;
    while (@tomatch && defined($token = $self->readToken)
      && push(@matched, $token) && ($token->equals($tomatch[0]))) {
      shift(@tomatch);
      if ($$token[1] == CC_SPACE) {    # If this was space, SKIP any following!!!
        while (defined($token = $self->readToken) && ($$token[1] == CC_SPACE)) {
          push(@matched, $token); }
        unshift(@{ $$self{pushback} }, $token) if $token; }    # Unread
    }
    return $choice unless @tomatch;                            # All matched!!!
    unshift(@{ $$self{pushback} }, @matched);                  # Put 'em back and try next!
  }
  return; }

# Match the input against a set of keywords; Similar to readMatch, but the keywords are strings,
# and Case and catcodes are ignored; additionally, leading spaces are skipped.
# AND, macros are expanded.
sub readKeyword {
  my ($self, @keywords) = @_;
  $self->skipSpaces;
  foreach my $keyword (@keywords) {
    $keyword = ToString($keyword) if ref $keyword;
    my @tomatch = split('', uc($keyword));
    my @matched = ();
    my $tok;
    while (@tomatch && defined($tok = $self->readXToken(0)) && push(@matched, $tok)
      && (uc($tok->toString) eq $tomatch[0])) {
      shift(@tomatch); }
    return $keyword unless @tomatch;             # All matched!!!
    unshift(@{ $$self{pushback} }, @matched);    # Put 'em back and try next!
  }
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
    #    while(($token = $self->readToken) && !$token->equals($want)){
    while (($token = shift(@{ $$self{pushback} }) || $$self{mouth}->readToken())
      && (($$token[1] != CC_SMUGGLE_THE) || ($token = $$token[2]))
      && !$token->equals($want)) {
      push(@tokens, $token);
      if ($$token[1] == CC_BEGIN) {    # And if it's a BEGIN, copy till balanced END
        $nbraces++;
        push(@tokens, $self->readBalanced, T_END); } } }
  else {

    my @ring = ();
    while (1) {
      # prefill the required number of tokens
      while ((scalar(@ring) < $ntomatch) && ($token = $self->readToken)) {
        if ($$token[1] == CC_BEGIN) {    # read balanced, and refill ring.
          $nbraces++;
          push(@tokens, @ring, $token, $self->readBalanced, T_END);    # Copy directly to result
          @ring = (); }                                                # and retry
        else {
          push(@ring, $token); } }
      my $i;
      for ($i = 0 ; ($i < $ntomatch) && $ring[$i] && ($ring[$i]->equals($want[$i])) ; $i++) { } # Test match
      last if $i >= $ntomatch;    # Matched all!
      last unless $token;
      push(@tokens, shift(@ring)); } }
  if (!defined $token) {          # Ran out!
    $self->unread(@tokens);       # Not more correct, but maybe less confusing?
    return; }
  # Notice that IFF the arg looks like {balanced}, the outer braces are stripped
  # so that delimited arguments behave more similarly to simple, undelimited arguments.
  if (($nbraces == 1) && ($tokens[0][1] == CC_BEGIN) && ($tokens[-1][1] == CC_END)) {
    shift(@tokens); pop(@tokens); }
  return Tokens(@tokens); }

sub readUntilBrace {
  my ($self) = @_;
  my @tokens = ();
  my $token;
  while (defined($token = $self->readToken())) {
    if ($$token[1] == CC_BEGIN) {    # INLINE Catcode
      unshift(@{ $$self{pushback} }, $token);    # Unread
      last; }
    push(@tokens, $token); }
  return Tokens(@tokens); }

#**********************************************************************
# Higher-level readers: Read various types of things from the input:
#  tokens, non-expandable tokens, args, Numbers, ...
#**********************************************************************
sub readArg {
  my ($self) = @_;
  my $token = $self->readNonSpace;
  if (!defined $token) {
    return; }
  elsif ($$token[1] == CC_BEGIN) {    # Inline ->getCatcode!
    return $self->readBalanced(0); }
  else {
    return Tokens($token); } }

# Note that this returns an empty array if [] is present,
# otherwise $default or undef.
sub readOptional {
  my ($self, $default) = @_;
  my $tok = $self->readNonSpace;
  if (!defined $tok) {
    return; }
  elsif (($tok->equals(T_OTHER('[')))) {
    return $self->readUntil(T_OTHER(']')); }
  else {
    unshift(@{ $$self{pushback} }, $tok);    # Unread
    return $default; } }

#**********************************************************************
#  Numbers, Dimensions, Glue
# See TeXBook, Ch.24, pp.269-271.
#**********************************************************************
sub readValue {
  my ($self, $type) = @_;
  if    ($type eq 'Number')    { return $self->readNumber; }
  elsif ($type eq 'Dimension') { return $self->readDimension; }
  elsif ($type eq 'Glue')      { return $self->readGlue; }
  elsif ($type eq 'MuGlue')    { return $self->readMuGlue; }
  elsif ($type eq 'Tokens')    { return $self->readTokensValue; }
  elsif ($type eq 'Token') {
    my $token = $self->readToken;
    if (Equals($token, T_CS('\csname'))) {
      my $cstoken = $STATE->lookupDefinition($token)->invoke($self);
      $self->unread(@{$cstoken});
      return $self->readToken; }
    else {
      return $token; } }
  elsif ($type eq 'any') { return $self->readArg; }
  else {
    Error('unexpected', $type, $self,
      "Gullet->readValue Didn't expect this type: $type");
    return; }
}

sub readRegisterValue {
  my ($self, $type) = @_;
  my $token = $self->readXToken;
  return unless defined $token;
  my $defn = $STATE->lookupDefinition($token);
  if ((defined $defn) && ($defn->isRegister eq $type)) {
    local $LaTeXML::CURRENT_TOKEN = $token;
    my $parms = $$defn{parameters};
    return $defn->valueOf(($parms ? $parms->readArguments($self) : ())); }
  else {
    unshift(@{ $$self{pushback} }, $token);    # Unread
    return; } }

# Apparent behaviour of a token value (ie \toks#=<arg>)
sub readTokensValue {
  my ($self) = @_;
  my $token = $self->readNonSpace;
  if (!defined $token) {
    return; }
  elsif ($$token[1] == CC_BEGIN) {    # Inline ->getCatcode!
    return $self->readBalanced; }
  elsif (my $defn = $STATE->lookupDefinition($token)) {
    if ($defn->isRegister eq 'Tokens') {
      my $parms = $$defn{parameters};
      return $defn->valueOf(($parms ? $parms->readArguments($self) : ())); }
    elsif ($defn->isExpandable) {
      if (my $x = $defn->invoke($self)) {
        $self->unread(@{$x}); }
      return $self->readTokensValue; }
    elsif (Equals($token, T_CS('\csname'))) {
      my $cstoken = $defn->invoke($self);
      $self->unread(@{$cstoken});
      return $self->readToken; }
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
  while (defined($t = $self->readXToken)
    && (($t->getString eq '+') || ($t->getString eq '-') || Equals($t, T_SPACE))) {
    $sign = -$sign if ($t->getString eq '-'); }
  unshift(@{ $$self{pushback} }, $t) if $t;    # Unread
  return $sign; }

# Read digits (within $range), while expanding and if $skip, skip <one optional space> (expanded!)
sub readDigits {
  my ($self, $range, $skip) = @_;
  my $string = '';
  my ($token, $digit);
  while (($token = $self->readXToken) && (($digit = $token->toString) =~ /^[$range]$/)) {
    $string .= $digit; }
  unshift(@{ $$self{pushback} }, $token) if $token && !($skip && Equals($token, T_SPACE));    #Inline
  return $string; }

# <factor> = <normal integer> | <decimal constant>
# <decimal constant> = . | , | <digit><decimal constant> | <decimal constant><digit>
# Return a number (perl number)
sub readFactor {
  my ($self) = @_;
  my $string = $self->readDigits('0-9');
  my $token  = $self->readXToken;
  if ($token && $token->getString =~ /^[\.\,]$/) {
    $string .= '.' . $self->readDigits('0-9');
    $token = $self->readXToken; }
  if (length($string) > 0) {
    unshift(@{ $$self{pushback} }, $token) if $token && $$token[1] != CC_SPACE; # Inline ->getCatcode, unread
    return $string; }
  else {
    unshift(@{ $$self{pushback} }, $token);                                     # Unread
    my $n = $self->readNormalInteger;
    return (defined $n ? $n->valueOf : undef); } }

#======================================================================
# Integer, Number
#======================================================================
# <number> = <optional signs><unsigned number>
# <unsigned number> = <normal integer> | <coerced integer>
# <coerced integer> = <internal dimen> | <internal glue>

sub readNumber {
  my ($self) = @_;
  my $s = $self->readOptionalSigns;
  if    (defined(my $n = $self->readNormalInteger))  { return ($s < 0 ? $n->negate : $n); }
  elsif (defined($n = $self->readInternalDimension)) { return Number($s * $n->valueOf); }
  elsif (defined($n = $self->readInternalGlue))      { return Number($s * $n->valueOf); }
  else {
    my $next = $self->readToken();
    unshift(@{ $$self{pushback} }, $next);    # Unread
    Warn('expected', '<number>', $self, "Missing number, treated as zero",
      "while processing " . ToString($LaTeXML::CURRENT_TOKEN), $self->showUnexpected);
    return Number(0); } }

# <normal integer> = <internal integer> | <integer constant>
#   | '<octal constant><one optional space> | "<hexadecimal constant><one optional space>
#   | `<character token><one optional space>
# Return a Number or undef
sub readNormalInteger {
  my ($self) = @_;
  my $token = $self->readXToken;     # expand more
  if (!defined $token) {
    return; }
  elsif (($$token[1] == CC_OTHER) && ($token->toString =~ /^[0-9]$/)) {    # Read decimal literal
    return Number(int($token->getString . $self->readDigits('0-9', 1))); }
  elsif ($token->equals(T_OTHER("'"))) {                                   # Read Octal literal
    return Number(oct($self->readDigits('0-7', 1))); }
  elsif ($token->equals(T_OTHER("\""))) {                                  # Read Hex literal
    return Number(hex($self->readDigits('0-9A-F', 1))); }
  elsif ($token->equals(T_OTHER("`"))) {                                   # Read Charcode
    my $next = $self->readToken;
    my $s    = ($next && $next->toString) || '';
    $s =~ s/^\\//;
    $self->skip1Space(1);
    return Number(ord($s)); }    # Only a character token!!! NOT expanded!!!!
  else {
    unshift(@{ $$self{pushback} }, $token);    # Unread
    return $self->readInternalInteger; } }

sub readInternalInteger {
  my ($self) = @_;
  return $self->readRegisterValue('Number'); }

#======================================================================
# Float, a floating point number.
# Similar to factor, but does NOT accept comma!
# This is NOT part of TeX, but is convenient.
sub readFloat {
  my ($self) = @_;
  my $s      = $self->readOptionalSigns;
  my $string = $self->readDigits('0-9');
  my $token  = $self->readXToken;
  if ($token && $token->getString =~ /^[\.]$/) {
    $string .= '.' . $self->readDigits('0-9');
    $token = $self->readXToken; }
  my $n;
  if (length($string) > 0) {
    unshift(@{ $$self{pushback} }, $token) if $token && $$token[1] != CC_SPACE; # Inline ->getCatcode, unread
    $n = $string; }
  else {
    unshift(@{ $$self{pushback} }, $token) if $token;                           # Unread
    $n = $self->readNormalInteger;
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
  my $s = $self->readOptionalSigns;
  if (defined(my $d = $self->readInternalDimension)) {
    return ($s < 0 ? $d->negate : $d); }
  elsif (defined($d = $self->readInternalGlue)) {
    return Dimension($s * $d->valueOf); }
  elsif (defined($d = $self->readFactor)) {
    my $unit = $self->readUnit;
    if (!defined $unit) {    # but leave undefined (effectively not rescaled)
      Warn('expected', '<unit>', $self, "Illegal unit of measure (pt inserted)."); }
    return Dimension(fixpoint($s * $d, $unit)); }
  else {
    Warn('expected', '<number>', $self, "Missing number (Dimension), treated as zero.",
      "while processing " . ToString($LaTeXML::CURRENT_TOKEN), $self->showUnexpected);
    return Dimension(0); } }

# <unit of measure> = <optional spaces><internal unit>
#     | <optional true><physical unit><one optional space>
# <internal unit> = em <one optional space> | ex <one optional space>
#     | <internal integer> | <internal dimen> | <internal glue>
# <physical unit> = pt | pc | in | bp | cm | mm | dd | cc | sp

# Read a unit, returning the equivalent number of scaled points,
sub readUnit {
  my ($self) = @_;
  if (defined(my $u = $self->readKeyword('ex', 'em'))) {
    $self->skip1Space(1);
    return $STATE->convertUnit($u); }
  elsif (defined($u = $self->readInternalInteger)) {
    return $u->valueOf; }    # These are coerced to number=>sp
  elsif (defined($u = $self->readInternalDimension)) {
    return $u->valueOf; }
  elsif (defined($u = $self->readInternalGlue)) {
    return $u->valueOf; }
  else {
    $self->readKeyword('true');    # But ignore, we're not bothering with mag...
    my $units = $STATE->lookupValue('UNITS');
    $u = $self->readKeyword(keys %$units);
    if ($u) {
      $self->skip1Space(1);
      return $STATE->convertUnit($u); }
    else {
      return; } } }

# Return a dimension value or undef
sub readInternalDimension {
  my ($self) = @_;
  return $self->readRegisterValue('Dimension'); }

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
  my $s = $self->readOptionalSigns;
  if (defined(my $m = $self->readFactor)) {
    my $munit = $self->readMuUnit;
    if (!defined $munit) {
      Warn('expected', '<unit>', $self, "Illegal unit of measure (mu inserted)."); }
    return MuDimension(fixpoint($s * $m, $munit)); }
  elsif (defined($m = $self->readInternalMuGlue)) {
    return MuDimension($s * $m->valueOf); }
  else {
    Warn('expected', '<mudimen>', $self, "Expecting mudimen; assuming 0");
    return MuDimension(0); } }

sub readMuUnit {
  my ($self) = @_;
  if (my $m = $self->readKeyword('mu')) {
    $self->skip1Space(1);
    return $UNITY; }    # effectively, scaled mu
  elsif ($m = $self->readInternalMuGlue) {
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
  my $s = $self->readOptionalSigns;
  my $n;
  if (defined($n = $self->readInternalGlue)) {
    return ($s < 0 ? $n->negate : $n); }
  else {
    my $d = $self->readDimension;
    if (!$d) {
      Warn('expected', '<number>', $self, "Missing number (Glue), treated as zero.",
        "while processing " . ToString($LaTeXML::CURRENT_TOKEN), $self->showUnexpected);
      return Glue(0); }
    $d = $d->negate if $s < 0;
    my ($r1, $f1, $r2, $f2);
    ($r1, $f1) = $self->readRubber if $self->readKeyword('plus');
    ($r2, $f2) = $self->readRubber if $self->readKeyword('minus');
    return Glue($d->valueOf, $r1, $f1, $r2, $f2); } }

my %FILLS = (fil => 1, fill => 2, filll => 3);    # [CONSTANT]

sub readRubber {
  my ($self, $mu) = @_;
  my $s = $self->readOptionalSigns;
  my $f = $self->readFactor;
  if (!defined $f) {
    $f = ($mu ? $self->readMuDimension : $self->readDimension);
    return ($f->valueOf * $s, 0); }
  elsif (defined(my $fil = $self->readKeyword('filll', 'fill', 'fil'))) {
    return (fixpoint($s * $f), $FILLS{$fil}); }
  else {
    my $u = ($mu ? $self->readMuUnit : $self->readUnit);
    if (!defined $u) {
      Warn('expected', '<unit>', $self,
        "Illegal unit of measure (" . ($mu ? 'mu' : 'pt') . " inserted)."); }
    return (fixpoint($s * $f, $u), 0); } }

# Return a glue value or undef.
sub readInternalGlue {
  my ($self) = @_;
  return $self->readRegisterValue('Glue'); }

#======================================================================
# Mu Glue
#======================================================================
# <muglue> = <optional signs><internal muglue> | <mudimen><mustretch><mushrink>
# <mustretch> = plus <mudimen> | plus <fil dimen> | <optional spaces>
# <mushrink> = minus <mudimen> | minus <fil dimen> | <optional spaces>
sub readMuGlue {
  my ($self) = @_;
  my $s = $self->readOptionalSigns;
  my $n;
  if (defined($n = $self->readInternalMuGlue)) {
    return ($s < 0 ? $n->negate : $n); }
  else {
    my $d = $self->readMuDimension;
    if (!$d) {
      Warn('expected', '<number>', $self, "Missing number (MuGlue), treated as zero.",
        "while processing " . ToString($LaTeXML::CURRENT_TOKEN), $self->showUnexpected);
      return MuGlue(0); }
    $d = $d->negate if $s < 0;
    my ($r1, $f1, $r2, $f2);
    ($r1, $f1) = $self->readRubber(1) if $self->readKeyword('plus');
    ($r2, $f2) = $self->readRubber(1) if $self->readKeyword('minus');
    return MuGlue($d->valueOf, $r1, $f1, $r2, $f2); } }

# Return a muglue value or undef.
sub readInternalMuGlue {
  my ($self) = @_;
  return $self->readRegisterValue('MuGlue'); }

#======================================================================
# See pp 272-275 for lists of the various registers.
# These are implemented in Primitive.pm

#**********************************************************************
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

=item C<< $tokens = $gullet->expandTokens($tokens); >>

Return the L<LaTeXML::Core::Tokens> resulting from expanding all the tokens in C<$tokens>.
This is actually only used in a few circumstances where the arguments to
an expandable need explicit expansion; usually expansion happens at the right time.

=item C<< $token = $gullet->readToken; >>

Return the next token from the input source, or undef if there is no more input.

=item C<< $token = $gullet->readXToken($toplevel,$commentsok); >>

Return the next unexpandable token from the input source, or undef if there is no more input.
If the next token is expandable, it is expanded, and its expansion is reinserted into the input.
If C<$commentsok>, a comment read or pending will be returned.

=item C<< $gullet->unread(@tokens); >>

Push the C<@tokens> back into the input stream to be re-read.

=back

=head2 Mid-level methods

=over 4

=item C<< $token = $gullet->readNonSpace; >>

Read and return the next non-space token from the input after discarding any spaces.

=item C<< $gullet->skipSpaces; >>

Skip the next spaces from the input.

=item C<< $gullet->skip1Space($expanded); >>

Skip the next token from the input if it is a space.
If C($expanded> is true, expands ( like C< <one optional space> > ).

=item C<< $tokens = $gullet->readBalanced; >>

Read a sequence of tokens from the input until the balancing '}' (assuming the '{' has
already been read). Returns a L<LaTeXML::Core::Tokens>,
except in an array context, returns the collected tokens and the closing token.

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

=item C<< $tokens = $gullet->readArg; >>

Read and return a TeX argument; the next Token or Tokens (if surrounded by braces).

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
