// Entity-graph zoom / pan / minimap.
//
// Extracted from concept_graph_controller. createZoom wires the SVG's wheel/pointer
// pan+zoom, the zoom-control buttons, and the collapsible minimap, and returns the
// { recenter, fitTo, reflow } API the controller already used via this._zoomApi.
// Everything it needs is passed in — no controller internals reached:
//   svg, vp    — the graph <svg> and its viewport <g>
//   world      — { x, y, w, h } content bounds
//   canvas     — the canvas element the controls/minimap attach to
//   storageGet/storageSet — localStorage helpers (for minimap collapse persistence)

const SVG = 'http://www.w3.org/2000/svg'
const MINIMAP_MAX = 240 // longest edge of the minimap thumbnail

export function createZoom ({ svg, vp, world, canvas, storageGet, storageSet }) {
  const winSize = () => {
    const r = canvas.getBoundingClientRect()
    // Fit against the VISIBLE height: the canvas can extend below the viewport
    // (its height is clamp(…100vh-260px…) and page chrome sits below it), so
    // fitting to the full canvas height pushed the bottom node off-screen. Clamp
    // the height to the part of the canvas actually within the viewport.
    const vh = window.innerHeight || document.documentElement.clientHeight
    const visibleH = Math.min(r.height, Math.max(0, Math.min(r.bottom, vh) - Math.max(r.top, 0)))
    return { w: r.width || 900, h: (visibleH || r.height) || 560 }
  }
  let { w: winW, h: winH } = winSize()
  // Fit scale never magnifies past 1:1 — a small graph shows at its natural size,
  // centred, rather than being blown up to fill a large canvas. A screen-space
  // margin (FIT_PAD each side) keeps the graph from butting right up against the
  // canvas edges, so the top/bottom nodes have a little breathing room.
  const FIT_PAD = 28
  const fitScale = () => Math.min(1, (winW - 2 * FIT_PAD) / world.w, (winH - 2 * FIT_PAD) / world.h)
  let fitK = fitScale()
  let minK = fitK * 0.9; const maxK = 3.5
  let k = fitK; let tx = 0; let ty = 0
  let userZoomed = false

  const clampPan = () => {
    const M = 60
    const vw = world.w * k; const vh = world.h * k
    const loX = Math.min(winW - vw - M, M); const hiX = Math.max(M, winW - vw + M)
    tx = Math.max(loX, Math.min(hiX, tx))
    const loY = Math.min(winH - vh - M, M); const hiY = Math.max(M, winH - vh + M)
    ty = Math.max(loY, Math.min(hiY, ty))
  }
  const apply = () => {
    vp.setAttribute('transform', `translate(${tx},${ty}) scale(${k}) translate(${-world.x},${-world.y})`)
    updateMinimap()
  }
  const recenter = () => { k = fitK; tx = (winW - world.w * k) / 2; ty = (winH - world.h * k) / 2; clampPan(); apply() }
  const fitTo = (rect) => {
    if (!rect || rect.w <= 0 || rect.h <= 0) return recenter()
    const PAD = 40
    k = Math.max(minK, Math.min(maxK, Math.min((winW - 2 * PAD) / rect.w, (winH - 2 * PAD) / rect.h)))
    const cx = rect.x + rect.w / 2; const cy = rect.y + rect.h / 2
    tx = winW / 2 - (cx - world.x) * k; ty = winH / 2 - (cy - world.y) * k
    userZoomed = true; clampPan(); apply()
  }
  const zoomAt = (sx, sy, factor) => {
    const nk = Math.max(minK, Math.min(maxK, k * factor)); if (nk === k) return
    const wx = (sx - tx) / k; const wy = (sy - ty) / k
    k = nk; tx = sx - wx * k; ty = sy - wy * k; userZoomed = true; clampPan(); apply()
  }

  svg.addEventListener('wheel', (ev) => {
    // Ctrl/⌘ + wheel (and trackpad pinch, which arrives as ctrl+wheel) = zoom.
    if (ev.ctrlKey || ev.metaKey) {
      ev.preventDefault()
      const r = svg.getBoundingClientRect()
      // Trackpad pinch sends many small-delta ctrl+wheel events, so a small
      // coefficient felt sluggish. Use a larger step, but clamp each event's
      // factor so a discrete mouse ctrl+wheel (delta ~±100+) doesn't over-zoom
      // in one jump.
      const factor = Math.min(1.5, Math.max(1 / 1.5, Math.exp(-ev.deltaY * 0.01)))
      zoomAt(ev.clientX - r.left, ev.clientY - r.top, factor)
      return
    }
    // Plain wheel / two-finger trackpad scroll = pan the graph. The user isn't
    // trapped: when the graph is pinned at the edge in the wheel's direction (or
    // fits entirely), the pan below is a no-op and we let the event bubble so the
    // page scrolls normally.
    const dx = ev.shiftKey ? ev.deltaY : ev.deltaX // shift+wheel scrolls horizontally
    const dy = ev.shiftKey ? 0 : ev.deltaY
    const beforeX = tx; const beforeY = ty
    tx -= dx; ty -= dy; clampPan()
    if (tx === beforeX && ty === beforeY) return // pinned at the edge → page scrolls
    ev.preventDefault()
    userZoomed = true; apply()
  }, { passive: false })

  let dragging = false; let moved = false; let lastX = 0; let lastY = 0
  svg.addEventListener('pointerdown', (ev) => {
    if (ev.button !== 0) return
    const t = ev.target
    if (t.closest('.entity-graph__node') || t.classList.contains('entity-graph__edge-hit')) return
    dragging = true; moved = false; lastX = ev.clientX; lastY = ev.clientY
    canvas.classList.add('entity-graph__canvas--panning'); svg.setPointerCapture(ev.pointerId)
  })
  svg.addEventListener('pointermove', (ev) => {
    if (!dragging) return
    const dx = ev.clientX - lastX; const dy = ev.clientY - lastY
    if (Math.abs(dx) + Math.abs(dy) > 2) { moved = true; userZoomed = true }
    lastX = ev.clientX; lastY = ev.clientY
    tx += dx; ty += dy; clampPan(); apply()
  })
  const endDrag = (ev) => { if (!dragging) return; dragging = false; canvas.classList.remove('entity-graph__canvas--panning'); try { svg.releasePointerCapture(ev.pointerId) } catch { /* capture already released */ } }
  svg.addEventListener('pointerup', endDrag)
  svg.addEventListener('pointercancel', endDrag)
  svg.addEventListener('click', (ev) => { if (moved) { ev.stopPropagation(); moved = false } }, true)

  // zoom control buttons
  const zmod = (navigator.platform || '').toLowerCase().includes('mac') ? '⌘' : 'Ctrl'
  const ctl = document.createElement('div'); ctl.className = 'entity-graph__zoom'
  // All three zoom controls use inline SVG glyphs so they match the round icon
  // buttons below. "Fit to view" is a crosshair target (circle + cross-hairs) —
  // "centre/fit on target", deliberately NOT the outward arrows people read as a popout.
  const svgOpen = '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">'
  const plusIcon = `${svgOpen}<path d="M12 5v14M5 12h14"/></svg>`
  const minusIcon = `${svgOpen}<path d="M5 12h14"/></svg>`
  const fitIcon = '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="6"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/></svg>'
  ctl.innerHTML = `<button data-z="in" title="Zoom in (${zmod}+scroll)" aria-label="Zoom in">${plusIcon}</button><button data-z="out" title="Zoom out (${zmod}+scroll)" aria-label="Zoom out">${minusIcon}</button><button data-z="fit" title="Fit to view" aria-label="Fit to view">${fitIcon}</button>`
  ctl.querySelector('[data-z="in"]').addEventListener('click', () => zoomAt(winW / 2, winH / 2, 1.3))
  ctl.querySelector('[data-z="out"]').addEventListener('click', () => zoomAt(winW / 2, winH / 2, 1 / 1.3))
  ctl.querySelector('[data-z="fit"]').addEventListener('click', () => { userZoomed = false; recenter() })
  canvas.append(ctl)

  // minimap
  const mmScale = Math.min(MINIMAP_MAX / world.w, MINIMAP_MAX / world.h)
  const mmW = Math.round(world.w * mmScale); const mmH = Math.round(world.h * mmScale)
  const mm = document.createElement('div'); mm.className = 'entity-graph__minimap'
  const mmSvg = document.createElementNS(SVG, 'svg')
  mmSvg.setAttribute('class', 'entity-graph__minimap-svg')
  mmSvg.setAttribute('width', mmW); mmSvg.setAttribute('height', mmH)
  mmSvg.setAttribute('viewBox', `${world.x} ${world.y} ${world.w} ${world.h}`)
  const snap = vp.cloneNode(true); snap.removeAttribute('transform'); snap.style.pointerEvents = 'none'
  // At thumbnail scale (~0.1x) the real strokes/labels shrink to sub-pixel and
  // vanish, leaving the minimap looking blank. Strip the text/badge clutter and
  // let the CSS give the boxes a solid fill + non-scaling strokes so the shape of
  // the graph reads at a glance.
  snap.querySelectorAll('text, .entity-graph__node-pill, .entity-graph__edge-label-bg').forEach((el) => el.remove())
  mmSvg.append(snap)
  const mmView = document.createElementNS(SVG, 'rect'); mmView.setAttribute('class', 'entity-graph__minimap-view')
  mmSvg.append(mmView)
  mm.append(mmSvg)

  // Collapse/expand toggle. Collapsed, the minimap shrinks to a small labelled
  // pill; expanded, it shows the thumbnail. The state persists in localStorage.
  const mmToggle = document.createElement('button')
  mmToggle.type = 'button'
  mmToggle.className = 'entity-graph__minimap-toggle'
  const mmLabel = document.createElement('span')
  mmLabel.className = 'entity-graph__minimap-label'
  mmLabel.textContent = 'Map'
  mm.append(mmToggle, mmLabel)

  const MM_COLLAPSED_KEY = 'entity-graph:minimap-collapsed'
  const setCollapsed = (collapsed) => {
    mm.classList.toggle('entity-graph__minimap--collapsed', collapsed)
    mmToggle.textContent = collapsed ? '□' : '–'
    mmToggle.title = collapsed ? 'Show map' : 'Hide map'
    mmToggle.setAttribute('aria-label', mmToggle.title)
  }
  setCollapsed(storageGet(MM_COLLAPSED_KEY) === '1')
  mmToggle.addEventListener('pointerdown', (ev) => ev.stopPropagation())
  mmToggle.addEventListener('click', (ev) => {
    ev.stopPropagation()
    const collapsed = !mm.classList.contains('entity-graph__minimap--collapsed')
    setCollapsed(collapsed)
    storageSet(MM_COLLAPSED_KEY, collapsed ? '1' : '0')
  })
  // Clicking the collapsed pill anywhere expands it (not just the button).
  mmLabel.addEventListener('pointerdown', (ev) => ev.stopPropagation())
  mmLabel.addEventListener('click', (ev) => {
    if (!mm.classList.contains('entity-graph__minimap--collapsed')) return
    ev.stopPropagation(); setCollapsed(false); storageSet(MM_COLLAPSED_KEY, '0')
  })

  canvas.append(mm)
  const updateMinimap = () => {
    const wx = (0 - tx) / k + world.x; const wy = (0 - ty) / k + world.y
    mmView.setAttribute('x', wx); mmView.setAttribute('y', wy)
    mmView.setAttribute('width', winW / k); mmView.setAttribute('height', winH / k)
  }
  const mmGoto = (ev) => {
    const r = mmSvg.getBoundingClientRect()
    const wx = world.x + (ev.clientX - r.left) / mmScale; const wy = world.y + (ev.clientY - r.top) / mmScale
    tx = winW / 2 - (wx - world.x) * k; ty = winH / 2 - (wy - world.y) * k; userZoomed = true; clampPan(); apply()
  }
  let mmDown = false
  const mmCollapsed = () => mm.classList.contains('entity-graph__minimap--collapsed')
  mm.addEventListener('pointerdown', (ev) => { if (mmCollapsed()) return; mmDown = true; mm.setPointerCapture(ev.pointerId); mmGoto(ev); ev.stopPropagation() })
  mm.addEventListener('pointermove', (ev) => { if (mmDown) mmGoto(ev) })
  mm.addEventListener('pointerup', (ev) => { mmDown = false; try { mm.releasePointerCapture(ev.pointerId) } catch { /* capture already released */ } })
  if (world.w <= winW + 1 && world.h <= winH + 1) mm.style.display = 'none'

  // reflow on canvas resize (until the user takes control) — the pane is often
  // display:none when the frame first loads, so the initial fit needs the real size.
  const reflow = () => {
    const s = winSize(); if (!s.w || !s.h) return
    winW = s.w; winH = s.h; fitK = fitScale(); minK = fitK * 0.9
    if (!userZoomed) recenter(); else { clampPan(); apply() }
  }

  recenter()
  // a couple of deferred fits to catch the pane becoming visible
  requestAnimationFrame(reflow)
  setTimeout(reflow, 120)

  return { recenter, fitTo, reflow }
}
