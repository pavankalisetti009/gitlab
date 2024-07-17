<script>
import { sprintf } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import RuleViewFoss from '~/projects/settings/branch_rules/components/view/index.vue';
import ApprovalRulesApp from 'ee/approvals/components/approval_rules_app.vue';
import ProjectRules from 'ee/approvals/project_settings/project_rules.vue';
import {
  I18N,
  APPROVALS_HELP_PATH,
  STATUS_CHECKS_HELP_PATH,
} from '~/projects/settings/branch_rules/components/view/constants';

// eslint-disable-next-line local-rules/require-valid-help-page-path
const approvalsHelpDocLink = helpPagePath(APPROVALS_HELP_PATH);
// eslint-disable-next-line local-rules/require-valid-help-page-path
const statusChecksHelpDocLink = helpPagePath(STATUS_CHECKS_HELP_PATH);

// This is a false violation of @gitlab/no-runtime-template-compiler, since it
// extends a valid Vue single file component.
// eslint-disable-next-line @gitlab/no-runtime-template-compiler
export default {
  name: 'EERuleView',
  components: { ApprovalRulesApp, ProjectRules }, // used in the CE template
  extends: RuleViewFoss,
  i18n: I18N,
  approvalsHelpDocLink,
  statusChecksHelpDocLink,
  inject: {
    approvalRulesPath: {
      default: '',
    },
    statusChecksPath: {
      default: '',
    },
  },
  computed: {
    statusChecksHeader() {
      return sprintf(this.$options.i18n.statusChecksHeader, {
        total: this.statusChecks.length,
      });
    },
  },
};
</script>
