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
          activeElem.scrollIntoView({ block: 'center' });
          window.scrollTo({ top: 0 });
          
          if (this.autoClickValue) {
            activeElem.click();
          }
        }
        
        this.#onClickTooManyChildrenInit();
      }
    }, 0);
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
