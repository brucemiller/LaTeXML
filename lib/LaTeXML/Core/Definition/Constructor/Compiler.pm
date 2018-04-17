# /=====================================================================\ #
# |  LaTeXML::Core::Definition::Constructor::Compiler                   | #
# | Compiler for Constructor Control Sequences                          | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Definition::Constructor::Compiler;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Common::XML;
use Scalar::Util qw(refaddr);

# We recognize several special operators:
#  #      #number|name      accesses an argument to or property of the whatsit
#  ? ( )  ?test(if)(else)   a conditional, test
#  & ,    &func(arg,...)    replaces by result of function call
#  < >    <qname attr...>   generates xml tag
#  ^      ^ pattern         floats to where pattern would be allowed
# Each of these can be used literally, if DOUBLED (ie. ## )
# (except ^ ??? ^^ means something special!)

# These recognize the beginnings of value expressions, conditionals, ..
my $VALUE_RE = "(\\#(?!\\#)|\\&[\\w\\:]*\\()";    # [CONSTANT]
my $COND_RE  = "\\?$VALUE_RE";                    # [CONSTANT]
                                                  # Attempt to follow XML Spec, Appendix B
# QName (element tags, attribute names);  Could this also allow expressions?
my $QNAME_RE = "((?:\\p{Ll}|\\p{Lu}|\\p{Lo}|\\p{Lt}|\\p{Nl}|_|:)"    # [CONSTANT]
  . "(?:\\p{Ll}|\\p{Lu}|\\p{Lo}|\\p{Lt}|\\p{Nl}|_|:|\\p{M}|\\p{Lm}|\\p{Nd}|\\.|\\-)*)";
# The special characters
my $SPECIALS = "#?&\\";
# Quoted special characters (or semi-special)
my $QUOTED_SPECIALS = "\\\\\\#|\\\\\\?|\\\\\\(|\\\\\\)|\\\\\\&|\\\\\\,|\\\\\\<|\\\\\\>|\\\\\\\\|\\\\\\%"
  # or special cases: doubled #, &amp;
  . "|\\#\\#|\\&amp;";
# Unquote the above
sub unquote {
  my ($string) = @_;
  $string =~ s/\\(\#|\?|\(|\)|\&|\,|\<|\>|\\|%)/$1/gs;
  $string =~ s/\#\#/\#/gs;
  $string =~ s/\&amp;/\&/gs;
  return $string; }

sub compileConstructor {
  my ($constructor) = @_;
  my $replacement = $$constructor{replacement};
  return sub { } unless $replacement;
  my $cs    = $constructor->getCS;
  my $name  = $cs->getCSName;
  my $nargs = $constructor->getNumArgs;
  local $LaTeXML::Core::Definition::Constructor::CONSTRUCTOR = $constructor;
  local $LaTeXML::Core::Definition::Constructor::NAME        = $name;
  local $LaTeXML::Core::Definition::Constructor::NARGS       = $nargs;
  $name =~ s/\W//g;
  my $uid = refaddr $constructor;
  $name = "LaTeXML::Package::Pool::constructor_" . $name . '_' . $uid;
  my $floats = ($replacement =~ s/^(\^+)\s*//) && $1;    # Grab float marker.
  my ($body, $code, $result);
  eval {
    local $LaTeXML::IGNORE_ERRORS = 1;
    $body = translate_constructor($replacement, $floats);
    # Compile the constructor pattern into an anonymous sub that will construct the requested XML.
    $code =
      # Put the function in the Pool package, so that functions defined there can be used within"
      # And, also that these definitions get cleaned up by the Daemon.
      " package LaTeXML::Package::Pool;\n"
      . "sub $name {\n"
      . "my(" . join(', ', '$document', (map { "\$arg$_" } 1 .. $nargs), '%prop') . ")=\@_;\n"
      . ($floats ? "my \$savenode;\n" : '')
      . $body
      . ($floats ? "\$document->setNode(\$savenode) if defined \$savenode;\n" : '')
      . "}\n"
      . "1;\n";
    $result = eval $code; };

  if (!defined $result) {
    # We can use die in the following code, which will get caught & wrapped "informatively"
    my $msg = $@;
    Error('misdefined', $cs, $LaTeXML::Core::Definition::Constructor::CONSTRUCTOR,
      "Complilation of constructor '" . ToString($cs) . "' failed     ",
      $replacement, $msg);
    my $stuff = slashify($replacement);
    $result = sub {
      LaTeXML::Core::Stomach::makeError($_[0], 'constructor_fail', $stuff); };
    return $result; }
  return \&$name; }

sub translate_constructor {
  my ($constructor, $float) = @_;
  my $code = '';
  local $_ = $constructor;
  while ($_) {
    # ?test(ifclause)(elseclause)
    if (/^$COND_RE/so) {
      my ($bool, $if, $else) = parse_conditional();
      $code .= "if($bool){\n" . translate_constructor($if) . "}\n"
        . ($else ? "else{\n" . translate_constructor($else) . "}\n" : ''); }
    # Processing instruction: <?name a=v ...?>
    elsif (s|^\s*<\?$QNAME_RE||so) {
      my ($pi, $av) = ($1, translate_avpairs());
      $code .= "\$document->insertPI('$pi'" . ($av ? ", $av" : '') . ");\n";
      die "Missing '?>' at '$_'\n" unless s|^\s*\?>||; }
    # Open tag: <name a=v ...> or .../> (for empty element)
    elsif (s|^\s*<$QNAME_RE||so) {
      my ($tag, $av) = ($1, translate_avpairs());
      if ($float) {
        my $floattype = length($float);
        if ($floattype == 1) {
          $code .= "\$savenode=\$document->floatToElement('$tag');\n"; }
        elsif ($floattype == 2) {
          $code .= "\$savenode=\$document->floatToElement('$tag',1);\n"; }
        $float = undef; }
      $code .= "\$document->openElement('$tag'" . ($av ? ", $av" : '') . ");\n";
      $code .= "\$document->closeElement('$tag');\n" if s|^/||;    # Empty element.
      die "Missing '>' at '$_'\n" unless s|^>||; }
    # Close tag: </name>
    elsif (s|^</$QNAME_RE\s*>||so) {
      $code .= "\$document->closeElement('$1');\n"; }
    # Substitutable value: argument, property...
    elsif (/^$VALUE_RE/o) {
      $code .= "\$document->absorb(" . translate_value() . ",\%prop);\n"; }
    # Attribute: a='v'; assigns in current node? [May conflict with random text!?!]
    # FISHY!!!
    elsif (s|^$QNAME_RE\s*=\s*||so) {
      my $key   = $1;
      my $value = translate_string();
      if (defined $value) {
        if ($float) {
          $code .= "\$savenode=\$document->floatToAttribute('$key');\n";
          $float = undef; }
        $code .= "\$document->setAttribute(\$document->getElement,'$key'," . $value . ");\n"; }
      else {    # attr value didn't match value pattern? treat whole thing as random text!
        $code .= "\$document->absorb('" . slashify($key) . "=',\%prop);\n"; } }
    # Else random text
    elsif (s/^((?:$QUOTED_SPECIALS|[^\Q$SPECIALS<\E])+)//so) {
      $code .= "\$document->absorb('" . slashify(unquote($1)) . "',\%prop);\n"; }
    else {
      die "Unrecognized at '$_'\n"; } }
  return $code; }

sub slashify {
  my ($string) = @_;
  $string =~ s/\\/\\\\/g;
  return $string; }

# parse a conditional in a constructor
# Conditionals are of the form ?value(...)(...), or  ?value(...),
# (the else clause may be omitted)
# Return the translated (condition, if clause, else clause)
# where the if and else clauses are the strings encountered; NOT yet translated!
# Note: Signals an error if the pattern can't be matched.
use Text::Balanced;

sub parse_conditional {
  s/^\?//;    # Remove leading "?"
  my $bool = 'ToString(' . translate_value("(") . ')';
  if (my $if = Text::Balanced::extract_bracketed($_, '()')) {
    $if =~ s/^\(//; $if =~ s/\)$//;
    my $else = Text::Balanced::extract_bracketed($_, '()');
    $else =~ s/^\(// if $else; $else =~ s/\)$// if $else;
    return ($bool, $if, $else); }
  else {
    die "Missing if clause at '$_'\n"; } }

# Parse a substitutable value from the constructor (in $_)
# Recognizes the #1, #prop, and also &function(args,...)
# Note: signals an error if no recognizable value was found!
sub translate_value {
  my ($exclude) = @_;
  $exclude = '' unless defined $exclude;
  my $value;
  if (s/^\&([\w\:]*)\(//) {    # Recognize a function call, w/args
    my $fcn  = $1;
    my @args = ();
    while (!/^\s*\)/) {
      my $arg = (/^\s*[\'\"]/ ? translate_string() : translate_value(",)"));
      push(@args, $arg);
      last unless s/^\s*\,\s*//; }
    die "Missing ')' in &$fcn(...) at '$_'\n" unless s/\)//;
    $value = "$fcn(" . join(',', @args) . ")"; }
  elsif (s/^\#(\d+)//) {       # Recognize an explicit #1 for whatsit args
    my $n = $1;
    if (($n < 1) || ($n > $LaTeXML::Core::Definition::Constructor::NARGS)) {
      die "Illegal argument number $n at '$_'\n"; }
    else {
      $value = "\$arg$n" } }
  elsif (s/^\#([\w\-_]+)//) { $value = "\$prop{'$1'}"; }    # Recognize #prop for whatsit properties
  elsif (s/^((?:$QUOTED_SPECIALS|[^\Q$SPECIALS$exclude\E])+)//s) {
    $value = "'" . slashify(unquote($1)) . "'"; }
  else { die "Missing value at '$_'\n"; }
  return $value; }

# Parse a delimited string from the constructor (in $_),
# for example, an attribute value.  Can contain substitutions (above), as if interpolated.
# The result is a string, or undef if no quotes are found.
# NOTE: UNLESS there is ONLY one substituted value, then return the value object.
# This is (hopefully) temporary to handle font objects as attributes.
# The DOM holds the font objects, rather than strings,
# to resolve relative fonts on output.
sub translate_string {
  my @values = ();
  if (s/^\s*([\'\"])//) {
    my $quote = $1;
    while ($_ && !s/^$quote//) {
      if (/^$COND_RE/o) {    # inline conditional; branches should be values
        my ($bool, $if, $else) = parse_conditional();
        my $code = "($bool ?";
        { local $_ = $if; $code .= translate_value(); }
        $code .= ":";
        if ($else) { local $_ = $else; $code .= translate_value(); }
        else       { $code .= "''"; }
        $code .= ")";
        push(@values, $code); }
      elsif (/^$VALUE_RE/o) {
        push(@values, translate_value($quote)); }
      elsif (s/^((?:$QUOTED_SPECIALS|[^\Q$SPECIALS$quote\E])+)//s) {
        push(@values, "'" . slashify(unquote($1)) . "'"); }
      else {
        die "Unrecognized at '$_'\n"; } } }
  if    (!@values)     { return; }
  elsif (@values == 1) { return $values[0]; }
  else { return join('.', (map { (/^\'/ ? $_ : " ToString($_)") } @values)); } }

# Parse a set of attribute value pairs from a constructor pattern,
# substituting argument and property values from the whatsit.
# Special cases:
#  hashes  %[value] the value is expected to return a hash!
#  Conditions are allowed; the branches should also be pairs or hashes
# It is acceptable to match NO pairs, returning an empty bit of code.
sub translate_avpairs {
  my @avs = ();
  s|^\s*||;
  while ($_) {
    if (/^$COND_RE/o) {    # inline conditional; branches can be pairs or hashes
      my ($bool, $if, $else) = parse_conditional();
      my $code = "($bool ? (";
      { local $_ = $if; $code .= translate_avpairs(); }
      $code .= ") : (";
      { local $_ = $else; $code .= translate_avpairs() if $else; }
      $code .= "))";
      push(@avs, $code); }
    elsif (/^%$VALUE_RE/) {    # Hash?  Assume the value can be turned into a hash!
      s/^%//;                  # Eat the "%"
      push(@avs, '%{' . translate_value() . '}'); }
    elsif (s|^$QNAME_RE\s*=\s*||o) {
      my ($key, $value) = ($1, translate_string());
      # Is it ok to assign undef to the attribute if no string?
      push(@avs, "'$key'=>$value"); }    # if defined $value; }
    else {
      last; }
    s|^\s*||; }
  return join(', ', @avs); }

#===============================================================================
1;
