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

# The main task of State is to efficiently maintain the bindings in a TeX-like fashion.
# There are two structures for this:
# table maintains the bound values.
# It is a nested hash such that
#    $$self{table}{subtable}{key} => array
# where the 0th element of the array is the current binding.
# other elements are bindings that have been superceded.
# There are subtables for catcode, value, stash,...
#
# Additionally, undo effectively records stack frames;
# It is an array of nested hashes recording which bindings need to be undone
# to pop the current stack frame, such that any defined entries
#   $$self{undo}[0]{subtable}{key}
# indicate that the given binding should be popped from table.

# $scope controls how the value is stored. It should be one of
#    global : global assignment
#    local  : in current stack frame
#    undef  : global if preceded by \global, else local
#    <other>: For any other named `stash', it will be stored in the stash list.
#             If that stash is currently active, the value will also be stored in current frame.

# options: 
#     catcodes => (standard|style|none)
#     stomach  => a Stomach object.
#     model    => a Model object.
sub new {
  my($class, %options)=@_;
  my $self = bless {table=>{}, undo=>[{}], prefixes=>{}, status=>{},
		    stomach=>$options{stomach}, model=>$options{model}}, $class; 
  $$self{table}{value}{VERBOSITY}=[0];
  if($options{catcodes} =~ /^(standard|style)/){
    # Setup default catcodes.
    my %std = ( "\\"=>   CC_ESCAPE, "{"=>    CC_BEGIN,  "}"=>    CC_END,   "\$"=>   CC_MATH,
		"\&"=>   CC_ALIGN,  "\n"=>   CC_EOL,    "#"=>    CC_PARAM,  "^"=>   CC_SUPER,
		"_"=>    CC_SUB,    " "=>    CC_SPACE,  "\t"=>   CC_SPACE,  "%"=>   CC_COMMENT,
		"~"=>    CC_ACTIVE, chr(0)=> CC_IGNORE);
    map( $$self{table}{catcode}{$_} = [$std{$_}], keys %std);
    for(my $c=ord('A'); $c <= ord('Z'); $c++){
      $$self{table}{catcode}{chr($c)} = [CC_LETTER];
      $$self{table}{catcode}{chr($c+ord('a')-ord('A'))} = [CC_LETTER];  }
  }
  if($options{catcodes} eq 'style'){
    $$self{table}{catcode}{'@'} = [CC_LETTER]; }
  $self; }

sub assign_internal {
  my($self,$subtable,$key,$value,$scope)=@_;
  my $table = $$self{table};
  $scope = ($$self{prefixes}{global} ? 'global' : 'local') unless defined $scope;
  if($scope eq 'global'){
    foreach my $undo (@{$$self{undo}}){ # remove ALL bindings of $key in $subtable's
      delete $$undo{$subtable}{$key}; }
    $$table{$subtable}{$key} = [$value]; } # And place single value in table.
  elsif($scope eq 'local'){
    $$self{undo}[0]{$subtable}{$key}++; # Note that this value must be undone
    unshift(@{$$table{$subtable}{$key}},$value); } # And push new binding.
  else {
    # print STDERR "Assigning $key in stash $stash\n";
    assign_internal($self,'stash',$scope,[],'global') unless $$table{stash}{$scope}[0];
    push(@{ $$table{stash}{$scope}[0] }, [$subtable,$key,$value]);
    assign_internal($self,$subtable,$key,$value,'local')
      if $$table{stash_active}{$scope}[0];
  }}

#======================================================================
sub getStomach { $_[0]->{stomach}; }
sub getModel   { $_[0]->{model}; }

#======================================================================

# Lookup & assign a general Value
sub lookupValue { $_[0]->{table}{value}{$_[1]}[0]; }
sub assignValue { assign_internal($_[0],'value',$_[1], $_[2],$_[3]); }

sub pushValue {
  my($self,$key,@values)=@_;
  my $vtable = $$self{table}{value};
  assign_internal($self,'value',$key,[],'global') unless $$vtable{$key}[0];
  push(@{$$vtable{$key}[0]},@values); }

sub popValue {
  my($self,$key)=@_;
  my $vtable = $$self{table}{value};
  assign_internal($self,'value',$key,[],'global') unless $$vtable{$key}[0];
  pop(@{$$vtable{$key}[0]}); }

sub unshiftValue {
  my($self,$key,@values)=@_;
  my $vtable = $$self{table}{value};
  assign_internal($self,'value',$key,[],'global') unless $$vtable{$key}[0];
  unshift(@{$$vtable{$key}[0]},@values); }

sub shiftValue {
  my($self,$key)=@_;
  my $vtable = $$self{table}{value};
  assign_internal($self,'value',$key,[],'global') unless $$vtable{$key}[0];
  shift(@{$$vtable{value}{$key}[0]}); }

sub lookupStackedValues { 
  my $stack = $_[0]->{table}{value}{$_[1]};
  ($stack ? @$stack : ()); }

#======================================================================
# Was $name bound?  If  $frame is given, check only whether it is bound in 
# that frame (0 is the topmost).
sub isValueBound {
  my($self,$key,$frame)=@_;
  (defined $frame ? $$self{undo}[$frame]{value}{$key} : defined $$self{table}{value}{$key}[0]); }

#======================================================================
# Lookup & assign a character's Catcode
sub lookupCatcode { $_[0]->{table}{catcode}{$_[1]}[0]; }
sub assignCatcode { assign_internal($_[0],'catcode',$_[1], $_[2],$_[3]); }

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
  my $table = $$self{table};
  # Should there be a separate subtable for catcode:math ?
  if($executable_cc[$cc]
     || ($$table{value}{IN_MATH}[0] && $$table{catcode}{'math:'.$cs}[0])){
    $$table{meaning}{$token->getCSName}[0]; }
  else {
    $token; }}

sub assignMeaning {
  my($self,$token,$definition,$scope)=@_;
  assign_internal($self,'meaning',$token->getCSName => $definition, $scope); }

sub lookupDefinition {
  my($self,$token)=@_;
  my $defn = $self->lookupMeaning($token);
  (defined $defn && $defn->isaDefinition ? $defn : undef); }

# And a shorthand for installing definitions
sub installDefinition {
  my($self,$definition,$scope)=@_;
  assign_internal($self,'meaning',$definition->getCS->getCSName => $definition, $scope); }

#======================================================================
sub pushFrame {
  my($self,$nobox)=@_;
  # Easy: just push a new undo hash.
  unshift(@{$$self{undo}},{}); }

sub popFrame {
  my($self)=@_;
  my $table = $$self{table};
  my $undo = shift(@{$$self{undo}});
  foreach my $subtable (keys %$undo){
    my $undosubtable = $$undo{$subtable};
    foreach my $name (keys %$undosubtable){
      map( shift(@{$$table{$subtable}{$name}}), 1..$$undosubtable{$name}); }}
}

#======================================================================
# Set one of the definition prefixes global, etc (only global matters!)
sub setPrefix     { $_[0]->{prefixes}{$_[1]} = 1; }
sub clearPrefixes { $_[0]->{prefixes} = {}; }

#======================================================================

sub activateScope {
  my($self,$scope)=@_;
  my $table = $$self{table};
  if(! $$table{stash_active}{$scope}[0]){
    assign_internal($self,'stash_active',$scope, 1, 'local');
    if(defined (my $defns = $$table{stash}{$scope}[0])){
      my $frame = $$self{undo}[0];
      foreach my $entry (@$defns){
	my($subtable,$key,$value)=@$entry;
	$$frame{$subtable}{$key}++; # Note that this value must be undone
	unshift(@{$$table{$subtable}{$key}},$value); }}}} # And push new binding.

sub deactivateScope {
  my($self,$scope)=@_;
  my $table = $$self{table};
  if( $$table{stash_active}{$scope}[0]){
    assign_internal($self,'stash_active',$scope, 0, 'global');
    if(defined (my $defns = $$table{stash}{$scope}[0])){
      my $frame = $$self{undo}[0];
      foreach my $entry (@$defns){
	my($subtable,$key,$value)=@$entry;
	if($$table{$subtable}{$key}[0] eq $value){
	  shift(@{$$table{$subtable}{$key}});
	  $$frame{$subtable}{$key}--; }
	else {
	  Warn(":internal Unassigning $subtable:$key from $value, but stack is "
	       .join(', ',@{$$table{$subtable}{$key}})); }}}}}

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
      Warn(":expected:<unit> Unknown unit \"$unit\"; assuming pt.");
      $sp = $UNITS{'pt'}; }
    $sp; }}

#======================================================================

sub noteStatus {
  my($self,$type,@data)=@_;
  if($type eq 'undefined'){
    map($$self{status}{undefined}{$_}++, @data); }
  elsif($type eq 'missing'){
    map($$self{status}{missing}{$_}++, @data); }
  else {
    $$self{status}{$type}++; }}

sub getStatus {
  my($self,$type)=@_;
  $$self{status}{$type}; }

sub getStatusMessage {
  my($self)=@_;
  my $status= $$self{status};
  my @report=();
  push(@report, "$$status{warning} warning".($$status{warning}>1?'s':''))
    if $$status{warning};
  push(@report, "$$status{error} error".($$status{error}>1?'s':''))
    if $$status{error};
  push(@report, "$$status{fatal} fatal error".($$status{fatal}>1?'s':''))
    if $$status{fatal};
  my @undef = ($$status{undefined} ? keys %{$$status{undefined}} :());
  push(@report, scalar(@undef)." undefined macro".(@undef > 1 ? 's':'')
       ."[".join(', ',@undef)."]")
    if @undef;
  my @miss = ($$status{missing} ? keys %{$$status{missing}} :());
  push(@report, scalar(@miss)." missing file".(@miss > 1 ? 's':'')
       ."[".join(', ',@miss)."]")
    if @miss;
  join('; ', @report) || 'No obvious problems'; }

#======================================================================
1;


__END__

=pod 

=head1 NAME

C<LaTeXML::State> - stores the current state of processing.

=head1 DESCRIPTION

A C<LaTeXML::State> object stores the current state of processing.
It recording catcodes, variables values, definitions and so forth,
as well as mimicing TeX's scoping rules.

=head2 Access to State and Processing

=over 4

=item C<< $STATE->getStomach; >>

Returns the current Stomach used for digestion.

=item C<< $STATE->getModel; >>

Returns the current Model representing the document model.

=back

=head2 Scoping

The assignment methods, described below, generally take a C<$scope> argument, which
determines how the assignment is made.  The allowed values and thier implications are:

 global   : global assignment.
 local    : local assignment, within the current grouping.
 undef    : global if \global preceded, else local (default)
 <name>   : stores the assignment in a `scope' which
            can be loaded later.

If no scoping is specified, then the assignment will be global
if a preceding C<\global> has set the global flag, otherwise
the value will be assigned within the current grouping.

=over 4

=item C<< $STATE->pushFrame; >>

Starts a new level of grouping.
Note that this is lower level than C<\bgroup>; See L<LaTeXML::Stomach>.

=item C<< $STATE->popFrame; >>

Ends the current level of grouping.
Note that this is lower level than C<\egroup>; See L<LaTeXML::Stomach>.

=item C<< $STATE->setPrefix($prefix); >>

Sets a prefix (eg. C<global> for C<\global>, etc) for the next operation, if applicable.

=item C<< $STATE->clearPrefixes; >>

Clears any prefixes.

=back

=head2 Values

=over 4

=item C<< $value = $STATE->lookupValue($name); >>

Lookup the current value associated with the the string C<$name>.

=item C<< $STATE->assignValue($name,$value,$scope); >>

Assign $value to be associated with the the string C<$name>, according
to the given scoping rule.

Values are also used to specify most configuration parameters (which can
therefor also be scoped).  The recognized configuration parameters are:

 VERBOSITY         : the level of verbosity for debugging
                     output, with 0 being default.
 STRICT            : whether errors (eg. undefined macros)
                     are fatal.
 INCLUDE_COMMENTS  : whether to preserve comments in the
                     source, and to add occasional line
                     number comments. (Default true).
 PRESERVE_NEWLINES : whether newlines in the source should
                     be preserved (not 100% TeX-like).
                     By default this is true.
 SEARCHPATHS       : a list of directories to search for
                     sources, implementations, etc.

=item C<< $STATE->pushValue($name,$value); >>

This is like C<< ->assign >>, but pushes a value onto the end of the stored value,
which should be a LIST reference.
Scoping is not handled here (yet?), it simply pushes the value
onto the last binding of C<$name>.

=item C<< $boole = $STATE->isValuebound($type,$name,$frame); >>

Returns whether the value C<$name> is bound. If  C<$frame> is given, check
whether it is bound in the C<$frame>-th frame, with 0 being the top frame.

=back

=head2 Category Codes

=over 4

=item C<< $value = $STATE->lookupCatcode($char); >>

Lookup the current catcode associated with the the character C<$char>.

=item C<< $STATE->assignCatcode($char,$catcode,$scope); >>

Set C<$char> to have the given C<$catcode>, with the assignment made
according to the given scoping rule.

This method is also used to specify whether a given character is
active in math mode, by using C<math:$char> for the character,
and using a value of 1 to specify that it is active.

=back

=head2 Definitions

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

=head2 Named Scopes

Named scopes can be used to set variables or redefine control sequences within
a scope other than the standard TeX grouping. For example, the LaTeX implementation
will automatically activate any definitions that were defined with a named
scope of, say "section:4", during the portion of the document that has
the section counter equal to 4.  Similarly, a scope named "label:foo" will
be activated in portions of the document where C<\label{foo}> is in effect.

=over 4

=item C<< $STATE->activateScope($scope); >>

Installs any definitions that were associated with the named C<$scope>.
Note that these are placed in the current grouping frame and will disappear when that
grouping ends.

=item C<< $STATE->deactivateScope($scope); >>

Removes any definitions that were associated with the named C<$scope>.
Normally not needed, since a scopes definitions are locally bound anyway.

=item C<< $sp = $STATE->convertUnit($unit); >>

Converts a TeX unit of the form C<'10em'> (or whatever TeX unit) into
scaled points.  (Defined here since in principle it could track the
size of ems and so forth (but currently doesn't))

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
