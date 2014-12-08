# /=====================================================================\ #
# |  LaTeXML::Common::Error                                             | #
# | Error handler                                                       | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Error;
use strict;
use warnings;
use LaTeXML::Global;
##use LaTeXML::Common::Object;
use Time::HiRes;
use base qw(Exporter);
our @EXPORT = (
  # Error Reporting
  qw(&Fatal &Error &Warn &Info),
  # Progress reporting
  qw( &NoteProgress &NoteProgressDetailed &NoteBegin &NoteEnd),
);

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Note: The exported symbols should ultimately be exported as part
# of LaTeXML::Common, or something like that, to be used BOTH in
# Digestion & Post-Processing.
# ======================================================================
# We want LaTeXML::Global to import this package,
# but we also want to use some of it's low-level functions.
sub ToString {
  my ($item, @more) = @_;
  return ($LaTeXML::BAILOUT ? "$item" : LaTeXML::Common::Object::ToString($item, @more)); }

sub Stringify {
  my ($item, @more) = @_;
  return ($LaTeXML::BAILOUT ? "$item" : LaTeXML::Common::Object::Stringify($item, @more)); }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Error reporting
# Public API

sub Fatal {
  my ($category, $object, $where, $message, @details) = @_;
  my $state = $STATE;
  my $verbosity = $state && $state->lookupValue('VERBOSITY') || 0;
##  if (!$LaTeXML::Common::Error::InHandler && defined($^S)) {
  if (!$LaTeXML::Common::Error::InHandler) {
    local $LaTeXML::BAILOUT = $LaTeXML::BAILOUT;
    if (checkRecursiveError()) {
      $LaTeXML::BAILOUT = 1;
      push(@details, "Recursive Error!"); }
    $state && $state->noteStatus('fatal');
    $message
      = generateMessage("Fatal:" . $category . ":" . ToString($object), $where, $message, 1,
      # ?!?!?!?!?!
      # or just verbosity code >>>1 ???
      @details,
      ($verbosity > 0 ? ("Stack Trace:", stacktrace()) : ()));
    # We're about to DIE, which will bypass the usual status message, so add it here.
    $message .= $state->getStatusMessage if $state;
  }
  else {    # If we ARE in a recursive call, the actual message is $details[0]
    $message = $details[0] if $details[0]; }
  local $LaTeXML::Common::Error::InHandler = 1;
  local $$SIG{__DIE__} = undef;
  die $message; }

sub checkRecursiveError {
  my @caller;
  for (my $frame = 2 ; @caller = caller($frame) ; $frame++) {
    if ($caller[3] =~ /^LaTeXML::(Global::ToString|Global::Stringify)$/) {
      #      print STDERR "RECURSED ON $caller[3]\n";
      return 1; } }
  return; }

# Note that "100" is hardwired into TeX, The Program!!!
my $MAXERRORS = 100;    # [CONSTANT]

# Should be fatal if strict is set, else warn.
sub Error {
  my ($category, $object, $where, $message, @details) = @_;
  my $state = $STATE;
  my $verbosity = $state && $state->lookupValue('VERBOSITY') || 0;
  if ($state && $state->lookupValue('STRICT')) {
    Fatal($category, $object, $where, $message, @details); }
  else {
    $state && $state->noteStatus('error');
    print STDERR generateMessage("Error:" . $category . ":" . ToString($object),
      $where, $message, 1, @details)
      if $verbosity >= -2; }
  if (!$state || ($state->getStatus('error') || 0) > $MAXERRORS) {
    Fatal('too_many_errors', $MAXERRORS, $where, "Too many errors (> $MAXERRORS)!"); }
  return; }

# Warning message; results may be OK, but somewhat unlikely
sub Warn {
  my ($category, $object, $where, $message, @details) = @_;
  my $state = $STATE;
  my $verbosity = $state && $state->lookupValue('VERBOSITY') || 0;
  $state && $state->noteStatus('warning');
  print STDERR generateMessage("Warning:" . $category . ":" . ToString($object),
    $where, $message, 0, @details)
    if $verbosity >= -1;
  return; }

# Informational message; results likely unaffected
# but the message may give clues about subsequent warnings or errors
sub Info {
  my ($category, $object, $where, $message, @details) = @_;
  my $state = $STATE;
  my $verbosity = $state && $state->lookupValue('VERBOSITY') || 0;
  $state && $state->noteStatus('info');
  print STDERR generateMessage("Info:" . $category . ":" . ToString($object),
    $where, $message, -1, @details)
    if $verbosity >= 0;
  return; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Progress Reporting
#**********************************************************************
# Progress reporting.

sub NoteProgress {
  my (@stuff) = @_;
  my $state = $STATE;
  my $verbosity = $state && $state->lookupValue('VERBOSITY') || 0;
  print STDERR @stuff if $verbosity >= 0;
  return; }

sub NoteProgressDetailed {
  my (@stuff) = @_;
  my $state = $STATE;
  my $verbosity = $state && $state->lookupValue('VERBOSITY') || 0;
  print STDERR @stuff if $verbosity >= 1;
  return; }

sub NoteBegin {
  my ($stage) = @_;
  my $state = $STATE;
  my $verbosity = $state && $state->lookupValue('VERBOSITY') || 0;
  if ($state && ($verbosity >= 0)) {
    $state->assignMapping('NOTE_TIMERS', $stage, [Time::HiRes::gettimeofday]);
    print STDERR "\n($stage..."; }
  return; }

sub NoteEnd {
  my ($stage) = @_;
  my $state = $STATE;
  my $verbosity = $state && $state->lookupValue('VERBOSITY') || 0;
  if (my $start = $state && $state->lookupMapping('NOTE_TIMERS', $stage)) {
    $state->assignMapping('NOTE_TIMERS', $stage, undef);
    if ($verbosity >= 0) {
      my $elapsed = Time::HiRes::tv_interval($start, [Time::HiRes::gettimeofday]);
      print STDERR sprintf(" %.2f sec)", $elapsed); } }
  return; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Handlers for perl's die & warn
# We'll try to decode some common errors to make them more usable
# for build systems.

my $quoted_re     = qr/\"([^\"]*)\"/;                                                   # [CONSTANT]
my $cantcall_re   = qr/Can't call method/;                                              # [CONSTANT]
my $cantlocate_re = qr/Can't locate object method/;                                     # [CONSTANT]
my $noself_re     = qr/on an undefined value|without a package or object reference/;    # [CONSTANT]
my $via_re        = qr/via package/;                                                    # [CONSTANT]
my $at_re         = qr/at (.*)/;                                                        # [CONSTANT]

sub perl_die_handler {
  my (@line) = @_;
  # We try to find a meaningful name for where the error occurred;
  # That's the thing that is "misdefined", after all.
  # Not completely sure we're looking in the right place up the stack, though.
  if ($line[0] =~ /^$cantcall_re\s+$cantcall_re\s+($noself_re)\s+$at_re$/) {
    my ($method, $kind, $where) = ($1, $2, $3);
    Fatal('misdefined', callerName(2), $where, @line); }
  elsif ($line[0] =~ /^$cantlocate_re\s+$quoted_re\s+$via_re\s+$quoted_re\s+$at_re$/) {
    my ($method, $class, $where) = ($1, $2, $3);
    Fatal('misdefined', callerName(2), $where, @line); }
  elsif ($line[0] =~ /^Not an? (\w*) reference at (.*)$/) {
    my ($type, $where) = ($1, $2);
    Fatal('misdefined', callerName(2), $where, @line); }
  elsif ($line[0] =~ /^File (.*?) had an error:/) {
    my ($file) = ($1);
    Fatal('misdefined', $file, undef, @line); }
  else {
    Fatal('perl', 'die', undef, "Perl died", @line); }
  return; }

sub perl_warn_handler {
  my (@line) = @_;
  Warn('perl', 'warn', undef, "Perl warning", @line);
  return; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Internals
# Synthesize an error message describing what happened, and where.
# $detail specifies the level of detail
#   $detail == -1 : no context or stack
#   $detail == 0  : context, no stack
#   $detail == +1 : context & stack
# including a level requesting full stack trace?

sub generateMessage {
  my ($errorcode, $where, $message, $detail, @extra) = @_;
  #----------------------------------------
  # Generate location information; basic and for stack trace.
  # If we've been given an object $where, where the error occurred, use it.
  my $docloc = getLocation($where);

  # $message and each of @extra should be single lines
  ($message, @extra) = grep { $_ ne '' } map { split("\n", $_) } grep { defined $_ } $message, @extra;
  # The initial portion of the message will consist of:
  $message = '' unless defined $message;
  my @lines = (
    # Start with the error code & primary error message
    $errorcode . ' ' . $message,
    # Followed by single line location of where the message occurred (if we know)
    ($docloc ? ($docloc) : ()),
    # and then any additional message lines supplied
    @extra);

  #----------------------------------------
  # Now add some additional context
  # NOTE: Should skip this for INFO
  # NOTE: Need to pass more of this onto the objects themselves....
  # What should it be called?
  #   showErrorContext() ?????
  $detail = 0 unless defined $detail;
  # Increment $detail if $verbosity > 0, unless $detail = -1,
  my $verbosity = ($STATE && $STATE->lookupValue('VERBOSITY')) || 0;
  if (($detail > -1) && ($verbosity > 0)) {
    $detail = 0 if defined $verbosity && $verbosity < -1;
    $detail++ if defined $verbosity && $verbosity > +1; }

  # FIRST line of stack trace information ought to look at the $where
  my $wheretype = ref $where;
  if ($detail <= 0) { }    # No extra context
  elsif ($wheretype =~ /^XML::LibXML/) {
    push(@lines, "Node is " . Stringify($where)); }
  ## Hmm... if we're being verbose or level is high, we might do this:
  ### "Currently in ".$doc->getInsertionContext); }
  elsif ($wheretype =~ 'LaTeXML::Core::Gullet') {
    push(@lines, $where->showUnexpected); }    # Or better?
  elsif ($wheretype =~ 'LaTeXML::Core::Stomach') {
    push(@lines,
      "Recently digested: " . join(' ', map { Stringify($_) } @LaTeXML::LIST))
      if $verbosity > 1; }

  #----------------------------------------
  # Add Stack Trace, if that seems worthwhile.
  if ($detail > -1) {
    my $nstack = ($detail > 1 ? undef : ($detail > 0 ? 4 : 1));
    if (my @objects = objectStack($nstack)) {
      my $top = shift(@objects);
      push(@lines,   "In " . trim(ToString($top)) . ' ' . ToString(Locator($top)));
      push(@objects, '...') if @objects && defined $nstack;
      push(@lines,   join('', (map { ' <= ' . trim(ToString($_)) } @objects))) if @objects; } }

  # finally, join the result into a block of lines, indenting all but the 1st line.
  return "\n" . join("\n\t", @lines) . "\n"; }

sub Locator {
  my ($object) = @_;
  return ($object && $object->can('getLocator') ? $object->getLocator : "???"); }

sub getLocation {
  my ($where) = @_;
  my $wheretype = ref $where;
  if ($wheretype && ($wheretype =~ /^XML::LibXML/)) {
    my $box = $LaTeXML::DOCUMENT->getNodeBox($where);
    return Locator($box) if $box; }
  elsif ($wheretype && $where->can('getLocator')) {
    return $where->getLocator; }
  elsif (defined $where) {
    return $where; }
  # Otherwise, try to guess where the error came from!
  elsif ($LaTeXML::DOCUMENT) {    # During construction?
    my $node = $LaTeXML::DOCUMENT->getNode;
    my $box  = $LaTeXML::DOCUMENT->getNodeBox($node);
    return Locator($box) if $box; }
  if ($LaTeXML::BOX) {            # In constructor?
    return Locator($LaTeXML::BOX); }
  if ($STATE && $STATE->getStomach) {
    my $gullet = $STATE->getStomach->getGullet;
    # NOTE: Problems here.
    # (1) With obsoleting Tokens as a Mouth, we can get pointless "Anonymous String" locators!
    # (2) If gullet is the source, we probably want to include next token, etc or
    return $gullet->getLocator(); }
  return; }

sub callerName {
  my ($frame) = @_;
  my %info = caller_info(($frame || 0) + 2);
  return $info{sub}; }

sub callerInfo {
  my ($frame) = @_;
  my %info = caller_info(($frame || 0) + 2);
  return "$info{call} @ $info{file} line $info{line}"; }

#======================================================================
# This portion adapted from Carp; simplified (but hopefully still correct),
# allow stringify overload, handle methods, make more concise!
#======================================================================
my $MAXARGS = 8;     # [CONSTANT]
my $MAXLEN  = 40;    # Or more? [CONSTANT]

sub trim {
  my ($string) = @_;
  return $string unless defined $string;
  $string = substr($string, 0, $MAXLEN - 3) . "..." if (length($string) > $MAXLEN);
  $string =~ s/\n/\x{240D}/gs;    # symbol for CR
  return $string; }

sub caller_info {
  my ($i) = @_;

  my (%info, @args);
  { package DB;
    @info{qw(package file line sub has_args wantarray evaltext is_require)}
      = caller($i);
    @args = @DB::args; }
  return () unless defined $info{package};
  # Work out the effective sub name, or eval, or method ...
  my $call = '';
  if (defined $info{evaltext}) {
    my $eval = $info{evaltext};
    if ($info{is_require}) {
      $call = "require $eval"; }
    else {
      $eval =~ s/([\\\'])/\\$1/g;
      $call = "eval '" . trim($eval) . "'"; } }
  elsif ($info{sub} eq '(eval)') {
    $call = "eval {...}"; }
  else {
    $call = $info{sub};
    my $method = $call;
    $method =~ s/^.*:://;
    # If $arg[0] is blessed, and `can' do $method, then we'll guess it's a method call?
    if ($info{has_args} && @args
      && ref $args[0] && ((ref $args[0]) !~ /^(?:SCALAR|ARRAY|HASH|CODE|REF|GLOB|LVALUE)$/)
      && $args[0]->can($method)) {
      $call = format_arg(shift(@args)) . "->" . $method; } }
  # Append arguments, if any.
  if ($info{has_args}) {
    @args = map { format_arg($_) } @args;
    if (@args > $MAXARGS) {
      $#args = $MAXARGS; push(@args, '...'); }
    $call .= '(' . join(',', @args) . ')'; }
  $info{call} = $call;
  return %info; }

sub format_arg {
  my ($arg) = @_;
  if    (not defined $arg) { $arg = 'undef'; }
  elsif (ref $arg)         { $arg = Stringify($arg); }    # Allow overloaded stringify!
  elsif ($arg =~ /^-?[\d.]+\z/) { }                       # Leave numbers alone.
  else {                                                  # Otherwise, string, so quote
    $arg =~ s/'/\\'/g;                                    # Slashify '
    $arg =~ s/([[:cntrl::]])/ "\\".chr(ord($1)+ord('A'))/ge;
    $arg = "'$arg'" }
  return trim($arg); }

# Semi-traditional (but reformatted) stack trace
sub stacktrace {
  my $frame = 0;
  my $trace = "";
  while (my %info = caller_info($frame++)) {
    next if $info{sub} =~ /^LaTeXML::Common::Error/;
##    $info{call} = '' if $info{sub} =~ /^LaTeXML::Common::Error::(?:Fatal|Error|Warn|Info)/;
    $trace .= "\t$info{call} @ $info{file} line $info{line}\n"; }
  return $trace; }

# Extract blessed `interesting' objects on stack.
# Get a maximum of $maxdepth objects (if $maxdepth is defined).
sub objectStack {
  my ($maxdepth) = @_;
  my $frame      = 0;
  my @objects    = ();
  while (1) {
    my (%info, @args);
    { package DB;
      @info{qw(package file line sub has_args wantarray evaltext is_require)} = caller($frame++);
      @args = @DB::args; }
    last unless defined $info{package};
    next if ($info{sub} eq '(eval)') || !$info{has_args} || !@args;
    my $self = $args[0];
    # If $arg[0] is blessed, and `can' do $method, then we'll guess it's a method call?
    # We'll collect such objects provided they can ->getLocator
    if ((ref $self) && ((ref $self) !~ /^(?:SCALAR|ARRAY|HASH|CODE|REF|GLOB|LVALUE)$/)) {
      my $method = $info{sub};
      $method =~ s/^.*:://;
      if ($self->can($method)) {
        next if @objects && ($self eq $objects[-1]);
        next unless $self->can('getLocator');
        push(@objects, $self);
        last if $maxdepth && (scalar(@objects) >= $maxdepth); } } }
  return @objects; }

#**********************************************************************
1;

__END__

=pod

=head1 NAME

C<LaTeXML::Common::Error> - Error and Progress Reporting and Logging support.

=head1 DESCRIPTION

C<LaTeXML::Common::Error> does some simple stack analysis to generate more informative, readable,
error messages for LaTeXML.  Its routines are used by the error reporting methods
from L<LaTeXML::Global>, namely C<Warn>, C<Error> and C<Fatal>.

=head2 Error Reporting

The Error reporting functions all take a similar set of arguments,
the differences are in the implied severity of the situation,
and in the amount of detail that will be reported.

The C<$category> is a string naming a broad category of errors,
such as "undefined". The set is open-ended, but see the manual
for a list of recognized categories.  C<$object> is the object
whose presence or lack caused the problem.

C<$where> indicates where the problem occurred; passs in
the C<$gullet> or C<$stomach> if the problem occurred during
expansion or digestion; pass in a document node if it occurred there.
A string will be used as is; if an undefined value is used,
the error handler will try to guess.

The C<$message> should be a somewhat concise, but readable,
explanation of the problem, but ought to not refer to the
document or any "incident specific" information, so as to
support indexing in build systems.  C<@details> provides
additional lines of information that may be indident specific.

=over 4

=item C<< Fatal($category,$object,$where,$message,@details); >>

Signals an fatal error, printing C<$message> along with some context.
In verbose mode a stack trace is printed.

=item C<< Error($category,$object,$where,$message,@details); >>

Signals an error, printing C<$message> along with some context.
If in strict mode, this is the same as Fatal().
Otherwise, it attempts to continue processing..

=item C<< Warn($category,$object,$where,$message,@details); >>

Prints a warning message along with a short indicator of
the input context, unless verbosity is quiet.

=item C<< Info($category,$object,$where,$message,@details); >>

Prints an informational message along with a short indicator of
the input context, unless verbosity is quiet.

=item C<< NoteProgress($message); >>

Prints C<$message> unless the verbosity level below 0.
Typically just a short mark to indicate motion, but can be longer;
provide your own newlines, if needed.

=item C<< NoteProgressDetailed($message); >>

Like C<NoteProgress>, but for noiser progress, only prints when verbosity >= 1.

=back

=head2 Internal Functions

No user serviceable parts inside.  These symbols are not exported.

=over 4

=item C<< $string = LaTeXML::Common::Error::generateMessage($typ,$msg,$lng,@more); >>

Constructs an error or warning message based on the current stack and
the current location in the document.
C<$typ> is a short string characterizing the type of message, such as "Error".  
C<$msg> is the error message itself. If C<$lng> is true, will generate a
more verbose message; this also uses the VERBOSITY set in the C<$STATE>.
Longer messages will show a trace of the objects invoked on the stack,
C<@more> are additional strings to include in the message.

=item C<< $string = LaTeXML::Common::Error::stacktrace; >>

Return a formatted string showing a trace of the stackframes up until this
function was invoked.

=item C<< @objects = LaTeXML::Common::Error::objectStack; >>

Return a list of objects invoked on the stack.  This procedure only
considers those stackframes which involve methods, and the objects are
those (unique) objects that the method was called on.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

