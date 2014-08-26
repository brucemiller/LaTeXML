# -*- CPERL -*-
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

#======================================================================
# A KeyVal argument MUST be delimited by either braces or brackets (if optional)
# This method reads the keyval pairs INCLUDING the delimiters, (rather than parsing
# after the fact), since some values may have special catcode needs.
##my $T_EQ    = T_OTHER('=');    # [CONSTANT]
##my $T_COMMA = T_OTHER(',');    # [CONSTANT]

sub readKeyVals {
  my ($gullet, $keyset, $close) = @_;
  my $startloc = $gullet->getLocator();
  my $open     = $gullet->readToken;
  my $assign   = T_OTHER('=');
  my $punct    = T_OTHER(',');

  $keyset = ($keyset ? ToString($keyset) : '_anonymous_');
  my @kv = ();
  while (1) {
    $gullet->skipSpaces;
    # Read the keyword.
    my ($ktoks, $delim) = $gullet->readUntil($assign, $punct, $close);
    Error('expected', $close, $gullet,
      "Fell off end expecting " . Stringify($close) . " while reading KeyVal key",
      "key started at $startloc")
      unless $delim;
    my $key = ToString($ktoks); $key =~ s/\s//g;
    if ($key) {
      my $keydef = $STATE->lookupValue('KEYVAL@' . $keyset . '@' . $key);
      my $value;
      if ($delim->equals($assign)) {    # Got =, so read the value
                                        # WHOA!!! Secret knowledge!!!
        my $type = ($keydef && (scalar(@$keydef) == 1) && $$keydef[0]{type}) || 'Plain';
        my $typedef = $STATE->lookupMapping('PARAMETER_TYPES', $type);
        $STATE->beginSemiverbatim() if $typedef && $$typedef{semiverbatim};

        ## ($value,$delim)=$gullet->readUntil($punct,$close);
        # This is the core of $gullet->readUntil, but preserves braces needed by rare key types
        my ($tok, @toks) = ();
        while ((!defined($delim = $gullet->readMatch($punct, $close)))
          && (defined($tok = $gullet->readToken()))) {    # Copy next token to args
          push(@toks, $tok,
            ($tok->getCatcode == CC_BEGIN ? ($gullet->readBalanced->unlist, T_END) : ())); }
        $value = Tokens(@toks);
        if (($type eq 'Plain') || ($typedef && $$typedef{undigested})) { }    # Fine as is.
        elsif ($type eq 'Semiverbatim') {                                     # Needs neutralization
          $value = $value->neutralize; }
        else {
          ($value) = $keydef->reparseArgument($gullet, $value) }
        $STATE->endSemiverbatim() if $typedef && $$typedef{semiverbatim};
      }
      else {                                                                  # Else, get default value.
        $value = $STATE->lookupValue('KEYVAL@' . $keyset . '@' . $key . '@default'); }
      push(@kv, $key);
      push(@kv, $value); }
    Error('expected', $close, $gullet,
      "Fell off end expecting " . Stringify($close) . " while reading KeyVal value",
      "key started at $startloc")
      unless $delim;
    last if $delim->equals($close); }
  return LaTeXML::Core::KeyVals->new($keyset, [@kv],
    open  => $open,  close  => $close,
    punct => $punct, assign => $assign); }

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
  my ($class, $keyset, $pairs, %options) = @_;
  $keyset = ($keyset ? ToString($keyset) : '_anonymous_');
  my %hash = ();
  my @pp   = @$pairs;
  while (@pp) {
    my ($k, $v) = (shift(@pp), shift(@pp));
    if (!defined $hash{$k}) { $hash{$k} = $v; }
    # Hmm, accumulate an ARRAY if multiple values for given key.
    # This is unlikely to be what the caller expects!! But what?
    elsif (ref $hash{$k} eq 'ARRAY') { push(@{ $hash{$k} }, $v); }
    else { $hash{$k} = [$hash{$k}, $v]; } }
  return bless {
    keyset => $keyset, keyvals => $pairs, hash => {%hash},
    open  => $options{open},  close  => $options{close},
    punct => $options{punct}, assign => $options{assign} },
    $class; }

sub getValue {
  my ($self, $key) = @_;
  return $$self{hash}{$key}; }

sub setValue {
  my ($self, $key, $value) = @_;
  if (defined $value) {
    $$self{hash}{$key} = $value; }
  else {
    delete $$self{hash}{$key}; }
  return; }

sub getPairs {
  my ($self) = @_;
  return @{ $$self{keyvals} }; }

sub getKeyVals {
  my ($self) = @_;
  return $$self{hash}; }

sub getHash {
  my ($self) = @_;
  return map { ($_ => ToString($$self{hash}{$_})) } keys %{ $$self{hash} }; }

sub hasKey {
  my ($self, $key) = @_;
  return exists $$self{hash}{$key}; }

sub beDigested {
  my ($self, $stomach) = @_;
  my $keyset = $$self{keyset};
  my @kv     = @{ $$self{keyvals} };
  my @dkv    = ();
  while (@kv) {
    my ($key, $value) = (shift(@kv), shift(@kv));
    my $keydef = $STATE->lookupValue('KEYVAL@' . $keyset . '@' . $key);
    my $dodigest = (ref $value) && (!$keydef || !$$keydef[0]{undigested});
    # Yuck
    my $type = ($keydef && (scalar(@$keydef) == 1) && $$keydef[0]{type}) || 'Plain';
    my $typedef = $STATE->lookupMapping('PARAMETER_TYPES', $type);
    my $semiverb = $dodigest && $typedef && $$typedef{semiverbatim};
    $STATE->beginSemiverbatim() if $semiverb;
    push(@dkv, $key, ($dodigest ? $value->beDigested($stomach) : $value));
    $STATE->endSemiverbatim() if $semiverb;
  }
  return LaTeXML::Core::KeyVals->new($keyset, [@dkv],
    open  => $$self{open},  close  => $$self{close},
    punct => $$self{punct}, assign => $$self{assign}); }

sub revert {
  my ($self) = @_;
  my $keyset = $$self{keyset};
  my @tokens = ();
  my @kv     = @{ $$self{keyvals} };
  while (@kv) {
    my ($key, $value) = (shift(@kv), shift(@kv));
    my $keydef = $STATE->lookupValue('KEYVAL@' . $keyset . '@' . $key);
    push(@tokens, $$self{punct}) if $$self{punct} && @tokens;
    push(@tokens, T_SPACE)       if @tokens;
    push(@tokens, Explode($key));
    push(@tokens, ($$self{assign} || T_SPACE)) if $value;
    push(@tokens, ($keydef ? $keydef->revertArguments($value) : Revert($value))) if $value; }
  unshift(@tokens, $$self{open}) if $$self{open};
  push(@tokens, $$self{close}) if $$self{close};
  return @tokens; }

sub unlist {
  my ($self) = @_;
  return $self; }    # ????

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
