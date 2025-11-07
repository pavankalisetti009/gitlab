<script>
import { GlModal, GlTruncateText, GlSkeletonLoader } from '@gitlab/ui';
import { s__, __, n__, sprintf } from '~/locale';
import { deleteMavenUpstream } from 'ee/api/virtual_registries_api';
import getMavenUpstreamRegistriesQuery from '../../../graphql/queries/get_maven_upstream_registries.query.graphql';
import { captureException } from '../../../sentry_utils';
import { convertToMavenUpstreamGraphQLId } from '../../../utils';

export default {
  name: 'DeleteMavenUpstreamWithModal',
  components: {
    GlModal,
    GlTruncateText,
    GlSkeletonLoader,
  },
  model: {
    prop: 'visible',
    event: 'change',
  },
  props: {
    upstreamId: {
      type: Number,
      required: false,
      default: null,
    },
    upstreamName: {
      type: String,
      required: false,
      default: '',
    },
    visible: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['success', 'error', 'canceled', 'change'],
  apollo: {
    registries: {
      query: getMavenUpstreamRegistriesQuery,
      variables() {
        return {
          id: this.mavenUpstreamRegistryID,
          // Maximum number of maven virtual registries per top-level group.
          first: 20,
        };
      },
      skip() {
        return !this.visible || !this.upstreamId;
      },
      update(data) {
        return data.mavenUpstreamRegistry?.registries?.nodes ?? [];
      },
      error(error) {
        captureException({ error, component: this.$options.name });
      },
    },
  },
  data() {
    return {
      registries: [],
    };
  },
  computed: {
    loading() {
      return this.$apollo.queries.registries.loading;
    },
    mavenUpstreamRegistryID() {
      return convertToMavenUpstreamGraphQLId(this.upstreamId);
    },
    confirmationMessage() {
      return sprintf(s__('VirtualRegistry|Are you sure you want to delete %{name}?'), {
        name: this.upstreamName,
      });
    },
    hasRegistries() {
      return this.registriesCount > 0;
    },
    registriesCount() {
      return this.registries.length;
    },
    upstreamPresent() {
      return this.upstreamId && this.upstreamName;
    },
    message() {
      return sprintf(
        n__(
          'VirtualRegistry|You are about to delete this upstream used by %{count} registry:',
          'VirtualRegistry|You are about to delete this upstream used by %{count} registries:',
          this.registriesCount,
        ),
        {
          count: this.registriesCount,
        },
      );
    },
    modalPrimaryAction() {
      return {
        text: s__('VirtualRegistry|Delete upstream'),
        attributes: {
          disabled: this.loading,
          variant: 'danger',
          category: 'primary',
        },
      };
    },
  },
  methods: {
    async deleteUpstream() {
      try {
        await deleteMavenUpstream({
          id: this.upstreamId,
        });

        this.$emit('success');
      } catch (error) {
        this.$emit('error', error);
      }
    },
  },
  modal: {
    cancelAction: {
      text: __('Cancel'),
    },
  },
};
</script>
<template>
  <gl-modal
    v-if="upstreamPresent"
    :visible="visible"
    modal-id="delete-upstream-modal"
    size="md"
    :action-primary="modalPrimaryAction"
    :action-cancel="$options.modal.cancelAction"
    :title="s__('VirtualRegistry|Delete upstream?')"
    @primary="deleteUpstream"
    @canceled="$emit('canceled')"
    @change="$emit('change', $event)"
  >
    <gl-skeleton-loader v-if="loading" />
    <template v-else-if="hasRegistries">
      <p class="gl-font-bold">{{ message }}</p>
      <gl-truncate-text class="gl-pb-3">
        <ul class="gl-pl-6">
          <li v-for="registry in registries" :key="registry.id">{{ registry.name }}</li>
        </ul>
      </gl-truncate-text>
      <p>
        {{
          s__(
            'VirtualRegistry|This action cannot be undone. Deleting this upstream might impact registries associated with it.',
          )
        }}
      </p>
    </template>
    <p v-else>{{ confirmationMessage }}</p>
  </gl-modal>
</template>
