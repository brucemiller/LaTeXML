# -*- mode: Perl -*-
# /=====================================================================\ #
# |  LaTeXML::Core::Dumper                                              | #
# | Support for dumping "images" of State                               | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Dumper;
use strict;
use warnings;
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Common::Error;
use LaTeXML::Core::Token;
use LaTeXML::Core::Tokens;
use LaTeXML::Core::Definition::Expandable;
use LaTeXML::Common::Dimension;
use LaTeXML::Core::List;
use Scalar::Util qw(blessed);
use LaTeXML::Package;
use base (qw(Exporter));
our @EXPORT    = (qw(&Dump));
our @EXPORT_OK = (
  qw(&Dump),
  qw($D0 $G0 $MD0 $MG0 $N0),
  qw($P),
  qw($TA $TB $TE $TM $TP $TS $TSB $TSP $CR),
  qw(&C &L &O &TA &TC &TM &A &T),
  qw(&N &D &G &Md &Mg),
  qw(&E &CD &R &P &Ps &FD &F &RGB),
  qw(&I &Im &Lt &V &Cc &Mc &Sc &Lc &Uc &Dc),
);
our %EXPORT_TAGS = (
  load => [
    qw($D0 $G0 $MD0 $MG0 $N0),
    qw($P),
    qw($TA $TB $TE $TM $TP $TS $TSB $TSP $CR),
    qw(&C &L &O &TA &TC &TM &A &T),
    qw(&N &D &G &Md &Mg),
    qw(&E &CD &R &P &Ps &FD &F &RGB),
    qw(&I &Im &Lt &V &Cc &Mc &Sc &Lc &Uc &Dc),
  ],
);

#======================================================================
# Dump Shorthands
#======================================================================
# Dump files get read by Perl on each run, and the file size affects the speed,
# as well as general directness & efficiency.
# Thus we use very short, Huffman-esque, names for constructors & installers.
# Since calls to these are derived from instanciated objects,
# we can assume validation of the arguments.

sub V  { LaTeXML::Core::State::assign_internal($STATE, 'value',   $_[0], $_[1], 'global'); return; }
sub Cc { LaTeXML::Core::State::assign_internal($STATE, 'catcode', $_[0], $_[1], 'global'); return; }
sub Mc { LaTeXML::Core::State::assign_internal($STATE, 'mathcode', $_[0], $_[1], 'global'); return; }
sub Sc { LaTeXML::Core::State::assign_internal($STATE, 'sfcode',  $_[0], $_[1], 'global'); return; }
sub Lc { LaTeXML::Core::State::assign_internal($STATE, 'lccode',  $_[0], $_[1], 'global'); return; }
sub Uc { LaTeXML::Core::State::assign_internal($STATE, 'uccode',  $_[0], $_[1], 'global'); return; }
sub Dc { LaTeXML::Core::State::assign_internal($STATE, 'delcode', $_[0], $_[1], 'global'); return; }
sub Im  { LaTeXML::Core::State::assign_internal($STATE, 'meaning', $_[0], $_[1], 'global'); return; }
sub I { LaTeXML::Core::State::assign_internal($STATE, 'meaning', $_[0]->getCSName, $_[0], 'global'); return; }

sub Lt {
  my $d = LaTeXML::Core::State::lookupDefinition($STATE, T_CS($_[1]));
  LaTeXML::Core::State::assign_internal($STATE, 'meaning', $_[0], $d, 'global');
  return; }

#======================================================================
our %transchar = (
  '@'  => '\\@', '$'  => '\\\$', "'" => '\\\'', '"' => '\\"', '\\' => "\\\\",    # Slashify
  "\n" => '\\n', "\t" => '\\t',                                                  # Control
                                                                                 #  '\\' => '\\\\'
);

sub transchar {
  my ($char) = @_;
  my $code = ord($char);
  if (defined $transchar{$char}) { return $transchar{$char}; }
  elsif ($code <= 0x20)          { return '".UTF(' . $code . ')."'; }    # Control chars
  elsif ($code <= 0x7F)          { return $char; }                       # graphical, ASCII chars
      #  elsif($code <= 0xFF){ return $char; } # ??? native?, but we want unicode!?!
  elsif ($code <= 0xFF) { return '".UTF(' . $code . ')."'; }    # 8bit, but force into Unicode
                                                                #  elsif($code <= 0xFF){ return 'X'; }
  else                  { return '\x{' . sprintf("%04x", $code) . '}'; } }    # Full blown Unicode

sub Dump {
  my ($object, $for) = @_;
  local $LaTeXML::DUMPING_KEY = $for;
  return dump_rec($object); }

sub dump_rec {
  my ($object) = @_;
  my $type = ref $object;
  if (!defined $object) {
    return 'undef'; }
  elsif (!$type) {
    my $string = "$object";
    # looks_like_number goes too far...
    if ($string =~ /^-?\d+(?:\.\d*)?$/) {
      return $object; }
    elsif ($string eq '\\') {
      return "'\\\\'"; }
    elsif ($string !~ /[^a-zA-Z0-9\@\$#\.,!:;+\-\*\/\?=~_^``\"&\(\)\[\]\<\>\{\}\|% \\]/) { # Only contains simple chars?
      $string =~ s/\\/\\\\/g;
      return "'" . $string . "'"; }    # single quoted string.
    else {                             # Slashify for double quotes & Unicode
          # $string =~ s/([\@\$'"\\])/\\$1/g;                 # Slashify meta characters
          # Control characters?
          # Unicode ?
          # $string = join('', map { (ord($_) > 0x7F
          #       ? '\x{' . sprintf("%04x", ord($_)) . '}'
          #       : $_); }
          #     split(//, $string));
      $string = join('', map { transchar($_); } split(//, $string));
      $string = '"' . $string . '"';
      $string =~ s/^""\.//;
      $string =~ s/\.""$//;
      return $string; } }
  elsif ($type eq 'ARRAY') {
    return dump_array($object); }
  elsif ($type eq 'HASH') {
    return dump_hash($object); }
  elsif ($type eq 'CODE') {
    Warn('unexpected', $type, undef, "Trying to dump $object in $LaTeXML::DUMPING_KEY")
      if $LaTeXML::DUMPING_KEY;
    return; }
  elsif (!blessed($object)) {
    Warn('unexpected', $type, undef, "Trying to dump $object within $LaTeXML::DUMPING_KEY")
      if $LaTeXML::DUMPING_KEY;
    return; }
  elsif ($object->isa('LaTeXML::Common::Number')) {
    return dump_number($object); }
  elsif ($object->isa('LaTeXML::Core::Token')) {
    return dump_token($object); }
  elsif ($object->isa('LaTeXML::Core::Tokens')) {
    return dump_tokens($object); }
  elsif ($object->isa('LaTeXML::Common::Font')) {
    return dump_font($object); }
  elsif ($object->isa('LaTeXML::Common::Color')) {
    return dump_color($object); }
  elsif ($object->isa('LaTeXML::Core::Parameter')) {
    return dump_parameter($object); }
  elsif ($object->isa('LaTeXML::Core::Parameters')) {
    return dump_parameters($object); }
  elsif ($object->isa('LaTeXML::Core::Definition::Expandable')) {
    return dump_expandable($object); }
  elsif ($object->isa('LaTeXML::Core::Definition::FontDef')) {
    return dump_fontdef($object); }
  elsif ($object->isa('LaTeXML::Core::Definition::CharDef')) {
    return dump_chardef($object); }
  elsif ($object->isa('LaTeXML::Core::Definition::Register')) {
    return dump_register($object); }
  elsif ($object->isa('LaTeXML::Core::Definition::Primitive')) {
    return dump_primitive($object); }
  else {
    Warn('unexpected', $type, undef, "Trying to dump $object within $LaTeXML::DUMPING_KEY",
      'Object is ' . Stringify($object))
      if $LaTeXML::DUMPING_KEY;
    return;
  }
  return; }

#======================================================================
# Dumpers for the various objects
#======================================================================
sub XXXdump_array {
  my ($object) = @_;
  return '[' . join(',', map { dump_rec($_); } @$object) . ']'; }

sub dump_array {
  my ($array) = @_;
  my $prev;
  my @dump = ();
  my $rep  = 0;
  foreach my $item (@$array) {
    my $dump = dump_rec($item);
    if (!defined $prev) {
      $prev = $dump; $rep = 1; }
    elsif ($dump eq $prev) {
      $rep++; }
    else {
      push(@dump, ($rep > 1 ? "($prev) x $rep" : $prev));
      $rep = 1; $prev = $dump; } }
  push(@dump, ($rep > 1 ? "($prev) x $rep" : $prev)) if defined $prev;
  return '[' . join(',', @dump) . ']'; }

sub dump_hash {
  my ($object) = @_;
  return '{' . join(',', map { dump_rec($_) . '=>' . dump_rec($$object{$_}); } sort keys %$object) . '}'; }

#======================================================================
# Number, Dimension, Glue, MuDimension, MuGlue
my %zname = (Number => 'N0', Dimension => 'D0', Glue => 'G0', MuDimension => 'MD0', MuGlue => 'MG0');
my %qname = (Number => 'N', Dimension => 'D', Glue => 'G', MuDimension => 'Md', MuGlue => 'Mg');
our $N0  = Number(0);
our $D0  = Dimension(0);
our $G0  = Glue(0, 0, 0, 0, 0);
our $MD0 = MuDimension(0);
our $MG0 = MuGlue(0, 0, 0, 0, 0);
sub N  { return bless [$_[0]], 'LaTeXML::Common::Number'; }
sub D  { return bless [$_[0]], 'LaTeXML::Common::Dimension'; }
sub G  { return bless [@_], 'LaTeXML::Common::Glue'; }
sub Md { return bless [$_[0]], 'LaTeXML::Core::MuDimension'; }
sub Mg { return bless [@_], 'LaTeXML::Core::MuGlue'; }

sub dump_number {
  my ($num) = @_;
  my $type = ref $num;
  $type =~ /::(\w+)$/;
  my $name = $1;
  my $f    = $qname{$name} || $name;
  my @comp = @$num;
  if (!grep { (defined $_) && ($_ != 0); } $comp[0], $comp[1], $comp[3]) {    # Zero?
    return '$' . $zname{$name}; }                                             # use constant
  return $f . '(' . join(',', map { dump_rec($_); } @comp) . ')'; }

#======================================================================
# Token & Tokens
our @CATCODE_TYPE =    #[CONSTANT]
  qw(??Escape $TB $TE $TM
  $TA ??EOL $TP $TSP
  $TSB ??Ignore $TS L?
  O? TA? TC? ??Invalid
  C? TM? A? ??NoExpand1);
our $TA  = T_ALIGN;
our $TB  = T_BEGIN;
our $TE  = T_END;
our $TM  = T_MATH;
our $TP  = T_PARAM;
our $TS  = T_SPACE;
our $CR  = Token("\n", 10);
our $TSB = T_SUB;
our $TSP = T_SUPER;
sub C  { return bless [$_[0], CC_CS],      'LaTeXML::Core::Token'; }
sub L  { return bless [$_[0], CC_LETTER],  'LaTeXML::Core::Token'; }
sub O  { return bless [$_[0], CC_OTHER],   'LaTeXML::Core::Token'; }
sub TA { return bless [$_[0], CC_ACTIVE],  'LaTeXML::Core::Token'; }
sub TC { return bless [$_[0], CC_COMMENT], 'LaTeXML::Core::Token'; }
sub TM { return bless [$_[0], CC_MARKER],  'LaTeXML::Core::Token'; }
sub A  { return bless [$_[0], CC_ARG],     'LaTeXML::Core::Token'; }
sub T  { return bless [@_], 'LaTeXML::Core::Tokens'; }

sub dump_token {
  my ($token) = @_;
  my ($string, $cc, $other) = @$token;
  my $fstring = (defined $string ? dump_rec($string) : undef);
  my $f       = $CATCODE_TYPE[$cc] || '??Unknown';
  if ($other) {    # !!! Shouldn't happen, but...
    Debug("Got Special Token " . Stringify($_[0]));
    return 'bless([' . $fstring . ',' . $cc . ',' . dump_rec($other) . '],\'LaTeXML::Core::Token\')'; }
  elsif (($cc == CC_SPACE) && ($string eq "\n")) {
    return '$CR'; }
  elsif ($f =~ s/\?$//) {    # gets arg
    return $f . '(' . $fstring . ')'; }
  elsif (($f !~ /^\?\?/)
    && !((defined $string) &&
      ($string ne ($LaTeXML::Core::Token::CATCODE_STANDARDCHAR[$cc] || '')))) {
    return $f; }
  else {
    return 'Token(' . $fstring . ',' . $cc . ')'; } }

sub dump_tokens {
  my ($tokens) = @_;
  return 'T(' . join(',', map { dump_rec($_); } @$tokens) . ')'; }

#======================================================================
# Fonts, Colors
sub F {
  return LaTeXML::Common::Font->new_internal(@_); }

sub RGB {
  my ($r, $g, $b) = @_;
  return bless ['rgb', $r, $g, $b], 'LaTeXML::Common::Color::rgb'; }

sub dump_font {
  my ($font) = @_;
  # Likely never shows in dump file, but need for bookkeeping (compare predump to dump)
  return 'F(' . join(',', map { dump_rec($_); } @$font) . ')'; }

sub dump_color {
  my ($color) = @_;
  # Likely never shows in dump file, but need for bookkeeping (compare predump to dump)
###  return 'RGB(' . join(',', map { dump_rec($_); } $color->rgb->components) . ')'; }
  my @c = $color->rgb->components;
  return ((grep @c) ? 'RGB(' . join(',', map { dump_rec($_); } @c) . ')' : 'Black'); }

#======================================================================
# Parameter & Parameters
our $P = LaTeXML::Core::Parameter->new('Plain', '{}');
sub P  { return LaTeXML::Core::Parameter->new(@_); }
sub Ps { return bless [@_], 'LaTeXML::Core::Parameters'; }

sub dump_parameter {
  my ($parameter) = @_;
  my $type        = $$parameter{type};
  my $spec        = $$parameter{spec};
  if ($type eq 'Plain') {
    return '$P'; }
  $spec =~ s/\\/\\\\/g if $spec;
  # options: extra, novalue
  my $options = '';
  if ($$parameter{novalue}) {
    $options .= ',novalue=>1'; }
  if (my $extra = $$parameter{extra}) {
    $options .= ',extra=>' . dump_rec($extra); }
  return 'P(' . dump_rec($type) . ',' . dump_rec($spec) . $options . ')'; }

sub dump_parameters {
  my ($parameters) = @_;
  return 'Ps(' . join(',', map { dump_rec($_); } @$parameters) . ')'; }

#======================================================================
# Various Definitions
sub E {
  my ($cs, $parameters, $expansion, %traits) = @_;
  return bless { cs => $cs, parameters => $parameters, expansion => $expansion,
    locator => $LaTeXML::LOCATOR,
    %traits }, 'LaTeXML::Core::Definition::Expandable'; }

sub FD {
  my ($cs, $fontID) = @_;
  return LaTeXML::Core::Definition::FontDef->new($cs, $fontID,
     locator => $LaTeXML::LOCATOR); }

sub CD {
  my ($cs, $mode, $value) = @_;
  return bless { cs => $cs, parameters => undef,
    mode         => $mode,    value    => $value,
    registerType => 'Number', readonly => 1,
    locator      => $LaTeXML::LOCATOR,
  }, 'LaTeXML::Core::Definition::CharDef'; }

sub R {
  my ($cs, $parameters, %traits) = @_;
  $traits{address} = ToString($cs) unless defined $traits{address};
  return bless { cs => $cs, parameters => $parameters,
    locator => $LaTeXML::LOCATOR,
    %traits }, 'LaTeXML::Core::Definition::Register'; }

sub dump_expandable {
  my ($object) = @_;
  return unless ((ref $$object{expansion}) || 'notcode') ne 'CODE';
  my $expansion = $object->getExpansion;
  return 'E(' . join(',',
    dump_rec($$object{cs}),
    dump_rec($$object{parameters}),
    dump_rec($expansion),
    (grep { $_; } map { ($$object{$_} ? $_ . '=>1' : ()); }
        qw(isProtected isOuter isLong))
  ) . ')'; }

sub dump_fontdef {
  my ($object) = @_;
  return 'FD(' . join(',', dump_rec($$object{cs}),
    dump_rec($$object{fontID})) . ')'; }

sub dump_chardef {
  my ($object) = @_;
  my $role = $$object{role};
  return 'CD(' . join(',',
    dump_rec($$object{cs}),
    dump_rec($$object{mode}),
    dump_rec($$object{value}),) . ')'; }

sub dump_register {
  my ($object) = @_;
  return if ($$object{getter} || $$object{setter});
  my $name = $$object{name};
  return 'R(' . join(',',
    dump_rec($$object{cs}),
    dump_rec($$object{parameters}),
    'registerType=>' . dump_rec($$object{registerType}),
    'name=>' . dump_rec($name),
    'default=>' . dump_rec($$object{default}),
    'address=>' . dump_rec($$object{address}),
    (grep { $_; } map { ($$object{$_} ? $_ . '=>1' : ()); }
        qw(readonly))) . ')'; }

sub dump_primitive {
  my ($object) = @_;
  # Really can only dump \font primitives?
  if ($$object{font} && !ref $$object{replacement}) {    # only changes font? defined by \font
    return 'FD(' . dump_rec($$object{cs}) . ')'; }
  else {
    return; } }
#======================================================================

1;

