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
#  Base object for all LaTeXML Objects; sets up overloading, etc.
# The first reason is to be able to stringify things concisely
# However, overloading stringify cause that stringification to be used
# for all sorts of things, like converting to boolean!!!
#**********************************************************************

package LaTeXML::Object;
use strict;
use overload
  '""'     => 'stringify',
  bool     => sub { 1; },	# If there's an object, it's true.
  '!'      => sub { 0; },	# Or not..
  eq       => 'equals',		# Allow defining our own comparisons
#  fallback => 0,		# Don't try to automagically generate ops.
  nomethod => \&nomethod;

sub stringify {
  my($object)=@_;
  my $string = overload::StrVal($object);
  $string =~ s/^LaTeXML:://;
  $string =~ s/=(SCALAR|HASH|ARRAY|CODE|REF|GLOB|LVALUE|)\(/\[@/;
  $string =~ s/\)$/\]/;
  $string; }

sub equals {
  my($a,$b)=@_;
  overload::StrVal($a) eq overload::StrVal($b); }

sub nomethod {
  my($a,$b,$reversed,$method)=@_;
  die("NOTE: Overloaded method $method was invoked on $a, $b\n"); }

#**********************************************************************
1;

__END__

=pod 

=head1 LaTeXML::Object

=head2 DESCRIPTION

LaTeXML::Object serves as a base class for all other objects (both the
data objects and control objects).  It provides for overloading of
stringification and comparison operations to simplify coding and
to beautify error reporting.

=head2 Methods of LaTeXML::Object

=over 4

=item C<< $string = $object->stringify; >>

Returns a hopefully readable representation of the object. 
This method overloads the operation performed when an object
is converted to a string, such as when it is interpolated or printed.

=item C<< $boole = $object->equals($other); >>

Returns whether $object and $other are equal.  By default it
just compares whether they are the same object.  This method
is invoked when the C<eq> operator is used.

=back

