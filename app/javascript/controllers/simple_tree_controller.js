import {Controller} from "@hotwired/stimulus"
import {useSimpleTree} from "../mixins/useSimpleTree";

const TREE_VIEW_PAGES = ['classes', 'properties', 'schemes', 'collections', 'instances']

export default class extends Controller {



    static values = {
        autoClick: { type: Boolean, default: false }
    }

    connect() {
        if (this.element.getAttribute('simple-tree-data-initial') == 0) {
            return;
        }
        this.simpleTreeCollection = useSimpleTree(this.element,
            this.#afterClick.bind(this),
            this.#afterAjaxError.bind(this),
            this.#beforeAjax.bind(this)
        );

        this.#onClickTooManyChildrenInit();
        this.element.setAttribute('simple-tree-data-initial', 0);
        this.#centerTreeView()
    }

    #centerTreeView() {
        setTimeout(() => {
            const location = window.location.href;

            const isTreeViewPage = TREE_VIEW_PAGES.some(param => location.includes(`p=${param}`));

            if (isTreeViewPage) {
                const activeElem = this.element.querySelector('.tree-link.active');

                if (activeElem) {
                    activeElem.scrollIntoView({block: 'center'});
                    window.scrollTo({top: 0});

                    if (this.autoClickValue) {
                        activeElem.click();
                    }
                }

                this.#onClickTooManyChildrenInit();
            }
        }, 0);
    }

    #onClickTooManyChildrenInit() {
        jQuery(".too_many_children_override").live('click', (event) => {
            event.preventDefault();
            let result = jQuery(event.target).closest("ul");
            result.html("<img src='/images/tree/spinner.gif'>");
            jQuery.ajax({
                url: jQuery(event.target).attr('href'),
                context: result,
                success: function (data) {
                    this.html(data);
                    this.simpleTreeCollection.get(0).setTreeNodes(this);
                },
                error: function () {
                    this.html("<div style='background: #eeeeee; padding: 5px; width: 80%;'>Problem getting children. <a href='" + jQuery(this).attr('href') + "' class='too_many_children_override'>Try again</a></div>");
                }
            });
        });
    }

    #afterClick(node) {
        const page_name = $(node.context).attr("data-bp-ont-page-name")
        const conf = jQuery(document).data().bp.ont_viewer
        const concept_id = jQuery(node).children("a").attr("id")
        History.pushState({
                p: "classes",
                conceptid: concept_id
            }, page_name + " | " + conf.org_site,
            '?p=classes&conceptid=' + concept_id)
    }

    #afterAjaxError(node) {
        this.simpleTreeCollection[0].option.animate = false;
        this.simpleTreeCollection.get(0).nodeToggle(node.parent()[0]);
        if (node.parent().children(".expansion_error").length === 0) {
            node.parent().append("<span class='expansion_error'>Error, please try again");
        }
        this.simpleTreeCollection[0].option.animate = true;
    }

    #beforeAjax(node) {
        node.parent().children(".expansion_error").remove();
    }
}
