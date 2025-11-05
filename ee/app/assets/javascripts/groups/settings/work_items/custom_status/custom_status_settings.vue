<script>
import { GlAlert, GlButton, GlLoadingIcon } from '@gitlab/ui';
import { uniqBy } from 'lodash';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import StatusModal from './status_modal.vue';
import CreateLifecycleModal from './create_lifecycle_modal.vue';
import LifecycleDetail from './lifecycle_detail.vue';
import namespaceLifecyclesQuery from './graphql/namespace_lifecycles.query.graphql';

export default {
  components: {
    GlAlert,
    GlButton,
    StatusModal,
    HelpPageLink,
    CreateLifecycleModal,
    LifecycleDetail,
    GlLoadingIcon,
    SettingsBlock,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      lifecycles: [],
      errorText: '',
      errorDetail: '',
      selectedLifecycleId: null,
      showCreateLifecycleModal: false,
      initialLifecyclesLoaded: false,
    };
  },
  apollo: {
    lifecycles: {
      query: namespaceLifecyclesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.namespace?.lifecycles?.nodes || [];
      },
      result() {
        this.initialLifecyclesLoaded = true;
      },
      error(error) {
        this.errorText = s__('WorkItem|Failed to load lifecycles.');
        this.errorDetail = error.message;
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    selectedLifecycle() {
      return this.lifecycles.find((lifecycle) => lifecycle.id === this.selectedLifecycleId);
    },
    loadingInitialLifecycles() {
      return !this.initialLifecyclesLoaded && this.$apollo.queries.lifecycles.loading;
    },
    allNamespaceStatuses() {
      const allStatuses = this.lifecycles.flatMap((lifecycle) => lifecycle.statuses);
      return uniqBy(allStatuses, 'id');
    },
  },
  methods: {
    dismissAlert() {
      this.errorText = '';
      this.errorDetail = '';
    },
    openStatusModal(lifecycleId) {
      this.selectedLifecycleId = lifecycleId;
    },
    closeModal() {
      this.selectedLifecycleId = null;
    },
    handleLifecycleUpdate() {
      this.$apollo.queries.lifecycles.refetch();
    },
    closeCreateLifecycleModal() {
      this.showCreateLifecycleModal = false;
    },
    handleLifecycleCreate(newLifecycleId) {
      this.handleLifecycleUpdate();
      this.openStatusModal(newLifecycleId);
    },
    toggleExpanded(expanded) {
      if (!expanded && this.$route.hash === '') {
        return;
      }
      this.$router.push({
        name: 'workItemSettingsHome',
        hash: expanded ? '#js-custom-status-settings' : '',
      });
    },
  },
};
</script>

<template>
  <settings-block
    id="js-custom-status-settings"
    :title="s__('WorkItem|Statuses')"
    @toggle-expand="toggleExpanded"
  >
    <template #description>
      <p>
        {{
          s__(
            'WorkItem|Statuses are used to manage workflow of planning items, helping you and your team understand how far an item has progressed.',
          )
        }}
        <help-page-link
          data-testid="settings-help-page-link"
          href="user/work_items/status"
          target="_blank"
        >
          {{ s__('WorkItems|How do I use statuses?') }}
        </help-page-link>
      </p>
    </template>
    <template #default>
      <gl-loading-icon v-if="loadingInitialLifecycles" size="lg" class="gl-mt-5" />

      <gl-alert
        v-if="errorText"
        variant="danger"
        :dismissible="true"
        class="gl-mb-5"
        data-testid="alert"
        @dismiss="dismissAlert"
      >
        {{ errorText }}
        <details>
          {{ errorDetail }}
        </details>
      </gl-alert>

      <section
        data-testid="more-lifecycle-information"
        class="gl-mb-4 gl-flex gl-flex-wrap gl-items-center gl-justify-between"
      >
        <div>
          <h3 class="gl-mb-2 gl-mt-0 gl-text-base">{{ s__('WorkItem|Lifecycles') }}</h3>
          <p class="gl-mb-0 gl-text-subtle">
            {{
              s__(
                'WorkItem|Lifecycles contain statuses that are used together as an item is worked on. Each item type uses a single lifecycle.',
              )
            }}
          </p>
        </div>
        <gl-button data-testid="create-lifecycle" @click="showCreateLifecycleModal = true">{{
          s__('WorkItem|Create lifecycle')
        }}</gl-button>
      </section>

      <div class="gl-flex gl-flex-col gl-gap-4">
        <lifecycle-detail
          v-for="lifecycle in lifecycles"
          :key="lifecycle.id"
          :lifecycle="lifecycle"
          :full-path="fullPath"
          show-usage-section
          show-not-in-use-section
          @deleted="handleLifecycleUpdate"
        >
          <template #detail-footer>
            <gl-button data-testid="edit-statuses" @click="openStatusModal(lifecycle.id)">{{
              s__('WorkItem|Edit statuses')
            }}</gl-button>
          </template>
        </lifecycle-detail>
      </div>

      <status-modal
        v-if="selectedLifecycle"
        :visible="Boolean(selectedLifecycleId)"
        :lifecycle="selectedLifecycle"
        :full-path="fullPath"
        :statuses="allNamespaceStatuses"
        @close="closeModal"
        @lifecycle-updated="handleLifecycleUpdate"
      />

      <create-lifecycle-modal
        :visible="showCreateLifecycleModal"
        :full-path="fullPath"
        @close="closeCreateLifecycleModal"
        @lifecycle-created="handleLifecycleCreate"
      />
    </template>
  </settings-block>
</template>
