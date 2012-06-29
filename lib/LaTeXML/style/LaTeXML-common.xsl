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
      <xsl:text>
      </xsl:text>
    </xsl:if>
    <xsl:if test="//ltx:date[@role='creation' or @role='conversion'][1]">
      <xsl:comment>Document created on <xsl:value-of select='//ltx:date/node()'/>.</xsl:comment>
      <xsl:text>
      </xsl:text>
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

<!--
  <xsl:template name="add_classes">
    <xsl:param name="extra_classes" select="''"/>
      <xsl:attribute name="class">
	<xsl:value-of
	    select="concat(local-name(.),
		           f:if(@class,concat(' ',@class),''),
			   f:if(@font,concat(' ',@font),''),
			   f:if(@fontsize,concat(' ',@fontsize),''),
			   f:if($extra_classes,concat(' ',$extra_classes),'')
			 )"/>
      </xsl:attribute>
  </xsl:template>
-->

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

<!--
  <xsl:template name="add_style">
    <xsl:param name="extra_style" select="''"/>
    <xsl:if test="@float or @width or @height or @pad-width or @pad-height or @xoffset or @yoffset
		  or @color or @backgroundcolor or @opacity or @framed or @align or @vattach
		  or @imagedepth or boolean($extra_style)">
      <xsl:attribute name="style">
	<xsl:if test="@float">
	  <xsl:value-of select="concat('float:',@float,';')"/>
	</xsl:if>
	<xsl:if test="@width">
	  <xsl:value-of select="concat('width:',@width,';')"/>
	</xsl:if>
	<xsl:if test="@height">
	  <xsl:value-of select="concat('height:',@height,';')"/>
	</xsl:if>
	<xsl:if test="@depth">
	  <xsl:value-of select="concat('vertical-align:',@depth,';')"/>
	</xsl:if>
	<xsl:if test="@pad-width">
	  <xsl:value-of select="concat('height:',@pad-width,';')"/>
	</xsl:if>
	<xsl:if test="@pad-height">
	  <xsl:value-of select="concat('height:',@pad-height,';')"/>
	</xsl:if>
	<xsl:if test="@xoffset">
	  <xsl:value-of select="concat('position:relative; left:',@xoffset,';')"/>
	</xsl:if>
	<xsl:if test="@yoffset">
	  <xsl:value-of select="concat('position:relative; bottom:',@yoffset,';')"/>
	</xsl:if>
	<xsl:if test="@color">
	  <xsl:value-of select="concat('color:',@color,';')"/>
	</xsl:if>
	<xsl:if test="@backgroundcolor">
	  <xsl:value-of select="concat('background-color:',@backgroundcolor,';')"/>
	</xsl:if>
	<xsl:if test="@opacity">
	  <xsl:value-of select="concat('opacity:',@opacity,';')"/>
	</xsl:if>
	<xsl:if test="@framed='rectangle'">
	  <xsl:value-of select="'border:1px solid black;'"/>
	</xsl:if>
	<xsl:if test="@framed='underline'">
	  <xsl:value-of select="'text-decoration:underline;'"/>
	</xsl:if>
	<xsl:if test="@align">
	  <xsl:value-of select="concat('text-align:',@align,';')"/>
	</xsl:if>
	<xsl:if test="@vattach">
	  <xsl:value-of select="concat('vertical-align:',@vattach,';')"/>
	</xsl:if>
	<xsl:if test="$extra_style">
	  <xsl:value-of select="$extra_style"/>
	</xsl:if>
      </xsl:attribute>
    </xsl:if>
  </xsl:template>
-->

  <func:function name="f:LaTeXML-icon">
    <func:result>data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAUCAYAAABSx2cSAAAAAXNSR0IArs4c6QAAAAZiS0dEAP8A/wD/oL2nkwAAAAlwSFlzAAALEwAACxMBAJqcGAAAAAd0SU1FB9wGEBQiL2E9pB4AAAAddEVYdENvbW1lbnQAQ3JlYXRlZCB3aXRoIFRoZSBHSU1Q72QlbgAAA21JREFUOMt9lM1LK2cUh39vJo6TGr2mTnX8uCY1antp1IrChRq8UEuhKHdzqUhLFoJLV4UguJCLBKr4F9guXBQXYkFaXNVtQRFvJIb4kY9xaogTIU41auLMmzdvF1YLF+tveeA5D4fDOYLH42lTFEU3TTNrWVYYAGw2WzOAPgB/AzDxP7F7PJ5vfD5fZSwWm+vu7n7ucDjM1dXVrwkhmWQy+T2eiHB1ddVRX1//ZmJi4oOTk5NXkiQNOauqPjo9Pf3ZMIx3T8H26enpPsMw8Pv6OsLvwuBlho5PPtUHBgZSiUQCT2Z/f38zEAhwh0vmzZ2fcdgreLXyXCPAMAAEg0G8ffv2UdbmdDrN0dFRDH3xEpl4DChR8CvD+eXQ0McAsLCwAACPNrATQlwjIyNQFAUXl5eIRqPcbrfXiaL4w9TU1K0sy78Gg8GLR+3ZbJZzzsuMMb69vc1DoVC5tbW1XFNTwwOBAJ+fn/9xZmam+jE70XU9ryhK9X3h/Pwcy8vLWFpa4k1NTaS/v78oCMI453zlfdhmGMZvAFAul3mxWERdXR3GxsYwPj5OWlpaeLFYdAD4FoDyvt2madpPpmmCUopkMnm3fEGAy+WCLMtEkiRwzr8yTbMRACYnJ/+Dj46OdnK53EG5XCa6rgMAGGO4vb2FIAgQRRGMsWfNzc2j0WjUIcsyZmdn7yShUKiUTqfrvV7vq3ujZVk4Pj7G2dkZMpkMd7vdRJblvsPDwz8FQdAWFxfvzGtra0TTtG3DMNDW1oZ/DwOCICAej0PTNOJ2u3mhUHDkcrmXvb29lQ97vrm54aVSKXNwcIBIJMJVVSUulwvFYhGqqqK9vR2NjY3IZDJgjH0oCILtYeZsNovLy8uznZ0daJpGfD4fKKWIxWIwDANerxdVVVWglIIxlrIsiz6YV1ZWIElSAQB6enrQ1dUFSZIwNzeHQqEAQggSiQTZ3d3VI5HIH3t7e1QUxQ5K6S8CAPj9/s9VVZ3Y2tpCbW0tCCEIh8P8+voaDQ0NZGNjA6lUqnJwcNAZDAbD8Xh8XNf17wgh5AWADUJIbUVFxa7f78/abLY3qqqSdDoNxlieMRYbHh7u7OzsrKOUlsLhsH1zc/Mvcv8UAMButzNRFBVK6WtKaQWAFIAtABder7cyn88/y+fzLyzL6uOcr/8DGmSkFuD9nqgAAAAASUVORK5CYII=</func:result></func:function>
</xsl:stylesheet>

