<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { ACTION_TYPES } from 'ee/geo_shared/constants';
import replicableTypeUpdateMutation from 'ee/geo_shared/graphql/replicable_type_update_mutation.graphql';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import toast from '~/vue_shared/plugins/global_toast';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import buildReplicableItemQuery from '../graphql/replicable_item_query_builder';
import GeoFeedbackBanner from '../../geo_replicable/components/geo_feedback_banner.vue';
import GeoReplicableItemRegistryInfo from './geo_replicable_item_registry_info.vue';
import GeoReplicableItemReplicationInfo from './geo_replicable_item_replication_info.vue';
import GeoReplicableItemVerificationInfo from './geo_replicable_item_verification_info.vue';

export default {
  name: 'GeoReplicableItemApp',
  components: {
    GlLoadingIcon,
    PageHeading,
    GeoReplicableItemRegistryInfo,
    GeoReplicableItemReplicationInfo,
    GeoReplicableItemVerificationInfo,
    GeoFeedbackBanner,
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
          this.replicableClass.graphqlRegistryIdType,
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
  methods: {
    async reverify() {
      try {
        await this.$apollo.mutate({
          mutation: replicableTypeUpdateMutation,
          variables: {
            action: ACTION_TYPES.REVERIFY,
            registryId: convertToGraphQLId(
              this.replicableClass.graphqlRegistryClass,
              this.replicableItemId,
            ),
          },
        });

        toast(s__('Geo|Reverification was scheduled successfully'));
        this.$apollo.queries.replicableItem.refetch();
      } catch (error) {
        createAlert({
          message: s__('Geo|There was an error reverifying this replicable'),
          error,
          captureError: true,
        });
      }
    },
  },
};
</script>

<template>
  <section>
    <geo-feedback-banner />
    <gl-loading-icon v-if="isLoading" size="xl" class="gl-mt-4" />
    <div v-else-if="replicableItem" data-testid="replicable-item-details">
      <page-heading :heading="registryId" />

      <div class="gl-flex gl-flex-col-reverse gl-gap-4 md:gl-grid md:gl-grid-cols-2">
        <div>
          <geo-replicable-item-replication-info :replicable-item="replicableItem" class="gl-mb-4" />
          <geo-replicable-item-verification-info
            v-if="replicableClass.verificationEnabled"
            :replicable-item="replicableItem"
            @reverify="reverify"
          />
        </div>

        <geo-replicable-item-registry-info
          :replicable-item="replicableItem"
          :registry-id="registryId"
          class="gl-h-max"
        />
      </div>
    </div>
  </section>
</template>
