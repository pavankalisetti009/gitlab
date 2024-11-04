<script>
import { GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  BLOCK_GROUP_BRANCH_MODIFICATION,
  SETTINGS_HUMANIZED_STRINGS,
} from '../../policy_editor/scan_result/lib/settings';

export default {
  name: 'PolicySettings',
  i18n: {
    title: s__('SecurityOrchestration|Override the following project settings:'),
    blockGroupBranchModificationExceptions: s__('SecurityOrchestration|exceptions: %{exceptions}'),
  },
  components: {
    GlSprintf,
  },
  props: {
    settings: {
      type: Object,
      required: true,
    },
  },
  computed: {
    hasSettings() {
      return Boolean(this.settingsList.length);
    },
    settingsList() {
      return Object.entries(this.settings).filter(this.isValidSetting).map(this.formatSettingItem);
    },
  },
  methods: {
    isGroupBranchModSettingWithExceptions(key, value) {
      return key === BLOCK_GROUP_BRANCH_MODIFICATION && value?.enabled;
    },
    isValidBranchModificationSetting(key, value) {
      return key === BLOCK_GROUP_BRANCH_MODIFICATION && typeof value !== 'boolean' && value.enabled;
    },
    isValidStandardSetting(key) {
      return this.settings[key] && Boolean(SETTINGS_HUMANIZED_STRINGS[key]);
    },
    isValidSetting([key, value]) {
      return this.isValidStandardSetting(key) || this.isValidBranchModificationSetting(key, value);
    },
    formatSettingItem([key, value]) {
      return {
        key,
        text: SETTINGS_HUMANIZED_STRINGS[key],
        value,
      };
    },
  },
};
</script>

<template>
  <div v-if="hasSettings" class="gl-mt-5">
    <h5>{{ $options.i18n.title }}</h5>
    <ul>
      <li v-for="{ key, text, value } in settingsList" :key="key" class="gl-mb-2">
        {{ text }}
        <div v-if="isGroupBranchModSettingWithExceptions(key, value)" class="gl-ml-5 gl-mt-2">
          <gl-sprintf :message="$options.i18n.blockGroupBranchModificationExceptions">
            <template #exceptions>
              <ul data-testid="group-branch-exceptions">
                <li v-for="exception in value.exceptions" :key="exception" class="gl-mt-2">
                  {{ exception }}
                </li>
              </ul>
            </template>
          </gl-sprintf>
        </div>
      </li>
    </ul>
  </div>
</template>
