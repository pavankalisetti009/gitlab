<script>
import { GlAlert, GlModal, GlFormGroup, GlFormTextarea, GlCollapsibleListbox } from '@gitlab/ui';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { __, s__ } from '~/locale';
import {
  INITIAL_STATE_NEXT_STEPS,
  WARN_MODE_BYPASS_REASONS,
  WARN_MODE_NEXT_STEPS,
} from 'ee/vue_merge_request_widget/components/checks/constants';
import SecurityPolicyViolationsSelector from './security_policy_violations_selector.vue';

export default {
  ACTION_CANCEL: { text: __('Cancel') },
  name: 'SecurityPolicyViolationsModal',
  components: {
    GlAlert,
    GlModal,
    GlFormGroup,
    GlFormTextarea,
    GlCollapsibleListbox,
    SecurityPolicyViolationsSelector,
  },
  model: {
    prop: 'visible',
    event: 'change',
  },
  props: {
    policies: {
      type: Array,
      required: true,
    },
    visible: {
      type: Boolean,
      required: false,
      default: false,
    },
    mode: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      bypassReason: '',
      selectedPolicies: [],
      selectedReasons: [],
    };
  },
  computed: {
    showModeSelection() {
      return this.mode === '';
    },
    actionPrimary() {
      return {
        text: __('Bypass'),
        attributes: {
          variant: 'danger',
          disabled: !this.isValid,
          'data-testid': 'bypass-policy-violations-button',
        },
      };
    },
    bypassReasonItems() {
      return WARN_MODE_BYPASS_REASONS;
    },
    isValid() {
      return (
        this.selectedPolicies.length > 0 &&
        this.selectedReasons.length > 0 &&
        this.bypassReason.trim().length > 0
      );
    },
    nextSteps() {
      return this.showModeSelection ? INITIAL_STATE_NEXT_STEPS : WARN_MODE_NEXT_STEPS;
    },
    selectedPolicyText() {
      return getSelectedOptionsText({
        options: this.policies,
        selected: this.selectedPolicies,
        placeholder: s__('SecurityOrchestration|Select policies'),
        maxOptionsShown: 2,
      });
    },
    selectedReasonText() {
      return getSelectedOptionsText({
        options: WARN_MODE_BYPASS_REASONS,
        selected: this.selectedReasons,
        placeholder: s__('SecurityOrchestration|Select bypass reasons'),
        maxOptionsShown: 4,
      });
    },
  },
  methods: {
    handleBypass() {
      // TODO send data to backend to bypass and close modal after save
      // const bypassData = {
      //   policies: this.selectedPolicies,
      //   reasons: this.selectedReasons,
      //   bypassReason: this.bypassReason.trim(),
      // };
      this.handleClose();
    },
    handleClose() {
      this.$emit('close');
    },
    handleSelect(property, value) {
      this[property] = value;
    },
    selectMode(mode) {
      this.$emit('select-mode', mode);
    },
  },
};
</script>

<template>
  <gl-modal
    :visible="visible"
    modal-id="security-policy-violations-modal"
    :title="s__('SecurityOrchestration|Bypass Policy Violation')"
    :action-primary="actionPrimary"
    :action-cancel="$options.ACTION_CANCEL"
    size="md"
    @primary="handleBypass"
    @cancel="handleClose"
    @change="handleClose"
  >
    <gl-alert variant="info" :dismissible="false" class="gl-mb-4" :title="__('What happens next?')">
      <ul class="gl-mb-0 gl-pl-5">
        <li v-for="step in nextSteps" :key="step">
          {{ step }}
        </li>
      </ul>
    </gl-alert>

    <security-policy-violations-selector
      v-if="showModeSelection"
      class="gl-mb-7"
      @select="selectMode"
    />
    <div v-else data-testid="modal-content">
      <gl-form-group
        :label="s__('SecurityOrchestration|Select policies to bypass')"
        label-for="policy-selector"
        class="gl-mb-4"
      >
        <gl-collapsible-listbox
          :selected="selectedPolicies"
          block
          multiple
          :items="policies"
          :toggle-text="selectedPolicyText"
          data-testid="policy-selector"
          @select="handleSelect('selectedPolicies', $event)"
        />
      </gl-form-group>

      <gl-form-group
        :label="s__('SecurityOrchestration|Bypassed as')"
        label-for="reason-selector"
        class="gl-mb-4"
      >
        <gl-collapsible-listbox
          :selected="selectedReasons"
          block
          multiple
          :items="bypassReasonItems"
          :toggle-text="selectedReasonText"
          data-testid="reason-selector"
          @select="handleSelect('selectedReasons', $event)"
        />
      </gl-form-group>

      <gl-form-group
        :label="s__('SecurityOrchestration|Reason for policy bypass')"
        label-for="bypass-reason-textarea"
        class="gl-mb-0"
      >
        <gl-form-textarea
          v-model="bypassReason"
          rows="4"
          :placeholder="
            s__('SecurityOrchestration|Provide a detailed justification for policy bypass.')
          "
        />
      </gl-form-group>
      <p class="gl-text-gray-300">
        {{ s__('SecurityOrchestration|Comments are required when bypassing policies.') }}
      </p>
    </div>
  </gl-modal>
</template>
