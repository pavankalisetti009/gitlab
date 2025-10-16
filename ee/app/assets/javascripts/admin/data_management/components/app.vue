<script>
import GeoListTopBar from 'ee/geo_shared/list/components/geo_list_top_bar.vue';
import GeoList from 'ee/geo_shared/list/components/geo_list.vue';
import { sprintf, s__ } from '~/locale';
import {
  DEFAULT_SORT,
  GEO_TROUBLESHOOTING_LINK,
  TOKEN_TYPES,
} from 'ee/admin/data_management/constants';
import { processFilters } from 'ee/admin/data_management/filters';
import { setUrlParams, visitUrl } from '~/lib/utils/url_utility';

export default {
  name: 'AdminDataManagementApp',
  components: {
    GeoListTopBar,
    GeoList,
  },
  props: {
    modelClass: {
      type: Object,
      required: true,
    },
  },
  computed: {
    emptyState() {
      return {
        title: sprintf(s__('Geo|No %{itemTitle} exist'), {
          itemTitle: this.modelClass.titlePlural.toLowerCase(),
        }),
        description: s__(
          'Geo|If you believe this is an error, see the %{linkStart}Geo troubleshooting%{linkEnd} documentation.',
        ),
        helpLink: GEO_TROUBLESHOOTING_LINK,
      };
    },
  },
  methods: {
    handleListboxChange(value) {
      const filters = [{ type: TOKEN_TYPES.MODEL, value }];

      const { query, url } = processFilters(filters);

      visitUrl(setUrlParams(query, url.href, true));
    },
  },
  defaultSort: DEFAULT_SORT,
};
</script>

<template>
  <div>
    <geo-list-top-bar
      :page-heading-title="__('Data management')"
      :page-heading-description="
        s__('Geo|Review stored data and data health within your instance.')
      "
      :filtered-search-option-label="__('Search by ID')"
      :active-listbox-item="modelClass.name"
      :active-sort="$options.defaultSort"
      @listboxChange="handleListboxChange"
    />
    <geo-list :is-loading="false" :has-items="false" :empty-state="emptyState" />
  </div>
</template>
