<script>
import { GlLoadingIcon, GlSprintf, GlCard } from '@gitlab/ui';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import { createAlert } from '~/alert';
import { __, s__ } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import buildReplicableItemQuery from '../graphql/replicable_item_query_builder';

export default {
  name: 'GeoReplicableItemApp',
  components: {
    GlLoadingIcon,
    GlSprintf,
    GlCard,
    PageHeading,
    TimeAgo,
    ClipboardButton,
  },
  i18n: {
    copy: __('Copy'),
    registryInformation: s__('Geo|Registry information'),
    registryId: s__('Geo|Registry ID: %{id}'),
    graphqlID: s__('Geo|GraphQL ID: %{id}'),
    replicableId: s__('Geo|Replicable ID: %{id}'),
    createdAt: s__('Geo|Created: %{timeAgo}'),
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
    registryInformation() {
      return [
        {
          title: this.$options.i18n.registryId,
          value: String(this.registryId),
        },
        {
          title: this.$options.i18n.graphqlID,
          value: String(this.replicableItem.id),
        },
        {
          title: this.$options.i18n.replicableId,
          value: String(this.replicableItem.modelRecordId),
        },
      ];
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
        <gl-card data-testid="geo-registry-information">
          <template #header>
            <h5 class="gl-my-0">{{ $options.i18n.registryInformation }}</h5>
          </template>

          <div class="gl-flex gl-flex-col gl-gap-4">
            <p
              v-for="(item, index) in registryInformation"
              :key="index"
              class="gl-mb-0"
              data-testid="copyable-registry-information"
            >
              <gl-sprintf :message="item.title">
                <template #id>
                  <span class="gl-font-bold">{{ item.value }}</span>
                </template>
              </gl-sprintf>
              <clipboard-button
                :title="$options.i18n.copy"
                :text="item.value"
                size="small"
                category="tertiary"
              />
            </p>

            <p class="gl-mb-0" data-testid="registry-info-created-at">
              <gl-sprintf :message="$options.i18n.createdAt">
                <template #timeAgo>
                  <time-ago :time="replicableItem.createdAt" class="gl-font-bold" />
                </template>
              </gl-sprintf>
            </p>
          </div>
        </gl-card>
      </div>
    </div>
  </section>
</template>
