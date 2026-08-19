# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

latexml_tests("t/complex",
  requires => {
    cleveref_minimal => 'cleveref.sty',
    figure_dual_caption => {packages => 'graphicx.sty', texlive_min => 2021},
    figure_mixed_content => {
      packages => ['algorithm.sty','algorithmic.sty','graphicx.sty','ifthen.sty','keyval.sty'], 
      texlive_min => 2021},
    si => {
      env=>'CI', # only runs in continuous integration
      packages => 'siunitx.sty', texlive_min => 2022 },  # should be 2015
    si_preamble => {
      env=>'CI', # only runs in continuous integration
      packages => 'siunitx.sty', texlive_min => 2015 },
    siV2 => {
      env=>'CI', # only runs in continuous integration
      packages => 'siunitx.sty', texlive_min => 2015, texlive_max => 2020 },
    # siV3 is triggered if \fmtversion >= 2021,
    # lib/LaTeXML/Engine/latex_base.pool.ltxml sets \fmtversion to 2018/12/01
    # if `make formats` is called, blib/lib/LaTeXML/Engine/latex_dump.pool.ltxml
    # overrides it to the actual value
    # GitHub actions call `make formats` only for 2023 onward
    # this also means `make test CI=true` will fail without `make formats`
    siV3 => {
      env=>'CI', # only runs in continuous integration
      packages => 'siunitx.sty', texlive_min => 2023 } });
