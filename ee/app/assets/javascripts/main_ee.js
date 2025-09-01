import initEETrialBanner from 'ee/ee_trial_banner';
import { initTanukiBotChatDrawer } from 'ee/ai/tanuki_bot';
import { initDuoAgenticChat } from 'ee/ai/duo_agentic_chat';
import { initSamlReloadModal } from 'ee/saml_sso/index';

// EE specific calls
initEETrialBanner();

initTanukiBotChatDrawer();
initDuoAgenticChat();
initSamlReloadModal();
if (gon.features?.projectStudioEnabled) {
  (async () => {
    const { initDuoPanel } = await import('ee/ai/init_duo_panel');
    initDuoPanel();
  })();
}
