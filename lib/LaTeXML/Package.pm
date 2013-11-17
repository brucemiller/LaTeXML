# -*- CPERL -*-
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
use Readonly;
use LaTeXML::Global;
use LaTeXML::Definition;
use LaTeXML::Parameters;
use LaTeXML::Util::Pathname;
use LaTeXML::Util::WWW;
use Unicode::Normalize;
use Text::Balanced;
use base qw(Exporter);
our @EXPORT = (qw(&DefExpandable
    &DefMacro &DefMacroI
    &DefConditional &DefConditionalI
    &DefPrimitive  &DefPrimitiveI
    &DefRegister &DefRegisterI
    &DefConstructor &DefConstructorI
    &dualize_arglist
    &DefMath &DefMathI &DefEnvironment &DefEnvironmentI
    &convertLaTeXArgs),

  # Class, Package and File loading.
  qw(&Input &InputContent &InputDefinitions &RequirePackage &LoadClass &LoadPool &FindFile
    &DeclareOption &PassOptions &ProcessOptions &ExecuteOptions
    &AddToMacro &AtBeginDocument &AtEndDocument),

  # Counter support
  qw(&NewCounter &CounterValue &SetCounter &AddToCounter &StepCounter &RefStepCounter &RefStepID &ResetCounter
    &GenerateID),

  # Document Model
  qw(&Tag &DocType &RelaxNGSchema &RegisterNamespace &RegisterDocumentNamespace),

  # Document Rewriting
  qw(&DefRewrite &DefMathRewrite
    &DefLigature &DefMathLigature),

  # Mid-level support for writing definitions.
  qw(&Expand &Invocation &Digest &DigestIf &DigestLiteral
    &RawTeX &Let),

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
    &LookupMeaning &LookupDefinition &InstallDefinition
    &LookupMathcode &AssignMathcode
    &LookupSFcode &AssignSFcode
    &LookupLCcode &AssignLCcode
    &LookupUCcode &AssignUCcode
    &LookupDelcode &AssignDelcode
    ),

  # Random low-level token or string operations.
  qw(&CleanID &CleanLabel &CleanIndexKey &CleanBibKey &CleanURL &CleanDimension
    &UTF
    &roman &Roman),
  # Math & font state.
  qw(&MergeFont),

  qw(&CheckOptions),
  # Resources
  qw(&RequireResource &ProcessPendingResources),

  @LaTeXML::Global::EXPORT);

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
  $cs = T_CS(ToString($cs)) unless ref $cs eq 'LaTeXML::Token';
  return $cs; }

sub parsePrototype {
  my ($proto) = @_;
  my $oproto = $proto;
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
  return ($cs, parseParameters($proto, $cs)); }

# Convert a LaTeX-style argument spec to our Package form.
# Ie. given $nargs and $optional, being the two optional arguments to
# something like \newcommand, convert it to the form we use
sub convertLaTeXArgs {
  my ($nargs, $optional) = @_;
  $nargs = $nargs->toString if ref $nargs;
  $nargs = 0 unless $nargs;
  my @params = ();
  if ($optional) {
    push(@params, LaTeXML::Parameters::newParameter('Optional',
        "[Default:" . UnTeX($optional) . "]",
        extra => [$optional, undef]));
    $nargs--; }
  push(@params, map { LaTeXML::Parameters::newParameter('Plain', '{}') } 1 .. $nargs);
  return (@params ? LaTeXML::Parameters->new(@params) : undef); }

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

sub LookupMathcode {
  my ($char) = @_;
  return $STATE->lookupMathcode($char); }

sub AssignMathcode {
  my ($char, $mathcode, $scope) = @_;
  $STATE->assigbMathcode($char, $mathcode, $scope);
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
  $STATE->assignMeaning($token1, $STATE->lookupMeaning($token2), $scope);
  AfterAssignment();
  return; }

sub Digest {
  my (@stuff) = @_;
  return $STATE->getStomach->digest(Tokens(map { (ref $_ ? $_ : TokenizeInternal($_)) } @stuff)); }

# probably need to export this, as well?
sub DigestLiteral {
  my (@stuff) = @_;
# Perhaps should do StartSemiverbatim, but is it safe to push a frame? (we might cover over valid changes of state!)
  my $font = LookupValue('font');
  AssignValue(font => $font->merge(encoding => 'ASCII'), 'local');  # try to stay as ASCII as possible
  my $value = $STATE->getStomach->digest(Tokens(map { (ref $_ ? $_ : Tokenize($_)) } @stuff));
  AssignValue(font => $font);
  return $value; }

sub DigestIf {
  my ($token) = @_;
  $token = T_CS($token) unless ref $token;
  if (my $defn = LookupDefinition($token)) {
    return $STATE->getStomach->digest($token); }
  else {
    return; } }

sub ReadParameters {
  my ($gullet, $spec) = @_;
  my $for = T_OTHER("Anonymous");
  my $parm = parseParameters($spec, $for);
  return ($parm ? $parm->readArguments($gullet, $for) : ()); }

# Merge the current font with the style specifications
sub MergeFont {
  my (@kv) = @_;
  AssignValue(font => LookupValue('font')->merge(@kv), 'local');
  return; }

# Dumb place for this, but where else...
# The TeX way! (bah!! hint: try a large number)
Readonly my @rmletters => ('i', 'v', 'x', 'l', 'c', 'd', 'm');

sub roman_aux {
  my ($n) = @_;
  my $div = 1000;
  my $s = ($n > $div ? ('m' x int($n / $div)) : '');
  my $p = 4;
  while ($n %= $div) {
    $div /= 10;
    my $d = int($n / $div);
    if ($d % 5 == 4) { $s .= $rmletters[$p]; $d++; }
    if ($d > 4) { $s .= $rmletters[$p + int($d / 5)]; $d %= 5; }
    if ($d) { $s .= $rmletters[$p] x $d; }
    $p -= 2; }
  return $s; }

# Convert the number to lower case roman numerals, returning a list of LaTeXML::Token
sub roman {
  my (@stuff) = @_;
  return ExplodeText(roman_aux(@stuff)); }
# Convert the number to upper case roman numerals, returning a list of LaTeXML::Token
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
  $key =~ s/:/../g;                        # No colons!
  return $key; }

sub CleanLabel {
  my ($label, $prefix) = @_;
  my $key = ToString($label);
  $key =~ s/^\s+//s; $key =~ s/\s+$//s;    # Trim leading/trailing, in any case
  $key =~ s/\s+/_/sg;
  return ($prefix || "LABEL") . ":" . $key; }

sub CleanIndexKey {
  my ($key) = @_;
  $key = ToString($key);
  $key =~ s/^\s+//s; $key =~ s/\s+$//s;    # Trim leading/trailing, in any case
       # We don't want accented chars (do we?) but we need to decompose the accents!
  $key = NFD($key);
  $key =~ s/[^a-zA-Z0-9]//g;
  $key = NFC($key);    # just to be safe(?)
## Shouldn't be case insensitive?
##  $key =~ tr|A-Z|a-z|;
  return $key; }

sub CleanBibKey {
  my ($key) = @_;
  $key = lc(ToString($key));    # Case insensitive
  $key =~ s/^\s+//s; $key =~ s/\s+$//s;    # Trim leading/trailing, in any case
  $key =~ s/\s//sg;
  return $key; }

sub CleanURL {
  my ($url) = @_;
  $url = ToString($url);
  $url =~ s/^\s+//s; $url =~ s/\s+$//s;    # Trim leading/trailing, in any case
  $url =~ s/\\~{}/~/g;
  return $url; }

# pretty printer, sorta
sub CleanDimension {
  my ($dim) = @_;
  if (!defined $dim) {
    return $dim; }
  elsif (ref $dim) {
    $dim = $dim->ptValue; }
  elsif ($dim =~ /\s*(.*)\s*pt\s*$/) {
    $dim = $1; }
  elsif ($dim) {
    $dim = int($dim * 100); }
  return ($dim ? $dim . "pt" : undef); }

#======================================================================
# Defining new Control-sequence Parameter types.
#======================================================================

Readonly my $parameter_options => {
  nargs => 1, reversion => 1, optional => 1, novalue => 1,
  semiverbatim => 1, undigested => 1 };

sub DefParameterType {
  my ($type, $reader, %options) = @_;
  CheckOptions("DefParameterType $type", $parameter_options, %options);
  $LaTeXML::Parameters::PARAMETER_TABLE{$type} = { reader => $reader, %options };
  return;
}

sub DefColumnType {
  my ($proto, $expansion) = @_;
  if ($proto =~ s/^(.)//) {
    my $char = $1;
    $proto =~ s/^\s*//;
    my $params = parseParameters($proto, $char);
    $expansion = TokenizeInternal($expansion) unless ref $expansion;
    DefMacroI(T_CS('\NC@rewrite@' . $char), $params, $expansion); }
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
  DefMacroI(T_CS("\\the$ctr"), undef, "\\arabic{$ctr}", scope => 'global');
