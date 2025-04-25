<script>
import {
  GlAccordion,
  GlAccordionItem,
  GlButton,
  GlCollapsibleListbox,
  GlLink,
  GlSprintf,
} from '@gitlab/ui';
import { n__, s__, sprintf } from '~/locale';
import {
  ALLOW,
  ALLOW_DENY_LISTBOX_ITEMS,
  ALLOW_DENY_OPTIONS,
  DEFAULT_VARIABLES_OVERRIDE_STATE,
  DENY,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import { helpPagePath } from '~/helpers/help_page_helper';
import VariablesOverrideModal from './variables_override_modal.vue';

export default {
  ALLOW_DENY_LISTBOX_ITEMS,
  HELP_PAGE_LINK: helpPagePath('user/application_security/policies/pipeline_execution_policies'),
  i18n: {
    allowList: s__('SecurityOrchestration|allowlist'),
    denyList: s__('SecurityOrchestration|denylist'),
    denyListText: s__('SecurityOrchestration|Edit denylist (%{variablesCount} %{variables})'),
    allowListText: s__('SecurityOrchestration|Edit allowlist (%{variablesCount} %{variables})'),
    header: s__('SecurityOrchestration|Variable option'),
    message: s__(
      'SecurityOrchestration|%{listType} attempts from %{linkStart}other settings%{linkEnd} to override variables when the policy runs, except the variables defined in the %{list}.',
    ),
    listTypeDefaultText: s__('SecurityOrchestration|Select list type'),
  },
  name: 'VariablesOverrideList',
  components: {
    GlAccordion,
    GlAccordionItem,
    GlButton,
    GlCollapsibleListbox,
    GlLink,
    GlSprintf,
    VariablesOverrideModal,
  },
  props: {
    variablesOverride: {
      type: Object,
      required: false,
      default: () => DEFAULT_VARIABLES_OVERRIDE_STATE,
    },
  },
  computed: {
    buttonText() {
      const { denyListText, allowListText } = this.$options.i18n;
      const message = this.isVariablesOverrideAllowed ? denyListText : allowListText;
      const variablesCount = this.selectedExceptions.filter(Boolean).length;
      const variables = n__('variable', 'variables', variablesCount);

      return sprintf(message, {
        variablesCount,
        variables,
      });
    },
    listName() {
      return this.isVariablesOverrideAllowed
        ? this.$options.i18n.denyList
        : this.$options.i18n.allowList;
    },
    isVariablesOverrideAllowed() {
      return this.variablesOverride.allowed;
    },
    selectedExceptions() {
      const { exceptions = [] } = this.variablesOverride || {};
      return exceptions.length > 0 ? exceptions : [''];
    },
    allowedKey() {
      return this.isVariablesOverrideAllowed ? ALLOW : DENY;
    },
    toggleText() {
      return ALLOW_DENY_OPTIONS[this.allowedKey] || this.$options.i18n.listTypeDefaultText;
    },
  },
  methods: {
    showModal() {
      this.$refs.modal.showModalWindow();
    },
    emitChange(payload) {
      this.$emit('select', { ...this.variablesOverride, ...payload });
    },
    selectExceptions(exceptions) {
      this.emitChange({ exceptions });
    },
    selectListType(type) {
      this.emitChange({ allowed: type !== DENY, exceptions: [] });
    },
  },
};
</script>

<template>
  <gl-accordion :header-level="3">
    <gl-accordion-item :title="$options.i18n.header">
      <p class="gl-my-4">
        <gl-sprintf :message="$options.i18n.message">
          <template #listType>
            <gl-collapsible-listbox
              :selected="allowedKey"
              :items="$options.ALLOW_DENY_LISTBOX_ITEMS"
              :toggle-text="toggleText"
              @select="selectListType"
            />
          </template>
          <template #link="{ content }">
            <gl-link :href="$options.HELP_PAGE_LINK" target="_blank">
              {{ content }}
            </gl-link>
          </template>
          <template #list>
            <span>{{ listName }}</span>
          </template>
        </gl-sprintf>
      </p>

      <gl-button category="primary" variant="link" @click="showModal">
        {{ buttonText }}
      </gl-button>

      <variables-override-modal
        ref="modal"
        :exceptions="selectedExceptions"
        :is-variables-override-allowed="isVariablesOverrideAllowed"
        @select-exceptions="selectExceptions"
      />
    </gl-accordion-item>
  </gl-accordion>
</template>
