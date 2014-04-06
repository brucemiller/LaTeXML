# /=====================================================================\ #
# |  LaTeXML::Common::Config                                            | #
# | Configuration logic for LaTeXML                                     | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                                | #
# | Deyan Ginev <deyan.ginev@nist.gov>                          #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Common::Config;
use strict;
use warnings;
use Carp;
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use Pod::Find qw(pod_where);
use LaTeXML::Util::Pathname;
use LaTeXML::Global;
use LaTeXML::Common::Error;
use Data::Dumper;
our $PROFILES_DB = {};    # Class-wide, caches all profiles that get used while the server is alive
our $is_bibtex  = qr/(^literal\:\s*\@)|(\.bib$)/;
our $is_archive = qr/(^literal\:PK)|(\.zip$)/;

sub new {
  my ($class, %opts) = @_;
  #TODO: How about defaults in the daemon server use case? Should we support those here?
  #      or are defaults always bad/confusing to allow?
  %opts = () unless %opts;
  return bless { dirty => 1, opts => \%opts }, $class; }

###########################################
#### Command-line reader              #####
###########################################
sub getopt_specification {
  my (%options) = @_;
  my $opts = $options{options} || {};
  my $spec = {
    # Basics and Paths
    "output=s"        => \$$opts{destination},
    "destination=s"   => \$$opts{destination},
    "log=s"           => \$$opts{log},
    "preload=s"       => \@{ $$opts{preload} },
    "preamble=s"      => \$$opts{preamble},
    "postamble=s"     => \$$opts{postamble},
    "base=s"          => \$$opts{base},
    "path=s"          => \@{ $$opts{paths} },
    "quiet"           => sub { $$opts{verbosity}--; },
    "verbose"         => sub { $$opts{verbosity}++; },
    "strict"          => \$$opts{strict},
    "includestyles"   => \$$opts{includestyles},
    "inputencoding=s" => \$$opts{inputencoding},
    # Formats
    "xml"     => sub { $$opts{format}    = 'xml'; },
    "tex"     => sub { $$opts{format}    = 'tex'; },
    "box"     => sub { $$opts{format}    = 'box'; },
    "bibtex"  => sub { $$opts{type}      = 'BibTeX'; },
    "noparse" => sub { $$opts{mathparse} = 'no'; },
    "format=s" => \$$opts{format},
    "parse=s"  => \$$opts{mathparse},
    # Profiles
    "profile=s"   => \$$opts{profile},
    "cache_key=s" => \$$opts{cache_key},
    "mode=s"      => \$$opts{profile},
    "source=s"    => \$$opts{source},
    # Output framing
    "embed" => sub { $$opts{whatsout} = 'fragment'; },
    "whatsin=s"  => \$$opts{whatsin},
    "whatsout=s" => \$$opts{whatsout},
    # Daemon options
    "autoflush=i" => \$$opts{input_limit},
    "timeout=i"   => \$$opts{timeout},
    "expire=i"    => \$$opts{expire},
    "address=s"   => \$$opts{address},
    "port=i"      => \$$opts{port},
    # Post-processing
    "post!"           => \$$opts{post},
    "validate!"       => \$$opts{validate},
    "omitdoctype!"    => \$$opts{omitdoctype},
    "numbersections!" => \$$opts{numbersections},
    "timestamp=s"     => \$$opts{timestamp},
    # Various choices for math processing.
    # Note: Could want OM embedded in mml annotation, too.
    # In general, could(?) want multiple math reps within <Math>
    # OR, multiple math reps combined with <mml:sematics>
    #   or, in fact, _other_ parallel means? (om?, omdoc? ...)
    # So, need to separate multiple transformations from the combination.
    # However, IF combining, then will need to support a id/ref mechanism.
    "mathimages!"                 => \$$opts{mathimages},
    "mathimagemagnification=f"    => \$$opts{mathimagemag},
    "linelength=i"                => \$$opts{linelength},
    "plane1!"                     => \$$opts{plane1},
    "hackplane1!"                 => \$$opts{hackplane1},
    "presentationmathml|pmml"     => sub { _addMathFormat($opts, 'pmml'); },
    "contentmathml|cmml"          => sub { _addMathFormat($opts, 'cmml'); },
    "openmath|om"                 => sub { _addMathFormat($opts, 'om'); },
    "keepXMath|xmath"             => sub { _addMathFormat($opts, 'xmath'); },
    "nopresentationmathml|nopmml" => sub { _removeMathFormat($opts, 'pmml'); },
    "nocontentmathml|nocmml"      => sub { _removeMathFormat($opts, 'cmml'); },
    "noopenmath|noom"             => sub { _removeMathFormat($opts, 'om'); },
    "nokeepXMath|noxmath"         => sub { _removeMathFormat($opts, 'xmath'); },
    "parallelmath"                => \$$opts{parallelmath},
    # Some general XSLT/CSS/JavaScript options.
    "stylesheet=s"      => \$$opts{stylesheet},
    "xsltparameter=s"   => \@{ $$opts{xsltparameters} },
    "css=s"             => \@{ $$opts{css} },
    "defaultresources!" => \$$opts{defaultresources},
    "javascript=s"      => \@{ $$opts{javascript} },
    "icon=s"            => \$$opts{icon},
    # Options for broader document set processing
    "split!" => \$$opts{split},
    "splitat=s" => sub { $$opts{splitat} = $_[1];
      $$opts{split} = 1 unless defined $$opts{split}; },
    "splitpath=s" => sub { $$opts{splitpath} = $_[1];
      $$opts{split} = 1 unless defined $$opts{split}; },
    "splitnaming=s" => sub { $$opts{splitnaming} = $_[1];
      $$opts{split} = 1 unless defined $$opts{split}; },
    "scan!"           => \$$opts{scan},
    "crossref!"       => \$$opts{crossref},
    "urlstyle=s"      => \$$opts{urlstyle},
    "navigationtoc=s" => \$$opts{navtoc},
    "navtoc=s"        => \$$opts{navtoc},
    # Generating indices
    "index!"         => \$$opts{index},
    "permutedindex!" => \$$opts{permutedindex},
    "splitindex!"    => \$$opts{splitindex},
    # Generating Bibliographies
    "bibliography=s"     => \@{ $$opts{bibliographies} },    # TODO: Document
    "splitbibliography!" => \$$opts{splitbibliography},
    # Options for two phase processing
    "prescan"           => \$$opts{prescan},
    "dbfile=s"          => \$$opts{dbfile},
    "sitedirectory=s"   => \$$opts{sitedirectory},
    "sourcedirectory=s" => \$$opts{sourcedirectory},
    # For graphics: vaguely similar issues, but more limited.
    # includegraphics images (eg. ps) can be converted to webimages (eg.png)
    # picture/pstricks images can be converted to png or possibly svg.
    "graphicimages!" => \$$opts{dographics},
    "graphicsmap=s"  => \@{ $$opts{graphicsmaps} },
    "svg!"           => \$$opts{svg},
    "pictureimages!" => \$$opts{picimages},
    # HELP
    "comments!"    => \$$opts{comments},
    "VERSION!"     => \$$opts{showversion},
    "debug=s"      => \@{ $$opts{debug} },
    "documentid=s" => \$$opts{documentid},
    "help"         => \$$opts{help}
  };
  return ($spec, $opts) unless ($options{type} && ($options{type} eq 'keyvals'));
  # Representation use case:
  my $keyvals = $options{keyvals} || [];
  my $rep_spec = {};    # Representation specification
  foreach my $key (keys %$spec) {
    if ($key =~ /^(.+)=\w$/) {
      my $name = $1;
      $$rep_spec{$key} = sub { CORE::push @$keyvals, [$name, $_[1]] };
    } else {
      $$rep_spec{$key} = sub {
        my $ctl = $_[0]->{ctl};
        my $used = ($$ctl[0] ? 'no' : '') . $$ctl[1];
        CORE::push @$keyvals, [$used, undef] };
    }
  }
  return ($rep_spec, $keyvals);
}
# TODO: Separate the keyvals scan from getopt_specification()
#       into its own sub, using @GETOPT_KEYS entirely.
our @GETOPT_KEYS = keys %{ (getopt_specification())[0] };

sub read {
  my ($self, $argref) = @_;
  my $opts = $$self{opts};
  local @ARGV = @$argref;
  my ($spec) = getopt_specification(options => $opts);
  GetOptions(%{$spec}) or pod2usage(-message => $LaTeXML::IDENTITY, -exitval => 1, -verbose => 99,
    -input => pod_where({ -inc => 1 }, __PACKAGE__),
    -sections => 'OPTIONS/SYNOPSIS', -output => \*STDERR);

  pod2usage(-message => $LaTeXML::IDENTITY, -exitval => 1, -verbose => 99,
    -input => pod_where({ -inc => 1 }, __PACKAGE__),
    -sections => 'OPTIONS/SYNOPSIS', output => \*STDOUT) if $$opts{help};

  # Check that destination is valid before wasting any time...
  if ($$opts{destination}) {
    $$opts{destination} = pathname_canonical($$opts{destination});
    if (my $dir = pathname_directory($$opts{destination})) {
      pathname_mkdir($dir) or croak "Couldn't create destination directory $dir: $!"; } }
  # Removed math formats are irrelevant for conversion:
  delete $$opts{removed_math_formats};

  if ($$opts{showversion}) { print STDERR "$LaTeXML::IDENTITY\n"; exit(1); }

  $$opts{source} = $ARGV[0] unless $$opts{source};
  if (!$$opts{type} || ($$opts{type} eq 'auto')) {
    $$opts{type} = 'BibTeX' if ($$opts{source} && ($$opts{source} =~ /$is_bibtex/)); }
  if (!$$opts{whatsin}) {
    $$opts{whatsin} = 'archive' if ($$opts{source} && ($$opts{source} =~ /$is_archive/)); }
  return;
}

sub read_keyvals {
  my ($self, $opts) = @_;
  my $cmdopts = [];
  while (my ($key, $value) = splice(@$opts, 0, 2)) {
    # TODO: Is skipping over empty values ever harmful? Do we have non-empty defaults anywhere?
    next if (!length($value)) && (grep { /^$key\=/ } @GETOPT_KEYS);
    $key = "--$key" unless $key =~ /^\-\-/;
    $value = length($value) ? "=$value" : '';
    CORE::push @$cmdopts, "$key$value";
  }
  # Read into a Config object:
  return $self->read($cmdopts); }

sub scan_to_keyvals {
  my ($self, $argref) = @_;
  local @ARGV = @$argref;
  my ($spec, $keyvals) = getopt_specification(type => 'keyvals');
  GetOptions(%$spec) or pod2usage(-message => $LaTeXML::IDENTITY, -exitval => 1, -verbose => 99,
    -input => pod_where({ -inc => 1 }, __PACKAGE__),
    -sections => 'OPTIONS/SYNOPSIS', -output => \*STDERR);
  CORE::push @$keyvals, ['source', $ARGV[0]] if $ARGV[0];
  return $keyvals;
}

###########################################
#### Options Object Hashlike API      #####
###########################################
sub get {
  my ($self, $key, $value) = @_;
  return $$self{opts}{$key}; }

sub set {
  my ($self, $key, $value) = @_;
  $$self{dirty} = 1;
  $$self{opts}{$key} = $value;
  return; }

sub push {
  my ($self, $key, $value) = @_;
  $$self{dirty} = 1;
  $$self{opts}{$key} = [] unless ref $$self{opts}{$key};
  CORE::push @{ $$self{opts}{$key} }, $value;
  return; }

sub delete {
  my ($self, $key) = @_;
  $$self{dirty} = 1;
  delete $$self{opts}{$key};
  return; }

sub exists {
  my ($self, $key) = @_;
  return exists $$self{opts}{$key}; }

sub keys {
  my ($self) = @_;
  return keys %{ $$self{opts} }; }

sub options {
  my ($self) = @_;
  return $$self{opts}; }

sub clone {
  my ($self) = @_;
  my $clone = LaTeXML::Common::Config->new(%{ $self->options });
  $$clone{dirty} = $$self{dirty};
  return $clone; }

###########################################
#### Option Sanity Checking           #####
###########################################

# Perform all option sanity checks
sub check {
  my ($self) = @_;
  return unless $$self{dirty};
  # 1. Resolve profile
  $self->_obey_profile;
  # 2. Place sane defaults where needed
  return $self->_prepare_options; }

sub _obey_profile {
  my ($self) = @_;
  $$self{dirty} = 1;
  my $opts = $$self{opts};
  my $profile = lc($$opts{profile} || 'custom');
  # Look at the PROFILES_DB or find a profiles file (otherwise fallback to custom)
  my $profile_opts = {};
  if ($profile ne 'custom') {
    if (defined $$PROFILES_DB{$profile}) {
      %$profile_opts = %{ $$PROFILES_DB{$profile} }
    } elsif (my $file = pathname_find($profile . '.opt', paths => [],
        types => [], installation_subdir => 'resources/Profiles')) {
      my $conf_tmp = LaTeXML::Common::Config->new;
      $conf_tmp->read(_read_options_file($file));
      $profile_opts = $conf_tmp->options;
    } else {
      # Throw an error, fallback to custom
      carp("Warning:unexpected:$profile Profile $profile was not recognized, reverting to 'custom'\n");
      $$opts{profile} = 'custom';
      $profile = 'custom';
    }
  }
  # Erase the profile, save it as cache key
  delete $$opts{profile};
  $$opts{cache_key} = $profile unless defined $$opts{cache_key};
  if (%$profile_opts) {
    # Merge the new options with the profile defaults:
    for my $key (grep { defined $$opts{$_} } (CORE::keys %$opts)) {
      if ($key =~ /^p(ath|reload)/) {    # Paths and preloads get merged in
        $$profile_opts{$key} = [] unless defined $$profile_opts{$key};
        foreach my $entry (@{ $$opts{$key} }) {
          my $new = 1;
          foreach (@{ $$profile_opts{$key} }) {
            if ($entry eq $_) { $new = 0; last; }
          }
          # If new to the array, push:
          CORE::push(@{ $$profile_opts{$key} }, $entry) if ($new);
        }
      } else {                           # The other options get overwritten
        $$profile_opts{$key} = $$opts{$key};
      }
    }
    %$opts = %$profile_opts;             # Move back into the user options
  }
  return; }

# TODO: Best way to throw errors when options don't work out?
#       How about in the case of Extras::ReadOptions?
#       Error() and Warn() would be neat, but we have to make sure STDERR is caught beforehand.
#       Also, there is no eval() here, so we might need a softer handling of Error()s.
sub _prepare_options {
  my ($self) = @_;
  my $opts = $$self{opts};
  #======================================================================
  # I. Sanity check and Completion of Core options.
  #======================================================================
  # "safe" and semi-perlcrtic acceptable way to set DEBUG inside arbitrary modules.
  # Note: 'LaTeXML' refers to the top-level class
  { no strict 'refs';
    foreach my $ltx_class (@{ $$opts{debug} || [] }) {
      if ($ltx_class eq 'LaTeXML') {
        ${'LaTeXML::DEBUG'} = 1; }
      else {
        ${ 'LaTeXML::' . $ltx_class . '::DEBUG' } = 1; } } }

  $$opts{timeout} = 600 if ((!defined $$opts{timeout}) || ($$opts{timeout} !~ /\d+/)); # 10 minute timeout default
  $$opts{expire} = 600 if ((!defined $$opts{expire}) || ($$opts{expire} !~ /\d+/)); # 10 minute timeout default
  $$opts{mathparse} = 'RecDescent' unless defined $$opts{mathparse};
  if ($$opts{mathparse} eq 'no') {
    $$opts{mathparse}   = 0;
    $$opts{nomathparse} = 1; }    #Backwards compatible
  $$opts{verbosity} = 10    unless defined $$opts{verbosity};
  $$opts{preload}   = []    unless defined $$opts{preload};
  $$opts{paths}     = ['.'] unless defined $$opts{paths};
  @{ $$opts{paths} } = map { pathname_canonical($_) } @{ $$opts{paths} };
  foreach (('destination', 'dbfile', 'sourcedirectory', 'sitedirectory')) {
    $$opts{$_} = pathname_canonical($$opts{$_}) if defined $$opts{$_};
  }

  $$opts{whatsin}  = 'document' unless defined $$opts{whatsin};
  $$opts{whatsout} = 'document' unless defined $$opts{whatsout};
  $$opts{type}     = 'auto'     unless defined $$opts{type};
  unshift(@{ $$opts{preload} }, ('TeX.pool', 'LaTeX.pool', 'BibTeX.pool')) if ($$opts{type} eq 'BibTeX');

  # Destination extension might indicate the format:
  if ((!defined $$opts{extension}) && (defined $$opts{destination})) {
    if ($$opts{destination} =~ /\.([^.]+)$/) {
      $$opts{extension} = $1; } }
  if ((!defined $$opts{format}) && (defined $$opts{destination})) {
    if ($$opts{destination} =~ /\.([^.]+)$/) {
      $$opts{format} = $1; } }
  if ((!defined $$opts{extension}) && (defined $$opts{format})) {
    if ($$opts{format} =~ /^html/) {
      $$opts{extension} = 'html'; }
    elsif ($$opts{format} =~ /^xhtml/) {
      $$opts{extension} = 'xhtml'; }
    else {
      $$opts{extension} = 'xml'; } }
  if ($$opts{format}) {
    # Lower-case for sanity's sake
    $$opts{format} = lc($$opts{format});
    $$opts{format} = 'html5' if $$opts{format} eq 'html';    # Default
    if ($$opts{format} eq 'zip') {
      # Not encouraged! But try to produce something sensible anyway...
      $$opts{format}   = 'html5';
      $$opts{whatsout} = 'archive';
    }
    $$opts{is_html}  = ($$opts{format} =~ /^html/);
    $$opts{is_xhtml} = ($$opts{format} =~ /^(xhtml5?|epub|mobi)$/);
    $$opts{whatsout} = 'archive' if (($$opts{format} eq 'epub') || ($$opts{format} eq 'mobi'));
  }
  #======================================================================
  # II. Sanity check and Completion of Post options.
  #======================================================================
  # Any post switch implies post (TODO: whew, lots of those, add them all!):
  $$opts{math_formats} = [] unless defined $$opts{math_formats};
  $$opts{post} = 1 if ((!defined $$opts{post}) &&
    (scalar(@{ $$opts{math_formats} }))
    || ($$opts{stylesheet})
    || $$opts{is_html}
    || $$opts{is_xhtml}
    || ($$opts{whatsout} && ($$opts{whatsout} ne 'document'))
  );
# || ... || ... || ...
# $$opts{post}=0 if (defined $$opts{mathparse} && (! $$opts{mathparse})); # No-parse overrides post-processing
  if ($$opts{post}) {    # No need to bother if we're not post-processing
                         # Default: scan and crossref on, other advanced off
    $$opts{prescan}  = undef unless defined $$opts{prescan};
    $$opts{dbfile}   = undef unless defined $$opts{dbfile};
    $$opts{scan}     = 1     unless defined $$opts{scan};
    $$opts{index}    = 1     unless defined $$opts{index};
    $$opts{crossref} = 1     unless defined $$opts{crossref};
    $$opts{sitedirectory} = defined $$opts{sitedirectory} ? $$opts{sitedirectory}
      : (defined $$opts{destination} ? pathname_directory($$opts{destination})
      : (defined $$opts{dbfile} ? pathname_directory($$opts{dbfile})
        : "."));
    $$opts{sourcedirectory} = undef unless defined $$opts{sourcedirectory};
    $$opts{numbersections}  = 1     unless defined $$opts{numbersections};
    $$opts{navtoc}          = undef unless defined $$opts{numbersections};
    $$opts{navtocstyles} = { context => 1, normal => 1, none => 1 } unless defined $$opts{navtocstyles};
    $$opts{navtoc} = lc($$opts{navtoc}) if defined $$opts{navtoc};
    delete $$opts{navtoc} if ($$opts{navtoc} && ($$opts{navtoc} eq 'none'));

    if ($$opts{navtoc}) {
      if (!$$opts{navtocstyles}->{ $$opts{navtoc} }) {
        croak($$opts{navtoc} . " is not a recognized style of navigation TOC"); }
      if (!$$opts{crossref}) {
        croak("Cannot use option \"navigationtoc\" (" . $$opts{navtoc} . ") without \"crossref\""); } }
    $$opts{urlstyle}       = 'server' unless defined $$opts{urlstyle};
    $$opts{bibliographies} = []       unless defined $$opts{bibliographies};

    # Validation:
    $$opts{validate} = 1 unless defined $$opts{validate};
    # Graphics:
    $$opts{mathimagemag} = 1.75 unless defined $$opts{mathimagemag};
    if ((defined $$opts{destination}) || ($$opts{whatsout} =~ /^archive/)) {
      # We want the graphics enabled by default, but only when we have a destination
      $$opts{dographics} = 1 unless defined $$opts{dographics};
      $$opts{picimages}  = 1 unless defined $$opts{picimages}; }
    # Split sanity:
    if ($$opts{split}) {
      $$opts{splitat}     = 'section' unless defined $$opts{splitat};
      $$opts{splitnaming} = 'id'      unless defined $$opts{splitnaming};
      $$opts{splitback} = "//ltx:bibliography | //ltx:appendix | //ltx:index" unless defined $$opts{splitback};
      $$opts{splitpaths} =
        { chapter => "//ltx:chapter | " . $$opts{splitback},
        section    => "//ltx:chapter | //ltx:section | " . $$opts{splitback},
        subsection => "//ltx:chapter | //ltx:section | //ltx:subsection | " . $$opts{splitback},
        subsubsection => "//ltx:chapter | //ltx:section | //ltx:subsection | //ltx:subsubsection | " . $$opts{splitback} }
        unless defined $$opts{splitpaths};

      $$opts{splitnaming} = _checkOptionValue('--splitnaming', $$opts{splitnaming},
        qw(id idrelative label labelrelative));
      $$opts{splitat} = _checkOptionValue('--splitat', $$opts{splitat}, CORE::keys %{ $$opts{splitpaths} });
      $$opts{splitpath} = $$opts{splitpaths}->{ $$opts{splitat} } unless defined $$opts{splitpath}; }

    # Check for appropriate combination of split, scan, prescan, dbfile, crossref
    if ($$opts{split} && (!defined $$opts{destination}) && ($$opts{whatsout} !~ /^archive/)) {
      croak("Must supply --destination when using --split"); }
    if ($$opts{prescan} && !$$opts{scan}) {
      croak("Makes no sense to --prescan with scanning disabled (--noscan)"); }
    if ($$opts{prescan} && (!defined $$opts{dbfile})) {
      croak("Cannot prescan documents (--prescan) without specifying --dbfile"); }
    if (!$$opts{prescan} && $$opts{crossref} && !($$opts{scan} || (defined $$opts{dbfile}))) {
      croak("Cannot cross-reference (--crossref) without --scan or --dbfile "); }
    if ($$opts{crossref}) {
      $$opts{urlstyle} = _checkOptionValue('--urlstyle', $$opts{urlstyle}, qw(server negotiated file)); }
    if (($$opts{permutedindex} || $$opts{splitindex}) && (!defined $$opts{index})) {
      $$opts{index} = 1; }
    if (!$$opts{prescan} && $$opts{index} && !($$opts{scan} || defined $$opts{crossref})) {
      croak("Cannot generate index (--index) without --scan or --dbfile"); }
    if (!$$opts{prescan} && @{ $$opts{bibliographies} } && !($$opts{scan} || defined $$opts{crossref})) {
      croak("Cannot generate bibliography (--bibliography) without --scan or --dbfile"); }
    if ((!defined $$opts{destination}) && ($$opts{whatsout} !~ /^archive/) && ($$opts{mathimages} || $$opts{dographics} || $$opts{picimages})) {
      croak("Must supply --destination unless all auxilliary file writing is disabled"
          . "(--nomathimages --nographicimages --nopictureimages --nodefaultcss)"); }

    # Format:
    #Default is XHTML, XML otherwise (TODO: Expand)
    $$opts{format} = "xml" if ($$opts{stylesheet}) && (!defined $$opts{format});
    $$opts{format} = "xhtml" unless defined $$opts{format};
    if (!$$opts{stylesheet}) {
      if    ($$opts{format} eq 'xhtml')       { $$opts{stylesheet} = "LaTeXML-xhtml.xsl"; }
      elsif ($$opts{format} eq "html4")       { $$opts{stylesheet} = "LaTeXML-html4.xsl"; }
      elsif ($$opts{format} =~ /^epub|mobi$/) { $$opts{stylesheet} = "LaTeXML-epub3.xsl"; }
      elsif ($$opts{format} eq "html5")       { $$opts{stylesheet} = "LaTeXML-html5.xsl"; }
      elsif ($$opts{format} eq "xml")         { delete $$opts{stylesheet}; }
      else                                    { croak("Unrecognized target format: " . $$opts{format}); }
    }
    # Check format and complete math and image options
    if ($$opts{format} eq 'html4') {
      $$opts{svg} = 0 unless defined $$opts{svg};    # No SVG by default in HTML.
      croak("Default html4 stylesheet only supports math images, not " . join(', ', @{ $$opts{math_formats} }))
        if scalar(@{ $$opts{math_formats} });
      croak("Default html stylesheet does not support svg") if $$opts{svg};
      $$opts{mathimages}   = 1;
      $$opts{math_formats} = [];
    }
    $$opts{svg} = 1 unless defined $$opts{svg};      # If we're not making HTML, SVG is on by default
          # PMML default if we're HTMLy and all else fails and no mathimages:
    if (((!defined $$opts{math_formats}) || (!scalar(@{ $$opts{math_formats} }))) &&
      (!$$opts{mathimages}) && ($$opts{is_html} || $$opts{is_xhtml}))
    {
      CORE::push @{ $$opts{math_formats} }, 'pmml';
    }
    # use parallel markup if there are multiple formats requested.
    $$opts{parallelmath} = 1 if ($$opts{math_formats} && (@{ $$opts{math_formats} } > 1));
  }
  # If really nothing hints to define format, then default it to XML
  $$opts{format} = 'xml' unless defined $$opts{format};
  $$self{dirty} = 0;
  return; }

## Utilities:

sub _addMathFormat {
  my ($opts, $fmt) = @_;
  $$opts{math_formats} = [] unless defined $$opts{math_formats};
  CORE::push(@{ $$opts{math_formats} }, $fmt)
    unless (grep { $_ eq $fmt } @{ $$opts{math_formats} }) || $$opts{removed_math_formats}->{$fmt};
  return; }

sub _removeMathFormat {
  my ($opts, $fmt) = @_;
  @{ $$opts{math_formats} } = grep { $_ ne $fmt } @{ $$opts{math_formats} };
  $$opts{removed_math_formats}->{$fmt} = 1;
  return; }

sub _checkOptionValue {
  my ($option, $value, @choices) = @_;
  if ($value) {
    foreach my $choice (@choices) {
      return $choice if substr($choice, 0, length($value)) eq $value; } }
  croak("Value for $option, $value, doesn't match " . join(', ', @choices)); }

### This is from t/lib/TestDaemon.pm and ideally belongs in Util::Pathname
sub _read_options_file {
  my ($file) = @_;
  my $opts = [];
  my $OPT;
  unless (open($OPT, "<", $file)) {
    Error('expected', $file, "Could not open options file '$file'");
    return; }
  while (my $line = <$OPT>) {
    # Cleanup comments, padding on the input line.
    $line =~ s/(?<!\\)#.*$//;    # Strip trailing comments starting w/ # (but \# is quoted)
    $line =~ s/\\#/#/g;          # unslashify any \#
    $line =~ s/^\s+//;           # Trim leading & trailing whitespace
    $line =~ s/\s+$//;
    next unless $line;           # if line isn't empty, after that.....
    chomp($line);
    if ($line =~ /(\S+)\s*=\s*(.*)/) {
      my ($key, $value) = ($1, $2 || '');
      $value =~ s/\s+$//;
      # Special treatment for --path=$env:
      if ($value =~ /^\$(.+)$/) {
        my @values   = ();
        my $env_name = $1;
        my $env_value;
        # Allow $env/foo paths, starting with $env prefixes
        if ($env_name =~ /^([^\/]+)(\/+)(.+)$/) {
          my $trailer = $3;
          if (my $env_path = $ENV{$1}) {
            $env_path .= '/' unless $env_path =~ /\/$/;
            CORE::push @values, $env_path . $trailer; } }
        else {
          # But also the standard behaviour, where the $env is an array of paths
          $env_value = $ENV{$env_name};
          next unless $env_value;
          @values = grep { -d $_ } reverse(split(':', $env_value));
          next unless @values; }
        CORE::push(@$opts, "--$key=$_") foreach (@values); }
      else {
        $value = $value ? "=$value" : '';
        CORE::push @$opts, "--$key" . $value; } }
    else {
      Warning('unexpected', $line, undef,
        "Unrecognized configuration data '$line'"); }
  }
  close $OPT;
  return $opts; }

1;

__END__

=pod

=head1 NAME

C<LaTeXML::Common::Config> - Configuration logic for LaTeXML

=head1 SYNPOSIS

    use LaTeXML::Common::Config;
    my $config = LaTeXML::Common::Config->new(
              profile=>'name',
              timeout=>number
              ... );
    $config->read(\@ARGV);
    $config->check;

    my $value = $config->get($name);
    $config->set($name,$value);
    $config->delete($name);
    my $bool = $config->exists($name);
    my @keys = $config->keys;
    my $options_hashref = $config->options;
    my $config_clone = $config->clone;

=head1 DESCRIPTION

Configuration management class for LaTeXML options.
    * Responsible for defining the options interface
      and parsing the usual Perl command-line options syntax
    * Provides the intuitive getters, setters, as well as
      hash methods for manipulating the option values.
    * Also supports cloning into new configuration objects.

=head2 METHODS

=over 4

=item C<< my $config = LaTeXML::Common::Config->new(%options); >>

Creates a new configuration object. Note that you should try
    not to provide your own %options hash but rather create an empty
    configuration and use $config->read to read in the options.

=item C<< $config->read(\@ARGV); >>

This is the main method for parsing in LaTeXML options.
    The input array should either be @ARGV, e.g. when the
    options were provided from the command line using the
    classic Getopt::Long syntax,
    or any other array reference that conforms to that setup.

=item C<< $config->check; >>

Ensures that the configuration obeys the given profile and
    performs a set of assignments of meaningful defaults
    (when needed) and normalizations (for relative paths, etc).

=item C<< my $value = $config->get($name); >>

Classic getter for the $value of an option $name.

=item C<< $config->set($name,$value); >>

Classic setter for the $value of an option $name.

=item C<< $config->delete($name); >>

Deletes option $name from the configuration.

=item C<< my $bool = $config->exists($name); >>

Checks whether the key $name exists in the options hash of the configuration.
    Similarly to Perl's "exist" for hashes, it returns true even when
    the option's value is undefined.

=item C<< my @keys = $config->keys; >>

Similar to "keys %hash" in Perl. Returns an array of all option names.

=item C<< my $options_hashref = $config->options; >>

Returns the actual hash reference that holds all options within the configuration object.

=item C<< my $config_clone = $config->clone; >>

Clones $config into a new LaTeXML::Common::Config object, $config_clone.

=back

=head1 OPTIONS

=head2 SYNOPSIS

latexmls/latexmlc [options]

 Options:
 --destination=file specifies destination file.
 --output=file      [obsolete synonym for --destination]
 --preload=module   requests loading of an optional module;
                    can be repeated
 --preamble=file    loads a tex file containing document
                    frontmatter. MUST include \begin{document}
                    or equivalent
 --postamble=file   loads a tex file containing document
                    backmatter. MUST include \end{document}
                    or equivalent
 --includestyles    allows latexml to load raw *.sty file;
                    by default it avoids this.
 --base=dir         sets the base directory that the server
                    operates in. Useful when converting
                    documents that employ relative paths.
 --path=dir         adds dir to the paths searched for files,
                    modules, etc; 
 --log=file         specifies log file (default: STDERR)
 --autoflush=count  Automatically restart the daemon after
                    "count" inputs. Good practice for vast
                    batch jobs. (default: 100)
 --timeout=secs     Timecap for conversions (default 600)
 --expire=secs      Timecap for server inactivity (default 600)
 --address=URL      Specify server address (default: localhost)
 --port=number      Specify server port (default: 3354)
 --documentid=id    assign an id to the document root.
 --quiet            suppress messages (can repeat)
 --verbose          more informative output (can repeat)
 --strict           makes latexml less forgiving of errors
 --bibtex           processes a BibTeX bibliography.
 --xml              requests xml output (default).
 --tex              requests TeX output after expansion.
 --box              requests box output after expansion
                    and digestion.
 --format=name      requests "name" as the output format.
                    Supported: tex,box,xml,html4,html5,xhtml
                    html implies html5
 --noparse          suppresses parsing math (default: off)
 --parse=name       enables parsing math (default: on)
                    and selects parser framework "name".
                    Supported: Marpa, RecDescent
 --profile=name     specify profile as defined in
                    LaTeXML::Common::Config
                    Supported: standard|math|fragment|...
                    (default: standard)
 --mode=name        Alias for profile
 --whatsin=chunk    Defines the provided input chunk,
                    choose from document (default), fragment
                    and formula
 --whatsout=chunk   Defines the expected output chunk,
                    choose from document (default), fragment
                    and formula
 --post             requests a followup post-processing
 --embed            requests an embeddable XHTML snippet
                    (requires: --post,--profile=fragment)
                    DEPRECATED: Use --whatsout=fragment
                    TODO: Remove completely
 --stylesheet       specifies a stylesheet,
                    to be used by the post-processor.
 --css=cssfile      adds a css stylesheet to html/xhtml
                    (can be repeated)
 --nodefaultresources    disables processing built-in resources
 --javscript=jsfile      adds a link to a javascript file into
                         html/html5/xhtml (can be repeated)
 --xsltparameter=name:value passes parameters to the XSLT.
 --sitedirectory=dir     sets the base directory of the site
 --sourcedirectory=dir   sets the base directory of the
                         original TeX source
 --mathimages            converts math to images
                         (default for html4 format)
 --nomathimages          disables the above
 --mathimagemagnification=mag specifies magnification factor
 --plane1           use plane-1 unicode for symbols
                    (default, if needed)
 --noplane1         do not use plane-1 unicode
 --pmml             converts math to Presentation MathML
                    (default for xhtml and html5 formats)
 --cmml             converts math to Content MathML
 --openmath         converts math to OpenMath
 --keepXMath        keeps the XMath of a formula as a MathML
                    annotation-xml element
 --nocomments       omit comments from the output
 --inputencoding=enc specify the input encoding.
 --VERSION          show version number.
 --debug=package    enables debugging output for the named
                    package
 --help             shows this help message.

Note that the profiles come with a variety of preset options. To customize your
own conversion setup, use --whatsin=math|fragment|document instead, respectively,
as well as --whatsout=math|fragment|document.

If you want to provide a TeX snippet directly on input, rather than supply a filename,
use the C<literal:> protocol to prefix your snippet.

For reliable communication and a stable conversion experience, invoke latexmls
only through the latexmlc client (you need to set --expire to a positive value,
in order to request auto-spawning of a dedicated conversion server).

=head2 DETAILS

=over 4

=item C<--destination>=I<file>

Specifies the destination file; by default the XML is written to STDOUT.

=item C<--preload>=I<module>

Requests the loading of an optional module or package.  This may be useful if the TeX code
    does not specificly require the module (eg. through input or usepackage).
    For example, use C<--preload=LaTeX.pool> to force LaTeX mode.

=item C<--preamble>=I<file>

Requests the loading of a tex file with document frontmatter, to be read in before the converted document, 
    but after all --preload entries.

Note that the given file MUST contain \begin{document} or an equivalent environment start,
    when processing LaTeX documents.

If the file does not contain content to appear in the final document, but only macro definitions and 
    setting of internal counters, it is more appropriate to use --preload instead.

=item C<--postamble>=I<file>

Requests the loading of a tex file with document backmatter, to be read in after the converted document.

Note that the given file MUST contain \end{document} or an equivalent environment end,
    when processing LaTeX documents.

=item C<--includestyles>

This optional allows processing of style files (files with extensions C<sty>,
    C<cls>, C<clo>, C<cnf>).  By default, these files are ignored  unless a latexml
    implementation of them is found (with an extension of C<ltxml>).

These style files generally fall into two classes:  Those
    that merely affect document style are ignorable in the XML.
    Others define new markup and document structure, often using
    deeper LaTeX macros to achieve their ends.  Although the omission
    will lead to other errors (missing macro definitions), it is
    unlikely that processing the TeX code in the style file will
    lead to a correct document.

=item C<--path>=I<dir>

Add I<dir> to the search paths used when searching for files, modules, style files, etc;
    somewhat like TEXINPUTS.  This option can be repeated.

=item C<--log>=I<file>

Specifies the log file; be default any conversion messages are printed to STDERR.

=item C<--autoflush>=I<count>

Automatically restart the daemon after converting "count" inputs.
    Good practice for vast batch jobs. (default: 100)

=item C<--expire>=I<secs>

Set an inactivity timeout value in seconds. If the daemon is not given any input
    for the timeout period it will automatically self-destruct.
    The default value is 600 seconds, set to 0 to never expire,
     -1 to entirely opt out of using a server.

=item C<--timeout>=I<secs>

Set time cap for conversion jobs, in seconds. Any job failing to convert in the
    time range would return with a Fatal error of timing out.
    Default value is 600, set to 0 to disable.

=item C<--address>=I<URL>

Specify server address (default: localhost)

=item C<--port>=I<number>

Specify server port (default: 3334 for math, 3344 for fragment and 3354 for standard)

=item C<--documentid>=I<id>

Assigns an ID to the root element of the XML document.  This ID is generally
    inherited as the prefix of ID's on all other elements within the document.
    This is useful when constructing a site of multiple documents so that
    all nodes have unique IDs.

=item C<--quiet>

Reduces the verbosity of output during processing, used twice is pretty silent.

=item C<--verbose>

Increases the verbosity of output during processing, used twice is pretty chatty.
    Can be useful for getting more details when errors occur.

=item C<--strict>

Specifies a strict processing mode. By default, undefined control sequences and
    invalid document constructs (that violate the DTD) give warning messages, but attempt
    to continue processing.  Using C<--strict> makes them generate fatal errors.

=item C<--bibtex>

Forces latexml to treat the file as a BibTeX bibliography.
    Note that the timing is slightly different than the usual
    case with BibTeX and LaTeX.  In the latter case, BibTeX simply
    selects and formats a subset of the bibliographic entries; the
    actual TeX expansion is carried out when the result is included
    in a LaTeX document.  In contrast, latexml processes and expands
    the entire bibliography; the selection of entries is done
    during post-processing.  This also means that any packages
    that define macros used in the bibliography must be
    specified using the C<--preload> option.

=item C<--xml>

Requests XML output; this is the default.

=item C<--tex>

Requests TeX output for debugging purposes;
    processing is only carried out through expansion and digestion.
    This may not be quite valid TeX, since Unicode may be introduced.

=item C<--box>

Requests Box output for debugging purposes;
    processing is carried out through expansion and digestions,
    and the result is printed.

=item C<--format=name>

Requests an explicitly provided "name" as the output format of the conversion.
    Currently supported: tex, box, xml, html4, html5, xhtml
    Tip: If you wish to apply your own custom XSLT stylesheet, select "xml"
    as the desired format.

=item C<--noparse>

Suppresses parsing math (default: parsing is on)

=item C<--parse=name>

Enables parsing math (default: parsing is on)
    and selects parser framework "name".
    Supported: Marpa, RecDescent, no
    Tip: --parse=no is equivalent to --noparse

=item C<--profile>

Variety of shorthand profiles, described at C<LaTeXML::Common::Config>.

Example: C<latexmlc --profile=math '1+2=3'>

=item C<--post>

Request post-processing. Enabled by default is processing graphics and cross-referencing.


=item C<--embed>

TODO: Deprecated, use --whatsout=fragment
Requests an embeddable XHTML div (requires: --post --format=xhtml),
    respectively the top division of the document's body.
    Caveat: This experimental mode is enabled only for fragment profile and post-processed
    documents (to XHTML).

=item C<--mathimages>, C<--nomathimages>

Requests or disables the conversion of math to images.
Conversion is the default for html4 format.

=item C<--mathimagemagnification=>I<factor>

Specifies the magnification used for math images, if they are made.
Default is 1.75.

=item C<--pmml>

Requests conversion of math to Presentation MathML.
    Presentation MathML is the default math processor for the XHTML/HTML5 formats.
    Will enable C<--post>.

=item C<--cmml>

Requests or disables conversion of math to Content MathML.
    Conversion is disabled by default.
    B<Note> that this conversion is only partially implemented.
    Will enable C<--post>.

=item C<--openmath>

Requests or disables conversion of math to OpenMath.
    Conversion is disabled by default.
    B<Note> that this conversion is not yet supported in C<latexmls>.
    Will enable C<--post>.

=item C<--xmath> and C<--keepXMath>

By default, when any of the MathML or OpenMath conversions
    are used, the intermediate math representation will be removed;
    Explicitly specifying --xmath|keepXMath preserves this format.
    Will enable C<--post>.

=item C<--stylesheet>=I<file>

Sets a stylesheet of choice to be used by the postprocessor.
    Will enable C<--post>.

=item C<--css>=I<cssfile>

Adds I<cssfile> as a css stylesheet to be used in the transformed html/xhtml.
    Multiple stylesheets can be used; they are included in the html in the
    order given, following the default C<core.css>
    (but see C<--nodefaultresources>). Some stylesheets included in the distribution are
  --css=navbar-left   Puts a navigation bar on the left.
                      (default omits navbar)
  --css=navbar-right  Puts a navigation bar on the left.
  --css=theme-blue    A blue coloring theme for headings.
  --css=amsart        A style suitable for journal articles.

=item C<--javascript>=I<jsfile>

Includes a link to the javascript file I<jsfile>, to be used in the transformed html/html5/xhtml.
Multiple javascript files can be included; they are linked in the html in the order given.
The javascript file is copied to the destination directory, unless it is an absolute url.

=item C<--nodefaultresources>

Disables the copying and inclusion of resources added by the binding files;
This includes CSS, javascript or other files.  This does not affect
resources explicitly requested by the C<--css> or C<--javascript> options.

=item C<--timestamp>=I<timestamp>

Provides a timestamp (typically a time and date) to be embedded in
the comments by the stock XSLT stylesheets.
If you don't supply a timestamp, the current time and date will be used.
(You can use C<--timestamp=0> to omit the timestamp).

=item C<--xsltparameter>=I<name>:I<value>

Passes parameters to the XSLT stylesheet.
See the manual or the stylesheet itself for available parameters.

=item C<--nocomments>

Normally latexml preserves comments from the source file, and adds a comment every 25 lines as
    an aid in tracking the source.  The option --nocomments discards such comments.

=item C<--sitedirectory=>I<dir>

Specifies the base directory of the overall web site.
Pathnames in the database are stored in a form relative
to this directory to make it more portable.

=item C<--sourcedirectory>=I<source>

Specifies the directory where the original latex source is located.
Unless LaTeXML is run from that directory, or it can be determined
from the xml filename, it may be necessary to specify this option in
order to find graphics and style files.

=item C<--inputencoding=>I<encoding>

Specify the input encoding, eg. C<--inputencoding=iso-8859-1>.
    The encoding must be one known to Perl's Encode package.
    Note that this only enables the translation of the input bytes to
    UTF-8 used internally by LaTeXML, but does not affect catcodes.
    In such cases, you should be using the inputenc package.
    Note also that this does not affect the output encoding, which is
    always UTF-8.

=item C<--VERSION>

Shows the version number of the LaTeXML package..

=item C<--debug>=I<package>

Enables debugging output for the named package. The package is given without the leading LaTeXML::.

=item C<--help>

Shows this help message.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>
Deyan Ginev <deyan.ginev@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.

=cut
