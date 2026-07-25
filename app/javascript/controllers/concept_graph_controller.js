import { Controller } from '@hotwired/stimulus'
import * as dagre from '@dagrejs/dagre'
import { select } from 'd3-selection'
import { zoom, zoomIdentity } from 'd3-zoom'

const SVG_NS = 'http://www.w3.org/2000/svg'

// Node box metrics (mirrors the WebProtege entity graph: rounded rects with a
// little horizontal padding around a single line of centred text).
const NODE_H = 34
const NODE_PAD_X = 14
const NODE_MIN_W = 44
const RANK_SEP = 44
const NODE_SEP = 24
const EDGE_SEP = 10

// Renders the is-a ancestor chain of a class as a node-link graph, laid out with
// dagre and drawn as hand-built SVG (same approach as WebProtege's Graph2Svg),
// with d3 zoom/pan. The selected class sits at the bottom and its superclasses
// rise to the top. Double-clicking a node navigates to that class.
//
// The full graph is delivered in one payload from the server (no client fetches).
//
// Connects to data-controller="concept-graph"
export default class extends Controller {
  static targets = ['canvas', 'gate', 'empty']
  static values = {
    graph: Object,
    ontology: String,
    large: String
  }

  connect () {
    const graph = this.graphValue || {}
    this.nodes = graph.nodes || []
    this.edges = graph.edges || []

    if (this.nodes.length <= 1 && this.edges.length === 0) {
      this.emptyTarget.classList.remove('d-none')
      return
    }

    if (this.largeValue === 'true') {
      this.gateTarget.classList.remove('d-none')
    } else {
      this.#render()
    }
  }

  disconnect () {
    this._resizeObserver?.disconnect()
    this._resizeObserver = null
  }

  // Called from the "Show graph anyway" button on the large-graph gate.
  renderAnyway () {
    this.gateTarget.classList.add('d-none')
    this.#render()
  }

  // --- rendering ------------------------------------------------------------

  #render () {
    // multigraph so a class can have several distinct edges to the same filler
    // (e.g. two object properties pointing at the same class).
    const g = new dagre.graphlib.Graph({ multigraph: true })
    // Lay out top-to-bottom (dagre's default, well-tested edge routing) and flip
    // vertically ourselves afterwards to get the bottom-to-top reading (selected
    // class at the bottom, superclasses rising). dagre's own rankdir:'BT' mirrors
    // node coordinates but leaves multi-point edge waypoints on the wrong axis,
    // so BT edges bend the wrong way; laying out TB avoids that bug entirely.
    g.setGraph({ rankdir: 'TB', ranksep: RANK_SEP, nodesep: NODE_SEP, edgesep: EDGE_SEP, marginx: 24, marginy: 24 })
    g.setDefaultEdgeLabel(() => ({}))

    this.nodes.forEach((n) => {
      const w = Math.max(NODE_MIN_W, this.#measureText(n.label) + NODE_PAD_X * 2)
      g.setNode(n.id, { label: n.label, width: w, height: NODE_H, data: n })
    })
    this.edges.forEach((e, i) => {
      if (!g.hasNode(e.from) || !g.hasNode(e.to)) return
      // Edges are {from, to}. tail=from, head=to puts the arrow (marker-end, drawn
      // at the head) on the target — parent for is-a, filler for a relationship.
      // In this TB layout the target (head) sits BELOW the source; the vertical
      // flip then places it above and turns the arrow to point upward at it.
      const cfg = { kind: e.kind }
      if (e.label) {
        cfg.label = e.label
        cfg.width = this.#measureText(e.label) + 8
        cfg.height = 14
        cfg.labelpos = 'c'
      }
      g.setEdge(e.from, e.to, cfg, `e${i}`)
    })

    dagre.layout(g)
    this.#flipVertical(g)
    this.#tidyEdgeWaypoints(g)
    this._layout = g

    const svg = this.#buildSvg(g)
    this.canvasTarget.replaceChildren(svg)
    this.#installZoom(svg)
  }

  // Mirror the laid-out graph about the horizontal axis (y' = H - y) so a
  // top-to-bottom dagre layout reads bottom-to-top. Mutates node centres, edge
  // waypoints, and edge label positions in place; x is untouched.
  #flipVertical (g) {
    const h = g.graph().height
    g.nodes().forEach((id) => { const n = g.node(id); n.y = h - n.y })
    g.edges().forEach((e) => {
      const ed = g.edge(e)
      ed.points = ed.points.map((p) => ({ x: p.x, y: h - p.y }))
      if (ed.y != null) ed.y = h - ed.y
    })
  }

  // Straighten stray edge waypoints. dagre occasionally routes an interior bend
  // point OUTSIDE the horizontal span between an edge's two endpoints, which
  // reads as the edge jogging away from its target before turning back. Clamp
  // any such interior point's x back into the [min,max] endpoint span; endpoints
  // and already-well-placed bends are left untouched.
  #tidyEdgeWaypoints (g) {
    g.edges().forEach((e) => {
      const ed = g.edge(e)
      const pts = ed.points
      if (!pts || pts.length < 3) return
      const sx = g.node(e.v).x
      const tx = g.node(e.w).x
      const lo = Math.min(sx, tx)
      const hi = Math.max(sx, tx)
      for (let i = 1; i < pts.length - 1; i++) {
        if (pts[i].x < lo) pts[i].x = lo
        else if (pts[i].x > hi) pts[i].x = hi
      }
    })
  }

  // Content bounds derived directly from the laid-out node rectangles
  // (deterministic and synchronous, unlike getBBox which depends on render
  // timing). Edge polylines stay within these bounds.
  #contentBounds (g) {
    let minX = Infinity; let minY = Infinity; let maxX = -Infinity; let maxY = -Infinity
    g.nodes().forEach((id) => {
      const n = g.node(id)
      minX = Math.min(minX, n.x - n.width / 2)
      maxX = Math.max(maxX, n.x + n.width / 2)
      minY = Math.min(minY, n.y - n.height / 2)
      maxY = Math.max(maxY, n.y + n.height / 2)
    })
    if (!isFinite(minX)) return null
    return { x: minX, y: minY, width: maxX - minX, height: maxY - minY }
  }

  #buildSvg (g) {
    const svg = document.createElementNS(SVG_NS, 'svg')
    svg.setAttribute('class', 'entity-graph__svg')
    svg.setAttribute('width', '100%')
    svg.setAttribute('height', '100%')

    // Arrowhead defs: closed = is-a, open = relationship (kept for parity even
    // though BioPortal only surfaces is-a today).
    const defs = document.createElementNS(SVG_NS, 'defs')
    defs.appendChild(this.#arrowMarker('eg-arrow-closed', true))
    defs.appendChild(this.#arrowMarker('eg-arrow-open', false))
    svg.appendChild(defs)

    // Outer group is the pan/zoom target; edges under nodes.
    const viewport = document.createElementNS(SVG_NS, 'g')
    viewport.setAttribute('data-viewport', '')
    svg.appendChild(viewport)

    const edgesGroup = document.createElementNS(SVG_NS, 'g')
    viewport.appendChild(edgesGroup)
    const nodesGroup = document.createElementNS(SVG_NS, 'g')
    viewport.appendChild(nodesGroup)

    g.edges().forEach((e) => edgesGroup.appendChild(this.#buildEdge(g.edge(e))))
    g.nodes().forEach((id) => nodesGroup.appendChild(this.#buildNode(id, g.node(id))))

    this._viewport = viewport
    return svg
  }

  #arrowMarker (id, closed) {
    const marker = document.createElementNS(SVG_NS, 'marker')
    marker.setAttribute('id', id)
    marker.setAttribute('viewBox', '0 0 10 10')
    marker.setAttribute('markerWidth', '8')
    marker.setAttribute('markerHeight', '8')
    marker.setAttribute('refX', '9')
    marker.setAttribute('refY', '5')
    marker.setAttribute('orient', 'auto')
    marker.setAttribute('class', `entity-graph__arrow ${closed ? 'entity-graph__arrow--is-a' : 'entity-graph__arrow--rel'}`)
    const path = document.createElementNS(SVG_NS, 'path')
    path.setAttribute('d', closed ? 'M 1,1 L 9,5 L 1,9 Z' : 'M 1,1 L 9,5 L 1,9')
    marker.appendChild(path)
    return marker
  }

  #buildEdge (edge) {
    const kind = edge.kind || 'is-a'
    const group = document.createElementNS(SVG_NS, 'g')
    group.setAttribute('class', `entity-graph__edge-group entity-graph__edge-group--${kind}`)

    const path = document.createElementNS(SVG_NS, 'path')
    path.setAttribute('class', `entity-graph__edge entity-graph__edge--${kind}`)
    path.setAttribute('fill', 'none')
    const d = edge.points.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x},${p.y}`).join(' ')
    path.setAttribute('d', d)
    // Closed arrowhead for is-a, open arrowhead for a relationship (WebProtege).
    path.setAttribute('marker-end', `url(#${kind === 'is-a' ? 'eg-arrow-closed' : 'eg-arrow-open'})`)
    group.appendChild(path)

    // Relationship edges are labelled with the property, on a small backing rect
    // so the text stays readable over the edge line.
    if (edge.label && edge.x != null && edge.y != null) {
      const w = this.#measureText(edge.label) + 8
      const h = 16
      const bg = document.createElementNS(SVG_NS, 'rect')
      bg.setAttribute('class', 'entity-graph__edge-label-bg')
      bg.setAttribute('x', edge.x - w / 2)
      bg.setAttribute('y', edge.y - h / 2)
      bg.setAttribute('width', w)
      bg.setAttribute('height', h)
      bg.setAttribute('rx', '3')
      group.appendChild(bg)

      const text = document.createElementNS(SVG_NS, 'text')
      text.setAttribute('class', 'entity-graph__edge-label')
      text.setAttribute('x', edge.x)
      text.setAttribute('y', edge.y)
      text.setAttribute('text-anchor', 'middle')
      text.setAttribute('dominant-baseline', 'central')
      text.textContent = edge.label
      group.appendChild(text)
    }
    return group
  }

  #buildNode (id, node) {
    const data = node.data || {}
    // All classes get the same box; only the selected class is styled apart.
    const cls = 'entity-graph__node' + (data.selected ? ' entity-graph__node--selected' : '')
    const group = document.createElementNS(SVG_NS, 'g')
    group.setAttribute('class', cls)
    group.setAttribute('data-node-id', id)

    const rect = document.createElementNS(SVG_NS, 'rect')
    rect.setAttribute('class', 'entity-graph__node-shape')
    rect.setAttribute('x', node.x - node.width / 2)
    rect.setAttribute('y', node.y - node.height / 2)
    rect.setAttribute('width', node.width)
    rect.setAttribute('height', node.height)
    rect.setAttribute('rx', '4')
    rect.setAttribute('ry', '4')
    group.appendChild(rect)

    const text = document.createElementNS(SVG_NS, 'text')
    text.setAttribute('class', 'entity-graph__node-label')
    text.setAttribute('x', node.x)
    text.setAttribute('y', node.y)
    text.setAttribute('text-anchor', 'middle')
    text.setAttribute('dominant-baseline', 'central')
    text.textContent = node.label
    group.appendChild(text)

    // Double-click navigates to the class (single-click does nothing — the
    // graph is fully materialised, there is nothing to expand).
    group.addEventListener('dblclick', (evt) => {
      evt.preventDefault()
      window.location.href = this.#classPath(id)
    })
    return group
  }

  #classPath (iri) {
    return `/ontologies/${encodeURIComponent(this.ontologyValue)}?p=classes&conceptid=${encodeURIComponent(iri)}`
  }

  // --- zoom / pan -----------------------------------------------------------

  #installZoom (svg) {
    const viewport = this._viewport
    this._zoom = zoom().scaleExtent([0.1, 4]).on('zoom', (event) => {
      viewport.setAttribute('transform', event.transform.toString())
    })
    this._svgSel = select(svg)
    // Auto-fit stays on until the user makes a deliberate zoom/pan gesture. Only
    // a genuine drag or wheel counts — flagged from d3-zoom's own start event
    // when it carries a real DOM sourceEvent that is a pointer/mouse/wheel one
    // (programmatic .transform() calls have no such sourceEvent).
    this._userZoomed = false
    this._zoom.on('start.userflag', (event) => {
      const src = event.sourceEvent
      if (src && /^(pointer|mouse|wheel|touch)/.test(src.type)) this._userZoomed = true
    })
    this._svgSel.call(this._zoom)
    // The tab pane is often display:none when the frame first loads, so the
    // canvas has no size yet. Fit once it does, and re-fit on every resize (the
    // pane becoming visible, its size settling) until the user zooms — the last
    // resize carries the correct canvas dimensions.
    this._readyFrames = 0
    this.#fitWhenReady()
    if (!this._resizeObserver && 'ResizeObserver' in window) {
      this._resizeObserver = new ResizeObserver(() => this.#fit())
      this._resizeObserver.observe(this.canvasTarget)
    }
  }

  #fitWhenReady (attempt = 0) {
    // The pane may stay display:none for a while (until the user opens the tab),
    // so poll persistently — but stop a couple seconds after the canvas first
    // has a size, by which point it has settled. The ResizeObserver handles any
    // later size change (and re-fits) as long as the user hasn't zoomed.
    const rect = this.canvasTarget.getBoundingClientRect()
    const ready = rect.width && rect.height
    if (ready) {
      this.#fit()
      this._readyFrames = (this._readyFrames || 0) + 1
    }
    if (!this._readyFrames || this._readyFrames < 30) {
      requestAnimationFrame(() => this.#fitWhenReady(attempt + 1))
    }
  }

  #fit () {
    if (this._userZoomed) return
    const box = this.#contentBounds(this._layout)
    if (!box || !box.width || !box.height) return
    const rect = this.canvasTarget.getBoundingClientRect()
    if (!rect.width || !rect.height) return // still hidden; let #fitWhenReady retry
    const cw = rect.width
    const ch = rect.height
    // Scale to fit, never magnifying past 1:1, leaving a margin around the graph.
    const scale = Math.min(1, 0.86 * Math.min(cw / box.width, ch / box.height))
    // Translate so the content centre lands at the canvas centre.
    const tx = (cw - box.width * scale) / 2 - box.x * scale
    const ty = (ch - box.height * scale) / 2 - box.y * scale
    this._svgSel.call(this._zoom.transform, zoomIdentity.translate(tx, ty).scale(scale))
  }

  // --- text measuring -------------------------------------------------------

  // Measure label width with a canvas 2D context (reliable and synchronous,
  // unlike getComputedTextLength on an off-screen SVG, which can report 0). The
  // font must match the .entity-graph__node-label CSS so boxes fit their text.
  #measureText (label) {
    if (!this._measureCtx) {
      this._measureCtx = document.createElement('canvas').getContext('2d')
      const sample = this.element.querySelector('.entity-graph__node-label')
      if (sample) {
        const cs = window.getComputedStyle(sample)
        this._measureFont = `${cs.fontStyle} ${cs.fontWeight} ${cs.fontSize} ${cs.fontFamily}`
      } else {
        this._measureFont = '400 13px sans-serif'
      }
    }
    this._measureCtx.font = this._measureFont
    return Math.ceil(this._measureCtx.measureText(label || '').width)
  }
}
