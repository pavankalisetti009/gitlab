<script>
import { isEmpty } from 'lodash';
import { GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { getParameterByName, removeParams, updateHistory } from '~/lib/utils/url_utility';
import aiCatalogAgentsQuery from '../graphql/queries/ai_catalog_agents.query.graphql';
import deleteAiCatalogAgentMutation from '../graphql/mutations/delete_ai_catalog_agent.mutation.graphql';
import AiCatalogList from '../components/ai_catalog_list.vue';
import AiCatalogItemDrawer from '../components/ai_catalog_item_drawer.vue';
import { AI_CATALOG_SHOW_QUERY_PARAM } from '../router/constants';

export default {
  name: 'AiCatalogAgents',
  components: {
    GlAlert,
    AiCatalogList,
    AiCatalogItemDrawer,
  },
  apollo: {
    aiCatalogAgents: {
      query: aiCatalogAgentsQuery,
      update: (data) => data.aiCatalogItems.nodes,
      result() {
        this.checkDrawerParams();
      },
    },
  },
  data() {
    return {
      aiCatalogAgents: [],
      activeItem: null,
      errorMessage: null,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiCatalogAgents.loading;
    },
    isItemSelected() {
      return !isEmpty(this.activeItem);
    },
  },
  created() {
    this.checkDrawerParams();
    window.addEventListener('popstate', this.checkDrawerParams);
  },
  beforeDestroy() {
    window.removeEventListener('popstate', this.checkDrawerParams);
  },
  methods: {
    formatId(id) {
      return getIdFromGraphQLId(id);
    },
    closeDrawer() {
      this.activeItem = null;
      updateHistory({
        url: removeParams([AI_CATALOG_SHOW_QUERY_PARAM]),
      });
    },
    selectItem(item) {
      this.activeItem = item;
    },
    async deleteAgent(id) {
      try {
        const { data } = await this.$apollo.mutate({
          mutation: deleteAiCatalogAgentMutation,
          variables: {
            id,
          },
          refetchQueries: [aiCatalogAgentsQuery],
        });

        if (!data.aiCatalogAgentDelete.success) {
          this.errorMessage = sprintf(s__('AICatalog|Failed to delete agent. %{error}'), {
            error: data.aiCatalogAgentDelete.errors?.[0],
          });
          return;
        }

        this.$toast.show(s__('AICatalog|Agent deleted successfully.'));
      } catch (error) {
        this.errorMessage = sprintf(s__('AICatalog|Failed to delete agent. %{error}'), { error });
        Sentry.captureException(error);
      }
    },
    checkDrawerParams() {
      const urlItemId = getParameterByName(AI_CATALOG_SHOW_QUERY_PARAM);
      if (urlItemId) {
        this.activeItem =
          this.aiCatalogAgents.find((item) => this.formatId(item.id).toString() === urlItemId) ||
          null;
      } else {
        this.activeItem = null;
      }
    },
  },
};
</script>

<template>
  <div>
    <gl-alert
      v-if="errorMessage"
      class="gl-mb-3 gl-mt-5"
      variant="danger"
      @dismiss="errorMessage = null"
      >{{ errorMessage }}
    </gl-alert>

    <ai-catalog-list
      :is-loading="isLoading"
      :items="aiCatalogAgents"
      :delete-confirm-title="s__('AICatalog|Delete agent')"
      :delete-confirm-message="s__('AICatalog|Are you sure you want to delete agent %{name}?')"
      :delete-fn="deleteAgent"
      @select-item="selectItem"
    />
    <ai-catalog-item-drawer
      :is-open="isItemSelected"
      :active-item="activeItem"
      @close="closeDrawer"
    />
  </div>
</template>
