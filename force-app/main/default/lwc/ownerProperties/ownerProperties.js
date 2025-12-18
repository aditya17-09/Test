// Import required modules
import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getOwnerProperties from '@salesforce/apex/SavePropertyController.getOwnerProperties';

// Define the OwnerProperties component
export default class OwnerProperties extends NavigationMixin(LightningElement) {
    // Tracked properties for reactive state
    @track properties = []; // List of properties with ariaLabel and animation
    @track error = ''; // Error message for display
    @track lastRefresh = 0; // Timestamp to track last refresh

    // Store wired Apex result for refresh
    wiredPropertiesResult;

    // Wire Apex method to fetch properties
    @wire(getOwnerProperties)
    wiredProperties(result) {
        this.wiredPropertiesResult = result;
        const { data, error } = result;
        if (data) {
            // Map properties to include ariaLabel and animation style
            this.properties = data.map((prop, index) => {
                // Log for debugging image issues
                if (!prop.imageUrl && prop.propertyData.Photos__c) {
                    console.warn(`Image URL missing for property ${prop.propertyData.Name}, Photos__c: ${prop.propertyData.Photos__c}`);
                }
                return {
                    ...prop,
                    ariaLabel: `Image for ${prop.propertyData.Name}`,
                    animationStyle: `animation-delay: ${index * 0.2}s`
                };
            });
            this.error = '';
            this.lastRefresh = Date.now(); // Update refresh timestamp
            // Show success toast if properties exist
            if (this.properties.length > 0) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Properties loaded successfully.',
                        variant: 'success'
                    })
                );
            }
        } else if (error) {
            // Handle errors
            this.error = error.body?.message || 'Error loading properties.';
            this.properties = [];
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.error,
                    variant: 'error'
                })
            );
        }
    }

    // Lifecycle hook to initialize component
    connectedCallback() {
        // Force refresh if navigating back (e.g., from Property_Entry_Page)
        if (sessionStorage.getItem('fromPropertyEntry') === 'true') {
            this.refreshProperties();
            sessionStorage.removeItem('fromPropertyEntry'); // Clear flag
        }
    }

    // Lifecycle hook to refresh data periodically
    renderedCallback() {
        // Refresh if more than 5 seconds since last refresh
        if (Date.now() - this.lastRefresh > 5000 && this.wiredPropertiesResult) {
            this.refreshProperties();
        }
    }

    // Method to force refresh properties
    refreshProperties() {
        if (this.wiredPropertiesResult) {
            refreshApex(this.wiredPropertiesResult).catch((error) => {
                this.error = error.body?.message || 'Error refreshing properties.';
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: this.error,
                        variant: 'error'
                    })
                );
            });
        }
    }

    // Navigate back to Owner Portal Home
    navigateToHome() {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'home' // Navigate to standard Home page
            }
        });
    }
}