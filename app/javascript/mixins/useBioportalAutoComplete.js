export function useBioportalAutoComplete(element, endpointUrl, extraParams, onFindValue, onItemSelect, formatItem) {
    jQuery(element).bioportal_autocomplete(endpointUrl, {
        extraParams: extraParams,
        selectFirst: true,
        lineSeparator: "~!~",
        matchSubset: 0,
        minChars: 1,
        maxItemsToShow: 25,
        onFindValue: onFindValue,
        onItemSelect: onItemSelect,
        formatItem: formatItem
    })
}