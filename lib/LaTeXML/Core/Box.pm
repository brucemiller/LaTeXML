# /=====================================================================\ #
# |  LaTeXML::Core::Box                                                 | #
# | Digested objects produced in the Stomach                            | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Box;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Dimension qw(Dimension);
use LaTeXML::Common::Object;
use base qw(LaTeXML::Common::Object);
use LaTeXML::Common::Error;
use base qw(Exporter);
our @EXPORT = (
  qw( &Box ),
);

DebuggableFeature('size', "Box sizing");
#======================================================================
# Exported constructors

sub Box {
  my ($string, $font, $locator, $tokens, %properties) = @_;
  $font    = $STATE->lookupValue('font')               unless defined $font;
  $locator = $STATE->getStomach->getGullet->getLocator unless defined $locator;
  $tokens  = LaTeXML::Core::Token::T_OTHER($string) if $string && !defined $tokens;
  if ((!defined $properties{isSpace}) && (defined $string) && ($string =~ /^\s*$/)) {
    $properties{isSpace} = 1; }
  if ($properties{isSpace} && ($properties{width} || $properties{height} || $properties{depth})) {
    $properties{width}  = Dimension(0) unless defined $properties{width};
    $properties{height} = Dimension(0) unless defined $properties{height};
    $properties{depth}  = Dimension(0) unless defined $properties{depth}; }
  my $state = $STATE;
  my $mode = $properties{mode} || $state->lookupValue('MODE') || 'restricted_horizontal';
  if ($state->lookupValue('IN_MATH')) {
    my $attr      = (defined $string) && $state->lookupValue('math_token_attributes_' . $string);
    my $usestring = ($attr && $$attr{replace}) || $string;
    return LaTeXML::Core::Box->new($usestring, $font->specialize($string), $locator, $tokens,
##      mode => 'math', ($attr ? %$attr : ()), %properties); }
      mode => $mode, ($attr ? %$attr : ()), %properties); }
  else {
    return LaTeXML::Core::Box->new($string, $font, $locator, $tokens,
                                   mode => $mode, %properties); } }

#======================================================================
# Box Object

sub new {
  my ($class, $string, $font, $locator, $tokens, %properties) = @_;
  return bless { string => $string,
    tokens     => $tokens,
    properties => { font => $font, locator => $locator, %properties }
  }, $class; }

# Accessors
sub isaBox {
  return 1; }

sub getString {
  my ($self) = @_;
  return $$self{string}; }    # Return the string contents of the box

sub getFont {
  my ($self) = @_;
  return $$self{properties}{font}; }    # and if undef ????

sub setFont {
  my ($self, $font) = @_;
  $$self{properties}{font} = $font;
  return; }

sub isMath {
  my ($self) = @_;
  return ($$self{properties}{mode} || 'restricted_horizontal') =~ /math$/; }

sub getLocator {
  my ($self) = @_;
  return $$self{properties}{locator}; }

sub getSource {
  my ($self) = @_;
  return $$self{properties}{locator}; }

# So a Box can stand in for a List
sub unlist {
  my ($self) = @_;
  return ($self); }    # Return list of the boxes

sub getBody {
  my ($self) = @_;
  return $self; }

sub revert {
  my ($self) = @_;
  return ($$self{tokens} ? $$self{tokens}->unlist : ()); }

sub toString {
  my ($self) = @_;
  return $$self{string} // ''; }

# Methods for overloaded operators
my %mode_abbrev = (
  vertical    => 'V',  internal_vertical     => 'iV',
  horizontal  => 'H',  restricted_horizontal => 'rH',
  inline_math => 'iM', display_math          => 'dM');

sub _stringify {
  my ($self) = @_;
  my $type = ref $self;
  my $mode = $$self{properties}{mode};
  $type =~ s/^LaTeXML::Core:://;
  $type .= '!'. ($mode_abbrev{$mode} || $mode) if $mode;
  return $type; }

sub stringify {
  my ($self) = @_;
  my $font = (defined $$self{properties}{font}) && $$self{properties}{font}->stringify; # show font, too, if interesting
  return $self->_stringify . '['
    . (defined $$self{string} ? $$self{string}
    : (defined $$self{tokens} ? '[' . ToString($$self{tokens}) . ']' : ''))
    . ($font && ($font ne 'Font[]') ? ' ' . $font : '') . ']'; }

# Should this compare fonts too?
sub equals {
  my ($a, $b) = @_;
  return (defined $b) && ((ref $a) eq (ref $b)) && ($$a{string} eq $$b{string}) && ($$a{properties}{font}->equals($$b{properties}{font})); }

sub beAbsorbed {
  my ($self, $document) = @_;
  my $string = $$self{string};
  my $ismath = ($$self{properties}{mode} || 'restricted_horizontal') =~ /math$/;

  # Guard via the absorb limit to avoid infinite loops
  if ($LaTeXML::ABSORB_LIMIT) {
    my $absorb_counter = $STATE->lookupValue('absorb_count') || 0;
    $STATE->assignValue(absorb_count => ++$absorb_counter, 'global');
    if ($absorb_counter > $LaTeXML::ABSORB_LIMIT) {
      Fatal('timeout', 'absorb_limit', $self,
        "Whatsit absorb limit of $LaTeXML::ABSORB_LIMIT exceeded, infinite loop?"); } }

  return (((defined $string) && ($string ne '')) || $$self{properties}{width}    # ?
    ? ($ismath
      ? $document->insertMathToken($string, %{ $$self{properties} })
      : $document->openText($string, $$self{properties}{font}))
    : undef); }

sub getProperty {
  my ($self, $key) = @_;
  return $$self{properties}{$key}; }

sub getProperties {
  my ($self) = @_;
  return %{ $$self{properties} }; }

sub getPropertiesRef {
  my ($self) = @_;
  return $$self{properties}; }

sub setProperty {
  my ($self, $key, $value) = @_;
  $$self{properties}{$key} = $value;
  return; }

sub setProperties {
  my ($self, %props) = @_;
  while (my ($key, $value) = each %props) {
    $$self{properties}{$key} = $value if defined $value; }
  return; }

# For the dimensions of boxes, we'll store the (lazily) computed size as:
#    cwidth, cheight, cdepth
# and the explicitly requested/assigned size as
#    width, height, depth.
# Generally speaking, an XML element should only get width, height, depth
# attributes when they were explicitly set.
# However, when requesting the size of a box, you'd get either (w/ explicit size overriding)
sub getWidth {
  my ($self, %options) = @_;
  my $props = $self->getPropertiesRef;
  $self->computeSizeStore(%options) unless (defined $$props{width}) or (defined $$props{cwidth});
  return $$props{width} || $$props{cwidth}; }

sub getHeight {
  my ($self, %options) = @_;
  my $props = $self->getPropertiesRef;
  $self->computeSizeStore(%options) unless (defined $$props{height}) or (defined $$props{cheight});
  return $$props{height} || $$props{cheight}; }

sub getDepth {
  my ($self, %options) = @_;
  my $props = $self->getPropertiesRef;
  $self->computeSizeStore(%options) unless (defined $$props{depth}) or (defined $$props{cdepth});
  return $$props{depth} || $$props{cdepth}; }

sub getTotalHeight {
  my ($self, %options) = @_;
  my $props = $self->getPropertiesRef;
  $self->computeSizeStore(%options)
    unless ((defined $$props{height}) or (defined $$props{cheight}))
    && ((defined $$props{depth}) or (defined $$props{cdepth}));
  my $h = $$props{height} || $$props{cheight};
  my $d = $$props{depth}  || $$props{cdepth};
  return $h->add($d); }

sub setWidth {
  my ($self, $width) = @_;
  my $props = $self->getPropertiesRef;
  $$props{width} = $width;
  return; }

sub setHeight {
  my ($self, $height) = @_;
  my $props = $self->getPropertiesRef;
  $$props{height} = $height;
  return; }

sub setDepth {
  my ($self, $depth) = @_;
  my $props = $self->getPropertiesRef;
  $$props{depth} = $depth;
  return; }

sub getSize {
  my ($self, %options) = @_;
  my $props = $self->getPropertiesRef;
  no warnings 'recursion';
  $self->computeSizeStore(%options)
    unless (defined $$props{cwidth})
    && (defined $$props{cheight})
    && (defined $$props{cdepth});
  Debug("SIZE of $self"
      . "\n preassigned: " . _showsize($$props{width},  $$props{height},  $$props{depth})
      . "\n calculated : " . _showsize($$props{cwidth}, $$props{cheight}, $$props{cdepth})
      . "\n w/options " . join(',', map { $_ . "=" . ToString($options{$_}); } sort keys %options)
      . "\n =>: " . _showsize($$props{width} || $$props{cwidth}, $$props{height} || $$props{cheight}, $$props{depth} || $$props{cdepth})
      . "\n   Of " . ToString($self)) if $LaTeXML::DEBUG{size};
  return ($$props{width} || $$props{cwidth},
    $$props{height}  || $$props{cheight},
    $$props{depth}   || $$props{cdepth},
    $$props{cwidth}  || $$props{width},
    $$props{cheight} || $$props{height},
    $$props{cdepth}  || $$props{depth}); }

sub _showsize {
  my ($w, $h, $d) = @_;
  return ($w ? ToString($w) : '<none>') . " x " . ($h ? ToString($h) : '<none>') . " + " . ($d ? ToString($d) : '<none>'); }

# for debugging....
sub showSize {
  my ($self) = @_;
  return '[' . ToString($self->getWidth) . ' x ' . ToString($self->getHeight) . ' + ' . ToString($self->getDepth) . ']'; }

#omg
# Fake computing the dimensions of strings (typically single chars).
# Eventually, this needs to link into real font data
sub computeSizeStore {
  my ($self, %options) = @_;
  no warnings 'recursion';
  my $props = $self->getPropertiesRef;
  $options{width}   = $$props{width}   if $$props{width};
  $options{height}  = $$props{height}  if $$props{height};
  $options{depth}   = $$props{depth}   if $$props{depth};
  $options{vattach} = $$props{vattach} if $$props{vattach};
  $options{layout}  = $$props{layout}  if $$props{layout};
  my ($w, $h, $d) = $self->computeSize(%options);
  $$props{cwidth}  = $w unless defined $$props{cwidth};
  $$props{cheight} = $h unless defined $$props{cheight};
  $$props{cdepth}  = $d unless defined $$props{cdepth};
  return; }

sub computeSize {
  my ($self, %options) = @_;
  if (my $body = $self->getProperty('body')) {
    return $body->computeSize(%options); }
  my $font = $self->getProperty('font') || LaTeXML::Common::Font->textDefault;
  return $font->computeStringSize($$self{string}, %options); }

#======================================================================
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Core::Box> - Representations of digested objects;
extends L<LaTeXML::Common::Object>.

=head2 Exported Functions

=over 4

=item C<< $box = Box($string,$font,$locator,$tokens); >>

Creates a Box representing the C<$string> in the given C<$font>.
The C<$locator> records the document source position.
The C<$tokens> is a Tokens list containing the TeX that created
(or could have) the Box.
If C<$font> or C<$locator> are undef, they are obtained from the
currently active L<LaTeXML::Core::State>.  Note that $string can
be undef which contributes nothing to the generated document,
but does record the TeX code (in C<$tokens>).

=back

=head2 METHODS

=over 4

=item C<< $font = $digested->getFont; >>

Returns the font used by C<$digested>.

=item C<< $boole = $digested->isMath; >>

Returns whether C<$digested> was created in math mode.

=item C<< @boxes = $digested->unlist; >>

Returns a list of the boxes contained in C<$digested>.
It is also defined for the Boxes and Whatsit (which just
return themselves) so they can stand-in for a List.

=item C<< $string = $digested->toString; >>

Returns a string representing this C<$digested>.

=item C<< $string = $digested->revert; >>

Reverts the box to the list of C<Token>s that created (or could have
created) it.

=item C<< $string = $digested->getLocator; >>

Get an object describing the location in the original source that gave rise
to C<$digested>.

=item C<< $digested->beAbsorbed($document); >>

C<$digested> should get itself absorbed into the C<$document> in whatever way
is apppropriate.

=item C<< $string = $box->getString; >>

Returns the string part of the C<$box>.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
