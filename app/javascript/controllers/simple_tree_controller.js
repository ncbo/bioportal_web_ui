import { Controller } from '@hotwired/stimulus'

const TREE_VIEW_PAGES = ['classes', 'properties', 'schemes', 'collections', 'instances']

// Connects to data-controller="simple-tree"
export default class extends Controller {

  static values = {
    autoClick: { type: Boolean, default: false }
  }

  connect () {
    this.#centerTreeView()
    this.#bindExpandFeedback()
  }

  disconnect () {
    if (this.boundExpandClick) {
      this.element.removeEventListener('click', this.boundExpandClick, true)
    }
    this.expandObserver?.disconnect()
  }

  // Give immediate feedback when a collapsed node is expanded. Expanding is a
  // server round-trip that can take a second or more, and the chevron only
  // flips once the response arrives. On click of a chevron's expand link we
  // optimistically mark the <li> `.tree-expanding` (CSS rotates + pulses the
  // chevron and shows a compact inline loader), and clear it once that node's
  // children actually land in the DOM.
  //
  // The children arrive via a Turbo Stream (see ConceptsController#index), which
  // does NOT emit turbo:frame-load on the target frame — so we can't key the
  // "done" signal off a frame event. Instead a MutationObserver watches for the
  // children list being inserted under any expanding node, which is robust to
  // however the markup gets there. Re-collapse/expand of already-loaded subtrees
  // uses the instant #toggleChildren path and never gets the class.
  #bindExpandFeedback () {
    this.boundExpandClick = (event) => {
      const link = event.target.closest('[id$="_open_link"] a')
      if (!link) return
      const li = link.closest('li')
      if (!li) return
      li.classList.add('tree-expanding')
      // Safety net: if children never arrive (leaf-like node, request error, or a
      // click that doesn't trigger a load), clear the state after a few seconds so
      // the chevron can't pulse forever. Success clears it sooner via the observer.
      clearTimeout(this.expandTimers?.get(li))
      const timer = setTimeout(() => li.classList.remove('tree-expanding'), 8000)
      ;(this.expandTimers ??= new WeakMap()).set(li, timer)
    }
    this.element.addEventListener('click', this.boundExpandClick, true)

    // Children arrive via a Turbo Stream (ConceptsController#index), which does
    // not emit turbo:frame-load on the target frame — so watch the DOM for the
    // children being inserted instead. Robust to however the markup lands.
    this.expandObserver = new MutationObserver(() => {
      this.element.querySelectorAll('li.tree-expanding').forEach((li) => {
        // Children have arrived once a nested children list exists under this node.
        // Match on the children <ul> (id-independent) rather than a specific frame
        // id, since Turbo swaps the frame markup on expand.
        if (li.querySelector('ul.tree-border-left, [id$="_childs"] ul, [id$="_childs"] li')) {
          this.#stopExpanding(li)
        }
      })
    })
    this.expandObserver.observe(this.element, { childList: true, subtree: true })
  }

  #stopExpanding (li) {
    li.classList.remove('tree-expanding')
    const timer = this.expandTimers?.get(li)
    if (timer) { clearTimeout(timer); this.expandTimers.delete(li) }
  }

  select (event) {
    this.element.querySelector('a.active')?.classList.toggle('active')
    event.currentTarget.classList.toggle('active')
    this.#afterClick(event.currentTarget)
  }

  toggleChildren (event) {
    event.preventDefault()
    // currentTarget is the SVG the action is bound to; target can be its inner <path>
    event.currentTarget.classList.toggle('open')
    event.currentTarget.nextElementSibling.nextElementSibling.classList.toggle('hidden')
  }

  #centerTreeView() {
    setTimeout(() => {
      const location = window.location.href;

      const isTreeViewPage = TREE_VIEW_PAGES.some(param => location.includes(`p=${param}`));

      if (isTreeViewPage) {
        const activeElem = this.element.querySelector('.tree-link.active');

        if (activeElem) {
          this.#centerWithinScrollParent(activeElem);

          if (this.autoClickValue) {
            activeElem.click();
          }
        }

        this.#onClickTooManyChildrenInit();
      }
    }, 0);
  }

  // Center the active node inside the tree's own scroll container only.
  // Using element.scrollIntoView() here would also scroll the window (it walks
  // every scrollable ancestor), producing a visible page "jump" on load that a
  // follow-up window.scrollTo(0) then snapped back. Scrolling the container
  // directly avoids touching the page scroll entirely.
  #centerWithinScrollParent (activeElem) {
    const scroller = activeElem.closest('#sd_content') || this.#nearestScrollParent(activeElem);
    if (!scroller) return;

    // Node's top relative to the scroller's content box, independent of how many
    // wrapper elements sit between them (offsetParent can be either).
    const elemRect = activeElem.getBoundingClientRect();
    const scrollerRect = scroller.getBoundingClientRect();
    const offsetWithinScroller = (elemRect.top - scrollerRect.top) + scroller.scrollTop;

    const target = offsetWithinScroller
      - (scroller.clientHeight / 2)
      + (elemRect.height / 2);
    scroller.scrollTop = Math.max(0, target);
  }

  #nearestScrollParent (el) {
    let node = el.parentElement;
    while (node) {
      const overflowY = getComputedStyle(node).overflowY;
      if ((overflowY === 'auto' || overflowY === 'scroll') && node.scrollHeight > node.clientHeight) {
        return node;
      }
      node = node.parentElement;
    }
    return null;
  }

  #onClickTooManyChildrenInit () {
    jQuery('.too_many_children_override').live('click', (event) => {
      event.preventDefault()
      let result = jQuery(event.target).closest('ul')
      result.html('<img src=\'/images/tree/spinner.gif\'>')
      jQuery.ajax({
        url: jQuery(event.target).attr('href'),
        context: result,
        success: function (data) {
          this.html(data)
          this.simpleTreeCollection.get(0).setTreeNodes(this)
        },
        error: function () {
          this.html('<div style=\'background: #eeeeee; padding: 5px; width: 80%;\'>Problem getting children. <a href=\'' + jQuery(this).attr('href') + '\' class=\'too_many_children_override\'>Try again</a></div>')
        }
      })
    })
  }

  #afterClick (node) {
    this.element.dispatchEvent(new CustomEvent('clicked', {
      detail: {
        node: node,
        data: { ...node.dataset }
      }, bubbles: true
    }))
  }
}
