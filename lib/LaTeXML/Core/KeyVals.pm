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
  qw(&DefKeyVal &GetKeyVal &GetKeyVals)
);

#======================================================================
# KeyVal Internal Helper functions
#======================================================================

# Gets the header matching to a given key-val pair
sub getKeyValHeader {
  my ($prefix, $keyset, $key) = @_;

  # prefix defaults to 'KV' if it is not defined
  # to be backwards compatible with the keyval package
  $prefix = $prefix || 'KV';

  my @header = ();

  # now we need to join all the components
  push(@header, $prefix) if $prefix;
  push(@header, $keyset) if $keyset;
  push(@header, $key);
  return join('@', @header); }

#======================================================================
# State Getter Methods
#======================================================================

# Get the LaTeXML definition (i.e. the type) of a keyval parameter
sub getKeyValType {
  my ($prefix, $keyset, $key) = @_;
  my $header = getKeyValHeader($prefix, $keyset, $key);

  return $STATE->lookupValue('KEYVAL@type@' . $header); }

# Get the LaTeXML default (i.e. the type) of a parameter
sub getKeyValDefault {
  my ($prefix, $keyset, $key) = @_;
  my $header = getKeyValHeader($prefix, $keyset, $key);

  return $STATE->lookupValue('KEYVAL@default@' . $header); }

#======================================================================
# Exposed Methods
#======================================================================

# Defines a new key-value pair and returns it's header
sub DefKeyVal {
  my ($keyset, $key, $type, $default, %options) = @_;

  # find the header to use for all the mappings
  my $header = getKeyValHeader($options{prefix}, $keyset, $key);

  # store the (LaTeXML) type of the key-value pair
  my $paramlist = LaTeXML::Package::parseParameters($type || "{}", "KeyVal $key in set $keyset");
  if (scalar(@$paramlist) != 1) {
    Warn('unexpected', 'keyval', $key,
      "Too many parameters in keyval $key (in set $keyset); taking only first", $paramlist); }
  my $parameter = $$paramlist[0];
  LaTeXML::Package::AssignValue('KEYVAL@type@' . $header => $parameter);

  # store the default value (if applicable)
  LaTeXML::Package::AssignValue('KEYVAL@default@' . $header => LaTeXML::Package::Tokenize($default))
    if defined $default;

  # if we have code, we should define the macros as well
  my $code = $options{code};
  if (defined($code)) {
    LaTeXML::Package::DefMacroI('\\' . $header,
      LaTeXML::Core::Parameters->new(LaTeXML::Core::Parameter->new('Plain', '{}')),
      $code,
      scope => 'global');

    LaTeXML::Package::DefMacroI('\\' . $header . '@default', undef,
      Tokens(T_CS('\\' . $header), T_BEGIN, LaTeXML::Package::Tokenize($default), T_END),
      scope => 'global')
      if $default;
  }

  return $header; }

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

#======================================================================
# KeyVal Parsing Methods
#======================================================================
# A KeyVal argument MUST be delimited by either braces or brackets (if optional)
# This method reads the keyval pairs INCLUDING the delimiters, (rather than parsing
# after the fact), since some values may have special catcode needs.
##my $T_EQ    = T_OTHER('=');    # [CONSTANT]
##my $T_COMMA = T_OTHER(',');    # [CONSTANT]

# Read a set of Key-Val parameters from the gullet and create a KeyVals objects
sub readKeyVals {
  # we need a gullet, a prefix, a keyset and a token to close groups
  my ($gullet, $prefix, $keyset, $close) = @_;

  # read the opening token and figure out where we are
  my $startloc = $gullet->getLocator();
  my $open     = $gullet->readToken;

  # token representing assignment and punctuation
  my $assign = T_OTHER('=');
  my $punct  = T_OTHER(',');

  # setup prefix and keyset in a sane fashion
  $prefix = ($prefix ? ToString($prefix) : 'KV');
  $keyset = ($keyset ? ToString($keyset) : '_anonymous_');

  # create arrays for key-value pairs and explicit values
  my @kv        = ();
  my @explicits = ();

  # iterate over all the key-value pairs to read
  while (1) {

    # gobble spaces
    $gullet->skipSpaces;

    # Read a single keyword, get a delimiter and a set of keyword tokens
    my ($ktoks, $delim) = readKeyValsKeyword($gullet, $close);

    # if there was no delimiter at the end, we throw an error
    Error('expected', $close, $gullet,
      "Fell off end expecting " . Stringify($close) . " while reading KeyVal key",
      "key started at $startloc")
      unless $delim;

    # turn the key tokens into a string and normalize
    my $key = ToString($ktoks); $key =~ s/\s//g;

    # if we have a non-empty key
    if ($key) {

      my ($value, $explicit);

      # get the type of the key-value pair
      my $keydef = getKeyValType($prefix, $keyset, $key);

      # if we have an '=', we explcity assign a value
      if ($delim->equals($assign)) {
        $explicit = 1;

        # setup the key-codes to properly read
        $keydef->setupCatcodes if $keydef;

        # read until $punct
        my ($tok, @toks) = ();
        while ((!defined($delim = $gullet->readMatch($punct, $close)))
          && (defined($tok = $gullet->readToken()))) {    # Copy next token to args
          push(@toks, $tok,
            ($tok->getCatcode == CC_BEGIN ? ($gullet->readBalanced->unlist, T_END) : ())); }

        # reparse (and expand) the tokens representing the value
        $value = Tokens(@toks);
        $value = $keydef->reparse($gullet, $value) if $keydef && $value;

        # and cleanup
        $keydef->revertCatcodes if $keydef;
      }

      # we did not get an '=', and thus need to read the default value
      else {
        $explicit = 0;
        $value = getKeyValDefault($prefix, $keyset, $key);
      }

      # store all the parsed things
      push(@kv,        $key);
      push(@kv,        $value);
      push(@explicits, $explicit);
    }

    # we finish if we have the last element
    last if $delim->equals($close); }

  # create the new keyvals object
  return LaTeXML::Core::KeyVals->new($prefix, $keyset, [@kv],
    explicits => [@explicits],
    open      => $open, close => $close,
    punct     => $punct, assign => $assign); }

# Read a keyvals keyword (tokens DO get expanded)
# read until we find =, comma or the end delimiter of the keyvals (typically } or ])
sub readKeyValsKeyword {

  # we need a gullet and a closing token
  my ($gullet, $close) = @_;

  # set of tokens we will expand
  my @tokens = ();

  # set of delimters we want to ignore
  my @delim = ($close, T_OTHER('='), T_OTHER(','));

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
# The Data object representing the KeyVals
#======================================================================
# This defines the KeyVal data object that can appear in the datastream
# along with tokens, boxes, etc.
# Thus it has to be digestible.

# KeyVals: representation of keyval arguments,
# Not necessarily a hash, since keys could be repeated and order may
# be significant.
#**********************************************************************
# Where does this really belong?
# The values can be Tokens, after parsing, or Boxes, after digestion.
# (or Numbers, etc. in either case)
# But also, it has a non-generic API used above...
# If Box-like, it could have a beAbsorbed method; which would do what?
# Should it convert to simple text? Or structure?
# If latter, there needs to be a key => tag mapping.

# Options can be tokens for open, close, punct (between pairs), assign (typically =)
sub new {
  my ($class, $prefix, $keyset, $pairs, %options) = @_;

  # make sure prefix and keyset are string (if applicable)
  $prefix = ($prefix ? ToString($prefix) : 'KV');
  $keyset = ($keyset ? ToString($keyset) : '_anonymous_');

  # Load pairs and explicits
  my @pp = @$pairs;
  my @explicits = @{ $options{explicits} || [(1) x ((scalar @pp) / 2)] };

  # create a hash of valuies
  my %hash = ();
  while (@pp) {
    my ($k, $v) = (shift(@pp), shift(@pp));

    # if we do not have a value yet, set it
    if (!defined $hash{$k}) { $hash{$k} = $v; }

    # If we get a third value, push into an array
    # This is unlikely to be what the caller expects!! But what else?
    elsif (ref $hash{$k} eq 'ARRAY') { push(@{ $hash{$k} }, $v); }

    # If we get a second value, make an array
    else { $hash{$k} = [$hash{$k}, $v]; } }

  return bless {
    prefix => $prefix, keyset => $keyset,
    keyvals => $pairs, hash => {%hash}, explicits => [@explicits],
    open  => $options{open},  close  => $options{close},
    punct => $options{punct}, assign => $options{assign} },
    $class; }

# creates an empty key-vals object from a (prefix, keyset) combination
sub empty {
  my ($prefix, $keyset) = @_;
  return LaTeXML::Core::KeyVals->new($prefix, $keyset, [], open => T_BEGIN, close => T_END); }

# return the value of a given key. If multiple values are given, return the last one.
sub getValue {
  my ($self, $key) = @_;
  my $value = $$self{hash}{$key};
  # Since we (by default) accumulate lists of values when repeated,
  # we need to provide the "common" thing: return the last value given.
  return (!defined $value ? undef : (ref $value eq 'ARRAY' ? $$value[-1] : $value)); }

# return a list of values for a given key
sub getValues {
  my ($self, $key) = @_;
  my $value = $$self{hash}{$key};
  return (!defined $value ? () : (ref $value eq 'ARRAY' ? @$value : ($value))); }

# sets of deletes a value for a given key
sub setValue {
  my ($self, $key, $value) = @_;
  if (defined $value) {
    $$self{hash}{$key} = $value; }
  else {
    delete $$self{hash}{$key}; }
  return; }

# return the set of key-value pairs
sub getPairs {
  my ($self) = @_;
  return @{ $$self{keyvals} }; }

# return a hash of key-value pairs
sub getKeyVals {
  my ($self) = @_;
  return $$self{hash}; }

# returns a hash kof key-value pairs
sub getHash {
  my ($self) = @_;
  return map { ($_ => ToString($$self{hash}{$_})) } keys %{ $$self{hash} }; }

# checks if the value for a given key exists
sub hasKey {
  my ($self, $key) = @_;
  return exists $$self{hash}{$key}; }

# digests this key-val object
sub beDigested {

  my ($self, $stomach) = @_;

  # read the prefix and keyset of this object
  my $prefix = $$self{prefix};
  my $keyset = $$self{keyset};

  # read the set of key-value pairs and explicit values
  my @kv        = @{ $$self{keyvals} };
  my @explicits = @{ $$self{explicits} };

  my @dkv = ();
  while (@kv) {
    my ($key, $value, $explicit) = (shift(@kv), shift(@kv), shift(@explicits));

    # get the key-value definition
    my $keydef = getKeyValType($prefix, $keyset, $key);

    # digest key & value pairs
    push(@dkv, $key,
      ($keydef ? $keydef->digest($stomach, $value, undef) : $value->beDigested($stomach)))
      if $value; }

  # and re-create the KeyVals object
  return LaTeXML::Core::KeyVals->new($prefix, $keyset,
    [@dkv], explicits => [@explicits],
    open  => $$self{open},  close  => $$self{close},
    punct => $$self{punct}, assign => $$self{assign}); }

# reverts this key-value object into a set of tokens representing
# the source that was used to parse it
sub revert {
  my ($self) = @_;

  my $prefix = $$self{prefix};
  my $keyset = $$self{keyset};

  my @tokens    = ();
  my @kv        = @{ $$self{keyvals} };
  my @explicits = @{ $$self{explicits} };

  # iterate over the key-value pairs
  while (@kv) {
    my ($key, $value, $explicit) = (shift(@kv), shift(@kv), shift(@explicits));

    # write comma and key, unless in the first iteration
    push(@tokens, $$self{punct}) if $$self{punct} && @tokens;
    push(@tokens, T_SPACE)       if @tokens;
    push(@tokens, Explode($key));

    # if we explicitly specefied the value, write equals and value
    if ($explicit) {
      my $keydef = getKeyValType($prefix, $keyset, $key);
      push(@tokens, ($$self{assign} || T_SPACE)) if $value;
      push(@tokens, ($keydef ? $keydef->revert($value) : Revert($value))) if $value; } }

  # add open and close values if they were given
  unshift(@tokens, $$self{open}) if $$self{open};
  push(@tokens, $$self{close}) if $$self{close};

  # and return the list of tokens
  return @tokens; }

# expands this key-value object into a set of tokens representing
# the result of expanding it
sub set {
  my ($self) = @_;

  my $prefix = $$self{prefix};
  my $keyset = $$self{keyset};

  my @tokens    = ();
  my @kv        = @{ $$self{keyvals} };
  my @explicits = @{ $$self{explicits} };

  # iterate over the key-value pairs
  while (@kv) {
    my ($key, $value, $explicit) = (shift(@kv), shift(@kv), shift(@explicits));
    my $kprefix = getKeyValHeader($prefix, $keyset, $key);

    # we have a value given, call the appropriate macro with it
    if ($explicit) { push(@tokens, T_CS('\\' . $kprefix), T_BEGIN, $value, T_END); }

    # if it was not given explicitly, call the default macro
    else { push(@tokens, T_CS('\\' . $kprefix . '@default')); } }

  # and return the list of tokens
  return @tokens; }

# TODO: ????
sub unlist {
  my ($self) = @_;
  return $self; }

# turns this object into a string
sub toString {
  my ($self) = @_;
  my $string = '';
  my @kv     = @{ $$self{keyvals} };
  while (@kv) {
    my ($key, $value) = (shift(@kv), shift(@kv));
    $string .= ToString($$self{punct} || '') . ' ' if $string;
    $string .= $key . ToString($$self{assign} || ' ') . ToString($value); }
  return $string; }

#======================================================================
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Core::KeyVals> - support for keyvals

=head1 DESCRIPTION

Provides a parser and representation of keyval pairs
C<LaTeXML::Core::KeyVals> represents parameters handled by LaTeX's keyval package.
It extends L<LaTeXML::Common::Object>.

=head2 Declarations

=over 4

=item C<< DefKeyVal($keyset,$key,$type); >>

Defines the type of value expected for the key $key when parsed in part
of a KeyVal using C<$keyset>.  C<$type> would be something like 'any' or 'Number', but
I'm still working on this.

=back

=head2 Accessors

=over 4

=item C<< GetKeyVal($arg,$key) >>

This is useful within constructors to access the value associated with C<$key> in
the argument C<$arg>.

=item C<< GetKeyVals($arg) >>

This is useful within constructors to extract all keyvalue pairs to assign all attributes.

=back

=head2 KeyVal Methods

=over 4

=item C<< $value = $keyval->getValue($key); >>

Return the value associated with C<$key> in the C<$keyval>.

=item C<< @keyvals = $keyval->getKeyVals; >>

Return the hash reference containing the keys and values bound in the C<$keyval>.
Note that will only contain the last value for a given key, if they
were repeated.

=item C<< @keyvals = $keyval->getPairs; >>

Return the alternating keys and values bound in the C<$keyval>.
Note that this may contain multiple entries for a given key, if they
were repeated.

=item C<< $keyval->digestValues; >>

Return a new C<LaTeXML::Core::KeyVals> object with all values digested as appropriate.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
