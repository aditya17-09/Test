import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class OwnerPortalHome extends NavigationMixin(LightningElement) {
    @track error = '';
    @track currentQuote = '';

    quotes = [
        'Real estate is about the people, not just the properties.',
        'Your property is an opportunity to create someone’s dream home.',
        'Invest in real estate, invest in the future.',
        'Every property tells a story—share yours with the world.'
    ];

    connectedCallback() {
        this.startQuoteRotation();
    }

    startQuoteRotation() {
        this.currentQuote = this.quotes[0];
        let index = 1;
        setInterval(() => {
            const quoteElement = this.template.querySelector('.custom-quote');
            if (quoteElement) {
                quoteElement.classList.add('fade-out');
            }
            setTimeout(() => {
                this.currentQuote = this.quotes[index];
                if (quoteElement) {
                    quoteElement.classList.remove('fade-out');
                    quoteElement.classList.add('fade-in');
                }
                index = (index + 1) % this.quotes.length;
            }, 500);
        }, 5000);
    }

    navigateToPropertyEntry() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/postaproperty'
            }
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