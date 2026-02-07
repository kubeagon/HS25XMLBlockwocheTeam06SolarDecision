<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:f="urn:functions"
                exclude-result-prefixes="xs f"
                version="2.0">

    <xsl:output method="xml" indent="yes" encoding="UTF-8"/>

    <xsl:param name="csv-uri" as="xs:string"/>
    <xsl:param name="timezone" as="xs:string" select="'Europe/Zurich'"/>
    <xsl:param name="unit" as="xs:string" select="'Rp/kWh'"/>
    <xsl:param name="currency" as="xs:string" select="'CHF'"/>
    <xsl:param name="resolution" as="xs:string" select="'PT1H'"/>

    <xsl:function name="f:to-iso" as="xs:string">
        <xsl:param name="dt" as="xs:string"/>
        <xsl:sequence select="replace(normalize-space($dt), ' ', 'T')"/>
    </xsl:function>

    <xsl:function name="f:month" as="xs:string">
        <xsl:param name="iso" as="xs:string"/>
        <xsl:sequence select="substring($iso, 1, 7)"/>
    </xsl:function>

    <!-- Call this named template from Saxon -->
    <xsl:template name="main">
        <xsl:if test="not(normalize-space($csv-uri))">
            <xsl:message terminate="yes">Missing parameter csv-uri</xsl:message>
        </xsl:if>

        <xsl:variable name="lines"
                      select="tokenize(unparsed-text(resolve-uri($csv-uri, static-base-uri())), '\r?\n')[normalize-space(.)]"/>

        <xsl:variable name="data-lines" select="$lines[position() gt 1]"/>

        <xsl:variable name="rows" as="element(r)*">
            <xsl:for-each select="$data-lines">
                <xsl:variable name="cols" select="tokenize(., ',')"/>
                <r dt="{f:to-iso($cols[1])}"
                   price="{format-number(number($cols[2]), '0.00')}"
                   region="{normalize-space($cols[3])}"/>
            </xsl:for-each>
        </xsl:variable>

        <xsl:variable name="month" select="f:month(($rows/@dt)[1])"/>

        <prices>
            <xsl:attribute name="month" select="$month"/>
            <xsl:attribute name="timezone" select="$timezone"/>
            <xsl:attribute name="unit" select="$unit"/>
            <xsl:attribute name="currency" select="$currency"/>

            <xsl:for-each-group select="$rows" group-by="@region">
                <region>
                    <xsl:attribute name="id" select="current-grouping-key()"/>
                    <xsl:attribute name="name" select="current-grouping-key()"/>

                    <series>
                        <xsl:attribute name="resolution" select="$resolution"/>

                        <xsl:for-each select="current-group()">
                            <xsl:sort select="@dt"/>
                            <price>
                                <xsl:attribute name="datetime" select="@dt"/>
                                <xsl:value-of select="@price"/>
                            </price>
                        </xsl:for-each>
                    </series>
                </region>
            </xsl:for-each-group>
        </prices>
    </xsl:template>

</xsl:stylesheet>
