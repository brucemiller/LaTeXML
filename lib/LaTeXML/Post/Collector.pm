# /=====================================================================\ #
# |  LaTeXML::Post::Collector                                           | #
# | Abstract class; collects info & builds, like MakeIndex, MakeBib...  | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Post::Collector;
use strict;
use LaTeXML::Util::Pathname;
use XML::LibXML;
use charnames qw(:full);
use base qw(LaTeXML::Post);

# Options:
#   scanner: pass in a scanner to scan what we've just built
#            Since these classes are typically built from scanned data...
sub new {
  my($class,%options)=@_;
  my $self = $class->SUPER::new(%options);
  $$self{scanner}  = $options{scanner};
  $self; }

# Needs sub process {...

# Given that the subclass has decided to break up the collected content
# into portions (presumably by Initials?), we'll fill in the
# main document (at $root) with the first subcollection, and create new documents for the rest.
# $collections{initial}=>construction data.
sub makeSubCollectionDocuments {
  my($self,$doc,$root,%collections)=@_;
  my @docs = ();

  my $roottag = $doc->getQName($root);
  my $rootid = $root->getAttribute('xml:id');

  my @initials = sort keys %collections;
  my $init0  = $initials[0];
  my @ids = ([$rootid,$init0],map(["$rootid.$_",$_],@initials[1..$#initials]));
  # Patchup the main node; Replace title, add nav, add the 1st subcollection.
  my @titles = $doc->findnodes('//ltx:title | //ltx:toctitle',$root);
  my @titlestuff = $doc->trimChildNodes($titles[0]);
  map($root->removeChild($_), @titles);
  for(my $i=0; $i<=$#ids; $i++){
    my $subdoc = ($i == 0 ? $doc
		  : $doc->newDocument([$roottag,{'xml:id'=>$ids[$i][0]}],
				      destination=>$self->getPageName($doc,$ids[$i][1])));
    push(@docs,$subdoc);
    $subdoc->addNodes($subdoc->findnode('//'.$roottag),
		      ['ltx:title',{},@titlestuff,' ',$ids[$i][1]],
		      ['ltx:TOC',{format=>'veryshort'},
		       ['ltx:toclist',{},
			map(($_ == $i
			     ? ['ltx:tocentry',{},$ids[$_][1]]
			     : ['ltx:tocentry',{},['ltx:ref',{idref=>$ids[$_][0]},$ids[$_][1]]]),
			    0..$#ids)]],
		      $collections{$ids[$i][1]});
    if($i > 0){
      $docs[$i  ]->addNavigation(previous=>$ids[$i-1][0]);
      $docs[$i-1]->addNavigation(next    =>$ids[$i  ][0]); }}
  @docs; }

sub rescan {
  my($self,$doc)=@_;
  ($$self{scanner} ? $$self{scanner}->process($doc) : $doc); }

# If the main document is named "index", (like index.html) presumably this collection
# will be contained in its own directory, so the sub document names can be short.
# Otherwise, we'll append the initial to 
sub getPageName {
  my($self,$doc,$initial)=@_;
  my($dir,$name,$type) = pathname_split($doc->getDestination);
  pathname_make(dir=>$dir,
		name=>($name eq 'index' ? $initial : "$name.$initial"),
		type=>$type); }

# ================================================================================
1;

