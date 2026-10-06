// Renders public/favicon.svg and public/logo.svg from the app's Android launcher
// vector (android/app/src/main/res/drawable/ic_launcher_foreground.xml), so the
// site uses the same F monogram as the app. Run manually: node scripts/make-icons.mjs
import fs from 'node:fs';
import { Resvg } from '@resvg/resvg-js';

const xml = fs.readFileSync(
  new URL('../../android/app/src/main/res/drawable/ic_launcher_foreground.xml', import.meta.url), 'utf8');
const attr = (s, name) => s.match(new RegExp(`android:${name}="([^"]*)"`))?.[1];
const g = xml.match(/<group([^>]*)>/)[1];
// Android draws the 338×401 viewport into a square 108dp box, which undoes the
// group's uneven scaleX/scaleY; stretch x by the same ratio or the F comes out narrow.
const k = attr(xml, 'viewportHeight') / attr(xml, 'viewportWidth');
const transform = `translate(${attr(g, 'translateX') * k} ${attr(g, 'translateY')}) scale(${attr(g, 'scaleX') * k} ${attr(g, 'scaleY')})`;
const paths = [...xml.matchAll(/<path([^>]*)\/>/g)].map((m) => ({
  d: attr(m[1], 'pathData'),
  filled: attr(m[1], 'fillColor') === '#000000',
  stroke: attr(m[1], 'strokeColor'),
}));

// [ink] draws the letter; [cut] is the background colour (the vector's white
// stroke that breaks the outline where it crosses the filled stem).
function mark(ink, cut, strokeScale) {
  return `<g transform="${transform}">${paths.map((p) => p.filled
    ? `<path d="${p.d}" fill="${ink}"/>`
    : `<path d="${p.d}" fill="none" stroke="${p.stroke === '#ffffff' ? cut : ink}" stroke-width="${(p.stroke === '#ffffff' ? 1 : 2) * strokeScale}" stroke-linecap="round" stroke-linejoin="round"/>`).join('')}</g>`;
}

// Frame the letter by its rendered bounds: the logo with a 9-unit margin, the
// favicon as a 240-unit square tile centred on it.
const b = new Resvg(`<svg xmlns="http://www.w3.org/2000/svg">${mark('#000', '#000', 1.6)}</svg>`).getBBox();
const r = (n) => Math.round(n * 10) / 10;
const cx = r(b.x + b.width / 2 - 120), cy = r(b.y + b.height / 2 - 120);
const favicon = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${cx} ${cy} 240 240"><rect x="${cx}" y="${cy}" width="240" height="240" rx="52" fill="#fff"/>${mark('#0A0A0A', '#fff', 4)}</svg>\n`;
const logo = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${r(b.x - 9)} ${r(b.y - 9)} ${r(b.width + 18)} ${r(b.height + 18)}">${mark('#fff', '#000', 1.6)}</svg>\n`;
fs.writeFileSync(new URL('../public/favicon.svg', import.meta.url), favicon);
fs.writeFileSync(new URL('../public/logo.svg', import.meta.url), logo);
console.log('favicon.svg, logo.svg written');
