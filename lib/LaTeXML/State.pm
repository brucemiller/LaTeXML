# /=====================================================================\ #
# |  LaTeXML::State                                                     | #
# | Maintains state: bindings, values, grouping                         | #
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
use warnings;
use LaTeXML::Global;

# Naming scheme for keys (such as it is)
#    binding:<cs>  : the definition associated with <cs>
#    value:<name>  : some data stored under <name>
#                  With TeX Registers/Parameters, the name begins with "\"
#    internal:<name> : Some internally interesting state.

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# The State efficiently maintain the bindings in a TeX-like fashion.
# bindings associate data with keys (eg definitions with macro names)
# and respect TeX grouping; that is, an assignment is only in effect
# until the current group (opened by \bgroup) is closed (by \egroup).
#----------------------------------------------------------------------
# The objective is to make the following, most-common, operations FAST:
#   begin & end a group (ie. push/pop a stack frame)
#   lookup & assignment of values
# With the more obvious approach, a "stack of frames", either lookup would involve
# checking a sequence of frames until the current value is found;
# or, starting a new frame would involve copying bindings for all values
# I never quite studied how Knuth does it;
# The following structures allow these to be constant operations (usually),
# except for endgroup (which is linear in # of changed values in that frame).

# There are 2 main structures used here.
# For each $subtable (being "value", "meaning" or other space of names),
# "table" maintains the bound values, and "undo" defines the stack frames:
#    $$self{table}{$subtable}{$key} = [$current_value, $previous_value, ...]
#    $$self{undo}[$frame]{$subtable}{$key} = (undef | $n)
# such that the "current value" associated with $key is the 0th element of the table array;
# the $previous_value's (if any) are values that had been assigned within previous groups.
# The undo list indicates how many values have been assigned for $key in
# the $frame'th frame (usually 0 is the one of interest).
# [Would be simpler to store boolean in undo, but see deactivateScope]
# [All keys fo $$self{undo}[$frame} are subtable names, EXCEPT "_FRAME_LOCK_"!!]
#
# So, in handwaving form, the algorithms are as follows:
# push-frame == bgroup == begingroup:
#    push an empty hash {} onto the undo stack;
# pop-frame == egroup == endgroup:
#   for the $n associated with every key in the topmost hash in the undo stack
#     pop $n values from the table
#   then remove the hash from the undo stack.
# Lookup value:
#   we simply fetch the 0th element from the table
# Assign a value:
#   local scope (the normal way):
#     we push a new value into the table described above,
#     and also increment the associated value in the undo stack
#   global scope:
#     remove any locally scoped values, and undo entries for the key
#     then set the 0th (only remaining) value to the given one.
#   named-scope $scope:
#      push an entry [$subtable,$key,$value] globally to the 'stash' subtable's value.
#      And assign locally, if the $scope is active (has non-zero value in stash_active subtable),
#
# There are subtables for
#  catcode: keys are char;
#         Also, "math:$char" =1 when $char is active in math.
#  value: keys are anything (typically a string, though) and value is the value associated with it
#         some special cases? "Boolean:$cs",...
#  meaning: The definition assocated with $key, usually a control-sequence.
#  stash & stash_active: support named scopes
#      (see also activateScope & deactivateScope)
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# options:
#     catcodes => (standard|style|none)
#     stomach  => a Stomach object.
#     model    => a Mod el object.
sub new {
  my ($class, %options) = @_;
  my $self = bless { table => {}, undo => [{ _FRAME_LOCK_ => 1 }], prefixes => {}, status => {},
    stomach => $options{stomach}, model => $options{model} }, $class;
  $$self{table}{value}{VERBOSITY} = [0];
  if ($options{catcodes} =~ /^(standard|style)/) {
    # Setup default catcodes.
    my %std = ("\\" => CC_ESCAPE, "{" => CC_BEGIN, "}" => CC_END, "\$" => CC_MATH,
      "\&" => CC_ALIGN, "\r" => CC_EOL,   "#"  => CC_PARAM, "^" => CC_SUPER,
      "_"  => CC_SUB,   " "  => CC_SPACE, "\t" => CC_SPACE, "%" => CC_COMMENT,
      "~" => CC_ACTIVE, chr(0) => CC_IGNORE);
    map { $$self{table}{catcode}{$_} = [$std{$_}] } keys %std;
    for (my $c = ord('A') ; $c <= ord('Z') ; $c++) {
      $$self{table}{catcode}{ chr($c) } = [CC_LETTER];
      $$self{table}{catcode}{ chr($c + ord('a') - ord('A')) } = [CC_LETTER]; }
  }
  $$self{table}{value}{SPECIALS} = [['^', '_', '@', '~', '&', '$', '#', '%', "'"]];
  if ($options{catcodes} eq 'style') {
    $$self{table}{catcode}{'@'} = [CC_LETTER]; }
  $$self{table}{mathcode} = {};
  $$self{table}{sfcode}   = {};
  $$self{table}{lccode}   = {};
  $$self{table}{uccode}   = {};
  $$self{table}{delcode}  = {};
  return $self; }

sub assign_internal {
  my ($self, $subtable, $key, $value, $scope) = @_;
  my $table = $$self{table};
  $scope = ($$self{prefixes}{global} ? 'global' : 'local') unless defined $scope;
  if ($scope eq 'global') {
## This was was sufficient before having lockable frames
##    foreach my $undo (@{$$self{undo}}){ # remove ALL bindings of $key in $subtable's
##      delete $$undo{$subtable}{$key}; }
##    $$table{$subtable}{$key} = [$value]; } # And place SINGLE value in table.
    # Remove bindings made in all frames down-to & including the next lower locked frame
###    foreach my $undo (@{$$self{undo}}){ # remove ALL bindings of $key in $subtable's
    my $frame;
    my @frames = @{ $$self{undo} };
    while (@frames) {
      $frame = shift(@frames);
      if (my $n = $$frame{$subtable}{$key}) {    # Undo the bindings, if $key was bound in this frame
        map { shift(@{ $$table{$subtable}{$key} }) } 1 .. $n if $n;
        delete $$frame{$subtable}{$key}; }
      last if $$frame{_FRAME_LOCK_}; }
    # whatever is left -- if anything -- should be bindings below the locked frame.
    $$frame{$subtable}{$key}++;    # Note that this many values -- ie. one more -- must be undone
    unshift(@{ $$table{$subtable}{$key} }, $value); }
  elsif ($scope eq 'local') {
    $$self{undo}[0]{$subtable}{$key}++;   # Note that this many values -- ie. one more -- must be undone
    unshift(@{ $$table{$subtable}{$key} }, $value); }    # And push new binding.
  else {
    # print STDERR "Assigning $key in stash $stash\n";
    assign_internal($self, 'stash', $scope, [], 'global') unless $$table{stash}{$scope}[0];
    push(@{ $$table{stash}{$scope}[0] }, [$subtable, $key, $value]);
    assign_internal($self, $subtable, $key, $value, 'local')
      if $$table{stash_active}{$scope}[0];  }
  return; }

#======================================================================
sub getStomach {
  my($self)=@_;
  return $$self{stomach}; }
sub getModel   {
  my($self)=@_;
  return $$self{model}; }

#======================================================================

# Lookup & assign a general Value
# [Note that the more direct $_[0]->{table}{value}{$_[1]}[0]; works, but creates entries
# this could concievably cause space issues, but timing doesn't show improvements this way]
sub lookupValue {
  my ($self, $key)=@_;
  my $e = $$self{table}{value}{$key};
  return $e && $$e[0]; }

sub assignValue {
  my($self, $key, $value, $scope)=@_;
  assign_internal($self, 'value', $key, $value, $scope);
  return; }

# manage a (global) list of values
sub pushValue {
  my ($self, $key, @values) = @_;
  my $vtable = $$self{table}{value};
  assign_internal($self, 'value', $key, [], 'global') unless $$vtable{$key}[0];
  push(@{ $$vtable{$key}[0] }, @values); 
  return; }

sub popValue {
  my ($self, $key) = @_;
  my $vtable = $$self{table}{value};
  assign_internal($self, 'value', $key, [], 'global') unless $$vtable{$key}[0];
  return pop(@{ $$vtable{$key}[0] }); }

sub unshiftValue {
  my ($self, $key, @values) = @_;
  my $vtable = $$self{table}{value};
  assign_internal($self, 'value', $key, [], 'global') unless $$vtable{$key}[0];
  unshift(@{ $$vtable{$key}[0] }, @values); 
  return; }

sub shiftValue {
  my ($self, $key) = @_;
  my $vtable = $$self{table}{value};
  assign_internal($self, 'value', $key, [], 'global') unless $$vtable{$key}[0];
  return shift(@{ $$vtable{$key}[0] }); }

# manage a (global) hash of values
sub lookupMapping {
  my ($self, $map, $key) = @_;
  my $vtable  = $$self{table}{value};
  my $mapping = $$vtable{$map}[0];
  return ($mapping ? $$mapping{$key} : undef); }

sub assignMapping {
  my ($self, $map, $key, $value) = @_;
  my $vtable = $$self{table}{value};
  assign_internal($self, 'value', $map, {}, 'global') unless $$vtable{$map}[0];
  if (!defined $value) {
    delete $$vtable{$map}[0]{$key}; }
  else {
    $$vtable{$map}[0]{$key} = $value; } 
  return; }

sub lookupMappingKeys {
  my ($self, $map) = @_;
  my $vtable  = $$self{table}{value};
  my $mapping = $$vtable{$map}[0];
  return ($mapping ? sort keys %$mapping : ()); }

sub lookupStackedValues {
  my ($self, $key) = @_;
  my $stack = $$self{table}{value}{$key};
  return ($stack ? @$stack : ()); }

#======================================================================
# Was $name bound?  If  $frame is given, check only whether it is bound in
# that frame (0 is the topmost).
sub isValueBound {
  my ($self, $key, $frame) = @_;
  return (defined $frame ? $$self{undo}[$frame]{value}{$key}
            : defined $$self{table}{value}{$key}[0]); }

#======================================================================
# Lookup & assign a character's Catcode
sub lookupCatcode {
  my ($self, $key)=@_;
  my $e = $$self{table}{catcode}{$key};
  return $e && $$e[0]; }

sub assignCatcode {
  my($self, $key, $value, $scope)=@_;
  assign_internal($self, 'catcode', $key, $value, $scope);
  return; }

# The following rarely used.
sub lookupMathcode {
  my($self, $key)=@_;
  my $e = $$self{table}{mathcode}{$key};
  return $e && $$e[0]; }

sub assignMathcode {
  my($self, $key, $value, $scope)=@_;
  assign_internal($self, 'mathcode', $key, $value, $scope);
  return; }

sub lookupSFcode {
  my($self, $key)=@_;
  my $e = $$self{table}{sfcode}{$key};
  return $e && $$e[0]; }

sub assignSFcode {
  my($self, $key, $value, $scope)=@_;
  assign_internal($self, 'sfcode', $key, $value, $scope);
  return; }

sub lookupLCcode {
  my($self, $key)=@_;
  my $e = $$self{table}{lccode}{$key};
  return $e && $$e[0]; }

sub assignLCcode {
  my($self, $key, $value, $scope)=@_;
  assign_internal($self, 'lccode', $key, $value, $scope);
  return; }

sub lookupUCcode {
  my($self,$key)=@_;
  my $e = $$self{table}{uccode}{$key};
  return $e && $$e[0]; }

sub assignUCcode {
  my($self, $key, $value, $scope)=@_;
  assign_internal($self, 'uccode', $key, $value, $scope);
  return; }

sub lookupDelcode {
  my($self, $key)=@_;
  my $e = $$self{table}{delcode}{$key};
  return $e && $$e[0]; }

sub assignDelcode {
  my($self, $key, $value, $scope)=@_;
  assign_internal($self, 'delcode', $key, $value, $scope);
  return; }

#======================================================================
# Specialized versions of lookup & assign for dealing with definitions

# Get the `Meaning' of a token.  For a control sequence or otherwise active token,
# this may give the definition object or a regular token (if it was \let), or undef.
# Otherwise, the token itself is returned.
sub lookupMeaning {
  my ($self, $token) = @_;
  if (my $cs = $token && $token->getExecutableName) {
    my $e = $$self{table}{meaning}{$cs}; return $e && $$e[0]; }
  else { return $token; } }

sub lookupMeaning_internal {
  my ($self, $token) = @_;
  my $e = $$self{table}{meaning}{ $token->getCSName };
  return $e && $$e[0]; }

sub assignMeaning {
  my ($self, $token, $definition, $scope) = @_;
  assign_internal($self, 'meaning', $token->getCSName => $definition, $scope); 
  return; }

sub lookupDefinition {
  my ($self, $token) = @_;
  my $x;
  return (($x = $token->getExecutableName) && ($x = $$self{table}{meaning}{$x}) && ($x = $$x[0])
            && $x->isaDefinition
            ? $x : undef); }

# And a shorthand for installing definitions
sub installDefinition {
  my ($self, $definition, $scope) = @_;
  # Locked definitions!!! (or should this test be in assignMeaning?)
  # Ignore attempts to (re)define $cs from tex sources
  my $cs = $definition->getCS->getCSName;
  if ($self->lookupValue("$cs:locked") && !$LaTeXML::State::UNLOCKED) {
    if (my $s = $self->getStomach->getGullet->getSource) {
      if (($s eq "Anonymous String") || ($s =~ /\.(tex|bib)$/)) {
        Info('ignore', $cs, $self->getStomach, "Ignoring redefinition of $cs");
        return; } } }
  assign_internal($self, 'meaning', $cs => $definition, $scope); 
  return; }

#======================================================================
sub pushFrame {
  my ($self, $nobox) = @_;
  # Easy: just push a new undo hash.
  unshift(@{ $$self{undo} }, {}); 
  return; }

sub popFrame {
  my ($self) = @_;
  my $table = $$self{table};
  if ($$self{undo}[0]{_FRAME_LOCK_}) {
    Fatal('unexpected', '<endgroup>', $self->getStomach,
      "Attempt to pop last locked stack frame"); }
  else {
    my $undo = shift(@{ $$self{undo} });
    foreach my $subtable (keys %$undo) {
      my $undosubtable = $$undo{$subtable};
      foreach my $name (keys %$undosubtable) {
        map { shift(@{ $$table{$subtable}{$name} }) } 1 .. $$undosubtable{$name}; } } }
  return; }

#======================================================================

sub pushDaemonFrame {
  my ($self) = @_;
  unshift(@{ $$self{undo} }, {});
  # Push copys of data for any data that is mutable;
  # Only the value & stash subtables need to be to be checked.
  foreach my $subtable (qw(value stash)) {
    if (my $hash = $$self{table}{$subtable}) {
      foreach my $key (keys %$hash) {
        my $value = $$hash{$key}[0];
        my $type  = ref $value;
        if (($type eq 'HASH') || ($type eq 'ARRAY')) {    # Only concerned with mutable perl data?
                                                # Local assignment
          $$self{undo}[0]{$subtable}{$key}++;   # Note that this many values -- ie. one more -- must be undone
          unshift(@{ $$hash{$key} }, daemon_copy($value)); } } } }    # And push new binding.
      # Now mark the top frame as LOCKED!!!
  $$self{undo}[0]{_FRAME_LOCK_} = 1; 
  return; }

sub daemon_copy {
  my ($ob) = @_;
  if (ref $ob eq 'HASH') {
    my %hash = map { ($_ => daemon_copy($$ob{$_})) } keys %$ob;
    return \%hash; }
  elsif (ref $ob eq 'ARRAY') {
    return [map { daemon_copy($_) } @$ob]; }
  else {
    return $ob; } }

sub popDaemonFrame {
  my ($self) = @_;
  while (!$$self{undo}[0]{_FRAME_LOCK_}) {
    $self->popFrame; }
  if (scalar(@{ $$self{undo} } > 1)) {
    delete $$self{undo}[0]{_FRAME_LOCK_};
    $self->popFrame; }
  else {
    Fatal('unexpected', '<endgroup>', $self->getStomach,
      "Daemon Attempt to pop last stack frame"); }
  return; }

#======================================================================
# Set one of the definition prefixes global, etc (only global matters!)
sub setPrefix     {
  my($self, $prefix)=@_;
  $$self{prefixes}{$prefix} = 1;
  return; }

sub getPrefix {
  my($self,$prefix)=@_;
  return $$self{prefixes}{$prefix}; }

sub clearPrefixes {
  my($self)=@_;
  $$self{prefixes} = {};
  return; }

#======================================================================

sub activateScope {
  my ($self, $scope) = @_;
  my $table = $$self{table};
  if (!$$table{stash_active}{$scope}[0]) {
    assign_internal($self, 'stash_active', $scope, 1, 'local');
    if (defined(my $defns = $$table{stash}{$scope}[0])) {
      # Now make local assignments for all those in the stash.
      my $frame = $$self{undo}[0];
      foreach my $entry (@$defns) {
        my ($subtable, $key, $value) = @$entry;
        $$frame{$subtable}{$key}++;    # Note that this many values must be undone
        unshift(@{ $$table{$subtable}{$key} }, $value); } } }    # And push new binding.
  return; }

# Probably, in most cases, the assignments made by activateScope
# will be undone by egroup or popping frames.
# But they can also be undone explicitly
sub deactivateScope {
  my ($self, $scope) = @_;
  my $table = $$self{table};
  if ($$table{stash_active}{$scope}[0]) {
    assign_internal($self, 'stash_active', $scope, 0, 'global');
    if (defined(my $defns = $$table{stash}{$scope}[0])) {
      my $frame = $$self{undo}[0];
      foreach my $entry (@$defns) {
        my ($subtable, $key, $value) = @$entry;
        if ($$table{$subtable}{$key}[0] eq $value) {
          shift(@{ $$table{$subtable}{$key} });
          $$frame{$subtable}{$key}--; }
        else {
          Warn('internal', $key, $self->getStomach,
            "Unassigning wrong value for $key from subtable $subtable in deactivateScope",
            "value is $value but stack is " . join(', ', @{ $$table{$subtable}{$key} })); } } } }
  return; }

sub getActiveScopes {
  my ($self) = @_;
  my $table = $$self{table};
  my $scopes = $$table{stash_active} || {};
  return [keys %$scopes]; }

#======================================================================
# Units.
#   Put here since it could concievably evolve to depend on the current font.

# Conversion to scaled points
our %UNITS = (pt => 65536, pc => 12 * 65536, in => 72.27 * 65536, bp => 72.27 * 65536 / 72,
  cm => 72.27 * 65536 / 2.54, mm => 72.27 * 65536 / 2.54 / 10, dd => 1238 * 65536 / 1157,
  cc => 12 * 1238 * 65536 / 1157, sp => 1);

sub convertUnit {
  my ($self, $unit) = @_;
  $unit = lc($unit);
  # Eventually try to track font size?
  if    ($unit eq 'em') { return 10.0 * 65536; }
  elsif ($unit eq 'ex') { return 4.3 * 65536; }
  elsif ($unit eq 'mu') { return 10.0 * 65536 / 18; }
  else {
    my $sp = $UNITS{$unit};
    if (!$sp) {
      Warn('expected', '<unit>', undef, "Illegal unit of measure '$unit', assuming pt.");
      $sp = $UNITS{'pt'}; }
    return $sp; } }

#======================================================================

sub noteStatus {
  my ($self, $type, @data) = @_;
  if ($type eq 'undefined') {
    map { $$self{status}{undefined}{$_}++ } @data; }
  elsif ($type eq 'missing') {
    map { $$self{status}{missing}{$_}++ } @data; }
  else {
    $$self{status}{$type}++; }
  return; }

sub getStatus {
  my ($self, $type) = @_;
  return $$self{status}{$type}; }

sub getStatusMessage {
  my ($self) = @_;
  my $status = $$self{status};
  my @report = ();
  push(@report, "$$status{warning} warning" . ($$status{warning} > 1 ? 's' : ''))
    if $$status{warning};
  push(@report, "$$status{error} error" . ($$status{error} > 1 ? 's' : ''))
    if $$status{error};
  push(@report, "$$status{fatal} fatal error" . ($$status{fatal} > 1 ? 's' : ''))

    if $$status{fatal};
  my @undef = ($$status{undefined} ? keys %{ $$status{undefined} } : ());
  push(@report, scalar(@undef) . " undefined macro" . (@undef > 1 ? 's' : '')
      . "[" . join(', ', @undef) . "]")
    if @undef;
  my @miss = ($$status{missing} ? keys %{ $$status{missing} } : ());
  push(@report, scalar(@miss) . " missing file" . (@miss > 1 ? 's' : '')
      . "[" . join(', ', @miss) . "]")
    if @miss;
  return join('; ', @report) || 'No obvious problems'; }

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
