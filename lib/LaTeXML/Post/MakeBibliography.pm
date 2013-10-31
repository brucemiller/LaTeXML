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
use LaTeXML::Post;
use base qw(LaTeXML::Post::Collector);

our %FMT_SPEC;
our @META_BLOCK;

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

sub toProcess { $_[1]->findnode('//ltx:bibliography'); }

sub process {
  my($self,$doc,$bib)=@_;

  my @bib = ($doc);
  return $doc if $doc->findnodes('//ltx:bibitem',$bib); # Already populated?

  local $LaTeXML::Post::MakeBibliography::NUMBER = 0;
  local %LaTeXML::Post::MakeBibliography::STYLE =
    ( map( ($_=>$bib->getAttribute($_)), qw(bibstyle citestyle sort)) );

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
    @bib = map($self->rescan($_),
	       $self->makeSubCollectionDocuments($doc,$bib,
			 map( ($_=>$self->makeBibliographyList($doc,$_,$$split{$_})),
			      keys %$split))); }
  else {
    $doc->addNodes($bib,$self->makeBibliographyList($doc,undef,$entries));
    @bib = ($self->rescan($doc)); }
  @bib; }

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
      my $bibid  = $bibentry->getAttribute('xml:id');
      $entries{$bibkey}{bibkey}   = $bibkey; 
      $entries{$bibkey}{bibentry} = $bibentry;
      $entries{$bibkey}{citations}= [grep($_,map(split(',',$_->value),
						 $bibdoc->findnodes('.//@bibrefs',$bibentry)))];
      # Also, register the key with the DB, if the bibliography hasn't already been scanned.
      $$self{db}->register("BIBLABEL:$bibkey",id=>$bibid);
    }}
  # Now, collect all bibkeys that were cited in other documents (NOT the bibliography)
  # And note any referrers to them (also only those outside the bib)
  my $citestar = $$self{db}->lookup('BIBLABEL:*');

  my @queue = ();
  foreach my $dbkey ($$self{db}->getKeys){
    if($dbkey =~ /^BIBLABEL:(.*)$/){
      my $bibkey = $1;
      if(my $referrers = $$self{db}->lookup($dbkey)->getValue('referrers')){
	my $e;
	foreach my $refr (keys %$referrers){
	  my($rid,$e,$t) = ($refr,undef,undef);
	  while($rid && ($e=$$self{db}->lookup("ID:$rid")) && (($t=($e->getValue('type')||'')) ne 'ltx:bibitem')){
	    $rid = $e->getValue('parent'); }
	  if($t ne 'ltx:bibitem'){
	    $entries{$bibkey}{referrers}{$refr} = 1; }}
	push(@queue,$bibkey) if keys %{$entries{$bibkey}{referrers}}; }
      elsif($citestar){		# If \cite{*} include all of them.
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
      my $sortnames='';
      my @names =$doc->findnodes('ltx:bib-name[@role="author"]',$bibentry);
      @names =$doc->findnodes('ltx:bib-name[@role="editor"]',$bibentry) unless @names;
      if(my $n = $doc->findnode('ltx:bib-key',$bibentry)){
	$sortnames = $names = $n->textContent; }
      elsif(scalar(@names)){
	$sortnames = join(' ',map(getNameText($doc,$_),@names));
	my @ns = map($_ && $_->textContent, map($doc->findnodes('ltx:surname',$_), @names));
	if(@ns > 2){    $names = $ns[0] .' et al'; }
	elsif(@ns > 1){ $names = $ns[0] .' and '. $ns[1]; }
	else          { $names = $ns[0]; }}
      elsif(my $t = $doc->findnode('ltx:bib-title',$bibentry)){
	$sortnames = $names = $t->textContent; }
      my $date = $doc->findnode('ltx:bib-date[@role="publication"] | ltx:bib-type',$bibentry);
      my $title =$doc->findnode('ltx:bib-title',$bibentry);
      $date  = ($date  ? $date->textContent  : '');
      $title = ($title ? $title->textContent : '');
      $$entry{ay}      = "$names.$date";
      $$entry{initial} = $doc->initial($names,1);
      # Include this entry keyed using a sortkey.
      $$included{lc(join('.',$sortnames,$date,$title,$bibkey))} = $entry;
      # And, since we're including this entry, we'll need to include any that it cites!
      push(@queue,@{$$entry{citations}}) if $$entry{citations}; }
    else {
      $missing_keys{$bibkey}=1; }}
  # Now that we know which entries will be included, note their citations as bibreferrers.
  foreach my $sortkey (keys %$included){
    my $entry  = $$included{$sortkey};
    my $bibkey = $$entry{bibkey};
    map( $entries{$_}{bibreferrers}{$bibkey}=1, @{$$entry{citations}}); }

  NoteProgress(" [".(scalar keys %entries)." bibentries, ".(scalar keys %$included)." cited]");
  Warn('expected','bibkeys',undef,
       "Missing bibkeys ".join(', ',sort keys %missing_keys)) if keys %missing_keys;

  # Finally, sort the bibentries according to author+year+title+bibkey
  # If any neighboring entries have same author+year, set a suffix: a,b,...
  # Actually, it isn't so much if they are adjacent; if author+year isn't unique, need a suffix
  my @sortkeys = sort keys %$included;
  my %suffixes=();
  while(my $sortkey = shift(@sortkeys)){
#    my $i=0;
#    while(@sortkeys && ($$included{$sortkey}{ay} eq $$included{$sortkeys[0]}{ay})){
#      $$included{$sortkey}{suffix}='a';
#      $$included{$sortkeys[0]}{suffix} = chr(ord('a')+(++$i));
#      shift(@sortkeys); }
    my $entry = $$included{$sortkey};
    my $ay = $$entry{ay};
    if(defined $suffixes{$ay}){
      my $prev = $suffixes{$ay};
      if(!$$prev{suffix}){
	$$prev{suffix} = 'a'; }
      $$entry{suffix} = chr(ord($$prev{suffix})+1); }
      $suffixes{$ay}=$entry;
  # HACKERY: AFTER all the sorting have been done, remove <ERROR role="sort"> nodes.
  # These may have been inserted to alter sorting, eg \NOOP{a}...
    foreach my $sortnode ($doc->findnodes('//ltx:ERROR[@class="sort"]',$$entry{bibentry})){
      $sortnode->parentNode->removeChild($sortnode); }
  }
  $included; }

sub getNameText {
  my($doc,$namenode)=@_;
  my $surname = $doc->findnodes('ltx:surname',$namenode);
  my $givenname = $doc->findnodes('ltx:givenname',$namenode);
  ($surname && $givenname ? $surname.' '.$givenname : $surname || $givenname); }

# ================================================================================
# Convert hash of bibentry(s) into biblist of bibitem(s)

sub makeBibliographyList {
  my($self,$doc,$initial,$entries)=@_;
  my $id = $doc->getDocumentElement->getAttribute('xml:id') || 'bib';
  $id .= ".L1";
  $id .= ".$initial" if $initial;
  ['ltx:biblist',{'xml:id'=>$id},
   map($self->formatBibEntry($doc,$$entries{$_}), sort keys %$entries)]; }

# ================================================================================
sub formatBibEntry {
  my($self,$doc,$entry)=@_;
  my $bibentry = $$entry{bibentry};
  my $id   = $bibentry->getAttribute('xml:id');
  my $key  = $bibentry->getAttribute('key');
  my $type = $bibentry->getAttribute('type');
  my @blockspecs = @{ $FMT_SPEC{$type} || [] };

  local $LaTeXML::Post::MakeBibliography::SUFFIX = $$entry{suffix};
  my $number = ++$LaTeXML::Post::MakeBibliography::NUMBER;

  Warn('unexpected',$type,undef,
       "No formatting specification for bibentry of type '$type'") unless @blockspecs;

  #------------------------------
  # Format the bibtag's
  my @tags=();
  push(@tags,['ltx:bibtag',{role=>'number', class=>'ltx_bib_number'},$number]); # number tag

  # Set up authors and fullauthors tags
  my @names = $doc->findnodes('ltx:bib-name[@role="author"]/ltx:surname',$bibentry);
  @names = $doc->findnodes('ltx:bib-name[@role="editor"]/ltx:surname',$bibentry) unless @names;
  if(@names > 2){
    push(@tags,['ltx:bibtag',{role=>'authors', class=>'ltx_bib_author'},
		$doc->cloneNodes($names[0]->childNodes),
                ['ltx:text',{class=>'ltx_bib_etal'},' et al.']]);
    my @fnames=();
    foreach my $n (@names[0..$#names-1]){
      push(@fnames,$n->childNodes,', '); }
    push(@tags,['ltx:bibtag',{role=>'fullauthors',class=>'ltx_bib_author'},
		$doc->cloneNodes(@fnames),
		' and ',$doc->cloneNodes($names[-1]->childNodes)]); }
  elsif(@names > 1){
    push(@tags,['ltx:bibtag',{role=>'authors',class=>'ltx_bib_author'},
		$doc->cloneNodes($names[0]->childNodes),
		' and ',$doc->cloneNodes($names[1]->childNodes)]); }
  elsif(@names){
    push(@tags,['ltx:bibtag',{role=>'authors',class=>'ltx_bib_author'},
		$doc->cloneNodes($names[0]->childNodes)]); }

  # Put a key tag, to use in place of authors if needed (esp for software, websites, etc)
  my $keytag;
  if($keytag = $doc->findnode('ltx:bib-key',$bibentry)){
    push(@tags,['ltx:bibtag',{role=>'key',class=>'ltx_bib_key'},
		$doc->cloneNodes($keytag->childNodes)]); }

  my @year=();
  if(my $date = $doc->findnode('ltx:bib-date[@role="publication"]',$bibentry)){
    @year = $date->childNodes;
    if(my $datetext = $date->textContent){
      if($datetext=~/^(\d\d\d\d)/){ # Extract 4 digit year, if any
	@year = ($1); }}
    push(@tags,['ltx:bibtag',{role=>'year',class=>'ltx_bib_year'},
		$doc->cloneNodes(@year),($$entry{suffix} ||'')]); }

  # Store a type tag, to use in place of year, if needed (esp for software, ...)
  my $typetag;
  if($typetag = $doc->findnode('ltx:bib-type',$bibentry)){
    push(@tags,['ltx:bibtag',{role=>'bibtype',class=>'ltx_bib_type'},
		$doc->cloneNodes($typetag->childNodes)]); }

  # put in the title
  if(my $title = $doc->findnode('ltx:bib-title',$bibentry)){
    push(@tags,['ltx:bibtag',{role=>'title',class=>'ltx_bib_title'},
		$doc->cloneNodes($title->childNodes)]); }

  # And finally, the refnum; we need to know the desired citation style!
  # This is screwy!!!
##  my $style = 'authoryear';	# else 'number'
  # AND OF COURSE, we need to know the key before we know the suffix!!!
  my $style = $LaTeXML::Post::MakeBibliography::STYLE{citestyle} || 'numbers';
  $style = 'numbers' unless (@names || $keytag) && (@year || $typetag);
  if($style eq 'numbers'){
    push(@tags,['ltx:bibtag',{role=>'refnum',class=>'ltx_bib_key',open=>'[',close=>']'},$number]); }
  elsif($style eq 'AY'){
    my @rfnames;
    if(my @authors = $doc->findnodes('ltx:bib-name[@role="author"]',$bibentry)){
      @rfnames = @authors; }
    elsif(my @editors = $doc->findnodes('ltx:bib-name[@role="editor"]',$bibentry)){
      @rfnames = @editors; }
    else {
      @rfnames = $keytag->childNodes; }
    my $aa;
    if(scalar(@rfnames) > 1){
      $aa = join('',map {  substr($_->textContent,0,1); } @rfnames); }
    else {
      $aa = uc(substr($rfnames[0]->textContent,0,3)); }
    my $yy = (@year ? substr(join('',map { (ref $_ ? $_->textContent : $_); } @year),2,2) :'');
    push(@tags,['ltx:bibtag',{role=>'refnum',class=>'ltx_bib_abbrv',open=>'[',close=>']'},
                $aa.$yy.($$entry{suffix}||'')]); }

  else {
    shift(@blockspecs);		# Skip redundant 1st block!!
    my @rfnames;
    if(my @authors = $doc->findnodes('ltx:bib-name[@role="author"]',$bibentry)){
      @rfnames = do_authors(@authors); }
    elsif(my @editors = $doc->findnodes('ltx:bib-name[@role="editor"]',$bibentry)){
      @rfnames = do_editorsA(@editors); }
    else {
      @rfnames = $keytag->childNodes; }
    my @rfyear  = (@year  ? (@year,($$entry{suffix} ||''))
		   : ($typetag ? $typetag->childNodes : ()));
    push(@tags,['ltx:bibtag',{role=>'refnum',class=>'ltx_bib_author-year'},
                $doc->cloneNodes(@rfnames),' (',$doc->cloneNodes(@rfyear),')']); }

  #------------------------------
  # Format the data in blocks, with the first being bib-label, rest bibblock.
  my @blocks = ();
  foreach my $blockspec (@blockspecs){
    my @x =();
    foreach my $row (@$blockspec){
      my($xpath,$punct,$pre,$class,$op,$post)=@$row;
      my $negated = $xpath =~ s/^!\s*//;
      my @nodes = ($xpath eq 'true' ? () : $doc->findnodes($xpath,$bibentry));
      next unless ($xpath eq 'true') || ($negated ? !@nodes : @nodes);
      push(@x,$punct) if $punct && @x;
      push(@x,$pre) if $pre;
      push(@x,['ltx:text',{class=>'ltx_bib_'.$class}, &$op($doc->cloneNodes(@nodes))]) if $op;
      push(@x,$post) if $post; }
    push(@blocks,['ltx:bibblock',{'xml:space'=>'preserve'},@x]) if @x;
  }
  # Add a Cited by block.
##  my @citedby=map(['ltx:ref',{idref=>$_, class=>'ltx_citedby'}], sort keys %{$$entry{referrers}});
##  push(@citedby,['ltx:bibref',{bibrefs=>join(',',sort keys %{$$entry{bibreferrers}}),
##			       show=>'refnum', class=>'ltx_citedby'}])
##    if $$entry{bibreferrers};

  my @citedby=map(['ltx:ref',{idref=>$_ ,show=>'rrefnum'}], sort keys %{$$entry{referrers}});
  push(@citedby,['ltx:bibref',{bibrefs=>join(',',sort keys %{$$entry{bibreferrers}}),show=>'refnum'}])
    if $$entry{bibreferrers};
  push(@blocks,['ltx:bibblock',{class=>'ltx_bib_cited'},
		"Cited by: ",$doc->conjoin(",\n",@citedby),'.']) if @citedby;

  ['ltx:bibitem',{'xml:id'=>$id, key=>$key, type=>$type,class=>"ltx_bib_$type"},
   @tags,
   @blocks]; }

# ================================================================================
# Formatting aids.
sub do_any  { @_; }

# Stuff for Author(s) & Editor(s)
sub do_name {
  my($node)=@_;
  # NOTE: This should be a formatting option; use initials or full first names.
  my $first = $LaTeXML::Post::DOCUMENT->findnode('ltx:givenname',$node);
  if($first){			# && use initials
    $first = join('',map( (/\.$/ ? "$_ " : (/^(.)/ ? "$1. " : '')),
			  split(/\s/,$first->textContent))); }
  else {
    $first = (); }
  my $sur = $LaTeXML::Post::DOCUMENT->findnode('ltx:surname',$node);
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
    ($names[0]->childNodes,' ',['ltx:text',{class=>'ltx_bib_etal'},'et al.']); }
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
#### sub do_title { (['ltx:text',{font=>'italic'},@_]); }
sub do_title { (@_); }
###sub do_bold  { (['ltx:text',{font=>'bold'},@_]); }
sub do_edition { (@_," edition"); } # If a number, should convert to cardinal!
sub do_thesis_type { @_; }
sub do_pages { (" pp.".pack('U',0xA0),@_); } # Non breaking space

sub do_crossref {
  (['ltx:cite',{},['ltx:bibref',{bibrefs=>$_[0]->getAttribute('bibrefs'), show=>'refnum'}]]); }

our $LINKS;
#BEGIN{
    $LINKS = "ltx:bib-links | ltx:bib-review | ltx:bib-identifier | ltx:bib-url";
#}

sub do_links {
  my(@nodes)=@_;
  my @links=();
  my $doc = $LaTeXML::Post::DOCUMENT;
  foreach my $node (@nodes){
    my $scheme = $node->getAttribute('scheme') || '';
    my $href   = $node->getAttribute('href');
    my $tag = $doc->getQName($node);
    if(($tag eq 'ltx:bib-identifier') || ($tag eq 'ltx:bib-review')){
      if($href){
	push(@links,['ltx:ref',{href=>$href, class=>"$scheme ltx_bib_external"},
		     $doc->cloneNodes($node->childNodes)]); }
      else {
	push(@links,['ltx:text',{class=>"$scheme ltx_bib_external"},
		     $doc->cloneNodes($node->childNodes)]); }}
    elsif($tag eq 'ltx:bib-links'){
      push(@links,['ltx:text',{class=>"ltx_bib_external"},
		   $doc->cloneNodes($node->childNodes)]); }
    elsif($tag eq 'ltx:bib-url'         ){
      push(@links,['ltx:ref',{href=>$href, class=>'ltx_bib_external'},
		   $doc->cloneNodes($node->childNodes)]); }}

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

#    [xpath                              punct  pre              class    formatter      post ]
@META_BLOCK =
  ([['ltx:bib-note',                     '',  "Note: ", 'note' , \&do_any  , ''   ]],
   [[$LINKS,                             '',  'External Links: ','links', \&do_links,'.'  ]]);

%FMT_SPEC=
#    [xpath                              punct pre    class     formatter      post ]
  (article=> 
   [[['ltx:bib-name[@role="author"]',     '',  '',    'author',  \&do_authors, '' ],
     ['ltx:bib-date[@role="publication"]','',  '',    'year',    \&do_year,    '' ]],
    [['ltx:bib-title',                    '',  '',    'title',   \&do_title,   ',']],
    [['ltx:bib-part[@role="part"]',       '',  '',    'part',    \&do_any,     '' ],
     ['ltx:bib-related/ltx:bib-title',    ', ','',    'journal', \&do_any,     '' ],
     ['ltx:bib-part[@role="volume"]',     ' ', '',    'volume',  \&do_any,     '' ],
     ['ltx:bib-part[@role="number"]',     ' ', '(',   'number',  \&do_any,     ')'],
     ['ltx:bib-status',                   ', ','(',   'status',  \&do_any,     ')'],
     ['ltx:bib-part[@role="pages"]',      ', ','',    'pages',   \&do_pages,   '' ],
     ['ltx:bib-language',                 ' ' ,'(',   'language',\&do_any,     ')'],
     ['true',                             '.']],
    @META_BLOCK],
   book=>
   [[['ltx:bib-name[@role="author"]',     '',  '',    'author',  \&do_authors,  '' ],
     ['ltx:bib-name[@role="editor"]',     '',  '',    'editor',  \&do_editorsA, '' ],
     ['ltx:bib-date[@role="publication"]','',  '',    'year',    \&do_year,     '' ]],
    [['ltx:bib-title',                    '',  '',    'title',   \&do_title,    ',']],
    [['ltx:bib-type',                     '',  '',    'type',    \&do_any,      '' ],
     ['ltx:bib-edition',                  ', ','',    'edition', \&do_edition,  '' ],
     ['ltx:bib-part[@role="series"]',     ', ','',    'series',  \&do_any,      '' ],
     ['ltx:bib-part[@role="volume"]',     ', ','Vol. ','volume', \&do_any,      '' ],
     ['ltx:bib-part[@role="part"]',       ', ','Part ','part',   \&do_any,      '' ],
     ['ltx:bib-publisher',                ', ',' ',   'publisher',\&do_any,     '' ],
     ['ltx:bib-organization',             ', ',' ',   'publisher',\&do_any,     '' ],
     ['ltx:bib-place',                    ', ','',    'place',   \&do_any,      '' ],
     ['ltx:bib-status',                   ' ', '(',   'status',  \&do_any,      ')'],
     ['ltx:bib-language',                 ' ', '(',   'language',\&do_any,      ')'],
     ['true',                             '.']],
    @META_BLOCK],
   'incollection'=>
   [[['ltx:bib-name[@role="author"]',     '',  '',    'author',   \&do_authors,  '' ],
     ['ltx:bib-date[@role="publication"]','',  '',    'year',     \&do_year,     '' ]],
    [['ltx:bib-title',                    '',  '',    'title',    \&do_title,    ',']],
    [['ltx:bib-type',                     '',  '',    'type',     \&do_any,      '' ],
     ['ltx:bib-related[@bibrefs]',        ' ', 'in ', 'crossref', \&do_crossref, ','],
     ['ltx:bib-related[@type="book"]/ltx:bib-title',' ','in ','inbook', \&do_title,',']],
    [['ltx:bib-edition',                  '',  '',    'edition',  \&do_edition  , '' ],
     ['ltx:bib-name[@role="editor"]',     ', ','',    'editor',   \&do_editorsB , '' ],
     ['ltx:bib-related/ltx:bib-part[@role="series"]',', ','',     'series', \&do_any, '' ],
     ['ltx:bib-related/ltx:bib-part[@role="volume"]',', ','Vol. ','volume', \&do_any, '' ],
     ['ltx:bib-related/ltx:bib-part[@role="part"]',  ', ','Part ','part',   \&do_any, '' ],
     ['ltx:bib-publisher',                ', ',' ',   'publisher',\&do_any,      '' ],
     ['ltx:bib-organization',             ', ','',    'publisher',\&do_any,      '' ],
     ['ltx:bib-place',                    ', ','',    'place',    \&do_any,      '' ],
     ['ltx:bib-part[@role="pages"]',      ', ','',    'pages',    \&do_pages,    '' ],
     ['ltx:bib-status',                   ' ' ,'(',   'status',   \&do_any,      ')'],
     ['ltx:bib-language',                 ' ' ,'(',   'language', \&do_any,      ')'],
     ['true',                             '.']],
    @META_BLOCK],
   report=>
   [[['ltx:bib-name[@role="author"]',     '',  '',    'author',   \&do_authors,  '' ],
     ['ltx:bib-name[@role="editor"]',     '',  '',    'editor',   \&do_editorsA, '' ],
     ['ltx:bib-date[@role="publication"]','',  '',    'year',     \&do_year,     '' ]],
    [['ltx:bib-title',                    '',  '',    'title',    \&do_title,    ',']],
    [['ltx:bib-type',                     '',  '',    'type',     \&do_any,      '' ]],
    [['ltx:bib-part[@role="number"]',     '','Technical Report ', 'number', \&do_any, '' ],
     ['ltx:bib-part[@role="series"]',     ', ','',     'series',  \&do_any,      '' ],
     ['ltx:bib-part[@role="volume"]',     ', ','Vol. ','volume',  \&do_any,      '' ],
     ['ltx:bib-part[@role="part"]',       ', ','Part ','part',    \&do_any,      '' ],
     ['ltx:bib-publisher',                ', ',' ',   'publisher',\&do_any,      '' ],
     ['ltx:bib-organization',             ', ',' ',   'publisher',\&do_any,      '' ],
     ['ltx:bib-place',                    ', ',' ',   'place',    \&do_any,      '' ],
     ['ltx:bib-status',                   ', ','(',   'status',   \&do_any,      ')'],
     ['ltx:bib-language',                 ' ', '(',   'language', \&do_any,      ')'],
     ['true',                             '.']],
    @META_BLOCK],
   thesis=>
   [[['ltx:bib-name[@role="author"]',     '',  '',    'author',   \&do_authors,  '' ],
     ['ltx:bib-name[@role="editor"]',     '',  '',    'editor',   \&do_editorsA, '' ],
     ['ltx:bib-date[@role="publication"]','',  '',    'year',     \&do_year,     '' ]],
    [['ltx:bib-title',                    '',  '',    'title',    \&do_title,    ',']],
    [['ltx:bib-type',                     ' ', '',    'type',     \&do_thesis_type,''],
     ['ltx:bib-part[@role="part"]',       ', ','Part ','part',    \&do_any,      '' ],
     ['ltx:bib-publisher',                ', ','',    'publisher',\&do_any,      '' ],
     ['ltx:bib-organization',             ', ','',    'publisher',\&do_any,      '' ],
     ['ltx:bib-place',                    ', ','',    'place',    \&do_any,      '' ],
     ['ltx:bib-status',                   ', ','(',   'status',   \&do_any,      ')'],
     ['ltx:bib-language',                 ', ','(',   'language', \&do_any,      ')'],
     ['true',                             '.']],
    @META_BLOCK],
   website=>
   [[['ltx:bib-name[@role="author"]',     '',  '',    'author',   \&do_authors,  '' ],
     ['ltx:bib-name[@role="editor"]',     '',  '',    'editor',   \&do_editorsA, '' ],
     ['ltx:bib-date[@role="publication"]', '', '',    'year',     \&do_year,     '' ],
     ['ltx:title',                         '', '',    'title',    \&do_any,      '' ],
     ['ltx:bib-type',                      '', '',    'type',     \&do_any,      '' ],
     ['! ltx:bib-type',                    '', '',    'type',   sub { ('(Website)'); },'']],
    [['ltx:bib-organization',              ', ',' ',  'publisher',\&do_any,      '' ],
    ['ltx:bib-place',                      ', ','',   'place',    \&do_any,      '' ],
     ['true',                              '.']],
    @META_BLOCK],
   software=>
   [[['ltx:bib-key',                       '',  '',   'key',      \&do_any,      '' ],
     ['ltx:bib-type',                      '',  '',   'type',     \&do_type,     '' ]],
    [['ltx:bib-title',                     '',  '',   'title',    \&do_any,      '' ]],
    [['ltx:bib-organization',              ', ',' ',  'publisher',\&do_any,      '' ],
     ['ltx:bib-place',                     ', ','',   'place',    \&do_any,      '' ],
     ['true',                              '.']],
    @META_BLOCK],
);

$FMT_SPEC{periodical}  = $FMT_SPEC{book};
$FMT_SPEC{collection}  = $FMT_SPEC{book};
$FMT_SPEC{proceedings} = $FMT_SPEC{book};
$FMT_SPEC{manual}      = $FMT_SPEC{book};
$FMT_SPEC{misc}        = $FMT_SPEC{book};
$FMT_SPEC{unpublished} = $FMT_SPEC{book};
$FMT_SPEC{booklet}     = $FMT_SPEC{book};
$FMT_SPEC{'collection.article'}  = $FMT_SPEC{incollection};
$FMT_SPEC{'proceedings.article'} = $FMT_SPEC{incollection};
$FMT_SPEC{inproceedings}         = $FMT_SPEC{incollection};
$FMT_SPEC{inbook}                = $FMT_SPEC{incollection};
$FMT_SPEC{techreport}  = $FMT_SPEC{report};

#}

# ================================================================================
1;

