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
use Encode;
use LaTeXML::Util::Pathname;

sub new {
  my($class,%options)=@_;
  my $self = bless {%options}, $class; 
  $$self{verbosity} = 0 unless defined $$self{verbosity};
  $$self{resourceDirectory} = $options{resourceDirectory};
  $$self{resourcePrefix}    = $options{resourcePrefix};
  $$self{siteDirectory}     = $options{siteDirectory};
  $self; }

sub getNamespace            { $_[0]->{namespace} || "http://dlmf.nist.gov/LaTeXML"; }

#======================================================================
# abstract:
# sub process($doc) => $doc,...


sub ProcessChain {
  my($doc,@postprocessors)=@_;
  my @docs = ($doc);
  foreach my $processor (@postprocessors){
    local $LaTeXML::Post::PROCESSOR = $processor;
    my $t0 = [Time::HiRes::gettimeofday];
    my @newdocs = ();
    foreach my $doc (@docs){
      local $LaTeXML::Post::DOCUMENT = $doc;
      push(@newdocs, $processor->process($doc)); }
    @docs = @newdocs;
    my $elapsed = Time::HiRes::tv_interval($t0,[Time::HiRes::gettimeofday]);
## not portable enough...
##    my $mem =  `ps -p $$ -o size=`; chomp($mem);
##    $processor->Progress($doc,sprintf(" %.2f sec; $mem KB",$elapsed));
    $processor->Progress($doc,sprintf(" %.2f sec",$elapsed));
  }
  @docs; }

#======================================================================
sub Error {
  my($self,$doc,$msg)=@_;
  my $dest= $doc && $doc->getDestination;
  die "".(ref $self).($dest ? "[".$dest."]" : '')." Error: $msg"; }

sub Warn {
  my($self,$doc,$msg)=@_;
  my $dest= $doc && $doc->getDestination;
  print STDERR "".(ref $self).($dest ? "[".$dest."]" : '').": Warning: $msg\n" if $$self{verbosity}>-1; }

sub Progress {
  my($self,$doc,$msg)=@_;
  my $dest= $doc && $doc->getDestination;
  print STDERR "".(ref $self).($dest ? "[".$dest."]" : '').": $msg\n" if $$self{verbosity}>0; }

sub ProgressDetailed {
  my($self,$doc,$msg)=@_;
  my $dest= $doc && $doc->getDestination;
  print STDERR "".(ref $self).($dest ? "[".$dest."]" : '').": $msg\n" if $$self{verbosity}>1; }

#======================================================================
# Return a pathname relative to the site base directory
sub siteRelativePathname {
  my($self,$pathname)=@_;
  (defined $pathname ? pathname_relative($pathname, $$self{siteDirectory}) : undef); }

sub getSiteDirectory { $_[0]->{siteDirectory}; }

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
use LaTeXML::Common::XML;
use LaTeXML::Util::Pathname;
use DB_File;
use Unicode::Normalize;

our $NSURI = "http://dlmf.nist.gov/LaTeXML";
our $XPATH = LaTeXML::Common::XML::XPath->new(ltx=>$NSURI);

# Useful options:
#   destination = the ultimate destination file for this document to be written.
#   destinationDirectory = the directory it will be stored in (derived from $destination)
#   namespaces = a hash of namespace prefix => namespace uri
#   namespaceURIs = reverse hash of above.
#   nocache = a boolean, disables storing of permanent LaTeXML.cache
#     the cache is used to remember things like image conversions from previous runs.
#   searchpaths = array of paths to search for other resources
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
  $data{namespaces}={ltx=>$NSURI} unless $data{namespaces};
  $data{namespaceURIs}={$NSURI=>'ltx'} unless $data{namespaceURIs};

  # Extract data from latexml's ProcessingInstructions
  # I'd like to provide structured access to the PI's for those modules that need them,
  # but it isn't quite clear what that api should be.
  $data{processingInstructions}=
    [map($_->textContent,$XPATH->findnodes('.//processing-instruction("latexml")',$xmldoc))];

  # Combine specified paths with any from the PI's
  my @paths = ();
  @paths = @{$data{searchpaths}} if $data{searchpaths};
  foreach my $pi (@{$data{processingInstructions}}){
    if($pi =~ /^\s*searchpaths\s*=\s*([\"\'])(.*?)\1\s*$/){
      push(@paths,split(',',$2)); }}
  push(@paths,pathname_absolute($data{sourceDirectory})) if $data{sourceDirectory};
  $data{searchpaths} = [@paths];

  my $self = bless {%data}, $class; 
  $$self{idcache} = {};
  foreach my $node ($self->findnodes("//*[\@xml:id]")){
    $$self{idcache}{$node->getAttribute('xml:id')} = $node; }
  # Possibly disable permanent cache?
  $$self{cache} = {} if $data{nocache};
  $self; }

sub Error {
  my($self,$msg)=@_;
  die "".(ref $self)." Error: $msg"; }

sub newFromFile {
  my($class,$source,%options)=@_;
  $options{source} = $source;
  if(!$options{sourceDirectory}){
    my($vol,$dir,$name) = File::Spec->splitpath($source);
    $options{sourceDirectory} = $dir || '.'; }
  my $doc = $class->new(LaTeXML::Common::XML::Parser->new()->parseFile($source),%options);
  $doc->validate if $$doc{validate};
  $doc; }

sub newFromString {
  my($class,$string,%options)=@_;
  $options{sourceDirectory} = '.' unless $options{sourceDirectory};
  my $doc = $class->new(LaTeXML::Common::XML::Parser->new()->parseString($string),%options);
  $doc->validate if $$doc{validate};
  $doc; }

sub newFromSTDIN {
  my($class,%options)=@_;
  my $string;
  { local $/ = undef; $string = <>; }
  $options{sourceDirectory} = '.' unless $options{sourceDirectory};
  my $doc = $class->new(LaTeXML::Common::XML::Parser()->parseString($string),%options);
  $doc->validate if $$doc{validate};
  $doc; }

sub getDocument             { $_[0]->{document}; }
sub getDocumentElement      { $_[0]->{document}->documentElement; }
sub getSource               { $_[0]->{source}; }
sub getSourceDirectory      { $_[0]->{sourceDirectory} || '.'; }
sub getSearchPaths          { @{$_[0]->{searchpaths}}; }
sub getDestination          { $_[0]->{destination}; }
sub getDestinationDirectory { $_[0]->{destinationDirectory}; }

sub getParentDocument { $_[0]->{parentDocument}; }
sub getAncestorDocument { 
  my($self)=@_;
  my($doc,$d) = $self;
  while($d = $$doc{parentDocument}){
    $doc = $d; }
  $doc; }

sub toString {
  my($self)=@_;
  $$self{document}->toString(1); }

sub getDestinationExtension {
  my($self)=@_;
  ($$self{destination} =~ /\.([^\.\/]*)$/ ? $1 : undef); }

sub checkDestination {
  my($self,$reldest)=@_;
  my $dest = pathname_concat($self->getDestinationDirectory,$reldest);
  if(my $destdir = pathname_directory($dest)){
    pathname_mkdir($destdir)
      or return $self->Error("Could not create directory $destdir for $reldest: $!"); }
  $dest; }

#======================================================================
sub validate {
  my($self)=@_;
  # First, load the LaTeXML catalog in case it's needed...
  map(XML::LibXML->load_catalog($_),
      pathname_findall('catalog',installation_subdir=>'schema'));
  # Check for a RelaxNGSchema PI
  my $schema;
  foreach my $pi (@{$$self{processingInstructions}}){
    if($pi =~ /^\s*RelaxNGSchema\s*=\s*([\"\'])(.*?)\1\s*$/){
      $schema = $2; }}
  if($schema){			# Validate using rng
    $schema .= ".rng" unless $schema =~ /\.rng$/;
#    print STDERR "Validating using schema $schema\n";
    my $rng;
    eval { $rng = XML::LibXML::RelaxNG->new(location=>$schema); };
    if($@){			# Failed to load schema from catalog
      my $schemapath = pathname_find($schema,paths=>[$self->getSearchPaths]);
      eval { $rng = XML::LibXML::RelaxNG->new(location=>$schemapath); };
    }
    die "Failed to load RelaxNG schema $schema:\n$@" unless $rng;
    eval { $rng->validate($$self{document}); };
    if($@){
#      die "Error during RelaxNG validation  (".$schema."):\n".substr($@,0,200); }}
      die "Error during RelaxNG validation  (".$schema."):\n".$@
	."\nEither fix the source document, or use the --novalidate option\n"; }}
  elsif(my $decldtd = $$self{document}->internalSubset){ # Else look for DTD Declaration
#    print STDERR "Validating using DTD ".$decldtd->publicId." at ".$decldtd->systemId."\n";
    my $dtd = XML::LibXML::Dtd->new($decldtd->publicId,$decldtd->systemId);
    if(!$dtd){
      die "Failed to load DTD ".$decldtd->publicId." at ".$decldtd->systemId; }
    eval { $$self{document}->validate($dtd); };
    if($@){
      die "Error during DTD validation  (".$decldtd->systemId."):\n$@"
	."\nEither fix the source document, or use the --novalidate option\n"; }}
  else {			# Nothing found to validate with
    warn "No Schema or DTD found for this document";  }
}

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
  if(!$$self{namespaces}{$prefix} || ($$self{namespaces}{$prefix} ne $nsuri)
    || (($self->getDocumentElement->lookupNamespacePrefix($nsuri)||'') ne $prefix)){
    $$self{namespaces}{$prefix}=$nsuri;
    $$self{namespaceURIs}{$nsuri}=$prefix;
    $XPATH->registerNS($prefix=>$nsuri);
    $self->getDocumentElement->setNamespace($nsuri,$prefix,0); }}

sub getQName {
  my($self,$node)=@_;
  my $nsuri = $node->namespaceURI;
  if(!$nsuri){			# No namespace at all???
    if($node->nodeType == XML_ELEMENT_NODE){
      $node->localname; }
    else {
      undef; }}
  elsif(my $prefix = $$self{namespaceURIs}{$nsuri}){
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

# Note that we're currently ignoring duplicated ids.
# these should only happen from rearrangement and copying of document fragments
# with embedded bits of math in them, which have those XMTok/XMRef pairs.
# If those are the cases, we should end up finding the original id'd item, anyway, right?
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
	  my $value = $$attributes{$key};
	  if($key eq 'xml:id'){	# Ignore duplicated IDs!!!
	    if(!defined $$self{idcache}{$value}){
	      $$self{idcache}{$value} = $new;
	      $new->setAttribute($key, $value); }}
	  elsif($attrprefix && ($attrprefix ne 'xml')){
	    my $attrnsuri = $attrprefix && $$self{namespaces}{$attrprefix};
	    $new->setAttributeNS($attrnsuri,$attrname, $$attributes{$key}); }
	  else {
	    $new->setAttribute($key, $$attributes{$key}); }
	}}
      $self->addNodes($new,@children); }
    elsif((ref $child) =~ /^XML::LibXML::/){
      my $type = $child->nodeType;
      if($type == XML_ELEMENT_NODE){
	my $new = $node->addNewChild($child->namespaceURI,$child->localname);
	foreach my $attr ($child->attributes){
	  my $atype = $attr->nodeType;
	  if($atype == XML_ATTRIBUTE_NODE){
	    my $key = $attr->nodeName;
	    if($key eq 'xml:id'){
	      my $value = $attr->getValue;
	      if(!defined $$self{idcache}{$value}){
		$$self{idcache}{$value} = $new;
		$new->setAttribute($key, $value); }}
	    elsif(my $ns = $attr->namespaceURI){
	      $new->setAttributeNS($ns,$attr->localname,$attr->getValue); }
	    else {
	      $new->setAttribute( $attr->localname,$attr->getValue); }}
	}
	$self->addNodes($new, $child->childNodes); }
      elsif($type == XML_DOCUMENT_FRAG_NODE){
	$self->addNodes($node,$child->childNodes); }
      elsif($type == XML_TEXT_NODE){
	$node->appendTextNode($child->textContent); }
    }
    elsif(ref $child){
      warn "Dont know how to add $child to $node; ignoring"; }
    elsif(defined $child){
      $node->appendTextNode($child); }}}

sub removeNodes {
  my($self,@nodes)=@_;
  foreach my $node (@nodes){
    foreach my $idd ($self->findnodes("//*[\@xml:id]",$node)){
      my $id = $idd->getAttribute('xml:id');
      if(($$self{idcache}{$id}||'') eq $idd){
	delete $$self{idcache}{$id}; }}
    $node->unlinkNode; }}

our @MonthNames=(qw( January February March April May June
		     July August September October November December));
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

  my $root_id = $self->getDocumentElement->getAttribute('xml:id');
  my $doc = $self->new($xmldoc,
		       ($parent_id ? (parent_id=>$parent_id) : ()),
		       ($root_id   ? (split_from_id=>$root_id) : ()),
		       %options); 

  # Copy any processing instructions.
  foreach my $pi ($self->findnodes(".//processing-instruction('latexml')")){
    $doc->getDocument->appendChild($pi->cloneNode); }
  # If new document has no date, try to add one
  $doc->addDate($self);

  # Finally, return the new document.
  $doc; }

sub addDate {
  my($self,$fromdoc)=@_;
  if(!$self->findnodes('ltx:date',$self->getDocumentElement)){
    my @dates;
    #  $fromdoc's document has some, so copy them.
    if($fromdoc && (@dates = $fromdoc->findnodes('ltx:date',$fromdoc->getDocumentElement))){
      $self->addNodes($self->getDocumentElement,@dates); }
    else {
      my ($sec,$min,$hour,$mday,$mon,$year)=localtime(time());
      $self->addNodes($self->getDocumentElement,
		      ['ltx:date',{role=>'creation'},
		       $MonthNames[$mon]." ".$mday.", ".(1900+$year)]); }}}

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
  my $ref = ['ltx:ref',{idref=>$id,class=>$direction,show=>'fulltitle'}];
  if(my $nav = $self->findnode('//ltx:navigation')){
    $self->addNodes($nav,$ref); }
  else {
    $self->addNodes($self->getDocumentElement, ['ltx:navigation',{},$ref]);}}

#======================================================================
# Support for ID's

sub findNodeByID {
  my($self,$id)=@_;
  $$self{idcache}{$id}; }

sub realizeXMNode {
  my($self,$node)=@_;
  if($self->getQName($node) eq 'ltx:XMRef'){
    my $realnode = $self->findNodeByID($node->getAttribute('idref'));
    return $self->Error("Cannot find a node with xml:id=".$node->getAttribute('idref'))
      unless $realnode;
    $realnode; }
  else {
    $node; }}

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

