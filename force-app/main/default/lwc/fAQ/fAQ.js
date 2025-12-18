import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import createCase from '@salesforce/apex/FAQController.createCase';
import USER_ID from '@salesforce/user/Id';
import CLIENT_ID from '@salesforce/schema/User.ContactId';

export default class FaqPortal extends LightningElement {
    @track formData = {
        subject: '',
        description: '',
        email: '',
        priority: 'Medium',
        contactId: ''
    };
    @track isAuthenticated = false;
    @track clientId;

    // Form Options
    priorityOptions = [
        { label: 'Low', value: 'Low' },
        { label: 'Medium', value: 'Medium' },
        { label: 'High', value: 'High' }
    ];

    @wire(getRecord, { recordId: USER_ID, fields: [CLIENT_ID] })
    user({ error, data }) {
        if (data) {
            this.isAuthenticated = !!data.fields.ContactId.value;
            this.clientId = data.fields.ContactId.value;
            if (this.isAuthenticated) {
                this.formData.email = data.fields.Email?.value || '';
            }
        } else if (error) {
            this.showToast('Error', 'Failed to fetch user data', 'error');
        }
    }

    handleSubjectChange(event) { this.formData.subject = event.target.value; }
    handleDescriptionChange(event) { this.formData.description = event.target.value; }
    handleEmailChange(event) { this.formData.email = event.target.value; }
    handlePriorityChange(event) { this.formData.priority = event.target.value; }
    handleContactChange(event) { this.formData.contactId = event.target.value; }

    async handleSubmit() {
        try {
            // Validate standard form fields (excluding lightning-input-field)
            const standardInputs = [...this.template.querySelectorAll('lightning-input, lightning-textarea, lightning-combobox')];
            const standardInputsValid = standardInputs.reduce((valid, input) => {
                input.reportValidity();
                return valid && input.checkValidity();
            }, true);

            // Validate ContactId field separately
            const contactInput = this.template.querySelector('lightning-input-field[field-name="ContactId"]');
            const contactIdValid = this.formData.contactId && this.formData.contactId.trim() !== '';

            if (!standardInputsValid) {
                this.showToast('Error', 'Please fill out all required fields correctly.', 'error');
                return;
            }

            if (!contactIdValid) {
                this.showToast('Error', 'Please select a Contact.', 'error');
                if (contactInput) {
                    contactInput.setCustomValidity('Contact is required');
                    contactInput.reportValidity();
                }
                return;
            } else {
                // Clear any custom validation error if the ContactId is valid
                if (contactInput) {
                    contactInput.setCustomValidity('');
                    contactInput.reportValidity();
                }
            }

            // Create the Case
            const caseId = await createCase({
                subject: this.formData.subject,
                description: this.formData.description,
                email: this.formData.email,
                priority: this.formData.priority,
                userId: this.isAuthenticated ? USER_ID : null,
                contactId: this.formData.contactId
            });

            // Show success toast
            this.showToast('Success', `Inquiry submitted successfully! Case ID: ${caseId}`, 'success');

            // Reset form
            this.formData = {
                subject: '',
                description: '',
                email: this.isAuthenticated ? this.formData.email : '',
                priority: 'Medium',
                contactId: ''
            };
            if (contactInput) {
                contactInput.value = null;
            }
        } catch (error) {
            const errorMessage = error.body?.message || error.message || 'An unexpected error occurred.';
            this.showToast('Error', errorMessage, 'error');
        }
    }

    // Helper method to show toast notifications
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    connectedCallback() {
        window.addEventListener('scroll', this.handleScroll.bind(this));
    }

    disconnectedCallback() {
        window.removeEventListener('scroll', this.handleScroll.bind(this));
    }

    handleScroll() {
        const fadeElements = this.template.querySelectorAll('.fade-in');
        const slideElements = this.template.querySelectorAll('.slide-in');
        fadeElements.forEach(element => {
            const rect = element.getBoundingClientRect();
            if (rect.top < window.innerHeight * 0.8) {
                element.classList.add('visible');
            }
        });
        slideElements.forEach(element => {
            const rect = element.getBoundingClientRect();
            if (rect.top < window.innerHeight * 0.8) {
                element.classList.add('visible');
            }
        });
    }
}