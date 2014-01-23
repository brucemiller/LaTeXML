# /=====================================================================\ #
# |  LaTeXML::Core::Mouth::http                                         | #
# | Analog of TeX's Mouth: for reading from http                        | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Mouth::http;
use strict;
use warnings;
use base qw(LaTeXML::Core::Mouth);
use LaTeXML::Util::WWW;
use LaTeXML::Global;

sub new {
  my ($class,   $url,  %options) = @_;
  my ($urlbase, $name, $ext)     = url_split($url);
  $STATE->assignValue(URLBASE => $urlbase) if defined $urlbase;
  my $self = bless { source => $url, shortsource => $name }, $class;
  $$self{fordefinitions} = 1 if $options{fordefinitions};
  $$self{notes}          = 1 if $options{notes};
  my $content = auth_get($url);
  $self->openString($content);
  $self->initialize;
  return $self; }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::Mouth::http> - tokenize the input from http

=head1 DESCRIPTION

A C<LaTeXML::Core::Mouth> (and subclasses) is responsible for I<tokenizing>, ie.
converting plain text and strings into L<LaTeXML::Core::Token>s according to the
current category codes (catcodes) stored in the C<LaTeXML::Core::State>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
