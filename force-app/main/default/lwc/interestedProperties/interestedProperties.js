import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInterestedProperties from '@salesforce/apex/InterestedPropertiesController.getInterestedProperties';
import PLACEHOLDER_IMAGE from '@salesforce/resourceUrl/placeholder';

export default class InterestedProperties extends LightningElement {
    @track properties = [];
    @track error = '';
    @track isLoading = false;
    placeholderImage = PLACEHOLDER_IMAGE;

    connectedCallback() {
        this.loadInterestedProperties();
    }

    async loadInterestedProperties() {
        this.isLoading = true;
        this.error = '';
        try {
            const properties = await getInterestedProperties();
            this.properties = properties || [];
            if (this.properties.length === 0) {
                this.error = 'No properties found with expressed interest.';
                this.showToast('Info', this.error, 'info');
            }
        } catch (error) {
            this.error = error.body?.message || 'Failed to load interested properties.';
            this.showToast('Error', this.error, 'error');
            this.properties = [];
        } finally {
            this.isLoading = false;
        }
    }

    handleImageError(event) {
        event.target.src = this.placeholderImage;
    }

    handleImageClick(event) {
        const propertyId = event.currentTarget.dataset.id;
        console.log('Image clicked for Property ID: ' + propertyId);
        // Future functionality to be added here
    }

    getOwnerDetails(ownerData) {
        return {
            name: ownerData?.Name__c || 'N/A',
            phone: ownerData?.Phone__c || 'N/A',
            email: ownerData?.Email__c || 'N/A',
            address: ownerData?.Address__c || 'N/A'
        };
    }

    showToast(title, message, variant) {
        const toastEvent = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(toastEvent);
    }
}