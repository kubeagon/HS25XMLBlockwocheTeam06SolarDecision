const fs = require("fs/promises");
const path = require("path");
const libxmljs = require("libxmljs");

const schemaCache = new Map(); // schemaPath -> parsed XSD doc

function xpathLiteral(value) {
    // safe XPath string literal for values that may contain quotes
    if (!value.includes("'")) return `'${value}'`;
    if (!value.includes('"')) return `"${value}"`;
    // concat('a', "'", 'b')
    return "concat(" + value.split("'").map(part => `'${part}'`).join(", \"'\", ") + ")";
}

async function loadSchema(schemaPath) {
    const abs = path.resolve(schemaPath);
    if (schemaCache.has(abs)) return schemaCache.get(abs);

    const xsdString = await fs.readFile(abs, "utf-8");
    const xsdDoc = libxmljs.parseXml(xsdString);
    schemaCache.set(abs, xsdDoc);
    return xsdDoc;
}

async function readXml(xmlPath) {
    const abs = path.resolve(xmlPath);
    const xmlString = await fs.readFile(abs, "utf-8");
    return libxmljs.parseXml(xmlString);
}

async function writeXmlAtomic(xmlPath, xmlDoc) {
    const abs = path.resolve(xmlPath);
    const tmp = abs + ".tmp";
    await fs.writeFile(tmp, xmlDoc.toString(), "utf-8");
    await fs.rename(tmp, abs);
}

async function validateXml(xmlDoc, schemaPath) {
    const xsdDoc = await loadSchema(schemaPath);
    const ok = xmlDoc.validate(xsdDoc);
    return { ok, errors: xmlDoc.validationErrors || [] };
}

async function updateXml({ xmlPath, schemaPath, mutator }) {
    const xmlDoc = await readXml(xmlPath);

    // apply change(s)
    await mutator(xmlDoc);

    // validate after change
    const { ok, errors } = await validateXml(xmlDoc, schemaPath);
    if (!ok) {
        const msg = errors.map(e => e.message.trim()).join("; ");
        const err = new Error("Invalid XML: " + msg);
        err.status = 400;
        throw err;
    }

    // persist
    await writeXmlAtomic(xmlPath, xmlDoc);
    return xmlDoc;
}

module.exports = {
    xpathLiteral,
    updateXml,
};
