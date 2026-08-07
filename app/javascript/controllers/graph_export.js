// Entity-graph export: copy/download the whole graph as PNG or SVG.
//
// Extracted from concept_graph_controller so the controller stays orchestration.
// The controller calls copyPng/copySvg with a small context object rather than
// this module reaching into controller internals:
//   ctx.svg    — the live <svg> element to clone
//   ctx.world  — { x, y, w, h } content bounds (from the layout)
//   ctx.name   — base filename (already slug-safe)
//   ctx.toast  — (msg) => void, for user feedback
// Clipboard first, download fallback — same behaviour as before.

const SVG = 'http://www.w3.org/2000/svg'

// Slugify a label into a safe filename base. Exported so the controller can build
// ctx.name from the selected class label without duplicating the rule.
export function safeFileName (label) {
  return String(label || 'entity-graph')
    .replace(/[^\w-]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 60) || 'entity-graph'
}

// The subset of entity-graph rules the exported SVG needs to look right, inlined
// (external stylesheets don't apply to a detached/rasterised SVG).
function exportCss () {
  return `
    .entity-graph__node-shape{fill:#fff;stroke:#234979;stroke-width:2px}
    .entity-graph__node--selected .entity-graph__node-shape{fill:#234979;stroke:#234979}
    .entity-graph__node-label{font-family:-apple-system,Helvetica,Arial,sans-serif;font-size:13px;fill:#222}
    .entity-graph__node--selected .entity-graph__node-label{fill:#fff;font-weight:600}
    .entity-graph__node--collector .entity-graph__node-shape{stroke:#c3ccd8;stroke-width:1.2px}
    .entity-graph__node--collector .entity-graph__node-label{fill:#9aa5b3}
    .entity-graph__node-pill{fill:#eef2f7;stroke:#d3ddea}
    .entity-graph__edge{fill:none;stroke-width:2.5px}
    .entity-graph__edge--is-a{stroke:#f0a848}
    .entity-graph__edge--rel{stroke:#2f6fed}
    .entity-graph__edge--to-collector{stroke:#e6c79a;stroke-width:1.6px}
    .entity-graph__edge-label{font-family:-apple-system,Helvetica,Arial,sans-serif;font-size:11px;fill:#1f4fb0}
    .entity-graph__edge-label-bg{fill:#f3f6f7;opacity:.9}
  `
}

// Build a self-contained SVG string of the WHOLE graph: the live SVG cloned with
// the interaction-only layers removed, the viewport transform reset, the viewBox
// set to the full content bounds, and the entity-graph CSS inlined (so the copied
// image is styled even outside the page). Returns { svgString, width, height } or
// null when there's nothing rendered yet.
function exportSvgString (svgEl, world) {
  if (!svgEl || !world) return null
  const w = Math.round(world.w); const h = Math.round(world.h)
  const clone = svgEl.cloneNode(true)
  clone.setAttribute('xmlns', SVG)
  clone.setAttribute('width', w)
  clone.setAttribute('height', h)
  clone.setAttribute('viewBox', `${world.x} ${world.y} ${w} ${h}`)
  clone.removeAttribute('style')
  // drop pointer-only layers: hit-areas and the (empty) hover overlay
  clone.querySelectorAll('.entity-graph__edge-hit').forEach((el) => el.remove())
  // reset the viewport transform so content sits at world coords (the viewBox frames it)
  const vp = clone.querySelector('[data-viewport]')
  if (vp) vp.removeAttribute('transform')
  // white background so the PNG isn't transparent
  const bg = document.createElementNS(SVG, 'rect')
  bg.setAttribute('x', world.x); bg.setAttribute('y', world.y)
  bg.setAttribute('width', w); bg.setAttribute('height', h); bg.setAttribute('fill', '#ffffff')
  clone.insertBefore(bg, clone.firstChild.nextSibling) // after <defs>
  // inline the entity-graph styles so the image renders standalone
  const style = document.createElementNS(SVG, 'style')
  style.textContent = exportCss()
  clone.insertBefore(style, clone.firstChild)
  // No <?xml?> prolog — it's optional for SVG and makes some tools treat the file
  // as generic XML (and name it .xml). The <svg> root + xmlns is enough.
  const svgString = new XMLSerializer().serializeToString(clone)
  return { svgString, width: w, height: h }
}

// Rasterise the export SVG to a PNG blob at 2x for crispness (capped so huge
// graphs don't blow past canvas limits).
function svgToPngBlob ({ svgString, width, height }) {
  return new Promise((resolve, reject) => {
    const scale = Math.min(2, 8000 / Math.max(width, height) || 2)
    const url = URL.createObjectURL(new Blob([svgString], { type: 'image/svg+xml;charset=utf-8' }))
    const img = new Image()
    img.onload = () => {
      try {
        const c = document.createElement('canvas')
        c.width = Math.round(width * scale); c.height = Math.round(height * scale)
        const ctx = c.getContext('2d')
        ctx.drawImage(img, 0, 0, c.width, c.height)
        URL.revokeObjectURL(url)
        c.toBlob((b) => b ? resolve(b) : reject(new Error('toBlob failed')), 'image/png')
      } catch (e) { URL.revokeObjectURL(url); reject(e) }
    }
    img.onerror = (e) => { URL.revokeObjectURL(url); reject(e) }
    img.src = url
  })
}

function download (blob, filename, toastMsg, toast) {
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = filename
  document.body.append(a); a.click(); a.remove()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
  toast(toastMsg)
}

export async function copySvg ({ svg, world, name, toast }) {
  const out = exportSvgString(svg, world); if (!out) return
  const blob = new Blob([out.svgString], { type: 'image/svg+xml' })
  try {
    if (navigator.clipboard && window.ClipboardItem) {
      // most apps paste SVG-as-text; provide both so text targets also work
      await navigator.clipboard.write([new window.ClipboardItem({
        'image/svg+xml': blob,
        'text/plain': new Blob([out.svgString], { type: 'text/plain' })
      })])
      toast('Copied graph (SVG)')
      return
    }
    if (navigator.clipboard?.writeText) { await navigator.clipboard.writeText(out.svgString); toast('Copied graph (SVG)'); return }
  } catch { /* fall through to download */ }
  download(blob, name + '.svg', 'Downloaded graph (SVG)', toast)
}

export async function copyPng ({ svg, world, name, toast }) {
  const out = exportSvgString(svg, world); if (!out) return
  let blob
  try {
    blob = await svgToPngBlob(out)
  } catch {
    // couldn't rasterise — fall back to an SVG download
    download(new Blob([out.svgString], { type: 'image/svg+xml' }), name + '.svg', 'Downloaded graph (SVG)', toast)
    return
  }
  // have a PNG: try the clipboard, and if that's unavailable/blocked, download it
  try {
    if (navigator.clipboard && window.ClipboardItem) {
      await navigator.clipboard.write([new window.ClipboardItem({ 'image/png': blob })])
      toast('Copied graph (PNG)')
      return
    }
  } catch { /* clipboard blocked — download instead */ }
  download(blob, name + '.png', 'Downloaded graph (PNG)', toast)
}
