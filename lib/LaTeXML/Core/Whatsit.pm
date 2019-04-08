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
  # (1) provide a means to get the RAW, internal markup that can (hopefully) be RE-digested
  #     this is needed for getting the numerator of \over into textstyle!
  # (2) caching the reversion (which is a big performance boost)
  if (my $saved = !$LaTeXML::REVERT_RAW
    && ($LaTeXML::DUAL_BRANCH
      ? $$self{dual_reversion}{$LaTeXML::DUAL_BRANCH}
      : $$self{reversion})) {
    return $saved->unlist; }
  else {
    my $defn   = $self->getDefinition;
    my $spec   = ($LaTeXML::REVERT_RAW ? undef : $defn->getReversionSpec);
    my @tokens = ();
    if ((defined $spec) && (ref $spec eq 'CODE')) {    # If handled by CODE, call it
      @tokens = &$spec($self, $self->getArgs); }
    else {
      if (defined $spec) {
        @tokens = $spec->substituteParameters(map { Tokens(Revert($_)) } $self->getArgs)->unlist
          if $spec ne ''; }
      else {
        my $alias = ($LaTeXML::REVERT_RAW ? undef : $defn->getAlias);
        if (defined $alias) {
          push(@tokens, T_CS($alias)) if $alias ne ''; }
        else {
          push(@tokens, $defn->getCS); }
        if (my $parameters = $defn->getParameters) {
          push(@tokens, $parameters->revertArguments($self->getArgs)); } }
      if (defined(my $body = $self->getBody)) {
        push(@tokens, Revert($body));
        if (defined(my $trailer = $self->getTrailer)) {
          push(@tokens, Revert($trailer)); } } }
    # Now cache it, in case it's needed again
    if ($LaTeXML::REVERT_RAW) { }    # don't cache
    elsif ($LaTeXML::DUAL_BRANCH) {
      $$self{dual_reversion}{$LaTeXML::DUAL_BRANCH} = Tokens(@tokens); }
    else {
      $$self{reversion} = Tokens(@tokens); }
    return @tokens; } }

sub toString {
  my ($self) = @_;
  return ToString(Tokens($self->revert)); }    # What else??

sub getString {
  my ($self) = @_;
  return $self->toString; }                    # Ditto?

# Methods for overloaded operators
sub stringify {
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
  my ($self, $document) = @_;
  # Significant time is consumed here, and associated with a specific CS,
  # so we should be profiling as well!
  # Hopefully the csname is the same that was charged in the digestioned phase!
  my $defn = $self->getDefinition;
  my $profiled = $STATE->lookupValue('PROFILING') && $defn->getCS;
  LaTeXML::Core::Definition::startProfiling($profiled, 'absorb') if $profiled;
  my @result = $defn->doAbsorbtion($document, $self);
  LaTeXML::Core::Definition::stopProfiling($profiled, 'absorb') if $profiled;
  return @result; }

# See discussion in Box.pm
sub computeSize {
  my ($self, %options) = @_;
  # Use #body, if any, else ALL args !?!?!
  # Eventually, possibly options like sizeFrom, or computeSize or....
  my $defn  = $self->getDefinition;
  my $props = $self->getPropertiesRef;
  my $sizer = $defn->getSizer;
  my ($width, $height, $depth);
  # If sizer is a function, call it
  if (ref $sizer) {
    ($width, $height, $depth) = &$sizer($self); }
  else {
    my @boxes = ();
    if (!defined $sizer) {    # Nothing specified? use #body if any, else sum all box args
      @boxes = ($$self{properties}{body}
        ? ($$self{properties}{body})
        : (map { ((ref $_) && ($_->isaBox) ? $_->unlist : ()) } @{ $$self{args} })); }
    elsif (($sizer eq '0') || ($sizer eq '')) { }    # 0 size!
    elsif ($sizer =~ /^(#\w+)*$/) {    # Else if of form '#digit' or '#prop', combine sizes
      while ($sizer =~ s/^#(\w+)//) {
        my $arg = $1;
        push(@boxes, ($arg =~ /^\d+$/ ? $self->getArg($arg) : $$props{$arg})); } }
    else {
      Warn('unexpected', $sizer, undef,
        "Expected sizer to be a function, or arg or property specification, not '$sizer'"); }
    my $font = $$props{font};
    $options{width}   = $$props{width}   if $$props{width};
    $options{height}  = $$props{height}  if $$props{height};
    $options{depth}   = $$props{depth}   if $$props{depth};
    $options{vattach} = $$props{vattach} if $$props{vattach};
    $options{layout}  = $$props{layout}  if $$props{layout};
    ($width, $height, $depth) = $font->computeBoxesSize([@boxes], %options); }
  # Now, only set the dimensions that weren't already set.
  $$props{cwidth}  = $width  unless defined $$props{width};
  $$props{cheight} = $height unless defined $$props{height};
  $$props{cdepth}  = $depth  unless defined $$props{depth};
  return; }

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
