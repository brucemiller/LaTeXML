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
use base qw(Exporter);
our @EXPORT = (qw(&Fatal &Error &Warn &Info));

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Note: The exported symbols should ultimately be exported as part
# of LaTeXML::Common, or something like that, to be used BOTH in
# Digestion & Post-Processing.
# ======================================================================
# We want LaTeXML::Global to import this package,
# but we also want to use some of it's low-level functions.
sub ToString  { LaTeXML::Global::ToString(@_); }
sub Stringify { LaTeXML::Global::Stringify(@_); }
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Error reporting
# Public API

sub Fatal { 
  my($category,$object,$where,$message,@details)=@_;
  my $state = $LaTeXML::Global::STATE;
  my $verbosity = $state && $state->lookupValue('VERBOSITY') || 0;
  if(!$LaTeXML::Error::InHandler && defined($^S)){
    $state && $state->noteStatus('fatal');
    $message
      = generateMessage("Fatal:".$category.":".ToString($object),$where,$message,1,
			# ?!?!?!?!?!
			# or just verbosity code >>>1 ???
			@details,
			($state && $state->lookupValue('VERBOSITY') > 0
			 ? ("Stack Trace:",LaTeXML::Error::stacktrace()):()));
    # We're about to DIE, which will bypass the usual status message, so add it here.
    $message .=$state->getStatusMessage if $state;
  }
  else {			# If we ARE in a recursive call, the actual message is $details[0]
    $message = $details[0] if $details[0]; }
  local $LaTeXML::Error::InHandler=1;
  die $message; 
###  print STDERR "\n".$message;
###  exit(1);
  return; }

# Note that "100" is hardwired into TeX, The Program!!!
our $MAXERRORS=100;

# Should be fatal if strict is set, else warn.
sub Error {
  my($category,$object,$where,$message,@details)=@_;
  my $state = $LaTeXML::Global::STATE;
  my $verbosity = $state && $state->lookupValue('VERBOSITY') || 0;
  if($LaTeXML::Global::STATE->lookupValue('STRICT')){
    Fatal($category,$object,$where,$message,@details); }
  else {
    $LaTeXML::Global::STATE->noteStatus('error');
    print STDERR generateMessage("Error:".$category.":".ToString($object),
				 $where,$message,1,@details)
      unless $verbosity < -2; }
  if(!$state || ($state->getStatus('error')||0) > $MAXERRORS){
    Fatal('too_many_errors',$MAXERRORS,$where,"Too many errors (> $MAXERRORS)!"); }
  return; }

# Warning message; results may be OK, but somewhat unlikely
sub Warn {
  my($category,$object,$where,$message,@details)=@_;
  my $state = $LaTeXML::Global::STATE;
  my $verbosity = $state && $state->lookupValue('VERBOSITY') || 0;
  $state && $state->noteStatus('warning');
  print STDERR generateMessage("Warning:".$category.":".ToString($object),
			       $where,$message,0, @details)
    unless $verbosity < -1; 
  return; }

# Informational message; results likely unaffected
# but the message may give clues about subsequent warnings or errors
sub Info {
  my($category,$object,$where,$message,@details)=@_;
  my $state = $LaTeXML::Global::STATE;
  my $verbosity = $state && $state->lookupValue('VERBOSITY') || 0;
  $state && $state->noteStatus('info');
  print STDERR generateMessage("Info:".$category.":".LaTeXML::Global::ToString($object),
			       $where,$message,0, @details)
    unless $verbosity < 0;
  return; }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Handlers for perl's die & warn
# We'll try to decode some common errors to make them more usable
# for build systems.

sub perl_die_handler {
  my(@line)=@_;
  if($line[0] =~ /^Can't call method \"([^\"]*)\" (on an undefined value|without a package or object reference) at (.*)$/){
    my($method,$kind,$where)=($1,$2,$3);
    Fatal('misdefined',$method,$where, @line); }
  else {
    Fatal('perl','die',undef,"Perl died",@_); }}

sub perl_warn_handler {
  Warn('perl','warn',undef,"Perl warning",@_); }

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Internals
# Synthesize an error message describing what happened, and where.
# NOTE: Possibly $long should be descrete levels
# including a level requesting full stack trace?

sub generateMessage {
  my($errorcode,$where,$message,$long,@extra)=@_;
  my $docloc;

  my $state = $LaTeXML::Global::STATE; # Maybe bound?
  # Generate location information; basic and for stack trace.
  # If we've been given an object $where, where the error occurred, use it.
  my $wheretype = ref $where;
  if($wheretype && ($wheretype =~/^XML::LibXML/)){
    my $box = $LaTeXML::DOCUMENT->getNodeBox($where);
    $docloc = Locator($box) if $box; }
  elsif($wheretype && $where->can('getLocator')){
    $docloc=$where->getLocator; }
  elsif(defined $where){
    $docloc=$where; }
  # Otherwise, try to guess where the error came from!
  elsif($LaTeXML::DOCUMENT){ # During construction?
    my $node = $LaTeXML::DOCUMENT->getNode;
    my $box  = $LaTeXML::DOCUMENT->getNodeBox($node);
    $docloc = Locator($box) if $box; }
  if(!$docloc && $LaTeXML::BOX){ # In constructor?
    $docloc = Locator($LaTeXML::BOX); }
  if(!$docloc && $state && $state->getStomach){
    my $gullet = $state->getStomach->getGullet;
    # NOTE: Problems here.
    # (1) With obsoleting Tokens as a Mouth, we can get pointless "Anonymous String" locators!
    # (2) If gullet is the source, we probably want to include next token, etc or 
    $docloc = $gullet->getLocator(); }

  # $message and each of @extra should be single lines
  ($message,@extra) = grep($_ ne '',map(split("\n",$_),$message,@extra));
  my @lines=($errorcode.' '.$message,
	     ($docloc ? ($docloc):()),
	     @extra);

  # Now add a certain amount of stack trace and/or context info.
  $long = 0 if $state && $state->lookupValue('VERBOSITY') < -1;
  $long ++  if $state && $state->lookupValue('VERBOSITY') > +1;

  # FIRST line of stack trace information ought to look at the $where
  if(!$long){}
  elsif($wheretype =~ /^XML::LibXML/){
    push(@lines,"Node is ".Stringify($where)); }
    ## Hmm... if we're being verbose or level is high, we might do this:
    ### "Currently in ".$doc->getInsertionContext); }
  elsif($wheretype =~ 'LaTeXML::Gullet'){
    push(@lines,$where->showUnexpected); } # Or better?

  my $nstack =  ($long > 1 ? undef : ($long ? 4 : 1));
  if(my @objects = objectStack($nstack)){
    my $top = shift(@objects);
    push(@lines,"In ".trim(ToString($top)).' '.ToString(Locator($top)));
    push(@objects,'...') if @objects && defined $nstack;
    push(@lines,join('',map(' <= '.trim(ToString($_)),@objects))) if @objects; }

  "\n".join("\n\t",@lines)."\n"; }

sub Locator {
  my($object)=@_;
  ($object && $object->can('getLocator') ? $object->getLocator :  "???"); }

sub callerInfo {
  my($frame)=@_;
  my %info = caller_info( ($frame || 0) + 2);
  "$info{call} @ $info{file} line $info{line}"; }

#======================================================================
# This portion adapted from Carp; simplified (but hopefully still correct),
# allow stringify overload, handle methods, make more concise!
#======================================================================
our $MAXARGS = 8;
our $MAXLEN=40;			# Or more?

sub trim {
  my($string)=@_;
  substr($string,$MAXLEN-3) = "..." if(length($string) > $MAXLEN);
  $string =~ s/\n/\x{240D}/gs;	# symbol for CR 
  $string; }

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
  elsif(ref $arg)     { $arg = Stringify($arg); } # Allow overloaded stringify!
  elsif($arg =~ /^-?[\d.]+\z/){ } # Leave numbers alone.
  else {			# Otherwise, string, so quote
    $arg =~ s/'/\\'/g;		# Slashify '
    $arg =~ s/([[:cntrl::]])/ "\\".chr(ord($1)+ord('A'))/ge;
    $arg = "'$arg'"} ;
  trim($arg); }

# Semi-traditional (but reformatted) stack trace
sub stacktrace {
  my $frame = 0;
  my $trace = "";
  while(my %info = caller_info($frame++)){
    next if $info{sub} =~ /^LaTeXML::Error/;
    $info{call} = '' if $info{sub} =~ /^LaTeXML::Error::Error/;
    $trace .= "\t$info{call} @ $info{file} line $info{line}\n"; }
  $trace; }


# Extract blessed `interesting' objects on stack.
# Get a maximum of $maxdepth objects (if $maxdepth is defined).
sub objectStack {
  my($maxdepth)=@_;
  my $frame = 0;
  my @objects=();
  while(1){
    my(%info,@args);
    { package DB;
      @info{ qw(package file line sub has_args wantarray evaltext is_require) } = caller($frame++);
      @args = @DB::args; }
    last unless defined $info{package};
    next if ($info{sub} eq '(eval)') || !$info{has_args} || !@args;
    my $self = $args[0];
    # If $arg[0] is blessed, and `can' do $method, then we'll guess it's a method call?
    # We'll collect such objects provided they can ->getLocator
    if((ref $self) && ((ref $self) !~ /^(SCALAR|ARRAY|HASH|CODE|REF|GLOB|LVALUE)$/)){
      my $method = $info{sub};
      $method =~ s/^.*:://;
      if($self->can($method)){
	next if @objects && ($self eq $objects[$#objects]);
	next unless $self->can('getLocator');
	push(@objects,$self);
	last if $maxdepth && (scalar(@objects) >= $maxdepth); }}}
  @objects; }

#**********************************************************************
1;


__END__

=pod

=head1 NAME

C<LaTeXML::Error> - Internal Error reporting code.

=head1 DESCRIPTION

C<LaTeXML::Error> does some simple stack analysis to generate more informative, readable,
error messages for LaTeXML.  Its routines are used by the error reporting methods
from L<LaTeXML::Global>, namely C<Warn>, C<Error> and C<Fatal>.

No user serviceable parts inside.  No symbols are exported.

=head2 Functions

=over 4

=item C<< $string = LaTeXML::Error::generateMessage($typ,$msg,$lng,@more); >>

Constructs an error or warning message based on the current stack and
the current location in the document.
C<$typ> is a short string characterizing the type of message, such as "Error".  
C<$msg> is the error message itself. If C<$lng> is true, will generate a
more verbose message; this also uses the VERBOSITY set in the C<$STATE>.
Longer messages will show a trace of the objects invoked on the stack,
C<@more> are additional strings to include in the message.

=item C<< $string = LaTeXML::Error::stacktrace; >>

Return a formatted string showing a trace of the stackframes up until this
function was invoked.

=item C<< @objects = LaTeXML::Error::objectStack; >>

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

