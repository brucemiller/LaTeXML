# /=====================================================================\ #
# |  LaTeXML::Global                                                    | #
# | Global constants, accessors and constructors                        | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

#======================================================================
#  This module collects all the commonly useful constants and constructors
# that other modules and package implementations are likely to need.
# This should be used in a context where presumably all the required
# LaTeXML modules that implement the various classes have already been loaded.
#
# Yes, a lot of stuff is exported, polluting your namespace.
# Thus, you use this module only if you _need_ the functionality!
#======================================================================
package LaTeXML::Global;
use strict;
use warnings;
use base qw(Exporter);
our @EXPORT = (    # Global STATE; This gets bound by LaTeXML.pm
  qw( *STATE
    TRACE_MACROS TRACE_COMMANDS TRACE_ALL TRACE_PROFILE
  ),
);

#local $LaTeXML::STATE;

use constant TRACE_MACROS   => 0x1;
use constant TRACE_COMMANDS => 0x2;
use constant TRACE_ALL      => 0x3;    # MACROS | COMMANDS
use constant TRACE_PROFILE  => 0x4;
#**********************************************************************
1;

__END__

=pod 

=head1 NAME

C<LaTeXML::Global> - global exports used within LaTeXML, and in Packages.

=head1 SYNOPSIS

use LaTeXML::Global;

=head1 DESCRIPTION

This module exports the various constants and constructors that are useful
throughout LaTeXML, and in Package implementations.

=head2 Global state

=over 4

=item C<< $STATE; >>

This is bound to the currently active L<LaTeXML::Core::State> by an instance
of L<LaTeXML> during processing.

=back 

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut

