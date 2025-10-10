<script>
import {
  GlButton,
  GlLink,
  GlSkeletonLoader,
  GlTable,
  GlTooltipDirective,
  GlTruncate,
} from '@gitlab/ui';
import { s__, n__, sprintf } from '~/locale';
import { deleteMavenUpstreamCache } from 'ee/api/virtual_registries_api';
import UpstreamClearCacheModal from 'ee/packages_and_registries/virtual_registries/components/maven/shared/upstream_clear_cache_modal.vue';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';

export default {
  name: 'MavenUpstreamsTable',
  components: {
    GlButton,
    GlLink,
    GlSkeletonLoader,
    GlTable,
    GlTruncate,
    UpstreamClearCacheModal,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glAbilitiesMixin()],
  inject: ['editUpstreamPathTemplate', 'showUpstreamPathTemplate'],
  props: {
    upstreams: {
      type: Array,
      required: true,
    },
    busy: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      upstreamToBeCleared: null,
      upstreamClearCacheModalIsShown: false,
    };
  },
  computed: {
    canEdit() {
      return this.glAbilities.updateVirtualRegistry;
    },
    upstreamNameForClearCache() {
      return this.upstreamToBeCleared?.name ?? '';
    },
  },
  methods: {
    showClearUpstreamCacheModal(upstream) {
      this.upstreamToBeCleared = upstream;
      this.upstreamClearCacheModalIsShown = true;
    },
    hideUpstreamClearCacheModal() {
      this.upstreamClearCacheModalIsShown = false;
      this.upstreamToBeCleared = null;
    },
    async clearUpstreamCache() {
      const { id } = this.upstreamToBeCleared;
      this.hideUpstreamClearCacheModal();
      try {
        await deleteMavenUpstreamCache({ id });
        this.$toast.show(s__('VirtualRegistry|Upstream cache cleared successfully.'));
      } catch (error) {
        this.$toast.show(s__('VirtualRegistry|Failed to clear upstream cache. Try again.'));
        captureException({ error, component: this.$options.name });
      }
    },
    getShowUpstreamURL(id) {
      return this.showUpstreamPathTemplate.replace(':id', id);
    },
    getEditUpstreamURL(id) {
      return this.editUpstreamPathTemplate.replace(':id', id);
    },
    getEditUpstreamLabel(name) {
      return sprintf(s__('VirtualRegistry|Edit upstream %{name}'), { name });
    },
    getCacheValidityHoursLabel(cacheValidityHours) {
      return sprintf(
        n__(
          'VirtualRegistry|Artifact cache: %{hours} hour',
          'VirtualRegistry|Artifact cache: %{hours} hours',
          cacheValidityHours,
        ),
        { hours: cacheValidityHours },
      );
    },
    getMetadataCacheValidityHoursLabel(cacheValidityHours) {
      return sprintf(
        n__(
          'VirtualRegistry|Metadata cache: %{hours} hour',
          'VirtualRegistry|Metadata cache: %{hours} hours',
          cacheValidityHours,
        ),
        { hours: cacheValidityHours },
      );
    },
  },
  fields: [
    {
      key: 'name',
      label: s__('VirtualRegistry|Upstream'),
      tdClass: '@sm/panel:gl-max-w-0',
    },
    {
      key: 'actions',
      label: s__('VirtualRegistry|Actions'),
      thAlignRight: true,
      thClass: 'gl-w-26',
      tdClass: 'gl-text-right',
    },
  ],
};
</script>

<template>
  <div>
    <gl-table stacked="sm" :fields="$options.fields" :items="upstreams" :busy="busy">
      <template #table-busy>
        <gl-skeleton-loader :lines="2" :width="500" />
      </template>
      <template #cell(name)="{ item }">
        <div class="gl-flex gl-min-w-0 gl-flex-1 gl-flex-col gl-gap-2">
          <div
            class="gl-flex gl-min-w-0 gl-flex-col gl-flex-wrap gl-items-end gl-gap-x-2 @sm/panel:gl-flex-row @sm/panel:gl-items-start"
          >
            <gl-link
              :href="getShowUpstreamURL(item.id)"
              class="gl-mr-2 gl-min-w-0 gl-max-w-full gl-font-bold gl-text-default"
              data-testid="upstream-name"
            >
              <gl-truncate
                :text="item.name"
                class="gl-min-w-0 gl-max-w-full hover:gl-underline"
                with-tooltip
              />
            </gl-link>
            <span
              data-testid="upstream-url"
              class="gl-min-w-0 gl-max-w-full gl-overflow-hidden gl-text-default"
            >
              <gl-truncate :text="item.url" class="gl-min-w-0 gl-max-w-full" with-tooltip />
            </span>
          </div>
          <div
            class="gl-flex gl-flex-wrap gl-items-center gl-justify-end gl-gap-2 @sm/panel:gl-justify-normal"
          >
            <div data-testid="cache-validity-hours">
              {{ getCacheValidityHoursLabel(item.cacheValidityHours) }}
            </div>
            <div>&middot;</div>
            <div data-testid="metadata-cache-validity-hours">
              {{ getMetadataCacheValidityHoursLabel(item.metadataCacheValidityHours) }}
            </div>
          </div>
        </div>
      </template>
      <template v-if="canEdit" #cell(actions)="{ item }">
        <gl-button
          size="small"
          category="tertiary"
          data-testid="clear-cache-button"
          @click="showClearUpstreamCacheModal(item)"
        >
          {{ s__('VirtualRegistry|Clear cache') }}
        </gl-button>
        <gl-button
          v-gl-tooltip="__('Edit')"
          :aria-label="getEditUpstreamLabel(item.name)"
          size="small"
          category="tertiary"
          icon="pencil"
          data-testid="edit-upstream-button"
          :href="getEditUpstreamURL(item.id)"
        />
      </template>
    </gl-table>
    <upstream-clear-cache-modal
      v-model="upstreamClearCacheModalIsShown"
      :upstream-name="upstreamNameForClearCache"
      @primary="clearUpstreamCache"
      @canceled="hideUpstreamClearCacheModal"
    />
  </div>
</template>
