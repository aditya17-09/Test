/**
 * propertyDetail LWC
 * Displays property details and handles actions like generating contracts, uploading documents,
 * scheduling visits, and initiating payments. Updated to fix payment screen (using PropertySearchController.initiatePayment)
 * and Generate Document button (enabled for new properties).
 */
import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateContract from '@salesforce/apex/ContractPDFController.generateContract';
import saveClientDocument from '@salesforce/apex/PropertySearchController.saveClientDocument';
import checkPropertyDocumentStatus from '@salesforce/apex/PropertySearchController.checkPropertyDocumentStatus';
import scheduleVisit from '@salesforce/apex/PropertyVisitController.scheduleVisit';
import hasScheduledVisit from '@salesforce/apex/PropertyVisitController.hasScheduledVisit';
import initiatePayment from '@salesforce/apex/PropertySearchController.initiatePayment'; // Updated to use PropertySearchController
import PLACEHOLDER_IMAGE from '@salesforce/resourceUrl/placeholder';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import EMAIL_FIELD from '@salesforce/schema/User.Email';
import NAME_FIELD from '@salesforce/schema/User.Name';
import PHONE_FIELD from '@salesforce/schema/User.Phone';
import PROPERTY_OBJECT from '@salesforce/schema/Property__c';
import PROPERTY_NAME_FIELD from '@salesforce/schema/Property__c.Name';
import ADDRESS_FIELD from '@salesforce/schema/Property__c.Address__c';
import PHOTOS_FIELD from '@salesforce/schema/Property__c.Photos__c';
import PRICE_FIELD from '@salesforce/schema/Property__c.Price__c';
import PROPERTY_TYPE_FIELD from '@salesforce/schema/Property__c.Property_Type__c';
import SQUARE_FOOTAGE_FIELD from '@salesforce/schema/Property__c.Square_Footage__c';
import BEDROOMS_FIELD from '@salesforce/schema/Property__c.Bedrooms__c';
import AMENITIES_FIELD from '@salesforce/schema/Property__c.Amenities__c';
import PROPERTY_STAGE_FIELD from '@salesforce/schema/Property__c.Property_Stage__c';
import LEASE_TERMS_FIELD from '@salesforce/schema/Property__c.Lease_Terms__c';
import STATUS_FIELD from '@salesforce/schema/Property__c.Status__c';

export default class PropertyDetail extends NavigationMixin(LightningElement) {
    @track propertyId;
    @track property;
    @track amenities = [];
    @track error = '';
    @track showFileUpload = false;
    @track isUploadDisabled = false;
    @track isGenerateDisabled = false; // Default to false to enable for new properties
    @track showScheduleVisitModal = false;
    @track visitDate;
    @track isScheduleButtonDisabled = true;
    @track hasScheduledVisit = false;
    @track minDateTime;
    @track showPaymentModal = false;
    @track paymentAmount;
    @track paymentDueDate;
    @track isPaymentButtonDisabled = true;
    @track isPaymentDisabled = true;
    @track clientId;
    placeholderImage = PLACEHOLDER_IMAGE;
    currentUserId = USER_ID;
    @track userEmail;
    @track userName;
    @track userPhone;

    propertyFields = [
        PROPERTY_NAME_FIELD,
        ADDRESS_FIELD,
        PHOTOS_FIELD,
        PRICE_FIELD,
        PROPERTY_TYPE_FIELD,
        SQUARE_FOOTAGE_FIELD,
        BEDROOMS_FIELD,
        AMENITIES_FIELD,
        PROPERTY_STAGE_FIELD,
        LEASE_TERMS_FIELD,
        STATUS_FIELD
    ];

    /**
     * Initializes the component, sets minimum date for modals, and checks document status.
     */
    connectedCallback() {
        const now = new Date();
        this.minDateTime = now.toISOString().slice(0, 16);

        // Extract propertyId from URL
        const urlParams = new URLSearchParams(window.location.search);
        this.propertyId = urlParams.get('c__propertyId');
        if (!this.propertyId || !this.propertyId.match(/^[a-zA-Z0-9]{15,18}$/)) {
            this.error = 'Invalid or missing property ID.';
            this.showError(this.error);
            return;
        }

        // Check document status to set button states
        checkPropertyDocumentStatus({ propertyId: this.propertyId })
            .then(result => {
                console.log('checkPropertyDocumentStatus result:', result);
                this.isUploadDisabled = result.isComplete;
                this.isGenerateDisabled = result.isComplete; // Enable unless a completed document exists
                this.isPaymentDisabled = !result.isComplete; // Enable payment only after document completion
                this.clientId = result.clientId;
            })
            .catch(error => {
                console.error('Error checking document status:', JSON.stringify(error));
                this.showError('Failed to check document status.');
            });
    }

    /**
     * Fetches user details (email, name, phone).
     */
    @wire(getRecord, { recordId: '$currentUserId', fields: [EMAIL_FIELD, NAME_FIELD, PHONE_FIELD] })
    wiredUser({ error, data }) {
        if (data) {
            this.userEmail = getFieldValue(data, EMAIL_FIELD);
            this.userName = getFieldValue(data, NAME_FIELD);
            this.userPhone = getFieldValue(data, PHONE_FIELD);
        } else if (error) {
            console.error('Error fetching user details:', JSON.stringify(error));
            this.showError('Failed to load user details.');
        }
    }

    /**
     * Checks if a visit is already scheduled.
     */
    @wire(hasScheduledVisit, { propertyId: '$propertyId' })
    wiredHasScheduledVisit({ error, data }) {
        if (data !== undefined) {
            this.hasScheduledVisit = data;
        } else if (error) {
            console.error('Error checking scheduled visit:', JSON.stringify(error));
            this.showError('Failed to check scheduled visit status.');
        }
    }

    /**
     * Fetches property details and formats data.
     */
    @wire(getRecord, { recordId: '$propertyId', fields: '$propertyFields' })
    wiredProperty({ error, data }) {
        if (data) {
            this.error = '';
            this.property = this.formatProperty({
                propertyData: {
                    Id: this.propertyId,
                    Name: getFieldValue(data, PROPERTY_NAME_FIELD),
                    Address__c: getFieldValue(data, ADDRESS_FIELD),
                    Photos__c: getFieldValue(data, PHOTOS_FIELD),
                    Price__c: getFieldValue(data, PRICE_FIELD),
                    Property_Type__c: getFieldValue(data, PROPERTY_TYPE_FIELD),
                    Square_Footage__c: getFieldValue(data, SQUARE_FOOTAGE_FIELD),
                    Bedrooms__c: getFieldValue(data, BEDROOMS_FIELD),
                    Amenities__c: getFieldValue(data, AMENITIES_FIELD),
                    Property_Stage__c: getFieldValue(data, PROPERTY_STAGE_FIELD),
                    Lease_Terms__c: getFieldValue(data, LEASE_TERMS_FIELD),
                    Status__c: getFieldValue(data, STATUS_FIELD)
                },
                ImageUrl: this.extractImageUrl(getFieldValue(data, PHOTOS_FIELD)) || this.placeholderImage
            });
            this.amenities = this.property.propertyData.Amenities__c
                ? this.property.propertyData.Amenities__c.split(';').map(item => item.trim()).filter(item => item)
                : [];
            this.paymentAmount = this.property.propertyData.Price__c; // Default payment amount to property price
        } else if (error) {
            console.error('Error fetching property details:', JSON.stringify(error));
            this.error = error.body?.message || 'Failed to load property details.';
            this.property = null;
            this.amenities = [];
            this.showError(this.error);
        }
    }

    /**
     * Extracts image URL from Photos__c field.
     */
    extractImageUrl(photos) {
        if (!photos) return null;
        if (photos.includes('<img')) {
            const match = photos.match(/src=["'](.*?)["']/i);
            return match && match[1] ? match[1] : null;
        }
        return photos;
    }

    /**
     * Formats property data, inferring bedrooms from square footage if needed.
     */
    formatProperty(property) {
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
    }

    /**
     * Handles image loading errors by setting placeholder image.
     */
    handleImageError(event) {
        console.error(`Image failed to load for property ${this.propertyId}`);
        event.target.src = this.placeholderImage;
    }

    /**
     * Navigates back to pending actions page.
     */
    handleBack() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/pendingactions'
            }
        });
    }

    /**
     * Opens the Schedule Visit modal.
     */
    openScheduleVisitModal() {
        this.showScheduleVisitModal = true;
        this.visitDate = null;
        this.isScheduleButtonDisabled = true;
        this.minDateTime = new Date().toISOString().slice(0, 16);
    }

    /**
     * Closes the Schedule Visit modal.
     */
    closeScheduleVisitModal() {
        this.showScheduleVisitModal = false;
        this.visitDate = null;
        this.isScheduleButtonDisabled = true;
    }

    /**
     * Updates visit date and validates schedule button.
     */
    handleVisitDateChange(event) {
        this.visitDate = event.target.value;
      this.isScheduleButtonDisabled = !this.visitDate || new Date(this.visitDate) < new Date();
    }

    /**
     * Schedules a property visit.
     */
    async handleScheduleVisit() {
        try {
            if (!this.visitDate) {
                throw new Error('Please select a valid date and time.');
            }
            const visitId = await scheduleVisit({
                propertyId: this.propertyId,
                visitDate: this.visitDate
            });
            this.hasScheduledVisit = true;
            this.closeScheduleVisitModal();
            this.showSuccess('Visit scheduled successfully.');
        } catch (error) {
            console.error('Error scheduling visit:', JSON.stringify(error));
            this.showError(error.body?.message || error.message || 'Failed to schedule visit.');
        }
    }

    /**
     * Generates a contract PDF for the property.
     */
    async handleGenerateDocument() {
        try {
            this.error = '';
            this.showFileUpload = false;

            if (!this.userEmail || !this.userName) {
                throw new Error('User email or name is missing.');
            }

            const contentDocumentId = await generateContract({
                propertyId: this.propertyId,
                clientEmail: this.userEmail,
                clientName: this.userName,
                clientPhone: this.userPhone
            });

            const downloadUrl = `/sfc/servlet.shepherd/document/download/${contentDocumentId}`;
            const link = document.createElement('a');
            link.href = downloadUrl;
            link.download = `contract_${this.propertyId}.pdf`;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);

            this.showFileUpload = true;
            this.isUploadDisabled = false;
            this.isGenerateDisabled = false;

            this.showSuccess('Contract generated successfully. Please upload the signed document.');
        } catch (error) {
            console.error('Error generating contract:', JSON.stringify(error));
            this.showError(error.body?.message || error.message || 'Failed to generate contract.');
        }
    }

    /**
     * Handles signed document upload.
     */
    async handleFileUpload(event) {
        try {
            this.error = '';
            const uploadedFiles = event.detail.files;
            if (uploadedFiles.length === 0) {
                throw new Error('No file uploaded.');
            }

            const contentDocumentId = uploadedFiles[0].documentId;

            await saveClientDocument({
                propertyId: this.propertyId,
                contentDocumentId: contentDocumentId,
                clientEmail: this.userEmail,
                clientName: this.userName,
                clientPhone: this.userPhone
            });

            this.isUploadDisabled = true;
            this.isGenerateDisabled = true;
            this.isPaymentDisabled = false; // Enable payment after document upload

            this.showSuccess('Signed document uploaded successfully.');
        } catch (error) {
            console.error('Error uploading file:', JSON.stringify(error));
            this.showError(error.body?.message || error.message || 'Failed to upload signed document.');
        }
    }

    /**
     * Opens the Payment modal with default values.
     */
    openPaymentModal() {
        this.showPaymentModal = true;
        this.paymentAmount = this.property?.propertyData?.Price__c || 0;
        this.paymentDueDate = null;
        this.isPaymentButtonDisabled = true;
        this.minDateTime = new Date().toISOString().slice(0, 16);
    }

    /**
     * Closes the Payment modal.
     */
    closePaymentModal() {
        this.showPaymentModal = false;
        this.paymentAmount = null;
        this.paymentDueDate = null;
        this.isPaymentButtonDisabled = true;
    }

    /**
     * Updates payment amount and validates button state.
     */
    handlePaymentAmountChange(event) {
        this.paymentAmount = event.target.value;
        this.updatePaymentButtonState();
    }

    /**
     * Updates payment due date and validates button state.
     */
    handlePaymentDueDateChange(event) {
        this.paymentDueDate = event.target.value;
        this.updatePaymentButtonState();
    }

    /**
     * Validates payment button state based on amount and due date.
     */
    updatePaymentButtonState() {
        this.isPaymentButtonDisabled = !this.paymentAmount || this.paymentAmount <= 0 || !this.paymentDueDate || new Date(this.paymentDueDate) < new Date();
    }

    /**
     * Initiates payment, creates Payment__c record, and downloads PDF receipt.
     * Updated to use PropertySearchController.initiatePayment for PDF generation.
     */
    async handleInitiatePayment() {
        try {
            if (!this.paymentAmount || !this.paymentDueDate || !this.clientId) {
                throw new Error('Please provide a valid payment amount, due date, and client.');
            }

            // Log inputs for debugging
            console.log('Calling initiatePayment with:', {
                propertyId: this.propertyId,
                clientId: this.clientId,
                amount: this.paymentAmount,
                dueDate: this.paymentDueDate
            });

            // Call Apex to create Payment__c and generate PDF receipt
            const contentDocumentId = await initiatePayment({
                propertyId: this.propertyId,
                clientId: this.clientId,
                amount: this.paymentAmount,
                dueDate: this.paymentDueDate
            });

            // Download the PDF receipt
            const downloadUrl = `/sfc/servlet.shepherd/document/download/${contentDocumentId}`;
            const link = document.createElement('a');
            link.href = downloadUrl;
            link.download = `payment_receipt_${this.propertyId}.pdf`;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);

            // Close modal and disable payment button
            this.closePaymentModal();
            this.isPaymentDisabled = true;
            this.showSuccess('Payment initiated successfully. Receipt has been downloaded.');
        } catch (error) {
            console.error('Error initiating payment:', JSON.stringify(error));
            this.showError(error.body?.message || error.message || 'Failed to initiate payment.');
        }
    }

    /**
     * Displays a success toast message.
     */
    showSuccess(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message,
                variant: 'success'
            })
        );
    }

    /**
     * Displays an error toast message.
     */
    showError(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message,
                variant: 'error'
            })
        );
    }
}