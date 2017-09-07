# /=====================================================================\ #
# |  LaTeXML::Core::KeyVal                                              | #
# | Key-Value Defintions in LaTeXML                                     | #
# |=====================================================================| #
# | Thanks to Tom Wiesing <tom.wiesing@gmail.com>                       | #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::KeyVal;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Core::Token;
use LaTeXML::Core::Tokens;
use base qw(LaTeXML::Common::Object);

our @EXPORT = (
  qw(&DefKeyVal &DisableKeyVal &HasKeyVal)
);

#======================================================================
# Exposed Methods
#======================================================================

# Defines a new key-value pair and returns it's header
sub DefKeyVal {
  my ($keyset, $key, $type, $default, %options) = @_;

  # extract the prefix
  my $prefix = $options{prefix};
  delete $options{prefix};

  # create a new keyval object
  my $keyval = LaTeXML::Core::KeyVal->new($prefix, $keyset, $key);
  $keyval->define($type, $default, %options);

  # return the keyval object (should we need it)
  return $keyval; }

# check if a key-value pair is defined
sub HasKeyVal {
  my ($prefix, $keyset, $key) = @_;

  my $keyval = LaTeXML::Core::KeyVal->new($prefix, $keyset, $key);
  return $keyval->isDefined(1); }

# disable a given key-val
sub DisableKeyVal {
  my ($prefix, $keyset, $key) = @_;

  my $keyval = LaTeXML::Core::KeyVal->new($prefix, $keyset, $key);
  return $keyval->disable; }

#======================================================================
# Creating KeyVal objects
#======================================================================

# create new class instance
sub new {
  my ($class, $prefix, $keyset, $key) = @_;

  return bless {
    prefix => defined($prefix) ? ToString($prefix) : 'KV',
    keyset => ToString($keyset), key => ToString($key)
    }, $class; }

#======================================================================
# Accessors
#======================================================================

sub getPrefix {
  my ($self) = @_;
  return $$self{prefix}; }

sub getKeySet {
  my ($self) = @_;
  return $$self{keyset}; }

sub getKey {
  my ($self) = @_;
  return $$self{key}; }

sub getFullPrefix {
  my ($self) = @_;

  # if we already have this cached, we can return
  return $$self{fullprefix} if defined($$self{fullprefix});

  # else, define the full prefix
  $$self{fullprefix} = $self->getPrefix . '@' . $self->getKeySet . '@';

  # and return it
  return $$self{fullprefix}; }

sub getHeader {
  my ($self) = @_;

  # if we already have this cached, we can return
  return $$self{header} if defined($$self{header});

  # else, define the header
  $$self{header} = $self->getPrefix . '@' . $self->getKeySet . '@' . $self->getKey;

  # and return it
  return $$self{header}; }

#======================================================================
# Property access
#======================================================================

# set a key-value property for this key
sub setProp {
  my ($self, $prop, $value, $scope) = @_;

  $STATE->assignValue('KEYVAL@' . $prop . '@' . $self->getHeader, $value, $scope);

  return; }

# get a key-value property for this key
sub getProp {
  my ($self, $prop) = @_;

  return $STATE->lookupValue('KEYVAL@' . $prop . '@' . $self->getHeader); }

sub getType {
  my ($self) = @_;
  return $$self{type} = $self->getProp('type'); }

sub setType {
  my ($self, $type) = @_;

  my $prefix = $self->getPrefix;
  my $keyset = $self->getKeySet;
  my $key    = $self->getKey;

  # parse the parameters
  my $paramlist = LaTeXML::Package::parseParameters($type || "{}", "KeyVal $key in set $keyset with prefix $prefix");
  if (scalar(@$paramlist) != 1) {
    Warn('unexpected', 'keyval', $key,
"Too many parameters in keyval $key (in set $keyset with prefix $prefix); taking only first", $paramlist); }
  my $parameter = $$paramlist[0];

  # store the property
  $self->setProp('type', $parameter);
  return; }

sub getDefault {
  my ($self) = @_;
  return $self->getProp('default'); }

sub setDefault {
  my ($self, $default, $setMacros) = @_;
  my @tdefault = LaTeXML::Package::Tokenize($default);

  $self->setProp('default', Tokens(@tdefault));

  if ($setMacros) {
    my $header = $self->getHeader;
    LaTeXML::Package::DefMacroI('\\' . $header . '@default', undef,
      Tokens(T_CS('\\' . $header), T_BEGIN, @tdefault, T_END));
    return; } }

#======================================================================
# Key Definition
#======================================================================

sub isDefined {
  my ($self, $checkMacro) = @_;

  # start by checking if the defined key exists
  return 1 if (defined $self->getProp('exists'));

  # check if the macro is given, if it is defined
  return (defined $STATE->lookupMeaning(T_CS('\\' . $self->getHeader))) if $checkMacro;

  return 0; }

# (re-)define this key
sub define {
  my ($self, $type, $default, %options) = @_;

  # define that the key exists and is not disabled
  $self->setProp('exists',   1);
  $self->setProp('disabled', 0);

  # set the type
  $self->setType($type);

  # set the default
  $self->setDefault($default, 1) if defined($default);

  # figure out the kind of key-val parameter we are defining
  my $kind = $options{kind} || 'ordinary';
  $self->setProp('kind', $kind);

  if ($kind eq 'ordinary') {
    $self->defineOrdinary($options{code}); }

  elsif ($kind eq 'command') {
    $self->defineCommand($options{code}, $options{macroprefix}); }

  elsif ($kind eq 'choice') {
    $self->defineChoice($options{code}, $options{mismatch},
      $options{choices}, ($options{normalize} || 0), $options{bin}); }

  elsif ($kind eq 'boolean') {
    $self->defineBoolean($options{code}, $options{mismatch}, $options{macroprefix}); }

  else { Warn('unknown', undef, "Unknown KeyVals kind $kind, should be one of 'ordinary', 'command', 'choice', 'boolean'. "); }

  return; }

sub defineOrdinary {
  my ($self, $code) = @_;

  LaTeXML::Package::DefMacroI('\\' . $self->getHeader,
    LaTeXML::Core::Parameters->new(LaTeXML::Core::Parameter->new('Plain', '{}')),
    defined($code) ? $code : '');

  return; }

sub defineCommand {
  my ($self, $code, $macroprefix) = @_;

  # store the header we have to define
  my $macroHeader = $macroprefix || ("cmd" . $self->getFullPrefix);
  $self->setProp('macroHeader', $macroHeader);

  # prefix the original macro with the code
  $self->defineOrdinary(sub {
      my ($gullet, $value) = @_;
      my $orig = '\\ltxml@orig@' . $self->getHeader;

      LaTeXML::Package::DefMacroI($orig,
        LaTeXML::Core::Parameters->new(LaTeXML::Core::Parameter->new('Plain', '{}')),
        $code);

      Tokens(
        T_CS("\\def"), T_CS('\\' . $macroHeader . $self->getKey), T_BEGIN, $value, T_END,
        T_CS($orig), T_BEGIN, T_PARAM, $value, T_END
      );
  });

  return; }

sub defineChoice {
  my ($self, $code, $mismatch, $choices, $normalize, $bin) = @_;

  # store the choices
  $self->setProp('choices', join(',', $choices));

  # we might need to 'normalize', i.e. turn labels into lowercase
  my $norm;
  if   ($normalize) { $norm = sub { lc $_[0]; }; }
  else              { $norm = sub { $_[0]; }; }
  $self->setProp('normalize', $normalize ? 0 : 1);

  # Unpack macros (if available)
  my ($varmacro, $idxmacro) = defined($bin) ? $bin->unlist : (undef, undef);
  $self->setProp('varmacro', $varmacro);
  $self->setProp('idxmacro', $idxmacro);

  # define advanced macro code
  $self->defineOrdinary(sub {
      my ($gullet, $value) = @_;

      # Store the normalized value (if applicable)
      my $nvalue = &$norm(ToString($value));
      LaTeXML::Package::DefMacro($varmacro, sub { Explode($nvalue); }) if defined($varmacro);

      # iterate over the possible choices and store them
      my $ochoice;
      my $index = 0;
      my $valid = 0;

      foreach my $choice (@{$choices}) {
        if (&$norm(ToString($choice)) eq $nvalue) {
          $ochoice = $choice;
          $valid   = 1;
          LaTeXML::Package::DefMacro($idxmacro, Explode(ToString($index))) if defined($idxmacro); }
        $index += 1; }

      # find a name for the original macro to store in
      my @tokens = ();
      my $orig   = '\\ltxml@orig@' . $self->getHeader;

      # if we have chosen a valid index, run $code
      if ($valid) {
        if (defined($code)) {
          LaTeXML::Package::DefMacroI($orig,
            LaTeXML::Core::Parameters->new(LaTeXML::Core::Parameter->new('Plain', '{}')),
            $code);
          push(@tokens, T_CS($orig), T_BEGIN, $value, T_END); } }

      # else run $mismatch
      elsif (defined($mismatch)) {
        LaTeXML::Package::DefMacroI($orig,
          LaTeXML::Core::Parameters->new(LaTeXML::Core::Parameter->new('Plain', '{}')),
          $mismatch);
        push(@tokens, T_CS($orig), T_BEGIN, $value, T_END); }

      @tokens; });

  return; }

sub defineBoolean {
  my ($self, $code, $mismatch, $macroprefix) = @_;

  # find the header and define a new conditional
  my $macroHeader = ($macroprefix || $self->getFullPrefix) . $self->getKey;
  LaTeXML::Package::DefConditional(T_CS("\\if$macroHeader"));    # We might need to $scope here
  $self->setProp('macroHeader', $macroHeader);

  # and define a choice key
  $self->defineChoice(sub {
      my ($gullet, $value) = @_;

      # set the value to true (if needed)
      my @tokens = ();
      push(@tokens, T_CS('\\' . $macroHeader . (((lc ToString($value)) eq 'true') ? 'true' : 'false')));

      # Store and invoke the original macro if needed
      if ($code) {
        my $orig = '\\ltxml@@rig@' . $self->getHeader;
        LaTeXML::Package::DefMacroI($orig,
          LaTeXML::Core::Parameters->new(LaTeXML::Core::Parameter->new('Plain', '{}')),
          $code);
        push(@tokens, T_CS($orig), T_BEGIN, $value, T_END); }
      @tokens; },
    $mismatch, [("true", "false")], 1);

  return; }

sub isDisabled {
  my ($self) = @_;
  return $self->getProp('disabled', 1); }

sub disable {
  my ($self) = @_;

  # disable the key
  $self->defineOrdinary(sub {
      LaTeXML::Package::Tokenize("\\PackageWarning{keyval}{`" . $self->getKey . "' has been disabled. }");
  });

  $self->setProp('disabled', 1);

  return; }

#======================================================================
# Value Related Reversion
#======================================================================

sub setKeysExpansion {
  my ($self, $value, $useDefault, $checkExistence, $checkDisabled, $setInternals) = @_;

  # if we do not exist, return undef
  if ($checkExistence && !($self->isDefined(1))) {
    Error(
      'undefined', 'Encountered unknown KeyVals key',
"'" . $self->getKey . "' with prefix '" . $self->getPrefix . "' not defined in '" . join(",", $self->getKeySet) . "'");
    return; }

  # if we are disabled, return an empty tokens
  if ($checkDisabled && $self->isDisabled) {
    Warn(
      'undefined', "`" . $self->getKey . "' has been disabled. ");
    return Tokens(); }

  # definition of 'xkeyval' internals (if applicable)
  my @tokens = $setInternals ? (
    T_CS('\def'), T_CS('\XKV@prefix'), T_BEGIN, Explode($self->getPrefix . '@'), T_END,
    T_CS('\def'), T_CS('\XKV@tfam'),   T_BEGIN, Explode($self->getKeySet),     T_END,
    T_CS('\def'), T_CS('\XKV@header'), T_BEGIN, Explode($self->getFullPrefix), T_END,
    T_CS('\def'), T_CS('\XKV@tkey'),   T_BEGIN, Explode($self->getKey),        T_END
  ) : ();

  # we have a value given, call the appropriate macro with it
  unless ($useDefault) { push(@tokens, T_CS('\\' . $self->getHeader), T_BEGIN, Revert($value), T_END); }

  # if it was not given explicitly, call the default macro
  else { push(@tokens, T_CS('\\' . $self->getHeader . '@default')); }

  # and reset the internals (if applicable)
  push(@tokens,
    T_CS('\def'), T_CS('\XKV@prefix'), T_BEGIN, T_END,
    T_CS('\def'), T_CS('\XKV@tfam'),   T_BEGIN, T_END,
    T_CS('\def'), T_CS('\XKV@header'), T_BEGIN, T_END,
    T_CS('\def'), T_CS('\XKV@tkey'),   T_BEGIN, T_END) if $setInternals;

  return Tokens(@tokens); }

sub toString {
  my ($self) = @_;
  return $self->getHeader; }

#======================================================================
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Core::KeyVal> - Key-Value Defintions in LaTeXML

=head1 DESCRIPTION

Provides an interface to define and access KeyVal definition.  
Used in conjunction with C<LaTeXML::Core::KeyVals> to fully implement KeyVal
pairs. It extends L<LaTeXML::Common::Object>.

=head2 Exposed Methods

=over 4

=item C<DefKeyVal(I<keyset>, I<key>, I<type>, I<default>, I<%options>); >

Defines a new KeyVal Parameter in the given I<keyset>, I<key> and with optional
prefix I<option{prefix}>. For descriptions of further parameters, see I<LaTeXML::Core::KeyVal::define>. 

=item C<HasKeyVal(I<prefix>, I<keyset>, I<key>); >

Checks if the given KeyVal pair exists. 

=item C<DisableKeyVal(I<prefix>, I<keyset>, I<key>); >

Disables the given KeyVal so that it can not be used. 

=back

=head2 Constructors

=over 4

=item C<<LaTeXML::Core::KeyVal->new(I<preset>, I<keyset>, I<key>); >>

Creates a new I<KeyVal> object. This serves as a simple reference to the given 
KeyVal object, regardless of its existence or not. 

=back

=head2 KeyVal Accessors

=over 4

=item C<< $prefix = $keyval->getPrefix; >>

Gets the prefix of this KeyVal object. 

=item C<< $keyset = $keyval->getKeySet; >>

Gets the keyset of this KeyVal object. 

=item C<< $key = $keyval->getKey; >>

Gets the key of this KeyVal object. 

=item C<< $prefix = $keyval->getFullPrefix; >>

Gets the full prefix of this keyval object, to be used when composing macros. 

=item C<< $prefix = $keyval->getHeader; >>

Gets the header of this keyval object, to be used when composing macros. 

=back

=head2 Keyval Property Getters

=over 4

=item C<< $value = $keyval->getProp($prop); >>

Gets the value of a given property of this KeyVal. Intended for internal use
only. 

=item C<< $value = $keyval->setProp($prop, $value, $scope); >>

Sets the value of the given property with the given value and scope. Intended
for internal use only. 

=item C<< $type = $keyval->getType(); >>

Gets the type of this KeyVal object, as found in $STATE. 

=item C<< $keyval->setType($type); >>

Sets the type of this KeyVal object, as found in $STATE. 

=item C<< $default = $keyval->getDefault(); >>

Gets the default of this KeyVal object, as found in $STATE. 

=item C<< $keyval->setDefault($default, $setMacros); >>

Sets the default of this KeyVal object, and optionally sets the macros as well. 

=back

=head2 KeyVal Key Definition

=over 4

=item C<< $defined = $keyval->isDefined($checkMacros); >>

Checks if this KeyVal item is actually defined. If checkMacros is set to true, 
also check if macros are defined. 

=item C<< $keyval->define($type, $default, %options); >>

(Re-)defines this Key of kind 'kind'. 
Defines a keyword I<key> used in keyval arguments for the set I<keyset> and, 
and if the option I<code> is given, defines appropriate macros 
when used with the I<keyval> package (or extensions thereof). 

If I<type> is given, it defines the type of value that must be supplied,
such as C<'Dimension'>.  If I<default> is given, that value will be used
when I<key> is used without an equals and explicit value in a keyvals argument.

A I<scope> option can be given, which can be used to defined the key-value pair
globally instead of in the current scope. 

Several more I<option>s can be given. These implement the behaviour of the
xkeyval package. 

The I<prefix> parameter can be used to configure a custom prefix for 
the macros to be defined. The I<kind> parameter can be used to configure special types of xkeyval 
pairs. 

The 'ordinary' kind behaves like a normal keyval parameter. 

The 'command' kind defines a command key, that when run stores the value of the
key in a special macro, which can be further specefied by the I<macroprefix> 
option. 

The 'choice' kind defines a choice key, which takes additional options 
I<choices> (to specify which choices are valid values), I<mismatch> (to be run
if an invalid choice is made) and I<bin> (see xkeyval documentation for 
details). 

The 'boolean' kind defines a special choice key that takes possible values true and
false, and defines a new Conditional according to the assumed value. The name of
this conditional can be specified with the I<macroprefix> option. 

The kind parameter only takes effect when I<code> is given, otherwise only 
meta-data is stored. 

=item C<< $keyval->defineOrdinary($code); >>

Helper function to define $STATE neccesary for an ordinary key. 

=item C<< $keyval->defineCommand($code, $macroprefix); >>

Helper function to define $STATE neccesary for a command key. 

=item C<< $keyval->defineChoice($code, $mismatch, $choices, $normalize, $bin); >>

Helper function to define $STATE neccesary for an choice key. 

=item C<< $keyval->defineBoolean($code, $mismatch, $macroprefix); >>

Helper function to define $STATE neccesary for a boolean key. 

=item C<< disabled = $keyval->isDisabled(); >>

Checks if this keyval property is disabled. 

=item C<< $keyval->disable(); >>

Disables this KeyVal object in $STATE. 

=back

=head2 Value Related

=over 4

=item C<< $expansion = $keyval->setKeys($value, $useDefault, $checkExistence, $checkDisabled, $setInternals); >>

Expands this KeyVal into a Tokens() to be used with \setkeys. 
I<value> contains the value to be used in the expansion, I<useDefault> indicates
if the value argument should be ignored and the default should be used instead. 
If I<checkExistence> is set to 1 and the macro does not exist, undef is returned. 
If I<checkDisabled> is set to 1 and the macro is disabled, an empty Tokens() is
returns. 
If I<$setInternals> is set, sets XKeyVal internal macros. 

=item C<< $reversion = $keyval->digest($stomach, $value); >>

Digests this KeyVal with the given stomach and value. 

=item C<< $reversion = $keyval->revert($value, $useDefault, $compact, $isFirst, $punct, $assign); >>

Reverts this KeyVal with a given I<value> (or the default if I<IsDefault> is set)
and punctuation and assignment tokens. 
If I<compact> is given, spaces will be omitted when possible. 
The I<isDefault> parameter indicates if appropriate seperation tokens should be
inserted. 

=item C<< $str = $keyval->toString(); >>

Turns this KeyVal object into a string. 

=back


=head1 AUTHOR

Tom Wiesing <tom.wiesing@gmail.com>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
