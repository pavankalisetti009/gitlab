<script>
import { GlButton, GlModal } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import {
  EXCEPTION_OPTIONS,
  ROLES,
  GROUPS,
  ACCOUNTS,
  SOURCE_BRANCH_PATTERNS,
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
  EXCEPTION_OPTIONS,
  i18n: {
    modalTitle: s__('ScanResultPolicy|Add policy exception'),
  },
  ACTION_CANCEL: { text: __('Cancel') },
  PRIMARY_ACTION: {
    text: s__('ScanResultPolicy|Add exception(s)'),
    attributes: {
      variant: 'confirm',
    },
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
      selectedTab: ROLES,
      selectedException: null,
    };
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
    :title="$options.i18n.modalTitle"
    scrollable
    size="md"
    content-class="security-policies-variables-modal-min-height"
    modal-id="deny-allow-list-modal"
    @canceled="hideModalWindow"
  >
    <div
      v-if="selectedException"
      class="security-policies-exceptions-modal-height gl-border-t gl-flex gl-w-full gl-flex-col md:gl-flex-row"
    >
      <div class="gl-flex gl-w-full gl-flex-col gl-items-start gl-pt-3 md:gl-border-r md:gl-w-2/6">
        <gl-button
          v-for="link in $options.EXCEPTION_OPTIONS"
          :key="link.key"
          class="gl-my-3 gl-block gl-font-bold"
          :class="{ '!gl-text-current': link.key !== selectedTab }"
          category="tertiary"
          variant="link"
          @click="selectTab(link.key)"
        >
          {{ link.value }}
        </gl-button>
      </div>
      <div class="gl-w-full gl-p-3 md:gl-w-4/6">
        <roles-selector v-if="tabSelected($options.ROLES)" />
        <groups-selector v-if="tabSelected($options.GROUPS)" />
        <tokens-selector v-if="tabSelected($options.ACCOUNTS)" />
        <branch-pattern-selector v-if="tabSelected($options.SOURCE_BRANCH_PATTERNS)" />
      </div>
    </div>
    <policy-exceptions-selector v-else />

    <template #modal-footer>
      <div v-if="!selectedException"></div>
    </template>
  </gl-modal>
</template>
