<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:f="urn:functions"
                exclude-result-prefixes="xs f"
                version="2.0">

    <xsl:output method="xml" indent="yes" encoding="UTF-8"/>

    <xsl:param name="csv-uri" as="xs:string"/>
    <xsl:param name="region" as="xs:string" select="'Basel'"/>
    <xsl:param name="timezone" as="xs:string" select="'Europe/Zurich'"/>
    <xsl:param name="unit" as="xs:string" select="'min'"/>
    <xsl:param name="resolution" as="xs:string" select="'PT1H'"/>

    <xsl:function name="f:to-iso" as="xs:string">
        <xsl:param name="dt" as="xs:string"/>
        <xsl:sequence select="replace(normalize-space($dt), ' ', 'T')"/>
    </xsl:function>

    <xsl:function name="f:month" as="xs:string">
        <xsl:param name="iso" as="xs:string"/>
        <xsl:sequence select="substring($iso, 1, 7)"/>
    </xsl:function>

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
                <xsl:variable name="first" select="normalize-space($cols[1])"/>
                <xsl:variable name="second" select="normalize-space($cols[2])"/>

                <!-- Case 1: normal comma CSV: timestamp,sunshine -->
                <xsl:choose>
                    <xsl:when test="$second != ''">
                        <r dt="{f:to-iso($first)}"
                           value="{format-number(number($second), '0.##')}"/>
                    </xsl:when>

                    <!-- Case 2: semicolon packed into first field: timestamp;sunshine -->
                    <xsl:when test="contains($first, ';')">
                        <xsl:variable name="parts" select="tokenize($first, ';')"/>
                        <r dt="{f:to-iso($parts[1])}"
                           value="{format-number(number($parts[2]), '0.##')}"/>
                    </xsl:when>

                    <!-- Otherwise skip bad rows -->
                    <xsl:otherwise/>
                </xsl:choose>
            </xsl:for-each>
        </xsl:variable>

        <xsl:variable name="month" select="f:month(($rows/@dt)[1])"/>

        <sunshine>
            <xsl:attribute name="month" select="$month"/>
            <xsl:attribute name="timezone" select="$timezone"/>
            <xsl:attribute name="unit" select="$unit"/>

            <region>
                <xsl:attribute name="id" select="$region"/>
                <xsl:attribute name="name" select="$region"/>

                <series>
                    <xsl:attribute name="resolution" select="$resolution"/>

                    <xsl:for-each select="$rows">
                        <xsl:sort select="@dt"/>
                        <value>
                            <xsl:attribute name="datetime" select="@dt"/>
                            <xsl:value-of select="@value"/>
                        </value>
                    </xsl:for-each>

                </series>
            </region>
        </sunshine>
    </xsl:template>

</xsl:stylesheet>
