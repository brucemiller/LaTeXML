# /=====================================================================\ #
# |  LaTeXML::BibTeX::Runtime::Builtin                                  | #
# | BibTeX builtin functions                                            | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #
package LaTeXML::BibTeX::Runtime::Builtins;
use strict;
use warnings;
use LaTeXML::Common::Error;

use LaTeXML::BibTeX::Runtime::Utils;
use LaTeXML::BibTeX::Runtime::Strings;
use LaTeXML::BibTeX::Runtime::Names;

sub install {
  my ($runtime) = @_;
  # define all the built-in functions
  $runtime->assignVariable('>',            'FUNCTION', ['FUNCTION', \&builtinZg,         undef]);
  $runtime->assignVariable('<',            'FUNCTION', ['FUNCTION', \&builtinZl,         undef]);
  $runtime->assignVariable('=',            'FUNCTION', ['FUNCTION', \&builtinZe,         undef]);
  $runtime->assignVariable('+',            'FUNCTION', ['FUNCTION', \&builtinZp,         undef]);
  $runtime->assignVariable('-',            'FUNCTION', ['FUNCTION', \&builtinZm,         undef]);
  $runtime->assignVariable('*',            'FUNCTION', ['FUNCTION', \&builtinZa,         undef]);
  $runtime->assignVariable(':=',           'FUNCTION', ['FUNCTION', \&builtinZcZe,       undef]);
  $runtime->assignVariable('add.period$',  'FUNCTION', ['FUNCTION', \&builtinAddPeriod,  undef]);
  $runtime->assignVariable('call.type$',   'FUNCTION', ['FUNCTION', \&builtinCallType,   undef]);
  $runtime->assignVariable('change.case$', 'FUNCTION', ['FUNCTION', \&builtinChangeCase, undef]);
  $runtime->assignVariable('chr.to.int$',  'FUNCTION', ['FUNCTION', \&builtinChrToInt,   undef]);
  $runtime->assignVariable('cite$',        'FUNCTION', ['FUNCTION', \&builtinCite,       undef]);
  $runtime->assignVariable('duplicate$',   'FUNCTION', ['FUNCTION', \&builtinDuplicate,  undef]);
  $runtime->assignVariable('empty$',       'FUNCTION', ['FUNCTION', \&builtinEmpty,      undef]);
  $runtime->assignVariable('format.name$', 'FUNCTION', ['FUNCTION', \&builtinFormatName, undef]);
  $runtime->assignVariable('if$',          'FUNCTION', ['FUNCTION', \&builtinIf,         undef]);
  $runtime->assignVariable('int.to.chr$',  'FUNCTION', ['FUNCTION', \&builtinIntToChr,   undef]);
  $runtime->assignVariable('int.to.str$',  'FUNCTION', ['FUNCTION', \&builtinIntToStr,   undef]);
  $runtime->assignVariable('missing$',     'FUNCTION', ['FUNCTION', \&builtinMissing,    undef]);
  $runtime->assignVariable('newline$',     'FUNCTION', ['FUNCTION', \&builtinNewline,    undef]);
  $runtime->assignVariable('num.names$',   'FUNCTION', ['FUNCTION', \&builtinNumNames,   undef]);
  $runtime->assignVariable('pop$',         'FUNCTION', ['FUNCTION', \&builtinPop,        undef]);
  $runtime->assignVariable('preamble$',    'FUNCTION', ['FUNCTION', \&builtinPreamble,   undef]);
  $runtime->assignVariable('purify$',      'FUNCTION', ['FUNCTION', \&builtinPurify,     undef]);
  $runtime->assignVariable('quote$',       'FUNCTION', ['FUNCTION', \&builtinQuote,      undef]);
  $runtime->assignVariable('skip$',        'FUNCTION', ['FUNCTION', \&builtinSkip,       undef]);
  $runtime->assignVariable('stack$',       'FUNCTION', ['FUNCTION', \&builtinStack,      undef]);
  $runtime->assignVariable('substring$',   'FUNCTION', ['FUNCTION', \&builtinSubstring,  undef]);
  $runtime->assignVariable('swap$',        'FUNCTION', ['FUNCTION', \&builtinSwap,       undef]);
  $runtime->assignVariable('text.length$', 'FUNCTION', ['FUNCTION', \&builtinTextLength, undef]);
  $runtime->assignVariable('text.prefix$', 'FUNCTION', ['FUNCTION', \&builtinTextPrefix, undef]);
  $runtime->assignVariable('top$',         'FUNCTION', ['FUNCTION', \&builtinTop,        undef]);
  $runtime->assignVariable('type$',        'FUNCTION', ['FUNCTION', \&builtinType,       undef]);
  $runtime->assignVariable('warning$',     'FUNCTION', ['FUNCTION', \&builtinWarning,    undef]);
  $runtime->assignVariable('while$',       'FUNCTION', ['FUNCTION', \&builtinWhile,      undef]);
  $runtime->assignVariable('width$',       'FUNCTION', ['FUNCTION', \&builtinWidth,      undef]);
  $runtime->assignVariable('write$',       'FUNCTION', ['FUNCTION', \&builtinWrite,      undef]);
  return; }

# builtin function >
# pops two integers from the stack, then pushes 1 if the the latter is bigger than
# the former, 0 otherwise.
# If either stack entry is not an integer literal, loudly pushes 0 on the stack.
sub builtinZg {
  my ($runtime, $instruction) = @_;
  my ($i1tp,    $i1)          = $runtime->popType('INTEGER', $instruction);
  unless (defined($i1tp)) {
    $runtime->pushInteger(0);
    return; }
  my ($i2tp, $i2) = $runtime->popType('INTEGER', $instruction);
  unless (defined($i2tp)) {
    $runtime->pushInteger(0);
    return 0; }
  $runtime->pushInteger($i2 > $i1 ? 1 : 0);
  return; }

# builtin function <
# pops two integers from the stack, then pushes 1 if the the latter is smaller than
# the former, 0 otherwise.
# If either stack entry is not an integer literal, loudly pushes 0 on the stack.
sub builtinZl {
  my ($runtime, $instruction) = @_;
  my ($i1tp,    $i1)          = $runtime->popType('INTEGER', $instruction);
  unless (defined($i1tp)) {
    $runtime->pushInteger(0);
    return; }
  my ($i2tp, $i2) = $runtime->popType('INTEGER', $instruction);
  unless (defined($i2tp)) {
    $runtime->pushInteger(0);
    return 0; }
  $runtime->pushInteger($i2 < $i1 ? 1 : 0);
  return; }

# builtin function =
# pops two strings or two integers from the stack. Then pushes 1 if they are equal, 0 if not.
# If either of the types don't match, loudly pushes 0 on the stack.
sub builtinZe {
  my ($runtime, $instruction) = @_;
  my ($tp,      $value)       = $runtime->popStack;
  unless (defined($tp)) {
    Warn('bibtex', 'runtime', $instruction->getLocator, "Unable to pop empty stack");
    $runtime->pushInteger(0); }
  if ($tp eq 'INTEGER') {
    my $i1 = $value;
    my ($i2tp, $i2) = $runtime->popType('INTEGER', $instruction);
    unless (defined($i2tp)) {
      $runtime->pushInteger(0);
      return; }
    $runtime->pushInteger($i1 == $i2 ? 1 : 0); }
  elsif ($tp eq 'STRING') {
    my ($s1) = simplifyString($value);
    my ($s2tp, $s2) = $runtime->popType('STRING', $instruction);
    unless (defined($s2tp)) {
      $runtime->pushInteger(0);
      return; }
    ($s2) = simplifyString($s2);
    $runtime->pushInteger($s1 eq $s2 ? 1 : 0); }
  else {
    Warn('bibtex', 'runtime', $instruction->getLocator,
      'Equals(=) expected to find a STRING or an INTEGER on the stack. ');
    $runtime->pushInteger(0); }
  return; }

# builtin function +
# pops two integer literals from the stack, and then pushes their sum.
# If either isn't an integer, loudly pushes a 0.
sub builtinZp {
  my ($runtime, $instruction) = @_;
  my ($i1tp,    $i1)          = $runtime->popType('INTEGER', $instruction);
  unless (defined($i1tp)) {
    $runtime->pushInteger(0);
    return; }
  my ($i2tp, $i2) = $runtime->popType('INTEGER', $instruction);
  unless (defined($i2tp)) {
    $runtime->pushInteger(0);
    return; }
  $runtime->pushInteger($i2 + $i1);
  return; }

# builtin function -
# pops two integer literals from the stack, and then pushes their difference.
# If either isn't an integer, loudly pushes a 0.
sub builtinZm {
  my ($runtime, $instruction) = @_;
  my ($i1tp,    $i1)          = $runtime->popType('INTEGER', $instruction);
  unless (defined($i1tp)) {
    $runtime->pushInteger(0);
    return; }
  my ($i2tp, $i2) = $runtime->popType('INTEGER', $instruction);
  unless (defined($i2tp)) {
    $runtime->pushInteger(0);
    return; }
  $runtime->pushInteger($i2 - $i1);
  return; }

# builtin function *
# pops two string literals from the stack and pushes their concatination
# If either isn't an string, loudly pushes the empty string.
sub builtinZa {
  my ($runtime, $instruction) = @_;
  my ($s1tp, $s1, $ss1) = $runtime->popType('STRING', $instruction);
  unless (defined($s1tp)) {
    $runtime->pushString("");
    return; }
  my ($s2tp, $s2, $ss2) = $runtime->popType('STRING', $instruction);
  unless (defined($s2tp)) {
    $runtime->pushString("");
    return; }
##  my ($ns, $nss) = concatString($s2, $ss2, $s1, $ss1);
  my ($ns, $nss) = concatString($s2, $ss2 || [''], $s1, $ss1 || ['']);
  $runtime->pushStack('STRING', $ns, $nss);
  return; }

# builtin function :=
# pops a function literal from the stack, and then a value of the appropriate type.
# finally assigns the literal to that value.
# complains when there is a type mismatch
# 0 if ok, 1 if it doesn't exist,  2 if an invalid context, 3 if read-only, 4 if unknown type
sub builtinZcZe {
  my ($runtime, $instruction) = @_;
  # pop the variable type and name to be assigned
  my ($rtp, $rv) = $runtime->popType('REFERENCE', $instruction);
  return unless defined($rtp);
  my ($rvt, $name) = @$rv;
  # pop the value to assign
  my ($t, $v, $s) = $runtime->popStack;
  return Warn('bibtex', 'runtime', $instruction->getLocator,
    'Attempted to pop the empty stack') unless defined($t);
  # and do it!
  my $asr = $runtime->setVariable($name, [$t, $v, $s]);
  if ($asr == 1) {
    Warn('bibtex', 'runtime', $instruction->getLocator,
      "Can not set $name: Does not exist."); }
  elsif ($asr == 2) {
    Warn('bibtex', 'runtime', $instruction->getLocator,
      "Can not set $name: Not in an entry context. "); }
  elsif ($asr == 4) {
    Warn('bibtex', 'runtime', $instruction->getLocator,
      "Can not set $name: Read-only. "); }
  elsif ($asr == 4) {
    Warn('bibtex', 'runtime', $instruction->getLocator,
      "Can not set $name: Unknown type. "); }
  return; }

# builtin function add.period$
# pops a string from the stack and adds a period to it when it does not already end with a
# '.', '!' or '?'.
# when there isn't a string literal, it loudly pushes the empty string
sub builtinAddPeriod {
  my ($runtime, $instruction) = @_;
  my ($type, $strings, $sources) = $runtime->popType('STRING', $instruction);
  unless (defined($type)) {
    $runtime->pushString("");
    return; }
  my ($newStrings, $newSources) = applyPatch($strings, $sources, \&addPeriod, 'inplace');
  $runtime->pushStack('STRING', $newStrings, $newSources);
  return; }

# builtin function call.type$
sub builtinCallType {
  my ($runtime, $instruction) = @_;
  my $entry = $runtime->getEntry;
  unless ($entry) {
    Warn('bibtex', 'runtime', $instruction->getLocator,
      'Can not call.type$: No active entry. ');
    return; }
  my $tp = $entry->getType;
  my ($ftype, $value) = $runtime->getVariable($tp);
  unless (defined($ftype) && $ftype eq 'FUNCTION') {
    ($ftype, $value) = $runtime->getVariable("default.type");
    unless (defined($ftype) && $ftype eq 'FUNCTION') {
      Warn('bibtex', 'runtime', $instruction->getLocator,
        'Can not call.type$: Unknown entrytype ' . $tp
          . ' and no default handler has been defined. ');
      return; } }
  # call the type function
  $runtime->executeFunction($instruction, $value);
  return; }

# builtin function change.case$
# pops two string literals from the stack and formats the first according to the second.
# when either is not a string literal, loudly pushes the empty string.
sub builtinChangeCase {
  my ($runtime, $instruction) = @_;
  # get the case string and simplify it to be a single character
  my ($ctp, $cstrings, $csources) = $runtime->popType('STRING', $instruction);
  unless (defined($ctp)) {
    $runtime->pushString("");
    return; }
  my ($spec) = simplifyString($cstrings, $csources);
  # pop the final string
  my ($stype, $strings, $sources) = $runtime->popType('STRING', $instruction);
  unless (defined($stype)) {
    $runtime->pushString("");
    return; }
  # add the text prefix and push it to the stack
  my ($newStrings, $newSources) = applyPatch(
    $strings, $sources,
    sub {
      my $result = changeCase('' . $_[0], $spec);
      unless (defined($result)) {
        Warn('bibtex', 'runtime', $instruction->getLocator,
          'Can not change.case$: Unknown format string' . $spec);
        return '' . $_[0]; }
      return $result; },
    'inplace'
  );
  $runtime->pushStack('STRING', $newStrings, $newSources);
  return; }

# builtin function chr.to.int$
# pops the top string literal, and push the integer corresponding to it's ascii value.
# if the top literal is not a string, or the string is not of length 1, loudly pushes a 0 on the stack.
sub builtinChrToInt {
  my ($runtime, $instruction) = @_;
  my ($type, $strings, $sources) = $runtime->popType('STRING', $instruction);
  # if we have a string, that's ok.
  if (defined($type)) {
    my ($str, $src) = simplifyString($strings, $sources);
    if (length($str) == 1) {
      $runtime->pushStack('INTEGER', ord($str), $src); }
    else {
      Warn('bibtex', 'runtime', $instruction->getLocator,
        'Expected a single character string on the stack, but got ' . length($str) . ' characters.');
      $runtime->pushInteger(0); } }
  else {
    $runtime->pushInteger(0); }
  return; }

# builtin function cite$
# pushes the key of the current entry or complains if there is none
sub builtinCite {
  my ($runtime, $instruction) = @_;
  my $entry = $runtime->getEntry;
  unless ($entry) {
    Warn('bibtex', 'runtime', $instruction->getLocator,
      'Can not push the entry key: No active entry.');
    return; }
  $runtime->pushStack(
    'STRING',
    [$entry->getKey],
    [[$entry->getName, $entry->getKey, '']]
  );
  return; }

# builtin function duplicate$
# duplicates the topmost stack entry, or complains if there is none.
sub builtinDuplicate {
  my ($runtime, $instruction) = @_;
  Warn('bibtex', 'runtime', $instruction->getLocator,
    'Attempted to duplicate the empty stack')
    unless $runtime->duplicateStack;
  return; }

# builtin function empty$
# pops the top literal from the stack.
# It then pushes a 0 if it is a whitespace-only string or a missing value.
# If pushes a 1 if it is a string that contains non-whitespace charaters.
# Otherwise, it complains and pushes the integer 0.
sub builtinEmpty {
  my ($runtime, $instruction) = @_;
  my ($tp,      $value)       = $runtime->popStack;
  return Warn('bibtex', 'runtime', $instruction->getLocator,
    'Attempted to pop the empty stack')
    unless defined($tp);
  if ($tp eq 'MISSING') {
    $runtime->pushInteger(1); }
  elsif ($tp eq 'STRING') {
    ($value) = simplifyString($value);
    $runtime->pushInteger(($value =~ /^\s*$/) ? 1 : 0); }
  else {
    Warn('bibtex', 'runtime', $instruction->getLocator,
      'empty$ expects a string or missing field on the stack');
    $runtime->pushInteger(0); }
  return; }

# builtin function format.name$
# Pops a string, an integer, and a string (in that order) from the stack
# It then formats the nth name of the first string according to the specification of the latter.
# If either type does not match, it pushes the empty string.
sub builtinFormatName {
  my ($runtime, $instruction) = @_;
  # get the format string
  my ($ftp, $fstrings) = $runtime->popType('STRING', $instruction);
  unless ($ftp) {
    $runtime->pushString("");
    return; }
  ($fstrings) = simplifyString($fstrings);
  # get the length
  my ($itp, $integer, $isource) = $runtime->popType('INTEGER', $instruction);
  unless ($itp) {
    $runtime->pushString("");
    return; }
  # pop the final name string
  my ($stype, $strings, $sources) = $runtime->popType('STRING', $instruction);
  unless (defined($stype)) {
    $runtime->pushString("");
    return; }

  # add the text prefix and push it to the stack
  my ($newStrings, $newSources) = applyPatch(
    $strings, $sources,
    sub {
      my @names = splitNames($_[0] . '');
      my $name  = $names[$integer - 1] || '';    # TODO: Warn if missing
      my ($fname, $error) = formatName("$name", $fstrings);
      Warn('bibtex', 'runtime', $instruction->getLocator, "Unable to format name: $error")
        if defined($error);
      return defined($fname) ? $fname : '';
    },
    0
  );
  $runtime->pushStack('STRING', $newStrings, $newSources);
  return; }

# builtin function if$
# pops two function literals and an integer literal from the stack.
# it then executes the first literal if the integer is > 0, otherwise the second.
# if either type mismatches, complains but does not attempt to recover.
sub builtinIf {
  my ($runtime, $instruction) = @_;
  my ($f1type, $f1, $f1src) = $runtime->popStack;
  return unless defined($f1type);
  my ($f2type, $f2, $f2src) = $runtime->popStack;
  return unless defined($f2type);
  my ($itype, $integer) = $runtime->popType('INTEGER', $instruction);
  return unless defined($itype);

  if ($integer > 0) {
    $runtime->executeStacked($instruction, $f2type, $f2, $f2src); }
  else {
    $runtime->executeStacked($instruction, $f1type, $f1, $f1src); }
  return; }

# builtin function int.to.chr$
# pops an integer literal from the stack, and pushes the corresponding ASCII character.
# when the stack does not contain an integer, complains and pushes the null string.
sub builtinIntToChr {
  my ($runtime, $instruction) = @_;
  my ($type, $integer, $isource) = $runtime->popType('INTEGER', $instruction);
  unless (defined($type)) {
    $runtime->pushString("");
    return; }
  $runtime->pushStack('STRING', [chr($integer)], [$isource]);
  return; }

# builtin function int.to.str$
# pops an integer literal from the stack, and pushes the corresponding string value.
# when the stack does not contain an integer, complains and pushes the null string.
sub builtinIntToStr {
  my ($runtime, $instruction) = @_;
  my ($type, $integer, $isource) = $runtime->popType('INTEGER', $instruction);
  unless (defined($type)) {
    $runtime->pushString("");
    return; }
  $runtime->pushStack('STRING', ["$integer"], [$isource]);
  return; }

# builtin function missing$
# pops the top literal from the stack, and pushes the integer 1 if it is a missing field, 0 otherwise.
sub builtinMissing {
  my ($runtime, $instruction) = @_;
  my ($tp) = $runtime->popStack;
  unless (defined($tp)) {
    Warn('bibtex', 'runtime', $instruction->getLocator, "Unable to pop empty stack");
    return; }
  $runtime->pushInteger(($tp eq 'MISSING') ? 1 : 0);
  return; }

# builtin function newline$
# sends the current content of the output buffer and a newline to the output.
sub builtinNewline {
  my ($runtime, $instruction) = @_;
  $runtime->getBuffer->writeLn;
  return; }

# builtin function num.names$
# pops a string literal from the stack, and then counts the number of names in it
# when the top literal is not a string, loudly pushes the number 0.
sub builtinNumNames {
  my ($runtime, $instruction) = @_;
  my ($type, $strings, $sources) = $runtime->popType('STRING', $instruction);
  unless (defined($type)) {
    $runtime->pushInteger(0);
    return; }

  # if we have a string, that's ok.
  if (defined($type)) {
    my ($str, $src) = simplifyString($strings, $sources);
    $runtime->pushStack('INTEGER', numNames($str), [$src]); }
  return; }

# builtin function pop$
# pops the top literal from the stack and does nothing
sub builtinPop {
  my ($runtime, $instruction) = @_;
  my ($tp) = $runtime->popStack;
  unless (defined($tp)) {
    Warn('bibtex', 'runtime', $instruction->getLocator, "Unable to pop empty stack"); }
  return; }

# builtin function preamble$
# pushes the concatination of all preambles onto the stack
sub builtinPreamble {
  my ($runtime, $instruction) = @_;
  my ($strings, $sources)     = $runtime->getPreamble;
  $runtime->pushStack('STRING', $strings, $sources);
  return; }

# builtin function purify$
# pops a string from the stack, purifies it, and then pushes it.
# when the top literal is not a string, loudly pushes the empty string.
sub builtinPurify {
  my ($runtime, $instruction) = @_;
  my ($type, $strings, $sources) = $runtime->popType('STRING', $instruction);
  unless (defined($type)) {
    $runtime->pushString("");
    return; }
  my ($newStrings, $newSources) = applyPatch($strings, $sources, \&textPurify, 'inplace');
  $runtime->pushStack('STRING', $newStrings, $newSources);
  return; }

# builtin function quote$
# push the string containing only a double quote onto the stack
sub builtinQuote {
  my ($runtime, $instruction) = @_;
  $runtime->pushString("\"");
  return; }

# builtin function skip$
# does nothing
sub builtinSkip { return; }

# builtin function stack$
# pops and prints the contents of the stack for debugging purposes
sub builtinStack {
  my ($runtime, $instruction) = @_;
  my ($tp, $value, $src) = $runtime->popStack;
  while (defined($tp)) {
    Degug(fmtType($tp, $value, $src));
    ($tp, $value, $src) = $runtime->popStack; }
  return; }

# builtin function substring$
# pops two integers and a string, then pushes the substring consisting of the appropriate position and length.
# When any of the types are incorrect, loudly pushes the empty string
sub builtinSubstring {
  my ($runtime, $instruction) = @_;
  # pop the first integer
  my ($i1t, $i1, $i1source) = $runtime->popType('INTEGER', $instruction);
  unless (defined($i1t)) {
    $runtime->pushString("");
    return; }
  # pop the second integer
  my ($i2t, $i2, $i2source) = $runtime->popType('INTEGER', $instruction);
  unless (defined($i2t)) {
    $runtime->pushString("");
    return; }
  # pop the string
  my ($stype, $strings, $sources) = $runtime->popType('STRING', $instruction);
  unless (defined($stype)) {
    $runtime->pushString("");
    return; }

  # add the text prefix and push it to the stack
  my ($newStrings, $newSources) = applyPatch(
    $strings, $sources,
    sub { return textSubstring($_[0] . '', $i2, $i1); },
    'inplace'
  );
  $runtime->pushStack('STRING', $newStrings, $newSources);
  return; }

# builtin function swap$
# pops two literals from the stack, and pushes them back swapped.
sub builtinSwap {
  my ($runtime, $instruction) = @_;
  Warn('bibtex', 'runtime', $instruction->getLocator,
    'Need at least two elements on the stack to swap.')
    unless $runtime->swapStack;
  return; }

# builtin function text.length$
# pops a string from the top of the stack, and then pushes it's length.
# When the top literal is not a string, loudly pushes the empty string.
sub builtinTextLength {
  my ($runtime, $instruction) = @_;
  my ($type, $strings, $sources) = $runtime->popType('STRING', $instruction);
  unless (defined($type)) {
    $runtime->pushString("");
    return;
  }
  my ($str, $src) = simplifyString($strings, $sources);
  $runtime->pushStack('INTEGER', textLength($str), $src);
  return; }

# builtin function text.prefix$
# pops an integer and a string from the stack, then pushes the prefix of the given length of that string
# if either of the types don't match, loudly pushes the empty string.
sub builtinTextPrefix {
  my ($runtime, $instruction) = @_;
  # pop the integer
  my ($itype, $integer, $isource) = $runtime->popType('INTEGER', $instruction);
  unless (defined($itype)) {
    $runtime->pushString("");
    return; }
  # pop and simplify the string
  my ($stype, $strings, $sources) = $runtime->popType('STRING', $instruction);
  unless (defined($stype)) {
    $runtime->pushString("");
    return; }
  # add the text prefix and push it to the stack
  my ($newStrings, $newSources) = applyPatch(
    $strings, $sources,
    sub { return textPrefix($_[0] . '', $integer); },
    'inplace'
  );
  $runtime->pushStack('STRING', $newStrings, $newSources);
  return; }

# builtin function top$
# pops the topmost entry of the stack and prints it for debugging purposes
sub builtinTop {
  my ($runtime, $instruction) = @_;
  my ($tp, $value, $src) = $runtime->popStack;
  if (defined($tp)) {
    Debug(fmtType($tp, $value, $src)); }
  else {
    Warn('bibtex', 'runtime', $instruction->getLocator, "Unable to pop empty stack"); }
  return; }

# builtin function type$
# pushes the type of the current entry onto the stack.
# If the string is empty or undefined, pushes the empty string.
sub builtinType {
  my ($runtime, $instruction) = @_;
  my $entry = $runtime->getEntry;
  if ($entry) {
    my $tp = $entry->getType;
    $tp = '' unless $runtime->hasVariable($tp, 'FUNCTION');
    $runtime->pushStack('STRING', [$tp],
      [[$entry->getName, $entry->getKey]]); }
  else {
    $runtime->pushString(""); }
  return; }

# builtin function warning$
# pops the top-most string from the stack and send a warning to the user
sub builtinWarning {
  my ($runtime, $instruction) = @_;
  my ($type, $strings, $sources) = $runtime->popType('STRING', $instruction);
  return unless defined($type);

  my ($str, $src) = simplifyString($strings, $sources);
  Warn('bibtex', 'runtime', $instruction->getLocator, $str);
  return; }

# builtin function while$
# pops two function literals from the stack and keeps executing the second
# while the integer literal returned from the first is > 0.
# If any involved type is wrong, fails silently.
sub builtinWhile {
  my ($runtime, $instruction) = @_;
  my ($f1type, $f1, $f1src) = $runtime->popStack;
  return unless defined($f1type);
  my ($f2type, $f2, $f2src) = $runtime->popStack;
  return unless defined($f2type);
  while (1) {
    $runtime->executeStacked($instruction, $f2type, $f2, $f2src);
    my ($itype, $integer) = $runtime->popType('INTEGER', $instruction);
    return unless defined($itype);
    return if $integer <= 0;
    $runtime->executeStacked($instruction, $f1type, $f1, $f1src); }
  return; }

# builtin function width$
# pops a string from the stack and computes it's width in units.
# when the stack does not contain a string, loudly pushes 0.
sub builtinWidth {
  my ($runtime, $instruction) = @_;
  my ($type, $strings, $sources) = $runtime->popType('STRING', $instruction);
  unless (defined($type)) {
    $runtime->pushInteger(0);
    return; }
  my ($str, $src) = simplifyString($strings, $sources);
  $runtime->pushStack('INTEGER', textWidth($str), $src);
  return; }

# builtin function write$
# writes a string to the output buffer (and potentially writes
# to the output iff it is long enugh)
sub builtinWrite {
  my ($runtime, $instruction) = @_;
  my ($type, $strings, $sources) = $runtime->popType('STRING', $instruction);
  return unless defined($type);
  # get the ouput buffer and array references to sources and strings
  my $buffer     = $runtime->getBuffer;
  my @theStrings = @{$strings};
##  my @theSources = @{$sources};
  my @theSources = (defined $sources ? @{$sources} : ());
  # we iterate by index to not mutate strings and sources
  foreach my $i (0 .. $#theStrings) {
    $buffer->write($theStrings[$i], $theSources[$i]); }
  return; }

1;
