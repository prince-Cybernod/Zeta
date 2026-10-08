import { LightningElement } from 'lwc';
import isGuest from '@salesforce/user/isGuest';
import LANG from '@salesforce/i18n/lang';
import setPortalLanguage from '@salesforce/apex/ZetaApplicationController.setPortalLanguage';
import { ErrorHandler } from 'c/errorHandler';
import labelEnglish from '@salesforce/label/c.AppUI_LanguageEnglish';
import labelSpanish from '@salesforce/label/c.AppUI_LanguageSpanish';
import labelChinese from '@salesforce/label/c.AppUI_LanguageChinese';
import labelLanguageSwitcher from '@salesforce/label/c.AppUI_LanguageSwitcher';

// Values are the Zeta_Supported_Languages picklist values, which are also User language keys.
const LANGUAGES = [
  { value: 'en_US', label: labelEnglish },
  { value: 'es', label: labelSpanish },
  { value: 'zh_CN', label: labelChinese }
];

/**
 * Lets a parent switch the portal language. A logged-in parent's choice is saved
 * on their user; a guest on the login pages has no user to save to, so the choice
 * rides on the ?language= URL override instead.
 */
export default class PortalLanguageSwitcher extends LightningElement {
  labelLanguageSwitcher = labelLanguageSwitcher;
  // Match on the base language only: Salesforce reports Chinese as zh-Hans-CN.
  currentLanguage = LANGUAGES.find(
    (language) => language.value.split('_')[0] === LANG.split('-')[0]
  )?.value;
  isSaving = false;

  // Guests see the purple login pages; logged-in parents see white pages.
  get barClass() {
    return isGuest ? 'bar bar-on-dark' : 'bar bar-on-light';
  }

  get options() {
    return LANGUAGES.map((language) => {
      const isSelected = language.value === this.currentLanguage;
      return {
        ...language,
        ariaPressed: String(isSelected),
        className: isSelected ? 'option selected' : 'option'
      };
    });
  }

  async handleSelect(event) {
    const language = event.currentTarget.dataset.value;
    if (this.isSaving || language === this.currentLanguage) {
      return;
    }
    this.isSaving = true;
    // Salesforce renders the whole page in one language at load time, so switching
    // always takes one page load — there is no client-side re-render to a new language.
    const url = new URL(window.location.href);
    if (isGuest) {
      url.searchParams.set('language', language);
      window.location.replace(url.toString());
      return;
    }
    try {
      await setPortalLanguage({ language });
      // Reload without a ?language= override that would win over the new setting.
      url.searchParams.delete('language');
      window.location.replace(url.toString());
    } catch (error) {
      this.isSaving = false;
      ErrorHandler.toast(this, error);
    }
  }
}
