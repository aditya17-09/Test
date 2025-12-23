import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import searchProperties from '@salesforce/apex/PropertySearchController.searchProperties';
import submitInterest from '@salesforce/apex/PropertySearchController.submitInterest';
import getOwnerDetails from '@salesforce/apex/PropertySearchController.getOwnerDetails';
import PLACEHOLDER_IMAGE from '@salesforce/resourceUrl/placeholder';

export default class PMLandingPage extends NavigationMixin(LightningElement) {
    @track activeTab = 'Buy';
    @track propertyType = '';
    @track location = '';
    @track searchedCity = 'Your City';
    @track showFilterModal = false;
    @track selectedPropertyTypes = [];
    @track budgetMin = 50000;
    @track budgetMax = 500000;
    @track selectedBedrooms = [];
    @track properties = [];
    @track displayedProperties = [];
    @track displayCount = 3;
    @track showMoreVisible = false;
    @track noMorePropertiesError = false;
    @track showInterestModal = false;
    @track interestName = '';
    @track interestEmail = '';
    @track interestPhone = '';
    @track interestBudget = '';
    @track interestReason = '';
    @track showOwnerModal = false;
    @track ownerDetails = null;
    @track error = '';
    @track recentSearches = [];
    @track selectedPropertyId = '';
    @track noResultsMessage = '';

    budgetMinValue = 50000;
    budgetMaxValue = 500000;
    budgetStepValue = 10000;

    placeholderImage = PLACEHOLDER_IMAGE;

    propertyTypeOptions = [
        { label: 'Apartment', value: 'Apartment' },
        { label: 'House', value: 'House' },
        { label: 'Condo', value: 'Condo' }
    ];

    bedroomOptions = [
        { label: '1 BHK', value: '1 BHK' },
        { label: '2 BHK', value: '2 BHK' },
        { label: '3 BHK', value: '3 BHK' },
        { label: '4+ BHK', value: '4+ BHK' }
    ];

    get buyTabClass() {
        return `slds-tabs_default__item ${this.activeTab === 'Buy' ? 'slds-is-active' : ''}`;
    }

    get rentTabClass() {
        return `slds-tabs_default__item ${this.activeTab === 'Rent' ? 'slds-is-active' : ''}`;
    }

    get commercialTabClass() {
        return `slds-tabs_default__item ${this.activeTab === 'Commercial' ? 'slds-is-active' : ''}`;
    }

    get budgetMinDisplay() {
        return this.formatCurrency(this.budgetMin);
    }

    get budgetMaxDisplay() {
        return this.budgetMax >= this.budgetMaxValue ? '5 Lac+' : this.formatCurrency(this.budgetMax);
    }

    formatCurrency(value) {
        return value >= 100000 ? `${(value / 100000).toFixed(1)} Lac` : `₹${value.toLocaleString('en-IN')}`;
    }

    get getFormattedProperties() {
        return this.properties.map(property => {
            const propertyData = property?.propertyData || {};
            const sqft = propertyData.Square_Footage__c || 0;
            let bedrooms = propertyData.Bedrooms__c || 'N/A';
            if (!bedrooms && sqft) {
                if (sqft >= 500 && sqft <= 1000) bedrooms = '1 BHK';
                else if (sqft <= 1500) bedrooms = '2 BHK';
                else if (sqft <= 2000) bedrooms = '3 BHK';
                else if (sqft > 2000) bedrooms = '4+ BHK';
            }
            return {
                propertyData: {
                    Id: propertyData.Id || '',
                    Name: propertyData.Name || 'Unknown Property',
                    Address__c: propertyData.Address__c || 'No Address',
                    Price__c: propertyData.Price__c || 0,
                    Property_Type__c: propertyData.Property_Type__c || 'Unknown',
                    Square_Footage__c: sqft,
                    Bedrooms__c: bedrooms,
                    Amenities__c: propertyData.Amenities__c || 'None',
                    Property_Stage__c: propertyData.Property_Stage__c || 'N/A',
                    Lease_Terms__c: propertyData.Lease_Terms__c || 'N/A',
                    Status__c: propertyData.Status__c || 'N/A'
                },
                ImageUrl: property.ImageUrl || this.placeholderImage,
                Bedrooms: bedrooms
            };
        });
    }

    handleImageError(event) {
        const propertyId = event.target.dataset.id;
        console.error(`Image failed to load for property ${propertyId}`);
        event.target.src = this.placeholderImage;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Image Load Error',
                message: `Failed to load image for property ${propertyId}.`,
                variant: 'warning'
            })
        );
    }

    handleTabChange(event) {
        this.activeTab = event.target.dataset.tab;
    }

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
            const locationInput = this.template.querySelector('lightning-input[data-id="location"]');
            if (!this.location || this.location.trim() === '') {
                locationInput.setCustomValidity('Search Locality is required.');
                locationInput.reportValidity();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Please enter a city or locality.',
                        variant: 'error'
                    })
                );
                return;
            }
            locationInput.setCustomValidity('');
            locationInput.reportValidity();

            this.error = '';
            this.noMorePropertiesError = false;
            this.noResultsMessage = '';
            this.displayCount = 3;

            console.log('Search parameters:', {
                searchType: this.activeTab,
                propertyType: this.propertyType,
                location: this.location,
                selectedPropertyTypes: this.selectedPropertyTypes,
                budgetMin: this.budgetMin,
                budgetMax: this.budgetMax,
                bedrooms: this.selectedBedrooms
            });

            const properties = await searchProperties({
                searchType: this.activeTab,
                propertyType: this.propertyType,
                location: this.location,
                selectedPropertyTypes: this.selectedPropertyTypes,
                budgetMin: this.budgetMin,
                budgetMax: this.budgetMax,
                bedrooms: this.selectedBedrooms
            });

            this.properties = Array.isArray(properties) ? properties : [];
            console.log('Properties received:', this.properties.length);

            this.searchedCity = this.location || 'Your City';
            this.displayedProperties = this.getFormattedProperties.slice(0, this.displayCount);
            this.showMoreVisible = this.properties.length > this.displayCount;

            if (this.properties.length === 0) {
                this.noResultsMessage = `No properties found in ${this.searchedCity}. Try a different locality or adjust filters.`;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'No Results',
                        message: this.noResultsMessage,
                        variant: 'info'
                    })
                );
            } else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: `Found ${this.properties.length} properties in ${this.searchedCity}.`,
                        variant: 'success'
                    })
                );
            }

            if (this.location) {
                this.recentSearches = [...new Set([this.location, ...this.recentSearches])].slice(0, 3);
            }

            this.template.querySelector('.property-list')?.scrollIntoView({ behavior: 'smooth' });
        } catch (error) {
            console.error('Search error:', error);
            this.error = error.body?.message || 'An error occurred during search.';
            this.properties = [];
            this.displayedProperties = [];
            this.showMoreVisible = false;
            this.noMorePropertiesError = false;
            this.noResultsMessage = this.error;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.error,
                    variant: 'error'
                })
            );
        }
    }

    handleShowMore() {
        this.noMorePropertiesError = false;
        this.displayCount += 3;
        this.displayedProperties = this.getFormattedProperties.slice(0, this.displayCount);
        this.showMoreVisible = this.properties.length > this.displayCount;

        if (!this.showMoreVisible && this.displayedProperties.length === this.properties.length) {
            this.noMorePropertiesError = true;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'No More Properties',
                    message: 'All properties displayed.',
                    variant: 'info'
                })
            );
        }
    }

    forceRender() {
        return new Promise(resolve => setTimeout(resolve, 0));
    }

    async handleExpressInterest(event) {
        try {
            this.error = '';
            const propertyId = event.target.dataset.id;
            console.log('Attempting to open Express Interest modal for propertyId:', propertyId);
            if (!propertyId) {
                throw new Error('Property ID is missing.');
            }
            this.selectedPropertyId = propertyId;
            await this.forceRender(); // Ensure DOM is ready
            this.showInterestModal = true;
            console.log('Express Interest modal should now be open');
        } catch (error) {
            console.error('Express Interest error:', error);
            this.error = 'Failed to open interest form.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.error,
                    variant: 'error'
                })
            );
        }
    }

    handleInterestNameChange(event) {
        this.interestName = event.detail.value;
    }

    handleInterestEmailChange(event) {
        this.interestEmail = event.detail.value;
    }

    handleInterestPhoneChange(event) {
        this.interestPhone = event.detail.value;
    }

    handleInterestBudgetChange(event) {
        this.interestBudget = event.detail.value;
    }

    handleInterestReasonChange(event) {
        this.interestReason = event.detail.value;
    }

    closeInterestModal() {
        this.showInterestModal = false;
        this.interestName = '';
        this.interestEmail = '';
        this.interestPhone = '';
        this.interestBudget = '';
        this.interestReason = '';
        this.selectedPropertyId = '';
    }

    async submitInterest() {
        try {
            const inputs = this.template.querySelectorAll('lightning-input, lightning-textarea');
            let allValid = true;
            inputs.forEach(input => {
                input.reportValidity();
                if (!input.checkValidity()) allValid = false;
            });

            if (!allValid) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Please complete all required fields.',
                        variant: 'error'
                    })
                );
                return;
            }

            console.log('Submitting interest:', {
                propertyId: this.selectedPropertyId,
                name: this.interestName,
                email: this.interestEmail,
                phone: this.interestPhone,
                budget: this.interestBudget,
                reason: this.interestReason
            });

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
                    message: 'Interest submitted successfully!',
                    variant: 'success'
                })
            );
            this.closeInterestModal();
        } catch (error) {
            console.error('Submit interest error:', error);
            this.error = error.body?.message || 'Failed to submit interest.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.error,
                    variant: 'error'
                })
            );
        }
    }

    async handleContactOwner(event) {
        try {
            this.error = '';
            const propertyId = event.target.dataset.id;
            console.log('Attempting to open Contact Owner modal for propertyId:', propertyId);
            if (!propertyId) {
                throw new Error('Property ID is missing.');
            }
            this.ownerDetails = await getOwnerDetails({ propertyId });
            console.log('Owner details:', this.ownerDetails);
            await this.forceRender(); // Ensure DOM is ready
            this.showOwnerModal = true;
            console.log('Contact Owner modal should now be open');
        } catch (error) {
            console.error('Contact owner error:', error);
            this.error = error.body?.message || 'Failed to fetch owner details.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.error,
                    variant: 'error'
                })
            );
        }
    }

    closeOwnerModal() {
        this.showOwnerModal = false;
        this.ownerDetails = null;
    }

    toggleFilterModal() {
        this.showFilterModal = !this.showFilterModal;
    }

    closeFilterModal() {
        this.showFilterModal = false;
    }

    handlePropertyTypeFilterChange(event) {
        this.selectedPropertyTypes = event.detail.value;
    }

    handleBudgetMinChange(event) {
        let minValue = parseInt(event.target.value, 10);
        if (minValue > this.budgetMax) minValue = this.budgetMax - this.budgetStepValue;
        this.budgetMin = minValue;
        this.updateSliderRange();
    }

    handleBudgetMaxChange(event) {
        let maxValue = parseInt(event.target.value, 10);
        if (maxValue < this.budgetMin) maxValue = this.budgetMin + this.budgetStepValue;
        this.budgetMax = maxValue;
        this.updateSliderRange();
    }

    updateSliderRange() {
        const sliders = this.template.querySelectorAll('.min-slider, .max-slider, .slider-range');
        if (sliders.length === 3) {
            const [minSlider, maxSlider, range] = sliders;
            const minPercent = ((this.budgetMin - this.budgetMinValue) / (this.budgetMaxValue - this.budgetMinValue)) * 100;
            const maxPercent = ((this.budgetMax - this.budgetMinValue) / (this.budgetMaxValue - this.budgetMinValue)) * 100;
            range.style.left = `${minPercent}%`;
            range.style.width = `${maxPercent - minPercent}%`;
        }
    }

    handleBedroomChange(event) {
        this.selectedBedrooms = event.detail.value;
    }

    resetFilters() {
        this.selectedPropertyTypes = [];
        this.budgetMin = this.budgetMinValue;
        this.budgetMax = this.budgetMaxValue;
        this.selectedBedrooms = [];
        this.updateSliderRange();
    }

    applyFilters() {
        this.showFilterModal = false;
        this.handleSearch();
    }

    navigateToPropertyDetail(event) {
        const propertyId = event.target.dataset.id;
        if (propertyId && propertyId.match(/^[a-zA-Z0-9]{15,18}$/)) {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: `/propertydetail?c__propertyId=${propertyId}`
                }
            });
        } else {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Invalid property ID.',
                    variant: 'error'
                })
            );
        }
    }

    connectedCallback() {
        this.updateSliderRange();
        this.properties = [];
        this.displayedProperties = [];
    }
}