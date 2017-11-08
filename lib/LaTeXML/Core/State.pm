# /=====================================================================\ #
# |  LaTeXML::Core::State                                               | #
# | Maintains state: bindings, values, grouping                         | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::State;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Error;
use LaTeXML::Core::Token;    # To get CatCodes

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
# For each of several $table's (being "value", "meaning", "catcode" or other space of names),
# each table maintains the bound values, and "undo" defines the stack frames:
#    $$self{$table}{$key} = [$current_value, $previous_value, ...]
#    $$self{undo}[$frame]{$table}{$key} = (undef | $n)
# such that the "current value" associated with $key is the 0th element of the table array;
# the $previous_value's (if any) are values that had been assigned within previous groups.
# The undo list indicates how many values have been assigned for $key in
# the $frame'th frame (usually 0 is the one of interest).
# [Would be simpler to store boolean in undo, but see deactivateScope]
# [All keys fo $$self{undo}[$frame} are table names, EXCEPT "_FRAME_LOCK_"!!]
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
#      push an entry [$table,$key,$value] globally to the 'stash' table's value.
#      And assign locally, if the $scope is active (has non-zero value in stash_active table),
#
# There are tables for
#  catcode: keys are char;
#     Also, "math:$char" =1 when $char is active in math.
#  mathcode, sfcode, lccode, uccode, delcode : are similar to catcode but store
#    additional kinds codes per char (see TeX)
#  value: keys are anything (typically a string, though) and value is the value associated with it
#  meaning: The definition assocated with $key, usually a control-sequence.
#  stash & stash_active: support named scopes
#      (see also activateScope & deactivateScope)
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# options:
#     catcodes => (standard|style|none)
#     stomach  => a Stomach object.
#     model    => a Mod el object.
sub XXXXnew {
  my ($class, %options) = @_;
  my $self = bless {    # table => {},
    value => {}, meaning => {}, stash => {}, stash_active => {},
    catcode => {}, mathcode => {}, sfcode => {}, lccode => {}, uccode => {}, delcode => {},
    undo => [{ _FRAME_LOCK_ => 1 }], prefixes => {}, status => {},
    stomach => $options{stomach}, model => $options{model} }, $class;
  $$self{value}{VERBOSITY} = [0];
  $options{catcodes} = 'standard' unless defined $options{catcodes};
  if ($options{catcodes} =~ /^(standard|style)/) {
    # Setup default catcodes.
    my %std = ("\\" => CC_ESCAPE, "{" => CC_BEGIN, "}" => CC_END, "\$" => CC_MATH,
      "\&" => CC_ALIGN, "\r" => CC_EOL,   "#"  => CC_PARAM, "^" => CC_SUPER,
      "_"  => CC_SUB,   " "  => CC_SPACE, "\t" => CC_SPACE, "%" => CC_COMMENT,
      "~" => CC_ACTIVE, chr(0) => CC_IGNORE);
    map { $$self{catcode}{$_} = [$std{$_}] } keys %std;
    for (my $c = ord('A') ; $c <= ord('Z') ; $c++) {
      $$self{catcode}{ chr($c) } = [CC_LETTER];
      $$self{catcode}{ chr($c + ord('a') - ord('A')) } = [CC_LETTER]; }
  }
  $$self{value}{SPECIALS} = [['^', '_', '@', '~', '&', '$', '#', "'"]];
  if ($options{catcodes} eq 'style') {
    $$self{catcode}{'@'} = [CC_LETTER]; }
  $$self{mathcode}            = {};
  $$self{sfcode}              = {};
  $$self{lccode}              = {};
  $$self{uccode}              = {};
  $$self{delcode}             = {};
  $$self{tracing_definitions} = {};
  return $self; }

sub new {
  my ($class, %options) = @_;
  my $self = LaTeXML::Core::State::new_internal($options{stomach},$options{model});
  $self->setFrameLock(1);
  $self->assignValue(VERBOSITY => 0);
  $options{catcodes} = 'standard' unless defined $options{catcodes};
  if ($options{catcodes} =~ /^(standard|style)/) {
    # Setup default catcodes.
    my %std = ("\\" => CC_ESCAPE, "{" => CC_BEGIN, "}" => CC_END, "\$" => CC_MATH,
      "\&" => CC_ALIGN, "\r" => CC_EOL,   "#"  => CC_PARAM, "^" => CC_SUPER,
      "_"  => CC_SUB,   " "  => CC_SPACE, "\t" => CC_SPACE, "%" => CC_COMMENT,
      "~" => CC_ACTIVE, chr(0) => CC_IGNORE);
    map { $self->assignCatcode($_ => $std{$_}) } keys %std;
    for (my $c = ord('A') ; $c <= ord('Z') ; $c++) {
      $self->assignCatcode( chr($c) => CC_LETTER);
      $self->assignCatcode( chr($c + ord('a') - ord('A')) => CC_LETTER); }
  }
  $self->assignValue(SPECIALS => ['^', '_', '@', '~', '&', '$', '#', "'"]);
  if ($options{catcodes} eq 'style') {
    $self->assignCatcode('@' => CC_LETTER); }
  return $self; }


# sub XXassign_internal {
#   my ($self, $table, $key, $value, $scope) = @_;
#   $scope = ($$self{prefixes}{global} ? 'global' : 'local') unless defined $scope;
#   #print STDERR "Assign internal in table $table, $key => $value; scope=$scope\n";
#   if (exists $$self{tracing_definitions}{$key}) {
#     print STDERR "ASSIGN $key in $table " . ($scope ? "($scope)" : '') . " => " .
#       (ref $value ? $value->stringify : $value) . "\n"; }
#   if ($scope eq 'global') {
#     # Remove bindings made in all frames down-to & including the next lower locked frame
#     my $frame;
#     my @frames = @{ $$self{undo} };
#     while (@frames) {
#       $frame = shift(@frames);
#       if (my $n = $$frame{$table}{$key}) {    # Undo the bindings, if $key was bound in this frame
#         map { shift(@{ $$self{$table}{$key} }) } 1 .. $n if $n;
#         delete $$frame{$table}{$key}; }
#       last if $$frame{_FRAME_LOCK_}; }
#     # whatever is left -- if anything -- should be bindings below the locked frame.
#     $$frame{$table}{$key} = 1;                # Note that there's only one value in the stack, now
#     unshift(@{ $$self{$table}{$key} }, $value); }
#   elsif ($scope eq 'local') {
#     if ($$self{undo}[0]{$table}{$key}) {      # If the value was previously assigned in this frame
#       $$self{$table}{$key}[0] = $value; }     # Simply replace the value
#     else {                                    # Otherwise, push new value & set 1 to be undone
#       $$self{undo}[0]{$table}{$key} = 1;
#       unshift(@{ $$self{$table}{$key} }, $value); } }    # And push new binding.
#   else {
#     # print STDERR "Assigning $key in stash $stash\n";
#     assign_internal($self, 'stash', $scope, [], 'global') unless $$self{stash}{$scope}[0];
#     push(@{ $$self{stash}{$scope}[0] }, [$table, $key, $value]);
#     assign_internal($self, $table, $key, $value, 'local')
#       if $$self{stash_active}{$scope}[0]; }
#   return; }

#======================================================================
# sub getStomach {
#   my ($self) = @_;
#   return $$self{stomach}; }

# sub getModel {
#   my ($self) = @_;
#   return $$self{model}; }

#======================================================================

# manage a (global) list of values
# sub pushValue {
#   my ($self, $key, @values) = @_;
#   my $vtable = $$self{value};
#   assign_internal($self, 'value', $key, [], 'global') unless $$vtable{$key}[0];
#   push(@{ $$vtable{$key}[0] }, @values);
#   return; }

# sub popValue {
#   my ($self, $key) = @_;
#   my $vtable = $$self{value};
#   assign_internal($self, 'value', $key, [], 'global') unless $$vtable{$key}[0];
#   return pop(@{ $$vtable{$key}[0] }); }

# sub unshiftValue {
#   my ($self, $key, @values) = @_;
#   my $vtable = $$self{value};
#   assign_internal($self, 'value', $key, [], 'global') unless $$vtable{$key}[0];
#   unshift(@{ $$vtable{$key}[0] }, @values);
#   return; }

# sub shiftValue {
#   my ($self, $key) = @_;
#   my $vtable = $$self{value};
#   assign_internal($self, 'value', $key, [], 'global') unless $$vtable{$key}[0];
#   return shift(@{ $$vtable{$key}[0] }); }

# manage a (global) hash of values
# sub lookupMapping {
#   my ($self, $map, $key) = @_;
#   my $vtable  = $$self{value};
#   my $mapping = $$vtable{$map}[0];
#   return ($mapping ? $$mapping{$key} : undef); }

# sub assignMapping {
#   my ($self, $map, $key, $value) = @_;
#   my $vtable = $$self{value};
#   assign_internal($self, 'value', $map, {}, 'global') unless $$vtable{$map}[0];
#   if (!defined $value) {
#     delete $$vtable{$map}[0]{$key}; }
#   else {
#     $$vtable{$map}[0]{$key} = $value; }
#   return; }

# sub lookupMappingKeys {
#   my ($self, $map) = @_;
#   my $vtable  = $$self{value};
#   my $mapping = $$vtable{$map}[0];
#   return ($mapping ? sort keys %$mapping : ()); }

# sub lookupStackedValues {
#   my ($self, $key) = @_;
#   my $stack = $$self{value}{$key};
#   return ($stack ? @$stack : ()); }

#======================================================================
# Was $name bound?  If  $frame is given, check only whether it is bound in
# that frame (0 is the topmost).
# sub isValueBound {
#   my ($self, $key, $frame) = @_;
#   return (defined $frame ? $$self{undo}[$frame]{value}{$key}
#     : defined $$self{value}{$key}[0]); }

# sub valueInFrame {
#   my ($self, $key, $frame) = @_;
#   $frame = 0 unless defined $frame;
#   my $p = 0;
#   for (my $f = 0 ; $f < $frame ; $f++) {
#     $p += $$self{undo}[$f]{value}{$key}; }
#   return $$self{value}{$key}[$p]; }

# Determine depth of group nesting created by {,},\bgroup,\egroup,\begingroup,\endgroup
# by counting all frames which are not Daemon frames (and thus don't possess _FRAME_LOCK_).
# This may give incorrect results for some special environments (e.g. minipage)
# sub getFrameDepth {
#   my ($self) = @_;
#   return scalar(grep { not defined $$_{_FRAME_LOCK_} } @{ $$self{undo} }) - 1; }

#======================================================================
# This is primarily about catcodes, but a bit more...

# used by startSemiverbatim
sub setASCIIencoding {
  my ($self) = @_;
  $self->assignValue(font => $self->lookupValue('font')->merge(encoding => 'ASCII'), 'local'); }

#======================================================================

# sub XXXXpushDaemonFrame {
#   my ($self) = @_;
#   my $frame = {};
#   unshift(@{ $$self{undo} }, $frame);
#   # Push copys of data for any data that is mutable;
#   # Only the value & stash tables need to be to be checked.
#   # NOTE ??? No...
#   foreach my $table (qw(value stash)) {
#     if (my $hash = $$self{$table}) {
#       foreach my $key (keys %$hash) {
#         my $value = $$hash{$key}[0];
#         my $type  = ref $value;
#         if (($type eq 'HASH') || ($type eq 'ARRAY')) {    # Only concerned with mutable perl data?
#                                                           # Local assignment
# #####          $$frame{$table}{$key} = 1;                      # Note new value in this frame.
# #####          unshift(@{ $$hash{$key} }, daemon_copy($value));    # And push new binding.
#           $self->assign_internal($table,daemon_copy($value),'global');
#         } } } }
#       # Record the contents of LaTeXML::Package::Pool as preloaded
#   my $pool_preloaded_hash = { map { $_ => 1 } keys %LaTeXML::Package::Pool:: };
#   $self->assignValue('_PRELOADED_POOL_', $pool_preloaded_hash, 'global');
#   # Now mark the top frame as LOCKED!!!
# #  $$frame{_FRAME_LOCK_} = 1;
#   $self->setFrameLock(1);
#   return; }

sub pushDaemonFrame {
  my ($self) = @_;
##  my $frame = {};
##  unshift(@{ $$self{undo} }, $frame);
  $self->pushFrame;
  # Push copys of data for any data that is mutable;
  # Only the value & stash tables need to be to be checked.
  # NOTE ??? No...
  foreach my $key ($self->getValueKeys) {
    my $value = $self->lookupValue($key);
    my $type  = ref $value;
    if (($type eq 'HASH') || ($type eq 'ARRAY')) {    # Only concerned with mutable perl data?
      $self->assignValue(daemon_copy($value),'global'); } }
  foreach my $key ($self->getKnownScopes) {
    my $value = $self->lookupStash($key);
    my $type  = ref $value;
    if (($type eq 'HASH') || ($type eq 'ARRAY')) {    # Only concerned with mutable perl data?
      $self->assignStash(daemon_copy($value),'global'); } }

  # Record the contents of LaTeXML::Package::Pool as preloaded
  my $pool_preloaded_hash = { map { $_ => 1 } keys %LaTeXML::Package::Pool:: };
  $self->assignValue('_PRELOADED_POOL_', $pool_preloaded_hash, 'global');
  # Now mark the top frame as LOCKED!!!
#  $$frame{_FRAME_LOCK_} = 1;
  $self->setFrameLock(1);
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
#  while (!$$self{undo}[0]{_FRAME_LOCK_}) {
  while (! $self->isFrameLocked) {
    $self->popFrame; }
#  if (scalar(@{ $$self{undo} } > 1)) {
#    delete $$self{undo}[0]{_FRAME_LOCK_};
  if($self->isFrameLocked){
    $self->setFrameLock(0);
    # Any non-preloaded Pool routines should be wiped away, as we
    # might want to reuse the Pool namespaces for the next run.
    my $pool_preloaded_hash = $self->lookupValue('_PRELOADED_POOL_');
    $self->assignValue('_PRELOADED_POOL_', undef, 'global');
    foreach my $subname (keys %LaTeXML::Package::Pool::) {
      unless (exists $$pool_preloaded_hash{$subname}) {
        undef $LaTeXML::Package::Pool::{$subname};
        delete $LaTeXML::Package::Pool::{$subname};
      } }
    # Finally, pop the frame
    $self->popFrame; }
  else {
    Fatal('unexpected', '<endgroup>', $self->getStomach,
      "Daemon Attempt to pop last stack frame"); }
  return; }

#======================================================================

# sub XXactivateScope {
#   my ($self, $scope) = @_;
#   if (!$$self{stash_active}{$scope}[0]) {
#     assign_internal($self, 'stash_active', $scope, 1, 'local');
#     if (defined(my $defns = $$self{stash}{$scope}[0])) {
#       # Now make local assignments for all those in the stash.
#       my $frame = $$self{undo}[0];
#       foreach my $entry (@$defns) {
#         # Here we ALWAYS push the stashed values into the table
#         # since they may be popped off by deactivateScope
#         my ($table, $key, $value) = @$entry;
#         $$frame{$table}{$key}++;    # Note that this many values must be undone
#         unshift(@{ $$self{$table}{$key} }, $value); } } }    # And push new binding.
#   return; }

# # Probably, in most cases, the assignments made by activateScope
# # will be undone by egroup or popping frames.
# # But they can also be undone explicitly
# sub XXdeactivateScope {
#   my ($self, $scope) = @_;
#   if ($$self{stash_active}{$scope}[0]) {
#     assign_internal($self, 'stash_active', $scope, 0, 'global');
#     if (defined(my $defns = $$self{stash}{$scope}[0])) {
#       my $frame = $$self{undo}[0];
#       foreach my $entry (@$defns) {
#         my ($table, $key, $value) = @$entry;
#         if ($$self{$table}{$key}[0] eq $value) {
#           # Here we're popping off the values pushed by activateScope
#           # to (possibly) reveal a local assignment in the same frame, preceding activateScope.
#           shift(@{ $$self{$table}{$key} });
#           $$frame{$table}{$key}--; }
#         else {
#           Warn('internal', $key, $self->getStomach,
#             "Unassigning wrong value for $key from table $table in deactivateScope",
#             "value is $value but stack is " . join(', ', @{ $$self{$table}{$key} })); } } } }
#   return; }

# sub getKnownScopes {
#   my ($self) = @_;
#   my @scopes = sort keys %{ $$self{stash} };
#   return @scopes; }

# sub getActiveScopes {
#   my ($self) = @_;
#   my @scopes = sort keys %{ $$self{stash_active} };
#   return @scopes; }


#======================================================================

# sub noteStatus {
#   my ($self, $type, @data) = @_;
#   if ($type eq 'undefined') {
#     map { $$self{status}{undefined}{$_}++ } @data; }
#   elsif ($type eq 'missing') {
#     map { $$self{status}{missing}{$_}++ } @data; }
#   else {
#     $$self{status}{$type}++; }
#   return; }

# sub getStatus {
#   my ($self, $type) = @_;
#   return $$self{status}{$type}; }

# sub getStatusMessage {
#   my ($self) = @_;
#   my $status = $$self{status};
#   my @report = ();
#   push(@report, colorizeString("$$status{warning} warning" . ($$status{warning} > 1 ? 's' : ''), 'warning'))
#     if $$status{warning};
#   push(@report, colorizeString("$$status{error} error" . ($$status{error} > 1 ? 's' : ''), 'error'))
#     if $$status{error};
#   push(@report, "$$status{fatal} fatal error" . ($$status{fatal} > 1 ? 's' : ''))

#     if $$status{fatal};
#   my @undef = ($$status{undefined} ? keys %{ $$status{undefined} } : ());
#   push(@report, colorizeString(scalar(@undef) . " undefined macro" . (@undef > 1 ? 's' : '')
#         . "[" . join(', ', @undef) . "]", 'details'))
#     if @undef;
#   my @miss = ($$status{missing} ? keys %{ $$status{missing} } : ());
#   push(@report, colorizeString(scalar(@miss) . " missing file" . (@miss > 1 ? 's' : '')
#         . "[" . join(', ', @miss) . "]", 'details'))
#     if @miss;
#   return join('; ', @report) || colorizeString('No obvious problems', 'success'); }

# sub getStatusCode {
#   my ($self) = @_;
#   my $status = $$self{status};
#   my $code;
#   if ($$status{fatal} && $$status{fatal} > 0) {
#     $code = 3; }
#   elsif ($$status{error} && $$status{error} > 0) {
#     $code = 2; }
#   elsif ($$status{warning} && $$status{warning} > 0) {
#     $code = 1; }
#   else {
#     $code = 0; }
#   return $code; }
sub getStatusMessage {
  my ($self) = @_;
  my $fatals = $self->getStatus("fatal") || 0;
  my $errors = $self->getStatus("error") || 0;
  my $warnings = $self->getStatus("warning") || 0;
  my @report = ();
  push(@report, colorizeString("$warnings warning" . ($warnings > 1 ? 's' : ''), 'warning'))
    if $warnings;
  push(@report, colorizeString("$errors error" . ($errors > 1 ? 's' : ''), 'error'))
    if $errors;
  push(@report, "$fatals fatal error" . ($fatals > 1 ? 's' : ''))
    if $fatals;
  my $undefined = $self->getStatus('undefined');
  my @undef = ($undefined ? sort keys %$undefined : ());
  push(@report, colorizeString(scalar(@undef) . " undefined macro" . (@undef > 1 ? 's' : '')
        . "[" . join(', ', @undef) . "]", 'details'))
    if @undef;
  my $missing = $self->getStatus('missing');
  my @miss = ($missing ? keys %$missing : ());
  push(@report, colorizeString(scalar(@miss) . " missing file" . (@miss > 1 ? 's' : '')
        . "[" . join(', ', @miss) . "]", 'details'))
    if @miss;
  return join('; ', @report) || colorizeString('No obvious problems', 'success'); }

sub getStatusCode {
  my ($self) = @_;
  my $fatals = 
  my $errors = $self->getStatus("error") || 0;
  my $warnings = $self->getStatus("warning") || 0;
  my $code;
  if (($self->getStatus("fatal") || 0) > 0) {
    $code = 3; }
  elsif (($self->getStatus("error") || 0) > 0) {
    $code = 2; }
  elsif (($self->getStatus("warning") || 0) > 0) {
    $code = 1; }
  else {
    $code = 0; }
  return $code; }

#======================================================================
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Core::State> - stores the current state of processing.

=head1 DESCRIPTION

A C<LaTeXML::Core::State> object stores the current state of processing.
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
Note that this is lower level than C<\bgroup>; See L<LaTeXML::Core::Stomach>.

=item C<< $STATE->popFrame; >>

Ends the current level of grouping.
Note that this is lower level than C<\egroup>; See L<LaTeXML::Core::Stomach>.

=item C<< $STATE->setPrefix($prefix); >>

Sets a prefix (eg. C<global> for C<\global>, etc) for the next operation, if applicable.

=item C<< $STATE->clearFlags; >>

Clears any prefix flags.

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
(See L<LaTeXML::Core::Definition>)

=item C<< $STATE->assignMeaning($token,$defn,$scope); >>

Set the definition associated with C<$token> to C<$defn>.
If C<$globally> is true, it makes this the global definition
rather than bound within the current group.
(See L<LaTeXML::Core::Definition>, and L<LaTeXML::Package>)

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
