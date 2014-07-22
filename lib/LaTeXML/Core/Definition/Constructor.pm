# /=====================================================================\ #
# |  LaTeXML::Core::Definition::Constructor                             | #
# | Representation of definitions of Control Sequences                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Definition::Constructor;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Core::Whatsit;
use base qw(LaTeXML::Core::Definition::Primitive);
use LaTeXML::Core::Definition::Constructor::Compiler;

#**********************************************************************
# Constructor control sequences.
# They are first converted to a Whatsit in the Stomach, and that Whatsit's
# contruction is carried out to form parts of the document.
# In particular, beforeDigest, reading args and afterDigest are executed
# in the Stomach.
#**********************************************************************

# Known traits:
#    beforeDigest, afterDigest : code for before/after digestion daemons
#    afterDigestBody : similar, but applies only the \begin{environment} commands.
#    reversion : CODE or TOKENS for reverting to TeX form
#    captureBody : whether to capture the following List as a `body`
#        (for environments, math modes)
#        If this is a token, it is the token that will be matched to end the body.
#    properties : a hash of default values for properties to store in the Whatsit.
sub new {
  my ($class, $cs, $parameters, $replacement, %traits) = @_;
  my $source = $STATE->getStomach->getGullet->getMouth;
  Fatal('misdefined', $cs, $source,
    "Constructor replacement for '" . ToString($cs) . "' is not a string or CODE",
    "Replacement is $replacement")
    if !(defined $replacement) || ((ref $replacement) && !(ref $replacement eq 'CODE'));
  return bless { cs => $cs, parameters => $parameters, replacement => $replacement,
    locator => "from " . $source->getLocator(-1), %traits,
##    nargs => (defined $traits{nargs} ? $traits{nargs}
    ##  : ($parameters ? $parameters->getNumArgs : 0))
    nargs => $traits{nargs}
    }, $class; }

sub getReversionSpec {
  my ($self) = @_;
  my $spec = $$self{reversion};
  if ($spec && !ref $spec) {
    $spec = $$self{reversion} = LaTeXML::Package::TokenizeInternal($spec); }
  return $spec; }

sub getSizer {
  my ($self) = @_;
  return $$self{sizer}; }

sub getAlias {
  my ($self) = @_;
  return $$self{alias}; }

sub getNumArgs {
  my ($self) = @_;
  return $$self{nargs} if defined $$self{nargs};
  my $params = $self->getParameters;
  $$self{nargs} = ($params ? $params->getNumArgs : 0);
  return $$self{nargs}; }

# Digest the constructor; This should occur in the Stomach to create a Whatsit.
# The whatsit which will be further processed to create the document.
sub invoke {
  my ($self, $stomach) = @_;
  # Call any `Before' code.
  my $profiled = $STATE->lookupValue('PROFILING') && ($LaTeXML::CURRENT_TOKEN || $$self{cs});
  LaTeXML::Core::Definition::startProfiling($profiled) if $profiled;

  my @pre = $self->executeBeforeDigest($stomach);

  if ($STATE->lookupValue('TRACINGCOMMANDS')) {
    print STDERR '{' . $self->getCSName . "}\n"; }
  # Get some info before we process arguments...
  my $font   = $STATE->lookupValue('font');
  my $ismath = $STATE->lookupValue('IN_MATH');
  # Parse AND digest the arguments to the Constructor
  my $params = $self->getParameters;
  my @args   = ($params ? $params->readArgumentsAndDigest($stomach, $self) : ());
  my $nargs  = $self->getNumArgs;
  @args = @args[0 .. $nargs - 1];

  # Compute any extra Whatsit properties (many end up as element attributes)
  my $properties = $$self{properties};
  my %props = (!defined $properties ? ()
    : (ref $properties eq 'CODE' ? &$properties($stomach, @args)
      : %$properties));
  foreach my $key (keys %props) {
    my $value = $props{$key};
    if (ref $value eq 'CODE') {
      $props{$key} = &$value($stomach, @args); } }
  $props{font}    = $font                                     unless defined $props{font};
  $props{locator} = $stomach->getGullet->getMouth->getLocator unless defined $props{locator};
  $props{isMath}  = $ismath                                   unless defined $props{isMath};
  $props{level}   = $stomach->getBoxingLevel;

  # Now create the Whatsit, itself.
  my $whatsit = LaTeXML::Core::Whatsit->new($self, [@args], %props);

  # Call any 'After' code.
  my @post = $self->executeAfterDigest($stomach, $whatsit);
  if (my $cap = $$self{captureBody}) {
    $whatsit->setBody(@post, $stomach->digestNextBody((ref $cap ? $cap : undef))); @post = (); }

  my @postpost = $self->executeAfterDigestBody($stomach, $whatsit);
  LaTeXML::Core::Definition::stopProfiling($profiled) if $profiled;
  return (@pre, $whatsit, @post, @postpost); }

# Similar to executeAfterDigest
sub executeAfterDigestBody {
  my ($self, $stomach, @whatever) = @_;
  local $LaTeXML::Core::State::UNLOCKED = 1;
  my $post = $$self{afterDigestBody};
  return ($post ? map { &$_($stomach, @whatever) } @$post : ()); }

sub doAbsorbtion {
  my ($self, $document, $whatsit) = @_;
  # First, compile the constructor pattern, if needed.
  my $replacement = $$self{replacement};
  if (!ref $replacement) {
    $$self{replacement} = $replacement = LaTeXML::Core::Definition::Constructor::Compiler::compileConstructor($self); }
  # Now do the absorbtion.
  if (my $pre = $$self{beforeConstruct}) {
    map { &$_($document, $whatsit) } @$pre; }
  &{$replacement}($document, $whatsit->getArgs, $whatsit->getProperties);
  if (my $post = $$self{afterConstruct}) {
    map { &$_($document, $whatsit) } @$post; }
  return; }

#===============================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Definition::Constructor>  - Control sequence definitions.

=head1 DESCRIPTION


This class represents control sequences that contribute arbitrary XML fragments
to the document tree.  During digestion, a C<LaTeXML::Core::Definition::Constuctor> records the arguments 
used in the invokation to produce a L<LaTeXML::Core::Whatsit>.  The resulting L<LaTeXML::Core::Whatsit>
(usually) generates an XML document fragment when absorbed by an instance of L<LaTeXML::Core::Document>.
Additionally, a C<LaTeXML::Core::Definition::Constructor> may have beforeDigest and afterDigest daemons
defined which are executed for side effect, or for adding additional boxes to the output.

It extends L<LaTeXML::Core::Definition>.

More documentation needed, but see LaTeXML::Package for the main user access to these.

=head2 More about Constructors

=begin latex

\label{LaTeXML::Core::Definition::ConstructorCompiler}

=end latex

A constructor has as it's C<replacement> a subroutine or a string pattern representing
the XML fragment it should generate.  In the case of a string pattern, the pattern is
compiled into a subroutine on first usage by the internal class C<LaTeXML::Core::Definition::ConstructorCompiler>.
Like primitives, constructors may have C<beforeDigest> and C<afterDigest>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
