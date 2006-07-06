# /=====================================================================\ #
# |  LaTeXML::Object                                                    | #
# | Abstract base class for LaTeXML objects                             | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

# LaTeXML Object
#  Base object for all LaTeXML Objects; 
# Defines basic default methods for comparison, printing
# Tried to use overloading, but the Magic methods lead to hard-to-find
# performance issues -- at least, if you try to have stringify do too much.
#**********************************************************************
package LaTeXML::Object;
use strict;

sub stringify {
  my($object)=@_;
  my $string = "$object"; overload::StrVal($object);
  $string =~ s/^LaTeXML:://;
  $string =~ s/=(SCALAR|HASH|ARRAY|CODE|REF|GLOB|LVALUE|)\(/\[@/;
  $string =~ s/\)$/\]/;
  $string; }

sub toString { $_[0]->stringify; }

sub equals {
  my($a,$b)=@_;
  "$a" eq "$b"; } # overload::StrVal($a) eq overload::StrVal($b); }

sub notequals {
  my($a,$b)=@_;
  !($a->equals($b)); }

sub isaToken      { 0; }
sub isaBox        { 0; }
sub isaDefinition { 0; }
sub isaNode       { 0; }

#**********************************************************************
1;

__END__

=pod 

=head1 LaTeXML::Object

=head2 DESCRIPTION

C<LaTeXML::Object> serves as an abstract base class for all other objects (both the
data objects and control objects).  It provides for common methods for
stringification and comparison operations to simplify coding and
to beautify error reporting.

=head2 Methods

=over 4

=item C<< $string = $object->stringify; >>

Returns a hopefully readable representation of C<$object>,
useful for debugging.

=item C<< $string = $object->toString; >>

Returns the string content of  C<$object>;
most useful for extracting a usable string from tokens or boxes 
that might representing a filename or such.

=item C<< $boole = $object->equals($other); >>

Returns whether $object and $other are equal.  Should perform
a deep comparision, but the default implementation just compares
for object identity.

=item C<< $boole = $object->isaToken; >>

=item C<< $boole = $object->isaBox; >>

=item C<< $boole = $object->isaDefinition; >>

=item C<< $boole = $object->isaNode; >>

Returns whether C<$object> is of the type indicated; L<LaTeXML::Token>,
L<LaTeXML::Box>, L<LaTeXML::Definition> or L<LaTeXML::Node>.

=back

