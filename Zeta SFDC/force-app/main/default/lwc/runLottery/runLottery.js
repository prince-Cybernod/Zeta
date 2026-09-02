import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import assignPreOffers from '@salesforce/apex/RunLotteryController.assignPreOffers';
import assignPreOffersBatch from '@salesforce/apex/RunLotteryController.assignPreOffersBatch';
import createAuditRecordsBatch from '@salesforce/apex/RunLotteryController.createAuditRecordsBatch';
import finalizeLottery from '@salesforce/apex/RunLotteryController.finalizeLottery';
import finalizeLotteryBatch from '@salesforce/apex/RunLotteryController.finalizeLotteryBatch';
import getCapacityStats from '@salesforce/apex/RunLotteryController.getCapacityStats';
import getResults from '@salesforce/apex/RunLotteryController.getResults';
import getUnrunCapacities from '@salesforce/apex/RunLotteryController.getUnrunCapacities';
import initializeLottery from '@salesforce/apex/RunLotteryController.initializeLottery';
import optimizeOffers from '@salesforce/apex/RunLotteryController.optimizeOffers';
import optimizeOffersBatch from '@salesforce/apex/RunLotteryController.optimizeOffersBatch';
import publishLotteryRun from '@salesforce/apex/RunLotteryController.publishLotteryRun';
import randomizeApplications from '@salesforce/apex/RunLotteryController.randomizeApplications';
import randomizeApplicationsBatch from '@salesforce/apex/RunLotteryController.randomizeApplicationsBatch';
import releaseLotteryLock from '@salesforce/apex/RunLotteryController.releaseLotteryLock';
import runLottery from '@salesforce/apex/RunLotteryController.runLottery';
import APPLICATION_CLOSE_DATE from '@salesforce/schema/ApplicationTimeline.ApplicationCloseDate';
import APPLICATION_OPEN_DATE from '@salesforce/schema/ApplicationTimeline.ApplicationOpenDate';
import { ErrorHandler } from 'c/errorHandler';

const SCHOOL_STATS_COLUMNS = [
  { label: 'School', fieldName: 'schoolName', type: 'text' },
  { label: 'Grade', fieldName: 'grade', type: 'text' },
  { label: 'Seats Available', fieldName: 'seatsAvailable', type: 'number' },
  { label: 'Offers Made', fieldName: 'offersMade', type: 'number' },
  { label: 'Waitlisted', fieldName: 'waitlisted', type: 'number' }
];

const PRE_RUN_STATS_COLUMNS = [
  { label: 'School', fieldName: 'schoolName', type: 'text' },
  { label: 'Grade', fieldName: 'grade', type: 'text' },
  { label: 'Seats Available', fieldName: 'availableSeats', type: 'number' },
  { label: 'Applications', fieldName: 'applicationCount', type: 'number' }
];

const STEPS = {
  CONFIGURE: 'configure',
  EXECUTE: 'execute',
  REVIEW: 'review'
};

const EXECUTION_STEPS = {
  INITIALIZE: {
    id: 'initialize',
    label: 'Initializing',
    icon: 'utility:setup',
    message: 'Acquiring lock and creating run log...'
  },
  RANDOMIZE: {
    id: 'randomize',
    label: 'Randomizing',
    icon: 'utility:sort',
    message: 'Assigning random sort keys to applications...'
  },
  ASSIGN: {
    id: 'assign',
    label: 'Assigning Offers',
    icon: 'utility:assignment',
    message: 'Making pre-offers within capacity...'
  },
  OPTIMIZE: {
    id: 'optimize',
    label: 'Optimizing',
    icon: 'utility:filter',
    message: 'Optimizing offers (one per student)...'
  },
  FINALIZE: {
    id: 'finalize',
    label: 'Finalizing',
    icon: 'utility:check',
    message: 'Assigning waitlist status and releasing lock...'
  },
  OPTIMIZE_ALL: {
    id: 'optimize_all',
    label: 'Optimizing',
    icon: 'utility:filter',
    message: 'Optimizing offers across all grades...'
  },
  FINALIZE_ALL: {
    id: 'finalize_all',
    label: 'Finalizing',
    icon: 'utility:check',
    message: 'Finalizing waitlist across all grades...'
  }
};

const MIN_STEP_DISPLAY_MS = 700;

// Batch size for chunked lottery execution (keyset pagination)
const LOTTERY_BATCH_SIZE = 200;

const DEFAULT_STEP_PROGRESS_RANGES = {
  INITIALIZE: { start: 0, end: 20 },
  RANDOMIZE: { start: 20, end: 40 },
  ASSIGN: { start: 40, end: 60 },
  OPTIMIZE: { start: 60, end: 80 },
  FINALIZE: { start: 80, end: 100 }
};

/**
 * Three-layer progress animation system:
 * Layer 1: Target Progress - actual batch completions
 * Layer 2: Animated Progress - smooth interpolation via requestAnimationFrame
 * Layer 3: Trickle Progress - slow advance during Apex calls
 */
class ProgressAnimator {
  constructor(onUpdate) {
    this.onUpdate = onUpdate;
    this.target = 0;
    this.current = 0;
    this.animationId = null;
    this.trickling = false;
    this.trickleCeiling = 0;
    this.lastFrameTime = 0;
  }

  /**
   * Set the target progress value and animate toward it.
   */
  setTarget(value) {
    this.target = value;
    this.stopTrickle();
    this._startAnimation();
  }

  /**
   * Start trickle mode - slowly advance during Apex calls.
   * @param {number} ceiling - Maximum value trickle can reach (typically 70% toward next target)
   */
  startTrickle(ceiling) {
    this.trickling = true;
    this.trickleCeiling = ceiling;
    this._startAnimation();
  }

  /**
   * Stop trickle mode without stopping animation.
   */
  stopTrickle() {
    this.trickling = false;
  }

  /**
   * Stop all animation.
   */
  stop() {
    this.trickling = false;
    if (this.animationId) {
      window.cancelAnimationFrame(this.animationId);
      this.animationId = null;
    }
  }

  /**
   * Reset to initial state.
   */
  reset() {
    this.stop();
    this.target = 0;
    this.current = 0;
    this.trickleCeiling = 0;
    this.onUpdate(0);
  }

  /**
   * Internal: Start the animation loop if not already running.
   */
  _startAnimation() {
    if (this.animationId) return;
    this.lastFrameTime = performance.now();
    this._animate();
  }

  /**
   * Internal: Animation frame callback.
   */
  _animate() {
    const now = performance.now();
    const deltaMs = now - this.lastFrameTime;
    this.lastFrameTime = now;

    let needsUpdate = false;
    const easeFactor = Math.min(1, deltaMs / 150); // Smooth ~150ms easing

    if (this.trickling && this.current < this.trickleCeiling) {
      // Trickle: slow exponential approach (2% of remaining per frame, capped)
      const remaining = this.trickleCeiling - this.current;
      const trickleAmount = Math.max(0.02, remaining * 0.02 * easeFactor);
      this.current = Math.min(
        this.current + trickleAmount,
        this.trickleCeiling
      );
      needsUpdate = true;
    } else if (this.current < this.target) {
      // Animate toward target: ease at ~15% of distance per frame
      const distance = this.target - this.current;
      const step = Math.max(0.1, distance * 0.15 * easeFactor);
      this.current = Math.min(this.current + step, this.target);
      needsUpdate = true;
    }

    if (needsUpdate) {
      this.onUpdate(this.current);
      this.animationId = window.requestAnimationFrame(() => this._animate());
    } else {
      this.animationId = null;
    }
  }
}

export default class RunLottery extends NavigationMixin(LightningElement) {
  _timelineId;

  @api
  set recordId(value) {
    if (value) this._timelineId = value;
  }
  get recordId() {
    return this._timelineId;
  }

  @wire(CurrentPageReference)
  handlePageRef(pageRef) {
    if (pageRef?.state?.c__timelineId) {
      this._timelineId = pageRef.state.c__timelineId;
    }
  }

  capacities = [];
  isLoading = true;
  error;
  runResponse;
  isPublished = false;
  isPublishing = false;
  showConfetti = false;
  confettiPieces = [];
  _confettiTimerId;
  _hasAutoScrolled = false;
  schoolStatsColumns = SCHOOL_STATS_COLUMNS;
  currentStep = STEPS.CONFIGURE;
  selectedSchoolIds = new Set();

  startDate;
  endDate;
  showConfirmationModal = false;
  runLogUrl;
  wiredCapacitiesResult;
  preRunStats = [];
  isLoadingStats = false;

  executionStep = null;
  executionMessage = '';
  executionIcon = 'utility:spinner';
  jobId = null;
  executionProgress = 0;

  // Progress animation
  progressAnimator = null;
  stepProgressRanges = DEFAULT_STEP_PROGRESS_RANGES;
  gradeProgressRanges = {};
  totalApplicationCount = 0;
  estimatedBatchCounts = {};

  // Grade-centric execution state
  currentGrade = null;
  currentGradeStep = null; // 'RANDOMIZE', 'ASSIGN', 'OPTIMIZE', 'FINALIZE'
  completedGrades = [];
  selectedGrades = [];
  assignedGrades = []; // Grades that completed Phase A (Randomize + Assign)

  // Phased execution state: 'PHASE_A' | 'PHASE_B' | 'PHASE_C' | null
  executionPhase = null;
  crossGradeProgressRanges = {}; // Progress ranges for Phase B/C

  connectedCallback() {
    this.progressAnimator = new ProgressAnimator((value) => {
      this.executionProgress = value;
    });
  }

  disconnectedCallback() {
    if (this.progressAnimator) {
      this.progressAnimator.stop();
    }
    if (this._confettiTimerId) {
      clearTimeout(this._confettiTimerId);
    }
  }

  renderedCallback() {
    if (
      this._hasAutoScrolled ||
      this.currentStep !== STEPS.REVIEW ||
      !this.runResponse
    ) {
      return;
    }
    this._hasAutoScrolled = true;
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => this.autoScrollTable(), 1200);
  }

  autoScrollTable() {
    const container = this.template.querySelector('.school-stats-scroll');
    if (!container || container.scrollHeight <= container.clientHeight) {
      return;
    }

    const distance = container.scrollHeight - container.clientHeight;
    const duration = Math.max(3000, distance * 15);
    const start = performance.now();

    const step = (now) => {
      const elapsed = now - start;
      const t = Math.min(elapsed / duration, 1);
      // Ease in-out cubic
      const eased = t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
      container.scrollTop = eased * distance;
      if (t < 1) {
        requestAnimationFrame(step);
      }
    };
    requestAnimationFrame(step);
  }

  /**
   * Grade sort order: TK < PK < K < 1-12
   */
  gradeOrder(grade) {
    if (grade === 'TK') return -2;
    if (grade === 'PK' || grade === 'Pre-K' || grade === 'PreK') return -1;
    if (grade === 'K') return 0;
    const num = parseInt(grade, 10);
    return isNaN(num) ? 999 : num;
  }

  /**
   * Extract unique grades from selected capacities, sorted in grade order.
   */
  getGradesFromCapacities(capacityIds) {
    const gradeSet = new Set();
    for (const cap of this.capacities) {
      if (capacityIds.includes(cap.Id) && cap.Grade__c) {
        gradeSet.add(cap.Grade__c);
      }
    }
    return Array.from(gradeSet).sort(
      (a, b) => this.gradeOrder(a) - this.gradeOrder(b)
    );
  }

  /**
   * Get capacity IDs for a specific grade from the selected set.
   */
  getCapacityIdsForGrade(grade, capacityIds) {
    return this.capacities
      .filter((cap) => capacityIds.includes(cap.Id) && cap.Grade__c === grade)
      .map((cap) => cap.Id);
  }

  /**
   * Get application count for a specific grade from preRunStats.
   */
  getApplicationCountForGrade(grade) {
    return this.preRunStats
      .filter((stat) => stat.grade === grade)
      .reduce((sum, stat) => sum + (stat.applicationCount || 0), 0);
  }

  /**
   * Phase detection getters
   */
  get isPhaseA() {
    return this.executionPhase === 'PHASE_A';
  }

  get isPhaseB() {
    return this.executionPhase === 'PHASE_B';
  }

  get isPhaseC() {
    return this.executionPhase === 'PHASE_C';
  }

  get isCrossGradePhase() {
    return this.isPhaseB || this.isPhaseC;
  }

  get crossGradePhaseLabel() {
    if (this.isPhaseB) return 'Optimizing';
    if (this.isPhaseC) return 'Finalizing';
    return 'Processing';
  }

  get crossGradeIcon() {
    if (this.isPhaseB) return 'utility:filter';
    if (this.isPhaseC) return 'utility:check';
    return 'utility:spinner';
  }

  /**
   * Number of assigned grades (completed Phase A but not fully complete).
   */
  get gradesAssigned() {
    return this.assignedGrades.length;
  }

  /**
   * Grade queue for template - array of objects with grade, status, and CSS class.
   */
  get gradeQueue() {
    return this.selectedGrades.map((grade) => {
      let status = 'pending';
      let badgeClass = 'grade-badge grade-badge-pending';

      if (this.completedGrades.includes(grade)) {
        status = 'completed';
        badgeClass = 'grade-badge grade-badge-completed';
      } else if (this.assignedGrades.includes(grade)) {
        // Phase A complete for this grade, waiting for Phase B/C
        status = 'assigned';
        badgeClass = 'grade-badge grade-badge-assigned';
      } else if (this.currentGrade === grade) {
        status = 'active';
        badgeClass = 'grade-badge grade-badge-active';
      }

      const appCount = this.getApplicationCountForGrade(grade);

      return {
        grade,
        status,
        badgeClass,
        isCompleted: status === 'completed',
        isAssigned: status === 'assigned',
        isActive: status === 'active',
        isPending: status === 'pending',
        applicationCount: appCount,
        showCount: status === 'pending' || status === 'active'
      };
    });
  }

  /**
   * Step dots for the current grade - used with lightning-progress-indicator.
   * During Phase A: only shows Randomize and Assign (2 steps).
   */
  get gradeStepDots() {
    // Phase A: only 2 steps per grade
    const steps = ['RANDOMIZE', 'ASSIGN'];
    const currentIdx = steps.indexOf(this.currentGradeStep);

    return steps.map((step, idx) => {
      const stepInfo = EXECUTION_STEPS[step];
      return {
        id: step,
        label: stepInfo?.label?.replace('ing', '') || step,
        isComplete: idx < currentIdx,
        isCurrent: idx === currentIdx
      };
    });
  }

  /**
   * Current step value for lightning-progress-indicator.
   */
  get currentStepValue() {
    return this.currentGradeStep || 'RANDOMIZE';
  }

  /**
   * Number of completed grades.
   */
  get gradesCompleted() {
    return this.completedGrades.length;
  }

  /**
   * Total number of grades to process.
   */
  get totalGrades() {
    return this.selectedGrades.length;
  }

  /**
   * Whether we're in grade-centric execution mode.
   */
  get isGradeCentricExecution() {
    return this.currentStep === STEPS.EXECUTE && this.selectedGrades.length > 0;
  }

  /**
   * Current action label for display (e.g., "Assigning offers").
   */
  get currentActionLabel() {
    if (!this.currentGradeStep) return 'Processing';
    const stepInfo = EXECUTION_STEPS[this.currentGradeStep];
    return stepInfo?.label || 'Processing';
  }

  get executionStepInfo() {
    if (!this.executionStep) {
      return null;
    }
    return EXECUTION_STEPS[this.executionStep] || null;
  }

  /**
   * Calculate dynamic step ranges based on application count and grade count.
   * Phased execution:
   *   - Initialize: 5%
   *   - Phase A (Randomize + Assign per grade): 60%
   *   - Phase B (Optimize all): 20%
   *   - Phase C (Finalize all): 15%
   */
  calculateStepRanges(totalApplications, gradeCount = 1) {
    if (!totalApplications || totalApplications <= 0) {
      this.stepProgressRanges = DEFAULT_STEP_PROGRESS_RANGES;
      this.estimatedBatchCounts = {};
      return;
    }

    this.totalApplicationCount = totalApplications;

    // Estimate batch counts for each step (per grade, roughly equal distribution)
    const batchSize = LOTTERY_BATCH_SIZE;
    const appsPerGrade = Math.ceil(totalApplications / gradeCount);
    const estimatedBatches = {
      INITIALIZE: 1, // Not batched
      RANDOMIZE: Math.ceil(appsPerGrade / batchSize),
      ASSIGN: Math.ceil(appsPerGrade / batchSize),
      OPTIMIZE: Math.ceil(totalApplications / batchSize), // All grades
      FINALIZE: Math.ceil(totalApplications / batchSize) // All grades
    };
    this.estimatedBatchCounts = estimatedBatches;

    // Progress allocation:
    // Initialize: 5%, Phase A: 60%, Phase B: 20%, Phase C: 15%
    const initWeight = 5;
    const phaseAWeight = 60; // Randomize + Assign per grade
    const phaseBWeight = 20; // Optimize all
    const phaseCWeight = 15; // Finalize all

    const phaseAStart = initWeight;
    const phaseAEnd = initWeight + phaseAWeight;
    const phaseBStart = phaseAEnd;
    const phaseBEnd = phaseBStart + phaseBWeight;
    const phaseCStart = phaseBEnd;
    const phaseCEnd = 100;

    // Build ranges object
    const ranges = {
      INITIALIZE: { start: 0, end: initWeight }
    };

    // Phase A: Each grade gets equal slice of 60%, with 2 steps per grade
    this.gradeProgressRanges = {};
    const gradeWeight = phaseAWeight / gradeCount;
    for (let g = 0; g < gradeCount; g++) {
      const gradeStart = phaseAStart + g * gradeWeight;
      const gradeEnd = gradeStart + gradeWeight;

      // Within grade, 2 steps (Randomize, Assign) get equal slices
      const stepWeight = gradeWeight / 2;
      this.gradeProgressRanges[g] = {
        RANDOMIZE: { start: gradeStart, end: gradeStart + stepWeight },
        ASSIGN: { start: gradeStart + stepWeight, end: gradeEnd }
      };
    }

    // Phase B/C: Cross-grade progress ranges
    this.crossGradeProgressRanges = {
      OPTIMIZE_ALL: { start: phaseBStart, end: phaseBEnd },
      FINALIZE_ALL: { start: phaseCStart, end: phaseCEnd }
    };

    // Keep global step ranges for fallback/non-grade-centric operations
    ranges.RANDOMIZE = { start: initWeight, end: initWeight + 23.75 };
    ranges.ASSIGN = { start: initWeight + 23.75, end: initWeight + 47.5 };
    ranges.OPTIMIZE = { start: initWeight + 47.5, end: initWeight + 71.25 };
    ranges.FINALIZE = { start: initWeight + 71.25, end: 100 };
    ranges.OPTIMIZE_ALL = { start: phaseBStart, end: phaseBEnd };
    ranges.FINALIZE_ALL = { start: phaseCStart, end: phaseCEnd };

    this.stepProgressRanges = ranges;
  }

  /**
   * Get progress range for a step within a specific grade index.
   */
  getGradeStepRange(gradeIndex, stepKey) {
    if (this.gradeProgressRanges && this.gradeProgressRanges[gradeIndex]) {
      return this.gradeProgressRanges[gradeIndex][stepKey];
    }
    // Fallback to global ranges
    return this.stepProgressRanges[stepKey];
  }

  /**
   * Set progress to the start of a step's range.
   */
  startStepProgress(stepKey) {
    const range = this.stepProgressRanges[stepKey];
    if (range && this.progressAnimator) {
      this.progressAnimator.setTarget(range.start);
    }
  }

  /**
   * Set progress to the end of a step's range.
   */
  completeStepProgress(stepKey) {
    const range = this.stepProgressRanges[stepKey];
    if (range && this.progressAnimator) {
      this.progressAnimator.setTarget(range.end);
    }
  }

  /**
   * Calculate target progress for a batch within a step.
   * Uses linear progress when batch count is known, gentler asymptotic fallback otherwise.
   */
  calculateBatchTarget(range, batchNumber, estimatedTotal) {
    if (estimatedTotal && estimatedTotal > 0) {
      // Linear: each batch gets an equal slice of the range
      const fractionComplete = Math.min(batchNumber / estimatedTotal, 1);
      return range.start + (range.end - range.start) * fractionComplete;
    }
    // Fallback: gentler asymptotic curve (1/(n+2)) for unknown totals
    const progress =
      range.start + (range.end - range.start) * (1 - 1 / (batchNumber + 2));
    return Math.min(progress, range.end - 1);
  }

  /**
   * Update progress within a step based on batch completion.
   * Uses linear progress when batch count is known.
   */
  updateBatchProgress(stepKey, batchNumber) {
    const range = this.stepProgressRanges[stepKey];
    if (!range || !this.progressAnimator) return;

    const estimatedBatches = this.estimatedBatchCounts[stepKey] || 0;
    const target = this.calculateBatchTarget(
      range,
      batchNumber,
      estimatedBatches
    );
    this.progressAnimator.setTarget(target);
  }

  /**
   * Start trickle mode before an Apex call.
   * Ceiling is ~70% toward the next expected batch target.
   */
  startTrickleBeforeApex(stepKey, nextBatchNumber) {
    const range = this.stepProgressRanges[stepKey];
    if (!range || !this.progressAnimator) return;

    const estimatedBatches = this.estimatedBatchCounts[stepKey] || 0;
    const nextTarget = this.calculateBatchTarget(
      range,
      nextBatchNumber,
      estimatedBatches
    );
    // Trickle ceiling: 70% of the way from current to next target
    const current = this.progressAnimator.current;
    const ceiling = current + (nextTarget - current) * 0.7;
    this.progressAnimator.startTrickle(ceiling);
  }

  get showExecutionProgress() {
    return (
      this.isLoading && this.currentStep === STEPS.EXECUTE && this.executionStep
    );
  }

  get steps() {
    return [
      {
        label: 'Configure',
        value: STEPS.CONFIGURE,
        isActive: this.currentStep === STEPS.CONFIGURE,
        isCompleted:
          this.currentStep === STEPS.EXECUTE ||
          this.currentStep === STEPS.REVIEW
      },
      {
        label: 'Execute',
        value: STEPS.EXECUTE,
        isActive: this.currentStep === STEPS.EXECUTE,
        isCompleted: this.currentStep === STEPS.REVIEW
      },
      {
        label: 'Review & Publish',
        value: STEPS.REVIEW,
        isActive: this.currentStep === STEPS.REVIEW,
        isCompleted: this.isPublished
      }
    ];
  }

  get isConfigureStep() {
    return this.currentStep === STEPS.CONFIGURE;
  }

  get isExecuteStep() {
    return this.currentStep === STEPS.EXECUTE;
  }

  get isReviewStep() {
    return this.currentStep === STEPS.REVIEW;
  }

  @wire(getUnrunCapacities, { applicationTimelineId: '$_timelineId' })
  wiredCapacities(result) {
    this.wiredCapacitiesResult = result;
    this.isLoading = false;
    const { data, error } = result;

    if (data) {
      this.capacities = data.map((capacity) => ({
        ...capacity,
        schoolId:
          capacity.Program_Term_Application_Timeline__r?.LearningProgram
            ?.School__c || 'unknown',
        schoolName:
          capacity.Program_Term_Application_Timeline__r?.LearningProgram
            ?.School__r?.Zeta_School_Name__c || 'Unknown School'
      }));
      this.error = undefined;
    } else if (error) {
      this.error = ErrorHandler.parse(error).messages.join(', ');
      this.capacities = [];
    }
  }

  @wire(getRecord, {
    recordId: '$_timelineId',
    fields: [APPLICATION_OPEN_DATE, APPLICATION_CLOSE_DATE]
  })
  wiredTimeline({ data }) {
    if (data) {
      // Only set defaults if user hasn't manually entered dates
      if (!this.startDate) {
        this.startDate = getFieldValue(data, APPLICATION_OPEN_DATE);
      }
      if (!this.endDate) {
        this.endDate = getFieldValue(data, APPLICATION_CLOSE_DATE);
      }
    }
  }

  get showContent() {
    return !this.error;
  }

  get showExecutionState() {
    return this.isLoading && this.currentStep === STEPS.EXECUTE;
  }

  get showCapacitySelection() {
    return !this.runResponse && !this.showExecutionState;
  }

  get showResults() {
    return !!this.runResponse;
  }

  get hasSchools() {
    return this.schools.length > 0;
  }

  get schoolStats() {
    const records =
      this.runResponse?.allResults || this.runResponse?.results || [];
    if (!records.length) {
      return [];
    }

    const statsMap = new Map();

    for (const row of records) {
      const schoolKey = row.schoolId || 'unknown';
      const grade = row.grade || 'Unknown';
      const key = `${schoolKey}|${grade}`;

      if (!statsMap.has(key)) {
        statsMap.set(key, {
          id: key,
          schoolId: schoolKey,
          schoolName: row.schoolName || 'Unknown School',
          grade: grade,
          seatsAvailable: row.seatsAvailable || 0,
          offersMade: 0,
          waitlisted: 0
        });
      }
      const stats = statsMap.get(key);
      if (row.status === 'Pre-Offer' || row.status === 'Seat Offered') {
        stats.offersMade++;
      } else if (row.status === 'Waitlisted') {
        stats.waitlisted++;
      }
    }

    // Sort by school name, then by grade (handling K, PreK, and numeric grades)
    return Array.from(statsMap.values()).sort((a, b) => {
      const schoolCompare = a.schoolName.localeCompare(b.schoolName);
      if (schoolCompare !== 0) {
        return schoolCompare;
      }
      // Sort grades: PreK < K < numeric grades
      const gradeOrder = (g) => {
        if (g === 'PreK' || g === 'Pre-K') return -1;
        if (g === 'K') return 0;
        const num = parseInt(g, 10);
        return isNaN(num) ? 999 : num;
      };
      return gradeOrder(a.grade) - gradeOrder(b.grade);
    });
  }

  get hasSchoolStats() {
    return this.schoolStats.length > 0;
  }

  get preRunStatsColumns() {
    return PRE_RUN_STATS_COLUMNS;
  }

  get hasPreRunStats() {
    return this.preRunStats.length > 0;
  }

  get hasZeroOffers() {
    return this.runResponse && this.runResponse.preOffersAssigned === 0;
  }

  get heroMetricClass() {
    return this.hasZeroOffers
      ? 'hero-metric-value slds-text-color_weak'
      : 'hero-metric-value slds-text-color_success';
  }

  get zeroOffersMessage() {
    if (!this.hasZeroOffers) {
      return null;
    }
    if (this.runResponse.totalEligible === 0) {
      return 'No eligible applicants found for the selected grades';
    }
    return 'All eligible applicants were waitlisted';
  }

  get schools() {
    const schoolMap = new Map();

    this.capacities.forEach((cap) => {
      const { schoolId, schoolName } = cap;

      if (!schoolMap.has(schoolId)) {
        schoolMap.set(schoolId, {
          id: schoolId,
          name: schoolName,
          capacityIds: [],
          grades: new Set(),
          totalSeats: 0
        });
      }

      const school = schoolMap.get(schoolId);
      school.capacityIds.push(cap.Id);
      school.grades.add(cap.Grade__c);
      school.totalSeats += cap.Total_Available_Seats__c || 0;
    });

    return [...schoolMap.values()]
      .sort((a, b) => a.name.localeCompare(b.name))
      .map((school) => ({
        ...school,
        gradeCount: school.grades.size,
        selected: this.selectedSchoolIds.has(school.id)
      }));
  }

  get selectedCapacityIds() {
    const ids = [];
    this.schools
      .filter((s) => s.selected)
      .forEach((school) => {
        ids.push(...school.capacityIds);
      });
    return ids;
  }

  get allSelected() {
    return this.schools.length > 0 && this.schools.every((s) => s.selected);
  }

  get runButtonDisabled() {
    return this.isLoading || this.selectedCapacityIds.length === 0;
  }

  get canPublish() {
    return this.runResponse?.runLogId && !this.isPublished;
  }

  get confirmationSummary() {
    const selectedSchools = this.schools.filter((s) => s.selected);
    let totalSeats = 0;
    const uniqueGrades = new Set();

    selectedSchools.forEach((school) => {
      totalSeats += school.totalSeats;
      // Get grades for this school and add to overall set
      this.capacities
        .filter((c) => c.schoolId === school.id)
        .forEach((c) => uniqueGrades.add(c.Grade__c));
    });

    return {
      capacityCount: uniqueGrades.size,
      schoolCount: selectedSchools.length,
      totalSeats
    };
  }

  get confirmationCapacityList() {
    return this.schools
      .filter((s) => s.selected)
      .map((school) => {
        const grades = this.capacities
          .filter((c) => c.schoolId === school.id)
          .map((c) => c.Grade__c)
          .join(', ');
        return { school: school.name, grades };
      });
  }

  handleSchoolSelect(event) {
    const schoolId = event.target.dataset.schoolId;
    const checked = event.target.checked;

    if (checked) {
      this.selectedSchoolIds.add(schoolId);
    } else {
      this.selectedSchoolIds.delete(schoolId);
    }
    this.selectedSchoolIds = new Set(this.selectedSchoolIds);
  }

  handleSchoolBoxClick(event) {
    // Don't toggle if click originated from the checkbox itself
    const target = event.target;
    if (target.tagName === 'INPUT' || target.closest('lightning-input')) {
      return;
    }

    const schoolId = event.currentTarget.dataset.schoolId;
    if (this.selectedSchoolIds.has(schoolId)) {
      this.selectedSchoolIds.delete(schoolId);
    } else {
      this.selectedSchoolIds.add(schoolId);
    }
    this.selectedSchoolIds = new Set(this.selectedSchoolIds);
  }

  handleSelectAll(event) {
    const checked = event.target.checked;
    if (checked) {
      this.selectedSchoolIds = new Set(this.schools.map((s) => s.id));
    } else {
      this.selectedSchoolIds = new Set();
    }
  }

  handleStartDateChange(event) {
    this.startDate = event.target.value;
  }

  handleEndDateChange(event) {
    this.endDate = event.target.value;
  }

  async handleRunLottery() {
    if (this.selectedCapacityIds.length === 0) {
      return;
    }

    this.isLoadingStats = true;
    this.preRunStats = [];
    this.showConfirmationModal = true;

    try {
      const stats = await getCapacityStats({
        capacityIds: this.selectedCapacityIds,
        startDate: this.startDate || null,
        endDate: this.endDate || null
      });
      this.preRunStats = stats.map((stat) => ({
        ...stat,
        id: stat.capacityId
      }));
    } catch (error) {
      const parsed = ErrorHandler.parse(error);
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Error loading statistics',
          message: parsed.messages.join(', '),
          variant: 'error'
        })
      );
    } finally {
      this.isLoadingStats = false;
    }
  }

  handleCancelConfirmation() {
    this.showConfirmationModal = false;
  }

  sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  async executeStepWithMinDisplay(stepKey, apexCall) {
    this.executionStep = stepKey;
    this.startStepProgress(stepKey);
    const startTime = Date.now();

    const result = await apexCall;

    // Ensure minimum display time for UX
    const elapsed = Date.now() - startTime;
    if (elapsed < MIN_STEP_DISPLAY_MS) {
      await this.sleep(MIN_STEP_DISPLAY_MS - elapsed);
    }

    this.completeStepProgress(stepKey);
    return result;
  }

  /**
   * Execute a step in batches using keyset/cursor-based pagination.
   * Progress bar fills incrementally as each batch completes with trickle during Apex calls.
   * @param {string} stepKey - Key from EXECUTION_STEPS
   * @param {function} apexCallFn - Function that takes (lastRecordId, batchSize) and returns promise
   * @returns {object} Aggregated result with total counts
   */
  async executeBatchedStep(stepKey, apexCallFn) {
    this.executionStep = stepKey;
    this.startStepProgress(stepKey);
    const startTime = Date.now();

    let lastRecordId = null;
    let batchNumber = 0;
    let hasMore = true;
    const aggregatedResult = {
      processedCount: 0,
      preOfferCount: 0,
      rescindedCount: 0,
      waitlistCount: 0,
      eventsPublished: 0
    };

    while (hasMore) {
      batchNumber++;
      const stepInfo = EXECUTION_STEPS[stepKey];
      this.executionMessage = `${stepInfo?.label || stepKey}: Batch ${batchNumber}...`;

      // Start trickle before Apex call
      this.startTrickleBeforeApex(stepKey, batchNumber);

      // eslint-disable-next-line no-await-in-loop -- Sequential batch pagination requires await in loop
      const result = await apexCallFn(lastRecordId, LOTTERY_BATCH_SIZE);

      // Check for errors
      if (result.isSuccess === false) {
        if (this.progressAnimator) {
          this.progressAnimator.stopTrickle();
        }
        throw new Error(result.errorMessage || 'Batch execution failed');
      }

      // Stop trickle and update to actual progress
      this.updateBatchProgress(stepKey, batchNumber);

      // Aggregate counts
      aggregatedResult.processedCount += result.processedCount || 0;
      aggregatedResult.preOfferCount += result.preOfferCount || 0;
      aggregatedResult.rescindedCount += result.rescindedCount || 0;
      aggregatedResult.waitlistCount += result.waitlistCount || 0;
      aggregatedResult.eventsPublished += result.eventsPublished || 0;

      lastRecordId = result.lastRecordId;
      hasMore = result.hasMore;
    }

    // Ensure minimum display time for UX
    const elapsed = Date.now() - startTime;
    if (elapsed < MIN_STEP_DISPLAY_MS) {
      await this.sleep(MIN_STEP_DISPLAY_MS - elapsed);
    }

    this.completeStepProgress(stepKey);
    return aggregatedResult;
  }

  /**
   * Execute a batched step for a specific grade, using grade-specific progress ranges.
   */
  async executeBatchedStepForGrade(stepKey, gradeIndex, apexCallFn) {
    this.executionStep = stepKey;
    this.currentGradeStep = stepKey;

    const range = this.getGradeStepRange(gradeIndex, stepKey);
    if (range && this.progressAnimator) {
      this.progressAnimator.setTarget(range.start);
    }

    const startTime = Date.now();

    let lastRecordId = null;
    let batchNumber = 0;
    let hasMore = true;
    const aggregatedResult = {
      processedCount: 0,
      preOfferCount: 0,
      rescindedCount: 0,
      waitlistCount: 0,
      eventsPublished: 0
    };

    while (hasMore) {
      batchNumber++;

      // Start trickle before Apex call
      if (range && this.progressAnimator) {
        const estimatedBatches = this.estimatedBatchCounts[stepKey] || 1;
        const nextTarget = this.calculateBatchTarget(
          range,
          batchNumber,
          estimatedBatches
        );
        const current = this.progressAnimator.current;
        const ceiling = current + (nextTarget - current) * 0.7;
        this.progressAnimator.startTrickle(ceiling);
      }

      // eslint-disable-next-line no-await-in-loop -- Sequential batch pagination requires await in loop
      const result = await apexCallFn(lastRecordId, LOTTERY_BATCH_SIZE);

      // Check for errors
      if (result.isSuccess === false) {
        if (this.progressAnimator) {
          this.progressAnimator.stopTrickle();
        }
        throw new Error(result.errorMessage || 'Batch execution failed');
      }

      // Update progress
      if (range && this.progressAnimator) {
        const estimatedBatches = this.estimatedBatchCounts[stepKey] || 1;
        const target = this.calculateBatchTarget(
          range,
          batchNumber,
          estimatedBatches
        );
        this.progressAnimator.setTarget(target);
      }

      // Aggregate counts
      aggregatedResult.processedCount += result.processedCount || 0;
      aggregatedResult.preOfferCount += result.preOfferCount || 0;
      aggregatedResult.rescindedCount += result.rescindedCount || 0;
      aggregatedResult.waitlistCount += result.waitlistCount || 0;
      aggregatedResult.eventsPublished += result.eventsPublished || 0;

      lastRecordId = result.lastRecordId;
      hasMore = result.hasMore;
    }

    // Ensure minimum display time for UX
    const elapsed = Date.now() - startTime;
    if (elapsed < MIN_STEP_DISPLAY_MS) {
      await this.sleep(MIN_STEP_DISPLAY_MS - elapsed);
    }

    // Complete to end of range
    if (range && this.progressAnimator) {
      this.progressAnimator.setTarget(range.end);
    }

    return aggregatedResult;
  }

  /**
   * Execute a batched step across ALL grades (Phase B/C).
   * Uses crossGradeProgressRanges for progress calculation.
   */
  async executeBatchedCrossGradeStep(stepKey, apexCallFn) {
    this.executionStep = stepKey;
    this.currentGradeStep = null; // Clear grade step during cross-grade phases

    const range = this.crossGradeProgressRanges[stepKey];
    if (range && this.progressAnimator) {
      this.progressAnimator.setTarget(range.start);
    }

    const startTime = Date.now();

    let lastRecordId = null;
    let batchNumber = 0;
    let hasMore = true;
    const aggregatedResult = {
      processedCount: 0,
      preOfferCount: 0,
      rescindedCount: 0,
      waitlistCount: 0,
      eventsPublished: 0
    };

    // Use total app count for batch estimates (all grades)
    const estimatedBatches = Math.ceil(
      this.totalApplicationCount / LOTTERY_BATCH_SIZE
    );

    while (hasMore) {
      batchNumber++;

      // Start trickle before Apex call
      if (range && this.progressAnimator) {
        const nextTarget = this.calculateBatchTarget(
          range,
          batchNumber,
          estimatedBatches
        );
        const current = this.progressAnimator.current;
        const ceiling = current + (nextTarget - current) * 0.7;
        this.progressAnimator.startTrickle(ceiling);
      }

      // eslint-disable-next-line no-await-in-loop -- Sequential batch pagination requires await in loop
      const result = await apexCallFn(lastRecordId, LOTTERY_BATCH_SIZE);

      // Check for errors
      if (result.isSuccess === false) {
        if (this.progressAnimator) {
          this.progressAnimator.stopTrickle();
        }
        throw new Error(result.errorMessage || 'Batch execution failed');
      }

      // Update progress
      if (range && this.progressAnimator) {
        const target = this.calculateBatchTarget(
          range,
          batchNumber,
          estimatedBatches
        );
        this.progressAnimator.setTarget(target);
      }

      // Aggregate counts
      aggregatedResult.processedCount += result.processedCount || 0;
      aggregatedResult.preOfferCount += result.preOfferCount || 0;
      aggregatedResult.rescindedCount += result.rescindedCount || 0;
      aggregatedResult.waitlistCount += result.waitlistCount || 0;
      aggregatedResult.eventsPublished += result.eventsPublished || 0;

      lastRecordId = result.lastRecordId;
      hasMore = result.hasMore;
    }

    // Ensure minimum display time for UX
    const elapsed = Date.now() - startTime;
    if (elapsed < MIN_STEP_DISPLAY_MS) {
      await this.sleep(MIN_STEP_DISPLAY_MS - elapsed);
    }

    // Complete to end of range
    if (range && this.progressAnimator) {
      this.progressAnimator.setTarget(range.end);
    }

    return aggregatedResult;
  }

  async handleConfirmLottery() {
    this.showConfirmationModal = false;
    this.currentStep = STEPS.EXECUTE;
    this.isLoading = true;
    this.error = undefined;
    this.jobId = null;
    this.executionProgress = 0;

    // Reset grade-centric state
    this.currentGrade = null;
    this.currentGradeStep = null;
    this.completedGrades = [];
    this.assignedGrades = [];
    this.executionPhase = null;

    // Get sorted grades from selected capacities
    this.selectedGrades = this.getGradesFromCapacities(
      this.selectedCapacityIds
    );

    // Calculate dynamic step ranges from preRunStats
    const totalApps = this.preRunStats.reduce(
      (sum, stat) => sum + (stat.applicationCount || 0),
      0
    );
    this.calculateStepRanges(totalApps, this.selectedGrades.length);

    // Reset animator for fresh execution
    if (this.progressAnimator) {
      this.progressAnimator.reset();
    }

    let runLogId = null;
    let runLogName = null;
    let preOffersAssigned = 0;
    let offersRescinded = 0;
    let waitlisted = 0;

    try {
      // Step 1: Initialize - acquire lock, create run log (once, before grades)
      const initResult = await this.executeStepWithMinDisplay(
        'INITIALIZE',
        initializeLottery({
          capacityIds: this.selectedCapacityIds,
          applicationTimelineId: this.recordId
        })
      );
      this.jobId = initResult.jobId;
      runLogId = initResult.runLogId;
      runLogName = initResult.runLogName;

      // ========================================
      // Phase A: Randomize + Assign per grade
      // ========================================
      this.executionPhase = 'PHASE_A';

      for (
        let gradeIdx = 0;
        gradeIdx < this.selectedGrades.length;
        gradeIdx++
      ) {
        const grade = this.selectedGrades[gradeIdx];
        this.currentGrade = grade;
        const gradeCapacityIds = this.getCapacityIdsForGrade(
          grade,
          this.selectedCapacityIds
        );

        // Randomize applications for this grade
        // eslint-disable-next-line no-await-in-loop -- Sequential grade processing
        await this.executeBatchedStepForGrade(
          'RANDOMIZE',
          gradeIdx,
          (lastRecordId, batchSize) =>
            randomizeApplicationsBatch({
              capacityIds: gradeCapacityIds,
              runLogId: runLogId,
              jobId: this.jobId,
              startDate: this.startDate || null,
              endDate: this.endDate || null,
              lastRecordId: lastRecordId,
              batchSize: batchSize
            })
        );

        // Assign pre-offers for this grade
        // eslint-disable-next-line no-await-in-loop -- Sequential grade processing
        const assignResult = await this.executeBatchedStepForGrade(
          'ASSIGN',
          gradeIdx,
          (lastRecordId, batchSize) =>
            assignPreOffersBatch({
              capacityIds: gradeCapacityIds,
              runLogId: runLogId,
              jobId: this.jobId,
              startDate: this.startDate || null,
              endDate: this.endDate || null,
              lastRecordId: lastRecordId,
              batchSize: batchSize
            })
        );
        preOffersAssigned += assignResult.preOfferCount;

        // Mark grade as "assigned" (Phase A complete for this grade)
        this.assignedGrades = [...this.assignedGrades, grade];
      }

      // Clear current grade before cross-grade phases
      this.currentGrade = null;
      this.currentGradeStep = null;

      // ========================================
      // Phase B: Optimize all grades
      // ========================================
      this.executionPhase = 'PHASE_B';

      const optimizeResult = await this.executeBatchedCrossGradeStep(
        'OPTIMIZE_ALL',
        (lastRecordId, batchSize) =>
          optimizeOffersBatch({
            runLogId: runLogId,
            jobId: this.jobId,
            capacityIds: this.selectedCapacityIds, // ALL capacities
            lastRecordId: lastRecordId,
            batchSize: batchSize
          })
      );
      offersRescinded += optimizeResult.rescindedCount;

      // ========================================
      // Phase C: Finalize all grades
      // ========================================
      this.executionPhase = 'PHASE_C';

      const finalizeResult = await this.executeBatchedCrossGradeStep(
        'FINALIZE_ALL',
        (lastRecordId, batchSize) =>
          finalizeLotteryBatch({
            capacityIds: this.selectedCapacityIds, // ALL capacities
            runLogId: runLogId,
            jobId: this.jobId,
            lastRecordId: lastRecordId,
            batchSize: batchSize
          })
      );
      waitlisted += finalizeResult.waitlistCount;

      // Mark all grades as completed
      this.completedGrades = [...this.selectedGrades];
      this.executionPhase = null;

      // Release lock after all grades complete
      await releaseLotteryLock({
        capacityIds: this.selectedCapacityIds,
        jobId: this.jobId
      });

      // Fetch results for display
      const resultsData = await getResults({
        capacityIds: this.selectedCapacityIds
      });

      // Create audit records in batches
      let auditLastRecordId = null;
      let auditHasMore = true;
      let auditLotteryNumber = 1;
      while (auditHasMore) {
        // eslint-disable-next-line no-await-in-loop -- Sequential batch pagination
        const auditResult = await createAuditRecordsBatch({
          runLogId: runLogId,
          capacityIds: this.selectedCapacityIds,
          lastRecordId: auditLastRecordId,
          batchSize: LOTTERY_BATCH_SIZE,
          startLotteryNumber: auditLotteryNumber
        });
        if (auditResult.isSuccess === false) {
          throw new Error(
            auditResult.errorMessage || 'Audit record creation failed'
          );
        }
        auditLastRecordId = auditResult.lastRecordId;
        auditHasMore = auditResult.hasMore;
        auditLotteryNumber = auditResult.nextLotteryNumber;
      }

      // Build response compatible with existing UI
      this.runResponse = {
        runLogId: runLogId,
        runLogName: runLogName,
        preOffersAssigned: preOffersAssigned,
        offersRescinded: offersRescinded,
        waitlisted: waitlisted,
        totalEligible: resultsData.totalEligible,
        results: resultsData.results,
        allResults: resultsData.allResults
      };

      this.runLogUrl = await this[NavigationMixin.GenerateUrl]({
        type: 'standard__recordPage',
        attributes: {
          recordId: runLogId,
          objectApiName: 'Lottery_Run_Log__c',
          actionName: 'view'
        }
      });

      this.currentStep = STEPS.REVIEW;
      this.executionStep = null;

      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Success',
          message: `Lottery completed: ${preOffersAssigned} offers made`,
          variant: 'success'
        })
      );
    } catch (error) {
      // Stop animator on error
      if (this.progressAnimator) {
        this.progressAnimator.stop();
      }

      // Release lock if we acquired one
      if (this.jobId) {
        try {
          await releaseLotteryLock({
            capacityIds: this.selectedCapacityIds,
            jobId: this.jobId
          });
        } catch (releaseError) {
          console.error('Failed to release lock:', releaseError);
        }
      }

      this.currentStep = STEPS.CONFIGURE;
      this.executionStep = null;
      this.executionPhase = null;
      this.currentGrade = null;
      this.currentGradeStep = null;
      this.assignedGrades = [];
      const parsed = ErrorHandler.parse(error);
      this.error = parsed.messages.join(', ');
    } finally {
      this.isLoading = false;
      this.executionStep = null;
    }
  }

  generateConfetti() {
    const colors = [
      '#ff6b6b',
      '#ffd93d',
      '#6bcb77',
      '#4d96ff',
      '#ff6eb4',
      '#a66cff',
      '#ff8c42',
      '#00d2d3'
    ];
    this.confettiPieces = Array.from({ length: 50 }, (_, i) => ({
      id: i,
      style: [
        `left:${Math.random() * 100}%`,
        `background:${colors[Math.floor(Math.random() * colors.length)]}`,
        `animation-delay:${(Math.random() * 1.5).toFixed(2)}s`,
        `animation-duration:${(2.5 + Math.random() * 1.5).toFixed(2)}s`,
        `--confetti-rotation:${Math.floor(Math.random() * 360)}deg`,
        `--confetti-drift:${Math.floor(Math.random() * 100 - 50)}px`
      ].join(';')
    }));
    this.showConfetti = true;
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._confettiTimerId = setTimeout(() => {
      this.showConfetti = false;
      this.confettiPieces = [];
      this._confettiTimerId = undefined;
    }, 4000);
  }

  async handlePublish() {
    if (!this.runResponse?.runLogId) {
      return;
    }

    this.isPublishing = true;

    try {
      await publishLotteryRun({ runLogId: this.runResponse.runLogId });
      this.isPublished = true;
      this.generateConfetti();

      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Success',
          message: 'Lottery results published successfully',
          variant: 'success'
        })
      );

      await refreshApex(this.wiredCapacitiesResult);
    } catch (error) {
      ErrorHandler.toast(this, error);
    } finally {
      this.isPublishing = false;
    }
  }

  async handleReset() {
    this.runResponse = undefined;
    this.runLogUrl = undefined;
    this.isPublished = false;
    this._hasAutoScrolled = false;
    this.error = undefined;
    this.currentStep = STEPS.CONFIGURE;
    this.selectedSchoolIds = new Set();
    this.isLoading = true;

    // Reset grade-centric state
    this.currentGrade = null;
    this.currentGradeStep = null;
    this.completedGrades = [];
    this.assignedGrades = [];
    this.selectedGrades = [];
    this.executionPhase = null;

    try {
      await refreshApex(this.wiredCapacitiesResult);
    } finally {
      this.isLoading = false;
    }
  }
}