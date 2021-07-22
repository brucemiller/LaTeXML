# /=====================================================================\ #
# |  LaTeXML::Core::KeyVal                                              | #
# | Key-Value Definitions in LaTeXML                                     | #
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
  qw(&DefKeyVal &DisableKeyVal &HasKeyVal),
  # Semi-internals
  qw(&keyval_qname &keyval_get));

#======================================================================
# Exposed Methods
#======================================================================

# Defines a new key-value pair
sub DefKeyVal {
  my ($keyset, $key, $type, $default, %options) = @_;
  # extract the prefix
  my $prefix = $options{prefix} || 'KV';
  delete $options{prefix};
  define($prefix, $keyset, $key, $type, $default, %options);
  return; }

# check if a key-value pair is defined
sub HasKeyVal {
  my ($prefix, $keyset, $key) = @_;
  my $qname = keyval_qname($prefix, $keyset, $key);
  return $STATE->lookupValue('KEYVAL@defined@' . $qname)
    || (defined $STATE->lookupMeaning(T_CS('\\' . $qname))); }

# disable a given key-val
sub DisableKeyVal {
  my ($prefix, $keyset, $key) = @_;
  my $qname = keyval_qname($prefix, $keyset, $key);
  keyval_set($qname, 'disabled', 1);
  # disable the key
  defineOrdinary($qname, sub {
      LaTeXML::Package::Tokenize("\\PackageWarning{keyval}{`" . $key . "' has been disabled. }");
  });
  return; }

# useful (only) for LaTeXML::Core::KeyVals
sub keyval_qname {
  my ($prefix, $keyset, $key) = @_;
  return ($prefix || 'KV') . '@' . $keyset . '@' . $key; }

sub keyval_get {
  my ($qname, $prop) = @_;
  return $STATE->lookupValue('KEYVAL@' . $prop . '@' . $qname); }

sub keyval_set {
  my ($qname, $prop, $value) = @_;
  return $STATE->assignValue('KEYVAL@' . $prop . '@' . $qname, $value); }

#======================================================================
# Key Definition
#======================================================================

# (re-)define this key
sub define {
  my ($prefix, $keyset, $key, $type, $default, %options) = @_;
  my $qname = keyval_qname($prefix, $keyset, $key);

  # define that the key exists and is not disabled
  keyval_set($qname, exists   => 1);
  keyval_set($qname, disabled => 0);
  # set the type
  my $paramlist = LaTeXML::Package::parseParameters($type || "{}",
    "KeyVal $key in set $keyset with prefix $prefix");
  if (scalar(@$paramlist) != 1) {
    Warn('unexpected', 'keyval', $key,
      "Too many parameters in keyval $key (in set $keyset with prefix $prefix)"
        . "taking only first", $paramlist); }
  keyval_set($qname, type => $$paramlist[0]);
  # set the default
  # Question: Why was $default converted ToString ???
  if (defined $default) {
    my @tdefault = LaTeXML::Package::Tokenize($default);
    keyval_set($qname, default => Tokens(@tdefault));
    LaTeXML::Package::DefMacroI('\\' . $qname . '@default', undef,
      Tokens(T_CS('\\' . $qname), T_BEGIN, @tdefault, T_END)); }

  # figure out the kind of key-val parameter we are defining
  my $kind = $options{kind} || 'ordinary';
  if ($kind eq 'ordinary') {
    defineOrdinary($qname, $options{code}); }
  elsif ($kind eq 'command') {
    my $macroname = ($options{macroprefix} ? $options{macroprefix} . $key : "cmd" . $qname);
    defineCommand($qname, $options{code}, $macroname); }
  elsif ($kind eq 'choice') {
    defineChoice($qname, $options{code}, $options{mismatch},
      $options{choices}, ($options{normalize} || 0), $options{bin}); }
  elsif ($kind eq 'boolean') {
    my $macroname = ($options{macroprefix} ? $options{macroprefix} . $key : $qname);
    defineBoolean($qname, $options{code}, $options{mismatch}, $macroname); }
  else {
    Warn('unknown', undef, "Unknown KeyVals kind $kind",
      "should be one of 'ordinary', 'command', 'choice', 'boolean'. "); }
  return; }

sub defineOrdinary {
  my ($qname, $code) = @_;
  LaTeXML::Package::DefMacroI('\\' . $qname, '{}', (defined($code) ? $code : ''));
  return; }

sub defineCommand {
  my ($qname, $code, $macroname) = @_;
  LaTeXML::Package::DefMacroI('\\' . $qname, '{}', sub {
      my ($gullet, $value) = @_;
      my $orig = '\\ltxml@orig@' . $qname;
      LaTeXML::Package::DefMacroI($orig, '{}', $code);
      Tokens(T_CS("\\def"), T_CS('\\' . $macroname), T_BEGIN, $value, T_END,
        T_CS($orig), T_BEGIN, T_PARAM, $value, T_END);    # $value !?!??! Is it a number 1--9 ???
  });
  return; }

sub defineChoice {
  my ($qname, $code, $mismatch, $choices, $normalize, $bin) = @_;
  my $norm = ($normalize ? sub { lc $_[0]; } : sub { $_[0]; });
  my ($varmacro, $idxmacro) = defined($bin) ? $bin->unlist : (undef, undef);
  LaTeXML::Package::DefMacroI('\\' . $qname, '{}', sub {
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
      my $orig   = '\\ltxml@orig@' . $qname;
      # if we have chosen a valid index, run $code
      if ($valid) {
        if (defined($code)) {
          LaTeXML::Package::DefMacroI($orig, '{}', $code);
          push(@tokens, T_CS($orig), T_BEGIN, $value, T_END); } }
      # else run $mismatch
      elsif (defined($mismatch)) {
        LaTeXML::Package::DefMacroI($orig, '{}', $mismatch);
        push(@tokens, T_CS($orig), T_BEGIN, $value, T_END); }
      @tokens; });
  return; }

sub defineBoolean {
  my ($qname, $code, $mismatch, $macroname) = @_;
  LaTeXML::Package::DefConditional(T_CS("\\if$macroname"));    # We might need to $scope here
  defineChoice($qname, sub {
      my ($gullet, $value) = @_;
      # set the value to true (if needed)
      my @tokens = ();
      push(@tokens, T_CS('\\' . $macroname . (((lc ToString($value)) eq 'true') ? 'true' : 'false')));
      # Store and invoke the original macro if needed
      if ($code) {
        my $orig = '\\ltxml@@rig@' . $qname;
        LaTeXML::Package::DefMacroI($orig, '{}', $code);
        push(@tokens, T_CS($orig), T_BEGIN, $value, T_END); }
      @tokens; },
    $mismatch, [("true", "false")], 1);
  return; }

#======================================================================
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Core::KeyVal> - Key-Value Definitions in LaTeXML

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

=head2 KeyVal Key Definition

=over 4

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

=back

=head1 AUTHOR

Tom Wiesing <tom.wiesing@gmail.com>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
