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
  my ($class) = @_;
  return bless {
    mouth => undef, mouthstack => [], pushback => [], autoclose => 1, pending_comments => []
    }, $class; }

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
    $$self{pushback} = [];
##    $$self{mouth}=Tokens();
    $$self{mouth} = LaTeXML::Core::Mouth->new();
####    $$self{mouth}=undef;
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
# Corresponds (I think) to TeX's \endinput
sub flushMouth {
  my ($self) = @_;
  $$self{mouth}->finish;;    # but not close!
  $$self{pushback}  = [];    # And don't read anytyhing more from it.
  $$self{autoclose} = 1;
  return; }

# Obscure, but the only way I can think of to End!! (see \bye or \end{document})
# Flush all sources (close all pending mouth's)
sub flush {
  my ($self) = @_;
  $$self{mouth}->finish;
  while (@{ $$self{mouthstack} }) {
    my $entry = shift @{ $$self{mouthstack} };
    $$entry[0]->finish; }
  $$self{pushback} = [];
##  $$self{mouth}=Tokens();
  $$self{mouth} = LaTeXML::Core::Mouth->new();
####    $$self{mouth}=undef;
  $$self{autoclose}  = 1;
  $$self{mouthstack} = [];
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
        "Reading from " . Stringify($mouth) . ", but it has already been closed."); }
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
  my ($self, $long) = @_;
  my $mouth = $$self{mouth};
  my $i     = 0;
  while ((defined $mouth) && (($$mouth{source} || '') eq 'Anonymous String')
    && ($i < scalar(@{ $$self{mouthstack} }))) {
    $mouth = $$self{mouthstack}[$i++][0]; }
  my $loc = (defined $mouth ? $mouth->getLocator($long) : '');
  if (!$loc || $long) {
    $loc .= show_pushback($$self{pushback}) if $long;
    foreach my $frame (@{ $$self{mouthstack} }) {
      my $ml = $$frame[0]->getLocator($long);
      $loc .= ' ' . $ml if $ml;
      last if $loc && !$long;
      $loc .= show_pushback($$frame[1]) if $long; } }
  return $loc; }

sub getSource {
  my ($self) = @_;
  my $source = defined $$self{mouth} && $$self{mouth}->getSource;
  if (!$source) {
    foreach my $frame (@{ $$self{mouthstack} }) {
      $source = $$frame[0]->getSource;
      last if $source; } }
  return $source; }

sub getSourceMouth {
  my ($self) = @_;
  my $mouth = $$self{mouth};
  my $source = defined $mouth && $mouth->getSource;
  if (!$source || ($source eq "Anonymous String")) {
    foreach my $frame (@{ $$self{mouthstack} }) {
      $mouth  = $$frame[0];
      $source = $mouth->getSource;
      last if $source && $source ne "Anonymous String"; } }
  return $mouth; }

# Handy message generator when we didn't get something expected.
sub showUnexpected {
  my ($self) = @_;
  my $token = $self->readToken;
  my $message = ($token ? "Next token is " . Stringify($token) : "Input is empty");
  $self->unread($token);
  return $message; }

sub show_pushback {
  my ($pb) = @_;
  my @pb = @$pb;
  @pb = (@pb[0 .. 50], T_OTHER('...')) if scalar(@pb) > 55;
  return (@pb ? "\n  To be read again " . ToString(Tokens(@pb)) : ''); }

#**********************************************************************
# Not really 100% sure how this is supposed to work
# See TeX Ch 20, p216 regarding noexpand, \edef with token list registers, etc.
# Solution: Duplicate param tokens, stick NOTEXPANDED infront of expandable tokens.
sub neutralizeTokens {
  my ($self, @tokens) = @_;
  my @result = ();
  foreach my $token (@tokens) {
    if ($$token[1] == CC_PARAM) {    # Inline ->getCatcode!
      push(@result, $token); }
    elsif (defined(my $defn = $STATE->lookupDefinition($token))) {
      push(@result, Token('\noexpand', CC_NOTEXPANDED)); }
    push(@result, $token); }
  return @result; }

#**********************************************************************
# Low-level readers: read token, read expanded token
#**********************************************************************
# Note that every char (token) comes through here (maybe even twice, through args parsing),
# So, be Fast & Clean!  This method only reads from the current input stream (Mouth).
sub readToken {
  my ($self) = @_;
  #  my $token = shift(@{$$self{pushback}});
  my $token;
  my $cc;
  # Check in pushback first....
  while (defined($token = shift(@{ $$self{pushback} }))
    && ($cc = $$token[1])
    && (($cc == CC_COMMENT) || ($cc == CC_MARKER))) {    # NOTE: Inlined
    if ($cc == CC_COMMENT) {
      push(@{ $$self{pending_comments} }, $token); }
    elsif ($cc == CC_MARKER) {
      LaTeXML::Core::Definition::stopProfiling($token); } }
  return $token if defined $token;
  while (defined($token = $$self{mouth}->readToken())
    && ($cc = $$token[1])
    && (($cc == CC_COMMENT) || ($cc == CC_MARKER))) {    # NOTE: Inlined
    if ($cc == CC_COMMENT) {
      push(@{ $$self{pending_comments} }, $token); }     # What to do with comments???
    elsif ($cc == CC_MARKER) {
      LaTeXML::Core::Definition::stopProfiling($token); } }
  return $token; }

# Unread tokens are assumed to be not-yet expanded.
sub unread {
  my ($self, @tokens) = @_;
  my $r;
  unshift(@{ $$self{pushback} },
    map { (!defined $_ ? ()
        : (($r = ref $_) eq 'LaTeXML::Core::Token' ? $_
          : ($r eq 'LaTeXML::Core::Tokens' ? @$_
            : Fatal('misdefined', $r, undef, "Expected a Token, got " . Stringify($_))))) }
      @tokens);
  return; }

# Read the next non-expandable token (expanding tokens until there's a non-expandable one).
# Note that most tokens pass through here, so be Fast & Clean! readToken is folded in.
# `Toplevel' processing, (if $toplevel is true), used at the toplevel processing by Stomach,
#  will step to the next input stream (Mouth) if one is available,
# If $commentsok is true, will also pass comments.
sub readXToken {
  my ($self, $toplevel, $commentsok) = @_;
  $toplevel = 1 unless defined $toplevel;
  return shift(@{ $$self{pending_comments} }) if $commentsok && @{ $$self{pending_comments} };
  my ($token, $cc, $defn);
  while (1) {
    if (!defined($token = (@{ $$self{pushback} } ? shift(@{ $$self{pushback} }) : $$self{mouth}->readToken()))) {
      return unless $$self{autoclose} && $toplevel && @{ $$self{mouthstack} };
      $self->closeMouth; }    # Next input stream.
    elsif (($cc = $$token[1]) == CC_NOTEXPANDED) {    # NOTE: Inlined ->getCatcode
          # Should only occur IMMEDIATELY after expanding \noexpand (by readXToken),
          # so this token should never leak out through an EXTERNAL call to readToken.
      return $self->readToken; }    # Just return the next token.
    elsif ($cc == CC_COMMENT) {
      return $token if $commentsok;
      push(@{ $$self{pending_comments} }, $token); }    # What to do with comments???
    elsif ($cc == CC_MARKER) {
      LaTeXML::Core::Definition::stopProfiling($token); }
    elsif (defined($defn = $STATE->lookupDefinition($token)) && $defn->isExpandable
      && ($toplevel || !$defn->isProtected)) { # is this the right logic here? don't expand unless digesting?
      local $LaTeXML::CURRENT_TOKEN = $token;
      my $t;
      # Do the check here, to be more forgiving and more informative
      my @expansion = map { (($t = ref $_) eq 'LaTeXML::Core::Token' ? $_
          : ($t eq 'LaTeXML::Core::Tokens' ? @$_
            : (Error('misdefined', $token, undef,
                "Expected a Token in expansion of " . ToString($token),
                "got " . Stringify($_)), ()))) }
        $defn->invoke($self);
      # already checked tokens, so just push to be re-read (like ->unread(@expansion); )
      unshift(@{ $$self{pushback} }, @expansion); }
    else {
      return $token; }    # just return it
  }
  return; }               # never get here.

# Read the next raw line (string);
# primarily to read from the Mouth, but keep any unread input!
sub readRawLine {
  my ($self) = @_;
  # If we've got unread tokens, they presumably should come before the Mouth's raw data
  # but we'll convert them back to string.
  my @tokens = @{ $$self{pushback} };
  my @markers = grep { $_->getCatcode == CC_MARKER } @tokens;
  if (@markers) {    # Whoops, profiling markers!
    @tokens = grep { $_->getCatcode != CC_MARKER } @tokens;            # Remove
    map { LaTeXML::Core::Definition::stopProfiling($_) } @markers; }
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
# The following higher-level parsing methods are built upon readToken & unread.
sub readNonSpace {
  my ($self) = @_;
  my $token;
  do { $token = $self->readToken();
  } while (defined $token && $$token[1] == CC_SPACE);    # Inline ->getCatcode!
  return $token; }

sub skipSpaces {
  my ($self) = @_;
  my $tok = $self->readNonSpace;
  $self->unread($tok) if defined $tok;
  return; }

sub skip1Space {
  my ($self) = @_;
  my $token = $self->readToken();
  $self->unread($token) if $token && ($$token[1] != CC_SPACE);    # Inline ->getCatcode!
  return; }

# <filler> = <optional spaces> | <filler>\relax<optional spaces>
sub skipFiller {
  my ($self) = @_;
  while (1) {
    my $tok = $self->readNonSpace;
    return unless defined $tok;
    # Should \foo work too (where \let\foo\relax) ??
    if ($tok->getString ne '\relax') { $self->unread($tok); return; }
  }
  return; }

# Read a sequence of tokens balanced in {}
# assuming the { has already been read.
# Returns a Tokens list of the balanced sequence, omitting the closing }
sub readBalanced {
  my ($self) = @_;
  my @tokens = ();
  my ($token, $level) = (undef, 1);
  while ($level && defined($token = $self->readToken())) {
    my $cc = $$token[1];    # Inline ->getCatcode!
    $level++ if $cc == CC_BEGIN;
    $level-- if $cc == CC_END;
    push(@tokens, $token) if $level; }
  return Tokens(@tokens); }

sub ifNext {
  my ($self, $token) = @_;
  if (my $tok = $self->readToken()) {
    $self->unread($tok);
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
        $self->unread($token) if $token; }
    }
    return $choice unless @tomatch;    # All matched!!!
    $self->unread(@matched);           # Put 'em back and try next!
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
      && (uc($tok->getString) eq $tomatch[0])) {
      shift(@tomatch); }
    return $keyword unless @tomatch;    # All matched!!!
    $self->unread(@matched);            # Put 'em back and try next!
  }
  return; }

# Return a (balanced) sequence tokens until a match against one of the Tokens in @delims.
# In list context, also returns the found delimiter.
sub readUntil {
  my ($self, @delims) = @_;
  my ($n, $found, @tokens) = (0);
  while (!defined($found = $self->readMatch(@delims))) {
    my $token = $self->readToken();    # Copy next token to args
    return unless defined $token;
    push(@tokens, $token);
    $n++;
    if ($$token[1] == CC_BEGIN) {      # And if it's a BEGIN, copy till balanced END
      push(@tokens, $self->readBalanced->unlist, T_END); } }
  # Notice that IFF the arg looks like {balanced}, the outer braces are stripped
  # so that delimited arguments behave more similarly to simple, undelimited arguments.
  if (($n == 1) && ($tokens[0][1] == CC_BEGIN)) {
    shift(@tokens); pop(@tokens); }
  return (wantarray ? (Tokens(@tokens), $found) : Tokens(@tokens)); }

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
    return $self->readBalanced; }
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
    $self->unread($tok);
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
  elsif ($type eq 'Token')     { return $self->readToken; }
  elsif ($type eq 'any')       { return $self->readArg; }
  else {
    Error('unexpected', $type, $self,
      "Gullet->readValue Didn't expect this type: $type");
    return; }
}

sub readRegisterValue {
  my ($self, $type) = @_;
  my $token = $self->readXToken(0);
  return unless defined $token;
  my $defn = $STATE->lookupDefinition($token);
  if ((defined $defn) && ($defn->isRegister eq $type)) {
    return $defn->valueOf($defn->readArguments($self)); }
  else {
    $self->unread($token);
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
      return $defn->valueOf($defn->readArguments($self)); }
    elsif ($defn->isExpandable) {
      $self->unread($defn->invoke($self));
      return $self->readTokensValue; }
    else {
      return $token; } }              # ?
  else {
    return $token; } }

#======================================================================
# some helpers...

# <optional signs> = <optional spaces> | <optional signs><plus or minus><optional spaces>
# return +1 or -1
sub readOptionalSigns {
  my ($self) = @_;
  my ($sign, $t) = ("+1", '');
  while (defined($t = $self->readXToken(0))
    && (($t->getString eq '+') || ($t->getString eq '-') || ($t->equals(T_SPACE)))) {
    $sign = -$sign if ($t->getString eq '-'); }
  $self->unread($t) if $t;
  return $sign; }

sub readDigits {
  my ($self, $range, $skip) = @_;
  my $string = '';
  my ($token, $digit);
  while (($token = $self->readXToken(0)) && (($digit = $token->getString) =~ /^[$range]$/)) {
    $string .= $digit; }
  $self->unread($token) if $token && !($skip && $$token[1] == CC_SPACE);    # Inline ->getCatcode!
  return $string; }

# <factor> = <normal integer> | <decimal constant>
# <decimal constant> = . | , | <digit><decimal constant> | <decimal constant><digit>
# Return a number (perl number)
sub readFactor {
  my ($self) = @_;
  my $string = $self->readDigits('0-9');
  my $token  = $self->readXToken(0);
  if ($token && $token->getString =~ /^[\.\,]$/) {
    $string .= '.' . $self->readDigits('0-9');
    $token = $self->readXToken(0); }
  if (length($string) > 0) {
    $self->unread($token) if $token && $$token[1] != CC_SPACE;    # Inline ->getCatcode!
    return $string; }
  else {
    $self->unread($token);
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
  if (defined(my $n = $self->readNormalInteger)) { return ($s < 0 ? $n->negate : $n); }
  elsif (defined($n = $self->readInternalDimension)) { return Number($s * $n->valueOf); }
  elsif (defined($n = $self->readInternalGlue))      { return Number($s * $n->valueOf); }
  else {
    my $next = $self->readToken();
    $self->unread($next);
    Warn('expected', '<number>', $self, "Missing number, treated as zero",
      "while processing " . ToString($LaTeXML::CURRENT_TOKEN),
      "next token is " . ToString($next));
    return Number(0); } }

# <normal integer> = <internal integer> | <integer constant>
#   | '<octal constant><one optional space> | "<hexadecimal constant><one optional space>
#   | `<character token><one optional space>
# Return a Number or undef
sub readNormalInteger {
  my ($self) = @_;
  my $token = $self->readXToken(0);
  if (!defined $token) {
    return; }
  elsif (($$token[1] == CC_OTHER) && ($token->getString =~ /^[0-9]$/)) {    # Read decimal literal
    return Number(int($token->getString . $self->readDigits('0-9', 1))); }
  elsif ($token->equals(T_OTHER("\'"))) {                                   # Read Octal literal
    return Number(oct($self->readDigits('0-7', 1))); }
  elsif ($token->equals(T_OTHER("\""))) {                                   # Read Hex literal
    return Number(hex($self->readDigits('0-9A-F', 1))); }
  elsif ($token->equals(T_OTHER("\`"))) {                                   # Read Charcode
    my $s = $self->readToken->getString;
    $s =~ s/^\\//;
    return Number(ord($s)); }    # Only a character token!!! NOT expanded!!!!
  else {
    $self->unread($token);
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
  my $token  = $self->readXToken(0);
  if ($token && $token->getString =~ /^[\.]$/) {
    $string .= '.' . $self->readDigits('0-9');
    $token = $self->readXToken(0); }
  my $n;
  if (length($string) > 0) {
    $self->unread($token) if $token && $$token[1] != CC_SPACE;    # Inline ->getCatcode!
    $n = $string; }
  else {
    $self->unread($token) if $token;
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
    if (!defined $unit) {
      Warn('expected', '<unit>', $self, "Illegal unit of measure (pt inserted).");
      $unit = 65536; }
    return Dimension($s * $d * $unit); }
  else {
    Warn('expected', '<number>', $self, "Missing number, treated as zero.",
      "while processing " . ToString($LaTeXML::CURRENT_TOKEN));
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
    $self->skip1Space;
    return $STATE->convertUnit($u); }
  elsif (defined($u = $self->readInternalInteger)) {
    return $u->valueOf; }    # These are coerced to number=>sp
  elsif (defined($u = $self->readInternalDimension)) {
    return $u->valueOf; }
  elsif (defined($u = $self->readInternalGlue)) {
    return $u->valueOf; }
  else {
    $self->readKeyword('true');    # But ignore, we're not bothering with mag...
    $u = $self->readKeyword('pt', 'pc', 'in', 'bp', 'cm', 'mm', 'dd', 'cc', 'sp');
    if ($u) {
      $self->skip1Space;
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
      Warn('expected', '<unit>', $self, "Illegal unit of measure (mu inserted).");
      $munit = $STATE->convertUnit('mu'); }
    return MuDimension($s * $m * $munit); }
  elsif (defined($m = $self->readInternalMuGlue)) {
    return MuDimension($s * $m->valueOf); }
  else {
    Warn('expected', '<mudimen>', $self, "Expecting mudimen; assuming 0");
    return MuDimension(0); } }

sub readMuUnit {
  my ($self) = @_;
  if (my $m = $self->readKeyword('mu')) {
    $self->skip1Space;
    return $STATE->convertUnit($m); }
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
      Warn('expected', '<number>', $self, "Missing number, treated as zero.",
        "while processing " . ToString($LaTeXML::CURRENT_TOKEN));
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
    return ($s * $f, $FILLS{$fil}); }
  elsif ($mu) {
    my $u = $self->readMuUnit;
    if (!defined $u) {
      Warn('expected', '<unit>', $self, "Illegal unit of measure (mu inserted).");
      $u = $STATE->convertUnit('mu'); }
    return ($s * $f * $u, 0); }
  else {
    my $u = $self->readUnit;
    if (!defined $u) {
      Warn('expected', '<unit>', $self, "Illegal unit of measure (pt inserted).");
      $u = 65536; }
    return ($s * $f * $u, 0); } }

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
      Warn('expected', '<number>', $self, "Missing number, treated as zero.",
        "while processing " . ToString($LaTeXML::CURRENT_TOKEN));
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

Returns a string describing the current location in the input stream.

=back

=head2 Low-level methods

=over 4

=item C<< $tokens = $gullet->expandTokens($tokens); >>

Return the L<LaTeXML::Core::Tokens> resulting from expanding all the tokens in C<$tokens>.
This is actually only used in a few circumstances where the arguments to
an expandable need explicit expansion; usually expansion happens at the right time.

=item C<< @tokens = $gullet->neutralizeTokens(@tokens); >>

Another unusual method: Used for things like \edef and token registers, to
inhibit further expansion of control sequences and proper spawning of register tokens.

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

=item C<< $gullet->skip1Space; >>

Skip the next token from the input if it is a space.

=item C<< $tokens = $gullet->readBalanced; >>

Read a sequence of tokens from the input until the balancing '}' (assuming the '{' has
already been read). Returns a L<LaTeXML::Core::Tokens>.

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

