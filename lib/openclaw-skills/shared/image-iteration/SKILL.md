---
name: image-iteration
description: Make and refine pictures over many rounds — illustrations, printables, page designs, covers, cards, decorations — and deliver print-ready files. Use whenever the user asks to draw, design, change, fix, resize, split, enlarge, print or export an image, or to prepare pieces for Canva.
---

# Image iteration

Two kinds of tool exist. Use each for what it can do.

| Tool | Does | Cannot |
| --- | --- | --- |
| `image_generate` | Invent and redraw pictures | Make a small exact change, hit an exact size, keep anything perfectly still |
| `claw-image-kit__*` | Crop, split, page-size, enlarge, trace, compare, make transparent, render SVG, build PDF | Invent anything |

The generator redraws the whole picture on every call, even for "change only X". The kit never redraws. When a request is about size, shape, position, cutting, resolution or file type, use the kit, not the generator.

## Rules for the generator

1. **The approved image is the seed.** Always edit from the version the user approved, passed as the reference image. Never regenerate a liked result from its text prompt: the same prompt never returns the same picture.
2. **Ask for one change per edit**, named precisely, and say what must stay the same.
3. **Small local changes edit well; global ones do not.** Pose, an object, an expression, a word: edit. Lighting, colour scheme, line weight, style, background tone: these change the whole picture, so make a new picture from the approved one and expect drift.
4. **Point at an example inside the picture** when a shape keeps coming out wrong: "make the large one match the small ones on the left".
5. **Keep the style words.** Reuse the exact style phrase from the approved version in every prompt. Dropping it changes more than style.
6. **After two failed tries at the same fix, stop.** Tell the user plainly, and offer a different route: make the part separately, fix it with the kit, or finish it in Canva.
7. Use only the image models this gateway allows: `gemini-3.1-flash-image` and `gpt-image-2`. Others fail with HTTP 403. Generators cannot make a transparent background: make it white, then use `make_transparent`.

## Rules for the kit

- **Exact page size:** `fit_page` (Letter 8.5×11 in at 300 dpi = 2550×3300 px). Never ask the generator for a page size. `mode=pad` keeps everything; `mode=crop` fills the page and trims edges.
- **Two pages from a spread:** `split` with `columns=2`.
- **Sharper or bigger:** `enlarge` for pictures. For black-and-white line art, `vectorize` then `render_svg` at the paper size gives crisp lines at any size.
- **Did the edit land?** `compare` the before and after with a tight `box` around the feature that should change. Report the verdict honestly.
- **SVG you wrote yourself:** always `render_svg`, then `view_image` the PNG, before you send it. `view_image` cannot open SVG.
- **One file to print or open on a phone:** `pdf`. Do not send `.md` files to a phone user.

## Working with the user

- **Keep versions.** Never overwrite an approved file. Record each approved file path in the project notes with one line saying what it is.
- **Offer parts early.** For layouts (pages, cards, covers), make each decoration as its own picture on white, then assemble in Canva. This avoids redrawing a whole page to move one thing.
- **Check before sending.** `view_image` every result and say what is right and what is still wrong.

## When a background image arrives

When an image job finishes, you wake in a delivery turn. That turn has look-only tools: `read`, `ls`, `view_image`, `tool_search`, `tool_describe`. Writing, editing, generating and kit tools are not available there.

- In a delivery turn, only look at the image and report it. Do not try to save notes, retry or edit.
- If a tool call fails there with "not found", that error is real. It is not a mistake you invented. Do not apologise for it as a false claim.
- Save notes and start the next step on the user's next message.
