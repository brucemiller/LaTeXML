# -*- CPERL -*-
# /=====================================================================\ #
# |  Array                                                              | #
# | Support for Lists or Arrays of digestable stuff for LaTeXML         | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Array;
use LaTeXML::Global;
use LaTeXML::Package;
use base qw(LaTeXML::Object);

# The following tokens (individual Token's or Tokens') describe how to revert the Array
#   open,close and separator are the outermost delimiter and separator between items
#   itemopen,itemclose are delimiters for each item
sub new {
  my($class,%options)=@_;
  bless {type=>$options{type},
	 open=>$options{open}, close=>$options{close}, separator=>$options{separator},
	 itemopen=>$options{itemopen}, itemclose=>$options{itemclose},
	 values=>$options{values}},$class; }

sub getValue {
  my($self,$n)=@_;
  $$self{values}[$n]; }

sub setValue {
  my($self,$n,$value)=@_;
  $$self{values}[$n]=$value; }

sub getValues {
  my($self)=@_;
  @{$$self{values}}; }

sub beDigested { 
  my($self,$stomach)=@_;
  my @v=();
  foreach my $item (@{$$self{values}}){
    # Yuck
    my $typedef = $$self{type} && $LaTeXML::Parameters::PARAMETER_TABLE{$$self{type}};
    my $dodigest = (ref $item) && (!$typedef || !$$typedef{undigested});
    my $semiverb = $dodigest && $typedef && $$typedef{semiverbatim};
    StartSemiverbatim if $semiverb;
    push(@v, ($dodigest ? $item->beDigested($stomach) : $item));
    EndSemiverbatim if $semiverb; 
  }
  (ref $self)->new(open=>$$self{open},close=>$$self{close}, separator=>$$self{separator},
		   itemopen=>$$self{itemopen},itemclose=>$$self{itemclose},
		   type=>$$self{type}, values=>[@v] ); }

sub revert {
  my($self)=@_;
  my @tokens=();
  foreach my $item (@{$$self{values}}){
    push(@tokens,$$self{separator}->unlist) if $$self{separator} && @tokens;
    push(@tokens,$$self{itemopen}->unlist) if $$self{itemopen};
    push(@tokens,Revert($item));
    push(@tokens,$$self{itemclose}->unlist) if $$self{itemclose}; }
  unshift(@tokens,$$self{open}->unlist ) if $$self{open};
  push(   @tokens,$$self{close}->unlist) if $$self{close};
  @tokens; }

sub unlist { @{$$_[0]{values}}; }		# ????

sub toString {
  my($self)=@_;
  my $string='';
  foreach my $item (@{$$self{values}}){
    $string .= ', ' if $string;
    $string .= ToString($item); }
  '[['.$string.']]'; }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Array> - support for Arrays of objects

=head1 DESCRIPTION

Provides a parser and representation of keyval pairs
C<LaTeXML::KeyVal> represents parameters handled by LaTeX's keyval package.

=head2 Methods

=over 4

=item C<< LaTeXML::Array->new(%options); >>

Creates an Array object
Options are
  values  List of values; typically Tokens, initially.
  type    The type of objects (as a ParameterType)

The following are Tokens lists that are used for reverting to raw TeX,
each can be undef
  open      the opening delimiter eg "{"
  close     the closing delimiter eg "}"
  separator the separator between items, eg ","
  itemopen  the opening delimiter for each item
  itemclose the closeing delimiter for each item

=back

=head2 Accessors

=over 4

=item C<< $value = $array->getValue($n) >>

Return the C<$n>-th item in the list.

=item C<< $array->setValue($n,$value) >>

Sets the C<$n>-th value to C<$value>.


=item C<< @values = $keyval->getValues(); >>

Return the list of values.


=item C<< $keyval->beDigested; >>

Return a new C<LaTeXML::Array> object with all values digested as appropriate.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
