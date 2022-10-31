# /=====================================================================\ #
# |  LaTeXML::BibTeX::Runtime                                           | #
# | Runtime for LaTeXML::BibTeX-generated perl code                    | #
# |=====================================================================| #
# | Part of LaTeXML                                                     | #
# |---------------------------------------------------------------------| #
# | Tom Wiesing <tom.wiesing@gmail.com>                                 | #
# \=====================================================================/ #

package LaTeXML::BibTeX::Runtime;
use strict;
use warnings;

use LaTeXML::Common::Error;
#use LaTeXML::BibTeX::Bibliography;
use LaTeXML::BibTeX::Runtime::Entry;
use LaTeXML::BibTeX::Runtime::Builtins;
use LaTeXML::BibTeX::BibStyle::StyCommand;
use LaTeXML::BibTeX::BibStyle::StyString;
use LaTeXML::BibTeX::Runtime::Strings;
use Scalar::Util qw(blessed);

sub new {
  my ($class, $name, $buffer, $bibliographies, $cites) = @_;
  return bless {
    name           => $name,
    buffer         => $buffer,
    bibliographies => [@{$bibliographies}],
    cites          => [@${cites}],
    stack          => [],                     ### the stack
    macros         => {},                     ### - a set of macros
    ### - a set of global string variables (with three values each, as in the stack)
    ### along with the types ('GLOBAL_STRING', 'ENTRY_STRING', 'GLOBAL_INTEGER', 'ENTRY_INTEGER', 'ENTRY_FIELD');
    variables     => {},
    variableTypes => {},
    ### - a list of read entries, and the current entry (if any)
    entries        => undef,
    entryHash      => undef,
    entry          => undef,
    preambleString => [],
    preambleSource => [],
  }, $class; }

#======================================================================
# gets the buffer of this config
sub getBuffer {
  my ($self, @data) = @_;
  return $$self{buffer}; }

# gets the bibliographies associated with this configuration
sub getBibliographies {
  my ($self) = @_;
  return @{ $$self{bibliographies} }; }

# gets the cites associated with this configuration
sub getCites {
  my ($self) = @_;
  return @{ $$self{cites} }; }

# initialises this context and registers all built-in functions
sub initContext {
  my ($self) = @_;
  # define the crossref field and sort.key$
  $self->defineVariable('crossref',  'ENTRY_FIELD');
  $self->defineVariable('sort.key$', 'ENTRY_STRING');
  # set pre-defined variables to their defaults
  # These can technically be re-defined, but one would have to re-compile BibTeX for that.
  $self->assignVariable('global.max$', 'GLOBAL_INTEGER', ['INTEGER', 20000, undef]);
  $self->assignVariable('entry.max$',  'GLOBAL_INTEGER', ['INTEGER', 250,   undef]);
  LaTeXML::BibTeX::Runtime::Builtins::install($self);
  return; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# High-level interpreter

# Debugging aid
sub trim {
  my ($string, $len) = @_;
  my $l = length($string);
  return ($l > $len ? substr($string, 0, $len) : $string . (' ' x ($len - $l))); }

sub RTDebug {
  my ($self, $op, $msg) = @_;
  my $d = scalar(@{ $$self{stack} });
  my ($t, $v, $xx) = $self->peekStack(1);
  my $s = trim(($t || '?') . ':' . ((defined $v) && (blessed $v) ? $v->stringify : ''), 20);
  $op  = trim((blessed $op ? $op->stringify : $op), 120);
  $msg = trim($msg, 40);
  Debug("[$d: $s] $msg : $op");
  return; }

#======================================================================
# Execute top-level Commands
sub run {
  my ($self, $program) = @_;
  RTDebug($self, $program, "PROGRAM") if $LaTeXML::DEBUG{bibtex_runtime};
  foreach my $command (@$program) {
    my $name = $command->getName;
    if    ($name eq 'ENTRY')    { do_ENTRY($self, $command); }
    elsif ($name eq 'STRINGS')  { do_STRINGS($self, $command); }
    elsif ($name eq 'INTEGERS') { do_INTEGERS($self, $command); }
    elsif ($name eq 'MACRO')    { do_MACRO($self, $command); }
    elsif ($name eq 'FUNCTION') { do_FUNCTION($self, $command); }
    elsif ($name eq 'EXECUTE')  { do_EXECUTE($self, $command); }
    elsif ($name eq 'READ')     { do_READ($self, $command); }
    elsif ($name eq 'SORT')     { do_SORT($self, $command); }
    elsif ($name eq 'ITERATE')  { do_ITERATE($self, $command); }
    elsif ($name eq 'REVERSE')  { do_REVERSE($self, $command); }
    else {
      Error('bibtex', 'runtime', $command->getLocator, "Unknown command $name"); } }
  return; }

sub do_ENTRY {
  my ($self, $command) = @_;
  my ($fields, $integers, $strings) = $command->getArguments;
  RTDebug($self, $command, "Define ENTRY") if $LaTeXML::DEBUG{bibtex_runtime};
  # define entry fields
  foreach my $field (@{ $fields->getValue }) {
    my $name = lc($field->getValue);
    if ($self->hasVariable($name)) {
      Warn('bibtex', 'runtime', $field->getLocator, "Entry field $name already defined"); }
    else {
      $self->defineVariable($name, 'ENTRY_FIELD'); } }
  # define entry fields
  foreach my $int (@{ $integers->getValue }) {
    my $name = $int->getValue;
    if ($self->hasVariable($name)) {
      Warn('bibtex', 'runtime', $int->getLocator, "Entry integer $name already defined"); }
    else {
      $self->defineVariable($name, 'ENTRY_INTEGER'); } }
  # define entry strings
  foreach my $string (@{ $strings->getValue }) {
    my $name = $string->getValue;
    if ($self->hasVariable($name)) {
      Warn('bibtex', 'runtime', $string->getLocator, "Entry string $name already defined"); }
    else {
      $self->defineVariable($name, 'ENTRY_STRING'); } }
  return; }

sub do_INTEGERS {
  my ($self, $command) = @_;
  my ($args) = $command->getArguments;
  RTDebug($self, $command, "Define INTEGERS") if $LaTeXML::DEBUG{bibtex_runtime};
  # define global integers
  foreach my $int (@{ $args->getValue }) {
    my $name = $int->getValue;
    if ($self->hasVariable($name)) {
      Warn('bibtex', 'runtime', $int->getLocator, "Global integer $name already defined"); }
    else {
      $self->defineVariable($name, 'GLOBAL_INTEGER'); } }
  return; }

sub do_STRINGS {
  my ($self, $command) = @_;
  my ($args) = $command->getArguments;
  RTDebug($self, $command, "Define STRINGS") if $LaTeXML::DEBUG{bibtex_runtime};
  # define global strings
  foreach my $string (@{ $args->getValue }) {
    my $name = $string->getValue;
    if ($self->hasVariable($name)) {
      Warn('bibtex', 'runtime', $string->getLocator, "Global string $name already defined"); }
    else {
      $self->defineVariable($name, 'GLOBAL_STRING'); } }
  return; }

sub check_one {
  my ($self, $thing, $desc) = @_;
  my @things = @{ $thing->getValue };
  return Error('bibtex', 'runtime', $thing->getLocator, 'Expected exactly one ' . $desc)
    if (scalar(@things) != 1);
  return $things[0]; }

sub do_MACRO {
  my ($self, $command) = @_;
  my ($name, $value)   = $command->getArguments;
  return unless $name  = $self->check_one($name,  'macro name');
  return unless $value = $self->check_one($value, 'macro value');
  RTDebug($self, $command, "Define Macro " . $name) if $LaTeXML::DEBUG{bibtex_runtime};
  $$self{macros}{ lc $name->getValue } = $value->getValue;
  return; }

sub do_FUNCTION {
  my ($self, $command) = @_;
  my ($name, $body)    = $command->getArguments;
  return unless $name = $self->check_one($name, 'function name');
  $name = $name->getValue;
  RTDebug($self, $command, "Define Function " . $name) if $LaTeXML::DEBUG{bibtex_runtime};
  $self->assignVariable($name, 'FUNCTION', ['FUNCTION', $body, undef]);
  return; }

sub do_EXECUTE {
  my ($self, $command) = @_;
  my ($name) = $command->getArguments;
  return unless $name = $self->check_one($name, 'function name');
  RTDebug($self, $command, "EXECUTE " . $name->getValue) if $LaTeXML::DEBUG{bibtex_runtime};
  do_Instruction($self, $name);
  return; }

sub do_READ {
  my ($self, $command) = @_;
  RTDebug($self, $command, "READ bibliographies") if $LaTeXML::DEBUG{bibtex_runtime};
  $self->readEntries([$self->getBibliographies], [$self->getCites]);
  return; }

sub do_SORT {
  my ($self, $command) = @_;
  my %keys = ();
  # find all the entries
  RTDebug($self, $command, "SORT bibliographies") if $LaTeXML::DEBUG{bibtex_runtime};
  my $entries = $self->getEntries;
  return Error('bibtex', 'runtime', $command->getLocator,
    'Can not sort entries:  No entries read yet. ')
    unless defined($entries);
  # determine their purified key
  foreach my $entry (@$entries) {
    # get the sort.key$ variable
    my ($tp, $key) = $entry->getVariable('sort.key$');
    $key = [''] unless defined($key);    # iff it is undefined
    $key = join('', @$key);
    # and purify it
    $keys{ $entry->getKey } = textPurify($key); }
  # sort entries using the purified sorting key
  $self->sortEntries(
    sub {
      my ($entryA, $entryB) = @_;
      return $keys{ $entryA->getKey } cmp $keys{ $entryB->getKey };
    });
  return; }

sub do_ITERATE {
  my ($self, $command) = @_;
  my ($function) = $command->getArguments;
  return unless $function = $self->check_one($function, 'function name');
  RTDebug($self, $command, "ITERATE $function") if $LaTeXML::DEBUG{bibtex_runtime};
  # Check that $name corresonds to some function???
  my $entries = $self->getEntries;
  return Warn('bibtex', 'runtime', $command->getLocator,
    'Can not iterate entries: No entries have been read')
    unless defined($entries);
  my $n = 0;
  foreach my $entry (@$entries) {
    RTDebug($self, $command, "Entry $n") if $LaTeXML::DEBUG{bibtex_runtime}; $n++;
    $self->setEntry($entry);
    do_Instruction($self, $function);
    Warn('bibtex', 'runtime', $command->getLocator,
      "Stack is not empty for entry " . $entry->getKey)
      unless $self->stackEmpty; }
  $self->leaveEntry;
  RTDebug($self, $command, "ITERATE done w/$n") if $LaTeXML::DEBUG{bibtex_runtime};
  return; }

sub do_REVERSE {
  my ($self, $command) = @_;
  my ($function) = $command->getArguments;
  return unless $function = $self->check_one($function, 'function name');
  RTDebug($self, $command, "REVERSE $function") if $LaTeXML::DEBUG{bibtex_runtime};
  # Check that $name corresonds to some function???
  my $entries = $self->getEntries;
  return Warn('bibtex', 'runtime', $command->getLocator,
    'Can not iterate entries: No entries have been read')
    unless defined($entries);
  my $n = 0;
  foreach my $entry (reverse(@$entries)) {
    RTDebug($self, $command, "Entry $n") if $LaTeXML::DEBUG{bibtex_runtime}; $n++;
    $self->setEntry($entry);
    do_Instruction($self, $function);
    Warn('bibtex', 'runtime', $command->getLocator,
      "Stack is not empty for entry " . $entry->getKey)
      unless $self->stackEmpty; }
  $self->leaveEntry;
  RTDebug($self, $command, "REVERSE done w/$n") if $LaTeXML::DEBUG{bibtex_runtime};
  return; }

#======================================================================
# Executing Instructions
sub do_Instruction {
  my ($self, $instruction) = @_;
  my $type = $instruction->getKind;
  if    ($type eq 'LITERAL')   { do_Literal($self, $instruction); }
  elsif ($type eq 'REFERENCE') { do_Reference($self, $instruction); }
  elsif ($type eq 'BLOCK')     { do_Block($self, $instruction); }
  elsif ($type eq 'QUOTE')     { do_Quote($self, $instruction); }
  elsif ($type eq 'NUMBER')    { do_Integer($self, $instruction); }
  else {
    Error('bibtex', 'runtime', $instruction->getLocator,
      "Unknown instruction of type $type"); }
  return; }

# execute a literal
sub do_Literal {
  my ($self, $variable) = @_;
  my $name = $variable->getValue;
  my ($type, $value, $source) = $self->getVariable(lc $name);
  if (!$type) {
    Error('bibtex', 'runtime', $variable->getLocator, "Unknown literal $name in literal"); }
  elsif ($type eq 'FUNCTION') {
    RTDebug($self, $variable, "INSTRUCTION Literal Function $name") if $LaTeXML::DEBUG{bibtex_runtime};
    $self->executeFunction($variable, $value); }
  elsif (defined($type)) {
    RTDebug($self, $variable, "INSTRUCTION Literal $type $name") if $LaTeXML::DEBUG{bibtex_runtime};
    $self->pushStack($type, $value, $source); }
  else {
    Warn('bibtex', 'runtime', $variable->getLocator,
      "Can not push $name: Does not exist. "); }
  return; }

# NOTE: Shouldn't this just turn the REFERENCE into a LITERAL ?
# Ah, but how to put that on the stack?
sub do_Reference {
  my ($self, $instruction) = @_;
  my $name = lc $instruction->getValue;
  my $type = $instruction->getKind;
  RTDebug($self, $instruction, "INSTRUCTION Literal Reference $name => $type") if $LaTeXML::DEBUG{bibtex_runtime};
  $self->pushStack('REFERENCE', [$type, $name], undef);
  return; }

# A block in the instruction stream gets pushed onto the stack
sub do_Block {
  my ($self, $block) = @_;
  RTDebug($self, $block, "Push block $block") if $LaTeXML::DEBUG{bibtex_runtime};
  $self->pushStack('FUNCTION', $block, undef);
  return; }

# execute a function (from stack) may be CODE or a BLOCK
sub executeFunction {
  my ($self, $instruction, $function) = @_;
  if (ref $function eq 'CODE') {
    RTDebug($self, $function, "Builtin $function") if $LaTeXML::DEBUG{bibtex_runtime};
    &{$function}($self, $instruction); }
  else {
    RTDebug($self, $function, "Run block") if $LaTeXML::DEBUG{bibtex_runtime};
    my @instructions = @{ $function->getValue };
    foreach my $instruction (@instructions) {
      do_Instruction($self, $instruction); } }
  return; }

# Execute an item popped from the stack
# weirdly re-encoded
sub executeStacked {
  my ($self, $instruction, $type, $value, $source) = @_;
  # Shouldn't REFERENCE's already have been DE-referenced?
  if ($type eq 'REFERENCE') {
    my ($vtype, $vname) = @$value;
    my ($t, $v, $s) = $self->getVariable($vname);
    if ($t eq 'FUNCTION') {
      $type = $t; $value = $v; }
    else {
      $self->pushStack($t, $v, $s);
      return; } }
  if ($type eq 'FUNCTION') {
    $self->executeFunction($instruction, $value); }
  else {
    Error('bibtex', 'runtime', $instruction->getLocator, "Attempt to evaluate $type"); }
  return; }

# execute a single quote
sub do_Quote {
  my ($self, $quote) = @_;
  RTDebug($self, $quote, "INSTRUCTION Literal Quote '" . $quote->getValue . "'") if $LaTeXML::DEBUG{bibtex_runtime};
  $self->pushStack('STRING', [$quote->getValue], undef);
  return; }

# executes a single number
sub do_Integer {
  my ($self, $number) = @_;
  RTDebug($self, $number, "INSTRUCTION Literal integer '" . $number->getValue . "'") if $LaTeXML::DEBUG{bibtex_runtime};
  $self->pushStack('INTEGER', $number->getValue, undef);
  return; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Low-level stack access

### Each entry in the runtime stack internally consists of a triple (type, valuye, source):
###  - 'type' contains types of objects
###  - 'value' the actual objects
###  - 'source' contains the source references of objects
### Entries on the stack are considered immutable (even though Perl provides no guarantees that it is indeed so).
### Any changes to the underlying values should be performed on a copy of the data.

### The following types are defined:

### 0. 'UNSET' - if a variable has not been set
### 1. 'MISSING' - a missing value of a field (TODO: perhaps also an uninititialized constant)
### 2. 'STRING' - a simple string
### 3. 'INTEGER' -- an integer
### 4. 'FUNCTION' -- a function
### 5. 'REFERENCE' -- a reference to a variable or function on the stack. Starts with 'GLOBAL_' or 'ENTRY_'.

### These have the corresponding values:

### 0. 'UNSET' -- undef
### 1. 'MISSING' -- undef
### 2. 'STRING' -- a tuple of strings
### 3. 'INTEGER' -- a single integer
### 4. 'FUNCTION' -- the function reference
### 5. 'REFERENCE' -- a pair (variable type, reference) of the type of variable being referenced and the actual value being referened

### The corresponding source references are:
### 0. 'UNSET' -- undef
### 1. 'MISSING' -- a tuple(key, field) this value comes from
### 2. 'STRING' -- a tuple (key, field) or undef for each string
### 3. 'INTEGER' -- a tuple (key, field) or undef, when joining take the first one
### 4. 'FUNCTION' -- undef
### 5. 'REFERENCE' -- undef

# TODO: Allow re-running a context without having to re-parse the bib files
# (There should probably be a reset function that clear entries, but keeps the read .bib files)

#======================================================================
# 'popStack' pops and returns a value from the stack, or returns undef, undef, undef
# The value returned from the stack is immutable, and should be copied if any changes are made
sub popStack {
  my ($self) = @_;
  if (my $top = pop(@{ $$self{stack} })) {
    return @$top; }
  return; }

# 'peekStack' peeks at position $index from the top of the stac, or undef, undef, undef if it is not defined.
# Note that index is 1-based, i.e. peekStack(1) returns the top-most element on the stack
sub peekStack {
  my ($self, $index) = @_;
  if (my $top = $$self{stack}[-($index || 1)]) {
    return @$top; }
  return; }

# 'pushStack' pushes a single value onto the stack
sub pushStack {
  my ($self, $type, $value, $source) = @_;
  ## NOTE: Some kind of weird programming error???
  Error("STACK", "nonsource", undef, "Stacked non-array source for $type, $value, $source: "
      . (ref $source ? join(',', @$source) : ''))
    if ($type eq 'STRING') && (defined $source) &&
    (!(ref $source) || grep { (defined $_) && ($_ ne '') && (!ref $_); } @$source);
  push(@{ $$self{stack} }, [$type, $value, $source]);
  return; }

# pops a string of a particular type, or throws an error;
# returns object & source if in array context, else just the object
sub popType {
  my ($self, $type,  $instruction) = @_;
  my ($tp,   $value, $src)         = $self->popStack;
  unless (defined($tp)) {
    Warn('bibtex', 'runtime', $instruction->getLocator,
      $instruction->getKind . ' attempted to pop the empty stack');
    return; }
  if ($tp ne $type) {
    Warn('bibtex', 'runtime', $instruction->getLocator,
      $instruction->getKind . " expected to pop type $type from stack, but got type $tp: " . $value);
    return; }
  return (wantarray ? ($value, $src) : $value); }

# 'pushString' pushes an string without a source refence onto the stack.
sub pushString {
  my ($self, $string) = @_;
  push(@{ $$self{stack} }, ['STRING', [$string], [undef]]);
  return; }

# 'pushInteger' pushes an integer without a source refence onto the stack.
sub pushInteger {
  my ($self, $integer) = @_;
  push(@{ $$self{stack} }, ['INTEGER', $integer, undef]);
  return; }

# 'stackEmpty' returns a boolean indicating if the stack is empty.
sub stackEmpty {
  my ($self) = @_;
  return @{ $$self{stack} } == 0; }

# 'duplicateStack' duplicates the top-most entry of the stack.
# returns a boolean indicating if duplication succeeded (i.e. if the stack was empty or not).
sub duplicateStack {
  my ($self) = @_;
  # grab and duplicate value (if needed)
  push(@{ $$self{stack} }, $$self{stack}[-1] || return 0);
  return 1; }

# 'swapStack' swaps the two top-most entries of the stack.
# returns a boolean indicating if swapping succeeded (i.e. if the stack had at least two element or not).
sub swapStack {
  my ($self) = @_;
  return 0 if scalar(@{ $$self{stack} }) <= 1;
  @{ $$self{stack} }[-1, -2] = @{ $$self{stack} }[-2, -1];
  return 1; }

#======================================================================
# VARIABLES

# 'hasVariable' checks if a variable of the given name and type exists.
# When type is omitted, checks if any variable of the given type exists
sub hasVariable {
  my ($self, $name, $type) = @_;
  return ($$self{variableTypes}{$name} || return 0) eq
    ($type || return 1); }

# 'defineVariable' defines a new variable of the given type.
# returns 1 if the variable was defined, 0 if it already existed.
sub defineVariable {
  my ($self, $name, $type) = @_;
  return 0 if defined($$self{variableTypes}{$name});
  # store the type and set initial value if global
  $$self{variableTypes}{$name} = $type;
  # if we don't have an entry variable, initialize them to sensible defaults here
  unless ($type =~ /^ENTRY_/) {
    if ($type eq 'GLOBAL_INTEGER') {
      $$self{variables}{$name} = [('INTEGER', 0, undef)]; }
    elsif ($type eq 'GLOBAL_STRING') {
      $$self{variables}{$name} = [('STRING', [""], [undef])]; }
    else {
      $$self{variables}{$name} = [('UNSET', undef, undef)]; } }
  return 1; }

# 'getVariable' gets a variable of the given name
# Returns a triple (type, value, source).
sub getVariable {
  my ($self, $name) = @_;
  # if the variable does not exist, return nothing
  my $type = $$self{variableTypes}{$name};
  return unless $type;
  # we need to look up inside the current entry
  if ($type eq 'ENTRY_FIELD'
    or $type eq 'ENTRY_STRING'
    or $type eq 'ENTRY_INTEGER')
  {
    my $entry = $$self{entry} || return ('UNSET', undef, undef);
    return $entry->getVariable($name); }
  # 'global' variable => return from our own state
  return (@{ $$self{variables}{$name} }); }

# 'setVariable' sets a variable of the given name.
# A variable is represented by a reference to a triple (type, value, source).
# returns 0 if ok, 1 if it doesn't exist,  2 if an invalid context, 3 if read-only, 4 if unknown type
sub setVariable {
  my ($self, $name, $value) = @_;
  # if the variable does not exist, return nothing
  my $type = $$self{variableTypes}{$name};
  return 1 unless defined($type);
  # normalize name of variable
  $name = lc $name;
  # we need to look up inside the current entry
  if ($type eq 'ENTRY_FIELD'
    or $type eq 'ENTRY_STRING'
    or $type eq 'ENTRY_INTEGER') {
    my $entry = $$self{entry} || return 2;
    return $entry->setVariable($name, $value); }
  # we have a global variable, so take it from our stack
  elsif ($type eq 'GLOBAL_STRING'
    or $type eq 'GLOBAL_INTEGER'
    or $type eq 'FUNCTION') {
    # else assign the value
    $$self{variables}{$name} = $value;
    # and return
    return 0; }
  # I don't know the type
  return 4; }

# 'assignVariable' defines and sets a variable to the given value.
# A variable is represented by a reference to a triple (type, value, source).
# Returns 0 if ok, 1 if it already exists, 2 if an invalid context, 3 if read-only, 4 if unknown type
sub assignVariable {
  my ($self, $name, $type, $value) = @_;
  # define the variable
  my $def = $self->defineVariable($name, $type);
  return 1 unless $def == 1;
  return $self->setVariable($name, $value); }

#======================================================================
# ENTRIES

# 'getEntries' gets a list of all entries
sub getEntries {
  my ($self) = @_;
  return $$self{entries}; }

# 'readEntries' reads in all entries and builds an entry list.
sub readEntries {
  my ($self, $bibliographies, $citations) = @_;
  my @bibliographies = @{$bibliographies};
  if (defined($$self{entries})) {    # Already have entries?
    Warn('bibtex', 'runtime', undef, 'Can not read entries: Already read entries');
    return; }
  my @entries = ();
  foreach my $bibliography (@bibliographies) {
    my $path = $bibliography->getPathname;
    # iterate over all the entries
    foreach my $entry ($bibliography->getEntries($$self{macros})) {
      push(@entries, LaTeXML::BibTeX::Runtime::Entry->new($path, $self, $entry)); }
    push(@{ $$self{preambleString} }, $bibliography->getPreamble);
    push(@{ $$self{preambleSource} }, [($path, '', 'preamble')]);
  }
  # build a map of entries
  my (%entryHash) = ();
  my ($key);
  foreach my $entry (@entries) {
    $key = $entry->getKey;
    if (defined($entryHash{$key})) {
      Warn('bibtex', 'runtime', undef,
        "Skipping duplicate entry for key $key", $$entry{entry}->getSource); }
    else {
      $entryHash{$key} = $entry; } }
  $$self{entryHash} = \%entryHash;
  # TODO: Allow numcrossref customization
  $$self{entries} = $self->buildEntryList([@entries], $citations, 2);
  return; }

# build a list of entries that should be cited.
sub buildEntryList {
  my ($self, $entryList, $citeList, $numCrossRefs) = @_;
  my %citedKeys = ();                   # same as citeList, but key => 1 mapping
  my %related   = ();                   # resolved reference entries
  my @xrefed    = ();
  my @entries   = ();
  my %refmap    = ();                   # [xrefed] => referencing entries
  my $entryHash = $$self{entryHash};    # hash for resolving entries
  my %entryMap  = %$entryHash;

  while (my $citeKey = shift(@$citeList)) {
    # If we already cited something it does not need to be cited again.
    # This is *not* an error, it might regularly occur if things are cited multiple times.
    next if exists($citedKeys{$citeKey});
    # When we receive a '*' key, we need to add all the entries that we know of
    if ($citeKey eq '*') {
      push(@$citeList, map { $_->getKey; } @$entryList);
      next; }
    # find the current entry
    if (my $entry = $entryMap{$citeKey}) {
      # push this entry into the list of cited 'stuff'
      push(@entries, $entry);
      $citedKeys{$citeKey} = 1;
      # grab the cross-referenced entry and resolve it
      my ($xref, $xrefentry) = $entry->resolveCrossReference($entryHash);
      if (defined $xref) {
        if (defined $xrefentry) {
          # Add this item to the 'cited'
          if (!defined($refmap{$xref})) {
            push(@xrefed, $xref);
            $refmap{$xref} = [()]; }
          # and add the current entry to the xrefed entry
          push(@{ $refmap{$xref} }, $entry); }
        else {    # if the cross-referenced entry doesn't exist
          Warn('bibtex', 'runtime', undef,
            "A bad cross reference---entry \"$citeKey\" refers to entry \"$xref\", which doesn't exist",
            $entry->getKind, $$entry{entry}->getSource);    # TODO: Better warning location
          $entry->clearCrossReference(); } } }
    else {
      Warn('bibtex', 'runtime', undef, "I didn't find a database entry for \"$citeKey\""); } }
  # iterate over everything that was cross-referenced
  # and either inline or add it to the citation list
  foreach my $value (@xrefed) {
    my @references = @{ $refmap{$value} };
    my $related    = $entryMap{$value};
    my $exists     = exists($citedKeys{$value});
    # We always inline cross-referenced entries.
    # When few references to a specific entry is small enough we remove the 'crossref' key.
    my $hideCrossref = !$exists && scalar @references < $numCrossRefs;
    foreach my $reference (@references) {
      $reference->inlineCrossReference($related, $hideCrossref); }
    # if there are more, it is included in the list of entries
    push(@entries, $related) unless ($hideCrossref || $exists); }
  return [@entries]; }

sub getPreamble {
  my ($self) = @_;
  return $$self{preambleString}, $$self{preambleSource}; }

# sort entries in-place using a comparison function
# return 1 iff entriues have been sorted
sub sortEntries {
  my ($self, $comp) = @_;
  $$self{entries} = [sort { &{$comp}($a, $b) } @{ $$self{entries} }];
  return 1; }

# sets the current entry
sub setEntry {
  my ($self, $entry) = @_;
  $$self{entry} = $entry;
  return $entry; }

# 'findEntry' finds and activates the entry with the given key and returns it.
# If no such entry exists, returns undef.
sub findEntry {
  my ($self, $key) = @_;
  my $theEntry;
  # if we have a hash for entries (i.e. we were initialized)
  # we should just lookup the key
  my $entryHash = $$self{entryHash};
  if (defined($entryHash)) {
    my %hash = %{$entryHash};
    $theEntry = $hash{$key}; }
  # if we weren't initalized, we need to iterate
  else {
    foreach my $entry (@{ $self->getEntries() }) {
      if ($entry->getKey eq $key) {
        $theEntry = $entry;
        last; } } }
  # set the active entry and return it
  return $self->setEntry($theEntry) if defined($theEntry);
  return; }

# gets the current entry (if any)
sub getEntry {
  my ($self) = @_;
  return $$self{entry}; }

# leave the current entry (if any)
sub leaveEntry {
  my ($self) = @_;
  $$self{entry} = undef;
  return; }

#======================================================================
1;
