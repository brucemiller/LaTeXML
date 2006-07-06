# /=====================================================================\ #
# |  LaTeXML::State                                                     | #
# | Maintains state: bindings, valuse, grouping                         | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::State;
use strict;
use LaTeXML::Global;

# Naming scheme for keys (such as it is)
#    binding:<cs>  : the definition associated with <cs>
#    value:<name>  : some data stored under <name>
#                  With TeX Registers/Parameters, the name begins with "\"
#    internal:<name> : Some internally interesting state.

# $scope controls how the value is stored. It should be one of
#    global : global assignment
#    local  : in current stack frame
#    undef  : global if preceded by \global, else local
#    <other>: For any other named `stash', it will be stored in the stash list.
#             If that stash is currently active, the value will also be stored in current frame.

# options: catcodes => (standard|style|none)
sub new {
  my($class, %options)=@_;
  my $self = bless {table=>{}, undo=>[{}], prefixes=>{} }, $class; 
  if($options{catcodes} =~ /^(standard|style)/){
    # Setup default catcodes.
    my %std = ( "\\"=>   CC_ESCAPE, "{"=>    CC_BEGIN,  "}"=>    CC_END,   "\$"=>   CC_MATH,
		"\&"=>   CC_ALIGN,  "\n"=>   CC_EOL,    "#"=>    CC_PARAM,  "^"=>   CC_SUPER,
		"_"=>    CC_SUB,    " "=>    CC_SPACE,  "\t"=>   CC_SPACE,  "%"=>   CC_COMMENT,
		"~"=>    CC_ACTIVE, chr(0)=> CC_IGNORE);
    map( $$self{table}{'catcode:'.$_} = [$std{$_}], keys %std);
    for(my $c=ord('A'); $c <= ord('Z'); $c++){
      $$self{table}{'catcode:'.chr($c)} = [CC_LETTER];
      $$self{table}{'catcode:'.chr($c+ord('a')-ord('A'))} = [CC_LETTER];  }
  }
  if($options{catcodes} eq 'style'){
    $$self{table}{'catcode:@'} = [CC_LETTER]; }
#  $$self{table}{'internal:active_stashes'} = [{}];
  $self; }

sub lookup {
  my($self,$type,$name)=@_;
  $$self{table}{$type.':'.$name}[0]; }

sub assign {
  my($self,$type,$name,$value,$scope)=@_;
  my $key = $type.':'.$name; 
  $scope = ($$self{prefixes}{global} ? 'global' : 'local') unless defined $scope;
  if($scope eq 'global'){
    foreach my $undo (@{$$self{undo}}){ # These no longer should get undone.
      delete $$undo{$key};}
    $$self{table}{$key} = [$value]; } # And place single value in table.
  elsif($scope eq 'local'){
    $$self{undo}[0]{$key}++; # Note that this value must be undone
    unshift(@{$$self{table}{$key}},$value); } # And push new binding.
  else {
    my $stash = 'stash:'.$scope;
    # print STDERR "Assigning $key in stash $stash\n";
    assign($self,'stash',$scope,[],'global') unless $$self{table}{$stash}[0];
    push(@{ $$self{table}{$stash}[0] }, [$key,$value]); 
    assign($self,$type,$name,$value,'local') 
      if $$self{table}{'internal:stash_active_'.$scope}[0];
#      if $$self{table}{'internal:active_stashes'}[0]{$scope};
  }}

sub push {
  my($self,$type,$name,@values)=@_;
  unshift(@{$$self{table}{$type.':'.$name}[0]},@values); }

#======================================================================
# Specialized versions of lookup & assign for dealing with definitions

our @executable_cc= (0,1,1,1, 1,0,0,1, 1,0,0,0, 0,1,0,0, 1,0);

# Get the `Meaning' of a token.  For a control sequence or otherwise active token,
# this may give the definition object or a regular token (if it was \let), or undef.
# Otherwise, the token itself is returned.
sub lookupMeaning {
  my($self,$token)=@_;
  # NOTE: Inlined token accessors!!!
  my $cs = $$token[0];
  my $cc = $$token[1];
  if($executable_cc[$cc]
     || ($self->lookup('internal','math_mode') &&  $self->lookup('mathactive',$cs))){
    $self->lookup('binding',$token->getCSName) }
  else {
    $token; }}

sub assignMeaning {
  my($self,$token,$definition,$scope)=@_;
  $self->assign('binding', $token->getCSName => $definition, $scope); }

# And a shorthand for installing definitions
sub installDefinition {
  my($self,$definition,$scope)=@_;
  $self->assign('binding',$definition->getCS->getCSName => $definition, $scope); }

#======================================================================
# Was $key bound in the $frame-th frame from the top? (default: top frame)
sub boundInFrame {
  my($self,$type,$name,$frame)=@_;
  $$self{undo}[$frame || 0]{$type.':'.$name}; }

#======================================================================
sub pushFrame {
  my($self,$nobox)=@_;
  # Easy: just push a new undo hash.
  unshift(@{$$self{undo}},{}); }

sub popFrame {
  my($self)=@_;
  my $undo = shift(@{$$self{undo}});
  foreach my $key (keys %$undo){
    map( shift(@{$$self{table}{$key}}), 1..$$undo{$key}); }
}

#======================================================================
# Set one of the definition prefixes global, etc (only global matters!)
sub setPrefix     { $_[0]->{prefixes}{$_[1]} = 1; }
sub clearPrefixes { $_[0]->{prefixes} = {}; }

#======================================================================

sub activateScope {
  my($self,$scope)=@_;
#  if(! $$self{table}{'internal:active_stashes'}[0]{$scope}){
  if(! $$self{table}{'internal:stash_active_'.$scope}[0]){
    $self->assign('internal','stash_active_'.$scope, 1, 'local');
    if(defined (my $defns = $$self{table}{'stash:'.$scope}[0])){
      foreach my $entry (@$defns){
	my($key,$value)=@$entry;
	$$self{undo}[0]{$key}++; # Note that this value must be undone
	unshift(@{$$self{table}{$key}},$value); }}}} # And push new binding.

sub deactivateScope {
  my($self,$scope)=@_;
#  if( $$self{table}{'internal:active_stashes'}[0]{$scope}){
  if( $$self{table}{'internal:stash_active_'.$scope}[0]){
    $self->assign('internal','stash_active_'.$scope, 0, 'global');
  #   print STDERR "DEActivating stash $key: ".join(', ',map($_->[0]."=>".$_->[1], @{$$self{table}{$key}[0] || []}))."\n";
#    delete $$self{table}{'internal:active_stashes'}[0]{$scope};
    if(defined (my $defns = $$self{table}{'stash:'.$scope}[0])){
      foreach my $entry (@$defns){
	my($key,$value)=@$entry;
	if($$self{table}{$key}[0] eq $value){
	  shift(@{$$self{table}{$key}});
	  $$self{undo}[0]{$key}--; }
	else {
	  Warn("Unassigning $key from $value, but stack is ".join(', ',@{$$self{table}{$key}})); }}}}}
#======================================================================
# Units.
#   Put here since it could concievably evolve to depend on the current font.

# Conversion to scaled points
our %UNITS= (pt=>65536, pc=>12*65536, in=>72.27*65536, bp=>72.27*65536/72, 
	     cm=>72.27*65536/2.54, mm=>72.27*65536/2.54/10, dd=>1238*65536/1157,
	     cc=>12*1238*65536/1157, sp=>1);

sub convertUnit {
  my($self,$unit)=@_;
  $unit = lc($unit);
  # Eventually try to track font size?
  if   ($unit eq 'em'){ 10.0 * 65536; }
  elsif($unit eq 'ex'){  4.3 * 65536; }
  elsif($unit eq 'mu'){ 10.0 * 65536 / 18; }
  else{
    my $sp = $UNITS{$unit}; 
    if(!$sp){
      Warn("Unknown unit \"$unit\"; assuming pt.");
      $sp = $UNITS{'pt'}; }
    $sp; }}

#======================================================================
1;


__END__

=pod 

=head1 LaTeXML::State

=head2 DESCRIPTION

C<LaTeXML::State> stores the current state of processing during expansion and
digestion.

=head2 Methods

=over 4

=item C<< $defn = $STATE->lookupMeaning($token); >>

Get the "meaning" currently associated with C<$token>,
either the definition (if it is a control sequence or active character)
 or the token itself if it shouldn't be executable.
(See L<LaTeXML::Definition>)

=item C<< $STATE->assignMeaning($token,$defn,$scope); >>

Set the definition associated with C<$token> to C<$defn>.
If C<$globally> is true, it makes this the global definition
rather than bound within the current group.
(See L<LaTeXML::Definition>, and L<LaTeXML::Package>)

=item C<< $STATE->installDefinition($definition, $scope); >>

Install the definition into the current stack frame under its normal control sequence.


=back

=cut
