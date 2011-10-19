<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  Common utility functions for stylesheet; for inclusion             |
|=====================================================================|
| Part of LaTeXML:                                                    |
|  Public domain software, produced as part of work done by the       |
|  United States Government & not subject to copyright in the US.     |
|=====================================================================|
| Bruce Miller <bruce.miller@nist.gov>                        #_#     |
| http://dlmf.nist.gov/LaTeXML/                              (o o)    |
\=========================================================ooo==U==ooo=/
-->
<xsl:stylesheet
    version     = "1.0"
    xmlns:xsl   = "http://www.w3.org/1999/XSL/Transform"
    xmlns:ltx   = "http://dlmf.nist.gov/LaTeXML"
    xmlns:string= "http://exslt.org/strings"
    xmlns:func  = "http://exslt.org/functions"
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    extension-element-prefixes="func f"
    exclude-result-prefixes = "ltx f func string">

  <!-- Copy ID info from latexml elements to generated element.
       Prefer the page-unique fragid attribute,
       but if none, and there's an xml:id, use that instead -->
  <xsl:template name="add_id">
    <xsl:choose>
      <xsl:when test="@fragid">
	<xsl:attribute name="id"><xsl:value-of select="@fragid"/></xsl:attribute>
      </xsl:when>
      <xsl:when test="@xml:id">
	<xsl:attribute name="id"><xsl:value-of select="@xml:id"/></xsl:attribute>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

<!-- Usage:  <element class='{f:classes(.)}'>...
     Adds space separated classes based on the current element's 
     local-name and class attribute (if any). -->
<func:function name="f:classes">
  <xsl:param name="node"/>
  <xsl:choose>
    <xsl:when test="$node/@class">
      <func:result><xsl:value-of select="concat(local-name($node),' ',@class)"/></func:result>
    </xsl:when>
    <xsl:otherwise>
      <func:result><xsl:value-of select="local-name($node)"/></func:result>
    </xsl:otherwise>
  </xsl:choose>
</func:function>

<!-- Three-way if as function: f:if(test,iftrue,iffalse)
     Returns either the iftrue or iffalse branch, depending on test. -->
<func:function name="f:if">
  <xsl:param name="test"/>
  <xsl:param name="iftrue"/>
  <xsl:param name="iffalse"/>
  <xsl:choose>
    <xsl:when test="$test"><func:result><xsl:value-of select="$iftrue"/></func:result></xsl:when>
    <xsl:otherwise><func:result><xsl:value-of select="$iffalse"/></func:result></xsl:otherwise>
  </xsl:choose>
</func:function>

<!-- Computes html/css styling attributes according to attributes on the current element,
     including Positioning.attributes, font, color, ? 
     These should (ultimately) include from Positionable.attributes:
        width, height, depth,
        pad-width, pad-height,
        xoffset, yoffset,
        align, vattach
     And also
        font, color, size(?), framed
-->
<func:function name="f:catatt">
  <xsl:param name="conj"/>
  <xsl:param name="val1"/>
  <xsl:param name="val2"/>
  <xsl:choose>
    <xsl:when test="not($val1 = '') and not($val2 = '')">
      <func:result><xsl:value-of select="concat($val1,$conj,$val2)"/></func:result>
    </xsl:when>
    <xsl:when test="not($val1 = '')">
      <func:result><xsl:value-of select="$val1"/></func:result>
    </xsl:when>
    <xsl:otherwise>
      <func:result><xsl:value-of select="$val2"/></func:result>
    </xsl:otherwise>
  </xsl:choose>
</func:function>

<!-- Note that width & height (& padding versions)
     will be ignored in most cases... silly CSS.
     Not yet done:
       depth
       align, vattach
       size
       framed=circle
 -->
<func:function name="f:positioning">
  <xsl:param name="node"/>
  <func:result>
    <xsl:value-of
	select="concat(f:if($node/@float,     concat('float:',$node/@float,'; '),''),
		       f:if($node/@width,     concat('width:',$node/@width,'; '),''),
		       f:if($node/@height,    concat('height:',$node/@height,'; '),''),
		       f:if($node/@pad-width, concat('height:',$node/@pad-width,'; '),''),
		       f:if($node/@pad-height,concat('height:',$node/@pad-height,'; '),''),
		       f:if($node/@xoffset,   concat('position:relative; left:',$node/@xoffset,'; '),''),
		       f:if($node/@yoffset,   concat('position:relative; bottom:',$node/@yoffset,'; '),''),
		       f:if($node/@color,     concat('color:',$node/@color,'; '),''),
		       f:if($node/@framed = 'rectangle','border:1px solid black; ',''),
		       f:if($node/@framed = 'underline','text-decoration:underline; ',''),
		       f:if($node/@align,     concat('text-align:',$node/@align,';'),''),
		       f:if($node/@vattach,   concat('vertical-align:',$node/@vattach,';'),'')
		       )"/>
  </func:result>
</func:function>

</xsl:stylesheet>

