# /=====================================================================\ #
# |  LaTeXML::Util::Pack::Dir                                           | #
# | Processor for handling Dir inputs                                   | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Util::Pack::Dir;
use strict;
use warnings;
use File::Find;
use File::Spec::Functions qw(catfile);

use base qw(LaTeXML::Util::Pack);

# LaTeXML::Util::Pack methods, pre-unpacked directory implementation

sub unpack_source {
  my ($self) = @_;
  # already unpacked, skip to detection
  return $self->detect_source();
}

sub find_file {
  my ($self, $name) = @_;
  my $filename = $$self{directory} . "/$name";
  my $found    = -e $filename;
  return $found && $filename; }

sub full_filename {
  my ($self, $name) = @_;
  return catfile($$self{directory}, $name);
}

sub find_tex_files {
  my ($self) = @_;
  return unless $$self{directory};
  my $tex_ext          = $LaTeXML::Util::Pack::TEX_EXT;
  my @TeX_file_members = ();
  find(sub { /$tex_ext/ && push(@TeX_file_members, $_); }, $$self{directory});
  if (!@TeX_file_members) {    # No .tex file? Try files with no, or unusually long, extensions
    find(sub { (!/\./ || /\.[^.]{4,}$/) && push(@TeX_file_members, $_); }, $$self{directory});
  }
  return @TeX_file_members; }

# directory is handled externally, nothing to clean up
sub cleanup { return; }

1;

=head1 NAME

C<LaTeXML::Util::Pack::Dir> - smart packing and unpacking of directories

=head1 DESCRIPTION

This module provides the concrete methods for handling a directory input,
following the interfaced defined by C<LaTeXML::Util::Pack>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>,
Deyan Ginev <deyan.ginev@gmail.com>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
