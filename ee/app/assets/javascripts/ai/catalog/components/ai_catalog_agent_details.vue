<script>
import { GlLink, GlSprintf, GlToken, GlTooltipDirective, GlTruncateText } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { getByVersionKey } from '../utils';
import {
  AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
} from '../constants';
import AiCatalogItemField from './ai_catalog_item_field.vue';
import AiCatalogItemFieldServiceAccount from './ai_catalog_item_field_service_account.vue';
import AiCatalogItemVisibilityField from './ai_catalog_item_visibility_field.vue';
import FormFlowDefinition from './form_flow_definition.vue';
import TriggerField from './trigger_field.vue';
import FormSection from './form_section.vue';

export default {
  name: 'AiCatalogAgentDetails',
  components: {
    AiCatalogItemField,
    AiCatalogItemFieldServiceAccount,
    AiCatalogItemVisibilityField,
    FormFlowDefinition,
    FormSection,
    GlLink,
    GlSprintf,
    GlToken,
    GlTruncateText,
    TriggerField,
  },
  truncateTextToggleButtonProps: {
    class: 'gl-font-regular',
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    versionKey: {
      type: String,
      required: true,
    },
  },
  computed: {
    projectName() {
      return this.item.project?.nameWithNamespace;
    },
    version() {
      return getByVersionKey(this.item, this.versionKey);
    },
    tools() {
      return [...(this.version.tools?.nodes ?? [])].sort((a, b) => a.title.localeCompare(b.title));
    },
    systemPrompt() {
      return this.version.systemPrompt;
    },
    definition() {
      return this.version.definition;
    },
    isThirdPartyFlow() {
      return this.item.itemType === AI_CATALOG_TYPE_THIRD_PARTY_FLOW;
    },
    typeField() {
      if (this.isThirdPartyFlow) {
        return s__('AICatalog|External');
      }
      if (this.item.foundational) {
        return s__('AICatalog|Foundational');
      }
      return s__('AICatalog|Custom');
    },
    hasProjectConfiguration() {
      return Boolean(this.item.configurationForProject);
    },
    serviceAccount() {
      if (this.hasProjectConfiguration) {
        return this.item.configurationForProject?.flowTrigger?.user;
      }
      return this.item.configurationForGroup?.serviceAccount;
    },
    helpTextSettingsLink() {
      return (
        this.item.configurationForGroup?.group?.duoSettingsPath ??
        helpPagePath('user/duo_agent_platform/agents/foundational_agents/_index', {
          anchor: 'turn-foundational-agents-on-or-off',
        })
      );
    },
  },
  AGENT_VISIBILITY_LEVEL_DESCRIPTIONS,
  toolsDocsLink: helpPagePath('user/duo_agent_platform/agents/tools'),
};
</script>

<template>
  <div>
    <h2 class="gl-heading-3">
      {{ s__('AICatalog|Agent configuration') }}
    </h2>
    <dl class="gl-flex gl-flex-col gl-gap-5">
      <form-section :title="s__('AICatalog|Visibility & access')" is-display>
        <ai-catalog-item-field
          v-if="projectName || item.foundational"
          :title="s__('AICatalog|Managed by')"
          data-testid="managed-by-field"
        >
          <gl-link v-if="!item.foundational" :href="item.project.webUrl">{{ projectName }}</gl-link>
          <gl-sprintf
            v-else
            :message="
              s__(
                'AICatalog|Foundational agents are managed by the %{linkStart}top-level group%{linkEnd}.',
              )
            "
          >
            <template #link="{ content }">
              <gl-link :href="helpTextSettingsLink">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </ai-catalog-item-field>
        <ai-catalog-item-visibility-field
          :public="item.public"
          :description-texts="$options.AGENT_VISIBILITY_LEVEL_DESCRIPTIONS"
        />
      </form-section>
      <form-section :title="s__('AICatalog|Configuration')" is-display>
        <ai-catalog-item-field :title="s__('AICatalog|Type')" :value="typeField" />
        <template v-if="isThirdPartyFlow">
          <ai-catalog-item-field-service-account
            v-if="serviceAccount"
            :service-account="serviceAccount"
            :item-type="item.itemType"
            data-testid="service-account-field"
          />
          <trigger-field v-if="hasProjectConfiguration" :item="item" />
          <ai-catalog-item-field :title="s__('AICatalog|Configuration')">
            <form-flow-definition :value="definition" read-only class="gl-mt-3" />
          </ai-catalog-item-field>
        </template>
        <template v-else>
          <ai-catalog-item-field :title="s__('AICatalog|Tools')">
            <p class="gl-text-subtle">
              <gl-sprintf
                :message="
                  s__(
                    'AICatalog|Tools are built and maintained by GitLab. %{linkStart}What are tools?%{linkEnd}',
                  )
                "
              >
                <template #link="{ content }">
                  <gl-link :href="$options.toolsDocsLink">{{ content }}</gl-link>
                </template>
              </gl-sprintf>
            </p>
            <span v-if="tools.length === 0" class="gl-text-subtle">
              {{ __('None') }}
            </span>
            <div v-else class="gl-mt-3 gl-flex gl-flex-wrap gl-gap-2 gl-whitespace-nowrap">
              <span
                v-for="tool in tools"
                :key="tool.title"
                v-gl-tooltip
                :title="tool.description"
                data-testid="tool-description-tooltip"
              >
                <gl-token view-only class="gl-cursor-default">
                  {{ tool.title }}
                </gl-token>
              </span>
            </div>
          </ai-catalog-item-field>
          <ai-catalog-item-field :title="s__('AICatalog|System prompt')">
            <div class="gl-border gl-mt-3 gl-rounded-default gl-bg-default gl-p-3">
              <pre class="gl-m-0 gl-whitespace-pre-wrap"><gl-truncate-text
              :lines="20"
              :show-more-text="__('Show more')"
              :show-less-text="__('Show less')"
              :toggle-button-props="$options.truncateTextToggleButtonProps"
              class="gl-flex gl-flex-col gl-items-start gl-gap-3"
            >{{ systemPrompt }}</gl-truncate-text></pre>
            </div>
          </ai-catalog-item-field>
        </template>
      </form-section>
    </dl>
  </div>
</template>
