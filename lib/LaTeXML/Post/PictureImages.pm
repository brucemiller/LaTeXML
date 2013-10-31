# /=====================================================================\ #
# |  LaTeXML::Post::PictureImages                                          | #
# | Postprocessor to create images for picture                             | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post::PictureImages;
use strict;
use LaTeXML::Post;
use base qw(LaTeXML::Post::LaTeXImages);

sub new {
  my ($class, %options) = @_;
  $options{resource_directory} = 'pic' unless defined $options{resource_directory};
  $options{resource_prefix}    = 'pic' unless defined $options{resource_prefix};
  $options{use_dvipng}         = 0     unless defined $options{use_dvipng};
  $class->SUPER::new(%options); }

#======================================================================

# Return the list of Picture nodes.
sub toProcess { $_[1]->findnodes('//ltx:picture'); }

# Return the TeX string to format the image for this node.
sub extractTeX {
  my ($self, $doc, $node) = @_;
  my $tex = $self->cleanTeX($node->getAttribute('tex') || '');
  $tex =~ s/\n//gs;    # trim stray CR's
  if (my $u = $node->getAttribute('unitlength')) {
    $tex = "\\setlength{\\unitlength}{$u}" . $tex; }
  # xunitlength, yunitlength for pstricks???
  "\\beginPICTURE $tex\\endPICTURE"; }

# Definitions needed for processing inline & display picture images
sub preamble {
  my ($self, $doc) = @_;
  return <<EOPreamble;
\\def\\beginPICTURE{\\lxBeginImage}
\\def\\endPICTURE{\\lxEndImage\\lxShowImage}
EOPreamble
}
#======================================================================
1;
