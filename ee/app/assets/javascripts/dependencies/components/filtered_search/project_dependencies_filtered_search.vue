<script>
import { __ } from '~/locale';
import {
  OPERATORS_IS,
  OPERATORS_IS_NOT,
} from '~/vue_shared/components/filtered_search_bar/constants';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import DependenciesFilteredSearch from './dependencies_filtered_search.vue';
import ComponentToken from './tokens/component_token.vue';
import VersionToken from './tokens/version_token.vue';

export default {
  components: {
    DependenciesFilteredSearch,
  },
  mixins: [glFeatureFlagsMixin()],
  computed: {
    tokens() {
      return [
        {
          type: 'component_names',
          title: __('Component'),
          multiSelect: true,
          unique: true,
          token: ComponentToken,
          operators: OPERATORS_IS,
        },
        ...(this.glFeatures.versionFilteringOnProjectLevelDependencyList
          ? [
              {
                type: 'component_version_ids',
                title: __('Version'),
                multiSelect: true,
                unique: true,
                token: VersionToken,
                operators: OPERATORS_IS_NOT,
              },
            ]
          : []),
      ];
    },
  },
};
</script>

<template>
  <dependencies-filtered-search
    :tokens="tokens"
    filtered-search-id="project-level-filtered-search"
  />
</template>
