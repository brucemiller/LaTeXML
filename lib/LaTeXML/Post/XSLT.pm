# /=====================================================================\ #
# |  LaTeXML::Post::XSLT                                                | #
# | Postprocessor for XSL Transform                                     | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package LaTeXML::Post::XSLT;
use strict;
use warnings;
use LaTeXML::Util::Pathname;
use LaTeXML::Common::XML;
use LaTeXML::Post;
use base qw(LaTeXML::Post::Processor);

# Useful Options:
#    stylesheet : path to XSLT stylesheet.
#    noresources: removes resource requests so CSS/Javascript/etc
#         are not copied, and they are not included in XSLT.
#    parameters : hash of parameters to pass to stylesheet.
#         Among which:
#         CSS   is a '|' separated list of paths
#         ICON  a favicon
#         resource_directory a directory under top-level to put resources (css, js, etc)
#         searchpaths : list of paths to search
sub new {
  my ($class, %options) = @_;
  my $self       = $class->SUPER::new(%options);
  my $stylesheet = $options{stylesheet};
  Error('expected', 'stylesheet', undef, "No stylesheet specified!") unless $stylesheet;
  if (!ref $stylesheet) {
    my $pathname = pathname_find($stylesheet,
      types => ['xsl'], installation_subdir => 'resources/XSLT',
      paths => $$self{searchpaths} || ['.']);
    Error('missing-file', $stylesheet, undef, "No stylesheet '$stylesheet' found!")
      unless $pathname && -f $pathname;
    $stylesheet = $pathname; }
  $stylesheet = $stylesheet && LaTeXML::Common::XML::XSLT->new($stylesheet);
  if ((!ref $stylesheet) || !($stylesheet->can('transform'))) {
    Error('expected', 'stylesheet', undef, "Stylesheet '$stylesheet' is not a usable stylesheet!"); }
  $$self{stylesheet} = $stylesheet;
  my %params = ();
  %params = %{ $options{parameters} } if $options{parameters};
  $$self{parameters}         = {%params};
  $$self{noresources}        = $options{noresources};
  $$self{resource_directory} = $options{resource_directory};    # ???
  return $self; }

sub process {
  my ($self, $doc, $root) = @_;
  return unless $$self{stylesheet};
  # # Set up the Stylesheet parameters; making pathname parameters relative to document
  my %params = %{ $$self{parameters} };

  # Deal with any resources embedded within the document
  if (my @resnodes = $doc->findnodes('//ltx:resource[@src]')) {
    if ($$self{noresources}) {
      $doc->removeNodes(@resnodes); }
    else {
      foreach my $node (@resnodes) {
        my $src = $node->getAttribute('src');
        my $path = $self->copyResource($doc, $src, $node->getAttribute('type'));
        $node->setAttribute(src => $path) unless $path eq $src; } } }
  if (my $css = $params{CSS}) {
    $params{CSS} = '"' . join('|', map { $self->copyResource($doc, $_, 'text/css') } @$css) . '"'; }
  if (my $js = $params{JAVASCRIPT}) {
    $params{JAVASCRIPT}
      = '"' . join('|', map { $self->copyResource($doc, $_, 'text/javascript') } @$js) . '"'; }
  if (my $icon = $params{ICON}) {
    # Hmm.... what type? could be various image types
    $params{ICON} = '"' . $self->copyResource($doc, $icon, undef) . '"'; }
  my $newdoc = $doc->new($$self{stylesheet}->transform($doc->getDocument, %params));
  return $newdoc; }

my $RESOURCE_INFO = {    # [CONSTANT]
  'text/css'        => { extension => 'css', subdir => 'resources/CSS' },
  'text/javascript' => { extension => 'js',  subdir => 'resources/javascript' }
};
# Copy a resource file, if found, and return the relative path to it
# (in case it has been adjusted to be local to the destination document)
sub copyResource {
  my ($self, $doc, $reqsrc, $type) = @_;
  my $ext    = $type && $$RESOURCE_INFO{$type}{extension};
  my $resdir = $type && $$RESOURCE_INFO{$type}{subdir};
  my @searchpaths => $doc->getSearchPaths;
  # If the $reqsrc is a URL, no need to copy the resource, or modify the path to it.
  if (pathname_is_url($reqsrc)) {
    return $reqsrc; }
  # Else find the file somewhere; in user's source or in distribution
  elsif (my $path = pathname_find($reqsrc, ($ext ? (types => [$ext]) : ()),
      paths => [@searchpaths],
      ($resdir ? (installation_subdir => $resdir) : ()))) {
    # Make an attempt to preserve the relative path to the requested resource
    # Ie. same path from dest doc to copied resource, as from original doc to source resource.
    # Get the path relative to user's source, and simulate that path in the destination
    my $relpath = pathname_relative($reqsrc, $doc->getSourceDirectory);
    if (my $rd = $$self{resource_directory}) {
      $relpath = pathname_concat($rd, $relpath); }
    my $dest = pathname_absolute($relpath, $doc->getSiteDirectory);
    # Now IFF that is a valid relative path WITHIN the site directory, we'll use it.
    # Otherwise, we'll place it in a resource directory, or at toplevel in the destination.
    if (!pathname_is_contained($dest, $doc->getSiteDirectory)) {
      # $resourcedir can be relative (interpreted relative to destination doc)
      # or absolute, HOPEFULLY, within the site directory
      my ($dir, $name, $ex) = pathname_split($dest);
      $relpath = pathname_make(dir => $$self{resource_directory} || '', name => $name, type => $ex);
      $relpath = pathname_relative($relpath, $doc->getSourceDirectory)
        if pathname_is_absolute($relpath);
      $dest = pathname_absolute($relpath, $doc->getSiteDirectory); }

    # Now, copy (unless in same place! happens a lot during testing!!!!)
    pathname_copy($path, $dest) unless $path eq $dest;
    # and return the relative path from the dest doc to the resource
    return pathname_relative($dest, $doc->getDestinationDirectory); }
  else {
    warn "Couldn't find resource file $reqsrc in paths " . join(',', @searchpaths) . "\n";
    return $reqsrc; } }

# ================================================================================
1;

