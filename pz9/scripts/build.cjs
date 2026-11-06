'use strict';
const fs = require('node:fs');
fs.mkdirSync('dist', { recursive: true });
fs.writeFileSync('dist/index.html', '<h1>Hello CI</h1>\n');
console.log('Building project...');
