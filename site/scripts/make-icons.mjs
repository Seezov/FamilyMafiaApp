// Renders public/favicon.svg and public/logo.svg from the app's Android launcher
// vector (android/app/src/main/res/drawable/ic_launcher_foreground.xml), so the
// site uses the same F monogram as the app. Run manually: node scripts/make-icons.mjs
import fs from 'node:fs';

const xml = fs.readFileSync(
  new URL('../../android/app/src/main/res/drawable/ic_launcher_foreground.xml', import.meta.url), 'utf8');
const attr = (s, name) => s.match(new RegExp(`android:${name}="([^"]*)"`))?.[1];
const g = xml.match(/<group([^>]*)>/)[1];
const transform = `translate(${attr(g, 'translateX')} ${attr(g, 'translateY')}) scale(${attr(g, 'scaleX')} ${attr(g, 'scaleY')})`;
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

// Letter bounds in the vector's viewport ≈ x 103–235, y 108–293.
const favicon = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="49 80 240 240"><rect x="49" y="80" width="240" height="240" rx="52" fill="#000"/>${mark('#fff', '#000', 4)}</svg>\n`;
const logo = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="94 100 150 202">${mark('#fff', '#000', 1.6)}</svg>\n`;
fs.writeFileSync(new URL('../public/favicon.svg', import.meta.url), favicon);
fs.writeFileSync(new URL('../public/logo.svg', import.meta.url), logo);
console.log('favicon.svg, logo.svg written');
