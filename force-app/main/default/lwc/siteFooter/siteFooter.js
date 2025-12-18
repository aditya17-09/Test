import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
// import facebookIcon from '@salesforce/resourceUrl/facebookIcon';
// import youtubeIcon from '@salesforce/resourceUrl/youtubeIcon';
// import twitterIcon from '@salesforce/resourceUrl/twitterIcon';
// import instagramIcon from '@salesforce/resourceUrl/instagramIcon';

export default class SiteFooter extends NavigationMixin(LightningElement) {
    // Static resource URLs for social icons
    // facebookIcon = facebookIcon;
    // youtubeIcon = youtubeIcon;
    // twitterIcon = twitterIcon;
    // instagramIcon = instagramIcon;

    // Navigate to About Us page
    navigateToAboutUs() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/aboutus'
            }
        });
    }
}