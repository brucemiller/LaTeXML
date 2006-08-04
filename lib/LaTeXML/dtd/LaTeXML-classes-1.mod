<!--
 /=====================================================================\ 
 |  LaTeXML-classes-1.mod                                              |
 | Assemble entities for model classes for DTD for LaTeXML documents   |
 |=====================================================================|
 | Part of LaTeXML:                                                    |
 |  Public domain software, produced as part of work done by the       |
 |  United States Government & not subject to copyright in the US.     |
 |=====================================================================|
 | Bruce Miller <bruce.miller@nist.gov>                        #_#     |
 | http://dlmf.nist.gov/LaTeXML/                              (o o)    |
 \=========================================================ooo==U==ooo=/
-->

<!-- Combine classes from all modules -->

<!ENTITY % LaTeXML-math.Inline.class  "">
<!ENTITY % LaTeXML-xref.Inline.class  "">
<!ENTITY % LaTeXML-acro.Inline.class  "">
<!ENTITY % LaTeXML-extra.Inline.class "">
<!ENTITY % LaTeXML.Inline.class
	 "%LaTeXML-text.Inline.class;
	  %LaTeXML-math.Inline.class;
	  %LaTeXML-xref.Inline.class;
	  %LaTeXML-acro.Inline.class;
	  %LaTeXML-extra.Inline.class;
	  ">

<!ENTITY % LaTeXML-acro.Block.class  "">
<!ENTITY % LaTeXML-list.Block.class  "">
<!ENTITY % LaTeXML-extra.Block.class "">
<!ENTITY % LaTeXML.Block.class
	 "%LaTeXML-block.Block.class;
	  %LaTeXML-acro.Block.class;
	  %LaTeXML-list.Block.class;
	  %LaTeXML-extra.Block.class;
	  ">

<!ENTITY % LaTeXML-tabular.Misc.class  "">
<!ENTITY % LaTeXML-graphics.Misc.class "">
<!ENTITY % LaTeXML-picture.Misc.class  "">
<!ENTITY % LaTeXML-extra.Misc.class    "">
<!ENTITY % LaTeXML.Misc.class
	 "%LaTeXML-block.Misc.class;
	  %LaTeXML-tabular.Misc.class;
	  %LaTeXML-graphics.Misc.class;
	  %LaTeXML-picture.Misc.class;
	  %LaTeXML-extra.Misc.class;
	  ">

<!ENTITY % LaTeXML-float.Para.class "">
<!ENTITY % LaTeXML-theorem.Para.class "">
<!ENTITY % LaTeXML-extra.Para.class "">
<!ENTITY % LaTeXML.Para.class
	 "%LaTeXML-block.Para.class;
	  %LaTeXML-float.Para.class;
	  %LaTeXML-theorem.Para.class;
	  %LaTeXML-extra.Para.class;
	  ">

<!ENTITY % LaTeXML-index.Meta.class "">
<!ENTITY % LaTeXML-extra.Meta.class "">
<!ENTITY % LaTeXML.Meta.class
	 "%LaTeXML-text.Meta.class;
	  %LaTeXML-index.Meta.class;
	  %LaTeXML-extra.Meta.class;
	  ">

<!-- Form core mixed models -->
<!ENTITY % LaTeXML.Inline.mix
	 "%LaTeXML.Inline.class; %LaTeXML.Misc.class; %LaTeXML.Meta.class;">
<!ENTITY % LaTeXML.Block.mix
	 "%LaTeXML.Block.class; %LaTeXML.Misc.class; %LaTeXML.Meta.class;">
<!ENTITY % LaTeXML.Flow.mix
	 "%LaTeXML.Inline.class; | %LaTeXML.Block.class;
	  %LaTeXML.Misc.class; %LaTeXML.Meta.class;">
<!ENTITY % LaTeXML.Para.mix 
	 "%LaTeXML.Para.class; %LaTeXML.Meta.class;">

<!ENTITY % LaTeXML.Inline.model "(#PCDATA | %LaTeXML.Inline.mix;)*">
<!ENTITY % LaTeXML.Flow.model   "(#PCDATA | %LaTeXML.Flow.mix;)*">

<!ENTITY % LaTeXML-math.Math.class  "">
<!ENTITY % LaTeXML-extra.Math.class "">
<!ENTITY % LaTeXML.Math.class
	 "%LaTeXML-math.Math.class;
	  %LaTeXML-extra.Math.class;">

<!ENTITY % LaTeXML-math.XMath.class  "">
<!ENTITY % LaTeXML-extra.XMath.class "">
<!ENTITY % LaTeXML.XMath.class
	 "%LaTeXML-math.XMath.class;
	  %LaTeXML-extra.XMath.class;">

<!ENTITY % LaTeXML-math.XMath.attrib  "">
<!ENTITY % LaTeXML-extra.XMath.attrib "">
<!ENTITY % LaTeXML.XMath.attrib
	 "%LaTeXML-math.XMath.attrib;
	  %LaTeXML-extra.XMath.attrib;">

<!ENTITY % LaTeXML-float.Caption.class "">
<!ENTITY % LaTeXML-extra.Caption.class "">
<!ENTITY % LaTeXML.Caption.class
	 "%LaTeXML-float.Caption.class;
	  %LaTeXML-extra.Caption.class;">

<!ENTITY % LaTeXML-bib.Bibentry.class   "">
<!ENTITY % LaTeXML-extra.Bibentry.class "">
<!ENTITY % LaTeXML.Bibentry.class
	 "%LaTeXML-bib.Bibentry.class;
	  %LaTeXML-extra.Bibentry.class;">

<!ENTITY % LaTeXML-bib.Bibname.model "">
<!ENTITY % LaTeXML.Bibname.model 
	 "%LaTeXML-bib.Bibname.model;">

<!ENTITY % LaTeXML-picture.Picture.class "">
<!ENTITY % LaTeXML-extra.Picture.class   "">
<!ENTITY % LaTeXML.Picture.class
	 "%LaTeXML-picture.Picture.class;
	  %LaTeXML-extra.Picture.class;
	  | %LaTeXML.Inline.mix;">

<!ENTITY % LaTeXML-picture.Picture.attrib "">
<!ENTITY % LaTeXML-extra.Picture.attrib   "">
<!ENTITY % LaTeXML.Picture.attrib
	 "%LaTeXML-picture.Picture.attrib;
	  %LaTeXML-extra.Picture.attrib;">

<!ENTITY % LaTeXML-picture.PictureGroup.attrib "">
<!ENTITY % LaTeXML-extra.PictureGroup.attrib   "">
<!ENTITY % LaTeXML.PictureGroup.attrib
	 "%LaTeXML-picture.PictureGroup.attrib;
	  %LaTeXML-extra.PictureGroup.attrib;">

<!ENTITY % LaTeXML-structure.Person.class "">
<!ENTITY % LaTeXML-extra.Person.class     "">
<!ENTITY % LaTeXML.Person.class
	 "%LaTeXML-structure.Person.class;
	  %LaTeXML-extra.Person.class;">

<!ENTITY % LaTeXML-structure.SectionalFrontMatter.class "">
<!ENTITY % LaTeXML-extra.SectionalFrontMatter.class     "">
<!ENTITY % LaTeXML.SectionalFrontMatter.class
	 "%LaTeXML-structure.SectionalFrontMatter.class;
	  %LaTeXML-extra.SectionalFrontMatter.class;">

<!ENTITY % LaTeXML-structure.FrontMatter.class "">
<!ENTITY % LaTeXML-extra.FrontMatter.class     "">
<!ENTITY % LaTeXML.FrontMatter.class
	 "%LaTeXML-structure.SectionalFrontMatter.class;
	  %LaTeXML-extra.SectionalFrontMatter.class;
	  %LaTeXML-structure.FrontMatter.class;
	  %LaTeXML-extra.FrontMatter.class;">

<!ENTITY % LaTeXML-structure.BackMatter.class "">
<!ENTITY % LaTeXML-extra.BackMatter.class     "">
<!ENTITY % LaTeXML.BackMatter.class
	 "%LaTeXML-structure.BackMatter.class;
	  %LaTeXML-extra.BackMatter.class;">
