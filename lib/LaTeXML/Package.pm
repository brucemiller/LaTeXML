# /=====================================================================\ #
# |  LaTeXML::Package                                                   | #
# | Exports of Defining forms for Package writers                       | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Package;
use strict;
use warnings;
use Exporter;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Core::Token;
use LaTeXML::Core::Tokens;
use LaTeXML::Core::Box;
use LaTeXML::Core::List;
use LaTeXML::Core::Mouth::Binding;
use LaTeXML::Core::Definition;
use LaTeXML::Core::Parameters;
use LaTeXML::Common::Number;
use LaTeXML::Common::Float;
use LaTeXML::Common::Dimension;
use LaTeXML::Common::Glue;
use LaTeXML::Core::MuDimension;
use LaTeXML::Core::MuGlue;
# Extra objects typically used in Bindings
use LaTeXML::Core::Alignment;
use LaTeXML::Core::Array;
use LaTeXML::Core::KeyVal;
use LaTeXML::Core::KeyVals;
use LaTeXML::Core::Pair;
use LaTeXML::Core::PairList;
use LaTeXML::Common::Color;
use LaTeXML::Common::Color::rgb;
# Utitlities
use LaTeXML::Util::Pathname;
use LaTeXML::Util::WWW;
use LaTeXML::Common::XML;
use LaTeXML::Core::Rewrite;
use LaTeXML::Util::Radix;
use File::Which;
use Unicode::Normalize;
use Text::Balanced;
use Text::Unidecode;
use base qw(Exporter);
our @EXPORT = (qw(&DefAutoload &DefExpandable
    &DefMacro &DefMacroI
    &DefConditional &DefConditionalI &IfCondition &SetCondition
    &DefPrimitive  &DefPrimitiveI
    &DefRegister &DefRegisterI &LookupRegister &AssignRegister &LookupDimension
    &DefConstructor &DefConstructorI
    &dualize_arglist &createXMRefs
    &DefMath &DefMathI &DefEnvironment &DefEnvironmentI
    &convertLaTeXArgs),

  # Class, Package and File loading.
  qw(&Input &InputContent &InputDefinitions &RequirePackage &LoadClass &LoadPool &FindFile
    &DeclareOption &PassOptions &ProcessOptions &ExecuteOptions
    &AddToMacro &AtBeginDocument &AtEndDocument),

  # Counter support
  qw(&NewCounter &CounterValue &SetCounter &AddToCounter &StepCounter &RefStepCounter &RefStepID &ResetCounter
    &GenerateID &AfterAssignment
    &MaybePeekLabel &MaybeNoteLabel),

  # Document Model
  qw(&Tag &DocType &RelaxNGSchema &RegisterNamespace &RegisterDocumentNamespace),

  # Document Rewriting
  qw(&DefRewrite &DefMathRewrite
    &DefLigature &DefMathLigature),

  # Mid-level support for writing definitions.
  qw(&Expand &Invocation &Digest &DigestText &DigestIf &DigestLiteral
    &RawTeX &Let &StartSemiverbatim &EndSemiverbatim
    &Tokenize &TokenizeInternal),

  # Font encoding
  qw(&DeclareFontMap &FontDecode &FontDecodeString &LoadFontMap),

  # Color
  qw(&DefColor &DefColorModel &LookupColor),

  # Support for structured/argument readers
  qw(&ReadParameters &DefParameterType  &DefColumnType),

  # Access to State
  qw(&LookupValue &AssignValue
    &PushValue &PopValue &UnshiftValue &ShiftValue
    &LookupMapping &AssignMapping &LookupMappingKeys
    &LookupCatcode &AssignCatcode
    &LookupMeaning &LookupDefinition &InstallDefinition &XEquals &IsDefined
    &LookupMathcode &AssignMathcode
    &LookupSFcode &AssignSFcode
    &LookupLCcode &AssignLCcode
    &LookupUCcode &AssignUCcode
    &LookupDelcode &AssignDelcode
    ),

  # Random low-level token or string operations.
  qw(&CleanID &CleanLabel &CleanIndexKey  &CleanClassName &CleanBibKey &NormalizeBibKey &CleanURL
    &ComposeURL
    &UTF
    &roman &Roman),
  # Math & font state.
  qw(&MergeFont),

  qw(&CheckOptions),
  # Resources
  qw(&RequireResource &ProcessPendingResources),

  @LaTeXML::Global::EXPORT,
  # And export those things exported by these Core & Common packages.
  @LaTeXML::Common::Object::EXPORT,
  @LaTeXML::Common::Error::EXPORT,
  @LaTeXML::Core::Token::EXPORT,
  @LaTeXML::Core::Tokens::EXPORT,
  @LaTeXML::Core::Box::EXPORT,
  @LaTeXML::Core::List::EXPORT,
  @LaTeXML::Common::Number::EXPORT,
  @LaTeXML::Common::Float::EXPORT,
  @LaTeXML::Common::Dimension::EXPORT,
  @LaTeXML::Common::Glue::EXPORT,
  @LaTeXML::Core::KeyVal::EXPORT,
  @LaTeXML::Core::KeyVals::EXPORT,
  @LaTeXML::Core::MuDimension::EXPORT,
  @LaTeXML::Core::MuGlue::EXPORT,
  @LaTeXML::Core::Pair::EXPORT,
  @LaTeXML::Core::PairList::EXPORT,
  @LaTeXML::Common::Color::EXPORT,
  @LaTeXML::Core::Alignment::EXPORT,
  @LaTeXML::Common::XML::EXPORT,
  @LaTeXML::Util::Radix::EXPORT,
);

#**********************************************************************
#   Initially, I thought LaTeXML Packages should try to be like perl modules:
# once loaded, you didn't need to re-load them, only `initialize' them to
# install their definitions into the current stomach.  I tried to achieve
# that through various package tricks.
#    But ultimately, most of a package _is_ installing defns in the stomach,
# and it's probably better to allow a more TeX-like evaluation of definitions
# in order, so \let and such work as expected.
#    So, it got simpler!
# Still, it would be nice if there were `compiled' forms of .ltxml files!
#**********************************************************************

sub UTF {
  my ($code) = @_;
  return pack('U', $code); }

sub coerceCS {
  my ($cs) = @_;
  $cs = T_CS($cs)           unless ref $cs;
  $cs = T_CS(ToString($cs)) unless ref $cs eq 'LaTeXML::Core::Token';
  return $cs; }

sub parsePrototype {
  my ($proto) = @_;
  my $oproto = $proto;
  if (ref $proto eq 'LaTeXML::Core::Token') {
    return ($proto, undef); }
  my $cs;
  if ($proto =~ s/^\\csname\s+(.*)\\endcsname//) {
    $cs = T_CS('\\' . $1); }
  elsif ($proto =~ s/^(\\[a-zA-Z@]+)//) {    # Match a cs
    $cs = T_CS($1); }
  elsif ($proto =~ s/^(\\.)//) {             # Match a single char cs, env name,...
    $cs = T_CS($1); }
  elsif ($proto =~ s/^(.)//) {               # Match an active char
    ($cs) = TokenizeInternal($1)->unlist; }
  else {
    Fatal('misdefined', $proto, $STATE->getStomach,
      "Definition prototype doesn't have proper control sequence: \"$proto\""); }
  $proto =~ s/^\s*//;
####  return ($cs, parseParameters($proto, $cs)); }
  return ($cs, $proto); }

# If a ReadFoo function exists (accessible from LaTeXML::Package::Pool),
# then the parameter spec:
#     Foo         : will invoke it and use the result for the corresponding argument.
#                   it will complain if ReadFoo returns undef.
#     SkipFoo     : will invoke SkipFoo, if it is defined, else ReadFoo,
#                   but in either case, will ignore the result
#     OptionalFoo : will invoke ReadOptionalFoo if defined, else ReadFoo
#                   but will not complain if the reader returns undef.
# In all cases, there is the provision to supply an additional parameter to the reader:
#    "Foo:stuff"   effectively invokes ReadFoo(Tokenize('stuff'))
# similarly for the other variants. What the 'stuff" means depends on the type.
sub parseParameters {
  my ($proto, $for) = @_;
  my $p      = $proto;
  my @params = ();
  while ($p) {
    # Handle possibly nested cases, such as {Number}
    if ($p =~ s/^(\{([^\}]*)\})\s*//) {
      my ($spec, $inner_spec) = ($1, $2);
      my $inner = ($inner_spec ? parseParameters($inner_spec, $for) : undef);
      # If single inner spec is optional, make whole thing optional
      my $opt = $inner && (scalar(@$inner) == 1) && $$inner[0]{optional};
      push(@params, LaTeXML::Core::Parameter->new('Plain', $spec, extra => [$inner],
          optional => $opt)); }
    elsif ($p =~ s/^(\[([^\]]*)\])\s*//) {    # Ditto for Optional
      my ($spec, $inner_spec) = ($1, $2);
      if ($inner_spec =~ /^Default:(.*)$/) {
        push(@params, LaTeXML::Core::Parameter->new('Optional', $spec,
            extra => [TokenizeInternal($1), undef])); }
      elsif ($inner_spec) {
        push(@params, LaTeXML::Core::Parameter->new('Optional', $spec,
            extra => [undef, parseParameters($inner_spec, $for)])); }
      else {
        push(@params, LaTeXML::Core::Parameter->new('Optional', $spec)); } }
    elsif ($p =~ s/^((\w*)(:([^\s\{\[]*))?)\s*//) {
      my ($spec, $type, $extra) = ($1, $2, $4);
      my @extra = map { TokenizeInternal($_) } split('\|', $extra || '');
      push(@params, LaTeXML::Core::Parameter->new($type, $spec, extra => [@extra])); }
    else {
      Fatal('misdefined', $for, undef, "Unrecognized parameter specification at \"$proto\""); } }
  return (@params ? LaTeXML::Core::Parameters->new(@params) : undef); }

# Convert a LaTeX-style argument spec to our Package form.
# Ie. given $nargs and $optional, being the two optional arguments to
# something like \newcommand, convert it to the form we use
sub convertLaTeXArgs {
  my ($nargs, $optional) = @_;
  $nargs = $nargs->toString if ref $nargs;
  $nargs = 0 unless $nargs;
  my @params = ();
  if ($optional) {
    push(@params, LaTeXML::Core::Parameter->new('Optional',
        "[Default:" . UnTeX($optional) . "]",
        extra => [$optional, undef]));
    $nargs--; }
  push(@params, map { LaTeXML::Core::Parameter->new('Plain', '{}') } 1 .. $nargs);
  return (@params ? LaTeXML::Core::Parameters->new(@params) : undef); }

#======================================================================
# Convenience functions for writing definitions.
#======================================================================

sub LookupValue {
  my ($name) = @_;
  return $STATE->lookupValue($name); }

sub AssignValue {
  my ($name, $value, $scope) = @_;
  $STATE->assignValue($name, $value, $scope); return; }

sub PushValue {
  my ($name, @values) = @_;
  $STATE->pushValue($name, @values);
  return; }

sub PopValue {
  my ($name) = @_;
  return $STATE->popValue($name); }

sub UnshiftValue {
  my ($name, @values) = @_;
  $STATE->unshiftValue($name, @values);
  return; }

sub ShiftValue {
  my ($name) = @_;
  return $STATE->shiftValue($name); }

sub LookupMapping {
  my ($map, $key) = @_;
  return $STATE->lookupMapping($map, $key); }

sub AssignMapping {
  my ($map, $key, $value) = @_;
  return $STATE->assignMapping($map, $key, $value); }

sub LookupMappingKeys {
  my ($map) = @_;
  return $STATE->lookupMappingKeys($map); }

sub LookupCatcode {
  my ($char) = @_;
  return $STATE->lookupCatcode($char); }

sub AssignCatcode {
  my ($char, $catcode, $scope) = @_;
  $STATE->assignCatcode($char, $catcode, $scope);
  return; }

sub LookupMeaning {
  my ($name) = @_;
  return $STATE->lookupMeaning($name); }

sub LookupDefinition {
  my ($name) = @_;
  return $STATE->lookupDefinition($name); }

sub InstallDefinition {
  my ($name, $definition, $scope) = @_;
  $STATE->installDefinition($name, $definition, $scope);
  return }

sub XEquals {
  my ($token1, $token2) = @_;
  my $def1 = LookupMeaning($token1);    # token, definition object or undef
  my $def2 = LookupMeaning($token2);    # ditto
  if (defined $def1 != defined $def2) { # False, if only one has 'meaning'
    return 0; }
  elsif (!defined $def1 && !defined $def2) {    # true if both undefined
    return 1; }
  elsif ($def1->equals($def2)) {                # If both have defns, must be same defn!
    return 1; }
  return 0; }

# Is defined in the LaTeX-y sense of also not being let to \relax.
sub IsDefined {
  my ($name) = @_;
  my $cs      = (ref $name ? $name : T_CS($name));
  my $meaning = $STATE->lookupMeaning($cs);
  return $meaning
    && ($meaning->isa('LaTeXML::Core::Token') || ($meaning->getCSName ne '\relax'))
    && $meaning; }

sub LookupMathcode {
  my ($char) = @_;
  return $STATE->lookupMathcode($char); }

sub AssignMathcode {
  my ($char, $mathcode, $scope) = @_;
  $STATE->assignMathcode($char, $mathcode, $scope);
  return; }

sub LookupSFcode {
  my ($char) = @_;
  return $STATE->lookupSFcode($char); }

sub AssignSFcode {
  my ($char, $sfcode, $scope) = @_;
  $STATE->assignSFcode($char, $sfcode, $scope);
  return; }

sub LookupLCcode {
  my ($char) = @_;
  return $STATE->lookupLCcode($char); }

sub AssignLCcode {
  my ($char, $lccode, $scope) = @_;
  $STATE->assignLCcode($char, $lccode, $scope);
  return; }

sub LookupUCcode {
  my ($char) = @_;
  return $STATE->lookupUCcode($char); }

sub AssignUCcode {
  my ($char, $uccode, $scope) = @_;
  $STATE->assignUCcode($char, $uccode, $scope);
  return; }

sub LookupDelcode {
  my ($char) = @_;
  return $STATE->lookupDelcode($char); }

sub AssignDelcode {
  my ($char, $delcode, $scope) = @_;
  $STATE->assignDelcode($char, $delcode, $scope);
  return; }

sub Let {
  my ($token1, $token2, $scope) = @_;
  # If strings are given, assume CS tokens (most common case)
  $token1 = T_CS($token1) unless ref $token1;
  $token2 = T_CS($token2) unless ref $token2;
  $STATE->assignMeaning($token1,
    ($token2->get_dont_expand ? $token2 : $STATE->lookupMeaning($token2)), $scope);
  AfterAssignment();
  return; }

sub Digest {
  my (@stuff) = @_;
  return $STATE->getStomach->digest(Tokens(map { (ref $_ ? $_ : TokenizeInternal($_)) } @stuff)); }

sub DigestText {
  my (@stuff) = @_;
  my $stomach = $STATE->getStomach;
  $stomach->beginMode('text');
  my $result = $stomach->digest(Tokens(map { (ref $_ ? $_ : TokenizeInternal($_)) } @stuff));
  $stomach->endMode('text');
  return $result; }

# probably need to export this, as well?
sub DigestLiteral {
  my (@stuff) = @_;
# Perhaps should do StartSemiverbatim, but is it safe to push a frame? (we might cover over valid changes of state!)
  my $stomach = $STATE->getStomach;
  $stomach->beginMode('text');
  my $font = LookupValue('font');
  AssignValue(font => $font->merge(encoding => 'ASCII'), 'local');  # try to stay as ASCII as possible
  my $value = $STATE->getStomach->digest(Tokens(map { (ref $_ ? $_ : Tokenize($_)) } @stuff));
  AssignValue(font => $font);
  $stomach->endMode('text');
  return $value; }

sub DigestIf {
  my ($token) = @_;
  $token = T_CS($token) unless ref $token;
  if (my $defn = $STATE->lookupDefinition($token)) {
    return $STATE->getStomach->digest($token); }
  else {
    return; } }

sub ReadParameters {
  my ($gullet, $spec) = @_;
  my $for  = T_OTHER("Anonymous");
  my $parm = parseParameters($spec, $for);
  return ($parm ? $parm->readArguments($gullet, $for) : ()); }

# Merge the current font with the style specifications
sub MergeFont {
  my (@kv) = @_;
  AssignValue(font => LookupValue('font')->merge(@kv), 'local');
  return; }

# Dumb place for this, but where else...
# The TeX way! (bah!! hint: try a large number)
my @rmletters = ('i', 'v', 'x', 'l', 'c', 'd', 'm');    # [CONSTANT]

sub roman_aux {
  my ($n) = @_;
  # We used to have a expl3-code.tex bug here with
  # input: -1
  # output: cmxcix
  # TeX proper returns empty on negative integers
  return '' unless $n && ($n > 0);
  my $div = 1000;
  my $s   = ($n > $div ? ('m' x int($n / $div)) : '');
  my $p   = 4;
  while ($n %= $div) {
    $div /= 10;
    my $d = int($n / $div);
    if ($d % 5 == 4) { $s .= $rmletters[$p]; $d++; }
    if ($d > 4) { $s .= $rmletters[$p + int($d / 5)]; $d %= 5; }
    if ($d) { $s .= $rmletters[$p] x $d; }
    $p -= 2; }
  return $s; }

# Convert the number to lower case roman numerals, returning a list of LaTeXML::Core::Token
sub roman {
  my (@stuff) = @_;
  return ExplodeText(roman_aux(@stuff)); }
# Convert the number to upper case roman numerals, returning a list of LaTeXML::Core::Token
sub Roman {
  my (@stuff) = @_;
  return ExplodeText(uc(roman_aux(@stuff))); }

#======================================================================
# Cleaners
#======================================================================

sub CleanID {
  my ($key) = @_;
  $key = ToString($key);
  $key =~ s/^\s+//s; $key =~ s/\s+$//s;    # Trim leading/trailing, in any case
  $key =~ s/\s//sg;
  # Remove common idiom:
  $key =~ s/\$\{\}\^\{(.*?)\}\$/$1/g;
  # transform some forbidden chars
  $key =~ s/:/../g;                        # No colons!
  $key =~ s/@/-at-/g;
  $key =~ s/\*/-star-/g;
  $key =~ s/\$/-dollar-/g;
  $key =~ s/,/-comma-/g;
  $key =~ s/%/-pct-/g;
  $key =~ s/&/-amp-/g;
  $key = unidecode($key);
  $key =~ s/[^\w\_\-.]//g;                 # remove everything else.

  if ($key =~ /^[^a-zA-Z\_]/) {
    # in case we are missing a prefix and have a leading ., default to X
    $key = "X$key";
  }
  return $key; }

sub CleanLabel {
  my ($label, $prefix) = @_;
  my $key = ToString($label);
  $key =~ s/^\s+//s; $key =~ s/\s+$//s;    # Trim leading/trailing, in any case
  $key =~ s/\s+/_/sg;
  return (defined $prefix ? ($prefix ? $prefix . ':' . $key : $key) : 'LABEL:' . $key); }

sub CleanIndexKey {
  my ($key) = @_;
  $key = ToString($key);
  $key =~ s/^\s+//s; $key =~ s/\s+$//s;    # Trim leading/trailing, in any case
        # We don't want accented chars (do we?) but we need to decompose the accents!
## No, leave in the unicode at this point (strip them later)
##  $key = NFD($key);
##  $key =~ s/[^a-zA-Z0-9]//g;
  $key = NFC($key);    # just to be safe(?)
## Shouldn't be case insensitive?
##  $key =~ tr|A-Z|a-z|;
  $key =~ s/[\.\,\;]+$//;    # Remove trailing punctuation
  return $key; }

sub CleanClassName {
  my ($key) = @_;
  $key = ToString($key);
  $key =~ s/^\s+//s; $key =~ s/\s+$//s;    # Trim leading/trailing, in any case
        # We don't want accented chars (do we?) but we need to decompose the accents!
  $key = NFD($key);
  $key =~ s/[^a-zA-Z0-9]//g;
  $key = NFC($key);    # just to be safe(?)
  return $key; }

sub CleanBibKey {
  my ($key) = @_;
  $key = ToString($key);    # Originally lc() here, but let's preserve case till Postproc.
  $key =~ s/^\s+//s; $key =~ s/\s+$//s;    # Trim leading/trailing, in any case
  $key =~ s/\s//sg;
  return $key; }

# Return the bibkey in a form to ACTUALLY lookup.
# Usually use CleanBibKey to preserve key in the original form (case)
sub NormalizeBibKey {
  my ($key) = @_;
  return ($key ? lc(CleanBibKey($key)) : undef); }

sub CleanURL {
  my ($url) = @_;
  $url = ToString($url);
  $url =~ s/^\s+//s; $url =~ s/\s+$//s;    # Trim leading/trailing, in any case
  $url =~ s/\\~\{\}/~/g;
  return $url; }

sub ComposeURL {
  my ($base, $url, $fragid) = @_;
  $base   = ToString($base); $base =~ s/\/$// if $base;    # remove trailing /
  $url    = ToString($url);
  $fragid = ToString($fragid);
  return CleanURL(join('',
      ($base ?
          ($url =~ /^\w+:/ ? ''                            # already has protocol, so is absolute url
          : $base . ($url =~ /^\// ? '' : '/'))            # else start w/base, possibly /
        : ''),
      $url,
      ($fragid ? '#' . CleanID($fragid) : ''))); }

#======================================================================
# Defining new Control-sequence Parameter types.
#======================================================================

my $parameter_options = {    # [CONSTANT]
  nargs        => 1, reversion   => 1, optional => 1, novalue => 1,
  beforeDigest => 1, afterDigest => 1,
  semiverbatim => 1, undigested  => 1 };

sub DefParameterType {
  my ($type, $reader, %options) = @_;
  CheckOptions("DefParameterType $type", $parameter_options, %options);
  AssignMapping('PARAMETER_TYPES', $type, { reader => $reader, %options });
  return; }

sub DefColumnType {
  my ($proto, $expansion) = @_;
  if ($proto =~ s/^(.)//) {
    my $char = $1;
    $proto =~ s/^\s*//;
    # Defer
    #    $proto = parseParameters($proto, $char);
    #    $expansion = TokenizeInternal($expansion) unless ref $expansion;
    DefMacroI(T_CS('\NC@rewrite@' . $char), $proto, $expansion); }
  else {
    Warn('expected', 'character', undef, "Expected Column specifier"); }
  return; }

#======================================================================
# Counters
#======================================================================
# This is modelled on LaTeX's counter mechanisms, but since it also
# provides support for ID's, even where there is no visible reference number,
# it is defined in genera.
# These id's should be both unique, and parallel the visible reference numbers
# (as much as possible).  Also, for consistency, we add id's to unnumbered
# document elements (eg from \section*); this requires an additional counter
# (eg. UNsection) and  mechanisms to track it.

# Defines a new counter named $ctr.
# If $within is defined, $ctr will be reset whenever $within is incremented.
# Keywords:
#  idprefix : specifies a prefix to be used in formatting ID's for document structure elements
#           counted by this counter.  Ie. subsection 3 in section 2 might get: id="S2.SS3"
#  idwithin : specifies that the ID is composed from $idwithin's ID,, even though
#           the counter isn't numbered within it.  (mainly to avoid duplicated ids)
#   nested : a list of counters that correspond to scopes which are "inside" this one.
#           Whenever any definitions scoped to this counter are deactivated,
#           the inner counter's scopes are also deactivated.
#           NOTE: I'm not sure this is even a sensible implementation,
#           or why inner should be different than the counters reset by incrementing this counter.

sub NewCounter {
  my ($ctr, $within, %options) = @_;
  my $unctr = "UN$ctr";    # UNctr is counter for generating ID's for UN-numbered items.
  DefRegisterI(T_CS("\\c\@$ctr"), undef, Number(0));
  AssignValue("\\c\@$ctr" => Number(0), 'global');
  AfterAssignment();
  AssignValue("\\cl\@$ctr" => Tokens(), 'global') unless LookupValue("\\cl\@$ctr");
  DefRegisterI(T_CS("\\c\@$unctr"), undef, Number(0));
  AssignValue("\\c\@$unctr" => Number(0), 'global');
  AssignValue("\\cl\@$unctr" => Tokens(), 'global') unless LookupValue("\\cl\@$unctr");
  my $x;
  AssignValue("\\cl\@$within" =>
      Tokens(T_CS($ctr), T_CS($unctr), (($x = LookupValue("\\cl\@$within")) ? $x->unlist : ())),
    'global') if $within;
  AssignValue("\\cl\@UN$within" =>
      Tokens(T_CS($unctr), (($x = LookupValue("\\cl\@UN$within")) ? $x->unlist : ())),
    'global') if $within;
  AssignValue('nested_counters_' . $ctr => $options{nested}, 'global') if $options{nested};
  # default is equivalent to \arabic{ctr}, but w/o using the LaTeX macro!
  DefMacroI(T_CS("\\the$ctr"), undef, sub {
      ExplodeText(CounterValue($ctr)->valueOf); },
    scope => 'global');
  if (!LookupDefinition(T_CS("\\p\@$ctr"))) {
    DefMacroI(T_CS("\\p\@$ctr"), undef, Tokens(), scope => 'global'); }
  my $prefix = $options{idprefix};
  AssignValue('@ID@prefix@' . $ctr => $prefix, 'global') if $prefix;
  $prefix = LookupValue('@ID@prefix@' . $ctr) || $ctr unless $prefix;
  $prefix = CleanID($prefix);
  if (defined $prefix) {
    if (my $idwithin = $options{idwithin} || $within) {
      DefMacroI(T_CS("\\the$ctr\@ID"), undef,
        "\\expandafter\\ifx\\csname the$idwithin\@ID\\endcsname\\\@empty"
          . "\\else\\csname the$idwithin\@ID\\endcsname.\\fi"
          . " $prefix\\csname \@$ctr\@ID\\endcsname",
        scope => 'global'); }
    else {
      DefMacroI(T_CS("\\the$ctr\@ID"), undef, "$prefix\\csname \@$ctr\@ID\\endcsname",
        scope => 'global'); }
    DefMacroI(T_CS("\\\@$ctr\@ID"), undef, "0", scope => 'global'); }
  return; }

sub CounterValue {
  my ($ctr) = @_;
  $ctr = ToString($ctr) if ref $ctr;
  my $value = LookupValue('\c@' . $ctr);
  if (!$value) {
    Warn('undefined', $ctr, $STATE->getStomach,
      "Counter '$ctr' was not defined; assuming 0");
    $value = Number(0); }
  return $value; }

sub AfterAssignment {
  if (my $after = $STATE->lookupValue('afterAssignment')) {
    $STATE->assignValue(afterAssignment => undef, 'global');
    $STATE->getStomach->getGullet->unread($after); } # primitive returns boxes, so these need to be digested!
  return; }

sub SetCounter {
  my ($ctr, $value) = @_;
  $ctr = ToString($ctr) if ref $ctr;
  AssignValue('\c@' . $ctr => $value, 'global');
  AfterAssignment();
  DefMacroI(T_CS("\\\@$ctr\@ID"), undef, Tokens(Explode($value->valueOf)), scope => 'global');
  return; }

sub AddToCounter {
  my ($ctr, $value) = @_;
  $ctr = ToString($ctr) if ref $ctr;
  my $v = CounterValue($ctr)->add($value);
  AssignValue('\c@' . $ctr => $v, 'global');
  AfterAssignment();
  DefMacroI(T_CS("\\\@$ctr\@ID"), undef, Tokens(Explode($v->valueOf)), scope => 'global');
  return; }

sub StepCounter {
  my ($ctr, $noreset) = @_;
  my $value = CounterValue($ctr);
  AssignValue("\\c\@$ctr" => $value->add(Number(1)), 'global');
  AfterAssignment();
  DefMacroI(T_CS("\\\@$ctr\@ID"), undef, Tokens(Explode(LookupValue('\c@' . $ctr)->valueOf)),
    scope => 'global');
  # and reset any within counters!
  if (!$noreset) {
    if (my $nested = LookupValue("\\cl\@$ctr")) {
      foreach my $c ($nested->unlist) {
        ResetCounter(ToString($c)); } } }
  DigestIf(T_CS("\\the$ctr"));
  return; }

# HOW can we retract this?
sub RefStepCounter {
  my ($type, $noreset) = @_;
  my $ctr = LookupMapping('counter_for_type', $type) || $type;
  StepCounter($ctr, $noreset);
  maybePreemptRefnum($ctr);
  my $iddef = $STATE->lookupDefinition(T_CS("\\the$ctr\@ID"));
  my $has_id = $iddef && ((!defined $iddef->getParameters) || ($iddef->getParameters->getNumArgs == 0));

  DefMacroI(T_CS('\@currentlabel'), undef, T_CS("\\the$ctr"), scope => 'global');
  DefMacroI(T_CS('\@currentID'), undef, T_CS("\\the$ctr\@ID"), scope => 'global') if $has_id;

  my $id = $has_id && CleanID(ToString(DigestLiteral(T_CS("\\the$ctr\@ID"))));

  my $refnum = DigestText(T_CS("\\the$ctr"));
  my $tags   = Digest(Invocation(T_CS('\lx@make@tags'), $type));
  # Any scopes activated for previous value of this counter (& any nested counters) must be removed.
  # This may also include scopes activated for \label
  deactivateCounterScope($ctr);
  # And install the scope (if any) for this reference number.
  AssignValue(current_counter => $ctr, 'local');
  my $scope = $ctr . ':' . ToString($refnum);
  AssignValue('scopes_for_counter:' . $ctr => [$scope], 'local');
  $STATE->activateScope($scope);
  return (
    ($tags   ? (tags => $tags) : ()),
    ($has_id ? (id   => $id)   : ())); }

# Internal: Use a label-derived reference number and/or ID
# instead of the traditional counter based ones.
# Since the \label{} determins the reference number and ID,
# we MUST sniff out the label BEFORE we call RefStepCounter/RefStepID !!!!!
# (see MaybePeekLabel below; and also MaybeNoteLabel for use within
# captions & certain equation environments)
# Assign a sub to LABEL_MAPPING_HOOK: &sub($label,$counter,$norefnum)
# to return the desired refnum and id for a given object.
sub maybePreemptRefnum {
  my ($ctr, $norefnum) = @_;
  if (my $mapper = LookupValue('LABEL_MAPPING_HOOK')) {
    my $hj_refnum = T_CS('\_PREEMPTED_REFNUM_' . $ctr);
    my $hj_id     = T_CS('\_PREEMPTED_ID_' . $ctr);
    # First, restore the \the<ctr> and \the<ctr>@ID macros to defaults
    if (!$norefnum && LookupMeaning($hj_refnum)) {
      Let(T_CS('\the' . $ctr), $hj_refnum, 'global'); }
    if (LookupMeaning($hj_id)) {
      Let(T_CS('\the' . $ctr . '@ID'), $hj_id, 'global'); }
    my $label = LookupValue('PEEKED_LABEL');
    my ($fixedrefnum, $fixedid) = &$mapper($label, $ctr, $norefnum);
    if (!$norefnum && $fixedrefnum) {
      if (!LookupMeaning($hj_refnum)) {    # Save for later
        Let($hj_refnum, T_CS('\the' . $ctr), 'global'); }
      DefMacroI('\the' . $ctr, undef, $fixedrefnum, scope => 'global'); }
    if ($fixedid) {
      if (!LookupMeaning($hj_id)) {        # Save for later
        Let($hj_id, T_CS('\the' . $ctr . '@ID'), 'global'); }
      DefMacroI('\the' . $ctr . '@ID', undef, $fixedid, scope => 'global'); }
    AssignValue(PEEKED_LABEL    => undef,  'global');    # CONSUME the label
    AssignValue(PROCESSED_LABEL => $label, 'global');    # Note that we've consumed the label
  }
  return; }

# Use to peek for FOLLOWING \label{...} to support label-derived refererence numbers
sub MaybePeekLabel {
  if (LookupValue('LABEL_MAPPING_HOOK')) {
    my $gullet = $STATE->getStomach->getGullet;
    my $peek   = $gullet->readNonSpace;
    if (Equals($peek, T_CS('\label'))) {
      StartSemiverbatim();
      my $arg = $gullet->readArg();
      EndSemiverbatim();
      my $label = CleanLabel($arg, '');
      AssignValue(PEEKED_LABEL => $label, 'global');
      $gullet->unread(T_BEGIN, $arg, T_END); }
    else {
      AssignValue(PROCESSED_LABEL => undef, 'global');
      AssignValue(PEEKED_LABEL    => undef, 'global'); }
    $gullet->unread($peek); }
  return; }

# Use to note a discovered label to support label-derived refererence numbers
# Can by used by \label, among others. Note we only record the label
# if it hasn't already been peeked, and consumed.
sub MaybeNoteLabel {
  my ($label) = @_;
  if (LookupValue('LABEL_MAPPING_HOOK')) {
    $label = CleanLabel($label, '');
    my $processed = LookupValue('PROCESSED_LABEL');
    if (!$processed || ($processed ne $label)) {    # Only if not already processed
      AssignValue(PROCESSED_LABEL => undef,  'global');
      AssignValue(PEEKED_LABEL    => $label, 'global'); } }
  return; }

sub deactivateCounterScope {
  my ($ctr) = @_;
  #  print STDERR "Unusing scopes for $ctr\n";
  if (my $scopes = LookupValue('scopes_for_counter:' . $ctr)) {
    map { $STATE->deactivateScope($_) } @$scopes; }
  foreach my $inner_ctr (@{ LookupValue('nested_counters_' . $ctr) || [] }) {
    deactivateCounterScope($inner_ctr); }
  return; }

# For UN-numbered units
sub RefStepID {
  my ($type) = @_;
  my $ctr   = LookupMapping('counter_for_type', $type) || $type;
  my $unctr = "UN$ctr";
  StepCounter($unctr);
  maybePreemptRefnum($ctr, 1);
  DefMacroI(T_CS("\\\@$ctr\@ID"), undef,
    Tokens(T_OTHER('x'), Explode(LookupValue('\c@' . $unctr)->valueOf)),
    scope => 'global');
  DefMacroI(T_CS('\@currentID'), undef, T_CS("\\the$ctr\@ID"));
  my $id = CleanID(ToString(DigestLiteral(T_CS("\\the$ctr\@ID"))));
  return (id => $id); }

sub ResetCounter {
  my ($ctr) = @_;
  AssignValue('\c@' . $ctr => Number(0), 'global');
  DefMacroI(T_CS("\\\@$ctr\@ID"), undef, Tokens(Explode(LookupValue('\c@' . $ctr)->valueOf)),
    scope => 'global');
  # and reset any within counters!
  if (my $nested = LookupValue("\\cl\@$ctr")) {
    foreach my $c ($nested->unlist) {
      ResetCounter(ToString($c)); } }
  return; }

#**********************************************************************
# This function computes an xml:id for a node, if it hasn't already got one.
# It is suitable for use in Tag afterOpen as
#  Tag('ltx:para',afterOpen=>sub { GenerateID(@_,'p'); });
# It generates an id of the form <parentid>.<prefix><number>
# The parent node (the one with ID=<parentid>) also maintains a counter
# stored in an attribute _ID_counter_<prefix> recording the last used
# <number> for <prefix> amongst its descendents.
sub GenerateID {
  my ($document, $node, $whatsit, $prefix) = @_;
  # If node doesn't already have an id, and can
  if (!$node->hasAttribute('xml:id') && $document->canHaveAttribute($node, 'xml:id')
    # but isn't a _Capture_ node (which ultimately should disappear)
    && ($document->getNodeQName($node) ne 'ltx:_Capture_')) {
    my $ancestor = $document->findnode('ancestor::*[@xml:id][1]', $node)
      || $document->getDocument->documentElement;
    ## Old versions don't like $ancestor->getAttribute('xml:id');
    my $ancestor_id = $ancestor && $ancestor->getAttributeNS($LaTeXML::Common::XML::XML_NS, 'id');
    # If we've got no $ancestor_id, then we've got no $ancestor (no document yet!),
    # or $ancestor IS the root element (but without an id);
    # If we also have no $prefix, we'll end up with an illegal id (just digits)!!!
    # We'll use "id" for an id prefix; this will work whether or not we have an $ancestor.
    $prefix = 'id' unless $prefix || $ancestor_id;

    my $ctrkey = '_ID_counter_' . (defined $prefix ? $prefix . '_' : '');
    my $ctr = ($ancestor && $ancestor->getAttribute($ctrkey)) || 0;

    my $id = ($ancestor_id ? $ancestor_id . "." : '') . (defined $prefix ? $prefix : '') . (++$ctr);
    $ancestor->setAttribute($ctrkey => $ctr) if $ancestor;
    $document->setAttribute($node, 'xml:id' => $id); }
  return; }

#======================================================================
#
#======================================================================

# Return $tokens with all tokens expanded
sub Expand {
  my (@tokens) = @_;
  return () unless @tokens;
  return $STATE->getStomach->getGullet->readingFromMouth(LaTeXML::Core::Mouth->new(), sub {
      my ($gullet) = @_;
      $gullet->unread(@tokens);
      my @expanded = ();
      while (defined(my $t = $gullet->readXToken(0))) {
        push(@expanded, $t); }
      return Tokens(@expanded); }); }

sub Invocation {
  my ($token, @args) = @_;
  $token = (ref $token ? $token : T_CS($token));
  # Note: $token may have been \let to another defn!
  if (my $defn = $STATE->lookupDefinition($token)) {
    my $params = $defn->getParameters;
    return Tokens($token, ($params ? $params->revertArguments(@args) : ())); }
  else {
    $STATE->generateErrorStub(undef, $token, convertLaTeXArgs(scalar(@args), 0));
    return Tokens($token, map { (T_BEGIN, $_->unlist, T_END) } @args); } }

sub RawTeX {
  my ($text) = @_;
  # It could be as simple as this, except if catcodes get changed, it's too late!!!
  #  Digest(TokenizeInternal($text));
  my $stomach = $STATE->getStomach;
  my $savedcc = $STATE->lookupCatcode('@');
  $STATE->assignCatcode('@' => CC_LETTER);

  $stomach->getGullet->readingFromMouth(LaTeXML::Core::Mouth->new($text, fordefinitions => 1), sub {
      my ($gullet) = @_;
      my $token;
      while ($token = $gullet->readXToken(0)) {
        next if $token->equals(T_SPACE);
        $stomach->invokeToken($token); } });

  $STATE->assignCatcode('@' => $savedcc);
  return; }

sub StartSemiverbatim {
  my (@chars) = @_;
  $STATE->beginSemiverbatim(@chars);
  return; }

sub EndSemiverbatim {
  $STATE->endSemiverbatim;
  return; }

# WARNING: These two utilities bind $STATE to simple State objects with known fixed catcodes.
# The State normally contains ALL the bindings, etc and links to other important objects.
# We CAN do that here, since we are ONLY tokenizing from a new Mouth, bypassing stomach & gullet.
# However, be careful with any changes.
our $STD_CATTABLE;
our $STY_CATTABLE;

# Tokenize($string); Tokenizes the string using the standard cattable, returning a LaTeXML::Core::Tokens
sub Tokenize {
  my ($string) = @_;
  $STD_CATTABLE = LaTeXML::Core::State->new(catcodes => 'standard') unless $STD_CATTABLE;
  local $STATE = $STD_CATTABLE;
  return LaTeXML::Core::Mouth->new($string)->readTokens; }

# TokenizeInternal($string); Tokenizes the string using the internal cattable, returning a LaTeXML::Core::Tokens
sub TokenizeInternal {
  my ($string) = @_;
  $STY_CATTABLE = LaTeXML::Core::State->new(catcodes => 'style') unless $STY_CATTABLE;
  local $STATE = $STY_CATTABLE;
  return LaTeXML::Core::Mouth->new($string)->readTokens; }

#======================================================================
# Non-exported support for defining forms.
#======================================================================
sub CheckOptions {
  my ($operation, $allowed, %options) = @_;
  my @badops = grep { !$$allowed{$_} } keys %options;
  Error('misdefined', $operation, $STATE->getStomach,
    "$operation does not accept options:" . join(', ', @badops)) if @badops;
  return; }

sub requireMath {
  my ($cs) = @_;
  $cs = ToString($cs);
  Warn('unexpected', $cs, $STATE->getStomach,
    "$cs should only appear in math mode") unless LookupValue('IN_MATH');
  return; }

sub forbidMath {
  my ($cs) = @_;
  $cs = ToString($cs);
  Warn('unexpected', $cs, $STATE->getStomach,
    "$cs should not appear in math mode") if LookupValue('IN_MATH');
  return; }

#**********************************************************************
# Definitions
#**********************************************************************
sub DefAutoload {
  my ($cs, $defnfile) = @_;
  my $csname = (ref $cs ? ToString($cs) : $cs);
  $csname = '\\' . $csname unless $cs =~ /^\\/;
  $cs     = T_CS($csname)  unless ref $cs;
  if ($defnfile =~ /^(.*?)\.(pool|sty|cls)\.ltxml$/) {
    my ($name, $type) = ($1, $2);
    if (!LookupValue($name . '.' . $type . '_loaded')) {    # if already loaded, DONT redefine!
      DefMacroI($cs, undef, sub {
          $STATE->assign_internal('meaning', $csname => undef, 'global');    # UNDEFINE (no recurse)
          if    ($type eq 'pool') { LoadPool($name); }                       # Load appropriate definitions
          elsif ($type eq 'cls')  { LoadClass($name); }
          else                    { RequirePackage($name); }
          ($cs); }); } }    # Then return the original cs, so that it's be re-tried.
  else {
    Warning('unexpected', $defnfile, undef, "Don't know how to autoload $csname from $defnfile"); }
  return; }

#======================================================================
# Defining Expandable Control Sequences.
#======================================================================
# Define an expandable control sequence. It will be expanded in the Gullet.
# The $replacement should be a LaTeXML::Core::Tokens (the arguments will be
# substituted for any #1,...), or a sub which returns a list of tokens (or just return;).
# Those tokens, if any, will be reinserted into the input.
# There are no options to these definitions.
my $expandable_options = {    # [CONSTANT]
  scope => 1, locked => 1 };

sub DefExpandable {
  my ($proto, $expansion, %options) = @_;
  Warn('deprecated', 'DefExpandable', $STATE->getStomach,
    "DefExpandable ($proto) is deprecated; use DefMacro");
  DefMacro($proto, $expansion, %options);
  return; }

# Define a Macro: Essentially an alias for DefExpandable
# For convenience, the $expansion can be a string which will be tokenized.
my $macro_options = {    # [CONSTANT]
  scope     => 1, locked => 1, mathactive => 1,
  protected => 1, outer  => 1, long       => 1 };

sub DefMacro {
  my ($proto, $expansion, %options) = @_;
  CheckOptions("DefMacro ($proto)", $macro_options, %options);
  DefMacroI(parsePrototype($proto), $expansion, %options);
  return; }

sub DefMacroI {
  my ($cs, $paramlist, $expansion, %options) = @_;
  if (!defined $expansion) { $expansion = Tokens(); }
  # Optimization: Defer till macro actually used
  #  elsif (!ref $expansion)     { $expansion = TokenizeInternal($expansion); }
  if ((length($cs) == 1) && $options{mathactive}) {
    $STATE->assignMathcode($cs => 0x8000, $options{scope}); }
  $cs = coerceCS($cs);
###  $paramlist = parseParameters($paramlist, $cs) if defined $paramlist && !ref $paramlist;
  $STATE->installDefinition(LaTeXML::Core::Definition::Expandable->new($cs, $paramlist, $expansion, %options),
    $options{scope});
  AssignValue(ToString($cs) . ":locked" => 1, 'global') if $options{locked};
  return; }

#======================================================================
# Defining Conditional Control Sequences.
#======================================================================
# Define a conditional control sequence. Its processing takes place in
# the Gullet.  The test is applied to the arguments (if any),
# which determines which branch is executed.
# If the test is undefined, the conditional is a "user defined" one;
# Two additional primitives are defined \footrue and \foofalse;
# the test is then determined by the most recently called of those.

# If you supply a skipper instead of a test, it is also applied to the arguments
# and should skip to the right place in the following \or, \else, \fi.
# This is ONLY used for \ifcase.
my $conditional_options = {    # [CONSTANT]
  scope => 1, locked => 1, skipper => 1 };

sub DefConditional {
  my ($proto, $test, %options) = @_;
  CheckOptions("DefConditional ($proto)", $conditional_options, %options);
  DefConditionalI(parsePrototype($proto), $test, %options);
  return; }

sub DefConditionalI {
  my ($cs, $paramlist, $test, %options) = @_;
  $cs = coerceCS($cs);
  my $csname = ToString($cs);
  # Special cases...
  if ($csname eq '\fi') {
    $STATE->installDefinition(LaTeXML::Core::Definition::Conditional->new(
        $cs, undef, undef, conditional_type => 'fi', %options),
      $options{scope}); }
  elsif ($csname eq '\else') {
    $STATE->installDefinition(LaTeXML::Core::Definition::Conditional->new(
        $cs, undef, undef, conditional_type => 'else', %options),
      $options{scope}); }
  elsif ($csname eq '\or') {
    $STATE->installDefinition(LaTeXML::Core::Definition::Conditional->new(
        $cs, undef, undef, conditional_type => 'or', %options),
      $options{scope}); }
  elsif ($csname eq '\unless') {
    $STATE->installDefinition(LaTeXML::Core::Definition::Conditional->new($cs, $paramlist, $test,
        conditional_type => 'unless', %options),
      $options{scope}); }
  elsif ($csname =~ /^\\if(.*)$/) {
    my $name = $1;
    if ((defined $name) && ($name ne 'case')
      && (!defined $test)) {    # user-defined conditional, like with \newif
      DefMacroI(T_CS('\\' . $name . 'true'),  undef, Tokens(T_CS('\let'), $cs, T_CS('\iftrue')));
      DefMacroI(T_CS('\\' . $name . 'false'), undef, Tokens(T_CS('\let'), $cs, T_CS('\iffalse')));
      Let($cs, T_CS('\iffalse')); }
    else {
      # For \ifcase, the parameter list better be a single Number !!
      $STATE->installDefinition(LaTeXML::Core::Definition::Conditional->new($cs, $paramlist, $test,
          conditional_type => 'if', %options),
        $options{scope}); }
  }
  else {
    Error('misdefined', $cs, $STATE->getStomach,
      "The conditional " . Stringify($cs) . " is being defined but doesn't start with \\if"); }
  AssignValue(ToString($cs) . ":locked" => 1) if $options{locked};
  return; }

sub IfCondition {
  my ($if, @args) = @_;
  my $gullet = $STATE->getStomach->getGullet;
  $if = coerceCS($if);
  my ($defn, $test);
  if (($defn = $STATE->lookupDefinition($if))
    && (($$defn{conditional_type} || '') eq 'if') && ($test = $defn->getTest)) {
    return &$test($gullet, @args); }
  elsif (XEquals($if, T_CS('\iftrue'))) {
    return 1; }
  elsif (XEquals($if, T_CS('\iffalse'))) {
    return 0; }
  else {
    Error('expected', 'conditional', $gullet,
      "Expected a conditional, got '" . ToString($if) . "'");
    return; } }

# Used only for regular \newif type conditions
sub SetCondition {
  my ($if, $value, $scope) = @_;
  my ($defn, $test);
  # We'll accept any conditional \ifxxx, providing it takes no arguments
  if (($defn = $STATE->lookupDefinition($if)) && (($$defn{conditional_type} || '') eq 'if')
    && !$defn->getParameters) {
    Let($if, ($value ? T_CS('\iftrue') : T_CS('\iffalse')), $scope) }
  else {
    Error('expected', 'conditional', $STATE->getStomach,
      "Expected a conditional defined by \\newif, got '" . ToString($if) . "'"); }
  return; }

#======================================================================
# Define a primitive control sequence.
#======================================================================
# Primitives are executed in the Stomach.
# The $replacement should be a sub which returns nothing, or a list of Box's or Whatsit's.
# The options are:
#    isPrefix  : 1 for things like \global, \long, etc.
#    registerType : for parameters (but needs to be worked into DefParameter, below).

my $primitive_options = {    # [CONSTANT]
  isPrefix => 1, scope => 1, mode => 1, font => 1,
  requireMath  => 1, forbidMath  => 1,
  beforeDigest => 1, afterDigest => 1,
  bounded => 1, locked => 1, alias => 1,
  outer   => 1, long   => 1 };

sub DefPrimitive {
  my ($proto, $replacement, %options) = @_;
  CheckOptions("DefPrimitive ($proto)", $primitive_options, %options);
  DefPrimitiveI(parsePrototype($proto), $replacement, %options);
  return; }

sub DefPrimitiveI {
  my ($cs, $paramlist, $replacement, %options) = @_;
#####  $replacement = sub { (); } unless defined $replacement;
  my $string = $replacement;
  $replacement = sub { Box($string, undef, undef, Invocation($options{alias} || $cs, @_[1 .. $#_])); }
    unless ref $replacement;
  $cs = coerceCS($cs);
###  $paramlist = parseParameters($paramlist, $cs) if defined $paramlist && !ref $paramlist;
  my $mode    = $options{mode};
  my $bounded = $options{bounded};
  $STATE->installDefinition(LaTeXML::Core::Definition::Primitive
      ->new($cs, $paramlist, $replacement,
      beforeDigest => flatten(($options{requireMath} ? (sub { requireMath($cs); }) : ()),
        ($options{forbidMath} ? (sub { forbidMath($cs); }) : ()),
        ($mode ? (sub { $_[0]->beginMode($mode); })
          : ($bounded ? (sub { $_[0]->bgroup; }) : ())),
        ($options{font} ? (sub { MergeFont(%{ $options{font} }); }) : ()),
        $options{beforeDigest}),
      afterDigest => flatten($options{afterDigest},
        ($mode ? (sub { $_[0]->endMode($mode) })
          : ($bounded ? (sub { $_[0]->egroup; }) : ()))),
      outer    => $options{outer},
      long     => $options{long},
      isPrefix => $options{isPrefix}),
    $options{scope});
  AssignValue(ToString($cs) . ":locked" => 1) if $options{locked};
  return; }

my $register_options = {    # [CONSTANT]
  readonly => 1, getter => 1, setter => 1, name => 1 };
my %register_types = (      # [CONSTANT]
  'LaTeXML::Common::Number'    => 'Number',
  'LaTeXML::Common::Dimension' => 'Dimension',
  'LaTeXML::Common::Glue'      => 'Glue',
  'LaTeXML::Core::MuGlue'      => 'MuGlue',
  'LaTeXML::Core::Tokens'      => 'Tokens',
  'LaTeXML::Core::Token'       => 'Token',
);

sub DefRegister {
  my ($proto, $value, %options) = @_;
  CheckOptions("DefRegister ($proto)", $register_options, %options);
  DefRegisterI(parsePrototype($proto), $value, %options);
  return; }

sub DefRegisterI {
  my ($cs, $paramlist, $value, %options) = @_;
  $cs = coerceCS($cs);
###  $paramlist = parseParameters($paramlist, $cs) if defined $paramlist && !ref $paramlist;
  my $type   = $register_types{ ref $value };
  my $name   = ToString($options{name} || $cs);
  my $getter = $options{getter}
    || sub { LookupValue(join('', $name, map { ToString($_) } @_)) || $value; };
  my $setter = $options{setter}
    || ($options{readonly}
    ? sub { my ($v, @args) = @_;
      Warn('unexpected', $name, $STATE->getStomach,
        "Can't assign readonly register $name to " . ToString($v)); return; }
    : sub { my ($v, @args) = @_;
      AssignValue(join('', $name, map { ToString($_) } @args) => $v); });
  # Not really right to set the value!
  AssignValue(ToString($cs) => $value) if defined $value;
  $STATE->installDefinition(LaTeXML::Core::Definition::Register->new($cs, $paramlist,
      replacement  => $name,
      registerType => $type,
      getter       => $getter, setter => $setter,
      readonly     => $options{readonly}),
    'global');
  return; }

sub LookupRegister {
  my ($cs, @parameters) = @_;
  my $defn;
  $cs = T_CS($cs) unless ref $cs;
  if (($defn = $STATE->lookupDefinition($cs)) && $defn->isRegister) {
    return $defn->valueOf(@parameters); }
  else {
    Warn('expected', 'register', $STATE->getStomach,
      "The control sequence " . ToString($cs) . " is not a register"); }
  return; }

sub LookupDimension {
  my ($cs) = @_;
  $cs = T_CS($cs) unless ref $cs;
  if (my $defn = $STATE->lookupDefinition($cs)) {
    if ($defn->isRegister) {    # Easy (and proper) case.
      return $defn->valueOf; }
    else {
      $STATE->getStomach->getGullet->readingFromMouth(LaTeXML::Core::Mouth->new(), sub { # start with empty mouth
          my ($gullet) = @_;
          $gullet->unread($cs);    # but put back tokens to be read
          return $gullet->readDimension; }); } }
  else {
    Warn('expected', 'register', $STATE->getStomach,
      "The control sequence " . ToString($cs) . " is not a register"); }
  return Dimension(0); }

sub AssignRegister {
  my ($cs, $value, @parameters) = @_;
  my $defn;
  $cs = T_CS($cs) unless ref $cs;
  if (($defn = $STATE->lookupDefinition($cs)) && $defn->isRegister) {
    return $defn->setValue($value, @parameters); }
  else {
    Warn('expected', 'register', $STATE->getStomach,
      "The control sequence " . ToString($cs) . " is not a register");
    return; } }

sub flatten {
  my (@stuff) = @_;
  return [map { (defined $_ ? (ref $_ eq 'ARRAY' ? @$_ : ($_)) : ()) } @stuff]; }

#======================================================================
# Define a constructor control sequence.
#======================================================================
# The arguments, if any, will be collected and processed in the Stomach, and
# a Whatsit will be constructed.
# It is the Whatsit that will be processed in the Document: It is responsible
# for constructing XML Nodes.  The $replacement should be a sub which inserts nodes,
# or a string specifying a constructor pattern (See somewhere).
#
# Options are:
#   bounded         : any side effects of before/after daemans are bounded; they are
#                     automatically enclosed by bgroup/egroup pair.
#   mode            : causes a switch into the given mode during the Whatsit building in the stomach.
#   reversion       : a string representing the preferred TeX form of the invocation.
#   beforeDigest    : code to be executed (in the stomach) before parsing & constructing the Whatsit.
#                     Can be used for changing modes, beginning groups, etc.
#   afterDigest     : code to be executed (in the stomach) after parsing & constructing the Whatsit.
#                     useful for setting Whatsit properties,
#   properties      : a hashref listing default values of properties to assign to the Whatsit.
#                     These properties can be used in the constructor.
my $constructor_options = {    # [CONSTANT]
  mode         => 1, requireMath => 1, forbidMath      => 1, font           => 1,
  alias        => 1, reversion   => 1, sizer           => 1, properties     => 1,
  nargs        => 1,
  beforeDigest => 1, afterDigest => 1, beforeConstruct => 1, afterConstruct => 1,
  captureBody  => 1, scope       => 1, bounded         => 1, locked         => 1,
  outer => 1, long => 1 };

sub inferSizer {
  my ($sizer, $reversion) = @_;
  return (defined $sizer ? $sizer
    : ((defined $reversion) && (!ref $reversion) && ($reversion =~ /^(?:#\w+)*$/)
      ? $reversion : undef)); }

sub DefConstructor {
  my ($proto, $replacement, %options) = @_;
  CheckOptions("DefConstructor ($proto)", $constructor_options, %options);
  DefConstructorI(parsePrototype($proto), $replacement, %options);
  return; }

sub DefConstructorI {
  my ($cs, $paramlist, $replacement, %options) = @_;
  $cs = coerceCS($cs);
###  $paramlist = parseParameters($paramlist, $cs) if defined $paramlist && !ref $paramlist;
  my $mode    = $options{mode};
  my $bounded = $options{bounded};
  $STATE->installDefinition(LaTeXML::Core::Definition::Constructor
      ->new($cs, $paramlist, $replacement,
      beforeDigest => flatten(($options{requireMath} ? (sub { requireMath($cs); }) : ()),
        ($options{forbidMath} ? (sub { forbidMath($cs); }) : ()),
        ($mode ? (sub { $_[0]->beginMode($mode); })
          : ($bounded ? (sub { $_[0]->bgroup; }) : ())),
        ($options{font} ? (sub { MergeFont(%{ $options{font} }); }) : ()),
        $options{beforeDigest}),
      afterDigest => flatten($options{afterDigest},
        ($mode ? (sub { $_[0]->endMode($mode) })
          : ($bounded ? (sub { $_[0]->egroup; }) : ()))),
      beforeConstruct => flatten($options{beforeConstruct}),
      afterConstruct  => flatten($options{afterConstruct}),
      nargs           => $options{nargs},
      alias           => $options{alias},
      reversion       => $options{reversion},
      sizer           => inferSizer($options{sizer}, $options{reversion}),
      captureBody     => $options{captureBody},
      properties      => $options{properties} || {},
      outer           => $options{outer},
      long            => $options{long}),
    $options{scope});
  AssignValue(ToString($cs) . ":locked" => 1) if $options{locked};
  return; }

#======================================================================
# Support for XMDual

# Perhaps it would be better to use a label(-like) indirection here,
# so all ID's can stay in the desired format?
sub getXMArgID {
  StepCounter('@XMARG');
  DefMacroI(T_CS('\@@XMARG@ID'), undef, Tokens(Explode(LookupValue('\c@@XMARG')->valueOf)),
    scope => 'global');
  return Expand(T_CS('\the@XMARG@ID')); }

# Given a list of Tokens (to be expanded into mathematical objects)
# return two lists:
#   (1) The Tokens' wrapped in an XMAarg, with an ID added
#   (2) a corresponding list of Tokens creating XMRef's to those IDs
# Ah, but there are complications!!!
# On the one hand, arguments may be hidden, never appearing on the presentation side
# (all will be passed to the content side); This argues for putting the XMArg's on the content side.
# OTOH, they ought to be on the presentation side, so that they can be expanded & digested in
# the proper context they will be presented, and pick up all the styling (font size, displaystyle..)
# I don't know how to work around the latter, so we'll put args on the presentation side,
# UNLESS they are hidden, in which case they'll be on the content side.
# So, how do we know if they're hidden? We'll scan the presentation for #\d, that's how!
sub dualize_arglist {
  my ($presentation, @args) = @_;
  my %used = ();
  $presentation = ToString($presentation);
  $presentation =~ s/#(\d)/{ $used{$1}++; }/ge;    # Get the args that were actually used!
  my (@cargs, @pargs);
  my $i = 0;
  foreach my $arg (@args) {
    $i++;
    if (!(defined $arg) || !$arg->unlist) {        # undefined or empty args, just pass through
      push(@pargs, $arg);
      push(@cargs, $arg); }
    elsif ($used{$i}) {                            # used in presentation?
      my $id = getXMArgID();
      push(@pargs, Invocation(T_CS('\@XMArg'), $id, $arg));    # put XMArg in presentation
      push(@cargs, Invocation(T_CS('\@XMRef'), $id)); }
    else {                                                     # Hidden arg, put XMArg in content.
      my $id = getXMArgID();
      push(@cargs, Invocation(T_CS('\@XMArg'), $id, $arg));
      push(@pargs, Invocation(T_CS('\@XMRef'), $id)); } }
  return ([@cargs], [@pargs]); }

# Given a list of XML nodes (either libxml nodes, or array representations)
# return a list of XMRef's referring to those nodes;
# ensure each source node has an ID (if already instanciated as XML)
# or _xmkey if still in array rep. since it will get an ID later, and the connection re-made)
# Note that ltx:XMHint nodes are ephemeral and shouldn't be ref'd!
# likewise, we avoid creating XMRefs to XMRefs
sub createXMRefs {
  my ($document, @args) = @_;
  my @refs = ();
  foreach my $arg (@args) {
    my $isarray = (ref $arg eq 'ARRAY');
    my $qname   = ($isarray ? $$arg[0] : $document->getNodeQName($arg));
    my $box     = ($isarray ? $$arg[1]{_box} : $document->getNodeBox($arg));
    # XMHint's are ephemeral, they may disappear; so just clone it w/o id
    if ($qname eq 'ltx:XMHint') {
      my %attr = ($isarray ? %{ $$arg[1] } : (map { $_->nodeName => $_->getValue } $arg->attributes));
      delete $attr{'xml:id'};
      push(@refs, [$qname, {%attr}]); }
    # Likewise, clone an XMRef (w/o any attributes or id ?) rather than create an XMRef to an XMRef.
    elsif ($qname eq 'ltx:XMRef') {
      my $key = ($isarray ? $$arg[1]{_xmkey} : $arg->getAttribute('_xmkey'));
      my $id  = ($isarray ? $$arg[1]{idref}  : $arg->getAttribute('idref'));
      push(@refs, [$qname, { _xmkey => $key, idref => $id, _box => $box }]); }
    else {
      if (my $id = ($isarray ? $$arg[1]{'xml:id'} : $arg->getAttribute('xml:id'))) {
        # $arg already has id, so refer to it.
        push(@refs, ['ltx:XMRef', { 'idref' => $id, _box => $box }]); }
      elsif ($isarray) {
        # $arg is not yet instanciated, so hasn't had chance to get auto-id; use _xmkey
        my $key = ToString(getXMArgID());
        $$arg[1]{'_xmkey'} = $key;
        push(@refs, ['ltx:XMRef', { '_xmkey' => $key, _box => $box }]); }
      else {
        # If arg is already XML, it's too late to get automatic ID's
        GenerateID($document, $arg, undef, '');
        push(@refs, ['ltx:XMRef', { 'idref' => $arg->getAttribute('xml:id'), _box => $box }]); } } }
  return @refs; }

# DefMath Define a Mathematical symbol or function.
# There are two sets of cases:
#  (1) If the presentation appears to be TeX code, we create an XMDual,
# since the presentation may end up with structure, etc.
#  (2) But if the presentation is a simple string, or unicode,
# it is just the content of the symbol; even if the function takes arguments.
# ALSO
#  arrange that the operator token gets cs="$cs"
# ALSO
#  Possibly some trick with SUMOP/INTOP affecting limits ?
#  Well, not exactly, but....
# HMM.... Still fishy.
# When to make a dual ?
# If the $presentation seems to be TeX (ie. it involves #1... but not ONLY!)
my $math_options = {    # [CONSTANT]
  name => 1, meaning       => 1, omcd    => 1, reversion => 1, sizer => 1, alias => 1,
  role => 1, operator_role => 1, reorder => 1, dual      => 1,
  mathstyle    => 1, font               => 1,
  scriptpos    => 1, operator_scriptpos => 1,
  stretchy     => 1, operator_stretchy  => 1,
  beforeDigest => 1, afterDigest        => 1, scope => 1, nogroup => 1, locked => 1,
  hide_content_reversion => 1 };
my $simpletoken_options = {    # [CONSTANT]
  name => 1, meaning   => 1, omcd  => 1, role   => 1, mathstyle => 1,
  font => 1, scriptpos => 1, scope => 1, locked => 1 };

sub DefMath {
  my ($proto, $presentation, %options) = @_;
  CheckOptions("DefMath ($proto)", $math_options, %options);
  DefMathI(parsePrototype($proto), $presentation, %options);
  return; }

sub DefMathI {
  my ($cs, $paramlist, $presentation, %options) = @_;
  $cs = coerceCS($cs);
  # Can't defer parsing parameters since we need to know number of args!
  $paramlist = parseParameters($paramlist, $cs) if defined $paramlist && !ref $paramlist;
  my $nargs   = ($paramlist ? scalar($paramlist->getParameters) : 0);
  my $csname  = $cs->getString;
  my $meaning = $options{meaning};
  my $name    = $options{alias} || $csname;
  # Avoid undefs specifically, we'll be doing string comparisons
  $presentation = '' unless defined $presentation;
  $meaning      = '' unless defined $meaning;
  $name =~ s/^\\//;
  $name = $options{name} if defined $options{name};
  $name = undef          if (defined $name)
    && (($name eq $presentation) || ($name eq '')
    || ($meaning eq $name));
  $options{name} = $name;
  $options{role} = 'UNKNOWN'
    if ($nargs == 0) && !defined $options{role};
  $options{operator_role} = 'UNKNOWN'
    if ($nargs > 0) && !defined $options{operator_role};
  # Store some data for introspection
  defmath_introspective($cs, $paramlist, $presentation, %options);

  # If single character, handle with a rewrite rule
  if (length($csname) == 1) {
    defmath_rewrite($cs, %options); }

  # If the macro involves arguments,
  # we will create an XMDual to separate simple content application
  # from the (likely) convoluted presentation.
  elsif ((ref $presentation eq 'CODE')
    || ((ref $presentation) && grep { $_->equals(T_PARAM) } $presentation->unlist)
    || (!(ref $presentation) && ($presentation =~ /\#\d|\\./))) {
    defmath_dual($cs, $paramlist, $presentation, %options); }
  # If no arguments, but the presentation involves macros, presumably with internal structure,
  # we'll wrap the presentation in ordet to capture the various semantic attributes
  elsif ((ref $presentation) && (grep { $_->isExecutable } $presentation->unlist)) {
    defmath_wrapped($cs, $presentation, %options); }

  # EXPERIMENT: Introduce an intermediate case for simple symbols
  # Define a primitive that will create a Box with the appropriate set of XMTok attributes.
  elsif (($nargs == 0) && !grep { !$$simpletoken_options{$_} } keys %options) {
    defmath_prim($cs, $paramlist, $presentation, %options); }
  else {
    defmath_cons($cs, $paramlist, $presentation, %options); }
  AssignValue($csname . ":locked" => 1) if $options{locked};
  return; }

sub defmath_introspective {
  my ($cs, $paramlist, $presentation, %options) = @_;
  # Store some data for introspection [should be optional?]
  my $nargs = ($paramlist ? scalar($paramlist->getParameters) : 0);
  AssignValue(join("##", "math_definition", $cs->getString, $nargs,
      $options{role} || $options{operator_role} || '', $options{name} || '',
      (defined $options{meaning} ? $options{meaning} : ''),
      $STATE->getStomach->getGullet->getMouth->getSource,
      (ref $presentation ? '' : $presentation)) => 1, global => 1);
  return; }

sub defmath_rewrite {
  my ($cs, %options) = @_;
  my $csname = $cs->getString;
  ####    $STATE->assignMathcode($csname=>0x8000, $options{scope}); }
  # No, do NOT make mathactive; screws up things like babel french, or... ?
  # EXPERIMENT: store XMTok attributes for if this char ends up a Math Token.
  # But only some DefMath options make sense!
  my $rw_options = { name => 1, meaning => 1, omcd => 1, role => 1, mathstyle => 1, stretchy => 1 }; # (well, mathstyle?)
  CheckOptions("DefMath reimplemented as DefRewrite ($csname)", $rw_options, %options);
  AssignValue('math_token_attributes_' . $csname => {%options}, 'global');
  return; }

sub defmath_common_constructor_options {
  my ($cs, $presentation, %options) = @_;
  my $sizer = inferSizer($options{sizer}, $options{reversion});
  return (
    alias => $options{alias} || $cs->getString,
    (defined $options{reversion} ? (reversion => $options{reversion}) : ()),
    (defined $sizer ? (sizer => $sizer) : ()),
    beforeDigest => flatten(sub { requireMath($cs->getString); },
      ($options{nogroup} ? () : (sub { $_[0]->bgroup; })),
      ($options{font} ? (sub { MergeFont(%{ $options{font} }); }) : ()),
      $options{beforeDigest}),
    afterDigest => flatten($options{afterDigest},
      ($options{nogroup} ? () : (sub { $_[0]->egroup; }))),
    beforeConstruct => flatten($options{beforeConstruct}),
    afterConstruct  => flatten($options{afterConstruct}),
    properties      => {
      name               => $options{name},
      meaning            => $options{meaning},
      omcd               => $options{omcd},
      role               => $options{role},
      operator_role      => $options{operator_role},
      mathstyle          => $options{mathstyle},
      scriptpos          => $options{scriptpos},
      operator_scriptpos => $options{operator_scriptpos},
      stretchy           => $options{stretchy},
      operator_stretchy  => $options{operator_stretchy},
      font               => ($options{mathstyle}
        ? sub { LookupValue('font')->merge(mathstyle => $options{mathstyle})->specialize($presentation); }
        : sub { LookupValue('font')->specialize($presentation); }) },
    scope => $options{scope}); }

# If the presentation is complex, and involves arguments,
# we will create an XMDual to separate content & presentation.
# This involves creating 3 control sequences:
#   \cs              macro that expands into \DUAL{pres}{content}
#   \cs@content      constructor creates the content branch
#   \cs@presentation macro that expands into code in the presentation branch.
# OK, this is getting a bit out-of-hand; I can't, myself, predict whether XMDual gets involved!
# The basic distinction seems to be whether the arguments are explicitly involved
# in the presentation form;
# This excludes (at least?) (OVER|UNDER)ACCENT's
sub defmath_dual {
  my ($cs, $paramlist, $presentation, %options) = @_;
  my $csname  = $cs->getString;
  my $cont_cs = T_CS($csname . "\@content");
  my $pres_cs = T_CS($csname . "\@presentation");
  # Make the original CS expand into a DUAL invoking a presentation macro and content constructor
  $STATE->installDefinition(LaTeXML::Core::Definition::Expandable->new($cs, $paramlist, sub {
        my ($self, @args) = @_;
        my ($cargs, $pargs) = dualize_arglist($presentation, @args);
        Invocation(T_CS('\DUAL'),
          Tokens(
            ($options{role}
              ? (T_OTHER('role'), T_OTHER('='), T_OTHER($options{role})) : ()),
            ($options{role} && $options{hide_content_reversion} ? (T_OTHER(',')) : ()),
            ($options{hide_content_reversion}
              ? (T_OTHER('hide_content_reversion'), T_OTHER('='), T_OTHER('true')) : ())),

          Invocation($cont_cs, @$cargs),
          Invocation($pres_cs, @$pargs))->unlist; }),
    $options{scope});
  # Make the presentation macro.
  $presentation = TokenizeInternal($presentation) unless ref $presentation;
  $STATE->installDefinition(LaTeXML::Core::Definition::Expandable->new($pres_cs, $paramlist, $presentation),
    $options{scope});
  my $nargs     = ($paramlist ? scalar($paramlist->getParameters) : 0);
  my $cons_attr = "name='#name' meaning='#meaning' omcd='#omcd' mathstyle='#mathstyle'";

  $STATE->installDefinition(LaTeXML::Core::Definition::Constructor->new($cont_cs, $paramlist,
      ($nargs == 0
        ? "<ltx:XMTok $cons_attr role='#role' scriptpos='#scriptpos' stretchy='#stretchy'/>"
        : "<ltx:XMApp role='#role' scriptpos='#scriptpos'>"
          . "<ltx:XMTok $cons_attr role='#operator_role'"
          . " scriptpos='#operator_scriptpos' stretchy='#operator_stretchy'/>"
          . join('', map { "#$_" }
            ($options{reorder} ? @{ $options{reorder} } : (1 .. $nargs)))
          . "</ltx:XMApp>"),
      defmath_common_constructor_options($cs, $presentation, %options)), $options{scope});
  return; }

# The case where there are NO arguments, but the presentation is (potentially) complex.
sub defmath_wrapped {
  my ($cs, $presentation, %options) = @_;
  my $csname  = $cs->getString;
  my $wrap_cs = T_CS($csname . "\@wrapper");
  my $pres_cs = T_CS($csname . "\@presentation");
  # Make the original CS expand into a wrapper constructor invoking a presentation
  $STATE->installDefinition(LaTeXML::Core::Definition::Expandable->new($cs, undef,
      Tokens($wrap_cs, T_BEGIN, $pres_cs, T_END)),
    $options{scope});
  # Make the presentation macro.
  $presentation = TokenizeInternal($presentation) unless ref $presentation;
  $STATE->installDefinition(LaTeXML::Core::Definition::Expandable->new($pres_cs, undef, $presentation),
    $options{scope});
  # Make the wrapper constructor
  my $cons_attr = "name='#name' meaning='#meaning' omcd='#omcd' mathstyle='#mathstyle'";
  $STATE->installDefinition(LaTeXML::Core::Definition::Constructor->new($wrap_cs,
      parseParameters('{}', $csname),
      "<ltx:XMWrap $cons_attr role='#role' scriptpos='#scriptpos' stretchy='#stretchy'>"
        . "#1"
        . "</ltx:XMWrap>",
      defmath_common_constructor_options($cs, $presentation, %options),
      reversion => sub { (($LaTeXML::DUAL_BRANCH || '') eq 'content' ? $cs : Revert($_[1])); }),
    $options{scope});
  return; }

sub defmath_prim {
  my ($cs, $paramlist, $presentation, %options) = @_;
  my $string  = ToString($presentation);
  my $reqfont = $options{font} || {};
  delete $options{locked};
  delete $options{font};
  $STATE->installDefinition(LaTeXML::Core::Definition::Primitive->new($cs, undef, sub {
        my ($stomach)  = @_;
        my $locator    = $stomach->getGullet->getLocator;
        my %properties = %options;
        my $font       = LookupValue('font')->merge(%$reqfont)->specialize($string);
        my $mode = (LookupValue('IN_MATH') ? 'math' : 'text');
        foreach my $key (keys %properties) {
          my $value = $properties{$key};
          if (ref $value eq 'CODE') {
            $properties{$key} = &$value(); } }
        LaTeXML::Core::Box->new($string, $font, $locator, $cs, mode => $mode, %properties); }));
  return; }

sub defmath_cons {
  my ($cs, $paramlist, $presentation, %options) = @_;
  # do we need to do anything about digesting the presentation?
  my $qpresentation = $presentation && ToString($presentation);    # Quote any constructor specials
  $qpresentation =~ s/(\#|\&|\?|\\)/\\$1/g if $presentation;
  my $end_tok   = (defined $presentation ? '>' . $qpresentation . '</ltx:XMTok>' : "/>");
  my $cons_attr = "name='#name' meaning='#meaning' omcd='#omcd' mathstyle='#mathstyle'";
  my $nargs     = ($paramlist ? scalar($paramlist->getParameters) : 0);
  $STATE->installDefinition(LaTeXML::Core::Definition::Constructor->new($cs, $paramlist,
      ($nargs == 0
          # If trivial presentation, allow it in Text
        ? ($presentation !~ /(?:\(|\)|\\)/
          ? "?#isMath(<ltx:XMTok role='#role' scriptpos='#scriptpos' stretchy='#stretchy'"
            . " font='#font' $cons_attr$end_tok)"
            . "($qpresentation)"
          : "<ltx:XMTok role='#role' scriptpos='#scriptpos' stretchy='#stretchy'"
            . " font='#font' $cons_attr$end_tok")
        : "<ltx:XMApp role='#role' scriptpos='#scriptpos' stretchy='#stretchy'>"
          . "<ltx:XMTok $cons_attr font='#font' role='#operator_role'"
          . " scriptpos='#operator_scriptpos' stretchy='#operator_stretchy' $end_tok"
          . join('', map { "<ltx:XMArg>#$_</ltx:XMArg>" } 1 .. $nargs)
          . "</ltx:XMApp>"),
      defmath_common_constructor_options($cs, $presentation,
        sizer => sub {
          #           my $font = $_[1]->getFont || LaTeXML::Common::Font->mathDefault;
          my $font = LaTeXML::Common::Font->mathDefault;
          $font->computeStringSize($presentation); },
        %options)), $options{scope});
  return; }

#======================================================================
# Define a LaTeX environment
# Note that the body of the environment is treated is the 'body' parameter in the constructor.
my $environment_options = {    # [CONSTANT]
  mode       => 1, requireMath => 1, forbidMath => 1,
  properties => 1, nargs       => 1, font       => 1,
  beforeDigest     => 1, afterDigest     => 1,
  afterDigestBegin => 1, beforeDigestEnd => 1, afterDigestBody => 1,
  beforeConstruct  => 1, afterConstruct  => 1,
  reversion        => 1, sizer           => 1, scope => 1, locked => 1 };

sub DefEnvironment {
  my ($proto, $replacement, %options) = @_;
  CheckOptions("DefEnvironment ($proto)", $environment_options, %options);
##  $proto =~ s/^\{([^\}]+)\}\s*//; # Pull off the environment name as {name}
##  my $paramlist=parseParameters($proto,"Environment $name");
##  my $name = $1;
  my ($name, $paramlist) = Text::Balanced::extract_bracketed($proto, '{}');
  $name      =~ s/[\{\}]//g;
  $paramlist =~ s/^\s*//;
##  $paramlist = parseParameters($paramlist, "Environment $name");
  DefEnvironmentI($name, $paramlist, $replacement, %options);
  return; }

sub DefEnvironmentI {
  my ($name, $paramlist, $replacement, %options) = @_;
  my $mode = $options{mode};
  $name = ToString($name) if ref $name;
##  $paramlist = parseParameters($paramlist, $name) if defined $paramlist && !ref $paramlist;
  # This is for the common case where the environment is opened by \begin{env}
  my $sizer = inferSizer($options{sizer}, $options{reversion});
  $STATE->installDefinition(LaTeXML::Core::Definition::Constructor
      ->new(T_CS("\\begin{$name}"), $paramlist, $replacement,
      beforeDigest => flatten(($options{requireMath} ? (sub { requireMath($name); }) : ()),
        ($options{forbidMath} ? (sub { forbidMath($name); }) : ()),
        sub { $_[0]->bgroup; },
        sub { my $b = LookupValue('@environment@' . $name . '@atbegin');
          ($b ? Digest(@$b) : ()); },
        ($mode ? (sub { $_[0]->setMode($mode); }) : ()),
        sub { AssignValue(current_environment => $name);
          DefMacroI('\@currenvir', undef, $name); },
        ($options{font} ? (sub { MergeFont(%{ $options{font} }); }) : ()),
        $options{beforeDigest}),
      afterDigest     => flatten($options{afterDigestBegin}),
      afterDigestBody => flatten($options{afterDigestBody}),
      beforeConstruct => flatten(sub { $STATE->pushFrame; }, $options{beforeConstruct}),
      # Curiously, it's the \begin whose afterConstruct gets called.
      afterConstruct => flatten($options{afterConstruct}, sub { $STATE->popFrame; }),
      nargs          => $options{nargs},
      captureBody    => 1,
      properties     => $options{properties} || {},
      (defined $options{reversion} ? (reversion => $options{reversion}) : ()),
      (defined $sizer ? (sizer => $sizer) : ()),
      ), $options{scope});
  $STATE->installDefinition(LaTeXML::Core::Definition::Constructor
      ->new(T_CS("\\end{$name}"), "", "",
      beforeDigest => flatten($options{beforeDigestEnd},
        sub { my $e = LookupValue('@environment@' . $name . '@atend');
          ($e ? Digest(@$e) : ()); },
      ),
      afterDigest => flatten($options{afterDigest},
        sub { my $env = LookupValue('current_environment');
          if (!$env || ($name ne $env)) {
            my @lines = ();
            my $nf    = $STATE->getFrameDepth;
            for (my $f = 0 ; $f <= $nf ; $f++) {    # Get currently open environments & locators
              if (my $e = $STATE->isValueBound('current_environment', $f)
                && $STATE->valueInFrame('current_environment', $f)) {
                my $locator = ToString($STATE->valueInFrame('groupInitiatorLocator', $f));
                push(@lines, $e . ' ' . $locator); } }
            Error('unexpected', "\\end{$name}", $_[0],
              "Can't close environment $name;", "Current are:", @lines); }
          return; },
        sub { $_[0]->egroup; },
      ),
      ), $options{scope});
  # For the uncommon case opened by \csname env\endcsname
  $STATE->installDefinition(LaTeXML::Core::Definition::Constructor
      ->new(T_CS("\\$name"), $paramlist, $replacement,
      beforeDigest => flatten(($options{requireMath} ? (sub { requireMath($name); }) : ()),
        ($options{forbidMath} ? (sub { forbidMath($name); })              : ()),
        ($mode                ? (sub { $_[0]->beginMode($mode); })        : ()),
        ($options{font}       ? (sub { MergeFont(%{ $options{font} }); }) : ()),
        $options{beforeDigest}),
      afterDigest     => flatten($options{afterDigestBegin}),
      afterDigestBody => flatten($options{afterDigestBody}),
      beforeConstruct => flatten(sub { $STATE->pushFrame; }, $options{beforeConstruct}),
      # Curiously, it's the \begin whose afterConstruct gets called.
      afterConstruct => flatten($options{afterConstruct}, sub { $STATE->popFrame; }),
      nargs          => $options{nargs},
      captureBody => T_CS("\\end$name"),           # Required to capture!!
      properties  => $options{properties} || {},
      (defined $options{reversion} ? (reversion => $options{reversion}) : ()),
      (defined $sizer ? (sizer => $sizer) : ()),
      ), $options{scope});
  $STATE->installDefinition(LaTeXML::Core::Definition::Constructor
      ->new(T_CS("\\end$name"), "", "",
      beforeDigest => flatten($options{beforeDigestEnd}),
      afterDigest  => flatten($options{afterDigest},
        ($mode ? (sub { $_[0]->endMode($mode); }) : ())),
      ), $options{scope});
  if ($options{locked}) {
    AssignValue("\\begin{$name}:locked" => 1);
    AssignValue("\\end{$name}:locked"   => 1);
    AssignValue("\\$name:locked"        => 1);
    AssignValue("\\end$name:locked"     => 1); }
  return; }

#======================================================================
# Declaring and Adjusting the Document Model.
#======================================================================

# Specify the properties of a Node tag.
my $tag_options = {    # [CONSTANT]
  autoOpen          => 1, autoClose          => 1, afterOpen => 1, afterClose => 1,
  'afterOpen:early' => 1, 'afterClose:early' => 1,
  'afterOpen:late'  => 1, 'afterClose:late'  => 1 };
my $tag_prepend_options = {    # [CONSTANT]
  'afterOpen:early' => 1, 'afterClose:early' => 1 };
my $tag_append_options = {     # [CONSTANT]
  'afterOpen'      => 1, 'afterClose'      => 1,
  'afterOpen:late' => 1, 'afterClose:late' => 1 };

sub Tag {
  my ($tag, %properties) = @_;
  CheckOptions("Tag ($tag)", $tag_options, %properties);
  my $model = $STATE->getModel;
  AssignMapping('TAG_PROPERTIES', $tag => {}) unless LookupMapping('TAG_PROPERTIES', $tag);
  my $props = LookupMapping('TAG_PROPERTIES', $tag);
  foreach my $key (keys %properties) {
    my $new = $properties{$key};
    my $old = $$props{$key};
    # These keys accumulate information which should not carry over daemon frames.
    if ($$tag_prepend_options{$key}) {
      $new = flatten($new, $old); }
    elsif ($$tag_append_options{$key}) {
      $new = flatten($old, $new); }
    $$props{$key} = $new; }
  return; }

sub DocType {
  my ($rootelement, $pubid, $sysid, %namespaces) = @_;
  my $model = $STATE->getModel;
  $model->setDocType($rootelement, $pubid, $sysid);
  foreach my $prefix (keys %namespaces) {
    $model->registerDocumentNamespace($prefix => $namespaces{$prefix}); }
  return; }

# What verb here? Set, Choose,...
sub RelaxNGSchema {
  my ($schema, %namespaces) = @_;
  my $model = $STATE->getModel;
  $model->setRelaxNGSchema($schema,);
  foreach my $prefix (keys %namespaces) {
    $model->registerDocumentNamespace($prefix => $namespaces{$prefix}); }
  return; }

sub RegisterNamespace {
  my ($prefix, $namespace) = @_;
  $STATE->getModel->registerNamespace($prefix => $namespace);
  return; }

sub RegisterDocumentNamespace {
  my ($prefix, $namespace) = @_;
  $STATE->getModel->registerDocumentNamespace($prefix => $namespace);
  return; }

#======================================================================
# Package, Class and File Loading
#======================================================================

# Does this test even make sense (or can it?)
# Shouldn't this more likely be dependent on the context?
# Ah, but what about \InputFileIfExists type stuff...
# should we assume a raw type can be processed if being read from within a raw type????
# yeah, that sounds about right...
my %definition_name = (    # [CONSTANT]
  sty   => 'package',              cls   => 'class', clo => 'class options',
  'cnf' => 'configuration',        'cfg' => 'configuration',
  'ldf' => 'language definitions', 'def' => 'definitions', 'dfu' => 'definitions');

sub pathname_is_raw {
  my ($pathname) = @_;
  return ($pathname =~ /\.(tex|pool|sty|cls|clo|cnf|cfg|ldf|def|dfu)$/); }

my $findfile_options = {    # [CONSTANT]
  type => 1, notex => 1, noltxml => 1 };

sub FindFile {
  my ($file, %options) = @_;
  $file = ToString($file);
  if ($options{raw}) {
    delete $options{raw};
    Warn('deprecated', 'raw', $STATE->getStomach->getGullet,
      "FindFile option raw is deprecated; it is not needed"); }
  CheckOptions("FindFile ($file)", $findfile_options, %options);
  if (pathname_is_literaldata($file)) {    # If literal protocol return immediately (unless notex!)
    return ($options{notex} ? undef : $file); }
  # If a known special protocol return immediately
  elsif (pathname_is_literaldata($file) || pathname_is_url($file)) {
    return $file; }
  # Otherwise, it's some kind of "real" file, and we might have to search for it
  if ($options{type}) {                    # Specific type requested? Search for it.
                                           # Add the extension, if it isn't already there.
    $file = $file . "." . $options{type} unless $file =~ /\.\Q$options{type}\E$/;
    return FindFile_aux($file, %options); }
  # If no type given, we MAY expect .tex, or maybe NOT!!
  elsif ($file =~ /\.tex$/) {    # No requested type, then .tex; Of course, it may already have it!
    return FindFile_aux($file, %options); }
  else {
    return FindFile_aux("$file.tex", %options) || FindFile_aux($file, %options); } }

sub FindFile_aux {
  my ($file, %options) = @_;
  my $path;
  # If cached, return simple path (it's a key into the cache)
  if (defined LookupValue($file . '_contents')) {
    return $file; }
  if (pathname_is_absolute($file)) {    # And if we've got an absolute path,
    if (!$options{noltxml}) {
      return $file . '.ltxml' if -f ($file . '.ltxml'); }    # No need to search, just check if it exists.
    return $file if -f $file;    # No need to search, just check if it exists.
    return; }                    # otherwise we're never going to find it.
  elsif (pathname_is_nasty($file)) {    # If it is a nasty filename, we won't touch it.
    return; }                           # we DO NOT want to pass this to kpathse or such!

  # Note that the strategy is complicated by the fact that
  # (1) we prefer .ltxml bindings, if present
  # (2) those MAY be present in kpsewhich's DB (although our searchpaths take precedence!)
  # (3) BUT we want to avoid kpsewhich if we can, since it's slower
  # (4) depending on switches we may EXCLUDE .ltxml OR raw tex OR allow both.
  my $paths       = LookupValue('SEARCHPATHS');
  my $urlbase     = LookupValue('URLBASE');
  my $nopaths     = LookupValue('REMOTE_REQUEST');
  my $ltxml_paths = $nopaths ? [] : $paths;
  # If we're looking for ltxml, look within our paths & installation first (faster than kpse)
  if (!$options{noltxml}) {
    if ($path = pathname_find("$file.ltxml", paths => $ltxml_paths, installation_subdir => 'Package')) {
      return $path; }
    elsif ($path = FindFile_fallback($file, $ltxml_paths, %options)) {
      return $path; } }
  # If we're looking for TeX, look within our paths & installation first (faster than kpse)
  if (!$options{notex}
    && ($path = pathname_find($file, paths => $paths))) {
    return $path; }
  # Otherwise, pass on to kpsewhich
  # Depending on flags, maybe search for ltxml in texmf or for plain tex in ours!
  # The main point, though, is to we make only ONE (more) call.
  return if grep { pathname_is_nasty($_) } @$paths;    # SECURITY! No nasty paths in cmdline
        # Do we need to sanitize these environment variables?
  my @candidates = (((!$options{noltxml} && !$nopaths) ? ("$file.ltxml") : ()),
    (!$options{notex} ? ($file) : ()));
  local $ENV{TEXINPUTS} = join($Config::Config{'path_sep'},
    @$paths, $ENV{TEXINPUTS} || $Config::Config{'path_sep'});
  if (my $result = pathname_kpsewhich(@candidates)) {
    return (-f $result ? $result : undef); }
  if ($urlbase && ($path = url_find($file, urlbase => $urlbase))) {
    return $path; }
  return; }

sub FindFile_fallback {
  my ($file, $ltxml_paths, %options) = @_;
  # Supported:
  # Numeric suffixes (version nums, dates) with optional separators
  my $fallback_file = $file;
  if ($fallback_file =~ s/\.(sty|cls)$//) {
    my $ltxtype = $1;
    my $discard = "";
    if ($fallback_file =~ s/([-_](?:arxiv|conference|workshop))$//) {
      # arxiv-specific suffixes, maybe move those out to an extension package?
      $discard = $1;
    }
    # TODO: If we want a Whitelist hash table -- add it here, before further regexing.
    if ($fallback_file =~ s/([-_]?v?[-_\d]+)$//) {
      $discard = "$1$discard";
    }
    if ($discard) {    # we had something to discard, so a new query is needed
      my $fallback_query = "$fallback_file.$ltxtype";
      if (my $path = pathname_find("$fallback_query.ltxml", paths => $ltxml_paths, installation_subdir => 'Package')) {
        Info('fallback', $file, $STATE->getStomach->getGullet,
"Interpreted $discard as a versioned package/class name, falling back to generic $fallback_query\n");
        return $path; } } }
  return; }

sub pathname_is_nasty {
  my ($pathname) = @_;
  return $pathname =~ /[^\w\-_\+\=\/\\\.~\:\s]/; }

sub maybeReportSearchPaths {
  if (LookupValue('SEARCHPATHS_REPORTED')) {
    return (); }
  else {
    AssignValue('SEARCHPATHS_REPORTED' => 1, 'global');
    return ("search paths are " . join(', ', @{ LookupValue('SEARCHPATHS') })); } }

my $inputcontent_options = {    # [CONSTANT]
  noerror => 1, type => 1 };

sub InputContent {
  my ($request, %options) = @_;
  CheckOptions("InputContent ($request)", $inputcontent_options, %options);
  if (my $path = FindFile($request, type => $options{type}, noltxml => 1)) {
    loadTeXContent($path); }
  elsif (!$options{noerror}) {
    # Consider it an error if we can't find a file of Content (in contrast to Definitions)
    Error('missing_file', $request, $STATE->getStomach->getGullet,
      "Can't find TeX file $request",
      maybeReportSearchPaths()); }
  return; }

# This is essentially the \input equivalent;
# we are most likely expecting to get actual content,
# (possibly with definitions included, as well)
# but might actually be getting pure definitions,
# (like a proper style file)
# in which case we may really want to load a latexml binding.
# Note that generic style files (non-latex) often have a .tex extension.
# But we may have implemented a .sty.ltxml, so we override the .tex.
# Is this actually safe, or should we be explicilty providing .tex.ltxml ?

my $input_options = {};    # [CONSTANT]

sub Input {
  my ($request, %options) = @_;
  $request = ToString($request);
  CheckOptions("Input ($request)", $input_options, %options);
  # HEURISTIC! First check if equivalent style file, but only under very specific circumstances
  if (pathname_is_literaldata($request)) {
    my ($dir, $name, $type) = pathname_split($request);
    my $file = $name; $file .= '.' . $type if $type;
    my $path;
    # Firstly, check if we are going to OVERRIDE the requested raw .tex file
    # with a latexml binding to a style file.
    if ((!$dir) && (!$type || ($type eq 'tex'))    # No SPECIFIC directory, but a raw tex file.
          # AND, in preamble; SHOULD be style file, OR also if we can't find the raw file.
      && (LookupValue('inPreamble') || !FindFile($file))
      && ($path = FindFile($name, type => 'sty', notex => 1))) {    # AND there IS such a style file
      Info('ignore', $request, $STATE->getStomach->getGullet,
        "Ignoring input of tex $request, using package $name instead");
      RequirePackage($name);    # Then override, assuming we'll find $name as a package file!
      return; } }
  # Next special case: If we were currently reading a "known" style or binding file,
  # then this file, even if .tex, must also be definitions rather than content.!!(?)
  if (LookupValue('INTERPRETING_DEFINITIONS')) {
    InputDefinitions($request); }
  elsif (my $path = FindFile($request)) {    # Found something plausible..
    my $type = (pathname_is_literaldata($path) ? 'tex' : pathname_type($path));

    # Should we be doing anything about options in the next 2 cases?..... I kinda think not, but?
    if ($type eq 'ltxml') {                  # it's a LaTeXML binding.
      loadLTXML($request, $path); }
    # Else some sort of "known" definitions type file, but not simply 'tex'
    elsif (($type ne 'tex') && (pathname_is_raw($path))) {
      loadTeXDefinitions($request, $path); }
    else {
      loadTeXContent($path); } }
  else {                                     # Couldn't find anything?
    $STATE->noteStatus(missing => $request);
    # We presumably are trying to input Content; an error if we can't find it (contrast to Definitions)
    Error('missing_file', $request, $STATE->getStomach->getGullet,
      "Can't find TeX file $request",
      maybeReportSearchPaths()); }
  return; }

# Pass in the "requested path" to the next two, since that's what gets
# recorded as having been loaded (by \@ifpackageloade, eg).
sub loadLTXML {
  my ($request, $pathname) = @_;
  # Note: $type will typically be ltxml and $name will include the .sty, .cls or whatever.
  # Note: we're NOT expecting (allowing?) either literal nor remote data objects here.
  if (my $p = pathname_is_literaldata($pathname) || pathname_is_url($pathname)) {
    Error('misdefined', 'loadLTXML', $STATE->getStomach->getGullet,
      "You can't load LaTeXML binding using protocol $p");
    return; }
  my ($dir, $name, $type) = pathname_split($pathname);
  # Don't load if the requested path was loaded (with or without the .ltxml)
  # We want to check against the original request, but WITH the type
  $request .= '.' . $type unless $request =~ /\Q.$type\E$/;    # make sure the .ltxml is added here
  my $trequest = $request; $trequest =~ s/\.ltxml$//;          # and NOT added here!
  return if LookupValue($request . '_loaded') || LookupValue($trequest . '_loaded');
  # Note (only!) that the ltxml version of this was loaded; still could load raw tex!
  AssignValue($request . '_loaded' => 1, 'global');

  $STATE->getStomach->getGullet->readingFromMouth(LaTeXML::Core::Mouth::Binding->new($pathname), sub {
      do $pathname;
      Fatal('die', $pathname, $STATE->getStomach->getGullet,
        "File $pathname had an error:\n  $@") if $@;
      # If we've opened anything, we should read it in completely.
      # But we'll assume that anything opened has already been processed by loadTeXDefinitions.
  });
  return; }

sub loadTeXDefinitions {
  my ($request, $pathname) = @_;
  if (!pathname_is_literaldata($pathname)) {    # We can't analyze literal data's pathnames!
    my ($dir, $name, $type) = pathname_split($pathname);
    # Don't load if we've already loaded it before.
    # Note that we'll still load it if we've already loaded only the ltxml version
    # since someone's presumably asking _explicitly_ for the raw TeX version.
    # It's probably even the ltxml version is asking for it!!
    # Of course, now it will be marked and wont get reloaded!
    return if LookupValue($request . '_loaded');
    AssignValue($request . '_loaded' => 1, 'global'); }

  my $stomach = $STATE->getStomach;
  # Note that we are reading definitions (and recursive input is assumed also definitions)
  my $was_interpreting = LookupValue('INTERPRETING_DEFINITIONS');
  # And that if we're interpreting this TeX file of definitions,
  # we probably should interpret any TeX files IT loads.
  my $was_including_styles = LookupValue('INCLUDE_STYLES');
  AssignValue('INTERPRETING_DEFINITIONS' => 1);
  # If we're reading in these definitions, probaly will accept included ones?
  # (but not forbid ltxml ?)
  AssignValue('INCLUDE_STYLES' => 1);
  # When set, this variable allows redefinitions of locked defns.
  # It is set in before/after methods to allow local rebinding of commands
  # but loading of sources & bindings is typically done in before/after methods of constructors!
  # This re-locks defns during reading of TeX packages.
  local $LaTeXML::Core::State::UNLOCKED = 0;
  $stomach->getGullet->readingFromMouth(
    LaTeXML::Core::Mouth->create($pathname,
      fordefinitions => 1, notes => 1,
      content        => LookupValue($pathname . '_contents')),
    sub {
      my ($gullet) = @_;
      my $token;
      while ($token = $gullet->readXToken(0)) {
        next if $token->equals(T_SPACE);
        $stomach->invokeToken($token); } });
  AssignValue('INTERPRETING_DEFINITIONS' => $was_interpreting);
  AssignValue('INCLUDE_STYLES'           => $was_including_styles);
  return; }

sub loadTeXContent {
  my ($pathname) = @_;
  my $gullet = $STATE->getStomach->getGullet;
  # If there is a file-specific declaration file (name.latexml), load it first!
  my $file = $pathname;
  $file =~ s/\.tex//;
  if (my $conf = !pathname_is_literaldata($pathname)
    && pathname_find("$file.latexml", paths => LookupValue('SEARCHPATHS'))) {
    loadLTXML($conf, $conf); }
  $gullet->openMouth(LaTeXML::Core::Mouth->create($pathname, notes => 1,
      content => LookupValue($pathname . '_contents')), 0);
  return; }

#======================================================================
# Option Handling for Packages and Classes

# Declare an option for the current package or class
# If $option is undef, it is the default.
# $code can be a sub (as a primitive), or a string to be expanded.
# (effectively a macro)

sub DeclareOption {
  my ($option, $code) = @_;
  $option = ToString($option) if ref $option;
  PushValue('@declaredoptions', $option) if $option;
  my $cs = ($option ? '\ds@' . $option : '\default@ds');
  # print STDERR "Declaring option: ".($option ? $option : '<default>')."\n";
  if ((!defined $code) || (ref $code eq 'CODE')) {
    DefPrimitiveI($cs, undef, $code); }
  else {
    DefMacroI($cs, undef, $code); }
  return; }

# Pass the sequence of @options to the package $name (if $ext is 'sty'),
# or class $name (if $ext is 'cls').
sub PassOptions {
  my ($name, $ext, @options) = @_;
  PushValue('opt@' . $name . '.' . $ext, map { ToString($_) } @options);
  # print STDERR "Passing to $name.$ext options: " . join(', ', @options) . "\n";
  return; }

# Process the options passed to the currently loading package or class.
# If inorder=>1, they are processed in the order given (like \ProcessOptions*),
# otherwise, they are processed in the order declared.
# Unless noundefine=>1 (like for \ExecuteOptions), all option definitions
# undefined after execution.
my $processoptions_options = {    # [CONSTANT]
  inorder => 1 };

sub ProcessOptions {
  my (%options) = @_;
  CheckOptions("ProcessOptions", $processoptions_options, %options);
  my $name = $STATE->lookupDefinition(T_CS('\@currname')) && ToString(Expand(T_CS('\@currname')));
  my $ext  = $STATE->lookupDefinition(T_CS('\@currext'))  && ToString(Expand(T_CS('\@currext')));
  my @declaredoptions = @{ LookupValue('@declaredoptions') };
  my @curroptions     = @{ (defined($name) && defined($ext)
        && LookupValue('opt@' . $name . '.' . $ext)) || [] };
  my @classoptions = @{ LookupValue('class_options') || [] };
  # print STDERR "\nProcessOptions for $name.$ext\n"
  #   . "  declared: " . join(',', @declaredoptions) . "\n"
  #   . "  provided: " . join(',', @curroptions) . "\n"
  #   . "  class: " . join(',', @classoptions) . "\n";

  my $defaultcs = T_CS('\default@ds');
  # Execute options in declared order (unless \ProcessOptions*)

  if ($options{inorder}) {    # Execute options in the order passed in (eg. \ProcessOptions*)
    foreach my $option (@classoptions) {    # process global options, but no error
      if (executeOption_internal($option)) { } }

    foreach my $option (@curroptions) {
      if    (executeOption_internal($option))        { }
      elsif (executeDefaultOption_internal($option)) { } } }
  else {                                    # Execute options in declared order (eg. \ProcessOptions)
    foreach my $option (@declaredoptions) {
      if (grep { $option eq $_ } @curroptions, @classoptions) {
        @curroptions = grep { $option ne $_ } @curroptions;    # Remove it, since it's been handled.
        executeOption_internal($option); } }
    # Now handle any remaining options (eg. default options), in the given order.
    foreach my $option (@curroptions) {
      executeDefaultOption_internal($option); } }
  # Now, undefine the handlers?
  foreach my $option (@declaredoptions) {
    Let('\ds@' . $option, '\relax'); }
  return; }

sub executeOption_internal {
  my ($option) = @_;
  my $cs = T_CS('\ds@' . $option);
  if ($STATE->lookupDefinition($cs)) {
    # print STDERR "\nPROCESS OPTION $option\n";
    DefMacroI('\CurrentOption', undef, $option);
    AssignValue('@unusedoptionlist',
      [grep { $_ ne $option } @{ LookupValue('@unusedoptionlist') || [] }]);
    Digest($cs);
    return 1; }
  else {
    return; } }

sub executeDefaultOption_internal {
  my ($option) = @_;
  # print STDERR "\nPROCESS DEFAULT OPTION $option\n";
  # presumably should NOT remove from @unusedoptionlist ?
  DefMacroI('\CurrentOption', undef, $option);
  Digest(T_CS('\default@ds'));
  return 1; }

sub ExecuteOptions {
  my (@options) = @_;
  my %unhandled = ();
  foreach my $option (@options) {
    if (executeOption_internal($option)) { }
    else {
      $unhandled{$option} = 1; } }
  foreach my $option (keys %unhandled) {
    Info('unexpected', $option, $STATE->getStomach->getGullet,
      "Unexpected options passed to ExecuteOptions '$option'"); }
  return; }

sub resetOptions {
  AssignValue('@declaredoptions', []);
  Let('\default@ds',
    (ToString(Expand(T_CS('\@currext'))) eq 'cls'
      ? '\OptionNotUsed' : '\@unknownoptionerror'));
  return; }

sub AddToMacro {
  my ($cs, @tokens) = @_;
  $cs = T_CS($cs) unless ref $cs;
  @tokens = map { (ref $_ ? $_ : TokenizeInternal($_)) } @tokens;
  # Needs error checking!
  my $defn = $STATE->lookupDefinition($cs);
  if (!defined $defn || !$defn->isExpandable) {
    Warn('unexpected', $cs, $STATE->getStomach->getGullet,
      ToString($cs) . " is not an expandable control sequence", "Ignoring addition"); }
  else {
    DefMacroI($cs, undef, Tokens($defn->getExpansion->unlist,
        map { $_->unlist } map { (ref $_ ? $_ : TokenizeInternal($_)) } @tokens),
      scope => 'global'); }
  return; }

#======================================================================
my $inputdefinitions_options = {    # [CONSTANT]
  options => 1, withoptions => 1, handleoptions => 1,
  type    => 1, as_class    => 1, noltxml       => 1, notex => 1, noerror => 1, after => 1 };
#   options=>[options...]
#   withoptions=>boolean : pass options from calling class/package
#   after=>code or tokens or string as $name.$type-h@@k macro. (executed after the package is loaded)
# Returns the path that was loaded, or undef, if none found.
sub InputDefinitions {
  my ($name, %options) = @_;
  $name = ToString($name) if ref $name;
  $name =~ s/^\s*//; $name =~ s/\s*$//;
  CheckOptions("InputDefinitions ($name)", $inputdefinitions_options, %options);

  my $prevname = $options{handleoptions} && $STATE->lookupDefinition(T_CS('\@currname')) && ToString(Expand(T_CS('\@currname')));
  my $prevext = $options{handleoptions} && $STATE->lookupDefinition(T_CS('\@currext')) && ToString(Expand(T_CS('\@currext')));

  # This file will be treated somewhat as if it were a class
  # IF as_class is true
  # OR if it is loaded by such a class, and has withoptions true!!! (yikes)
  $options{as_class} = 1 if $options{handleoptions} && $options{withoptions}
    && grep { $prevname eq $_ } @{ LookupValue('@masquerading@as@class') || [] };

  $options{raw} = 1 if $options{noltxml};    # so it will be read as raw by Gullet.!L!
  my $astype = ($options{as_class} ? 'cls' : $options{type});

  my $filename = $name;
  $filename .= '.' . $options{type} if $options{type};
  if ($options{options} && scalar(@{ $options{options} })) {
    if (my $prevoptions = LookupValue($filename . '_loaded_with_options')) {
      my $curroptions = join(',', @{ $options{options} });
      Info('unexpected', 'options', $STATE->getStomach->getGullet,
        "Option clash for file $filename with options '$curroptions'",
        "previously loaded with '$prevoptions'") unless $curroptions eq $prevoptions; } }
  if (my $file = FindFile($filename, type => $options{type},
      notex => $options{notex}, noltxml => $options{noltxml})) {
    if ($options{handleoptions}) {
      Digest(T_CS('\@pushfilename'));
      # For \RequirePackageWithOptions, pass the options from the outer class/style to the inner one.
      if (my $passoptions = $options{withoptions} && $prevname
        && LookupValue('opt@' . $prevname . "." . $prevext)) {
        # Only pass those class options that are declared by the package!
        my @declaredoptions = @{ LookupValue('@declaredoptions') };
        my @topass          = ();
        foreach my $op (@$passoptions) {
          push(@topass, $op) if grep { $op eq $_ } @declaredoptions; }
        PassOptions($name, $astype, @topass) if @topass; }
      DefMacroI('\@currname', undef, Tokens(Explode($name)));
      DefMacroI('\@currext',  undef, Tokens(Explode($astype)));
      # reset options (Note reset & pass were in opposite order in LoadClass ????)
      resetOptions();
      PassOptions($name, $astype, @{ $options{options} || [] });    # passed explicit options.
             # Note which packages are pretending to be classes.
      PushValue('@masquerading@as@class', $name) if $options{as_class};
      DefMacroI(T_CS('\\' . $name . '.' . $astype . '-h@@k'), undef, $options{after} || '');
      DefMacroI(T_CS('\opt@' . $name . '.' . $astype), undef,
        Tokens(Explode(join(',', @{ LookupValue('opt@' . $name . "." . $astype) }))));
    }
    AssignValue($filename . '_loaded_with_options' => join(',', @{ $options{options} }), 'global')
      if $options{options};

    my ($fdir, $fname, $ftype) = pathname_split($file);
    if ($options{handleoptions}) {
      # Add an appropriately faked entry into \@filelist
      my ($d, $n, $e) = ($fdir, $fname, $ftype);    # If ftype is ltxml, reparse to get sty/cls!
      ($d, $n, $e) = pathname_split(pathname_concat($d, $n)) if $e eq 'ltxml';    # Fake it???
      my @p = ($STATE->lookupDefinition(T_CS('\@filelist'))
        ? Expand(T_CS('\@filelist'))->unlist : ());
      my @n = Explode($e ? $n . '.' . $e : $n);
      DefMacroI('\@filelist', undef, (@p ? Tokens(@p, T_OTHER(','), @n) : Tokens(@n))); }
    if ($ftype eq 'ltxml') {
      loadLTXML($filename, $file); }                                              # Perl module.
    else {
      # Special case -- add a default resource if we're loading a raw .cls file as a first choice.
      # Raw class interpretations needs _some_ styling as baseline.
      if (!$options{noltxml} && ($file =~ /\.cls$/)) {
        RelaxNGSchema("LaTeXML");
        RequireResource('ltx-article.css'); }
      loadTeXDefinitions($filename, $file); }
    if ($options{handleoptions}) {
      Digest(T_CS('\\' . $name . '.' . $astype . '-h@@k'));
      DefMacroI('\@currname', undef, Tokens(Explode($prevname))) if $prevname;
      DefMacroI('\@currext',  undef, Tokens(Explode($prevext)))  if $prevext;
      Digest(T_CS('\@popfilename'));
      resetOptions(); }    # And reset options afterwards, too.
    return $file; }
  elsif (!$options{noerror}) {
    $STATE->noteStatus(missing => $name . ($options{type} ? '.' . $options{type} : ''));
    # We'll only warn about a missing file of definitions: it may be ignorable or never used.
    # if there ARE problems, they'll likely produce their own errors!
    Warn('missing_file', $name, $STATE->getStomach->getGullet,
      "Can't find "
        . ($options{notex} ? "binding for " : "")
        . (($options{type} && $definition_name{ $options{type} }) || 'definitions') . ' '
        . $name,
      "Anticipate undefined macros or environments",
      maybeReportSearchPaths()); }
  return; }

my $require_options = {    # [CONSTANT]
  options => 1, withoptions => 1, type => 1, as_class => 1,
  noltxml => 1, notex       => 1, raw  => 1, after    => 1 };
# This (& FindFile) needs to evolve a bit to support reading raw .sty (.def, etc) files from
# the standard texmf directories.  Maybe even use kpsewhich itself (INSTEAD of pathname_find ???)
# Another potentially useful option might be that if we are reading a raw file,
# perhaps it should just get digested immediately, since it shouldn't contribute any boxes.
sub RequirePackage {
  my ($package, %options) = @_;
  $package = ToString($package) if ref $package;
  if ($options{raw}) {
    delete $options{raw}; $options{notex} = 0;
    Warn('deprecated', 'raw', $STATE->getStomach->getGullet,
      "RequirePackage option raw is obsolete; it is not needed"); }
  CheckOptions("RequirePackage ($package)", $require_options, %options);
  # We'll usually disallow raw TeX, unless the option explicitly given, or globally set.
  $options{notex} = 1
    if !defined $options{notex} && !LookupValue('INCLUDE_STYLES') && !$options{noltxml};
  my $success = InputDefinitions($package, type => $options{type} || 'sty', handleoptions => 1,
    # Pass classes options if we have NONE!
    withoptions => !($options{options} && @{ $options{options} }),
    %options);
  maybeRequireDependencies($package, $options{type} || 'sty') unless $success;
  return; }

my $loadclass_options = {    # [CONSTANT]
  options => 1, withoptions => 1, after => 1, notex => 1 };

sub LoadClass {
  my ($class, %options) = @_;
  $options{notex} = 1
    if !defined $options{notex} && !LookupValue('INCLUDE_STYLES') && !$options{noltxml};

  $class = ToString($class) if ref $class;
  CheckOptions("LoadClass ($class)", $loadclass_options, %options);
  #  AssignValue(class_options => [$options{options} ? @{ $options{options} } : ()]);
  PushValue(class_options => ($options{options} ? @{ $options{options} } : ()));
  if (my $op = $options{options}) {
    # ? Expand {\zap@space#2 \@empty}%
    DefMacroI('\@classoptionslist', undef, join(',', @$op)); }
  # Note that we'll handle errors specifically for this case.
  if (my $success = InputDefinitions($class, type => 'cls', notex => $options{notex}, handleoptions => 1, noerror => 1,
      %options)) {
    return $success; }
  else {
    $STATE->noteStatus(missing => $class . '.cls');
    # Try guessing at an alternative class that we do have!
    # Find all class bindings (pathname_name twice for .cls.ltxml!!!)
    my @classes = sort { -(length($a) <=> length($b)) }
      map { pathname_name($_) } map { pathname_name($_) }
      pathname_findall('*', type => 'cls.ltxml', paths => LookupValue('SEARCHPATHS'),
      installation_subdir => 'Package');
    my ($alternate) = grep { $class =~ /^\Q$_\E/ } @classes;
    $alternate = 'OmniBus' unless $alternate;
    # Only Warn for missing style/class: we'll punt with an alternative;
    # there may come other errors from undefined macros, though.
    Warn('missing_file', $class, $STATE->getStomach->getGullet,
      "Can't find binding for class $class (using $alternate)",
      "Anticipate undefined macros or environments",
      maybeReportSearchPaths());
    if (my $success = InputDefinitions($alternate, type => 'cls', noerror => 1, handleoptions => 1, %options)) {
      maybeRequireDependencies($class, 'cls');
      return $success; }
    else {
      Fatal('missing_file', $alternate . '.cls.ltxml', $STATE->getStomach->getGullet,
        "Can't find binding for class $alternate (installation error)");
      return; } } }

sub LoadPool {
  my ($pool) = @_;
  $pool = ToString($pool) if ref $pool;
  if (my $success = InputDefinitions($pool, type => 'pool', notex => 1, noerror => 1)) {
    return $success; }
  else {
    Fatal('missing_file', "$pool.pool.ltxml", $STATE->getStomach->getGullet,
      "Can't find binding for pool $pool (installation error)",
      maybeReportSearchPaths());
    return; } }

# Somewhat an act of desperation in contexts like arXiv
# where we may have a bunch of random styles & classes that load other packages
# whose macros are then expected to be present.
# We scan the source for \RequirePackage & \usepackage and load the ones that have bindings.
# This is almost safe: the packages may only be loaded unconditionally, and we don't notice that!
sub maybeRequireDependencies {
  my ($file, $type) = @_;
  if (my $path = FindFile($file, type => $type, noltxml => 1)) {
    local $/ = undef;
    my $IN;
    if (open($IN, '<', $path)) {
      my $code = <$IN>;
      close($IN);
      my @classes  = ();
      my @packages = ();
      my %dups     = ();
      my $collect  = sub {
        my ($packages, $options) = @_;
        foreach my $p (split(/\s*,\s*/, $packages)) {
          if (!$dups{$p} && !LookupValue($p . '.sty.ltxml_loaded')) {
            push(@packages, [$p, $options]); $dups{$p} = 1; } } };
      # Yes, Regexps on TeX code! Ugh!!! Well, this is an act of desperation anyway :>
      $code =~ s/%[^\n]*\n//gs;    # strip comments
      $code =~ s/\\RequirePackage\s*(?:\[([^\]]*)\])?\s*\{([^\}]*)\}/ &$collect($2,$1); /xegs;
      # Ugh. \usepackage, too
      $code =~ s/\\usepackage\s*(?:\[([^\]]*)\])?\s*\{([^\}]*)\}/ &$collect($2,$1); /xegs;
      # Even more ugh; \LoadClass
      if ($type eq 'cls') {
        $code =~ s/\\LoadClass\s*(?:\[([^\]]*)\])?\s*\{([^\}]*)\}/ push(@classes,[$2,$1]); /xegs; }

      Info('dependencies', 'dependencies', undef,
"Loading dependencies for $path: " . join(',', map { $$_[0]; } @classes, @packages)) if scalar(@classes) || scalar(@packages);
      foreach my $pair (@classes) {
        my ($class, $options) = @$pair;
        if (FindFile($class, type => 'cls', notex => 1)) {
          LoadClass($class, ($options ? (options => [split(/\s*,\s*/, $options)]) : ())); } }
      foreach my $pair (@packages) {
        my ($package, $options) = @$pair;
        if (FindFile($package, type => 'sty', notex => 1)) {
          RequirePackage($package, ($options ? (options => [split(/\s*,\s*/, $options)]) : ())); } } }
    else {
      Warn('I/O', 'read', undef, "Couldn't open $path to scan dependencies", $!); } }
  return; }

sub AtBeginDocument {
  my (@operations) = @_;
  AssignValue('@at@begin@document', []) unless LookupValue('@at@begin@document');
  foreach my $op (@operations) {
    next unless $op;
    my $t = ref $op;
    if (!$t) {    # Presumably String?
      $op = TokenizeInternal($op); }
    elsif ($t eq 'CODE') {
      my $tn = T_CS(ToString($op));
      DefMacroI($tn, undef, $op);
      $op = $tn; }
    PushValue('@at@begin@document', $op->unlist); }
  return; }

sub AtEndDocument {
  my (@operations) = @_;
  AssignValue('@at@end@document', []) unless LookupValue('@at@end@document');
  foreach my $op (@operations) {
    next unless $op;
    my $t = ref $op;
    if (!$t) {    # Presumably String?
      $op = TokenizeInternal($op); }
    elsif ($t eq 'CODE') {
      my $tn = T_CS(ToString($op));
      DefMacroI($tn, undef, $op);
      $op = $tn; }
    PushValue('@at@end@document', $op->unlist); }
  return; }

#======================================================================
#
my $fontmap_options = {    # [CONSTANT]
  family => 1 };

sub DeclareFontMap {
  my ($name, $map, %options) = @_;
  CheckOptions("DeclareFontMap", $fontmap_options, %options);
  my $mapname = ToString($name)
    . ($options{family} ? '_' . $options{family} : '')
    . '_fontmap';
  AssignValue($mapname => $map, 'global');
  return; }

# Decode a codepoint using the fontmap for a given font and/or fontencoding.
# If $encoding not provided, then lookup according to the current font's
# encoding; the font family may also be used to choose the fontmap (think tt fonts!).
# When $implicit is false, we are "explicitly" asking for a decoding, such as
# with \char, \mathchar, \symbol, DeclareTextSymbol and such cases.
# In such cases, only codepoints specifically within the map are covered; the rest are undef.
# If $implicit is true, we'll decode token content that has made it to the stomach:
# We're going to assume that SOME sort of handling of input encoding is taking place,
# so that if anything above 128 comes in, it must already be Unicode!.
# The lower half plane still needs to go through decoding, though, to deal
# with TeX's rearrangement of ASCII...
sub FontDecode {
  my ($code, $encoding, $implicit) = @_;
  return if !defined $code || ($code < 0);
  my ($map, $font);
  if (!$encoding) {
    $font     = LookupValue('font');
    $encoding = $font->getEncoding || 'OT1'; }
  if ($encoding && ($map = LoadFontMap($encoding))) {    # OK got some map.
    my ($family, $fmap);
    if ($font && ($family = $font->getFamily) && ($fmap = LookupValue($encoding . '_' . $family . '_fontmap'))) {
      $map = $fmap; } }                                  # Use the family specific map, if any.
  if ($implicit) {
    if ($map && ($code < 128)) {
      return $$map[$code]; }
    else {
      return pack('U', $code); } }
  else {
    return ($map ? $$map[$code] : undef); } }

sub FontDecodeString {
  my ($string, $encoding, $implicit) = @_;
  return if !defined $string;
  my ($map, $font);
  if (!$encoding) {
    $font     = LookupValue('font');
    $encoding = $font->getEncoding; }
  if ($encoding && ($map = LoadFontMap($encoding))) {    # OK got some map.
    my ($family, $fmap);
    if ($font && ($family = $font->getFamily) && ($fmap = LookupValue($encoding . '_' . $family . '_fontmap'))) {
      $map = $fmap; } }                                  # Use the family specific map, if any.

  return join('', grep { defined $_ }
      map { ($implicit ? (($map && ($_ < 128)) ? $$map[$_] : pack('U', $_))
        : ($map ? $$map[$_] : undef)) }
      map { ord($_) } split(//, $string)); }

sub LoadFontMap {
  my ($encoding) = @_;
  my $map = LookupValue($encoding . '_fontmap');
  if (!$map && !LookupValue($encoding . '_fontmap_failed_to_load')) {
    AssignValue($encoding . '_fontmap_failed_to_load' => 1);    # Stop recursion?
    RequirePackage(lc($encoding), type => 'fontmap');
    if ($map = LookupValue($encoding . '_fontmap')) {           # Got map?
      AssignValue($encoding . '_fontmap_failed_to_load' => 0); }
    else {
      AssignValue($encoding . '_fontmap_failed_to_load' => 1, 'global'); } }
  return $map; }

#======================================================================
# Color
sub LookupColor {
  my ($name) = @_;
  if (my $color = LookupValue('color_' . $name)) {
    return $color; }
  else {
    Error('undefined', $name, $STATE->getStomach, "color '$name' is undefined...");
    return Black; } }

sub DefColor {
  my ($name, $color, $scope) = @_;
  #print STDERR "DEFINE ".ToString($name)." => ".join(',',@$color)."\n";
  return unless ref $color;
  my ($model, @spec) = @$color;
  $scope = 'global' if $STATE->lookupDefinition(T_CS('\ifglobalcolors')) && IfCondition(T_CS('\ifglobalcolors'));
  AssignValue('color_' . $name => $color, $scope);
  # We could store these pieces separately,or in a list for above,
  # so that extract could use them more reasonably?
  # This is perhaps too xcolor specific?
  DefMacroI('\\\\color@' . $name, undef,
    '\relax\relax{' . join(' ', $model, @spec) . '}{' . $model . '}{' . join(',', @spec) . '}',
    scope => $scope);
  return; }

# Need 3 things for Derived Models:
#   derivedfrom  : the core model that this model is "derived from"
#   convertto    : code to convert to the (a) core model
#   convertfrom  : code to convert from the core model
sub DefColorModel {
  my ($model, $coremodel, $tocore, $fromcore) = @_;
  AssignValue('derived_color_model_' . $model => [$coremodel, $tocore, $fromcore], 'global');
  return; }

#======================================================================
# Defining Rewrite rules that act on the DOM
# These are applied after the document is completely constructed
my $rewrite_options = {    # [CONSTANT]
  label      => 1, scope   => 1, xpath  => 1, match  => 1,
  attributes => 1, replace => 1, regexp => 1, select => 1 };

sub DefRewrite {
  my (@specs) = @_;
  CheckOptions("DefRewrite", $rewrite_options, @specs);
  PushValue('DOCUMENT_REWRITE_RULES',
    LaTeXML::Core::Rewrite->new('text', processRewriteSpecs(0, @specs)));
  return; }

sub DefMathRewrite {
  my (@specs) = @_;
  CheckOptions("DefMathRewrite", $rewrite_options, @specs);
  PushValue('DOCUMENT_REWRITE_RULES',
    LaTeXML::Core::Rewrite->new('math', processRewriteSpecs(1, @specs)));
  return; }

sub processRewriteSpecs {
  my ($math, @specs) = @_;
  my @procspecs = ();
  my $delimiter = ($math ? '$' : '');
  while (@specs) {
    my $k = shift(@specs);
    my $v = shift(@specs);
    # Make sure match & replace are (at least) tokenized
    if (($k eq 'match') || ($k eq 'replace')) {
      if (ref $v eq 'ARRAY') {
        $v = [map { (ref $_ ? $_ : Tokenize($delimiter . $_ . $delimiter)) } @$v]; }
      elsif (!ref $v) {
        $v = Tokenize($delimiter . $v . $delimiter); } }
    push(@procspecs, $k, $v); }
  return @procspecs; }

#======================================================================
# Defining "Ligatures" rules that act on the DOM
# These are actually a sort of rewrite that is applied while the doom
# is being constructed, in particular as each node is closed.

my $ligature_options = {    # [CONSTANT]
  fontTest => 1 };

sub DefLigature {
  my ($regexp, $replacement, %options) = @_;
  CheckOptions("DefLigature", $ligature_options, %options);
  UnshiftValue('TEXT_LIGATURES',
    { regexp => $regexp,
      code => sub { $_[0] =~ s/$regexp/$replacement/g; $_[0]; },
      %options });
  return; }

my $old_math_ligature_options = {};                                                     # [CONSTANT]
my $math_ligature_options     = { matcher => 1, role => 1, name => 1, meaning => 1 };   # [CONSTANT]

sub DefMathLigature {
  if ((scalar(@_) % 2) == 1) {                                                          # Old style!
    my ($matcher, %options) = @_;
    Info('deprecated', 'ligature', undef, "Old style arguments to DefMathLigature; please update");
    CheckOptions("DefMathLigature", $old_math_ligature_options, %options);
    UnshiftValue('MATH_LIGATURES', { old_style => 1, matcher => $matcher }); }          # Install it...
  else {                                                                                # new style!
    my (%options) = @_;
    my $matcher = $options{matcher};
    delete $options{matcher};
    my ($pattern) = grep { !$$math_ligature_options{$_} } keys %options;
    my $replacement = $pattern && $options{$pattern};
    delete $options{$pattern} if $replacement;
    CheckOptions("DefMathLigature", $math_ligature_options, %options);    # Check remaining options
    if ($matcher && $pattern) {
      Error('misdefined', 'MathLigature', undef,
        "DefMathLigature only gets one of matcher or pattern=>replacement keywords");
      return; }
    elsif ($pattern) {
      my @chars    = reverse(split(//, $pattern));
      my $ntomatch = scalar(@chars);
      my %attr     = %options;
      $matcher = sub {
        my ($document, $node) = @_;
        foreach my $char (@chars) {
          return unless
            ($node
            && ($document->getModel->getNodeQName($node) eq 'ltx:XMTok')
            && (($node->textContent || '') eq $char));
          $node = $node->previousSibling; }
        return ($ntomatch, $replacement, %attr); }; }
    elsif (!$matcher) {
      Error('misdefined', 'MathLigature', undef,
        "DefMathLigature missing matcher or pattern=>replacement keywords");
      return; }
    UnshiftValue('MATH_LIGATURES', { matcher => $matcher }); }    # Install it...
  return; }

#======================================================================
# Support for requiring "Resources", ie CSS, Javascript, whatever

my $resource_options = {    # [CONSTANT]
  type => 1, media => 1, content => 1 };
my $resource_types = {      # [CONSTANT]
  css => 'text/css', js => 'text/javascript' };

sub RequireResource {
  my ($resource, %options) = @_;
  CheckOptions("RequireResource", $resource_options, %options);
  if (!$options{content} && !$resource) {
    Warn('expected', 'resource', undef, "Resource must have a resource pathname or content; skipping");
    return; }
  if (!$options{type}) {
    my $ext = $resource && pathname_type($resource);
    $options{type} = $ext && $$resource_types{$ext}; }
  if (!$options{type}) {
    my $ext = $resource && pathname_type($resource);
    my $t   = $ext      && $$resource_types{$ext};
    Warn('expected', 'type', undef, "Resource must have a mime-type; skipping"); return; }

  if ($LaTeXML::DOCUMENT) {    # If we've got a document, go ahead & put the resource in.
    addResource($LaTeXML::DOCUMENT, $resource, %options); }
  else {
    AssignValue(PENDING_RESOURCES => [], 'global') unless LookupValue('PENDING_RESOURCES');
    PushValue(PENDING_RESOURCES => [$resource, %options]); }
  return; }

# No checking...
sub addResource {
  my ($document, $resource, %options) = @_;
  my $savenode = $document->floatToElement('ltx:resource');
  $document->insertElement('ltx:resource', $options{content},
    src => $resource, type => $options{type}, media => $options{media});
  $document->setNode($savenode) if $savenode;
  return; }

sub ProcessPendingResources {
  my ($document) = @_;
  if (my $resources = LookupValue('PENDING_RESOURCES')) {
    my %seen             = ();
    my @unique_resources = grep { my $new = !$seen{$_}; $seen{$_} = 1; $new; } @$resources;
    for my $resource (@unique_resources) {
      addResource($document, @$resource); }
    AssignValue(PENDING_RESOURCES => [], 'global'); }
  return; }

#**********************************************************************
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Package> - Support for package implementations and document customization.

=head1 SYNOPSIS

This package defines and exports most of the procedures users will need
to customize or extend LaTeXML. The LaTeXML implementation of some package
might look something like the following, but see the
installed C<LaTeXML/Package> directory for realistic examples.

  package LaTeXML::Package::pool;  # to put new subs & variables in common pool
  use LaTeXML::Package;            # to load these definitions
  use strict;                      # good style
  use warnings;
  #
  # Load "anotherpackage"
  RequirePackage('anotherpackage');
  #
  # A simple macro, just like in TeX
  DefMacro('\thesection', '\thechapter.\roman{section}');
  #
  # A constructor defines how a control sequence generates XML:
  DefConstructor('\thanks{}', "<ltx:thanks>#1</ltx:thanks>");
  #
  # And a simple environment ...
  DefEnvironment('{abstract}','<abstract>#body</abstract>');
  #
  # A math  symbol \Real to stand for the Reals:
  DefMath('\Real', "\x{211D}", role=>'ID');
  #
  # Or a semantic floor:
  DefMath('\floor{}','\left\lfloor#1\right\rfloor');
  #
  # More esoteric ...
  # Use a RelaxNG schema
  RelaxNGSchema("MySchema");
  # Or use a special DocType if you have to:
  # DocType("rootelement",
  #         "-//Your Site//Your DocType",'your.dtd',
  #          prefix=>"http://whatever/");
  #
  # Allow sometag elements to be automatically closed if needed
  Tag('prefix:sometag', autoClose=>1);
  #
  # Don't forget this, so perl knows the package loaded.
  1;


=head1 DESCRIPTION

This module provides a large set of utilities and declarations that are useful
for writing `bindings': LaTeXML-specific implementations of a set of control
sequences such as would be defined in a LaTeX style or class file. They are also
useful for controlling and customization of LaTeXML's processing.
See the L</"See also"> section, below, for additional lower-level modules imported & re-exported.

To a limited extent (and currently only when explicitly enabled), LaTeXML can process
the raw TeX code found in style files.  However, to preserve document structure
and semantics, as well as for efficiency, it is usually necessary to supply a
LaTeXML-specific `binding' for style and class files. For example, a binding
C<mypackage.sty.ltxml> would encode LaTeXML-specific implementations of
all the control sequences in C<mypackage.sty> so that C<\usepackage{mypackage}> would work.
Similarly for C<myclass.cls.ltxml>.  Additionally, document-specific bindings can
be supplied: before processing a TeX source file, eg C<mydoc.tex>, LaTeXML
will automatically include the definitions and settings in C<mydoc.latexml>.
These C<.ltxml> and C<.latexml> files should be placed LaTeXML's searchpaths, where will
find them: either in the current directory or in a directory given to the --path option,
or possibly added to the variable SEARCHPATHS).

Since LaTeXML mimics TeX, a familiarity with TeX's processing model is critical.
LaTeXML models: catcodes and tokens
(See L<LaTeXML::Core::Token>,  L<LaTeXML::Core::Tokens>) which are extracted
from the plain source text characters by the L<LaTeXML::Core::Mouth>;
L</Macros>, which are expanded within the L<LaTeXML::Core::Gullet>;
and L</Primitives>, which are digested within the L<LaTeXML::Core::Stomach>
to produce L<LaTeXML::Core::Box>, L<LaTeXML::Core::List>.
A key additional feature is the L</Constructors>:
when digested they generate a L<LaTeXML::Core::Whatsit> which, upon absorbtion by
L<LaTeXML::Core::Document>, inserts text or XML fragments in the final document tree.


I<Notation:> Many of the following forms take code references as arguments or options.
That is, either a reference to a defined sub, eg. C<\&somesub>, or an
anonymous function C<sub { ... }>.  To document these cases, and the
arguments that are passed in each case, we'll use a notation like
C<I<code>($stomach,...)>.

=head2 Control Sequences

Many of the following forms define the behaviour of control sequences.
While in TeX you'll typically only define macros, LaTeXML is effectively redefining TeX itself,
so we define L</Macros> as well as L</Primitives>, L</Registers>,
L</Constructors> and L</Environments>.
These define the behaviour of these control sequences when processed during the various
phases of LaTeX's imitation of TeX's digestive tract.

=head3 Prototypes

LaTeXML uses a more convienient method of specifying parameter patterns for
control sequences. The first argument to each of these defining forms
(C<DefMacro>, C<DefPrimive>, etc) is a I<prototype> consisting of the control
sequence being defined along with the specification of parameters required by the control sequence.
Each parameter describes how to parse tokens following the control sequence into
arguments or how to delimit them.  To simplify coding and capture common idioms
in TeX/LaTeX programming, latexml's parameter specifications are more expressive
than TeX's  C<\def> or LaTeX's C<\newcommand>.  Examples of the prototypes for
familiar TeX or LaTeX control sequences are:

   DefConstructor('\usepackage[]{}',...
   DefPrimitive('\multiply Variable SkipKeyword:by Number',..
   DefPrimitive('\newcommand OptionalMatch:* DefToken[]{}', ...

The general syntax for parameter specification is

=over 4

=item C<{I<spec>}>

reads a regular TeX argument.
I<spec> can be omitted (ie. C<{}>).
Otherwise I<spec> is itself a parameter specification and
the argument is reparsed to accordingly.
(C<{}> is a shorthand for C<Plain>.)

=item C<[I<spec>]>

reads an LaTeX-style optional argument.
I<spec> can be omitted (ie. C<{}>).
Otherwise, if I<spec> is of the form Default:stuff, then stuff
would be the default value.
Otherwise I<spec> is itself a parameter specification
and the argument, if supplied, is reparsed according to that specification.
(C<[]> is a shorthand for C<Optional>.)

=item I<Type>

Reads an argument of the given type, where either
Type has been declared, or there exists a ReadType
function accessible from LaTeXML::Package::Pool.
See the available types, below.

=item C<I<Type>:I<value> | I<Type>:I<value1>:I<value2>...>

These forms invoke the parser for I<Type> but
pass additional Tokens to the reader function.
Typically this would supply defaults or parameters to a match.

=item C<OptionalI<Type>>

Similar to I<Type>, but it is not considered
an error if the reader returns undef.

=item C<SkipI<Type>>

Similar to C<Optional>I<Type>, but the value returned
from the reader is ignored, and does not occupy a
position in the arguments list.

=back

The predefined argument I<Type>s are as follows.

=over 4

=item C<Plain, Semiverbatim>

X<Plain>X<Semiverbatim>
Reads a standard TeX argument being either the next token, or if the
next token is an {, the balanced token list.  In the case of C<Semiverbatim>,
many catcodes are disabled, which is handy for URL's, labels and similar.

=item C<Token, XToken>

X<Token>X<XToken>
Read a single TeX Token.  For C<XToken>, if the next token is expandable,
it is repeatedly expanded until an unexpandable token remains, which is returned.

=item C<Number, Dimension, Glue | MuGlue>

X<Number>X<Dimension>X<Glue>X<MuGlue>
Read an Object corresponding to Number, Dimension, Glue or MuGlue,
using TeX's rules for parsing these objects.

=item C<Until:I<match> | XUntil:>I<match>>

X<Until>X<XUntil>
Reads tokens until a match to the tokens I<match> is found, returning
the tokens preceding the match. This corresponds to TeX delimited arguments.
For C<XUntil>, tokens are expanded as they are matched and accumulated.

=item C<UntilBrace>

X<UntilBrace>
Reads tokens until the next open brace C<{>.
This corresponds to the peculiar TeX construct C<\def\foo#{...>.

=item C<Match:I<match(|match)*> | Keyword:>I<match(|match)*>>

X<Match>X<Keyword>
Reads tokens expecting a match to one of the token lists I<match>,
returning the one that matches, or undef.
For C<Keyword>, case and catcode of the I<matches> are ignored.
Additionally, any leading spaces are skipped.

=item C<Balanced>

X<Balanced>
Read tokens until a closing }, but respecting nested {} pairs.

=item C<BalancedParen>

X<BalancedParen>
Read a parenthesis delimited tokens, but does I<not> balance any nested parentheses.

=item C<Undigested, Digested, DigestUntil:I<match>>

X<Undigested>X<Digested>
These types alter the usual sequence of tokenization and digestion in separate stages (like TeX).
A C<Undigested> parameter inhibits digestion completely and remains in token form.
A C<Digested> parameter gets digested until the (required) opening { is balanced; this is
useful when the content would usually need to have been protected in order to correctly deal
with catcodes.  C<DigestUntil> digests tokens until a token matching I<match> is found.

=item C<Variable>

X<Variable>
Reads a token, expanding if necessary, and expects a control sequence naming
a writable register.  If such is found, it returns an array of the corresponding
definition object, and any arguments required by that definition.

=item C<SkipSpaces, Skip1Space>

X<SkipSpaces>X<Skip1Space>
Skips one, or any number of, space tokens, if present, but contributes nothing to the argument list.

=back

=head3 Common Options

=over

=item C<scope=E<gt>'local' | 'global' | I<scope>>

Most defining commands accept an option to control how the definition is stored,
for global or local definitions, or using a named I<scope>
A named scope saves a set of definitions and values that can be activated at a later time.

Particularly interesting forms of scope are those that get automatically activated
upon changes of counter and label.  For example, definitions that have
C<scope=E<gt>'section:1.1'>  will be activated when the section number is "1.1",
and will be deactivated when that section ends.

=item C<locked=E<gt>I<boolean>>

This option controls whether this definition is locked from further
changes in the TeX sources; this keeps local 'customizations' by an author
from overriding important LaTeXML definitions and breaking the conversion.

=back

=head3 Macros

=over 4

=item C<DefMacro(I<prototype>, I<expansion>, I<%options>);>

X<DefMacro>
Defines the macro expansion for I<prototype>; a macro control sequence that is
expanded during macro expansion time in the  L<LaTeXML::Core::Gullet>.
The I<expansion> should be one of I<tokens> | I<string> | I<code>($gullet,@args)>:
a I<string> will be tokenized upon first usage.
Any macro arguments will be substituted for parameter indicators (eg #1)
in the I<tokens> or tokenized I<string> and the result is used as the expansion
of the control sequence. If I<code> is used, it is called at expansion time
and should return a list of tokens as its result.

DefMacro options are

=over 4

=item C<scope=E<gt>I<scope>>,

=item C<locked=E<gt>I<boolean>>

See L</"Common Options">.

=item C<mathactive=E<gt>I<boolean>>

specifies a definition that will only be expanded in math mode;
the control sequence must be a single character.

=back

Examples:

  DefMacro('\thefootnote','\arabic{footnote}');
  DefMacro('\today',sub { ExplodeText(today()); });

=item C<DefMacroI(I<cs>, I<paramlist>, I<expansion>, I<%options>);>

X<DefMacroI>
Internal form of C<DefMacro> where the control sequence and parameter list
have already been separated; useful for definitions from within code.
Also, slightly more efficient for macros with no arguments (use C<undef> for
I<paramlist>), and useful for obscure cases like defining C<\begin{something*}>
as a Macro.

=back

=head3 Conditionals

=over 4

=item C<DefConditional(I<prototype>, I<test>, I<%options>);>

X<DefConditional>
Defines a conditional for I<prototype>; a control sequence that is
processed during macro expansion time (in the  L<LaTeXML::Core::Gullet>).
A conditional corresponds to a TeX C<\if>.
If the I<test> is C<undef>, a C<\newif> type of conditional is defined,
which is controlled with control sequences like C<\footrue> and C<\foofalse>.
Otherwise the I<test> should be C<I<code>($gullet,@args)> (with the control sequence's arguments)
that is called at expand time to determine the condition.
Depending on whether the result of that evaluation returns a true or false value
(in the usual Perl sense), the result of the expansion is either the
first or else code following, in the usual TeX sense.

DefConditional options are

=over 4

=item C<scope=E<gt>I<scope>>,

=item C<locked=E<gt>I<boolean>>

See L</"Common Options">.

=item C<skipper=E<gt>I<code>($gullet)>

This option is I<only> used to define C<\ifcase>.

=back

Example:

  DefConditional('\ifmmode',sub {
     LookupValue('IN_MATH'); });

=item C<DefConditionalI(I<cs>, I<paramlist>, I<test>, I<%options>);>

X<DefConditionalI>
Internal form of C<DefConditional> where the control sequence and parameter list
have already been parsed; useful for definitions from within code.
Also, slightly more efficient for conditinal with no arguments (use C<undef> for
C<paramlist>).

=item C<IfCondition(I<$ifcs>,I<@args>)>

X<IfCondition>
C<IfCondition> allows you to test a conditional from within perl. Thus something like
C<if(IfCondition('\ifmmode')){ domath } else { dotext }> might be equivalent to
TeX's C<\ifmmode domath \else dotext \fi>.

=back

=head3 Primitives

=over 4

=item C<DefPrimitive(I<prototype>, I<replacement>, I<%options>);>

X<DefPrimitive>
Defines a primitive control sequence; a primitive is processed during
digestion (in the  L<LaTeXML::Core::Stomach>), after macro expansion but before Construction time.
Primitive control sequences generate Boxes or Lists, generally
containing basic Unicode content, rather than structured XML.
Primitive control sequences are also executed for side effect during digestion,
effecting changes to the L<LaTeXML::Core::State>.

The I<replacement> can be a string used as the text content of a Box to be
created (using the current font).
Alternatively I<replacement> can be C<I<code>($stomach,@args)>
(with the control sequence's arguments)
which is invoked at digestion time, probably for side-effect,
but returning Boxes or Lists or nothing.
I<replacement> may also be undef, which contributes nothing to the document,
but does record the TeX code that created it.

DefPrimitive options are

=over 4

=item C<scope=E<gt>I<scope>>,

=item C<locked=E<gt>I<boolean>>

See L</"Common Options">.

=item C<mode=E<gt> ('text' | 'display_math' | 'inline_math')>

Changes to this mode during digestion.

=item C<font=E<gt>{I<%fontspec>}>

Specifies the font to use (see L</"Fonts">).
If the font change is to only apply to material generated within this command,
you would also use C<<bounded=>1>>; otherwise, the font will remain in effect afterwards
as for a font switching command.

=item C<bounded=E<gt>I<boolean>>

If true, TeX grouping (ie. C<{}>) is enforced around this invocation.

=item C<requireMath=E<gt>I<boolean>>,

=item C<forbidMath=E<gt>I<boolean>>

specifies whether the given constructor can I<only> appear,
or I<cannot> appear, in math mode.

=item C<beforeDigest=E<gt>I<code>($stomach)>

supplies a hook to execute during digestion
just before the main part of the primitive is executed
(and before any arguments have been read).
The I<code> should either return nothing (return;)
or a list of digested items (Box's,List,Whatsit).
It can thus change the State and/or add to the digested output.

=item C<afterDigest=E<gt>I<code>($stomach)>

supplies a hook to execute during digestion
just after the main part of the primitive ie executed.
it should either return nothing (return;) or digested items.
It can thus change the State and/or add to the digested output.

=item C<isPrefix=E<gt>I<boolean>>

indicates whether this is a prefix type of command;
This is only used for the special TeX assignment prefixes, like C<\global>.

=back

Example:

   DefPrimitive('\begingroup',sub { $_[0]->begingroup; });

=item C<DefPrimitiveI(I<cs>, I<paramlist>, I<code>($stomach,@args), I<%options>);>

X<DefPrimitiveI>
Internal form of C<DefPrimitive> where the control sequence and parameter list
have already been separated; useful for definitions from within code.

=back

=head3 Registers

=over

=item C<DefRegister(I<prototype>, I<value>, I<%options>);>

X<DefRegister>
Defines a register with I<value> as the initial value (a Number, Dimension, Glue, MuGlue or Tokens
--- I haven't handled Box's yet).  Usually, the I<prototype> is just the control sequence,
but registers are also handled by prototypes like C<\count{Number}>. C<DefRegister> arranges
that the register value can be accessed when a numeric, dimension, ... value is being read,
and also defines the control sequence for assignment.

Options are

=over 4

=item C<readonly=E<gt>I<boolean>>

specifies if it is not allowed to change this value.

=item C<getter=E<gt>I<code>(@args)>,

=item C<setter=E<gt>I<code>($value,@args)>

By default I<value> is stored in the State's Value table under a name concatenating the
control sequence and argument values.  These options allow other means of fetching and
storing the value.

=back

Example:

  DefRegister('\pretolerance',Number(100));

=item C<DefRegisterI(I<cs>, I<paramlist>, I<value>, I<%options>);>

X<DefRegisterI>
Internal form of C<DefRegister> where the control sequence and parameter list
have already been parsed; useful for definitions from within code.

=back

=head3 Constructors

=over 4

=item C<DefConstructor(I<prototype>, I<$replacement>, I<%options>);>

X<DefConstructor>
The Constructor is where LaTeXML really starts getting interesting;
invoking the control sequence will generate an arbitrary XML
fragment in the document tree.  More specifically: during digestion, the arguments
will be read and digested, creating a L<LaTeXML::Core::Whatsit> to represent the object. During
absorbtion by the L<LaTeXML::Core::Document>, the C<Whatsit> will generate the XML fragment according
to I<replacement>. The I<replacement> can be C<I<code>($document,@args,%properties)>
which is called during document absorbtion to create the appropriate XML
(See the methods of L<LaTeXML::Core::Document>).

More conveniently, I<replacement> can be an pattern: simply a bit of XML as a string
with certain substitutions to be made. The substitutions are of the following forms:

=over 4

=item C<#1, #2 ... #name>

These are replaced by the corresponding argument (for #1) or property (for #name)
stored with the Whatsit. Each are turned into a string when it appears as
in an attribute position, or recursively processed when it appears as content.

=item C<&I<function>(@args)>

Another form of substituted value is prefixed with C<&> which invokes a function.
For example, C< &func(#1) > would invoke the function C<func> on the first argument
to the control sequence; what it returns will be inserted into the document.

=item C<?I<test>(I<pattern>)>  or C<?I<test>(I<ifpattern>)(I<elsepattern>)>

Patterns can be conditionallized using this form.  The I<test> is any
of the above expressions (eg. C<#1>), considered true if the result is non-empty.
Thus C<< ?#1(<foo/>) >> would add the empty element C<foo> if the first argument
were given.

=item C<^>

If the constuctor I<begins> with C<^>, the XML fragment is allowed to I<float up>
to a parent node that is allowed to contain it, according to the Document Type.

=back

The Whatsit property C<font> is defined by default.  Additional properties
C<body> and C<trailer> are defined when C<captureBody> is true, or for environments.
By using C<< $whatsit->setProperty(key=>$value); >> within C<afterDigest>,
or by using the C<properties> option, other properties can be added.

DefConstructor options are

=over 4

=item C<scope=E<gt>I<scope>>,

=item C<locked=E<gt>I<boolean>>

See L</"Common Options">.

=item C<mode=E<gt>I<mode>>,

=item C<font=E<gt>{I<%fontspec>}>,

=item C<bounded=E<gt>I<boolean>>,

=item C<requireMath=E<gt>I<boolean>>,

=item C<forbidMath=E<gt>I<boolean>>

These options are the same as for L</Primitives>

=item C<reversion=E<gt>I<texstring> | I<code>($whatsit,#1,#2,...)>

specifies the reversion of the invocation back into TeX tokens
(if the default reversion is not appropriate).
The I<textstring> string can include C<#1>, C<#2>...
The I<code> is called with the C<$whatsit> and digested arguments
and must return a list of Token's.

=item C<alias=E<gt>I<control_sequence>>

provides a control sequence to be used in the C<reversion> instead of
the one defined in the C<prototype>.  This is a convenient alternative for
reversion when a 'public' command conditionally expands into
an internal one, but the reversion should be for the public command.

=item C<sizer=E<gt>I<string> | I<code>($whatsit)>

specifies how to compute (approximate) the displayed size of the object,
if that size is ever needed (typically needed for graphics generation).
If a string is given, it should contain only a sequence of C<#1> or C<#name> to
access arguments and properties of the Whatsit: the size is computed from these
items layed out side-by-side.  If I<code> is given, it should return
the three Dimensions (width, height and depth).  If neither is given,
and the C<reversion> specification is of suitible format, it will be used for the sizer.

=item C<properties=E<gt>{I<%properties>} | I<code>($stomach,#1,#2...)>

supplies additional properties to be set on the
generated Whatsit.  In the first form, the values can
be of any type, but if a value is a code references, it takes
the same args ($stomach,#1,#2,...) and should return the value;
it is executed before creating the Whatsit.
In the second form, the code should return a hash of properties.

=item C<beforeDigest=E<gt>I<code>($stomach)>

supplies a hook to execute during digestion
just before the Whatsit is created.  The I<code> should either
return nothing (return;) or a list of digested items (Box's,List,Whatsit).
It can thus change the State and/or add to the digested output.

=item C<afterDigest=E<gt>I<code>($stomach,$whatsit)>

supplies a hook to execute during digestion
just after the Whatsit is created (and so the Whatsit already
has its arguments and properties). It should either return
nothing (return;) or digested items.  It can thus change the State,
modify the Whatsit, and/or add to the digested output.

=item C<beforeConstruct=E<gt>I<code>($document,$whatsit)>

supplies a hook to execute before constructing the XML
(generated by I<replacement>).

=item C<afterConstruct=E<gt>I<code>($document,$whatsit)>

Supplies I<code> to execute after constructing the XML.

=item C<captureBody=E<gt>I<boolean> | I<Token>>

if true, arbitrary following material will be accumulated into
a `body' until the current grouping level is reverted,
or till the C<Token> is encountered if the option is a C<Token>.
This body is available as the C<body> property of the Whatsit.
This is used by environments and math.

=item C<nargs=E<gt>I<nargs>>

This gives a number of args for cases where it can't be infered directly
from the I<prototype> (eg. when more args are explicitly read by hooks).

=back

=item C<DefConstructorI(I<cs>, I<paramlist>, I<replacement>, I<%options>);>

X<DefConstructorI>
Internal form of C<DefConstructor> where the control sequence and parameter list
have already been separated; useful for definitions from within code.

=item C<DefMath(I<prototype>, I<tex>, I<%options>);>

X<DefMath>
A common shorthand constructor; it defines a control sequence that creates a mathematical object,
such as a symbol, function or operator application.
The options given can effectively create semantic macros that contribute to the eventual
parsing of mathematical content.
In particular, it generates an XMDual using the replacement I<tex> for the presentation.
The content information is drawn from the name and options

C<DefMath> accepts the options:

=over 4

=item C<scope=E<gt>I<scope>>,

=item C<locked=E<gt>I<boolean>>

See L</"Common Options">.

=item C<font=E<gt>{I<%fontspec>}>,

=item C<reversion=E<gt>I<reversion>>,

=item C<alias=E<gt>I<cs>>,

=item C<sizer=E<gt>I<sizer>>,

=item C<properties=E<gt>I<properties>>,

=item C<beforeDigest=E<gt>I<code>($stomach)>,

=item C<afterDigest=E<gt>I<code>($stomach,$whatsit)>,

These options are the same as for L</Constructors>

=item C<name=E<gt>I<name>>

gives a name attribute for the object

=item C<omcd=E<gt>I<cdname>>

gives the OpenMath content dictionary that name is from.

=item C<role=E<gt>I<grammatical_role>>

adds a grammatical role attribute to the object; this specifies
the grammatical role that the object plays in surrounding expressions.
This direly needs documentation!

=item C<mathstyle=E<gt>('display' | 'text' | 'script' | 'scriptscript')>

Controls whether the this object will be presented in a specific
mathstyle, or according to the current setting of C<mathstyle>.

=item C<scriptpos=E<gt>('mid' | 'post')>

Controls the positioning of any sub and super-scripts relative to this object;
whether they be stacked over or under it, or whether they will appear in the usual position.
TeX.pool defines a function C<doScriptpos()> which is useful for operators
like C<\sum> in that it sets to C<mid> position when in displaystyle, otherwise C<post>.

=item C<stretchy=E<gt>I<boolean>>

Whether or not the object is stretchy when displayed.

=item C<operator_role=E<gt>I<grammatical_role>>,

=item C<operator_scriptpos=E<gt>I<boolean>>,

=item C<operator_stretchy=E<gt>I<boolean>>

These three are similar to C<role>, C<scriptpos> and C<stretchy>, but are used in
unusual cases.  These apply to the given attributes to the operator token
in the content branch.

=item C<nogroup=E<gt>I<boolean>>

Normally, these commands are digested with an implicit grouping around them,
localizing changes to fonts, etc; C<< noggroup=>1 >> inhibits this.

=back

Example:

  DefMath('\infty',"\x{221E}",
     role=>'ID', meaning=>'infinity');

=item C<DefMathI(I<cs>, I<paramlist>, I<tex>, I<%options>);>

X<DefMathI>
Internal form of C<DefMath> where the control sequence and parameter list
have already been separated; useful for definitions from within code.

=back

=head3 Environments

=over

=item C<DefEnvironment(I<prototype>, I<replacement>, I<%options>);>

X<DefEnvironment>
Defines an Environment that generates a specific XML fragment.  C<replacement> is
of the same form as for DefConstructor, but will generally include reference to
the C<#body> property. Upon encountering a C<\begin{env}>:  the mode is switched, if needed,
else a new group is opened; then the environment name is noted; the beforeDigest hook is run.
Then the Whatsit representing the begin command (but ultimately the whole environment) is created
and the afterDigestBegin hook is run.
Next, the body will be digested and collected until the balancing C<\end{env}>.   Then,
any afterDigest hook is run, the environment is ended, finally the mode is ended or
the group is closed.  The body and C<\end{env}> whatsit are added to the C<\begin{env}>'s whatsit
as body and trailer, respectively.

C<DefEnvironment> takes the following options:

=over 4

=item C<scope=E<gt>I<scope>>,

=item C<locked=E<gt>I<boolean>>

See L</"Common Options">.

=item C<mode=E<gt>I<mode>>,

=item C<font=E<gt>{I<%fontspec>}>

=item C<requireMath=E<gt>I<boolean>>,

=item C<forbidMath=E<gt>I<boolean>>,

These options are the same as for L</Primitives>

=item C<reversion=E<gt>I<reversion>>,

=item C<alias=E<gt>I<cs>>,

=item C<sizer=E<gt>I<sizer>>,

=item C<properties=E<gt>I<properties>>,

=item C<nargs=E<gt>I<nargs>>

These options are the same as for L</DefConstructor>

=item C<beforeDigest=E<gt>I<code>($stomach)>

This hook is similar to that for C<DefConstructor>,
but it applies to the C<\begin{environment}> control sequence.

=item C<afterDigestBegin=E<gt>I<code>($stomach,$whatsit)>

This hook is similar to C<DefConstructor>'s C<afterDigest>
but it applies to the C<\begin{environment}> control sequence.
The Whatsit is the one for the beginning control sequence,
but represents the environment as a whole.
Note that although the arguments and properties are present in
the Whatsit, the body of the environment is I<not> yet available!

=item C<beforeDigestEnd=E<gt>I<code>($stomach)>

This hook is similar to C<DefConstructor>'s C<beforeDigest>
but it applies to the C<\end{environment}> control sequence.

=item C<afterDigest=E<gt>I<code>($stomach,$whatsit)>

This hook is simlar to C<DefConstructor>'s C<afterDigest>
but it applies to the C<\end{environment}> control sequence.
Note, however that the Whatsit is only for the ending control sequence,
I<not> the Whatsit for the environment as a whole.

=item C<afterDigestBody=E<gt>I<code>($stomach,$whatsit)>

This option supplies a hook to be executed during digestion
after the ending control sequence has been digested (and all the 4
other digestion hook have executed) and after
the body of the environment has been obtained.
The Whatsit is the (useful) one representing the whole
environment, and it now does have the body and trailer available,
stored as a properties.

=back

Example:

  DefConstructor('\emph{}',
     "<ltx:emph>#1</ltx:emph", mode=>'text');

=item C<DefEnvironmentI(I<name>, I<paramlist>, I<replacement>, I<%options>);>

X<DefEnvironmentI>
Internal form of C<DefEnvironment> where the control sequence and parameter list
have already been separated; useful for definitions from within code.

=back

=head2 Inputing Content and Definitions

=over 4

=item C<FindFile(I<name>, I<%options>);>

X<FindFile>
Find an appropriate file with the given I<name> in the current directories
in C<SEARCHPATHS>.
If a file ending with C<.ltxml> is found, it will be preferred.

Note that if the C<name> starts with a recognized I<protocol>
(currently one of C<(literal|http|https|ftp)>) followed by a colon,
the name is returned, as is, and no search for files is carried out.

The options are:

=over 4

=item C<type=E<gt>I<type>>

specifies the file type.  If not set, it will search for
both C<I<name>.tex> and I<name>.

=item C<noltxml=E<gt>1>

inhibits searching for a LaTeXML binding (C<I<name>.I<type>.ltxml>)
to use instead of the file itself.

=item C<notex=E<gt>1>

inhibits searching for raw tex version of the file.
That is, it will I<only> search for the LaTeXML binding.

=back

=item C<InputContent(I<request>, I<%options>);>

X<InputContent>
C<InputContent> is used for cases when the file (or data)
is plain TeX material that is expected to contribute content
to the document (as opposed to pure definitions).
A Mouth is opened onto the file, and subsequent reading
and/or digestion will pull Tokens from that Mouth until it is
exhausted, or closed.

In some circumstances it may be useful to provide a string containing
the TeX material explicitly, rather than referencing a file.
In this case, the C<literal> pseudo-protocal may be used:

  InputContent('literal:\textit{Hey}');

If a file named C<$request.latexml> exists, it will be read
in as if it were a latexml binding file, before processing.
This can be used for adhoc customization of the conversion of specific files,
without modifying the source, or creating more elaborate bindings.

The only option to C<InputContent> is:

=over 4

=item C<noerror=E<gt>I<boolean>>

Inhibits signalling an error if no appropriate file is found.

=back

=item C<Input(I<request>);>

X<Input>
C<Input> is analogous to LaTeX's C<\input>, and is used in
cases where it isn't completely clear whether content or definitions
is expected.  Once a file is found, the approach specified
by C<InputContent> or C<InputDefinitions> is used, depending on
which type of file is found.

=item C<InputDefinitions(I<request>, I<%options>);>

X<InputDefinitions>
C<InputDefinitions> is used for loading I<definitions>,
ie. various macros, settings, etc, rather than document content;
it can be used to load LaTeXML's binding files, or for
reading in raw TeX definitions or style files.
It reads and processes the material completely before
returning, even in the case of TeX definitions.
This procedure optionally supports the conventions used
for standard LaTeX packages and classes (see C<RequirePackage> and C<LoadClass>).

Options for C<InputDefinitions> are:

=over

=item C<type=E<gt>I<type>>

the file type to search for.

=item C<noltxml=E<gt>I<boolean>>

inhibits searching for a LaTeXML binding; only raw TeX files will be sought and loaded.

=item C<notex=E<gt>I<boolean>>

inhibits searching for raw TeX files, only a LaTeXML binding will be sought and loaded.

=item C<noerror=E<gt>I<boolean>>

inhibits reporting an error if no appropriate file is found.

=back

The following options are primarily useful when C<InputDefinitions>
is supporting standard LaTeX package and class loading.

=over

=item C<withoptions=E<gt>I<boolean>>

indicates whether to pass in any options from the calling class or package.

=item C<handleoptions=E<gt>I<boolean>>

indicates whether options processing should be handled.

=item C<options=E<gt>[...]>

specifies a list of options (in the 'package options' sense) to be passed
(possibly in addition to any provided by the calling class or package).

=item C<after=E<gt>I<tokens> | I<code>($gullet)>

provides I<tokens> or I<code> to be processed by a C<I<name>.I<type>-h@@k> macro.

=item C<as_class=E<gt>I<boolean>>

fishy option that indicates that this definitions file should
be treated as if it were defining a class; typically shows up
in latex compatibility mode, or AMSTeX.

=back

A handy method to use most of the TeX distribution's raw TeX definitions for a package,
but override only a few with LaTeXML bindings is by defining a binding file,
say C<tikz.sty.ltxml>, to contain

  InputDefinitions('tikz', type => 'sty', noltxml => 1);

which would find and read in C<tizk.sty>, and then follow it by a couple of strategic
LaTeXML definitions, C<DefMacro>, etc.

=back

=head2 Class and Packages

=over

=item C<RequirePackage(I<package>, I<%options>);>

X<RequirePackage>
Finds and loads a package implementation (usually C<I<package>.sty.ltxml>,
unless C<noltxml> is specified)for the requested I<package>.
It returns the pathname of the loaded package.
The options are:

=over

=item C<type=E<gt>I<type>>

specifies the file type (default C<sty>.

=item C<options=E<gt>[...]>

specifies a list of package options.

=item C<noltxml=E<gt>I<boolean>>

inhibits searching for the LaTeXML binding for the file (ie. C<I<name>.I<type>.ltxml>

=item C<notex=E<gt>1>

inhibits searching for raw tex version of the file.
That is, it will I<only> search for the LaTeXML binding.

=back

=item C<LoadClass(I<class>, I<%options>);>

X<LoadClass>
Finds and loads a class definition (usually C<I<class>.cls.ltxml>).
It returns the pathname of the loaded class.
The only option is

=over

=item C<options=E<gt>[...]>

specifies a list of class options.

=back

=item C<LoadPool(I<pool>, I<%options>);>

X<LoadPool>
Loads a I<pool> file (usually C<I<pool>.pool.ltxml>),
one of the top-level definition files, such as TeX, LaTeX or AMSTeX.
It returns the pathname of the loaded file.

=item C<DeclareOption(I<option>, I<tokens> | I<string> | I<code>($stomach));>

X<DeclareOption>
Declares an option for the current package or class.
The 2nd argument can be a I<string> (which will be tokenized and expanded)
or I<tokens> (which will be macro expanded), to provide the value for the option,
or it can be a code reference which is treated as a primitive for side-effect.

If a package or class wants to accomodate options, it should start
with one or more C<DeclareOptions>, followed by C<ProcessOptions()>.

=item C<PassOptions(I<name>, I<ext>, I<@options>); >

X<PassOptions>
Causes the given I<@options> (strings) to be passed to the package
(if I<ext> is C<sty>) or class (if I<ext> is C<cls>)
named by I<name>.

=item C<ProcessOptions(I<%options>);>

X<ProcessOptions>
Processes the options that have been passed to the current package
or class in a fashion similar to LaTeX.  The only option (to C<ProcessOptions>
is C<inorder=E<gt>I<boolean>> indicating whehter the (package) options are processed in the
order they were used, like C<ProcessOptions*>.

=item C<ExecuteOptions(I<@options>);>

X<ExecuteOptions>
Process the options given explicitly in I<@options>.

=item C<AtBeginDocument(I<@stuff>); >

X<AtBeginDocument>
Arranges for I<@stuff> to be carried out after the preamble, at the beginning of the document.
I<@stuff> should typically be macro-level stuff, but carried out for side effect;
it should be tokens, tokens lists, strings (which will be tokenized),
or C<I<code>($gullet)> which would yeild tokens to be expanded.

This operation is useful for style files loaded with C<--preload> or document specific
customization files (ie. ending with C<.latexml>); normally the contents would be executed
before LaTeX and other style files are loaded and thus can be overridden by them.
By deferring the evaluation to begin-document time, these contents can override those style files.
This is likely to only be meaningful for LaTeX documents.

=item C<AtEndDocument(I<@stuff>)>

Arranges for I<@stuff> to be carried out just before C<\\end{document}>.
These tokens can be used for side effect, or any content they generate will appear as the
last children of the document.

=back

=head2 Counters and IDs

=over 4

=item C<NewCounter(I<ctr>, I<within>, I<%options>);>

X<NewCounter>
Defines a new counter, like LaTeX's \newcounter, but extended.
It defines a counter that can be used to generate reference numbers,
and defines C<\theI<ctr>>, etc. It also defines an "uncounter" which
can be used to generate ID's (xml:id) for unnumbered objects.
I<ctr> is the name of the counter.  If defined, I<within> is the name
of another counter which, when incremented, will cause this counter
to be reset.
The options are

=over

=item C<idprefix=E<gt>I<string>>

Specifies a prefix to be used to generate ID's when using this counter

=item C<nested>

Not sure that this is even sane.

=back

=item C<< $num = CounterValue($ctr); >>

X<CounterValue>
Fetches the value associated with the counter C<$ctr>.

=item C<< $tokens = StepCounter($ctr); >>

X<StepCounter>
Analog of C<\stepcounter>, steps the counter and returns the expansion of
C<\the$ctr>.  Usually you should use C<RefStepCounter($ctr)> instead.

=item C<< $keys = RefStepCounter($ctr); >>

X<RefStepCounter>
Analog of C<\refstepcounter>, steps the counter and returns a hash
containing the keys C<refnum=>$refnum, id=>$id>.  This makes it
suitable for use in a C<properties> option to constructors.
The C<id> is generated in parallel with the reference number
to assist debugging.

=item C<< $keys = RefStepID($ctr); >>

X<RefStepID>
Like to C<RefStepCounter>, but only steps the "uncounter",
and returns only the id;  This is useful for unnumbered cases
of objects that normally get both a refnum and id.

=item C<< ResetCounter($ctr); >>

X<ResetCounter>
Resets the counter C<$ctr> to zero.

=item C<< GenerateID($document,$node,$whatsit,$prefix); >>

X<GenerateID>
Generates an ID for nodes during the construction phase, useful
for cases where the counter based scheme is inappropriate.
The calling pattern makes it appropriate for use in Tag, as in

   Tag('ltx:para',afterClose=>sub { GenerateID(@_,'p'); })

If C<$node> doesn't already have an xml:id set, it computes an
appropriate id by concatenating the xml:id of the closest
ancestor with an id (if any), the prefix (if any) and a unique counter.

=back

=head2 Document Model

Constructors define how TeX markup will generate XML fragments, but the
Document Model is used to control exactly how those fragments are assembled.

=over

=item C<Tag(I<tag>, I<%properties>);>

X<Tag>
Declares properties of elements with the name I<tag>.
Note that C<Tag> can set or add properties to any element from any binding file,
unlike the properties set on control by  C<DefPrimtive>, C<DefConstructor>, etc..
And, since the properties are recorded in the current Model, they are not
subject to TeX grouping; once set, they remain in effect until changed
or the end of the document.

The I<tag> can be specified in one of three forms:

   prefix:name matches specific name in specific namespace
   prefix:*    matches any tag in the specific namespace;
   *           matches any tag in any namespace.

There are two kinds of properties:

=over

=item Scalar properties

For scalar properties, only a single value is returned for a given element.
When the property is looked up, each of the above forms is considered
(the specific element name, the namespace, and all elements);
the first defined value is returned.

The recognized scalar properties are:

=over

=item C<autoOpen=E<gt>I<boolean>>

Specifies whether I<tag> can be automatically opened
if needed to insert an element that can only be contained by I<tag>.
This property can help match the more  SGML-like LaTeX to XML.

=item C<autoClose=E<gt>I<boolean>>

Specifies whether this I<tag> can be automatically closed
if needed to close an ancestor node, or insert
an element into an ancestor.
This property can help match the more  SGML-like LaTeX to XML.

=back

=item Code properties

These properties provide a bit of code to be run at the times
of certain events associated with an element.  I<All> the code bits
that match a given element will be run, and since they can be added by
any binding file, and be specified in a random orders,
a little bit of extra control is desirable.

Firstly, any I<early> codes are run (eg C<afterOpen:early>), then
any normal codes (without modifier) are run, and finally
any I<late> codes are run (eg. C<afterOpen:late>).

Within I<each> of those groups, the codes assigned for an element's specific
name are run first, then those assigned for its package and finally the generic one (C<*>);
that is, the most specific codes are run first.

When code properties are accumulated by C<Tag> for normal or late events,
the code is appended to the end of the current list (if there were any previous codes added);
for early event, the code is prepended.

The recognized code properties are:

=over

=item C<afterOpen=E<gt>I<code>($document,$box)>

Provides I<code> to be run whenever a node with this I<tag>
is opened.  It is called with the document being constructed,
and the initiating digested object as arguments.
It is called after the node has been created, and after
any initial attributes due to the constructor (passed to openElement)
are added.

C<afterOpen:early> or C<afterOpen:late> can be used in
place of C<afterOpen>; these will be run as a group
bfore, or after (respectively) the unmodified blocks.

=item C<afterClose=E<gt>I<code>($document,$box)>

Provides I<code> to be run whenever a node with this I<tag>
is closed.  It is called with the document being constructed,
and the initiating digested object as arguments.

C<afterClose:early> or C<afterClose:late> can be used in
place of C<afterClose>; these will be run as a group
bfore, or after (respectively) the unmodified blocks.

=back

=back

=item C<RelaxNGSchema(I<schemaname>);>

X<RelaxNGSchema>
Specifies the schema to use for determining document model.
You can leave off the extension; it will look for C<I<schemaname>.rng>
(and maybe eventually, C<.rnc> if that is ever implemented).

=item C<RegisterNamespace(I<prefix>, I<URL>);>

X<RegisterNamespace>
Declares the I<prefix> to be associated with the given I<URL>.
These prefixes may be used in ltxml files, particularly for
constructors, xpath expressions, etc.  They are not necessarily
the same as the prefixes that will be used in the generated document
Use the prefix C<#default> for the default, non-prefixed, namespace.
(See RegisterDocumentNamespace, as well as DocType or RelaxNGSchema).

=item C<RegisterDocumentNamespace(I<prefix>, I<URL>);>

X<RegisterDocumentNamespace>
Declares the I<prefix> to be associated with the given I<URL>
used within the generated XML. They are not necessarily
the same as the prefixes used in code (RegisterNamespace).
This function is less rarely needed, as the namespace declarations
are generally obtained from the DTD or Schema themselves
Use the prefix C<#default> for the default, non-prefixed, namespace.
(See DocType or RelaxNGSchema).

=item C<DocType(I<rootelement>, I<publicid>, I<systemid>, I<%namespaces>);>

X<DocType>
Declares the expected I<rootelement>, the public and system ID's of the document type
to be used in the final document.  The hash I<%namespaces> specifies
the namespaces prefixes that are expected to be found in the DTD, along with
each associated namespace URI.  Use the prefix C<#default> for the default namespace
(ie. the namespace of non-prefixed elements in the DTD).

The prefixes defined for the DTD may be different from the prefixes used in
implementation CODE (eg. in ltxml files; see RegisterNamespace).
The generated document will use the namespaces and prefixes defined for the DTD.

=back

=head2 Document Rewriting

During document construction, as each node gets closed, the text content gets simplfied.
We'll call it I<applying ligatures>, for lack of a better name.

=over

=item C<DefLigature(I<regexp>, I<%options>);>

X<DefLigature>
Apply the regular expression (given as a string: "/fa/fa/" since it will
be converted internally to a true regexp), to the text content.
The only option is C<fontTest=E<gt>I<code>($font)>; if given, then the substitution
is applied only when C<fontTest> returns true.

Predefined Ligatures combine sequences of "." or single-quotes into appropriate
Unicode characters.

=item C<DefMathLigature(I<$string>C<=>>I<$replacment>,I<%options>);>

X<DefMathLigature>
A Math Ligature typically combines a sequence of math tokens (XMTok) into a single one.
A simple example is

   DefMathLigature(":=" => ":=", role => 'RELOP', meaning => 'assign');

replaces the two tokens for colon and equals by a token representing assignment.
The options are those characterising an XMTok, namely: C<role>, C<meaning> and C<name>.

For more complex cases (recognizing numbers, for example), you may supply a
function C<matcher=>CODE($document,$node)>, which is passed the current document
and the last math node in the sequence.  It should examine C<$node> and any preceding
nodes (using C<previousSibling>) and return a list of C<($n,$string,%attributes)> to replace
the C<$n> nodes by a new one with text content being C<$string> content and the given attributes.
If no replacement is called for, CODE should return undef.

=back

After document construction, various rewriting and augmenting of the
document can take place.

=over

=item C<DefRewrite(I<%specification>);>

=item C<DefMathRewrite(I<%specification>);>

X<DefRewrite>X<DefMathRewrite>
These two declarations define document rewrite rules that are applied to the
document tree after it has been constructed, but before math parsing, or
any other postprocessing, is done.  The I<%specification> consists of a
sequence of key/value pairs with the initial specs successively narrowing the
selection of document nodes, and the remaining specs indicating how
to modify or replace the selected nodes.

The following select portions of the document:

=over

=item C<label=E<gt>I<label>>

Selects the part of the document with label=$label

=item C<scope=E<gt>I<scope>>

The I<scope> could be "label:foo" or "section:1.2.3" or something
similar. These select a subtree labelled 'foo', or
a section with reference number "1.2.3"

=item C<xpath=E<gt>I<xpath>>

Select those nodes matching an explicit xpath expression.

=item C<match=E<gt>I<tex>>

Selects nodes that look like what the processing of I<tex> would produce.

=item C<regexp=E<gt>I<regexp>>

Selects text nodes that match the regular expression.

=back

The following act upon the selected node:

=over

=item C<attributes=E<gt>I<hashref>>

Adds the attributes given in the hash reference to the node.

=item C<replace=E<gt>I<replacement>>

Interprets I<replacement> as TeX code to generate nodes that will
replace the selected nodes.

=back

=back

=head2 Mid-Level support

=over

=item C<< $tokens = Expand($tokens); >>

X<Expand>
Expands the given C<$tokens> according to current definitions.

=item C<< $boxes = Digest($tokens); >>

X<Digest>
Processes and digestes the C<$tokens>.  Any arguments needed by
control sequences in C<$tokens> must be contained within the C<$tokens> itself.

=item C<< @tokens = Invocation($cs,@args); >>

X<Invocation>
Constructs a sequence of tokens that would invoke the token C<$cs>
on the arguments.

=item C<< RawTeX('... tex code ...'); >>

X<RawTeX>
RawTeX is a convenience function for including chunks of raw TeX (or LaTeX) code
in a Package implementation.  It is useful for copying portions of the normal
implementation that can be handled simply using macros and primitives.

=item C<< Let($token1,$token2); >>

X<Let>
Gives C<$token1> the same `meaning' (definition) as C<$token2>; like TeX's \let.

=item C<< StartSemiVerbatim(); ... ; EndSemiVerbatim(); >>

Disable disable most TeX catcodes.

=item C<< $tokens = Tokenize($string); >>

Tokenizes the C<$string> using the standard catcodes, returning a L<LaTeXML::Core::Tokens>.

=item C<< $tokens = TokenizeInternal($string); >>

Tokenizes the C<$string> according to the internal cattable (where @ is a letter),
returning a L<LaTeXML::Core::Tokens>.

=back

=head2 Argument Readers

=over

=item C<< ReadParameters($gullet,$spec); >>

X<ReadParameters>
Reads from C<$gullet> the tokens corresponding to C<$spec>
(a Parameters object).

=item C<DefParameterType(I<type>, I<code>($gullet,@values), I<%options>);>

X<DefParameterType>
Defines a new Parameter type, I<type>, with I<code> for its reader.

Options are:

=over

=item C<reversion=E<gt>I<code>($arg,@values);>

This I<code> is responsible for converting a previously parsed argument back
into a sequence of Token's.

=item C<optional=E<gt>I<boolean>>

whether it is an error if no matching input is found.

=item C<novalue=E<gt>I<boolean>>

whether the value returned should contribute to argument lists, or
simply be passed over.

=item C<semiverbatim=E<gt>I<boolean>>

whether the catcode table should be modified before reading tokens.

=back

=item C<<DefColumnType(I<proto>, I<expansion>);>

X<DefColumnType>
Defines a new column type for tabular and arrays.
I<proto> is the prototype for the pattern, analogous to the pattern
used for other definitions, except that macro being defined is a single character.
The I<expansion> is a string specifying what it should expand into,
typically more verbose column specification.

=back

=head2 Access to State

=over

=item C<< $value = LookupValue($name); >>

X<LookupValue>
Lookup the current value associated with the the string C<$name>.

=item C<< AssignValue($name,$value,$scope); >>

X<AssignValue>
Assign $value to be associated with the the string C<$name>, according
to the given scoping rule.

Values are also used to specify most configuration parameters (which can
therefor also be scoped).  The recognized configuration parameters are:

 VERBOSITY         : the level of verbosity for debugging
                     output, with 0 being default.
 STRICT            : whether errors (eg. undefined macros)
                     are fatal.
 INCLUDE_COMMENTS  : whether to preserve comments in the
                     source, and to add occasional line
                     number comments. (Default true).
 PRESERVE_NEWLINES : whether newlines in the source should
                     be preserved (not 100% TeX-like).
                     By default this is true.
 SEARCHPATHS       : a list of directories to search for
                     sources, implementations, etc.

=item C<< PushValue($name,@values); >>

X<PushValue>
This function, along with the next three are like C<AssignValue>,
but maintain a global list of values.
C<PushValue> pushes the provided values onto the end of a list.
The data stored for C<$name> is global and must be a LIST reference; it is created if needed.

=item C<< UnshiftValue($name,@values); >>

X<UnshiftValue>
Similar to  C<PushValue>, but pushes a value onto the front of the list.
The data stored for C<$name> is global and must be a LIST reference; it is created if needed.

=item C<< PopValue($name); >>

X<PopValue>
Removes and returns the value on the end of the list named by C<$name>.
The data stored for C<$name> is global and must be a LIST reference.
Returns C<undef> if there is no data in the list.

=item C<< ShiftValue($name); >>

X<ShiftValue>
Removes and returns the first value in the list named by C<$name>.
The data stored for C<$name> is global and must be a LIST reference.
Returns C<undef> if there is no data in the list.

=item C<< LookupMapping($name,$key); >>

X<LookupMapping>
This function maintains a hash association named by C<$name>.
It returns the value associated with C<$key> within that mapping.
The data stored for C<$name> is global and must be a HASH reference.
Returns C<undef> if there is no data associated with C<$key> in the mapping,
or the mapping is not (yet) defined.

=item C<< AssignMapping($name,$key,$value); >>

X<AssignMapping>
This function associates C<$value> with C<$key> within the mapping named by C<$name>.
The data stored for C<$name> is global and must be a HASH reference; it is created if needed.

=item C<< $value = LookupCatcode($char); >>

X<LookupCatcode>
Lookup the current catcode associated with the the character C<$char>.

=item C<< AssignCatcode($char,$catcode,$scope); >>

X<AssignCatcode>
Set C<$char> to have the given C<$catcode>, with the assignment made
according to the given scoping rule.

This method is also used to specify whether a given character is
active in math mode, by using C<math:$char> for the character,
and using a value of 1 to specify that it is active.

=item C<< $meaning = LookupMeaning($token); >>

X<LookupMeaning>
Looks up the current meaning of the given C<$token> which may be a
Definition, another token, or the token itself if it has not
otherwise been defined.

=item C<< $defn = LookupDefinition($token); >>

X<LookupDefinition>
Looks up the current definition, if any, of the C<$token>.

=item C<< InstallDefinition($defn); >>

X<InstallDefinition>
Install the Definition C<$defn> into C<$STATE> under its
control sequence.

=item C<XEquals($token1,$token2)>

Tests whether the two tokens are equal in the sense that they are either equal
tokens, or if defined, have the same definition.

=back

=head2 Fonts

=over

=item C<MergeFont(I<%fontspec>); >

X<MergeFont>
Set the current font by merging the font style attributes with the current font.
The I<%fontspec> specifies the properties of the desired font.
Likely values include (the values aren't required to be in this set):

 family : serif, sansserif, typewriter, caligraphic,
          fraktur, script
 series : medium, bold
 shape  : upright, italic, slanted, smallcaps
 size   : tiny, footnote, small, normal, large,
          Large, LARGE, huge, Huge
 color  : any named color, default is black

Some families will only be used in math.
This function returns nothing so it can be easily used in beforeDigest, afterDigest.

=item C<< DeclareFontMap($name,$map,%options); >>

Declares a font map for the encoding C<$name>. The map C<$map>
is an array of 128 or 256 entries, each element is either a unicode
string for the representation of that codepoint, or undef if that
codepoint is not supported  by this encoding.  The only option
currently is C<family> used because some fonts (notably cmr!)
have different glyphs in some font families, such as
C<family=>'typewriter'>.

=item C<< FontDecode($code,$encoding,$implicit); >>

Returns the unicode string representing the given codepoint C<$code>
(an integer) in the given font encoding C<$encoding>.
If C<$encoding> is undefined, the usual case, the current font encoding
and font family is used for the lookup.  Explicit decoding is
used when C<\\char> or similar are invoked (C<$implicit> is false), and
the codepoint must be represented in the fontmap, otherwise undef is returned.
Implicit decoding (ie. C<$implicit> is true) occurs within the Stomach
when a Token's content is being digested and converted to a Box; in that case
only the lower 128 codepoints are converted; all codepoints above 128 are assumed to already be Unicode.

The font map for C<$encoding> is automatically loaded if it has not already been loaded.

=item C<< FontDecodeString($string,$encoding,$implicit); >>

Returns the unicode string resulting from decoding the individual
characters in C<$string> according to L<FontDecode>, above.

=item C<< LoadFontMap($encoding); >>

Finds and loads the font map for the encoding named C<$encoding>, if it hasn't been
loaded before.  It looks for C<encoding.fontmap.ltxml>, which would typically define
the font map using C<DeclareFontMap>, possibly including extra maps for families
like C<typewriter>.

=back

=head2 Color

=over

=item C<< $color=LookupColor($name); >>

Lookup the color object associated with C<$name>.

=item C<< DefColor($name,$color,$scope); >>

Associates the C<$name> with the given C<$color> (a color object),
with the given scoping.

=item C<< DefColorModel($model,$coremodel,$tocore,$fromcore); >>

Defines a color model C<$model> that is derived from the core color
model C<$coremodel>.  The two functions C<$tocore> and C<$fromcore>
convert a color object in that model to the core model, or from the core model
to the derived model.  Core models are rgb, cmy, cmyk, hsb and gray.

=back

=head2 Low-level Functions

=over

=item C<< CleanID($id); >>

X<CleanID>
Cleans an C<$id> of disallowed characters, trimming space.

=item C<< CleanLabel($label,$prefix); >>

X<CleanLabel>
Cleans a C<$label> of disallowed characters, trimming space.
The prefix C<$prefix> is prepended (or C<LABEL>, if none given).

=item C<< CleanIndexKey($key); >>

X<CleanIndexKey>
Cleans an index key, so it can be used as an ID.

=item C<< CleanBibKey($key); >>

Cleans a bibliographic citation key, so it can be used as an ID.

=item C<< CleanURL($url); >>

X<CleanURL>
Cleans a url.

=item C<< UTF($code); >>

X<UTF>
Generates a UTF character, handy for the the 8 bit characters.
For example, C<UTF(0xA0)> generates the non-breaking space.

=item C<< @tokens = roman($number); >>

X<roman>
Formats the C<$number> in (lowercase) roman numerals, returning a list of the tokens.

=item C<< @tokens = Roman($number); >>

X<Roman>
Formats the C<$number> in (uppercase) roman numerals, returning a list of the tokens.

=back

=head1 SEE ALSO

X<See also>
See also L<LaTeXML::Global>,
L<LaTeXML::Common::Object>,
L<LaTeXML::Common::Error>,
L<LaTeXML::Core::Token>,
L<LaTeXML::Core::Tokens>,
L<LaTeXML::Core::Box>,
L<LaTeXML::Core::List>,
L<LaTeXML::Common::Number>,
L<LaTeXML::Common::Float>,
L<LaTeXML::Common::Dimension>,
L<LaTeXML::Common::Glue>,
L<LaTeXML::Core::MuDimension>,
L<LaTeXML::Core::MuGlue>,
L<LaTeXML::Core::Pair>,
L<LaTeXML::Core::PairList>,
L<LaTeXML::Common::Color>,
L<LaTeXML::Core::Alignment>,
L<LaTeXML::Common::XML>,
L<LaTeXML::Util::Radix>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
