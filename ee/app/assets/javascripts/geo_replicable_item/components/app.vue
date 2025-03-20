<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import buildReplicableItemQuery from '../graphql/replicable_item_query_builder';
import GeoReplicableItemRegistryInfo from './geo_replicable_item_registry_info.vue';

export default {
  name: 'GeoReplicableItemApp',
  components: {
    GlLoadingIcon,
    PageHeading,
    GeoReplicableItemRegistryInfo,
  },
  i18n: {
    errorMessage: s__("Geo|There was an error fetching this replicable's details"),
  },
  props: {
    replicableClass: {
      type: Object,
      required: true,
    },
    replicableItemId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      replicableItem: null,
    };
  },
  apollo: {
    replicableItem: {
      query() {
        return buildReplicableItemQuery(
          this.replicableClass.graphqlFieldName,
          this.replicableClass.verificationEnabled,
        );
      },
      variables() {
        return {
          ids: convertToGraphQLId(this.replicableClass.graphqlRegistryClass, this.replicableItemId),
        };
      },
      update(data) {
        const [res] = data.geoNode[this.replicableClass.graphqlFieldName].nodes;
        return res;
      },
      error(error) {
        createAlert({ message: this.$options.i18n.errorMessage, error, captureError: true });
      },
    },
  },
  computed: {
    registryId() {
      return `${this.replicableClass.graphqlRegistryClass}/${this.replicableItemId}`;
    },
    isLoading() {
      return this.$apollo.queries.replicableItem.loading;
    },
  },
};
</script>

<template>
  <section>
    <gl-loading-icon v-if="isLoading" size="xl" class="gl-mt-4" />
    <div v-else-if="replicableItem" data-testid="replicable-item-details">
      <page-heading :heading="registryId" />

      <div class="gl-flex gl-flex-col gl-gap-4 md:gl-grid md:gl-grid-cols-2">
        <geo-replicable-item-registry-info
          :replicable-item="replicableItem"
          :registry-id="registryId"
        />
      </div>
    </div>
  </section>
</template>
