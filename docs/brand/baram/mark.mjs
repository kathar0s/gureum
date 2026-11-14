// Original Baram geometry. A vertical stem and two wind curls read as a Latin B at first glance.
// The master keeps the hand-drawn flow; the small version is separately simplified for menu size.
export const master = {
  width: 9,
  paths: [
    'M39 15C31 38 29 88 39 113',
    'M14 41C35 23 63 13 87 18C108 23 116 37 111 50C105 65 82 69 62 64C48 60 46 49 56 40C64 33 75 31 82 34',
    'M14 89C37 106 61 115 86 108C107 102 116 88 109 76C101 63 78 60 60 67C45 73 43 87 54 95C63 101 76 97 82 87',
  ],
};

export const small = {
  width: 12,
  paths: [
    'M36 16V112',
    'M36 20H67C96 20 101 58 68 59H48C58 48 70 42 81 43',
    'M36 59H70C104 59 106 108 68 108H48C60 96 72 90 83 92',
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

export function inputSourceIcon(title, size = 128) {
  const background = '<rect x="5" y="5" width="118" height="118" rx="26" fill="#14675F"/>';
  const geometry = `<g transform="translate(-7 0)">${strands(small, ['#F6F4EE'])}</g>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 128 128" role="img" aria-labelledby="title"><title id="title">${title}</title>${background}${geometry}</svg>`;
}
