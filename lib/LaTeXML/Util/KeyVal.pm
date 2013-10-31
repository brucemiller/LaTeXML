# -*- CPERL -*-
# /=====================================================================\ #
# |  KeyVal                                                             | #
# | Support for key-value pairs for LaTeXML                             | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Util::KeyVal;
use strict;
use LaTeXML::Package;

our @ISA    = qw(Exporter);
our @EXPORT = (qw(&ReadRequiredKeyVals &ReadOptionalKeyVals
    &DefKeyVal
    &KeyVal &KeyVals));

#======================================================================
# New Readers for required and optional KeyVal sets.
# These can also be used as parameter types.
# They create a new data KeyVals object

sub ReadRequiredKeyVals {
  my ($gullet, $keyset) = @_;
  if ($gullet->ifNext(T_BEGIN)) {
    (readKeyVals($gullet, $keyset, T_END)); }
  else {
    Error('expected', '{', $gullet, "Missing keyval arguments");
    (LaTeXML::KeyVals->new($keyset, T_BEGIN, T_END,)); } }

sub ReadOptionalKeyVals {
  my ($gullet, $keyset) = @_;
  ($gullet->ifNext(T_OTHER('[')) ? (readKeyVals($gullet, $keyset, T_OTHER(']'))) : undef); }

#======================================================================
# This new declaration allows you to define the type associated with
# the value for specific keys.
sub DefKeyVal {
  my ($keyset, $key, $type, $default) = @_;
  my $paramlist = LaTeXML::Package::parseParameters($type, "KeyVal $key in set $keyset");
  AssignValue('KEYVAL@' . $keyset . '@' . $key              => $paramlist);
  AssignValue('KEYVAL@' . $keyset . '@' . $key . '@default' => Tokenize($default))
    if defined $default;
  return; }

#======================================================================
# These functions allow convenient access to KeyVal objects within constructors.

# Access the value associated with a given key.
# Can use in constructor: eg. <foo attrib='&KeyVal(#1,'key')'>
sub KeyVal {
  my ($keyval, $key) = @_;
  (defined $keyval) && $keyval->getValue($key); }

# Access the entire hash.
# Can use in constructor: <foo %&KeyVals(#1)/>
sub KeyVals {
  my ($keyval) = @_;
  (defined $keyval ? $keyval->getKeyVals : {}); }

#======================================================================
# A KeyVal argument MUST be delimited by either braces or brackets (if optional)
# This method reads the keyval pairs INCLUDING the delimiters, (rather than parsing
# after the fact), since some values may have special catcode needs.
our $T_EQ    = T_OTHER('=');
our $T_COMMA = T_OTHER(',');

sub readKeyVals {
  my ($gullet, $keyset, $close) = @_;
  my $startloc = $gullet->getLocator();
  my $open     = $gullet->readToken;
  $keyset = ($keyset ? ToString($keyset) : '_anonymous_');
  my @kv = ();
  while (1) {
    $gullet->skipSpaces;
    # Read the keyword.
    my ($ktoks, $delim) = $gullet->readUntil($T_EQ, $T_COMMA, $close);
    Error('expected', $close, $gullet,
      "Fell off end expecting " . Stringify($close) . " while reading KeyVal key",
      "key started at $startloc")
      unless $delim;
    my $key = ToString($ktoks); $key =~ s/\s//g;
    if ($key) {
      my $keydef = LookupValue('KEYVAL@' . $keyset . '@' . $key);
      my $value;
      if ($delim->equals($T_EQ)) {    # Got =, so read the value
                                      # WHOA!!! Secret knowledge!!!
        my $type = ($keydef && (scalar(@$keydef) == 1) && $keydef->[0]->{type}) || 'Plain';
        my $typedef = $LaTeXML::Parameters::PARAMETER_TABLE{$type};
        StartSemiverbatim() if $typedef && $$typedef{semiverbatim};

        ## ($value,$delim)=$gullet->readUntil($T_COMMA,$close);
        # This is the core of $gullet->readUntil, but preserves braces needed by rare key types
        my ($tok, @toks) = ();
        while ((!defined($delim = $gullet->readMatch($T_COMMA, $close)))
          && (defined($tok = $gullet->readToken()))) {    # Copy next token to args
          push(@toks, $tok,
            ($tok->getCatcode == CC_BEGIN ? ($gullet->readBalanced->unlist, T_END) : ())); }
        $value = Tokens(@toks);
        if (($type eq 'Plain') || ($typedef && $$typedef{undigested})) { }    # Fine as is.
        elsif ($type eq 'Semiverbatim') {                                     # Needs neutralization
          $value = $value->neutralize; }
        else {
          ($value) = $keydef->reparseArgument($gullet, $value) }
        EndSemiverbatim() if $typedef && $$typedef{semiverbatim};
      }
      else {                                                                  # Else, get default value.
        $value = LookupValue('KEYVAL@' . $keyset . '@' . $key . '@default'); }
      push(@kv, $key);
      push(@kv, $value); }
    Error('expected', $close, $gullet,
      "Fell off end expecting " . Stringify($close) . " while reading KeyVal value",
      "key started at $startloc")
      unless $delim;
    last if $delim->equals($close); }
  LaTeXML::KeyVals->new($keyset, $open, $close, @kv); }

#**********************************************************************
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

package LaTeXML::KeyVals;
use LaTeXML::Global;
use LaTeXML::Package;
use base qw(LaTeXML::Object);

# Spec??
sub new {
  my ($class, $keyset, $open, $close, @pairs) = @_;
  my %hash = ();
  my @pp   = @pairs;
  while (@pp) {
    my ($k, $v) = (shift(@pp), shift(@pp));
    if (!defined $hash{$k}) { $hash{$k} = $v; }
    # Hmm, accumulate an ARRAY if multiple values for given key.
    # This is unlikely to be what the caller expects!! But what?
    elsif (ref $hash{$k} eq 'ARRAY') { push(@{ $hash{$k} }, $v); }
    else { $hash{$k} = [$hash{$k}, $v]; } }
  bless { keyset => $keyset, open => $open, close => $close, keyvals => [@pairs], hash => {%hash} }, $class; }

sub getValue {
  my ($self, $key) = @_;
  $$self{hash}{$key}; }

sub setValue {
  my ($self, $key, $value) = @_;
  if (defined $value) {
    $$self{hash}{$key} = $value; }
  else {
    delete $$self{hash}{$key}; } }

sub getPairs {
  my ($self) = @_;
  @{ $$self{keyvals} }; }

sub getKeyVals {
  my ($self) = @_;
  $$self{hash}; }

sub getHash {
  my ($self) = @_;
  map(($_ => ToString($$self{hash}{$_})), keys %{ $$self{hash} }); }

sub beDigested {
  my ($self, $stomach) = @_;
  my $keyset = $$self{keyset};
  my @kv     = @{ $$self{keyvals} };
  my @dkv    = ();
  while (@kv) {
    my ($key, $value) = (shift(@kv), shift(@kv));
    my $keydef = LookupValue('KEYVAL@' . $keyset . '@' . $key);
    my $dodigest = (ref $value) && (!$keydef || !$$keydef[0]{undigested});
    # Yuck
    my $type     = ($keydef && (scalar(@$keydef) == 1) && $keydef->[0]->{type}) || 'Plain';
    my $typedef  = $LaTeXML::Parameters::PARAMETER_TABLE{$type};
    my $semiverb = $dodigest && $typedef && $$typedef{semiverbatim};
    StartSemiverbatim() if $semiverb;
    push(@dkv, $key, ($dodigest ? $value->beDigested($stomach) : $value));
    EndSemiverbatim() if $semiverb;
  }
  (ref $self)->new($$self{keyset}, $$self{open}, $$self{close}, @dkv); }

sub revert {
  my ($self) = @_;
  my $keyset = $$self{keyset};
  my @tokens = ();
  my @kv     = @{ $$self{keyvals} };
  while (@kv) {
    my ($key, $value) = (shift(@kv), shift(@kv));
    my $keydef = LookupValue('KEYVAL@' . $keyset . '@' . $key);
    push(@tokens, T_OTHER(','), T_SPACE) if @tokens;
    push(@tokens, Explode($key));
    push(@tokens, T_OTHER('='),
      ($keydef ? $keydef->revertArguments($value) : Revert($value))) if $value; }
  unshift(@tokens, $$self{open}) if $$self{open};
  push(@tokens, $$self{close}) if $$self{close};
  @tokens; }

sub unlist { $_[0]; }    # ????

sub toString {
  my ($self) = @_;
  my $string = '';
  my @kv     = @{ $$self{keyvals} };
  while (@kv) {
    my ($key, $value) = (shift(@kv), shift(@kv));
    $string .= ', ' if $string;
    $string .= $key . '=' . ToString($value); }
  $string; }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Util::KeyVal> - support for keyvals

=head1 DESCRIPTION

Provides a parser and representation of keyval pairs
C<LaTeXML::KeyVal> represents parameters handled by LaTeX's keyval package.

=head2 Declarations

=over 4

=item C<< DefKeyVal($keyset,$key,$type); >>

Defines the type of value expected for the key $key when parsed in part
of a KeyVal using C<$keyset>.  C<$type> would be something like 'any' or 'Number', but
I'm still working on this.

=back

=head2 Accessors

=over 4

=item C<< KeyVal($arg,$key) >>

This is useful within constructors to access the value associated with C<$key> in
the argument C<$arg>.

=item C<< KeyVals($arg) >>

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

Return a new C<LaTeXML::KeyVals> object with all values digested as appropriate.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
