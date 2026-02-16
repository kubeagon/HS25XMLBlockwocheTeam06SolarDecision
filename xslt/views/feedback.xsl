<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" 
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns="http://www.w3.org/1999/xhtml">
    
    <xsl:param name="success" />
    <xsl:param name="error" />
    
    <xsl:output method="xml" doctype-public="-//W3C//DTD XHTML 1.0 Strict//EN" doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd" indent="yes" encoding="UTF-8"/>
    
    <xsl:template match="/">
        <html xmlns="http://www.w3.org/1999/xhtml">
            <head>
                <title>Solar Decision - Feedback</title>
                <style>
                    .feedback-container { max-width: 800px; margin: 20px auto; padding: 20px; font-family: 'Segoe UI', sans-serif; }
                    .header-nav { margin-bottom: 20px; display: flex; justify-content: flex-start; }
                    .card { background: #fff; padding: 30px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); border: 1px solid #eee; }
                    
                    /* Success State */
                    .success-view { text-align: center; }
                    .success-icon { font-size: 60px; color: #4BB543; margin-bottom: 10px; display: block; }
                    
                    /* Buttons */
                    .btn { padding: 10px 20px; border-radius: 6px; text-decoration: none; font-weight: bold; display: inline-block; transition: 0.2s; border: none; cursor: pointer; }
                    .btn-primary { background: #ffcc00; color: #333; }
                    .btn-outline { border: 2px solid #ffcc00; color: #333; background: transparent; }
                    .btn:hover { filter: brightness(90%); }
                    
                    .form-group { margin-bottom: 15px; }
                    .form-group label { display: block; margin-bottom: 5px; font-weight: bold; }
                    .form-group input, .form-group textarea { width: 100%; padding: 10px; border: 1px solid #ccc; border-radius: 4px; box-sizing: border-box; }
                    
                    .review-item { border-bottom: 1px solid #eee; padding: 15px 0; }
                    .stars-display { color: #f39c12; font-weight: bold; }
                </style>
            </head>
            <body>
                <div class="feedback-container">
                    
                    <div class="header-nav">
                        <a href="/" class="btn btn-outline">← Zurück zum Dashboard</a>
                    </div>
                    
                    <xsl:choose>
                        <xsl:when test="$success = 'true'">
                            <div class="card success-view">
                                <span class="success-icon" style="color: #4BB543;">✔</span>
                                <h1>Vielen Dank!</h1>
                                <p>Ihr Feedback hilft uns, das Solar Decision Tool stetig weiter zu entwickeln.</p>
                                <div style="margin-top: 20px;">
                                    <a href="/feedback" class="btn btn-primary">Weiteres Feedback erstellen</a>
                                </div>
                            </div>
                        </xsl:when>
                        
                        <xsl:when test="$error = 'true'">
                            <div class="card success-view" style="border-color: #ff4d4d;">
                                <span class="success-icon" style="color: #ff4d4d;">✘</span>
                                <h1 style="color: #d93025;">Fehler bei der Validierung</h1>
                                <p>Das Feedback-Formular war ungültig und konnte nicht gespeichert werden.</p>
                                <div style="margin-top: 20px;">
                                    <a href="/feedback" class="btn btn-outline">Erneut versuchen</a>
                                </div>
                            </div>
                        </xsl:when>
                        
                        <xsl:otherwise>
                            <div class="card">
                                <h1>Hinterlasse ein Feedback</h1>
                                <form action="/submit-feedback" method="post">
                                    <div class="form-group">
                                        <label>Ihr Name</label>
                                        <input type="text" name="username" required="required" placeholder="Hans Muster"/>
                                    </div>
                                    <div class="form-group">
                                        <label>Bewertung</label>
                                        <select name="rating" style="width:100%; padding:10px;">
                                            <option value="5">★★★★★ (Sehr gut)</option>
                                            <option value="4">★★★★☆ (Gut)</option>
                                            <option value="3">★★★☆☆ (Zufriedenstellend)</option>
                                            <option value="2">★★☆☆☆ (Schlecht)</option>
                                            <option value="1">★☆☆☆☆ (Sehr schlecht)</option>
                                        </select>
                                    </div>
                                    <div class="form-group">
                                        <label>Kommentar</label>
                                        <textarea name="comment" rows="4" required="required" placeholder="Was denken Sie?"><xsl:text> </xsl:text></textarea>
                                    </div>
                                    <button type="submit" class="btn btn-primary" style="width:100%">Feedback Übermitteln</button>
                                </form>
                            </div>
                        </xsl:otherwise>
                    </xsl:choose>
                    
                    <div style="margin-top: 40px;">
                        <h2>Letze Feedbacks</h2>
                        <xsl:for-each select="feedbacks/feedback">
                            <xsl:sort select="date" order="descending" />
                            <div class="review-item">
                                <div class="stars-display">
                                    <xsl:choose>
                                        <xsl:when test="rating = 5">★★★★★</xsl:when>
                                        <xsl:when test="rating = 4">★★★★☆</xsl:when>
                                        <xsl:when test="rating = 3">★★★☆☆</xsl:when>
                                        <xsl:when test="rating = 2">★★☆☆☆</xsl:when>
                                        <xsl:otherwise>★☆☆☆☆</xsl:otherwise>
                                    </xsl:choose>
                                </div>
                                <h3 style="margin: 5px 0;"><xsl:value-of select="user"/></h3>
                                <p style="white-space: pre-line; word-wrap: break-word;">
                                    <xsl:value-of select="comment"/>
                                </p>
                                <small style="color: #999;"><xsl:value-of select="substring(date, 1, 10)"/></small>
                            </div>
                        </xsl:for-each>
                    </div>
                </div>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>