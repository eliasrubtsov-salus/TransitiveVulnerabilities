const express = require('express');
const bodyParser = require('body-parser');
const jwt = require('jsonwebtoken');
const axios = require('axios');
const ejs = require('ejs');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Set EJS as templating engine
app.set('view engine', 'ejs');

// JWT secret (intentionally weak for demo)
const JWT_SECRET = process.env.JWT_SECRET || 'weak-secret';

// Route 1: User authentication with JWT
app.post('/login', (req, res) => {
    const { username, password } = req.body;
    
    // Simplified authentication (not secure, for demo only)
    if (username && password) {
        const token = jwt.sign({ username }, JWT_SECRET, { expiresIn: '1h' });
        res.json({ token });
    } else {
        res.status(401).json({ error: 'Invalid credentials' });
    }
});

// Route 2: Verify JWT token
app.get('/protected', (req, res) => {
    const token = req.headers.authorization?.split(' ')[1];
    
    if (!token) {
        return res.status(401).json({ error: 'No token provided' });
    }
    
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        res.json({ message: 'Access granted', user: decoded });
    } catch (error) {
        res.status(401).json({ error: 'Invalid token' });
    }
});

// Route 3: Proxy endpoint using axios (vulnerable to SSRF)
app.post('/fetch-url', async (req, res) => {
    const { url } = req.body;
    
    try {
        // Vulnerable: No URL validation
        const response = await axios.get(url);
        res.json({ data: response.data });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Route 4: Template rendering with EJS (vulnerable to template injection)
app.post('/render-template', (req, res) => {
    const { template, data } = req.body;
    
    try {
        // Vulnerable: User-controlled template
        const rendered = ejs.render(template, data || {});
        res.send(rendered);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Route 5: Parse JSON with body-parser (vulnerable via qs)
app.post('/parse-data', (req, res) => {
    // The vulnerability is in the qs package used by body-parser
    // for parsing query strings and URL-encoded bodies
    res.json({
        message: 'Data parsed successfully',
        received: req.body
    });
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Start server
app.listen(PORT, () => {
    console.log(`Vulnerable app running on port ${PORT}`);
    console.log(`
Known vulnerabilities in this app:
- express@4.17.1 → has transitive vulnerabilities via qs
- body-parser@1.19.0 → depends on vulnerable qs package
- ejs@3.1.6 → CVE-2022-29078 (template injection)
- axios@0.21.1 → CVE-2021-3749 (SSRF)
- jsonwebtoken@8.5.1 → CVE-2022-23529
- webpack@4.46.0 (dev) → multiple vulnerabilities

Test your remediation agent with:
1. npm audit
2. npm ls qs (to see transitive dependency chain)
3. npm ls minimist (another common transitive vulnerability)
    `);
});

module.exports = app;
