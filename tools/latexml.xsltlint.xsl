<?xml version="1.0" encoding="US-ASCII"?>
<xsl:stylesheet
    xmlns:str="http://exslt.org/strings"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    extension-element-prefixes="str"
    version="1.0">

  <!-- force non-ASCII characters to be output as entities -->
  <xsl:output
      encoding="US-ASCII"/>

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="/">
    <xsl:apply-templates select="@*|node()"/>
    <xsl:text>&#x0A;</xsl:text>
  </xsl:template>

  <!-- replace newlines with &#x0A; entities in xsl:text -->
  <xsl:template match="xsl:text[contains(.,'&#x0A;')]">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" mode="newline-to-entity"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template name="newline">
    <xsl:text disable-output-escaping="yes">&amp;#x0A;</xsl:text>
  </xsl:template>

  <xsl:template match="@*|node()" mode="newline-to-entity">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="text()[contains(.,'&#x0A;')]" mode="newline-to-entity">
    <xsl:if test="substring(.,1,1)='&#x0A;'">
      <xsl:call-template name="newline"/>
    </xsl:if>
    <xsl:apply-templates select="str:split(.,'&#x0A;')" mode="newline-to-entity"/>
    <xsl:if test="substring(.,string-length(),1)='&#x0A;'">
      <xsl:call-template name="newline"/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="text()[.='&#x0A;']" mode="newline-to-entity">
    <xsl:call-template name="newline"/>
  </xsl:template>

  <xsl:template match="token" mode="newline-to-entity">
    <xsl:value-of select="text()"/>
    <xsl:call-template name="newline"/>
  </xsl:template>

  <xsl:template match="token[last()]" mode="newline-to-entity">
    <xsl:value-of select="text()"/>
  </xsl:template>

  <!-- replace runs of consecutive spaces with the fake entity #xNL -->
  <!-- use concat(' ',' ') to ensure that this file can be linted -->
  <xsl:template match="@*[contains(.,concat(' ',' '))]">
    <xsl:attribute name="{name()}" namespace="{namespace-uri()}">
      <xsl:call-template name="spaces-to-newline">
        <xsl:with-param name="text" select="string()"/>
      </xsl:call-template>
    </xsl:attribute>
  </xsl:template>

  <xsl:variable name="sep" select="concat(' ',' ')"/>

  <xsl:template name="spaces-to-newline">
    <xsl:param name="text"/>
    <xsl:variable name="before" select="substring-before($text,$sep)"/>
    <xsl:choose>
      <xsl:when test="$text=''"/>
      <xsl:when test="starts-with($text,$sep)">
        <xsl:text>  </xsl:text>
        <xsl:call-template name="spaces-to-newline">
          <xsl:with-param name="text" select="substring($text,3)"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$before">
        <xsl:value-of select="$before"/>
        <xsl:text>&amp;</xsl:text>
        <xsl:text>#xNL;</xsl:text>
        <xsl:call-template name="spaces-to-newline">
          <xsl:with-param name="text" select="substring-after($text,$sep)"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$text"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
