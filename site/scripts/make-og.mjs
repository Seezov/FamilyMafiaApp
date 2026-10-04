// Renders public/og.png (1200×630) for link previews. Run manually: node scripts/make-og.mjs
import fs from 'node:fs';
import { Resvg } from '@resvg/resvg-js';

const icon = fs.readFileSync(new URL('../../assets/app_icon.png', import.meta.url)).toString('base64');
const svg = `
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <rect width="1200" height="630" fill="#0B0D10"/>
  <rect x="0" y="0" width="1200" height="8" fill="#E5484D"/>
  <image href="data:image/png;base64,${icon}" x="96" y="171" width="288" height="288"/>
  <text x="440" y="300" font-family="Arial Black, Arial, sans-serif" font-weight="900" font-size="92" fill="#E6E8EB">FAMILY</text>
  <text x="440" y="400" font-family="Arial Black, Arial, sans-serif" font-weight="900" font-size="92" fill="#E5484D">MAFIA</text>
  <text x="444" y="460" font-family="Arial, sans-serif" font-size="32" fill="#8B95A1">Club statistics · seasons · players · records</text>
</svg>`;
const png = new Resvg(svg, { font: { loadSystemFonts: true } }).render().asPng();
fs.writeFileSync(new URL('../public/og.png', import.meta.url), png);
console.log(`og.png: ${png.length} bytes`);
