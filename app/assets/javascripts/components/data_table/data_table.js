class DataTable extends HTMLElement{


    get config() {
        return this.getAttribute("config") || {}
    }

    set config(v) {
        this.setAttribute("config" ,v)
    }
    constructor(){
        super()
        this.tableElem = document.createElement("table")
        this.tableElem.style.width = "100%"

        this.container = document.createElement("div")
        this.container.appendChild(this.tableElem)

        this.dataTable = null
    }

    connectedCallback(){
        this.initDataTable()
        this.dispatchTableUpdateEvent()
        this.dispatchClickedRow()
    }

    initDataTable(){
        if ( $.fn.dataTable.isDataTable( this.tableElem ) ) {
            $(this.tableElem).DataTable().destroy();
        }
        this.dataTable = $(this.tableElem).DataTable(this.config)
        this.appendChild(this.container)
    }
    dispatchTableUpdateEvent(){
        this.dataTable.on("xhr" ,  () => {
            this.dispatchEvent(new CustomEvent("update" , {
                detail :{data:this.dataTable.ajax.json()}
            }))
        })
    }

    dispatchClickedRow(){
        this.dataTable.on('click', 'tbody tr', (e) => {
            const row = e.currentTarget
            const rowIndex = row.rowIndex
            const data = this.dataTable.row(row).data()
            this.dispatchEvent(new CustomEvent("row-click" ,{
              detail: {row, data, rowIndex}
            }))
        })
    }


}