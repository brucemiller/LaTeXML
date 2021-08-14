# /=====================================================================\ #
# |  LaTeXML::Common::Locator                                           | #
# | Locators                                                            | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Locator;
use LaTeXML::Global;
use strict;
use warnings;
use base qw(LaTeXML::Common::Object);

use LaTeXML::Util::Pathname;
use LaTeXML::Util::WWW;

sub new {
  my ($class, $source, $fromLine, $fromCol, $toLine, $toCol) = @_;
  my $locator = bless { source => $source,
    fromLine => $fromLine, fromCol => $fromCol,
    toLine   => $toLine,   toCol   => $toCol
  }, $class;
  return $locator; }

# creates a new locator range from a given start and end
sub newRange {
  my ($class, $from, $to) = @_;
  # make sure that either parameters are defined
  return $to   unless defined($from);
  return $from unless defined($to);
  # bail if we have differnt sources
  return unless ($$from{source} || '') eq ($$to{source} || '');
  # the end coordinates depend on
  my ($toLine, $toCol);
  if ($to->isRange) {
    $toLine = $$to{toLine};
    $toCol  = $$to{toCol}; }
  else {
    $toLine = $$to{fromLine};
    $toCol  = $$to{fromCol}; }
  return new($class, $$from{source}, $$from{fromLine}, $$from{fromCol}, $toLine, $toCol); }

sub isRange {
  my ($self) = @_;
  return defined($$self{toLine}) || defined($$self{toCol}); }

sub getShortSource {
  my ($self, $stringSource) = @_;
  my $source = $$self{source};
  return ($stringSource || 'String') unless ((defined $source) && $source);
  if (index($source, ':') > 1) {    # assuming legit protocols are more than 1 char (NOT windows C:/)
    my ($path, $base, $ext) = url_split($source);
    return "$base.$ext"; }
  else {
    my ($path, $base, $ext) = pathname_split($source);
    return "$base.$ext"; } }

sub toString {
  my ($self) = @_;
  my $loc = $self->getShortSource;
  $loc .= "; line $$self{fromLine}" if defined($$self{fromLine});
  $loc .= " col $$self{fromCol}"    if defined($$self{fromLine}) && defined($$self{fromCol});
  $loc .= " - line $$self{toLine}"  if defined($$self{toLine});
  $loc .= " col $$self{toCol}"      if defined($$self{toLine}) && defined($$self{toCol});
  return $loc; }

sub stringify {
  my ($self)    = @_;
  my $loc       = defined $$self{source} ? ($$self{source} || 'Literal String') : 'Anonymous String';
  my $rangeFrom = $self->isRange         ? ' from'                              : '';
  $loc .= ";$rangeFrom line $$self{fromLine}" if defined($$self{fromLine});
  $loc .= " col $$self{fromCol}"    if defined($$self{fromLine}) && defined($$self{fromCol});
  $loc .= " to line $$self{toLine}" if defined($$self{toLine});
  $loc .= " col $$self{toCol}"      if defined($$self{toLine}) && defined($$self{toCol});
  return $loc; }

sub toAttribute {
  my ($self) = @_;
  my $loc = $self->getShortSource('anonymous_string') . '#text';
  if ($self->isRange) {
    $loc .= 'range(from=';
    $loc .= "$$self{fromLine}" if defined($$self{fromLine});
    $loc .= ";$$self{fromCol}" if defined($$self{fromCol});
    $loc .= ',to=';
    $loc .= "$$self{toLine}" if defined($$self{toLine});
    $loc .= ";$$self{toCol}" if defined($$self{toCol});
    $loc .= ')';
    return $loc; }
  else {
    $loc .= 'point(';
    $loc .= "$$self{fromLine}" if defined($$self{fromLine});
    $loc .= ";$$self{fromCol}" if defined($$self{fromCol});
    $loc .= ')';
    return $loc; } }

sub getLocator {
  # getting the locator of a locator should return itself
  my ($self) = @_;
  return $self; }

sub getSource {
  my ($self) = @_;
  return $self; }

sub getFromLocator {
  my ($self) = @_;
  return LaTeXML::Common::Locator->new($$self{source}, $$self{fromLine}, $$self{fromCol}); }

sub getToLocator {
  my ($self) = @_;
  return LaTeXML::Common::Locator->new($$self{source}, $$self{toLine}, $$self{toCol}); }

#**********************************************************************
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Common::Locator> - represents a reference to a point or range in the source
file. 

=head1 DESCRIPTION

C<LaTeXML::Common::Locator> contains a reference to a point or range within a source file. 
This data structure is intended to be used both programtically (for "source references")
and to display error messages to the user. 

It extends L<LaTeXML::Common::Object>.

=head2 Locator Creation

=over 4

=item C<< $locator = LaTeXML::Common::Locator->new($source, $fromLine, $fromCol, $toLine, $toCol); >>

Creates a new locator. C<$source> should be a string containing the full path
of the source file, an empty string in case of a literal string, or undef in 
case of an anonymous string. C<$fromLine> and C<$fromCol> should be integers
containing the line and column numbers of the start of the range in the source
file, or undef if unknown. C<$toLine> and C<$toCol> should be the integers
containing the line and column numbers of the end of the range, or undef 
if a point is being refered to. 

=item C<< $locator = LaTeXML::Common::Locator->newRange($from, $to); >>

Creates a new locator, starting at the locator C<$from> and ending at the
locator C<$to>. Either locator may be undef, in which case the other one is
returned.

=back

=head2 Methods

=over 4

=item C<< $str = $locator->toString; >>

Turns this locator into a short string for output in user messages. 

=item C<< $str = $locator->stringify; >>

Turns this locator into a long string, including the full filename of the
input. 

=item C<< $attr = $locator->toAttribute; >>

Turns this locator into an XPointer expression, for usage within an XML attribute. 

=item C<< $isRange = $locator->isRange; >>

Checks if this locator points to a range or a point. 

=item C<< $source = $locator->getShortSource($stringSource); >>

Gets a short string refering to the source of this locator. 
C<$stringSource> will be used if the source refers to an
anonymous or literal string input. 

=item C<< $from = $locator->getFromLocator; >>

Gets a locator pointing to the first point in the range of this locator. 
Works for both point and range locators. 

=item C<< $from = $locator->getToLocator; >>

Gets a locator pointing to the last point in the range of this locator. 
Does not work for point locators. 

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>
Tom Wiesing <tom.wiesing@gmail.com>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
