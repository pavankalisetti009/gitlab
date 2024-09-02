<script>
import { GlLink, GlSprintf, GlFormGroup, GlFormCheckbox, GlPopover } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__, __ } from '~/locale';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';

export default {
  name: 'DuoExperimentBetaFeaturesForm',
  i18n: {
    sectionTitle: __('GitLab Duo experiment and beta features'),
    sectionSubtitle: s__(
      'AiPowered|These features are being developed and might be unstable. %{linkStart}What do experiment and beta mean?%{linkEnd}',
    ),
    checkboxLabel: __('Use experiment and beta GitLab Duo features'),
    checkboxHelpText: s__(
      'AiPowered|Enabling these features is your acceptance of the %{linkStart}GitLab Testing Agreement%{linkEnd}.',
    ),
    popoverTitle: s__('AiPowered|Setting unavailable'),
    popoverContent: s__(
      'AiPowered|When GitLab Duo is not available, experiment and beta features cannot be turned on.',
    ),
  },
  components: {
    GlLink,
    GlSprintf,
    GlFormGroup,
    GlFormCheckbox,
    GlPopover,
    PromoPageLink,
  },
  inject: ['areExperimentSettingsAllowed'],
  props: {
    disabledCheckbox: {
      type: Boolean,
      required: true,
    },
    experimentFeaturesEnabled: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      experimentsEnabled: this.experimentFeaturesEnabled,
    };
  },
  methods: {
    checkboxChanged() {
      this.$emit('change', this.experimentsEnabled);
    },
  },
  experimentBetaHelpPath: helpPagePath('policy/experiment-beta-support'),
  testingAgreementPath: `/handbook/legal/testing-agreement/`,
};
</script>
<template>
  <div v-if="areExperimentSettingsAllowed">
    <h5>{{ $options.i18n.sectionTitle }}</h5>
    <gl-sprintf :message="$options.i18n.sectionSubtitle">
      <template #link="{ content }">
        <gl-link :href="$options.experimentBetaHelpPath">
          {{ content }}
        </gl-link>
      </template>
    </gl-sprintf>
    <gl-form-group>
      <gl-form-checkbox
        v-model="experimentsEnabled"
        data-testid="use-experimental-features-checkbox"
        :disabled="disabledCheckbox"
        @change="checkboxChanged"
      >
        <span id="duo-experiment-checkbox-label">{{ $options.i18n.checkboxLabel }}</span>
        <template #help>
          <gl-sprintf :message="$options.i18n.checkboxHelpText">
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
      <gl-popover v-if="disabledCheckbox" target="duo-experiment-checkbox-label">
        <template #title>{{ $options.i18n.popoverTitle }}</template>
        <span data-testid="duo-experiment-popover">
          {{ $options.i18n.popoverContent }}
        </span>
      </gl-popover>
    </gl-form-group>
  </div>
</template>
