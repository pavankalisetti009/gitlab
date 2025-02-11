<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import buildReplicableItemQuery from '../graphql/replicable_item_query_builder';

export default {
  name: 'GeoReplicableItemApp',
  components: {
    GlLoadingIcon,
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
    isLoading() {
      return this.$apollo.queries.replicableItem.loading;
    },
  },
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="isLoading" />
    <div v-else data-testid="replicable-item-details">{{ replicableItem }}</div>
  </div>
</template>
