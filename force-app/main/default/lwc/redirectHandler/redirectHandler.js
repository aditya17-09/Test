import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getLastVisitedPage from '@salesforce/apex/PagePersistenceController.getLastVisitedPage';

export default class RedirectHandler extends NavigationMixin(LightningElement) {
    connectedCallback() {
        // Check localStorage first
        const lastPage = localStorage.getItem('lastVisitedPage') || null;
        if (lastPage) {
            this.redirectToPage(lastPage);
            return;
        }

        // Fallback to Apex if localStorage is empty
        getLastVisitedPage()
            .then(pageDetails => {
                if (pageDetails) {
                    this.redirectToPage(pageDetails);
                } else {
                    // Default to pmLandingPage if no last page
                    this.redirectToDefaultPage();
                }
            })
            .catch(error => {
                console.error('Error fetching last visited page:', error);
                this.redirectToDefaultPage();
            });
    }

    redirectToPage(pageDetails) {
        try {
            // Parse pageDetails (e.g., 'c__PropertyDetail?c__propertyId=001xyz')
            const [componentName, queryString] = pageDetails.split('?');
            if (!['c__PMLandingPage', 'c__PropertyDetail'].includes(componentName)) {
                throw new Error('Invalid component name');
            }
            const params = new URLSearchParams(queryString || '');
            const state = {};
            for (const [key, value] of params) {
                state[key] = value;
            }
            // Validate propertyId for propertyDetail
            if (componentName === 'c__PropertyDetail' && !state.c__propertyId) {
                throw new Error('Invalid propertyId');
            }
            this[NavigationMixin.Navigate]({
                type: 'standard__webpage',
                attributes: {
                    url: url
                },
                state
            });
            // Clear localStorage after redirect
            localStorage.removeItem('lastVisitedPage');
        } catch (error) {
            console.error('Error redirecting to page:', error);
            this.redirectToDefaultPage();
        }
    }

    redirectToDefaultPage() {
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: {
                componentName: 'c__PMLandingPage'
            }
        });
    }
}