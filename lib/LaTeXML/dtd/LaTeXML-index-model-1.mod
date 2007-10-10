<!--
 /=====================================================================\ 
 |  LaTeXML-index-model-1.mod                                          |
 | Modular DTD model for LaTeXML generated documents                   |
 |=====================================================================|
 | Part of LaTeXML:                                                    |
 |  Public domain software, produced as part of work done by the       |
 |  United States Government & not subject to copyright in the US.     |
 |=====================================================================|
 | Bruce Miller <bruce.miller@nist.gov>                        #_#     |
 | http://dlmf.nist.gov/LaTeXML/                              (o o)    |
 \=========================================================ooo==U==ooo=/
-->

<!--% Metadata to record an indexing position. The content is 
    a sequence of <indexphrase>, each representing a level in
    a multilevel indexing entry. -->
<!ELEMENT %LaTeXML.indexmark.qname; (%LaTeXML.indexphrase.qname;)*>
<!--% 
   @see_also would be flattened form (@key) of another <indexmark>,
         used to crossreference.
-->
<!ATTLIST %LaTeXML.indexmark.qname; 
	  %LaTeXML.Common.attrib;
	  see_also CDATA #IMPLIED
	  style    CDATA #IMPLIED>

<!--% A phrase within an <indexmark> -->
<!ELEMENT %LaTeXML.indexphrase.qname; %LaTeXML.Inline.model;>
<!--% @key is a flattened form of the phrase.-->
<!ATTLIST %LaTeXML.indexphrase.qname;
	  %LaTeXML.Common.attrib;
          key CDATA #IMPLIED>

<!--% An index generated from the collection of <indexmark> in a document
    (or document collection). -->
<!ELEMENT %LaTeXML.indexlist.qname; (%LaTeXML.indexentry.qname;)*>
<!ATTLIST %LaTeXML.indexlist.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.ID.attrib;>

<!--% An entry in an <indexlist> consisting of a phrase, references to
     points in the document where the phrase was found, and possibly
     a nested <indexlist> represented index levels below this one.-->
<!ELEMENT %LaTeXML.indexentry.qname; 
	  ((%LaTeXML.indexphrase.qname;), (%LaTeXML.indexrefs.qname;)?,
	   (%LaTeXML.indexlist.qname;)?)>
<!ATTLIST %LaTeXML.indexentry.qname;
	  %LaTeXML.Common.attrib;
	  %LaTeXML.ID.attrib;>

<!--% A container for the references (<ref>) to where an <indexphrase> was
    encountered in the document. The model is Inline to allow
    arbitrary text, in addition to the expected <ref>'s.-->
<!ELEMENT %LaTeXML.indexrefs.qname; %LaTeXML.Inline.model;>
