# /=====================================================================\ #
# |  LaTeXML::Post::Manifest::Epub                                      | #
# | Manifest creation for EPUB                                          | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Post::Manifest::Epub;
use strict;
use warnings;
use File::Find qw(find);
use URI::file;

# ensure that we can use xhtml: and epub: in the xpath queries below
$LaTeXML::Post::Document::XPATH->registerNS('xhtml' => 'http://www.w3.org/1999/xhtml');
$LaTeXML::Post::Document::XPATH->registerNS('epub'  => 'http://www.idpf.org/2007/ops');

our $uuid_tiny_installed;

BEGIN {
  my $eval_return = eval {
    local $LaTeXML::IGNORE_ERRORS = 1;
    require UUID::Tiny; 1; };
  if ($eval_return && (!$@)) {
    $uuid_tiny_installed = 1; } }

use base qw(LaTeXML::Post::Manifest);
use LaTeXML::Util::Pathname;
use File::Spec::Functions qw(catdir);
use POSIX qw(strftime);
use LaTeXML::Post;    # for error handling!
our $container_content = <<'EOL';
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
    <rootfiles>
        <rootfile full-path="OPS/content.opf" media-type="application/oebps-package+xml"/>
   </rootfiles>
</container>
EOL

# Core Media Types as per EPUB 3.2 spec
our %CORE_MEDIA_TYPES = (
  'gif'   => 'image/gif',
  'jpg'   => 'image/jpeg',
  'jpeg'  => 'image/jpeg',
  'png'   => 'image/png',
  'svg'   => 'image/svg+xml',
  'mp3'   => 'audio/mpeg',                 # only mp3 is supported
  'mp4'   => 'audio/mp4',                  # only mp4 *audio* is core
  'mpg4'  => 'audio/mp4',
  'css'   => 'text/css',
  'ttf'   => 'font/ttf',
  'otf'   => 'font/otf',
  'woff'  => 'font/woff',
  'woff2' => 'font/woff2',
  'xhtml' => 'application/xhtml+xml',
  'js'    => 'text/javascript',
  'ncx'   => 'application/x-dtbncx+xml',
  'smi'   => 'application/smil+xml',
  'smil'  => 'application/smil+xml',
  'pls'   => 'application/pls+xml'
);

sub new {
  my ($class, %options) = @_;
  my $self = $class->SUPER::new(%options);
  return $self; }

sub initialize {
  my ($self, $doc) = @_;
  my $directory = $$self{siteDirectory};
  # 1. Create mimetype declaration
  my $EPUB_FH;
  my $mime_path = pathname_concat($directory, 'mimetype');
  open($EPUB_FH, ">", $mime_path)
    or Fatal('I/O', 'mimetype', $doc, "Couldn't open '$mime_path' for writing: $!");
  print $EPUB_FH 'application/epub+zip';
  close $EPUB_FH;
  # 2. Create META-INF metadata directory
  my $meta_inf_dir = catdir($directory, 'META-INF');
  mkdir $meta_inf_dir;
  # 2.1. Add the container.xml description
  my $CONTAINER_FH;
  my $container_path = pathname_concat($meta_inf_dir, 'container.xml');
  open($CONTAINER_FH, ">", $container_path)
    or Fatal('I/O', 'container.xml', $doc, "Couldn't open '$container_path' for writing: $!");
  print $CONTAINER_FH $container_content;
  close $CONTAINER_FH;

  # 3. Create OPS content container
  my $OPS_directory = catdir($directory, 'OPS');
  # 3.1 OPS/content.opf XML Spine
  my $opf     = XML::LibXML::Document->new('1.0', 'UTF-8');
  my $package = $opf->createElementNS("http://www.idpf.org/2007/opf", 'package');
  $opf->setDocumentElement($package);
  $package->setAttribute('unique-identifier', 'pub-id');
  $package->setAttribute('version',           '3.0');

  # Metadata
  my $rootentry         = $$self{db}->lookup('SITE_ROOT');
  my $document_metadata = $$self{db}->lookup("ID:" . $rootentry->getValue('id'));
  my $document_title    = $document_metadata->getValue('title');
  $document_title = $document_title ? $document_title->textContent : 'No Title';
  my $document_authors = $document_metadata->getValue('authors') || [];
  $document_authors = [map { $_->textContent } @$document_authors];
  my $document_language = $document_metadata->getValue('language') || 'en';

  # Fish out any existing unique identifier for the book
  #       the UUID is the fallback default
  my $uid = $document_metadata->getValue('dc:identifier') ||
    "urn:uuid:" . _uuid();
  unless (($uid =~ /^urn:/) || pathname_is_url($uid)) {    # Already qualified
    my $type = 'uuid';
    if ($uid =~ /^[\d\- ]+$/) {                            # ISBN
      $type = 'isbn'; }
    elsif ($uid =~ /^[\d\-._\/ ]+$/) {
      $type = 'doi'; }
    $uid = "urn:$type:$uid"; }                             # Set the guessed qualified name
                                                           # Save the identifier
  $$self{'unique-identifier'} = $uid;

  my $metadata = $package->addNewChild(undef, 'metadata');
  $metadata->setNamespace("http://purl.org/dc/elements/1.1/", "dc",  0);
  $metadata->setNamespace("http://www.idpf.org/2007/opf",     'opf', 0);
  my $title = $metadata->addNewChild("http://purl.org/dc/elements/1.1/", "title");
  $title->appendText($document_title);
  foreach my $document_author (@$document_authors) {
    my $author = $metadata->addNewChild("http://purl.org/dc/elements/1.1/", "creator");
    $author->appendText($document_author); }
  my $language = $metadata->addNewChild("http://purl.org/dc/elements/1.1/", "language");
  $language->appendText($document_language);
  my $modified = $metadata->addNewChild(undef, "meta");
  $modified->setAttribute('property', 'dcterms:modified');
  my $now_string = strftime "%Y-%m-%dT%H:%M:%SZ", gmtime;    # CCYY-MM-DDThh:mm:ssZ
  $modified->appendText($now_string);
  my $identifier = $metadata->addNewChild("http://purl.org/dc/elements/1.1/", "identifier");
  $identifier->setAttribute('id', 'pub-id');
  $identifier->appendText($$self{'unique-identifier'});
  # Manifest
  my $manifest = $package->addNewChild(undef, 'manifest');
  # Spine
  my $spine = $package->addNewChild(undef, 'spine');
  # 3.2 OPS/nav.xhtml - default navigation document
  my $nav_path = pathname_concat($OPS_directory, 'nav.xhtml');
  my ($nav, $nav_map) = (undef, undef);
  if (-f $nav_path) {
    Info('note', 'nav.xhtml', undef, 'using the navigation document supplied by the user'); }
  else {
    $nav = XML::LibXML::Document->new('1.0', 'UTF-8');
    my $nav_html = $opf->createElementNS("http://www.w3.org/1999/xhtml", 'html');
    $nav->setDocumentElement($nav_html);
    $nav_html->setNamespace("http://www.idpf.org/2007/ops", "epub", 0);
    my $nav_head  = $nav_html->addNewChild(undef, 'head');
    my $nav_title = $nav_head->addNewChild(undef, 'title');
    $nav_title->appendText($document_title);
    my $nav_body = $nav_html->addNewChild(undef, 'body');
    my $nav_nav  = $nav_body->addNewChild(undef, 'nav');
    $nav_nav->setAttribute('epub:type', 'toc');
    $nav_nav->setAttribute('id',        'toc');
    $nav_map = $nav_nav->addNewChild(undef, 'ol'); }

  $$self{OPS_directory} = $OPS_directory;
  $$self{opf}           = $opf;
  $$self{opf_spine}     = $spine;
  $$self{opf_manifest}  = $manifest;
  $$self{nav}           = $nav;
  $$self{nav_map}       = $nav_map;
  $$self{nav_path}      = $nav_path;
  return; }

sub url_id {
  my ($name) = @_;
  # convert a relative url to a valid NCName for use as id
  # any invalid character is encoded as _xN_ where N is its uppercase hex codepoint
  # underscores starting a sequence of the form _xN_ are encoded as _x5F_
  $name =~ s/_(x[0-9A-F]+)(?=_)/_x5F_$1/g;
  $name =~ s/([^A-Z_a-z\x{C0}-\x{D6}\x{D8}-\x{F6}\x{F8}-\x{2FF}\x{370}-\x{37D}\x{37F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}\-.0-9\x{B7}\x{0300}-\x{036F}\x{203F}-\x{2040}])/_x${\(sprintf("%X", ord($1)))}_/g;
  # ensure the starting char is valid and prevent collisions with the other id's below
  $name = '_' . $name;
  return $name;
}

sub process {
  my ($self, @docs) = @_;
  my $tocfound = 0;
  $self->initialize($docs[0]);
  my $nav_map   = $$self{nav_map};
  my $nav_xhtml = !defined $nav_map;
  foreach my $doc (@docs) {
    # Add each document to the spine manifest
    if (my $destination = $doc->getDestination) {
      my (undef, $name, $ext) = pathname_split($destination);
      my $file                 = "$name.$ext";
      my $relative_destination = pathname_relative($destination, $$self{OPS_directory});

      # Add to manifest
      my $manifest = $$self{opf_manifest};
      my $item     = $manifest->addNewChild(undef, 'item');
      my $item_url = URI::file->new($relative_destination);
      my $item_id  = url_id($item_url);
      $item->setAttribute('id',         $item_id);
      $item->setAttribute('href',       $item_url);
      $item->setAttribute('media-type', "application/xhtml+xml");
      my @properties;
      push @properties, 'mathml' if $doc->findnode('//*[local-name() = "math"]');
      push @properties, 'svg'    if $doc->findnode('//*[local-name() = "svg"]');
      # check if the document contains a toc nav element
      if (!$nav_xhtml && !$tocfound && $doc->findnode('//xhtml:nav[@epub:type = "toc"]')) {
        Info('note', 'tocnav', undef, "found <nav epub:type=\"toc\">, using " . $relative_destination . " as navigation document");
        push @properties, 'nav';
        $tocfound = 1; }
      my $properties = join(" ", @properties);
      $item->setAttribute('properties', $properties) if $properties;

      # Add to spine
      my $spine   = $$self{opf_spine};
      my $itemref = $spine->addNewChild(undef, 'itemref');
      $itemref->setAttribute('idref', $item_id);

      # Add to default navigation document
      if (!$nav_xhtml && !$tocfound) {
        my $nav_li = $nav_map->addNewChild(undef, 'li');
        my $nav_a  = $nav_li->addNewChild(undef, 'a');
        $nav_a->setAttribute('href', URI::file->new($relative_destination));
        map { $nav_a->appendChild($_->cloneNode(1)) }
        $doc->findnodes('/xhtml:html/xhtml:head/xhtml:title/node()'); } } }

  if ($tocfound) {
    # Delete default navigation document
    $$self{nav} = undef; }
  else {
    # Add default navigation document to the manifest
    my $nav_item = $$self{opf_manifest}->addNewChild(undef, 'item');
    $nav_item->setAttribute('id',         'nav');
    $nav_item->setAttribute('href',       'nav.xhtml');
    $nav_item->setAttribute('properties', 'nav');
    $nav_item->setAttribute('media-type', 'application/xhtml+xml'); }

  $self->finalize;
  return; }

sub finalize {
  my ($self) = @_;
  # index all resources that got written to file
  # TODO: recover resources and mime types directly from the documents
  my $OPS_directory = $$self{OPS_directory};
  my @content       = ();
  find({ no_chdir => 1, preprocess => sub { sort @_; },    # sort files for reproducbility
      wanted => sub {
        my $OPS_abspath  = $_;
        my $OPS_pathname = pathname_relative($OPS_abspath, $OPS_directory);
        my (undef, $name, $ext) = pathname_split($OPS_pathname);
        if (-f $OPS_abspath && $ext ne 'xhtml' && "$name.$ext" ne 'LaTeXML.cache' && $OPS_abspath ne 'content.opf') {
          push(@content, $OPS_pathname); }
      } }, $OPS_directory);

  my $manifest = $$self{opf_manifest};
  foreach my $file (@content) {
    my (undef, undef, $ext) = pathname_split($file);
    my $file_type = $CORE_MEDIA_TYPES{ lc($ext) };
    if (!defined $file_type) {
      Info('unexpected', lc($ext), undef, "resource '$file' is not of a core media type, assigning type application/octet-stream");
      $file_type = 'application/octet-stream'; }

    my $file_item = $manifest->addNewChild(undef, 'item');
    my $file_url  = URI::file->new($file);
    $file_item->setAttribute('id',         url_id($file_url));
    $file_item->setAttribute('href',       $file_url);
    $file_item->setAttribute('media-type', $file_type); }

  # Write the content.opf file to disk
  my $directory    = $$self{siteDirectory};
  my $content_path = pathname_concat($OPS_directory, 'content.opf');
  if (-f $content_path) {
    Info('note', 'content.opf', undef, 'using the manifest supplied by the user'); }
  else {
    my $OPF_FH;
    open($OPF_FH, ">", $content_path)
      or Fatal('I/O', 'content.opf', undef, "Couldn't open '$content_path' for writing: $_");
    print $OPF_FH $$self{opf}->toString(1);
    close $OPF_FH; }

  # If present, write the default navigation document to disk
  if (my $nav = $$self{nav}) {
    my $nav_path = $$self{nav_path};
    my $NAV_FH;
    open($NAV_FH, ">", $nav_path)
      or Fatal('I/O', 'nav.xhtml', undef, "Couldn't open '$nav_path' for writing: $!");
    print $NAV_FH $nav->toString(1);
    close $NAV_FH; }

  return (); }

# Less reliable fallback for UUID generation
# Borrowed from: http://stackoverflow.com/a/2117523
sub _uuid {
  if ($uuid_tiny_installed) {
    return UUID::Tiny::create_uuid_as_string(); }
  else {
    my $uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
    $uuid =~ s/([xy])/_uuid_char($1)/eg;
    return $uuid; } }

sub _uuid_char {
  my $c = shift;
  my $r = rand() * 16 | 0;
  my $v = ($c eq 'x') ? $r : ($r & 0x3 | 0x8);
  return sprintf('%x', $v); }
1;
