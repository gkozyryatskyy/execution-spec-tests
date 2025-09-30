#!/usr/bin/env node

const fs = require('fs');

function getTests() {
    let tests = {};
    const files = process.argv.slice(2);
    for (const file of files) {
        const input = fs.readFileSync(file, 'utf-8').trim();
        const match = /data-jsonblob="(.*)"/m.exec(input);
        if (match !== null) {
            const text = match[1].replaceAll('&#34;', '"');
            const json = JSON.parse(text);
            tests = { ...tests, ...json.tests };
        }
    }
    return tests;
}

function main() {
    const tests = getTests();
    // console.log(tests);
    console.log(JSON.stringify(tests, null, 2));
}

main();