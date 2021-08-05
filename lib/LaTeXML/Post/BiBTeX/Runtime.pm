# /=====================================================================\ #
# |  LaTeXML::Post::BiBTeX::Runtime                                     | #
# | Runtime for LaTeXML::Post::BiBTeX-generated perl code               | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::Post::BiBTeX::Runtime;
use strict;
use warnings;

use LaTeXML::Post::BiBTeX::Runtime::Functions;
use LaTeXML::Post::BiBTeX::Runtime::Builtins;

use LaTeXML::Post::BiBTeX::BibStyle::StyCommand;
use LaTeXML::Post::BiBTeX::BibStyle::StyString;

sub StyCommand { LaTeXML::Post::BiBTeX::BibStyle::StyCommand->new(@_); }
sub StyString  { LaTeXML::Post::BiBTeX::BibStyle::StyString->new(@_); }

use base qw(Exporter);
our @EXPORT = qw(
  &defineEntryField &defineEntryInteger &defineEntryString &defineGlobalString &defineGlobalInteger &defineGlobalInteger &registerFunctionDefinition &defineMacro
  &readEntries &sortEntries &iterateFunction &reverseFunction
  &pushString &pushInteger &pushFunction
  &pushFunction &pushGlobalString &pushGlobalInteger &pushEntryField &pushEntryString &pushEntryInteger
  &lookupGlobalString &lookupGlobalInteger &lookupEntryString &lookupEntryField &lookupEntryInteger
  &sortEntries

  &builtinZg &builtinZl &builtinZe &builtinZp &builtinZm &builtinZa
  &builtinZcZe &builtinAddPeriod &builtinCallType &builtinChangeCase
  &builtinChrToInt &builtinCite &builtinDuplicate &builtinEmpty
  &builtinFormatName &builtinIf &builtinIntToChr &builtinIntToStr
  &builtinMissing &builtinNewline &builtinNumNames &builtinPop
  &builtinPreamble &builtinPurify &builtinQuote &builtinSkip
  &builtinStack &builtinSubstring &builtinSwap &builtinTextLength
  &builtinTextPrefix &builtinTop &builtinType &builtinWarning
  &builtinWhile &builtinWidth &builtinWrite

  &StyString
  &StyCommand
);

1;
