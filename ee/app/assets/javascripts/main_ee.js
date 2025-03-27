import initEETrialBanner from 'ee/ee_trial_banner';
import { initTanukiBotChatDrawer } from 'ee/ai/tanuki_bot';
import { initSamlReloadModal } from 'ee/saml_sso/index';

// EE specific calls
initEETrialBanner();

initTanukiBotChatDrawer();
initSamlReloadModal();
