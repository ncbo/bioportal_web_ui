export function useSimpleTree(element, afterClick, afterAjaxError, beforeAjax) {
    if (!jQuery(element).data('simpleTree')) {
        return jQuery(element).simpleTree({
            autoclose: false,
            drag: false,
            animate: true,
            timeout: 20000,
            afterClick: afterClick,
            afterAjaxError: afterAjaxError,
            beforeAjax: beforeAjax
        });
    }
}
