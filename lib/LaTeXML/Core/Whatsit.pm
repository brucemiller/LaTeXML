# /=====================================================================\ #
# |  LaTeXML::Core::Whatsit                                             | #
# | Digested objects produced in the Stomach                            | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
#**********************************************************************
# LaTeXML Whatsit.
#  Some arbitrary object, possibly with arguments.
# Particularly as an intermediate representation for invocations of control
# sequences that do NOT get expanded or processed, but are taken to represent
# some semantic something or other.
# These get preserved in the expanded/processed token stream to be
# converted into XML objects in the document.
#**********************************************************************
package LaTeXML::Core::Whatsit;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Locator;
use LaTeXML::Common::Error;
use LaTeXML::Core::Token;
use LaTeXML::Core::Tokens;
use LaTeXML::Core::Definition::Expandable;
use LaTeXML::Common::Dimension;
use List::Util qw(min max);
use LaTeXML::Core::List;
use base qw(LaTeXML::Core::Box);

# Specially recognized (some required?) properties:
#  font    : The font object
#  locator : a locator object, where in the source this whatsit was created
#  isMath  : whether this is a math object
#  id
#  body
#  trailer
sub new {
  my ($class, $defn, $args, %properties) = @_;
  return bless { definition => $defn, args => $args || [], properties => {%properties} }, $class; }

sub getDefinition {
  my ($self) = @_;
  return $$self{definition}; }

sub isMath {
  my ($self) = @_;
  return $$self{properties}{isMath}; }

sub getProperty {
  my ($self, $key) = @_;
  return $$self{properties}{$key}; }

sub getArg {
  my ($self, $n) = @_;
  return $$self{args}[$n - 1]; }

sub getArgs {
  my ($self) = @_;
  return @{ $$self{args} }; }

sub setArgs {
  my ($self, @args) = @_;
  $$self{args} = [@args];
  return; }

sub getBody {
  my ($self) = @_;
  return $$self{properties}{body}; }

sub setBody {
  my ($self, @body) = @_;
  my $trailer = pop(@body);
  $$self{properties}{body} = List(@body);
  $$self{properties}{body}->setProperty(mode => 'math') if $self->isMath;
  $$self{properties}{trailer} = $trailer;
  # And copy any otherwise undefined properties from the trailer
  if ($trailer) {
    $$self{properties}{locator} = LaTeXML::Common::Locator->newRange($self->getLocator, $trailer->getLocator);
    my %trailerhash = $trailer->getProperties;
    foreach my $prop (keys %trailerhash) {
      $$self{properties}{$prop} = $trailer->getProperty($prop) unless defined $$self{properties}{$prop}; } }
  return; }

sub getTrailer {
  my ($self) = @_;
  return $$self{properties}{trailer}; }

# So a Whatsit can stand in for a List
sub unlist {
  my ($self) = @_;
  return ($self); }

sub revert {
  my ($self) = @_;
  # WARNING: Forbidden knowledge?
  # (2) caching the reversion (which is a big performance boost)
  my $defn = $self->getDefinition;
  my $alignment;
  if (my $saved = ($LaTeXML::DUAL_BRANCH
      ? $$self{dual_reversion}{$LaTeXML::DUAL_BRANCH}
      : $$self{reversion})) {
    return $saved->unlist; }
##  elsif($alignment = $$self{properties}{alignment}) {
  elsif ((!$defn->getReversionSpec)
    && ($alignment = $$self{properties}{alignment})) {
    return $alignment->revert; }
  else {
    my $props = $$self{properties};
    # Find the appropriate reversion spec;
    # content_reversion or presntation_reversion if on dual branch
    # or (general) reversion, or the reversion from the definition
    my $spec   = $$props{'reversion'} || $defn->getReversionSpec;
    my @tokens = ();
    if ((defined $spec) && (ref $spec eq 'CODE')) {    # If handled by CODE, call it
      @tokens = $self->substituteParameters(Tokens(&$spec($self, $self->getArgs))); }
    else {
      if (defined $spec) {
        @tokens = $self->substituteParameters($spec)
          if $spec ne ''; }
      else {
        my $alias = $defn->getAlias;
        if (defined $alias) {
          push(@tokens, (ref $alias ? $alias : T_CS($alias))) if $alias ne ''; }
        else {
          push(@tokens, $defn->getCS); }
        if (my $parameters = $defn->getParameters) {
          push(@tokens, $parameters->revertArguments($self->getArgs)); } }
      if (defined(my $body = $self->getBody)) {
###      if (defined(my $body = $self->getBody || $self->getProperty('alignment'))) {
        push(@tokens, Revert($body));
        if (defined(my $trailer = $self->getTrailer)) {
          push(@tokens, Revert($trailer)); } } }
    # Now cache it, in case it's needed again
    if ($LaTeXML::DUAL_BRANCH) {
      $$self{dual_reversion}{$LaTeXML::DUAL_BRANCH} = Tokens(@tokens); }
    else {
      $$self{reversion} = Tokens(@tokens); }
    return @tokens; } }

# Like Tokens-substituteParameters, but substitutes in the Whatsit's arguments OR properties!
# #<digit> is the standard TeX positional argument
# # followed by a T_OTHER(propname) specifies the property propname!!
sub substituteParameters {
  my ($self, $spec) = @_;
# TODO: This is kind of unfortunate -- I am not sure what are the reasonable "entryways" into the Whatsit substituteParameters. For Expandable we now have guarantees that "#,i" has been mapped into a single T_ARG(#i), but not here.
# so for now run on each call?
  my @in     = $spec->unlist;
  my @args   = $self->getArgs;
  my $props  = $$self{properties};
  my @result = ();
  while (@in) {
    my $token = shift(@in);
    if ($$token[1] != CC_ARG) {    # Non '#'; copy it
      push(@result, $token); }
    else {
      my $s = $$token[0];
      my $n = ord($s) - ord('0') - 1;
      if (my $arg = (($n >= 0) && ($n < 10) ? $args[$n] : $$props{$s})) {
        push(@result, Revert($arg)); } } }
  return @result; }

sub toString {
  my ($self) = @_;
  return ToString(Tokens($self->revert)); }    # What else??

sub getString {
  my ($self) = @_;
  return $self->toString; }                    # Ditto?

# Methods for overloaded operators
sub stringify {
  no warnings 'recursion';
  my ($self) = @_;
  my $hasbody = defined $$self{properties}{body};
  return "Whatsit[" . join(',', $self->getDefinition->getCS->getCSName,
    map { Stringify($_) }
      $self->getArgs,
    (defined $$self{properties}{body}
      ? ($$self{properties}{body}, $$self{properties}{trailer})
      : ()))
    . "]"; }

sub equals {
  my ($a, $b) = @_;
  return 0 unless (defined $b) && ((ref $a) eq (ref $b));
  return 0 unless $$a{definition} eq $$b{definition};    # I think we want IDENTITY here, not ->equals
  my @a = @{ $$a{args} }; push(@a, $$a{properties}{body}) if $$a{properties}{body};
  my @b = @{ $$b{args} }; push(@b, $$b{properties}{body}) if $$b{properties}{body};
  while (@a && @b && ($a[0]->equals($b[0]))) {
    shift(@a); shift(@b); }
  return !(@a || @b); }

sub beAbsorbed {
  no warnings 'recursion';
  my ($self, $document) = @_;
  # Significant time is consumed here, and associated with a specific CS,
  # so we should be profiling as well!
  # Hopefully the csname is the same that was charged in the digestioned phase!

  # Guard via the absorb limit to avoid infinite loops
  if ($LaTeXML::ABSORB_LIMIT) {
    my $absorb_counter = $STATE->lookupValue('absorb_count') || 0;
    $STATE->assignValue(absorb_count => ++$absorb_counter, 'global');
    if ($absorb_counter > $LaTeXML::ABSORB_LIMIT) {
      Fatal('timeout', 'absorb_limit', $self,
        "Whatsit absorb limit of $LaTeXML::ABSORB_LIMIT exceeded, infinite loop?"); } }

  my $defn     = $self->getDefinition;
  my $profiled = (($STATE->lookupValue('TRACING') || 0) & TRACE_PROFILE) && $defn->getCS;
  LaTeXML::Core::Definition::startProfiling($profiled, 'absorb') if $profiled;
  my @result = $defn->doAbsorbtion($document, $self);
  LaTeXML::Core::Definition::stopProfiling($profiled, 'absorb') if $profiled;
  return @result; }

# Similar to ->revert, but converts to pure string for use in an attribute value
sub toAttribute {
  my ($self) = @_;
  my $props  = $$self{properties};
  my $defn   = $self->getDefinition;
  my $spec   = $$props{toAttribute} || $$defn{toAttribute};
  if (!defined $spec) {
    return $self->toString; }    # Default
  elsif (ref $spec eq 'CODE') {    # If handled by CODE, call it
    $spec = &$spec($self, $self->getArgs); }
  # Now, similar to substituteParameters, but creating a string.
  $spec =~ s/#(#|[1-9]|\w+)/ toAttribute_aux($self,$1)/eg;
  return $spec; }

sub toAttribute_aux {
  my ($self, $code) = @_;
  my $value;
  if    ($code eq '#') { return $code; }
  elsif ((ord($code) > ord('0')) && (ord($code) <= ord('9'))) {
    $value = $self->getArg(ord($code) - ord('0')); }
  else {
    $value = $self->getProperty($code); }
  $value = $value->toAttribute if (defined $value) && (ref $value);
  return $value; }

# See discussion in Box.pm
sub computeSize {
  my ($self, %options) = @_;
  # Use #body, if any, else ALL args !?!?!
  my $defn  = $self->getDefinition;
  my $props = $self->getPropertiesRef;
  my $sizer = $defn->getSizer;
  if (ref $sizer) {    # If sizer is a function, call it
    return &$sizer($self); }
  else {               # Else collect up args/body/boxes which represent this thing
    my @boxes = ();
    if (!defined $sizer) {    # Nothing specified? use #body if any, else sum all box args
      @boxes = ($$props{body}
        ? ($$props{body})
        : (map { ((ref $_) && ($_->isaBox) ? $_->unlist : ()) } @{ $$self{args} })); }
    elsif (($sizer eq '0') || ($sizer eq '')) { }   # 0 size!
    elsif ($sizer =~ /^(#\w+)*$/) {                 # Else if of form '#digit' or '#prop', combine sizes
      while ($sizer =~ s/^#(\w+)//) {
        my $arg = $1;
        push(@boxes, ($arg =~ /^\d+$/ ? $self->getArg($arg) : $$props{$arg})); }
      # Special case: If only a single object to be sized and it is a List, unlist it.
      # This is so that whatsit's layout properties will be applied to the sequence
      if ((scalar(@boxes) == 1) && ((ref $boxes[0]) eq 'LaTeXML::Core::List')) {
        @boxes = $boxes[0]->unlist; } }
    else {
      push(@boxes, $sizer); }
    no warnings 'recursion';
    return $$props{font}->computeBoxesSize([@boxes], %options); } }

#======================================================================
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Core::Whatsit> - Representations of digested objects.

=head1 DESCRIPTION

represents a digested object that can generate arbitrary elements in the XML Document.
It extends L<LaTeXML::Core::Box>.

=head2 METHODS

Note that the font is stored in the data properties under 'font'.

=over 4

=item C<< $defn = $whatsit->getDefinition; >>

Returns the L<LaTeXML::Core::Definition> responsible for creating C<$whatsit>.

=item C<< $value = $whatsit->getProperty($key); >>

Returns the value associated with C<$key> in the C<$whatsit>'s property list.

=item C<< $whatsit->setProperty($key,$value); >>

Sets the C<$value> associated with the C<$key> in the C<$whatsit>'s property list.

=item C<< $props = $whatsit->getProperties(); >>

Returns the hash of properties stored on this Whatsit.
(Note that this hash is modifiable).

=item C<< $props = $whatsit->setProperties(%keysvalues); >>

Sets several properties, like setProperty.

=item C<< $list = $whatsit->getArg($n); >>

Returns the C<$n>-th argument (starting from 1) for this C<$whatsit>.

=item C<< @args = $whatsit->getArgs; >>

Returns the list of arguments for this C<$whatsit>.

=item C<< $whatsit->setArgs(@args); >>

Sets the list of arguments for this C<$whatsit> to C<@args> (each arg should be
a C<LaTeXML::Core::List>).

=item C<< $list = $whatsit->getBody; >>

Return the body for this C<$whatsit>. This is only defined for environments or
top-level math formula.  The body is stored in the properties under 'body'.

=item C<< $whatsit->setBody(@body); >>

Sets the body of the C<$whatsit> to the boxes in C<@body>.  The last C<$box> in C<@body>
is assumed to represent the `trailer', that is the result of the invocation
that closed the environment or math.  It is stored separately in the properties
under 'trailer'.

=item C<< $list = $whatsit->getTrailer; >>

Return the trailer for this C<$whatsit>. See C<setBody>.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
