<script>
import { GlSprintf, GlFormCheckbox, GlIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';

export default {
  name: 'AiModelsForm',
  i18n: {
    title: s__('AiPowered|Self-hosted AI models'),
    checkBoxLabel: s__('AiPowered|Turn on self-hosted models'),
    checkboxHelpText: s__(
      'AiPowered|By turning on self-hosted AI models, you agree to the %{linkStart}GitLab Testing Agreement%{linkEnd}. This action cannot be reversed.',
    ),
    selfHostedModelsEnabledHelpText: s__(
      'AiPowered|You have turned on self-hosted AI models and agreed to the %{linkStart}GitLab Testing Agreement%{linkEnd}. This action cannot be reversed.',
    ),
  },
  components: {
    GlSprintf,
    GlIcon,
    PromoPageLink,
    GlFormCheckbox,
  },
  inject: ['selfHostedModelsEnabled'],
  testingAgreementPath: '/handbook/legal/testing-agreement/',
  data() {
    return {
      aiModelsEnabled: this.selfHostedModelsEnabled,
    };
  },
  methods: {
    checkBoxChanged(value) {
      this.$emit('change', value);
    },
    checkBoxHelpText() {
      return this.selfHostedModelsEnabled
        ? this.$options.i18n.selfHostedModelsEnabledHelpText
        : this.$options.i18n.checkboxHelpText;
    },
  },
};
</script>
<template>
  <div>
    <h3 class="gl-text-base">{{ $options.i18n.title }}</h3>
    <gl-form-checkbox
      v-model="aiModelsEnabled"
      :disabled="selfHostedModelsEnabled"
      @change="checkBoxChanged"
    >
      <span data-testid="ai-models-checkbox-label"
        >{{ $options.i18n.checkBoxLabel }} <gl-icon name="lock" variant="subtle"
      /></span>
      <template #help>
        <gl-sprintf :message="checkBoxHelpText()">
          <template #link="{ content }">
            <promo-page-link
              :path="$options.testingAgreementPath"
              target="_blank"
              rel="noopener noreferrer"
            >
              {{ content }}
            </promo-page-link>
          </template>
        </gl-sprintf>
      </template>
    </gl-form-checkbox>
  </div>
</template>
