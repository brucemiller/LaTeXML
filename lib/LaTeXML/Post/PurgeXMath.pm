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
use Exporter;
use LaTeXML::Post;
our @ISA = (qw(Exporter LaTeXML::Post::Processor));

# ================================================================================
sub new {
  my($class,%options)=@_;
  my $self = bless {},$class;
  $self->init(%options);
  $self; }

sub process {
  my($self,$doc,%options)=@_;

  my @math =  $self->findMathNodes($doc);
  $self->Progress("Removing ".scalar(@math)." Intermediate XMath nodes");
  foreach my $math (@math){
    $math->parentNode->removeChild($math); }
  $doc; }

sub findMathNodes {
  my($self,$doc)=@_;
  $doc->getElementsByTagNameNS($self->getNamespace,'XMath'); }

# ================================================================================
1;
