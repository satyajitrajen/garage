// Everything the store listings and legal pages depend on, in one place.
// Update the store links once the app is published.
export const site = {
  appName: 'NT Garage',
  company: 'Nexory',
  supportEmail: 'support@nexorytechnologies.com',
  // Shown on the legal pages as their effective date.
  policiesUpdated: '8 October 2026',
  trialDays: 14,
  prices: { monthly: 499, yearly: 4990 },
  // null = not published yet: the badge shows "Coming soon" and is not a link.
  stores: {
    appStore: null, // e.g. 'https://apps.apple.com/app/id0000000000'
    playStore: null, // e.g. 'https://play.google.com/store/apps/details?id=com.nexory.garage'
  },
  androidPackage: 'com.nexory.garage',
}

export const rupees = (n) => '₹' + n.toLocaleString('en-IN')
