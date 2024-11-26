<script>
import { GlCollapsibleListbox, GlSprintf, GlButton, GlIcon } from '@gitlab/ui';
import { s__, n__, sprintf } from '~/locale';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import { ALLOWED_DENIED_OPTIONS, ALLOWED_DENIED_LISTBOX_ITEMS, DENIED } from './constants';

export default {
  ALLOWED_DENIED_LISTBOX_ITEMS,
  i18n: {
    denyListText: s__('ScanResultPolicy|denylist (%{licenceCount} %{licences})'),
    allowListText: s__('ScanResultPolicy|allowlist (%{licenceCount} %{licences})'),
    label: s__('ScanResultPolicy|License is:'),
    message: s__('ScanResultPolicy|%{listType} according to the %{buttonType}'),
  },
  name: 'DenyAllowList',
  components: {
    GlButton,
    GlCollapsibleListbox,
    GlIcon,
    GlSprintf,
    SectionLayout,
  },
  props: {
    selected: {
      type: String,
      required: false,
      default: DENIED,
    },
    licences: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    buttonText() {
      const { denyListText, allowListText } = this.$options.i18n;
      const message = this.selected === DENIED ? denyListText : allowListText;
      const licences = n__('licence', 'licenses', this.licences.length);

      return sprintf(message, {
        licenceCount: this.licences.length,
        licences,
      });
    },
    toggleText() {
      return ALLOWED_DENIED_OPTIONS[this.selected] || s__('ScanResultPolicy|Select list type');
    },
  },
  methods: {
    selectListType(type) {
      this.$emit('select-type', type);
    },
  },
};
</script>

<template>
  <section-layout
    :rule-label="$options.i18n.label"
    class="gl-w-full gl-bg-white gl-pr-1 md:gl-items-center"
    label-classes="!gl-text-base !gl-w-10 md:!gl-w-12 !gl-pl-0 !gl-font-bold"
    @remove="$emit('remove')"
  >
    <template #content>
      <gl-sprintf :message="$options.i18n.message">
        <template #listType>
          <gl-collapsible-listbox
            :selected="selected"
            :items="$options.ALLOWED_DENIED_LISTBOX_ITEMS"
            :toggle-text="toggleText"
            @select="selectListType"
          />
        </template>
        <template #buttonType>
          <gl-button category="primary" variant="link">
            {{ buttonText }}
            <gl-icon name="pencil" />
          </gl-button>
        </template>
      </gl-sprintf>
    </template>
  </section-layout>
</template>
