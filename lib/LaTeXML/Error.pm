# /=====================================================================\ #
# |  LaTeXML::Error                                                     | #
# | Error handler                                                       | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Error;
use strict;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = ( qw( &Error &TypeError &CheckOptions &Message &Warn &Debugging &SetDebugging));

#**********************************************************************
# Error reporting
#**********************************************************************
our %DEBUGKEYS=();
our $VERBOSITY=0;		# -1: quiet, 0: only warnings, 1: some debugging info, 2: verbosely.

# Error should be used for error reporting within LaTeXML, much like die or Carp.
# Can also be used as a signal handler to report All errors to provide debugging context:
#      $SIG{__DIE__} = \&LaTeXML::Error::Error;
# Can I make the Input/Output/Stacktrace info optional?  How to specify?
# NOTE: a stack trace should probably start from the eval'd error rather than when it eventually
# gets reported?
# So, maybe I want to fill out the error info from there?  (w/o test of $^S ???)
sub Error {
  my $msg = join('',@_);
#  if(!$LaTeXML::Error::IN_ERROR_HANDLER && !$^S){
  if(!$LaTeXML::Error::IN_ERROR_HANDLER
    && !($msg =~/(Input Context|Output Context|Stack Trace)/)){
    my $context = getContextMessage(0);
    chomp($msg);
    $msg = join('',"\nERROR: ", $msg, "\n", ($context ? $context."\n" : ''));
#    $msg = Carp::longmess($msg);
    $msg .= "Stack Trace:\n".LaTeXML::Error::stacktrace();
  }
  local $LaTeXML::Error::IN_ERROR_HANDLER=1;
  die $msg; }

sub Message { print STDERR @_,"\n" unless $VERBOSITY < 0; }

sub CheckOptions {
  my($operation,$allowed,%options)=@_;
  my @badops = grep(!$$allowed{$_}, keys %options);
  Warn($operation." does not accept options:".join(', ',@badops)) if @badops;
}

# Should it print context ??
sub Warn    { 
  return if $VERBOSITY < 0;
  my $context = getContextMessage(1);
  print STDERR "\nWARNING: ",@_,"\n" 
    . ($context ? $context."\n" : '');
}

sub getContextMessage {
  my($short)=@_;
  ($LaTeXML::STOMACH   ? "During digestion: ".$LaTeXML::STOMACH->getContext($short) : '')
    .($LaTeXML::INTESTINE ? "During DOM construction: ".$LaTeXML::INTESTINE->getContext($short) : ''); }

# Possible debugging levels:
#   quiet : No debugging info, nor warning messages.
#   all   : A ridiculous amount of useless info.
#   others, scatterred throughout the code!
# Combine with "|"
sub SetDebugging {
  my($spec)=@_;
  if(!$spec){ $VERBOSITY=0; }
  elsif($spec =~ /quiet/i){ $VERBOSITY=-1; }
  else {
    $VERBOSITY=1;
    map( $DEBUGKEYS{$_}=1, split('\|',$spec));
    $VERBOSITY=2 if $DEBUGKEYS{verbose}; }
}

# If $level is empty, then return 1 if we're debugging at all.
sub Debugging   {
  my($level)=@_;
  ($level ? $DEBUGKEYS{$level}||$DEBUGKEYS{all} : $VERBOSITY > 0); }

sub TypeError {
  my($thing,$type)=@_;
  $type = '?' unless defined $type;
  $thing = '<nothing>' unless defined $thing;
  Error("Internal error:\nExpected \"$type\", got $thing"); }

#======================================================================
# This portion adapted from Carp; simplified (but hopefully still correct),
# allow stringify overload, handle methods, make more concise!
#======================================================================
our $MAXARGS = 8;
our $MAXLEN=64;

sub caller_info {
  my($i)=@_;

  my(%info,@args);
  { package DB;
    @info{ qw(package file line sub has_args wantarray evaltext is_require) }
      = caller($i);
    @args = @DB::args; }
  return () unless defined $info{package};
  # Work out the effective sub name, or eval, or method ...
  my $call='';
  if(defined $info{evaltext}){
    my $eval = $info{evaltext};
    if($info{is_require}){
      $call = "require $eval"; }
    else {
      $eval =~ s/([\\\'])/\\$1/g;
      $call = "eval '".trim($eval)."'"; }}
  elsif($info{sub} eq '(eval)'){
    $call = "eval {...}"; }
  else {
    $call = $info{sub};
    my $method = $call;
    $method =~ s/^.*:://;
    # If $arg[0] is blessed, and `can' do $method, then we'll guess it's a method call?
    if($info{has_args} && @args 
       && ref $args[0] && ((ref $args[0]) !~ /^(SCALAR|ARRAY|HASH|CODE|REF|GLOB|LVALUE)$/)
       && $args[0]->can($method)){
      $call = format_arg(shift(@args))."->".$method; }}
  # Append arguments, if any.
  if($info{has_args}){
     @args = map(format_arg($_), @args);
    if(@args > $MAXARGS){
      $#args = $MAXARGS; push(@args,'...'); }
    $call .= '('.join(',',@args).')'; }
  $info{call} = $call;
  %info; }

sub format_arg {
  my($arg)=@_;
  if(not defined $arg){ $arg = 'undef'; }
  elsif(ref $arg)     { $arg = "$arg"; } # Allow overloaded stringify!
  elsif($arg =~ /^-?[\d.]+\z/){ } # Leave numbers alone.
  else {			# Otherwise, string, so quote
    $arg =~ s/'/\\'/g;		# Slashify '
    $arg =~ s/[[:cntrl::]]/ "\\".chr(ord($1)+ord('A'))/ge;
    $arg = "'$arg'"} ;
  trim($arg); }

sub trim {
  my($string)=@_;
  substr($string,$MAXLEN-3) = "..." if(length($string) > $MAXLEN);
  $string; }

sub stacktrace {
  my $i = 0;
  my $trace = "";
  while(my %info = caller_info($i++)){
    next if $info{sub} =~ /^LaTeXML::Error/;
    $info{call} = '' if $info{sub} =~ /^LaTeXML::Error::Error/;
    $trace .= "  $info{call} @ $info{file} line $info{line}\n"; }
  $trace; }

#**********************************************************************
1;

__END__

=pod 

=head1 LaTeXML::Error

=head2 SYNOPSIS

use LaTeXML::Error;

=head2 DESCRIPTION

This module provides support for reporting errors and warnings,
along with a few common typechecks.  It uses code adapted from 
the L<Carp> module and the alternate stringification of
L<LaTeXML::Object> to provide a (hopefully) more readable
version of the stack trace to help figure out what the root cause
of an error is.  It also uses the C<getContext> methods of
the various processing classes to determine the context of the error.

If you want to get this same style of error reporting for I<any>
error that occurs (from C<die>), you can use
   BEGIN { $SIG{__DIE__} = \&LaTeXML::Error::Error; }

=head2 Exported procedures

=over 4

=item C<< Error(@stuff); >>

Signals an error, printing whatever is in @stuff along with an
indication of where we are in the input stream and a stack trace.

=item C<< Warn(@stuff); >>

Prints a warning message along with a short indicator of
the input context, unless verbosity is quiet.

=item C<< Message(@stuff); >>

Prints whatever is in @stuff, unless the verbosity level is quiet.

=item C<< TypeError($thing,$type); >>

Signals an error with a message to the effect that the given $thing
was expected to be of type $type.

=item C<< CheckOptions($operation,$allowed,%options); >>

This method checks that all hashkeys in %options are specified
(w/some defined value) in the hashref $allowed.  If not, an
appropriate warning message is generated.

=item C<< SetDebugging($specs); >>

Sets the level of debugging information to display. $specs is a concatination
of various specifiers combined with '|'. The specifiers can contain 'quiet',
'all' (a ridiculous amount of info) and various random others which have gotten
scattered throughout the code including 'macros', 'DOM', 'DOCTYPE', 'mode', 'catcodes'.

=item C<< Debugging($spec); >>

Returns true if $spec is one of the identifiers specified by SetDebugging.
A typical debugging statement might be:
   Message("We made it here!") if Debugging('here');

=back

=cut
