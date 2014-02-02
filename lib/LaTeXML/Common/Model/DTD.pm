# /=====================================================================\ #
# |  LaTeXML::Common::Model::DTD                                        | #
# | Extract Model information from a DTD                                | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Model::DTD;
use strict;
use warnings;
use LaTeXML::Util::Pathname;
use LaTeXML::Global;
use LaTeXML::Common::Error;
use LaTeXML::Common::XML;

#**********************************************************************
# NOTE: Arglist is DTD specific.
# Effectively asks for DTD submodel.
sub new {
  my ($class, $model, $roottag, $publicid, $systemid) = @_;
  my $self = { model => $model, roottag => $roottag, public_id => $publicid, system_id => $systemid };
  bless $self, $class;
  return $self; }

# Question: if we don't have a doctype, can we rig the queries to
# let it build a `reasonable' document?

# This is responsible for setting any DocType, and adding any
# required namespace declarations to the root element.
sub addSchemaDeclaration {
  my ($self, $document, $tag) = @_;
  $document->getDocument->createInternalSubset($tag, $$self{public_id}, $$self{system_id});
  return; }

#**********************************************************************
# DTD Analysis
#**********************************************************************
# Uses XML::LibXML to read in the DTD. Then extracts a simplified
# model: which elements can appear within each element, ignoring
# (for now) the ordering, repeat, etc, of the elements.
# From this, and the Tag declarations of autoOpen (that an
# element can be opened automatically, if needed) we derive an implicit model.
# Thus, if we want to insert an element (or, say #PCDATA) into an
# element that doesn't allow it, we may find an implied element
# to create & insert, and insert the #PCDATA into it.

my $NAME_re = qr/[a-zA-Z0-9\-\_\:]+/;    # [CONSTANT]

sub loadSchema {
  my ($self) = @_;
  $$self{schema_loaded} = 1;
  NoteBegin("Loading DTD " . $$self{public_id} || $$self{system_id});
  my $model = $$self{model};
  $model->addTagContent('#Document', $$self{roottag}) if $$self{roottag};
  # Parse the DTD
  my $dtd = $self->readDTD;
  return unless $dtd;

  NoteBegin("Analyzing DTD");
  # Extract all possible namespace attributes
  foreach my $node ($dtd->childNodes()) {
    if ($node->nodeType() == XML_ATTRIBUTE_DECL) {
      if ($node->toString =~ /^<!ATTLIST\s+($NAME_re)\s+($NAME_re)\s+(.*)>$/) {
        my ($tag, $attr, $extra) = ($1, $2, $3);
        if ($attr =~ /^xmlns(:($NAME_re))?$/) {
          my $prefix = ($1 ? $2 : '#default');
          my $ns;
          if ($extra =~ /^CDATA\s+#FIXED\s+(\'|\")(.*)\1\s*$/) {
            $ns = $2; }
          # Just record prefix, not element??
          $model->registerDocumentNamespace($prefix, $ns); } } } }

  # Extract all possible children for each tag.
  foreach my $node ($dtd->childNodes()) {
    if ($node->nodeType() == XML_ELEMENT_DECL) {
      my $decl = $node->toString();
      chomp($decl);
      if ($decl =~ /^<!ELEMENT\s+($NAME_re)\s+(.*)>$/) {
        my ($tag, $content) = ($1, $2);
        $content =~ s/[\+\*\?\,\(\)\|]/ /g;
        $content =~ s/\s+/ /g; $content =~ s/^\s+//; $content =~ s/\s+$//;
        $model->addTagContent($model->recodeDocumentQName($tag),
          ($content eq 'EMPTY'
            ? ()
            : map { $model->recodeDocumentQName($_) } split(/ /, $content))); }
      else {
        Warn('misdefined', $decl, undef, "Can't process DTD declaration '$decl'"); } }

    elsif ($node->nodeType() == XML_ATTRIBUTE_DECL) {
      if ($node->toString =~ /^<!ATTLIST\s+($NAME_re)\s+($NAME_re)\s+(.*)>$/) {
        my ($tag, $attr, $extra) = ($1, $2, $3);
        if ($attr !~ /^xmlns/) {
          $model->addTagAttribute($model->recodeDocumentQName($tag),
            ($attr =~ /:/ ? $model->recodeDocumentQName($attr) : $attr));
        } } }
  }
  NoteEnd("Analyzing DTD");    # Done analyzing
  NoteEnd("Loading DTD " . $$self{public_id} || $$self{system_id});
  return; }

sub readDTD {
  my ($self) = @_;
  LaTeXML::Common::XML::initialize_catalogs();

  NoteBegin("Loading DTD for $$self{public_id} $$self{system_id}");
  # NOTE: setting XML_DEBUG_CATALOG makes this Fail!!!
  my $dtd = XML::LibXML::Dtd->new($$self{public_id}, $$self{system_id});
  if ($dtd) {
    NoteProgress(" via catalog "); }
  else {    # Couldn't find dtd in catalog, try finding the file. (search path?)
    my $dtdfile = pathname_find($$self{system_id},
      paths               => $STATE->lookupValue('SEARCHPATHS'),
      installation_subdir => 'resources/DTD');
    if ($dtdfile) {
      NoteProgress(" from $dtdfile ");
      $dtd = XML::LibXML::Dtd->new($$self{public_id}, $dtdfile);
      NoteProgress(" from $dtdfile ") if $dtd;
      Error('misdefined', $$self{system_id}, undef,
        "Parsing of DTD \"$$self{public_id}\" \"$$self{system_id}\" failed")
        unless $dtd;
    }
    else {
      Error('missing_file', $$self{system_id}, undef,
        "Can't find DTD \"$$self{public_id}\" \"$$self{system_id}\""); } }
  return $dtd; }

#======================================================================
1;

__END__

=head1 NAME

C<LaTeXML::Common::Model::DTD> - represents DTD document models;
extends L<LaTeXML::Common::Model>.

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
