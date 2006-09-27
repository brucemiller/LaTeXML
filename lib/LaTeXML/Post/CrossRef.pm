# /=====================================================================\ #
# |  LaTeXML::Post::CrossRef                                            | #
# | Scan for ID's etc                                                   | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post::CrossRef;
use strict;
use LaTeXML::Util::Pathname;
use XML::LibXML;
use base qw(LaTeXML::Post);

sub new {
  my($class,%options)=@_;
  my $self = $class->SUPER::new(%options);
  $$self{db}=$options{db};
  $self; }

sub process {
  my($self,$doc)=@_;
  my $root = $doc->getDocumentElement;
  $self->fill_in_cites($doc);
  $self->fill_in_refs($doc);
  $doc; }

# Fill in content text for any <ref..>'s; Section name
# Mostly should apply to cite, as well?
# In fact, probably should apply to all @idref's
# EXCEPT XMRef!!!!
sub fill_in_refs {
  my($self,$doc)=@_;
  my $db = $$self{db};
  my $baseurl = pathname_directory($doc->getURL);
  print STDERR "Filling in refs\n" if $$self{verbosity}>1;
  foreach my $ref ($doc->findnodes('descendant::ltx:ref')){
    my $id = $ref->getAttribute('idref');
    if(!$id){
      if(my $label = $ref->getAttribute('labelref')){
	if(my $entry = $db->lookup("LABEL:$label")){
	  $id = $entry->getValue('id'); }}}
    if($id){
      if(my $object = $db->lookup("ID:".$id)){
	my $url    = $object->getValue('url');
	my $fragid = $object->getValue('fragid');
	$url = pathname_relative('/'.$url,'/'.$baseurl) if $url && $baseurl;
	$url .= '#'.$fragid if $url && $fragid;
	$ref->setAttribute(href=>$url) if $url;
	if(my $titlestring = $object->getValue('titlestring')){
	  $ref->setAttribute(title=>$titlestring); }
	if(!$ref->textContent){
	  my $title = $object->getValue('title');
	  $doc->addNodes($ref,(ref $title ? $title->childNodes : $title)); }
      }}}}

# Needs to evolve into the combined stuff that we had in DLMF.
# (eg. concise author/year combinations for multiple cites)
sub fill_in_cites {
  my($self,$doc)=@_;
  my $db = $$self{db};
  my $baseurl = pathname_directory($doc->getURL);
  print STDERR "Filling in cites\n" if $$self{verbosity}>1;
  foreach my $cite ($doc->findnodes('descendant::ltx:cite')){
    my $style  = $cite->getAttribute('style') || '';
    my $show   = $cite->getAttribute('show');
    my $pre    = $doc->findnode('ltx:citepre',$cite);
    my $post   = $doc->findnode('ltx:citepost',$cite);
    my @cites  = ();
    foreach my $key (split(/,/,$cite->getAttribute('ref'))){
      my $entry = $db->lookup("BIBLABEL:$key");
      if(my $id = $entry->getValue('id')){
	my $object = $db->lookup("ID:$id");
	my $url    = $object->getValue('url');
	my $fragid = $object->getValue('fragid');
	my $titlestring = $object->getValue('titlestring');
	$url = pathname_relative('/'.$url,'/'.$baseurl) if $url && $baseurl;
	$url .= '#'.$fragid if $url && $fragid;
	my $title = $object->getValue('title');
	push(@cites,
	     ['ltx:ref',{ idref=>$id,
			  ($url         ? (href=>$url):()),
			  ($titlestring ? (title=>$titlestring):()) },
	      (ref $title ? $title->childNodes : $title)]); }
      map($cite->removeChild($_),$cite->childNodes);
      $doc->addNodes($cite,
		     ($style ne 'intext' ? ('('):()),
		     ($pre  && $style eq 'intext' ? ('(',$pre, ')') : ($pre)),
		     @cites,
		     ($post && $style eq 'intext' ? ('(',$post,')') : ($post)),
		     ($style ne 'intext' ? (')'):())); }}}

# NOTE: THis needs to be adapted from XDLMF,
# but the functionality is desirable.
# Given a list of bibitem targets, construct links to them.
# Combines when multiple bibitems share the same authors.
sub make_bibcite {
  my($show,$format,@bibtargets)=@_;
  if(($show||'all') eq 'all'){ # Combine same authors
##    if(@bibtargets > 1){
##      print STDERR "Joining ".join(', ',map($_->key,@bibtargets))."\n"; }
    my @stuff=();
    while(@bibtargets){
      push(@stuff,', ') if @stuff;
      my $target = shift(@bibtargets);
      my $authors = $target->get_xml_value('names');
      my $authtxt = $authors && $authors->textContent;
      my @group = ();
      my $a;
      while($authtxt && @bibtargets
	    && ($a = $bibtargets[0]->get_xml_value('names'))
	    && ($authtxt eq $a->textContent)){
	push(@group,shift(@bibtargets)); }
      if(@group){
	push(@stuff,content_nodes($authors),'(',
	    ['bibref',{bibref=>$target->key,
		       title=>stringify($target->make_ref(format=>'long'))},
	     content_nodes($target->get_xml_value('year'))]);
	foreach my $next (@group){
	  push(@stuff,', ',
	       ['bibref',{bibref=>$next->key,
			  title=>stringify($next->make_ref(format=>'long'))},
		content_nodes($next->get_xml_value('year'))]); }
	push(@stuff,')'); }
      else {
	push(@stuff,['bibref',{bibref=>$target->key,
			       title=>stringify($target->make_ref(format=>'long'))},
		     content_nodes($authors),'(',
		     content_nodes($target->get_xml_value('year')),')']); }}
    @stuff; }
  else {
    conjoin(', ',
	    map(['bibref',{bibref=>$_->key,
			   title=>stringify($_->make_ref(format=>'long'))},
		 $_->make_ref(show=>$show,format=>$format)],
		@bibtargets)); }}


# ================================================================================
1;

