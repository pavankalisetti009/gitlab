<script>
import { nextTick } from 'vue';
import { GlFilteredSearch } from '@gitlab/ui';
import { isEqual } from 'lodash';
import { ALL_ID } from 'ee/security_dashboard/components/shared/filters/constants';

export default {
  components: {
    GlFilteredSearch,
  },
  props: {
    tokens: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      filters: {},
      value: [],
    };
  },
  created() {
    const params = new URLSearchParams(window.location.search);

    const { initialValue, newFilters } = this.tokens.reduce(
      (acc, token) => {
        const paramValue = params.get(token.type);
        const data = paramValue?.split(',').filter(Boolean);

        if (data?.length > 0) {
          acc.newFilters[token.type] = data;
          acc.initialValue.push({
            type: token.type,
            value: {
              data,
              operator: token.operators[0]?.value,
            },
          });
        }

        return acc;
      },
      { initialValue: [], newFilters: {} },
    );

    this.value = initialValue;
    this.updateFilters(newFilters);
  },
  methods: {
    getTokenValue(type) {
      const token = this.value.find((t) => t.type === type);
      return token?.value?.data?.filter((v) => v !== ALL_ID);
    },
    updateFilters(newFilters) {
      if (isEqual(newFilters, this.filters)) return;

      this.filters = newFilters;
      this.$emit('filters-changed', this.filters);
    },
    updateUrlParams() {
      const params = this.tokens.reduce((acc, { type }) => {
        const filterValue = this.filters[type];
        if (filterValue?.length > 0) {
          acc.set(type, filterValue.join(','));
        } else {
          acc.delete(type);
        }
        return acc;
      }, new URLSearchParams(window.location.search));

      const newUrl = params.toString()
        ? `${window.location.pathname}?${params.toString()}`
        : window.location.pathname;
      window.history.pushState({}, '', newUrl);
    },
    async handleTokenComplete({ type }) {
      // Need to wait for `this.value` to have been updated
      await nextTick();

      const value = this.getTokenValue(type);
      if (!value) return;

      const newFilters = { ...this.filters, [type]: value };
      this.updateFilters(newFilters);
      this.updateUrlParams();
    },
    handleTokenDestroy({ type }) {
      const { [type]: removed, ...rest } = this.filters;
      const newFilters = rest;
      this.updateFilters(newFilters);
      this.updateUrlParams();
    },
    clear() {
      this.updateFilters({});
      this.updateUrlParams();
    },
  },
};
</script>
<template>
  <gl-filtered-search
    v-model="value"
    :placeholder="s__('SecurityReports|Filter results...')"
    :available-tokens="tokens"
    @token-complete="handleTokenComplete"
    @token-destroy="handleTokenDestroy"
    @clear="clear"
  />
</template>
