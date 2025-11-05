<script>
import { GlAlert, GlButton } from '@gitlab/ui';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { s__ } from '~/locale';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { updateMavenUpstream } from 'ee/api/virtual_registries_api';
import DeleteUpstreamWithModal from '../../../components/maven/shared/delete_upstream_with_modal.vue';
import RegistryUpstreamForm from '../../../components/maven/shared/registry_upstream_form.vue';
import { captureException } from '../../../sentry_utils';

export default {
  name: 'MavenEditUpstreamApp',
  components: {
    GlAlert,
    GlButton,
    PageHeading,
    RegistryUpstreamForm,
    DeleteUpstreamWithModal,
  },
  mixins: [glAbilitiesMixin()],
  inject: {
    upstream: {
      default: {},
    },
    upstreamsPath: {
      default: '',
    },
    upstreamPath: {
      default: '',
    },
  },
  data() {
    return {
      alertMessage: '',
      loading: false,
      upstreamDeleteModalIsShown: false,
    };
  },
  methods: {
    async updateUpstream(formData) {
      this.alertMessage = '';
      this.loading = true;
      try {
        const { cacheValidityHours, metadataCacheValidityHours, ...restFields } = formData;

        await updateMavenUpstream({
          id: this.upstream.id,
          data: {
            ...restFields,
            cache_validity_hours: formData.cacheValidityHours,
            metadata_cache_validity_hours: formData.metadataCacheValidityHours,
          },
        });

        visitUrlWithAlerts(this.upstreamPath, [
          {
            message: s__('VirtualRegistry|Maven upstream has been updated.'),
          },
        ]);
      } catch (error) {
        if (error.response?.status === 400 && typeof error.response?.data?.message === 'object') {
          const message = Object.entries(error.response.data.message)[0].join(' ');
          this.alertMessage = message;
        } else {
          this.alertMessage = this.parseError(error);
        }
      } finally {
        this.loading = false;
      }
    },
    parseError(error) {
      captureException({ component: this.$options.name, error });
      return error.response?.data?.error || error.message;
    },
    handleSuccess() {
      visitUrlWithAlerts(this.upstreamsPath, [
        {
          message: s__('VirtualRegistry|Maven upstream has been deleted.'),
        },
      ]);
    },
    handleError(error) {
      this.alertMessage = this.parseError(error);
    },
    showModal() {
      this.upstreamDeleteModalIsShown = true;
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="s__('VirtualRegistry|Edit upstream')" />
    <gl-alert v-if="alertMessage" class="gl-mb-3" variant="danger" :dismissible="false">
      {{ alertMessage }}
    </gl-alert>
    <registry-upstream-form :upstream="upstream" :loading="loading" @submit="updateUpstream">
      <template v-if="glAbilities.destroyVirtualRegistry" #actions>
        <gl-button category="secondary" variant="danger" @click="showModal">
          {{ s__('VirtualRegistry|Delete upstream') }}
        </gl-button>
      </template>
    </registry-upstream-form>
    <delete-upstream-with-modal
      v-model="upstreamDeleteModalIsShown"
      :upstream-id="upstream.id"
      :upstream-name="upstream.name"
      @success="handleSuccess"
      @error="handleError"
      @canceled="upstreamDeleteModalIsShown = false"
    />
  </div>
</template>
