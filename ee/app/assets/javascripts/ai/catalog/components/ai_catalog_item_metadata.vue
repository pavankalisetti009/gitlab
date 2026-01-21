<script>
import { GlIcon } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import { getLatestUpdatedAt, getByVersionKey } from 'ee/ai/catalog/utils';
import { AI_CATALOG_TYPE_FLOW } from '../constants';

export default {
  name: 'AiCatalogItemMetadata',
  components: {
    GlIcon,
  },
  mixins: [timeagoMixin],
  props: {
    item: {
      type: Object,
      required: true,
    },
    versionKey: {
      type: String,
      required: true,
    },
  },
  computed: {
    latestUpdatedAt() {
      return getLatestUpdatedAt(this.item);
    },
    metaData() {
      const items = [
        {
          text: __('Created on'),
          icon: 'calendar',
          value: formatDate(this.item.createdAt, 'mmmm d, yyyy'),
          testId: 'created-on',
        },
      ];

      if (this.item.foundational) {
        const foundationalText =
          this.item.itemType === AI_CATALOG_TYPE_FLOW
            ? s__('AICatalog|Foundational flow')
            : s__('AICatalog|Foundational agent');

        items.push({
          text: foundationalText,
          icon: 'tanuki-verified',
          value: '',
          testId: 'foundational',
        });
      }

      if (this.latestUpdatedAt !== this.item.createdAt) {
        items.push({
          text: __('Modified'),
          icon: 'clock',
          value: this.timeFormatted(this.latestUpdatedAt),
          testId: 'modified',
        });
      }

      const version = getByVersionKey(this.item, this.versionKey).humanVersionName;
      items.push({
        icon: 'tag',
        value: version,
        testId: 'version',
      });

      return items;
    },
  },
  methods: {
    formatText(text, value) {
      return [text, value].join(' ');
    },
  },
};
</script>

<template>
  <div>
    <ul class="gl-flex gl-list-none gl-flex-row gl-flex-wrap gl-gap-x-5 gl-gap-y-3 gl-pl-0">
      <li
        v-for="metaItem in metaData"
        :key="metaItem.testId"
        :data-testid="`metadata-${metaItem.testId}`"
        class="gl-flex gl-items-center gl-gap-3"
      >
        <gl-icon :name="metaItem.icon" variant="subtle" class="gl-mb-px" />
        <span>{{ formatText(metaItem.text, metaItem.value) }}</span>
      </li>
    </ul>
  </div>
</template>
