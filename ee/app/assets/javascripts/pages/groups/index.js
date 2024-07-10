import { initHandRaiseLead } from 'ee/hand_raise_leads/hand_raise_lead';
import { initAiSettings } from 'ee/ai/settings/index';
import AiGroupSettings from 'ee/ai/settings/pages/ai_group_settings.vue';

initHandRaiseLead();
initAiSettings('js-ai-settings', AiGroupSettings);
