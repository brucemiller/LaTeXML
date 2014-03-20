# /=====================================================================\ #
# |  LaTeXML::Common::Object                                            | #
# | Abstract base class for LaTeXML objects                             | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Object;
use strict;
use warnings;
use LaTeXML::Global;
use XML::LibXML;    # Need XML_xxx constants!
use base qw(Exporter);
our @EXPORT = (
  qw(&Stringify &ToString &Revert &Equals),
);

#======================================================================
# Exported generic functions for dealing with LaTeXML's objects
#======================================================================

my %NOBLESS = map { ($_ => 1) } qw( SCALAR HASH ARRAY CODE REF GLOB LVALUE);    # [CONSTANT]

sub Stringify {
  my ($object) = @_;
  if    (!defined $object)          { return 'undef'; }
  elsif (!ref $object)              { return $object; }
  elsif ($NOBLESS{ ref $object })   { return "$object"; }
  elsif ($object->can('stringify')) { return $object->stringify; }
  # Have to handle LibXML stuff explicitly (unless we want to add methods...?)
  elsif ($object->isa('XML::LibXML::Node')) {
    if ($object->nodeType == XML_ELEMENT_NODE) {
      my $tag        = $STATE->getModel->getNodeQName($object);
      my $attributes = '';
      foreach my $attr ($object->attributes) {
        my $name = $attr->nodeName;
        my $val  = $attr->getData;
        $val = substr($val, 0, 30) . "..." if length($val) > 35;
        $attributes .= ' ' . $name . "=\"" . $val . "\""; }
      return "<" . $tag . $attributes . ($object->hasChildNodes ? ">..." : "/>");
    }
    elsif ($object->nodeType == XML_TEXT_NODE) {
      return "XMLText[" . $object->data . "]"; }
    elsif ($object->nodeType == XML_DOCUMENT_NODE) {
      return "XMLDocument[" . $$object . "]"; }
    elsif ($object->nodeType == XML_DOCUMENT_FRAG_NODE) {
      return "XMLFragment[" . join('', map { Stringify($_) } $object->childNodes) . "]"; }
    else { return "$object"; } }
  else { return "$object"; } }

sub ToString {
  my ($object) = @_;
  my $r;
  return (defined $object
    ? (($r = ref $object) && !$NOBLESS{$r} ? $object->toString : "$object") : ''); }

# Just how deep of an equality test should this be?
sub Equals {
  my ($a, $b) = @_;
  return 1 if !(defined $a) && !(defined $b);    # both undefined, equal, I guess
  return 0 unless (defined $a) && (defined $b);  # else both must be defined
  my $refa = (ref $a) || '_notype_';
  my $refb = (ref $b) || '_notype_';
  return 0 if $refa ne $refb;                    # same type?
  return $a eq $b if ($refa eq '_notype_') || $NOBLESS{$refa};    # Deep comparison of builtins?
  return 1 if $a->equals($b);                                     # semi-shallow comparison?
       # Special cases? (should be methods, but that embeds State knowledge too low)

  if ($refa eq 'LaTeXML::Core::Token') {    # Check if they've been \let to the same defn.
    my $defa = $STATE->lookupDefinition($a);
    my $defb = $STATE->lookupDefinition($b);
    return $defa && $defb && ($defa eq $defb); }
  return 0; }

# Reverts an object into TeX code, as a Tokens list, that would create it.
# Note that this is not necessarily the original TeX.
sub Revert {
  my ($thing) = @_;
  return (defined $thing
    ? (ref $thing ? map { $_->unlist } $thing->revert
      : LaTeXML::Core::Token::Explode($thing))    # Ugh!!
    : ()); }

#======================================================================
# LaTeXML Object
#  Base object for all LaTeXML Objects;
# Defines basic default methods for comparison, printing
# Tried to use overloading, but the Magic methods lead to hard-to-find
# (and occasionally quite serious) performance issues -- at least, if you
# try to have stringify do too much.
#======================================================================

sub stringify {
  my ($object) = @_;
  my $string = "$object"; overload::StrVal($object);
  $string =~ s/^LaTeXML:://;
  $string =~ s/=(SCALAR|HASH|ARRAY|CODE|REF|GLOB|LVALUE|)\(/\[@/;
  $string =~ s/\)$/\]/;
  return $string; }

sub toString {
  my ($self) = @_;
  return $self->stringify; }

sub toAttribute {
  my ($self) = @_;
  return $self->toString; }

sub equals {
  my ($a, $b) = @_;
  return "$a" eq "$b"; }    # overload::StrVal($a) eq overload::StrVal($b); }

sub notequals {
  my ($a, $b) = @_;
  return !($a->equals($b)); }

sub isaToken      { return 0; }
sub isaBox        { return 0; }
sub isaDefinition { return 0; }

# These should really only make sense for Data objects within the
# processing stream.
# Defaults (probably poor)
sub beDigested {
  my ($self) = @_;
  return $self; }

sub beAbsorbed {
  my ($self, $document) = @_;
  return $document->openText($self->toString, $document->getNodeFont($document->getElement)); }

sub unlist {
  my ($self) = @_;
  return $self; }

#**********************************************************************
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Common::Object> - abstract base class for most LaTeXML objects.

=head1 DESCRIPTION

C<LaTeXML::Common::Object> serves as an abstract base class for all other objects (both the
data objects and control objects).  It provides for common methods for
stringification and comparison operations to simplify coding and
to beautify error reporting.

=head2 Generic functions

=over 4

=item C<< $string = Stringify($object); >>

Returns a string identifying C<$object>, for debugging.
Works on any values and objects, but invokes the stringify method on 
blessed objects.
More informative than the default perl conversion to a string.

=item C<< $string = ToString($object); >>

Converts C<$object> to string attempting, when possible,
to generate straight text without TeX markup.
This is most useful for converting Tokens or Boxes to document
content or attribute values, or values to be used for pathnames,
keywords, etc.   Generally, however, it is not possible
to convert Whatsits generated by Constructors into clean strings,
without TeX markup.
Works on any values and objects, but invokes
the toString method on blessed objects.

=item C<< $boolean = Equals($a,$b); >>

Compares the two objects for equality.  Works on any values and objects, 
but invokes the equals method on blessed objects, which does a
deep comparison of the two objects.

=item C<< $tokens = Revert($object); >>

Returns a Tokens list containing the TeX that would create C<$object>.
Note that this is not necessarily the original TeX code;
expansions or other substitutions may have taken place.

=back

=head2 Methods

=over 4

=item C<< $string = $object->stringify; >>

Returns a readable representation of C<$object>,
useful for debugging.

=item C<< $string = $object->toString; >>

Returns the string content of C<$object>;
most useful for extracting a clean, usable, Unicode string from
tokens or boxes that might representing a filename or such.
To the extent possible, this should provide a string
that can be used as XML content, or attribute values,
or for filenames or whatever. However, control sequences
defined as Constructors may leave TeX code in the value.

=item C<< $boole = $object->equals($other); >>

Returns whether $object and $other are equal.  Should perform
a deep comparision, but the default implementation just compares
for object identity.

=item C<< $boole = $object->isaToken; >>

Returns whether C<$object> is an L<LaTeXML::Core::Token>.

=item C<< $boole = $object->isaBox; >>

Returns whether C<$object> is an L<LaTeXML::Core::Box>.

=item C<< $boole = $object->isaDefinition; >>

Returns whether C<$object> is an L<LaTeXML::Core::Definition>.

=item C<< $digested = $object->beDigested; >>

Does whatever is needed to digest the object, and
return the digested representation.  Tokens would be digested
into boxes; Some objects, such as numbers can just return themselves.

=item C<< $object->beAbsorbed($document); >>

Do whatever is needed to absorb the C<$object> into the C<$document>,
typically by invoking appropriate methods on the C<$document>.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

