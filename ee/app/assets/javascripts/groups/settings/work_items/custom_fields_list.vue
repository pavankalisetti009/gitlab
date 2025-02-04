<script>
import {
  GlAlert,
  GlBadge,
  GlButton,
  GlIntersperse,
  GlLoadingIcon,
  GlSprintf,
  GlTable,
  GlTooltipDirective,
} from '@gitlab/ui';
import { humanize } from '~/lib/utils/text_utility';
import { __, n__, s__, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import TimeagoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import CustomFieldForm from './custom_field_form.vue';
import groupCustomFieldsQuery from './group_custom_fields.query.graphql';
import customFieldArchiveMutation from './custom_field_archive.mutation.graphql';

export default {
  components: {
    CustomFieldForm,
    GlAlert,
    GlBadge,
    GlButton,
    GlIntersperse,
    GlLoadingIcon,
    GlSprintf,
    GlTable,
    TimeagoTooltip,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['fullPath'],
  data() {
    return {
      customFields: [],
      customFieldsForList: [],
      archivingId: null,
      errorText: '',
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.customFields.loading;
    },
  },
  apollo: {
    customFields: {
      query: groupCustomFieldsQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          active: true,
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
        this.errorText = s__('WorkItem|Failed to load custom fields.');
        Sentry.captureException(error.message);
      },
    },
  },
  methods: {
    detailsToggleIcon(detailsVisible) {
      return detailsVisible ? 'chevron-down' : 'chevron-right';
    },
    dismissAlert() {
      this.errorText = '';
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
    archiveButtonText(item) {
      return sprintf(s__('WorkItem|Archive %{itemName}'), { itemName: item.name });
    },
    async archiveCustomField(id) {
      this.archivingId = id;

      try {
        await this.executeArchiveMutation(id);
      } catch (error) {
        this.handleArchiveError(error);
      } finally {
        this.archivingId = null;
      }
    },
    async executeArchiveMutation(id) {
      const field = this.getFieldById(id);
      const optimisticResponse = this.createOptimisticResponse(field);

      const { data } = await this.$apollo.mutate({
        mutation: customFieldArchiveMutation,
        variables: { id },
        optimisticResponse,
        update: this.updateCacheAfterArchive,
      });

      if (data?.customFieldArchive?.errors?.length) {
        throw new Error(data.customFieldArchive.errors.join(', '));
      }
    },
    getFieldById(id) {
      return this.customFieldsForList.find((f) => f.id === id);
    },
    createOptimisticResponse(field) {
      return {
        customFieldArchive: {
          __typename: 'CustomFieldArchivePayload',
          customField: {
            __typename: 'CustomField',
            id: field.id,
            name: field.name,
            fieldType: field.fieldType,
          },
          errors: [],
        },
      };
    },

    updateCacheAfterArchive(cache, { data: { customFieldArchive } }) {
      if (customFieldArchive?.errors?.length) return;

      const queryParams = {
        query: groupCustomFieldsQuery,
        variables: { fullPath: this.fullPath, active: true },
      };

      const prevData = cache.readQuery(queryParams);
      if (!prevData?.group?.customFields) return;

      const updatedCustomFields = {
        ...prevData.group.customFields,
        nodes: prevData.group.customFields.nodes.filter(
          (node) => node.id !== customFieldArchive.customField.id,
        ),
        count: prevData.group.customFields.count - 1,
      };

      cache.writeQuery({
        ...queryParams,
        data: {
          group: {
            ...prevData.group,
            customFields: updatedCustomFields,
          },
        },
      });
    },

    handleArchiveError(error) {
      this.errorText = s__('WorkItem|Failed to archive custom field.');
      Sentry.captureException(error);
    },
  },
  fields: [
    {
      key: 'show_details',
      label: s__('WorkItem|Toggle details'),
      class: 'gl-w-0 !gl-align-middle',
      thClass: 'gl-sr-only',
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
      class: '!gl-align-middle',
    },
  ],
};
</script>

<template>
  <div>
    <gl-alert
      v-if="errorText"
      variant="danger"
      :dismissible="true"
      class="gl-mb-5"
      data-testid="alert"
      @dismiss="dismissAlert"
    >
      {{ errorText }}
    </gl-alert>
    <div
      class="gl-font-lg gl-border gl-flex gl-items-center gl-rounded-t-base gl-border-b-0 gl-px-5 gl-py-4 gl-font-bold"
    >
      {{ s__('WorkItem|Active custom fields') }}
      <gl-badge v-if="!isLoading" class="gl-mx-4">
        <!-- eslint-disable-next-line @gitlab/vue-require-i18n-strings -->
        {{ customFields.count }}/50
      </gl-badge>

      <custom-field-form class="gl-ml-auto" @created="$apollo.queries.customFields.refetch()" />
    </div>
    <gl-table
      :items="customFieldsForList"
      :fields="$options.fields"
      :busy="isLoading"
      outlined
      responsive
      class="gl-rounded-b-base !gl-bg-gray-10"
    >
      <template #table-busy>
        <gl-loading-icon size="lg" class="gl-my-5" />
      </template>
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
        <div class="gl-text-subtle">{{ selectOptionsText(item) }}</div>
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
      <template #head(actions)>
        <div class="gl-ml-auto">{{ __('Actions') }}</div>
      </template>
      <template #cell(actions)="{ item }">
        <div class="gl-align-items-center gl-end gl-flex gl-justify-end gl-gap-1">
          <custom-field-form
            :custom-field-id="item.id"
            :custom-field-name="item.name"
            @updated="$apollo.queries.customFields.refetch()"
          />
          <gl-button
            v-gl-tooltip="archiveButtonText(item)"
            :aria-label="archiveButtonText(item)"
            icon="archive"
            category="tertiary"
            data-testid="archiveButton"
            @click="archiveCustomField(item.id)"
          />
        </div>
      </template>
      <template #row-details="{ item }">
        <div class="gl-border gl-col-span-5 gl-mt-3 gl-rounded-lg gl-bg-default gl-p-5">
          <dl class="gl-mb-3 gl-flex gl-gap-3">
            <dt>{{ s__('WorkItem|Usage:') }}</dt>
            <dd>
              <gl-intersperse>
                <span v-for="workItemType in item.workItemTypes" :key="workItemType.id">{{
                  workItemType.name
                }}</span>
              </gl-intersperse>
            </dd>
          </dl>
          <dl v-if="item.selectOptions.length > 0" class="gl-mb-3">
            <dt>{{ s__('WorkItem|Options:') }}</dt>
            <dd>
              <ul>
                <li v-for="option in item.selectOptions" :key="option.id">
                  {{ option.value }}
                </li>
              </ul>
            </dd>
          </dl>
          <div class="gl-text-sm gl-text-subtle">
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
