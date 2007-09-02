# /=====================================================================\ #
# |  LaTeXML::Post                                                      | #
# | PostProcessing driver                                               | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post;
use strict;
use Time::HiRes;
use LaTeXML::Util::Pathname;

sub new {
  my($class,%options)=@_;
  my $self = bless {%options}, $class; 
  $$self{verbosity} = 0 unless defined $$self{verbosity};
  $$self{resourceDirectory} = $options{resourceDirectory};
  $$self{resourcePrefix} = $options{resourcePrefix};
  $self; }

sub getNamespace            { $_[0]->{namespace} || "http://dlmf.nist.gov/LaTeXML"; }

#======================================================================
# abstract:
# sub process($doc) => $doc,...


sub ProcessChain {
  my($doc,@postprocessors)=@_;
  my @docs = ($doc);
  foreach my $processor (@postprocessors){
    my $t0 = [Time::HiRes::gettimeofday];
    @docs = map($processor->process($_),@docs);
    my $elapsed = Time::HiRes::tv_interval($t0,[Time::HiRes::gettimeofday]);
    my $mem =  `ps -p $$ -o size=`; chomp($mem);
    $processor->Progress(sprintf(" %.2f sec; $mem KB",$elapsed));
  }
  @docs; }

#======================================================================
sub Error {
  my($self,$msg)=@_;
  die "".(ref $self)." Error: $msg"; }

sub Warn {
  my($self,$msg)=@_;
  print STDERR "".(ref $self)." Warning: $msg\n" if $$self{verbosity}>-1; }

sub Progress {
  my($self,$msg)=@_;
  print STDERR "".(ref $self).": $msg\n" if $$self{verbosity}>0; }

sub ProgressDetailed {
  my($self,$msg)=@_;
  print STDERR "".(ref $self).": $msg\n" if $$self{verbosity}>1; }

#======================================================================
# Some postprocessors will want to create a bunch of "resource"s,
# such as generated or transformed image files, or other data files.
# These should return a pathname, relative to the document's destination,
# for storing a resource associated with $node.
# Will use the Post option resourceDirectory
sub desiredResourcePathname {
  my($self,$doc,$node,$source,$type)=@_;
  undef; }

sub generateResourcePathname {
  my($self,$doc,$node,$source,$type)=@_;
  my $subdir = $$self{resourceDirectory} || '';
  my $prefix = $$self{resourcePrefix} || "x";
  my $counter = join('_', "_max",$subdir,$prefix,"counter_");
  my $n = $doc->cacheLookup($counter) || 0;
  my $name = $prefix . ++$n;
  $doc->cacheStore($counter,$n); 
  pathname_make(dir=>$subdir, name=>$name, type=>$type); }
#======================================================================


#**********************************************************************
package LaTeXML::Post::Document;
use strict;
use XML::LibXML;
use XML::LibXML::XPathContext;
use LaTeXML::Util::Pathname;
use DB_File;
use Unicode::Normalize;

our $NSURI = "http://dlmf.nist.gov/LaTeXML";
our $XPATH = XML::LibXML::XPathContext->new();
$XPATH->registerNs(ltx=>$NSURI);

sub new {
  my($class,$xmldoc,%options)=@_;
  my %data = ();
  if(ref $class){		# Cloning!
    map($data{$_}=$$class{$_}, keys %$class);
    $class = ref $class; }
  map($data{$_}=$options{$_}, keys %options); # These override.
  if((defined $options{destination}) && (!defined $options{destinationDirectory})){
    my($vol,$dir,$name)=File::Spec->splitpath($data{destination});
    $data{destinationDirectory} = $dir || '.'; }
  $data{document}=$xmldoc;
  $data{idcache} = undef;
  $data{namespaces}={ltx=>$NSURI} unless $data{namespaces};
  $data{namespaceURIs}={$NSURI=>'ltx'} unless $data{namespaceURIs};

  if(!$data{searchpaths}){
    my @paths = ();
    push(@paths,pathname_absolute($data{sourceDirectory})) if $data{sourceDirectory};
    foreach my $pi ($XPATH->findnodes('.//processing-instruction("latexml")',$xmldoc)){
      if($pi->textContent =~ /^\s*searchpaths\s*=\s*([\"\'])(.*?)\1\s*$/){
	push(@paths,split(',',$2)); }}
    $data{searchpaths} = [@paths]; }

  bless {%data}, $class; }

sub Error {
  my($self,$msg)=@_;
  die "".(ref $self)." Error: $msg"; }

sub newFromFile {
  my($class,$source,%options)=@_;
  if(!$options{sourceDirectory}){
    my($vol,$dir,$name) = File::Spec->splitpath($source);
    $options{sourceDirectory} = $dir || '.'; }
  $class->new(createParser(%options)->parse_file($source),
	      %options); }

sub newFromString {
  my($class,$string,%options)=@_;
  $options{sourceDirectory} = '.' unless $options{sourceDirectory};
  $class->new(createParser(%options)->parse_string($string),
	      %options); }

sub newFromSTDIN {
  my($class,%options)=@_;
  my $string;
  { local $/ = undef; $string = <>; }
  $options{sourceDirectory} = '.' unless $options{sourceDirectory};
  $class->new(createParser(%options)->parse_string($string),
	      %options); }

sub createParser {
  my(%options)=@_;
  # Read in the XML, unless it already is a Doc.
  my $XMLParser = XML::LibXML->new();
  if($options{validate}){ # First, load the LaTeXML catalog in case it's needed...
    map(XML::LibXML->load_catalog($_),
	pathname_find('catalog',installation_subdir=>'dtd'));
    $XMLParser->load_ext_dtd(1);  # DO load dtd.
    $XMLParser->validation(1); }
  else {
    $XMLParser->load_ext_dtd(0);
    $XMLParser->validation(0); }
  $XMLParser->keep_blanks(0);	# This allows formatting the output.
  $XMLParser; }


sub getDocument             { $_[0]->{document}; }
sub getDocumentElement      { $_[0]->{document}->documentElement; }
sub getSourceDirectory      { $_[0]->{sourceDirectory} || '.'; }
sub getSearchPaths          { @{$_[0]->{searchpaths}}; }
sub getDestination          { $_[0]->{destination}; }
sub getDestinationDirectory { $_[0]->{destinationDirectory}; }
sub toString                { $_[0]->{document}->toString(1); }

sub getDestinationExtension {
  my($self)=@_;
  ($$self{destination} =~ /\.([^\.\/]*)$/ ? $1 : undef); }

sub checkDestination {
  my($self,$reldest)=@_;
  my $dest = pathname_concat($self->getDestinationDirectory,$reldest);
  my $destdir = pathname_directory($dest);
  pathname_mkdir($destdir)
      or return $self->Error("Could not create directory $destdir for $reldest: $!"); 
  $dest; }

#======================================================================
sub findnodes {
  my($self,$path,$node)=@_;
  $XPATH->findnodes($path,$node || $$self{document}); }

# Similar but returns only 1st node
sub findnode {
  my($self,$path,$node)=@_;
  my($first)=$XPATH->findnodes($path,$node || $$self{document});
  $first; }

sub addNamespace{
  my($self,$nsuri,$prefix)=@_;
  $$self{namespaces}{$prefix}=$nsuri;
  $$self{namespaceURIs}{$nsuri}=$prefix;
  $self->getDocumentElement->setNamespace($nsuri,$prefix,0); }

sub getQName {
  my($self,$node)=@_;
  my $nsuri = $node->namespaceURI;
  if(my $prefix = $$self{namespaceURIs}{$nsuri}){
    $prefix.":".$node->localname; }
  else {
    warn "Missing namespace prefix for $nsuri";
    $node->localname; }}
#======================================================================
# ADD nodes to $node in the document $self.
# This takes a convenient recursive reprsentation for xml:
# data = string |  [$tagname, {attr=>value,..}, @children...]
# The $tagname should have a namespace prefix whose URI has been
# registered with addNamespace.

sub addNodes {
  my($self,$node,@data)=@_;
  foreach my $child (@data){
    if(ref $child eq 'ARRAY'){
      my($tag,$attributes,@children)=@$child;
      my($prefix,$localname)= $tag =~ /^(.*):(.*)$/;
      my $nsuri = $prefix && $$self{namespaces}{$prefix};
      warn "No namespace on $tag" unless $nsuri;
      my $new = $node->addNewChild($nsuri,$localname);
      if($attributes){
	foreach my $key (keys %$attributes){
	  next unless defined $$attributes{$key};
	  my($attrprefix,$attrname)= $key =~ /^(.*):(.*)$/;
	  if($attrprefix){
	    my $attrnsuri = $attrprefix && $$self{namespaces}{$attrprefix};
	    $new->setAttributeNS($attrnsuri,$attrname, $$attributes{$key}); }
	  else {
	    $new->setAttribute($key, $$attributes{$key}); }
	}}
      $self->addNodes($new,@children); }
    elsif((ref $child) =~ /^XML::LibXML::/){
      # NOTE: Watch this space for possible namespace mangling.
#      $node->appendChild($$self{document}->importNode($child));
#      $node->addChild($$self{document}->importNode($child));
#      $node->appendChild($$self{document}->adoptNode($child));
      # This version seems to work, but assumes the $child isn't 
      # still part of some other document.   BUT that's risky
#      $node->addChild($child);
##      my $newchild = $$self{document}->importNode($child);
##      $node->appendChild($newchild);
##      $newchild->setNamespace($child->namespaceURI,$child->prefix,1)
##	if $child->nodeType == XML_ELEMENT_NODE;

##      if(0){
      # So, we walk through the to-be-added node, copying it's data & children.
      my $type = $child->nodeType;
      if($type == XML_ELEMENT_NODE){
	my $newnode = $node->addNewChild($child->namespaceURI,$child->localname);
	copy_attributes($newnode,$child);
	$self->addNodes($newnode,$child->childNodes); }
      elsif($type == XML_DOCUMENT_FRAG_NODE){
	$self->addNodes($node,$child->childNodes); }
      elsif($type == XML_TEXT_NODE){
	$node->appendTextNode($child->textContent); }
##    }
    }
    elsif(ref $child){
      warn "Dont know how to add $child to $node; ignoring"; }
    elsif(defined $child){
      $node->appendTextNode($child); }}}

sub newDocument {
  my($self,$root,%options)=@_;
  my $xmldoc = XML::LibXML::Document->new("1.0","UTF-8");
  my($public_id,$system_id);
  if(my $dtd = $$self{document}->internalSubset){
    if($dtd->toString
       =~ /^<!DOCTYPE\s+(\w+)\s+PUBLIC\s+(\"|\')([^\2]*)\2\s+(\"|\')([^\4]*)\4>$/){
      ($public_id,$system_id)=($3,$5); }}
  my $parent_id;
  if(ref $root eq 'ARRAY'){
    my($tag,$attributes,@children)=@$root;
    my($prefix,$localname)= $tag =~ /^(.*):(.*)$/;
    $xmldoc->createInternalSubset($localname,$public_id,$system_id) if $public_id;
    my $nsuri = $$self{namespaces}{$prefix};
    my $node = $xmldoc->createElementNS($nsuri,$localname);
    $xmldoc->setDocumentElement($node);
    map( $node->setAttribute($_=>$$attributes{$_}),keys %$attributes) if $attributes;
    $self->addNodes($node,@children); }
  elsif(ref $root eq 'XML::LibXML::Element'){
    $parent_id = $self->findnode('ancestor::*[@id]',$root);
    $parent_id = $parent_id->getAttribute('id') if $parent_id;
    my $localname = $root->localname;
    $xmldoc->createInternalSubset($localname,$public_id,$system_id) if $public_id;
    # Make a copy of $root be the new element node, carefully w.r.t. namespaces.
    # Seems that only importNode (not adopt) works correctly,
    # PROVIDED we also set the namespace.
    my $node = $xmldoc->importNode($root);
    $xmldoc->setDocumentElement($node); 
    $xmldoc->documentElement->setNamespace($root->namespaceURI,$root->prefix,1); }
  else {
    die "Dont know how to use $root as document element"; }

  my $root_id = $self->getDocumentElement->getAttribute('id');
  my $doc = $self->new($xmldoc,
		       ($parent_id ? (parent_id=>$parent_id) : ()),
		       ($root_id   ? (split_from_id=>$root_id) : ()),
		       %options); 

  # Copy any processing instructions.
  foreach my $pi ($self->findnodes(".//processing-instruction('latexml')")){
    $doc->getDocument->appendChild($pi->cloneNode); }
  # If new document has no date, but $self's document has some, copy them.
  if(!$doc->findnodes('ltx:date',$doc->getDocumentElement)){
    if(my @dates = $self->findnodes('ltx:date',$self->getDocumentElement)){
      $doc->addNodes($doc->getDocumentElement,@dates); }}
  # Finally, return the new document.
  $doc; }

sub copy_attributes {
  my($newnode,$oldnode)=@_;
  foreach my $child ($oldnode->attributes){
    my $type = $child->nodeType;
    if($type == XML_ATTRIBUTE_NODE){
      if(my $ns = $child->namespaceURI){
	$newnode->setAttributeNS($ns,$child->localname,$child->getValue); }
      else {
	$newnode->setAttribute($child->localname,$child->getValue); }}
    elsif($type == XML_NAMESPACE_DECL){}
    else {
      warn "Dont know how to add $child to $newnode; ignoring"; }}}

#======================================================================
# Given a list of nodes (or node constructors [tag,attr,content...])
# conjoin given a conjunction like ',' or a pair like [',', ' and ']
sub conjoin {
  my($self,$conjunction,@nodes)=@_;
  my ($comma,$and) = ($conjunction,$conjunction);
  ($comma,$and)=@$conjunction if ref $conjunction;
  my $n = scalar(@nodes);
  if($n < 2){ return @nodes; }
  else {
    my @foo=();
    push(@foo,shift(@nodes));
    while($nodes[1]){
      push(@foo, $comma,shift(@nodes)); }
    push(@foo,$and,shift(@nodes)); 
    @foo; }}

# Find the initial letter in a string, or *.
# Uses unicode decomposition to reduce accented characters to A-Z
# If $force is true, skips any non-letter initials
sub initial {
  my($self,$string,$force)=@_;
  $string = NFD($string);	# Decompose accents, etc.
  $string =~ s/^[^a-zA-Z]*// if $force;
  ($string =~/^([a-zA-Z])/ ? uc($1) : '*'); }

sub trimChildNodes {
  my($self,$node)=@_;
  if(!$node){ (); }
  elsif(!ref $node){ ($node); }
  elsif(my @children = $node->childNodes){
    if($children[0]->nodeType == XML_TEXT_NODE){
      my $s = $children[0]->data;
      $s =~ s/^\s+//;
      $children[0]->setData($s); }
    if($children[-1]->nodeType == XML_TEXT_NODE){
      my $s = $children[-1]->data;
      $s =~ s/\s+$//;
      $children[-1]->setData($s); }
    @children; }
  else { (); }}
    
#======================================================================

sub addNavigation {
  my($self,$direction,$id)=@_;
  my $ref = ['ltx:ref',{class=>$direction,show=>'typerefnum. title',idref=>$id}];
  if(my $nav = $self->findnode('//ltx:navigation')){
    $self->addNodes($nav,$ref); }
  else {
    $self->addNodes($self->getDocumentElement, ['ltx:navigation',{},$ref]);}}

#======================================================================
# Support for ID's

sub findNodeByID {
  my($self,$id)=@_;
  if(!$$self{idcache}){
    $$self{idcache}={};
    foreach my $node ($self->findnodes("//*[\@id]")){
      $$self{idcache}{$node->getAttribute('id')} = $node; }}
  $$self{idcache}{$id}; }

sub realizeXMNode {
  my($self,$node)=@_;
  (($node->localname eq 'XMRef') && ($node->getNamespaceURI eq $NSURI)
   ? $node=$self->findNodeByID($node->getAttribute('idref'))
   : $node); }

#======================================================================
# adjust_latexml_doctype($doc,"Foo","Bar") =>
# <!DOCTYPE document PUBLIC "-//NIST LaTeXML//LaTeXML article + Foo + Bar"
#                 "http://dlmf.nist.gov/LaTeXML/LaTeXML-Foo-Bar.dtd">
sub adjust_latexml_doctype {
  my($self,@additions)=@_;
  my $doc = $$self{document};
  if(my $dtd = $doc->internalSubset){
    if($dtd->toString
       =~ /^<!DOCTYPE\s+(\w+)\s+PUBLIC\s+(\"|\')-\/\/NIST LaTeXML\/\/LaTeXML\s+([^\"]*)\2\s+(\"|\')([^\"]*)\4>$/){
      my($root,$parts,$system)=($1,$3,$5);
      my($type,@addns)=split(/ \+ /,$parts);
      my %addns = ();
      map($addns{$_}=1,@addns,@additions);
      @addns = sort keys %addns;
      my $publicid = join(' + ',"-//NIST LaTeXML//LaTeXML $type",@addns);
      my $systemid = join('-',"http://dlmf.nist.gov/LaTeXML/LaTeXML",@addns).".dtd";
      $doc->removeInternalSubset;	# Apparently we've got to remove it first.
      $doc->createInternalSubset($root,$publicid,$systemid); }}}

#======================================================================
# Cache support: storage of data from previous run.
# ?

# cacheFile as parameter ????

sub cacheLookup {
  my($self,$key)=@_;
  $self->openCache;
  $$self{cache}{$key}; }

sub cacheStore {
  my($self,$key,$value)=@_;
  $self->openCache;
  if(defined $value){
    $$self{cache}{$key} = $value; }
  else {
    delete $$self{cache}{$key}; }}

sub openCache {
  my($self)=@_;
  if(!$$self{cache}){
    $$self{cache}={};
    my $dbfile = $self->checkDestination("LaTeXML.cache");
    tie %{$$self{cache}}, 'DB_File', $dbfile,  O_RDWR|O_CREAT
      or return $self->Error("Couldn't create DB cache for ".$self->getDestination.": $!");
  }}

sub closeCache {
  my($self)=@_;
  if($$self{cache}){
      untie %{$$self{cache}};
      $$self{cache}=undef; }}

1;

__END__

=head1 LaTeXML::Post

LaTeXML::Post is the driver for various postprocessing operations.
It has a complicated set of options that I'll document shortly.

=cut
#**********************************************************************

