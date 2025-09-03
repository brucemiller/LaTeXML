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
    various_colors => { packages => ['algorithm.sty','colortbl.sty','listings.sty','tcolorbox.sty'],
      texlive_min => 2021 },
    si => {
      env=>'CI', # only runs in continuous integration
      packages => 'siunitx.sty', texlive_min => 2015 } });
