<script>
import {
  GlTableLite,
  GlButtonGroup,
  GlButton,
  GlIcon,
  GlTooltipDirective,
  GlLink,
  GlPopover,
} from '@gitlab/ui';
import { __ } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import AvailableSecurityScanProfiles from '../graphql/available_security_scan_profiles.query.graphql';
import { SCANNER_TYPES, SECRET_PUSH_PROTECTION_KEY } from '../constants';

export default {
  name: 'BulkScannerProfileConfiguration',
  components: {
    CrudComponent,
    GlTableLite,
    GlButtonGroup,
    GlButton,
    GlIcon,
    GlLink,
    GlPopover,
  },
  directives: { GlTooltip: GlTooltipDirective },
  inject: ['groupFullPath'],
  emits: ['attach-profile', 'detach-profile', 'preview-profile'],
  data() {
    return {
      group: {
        availableSecurityScanProfiles: [],
      },
    };
  },
  apollo: {
    group: {
      query: AvailableSecurityScanProfiles,
      variables() {
        return {
          fullPath: this.groupFullPath,
          gitlabRecommended: true,
        };
      },
    },
  },
  computed: {
    scanTypeLabel() {
      return (scanType) => this.$options.SCANNER_CATEGORIES[scanType]?.label || '';
    },
    scanTypeName() {
      return (scanType) => this.$options.SCANNER_CATEGORIES[scanType]?.name || __('Unknown');
    },
  },
  methods: {
    profileText(profile) {
      switch (profile.status) {
        case 'applied':
          return profile.name;
        case 'mixed':
          return __('Mixed');
        case 'disabled':
        default:
          return __('No profile applied');
      }
    },
    statusClasses(status) {
      switch (status) {
        case 'applied':
          return 'gl-bg-feedback-success gl-border-feedback-success gl-text-feedback-success';
        case 'disabled':
          return 'gl-bg-feedback-danger gl-border-feedback-danger gl-text-feedback-danger';
        case 'mixed':
        default:
          return 'gl-bg-feedback-neutral gl-border-feedback-neutral gl-text-feedback-neutral';
      }
    },
  },
  SCANNER_CATEGORIES: {
    SECRET_DETECTION: {
      name: SCANNER_TYPES[SECRET_PUSH_PROTECTION_KEY].name,
      label: SCANNER_TYPES[SECRET_PUSH_PROTECTION_KEY].textLabel,
    },
  },
  fields: [
    {
      key: 'scanType',
      label: __('Scanner'),
    },
    {
      key: 'actions',
      label: '',
      tdClass: '!gl-flex gl-justify-end gl-gap-3 !gl-border-t-0',
    },
  ],
};
</script>

<template>
  <div>
    <crud-component header-class="gl-hidden">
      <gl-table-lite
        :items="group.availableSecurityScanProfiles"
        :fields="$options.fields"
        stacked="md"
      >
        <template #cell(scanType)="{ item }">
          <div data-testid="scan-type-cell" class="gl-flex gl-items-center">
            <div
              class="gl-border gl-mr-3 gl-flex gl-items-center gl-justify-center gl-rounded-base gl-p-2"
              :class="statusClasses(item.status)"
              data-testid="scan-type-icon"
              style="width: 32px; height: 32px"
            >
              <span class="gl-font-weight-bold gl-font-sm">
                {{ scanTypeLabel(item.scanType) }}
              </span>
            </div>
            <span class="gl-font-bold">
              {{ scanTypeName(item.scanType) }}
            </span>
          </div>
        </template>

        <template #cell(name)="{ item }">
          <div data-testid="profile-name-cell" class="gl-flex gl-h-7 gl-items-center">
            <gl-link v-if="item.status === 'applied'" href="#">
              {{ profileText(item) }}
            </gl-link>
            <span v-else :class="{ 'gl-italic': item.status === 'mixed' }">
              {{ profileText(item) }}
            </span>
            <template v-if="item.status === 'mixed'">
              <gl-icon
                :id="`${item.id}-profile`"
                name="information-o"
                class="gl-link gl-ml-2 gl-shrink-0"
              />
              <gl-popover :target="`${item.id}-profile`">
                {{
                  __(
                    'The selected projects use different configuration profiles. Choosing a new profile will replace their existing ones.',
                  )
                }}
              </gl-popover>
            </template>
            <template v-if="item.status === 'applied' && item.description">
              <gl-icon
                :id="`${item.id}-profile`"
                name="information-o"
                class="gl-link gl-ml-2 gl-shrink-0"
              />
              <gl-popover :target="`${item.id}-profile`">
                {{ item.description }}
              </gl-popover>
            </template>
          </div>
        </template>

        <template #cell(actions)="{ item }">
          <div data-testid="actions-cell" class="gl-flex gl-flex-wrap gl-justify-end gl-gap-3">
            <gl-button-group v-if="item.status !== 'applied'">
              <gl-button
                data-testid="apply-default-profile-button"
                variant="confirm"
                category="secondary"
                @click="$emit('attach-profile', item)"
              >
                {{ __('Apply default profile to all') }}
              </gl-button>
              <gl-button
                v-gl-tooltip
                data-testid="preview-default-profile-button"
                :title="__('Preview default profile')"
                :aria-label="__('Preview default profile')"
                variant="confirm"
                category="secondary"
                icon="eye"
                icon-only
                @click="$emit('preview-profile', item)"
              />
            </gl-button-group>
            <gl-button
              v-if="item.status !== 'disabled'"
              data-testid="disable-for-all-button"
              variant="danger"
              category="secondary"
              @click="$emit('detach-profile', item)"
            >
              {{ __('Disable for all') }}
            </gl-button>
          </div>
        </template>
      </gl-table-lite>
    </crud-component>
  </div>
</template>
