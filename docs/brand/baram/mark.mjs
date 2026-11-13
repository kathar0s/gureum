// Original Baram geometry. Coordinates and optical variants are defined here only.
export const master = {
  width: 10,
  main: 'M14 32H25C35 32 40 39 40 49V92H77C99 92 99 59 77 59H40',
  upper: 'M14 12H59C72 12 77 21 77 34V59',
  exit: 'M77 92C94 92 105 92 115 82',
};

export const small = {
  width: 12,
  main: 'M20 32H26C34 32 38 39 38 47V96H78C101 96 101 58 78 58H38',
  upper: 'M20 12H60C74 12 78 22 78 35V58',
  exit: 'M78 96H108',
};

export function strands(spec, colors = ['currentColor', 'currentColor']) {
  const attrs = `fill="none" stroke-width="${spec.width}" stroke-linecap="round" stroke-linejoin="round"`;
  return `<path d="${spec.main}" ${attrs} stroke="${colors[0]}"/><path d="${spec.upper}" ${attrs} stroke="${colors[1]}"/><path d="${spec.exit}" ${attrs} stroke="${colors[0]}"/>`;
}

export function symbols() {
  return `<symbol id="wind-b" viewBox="0 0 128 128">${strands(master)}</symbol>
  <symbol id="wind-b-small" viewBox="0 0 128 128">${strands(small)}</symbol>
  <symbol id="wind-b-duo" viewBox="0 0 128 128">${strands(master, ['#F6F4EE', '#D9A15F'])}</symbol>
  <symbol id="wind-b-negative" viewBox="0 0 128 128"><path d="M12 12H61C79 12 85 23 85 39V51C113 55 111 100 81 100H35V48C35 42 30 40 24 40H12V28H26C41 28 47 35 47 48V87H80C95 87 95 64 80 64H47V51H72V39C72 29 69 25 60 25H12Z" fill="currentColor"/><path d="M80 94H113" fill="none" stroke="currentColor" stroke-width="12" stroke-linecap="round"/></symbol>
  <symbol id="wind-b-weave" viewBox="0 0 128 128"><path d="M12 17H59C76 17 80 29 80 43V89H43V45C43 32 35 31 13 31M43 62H79C100 62 101 91 79 91H114" fill="none" stroke="currentColor" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/></symbol>`;
}

export function standalone(id, title, options = {}) {
  const spec = id === 'small' ? small : master;
  const color = options.color || '#14675F';
  const bg = options.background ? `<rect width="128" height="128" fill="${options.background}"/>` : '';
  const geometry = strands(spec, options.twoTone ? ['#F6F4EE', '#D9A15F'] : [color, color]);
  const content = options.background ? `<g transform="translate(16 16) scale(.75)">${geometry}</g>` : geometry;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${options.size || 128}" height="${options.size || 128}" viewBox="0 0 128 128" role="img" aria-labelledby="title"><title id="title">${title}</title>${bg}${content}</svg>`;
}
