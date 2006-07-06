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
use LaTeXML::Global;

#**********************************************************************
# Error reporting
#**********************************************************************

# Synthesize an error message describing what happened, and where.
sub generateMessage {
  my($type,$message,$long,@extra)=@_;
  my @lines=("\n".$type.": ".$message);
  $long = 0 if $LaTeXML::Global::VERBOSITY < -1;
  $long = 1 if $LaTeXML::Global::VERBOSITY > +1;
  if(my @objects = objectStack( ($long ? undef : 1))){
    my $top = shift(@objects);
    push(@lines,"In ".trim(Stringify($top)).' '.Stringify($top->getLocator));
    push(@lines,join('',map(' <= '.trim(Stringify($_)),@objects))) if @objects; }
  push(@lines,$GULLET->getLocator($long)) if $GULLET;
  join("\n",grep($_,@lines, @extra)); }

#======================================================================
# This portion adapted from Carp; simplified (but hopefully still correct),
# allow stringify overload, handle methods, make more concise!
#======================================================================
our $MAXARGS = 8;
our $MAXLEN=40;			# Or more?

sub trim {
  my($string)=@_;
  substr($string,$MAXLEN-3) = "..." if(length($string) > $MAXLEN);
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
    $trace .= "  $info{call} @ $info{file} line $info{line}\n"; }
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
    if((ref $self) && ((ref $self) !~ /^(SCALAR|ARRAY|HASH|CODE|REF|GLOB|LVALUE)$/)){
      my $method = $info{sub};
      $method =~ s/^.*:://;
      if($self->can($method) && ($self->isaBox || $self->isaNode || $self->isaDefinition)){
	next if @objects && ($self eq $objects[$#objects]);
	push(@objects,$self);
	last if $maxdepth && (scalar(@objects) >= $maxdepth); }}}
  @objects; }

sub line_in_file {
  my($file)=@_;
  my $frame=0;
  while(my($pkg,$cfile,$line) = caller($frame++)){
    return $line if $cfile eq $file; }
  undef; }

#**********************************************************************
1;


__END__

=pod 

=head1 LaTeXML::Error

=head2 DESCRIPTION

C<LaTeXML::Error> does some simple stack analysis to generate more informative, readable,
error messages for LaTeXML.  Its routines are used by the error reporting methods
from L<LaTeXML::Global>, namely C<Warn>, C<Error> and C<Fatal>.

No user serviceable parts inside.

=cut

