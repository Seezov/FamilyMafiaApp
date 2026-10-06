// Renders public/og.png (1200×630) for link previews from public/logo.svg
// (run scripts/make-icons.mjs first). Run manually: node scripts/make-og.mjs
import fs from 'node:fs';
import { Resvg } from '@resvg/resvg-js';

const logo = fs.readFileSync(new URL('../public/logo.svg', import.meta.url), 'utf8')
  .replace('<svg ', '<svg x="120" y="135" width="300" height="360" ');
const svg = `
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <rect width="1200" height="630" fill="#0A0A0A"/>
  ${logo}
  <text x="440" y="270" font-family="Arial Black, Arial, sans-serif" font-weight="900" font-size="88" fill="#F2F2F2">FAMILY</text>
  <text x="440" y="368" font-family="Arial Black, Arial, sans-serif" font-weight="900" font-size="88" fill="#F2F2F2">MAFIA CLUB</text>
  <text x="444" y="430" font-family="Arial, sans-serif" font-size="32" fill="#8C8C8C">Statistics · seasons · players · records</text>
</svg>`;
const png = new Resvg(svg, { font: { loadSystemFonts: true } }).render().asPng();
fs.writeFileSync(new URL('../public/og.png', import.meta.url), png);
console.log(`og.png: ${png.length} bytes`);
