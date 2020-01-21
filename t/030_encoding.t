# -*- CPERL -*-
#**********************************************************************
# Test cases for LaTeXML
#**********************************************************************
use LaTeXML::Util::Test;

# These all depend on various input or font encoding files being present
# (they're read in by the LaTeXML binding)
latexml_tests("t/encoding",
	      requires=>{ansinew=>'ansinew.def',
			 applemac=>'applemac.def',
			 cp437  =>'cp437.def',
			 cp437de=>'cp437de.def',
			 cp850  =>'cp850.def',
			 cp852  =>'cp852.def',
			 cp858  =>'cp858.def',
			 cp865  =>'cp865.def',
			 cp1250 =>'cp1250.def',
			 cp1252 =>'cp1252.def',
			 decmulti=>'decmulti.def',
			 macce  =>'macce.def',
			 next   =>'next.def',
			 latin1 =>'latin1.def',
			 latin2 =>'latin2.def',
			 latin3 =>'latin3.def',
			 latin4 =>'latin4.def',
			 latin5 =>'latin5.def',
			 latin9 =>'latin9.def',
			 latin10 =>'latin10.def',
			 ot1   =>'ot1enc.def',
			 t1    =>'t1enc.def',
			 t2a   =>'t2aenc.def',
			 t2b   =>'t2benc.def',
			 t2c   =>'t2cenc.def',
			 ts1   =>'ts1enc.def',
			 ly1   =>'ly1enc.def',
			 });
