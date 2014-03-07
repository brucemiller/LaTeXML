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
use LaTeXML::Common::Object;
use base qw(LaTeXML::Common::Object);
use base qw(Exporter);
our @EXPORT = (
  qw( &Box ),
);

#======================================================================
# Exported constructors

sub Box {
  my ($string, $font, $locator, $tokens) = @_;
  $font = $STATE->lookupValue('font') unless defined $font;
  $locator = $STATE->getStomach->getGullet->getLocator unless defined $locator;
  $tokens = LaTeXML::Core::Token::T_OTHER($string) if $string && !defined $tokens;
  my $state = $STATE;
  if ($state->lookupValue('IN_MATH')) {
    my $attr = (defined $string) && $state->lookupValue('math_token_attributes_' . $string);
    return LaTeXML::Core::Box->new($string, $font->specialize($string), $locator, $tokens,
      mode => 'math', attributes => $attr); }
  else {
    return LaTeXML::Core::Box->new($string, $font, $locator, $tokens); } }

#======================================================================
# Box Object

sub new {
  my ($class, $string, $font, $locator, $tokens, %properties) = @_;
  return bless [$string, $font, $locator, $tokens, {%properties}], $class; }

# Accessors
sub isaBox {
  return 1; }

sub getString {
  my ($self) = @_;
  return $$self[0]; }    # Return the string contents of the box

sub getFont {
  my ($self) = @_;
  return $$self[1]; }    # Return the font this box uses.

sub isMath {
  my ($self) = @_;
  return ($$self[4]{mode} || 'text') eq 'math'; }

sub getLocator {
  my ($self) = @_;
  return $$self[2]; }

sub getSource {
  my ($self) = @_;
  return $$self[2]; }

# So a Box can stand in for a List
sub unlist {
  my ($self) = @_;
  return ($self); }    # Return list of the boxes

sub revert {
  my ($self) = @_;
  return ($$self[3] ? $$self[3]->unlist : ()); }

sub toString {
  my ($self) = @_;
  return $$self[0]; }

# Methods for overloaded operators
sub stringify {
  my ($self) = @_;
  my $type = ref $self;
  $type =~ s/^LaTeXML::Core:://;
  my $font = (defined $$self[1]) && $$self[1]->stringify;    # show font, too, if interesting
  return $type . '['
    . (defined $$self[0] ? $$self[0]
    : (defined $$self[3] ? '[' . ToString($$self[3]) . ']' : ''))
    . ($font && ($font ne 'Font[]') ? ' ' . $font : '')
    . ']'; }

# Should this compare fonts too?
sub equals {
  my ($a, $b) = @_;
  return (defined $b) && ((ref $a) eq (ref $b)) && ($$a[0] eq $$b[0]) && ($$a[1]->equals($$b[1])); }

sub beAbsorbed {
  my ($self, $document) = @_;
  my $string = $$self[0];
  my $mode   = $$self[4]{mode} || 'text';
  my $attr   = $$self[4]{attributes};
  return ((defined $string) && ($string ne '')
    ? ($mode eq 'math'
      ? $document->insertMathToken($string, font => $$self[1], ($attr ? %$attr : ()))
      : $document->openText($string, $$self[1]))
    : undef); }

sub getProperty {
  my ($self, $key) = @_;
  if ($key eq 'isSpace') {
    my $tex = LaTeXML::Core::Token::UnTeX($$self[3]);    # !
    return (defined $tex) && ($tex =~ /^\s*$/); }        # Check the TeX code, not (just) the string!
  else {
    return $$self[4]{$key}; } }

sub getProperties {
  my ($self) = @_;
  return %{ $$self[4] }; }

sub getPropertiesRef {
  my ($self) = @_;
  return $$self[4]; }

sub setProperty {
  my ($self, $key, $value) = @_;
  $$self[4]{$key} = $value;
  return; }

sub setProperties {
  my ($self, %props) = @_;
  while (my ($key, $value) = each %props) {
    $$self{properties}{$key} = $value if defined $value; }
  return; }

sub getWidth {
  my ($self, %options) = @_;
  my $props = $self->getPropertiesRef;
  $self->computeSize(%options) unless defined $$props{width};
  return $$props{width}; }

sub getHeight {
  my ($self, %options) = @_;
  my $props = $self->getPropertiesRef;
  $self->computeSize(%options) unless defined $$props{height};
  return $$props{height}; }

sub getDepth {
  my ($self, %options) = @_;
  my $props = $self->getPropertiesRef;
  $self->computeSize(%options) unless defined $$props{depth};
  return $$props{depth}; }

sub getTotalHeight {
  my ($self, %options) = @_;
  my $props = $self->getPropertiesRef;
  $self->computeSize(%options) unless defined $$props{height} && defined $$props{depth};
  return $$props{height}->add($$props{depth}); }

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
  $self->computeSize(%options)
    unless (defined $$props{width}) && (defined $$props{height}) && (defined $$props{depth});
  return ($$props{width}, $$props{height}, $$props{depth}); }

# for debugging....
sub showSize {
  my ($self) = @_;
  return '[' . ToString($self->getWidth) . ' x ' . ToString($self->getHeight) . ' + ' . ToString($self->getDepth) . ']'; }

#omg
# Fake computing the dimensions of strings (typically single chars).
# Eventually, this needs to link into real font data
sub computeSize {
  my ($self, %options) = @_;
  my $props = $self->getPropertiesRef;
  $options{width}  = $$props{width}  if $$props{width};
  $options{height} = $$props{height} if $$props{height};
  $options{depth}  = $$props{depth}  if $$props{depth};
  my ($w, $h, $d) = ($$self[1]
      || LaTeXML::Common::Font->textDefault)->computeStringSize($$self[0], %options);
  $$props{width}  = $w unless defined $$props{width};
  $$props{height} = $h unless defined $$props{height};
  $$props{depth}  = $d unless defined $$props{depth};
  return; }

#**********************************************************************
# What about Kern, Glue, Penalty ...

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

Get a string describing the location in the original source that gave rise
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
