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
use LaTeXML::Core::KeyVals;
use LaTeXML::Core::Pair;
use LaTeXML::Core::PairList;
use LaTeXML::Common::Color;
# Utitlities
use LaTeXML::Util::Pathname;
use LaTeXML::Util::WWW;
use LaTeXML::Common::XML;
use LaTeXML::Core::Rewrite;
use LaTeXML::Util::Radix;
use File::Which;
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
    &GenerateID &AfterAssignment),

  # Document Model
  qw(&Tag &DocType &RelaxNGSchema &RegisterNamespace &RegisterDocumentNamespace),

  # Document Rewriting
  qw(&DefRewrite &DefMathRewrite
    &DefLigature &DefMathLigature),

  # Mid-level support for writing definitions.
  qw(&Expand &Invocation &Digest &DigestIf &DigestLiteral
    &RawTeX &Let &StartSemiverbatim &EndSemiverbatim
    &Tokenize &TokenizeInternal),

  # Font encoding
  qw(&DeclareFontMap &FontDecode &FontDecodeString &LoadFontMap),

  # Color
  qw(&DefColor &DefColorModel &LookupColor),

  # Support for structured/argument readers
  qw(&ReadParameters &DefParameterType  &DefColumnType
    &DefKeyVal &GetKeyVal &GetKeyVals),

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
  qw(&CleanID &CleanLabel &CleanIndexKey &CleanBibKey &NormalizeBibKey &CleanURL
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
      push(@params, LaTeXML::Core::Parameter->new('Plain', $spec, extra => [$inner])); }
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

# This new declaration allows you to define the type associated with
# the value for specific keys.
sub DefKeyVal {
  my ($keyset, $key, $type, $default) = @_;
  my $paramlist = LaTeXML::Package::parseParameters($type, "KeyVal $key in set $keyset");
  AssignValue('KEYVAL@' . $keyset . '@' . $key              => $paramlist);
  AssignValue('KEYVAL@' . $keyset . '@' . $key . '@default' => Tokenize($default))
    if defined $default;
  return; }

# These functions allow convenient access to KeyVal objects within constructors.
# Access the value associated with a given key.
# Can use in constructor: eg. <foo attrib='&GetKeyVal(#1,'key')'>
sub GetKeyVal {
  my ($keyval, $key) = @_;
  return (defined $keyval) && $keyval->getValue($key); }

# Access the entire hash.
# Can use in constructor: <foo %&GetKeyVals(#1)/>
sub GetKeyVals {
  my ($keyval) = @_;
  return (defined $keyval ? $keyval->getKeyVals : {}); }

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
  $url =~ s/\\~{}/~/g;
  return $url; }

#======================================================================
# Defining new Control-sequence Parameter types.
#======================================================================

my $parameter_options = {    # [CONSTANT]
  nargs => 1, reversion => 1, optional => 1, novalue => 1,
  semiverbatim => 1, undigested => 1 };

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
  DefMacroI(T_CS("\\the$ctr"), undef, "\\arabic{$ctr}", scope => 'global');
  my $prefix = $options{idprefix};
  AssignValue('@ID@prefix@' . $ctr => $prefix, 'global') if $prefix;
  $prefix = LookupValue('@ID@prefix@' . $ctr) unless $prefix;
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
  my ($ctr) = @_;
  my $value = CounterValue($ctr);
  AssignValue("\\c\@$ctr" => $value->add(Number(1)), 'global');
  AfterAssignment();
  DefMacroI(T_CS("\\\@$ctr\@ID"), undef, Tokens(Explode(LookupValue('\c@' . $ctr)->valueOf)),
    scope => 'global');
  # and reset any within counters!
  if (my $nested = LookupValue("\\cl\@$ctr")) {
    foreach my $c ($nested->unlist) {
      ResetCounter(ToString($c)); } }
  DigestIf(T_CS("\\the$ctr"));
  return; }

# HOW can we retract this?
sub RefStepCounter {
  my ($ctr) = @_;
  my $refnumtokens = StepCounter($ctr);
  DefMacroI(T_CS("\\\@$ctr\@ID"), undef, Tokens(Explode(LookupValue('\c@' . $ctr)->valueOf)),
    scope => 'global');
  my $iddef = LookupDefinition(T_CS("\\the$ctr\@ID"));
  my $has_id = $iddef && ((!defined $iddef->getParameters) || ($iddef->getParameters->getNumArgs == 0));

  DefMacroI(T_CS('\@currentlabel'), undef, T_CS("\\the$ctr"), scope => 'global');
  DefMacroI(T_CS('\@currentID'), undef, T_CS("\\the$ctr\@ID"), scope => 'global') if $has_id;

###  my $id      = $has_id && ToString(Digest($idtokens));
  #  my $id      = $has_id && ToString(DigestLiteral($idtokens));
  my $id = $has_id && ToString(DigestLiteral(T_CS("\\the$ctr\@ID")));

  #  my $refnum  = ToString(Digest(T_CS("\\the$ctr")));
  #  my $frefnum = ToString(Digest(Invocation(T_CS('\lx@fnum@@'),$ctr)));
  #  my $rrefnum  = ToString(Digest(Invocation(T_CS('\lx@refnum@@'),$ctr)));

  my $refnum    = Digest(T_CS("\\the$ctr"));
  my $frefnum   = Digest(Invocation(T_CS('\lx@fnum@@'), $ctr));
  my $rrefnum   = Digest(Invocation(T_CS('\lx@refnum@@'), $ctr));
  my $s_refnum  = ToString($refnum);
  my $s_frefnum = ToString($frefnum);
  my $s_rrefnum = ToString($rrefnum);
  # Any scopes activated for previous value of this counter (& any nested counters) must be removed.
  # This may also include scopes activated for \label
  deactivateCounterScope($ctr);
  # And install the scope (if any) for this reference number.
  AssignValue(current_counter => $ctr, 'local');
  AssignValue('scopes_for_counter:' . $ctr => [$ctr . ':' . $s_refnum], 'local');
  $STATE->activateScope($ctr . ':' . $s_refnum);
  return (refnum => $refnum,
    ($frefnum && (!$refnum || ($s_frefnum ne $s_refnum)) ? (frefnum => $frefnum) : ()),
    ($rrefnum && ($frefnum ? ($s_rrefnum ne $s_frefnum) : (!$refnum || ($s_rrefnum ne $s_refnum)))
      ? (rrefnum => $rrefnum) : ()),
    ($has_id ? (id => $id) : ())); }

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
  my ($ctr) = @_;
  my $unctr = "UN$ctr";
  StepCounter($unctr);
  DefMacroI(T_CS("\\\@$ctr\@ID"), undef,
    Tokens(T_OTHER('x'), Explode(LookupValue('\c@' . $unctr)->valueOf)),
    scope => 'global');
  DefMacroI(T_CS('\@currentID'), undef, T_CS("\\the$ctr\@ID"));
  return (id => ToString(Digest(T_CS("\\the$ctr\@ID")))); }

sub ResetCounter {
  my ($ctr) = @_;
  AssignValue('\c@' . $ctr => Number(0), 'global');
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
  if (!$node->hasAttribute('xml:id') && $document->canHaveAttribute($node, 'xml:id')) {
    my $ancestor = $document->findnode('ancestor::*[@xml:id][1]', $node)
      || $document->getDocument->documentElement;
    ## Old versions don't like $ancestor->getAttribute('xml:id');
    my $ancestor_id = $ancestor && $ancestor->getAttributeNS("http://www.w3.org/XML/1998/namespace", 'id');
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
  if (my $defn = LookupDefinition((ref $token ? $token : T_CS($token)))) {
    return Tokens($defn->invocation(@args)); }
  else {
    Fatal('undefined', $token, undef,
      "Can't invoke " . Stringify($token) . "; it is undefined");
    return Tokens(); } }

sub RawTeX {
  my ($text) = @_;
  # It could be as simple as this, except if catcodes get changed, it's too late!!!
  #  Digest(TokenizeInternal($text));
  my $stomach = $STATE->getStomach;
  my $savedcc = $STATE->lookupCatcode('@');
  $STATE->assignCatcode('@' => CC_LETTER);

  $stomach->getGullet->readingFromMouth(LaTeXML::Core::Mouth->new($text), sub {
      my ($gullet) = @_;
      my $token;
      while ($token = $gullet->readXToken(0)) {
        next if $token->equals(T_SPACE);
        $stomach->invokeToken($token); } });

  $STATE->assignCatcode('@' => $savedcc);
  return; }

sub StartSemiverbatim {
  $STATE->beginSemiverbatim;
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
  scope => 1, locked => 1, mathactive => 1 };

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
    $STATE->installDefinition(LaTeXML::Core::Definition::Conditional->new($cs, undef, undef, is_fi => 1, %options),
      $options{scope}); }
  elsif ($csname eq '\else') {
    $STATE->installDefinition(LaTeXML::Core::Definition::Conditional->new($cs, undef, undef, is_else => 1, %options),
      $options{scope}); }
  elsif ($csname eq '\or') {
    $STATE->installDefinition(LaTeXML::Core::Definition::Conditional->new($cs, undef, undef, is_or => 1, %options),
      $options{scope}); }
  elsif ($csname =~ /^\\(?:if(.*)|unless)$/) {
    my $name = $1;
    if ((defined $name) && ($name ne 'case')
      && (!defined $test)) {    # user-defined conditional, like with \newif
      $test = sub { LookupValue('Boolean:' . $name); };
      DefPrimitiveI(T_CS('\\' . $name . 'true'), undef, sub {
          AssignValue('Boolean:' . $name => 1); });
      DefPrimitiveI(T_CS('\\' . $name . 'false'), undef, sub {
          AssignValue('Boolean:' . $name => 0); }); }
    # For \ifcase, the parameter list better be a single Number !!
###    $paramlist = parseParameters($paramlist, $cs) if defined $paramlist && !ref $paramlist;
    $STATE->installDefinition(LaTeXML::Core::Definition::Conditional->new($cs, $paramlist, $test,
        is_conditional => 1, %options),
      $options{scope}); }
  else {
    Error('misdefined', $cs, $STATE->getStomach,
      "The conditional " . Stringify($cs) . " is being defined but doesn't start with \\if"); }
  AssignValue(ToString($cs) . ":locked" => 1) if $options{locked};
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
  bounded => 1, locked => 1, alias => 1 };

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

      isPrefix => $options{isPrefix}),
    $options{scope});
  AssignValue(ToString($cs) . ":locked" => 1) if $options{locked};
  return; }

my $register_options = {    # [CONSTANT]
  readonly => 1, getter => 1, setter => 1 };
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
  my $name   = ToString($cs);
  my $getter = $options{getter}
    || sub { LookupValue(join('', $name, map { ToString($_) } @_)) || $value; };
  my $setter = $options{setter}
    || ($options{readonly}
    ? sub { my ($v, @args) = @_;
      Error('unexpected', $name, $STATE->getStomach,
        "Can't assign to register $name"); return; }
    : sub { my ($v, @args) = @_;
      AssignValue(join('', $name, map { ToString($_) } @args) => $v); });
  # Not really right to set the value!
  AssignValue(ToString($cs) => $value) if defined $value;
  $STATE->installDefinition(LaTeXML::Core::Definition::Register->new($cs, $paramlist,
      registerType => $type,
      getter       => $getter, setter => $setter,
      readonly     => $options{readonly}),
    'global');
  return; }

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
  reversion    => 1, properties  => 1, alias           => 1, nargs          => 1,
  beforeDigest => 1, afterDigest => 1, beforeConstruct => 1, afterConstruct => 1,
  captureBody  => 1, scope       => 1, bounded         => 1, locked         => 1 };

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
      reversion       => ($options{reversion} && !ref $options{reversion}
        ? Tokenize($options{reversion}) : $options{reversion}),
      captureBody => $options{captureBody},
      properties => $options{properties} || {}),
    $options{scope});
  AssignValue(ToString($cs) . ":locked" => 1) if $options{locked};
  return; }

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
  name => 1, meaning => 1, omcd => 1, reversion => 1, alias => 1,
  role => 1, operator_role => 1, reorder => 1, dual => 1,
  mathstyle    => 1, font               => 1,
  scriptpos    => 1, operator_scriptpos => 1,
  stretchy     => 1, operator_stretchy  => 1,
  beforeDigest => 1, afterDigest        => 1, scope => 1, nogroup => 1, locked => 1 };
my $simpletoken_options = {    # [CONSTANT]
  name => 1, meaning => 1, omcd => 1, role => 1, mathstyle => 1,
  font => 1, scriptpos => 1, scope => 1, locked => 1 };

sub dualize_arglist {
  my (@args) = @_;
  my (@cargs, @pargs);
  foreach my $arg (@args) {
    if ((defined $arg) && $arg->unlist) {    # defined and non-empty args get an ID.
      StepCounter('@XMARG');
      DefMacroI(T_CS('\@@XMARG@ID'), undef, Tokens(Explode(LookupValue('\c@@XMARG')->valueOf)),
        scope => 'global');
      my $id = Expand(T_CS('\the@XMARG@ID'));
      push(@cargs, Invocation(T_CS('\@XMArg'), $id, $arg));
      push(@pargs, Invocation(T_CS('\@XMRef'), $id)); }
    else {
      push(@cargs, $arg);
      push(@pargs, $arg); } }
  return ([@cargs], [@pargs]); }
# Quick reversal!
#  ( [@pargs],[@cargs] ); }

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
  my $name    = $csname;
  $name =~ s/^\\//;
  $name = $options{name} if defined $options{name};
  $name = undef          if (defined $name)
    && (($name eq $presentation) || ($name eq '')
    || ((defined $meaning) && ($meaning eq $name)));
  $options{name} = $name;
  $options{role} = 'UNKNOWN'
    if ($nargs == 0) && !defined $options{role};
  $options{operator_role} = 'UNKNOWN'
    if ($nargs > 0) && !defined $options{operator_role};
  $options{reversion} = Tokenize($options{reversion})
    if $options{reversion} && !ref $options{reversion};
  # Store some data for introspection
  defmath_introspective($cs, $paramlist, $presentation, %options);

  # If single character, handle with a rewrite rule
  if (length($csname) == 1) {
    defmath_rewrite($cs, %options); }

  # If the presentation is complex, and involves arguments,
  # we will create an XMDual to separate content & presentation.
  elsif ((ref $presentation eq 'CODE')
    || ((ref $presentation) && grep { $_->equals(T_PARAM) } $presentation->unlist)
    || (!(ref $presentation) && ($presentation =~ /\#\d|\\./))) {
    defmath_dual($cs, $paramlist, $presentation, %options); }

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
  my $rw_options = { name => 1, meaning => 1, omcd => 1, role => 1, mathstyle => 1 }; # (well, mathstyle?)
  CheckOptions("DefMath reimplemented as DefRewrite ($csname)", $rw_options, %options);
  AssignValue('math_token_attributes_' . $csname => {%options}, 'global');
  return; }

sub defmath_common_constructor_options {
  my ($cs, $presentation, %options) = @_;
  return (
    alias => $options{alias} || $cs->getString,
    (defined $options{reversion} ? (reversion => $options{reversion}) : ()),
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
      font               => sub { LookupValue('font')->specialize($presentation); } },
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
        my ($self,  @args)  = @_;
        my ($cargs, $pargs) = dualize_arglist(@args);
        Invocation(T_CS('\DUAL'),
          ($options{role} ? T_OTHER($options{role}) : undef),
          Invocation($cont_cs, @$cargs),
          Invocation($pres_cs, @$pargs))->unlist; }),
    $options{scope});
  # Make the presentation macro.
  $presentation = TokenizeInternal($presentation) unless ref $presentation;
  $presentation = Invocation(T_CS('\@ASSERT@MEANING'), T_OTHER($options{meaning}), $presentation)
    if $options{meaning};
  $STATE->installDefinition(LaTeXML::Core::Definition::Expandable->new($pres_cs, $paramlist, $presentation),
    $options{scope});
  my $nargs = ($paramlist ? scalar($paramlist->getParameters) : 0);
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

sub defmath_prim {
  my ($cs, $paramlist, $presentation, %options) = @_;
  my $string     = ToString($presentation);
  my %attributes = %options;
  my $reqfont    = $attributes{font} || {};
  delete $attributes{locked};
  delete $attributes{font};
  ## Whoops???
###  $attributes{name} = $name if (defined $name) && !(defined $options{name});
  $STATE->installDefinition(LaTeXML::Core::Definition::Primitive->new($cs, undef, sub {
        my ($stomach) = @_;
        my $locator   = $stomach->getGullet->getLocator;
        my $font      = LookupValue('font')->merge(%$reqfont)->specialize($string);
        my $attr      = {};
        foreach my $key (keys %attributes) {
          my $value = $attributes{$key};
          if (ref $value eq 'CODE') {
            $$attr{$key} = &$value(); }
          else {
            $$attr{$key} = $value; } }
        LaTeXML::Core::Box->new($string, $font, $locator, $cs,
          mode => 'math', attributes => $attr); }));
  return; }

sub defmath_cons {
  my ($cs, $paramlist, $presentation, %options) = @_;
  # do we need to do anything about digesting the presentation?
  my $end_tok   = (defined $presentation ? '>' . ToString($presentation) . '</ltx:XMTok>' : "/>");
  my $cons_attr = "name='#name' meaning='#meaning' omcd='#omcd' mathstyle='#mathstyle'";
  my $nargs     = ($paramlist ? scalar($paramlist->getParameters) : 0);
  $STATE->installDefinition(LaTeXML::Core::Definition::Constructor->new($cs, $paramlist,
      ($nargs == 0
          # If trivial presentation, allow it in Text
        ? ($presentation !~ /(?:\(|\)|\\)/
          ? "?#isMath(<ltx:XMTok role='#role' scriptpos='#scriptpos' stretchy='#stretchy'"
            . " font='#font' $cons_attr$end_tok)"
            . "($presentation)"
          : "<ltx:XMTok role='#role' scriptpos='#scriptpos' stretchy='#stretchy'"
            . " font='#font' $cons_attr$end_tok")
        : "<ltx:XMApp role='#role' scriptpos='#scriptpos' stretchy='#stretchy'>"
          . "<ltx:XMTok $cons_attr font='#font' role='#operator_role'"
          . " scriptpos='#operator_scriptpos' stretchy='#operator_stretchy' $end_tok"
          . join('', map { "<ltx:XMArg>#$_</ltx:XMArg>" } 1 .. $nargs)
          . "</ltx:XMApp>"),
      defmath_common_constructor_options($cs, $presentation, %options)), $options{scope});
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
  reversion        => 1, scope           => 1, locked => 1 };

sub DefEnvironment {
  my ($proto, $replacement, %options) = @_;
  CheckOptions("DefEnvironment ($proto)", $environment_options, %options);
##  $proto =~ s/^\{([^\}]+)\}\s*//; # Pull off the environment name as {name}
##  my $paramlist=parseParameters($proto,"Environment $name");
##  my $name = $1;
  my ($name, $paramlist) = Text::Balanced::extract_bracketed($proto, '{}');
  $name =~ s/[\{\}]//g;
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
  $STATE->installDefinition(LaTeXML::Core::Definition::Constructor
      ->new(T_CS("\\begin{$name}"), $paramlist, $replacement,
      beforeDigest => flatten(($options{requireMath} ? (sub { requireMath($name); }) : ()),
        ($options{forbidMath} ? (sub { forbidMath($name); }) : ()),
        ($mode ? (sub { $_[0]->beginMode($mode); })
          : (sub { $_[0]->bgroup; })),
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
      properties => $options{properties} || {},
      (defined $options{reversion} ? (reversion => $options{reversion}) : ()),

      ), $options{scope});
  $STATE->installDefinition(LaTeXML::Core::Definition::Constructor
      ->new(T_CS("\\end{$name}"), "", "",
      beforeDigest => flatten($options{beforeDigestEnd}),
      afterDigest  => flatten($options{afterDigest},
        sub { my $env = LookupValue('current_environment');
          Error('unexpected', "\\end{$name}", $_[0],
            "Can't close environment $name",
            "Current are "
              . join(', ', $STATE->lookupStackedValues('current_environment')))
            unless $env && $name eq $env;
          return; },
        ($mode ? (sub { $_[0]->endMode($mode); })
          : (sub { $_[0]->egroup; }))),
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
      nargs => $options{nargs},
      captureBody => T_CS("\\end$name"),          # Required to capture!!
      properties => $options{properties} || {},
      (defined $options{reversion} ? (reversion => $options{reversion}) : ()),
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
  autoOpen => 1, autoClose => 1, afterOpen => 1, afterClose => 1,
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
  sty => 'package', cls => 'class', clo => 'class options',
  'cnf' => 'configuration', 'cfg' => 'configuration',
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
  if (LookupValue($file . '_contents')) {
    return $file; }
  if (pathname_is_absolute($file)) {    # And if we've got an absolute path,
    return $file if -f $file;           # No need to search, just check if it exists.
    return; }                           # otherwise we're never going to find it.
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
  if (!$options{noltxml}
    && ($path = pathname_find("$file.ltxml", paths => $ltxml_paths, installation_subdir => 'Package'))) {
    return $path; }
  # If we're looking for TeX, look within our paths & installation first (faster than kpse)
  if (!$options{notex}
    && ($path = pathname_find($file, paths => $paths))) {
    return $path; }
  # Otherwise, pass on to kpsewhich
  # Depending on flags, maybe search for ltxml in texmf or for plain tex in ours!
  # The main point, though, is to we make only ONE (more) call.
  return if grep { pathname_is_nasty($_) } @$paths;    # SECURITY! No nasty paths in cmdline
        # Do we need to sanitize these environment variables?
  my $kpsewhich = which($ENV{LATEXML_KPSEWHICH} || 'kpsewhich');
  local $ENV{TEXINPUTS} = join($Config::Config{'path_sep'},
    @$paths, $ENV{TEXINPUTS} || $Config::Config{'path_sep'});
  my $candidates = join(' ',
    ((!$options{noltxml} && !$nopaths) ? ("$file.ltxml") : ()),
    (!$options{notex} ? ($file) : ()));
  if ($kpsewhich && (my $result = `"$kpsewhich" $candidates`)) {
    if ($result =~ /^\s*(.+?)\s*\n/s) {
      return $1; } }
  if ($urlbase && ($path = url_find($file, urlbase => $urlbase))) {
    return $path; }
  return; }

sub pathname_is_nasty {
  my ($pathname) = @_;
  return $pathname =~ /[^\w\-_\+\=\/\\\.~\:]/; }

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
  # Note that we are reading definitions (and recursive input is assumed also defintions)
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
      content => LookupValue($pathname . '_contents')),
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
  # print STDERR "Passing to $name.$ext options: ".join(', ',@options)."\n";
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
  my $name = LookupDefinition(T_CS('\@currname')) && ToString(Digest(T_CS('\@currname')));
  my $ext  = LookupDefinition(T_CS('\@currext'))  && ToString(Digest(T_CS('\@currext')));
  my @declaredoptions = @{ LookupValue('@declaredoptions') };
  my @curroptions = @{ (defined($name) && defined($ext) && LookupValue('opt@' . $name . '.' . $ext)) || [] };
  #  print STDERR "\nProcessing options for $name.$ext: ".join(', ',@curroptions)."\n";

  my $defaultcs = T_CS('\default@ds');
  # Execute options in declared order (unless \ProcessOptions*)

  if ($options{inorder}) {    # Execute options in order (eg. \ProcessOptions*)
    foreach my $option (@curroptions) {
      DefMacroI('\CurrentOption', undef, $option);
      my $cs = T_CS('\ds@' . $option);
      if (LookupDefinition($cs)) {
        Digest($cs); }
      elsif ($defaultcs) {
        Digest($defaultcs); } } }
  else {                      # Execute options in declared order (eg. \ProcessOptions)
    foreach my $option (@declaredoptions) {
      if (grep { $option eq $_ } @curroptions) {
        @curroptions = grep { $option ne $_ } @curroptions;    # Remove it, since it's been handled.
        DefMacroI('\CurrentOption', undef, $option);
        Digest(T_CS('\ds@' . $option)); } }
    # Now handle any remaining options (eg. default options), in the given order.
    foreach my $option (@curroptions) {
      DefMacroI('\CurrentOption', undef, $option);
      Digest($defaultcs); } }
  # Now, undefine the handlers?
  foreach my $option (@declaredoptions) {
    Let('\ds@' . $option, '\relax'); }
  return; }

sub ExecuteOptions {
  my (@options) = @_;
  my %unhandled = ();
  foreach my $option (@options) {
    my $cs = T_CS('\ds@' . $option);
    if (LookupDefinition($cs)) {
      DefMacroI('\CurrentOption', undef, $option);
      Digest($cs); }
    else {
      $unhandled{$option} = 1; } }
  foreach my $option (keys %unhandled) {
    Info('unexpected', $option, $STATE->getStomach->getGullet,
      "Unexpected options passed to ExecuteOptions '$option'"); }
  return; }

sub resetOptions {
  AssignValue('@declaredoptions', []);
  Let('\default@ds',
    (ToString(Digest(T_CS('\@currext'))) eq 'cls'
      ? '\OptionNotUsed' : '\@unknownoptionerror'));
  return; }

sub AddToMacro {
  my ($cs, @tokens) = @_;
  $cs = T_CS($cs) unless ref $cs;
  @tokens = map { (ref $_ ? $_ : TokenizeInternal($_)) } @tokens;
  # Needs error checking!
  my $defn = LookupDefinition($cs);
  if (!defined $defn || !$defn->isExpandable) {
    Error('unexpected', $cs, $STATE->getStomach->getGullet,
      ToString($cs) . " is not an expandable control sequence"); }
  else {
    DefMacroI($cs, undef, Tokens($defn->getExpansion->unlist,
        map { $_->unlist } map { (ref $_ ? $_ : TokenizeInternal($_)) } @tokens),
      scope => 'global'); }
  return; }

#======================================================================
my $inputdefinitions_options = {    # [CONSTANT]
  options => 1, withoptions => 1, handleoptions => 1,
  type => 1, as_class => 1, noltxml => 1, notex => 1, noerror => 1, after => 1 };
#   options=>[options...]
#   withoptions=>boolean : pass options from calling class/package
#   after=>code or tokens or string as $name.$type-hook macro. (executed after the package is loaded)
# Returns the path that was loaded, or undef, if none found.
sub InputDefinitions {
  my ($name, %options) = @_;
  $name = ToString($name) if ref $name;
  $name =~ s/^\s*//; $name =~ s/\s*$//;
  CheckOptions("InputDefinitions ($name)", $inputdefinitions_options, %options);

  my $prevname = $options{handleoptions} && LookupDefinition(T_CS('\@currname')) && ToString(Digest(T_CS('\@currname')));
  my $prevext = $options{handleoptions} && LookupDefinition(T_CS('\@currext')) && ToString(Digest(T_CS('\@currext')));

  # This file will be treated somewhat as if it were a class
  # IF as_class is true
  # OR if it is loaded by such a class, and has withoptions true!!! (yikes)
  $options{as_class} = 1 if $options{handleoptions} && $options{withoptions}
    && grep { $prevname eq $_ } @{ LookupValue('@masquerading@as@class') || [] };

  $options{raw} = 1 if $options{noltxml};    # so it will be read as raw by Gullet.!L!
  my $astype = ($options{as_class} ? 'cls' : $options{type});

  my $filename = $name;
  $filename .= '.' . $options{type} if $options{type};
  if (my $file = FindFile($filename, type => $options{type},
      notex => $options{notex}, noltxml => $options{noltxml})) {
    if ($options{handleoptions}) {
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
      DefMacroI(T_CS("\\$name.$astype-hook"), undef, $options{after} || '');
      DefMacroI(T_CS('\opt@' . $name . '.' . $astype), undef,
        Tokens(Explode(join(',', @{ LookupValue('opt@' . $name . "." . $astype) }))));
    }

    my ($fdir, $fname, $ftype) = pathname_split($file);
    if ($ftype eq 'ltxml') {
      loadLTXML($filename, $file); }    # Perl module.
    else {
      loadTeXDefinitions($filename, $file); }
    if ($options{handleoptions}) {
      Digest(T_CS("\\$name.$astype-hook"));
      DefMacroI('\@currname', undef, Tokens(Explode($prevname))) if $prevname;
      DefMacroI('\@currext',  undef, Tokens(Explode($prevext)))  if $prevext;
      # Add an appropriately faked entry into \@filelist
      my ($d, $n, $e) = ($fdir, $fname, $ftype);    # If ftype is ltxml, reparse to get sty/cls!
      ($d, $n, $e) = pathname_split(pathname_concat($d, $n)) if $e eq 'ltxml';    # Fake it???
      my @p = (LookupDefinition(T_CS('\@filelist'))
        ? Expand(T_CS('\@filelist'))->unlist : ());
      my @n = Explode($e ? $n . '.' . $e : $n);
      DefMacroI('\@filelist', undef, (@p ? Tokens(@p, T_OTHER(','), @n) : Tokens(@n)));
      resetOptions(); }    # And reset options afterwards, too.
    return $file; }
  elsif (!$options{noerror}) {
    $STATE->noteStatus(missing => $name . ($options{type} ? '.' . $options{type} : ''));
    Error('missing_file', $name, $STATE->getStomach->getGullet,
      "Can't find "
        . ($options{notex} ? "binding for " : "")
        . (($options{type} && $definition_name{ $options{type} }) || 'definitions') . ' '
        . $name,
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
  InputDefinitions($package, type => $options{type} || 'sty', handleoptions => 1,
    # Pass classes options if we have NONE!
    withoptions => !($options{options} && @{ $options{options} }),
    %options);
  return; }

my $loadclass_options = {    # [CONSTANT]
  options => 1, withoptions => 1, after => 1 };

sub LoadClass {
  my ($class, %options) = @_;
  $class = ToString($class) if ref $class;
  CheckOptions("LoadClass ($class)", $loadclass_options, %options);
  # Note that we'll handle errors specifically for this case.
  if (my $success = InputDefinitions($class, type => 'cls', notex => 1, handleoptions => 1, noerror => 1,
      %options)) {
    return $success; }
  else {
    $STATE->noteStatus(missing => $class . '.cls');
    Warn('missing_file', $class, $STATE->getStomach->getGullet,
      "Can't find binding for class $class (using article)",
      maybeReportSearchPaths());
    if (my $success = InputDefinitions('article', type => 'cls', noerror => 1, %options)) {
      return $success; }
    else {
      Fatal('missing_file', 'article.cls.ltxml', $STATE->getStomach->getGullet,
        "Can't find binding for class article (installation error)");
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
    $encoding = $font->getEncoding; }
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
  my ($model, @spec) = @$color;
  $scope = 'global' if LookupValue('Boolean:globalcolors');
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

my $math_ligature_options = {};    # [CONSTANT]

sub DefMathLigature {
  my ($matcher, %options) = @_;
  CheckOptions("DefMathLigature", $math_ligature_options, %options);
  UnshiftValue('MATH_LIGATURES', { matcher => $matcher, %options });
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
  if (my $req = LookupValue('PENDING_RESOURCES')) {
    map { addResource($document, @$_) } @$req;
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

  use LaTeXML::Package;
  use strict;
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

To provide a LaTeXML-specific version of a LaTeX package C<mypackage.sty>
or class C<myclass.cls> (so that eg. C<\usepackage{mypackage}> works),
you create the file C<mypackage.sty.ltxml> or C<myclass.cls.ltxml>
and save it in the searchpath (current directory, or one of the directories
given to the --path option, or possibly added to the variable SEARCHPATHS).
Similarly, to provide document-specific customization for, say, C<mydoc.tex>,
you would create the file C<mydoc.latexml> (typically in the same directory).
However,  in the first cases, C<mypackage.sty.ltxml> are loaded I<instead> of
C<mypackage.sty>, while a file like C<mydoc.latexml> is loaded in I<addition> to
C<mydoc.tex>.
In either case, you'll C<use LaTeXML::Package;> to import the various declarations
and defining forms that allow you to specify what should be done with various
control sequences, whether there is special treatment of certain document elements,
and so forth.  Using C<LaTeXML::Package> also imports the functions and variables
defined in L<LaTeXML::Global>, so see that documentation as well.

Since LaTeXML attempts to mimic TeX, a familiarity with TeX's processing
model is also helpful.  Additionally, it is often useful, when implementing
non-trivial behaviour, to think TeX-like.

Many of the following forms take code references as arguments or options.
That is, either a reference to a defined sub, C<\&somesub>, or an
anonymous function S<sub { ... }>.  To document these cases, and the
arguments that are passed in each case, we'll use a notation like
S<CODE($token,..)>.

=head2 Control Sequences

Many of the following forms define the behaviour of control sequences.
In TeX you'll typically only define macros. In LaTeXML, we're
effectively redefining TeX itself,  so we define macros as well as primitives,
registers, constructors and environments.  These define the behaviour
of these commands when processed during the various phases of LaTeX's
immitation of TeX's digestive tract.

The first argument to each of these defining forms (C<DefMacro>, C<DefPrimive>, etc)
is a I<prototype> consisting of the control sequence being defined along with
the specification of parameters required by the control sequence.
Each parameter describes how to parse tokens following the control sequence into
arguments or how to delimit them.  To simplify coding and capture common idioms
in TeX/LaTeX programming, latexml's parameter specifications are more expressive
than TeX's  C<\def> or LaTeX's C<\newcommand>.  Examples of the prototypes for
familiar TeX or LaTeX control sequences are:

   DefConstructor('\usepackage[]{}',...
   DefPrimitive('\multiply Variable SkipKeyword:by Number',..
   DefPrimitive('\newcommand OptionalMatch:* {Token}[]{}', ...

=head3 Control Sequence Parameters

The general syntax for parameter for a control sequence is something like

  OpenDelim? Modifier? Type (: value (| value)* )? CloseDelim?

The enclosing delimiters, if any, are either {} or [], affect the way the
argument is delimited.  With {}, a regular TeX argument (token or sequence
balanced by braces) is read before parsing according to the type (if needed).
With [], a LaTeX optional argument is read, delimited by (non-nested) square brackets.

The modifier can be either C<Optional> or C<Skip>, allowing the argument to
be optional. For C<Skip>, no argument is contributed to the argument list.

The shorthands {} and [] default the type to C<Plain> and reads a normal
TeX argument or LaTeX default argument with no special parsing.

The general syntax for parameter specification is

 {}     reads a regular TeX argument, a sequence of
        tokens delimited by braces, or a single token.
 {spec} reads a regular TeX argument, then reparses it
        to match the given spec. The spec is parsed
        recursively, but usually should correspond to
        a single argument.
 [spec] reads an LaTeX-style optional argument. If the
        spec is of the form Default:stuff, then stuff
        would be the default value.
 Type   Reads an argument of the given type, where either
        Type has been declared, or there exists a ReadType
        function accessible from LaTeXML::Package::Pool.
 Type:value, or Type:value1:value2...    These forms
        pass additional Tokens to the reader function.
 OptionalType  Similar to Type, but it is not considered
        an error if the reader returns undef.
 SkipType  Similar to OptionalType, but the value returned
        from the reader is ignored, and does not occupy a
        position in the arguments list.

The predefined argument types are as follows.

=over 4

=item C<Plain>, C<Semiverbatim>

X<Plain>X<Semiverbatim>
Reads a standard TeX argument being either the next token, or if the
next token is an {, the balanced token list.  In the case of C<Semiverbatim>,
many catcodes are disabled, which is handy for URL's, labels and similar.

=item C<Token>, C<XToken>

X<Token>X<XToken>
Read a single TeX Token.  For C<XToken>, if the next token is expandable,
it is repeatedly expanded until an unexpandable token remains, which is returned.

=item C<Number>, C<Dimension>, C<Glue> or C<MuGlue>

X<Number>X<Dimension>X<Glue>X<MuGlue>
Read an Object corresponding to Number, Dimension, Glue or MuGlue,
using TeX's rules for parsing these objects.

=item C<Until:>I<match>, C<XUntil:>I<match>

X<Until>X<XUntil>
Reads tokens until a match to the tokens I<match> is found, returning
the tokens preceding the match. This corresponds to TeX delimited arguments.
For C<XUntil>, tokens are expanded as they are matched and accumulated.

=item C<UntilBrace>

X<UntilBrace>
Reads tokens until the next open brace C<{>.  
This corresponds to the peculiar TeX construct C<\def\foo#{...>.

=item C<Match:>I<match(|match)*>, C<Keyword:>I<match(|match)*>

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

=item C<Undigested>, C<Digested>, C<DigestUntil:>I<match>

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

=item C<SkipSpaces>,C<Skip1Space>

X<SkipSpaces>X<Skip1Space>
Skips one, or any number of, space tokens, if present, but contributes nothing to the argument list.

=back

=head3 Control of Scoping

Most defining commands accept an option to control how the definition is stored,
C<< scope=>$scope >>, where C<$scope> can be c<'global'> for global definitions,
C<'local'>, to be stored in the current stack frame, or a string naming a I<scope>.
A scope saves a set of definitions and values that can be activated at a later time.

Particularly interesting forms of scope are those that get automatically activated
upon changes of counter and label.  For example, definitions that have
C<< scope=>'section:1.1' >>  will be activated when the section number is "1.1",
and will be deactivated when the section ends.

=head3 Macros

=over 4

=item C<< DefMacro($prototype,$string | $tokens | $code,%options); >>

X<DefMacro>
Defines the macro expansion for C<$prototype>; a macro control sequence that is
expanded during macro expansion time (in the  L<LaTeXML::Core::Gullet>).  If a C<$string> is supplied, it will be
tokenized at definition time. Any macro arguments will be substituted for parameter
indicators (eg #1) at expansion time; the result is used as the expansion of
the control sequence. 

If defined by C<$code>, the form is C<CODE($gullet,@args)> and it
must return a list of L<LaTeXML::Core::Token>'s.


DefMacro options are

=over 4

=item scope=>$scope

See L</"Control of Scoping">.

=item locked=>boolean

Whether this definition is locked out of changes in the TeX sources.

=back

Examples:

  DefMacro('\thefootnote','\arabic{footnote}');
  DefMacro('\today',sub { ExplodeText(today()); });

=item C<< DefMacroI($cs,$paramlist,$string | $tokens | $code,%options); >>

X<DefMacroI>
Internal form of C<DefMacro> where the control sequence and parameter list
have already been separated; useful for definitions from within code.
Also, slightly more efficient for macros with no arguments (use C<undef> for
C<$paramlist>), and useful for obscure cases like defining C<\begin{something*}>
as a Macro.

=back

=head3 Conditionals

=over 4

=item C<< DefConditional($prototype,$test,%options); >>

X<DefConditional>
Defines a conditional for C<$prototype>; a control sequence that is
processed during macro expansion time (in the  L<LaTeXML::Core::Gullet>).
A conditional corresponds to a TeX C<\if>.
It evaluates C<$test>, which should be CODE that is applied to the arguments, if any.
Depending on whether the result of that evaluation returns a true or false value
(in the usual Perl sense), the result of the expansion is either the
first or else code following, in the usual TeX sense.

DefConditional options are

=over 4

=item scope=>$scope

See L</"Control of Scoping">.

=item locked=>boolean

Whether this definition is locked out of changes in the TeX sources.

=back

Example:

  DefConditional('\ifmmode',sub {
     LookupValue('IN_MATH'); });

=item C<< DefConditionalI($cs,$paramlist,$test,%options); >>

X<DefConditionalI>
Internal form of C<DefConditional> where the control sequence and parameter list
have already been parsed; useful for definitions from within code.
Also, slightly more efficient for conditinal with no arguments (use C<undef> for
C<$paramlist>).

=back

=head3 Primitives

=over 4

=item C<< DefPrimitive($prototype,$replacement,%options); >>

X<DefPrimitive>
Define a primitive control sequence; a primitive is processed during
digestion (in the  L<LaTeXML::Core::Stomach>), after macro expansion but before Construction time.
Primitive control sequences generate Boxes or Lists, generally
containing basic Unicode content, rather than structured XML.
Primitive control sequences are also executed for side effect during digestion,
effecting changes to the L<LaTeXML::Core::State>.

The C<$replacement> is either a string, used as the Boxes text content
(the box gets the current font), or C<CODE($stomach,@args)>, which is
invoked at digestion time, probably for side-effect, but returning Boxes or Lists.
C<$replacement> may also be undef, which contributes nothing to the document,
but does record the TeX code that created it.

DefPrimitive options are

=over 4

=item  mode=>(text|display_math|inline_math)

Changes to this mode during digestion.

=item  bounded=>boolean

If true, TeX grouping (ie. C<{}>) is enforced around this invocation.

=item  requireMath=>boolean,

=item  forbidMath=>boolean

These specify whether the given constructor can only appear,
or cannot appear, in math mode.

=item  font=>{fontspec...}

Specifies the font to use (see L</"MergeFont(%style);">).
If the font change is to only apply to material generated within this command,
you would also use C<<bounded=>1>>; otherwise, the font will remain in effect afterwards
as for a font switching command.

=item  beforeDigest=>CODE($stomach)

This option supplies a Daemon to be executed during digestion 
just before the main part of the primitive is executed.
The CODE should either return nothing (return;) or a list of digested items (Box's,List,Whatsit).
It can thus change the State and/or add to the digested output.

=item  afterDigest=>CODE($stomach)

This option supplies a Daemon to be executed during digestion
just after the main part of the primitive ie executed.
it should either return nothing (return;) or digested items.
It can thus change the State and/or add to the digested output.

=item  scope=>$scope

See L</"Control of Scoping">.

=item locked=>boolean

Whether this definition is locked out of changes in the TeX sources.

=item C<< isPrefix=>1 >>

Indicates whether this is a prefix type of command;
This is only used for the special TeX assignment prefixes, like C<\global>.

=back

Example:

   DefPrimitive('\begingroup',sub { $_[0]->begingroup; });

=item C<< DefPrimitiveI($cs,$paramlist,CODE($stomach,@args),%options); >>

X<DefPrimitiveI>
Internal form of C<DefPrimitive> where the control sequence and parameter list
have already been separated; useful for definitions from within code.

=item C<< DefRegister($prototype,$value,%options); >>

X<DefRegister>
Defines a register with the given initial value (a Number, Dimension, Glue, MuGlue or Tokens
--- I haven't handled Box's yet).  Usually, the C<$prototype> is just the control sequence,
but registers are also handled by prototypes like C<\count{Number}>. C<DefRegister> arranges
that the register value can be accessed when a numeric, dimension, ... value is being read,
and also defines the control sequence for assignment.

Options are

=over 4

=item C<readonly>

specifies if it is not allowed to change this value.

=item C<getter>=>CODE(@args)

=item C<setter>=>CODE($value,@args)

By default the value is stored in the State's Value table under a name concatenating the 
control sequence and argument values.  These options allow other means of fetching and
storing the value.

=back

Example:

  DefRegister('\pretolerance',Number(100));

=item C<< DefRegisterI($cs,$paramlist,$value,%options); >>

X<DefRegisterI>
Internal form of C<DefRegister> where the control sequence and parameter list
have already been parsed; useful for definitions from within code.

=back

=head3 Constructors

=over 4

=item C<< DefConstructor($prototype,$xmlpattern | $code,%options); >>

X<DefConstructor>
The Constructor is where LaTeXML really starts getting interesting;
invoking the control sequence will generate an arbitrary XML
fragment in the document tree.  More specifically: during digestion, the arguments
will be read and digested, creating a L<LaTeXML::Core::Whatsit> to represent the object. During
absorbtion by the L<LaTeXML::Core::Document>, the C<Whatsit> will generate the XML fragment according
to the replacement C<$xmlpattern>, or by executing C<CODE>.

The C<$xmlpattern> is simply a bit of XML as a string with certain substitutions to be made.
The substitutions are of the following forms:

If code is supplied,  the form is C<CODE($document,@args,%properties)>

=over 4

=item  #1, #2 ... #name

These are replaced by the corresponding argument (for #1) or property (for #name)
stored with the Whatsit. Each are turned into a string when it appears as
in an attribute position, or recursively processed when it appears as content.

=item C<&function(@args)>

Another form of substituted value is prefixed with C<&> which invokes a function.
For example, C< &func(#1) > would invoke the function C<func> on the first argument
to the control sequence; what it returns will be inserted into the document.

=item C<?COND(pattern)>  or C<?COND(ifpattern)(elsepattern)>

Patterns can be conditionallized using this form.  The C<COND> is any
of the above expressions, considered true if the result is non-empty.
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

=item  mode=>(text|display_math|inline_math)

Changes to this mode during digestion.

=item  bounded=>boolean

If true, TeX grouping (ie. C<{}>) is enforced around this invocation.

=item  requireMath=>boolean,

=item  forbidMath=>boolean

These specify whether the given constructor can only appear,
or cannot appear, in math mode.

=item  font=>{fontspec...}

Specifies the font to use (see L</"MergeFont(%style);">).
If the font change is to only apply to material generated within this command,
you would also use C<<bounded=>1>>; otherwise, the font will remain in effect afterwards
as for a font switching command.

=item  reversion=>$texstring or CODE($whatsit,#1,#2,...)

Specifies the reversion of the invocation back into TeX tokens
(if the default reversion is not appropriate).
The $textstring string can include #1,#2...
The CODE is called with the $whatsit and digested arguments
and must return a list of Token's.

=item  properties=>{prop=>value,...} or CODE($stomach,#1,#2...)

This option supplies additional properties to be set on the
generated Whatsit.  In the first form, the values can
be of any type, but if a value is a code references, it takes
the same args ($stomach,#1,#2,...) and should return the value;
it is executed before creating the Whatsit.
In the second form, the code should return a hash of properties.

=item  beforeDigest=>CODE($stomach)

This option supplies a Daemon to be executed during digestion
just before the Whatsit is created.  The CODE should either
return nothing (return;) or a list of digested items (Box's,List,Whatsit).
It can thus change the State and/or add to the digested output.

=item  afterDigest=>CODE($stomach,$whatsit)

This option supplies a Daemon to be executed during digestion
just after the Whatsit is created (and so the Whatsit already
has its arguments and properties). It should either return
nothing (return;) or digested items.  It can thus change the State,
modify the Whatsit, and/or add to the digested output.

=item  beforeConstruct=>CODE($document,$whatsit)

Supplies CODE to execute before constructing the XML
(generated by $replacement).

=item  afterConstruct=>CODE($document,$whatsit)

Supplies CODE to execute after constructing the XML.

=item  captureBody=>boolean or Token

if true, arbitrary following material will be accumulated into
a `body' until the current grouping level is reverted,
or till the C<Token> is encountered if the option is a C<Token>.
This body is available as the C<body> property of the Whatsit.
This is used by environments and math.

=item  alias=>$control_sequence

Provides a control sequence to be used when reverting Whatsit's back to Tokens,
in cases where it isn't the command used in the C<$prototype>.

=item  nargs=>$nargs

This gives a number of args for cases where it can't be infered directly
from the C<$prototype> (eg. when more args are explictly read by Daemons).

=item  scope=>$scope

See L</"Control of Scoping">.

=back

=item C<< DefConstructorI($cs,$paramlist,$xmlpattern | $code,%options); >>

X<DefConstructorI>
Internal form of C<DefConstructor> where the control sequence and parameter list
have already been separated; useful for definitions from within code.

=item C<< DefMath($prototype,$tex,%options); >>

X<DefMath>
A common shorthand constructor; it defines a control sequence that creates a mathematical object,
such as a symbol, function or operator application.  
The options given can effectively create semantic macros that contribute to the eventual
parsing of mathematical content.
In particular, it generates an XMDual using the replacement $tex for the presentation.
The content information is drawn from the name and options

These C<DefConstructor> options also apply:

  reversion, alias, beforeDigest, afterDigest,
  beforeConstruct, afterConstruct and scope.

Additionally, it accepts

=over 4

=item  style=>astyle

adds a style attribute to the object.

=item  name=>aname

gives a name attribute for the object

=item  omcd=>cdname

gives the OpenMath content dictionary that name is from.

=item  role=>grammatical_role

adds a grammatical role attribute to the object; this specifies
the grammatical role that the object plays in surrounding expressions.
This direly needs documentation!

=item  font=>{fontspec}

Specifies the font to use (see L</"MergeFont(%style);">).

=item mathstyle=(display|text|inline)

Controls whether the this object will be presented in a specific
mathstyle, or according to the current setting of C<mathstyle>.

=item scriptpos=>(mid|post)

Controls the positioning of any sub and super-scripts relative to this object;
whether they be stacked over or under it, or whether they will appear in the usual position.
TeX.pool defines a function C<doScriptpos()> which is useful for operators
like C<\sum> in that it sets to C<mid> position when in displaystyle, otherwise C<post>.

=item stretchy=>boolean

Whether or not the object is stretchy when displayed.

=item operator_role=>grammatical_role

=item operator_scriptpos=>boolean

=item operator_stretchy=>boolean

These three are similar to C<role>, C<scriptpos> and C<stretchy>, but are used in
unusual cases.  These apply to the given attributes to the operator token
in the content branch.

=item  nogroup=>boolean

Normally, these commands are digested with an implicit grouping around them,
localizing changes to fonts, etc; C<< noggroup=>1 >> inhibits this.

Example:

  DefMath('\infty',"\x{221E}",
     role=>'ID', meaning=>'infinity');

=back

=item C<< DefMathI($cs,$paramlist,$tex,%options); >>

X<DefMathI>
Internal form of C<DefMath> where the control sequence and parameter list
have already been separated; useful for definitions from within code.

=item C<< DefEnvironment($prototype,$replacement,%options); >>

X<DefEnvironment>
Defines an Environment that generates a specific XML fragment.  C<$replacement> is
of the same form as for DefConstructor, but will generally include reference to
the C<#body> property. Upon encountering a C<\begin{env}>:  the mode is switched, if needed,
else a new group is opened; then the environment name is noted; the beforeDigest daemon is run.
Then the Whatsit representing the begin command (but ultimately the whole environment) is created
and the afterDigestBegin daemon is run.
Next, the body will be digested and collected until the balancing C<\end{env}>.   Then,
any afterDigest daemon is run, the environment is ended, finally the mode is ended or
the group is closed.  The body and C<\end{env}> whatsit are added to the C<\begin{env}>'s whatsit
as body and trailer, respectively.


It shares options with C<DefConstructor>:

 mode, requireMath, forbidMath, properties, nargs,
 font, beforeDigest, afterDigest, beforeConstruct, 
 afterConstruct and scope.

Additionally, C<afterDigestBegin> is effectively an C<afterDigest>
for the C<\begin{env}> control sequence.

Example:

  DefConstructor('\emph{}',
     "<ltx:emph>#1</ltx:emph", mode=>'text');

DefEnvironment gives slightly different interpretation to some of
C<DefConstructor>'s options and adds some new ones:

=over 4

=item  beforeDigest=>CODE($stomach)

This option is the same as for C<DefConstructor>,
but it applies to the C<\begin{environment}> control sequence.

=item  afterDigestBegin=>CODE($stomach,$whatsit)

This option is the same as C<DefConstructor>'s C<afterDigest>
but it applies to the C<\begin{environment}> control sequence.
The Whatsit is the one for the begining control sequence,
but represents the environment as a whole.
Note that although the arguments and properties are present in
the Whatsit, the body of the environment is I<not>.

=item  beforeDigestEnd=>CODE($stomach)

This option is the same as C<DefConstructor>'s C<beforeDigest>
but it applies to the C<\end{environment}> control sequence.

=item  afterDigest=>CODE($stomach,$whatsit)

This option is the same as C<DefConstructor>'s C<afterDigest>
but it applies to the C<\end{environment}> control sequence.
Note, however that the Whatsit is only for the ending control sequence,
I<not> the Whatsit for the environment as a whole.

=item  afterDigestBody=>CODE($stomach,$whatsit)

This option supplies a Daemon to be executed during digestion
after the ending control sequence has been digested (and all the 4
other digestion Daemons have executed) and after
the body of the environment has been obtained.
The Whatsit is the (usefull) one representing the whole
environment, and it now does have the body and trailer available,
stored as a properties.

=back

=item C<< DefEnvironmentI($name,$paramlist,$replacement,%options); >>

X<DefEnvironmentI>
Internal form of C<DefEnvironment> where the control sequence and parameter list
have already been separated; useful for definitions from within code.

=back

=head2 Inputing Content and Definitions

=over 4

=item C<< FindFile($name,%options); >>

X<FindFile>
Find an appropriate file with the given C<$name> in the current directories
in C<SEARCHPATHS>.
If a file ending with C<.ltxml> is found, it will be preferred.

Note that if the C<$name> starts with a recognized I<protocol>
(currently one of C<(literal|http|https|ftp)>) followed by a colon,
the name is returned, as is, and no search for files is carried out.

The options are:

=over 4

=item type=>type

specifies the file type.  If not set, it will search for
both C<$name.tex> and C<$name>.

=item noltxml=>1

inhibits searching for a LaTeXML binding to use instead
of the file itself (C<$name.$type.ltxml>)

=item notex=>1

inhibits searching for raw tex version of the file.
That is, it will I<only> search for the LaTeXML binding.

=back

=item C<< InputContent($request,%options); >>

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

=item noerror=>boolean

Inhibits signalling an error if no appropriate file is found.

=back

=item C<< Input($request); >>

X<Input>
C<Input> is analogous to LaTeX's C<\input>, and is used in
cases where it isn't completely clear whether content or definitions
is expected.  Once a file is found, the approach specified
by L<InputContent> or L<InputDefinitions> is used, depending on
which type of file is found.

=item C<< InputDefinitions($request,%options); >>

X<InputDefinitions>
C<InputDefinitions> is used for loading I<definitions>,
ie. various macros, settings, etc, rather than document content;
it can be used to load LaTeXML's binding files, or for
reading in raw TeX definitions or style files.
It reads and processes the material completely before
returning, even in the case of TeX definitions.
This procedure optionally supports the conventions used
for standard LaTeX packages and classes (see L<RequirePackage> and L<LoadClass>).

Options for C<InputDefinitions> are:

=over

=item type=>$type

the file type to search for.

=item noltxml=>boolean

inhibits searching for a LaTeXML binding; only raw TeX files will be sought and loaded.

=item notex=>boolean

inhibits searching for raw TeX files, only a LaTeXML binding will be sought and loaded.

=item noerror=>boolean

inhibits reporting an error if no appropriate file is found.


=back

The following options are primarily useful when C<InputDefinitions>
is supporting standard LaTeX package and class loading.

=over

=item withoptions=boolean

indicates whether to pass in any options from the calling class or package.

=item handleoptions=boolean

indicates whether options processing should be handled.

=item options=>[...]

specifies a list of options to be passed
(possibly in addition to any provided by the calling class or package).

=item after

provides code or tokens to be processed by a C<$name.$type-hook> macro.

=item as_class

fishy option that indicates that this definitions file should
be treated as if it were defining a class; typically shows up
in latex compatibility mode, or AMSTeX.

=back

=back

=head2 Class and Packages

=over

=item C<< RequirePackage($package,%options); >>

X<RequirePackage>
Finds and loads a package implementation (usually C<*.sty.ltxml>, unless C<raw> is specified)
for the required C<$package>.  It returns the pathname of the loaded package.
The options are:

=over

=item type=>type

specifies the file type (default C<sty>.

=item options=>[...]

specifies a list of package options.

=item noltxml=>1

inhibits searching for the LaTeXML binding for the file (ie. C<$name.$type.ltxml>

=item notex=>1

inhibits searching for raw tex version of the file.
That is, it will I<only> search for the LaTeXML binding.

=back

=item C<< LoadClass($class,%options); >>

X<LoadClass>
Finds and loads a class definition (usually C<*.cls.ltxml>).
It returns the pathname of the loaded class.
The only option is

=over

=item options=>[...] 

specifies a list of class options.

=back

=item C<< LoadPool($pool,%options); >>

X<LoadPool>
Loads a I<pool> file, one of the top-level definition files,
such as TeX, LaTeX or AMSTeX.
It returns the pathname of the loaded file.

=item C<< DeclareOption($option,$code); >>

X<DeclareOption>
Declares an option for the current package or class.
The C<$code> can be a string or Tokens (which will be macro expanded),
or can be a code reference which is treated as a primitive.

If a package or class wants to accomodate options, it should start
with one or more C<DeclareOptions>, followed by C<ProcessOptions()>.

=item C<< PassOptions($name,$ext,@options); >>

X<PassOptions>
Causes the given C<@options> (strings) to be passed to the package
(if C<$ext> is C<sty>) or class (if C<$ext> is C<cls>)
named by C<$name>.

=item C<< ProcessOptions(); >>

X<ProcessOptions>
Processes the options that have been passed to the current package
or class in a fashion similar to LaTeX.  If the keyword
C<< inorder=>1 >> is given, the options are processed in the
order they were used, like C<ProcessOptions*>.

=item C<< ExecuteOptions(@options); >>

X<ExecuteOptions>
Process the options given explicitly in C<@options>.

=item C<< AtBeginDocument(@stuff); >>

X<AtBeginDocument>
Arranges for C<@stuff> to be carried out after the preamble, at the beginning of the document.
C<@stuff> should typically be macro-level stuff, but carried out for side effect;
it should be tokens, tokens lists, strings (which will be tokenized),
or a sub (which presumably contains code as would be in a package file, such as C<DefMacro>
or similar.

This operation is useful for style files loaded with C<--preload> or document specific
customization files (ie. ending with C<.latexml>); normally the contents would be executed
before LaTeX and other style files are loaded and thus can be overridden by them.
By deferring the evaluation to begin-document time, these contents can override those style files. 
This is likely to only be meaningful for LaTeX documents.

=back

=head2 Counters and IDs

=over 4

=item C<< NewCounter($ctr,$within,%options); >>

X<NewCounter>
Defines a new counter, like LaTeX's \newcounter, but extended.
It defines a counter that can be used to generate reference numbers,
and defines \the$ctr, etc. It also defines an "uncounter" which
can be used to generate ID's (xml:id) for unnumbered objects.
C<$ctr> is the name of the counter.  If defined, C<$within> is the name
of another counter which, when incremented, will cause this counter
to be reset.
The options are

   idprefix  Specifies a prefix to be used to generate ID's
             when using this counter
   nested    Not sure that this is even sane.

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

=item C<< Tag($tag,%properties); >>

X<Tag>
Declares properties of elements with the name C<$tag>.
Note that C<Tag> can set or add properties to any element from any binding file,
unlike the properties set on control by  C<DefPrimtive>, C<DefConstructor>, etc..
And, since the properties are recorded in the current Model, they are not
subject to TeX grouping; once set, they remain in effect until changed
or the end of the document.

The C<$tag> can be specified in one of three forms:

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

=item autoOpen=>boolean

Specifies whether this $tag can be automatically opened
if needed to insert an element that can only
be contained by $tag.
This property can help match the more  SGML-like LaTeX to XML.

=item  autoClose=>boolean

Specifies whether this $tag can be automatically closed
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

=item C<< afterOpen=>CODE($document,$box) >>

Provides CODE to be run whenever a node with this $tag
is opened.  It is called with the document being constructed,
and the initiating digested object as arguments.
It is called after the node has been created, and after
any initial attributes due to the constructor (passed to openElement)
are added.

C<afterOpen:early> or C<afterOpen:late> can be used in
place of C<afterOpen>; these will be run as a group
bfore, or after (respectively) the unmodified blocks.

=item C<< afterClose=>CODE($document,$box) >>

Provides CODE to be run whenever a node with this $tag
is closed.  It is called with the document being constructed,
and the initiating digested object as arguments.

C<afterClose:early> or C<afterClose:late> can be used in
place of C<afterClose>; these will be run as a group
bfore, or after (respectively) the unmodified blocks.

=back

=back

=item C<< RelaxNGSchema($schemaname); >>

X<RelaxNGSchema>
Specifies the schema to use for determining document model.
You can leave off the extension; it will look for C<.rng>,
and maybe eventually, C<.rnc> once that is implemented.

=item C<< RegisterNamespace($prefix,$URL); >>

X<RegisterNamespace>
Declares the C<$prefix> to be associated with the given C<$URL>.
These prefixes may be used in ltxml files, particularly for
constructors, xpath expressions, etc.  They are not necessarily
the same as the prefixes that will be used in the generated document
Use the prefix C<#default> for the default, non-prefixed, namespace.
(See RegisterDocumentNamespace, as well as DocType or RelaxNGSchema).

=item C<< RegisterDocumentNamespace($prefix,$URL); >>

X<RegisterDocumentNamespace>
Declares the C<$prefix> to be associated with the given C<$URL>
used within the generated XML. They are not necessarily
the same as the prefixes used in code (RegisterNamespace).
This function is less rarely needed, as the namespace declarations
are generally obtained from the DTD or Schema themselves
Use the prefix C<#default> for the default, non-prefixed, namespace.
(See DocType or RelaxNGSchema).

=item C<< DocType($rootelement,$publicid,$systemid,%namespaces); >>

X<DocType>
Declares the expected rootelement, the public and system ID's of the document type
to be used in the final document.  The hash C<%namespaces> specifies
the namespaces prefixes that are expected to be found in the DTD, along with
each associated namespace URI.  Use the prefix C<#default> for the default namespace
(ie. the namespace of non-prefixed elements in the DTD).

The prefixes defined for the DTD may be different from the prefixes used in
implementation CODE (eg. in ltxml files; see RegisterNamespace).
The generated document will use the namespaces and prefixes defined for the DTD.

=back

A related capability is adding commands to be executed at the beginning
and end of the document

=over

=item C<< AtBeginDocument($tokens,...) >>

adds the C<$tokens> to a list to be processed just after C<\\begin{document}>.
These tokens can be used for side effect, or any content they generate will appear as the
first children of the document (but probably after titles and frontmatter).

=item C<< AtEndDocument($tokens,...) >>

adds the C<$tokens> to the list to be processed just before C<\\end{document}>.
These tokens can be used for side effect, or any content they generate will appear as the
last children of the document.

=back

=head2 Document Rewriting

During document construction, as each node gets closed, the text content gets simplfied.
We'll call it I<applying ligatures>, for lack of a better name.

=over

=item C<< DefLigature($regexp,%options); >>

X<DefLigature>
Apply the regular expression (given as a string: "/fa/fa/" since it will
be converted internally to a true regexp), to the text content.
The only option is C<fontTest=CODE($font)>; if given, then the substitution
is applied only when C<fontTest> returns true.

Predefined Ligatures combine sequences of "." or single-quotes into appropriate
Unicode characters.

=item C<< DefMathLigature(CODE($document,@nodes)); >>

X<DefMathLigature>
CODE is called on each sequence of math nodes at a given level.  If they should
be replaced, return a list of C<($n,$string,%attributes)> to replace
the text content of the first node with C<$string> content and add the given attributes.
The next C<$n-1> nodes are removed.  If no replacement is called for, CODE
should return undef.

Predefined Math Ligatures combine letter or digit Math Tokens (XMTok) into multicharacter
symbols or numbers, depending on the font (non math italic).

=back

After document construction, various rewriting and augmenting of the
document can take place.

=over

=item C<< DefRewrite(%specification); >>

=item C<< DefMathRewrite(%specification); >>

X<DefRewrite>X<DefMathRewrite>
These two declarations define document rewrite rules that are applied to the
document tree after it has been constructed, but before math parsing, or
any other postprocessing, is done.  The C<%specification> consists of a 
seqeuence of key/value pairs with the initial specs successively narrowing the
selection of document nodes, and the remaining specs indicating how
to modify or replace the selected nodes.

The following select portions of the document:

=over

=item label =>$label

Selects the part of the document with label=$label

=item scope =>$scope

The $scope could be "label:foo" or "section:1.2.3" or something
similar. These select a subtree labelled 'foo', or
a section with reference number "1.2.3"

=item xpath =>$xpath

Select those nodes matching an explicit xpath expression.

=item match =>$TeX

Selects nodes that look like what the processing of $TeX would produce.

=item regexp=>$regexp

Selects text nodes that match the regular expression.

=back

The following act upon the selected node:

=over

=item attributes => $hash

Adds the attributes given in the hash reference to the node.

=item replace =>$replacement

Interprets the $replacement as TeX code to generate nodes that will
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

=item C<< DefParameterType($type,CODE($gullet,@values),%options); >>

X<DefParameterType>
Defines a new Parameter type, C<$type>, with CODE for its reader.

Options are:

=over

=item reversion=>CODE($arg,@values);

This CODE is responsible for converting a previously parsed argument back
into a sequence of Token's.

=item optional=>boolean

whether it is an error if no matching input is found.

=item novalue=>boolean

whether the value returned should contribute to argument lists, or
simply be passed over.

=item semiverbatim=>boolean

whether the catcode table should be modified before reading tokens.

=back

=item C<< DefColumnType($proto,$expansion); >>

X<DefColumnType>
Defines a new column type for tabular and arrays.
C<$proto> is the prototype for the pattern, analogous to the pattern
used for other definitions, except that macro being defined is a single character.
The C<$expansion> is a string specifying what it should expand into,
typically more verbose column specification.

=item C<< DefKeyVal($keyset,$key,$type,$default); >>

X<DefKeyVal>
Defines a keyword C<$key> used in keyval arguments for the set C<$keyset>.
If type is given, it defines the type of value that must be supplied,
such as C<'Dimension'>.  If C<$default> is given, that value will be used
when C<$key> is used without an equals and explicit value.

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

=back

=head2 Font Encoding

=over

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

=item C<< MergeFont(%style); >>

X<MergeFont>
Set the current font by merging the font style attributes with the current font.
The attributes and likely values (the values aren't required to be in this set):

 family : serif, sansserif, typewriter, caligraphic,
          fraktur, script
 series : medium, bold
 shape  : upright, italic, slanted, smallcaps
 size   : tiny, footnote, small, normal, large,
          Large, LARGE, huge, Huge
 color  : any named color, default is black

Some families will only be used in math.
This function returns nothing so it can be easily used in beforeDigest, afterDigest.

=item C<< @tokens = roman($number); >>

X<roman>
Formats the C<$number> in (lowercase) roman numerals, returning a list of the tokens.

=item C<< @tokens = Roman($number); >>

X<Roman>
Formats the C<$number> in (uppercase) roman numerals, returning a list of the tokens.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
