<script>
import { GlAlert, GlButton } from '@gitlab/ui';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { s__ } from '~/locale';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { updateMavenUpstream } from 'ee/api/virtual_registries_api';
import DeleteUpstreamWithModal from '../components/delete_upstream_with_modal.vue';
import RegistryUpstreamForm from '../components/registry_upstream_form.vue';
import { captureException } from '../sentry_utils';
import getMavenUpstreamRegistriesQuery from '../graphql/queries/get_maven_upstream_registries.query.graphql';
import { convertToMavenUpstreamGraphQLId } from '../utils';

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
    registriesPath: {
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
      registries: [],
    };
  },
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
      update(data) {
        return data.mavenUpstreamRegistry?.registries?.nodes ?? [];
      },
      error(error) {
        captureException({ error, component: this.$options.name });
      },
    },
  },
  computed: {
    mavenUpstreamRegistryID() {
      return convertToMavenUpstreamGraphQLId(this.upstream.id);
    },
  },
  methods: {
    async updateUpstream(formData) {
      this.alertMessage = '';
      this.loading = true;
      try {
        await updateMavenUpstream({
          id: this.upstream.id,
          data: formData,
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
      visitUrlWithAlerts(this.registriesPath, [
        {
          message: s__('VirtualRegistry|Maven upstream has been deleted.'),
        },
      ]);
    },
    handleError(error) {
      this.alertMessage = this.parseError(error);
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
        <delete-upstream-with-modal
          :upstream-id="upstream.id"
          :upstream-name="upstream.name"
          :registries="registries"
          @success="handleSuccess"
          @error="handleError"
        >
          <template #default="{ showModal }">
            <gl-button category="secondary" variant="danger" @click="showModal">
              {{ s__('VirtualRegistry|Delete upstream') }}
            </gl-button>
          </template>
        </delete-upstream-with-modal>
      </template>
    </registry-upstream-form>
  </div>
</template>
