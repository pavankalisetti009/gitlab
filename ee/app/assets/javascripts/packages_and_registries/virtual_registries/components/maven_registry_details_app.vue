<script>
import { GlAlert, GlButton } from '@gitlab/ui';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import MetadataItem from '~/vue_shared/components/registry/metadata_item.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { sprintf, s__ } from '~/locale';
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
    MetadataItem,
    TitleArea,
    CrudComponent,
    RegistryUpstreamItem,
    RegistryUpstreamForm,
  },
  mixins: [glAbilitiesMixin()],
  inject: {
    registryEditPath: {
      default: '',
    },
  },
  props: {
    /**
     * The registry object
     */
    registry: {
      type: Object,
      required: false,
      default: () => ({}),
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
   * @event reorderUpstream
   * @property {string} direction - The direction to move the upstream ('up' or 'down')
   * @property {string} upstreamId - The ID of the upstream to reorder
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
   * Emitted when the cache is cleared
   * @event clearCache
   * @property {string} upstreamId - The ID of the upstream to clear the cache
   */

  /**
   * Emitted when the upstream is deleted
   * @event deleteUpstream
   * @property {string} upstreamId - The ID of the upstream to delete
   */
  emits: ['reorderUpstream', 'upstreamCreated', 'testUpstream', 'clearCache', 'deleteUpstream'],
  data() {
    return {
      createUpstreamError: '',
      createUpstreamMutationLoading: false,
      upstreamItems: this.upstreams,
    };
  },
  computed: {
    canEdit() {
      return this.glAbilities.updateVirtualRegistry;
    },
    sortedUpstreamItems() {
      return [...this.upstreamItems].sort((a, b) => a.position - b.position);
    },
    storageUsed() {
      const { storageSize } = this.registry;

      return storageSize
        ? sprintf(s__('VirtualRegistry|%{size} storage used'), { size: storageSize })
        : '';
    },
    toggleText() {
      return this.glAbilities.createVirtualRegistry ? s__('VirtualRegistry|Add upstream') : null;
    },
    upstreamsCount() {
      return this.upstreams.length;
    },
    mavenVirtualRegistryID() {
      return convertToMavenRegistryGraphQLId(this.registry.id);
    },
  },
  watch: {
    upstreams(val) {
      this.upstreamItems = val || [];
    },
  },
  methods: {
    reorderUpstream(direction, upstreamId) {
      this.$emit('reorderUpstream', direction, upstreamId);
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
          this.$toast.show(s__('VirtualRegistry|Upstream created successfully'));
        }
      } catch (error) {
        this.createUpstreamError = s__(
          'VirtualRegistry|Something went wrong while creating the upstream. Please try again.',
        );
        captureException({ error, component: this.$options.name });
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
    clearCache(upstreamId) {
      this.$emit('clearCache', upstreamId);
    },
    deleteUpstream(upstreamId) {
      this.$emit('deleteUpstream', upstreamId);
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
  },
  upstreamRegistryCreate: 'mavenUpstreamCreate',
};
</script>

<template>
  <div>
    <title-area :title="registry.name">
      <template #metadata-registry-type>
        <metadata-item icon="infrastructure-registry" :text="s__('VirtualRegistry|Maven')" />
      </template>
      <template v-if="storageUsed" #metadata-registry-storage>
        <metadata-item icon="container-image" :text="storageUsed" />
      </template>
      <p data-testid="description">{{ registry.description }}</p>
      <template v-if="canEdit" #right-actions>
        <gl-button :href="registryEditPath">
          {{ __('Edit') }}
        </gl-button>
      </template>
    </title-area>
    <crud-component
      ref="registryDetailsCrud"
      :title="s__('VirtualRegistry|Upstreams')"
      icon="infrastructure-registry"
      :toggle-text="toggleText"
      :description="
        s__(
          'VirtualRegistry|Use the arrow buttons to reorder upstreams. Artifacts are resolved from top to bottom.',
        )
      "
      :count="upstreamsCount"
    >
      <template #default>
        <div v-if="upstreamsCount" class="gl-flex gl-flex-col gl-gap-3">
          <registry-upstream-item
            v-for="(upstream, index) in sortedUpstreamItems"
            :key="upstream.id"
            :upstream="upstream"
            :upstreams-count="upstreamsCount"
            :index="index"
            @reorderUpstream="reorderUpstream"
            @clearCache="clearCache"
            @deleteUpstream="deleteUpstream"
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
          :registry="registry"
          :loading="createUpstreamMutationLoading"
          :can-test-upstream="canTestUpstream"
          @submit="createUpstream"
          @testUpstream="testUpstream"
          @cancel="hideForm"
        />
      </template>
    </crud-component>
  </div>
</template>
