<script>
import { GlFilteredSearch, GlTableLite } from '@gitlab/ui';
import { __, n__ } from '~/locale';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import MetadataItem from '~/vue_shared/components/registry/metadata_item.vue';

export default {
  name: 'MavenUpstreamDetailsApp',
  components: {
    GlFilteredSearch,
    GlTableLite,
    MetadataItem,
    TitleArea,
  },
  props: {
    upstream: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    cacheEntries: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    return {
      search: [],
    };
  },
  computed: {
    artifactsCountText() {
      return n__('%d Artifact', '%d Artifacts', this.upstream.cacheEntries?.count || 0);
    },
    cacheEntryItems() {
      return this.cacheEntries?.nodes ?? [];
    },
  },
  fields: [
    {
      key: 'relativePath',
      label: __('Artifact'),
    },
    {
      key: 'size',
      label: __('Size'),
    },
    {
      key: 'actions',
      label: __('Actions'),
      thClass: 'hidden',
    },
  ],
};
</script>

<template>
  <div>
    <title-area :title="upstream.name">
      <template #metadata-registry-type>
        <metadata-item icon="infrastructure-registry" :text="s__('VirtualRegistry|Maven')" />
      </template>
      <template #metadata-count>
        <metadata-item icon="doc-text" :text="artifactsCountText" />
      </template>
      <template #metadata-url>
        <metadata-item icon="earth" :text="upstream.url" size="xl" />
      </template>
      <p data-testid="description">{{ upstream.description }}</p>
    </title-area>
    <div class="row-content-block gl-flex gl-flex-col gl-gap-3 md:gl-flex-row">
      <gl-filtered-search
        v-model="search"
        class="gl-min-w-0 gl-grow"
        :placeholder="__('Filter results')"
        :search-text-option-label="__('Search for this text')"
        terms-as-tokens
      />
    </div>
    <gl-table-lite :fields="$options.fields" :items="cacheEntryItems" />
  </div>
</template>
