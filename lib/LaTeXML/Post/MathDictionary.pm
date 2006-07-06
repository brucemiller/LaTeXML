# /=====================================================================\ #
# |  LaTeXML::Post::MathDictionary                                      | #
# | Dictionary of Math `names' to semantic properties                   | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
# ================================================================================
# LaTeXML::Post::MathDictionary
#  A Mapping of math token names
# to properties such as
#     partOfSpeech (POS)
#     signature (?) : the grammar rules that should apply to argments when used the token is applied
#       but also/eventually type signature ?

# ================================================================================
package LaTeXML::Post::MathDictionary;
use strict;
use LaTeXML::Util::Pathname;
use LaTeXML::Post::MathPath;
use XML::LibXML;
use Exporter;
our @EXPORTER= (qw(&Declare));

# ================================================================================

our %POSMAP = ();

sub new {
  my($class)=@_;
  bless {map=>{%POSMAP}}, $class; }


# Hmm, a heirarchy of dictionaries?
#  Default dictionary is from the stuff at end.
#  document specific declarations add a layer
#  some declarations are specific to sections of the doc.

# Either we can ask for a dictionary that applies to a certain
# node, combining the relevant portions based on node ancestry,
# and constructing a `new' dictionary.
# Then we get definitions from that  specific dictionary.
#
# OR we always use the big dictionary, and ask for the meaning
# that would apply to a given $node.  Then we've got to walk up
# the ancestry, until we find a meaning.

# The latter seems time inefficent, the former space inefficient.

# In the former case, we've got to distinguish 2 kinds of object:
#  dictionary_factory and dictionary.

# Hmm...

#   Dictionary: list of hashes associating data with name.
#     go down list returning first found data 
#   DictionaryTree(?):
#    [ factory ? warehouse, aggregator, 
#     hash (on ID) of hashes (name=>meaning)
#     construct a dictionary for a given node based on ancestry.

sub getDocumentDictionary {
  my($doc,$pathname)=@_;
  
  my $dict = LaTeXML::Post::MathDictionary->new(); 
  $dict->loadDocumentDictionary($doc,$pathname);
  $dict; }

sub getNodeDictionary {
  my($self,$doc)=@_;
  $self; }

# ================================================================================
sub loadDocumentDictionary {
  my($dict,$doc,$pathname)=@_;
  my($dir,$name,$ext)=pathname_split($pathname);
  if(my $docdictpath = pathname_find($name,paths=>[$dir], types=>['dict'])){
#    print STDERR "loading dictionary: $docdictpath\n";
    local $LaTeXML::DOCUMENT = $doc;
    if(!defined(do $docdictpath)){
      warn "Failed to process dictionary $docdictpath: $!$@"; }}
}

# ================================================================================
sub Declare {
  my($pattern,%options)=@_;
  my $xpath = constructMathPath($pattern, undeclared=>0,
				label=>$options{label}, refnum=>$options{refnum}, font=>$options{font});
  my $POS  = $options{partOfSpeech};
  my $name = $options{name};
  my $content = $options{content};
  foreach my $math ($LaTeXML::DOCUMENT->findnodes($xpath)){
    next if $math->getAttribute('POS'); # Already declared
    $math->setAttribute('POS',$POS) if defined $POS;
    $math->setAttribute('name',$name) if defined $name;
    if(defined $content){
      map($math->removeChild($_),grep($_ ->nodeType == XML_TEXT_NODE, $math->childNodes));
      $math->appendText($content); }
  }
}
# ================================================================================

# Given the name for a token, return the part_of_speech (if any)
# Typically signifies a terminal for the grammar.
sub getPartOfSpeech {
  my($self,$name)=@_;
  if(defined $name){
    if(($name =~ /^(\+|\-)?(\d*)(\.(\d*))?$/) && ((length $2) || (length($4||'')))){
      'NUMBER'; }
    else {
      $POSMAP{$name}; }}}

# Given the name for a token, return the signature (if any)
# This is a list of the grammar rules that should apply to the
# arguments when this token is applied.
sub signature {
  my($self,$name)=@_;

}

# ================================================================================

sub DefPOS {
  my($name,$pos)=@_;
  $POSMAP{$name}=$pos; }

# ================================================================================

# Relational Operators
foreach my $op (qw(= NotEqual
		   < NotLessThan LessEqual NotLessEqual MuchLess
		   > NotGreaterThan GreaterEqual NotGreaterEqual MuchGreater
		   GreaterLess
		   Approximately NotApproximately ApproximatelyEqual Proportional
		   Identical NotIdentical Similar SimilarEqual Equivalent NotEquivalent
		   Subset NotSubset SubsetEqual NotSubsetEqual
		   Superset NotSuperset SupersetEqual NotSupersetEqual
		   Precedes NotPrecedes PrecedesEqual NotPrecedesEqual
		   Succeeds NotSucceeds SucceedsEqual NotSucceedsEqual

		   SquareImage SquareImageEqual NotSquareImageEqual
		   SquareOriginal SquareOriginalEqual NotSquareOriginalEqual

		   In Contains NotIn
		   Divides 
		  )){
  DefPOS($op,'RELOP');}
foreach my $op (qw(iff)){	# amsmath
  DefPOS($op,'RELOP');}

# Function Application Operators
foreach my $op (qw(ApplyFunction)){
  DefPOS($op,'APPLYOP');}

# Additive Operators
foreach my $op (qw(+ PlusMinus MinusPlus
		   Intersection Union Multiset SquareCap SquareCup Or And SetMinus 
		   bmod)){
  DefPOS($op,'ADDOP');}
foreach my $op (qw(- MinusPlus)){ # ??
  DefPOS($op,'SUBOP');}

# Multiplicative Operators
foreach my $op (qw(* Times Asterisk Star Circle BigCircle Bullet Dot Wreath
		   InvisibleTimes)){
  DefPOS($op,'MULOP');}
foreach my $op (qw(/ Divide Backslash)){
  DefPOS($op,'DIVOP');}
# Hmm, InvisibleTimes should perhaps be times with some invisibility attribute?

DefPOS('^','POWEROP');

# Punctuation
foreach my $op (',', '.', ';'){
  DefPOS($op,'PUNCT');}

# Open, Close and Middle Delimiters
foreach my $op (qw( OPEN \( [ { LeftFloor LeftCeiling LeftAngle)){
  DefPOS($op,'OPEN');}
foreach my $op (qw( CLOSE \) ] } RightFloor RightCeiling RightAngle)){
  DefPOS($op,'CLOSE');}
foreach my $op (qw( MIDDLE)){
  DefPOS($op,'MIDDLE');}
foreach my $op ('|', 'Parallel'){
  DefPOS($op,'VERTBAR');}

# Postfix operators
foreach my $op (qw(!  pmod)){
  DefPOS($op,'POSTFIX');}
DefPOS('PostSubscript','POSTSUBSCRIPT');
DefPOS('PostSuperscript','POSTSUPERSCRIPT');
# These for presentation properties (they are created after parsing)
DefPOS('Subscript','SUBSCRIPT');
DefPOS('Superscript','SUPERSCRIPT');

# Big Operators (with limits)
foreach my $op (qw(Summation Product Coproduct
		NAryIntersection NAryUnion NArySquareCup 
		NAryOr NAryAnd NAryCircledDot NAryCircledTimes NAryCirledPlus NAryCircledMinus)){
  DefPOS($op,'BIGOP');}
# Integral Operators
foreach my $op (qw(Integral DoubleIntegral TripleIntegral 
		   ContourIntegral PrincipalValueIntegral)){
#  DefPOS($op,'INTOP');}
  DefPOS($op,'BIGOP');}
# Limit Operators
foreach my $op (qw(lim liminf limsup inf sup
		   det dim max min)){
#  DefPOS($op,'LIMITOP'); }
  DefPOS($op,'BIGOP'); }
# DLMF Addition
#DefPOS('Residue','LIMITOP');
DefPOS('Residue','BIGOP');

# Arrows.
# (do I need to distinguish left/right?)
foreach my $op (qw(LeftArrow LeftDoubleArrow  LongLeftArrow LongLeftDoubleArrow
		   LeftArrowHook LeftHarpoonBarbUp LeftHarpoonBarbDown )){
  DefPOS($op,'LARROW');}
foreach my $op (qw(RightArrow RightDoubleArrow LongRightArrow LongRightDoubleArrow
		   MapsTo LongRightArrowBar RightWaveArrow
		   RightArrowHook RightHarpoonBarbUp RightHarpoonBarbDown)){
  DefPOS($op,'RARROW');}

foreach my $op (qw(RightHarpoonLeftHarpoon
		   UpArrow UpDoubleArrow DownArrow DownDoubleArrow 
		   UpDownArrow UpDownDoubleArrow
		   NEArrow SEArrow SWArrow NWArrow)){
  DefPOS($op,'ARROW');}
# For DLMF, AS
foreach my $op (qw(LeftRightArrow LeftRightDoubleArrow 
		   LongLeftRightArrow LongLeftRightDoubleArrow)){
  DefPOS($op,'METARELOP');}

# Functions
foreach my $op (qw(RealPart ImaginaryPart Nabla Surd
		   ForAll Exists NotExists Not
		   Partial
		   arccos arcsin arctan arg cos cosh cot coth csc deg 
		   exp gcd hom ker lg ln log  Pr sec 
		   sin sinh tan tanh)){
  DefPOS($op,'FUNCTION');}
# Added for DLMF
foreach my $op (qw(phase sign Wronskian LaplaceTrans VariationalOp)){
  DefPOS($op,'FUNCTION');}

# Superscript operators (operators that can only appear in superscript)
foreach my $op (qw(prime)){
  DefPOS($op,'SUPOP');}

# Known Identifiers
# [removed pi, since it can be different...]
foreach my $op (qw(Infinity hbar
		   Ellipsis CenterEllipsis VerticalEllipsis DiagonalEllipsis
		   EmptySet)){
  DefPOS($op,'ID');}
# Added for DLMF
foreach my $op (qw(Reals Complex NaturalNumbers Integers Polynomial
		  iunit)){
  DefPOS($op,'ID');}

# These identifiers don't get roles, since they never are seen by the Grammar.
# They correspond to math accents applied to a symbol
# (qw(OverHat OverCheck OverBreve OverAcute OverGrave OverTilde OverBar OverArrow
#     OverDot OverDoubleDot OverLine OverBrace
#     UnderLine UnderBrace))

# ================================================================================
# Known not to be known.

my @unknown = (qw(alpha beta gamma delta epsilon varepsilon varepsilon zeta eta theta vartheta
		  iota kappa lambda mu nu xi varpi rho varrho sigma varsigma tau upsilon phi varphi
		  chi psi omega Gamma Delta Theta Lambda Xi Sigma Upsilon Phi Psi Omega
		  
		  aleph ell Weierstrassp InvertedOhm
		  Diamond UpTriangle BigTriangleUp BigTriangleDown TriangleLeft TriangleRight
		  Subgroup NotSubgroup ContainsSubgroup NotContainsSubgroup 
		  SubgroupOrEquals NotSubgroupOrEquals ContainsSubgroupOrEquals NotContainsSubgroupOrEquals
		  CircledPlus CircledMinus CircledTimes CircledDivision CircledDot
		  Dagger DoubleDagger

		  LeftTack RightTack UpTack DownTack
		  Models BowTie Join Smile Frown 
		  Angle
		  Box Diamond Flat Natural Sharp ClubSuit DiamondSuit HeartSuit SpadeSuit
	       ));
# ================================================================================
1;
