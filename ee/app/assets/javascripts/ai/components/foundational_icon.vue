<script>
import { GlIcon, GlPopover, GlSprintf, GlTooltipDirective, GlLink } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'FoundationalIcon',
  foundationalAgentsHelpPagePath: helpPagePath(
    'user/duo_agent_platform/agents/foundational_agents/_index.md',
  ),
  components: {
    GlIcon,
    GlPopover,
    GlSprintf,
    GlLink,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    resourceId: {
      type: String,
      required: true,
    },
    size: {
      type: Number,
      required: false,
      default: 24,
    },
  },
  computed: {
    popoverTarget() {
      return `${this.resourceId}-foundational-icon`;
    },
  },
};
</script>

<template>
  <span>
    <gl-icon
      :id="popoverTarget"
      v-gl-tooltip
      name="tanuki-verified"
      variant="subtle"
      :size="size"
    />
    <gl-popover :target="popoverTarget" triggers="hover focus">
      <div class="gl-flex gl-flex-col gl-gap-4">
        <span>
          <gl-sprintf
            :message="s__('AICatalog|Created and maintained by %{boldStart}GitLab%{boldEnd}')"
          >
            <template #bold="{ content }">
              <strong>
                {{ content }}
              </strong>
            </template>
          </gl-sprintf>
        </span>
        <gl-link :href="$options.foundationalAgentsHelpPagePath" target="_blank">
          {{ s__('AICatalog|Learn more about foundational agents') }}
        </gl-link>
      </div>
    </gl-popover>
  </span>
</template>
