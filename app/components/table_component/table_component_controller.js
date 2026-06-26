import {Controller} from "@hotwired/stimulus"
import DataTable from 'datatables.net-bs5';


// Connects to data-controller="table-component"
export default class extends Controller {
    static values = {
        sortcolumn: String,
        paging: Boolean,
        searching: Boolean,
        noinitsort: Boolean,
        searchPlaceholder: {type: String, default: 'Filter records'},
    }
    connect(){
        const table_component = this.element.querySelector('table')
        const default_sort_column = parseInt(this.sortcolumnValue, 10)

        if (this.sortcolumnValue || this.searchingValue || this.pagingValue){
            this.table = new DataTable('#'+table_component.id, {
                paging: this.pagingValue,
                info: false,
                searching: this.searchingValue,
                autoWidth: true,
                order: this.noinitsortValue ? [] : [[default_sort_column, 'desc']],
                language: {
                    search: '_INPUT_',
                    searchPlaceholder: this.searchPlaceholderValue
                }
            });
        }
    }
}