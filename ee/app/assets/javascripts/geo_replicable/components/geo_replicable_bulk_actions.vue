<script>
import { GlButton, GlModal, GlSprintf, GlModalDirective } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { s__, sprintf } from '~/locale';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { ACTION_TYPES, GEO_BULK_ACTION_MODAL_ID } from '../constants';

export default {
  name: 'GeoReplicableBulkActions',
  i18n: {
    resyncAll: s__('Geo|Resync all'),
    reverifyAll: s__('Geo|Reverify all'),
    modalTitle: s__('Geo|%{action} %{replicableType}'),
    modalBody: s__(
      'Geo|This will %{action} %{replicableType}. It may take some time to complete. Are you sure you want to continue?',
    ),
  },
  components: {
    GlButton,
    GlModal,
    GlSprintf,
  },
  directives: {
    GlModalDirective,
  },
  data() {
    return {
      modalAction: null,
    };
  },
  computed: {
    ...mapState(['verificationEnabled', 'titlePlural']),
    modalTitle() {
      return sprintf(this.$options.i18n.modalTitle, {
        action: this.readableModalAction && capitalizeFirstCharacter(this.readableModalAction),
        replicableType: this.titlePlural,
      });
    },
    readableModalAction() {
      return this.modalAction?.replace('_', ' ');
    },
  },
  methods: {
    ...mapActions(['initiateAllReplicableAction']),
    setModalData(action) {
      this.modalAction = action;
    },
  },
  actionTypes: ACTION_TYPES,
  GEO_BULK_ACTION_MODAL_ID,
};
</script>

<template>
  <div>
    <div>
      <gl-button
        v-gl-modal-directive="$options.GEO_BULK_ACTION_MODAL_ID"
        data-testid="geo-resync-all"
        @click="setModalData($options.actionTypes.RESYNC_ALL)"
        >{{ $options.i18n.resyncAll }}</gl-button
      >
      <gl-button
        v-if="verificationEnabled"
        v-gl-modal-directive="$options.GEO_BULK_ACTION_MODAL_ID"
        data-testid="geo-reverify-all"
        @click="setModalData($options.actionTypes.REVERIFY_ALL)"
        >{{ $options.i18n.reverifyAll }}</gl-button
      >
    </div>
    <gl-modal
      :modal-id="$options.GEO_BULK_ACTION_MODAL_ID"
      :title="modalTitle"
      size="sm"
      @primary="initiateAllReplicableAction({ action: modalAction })"
    >
      <gl-sprintf :message="$options.i18n.modalBody">
        <template #action>{{ readableModalAction }}</template>
        <template #replicableType>{{ titlePlural }}</template>
      </gl-sprintf>
    </gl-modal>
  </div>
</template>
