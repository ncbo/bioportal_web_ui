export class HistoryService {

    unWantedData = ['turbo', 'controller', 'target', 'value', 'action']


    constructor() {
        this.history = window.history
        this.state  = {data: {}}
    }

    pushState(data, title, url) {
        this.history.pushState(data, title, url)
        this.state = {data: data}
    }

    getState() {
        return this.state
    }

    updateHistory(currentUrl, newData) {
        const newUrl = this.getUpdatedURL(currentUrl, newData)
        const newState = this.#initStateFromUrl(newUrl)
        this.pushState(newState, newState.title, newUrl)
    }

    getUpdatedURL(currentUrl, newData) {
        const base = document.location.origin
        const url = new URL(currentUrl, base)

        this.#updateURLFromState(url.searchParams, this.getState().data)
        this.#addNewDataToUrl(url, newData)
        return url.pathname + url.search
    }

    #addNewDataToUrl(url, newData) {
        const wantedData = this.#filterUnwantedData(newData, this.unWantedData);

        wantedData.forEach(([updatedParam, newValue]) => {
            if (newValue === null) {
                url.searchParams.delete(updatedParam)
            } else {
                newValue = Array.isArray(newValue) ? newValue : [newValue]
                url.searchParams.set(updatedParam, newValue.join(','))
            }
        });
    }

    #filterUnwantedData(data, unWantedData) {
        return Object.entries(data).filter(([key]) => !unWantedData.some(uw => key.toLowerCase().includes(uw.toLowerCase())))
    }

    #initStateFromUrl(currentUrl) {
        const url = new URL(currentUrl, document.location.origin)
        const urlParams = url.searchParams
        let newState = this.getState().data
        urlParams.forEach((newVal, key) => {
            newState[key] = newVal
        })
        return newState
    }

    #updateURLFromState(urlParams, state) {
        Object.entries(state).forEach(([key, val]) => {
            if (key !== 'p'  && !urlParams.has(key)){
                urlParams.set(key, val)
            }
        })
    }


}