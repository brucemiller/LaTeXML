<!--
 /=====================================================================\ 
 |  LaTeXML-qname-1.mod                                                  |
 | Module collecting various qname modules for LaTeXML documents       |
 |=====================================================================|
 | Part of LaTeXML:                                                    |
 |  Public domain software, produced as part of work done by the       |
 |  United States Government & not subject to copyright in the US.     |
 |=====================================================================|
 | Bruce Miller <bruce.miller@nist.gov>                        #_#     |
 | http://dlmf.nist.gov/LaTeXML/                              (o o)    |
 \=========================================================ooo==U==ooo=/
-->

<!-- ==================== Text module ====================-->
<!ENTITY % LaTeXML-text-qname.mod   SYSTEM "LaTeXML-text-qname-1.mod">
%LaTeXML-text-qname.mod;

<!-- ==================== Block module ====================-->
<!ENTITY % LaTeXML-block-qname.mod   SYSTEM "LaTeXML-block-qname-1.mod">
%LaTeXML-block-qname.mod;

<!-- ==================== Math module ====================-->
<!ENTITY % LaTeXML-math.module  "INCLUDE" >
<![%LaTeXML-math.module;[
  <!ENTITY % LaTeXML-math-qname.mod   SYSTEM "LaTeXML-math-qname-1.mod">
  %LaTeXML-math-qname.mod;
]]>

<!-- ==================== Xref module ====================-->
<!ENTITY % LaTeXML-xref.module  "INCLUDE" >
<![%LaTeXML-xref.module;[
  <!ENTITY % LaTeXML-xref-qname.mod   SYSTEM "LaTeXML-xref-qname-1.mod">
  %LaTeXML-xref-qname.mod;
]]>

<!-- ==================== Index module ====================-->
<!ENTITY % LaTeXML-index.module  "INCLUDE" >
<![%LaTeXML-index.module;[
  <!ENTITY % LaTeXML-index-qname.mod   SYSTEM "LaTeXML-index-qname-1.mod">
  %LaTeXML-index-qname.mod;
]]>

<!-- ==================== Tabular module ====================-->
<!ENTITY % LaTeXML-tabular.module  "INCLUDE" >
<![%LaTeXML-tabular.module;[
  <!ENTITY % LaTeXML-tabular-qname.mod   SYSTEM "LaTeXML-tabular-qname-1.mod">
  %LaTeXML-tabular-qname.mod;
]]>

<!-- ==================== Graphics module ====================-->
<!ENTITY % LaTeXML-graphics.module  "INCLUDE" >
<![%LaTeXML-graphics.module;[
  <!ENTITY % LaTeXML-graphics-qname.mod   SYSTEM "LaTeXML-graphics-qname-1.mod">
  %LaTeXML-graphics-qname.mod;
]]>

<!-- ==================== Picture module ====================-->
<!ENTITY % LaTeXML-picture.module  "INCLUDE" >
<![%LaTeXML-picture.module;[
  <!ENTITY % LaTeXML-picture-qname.mod   SYSTEM "LaTeXML-picture-qname-1.mod">
  %LaTeXML-picture-qname.mod;
]]>

<!-- ==================== Float module ====================-->
<!ENTITY % LaTeXML-float.module  "INCLUDE" >
<![%LaTeXML-float.module;[
  <!ENTITY % LaTeXML-float-qname.mod   SYSTEM "LaTeXML-float-qname-1.mod">
  %LaTeXML-float-qname.mod;
]]>

<!-- ==================== Theorem module ====================-->
<!ENTITY % LaTeXML-theorem.module  "INCLUDE" >
<![%LaTeXML-theorem.module;[
  <!ENTITY % LaTeXML-theorem-qname.mod   SYSTEM "LaTeXML-theorem-qname-1.mod">
  %LaTeXML-theorem-qname.mod;
]]>

<!-- ==================== Acro module ====================-->
<!ENTITY % LaTeXML-acro.module  "INCLUDE" >
<![%LaTeXML-acro.module;[
  <!ENTITY % LaTeXML-acro-qname.mod   SYSTEM "LaTeXML-acro-qname-1.mod">
  %LaTeXML-acro-qname.mod;
]]>

<!-- ==================== List module ====================-->
<!ENTITY % LaTeXML-list.module  "INCLUDE" >
<![%LaTeXML-list.module;[
  <!ENTITY % LaTeXML-list-qname.mod   SYSTEM "LaTeXML-list-qname-1.mod">
  %LaTeXML-list-qname.mod;
]]>

<!-- ==================== Bib module ====================-->
<!ENTITY % LaTeXML-bib.module  "INCLUDE" >
<![%LaTeXML-bib.module;[
  <!ENTITY % LaTeXML-bib-qname.mod   SYSTEM "LaTeXML-bib-qname-1.mod">
  %LaTeXML-bib-qname.mod;
]]>

<!-- ==================== Structure module ====================-->
<!ENTITY % LaTeXML-structure.module  "INCLUDE" >
<![%LaTeXML-structure.module;[
  <!ENTITY % LaTeXML-structure-qname.mod   SYSTEM "LaTeXML-structure-qname-1.mod">
  %LaTeXML-structure-qname.mod;
]]>
