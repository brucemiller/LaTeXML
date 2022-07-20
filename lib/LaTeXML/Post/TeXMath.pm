# /=====================================================================\ #
# |  LaTeXML::Post::TeXMath                                             | #
# | Copy TeX as parallel Math                                           | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

# ================================================================================
# Trivial Math PostProcessor which supplies the TeX string
# ================================================================================

package LaTeXML::Post::TeXMath;
use strict;
use warnings;
use LaTeXML::Common::XML;
use LaTeXML::Post;
use base qw(LaTeXML::Post::MathProcessor);

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Top level
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

our $lxMimeType = 'application/x-tex';

sub convertNode {
  my ($self, $doc, $xmath, $style) = @_;
  my $math = $xmath->parentNode;
  my $tex  = $math && isElementNode($math) && $math->getAttribute('tex');
  return { processor => $self, encoding => $lxMimeType, mimetype => $lxMimeType,
    string => $tex }; }

sub rawIDSuffix {
  return '.tm'; }

sub canConvert { return 1; }

#================================================================================

1;
