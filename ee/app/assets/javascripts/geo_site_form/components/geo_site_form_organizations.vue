<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { n__, s__ } from '~/locale';
import organizationsQuery from '~/organizations/shared/graphql/queries/organizations.query.graphql';
import { SELECTIVE_SYNC_ORGANIZATIONS } from 'ee/geo_site_form/constants';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { createAlert } from '~/alert';

export default {
  name: 'GeoSiteFormOrganizations',
  components: {
    GlCollapsibleListbox,
  },
  props: {
    selectedOrganizationIds: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  apollo: {
    organizations: {
      query: organizationsQuery,
      update(data) {
        if (!data?.organizations?.nodes) return [];

        return data.organizations.nodes.map((node) => ({
          text: node.name,
          value: getIdFromGraphQLId(node.id),
        }));
      },
      result({ data }) {
        if (!data?.organizations?.pageInfo) return;

        this.pageInfo = data.organizations.pageInfo;
      },
      error(error) {
        createAlert({
          message: s__("Geo|There was an error fetching the Site's Organizations"),
          error,
          captureError: true,
        });
      },
    },
  },
  data() {
    return {
      organizations: [],
      pageInfo: {},
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.organizations.loading;
    },
    dropdownTitle() {
      const selectedCount = this.selectedOrganizationIds.length;
      return selectedCount
        ? n__('Geo|%d organization selected', 'Geo|%d organizations selected', selectedCount)
        : s__('Geo|Select organizations to replicate');
    },
  },
  methods: {
    handleSelect(items) {
      this.$emit('updateSyncOptions', { key: SELECTIVE_SYNC_ORGANIZATIONS, value: items });
    },
    loadMoreOrganizations() {
      if (!this.pageInfo?.hasNextPage) return;

      this.$apollo.queries.organizations.fetchMore({
        variables: { after: this.pageInfo.endCursor },
        updateQuery: (previousResult, { fetchMoreResult }) => {
          if (!fetchMoreResult?.organizations?.nodes?.length) return previousResult;

          return {
            organizations: {
              ...fetchMoreResult.organizations,
              nodes: [
                ...previousResult.organizations.nodes,
                ...fetchMoreResult.organizations.nodes,
              ],
            },
          };
        },
      });
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    :items="organizations"
    :selected="selectedOrganizationIds"
    :toggle-text="dropdownTitle"
    :searching="isLoading"
    :no-results-text="s__('Geo|Nothing found…')"
    multiple
    infinite-scroll
    @select="handleSelect"
    @bottom-reached="loadMoreOrganizations"
  />
</template>
