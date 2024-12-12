<script>
import { GlIcon, GlPopover } from '@gitlab/ui';
import { DB_CONNECTION_TYPE_UI } from 'ee/geo_sites/constants';
import { s__ } from '~/locale';

export default {
  name: 'GeoSiteDatabaseConnectionType',
  i18n: {
    dbConnectionTypeHelpText: s__(
      "Geo|Whether this site's database is connected to the primary database directly or through data replication",
    ),
  },
  components: {
    GlIcon,
    GlPopover,
  },
  props: {
    site: {
      type: Object,
      required: true,
    },
  },
  computed: {
    databaseConnectionTypeUi() {
      return this.site.dbReplicationLagSeconds !== null
        ? DB_CONNECTION_TYPE_UI.replicating
        : DB_CONNECTION_TYPE_UI.direct;
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center">
    <span class="gl-font-bold" data-testid="database-connection-type-text">{{
      databaseConnectionTypeUi.text
    }}</span>
    <gl-icon
      ref="databaseConnectionType"
      name="question-o"
      class="gl-ml-2 gl-cursor-pointer gl-text-blue-600"
    />
    <gl-popover
      :target="() => $refs.databaseConnectionType && $refs.databaseConnectionType.$el"
      placement="top"
      triggers="hover focus"
    >
      <p class="gl-text-base">
        {{ $options.i18n.dbConnectionTypeHelpText }}
      </p>
    </gl-popover>
  </div>
</template>
