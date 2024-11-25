<script>
import { GlBadge, GlButton, GlIntersperse, GlSprintf, GlTable } from '@gitlab/ui';
import { humanize } from '~/lib/utils/text_utility';
import { __, n__, s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import TimeagoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import CreateCustomField from './create_custom_field.vue';
import groupCustomFieldsQuery from './group_custom_fields.query.graphql';

export default {
  components: {
    CreateCustomField,
    GlBadge,
    GlButton,
    GlIntersperse,
    GlSprintf,
    GlTable,
    TimeagoTooltip,
  },
  inject: ['fullPath'],
  data() {
    return {
      customFields: [],
      customFieldsForList: [],
    };
  },
  apollo: {
    customFields: {
      query: groupCustomFieldsQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.group.customFields;
      },
      result() {
        // need a copy of the apollo query response as the table adds
        // properties to it for showing the detail view
        // prevents "Cannot add property _showDetails, object is not extensible" error
        this.customFieldsForList = this.customFields?.nodes?.map((field) => ({ ...field })) ?? [];
      },
      error(error) {
        Sentry.captureException(error.message);
      },
    },
  },
  methods: {
    detailsToggleIcon(detailsVisible) {
      return detailsVisible ? 'chevron-down' : 'chevron-right';
    },
    formattedFieldType(item) {
      return humanize(item.fieldType.toLowerCase());
    },
    selectOptionsText(item) {
      if (item.selectOptions.length > 0) {
        return n__('%d option', '%d options', item.selectOptions.length);
      }
      return null;
    },
  },
  fields: [
    {
      key: 'show_details',
      label: '',
      class: 'gl-w-0 !gl-align-middle',
    },
    {
      key: 'name',
      label: s__('WorkItem|Field'),
      class: '!gl-align-middle',
    },
    {
      key: 'fieldType',
      label: s__('WorkItem|Type'),
      class: '!gl-align-middle',
    },
    {
      key: 'usage',
      label: s__('WorkItem|Usage'),
      class: '!gl-align-middle',
    },
    {
      key: 'lastModified',
      label: __('Last modified'),
      class: '!gl-align-middle',
    },
    {
      key: 'actions',
      label: __('Actions'),
      class: 'gl-w-0 gl-text-right',
    },
  ],
};
</script>

<template>
  <div>
    <div
      class="gl-font-lg gl-border gl-flex gl-items-center gl-rounded-t-base gl-border-b-0 gl-px-5 gl-py-4 gl-font-bold"
    >
      {{ s__('WorkItem|Active custom fields') }}
      <gl-badge v-if="!$apollo.queries.customFields.loading" class="gl-mx-4">
        <!-- eslint-disable-next-line @gitlab/vue-require-i18n-strings -->
        {{ customFields.count }}/50
      </gl-badge>

      <create-custom-field class="gl-ml-auto" @created="$apollo.queries.customFields.refetch()" />
    </div>
    <gl-table
      :items="customFieldsForList"
      :fields="$options.fields"
      outlined
      responsive
      class="gl-rounded-b-base !gl-bg-gray-10"
    >
      <template #cell(show_details)="row">
        <gl-button
          :aria-label="s__('WorkItem|Toggle details')"
          :icon="detailsToggleIcon(row.detailsShowing)"
          category="tertiary"
          class="gl-align-self-flex-start"
          data-testid="toggleDetailsButton"
          @click="row.toggleDetails"
        />
      </template>
      <template #cell(name)="{ item }">
        {{ item.name }}
      </template>
      <template #cell(fieldType)="{ item }">
        {{ formattedFieldType(item) }}
        <div class="gl-text-secondary">{{ selectOptionsText(item) }}</div>
      </template>
      <template #cell(usage)="{ item }">
        <gl-intersperse>
          <span v-for="workItemType in item.workItemTypes" :key="workItemType.id">{{
            workItemType.name
          }}</span>
        </gl-intersperse>
      </template>
      <template #cell(lastModified)="{ item }">
        <timeago-tooltip :time="item.updatedAt" />
      </template>
      <template #cell(actions)>
        <gl-button :aria-label="s__('WorkItem|Edit field')" icon="pencil" category="tertiary" />
      </template>
      <template #row-details="{ item }">
        <div class="gl-border gl-col-span-5 gl-mt-3 gl-rounded-lg gl-bg-default gl-p-5">
          <div class="gl-mb-3 gl-flex gl-gap-3">
            <dt>{{ s__('WorkItem|Usage:') }}</dt>
            <dd>
              <gl-intersperse>
                <span v-for="workItemType in item.workItemTypes" :key="workItemType.id">{{
                  workItemType.name
                }}</span>
              </gl-intersperse>
            </dd>
          </div>
          <div v-if="item.selectOptions.length > 0" class="gl-mb-3">
            <dt>{{ s__('WorkItem|Options:') }}</dt>
            <dd>
              <ul>
                <li v-for="option in item.selectOptions" :key="option.id">
                  {{ option.value }}
                </li>
              </ul>
            </dd>
          </div>
          <div class="gl-text-sm gl-text-secondary">
            <gl-sprintf :message="s__('WorkItem|Last updated %{timeago}')">
              <template #timeago>
                <timeago-tooltip :time="item.updatedAt" />
              </template>
            </gl-sprintf>
            &middot;
            <gl-sprintf :message="s__('WorkItem|Created %{timeago}')">
              <template #timeago>
                <timeago-tooltip :time="item.updatedAt" />
              </template>
            </gl-sprintf>
          </div>
        </div>
      </template>
    </gl-table>
  </div>
</template>

<style>
/* remove border between row and details row */
.gl-table tr.b-table-has-details td {
  border-bottom-style: none;
}
</style>
