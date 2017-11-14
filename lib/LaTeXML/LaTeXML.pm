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
use Data::Dumper;
use File::Temp;
File::Temp->safe_level(File::Temp::HIGH);
use File::Path qw(rmtree);
use File::Spec;
use List::Util qw(max);
use LaTeXML::Common::Config;
use LaTeXML::Core;
use LaTeXML::Util::Pack;
use LaTeXML::Util::Pathname;
use LaTeXML::Util::WWW;
use LaTeXML::Util::ObjectDB;
use LaTeXML::Post::Scan;
use vars qw($VERSION);
# This is the main version of LaTeXML being claimed.
use version; our $VERSION = version->declare("0.8.2");
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
our %DAEMON_DB = ();

sub new {
  my ($class, $config) = @_;
  $config = LaTeXML::Common::Config->new() unless (defined $config);
  # The daemon should be setting the identity:
  my $self = bless { opts => $config->options, ready => 0, log => q{}, runtime => {},
    latexml => undef }, $class;
  # Special check if the debug directive is on, just to neutralize the bind_log
  my $debug_directives = $$self{opts}->{debug};
  $LaTeXML::DEBUG = 1 if (ref $debug_directives eq 'ARRAY') && (grep { /latexml/i } @$debug_directives);
  $self->bind_log;
  my $rv = eval { $config->check; };
  $$self{log} .= $self->flush_log;
  return $self; }

sub prepare_session {
  my ($self, $config) = @_;
  # TODO: The defaults feature was never used, do we really want it??
  #0. Ensure all default keys are present:
  # (always, as users can specify partial options that build on the defaults)
  #foreach (keys %{$$self{defaults}}) {
  #  $config->{$_} = $$self{defaults}->{$_} unless exists $config->{$_};
  #}
  # 1. Ensure option "sanity"
  $self->bind_log;
  my $rv = eval { $config->check; };
  $$self{log} .= $self->flush_log;

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
  $$self{runtime} = {};
  $self->bind_log;
  # Empty the package namespace
  foreach my $subname (keys %LaTeXML::Package::Pool::) {
    delete $LaTeXML::Package::Pool::{$subname};
  }

  my $latexml;
  my $init_eval_return = eval {
    # Prepare LaTeXML object
    local $SIG{'ALRM'} = sub { die "Fatal:conversion:init Failed to initialize LaTeXML state\n" };
    alarm($$self{opts}{timeout});

    $latexml = new_latexml($$self{opts});

    alarm(0);
    1;
  };
  ## NOTE: This will give double errors, if latexml has already handled it!
  $$latexml{state}->noteStatus('fatal') if $latexml && $@;    # Fatal Error?
  local $@ = 'Fatal:conversion:unknown Session initialization failed! (Unknown reason)' if ((!$init_eval_return) && (!$@));
  if ($@) {                                                   #Fatal occured!
    print STDERR "$@\n";
    print STDERR "\nInitialization complete: " . $latexml->getStatusMessage . ". Aborting.\n" if defined $latexml;
    # Close and restore STDERR to original condition.
    $$self{log} .= $self->flush_log;
    $$self{ready} = 0;
    return;
  } else {
    # Demand errorless initialization
    my $init_status = $latexml->getStatusMessage;
    if ($init_status =~ /error/i) {
      print STDERR "\nInitialization complete: " . $init_status . ". Aborting.\n";
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
  $$self{runtime} = {};
  $self->initialize_session unless $$self{ready};
  if (!$$self{ready}) {    # We can't initialize, return error:
    return { result => undef, log => $$self{log}, status => "Initialization failed.", status_code => 3 };
  }

  $self->bind_log;
  # 1.2 Inform of identity, increase conversion counter
  my $opts    = $$self{opts};
  my $runtime = $$self{runtime};
  ($$runtime{status}, $$runtime{status_code}) = (undef, undef);
  if ($$opts{verbosity} >= 0) {
    print STDERR "$LaTeXML::IDENTITY\n";
    print STDERR "invoked as [$0 " . join(' ', @ARGV) . "]\n" if $$opts{verbosity} >= 1;
    print STDERR "processing started " . localtime() . "\n"; }

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
    $source = unpack_source($source, $sandbox_directory);
    if (!defined $source) {    # Unpacking failed to find a source
      $$opts{sourcedirectory} = $$opts{archive_sourcedirectory};
      my $log = $self->flush_log;
      $log .= "\nFatal:invalid:Archive Can't detect a source TeX file!\nStatus:conversion:3\n";
      return { result => undef, log => $log, status => "Fatal:invalid:Archive Can't detect a source TeX file!", status_code => 3 }; }
# Destination magic: If we expect an archive on output, we need to invent the appropriate destination ourselves when not given.
# Since the LaTeXML API never writes the final archive file to disk, we just use a pretend sourcename.zip:
    if (($$opts{whatsout} =~ /^archive/) && (!$$opts{destination})) {
      $$opts{placeholder_destination} = 1;
      $$opts{destination}             = pathname_name($source) . ".zip"; } }

  # 1.4 Prepare for What's OUT (if we need a sandbox)
  if ($$opts{whatsout} =~ /^archive/) {
    $$opts{archive_sitedirectory} = $$opts{sitedirectory};
    $$opts{archive_destination}   = $$opts{destination};
    my $destination_name = $$opts{destination} ? pathname_name($$opts{destination}) : 'document';
    my $sandbox_directory = File::Temp->newdir(TMPDIR => 1);
    my $extension = $$opts{format};
    $extension =~ s/\d+$//;
    $extension =~ s/^epub|mobi$/xhtml/;
    my $sandbox_destination = "$destination_name.$extension";
    $$opts{sitedirectory} = $sandbox_directory;

    if ($$opts{format} eq 'epub') {
      $$opts{resource_directory} = File::Spec->catdir($sandbox_directory, 'OPS');
      $$opts{destination} = pathname_concat(File::Spec->catdir($sandbox_directory, 'OPS'), $sandbox_destination); }
    else {
      $$opts{destination} = pathname_concat($sandbox_directory, $sandbox_destination); }
  }

  # 1.5 Prepare a daemon frame
  my $latexml = $$self{latexml};
  $latexml->withState(sub {
      my ($state) = @_;    # Sandbox state
      $state->pushDaemonFrame;
      $state->assignValue('_authlist', $$opts{authlist}, 'global');
      $state->assignValue('REMOTE_REQUEST', (!$$opts{local}), 'global');
  });

  # 2 Beginning Core conversion - digest the source:
  my ($digested, $dom, $serialized) = (undef, undef, undef);
  my $convert_eval_return = eval {
    # Should be this, but is overridden by withState.
    #local $SIG{'ALRM'} = sub { LaTeXML::Common::Error::Fatal('conversion','timeout',
    # "Conversion timed out after " . $$opts{timeout} . " seconds!\n"); };
    alarm($$opts{timeout});
    my $mode = ($$opts{type} eq 'auto') ? 'TeX' : $$opts{type};
    $digested = $latexml->digestFile($source, preamble => $current_preamble,
      postamble    => $current_postamble,
      mode         => $mode,
      noinitialize => 1);
    # 2.1 Now, convert to DOM and output, if desired.
    if ($digested) {
      $latexml->withState(sub {
          if ($$opts{format} eq 'tex') {
            $serialized = LaTeXML::Core::Token::UnTeX($digested);
          } elsif ($$opts{format} eq 'box') {
            $serialized = ($$opts{verbosity} > 0 ? $digested->stringify : $digested->toString);
          } else {    # Default is XML
            $dom = $latexml->convertDocument($digested);
          }
          }); }
    alarm(0);
    1;
  };
  # 2.2 Bookkeeping in case fatal errors occurred
  ### Note: this cause double counting if LaTeXML has already handled it.
  ### But leaving it might might miss errors that sneak through (can that happen?)
  ####  $$latexml{state}->noteStatus('fatal') if $latexml && $@;    # Fatal Error?
  local $@ = 'Fatal:conversion:unknown TeX to XML conversion failed! (Unknown Reason)' if ((!$convert_eval_return) && (!$@));
  my $eval_report = $@;
  $$runtime{status}      = $latexml->getStatusMessage;
  $$runtime{status_code} = $latexml->getStatusCode;

  # End daemon run, by popping frame:
  $latexml->withState(sub {
      my ($state) = @_;    # Remove current state frame
      $$opts{searchpaths} = $state->lookupValue('SEARCHPATHS'); # save the searchpaths for post-processing
      $state->popDaemonFrame;
      $$state{status} = {};
  });
  if ($LaTeXML::UNSAFE_FATAL) {
    # If the conversion hit an unsafe fatal, we need to reinitialize
    $LaTeXML::UNSAFE_FATAL = 0;
    $$self{ready} = 0;
  }
  if ($eval_report || ($$runtime{status_code} == 3)) {
    # Terminate immediately on Fatal errors
    $$runtime{status_code} = 3;
    print STDERR $eval_report . "\n" if $eval_report;
    print STDERR "\nConversion complete: " . $$runtime{status} . ".\n";
    print STDERR "Status:conversion:" . ($$runtime{status_code} || '0') . "\n";
    # If we just processed an archive, clean up sandbox directory.
    if ($$opts{whatsin} =~ /^archive/) {
      rmtree($$opts{sourcedirectory});
      $$opts{sourcedirectory} = $$opts{archive_sourcedirectory}; }

    # Close and restore STDERR to original condition.
    my $log = $self->flush_log;
    $serialized = $dom if ($$opts{format} eq 'dom');
    $serialized = $dom->toString if ($dom && (!defined $serialized));

    return { result => $serialized, log => $log, status => $$runtime{status}, status_code => $$runtime{status_code} }; }
  else {
    # Standard report, if we're not in a Fatal case
    print STDERR "\nConversion complete: " . $$runtime{status} . ".\n"; }

  # 2.3 Clean up and exit if we only wanted the serialization of the core conversion
  if ($serialized) {
    # If serialized has been set, we are done with the job
    # If we just processed an archive, clean up sandbox directory.
    if ($$opts{whatsin} =~ /^archive/) {
      rmtree($$opts{sourcedirectory});
      $$opts{sourcedirectory} = $$opts{archive_sourcedirectory}; }
    my $log = $self->flush_log;
    return { result => $serialized, log => $log, status => $$runtime{status}, status_code => $$runtime{status_code} };
  }

  # 3 If desired, post-process
  my $result = $dom;
  if ($$opts{post} && $dom && $dom->documentElement) {
    $result = $self->convert_post($dom);
  }
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

  # 5 Output
  # 5.1 Serialize the XML/HTML result (or just return the Perl object, if requested)
  undef $serialized;
  if ((defined $result) && ref($result) && (ref($result) =~ /^(:?LaTe)?XML/)) {
    if (($$opts{format} =~ /x(ht)?ml/) || ($$opts{format} eq 'jats')) {
      $serialized = $result->toString(1); }
    elsif ($$opts{format} =~ /^html/) {
      if (ref($result) =~ /^LaTeXML::(Post::)?Document$/) {    # Special for documents
        $serialized = $result->getDocument->toStringHTML; }
      else {                                                   # Regular for fragments
        do {
          local $XML::LibXML::setTagCompression = 1;
          $serialized = $result->toString(1);
          } } }
    elsif ($$opts{format} eq 'dom') {
      $serialized = $result; } }
  else { $serialized = $result; }                              # Compressed case

  # 5.2 Finalize logging and return a response containing the document result, log and status
  print STDERR "Status:conversion:" . ($$runtime{status_code} || '0') . " \n";
  my $log = $self->flush_log;
  return { result => $serialized, log => $log, status => $$runtime{status}, 'status_code' => $$runtime{status_code} };
}

###########################################
####       Converter Management       #####
###########################################
sub get_converter {
  my ($self, $config) = @_;
  # TODO: Make this more flexible via an admin interface later
  my $key = $config->get('cache_key') || $config->get('profile') || 'custom';
  my $d = $DAEMON_DB{$key};
  if (!defined $d) {
    $d = LaTeXML->new($config->clone);
    $DAEMON_DB{$key} = $d; }
  return $d; }

###########################################
####       Helper routines            #####
###########################################
sub convert_post {
  my ($self, $dom) = @_;
  my $opts    = $$self{opts};
  my $runtime = $$self{runtime};
  my ($xslt, $parallel, $math_formats, $format, $verbosity, $defaultresources, $embed) =
    map { $$opts{$_} } qw(stylesheet parallelmath math_formats format verbosity defaultresources embed);
  $verbosity = $verbosity || 0;

  my %PostOPS = (verbosity => $verbosity,
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

  my $DOCUMENT = LaTeXML::Post::Document->new($dom, %PostOPS);
  my @procs = ();
  #TODO: Add support for the following:
  my $dbfile = $$opts{dbfile};
  if (defined $dbfile && !-f $dbfile) {
    if (my $dbdir = pathname_directory($dbfile)) {
      pathname_mkdir($dbdir); } }
  my $DB = LaTeXML::Util::ObjectDB->new(dbfile => $dbfile, %PostOPS);
  ### Advanced Processors:
  if ($$opts{split}) {
    require LaTeXML::Post::Split;
    push(@procs, LaTeXML::Post::Split->new(split_xpath => $$opts{splitpath}, splitnaming => $$opts{splitnaming},
        db => $DB, %PostOPS)); }
  my $scanner = ($$opts{scan} || $DB) && (LaTeXML::Post::Scan->new(db => $DB, %PostOPS));
  push(@procs, $scanner) if $$opts{scan};
  if (!($$opts{prescan})) {
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
          db => $DB, urlstyle => $$opts{urlstyle},
          extension => $$opts{extension},
          ($$opts{numbersections} ? (number_sections => 1) : ()),
          ($$opts{navtoc} ? (navigation_toc => $$opts{navtoc}) : ()),
          %PostOPS)); }
    if ($$opts{picimages}) {
      require LaTeXML::Post::PictureImages;
      push(@procs, LaTeXML::Post::PictureImages->new(%PostOPS));
    }
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
              (defined $$opts{plane1} ? (plane1 => $$opts{plane1}) : (plane1 => 1)),
              ($$opts{hackplane1} ? (hackplane1 => 1) : ()),
              %PostOPS)); }
        elsif ($fmt eq 'cmml') {
          require LaTeXML::Post::MathML::Content;
          push(@mprocs, LaTeXML::Post::MathML::Content->new(
              (defined $$opts{plane1} ? (plane1 => $$opts{plane1}) : (plane1 => 1)),
              ($$opts{hackplane1} ? (hackplane1 => 1) : ()),
              %PostOPS)); }
        elsif ($fmt eq 'om') {
          require LaTeXML::Post::OpenMath;
          push(@mprocs, LaTeXML::Post::OpenMath->new(
              (defined $$opts{plane1} ? (plane1 => $$opts{plane1}) : (plane1 => 1)),
              ($$opts{hackplane1} ? (hackplane1 => 1) : ()),
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
      my $parameters = { LATEXML_VERSION => "'$LaTeXML::VERSION'" };
      my @searchpaths = ('.', $DOCUMENT->getSearchPaths);
      # store these for the XSLT; XSLT Processor will copy resources where needed.
      foreach my $css (@{ $$opts{css} }) {
        push(@{ $$parameters{CSS} }, $css); }
      foreach my $js (@{ $$opts{javascript} }) {
        push(@{ $$parameters{JAVASCRIPT} }, $js); }
      if ($$opts{icon}) {
        $$parameters{ICON} = $$opts{icon}; }
      if (!defined $$opts{timestamp}) { $$opts{timestamp}       = localtime(); }
      if ($$opts{timestamp})          { $$parameters{TIMESTAMP} = "'" . $$opts{timestamp} . "'"; }
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
  my $latexmlpost = LaTeXML::Post->new(verbosity => $verbosity || 0);
  my $post_eval_return = eval {
    local $SIG{'ALRM'} = sub { die "Fatal:conversion:post-processing timed out.\n" };
    alarm($$opts{timeout});
    @postdocs = $latexmlpost->ProcessChain($DOCUMENT, @procs);
    alarm(0);
    1;
  };
  # 3.1 Bookkeeping if a post-processing Fatal error occurred
  local $@ = 'Fatal:conversion:unknown Post-processing failed! (Unknown Reason)'
    if ((!$post_eval_return) && (!$@));
  if ($@) {    #Fatal occured!
    $$runtime{status_code} = 3;
    $@ = 'Fatal:conversion:unknown ' . $@ unless $@ =~ /^\n?\S*Fatal:/s;
    print STDERR $@;
    undef @postdocs;    # Empty document for fatals, for sanity's sake
  }

  # Finalize by arranging any manifests and packaging the output.
  # If our format requires a manifest, create one
  if (($$opts{whatsout} =~ /^archive/) && ($format !~ /^x?html|xml/)) {
    require LaTeXML::Post::Manifest;
    my $manifest_maker = LaTeXML::Post::Manifest->new(db => $DB, format => $format, %PostOPS);
    $manifest_maker->process(@postdocs); }
  # Archives: when a relative --log is requested, write to sandbox prior packing
  if ($$opts{log} && ($$opts{whatsout} =~ /^archive/) && (!pathname_is_absolute($$opts{log}))) {
    ### We can't rely on the ->getDestinationDirectory method, as Fatal post-processing jobs have UNDEF @postdocs !!!
    ### my $destination_directory = $postdocs[0]->getDestinationDirectory();
    my $destination_directory = $PostOPS{destinationDirectory};
    my $log_file = pathname_absolute($$opts{log}, $destination_directory);
    if (pathname_is_contained($log_file, $destination_directory)) {
      print STDERR "\nPost-processing complete: " . $latexmlpost->getStatusMessage . "\n";
      print STDERR "processing finished " . localtime() . "\n" if $verbosity >= 0;
      my $archive_log_status_code = max($$runtime{status_code}, $latexmlpost->getStatusCode);
      print STDERR "Status:conversion:" . $archive_log_status_code . " \n";
      open my $log_fh, '>', $log_file;
      print $log_fh $self->flush_log;
      close $log_fh;
      $self->bind_log; }
    else { print STDERR "Error:I/O:log The target log file isn't contained in the destination directory!\n"; } }
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

  print STDERR "\nPost-processing complete: " . $latexmlpost->getStatusMessage . "\n";
  print STDERR "processing finished " . localtime() . "\n" if $verbosity >= 0;
  # Avoid writing the main file twice (non-archive documents):
  if ($$opts{destination} && $$opts{local} && ($$opts{whatsout} eq 'document')) {
    undef $postdoc; }
  return $postdoc; }

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
  require LaTeXML;
  my $latexml = LaTeXML::Core->new(preload => [@pre], searchpaths => [@{ $$opts{paths} }],
    graphicspaths   => ['.'],
    verbosity       => $$opts{verbosity}, strict => $$opts{strict},
    includeComments => $$opts{comments},
    inputencoding   => $$opts{inputencoding},
    includestyles   => $$opts{includestyles},
    documentid      => $$opts{documentid},
    nomathparse     => $$opts{nomathparse},                           # Backwards compatibility
    mathparse       => $$opts{mathparse});

  if (my @baddirs = grep { !-d $_ } @{ $$opts{paths} }) {
    warn "\n$LaTeXML::IDENTITY : these path directories do not exist: " . join(', ', @baddirs) . "\n"; }

  $latexml->withState(sub {
      my ($state) = @_;
      $latexml->initializeState('TeX.pool', @{ $$latexml{preload} || [] });
  });

  # TODO: Do again, need to do this in a GOOD way as well:
  $latexml->digestFile($_, noinitialize => 1) foreach (@str_pre);
  print STDERR "\n\n";    # Flush a pair of newlines to delimit the initalization
  return $latexml;
}

sub bind_log {
  my ($self) = @_;
  # HACK HACK HACK !!! Refactor with proplery scoped logging !!!
  $LaTeXML::LOG_STACK++;    # May the modern Perl community forgive me for this hack...
  return if $LaTeXML::LOG_STACK > 1;
  # TODO: Move away from global file handles, they will inevitably end up causing problems..

  if (!$LaTeXML::DEBUG) {    # Debug will use STDERR for logs
                             # Tie STDERR to log:
    my $log_handle;
    open($log_handle, ">>", \$$self{log}) or croak "Can't redirect STDERR to log! Dying...";
    *STDERR_SAVED = *STDERR;
    *STDERR       = *$log_handle;
    binmode(STDERR, ':encoding(UTF-8)');
    $LaTeXML::Common::Error::COLORIZED_LOGGING = -t STDERR;
    $$self{log_handle} = $log_handle;
  }
  return; }

sub flush_log {
  my ($self) = @_;
  # HACK HACK HACK !!! Refactor with proplery scoped logging !!!
  $LaTeXML::LOG_STACK--;    # May the modern Perl community forgive me for this hack...
  return '' if $LaTeXML::LOG_STACK > 0;

  # Close and restore STDERR to original condition.
  if (!$LaTeXML::DEBUG) {
    close $$self{log_handle};
    delete $$self{log_handle};
    *STDERR                                    = *STDERR_SAVED;
    $LaTeXML::Common::Error::COLORIZED_LOGGING = -t STDERR;
  }
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
         reseting STDERR to its usual stream.

=back

=head1 AUTHOR

Bruce Miller <bruce.miller@nist.gov>
Deyan Ginev <deyan.ginev@nist.gov>

=head1 COPYRIGHT

Public domain software, produced as part of work done by the
United States Government & not subject to copyright in the US.
You may consider this as released under the CC0 License.

=cut
