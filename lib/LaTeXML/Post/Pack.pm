# /=====================================================================\ #
# |  LaTeXML::Post::Pack                                                | #
# | Packs the requested output (document, fragment, math, archive)      | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Post::Pack;
use strict;
use warnings;
use LaTeXML::Post;
use base qw(LaTeXML::Post::Processor);

use LaTeXML::Util::Pathname;
use Archive::Zip qw(:CONSTANTS :ERROR_CODES);
use IO::String;

use Data::Dumper;

# Options:
#   whatsout: determine what shape and size we want to pack into
#             admissible: document (default), fragment, math, archive
#   siteDirectory: the directory to compress into a ZIP archive
sub new {
  my($class,%options)=@_;
  my $self = $class->SUPER::new(%options);
  $$self{siteDirectory}  = $options{siteDirectory};
  $$self{whatsout} = $options{whatsout};
  $$self{format} = $options{format};
  $$self{finished} = 0;
  $self; }

sub process {
  my($self,$doc,$root)=@_;
  return unless defined $doc;  
  my $whatsout = $self->{whatsout};
  if ((! $whatsout) || ($whatsout eq 'document')) {} # Document is no-op
  elsif ($whatsout eq 'fragment') {
    # If we want an embedable snippet, unwrap to body's "main" div
    $doc = GetEmbeddable($doc); }
  elsif ($whatsout eq 'math') {
    # Math output - least common ancestor of all math in the document
    $doc = GetMath($doc); }
  elsif ($whatsout eq 'archive') {
    return () if $self->{finished};
    # Run a single time, even if there are multiple document fragments
    $self->{finished} = 1;
    # Archive the site directory
    my $directory = $self->{siteDirectory};
    $doc = GetArchive($directory);
    # Should we empty the site directory???
    Fatal("I/O",$self,$doc,"Writing archive to IO::String handle failed") unless defined $doc; 
  }
  return $doc; }

sub GetArchive {
  my ($directory) = @_;
  # Zip and send back
  my $archive = Archive::Zip->new();
  my $payload='';
  opendir(my $dirhandle, $directory);
  my @entries = grep {/^[^.]/} readdir($dirhandle);
  closedir $dirhandle;
  my @files = grep { (!/zip|gz|epub|tex|mobi|~$/) && -f pathname_concat($directory,$_) } @entries;
  my @subdirs = grep {-d File::Spec->catdir($directory,$_)} @entries;
  # We want to first add the files instead of simply invoking ->addTree on the top level
  # without ANY file attributes at all,
  # since EPUB is VERY picky about the first entry in the archive starting at byte 38 (file 'mimetype')
  foreach my $file(sort @files) {
    local $/ = undef;
    open my $fh_zip, "<", pathname_concat($directory,$file);
    my $file_contents = <$fh_zip>;
    $archive->addString($file_contents,$file); }
  foreach my $subdir(sort @subdirs) {
    my $current_dir = File::Spec->catdir($directory,$subdir);
    $archive->addTree($current_dir,$subdir,sub{/^[^.]/ && (!/zip|gz|epub|tex|mobi|~$/)}); }

  my $content_handle = IO::String->new($payload);
  undef $payload unless ($archive->writeToFileHandle( $content_handle ) == AZ_OK);
  return $payload; }

sub GetMath {
  my ($doc) = @_;
  my $math_xpath = '//*[local-name()="math" or local-name()="Math"]';
  return unless defined $doc;
  my @mnodes = $doc->findnodes($math_xpath);
  my $math_count = scalar(@mnodes);
  my $math = $mnodes[0] if $math_count;
  if ($math_count > 1) {
    my $math_found = 0;
    while ($math_found != $math_count) {
      $math_found = $math->findnodes('.'.$math_xpath)->size;
      $math_found++ if ($math->localname =~ /^math$/i);
      $math = $math->parentNode if ($math_found != $math_count);
    }
    $math = $math->parentNode while ($math->nodeName =~ '^t[rd]$');
    $math; }
  elsif ($math_count == 0) {
    GetEmbeddable($doc); }
  else {
    $math; }}

sub GetEmbeddable {
  my ($doc) = @_;
  return unless defined $doc;
  my ($embeddable) = $doc->findnodes('//*[contains(@class,"ltx_document")]');
  if ($embeddable) {
    # Only one child? Then get it, must be a inline-compatible one!
    while (($embeddable->nodeName eq 'div') && (scalar(@{$embeddable->childNodes}) == 1) &&
     ($embeddable->getAttribute('class') =~ /^ltx_(page_(main|content)|document|para|header)$/) && 
     (! defined $embeddable->getAttribute('style'))) {
      if (defined $embeddable->firstChild) {
        $embeddable=$embeddable->firstChild; }
      else {
        last; }
    }
    # Is the root a <p>? Make it a span then, if it has only math/text/spans - it should be inline
    # For MathJax-like inline conversion mode
    # TODO: Make sure we are schema-complete wrt nestable inline elements, and maybe find a smarter way to do this?
    if (($embeddable->nodeName eq 'p') && ((@{$embeddable->childNodes}) == (grep {$_->nodeName =~ /math|text|span/} $embeddable->childNodes))) {
      $embeddable->setNodeName('span');
      $embeddable->setAttribute('class','text');
    }

    # Copy over document namespace declarations:
    foreach ($doc->getDocumentElement->getNamespaces) {
      $embeddable->setNamespace( $_->getData , $_->getLocalName, 0 );
    }
    # Also, copy the prefix attribute, for RDFa:
    my $prefix = $doc->getDocumentElement->getAttribute('prefix');
    $embeddable->setAttribute('prefix',$prefix) if ($prefix);
  }
  return $embeddable||$doc; }

1;

