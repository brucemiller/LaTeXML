<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0"
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		xmlns    ="http://relaxng.org/ns/structure/1.0"
		xmlns:rng="http://relaxng.org/ns/structure/1.0"
		exclude-result-prefixes = "rng">

  <xsl:output method="xml"/>

  <!-- Stylesheet to "dumb down" the rng schema so that trang can successfully
       approximate it as a DTD. -->


  <!-- Copy anything we're not otherwise handling -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- If an <attribute>'s pattern contains a <choice>,
       and one of the choices is <text/>,
       reduce the pattern to <text/> -->
  <xsl:template match="rng:attribute[rng:choice[rng:text]]">
    <attribute>
      <xsl:apply-templates select="rng:name"/>
      <text/>
    </attribute>
  </xsl:template>


  <!-- Convert various specific data types to <text/> -->
  <xsl:template match="rng:data[@type='boolean']
		       | rng:data[@type='anyURI']
		       | rng:data[@type='nonNegativeInteger']
		       ">
    <text/>
  </xsl:template>
</xsl:stylesheet>
