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
    xmlns:date  = "http://exslt.org/dates-and-times"
    xmlns:func  = "http://exslt.org/functions"
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    extension-element-prefixes="func f"
    exclude-result-prefixes = "ltx f func string">

  <xsl:param name="LATEXML_VERSION"></xsl:param>
  <xsl:param name="TIMESTAMP"></xsl:param>

  <xsl:template name="LaTeXML_identifier">
    <xsl:if test="$LATEXML_VERSION or $TIMESTAMP">
      <xsl:comment>Generated<!--
      --><xsl:if test="$TIMESTAMP"> on <xsl:value-of select="$TIMESTAMP"/></xsl:if><!--
      --> by LaTeXML<!--
      --><xsl:if test="$LATEXML_VERSION"> (version <xsl:value-of select="$LATEXML_VERSION"/>)</xsl:if><!--
      --> http://dlmf.nist.gov/LaTeXML/.</xsl:comment>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:if>
    <xsl:if test="//ltx:date[@role='creation' or @role='conversion'][1]">
      <xsl:comment>Document created on <xsl:value-of select='//ltx:date/node()'/>.</xsl:comment>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:if>
  </xsl:template>

  <!-- Copy ID info from latexml elements to generated element.-->
  <xsl:template name="add_id">
    <xsl:if test="@fragid">
      <xsl:attribute name="id"><xsl:value-of select="@fragid"/></xsl:attribute>
    </xsl:if>
  </xsl:template>

  <!-- Add the various common attributes to the html element being generated
       according to the attributes of the context node.
       This is an entry point for extensibilty.
       Would be nice if we could make provision for "extra classes",
       then we could incorporate the class attribute, as well.
       -->
  <xsl:template name="add_attributes">
    <xsl:param name="extra_classes" select="''"/>
    <xsl:param name="extra_style" select="''"/>
    <xsl:call-template name="add_classes">
      <xsl:with-param name="extra_classes" select="string($extra_classes)"/>
    </xsl:call-template>
    <xsl:call-template name="add_style">
      <xsl:with-param name="extra_style" select="string($extra_style)"/>
    </xsl:call-template>
    <xsl:call-template name="add_RDFa"/>
  </xsl:template>


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

  <!-- Add an attribute to the current node, but only if the value is non-empty -->
  <xsl:template name="add_attribute">
    <xsl:param name="name"/>
    <xsl:param name="value"/>
    <xsl:if test="not($value = '')">
      <xsl:attribute name="{$name}"><xsl:value-of select="$value"/></xsl:attribute>
    </xsl:if>
  </xsl:template>

  <!-- Add a class attribute value to the current html element
       according to the attributes of the context element:
       * the element name (this should be prefixed somehow!!!)
       * the class attribute
       * attributes in the Fontable.attribute set
       * content passed in via the parameter $extra_classes.
  -->


  <xsl:template name="add_classes">
    <xsl:param name="extra_classes" select="''"/>
    <xsl:call-template name="add_attribute">
      <xsl:with-param name="name" select="'class'"/>
      <xsl:with-param name="value" select="normalize-space(f:compute_classes(.,$extra_classes))"/>
    </xsl:call-template>
  </xsl:template>

<!--
  <func:function name="f:compute_classes">
    <xsl:param name="node"/>
    <xsl:param name="extra_classes"/>
    <func:result>
      <xsl:value-of select="concat(local-name($node),
			    f:if($node/@class,concat(' ',$node/@class),''),
			    f:if($node/@font,concat(' ',$node/@font),''),
			    f:if($node/@fontsize,concat(' ',$node/@fontsize),''),
			    f:if($extra_classes,concat(' ',$extra_classes),'')
			    )"/>
      </func:result>
  </func:function>
-->
  <func:function name="f:compute_classes">
    <xsl:param name="node"/>
    <xsl:param name="extra_classes"/>
    <func:result>
      <xsl:value-of select="local-name($node)"/>
      <xsl:if test="$node/@class">
	<xsl:value-of select="concat(' ',$node/@class)"/>
      </xsl:if>
      <xsl:if test="$node/@font">
	<xsl:value-of select="concat(' ',$node/@font)"/>
      </xsl:if>
      <xsl:if test="$node/@fontsize">
	<xsl:value-of select="concat(' ',$node/@fontsize)"/>
      </xsl:if>
      <xsl:if test="$extra_classes">
	<xsl:value-of select="concat(' ',$extra_classes)"/>
      </xsl:if>
    </func:result>
  </func:function>


  <!-- template add_style adds a css style attribute to the current html element
       according to attributes of the context node.
       * Positionable.attributes
       * Colorable.attributes

       Note that width & height (& padding versions)
       will be ignored in most cases... silly CSS.
       Note that some attributes clash because they're setting
       the same CSS property; there's no combining here (yet?).   
  -->


  <xsl:template name="add_style">
    <xsl:param name="extra_style" select="''"/>
    <xsl:call-template name="add_attribute">
      <xsl:with-param name="name" select="'style'"/>
      <xsl:with-param name="value" select="normalize-space(f:compute_styling(.,$extra_style))"/>
    </xsl:call-template>
  </xsl:template>

  <func:function name="f:compute_styling">
    <xsl:param name="node"/>
    <xsl:param name="extra_style"/>
    <func:result>
	<xsl:if test="$node/@float">
	  <xsl:value-of select="concat('float:',$node/@float,';')"/>
	</xsl:if>
	<xsl:if test="$node/@width">
	  <xsl:value-of select="concat('width:',$node/@width,';')"/>
	</xsl:if>
	<xsl:if test="$node/@height">
	  <xsl:value-of select="concat('height:',$node/@height,';')"/>
	</xsl:if>
	<xsl:if test="$node/@depth">
	  <xsl:value-of select="concat('vertical-align:',$node/@depth,';')"/>
	</xsl:if>
	<xsl:if test="$node/@pad-width">
	  <xsl:value-of select="concat('height:',$node/@pad-width,';')"/>
	</xsl:if>
	<xsl:if test="$node/@pad-height">
	  <xsl:value-of select="concat('height:',$node/@pad-height,';')"/>
	</xsl:if>
	<xsl:if test="$node/@xoffset">
	  <xsl:value-of select="concat('position:relative; left:',$node/@xoffset,';')"/>
	</xsl:if>
	<xsl:if test="$node/@yoffset">
	  <xsl:value-of select="concat('position:relative; bottom:',$node/@yoffset,';')"/>
	</xsl:if>
	<xsl:if test="$node/@color">
	  <xsl:value-of select="concat('color:',$node/@color,';')"/>
	</xsl:if>
	<xsl:if test="$node/@backgroundcolor">
	  <xsl:value-of select="concat('background-color:',$node/@backgroundcolor,';')"/>
	</xsl:if>
	<xsl:if test="$node/@opacity">
	  <xsl:value-of select="concat('opacity:',$node/@opacity,';')"/>
	</xsl:if>
	<xsl:if test="$node/@framed='rectangle'">
	  <xsl:value-of select="'border:1px solid black;'"/>
	</xsl:if>
	<xsl:if test="$node/@framed='underline'">
	  <xsl:value-of select="'text-decoration:underline;'"/>
	</xsl:if>
	<xsl:if test="$node/@align">
	  <xsl:value-of select="concat('text-align:',$node/@align,';')"/>
	</xsl:if>
	<xsl:if test="$node/@vattach">
	  <xsl:value-of select="concat('vertical-align:',$node/@vattach,';')"/>
	</xsl:if>
	<xsl:if test="$extra_style">
	  <xsl:value-of select="$extra_style"/>
	</xsl:if>
    </func:result>
  </func:function>

  <xsl:template name="add_RDFa">
    <xsl:if test="@vocab">
      <xsl:attribute name="vocab"><xsl:value-of select="@vocab"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@prefix">
      <xsl:attribute name="prefix"><xsl:value-of select="@prefix"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@about">
      <xsl:attribute name="about"><xsl:value-of select="@about"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@resource">
      <xsl:attribute name="resource"><xsl:value-of select="@resource"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@property">
      <xsl:attribute name="property"><xsl:value-of select="@property"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@rel">
      <xsl:attribute name="rel"><xsl:value-of select="@rel"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@rel">
      <xsl:attribute name="rel"><xsl:value-of select="@rel"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@rev">
      <xsl:attribute name="rev"><xsl:value-of select="@rev"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@typeof">
      <xsl:attribute name="typeof"><xsl:value-of select="@typeof"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@datatype">
      <xsl:attribute name="datatype"><xsl:value-of select="@datatype"/></xsl:attribute>
    </xsl:if>
    <xsl:if test="@content">
      <xsl:attribute name="content"><xsl:value-of select="@content"/></xsl:attribute>
    </xsl:if>
  </xsl:template>

  <func:function name="f:LaTeXML-icon">
    <func:result>data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAsAAAAOCAYAAAD5YeaVAAAAAXNSR0IArs4c6QAAAAZiS0dEAP8A/wD/oL2nkwAAAAlwSFlzAAALEwAACxMBAJqcGAAAAAd0SU1FB9wKExQZLWTEaOUAAAAddEVYdENvbW1lbnQAQ3JlYXRlZCB3aXRoIFRoZSBHSU1Q72QlbgAAAdpJREFUKM9tkL+L2nAARz9fPZNCKFapUn8kyI0e4iRHSR1Kb8ng0lJw6FYHFwv2LwhOpcWxTjeUunYqOmqd6hEoRDhtDWdA8ApRYsSUCDHNt5ul13vz4w0vWCgUnnEc975arX6ORqN3VqtVZbfbTQC4uEHANM3jSqXymFI6yWazP2KxWAXAL9zCUa1Wy2tXVxheKA9YNoR8Pt+aTqe4FVVVvz05O6MBhqUIBGk8Hn8HAOVy+T+XLJfLS4ZhTiRJgqIoVBRFIoric47jPnmeB1mW/9rr9ZpSSn3Lsmir1fJZlqWlUonKsvwWwD8ymc/nXwVBeLjf7xEKhdBut9Hr9WgmkyGEkJwsy5eHG5vN5g0AKIoCAEgkEkin0wQAfN9/cXPdheu6P33fBwB4ngcAcByHJpPJl+fn54mD3Gg0NrquXxeLRQAAwzAYj8cwTZPwPH9/sVg8PXweDAauqqr2cDjEer1GJBLBZDJBs9mE4zjwfZ85lAGg2+06hmGgXq+j3+/DsixYlgVN03a9Xu8jgCNCyIegIAgx13Vfd7vdu+FweG8YRkjXdWy329+dTgeSJD3ieZ7RNO0VAXAPwDEAO5VKndi2fWrb9jWl9Esul6PZbDY9Go1OZ7PZ9z/lyuD3OozU2wAAAABJRU5ErkJggg==</func:result></func:function>

</xsl:stylesheet>

