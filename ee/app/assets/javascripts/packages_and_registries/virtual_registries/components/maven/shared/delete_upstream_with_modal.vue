<script>
import { GlModal, GlTruncateText } from '@gitlab/ui';
import { s__, __, n__, sprintf } from '~/locale';
import { deleteMavenUpstream } from 'ee/api/virtual_registries_api';

export default {
  name: 'DeleteMavenUpstreamWithModal',
  components: {
    GlModal,
    GlTruncateText,
  },
  props: {
    upstreamId: {
      type: Number,
      required: true,
    },
    upstreamName: {
      type: String,
      required: true,
    },
    registries: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['success', 'error'],
  data() {
    return {
      showDeleteModal: false,
    };
  },
  computed: {
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
    showModal() {
      this.showDeleteModal = true;
    },
  },
  modal: {
    primaryAction: {
      text: s__('VirtualRegistry|Delete upstream'),
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
  <div>
    <slot :show-modal="showModal"></slot>
    <gl-modal
      v-model="showDeleteModal"
      modal-id="delete-upstream-modal"
      size="md"
      :action-primary="$options.modal.primaryAction"
      :action-cancel="$options.modal.cancelAction"
      :title="s__('VirtualRegistry|Delete upstream?')"
      @primary="deleteUpstream"
      @canceled="showDeleteModal = false"
    >
      <template v-if="hasRegistries">
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
  </div>
</template>
