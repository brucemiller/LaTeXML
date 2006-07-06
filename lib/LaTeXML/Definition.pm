# /=====================================================================\ #
# |  LaTeXML::Definition                                                | #
# | Representation of definitions of Control Sequences                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Definition;
use strict;
use LaTeXML::Global;
use Exporter;
use LaTeXML::Object;
use LaTeXML::Parameters;
our @ISA = qw(LaTeXML::Object);

#**********************************************************************

sub getCS        { $_[0]->{cs}; }
sub isExpandable { 0; }
sub isRegister   { ''; }
sub isPrefix     { 0; }

sub readArguments {
  my($self,$gullet)=@_;
  my $params = $$self{parameters};
  ($params ? $params->readArguments($gullet) : ()); }

sub showInvocation {
  my($self,@args)=@_;
  my $params = $$self{parameters};
  ($params ? $$self{cs}.$params->untexArguments(@args) : $$self{cs}); }

#======================================================================
# Overriding methods
sub stringify {
  my($self)=@_;
  my $type = ref $self;
  $type =~ s/^LaTeXML:://;
  $type.'['.$$self{cs}.($$self{parameters} ||'').']'; }

#**********************************************************************
# Expandable control sequences (& Macros);  Expanded in the Gullet.
#**********************************************************************
package LaTeXML::Expandable;
use LaTeXML::Global;
our @ISA = qw(LaTeXML::Definition);

# Known properties: isConditional
sub new {
  my($class,$cs,$parameters,$expansion,%properties)=@_;
  $cs = $cs->untex if ref $cs;
  Error("Defining Expandable $cs but expansion is neither Tokens nor CODE: $expansion.")
    unless (ref $expansion) =~ /^(LaTeXML::Tokens|CODE)$/;
  if(ref $expansion eq 'LaTeXML::Tokens'){
    my $level=0;
    foreach my $t ($expansion->unlist){
      $level++ if $t eq T_BEGIN;
      $level-- if $t eq T_END; }
    Error("Defining Macro $cs: replacement has unbalanced {}: $expansion") if $level;  }
  my $self= bless {cs=>$cs, parameters=>$parameters, expansion=>$expansion,
		   %properties}, $class;
  Message("Defining $self") if Debugging('macros');
  $self; }

sub isExpandable  { 1; }
sub isConditional { $_[0]->{isConditional}; }

# Expand the expandable control sequence. This should be carried out by the Gullet.
sub invoke {
  my($self,$gullet)=@_;
  local $LaTeXML::DEFINITION = $self;
  Message("Expanding $self") if Debugging('macros');
  my @args = $self->readArguments($gullet);
  my $expansion = $$self{expansion};
  my @result=(ref $expansion eq 'CODE' 
	      ? &$expansion($gullet,@args)
	      : substituteTokens($expansion,@args));
  Message("Expansion ".$self->showInvocation(@args)." => ".Tokens(@result)->untex)
    if Debugging('macros');
  CheckTokens(@result);
  @result; }

sub substituteTokens {
  my($tokens,@args)=@_;
  my @in = $tokens->unlist;
  my @result=();
  while(@in){
    my $token;
    if(($token=shift(@in))->getCatcode != CC_PARAM){ # Non '#'; copy it
      push(@result,$token); }
    elsif(($token=shift(@in))->getCatcode != CC_PARAM){ # Not multiple '#'; read arg.
      push(@result,@{$args[ord($token->getString)-ord('0')-1]||[]}); }
    else {		# Duplicated '#', copy 2nd '#'
      push(@result,$token); }}
  @result; }

sub equals {
  my($self,$other)=@_;
  ((ref $self) eq (ref $other))
    && ($$self{parameters} eq $$other{parameters})
      && ($$self{expansion} eq $$other{expansion}); }

#**********************************************************************
# Primitive control sequences; Executed in the Stomach.
#**********************************************************************

package LaTeXML::Primitive;
use LaTeXML::Global;
our @ISA = qw(LaTeXML::Definition);

# Known properties: isPrefix
sub new {
  my($class,$cs,$parameters,$replacement,%properties)=@_;
  # Could conceivably have $replacement being a List or Box?
  Error("Defining Primitive $cs but replacement is not CODE: $replacement.")
    unless ref $replacement eq 'CODE';
  $cs = $cs->untex if ref $cs;
  my $self= bless {cs=>$cs, parameters=>$parameters, replacement=>$replacement, 
		   %properties}, $class;
  Message("Defining $self") if Debugging('macros');
  $self; }

sub isPrefix      { $_[0]->{isPrefix}; }

sub executeBeforeDigest {
  my($self,$stomach)=@_;
  my $pre = $$self{beforeDigest};
  ($pre ? map(&$_($stomach), @$pre) : ()); }

sub executeAfterDigest {
  my($self,$stomach,@whatever)=@_;
  my $post = $$self{afterDigest};
  ($post ? map(&$_($stomach,@whatever), @$post) : ()); }

# Digest the primitive; this should occur in the stomach.
sub invoke {
  my($self,$stomach)=@_;
  local $LaTeXML::DEFINITION = $self;
  Message("Digesting $self") if Debugging('macros');
  my @result;
  push(@result, $self->executeBeforeDigest($stomach));
  my @args = $self->readArguments($stomach->getGullet);
  push(@result, &{$$self{replacement}}($stomach, @args));
  push(@result, $self->executeAfterDigest($stomach));
  Message("Digested ".$self->showInvocation(@args)." => ".join('',@result))
    if Debugging('macros');
  CheckBoxes(@result);
  @result; }

sub equals {
  my($self,$other)=@_;
  ((ref $self) eq (ref $other))
    && ($$self{parameters} eq $$other{parameters})
      && ($$self{replacement} eq $$other{replacement}); }

#**********************************************************************
# A `Generalized' register;
# includes the normal ones, as well as registers and 
# eventually things like catcode, 
package LaTeXML::Register;
use LaTeXML::Global;
our @ISA = qw(LaTeXML::Primitive);

# Known Properties: beforeDigest, afterDigest, readonly
sub new {
  my($class,$cs,$parameters,$type,$getter,$setter ,%properties)=@_;
  $cs = $cs->untex if ref $cs;
  my $self= bless {cs=>$cs, parameters=>$parameters,
		   registerType=>$type, getter => $getter, setter => $setter,
		   %properties}, $class;
  Message("Defining $self") if Debugging('macros');
  $self; }

sub isPrefix    { 0; }
sub isRegister { $_[0]->{registerType}; }
sub isReadonly  { $_[0]->{readonly}; }

sub getValue {
  my($self,$stomach,@args)=@_;
  &{$$self{getter}}($stomach,@args); }

sub setValue {
  my($self,$stomach,$value,@args)=@_;
  &{$$self{setter}}($stomach,$value,@args);
  return; }

# No before/after daemons ???
sub invoke {
  my($self,$stomach)=@_;
  local $LaTeXML::DEFINITION = $self;
  Message("Assigning $self") if Debugging('macros');
  my $gullet = $stomach->getGullet;
  my @args = $self->readArguments($gullet);
  $gullet->readKeyword('=');	# Ignore 
  my $value = $gullet->readValue($self->isRegister);
  $self->setValue($stomach,$value,@args);
  Message("Assigned ".$self->showInvocation(@args)." => ".$value)
      if Debugging('macros');
  return; }

#**********************************************************************
# Constructor control sequences.  These are executed in the Intestine,
# BUT, they are converted to a Whatsit in the Stomach!
# In particular, beforeDigest, reading args and afterDigest are executed
# in the Stomach.
#**********************************************************************
package LaTeXML::Constructor;
use LaTeXML::Global;
our @ISA = qw(LaTeXML::Primitive);

# Known properties: beforeDigest, afterDigest, 
#    mathConstructor, mathclass, floats, untex, captureBody
sub new {
  my($class,$cs,$parameters,$replacement,%properties)=@_;
  $cs = $cs->untex if ref $cs;
  Error("Defining Constructor $cs but replacement is not a string or CODE: $replacement")
    unless (defined $replacement) && (!(ref $replacement) || (ref $replacement eq 'CODE'));
  my $m = $properties{mathConstructor};
  Error("Defining Constructor $cs but math constructor is not a string or CODE: $m")
    unless !(defined $m) || !(ref $m) || (ref $m eq 'CODE');
  my $self= bless {cs=>$cs, parameters=>$parameters, replacement=>$replacement,
		   %properties}, $class;
  Message("Defining $self") if Debugging('macros');
  $self; }

sub floats { $_[0]->{floats}; }
sub getMathClass { $_[0]->{mathclass} || 'symbol'; }

sub getConstructor {
  my($self,$ismath)=@_;
  (($ismath && defined $$self{mathConstructor}) ? $$self{mathConstructor} : $$self{replacement}); }

sub untex {
  my($self,$whatsit,@params)=@_;
  my $untex = $$self{untex};
  if((defined $untex) && (ref $untex eq 'CODE')){
    return &$untex($whatsit,@params); }
  else {
    return "" if grep(/nofloats/,@params) && $self->floats;
    my $string = '';
    if(defined $untex){
      $string = $untex;
      $string =~ s/#(\d)/ $whatsit->getArg($1)->untex(@params); /eg; }
    else {
      $string= $$self{cs};
      my @args = $whatsit->getArgs;
      $string .= ' ' unless scalar(@args) || ($string=~/\W$/) || !($string =~ /^\\/);
      my $params = $$self{parameters};
      $string .= $params->untexArguments(@args) if $params;
    }
    if(defined (my $body = $whatsit->getBody)){
      $string .= $body->untex(@params);
      $string .= $whatsit->getTrailer->untex(@params); }
    $string; }}

# Digest the constructor; This should occur in the Stomach (NOT the Intestine)
# to create a Whatsit, which will be further processed in the Intestine
sub invoke {
  my($self,$stomach)=@_;
  local $LaTeXML::DEFINITION = $self;
  Message("Digesting Constructor $self") if Debugging('macros');
  # Call any `Before' code.
  my @pre = $self->executeBeforeDigest($stomach);
  # Parse AND digest the arguments to the Constructor
  my $params = $$self{parameters};
  my @args = $self->readArguments($stomach->getGullet);
  my $whatsit = Whatsit($self,$stomach,[($params ? $params->digestArguments($stomach,@args) : ())]);
  my @post = $self->executeAfterDigest($stomach,$whatsit);
  Message("Digested ".$self->showInvocation(@args)." => ".$whatsit)
    if Debugging('macros');
  if($$self{captureBody}){
    my @body = $stomach->readAndDigestBody;
    $whatsit->setBody(@post,@body); @post=();
    Message("Added body to $$self{cs}") if Debugging('macros');
  }
  CheckBoxes(@pre); CheckBoxes(@post);
  (@pre,$whatsit,@post); }

#**********************************************************************
1;

__END__

=pod 

=head1 LaTeXML::Definition, LaTeXML::Expandable, LaTeXML::Primitive, LaTeXML::Register, LaTeXML::Constructor.

=head2 DESCRIPTION

These represent the various executables corresponding to control sequences.
LaTeXML::Expandable represents macros and other expandable control sequences like \if, etc
that are carried out in the Gullet during expansion.
LaTeXML::Primitive represents primitive control sequences that are primarily carried out
for side effect during digestion in the Stomach.
LaTeXML::Register is set up as a speciallized primitive with a getter and setter
to access and store values in the Stomach.
LaTeXML::Constructor represents control sequences that contribute arbitrary XML fragments
to the document tree.

More documentation needed, but see LaTeXML::Package for the main user access to these.

=cut
