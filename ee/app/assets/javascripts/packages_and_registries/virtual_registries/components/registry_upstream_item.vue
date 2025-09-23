<script>
import {
  GlButton,
  GlButtonGroup,
  GlBadge,
  GlLink,
  GlTooltipDirective,
  GlTruncate,
} from '@gitlab/ui';
import { s__, sprintf, n__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';

export default {
  name: 'RegistryUpstreamItem',
  components: {
    GlButton,
    GlButtonGroup,
    GlBadge,
    GlLink,
    GlTruncate,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glAbilitiesMixin()],
  inject: ['editUpstreamPathTemplate', 'showUpstreamPathTemplate'],
  props: {
    upstream: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    upstreamsCount: {
      type: Number,
      required: true,
    },
    index: {
      type: Number,
      required: true,
    },
  },
  /**
   * Emitted when an upstream is reordered
   * @event reorderUpstream
   * @property {string} direction - The direction to move the upstream ('up' or 'down')
   * @property {string} upstream - The upstream to reorder
   */
  /**
   * Emitted when the cache is cleared
   * @event clearCache
   * @property {string} upstream - The upstream to clear the cache
   */
  /**
   * Emitted when the upstream is removed
   * @event removeUpstream
   * @property {string} upstreamId - ID of the registry upstream association
   */
  emits: ['reorderUpstream', 'clearCache', 'removeUpstream'],
  computed: {
    name() {
      return this.upstream.name;
    },
    url() {
      return this.upstream.url;
    },
    id() {
      return this.upstream.id;
    },
    idFromGraphQL() {
      return getIdFromGraphQLId(this.id);
    },
    cacheSize() {
      return this.upstream.cacheSize;
    },
    cacheValidityHours() {
      return this.upstream.cacheValidityHours;
    },
    metadataCacheValidityHours() {
      return this.upstream.metadataCacheValidityHours;
    },
    canUpdate() {
      return this.glAbilities.updateVirtualRegistry;
    },
    canRemove() {
      return this.glAbilities.destroyVirtualRegistry;
    },
    removeUpstreamAriaLabel() {
      return sprintf(s__('VirtualRegistry|Remove upstream %{name}'), { name: this.upstream.name });
    },
    artifactCount() {
      return this.upstream.artifactCount;
    },
    editPath() {
      return this.editUpstreamPathTemplate.replace(':id', this.idFromGraphQL);
    },
    showPath() {
      return this.showUpstreamPathTemplate.replace(':id', this.idFromGraphQL);
    },
    isFirstUpstream() {
      return this.index === 0;
    },
    isLastUpstream() {
      return this.index === this.upstreamsCount - 1;
    },

    hasWarning() {
      return Boolean(this.upstream.warning);
    },
    warningText() {
      return this.upstream.warning?.text || this.$options.i18n.defaultWarningText;
    },
    showButtons() {
      return this.hasWarning || (this.canUpdate && this.editPath) || this.canRemove;
    },
    cacheSizeLabel() {
      return sprintf(s__('VirtualRegistry|Cache: %{size}'), { size: this.cacheSize });
    },
    cacheValidityHoursLabel() {
      return sprintf(
        n__(
          'VirtualRegistry|Artifact cache: %{hours} hour',
          'VirtualRegistry|Artifact cache: %{hours} hours',
          this.cacheValidityHours,
        ),
        { hours: this.cacheValidityHours },
      );
    },
    metadataCacheValidityHoursLabel() {
      return sprintf(
        n__(
          'VirtualRegistry|Metadata cache: %{hours} hour',
          'VirtualRegistry|Metadata cache: %{hours} hours',
          this.metadataCacheValidityHours,
        ),
        { hours: this.metadataCacheValidityHours },
      );
    },
    artifactCountLabel() {
      return sprintf(
        n__(
          'VirtualRegistry|%{count} artifact',
          'VirtualRegistry|%{count} artifacts',
          this.artifactCount,
        ),
        { count: this.artifactCount },
      );
    },
  },
  methods: {
    reorderUpstream(direction) {
      this.$emit('reorderUpstream', direction, this.upstream);
    },
    clearCache() {
      this.$emit('clearCache', this.upstream);
    },
    removeUpstream() {
      const { id } = this.upstream.registryUpstreams[0];
      this.$emit('removeUpstream', id);
    },
  },
  i18n: {
    moveUpLabel: s__('VirtualRegistry|Move upstream up'),
    moveDownLabel: s__('VirtualRegistry|Move upstream down'),
    clearCacheLabel: s__('VirtualRegistry|Clear cache'),
    editUpstreamLabel: s__('VirtualRegistry|Edit upstream'),
    removeUpstreamLabel: s__('VirtualRegistry|Remove upstream'),
    defaultWarningText: s__('VirtualRegistry|There is a problem with this cached upstream'),
  },
};
</script>
<template>
  <div
    data-testid="registry-upstream-item"
    class="gl-border gl-grid gl-grid-cols-[auto_1fr] gl-gap-3 gl-rounded-base gl-bg-default gl-p-3"
  >
    <div v-if="canUpdate" class="gl-flex gl-items-start gl-justify-between">
      <gl-button-group vertical>
        <gl-button
          size="small"
          icon="chevron-up"
          data-testid="reorder-up-button"
          :disabled="isFirstUpstream"
          :title="$options.i18n.moveUpLabel"
          :aria-label="$options.i18n.moveUpLabel"
          @click="reorderUpstream('up')"
        />
        <gl-button
          size="small"
          icon="chevron-down"
          data-testid="reorder-down-button"
          :disabled="isLastUpstream"
          :title="$options.i18n.moveDownLabel"
          :aria-label="$options.i18n.moveDownLabel"
          @click="reorderUpstream('down')"
        />
      </gl-button-group>
    </div>
    <div class="gl-flex gl-min-w-0 gl-flex-col gl-gap-3 @sm/panel:gl-flex-row">
      <div class="gl-flex gl-min-w-0 gl-flex-1 gl-flex-col gl-gap-2">
        <div
          class="gl-flex gl-min-w-0 gl-flex-col gl-flex-wrap gl-items-start gl-gap-x-2 @sm/panel:gl-flex-row @sm/panel:gl-items-center"
        >
          <gl-link
            :href="showPath"
            class="gl-mr-2 gl-min-w-0 gl-max-w-full gl-font-bold gl-text-default"
            data-testid="upstream-name"
          >
            <gl-truncate
              :text="name"
              class="gl-min-w-0 gl-max-w-full hover:gl-underline"
              with-tooltip
            />
          </gl-link>
          <span
            data-testid="upstream-url"
            class="gl-min-w-0 gl-max-w-full gl-overflow-hidden gl-text-default"
          >
            <gl-truncate :text="url" class="gl-min-w-0 gl-max-w-full" with-tooltip />
          </span>
        </div>
        <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-2">
          <div v-if="cacheSize" data-testid="cache-size">
            {{ cacheSizeLabel }}
          </div>
          <div v-if="cacheSize">&middot;</div>
          <div data-testid="cache-validity-hours">
            {{ cacheValidityHoursLabel }}
          </div>
          <div>&middot;</div>
          <div data-testid="metadata-cache-validity-hours">
            {{ metadataCacheValidityHoursLabel }}
          </div>
          <div v-if="artifactCount">&middot;</div>
          <div v-if="artifactCount" data-testid="artifact-count">
            {{ artifactCountLabel }}
          </div>
        </div>
      </div>
      <template v-if="showButtons">
        <div
          class="gl-flex gl-flex-wrap gl-items-start gl-gap-2 @sm/panel:gl-flex-nowrap @sm/panel:gl-justify-end"
        >
          <div v-if="hasWarning" data-testid="warning-badge">
            <button
              v-gl-tooltip="warningText"
              :title="warningText"
              type="button"
              class="gl-border-none gl-bg-transparent gl-p-0"
            >
              <gl-badge variant="warning" icon="status-alert" icon-size="sm" />
            </button>
          </div>
          <gl-button
            v-if="canUpdate"
            size="small"
            category="tertiary"
            data-testid="clear-cache-button"
            @click="clearCache"
          >
            {{ $options.i18n.clearCacheLabel }}</gl-button
          >
          <gl-button
            v-if="canUpdate && editPath"
            v-gl-tooltip="$options.i18n.editUpstreamLabel"
            data-testid="edit-button"
            :aria-label="$options.i18n.editUpstreamLabel"
            size="small"
            category="tertiary"
            icon="pencil"
            :href="editPath"
          />
          <gl-button
            v-if="canRemove"
            v-gl-tooltip="$options.i18n.removeUpstreamLabel"
            data-testid="remove-button"
            :aria-label="removeUpstreamAriaLabel"
            size="small"
            category="tertiary"
            icon="remove"
            @click="removeUpstream"
          />
        </div>
      </template>
    </div>
  </div>
</template>
