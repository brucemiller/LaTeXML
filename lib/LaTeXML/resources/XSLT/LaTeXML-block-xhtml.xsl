<?xml version="1.0" encoding="utf-8"?>
<!--
/=====================================================================\ 
|  LaTeXML-block-xhtml.xsl                                            |
|  Converting various block-level elements to xhtml                   |
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
    xmlns:func  = "http://exslt.org/functions"
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    extension-element-prefixes="func f"
    exclude-result-prefixes = "ltx func f">

  <!-- ======================================================================
       Various Block-level elements:
       ltx:p, ltx:equation, ltx:equationgroup, ltx:quote, ltx:block,
       ltx:listingblock, ltx:itemize, ltx:enumerate, ltx:description
       ====================================================================== -->

  <xsl:template match="ltx:p">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="p" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:quote">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="blockquote" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:block">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:listingblock">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
      </xsl:call-template>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:listingblock" mode="classes">
    <xsl:apply-imports/>
    <xsl:text> ltx_listing</xsl:text>
  </xsl:template>

  <!-- ======================================================================
       Equation structures
       ====================================================================== -->

  <!-- Equation formatting parameters.
       [how should these be controlled? cmdline? processing-instructions?]

       The alignment capability blurs the line between the HTML structure & CSS.
       Some things are getting hardcoded that really should be in CSS.
  -->

  <!-- Should alignments like eqnarray, align, be respected, or more semantically presented?-->
  <xsl:param name="aligned_equations" select="true()"/>

  <xsl:param name="classPI">
    <xsl:value-of select="//processing-instruction()[local-name()='latexml'][contains(.,'class')]"/>
  </xsl:param>
  <!-- Equation numbers on left, or default right? -->
  <xsl:param name="eqnopos"
	     select="f:if(//processing-instruction('latexml')[contains(substring-after(.,'options'),'leqno')],'left','right')"/>

  <!-- Displayed equations centered, or indented on left? -->
  <xsl:param name="eqpos"
	     select="f:if(//processing-instruction('latexml')[contains(substring-after(.,'options'),'fleqn')],'left','center')"/>


  <!--
  <xsl:template match="ltx:equation/@refnum | ltx:equationgroup/@refnum">
    <xsl:text>(</xsl:text>
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:attribute name="class">ltx_refnum</xsl:attribute>
      <xsl:value-of select="."/>
    </xsl:element>
    <xsl:text>)</xsl:text>
  </xsl:template>
  -->
  <!-- Make @refnum simulate a <ltx:tag>...</ltx:tag>-->
  <xsl:template match="ltx:equation/@refnum | ltx:equationgroup/@refnum">
<!--    <xsl:text>(</xsl:text>-->
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:attribute name="class">ltx_tag ltx_tag_<xsl:value-of select="local-name(..)"/></xsl:attribute>
      <xsl:choose>
	<xsl:when test="../@frefnum">
	  <xsl:value-of select="../@frefnum"/>	  
	</xsl:when>
	<xsl:otherwise>
	  <xsl:value-of select="."/>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:element>
<!--    <xsl:text>)</xsl:text>-->
  </xsl:template>

  <!-- ======================================================================
       Basic templates, dispatching on aligned or unaligned forms-->

  <xsl:template match="ltx:equationgroup">
    <xsl:choose>
      <xsl:when test="$aligned_equations">
	<xsl:apply-templates select="." mode="aligned"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:apply-templates select="." mode="unaligned"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:equation">
    <xsl:choose>
      <xsl:when test="$aligned_equations">
	<xsl:apply-templates select="." mode="aligned"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:apply-templates select="." mode="unaligned"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ======================================================================
       Unaligned templates -->

  <xsl:template match="*" mode="unaligned-begin"/>
  <xsl:template match="*" mode="unaligned-end"/>

  <xsl:template match="ltx:equationgroup" mode="unaligned">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates select="." mode="unaligned-begin"/>
      <xsl:if test="@refnum and not(descendant::ltx:equation[@refnum]) and $eqnopos='left'">
	<xsl:apply-templates select="@refnum"/>
      </xsl:if>
      <xsl:apply-templates select="ltx:equationgroup | ltx:equation | ltx:p"/>
      <xsl:if test="@refnum and not(descendant::ltx:equation[@refnum]) and $eqnopos='right'">
	<xsl:apply-templates select="@refnum"/>
      </xsl:if>
      <xsl:apply-templates select="." mode="constraints"/>
      <xsl:apply-templates select="." mode="unaligned-end"/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:equation" mode="unaligned">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="div" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates select="." mode="unaligned-begin"/>
      <xsl:if test="@refnum and $eqnopos='left'">
	<xsl:apply-templates select="@refnum"/>
      </xsl:if>
      <xsl:element name="span" namespace="{$html_ns}">
        <!-- This should cover: ltx:Math, ltx:MathFork, ltx:text & Misc
             (ie. all of equation_model EXCEPT Meta & EquationMeta) -->
	<xsl:apply-templates select="ltx:Math | ltx:MathFork | ltx:text
                                     | ltx:inline-block | ltx:verbatim | ltx:break 
                                     | ltx:graphics | ltx:svg | ltx:rawhtml | ltx:inline-para
                                     | ltx:tabular | ltx:picture" />
      </xsl:element>
      <xsl:if test="@refnum and $eqnopos='right'">
	<xsl:apply-templates select="@refnum"/>
      </xsl:if>
      <xsl:apply-templates select="." mode="constraints"/>
      <xsl:apply-templates select="." mode="unaligned-end"/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
      </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:equationgroup|ltx:equation" mode="constraints">
    <xsl:apply-templates select="ltx:constraint[not(@hidden='true')]"/>
  </xsl:template>

  <!-- by default (not inside an aligned equationgroup) -->
  <xsl:template match="ltx:MathFork">
    <xsl:apply-templates select="ltx:Math[1]"/>
  </xsl:template>

  <!-- ======================================================================
       Aligned templates -->

  <!-- typical table arrangement for numbered equation w/constraint:
       _______________________________
       | (1) | pad | lhs | =rhs | pad |
       |     |_____|_____|______|_____|
       |     | pad |     | =rhs | pad |
       |     |_____|_____|______|_____|
       |     |             constraint |
       |_____|________________________|  

       typical arrangement for numbered equations in equationgroup
       (ignores the number (if any) on the equationgroup)
       _______________________________
       | (1) | pad | lhs | =rhs | pad |
       |     |_____|_____|______|_____|
       |     | pad |     | =rhs | pad |
       |     |_____|_____|______|_____|
       |     |             constraint |
       |_____|________________________|  
       | (2) | pad | lhs | =rhs | pad |
       |     |_____|_____|______|_____|
       |     | pad |     | =rhs | pad |
       |     |_____|_____|______|_____|
       |     |             constraint |
       |_____|________________________|  

       typical arrangement for unnumbered equations in numbered equationgroup
       _______________________________
       | (1) | pad | lhs | =rhs | pad |
       |     |_____|_____|______|_____|
       |     | pad |     | =rhs | pad |
       |     |_____|_____|______|_____|
       |     |             constraint |
       |     |________________________|  
       |     | pad | lhs | =rhs | pad |
       |     |_____|_____|______|_____|
       |     | pad |     | =rhs | pad |
       |     |_____|_____|______|_____|
       |     |             constraint |
       |_____|________________________|  

  -->

  <func:function name="f:countcolumns">
    <xsl:param name="equation"/>
    <func:result>
      <xsl:value-of select="count(ltx:MathFork/ltx:MathBranch[1]/ltx:tr[1]/ltx:td
			    | ltx:MathFork/ltx:MathBranch[1]/ltx:td
			    | ltx:MathFork/ltx:MathBranch[1][not(ltx:tr or ltx:td)]
			    | ltx:Math)"/>
    </func:result>
  </func:function>

  <func:function name="f:maxcolumns">
    <xsl:param name="equations"/>    
    <xsl:for-each select="$equations">
      <xsl:sort select="f:countcolumns(.)" data-type="number" order="descending"/>
      <xsl:if test="position()=1">
	<func:result><xsl:value-of select="f:countcolumns(.)"/></func:result>
      </xsl:if>
    </xsl:for-each>
  </func:function>

  <!-- These are the top-level templates for handling aligned equationgroups
       (possibly with nested equationgroups, but most likely with equations) and equations.
       These create the outer table; work out the # columns being the max of the children.
       We might as well put id's on the outer table for outer-most equationgroups
       (but where for nested ones?).
       For equations, we'll create a tbody, which will get the id!  -->

  <xsl:template match="ltx:equationgroup" mode="aligned">
    <xsl:param name="ncolumns" 
	       select="f:maxcolumns(ltx:equation | ltx:equationgroup/ltx:equation)"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="table" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:text>&#x0A;</xsl:text>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates select="." mode="aligned-begin"/>
      <xsl:apply-templates select="." mode="inalignment">
	<xsl:with-param name="ncolumns" select="$ncolumns"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="aligned-end"/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <!-- Can an equation NOT inside equationgroup meaningfully have embedded  MathForks with tr/td ??
       Having only td's wouldn't actually do anything useful, if a single row is implied.
       Having several tr's is possible, though nothing currently constructs such a thing.
       Can we divide up contained Math's, etc, into something useful?...

       Currently we assume the content will be placed in a single tr/td. -->
  <xsl:template match="ltx:equation" mode="aligned">
    <xsl:param name="ncolumns" select="f:countcolumns(.)"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="table" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates select="." mode="aligned-begin"/>
      <xsl:text>&#x0A;</xsl:text>
      <xsl:apply-templates select="." mode="inalignment">
	<xsl:with-param name="ncolumns" select="$ncolumns"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="." mode="aligned-end"/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="*" mode="aligned-begin"/>
  <xsl:template match="*" mode="aligned-end"/>

  <!-- ======================================================================
       Generate the padding column (td) for a (potentially) numbered row
       in an aligned equationgroup|equation.
       May contain refnum for eqation or containing equationgroup.
       And, may be omitted entirely, if not 1st row of a numbered equationgroup,
       since that column has a rowspan for the entire numbered sequence.
       Note that even though this will be a td within a tr generated by an equation,
       it MAY be displaying the refnum of a containing equationgroup!
       [this mangled nesting keeps us from being able to use tbody!]
  -->
  <xsl:template name="eqnumtd">
    <xsl:param name="side"/>				       <!-- left or right -->
    <xsl:choose>
      <xsl:when test="$eqnopos != $side"/>                       <!-- Wrong side: Nothing -->
      <xsl:when test="ancestor-or-self::ltx:equationgroup[position()=1][@refnum][not(descendant::ltx:equation[@refnum])]"> <!-- eqn.group is numbered, but not eqns! -->
	<!-- place number only for 1st row -->
	<xsl:if test="(ancestor-or-self::ltx:tr and not(preceding-sibling::ltx:tr))
		      or (not(ancestor-or-self::ltx:tr) and not(preceding-sibling::ltx:equation))">
	  <!-- for the containing equationgroup, count the rows in MathFork'd equations,
	       the MathFork'd equations w/ only implicit row, the equations that aren't MathFork'd,
	       and any constraints within equations -->
	  <xsl:variable name="nrows"
			select="count(
ancestor-or-self::ltx:equationgroup[position()=1][@refnum]/descendant::ltx:equation/ltx:MathFork/ltx:MathBranch[1]/ltx:tr
| ancestor-or-self::ltx:equationgroup[position()=1][@refnum]/descendant::ltx:equation[ltx:MathFork/ltx:MathBranch[1]/ltx:td]
| ancestor-or-self::ltx:equationgroup[position()=1][@refnum]/descendant::ltx:equation[ltx:Math or ltx:MathFork/ltx:MathBranch[not(ltx:tr or ltx:td)]]
| ancestor-or-self::ltx:equationgroup[position()=1][@refnum]/descendant::ltx:equation/ltx:constraint
				)"/>
	  <xsl:text>&#x0A;</xsl:text>
	  <xsl:element name="td" namespace="{$html_ns}">
	    <xsl:attribute name="rowspan"><xsl:value-of select="$nrows"/></xsl:attribute>
	    <xsl:attribute name="class">
	      <xsl:value-of select="concat('ltx_align_middle ltx_align_',$side)"/>
	    </xsl:attribute>
	    <xsl:apply-templates
		select="ancestor-or-self::ltx:equationgroup[position()=1]/@refnum"/>
	    </xsl:element>
	</xsl:if>					       <!--Else NOTHING (rowspan'd!) -->
      </xsl:when>
      <xsl:when test="ancestor-or-self::ltx:equation[position()=1][@refnum]">        <!-- equation is numbered! -->
	<!-- place number only for 1st row -->
	<xsl:if test="(ancestor-or-self::ltx:tr and not(preceding-sibling::ltx:tr))
		      or not(ancestor-or-self::ltx:tr)">
	  <!-- Count the MathFork rows, the MathForks w/only implicit row,
	       or if not MathFork'd at all, and also any constraints.-->
	  <xsl:variable name="nrows"
			select="count(
				ancestor-or-self::ltx:equation[position()=1][@refnum]
				/ltx:MathFork/ltx:MathBranch[1]/ltx:tr
				| ancestor-or-self::ltx:equation[position()=1][@refnum]
				[ltx:MathFork/ltx:MathBranch[1]/ltx:td]
				| ancestor-or-self::ltx:equation[position()=1][@refnum]
				[ltx:Math or ltx:MathFork/ltx:MathBranch[not(ltx:tr or ltx:td)]]
				| ancestor-or-self::ltx:equation[position()=1][@refnum]/ltx:constraint
				)"/>
	  <xsl:text>&#x0A;</xsl:text>
	  <xsl:element name="td" namespace="{$html_ns}">
	    <xsl:attribute name="rowspan"><xsl:value-of select="$nrows"/></xsl:attribute>
	    <xsl:attribute name="class">
	      <xsl:value-of select="concat('ltx_align_middle ltx_align_',$side)"/>
	    </xsl:attribute>
	    <xsl:apply-templates select="ancestor-or-self::ltx:equation[position()=1]/@refnum"/>
	  </xsl:element>
	</xsl:if>						       <!--Else NOTHING (rowspan'd!) -->
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="eq-left">
    <xsl:call-template name="eqnumtd">			       <!--Place left number, if any-->
      <xsl:with-param name='side' select="'left'"/>
    </xsl:call-template>
    <xsl:if test="$eqpos != 'left'">
      <xsl:text>&#x0A;</xsl:text>
      <xsl:element name="td" namespace="{$html_ns}">
	<xsl:attribute name="class">ltx_eqn_pad</xsl:attribute>
      </xsl:element>
    </xsl:if><!-- column for centering -->
  </xsl:template>

  <xsl:template name="eq-right">
    <xsl:if test="$eqpos != 'right'">
      <xsl:text>&#x0A;</xsl:text>
      <xsl:element name="td" namespace="{$html_ns}">
	<xsl:attribute name="class">ltx_eqn_pad</xsl:attribute>
      </xsl:element>
    </xsl:if> <!-- Column for centering-->
    <xsl:call-template name="eqnumtd">
      <xsl:with-param name='side' select="'right'"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ====================================================================== 
       Synthesizing rows & columns out for aligned equations and equationgroups 
  -->
  <xsl:template match="*" mode="inalignment-begin">
    <xsl:param name="ncolumns"/>
  </xsl:template>
  <xsl:template match="*" mode="inalignment-end">
    <xsl:param name="ncolumns"/>
  </xsl:template>

  <!-- for intertext type entries -->
  <xsl:template match="ltx:p" mode="inalignment">
    <xsl:param name="ncolumns"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="tr" namespace="{$html_ns}">
      <xsl:attribute name="class">ltx_align_baseline</xsl:attribute>
      <xsl:element name="td" namespace="{$html_ns}">
	<xsl:attribute name="class">ltx_align_left</xsl:attribute>
	<xsl:attribute name="style">white-space:normal;</xsl:attribute>
	<xsl:attribute name="colspan">
	  <xsl:value-of select="1+$ncolumns+f:if($eqpos!='left',1,0)+f:if($eqpos!='right',1,0)"/>
	</xsl:attribute>
	<xsl:apply-templates select="." mode="begin"/>
	<xsl:apply-templates select="." mode="inalignment-begin">
	  <xsl:with-param name="ncolumns" select="$ncolumns"/>
	</xsl:apply-templates>
	<xsl:apply-templates/>
	<xsl:apply-templates select="." mode="inalignment-end">
	  <xsl:with-param name="ncolumns" select="$ncolumns"/>
	</xsl:apply-templates>
	<xsl:apply-templates select="." mode="end"/>
      </xsl:element>
    </xsl:element>
  </xsl:template>

  <!-- Hopefully we can deal with nested equationgroups, but we've got to attach the id somewhere!
       We can put it on outer table, insert a tbody (but not nested!);
       That handles the most common mangled cases (w/equationgroup for labelling AND aligning).
       For fallback nested too deep, we'll just insert an empty tr -->
  <xsl:template match="ltx:equationgroup" mode="inalignment">
    <xsl:param name="ncolumns"/>
    <!-- This is pretty lame, but if there's an id, we better put it SOMEPLACE! -->
    <xsl:choose>
      <!-- easy case: no id, or already on table (since this is outer equationgroup)-->
      <xsl:when test="not(@fragid) or not(parent::ltx:equationgroup)">
	<xsl:apply-templates select="." mode="ininalignment">
	  <xsl:with-param name="ncolumns" select="$ncolumns"/>
	</xsl:apply-templates>
      </xsl:when>
      <!-- Nested, but only 1 deep; introduce a tbody-->
      <xsl:when test="not(parent::ltx:equationgroup[ancestor::ltx:equationgroup])">
	<xsl:element name="tbody" namespace="{$html_ns}">
	  <xsl:call-template name="add_id"/>
	  <xsl:apply-templates select="." mode="ininalignment">
	    <xsl:with-param name="ncolumns" select="$ncolumns"/>
	  </xsl:apply-templates>
	</xsl:element>
      </xsl:when>
      <!-- Sloppy case, we at least need an empty row to put the id on; Ugh -->
      <xsl:otherwise>
	<xsl:element name="tr" namespace="{$html_ns}">
	  <xsl:call-template name="add_id"/>
	  <xsl:element name="td" namespace="{$html_ns}"/> <!--Empty, too-->
	</xsl:element>
	<xsl:apply-templates select="." mode="ininalignment">
	  <xsl:with-param name="ncolumns" select="$ncolumns"/>
	</xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:equationgroup" mode="ininalignment">
    <xsl:param name="ncolumns"/>
    <!-- This is pretty lame, but if there's an id, we better put it SOMEPLACE! -->
    <xsl:apply-templates select="." mode="inalignment-begin">
      <xsl:with-param name="ncolumns" select="$ncolumns"/>
    </xsl:apply-templates>
    <xsl:apply-templates select="ltx:equationgroup | ltx:equation | ltx:p" mode="inalignment">
      <xsl:with-param name="ncolumns" select="$ncolumns"/>
    </xsl:apply-templates>
    <xsl:apply-templates select="." mode="aligned-constraints">
      <xsl:with-param name="ncolumns" select="$ncolumns"/>
    </xsl:apply-templates>
    <xsl:apply-templates select="." mode="inalignment-end">
      <xsl:with-param name="ncolumns" select="$ncolumns"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="ltx:equation" mode="inalignment">
    <xsl:param name="ncolumns"/>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:choose>
      <!-- Case 1: (possibly) Multi-line equation -->
      <xsl:when test="ltx:MathFork/ltx:MathBranch[1]/ltx:tr">
	<xsl:element name="tr" namespace="{$html_ns}">
	  <!-- Note that the id is only going on the 1st row! -->
	  <xsl:if test="parent::ltx:equationgroup"> <!--Don't duplicate id! -->
	    <xsl:call-template name="add_id"/>
	  </xsl:if>
	  <xsl:call-template name="add_attributes">
	    <xsl:with-param name="extra_classes" select="'ltx_align_baseline'"/>
	  </xsl:call-template>
	  <xsl:apply-templates select="." mode="inalignment-begin">
	    <xsl:with-param name="ncolumns" select="$ncolumns"/>
	  </xsl:apply-templates>
	  <xsl:call-template name="eq-left"/>
	  <xsl:apply-templates select="ltx:MathFork/ltx:MathBranch[1]/ltx:tr[1]/ltx:td"
			       mode="inalignment"/>
	  <xsl:call-template name="eq-right"/>
	</xsl:element>
	<xsl:for-each select="ltx:MathFork/ltx:MathBranch[1]/ltx:tr[position() &gt; 1]">
	  <xsl:text>&#x0A;</xsl:text>
	  <xsl:element name="tr" namespace="{$html_ns}">
	    <xsl:attribute name="class">ltx_align_baseline</xsl:attribute>
	    <xsl:call-template name="eq-left"/>
	    <xsl:apply-templates select="ltx:td" mode="inalignment"/>
	    <xsl:call-template name="eq-right"/>
	  </xsl:element>
	</xsl:for-each>
      </xsl:when>
      <!-- Case 2: Single line, (possibly) multiple columns -->
      <xsl:when test="ltx:MathFork/ltx:MathBranch[1]">
	<xsl:element name="tr" namespace="{$html_ns}">
	  <xsl:if test="parent::ltx:equationgroup"> <!--Don't duplicate id! -->
	    <xsl:call-template name="add_id"/>
	  </xsl:if>
	  <xsl:call-template name="add_attributes">
	    <xsl:with-param name="extra_classes" select="'ltx_align_baseline'"/>
	  </xsl:call-template>
	  <xsl:apply-templates select="." mode="inalignment-begin">
	    <xsl:with-param name="ncolumns" select="$ncolumns"/>
	  </xsl:apply-templates>
	  <xsl:call-template name="eq-left"/>
	  <xsl:apply-templates select="ltx:MathFork/ltx:MathBranch[1]/*"
			       mode="inalignment"/>
	  <xsl:call-template name="eq-right"/>
	</xsl:element>
      </xsl:when>
      <!-- Case : default; just an unaligned equation, presumably within a group-->
      <xsl:otherwise>
	<xsl:element name="tr" namespace="{$html_ns}">
	  <xsl:if test="parent::ltx:equationgroup"> <!--Don't duplicate id! -->
	    <xsl:call-template name="add_id"/>
	  </xsl:if>
	  <xsl:call-template name="add_attributes">
	    <xsl:with-param name="extra_classes" select="'ltx_align_baseline'"/>
	  </xsl:call-template>
	  <xsl:apply-templates select="." mode="inalignment-begin">
	    <xsl:with-param name="ncolumns" select="$ncolumns"/>
	  </xsl:apply-templates>
	  <xsl:call-template name="eq-left"/>
	  <xsl:text>&#x0A;</xsl:text>
	  <xsl:element name="td" namespace="{$html_ns}">
	    <xsl:attribute name="class">
	      <xsl:value-of select="concat('ltx_align_',$eqpos)"/>
	    </xsl:attribute>
	    <xsl:if test="$ncolumns > 1">
	      <xsl:attribute name="colspan"><xsl:value-of select="$ncolumns"/></xsl:attribute>
	    </xsl:if>
            <!-- Hopefully, ltx:MathFork has been handled by the above cases;
                 This should cover: ltx:Math, ltx:text & Misc
                 (ie. all of equation_model EXCEPT Meta & EquationMeta) -->
            <xsl:apply-templates select="ltx:Math | ltx:text
                                         | ltx:inline-block | ltx:verbatim | ltx:break 
                                         | ltx:graphics | ltx:svg | ltx:rawhtml | ltx:inline-para
                                         | ltx:tabular | ltx:picture" />
	  </xsl:element>
	  <xsl:call-template name="eq-right"/>
	</xsl:element>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="." mode="aligned-constraints">
      <xsl:with-param name="ncolumns" select="$ncolumns"/>
    </xsl:apply-templates>
    <xsl:apply-templates select="." mode="inalignment-end">
      <xsl:with-param name="ncolumns" select="$ncolumns"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="ltx:equationgroup|ltx:equation" mode="aligned-constraints">
    <xsl:param name="ncolumns"/>
    <xsl:if test="ltx:constraint[not(@hidden='true')]">
      <xsl:text>&#x0A;</xsl:text>
      <xsl:element name="tr" namespace="{$html_ns}">
	<xsl:element name="td" namespace="{$html_ns}">
	  <xsl:attribute name="class">ltx_align_right</xsl:attribute>
	  <!-- the $ncolumns of math, plus whatever endpadding, but NOT the number-->
	  <xsl:attribute name="colspan">
	    <xsl:value-of select="$ncolumns
				  +f:if($eqpos != 'left',1,0)+f:if($eqpos != 'right',1,0)"/>
	  </xsl:attribute>
	  <xsl:apply-templates select="." mode="constraints"/>
	</xsl:element>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <xsl:template match="ltx:constraint">
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

  <!-- NOTE: This is pretty wacky.  Maybe we should move the text inside the equation? -->
  <xsl:template match="ltx:td" mode="inalignment">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="td" namespace="{$html_ns}">
      <xsl:if test="@colspan">
	<xsl:attribute name="colspan"><xsl:value-of select="@colspan"/></xsl:attribute>
      </xsl:if>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
      <xsl:if test="(self::* = ../ltx:td[position()=last()])
		    and (parent::* = ../../ltx:tr[position()=last()])
		    and ancestor::ltx:MathFork/following-sibling::*[position()=1][self::ltx:text]">
	<!-- if we're the last td in the last tr in an equation followed by a text, 
	     insert the text here!-->
	<xsl:apply-templates select="ancestor::ltx:MathFork/following-sibling::ltx:text[1]/node()"/>
      </xsl:if>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:Math" mode="inalignment">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="td" namespace="{$html_ns}">
      <xsl:call-template name="add_attributes">
	<xsl:with-param name="extra_classes" select="'ltx_align_center'"/>
      </xsl:call-template>
      <xsl:apply-templates select="."/>
      <xsl:if test="ancestor::ltx:MathFork/following-sibling::*[position()=1][self::ltx:text]">
	<!-- if we're followed by a text, insert the text here!-->
	<xsl:apply-templates select="ancestor::ltx:MathFork/following-sibling::ltx:text[1]/node()"/>
      </xsl:if>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:text" mode="inequationgroup"/>

  <!-- ======================================================================
       Various Lists
       ====================================================================== -->

  <xsl:template match="ltx:itemize">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="ul" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:enumerate">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="ol" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:description">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="dl" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates mode='description'/>
      <xsl:apply-templates select="." mode="end"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:item">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:choose>
      <xsl:when test="child::ltx:tag">
	<xsl:element name="li" namespace="{$html_ns}">
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes">
	    <xsl:with-param name="extra_style" select="'list-style-type:none;'"/>
	  </xsl:call-template>
	  <xsl:apply-templates select="." mode="begin"/>
	  <xsl:apply-templates/>
	  <xsl:apply-templates select="." mode="end"/>
	</xsl:element>
      </xsl:when>
      <xsl:when test="@frefnum">
	<xsl:element name="li" namespace="{$html_ns}">
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes">
	    <xsl:with-param name="extra_style" select="'list-style-type:none;'"/>
	  </xsl:call-template>
	  <xsl:apply-templates select="." mode="begin"/>
	  <xsl:element name="tag" namespace="{$html_ns}">
	    <xsl:attribute name="class">ltx_tag</xsl:attribute>
	    <xsl:value-of select="@frefnum"/>
	  </xsl:element>
	  <xsl:apply-templates/>
	  <xsl:apply-templates select="." mode="end"/>
	</xsl:element>
      </xsl:when>
      <xsl:otherwise>
	<xsl:element name="li" namespace="{$html_ns}">
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes"/>
	  <xsl:apply-templates select="." mode="begin"/>
	  <xsl:apply-templates/>
	  <xsl:apply-templates select="." mode="end"/>
	</xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:item" mode="description">
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="dt" namespace="{$html_ns}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="ltx:tag"/>
    </xsl:element>
    <xsl:text>&#x0A;</xsl:text>
    <xsl:element name="dd" namespace="{$html_ns}">
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:apply-templates select="*[local-name() != 'tag']"/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="ltx:tag">
    <xsl:element name="span" namespace="{$html_ns}">
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="." mode="begin"/>
      <xsl:value-of select="@open"/>
      <xsl:apply-templates/>
      <xsl:value-of select="@close"/>
      <xsl:apply-templates select="." mode="end"/>
    </xsl:element>
  </xsl:template>

  <!-- Tricky, perhaps: ltx:tag is typically within a title or caption
       so it's the GRANDPARENT's type we want to use here!-->
  <xsl:template match="ltx:tag" mode="classes">
    <xsl:apply-imports/>
    <xsl:text> </xsl:text>
    <xsl:value-of select="concat('ltx_tag_',local-name(../..))"/>
  </xsl:template>

  <!-- ======================================================================
       Support for column splitting
       ====================================================================== -->

  <!-- Given a list of items, split it into 2 columns.
       $wrapper names the element to wrap each half of the items
       [We'd really like to call a template, but xslt1 can't call variable templates! Sigh...]
       $items is the list of items
       $miditem is the cut-off position -->
  <xsl:template name="split-columns">
    <xsl:param name="wrapper"/>
    <xsl:param name="items"/>
    <xsl:param name="miditem"/>

    <xsl:text>&#x0A;</xsl:text>
    <xsl:choose>
      <xsl:when test="($miditem &lt; count($items)) or not(parent::ltx:chapter)">
	<xsl:element name="div" namespace="{$html_ns}">
	  <xsl:call-template name="add_id"/>
	  <xsl:attribute name='class'>ltx_page_columns</xsl:attribute>
	  <xsl:text>&#x0A;</xsl:text>
	  <xsl:element name="div" namespace="{$html_ns}">
	    <xsl:attribute name='class'>ltx_page_column1</xsl:attribute>
	    <xsl:text>&#x0A;</xsl:text>
	    <xsl:element name="{$wrapper}" namespace="{$html_ns}">
	      <xsl:call-template name="add_attributes"/>
	      <xsl:apply-templates select="." mode="begin"/>
	      <xsl:apply-templates select="$items[position() &lt; $miditem]"/>
	      <xsl:apply-templates select="." mode="end"/>
	      <xsl:text>&#x0A;</xsl:text>
	    </xsl:element>
	    <xsl:text>&#x0A;</xsl:text>
	  </xsl:element>
	  <xsl:text>&#x0A;</xsl:text>
	  <xsl:element name="div" namespace="{$html_ns}">
	    <xsl:attribute name='class'>ltx_page_column2</xsl:attribute>
	    <xsl:text>&#x0A;</xsl:text>
	    <xsl:element name="{$wrapper}" namespace="{$html_ns}">
	      <xsl:call-template name="add_attributes"/>
	      <xsl:apply-templates select="." mode="begin"/>
	      <xsl:apply-templates select="$items[not(position() &lt; $miditem)]"/>
	      <xsl:apply-templates select="." mode="end"/>
	      <xsl:text>&#x0A;</xsl:text>
	    </xsl:element>
	    <xsl:text>&#x0A;</xsl:text>
	  </xsl:element>
	  <xsl:text>&#x0A;</xsl:text>
	</xsl:element>
      </xsl:when>
      <xsl:otherwise>
	<xsl:element name="{$wrapper}" namespace="{$html_ns}">
	  <xsl:call-template name="add_attributes"/>
	  <xsl:apply-templates select="." mode="begin"/>
	  <xsl:apply-templates select="$items"/>
	  <xsl:apply-templates select="." mode="end"/>
	  <xsl:text>&#x0A;</xsl:text>
	</xsl:element>
	<xsl:text>&#x0A;</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
