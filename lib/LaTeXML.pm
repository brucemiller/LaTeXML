# /=====================================================================\ #
# |  LaTeXML                                                            | #
# | Overall LaTeXML Converter                                           | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Deyan Ginev <d.ginev@jacobs-university.de>                  #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML;
use strict;
use warnings;
use Carp;
use Encode;
use File::Temp;
File::Temp->safe_level(File::Temp::MEDIUM);
use File::Path qw(rmtree);
use File::Spec;
use List::Util qw(max);
use LaTeXML::Common::Config;
use LaTeXML::Common::Error;
use LaTeXML::Core;
use LaTeXML::Util::Pack qw(pack_collection);
use LaTeXML::Util::Pack::Zip;
use LaTeXML::Util::Pack::Dir;
use LaTeXML::Util::Pathname;
use LaTeXML::Util::WWW;
use LaTeXML::Util::ObjectDB;
use LaTeXML::Post::Scan;
use vars qw($VERSION);
# This is the main version of LaTeXML being claimed.
use version; our $VERSION = version->declare("0.8.8");
use LaTeXML::Version;
# Derived, more informative version numbers
our $FULLVERSION = "LaTeXML version $LaTeXML::VERSION"
  . ($LaTeXML::Version::REVISION ? "; revision $LaTeXML::Version::REVISION" : '');
# Handy identifier string for any executable.
our $IDENTITY = "$FindBin::Script ($LaTeXML::FULLVERSION)";

our $LOG_STACK = 0;

#**********************************************************************
#our @IGNORABLE = qw(timeout profile port preamble postamble port destination log removed_math_formats whatsin whatsout math_formats input_limit input_counter dographics mathimagemag );

# Switching to white-listing options that are important for new_latexml:
our @COMPARABLE = qw(preload paths verbosity strict comments inputencoding includestyles documentid mathparse);

sub new {
  my ($class, $config) = @_;
  $config = LaTeXML::Common::Config->new() unless (defined $config);
  # The daemon should be setting the identity:
  my $self = bless { opts => $config->options, ready => 0, log => q{}, runtime => {},
    latexml => undef }, $class;
  # Special check if the debug directive is on, just to neutralize the bind_log
  my $debug_directives = $$self{opts}->{debug};
  $LaTeXML::DEBUG{latexml} = 1 if (ref $debug_directives eq 'ARRAY') && (grep { /latexml/i } @$debug_directives);
  eval { $config->check; };
  if ($@) {
    $self->bind_log;
    NoteLog($@);
    $$self{log} .= $self->flush_log; }

  return $self; }

sub prepare_session {
  my ($self, $config) = @_;
  # 1. Ensure option "sanity"
  eval { $config->check; };
  if ($@) {
    $self->bind_log;
    NoteLog($@);
    $$self{log} .= $self->flush_log; }

  my $opts                 = $config->options;
  my $opts_comparable      = { map { $_ => $$opts{$_} } @COMPARABLE };
  my $self_opts_comparable = { map { $_ => $$self{opts}{$_} } @COMPARABLE };
  #TODO: Some options like paths and includes are additive, we need special treatment there
  #2.2. Compare old and new $opts hash
  my $something_to_do;
  $something_to_do = LaTeXML::Util::ObjectDB::compare($opts_comparable, $self_opts_comparable) ? 0 : 1;
  #2.3. Set new options in converter:
  $$self{opts} = $opts;

  #3. If there is something to do, initialize a session:
  $self->initialize_session if ($something_to_do || (!$$self{ready}));

  return;
}

sub initialize_session {
  my ($self) = @_;
  $$self{runtime} = {} unless $$self{runtime};
  # TTL = time-to-live, starting with the allotted timeout (or 0 for unlimited)
  my $runtime = $$self{runtime};
  $$runtime{TTL} = $$self{opts}{timeout} unless defined $$runtime{TTL};
  $self->bind_log;
  # Empty the package namespace
  foreach my $subname (keys %LaTeXML::Package::Pool::) {
    delete $LaTeXML::Package::Pool::{$subname};
  }

  my $latexml;
  eval {
    # Prepare LaTeXML object
    local $SIG{'ALRM'} = sub { die "Fatal:conversion:init Failed to initialize LaTeXML state\n" };
    alarm($$runtime{TTL});

    $latexml = new_latexml($$self{opts});

    $$runtime{TTL} = alarm(0);
    1;
  };
  ## NOTE: This will give double errors, if latexml has already handled it!
  $$latexml{state}->noteStatus('fatal') if $latexml && $@;    # Fatal Error?
  if ($@) {                                                   #Fatal occured!
    Debug($@);
    Note("Initialization complete: " . $latexml->getStatusMessage . ". Aborting.") if defined $latexml;
    # Close and restore STDERR to original condition.
    $$self{log} .= $self->flush_log;
    $$self{ready} = 0;
    return;
  } else {
    # Demand errorless initialization
    my $init_status = $latexml->getStatusMessage;
    if ($init_status =~ /error/i) {
      Note("Initialization complete: " . $init_status . ". Aborting.");
      $$self{log} .= $self->flush_log;
      $$self{ready} = 0;
      return;
    }
  }

  # Save latexml in object:
  $$self{log} .= $self->flush_log;
  $$self{latexml} = $latexml;
  $$self{ready}   = 1;
  return;
}

sub convert {
  my ($self, $source) = @_;
  # 1 Prepare for conversion
  # 1.1 Initialize session if needed:
  # TTL = time-to-live, starting with the allotted timeout
  #       on each call to convert (or 0 for unlimited)
  $$self{runtime} = { TTL => $$self{opts}{timeout} };
  my $runtime = $$self{runtime};
  $self->initialize_session unless $$self{ready};
  if (!$$self{ready}) {    # We can't initialize, return error:
    return { result => undef, log => $self->flush_log, status => "Initialization failed.", status_code => 3 }; }

  $self->bind_log;
  # 1.2 Inform of identity, increase conversion counter
  my $opts = $$self{opts};
  ($$runtime{status}, $$runtime{status_code}) = (undef, undef);
  Note("$LaTeXML::IDENTITY");
  NoteLog("invoked as [$0 " . join(' ', @ARGV) . "]");
  Note(($$opts{recursive} ? "recursive " : "") . "processing started " . localtime());

  # 1.3 Prepare for What's IN:
  # We use a new temporary variable to avoid confusion with daemon caching
  my ($current_preamble, $current_postamble);
  # 1.3.1 Math needs to magically trigger math mode if needed
  if ($$opts{whatsin} eq "math") {
    $current_preamble  = 'literal:\begin{document}\ensuremathfollows';
    $current_postamble = 'literal:\ensuremathpreceeds\end{document}'; }
  # 1.3.2 Fragments need to have a default pre- and postamble, if none provided
  elsif ($$opts{whatsin} eq 'fragment') {
    $current_preamble  = $$opts{preamble}  || 'standard_preamble.tex';
    $current_postamble = $$opts{postamble} || 'standard_postamble.tex'; }
  # 1.3.3 Archives need to get unpacked in a sandbox (with sufficient bookkeeping)
  elsif ($$opts{whatsin} =~ /^archive/) {
    # Sandbox the input
    $$opts{archive_sourcedirectory} = $$opts{sourcedirectory};
    my $sandbox_directory = File::Temp->newdir(TMPDIR => 1);
    $$opts{sourcedirectory} = $sandbox_directory;
    # Extract the archive in the sandbox
    my $packer = LaTeXML::Util::Pack->new(
      source => $source, sandbox_directory => $sandbox_directory, type => 'zip');
    $source = $packer->unpack_source(); }
# Destination magic: If we expect an archive on output, we need to invent the appropriate destination ourselves when not given.
# Since the LaTeXML API never writes the final archive file to disk, we just use a pretend sourcename.zip:
  if (($$opts{whatsout} =~ /^archive|directory/) && $source && (!$$opts{destination})) {
    $$opts{placeholder_destination} = 1;
    $$opts{destination}             = pathname_name($source) . ".zip"; }
  # 1.3.4 If we are dealing with a directory, we need to detect the source file
  elsif ($$opts{whatsin} eq 'directory') {
    # Directories are half of the archive case - no need to unpack and sandbox,
    # but we need to find the top-level file.
    $$opts{sourcedirectory} = $source;
    my $packer = LaTeXML::Util::Pack->new(directory => $source, type => 'directory');
    $source = $packer->unpack_source();
  }
  # 1.4 Prepare for What's OUT (if we need a sandbox)
  if ($$opts{whatsout} =~ /^archive/) {
    $$opts{archive_sitedirectory} = $$opts{sitedirectory};
    $$opts{archive_destination}   = $$opts{destination};
    my $destination_name  = $$opts{destination} ? pathname_name($$opts{destination}) : 'document';
    my $sandbox_directory = File::Temp->newdir(TMPDIR => 1);
    my $extension         = $$opts{format};
    $extension =~ s/\d+$//;
    $extension =~ s/^epub|mobi$/xhtml/;
    my $sandbox_destination = "$destination_name.$extension";
    $$opts{sitedirectory} = $sandbox_directory;

    if ($$opts{format} eq 'epub') {
      $$opts{resource_directory} = File::Spec->catdir($sandbox_directory, 'OPS');
      $$opts{destination} = pathname_concat(File::Spec->catdir($sandbox_directory, 'OPS'), $sandbox_destination); }
    else {
      $$opts{destination} = pathname_concat($sandbox_directory, $sandbox_destination); } }
  # 1.4.1 Since we can allow "virtual" destinations for archives / webservice APIs,
  #       we postpone the auxiliary resource sanity check (logically of LaTeXML::Config)
  #       to this time, where we can be certain if a user has run a local job without --dest
  if ((!$$opts{destination})
    && ($$opts{dographics} || $$opts{picimages} || grep { $_ eq 'images' or $_ eq 'svg' } @{ $$opts{math_formats} })) {
    Warn("expected", "options", undef,
      "must supply --destination to support auxilliary files",
      "  disabling: --nomathimages --nographicimages --nopictureimages");
    # default resources is sorta ok: we might not copy, but we'll still have the links/script/etc
    $$opts{dographics} = 0;
    $$opts{picimages}  = 0;
    removeMathFormat($opts, 'images');
    removeMathFormat($opts, 'svg');
    maybeAddMathFormat($opts, 'pmml'); }

  # 1.5 Prepare a daemon frame
  my $latexml = $$self{latexml};
  $latexml->withState(sub {
      my ($state) = @_;    # Sandbox state
      $$state{status} = {};
      my $stomach = $$state{stomach};
      delete $$stomach{rescued_boxes} if $$stomach{rescued_boxes};
      $state->pushDaemonFrame;
      $state->assignValue('_authlist',      $$opts{authlist}, 'global');
      $state->assignValue('REMOTE_REQUEST', (!$$opts{local}), 'global');
  });

  # 2 Beginning Core conversion - digest the source:
  my ($digested, $dom, $serialized) = (undef, undef, undef);
  eval {
    alarm($$runtime{TTL});
    my $mode = ($$opts{type} eq 'auto') ? 'TeX' : $$opts{type};
    $digested = $latexml->digestFile($source, preamble => $current_preamble,
      postamble    => $current_postamble,
      mode         => $mode,
      noinitialize => 1);
    $$runtime{TTL} = alarm(0); };
  my $eval_report = $@;
  if ($source && !$digested && $eval_report) {
    # We can retry finishing digestion if hit a Fatal,
    # sometimes there are leftover boxes we can accept.
    eval {
      alarm($$runtime{TTL});
      $digested = $latexml->withState(sub {
          return $latexml->finishDigestion; });
      $$runtime{TTL} = alarm(0); };
    $eval_report .= $@ if $@; }
  # 2.1 Now, convert to DOM and output, if desired.
  my $core_target = $$opts{format};
  # Default Core target is XML
  if ($core_target ne 'tex' and $core_target ne 'box') {
    $core_target = 'xml'; }
  if ($digested) {
    eval {
      alarm($$runtime{TTL});
      $latexml->withState(sub {
          if ($core_target eq 'tex') {
            $serialized = LaTeXML::Core::Token::UnTeX($digested); }
          elsif ($core_target eq 'box') {
            $serialized = ($$opts{verbosity} > 0 ? $digested->stringify : $digested->toString); }
          elsif ($core_target eq 'xml') {
            $dom = $latexml->convertDocument($digested); } });
      $$runtime{TTL} = alarm(0); };
    $eval_report .= $@ if $@;
    # Try to rescue the document if e.g. math parsing hit a Fatal error
    if (!$dom && $@ && ($core_target eq 'xml')) {
      $dom = $latexml->withState(sub {
          my ($state) = @_;
          my $rescued = $$state{rescued_document};
          $rescued->finalize() if $rescued;
          return $rescued; }); } }
  $$runtime{status}      = $latexml->getStatusMessage;
  $$runtime{status_code} = $latexml->getStatusCode;

  $latexml->showProfile();    # Show profile (if any)

  # 2.2 Bookkeeping in case in-eval perl die() deaths occurred
  if ($eval_report) {
    $$runtime{status} .= "\n" . $eval_report . "\n";
    $$runtime{status_code} = 3; }

  # End daemon run, by popping frame:
  $latexml->withState(sub {
      my ($state) = @_;    # Remove current state frame
      ## TODO: This section of option preparations can be factored out as a subroutine if it grows further
      ##       the general idea is that right before the "pop" of the daemon frame, we have access to all meaningful
      ##       global state values, and we can preserve the relevant ones for the post-processing stage
      ## BEGIN POST-PROCESSING-PREP
      $$opts{searchpaths} = $state->lookupValue('SEARCHPATHS'); # save the searchpaths for post-processing
      if ($state->lookupValue('LEXEMATIZE_MATH')) {  # save potential request for serializing math lexemes
        $$opts{math_formats} ||= [];
        push @{ $$opts{math_formats} }, 'lexemes';
        # recheck need for parallel
        $$opts{parallelmath} = 1 if (@{ $$opts{math_formats} } > 1); }
      ## END POST-PROCESSING-PREP
      $state->popDaemonFrame;
  });
  if ($LaTeXML::UNSAFE_FATAL) {
    # If the conversion hit an unsafe fatal, we need to reinitialize
    $LaTeXML::UNSAFE_FATAL = 0;
    $$self{ready} = 0;
  }
  Note(($$opts{recursive} ? "recursive " : "") . "Conversion complete: " . $$runtime{status});

  # 2.3 Clean up and exit if we only wanted the serialization of the core conversion
  if ($serialized) {
    # If serialized has been set, we are done with the job
    # If we just processed an archive, clean up sandbox directory.
    if ($$opts{whatsin} =~ /^archive/) {
      rmtree($$opts{sourcedirectory});
      $$opts{sourcedirectory} = $$opts{archive_sourcedirectory}; }
    return { result => $serialized, log => $self->flush_log, status => $$runtime{status}, status_code => $$runtime{status_code} };
  }

  # 3 If desired, post-process
  my $result = $dom;
  if ($$opts{post}) {
    if ($dom) {
      if (!$dom->documentElement) {
        # Make a completely empty document have at least one element for post-processing
        # important for utility features such as packing .zip archives for output
        $$dom{document}->setDocumentElement($$dom{document}->createElement("document"));
      }
    }
    $result = $self->convert_post($dom); }
  # 4 Clean-up: undo everything we sandboxed
  if ($$opts{whatsin} =~ /^archive/) {
    rmtree($$opts{sourcedirectory});
    $$opts{sourcedirectory} = $$opts{archive_sourcedirectory}; }
  if ($$opts{whatsout} =~ /^archive/) {
    rmtree($$opts{sitedirectory});
    $$opts{sitedirectory} = $$opts{archive_sitedirectory};
    $$opts{destination}   = $$opts{archive_destination};
    if (delete $$opts{placeholder_destination}) {
      delete $$opts{destination}; } }

# 5 Output -- if not using Post::Writer, which never considers this serialization logic
#
# 5.1 Serialize the XML/HTML result (or just return the Perl object, if requested)
# GOAL: $serialized must contain a utf8-encoded string at the return.
#
# This logic can be fragile, especially due to external components changing behavior between versions.
# but also due to having a variety of serialization routes based on Core vs Post, whatsout, destination...
#
  undef $serialized;
  my $ref_result = ref($result) || '';
  if ($$opts{format} eq 'dom') {    # No serialize needed in DOM output case
    $serialized = $result; }
  elsif ($ref_result =~ /^(:?LaTe)?XML/) {
    if ($$opts{format} =~ /^jats|x(ht)?ml$/) {
      if ($ref_result =~ /Document$/) {
        $serialized = $result->toString(1);
        if ($serialized and $ref_result eq 'LaTeXML::Core::Document') {
          $serialized = Encode::encode('UTF-8', $serialized); }
      } else {    # fragment case
        $serialized = $result->toString(1, 1);
    } }
    elsif ($$opts{format} =~ /^html/) {
      if (ref($result) =~ /^LaTeXML::(Post::)?Document$/) {
        $serialized = $result->getDocument->toStringHTML; }
      else {      # fragment case
        local $XML::LibXML::setTagCompression = 1;
        $serialized = $result->toString(1, 1); } } }
  # Compressed/archive/other case, just pass on
  else { $serialized = $result; }

  # 5.2 Finalize logging and return a response containing the document result, log and status
  Note("Status:conversion:" . ($$runtime{status_code} || '0'));
  return { result => $serialized, log => $self->flush_log, status => $$runtime{status}, 'status_code' => $$runtime{status_code} };
}

###########################################
####       Converter Management       #####
###########################################

our %DAEMON_CACHE = ();
our %CONFIG_CACHE = ();

sub get_converter {
  my ($self, $config, $key) = @_;
  # Default key, unless made explicit
  if (!$key && $config) {
    $key = $config->get('cache_key') || $config->get('profile'); }

  my $converter = $key && $DAEMON_CACHE{$key};

  if (!defined $converter) {
    # Trading flexibility for performance:
    # once a cache_key is used, it can not be redefined in the same session
    # (and we never needed it redefine-able)
    #
    # Instead, once a cache_key is specified, (re)booting converter objects
    # for that config set can be done without spending time examining options
    # via the $CONFIG_CACHE
    $config ||= $CONFIG_CACHE{$key};

    $converter = LaTeXML->new($config->clone);
    if ($key) {
      # cache both converter and config, for self-contained reloading
      $DAEMON_CACHE{$key} = $converter;
      $CONFIG_CACHE{$key} = $config; } }
  return $converter; }

###########################################
####       Helper routines            #####
###########################################
sub convert_post {
  my ($self, $dom) = @_;
  my $opts    = $$self{opts};
  my $runtime = $$self{runtime};
  my ($xslt, $parallel, $math_formats, $format, $verbosity, $defaultresources, $embed) =
    map { $$opts{$_} } qw(stylesheet parallelmath math_formats format verbosity defaultresources embed);
##  $verbosity = $verbosity || 0;
  SetVerbosity($verbosity) if defined $verbosity;
  my %PostOPS = (    ####verbosity => $verbosity,
    validate           => $$opts{validate},
    sourceDirectory    => $$opts{sourcedirectory},
    siteDirectory      => $$opts{sitedirectory},
    resource_directory => $$opts{resource_directory},
    searchpaths        => $$opts{searchpaths},
    nocache            => 1,
    destination        => $$opts{destination},
    is_html            => $$opts{is_html});
  # Compute destinationDirectory here,
  #   so that we don't depend on post-processing returning a usable Post::Document (Fatal-resilience)
  if ($PostOPS{destination}) {
    my ($dir, $name, $ext) = pathname_split($PostOPS{destination});
    $PostOPS{destinationDirectory} = $dir || '.'; }

  #Postprocess
  $parallel = $parallel || 0;

  my $DOCUMENT = $dom && LaTeXML::Post::Document->new($dom, %PostOPS);
  my @procs    = ();
  #TODO: Add support for the following:
  my $dbfile = $$opts{dbfile};
  if (defined $dbfile && !pathname_test_f($dbfile)) {
    if (my $dbdir = pathname_directory($dbfile)) {
      pathname_mkdir($dbdir); } }
  my $DB = LaTeXML::Util::ObjectDB->new(dbfile => $dbfile, %PostOPS);
  if ($format eq 'epub') {    # epub requires a TOC
    $self->check_TOC($DOCUMENT) if $DOCUMENT; }
  ### Advanced Processors:
  if ($$opts{split} && $DOCUMENT) {
    require LaTeXML::Post::Split;
    push(@procs, LaTeXML::Post::Split->new(split_xpath => $$opts{splitpath}, splitnaming => $$opts{splitnaming},
        db => $DB, %PostOPS)); }
  my $scanner = ($$opts{scan} || $DB) && (LaTeXML::Post::Scan->new(
      db       => $DB,
      labelids => ($$opts{splitnaming} && ($$opts{splitnaming} =~ /^label/) ? 1 : 0),
      %PostOPS));
  push(@procs, $scanner) if $$opts{scan};
  if (!($$opts{prescan}) && $DOCUMENT) {
    if ($$opts{index}) {
      require LaTeXML::Post::MakeIndex;
      push(@procs, LaTeXML::Post::MakeIndex->new(db => $DB, permuted => $$opts{permutedindex},
          split => $$opts{splitindex}, scanner => $scanner,
          %PostOPS)); }
    require LaTeXML::Post::MakeBibliography;
    push(@procs, LaTeXML::Post::MakeBibliography->new(db => $DB, bibliographies => $$opts{bibliographies},
        split => $$opts{splitbibliography}, scanner => $scanner,
        %PostOPS));
    if ($$opts{crossref}) {
      require LaTeXML::Post::CrossRef;
      push(@procs, LaTeXML::Post::CrossRef->new(
          db        => $DB, urlstyle => $$opts{urlstyle},
          extension => $$opts{extension},
          ($$opts{numbersections} ? (number_sections => 1)              : ()),
          ($$opts{navtoc}         ? (navigation_toc  => $$opts{navtoc}) : ()),
          %PostOPS)); }
    if ($$opts{picimages}) {
      require LaTeXML::Post::PictureImages;
      push(@procs, LaTeXML::Post::PictureImages->new(%PostOPS));
    }
    else {
      require LaTeXML::Post::PictureImages;
      push(@procs, LaTeXML::Post::PictureImages->new(empty_only => 1, %PostOPS)); }

    if ($$opts{dographics}) {
      # TODO: Rethink full-fledged graphics support
      require LaTeXML::Post::Graphics;
      my @g_options = ();
      if ($$opts{graphicsmaps} && scalar(@{ $$opts{graphicsmaps} })) {
        my @maps = map { [split(/\./, $_)] } @{ $$opts{graphicsmaps} };
        push(@g_options, (graphics_types => [map { $$_[0] } @maps],
            type_properties => { map { ($$_[0] => { destination_type => ($$_[1] || $$_[0]) }) } @maps })); }
      push(@procs, LaTeXML::Post::Graphics->new(@g_options, %PostOPS));
    }
    if ($$opts{svg}) {
      require LaTeXML::Post::SVG;
      push(@procs, LaTeXML::Post::SVG->new(%PostOPS)); }
    if (@$math_formats) {
      my @mprocs = ();
      ###    # If XMath is not first, it must be at END!  Or... ???
      foreach my $fmt (@$math_formats) {
        if ($fmt eq 'xmath') {
          require LaTeXML::Post::XMath;
          push(@mprocs, LaTeXML::Post::XMath->new(%PostOPS)); }
        elsif ($fmt eq 'pmml') {
          require LaTeXML::Post::MathML::Presentation;
          push(@mprocs, LaTeXML::Post::MathML::Presentation->new(
              linelength => $$opts{linelength},
              (defined $$opts{plane1}         ? (plane1         => $$opts{plane1}) : (plane1 => 1)),
              ($$opts{hackplane1}             ? (hackplane1     => 1)              : ()),
              (defined $$opts{invisibletimes} ? (invisibletimes => $$opts{invisibletimes}) :
                  (invisibletimes => 1)),
              %PostOPS)); }
        elsif ($fmt eq 'cmml') {
          require LaTeXML::Post::MathML::Content;
          push(@mprocs, LaTeXML::Post::MathML::Content->new(
              (defined $$opts{plane1} ? (plane1     => $$opts{plane1}) : (plane1 => 1)),
              ($$opts{hackplane1}     ? (hackplane1 => 1)              : ()),
              %PostOPS)); }
        elsif ($fmt eq 'om') {
          require LaTeXML::Post::OpenMath;
          push(@mprocs, LaTeXML::Post::OpenMath->new(
              (defined $$opts{plane1} ? (plane1     => $$opts{plane1}) : (plane1 => 1)),
              ($$opts{hackplane1}     ? (hackplane1 => 1)              : ()),
              %PostOPS)); }
        elsif ($fmt eq 'images') {
          require LaTeXML::Post::MathImages;
          push(@mprocs, LaTeXML::Post::MathImages->new(magnification => $$opts{mathimagemag},
              %PostOPS)); }
        elsif ($fmt eq 'svg') {
          require LaTeXML::Post::MathImages;
          push(@mprocs, LaTeXML::Post::MathImages->new(magnification => $$opts{mathimagemag},
              imagetype => 'svg',
              %PostOPS)); }
        elsif ($fmt eq 'mathtex') {
          require LaTeXML::Post::TeXMath;
          push(@mprocs, LaTeXML::Post::TeXMath->new(%PostOPS)); }
        elsif ($fmt eq 'unicodemath') {
          require LaTeXML::Post::UnicodeMath;
          push(@mprocs, LaTeXML::Post::UnicodeMath->new(%PostOPS)); }
        elsif ($fmt eq 'lexemes') {
          require LaTeXML::Post::LexMath;
          push(@mprocs, LaTeXML::Post::LexMath->new(%PostOPS)); }
      }
      ###    $keepXMath  = 0 unless defined $keepXMath;
      ### OR is $parallelmath ALWAYS on whenever there's more than one math processor?
      if ($parallel) {
        my $main = shift(@mprocs);
        $main->setParallel(@mprocs);
        push(@procs, $main); }
      else {
        push(@procs, @mprocs); }
    }
    if ($xslt) {
      require LaTeXML::Post::XSLT;
      my $parameters  = { LATEXML_VERSION => "'$LaTeXML::VERSION'" };
      my @searchpaths = ('.', $DOCUMENT->getSearchPaths);
      # store these for the XSLT; XSLT Processor will copy resources where needed.
      foreach my $css (@{ $$opts{css} }) {
        push(@{ $$parameters{CSS} }, $css); }
      foreach my $js (@{ $$opts{javascript} }) {
        push(@{ $$parameters{JAVASCRIPT} }, $js); }
      if ($$opts{icon}) {
        $$parameters{ICON} = $$opts{icon}; }
      if (!defined $$opts{timestamp}) { $$opts{timestamp} = defined $ENV{SOURCE_DATE_EPOCH} ? gmtime($ENV{SOURCE_DATE_EPOCH}) : localtime(); }
      if ($$opts{timestamp}) { $$parameters{TIMESTAMP} = "'" . $$opts{timestamp} . "'"; }
      # Now add in the explicitly given XSLT parameters
      foreach my $parm (@{ $$opts{xsltparameters} }) {
        if ($parm =~ /^\s*(\w+)\s*:\s*(.*)$/) {
          $$parameters{$1} = "'" . $2 . "'"; }
        else {
          warn "xsltparameter not in recognized format: 'name:value' got: '$parm'\n"; }
      }

      push(@procs, LaTeXML::Post::XSLT->new(stylesheet => $xslt,
          parameters  => $parameters,
          searchpaths => [@searchpaths],
          noresources => (defined $$opts{defaultresources}) && !$$opts{defaultresources},
          %PostOPS));
    }
  }

  # If we are doing a local conversion OR
  # we are going to package into an archive
  # write all the files to disk during post-processing
  if ($$opts{destination} &&
    (($$opts{local} && ($$opts{whatsout} eq 'document'))
      || ($$opts{whatsout} =~ /^archive/))) {
    require LaTeXML::Post::Writer;
    push(@procs, LaTeXML::Post::Writer->new(
        format => $format, omit_doctype => $$opts{omit_doctype},
        %PostOPS));
  }

  # Do the actual post-processing:
  my @postdocs;
##  my $latexmlpost      = LaTeXML::Post->new(verbosity => $verbosity || 0);
  my $latexmlpost = LaTeXML::Post->new();
  eval {
    alarm($$runtime{TTL});
    @postdocs = $DOCUMENT && $latexmlpost->ProcessChain($DOCUMENT, @procs);
    $$runtime{TTL} = alarm(0);
    1; };
  # 3.1 Bookkeeping if a post-processing Fatal error occurred
  if ($@) {    #Fatal occured!
    $$runtime{status_code} = 3;
    local $@ = 'Fatal:conversion:unknown ' . $@ unless $@ =~ /^\n?\S*Fatal:/s;
    Debug($@); }

  # Finalize by arranging any manifests and packaging the output.
  # If our format requires a manifest, create one
  if (($$opts{whatsout} =~ /^archive/) && ($format !~ /^x?html|xml|jats/)) {
    require LaTeXML::Post::Manifest;
    my $manifest_maker = LaTeXML::Post::Manifest->new(db => $DB, format => $format, log => $$opts{log}, %PostOPS);
    $manifest_maker->process(@postdocs); }
  # Archives: when a relative --log is requested, write to sandbox prior packing
  #     TODO: This can be enhanced, as any path can be relativized.
  #     TODO: ALSO, we now always have a log file, so maybe always add it as default?
  if ($$opts{log} && ($$opts{whatsout} =~ /^archive/) && (!pathname_is_absolute($$opts{log}))) {
    ### We can't rely on the ->getDestinationDirectory method, as Fatal post-processing jobs have UNDEF @postdocs !!!
    ### my $destination_directory = $postdocs[0]->getDestinationDirectory();
    my $destination_directory = $PostOPS{destinationDirectory};
    my $log_file              = pathname_absolute($$opts{log}, $destination_directory);
    if (pathname_is_contained($log_file, $destination_directory)) {
      NoteLog(($$opts{recursive} ? "recursive " : "") . "Post-processing complete: " . $latexmlpost->getStatusMessage);
      NoteLog(($$opts{recursive} ? "recursive " : "") . "processing finished " . localtime());
      my $archive_log_status_code = max($$runtime{status_code}, $latexmlpost->getStatusCode);
      Note("Status:conversion:" . $archive_log_status_code);
      open my $log_fh, '>', $log_file;
      print $log_fh $self->flush_log;
      close $log_fh;
      $self->bind_log; }
# TODO: This needs a bit of rethinking, likely a fallback.log file should be created and returned with the archive
    else { Error("I/O", "log", "The target log file isn't contained in the destination directory!"); } }
  # Handle the output packaging

  my ($postdoc) = pack_collection(collection => [@postdocs], whatsout => $$opts{whatsout}, format => $format, %PostOPS);

  $DB->finish;

  # Merge postprocessing and main processing reports
  ### HACKY until we use a single Core::State object, we'll just "wing it" for status messages:
  my $post_status = $latexmlpost->getStatusMessage;
  if ($post_status ne $$runtime{status}) {    # Just so that we avoid double "No problem" reporting
    $$runtime{status} .= "\n" . $post_status;
  }
  $$runtime{status_code} = max($$runtime{status_code}, $latexmlpost->getStatusCode);
  ### HACKY END
  Note(($$opts{recursive} ? "recursive " : "") . "Post-processing complete: " . $latexmlpost->getStatusMessage);
  NoteLog(($$opts{recursive} ? "recursive " : "") . "processing finished " . localtime());

  # Avoid writing the main file twice (non-archive documents):
  if ($$opts{destination} && $$opts{local} && ($$opts{whatsout} eq 'document')) {
    undef $postdoc; }
  return $postdoc; }

# This is *very* unmodular, but introducing a pre-Epub postprocessor
# seems rather heavy at this stage?
# Add a full TOC, to be used for navigation, but *not* displayed.
sub check_TOC {
  my ($self, $document) = @_;
  if (!$document->findnode('//ltx:TOC[@lists="toc"]')) {
    my @s = (qw(ltx:part ltx:chapter ltx:section ltx:subsection ltx:subsubsection
        ltx:paragraph ltx:subparagraph ltx:appendix ltx:index ltx:bibliography));
    $document->prependNodes($document->getDocumentElement,
      ['ltx:TOC', { lists => 'toc', scope => 'global',
          select => join(' | ', @s), class => 'ltx_nodisplay' }]); }
  return; }

sub new_latexml {
  my ($opts) = @_;

  # TODO: Do this in a GOOD way to support filepath/URL/string snippets
  # If we are given string preloads, load them and remove them from the preload list:
  my $preloads = $$opts{preload};
  my (@pre, @str_pre);
  foreach my $pre (@$preloads) {
    if (pathname_is_literaldata($pre)) {
      push @str_pre, $pre;
    } else {
      push @pre, $pre;
    }
  }
  my $includepathpis = !(exists $$opts{xsltparameters} &&
    (grep { $_ eq 'LATEXML_VERSION:TEST' } @{ $$opts{xsltparameters} }));
  require LaTeXML;
  SetVerbosity($$opts{verbosity}) if defined $$opts{verbosity};
  my $latexml = LaTeXML::Core->new(preload => [@pre], searchpaths => [@{ $$opts{paths} }],
    graphicspaths => ['.'],
###    verbosity       => $$opts{verbosity}, strict => $$opts{strict},
    includecomments => $$opts{comments},
    includepathpis  => $includepathpis,
    inputencoding   => $$opts{inputencoding},
    includestyles   => $$opts{includestyles},
    documentid      => $$opts{documentid},
    nomathparse     => $$opts{nomathparse},     # Backwards compatibility
    mathparse       => $$opts{mathparse});

  if (my @baddirs = grep { !-d $_ } @{ $$opts{paths} }) {
    warn "\n$LaTeXML::IDENTITY : these path directories do not exist: " . join(', ', @baddirs) . "\n"; }

  $latexml->withState(sub {
      my ($state) = @_;
      $latexml->initializeState('TeX.pool', @{ $$latexml{preload} || [] });
  });

  # TODO: Do again, need to do this in a GOOD way as well:
  $latexml->digestFile($_, noinitialize => 1) foreach (@str_pre);

  return $latexml;
}

sub bind_log {
  my ($self) = @_;
  my $opts = $$self{opts};
  # For now --whatsout=archive just gets deferred back to the old code
  # But this needs a streamlined refactor in the future.
  # Something to consider:
  # 1. Multiple latexml_workers are started in the same CWD by their harness
  # 2. Before an archive job starts, they would be opening the same default
  # "latexml.log" or "cortex.log" etc.
  # 3. The final log destination is available only after the temp dir is setup
  # ... So we may want to completely remodel the whatsout handling
  #     but what is cleanest and least confusing?
  if (my $logfile = $$opts{log}) {
    my $whatsout = $$opts{whatsout};
    if ($whatsout && ($whatsout !~ /^archive/)) {
      UseLog($logfile, 1); }
    else {
      UseLog(\$$self{log}, 1);
    }
  } else {
    UseLog(\$$self{log}, 1); }
  return; }

sub flush_log {
  my ($self) = @_;
  UseLog(undef);
  my $log = $$self{log};
  $$self{log} = q{};
  return $log; }

1;

__END__

=pod

=head1 NAME

C<LaTeXML> - A converter that transforms TeX and LaTeX into XML/HTML/MathML

=head1 SYNOPSIS

    use LaTeXML;
    my $converter = LaTeXML->get_converter($config);
    my $converter = LaTeXML->new($config);
    $converter->prepare_session($opts);
    $converter->initialize_session; # SHOULD BE INTERNAL
    $hashref = $converter->convert($tex);
    my ($result,$log,$status)
         = map {$hashref->{$_}} qw(result log status);

=head1 DESCRIPTION

LaTeXML is a converter that transforms TeX and LaTeX into XML/HTML/MathML
and other formats.

A LaTeXML object represents a converter instance and can convert files on demand, until dismissed.

=head2 METHODS

=over 4

=item C<< my $converter = LaTeXML->new($config); >>

Creates a new converter object for a given LaTeXML::Common::Config object, $config.

=item C<< my $converter = LaTeXML->get_converter($config); >>

Either creates, or looks up a cached converter for the $config configuration object.

=item C<< $converter->prepare_session($opts); >>

Top-level preparation routine that prepares both a correct options object
    and an initialized LaTeXML object,
    using the "initialize_options" and "initialize_session" routines, when needed.

Contains optimization checks that skip initializations unless necessary.

Also adds support for partial option specifications during daemon runtime,
     falling back on the option defaults given when converter object was created.

=item C<< my ($result,$status,$log) = $converter->convert($tex); >>

Converts a TeX input string $tex into the LaTeXML::Core::Document object $result.

Supplies detailed information of the conversion log ($log),
         as well as a brief conversion status summary ($status).

=back

=head2 INTERNAL ROUTINES

=over 4

=item C<< $converter->initialize_session($opts); >>

Given an options hash reference $opts, initializes a session by creating a new LaTeXML object
      with initialized state and loading a daemonized preamble (if any).

Sets the "ready" flag to true, making a subsequent "convert" call immediately possible.

=item C<< my $latexml = new_latexml($opts); >>

Creates a new LaTeXML object and initializes its state.

=item C<< my $postdoc = $converter->convert_post($dom); >>

Post-processes a LaTeXML::Core::Document object $dom into a final format,
               based on the preferences specified in $$self{opts}.

Typically used only internally by C<convert>.

=item C<< $converter->bind_log; >>

Binds STDERR to a "log" field in the $converter object

=item C<< my $log = $converter->flush_log; >>

Flushes out the accumulated conversion log into $log,
         resetting STDERR to its usual stream.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>
Deyan Ginev <deyan.ginev@gmail.com>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.
You may consider this as released under the CC0 License.

=cut
