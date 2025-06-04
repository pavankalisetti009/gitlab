<script>
import { GlButton, GlModal } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import {
  ROLES,
  GROUPS,
  ACCOUNTS,
  TOKENS,
  SOURCE_BRANCH_PATTERNS,
  EXCEPTIONS_FULL_OPTIONS_MAP,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';
import RolesSelector from './roles_selector.vue';
import GroupsSelector from './groups_selector.vue';
import TokensSelector from './tokens_selector.vue';
import BranchPatternSelector from './branch_pattern_selector.vue';
import PolicyExceptionsSelector from './policy_exceptions_selector.vue';

export default {
  ROLES,
  GROUPS,
  ACCOUNTS,
  SOURCE_BRANCH_PATTERNS,
  EXCEPTIONS_FULL_OPTIONS_MAP,
  TOKENS,
  i18n: {
    modalTitle: s__('ScanResultPolicy|Add policy exception'),
    cancelAction: __('Cancel'),
    backAction: __('Back'),
    primaryAction: __('Add exception(s)'),
  },
  name: 'PolicyExceptionsModal',
  components: {
    GlButton,
    GlModal,
    BranchPatternSelector,
    GroupsSelector,
    TokensSelector,
    RolesSelector,
    PolicyExceptionsSelector,
  },
  data() {
    return {
      selectedTab: null,
    };
  },
  computed: {
    modalTitle() {
      return EXCEPTIONS_FULL_OPTIONS_MAP[this.selectedTab]?.header || this.$options.i18n.modalTitle;
    },
  },
  methods: {
    tabSelected(tab) {
      return this.selectedTab === tab;
    },
    hideModalWindow() {
      this.$refs.modal.hide();
    },
    /**
     * Used in a parent component
     */
    // eslint-disable-next-line vue/no-unused-properties
    showModalWindow() {
      this.$refs.modal.show();
    },
    selectTab(tab) {
      this.selectedTab = tab;
    },
  },
};
</script>

<template>
  <gl-modal
    ref="modal"
    :action-cancel="$options.ACTION_CANCEL"
    :action-primary="$options.PRIMARY_ACTION"
    :title="modalTitle"
    scrollable
    size="md"
    content-class="security-policies-variables-modal-min-height"
    modal-id="deny-allow-list-modal"
    @canceled="hideModalWindow"
  >
    <div
      v-if="selectedTab"
      class="security-policies-exceptions-modal-height gl-border-t gl-flex gl-w-full gl-flex-col md:gl-flex-row"
    >
      <roles-selector v-if="tabSelected($options.ROLES)" />
      <groups-selector v-if="tabSelected($options.GROUPS)" />
      <tokens-selector v-if="tabSelected($options.TOKENS)" />
      <branch-pattern-selector v-if="tabSelected($options.SOURCE_BRANCH_PATTERNS)" />
    </div>
    <policy-exceptions-selector v-else @select="selectTab" />

    <template #modal-footer>
      <div v-if="!selectedTab"></div>
      <div v-else class="gl-flex gl-w-full">
        <gl-button category="secondary" variant="confirm" @click="selectTab(null)">{{
          $options.i18n.backAction
        }}</gl-button>
        <div class="gl-ml-auto">
          <gl-button category="secondary" variant="confirm" @click="hideModalWindow">{{
            $options.i18n.cancelAction
          }}</gl-button>
          <gl-button category="primary" variant="confirm">{{
            $options.i18n.primaryAction
          }}</gl-button>
        </div>
      </div>
    </template>
  </gl-modal>
</template>
