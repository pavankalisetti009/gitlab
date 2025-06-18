<script>
import { GlSprintf } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { REPLICATION_STATUS_STATES } from 'ee/geo_shared/constants';
import GeoListItem from 'ee/geo_shared/list/components/geo_list_item.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { __, s__, sprintf } from '~/locale';
import { ACTION_TYPES } from '../constants';

export default {
  name: 'GeoReplicableItem',
  i18n: {
    unknown: __('Unknown'),
    nA: __('Not applicable.'),
    resync: s__('Geo|Resync'),
    reverify: s__('Geo|Reverify'),
    lastVerified: s__('Geo|Last time verified'),
    modelRecordId: s__('Geo|Model record: %{modelRecordId}'),
    replicationStatus: s__('Geo|Replication: %{status}'),
  },
  components: {
    GeoListItem,
    GlSprintf,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['replicableBasePath', 'graphqlRegistryClass'],
  props: {
    registryId: {
      type: [String, Number],
      required: true,
    },
    modelRecordId: {
      type: Number,
      required: true,
    },
    syncStatus: {
      type: String,
      required: false,
      default: '',
    },
    lastSynced: {
      type: String,
      required: false,
      default: '',
    },
    lastVerified: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    ...mapState(['verificationEnabled']),
    timeAgoArray() {
      return [
        {
          label: capitalizeFirstCharacter(this.syncStatus),
          dateString: this.lastSynced,
          defaultText: this.$options.i18n.unknown,
        },
        {
          label: this.$options.i18n.lastVerified,
          dateString: this.lastVerified,
          defaultText: this.verificationEnabled
            ? this.$options.i18n.unknown
            : this.$options.i18n.nA,
        },
      ];
    },
    id() {
      return getIdFromGraphQLId(this.registryId);
    },
    detailsPath() {
      return this.glFeatures.geoReplicablesShowView
        ? `${this.replicableBasePath}/${getIdFromGraphQLId(this.id)}`
        : null;
    },
    name() {
      return `${this.graphqlRegistryClass}/${this.id}`;
    },
    statusArray() {
      const replicationStatus =
        REPLICATION_STATUS_STATES[this.syncStatus?.toUpperCase()] ||
        REPLICATION_STATUS_STATES.UNKNOWN;

      return [
        {
          tooltip: sprintf(this.$options.i18n.replicationStatus, {
            status: replicationStatus.title,
          }),
          icon: replicationStatus.icon,
          variant: replicationStatus.variant,
        },
      ];
    },
    actionsArray() {
      const actions = [
        {
          id: 'geo-resync-item',
          value: ACTION_TYPES.RESYNC,
          text: this.$options.i18n.resync,
        },
      ];

      if (this.verificationEnabled) {
        actions.push({
          id: 'geo-reverify-item',
          value: ACTION_TYPES.REVERIFY,
          text: this.$options.i18n.reverify,
        });
      }

      return actions;
    },
  },
  methods: {
    ...mapActions(['initiateReplicableAction']),
    handleActionClicked(action) {
      this.initiateReplicableAction({
        registryId: this.registryId,
        name: this.name,
        action: action.value,
      });
    },
  },
};
</script>

<template>
  <geo-list-item
    :name="name"
    :details-path="detailsPath"
    :status-array="statusArray"
    :time-ago-array="timeAgoArray"
    :actions-array="actionsArray"
    @actionClicked="handleActionClicked"
  >
    <template #extra-details>
      <gl-sprintf :message="$options.i18n.modelRecordId">
        <template #modelRecordId>
          {{ modelRecordId }}
        </template>
      </gl-sprintf>
    </template>
  </geo-list-item>
</template>
