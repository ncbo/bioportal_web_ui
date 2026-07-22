import { Controller } from '@hotwired/stimulus'

const TREE_VIEW_PAGES = ['classes', 'properties', 'schemes', 'collections', 'instances']

// Connects to data-controller="simple-tree"
export default class extends Controller {

  static values = {
    autoClick: { type: Boolean, default: false }
  }

  connect () {
    this.#centerTreeView()
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
