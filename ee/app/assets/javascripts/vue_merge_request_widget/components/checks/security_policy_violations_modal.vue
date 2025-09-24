<script>
import { GlAlert, GlModal, GlFormGroup, GlFormTextarea, GlCollapsibleListbox } from '@gitlab/ui';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { __, s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  INITIAL_STATE_NEXT_STEPS,
  WARN_MODE_BYPASS_REASONS,
  POLICY_EXCEPTIONS_BYPASS_REASONS,
  WARN_MODE_NEXT_STEPS,
  WARN_MODE,
} from 'ee/vue_merge_request_widget/components/checks/constants';
import SecurityPolicyViolationsSelector from './security_policy_violations_selector.vue';
import bypassSecurityPolicyViolations from './queries/bypass_security_policy_violations.mutation.graphql';

export default {
  ACTION_CANCEL: { text: __('Cancel') },
  DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
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
    mr: {
      type: Object,
      required: false,
      default: () => ({}),
    },
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
      bypassReasonTextAreaDirty: false,
      bypassReason: '',
      loading: false,
      selectedPolicies: [],
      selectedReasons: [],
      showErrorAlert: false,
    };
  },
  computed: {
    isBypassReasonEmpty() {
      return this.bypassReason.trim().length === 0;
    },
    showModeSelection() {
      return this.mode === '';
    },
    isWarnMode() {
      return this.mode === WARN_MODE;
    },
    actionPrimary() {
      return {
        text: __('Bypass'),
        attributes: {
          variant: 'danger',
          disabled: !this.isValid,
          loading: this.loading,
          'data-testid': 'bypass-policy-violations-button',
        },
      };
    },
    bypassReasonItems() {
      return this.isWarnMode ? WARN_MODE_BYPASS_REASONS : POLICY_EXCEPTIONS_BYPASS_REASONS;
    },
    isValid() {
      return (
        this.selectedPolicies.length > 0 &&
        this.selectedReasons.length > 0 &&
        !this.isBypassReasonEmpty
      );
    },
    nextSteps() {
      return this.showModeSelection ? INITIAL_STATE_NEXT_STEPS : WARN_MODE_NEXT_STEPS;
    },
    policyItems() {
      return this.policies.map((policy) => ({
        ...policy,
        text: policy.name,
        value: policy.securityPolicyId,
      }));
    },
    selectedPolicyText() {
      return getSelectedOptionsText({
        options: this.policyItems,
        selected: this.selectedPolicies,
        placeholder: s__('SecurityOrchestration|Select policies'),
        maxOptionsShown: 2,
      });
    },
    selectedReasonText() {
      return getSelectedOptionsText({
        options: this.bypassReasonItems,
        selected: this.selectedReasons,
        placeholder: s__('SecurityOrchestration|Select bypass reasons'),
        maxOptionsShown: 4,
      });
    },
    bypassReasonState() {
      return !(this.bypassReasonTextAreaDirty && this.isBypassReasonEmpty);
    },
  },
  methods: {
    async handleBypass() {
      this.loading = true;

      try {
        const {
          data: {
            dismissPolicyViolations: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: bypassSecurityPolicyViolations,
          variables: {
            comment: this.bypassReason,
            dismissalTypes: this.selectedReasons,
            iid: this.mr.iid.toString(),
            projectPath: this.mr.targetProjectFullPath,
            securityPolicyIds: this.selectedPolicies,
          },
        });

        if (errors?.length) {
          throw Error(errors.join(','));
        }

        this.handleClose();
      } catch (e) {
        this.showErrorAlert = true;
        Sentry.captureException(e);
      } finally {
        this.loading = false;
      }
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
    updateBypassReason(value) {
      this.bypassReasonTextAreaDirty = true;
      this.bypassReason = value;
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
    @primary.prevent="handleBypass"
    @cancel="handleClose"
  >
    <gl-alert variant="info" :dismissible="false" class="gl-mb-4" :title="__('What happens next?')">
      <ul class="gl-mb-0 gl-pl-5">
        <li v-for="step in nextSteps" :key="step">
          {{ step }}
        </li>
      </ul>
    </gl-alert>

    <gl-alert
      v-if="showErrorAlert"
      class="gl-mb-5"
      variant="danger"
      :dismissible="false"
      :title="s__('SecurityOrchestration|Policy bypass failed')"
    >
      {{
        s__(
          'SecurityOrchestration|An error occurred while attempting to bypass policies. Please refresh the page and try again.',
        )
      }}
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
          data-testid="policy-selector"
          block
          multiple
          :items="policyItems"
          :selected="selectedPolicies"
          :toggle-text="selectedPolicyText"
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
          rows="4"
          :debounce="$options.DEFAULT_DEBOUNCE_AND_THROTTLE_MS"
          :placeholder="
            s__('SecurityOrchestration|Provide a detailed justification for policy bypass.')
          "
          :state="bypassReasonState"
          :value="bypassReason"
          @input="updateBypassReason"
        />
      </gl-form-group>
      <p class="gl-text-gray-300">
        {{ s__('SecurityOrchestration|Comments are required when bypassing policies.') }}
      </p>
    </div>
  </gl-modal>
</template>
