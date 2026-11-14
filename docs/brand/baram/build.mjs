import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';
import { inputSourceIcon, standalone, symbols } from './mark.mjs';

const root = dirname(fileURLToPath(import.meta.url));
const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const output = join(root, 'brand-sheet');
const assets = join(root, 'assets');
mkdirSync(output, { recursive: true });
mkdirSync(assets, { recursive: true });

for (const appearance of ['light', 'dark']) {
  const name = `preferences-input-${appearance}.png`;
  const destination = join(assets, name);
  if (!existsSync(destination) || process.argv.includes('--refresh-screenshots')) {
    const source = `/tmp/gureum-preferences-after/${name}`;
    if (!existsSync(source)) throw new Error(`Missing verified screenshot: ${source}`);
    copyFileSync(source, destination);
  }
}
const pdf = join(output, 'baram-brand-sheet.pdf');
const profile = mkdtempSync(join(tmpdir(), 'baram-brand-chrome.'));
for (const [id, name, options] of [
  ['master', 'baram-mark-master', {}],
  ['small', 'baram-mark-small', {}],
  ['master', 'baram-app-icon-concept', { background: '#14675F', size: 1024 }],
]) {
  const svg = join(assets, `${name}.svg`);
  writeFileSync(svg, standalone(id, `바람 궤적 B ${name}`, options));
  for (const size of name.includes('app-icon') ? [128, 256, 512, 1024] : [16, 32, 128]) {
    execFileSync('rsvg-convert', ['-w', `${size}`, '-h', `${size}`, svg, '-o', join(assets, `${name}-${size}.png`)]);
  }
}
const smallAppIconSVG = join(assets, 'baram-app-icon-concept-small.svg');
writeFileSync(smallAppIconSVG, standalone(
  'small', '바람 앱 아이콘 작은 크기 보정', { background: '#14675F', size: 128 }));
for (const size of [16, 32, 64]) {
  execFileSync('rsvg-convert', [
    '-w', `${size}`, '-h', `${size}`, smallAppIconSVG,
    '-o', join(assets, `baram-app-icon-concept-${size}.png`),
  ]);
}
const appIconAsset = join(root, '../../../OSX/Assets.xcassets/BaramAppIcon.appiconset');
for (const [filename, size] of [
  ['icon_16x16.png', 16], ['icon_16x16@2x.png', 32],
  ['icon_32x32.png', 32], ['icon_32x32@2x.png', 64],
  ['icon_128x128.png', 128], ['icon_128x128@2x.png', 256],
  ['icon_256x256.png', 256], ['icon_256x256@2x.png', 512],
  ['icon_512x512.png', 512], ['icon_512x512@2x.png', 1024],
]) {
  copyFileSync(join(assets, `baram-app-icon-concept-${size}.png`), join(appIconAsset, filename));
}
const inputSourceVariants = [
  { asset: 'baram', suffix: '', title: '한글 일반', label: '', background: '#14675F' },
  { asset: 'baram2', suffix: '-2', title: '두벌식', label: '2', background: '#14675F' },
  { asset: 'baram3', suffix: '-3', title: '세벌식', label: '3', background: '#14675F' },
  { asset: 'baram3f', suffix: '-3f', title: '세벌식 최종', label: '3F', background: '#14675F' },
  { asset: 'baram390', suffix: '-390', title: '세벌식 390', label: '390', background: '#14675F' },
  { asset: 'baramrom', suffix: '-rom', title: '한글 로마자', label: 'ROM', background: '#14675F' },
  { asset: 'barameng', suffix: '-english', title: '영문 일반', label: '', background: '#7B4A24' },
  { asset: 'baramqw', suffix: '-qw', title: '쿼티', label: 'QW', background: '#7B4A24' },
];
const inputSourceContents = asset => JSON.stringify({
  images: [
    { idiom: 'universal', filename: `${asset}.png`, scale: '1x' },
    { idiom: 'universal', filename: `${asset}@2x.png`, scale: '2x' },
    { idiom: 'universal', scale: '3x' },
  ],
  info: { version: 1, author: 'xcode' },
}, null, 2) + '\n';
const directInputSourceAssets = join(root, '../../../OSX/InputSourceIcons');
mkdirSync(directInputSourceAssets, { recursive: true });
for (const variant of inputSourceVariants) {
  const base = `baram-input-source-icon${variant.suffix}`;
  const svg = join(assets, `${base}.svg`);
  writeFileSync(svg, inputSourceIcon(`바람 ${variant.title} 입력 소스 아이콘`, variant));
  for (const [width, height, suffix] of [[22, 16, '16'], [44, 32, '32'], [176, 128, 'preview']]) {
    execFileSync('rsvg-convert', [
      '-w', `${width}`, '-h', `${height}`, svg,
      '-o', join(assets, `${base}-${suffix}.png`),
    ]);
  }
  const assetDirectory = join(root, `../../../OSX/Assets.xcassets/${variant.asset}.imageset`);
  mkdirSync(assetDirectory, { recursive: true });
  copyFileSync(join(assets, `${base}-16.png`), join(assetDirectory, `${variant.asset}.png`));
  copyFileSync(join(assets, `${base}-32.png`), join(assetDirectory, `${variant.asset}@2x.png`));
  writeFileSync(join(assetDirectory, 'Contents.json'), inputSourceContents(variant.asset));
  copyFileSync(join(assets, `${base}-16.png`), join(directInputSourceAssets, `${variant.asset}.png`));
  copyFileSync(join(assets, `${base}-32.png`), join(directInputSourceAssets, `${variant.asset}@2x.png`));
}
const prepared = readFileSync(join(root, 'sheet.html'), 'utf8')
  .replace('{{MARK_SYMBOLS}}', symbols())
  .replace('href="tokens.css"', 'href="../tokens.css"')
  .replaceAll('src="assets/', 'src="../assets/');
const printFile = join(output, 'print.html');
writeFileSync(printFile, prepared);
execFileSync(chrome, [
  '--headless=new', '--no-pdf-header-footer', '--disable-gpu',
  `--user-data-dir=${profile}`, '--virtual-time-budget=3000',
  `--print-to-pdf=${pdf}`, pathToFileURL(printFile).href,
], { stdio: 'pipe' });
const info = execFileSync('pdfinfo', [pdf], { encoding: 'utf8' });
if (!/^Pages:\s+8$/m.test(info) || !/1200 x 750 pts/.test(info)) {
  throw new Error(`Unexpected PDF shape:\n${info}`);
}
execFileSync('pdftoppm', ['-png', '-r', '72', pdf, join(output, 'page')], { stdio: 'pipe' });
const rows = [16, 18, 32, 128].map(size => `<tr><th>${size} px</th>${['wind-b', 'wind-b-small', 'bitcoin-b', 'plain-latin-b', 'plain-b'].map(id => `<td><svg width="${size}" height="${size}" aria-label="${id} ${size}px"><use href="#${id}"/></svg></td>`).join('')}</tr>`).join('\n');
const recognition = readFileSync(join(root, 'recognition.html'), 'utf8')
  .replace('{{MARK_SYMBOLS}}', symbols())
  .replace('{{RECOGNITION_ROWS}}', rows)
  .replace('href="tokens.css"', 'href="../tokens.css"');
const recognitionFile = join(output, 'recognition.rendered.html');
writeFileSync(recognitionFile, recognition);
execFileSync(chrome, [
  '--headless=new', '--disable-gpu', `--user-data-dir=${profile}`, '--hide-scrollbars',
  '--force-device-scale-factor=1', '--window-size=1600,1100', '--virtual-time-budget=2000',
  `--screenshot=${join(output, 'recognition.png')}`, pathToFileURL(recognitionFile).href,
], { stdio: 'pipe' });
console.log(info.match(/^Pages:.*$/m)?.[0]);
console.log(info.match(/^Page size:.*$/m)?.[0]);
console.log(pdf);

if (process.argv.includes('--sync-obsidian')) {
  const vault = '/Users/nexus/Obsidian/kathar0s/Resources/brand_assets/baram';
  if (!existsSync(join(vault, 'README.md'))) throw new Error('Create the reviewed vault README first.');
  for (const name of ['baram-brand-sheet.pdf', 'recognition.png', ...Array.from({ length: 8 }, (_, i) => `page-${i + 1}.png`)]) {
    copyFileSync(join(output, name), join(vault, name));
  }
  console.log(`Synced named review artifacts to ${vault}`);
}
