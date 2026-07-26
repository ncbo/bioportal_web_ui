import { Controller } from '@hotwired/stimulus'
import {
  computeLayout, routePath, straightPath, samplePath, boundary,
  isUpperOnto, shortId, ontoAcronym, measureText,
  NODE_H_BASE, PILL_H, PILL_PAD
} from './entity_graph_layout'

const SVG = 'http://www.w3.org/2000/svg'
const MINIMAP_MAX = 240 // longest edge of the minimap thumbnail

// Renders the ancestor/relationship neighbourhood of a class as a node-link graph,
// using the custom "tidy ancestor tree" layout (ranking by longest is-a path,
// Reingold-Tilford placement, crossing reduction, curved obstruction-aware edge
// routing) ported from the offline harness. Drawn as hand-built SVG with a
// fixed-viewport zoom/pan, a context minimap, node search, selection/highlight,
// a legend, and per-node copy/navigate actions.
//
// The full graph is delivered in one payload from the server (no client fetches).
// Connects to data-controller="concept-graph".
export default class extends Controller {
  static targets = ['canvas', 'gate', 'empty', 'toolbar']
  static values = {
    graph: Object,
    ontology: String,
    large: String
  }

  connect () {
    const graph = this.graphValue || {}
    this.graph = graph
    this.nodes = graph.nodes || []
    this.edges = graph.edges || []

    // display options (toolbar toggles)
    this.opts = {
      hideUpper: false,
      isaOnly: false,
      fadeUpper: true,
      useUpperInfo: true,
      transitiveReduction: true,
      showPills: false,
      showAcronym: false
    }

    if (this.nodes.length <= 1 && this.edges.length === 0) {
      this.emptyTarget.classList.remove('d-none')
      return
    }

    if (this.largeValue === 'true') {
      this.gateTarget.classList.remove('d-none')
    } else {
      this.#boot()
    }
  }

  disconnect () {
    this._resizeObserver?.disconnect()
    this._resizeObserver = null
    this._tip?.remove()
  }

  // "Show graph anyway" on the large-graph gate.
  renderAnyway () {
    this.gateTarget.classList.add('d-none')
    this.#boot()
  }

  // --- boot / chrome --------------------------------------------------------

  #boot () {
    this.#buildToolbar()
    this.#render()
    if (!this._resizeObserver && 'ResizeObserver' in window) {
      // re-fit while the pane settles / becomes visible, until the user zooms
      this._resizeObserver = new ResizeObserver(() => this._zoomApi && this._zoomApi.reflow())
      this._resizeObserver.observe(this.canvasTarget)
    }
  }

  #effNodeH () {
    return this.opts.showPills ? NODE_H_BASE + PILL_H + PILL_PAD : NODE_H_BASE
  }

  #buildToolbar () {
    if (!this.hasToolbarTarget) return
    const t = this.toolbarTarget
    t.replaceChildren()
    const wrap = document.createElement('span')
    wrap.style.cssText = 'position:relative;display:inline-flex;align-items:center'
    const search = document.createElement('input')
    search.type = 'search'; search.placeholder = 'Search nodes…'; search.autocomplete = 'off'
    search.className = 'entity-graph__search'
    const count = document.createElement('span')
    count.className = 'entity-graph__search-count'
    wrap.append(search, count)
    t.append(wrap)
    this._search = search; this._searchCount = count
    let timer = null
    search.addEventListener('input', () => { clearTimeout(timer); timer = setTimeout(() => this.#runSearch(), 180) })
    search.addEventListener('keydown', (ev) => { if (ev.key === 'Escape') { search.value = ''; this.#runSearch(); search.blur() } })

    const toggles = [
      ['isaOnly', 'Only show is-a'],
      ['transitiveReduction', 'Transitive reduction'],
      ['hideUpper', 'Hide upper ontology (BFO / COB)'],
      ['fadeUpper', 'Fade upper ontology'],
      ['useUpperInfo', 'Use authoritative BFO/COB info'],
      ['showPills', 'Show short-id pills'],
      ['showAcronym', 'Show ontology acronym']
    ]
    toggles.forEach(([key, text]) => {
      const label = document.createElement('label')
      label.style.cssText = 'display:flex;align-items:center;gap:7px;cursor:pointer;user-select:none'
      const cb = document.createElement('input')
      cb.type = 'checkbox'; cb.checked = !!this.opts[key]; cb.style.cursor = 'pointer'
      cb.addEventListener('change', () => {
        this.opts[key] = cb.checked
        // pills and acronym are mutually exclusive
        if (key === 'showPills' && cb.checked) { this.opts.showAcronym = false }
        if (key === 'showAcronym' && cb.checked) { this.opts.showPills = false }
        this.#buildToolbar() // reflect the mutual-exclusion in the checkboxes
        this.#render()
        this.#runSearch()
      })
      label.append(cb, document.createTextNode(' ' + text))
      t.append(label)
    })
    // the key/shortcuts help icon sits at the end of the same row
    this.#buildLegend()
  }

  // The key/legend is collapsed behind a help icon in the toolbar so it doesn't
  // eat a full row; clicking the icon toggles a small popover with the full key.
  #buildLegend () {
    if (!this.hasToolbarTarget) return
    const key = (svg, text) => `<span class="entity-graph__legend-item"><svg width="30" height="14" style="overflow:visible">${svg}</svg>${text}</span>`
    const content =
      key('<line x1="1" y1="7" x2="22" y2="7" stroke="#f0a848" stroke-width="2.5"/><path d="M20,3 L27,7 L20,11 Z" fill="#f0a848"/>', 'is-a (subclass)') +
      key('<line x1="1" y1="7" x2="22" y2="7" stroke="#2f6fed" stroke-width="2.5"/><path d="M20,3 L27,7 L20,11" fill="none" stroke="#2f6fed"/>', 'relationship') +
      key('<line x1="1" y1="7" x2="22" y2="7" stroke="#e6c79a" stroke-width="1.6"/><path d="M21,4 L27,7 L21,10 Z" fill="#e6c79a"/>', 'to upper ontology') +
      key('<circle cx="6" cy="7" r="3.4" fill="#2f6fed"/><line x1="9" y1="7" x2="28" y2="7" stroke="#2f6fed" stroke-width="2"/>', '● = source end') +
      key('<rect x="1" y="2" width="26" height="10" rx="2.5" fill="#fff" stroke="#234979" stroke-width="1.6"/>', 'class') +
      key('<rect x="1" y="2" width="26" height="10" rx="2.5" fill="#fff" stroke="#c3ccd8" stroke-width="1.2"/>', 'upper ontology (faded)') +
      '<div class="entity-graph__legend-hint">Double-click a node to open it · scroll or drag to pan · ⌘/Ctrl+scroll to zoom · F to fit selection</div>'

    const holder = document.createElement('span')
    holder.className = 'entity-graph__help'
    const btn = document.createElement('button')
    btn.type = 'button'
    btn.className = 'entity-graph__help-btn'
    btn.title = 'Graph key & shortcuts'
    btn.setAttribute('aria-label', 'Graph key and shortcuts')
    btn.textContent = '?'
    const pop = document.createElement('div')
    pop.className = 'entity-graph__help-pop'
    pop.hidden = true
    pop.innerHTML = content
    holder.append(btn, pop)

    const close = () => { pop.hidden = true; document.removeEventListener('click', onDoc, true) }
    const onDoc = (ev) => { if (!holder.contains(ev.target)) close() }
    btn.addEventListener('click', (ev) => {
      ev.stopPropagation()
      const open = pop.hidden
      pop.hidden = !open
      if (open) setTimeout(() => document.addEventListener('click', onDoc, true), 0)
      else document.removeEventListener('click', onDoc, true)
    })
    // sits at the end of the toolbar row
    this.toolbarTarget.append(holder)
  }

  // --- rendering ------------------------------------------------------------

  #render () {
    const nodeH = this.#effNodeH()
    const L = computeLayout(this.graph, { ...this.opts, nodeH })
    this._layout = L
    const N = (id) => L.nodes.get(id)

    const svg = document.createElementNS(SVG, 'svg')
    svg.setAttribute('class', 'entity-graph__svg')
    svg.innerHTML = this.#defs()

    // viewport group holds all drawable content; its transform is the zoom/pan
    const vp = document.createElementNS(SVG, 'g'); vp.setAttribute('data-viewport', '')
    const eg = document.createElementNS(SVG, 'g') // edges
    const kg = document.createElementNS(SVG, 'g') // knockout bridge gaps
    const hg = document.createElementNS(SVG, 'g') // transparent edge hit-areas
    const ng = document.createElementNS(SVG, 'g') // nodes
    const og = document.createElementNS(SVG, 'g') // hover overlay (raised edge)
    vp.append(eg, kg, hg, ng, og)
    svg.append(vp)

    const obstacles = [...L.nodes.values()].map((n) => ({ id: n.id, x: n.x, y: n.y, w: n.width, h: nodeH }))
    const laneReg = []
    const edgeSegs = []
    const edgeRecs = []
    const nodeEls = new Map()
    const incidentEdges = new Map()
    const fullAdj = new Map()
    const upAdj = new Map()
    const labelReqs = []
    let hoveredEdge = null
    const nodeLit = new Set()

    // selection state
    this._sel = { nodes: new Set(), edges: new Set(), traceId: null }

    const drawEdge = (e, curved) => {
      const a = N(e.from); const b = N(e.to); if (!a || !b) return
      const isa = e.kind === 'is-a'
      const toColl = this.opts.fadeUpper && L.collector && L.collector.has(e.to)
      const routed = curved ? routePath(a, b, obstacles, laneReg, nodeH) : straightPath(a, b, nodeH)
      const { d, mid, seg } = routed
      const p = document.createElementNS(SVG, 'path')
      p.setAttribute('class', 'entity-graph__edge entity-graph__edge--' + (isa ? 'is-a' : 'rel') + (toColl ? ' entity-graph__edge--to-collector' : ''))
      p.setAttribute('d', d)
      p.setAttribute('marker-end', toColl ? 'url(#eg-ah-coll)' : (isa ? 'url(#eg-ah-isa)' : 'url(#eg-ah-rel)'))
      p.setAttribute('marker-start', toColl ? 'url(#eg-src-coll)' : (isa ? 'url(#eg-src-isa)' : 'url(#eg-src-rel)'))
      eg.append(p)
      const rec = { el: p, from: e.from, to: e.to, knockouts: [] }
      const hit = document.createElementNS(SVG, 'path'); hit.setAttribute('class', 'entity-graph__edge-hit'); hit.setAttribute('d', d)
      const setHover = (on) => {
        p.classList.toggle('entity-graph__edge--hover', on)
        rec.knockouts.forEach((k) => { k.style.display = on ? 'none' : '' })
        ;(on ? og : eg).append(p)
      }
      hit.addEventListener('mouseenter', () => { if (hoveredEdge && hoveredEdge !== rec) hoveredEdge.setHover(false); hoveredEdge = rec; setHover(true) })
      hit.addEventListener('mouseleave', () => { setHover(false); if (hoveredEdge === rec) hoveredEdge = null })
      hit.addEventListener('click', (ev) => { ev.stopPropagation(); this.#toggleEdge(rec) })
      rec.setHover = setHover
      hg.append(hit)
      if (seg) edgeSegs.push({ seg, from: e.from, to: e.to, el: p, rec })
      edgeRecs.push(rec)
      ;(incidentEdges.get(e.from) || incidentEdges.set(e.from, []).get(e.from)).push(rec)
      ;(incidentEdges.get(e.to) || incidentEdges.set(e.to, []).get(e.to)).push(rec)
      ;(fullAdj.get(e.from) || fullAdj.set(e.from, []).get(e.from)).push(e.to)
      if (b.y < a.y - 1) (upAdj.get(e.from) || upAdj.set(e.from, []).get(e.from)).push(e.to)
      if (!isa && e.label && mid) labelReqs.push({ text: e.label, x: mid.x, y: mid.y, from: e.from, to: e.to, els: [] })
    }
    L.treeEdges.forEach((e) => drawEdge(e, false))
    L.overlays.forEach((e) => drawEdge(e, true))

    // bridge knockouts: gap where an edge tunnels under an unrelated node box
    this.#drawKnockouts(kg, edgeSegs, L, nodeH)

    // nodes
    L.nodes.forEach((n, id) => {
      const g = this.#buildNode(n, id, L)
      nodeEls.set(id, g)
      ng.append(g)
    })

    // edge labels (inside viewport, below the hover overlay so they zoom with content)
    const lg = document.createElementNS(SVG, 'g')
    vp.insertBefore(lg, og)
    this.#placeLabels(lg, labelReqs, L, nodeH)

    // stash render state for selection/search/hover
    this._render = { svg, vp, eg, og, kg, ng, N, nodeEls, edgeRecs, incidentEdges, fullAdj, upAdj, labelReqs, nodeLit, nodeH }
    this.#wireNodeInteractions(nodeEls, incidentEdges)
    this.#wireBackground(svg)

    // content bounds (world rect)
    const world = this.#worldBounds(vp, L)

    this.canvasTarget.replaceChildren(svg)
    this.#installZoom(svg, vp, world)
    this.#applyFocus()
  }

  #defs () {
    return `<defs>
      <marker id="eg-ah-isa" viewBox="0 0 10 10" markerWidth="8" markerHeight="8" refX="9" refY="5" orient="auto"><path d="M1,1 L9,5 L1,9 Z" fill="#f0a848"/></marker>
      <marker id="eg-ah-rel" viewBox="0 0 10 10" markerWidth="8" markerHeight="8" refX="9" refY="5" orient="auto"><path d="M1,1 L9,5 L1,9" fill="none" stroke="#2f6fed"/></marker>
      <marker id="eg-src-isa" viewBox="0 0 10 10" markerWidth="6" markerHeight="6" refX="5" refY="5" orient="auto"><circle cx="5" cy="5" r="3.4" fill="#f0a848"/></marker>
      <marker id="eg-src-rel" viewBox="0 0 10 10" markerWidth="6" markerHeight="6" refX="5" refY="5" orient="auto"><circle cx="5" cy="5" r="3.4" fill="#2f6fed"/></marker>
      <marker id="eg-ah-coll" viewBox="0 0 10 10" markerWidth="7" markerHeight="7" refX="9" refY="5" orient="auto"><path d="M1,1 L9,5 L1,9 Z" fill="#e6c79a"/></marker>
      <marker id="eg-src-coll" viewBox="0 0 10 10" markerWidth="5" markerHeight="5" refX="5" refY="5" orient="auto"><circle cx="5" cy="5" r="3" fill="#e6c79a"/></marker>
    </defs>`
  }

  // "Bridge" knockouts: where an edge passes UNDER a node it is not attached to,
  // punch a short background-coloured dash on each side of that node so the eye reads
  // the edge as tunnelling past, not connecting to, the node. GAP is a fixed dash
  // half-length IN PIXELS along the local path tangent (not a sample-index count), and
  // a dash is placed only at the ENTRY and EXIT of each contiguous run of samples inside
  // the node's box — so the break sits tight against the box, not out in open space.
  #drawKnockouts (kg, edgeSegs, L, nodeH) {
    const bg = getComputedStyle(this.canvasTarget).backgroundColor || '#ffffff'
    const GAP = 5; const INFL = 3
    edgeSegs.forEach(({ seg, from, to, rec }) => {
      const pts = samplePath(seg, 60)
      for (const n of L.nodes.values()) {
        if (n.id === from || n.id === to) continue
        const x0 = n.x - n.width / 2 - INFL; const x1 = n.x + n.width / 2 + INFL
        const y0 = n.y - nodeH / 2 - INFL; const y1 = n.y + nodeH / 2 + INFL
        const inside = (p) => p.x >= x0 && p.x <= x1 && p.y >= y0 && p.y <= y1
        // contiguous runs of sample points inside this node's inflated rect
        let i = 0
        while (i < pts.length) {
          if (!inside(pts[i])) { i++; continue }
          let j = i
          while (j + 1 < pts.length && inside(pts[j + 1])) j++
          // knock out at the entry (i) and exit (j) of the run
          for (const idx of (i === j ? [i] : [i, j])) {
            const a = pts[Math.max(0, idx - 1)]; const b = pts[Math.min(pts.length - 1, idx + 1)]
            const dx = b.x - a.x; const dy = b.y - a.y; const len = Math.hypot(dx, dy) || 1
            const ux = dx / len; const uy = dy / len; const c = pts[idx]
            const k = document.createElementNS(SVG, 'path')
            k.setAttribute('class', 'entity-graph__edge-knockout')
            k.setAttribute('stroke', bg)
            k.setAttribute('d', `M ${c.x - ux * GAP},${c.y - uy * GAP} L ${c.x + ux * GAP},${c.y + uy * GAP}`)
            kg.append(k)
            rec.knockouts.push(k)
          }
          i = j + 1
        }
      }
    })
  }

  #buildNode (n, id, L) {
    const isColl = this.opts.fadeUpper && L.collector && L.collector.has(id) && !n.selected
    const g = document.createElementNS(SVG, 'g')
    g.setAttribute('class', 'entity-graph__node' + (n.selected ? ' entity-graph__node--selected' : '') + (isColl ? ' entity-graph__node--collector' : ''))
    g.setAttribute('data-node-id', id)

    const nodeH = this.#effNodeH()
    const rect = document.createElementNS(SVG, 'rect')
    rect.setAttribute('class', 'entity-graph__node-shape')
    rect.setAttribute('x', n.x - n.width / 2)
    rect.setAttribute('y', n.y - nodeH / 2)
    rect.setAttribute('width', n.width)
    rect.setAttribute('height', nodeH)
    rect.setAttribute('rx', '4'); rect.setAttribute('ry', '4')
    g.append(rect)

    const label = this.#effLabel(n)
    const showPill = this.opts.showPills && shortId(id)
    const text = document.createElementNS(SVG, 'text')
    text.setAttribute('class', 'entity-graph__node-label')
    text.setAttribute('x', n.x)
    text.setAttribute('y', showPill ? n.y - PILL_H / 2 : n.y)
    text.setAttribute('text-anchor', 'middle')
    text.setAttribute('dominant-baseline', 'central')
    text.textContent = label
    g.append(text)

    if (showPill) {
      const pillText = shortId(id)
      const pw = measureText(pillText, '600 9.5px -apple-system, sans-serif') + 12
      const pill = document.createElementNS(SVG, 'rect')
      pill.setAttribute('class', 'entity-graph__node-pill')
      pill.setAttribute('x', n.x - pw / 2); pill.setAttribute('y', n.y + 2)
      pill.setAttribute('width', pw); pill.setAttribute('height', PILL_H - 2); pill.setAttribute('rx', '7')
      pill.setAttribute('fill', '#eef2f7'); pill.setAttribute('stroke', '#d3ddea')
      g.append(pill)
      const pt = document.createElementNS(SVG, 'text')
      pt.setAttribute('x', n.x); pt.setAttribute('y', n.y + PILL_H / 2 + 2)
      pt.setAttribute('text-anchor', 'middle'); pt.setAttribute('dominant-baseline', 'central')
      pt.setAttribute('font-size', '9.5px'); pt.setAttribute('font-weight', '600'); pt.setAttribute('fill', '#5a6b82')
      pt.textContent = pillText
      g.append(pt)
    } else if (this.opts.showAcronym) {
      const acr = ontoAcronym(id)
      if (acr) {
        const aw = measureText(acr, '600 9px -apple-system, sans-serif') + 8
        const badge = document.createElementNS(SVG, 'rect')
        badge.setAttribute('x', n.x + n.width / 2 - aw - 2); badge.setAttribute('y', n.y - nodeH / 2 - 6)
        badge.setAttribute('width', aw); badge.setAttribute('height', 13); badge.setAttribute('rx', '6')
        badge.setAttribute('fill', '#dff3ee'); badge.setAttribute('stroke', '#a9ddd0')
        g.append(badge)
        const at = document.createElementNS(SVG, 'text')
        at.setAttribute('x', n.x + n.width / 2 - aw / 2 - 2); at.setAttribute('y', n.y - nodeH / 2)
        at.setAttribute('text-anchor', 'middle'); at.setAttribute('dominant-baseline', 'central')
        at.setAttribute('font-size', '9px'); at.setAttribute('font-weight', '600'); at.setAttribute('fill', '#1c7a63')
        at.textContent = acr
        g.append(at)
      }
    }
    return g
  }

  #placeLabels (lg, labelReqs, L, nodeH) {
    const nodeRects = [...L.nodes.values()].map((n) => ({ x: n.x - n.width / 2, y: n.y - nodeH / 2, w: n.width, h: nodeH }))
    const overlap = (a, b) => a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y
    const placed = []; const H = 15
    labelReqs.forEach((req) => {
      const w = measureText(req.text, '400 11px -apple-system, sans-serif') + 8
      const cands = [0, -16, 16, -32, 32, -48, 48]
      let best = null
      for (const dy of cands) {
        const r = { x: req.x - w / 2, y: req.y + dy - H / 2, w, h: H }
        if (!nodeRects.some((nr) => overlap(r, nr)) && !placed.some((pr) => overlap(r, pr))) { best = r; break }
      }
      if (!best) best = { x: req.x - w / 2, y: req.y - H / 2, w, h: H }
      placed.push(best)
      const bgEl = document.createElementNS(SVG, 'rect')
      bgEl.setAttribute('class', 'entity-graph__edge-label-bg')
      bgEl.setAttribute('x', best.x); bgEl.setAttribute('y', best.y); bgEl.setAttribute('width', w); bgEl.setAttribute('height', H); bgEl.setAttribute('rx', '3')
      lg.append(bgEl)
      const t = document.createElementNS(SVG, 'text')
      t.setAttribute('class', 'entity-graph__edge-label')
      t.setAttribute('x', best.x + w / 2); t.setAttribute('y', best.y + H / 2)
      t.setAttribute('text-anchor', 'middle'); t.setAttribute('dominant-baseline', 'central')
      t.textContent = req.text
      lg.append(t)
      req.els = [bgEl, t]
    })
  }

  #worldBounds (vp, L) {
    let world = { x: 0, y: 0, w: L.width, h: L.height }
    try {
      const bb = vp.getBBox(); const PAD = 10
      const x0 = Math.floor(Math.min(0, bb.x) - PAD); const y0 = Math.floor(Math.min(0, bb.y) - PAD)
      const x1 = Math.ceil(Math.max(L.width, bb.x + bb.width) + PAD); const y1 = Math.ceil(Math.max(L.height, bb.y + bb.height) + PAD)
      world = { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }
    } catch (_) { /* getBBox throws if not laid out; ignore */ }
    return world
  }

  // --- node label / id helpers ---------------------------------------------

  #effLabel (n) {
    return (this.opts.useUpperInfo && n.upper && n.upper.label) ? n.upper.label : n.label
  }

  #classPath (iri) {
    return `/ontologies/${encodeURIComponent(this.ontologyValue)}?p=classes&conceptid=${encodeURIComponent(iri)}`
  }

  // --- interactions: nodes, popup, selection --------------------------------

  #wireNodeInteractions (nodeEls, incidentEdges) {
    const R = this._render
    nodeEls.forEach((g, id) => {
      const n = this._layout.nodes.get(id)
      let clickTimer = null
      g.addEventListener('click', (ev) => {
        ev.stopPropagation()
        if (clickTimer) return
        clickTimer = setTimeout(() => { clickTimer = null; this.#toggleNode(id) }, 220)
      })
      g.addEventListener('dblclick', (ev) => {
        ev.stopPropagation()
        if (clickTimer) { clearTimeout(clickTimer); clickTimer = null }
        window.location.href = this.#classPath(id)
      })
      g.addEventListener('contextmenu', (ev) => {
        ev.preventDefault(); ev.stopPropagation()
        this.#hideTip()
        this.#showMenu(ev.clientX, ev.clientY, id)
      })
      g.addEventListener('mouseenter', (ev) => {
        // light incident edges
        ;(incidentEdges.get(id) || []).forEach((rec) => { if (rec !== R.hoveredEdge) { R.nodeLit.add(rec); rec.setHover(true) } })
        this.#showTip(ev, n, id)
      })
      g.addEventListener('mousemove', (ev) => this.#positionTip(ev.clientX, ev.clientY))
      g.addEventListener('mouseleave', () => {
        ;(incidentEdges.get(id) || []).forEach((rec) => { if (R.nodeLit.has(rec)) { R.nodeLit.delete(rec); rec.setHover(false) } })
        this.#hideTip()
      })
    })
    // F fits the current selection; keep it panel-scoped via canvas focus
    this.canvasTarget.tabIndex = -1
    this.canvasTarget.addEventListener('keydown', (ev) => {
      if (ev.key === 'f' || ev.key === 'F') { ev.preventDefault(); this.#fitToSelection() }
    })
    this.canvasTarget.addEventListener('pointerenter', () => this.canvasTarget.focus({ preventScroll: true }))
    document.addEventListener('keydown', this._escHandler = (ev) => { if (ev.key === 'Escape') this.#clearSelection() })
  }

  #wireBackground (svg) {
    svg.addEventListener('click', () => this.#clearSelection())
    svg.addEventListener('contextmenu', (ev) => {
      // only fire the background menu when the target isn't a node/edge
      if (ev.target.closest('.entity-graph__node') || ev.target.classList.contains('entity-graph__edge-hit')) return
      ev.preventDefault()
      this.#showMenu(ev.clientX, ev.clientY, null)
    })
  }

  #toggleNode (id) {
    const s = this._sel; s.traceId = null
    if (s.nodes.has(id)) s.nodes.delete(id); else s.nodes.add(id)
    this.#applyFocus()
  }

  #toggleEdge (rec) {
    const s = this._sel; s.traceId = null
    if (s.edges.has(rec)) s.edges.delete(rec); else s.edges.add(rec)
    this.#applyFocus()
  }

  #traceNode (id) {
    const s = this._sel; s.nodes.clear(); s.edges.clear()
    s.traceId = (s.traceId === id) ? null : id
    this.#applyFocus()
  }

  #clearSelection () {
    const s = this._sel
    if (s.traceId || s.nodes.size || s.edges.size) { s.traceId = null; s.nodes.clear(); s.edges.clear(); this.#applyFocus() }
  }

  // reachable set (transitive) upward from an id over the up-adjacency
  #traceSet () {
    const s = this._sel; if (!s.traceId) return null
    const R = this._render; const seen = new Set(); const stack = [s.traceId]
    while (stack.length) { const x = stack.pop(); if (seen.has(x)) continue; seen.add(x); (R.fullAdj.get(x) || []).forEach((t) => stack.push(t)) }
    return seen
  }

  #applyFocus () {
    const R = this._render; if (!R) return
    const s = this._sel
    const active = s.traceId || s.nodes.size > 0 || s.edges.size > 0
    R.kg.style.display = active ? 'none' : ''
    if (!active) {
      R.edgeRecs.forEach((r) => r.el.classList.remove('entity-graph__edge--dim', 'entity-graph__edge--sel'))
      R.nodeEls.forEach((g) => g.classList.remove('entity-graph__node--dim', 'entity-graph__node--sel'))
      R.labelReqs.forEach((r) => r.els.forEach((el) => el.classList.remove('entity-graph__edge-label--dim', 'entity-graph__edge-label-bg--dim')))
      return
    }
    const tf = this.#traceSet()
    const litNodes = new Set(tf || [])
    const litEdges = new Set()
    if (!tf) {
      s.nodes.forEach((id) => litNodes.add(id))
      s.edges.forEach((rec) => { litEdges.add(rec); litNodes.add(rec.from); litNodes.add(rec.to) })
      R.edgeRecs.forEach((rec) => { if (s.nodes.has(rec.from) && s.nodes.has(rec.to)) litEdges.add(rec) })
    }
    const litEdge = (rec) => tf ? (tf.has(rec.from) && tf.has(rec.to)) : litEdges.has(rec)
    R.nodeEls.forEach((g, id) => {
      g.classList.toggle('entity-graph__node--dim', !litNodes.has(id))
      g.classList.toggle('entity-graph__node--sel', s.nodes.has(id))
    })
    const edgeSelected = (rec) => s.edges.has(rec) || (s.nodes.has(rec.from) && s.nodes.has(rec.to))
    R.edgeRecs.forEach((rec) => {
      const on = litEdge(rec)
      rec.el.classList.toggle('entity-graph__edge--dim', !on)
      rec.el.classList.toggle('entity-graph__edge--sel', edgeSelected(rec))
    })
    R.labelReqs.forEach((r) => {
      const rec = R.edgeRecs.find((e) => e.from === r.from && e.to === r.to)
      const on = rec ? litEdge(rec) : false
      r.els.forEach((el) => {
        el.classList.toggle(el.classList.contains('entity-graph__edge-label-bg') ? 'entity-graph__edge-label-bg--dim' : 'entity-graph__edge-label--dim', !on)
      })
    })
  }

  #litNodesNow () {
    const s = this._sel
    if (s.traceId) { const tf = this.#traceSet(); return tf ? new Set(tf) : new Set() }
    const set = new Set(s.nodes)
    s.edges.forEach((rec) => { set.add(rec.from); set.add(rec.to) })
    return set
  }

  #fitToSelection () {
    const lit = this.#litNodesNow()
    if (!lit.size) { this._zoomApi && this._zoomApi.recenter(); return }
    const L = this._layout; const nodeH = this.#effNodeH()
    let x0 = Infinity; let y0 = Infinity; let x1 = -Infinity; let y1 = -Infinity
    lit.forEach((id) => {
      const n = L.nodes.get(id); if (!n) return
      x0 = Math.min(x0, n.x - n.width / 2); x1 = Math.max(x1, n.x + n.width / 2)
      y0 = Math.min(y0, n.y - nodeH / 2); y1 = Math.max(y1, n.y + nodeH / 2)
    })
    if (x1 < x0) return
    this._zoomApi && this._zoomApi.fitTo({ x: x0, y: y0, w: x1 - x0, h: y1 - y0 })
  }

  // --- context menu ---------------------------------------------------------

  #showMenu (clientX, clientY, nodeId) {
    this.#hideMenu()
    const s = this._sel
    const hasSel = s.traceId || s.nodes.size || s.edges.size
    const items = []
    if (nodeId) {
      const sid = shortId(nodeId)
      items.push({ label: s.nodes.has(nodeId) ? 'Deselect node' : 'Select node', run: () => this.#toggleNode(nodeId) })
      items.push({ label: 'Highlight path', run: () => this.#traceNode(nodeId) })
      items.push({ label: 'Fit to selection (F)', disabled: !hasSel, run: () => this.#fitToSelection() })
      items.push({ label: 'Open class', run: () => { window.location.href = this.#classPath(nodeId) } })
      items.push({ separator: true })
      items.push({ label: sid ? ('Copy ' + sid) : 'Copy short-id', disabled: !sid, run: () => this.#copyText(sid) })
      items.push({ label: 'Copy IRI', run: () => this.#copyText(nodeId) })
      items.push({ separator: true })
    } else {
      items.push({ label: 'Fit to selection (F)', disabled: !hasSel, run: () => this.#fitToSelection() })
      items.push({ label: 'Fit whole graph', run: () => this._zoomApi && this._zoomApi.recenter() })
      items.push({ separator: true })
    }
    items.push({ label: 'Clear all', disabled: !hasSel, run: () => this.#clearSelection() })

    const menu = document.createElement('div')
    menu.style.cssText = 'position:fixed;z-index:3000;background:#fff;border:1px solid #cfd8e2;border-radius:6px;box-shadow:0 2px 12px rgba(0,0,0,.18);padding:4px 0;font:13px -apple-system,sans-serif;min-width:150px'
    items.forEach((it) => {
      if (it.separator) { const hr = document.createElement('div'); hr.style.cssText = 'height:1px;background:#eef2f6;margin:4px 0'; menu.append(hr); return }
      const el = document.createElement('div')
      el.textContent = it.label
      el.style.cssText = 'padding:5px 14px;cursor:pointer;color:' + (it.disabled ? '#b3bdc9' : '#28374a')
      if (!it.disabled) {
        el.addEventListener('mouseenter', () => { el.style.background = '#eef3f8' })
        el.addEventListener('mouseleave', () => { el.style.background = '' })
        el.addEventListener('click', () => { this.#hideMenu(); it.run && it.run() })
      }
      menu.append(el)
    })
    document.body.append(menu)
    // clamp into viewport
    const r = menu.getBoundingClientRect()
    menu.style.left = Math.min(clientX, window.innerWidth - r.width - 6) + 'px'
    menu.style.top = Math.min(clientY, window.innerHeight - r.height - 6) + 'px'
    this._menu = menu
    this._menuDismiss = () => this.#hideMenu()
    setTimeout(() => document.addEventListener('click', this._menuDismiss, { once: true }), 0)
  }

  #hideMenu () { this._menu?.remove(); this._menu = null }

  #copyText (text) {
    const done = () => this.#toast('Copied ' + text)
    if (navigator.clipboard?.writeText) navigator.clipboard.writeText(text).then(done, done)
    else { const ta = document.createElement('textarea'); ta.value = text; document.body.append(ta); ta.select(); try { document.execCommand('copy') } catch (_) {} ta.remove(); done() }
  }

  #toast (msg) {
    let t = this._toastEl
    if (!t) {
      t = document.createElement('div'); this._toastEl = t
      t.style.cssText = 'position:fixed;left:50%;bottom:26px;transform:translateX(-50%);z-index:3000;background:#1b2a3a;color:#fff;font:13px -apple-system,sans-serif;padding:7px 14px;border-radius:7px;box-shadow:0 2px 10px rgba(0,0,0,.25);opacity:0;transition:opacity .15s'
      document.body.append(t)
    }
    t.textContent = msg; t.style.opacity = '1'
    clearTimeout(this._toastT); this._toastT = setTimeout(() => { t.style.opacity = '0' }, 1400)
  }

  // --- popup / tooltip ------------------------------------------------------

  #ensureTip () {
    if (this._tip) return this._tip
    const tip = document.createElement('div')
    tip.style.cssText = 'position:fixed;z-index:2500;max-width:570px;background:#fff;border:1px solid #d4dde8;border-radius:8px;box-shadow:0 4px 20px rgba(0,0,0,.16);padding:10px 13px;font:13px -apple-system,sans-serif;color:#28374a;pointer-events:none;display:none;line-height:1.45'
    document.body.append(tip)
    this._tip = tip
    return tip
  }

  #esc (s) { const d = document.createElement('div'); d.textContent = String(s == null ? '' : s); return d.innerHTML }

  #showTip (ev, n, id) {
    const tip = this.#ensureTip()
    const label = this.#effLabel(n)
    const sid = shortId(id)
    const pill = sid ? ` <span style="display:inline-block;font-size:10.5px;font-weight:600;padding:1px 6px;margin-left:5px;border-radius:8px;background:#eef2f7;color:#5a6b82;vertical-align:middle">${this.#esc(sid)}</span>` : ''
    const parents = this.#isaParents(id).map((l) => this.#esc(l))
    const def = this.opts.useUpperInfo && n.upper && n.upper.definition ? n.upper.definition : n.definition
    const syn = this.#effSynonyms(n)
    const src = (this.opts.useUpperInfo && n.upper && (n.upper.definition || n.upper.label)) ? n.upper.source : ''
    const srcTag = src ? ` <span style="font-size:10px;font-weight:600;color:#1c7a63;background:#dff3ee;border:1px solid #a9ddd0;border-radius:8px;padding:1px 6px;margin-left:4px;vertical-align:middle">from ${this.#esc(src)}</span>` : ''
    tip.innerHTML = `<b style="color:#1b2a3a">${this.#esc(label)}</b>${pill}${srcTag}` +
      `<div style="margin-top:4px;color:#4a5b6e">${parents.length ? ('is-a &rarr; ' + parents.join(', ')) : '<i>no is-a parents in graph</i>'}</div>` +
      (syn.length ? `<div style="margin-top:6px;color:#4a5b6e"><span style="font-size:10px;font-weight:700;text-transform:uppercase;color:#8794a5">Synonym${syn.length > 1 ? 's' : ''}</span> ${syn.map((x) => this.#esc(x)).join(', ')}</div>` : '') +
      (def ? `<div style="margin-top:5px;color:#6a7787;font-style:italic">${this.#esc(def)}</div>` : '')
    tip.style.display = 'block'
    this.#positionTip(ev.clientX, ev.clientY)
  }

  #positionTip (mx, my) {
    const tip = this._tip; if (!tip || tip.style.display === 'none') return
    const r = tip.getBoundingClientRect(); const pad = 12
    let x = mx + 16; let y = my + 16
    if (x + r.width > window.innerWidth - pad) x = mx - r.width - 16
    if (y + r.height > window.innerHeight - pad) y = my - r.height - 16
    tip.style.left = Math.max(pad, x) + 'px'
    tip.style.top = Math.max(pad, y) + 'px'
  }

  #hideTip () { if (this._tip) this._tip.style.display = 'none' }

  #isaParents (id) {
    const out = []
    this.edges.forEach((e) => { if (e.kind === 'is-a' && e.from === id) { const t = this._layout.nodes.get(e.to); if (t) out.push(this.#effLabel(t)) } })
    return out
  }

  #effSynonyms (n) {
    const s = (this.opts.useUpperInfo && n.upper && n.upper.synonyms && n.upper.synonyms.length) ? n.upper.synonyms : (n.synonyms || [])
    return Array.isArray(s) ? s.filter(Boolean) : []
  }

  // --- search ---------------------------------------------------------------

  #runSearch () {
    const R = this._render; if (!R) return
    const q = (this._search?.value || '').trim().toLowerCase()
    let total = 0
    R.nodeEls.forEach((g, id) => {
      const n = this._layout.nodes.get(id)
      const match = q && (this.#effLabel(n) || '').toLowerCase().includes(q)
      g.classList.toggle('entity-graph__node--match', !!match)
      if (match) total++
    })
    if (this._searchCount) this._searchCount.textContent = q ? (total ? `${total} match${total > 1 ? 'es' : ''}` : 'no matches') : ''
    if (q && total) {
      const ids = new Set()
      R.nodeEls.forEach((g, id) => { if (g.classList.contains('entity-graph__node--match')) ids.add(id) })
      const L = this._layout; const nodeH = this.#effNodeH()
      let x0 = Infinity; let y0 = Infinity; let x1 = -Infinity; let y1 = -Infinity
      ids.forEach((id) => { const n = L.nodes.get(id); if (!n) return; x0 = Math.min(x0, n.x - n.width / 2); x1 = Math.max(x1, n.x + n.width / 2); y0 = Math.min(y0, n.y - nodeH / 2); y1 = Math.max(y1, n.y + nodeH / 2) })
      if (x1 >= x0) this._zoomApi && this._zoomApi.fitTo({ x: x0, y: y0, w: x1 - x0, h: y1 - y0 })
    }
  }

  // --- zoom / pan / minimap -------------------------------------------------

  #installZoom (svg, vp, world) {
    const canvas = this.canvasTarget
    const winSize = () => {
      const r = canvas.getBoundingClientRect()
      return { w: r.width || 900, h: r.height || 560 }
    }
    let { w: winW, h: winH } = winSize()
    const fitScale = () => Math.min(winW / world.w, winH / world.h)
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
        zoomAt(ev.clientX - r.left, ev.clientY - r.top, Math.exp(-ev.deltaY * 0.0015))
        return
      }
      // Plain wheel = pan the graph, so scrolling over the canvas moves the graph
      // rather than the page. Apply the delta, clamp, and see if anything actually
      // moved: if the graph is already pinned at the edge in that direction (or fits
      // entirely), nothing moves — so let the event through and the page scrolls
      // normally. This keeps the user from ever being trapped at the graph's edge.
      const dx = ev.shiftKey ? ev.deltaY : ev.deltaX // shift+wheel scrolls horizontally
      const dy = ev.shiftKey ? 0 : ev.deltaY
      const beforeX = tx; const beforeY = ty
      tx -= dx; ty -= dy; clampPan()
      if (tx === beforeX && ty === beforeY) return // couldn't move → page scrolls
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
    const endDrag = (ev) => { if (!dragging) return; dragging = false; canvas.classList.remove('entity-graph__canvas--panning'); try { svg.releasePointerCapture(ev.pointerId) } catch (_) {} }
    svg.addEventListener('pointerup', endDrag)
    svg.addEventListener('pointercancel', endDrag)
    svg.addEventListener('click', (ev) => { if (moved) { ev.stopPropagation(); moved = false } }, true)

    // zoom control buttons
    const zmod = (navigator.platform || '').toLowerCase().includes('mac') ? '⌘' : 'Ctrl'
    const ctl = document.createElement('div'); ctl.className = 'entity-graph__zoom'
    ctl.innerHTML = `<button data-z="in" title="Zoom in (${zmod}+scroll)">+</button><button data-z="out" title="Zoom out (${zmod}+scroll)">−</button><button data-z="fit" title="Fit to view">⤢</button>`
    ctl.querySelector('[data-z="in"]').addEventListener('click', () => zoomAt(winW / 2, winH / 2, 1.3))
    ctl.querySelector('[data-z="out"]').addEventListener('click', () => zoomAt(winW / 2, winH / 2, 1 / 1.3))
    ctl.querySelector('[data-z="fit"]').addEventListener('click', () => { userZoomed = false; recenter() })
    canvas.append(ctl)

    // minimap
    const mmScale = Math.min(MINIMAP_MAX / world.w, MINIMAP_MAX / world.h)
    const mmW = Math.round(world.w * mmScale); const mmH = Math.round(world.h * mmScale)
    const mm = document.createElement('div'); mm.className = 'entity-graph__minimap'
    const mmSvg = document.createElementNS(SVG, 'svg')
    mmSvg.setAttribute('width', mmW); mmSvg.setAttribute('height', mmH)
    mmSvg.setAttribute('viewBox', `${world.x} ${world.y} ${world.w} ${world.h}`)
    const snap = vp.cloneNode(true); snap.removeAttribute('transform'); snap.style.pointerEvents = 'none'
    mmSvg.append(snap)
    const mmView = document.createElementNS(SVG, 'rect'); mmView.setAttribute('class', 'entity-graph__minimap-view')
    mmSvg.append(mmView)
    mm.append(mmSvg); canvas.append(mm)
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
    mm.addEventListener('pointerdown', (ev) => { mmDown = true; mm.setPointerCapture(ev.pointerId); mmGoto(ev); ev.stopPropagation() })
    mm.addEventListener('pointermove', (ev) => { if (mmDown) mmGoto(ev) })
    mm.addEventListener('pointerup', (ev) => { mmDown = false; try { mm.releasePointerCapture(ev.pointerId) } catch (_) {} })
    if (world.w <= winW + 1 && world.h <= winH + 1) mm.style.display = 'none'

    // reflow on canvas resize (until the user takes control) — the pane is often
    // display:none when the frame first loads, so the initial fit needs the real size.
    const reflow = () => {
      const s = winSize(); if (!s.w || !s.h) return
      winW = s.w; winH = s.h; fitK = fitScale(); minK = fitK * 0.9
      if (!userZoomed) recenter(); else { clampPan(); apply() }
    }

    this._zoomApi = { recenter, fitTo, reflow }
    recenter()
    // a couple of deferred fits to catch the pane becoming visible
    requestAnimationFrame(reflow)
    setTimeout(reflow, 120)
  }
}
