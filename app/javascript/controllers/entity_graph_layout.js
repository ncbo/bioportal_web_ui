// Tidy ancestor-tree layout + edge routing for the entity graph.
//
// This is a faithful, behaviour-preserving extraction of the layout engine
// prototyped in the offline harness. It is a pure module: the only DOM contact
// is an offscreen canvas 2D context used to measure label widths (needed to size
// node boxes) — there is no document/element manipulation here. All rendering,
// zoom, and interaction live in the Stimulus controller that consumes this.
//
// The engine lays a class's is-a + relationship neighbourhood out as a tidy tree:
// rank by longest is-a-DAG path (then relationship relaxation), Reingold-Tilford
// contour placement, subtree-pull crossing reduction, collector ordering, and
// x-relaxation toward neighbour barycentres. Edges are then routed straight by
// default and bowed only to clear node boxes (see routePath).

// ---- geometry constants -----------------------------------------------------
export const NODE_H_BASE = 34
export const PILL_H = 15          // height of the short-id chip added inside the box when showPills
export const PILL_PAD = 7         // extra white space beneath the chip (before the box edge)
const PAD_X = 14
const MIN_W = 44
const ROW_GAP = 56
const SIB_GAP = 14
const MARGIN = 24
// Wider gap between two same-rank siblings that have a relationship edge between
// them (a diamond base), so the arc + its label have room to breathe.
const REL_SIB_GAP = 96
// Extra gutter between two adjacent same-rank nodes that descend from DIFFERENT
// is-a parents (cousins), so distinct sibling groups read as separate clusters.
const COUSIN_GAP = SIB_GAP + 62

// ---- id helpers -------------------------------------------------------------
// Short compact id from an IRI: last path/fragment segment, with the OBO-style
// underscore turned into a colon (GO_0004672 -> GO:0004672).
export const shortId = (iri) => {
  if (!iri) return ''
  const s = String(iri).split(/[#/]/).pop() || ''
  return s.replace(/^([A-Za-z]+)_(\w+)$/, '$1:$2')
}
// Ontology acronym = the prefix before the colon of the short id (GO_0004672 -> GO).
export const ontoAcronym = (iri) => {
  const s = shortId(iri)
  const i = s.indexOf(':')
  return i > 0 ? s.slice(0, i) : ''
}
// Upper-ontology (BFO/COB) detector, by OBO short-id. Used both to treat these as
// collectors and — when hideUpper is on — to drop them from the graph entirely.
export const isUpperOnto = (id) => /(^|[#/])(BFO|COB)_\d+$/i.test(String(id || ''))

// ---- text measure -----------------------------------------------------------
// Measure label width with a shared canvas 2D context — reliable and synchronous,
// unlike getComputedTextLength on an off-screen SVG (which can report 0). The font
// must match the .entity-graph node-label CSS so boxes fit their text.
const MEASURE_FONT = '400 13px -apple-system, sans-serif'
let _ctx = null
export function measureText (t, font) {
  if (!_ctx) {
    _ctx = document.createElement('canvas').getContext('2d')
  }
  _ctx.font = font || MEASURE_FONT
  return Math.ceil(_ctx.measureText(t || '').width)
}

// relationship labels to omit entirely
const DROP_RELS = new Set(['in taxon'])

// ================= TIDY ANCESTOR TREE =================
// opts (all optional; defaults mirror the harness):
//   hideUpper, isaOnly, useUpperInfo, transitiveReduction, showPills : booleans
//   nodeH : effective node box height (grows when the short-id pill row is shown)
export function computeLayout (graph, opts = {}) {
  const HIDE_UPPER = !!opts.hideUpper
  const ISA_ONLY = !!opts.isaOnly
  const USE_UPPER_INFO = opts.useUpperInfo !== false // default true, as in the harness
  const TRANSITIVE_REDUCTION = opts.transitiveReduction !== false // default true
  const SHOW_PILLS = !!opts.showPills
  const NODE_H = opts.nodeH || NODE_H_BASE

  // Effective display label for a node: when useUpperInfo is on and the node carries
  // authoritative upper-ontology info (n.upper), prefer that ontology's real label
  // over the (often stub) imported one. (Only the label matters for layout — box width.)
  const effLabel = (n) => (USE_UPPER_INFO && n.upper && n.upper.label) ? n.upper.label : n.label

  const measure = (t) => measureText(t, MEASURE_FONT)
  const nodeW = (label) => Math.max(MIN_W, measure(label) + PAD_X * 2)

  // Drop unwanted relationships (e.g. "in taxon"), optionally drop upper-ontology
  // (BFO/COB) nodes, and prune any nodes that become disconnected from the selected
  // class as a result (the taxonomy lineage those relationships dragged in, or the
  // domain-top classes that were only reachable through a removed BFO parent).
  {
    // ISA_ONLY drops every relationship edge, leaving the pure is-a hierarchy; the
    // connectivity prune below then removes any node that was only reachable via a
    // relationship (a filler with no is-a path to the selected class).
    let ed = graph.edges.filter((e) => e.kind === 'is-a' || (!ISA_ONLY && !DROP_RELS.has((e.label || '').toLowerCase())))
    let ns = graph.nodes
    if (HIDE_UPPER) {
      ns = ns.filter((n) => n.selected || !isUpperOnto(n.id)) // never drop the selected class
      const kept = new Set(ns.map((n) => n.id))
      ed = ed.filter((e) => kept.has(e.from) && kept.has(e.to))
    }
    const sel = (ns.find((n) => n.selected) || {}).id
    let keep = new Set(ns.map((n) => n.id))
    if (sel) {
      // Connectivity from the selected class:
      //   - is-a edges are traversed UPWARD only (child -> parent), so we collect the
      //     selected class's ancestors but never descend a foreign is-a branch.
      //   - relationship edges are traversed BOTH ways: a relationship's target (and,
      //     through the upward is-a walk, that target's ancestors) belongs in the graph.
      // A fully-undirected walk was wrong: it climbed is-a up to the shared upper-
      // ontology root (entity/continuant) and then descended into unrelated subtrees
      // (quality, biological process, …), which have no path from the selected class
      // once the relationships that reached them are hidden.
      const adj = new Map()
      const add = (a, b) => { (adj.get(a) || adj.set(a, []).get(a)).push(b) }
      ed.forEach((e) => {
        if (e.kind === 'is-a') { add(e.from, e.to) } // upward only
        else if (!ISA_ONLY) { add(e.from, e.to); add(e.to, e.from) } // relationships both ways
      })
      keep = new Set([sel])
      const q = [sel]
      while (q.length) { const x = q.shift(); for (const y of (adj.get(x) || [])) if (!keep.has(y)) { keep.add(y); q.push(y) } }
    }
    graph = { nodes: ns.filter((n) => keep.has(n.id)), edges: ed.filter((e) => keep.has(e.from) && keep.has(e.to)) }
  }

  const nodes = new Map() // id -> {id,label,width, rank, primaryParent, children:[], _x,_depth}
  graph.nodes.forEach((n) => {
    // width fits the EFFECTIVE label (authoritative upper-ontology name when enabled),
    // and — when pills are shown — also the short-id chip
    let w = nodeW(effLabel(n))
    if (SHOW_PILLS) { const sid = shortId(n.id); if (sid) w = Math.max(w, measure(sid) + 14 + PAD_X) }
    nodes.set(n.id, { ...n, width: w, children: [] })
  })

  // Transitive reduction of the is-a relation: the parser's reasoner materialises
  // inferred subclass axioms, so a class can carry a direct is-a edge to an
  // ancestor it already reaches through a longer chain (e.g. A->tissue when
  // A->embryonic tissue->tissue). Drop those redundant shortcuts so each is-a
  // edge is an immediate (Hasse) link. (Relationships are not transitive.)
  const isaParents = new Map()
  graph.edges.forEach((e) => {
    if (e.kind === 'is-a' && nodes.has(e.from) && nodes.has(e.to)) {
      if (!isaParents.has(e.from)) isaParents.set(e.from, new Set())
      isaParents.get(e.from).add(e.to)
    }
  })
  const ancCache = new Map()
  function ancestors (id) {
    if (ancCache.has(id)) return ancCache.get(id)
    const s = new Set(); ancCache.set(id, s) // set early to tolerate cycles
    for (const p of (isaParents.get(id) || [])) { s.add(p); for (const a of ancestors(p)) s.add(a) }
    return s
  }
  nodes.forEach((_, id) => ancestors(id))
  const isaRedundant = (a, c) => { for (const b of (isaParents.get(a) || [])) { if (b !== c && ancestors(b).has(c)) return true } return false }
  // Two classes are is-a siblings if they share a direct is-a parent. A
  // relationship between siblings should draw as a diamond (both under the shared
  // parent), not stack one below the other.
  const sharesIsaParent = (a, b) => { const pa = isaParents.get(a); const pb = isaParents.get(b); if (!pa || !pb) return false; for (const p of pa) if (pb.has(p)) return true; return false }

  // "up-edges": both is-a AND relationship edges point subject(below) -> object
  // (above). Ranking and the tidy-tree backbone use this combined set, so a
  // relationship filler is placed above its source (WebProtege style) instead of
  // as a long horizontal cross-link.
  const up = new Map() // id -> [{to, kind, label}]
  graph.edges.forEach((e) => {
    // drop transitive is-a shortcuts (unless the option is off — then show every inferred
    // is-a edge, including redundant ones, so the full materialised hierarchy is visible)
    if (TRANSITIVE_REDUCTION && e.kind === 'is-a' && isaRedundant(e.from, e.to)) return
    if (!up.has(e.from)) up.set(e.from, [])
    up.get(e.from).push({ to: e.to, kind: e.kind, label: e.label })
  })

  // rank = longest path over up-edges: rank(n)=1+max(rank(targets)); roots=0.
  //
  // is-a edges form a DAG, but relationship up-edges can point back "up" against
  // is-a (e.g. apoptotic process has_part apoptotic signaling pathway, which is-a
  // apoptotic process — a 2-cycle). Ranking naively over the combined graph lets
  // the cycle guard truncate longest paths and mis-rank a node above one of its
  // OWN is-a ancestors. So rank the is-a DAG first (authoritative), then only let
  // a relationship push its filler DEEPER, never shallower — and never past an
  // edge that would contradict is-a.
  const rank = new Map()
  const isaRank = new Map()
  function computeIsaRank (id) {
    if (isaRank.has(id)) return isaRank.get(id)
    isaRank.set(id, 0) // provisional, guards is-a cycles (shouldn't exist)
    let r = 0
    for (const { to, kind } of (up.get(id) || [])) {
      if (kind !== 'is-a' || !nodes.has(to)) continue
      r = Math.max(r, computeIsaRank(to) + 1)
    }
    isaRank.set(id, r); return r
  }
  nodes.forEach((_, id) => computeIsaRank(id))
  // Relaxation: raise a filler to sit above its relationship target, but only when
  // that target is is-a-shallower (isaRank strictly less) — so a has_part back-edge
  // into an is-a ancestor is ignored for ranking and left as an overlay.
  nodes.forEach((_, id) => rank.set(id, isaRank.get(id)))
  let changed = true; let guard = 0
  while (changed && guard++ < nodes.size + 4) {
    changed = false
    nodes.forEach((_, id) => {
      for (const { to, kind } of (up.get(id) || [])) {
        if (!nodes.has(to)) continue
        if (kind === 'is-a') { continue } // already in isaRank baseline
        if (sharesIsaParent(id, to)) continue // sibling relationship → diamond, same rank
        if (isaRank.get(to) >= isaRank.get(id)) continue // don't rank a filler above an is-a peer/ancestor of the source
        const want = rank.get(to) + 1
        if (want > rank.get(id)) { rank.set(id, want); changed = true }
      }
    })
  }

  // Collector nodes: abstract high-fan-in classes near the top of the hierarchy
  // that unite otherwise-disparate branches (entity, continuant, occurrent,
  // role, chemical entity...). Heuristic: is-a in-degree > 5 AND in the top two
  // ranks (rank <= 1, i.e. a root or its direct child). Their edges are kept out
  // of the backbone and the sibling-ordering barycentre so the meaningful mid-
  // level structure lays out on its own; collectors then float above.
  const childCount = new Map()
  up.forEach((outs) => outs.forEach((e) => { if (e.kind === 'is-a' && nodes.has(e.to)) childCount.set(e.to, (childCount.get(e.to) || 0) + 1) }))
  const collector = new Set()
  // If the SELECTED class is itself an upper-ontology (BFO/COB) class, the whole
  // graph is upper ontology — there is no "domain structure" to keep clear of the
  // scaffolding, so nothing is a collector (everything renders as normal structure).
  const selNode = [...nodes.values()].find((n) => n.selected)
  const selIsUpper = selNode && isUpperOnto(selNode.id)
  if (!selIsUpper) {
    nodes.forEach((_, id) => {
      // Upper-ontology classes (BFO, COB) are ALWAYS collectors: they are the abstract
      // top-level categories (continuant, occurrent, independent continuant, ...) that
      // unite disparate branches, so they should float above the backbone regardless of
      // fan-in or rank. Matched by the OBO short-id prefix (…/obo/BFO_*, …/obo/COB_*).
      if (isUpperOnto(id)) { collector.add(id); return }
      // Otherwise: an abstract high-fan-in class in the top two ranks (a root or its
      // direct child with is-a in-degree > 5).
      if ((childCount.get(id) || 0) > 5 && (rank.get(id) || 0) <= 1) collector.add(id)
    })
  }

  // primary parent = deepest up-target, PREFERRING non-collector parents so a
  // collector doesn't become the backbone and fan its children into a wide arc.
  // y is set from rank (below), so a non-primary/collector parent is just an
  // overlay one or more ranks above.
  const primary = new Map() // id -> {to, kind, label}
  const overlays = [] // non-primary up-edges (curved)
  const better = (e, b) => {
    const re = rank.get(e.to); const rb = rank.get(b.to)
    if (re !== rb) return re > rb // deeper wins
    if ((e.kind === 'is-a') !== (b.kind === 'is-a')) return e.kind === 'is-a' // is-a wins tie
    return e.to < b.to // stable
  }
  nodes.forEach((n, id) => {
    const outs = (up.get(id) || []).filter((e) => nodes.has(e.to))
    if (outs.length === 0) return // root
    // A backbone (primary) parent must be strictly ABOVE (lower rank); a same-rank
    // target (a sibling relationship) is drawn as an overlay, giving a diamond.
    const above = outs.filter((e) => rank.get(e.to) < rank.get(id))
    if (above.length === 0) { outs.forEach((e) => overlays.push({ from: id, to: e.to, kind: e.kind, label: e.label })); return }
    const nonColl = above.filter((e) => !collector.has(e.to))
    const pool = nonColl.length ? nonColl : above // only fall back to a collector if it's the sole parent
    let best = pool[0]
    for (const e of pool) { if (better(e, best)) best = e }
    primary.set(id, best)
    nodes.get(best.to).children.push(id)
    for (const e of outs) { if (e !== best) overlays.push({ from: id, to: e.to, kind: e.kind, label: e.label }) }
  })

  // ---- dummy nodes for long edges (Sugiyama-style) ------------------------
  // An overlay that spans several ranks (e.g. `urinary bladder` is-a
  // `mesoderm-derived structure`, five ranks up) drawn as one curve has to bow
  // across the whole node field and ends up crossing unrelated edges. Instead we
  // break each long overlay into a chain of unit-rank segments through invisible
  // DUMMY nodes, one per intermediate rank. The dummies are real participants in
  // the rank rows: they take a slot (so real nodes leave a vertical corridor for
  // the edge) and they sit in the x-relaxation adjacency (so the corridor lines up
  // straight). The renderer then draws the edge as a smooth spline through the
  // dummy x-positions, weaving between nodes rather than bowing around them.
  //
  // Only overlays are broken up; tree (primary) edges are always unit-rank by
  // construction. Same-rank overlays (sibling relationship diamonds, span 0) and
  // unit-span overlays are left exactly as they were.
  let dummySeq = 0
  const dummyChains = new Map() // overlay key "from|to" -> [dummyId, dummyId, ...] top-to-... (ordered from just below `to` down to just above `from`)
  const isDummy = (id) => nodes.get(id)?.isDummy
  const longOverlays = overlays.filter((e) => {
    const rf = rank.get(e.from); const rt = rank.get(e.to)
    return rf != null && rt != null && Math.abs(rf - rt) >= 2
  })
  longOverlays.forEach((e) => {
    const rFrom = rank.get(e.from); const rTo = rank.get(e.to)
    // `to` is above (smaller rank) for an up-edge; guard either orientation.
    const hi = Math.min(rFrom, rTo); const lo = Math.max(rFrom, rTo)
    const chain = [] // dummy ids for the ranks strictly between hi and lo, ordered lo-1 .. hi+1
    for (let r = lo - 1; r > hi; r--) {
      const id = '__dummy__' + (dummySeq++)
      nodes.set(id, { id, label: '', width: 8, children: [], isDummy: true, _depth: r })
      rank.set(id, r)
      chain.push(id)
    }
    dummyChains.set(e.from + '|' + e.to, { chain, from: e.from, to: e.to, kind: e.kind, label: e.label })
  })

  // roots (no primary parent). Dummies are never roots (they have no primary
  // parent, but they must not be placed by the tidy tree — see below).
  const roots = [...nodes.keys()].filter((id) => !primary.has(id) && !isDummy(id))

  // virtual super-root over all roots so the forest is placed as one tidy tree
  const SUPER = '__super__'
  const superNode = { id: SUPER, label: '', width: 0, children: roots }

  // adjacency across the DRAWN edges (both directions) for crossing reduction and
  // the x-relaxation barycentre. Built from the transitively-reduced up-edge set
  // (`up`), NOT the raw graph — otherwise the relaxation would pull nodes toward
  // redundant is-a shortcuts that were dropped from the drawing (e.g. a phantom
  // breast cancer->cancer edge), distorting positions to straighten lines that
  // aren't there and bending the ones that are.
  const nbr = new Map()
  const addNbr = (a, b) => { if (!nbr.has(a)) nbr.set(a, []); nbr.get(a).push(b) }
  // For a long overlay that has been broken into a dummy chain, wire the CHAIN
  // (from ↔ d ↔ d ↔ … ↔ to) into the adjacency instead of the direct from↔to link,
  // so the relaxation straightens the whole corridor rather than pulling the two
  // real endpoints toward each other across the intervening ranks.
  const longKey = (from, to) => (dummyChains.has(from + '|' + to) ? from + '|' + to : null)
  up.forEach((outs, from) => outs.forEach((e) => {
    if (!nodes.has(from) || !nodes.has(e.to)) return
    const k = longKey(from, e.to)
    if (k) {
      // chain is ordered lo-1 .. hi+1, i.e. nearest `from` first, nearest `to` last
      const ch = dummyChains.get(k).chain
      let prev = from
      for (const d of ch) { addNbr(prev, d); addNbr(d, prev); prev = d }
      addNbr(prev, e.to); addNbr(e.to, prev)
    } else {
      addNbr(from, e.to); addNbr(e.to, from)
    }
  }))

  // relationship-neighbour sets (both directions) — used to give a wider gap to
  // sibling nodes joined by a relationship (the base of a diamond).
  const relNbr = new Map()
  graph.edges.forEach((e) => {
    if (e.kind !== 'is-a' && nodes.has(e.from) && nodes.has(e.to)) {
      ;(relNbr.get(e.from) || relNbr.set(e.from, new Set()).get(e.from)).add(e.to)
      ;(relNbr.get(e.to) || relNbr.set(e.to, new Set()).get(e.to)).add(e.from)
    }
  })
  const relConnected = (a, b) => relNbr.has(a) && relNbr.get(a).has(b)

  // ---- inputs for ADAPTIVE sibling spacing --------------------------------
  // (1) label between siblings: the widest relationship label joining a<->b, so
  //     the gap can fit the text instead of clipping it.
  const relLabelW = new Map() // "a b" (sorted) -> px width of widest joining label
  graph.edges.forEach((e) => {
    if (e.kind !== 'is-a' && e.label && nodes.has(e.from) && nodes.has(e.to)) {
      const k = [e.from, e.to].sort().join(' '); const w = measure(e.label) + 10
      if (w > (relLabelW.get(k) || 0)) relLabelW.set(k, w)
    }
  })
  // (4) fan-out: how many is-a children each node has (a wide fan wants its
  //     children spread so the parent's edges don't bunch into a vertical pencil).
  const childrenCount = new Map()
  graph.edges.forEach((e) => { if (e.kind === 'is-a' && nodes.has(e.from) && nodes.has(e.to)) childrenCount.set(e.to, (childrenCount.get(e.to) || 0) + 1) })
  const isaParentOf = new Map() // child -> its primary parent id (for fan lookup)
  primary.forEach((e, id) => { if (e.kind === 'is-a') isaParentOf.set(id, e.to) })
  // (5) subtree size: number of tree-descendants under a node (visual weight).
  const subSize = new Map()
  function computeSubSize (id) {
    if (subSize.has(id)) return subSize.get(id)
    subSize.set(id, 1)
    let s = 1; for (const c of (nodes.get(id)?.children || [])) s += computeSubSize(c)
    subSize.set(id, s); return s
  }
  // (computed lazily in sibGap so it reflects the current child ordering)

  // Desired CENTER-TO-CENTER distance between two adjacent same-rank nodes a,b.
  // Base half-widths + SIB_GAP, then widened by whichever adaptive demand is
  // largest: a relationship label in the gap, both siblings rooting sizable
  // subtrees, or a wide sibling fan under a shared parent.
  function sibGap (a, b) {
    const base = (a.width + b.width) / 2 + SIB_GAP
    let extra = 0
    // (1)+(2) a relationship joins them → fit its label (falls back to REL_SIB_GAP)
    if (relConnected(a.id, b.id)) {
      const lbl = relLabelW.get([a.id, b.id].sort().join(' ')) || 0
      extra = Math.max(extra, Math.max(REL_SIB_GAP - SIB_GAP, lbl + 18))
    }
    // (5) subtree size: a gentle nudge so a bushy branch isn't crammed against a
    //     leaf. Deliberately small & capped — this accumulates across a whole row,
    //     so a large per-pair value would balloon wide graphs.
    const sa = computeSubSize(a.id); const sb = computeSubSize(b.id)
    if (sa > 1 && sb > 1) extra = Math.max(extra, Math.min(24, (Math.min(sa, sb) - 1) * 4))
    // (4) fan-out: if a,b are both children of the SAME parent that fans widely,
    //     nudge them apart so the parent's edges spread at a readable angle
    const pa = isaParentOf.get(a.id); const pb = isaParentOf.get(b.id)
    if (pa && pa === pb) { const fan = childrenCount.get(pa) || 0; if (fan >= 5) extra = Math.max(extra, Math.min(28, (fan - 4) * 8)) }
    // (6) cousins: a,b sit side by side on the same rank but descend from DIFFERENT
    //     is-a parents. Add a wider gutter so the eye reads two distinct sibling
    //     groups rather than one undifferentiated row, and so the parents' edge fans
    //     don't visually merge. Only when both actually have a (different) parent —
    //     roots and cross-parent relationship pairs are left to their own rules above.
    if (pa && pb && pa !== pb) extra = Math.max(extra, COUSIN_GAP)
    return base + extra
  }

  // initial deterministic child order (deepest lineage first, then id)
  nodes.forEach((n) => n.children.sort((a, b) => (rank.get(b) - rank.get(a)) || (a < b ? -1 : 1)))

  // barycentre of a node = mean x of its neighbours (all edge kinds), used for
  // per-node x-relaxation. Collector neighbours are skipped so nodes arrange by
  // their meaningful connections rather than chasing an abstract hub (a
  // collector still gets centred by its own non-collector children).
  function barycentre (id) {
    const ns = nbr.get(id) || []
    let s = 0; let c = 0
    for (const m of ns) { if (collector.has(m)) continue; const mm = nodes.get(m); if (mm && mm._x != null) { s += mm._x; c++ } }
    return c ? s / c : (nodes.get(id)._x || 0)
  }

  // ids in a node's tree subtree (its tree-descendants incl. itself)
  function subtreeIds (node) {
    const out = []; const st = [node]
    while (st.length) {
      const x = st.pop(); if (x.id !== '__super__') out.push(x.id)
      ;(x.children || []).forEach((cid) => { const c = nodes.get(cid); if (c) st.push(c) })
    }
    return out
  }
  // subtree-aggregate pull: mean x of every neighbour of every node in the
  // subtree that lies OUTSIDE the subtree. Ordering cones by this migrates a
  // whole subtree toward wherever it actually connects — even when that link
  // sits several levels down (e.g. a small "process" cone whose only tie is a
  // deep child), which a root-only barycentre can't see.
  function subtreePull (id) {
    const node = nodes.get(id); const sub = new Set(subtreeIds(node))
    let s = 0; let c = 0
    for (const m of sub) {
      for (const nb of (nbr.get(m) || [])) {
        if (!sub.has(nb) && !collector.has(nb)) { const mm = nodes.get(nb); if (mm && mm._x != null) { s += mm._x; c++ } }
      }
    }
    return c ? s / c : (node._x || 0)
  }

  // ---- tidy placement (naive contour, absolute coords) ----
  // Vertical position is by RANK (not tree recursion depth), so a node stays at
  // its correct level even when its tree-parent is a shallower non-collector and
  // its collector parent sits several ranks above (drawn as an overlay).
  function place (node) {
    const dep = node.id === '__super__' ? -1 : (rank.get(node.id) || 0)
    node._depth = dep
    const hw = node.width / 2
    const kids = (node.children || []).map((id) => nodes.get(id)).filter(Boolean)
    if (kids.length === 0) {
      node._x = 0
      return { L: new Map([[dep, -hw]]), R: new Map([[dep, +hw]]), nodes: [node] }
    }
    const subs = kids.map((k) => place(k))
    const mergedL = new Map(); const mergedR = new Map(); const all = []
    const shift = (sub, dx) => {
      for (const n of sub.nodes) n._x += dx
      const nL = new Map(); const nR = new Map()
      for (const [d, x] of sub.L) nL.set(d, x + dx)
      for (const [d, x] of sub.R) nR.set(d, x + dx)
      sub.L = nL; sub.R = nR
    }
    const mergedIds = new Set()
    subs.forEach((sub, i) => {
      if (i > 0) {
        // wider gap if this subtree is joined to an already-placed sibling by a
        // relationship (diamond base needs room for its arc + label)
        const wide = sub.nodes.some((n) => { const rn = relNbr.get(n.id); return rn && [...rn].some((r) => mergedIds.has(r)) })
        const gap = wide ? REL_SIB_GAP : SIB_GAP
        let need = -Infinity
        for (const [d, rx] of mergedR) { if (sub.L.has(d)) { const req = rx + gap - sub.L.get(d); if (req > need) need = req } }
        if (need === -Infinity || need < 0) need = 0
        shift(sub, need)
      }
      for (const [d, x] of sub.L) { if (!mergedL.has(d) || x < mergedL.get(d)) mergedL.set(d, x) }
      for (const [d, x] of sub.R) { if (!mergedR.has(d) || x > mergedR.get(d)) mergedR.set(d, x) }
      all.push(...sub.nodes)
      sub.nodes.forEach((n) => mergedIds.add(n.id))
    })
    const first = kids[0]._x; const last = kids[kids.length - 1]._x
    node._x = (first + last) / 2
    const L = new Map(mergedL); const R = new Map(mergedR)
    L.set(dep, node._x - hw); R.set(dep, node._x + hw)
    all.push(node)
    return { L, R, nodes: all }
  }

  // crossing reduction: iterate place -> reorder each parent's children by their
  // subtree pull. Barycentre-style reordering can OSCILLATE in densely
  // cross-linked graphs (a cone chases a partner that is itself being pulled the
  // other way), so instead of using the last iteration we keep the configuration
  // with the shortest total horizontal edge length seen.
  const edgeLen = () => { let s = 0; for (const e of graph.edges) { const a = nodes.get(e.from); const b = nodes.get(e.to); if (a && b) s += Math.abs(a._x - b._x) } return s }
  const snapshot = () => { const m = new Map(); nodes.forEach((n) => m.set(n.id, n.children.slice())); m.set(SUPER, superNode.children.slice()); return m }
  const restore = (m) => { nodes.forEach((n) => { if (m.has(n.id)) n.children = m.get(n.id).slice() }); superNode.children = m.get(SUPER).slice() }
  let bestLen = Infinity; let best = null
  for (let it = 0; it < 16; it++) {
    place(superNode)
    const len = edgeLen()
    if (len < bestLen - 0.5) { bestLen = len; best = snapshot() }
    let ch = false
    const reorder = (n) => {
      if (!n.children || n.children.length < 2) return
      const scored = n.children.map((id) => ({ id, b: subtreePull(id) }))
      scored.sort((p, q) => (p.b - q.b) || (p.id < q.id ? -1 : 1))
      const order = scored.map((s) => s.id)
      if (order.join('|') !== n.children.join('|')) { n.children = order; ch = true }
    }
    nodes.forEach(reorder); reorder(superNode)
    if (!ch) break
  }
  if (best) restore(best)
  place(superNode)

  // Seed each dummy's x by interpolating a straight line between its overlay's two
  // real endpoints (which now have final tree x). The x-relaxation below then pulls
  // the whole chain taut and nudges real nodes aside to keep the corridor clear.
  dummyChains.forEach(({ chain, from, to }) => {
    const a = nodes.get(from); const b = nodes.get(to)
    if (!a || !b) return
    const rA = a._depth; const rB = b._depth
    chain.forEach((id) => {
      const d = nodes.get(id); if (!d) return
      const t = (rB - rA) !== 0 ? (d._depth - rA) / (rB - rA) : 0.5
      d._x = a._x + (b._x - a._x) * t
    })
  })

  // collector ordering: collector (upper-ontology) nodes are placed by the tidy pass
  // like any other node, but their left-to-right ORDER within a rank is then frozen —
  // x-relaxation only slides a node within its neighbours' gaps, it never reorders. That
  // can leave a collector on the wrong side of its descendants, so its is-a edges cross
  // a sibling's (e.g. `immaterial entity` sitting LEFT of `anatomical entity` while its
  // only child sits far to the RIGHT). Fix by sorting each rank's collectors into the
  // order of their child-barycentre and swapping their x-slots to match, so each abstract
  // hub sits above where its descendants actually are. Non-collectors keep their slots.
  {
    const childBary = (id) => {
      const dep = nodes.get(id)._depth; let s = 0; let c = 0
      for (const m of (nbr.get(id) || [])) {
        const mm = nodes.get(m)
        if (mm && mm._x != null && mm._depth > dep) { s += mm._x; c++ } // descendants only
      }
      return c ? s / c : null
    }
    const byRank = new Map()
    nodes.forEach((n) => { (byRank.get(n._depth) || byRank.set(n._depth, []).get(n._depth)).push(n) })
    byRank.forEach((arr) => {
      if (arr.length < 2) return
      if (!arr.some((n) => collector.has(n.id))) return // nothing to reorder on this rank
      arr.sort((a, b) => a._x - b._x)
      const slots = arr.map((n) => n._x) // the x-positions to redistribute
      // sort key: a collector sorts by WHERE ITS DESCENDANTS ARE (so it sits above them);
      // a non-collector keeps its own x. This lets a mis-ordered collector slide past a
      // real sibling to the correct side, removing the is-a crossing, while real nodes
      // hold their relative order.
      const keyOf = (n) => { if (collector.has(n.id)) { const cb = childBary(n.id); if (cb != null) return cb } return n._x }
      const reordered = arr.map((n) => ({ n, k: keyOf(n) })).sort((p, q) => p.k - q.k || (p.n._x - q.n._x) || (p.n.id < q.n.id ? -1 : 1))
      reordered.forEach((o, i) => { o.n._x = slots[i] })
    })
  }

  // x-relaxation: nudge each node toward the barycentre of ALL its neighbours
  // (parents, children, relationships) while keeping a minimum gap within its
  // rank. Balances multi-parent nodes between their parents and shortens
  // cross-links, without changing ranks. Clean trees barely move (already
  // centred). Damped, alternating left/right sweeps to avoid oscillation.
  {
    const byRank = new Map()
    nodes.forEach((n) => { (byRank.get(n._depth) || byRank.set(n._depth, []).get(n._depth)).push(n) })
    byRank.forEach((arr) => arr.sort((a, b) => a._x - b._x))
    const gap = (a, b) => sibGap(a, b)
    for (let it = 0; it < 18; it++) {
      const l2r = it % 2 === 0
      byRank.forEach((arr) => {
        const idx = [...arr.keys()]; if (!l2r) idx.reverse()
        for (const i of idx) {
          const n = arr[i]
          const des = barycentre(n.id)
          const target = n._x + (des - n._x) * 0.5 // damping
          const lo = i > 0 ? arr[i - 1]._x + gap(arr[i - 1], n) : -Infinity
          const hi = i < arr.length - 1 ? arr[i + 1]._x - gap(n, arr[i + 1]) : Infinity
          n._x = Math.max(lo, Math.min(hi, target))
        }
      })
    }
  }

  // final coords: y by rank (root at top, selected/max-rank at bottom)
  let minX = Infinity; let maxX = -Infinity; let maxRank = 0
  nodes.forEach((n) => { maxRank = Math.max(maxRank, n._depth) })
  nodes.forEach((n) => { minX = Math.min(minX, n._x - n.width / 2); maxX = Math.max(maxX, n._x + n.width / 2) })
  const dx = MARGIN - minX

  // ---- per-row rank spacing -----------------------------------------------
  // Edges are now drawn STRAIGHT unless they'd cut through a node box (see
  // routePath), so gaps no longer need to reserve room for downward arcs or bowed
  // overlays. The only residual demand: when MANY overlays fan through one gap as
  // straight rays, a little extra height keeps them from bunching into a hard-to-
  // read pencil of near-parallel lines. That's a small, count-based nudge only.
  const extraGap = new Array(Math.max(0, maxRank)).fill(0)
  const bump = (k, v) => { if (k >= 0 && k < extraGap.length) extraGap[k] = Math.max(extraGap[k], v) }
  const crossCount = new Array(Math.max(0, maxRank)).fill(0)
  overlays.forEach((e) => {
    const a = nodes.get(e.from); const b = nodes.get(e.to); if (!a || !b) return
    const lo = Math.min(a._depth, b._depth); const hi = Math.max(a._depth, b._depth)
    for (let k = lo; k < hi; k++) if (k < crossCount.length) crossCount[k]++
  })
  for (let k = 0; k < extraGap.length; k++) {
    const n = Math.max(0, crossCount[k] - 2) // only once a gap is truly busy (3+ rays)
    if (n > 0) bump(k, Math.min(30, n * 10))
  }
  // A SAME-RANK cross-link (e.g. `multicellular anatomical structure has_part cell`)
  // is drawn as an arc between two nodes on the SAME rank. Give that rank extra room
  // by opening the gap ABOVE it (between it and its parent rank) proportional to the
  // horizontal span the arc must bridge — so the whole row of children drops away from
  // the parent and the arc has space to curve gently instead of pinching into a tight,
  // dominant hook. (crossCount above ignores these, since lo===hi for a same-rank edge.)
  const spanGap = new Array(Math.max(0, maxRank)).fill(0)
  overlays.forEach((e) => {
    const a = nodes.get(e.from); const b = nodes.get(e.to); if (!a || !b) return
    if (a._depth !== b._depth) return // same-rank only
    const above = a._depth - 1 // gap between the parent rank and this one
    if (above < 0 || above >= spanGap.length) return
    const span = Math.abs(a._x - b._x) // horizontal distance the arc bridges
    // wider gap for a wider span; capped so it never dominates the layout.
    const want = Math.min(160, Math.round(span * 0.18))
    if (want > spanGap[above]) spanGap[above] = want
  })
  for (let k = 0; k < extraGap.length; k++) if (spanGap[k] > 0) bump(k, spanGap[k])
  // cumulative y of the TOP of each rank row
  const rowTop = new Array(maxRank + 1); rowTop[0] = MARGIN
  for (let k = 1; k <= maxRank; k++) rowTop[k] = rowTop[k - 1] + NODE_H + ROW_GAP + (extraGap[k - 1] || 0)

  nodes.forEach((n) => { n.x = n._x + dx; n.y = rowTop[n._depth] + NODE_H / 2 })
  const width = (maxX - minX) + 2 * MARGIN
  const height = rowTop[maxRank] + NODE_H + MARGIN

  // Attach the routed waypoints (final coords, ordered from nearest `from` to
  // nearest `to`) to each long overlay so the renderer can spline the edge through
  // the corridor the dummies opened instead of bowing across the node field.
  overlays.forEach((e) => {
    const rec = dummyChains.get(e.from + '|' + e.to)
    if (!rec) return
    e.waypoints = rec.chain.map((id) => { const d = nodes.get(id); return { x: d.x, y: d.y } })
  })

  // Drop the dummy nodes from the output: their only purpose was to shape the
  // layout and supply waypoints (already copied onto the overlays above). The
  // renderer must never see them as boxes/obstacles.
  nodes.forEach((n, id) => { if (n.isDummy) nodes.delete(id) })

  const treeEdges = []
  primary.forEach((e, id) => treeEdges.push({ from: id, to: e.to, kind: e.kind, label: e.label }))
  return { nodes, treeEdges, overlays, width, height, collector }
}

// ================= EDGE ROUTING =================
// These are pure geometry helpers used by the renderer to draw each edge. They
// need the effective node box height, so it is threaded in as `nodeH` (the harness
// read it from a module global).

// Point on node n's rectangle boundary in the direction of (tx,ty).
export function boundary (n, tx, ty, nodeH) {
  const H = nodeH || NODE_H_BASE
  const dx = tx - n.x; const dy = ty - n.y; const hw = n.width / 2; const hh = H / 2
  if (dx === 0 && dy === 0) return { x: n.x, y: n.y }
  const sx = dx !== 0 ? hw / Math.abs(dx) : Infinity
  const sy = dy !== 0 ? hh / Math.abs(dy) : Infinity
  const s = Math.min(sx, sy)
  return { x: n.x + dx * s, y: n.y + dy * s }
}

// Straight edge between the two node boundaries (arrowhead lands on b's edge).
// a = source (below), b = target (above).
export function straightPath (a, b, nodeH) {
  const p1 = boundary(a, b.x, b.y, nodeH); const p2 = boundary(b, a.x, a.y, nodeH)
  return {
    d: `M ${p1.x},${p1.y} L ${p2.x},${p2.y}`,
    mid: { x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2 },
    seg: { p1, p2 }
  }
}

// Route a long edge through pre-computed waypoints (the dummy-node corridor). The
// endpoints attach to the real node boundaries; the interior follows the way-
// points as a smooth Catmull-Rom spline (rendered as cubic Béziers), so the edge
// weaves through the lanes the dummies opened instead of bowing across the field.
// `way` is ordered from nearest `a` (source, below) to nearest `b` (target, above).
export function waypointPath (a, b, way, nodeH) {
  // Full control polyline: source centre-ish → waypoints → target centre-ish. We
  // anchor the ends on the box faces pointing at the first/last waypoint.
  const first = way[0] || { x: b.x, y: b.y }
  const last = way[way.length - 1] || { x: a.x, y: a.y }
  const p1 = boundary(a, first.x, first.y, nodeH)
  const p2 = boundary(b, last.x, last.y, nodeH)
  const P = [p1, ...way, p2]
  // Catmull-Rom → cubic Bézier. Tension 0 (standard CR) gives a gentle, non-
  // overshooting curve through every point.
  let d = `M ${P[0].x},${P[0].y}`
  for (let i = 0; i < P.length - 1; i++) {
    const p0 = P[i - 1] || P[i]; const pA = P[i]; const pB = P[i + 1]; const p3 = P[i + 2] || P[i + 1]
    const c1x = pA.x + (pB.x - p0.x) / 6; const c1y = pA.y + (pB.y - p0.y) / 6
    const c2x = pB.x - (p3.x - pA.x) / 6; const c2y = pB.y - (p3.y - pA.y) / 6
    d += ` C ${c1x},${c1y} ${c2x},${c2y} ${pB.x},${pB.y}`
  }
  const mid = P[Math.floor(P.length / 2)]
  return { d, mid: { x: mid.x, y: mid.y }, seg: { pts: P } }
}

// Sample a straight or quadratic edge into a polyline of {x,y} points.
export function samplePath (seg, n) {
  const out = []; n = n || 40
  if (seg.pts) { // orthogonal polyline: sample each segment
    const P = seg.pts
    for (let s = 0; s < P.length - 1; s++) { const a = P[s]; const b = P[s + 1]; for (let i = 0; i <= n; i++) { const t = i / n; out.push({ x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t }) } }
  } else if (seg.c) { // quadratic p1 - c - p2
    for (let i = 0; i <= n; i++) {
      const t = i / n; const u = 1 - t
      out.push({ x: u * u * seg.p1.x + 2 * u * t * seg.c.x + t * t * seg.p2.x, y: u * u * seg.p1.y + 2 * u * t * seg.c.y + t * t * seg.p2.y })
    }
  } else {
    for (let i = 0; i <= n; i++) { const t = i / n; out.push({ x: seg.p1.x + (seg.p2.x - seg.p1.x) * t, y: seg.p1.y + (seg.p2.y - seg.p1.y) * t }) }
  }
  return out
}

// Does the segment p1->p2 pass through rectangle r (already inflated)? Sampled
// along the segment — cheap and robust enough at these sizes.
export function segHitsRect (p1, p2, r) {
  const steps = 24
  for (let i = 1; i < steps; i++) {
    const t = i / steps; const x = p1.x + (p2.x - p1.x) * t; const y = p1.y + (p2.y - p1.y) * t
    if (x >= r.x0 && x <= r.x1 && y >= r.y0 && y <= r.y1) return true
  }
  return false
}

// Edge routing: draw a STRAIGHT line by default; bow only when the straight
// segment would cut through a non-endpoint node box, and then only by the minimum
// needed to clear it (toward whichever side has room). `obstacles` is the list of
// node rects to avoid; a and b are the endpoints (excluded from the test).
// `nodeH` is the effective node box height.
export function routePath (a, b, obstacles, laneReg, nodeH) {
  const p1 = boundary(a, b.x, b.y, nodeH); const p2 = boundary(b, a.x, a.y, nodeH)
  const dx = p2.x - p1.x; const dy = p2.y - p1.y; const len = Math.hypot(dx, dy) || 1
  const mx = (p1.x + p2.x) / 2; const my = (p1.y + p2.y) / 2
  const straight = { d: `M ${p1.x},${p1.y} L ${p2.x},${p2.y}`, mid: { x: mx, y: my }, seg: { p1, p2 } }
  if (!obstacles || !obstacles.length) return straight
  const nx = -dy / len; const ny = dx / len // unit normal to the chord
  const PAD = 6
  // obstacles that the straight chord actually cuts through (exclude endpoints)
  const blockers = obstacles.filter((r) => r.id !== a.id && r.id !== b.id &&
    segHitsRect(p1, p2, { x0: r.x - r.w / 2 - PAD, x1: r.x + r.w / 2 + PAD, y0: r.y - r.h / 2 - PAD, y1: r.y + r.h / 2 + PAD }))

  // (A blocked same-rank cross-link used to be routed with right-angled dog-legs
  // through the inter-rank corridor; that read as too dominant. It now falls through
  // to the curved corridor routing below like every other cross-link — a smooth arc
  // that dips into the gap between its rank and the next, deepening only as far as it
  // must to clear the box(es) in between.)

  // A long, NEAR-VERTICAL overlay that spans several ranks runs right alongside the
  // backbone spine and reads as a redundant twin of it. For those, bow OUTWARD (away
  // from the nodes it passes) so it arcs clearly to the side. But an overlay whose
  // endpoints are already well separated horizontally (it clearly slants off toward
  // another column, e.g. analyte assay -> measurement datum) reads fine straight and
  // must NOT be forced into a bow — that only drags it across neighbouring nodes.
  const span = Math.abs((a._depth || 0) - (b._depth || 0))
  const adxEnds = Math.abs(p2.x - p1.x); const adyEnds = Math.abs(p2.y - p1.y) || 1
  const nearVertical = adxEnds < 0.35 * adyEnds // slope steeper than ~70° from horizontal
  let minBow = 0; let outSign = 0
  if (span >= 2 && nearVertical) {
    // Collect the nodes strictly BETWEEN the two ranks that the straight chord would
    // run CLOSE TO — i.e. whose horizontal centre is near the line's x at that height.
    // Only those justify bowing outward; a near-vertical overlay through open space
    // (nothing alongside it) should stay straight. NEAR = within half a node width.
    const yLo = Math.min(p1.y, p2.y) + 2; const yHi = Math.max(p1.y, p2.y) - 2
    const NEAR = 70
    let sx = 0; let sc = 0
    for (const r of obstacles) {
      if (r.id === a.id || r.id === b.id) continue
      if (r.y > yLo && r.y < yHi) {
        const t = (r.y - p1.y) / (p2.y - p1.y || 1) // where along the chord this node's height falls
        const lineX = p1.x + (p2.x - p1.x) * t // chord x at that height
        if (Math.abs(r.x - lineX) < NEAR + r.w / 2) { sx += r.x; sc++ } // node sits alongside the line
      }
    }
    if (sc) { // something to steer around → bow outward
      const centerX = sx / sc
      outSign = ((mx - centerX) * nx >= 0) ? 1 : -1
      minBow = Math.min(120, 26 + span * 20)
    }
    // else: open corridor — leave minBow=0 so the edge draws straight.
  }

  if (!blockers.length && minBow === 0) return straight // short overlay, clear → straight
  // Nodes the CURVE must avoid: not just the ones the straight chord hit, but any
  // other node too — so a bow deep enough to clear the first obstacle doesn't come
  // to rest grazing a second one on the way (e.g. a same-rank link bowing down just
  // far enough to clear the box in its row lands right on a node in the row below).
  const avoid = obstacles.filter((r) => r.id !== a.id && r.id !== b.id)
  // For each side, find the smallest control-offset that clears every node AND meets
  // the outward-bow minimum for long overlays.
  const CLR = PAD + 2 // keep the curve a bit clear of boxes
  const clears = (bow) => {
    if (!blockers.length && minBow === 0) return true
    const cx = mx + nx * bow; const cy = my + ny * bow // control point
    for (let i = 1; i < 60; i++) { // finer sampling — coarse steps let a curve graze a box between samples
      const t = i / 60; const u = 1 - t
      const x = u * u * p1.x + 2 * u * t * cx + t * t * p2.x; const y = u * u * p1.y + 2 * u * t * cy + t * t * p2.y
      for (const r of avoid) { if (x >= r.x - r.w / 2 - CLR && x <= r.x + r.w / 2 + CLR && y >= r.y - r.h / 2 - CLR && y <= r.y + r.h / 2 + CLR) return false }
    }
    return true
  }
  const findBow = (s, cap) => { const top = cap || 320; for (let bow = Math.max(24, minBow); bow <= top; bow += 8) { if (clears(s * bow)) return bow } return null }
  const sameRank = Math.abs((a._depth || 0) - (b._depth || 0)) === 0
  let best = null
  if (outSign !== 0) {
    // long near-vertical overlay: keep the deliberate outward direction
    const bow = findBow(outSign); best = bow != null ? { bow, sign: outSign } : { bow: Math.max(minBow, 120), sign: outSign }
  } else if (sameRank) {
    // A same-rank cross-link should slot into the corridor BETWEEN its rank and the
    // next one down — a shallow arc that clears the box(es) in its own row but does
    // NOT dive a full rank down to avoid a node in the row below. Cap the downward bow
    // so its apex stays within ~the row gap; only if that shallow arc can't clear its
    // own-row blockers do we fall back to a deeper sweep or an upward arc.
    // "down" is ABSOLUTE screen-down (increasing y), independent of edge direction:
    // the sign that makes apex y = my + ny*bow*sign increase is sign(ny).
    const dnSign = ny >= 0 ? 1 : -1
    // Prefer the SHALLOWEST clearing bow within the inter-rank corridor. Scan from
    // shallow upward and take the first bow that clears (a shallow arc that grazes the
    // same-row box but stays above the next row down). Cap at one row-gap of depth; only
    // if nothing in that band clears do we allow a deeper sweep or an upward arc.
    // Try both directions and take whichever gives the SHALLOWEST arc (smallest bow) —
    // the least-intrusive slot, whether that's the corridor below or the one above.
    const bDn = findBow(dnSign); const bUp = findBow(-dnSign)
    if (bDn == null && bUp == null) best = { bow: 2 * (ROW_GAP + (nodeH || NODE_H_BASE)), sign: dnSign }
    else if (bDn != null && (bUp == null || bDn <= bUp)) best = { bow: bDn, sign: dnSign }
    else best = { bow: bUp, sign: -dnSign }
  } else {
    // Multi-rank cross-links: prefer the downward corridor, else up.
    const dnSign = ny >= 0 ? 1 : -1
    const bDn = findBow(dnSign); const bUp = findBow(-dnSign)
    if (bDn == null && bUp == null) best = { bow: 220, sign: dnSign }
    else if (bDn != null && (bUp == null || bDn <= bUp + 70)) best = { bow: bDn, sign: dnSign }
    else best = { bow: bUp, sign: -dnSign }
  }
  const cx = mx + nx * best.bow * best.sign; const cy = my + ny * best.bow * best.sign
  // Re-attach the endpoints along the curve's actual tangents: a quadratic leaves
  // p1 heading toward the control point and arrives at p2 coming from it. Anchoring
  // to the box face in THAT direction (instead of the straight-chord direction) lets
  // the edge emerge from the correct side of the node — e.g. the right face of the
  // source when the curve sweeps right — rather than kinking off the top edge.
  const q1 = boundary(a, cx, cy, nodeH); const q2 = boundary(b, cx, cy, nodeH)
  const mid = { x: (q1.x + 2 * cx + q2.x) / 4, y: (q1.y + 2 * cy + q2.y) / 4 }
  return { d: `M ${q1.x},${q1.y} Q ${cx},${cy} ${q2.x},${q2.y}`, mid, seg: { p1: q1, p2: q2, c: { x: cx, y: cy } } }
}
