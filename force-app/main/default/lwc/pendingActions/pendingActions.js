import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getPendingActions from '@salesforce/apex/PropertySearchController.getPendingActions';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import EMAIL_FIELD from '@salesforce/schema/User.Email';
import NAME_FIELD from '@salesforce/schema/User.Name';
import PHONE_FIELD from '@salesforce/schema/User.Phone';

export default class PendingActions extends NavigationMixin(LightningElement) {
    @track pendingActions = [];
    @track error = '';
    @track userEmail;
    @track userName;
    @track userPhone;
    currentUserId = USER_ID;

    columns = [
        { label: 'Document Name', fieldName: 'documentName', type: 'text' },
        { label: 'Property Name', fieldName: 'propertyName', type: 'text' },
        { label: 'Property Address', fieldName: 'propertyAddress', type: 'text' },
        { label: 'Document Type', fieldName: 'documentType', type: 'text' },
        { label: 'Status', fieldName: 'status', type: 'text' },
        { label: 'Pending Reason', fieldName: 'pendingReason', type: 'text' },
        { label: 'Created Date', fieldName: 'createdDate', type: 'date' },
        { label: 'Action Type', fieldName: 'actionType', type: 'text' },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [
                    { label: 'View Details', name: 'view_details' }
                ]
            }
        }
    ];

    @wire(getRecord, { recordId: '$currentUserId', fields: [EMAIL_FIELD, NAME_FIELD, PHONE_FIELD] })
    wiredUser({ error, data }) {
        if (data) {
            this.userEmail = getFieldValue(data, EMAIL_FIELD);
            this.userName = getFieldValue(data, NAME_FIELD);
            this.userPhone = getFieldValue(data, PHONE_FIELD);
            this.loadPendingActions();
        } else if (error) {
            console.error('Error fetching user details:', JSON.stringify(error));
            this.error = 'Failed to load user details.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.error,
                    variant: 'error'
                })
            );
        }
    }

    loadPendingActions() {
        if (!this.userEmail) {
            this.error = 'User email is missing.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: this.error,
                    variant: 'error'
                })
            );
            return;
        }

        getPendingActions({ userEmail: this.userEmail })
            .then(result => {
                this.pendingActions = result.map(action => ({
                    ...action,
                    isDisabled: action.actionType !== 'PropertyDocument'
                }));
                this.error = '';
            })
            .catch(error => {
                console.error('Error fetching pending actions:', JSON.stringify(error));
                this.error = error.body?.message || error.message || 'Failed to load pending actions.';
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: this.error,
                        variant: 'error'
                    })
                );
            });
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'view_details') {
            if (row.actionType === 'PropertyDocument' && row.propertyId) {
                // Validate propertyId (basic check for Salesforce ID format)
                if (row.propertyId.match(/^[a-zA-Z0-9]{15,18}$/)) {
                    // Navigate to propertydetail page
                    this[NavigationMixin.Navigate]({
                        type: 'standard__webPage',
                        attributes: {
                            url: `/propertydetail?c__propertyId=${row.propertyId}`
                        }
                    });
                } else {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: 'Invalid property ID for this document.',
                            variant: 'error'
                        })
                    );
                }
            } else {
                // Show toast for Client_Document__c or invalid rows
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Info',
                        message: 'No property details available for this document.',
                        variant: 'info'
                    })
                );
            }
        }
    }
}