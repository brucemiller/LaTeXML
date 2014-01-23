# /=====================================================================\ #
# |  LaTeXML::Pre::BibTeX::Entry                                        | #
# | Implements BibTeX for LaTeXML                                       | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Pre::BibTeX::Entry;
use strict;
use warnings;

sub new {
  my ($class, $type, $key, $fields, $rawfields) = @_;
  my $self = { type => $type, key => $key,
    fieldlist => $fields, rawfieldlist => $rawfields,
    fieldmap    => { map { ($$_[0] => $$_[1]) } @$fields },
    rawfieldmap => { map { ($$_[0] => $$_[1]) } @$rawfields } };
  bless $self, $class;
  return $self; }

sub getType {
  my ($self) = @_;
  return $$self{type}; }

sub getKey {
  my ($self) = @_;
  return $$self{key}; }

sub getFields {
  my ($self) = @_;
  return @{ $$self{fieldlist} }; }

sub getField {
  my ($self, $key) = @_;
  return $$self{fieldmap}{$key}; }

sub getRawField {
  my ($self, $key) = @_;
  return $$self{rawfieldmap}{$key}; }

sub addField {
  my ($self, $field, $value) = @_;
  push(@{ $$self{fieldlist} }, [$field, $value]);
  $$self{fieldmap}{$field} = $value;
  return; }

sub addRawField {
  my ($self, $field, $value) = @_;
  push(@{ $$self{rawfieldlist} }, [$field, $value]);
  $$self{rawfieldmap}{$field} = $value;
  return; }

sub prettyPrint {
  my ($self) = @_;
  return join(",\n",
    "@" . $$self{type} . "{" . $$self{key},
    (map { (" " x (10 - length($$_[0]))) . $$_[0] . " = {" . $$_[1] . "}" }
        @{ $$self{fieldlist} })
    ) . "}\n"; }

#======================================================================
1;
