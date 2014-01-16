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
use base qw(LaTeXML::Object);

sub new {
  my ($class, $string, $font, $locator, $tokens) = @_;
  return bless [$string, $font, $locator, $tokens, {}], $class; }

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
  return 0; }            # Box is text mode.

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
  $type =~ s/^LaTeXML:://;
  return $type . '['
    . (defined $$self[0] ? $$self[0]
    : (defined $$self[3] ? '[' . ToString($$self[3]) . ']' : '')) . ']'; }

# Should this compare fonts too?
sub equals {
  my ($a, $b) = @_;
  return (defined $b) && ((ref $a) eq (ref $b)) && ($$a[0] eq $$b[0]) && ($$a[1]->equals($$b[1])); }

sub beAbsorbed {
  my ($self, $document) = @_;
  my $string = $$self[0];
  return ((defined $string) && ($string ne '')
    ? $document->openText($$self[0], $$self[1]) : undef); }

sub getProperty {
  my ($self, $key) = @_;
  if ($key eq 'isSpace') {
    my $tex = UnTeX($$self[3]);
    return (defined $tex) && ($tex =~ /^\s*$/); }    # Check the TeX code, not (just) the string!
  else {
    return $$self[4]{$key}; } }

sub getProperties {
  my ($self) = @_;
  return %{ $$self[4] }; }

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
  my ($self) = @_;
  $self->computeSize unless defined $$self[4]{width};
  return $$self[4]{width}; }

sub getHeight {
  my ($self) = @_;
  $self->computeSize unless defined $$self[4]{height};
  return $$self[4]{height}; }

sub getDepth {
  my ($self) = @_;
  $self->computeSize unless defined $$self[4]{depth};
  return $$self[4]{depth}; }

sub getTotalHeight {
  my ($self) = @_;
  return $self->getHeight->add($self->getDepth); }

sub setWidth {
  my ($self, $width) = @_;
  $$self[4]{width} = $width;
  return; }

sub setHeight {
  my ($self, $height) = @_;
  $$self[4]{height} = $height;
  return; }

sub setDepth {
  my ($self, $depth) = @_;
  $$self[4]{depth} = $depth;
  return; }

sub getSize {
  my ($self) = @_;
  return ($self->getWidth, $self->getHeight, $self->getDepth); }

# for debugging....
sub showSize {
  my ($self) = @_;
  return '[' . ToString($self->getWidth) . ' x ' . ToString($self->getHeight) . ' + ' . ToString($self->getDepth) . ']'; }

#omg
# Fake computing the dimensions of strings (typically single chars).
# Eventually, this needs to link into real font data
sub computeSize {
  my ($self) = @_;
  my ($w, $h, $d) = ($$self[1] || LaTeXML::Common::Font->textDefault)->computeStringSize($$self[0]);
  $$self[4]{width}  = $w unless defined $$self[4]{width};
  $$self[4]{height} = $h unless defined $$self[4]{height};
  $$self[4]{depth}  = $d unless defined $$self[4]{depth};
  return; }

#**********************************************************************
# What about Kern, Glue, Penalty ...

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Box> - Representations of digested objects.

=head1 DESCRIPTION

A Box represents a digested object, text in a particular font;


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
