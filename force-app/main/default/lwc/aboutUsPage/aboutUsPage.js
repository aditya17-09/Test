import { LightningElement } from 'lwc';
// import facebookIcon from '@salesforce/resourceUrl/facebookIcon';
// import twitterIcon from '@salesforce/resourceUrl/twitterIcon';
// import linkedinIcon from '@salesforce/resourceUrl/linkedinIcon';
// import instagramIcon from '@salesforce/resourceUrl/instagramIcon';

export default class AboutUsPage extends LightningElement {
    // facebookIcon = facebookIcon;
    // twitterIcon = twitterIcon;
    // linkedinIcon = linkedinIcon;
    // instagramIcon = instagramIcon;

    // Handle Scroll for Fade-In Animations
    connectedCallback() {
        window.addEventListener('scroll', this.handleScroll.bind(this));
    }

    disconnectedCallback() {
        window.removeEventListener('scroll', this.handleScroll.bind(this));
    }

    handleScroll() {
        const elements = this.template.querySelectorAll('.fade-in');
        elements.forEach(element => {
            const rect = element.getBoundingClientRect();
            if (rect.top < window.innerHeight * 0.8) {
                element.classList.add('visible');
            }
        });
    }
}