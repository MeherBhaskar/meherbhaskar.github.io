<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:atom="http://www.w3.org/2005/Atom">
  <xsl:output method="html" version="5.0" encoding="utf-8" indent="yes"/>
  <xsl:template match="/atom:feed">
    <html lang="en">
      <head>
        <title><xsl:value-of select="atom:title"/> — RSS Feed</title>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <style>
          * { box-sizing: border-box; }
          body { margin: 0; background: #fbfaf8; color: #1b1815;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            font-size: 16px; line-height: 1.65; -webkit-font-smoothing: antialiased; }
          .wrap { max-width: 42rem; margin: 0 auto; padding: 3rem 1.25rem 4rem; }
          .kicker { text-transform: uppercase; letter-spacing: .12em; font-size: .75rem;
            font-weight: 700; color: #9a3412; margin: 0 0 .5rem; }
          h1 { font-family: Georgia, "Times New Roman", serif; font-size: 2.2rem;
            line-height: 1.15; margin: 0 0 .75rem; letter-spacing: -0.01em; }
          .desc { color: #6b6259; margin: 0 0 1.5rem; }
          .how { background: #fff; border: 1px solid #e8e2d9; border-radius: 12px;
            padding: 1rem 1.25rem; font-size: .92rem; color: #6b6259; }
          .how code { background: #f4f1ec; padding: .15em .4em; border-radius: 4px;
            font-size: .85em; word-break: break-all; }
          .how a { color: #9a3412; }
          article { background: #fff; border: 1px solid #e8e2d9; border-radius: 12px;
            padding: 1.25rem 1.5rem; margin-top: 1rem; }
          article h2 { font-family: Georgia, "Times New Roman", serif;
            font-size: 1.35rem; line-height: 1.3; margin: 0 0 .35rem; }
          article h2 a { color: #1b1815; text-decoration: none; }
          article h2 a:hover { color: #9a3412; }
          article .meta { font-size: .82rem; color: #6b6259; margin: 0 0 .5rem; }
          article p.sum { margin: 0; color: #6b6259; }
          footer { margin-top: 2.5rem; font-size: .85rem; color: #6b6259; }
          footer a { color: #9a3412; }
        </style>
      </head>
      <body>
        <div class="wrap">
          <p class="kicker">RSS Feed</p>
          <h1><xsl:value-of select="atom:title"/></h1>
          <p class="desc"><xsl:value-of select="atom:subtitle"/></p>
          <p class="how">
            This is an RSS feed, meant for feed readers, not browsers.
            Copy this URL into your reader of choice:
            <br/><code><xsl:value-of select="atom:link[@rel='self']/@href"/></code>
            <br/>Or <a href="{atom:link[@rel='alternate']/@href}">read the blog directly</a>.
          </p>
          <xsl:for-each select="atom:entry">
            <article>
              <h2><a href="{atom:link[@rel='alternate']/@href}"><xsl:value-of select="atom:title"/></a></h2>
              <p class="meta"><xsl:value-of select="substring(atom:published, 1, 10)"/></p>
              <p class="sum"><xsl:value-of select="atom:summary"/></p>
            </article>
          </xsl:for-each>
          <footer>
            <p><xsl:value-of select="atom:title"/> · <a href="{atom:link[@rel='alternate']/@href}"><xsl:value-of select="atom:link[@rel='alternate']/@href"/></a></p>
          </footer>
        </div>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
