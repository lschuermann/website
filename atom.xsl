<?xml version='1.0' encoding='UTF-8'?>
<xsl:stylesheet
    version='1.0'
    xmlns:xsl='http://www.w3.org/1999/XSL/Transform'
    xmlns:str="http://exslt.org/strings">
  <xsl:output method="xml" version="1.0" encoding="utf-8" indent="yes"/>
  <xsl:template match="/">
    <feed xmlns='http://www.w3.org/2005/Atom'>
      <title>
        <xsl:value-of select="/expr/attrs/attr[@name='title']/string/@value" />
      </title>
      <id>
        <xsl:value-of select="/expr/attrs/attr[@name='feedUrl']/string/@value" />
      </id>
      <link rel="self" type="application/atom+xml">
	<xsl:attribute name="href">
          <xsl:value-of select="/expr/attrs/attr[@name='feedUrl']/string/@value" />
        </xsl:attribute>
      </link>
      <link rel="alternate" type="text/html">
	<xsl:attribute name="href">
          <xsl:value-of select="/expr/attrs/attr[@name='alternateUrl']/string/@value" />
        </xsl:attribute>
      </link>
      <updated><xsl:value-of select="/expr/attrs/attr[@name='updated']/string/@value" /></updated>
      <xsl:for-each select="/expr/attrs/attr[@name='posts']/list/attrs">
        <entry>
          <title><xsl:value-of select="attr[@name = 'title']/string/@value" /></title>
          <link>
            <xsl:attribute name="href">
              <xsl:value-of select="attr[@name = 'url']/string/@value" />
            </xsl:attribute>
            <xsl:attribute name="title">
              <xsl:value-of select="attr[@name = 'title']/string/@value" />
            </xsl:attribute>
          </link>
          <published><xsl:value-of select="attr[@name = 'published']/string/@value" /></published>
	  <updated><xsl:value-of select="attr[@name = 'published']/string/@value" /></updated>
          <id><xsl:value-of select="attr[@name = 'url']/string/@value" /></id>
          <xsl:for-each select="attr[@name = 'authors']/list">
            <author><name><xsl:value-of select="string/@value" /></name></author>
          </xsl:for-each>
          <xsl:if test="attr[@name = 'abstract']/string">
            <summary type="html">
	      <xsl:attribute name="xml:base">
		<xsl:value-of select="attr[@name = 'url']/string/@value" />
              </xsl:attribute>
	      <xsl:text disable-output-escaping="yes">&lt;![CDATA[</xsl:text>
	      <xsl:comment>
		<!-- The next "select" query is a combination of https://stackoverflow.com/a/59815107
		     and https://stackoverflow.com/a/223773 to escape ]]> tokens -->
	      </xsl:comment>
	      <xsl:value-of
		  select="str:replace(attr[@name = 'abstract']/string/@value, ']]>', ']]]]&gt;&lt;![CDATA[>')"
		  disable-output-escaping="yes" />
	      <xsl:text disable-output-escaping="yes">]]&gt;</xsl:text>
	    </summary>
          </xsl:if>
	  <xsl:if test="attr[@name = 'content']/string">
            <content type="html">
	      <xsl:attribute name="xml:base">
		<xsl:value-of select="attr[@name = 'url']/string/@value" />
              </xsl:attribute>
	      <xsl:text disable-output-escaping="yes">&lt;![CDATA[</xsl:text>
	      <xsl:comment>
		<!-- The next "select" query is a combination of https://stackoverflow.com/a/59815107
		     and https://stackoverflow.com/a/223773 to escape ]]> tokens -->
	      </xsl:comment>
	      <xsl:value-of
		  select="str:replace(attr[@name = 'content']/string/@value, ']]>', ']]]]&gt;&lt;![CDATA[>')"
		  disable-output-escaping="yes" />
	      <xsl:text disable-output-escaping="yes">]]&gt;</xsl:text>
	    </content>
          </xsl:if>
        </entry>
      </xsl:for-each>
    </feed>
  </xsl:template>
</xsl:stylesheet>
