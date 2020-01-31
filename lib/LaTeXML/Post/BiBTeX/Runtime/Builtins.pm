# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Runtime::Builtin                            | #
# | BibTeX builtin functions                                            | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #
package LaTeXML::Post::BiBTeX::Runtime::Builtins;
use strict;
use warnings;

use LaTeXML::Post::BiBTeX::Runtime::Utils;
use LaTeXML::Post::BiBTeX::Runtime::Strings;
use LaTeXML::Post::BiBTeX::Runtime::Names;

use base qw(Exporter);
our @EXPORT = qw(
  &builtinZg &builtinZl &builtinZe &builtinZp &builtinZm &builtinZa
  &builtinZcZe &builtinAddPeriod &builtinCallType &builtinChangeCase
  &builtinChrToInt &builtinCite &builtinDuplicate &builtinEmpty
  &builtinFormatName &builtinIf &builtinIntToChr &builtinIntToStr
  &builtinMissing &builtinNewline &builtinNumNames &builtinPop
  &builtinPreamble &builtinPurify &builtinQuote &builtinSkip
  &builtinStack &builtinSubstring &builtinSwap &builtinTextLength
  &builtinTextPrefix &builtinTop &builtinType &builtinWarning
  &builtinWhile &builtinWidth &builtinWrite
);

# builtin function >
# pops two integers from the stack, then pushes 1 if the the latter is bigger than
# the former, 0 otherwise.
# If either stack entry is not an integer literal, loudly pushes 0 on the stack.
sub builtinZg {
  my ($context, $config, $source) = @_;
  my ($i1tp, $i1) = popType($context, $config, 'INTEGER', undef, $source);
  unless (defined($i1tp)) {
    $context->pushInteger(0);
    return; }
  my ($i2tp, $i2) = popType($context, $config, 'INTEGER', undef, $source);
  unless (defined($i2tp)) {
    $context->pushInteger(0);
    return 0; }
  $context->pushInteger($i2 > $i1 ? 1 : 0); }

# builtin function <
# pops two integers from the stack, then pushes 1 if the the latter is smaller than
# the former, 0 otherwise.
# If either stack entry is not an integer literal, loudly pushes 0 on the stack.
sub builtinZl {
  my ($context, $config, $source) = @_;
  my ($i1tp, $i1) = popType($context, $config, 'INTEGER', undef, $source);
  unless (defined($i1tp)) {
    $context->pushInteger(0);
    return; }
  my ($i2tp, $i2) = popType($context, $config, 'INTEGER', undef, $source);
  unless (defined($i2tp)) {
    $context->pushInteger(0);
    return 0; }
  $context->pushInteger($i2 < $i1 ? 1 : 0); }

# builtin function =
# pops two strings or two integers from the stack. Then pushes 1 if they are equal, 0 if not.
# If either of the types don't match, loudly pushes 0 on the stack.
sub builtinZe {
  my ($context, $config, $source) = @_;
  my ($tp, $value) = $context->popStack;
  unless (defined($tp)) {
    $config->log(
      'WARN',
      "Unable to pop empty stack",
      $config->location($source)
    );
    $context->pushInteger(0); }
  if ($tp eq 'INTEGER') {
    my $i1 = $value;
    my ($i2tp, $i2) =
      popType($context, $config, 'INTEGER', undef, $source);
    unless (defined($i2tp)) {
      $context->pushInteger(0);
      return; }
    $context->pushInteger($i1 == $i2 ? 1 : 0); }
  elsif ($tp eq 'STRING') {
    my ($s1) = simplifyString($value);
    my ($s2tp, $s2) =
      popType($context, $config, 'STRING', undef, $source);
    unless (defined($s2tp)) {
      $context->pushInteger(0);
      return; }
    ($s2) = simplifyString($s2);
    $context->pushInteger($s1 eq $s2 ? 1 : 0); }
  else {
    $config->log(
      'WARN',
      'Expected to find a STRING or an INTEGER on the stack. ',
      $config->location($source)
    );
    $context->pushInteger(0); } }

# builtin function +
# pops two integer literals from the stack, and then pushes their sum.
# If either isn't an integer, loudly pushes a 0.
sub builtinZp {
  my ($context, $config, $source) = @_;
  my ($i1tp, $i1) = popType($context, $config, 'INTEGER', undef, $source);
  unless (defined($i1tp)) {
    $context->pushInteger(0);
    return; }
  my ($i2tp, $i2) = popType($context, $config, 'INTEGER', undef, $source);
  unless (defined($i2tp)) {
    $context->pushInteger(0);
    return; }
  $context->pushInteger($i2 + $i1); }

# builtin function -
# pops two integer literals from the stack, and then pushes their difference.
# If either isn't an integer, loudly pushes a 0.
sub builtinZm {
  my ($context, $config, $source) = @_;
  my ($i1tp, $i1) = popType($context, $config, 'INTEGER', undef, $source);
  unless (defined($i1tp)) {
    $context->pushInteger(0);
    return; }
  my ($i2tp, $i2) = popType($context, $config, 'INTEGER', undef, $source);
  unless (defined($i2tp)) {
    $context->pushInteger(0);
    return; }
  $context->pushInteger($i2 - $i1); }

# builtin function *
# pops two string literals from the stack and pushes their concatination
# If either isn't an string, loudly pushes the empty string.
sub builtinZa {
  my ($context, $config, $source) = @_;
  my ($s1tp, $s1, $ss1) =
    popType($context, $config, 'STRING', undef, $source);
  unless (defined($s1tp)) {
    $context->pushString("");
    return; }
  my ($s2tp, $s2, $ss2) =
    popType($context, $config, 'STRING', undef, $source);
  unless (defined($s2tp)) {
    $context->pushString("");
    return; }
  my ($ns, $nss) = concatString($s2, $ss2, $s1, $ss1);
  $context->pushStack('STRING', $ns, $nss); }

# builtin function :=
# pops a function literal from the stack, and then a value of the appropriate type.
# finally assigns the literal to that value.
# complains when there is a type mismatch
# 0 if ok, 1 if it doesn't exist,  2 if an invalid context, 3 if read-only, 4 if unknown type
sub builtinZcZe {
  my ($context, $config, $source) = @_;
  # pop the variable type and name to be assigned
  my ($rtp, $rv) =
    popType($context, $config, 'REFERENCE', undef, $source);
  return unless defined($rtp);
  my ($rvt, $name) = @$rv;
  # pop the value to assign
  my ($t, $v, $s) = $context->popStack;
  return $config->log(
    'WARN',
    'Attempted to pop the empty stack',
    $config->location($source)
  ) unless defined($t);
  # and do it!
  my $asr = $context->setVariable($name, [$t, $v, $s]);
  if ($asr eq 1) {
    $config->log(
      'WARN',
      "Can not set $name: Does not exist. ",
      $config->location($source)
      ); }
  elsif ($asr eq 2) {
    $config->log(
      'WARN',
      "Can not set $name: Not in an entry context. ",
      $config->location($source)
      ); }
  elsif ($asr eq 4) {
    $config->log(
      'WARN',
      "Can not set $name: Read-only. ",
      $config->location($source)
      ); }
  elsif ($asr eq 4) {
    $config->log(
      'WARN',
      "Can not set $name: Unknown type. ",
      $config->location($source)
      ); } }

# builtin function add.period$
# pops a string from the stack and adds a period to it when it does not already end with a
# '.', '!' or '?'.
# when there isn't a string literal, it loudly pushes the empty string
sub builtinAddPeriod {
  my ($context, $config, $source) = @_;
  my ($type, $strings, $sources) =
    popType($context, $config, 'STRING', undef, $source);
  unless (defined($type)) {
    $context->pushString("");
    return; }
  my ($newStrings, $newSources) =
    applyPatch($strings, $sources, \&addPeriod, 'inplace');
  $context->pushStack('STRING', $newStrings, $newSources); }

# builtin function call.type$
sub builtinCallType {
  my ($context, $config, $source) = @_;
  my $entry = $context->getEntry;
  unless ($entry) {
    $config->log(
      'WARN',
      'Can not call.type$: No active entry. ',
      $config->location($source)
    );
    return; }
  my $tp = $entry->getType;
  my ($ftype, $value) = $context->getVariable($tp);
  unless (defined($ftype) && $ftype eq 'FUNCTION') {
    ($ftype, $value) = $context->getVariable("default.type");
    unless (defined($ftype) && $ftype eq 'FUNCTION') {
      $config->log(
        'WARN',
        'Can not call.type$: Unknown entrytype '
          . $tp
          . ' and no default handler has been defined. ',
        $config->location($source)
      );
      return; } }
  # call the type function
  &{$value}($context, $config); }

# builtin function change.case$
# pops two string literals from the stack and formats the first according to the second.
# when either is not a string literal, loudly pushes the empty string.
sub builtinChangeCase {
  my ($context, $config, $source) = @_;
  # get the case string and simplify it to be a single character
  my ($ctp, $cstrings, $csources) =
    popType($context, $config, 'STRING', undef, $source);
  unless (defined($ctp)) {
    $context->pushString("");
    return; }
  my ($spec) = simplifyString($cstrings, $csources);
  # pop the final string
  my ($stype, $strings, $sources) =
    popType($context, $config, 'STRING', undef, $source);
  unless (defined($stype)) {
    $context->pushString("");
    return; }
  # add the text prefix and push it to the stack
  my ($newStrings, $newSources) = applyPatch(
    $strings, $sources,
    sub {
      my $result = changeCase('' . $_[0], $spec);
      unless (defined($result)) {
        $config->log(
          'WARN',
          'Can not change.case$: Unknown format string'
            . $spec,
          $config->location($source)
        );
        return '' . $_[0];
      }
      return $result;
    },
    'inplace'
  );
  $context->pushStack('STRING', $newStrings, $newSources); }

# builtin function chr.to.int$
# pops the top string literal, and push the integer corresponding to it's ascii value.
# if the top literal is not a string, or the string is not of length 1, loudly pushes a 0 on the stack.
sub builtinChrToInt {
  my ($context, $config, $source) = @_;
  my ($type, $strings, $sources) =
    popType($context, $config, 'STRING', undef, $source);
  # if we have a string, that's ok.
  if (defined($type)) {
    my ($str, $src) = simplifyString($strings, $sources);
    if (length($str) eq 1) {
      $context->pushStack('INTEGER', ord($str), $src); }
    else {
      $config->log(
        'WARN',
        'Expected a single character string on the stack, but got '
          . length($str)
          . ' characters. ',
        $config->location($source)
      );
      $context->pushInteger(0); } }
  else {
    $context->pushInteger(0); } }

# builtin function cite$
# pushes the key of the current entry or complains if there is none
sub builtinCite {
  my ($context, $config, $source) = @_;
  my $entry = $context->getEntry;
  unless ($entry) {
    $config->log(
      'WARN',
      'Can not push the entry key: No active entry. ',
      $config->location($source)
    );
    return; }
  $context->pushStack(
    'STRING',
    [$entry->getKey],
    [[$entry->getName, $entry->getKey, '']]
    ); }

# builtin function duplicate$
# duplicates the topmost stack entry, or complains if there is none.
sub builtinDuplicate {
  my ($context, $config, $source) = @_;
  $config->log(
    'WARN',
    'Attempted to duplicate the empty stack',
    $config->location($source)
    ) unless $context->duplicateStack; }

# builtin function empty$
# pops the top literal from the stack.
# It then pushes a 0 if it is a whitespace-only string or a missing value.
# If pushes a 1 if it is a string that contains non-whitespace charaters.
# Otherwise, it complains and pushes the integer 0.
sub builtinEmpty {
  my ($context, $config, $source) = @_;
  my ($tp, $value) = $context->popStack;
  return $config->log(
    'WARN',
    'Attempted to pop the empty stack',
    $config->location($source)
  ) unless defined($tp);
  if ($tp eq 'MISSING') {
    $context->pushInteger(1); }
  elsif ($tp eq 'STRING') {
    ($value) = simplifyString($value);
    $context->pushInteger(($value =~ /^\s*$/) ? 1 : 0); }
  else {
    $config->log(
      'WARN',
      'empty$ expects a string or missing field on the stack',
      $config->location($source)
    );
    $context->pushInteger(0); } }

# builtin function format.name$
# Pops a string, an integer, and a string (in that order) from the stack
# It then formats the nth name of the first string according to the specification of the latter.
# If either type does not match, it pushes the empty string.
sub builtinFormatName {
  my ($context, $config, $source) = @_;
  # get the format string
  my ($ftp, $fstrings) =
    popType($context, $config, 'STRING', undef, $source);
  unless ($ftp) {
    $context->pushString("");
    return; }
  ($fstrings) = simplifyString($fstrings);
  # get the length
  my ($itp, $integer, $isource) =
    popType($context, $config, 'INTEGER', undef, $source);
  unless ($itp) {
    $context->pushString("");
    return; }
  # pop the final name string
  my ($stype, $strings, $sources) =
    popType($context, $config, 'STRING', undef, $source);
  unless (defined($stype)) {
    $context->pushString("");
    return; }

  # add the text prefix and push it to the stack
  my ($newStrings, $newSources) = applyPatch(
    $strings, $sources,
    sub {
      my @names = splitNames($_[0] . '');
      my $name = $names[$integer - 1] || '';    # TODO: Warn if missing
      my ($fname, $error) = formatName("$name", $fstrings);
      $config->log(
        'WARN',
        "Unable to format name: $error",
        $config->location($source)
      ) if defined($error);
      return defined($fname) ? $fname : '';
    },
    0
  );
  $context->pushStack('STRING', $newStrings, $newSources); }

# builtin function if$
# pops two function literals and an integer literal from the stack.
# it then executes the first literal if the integer is > 0, otherwise the second.
# if either type mismatches, complains but does not attempt to recover.
sub builtinIf {
  my ($context, $config, $source) = @_;
  my ($f1type, $f1) = popFunction($context, $config, $source);
  return unless defined($f1type);
  my ($f2type, $f2) = popFunction($context, $config, $source);
  return unless defined($f2type);

  my ($itype, $integer) =
    popType($context, $config, 'INTEGER', undef, $source);
  return unless defined($itype);

  if ($integer > 0) {
    &{$f2}($context, $config); }
  else {
    &{$f1}($context, $config); } }

# builtin function int.to.chr$
# pops an integer literal from the stack, and pushes the corresponding ASCII character.
# when the stack does not contain an integer, complains and pushes the null string.
sub builtinIntToChr {
  my ($context, $config, $source) = @_;
  my ($type, $integer, $isource) =
    popType($context, $config, 'INTEGER', undef, $source);
  unless (defined($type)) {
    $context->pushString("");
    return; }
  $context->pushStack('STRING', [chr($integer)], [$isource]); }

# builtin function int.to.str$
# pops an integer literal from the stack, and pushes the corresponding string value.
# when the stack does not contain an integer, complains and pushes the null string.
sub builtinIntToStr {
  my ($context, $config, $source) = @_;
  my ($type, $integer, $isource) =
    popType($context, $config, 'INTEGER', undef, $source);
  unless (defined($type)) {
    $context->pushString("");
    return; }
  $context->pushStack('STRING', ["$integer"], [$isource]); }

# builtin function missing$
# pops the top literal from the stack, and pushes the integer 1 if it is a missing field, 0 otherwise.
sub builtinMissing {
  my ($context, $config, $source) = @_;
  my ($tp) = $context->popStack;
  unless (defined($tp)) {
    $config->log(
      'WARN',
      "Unable to pop empty stack",
      $config->location($source)
    );
    return; }
  $context->pushInteger(($tp eq 'MISSING') ? 1 : 0); }

# builtin function newline$
# sends the current content of the output buffer and a newline to the output.
sub builtinNewline {
  my ($context, $config, $source) = @_;
  $config->getBuffer->writeLn; }

# builtin function num.names$
# pops a string literal from the stack, and then counts the number of names in it
# when the top literal is not a string, loudly pushes the number 0.
sub builtinNumNames {
  my ($context, $config, $source) = @_;
  my ($type, $strings, $sources) =
    popType($context, $config, 'STRING', undef, $source);
  unless (defined($type)) {
    $context->pushInteger(0);
    return; }

  # if we have a string, that's ok.
  if (defined($type)) {
    my ($str, $src) = simplifyString($strings, $sources);
    $context->pushStack('INTEGER', numNames($str), [$src]); } }

# builtin function pop$
# pops the top literal from the stack and does nothing
sub builtinPop {
  my ($context, $config, $source) = @_;
  my ($tp) = $context->popStack;
  unless (defined($tp)) {
    $config->log(
      'WARN',
      "Unable to pop empty stack",
      $config->location($source)
      ); } }

# builtin function preamble$
# pushes the concatination of all preambles onto the stack
sub builtinPreamble {
  my ($context, $config, $source) = @_;
  my ($strings, $sources) = $context->getPreamble;
  $context->pushStack('STRING', $strings, $sources); }

# builtin function purify$
# pops a string from the stack, purifies it, and then pushes it.
# when the top literal is not a string, loudly pushes the empty string.
sub builtinPurify {
  my ($context, $config, $source) = @_;
  my ($type, $strings, $sources) =
    popType($context, $config, 'STRING', undef, $source);
  unless (defined($type)) {
    $context->pushString("");
    return; }
  my ($newStrings, $newSources) =
    applyPatch($strings, $sources, \&textPurify, 'inplace');
  $context->pushStack('STRING', $newStrings, $newSources); }

# builtin function quote$
# push the string containing only a double quote onto the stack
sub builtinQuote {
  my ($context, $config, $source) = @_;
  $context->pushString("\""); }

# builtin function skip$
# does nothing
sub builtinSkip { return; }

# builtin function stack$
# pops and prints the contents of the stack for debugging purposes
sub builtinStack {
  my ($context, $config, $source) = @_;
  my ($tp,      $value,  $src)    = $context->popStack;
  while (defined($tp)) {
    $config->log('DEBUG', fmtType($tp, $value, $src));
    ($tp, $value, $src) = $context->popStack; } }

# builtin function substring$
# popts two integers and a string, then pushes the substring consisting of the appropriate position and length.
# When any of the types are incorrect, loudly pushes the empty string
sub builtinSubstring {
  my ($context, $config, $source) = @_;
  # pop the first integer
  my ($i1t, $i1, $i1source) =
    popType($context, $config, 'INTEGER', undef, $source);
  unless (defined($i1t)) {
    $context->pushString("");
    return; }
  # pop the second integer
  my ($i2t, $i2, $i2source) =
    popType($context, $config, 'INTEGER', undef, $source);
  unless (defined($i2t)) {
    $context->pushString("");
    return; }
  # pop the string
  my ($stype, $strings, $sources) =
    popType($context, $config, 'STRING', undef, $source);
  unless (defined($stype)) {
    $context->pushString("");
    return; }

  # add the text prefix and push it to the stack
  my ($newStrings, $newSources) = applyPatch(
    $strings, $sources,
    sub {
      return textSubstring($_[0] . '', $i2, $i1);
    },
    'inplace'
  );
  $context->pushStack('STRING', $newStrings, $newSources); }

# builtin function swap$
# pops two literals from the stack, and pushes them back swapped.
sub builtinSwap {
  my ($context, $config, $source) = @_;
  $config->log(
    'WARN',
    'Need at least two elements on the stack to swap. ',
    $config->location($source)
    ) unless $context->swapStack; }

# builtin function text.length$
# pops a string from the top of the stack, and then pushes it's length.
# When the top literal is not a string, loudly pushes the empty string.
sub builtinTextLength {
  my ($context, $config, $source) = @_;
  my ($type, $strings, $sources) =
    popType($context, $config, 'STRING', undef, $source);
  unless (defined($type)) {
    $context->pushString("");
    return;
  }
  my ($str, $src) = simplifyString($strings, $sources);
  $context->pushStack('INTEGER', textLength($str), $src); }

# builtin function text.prefix$
# pops an integer and a string from the stack, then pushes the prefix of the given length of that string
# if either of the types don't match, loudly pushes the empty string.
sub builtinTextPrefix {
  my ($context, $config, $source) = @_;
  # pop the integer
  my ($itype, $integer, $isource) =
    popType($context, $config, 'INTEGER', undef, $source);
  unless (defined($itype)) {
    $context->pushString("");
    return; }
  # pop and simplify the string
  my ($stype, $strings, $sources) =
    popType($context, $config, 'STRING', undef, $source);
  unless (defined($stype)) {
    $context->pushString("");
    return; }
  # add the text prefix and push it to the stack
  my ($newStrings, $newSources) = applyPatch(
    $strings, $sources,
    sub {
      return textPrefix($_ . '', $integer, 'inplace');
      }
  );
  $context->pushStack('STRING', $newStrings, $newSources); }

# builtin function top$
# pops the topmost entry of the stack and prints it for debugging purposes
sub builtinTop {
  my ($context, $config, $source) = @_;
  my ($tp,      $value,  $src)    = $context->popStack;
  if (defined($tp)) {
    $config->log('DEBUG', fmtType($tp, $value, $src)); }
  else {
    $config->log(
      'WARN',
      "Unable to pop empty stack",
      $config->location($source)
      ); } }

# builtin function type$
# pushes the type of the current entry onto the stack.
# If the string is empty or undefined, pushes the empty string.
sub builtinType {
  my ($context, $config, $source) = @_;
  my $entry = $context->getEntry;
  if ($entry) {
    my $tp = $entry->getType;
    $tp = '' unless $context->hasVariable($tp, 'FUNCTION');
    $context->pushStack('STRING', [$tp],
      [[$entry->getName, $entry->getKey]]); }
  else {
    $context->pushString(""); } }

# builtin function warning$
# pops the top-most string from the stack and send a warning to the user
sub builtinWarning {
  my ($context, $config, $source) = @_;
  my ($type, $strings, $sources) =
    popType($context, $config, 'STRING', undef, $source);
  return unless defined($type);

  my ($str, $src) = simplifyString($strings, $sources);
  $config->log('WARN', $str, $src);
}

# builtin function while$
# pops two function literals from the stack and keeps executing the second
# while the integer literal returned from the first is > 0.
# If any involved type is wrong, fails silently.
sub builtinWhile {
  my ($context, $config, $source) = @_;
  my ($f1type, $f1) = popFunction($context, $config, $source);
  return unless defined($f1type);
  my ($f2type, $f2) = popFunction($context, $config, $source);
  return unless defined($f2type);
  while (1) {
    &{$f2}($context, $config, $source);

    my ($itype, $integer) =
      popType($context, $config, 'INTEGER', undef, $source);
    return unless defined($itype);

    return unless ($integer > 0);
    &{$f1}($context, $config, $source); }

}

# builtin function width$
# pops a string from the stack and computes it's width in units.
# when the stack does not contain a string, loudly pushes 0.
sub builtinWidth {
  my ($context, $config, $source) = @_;
  my ($type, $strings, $sources) =
    popType($context, $config, 'STRING', undef, $source);
  unless (defined($type)) {
    $context->pushInteger(0);
    return; }
  my ($str, $src) = simplifyString($strings, $sources);
  $context->pushStack('INTEGER', textWidth($str), $src); }

# builtin function write$
# writes a string to the output buffer (and potentially writes
# to the output iff it is long enugh)
sub builtinWrite {
  my ($context, $config, $source) = @_;
  my ($type, $strings, $sources) =
    popType($context, $config, 'STRING', undef, $source);
  return unless defined($type);
  # get the ouput buffer and array references to sources and strings
  my $buffer     = $config->getBuffer;
  my @theStrings = @{$strings};
  my @theSources = @{$sources};
  # we iterate by index to not mutate strings and sources
  my ($i);
  for $i (0 .. $#theStrings) {
    $buffer->write($theStrings[$i], $theSources[$i]); } }

1;
