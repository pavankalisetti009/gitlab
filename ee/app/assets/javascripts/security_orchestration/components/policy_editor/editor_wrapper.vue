<script>
import { GlAlert, GlFormGroup, GlFormSelect } from '@gitlab/ui';
import getSecurityPolicyProjectSub from 'ee/security_orchestration/graphql/queries/security_policy_project_created.subscription.graphql';
import { NAMESPACE_TYPES } from '../../constants';
import { POLICY_TYPE_COMPONENT_OPTIONS } from '../constants';
import PipelineExecutionPolicyEditor from './pipeline_execution/editor_component.vue';
import ScanExecutionPolicyEditor from './scan_execution/editor_component.vue';
import ScanResultPolicyEditor from './scan_result/editor_component.vue';
import VulnerabilityManagementPolicyEditor from './vulnerability_management/editor_component.vue';

export default {
  apollo: {
    $subscribe: {
      // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
      newlyCreatedPolicyProject: {
        query() {
          return getSecurityPolicyProjectSub;
        },
        variables() {
          return { fullPath: this.namespacePath };
        },
        result({ data: { securityPolicyProjectCreated } }) {
          const project = securityPolicyProjectCreated?.project;

          if (project) {
            this.currentAssignedPolicyProject = {
              ...project,
              branch: project?.branch?.rootRef,
            };
          }
        },
        error(e) {
          this.setError(e);
        },
        skip() {
          // TODO toggle with feature flag in next MR
          return true;
        },
      },
    },
  },
  components: {
    GlAlert,
    GlFormGroup,
    GlFormSelect,
    PipelineExecutionPolicyEditor,
    ScanExecutionPolicyEditor,
    ScanResultPolicyEditor,
    VulnerabilityManagementPolicyEditor,
  },
  inject: {
    assignedPolicyProject: { default: null },
    existingPolicy: { default: null },
    namespaceType: { default: NAMESPACE_TYPES.PROJECT },
    namespacePath: { default: '' },
  },
  props: {
    // This is the `value` field of the POLICY_TYPE_COMPONENT_OPTIONS
    selectedPolicyType: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      currentAssignedPolicyProject: this.assignedPolicyProject,
      error: '',
      errorMessages: [],
    };
  },
  computed: {
    isEditing() {
      return Boolean(this.existingPolicy);
    },
    policyTypes() {
      return Object.values(POLICY_TYPE_COMPONENT_OPTIONS);
    },
    policyOptions() {
      return (
        this.policyTypes.find(({ value }) => value === this.selectedPolicyType) ||
        POLICY_TYPE_COMPONENT_OPTIONS.scanExecution
      );
    },
    shouldAllowPolicyTypeSelection() {
      return !this.existingPolicy;
    },
  },
  methods: {
    setError(errors) {
      [this.error, ...this.errorMessages] = errors.split('\n');
    },
  },
  NAMESPACE_TYPES,
};
</script>

<template>
  <section class="policy-editor">
    <gl-alert
      v-if="error"
      class="security-policies-alert gl-z-2 gl-mt-5"
      :title="error"
      dismissible
      variant="danger"
      data-testid="error-alert"
      sticky
      @dismiss="setError('')"
    >
      <ul v-if="errorMessages.length" class="!gl-mb-0 gl-ml-5">
        <li v-for="errorMessage in errorMessages" :key="errorMessage">
          {{ errorMessage }}
        </li>
      </ul>
    </gl-alert>
    <component
      :is="policyOptions.component"
      :existing-policy="existingPolicy"
      :assigned-policy-project="currentAssignedPolicyProject"
      :is-editing="isEditing"
      @error="setError($event)"
    />
  </section>
</template>
