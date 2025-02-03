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
  qw($D0 $G0 $MD0 $MG0 $N0),
  qw($PPLAIN),
  qw($TA $TB $TE $TM $TP $TS $TSB $TSP),
  qw(&Dump &_Exp &_CDef &_Reg &_Par &_Pars &_FDef),
);
our %EXPORT_TAGS = (
  load => [
    qw($D0 $G0 $MD0 $MG0 $N0),
    qw($PPLAIN),
    qw($TA $TB $TE $TM $TP $TS $TSB $TSP),
    qw(&_Exp &_CDef &_Reg &_Par &_Pars &_FDef),
  ],
);

# Experimenal analogue to TeX's format or "pool" maker;
# It saves the changes to STATE due to loading a package or binding.
# Note that although it supports closures within the stored values,
# it does NOT arrange for subs defined separately in a blnding to be saved.
#======================================================================
# Shorthand constants
our $D0     = Dimension(0);
our $G0     = Glue(0, 0, 0, 0, 0);
our $MD0    = MuDimension(0);
our $MG0    = MuGlue(0, 0, 0, 0, 0);
our $N0     = Number(0);
our $PPLAIN = LaTeXML::Core::Parameter->new('Plain', '{}');
our $TA     = T_ALIGN;
our $TB     = T_BEGIN;
our $TE     = T_END;
our $TM     = T_MATH;
our $TP     = T_PARAM;
our $TS     = T_SPACE;
our $TSB    = T_SUB;
our $TSP    = T_SUPER;
#======================================================================
# Shorthand, efficient, object creators for use in Dump'd formats
sub _Exp {
  my ($cs, $parameters, $expansion, %traits) = @_;
  return bless { cs => $cs, parameters => $parameters, expansion => $expansion,
    hasCCARG => ((grep { $$_[1] == CC_ARG; } $expansion->unlist) ? 1 : 0),
    %traits }, 'LaTeXML::Core::Definition::Expandable'; }

sub _CDef {
  my ($cs, $mode, $value) = @_;
  return bless { cs => $cs, parameters => undef,
    mode         => $mode,    value    => $value,
    registerType => 'Number', readonly => 1,
  }, 'LaTeXML::Core::Definition::CharDef'; }
# Register
sub _Reg {
  my ($cs, $parameters, %traits) = @_;
  $traits{address} = ToString($cs) unless defined $traits{address};
  return bless { cs => $cs, parameters => $parameters,
    %traits }, 'LaTeXML::Core::Definition::Register'; }
# Parameter
sub _Par {
  return LaTeXML::Core::Parameter->new(@_); }
# Parameters
sub _Pars {
  my (@paramspecs) = @_;
  return bless [@paramspecs], 'LaTeXML::Core::Parameters'; }

sub _FDef {
  my ($cs, $fontID) = @_;
  return LaTeXML::Core::Definition::FontDef->new($cs, $fontID); }

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
      "'\\\\'"; }
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
    return '[' . join(',', map { dump_rec($_); } @$object) . ']'; }
  elsif ($type eq 'HASH') {
    return '{' . join(',', map { dump_rec($_) . '=>' . dump_rec($$object{$_}); } sort keys %$object) . '}'; }
  elsif ($type eq 'CODE') {
    Warn('unexpected', $type, undef, "Trying to dump $object in $LaTeXML::DUMPING_KEY")
      if $LaTeXML::DUMPING_KEY;
    return; }
  elsif (!blessed($object)) {
    Warn('unexpected', $type, undef, "Trying to dump $object within $LaTeXML::DUMPING_KEY")
      if $LaTeXML::DUMPING_KEY;
    return; }
  elsif ($object->isa('LaTeXML::Core::Token')) {
    return dump_token($object); }
  elsif ($object->isa('LaTeXML::Core::Tokens')) {
    return 'TokensI(' . join(',', map { dump_rec($_); } @$object) . ')'; }
  elsif ($object->isa('LaTeXML::Core::Parameter')) {
    return dump_parameter($object); }
  elsif ($object->isa('LaTeXML::Core::Parameters')) {
    return '_Pars(' . join(',', map { dump_rec($_); } @$object) . ')'; }
  elsif ($object->isa('LaTeXML::Common::Number')) {
    return dump_number($object); }
  elsif ($object->isa('LaTeXML::Core::Definition::Expandable')) {
    return unless ((ref $$object{expansion}) || 'notcode') ne 'CODE';
    my $expansion = $object->getExpansion;
    return '_Exp(' . join(',',
      dump_rec($$object{cs}),
      dump_rec($$object{parameters}),
      dump_rec($expansion),
      (grep { $_; } map { ($$object{$_} ? $_ . '=>1' : ()); }
          qw(isProtected isOuter isLong))
    ) . ')'; }
  elsif ($object->isa('LaTeXML::Core::Definition::FontDef')) {
    return '_FDef(' . join(',', dump_rec($$object{cs}),
      dump_rec($$object{fontID})) . ')'; }
  elsif ($object->isa('LaTeXML::Core::Definition::CharDef')) {
    my $role = $$object{role};
    return '_CDef(' . join(',',
      dump_rec($$object{cs}),
      dump_rec($$object{mode}),
      dump_rec($$object{value}),) . ')'; }
  elsif ($object->isa('LaTeXML::Core::Definition::Register')) {
    return if ($$object{getter} || $$object{setter});
    my $name = $$object{name};
    return '_Reg(' . join(',',
      dump_rec($$object{cs}),
      dump_rec($$object{parameters}),
      'registerType=>' . dump_rec($$object{registerType}),
      'name=>' . dump_rec($name),
      'default=>' . dump_rec($$object{default}),
      'address=>' . dump_rec($$object{address}),
      (grep { $_; } map { ($$object{$_} ? $_ . '=>1' : ()); }
          qw(readonly))) . ')'; }
  elsif ($object->isa('LaTeXML::Core::Definition::Primitive')) {
    # Really can only dump \font primitives?
    if ($$object{font} && !ref $$object{replacement}) {    # only changes font? defined by \font
      return '_FDef(' . dump_rec($$object{cs}) . ')'; }
    else {
      return; } }
  else {
    Warn('unexpected', $type, undef, "Trying to dump $object within $LaTeXML::DUMPING_KEY")
      if $LaTeXML::DUMPING_KEY;
    return;
  }
  return; }

# Dumpers for the various objects

our @CATCODE_TYPE =    #[CONSTANT]
  qw(??Escape $TB $TE $TM
  $TA ??EOL $TP $TSP
  $TSB ??Ignore $TS T_LETTER?
  T_OTHER? T_ACTIVE? T_COMMENT? ??Invalid
  T_CS? T_MARKER? T_ARG? ??NoExpand1);

sub dump_token {
  my ($self) = @_;
  my ($string, $cc, $other) = @$self;
  my $fstring = (defined $string ? dump_rec($string) : undef);
  my $f       = $CATCODE_TYPE[$cc] || '??Unknown';
  if ($other) {    # !!! Shouldn't happen, but...
    Debug("Got Special Token " . Stringify($_[0]));
    return 'bless([' . $fstring . ',' . $cc . ',' . dump_rec($other) . '],\'LaTeXML::Core::Token\')'; }
  elsif ($f =~ s/\?$//) {    # gets arg
    return $f . '(' . $fstring . ')'; }
  elsif (($f !~ /^\?\?/)
    && !((defined $string) &&
      ($string ne ($LaTeXML::Core::Token::CATCODE_STANDARDCHAR[$cc] || '')))) {
    return $f; }
  else {
    return 'Token(' . $fstring . ',' . $cc . ')'; } }

#======================================================================
sub dump_parameter {
  my ($self) = @_;
  my $type   = $$self{type};
  my $spec   = $$self{spec};
  if ($type eq 'Plain') {
    return '$PPLAIN'; }
  $spec =~ s/\\/\\\\/g if $spec;
  # options: extra, novalue
  my $options = '';
  if ($$self{novalue}) {
    $options .= ',novalue=>1'; }
  if (my $extra = $$self{extra}) {
    $options .= ',extra=>' . LaTeXML::Core::Dumper::dump_rec($extra); }
  return '_Par('
    . LaTeXML::Core::Dumper::dump_rec($type) . ','
    . LaTeXML::Core::Dumper::dump_rec($spec)
    . $options . ')'; }

#======================================================================
my %zname = (Number => 'N0', Dimension => 'D0', Glue => 'G0', MuDimension => 'MD0', MuGlue => 'MG0');

sub dump_number {
  my ($self) = @_;
  my $type = ref $self;
  #  return $type . '->new(' . join(',', map { LaTeXML::Core::Dumper::dump_rec($_); } @$self) . ')'; }
  $type =~ /::(\w+)$/;
  my $name = $1;
##  if (!grep { $_ != 0; } @$self) {    # Zero?
  my @comp = @$self;
  if (!grep { (defined $_) && ($_ != 0); } $comp[0], $comp[1], $comp[3]) {    # Zero?
    return '$' . $zname{$name}; }                                             # use constant
  return $name . '(' . join(',', map { LaTeXML::Core::Dumper::dump_rec($_); } @$self) . ')'; }

#======================================================================

1;

