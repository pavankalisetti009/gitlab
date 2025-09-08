<script>
import { GlButton, GlModal, GlSprintf, GlModalDirective, GlLink, GlIcon } from '@gitlab/ui';
import { __, sprintf } from '~/locale';

export default {
  components: {
    GlButton,
    GlModal,
    GlSprintf,
    GlLink,
    GlIcon,
  },
  directives: {
    GlModalDirective,
  },
  inject: {
    itemTitle: {
      type: String,
    },
  },
  props: {
    bulkActions: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      modalAction: null,
    };
  },
  computed: {
    modalTitle() {
      if (!this.modalAction) {
        return null;
      }

      return sprintf(this.modalAction.modal.title, {
        type: this.itemTitle,
      });
    },
    modalDescription() {
      return sprintf(this.modalAction.modal.description, {
        type: this.itemTitle,
      });
    },
    modalHelpLink() {
      return this.modalAction.modal.helpLink;
    },
  },
  methods: {
    setModalData(action) {
      this.modalAction = action;
    },
  },
  GEO_BULK_ACTION_MODAL_ID: 'geo-bulk-action',
  modal: {
    actionPrimary: {
      text: __('Confirm'),
      attributes: {
        variant: 'confirm',
      },
    },
    actionCancel: {
      text: __('Cancel'),
    },
  },
};
</script>

<template>
  <div>
    <div>
      <gl-button
        v-for="action in bulkActions"
        :key="action.id"
        v-gl-modal-directive="$options.GEO_BULK_ACTION_MODAL_ID"
        :icon="action.icon"
        :data-testid="action.id"
        class="gl-ml-3"
        @click="setModalData(action)"
      >
        {{ action.text }}
      </gl-button>
    </div>
    <gl-modal
      :modal-id="$options.GEO_BULK_ACTION_MODAL_ID"
      :title="modalTitle"
      size="sm"
      no-focus-on-show
      :action-primary="$options.modal.actionPrimary"
      :action-cancel="$options.modal.actionCancel"
      @primary="$emit('bulkAction', modalAction.action)"
    >
      <template v-if="modalAction">
        <gl-sprintf :message="modalDescription">
          <template #type>{{ itemTitle }}</template>
        </gl-sprintf>
        <div v-if="modalHelpLink" class="gl-mt-3">
          <gl-link :href="modalHelpLink.href"
            ><gl-icon name="question" class="gl-mr-2" />{{ modalHelpLink.text }}</gl-link
          >
        </div>
      </template>
    </gl-modal>
  </div>
</template>
