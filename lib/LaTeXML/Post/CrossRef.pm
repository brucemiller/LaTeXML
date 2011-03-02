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
use LaTeXML::Common::XML;
use charnames qw(:full);
use base qw(LaTeXML::Post);

sub new {
  my($class,%options)=@_;
  my $self = $class->SUPER::new(%options);
  $$self{db}       = $options{db};
  $$self{urlstyle} = $options{urlstyle};
##  $$self{toc_show} = ($options{number_sections} ? "typerefnum title" : "title");
  $$self{toc_show} = 'toctitle';
  $$self{ref_show} = ($options{number_sections} ? "typerefnum" : "title");
  $$self{min_ref_length} = (defined $options{min_ref_length} ? $options{min_ref_length} : 1);
  $$self{ref_join} = (defined $options{ref_join} ? $options{ref_join} : " \x{2023} "); # or " in " or ... ?
  $self; }

sub process {
  my($self,$doc)=@_;
  $self->ProgressDetailed($doc,"Beginning cross-references");
  my $root = $doc->getDocumentElement;
  local %LaTeXML::Post::CrossRef::MISSING=();
  $self->fill_in_tocs($doc);
  $self->fill_in_frags($doc);
  $self->fill_in_refs($doc);
  $self->fill_in_bibrefs($doc);
  if(($$self{verbosity} >= 0) && (keys %LaTeXML::Post::CrossRef::MISSING)){
    my @msgs=();
    foreach my $type (sort keys %LaTeXML::Post::CrossRef::MISSING){
      push(@msgs,$type.": ".join(', ',sort keys %{$LaTeXML::Post::CrossRef::MISSING{$type}}));}
    $self->Warn($doc,"Missing keys:\n  ".join(";\n  ",@msgs)); }
  $self->ProgressDetailed($doc,"done cross-references");
  $doc; }

sub note_missing {
  my($self,$type,$key)=@_;
  $LaTeXML::Post::CrossRef::MISSING{$type}{$key}++; }

our $normaltoctypes = {map( ($_=>1), qw(ltx:document ltx:part ltx:chapter ltx:section ltx:subsection ltx:subsubsection
				      ltx:paragraph ltx:subparagraph ltx:index ltx:bibliography ltx:appendix))};

sub fill_in_tocs {
  my($self,$doc)=@_;
  $self->ProgressDetailed($doc,"Filling in TOCs");
  foreach my $toc ($doc->findnodes('descendant::ltx:TOC[not(ltx:toclist)]')){
    my $selector = $toc->getAttribute('select');
    my $types = ($selector
		 ? {map(($_=>1),split(/\s*\|\s*/,$selector))}
		 : $normaltoctypes);
    # global vs children of THIS or Document node?
    my $id = $doc->getDocumentElement->getAttribute('xml:id');
    my $format = $toc->getAttribute('format');

    my @list = ();
    if(!$format || ($format eq 'normal')){
      @list = $self->gentoc($id,$types); }
    elsif($format eq 'context'){
      @list = $self->gentoc_context($id,$types); }
    $doc->addNodes($toc,['ltx:toclist',{},@list]) if @list; }
}

# generate TOC for $id & its children,
# providing that those objects are of appropriate type.
# Returns a list of 0 or more ltx:tocentry's (possibly containing ltx:toclist's)
# Note that parent/child relationships stored in ObjectDB can also reflect less
# `interesting' objects like para or p style paragraphs, and such.
#   $location: if defined (as a pathname), only include children that are on that page
#   $depth   : only to the specific depth
#
sub gentoc {
  my($self,$id, $types, $localto,$selfid)=@_;
  if(my $entry = $$self{db}->lookup("ID:$id")){
    my @kids = ();
    if((!defined $localto) || ( ($entry->getValue('location')||'') eq $localto) ){
      @kids = map($self->gentoc($_,$types,$localto,$selfid), @{ $entry->getValue('children')||[]}); }
    my $type = $entry->getValue('type');
    if($$types{$type}){
      (['ltx:tocentry',(defined $selfid && ($selfid eq $id) ? {class=>'self'} : {}),
	['ltx:ref',{class=>'toc',show=>'toctitle',idref=>$id}],
	(@kids ? (['ltx:toclist',{},@kids]) : ())]); }
    else {
      @kids; }}
  else {
    (); }}

# Generate a "context" TOC, that shows what's on the current page,
# but also shows the page in the context of it's siblings & ancestors.
# This is useful for putting in a navigation bar.
sub gentoc_context {
  my($self,$id,$types)=@_;
  if(my $entry = $$self{db}->lookup("ID:$id")){
    # Generate Downward TOC covering items WITHIN the current page.
    my @navtoc = $self->gentoc($id, $types, $entry->getValue('location')||'',$id);
    # Then enclose it upwards along with siblings & ancestors
    my $p_id;
    while(($p_id = $entry->getValue('parent')) && ($entry = $$self{db}->lookup("ID:$p_id"))){
      @navtoc = map(($_ eq $id
		     ? @navtoc
		     : ['ltx:tocentry',{},
			['ltx:ref',{class=>'toc',idref=>$_,show=>'toctitle'}]]),
		    grep($$normaltoctypes{$$self{db}->lookup("ID:$_")->getValue('type')},
			 @{ $entry->getValue('children')||[] }) );
      if($$types{$entry->getValue('type')}){
	@navtoc = (['ltx:tocentry',{},
		    ['ltx:ref',{class=>'toc',show=>'toctitle',idref=>$p_id}],
		    (@navtoc ? (['ltx:toclist',{},@navtoc]) : ())]); }
      $id = $p_id; }
    @navtoc; }
  else {
    (); }}

sub fill_in_frags {
  my($self,$doc)=@_;
  $self->ProgressDetailed($doc,"Filling in fragment ids");
  my $db = $$self{db};
  # Any nodes with an ID will get a fragid;
  # This is the id/name that will be used within xhtml/html.
  foreach my $node ($doc->findnodes('//@xml:id')){
    if(my $entry = $db->lookup("ID:".$node->value)){
      if(my $fragid = $entry->getValue('fragid')){
	$node->parentNode->setAttribute(fragid=>$fragid); }}}}

# Fill in content text for any <... @idref..>'s or @labelref
sub fill_in_refs {
  my($self,$doc)=@_;
  my $db = $$self{db};
  $self->ProgressDetailed($doc,"Filling in refs");
  foreach my $ref ($doc->findnodes('descendant::*[@idref or @labelref]')){
    my $tag = $doc->getQName($ref);
    next if $tag eq 'ltx:XMRef'; # Blech; list those TO fill-in, or list those to exclude?
    my $id = $ref->getAttribute('idref');
    my $show = $ref->getAttribute('show');
    $show = $$self{ref_show} unless $show;
    $show = $$self{toc_show} if ($show eq 'fulltitle') || ($show =~ /.+title|title.+/);
    if(!$id){
      if(my $label = $ref->getAttribute('labelref')){
	my $entry;
	if(($entry = $db->lookup($label)) && ($id=$entry->getValue('id'))){
	  $show =~ s/^type//; 	# Since author may have put explicit \S\ref... in! 
	}
	else {
	  $self->note_missing('Label',$label);
	  if(!$ref->textContent){
	    $doc->addNodes($ref,$label);  # Just to reassure (?) readers.
	    $ref->setAttribute(broken=>1); }
	}}}
    if($id){
      if(!$ref->getAttribute('href')){
	if(my $url = $self->generateURL($doc,$id)){
	  $ref->setAttribute(href=>$url); }}
      if(!$ref->getAttribute('title')){
	if(my $titlestring = $self->generateTitle($doc,$id)){
	  $ref->setAttribute(title=>$titlestring); }}
      if(!$ref->textContent && !(($tag eq 'ltx:graphics') || ($tag eq 'ltx:picture'))){
	$doc->addNodes($ref,$self->generateRef($doc,$id,$show)); }
      if(my $entry = $$self{db}->lookup("ID:$id")){
	$ref->setAttribute(stub=>1) if $entry->getValue('stub'); }
    }}}


# Needs to evolve into the combined stuff that we had in DLMF.
# (eg. concise author/year combinations for multiple bibrefs)
sub fill_in_bibrefs {
  my($self,$doc)=@_;
  $self->ProgressDetailed($doc,"Filling in bibrefs");
  foreach my $bibref ($doc->findnodes('descendant::ltx:bibref')){
    $doc->replaceNode($bibref,$self->make_bibcite($doc,$bibref)); }}

# Given a list of bibkeys, construct links to them.
# Mostly tuned to author-year style.
# Combines when multiple bibitems share the same authors.
sub make_bibcite {
  my($self,$doc,$bibref)=@_;

  my @keys = grep($_,split(/,/,$bibref->getAttribute('bibrefs')));
  my $show = $bibref->getAttribute('show');
  my @preformatted = $bibref->childNodes();
  if($show && ($show eq 'none') && !@preformatted){
    $show = 'refnum'; }
  if(!$show){
    $self->Warn($doc,"No show in bibref ".join(', ',@keys)); 
    $show = 'refnum'; }

  my $sep  = $bibref->getAttribute('separator') || ',';
  my $yysep= $bibref->getAttribute('yyseparator') || ',';
  my @phrases = $bibref->getChildNodes();	  # get the ltx;note's in the bibref!
  # Collect all the data from the bibliography
  my @data = ();
  foreach my $key (@keys){
    if(my $bentry = $$self{db}->lookup("BIBLABEL:$key")){
      if(my $id = $bentry->getValue('id')){
	if(my $entry = $$self{db}->lookup("ID:$id")){
	  my $authors  = $entry->getValue('authors');
	  my $fauthors = $entry->getValue('fullauthors');
	  my $keytag   = $entry->getValue('keytag');
	  my $year     = $entry->getValue('year');
	  my $typetag  = $entry->getValue('typetag');
	  my $number   = $entry->getValue('number');
	  my $title    = $entry->getValue('title');
	  my $refnum   = $entry->getValue('refnum'); # This come's from the \bibitem, w/o BibTeX
	  my($rawyear,$suffix);
	  if($year && ($year->textContent) =~ /^(\d\d\d\d)(\w)$/){
	    ($rawyear,$suffix)=($1,$2); }
	  $show = 'refnum' unless ($show eq 'none') || $authors || $fauthors || $keytag; # Disable author-year format!
	  # fullnames ?
	  push(@data,{authors     =>[$doc->trimChildNodes($authors || $fauthors || $keytag)],
		      fullauthors =>[$doc->trimChildNodes($fauthors || $authors || $keytag)],
		      authortext  =>($authors||$fauthors ? ($authors||$fauthors)->textContent :''),
		      year        =>[$doc->trimChildNodes($year || $typetag)],
		      rawyear     =>$rawyear,
		      suffix      =>$suffix,
		      number      =>[$doc->trimChildNodes($number)],
		      refnum      =>[$doc->trimChildNodes($refnum)],
		      title       =>[$doc->trimChildNodes($title || $keytag)],
		      attr=>{idref=>$id,
			     href=>$self->generateURL($doc,$id),
			     ($title ? (title=>$title->textContent):())}}); }}}
    else {
      $self->note_missing('Citation',$key); }}
  my $checkdups = ($show =~ /author/i) && ($show =~ /(year|number)/i);
  my @refs=();
  my $saveshow = $show;
  while(@data){
    my $datum = shift(@data);
    my $didref = 0;
    my @stuff=();
    $show=$saveshow;
    if(($show eq 'none') && @preformatted){
      @stuff = @preformatted; $show=''; }
    while($show){
      if($show =~ s/^authors?//i){
	push(@stuff,@{$$datum{authors}}); }
      elsif($show =~ s/^fullauthors?//i){
	push(@stuff,@{$$datum{fullauthors}}); }
      elsif($show =~ s/^title//i){
	push(@stuff,@{$$datum{title}}); }
      elsif($show =~ s/^refnum//i){
	push(@stuff,@{$$datum{refnum}}); }
      elsif($show =~ s/^phrase(\d)//i){
	push(@stuff,$phrases[$1-1]->childNodes) if $phrases[$1-1]; }
      elsif($show =~ s/^year//i){
	if(@{$$datum{year}}){
	  push(@stuff,['ltx:ref',$$datum{attr},@{$$datum{year}}]);
	  $didref=1; 
	  while($checkdups && @data && ($$datum{authortext} eq $data[0]{authortext})){
	    my $next = shift(@data);
	    push(@stuff, $yysep,' ');
	    if((($$datum{rawyear}||'no_year_1') eq ($$next{rawyear}||'no_year_2')) && $$next{suffix}){
	      push(@stuff,['ltx:ref',$$next{attr},$$next{suffix}]);  }
	    else {
	      push(@stuff,['ltx:ref',$$next{attr},@{$$next{year}}]);  }}}}
      elsif($show =~ s/^number//i){
	push(@stuff,['ltx:ref',$$datum{attr},@{$$datum{number}}]);
	$didref=1;
	while($checkdups && @data && ($$datum{authortext} eq $data[0]{authortext})){
	  my $next = shift(@data);
	  push(@stuff,$yysep,' ',['ltx:ref',$$next{attr},@{$$next{number}}]);  }}
      elsif($show =~ s/^(.)//){
	push(@stuff, $1); }}
    push(@refs,
	 (@refs ? ($sep,' ') : ()),
	 ($didref ? @stuff : (['ltx:ref',$$datum{attr},@stuff]))); }
  @refs; }

sub generateURL {
  my($self,$doc,$id)=@_;
  my($object,$location);
  if(($object = $$self{db}->lookup("ID:".$id))
     && ($location = $object->getValue('location'))){
    my $doclocation = $self->siteRelativePathname($doc->getDestination);
    my $pathdir = pathname_directory($doclocation);
    my $url = pathname_relative(($location =~ m|^/| ? $location : '/'.$location),
				($pathdir  =~ m|^/| ? $pathdir  : '/'.$pathdir));
    my $format = $$self{format} || 'xml';
    my $urlstyle = $$self{urlstyle}||'file';
    if($urlstyle eq 'server'){
      $url =~ s/(^|\/)index.\Q$format\E$/$1/; } # Remove trailing index.$format
    elsif($urlstyle eq 'negotiated'){
      $url =~ s/\.\Q$format\E$//; # Remove trailing $format
      $url =~ s/(^|\/)index$/$1/; # AND trailing index
    }
    $url = '.' unless $url;
#    $url .= '/' if ($url ne '.') && ($url =~ /\/$/);
    if(my $fragid = $object->getValue('fragid')){
      $url = '' if ($url eq '.') or ($location eq $doclocation);
      $url .= '#'.$fragid; }
    elsif($location eq $doclocation){
      $url = ''; }
    $url; }
  else {
    $self->note_missing('ID',$id); }}

our $NBSP = pack('U',0xA0);
# Generate the contents of a <ltx:ref> of the given id.
# show is a string containing substrings 'type', 'refnum' and 'title'
# (standing for the type prefix, refnum and title of the id'd object)
# and any other random characters; the
sub generateRef {
  my($self,$doc,$reqid,$reqshow)=@_;
  my $pending='';
  my @stuff;
  # Try the requested show pattern, and if it fails, try a fallback of just the title or refnum
  foreach my $show (($reqshow,  ($reqshow !~ /title/ ? "title" : "refnum"))){
    my $id = $reqid;
    # Start with requested ID, add some from parent(s), if needed/until to make "useful" link content
    while(my $entry = $id && $$self{db}->lookup("ID:$id")){
      if(my @s = $self->generateRef_aux($doc,$entry,$show)){
	push(@stuff,$pending) if $pending;
	push(@stuff,@s);
	return @stuff if $self->checkRefContent(@stuff);
	$pending = $$self{ref_join}; }	# inside/outside this brace determines if text can START with the join.
      $id = $entry->getValue('parent'); }}
  if(@stuff){
    @stuff; }
  else {
    $self->Warn($doc,"failed to generate good ref text for $reqid");
    ("?"); }}

# Check if the proposed content of a <ltx:ref> is "Good Enough"
# (long enough, unique enough to give reader feedback,...)
sub checkRefContent {
  my($self,@stuff)=@_;
  # Length? having _some_ actual text ?
  my $s = text_content(@stuff);
  # Could compare a minum length
  # But perhaps this is better: check that there's some "text", not just symbols!
  $s =~ s/\bin\s+//g;
  ($s =~ /\w/ ? 1 : 0); }

sub text_content { join('',map(text_content_aux($_),@_)); }
sub text_content_aux {
  my($n)=@_;
  my $r = ref $n;
  if(!$r){ $n; }
  elsif($r eq 'ARRAY'){
    my($t,$a,@c)=@$n;
    text_content(@c); }
  elsif($r =~ /^XML::/){
    $n->textContent; }
  else { $n; }}

# Interpret a "Show" pattern for a given DB entry.
# The pattern can contain substrings to be substituted
#   type   => the type prefix (eg Ch. or similar)
#   refnum => the reference number
#   title  => the title.
# and any other random characters which are preserved.
sub generateRef_aux {
  my($self,$doc,$entry,$show)=@_;
  my @stuff=();
  my $OK=0;
  $show =~ s/typerefnum\s*title/title/; # Same thing NOW!!!
  while($show){
    if($show =~ s/^type(\.?\s*)refnum(\.?\s*)//){
      my $frefnum  = $entry->getValue('frefnum') || $entry->getValue('refnum');
      if($frefnum){
	$OK = 1;
	push(@stuff, ['ltx:text',{class=>'tag'},$frefnum]); }}
    elsif($show =~ s/^refnum(\.?\s*)//){
      if(my $refnum = $entry->getValue('refnum')){
	$OK = 1;
	push(@stuff, ['ltx:text',{class=>'tag'},$refnum]); }}
    elsif($show =~ s/^toctitle//){
      my $title = $self->fillInTitle($doc,$entry->getValue('toctitle')||$entry->getValue('title'));
      if($title){
	$OK = 1;
	push(@stuff, ['ltx:text',{class=>'title'},$doc->trimChildNodes($title)]); }}

    elsif($show =~ s/^title//){
      my $title= $self->fillInTitle($doc,$entry->getValue('title'));
      if($title){
	$OK = 1;
	push(@stuff, ['ltx:text',{class=>'title'},$doc->trimChildNodes($title)]); }}
    elsif($show =~ s/^(.)//){
      push(@stuff, $1); }}
  ($OK ? @stuff : ()); }

# Generate a title string for ltx:ref
sub generateTitle {
  my($self,$doc,$id)=@_;
  # Add author, if any ???
  my $string = "";
  while(my $entry = $id && $$self{db}->lookup("ID:$id")){
    my $title  = $self->fillInTitle($doc,$entry->getValue('title'))
      || $entry->getValue('frefnum') || $entry->getValue('refnum');
    $title = $title->textContent if $title && ref $title;
    $title =~ s/^\s+// if $title;
    $title =~ s/\s+$// if $title;
    if($title){
      $string .= $$self{ref_join} if $string;
      $string .= $title; }
    $id = $entry->getValue('parent'); }
  $string; }

# Fill in any embedded ltx:ref's & ltx:cite's within a title
sub fillInTitle {
  my($self,$doc,$title)=@_;
  return unless $title;
  $doc->getDocument->adoptNode($title);
  # Fill in any nested ref's!
  foreach my $ref ($doc->findnodes('descendant::ltx:ref[@idref or @labelref]',$title)){
    next if $ref->textContent;
    my $show = $ref->getAttribute('show');
    $show = $$self{ref_show} unless $show;
    $show = $$self{toc_show} if $show eq 'fulltitle';
    my $refentry;
    if(my $id = $ref->getAttribute('idref')){
      $refentry = $$self{db}->lookup("ID:$id"); }
    elsif(my $label = $ref->getAttribute('labelref')){
      $refentry = $$self{db}->lookup($label);
      if($id = $refentry->getValue('id')){
	$refentry = $$self{db}->lookup("ID:$id"); }
      $show =~ s/^type//;  }	# Since author may have put explicit \S\ref... in! 
    if($refentry){
      $doc->replaceNode($ref,$self->generateRef_aux($doc,$refentry,$show)); }}
  # Fill in (replace, actually) any embedded citations.
  foreach my $bibref ($doc->findnodes('descendant::ltx:bibref',$title)){
    $doc->replaceNode($bibref,$self->make_bibcite($doc,$bibref)); }
  foreach my $break ($doc->findnodes('descendant::ltx:break',$title)){
    $doc->replaceNode($break->parentNode,['ltx:text',{}," "]); }
  $title; }

# ================================================================================
1;

