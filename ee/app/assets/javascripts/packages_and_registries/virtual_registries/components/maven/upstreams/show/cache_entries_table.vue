<script>
import {
  GlBadge,
  GlButton,
  GlIcon,
  GlLoadingIcon,
  GlModal,
  GlSprintf,
  GlTable,
  GlTooltipDirective,
} from '@gitlab/ui';
import { __ } from '~/locale';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { numberToHumanSize } from '~/lib/utils/number_utils';

export default {
  name: 'MavenUpstreamDetails',
  components: {
    GlBadge,
    GlButton,
    GlIcon,
    GlLoadingIcon,
    GlModal,
    GlSprintf,
    GlTable,
    TimeAgoTooltip,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glAbilitiesMixin()],
  props: {
    cacheEntries: {
      type: Array,
      required: true,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      cacheEntryToBeDeleted: null,
      showDeleteModal: false,
    };
  },
  computed: {
    canDelete() {
      return this.glAbilities.destroyVirtualRegistry;
    },
  },
  methods: {
    handleDelete(item) {
      this.cacheEntryToBeDeleted = item;
      this.showDeleteModal = true;
    },
    hideModal() {
      this.showDeleteModal = false;
      this.cacheEntryToBeDeleted = null;
    },
    formatSize(size) {
      return numberToHumanSize(size);
    },
  },
  fields: [
    {
      key: 'relative_path',
      label: __('Artifact'),
      thClass: 'gl-w-3/5',
    },
    {
      key: 'size',
      label: __('Size'),
      tdClass: '!gl-align-middle',
    },
    {
      key: 'actions',
      label: __('Actions'),
      thAlignRight: true,
      thClass: 'gl-w-26',
    },
  ],
  modal: {
    primaryAction: {
      text: __('Delete'),
      attributes: {
        variant: 'danger',
        category: 'primary',
      },
    },
    cancelAction: {
      text: __('Cancel'),
    },
  },
};
</script>

<template>
  <div>
    <gl-table
      :fields="$options.fields"
      :items="cacheEntries"
      stacked="sm"
      :tbody-tr-attr="{ 'data-testid': 'cache-entry-row' }"
      :busy="loading"
      show-empty
    >
      <template #table-busy>
        <gl-loading-icon size="lg" class="gl-mt-5" />
      </template>

      <template #empty>
        <p class="gl-mb-0 gl-text-center gl-text-subtle">
          {{ s__('VirtualRegistry|No artifacts to display.') }}
        </p>
      </template>

      <template #cell(relative_path)="{ item }">
        <div class="gl-mb-3">
          <gl-icon name="doc-text" />
          <span class="gl-ml-2 gl-text-subtle" data-testid="relative-path">{{
            item.relative_path
          }}</span>
        </div>
        <gl-badge>{{ item.content_type }}</gl-badge>
      </template>

      <template #cell(size)="{ item }">
        <span data-testid="artifact-size">{{ formatSize(item.size) }}</span>
      </template>

      <template #cell(actions)="{ item }">
        <div class="gl-flex gl-flex-col gl-items-end">
          <gl-button
            v-if="canDelete"
            v-gl-tooltip="__('Delete')"
            class="gl-mb-3"
            :aria-label="__('Delete')"
            size="small"
            category="tertiary"
            icon="remove"
            data-testid="delete-cache-entry-btn"
            @click="handleDelete(item)"
          />
          <div class="gl-text-sm gl-text-subtle">
            <gl-sprintf :message="s__('VirtualRegistry|last checked %{date}')">
              <template #date>
                <time-ago-tooltip :time="item.upstream_checked_at" />
              </template>
            </gl-sprintf>
          </div>
        </div>
      </template>
    </gl-table>
    <gl-modal
      v-model="showDeleteModal"
      modal-id="delete-cache-entry-modal"
      size="sm"
      :action-primary="$options.modal.primaryAction"
      :action-cancel="$options.modal.cancelAction"
      :title="s__('VirtualRegistry|Delete Maven upstream cache entry?')"
      @primary="$emit('delete', { id: cacheEntryToBeDeleted.id })"
      @canceled="hideModal"
    >
      <gl-sprintf
        v-if="cacheEntryToBeDeleted"
        :message="s__('VirtualRegistry|Are you sure you want to delete %{name}?')"
      >
        <template #name>
          <strong>{{ cacheEntryToBeDeleted.relative_path }}</strong>
        </template>
      </gl-sprintf>
    </gl-modal>
  </div>
</template>
