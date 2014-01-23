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

my $VALUE_RE = "(\\#|\\&[\\w\\:]*\\()";    # [CONSTANT]
my $COND_RE  = "\\?$VALUE_RE";             # [CONSTANT]
                                           # Attempt to follow XML Spec, Appendix B
my $QNAME_RE = "((?:\\p{Ll}|\\p{Lu}|\\p{Lo}|\\p{Lt}|\\p{Nl}|_|:)"    # [CONSTANT]
  . "(?:\\p{Ll}|\\p{Lu}|\\p{Lo}|\\p{Lt}|\\p{Nl}|_|:|\\p{M}|\\p{Lm}|\\p{Nd}|\\.|\\-)*)";
my $TEXT_RE = "(.[^\\#<\\?\\)\\&\\,]*)";                             # [CONSTANT]

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
  my $floats = ($replacement =~ s/^\^\s*//);                 # Grab float marker.
  my $body = translate_constructor($replacement, $floats);
  # Compile the constructor pattern into an anonymous sub that will construct the requested XML.
  my $code =
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
###print STDERR "Compilation of \"$replacement\" => \n$code\n";

  my $result = eval $code;
  Fatal('misdefined', $name, $constructor,
    "Compilation of constructor code for '$name' failed",
    "\"$replacement\" => $code", $@) if !$result || $@;
  return \&$name; }

sub translate_constructor {
  my ($constructor, $float) = @_;
  my $code = '';
  local $_ = $constructor;
  while ($_) {
    if (/^$COND_RE/so) {
      my ($bool, $if, $else) = parse_conditional();
      $code .= "if($bool){\n" . translate_constructor($if) . "}\n"
        . ($else ? "else{\n" . translate_constructor($else) . "}\n" : ''); }
    # Processing instruction: <?name a=v ...?>
    elsif (s|^\s*<\?$QNAME_RE||so) {
      my ($pi, $av) = ($1, translate_avpairs());
      $code .= "\$document->insertPI('$pi'" . ($av ? ", $av" : '') . ");\n";
      Fatal('misdefined', $LaTeXML::Core::Definition::Constructor::NAME, $LaTeXML::Core::Definition::Constructor::CONSTRUCTOR,
        "Missing \"?>\" in constructor template at \"$_\"") unless s|^\s*\?>||; }
    # Open tag: <name a=v ...> or .../> (for empty element)
    elsif (s|^\s*<$QNAME_RE||so) {
      my ($tag, $av) = ($1, translate_avpairs());
      if ($float) {
        $code .= "\$savenode=\$document->floatToElement('$tag');\n";
        $float = undef; }
      $code .= "\$document->openElement('$tag'" . ($av ? ", $av" : '') . ");\n";
      $code .= "\$document->closeElement('$tag');\n" if s|^/||;    # Empty element.
      Fatal('misdefined', $LaTeXML::Core::Definition::Constructor::NAME, $LaTeXML::Core::Definition::Constructor::CONSTRUCTOR,
        "Missing \">\" in constructor template at \"$_\"") unless s|^>||; }
    # Close tag: </name>
    elsif (s|^</$QNAME_RE\s*>||so) {
      $code .= "\$document->closeElement('$1');\n"; }
    # Substitutable value: argument, property...
    elsif (/^$VALUE_RE/o) {
      $code .= "\$document->absorb(" . translate_value() . ",\%prop);\n"; }
    # Attribute: a=v; assigns in current node? [May conflict with random text!?!]
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
    elsif (s/^$TEXT_RE//so) {    # Else, just some text.
      $code .= "\$document->absorb('" . slashify($1) . "',\%prop);\n"; }
  }
  return $code; }

sub slashify {
  my ($string) = @_;
  $string =~ s/\\/\\\\/g;
  return $string; }

# parse a conditional in a constructor
# Conditionals are of the form ?value(...)(...),
# Return the translated condition, along with the strings for the if and else clauses.
use Text::Balanced;

sub parse_conditional {
  s/^\?//;    # Remove leading "?"
  my $bool = 'ToString(' . translate_value() . ')';
  if (my $if = Text::Balanced::extract_bracketed($_, '()')) {
    $if =~ s/^\(//; $if =~ s/\)$//;
    my $else = Text::Balanced::extract_bracketed($_, '()');
    $else =~ s/^\(// if $else; $else =~ s/\)$// if $else;
    return ($bool, $if, $else); }
  else {
    Fatal('misdefined', $LaTeXML::Core::Definition::Constructor::NAME, $LaTeXML::Core::Definition::Constructor::CONSTRUCTOR,
      "Unbalanced conditional in constructor template \"$_\"");
    return; } }

# Parse a substitutable value from the constructor (in $_)
# Recognizes the #1, #prop, and also &function(args,...)
sub translate_value {
  my $value;
  if (s/^\&([\w\:]*)\(//) {    # Recognize a function call, w/args
    my $fcn  = $1;
    my @args = ();
    while (!/^\s*\)/) {
      if   (/^\s*[\'\"]/) { push(@args, translate_string()); }
      else                { push(@args, translate_value()); }
      last unless s/^\s*\,\s*//; }
    Error('misdefined', $LaTeXML::Core::Definition::Constructor::NAME, $LaTeXML::Core::Definition::Constructor::CONSTRUCTOR,
"Missing ')' in &$fcn(...) in constructor pattern for $LaTeXML::Core::Definition::Constructor::NAME")
      unless s/\)//;
    $value = "$fcn(" . join(',', @args) . ")"; }
  elsif (s/^\#(\d+)//) {       # Recognize an explicit #1 for whatsit args
    my $n = $1;
    if (($n < 1) || ($n > $LaTeXML::Core::Definition::Constructor::NARGS)) {
      Error('misdefined', $LaTeXML::Core::Definition::Constructor::NAME, $LaTeXML::Core::Definition::Constructor::CONSTRUCTOR,
        "Illegal argument number $n in constructor for "
          . "$LaTeXML::Core::Definition::Constructor::NAME which takes $LaTeXML::Core::Definition::Constructor::NARGS args");
      $value = "\"Missing\""; }
    else {
      $value = "\$arg$n" } }
  elsif (s/^\#([\w\-_]+)//) { $value = "\$prop{'$1'}"; }    # Recognize #prop for whatsit properties
  elsif (s/$TEXT_RE//so) { $value = "'" . slashify($1) . "'"; }
  return $value; }

# Parse a delimited string from the constructor (in $_),
# for example, an attribute value.  Can contain substitutions (above),
# the result is a string.
# NOTE: UNLESS there is ONLY one substituted value, then return the value object.
# This is (hopefully) temporary to handle font objects as attributes.
# The DOM holds the font objects, rather than strings,
# to resolve relative fonts on output.
sub translate_string {
  my @values = ();
  if (s/^\s*([\'\"])//) {
    my $quote = $1;
    while ($_ && !s/^$quote//) {
      if (/^$COND_RE/o) {
        my ($bool, $if, $else) = parse_conditional();
        my $code = "($bool ?";
        { local $_ = $if; $code .= translate_value(); }
        $code .= ":";
        if ($else) { local $_ = $else; $code .= translate_value(); }
        else       { $code .= "''"; }
        $code .= ")";
        push(@values, $code); }
      elsif (/^$VALUE_RE/o)             { push(@values, translate_value()); }
      elsif (s/^(.[^\#<\?\!$quote]*)//) { push(@values, "'" . slashify($1) . "'"); } } }
  if    (!@values)     { return; }
  elsif (@values == 1) { return $values[0]; }
  else { return join('.', (map { (/^\'/ ? $_ : " ToString($_)") } @values)); } }

# Parse a set of attribute value pairs from a constructor pattern,
# substituting argument and property values from the whatsit.
sub translate_avpairs {
  my @avs = ();
  s|^\s*||;
  while ($_) {
    if (/^$COND_RE/o) {
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
      push(@avs, "'$key'=>$value"); }    # if defined $value; }
    else { last; }
    s|^\s*||; }
  return join(', ', @avs); }

#===============================================================================
1;
