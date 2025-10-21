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
import { createAlert } from '~/alert';
import { getModels } from 'ee/api/data_management_api';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';

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
  data() {
    return {
      isLoading: false,
      modelItems: [],
    };
  },
  computed: {
    hasItems() {
      return Boolean(this.modelItems.length);
    },
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
  created() {
    this.getModelList();
  },
  methods: {
    async getModelList() {
      this.isLoading = true;

      try {
        const { data } = await getModels(this.modelClass.name);
        this.modelItems = convertObjectPropsToCamelCase(data, { deep: true });
      } catch (error) {
        createAlert({
          message: sprintf(
            s__('Geo|There was an error fetching %{model}. Please refresh the page and try again.'),
            {
              model: this.modelClass.titlePlural.toLowerCase(),
            },
          ),
          captureError: true,
          error,
        });
      } finally {
        this.isLoading = false;
      }
    },
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
    <geo-list :is-loading="isLoading" :has-items="hasItems" :empty-state="emptyState">
      <ul>
        <li v-for="modelItem in modelItems" :key="modelItem.recordIdentifier">
          {{ modelItem.recordIdentifier }}
        </li>
      </ul>
    </geo-list>
  </div>
</template>
