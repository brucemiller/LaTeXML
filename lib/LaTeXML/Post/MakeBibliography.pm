# /=====================================================================\ #
# |  LaTeXML::Post::MakeBibliography                                    | #
# | Make an bibliography from cited entries                             | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Post::MakeBibliography;
use strict;
use LaTeXML::Util::Pathname;
use LaTeXML::Common::XML;
use charnames qw(:full);
use base qw(LaTeXML::Post::Collector);

our %FMT_SPEC;

# Options:
#   bibliographies : list of xml file names containing bibliographies (from bibtex)
#   split  : whether the split into separate pages by initial.
# NOTE:
#  Ultimately needs to respond to the desired bibligraphic style
#     Currently set up primarily for author-year
#     What about numerical citations? (how would we split the bib?)
#     But we should presumably encode a number anyway...
sub new {
  my($class,%options)=@_;
  my $self = $class->SUPER::new(%options);
  $$self{split}    = $options{split};
  $$self{bibliographies} = $options{bibliographies};
  $self; }

sub process {
  my($self,$doc)=@_;

  if(my $bib = $doc->findnode('//ltx:bibliography')){
    return $doc if $doc->findnodes('//ltx:bibitem',$bib); # Already populated?
    local $LaTeXML::Post::MakeBibliography::NUMBER = 0;
    my $entries = $self->getBibEntries($doc);

    # Remove any bibentry's (these should have been converted to bibitems)
    $doc->removeNodes($doc->findnodes('//ltx:bibentry'));
    foreach my $biblist ($doc->findnodes('//ltx:biblist')){
      $doc->removeNodes($biblist)
	unless grep($_->nodeType == XML_ELEMENT_NODE, $biblist->childNodes); }

    if($$self{split}){
      # Separate by initial.
      my $split = {};
      foreach my $sortkey (keys %$entries){
	my $entry = $$entries{$sortkey};
	$$split{$$entry{initial}}{$sortkey} = $entry; }
      map($self->rescan($_),
	  $self->makeSubCollectionDocuments($doc,$bib,
					    map( ($_=>$self->makeBibliographyList($doc,$$split{$_})),
						 keys %$split))); }
    else {
      $doc->addNodes($bib,$self->makeBibliographyList($doc,$entries));
      $self->rescan($doc); }}
  else {
    $doc; }}

# ================================================================================
# Get all cited bibentries from the requested bibliography files.
# Sort (cited) bibentries on author+year+title, [NOT on the key!!!]
# and then check whether author+year is unique!!!
# Returns a list of hashes containing:
#  bibkey : the bibliographic entry's key
#  bibentry : the bibentry node
#  citations : array of bib keys that are cited somewhere within this bibentry
#  referrers : array of ID's of places that refer to this bibentry
#  suffix    : a,b... if adjacent author/year are identical.

sub getBibEntries {
  my($self,$doc)=@_;

  # First, scan the bib files for all ltx:bibentry's, (hash key is bibkey)
  # Also, record the citations from each bibentry to others.
  my %entries=();
  foreach my $bibfile (@{$$self{bibliographies}}){
    my $bibdoc = $doc->newFromFile($bibfile);
    foreach my $bibentry ($bibdoc->findnodes('//ltx:bibentry')){
      my $bibkey = $bibentry->getAttribute('key');
      $entries{$bibkey}{bibkey}   = $bibkey; 
      $entries{$bibkey}{bibentry} = $bibentry;
      $entries{$bibkey}{citations}= [map(split(',',$_->value),
					 $bibdoc->findnodes('.//@bibrefs',$bibentry))];
    }}
  # Now, collect all bibkeys that were cited in other documents (NOT the bibliography)
  # And note any referrers to them (also only those outside the bib)
  my @queue = ();
  foreach my $dbkey ($$self{db}->getKeys){
    if($dbkey =~ /^BIBLABEL:(.*)$/){
      my $bibkey = $1;
      if(my $referrers = $$self{db}->lookup($dbkey)->getValue('referrers')){
	my $e;
	foreach my $refr (keys %$referrers){
	  if(($e=$$self{db}->lookup("ID:$refr")) && (($e->getValue('type')||'') ne 'ltx:bibitem')){
	    $entries{$bibkey}{referrers}{$refr} = 1; }}
	push(@queue,$bibkey); }}}
  # For each bibkey in the queue, complete and include the entry
  # And add any keys cited from within each include entry
  my %seen_keys = ();
  my %missing_keys = ();
  my $included = {};		# included entries (hash key is sortkey)
  while(my $bibkey = shift(@queue)){
    next if $seen_keys{$bibkey}; # Done already.
    $seen_keys{$bibkey}=1;
    if(my $bibentry = $entries{$bibkey}{bibentry}){
      my $entry = $entries{$bibkey};
      # Extract names, year and title from bibentry.
      my $names='';
      if(my $n = $doc->findnode('ltx:bib-key',$bibentry)){
	$names = $n->textContent; }
      elsif(my @ns = $doc->findnodes('ltx:bib-name[@role="author"]/ltx:surname'
				     .' | ltx:bib-name[@role="editor"]/ltx:surname',
				     $bibentry)){
	if(@ns > 2){    $names = $ns[0]->textContent .' et al'; }
	elsif(@ns > 1){ $names = $ns[0]->textContent .' and '. $ns[1]->textContent; }
	else          { $names = $ns[0]->textContent; }}
      elsif(my $t = $doc->findnode('ltx:bib-title',$bibentry)){
	$names = $t->textContent; }
      my $date = $doc->findnode('ltx:bib-date[@role="publication"] | ltx:bib-type',$bibentry);
      my $title =$doc->findnode('ltx:bib-title',$bibentry);
      $date  = ($date  ? $date->textContent  : '');
      $title = ($title ? $title->textContent : '');
      $$entry{ay}      = "$names.$date";
      $$entry{initial} = $doc->initial($names,1);
      # Include this entry keyed using a sortkey.
      $$included{lc(join('.',$names,$date,$title,$bibkey))} = $entry;
      # And, since we're including this entry, we'll need to include any that it cites!
      push(@queue,@{$$entry{citations}}) if $$entry{citations}; }
    else {
      $missing_keys{$bibkey}=1; }}
  # Now that we know which entries will be included, note their citations as bibreferrers.
  foreach my $sortkey (keys %$included){
    my $entry  = $$included{$sortkey};
    my $bibkey = $$entry{bibkey};
    map( $entries{$_}{bibreferrers}{$bibkey}=1, @{$$entry{citations}}); }

  $self->Progress($doc,(scalar keys %entries)." bibentries, ".(scalar keys %$included)." cited");
  $self->Progress($doc,"Missing bibkeys ".join(', ',sort keys %missing_keys)) if keys %missing_keys;

  # Finally, sort the bibentries according to author+year+title+bibkey
  # If any neighboring entries have same author+year, set a suffix: a,b,...
  my @sortkeys = sort keys %$included;
  while(my $sortkey = shift(@sortkeys)){
    my $i=0;
    while(@sortkeys && ($$included{$sortkey}{ay} eq $$included{$sortkeys[0]}{ay})){
      $$included{$sortkey}{suffix}='a';
      $$included{$sortkeys[0]}{suffix} = chr(ord('a')+(++$i));
      shift(@sortkeys); }}
  $included; }

# ================================================================================
# Convert hash of bibentry(s) into biblist of bibitem(s)

sub makeBibliographyList {
  my($self,$doc,$entries)=@_;
  local $LaTeXML::Post::MakeBibliography::DOCUMENT = $doc;
  ['ltx:biblist',{},
   map($self->formatBibEntry($doc,$$entries{$_}), sort keys %$entries)]; }

sub getQName {
  $LaTeXML::Post::MakeBibliography::DOCUMENT->getQName(@_); }

# ================================================================================
sub formatBibEntry {
  my($self,$doc,$entry)=@_;
  my $bibentry = $$entry{bibentry};
  my $id   = $bibentry->getAttribute('xml:id');
  my $key  = $bibentry->getAttribute('key');
  my $type = $bibentry->getAttribute('type');
  my @blockspecs = @{ $FMT_SPEC{$type} || [] };

  local $LaTeXML::Post::MakeBibliography::DOCUMENT = $doc;
  local $LaTeXML::Post::MakeBibliography::SUFFIX = $$entry{suffix};
  my $number = ++$LaTeXML::Post::MakeBibliography::NUMBER;

  # NOTE: $id may have already been associated with the bibentry
  # Break the association so it associates with the bibitem
  delete $$doc{idcache}{$id};
  warn "\nNo formatting specification for bibentry of type $type" unless @blockspecs;

  #------------------------------
  # Format the bibtag's
  my @tags=();
  push(@tags,['ltx:bibtag',{role=>'number'},$number]); # number tag

  # Set up authors and fullauthors tags
  my @names = $doc->findnodes('ltx:bib-name[@role="author"]/ltx:surname',$bibentry);
  @names = $doc->findnodes('ltx:bib-name[@role="editor"]/ltx:surname',$bibentry) unless @names;
  if(@names > 2){
    push(@tags,['ltx:bibtag',{role=>'authors'},
		$names[0]->childNodes,['ltx:emph',{},' et al.']]);
    my @fnames=();
    foreach my $n (@names[0..$#names-1]){
      push(@fnames,$n->childNodes,', '); }
    push(@tags,['ltx:bibtag',{role=>'fullauthors'},@fnames,'and ',$names[-1]->childNodes]); }
  elsif(@names > 1){
    push(@tags,['ltx:bibtag',{role=>'authors'},
		$names[0]->childNodes,' and ',$names[1]->childNodes]); }
  elsif(@names){
    push(@tags,['ltx:bibtag',{role=>'authors'},$names[0]->childNodes]); }

  # Put a key tag, to use in place of authors if needed (esp for software, websites, etc)
  my $keytag;
  if($keytag = $doc->findnode('ltx:bib-key',$bibentry)){
    push(@tags,['ltx:bibtag',{role=>'key'},$keytag->childNodes]); }

  my @year=();
  if(my $date = $doc->findnode('ltx:bib-date[@role="publication"]',$bibentry)){
    @year = $date->childNodes;
    if(my $datetext = $date->textContent){
      if($datetext=~/^(\d\d\d\d)/){ # Extract 4 digit year, if any
	@year = ($1); }}
    push(@tags,['ltx:bibtag',{role=>'year'},@year,($$entry{suffix} ||'')]); }

  # Store a type tag, to use in place of year, if needed (esp for software, ...)
  my $typetag;
  if($typetag = $doc->findnode('ltx:bib-type',$bibentry)){
    push(@tags,['ltx:bibtag',{role=>'bibtype'},$typetag->childNodes]); }

  # put in the title
  if(my $title = $doc->findnode('ltx:bib-title',$bibentry)){
    push(@tags,['ltx:bibtag',{role=>'title'},$title->childNodes]); }

  # And finally, the refnum; we need to know the desired citation style!
  # This is screwy!!!
  my $style = 'authoryear';	# else 'number'
  $style = 'number' unless (@names || $keytag) && (@year || $typetag);
  if($style eq 'number'){
    push(@tags,['ltx:bibtag',{role=>'refnum'},$number]); }
  else {
    shift(@blockspecs);		# Skip redundant 1st block!!
    my @rfnames;
    if(my @authors = $doc->findnodes('ltx:bib-name[@role="author"]',$bibentry)){
      @rfnames = do_authors(@authors); }
    elsif(my @editors = $doc->findnodes('ltx:bib-name[@role="editor"]',$bibentry)){
      @rfnames = do_editorsA(@editors); }
    else {
      @rfnames = $keytag->childNodes; }
    my @rfyear  = (@year  ? @year  : ($typetag ? $typetag->childNodes : ()));

    push(@tags,['ltx:bibtag',{role=>'refnum'},@rfnames,' (',@rfyear,')']); }

  #------------------------------
  # Format the data in blocks, with the first being bib-label, rest bibblock.
  my @blocks = ();
  foreach my $blockspec (@blockspecs){
    my @x =();
    foreach my $row (@$blockspec){
      my($xpath,$punct,$pre,$op,$post)=@$row;
      my @nodes = ($xpath eq 'true' ? () : $doc->findnodes($xpath,$bibentry));
      next unless @nodes || ($xpath eq 'true');
      push(@x,$punct) if $punct && @x;
      push(@x,$pre) if $pre;
      push(@x,&$op(map($_->cloneNode(1),@nodes))) if $op;
      push(@x,$post) if $post; }
    push(@blocks,['ltx:bibblock',{},@x]) if @x;
  }
  # Add a Cited by block.
  my @citedby=map(['ltx:ref',{idref=>$_}], sort keys %{$$entry{referrers}});
  push(@citedby,['ltx:bibref',{bibrefs=>join(',',sort keys %{$$entry{bibreferrers}}),
			       show=>'refnum'}])
    if $$entry{bibreferrers};
  push(@blocks,['ltx:bibblock',{},"Cited by: ",$doc->conjoin(', ',@citedby)]);

  ['ltx:bibitem',{'xml:id'=>$id, key=>$key, type=>$type},
   @tags,
   @blocks]; }

# ================================================================================
# Formatting aids.
sub do_any  { @_; }

# Stuff for Author(s) & Editor(s)
sub do_name {
  my($node)=@_;
  # NOTE: This should be a formatting option; use initials or full first names.
  my $first = $LaTeXML::Post::MakeBibliography::DOCUMENT->findnode('ltx:givenname',$node);
  if($first){			# && use initials
    $first = join('',map( (/\.$/ ? "$_ " : (/^(.)/ ? "$1. " : '')),
			  split(/\s/,$first->textContent))); }
  else {
    $first = (); }
  my $sur = $LaTeXML::Post::MakeBibliography::DOCUMENT->findnode('ltx:surname',$node);
# Why, oh Why do we need the _extra_ cloneNode ???
  ( $first,$sur->cloneNode(1)->childNodes); }

sub do_names {
  my(@names)=@_;
  my @stuff=();
  while(my $name = shift(@names)){
    push(@stuff, (@names ? ', ' : ' and ')) if @stuff;
    push(@stuff, do_name($name)); }
  @stuff; }

sub do_names_short {
  my(@names)=@_;
  if(@names > 2){
    ($names[0]->childNodes,' ',['ltx:emph',{},'et al.']); }
  elsif(@names > 1){
  ($names[0]->childNodes,' and ',$names[1]->childNodes); }
  elsif(@names){
    ($names[0]->childNodes); }}

sub do_authors { do_names(@_); }
sub do_editorsA {		# Should be used in citation tags?
  my @n = do_names(@_);
  if(scalar(@_)>1) { push(@n," (Eds.)"); }
  elsif(scalar(@_)){ push(@n," (Ed.)"); }
  @n; }
sub do_editorsB {
  my @x = do_names(@_);
  if(scalar(@_)>1) { push(@x," Eds."); }
  elsif(scalar(@_)){ push(@x," Ed."); }
  (@x ? ("(",@x,")") : ()); }

sub do_year { ('(',@_,@LaTeXML::Post::MakeBibliography::SUFFIX,')'); }
sub do_type { ('(',@_,')'); }

# Other fields.
sub do_title { (['ltx:text',{font=>'italic'},@_]); }
sub do_bold  { (['ltx:text',{font=>'bold'},@_]); }
sub do_edition { (@_," edition"); } # If a number, should convert to cardinal!
sub do_thesis_type { @_; }
sub do_pages { (" pp.\N{NO-BREAK SPACE}",@_); } # Non breaking space

our $LINKS;
#BEGIN{
    $LINKS = "ltx:bib-links | ltx:bib-review | ltx:bib-identifier | ltx:bib-url";
#}

sub do_links {
  my(@nodes)=@_;
  my @links=();

  foreach my $node (@nodes){
    my $scheme = $node->getAttribute('scheme') || '';
    my $href   = $node->getAttribute('href');
    my $tag = getQName($node);
    if(($tag eq 'ltx:bib-identifier') || ($tag eq 'ltx:bib-review')){
      if($href){
	push(@links,['ltx:ref',{href=>$href, class=>"$scheme externallink"},
		     map($_->cloneNode(1),$node->childNodes)]); }
      else {
	push(@links,['ltx:text',{class=>"$scheme externallink"},
		     map($_->cloneNode(1),$node->childNodes)]); }}
    elsif($tag eq 'ltx:bib-links'){
      push(@links,['ltx:text',{class=>"externallink"},map($_->cloneNode(1),$node->childNodes)]); }
    elsif($tag eq 'ltx:bib-url'         ){
      push(@links,['ltx:ref',{href=>$href, class=>'externallink'},
		   map($_->cloneNode(1),$node->childNodes)]); }}

  @links = map((",\n",$_),@links); # non-string join()
  @links[1..$#links]; }

# ================================================================================
# Formatting specifications.
# Adpated from amsrefs.sty
#BEGIN{

# For each bibliographic type, 
# the specification is an array representing each bibblock.
# Each biblock is an array of field specifications.
# Each field specification is:
#   [xpath, punct, prestring, operatorname, poststring]
# NOTE That the first block is only shown for numeric style,
# since otherwise athors will already be shown in the bibtag@refnum!!!
# Ugh...

%FMT_SPEC=
  (article=> [[['ltx:bib-name[@role="author"]'   , ''  , '', \&do_authors,''],
	       ['ltx:bib-date[@role="publication"]'         , ''  , '', \&do_year,'']],
	      [['ltx:bib-title'    , ''  , '', \&do_title,',']],
	      [['ltx:bib-part[@role="part"]'     , ''  , '', \&do_any,''],
	       ['ltx:bib-related/ltx:bib-title'  , ', ', '', \&do_any,''],
	       ['ltx:bib-part[@role="volume"]'   , ' ' , '', \&do_bold,''],
	       ['ltx:bib-part[@role="number"]'   , ' ' , '(', \&do_any,')'],
	       ['ltx:bib-status'   , ', ', '(', \&do_any,')'],
	       ['ltx:bib-part[@role="pages"]'    , ', ', '', \&do_pages,''],
	       ['ltx:bib-language' , ' ' , '(', \&do_any,')'],
	       ['true'             , '.']],
	      [['ltx:bib-note'     ,'', "Note: ",\&do_any,'']],
	      [[$LINKS             ,'', 'External Links: ',\&do_links,'']]],
   book=>   [ [['ltx:bib-name[@role="author"]'   , ''  , '', \&do_authors,''],
	       ['ltx:bib-name[@role="editor"]'   , ''  , '', \&maybe_editorsA,''],
	       ['ltx:bib-date[@role="publication"]'         , ''  , '', \&do_year,'']],
	      [['ltx:bib-title'    , ''  , '', \&do_title,',']],
	      [['ltx:bib-type'     , ''  , '', \&do_any,''],
	       ['ltx:bib-edition'  , ', ', '', \&do_edition,''],
	       ['ltx:bib-part[@role="series"]'   , ', ', '', \&do_any,''],
	       ['ltx:bib-part[@role="volume"]'   , ', ', 'Vol. ', \&do_any,''],
	       ['ltx:bib-part[@role="part"]'     , ', ', 'Part ', \&do_any,''],
	       ['ltx:bib-publisher', ', ', ' ', \&do_any,''],
	       ['ltx:bib-organization',', ',' ', \&do_any,''],
	       ['ltx:bib-place'    , ', ', '', \&do_any,''],
	       ['ltx:bib-status'   , ' ' , '(',\&do_any,')'],
	       ['ltx:bib-language' , ' ' , '(',\&do_any,')'],
	       ['true','.']],
	      [['ltx:bib-note'     , ''  , "Note: ",\&do_any,'']],
	      [[$LINKS             , ''  , 'External Links: ',\&do_links,'']]],
   'incollection'=>[
	      [['ltx:bib-name[@role="author"]'   , ''  , '', \&do_authors,''],
	       ['ltx:bib-date[@role="publication"]'         , ''  , '', \&do_year,'']],
	      [['ltx:bib-title'    , ''  , '', \&do_title,',']],
	      [['ltx:bib-type'     , ''  , '', \&do_any,''],
	       ['ltx:bib-related[@type="book"]/ltx:bib-title', ' ' , 'in ', \&do_title,',']],
	      [['ltx:bib-edition'  , ''  , '', \&do_edition,''],
	       ['ltx:bib-name[@role="editor"]'   , ', ', '', \&do_editorsB,''],
	       ['ltx:bib-related/ltx:bib-part[@role="series"]', ', ', '', \&do_any,''],
	       ['ltx:bib-related/ltx:bib-part[@role="volume"]', ', ', 'Vol. ',\&do_any,''],
	       ['ltx:bib-related/ltx:bib-part[@role="part"]', ', ', 'Part ',\&do_any,''],
	       ['ltx:bib-publisher', ', ', ' ', \&do_any,''],
	       ['ltx:bib-organization',', ','', \&do_any,''],
	       ['ltx:bib-place'    , ', ', '', \&do_any,''],
	       ['ltx:bib-part[@role="pages"]'    , ', ', '', \&do_pages,''],
	       ['ltx:bib-status'   , ' ' , '(',\&do_any,')'],
	       ['ltx:bib-language' , ' ' , '(', \&do_any,')'],
	       ['true','.']],
	      [['ltx:bib-note'     , ''  , "Note: ",\&do_any,'']],
	      [[$LINKS             , ''  , 'External Links: ',\&do_links,'']]],
   report=>[  [['ltx:bib-name[@role="author"]'   , ''  , '', \&do_authors,''],
	       ['ltx:bib-name[@role="editor"]'   , ''  , '', \&maybe_editorsA,''],
	       ['ltx:bib-date[@role="publication"]'         , ''  , '', \&do_year,'']],
	      [['ltx:bib-title'    , ''  , '', \&do_title,',']],
	      [['ltx:bib-type'     , ''  , '', \&do_any,'']],
	      [['ltx:bib-part[@role="number"]'   , ''  , 'Technical Report ',\&do_any,''],
	       ['ltx:bib-part[@role="series"]'   , ', ', '',\&do_any,''],
	       ['ltx:bib-part[@role="volume"]'   , ', ', 'Vol. ',\&do_any,''],
	       ['ltx:bib-part[@role="part"]'     , ', ', 'Part ',\&do_any,''],
	       ['ltx:bib-publisher', ', ', ' ',\&do_any,''],
	       ['ltx:bib-organization',', ', ' ',\&do_any,''],
	       ['ltx:bib-place'    , ', ', ' ',\&do_any,''],
	       ['ltx:bib-status'   , ', ', '(',\&do_any,')'],
	       ['ltx:bib-language' , ' ' , '(',\&do_any,')'],
	       ['true','.']],
	      [['ltx:bib-note'     , ''  , "Note: ",\&do_any,'']],
	      [[$LINKS             , ''  , 'External Links: ',\&do_links,'']]],
   thesis=>[  [['ltx:bib-name[@role="author"]'   , ''  , '', \&do_authors,''],
	       ['ltx:bib-name[@role="editor"]'   , ''  , '', \&maybe_editorsA,''],
	       ['ltx:bib-date[@role="publication"]'         , ''  , '', \&do_year,'']],
	      [['ltx:bib-title'    , ''  , '', \&do_title,',']],
	      [['ltx:bib-type'     , ' ' , '',\&do_thesis_type,''],
	       ['ltx:bib-part[@role="part"]'     , ', ', 'Part ',\&do_any,''],
	       ['ltx:bib-publisher',', ','',\&do_any,''],
	       ['ltx:bib-organization',', ','',\&do_any,''],
	       ['ltx:bib-place'    , ', ', '',\&do_any,''],
	       ['ltx:bib-status'   , ', ', '(',\&do_any,')'],
	       ['ltx:bib-language' , ', ', '(',\&do_any,')'],
	       ['true','.']],
	      [['ltx:bib-note'     , ''  , "Note: ",\&do_any,'']],
	      [[$LINKS             , ''  , 'External Links: ',\&do_links,'']]],
   website=>[ [['ltx:title'        , ''  , '', \&do_any,''],
	       ['true'             , ''  , '', '(Website)']],
##	      [['ltx:bib-url',     '', '', sub { (['a',{href=>$_[0]->textContent},'Website']); },'']],
	      [['ltx:bib-organization',', ',' ', \&do_any,''],
	       ['ltx:bib-place'    , ', ', '', \&do_any,''],
	       ['true','.']],
	      [['ltx:bib-note'     , ''  , "Note: ",\&do_any,'']],
	      [[$LINKS             , ''  , 'External Links: ',\&do_links,'']]],
   software=>[[['ltx:bib-key'       , ''  , '', \&do_any,''],
	       ['ltx:bib-type'      , ''  , '', \&do_type,'']],
	      [['ltx:bib-title'     ,  ''  , '', \&do_any, '']],
	      [['ltx:bib-organization',', ',' ', \&do_any,''],
	       ['ltx:bib-place'    , ', ', '', \&do_any,''],
	       ['true','.']],
	      [['ltx:bib-note'  ,'', "Note: ",\&do_any,'']],
	      [[$LINKS          ,'','External Links: ',\&do_links,'']]],

);

$FMT_SPEC{periodical}  = $FMT_SPEC{book};
$FMT_SPEC{collection}  = $FMT_SPEC{book};
$FMT_SPEC{proceedings} = $FMT_SPEC{book};
$FMT_SPEC{manual}      = $FMT_SPEC{book};
$FMT_SPEC{misc}        = $FMT_SPEC{book};
$FMT_SPEC{unpublished} = $FMT_SPEC{book};
$FMT_SPEC{'collection.article'}  = $FMT_SPEC{incollection};
$FMT_SPEC{'proceedings.article'} = $FMT_SPEC{incollection};
$FMT_SPEC{inproceedings}         = $FMT_SPEC{incollection};
$FMT_SPEC{inbook}                = $FMT_SPEC{incollection};
$FMT_SPEC{techreport}  = $FMT_SPEC{report};

#}

# ================================================================================
1;

