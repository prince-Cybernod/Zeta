import { LightningElement, api } from 'lwc';
import getEligibleSchools from '@salesforce/apex/SchoolSelectionController.getEligibleSchools';
import getSelectedSchools from '@salesforce/apex/SchoolSelectionController.getSelectedSchools';
import saveSchoolSelections from '@salesforce/apex/SchoolSelectionController.saveSchoolSelections';
import labelAriaLoadingSchools from '@salesforce/label/c.AppUI_AriaLoadingSchools';
import labelAriaSchoolSelections from '@salesforce/label/c.AppUI_AriaSchoolSelections';
import labelChooseSchools from '@salesforce/label/c.AppUI_ChooseSchools';
import labelChooseSchoolsDesc from '@salesforce/label/c.AppUI_ChooseSchoolsDesc';
import labelDistanceLessThan from '@salesforce/label/c.AppUI_DistanceLessThanPoint1';
import labelDistanceMiles from '@salesforce/label/c.AppUI_DistanceMiles';
import labelFilterBySchool from '@salesforce/label/c.AppUI_FilterBySchool';
import labelHome from '@salesforce/label/c.AppUI_Home';
import labelNoSchoolsSelected from '@salesforce/label/c.AppUI_NoSchoolsSelected';
import labelOneSchoolSelected from '@salesforce/label/c.AppUI_OneSchoolSelected';
import labelSaveSchoolsFailed from '@salesforce/label/c.AppUI_SaveSchoolsFailed';
import labelSchoolsSelectedPlural from '@salesforce/label/c.AppUI_SchoolsSelectedPlural';
import labelSearchSchools from '@salesforce/label/c.AppUI_SearchSchools';
import labelShowingSchoolsForGrade from '@salesforce/label/c.AppUI_ShowingSchoolsForGrade';
import labelValidateSelectSchool from '@salesforce/label/c.AppUI_ValidateSelectSchool';
import labelZetaSchools from '@salesforce/label/c.AppUI_ZetaSchools';
import ZIP_CENTROIDS from '@salesforce/resourceUrl/zipCentroids';

const ZETA_PURPLE = '#4F497A';
const ZETA_MAGENTA = '#CF3D96';
const HOME_RED = '#EF4444';

const SCHOOL_PIN_SIZE = { width: 34, height: 34 };
const SCHOOL_PIN_ANCHOR = { x: 17, y: 34 };

function buildSchoolPinUrl(fillColor) {
  const svg = [
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="34" height="34">',
    `<path d="M12 0C6 0 1 5 1 11C1 17 12 24 12 24C12 24 23 17 23 11C23 5 18 0 12 0Z" fill="${fillColor}" stroke="white" stroke-width="0.7"/>`,
    '<text x="12" y="14" font-family="Arial,sans-serif" font-size="10" font-weight="bold" fill="white" text-anchor="middle">Z</text>',
    '</svg>'
  ].join('');
  return `data:image/svg+xml;base64,${btoa(svg)}`;
}

const _centroidCache = new Map();
const STATE_ABBR = {
  alabama: 'al',
  alaska: 'ak',
  arizona: 'az',
  arkansas: 'ar',
  california: 'ca',
  colorado: 'co',
  connecticut: 'ct',
  delaware: 'de',
  'district of columbia': 'dc',
  florida: 'fl',
  georgia: 'ga',
  hawaii: 'hi',
  idaho: 'id',
  illinois: 'il',
  indiana: 'in',
  iowa: 'ia',
  kansas: 'ks',
  kentucky: 'ky',
  louisiana: 'la',
  maine: 'me',
  maryland: 'md',
  massachusetts: 'ma',
  michigan: 'mi',
  minnesota: 'mn',
  mississippi: 'ms',
  missouri: 'mo',
  montana: 'mt',
  nebraska: 'ne',
  nevada: 'nv',
  'new hampshire': 'nh',
  'new jersey': 'nj',
  'new mexico': 'nm',
  'new york': 'ny',
  'north carolina': 'nc',
  'north dakota': 'nd',
  ohio: 'oh',
  oklahoma: 'ok',
  oregon: 'or',
  pennsylvania: 'pa',
  'rhode island': 'ri',
  'south carolina': 'sc',
  'south dakota': 'sd',
  tennessee: 'tn',
  texas: 'tx',
  utah: 'ut',
  vermont: 'vt',
  virginia: 'va',
  washington: 'wa',
  'west virginia': 'wv',
  wisconsin: 'wi',
  wyoming: 'wy'
};

export default class SchoolSelection extends LightningElement {
  @api recordId;

  schools = [];
  selectedSchoolIds = new Set();
  searchTerm = '';
  isLoading = true;
  isSaving = false;
  saveError = '';
  _homeAddress = null;
  _grade = '';
  _schoolDataMap = new Map();
  _cachedMapMarkers = [];

  labels = {
    chooseSchools: labelChooseSchools,
    chooseSchoolsDesc: labelChooseSchoolsDesc,
    zetaSchools: labelZetaSchools,
    searchSchools: labelSearchSchools,
    filterBySchool: labelFilterBySchool,
    ariaLoadingSchools: labelAriaLoadingSchools,
    ariaSchoolSelections: labelAriaSchoolSelections
  };

  get showContent() {
    return !this.isLoading;
  }

  get gradeSubtitle() {
    if (!this._grade) return '';
    return labelShowingSchoolsForGrade.replace('{0}', this._grade);
  }

  get mapMarkers() {
    return this._cachedMapMarkers;
  }

  _buildMapMarkers() {
    if (!this.schools.length) {
      this._cachedMapMarkers = [];
      return;
    }
    const markers = this.schools.map((s) => ({
      location: {
        Street: s.street || '',
        City: s.city || '',
        State: s.state || '',
        PostalCode: s.postalCode || ''
      },
      title: s.name,
      description: [s.street, s.city, s.state].filter(Boolean).join(', '),
      value: s.schoolAccountId,
      mapIcon: {
        url: buildSchoolPinUrl(
          this.selectedSchoolIds.has(s.schoolAccountId)
            ? ZETA_MAGENTA
            : ZETA_PURPLE
        ),
        anchor: SCHOOL_PIN_ANCHOR,
        size: SCHOOL_PIN_SIZE,
        scaledSize: SCHOOL_PIN_SIZE
      }
    }));
    if (this._homeAddress?.street) {
      markers.push({
        location: {
          Street: this._homeAddress.street || '',
          City: this._homeAddress.city || '',
          State: this._homeAddress.state || '',
          PostalCode: this._homeAddress.postalCode || ''
        },
        title: labelHome,
        mapIcon: {
          path: 'M12 2L2 12h3v8h6v-6h2v6h6v-8h3L12 2z',
          fillColor: HOME_RED,
          fillOpacity: 1,
          strokeColor: '#FFFFFF',
          strokeWeight: 1,
          scale: 1.5,
          anchor: { x: 12, y: 22 }
        },
        value: '__home__'
      });
    }
    this._cachedMapMarkers = markers;
  }

  get hasMapMarkers() {
    return this._cachedMapMarkers.length > 0;
  }

  get filteredSchools() {
    const term = this.searchTerm.toLowerCase();
    return this.schools
      .filter((s) => !term || s.name.toLowerCase().includes(term))
      .map((s) => ({
        ...s,
        isSelected: this.selectedSchoolIds.has(s.schoolAccountId),
        hasDistance: s.distance != null,
        distanceLabel:
          s.distance != null
            ? s.distance === 0
              ? labelDistanceLessThan
              : labelDistanceMiles.replace('{0}', s.distance)
            : '',
        checkboxClass: `school-checkbox${this.selectedSchoolIds.has(s.schoolAccountId) ? ' school-checkbox--checked' : ''}`,
        rowClass: `school-row${this.selectedSchoolIds.has(s.schoolAccountId) ? ' school-row--selected' : ''}`
      }));
  }

  get selectedCount() {
    return this.selectedSchoolIds.size;
  }

  get selectionSummary() {
    const count = this.selectedCount;
    if (count === 0) return labelNoSchoolsSelected;
    if (count === 1) return labelOneSchoolSelected;
    return labelSchoolsSelectedPlural.replace('{0}', count);
  }

  get isStepComplete() {
    return this.selectedCount > 0;
  }

  connectedCallback() {
    this._loadData();
  }

  async _loadData() {
    try {
      const [eligibleResult, existingSelections] = await Promise.all([
        getEligibleSchools({ applicationId: this.recordId }),
        getSelectedSchools({ applicationId: this.recordId })
      ]);

      this.schools = eligibleResult.schools || [];
      this._homeAddress = eligibleResult.homeAddress || null;
      this._grade = eligibleResult.gradeLabel || eligibleResult.grade || '';

      const homeCentroid = await this._resolveCentroid(
        this._homeAddress?.state,
        this._homeAddress?.postalCode
      );
      const homeLat =
        homeCentroid?.latitude ?? this._homeAddress?.latitude ?? null;
      const homeLon =
        homeCentroid?.longitude ?? this._homeAddress?.longitude ?? null;

      this.schools = await Promise.all(
        this.schools.map(async (s, idx) => {
          const schoolCentroid = await this._resolveCentroid(
            s.state,
            s.postalCode
          );
          const dist = this._calculateDistance(
            homeLat,
            homeLon,
            schoolCentroid?.latitude ?? s.latitude ?? null,
            schoolCentroid?.longitude ?? s.longitude ?? null
          );
          return { ...s, distance: dist, _originalIndex: idx };
        })
      );
      this.schools.sort((a, b) => {
        if (a.distance != null && b.distance != null)
          return a.distance - b.distance;
        if (a.distance != null) return -1;
        if (b.distance != null) return 1;
        return a._originalIndex - b._originalIndex;
      });

      this._buildMapMarkers();

      this._schoolDataMap.clear();
      for (const school of this.schools) {
        this._schoolDataMap.set(school.schoolAccountId, school);
      }

      this.selectedSchoolIds = new Set(
        existingSelections.map((s) => s.schoolAccountId)
      );
    } catch (err) {
      console.error('Failed to load school data:', err);
    } finally {
      this.isLoading = false;
      this._dispatchCompletionStatus();
    }
  }

  handleMarkerSelect(event) {
    const markerValue = event.detail.selectedMarkerValue;
    if (markerValue && markerValue !== '__home__') {
      this._toggleSchool(markerValue);
    }
  }

  handleSearchChange(event) {
    this.searchTerm = event.target.value;
  }

  handleSchoolToggle(event) {
    const schoolId = event.currentTarget.dataset.id;
    this._toggleSchool(schoolId);
  }

  handleRowKeydown(event) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      this.handleSchoolToggle(event);
    }
  }

  _toggleSchool(schoolId) {
    const newSet = new Set(this.selectedSchoolIds);
    if (newSet.has(schoolId)) {
      newSet.delete(schoolId);
    } else {
      newSet.add(schoolId);
    }
    this.selectedSchoolIds = newSet;
    this._buildMapMarkers();
    this._dispatchCompletionStatus();
  }

  _dispatchCompletionStatus() {
    this.dispatchEvent(
      new CustomEvent('completionchange', {
        detail: {
          complete: this.isStepComplete,
          selectedCount: this.selectedCount
        },
        bubbles: true,
        composed: true
      })
    );
  }

  @api
  validate() {
    if (!this.isStepComplete) {
      this.saveError = labelValidateSelectSchool;
      return false;
    }
    this.saveError = '';
    return true;
  }

  @api
  async flushAndSave() {
    if (this.selectedCount === 0) return;

    this.isSaving = true;
    this.saveError = '';
    try {
      const selections = [];
      for (const schoolId of this.selectedSchoolIds) {
        const school = this._schoolDataMap.get(schoolId);
        if (school) {
          selections.push({
            schoolAccountId: school.schoolAccountId,
            learningProgramId: school.learningProgramId,
            lotteryCapacityId: school.lotteryCapacityId,
            academicTermId: school.academicTermId
          });
        }
      }

      await saveSchoolSelections({
        applicationId: this.recordId,
        selectionsJson: JSON.stringify(selections)
      });
    } catch (err) {
      this.saveError =
        err.body?.message || err.message || labelSaveSchoolsFailed;
      throw err;
    } finally {
      this.isSaving = false;
    }
  }

  async _resolveCentroid(state, postalCode) {
    if (!postalCode) return null;
    const raw = (state || '').trim().toLowerCase();
    if (!raw) return null;
    const stateAbbr = raw.length === 2 ? raw : STATE_ABBR[raw] || null;
    if (!stateAbbr) return null;

    if (!_centroidCache.has(stateAbbr)) {
      try {
        const resp = await fetch(`${ZIP_CENTROIDS}/${stateAbbr}.json`);
        if (!resp.ok) return null;
        _centroidCache.set(stateAbbr, await resp.json());
      } catch (e) {
        return null;
      }
    }

    const zip = postalCode.substring(0, 5);
    const stateData = _centroidCache.get(stateAbbr);
    const coords = stateData?.[zip] || this._findNearestZip(stateData, zip);
    return coords ? { latitude: coords[0], longitude: coords[1] } : null;
  }

  _findNearestZip(stateData, zip) {
    if (!stateData) return null;
    const prefix = zip.substring(0, 3);
    let closest = null;
    let minDiff = Infinity;
    const zipNum = parseInt(zip, 10);
    for (const key of Object.keys(stateData)) {
      if (key.substring(0, 3) === prefix) {
        const diff = Math.abs(parseInt(key, 10) - zipNum);
        if (diff < minDiff) {
          minDiff = diff;
          closest = stateData[key];
        }
      }
    }
    return closest;
  }

  _calculateDistance(lat1, lon1, lat2, lon2) {
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      return null;
    }
    const R = 3959;
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLon = ((lon2 - lon1) * Math.PI) / 180;
    const rLat1 = (lat1 * Math.PI) / 180;
    const rLat2 = (lat2 * Math.PI) / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(rLat1) *
        Math.cos(rLat2) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return Math.round(R * c * 10) / 10;
  }
}