import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getScheduledVisits from '@salesforce/apex/OwnerPortalController.getScheduledVisits';
import generateCalendarInvite from '@salesforce/apex/OwnerPortalController.generateCalendarInvite';

export default class ScheduledVisitsTab extends LightningElement {
    @track error = '';
    @track visits = [];
    @track showInviteModal = false;
    @track selectedVisit;

    visitColumns = [
        { label: 'Visit Name', fieldName: 'Name' },
        { label: 'Property', fieldName: 'PropertyName' },
        { label: 'Client', fieldName: 'ClientName' },
        { label: 'Visit Date', fieldName: 'Visit_Date__c', type: 'date' },
        { label: 'Status', fieldName: 'Status__c' },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [{ label: 'Send Calendar Invite', name: 'send_invite' }]
            }
        }
    ];

    @wire(getScheduledVisits)
    wiredVisits({ error, data }) {
        if (data) {
            this.visits = data.map(visit => ({
                Id: visit.Id,
                Name: visit.Name,
                PropertyName: visit.Property__r?.Name || 'Unknown Property',
                ClientName: visit.Client__r?.Name__c || 'Unknown Client',
                Visit_Date__c: visit.Visit_Date__c,
                Status__c: visit.Status__c || 'Unknown'
            }));
            this.error = this.visits.length === 0 ? 'No visits found.' : '';
        } else if (error) {
            this.error = 'Error loading visits: ' + (error.body?.message || 'Unknown error');
            this.visits = [];
            this.showError(this.error);
        }
    }

    handleVisitRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'send_invite') {
            this.selectedVisit = {
                Id: row.Id,
                ClientName: row.ClientName,
                VisitDate: row.Visit_Date__c,
                PropertyName: row.PropertyName
            };
            this.showInviteModal = true;
        }
    }

    closeInviteModal() {
        this.showInviteModal = false;
        this.selectedVisit = null;
    }

    confirmSendInvite() {
        const visitId = this.selectedVisit.Id;
        generateCalendarInvite({ visitId })
            .then(result => {
                const url = 'data:text/calendar;charset=utf-8,' + encodeURIComponent(result);
                const link = document.createElement('a');
                link.setAttribute('href', url);
                link.setAttribute('download', `visit_${visitId}.ics`);
                link.click();
                this.closeInviteModal();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Calendar invite generated.',
                        variant: 'success'
                    })
                );
            })
            .catch(error => {
                this.closeInviteModal();
                this.error = 'Error generating calendar invite: ' + (error.body?.message || 'Unknown error');
                this.showError(this.error);
            });
    }

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