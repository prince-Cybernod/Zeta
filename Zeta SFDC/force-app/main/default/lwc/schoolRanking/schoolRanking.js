import { LightningElement, api } from 'lwc';
import getRankedSchools from '@salesforce/apex/SchoolRankingController.getRankedSchools';
import saveRankings from '@salesforce/apex/SchoolRankingController.saveRankings';
import labelAriaLoadingRankings from '@salesforce/label/c.AppUI_AriaLoadingRankings';
import labelAriaSchoolRankings from '@salesforce/label/c.AppUI_AriaSchoolRankings';
import labelFieldRank from '@salesforce/label/c.AppUI_FieldRank';
import labelRankInfoBanner from '@salesforce/label/c.AppUI_RankInfoBanner';
import labelRankSchools from '@salesforce/label/c.AppUI_RankSchools';
import labelRankSchoolsDesc from '@salesforce/label/c.AppUI_RankSchoolsDesc';
import labelRankSchoolsDrag from '@salesforce/label/c.AppUI_RankSchoolsDrag';
import labelSaveRankingsFailed from '@salesforce/label/c.AppUI_SaveRankingsFailed';
import labelValidateAssignRanks from '@salesforce/label/c.AppUI_ValidateAssignRanks';
import labelValidateNoSchools from '@salesforce/label/c.AppUI_ValidateNoSchools';
import labelValidateUniqueRanks from '@salesforce/label/c.AppUI_ValidateUniqueRanks';

export default class SchoolRanking extends LightningElement {
  @api recordId;

  schools = [];
  isLoading = true;
  isSaving = false;
  saveError = '';
  _dragSourceId = null;
  _touchDragId = null;
  _touchStartY = 0;
  _touchClone = null;
  _touchCurrentTarget = null;

  labels = {
    rankSchools: labelRankSchools,
    rankSchoolsDesc: labelRankSchoolsDesc,
    rankSchoolsDrag: labelRankSchoolsDrag,
    rankInfoBanner: labelRankInfoBanner,
    fieldRank: labelFieldRank,
    ariaLoadingRankings: labelAriaLoadingRankings,
    ariaSchoolRankings: labelAriaSchoolRankings
  };

  get showContent() {
    return !this.isLoading;
  }

  get schoolCount() {
    return this.schools.length;
  }

  get isStepComplete() {
    return this.schools.length > 0 && this.schools.every((s) => s.rank != null);
  }

  get rankedRows() {
    return this.schools.map((school, index) => ({
      ...school,
      position: index + 1,
      rankOptions: this._buildRankOptions(index),
      rowClass: `ranking-row${school._dragClass ? ' ' + school._dragClass : ''}`
    }));
  }

  get singleSchool() {
    return this.schools.length === 1;
  }

  get multipleSchools() {
    return this.schools.length > 1;
  }

  // Joined with an explicit space so "...rank 1." and "Drag to reorder..." don't
  // run together (LWC strips the whitespace between adjacent template bindings).
  get rankSchoolsInstructions() {
    return this.multipleSchools
      ? `${this.labels.rankSchoolsDesc} ${this.labels.rankSchoolsDrag}`
      : this.labels.rankSchoolsDesc;
  }

  connectedCallback() {
    this._loadData();
  }

  async _loadData() {
    try {
      const result = await getRankedSchools({ applicationId: this.recordId });
      this.schools = (result || []).map((s) => ({ ...s }));

      this.schools = this.schools.map((s) => ({
        ...s,
        rank: s.rank != null ? String(s.rank) : null
      }));

      if (this.schools.length === 1 && this.schools[0].rank == null) {
        this.schools = [{ ...this.schools[0], rank: '1' }];
      }

      if (
        this.schools.length > 1 &&
        this.schools.every((s) => s.rank == null)
      ) {
        this.schools = this.schools.map((s, i) => ({
          ...s,
          rank: String(i + 1)
        }));
      }
    } catch (err) {
      console.error('Failed to load ranked schools:', err);
    } finally {
      this.isLoading = false;
      this._dispatchCompletionStatus();
    }
  }

  _buildRankOptions(currentIndex) {
    const usedRanks = new Set();
    this.schools.forEach((s, i) => {
      if (i !== currentIndex && s.rank != null) {
        usedRanks.add(s.rank);
      }
    });

    const options = [];
    for (let i = 1; i <= this.schools.length; i++) {
      const val = String(i);
      options.push({
        label: val,
        value: val,
        disabled: usedRanks.has(val)
      });
    }
    return options;
  }

  handleRankChange(event) {
    const schoolId = event.currentTarget.dataset.id;
    const newRank = Number(event.detail.value);

    const arr = [...this.schools];
    const sourceIdx = arr.findIndex((s) => s.academicInterestId === schoolId);
    const [moved] = arr.splice(sourceIdx, 1);

    const targetIdx = Math.min(Math.max(newRank - 1, 0), arr.length);
    arr.splice(targetIdx, 0, moved);

    this.schools = arr.map((s, i) => ({
      ...s,
      rank: String(i + 1),
      _dragClass: undefined
    }));

    this._dispatchCompletionStatus();
  }

  handleDragStart(event) {
    const id = event.currentTarget.dataset.id;
    this._dragSourceId = id;
    event.dataTransfer.effectAllowed = 'move';
    event.dataTransfer.setData('text/plain', id);
    requestAnimationFrame(() => {
      this.schools = this.schools.map((s) =>
        (s.academicInterestId === id ? { ...s, _dragClass: 'dragging' } : s)
      );
    });
  }

  handleDragOver(event) {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';

    if (!this._dragSourceId) return;

    const row = event.currentTarget;
    const targetId = row.dataset.id;
    if (targetId === this._dragSourceId) return;

    const rect = row.getBoundingClientRect();
    const midY = rect.top + rect.height / 2;
    const isAbove = event.clientY < midY;

    this.schools = this.schools.map((s) => {
      if (s.academicInterestId === targetId) {
        return {
          ...s,
          _dragClass: isAbove ? 'drop-target-above' : 'drop-target-below'
        };
      }
      if (s.academicInterestId === this._dragSourceId) {
        return { ...s, _dragClass: 'dragging' };
      }
      return { ...s, _dragClass: undefined };
    });
  }

  handleDragLeave(event) {
    const targetId = event.currentTarget.dataset.id;
    if (targetId && targetId !== this._dragSourceId) {
      this.schools = this.schools.map((s) => {
        if (s.academicInterestId === targetId) {
          return { ...s, _dragClass: undefined };
        }
        return s;
      });
    }
  }

  handleDragEnd() {
    this._clearDragClasses();
    this._dragSourceId = null;
  }

  handleDrop(event) {
    event.preventDefault();
    const targetId = event.currentTarget.dataset.id;
    if (!this._dragSourceId || this._dragSourceId === targetId) {
      this._clearDragClasses();
      return;
    }

    const rect = event.currentTarget.getBoundingClientRect();
    const midY = rect.top + rect.height / 2;
    const insertBefore = event.clientY < midY;

    this._reorderSchool(this._dragSourceId, targetId, insertBefore);
    this._dragSourceId = null;
  }

  handleTouchStart(event) {
    if (this.singleSchool) return;
    const handle = event.target.closest('.drag-handle');
    if (!handle) return;

    const row = event.currentTarget;
    const id = row.dataset.id;
    this._touchDragId = id;
    this._touchStartY = event.touches[0].clientY;

    const rect = row.getBoundingClientRect();
    const clone = row.cloneNode(true);
    clone.classList.add('touch-ghost');
    clone.style.width = rect.width + 'px';
    clone.style.top = rect.top + 'px';
    clone.style.left = rect.left + 'px';
    this.template.querySelector('.ranking-list').appendChild(clone);
    this._touchClone = clone;

    this.schools = this.schools.map((s) =>
      (s.academicInterestId === id ? { ...s, _dragClass: 'dragging' } : s)
    );
  }

  handleTouchMove(event) {
    if (!this._touchDragId) return;
    event.preventDefault();

    const touch = event.touches[0];
    const deltaY = touch.clientY - this._touchStartY;

    if (this._touchClone) {
      this._touchClone.style.transform = `translateY(${deltaY}px)`;
    }

    const row = this._findRowAtPoint(touch.clientX, touch.clientY);
    if (!row) return;

    const targetId = row.dataset.id;
    if (!targetId || targetId === this._touchDragId) {
      if (this._touchCurrentTarget && this._touchCurrentTarget !== targetId) {
        this._clearNonDragClasses();
      }
      this._touchCurrentTarget = targetId;
      return;
    }

    this._touchCurrentTarget = targetId;
    const rect = row.getBoundingClientRect();
    const midY = rect.top + rect.height / 2;
    const isAbove = touch.clientY < midY;

    this.schools = this.schools.map((s) => {
      if (s.academicInterestId === targetId) {
        return {
          ...s,
          _dragClass: isAbove ? 'drop-target-above' : 'drop-target-below'
        };
      }
      if (s.academicInterestId === this._touchDragId) {
        return { ...s, _dragClass: 'dragging' };
      }
      return { ...s, _dragClass: undefined };
    });
  }

  handleTouchCancel() {
    if (!this._touchDragId) return;

    if (this._touchClone) {
      this._touchClone.remove();
      this._touchClone = null;
    }

    this._clearDragClasses();
    this._touchDragId = null;
    this._touchCurrentTarget = null;
  }

  handleTouchEnd() {
    if (!this._touchDragId) return;

    if (this._touchClone) {
      this._touchClone.remove();
      this._touchClone = null;
    }

    if (
      this._touchCurrentTarget &&
      this._touchCurrentTarget !== this._touchDragId
    ) {
      const targetSchool = this.schools.find(
        (s) => s.academicInterestId === this._touchCurrentTarget
      );
      const insertBefore = targetSchool?._dragClass === 'drop-target-above';
      this._reorderSchool(
        this._touchDragId,
        this._touchCurrentTarget,
        insertBefore
      );
    } else {
      this._clearDragClasses();
    }

    this._touchDragId = null;
    this._touchCurrentTarget = null;
  }

  _reorderSchool(sourceId, targetId, insertBefore) {
    const arr = [...this.schools];
    const sourceIdx = arr.findIndex((s) => s.academicInterestId === sourceId);
    const [moved] = arr.splice(sourceIdx, 1);

    let targetIdx = arr.findIndex((s) => s.academicInterestId === targetId);
    if (!insertBefore) {
      targetIdx += 1;
    }

    arr.splice(targetIdx, 0, moved);

    this.schools = arr.map((s, i) => ({
      ...s,
      rank: String(i + 1),
      _dragClass: undefined
    }));

    this._dispatchCompletionStatus();
  }

  _findRowAtPoint(x, y) {
    const rows = this.template.querySelectorAll('.ranking-row');
    for (const row of rows) {
      if (row.dataset.id === this._touchDragId) continue;
      const rect = row.getBoundingClientRect();
      if (
        y >= rect.top &&
        y <= rect.bottom &&
        x >= rect.left &&
        x <= rect.right
      ) {
        return row;
      }
    }
    return null;
  }

  _clearDragClasses() {
    this.schools = this.schools.map((s) => ({ ...s, _dragClass: undefined }));
  }

  _clearNonDragClasses() {
    this.schools = this.schools.map((s) => {
      if (s.academicInterestId === this._touchDragId) return s;
      return { ...s, _dragClass: undefined };
    });
  }

  _dispatchCompletionStatus() {
    this.dispatchEvent(
      new CustomEvent('completionchange', {
        detail: {
          complete: this.isStepComplete,
          schoolCount: this.schoolCount
        },
        bubbles: true,
        composed: true
      })
    );
  }

  @api
  validate() {
    if (this.schools.length === 0) {
      this.saveError = labelValidateNoSchools;
      return false;
    }
    if (!this.isStepComplete) {
      this.saveError = labelValidateAssignRanks;
      return false;
    }

    const ranks = this.schools.map((s) => s.rank);
    const uniqueRanks = new Set(ranks);
    if (uniqueRanks.size !== ranks.length) {
      this.saveError = labelValidateUniqueRanks;
      return false;
    }

    this.saveError = '';
    return true;
  }

  @api
  async flushAndSave() {
    if (this.schools.length === 0) return;

    this.isSaving = true;
    this.saveError = '';
    try {
      const rankings = this.schools.map((s) => ({
        academicInterestId: s.academicInterestId,
        rank: Number(s.rank)
      }));

      await saveRankings({
        applicationId: this.recordId,
        rankingsJson: JSON.stringify(rankings)
      });
    } catch (err) {
      this.saveError =
        err.body?.message || err.message || labelSaveRankingsFailed;
      throw err;
    } finally {
      this.isSaving = false;
    }
  }
}