<script>
import { GlButton, GlBadge, GlMarkdown, GlLink, GlAvatar, GlTooltipDirective } from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { AI_CATALOG_AGENTS_SHOW_ROUTE, AI_CATALOG_AGENTS_RUN_ROUTE } from '../router/constants';
import { ENUM_TO_NAME_MAP } from '../constants';

export default {
  name: 'AiCatalogListItem',
  components: {
    GlButton,
    GlBadge,
    GlMarkdown,
    GlLink,
    GlAvatar,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  methods: {
    formatId(id) {
      return getIdFromGraphQLId(id);
    },
  },
  routes: {
    show: AI_CATALOG_AGENTS_SHOW_ROUTE,
    run: AI_CATALOG_AGENTS_RUN_ROUTE,
  },
  ENUM_TO_NAME_MAP,
};
</script>

<template>
  <li
    data-testid="ai-catalog-list-item"
    class="gl-flex gl-items-center gl-justify-between gl-border-b-1 gl-border-default gl-py-3 gl-text-subtle gl-border-b-solid"
  >
    <div class="gl-flex gl-items-center">
      <gl-avatar
        :alt="`${item.name} avatar`"
        :entity-name="item.name"
        :size="48"
        class="gl-mr-4 gl-self-start"
      />
      <div class="gl-flex gl-grow gl-flex-col gl-gap-1">
        <div class="gl-mb-1 gl-flex gl-flex-wrap gl-items-center gl-gap-2">
          <gl-link :to="{ name: $options.routes.show, params: { id: formatId(item.id) } }">
            {{ item.name }}
          </gl-link>
          <gl-badge variant="neutral" class="gl-self-center">
            {{ $options.ENUM_TO_NAME_MAP[item.itemType] }}
          </gl-badge>
        </div>

        <div v-if="item.description" class="gl-line-clamp-2 gl-break-words gl-text-default">
          <gl-markdown compact class="gl-text-sm">{{ item.description }}</gl-markdown>
        </div>
      </div>
    </div>
    <div>
      <gl-button :to="{ name: $options.routes.run, params: { id: formatId(item.id) } }">
        {{ s__('AICatalog|Run') }}
      </gl-button>
    </div>
  </li>
</template>
