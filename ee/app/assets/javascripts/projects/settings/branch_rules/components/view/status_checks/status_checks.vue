<script>
import produce from 'immer';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import branchRulesQuery from 'ee_else_ce/projects/settings/branch_rules/queries/branch_rules_details.query.graphql';
import createStatusCheckMutation from '../../../mutations/external_status_check_create.mutation.graphql';
import StatusChecksTable from './status_checks_table.vue';
import StatusChecksDrawer from './status_checks_drawer.vue';

export default {
  name: 'StatusChecks',
  i18n: {
    statusChecksSuccessMessage: s__('BranchRules|Status checks created'),
    createStatusCheckError: s__('StatusChecks|Unable to create status check. Please try again.'),
  },
  components: {
    StatusChecksTable,
    StatusChecksDrawer,
  },
  props: {
    statusChecks: {
      type: Array,
      required: false,
      default: () => [],
    },
    branchRuleId: {
      type: String,
      required: true,
    },
    projectPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      isStatusChecksDrawerOpen: false,
      selectedStatusCheck: null,
      isStatusChecksLoading: false,
      serverValidationErrors: [],
    };
  },
  methods: {
    openStatusCheckDrawer(selectedStatusCheck) {
      this.isStatusChecksDrawerOpen = true;
      this.selectedStatusCheck = selectedStatusCheck;
    },
    closeStatusCheckDrawer() {
      this.isStatusChecksDrawerOpen = false;
      this.selectedStatusCheck = null;
    },
    saveStatusCheckChange(statusCheck, type) {
      if (type === 'create') {
        this.createStatusCheck({
          statusCheck,
          toastMessage: this.$options.i18n.statusChecksSuccessMessage,
        });
      } else {
        // TODO - edit status check mutation
      }
    },
    createStatusCheck({ statusCheck: { name, externalUrl }, toastMessage = '' }) {
      this.isStatusChecksLoading = true;
      this.$apollo
        .mutate({
          mutation: createStatusCheckMutation,
          variables: {
            branchRuleId: this.branchRuleId,
            name,
            externalUrl,
          },
          update: (
            store,
            {
              data: {
                branchRuleExternalStatusCheckCreate: { externalStatusCheck, errors },
              },
            },
          ) => {
            if (errors.length === 0) {
              const sourceData = store.readQuery({
                query: branchRulesQuery,
                variables: { projectPath: this.projectPath },
              });
              const data = produce(sourceData, (draftData) => {
                const currentBranchIndex = sourceData.project.branchRules.nodes.findIndex(
                  (branchRule) => branchRule.id === this.branchRuleId,
                );
                draftData.project.branchRules.nodes[
                  currentBranchIndex
                ].externalStatusChecks.nodes.push(externalStatusCheck);
              });
              store.writeQuery({
                query: branchRulesQuery,
                variables: { projectPath: this.projectPath },
                data,
              });
            }
          },
        })
        .then(
          ({
            data: {
              branchRuleExternalStatusCheckCreate: { errors },
            },
          }) => {
            if (errors.length) {
              this.serverValidationErrors = errors;
              return;
            }
            this.closeStatusCheckDrawer();
            this.$toast.show(toastMessage);
          },
        )
        .catch(() => {
          createAlert({ message: this.$options.i18n.createStatusCheckError });
        })
        .finally(() => {
          this.isStatusChecksLoading = false;
        });
    },
  },
};
</script>

<template>
  <div>
    <status-checks-table
      :status-checks="statusChecks"
      data-testid="status-checks-table"
      @open-status-check-drawer="openStatusCheckDrawer"
    />
    <status-checks-drawer
      :is-open="isStatusChecksDrawerOpen"
      :is-loading="isStatusChecksLoading"
      :selected-status-check="selectedStatusCheck"
      :server-validation-errors="serverValidationErrors"
      data-testid="status-checks-drawer"
      @close-status-check-drawer="closeStatusCheckDrawer"
      @save-status-check-change="saveStatusCheckChange"
    />
  </div>
</template>
