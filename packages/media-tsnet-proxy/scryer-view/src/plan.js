// The Scryer view's layout policy: a pure function of what is shown, the display
// mode and the frame's size. Every threshold is a named guess, not a measurement.
// Nothing here removes a capability: a smaller frame moves things one tap away
// (into the full view), and the full view always shows everything.

/** The inline search card shows this many tiles; the rest are one tap away in the full view. */
export const INLINE_RESULTS = 4;
/** The inline title card lists this many seasons; more are in the full view. */
export const INLINE_SEASONS = 6;
/** From this width the full view sets search tiles in two columns (each tile then ~27rem). */
export const TWO_COLUMN_MIN_WIDTH = 920;
/**
 * From this width an episode is one table row: number 3rem, name 1fr (min 12rem),
 * air date 7rem, file 9rem, monitor 7.5rem, plus page padding: 640 px.
 */
export const EPISODE_TABLE_MIN_WIDTH = 640;
/** Below this fixed height the inline card cannot pin its header over rows, so it scrolls whole. */
export const PIN_MIN_HEIGHT = 300;

/**
 * @param {{view: "search" | "title", mode: string, width: number, height: number | undefined, canFullscreen: boolean, count: number}} f
 *   `height` is the host's fixed frame height, or undefined when the frame grows with content.
 *   `count` is the number of results (search) or seasons (title).
 */
export function plan({ view, mode, width, height, canFullscreen, count }) {
  const full = mode === "fullscreen" || mode === "expanded";
  const limit = view === "search" ? INLINE_RESULTS : INLINE_SEASONS;
  return {
    kind: full ? "page" : "card",
    // Inline shows the first few; the full view shows all of them.
    shown: full ? count : Math.min(count, limit),
    more: full ? 0 : Math.max(0, count - limit),
    columns: full && view === "search" && width >= TWO_COLUMN_MIN_WIDTH ? 2 : 1,
    episodes: !full ? "none" : width >= EPISODE_TABLE_MIN_WIDTH ? "table" : "stack",
    scroll: full ? "page" : height !== undefined && height < PIN_MIN_HEIGHT ? "card" : "list",
    // The host owns open and close. Without a host full view, the card grows in place.
    open: canFullscreen ? "host" : "in-place",
  };
}
