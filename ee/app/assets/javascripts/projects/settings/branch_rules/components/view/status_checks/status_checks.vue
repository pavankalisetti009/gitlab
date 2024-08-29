<script>
import produce from 'immer';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import branchRulesQuery from 'ee_else_ce/projects/settings/branch_rules/queries/branch_rules_details.query.graphql';
import createStatusCheckMutation from '../../../mutations/external_status_check_create.mutation.graphql';
import updateStatusCheckMutation from '../../../mutations/external_status_check_update.mutation.graphql';
import StatusChecksTable from './status_checks_table.vue';
import StatusChecksDrawer from './status_checks_drawer.vue';

export default {
  name: 'StatusChecks',
  i18n: {
    statusChecksCreateSuccessMessage: s__('BranchRules|Status checks created'),
    statusChecksUpdateSuccessMessage: s__('BranchRules|Status checks updated'),
    createStatusCheckError: s__('StatusChecks|Unable to create status check. Please try again.'),
    updateStatusCheckError: s__('StatusChecks|Unable to update status check. Please try again.'),
    noChangesToast: s__('StatusChecks|No changes were made to the status check.'),
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
      this.serverValidationErrors = [];
    },
    saveStatusCheckChange(statusCheck, type) {
      if (type === 'create') {
        this.createStatusCheck({
          statusCheck,
        });
      } else {
        this.updateStatusCheck({
          statusCheck,
        });
      }
    },
    createStatusCheck({ statusCheck }) {
      this.isStatusChecksLoading = true;
      this.$apollo
        .mutate({
          mutation: createStatusCheckMutation,
          variables: {
            branchRuleId: this.branchRuleId,
            ...statusCheck,
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
            this.$toast.show(this.$options.i18n.statusChecksCreateSuccessMessage);
          },
        )
        .catch(() => {
          createAlert({ message: this.$options.i18n.createStatusCheckError });
        })
        .finally(() => {
          this.isStatusChecksLoading = false;
        });
    },
    updateStatusCheck({ statusCheck }) {
      const hasChanges = this.checkForChanges(this.selectedStatusCheck, statusCheck);
      if (!hasChanges) {
        this.closeStatusCheckDrawer();
        this.$toast.show(this.$options.i18n.noChangesToast);
        return;
      }

      this.isStatusChecksLoading = true;
      this.$apollo
        .mutate({
          mutation: updateStatusCheckMutation,
          variables: {
            branchRuleId: this.branchRuleId,
            ...statusCheck,
          },
        })
        .then(
          ({
            data: {
              branchRuleExternalStatusCheckUpdate: { errors },
            },
          }) => {
            if (errors.length) {
              this.serverValidationErrors = errors;
              return;
            }
            this.closeStatusCheckDrawer();
            this.$toast.show(this.$options.i18n.statusChecksUpdateSuccessMessage);
          },
        )
        .catch(() => {
          createAlert({ message: this.$options.i18n.updateStatusCheckError });
        })
        .finally(() => {
          this.isStatusChecksLoading = false;
        });
    },
    checkForChanges(originalStatusCheck, updatedStatusCheck) {
      const fieldsToCompare = ['name', 'externalUrl'];
      return fieldsToCompare.some(
        (field) => originalStatusCheck[field] !== updatedStatusCheck[field],
      );
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
