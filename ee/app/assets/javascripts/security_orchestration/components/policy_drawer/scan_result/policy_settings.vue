<script>
import { GlSprintf } from '@gitlab/ui';
import Api from '~/api';
import { s__, sprintf } from '~/locale';
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
  data() {
    return {
      groups: [],
      loading: false,
    };
  },
  computed: {
    hasSettings() {
      return Boolean(this.settingsList.length);
    },
    settingsList() {
      return Object.entries(this.settings).filter(this.isValidSetting).map(this.formatSettingItem);
    },
  },
  async mounted() {
    await this.fetchGroups();
  },
  methods: {
    async fetchGroups() {
      this.loading = true;
      try {
        this.groups = await Api.groups('', { top_level_only: true });
      } catch {
        this.groups = [];
      } finally {
        this.loading = false;
      }
    },
    getGroupName(id) {
      const defaultName = sprintf(s__('SecurityOrchestration|Group with id: %{id}'), { id });

      if (this.loading) {
        return defaultName;
      }

      const group = this.groups.find((g) => g.id === id);
      return group?.full_name ?? defaultName;
    },
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
                <li v-for="exception in value.exceptions" :key="exception.id" class="gl-mt-2">
                  {{ getGroupName(exception.id) }}
                </li>
              </ul>
            </template>
          </gl-sprintf>
        </div>
      </li>
    </ul>
  </div>
</template>
