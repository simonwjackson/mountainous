// What a title is, drawn on the 16 x 16 grid of the assistant's launcher mark,
// where a poster would be: a clapperboard, a television, a sparkle. Ported from
// the assistant's web/src/ui/pixel.tsx (mediaGrid and PixelGrid), unchanged in shape.

const SIZE = 16;

function set(grid, x, y, tone) {
  if (x < 0 || y < 0 || x >= SIZE || y >= SIZE) return;
  grid.set(`${x},${y}`, tone);
}
function rect(grid, x0, y0, x1, y1, tone) {
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) set(grid, x, y, tone);
}
function points(grid, list, tone) {
  for (const [x, y] of list) set(grid, x, y, tone);
}

/** @param {"movie" | "series" | "anime"} kind */
export function mediaGrid(kind) {
  const grid = new Map();
  switch (kind) {
    case "movie":
      // The clapper, hinged on the left, with its stripes on a slant.
      rect(grid, 2, 2, 3, 2, "side");
      for (let y = 3; y <= 4; y++) for (let x = 2; x <= 13; x++) set(grid, x, y, (x + y) % 4 < 2 ? "light" : "side");
      rect(grid, 2, 6, 13, 12, "face");
      rect(grid, 2, 13, 13, 13, "side");
      break;
    case "series":
      points(grid, [[5, 1], [6, 2], [7, 3], [10, 1], [9, 2], [8, 3]], "side");
      rect(grid, 1, 4, 14, 12, "side");
      rect(grid, 2, 5, 13, 11, "light");
      points(grid, [[3, 6], [4, 6], [3, 7]], "face");
      rect(grid, 6, 13, 9, 13, "side");
      rect(grid, 4, 14, 11, 14, "side");
      break;
    case "anime":
      for (let y = 0; y < SIZE; y++) {
        for (let x = 0; x < SIZE; x++) {
          const dx = Math.abs(x - 6);
          const dy = Math.abs(y - 9);
          if ((dx === 0 && dy <= 5) || (dy === 0 && dx <= 5) || dx + dy <= 2) set(grid, x, y, "light");
        }
      }
      points(grid, [[12, 1], [12, 2], [12, 4], [12, 5], [10, 3], [11, 3], [13, 3], [14, 3], [12, 3]], "face");
      break;
  }
  return grid;
}

/** One crisp rectangle per horizontal run of a tone. Decorative: hidden from screen readers. */
export function pixelSvg(grid, className) {
  let rects = "";
  for (let y = 0; y < SIZE; y++) {
    let x = 0;
    while (x < SIZE) {
      const tone = grid.get(`${x},${y}`);
      if (tone === undefined) { x++; continue; }
      let end = x + 1;
      while (end < SIZE && grid.get(`${end},${y}`) === tone) end++;
      rects += `<rect class="px-${tone}" x="${x}" y="${y}" width="${end - x}" height="1"/>`;
      x = end;
    }
  }
  return `<svg class="${className}" viewBox="0 0 ${SIZE} ${SIZE}" shape-rendering="crispEdges" aria-hidden="true">${rects}</svg>`;
}
