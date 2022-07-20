# /=====================================================================\ #
# |  LaTeXML::Post::LexMath                                             | #
# | Copy Lexemes as parallel Math                                       | #
# \=========================================================ooo==U==ooo=/ #

# ================================================================================
# Trivial Math PostProcessor which supplies the lexemes string
#   (if deposited in the lexemes attribute of the XMath)
# currently required to --preload=llamapun.sty to achieve that
# ================================================================================

package LaTeXML::Post::LexMath;
use strict;
use warnings;
use LaTeXML::Common::XML;
use LaTeXML::Post;
use base qw(LaTeXML::Post::MathProcessor);

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Top level
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

our $lxMimeType = 'application/x-llamapun';

sub convertNode {
  my ($self, $doc, $xmath, $style) = @_;
  my $math    = $xmath->parentNode;
  my $lexemes = $math && isElementNode($math) && $math->getAttribute('lexemes');
  return { processor => $self, encoding => $lxMimeType, mimetype => $lxMimeType,
    string => $lexemes }; }

sub rawIDSuffix {
  return '.lm'; }

sub canConvert { return 1; }

#================================================================================

1;
