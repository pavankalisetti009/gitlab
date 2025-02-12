<script>
import {
  GlTabs,
  GlTab,
  GlBadge,
  GlTable,
  GlPagination,
  GlDisclosureDropdown,
  GlSprintf,
  GlLink,
  GlButton,
} from '@gitlab/ui';
import { mapActions, mapState } from 'pinia';
import { s__ } from '~/locale';

import PageHeading from '~/vue_shared/components/page_heading.vue';
import { useServiceAccounts } from '../../stores/service_accounts';

const PAGE_SIZE = 8;

export default {
  components: {
    GlTabs,
    GlTab,
    GlBadge,
    GlTable,
    GlSprintf,
    GlLink,
    GlPagination,
    GlButton,
    GlDisclosureDropdown,
    PageHeading,
  },
  inject: ['serviceAccountsPath', 'serviceAccountsDocsPath'],
  data() {
    return {
      currentPage: 1,
    };
  },
  computed: {
    ...mapState(useServiceAccounts, ['serviceAccounts', 'serviceAccountCount', 'busy']),
  },
  created() {
    this.fetchServiceAccounts(this.serviceAccountsPath, {
      page: this.currentPage,
      perPage: this.$options.PAGE_SIZE,
    });
  },
  methods: {
    ...mapActions(useServiceAccounts, ['fetchServiceAccounts', 'addServiceAccount']),
    pageServiceAccounts(page) {
      this.fetchServiceAccounts(this.serviceAccountsPath, {
        page,
        perPage: this.$options.PAGE_SIZE,
      });
    },
  },
  fields: [
    {
      key: 'name',
      label: s__('ServiceAccounts|Name'),
      thAttr: { 'data-testid': 'header-name' },
    },
    {
      key: 'options',
      label: '',
      tdClass: 'gl-text-end',
      tdAttr: { 'data-testid': 'cell-options' },
    },
  ],
  optionsItems: [
    {
      text: s__('ServiceAccounts|Manage Access Tokens'),
    },
    {
      text: s__('ServiceAccounts|Edit'),
    },
    {
      text: s__('ServiceAccounts|Delete Account'),
      variant: 'danger',
    },
    {
      text: s__('ServiceAccounts|Delete Account and Contributions'),
      variant: 'danger',
    },
  ],
  i18n: {
    title: s__('ServiceAccounts|Service Accounts'),
    titleDescription: s__(
      'ServiceAccounts|Service accounts are non-human accounts that allow interactions between software applications, systems, or services. %{learnMore}',
    ),
    addServiceAccount: s__('ServiceAccounts|Add Service Account'),
  },
  PAGE_SIZE,
};
</script>

<template>
  <div>
    <page-heading :heading="$options.i18n.title">
      <template #description>
        <gl-sprintf :message="$options.i18n.titleDescription">
          <template #learnMore>
            <gl-link :href="serviceAccountsDocsPath">{{ __('Learn more') }}</gl-link>
          </template>
        </gl-sprintf>
      </template>

      <template #actions>
        <gl-button variant="confirm" @click="addServiceAccount">
          {{ $options.i18n.addServiceAccount }}
        </gl-button>
      </template>
    </page-heading>

    <gl-tabs>
      <gl-tab>
        <template #title>
          <span>{{ $options.i18n.title }}</span>
          <gl-badge class="gl-tab-counter-badge">{{ serviceAccountCount }}</gl-badge>
        </template>

        <gl-table
          :items="serviceAccounts"
          :fields="$options.fields"
          :per-page="$options.PAGE_SIZE"
          :busy="busy"
        >
          <template #cell(name)="{ item }">
            <div class="gl-font-bold" data-testid="service-account-name">{{ item.name }}</div>
            <div data-testid="service-account-username">{{ item.username }}</div>
          </template>

          <template #cell(options)>
            <gl-disclosure-dropdown
              :disabled="busy"
              icon="ellipsis_v"
              :no-caret="true"
              category="tertiary"
              :fluid-width="true"
              :items="$options.optionsItems"
            />
          </template>
        </gl-table>

        <gl-pagination
          v-model="currentPage"
          :disabled="busy"
          :per-page="$options.PAGE_SIZE"
          :total-items="serviceAccountCount"
          align="center"
          @input="pageServiceAccounts"
        />
      </gl-tab>
    </gl-tabs>
  </div>
</template>
