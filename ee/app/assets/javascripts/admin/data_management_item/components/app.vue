<script>
import { GlLoadingIcon } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import DataManagementItemModelInfo from 'ee/admin/data_management_item/components/data_management_item_model_info.vue';
import { getModel } from 'ee/api/data_management_api';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { createAlert } from '~/alert';
import { sprintf, s__ } from '~/locale';
import ChecksumInfo from 'ee/admin/data_management_item/components/checksum_info.vue';

export default {
  name: 'AdminDataManagementItemApp',
  components: {
    PageHeading,
    ChecksumInfo,
    DataManagementItemModelInfo,
    GlLoadingIcon,
  },
  props: {
    modelClass: {
      type: String,
      required: true,
    },
    modelId: {
      type: String,
      required: true,
    },
    modelName: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      model: null,
      isLoading: true,
    };
  },
  computed: {
    name() {
      return `${this.modelClass}/${this.modelId}`;
    },
    checksumInformation() {
      return this.model?.checksumInformation ?? {};
    },
  },
  created() {
    this.initializeModel();
  },
  methods: {
    async initializeModel() {
      try {
        const { data } = await getModel(this.modelName, this.modelId);
        this.model = convertObjectPropsToCamelCase(data, { deep: true });
      } catch (error) {
        createAlert({
          message: sprintf(
            s__('Geo|There was an error fetching %{model}. Please refresh the page and try again.'),
            { model: this.name },
          ),
          captureError: true,
          error,
        });
      } finally {
        this.isLoading = false;
      }
    },
  },
};
</script>

<template>
  <section>
    <page-heading :heading="name" />
    <gl-loading-icon v-if="isLoading" size="xl" class="gl-mt-4" />
    <div v-else-if="model" class="gl-grid gl-gap-4 @md/panel:gl-grid-cols-2">
      <checksum-info :details="checksumInformation" class="gl-order-2 @md/panel:gl-order-1" />
      <data-management-item-model-info :model="model" class="gl-order-1 @md/panel:gl-order-2" />
    </div>
  </section>
</template>
