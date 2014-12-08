# /=====================================================================\ #
# |  LaTeXML::Post::XMath                                               | #
# | XMath pseudo-generator for LaTeXML                                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

# ================================================================================
# LaTeXML::XMath  Math Formatter for LaTeXML's Parsed Math.
#   LaTeXML's parallel math markup model is rather primitive;
# we just let the ltx:Math contain ltx:XMath and any other math representations.
# There isn't any intelligent selection or classification of them (yet?).
#
#   If XMath is going to be kept in the document either alone,
# or as the "primary" representation within a Parallel markup,
# then all we have to do is leave it alone --- it's fine where it is.
#
#   If it is NOT the primary representation, however, then we'll need
# to MOVE the XMath from where it is to whereever the primary representation
# wants it.  Since it has ID's within it that are already known to the document,
# it needs to move, rather than be copied.
#
# AND, since any formatters that would follow this one would want to translate
# the XMath (which is now gone), this math formatter MUST be the last one....
# OR... Does it?????
# ================================================================================

package LaTeXML::Post::XMath;
use strict;
use warnings;
use LaTeXML::Common::XML;
use LaTeXML::Post;
use base qw(LaTeXML::Post::MathProcessor);

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Top level
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

our $lxMimeType = 'application/x-latexml';

sub convertNode {
  my ($self, $doc, $xmath, $style) = @_;
  my $idsuffix = $self->IDSuffix;
  return { processor => $self, encoding => $lxMimeType, mimetype => $lxMimeType,
    xml => ($idsuffix
        # Should we be trying to call/mimic associateID ?
      ? ['ltx:XMath', {}, map { $doc->cloneNode($_, $idsuffix) } element_nodes($xmath)]
        # If no idsuffix, we're actually just PRESERVING the xmath,
        # so we shouldn't need any cloning or id munging (!?!?!?!)
      : $xmath) }; }

sub combineParallel {
  my ($self, $doc, $xmath, $primary, @secondaries) = @_;
  # Just return the converted nodes to be added to the ltx:Math
  my $id  = $xmath->getAttribute('fragid');
  my @alt = ();
  foreach my $secondary (@secondaries) {
    my $mimetype = $$secondary{mimetype} || 'unknown';
    if ($mimetype eq $lxMimeType) {    # XMath
      push(@alt, $$secondary{xml}); }
    elsif (my $xml = $$secondary{xml}) {    # Other XML? may need wrapping.
      push(@alt, $$secondary{processor}->outerWrapper($doc, $xmath, $xml)); }
    #    elsif (my $src = $$secondary{src}) {         # something referred to by a file? Image, maybe?
    #      push(@alt, ['ltx:graphic', { src => $src }]); }
    #    elsif (my $string = $$secondary{string}) {    # simple string data?
    #      push(@alt, ['m:annotation', { encoding => $$secondary{encoding} }, $string]); }
    # anything else ignore?
  }
  return { processor => $self, mimetype => $lxMimeType,
    xml => ['_Fragment_', {}, $$primary{xml}, @alt] }; }

sub rawIDSuffix {
  return '.xm'; }

#================================================================================

1;
