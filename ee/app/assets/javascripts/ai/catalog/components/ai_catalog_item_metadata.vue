<script>
import { GlIcon } from '@gitlab/ui';
import { __ } from '~/locale';
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
  },
  computed: {
    latestUpdatedAt() {
      return getLatestUpdatedAt(this.item);
    },
    metaData() {
      const showUpdatedAt = this.latestUpdatedAt !== this.item.createdAt;
      return [
        {
          text: __('Created on'),
          icon: 'calendar',
          value: formatDate(this.item.createdAt, 'mmmm d, yyyy'),
        },
        ...(showUpdatedAt
          ? [
              {
                text: __('Modified'),
                icon: 'clock',
                value: this.timeFormatted(this.latestUpdatedAt),
              },
            ]
          : []),
      ];
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
        :key="metaItem.field"
        class="gl-flex gl-items-center gl-gap-3"
      >
        <gl-icon :name="metaItem.icon" variant="subtle" class="gl-mb-px" />
        <span>{{ formatText(metaItem.text, metaItem.value) }}</span>
      </li>
    </ul>
  </aside>
</template>
