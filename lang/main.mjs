import { readFileSync, writeFileSync } from 'node:fs';
import { compile } from './target/js/release/build/lib/lib.js';

const source = readFileSync('./examples/function.txt', 'utf8');
const prog = compile(source, true);

if (prog.$tag === 1) {
    writeFileSync('out.bin', new Uint16Array(prog._0), 'binary');
} else {
    console.error(prog._0._0);
}
