<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="http://relaxng.org/ns/structure/1.0" xmlns:rng="http://relaxng.org/ns/structure/1.0" xmlns:exsl="http://exslt.org/common" extension-element-prefixes="exsl" 
exclude-result-prefixes = "exsl rng">

<xsl:output method="xml"/>

<xsl:param name="out-name">simplified-</xsl:param>

<!-- 7.2 -->

<xsl:template match="/">
	<xsl:param name="out" select="1"/>
	<xsl:param name="stop-after" select="''"/>
	<xsl:comment>7.2</xsl:comment>
	<xsl:variable name="step">
		<xsl:apply-templates mode="step7.2"/>
	</xsl:variable>
	<xsl:if test="$out=1">
		<exsl:document href="{$out-name}7-2.rng" method="xml" indent="no">
			<xsl:copy-of select="$step"/>
		</exsl:document>
	</xsl:if>
	<xsl:choose>
		<xsl:when test="$stop-after = 'step7.2'">
			<xsl:copy-of select="$step"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="exsl:node-set($step)" mode="step7.3"> 
				<xsl:with-param name="out" select="$out"/>
				<xsl:with-param name="stop-after" select="$stop-after"/>
			</xsl:apply-templates>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="rng:*|text()|@*[namespace-uri()='']" mode="step7.2">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.2"/>
		<xsl:apply-templates mode="step7.2"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="*|@*" mode="step7.2"/>

<!-- 7.3 -->

<xsl:template match="/" mode="step7.3">
	<xsl:param name="out" select="1"/>
	<xsl:param name="stop-after" select="''"/>
	<xsl:comment>7.3</xsl:comment>
	<xsl:variable name="step">
		<xsl:apply-templates mode="step7.3"/>
	</xsl:variable>
	<xsl:if test="$out=1">
		<exsl:document href="{$out-name}7-3.rng" method="xml" indent="yes">
			<xsl:copy-of select="$step"/>
		</exsl:document>
	</xsl:if>
	<xsl:choose>
		<xsl:when test="$stop-after = 'step7.3'">
			<xsl:copy-of select="$step"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="exsl:node-set($step)" mode="step7.4">
				<xsl:with-param name="out" select="$out"/>
				<xsl:with-param name="stop-after" select="$stop-after"/>
			</xsl:apply-templates>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="*|text()|@*" mode="step7.3">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.3"/>
		<xsl:apply-templates mode="step7.3"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="text()[normalize-space(.)='' and not(parent::rng:param or parent::rng:value)]" mode="step7.3"/>

<xsl:template match="@name|@type|@combine" mode="step7.3">
	<xsl:attribute name="{name()}">
		<xsl:value-of select="normalize-space(.)"/>
	</xsl:attribute>
</xsl:template>

<xsl:template match="rng:name/text()" mode="step7.3">
	<xsl:value-of select="normalize-space(.)"/>
</xsl:template>

<!-- 7.4 -->

<xsl:template match="/" mode="step7.4">
	<xsl:param name="out" select="1"/>
	<xsl:param name="stop-after" select="''"/>
	<xsl:comment>7.4</xsl:comment>
	<xsl:variable name="step">
		<xsl:apply-templates mode="step7.4"/>
	</xsl:variable>
	<xsl:if test="$out=1">
		<exsl:document href="{$out-name}7-4.rng" method="xml" indent="yes">
			<xsl:copy-of select="$step"/>
		</exsl:document>
	</xsl:if>
	<xsl:choose>
		<xsl:when test="$stop-after = 'step7.4'">
			<xsl:copy-of select="$step"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="exsl:node-set($step)" mode="step7.5"> 
				<xsl:with-param name="out" select="$out"/>
				<xsl:with-param name="stop-after" select="$stop-after"/>
			</xsl:apply-templates>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="*|text()|@*" mode="step7.4">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.4"/>
		<xsl:apply-templates mode="step7.4"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="@datatypeLibrary" mode="step7.4"/>

<xsl:template match="rng:data|rng:value" mode="step7.4">
	<xsl:copy>
		<xsl:attribute name="datatypeLibrary">
			<xsl:value-of select="ancestor-or-self::*[@datatypeLibrary][1]/@datatypeLibrary"/>
		</xsl:attribute>
		<xsl:apply-templates select="@*" mode="step7.4"/>
		<xsl:apply-templates mode="step7.4"/>
	</xsl:copy>
</xsl:template>

<!-- 7.5 -->

<xsl:template match="/" mode="step7.5">
	<xsl:param name="out" select="1"/>
	<xsl:param name="stop-after" select="''"/>
	<xsl:comment>7.5</xsl:comment>
	<xsl:variable name="step">
		<xsl:apply-templates mode="step7.5"/>
	</xsl:variable>
	<xsl:if test="$out=1">
		<exsl:document href="{$out-name}7-5.rng" method="xml" indent="yes">
			<xsl:copy-of select="$step"/>
		</exsl:document>
	</xsl:if>
	<xsl:choose>
		<xsl:when test="$stop-after = 'step7.5'">
			<xsl:copy-of select="$step"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="exsl:node-set($step)" mode="step7.7"> 
				<xsl:with-param name="out" select="$out"/>
				<xsl:with-param name="stop-after" select="$stop-after"/>
			</xsl:apply-templates>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="*|text()|@*" mode="step7.5">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.5"/>
		<xsl:apply-templates mode="step7.5"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="rng:value[not(@type)]/@datatypeLibrary" mode="step7.5"/>

<xsl:template match="rng:value[not(@type)]" mode="step7.5">
	<value type="token" datatypeLibrary="">
		<xsl:apply-templates select="@*" mode="step7.5"/>
		<xsl:apply-templates mode="step7.5"/>
	</value>
</xsl:template>

<!-- 7.7 -->

<xsl:template match="/" mode="step7.7">
	<xsl:param name="out" select="1"/>
	<xsl:param name="stop-after" select="''"/>
	<xsl:comment>7.7</xsl:comment>
	<xsl:variable name="step">
		<xsl:apply-templates mode="step7.7"/>
	</xsl:variable>
	<xsl:if test="$out=1">
		<exsl:document href="{$out-name}7-7.rng" method="xml" indent="yes">
			<xsl:copy-of select="$step"/>
		</exsl:document>
	</xsl:if>
	<xsl:choose>
		<xsl:when test="$stop-after = 'step7.7'">
			<xsl:copy-of select="$step"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="exsl:node-set($step)" mode="step7.8"> 
				<xsl:with-param name="out" select="$out"/>
				<xsl:with-param name="stop-after" select="$stop-after"/>
			</xsl:apply-templates>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="*|text()|@*" mode="step7.7">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.7"/>
		<xsl:apply-templates mode="step7.7"/>
	</xsl:copy>
</xsl:template>


<xsl:template match="rng:externalRef" mode="step7.7">
	<xsl:variable name="ref-rtf">
		<xsl:apply-templates select="document(@href)">
			<xsl:with-param name="out" select="0"/>
				<xsl:with-param name="stop-after" select="'step7.7'"/>
		</xsl:apply-templates>
	</xsl:variable>
	<xsl:variable name="ref" select="exsl:node-set($ref-rtf)"/>
	<xsl:element name="{local-name($ref/*)}" namespace="http://relaxng.org/ns/structure/1.0">
		<xsl:if test="not($ref/*/@ns) and @ns">
			<xsl:attribute name="ns">
				<xsl:value-of select="@ns"/>
			</xsl:attribute>
		</xsl:if>
		<xsl:copy-of select="$ref/*/@*"/>
		<xsl:copy-of select="$ref/*/*|$ref/*/text()"/>
	</xsl:element>
</xsl:template>

<!-- 7.8 -->

<xsl:template match="/" mode="step7.8">
	<xsl:param name="out" select="1"/>
	<xsl:param name="stop-after" select="''"/>
	<xsl:comment>7.8</xsl:comment>
	<xsl:variable name="step">
		<xsl:apply-templates mode="step7.8"/>
	</xsl:variable>
	<xsl:if test="$out=1">
		<exsl:document href="{$out-name}7-8.rng" method="xml" indent="yes">
			<xsl:copy-of select="$step"/>
		</exsl:document>
	</xsl:if>
	<xsl:choose>
		<xsl:when test="$stop-after = 'step7.8'">
			<xsl:copy-of select="$step"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="exsl:node-set($step)" mode="step7.9"> 
				<xsl:with-param name="out" select="$out"/>
				<xsl:with-param name="stop-after" select="$stop-after"/>
			</xsl:apply-templates>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="*|text()|@*" mode="step7.8">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.8"/>
		<xsl:apply-templates mode="step7.8"/>
	</xsl:copy>
</xsl:template>


<xsl:template match="rng:include" mode="step7.8">
	<xsl:variable name="ref-rtf">
		<xsl:apply-templates select="document(@href)">
			<xsl:with-param name="out" select="0"/>
				<xsl:with-param name="stop-after" select="'step7.8'"/>
		</xsl:apply-templates>
	</xsl:variable>
	<xsl:variable name="ref" select="exsl:node-set($ref-rtf)"/>
	<div>
		<xsl:copy-of select="@*[name() != 'href']"/>
		<xsl:copy-of select="*"/>
		<xsl:copy-of select="$ref/rng:grammar/rng:start[not(current()/rng:start)]"/>
		<xsl:copy-of select="$ref/rng:grammar/rng:define[not(@name = current()/rng:define/@name)]"/>
	</div>
</xsl:template>

<!-- 7.9 -->

<xsl:template match="/" mode="step7.9">
	<xsl:param name="out" select="1"/>
	<xsl:param name="stop-after" select="''"/>
	<xsl:comment>7.9</xsl:comment>
	<xsl:variable name="step">
		<xsl:apply-templates mode="step7.9"/>
	</xsl:variable>
	<xsl:if test="$out=1">
		<exsl:document href="{$out-name}7-9.rng" method="xml" indent="yes">
			<xsl:copy-of select="$step"/>
		</exsl:document>
	</xsl:if>
	<xsl:choose>
		<xsl:when test="$stop-after = 'step7.9'">
			<xsl:copy-of select="$step"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="exsl:node-set($step)" mode="step7.10"> 
				<xsl:with-param name="out" select="$out"/>
				<xsl:with-param name="stop-after" select="$stop-after"/>
			</xsl:apply-templates>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="*|text()|@*" mode="step7.9">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.9"/>
		<xsl:apply-templates mode="step7.9"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="@name[parent::rng:element|parent::rng:attribute]" mode="step7.9"/>

<xsl:template match="rng:element[@name]|rng:attribute[@name]" mode="step7.9">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.9"/>
		<xsl:if test="self::rng:attribute and not(@ns)">
			<xsl:attribute name="ns"/>
		</xsl:if>
		<name>
			<xsl:value-of select="@name"/>
		</name>
		<xsl:apply-templates mode="step7.9"/>
	</xsl:copy>
</xsl:template>

<!-- 7.10 -->

<xsl:template match="/" mode="step7.10">
	<xsl:param name="out" select="1"/>
	<xsl:param name="stop-after" select="''"/>
	<xsl:comment>7.10</xsl:comment>
	<xsl:variable name="step">
		<xsl:apply-templates mode="step7.10"/>
	</xsl:variable>
	<xsl:if test="$out=1">
		<exsl:document href="{$out-name}7-10.rng" method="xml" indent="yes">
			<xsl:copy-of select="$step"/>
		</exsl:document>
	</xsl:if>
	<xsl:choose>
		<xsl:when test="$stop-after = 'step7.10'">
			<xsl:copy-of select="$step"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="exsl:node-set($step)" mode="step7.11"> 
				<xsl:with-param name="out" select="$out"/>
				<xsl:with-param name="stop-after" select="$stop-after"/>
			</xsl:apply-templates>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="*|text()|@*" mode="step7.10">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.10"/>
		<xsl:apply-templates mode="step7.10"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="@ns" mode="step7.10"/>

<xsl:template match="rng:name|rng:nsName|rng:value" mode="step7.10">
	<xsl:copy>
		<xsl:attribute name="ns">
			<xsl:value-of select="ancestor-or-self::*[@ns][1]/@ns"/>
		</xsl:attribute>
		<xsl:apply-templates select="@*" mode="step7.10"/>
		<xsl:apply-templates mode="step7.10"/>
	</xsl:copy>
</xsl:template>

<!-- 7.11 -->

<xsl:template match="/" mode="step7.11">
	<xsl:param name="out" select="1"/>
	<xsl:param name="stop-after" select="''"/>
	<xsl:comment>7.11</xsl:comment>
	<xsl:variable name="step">
		<xsl:apply-templates mode="step7.11"/>
	</xsl:variable>
	<xsl:if test="$out=1">
		<exsl:document href="{$out-name}7-11.rng" method="xml" indent="yes">
			<xsl:copy-of select="$step"/>
		</exsl:document>
	</xsl:if>
	<xsl:choose>
		<xsl:when test="$stop-after = 'step7.11'">
			<xsl:copy-of select="$step"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="exsl:node-set($step)" mode="step7.12"> 
				<xsl:with-param name="out" select="$out"/>
				<xsl:with-param name="stop-after" select="$stop-after"/>
			</xsl:apply-templates>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="*|text()|@*" mode="step7.11">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.11"/>
		<xsl:apply-templates mode="step7.11"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="rng:name[contains(., ':')]" mode="step7.11">
	<xsl:variable name="prefix" select="substring-before(., ':')"/>
	<name>
		<xsl:attribute name="ns">
			<xsl:for-each select="namespace::*">
				<xsl:if test="name()=$prefix">
					<xsl:value-of select="."/>
				</xsl:if>
			</xsl:for-each>
		</xsl:attribute>
		<xsl:value-of select="substring-after(., ':')"/>
	</name>
</xsl:template>

<!-- 7.12 -->

<xsl:template match="/" mode="step7.12">
	<xsl:param name="out" select="1"/>
	<xsl:param name="stop-after" select="''"/>
	<xsl:comment>7.12</xsl:comment>
	<xsl:variable name="step">
		<xsl:apply-templates mode="step7.12"/>
	</xsl:variable>
	<xsl:if test="$out=1">
		<exsl:document href="{$out-name}7-12.rng" method="xml" indent="yes">
			<xsl:copy-of select="$step"/>
		</exsl:document>
	</xsl:if>
	<xsl:choose>
		<xsl:when test="$stop-after = 'step7.12'">
			<xsl:copy-of select="$step"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="exsl:node-set($step)" mode="step7.13"> 
				<xsl:with-param name="out" select="$out"/>
				<xsl:with-param name="stop-after" select="$stop-after"/>
			</xsl:apply-templates>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="*|text()|@*" mode="step7.12">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.12"/>
		<xsl:apply-templates mode="step7.12"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="rng:div" mode="step7.12">
	<xsl:apply-templates mode="step7.12"/>
</xsl:template>

<!-- 7.13 -->

<xsl:template match="/" mode="step7.13">
	<xsl:param name="out" select="1"/>
	<xsl:param name="stop-after" select="''"/>
	<xsl:comment>7.13</xsl:comment>
	<xsl:variable name="step">
		<xsl:apply-templates mode="step7.13"/>
	</xsl:variable>
	<xsl:if test="$out=1">
		<exsl:document href="{$out-name}7-13.rng" method="xml" indent="yes">
			<xsl:copy-of select="$step"/>
		</exsl:document>
	</xsl:if>
	<xsl:choose>
		<xsl:when test="$stop-after = 'step7.13'">
			<xsl:copy-of select="$step"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="exsl:node-set($step)" mode="step7.14"> 
				<xsl:with-param name="out" select="$out"/>
				<xsl:with-param name="stop-after" select="$stop-after"/>
			</xsl:apply-templates>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="*|text()|@*" mode="step7.13">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.13"/>
		<xsl:apply-templates mode="step7.13"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="rng:define[count(*)>1]|rng:oneOrMore[count(*)>1]|rng:zeroOrMore[count(*)>1]|rng:optional[count(*)>1]|rng:list[count(*)>1]|rng:mixed[count(*)>1]" mode="step7.13">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.13"/>
		<xsl:call-template name="reduce7.13">
			<xsl:with-param name="node-name" select="'group'"/>
		</xsl:call-template>
	</xsl:copy>
</xsl:template>

<xsl:template match="rng:except[count(*)>1]" mode="step7.13">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.13"/>
		<xsl:call-template name="reduce7.13">
			<xsl:with-param name="node-name" select="'choice'"/>
		</xsl:call-template>
	</xsl:copy>
</xsl:template>

<xsl:template match="rng:attribute[count(*) =1]" mode="step7.13">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.13"/>
		<xsl:apply-templates select="*" mode="step7.13"/>
		<text/>
	</xsl:copy>
</xsl:template>

<xsl:template match="rng:element[count(*)>2]" mode="step7.13">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.13"/>
		<xsl:apply-templates select="*[1]" mode="step7.13"/>
		<xsl:call-template name="reduce7.13">
			<xsl:with-param name="left" select="*[4]"/>
			<xsl:with-param name="node-name" select="'group'"/>
			<xsl:with-param name="out">
				<group>
					<xsl:apply-templates select="*[2]" mode="step7.13"/>
					<xsl:apply-templates select="*[3]" mode="step7.13"/>
				</group>
			</xsl:with-param>
		</xsl:call-template>
	</xsl:copy>
</xsl:template>

<xsl:template match="rng:group[count(*)=1]|rng:choice[count(*)=1]|rng:interleave[count(*)=1]" mode="step7.13">
	<xsl:apply-templates select="*" mode="step7.13"/>
</xsl:template>

<xsl:template match="rng:group[count(*)>2]|rng:choice[count(*)>2]|rng:interleave[count(*)>2]" mode="step7.13" name="reduce7.13">
	<xsl:param name="left" select="*[3]"/>
	<xsl:param name="node-name" select="name()"/>
	<xsl:param name="out">
		<xsl:element name="{$node-name}">
			<xsl:apply-templates select="*[1]" mode="step7.13"/>
			<xsl:apply-templates select="*[2]" mode="step7.13"/>
		</xsl:element>
	</xsl:param>
	<xsl:choose>
		<xsl:when test="$left">
			<xsl:variable name="newOut">
				<xsl:element name="{$node-name}">
					<xsl:copy-of select="$out"/>
					<xsl:apply-templates select="$left" mode="step7.13"/>
				</xsl:element>
			</xsl:variable>
			<xsl:call-template name="reduce7.13">
				<xsl:with-param name="left" select="$left/following-sibling::*[1]"/>
				<xsl:with-param name="out" select="$newOut"/>
				<xsl:with-param name="node-name" select="$node-name"/>
			</xsl:call-template>
		</xsl:when>
		<xsl:otherwise>
			<xsl:copy-of select="$out"/>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<!-- 7.14 -->

<xsl:template match="/" mode="step7.14">
	<xsl:param name="out" select="1"/>
	<xsl:param name="stop-after" select="''"/>
	<xsl:comment>7.14</xsl:comment>
	<xsl:variable name="step">
		<xsl:apply-templates mode="step7.14"/>
	</xsl:variable>
	<xsl:if test="$out=1">
		<exsl:document href="{$out-name}7-14.rng" method="xml" indent="yes">
			<xsl:copy-of select="$step"/>
		</exsl:document>
	</xsl:if>
	<xsl:choose>
		<xsl:when test="$stop-after = 'step7.14'">
			<xsl:copy-of select="$step"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="exsl:node-set($step)" mode="step7.15"> 
				<xsl:with-param name="out" select="$out"/>
				<xsl:with-param name="stop-after" select="$stop-after"/>
			</xsl:apply-templates>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="*|text()|@*" mode="step7.14">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.14"/>
		<xsl:apply-templates mode="step7.14"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="rng:mixed" mode="step7.14">
	<interleave>
		<xsl:apply-templates mode="step7.14"/>
		<text/>
	</interleave>
</xsl:template>

<!-- 7.15 -->

<xsl:template match="/" mode="step7.15">
	<xsl:param name="out" select="1"/>
	<xsl:param name="stop-after" select="''"/>
	<xsl:comment>7.15</xsl:comment>
	<xsl:variable name="step">
		<xsl:apply-templates mode="step7.15"/>
	</xsl:variable>
	<xsl:if test="$out=1">
		<exsl:document href="{$out-name}7-15.rng" method="xml" indent="yes">
			<xsl:copy-of select="$step"/>
		</exsl:document>
	</xsl:if>
	<xsl:choose>
		<xsl:when test="$stop-after = 'step7.15'">
			<xsl:copy-of select="$step"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="exsl:node-set($step)" mode="step7.16"> 
				<xsl:with-param name="out" select="$out"/>
				<xsl:with-param name="stop-after" select="$stop-after"/>
			</xsl:apply-templates>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="*|text()|@*" mode="step7.15">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.15"/>
		<xsl:apply-templates mode="step7.15"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="rng:optional" mode="step7.15">
	<choice>
		<xsl:apply-templates mode="step7.15"/>
		<empty/>
	</choice>
</xsl:template>

<!-- 7.16 -->

<xsl:template match="/" mode="step7.16">
	<xsl:param name="out" select="1"/>
	<xsl:param name="stop-after" select="''"/>
	<xsl:comment>7.16</xsl:comment>
	<xsl:variable name="step">
		<xsl:apply-templates mode="step7.16"/>
	</xsl:variable>
	<xsl:if test="$out=1">
		<exsl:document href="{$out-name}7-16.rng" method="xml" indent="yes">
			<xsl:copy-of select="$step"/>
		</exsl:document>
	</xsl:if>
	<xsl:choose>
		<xsl:when test="$stop-after = 'step7.16'">
			<xsl:copy-of select="$step"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="exsl:node-set($step)" mode="step7.18"> 
				<xsl:with-param name="out" select="$out"/>
				<xsl:with-param name="stop-after" select="$stop-after"/>
			</xsl:apply-templates>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="*|text()|@*" mode="step7.16">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.16"/>
		<xsl:apply-templates mode="step7.16"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="rng:zeroOrMore" mode="step7.16">
	<choice>
		<oneOrMore>
			<xsl:apply-templates mode="step7.16"/>
		</oneOrMore>
		<empty/>
	</choice>
</xsl:template>

<!-- 7.18 -->

<xsl:template match="/" mode="step7.18">
	<xsl:param name="out" select="1"/>
	<xsl:param name="stop-after" select="''"/>
	<xsl:comment>7.18</xsl:comment>
	<xsl:variable name="step">
		<xsl:apply-templates mode="step7.18"/>
	</xsl:variable>
	<xsl:if test="$out=1">
		<exsl:document href="{$out-name}7-18.rng" method="xml" indent="yes">
			<xsl:copy-of select="$step"/>
		</exsl:document>
	</xsl:if>
	<xsl:choose>
		<xsl:when test="$stop-after = 'step7.18'">
			<xsl:copy-of select="$step"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="exsl:node-set($step)" mode="step7.19"> 
				<xsl:with-param name="out" select="$out"/>
				<xsl:with-param name="stop-after" select="$stop-after"/>
			</xsl:apply-templates>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="*|text()|@*" mode="step7.18">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.18"/>
		<xsl:apply-templates mode="step7.18"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="@combine" mode="step7.18"/>
<xsl:template match="rng:start[preceding-sibling::rng:start]|rng:define[@name=preceding-sibling::rng:define/@name]" mode="step7.18"/>

<xsl:template match="rng:start[not(preceding-sibling::rng:start) and following-sibling::rng:start]" mode="step7.18">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.18"/>
		<xsl:element name="{parent::*/rng:start/@combine}">
			<xsl:call-template name="start7.18"/>
		</xsl:element>
	</xsl:copy>
</xsl:template>

<xsl:template name="start7.18">
	<xsl:param name="left" select="following-sibling::rng:start[2]"/>
	<xsl:param name="node-name" select="parent::*/rng:start/@combine"/>
	<xsl:param name="out">
		<xsl:element name="{$node-name}">
			<xsl:apply-templates select="*" mode="step7.18"/>
			<xsl:apply-templates select="following-sibling::rng:start[1]/*" mode="step7.18"/>
		</xsl:element>
	</xsl:param>
	<xsl:choose>
		<xsl:when test="$left/*">
			<xsl:variable name="newOut">
				<xsl:element name="{$node-name}">
					<xsl:copy-of select="$out"/>
					<xsl:apply-templates select="$left/*" mode="step7.18"/>
				</xsl:element>
			</xsl:variable>
			<xsl:call-template name="start7.18">
				<xsl:with-param name="left" select="$left/following-sibling::rng:start[1]"/>
				<xsl:with-param name="node-name" select="$node-name"/>
				<xsl:with-param name="out" select="$newOut"/>
			</xsl:call-template>
		</xsl:when>
		<xsl:otherwise>
			<xsl:copy-of select="$out"/>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="rng:define[not(@name=preceding-sibling::rng:define/@name) and @name=following-sibling::rng:define/@name]" mode="step7.18">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.18"/>
		<xsl:call-template name="define7.18"/>
	</xsl:copy>
</xsl:template>

<xsl:template name="define7.18">
	<xsl:param name="left" select="following-sibling::rng:define[@name=current()/@name][2]"/>
	<xsl:param name="node-name" select="parent::*/rng:define[@name=current()/@name]/@combine"/>
	<xsl:param name="out">
		<xsl:element name="{$node-name}">
			<xsl:apply-templates select="*" mode="step7.18"/>
			<xsl:apply-templates select="following-sibling::rng:define[@name=current()/@name][1]/*" mode="step7.18"/>
		</xsl:element>
	</xsl:param>
	<xsl:choose>
		<xsl:when test="$left/*">
			<xsl:variable name="newOut">
				<xsl:element name="{$node-name}">
					<xsl:copy-of select="$out"/>
					<xsl:apply-templates select="$left/*" mode="step7.18"/>
				</xsl:element>
			</xsl:variable>
			<xsl:call-template name="define7.18">
				<xsl:with-param name="left" select="$left/following-sibling::rng:define[@name=current()/@name][1]"/>
				<xsl:with-param name="node-name" select="$node-name"/>
				<xsl:with-param name="out" select="$newOut"/>
			</xsl:call-template>
		</xsl:when>
		<xsl:otherwise>
			<xsl:copy-of select="$out"/>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<!-- 7.19 -->

<xsl:template match="/" mode="step7.19">
	<xsl:param name="out" select="1"/>
	<xsl:param name="stop-after" select="''"/>
	<xsl:comment>7.19</xsl:comment>
	<xsl:variable name="step">
		<xsl:apply-templates mode="step7.19"/>
	</xsl:variable>
	<xsl:if test="$out=1">
		<exsl:document href="{$out-name}7-19.rng" method="xml" indent="yes">
			<xsl:copy-of select="$step"/>
		</exsl:document>
	</xsl:if>
	<xsl:choose>
		<xsl:when test="$stop-after = 'step7.19'">
			<xsl:copy-of select="$step"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="exsl:node-set($step)" mode="step7.20"> 
				<xsl:with-param name="out" select="$out"/>
				<xsl:with-param name="stop-after" select="$stop-after"/>
			</xsl:apply-templates>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="*|text()|@*" mode="step7.19">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.19"/>
		<xsl:apply-templates mode="step7.19"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="/rng:grammar" mode="step7.19">
	<grammar>
		<xsl:apply-templates mode="step7.19"/>
		<xsl:apply-templates select="//rng:define" mode="step7.19-define"/>
	</grammar>
</xsl:template>

<xsl:template match="/*" mode="step7.19">
	<grammar>
		<start>
			<xsl:copy>
				<xsl:apply-templates select="@*" mode="step7.19"/>
				<xsl:apply-templates mode="step7.19"/>
			</xsl:copy>
		</start>
	</grammar>
</xsl:template>

<xsl:template match="rng:define|rng:define/@name|rng:ref/@name" mode="step7.19"/>

<xsl:template match="rng:define" mode="step7.19-define">
	<xsl:copy>
		<xsl:attribute name="name">
			<xsl:value-of select="concat(@name, '-', generate-id())"/>
		</xsl:attribute>
		<xsl:apply-templates select="@*" mode="step7.19"/>
		<xsl:apply-templates mode="step7.19"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="rng:grammar" mode="step7.19">
	<xsl:apply-templates select="rng:start/*" mode="step7.19"/>
</xsl:template>

<xsl:template match="rng:ref" mode="step7.19">
	<xsl:copy>
		<xsl:attribute name="name">
			<xsl:value-of select="concat(@name, '-', generate-id(ancestor::rng:grammar[1]/rng:define[@name=current()/@name]))"/>
		</xsl:attribute>
		<xsl:apply-templates select="@*" mode="step7.19"/>
		<xsl:apply-templates mode="step7.19"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="rng:parentRef" mode="step7.19">
	<ref>
		<xsl:attribute name="name">
			<xsl:value-of select="concat(@name, '-', generate-id(ancestor::rng:grammar[2]/rng:define[@name=current()/@name]))"/>
		</xsl:attribute>
		<xsl:apply-templates select="@*" mode="step7.19"/>
		<xsl:apply-templates mode="step7.19"/>
	</ref>
</xsl:template>

<!-- 7.20 -->

<xsl:template match="/" mode="step7.20">
	<xsl:param name="out" select="1"/>
	<xsl:param name="stop-after" select="''"/>
	<xsl:comment>7.20</xsl:comment>
	<xsl:variable name="step">
		<xsl:apply-templates mode="step7.20"/>
	</xsl:variable>
	<xsl:if test="$out=1">
		<exsl:document href="{$out-name}7-20.rng" method="xml" indent="yes">
			<xsl:copy-of select="$step"/>
		</exsl:document>
	</xsl:if>
	<xsl:choose>
		<xsl:when test="$stop-after = 'step7.20'">
			<xsl:copy-of select="$step"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="exsl:node-set($step)" mode="step7.22"> 
				<xsl:with-param name="out" select="$out"/>
				<xsl:with-param name="stop-after" select="$stop-after"/>
			</xsl:apply-templates>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="*|text()|@*" mode="step7.20">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.20"/>
		<xsl:apply-templates mode="step7.20"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="/rng:grammar" mode="step7.20">
	<xsl:copy>
		<xsl:apply-templates select="@*" mode="step7.20"/>
		<xsl:apply-templates mode="step7.20"/>
		<xsl:apply-templates select="//rng:element[not(parent::rng:define)]" mode="step7.20-define"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="rng:element" mode="step7.20-define">
	<define name="__{rng:name}-elt-{generate-id()}">
		<xsl:copy>
			<xsl:apply-templates select="@*" mode="step7.20"/>
			<xsl:apply-templates mode="step7.20"/>
		</xsl:copy>
	</define>
</xsl:template>

<xsl:template match="rng:element[not(parent::rng:define)]" mode="step7.20">
	<ref name="__{rng:name}-elt-{generate-id()}"/>
</xsl:template>

<xsl:template match="rng:define[not(rng:element)]" mode="step7.20"/>

<xsl:template match="rng:ref[@name=/*/rng:define[not(rng:element)]/@name]" mode="step7.20">
	<xsl:apply-templates select="/*/rng:define[@name=current()/@name]/*" mode="step7.20"/>
</xsl:template>

<!-- 7.22 -->

<xsl:template match="/" mode="step7.22">
	<xsl:param name="out" select="1"/>
	<xsl:param name="stop-after" select="''"/>
	<xsl:comment>7.22</xsl:comment>
	<xsl:variable name="step">
		<xsl:apply-templates mode="step7.22"/>
	</xsl:variable>
	<xsl:if test="$out=1">
		<exsl:document href="{$out-name}7-22.rng" method="xml" indent="yes">
			<xsl:copy-of select="$step"/>
		</exsl:document>
	</xsl:if>
	<xsl:choose>
		<xsl:when test="$stop-after = 'step7.22'">
			<xsl:copy-of select="$step"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:apply-templates select="exsl:node-set($step)" mode="step7.23"> 
				<xsl:with-param name="out" select="$out"/>
				<xsl:with-param name="stop-after" select="$stop-after"/>
			</xsl:apply-templates>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="*|text()|@*" mode="step7.22">
	<xsl:param name="updated" select="0"/>
	<xsl:copy>
		<xsl:if test="$updated != 0">
			<xsl:attribute name="updated"><xsl:value-of select="$updated"/></xsl:attribute>
		</xsl:if>
		<xsl:apply-templates select="@*" mode="step7.22"/>
		<xsl:apply-templates mode="step7.22"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="@updated" mode="step7.22"/>

<xsl:template match="/rng:grammar" mode="step7.22">
	<xsl:variable name="thisIteration-rtf">
		<xsl:copy>
			<xsl:apply-templates select="@*" mode="step7.22"/>
			<xsl:apply-templates mode="step7.22"/>
		</xsl:copy>
	</xsl:variable>
	<xsl:variable name="thisIteration" select="exsl:node-set($thisIteration-rtf)"/>
	<xsl:choose>
		<xsl:when test="$thisIteration//@updated">
			<xsl:apply-templates select="$thisIteration/rng:grammar" mode="step7.22"/>
		</xsl:when>
		<xsl:otherwise>
			<xsl:copy-of select="$thisIteration-rtf"/>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="rng:choice[*[1][not(self::rng:empty)] and *[2][self::rng:empty]]" mode="step7.22">
	<xsl:copy>
		<xsl:attribute name="updated">1</xsl:attribute>
		<xsl:apply-templates select="*[2]" mode="step7.22" />
		<xsl:apply-templates select="*[1]" mode="step7.22" />
	</xsl:copy>
</xsl:template>

<xsl:template match="rng:group[count(rng:empty)=1]|rng:interleave[count(rng:empty)=1]" mode="step7.22">
	<xsl:apply-templates select="*[not(self::rng:empty)]" mode="step7.22">
		<xsl:with-param name="updated" select="1"/>
	</xsl:apply-templates>
</xsl:template>

<xsl:template match="rng:group[count(rng:empty)=2]|rng:interleave[count(rng:empty)=2]|rng:choice[count(rng:empty)=2]|rng:oneOrMore[rng:empty]" mode="step7.22">
	<rng:empty updated="1"/>
</xsl:template>

</xsl:stylesheet>
