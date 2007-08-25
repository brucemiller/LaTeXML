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
use XML::LibXML;
use charnames qw(:full);
use base qw(LaTeXML::Post::Collector);

our %FMT_SPEC;

# Options:
#   bibliographies : list of xml file names containing bibliographies (from bibtex)
#   split  : whether the split into separate pages by initial.
# Possibly:
#   Optionally use numeric citations? Currently set up for author-year.
#   (for numeric how would we split?)

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
    my $entries = $self->getBibEntries($doc);

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

# Need to sort (cited) on author+year+title, [NOT on the key!!!]
# and then check whether author+year is unique!!!

# ================================================================================
sub getBibEntries {
  my($self,$doc)=@_;

  my %citations = map( (/^BIBLABEL:(.*)$/ ? ($1=>1) : ()),$$self{db}->getKeys);
  my $entries = {};
  my($ntotal,$ncited)=(0,0);
  foreach my $bibfile (@{$$self{bibliographies}}){
    my $bibdoc = $doc->newFromFile($bibfile);
    foreach my $bibentry ($bibdoc->findnodes('//ltx:bibentry')){
      $ntotal++;
      my $bibkey = $bibentry->getAttribute('key');
      if($citations{$bibkey}){
	my $dbentry = $$self{db}->lookup("BIBLABEL:$bibkey");
	$ncited++;
	my $names='';
	if(my $n = $doc->findnode('ltx:bib-key',$bibentry)){
	  $names = $n->textContent; }
	elsif(my @ns = $doc->findnodes('ltx:bib-author/ltx:surname | ltx:bib-editor/ltx:surname',
					$bibentry)){
	  if(@ns > 2){    $names = $ns[0]->textContent .' et.al'; }
	  elsif(@ns > 1){ $names = $ns[0]->textContent .' and '. $ns[1]->textContent; }
	  else          { $names = $ns[0]->textContent; }}
	elsif(my $t = $doc->findnode('ltx:bib-title',$bibentry)){
	  $names = $t->textContent; }
	my $date = $doc->findnode('ltx:bib-date | ltx:bib-type',$bibentry);
	my $title =$doc->findnode('ltx:bib-title',$bibentry);
	$date = ($date ? $date->textContent : '');
	$title= ($title ?$title->textContent : '');

	my $sortkey = lc(join('.',$names,$date,$title,$bibkey));
	my $referrers = $dbentry->getValue('referrers');
	$$entries{$sortkey} = {bibentry=>$bibentry, ay=>"$names.$date",
			       initial=>$doc->initial($names,1), 
			       referrers=> ($referrers ? [sort keys %$referrers]:[])};
	delete $citations{$bibkey}; }}}
  $self->Progress("$ntotal bibentries, $ncited cited");
  # Remaining citations were never found!
  $self->Progress("Missing bib keys ".join(', ',keys %citations)) if keys %citations;

  # Sort the bibentries according to author+year+title+bibkey
  # If any neighboring entries have same author+year, set a suffix: a,b,...
  my @keys = sort keys %$entries;
  while(my $key = shift(@keys)){
    my $i=0;
    while(@keys && ($$entries{$key}{ay} eq $$entries{$keys[0]}{ay})){
      $$entries{$key}{suffix}='a';
      $$entries{$keys[0]}{suffix} = chr(ord('a')+(++$i));
      shift(@keys); }}
  $entries; }

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
  my $id   = $bibentry->getAttribute('id');
  my $key  = $bibentry->getAttribute('key');
  my $type = $bibentry->getAttribute('type');
  my $spec = $FMT_SPEC{$type};
  local $LaTeXML::Post::MakeBibliography::DOCUMENT = $doc;
  local @LaTeXML::Post::MakeBibliography::SUFFIX = ($$entry{suffix} ? ($$entry{suffix}):());

  warn "\nNo formatting specification for bibentry of type $type" unless $spec;
  # Format the data in blocks, with the first being bib-label, rest bib-block.
  my @blocks = ();
  foreach my $blockspec (@$spec){
    my($blockname,@linespecs)=@$blockspec;
    my @x =();
    foreach my $row (@linespecs){
      my($xpath,$punct,$pre,$op,$post)=@$row;
      my @nodes = ($xpath eq 'true' ? () : $doc->findnodes($xpath,$bibentry));
      next unless @nodes || ($xpath eq 'true');
      push(@x,$punct) if $punct && @x;
      push(@x,$pre) if $pre;
      push(@x,&$op(map($_->cloneNode(1),@nodes))) if $op;
      push(@x,$post) if $post; }
    push(@blocks,[$blockname,{},@x]) if @x;
  }
  push(@blocks,['ltx:bib-block',{},"Cited by: ",
		$doc->conjoin(', ',map(['ltx:ref',{idref=>$_, show=>'typerefnum'}],
				       @{$$entry{referrers}}))]);

  ['ltx:bibitem',{id=>$id, key=>$key, type=>$type},@blocks]; }

# ================================================================================
# Formatting aids.
sub do_any  { @_; }

# Stuff for Author(s) & Editor(s)
sub do_names {
  my(@names)=@_;
  my @stuff=();
  while(my $name = shift(@names)){
    push(@stuff, (@names ? ', ' : ' and ')) if @stuff;
    push(@stuff, do_name($name)); }
  @stuff; }

sub do_name {
  my($node)=@_;
  my ($init)= $LaTeXML::Post::MakeBibliography::DOCUMENT->findnodes('ltx:initials',$node);
  my ($sur) = $LaTeXML::Post::MakeBibliography::DOCUMENT->findnodes('ltx:surname',$node);
# Why, oh Why do we need the _extra_ cloneNode ???
  ( ($init ? ($init->cloneNode(1)->childNodes,' '):()), $sur->cloneNode(1)->childNodes); }
#  ( ($init ? (content_nodes($init),' '):()),content_nodes($sur)); }

sub do_authors { do_names(@_); }
sub do_editorsA {
  my @n = do_names(@_);
  if(scalar(@_)>1) { push(@n," (Eds.)"); }
  elsif(scalar(@_)){ push(@n," (Ed.)"); }
  @n; }
sub do_editorsB {
  my @x = do_names(@_);
  if(scalar(@_)>1) { push(@x," Eds."); }
  elsif(scalar(@_)){ push(@x," Ed."); }
  (@x ? ("(",@x,")") : ()); }

# These two are used for generating the citation keys.
# (Used to fill in the text of \cite{})
sub do_cite_names { 
  my(@names)=@_;
  if(@names > 2){
    @names = ($names[0]->childNodes,' ',['ltx:emph',{},'et.al.']); }
  elsif(@names > 1){
    @names = ($names[0]->childNodes,' and ',$names[1]->childNodes); }
  elsif(@names){
    @names = $names[0]->childNodes; }
  (['ltx:cite-names',{},@names]); }

# NOTE: The TargetDB will manage any a,b, etc
sub do_cite_year {
  my($year_or_text)=@_;
  (['ltx:cite-year',{},
    (ref $year_or_text ? $year_or_text->childNodes : $year_or_text),
    @LaTeXML::Post::MakeBibliography::SUFFIX]); }

sub do_cite_title { (['ltx:cite-title',{},@_]); }

# Other fields.
sub do_year { ('(',@_,@LaTeXML::Post::MakeBibliography::SUFFIX,')'); }
sub do_type { ('(',@_,')'); }
sub do_date { @_; }
sub do_title { (['ltx:text',{font=>'italic'},@_]); }
sub do_bold  { (['ltx:text',{font=>'bold'},@_]); }
sub do_edition { (@_," edition"); } # If a number, should convert to cardinal!
sub do_isbn { my @l = map( (", ",$_), @_); @l[1..$#l]; }
sub do_thesis_type { @_; }
sub do_eprint { @_; }
sub do_pages { (" pp.\N{NO-BREAK SPACE}",@_); } # Non breaking space

our $LINKS;
BEGIN{
    $LINKS = "ltx:bib-doi | ltx:bib-links | ltx:bib-url"
	." | ltx:bib-mrnumber | ltx:bib-mrreviewer | ltx:bib-review";
}

sub do_links {
  my(@nodes)=@_;
  my @links=();

  my($mrreviewer) = grep( getQName($_) eq 'ltx:bib-mrreviewer', @nodes);

  foreach my $node (@nodes){
    my $href = $node->textContent;
    my $tag = getQName($node);
    if   ($tag eq 'ltx:bib-doi'         ){
      push(@links,['ltx:ref',{href=>"http://dx.doi.org/".$href},"FullText"]); }
    elsif($tag eq 'ltx:bib-links'       ){
      push(@links, map($_->cloneNode(1),
		       $LaTeXML::Post::MakeBibliography::DOCUMENT->findnodes('ltx:ref | ltx:GAMS',$node))); }
    elsif($tag eq 'ltx:bib-mrnumber'    ){
      push(@links,['ltx:ref',{href=>"http://www.ams.org/mathscinet-getitem?mr=".$href},
		   "MathReviews",
		   ($mrreviewer ? (" (",$mrreviewer->childNodes,")"):())]); }
    elsif($tag eq 'ltx:bib-review'      ){
      push(@links,['ltx:ref',{href=>$href},"Review"]); }
    elsif($tag eq 'ltx:bib-url'         ){
      push(@links,['ltx:ref',{href=>$href},"Other"]); }}
  @links = map((",\n",$_),@links);
  @links[1..$#links]; }

# ================================================================================
# Formatting specifications.
# Adpated from amsrefs.sty
BEGIN{

# Structure is:
#  type => [block_format, ...]
#  block_format = [block_name, fieldformat,...]
#  fieldformat == [xpath, punct, prestring, operatorname, poststring]
# The first block should typically be 'tag', the rest 'bib-block'.

%FMT_SPEC=
  (article=>[ ['ltx:tag',
	       ['ltx:bib-author'   , ''  , '', \&do_authors,''],
	       ['ltx:bib-date'     , ' ' , '', \&do_year,'']],
	      ['ltx:bib-citekeys',
	       ['ltx:bib-author/ltx:surname','', '', \&do_cite_names,''],
	       ['ltx:bib-date',              '', '', \&do_cite_year,''],
	       ['ltx:bib-title',             '', '', \&do_cite_title,'']],
	      ['ltx:bib-block',
	       ['ltx:bib-title'    , ''  , '', \&do_title,',']],
	      ['ltx:bib-block',
	       ['ltx:bib-part'     , ''  , '', \&do_any,''],
	       ['ltx:bib-journal'  , ', ', '', \&do_any,''],
	       ['ltx:bib-volume'   , ' ' , '', \&do_bold,''],
	       ['ltx:bib-number'   , ' ' , '(', \&do_any,')'],
	       ['ltx:bib-eprint'   , ', ', '', \&do_eprint,''],
	       ['ltx:bib-status'   , ', ', '(', \&do_any,')'],
	       ['ltx:bib-pages'    , ', ', '', \&do_pages,''],
	       ['ltx:bib-language' , ' ' , '(', \&do_any,')'],
	       ['ltx:bib-issn'     , ' ' , '[ISSN ',\&do_any,']'],
	       ['true'             , '.']],
	      ['ltx:bib-block',
	       ['ltx:bib-note'     ,'', "Note: ",\&do_any,'']],
	      ['ltx:bib-block',
	       [$LINKS             ,'', 'Links: ',\&do_links,'']]],
   book=>   [ ['ltx:tag',
	       ['ltx:bib-author'   , ''  , '', \&do_authors,''],
	       ['ltx:bib-editor'   , ', ', '', \&do_editorsA,''],
	       ['ltx:bib-date'     , ' ' , '', \&do_year,'']],
	      ['ltx:bib-citekeys',
	       ['ltx:bib-author/ltx:surname | ltx:bib-editor/ltx:surname','', '', \&do_cite_names,''],
	       ['ltx:bib-date',              '', '', \&do_cite_year,''],
	       ['ltx:bib-title',             '', '', \&do_cite_title,'']],
	      ['ltx:bib-block',
	       ['ltx:bib-title'    , ''  , '', \&do_title,',']],
	      ['ltx:bib-block',
	       ['ltx:bib-type'     , ''  , '', \&do_any,''],
	       ['ltx:bib-booktitle', ', ', '', \&do_title,''],
	       ['ltx:bib-edition'  , ', ', '', \&do_edition,''],
	       ['ltx:bib-series'   , ', ', '', \&do_any,''],
	       ['ltx:bib-volume'   , ', ', 'Vol. ', \&do_any,''],
	       ['ltx:bib-part'     , ', ', 'Part ', \&do_any,''],
	       ['ltx:bib-publisher', ', ', ' ', \&do_any,''],
	       ['ltx:bib-organization',', ',' ', \&do_any,''],
	       ['ltx:bib-place'    , ', ', '', \&do_any,''],
	       ['ltx:bib-isbn'     , ' ' , '[ISBN ',\&do_isbn,']'],
	       ['ltx:bib-status'   , ' ' , '(',\&do_any,')'],
	       ['ltx:bib-language' , ' ' , '(',\&do_any,')'],
	       ['true','.']],
	      ['ltx:bib-block',
	       ['ltx:bib-note'  ,'', "Note: ",\&do_any,'']],
	      ['ltx:bib-block',
	       [$LINKS          ,'', 'Links: ',\&do_links,'']]],
   'collection.article'=>[
	      ['ltx:tag',
	       ['ltx:bib-author'   , ''  , '', \&do_authors,''],
	       ['ltx:bib-date'     , ' ' , '', \&do_year,'']],
	      ['ltx:bib-citekeys',
	       ['ltx:bib-author/ltx:surname','', '', \&do_cite_names,''],
	       ['ltx:bib-date',              '', '', \&do_cite_year,''],
	       ['ltx:bib-title',             '', '', \&do_cite_title,'']],
	      ['ltx:bib-block',
	       ['ltx:bib-title'    , ''  , '', \&do_title,',']],
	      ['ltx:bib-block',
	       ['ltx:bib-type'     , ''  , '', \&do_any,''],
	       ['ltx:bib-booktitle', ' ' , 'in ', \&do_title,',']],
	      ['ltx:bib-block',
	       ['ltx:bib-edition'  , ''  , '', \&do_edition,''],
	       ['ltx:bib-editor'   , ', ', '', \&do_editorsB,''],
	       ['ltx:bib-series'   , ', ', '', \&do_any,''],
	       ['ltx:bib-volume'   , ', ', 'Vol. ',\&do_any,''],
	       ['ltx:bib-part'     , ', ', 'Part ',\&do_any,''],
	       ['ltx:bib-publisher', ', ', ' ', \&do_any,''],
	       ['ltx:bib-organization',', ','', \&do_any,''],
	       ['ltx:bib-place'    , ', ', '', \&do_any,''],
	       ['ltx:bib-pages'    , ', ', '', \&do_pages,''],
	       ['ltx:bib-isbn'     , ' ' , '[ISBN ',\&do_isbn,']'],
	       ['ltx:bib-status'   , ' ' , '(',\&do_any,')'],
	       ['ltx:bib-language' , ' ' , '(', \&do_any,')'],
	       ['true','.']],
	      ['ltx:bib-block',
	       ['ltx:bib-note'  ,'', "Note: ",\&do_any,'']],
	      ['ltx:bib-block',
	       [$LINKS          ,'', 'Links: ',\&do_links,'']]],
   report=>[  ['ltx:tag',
	       ['ltx:bib-author'   , ''  , '', \&do_authors,''],
	       ['ltx:bib-editor'   , ', ', '', \&do_editorsA,''],
	       ['ltx:bib-date'     , ' ' , '', \&do_year,'']],
	      ['ltx:bib-citekeys',
	       ['ltx:bib-author/ltx:surname | ltx:bib-editor/ltx:surname','', '', \&do_cite_names,''],
	       ['ltx:bib-date',              '', '', \&do_cite_year,''],
	       ['ltx:bib-title',             '', '', \&do_cite_title,'']],
	      ['ltx:bib-block',
	       ['ltx:bib-title'    , ''  , '', \&do_title,',']],
	      ['ltx:bib-block',
	       ['ltx:bib-type'     , ''  , '', \&do_any,''],
	       ['ltx:bib-booktitle', ', ', ' in ',\&do_title,',']],
	      ['ltx:bib-block',
	       ['ltx:bib-number'   , ''  , 'Technical Report ',\&do_any,''],
	       ['ltx:bib-series'   , ', ', '',\&do_any,''],
	       ['ltx:bib-volume'   , ', ', 'Vol. ',\&do_any,''],
	       ['ltx:bib-part'     , ', ', 'Part ',\&do_any,''],
	       ['ltx:bib-publisher', ', ', ' ',\&do_any,''],
	       ['ltx:bib-organization',', ', ' ',\&do_any,''],
	       ['ltx:bib-institution',', ', ' ',\&do_any,''],
	       ['ltx:bib-place'    , ', ', ' ',\&do_any,''],
	       ['ltx:bib-isbn'     , ', ', '[ISBN ',\&do_isbn,']'],
	       ['ltx:bib-eprint'   , ', ', '',\&do_eprint,''],
	       ['ltx:bib-status'   , ', ', '(',\&do_any,')'],
	       ['ltx:bib-language' , ' ' , '(',\&do_any,')'],
	       ['true','.']],
	      ['ltx:bib-block',
	       ['ltx:bib-note'  ,'', "Note: ",\&do_any,'']],
	      ['ltx:bib-block',
	       [$LINKS          ,'','Links: ',\&do_links,'']]],
   thesis=>[  ['ltx:tag',
	       ['ltx:bib-author', ''  , '', \&do_authors,''],
	       ['ltx:bib-editor'   , ', ', '', \&do_editorsA,''],
	       ['ltx:bib-date'     , ' ' , '', \&do_year,'']],
	      ['ltx:bib-citekeys',
	       ['ltx:bib-author/ltx:surname | ltx:bib-editor/ltx:surname','', '', \&do_cite_names,''],
	       ['ltx:bib-date',              '', '', \&do_cite_year,''],
	       ['ltx:bib-title',             '', '', \&do_cite_title,'']],
	      ['ltx:bib-block',
	       ['ltx:bib-title'    , ''  , '', \&do_title,',']],
	      ['ltx:bib-block',
	       ['ltx:bib-type'     , ' ' , '',\&do_thesis_type,''],
	       ['ltx:bib-part'     , ', ', 'Part ',\&do_any,''],
	       ['ltx:bib-institution',', ','',\&do_any,''],
	       ['ltx:bib-place'    , ', ', '',\&do_any,''],
	       ['ltx:bib-status'   , ', ', '(',\&do_any,')'],
	       ['ltx:bib-language' , ', ', '(',\&do_any,')'],
	       ['true','.']],
	      ['ltx:bib-block',
	       ['ltx:bib-note'  ,'', "Note: ",\&do_any,'']],
	      ['ltx:bib-block',
	       [$LINKS          ,'','Links: ',\&do_links,'']]],
   website=>[ ['ltx:tag',
	       ['ltx:bib-title'     ,  ''  , '', \&do_any, ''],
	       ['true'      , ' '  , '(Website)']],
	      ['ltx:bib-citekeys',
	       ['ltx:bib-title',   '', '', \&do_cite_names,''],
	       ['true',            '', '(Website)']],
#	      ['ltx:bib-block',
#	       ['ltx:bib-url',     '', '', sub { (['a',{href=>$_[0]->textContent},'Website']); },'']],
	      ['ltx:bib-block',
	       ['ltx:bib-organization',', ',' ', \&do_any,''],
	       ['ltx:bib-place'    , ', ', '', \&do_any,''],
	       ['true','.']],
	      ['ltx:bib-block',
	       ['ltx:bib-note'  ,'', "Note: ",\&do_any,'']],
	      ['ltx:bib-block',
	       [$LINKS          ,'','Links: ',\&do_links,'']]],
   software=>[['ltx:tag',
	       ['ltx:bib-key'       ,  ''  , '', \&do_any, ''],
	       ['ltx:bib-type'      , ' '  , '', \&do_type, '']],
	      ['ltx:bib-citekeys',
	       ['ltx:bib-key',         '', '', \&do_cite_names,''],
	       ['ltx:bib-type',        '', '', \&do_cite_year,'']],
	      ['ltx:bib-block',
	       ['ltx:bib-title'     ,  ''  , '', \&do_any, '']],
	      ['ltx:bib-block',
	       ['ltx:bib-organization',', ',' ', \&do_any,''],
	       ['ltx:bib-place'    , ', ', '', \&do_any,''],
	       ['true','.']],
	      ['ltx:bib-block',
	       ['ltx:bib-note'  ,'', "Note: ",\&do_any,'']],
	      ['ltx:bib-block',
	       [$LINKS          ,'','Links: ',\&do_links,'']]],

);

$FMT_SPEC{periodical}  = $FMT_SPEC{book};
$FMT_SPEC{collection}  = $FMT_SPEC{book};
$FMT_SPEC{proceedings} = $FMT_SPEC{book};
$FMT_SPEC{manual}      = $FMT_SPEC{book};
$FMT_SPEC{misc}        = $FMT_SPEC{book};
$FMT_SPEC{unpublished} = $FMT_SPEC{book};
$FMT_SPEC{'proceedings.article'} = $FMT_SPEC{'collection.article'};
$FMT_SPEC{incollection} = $FMT_SPEC{'collection.article'};
$FMT_SPEC{inproceedings} = $FMT_SPEC{'collection.article'};
$FMT_SPEC{inbook} = $FMT_SPEC{'collection.article'};
$FMT_SPEC{techreport}  = $FMT_SPEC{report};

}

# ================================================================================
1;

