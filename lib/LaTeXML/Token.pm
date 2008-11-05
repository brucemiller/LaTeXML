# /=====================================================================\ #
# |  LaTeXML::Token, LaTeXML::Tokens                                    | #
# | Representation of Token(s)                                          | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

#**********************************************************************
#   A Token represented as a pair: [string,catcode]
# string is a character or control sequence.
# Yes, a bit inefficient, but code is clearer...
#**********************************************************************
package LaTeXML::Token;
use strict;
use LaTeXML::Global;
use base qw(LaTeXML::Object);

#======================================================================
# See LaTeXML::Global for constructors.

#======================================================================
# Categories of Category codes.
# For Tokens with these catcodes, only the catcode is relevant for comparison.
# (if they even make it to a stage where they get compared)
our @primitive_catcode = (1,1,1,1,
			  1,1,1,1,
			  1,0,1,0,
			  0,0,0,0,
			  0,1);

my @standardchar=("\\",'{','}','$',
                    '&',"\n",'#','^', 
		    '_',undef,undef,undef,
 		    undef,undef,'%',undef);

our @CC_NAME=qw(Escape Begin End Math Align EOL Parameter Superscript Subscript
		Ignore Space Letter Other Active Comment Invalid
		ControlSequence NotExpanded);
our @CC_SHORT_NAME = qw(T_ESCAPE T_BEGIN T_END T_MATH
			T_ALIGN T_EOL T_PARAM T_SUPER
			T_SUB T_IGNORE T_SPACE T_LETTER
			T_OTHER T_ACTIVE T_COMMENT T_INVALID
			T_CS T_NOTEXPANDED
		       );

#======================================================================
# Accessors.

sub isaToken { 1; }

# Get the CS Name of the token. This is the name that definitions will be
# stored under; It's the same for various `different' BEGIN tokens, eg.
sub getCSName {
  my($token)=@_;
  my $cc = $$token[1];
  ($primitive_catcode[$cc] ? $CC_NAME[$cc] : $$token[0]); }

# Return the string or character part of the token
sub getString  { $_[0]->[0]; }
# Return the character code of  character part of the token, or 256 if it is a control sequence
sub getCharcode{ ($_[0]->[1] == CC_CS ? 256 : ord($_[0]->[0])); }
# Return the catcode of the token.
sub getCatcode { $_[0]->[1]; }

# Defined so a Token or Tokens can be used interchangeably.
sub unlist { ($_[0]); }
sub getLocator { ''; }
sub getSource  { ''; }

our @NEUTRALIZABLE=(0,0,0,1,
		    1,0,1,1,
		    1,0,0,0,
		    0,1,1,0,
		    0,0);
sub neutralize {
  ($NEUTRALIZABLE[$_[0]->[1]] ? T_OTHER($_[0]->[0]) : $_[0]); }

#======================================================================
# Note that this converts the string to a more `user readable' form using `standard' chars for catcodes.
# We'll need to be careful about using string instead of reverting for internal purposes where the
# actual character is needed.

# Should revert do something with this???
#  ($standardchar[$$self[1]] || $$self[0]); }

sub revert { $_[0]; }
sub toString { $_[0]->[0]; }

sub beDigested { 
  my($self,$stomach)=@_;
  $stomach->digest($self); }

#======================================================================
# Methods for overloaded ops.

# Compare two tokens; They are equal if they both have same catcode,
# and either the catcode is one of the primitive ones, or thier strings
# are equal.
sub equals {
  my($a,$b)=@_;
  (defined $b
   && (ref $a) eq (ref $b)) 
    && ($$a[1] eq $$b[1])
      && ($primitive_catcode[$$a[1]] || ($$a[0] eq $$b[0])); }

# Primarily for error reporting.
sub stringify {
  my($self)=@_;
  $CC_SHORT_NAME[$$self[1]].'['.$$self[0].']'; }

#**********************************************************************
# LaTeXML::Tokens
#   A blessed reference to a list of LaTeXML::Token's
#   It implements the core API of Mouth, as if pre-tokenized.
#**********************************************************************
package LaTeXML::Tokens;
use strict;
use LaTeXML::Global;
use base qw(LaTeXML::Object);

sub new {
  my($class,@tokens)=@_;
  bless [@tokens],$class; }

# Return a list of the tokens making up this Tokens
sub unlist { @{$_[0]}; }

# Return a shallow copy of the Tokens
sub clone {
  my($self)=@_;
  bless [@$self], ref $self; }


# Return a string containing the TeX form of the Tokens
sub revert { @{$_[0]}; }

#sub toString { join('',map($_->toString, @{$_[0]})); }

sub toString {
  my($self)=@_;
  my $string = '';
  my $prevmac=0;
  foreach my $token (@$self){
    next if $token->getCatcode == CC_COMMENT;
    my $s = $token->toString();
    $string .= ' ' if $prevmac && ($s =~ /^\w/);
    $string .= $s;
    $prevmac = ($s  =~ /^\\/) if $s; }
  $string; }

# Methods for overloaded ops.
sub equals {
  my($a,$b)=@_;
  return 0 unless defined $b && (ref $a) eq (ref $b);
  my @a = @$a;
  my @b = @$b;
  while(@a && @b && ($a[0]->equals($b[0]))){
    shift(@a); shift(@b); }
  return !(@a || @b); }

sub stringify {
  my($self)=@_;
  "Tokens[".join(',',map($_->toString,@$self))."]"; }

sub beDigested { 
  my($self,$stomach)=@_;
  $stomach->digest($self); }

sub neutralize {
  Tokens(map($_->neutralize,$_[0]->unlist)); }

#======================================================================
# The following implements the Mouth API, so that a Token list can
# act as a pre-tokenized source of tokens.

sub finish {}
sub hasMoreInput {
  my($self)=@_;
  scalar(@$self); }

sub readToken {
  my($self)=@_;
  return unless @$self;
  shift(@$self); }

sub readTokens {
  my($self,$until)=@_;
  my @tokens=();
  while(defined(my $token = $self->readToken())){
    last if $until and $token->getString eq $until->getString;
    push(@tokens,$token); }
  while(@tokens && $tokens[$#tokens]->getCatcode == CC_SPACE){ # Remove trailing space
    pop(@tokens); }
  Tokens(@tokens); }

sub getLocator { ''; }
sub getSource  { ''; }
#**********************************************************************
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Token> - representation of a token,
and C<LaTeXML::Tokens>, representing lists of tokens.

=head1 DESCRIPTION

This module defines Tokens (C<LaTeXML::Token>, C<LaTeXML::Tokens>)
that get created during tokenization and  expansion.

A C<LaTeXML::Token> represents a TeX token which is a pair of a character or string and
a category code.  A C<LaTeXML::Tokens> is a list of tokens (and also implements the API
of a L<LaTeXML::Mouth> so that tokens can be read from a list).

=head2 Common methods

The following methods apply to all objects.

=over 4

=item C<< @tokens = $object->unlist; >>

Return a list of the tokens making up this C<$object>.

=item C<< $string = $object->toString; >>

Return a string representing C<$object>.

=back

=head2 Token methods

The following methods are specific to C<LaTeXML::Token>.

=over 4

=item C<< $string = $token->getCSName; >>

Return the string or character part of the C<$token>; for the special category
codes, returns the standard string (eg. C<T_BEGIN->getCSName> returns "{").

=item C<< $string = $token->getString; >>

Return the string or character part of the C<$token>.

=item C<< $code = $token->getCharcode; >>

Return the character code of the character part of the C<$token>,
or 256 if it is a control sequence.

=item C<< $code = $token->getCatcode; >>

Return the catcode of the C<$token>.

=item C<< $defn = $token->getDefinition; >>

Return the current definition associated with C<$token> in C<$STATE>, or
undef if none.

=back

=head2 Tokens methods

=begin latex

\label{LaTeXML::Tokens}

=end latex

The following methods are specific to C<LaTeXML::Tokens>.

=over 4

=item C<< $tokenscopy = $tokens->clone; >>

Return a shallow copy of the $tokens.  This is useful before reading from a C<LaTeXML::Tokens>.

=item C<< $token = $tokens->readToken; >>

Returns (and remove) the next token from $tokens.  This is part of the public API of L<LaTeXML::Mouth>
so that a C<LaTeXML::Tokens> can serve as a L<LaTeXML::Mouth>.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

