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
    xmlns       = "http://www.w3.org/1999/xhtml"
    xmlns:func  = "http://exslt.org/functions"
    xmlns:f     = "http://dlmf.nist.gov/LaTeXML/functions"
    extension-element-prefixes="func f"
    exclude-result-prefixes = "ltx func f">

  <!-- ======================================================================
       Various Blocks
       ====================================================================== -->

  <!-- no class here, since ltx:p it is generated behind the scenes (?)-->
  <xsl:template match="ltx:p">
    <p>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </p>
  </xsl:template>

  <xsl:template match="ltx:quote">
    <blockquote>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </blockquote>
  </xsl:template>

  <xsl:template match="ltx:block">
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="ltx:listingblock">
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
	<xsl:with-param name="extra_classes" select="'listing'"/>
      </xsl:call-template>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="ltx:listingblock/ltx:tabular">
    <table>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </table>
  </xsl:template>

  <xsl:template match="ltx:break">
    <br><xsl:call-template name="add_attributes"/></br>
  </xsl:template>

  <!-- Need to handle attributes! -->
  <xsl:template match="ltx:inline-block">
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="ltx:verbatim">
    <xsl:choose>
      <xsl:when test="contains(text(),'&#xA;')">
	<pre>
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes"/>
	  <xsl:apply-templates/>
	</pre>
      </xsl:when>
      <xsl:otherwise>
	<code>
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes"/>
	  <xsl:apply-templates/>
	</code>
      </xsl:otherwise>
    </xsl:choose>
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


  <xsl:template match="ltx:equation/@refnum | ltx:equationgroup/@refnum"
		>(<span class='refnum'><xsl:value-of select="."/></span>)</xsl:template>

  <!-- ======================================================================
       Basic templates, dispatching on aligned or unaligned forms-->

  <xsl:template match="ltx:equationgroup">
    <xsl:choose>
      <xsl:when test="$aligned_equations">
	<xsl:call-template name="equationgroup-aligned"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:call-template name="equationgroup-unaligned"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:equation">
    <xsl:choose>
      <xsl:when test="$aligned_equations">
	<xsl:call-template name="equation-aligned"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:call-template name="equation-unaligned"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ======================================================================
       Unaligned templates -->

  <xsl:template name="equationgroup-unaligned">
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:if test="@refnum and $eqnopos='left'"><xsl:apply-templates select="@refnum"/></xsl:if>
      <xsl:apply-templates select="ltx:equationgroup | ltx:equation | ltx:p"/>
      <xsl:if test="@refnum and $eqnopos='right'"><xsl:apply-templates select="@refnum"/></xsl:if>
      <xsl:apply-templates select="ltx:constraint[not(@hidden='true')]"/>
    </div>
    <xsl:apply-templates select="ltx:metadata" mode="meta"/>
  </xsl:template>

  <xsl:template name="equation-unaligned">
    <div>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:if test="@refnum and $eqnopos='left'"><xsl:apply-templates select="@refnum"/></xsl:if>
      <span class='equationcontent'
  	  ><xsl:apply-templates select="ltx:Math | ltx:MathFork | ltx:text"/></span>
      <xsl:if test="@refnum and $eqnopos='right'"><xsl:apply-templates select="@refnum"/></xsl:if>
      <xsl:apply-templates select="ltx:constraint[not(@hidden='true')]"/>
    </div>
    <xsl:apply-templates select="ltx:metadata" mode="meta"/>
  </xsl:template>


  <xsl:template name="equation-meta-unaligned">
    <xsl:apply-templates select="ltx:constraint[not(@hidden='true')]"/>
    <xsl:apply-templates select="ltx:metadata" mode="meta"/>
  </xsl:template>

  <!-- by default (not inside an aligned equationgroup) -->
  <xsl:template match="ltx:MathFork">
    <xsl:apply-templates select="ltx:Math[1]"/>
  </xsl:template>

  <!-- ======================================================================
       Aligned templates -->

  <func:function name="f:countcolumns">
    <xsl:param name="equation"/>
    <func:result><xsl:value-of select="count(ltx:MathFork/ltx:MathBranch[1]/ltx:tr[1]/ltx:td
                                           | ltx:MathFork/ltx:MathBranch[1]/ltx:td
					   | ltx:MathFork/ltx:MathBranch[1][not(ltx:tr or ltx:td)]
					   | ltx:Math)"/></func:result>
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

  <xsl:template name="equationgroup-aligned">
    <!-- Hopefully the 1st equation row will sufficiently represent the pattern.
	 Really should be some complex of max's of sum's of... -->
<!--
    <xsl:param name="columns"
	       select="  ltx:equation[1]/ltx:MathFork/ltx:MathBranch[1]/ltx:tr[1]/ltx:td
		       | ltx:equation[1]/ltx:MathFork/ltx:MathBranch[1]/ltx:td
		       | ltx:equation[1]/ltx:MathFork/ltx:MathBranch[1][not(ltx:tr or ltx:td)]
		       | ltx:equation[1]/ltx:Math "/>
    <xsl:param name="ncolumns" select="count($columns)"/>
-->
<!--    <xsl:param name="ncolumns" select="f:countcolumns(ltx:equation[1])"/>-->
    <xsl:param name="ncolumns" select="f:maxcolumns(ltx:equation | ltx:equationgroup/ltx:equation)"/>
    <table><xsl:call-template name="add_attributes"/><!-- but not id -->
      <xsl:text>
      </xsl:text>
      <xsl:apply-templates select="." mode="aligned">
	<xsl:with-param name="ncolumns" select="$ncolumns"/>
      </xsl:apply-templates>
      <xsl:text>
      </xsl:text>
    </table>
  </xsl:template>

  <!-- Can an equation NOT inside equationgroup meaningfully have embedded  MathForks with tr/td ??
       Having only td's wouldn't actually do anything useful, if a single row is implied.
       Having several tr's is possible, though nothing currently constructs such a thing.
       Can we divide up contained Math's, etc, into something useful?...

Currently we assume the content will be placed in a single tr/td. -->
  <xsl:template name="equation-aligned">
    <xsl:param name="ncolumns" select="f:countcolumns(.)"/>
    <table><xsl:call-template name="add_attributes"/><!-- but not id -->
      <xsl:text>
      </xsl:text>
      <xsl:apply-templates select="." mode="aligned">
	<xsl:with-param name="ncolumns" select="$ncolumns"/>
      </xsl:apply-templates>
      <xsl:text>
      </xsl:text>
    </table>
  </xsl:template>

  <!-- ======================================================================
       Generate the padding column (td) for a (potentially) numbered row
       in an aligned equationgroup|equation.
       May contain refnum for eqation or containing equationgroup.
       And, may be omitted entirely, if not 1st row of a numbered equationgroup,
       since that column has a rowspan for the entire table.
  -->
  <xsl:template name="eqnumtd">
    <xsl:param name="side"/>				       <!-- left or right -->
    <xsl:choose>
      <xsl:when test="$eqnopos != $side"/>                       <!-- Wrong side: Nothing -->
      <xsl:when test="ancestor-or-self::ltx:equationgroup[position()=1][@refnum]"> <!-- eqn.group is numbered! -->
	<!-- place number only for 1st row -->
	<xsl:if test="(ancestor-or-self::ltx:tr and not(preceding-sibling::ltx:tr))
		      or (not(ancestor-or-self::ltx:tr) and not(preceding-sibling::ltx:equation))">
	  <xsl:variable name="nrows"
			select="count(
ancestor-or-self::ltx:equationgroup[position()=1][@refnum]/descendant::ltx:equation/ltx:MathFork/ltx:MathBranch[1]/ltx:tr
| ancestor-or-self::ltx:equationgroup[position()=1][@refnum]/descendant::ltx:equation[ltx:MathFork/ltx:MathBranch[1]/ltx:td]
| ancestor-or-self::ltx:equationgroup[position()=1][@refnum]/descendant::ltx:equation[ltx:Math or ltx:MathFork/ltx:MathBranch[not(ltx:tr or ltx:td)]]
| ancestor-or-self::ltx:equationgroup[position()=1][@refnum]/descendant::ltx:equation[ltx:constraint or ltx:metadata]
				)"/>
	  <td rowspan="{$nrows}" class="{concat('middle ',$side)}">
	    <xsl:apply-templates select="ancestor-or-self::ltx:equationgroup[position()=1]/@refnum"/>
	  </td>
	</xsl:if>						       <!--Else NOTHING (rowspan'd!) -->
      </xsl:when>
      <xsl:when test="ancestor-or-self::ltx:equation[position()=1][@refnum]">        <!-- equation is numbered! -->
	<!-- place number only for 1st row -->
	<xsl:if test="(ancestor-or-self::ltx:tr and not(preceding-sibling::ltx:tr))
		      or not(ancestor-or-self::ltx:tr)">
	  <xsl:variable name="nrows"
			select="count(
				ancestor-or-self::ltx:equation[position()=1][@refnum]
				/ltx:MathFork/ltx:MathBranch[1]/ltx:tr
				| ancestor-or-self::ltx:equation[position()=1][@refnum]
				[ltx:MathFork/ltx:MathBranch[1]/ltx:td]
				| ancestor-or-self::ltx:equation[position()=1][@refnum]
				[ltx:Math or ltx:MathFork/ltx:MathBranch[not(ltx:tr or ltx:td)]]
				| ancestor-or-self::ltx:equation[position()=1][@refnum][ltx:constraint or ltx:metadata]
				)"/>
	  <td rowspan="{$nrows}" class="{concat('middle ',$side)}">
	    <xsl:apply-templates select="ancestor-or-self::ltx:equation[position()=1]/@refnum"/>
	  </td>
	</xsl:if>						       <!--Else NOTHING (rowspan'd!) -->
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="eq-left">
    <xsl:call-template name="eqnumtd">			       <!--Place left number, if any-->
      <xsl:with-param name='side' select="'left'"/>
    </xsl:call-template>
    <xsl:if test="$eqpos != 'left'"><td class="eqpad"/></xsl:if><!-- column for centering -->
  </xsl:template>

  <xsl:template name="eq-right">
    <xsl:if test="$eqpos != 'right'"><td class="eqpad"/></xsl:if> <!-- Column for centering-->
    <xsl:call-template name="eqnumtd">
      <xsl:with-param name='side' select="'right'"/>
    </xsl:call-template>
  </xsl:template>

  <!-- ====================================================================== 
       Synthesizing rows & columns out for aligned equations and equationgroups 
  -->

  <!-- for intertext type entries -->
  <xsl:template match="ltx:p" mode="aligned">
    <xsl:param name="ncolumns"/>
    <tr class="baseline">
      <td class="left"
	  colspan="{1+$ncolumns+f:if($eqpos!='left',1,0)+f:if($eqpos!='right',1,0)}"
	  style="white-space:normal;"
	  ><xsl:apply-templates/></td>
    </tr>
  </xsl:template>

  <!-- Can this reasonably deal with NESTED equationgroups?
       Probably, assuming the previous counts of tr's and td's are done right.-->
  <xsl:template match="ltx:equationgroup" mode="aligned">
    <xsl:param name="ncolumns"/>
    <xsl:apply-templates select="ltx:equationgroup | ltx:equation | ltx:p" mode="aligned">
      <xsl:with-param name="ncolumns" select="$ncolumns"/>
    </xsl:apply-templates>
    <xsl:call-template name="equation-meta-aligned">
      <xsl:with-param name="ncolumns" select="$ncolumns"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="ltx:equation" mode="aligned">
    <xsl:param name="ncolumns"/>
    <xsl:choose>
      <xsl:when test="ltx:MathFork/ltx:MathBranch[1]/ltx:tr">
	<!-- What class information were we obtaining from the tr??? -->
	<tr>
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes">
	    <!-- NOTE HACK (see above) should this be a call to a new template on the .../ltx:tr? -->
	    <xsl:with-param name="extra_classes" select="'baseline tr'"/>
	  </xsl:call-template>
	  <xsl:call-template name="eq-left"/>
	  <xsl:apply-templates select="ltx:MathFork/ltx:MathBranch[1]/ltx:tr[1]/ltx:td"
			       mode="aligned"/>
	  <xsl:call-template name="eq-right"/>
	</tr>
	<xsl:for-each select="ltx:MathFork/ltx:MathBranch[1]/ltx:tr[position() &gt; 1]">
	  <tr>
	    <xsl:call-template name="add_id"/><!-- or ? -->
	    <xsl:call-template name="add_attributes">
	      <xsl:with-param name="extra_classes" select="'baseline'"/>
	    </xsl:call-template>
	    <xsl:call-template name="eq-left"/>
	    <xsl:apply-templates select="ltx:td" mode="aligned"/>
	    <xsl:call-template name="eq-right"/>
	  </tr>
	</xsl:for-each>
	<!--</tbody>-->
      </xsl:when>

      <xsl:when test="ltx:MathFork/ltx:MathBranch[1]">
	<tr>
	  <xsl:call-template name="add_id"/><!-- or ? -->
	  <xsl:call-template name="add_attributes">
	    <xsl:with-param name="extra_classes" select="'baseline'"/>
	  </xsl:call-template>
	  <xsl:call-template name="eq-left"/>
	  <xsl:apply-templates select="ltx:MathFork/ltx:MathBranch[1]/*"
			       mode="aligned"/>
	  <xsl:call-template name="eq-right"/>
	</tr>
      </xsl:when>

      <xsl:otherwise>
	<tr>
	  <xsl:call-template name="add_id"/><!-- or ? -->
	  <xsl:call-template name="add_attributes">
	    <xsl:with-param name="extra_classes" select="'baseline'"/>
	  </xsl:call-template>
	  <xsl:call-template name="eq-left"/>
	  <td  class="{$eqpos}" colspan="{$ncolumns}"><xsl:apply-templates select="ltx:Math | ltx:text"/></td>
	  <xsl:call-template name="eq-right"/>
	</tr>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:call-template name="equation-meta-aligned">
      <xsl:with-param name="ncolumns" select="$ncolumns"/>
    </xsl:call-template>
  </xsl:template>

  <!-- NOTE: This is pretty wacky.  Maybe we should move the text inside the equation? -->
  <xsl:template match="ltx:td" mode="aligned" xml:space='default'>
    <td colspan="{f:if(@colspan,@colspan,1)}">
      <xsl:call-template name="add_attributes">
	<xsl:with-param name="extra_classes" select="@align"/>
      </xsl:call-template>
      <xsl:apply-templates/>
      <xsl:if test="(self::* = ../ltx:td[position()=last()])
		    and (parent::* = ../../ltx:tr[position()=last()])
		    and ancestor::ltx:MathFork/following-sibling::*[position()=1][self::ltx:text]"
	      ><!-- if we're the last td in the last tr in an equation followed by a text, 
		    insert the text here! 
	       --><xsl:apply-templates select="ancestor::ltx:MathFork/following-sibling::ltx:text[1]/node()"
      /></xsl:if></td>
  </xsl:template>

  <xsl:template match="ltx:Math" mode="aligned" xml:space='default'>
    <td>
      <xsl:call-template name="add_attributes">
	<xsl:with-param name="extra_classes" select="'center'"/>
      </xsl:call-template>
      <xsl:apply-templates select="."/><xsl:if test="
      ancestor::ltx:MathFork/following-sibling::*[position()=1][self::ltx:text]"
      ><!-- if we're followed by a text, insert the text here! 
      --><xsl:apply-templates select="ancestor::ltx:MathFork/following-sibling::ltx:text[1]/node()"
      /></xsl:if></td>
  </xsl:template>

  <xsl:template name="equation-meta-aligned">
    <xsl:param name="ncolumns"/>
    <xsl:if test="ltx:constraint[not(@hidden='true')] or ltx:metadata">
      <tr>
	<td class='right' colspan="{1+$ncolumns
				   +f:if($eqpos != 'left',1,0)+f:if($eqpos != 'right',1,0)}">
	  <xsl:apply-templates select="ltx:constraint[not(@hidden='true')]"/>
	  <xsl:apply-templates select="ltx:metadata" mode="meta"/>
	</td>
      </tr>
    </xsl:if>
  </xsl:template>

  <xsl:template match="ltx:constraint" xml:space='default'>
    <span>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </span>
    <span class="eqnend"/>
  </xsl:template>

  <xsl:template match="ltx:text" mode="inequationgroup"/>

  <!-- ======================================================================
       Various Lists
       ====================================================================== -->

  <xsl:template match="ltx:itemize">
    <ul>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </ul>
  </xsl:template>

  <xsl:template match="ltx:enumerate">
    <ol>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates/>
    </ol>
  </xsl:template>

  <xsl:template match="ltx:description">
    <dl>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates mode='description'/>
    </dl>
  </xsl:template>

  <xsl:template match="ltx:item">
    <xsl:choose>
      <xsl:when test="child::ltx:tag">
	<li>
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes">
	    <xsl:with-param name="extra_classes" select="'nobullet'"/>
	  </xsl:call-template>
	<xsl:apply-templates/>
	</li>
      </xsl:when>
      <xsl:otherwise>
	<li>
	  <xsl:call-template name="add_id"/>
	  <xsl:call-template name="add_attributes"/>
	  <xsl:apply-templates/>
	</li>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="ltx:item" mode="description">
    <dt>
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="ltx:tag"/>
    </dt>
    <dd>
      <xsl:call-template name="add_attributes"/>
      <xsl:apply-templates select="*[local-name() != 'tag']"/>
    </dd>
  </xsl:template>

  <xsl:template match="ltx:tag">
    <span>
      <xsl:call-template name="add_attributes"/>
      <xsl:value-of select="@open"/><xsl:apply-templates/><xsl:value-of select="@close"/>
    </span>
  </xsl:template>

  <!-- ======================================================================
       Graphics inclusions
       ====================================================================== -->

  <xsl:template match="ltx:graphics">
    <img src="{@imagesrc}">
      <xsl:call-template name="add_id"/>
      <xsl:call-template name="add_attributes">
	<xsl:with-param name="extra_style">
	  <xsl:if test="@imagedepth">
	    <xsl:value-of select="concat('vertical-align:-',@imagedepth,'px')"/>
	  </xsl:if>
	</xsl:with-param>
      </xsl:call-template>
      <xsl:if test="@imagewidth">
	<xsl:attribute name='width'><xsl:value-of select="@imagewidth"/></xsl:attribute>
      </xsl:if>
      <xsl:if test="@imageheight">
	<xsl:attribute name='height'><xsl:value-of select="@imageheight"/></xsl:attribute>
      </xsl:if>
      <xsl:choose>
	<xsl:when test="../ltx:figure/ltx:caption">
	  <xsl:attribute name='alt'><xsl:value-of select="../ltx:figure/ltx:caption/text()"/></xsl:attribute>
	</xsl:when>
	<xsl:when test="@description">
	  <xsl:attribute name='alt'><xsl:value-of select="@description"/></xsl:attribute>
	</xsl:when>
      </xsl:choose>
    </img>
  </xsl:template>

</xsl:stylesheet>