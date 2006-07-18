<!--
 /=====================================================================\ 
 |  LaTeXML-model-1.mod                                                |
 | Collect various model modules for DTD for LaTeXML documents         |
 |=====================================================================|
 | Part of LaTeXML:                                                    |
 |  Public domain software, produced as part of work done by the       |
 |  United States Government & not subject to copyright in the US.     |
 |=====================================================================|
 | Bruce Miller <bruce.miller@nist.gov>                        #_#     |
 | http://dlmf.nist.gov/LaTeXML/                              (o o)    |
 \=========================================================ooo==U==ooo=/
-->

<!-- Always include text & block module's models -->

<!ENTITY % LaTeXML-text-model.mod   SYSTEM "LaTeXML-text-model-1.mod">
%LaTeXML-text-model.mod;
<!ENTITY % LaTeXML-block-model.mod   SYSTEM "LaTeXML-block-model-1.mod">
%LaTeXML-block-model.mod;

<!-- Optionally include other module's models -->

<![%LaTeXML-math.module;[
  <!ENTITY % LaTeXML-math-model.mod   SYSTEM "LaTeXML-math-model-1.mod">
  %LaTeXML-math-model.mod;
]]>

<![%LaTeXML-xref.module;[
  <!ENTITY % LaTeXML-xref-model.mod   SYSTEM "LaTeXML-xref-model-1.mod">
  %LaTeXML-xref-model.mod;
]]>

<![%LaTeXML-index.module;[
  <!ENTITY % LaTeXML-index-model.mod   SYSTEM "LaTeXML-index-model-1.mod">
  %LaTeXML-index-model.mod;
]]>

<![%LaTeXML-tabular.module;[
  <!ENTITY % LaTeXML-tabular-model.mod   SYSTEM "LaTeXML-tabular-model-1.mod">
  %LaTeXML-tabular-model.mod;
]]>

<![%LaTeXML-graphics.module;[
  <!ENTITY % LaTeXML-graphics-model.mod   SYSTEM "LaTeXML-graphics-model-1.mod">
  %LaTeXML-graphics-model.mod;
]]>

<![%LaTeXML-picture.module;[
  <!ENTITY % LaTeXML-picture-model.mod   SYSTEM "LaTeXML-picture-model-1.mod">
  %LaTeXML-picture-model.mod;
]]>


<![%LaTeXML-float.module;[
  <!ENTITY % LaTeXML-float-model.mod   SYSTEM "LaTeXML-float-model-1.mod">
  %LaTeXML-float-model.mod;
]]>

<![%LaTeXML-acro.module;[
  <!ENTITY % LaTeXML-acro-model.mod   SYSTEM "LaTeXML-acro-model-1.mod">
  %LaTeXML-acro-model.mod;
]]>

<![%LaTeXML-list.module;[
  <!ENTITY % LaTeXML-list-model.mod   SYSTEM "LaTeXML-list-model-1.mod">
  %LaTeXML-list-model.mod;
]]>

<![%LaTeXML-bib.module;[
  <!ENTITY % LaTeXML-bib-model.mod   SYSTEM "LaTeXML-bib-model-1.mod">
  %LaTeXML-bib-model.mod;
]]>

<![%LaTeXML-structure.module;[
  <!ENTITY % LaTeXML-structure-model.mod   SYSTEM "LaTeXML-structure-model-1.mod">
  %LaTeXML-structure-model.mod;
]]>
