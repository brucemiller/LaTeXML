#======================================================================
# Unit tests for LaTeXML
#======================================================================
# I'd like to have a directory of unit tests, so it can be more easily
# grown, but this will be a start

use Test::More;
BEGIN { use_ok('LaTeXML'); }
BEGIN { use_ok('LaTeXML::Core::State'); }
BEGIN { use_ok('LaTeXML::Core::Stomach'); }
BEGIN { use_ok('LaTeXML::Common::Model'); }
BEGIN { use_ok('LaTeXML::Global'); }
BEGIN { use_ok('LaTeXML::Package'); }
BEGIN { use_ok('LaTeXML::Common::Error'); }

local $STATE = LaTeXML::Core::State->new(catcodes => 'standard',
    stomach => LaTeXML::Core::Stomach->new(),
    model   => LaTeXML::Common::Model->new());

SetVerbosity(-2);

my @supported_filename_patterns = qw(
  amsmath2.sty amsmath3-1.sty amsmathv2.sty amsmath_v2.sty amsmath2019.sty amsmath_v2019.sty amsmath_2019.sty
  amsmath_05_2019.sty amsmath052019.sty amsmath_052019.sty amsmath05_2019.sty amsmath05-2019.sty
  amsmath_arxiv.sty amsmath_arXiv.sty amsmath2_arxiv.sty amsmath2019_arxiv.sty 
  amsmath_05-2019_arxiv.sty amsmath_05-2019_arxiv.sty amsmath95.sty amsmath_conference.sty 
  amsmath2019_conference.sty amsmath_v2-workshop.sty
  amsmath-arxiv-v2021.sty amsmath62_rev.sty amsmath3248731.sty amsmath.mod.sty
  amsmath_modified_2016.sty preprint_amsmath.sty amsmath_preprint.sty 
);
# we could generalize further...
my @unsupported_filename_patterns = qw(
  amsmath3-r.sty amsmath3-id.sty my-amsmath_ed.sty 
);

# Make sure the main file is available first
my $regular_path = LaTeXML::Package::FindFile("amsmath.sty");
like($regular_path, qr/amsmath\.sty\.ltxml$/, "amsmath.sty did not resolve as amsmath.sty.ltxml");

# Now we can check the fallbacks
for my $name (@supported_filename_patterns) {
  my $path = LaTeXML::Package::FindFile_fallback($name,[]);
  like($path, qr/amsmath\.sty\.ltxml$/, "$name did not resolve as amsmath.sty.ltxml");
}
for my $name (@unsupported_filename_patterns) {
  my $path = LaTeXML::Package::FindFile_fallback($name,[]);
  is(!$path, 1, "$name should not have resolved as amsmath.sty.ltxml, got $path");
}
done_testing();