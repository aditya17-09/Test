import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

import searchProperties from '@salesforce/apex/PropertySearchController.searchProperties';
import submitInterest from '@salesforce/apex/PropertySearchController.submitInterest';
import getOwnerDetails from '@salesforce/apex/PropertySearchController.getOwnerDetails';

import PLACEHOLDER_IMAGE from '@salesforce/resourceUrl/placeholder';

export default class PMlandingPage extends NavigationMixin(LightningElement) {

    /* =========================
       STATE
    ========================= */
    @track activeTab = 'Buy';
    @track propertyType = '';
    @track location = '';
    @track searchedCity = 'Your City';

    @track properties = [];
    @track displayedProperties = [];
    @track displayCount = 3;

    @track showMoreVisible = false;
    @track noMorePropertiesError = false;

    @track showInterestModal = false;
    @track showOwnerModal = false;

    @track interestName = '';
    @track interestEmail = '';
    @track interestPhone = '';
    @track interestBudget = '';
    @track interestReason = '';

    @track ownerDetails = null;
    @track error = '';
    @track recentSearches = [];
    @track selectedPropertyId = '';
    @track noResultsMessage = '';

    placeholderImage = PLACEHOLDER_IMAGE;

    /* =========================
       OPTIONS
    ========================= */
    propertyTypeOptions = [
        { label: 'Apartment', value: 'Apartment' },
        { label: 'House', value: 'House' },
        { label: 'Condo', value: 'Condo' }
    ];

    /* =========================
       COMPUTED
    ========================= */
    get formattedProperties() {
        return this.properties.map((property) => {
            var data = property.propertyData || {};
            var sqft = data.Square_Footage__c || 0;
            var bedrooms = data.Bedrooms__c || 'N/A';

            if (!bedrooms && sqft) {
                if (sqft <= 1000) bedrooms = '1 BHK';
                else if (sqft <= 1500) bedrooms = '2 BHK';
                else if (sqft <= 2000) bedrooms = '3 BHK';
                else bedrooms = '4+ BHK';
            }

            return {
                propertyData: {
                    Id: data.Id || '',
                    Name: data.Name || 'Unknown Property',
                    Address__c: data.Address__c || 'No Address',
                    Price__c: data.Price__c || 0,
                    Property_Type__c: data.Property_Type__c || 'Unknown'
                },
                ImageUrl: property.ImageUrl || this.placeholderImage,
                Bedrooms: bedrooms
            };
        });
    }

    /* =========================
       EVENTS
    ========================= */
    handlePropertyTypeChange(event) {
        this.propertyType = event.detail.value;
    }

    handleLocationChange(event) {
        this.location = event.detail.value;
    }

    handleRecentSearch(event) {
        this.location = event.target.textContent;
        this.handleSearch();
    }

    async handleSearch() {
        try {
            var locationInput = this.template.querySelector('lightning-input[data-id="location"]');

            if (!this.location || this.location.trim() === '') {
                locationInput.setCustomValidity('Location is required');
                locationInput.reportValidity();
                return;
            }

            locationInput.setCustomValidity('');
            locationInput.reportValidity();

            this.error = '';
            this.noResultsMessage = '';
            this.displayCount = 3;

            var result = await searchProperties({
                searchType: this.activeTab,
                propertyType: this.propertyType,
                location: this.location
            });

            this.properties = Array.isArray(result) ? result : [];
            this.searchedCity = this.location;

            this.displayedProperties = this.formattedProperties.slice(0, this.displayCount);
            this.showMoreVisible = this.properties.length > this.displayCount;

            if (this.properties.length === 0) {
                this.noResultsMessage =
                    'No properties found in ' + this.searchedCity;
            } else {
                this.recentSearches = [this.location]
                    .concat(this.recentSearches)
                    .filter((v, i, a) => a.indexOf(v) === i)
                    .slice(0, 3);
            }

            var content = this.template.querySelector('.content');
            if (content) {
                content.scrollIntoView({ behavior: 'smooth' });
            }

        } catch (err) {
            this.error = 'Search failed';
            this.properties = [];
            this.displayedProperties = [];
        }
    }

    handleShowMore() {
        this.displayCount += 3;
        this.displayedProperties =
            this.formattedProperties.slice(0, this.displayCount);

        this.showMoreVisible =
            this.properties.length > this.displayCount;

        if (!this.showMoreVisible) {
            this.noMorePropertiesError = true;
        }
    }

    /* =========================
       IMAGE FALLBACK
    ========================= */
    handleImageError(event) {
        event.target.src = this.placeholderImage;
    }

    /* =========================
       INTEREST
    ========================= */
    handleExpressInterest(event) {
        event.stopPropagation();
        this.selectedPropertyId = event.target.dataset.id;
        this.showInterestModal = true;
    }

    closeInterestModal() {
        this.showInterestModal = false;
        this.interestName = '';
        this.interestEmail = '';
        this.interestPhone = '';
        this.interestBudget = '';
        this.interestReason = '';
    }

    handleInterestNameChange(e) { this.interestName = e.detail.value; }
    handleInterestEmailChange(e) { this.interestEmail = e.detail.value; }
    handleInterestPhoneChange(e) { this.interestPhone = e.detail.value; }
    handleInterestBudgetChange(e) { this.interestBudget = e.detail.value; }
    handleInterestReasonChange(e) { this.interestReason = e.detail.value; }

    async submitInterest() {
        try {
            await submitInterest({
                propertyId: this.selectedPropertyId,
                name: this.interestName,
                email: this.interestEmail,
                phone: this.interestPhone,
                budget: parseFloat(this.interestBudget),
                reason: this.interestReason
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Interest submitted successfully',
                    variant: 'success'
                })
            );

            this.closeInterestModal();
        } catch (e) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to submit interest',
                    variant: 'error'
                })
            );
        }
    }

    /* =========================
       OWNER
    ========================= */
    async handleContactOwner(event) {
        event.stopPropagation();
        try {
            this.ownerDetails =
                await getOwnerDetails({ propertyId: event.target.dataset.id });
            this.showOwnerModal = true;
        } catch (e) {
            this.ownerDetails = null;
        }
    }

    closeOwnerModal() {
        this.showOwnerModal = false;
        this.ownerDetails = null;
    }

    /* =========================
       NAVIGATION
    ========================= */
    navigateToPropertyDetail(event) {
        if (event.target.tagName === 'LIGHTNING-BUTTON') {
            return;
        }

        var propertyId = event.currentTarget.dataset.id;

        if (!propertyId) return;

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/propertydetail?c__propertyId=' + propertyId
            }
        });
    }

    /* =========================
       LIFECYCLE
    ========================= */
    connectedCallback() {
        this.properties = [];
        this.displayedProperties = [];
    }
}
