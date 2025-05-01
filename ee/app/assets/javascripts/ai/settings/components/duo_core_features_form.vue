<script>
import { GlSprintf, GlFormCheckbox } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';

export default {
  name: 'DuoCoreFeaturesForm',
  i18n: {
    sectionTitle: __('Gitlab Duo Core'),
    checkboxLabel: s__('AiPowered|Turn on IDE features'),
    checkboxHelpText: s__(
      'AiPowered|This settings applies Namespace/Instance-wide, Subgroup and project access controls are coming soon.%{br}By turning this on, you accept the %{linkStart}GitLab AI functionality terms%{linkEnd}.',
    ),
  },
  components: {
    GlSprintf,
    GlFormCheckbox,
    PromoPageLink,
  },
  props: {
    duoCoreFeaturesEnabled: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      duoCoreEnabled: this.duoCoreFeaturesEnabled,
    };
  },
  methods: {
    checkboxChanged() {
      this.$emit('change', this.duoCoreEnabled);
    },
  },
  termsPath: `/handbook/legal/ai-functionality-terms/`,
};
</script>
<template>
  <div>
    <h5>{{ $options.i18n.sectionTitle }}</h5>
    <gl-form-checkbox
      v-model="duoCoreEnabled"
      data-testid="use-duo-core-features-checkbox"
      @change="checkboxChanged"
    >
      <span id="duo-core-checkbox-label">{{ $options.i18n.checkboxLabel }}</span>
      <template #help>
        <gl-sprintf :message="$options.i18n.checkboxHelpText">
          <template #br>
            <br />
          </template>
          <template #link="{ content }">
            <promo-page-link :path="$options.termsPath" target="_blank">
              {{ content }}
            </promo-page-link>
          </template>
        </gl-sprintf>
      </template>
    </gl-form-checkbox>
  </div>
</template>
