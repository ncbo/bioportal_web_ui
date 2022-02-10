class DataTableLoader extends HTMLElement {

    constructor() {
        super()
    }

    connectedCallback() {
        this.innerHTML = `           
                                <div class="spinner-border m-2" role="status"> 
                                    <span class="sr-only">Loading...</span>
                                </div>           
                `
    }
}