<script>
import { nextTick } from 'vue';
import { GlAlert, GlLoadingIcon } from '@gitlab/ui';
import { s__ } from '~/locale';

import { GRAPHQL_FIELD_MISSING_ERROR_MESSAGE } from '../../constants';
import { isGraphqlFieldMissingError } from '../../utils';
import DetailsDrawer from './components/details_drawer/details_drawer.vue';
import GroupedTable from './components/grouped_table/grouped_table.vue';
import { GroupedLoader } from './services/grouped_loader';

export default {
  name: 'ComplianceStandardsAdherenceTableV2',
  components: {
    GlAlert,
    GlLoadingIcon,

    DetailsDrawer,
    GroupedTable,
  },
  props: {
    groupPath: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      selectedStatus: null,
      items: {
        data: [],
        pageInfo: {},
      },
      isInitiallyLoading: true,

      errorMessage: null,
    };
  },
  mounted() {
    this.groupedLoader = new GroupedLoader({
      fullPath: this.groupPath,
      apollo: this.$apollo,
    });
    this.loadFirstPage();
  },
  methods: {
    onRowSelected(item) {
      if (this.selectedStatus === item) {
        return;
      }

      this.selectedStatus = null;
      nextTick(() => {
        this.selectedStatus = item;
      });
    },

    async invokeLoader(loaderMethod = 'loadPage') {
      try {
        this.errorMessage = null;
        this.items = await this.groupedLoader[loaderMethod]();
      } catch (error) {
        if (isGraphqlFieldMissingError(error, 'projectComplianceRequirementsStatus')) {
          this.errorMessage = GRAPHQL_FIELD_MISSING_ERROR_MESSAGE;
        } else {
          this.errorMessage = this.$options.i18n.errorMessage;
        }
      } finally {
        this.isInitiallyLoading = false;
      }
    },

    loadFirstPage() {
      return this.invokeLoader();
    },
  },
  i18n: {
    errorMessage: s__('AdherenceReport|There was an error loading adherence report.'),
    emptyReport: s__('AdherenceReport|No statuses found.'),
  },
};
</script>

<template>
  <section>
    <details-drawer :status="selectedStatus" @close="selectedStatus = null" />
    <gl-alert v-if="errorMessage" variant="warning" class="gl-mt-3" :dismissible="false">
      {{ errorMessage }}
    </gl-alert>
    <template v-if="isInitiallyLoading">
      <gl-loading-icon size="lg" class="gl-mt-5" />
    </template>
    <div v-else>
      <grouped-table v-if="items.data.length" :items="items.data" @row-selected="onRowSelected" />
      <div v-else class="gl-m-3">{{ $options.i18n.emptyReport }}</div>
    </div>
  </section>
</template>
