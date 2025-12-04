<script>
import { GlIcon } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import { getLatestUpdatedAt } from 'ee/ai/catalog/utils';

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
    versionData: {
      type: Object,
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
        items.push({
          text: s__('AICatalog|Foundational agent'),
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

      items.push({
        icon: 'tag',
        value: this.versionData.humanVersionName,
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
  <aside>
    <h3 class="gl-heading-3 gl-mb-4 gl-mt-0 gl-font-semibold">{{ __('About') }}</h3>
    <ul class="gl-flex gl-list-none gl-flex-col gl-gap-3 gl-pl-0">
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
  </aside>
</template>
