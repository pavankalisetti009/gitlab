<script>
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import SearchSettings from '~/search_settings/components/search_settings.vue';
import CustomFieldsList from './custom_fields/custom_fields_list.vue';
import CustomStatusSettings from './custom_status/custom_status_settings.vue';
import ConfigurableTypesSettings from './configurable_types/configurable_types_settings.vue';

const STATUS_SECTION_ID = 'js-custom-status-settings';
const CUSTOM_FIELD_SECTION_ID = 'js-custom-fields-settings';

export default {
  components: {
    CustomFieldsList,
    CustomStatusSettings,
    ConfigurableTypesSettings,
    SearchSettings,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    fullPath: {
      type: String,
      required: true,
    },
  },
  STATUS_SECTION_ID,
  CUSTOM_FIELD_SECTION_ID,
  data() {
    return {
      sectionsExpandedState: {
        [STATUS_SECTION_ID]: false,
        [CUSTOM_FIELD_SECTION_ID]: false,
      },
      searchRoot: null,
    };
  },
  computed: {
    workItemConfigurableTypesEnabled() {
      return this.glFeatures.workItemConfigurableTypes;
    },
  },
  mounted() {
    this.searchRoot = this.$refs.searchRoot;
  },
  methods: {
    isExpanded(section) {
      const sectionId = section.getAttribute('id');

      return this.expandedProp(sectionId);
    },
    setSectionExpandedState(section, state) {
      const sectionId = section.getAttribute('id');

      this.sectionsExpandedState[sectionId] = state;
    },
    onSearchExpand(section) {
      this.setSectionExpandedState(section, true);
    },
    onSearchCollapse(section) {
      this.setSectionExpandedState(section, false);
    },
    onToggleExpand(sectionId, state) {
      this.sectionsExpandedState[sectionId] = state;

      if (!state && this.$route.hash === '') {
        return;
      }

      this.$router.push({
        name: 'workItemSettingsHome',
        hash: state ? `#${sectionId}` : '',
      });
    },
    expandedProp(sectionId) {
      return this.sectionsExpandedState[sectionId] || this.$route.hash === `#${sectionId}`;
    },
  },
};
</script>

<template>
  <div class="gl-pt-5">
    <search-settings
      v-if="searchRoot"
      class="gl-mb-5"
      :search-root="searchRoot"
      section-selector=".vue-settings-block"
      :is-expanded-fn="isExpanded"
      @expand="onSearchExpand"
      @collapse="onSearchCollapse"
    />
    <h1 class="settings-title gl-heading-1 gl-mb-1">
      {{ __('Issues') }}
    </h1>
    <p class="gl-text-subtle">
      {{
        s__(
          'WorkItem|Configure work items such as epics, issues, and tasks to represent how your team works.',
        )
      }}
    </p>

    <div ref="searchRoot">
      <configurable-types-settings v-if="workItemConfigurableTypesEnabled" />
      <custom-status-settings
        :id="$options.STATUS_SECTION_ID"
        :full-path="fullPath"
        :expanded="expandedProp($options.STATUS_SECTION_ID)"
        @toggle-expand="onToggleExpand($options.STATUS_SECTION_ID, $event)"
      />
      <custom-fields-list
        :id="$options.CUSTOM_FIELD_SECTION_ID"
        :full-path="fullPath"
        :expanded="expandedProp($options.CUSTOM_FIELD_SECTION_ID)"
        @toggle-expand="onToggleExpand($options.CUSTOM_FIELD_SECTION_ID, $event)"
      />
    </div>
  </div>
</template>
