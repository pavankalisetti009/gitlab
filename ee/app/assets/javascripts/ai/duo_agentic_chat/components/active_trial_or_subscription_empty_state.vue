<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { GlAvatar, GlIcon, GlLink } from '@gitlab/ui';
import tanukiAiSvgUrl from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';
import { DuoChatPredefinedPrompts } from '@gitlab/duo-ui';

const SUGGESTED_AGENTS_LIMIT = 2;
const DEFAULT_AGENT_ID = 'gid://gitlab/Ai::FoundationalChatAgent/chat';

export default {
  name: 'ActiveTrialOrSubscriptionEmptyState',
  components: {
    DuoChatPredefinedPrompts,
    GlAvatar,
    GlIcon,
    GlLink,
  },
  props: {
    agents: {
      type: Array,
      required: true,
    },
    predefinedPrompts: {
      type: Array,
      required: true,
    },
    exploreAiCatalogPath: {
      type: String,
      required: true,
    },
  },
  emits: ['new-chat', 'send-chat-prompt'],
  computed: {
    ...mapState(['currentAgent']),
    suggestedAgents() {
      const currentAgentId = this.currentAgent?.id || DEFAULT_AGENT_ID;
      const filtered = this.agents.filter((agent) => {
        return agent.id !== currentAgentId;
      });

      return filtered.slice(0, SUGGESTED_AGENTS_LIMIT);
    },
  },
  tanukiAiSvgUrl,
  methods: {
    ...mapActions(['setCurrentAgent']),
    handleAgentClick(agent) {
      this.setCurrentAgent(agent);

      this.$emit('new-chat', agent);
    },
    sendPredefinedPrompt(prompt) {
      this.$emit('send-chat-prompt', prompt);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-w-full gl-flex-col gl-gap-4 gl-py-8">
    <img
      :src="$options.tanukiAiSvgUrl"
      class="gl-h-10 gl-w-10"
      :alt="s__('DuoAgenticChat|GitLab Duo AI assistant')"
    />
    <h2 class="gl-my-0 gl-text-size-h2">
      {{ s__('DuoAgenticChat|GitLab Duo Agent Platform') }}
    </h2>
    <p class="gl-text-subtle">
      {{
        s__(
          'DuoAgenticChat|Collaborate with AI agents to accomplish  tasks and answer questions, or use a multi-agent flow to solve a complex problem.',
        )
      }}
    </p>

    <span class="gl-font-bold">{{ s__('DuoAgenticChat|Chat about different topics') }}</span>

    <duo-chat-predefined-prompts
      key="predefined-prompts"
      :prompts="predefinedPrompts"
      @click="sendPredefinedPrompt"
    />

    <div class="gl-py-5">
      <span class="gl-font-bold">{{ s__('DuoAgenticChat|Chat with different agents') }}</span>
      <p class="gl-my-4">
        {{ s__('DuoAgenticChat|Get targeted help for tasks with specialized agents') }}
      </p>

      <div class="gl-grid gl-grid-cols-2 gl-gap-5">
        <gl-link
          v-for="agent in suggestedAgents"
          :key="agent.id"
          data-testid="agent-link"
          class="gl-rounded-full gl-bg-gray-50 gl-p-2 hover:gl-no-underline"
          variant="meta"
          @click="handleAgentClick(agent)"
        >
          <gl-avatar :src="agent.avatarUrl" :alt="agent.name" :size="32" />
          <span class="gl-ml-2 gl-align-middle gl-font-bold">{{ agent.name }}</span>
        </gl-link>

        <div class="gl-col-span-2 gl-text-center">
          <gl-link
            class="gl-rounded-full gl-bg-gray-50 gl-px-6 gl-py-2 hover:gl-no-underline"
            :href="exploreAiCatalogPath"
            variant="meta"
            data-testid="explore-agents-link"
          >
            <gl-icon name="plus" />
            <span class="gl-font-bold">{{ s__('Agents|Explore other agents') }}</span>
          </gl-link>
        </div>
      </div>
    </div>
  </div>
</template>
