<script>
import { GlAlert, GlBadge, GlButton, GlModal } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { sprintf, s__, __ } from '~/locale';
import {
  associateMavenUpstreamWithVirtualRegistry,
  deleteMavenRegistryCache,
  deleteMavenUpstreamCache,
  getMavenUpstreamRegistriesList,
  updateMavenRegistryUpstreamPosition,
  removeMavenUpstreamRegistryAssociation,
} from 'ee/api/virtual_registries_api';
import createUpstreamRegistryMutation from 'ee/packages_and_registries/virtual_registries/graphql/mutations/create_maven_upstream.mutation.graphql';
import { convertToMavenRegistryGraphQLId } from 'ee/packages_and_registries/virtual_registries/utils';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import RegistryUpstreamForm from 'ee/packages_and_registries/virtual_registries/components/maven/shared/registry_upstream_form.vue';
import UpstreamClearCacheModal from 'ee/packages_and_registries/virtual_registries/components/maven/shared/upstream_clear_cache_modal.vue';
import AddUpstream from './add_upstream.vue';
import LinkUpstreamForm from './link_upstream_form.vue';
import RegistryUpstreamItem from './registry_upstream_item.vue';

const FORM_TYPES = {
  CREATE: 'create',
  LINK: 'link',
};

const MAX_UPSTREAMS_PER_REGISTRY = 20;

export default {
  name: 'MavenRegistryDetailsUpstreamsList',
  components: {
    GlAlert,
    GlBadge,
    GlButton,
    GlModal,
    AddUpstream,
    CrudComponent,
    LinkUpstreamForm,
    RegistryUpstreamItem,
    RegistryUpstreamForm,
    UpstreamClearCacheModal,
  },
  mixins: [glAbilitiesMixin()],
  inject: {
    groupPath: {
      default: '',
    },
  },
  props: {
    loading: {
      type: Boolean,
      default: false,
      required: false,
    },
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
   * Emitted when the upstream is deleted
   * @event upstreamRemoved
   */
  emits: ['upstreamReordered', 'upstreamCreated', 'upstreamRemoved', 'upstreamLinked'],
  data() {
    return {
      currentFormType: '',
      createUpstreamError: '',
      createUpstreamMutationLoading: false,
      linkUpstreamInProgress: false,
      registryClearCacheModalIsShown: false,
      topLevelUpstreams: [],
      topLevelUpstreamsTotalCount: 0,
      topLevelUpstreamsQueryInProgress: false,
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
    canLinkUpstream() {
      return this.canEdit && this.topLevelUpstreamsTotalCount > this.upstreamsCount;
    },
    isCreateUpstreamForm() {
      return this.currentFormType === FORM_TYPES.CREATE;
    },
    isLinkUpstreamForm() {
      return this.currentFormType === FORM_TYPES.LINK;
    },
    upstreamsCount() {
      return this.upstreams.length;
    },
    mavenVirtualRegistryID() {
      return convertToMavenRegistryGraphQLId(this.registryId);
    },
    queriesInProgress() {
      return this.topLevelUpstreamsQueryInProgress || this.loading;
    },
    upstreamNameForClearCache() {
      return this.upstreamToBeCleared?.name ?? '';
    },
    upstreamsCountBadgeText() {
      return sprintf(s__('VirtualRegistry|%{count} of %{max}'), {
        max: MAX_UPSTREAMS_PER_REGISTRY,
        count: this.upstreamsCount,
      });
    },
    upstreamsLimitReached() {
      return this.upstreamsCount === MAX_UPSTREAMS_PER_REGISTRY;
    },
  },
  watch: {
    upstreams(val) {
      this.upstreamItems = val || [];
    },
  },
  async created() {
    if (!this.canEdit) return;

    try {
      this.topLevelUpstreamsQueryInProgress = true;
      const { headers, data } = await getMavenUpstreamRegistriesList({ id: this.groupPath });

      this.topLevelUpstreamsTotalCount = Number(headers['x-total']) || 0;
      this.topLevelUpstreams = data;
    } catch (error) {
      this.handleError(error);
    } finally {
      this.topLevelUpstreamsQueryInProgress = false;
    }
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
    emitUpstreamLinked() {
      this.$emit('upstreamLinked');
      this.hideForm();
    },
    async linkUpstream(upstreamId) {
      this.createUpstreamError = '';
      try {
        this.linkUpstreamInProgress = true;
        await associateMavenUpstreamWithVirtualRegistry({
          registryId: this.registryId,
          upstreamId,
        });
        this.emitUpstreamLinked();
        this.$toast.show(s__('VirtualRegistry|Upstream added to virtual registry successfully.'));
      } catch (error) {
        this.createUpstreamError = s__(
          'VirtualRegistry|Something went wrong while adding the upstream to virtual registry. Try again.',
        );
        this.handleError(error);
      } finally {
        this.linkUpstreamInProgress = false;
      }
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
    async removeUpstream(upstreamAssociationId) {
      const id = getIdFromGraphQLId(upstreamAssociationId);
      this.resetUpdateActionErrorMessage();
      try {
        await removeMavenUpstreamRegistryAssociation({ id });
        this.$toast.show(s__('VirtualRegistry|Removed upstream from virtual registry.'));
        this.$emit('upstreamRemoved');
      } catch (error) {
        this.updateActionErrorMessage = s__(
          'VirtualRegistry|Failed to remove upstream. Try again.',
        );
        this.handleError(error);
      }
    },
    resetUpdateActionErrorMessage() {
      this.updateActionErrorMessage = '';
    },
    showCreateForm() {
      this.currentFormType = FORM_TYPES.CREATE;
      this.$refs.registryDetailsCrud.showForm();
    },
    showLinkForm() {
      this.currentFormType = FORM_TYPES.LINK;
      this.$refs.registryDetailsCrud.showForm();
    },
    hideForm() {
      this.$refs.registryDetailsCrud.hideForm();
      this.currentFormType = '';
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
    :is-loading="loading"
    :description="
      s__(
        'VirtualRegistry|Use the arrow buttons to reorder upstreams. Artifacts are resolved from top to bottom.',
      )
    "
  >
    <template #count>
      <gl-badge>
        {{ upstreamsCountBadgeText }}
      </gl-badge>
    </template>
    <template #actions="{ isFormVisible }">
      <gl-button
        v-if="canClearRegistryCache"
        data-testid="clear-registry-cache-button"
        size="small"
        category="tertiary"
        @click="showClearRegistryCacheModal"
      >
        {{ s__('VirtualRegistry|Clear all caches') }}
      </gl-button>
      <span v-if="upstreamsLimitReached" data-testid="max-upstreams">{{
        s__('VirtualRegistry|Maximum number of upstreams reached.')
      }}</span>
      <add-upstream
        v-else-if="canCreate"
        :loading="queriesInProgress"
        :can-link="canLinkUpstream"
        :disabled="isFormVisible"
        @create="showCreateForm"
        @link="showLinkForm"
      />
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
          @removeUpstream="removeUpstream"
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
        <upstream-clear-cache-modal
          v-model="upstreamClearCacheModalIsShown"
          :upstream-name="upstreamNameForClearCache"
          @primary="clearUpstreamCache"
          @canceled="hideUpstreamClearCacheModal"
        />
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
        v-if="isCreateUpstreamForm"
        :loading="createUpstreamMutationLoading"
        @submit="createUpstream"
        @cancel="hideForm"
      />
      <link-upstream-form
        v-if="isLinkUpstreamForm"
        :loading="linkUpstreamInProgress"
        :upstreams-count="topLevelUpstreamsTotalCount"
        :linked-upstreams="upstreamItems"
        :initial-upstreams="topLevelUpstreams"
        @submit="linkUpstream"
        @cancel="hideForm"
      />
    </template>
  </crud-component>
</template>
