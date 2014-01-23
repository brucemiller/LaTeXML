package Perl::Critic::Policy::LaTeXML::RequireDoubleSigils;
use strict;
use warnings;
use Readonly;

use Perl::Critic::Utils qw{ :severities };
use base 'Perl::Critic::Policy';

our $VERSION = '0.0001';

#-----------------------------------------------------------------------------

Readonly::Scalar my $DESC => q{Method call style dereference};
Readonly::Scalar my $EXPL => q{Use double sigil};

#-----------------------------------------------------------------------------

sub supported_parameters { return () }
sub default_severity     { return $SEVERITY_HIGH }
sub default_themes       { return qw(core cosmetic) }
sub applies_to           { return 'PPI::Structure::Subscript' }

#-----------------------------------------------------------------------------
# We're looking for stuff like
#    $something->{key}  or #    $something->[key]
sub violates {
  my ($self, $elem, undef) = @_;
  return if $elem eq q{\\};
  # Check that "->" is the preceding operattor
  my $op = $elem->sprevious_sibling;
  return if !$op || !$op->isa('PPI::Token::Operator') || $op->content ne '->';
  # And check that the preceding object is a symbol, but not $_
  # However, I'll condescend to allow Magic variables to use this notation
  my $object = $op->sprevious_sibling;
  return if !$object || !$object->isa('PPI::Token::Symbol') || $object->isa('PPI::Token::Magic');
##  print STDERR "ARROWREF: "
##    ."object: '".$object->content."' [".(ref $object)."] "
##    ."operator: '".$op->content."' [".(ref $op)."] "
##    ."script: '".$elem->content."' [".(ref $elem)."] "
##    ."\n";
  return $self->violation($DESC, $EXPL, $elem);
}

1;

__END__

#-----------------------------------------------------------------------------

=pod

=head1 NAME

Perl::Critic::Policy::LaTeXML::RequireDoubleSigils - Write C<$$hash_ref{key}> instead of C<$hash_ref->{key}>.

=head1 AFFILIATION

This Policy is mine, all mine.

=head1 DESCRIPTION

When dereferencing a hash or array, use double sigils instead an arrow.
The arrows are verbose and cluttered; they look like a weird method call.
If you want to do that, you probably should define an actual accessor
method rather than trying to hide it.

  $hash->{$key}           # not ok
  $$hash{$key}            # ok
  $arrayref->[$n]         # not ok
  $$arrayref[$n]          # ok

=head1 CONFIGURATION

This Policy is not configurable except for the standard options.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

