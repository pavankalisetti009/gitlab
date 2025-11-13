<script>
import { GlFormCheckbox, GlFormGroup, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import CascadingLockIcon from '~/namespaces/cascading_settings/components/cascading_lock_icon.vue';

export default {
  name: 'DuoSastFpDetectionSettings',
  i18n: {
    sectionTitle: s__('DuoSAST|SAST False Positive Detection'),
    checkboxLabel: s__('DuoSAST|Use Duo SAST False Positive Detection'),
    checkboxHelpTextGroup: s__(
      'DuoSAST|Turn on False Positive Detection for Vulnerabilities on default branch in this group and its subgroups and projects.',
    ),
    checkboxHelpTextInstance: s__(
      'DuoSAST|Turn on False Positive Detection for Vulnerabilities on default branch for the instance.',
    ),
  },
  components: {
    CascadingLockIcon,
    GlFormCheckbox,
    GlFormGroup,
    GlIcon,
  },

  directives: {
    tooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['isGroupSettings', 'duoSastFpDetectionCascadingSettings'],
  props: {
    disabledCheckbox: {
      type: Boolean,
      required: true,
    },
    duoSastFpDetectionAvailability: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      fpDetectionEnabled: this.duoSastFpDetectionAvailability,
    };
  },
  computed: {
    description() {
      return this.isGroupSettings
        ? this.$options.i18n.checkboxHelpTextGroup
        : this.$options.i18n.checkboxHelpTextInstance;
    },
    showCascadingButton() {
      return (
        this.duoSastFpDetectionCascadingSettings?.lockedByAncestor ||
        this.duoSastFpDetectionCascadingSettings?.lockedByApplicationSetting
      );
    },
  },
  methods: {
    checkboxChanged() {
      this.$emit('change', this.fpDetectionEnabled);
    },
  },
};
</script>
<template>
  <div v-if="glFeatures.aiExperimentSastFpDetection">
    <gl-form-group :label="$options.i18n.sectionTitle" class="gl-my-4">
      <gl-form-checkbox
        v-model="fpDetectionEnabled"
        data-testid="duo-sast-fp-detection-checkbox"
        :disabled="disabledCheckbox || showCascadingButton"
        @change="checkboxChanged"
      >
        <div class="gl-flex">
          <span id="duo-sast-fp-detection-checkbox-label">{{ $options.i18n.checkboxLabel }}</span>
          <span
            v-if="disabledCheckbox"
            v-tooltip="
              s__(
                'AiPowered|This setting requires GitLab Duo availability to be on or off by default.',
              )
            "
            class="gl-ml-2"
            :aria-label="s__('AiPowered|Lock tooltip icon')"
            data-testid="duo-sast-fp-detection-checkbox-locked"
          >
            <gl-icon name="lock" />
          </span>
          <cascading-lock-icon
            v-if="showCascadingButton"
            class="gl-relative gl--inset-y-3"
            :is-locked-by-group-ancestor="duoSastFpDetectionCascadingSettings.lockedByAncestor"
            :is-locked-by-application-settings="
              duoSastFpDetectionCascadingSettings.lockedByApplicationSetting
            "
            :ancestor-namespace="duoSastFpDetectionCascadingSettings.ancestorNamespace"
          />
        </div>
        <template #help>
          <span>{{ description }}</span>
        </template>
      </gl-form-checkbox>
    </gl-form-group>
  </div>
</template>
