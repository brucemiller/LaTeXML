# /=====================================================================\ #
# |  LaTeXML::Post::PurgeXMath                                          | #
# | Postprocessor to purge the intermedate parsed math                  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Post::PurgeXMath;
use strict;
use LaTeXML::Util::LibXML;
use base qw(LaTeXML::Post::Processor);

# ================================================================================
sub process {
  my($self,$doc,%options)=@_;
  my @math = $doc->getElementsByTagNameNS($self->getNamespace,'XMath');
  $self->Progress("Removing ".scalar(@math)." Intermediate XMath nodes");
  foreach my $math (@math){
    $math->parentNode->removeChild($math); }
  $doc; }

# ================================================================================
1;
