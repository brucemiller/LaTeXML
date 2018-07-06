# /=====================================================================\ #
# |  LaTeXML::Core::KeyVals                                             | #
# | Support for key-value pairs for LaTeXML                             | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::KeyVals;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Core::Token;
use LaTeXML::Core::Tokens;
use base qw(LaTeXML::Common::Object);

our @EXPORT = (
  qw(&GetKeyVal &GetKeyVals)
);

#======================================================================
# Exposed Methods
#======================================================================

sub GetKeyVal {
  my ($keyval, $key) = @_;
  return (defined $keyval) && $keyval->getValue($key); }

sub GetKeyVals {
  my ($keyval) = @_;
  return (defined $keyval ? $keyval->getKeyVals : {}); }

#======================================================================
# The KeyVals constructor
#======================================================================
# This defines the KeyVals data object that can appear in the datastream
# along with tokens, boxes, etc.
# Thus it has to be digestible, however we may not want to digest it more
# than once.
#**********************************************************************

sub new {
  my ($class, $prefix, $keysets, %options) = @_;
  # parse all the arguments
  $prefix = defined($prefix) ? ToString($prefix) : 'KV';
  $keysets = [split(',', ToString(defined($keysets) ? $keysets : '_anonymous_'))] unless (ref($keysets) eq 'ARRAY');
  my $skip = $options{skip};
  $skip = [split(',', ToString(defined($options{skip}) ? $options{skip} : ''))] unless (ref($options{skip}) eq 'ARRAY');
  my $setAll       = $options{setAll}       ? 1 : 0;
  my $setInternals = $options{setInternals} ? 1 : 0;
  my $skipMissing  = $options{skipMissing};
  my $hookMissing  = $options{hookMissing};
  # hook missing, if defined, must be a token
  if (defined($hookMissing) && $hookMissing) {
    $hookMissing = ref($hookMissing) ? $hookMissing : T_CS(ToString($hookMissing)); }
  else { $hookMissing = undef; }
  # skip missing may be a token (=store all the missing macros there)
  unless (ref($skipMissing)) {
    # may be undef or 0 (= throw errors)
    unless (defined($skipMissing)) { $skipMissing = undef; }
    elsif  ($skipMissing eq '0')   { $skipMissing = undef; }
    # may be 1 (= ignore all missing keys)
    elsif ($skipMissing eq '1') { $skipMissing = 1; }
    # may be a string (= store all the missing keys there)
    else { $skipMissing = T_CS($skipMissing); } }
  my %hash = ();
  my $self = bless {
    # which KeyVals are we parsing and how do we behave?
    prefix      => $prefix,      keysets     => $keysets,
    skip        => $skip,        setAll      => $setAll, setInternals => $setInternals,
    skipMissing => $skipMissing, hookMissing => $hookMissing,

    # all the internal representations
    tuples => [], cachedPairs => [()], cachedHash => \%hash,

    # all the character tokens we used
    punct => $options{punct}, assign => $options{assign} },

    $class;
  return $self; }

#======================================================================
# Accessors for internal usage
#======================================================================

sub getPrefix {
  my ($self) = @_;
  return $$self{prefix}; }

sub getKeySets {
  my ($self) = @_;
  return @{ $$self{keysets} }; }

sub getSetAll {
  my ($self) = @_;
  return $$self{setAll}; }

sub getSetInternals {
  my ($self) = @_;
  return $$self{setInternals}; }

sub getTuples {
  my ($self) = @_;
  return @{ $$self{tuples}; } }

sub setTuples {
  my ($self, @tuples) = @_;
  $$self{tuples} = [@tuples];
  # we need to build all the caches
  $self->rebuild;
  return; }

sub getCachedPairs {
  my ($self) = @_;
  return @{ $$self{cachedPairs}; } }

sub getCachedHash {
  my ($self) = @_;
  return %{ $$self{cachedHash} }; }

sub getSkip {
  my ($self) = @_;
  return @{ $$self{skip} }; }

sub getSkipMissing {
  my ($self) = @_;
  return $$self{skipMissing}; }

sub getHookMissing {
  my ($self) = @_;
  return $$self{hookMissing}; }

#======================================================================
# Resolution to KeySets
#======================================================================

sub resolveKeyValFor {
  my ($self, $key) = @_;

  my $prefix  = $self->getPrefix;
  my @keysets = $self->getKeySets;
  my @sets    = ();

  # iterate over the keysets
  foreach my $keyset (@keysets) {
    my $bkeyval = LaTeXML::Core::KeyVal->new($prefix, $keyset, $key);
    push(@sets, $bkeyval) if $bkeyval->isDefined(1); }

  # throw an error, unless we record the missing macros
  if (scalar @sets == 0) {
    Error(
      'undefined', 'Encountered unknown KeyVals key',
      "'$key' with prefix '$prefix' not defined in '" . join(",", @keysets) . "', " .
        'were you perhaps using \setkeys instead of \setkeys*?') unless defined($self->getSkipMissing);
    return; }

  # return either the first or all of the elements
  return ($sets[0]) unless $self->getSetAll;
  return @sets; }

sub canResolveKeyValFor {
  my ($self, $key) = @_;
  my $prefix  = $self->getPrefix;
  my @keysets = $self->getKeySets;

  # iterate over the keysets
  foreach my $keyset (@keysets) {
    my $bkeyval = LaTeXML::Core::KeyVal->new($prefix, $keyset, $key);
    return 1 if $bkeyval->isDefined(1); }

  return 0; }

sub getPrimaryKeyValOf {
  my ($self, $key, @keysets) = @_;

  if (scalar @keysets == 0) {
    my $prefix   = $self->getPrefix;
    my @headsets = $self->getKeySets;
    return LaTeXML::Core::KeyVal->new($prefix, $headsets[0], $key); }
  else { return $keysets[0] } }

#======================================================================
# Changing contained values
#======================================================================

sub addValue {
  my ($self, $key, $value, $useDefault, $noRebuild) = @_;

  # figure out the keyset(s) for the key to be added
  my @keysets = $self->resolveKeyValFor($key);
  my $headset = $self->getPrimaryKeyValOf($key, @keysets);

  # and add the new tuple to the set of tuples
  push(@{ $$self{tuples} },
    [$key, ($useDefault ? $headset->getDefault : $value), $useDefault, [@keysets], $headset]);

  # we now need to rebuild, unless we were asked not to
  # TODO: Maybe only update the last element?
  $self->rebuild unless $noRebuild;

  return; }

sub setValue {
  my ($self, $key, $value, $useDefault) = @_;

  # delete the existing values by skipping key
  $self->rebuild($key);

  # if we have an array, we need to push all of them
  if (ref $value eq 'ARRAY') {
    foreach my $val (@{$value}) {
      $self->addValue($key, $val, $useDefault, 1); }

    $self->rebuild();
    return; }

  # if we have a single value, set it normally
  elsif (defined($value)) {
    $self->addValue($key, $value, $useDefault); }

  return; }

sub rebuild {
  my ($self, $skip) = @_;

  # the new data structures to create
  my @newtuples = ();
  my @pairs     = ();
  my %hash      = ();

  foreach my $tuple (@{ $$self{tuples} }) {
    # take all the elements we need from the stack
    my ($key, $value, $useDefault, $resolution, $keyval) = @$tuple;

    # if we want to skip some values, we need to store new tuples
    if (defined($skip)) {
      next if $key eq $skip;
      push(@newtuples, [$key, $value, $useDefault, $resolution, $keyval]) if defined($skip); }

    # push key / value into the pair
    push(@pairs, $key, $value);

    # if we do not have a value yet, set it
    if (!defined $hash{$key}) { $hash{$key} = $value; }

    # If we get a third value, push into an array
    # This is unlikely to be what the caller expects!! But what else?
    elsif (ref $hash{$key} eq 'ARRAY') { push(@{ $hash{$key} }, $value); }

    # If we get a second value, make an array
    else { $hash{$key} = [$hash{$key}, $value]; } }

  # store all of the values
  $$self{cachedPairs} = [@pairs];
  $$self{cachedHash}  = \%hash;
  $$self{tuples}      = [@newtuples] if defined($skip);

  return; }

#======================================================================
# parsing values from a gullet
#======================================================================

# A KeyVal argument MUST be delimited by either braces or brackets (if optional)
# This method reads the keyval pairs INCLUDING the delimiters, (rather than
# parsing after the fact), since some values may have special catcode needs.
##my $T_EQ    = T_OTHER('=');    # [CONSTANT]
##my $T_COMMA = T_OTHER(',');    # [CONSTANT]

sub readFrom {
  my ($self, $gullet, $until, %options) = @_;

  # if we want to force skipMissing keys, we set it up here
  my $silenceMissing = $options{silenceMissing} ? 1 : 0;

  my $skipMissing = $self->getSkipMissing;
  my $hookMissing = $self->getHookMissing;

  # if we want to silence all missing errors, store them in a hook
  if ($silenceMissing) {
    $$self{skipMissing} = 1;
    $$self{hookMissing} = undef; }

  # read the opening token and figure out where we are
  my $startloc = $gullet->getLocator;

  # set and read tokens
  my $open   = $gullet->readToken;
  $$self{assign} = T_OTHER('=');
  $$self{punct}  = T_OTHER(',');
  my ($punct, $assign) = ($$self{punct}, $$self{assign});

  # create arrays for key-value pairs and explicit values
  my @kv        = ();
  my @explicits = ();

  # iterate over all the key-value pairs to read
  while (1) {

    # gobble spaces
    $gullet->skipSpaces;

    # Read a single keyword, get a delimiter and a set of keyword tokens
    my ($ktoks, $delim) = $self->readKeyWordFrom($gullet, $until);

    # if there was no delimiter at the end, we throw an error
    Error('expected', $until, $gullet,
      "Fell off end expecting " . Stringify($until) . " while reading KeyVal key",
      "key started at $startloc")
      unless $delim;

    # turn the key tokens into a string and normalize
    my $key = ToString($ktoks); $key =~ s/\s//g;

    # if we have a non-empty key
    if ($key) {

      my $value;
      my $isDefault;

      # if we have an '=', we explcity assign a value
      if ($delim->equals($assign)) {
        $isDefault = 0;

        # setup the key-codes to properly read
        my $keyval = $self->getPrimaryKeyValOf($key, $self->resolveKeyValFor($key));
        my $keydef = $keyval->getType();
        $keydef->setupCatcodes if $keydef;

        # read until $punct
        my ($tok, @toks) = ();
        while ((!defined($delim = $gullet->readMatch($punct, $until)))
          && (defined($tok = $gullet->readToken()))) {    # Copy next token to args
          push(@toks, $tok,
            ($tok->getCatcode == CC_BEGIN ? ($gullet->readBalanced->unlist, T_END) : ())); }

        # reparse (and expand) the tokens representing the value
        $value = Tokens(@toks);
        $value = $keydef->reparse($gullet, $value) if $keydef && $value;

        # and cleanup
        $keydef->revertCatcodes if $keydef; }

      # we did not get an '=', and thus need to read the default value
      else { $isDefault = 1; }

      # and store our value please
      $self->addValue($key, $value, $isDefault, 0) if (!$silenceMissing || $self->canResolveKeyValFor($key)); }

    # we finish if we have the last element
    last if $delim->equals($until); }

  # rebuild and return nothing
  $self->rebuild;

  # restore all settings if we silenced the missing keys
  if ($silenceMissing) {
    $$self{skipMissing} = $skipMissing;
    $$self{hookMissing} = $hookMissing; }

  return; }

sub readKeyWordFrom {
  my ($self, $gullet, $close) = @_;

  # set of tokens we will expand
  my @tokens = ();

  # set of delimiters we want to ignore
  my @delim = ($close, $$self{punct}, $$self{assign});

  # we do not want any spaces
  $gullet->skipSpaces;

  # read tokens one-by-one
  my $token;
  while ($token = $gullet->readXToken) {
    # skip to the next iteration if we have a paragraph
    next if $token->equals(T_CS('\par'));

    # if we have one of out delimiters, we end
    last if grep { $token->equals($_) } @delim;

    # push a token unless we have a space
    # TODO: remove or normalize
    push(@tokens, $token) unless $$token[1] == CC_SPACE; }

  # return the tokens and the last token
  return (Tokens(@tokens), $token); }

#======================================================================
# Public accessors of all the values
#======================================================================
# Note: The API of this need to be stable, as people may be using it

# return the value of a given key. If multiple values are given, return the last one.
sub getValue {
  my ($self, $key) = @_;
  my %hash  = $self->getCachedHash;
  my $value = $hash{$key};
  # Since we (by default) accumulate lists of values when repeated,
  # we need to provide the "common" thing: return the last value given.
  return (!defined $value ? undef : (ref $value eq 'ARRAY' ? $$value[-1] : $value)); }

# return a list of values for a given key
sub getValues {
  my ($self, $key) = @_;
  my %hash  = $self->getCachedHash;
  my $value = $hash{$key};
  return (!defined $value ? () : (ref $value eq 'ARRAY' ? @$value : ($value))); }

# return the set of key-value pairs
sub getPairs {
  my ($self) = @_;
  return $self->getCachedPairs; }

# returns a key => ToString(value)
sub getHash {
  my ($self) = @_;
  my %hash = $self->getCachedHash;
  return map { ($_ => ToString($hash{$_})) } keys %hash; }

# return a hash of key-value pairs
sub getKeyVals {
  my ($self) = @_;
  my %hash = $self->getCachedHash;
  return \%hash; }

# checks if the value for a given key exists
sub hasKey {
  my ($self, $key) = @_;
  my %hash = $self->getCachedHash;
  return exists $hash{$key}; }

#======================================================================
# Value Related Reversion
#======================================================================

sub setKeysExpansion {
  my ($self)       = @_;
  my @skip         = $self->getSkip;
  my $setInternals = $self->getSetInternals;

  my ($punct, $assign) = ($$self{punct}, $$self{assign});

  # we might have to store values in a seperate token
  my $rmmacro     = $self->getSkipMissing;
  my $hookMissing = $self->getHookMissing;
  my $definedrm   = ref($rmmacro) ? 1 : 0;
  my @rmtokens    = ();

  # read in existing tokens (if they are defined)
  if ($definedrm && $STATE->lookupMeaning($rmmacro)) {
    @rmtokens = LaTeXML::Package::Expand($rmmacro)->unlist; }

  # define some xkeyval internals
  my @tokens = $setInternals ? (
    T_CS('\def'), T_CS('\XKV@fams'), T_BEGIN, Explode(join(',', $self->getKeySets)), T_END,
    T_CS('\def'), T_CS('\XKV@na'), T_BEGIN, Explode(join(',', @skip)), T_END
  ) : ();

  # iterate over the key-value pairs
  foreach my $tuple (@{ $$self{tuples} }) {
    my ($key, $value, $useDefault, $resolution, $keyval) = @$tuple;
    my @keyvals = @{$resolution};

    # we might want to skip to the next iteration if key is to be omitted
    next if (grep { $_ eq $key } @skip);

    # we might need to save the macros that weren't saved
    if (scalar @keyvals == 0) {
      if ($definedrm) {
        push(@rmtokens, $self->revertKeyVal($keyval, $value, $useDefault, (@rmtokens ? 0 : 1),
            1, $punct, $assign)); }
      my @reversion = $self->revertKeyVal($keyval, $value, $useDefault, 1, 1, $punct, $assign);
      push(@tokens, $hookMissing, T_BEGIN, $self->revertKeyVal($keyval, $value, $useDefault, 1, 1, $punct, $assign), T_END) if $hookMissing;
      next; }

    # and iterate over all valid keysets
    foreach my $keyset (@keyvals) {
      my $expansion = $keyset->setKeysExpansion($value, $useDefault, 1, 1, $setInternals);
      next unless defined($expansion);
      push(@tokens, $expansion->unlist); } }

  # and assign the macro with the other keys
  push(@tokens, T_CS('\def'), $rmmacro, T_BEGIN, @rmtokens, T_END) if $definedrm;

  # reset all the internals (if applicable)
  push(@tokens,
    T_CS('\def'), T_CS('\XKV@fams'), T_BEGIN, T_END,
    T_CS('\def'), T_CS('\XKV@na'), T_BEGIN, T_END) if $setInternals;

  # and return the list of tokens
  return Tokens(@tokens); }

sub beDigested {
  my ($self, $stomach) = @_;

  if ($$self{was_digested}) {
    Info('ignore', 'keyvals', $self,
      "Skipping digestion of \\setkeys as requested (did you digest a KeyVals twice?) "); }
  else {
    $stomach->digest($self->setKeysExpansion); }

  # new tuples we want to create
  my @newtuples = ();

  # iterate over them
  foreach my $tuple (@{ $$self{tuples} }) {
    my ($key, $value, $useDefault, $resolution, $keyval) = @$tuple;
    # digest a single token
    my $keydef = $keyval->getType();
    my $v      = (defined $value ?
        ($keydef ? $keydef->digest($stomach, $value, undef) : $value->beDigested($stomach))
      : undef);
    push(@newtuples, [$key, $v, $useDefault, $resolution, $keyval]); }

  # read all our current state
  my $prefix       = $self->getPrefix;
  my $keysets      = $self->getKeySets;
  my $setAll       = $self->getSetAll;
  my $skip         = $self->getSkip;
  my $setInternals = $self->getSetInternals;
  my $skipMissing  = $self->getSkipMissing;
  my $hookMissing  = $self->getHookMissing;
  my ($punct, $assign) = ($$self{punct}, $$self{assign});

  # then re-create the current object
  my $new = LaTeXML::Core::KeyVals->new(
    $prefix, $keysets,
    setAll => $setAll, setInternals => $setInternals,
    skip => $skip, skipMissing => $skipMissing, hookMissing => $hookMissing,
    was_digested => 1,
    punct        => $punct, assign => $assign);
  $new->setTuples(@newtuples);
  return $new; }

sub revert {
  my ($self) = @_;

  # read values from class
  my ($punct, $assign) = ($$self{punct}, $$self{assign});

  my @tokens = ();

  # iterate over the key-value pairs
  foreach my $tuple (@{ $$self{tuples} }) {
    my ($key, $value, $useDefault, $resolution, $keyval) = @$tuple;
    # revert a single token
    if ($keyval) {    # when is this undef?
      push(@tokens, $self->revertKeyVal($keyval, $value, $useDefault, (@tokens ? 0 : 1), 0, $punct, $assign)); } }

  # and return the list of tokens
  return Tokens(@tokens); }

# turns this object into a string
sub toString {
  my ($self) = @_;

  my @kv = $self->getPairs;
  my ($punct, $assign) = ($$self{punct} || '', $$self{assign} || ' ');

  my $string = '';

  while (@kv) {
    my ($key, $value) = (shift(@kv), shift(@kv));
    $string .= ToString($punct) . ' ' if $string;
    $string .= $key . ToString($assign) . ToString($value); }
  return $string; }

sub revertKeyVal {
  my ($self, $keyval, $value, $useDefault, $isFirst, $compact, $punct, $assign) = @_;

  # get the key-value definition
  my $keydef = $keyval->getType();

  # define the tokens
  my @tokens = ();

  # write comma and key, unless in the first iteration
  push(@tokens, $punct)  if $punct    && !$isFirst;
  push(@tokens, T_SPACE) if !$isFirst && !$compact;
  push(@tokens, Explode($keyval->getKey));

  # write the default (if applicable)
  if (!$useDefault && $value) {
    push(@tokens, ($assign || T_SPACE));
    push(@tokens, ($keydef ? $keydef->revert($value) : Revert($value))); }

  return @tokens; }

# TODO: ????
sub unlist {
  my ($self) = @_;
  return $self; }

#======================================================================
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Core::KeyVals> - Key-Value Pairs in LaTeXML

=head1 DESCRIPTION

Provides a parser and representation of keyval pairs
C<LaTeXML::Core::KeyVals> represents parameters handled by LaTeX's keyval package.
It extends L<LaTeXML::Common::Object>.

=head2 Accessors

=over 4

=item C<< GetKeyVal($arg,$key) >>

Access the value associated with a given key. 
This is useful within constructors to access the value associated with C<$key> 
in the argument C<$arg>. Example usage in a copnstructor:

<foo attrib='&GetKeyVal(#1,'key')'>

=item C<< GetKeyVals($arg) >>

Access the entire hash. Can be used in a constructor like:
Can use in constructor: <foo %&GetKeyVals(#1)/>

=back

=head2 Constructors

=over 4

=item C<<LaTeXML::Core::KeyVals->new(I<prefix>, I<keysets>, I<options>)); >>

Creates a new KeyVals object with the given parameters. 
All arguments are optional and the simples way of calling this method is 
C<< my $keyvals = LaTeXML::Core::KeyVals->new() >>. 

I<prefix> is the given prefix all key-value pairs operate in and defaults to 
C<'KV'>. If given, prefix should be a string. 

I<keysets> should be a list of keysets to find keys inside of. If given, it
should either be reference to a list of strings or a comma-seperated string. 
This argument defaults to C<'_anonymous_'>. 

Furthermore, the KeyVals constructor accepts a variety of options that can
be used to customize its behaviour. These are I<setAll>, I<setInternals>, 
I<skip>, I<skipMissing>, I<hookMissing>, I<open>, I<close>,
I<punct> and I<assign>. 

I<setAll> is a flag that, if set, ensures that keys will be set in all existing
keysets, instad of only in the first one. 

I<setInternals> is a flag that, if set, ensures that certain 'xkeyval' package
internals are set during key digestion. 

I<skip> should be a list of keys to be skipped when digesting the keys of this
object. 

I<skipMissing> allows one way of handling keys during key digestion
that have not been explictilty declared using C<DefKey> or related
functionality. If set to C<undef> or C<0>, an error is thrown upon trying to set
such a key, if set to C<1> they are ignored. Alternatively, this can be set to a
key macro which is then extended to contain a comman-separated list of the
undefined keys. 

I<hookMissing> allows to call a specific macro if a single key is unknown during
key digestion. 

The options I<open>, I<close>, I<punct> and I<assign> optionally contain the 
tokens used for the respective meanings. 

=back

=head2 KeyVals Accessors (intended for internal usage)

=over 4

=item C<< my $prefix = $keyvals->getPrefix() >>

Returns the I<Prefix> property. 

=item C<< my @keysets = $keyvals->getKeySets() >>

Returns the I<KeySets> property. 

=item C<< my $setall = $keyvals->getSetAll() >>

Returns the I<SetAll> property. 

=item C<< my $setinternals = $keyvals->getSetInternals() >>

Returns the I<SetInternals> property. 

=item C<< my @skip = $keyvals->getSkip() >>

Returns the I<Skip> property. 

=item C<< my $skipmissing = $keyvals->getSkipMissing() >>

Returns the I<SkipMissing> property. 

=item C<< my $hookmissing = $keyvals->getHookMissing() >>

Returns the I<HookMissing> property. 

=item C<< my @tuples = $keyvals->getTuples() >>

Returns the I<Tuples> property representing

=item C<< $keyvals->setTuples(@tuples) >>

Sets the I<tuples> which should be a list of five-tuples (array references) representing
the key-value pairs this KeyVals object is seeded with. See the I<getTuples>
function on details of the structure of this list. 
I<rebuild> is called automatically to populate the other caches. 
Typically, the tuples is set by I<readFrom>.

=item C<< my @cachedpairs = $keyvals->getCachedPairs() >>

Returns the I<CachedPairs> property. 

=item C<< my %cachedhash = $keyvals->getCachedHash() >>

Returns the I<CachedHash> property. 

=back

=head2 Resolution to KeySets

=over 4

=item C<< my @keysets = $keyvals->resolveKeyValFor($key) >>

Finds all I<KeyVal> objects that should be used for interacting with the given
I<key>. May return C<undef> if no matching keysets are found. Use the parameters
 I<keysets>, I<setAll> and I<skipMissing> to customize the exact behaviour of
this function. 

=item C<< my $canResolveKeyVal = $keyvals->canResolveKeyValFor($key) >>

Checks if this I<KeyVals> object can resolve a KeyVal for I<key>. Ignores
I<setAll> and I<skipMissing> parameters. 

=item C<< my $keyval = $keyvals->getPrimaryKeyValOf($key, @keysets) >>

Gets a single I<KeyVal> parameter to be used for interacting a a single I<key>, 
given that it resolves to I<keysets>. Always returns a single I<KeyVal> object, 
even if no keysets are found. 

=back

=head2 Changing contained values

=over 4

=item C<< $keyvals->addValue($key, $value, $useDefault, $noRebuild) >>

Adds the given I<value> for I<key> at the end of the given list of values and
rebuilds all internal caches. If the I<useDefault> flag is set, the specific
value is ignored, and the default is set instead. 

If this function is called multiple times the I<noRebuild> option should be 
given to prevent constant rebuilding and the I<rebuild> function should be 
called manually called. 

=item C<< $keyvals->setValue($key, $value, $useDefault) >>

Sets the value of I<key> to I<value>, optionally using the default if 
I<useDefault> is set. Note that if I<value> is a reference to an array, 
the key is inserted multiple times. If I<value> is C<undef>, the values is
deleted. 

=item C<< $keyvals->rebuild($skip) >>

Rebuilds the internal caches of key-value mapping and list of pairs from from
main list of tuples. If I<skip> is given, all values for the given key are
omitted, and the given key is deleted. 

=back

=head2 Parsing values from a gullet

=over 4

=item C<< $keyvals->readFrom($gullet, $until, %options) >>

Reads a set of KeyVals from I<gullet>, up until the I<until> token, and updates
the state of this I<KeyVals> object accordingly. 

Furthermore, this methods supports several options. 

When the I<silenceMissing> option is set, missing keys will be completely
ignored when reading keys, that is they do not get recorded into the KeyVals
object and no warnings or errors will be thrown. 

=item C<< $keyvals->readKeyWordFrom($gullet, $until) >>

Reads a single keyword from I<gullet>. Intended for internal use only. 

=back

=head2 KeyVals Accessors

=over 4

=item C<< my $value = $keyvals->getValue($key); >>

Return a value associated with C<$key>. 

=item C<< @values = $keyvals->getValues($key); >>

Return the list of all values associated with C<$key>. 

=item C<< %keyvals = $keyvals->getKeyVals; >>

Return the hash reference containing the keys and values bound in the C<$keyval>.
Each value in the hash may be a single value or a list if the key is repeated. 

=item C<< @keyvals = $keyvals->getPairs; >>

Return the alternating keys and values bound in the C<$keyval>.
Note that this may contain multiple entries for a given key, if they
were repeated. 

=item C<< %hash = $keyvals->getHash; >>

Return the hash reference containing the keys and values bound in the C<$keyval>.
Note that will only contain the last value for a given key, if they
were repeated.

=item C<< $haskey = $keyvals->hasKey($key); >>

Checks if the KeyVals object contains a value for $key. 

=back

=head2 Value Related Reversion

=over 4

=item C<< $expansion = $keyvals->setKeysExpansion; >>

Expand this KeyVals into a set of tokens for digesting keys. 


=item C<< $keyvals = $keyvals->beDigested($stomach); >>

Return a new C<LaTeXML::Core::KeyVals> object with both keys and values
digested. 

=item C<< $reversion = $keyvals->revert(); >>

Revert this object into a set of tokens representing the original 
sequence of Tokens that was used to be read it from the gullet. 

=item C<< $str = $keyvals->toString(); >>

Turns this object into a key=value comma seperated string. 

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>
Tom Wiesing <tom.wiesing@gmail.com>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
