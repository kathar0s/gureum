// Original Baram geometry. Three independent wind strokes read as wind first; the stacked
// right-hand curls and aligned left terminals suggest a Latin B only on a second look.
// The master keeps the open flow; the small version is separately simplified for menu size.
export const master = {
  width: 9,
  paths: [
    'M18 38H42C53 38 60 31 60 22C60 14 55 11 50 11C43 11 39 15 38 21',
    'M16 62H82C103 62 114 50 114 34C114 19 104 11 91 11C79 11 70 17 68 27',
    'M16 85H81C101 85 111 95 111 107C111 118 101 123 91 123C79 123 70 117 68 108',
  ],
};

export const small = {
  width: 11,
  paths: [
    'M18 38H43C52 38 57 32 57 25C57 19 53 17 49 17C44 17 41 20 40 24',
    'M16 61H81C99 61 108 51 108 38C108 25 100 18 90 18C80 18 73 23 71 31',
    'M16 84H80C97 84 105 93 105 104C105 114 97 119 89 119C79 119 73 114 71 106',
  ],
};

export function strands(spec, colors = ['currentColor']) {
  const attrs = `fill="none" stroke-width="${spec.width}" stroke-linecap="round" stroke-linejoin="round"`;
  return spec.paths
    .map((path, index) => `<path d="${path}" ${attrs} stroke="${colors[index] || colors[0]}"/>`)
    .join('');
}

export function symbols() {
  return `<symbol id="wind-b" viewBox="0 0 128 128">${strands(master)}</symbol>
  <symbol id="wind-b-small" viewBox="0 0 128 128">${strands(small)}</symbol>
  <symbol id="wind-b-duo" viewBox="0 0 128 128">${strands(master, ['#F6F4EE', '#F6F4EE', '#D9A15F'])}</symbol>`;
}

export function standalone(id, title, options = {}) {
  const spec = id === 'small' ? small : master;
  const color = options.color || (options.background ? '#F6F4EE' : '#14675F');
  const bg = options.background ? `<rect width="128" height="128" fill="${options.background}"/>` : '';
  const colors = options.twoTone ? ['#F6F4EE', '#F6F4EE', '#D9A15F'] : [color];
  const geometry = strands(spec, colors);
  const content = options.background ? `<g transform="translate(16 16) scale(.75)">${geometry}</g>` : geometry;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${options.size || 128}" height="${options.size || 128}" viewBox="0 0 128 128" role="img" aria-labelledby="title"><title id="title">${title}</title>${bg}${content}</svg>`;
}

export function inputSourceIcon(title, options = {}) {
  const label = options.label || '';
  const backgroundColor = options.background || '#14675F';
  const frameWidth = 192;
  const background = `<rect x="5" y="5" width="${frameWidth - 10}" height="118" rx="26" fill="${backgroundColor}"/>`;
  const geometry = `<g transform="translate(9 9) scale(.86)">${strands(small, ['#F6F4EE'])}</g>`;
  const labelLength = Array.from(label).length;
  const fontSize = labelLength >= 3 ? 38 : labelLength === 2 ? 46 : 50;
  const letterSpacing = labelLength >= 3 ? -1.5 : label === 'QW' ? -1 : -2;
  const labelBaseline = labelLength >= 3 ? 78 : labelLength === 2 ? 80 : 82;
  const horizontalScale = label === '390' ? .93 : label === 'ROM' ? .66 : label === 'QW' ? .72 : 1;
  const labelPosition = horizontalScale === 1
    ? 'x="149"'
    : `x="0" transform="translate(149 0) scale(${horizontalScale} 1)"`;
  const layout = label
    ? `<text ${labelPosition} y="${labelBaseline}" fill="#F6F4EE" font-family="Helvetica Neue, Arial, sans-serif" font-size="${fontSize}" font-weight="800" letter-spacing="${letterSpacing}" text-anchor="middle">${label}</text>`
    : '';
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${frameWidth}" height="128" viewBox="0 0 ${frameWidth} 128" role="img" aria-labelledby="title"><title id="title">${title}</title>${background}${geometry}${layout}</svg>`;
}
