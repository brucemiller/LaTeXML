# /=====================================================================\ #
# |  LaTeXML::Post::MakeIndex                                           | #
# | Make an index from scanned indexmark's                              | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Post::MakeIndex;
use strict;
use LaTeXML::Util::Pathname;
use LaTeXML::Common::XML;
use charnames qw(:full);
use base qw(LaTeXML::Post::Collector);

# Options:
#   permuted : Generates a permuted index
#              The phrases (separated by ! in LaTeX) within each \index entry
#              are permuted before adding to the index tree.
#   split  : whether the split into separate pages by initial.
sub new {
  my($class,%options)=@_;
  my $self = $class->SUPER::new(%options);
  $$self{permuted} = $options{permuted};
  $$self{split}    = $options{split};
  $self; }

sub process {
  my($self,$doc)=@_;
  my($index,$tree);
  if($index = $doc->findnode('//ltx:index')){
    $doc->addDate();
    my($allkeys,$tree)= $self->build_tree($doc,$index);
    if($tree){
      if($$self{split}){
	map($self->rescan($_),
	    $self->makeSubCollectionDocuments($doc,$index,
					      map( ($_=>$self->makeIndexList($doc,$allkeys,$$tree{subtrees}{$_})),
						   keys %{$$tree{subtrees}}))); }
      else {
	$doc->addNodes($index,$self->makeIndexList($doc,$allkeys,$tree));
	$self->rescan($doc); }}
    else { $doc; }}
  else { $doc; }}

# ================================================================================
# Extracting a tree of index entries from the database
sub build_tree {
  my($self,$doc,$index)=@_;
  if(my @keys = grep(/^INDEX:/,$$self{db}->getKeys)){
    $self->Progress($doc,"processing ".scalar(@keys)." index entries");
#    my $id = $doc->getDocumentElement->getAttribute('xml:id');
    my $id = $index->getAttribute('xml:id');
    my $allkeys={''=>{id=>$id,phrases=>[]}};
    my $tree = {subtrees=>{},referrers=>{}, id=>$id};
    foreach my $key (@keys){
      my $entry = $$self{db}->lookup($key);
      # my $phrases = $entry->getValue('phrases');
      # my $xml = $doc->getDocument->adoptNode($phrases);
      # my @phrases = $doc->findnodes('ltx:indexphrase',$xml);
      # if(!scalar(@phrases)){
      # 	$self->Warn($doc,"Missing phrases in indexmark: $key");
      # 	next; }

      my $phrases = $entry->getValue('phrases');
      my @phrases = @$phrases;
      map($doc->getDocument->adoptNode($_), @phrases);
      if(!scalar(@phrases)){
	$self->Warn($doc,"Missing phrases in indexmark: $key");
	next; }

      if($$self{permuted}){
	map( $self->add_entry($doc,$allkeys,$tree,$entry,@{$_}), cyclic_permute(@phrases)); }
      else {
	$self->add_entry($doc,$allkeys,$tree,$entry,@phrases); }}
    ($allkeys,$tree); }
  else { (undef,undef); }}

# NOTE: We're building ID's for each entry, of the form idx.key.key...
# I'd like to insert the initial in the case of split index: idx.A.key.key...
# But this makes it impossible to predict the id of a phrase key, w/o knowing
# whether the index has been split!
# OTOH, leaving it out risks that a single letter entry, say "A", will have the
# same id as the A page! (or maybe not if the key is downcased....)
sub add_entry {
  my($self,$doc,$allkeys,$tree,$entry,@phrases)=@_;
  # NOTE: Still need option for splitting!
  # We'll just prefix a level for the initial...
  if($$self{split}){
    my $init = $doc->initial($phrases[0]->getAttribute('key'));
    my $subtree = $$tree{subtrees}{$init};
    if(!$subtree){
      $subtree = $$tree{subtrees}{$init}
	= {phrase=>$init,subtrees=>{},referrers=>{}, id=>$$tree{id}}; }
    add_rec($doc,$allkeys,$subtree,$entry,@phrases); }
  else {
    add_rec($doc,$allkeys,$tree,$entry,@phrases); }}

sub add_rec {
  my($doc,$allkeys,$tree,$entry,@phrases)=@_;
  if(@phrases){
    my $phrase = shift(@phrases);
    my $key = $phrase->getAttribute('key');
    my $id  = $$tree{id}.'.'.$key;
    my $subtree = $$tree{subtrees}{$key};
    if(!$subtree){		# clone the phrase ??
      my $fullkey = ($$tree{key} ? "$$tree{key}.":'').$key;
      $subtree = $$tree{subtrees}{$key} = {key=>$fullkey, id=>$id,
					   phrase=>$phrase->cloneNode(1),
					   subtrees=>{},referrers=>{}}; 
      $$allkeys{$fullkey}={id=>$id,
			   phrases=>[($$tree{key} ? @{$$allkeys{$$tree{key}}{phrases}}:())," ",
				     $doc->trimChildNodes($phrase->cloneNode(1))]};
      }
    add_rec($doc,$allkeys,$subtree,$entry,@phrases); }
  else {
    if(my $seealso = $entry->getValue('see_also')){
      $$tree{see_also} = $seealso; }
    if(my $refs = $entry->getValue('referrers')){
      map($$tree{referrers}{$_}=$$refs{$_}, keys %$refs); }}}

# ================================================================================
# Generate permutations of indexing phrases.
sub permute {
  my(@l)=@_;
  if(scalar(@l) > 1){ map( permute_aux($l[$_], @l[0..$_-1],@l[$_+1..$#l]), 0..$#l); }
  else { [@l]; }}

sub permute_aux {
  my($first,@rest)=@_;
  map([$first,@$_], permute(@rest)); }

# Or would cyclic permutations be more appropriate?
#  We could get odd orderings, if authors aren't consistent,
# but would avoid silly redundancies in small top-level listings.
sub cyclic_permute {
  my(@l)=@_;
  if(scalar(@l) > 1){ map( [@l[$_..$#l],@l[0..$_-1]], 0..$#l); }
  else { [@l]; }}

# ================================================================================
# Formatting the resulting index tree.

# Sorting comparison that puts different cases together
sub alphacmp {
  (lc($a) cmp lc($b)) || ($a cmp $b); }

sub makeIndexList {
  my($self,$doc,$allkeys,$tree)=@_;
  my $subtrees =$$tree{subtrees};
  if(my @keys = sort alphacmp keys %$subtrees){
    ['ltx:indexlist',{}, map($self->makeIndexEntry($doc,$allkeys,$$subtrees{$_}), @keys)]; }
  else {
    (); }}

sub makeIndexEntry {
  my($self,$doc,$allkeys,$tree)=@_;
  my $refs   = $$tree{referrers};
  my $seealso= $$tree{see_also};
  my @links = ();
   # Note sort of keys here is questionable!
  if(keys %$refs){
    push(@links,conjoin(map($self->makeIndexRefs($doc,$_,sort alphacmp keys %{$$refs{$_}}),
				 sort alphacmp keys %$refs))); }
  if($seealso){
    my @missing = sort grep(!$$allkeys{$_},map($_->getAttribute('key'),@$seealso));
    $self->Warn($doc,"Missing index see-also terms (under $$tree{key}) : ".join(', ',@missing)) if @missing;
    foreach my $see (@$seealso){
      push(@links, ', ');# if @links;
      if(my $name = $see->getAttribute('name')){
	push(@links, ['ltx:text',{font=>'italic'},$name],' '); }
      if(my $entry = $$allkeys{$see->getAttribute('key')}){
	push(@links,['ltx:ref',{idref=>$$entry{id}},$see->childNodes]); }
      else {
	push(@links,['ltx:text',{}, $see->childNodes]); }}}

  ['ltx:indexentry',{'xml:id'=>$$tree{id}},
   ['ltx:indexphrase',{},$doc->trimChildNodes($$tree{phrase})],
   (@links ? (['ltx:indexrefs',{},@links]):()),
   $self->makeIndexList($doc,$allkeys,$tree)]; }

# Given that sorted styles gives bold, italic, normal,
# let's just do the first.
sub makeIndexRefs {
  my($self,$doc,$id,@styles)=@_;
  ((($styles[0]||'normal') ne 'normal')
   ? ['ltx:text',{font=>$styles[0]},['ltx:ref',{idref=>$id}]]
   : ['ltx:ref',{idref=>$id}]); }

# ================================================================================
sub conjoin {
  my(@items)=@_;
  my @result=();
  if(@items){
    push(@result,shift(@items));
    while(@items){
      push(@result,", ",shift(@items)); }}
  @result; }
 
# ================================================================================
1;

