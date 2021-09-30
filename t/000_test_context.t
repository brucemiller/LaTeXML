# -*- CPERL -*-
#**********************************************************************
# Record testing context for LaTeXML
#**********************************************************************
use LaTeXML;
use LaTeXML::Util::Test;
use File::Which;

# Show the context in which we're running tests.
# in particular, the versions of things which tend to cause problems,
# and which aren't as obvious from a CPAN Tester's page.
sub show_context {
  my @context = ("", "LaTeXML version $LaTeXML::VERSION");
  # Find libxml2, libxslt
  {
    require XML::LibXML;
    require XML::LibXSLT;
    push(@context, "XML::LibXML $XML::LibXML::VERSION; libxml2 "
        . XML::LibXML::LIBXML_RUNTIME_VERSION());
    push(@context, "XML::LibXSLT $XML::LibXSLT::VERSION; libxslt "
        . XML::LibXSLT::LIBXSLT_RUNTIME_VERSION()); }

  # kpsewhich has it's own version, we need the version from tex, itself; So find tex:
  if (my $path = $ENV{LATEXML_KPSEWHICH}) {
    if (($path =~ s/kpsewhich/tex/i) && (-X $path)) {
      $tex = $path; } }
  if (!$tex) {    # Else look for executable
    $tex = which("tex"); }
  if ($tex && open(my $texfh, '-|', $tex, '--version')) { # If we found one, hope it has TeX Live version in it's --version
    my $texv = <$texfh>;
    push(@context, $texv);                                # 1st line only
    close($texfh); }
  else {
    push(@context, "No TeX"); }

  my $ok = ok(1, "Test Context");
  diag(join("\n  ", @context));
  return $ok; }

plan tests => 1;
show_context();

