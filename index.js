const express = require('express')
const path = require('path')
const fs = require('fs')
const os = require('os')
const libxmljs = require('libxmljs2')
const app = express()
const { execFile } = require('child_process')

const schemaCache = new Map();
const PDF_RENDERER = (process.env.PDF_RENDERER || 'local').trim().toLowerCase()
const FOP_REMOTE_URL = (process.env.FOP_REMOTE_URL || 'https://fop.xml.hslu-edu.ch/fop.php').trim()

app.use(express.static(__dirname));
app.use(express.text());
app.use(express.urlencoded({ extended: false }));

function runCommand(command, args, options = {}) {
    return new Promise((resolve, reject) => {
        execFile(command, args, { maxBuffer: 50 * 1024 * 1024, ...options }, (err, stdout, stderr) => {
            if (err) {
                const message = (stderr || err.message || '').trim()
                reject(new Error(`${command} failed: ${message}`))
                return
            }
            resolve({ stdout, stderr })
        })
    })
}

async function generateFoReport(dt) {
    const saxonJar = path.resolve('tools', 'saxon-he.jar')
    const xmlPath = path.resolve('data', 'recommendation.xml')
    const xslPath = path.resolve('xslt', 'fo', 'report.fo.xsl')
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'solardecision-'))
    const foPath = path.join(tempDir, 'report.fo')
    const dtParam = (dt || '').trim()

    const saxonArgs = [
        '-jar', saxonJar,
        `-s:${xmlPath}`,
        `-xsl:${xslPath}`,
        `-o:${foPath}`,
        `dt=${dtParam}`
    ]

    try {
        await runCommand('java', saxonArgs)
        return fs.readFileSync(foPath)
    } finally {
        fs.rmSync(tempDir, { recursive: true, force: true })
    }
}

async function renderPdfLocal(foBuffer) {
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'solardecision-'))
    const foPath = path.join(tempDir, 'report.fo')
    const pdfPath = path.join(tempDir, 'report.pdf')

    try {
        fs.writeFileSync(foPath, foBuffer)
        await runCommand('fop', ['-fo', foPath, '-pdf', pdfPath])
        return fs.readFileSync(pdfPath)
    } finally {
        fs.rmSync(tempDir, { recursive: true, force: true })
    }
}

async function renderPdfRemote(foBuffer) {
    const response = await fetch(FOP_REMOTE_URL, {
        method: 'POST',
        body: foBuffer,
        headers: {
            'Content-Type': 'application/xml'
        }
    })

    if (!response.ok) {
        const responseText = await response.text()
        throw new Error(`Remote FOP failed (${response.status}): ${responseText}`)
    }

    const arrayBuffer = await response.arrayBuffer()
    return Buffer.from(arrayBuffer)
}

async function generatePdfReport(dt) {
    const foBuffer = await generateFoReport(dt)
    if (PDF_RENDERER === 'remote') {
        return renderPdfRemote(foBuffer)
    }
    return renderPdfLocal(foBuffer)
}

app.get('/', (req, res) => {
    const dt = (req.query.dt || '').trim()

    const saxonJar = path.resolve('tools', 'saxon-he.jar')
    const xmlPath = path.resolve('data', 'recommendation.xml')
    const xslPath = path.resolve('dashboard.xsl')

    const args = [
        '-jar', saxonJar,
        `-s:${xmlPath}`,
        `-xsl:${xslPath}`,
        dt ? `dt=${dt}` : null
    ].filter(Boolean)

    execFile('java', args, { maxBuffer: 50 * 1024 * 1024 }, (err, stdout, stderr) => {
        if (err) {
            res.status(500).type('text/plain').send(stderr || err.message)
            return
        }
        res.status(200).type('application/xhtml+xml').send(stdout)
    })
})

app.get('/report.pdf', async (req, res) => {
    try {
        const dt = (req.query.dt || '').trim()
        const pdfBuffer = await generatePdfReport(dt)
        const safeDt = dt ? dt.replace(/[^0-9T-]/g, '_') : 'latest'

        res.setHeader('Content-Type', 'application/pdf')
        res.setHeader('Content-Disposition', `attachment; filename=\"solar-report-${safeDt}.pdf\"`)
        res.status(200).send(pdfBuffer)
    } catch (err) {
        console.error('PDF generation failed:', err.message)
        res.status(500).type('text/plain').send(err.message)
    }
})

app.post('/convertToPdf', async (req, res) => {
    try {
        const dt = typeof req.body === 'string'
            ? req.body.trim()
            : ((req.body && req.body.dt) ? String(req.body.dt).trim() : '')
        const pdfBuffer = await generatePdfReport(dt)
        res.setHeader('Content-Type', 'application/pdf')
        res.status(200).send(pdfBuffer)
    } catch (err) {
        console.error('PDF generation failed:', err.message)
        res.status(500).type('text/plain').send(err.message)
    }
})

app.post('/updateData', (req, res) => {
    const dataToUpdate = req.body
    // read database xml
    const databasePath = path.resolve('data', 'database.xml');
    const databaseXml = fs.readFileSync(databasePath, 'utf-8')
    const xmlDocDatabase = libxmljs.parseXml(databaseXml)
    // select node to update
    const plantStatistics = xmlDocDatabase.get(`//plant[name="${dataToUpdate.plant}"]/statistics`);
    // create new node with attribute etc.
    plantStatistics.node('price', dataToUpdate.price).attr('date', dataToUpdate.date)
    console.log(xmlDocDatabase.toString())

    // validate new database against schema
    const valid = validateDatabase(xmlDocDatabase)
    if (!valid) {
        res.status(400).send('Invalid XML')
        return
    }
    // write new database.xml
    fs.writeFileSync(databasePath, xmlDocDatabase.toString(), 'utf-8')
    res.sendStatus(200)
})

app.get('/feedback', (req, res) => {
    const saxonJar = path.resolve('tools', 'saxon-he.jar')
    const xmlPath = path.resolve('data', 'feedback.xml')
    const xslPath = path.resolve('xslt', 'views', 'feedback.xsl')

    const success = req.query.success || 'false'
    const error = req.query.error || 'false' 

    const args = [
        '-jar', saxonJar,
        `-s:${xmlPath}`,
        `-xsl:${xslPath}`,
        `success=${success}`,
        `error=${error}`
    ]

    execFile('java', args, { maxBuffer: 50 * 1024 * 1024 }, (err, stdout, stderr) => {
        if (err) {
            console.error("Java Saxon Error:", stderr)
            res.status(500).type('text/plain').send("Transformation Error: " + (stderr || err.message))
            return;
        }
        // Send the output as XHTML/HTML
        res.status(200).type('text/html').send(stdout)
    })
})

app.post('/submit-feedback', (req, res) => {
    const { username, rating, comment } = req.body
    const xmlPath = path.resolve('data', 'feedback.xml')

    // Keep your original sanitization but trim for XSD compatibility
    const cleanUser = (username || 'Anonymous').trim() 
    const cleanComment = (comment || '').trim().replace(/</g, "&lt;").replace(/>/g, "&gt;")
    const cleanRating = (rating || '5').trim()

    const newEntrySnippet = `
    <feedback>
        <user>${cleanUser}</user>
        <rating>${cleanRating}</rating>
        <comment>${cleanComment}</comment>
        <date>${new Date().toISOString()}</date>
    </feedback>
</feedbacks>`;

    fs.readFile(xmlPath, 'utf8', (err, data) => {
        if (err) return res.redirect('/feedback?error=true')
        
        const updatedXmlString = data.replace('</feedbacks>', newEntrySnippet);
        
        try {
            const xmlDoc = libxmljs.parseXml(updatedXmlString)

            if (validateFeedbackForm(xmlDoc)) {
                fs.writeFileSync(xmlPath, updatedXmlString, 'utf8')
                res.redirect('/feedback?success=true')
            } else {
                res.redirect('/feedback?error=true')
            }
        } catch (e) {
            console.error("XML Syntax Error:", e.message)
            res.redirect('/feedback?error=true')
        }
    })
})

function validate(xmlDoc, xmlSchema) {
    const xmlDocDatabaseXsd = libxmljs.parseXml(xmlSchema)
    return xmlDoc.validate(xmlDocDatabaseXsd)
}

function validatePrices(xmlDoc) {
    const pricesSchema = fs.readFileSync(path.resolve('schema', 'prices.xsd'), 'utf-8')
    return validate(xmlDoc, pricesSchema)
}

function validateUV(xmlDoc) {
    const uvSchema = fs.readFileSync(path.resolve('schema', 'sunshine.xsd'), 'utf-8')
    return validate(xmlDoc, uvSchema)
}

function validateRecommendation(xmlDoc) {
    const recommendationSchema = fs.readFileSync(path.resolve('schema', 'recommendation.xsd'), 'utf-8')
    return validate(xmlDoc, recommendationSchema)
}

function validateFeedbackForm(xmlDoc) {
    try {
        const schemaPath = path.resolve('schema', 'feedback.xsd')
        const schemaXml = fs.readFileSync(schemaPath, 'utf-8')
        const schemaDoc = libxmljs.parseXml(schemaXml)
        
        const isValid = xmlDoc.validate(schemaDoc)
        if (!isValid) {
            console.error("Validation Errors:", xmlDoc.validationErrors.map(e => e.message))
        }
        return isValid
    } catch (err) {
        console.error("Schema or Parsing Error:", err.message)
        return false
    }
}

app.listen(3000, () => {
    console.log('listen on port', 3000)
    console.log('pdf renderer:', PDF_RENDERER === 'remote' ? `remote (${FOP_REMOTE_URL})` : 'local')
})
