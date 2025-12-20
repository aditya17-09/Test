import { LightningElement, track } from 'lwc';
import searchProperties from '@salesforce/apex/PropertySearchController.searchProperties';
import PLACEHOLDER_IMAGE from '@salesforce/resourceUrl/placeholder';

export default class PMlandingPage extends LightningElement {

    @track propertyType = '';
    @track location = '';
    @track properties = [];
    @track displayedProperties = [];
    @track favorites = [];
    @track compareList = [];
    @track isLoading = false;
    @track noResultsMessage = '';

    skeletons = [1,2,3,4,5,6];
    placeholderImage = PLACEHOLDER_IMAGE;
    isDark = false;

    propertyTypeOptions = [
        { label: 'Apartment', value: 'Apartment' },
        { label: 'House', value: 'House' },
        { label: 'Condo', value: 'Condo' }
    ];

    connectedCallback() {
        this.favorites = JSON.parse(localStorage.getItem('favorites')) || [];
        this.isDark = localStorage.getItem('theme') === 'dark';
        this.template.host.dataset.theme = this.isDark ? 'dark' : 'light';
    }

    get themeIcon() {
        return this.isDark ? '☀️' : '🌙';
    }

    handlePropertyTypeChange(e) {
        this.propertyType = e.detail.value;
    }

    handleLocationChange(e) {
        this.location = e.detail.value;
    }

    async handleSearch() {
        this.isLoading = true;
        this.noResultsMessage = '';

        const result = await searchProperties({
            propertyType: this.propertyType,
            location: this.location
        });

        this.properties = result || [];
        this.displayedProperties = this.properties.slice(0,6);
        this.isLoading = false;

        if (!this.properties.length) {
            this.noResultsMessage = 'Try nearby locations or adjust filters.';
        }

        this.track('SEARCH', { location: this.location });
    }

    toggleFavorite(e) {
        e.stopPropagation();
        const id = e.target.dataset.id;

        if (this.favorites.includes(id)) {
            this.favorites = this.favorites.filter(f => f !== id);
        } else {
            this.favorites = [...this.favorites, id];
        }
        localStorage.setItem('favorites', JSON.stringify(this.favorites));
        this.track('FAVORITE_TOGGLE', { id });
    }

    toggleCompare(e) {
        const id = e.target.dataset.id;
        if (this.compareList.includes(id)) {
            this.compareList = this.compareList.filter(c => c !== id);
        } else if (this.compareList.length < 3) {
            this.compareList = [...this.compareList, id];
        }
    }

    toggleTheme() {
        this.isDark = !this.isDark;
        this.template.host.dataset.theme = this.isDark ? 'dark' : 'light';
        localStorage.setItem('theme', this.isDark ? 'dark' : 'light');
    }

    handleImageError(e) {
        e.target.src = this.placeholderImage;
    }

    navigateToPropertyDetail(e) {
        if (e.target.tagName === 'LIGHTNING-BUTTON') return;
        this.track('PROPERTY_CLICK', { id: e.currentTarget.dataset.id });
    }

    track(name, payload) {
        console.log('[ANALYTICS]', name, payload);
    }
}
