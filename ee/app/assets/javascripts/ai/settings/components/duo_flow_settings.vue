<script>
import {
  GlFormCheckbox,
  GlFormGroup,
  GlIcon,
  GlLink,
  GlSprintf,
  GlTooltipDirective,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { duoFlowHelpPath } from '~/pages/projects/shared/permissions/constants';
import CascadingLockIcon from '~/namespaces/cascading_settings/components/cascading_lock_icon.vue';

export default {
  name: 'DuoFlowSettings',
  i18n: {
    sectionTitle: __('Flow execution'),
    checkboxLabel: s__('DuoAgentPlatform|Allow flow execution'),
    checkboxHelpTextGroup: s__(
      'AiPowered|Allow GitLab Duo agents to execute flows in this group and its subgroups and projects. %{linkStart}What are flows%{linkEnd}?',
    ),
    checkboxHelpTextInstance: s__(
      'AiPowered|Allow GitLab Duo agents to execute flows for the instance. %{linkStart}What are flows%{linkEnd}?',
    ),
  },
  components: {
    CascadingLockIcon,
    GlFormCheckbox,
    GlFormGroup,
    GlIcon,
    GlLink,
    GlSprintf,
  },

  directives: {
    tooltip: GlTooltipDirective,
  },
  inject: ['isGroupSettings', 'duoRemoteFlowsCascadingSettings'],
  props: {
    disabledCheckbox: {
      type: Boolean,
      required: true,
    },
    duoRemoteFlowsAvailability: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      flowEnabled: this.duoRemoteFlowsAvailability,
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
        this.duoRemoteFlowsCascadingSettings?.lockedByAncestor ||
        this.duoRemoteFlowsCascadingSettings?.lockedByApplicationSetting
      );
    },
  },
  methods: {
    checkboxChanged() {
      this.$emit('change', this.flowEnabled);
    },
  },
  duoFlowHelpPath,
};
</script>
<template>
  <div>
    <gl-form-group :label="$options.i18n.sectionTitle" class="gl-my-4">
      <gl-form-checkbox
        v-model="flowEnabled"
        data-testid="duo-flow-features-checkbox"
        :disabled="disabledCheckbox || showCascadingButton"
        @change="checkboxChanged"
      >
        <div class="gl-flex">
          <span id="duo-flow-checkbox-label">{{ $options.i18n.checkboxLabel }}</span>
          <span
            v-if="disabledCheckbox"
            v-tooltip="
              s__(
                'AiPowered|This setting requires GitLab Duo availability to be on or off by default.',
              )
            "
            class="gl-ml-2"
            :aria-label="s__('AiPowered|Lock tooltip icon')"
            data-testid="duo-flow-feature-checkbox-locked"
          >
            <gl-icon name="lock" />
          </span>
          <cascading-lock-icon
            v-if="showCascadingButton"
            class="gl-relative gl--inset-y-3"
            :is-locked-by-group-ancestor="duoRemoteFlowsCascadingSettings.lockedByAncestor"
            :is-locked-by-application-settings="
              duoRemoteFlowsCascadingSettings.lockedByApplicationSetting
            "
            :ancestor-namespace="duoRemoteFlowsCascadingSettings.ancestorNamespace"
          />
        </div>
        <template #help>
          <gl-sprintf :message="description">
            <template #link="{ content }">
              <gl-link :href="$options.duoFlowHelpPath" target="_blank">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </template>
      </gl-form-checkbox>
    </gl-form-group>
  </div>
</template>
