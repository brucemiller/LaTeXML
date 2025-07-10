# /=====================================================================\ #
# |  LaTeXML::Core::List                                                | #
# | Digested objects produced in the Stomach                            | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::List;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Common::Dimension;
use List::Util qw(min max);
use base       qw(Exporter LaTeXML::Core::Box);
our @EXPORT = (qw(&List));

# Tricky; don't really want a separate constructor for a Math List,
# but you really have to specify it in the arguments
# BUT you can't infer the mode from the current state ($STATE may have already switched
#  back to text) or from the modes of the boxes (may be mixed)
# So, it has to be specified along with the boxes;
# Here we simply allow
#    List($box,.... mode=>'math')
# Also, if there's only 1 box, we just return it!
sub List {
  my (@boxes) = @_;
  my $mode;
  # Check for Hacky mode argument!!!
  if ((scalar(@boxes) >= 2) && ($boxes[-2] eq 'mode')) {
    $mode = pop(@boxes); pop(@boxes); }
  else {
    $mode = $STATE->lookupValue('MODE'); } # HOPEFULLY, mode hasn't changed by now?
  @boxes = grep { defined $_ } @boxes;    # strip out undefs
  # Simplify single box, IFF NOT vertical list or box IS vertical
  if ((scalar(@boxes) == 1)
      && (!$mode || ($mode !~ /vertical$/)
          || (($boxes[0]->getProperty('mode')||'') =~ /vertical$/))) {
    return $boxes[0]; }                   # Simplify!
  else {
    # Flatten horizontal lists within horizontal lists
    if($mode eq 'horizontal'){
      @boxes = map { ((ref $_ eq 'LaTeXML::Core::List')
                      && (($_->getProperty('mode')||'') eq 'horizontal')
                      ? $_->unlist : $_); } @boxes; }
    my $list = LaTeXML::Core::List->new(@boxes);
    $list->setProperty(mode => $mode);
    $list->setProperty(width => LaTeXML::Package::LookupRegister('\hsize'))
        if $mode eq 'horizontal';
    return $list; } }

sub new {
  my ($class, @boxes) = @_;
  my ($bx, $font, $locator);
  my @bxs = @boxes;
  while (defined($bx = shift(@bxs)) && (!defined $locator)) {
    $locator = $bx->getLocator unless defined $locator; }
  @bxs = @boxes;
  # Maybe the most representative font for a List is the font of the LAST box (that _has_ a font!) ???
  while (defined($bx = pop(@bxs)) && (!defined $font)) {
    $font = $bx->getFont unless defined $font; }
  #return bless [[@boxes], $font, $locator || '', undef, {}], $class; }
  return bless { boxes => [@boxes],
    properties => { font => $font, locator => $locator || undef, }
  }, $class; }

sub unlist {
  my ($self) = @_;
  return @{ $$self{boxes} }; }

sub revert {
  no warnings 'recursion';
  my ($self) = @_;
  return map { $_->revert } $self->unlist; }

sub toString {
  my ($self) = @_;
  return join('', grep { defined $_ } map { $_->toString } $self->unlist); }

sub toAttribute {
  my ($self) = @_;
  return join('', grep { defined $_ } map { $_->toAttribute } $self->unlist); }

# Methods for overloaded operators
sub stringify {
  no warnings 'recursion';
  my ($self) = @_;
  return $self->_stringify . '[' . join(',', map { Stringify($_) } $self->unlist) . ']'; }

sub equals {
  my ($a, $b) = @_;
  return 0 unless (defined $b) && ((ref $a) eq (ref $b));
  my @a = $a->unlist;
  my @b = $b->unlist;
  while (@a && @b && ($a[0]->equals($b[0]))) {
    shift(@a); shift(@b); }
  return !(@a || @b); }

# NOTE: No longer used; Document->absorb bypasses this for stack efficiency.
sub beAbsorbed {
  my ($self, $document) = @_;
  no warnings 'recursion';
  return map { $document->absorb($_) } $self->unlist; }

sub computeSize {
  no warnings 'recursion';
  my ($self, %options) = @_;
  my $font = $self->getProperty('font') || LaTeXML::Common::Font->textDefault;
  return $font->computeBoxesSize($self, %options); }
#======================================================================
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Core::List> - represents lists of digested objects;
extends L<LaTeXML::Core::Box>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
