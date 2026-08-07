import { Controller } from '@hotwired/stimulus'
import {
  computeLayout, routePath, curvedIsaPath, waypointPath,
  isUpperOnto, shortId, ontoAcronym, measureText,
  NODE_H_BASE, PILL_H, PILL_PAD
} from './entity_graph_layout'
import { copyPng, copySvg, safeFileName } from './graph_export'

const SVG = 'http://www.w3.org/2000/svg'

// A small outline eye — the 'show this again' affordance for a hidden node.
const EYE_SVG = '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7z"/><circle cx="12" cy="12" r="3"/></svg>'
// A small outline (i) — the per-option help affordance; its tooltip explains the setting.
const INFO_SVG = '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 11v5"/><circle cx="12" cy="7.5" r="0.6" fill="currentColor"/></svg>'
const MINIMAP_MAX = 240 // longest edge of the minimap thumbnail

// Renders the ancestor/relationship neighbourhood of a class as a node-link graph,
// using the custom "tidy ancestor tree" layout (ranking by longest is-a path,
// Reingold-Tilford placement, crossing reduction, curved obstruction-aware edge
// routing) ported from the offline harness. Drawn as hand-built SVG with a
// fixed-viewport zoom/pan, a context minimap, a path-to-root highlight,
// a legend, and per-node copy/navigate actions.
//
// The full graph is delivered in one payload from the server (no client fetches).
// Connects to data-controller="concept-graph".
export default class extends Controller {
  static targets = ['canvas', 'gate', 'empty']
  static values = {
    graph: Object,
    ontology: String,
    large: String
  }

  connect () {
    // All document-level listeners this controller adds are tied to this signal, so
    // disconnect() (e.g. when Turbo swaps the frame) removes them in one shot — no
    // stale Escape/keydown handlers accumulating across re-renders or frame swaps.
    this._ac = new AbortController()

    // The graph frame's content is now in the DOM and #render() below draws
    // synchronously within this connect(), so the browser won't repaint until we
    // return — safe to lift the class-select loading veil here. This clears the
    // marker the tree sets to bridge the concept_show → entity-graph frame handoff
    // (see simple_tree_controller). All connect() paths (empty / gate / boot) pass
    // through here, so one clear covers them.
    document.getElementById('concept_content')?.classList.remove('entity-graph-loading')

    const graph = this.graphValue || {}
    this.graph = graph
    this.nodes = graph.nodes || []
    this.edges = graph.edges || []

    // display options (toolbar toggles). Defaults, overlaid with any the user has
    // saved before — persisted in localStorage so they survive reloads and new
    // sessions. These toggles are ontology-independent, so they're stored globally.
    this.opts = {
      hideUpper: false,
      isaOnly: false,
      fadeUpper: true,
      useUpperInfo: true,
      transitiveReduction: true,
      showPills: false,
      showAcronym: true,
      // Tooltip content — all on by default.
      tipDefinition: true,
      tipIsa: true,
      tipSynonyms: true,
      tipExamples: true,
      ...this.#loadOpts()
    }
    // relationship properties toggled OFF (by property key); is-a is never hidden here.
    // Persisted per ontology (property names differ across ontologies), in localStorage
    // so the selection survives reloads and new sessions, not just the current tab.
    this._hiddenProps = this.#loadHiddenProps()

    // Node removal. Two independent sets, both keyed by class IRI:
    //  - _removedNodes: TRANSIENT, this graph only — for curating a figure. Not
    //    persisted; a reload starts clean.
    //  - _hiddenNodes: PERSISTENT per ontology — "never show this class here".
    // The selected class is never removable (it's the graph's anchor).
    this._removedNodes = new Set()
    this._hiddenNodes = this.#loadHiddenNodes()

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
    // Remove every document-level listener registered with the abort signal
    // (Escape handlers, panel dismissers), so a Turbo frame swap doesn't leave
    // stale handlers or accumulate them across re-renders.
    this._ac?.abort()
    // If we locked page scroll for fullscreen, restore it — otherwise a swap while
    // fullscreen was active would leave the page permanently unscrollable.
    if (this._bodyOverflowLocked) { document.body.style.overflow = ''; this._bodyOverflowLocked = false }
    clearTimeout(this._toastT)
  }

  // "Show graph anyway" on the large-graph gate.
  renderAnyway () {
    this.gateTarget.classList.add('d-none')
    this.#boot()
  }

  // debug helper: re-render (e.g. after toggling window.__egDebugDummies).
  debugRerender () { this.#render() }

  // --- boot / chrome --------------------------------------------------------

  #boot () {
    this.#render()
    this.#showTruncatedNotice()
    if (!this._resizeObserver && 'ResizeObserver' in window) {
      // re-fit while the pane settles / becomes visible, until the user zooms
      this._resizeObserver = new ResizeObserver(() => this._zoomApi && this._zoomApi.reflow())
      this._resizeObserver.observe(this.canvasTarget)
    }
  }

  // The service caps ancestor walking at MAX_NODES and flags the graph
  // `truncated` when it hits that cap. Without a notice the user can't tell the
  // graph is incomplete, so surface a dismissable banner when it is.
  #showTruncatedNotice () {
    if (!this.graph || !this.graph.truncated) return
    if (this.canvasTarget.querySelector('.entity-graph__truncated')) return
    const bar = document.createElement('div')
    bar.className = 'entity-graph__truncated'
    bar.innerHTML =
      '<span>This graph is large and has been truncated — some ancestors are not shown.</span>' +
      '<button type="button" class="entity-graph__truncated-close" aria-label="Dismiss">×</button>'
    bar.querySelector('.entity-graph__truncated-close').addEventListener('click', (ev) => {
      ev.stopPropagation(); bar.remove()
    })
    this.canvasTarget.append(bar)
  }

  #effNodeH () {
    return this.opts.showPills ? NODE_H_BASE + PILL_H + PILL_PAD : NODE_H_BASE
  }

  // Floating chrome: the settings (gear) and key (?) icon buttons, overlaid on the
  // top-left of the canvas (the zoom controls sit top-right). No toolbar row — the
  // graph gets the full height. Rebuilt on each render (the canvas content is
  // replaced), so it's appended here rather than to a persistent toolbar element.
  #buildChrome (canvas) {
    const cluster = document.createElement('div')
    cluster.className = 'entity-graph__chrome'
    cluster.append(this.#buildPopout())
    // relationship-property picker — only when the graph has relationships to pick
    if (this.#relProps().length) cluster.append(this.#buildFilter())
    // Copy sits below the settings (gear) button.
    cluster.append(this.#buildGear(), this.#buildCopy(), this.#buildHelp())
    canvas.append(cluster)
  }

  // Copy button: a small popover with "Copy as image (PNG)" / "Copy as SVG (vector)",
  // each of which copies the WHOLE graph to the clipboard (with a download fallback).
  #buildCopy () {
    const holder = document.createElement('span')
    holder.className = 'entity-graph__icon-wrap'
    const btn = document.createElement('button')
    btn.type = 'button'
    btn.className = 'entity-graph__icon-btn'
    btn.title = 'Copy graph'
    btn.setAttribute('aria-label', 'Copy graph')
    // two overlapping sheets (copy) glyph
    btn.innerHTML = '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="11" height="11" rx="2"/><path d="M6 15H5a2 2 0 01-2-2V5a2 2 0 012-2h8a2 2 0 012 2v1"/></svg>'
    const pop = document.createElement('div')
    pop.className = 'entity-graph__menu-pop'
    pop.hidden = true
    const item = (label, run) => {
      const el = document.createElement('button')
      el.type = 'button'; el.className = 'entity-graph__menu-item'; el.textContent = label
      el.addEventListener('click', (ev) => { ev.stopPropagation(); pop.hidden = true; run() })
      return el
    }
    pop.append(
      item('Copy as image (PNG)', () => copyPng(this.#exportCtx())),
      item('Copy as SVG (vector)', () => copySvg(this.#exportCtx()))
    )
    holder.append(btn, pop)
    this.#wirePopover(holder, btn, pop)
    return holder
  }

  // Relationship-property picker: a scrollable list of the graph's relationship
  // properties (each with a colour swatch + edge count), toggleable on/off, with
  // All/None bulk actions and a filter box that appears once the list is long — so
  // it stays usable whether the graph has 2 properties or 40.
  #buildFilter () {
    const props = this.#relProps()
    const holder = document.createElement('span')
    holder.className = 'entity-graph__icon-wrap'
    const btn = document.createElement('button')
    btn.type = 'button'
    btn.className = 'entity-graph__icon-btn'
    btn.title = 'Choose relationships'
    btn.setAttribute('aria-label', 'Choose relationships')
    // funnel/filter glyph
    btn.innerHTML = '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 5h18l-7 8v5l-4 2v-7L3 5z"/></svg>'

    // A dot on the button flags that some relationships are currently hidden, so
    // the filtered state is visible without opening the popover. Counts only the
    // hidden properties that actually exist in this graph.
    const keysHere = new Set(props.map((p) => p.key))
    const refreshBadge = () => {
      const n = [...this._hiddenProps].filter((k) => keysHere.has(k)).length
      btn.classList.toggle('is-filtered', n > 0)
      btn.title = n > 0 ? `Choose relationships (${n} hidden)` : 'Choose relationships'
      btn.setAttribute('aria-label', btn.title)
    }

    const pop = document.createElement('div')
    pop.className = 'entity-graph__filter-pop'
    pop.hidden = true

    // header: title + All / None
    const head = document.createElement('div'); head.className = 'entity-graph__filter-head'
    const title = document.createElement('span'); title.textContent = 'Relationships'
    const actions = document.createElement('span'); actions.className = 'entity-graph__filter-actions'
    const allBtn = document.createElement('button'); allBtn.type = 'button'; allBtn.textContent = 'All'
    const noneBtn = document.createElement('button'); noneBtn.type = 'button'; noneBtn.textContent = 'None'
    actions.append(allBtn, noneBtn)
    head.append(title, actions)
    pop.append(head)

    // optional filter box for long lists
    let filterInput = null
    if (props.length > 10) {
      filterInput = document.createElement('input')
      filterInput.type = 'search'; filterInput.placeholder = 'Filter…'; filterInput.className = 'entity-graph__filter-search'
      pop.append(filterInput)
    }

    const list = document.createElement('div'); list.className = 'entity-graph__filter-list'
    pop.append(list)

    // Toggling a relationship applies immediately (persist + redo the graph), like the
    // display settings — the panel is a side panel that doesn't cover the graph, so
    // direct "click → see the result" is clearer than deferring to close.
    const rowByKey = new Map()
    props.forEach(({ key, count }) => {
      const label = document.createElement('label'); label.className = 'entity-graph__filter-item'
      const cb = document.createElement('input'); cb.type = 'checkbox'; cb.className = 'form-check-input'; cb.checked = !this._hiddenProps.has(key)
      const text = document.createElement('span'); text.className = 'entity-graph__filter-name'; text.textContent = key
      const cnt = document.createElement('span'); cnt.className = 'entity-graph__filter-count'; cnt.textContent = count
      cb.addEventListener('change', () => {
        if (cb.checked) this._hiddenProps.delete(key); else this._hiddenProps.add(key)
        refreshBadge()
        this.#saveHiddenProps()
        this.#render()
      })
      label.append(cb, text, cnt)
      list.append(label)
      rowByKey.set(key, { cb, label })
    })

    const setAll = (on) => {
      props.forEach(({ key }) => {
        if (on) this._hiddenProps.delete(key); else this._hiddenProps.add(key)
        const r = rowByKey.get(key); if (r) r.cb.checked = on
      })
      refreshBadge()
      this.#saveHiddenProps()
      this.#render()
    }
    allBtn.addEventListener('click', (ev) => { ev.stopPropagation(); setAll(true) })
    noneBtn.addEventListener('click', (ev) => { ev.stopPropagation(); setAll(false) })
    if (filterInput) {
      filterInput.addEventListener('input', () => {
        const q = filterInput.value.trim().toLowerCase()
        rowByKey.forEach(({ label }, key) => { label.style.display = (!q || key.toLowerCase().includes(q)) ? '' : 'none' })
      })
      // keep clicks inside the search from closing the popover
      filterInput.addEventListener('click', (ev) => ev.stopPropagation())
    }

    // Persistent per-ontology hidden nodes: a 'Hidden nodes' section below the
    // relationships, so they can be seen and un-hidden individually.
    const renderHiddenNodes = this.#buildHiddenNodesSection(pop)

    holder.append(btn)
    refreshBadge() // reflect any persisted filter state on first paint
    // Changes apply immediately (each toggle / un-hide persists and redoes the graph),
    // like the display settings — the side panel doesn't cover the graph, so direct
    // "click → see the result" is clearer than deferring to close. On open, repopulate
    // the hidden-nodes list so it reflects the current set.
    btn.addEventListener('click', () => { if (pop.hidden) renderHiddenNodes() }, true)
    this.#wirePanel(btn, pop, 'Relationships & hidden nodes', 'filter')
    return holder
  }

  // Builds and appends the "Hidden nodes" section to the filter popover `pop`, and
  // returns a function to (re)render its list. Lists the persistent per-ontology
  // hidden classes so they can be seen and un-hidden individually. Un-hiding only
  // updates the pending set and this list; like the relationship checkboxes, it's
  // persisted and the graph is rebuilt once, when the popover closes.
  #buildHiddenNodesSection (pop) {
    const section = document.createElement('div'); section.className = 'entity-graph__filter-section'
    const head = document.createElement('div'); head.className = 'entity-graph__filter-head'
    const title = document.createElement('span'); title.textContent = 'Hidden nodes'
    const showAllBtn = document.createElement('button'); showAllBtn.type = 'button'; showAllBtn.textContent = 'Show all'
    const actions = document.createElement('span'); actions.className = 'entity-graph__filter-actions'
    actions.append(showAllBtn)
    head.append(title, actions)
    const list = document.createElement('div'); list.className = 'entity-graph__filter-list'
    section.append(head, list)
    pop.append(section)

    const render = () => {
      list.replaceChildren()
      const ids = [...this._hiddenNodes]
      section.style.display = ids.length ? '' : 'none'
      ids
        .map((id) => ({ id, label: this.#nodeLabel(id) }))
        .sort((a, b) => a.label.localeCompare(b.label))
        .forEach(({ id, label }) => {
          const row = document.createElement('div'); row.className = 'entity-graph__filter-item'
          const name = document.createElement('span'); name.className = 'entity-graph__filter-name'; name.textContent = label; name.title = id
          const rm = document.createElement('button'); rm.type = 'button'; rm.className = 'entity-graph__filter-show'
          rm.innerHTML = EYE_SVG; rm.title = 'Show this node again'; rm.setAttribute('aria-label', `Show ${label}`)
          rm.addEventListener('click', (ev) => {
            // Un-hide applies immediately (persist + redo the graph), like the
            // relationship toggles and display settings.
            ev.stopPropagation()
            this._hiddenNodes.delete(id)
            this.#saveHiddenNodes()
            this.#render()
          })
          row.append(name, rm)
          list.append(row)
        })
    }
    showAllBtn.addEventListener('click', (ev) => {
      ev.stopPropagation()
      if (!this._hiddenNodes.size) return
      this._hiddenNodes.clear()
      this.#saveHiddenNodes()
      this.#render()
    })
    render()
    return render
  }

  // Popout/close button: toggles a full-viewport overlay so the graph can use the
  // whole browser window. Re-renders on toggle so the layout re-fits to the new size.
  #buildPopout () {
    const holder = document.createElement('span')
    holder.className = 'entity-graph__icon-wrap'
    const btn = document.createElement('button')
    btn.type = 'button'
    btn.className = 'entity-graph__icon-btn'
    const full = this.element.classList.contains('entity-graph--fullscreen')
    btn.title = full ? 'Exit full window' : 'Open in full window'
    btn.setAttribute('aria-label', btn.title)
    // expand arrows, or an ✕ when already expanded
    btn.innerHTML = full
      ? '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>'
      : '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 4H4v5M20 9V4h-5M4 15v5h5M15 20h5v-5"/></svg>'
    btn.addEventListener('click', (ev) => { ev.stopPropagation(); this.#toggleFullscreen() })
    holder.append(btn)
    return holder
  }

  #toggleFullscreen () {
    const on = this.element.classList.toggle('entity-graph--fullscreen')
    // lock/unlock page scroll behind the overlay. Track that WE set it so
    // disconnect() can restore scrolling if Turbo swaps the frame while fullscreen.
    document.body.style.overflow = on ? 'hidden' : ''
    this._bodyOverflowLocked = on
    if (on) {
      this._escFull = (ev) => { if (ev.key === 'Escape') this.#toggleFullscreen() }
      document.addEventListener('keydown', this._escFull, { signal: this._ac.signal })
    } else if (this._escFull) {
      document.removeEventListener('keydown', this._escFull); this._escFull = null
    }
    // re-render so the layout re-fits to the new canvas size
    this.#render()
  }

  // Does the graph reference any upper-ontology (BFO/COB) terms? Checked against the
  // raw graph nodes (not the current hide/fade view) and cached, so the upper-ontology
  // controls are shown iff they'd actually do something.
  #hasUpperOntology () {
    if (this._hasUpper === undefined) {
      this._hasUpper = (this.nodes || []).some((n) => isUpperOnto(n.id))
    }
    return this._hasUpper
  }

  // The key that identifies a relationship property (its display label). Falls back
  // to an explicit property field or a placeholder for unlabelled relationships.
  #propKey (e) {
    return e.label || e.property || '(unlabelled)'
  }

  // Distinct relationship properties present in THIS graph, with edge counts, sorted
  // by frequency then name — so the picker lists only what's relevant (scales with
  // the graph, not the ontology's whole property set). Computed once.
  #relProps () {
    if (!this._relProps) {
      const counts = new Map()
      ;(this.edges || []).forEach((e) => {
        if (e.kind === 'is-a') return
        const k = this.#propKey(e)
        counts.set(k, (counts.get(k) || 0) + 1)
      })
      this._relProps = [...counts.entries()]
        .map(([key, count]) => ({ key, count }))
        .sort((a, b) => b.count - a.count || (a.key < b.key ? -1 : 1))
    }
    return this._relProps
  }

  // The graph the layout actually sees: hidden-property relationship edges dropped,
  // and removed/hidden nodes (plus their incident edges) taken out. The layout's own
  // connectivity prune then drops anything left disconnected from the selected class,
  // so removing a node also removes whatever only hung off it.
  #visibleGraph () {
    const cut = this.#cutNodes()
    if (!this._hiddenProps.size && !cut.size) return this.graph
    return {
      ...this.graph,
      nodes: this.graph.nodes.filter((n) => !cut.has(n.id)),
      edges: this.graph.edges.filter((e) =>
        !cut.has(e.from) && !cut.has(e.to) &&
        (e.kind === 'is-a' || !this._hiddenProps.has(this.#propKey(e))))
    }
  }

  // Nodes to take out of the graph = transient removals ∪ persistent per-ontology
  // hides, minus the selected class (never removable — it anchors the graph).
  #cutNodes () {
    const cut = new Set([...this._removedNodes, ...this._hiddenNodes])
    const sel = (this.nodes.find((n) => n.selected) || {}).id
    if (sel) cut.delete(sel)
    return cut
  }

  // Settings and filters persist in localStorage so they survive reloads and new
  // sessions (previously sessionStorage, which was cleared on tab close).
  #storageGet (key) {
    try { return window.localStorage.getItem(key) } catch (_) { return null }
  }

  #storageSet (key, value) {
    try { window.localStorage.setItem(key, value) } catch (_) { /* storage unavailable */ }
  }

  // Display options are ontology-independent, so they share one global key.
  #optsKey () { return 'entity-graph:opts' }

  #loadOpts () {
    try {
      const raw = this.#storageGet(this.#optsKey())
      if (raw) return JSON.parse(raw)
    } catch (_) { /* bad JSON — fall back to defaults */ }
    return {}
  }

  #saveOpts () {
    this.#storageSet(this.#optsKey(), JSON.stringify(this.opts))
  }

  // The hidden-property set is scoped to this ontology (property names aren't
  // comparable across ontologies).
  #hiddenPropsKey () {
    return 'entity-graph:hidden-props:' + (this.ontologyValue || '_')
  }

  #loadHiddenProps () {
    try {
      const raw = this.#storageGet(this.#hiddenPropsKey())
      if (raw) return new Set(JSON.parse(raw))
    } catch (_) { /* bad JSON — start empty */ }
    return new Set()
  }

  #saveHiddenProps () {
    this.#storageSet(this.#hiddenPropsKey(), JSON.stringify([...this._hiddenProps]))
  }

  // Persistent "never show this class in this ontology" set, keyed by ontology
  // (class IRIs are ontology-scoped), stored like the hidden-property set.
  #hiddenNodesKey () {
    return 'entity-graph:hidden-nodes:' + (this.ontologyValue || '_')
  }

  #loadHiddenNodes () {
    try {
      const raw = this.#storageGet(this.#hiddenNodesKey())
      if (raw) return new Set(JSON.parse(raw))
    } catch (_) { /* bad JSON — start empty */ }
    return new Set()
  }

  #saveHiddenNodes () {
    this.#storageSet(this.#hiddenNodesKey(), JSON.stringify([...this._hiddenNodes]))
  }

  #buildGear () {
    const cbByKey = {}
    const pop = document.createElement('div')
    pop.className = 'entity-graph__options-pop'
    pop.hidden = true

    // Each option gets a label, and an info (i) icon whose tooltip explains what it
    // does. `target` lets a section (e.g. the upper-ontology group) collect its own
    // rows instead of appending to the top-level popover.
    // `rerender` is true for options that change the drawn graph; tooltip-content
    // options leave it false, since the tooltip is rebuilt on each hover and a full
    // re-render would be wasteful (and would clear any active highlight).
    const addCheckbox = (key, text, help, target = pop, rerender = true) => {
      const label = document.createElement('label')
      label.className = 'entity-graph__option'
      const cb = document.createElement('input')
      cb.type = 'checkbox'; cb.className = 'form-check-input'; cb.checked = !!this.opts[key]
      cbByKey[key] = cb
      cb.addEventListener('change', () => {
        this.opts[key] = cb.checked
        // pills and acronym are mutually exclusive — sync the other box in place
        if (key === 'showPills' && cb.checked) { this.opts.showAcronym = false; cbByKey.showAcronym.checked = false }
        if (key === 'showAcronym' && cb.checked) { this.opts.showPills = false; cbByKey.showPills.checked = false }
        this.#saveOpts()
        this.#refreshGearBadge()
        if (rerender) this.#render()
      })
      const name = document.createElement('span'); name.className = 'entity-graph__option-name'; name.textContent = text
      label.append(cb, name, this.#infoIcon(help))
      target.append(label)
    }

    // Structure options — what edges/nodes are drawn.
    addCheckbox('isaOnly', 'Only show is-a',
      'Hide all relationship edges, showing just the is-a (subclass) hierarchy.')
    addCheckbox('transitiveReduction', 'Simplify is-a links',
      'Draw only direct-parent is-a links: drop the redundant edges to an ancestor that’s already reachable through a longer is-a chain.')
    // divider between structure options and node-label/display options
    pop.append(this.#optionDivider())
    // Display options — how nodes are labelled.
    addCheckbox('showPills', 'Show short-id pills',
      'Show each class’s short identifier (e.g. GO:0005634) as a chip inside its box.')
    addCheckbox('showAcronym', 'Show ontology acronym',
      'Tag each node with its source ontology’s acronym (e.g. UBERON, PATO).')

    // Tooltip section — which parts of the hover popup to show. These don't redraw
    // the graph (the tooltip is rebuilt on each hover), so they pass rerender=false.
    {
      const section = document.createElement('div'); section.className = 'entity-graph__option-section'
      const heading = document.createElement('div'); heading.className = 'entity-graph__option-section-title'
      heading.append(document.createTextNode('Tooltip'),
        this.#infoIcon('Choose what the hover popup shows for a class. The name and short id are always shown.'))
      section.append(heading)
      addCheckbox('tipDefinition', 'Definition', 'Show the class definition in the tooltip.', section, false)
      addCheckbox('tipIsa', 'is-a parents', 'Show the class’s direct is-a parents in the tooltip.', section, false)
      addCheckbox('tipSynonyms', 'Synonyms', 'Show the class’s synonyms in the tooltip.', section, false)
      addCheckbox('tipExamples', 'Examples of usage', 'Show the class’s “example of usage” sentences in the tooltip.', section, false)
      pop.append(section)
    }

    // Upper-ontology controls only make sense when the graph actually references
    // BFO/COB terms — otherwise Show/Fade/Hide and "authoritative info" are no-ops.
    // Grouped into their own labelled section at the bottom of the panel.
    if (this.#hasUpperOntology()) {
      const section = document.createElement('div'); section.className = 'entity-graph__option-section'
      const heading = document.createElement('div'); heading.className = 'entity-graph__option-section-title'
      heading.append(document.createTextNode('Upper ontology (BFO / COB)'),
        this.#infoIcon('BFO and COB are the abstract upper-ontology classes (continuant, occurrent, quality…) that sit above the domain terms. These control how they appear.'))
      section.append(heading)
      // Show / Fade / Hide is a THREE-state choice — a segmented control reads clearer.
      section.append(this.#buildUpperSegment())
      addCheckbox('useUpperInfo', 'Use authoritative BFO/COB info',
        'Prefer the upper ontology’s own label and definition for a BFO/COB class over the (often stub) imported one.', section)
      pop.append(section)
    }

    const holder = document.createElement('span')
    holder.className = 'entity-graph__icon-wrap'
    const btn = document.createElement('button')
    btn.type = 'button'
    btn.className = 'entity-graph__icon-btn'
    btn.title = 'Display options'
    btn.setAttribute('aria-label', 'Display options')
    // A clean, symmetric cog (Material-style gear): even trapezoidal teeth around a
    // round body with a hollow hub — reads as a gear at 16px without looking lumpy.
    btn.innerHTML = '<svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor"><path d="M19.14 12.94c.04-.31.06-.62.06-.94s-.02-.63-.06-.94l2.03-1.58a.5.5 0 00.12-.64l-1.92-3.32a.5.5 0 00-.6-.22l-2.39.96a7 7 0 00-1.62-.94l-.36-2.54a.5.5 0 00-.5-.42h-3.84a.5.5 0 00-.5.42l-.36 2.54c-.58.24-1.12.56-1.62.94l-2.39-.96a.5.5 0 00-.6.22L2.74 8.84a.5.5 0 00.12.64l2.03 1.58c-.04.31-.06.63-.06.94s.02.63.06.94l-2.03 1.58a.5.5 0 00-.12.64l1.92 3.32c.13.23.4.32.63.22l2.39-.96c.5.38 1.04.7 1.62.94l.36 2.54c.05.24.25.42.5.42h3.84c.25 0 .45-.18.5-.42l.36-2.54c.58-.24 1.12-.56 1.62-.94l2.39.96c.23.1.5.01.63-.22l1.92-3.32a.5.5 0 00-.12-.64l-2.03-1.58zM12 15.6A3.6 3.6 0 1112 8.4a3.6 3.6 0 010 7.2z"/></svg>'
    holder.append(btn)
    // Flag the gear when a CONTENT-HIDING option is active (is-a-only, or upper
    // ontology hidden) — these silently remove edges/nodes, and because settings
    // persist they can carry over from a previous session; the dot makes that
    // visible instead of leaving the user staring at a graph with no relationships.
    this._gearBtn = btn
    this.#refreshGearBadge()
    this.#wirePanel(btn, pop, 'Display options', 'gear')
    return holder
  }

  // A thin rule between two groups of options within the settings panel.
  #optionDivider () {
    const hr = document.createElement('div')
    hr.className = 'entity-graph__option-divider'
    return hr
  }

  // A small (i) info icon that explains an option. Shows the custom tooltip on hover
  // (immediate and styled, unlike the native `title`, which is slow and easy to miss).
  // Clicking it must not toggle the option's checkbox, so it swallows the click.
  #infoIcon (text) {
    const el = document.createElement('span')
    el.className = 'entity-graph__option-info'
    el.innerHTML = INFO_SVG
    el.setAttribute('aria-label', text)
    el.addEventListener('click', (ev) => { ev.preventDefault(); ev.stopPropagation() })
    el.addEventListener('mouseenter', (ev) => this.#showInfoTip(ev, text))
    el.addEventListener('mousemove', (ev) => this.#positionTip(ev.clientX, ev.clientY))
    el.addEventListener('mouseleave', () => this.#hideTip())
    return el
  }

  // Show the shared tooltip with a plain-text help string (used by the option info
  // icons), positioned near the cursor.
  #showInfoTip (ev, text) {
    const tip = this.#ensureTip()
    tip.style.maxWidth = '280px'
    tip.innerHTML = `<div style="color:#4a5b6e">${this.#esc(text)}</div>`
    tip.style.display = 'block'
    this.#positionTip(ev.clientX, ev.clientY)
  }

  #refreshGearBadge () {
    const btn = this._gearBtn; if (!btn) return
    const hiding = !!this.opts.isaOnly || !!this.opts.hideUpper
    btn.classList.toggle('is-filtered', hiding)
    const why = this.opts.isaOnly
      ? 'showing is-a only — relationships hidden'
      : (this.opts.hideUpper ? 'upper ontology hidden' : '')
    btn.title = hiding ? `Display options (${why})` : 'Display options'
    btn.setAttribute('aria-label', btn.title)
  }

  // Segmented control for the upper-ontology (BFO/COB) display: Show / Fade / Hide.
  // Maps to the two underlying flags: hide wins; otherwise fade toggles the dimming.
  #buildUpperSegment () {
    const wrap = document.createElement('div')
    wrap.className = 'entity-graph__seg-row'
    const seg = document.createElement('div')
    seg.className = 'entity-graph__seg'
    const current = this.opts.hideUpper ? 'hide' : (this.opts.fadeUpper ? 'fade' : 'show')
    const modes = [['show', 'Show'], ['fade', 'Fade'], ['hide', 'Hide']]
    modes.forEach(([mode, text]) => {
      const b = document.createElement('button')
      b.type = 'button'
      b.className = 'entity-graph__seg-btn' + (mode === current ? ' is-active' : '')
      b.textContent = text
      b.addEventListener('click', (ev) => {
        ev.stopPropagation()
        this.opts.hideUpper = (mode === 'hide')
        this.opts.fadeUpper = (mode === 'fade')
        seg.querySelectorAll('.entity-graph__seg-btn').forEach((x) => x.classList.remove('is-active'))
        b.classList.add('is-active')
        this.#saveOpts()
        this.#refreshGearBadge()
        this.#render()
      })
      seg.append(b)
    })
    wrap.append(seg)
    return wrap
  }

  #buildHelp () {
    const key = (svg, text) => `<span class="entity-graph__legend-item"><svg width="30" height="14" style="overflow:visible">${svg}</svg>${text}</span>`
    const content =
      key('<line x1="1" y1="7" x2="22" y2="7" stroke="#f0a848" stroke-width="2.5"/><path d="M20,3 L27,7 L20,11 Z" fill="#f0a848"/>', 'is-a (subclass)') +
      key('<line x1="1" y1="7" x2="22" y2="7" stroke="#2f6fed" stroke-width="2.5"/><path d="M20,3 L27,7 L20,11" fill="none" stroke="#2f6fed"/>', 'relationship') +
      key('<line x1="1" y1="7" x2="22" y2="7" stroke="#e6c79a" stroke-width="1.6"/><path d="M21,4 L27,7 L21,10 Z" fill="#e6c79a"/>', 'to upper ontology') +
      key('<circle cx="6" cy="7" r="3.4" fill="#2f6fed"/><line x1="9" y1="7" x2="28" y2="7" stroke="#2f6fed" stroke-width="2"/>', '● = source end') +
      key('<rect x="1" y="2" width="26" height="10" rx="2.5" fill="#fff" stroke="#234979" stroke-width="1.6"/>', 'class') +
      key('<rect x="1" y="2" width="26" height="10" rx="2.5" fill="#fff" stroke="#c3ccd8" stroke-width="1.2"/>', 'upper ontology (faded)') +
      '<div class="entity-graph__legend-hint">Click a node to highlight its path to the root · double-click to open it · scroll or drag to pan · ⌘/Ctrl+scroll to zoom · F to fit highlight</div>'

    const holder = document.createElement('span')
    holder.className = 'entity-graph__icon-wrap'
    const btn = document.createElement('button')
    btn.type = 'button'
    btn.className = 'entity-graph__icon-btn'
    btn.title = 'Graph key & shortcuts'
    btn.setAttribute('aria-label', 'Graph key and shortcuts')
    btn.textContent = '?'
    const pop = document.createElement('div')
    pop.className = 'entity-graph__help-pop'
    pop.hidden = true
    pop.innerHTML = content
    holder.append(btn, pop)
    this.#wirePopover(holder, btn, pop)
    return holder
  }

  // toggle a popover open/closed; a document click outside the holder closes it.
  // onClose (optional) fires whenever the popover transitions from open to closed —
  // used by the filter popover to apply pending changes only once, on close.
  #wirePopover (holder, btn, pop, onClose) {
    const close = () => {
      if (pop.hidden) return
      pop.hidden = true
      document.removeEventListener('click', onDoc, true)
      if (onClose) onClose()
    }
    const onDoc = (ev) => { if (!holder.contains(ev.target)) close() }
    btn.addEventListener('click', (ev) => {
      ev.stopPropagation()
      if (pop.hidden) {
        pop.hidden = false
        setTimeout(() => document.addEventListener('click', onDoc, { capture: true, signal: this._ac.signal }), 0)
      } else {
        close()
      }
    })
  }

  // A side panel: like a popover, but docked to the right edge of the canvas at full
  // height so tall content (the relationship + hidden-node lists, all the settings)
  // scrolls internally instead of overflowing the viewport. The panel is moved OUT of
  // its icon holder and appended to the canvas so it docks to the canvas edge; only
  // one panel is open at a time (opening one closes the other). `title` is shown in a
  // header with a close button; optional `onClose` fires on any close.
  #wirePanel (btn, panel, title, key, onClose) {
    // Wrap the panel's existing content in a scrolling body, then add a fixed header
    // above it (title + close). The body scrolls as one column so tall content stays
    // in the panel instead of overflowing.
    const body = document.createElement('div'); body.className = 'entity-graph__panel-body'
    while (panel.firstChild) body.append(panel.firstChild)
    const header = document.createElement('div'); header.className = 'entity-graph__panel-head'
    const h = document.createElement('span'); h.className = 'entity-graph__panel-title'; h.textContent = title
    const x = document.createElement('button'); x.type = 'button'; x.className = 'entity-graph__panel-close'
    x.innerHTML = '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>'
    x.title = 'Close'; x.setAttribute('aria-label', 'Close')
    header.append(h, x)
    panel.append(header, body)
    panel.classList.add('entity-graph__panel')
    // dock to the canvas edge (not the icon), so full-height positioning is simple
    this.canvasTarget.append(panel)

    // Slide animation: `--open` drives a transform transition (see CSS). We keep
    // `panel.hidden` as the logical open/closed flag but only flip it to true AFTER
    // the slide-out finishes, so the panel animates off-screen instead of vanishing.
    const close = (viaRender) => {
      if (panel.hidden || panel.__closing) return
      document.removeEventListener('click', onDoc, true)
      if (this._openPanel === panel) this._openPanel = null
      // `viaRender` is a silent close during a re-render (chrome is being rebuilt) —
      // keep _openPanelKey so #buildChrome can reopen this panel afterwards, and skip
      // onClose (it will run when the user actually closes it).
      if (!viaRender) { if (this._openPanelKey === key) this._openPanelKey = null; if (onClose) onClose() }
      if (viaRender) { panel.hidden = true; return } // re-render destroys it; no animation
      // animate out, then hide once the slide finishes
      panel.__closing = true
      panel.classList.remove('entity-graph__panel--open')
      const done = () => { panel.hidden = true; panel.__closing = false; panel.removeEventListener('transitionend', done) }
      panel.addEventListener('transitionend', done)
      setTimeout(done, 300) // fallback if transitionend doesn't fire
    }
    // Outside-click closes the panel — but only for a genuine outside click. A click
    // on an option INSIDE the panel triggers a re-render that rebuilds the chrome, so
    // by the time this fires the clicked element is detached from the DOM; treat that
    // as "not outside" so toggling an option never closes the panel (it only closes on
    // the × or a real click elsewhere).
    const onDoc = (ev) => {
      if (!ev.target.isConnected) return
      if (!panel.contains(ev.target) && ev.target !== btn && !btn.contains(ev.target)) close()
    }
    const open = (instant) => {
      if (this._openPanel && this._openPanel !== panel) this._openPanel.__close()  // one at a time
      panel.__closing = false
      panel.hidden = false
      if (instant) {
        // no slide — used when reopening after a re-render, so a settings toggle
        // doesn't make the panel flick out and back in.
        panel.classList.add('entity-graph__panel--no-anim', 'entity-graph__panel--open')
        requestAnimationFrame(() => panel.classList.remove('entity-graph__panel--no-anim'))
      } else {
        // add --open on the next frame so the transition runs from the off-screen state
        requestAnimationFrame(() => requestAnimationFrame(() => panel.classList.add('entity-graph__panel--open')))
      }
      this._openPanel = panel
      this._openPanelKey = key
      setTimeout(() => document.addEventListener('click', onDoc, { capture: true, signal: this._ac.signal }), 0)
    }
    panel.__close = close // let the "one at a time" logic close a sibling panel
    panel.__open = open // let #buildChrome reopen the previously-open panel after a render
    x.addEventListener('click', (ev) => { ev.stopPropagation(); close() })
    btn.addEventListener('click', (ev) => { ev.stopPropagation(); panel.hidden ? open() : close() })
    // Reopen this panel if it was open before a re-render rebuilt the chrome (e.g. a
    // settings checkbox toggled the graph). Matched by its stable key; instant (no
    // slide) since it's a continuation of an already-open panel.
    if (this._openPanelKey === key) open(true)
  }

  // --- rendering ------------------------------------------------------------

  #render () {
    const nodeH = this.#effNodeH()
    // debug: draw the dummy-node waypoints that long edges are routed through. Enable
    // by running `localStorage.setItem('entity-graph:debug-dummies','1')` in the
    // console and reloading (or set window.__egDebugDummies=true for the current
    // render). Picked up on the natural initial render so there's no re-render.
    let debugDummies = typeof window !== 'undefined' && !!window.__egDebugDummies
    try { debugDummies = debugDummies || window.localStorage.getItem('entity-graph:debug-dummies') === '1' } catch (_) { /* storage off */ }
    // Dummy-node routing is OFF by default: an A/B on heart/urinary bladder showed it
    // gives little and inconsistent crossing benefit (heart 20=20, bladder 2 vs 4)
    // while long edges route just as well as plain curves and the graph reads cleaner
    // and more compact. The machinery is kept behind this opt-in flag for experiments:
    // localStorage 'entity-graph:dummies'='1' (or window.__egDummies) re-enables it.
    let dummiesOn = typeof window !== 'undefined' && !!window.__egDummies
    try { dummiesOn = dummiesOn || window.localStorage.getItem('entity-graph:dummies') === '1' } catch (_) { /* storage off */ }
    const L = computeLayout(this.#visibleGraph(), { ...this.opts, nodeH, debugDummies, noDummies: !dummiesOn })
    this._layout = L
    const N = (id) => L.nodes.get(id)

    const svg = document.createElementNS(SVG, 'svg')
    svg.setAttribute('class', 'entity-graph__svg')
    svg.innerHTML = this.#defs()

    // viewport group holds all drawable content; its transform is the zoom/pan
    const vp = document.createElementNS(SVG, 'g'); vp.setAttribute('data-viewport', '')
    const eg = document.createElementNS(SVG, 'g') // edges
    const hg = document.createElementNS(SVG, 'g') // transparent edge hit-areas
    const ng = document.createElementNS(SVG, 'g') // nodes
    const og = document.createElementNS(SVG, 'g') // hover overlay (raised edge)
    vp.append(eg, hg, ng, og)
    svg.append(vp)

    const obstacles = [...L.nodes.values()].map((n) => ({ id: n.id, x: n.x, y: n.y, w: n.width, h: nodeH }))
    const laneReg = []
    const edgeRecs = []
    const nodeEls = new Map()
    const incidentEdges = new Map()
    const fullAdj = new Map()
    // fullRev: all edges reversed (to -> from). Used with fullAdj to find every
    // node on some selected -> clicked route, which may cross relationship edges.
    const fullRev = new Map()
    const upAdj = new Map()
    // is-a-only up-adjacency (node -> its parents). The clicked node's path to
    // root is an ancestry path, so that segment uses is-a edges only.
    const isaUp = new Map()
    const labelReqs = []
    let hoveredEdge = null
    const nodeLit = new Set()

    // selection state: traceId is the clicked node whose ancestry ribbon is lit
    // (null when nothing is highlighted). There is no per-node/per-edge selection.
    this._sel = { traceId: null }

    // Fan-out attach points: several is-a children entering the same parent used to
    // converge on its bottom-centre and bunch into one thick doubled line. Spread
    // each parent's incoming is-a edges across a band of its bottom edge — ordered
    // by the child's x so lines don't cross — keyed "from|to" -> x-offset at parent.
    const attachOffset = new Map()
    {
      const byParent = new Map()
      L.treeEdges.forEach((e) => { if (e.kind === 'is-a') (byParent.get(e.to) || byParent.set(e.to, []).get(e.to)).push(e) })
      byParent.forEach((kids, pid) => {
        if (kids.length < 2) return // single child attaches at centre, no fan needed
        const p = N(pid); if (!p) return
        kids.sort((x, y) => (N(x.from)?.x || 0) - (N(y.from)?.x || 0))
        const band = Math.min(p.width - 24, 26 * (kids.length - 1)) // stay inside the box
        kids.forEach((e, i) => {
          const t = kids.length === 1 ? 0.5 : i / (kids.length - 1)
          attachOffset.set(e.from + '|' + e.to, (t - 0.5) * band)
        })
      })
    }

    const drawEdge = (e, curved) => {
      const a = N(e.from); const b = N(e.to); if (!a || !b) return
      const isa = e.kind === 'is-a'
      const toColl = this.opts.fadeUpper && L.collector && L.collector.has(e.to)
      const attX = attachOffset.get(e.from + '|' + e.to) || 0
      const routed = (curved && e.waypoints && e.waypoints.length)
        ? waypointPath(a, b, e.waypoints, nodeH)
        : (curved ? routePath(a, b, obstacles, laneReg, nodeH) : curvedIsaPath(a, b, nodeH, attX))
      const { d, mid, seg } = routed
      const p = document.createElementNS(SVG, 'path')
      p.setAttribute('class', 'entity-graph__edge entity-graph__edge--' + (isa ? 'is-a' : 'rel') + (toColl ? ' entity-graph__edge--to-collector' : ''))
      p.setAttribute('d', d)
      p.setAttribute('marker-end', toColl ? 'url(#eg-ah-coll)' : (isa ? 'url(#eg-ah-isa)' : 'url(#eg-ah-rel)'))
      p.setAttribute('marker-start', toColl ? 'url(#eg-src-coll)' : (isa ? 'url(#eg-src-isa)' : 'url(#eg-src-rel)'))
      eg.append(p)
      const rec = { el: p, from: e.from, to: e.to, isa }
      const hit = document.createElementNS(SVG, 'path'); hit.setAttribute('class', 'entity-graph__edge-hit'); hit.setAttribute('d', d)
      const setHover = (on) => {
        p.classList.toggle('entity-graph__edge--hover', on)
        ;(on ? og : eg).append(p)
      }
      hit.addEventListener('mouseenter', (ev) => {
        if (hoveredEdge && hoveredEdge !== rec) hoveredEdge.setHover(false); hoveredEdge = rec; setHover(true)
        // Relationship edges get a popup naming the property; is-a edges don't — the
        // orange arrow and the node tooltip's "is-a → …" line already convey them.
        if (!isa && e.label) this.#showEdgeTip(ev, e.label, e.propId)
      })
      if (!isa && e.label) hit.addEventListener('mousemove', (ev) => this.#positionTip(ev.clientX, ev.clientY))
      hit.addEventListener('mouseleave', () => { setHover(false); if (hoveredEdge === rec) hoveredEdge = null; this.#hideTip() })
      rec.setHover = setHover
      hg.append(hit)
      edgeRecs.push(rec)
      ;(incidentEdges.get(e.from) || incidentEdges.set(e.from, []).get(e.from)).push(rec)
      ;(incidentEdges.get(e.to) || incidentEdges.set(e.to, []).get(e.to)).push(rec)
      ;(fullAdj.get(e.from) || fullAdj.set(e.from, []).get(e.from)).push(e.to)
      ;(fullRev.get(e.to) || fullRev.set(e.to, []).get(e.to)).push(e.from)
      if (b.y < a.y - 1) (upAdj.get(e.from) || upAdj.set(e.from, []).get(e.from)).push(e.to)
      // is-a edge: from = subclass (child), to = superclass (parent)
      if (isa) (isaUp.get(e.from) || isaUp.set(e.from, []).get(e.from)).push(e.to)
      if (!isa && e.label && mid) labelReqs.push({ text: e.label, x: mid.x, y: mid.y, from: e.from, to: e.to, els: [] })
    }
    L.treeEdges.forEach((e) => drawEdge(e, false))
    L.overlays.forEach((e) => drawEdge(e, true))

    // debug: draw the dummy-node waypoints (the corridors long edges are routed
    // through). Only present when opts.debugDummies is on. Magenta rings so they
    // stand out against the graph.
    if (L.dummyDebug && L.dummyDebug.length) {
      const dg = document.createElementNS(SVG, 'g')
      L.dummyDebug.forEach((d) => {
        const c = document.createElementNS(SVG, 'circle')
        c.setAttribute('cx', d.x); c.setAttribute('cy', d.y); c.setAttribute('r', '4')
        c.setAttribute('fill', '#ff00aa'); c.setAttribute('stroke', '#ffffff'); c.setAttribute('stroke-width', '1')
        dg.append(c)
      })
      vp.append(dg)
    }

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
    this._render = { svg, vp, eg, og, ng, N, nodeEls, edgeRecs, incidentEdges, fullAdj, fullRev, upAdj, isaUp, labelReqs, nodeLit, nodeH }
    this.#wireNodeInteractions(nodeEls, incidentEdges)
    this.#wireBackground(svg)

    // Attach FIRST, then measure content bounds: getBBox() only reports real
    // geometry once the SVG is in the document, so world must be computed after
    // replaceChildren (measuring a detached SVG returned a truncated box, which
    // made fit-to-view mis-scale).
    // Tear down the open panel's document-level outside-click listener BEFORE the
    // chrome is wiped: replaceChildren only detaches the DOM, it doesn't run our
    // close(), so the capture-phase `onDoc` handler would otherwise leak onto
    // `document` on every toggle. A leaked handler (bound to the now-detached panel)
    // fires on the next click, sees the new checkbox isn't inside its old panel, and
    // closes — clearing _openPanelKey so the panel fails to reopen. close(true) removes
    // the listener quietly and preserves _openPanelKey so #buildChrome reopens it.
    if (this._openPanel) this._openPanel.__close(true)
    this.canvasTarget.replaceChildren(svg) // wipes the old chrome/panels; rebuilt below
    this._openPanel = null // panels are recreated per render; drop the stale reference
    const world = this.#worldBounds(vp, L)
    this._render.world = world // for whole-graph export
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
      pt.setAttribute('font-family', '-apple-system, Helvetica, Arial, sans-serif')
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
        at.setAttribute('font-family', '-apple-system, Helvetica, Arial, sans-serif')
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

  // Content bounds ("world"). The layout's own width/height are the authoritative
  // extent and are always available (DOM-independent); getBBox is used only to
  // EXPAND them for edge curves that bow beyond the node box — and only when it
  // returns a valid (non-degenerate) box, since a detached or display:none SVG
  // reports a zero/truncated box that would otherwise corrupt the fit scale.
  #worldBounds (vp, L) {
    const PAD = 10
    let x0 = -PAD; let y0 = -PAD; let x1 = L.width + PAD; let y1 = L.height + PAD
    try {
      const bb = vp.getBBox()
      // trust getBBox only if it plausibly covers the laid-out content
      if (bb.width >= L.width * 0.5 && bb.height >= L.height * 0.5) {
        x0 = Math.floor(Math.min(0, bb.x) - PAD); y0 = Math.floor(Math.min(0, bb.y) - PAD)
        x1 = Math.ceil(Math.max(L.width, bb.x + bb.width) + PAD); y1 = Math.ceil(Math.max(L.height, bb.y + bb.height) + PAD)
      }
    } catch (_) { /* getBBox throws if not laid out; keep the layout-dim fallback */ }
    return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }
  }

  // --- node label / id helpers ---------------------------------------------

  #effLabel (n) {
    return (this.opts.useUpperInfo && n.upper && n.upper.label) ? n.upper.label : n.label
  }

  // Human-readable label for a class IRI. Uses the node's label if it's in this
  // graph; otherwise falls back to the short id (a class hidden from a different
  // class's graph may not appear in this one).
  #nodeLabel (iri) {
    const n = this.graph.nodes.find((x) => x.id === iri)
    return (n && this.#effLabel(n)) || shortId(iri) || iri
  }

  #classPath (iri) {
    // Navigating from a graph node should land on the same Graph view and keep the
    // active language, rather than resetting to Details in the portal default
    // language. Carry both forward from the current page URL when present.
    let url = `/ontologies/${encodeURIComponent(this.ontologyValue)}?p=classes&conceptid=${encodeURIComponent(iri)}&view=concept-graph`
    const cur = new URLSearchParams(window.location.search)
    const lang = cur.get('language') || cur.get('lang')
    if (lang) url += `&language=${encodeURIComponent(lang)}`
    return url
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
        clickTimer = setTimeout(() => { clickTimer = null; this.#traceNode(id) }, 220)
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
    // #wireNodeInteractions runs on every #render; remove the previous handler
    // before re-adding so re-renders don't stack duplicate document listeners.
    if (this._escHandler) document.removeEventListener('keydown', this._escHandler)
    this._escHandler = (ev) => { if (ev.key === 'Escape') this.#clearSelection() }
    document.addEventListener('keydown', this._escHandler, { signal: this._ac.signal })
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

  // --- node removal ---------------------------------------------------------

  // Take a node out of THIS graph only (transient — a reload brings it back).
  #removeNode (id) {
    this._removedNodes.add(id)
    this.#render()
    this.#toast('Removed from graph')
  }

  // Always hide a node in this ontology (persistent across graphs and sessions).
  #hideNode (id) {
    this._hiddenNodes.add(id)
    this.#saveHiddenNodes()
    this.#render()
    this.#toast(`Hidden in ${this.ontologyValue || 'this ontology'}`)
  }

  #restoreRemovedNodes () {
    if (!this._removedNodes.size) return
    this._removedNodes.clear()
    this.#render()
  }

  #restoreHiddenNodes () {
    if (!this._hiddenNodes.size) return
    this._hiddenNodes.clear()
    this.#saveHiddenNodes()
    this.#render()
  }

  // Highlight the is-a path(s) from the selected class up through the clicked
  // node to the root, dimming everything else. Click the same node again (or the
  // background / Escape) to clear. This is the only focus gesture — there is no
  // per-node or per-edge selection.
  #traceNode (id) {
    const s = this._sel
    const turningOn = s.traceId !== id
    s.traceId = turningOn ? id : null
    this.#applyFocus()
    // If the clicked node can't be reached from the selected class at all (not via
    // is-a nor relationships in this graph), only the clicked -> root tail is
    // shown; say so rather than leaving it looking disconnected.
    if (turningOn && id !== (this.nodes.find((n) => n.selected) || {}).id &&
        !this.#clickedReachableFromSelected(id)) {
      this.#toast('Not reachable from the selected class — showing its path to the root')
    }
  }

  #clearSelection () {
    const s = this._sel
    if (s.traceId) { s.traceId = null; this.#applyFocus() }
  }

  // The highlight is a ribbon that connects the selected class, through the
  // clicked node, up to the root. It has two segments joined at the clicked node:
  //   selected -> clicked : every node/edge on some route from the selected class
  //                         to the clicked node, over ALL edges (is-a AND
  //                         relationship), following edge direction. This keeps the
  //                         ribbon anchored to the selected class even when the two
  //                         are connected by a "has part"-style relationship rather
  //                         than pure ancestry.
  //   clicked  -> root    : the clicked node's is-a ancestor closure (path to root
  //                         is an ancestry path, so is-a edges only).
  // Returns { nodes, edgeOn } where edgeOn(rec) says whether an edge lies on the
  // ribbon. Null when nothing is highlighted.
  #traceSet () {
    const s = this._sel; if (!s.traceId) return null
    const R = this._render
    const clicked = s.traceId
    const selId = (this.nodes.find((n) => n.selected) || {}).id

    const closure = (start, adj) => {
      const seen = new Set(); const stack = [start]
      while (stack.length) { const x = stack.pop(); if (seen.has(x)) continue; seen.add(x); (adj.get(x) || []).forEach((t) => stack.push(t)) }
      return seen
    }

    // clicked -> root: is-a ancestors of the clicked node.
    const toRoot = closure(clicked, R.isaUp)
    const nodes = new Set(toRoot)

    // selected -> clicked: a node lies on some route iff it is forward-reachable
    // from the selected class AND can still reach the clicked node. Intersect
    // "reachable from selected" (over all edges) with "can reach clicked" (over all
    // edges reversed).
    let onRoute = new Set()
    if (selId && selId !== clicked) {
      const fromSel = closure(selId, R.fullAdj)       // reachable from selected
      const canReachClicked = closure(clicked, R.fullRev) // can reach clicked
      onRoute = new Set([...fromSel].filter((n) => canReachClicked.has(n)))
      onRoute.forEach((n) => nodes.add(n))
    }

    // An edge is on the ribbon if: it's an is-a edge within the clicked->root
    // ancestry, OR both its endpoints are on a selected->clicked route (any kind).
    const edgeOn = (rec) =>
      (rec.isa && toRoot.has(rec.from) && toRoot.has(rec.to)) ||
      (onRoute.has(rec.from) && onRoute.has(rec.to))

    return { nodes, edgeOn }
  }

  // True when the clicked node is reachable from the selected class over the
  // displayed edges (i.e. the "selected -> clicked" segment is non-empty). Used to
  // decide whether to toast that only the clicked -> root tail is shown.
  #clickedReachableFromSelected (clicked) {
    const R = this._render
    const selId = (this.nodes.find((n) => n.selected) || {}).id
    if (!selId || selId === clicked) return false
    const stack = [selId]; const seen = new Set()
    while (stack.length) {
      const x = stack.pop(); if (seen.has(x)) continue; seen.add(x)
      if (x === clicked) return true
      ;(R.fullAdj.get(x) || []).forEach((t) => stack.push(t))
    }
    return false
  }

  #applyFocus () {
    const R = this._render; if (!R) return
    const s = this._sel
    if (!s.traceId) {
      R.edgeRecs.forEach((r) => r.el.classList.remove('entity-graph__edge--dim', 'entity-graph__edge--sel'))
      R.nodeEls.forEach((g) => g.classList.remove('entity-graph__node--dim', 'entity-graph__node--sel'))
      R.labelReqs.forEach((r) => r.els.forEach((el) => el.classList.remove('entity-graph__edge-label--dim', 'entity-graph__edge-label-bg--dim')))
      return
    }
    const trace = this.#traceSet() || { nodes: new Set(), edgeOn: () => false }
    const litNodes = trace.nodes
    const litEdge = trace.edgeOn
    R.nodeEls.forEach((g, id) => {
      const on = litNodes.has(id)
      g.classList.toggle('entity-graph__node--dim', !on)
      g.classList.toggle('entity-graph__node--sel', on)
    })
    R.edgeRecs.forEach((rec) => {
      const on = litEdge(rec)
      rec.el.classList.toggle('entity-graph__edge--dim', !on)
      rec.el.classList.toggle('entity-graph__edge--sel', on)
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
    if (!this._sel.traceId) return new Set()
    const trace = this.#traceSet()
    return trace ? trace.nodes : new Set()
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
    const hasSel = !!s.traceId
    const items = []
    const isSelectedClass = nodeId && nodeId === (this.nodes.find((n) => n.selected) || {}).id
    if (nodeId) {
      const sid = shortId(nodeId)
      items.push({ label: s.traceId === nodeId ? 'Clear highlight' : 'Highlight path to root', run: () => this.#traceNode(nodeId) })
      items.push({ label: 'Fit to highlight (F)', disabled: !hasSel, run: () => this.#fitToSelection() })
      items.push({ label: 'Open class', run: () => { window.location.href = this.#classPath(nodeId) } })
      items.push({ separator: true })
      // Node removal — never offered for the selected class (it anchors the graph).
      items.push({ label: 'Remove from graph', disabled: isSelectedClass, run: () => this.#removeNode(nodeId) })
      items.push({ label: `Never show in ${this.ontologyValue || 'this ontology'}`, disabled: isSelectedClass, run: () => this.#hideNode(nodeId) })
      items.push({ separator: true })
      items.push({ label: sid ? ('Copy ' + sid) : 'Copy short-id', disabled: !sid, run: () => this.#copyText(sid) })
      items.push({ label: 'Copy IRI', run: () => this.#copyText(nodeId) })
      items.push({ separator: true })
    } else {
      items.push({ label: 'Fit to highlight (F)', disabled: !hasSel, run: () => this.#fitToSelection() })
      items.push({ label: 'Fit whole graph', run: () => this._zoomApi && this._zoomApi.recenter() })
      items.push({ separator: true })
    }
    // Restore removed/hidden nodes — shown wherever there's something to restore.
    if (this._removedNodes.size) items.push({ label: `Restore removed nodes (${this._removedNodes.size})`, run: () => this.#restoreRemovedNodes() })
    if (this._hiddenNodes.size) items.push({ label: `Show always-hidden nodes (${this._hiddenNodes.size})`, run: () => this.#restoreHiddenNodes() })
    items.push({ label: 'Clear highlight', disabled: !hasSel, run: () => this.#clearSelection() })

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
    setTimeout(() => document.addEventListener('click', this._menuDismiss, { once: true, signal: this._ac.signal }), 0)
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

  // --- graph export (copy PNG / SVG) ----------------------------------------

  // Context handed to the graph_export module: the live SVG, its content bounds,
  // a safe filename, and the toast callback. Keeps export logic out of the controller.
  #exportCtx () {
    const R = this._render
    return {
      svg: R?.svg,
      world: R?.world,
      name: safeFileName(this.graph?.nodes?.find((n) => n.selected)?.label),
      toast: (m) => this.#toast(m)
    }
  }

  // --- popup / tooltip ------------------------------------------------------

  #ensureTip () {
    if (this._tip) return this._tip
    const tip = document.createElement('div')
    tip.style.cssText = 'position:fixed;z-index:2500;max-width:600px;background:#fff;border:1px solid #d4dde8;border-radius:8px;box-shadow:0 4px 20px rgba(0,0,0,.16);padding:12px 15px;font:15px -apple-system,sans-serif;color:#28374a;pointer-events:none;display:none;line-height:1.5'
    document.body.append(tip)
    this._tip = tip
    return tip
  }

  #esc (s) { const d = document.createElement('div'); d.textContent = String(s == null ? '' : s); return d.innerHTML }

  #showTip (ev, n, id) {
    const tip = this.#ensureTip()
    tip.style.maxWidth = '570px' // reset — the option info tooltip narrows the shared tip
    const label = this.#effLabel(n)
    const sid = shortId(id)
    const pill = sid ? ` <span style="display:inline-block;font-size:12px;font-weight:600;padding:1px 7px;margin-left:5px;border-radius:8px;background:#eef2f7;color:#5a6b82;vertical-align:middle">${this.#esc(sid)}</span>` : ''
    const parents = this.#isaParents(id)
    const def = this.opts.useUpperInfo && n.upper && n.upper.definition ? n.upper.definition : n.definition
    const syn = this.#effSynonyms(n)
    const src = (this.opts.useUpperInfo && n.upper && (n.upper.definition || n.upper.label)) ? n.upper.source : ''
    const srcTag = src ? ` <span style="font-size:12px;font-weight:600;color:#1c7a63;background:#dff3ee;border:1px solid #a9ddd0;border-radius:8px;padding:1px 7px;margin-left:4px;vertical-align:middle">from ${this.#esc(src)}</span>` : ''
    // Tooltip sections use coloured pills to distinguish their kind:
    //   is-a parents -> blue (navigable superclasses)
    //   synonyms     -> neutral grey (matches the header short-id pill)
    const pillRow = (items, bg, fg) =>
      `<div style="margin-top:3px;display:flex;flex-wrap:wrap;gap:4px">` +
      items.map((s) => `<span style="display:inline-block;font-size:13px;padding:1px 8px;border-radius:8px;background:${bg};color:${fg};white-space:nowrap">${s}</span>`).join('') +
      '</div>'
    // is-a parent pills: shown parents in solid blue; parents present in the class
    // but hidden from the drawn graph (e.g. upper-ontology when "hide upper" is on)
    // in a muted, dashed-outline pill with a "· hidden" note, so the user still sees
    // the real superclass rather than "no parents".
    const parentPill = (p) => p.hidden
      ? `<span style="display:inline-block;font-size:13px;padding:1px 8px;border-radius:8px;background:#eef2f7;color:#8794a5;border:1px dashed #c3ccd8;white-space:nowrap">${this.#esc(p.label)} <span style="font-size:10px;text-transform:uppercase;letter-spacing:.03em">· hidden</span></span>`
      : `<span style="display:inline-block;font-size:13px;padding:1px 8px;border-radius:8px;background:#e7f0fb;color:#2f6fb0;white-space:nowrap">${this.#esc(p.label)}</span>`
    const isaHtml = parents.length
      ? `<div style="margin-top:4px;color:#4a5b6e"><span style="font-size:12px;font-weight:700;text-transform:uppercase;color:#8794a5">is-a</span>` +
        `<div style="margin-top:3px;display:flex;flex-wrap:wrap;gap:4px">${parents.map(parentPill).join('')}</div></div>`
      : '<div style="margin-top:4px;color:#8794a5"><i>no is-a parents</i></div>'
    const synHtml = syn.length
      ? `<div style="margin-top:6px;color:#4a5b6e"><span style="font-size:12px;font-weight:700;text-transform:uppercase;color:#8794a5">Synonym${syn.length > 1 ? 's' : ''}</span>` +
        pillRow(syn.map((x) => this.#esc(x)), '#eef2f7', '#5a6b82') + '</div>'
      : ''
    // "Example of usage" sentences. Cap the number shown so a class with many
    // examples doesn't produce a runaway tooltip; note how many more there are.
    const ex = this.#effExamples(n)
    const EX_SHOWN = 3
    // Each example is set off with a soft left rule (blockquote-style) rather than
    // quote marks, so it reads clearly as sample text and stays distinct from the
    // italic definition above.
    const exHtml = ex.length
      ? `<div style="margin-top:6px;color:#4a5b6e"><span style="font-size:12px;font-weight:700;text-transform:uppercase;color:#8794a5">Example${ex.length > 1 ? 's' : ''}</span>` +
        ex.slice(0, EX_SHOWN).map((x) => `<div style="margin-top:3px;padding-left:9px;border-left:2px solid #cbd6e4;color:#5a6b82">${this.#esc(x)}</div>`).join('') +
        (ex.length > EX_SHOWN ? `<div style="margin-top:3px;font-size:13px;color:#8794a5">+${ex.length - EX_SHOWN} more</div>` : '') +
        '</div>'
      : ''
    // Each section is gated by its Tooltip display option (all on by default).
    const o = this.opts
    tip.innerHTML = `<b style="color:#1b2a3a">${this.#esc(label)}</b>${pill}${srcTag}` +
      ((o.tipDefinition && def) ? `<div style="margin-top:5px;color:#6a7787;font-style:italic">${this.#esc(def)}</div>` : '') +
      (o.tipIsa ? isaHtml : '') +
      (o.tipSynonyms ? synHtml : '') +
      (o.tipExamples ? exHtml : '')
    tip.style.display = 'block'
    this.#positionTip(ev.clientX, ev.clientY)
  }

  // Hover popup for a relationship edge: the property name (e.g. "innervated_by")
  // plus its short id (e.g. RO_0002131) as a pill. The two nodes it connects are
  // already visible, so they're left out.
  #showEdgeTip (ev, property, propId) {
    const tip = this.#ensureTip()
    tip.style.maxWidth = '570px' // reset — the option info tooltip narrows the shared tip
    const sid = shortId(propId)
    const pill = sid ? ` <span style="display:inline-block;font-size:12px;font-weight:600;padding:1px 7px;margin-left:5px;border-radius:8px;background:#eef2f7;color:#5a6b82;vertical-align:middle">${this.#esc(sid)}</span>` : ''
    tip.innerHTML = `<span style="color:#2f6fb0;font-weight:600">${this.#esc(property)}</span>${pill}`
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

  // Direct is-a parents for the tooltip. `this.edges` is the full (unfiltered) edge
  // set, so this still sees parents that were dropped from the drawn graph (e.g. an
  // upper-ontology parent when "hide upper" is on). Those are returned too, flagged
  // `hidden`, so the popup can still report them instead of claiming there are none.
  #isaParents (id) {
    const out = []
    this.edges.forEach((e) => {
      if (e.kind !== 'is-a' || e.from !== id) return
      const rendered = this._layout.nodes.get(e.to)
      if (rendered) { out.push({ label: this.#effLabel(rendered), hidden: false }); return }
      // parent not drawn — recover its label from the full graph node data
      const gn = (this.graph.nodes || []).find((x) => x.id === e.to)
      if (gn) out.push({ label: this.#effLabel(gn), hidden: true })
    })
    return out
  }

  #effSynonyms (n) {
    const s = (this.opts.useUpperInfo && n.upper && n.upper.synonyms && n.upper.synonyms.length) ? n.upper.synonyms : (n.synonyms || [])
    return Array.isArray(s) ? s.filter(Boolean) : []
  }

  // "Example of usage" (IAO:0000112) sentences, preferring the authoritative
  // BFO/COB copy when that option is on, mirroring #effSynonyms.
  #effExamples (n) {
    const e = (this.opts.useUpperInfo && n.upper && n.upper.examples && n.upper.examples.length) ? n.upper.examples : (n.examples || [])
    return Array.isArray(e) ? e.filter(Boolean) : []
  }


  // --- zoom / pan / minimap -------------------------------------------------

  #installZoom (svg, vp, world) {
    const canvas = this.canvasTarget
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

    // floating gear/help icons (top-left)
    this.#buildChrome(canvas)

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
    setCollapsed(this.#storageGet(MM_COLLAPSED_KEY) === '1')
    mmToggle.addEventListener('pointerdown', (ev) => ev.stopPropagation())
    mmToggle.addEventListener('click', (ev) => {
      ev.stopPropagation()
      const collapsed = !mm.classList.contains('entity-graph__minimap--collapsed')
      setCollapsed(collapsed)
      this.#storageSet(MM_COLLAPSED_KEY, collapsed ? '1' : '0')
    })
    // Clicking the collapsed pill anywhere expands it (not just the button).
    mmLabel.addEventListener('pointerdown', (ev) => ev.stopPropagation())
    mmLabel.addEventListener('click', (ev) => {
      if (!mm.classList.contains('entity-graph__minimap--collapsed')) return
      ev.stopPropagation(); setCollapsed(false); this.#storageSet(MM_COLLAPSED_KEY, '0')
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
