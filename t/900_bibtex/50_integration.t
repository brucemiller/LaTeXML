use LaTeXML::Post::BiBTeX::Common::Test;
use Test::More tests => 4;


integrationTest( "change.case\$ tests", "01_preamble", );

integrationTest( "format.name\$ tests", "02_formatName", );

integrationTest( "change.case\$ tests", "03_changeCase", );

integrationTest( "cite everything", "10_complicated", );
