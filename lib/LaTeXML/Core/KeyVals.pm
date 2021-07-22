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
use LaTeXML::Core::KeyVal;
use base qw(LaTeXML::Common::Object);

our @EXPORT = (
  qw(&GetKeyVal &GetKeyVals)
);

#======================================================================
# Exposed Methods
#======================================================================

sub GetKeyVal {
  my ($keyvals, $key) = @_;
  return (defined $keyvals) && $keyvals->getValue($key); }

sub GetKeyVals {
  my ($keyvals) = @_;
  return (defined $keyvals ? $keyvals->getKeyVals : {}); }

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
  my $self = bless {
    # which KeyVals are we parsing and how do we behave?
    prefix      => $prefix,      keysets     => $keysets,
    skip        => $skip,        setAll      => $setAll, setInternals => $setInternals,
    skipMissing => $skipMissing, hookMissing => $hookMissing,
    # all the internal representations
    tuples => [], cachedPairs => [()], cachedHash => {} },
    $class;
  if (my $tuples = $options{tuples}) {
    $$self{tuples} = $tuples;
    $self->rebuild; }
  return $self; }

#======================================================================
# Resolution to KeySets
#======================================================================
# Return a list of the keysets in which this key is defined
sub resolveKeyValFor {
  my ($self, $key) = @_;
  my $prefix     = $$self{prefix};
  my @allkeysets = @{ $$self{keysets} };
  my @keysets    = grep { HasKeyVal($prefix, $_, $key); } @{ $$self{keysets} };
  # throw an error, unless we record the missing macros
  if (scalar @keysets == 0) {
    Error('undefined', 'Encountered unknown KeyVals key',
      "'$key' with prefix '$prefix' not defined in '" . join(",", @allkeysets) . "', " .
        'were you perhaps using \setkeys instead of \setkeys*?') unless defined($$self{skipMissing});
    return; }
  # return either the first or all of the KeyVal objects
  return ($$self{setAll} ? @keysets : ($keysets[0])); }

sub canResolveKeyValFor {
  my ($self, $key) = @_;
  my $prefix = $$self{prefix};
  # iterate over the keysets
  foreach my $keyset (@{ $$self{keysets} }) {
    return 1 if HasKeyVal($prefix, $keyset, $key); }
  return 0; }

# Return the 1st of the keysets, or the 1st one of the KeyVals itself
sub getPrimaryKeyValOf {
  my ($self, $key, @keysets) = @_;
  return (@keysets ? $keysets[0] : $$self{keysets}[0]); }

#======================================================================
# Changing contained values
#======================================================================

sub addValue {
  my ($self, $key, $value, $useDefault, $noRebuild) = @_;

  # figure out the keyset(s) for the key to be added
  my @keysets = $self->resolveKeyValFor($key);
  my $pkeyset = $self->getPrimaryKeyValOf($key, @keysets);

  # and add the new tuple to the set of tuples
  push(@{ $$self{tuples} },
    [$key, ($useDefault ? keyval_get(keyval_qname($$self{prefix}, $pkeyset, $key), 'default') : $value),
      $useDefault, $pkeyset, [@keysets]]);

  # we now need to rebuild, unless we were asked not to
  # TODO: Maybe only update the last element?
  $self->rebuild unless $noRebuild;
  return; }

sub setValue {
  my ($self, $key, $value, $useDefault) = @_;
  # delete the existing values by skipping key;
  $self->rebuild($key);

  # if we have an array, we need to push all of them
  if (ref $value eq 'ARRAY') {
    foreach my $val (@{$value}) {
      $self->addValue($key, $val, $useDefault, 1); }
    $self->rebuild(); }
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
    my ($key, $value, $useDefault, $keyset, $keysets) = @$tuple;
    # if we want to skip some values, we need to store new tuples
    if (defined($skip)) {
      next if $key eq $skip;
      push(@newtuples, [$key, $value, $useDefault, $keyset, $keysets]) if defined($skip); }
    # push key / value into the pair
    push(@pairs, $key, $value);
    # if we do not have a value yet, set it
    if (!defined $hash{$key}) {
      $hash{$key} = $value; }
    # If we get a third value, push into an array
    # This is unlikely to be what the caller expects!! But what else?
    elsif (ref $hash{$key} eq 'ARRAY') {
      push(@{ $hash{$key} }, $value); }
    # If we get a second value, make an array
    else {
      $hash{$key} = [$hash{$key}, $value]; } }
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
  my $skipMissing    = $$self{skipMissing};
  my $hookMissing    = $$self{hookMissing};

  # if we want to silence all missing errors, store them in a hook
  if ($silenceMissing) {
    $$self{skipMissing} = 1;
    $$self{hookMissing} = undef; }

  # read the opening token and figure out where we are
  my $startloc = $gullet->getLocator;
  # set and read tokens
  my $open = $gullet->readToken;
  # create arrays for key-value pairs and explicit values
  my @kv        = ();
  my @explicits = ();
  # iterate over all the key-value pairs to read
  while (1) {
    # gobble leading spaces
    $gullet->skipSpaces;
    if ($gullet->ifNext(T_BEGIN)) {    # Protect against redundant {} wrapping
      $gullet->readToken;
      $gullet->unread($gullet->readBalanced()->stripBraces);
      $gullet->skipSpaces; }
    # Read a single keyword, get a delimiter and a set of keyword tokens
    my ($ktoks, $delim) = $self->readKeyWordFrom($gullet, $until);

    # if there was no delimiter at the end, we throw an error
    Error('expected', $until, $gullet,
      "Fell off end expecting " . Stringify($until) . " while reading KeyVal key",
      "key started at " . ToString($startloc))
      unless $delim;

    # turn the key tokens into a string and trim whitespace
    my $key = ToString($ktoks); $key =~ s/^\s+//; $key =~ s/\s+$//;
    # if we have a non-empty key
    if ($key) {
      my $value;
      my $isDefault;
      # if we have an '=', we explcity assign a value
      if ($delim->equals(T_OTHER('='))) {
        $isDefault = 0;
        # setup the key-codes to properly read
        my $keyset  = $self->getPrimaryKeyValOf($key, $self->resolveKeyValFor($key));
        my $keytype = keyval_get(keyval_qname($$self{prefix}, $keyset, $key), 'type');
        $keytype->setupCatcodes if $keytype;
        # read until comma
        my ($tok, @toks) = ();
        while ((!defined($delim = $gullet->readMatch(T_OTHER(','), $until)))
          && (defined($tok = $gullet->readToken()))) {    # Copy next token to args
          push(@toks, $tok,
            ($tok->getCatcode == CC_BEGIN ? ($gullet->readBalanced, T_END) : ())); }
        # reparse (and expand) the tokens representing the value
        $value = Tokens(@toks)->stripBraces;
        $value = $keytype->reparse($gullet, $value) if $keytype && $value;
        # and cleanup
        $keytype->revertCatcodes if $keytype; }
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
  my @tokens = ();
  my @delim  = ($close, T_OTHER(','), T_OTHER('='));
  $gullet->skipSpaces;    # Skip leasding spaces
  my $token;
  while ($token = $gullet->readXToken) {
    # skip to the next iteration if we have a paragraph
    next if $token->equals(T_CS('\par'));
    # if we have one of out delimiters, we end
    last if grep { $token->equals($_) } @delim;
    push(@tokens, $token); }
  # return the tokens and the last token
  return (Tokens(@tokens), $token); }

#======================================================================
# Public accessors of all the values
#======================================================================
# Note: The API of this need to be stable, as people may be using it

# return the value of a given key. If multiple values are given, return the last one.
sub getValue {
  my ($self, $key) = @_;
  my %hash  = %{ $$self{cachedHash} };
  my $value = $hash{$key};
  # Since we (by default) accumulate lists of values when repeated,
  # we need to provide the "common" thing: return the last value given.
  return (!defined $value ? undef : (ref $value eq 'ARRAY' ? $$value[-1] : $value)); }

# return a list of values for a given key
sub getValues {
  my ($self, $key) = @_;
  my %hash  = %{ $$self{cachedHash} };
  my $value = $hash{$key};
  return (!defined $value ? () : (ref $value eq 'ARRAY' ? @$value : ($value))); }

# return the set of key-value pairs
sub getPairs {
  my ($self) = @_;
  return @{ $$self{cachedPairs} }; }

# returns a key => ToString(value)
sub getHash {
  my ($self) = @_;
  return %{ $$self{cachedHash} }; }

# return a hash of key-value pairs
sub getKeyVals {
  my ($self) = @_;
  my %hash = %{ $$self{cachedHash} };
  return \%hash; }    # A COPY ??? or can it be the real hash?

# checks if the value for a given key exists
sub hasKey {
  my ($self, $key) = @_;
  return exists $$self{cachedHash}{$key}; }

#======================================================================
# Value Related Reversion
#======================================================================

# This apparently means "the expansion of \setkeys"
sub setKeysExpansion {
  my ($self)       = @_;
  my @skipkeys     = @{ $$self{skip} };
  my $setInternals = $$self{setInternals};
  my $prefix       = $$self{prefix};
  # we might have to store values in a seperate token
  my $rmmacro     = (ref $$self{skipMissing} ? $$self{skipMissing} : undef);
  my $hookMissing = $$self{hookMissing};
  my @rmtokens    = ();
  # read in existing tokens (if they are defined)
  if ($rmmacro && $STATE->lookupMeaning($rmmacro)) {
    @rmtokens = LaTeXML::Package::Expand($rmmacro)->unlist; }
  # define some xkeyval internals
  my @tokens = ();
  push(@tokens,
    T_CS('\def'), T_CS('\XKV@fams'), T_BEGIN, Explode(join(',', @{ $$self{keysets} })), T_END,
    T_CS('\def'), T_CS('\XKV@na'), T_BEGIN, Explode(join(',', @skipkeys)), T_END)
    if $setInternals;

  # iterate over the key-value pairs
  foreach my $tuple (@{ $$self{tuples} }) {
    my ($key, $value, $useDefault, $keyset, $keysets) = @$tuple;
    next if (grep { $_ eq $key } @skipkeys);    # Skip these keys
    my @keysets = @{$keysets};
    # we might need to save the macros that weren't saved
    if (scalar @keysets == 0) {
      if ($rmmacro) {
        push(@rmtokens, $self->revertKeyVal($key, $keyset, $value, $useDefault, (@rmtokens ? 0 : 1))); }
      my @reversion = $self->revertKeyVal($key, $keyset, $value, $useDefault);
      push(@tokens, $hookMissing, T_BEGIN, $self->revertKeyVal($key, $keyset, $value, $useDefault, 1), T_END) if $hookMissing;
      next; }

    # and iterate over all valid keysets
    foreach my $keyset (@keysets) {
      my $qname = keyval_qname($prefix, $keyset, $key);
      if (!HasKeyVal($prefix, $keyset, $key)) {
        Error('undefined', 'Encountered unknown KeyVals key',
          "'" . $key . "' with prefix '" . $prefix
            . "' not defined in '" . join(",", $keyset) . "'"); }
      elsif (keyval_get($qname, 'disabled')) {    # if we are disabled, return an empty tokens
        Warn('undefined', "`" . $key . "' has been disabled. "); }
      else {
        push(@tokens,                             # definition of 'xkeyval' internals (if applicable)
          T_CS('\def'), T_CS('\XKV@prefix'), T_BEGIN, Explode($prefix . '@'), T_END,
          T_CS('\def'), T_CS('\XKV@tfam'),   T_BEGIN, Explode($keyset), T_END,
          T_CS('\def'), T_CS('\XKV@header'), T_BEGIN, Explode($prefix . '@' . $keyset . '@'), T_END,
          T_CS('\def'), T_CS('\XKV@tkey'),   T_BEGIN, Explode($key), T_END
        ) if $setInternals;
        if ($useDefault) {                        # if it was not given explicitly, call the default macro
          push(@tokens, T_CS('\\' . $qname . '@default')); }
        else {    # we have a value given, call the appropriate macro with it
          push(@tokens, T_CS('\\' . $qname), T_BEGIN, Revert($value), T_END); }
        # and reset the internals (if applicable)
        push(@tokens,
          T_CS('\def'), T_CS('\XKV@prefix'), T_BEGIN, T_END,
          T_CS('\def'), T_CS('\XKV@tfam'),   T_BEGIN, T_END,
          T_CS('\def'), T_CS('\XKV@header'), T_BEGIN, T_END,
          T_CS('\def'), T_CS('\XKV@tkey'),   T_BEGIN, T_END) if $setInternals;
  } } }

  # and assign the skipmissing macro with the other keys
  push(@tokens, T_CS('\def'), $rmmacro, T_BEGIN, @rmtokens, T_END) if $rmmacro;
  # reset all the internals (if applicable)
  push(@tokens,
    T_CS('\def'), T_CS('\XKV@fams'), T_BEGIN, T_END,
    T_CS('\def'), T_CS('\XKV@na'),   T_BEGIN, T_END) if $setInternals;

  return Tokens(@tokens); }

sub beDigested {
  my ($self, $stomach) = @_;

  if ($$self{was_digested}) {
    Info('ignore', 'keyvals', $self,
      "Skipping digestion of \\setkeys as requested (did you digest a KeyVals twice?) "); }
  else {
    $stomach->digest($self->setKeysExpansion); }

  # iterate over the tuples, digesting the values
  my @newtuples = ();
  foreach my $tuple (@{ $$self{tuples} }) {
    my ($key, $value, $useDefault, $keyset, $keysets) = @$tuple;
    my $keytype = keyval_get(keyval_qname($$self{prefix}, $keyset, $key), 'type');
    my $v       = (defined $value ?
        ($keytype ? $keytype->digest($stomach, $value, undef) : $value->beDigested($stomach))
      : undef);
    push(@newtuples, [$key, $v, $useDefault, $keyset, $keysets]); }

  # then Copy the current object
  my $new = LaTeXML::Core::KeyVals->new(
    $$self{prefix}, $$self{keysets},
    setAll       => $$self{setAll}, setInternals => $$self{setInternals},
    skip         => $$self{skip},   skipMissing  => $$self{skipMissing},
    hookMissing  => $$self{hookMissing},
    was_digested => 1,
    tuples       => [@newtuples]);
  return $new; }

sub revert {
  my ($self) = @_;
  # read values from class
  my @tokens = ();
  # iterate over the key-value pairs
  foreach my $tuple (@{ $$self{tuples} }) {
    my ($key, $value, $useDefault, $keyset, $keysets) = @$tuple;
    # revert a single token
    if ($keyset) {    # when is this undef?
      push(@tokens, $self->revertKeyVal($key, $keyset, $value, $useDefault, (@tokens ? 0 : 1))); } }

  # and return the list of tokens
  return Tokens(@tokens); }

# turns this object into a string
sub toString {
  my ($self) = @_;
  my @kv     = $self->getPairs;
  my $string = '';
  while (@kv) {
    my ($key, $value) = (shift(@kv), shift(@kv));
    $string .= ',' if $string;
    $string .= $key . '=' . ToString($value); }
  return $string; }

sub revertKeyVal {
  my ($self, $key, $keyset, $value, $useDefault, $isFirst) = @_;
  # get the key-value definition
  my $keytype = keyval_get(keyval_qname($$self{prefix}, $keyset, $key), 'type');
  # define the tokens
  my @tokens = ();
  # write comma and key, unless in the first iteration
  push(@tokens, T_OTHER(',')) if !$isFirst;
  push(@tokens, Explode($key));
  # write the default (if applicable)
  if (!$useDefault && $value) {
    push(@tokens, T_OTHER('='), ($keytype ? $keytype->revert($value) : Revert($value))); }
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
I<skip>, I<skipMissing>, I<hookMissing>, I<open>, I<close>.

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

=back

=head2 KeyVals Accessors (intended for internal usage)

=over 4

=item C<< $keyvals->setTuples(@tuples) >>

Sets the I<tuples> which should be a list of five-tuples (array references) representing
the key-value pairs this KeyVals object is seeded with. See the I<getTuples>
function on details of the structure of this list. 
I<rebuild> is called automatically to populate the other caches. 
Typically, the tuples is set by I<readFrom>.

=back

=head2 Resolution to KeySets

=over 4

=item C<< my @keysets = $keyvals->resolveKeyValFor($key) >>

Finds all keysets that should be used for interacting with the given
I<key>. May return C<undef> if no matching keysets are found. Use the parameters
 I<keysets>, I<setAll> and I<skipMissing> to customize the exact behaviour of
this function.

=item C<< my $canResolveKeyVal = $keyvals->canResolveKeyValFor($key) >>

Checks if this I<KeyVals> object can resolve a KeyVal for I<key>. Ignores
I<setAll> and I<skipMissing> parameters. 

=item C<< my $keyval = $keyvals->getPrimaryKeyValOf($key, @keysets) >>

Gets the primary keyset to be used for interacting a a single I<key>,
given that it resolves to I<keysets>. Defaults to first keyset in KeyVals, if none given.

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
