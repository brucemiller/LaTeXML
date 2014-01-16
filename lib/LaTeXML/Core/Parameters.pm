# /=====================================================================\ #
# |  LaTeXML::Core::Parameters                                          | #
# | Representation of Parameters for Control Sequences                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Parameters;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Core::Parameter;
use base qw(Exporter LaTeXML::Object);
our @EXPORT = qw(parseParameters);

sub new {
  my ($class, @paramspecs) = @_;
  return bless [@paramspecs], $class; }

#**********************************************************************
# Parameter List & Arguments
#**********************************************************************
#**********************************************************************

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

# Parsing a parameter list spec.
sub parseParameters {
  my ($proto, $for) = @_;
  my $p      = $proto;
  my @params = ();
  while ($p) {
    # Handle possibly nested cases, such as {Number}
    if ($p =~ s/^(\{([^\}]*)\})\s*//) {
      my ($spec, $inner_spec) = ($1, $2);
      my $inner = ($inner_spec ? parseParameters($inner_spec, $for) : undef);
      push(@params, newParameter('Plain', $spec, extra => [$inner])); }
    elsif ($p =~ s/^(\[([^\]]*)\])\s*//) {    # Ditto for Optional
      my ($spec, $inner_spec) = ($1, $2);
      if ($inner_spec =~ /^Default:(.*)$/) {
        push(@params, newParameter('Optional', $spec, extra => [TokenizeInternal($1), undef])); }
      elsif ($inner_spec) {
        push(@params, newParameter('Optional', $spec, extra => [undef, parseParameters($inner_spec, $for)])); }
      else {
        push(@params, newParameter('Optional', $spec)); } }
    elsif ($p =~ s/^((\w*)(:([^\s\{\[]*))?)\s*//) {
      my ($spec, $type, $extra) = ($1, $2, $4);
      my @extra = map { TokenizeInternal($_) } split('\|', $extra || '');
      push(@params, newParameter($type, $spec, extra => [@extra])); }
    else {
      Fatal('misdefined', $for, undef, "Unrecognized parameter specification at \"$proto\""); } }
  return (@params ? LaTeXML::Core::Parameters->new(@params) : undef); }

# Create a parameter reading object for a specific type.
# If either a declared entry or a function Read<Type> accessible from LaTeXML::Package::Pool
# is defined.
sub newParameter {
  my ($type, $spec, %options) = @_;
  my $descriptor = $STATE->lookupMapping('PARAMETER_TYPES', $type);
  if (!defined $descriptor) {
    if ($type =~ /^Optional(.+)$/) {
      my $basetype = $1;
      if ($descriptor = $STATE->lookupMapping('PARAMETER_TYPES', $basetype)) { }
      elsif (my $reader = checkReaderFunction("Read$type") || checkReaderFunction("Read$basetype")) {
        $descriptor = { reader => $reader }; }
      $descriptor = { %$descriptor, optional => 1 } if $descriptor; }
    elsif ($type =~ /^Skip(.+)$/) {
      my $basetype = $1;
      if ($descriptor = $STATE->lookupMapping('PARAMETER_TYPES', $basetype)) { }
      elsif (my $reader = checkReaderFunction($type) || checkReaderFunction("Read$basetype")) {
        $descriptor = { reader => $reader }; }
      $descriptor = { %$descriptor, novalue => 1, optional => 1 } if $descriptor; }
    else {
      my $reader = checkReaderFunction("Read$type");
      $descriptor = { reader => $reader } if $reader; } }
  Fatal('misdefined', $type, undef, "Unrecognized parameter type in \"$spec\"") unless $descriptor;
  return LaTeXML::Core::Parameter->new($spec, type => $type, %{$descriptor}, %options); }

# Check whether a reader function is accessible within LaTeXML::Package::Pool
sub checkReaderFunction {
  my ($function) = @_;
  if (defined $LaTeXML::Package::Pool::{$function}) {
    local *reader = $LaTeXML::Package::Pool::{$function};
    if (defined &reader) {
      return \&reader; } } }

#======================================================================

sub getParameters {
  my ($self) = @_;
  return @$self; }

sub stringify {
  my ($self) = @_;
  my $string = '';
  foreach my $parameter (@$self) {
    my $s = $parameter->stringify;
    $string .= ' ' if ($string =~ /\w$/) && ($s =~ /^\w/);
    $string .= $s; }
  return $string; }

sub equals {
  my ($self, $other) = @_;
  return (defined $other)
    && ((ref $self) eq (ref $other)) && ($self->stringify eq $other->stringify); }

sub getNumArgs {
  my ($self) = @_;
  my $n = 0;
  foreach my $parameter (@$self) {
    $n++ unless $$parameter{novalue}; }
  return $n; }

sub revertArguments {
  my ($self, @args) = @_;
  my @tokens = ();
  foreach my $parameter (@$self) {
    next if $$parameter{novalue};
    my $arg = shift(@args);
    if (my $retoker = $$parameter{reversion}) {
      push(@tokens, &$retoker($arg, @{ $$parameter{extra} || [] })); }
    else {
      push(@tokens, Revert($arg)) if ref $arg; } }
  return @tokens; }

sub readArguments {
  my ($self, $gullet, $fordefn) = @_;
  my @args = ();
  foreach my $parameter (@$self) {
    #    my $value = &{$$parameter{reader}}($gullet,@{$$parameter{extra}||[]});
    my $value = $parameter->read($gullet);
    if ((!defined $value) && !$$parameter{optional}) {
      Error('expected', $parameter, $gullet,
        "Missing argument " . ToString($parameter) . " for " . ToString($fordefn),
        $gullet->showUnexpected); }
    push(@args, $value) unless $$parameter{novalue}; }
  return @args; }

sub readArgumentsAndDigest {
  my ($self, $stomach, $fordefn) = @_;
  my @args   = ();
  my $gullet = $stomach->getGullet;
  foreach my $parameter (@$self) {
    #    my $value = &{$$parameter{reader}}($gullet,@{$$parameter{extra}||[]});
    my $value = $parameter->read($gullet);
    if ((!defined $value) && !$$parameter{optional}) {
      Error('expected', $parameter, $stomach,
        "Missing argument " . Stringify($parameter) . " for " . Stringify($fordefn),
        $gullet->showUnexpected); }
    if (!$$parameter{novalue}) {
      StartSemiverbatim() if $$parameter{semiverbatim};    # Corner case?
      $value = $value->beDigested($stomach) if (ref $value) && !$$parameter{undigested};
      EndSemiverbatim() if $$parameter{semiverbatim};      # Corner case?
      push(@args, $value); } }
  return @args; }

sub reparseArgument {
  my ($self, $gullet, $tokens) = @_;
  if (defined $tokens) {
    return $gullet->readingFromMouth(LaTeXML::Core::Mouth->new(), sub {    # start with empty mouth
        my ($gulletx) = @_;
        $gulletx->unread($tokens);                                         # but put back tokens to be read
        my @values = $self->readArguments($gulletx);
        $gulletx->skipSpaces;
        return @values; }); }
  else {
    return (); } }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Parameters> - formal parameters.

=head1 DESCRIPTION

Provides a representation for the formal parameters of L<LaTeXML::Core::Definition>s:

=over 4

=head2 METHODS

=over 4

=item C<< $parameters = parseParameters($prototype,$for); >>

Parses a string for a sequence of parameter specifications.
Each specification should be of the form 

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

=item C<< @parameters = $parameters->getParameters; >>

Return the list of C<LaTeXML::Core::Parameter> contained in C<$parameters>.

=item C<< @tokens = $parameters->revertArguments(@args); >>

Return a list of L<LaTeXML::Core::Token> that would represent the arguments
such that they can be parsed by the Gullet.

=item C<< @args = $parameters->readArguments($gullet,$fordefn); >>

Read the arguments according to this C<$parameters> from the C<$gullet>.
This takes into account any special forms of arguments, such as optional,
delimited, etc.

=item C<< @args = $parameters->readArgumentsAndDigest($stomach,$fordefn); >>

Reads and digests the arguments according to this C<$parameters>, in sequence.
this method is used by Constructors.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
