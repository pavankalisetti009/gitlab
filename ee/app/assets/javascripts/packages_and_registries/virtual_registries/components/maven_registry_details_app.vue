<script>
import { GlAlert, GlButton, GlModal } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { sprintf, s__, __ } from '~/locale';
import {
  deleteMavenRegistryCache,
  deleteMavenUpstreamCache,
  updateMavenRegistryUpstreamPosition,
} from 'ee/api/virtual_registries_api';
import createUpstreamRegistryMutation from '../graphql/mutations/create_maven_upstream.mutation.graphql';
import { convertToMavenRegistryGraphQLId } from '../utils';
import { captureException } from '../sentry_utils';
import RegistryUpstreamItem from './registry_upstream_item.vue';
import RegistryUpstreamForm from './registry_upstream_form.vue';

export default {
  name: 'MavenRegistryDetailsApp',
  components: {
    GlAlert,
    GlButton,
    GlModal,
    CrudComponent,
    RegistryUpstreamItem,
    RegistryUpstreamForm,
  },
  mixins: [glAbilitiesMixin()],
  props: {
    /**
     * The registry object
     */
    registryId: {
      type: Number,
      required: true,
    },
    /**
     * The upstreams object
     */
    upstreams: {
      type: Array,
      required: false,
      default: () => [],
    },
    /**
     * Whether the upstream can be tested
     */
    canTestUpstream: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  /**
   * Emitted when an upstream is reordered
   * @event upstreamReordered
   */
  /**
   * Emitted when a new upstream is created
   * @event upstreamCreated
   */
  /**
   * Emitted when an upstream is tested
   * @event testUpstream
   * @property {Object} upstream - The upstream object being tested
   */

  /**
   * Emitted when the upstream is deleted
   * @event deleteUpstream
   * @property {string} upstreamId - The ID of the upstream to delete
   */
  emits: ['upstreamReordered', 'upstreamCreated', 'testUpstream', 'deleteUpstream'],
  data() {
    return {
      createUpstreamError: '',
      createUpstreamMutationLoading: false,
      registryClearCacheModalIsShown: false,
      upstreamClearCacheModalIsShown: false,
      upstreamToBeCleared: null,
      upstreamItems: this.upstreams,
      updateActionErrorMessage: '',
    };
  },
  computed: {
    canEdit() {
      return this.glAbilities.updateVirtualRegistry;
    },
    canClearRegistryCache() {
      return this.canEdit && this.upstreamsCount;
    },
    sortedUpstreamItems() {
      return [...this.upstreamItems].sort((a, b) => a.position - b.position);
    },
    canCreate() {
      return this.glAbilities.createVirtualRegistry;
    },
    upstreamsCount() {
      return this.upstreams.length;
    },
    mavenVirtualRegistryID() {
      return convertToMavenRegistryGraphQLId(this.registryId);
    },
    clearUpstreamCacheModalTitle() {
      if (!this.upstreamClearCacheModalIsShown) return '';

      return sprintf(s__('VirtualRegistry|Clear cache for %{upstreamName}?'), {
        upstreamName: this.upstreamToBeCleared.name,
      });
    },
  },
  watch: {
    upstreams(val) {
      this.upstreamItems = val || [];
    },
  },
  methods: {
    async reorderUpstream(direction, upstream) {
      const [registryUpstream] = upstream.registryUpstreams;
      const position = registryUpstream.position + (direction === 'up' ? -1 : 1);

      const id = getIdFromGraphQLId(registryUpstream.id);
      this.resetUpdateActionErrorMessage();

      try {
        await updateMavenRegistryUpstreamPosition({ id, position });
        this.$emit('upstreamReordered');
        this.$toast.show(
          s__('VirtualRegistry|Position of the upstream has been updated successfully.'),
        );
      } catch (error) {
        this.updateActionErrorMessage =
          error.error ||
          s__('VirtualRegistry|Failed to update position of the upstream. Try again.');
        this.handleError(error);
      }
    },
    async upstreamAction(name, mutationData) {
      this.createUpstreamMutationLoading = true;
      this.createUpstreamError = '';

      try {
        const {
          data: {
            [name]: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: createUpstreamRegistryMutation,
          variables: mutationData,
        });

        if (errors.length > 0) {
          this.createUpstreamError = errors.join(', ');
        } else {
          this.emitUpstreamCreated();
          this.$toast.show(s__('VirtualRegistry|Upstream created successfully.'));
        }
      } catch (error) {
        this.createUpstreamError = s__(
          'VirtualRegistry|Something went wrong while creating the upstream. Try again.',
        );
        this.handleError(error);
      } finally {
        this.createUpstreamMutationLoading = false;
      }
    },
    createUpstream(form) {
      this.upstreamAction(this.$options.upstreamRegistryCreate, {
        id: this.mavenVirtualRegistryID,
        ...form,
      });
    },
    emitUpstreamCreated() {
      this.$emit('upstreamCreated');
      this.hideForm();
    },
    showClearRegistryCacheModal() {
      this.registryClearCacheModalIsShown = true;
    },
    hideRegistryClearCacheModal() {
      this.registryClearCacheModalIsShown = false;
    },
    async clearRegistryCache() {
      this.resetUpdateActionErrorMessage();
      this.hideRegistryClearCacheModal();
      try {
        await deleteMavenRegistryCache({ id: this.registryId });
        this.$toast.show(s__('VirtualRegistry|Registry cache cleared successfully.'));
      } catch (error) {
        this.updateActionErrorMessage = s__(
          'VirtualRegistry|Failed to clear registry cache. Try again.',
        );
        this.handleError(error);
      }
    },
    showClearUpstreamCacheModal(upstream) {
      this.upstreamToBeCleared = upstream;
      this.upstreamClearCacheModalIsShown = true;
    },
    hideUpstreamClearCacheModal() {
      this.upstreamClearCacheModalIsShown = false;
      this.upstreamToBeCleared = null;
    },
    async clearUpstreamCache() {
      const id = getIdFromGraphQLId(this.upstreamToBeCleared.id);
      this.resetUpdateActionErrorMessage();
      this.hideUpstreamClearCacheModal();
      try {
        await deleteMavenUpstreamCache({ id });
        this.$toast.show(s__('VirtualRegistry|Upstream cache cleared successfully.'));
      } catch (error) {
        this.updateActionErrorMessage = s__(
          'VirtualRegistry|Failed to clear upstream cache. Try again.',
        );
        this.handleError(error);
      }
    },
    deleteUpstream(upstreamId) {
      this.$emit('deleteUpstream', upstreamId);
    },
    resetUpdateActionErrorMessage() {
      this.updateActionErrorMessage = '';
    },
    testUpstream(upstreamId) {
      this.$emit('testUpstream', upstreamId);
    },
    hideForm() {
      this.$refs.registryDetailsCrud.hideForm();
      if (this.createUpstreamError) {
        this.createUpstreamError = '';
      }
    },
    handleError(error) {
      captureException({ error, component: this.$options.name });
    },
  },
  upstreamRegistryCreate: 'mavenUpstreamCreate',
  modal: {
    primaryAction: {
      text: s__('VirtualRegistry|Clear cache'),
      attributes: {
        variant: 'danger',
        category: 'primary',
      },
    },
    cancelAction: {
      text: __('Cancel'),
    },
  },
};
</script>

<template>
  <crud-component
    ref="registryDetailsCrud"
    :title="s__('VirtualRegistry|Upstreams')"
    icon="infrastructure-registry"
    :description="
      s__(
        'VirtualRegistry|Use the arrow buttons to reorder upstreams. Artifacts are resolved from top to bottom.',
      )
    "
    :count="upstreamsCount"
  >
    <template #actions="{ showForm, isFormVisible }">
      <gl-button
        v-if="canClearRegistryCache"
        data-testid="clear-registry-cache-button"
        size="small"
        category="tertiary"
        @click="showClearRegistryCacheModal"
      >
        {{ s__('VirtualRegistry|Clear all caches') }}
      </gl-button>
      <gl-button
        v-if="canCreate"
        :disabled="isFormVisible"
        data-testid="add-upstream-button"
        size="small"
        @click="showForm"
        >{{ s__('VirtualRegistry|Add upstream') }}</gl-button
      >
    </template>
    <template #default>
      <div v-if="upstreamsCount" class="gl-flex gl-flex-col gl-gap-3">
        <gl-alert
          v-if="updateActionErrorMessage"
          data-testid="update-action-error-alert"
          variant="danger"
          @dismiss="resetUpdateActionErrorMessage"
        >
          {{ updateActionErrorMessage }}
        </gl-alert>
        <registry-upstream-item
          v-for="(upstream, index) in sortedUpstreamItems"
          :key="upstream.id"
          :upstream="upstream"
          :upstreams-count="upstreamsCount"
          :index="index"
          @reorderUpstream="reorderUpstream"
          @clearCache="showClearUpstreamCacheModal"
          @deleteUpstream="deleteUpstream"
        />
        <gl-modal
          v-model="registryClearCacheModalIsShown"
          data-testid="clear-registry-cache-modal"
          modal-id="clear-registry-cache-modal"
          size="sm"
          :title="s__('VirtualRegistry|Clear all caches?')"
          :action-primary="$options.modal.primaryAction"
          :action-cancel="$options.modal.cancelAction"
          @canceled="hideRegistryClearCacheModal"
          @primary="clearRegistryCache"
        >
          {{
            s__(
              'VirtualRegistry|This will delete all cached packages for exclusive upstream registries in this virtual registry. If any upstream is unavailable or misconfigured after clearing, jobs that rely on those packages might fail. Are you sure you want to continue?',
            )
          }}
        </gl-modal>
        <gl-modal
          v-model="upstreamClearCacheModalIsShown"
          data-testid="clear-upstream-cache-modal"
          modal-id="clear-upstream-cache-modal"
          size="sm"
          :title="clearUpstreamCacheModalTitle"
          :action-primary="$options.modal.primaryAction"
          :action-cancel="$options.modal.cancelAction"
          @canceled="hideUpstreamClearCacheModal"
          @primary="clearUpstreamCache"
        >
          {{
            s__(
              'VirtualRegistry|This will delete all cached packages for this upstream and re-fetch them from the source. If the upstream is unavailable or misconfigured, jobs might fail. Are you sure you want to continue?',
            )
          }}
        </gl-modal>
      </div>
      <p v-else class="gl-text-subtle">
        {{ s__('VirtualRegistry|No upstreams yet') }}
      </p>
    </template>
    <template #form>
      <gl-alert v-if="createUpstreamError" variant="danger" @dismiss="createUpstreamError = ''">
        {{ createUpstreamError }}
      </gl-alert>
      <registry-upstream-form
        :loading="createUpstreamMutationLoading"
        :can-test-upstream="canTestUpstream"
        @submit="createUpstream"
        @testUpstream="testUpstream"
        @cancel="hideForm"
      />
    </template>
  </crud-component>
</template>
