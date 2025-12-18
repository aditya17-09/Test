import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createProperty from '@salesforce/apex/SavePropertyController.createProperty';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import BEDROOMS_FIELD from '@salesforce/schema/Property__c.Bedrooms__c';
import STATUS_FIELD from '@salesforce/schema/Property__c.Status__c';
import PROPERTY_TYPE_FIELD from '@salesforce/schema/Property__c.Property_Type__c';
import OWNER_TYPE_FIELD from '@salesforce/schema/Property_Owner__c.Type__c';
export default class PropertyEntry extends LightningElement {
    @track name = '';
    @track address = '';
    @track price = '';
    @track propertyType = '';
    @track bedrooms = '';
    @track status = '';
    @track squareFootage = '';
    @track contentDocumentId = '';
    @track amenities = [];
    @track leaseTerms = '';
    @track ownerName = '';
    @track ownerPhone = '';
    @track ownerEmail = '';
    @track ownerAddress = '';
    @track ownerType = '';
    @track error = '';
    @track bedroomOptions = [];
    @track statusOptions = [];
    @track propertyTypeOptions = [];
    @track ownerTypeOptions = [];
    amenityOptions = [
        { label: 'Pool', value: 'Pool', checked: false },
        { label: 'Gym', value: 'Gym', checked: false },
        { label: 'Parking', value: 'Parking', checked: false },
        { label: 'Balcony', value: 'Balcony', checked: false }
    ];
    @wire(getPicklistValues, { recordTypeId: '012000000000000AAA', fieldApiName: PROPERTY_TYPE_FIELD })
    propertyTypePicklist({ error, data }) {
        if (data) this.propertyTypeOptions = data.values.map(value => ({ label: value.label, value: value.value }));
        else if (error) this.showErrorToast('Failed to load Property Type options.');
    }
    @wire(getPicklistValues, { recordTypeId: '012000000000000AAA', fieldApiName: BEDROOMS_FIELD })
    bedroomsPicklist({ error, data }) {
        if (data) this.bedroomOptions = data.values.map(value => ({ label: value.label, value: value.value }));
        else if (error) this.showErrorToast('Failed to load Bedrooms options.');
    }
    @wire(getPicklistValues, { recordTypeId: '012000000000000AAA', fieldApiName: STATUS_FIELD })
    statusPicklist({ error, data }) {
        if (data) this.statusOptions = data.values.map(value => ({ label: value.label, value: value.value }));
        else if (error) this.showErrorToast('Failed to load Status options.');
    }
    @wire(getPicklistValues, { recordTypeId: '012000000000000AAA', fieldApiName: OWNER_TYPE_FIELD })
    ownerTypePicklist({ error, data }) {
        if (data) this.ownerTypeOptions = data.values.map(value => ({ label: value.label, value: value.value }));
        else if (error) this.showErrorToast('Failed to load Owner Type options.');
    }
    handleNameChange(event) { this.name = event.target.value; }
    handleAddressChange(event) { this.address = event.target.value; }
    handlePriceChange(event) { this.price = event.target.value; }
    handlePropertyTypeChange(event) { this.propertyType = event.target.value; }
    handleBedroomsChange(event) { this.bedrooms = event.target.value; }
    handleStatusChange(event) { this.status = event.target.value; }
    handleSquareFootageChange(event) { this.squareFootage = event.target.value; }
    handleLeaseTermsChange(event) { this.leaseTerms = event.target.value; }
    handleOwnerNameChange(event) { this.ownerName = event.target.value; }
    handleOwnerPhoneChange(event) { this.ownerPhone = event.target.value; }
    handleOwnerEmailChange(event) { this.ownerEmail = event.target.value; }
    handleOwnerAddressChange(event) { this.ownerAddress = event.target.value; }
    handleOwnerTypeChange(event) { this.ownerType = event.target.value; }
    handleAmenityChange(event) {
        const value = event.target.value;
        const checked = event.target.checked;
        this.amenityOptions = this.amenityOptions.map(option => option.value === value ? { ...option, checked } : option);
        this.amenities = this.amenityOptions.filter(option => option.checked).map(option => option.value);
    }
    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            this.contentDocumentId = uploadedFiles[0].documentId;
            this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'File uploaded successfully.', variant: 'success' }));
        } else {
            this.error = 'File upload failed.';
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: this.error, variant: 'error' }));
        }
    }
    async handleSave() {
        try {
            const requiredFields = [
                { value: this.name, label: 'Name' },
                { value: this.address, label: 'Address' },
                { value: this.price, label: 'Price' },
                { value: this.propertyType, label: 'Property Type' },
                { value: this.bedrooms, label: 'Bedrooms' },
                { value: this.status, label: 'Status' },
                { value: this.ownerName, label: 'Owner Name' },
                { value: this.ownerEmail, label: 'Owner Email' },
                { value: this.ownerType, label: 'Owner Type' }
            ];
            const invalidFields = requiredFields.filter(field => !field.value);
            if (invalidFields.length > 0) {
                this.error = `Please fill out: ${invalidFields.map(f => f.label).join(', ')}.`;
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: this.error, variant: 'error' }));
                return;
            }
            const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            if (!emailRegex.test(this.ownerEmail)) {
                this.error = 'Please enter a valid Owner Email.';
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: this.error, variant: 'error' }));
                return;
            }
            const propertyId = await createProperty({
                name: this.name,
                address: this.address,
                price: this.price ? Number(this.price) : null,
                propertyType: this.propertyType,
                bedrooms: this.bedrooms,
                status: this.status,
                squareFootage: this.squareFootage ? Number(this.squareFootage) : null,
                contentDocumentId: this.contentDocumentId,
                amenities: this.amenities,
                leaseTerms: this.leaseTerms,
                ownerName: this.ownerName,
                ownerPhone: this.ownerPhone,
                ownerEmail: this.ownerEmail,
                ownerAddress: this.ownerAddress,
                ownerType: this.ownerType
            });
            this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Property saved successfully.', variant: 'success' }));
            this.name = '';
            this.address = '';
            this.price = '';
            this.propertyType = '';
            this.bedrooms = '';
            this.status = '';
            this.squareFootage = '';
            this.contentDocumentId = '';
            this.amenities = [];
            this.leaseTerms = '';
            this.ownerName = '';
            this.ownerPhone = '';
            this.ownerEmail = '';
            this.ownerAddress = '';
            this.ownerType = '';
            this.error = '';
            this.amenityOptions = this.amenityOptions.map(option => ({ ...option, checked: false }));
            const fileUpload = this.template.querySelector('lightning-file-upload');
            if (fileUpload) fileUpload.files = [];
        } catch (error) {
            this.error = error.body?.message || 'An unexpected error occurred.';
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: this.error, variant: 'error' }));
        }
    }
    showErrorToast(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: message, variant: 'error' }));
    }
}