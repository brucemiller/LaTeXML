#======================================================================
# Makefile Maker for LaTeXML
# Bruce.Miller@NIST.gov
#======================================================================
use ExtUtils::MakeMaker;

WriteMakefile(
	      NAME => 'LaTeXML',
	      VERSION_FROM => 'lib/LaTeXML.pm',
	      AUTHOR => 'Bruce Miller <bruce.miller@nist.gov>',
	      PREREQ_PM => { 'XML::LibXML'  => 1.57,
			     'XML::LibXSLT' => 1.57,
			     'Parse::RecDescent' => 0,
			     'Image::Magick'=> 0},
	      EXE_FILES => [ 'bin/latexml', 'bin/latexmlpost'],
	      );


# Hmm...
# Have test.t 
#  Should rename to latexml.t
# and add tests for latexmlpost!

# Need to do something about compiling the LaTeXML::Post::MathGrammer ???
