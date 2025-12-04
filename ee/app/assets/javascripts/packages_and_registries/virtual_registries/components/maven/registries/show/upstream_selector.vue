<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { debounce } from 'lodash';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { getMavenUpstreamRegistriesList } from 'ee/api/virtual_registries_api';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';

const PAGE_SIZE = 20;

export default {
  name: 'MavenUpstreamSelector',
  components: {
    GlCollapsibleListbox,
  },
  inject: ['groupPath'],
  props: {
    linkedUpstreams: {
      type: Array,
      required: true,
    },
    initialUpstreams: {
      type: Array,
      required: true,
    },
    upstreamsCount: {
      type: Number,
      required: true,
    },
  },
  emits: ['select'],
  data() {
    return {
      searchTerm: '',
      page: 1,
      selectedUpstream: null,
      isFetchingUpstreams: false,
      upstreams: this.initialUpstreams,
      totalUpstreamsCount: this.upstreamsCount,
    };
  },
  computed: {
    upstreamItemIdsMap() {
      return this.linkedUpstreams.reduce(
        (map, { id }) => ({
          ...map,
          [getIdFromGraphQLId(id)]: true,
        }),
        {},
      );
    },
    linkableUpstreams() {
      return (
        this.upstreams
          // filter out upstreams that are already linked to this virtual registry
          .filter((upstream) => {
            return !this.upstreamItemIdsMap[upstream.id];
          })
      );
    },
    linkableUpstreamsDropdownOptions() {
      return this.linkableUpstreams.map((upstream) => {
        return {
          value: upstream.id,
          text: upstream.name,
          secondaryText: upstream.description,
        };
      });
    },
    selectedUpstreamName() {
      return (
        this.linkableUpstreams.find((upstream) => upstream.id === this.selectedUpstream)?.name ?? ''
      );
    },
  },
  created() {
    this.debouncedSearchUpstream = debounce(this.searchUpstream, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  methods: {
    async fetchUpstreams() {
      this.isFetchingUpstreams = true;
      try {
        const { data, headers } = await getMavenUpstreamRegistriesList({
          id: this.groupPath,
          params: {
            upstream_name: this.searchTerm,
            page: this.page,
            per_page: PAGE_SIZE,
          },
        });
        this.totalUpstreamsCount = Number(headers['x-total']) || 0;

        if (this.page === 1) {
          this.upstreams = data;
        } else {
          this.upstreams = this.upstreams.concat(data);
        }
      } catch (error) {
        captureException({ error, component: this.$options.name });
      } finally {
        this.isFetchingUpstreams = false;
      }
    },
    searchUpstream(searchTerm = '') {
      this.searchTerm = searchTerm;
      this.page = 1;
      this.fetchUpstreams();
    },
    fetchNextPage() {
      if (this.isFetchingUpstreams || this.upstreams.length === this.totalUpstreamsCount) {
        return;
      }

      this.page += 1;
      this.fetchUpstreams();
    },
    handleSelect(upstreamId) {
      this.$emit('select', upstreamId);
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    v-model="selectedUpstream"
    block
    toggle-id="upstream-select"
    :toggle-text="selectedUpstreamName"
    :items="linkableUpstreamsDropdownOptions"
    infinite-scroll
    searchable
    :no-results-text="__('No matching results')"
    :infinite-scroll-loading="isFetchingUpstreams"
    @select="handleSelect"
    @search="debouncedSearchUpstream"
    @bottom-reached="fetchNextPage"
  >
    <template #list-item="{ item }">
      <div class="gl-whitespace-nowrap">{{ item.text }}</div>
      <div class="gl-text-subtle">{{ item.secondaryText }}</div>
    </template>
  </gl-collapsible-listbox>
</template>
