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
use LaTeXML::Common::Object;
use LaTeXML::Util::Pathname;
use Time::HiRes;
use Term::ANSIColor 2.01 qw(colored colorstrip);

use base qw(Exporter);
our @EXPORT = (
  qw(&SetVerbosity),
  # Managing STDERR messages
  qw(&OpenSTDERR &CloseSTDERR),
  # Log file support
  qw(&OpenLog &CloseLog),
  # Error Reporting
  qw(&Fatal &Error &Warn &Info),
  # General messages
  qw(&Note &NoteTerminal &NoteLog),
  # Progress Spinner
  qw(&ProgressSpinup &ProgressSpindown &ProgressStep),
  # Debugging messages
  qw(&DebuggableFeature &Debug &CheckDebuggable),
  # Colored-logging related functions
  qw(&colorizeString),
  # stateless message generation
  qw(&generateMessage),
  # Status management
  qw(&MergeStatus),
);

our $VERBOSITY = 0;

sub SetVerbosity {
  # Validate?
  return $VERBOSITY = $_[0]; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Terminal setup

# Color setup
# Possibly more dynamic?
$Term::ANSIColor::AUTORESET = 1;
our $IS_TERMINAL = undef;
our $USE_STDERR  = undef;

# Possibility of more terminal initialization & control?
sub OpenSTDERR {
  $USE_STDERR  = 1;
  $IS_TERMINAL = -t STDERR;
  binmode(STDERR, ":encoding(UTF-8)");
  use IO::Handle;
  *STDERR->autoflush();
  return; }

sub CloseSTDERR {
  $USE_STDERR  = undef;
  $IS_TERMINAL = undef;
  return; }

our %color_scheme = (
  details => 'bold',
  success => 'green',
  info    => 'bright_blue',          # bright only recently defined
  warning => 'yellow',
  error   => 'bold red',
  fatal   => 'bold red underline',
);

sub colorizeString {
  my ($string, $alias) = @_;
  return ($IS_TERMINAL && $color_scheme{$alias}
    ? colored($string, $color_scheme{$alias})
    : $string); }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Log file
# Initially: possibility of a single log file, as well as STDERR
# General idea: everything goes to the log file (if any)
# only a little bit goes to STDERR (controllable by verbosity)
# Is there a single DWIM strategy that puts the right things on each stream?
our $LOG;
our $LOG_PATH;
# NOTE: since LaTeXML.pm (currently) repeatedly opens & closes the log,
# and doesn't (YET) know whether there's already a log open,
# this bit of hackery only keeps the outermost log open. Fix this!
our $log_count = 0;
# Where? Current directory? (probably) Source directory? (probably not)
# Option for appending?
# Note that the $path can be a reference to a string (which gets appended to)
sub OpenLog {
  my ($path, $append) = @_;
  $log_count++;
  return if $LOG or not($path);                 # already opened?
  pathname_mkdir(pathname_directory($path));    # and hopefully no errors! :>
  open($LOG, ($append ? '>>' : '>'), $path) or die "Cannot open log file $path for writing: $!";
  $LOG_PATH = $path;
  binmode($LOG, ":encoding(UTF-8)");
  return; }

# Should be sure it autocloses
sub CloseLog {
  $log_count--;
  return if !$LOG || $log_count;
  # ensure trailing newline when flushing, since we may have
  # multiple re-opens during the same conversion run (preamble, main, post ...)
  print $LOG _freshline($LOG);
  close($LOG) or die "Cannot close log file: $!";
  $LOG = undef;
  return; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Low-level I/O

# print one (or more) lines to the Log and STDERR, according to $loglevel, $termlevel, respectively.
# If verbosity == $termlevel, only prints the 1st line of the message.
# Print to STDERR if verbosity is >= $level; only first line if verbosity is >= $shortlevel.
# Starts a fresh line by pushing any Spinner line ahead.
# ORRR should $level also apply to Logfile ???
sub _printline {
  my ($loglevel, $termlevel, $message) = @_;
  return if ($VERBOSITY < $loglevel) && ($VERBOSITY < $termlevel);
  $message =~ s/^\n+//s;    # Strip newlines off ends.
  $message =~ s/\n+$//s;
  my $clean_message = ($LOG || !$IS_TERMINAL ? strip_ansi($message) : $message);
  $message = $clean_message unless $IS_TERMINAL;
  # Don't really want this verbosity check, here, but tests fail!
  print $LOG _freshline($LOG), $clean_message, "\n" if $LOG && ($VERBOSITY >= $loglevel);

  # Spinner logic only for terminal-enabled applications
  return unless $USE_STDERR;

  _spinnerclear();
##  if ($VERBOSITY > $termlevel) {
##    print STDERR _freshline(\*STDERR), $message, "\n"; }
##  elsif ($VERBOSITY == $termlevel) {
# Show only single line: first line plus including 2nd, if locator
#  my $short = ($message =~ /^([^\n]*)(:?\n(\s*at\s+[^\n]*))?/s ? $1 . ($2 ? '...' . $3 : '') : $message);
  my $short = $message;
  if ($short =~ /^([^\n]*)(:?\n\s*(at\s+[^\n]*))?/s) {
    my ($first, $more, $at) = ($1, $2, $3);
    $at =~ s/\s+-\s+.*$// if $at;
    $short = $first;
    $short .= ' ' . $at if $at; }
  print STDERR _freshline(\*STDERR), $short, "\n";    ##}
  _spinnerrestore();
  return; }

our %NEEDSFRESHLINE = ();

sub _freshline {
  my ($stream) = @_;
  if ($stream && $NEEDSFRESHLINE{$stream}) {
    $NEEDSFRESHLINE{$stream} = 0;
    return "\n"; }
  return ''; }

sub strip_ansi {
  my ($string) = @_;
  $string =~ s/\e\[[0-9;]*[a-zA-Z]//g;
  return $string; }

#======================================================================
# Spinner support
# Stack of [stage,count,count_message]
# Note: Would look prettier if we blank the cursor, but have to restore!
# Note: linewrap leaves terminal turds: the disable/enable codes are VT escape codes
our @spinnerstack = ();
our @spinnerchar  = map { colored($_, "bold red"); } ('-', '\\', '|', '/');
our $spinnerpos   = 0;
our $spinnerpre   = "\x1b[1G\x1b[?7l";    # Cursor to col 1; turn off linewrap
our $spinnerpost  = "\x1b[?7h";
# sub _spinnerreset {
#   if($USE_STDERR && $IS_TERMINAL){
#     print STDERR "\x1b[?7h"; }  # Reset linewrap on
#   return; }

sub _spinnerclear {    # Clear the spinner line (if any)
##  if ($USE_STDERR && $IS_TERMINAL && ($VERBOSITY >= 0) && @spinnerstack) {
  if ($USE_STDERR && $IS_TERMINAL && @spinnerstack) {
    print STDERR "\x1b[1G\x1b[0K"; }    # clear line
  return; }

sub _spinnerrestore {    # Restore the spinner line (if any)
##  if ($USE_STDERR && $IS_TERMINAL && ($VERBOSITY >= 0) && @spinnerstack) {
  if ($USE_STDERR && $IS_TERMINAL && @spinnerstack) {
    my ($stage, $short, $start) = @{ $spinnerstack[-1] };
    print STDERR join(' ', $spinnerpre, $spinnerchar[$spinnerpos],
      (map { $$_[1]; } @spinnerstack[0 .. $#spinnerstack - 1]), $stage), $spinnerpost; }
  return; }

sub _spinnerstep {    # Increment stepper
  my ($note) = @_;
##  if ($USE_STDERR && $IS_TERMINAL && ($VERBOSITY >= 0) && @spinnerstack) {
  if ($USE_STDERR && $IS_TERMINAL && @spinnerstack) {
    my ($stage, $short, $start) = @{ $spinnerstack[-1] };
    $spinnerpos = ($spinnerpos + 1) % 4;
    if ($note) {      # If note, redraw whole line.
      print STDERR join(' ', $spinnerpre, $spinnerchar[$spinnerpos],
        (map { $$_[1]; } @spinnerstack), $note, "\x1b[0K"), $spinnerpost; }
    else {            # overwrite previous spinner
      print STDERR $spinnerpre . ' ', $spinnerchar[$spinnerpos], $spinnerpost; } }
  return; }

sub _spinnerpush {    # New spinner level
  my ($stage) = @_;
  my $short = ($stage =~ /^(\w+)\s+(.*)$/ && $2 ? "$1 >" : $stage);
  push(@spinnerstack, [$stage, $short, [Time::HiRes::gettimeofday]]);
  return; }

sub _spinnerpop {    # Finished with spinner level
  my ($stage) = @_;
  if (@spinnerstack && ($stage eq $spinnerstack[-1][0])) {
    my ($stage, $short, $start) = @{ pop(@spinnerstack) };
    return Time::HiRes::tv_interval($start, [Time::HiRes::gettimeofday]); }
  elsif ($USE_STDERR) {    # What else to do about mis-matched begin/end ??
    print STDERR "SPINNER is " . ((@spinnerstack && $spinnerstack[-1][0]) || 'undef') . " not $stage\n"; }
  return; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Error reporting
# Public API

sub Fatal {
  my ($category, $object, $where, $message, @details) = @_;

# Check if this is a known unsafe fatal and flag it if so (so that we reinitialize in daemon contexts)
  if ((($category eq 'internal') && ($object eq '<recursion>')) ||
    ($category eq 'too_many_errors')) {
    $LaTeXML::UNSAFE_FATAL = 1; }

  # We'll assume that if the DIE handler is bound (presumably to this function)
  # we're in the outermost call to Fatal; we'll clear the handler so that we don't nest calls.
  die $message if $LaTeXML::IGNORE_ERRORS        # Short circuit, w/no formatting, if in probing eval
    || (($SIG{__DIE__} eq 'DEFAULT') && $^S);    # Also missing class when parsing bindings(?!?!)

  # print STDERR "\nHANDLING FATAL:"
  #   ." ignore=".($LaTeXML::IGNORE_ERRORS || '<no>')
  #   ." handler=".($SIG{__DIE__}||'<none>')
  #   ." parsing=".($^S||'<no>')
  #   ."\n";
  my $inhandler = !$SIG{__DIE__};
  my $ineval    = 0;                # whether we're in an eval should no longer matter!

  # This seemingly should be "local", but that doesn't seem to help with timeout/alarm/term?
  # It should be safe so long as the caller has bound it and rebinds it if necessary.
  local $SIG{__DIE__} = 'DEFAULT';    # Avoid recursion while preparing the message.
  my $state = $STATE;

  if (!$inhandler) {
    local $LaTeXML::BAILOUT = $LaTeXML::BAILOUT;
    if (checkRecursiveError()) {
      $LaTeXML::BAILOUT = 1;
      push(@details, "Recursive Error!"); }
    $state->noteStatus('fatal') if $state && !$ineval;
    my $detail_level = (($VERBOSITY <= 1) && ($category =~ /^(?:timeout|too_many_errors)$/)) ? 0 : 2;
    $message
      = generateMessage("Fatal:" . $category . ":" . ToString($object),
      $where, $message, $detail_level, @details);
    # If we're about to (really) DIE, we'll bypass the usual status message, so add it here.
    # This really should be handled by the top-level program,
    # after doing all processing within an eval
    # BIZARRE: Note that die adds the "at <file> <line>" stuff IFF the message doesn't end w/ CR!
    $message .= $state->getStatusMessage . "\n" if $state && !$ineval;
  }
  else {    # If we ARE in a recursive call, the actual message is $details[0]
    $message = $details[0] if $details[0]; }
  # inhibit message to STDERR, since die will handle that
  _printline(-9999, -9999, $message);
  # If inside an eval, this won't actually die, but WILL set $@ for caller's use.
  die $message; }

sub checkRecursiveError {
  my @caller;
  for (my $frame = 2 ; @caller = caller($frame) ; $frame++) {
    if ($caller[3] =~ /^LaTeXML::(Global::ToString|Global::Stringify)$/) {
      #      print STDERR "RECURSED ON $caller[3]\n";
      return 1; } }
  return; }

# Should be fatal if strict is set, else warn.
sub Error {
  my ($category, $object, $where, $message, @details) = @_;
  return if $LaTeXML::IGNORE_ERRORS;
  my $state = $STATE;
  if ($state && $state->lookupValue('STRICT')) {
    Fatal($category, $object, $where, $message, @details); }
  else {
    $state && $state->noteStatus('error');
    my $formatted = generateMessage("Error:" . $category . ":" . ToString($object),
      $where, $message, 1, @details);
    _printline(0, 0, $formatted); }
  # Note that "100" is hardwired into TeX, The Program!!!
  my $maxerrors = ($state ? $state->lookupValue('MAX_ERRORS') : 100);
  if ($state && (defined $maxerrors) && (($state->getStatus('error') || 0) > $maxerrors)) {
    Fatal('too_many_errors', $maxerrors, $where, "Too many errors (> $maxerrors)!"); }
  return; }

# Warning message; results may be OK, but somewhat unlikely
sub Warn {
  my ($category, $object, $where, $message, @details) = @_;
  return if $LaTeXML::IGNORE_ERRORS;
  my $state = $STATE;
  $state && $state->noteStatus('warning');
  my $formatted = generateMessage("Warning:" . $category . ":" . ToString($object),
    $where, $message, 0, @details);
  _printline(0, 0, $formatted);
  return; }

# Informational message; results likely unaffected
# but the message may give clues about subsequent warnings or errors
sub Info {
  my ($category, $object, $where, $message, @details) = @_;
  return if $LaTeXML::IGNORE_ERRORS;
  my $state = $STATE;
  $state && $state->noteStatus('info');
  my $formatted = generateMessage("Info:" . $category . ":" . ToString($object),
    $where, $message, -1, @details);
  _printline(0, 0, $formatted);
  return; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Progress Reporting
#**********************************************************************

sub Note {
  my (@stuff) = @_;
  _printline(0, 0, join('', @stuff));
  return; }

sub NoteTerminal {
  my (@stuff) = @_;
  if ($USE_STDERR) {
    _spinnerclear();
    print STDERR _freshline(\*STDERR), @stuff, "\n";
    _spinnerrestore(); }
  return; }

sub NoteLog {
  my (@stuff) = @_;
  print $LOG _freshline($LOG), strip_ansi(join('', @stuff)), "\n" if $LOG && ($VERBOSITY >= 0); # verbosity???
  return; }

# NOTE: Make this OBSOLETE!
sub NoteStatus {
  my (@stuff) = @_;
  _printline(0, 0, join('', @stuff));
  return; }

# Progress reporting.
# Needs LOG/STDERR sorted out. Maybe some Term magic on STDERR? (rotating "-"?)
# Possibly wants more explicit levels?
# or at least a report-always level?
sub ProgressStep {
  my ($note) = @_;
  _spinnerstep($note);
  return; }

sub ProgressSpinup {
  my ($stage) = @_;
  if ($VERBOSITY >= 0) {
    _spinnerclear();
    _spinnerpush($stage);
    _spinnerrestore();
    my $message = "($stage...";
    print $LOG _freshline($LOG), $message if $LOG && ($VERBOSITY >= 0);    # verbosity???
    $NEEDSFRESHLINE{$LOG} = 1 if $LOG;
## NOTE: Rethink this; possibly want something going to non-terminals, but this fouls tests
    if ($USE_STDERR && !$IS_TERMINAL) {
      print STDERR _freshline(\*STDERR), $message;
      $NEEDSFRESHLINE{ \*STDERR } = 1; } }
  return; }

sub ProgressSpindown {
  my ($stage) = @_;
  if ($VERBOSITY >= 0) {
    _spinnerclear();
    my $elapsed = _spinnerpop($stage);
    _spinnerrestore();
    my $message = ($elapsed ? sprintf(" %.2f sec)", $elapsed) : '?');
    print $LOG $message       if $LOG && ($VERBOSITY >= 0);    # verbosity???
    $NEEDSFRESHLINE{$LOG} = 1 if $LOG;
    if ($USE_STDERR && !$IS_TERMINAL) {
      print STDERR $message;
      $NEEDSFRESHLINE{ \*STDERR } = 1; } }
  return; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Debugging support.
# Short of real macros, here's a flexible, low-cost debug technique:
#   Debug(message...) if $LaTeXML::DEBUG{feature};
our %Debugbable = ();
#  %LaTeXML::DEBUG      = {};

sub DebuggableFeature {
  my ($feature, $description) = @_;
  $LaTeXML::Debuggable{$feature} = $description;
  return; }

sub Debug {
  # Note: Could append source code location of the caller?
  _printline(0, 0, join('', @_));
  return; }

# This only makes sense at end of run, after all needed modules have been loaded!
sub CheckDebuggable {
  my %unknown = ();
  foreach my $feature (keys %LaTeXML::DEBUG) {
    $unknown{$feature} = 1 unless $LaTeXML::Debuggable{$feature}; }
  # Now report unknown; suggest similar spellings ?
  if (keys %unknown) {
    print STDERR _freshline(\*STDERR), "The debugging feature(s) " . join(', ', sort keys %unknown) . " were never declared\n";
    print STDERR _freshline(\*STDERR), "Known debugging features: " . join(', ', sort keys %LaTeXML::Debuggable) . "\n"; }
  return; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Handlers for perl's die & warn
# We'll try to decode some common errors to make them more usable
# for build systems.

my $quoted_re     = qr/\"([^\"]*)\"/;                                                   # [CONSTANT]
my $cantcall_re   = qr/Can't call method/;                                              # [CONSTANT]
my $cantlocate_re = qr/Can't locate object method/;                                     # [CONSTANT]
my $undef_re      = qr/Undefined subroutine/;                                           # [CONSTANT]
my $noself_re     = qr/on an undefined value|without a package or object reference/;    # [CONSTANT]
my $via_re        = qr/via package/;                                                    # [CONSTANT]
my $at_re         = qr/(at .*)/;                                                        # [CONSTANT]

sub perl_die_handler {
  my (@line) = @_;
  if ($LaTeXML::IGNORE_ERRORS    # Just get out now, if we're ignoring errors within an eval.
    || (colorstrip($line[0]) =~ /^\s*Fatal:/)) {    # Or, we've already been through here.
    local $SIG{__DIE__} = undef;
    die @line; }
  # We try to find a meaningful name for where the error occurred;
  # That's the thing that is "misdefined", after all.
  # Not completely sure we're looking in the right place up the stack, though.
  if ($line[0] =~ /^$cantcall_re\s+$quoted_re\s+($noself_re)\s+$at_re$/) {
    my ($method, $kind, $where) = ($1, $2, $3);
    Fatal('misdefined', callerName(1), $where,
      "Can't call method '$method' $kind", @line[1 .. $#line]); }
  elsif ($line[0] =~ /^$undef_re\s+(\S+)\s+called $at_re$/) {
    my ($function, $where) = ($1, $2);
    Fatal('misdefined', callerName(1), $where,
      "Undefined subroutine '$function' called", @line[1 .. $#line]); }
  elsif ($line[0] =~ /^$cantlocate_re\s+$quoted_re\s+$via_re\s+$quoted_re\s+\(.*\)\s+$at_re/) {
    my ($method, $class, $where) = ($1, $2, $3);
    Fatal('misdefined', callerName(1), $where,
      "Can't locate method '$method' via '$class'", @line[1 .. $#line]); }
  elsif ($line[0] =~ /^Can't locate \S* in \@INC \(you may need to install the (\S*) module\) \(\@INC contains: ([^\)]*)\) $at_re$/) {
    my ($class, $inc, $where) = ($1, $2);
    Fatal('misdefined', callerName(1), $where,
      "Can't locate class '$class' (not installed or misspelled?)", @line[1 .. $#line]); }
  elsif ($line[0] =~ /^Can't use\s+(\w*)\s+\([^\)]*\) as (.*?) ref(?:\s+while "strict refs" in use)? at (.*)$/) {
    my ($gottype, $wanttype, $where) = ($1, $2, $3);
    Fatal('misdefined', callerName(1), $where,
      "Can't use $gottype as $wanttype reference", @line[1 .. $#line]); }
  elsif ($line[0] =~ /^File (.*?) had an error:/) {
    my ($file) = ($1);
    Fatal('misdefined', $file, undef, @line); }
  else {
    Fatal('perl', 'die', undef, "Perl died", @line); }
  return; }

sub perl_warn_handler {
  my (@line) = @_;
  return if $LaTeXML::IGNORE_ERRORS;
  if ($line[0] =~ /^Use of uninitialized value (.*?)(\s?+in .*?)\s+(at\s+.*?\s+line\s+\d+)\.$/) {
    my ($what, $how, $where) = ($1 || 'value', $2, $3);
    Warn('uninitialized', $what, $where, "Use of uninitialized value $what $how", @line[1 .. $#line]); }
  elsif ($line[0] =~ /^Deep recursion on/) {
    Fatal('perl', 'deep_recursion', undef, $line[0]); }
  elsif ($line[0] =~ /^(.*?)\s+(at\s+.*?\s+line\s+\d+)\.$/) {
    my ($warning, $where) = ($1, $2);
    Warn('perl', 'warn', undef, $warning, $where, @line[1 .. $#line]); }
  else {
    Warn('perl', 'warn', undef, "Perl warning", @line); }
  return; }

# The following handlers SHOULD report the problem,
# even when within a "safe" eval that's ignoring errors.
# Moreover, we'd really like to be able to throw all the way to
# the top-level containing eval.  How to do that?
sub perl_interrupt_handler {
  my (@line) = @_;
  $LaTeXML::IGNORE_ERRORS = 0;    # NOT ignored
  $LaTeXML::UNSAFE_FATAL  = 1;
  Fatal('interrupt', 'interrupted', undef, "LaTeXML was interrupted", @line);
  return; }

sub perl_timeout_handler {
  my (@line) = @_;
  $LaTeXML::IGNORE_ERRORS = 0;    # NOT ignored
  $LaTeXML::UNSAFE_FATAL  = 1;
  Fatal('timeout', 'timedout', undef, "Conversion timed out", @line);
  return; }

sub perl_terminate_handler {
  my (@line) = @_;
  $LaTeXML::IGNORE_ERRORS = 0;    # NOT ignored
  $LaTeXML::UNSAFE_FATAL  = 1;
  Fatal('terminate', 'terminated', undef, "Conversion was terminated", @line);
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
  # Colorize errorcode if appropriate
  if ($USE_STDERR && $IS_TERMINAL) {
    $errorcode =~ /^(\w+)\:/;
    my $errorkind = lc($1);
    $errorcode = colorizeString($errorcode, $errorkind) if $errorkind; }

  #----------------------------------------
  # Generate location information; basic and for stack trace.
  # If we've been given an object $where, where the error occurred, use it.
  my $docloc = getLocation($where);
  $docloc = defined $docloc ? ToString($docloc) : '';

  # $message and each of @extra should be single lines
  @extra = grep { $_ ne '' } map { split("\n", $_) } grep { defined $_ } $message, @extra;
  # make 1st line be 1st line of message
  $message = shift(@extra);
  #  $message =~ s/\n.*//g;
  # The initial portion of the message will consist of:
  $message = '' unless defined $message;
  my @lines = (
    # Start with the error code & primary error message
    $errorcode . ' ' . $message,
    # Followed by single line location of where the message occurred (if we know)
    ($docloc ? ('at ' . $docloc) : ()),
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
  if (($detail > -1) && ($VERBOSITY > 0)) {
    $detail = 0 if defined $VERBOSITY && $VERBOSITY < -1;
    $detail++ if defined $VERBOSITY && $VERBOSITY > +1; }

  # FIRST line of stack trace information ought to look at the $where
  my $wheretype = ref $where;
  if    ($detail <= 0) { }                 # No extra context
  elsif ($wheretype =~ /^XML::LibXML/) {
    push(@lines, "Node is " . Stringify($where)); }
  ## Hmm... if we're being verbose or level is high, we might do this:
  ### "Currently in ".$doc->getInsertionContext); }
  elsif ($wheretype =~ 'LaTeXML::Core::Gullet') {
    push(@lines, $where->showUnexpected); }    # Or better?
  elsif ($wheretype =~ 'LaTeXML::Core::Stomach') {
    push(@lines,
      "Recently digested: " . join(' ', map { Stringify($_) } @LaTeXML::LIST))
      if $VERBOSITY > 1; }

  #----------------------------------------
  # Add Stack Trace, if that seems worthwhile.
  if (($detail > 1) && ($VERBOSITY > 0)) {
    push(@lines, "Stack Trace:", stacktrace()); }
  elsif ($detail > -1) {
    my $nstack = ($detail > 1 ? undef : ($detail > 0 ? 4 : 1));
    if (my @objects = objectStack($nstack)) {
      my $top = shift(@objects);
      push(@lines,   "In " . trim(Stringify($$top[0])) . ' ' . Stringify($$top[1]));
      push(@objects, ['...']) if @objects && defined $nstack;
      push(@lines,   join('', (map { ' <= ' . trim(Stringify($$_[0])) } @objects))) if @objects;
  } }

  # finally, join the result into a block of lines, indenting all but the 1st line.
  return join("\n\t", @lines); }

sub MergeStatus {
  my ($external_state) = @_;
  my $state = $STATE;
  return unless $state && $external_state;
  my $status          = $$state{status};
  my $external_status = $$external_state{status};
  # Should this be a state method? I suspect XS-ive conflicts later on...
  foreach my $type (keys %$external_status) {
    if ($type eq 'undefined' or $type eq 'missing') {
      my $table = $$external_status{$type};
      foreach my $subtype (keys %$table) {
        $$status{$type}{$subtype} += $$table{$subtype};
      }
    } else {
      $$status{$type} += $$external_status{$type};
    }
  }
  return; }

# returns the locator of an object, or undef
sub Locator {
  my ($object) = @_;
  return ($object && $object->can('getLocator') ? $object->getLocator : undef); }

# A more organized abstraction along there likes of $where->whereAreYou
# might be useful?
sub getLocation {
  my ($where) = @_;
  my $wheretype = ref $where;
  if ($wheretype && ($wheretype =~ /^XML::LibXML/)) {
    my $box = $LaTeXML::DOCUMENT && $LaTeXML::DOCUMENT->getNodeBox($where);
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
    return Locator($gullet); }
  # # If in postprocessing
  # if($LaTeXML::Post::PROCESSOR && $LaTeXML::Post::DOCUMENT){
  #   return 'in '. $LaTeXML::Post::PROCESSOR->getName
  #     . ' on '. $LaTeXML::Post::DOCUMENT->siteRelativeDestination; }
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
    $arg =~ s/'/\\'/g;                                        # Slashify '
    $arg =~ s/([[:cntrl:]])/ "\\".chr(ord($1)+ord('A'))/ge;
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
        next if @objects && ($self eq $objects[-1][0]);    # but don't duplicate
        if ($self->can('getLocator')) {                    # Digestion object?
          push(@objects, [$self, Locator($self)]); }
        elsif ($self->isa('LaTeXML::Post::Processor') || $self->isa('LaTeXML::Post::Document')) {
          push(@objects, [$self, '->' . $method]); }
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

=over 4

=item C<< SetVerbosity($verbosity) >>

Controls the verbosity of output to the terminal;
default is 0, higher gives more information, lower gives less.

=item C<< DisableSTDERR() >>

Disables use of the STDERR stream for logging. Should be set as early as possible
by applications that wish to have no output to STDERR.

=back

=head2 STDERR

A limited amount of information can be displayed on STDERR:
short forms of messages for Errors, Warnings, progress, etc
along with a status spinner indicating progress through various stages of processing.
More complete information will be recorded to the log file (if any).

=over 4

=item C<< OpenSTDERR() >>

Enables and initializes STDERR to accept messages.
If this is not called, there will be no output to STDERR.

=item C<< CloseLog() >>

Disables output to STDERR.

=back

=head2 Log File

Various kinds of messages for Errors, Warnings, progress, etc. are printed to both
STDERR and a log file, if one has been opened.  The log file typically recieves complete information
(as adjusted by the verbosity), whereas the output to STDERR tends to be breif.

=over 4

=item C<< OpenLog($path, $append) >>

Opens a log file on the given path. If C<$append> is true, this file will be appended to,
otherwise, it will be created initially empty.

=item C<< CloseLog() >>

Close the log file.

=back

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

=back

=head2 Progress Reporting

=over 4

=item C<< Note($message); >>

General status message, printed whenever verbosity at or above 0,
to both STDERR and the Log file (when enabled).

=item C<< NoteLog($message); >>

Prints a status message to the Log file (when enabled).

=item C<< NoteTerminal($message); >>

Prints a status message to the terminal (STDERR) (when enabled).

=item C<< ProgressSpinup($stage); >>

Begin a processing stage, which will be ended with C<ProgressSpindown($stage)>;
This prints a message to the log such as "(stage... runtime)", where runtime is the time required.
In conjunction with C<ProgressStep()>, creates a progress spinner on STDERR.

=item C<< ProgressSpinup($stage); >>

End a processing stage bugin with C<ProgressSpindown($stage);>.

=item C<< ProgressStep(); >>

Steps a progress spinner on STDERR.

=back

=head2 Debugging

Debugging statements may be embedded throughout the program. These are associated with a
feature keyword.  A given feature is enabled using the command-line option
C<--debug=feature>.

=over 4

=item C<< Debug($message) if $LaTeXML::DEBUG{$feature} >>

Prints C<$message> if debugging has been enabled for the given feature.

=item C<< DebuggableFeature($feature,$description) >>

Declare that C<$feature> is a known debuggable feature, and give a description of it.

=item C<< CheckDebuggable() >>

A untility to check and report if all requested debugging features actually have debugging messages
declared.

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
