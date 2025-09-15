<script>
import { GlButton } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'ChangeLifecycleStepper',
  components: {
    GlButton,
  },
  props: {
    steps: {
      type: Array,
      required: true,
      validator: (steps) => {
        return steps.every((step) => step.label);
      },
    },
    initialStep: {
      type: Number,
      required: false,
      default: 0,
    },
    allowSkip: {
      type: Boolean,
      required: false,
      default: false,
    },
    showActions: {
      type: Boolean,
      required: false,
      default: true,
    },
    showBackButton: {
      type: Boolean,
      required: false,
      default: true,
    },
    showNextButton: {
      type: Boolean,
      required: false,
      default: true,
    },
    showFinishButton: {
      type: Boolean,
      required: false,
      default: true,
    },
    showCancelButton: {
      type: Boolean,
      required: false,
      default: true,
    },
    backButtonText: {
      type: String,
      required: false,
      default: __('Back'),
    },
    nextButtonText: {
      type: String,
      required: false,
      default: __('Next'),
    },
    finishButtonText: {
      type: String,
      required: false,
      default: __('Finish'),
    },
    transitionName: {
      type: String,
      required: false,
      default: 'fade',
    },
  },
  data() {
    return {
      currentStep: this.initialStep,
    };
  },
  watch: {
    initialStep: {
      immediate: true,
      handler(newVal) {
        this.currentStep = newVal;
      },
    },
  },
  methods: {
    nextStep() {
      if (this.currentStep < this.steps.length - 1) {
        const canProceed = this.validateStep(this.currentStep);
        if (canProceed) {
          this.currentStep += 1;
          this.$emit('step-change', {
            currentStep: this.currentStep,
            direction: 'next',
            step: this.steps[this.currentStep],
          });
        }
      }
    },
    previousStep() {
      if (this.currentStep > 0) {
        this.currentStep -= 1;
        this.$emit('step-change', {
          currentStep: this.currentStep,
          direction: 'previous',
          step: this.steps[this.currentStep],
        });
      }
    },
    validateStep(stepIndex) {
      // Emit validation event - parent can prevent progression by returning false
      const result = this.$emit('validate-step', {
        stepIndex,
        step: this.steps[stepIndex],
      });
      return result !== false;
    },
    finish() {
      const canFinish = this.validateStep(this.currentStep);
      if (canFinish) {
        this.$emit('finish', {
          completedSteps: this.steps,
          currentStep: this.currentStep,
        });
      }
    },
    // eslint-disable-next-line vue/no-unused-properties -- will be used in next MR
    reset() {
      this.currentStep = this.initialStep;
      this.$emit('reset');
    },
    cancel() {
      this.currentStep = this.initialStep;
      this.$emit('cancel');
    },
  },
};
</script>

<template>
  <ul class="workflow-container gl-relative gl-list-none gl-ps-0">
    <li
      v-for="(step, index) in steps"
      :key="index"
      class="workflow-step"
      :class="{
        active: index === currentStep,
        completed: index < currentStep,
        disabled: index > currentStep && !allowSkip,
      }"
    >
      <div
        data-testid="step-header"
        :class="{
          'gl-heading-4': true,
          'gl-font-normal gl-text-subtle': index !== currentStep,
        }"
      >
        {{ step.label }}
      </div>

      <div v-if="index === currentStep" class="stepper-content">
        <transition :name="transitionName" mode="out-in">
          <div :key="currentStep" data-testid="step-content">
            <slot :name="`step-${currentStep}`" :step="steps[currentStep]">
              <div class="default-content">
                <h2>{{ steps[currentStep].label }}</h2>
                <p>{{ steps[currentStep].description }}</p>
              </div>
            </slot>
          </div>
        </transition>
      </div>

      <div v-if="showActions && index === currentStep" class="gl-mt-5">
        <gl-button
          v-if="showBackButton && currentStep > 0"
          data-testid="stepper-back"
          @click="previousStep"
        >
          {{ backButtonText }}
        </gl-button>

        <gl-button
          v-if="showNextButton && currentStep < steps.length - 1"
          data-testid="stepper-next"
          variant="confirm"
          :disabled="currentStep === steps.length - 1"
          @click="nextStep"
        >
          {{ nextButtonText }}
        </gl-button>

        <gl-button
          v-if="showFinishButton && currentStep === steps.length - 1"
          data-testid="stepper-finish"
          @click="finish"
        >
          {{ finishButtonText }}
        </gl-button>

        <gl-button v-if="showCancelButton" data-testid="stepper-cancel" @click="cancel">
          {{ __('Cancel') }}
        </gl-button>
      </div>
    </li>
  </ul>
</template>
