import 'ee/registrations/welcome/jobs_to_be_done';
import { initWelcomeIndex } from 'ee/registrations/welcome';
import { saasTrialWelcome } from 'ee/google_tag_manager';
import Tracking from '~/tracking';
import FormErrorTracker from '~/pages/shared/form_error_tracker';

initWelcomeIndex();
saasTrialWelcome();
Tracking.enableFormTracking({
  forms: { allow: ['js-users-signup-welcome'] },
});

// Warning: run after all input initializations
// eslint-disable-next-line no-new
new FormErrorTracker();
