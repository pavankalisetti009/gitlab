import { s__ } from '~/locale';
import { PROMO_URL } from '~/constants';

export const ULTIMATE_TRIAL_FORM_SUBMIT_TEXT = s__('Trial|Start free GitLab Ultimate trial');
export const GENERIC_TRIAL_FORM_SUBMIT_TEXT = s__('Trial|Continue');
export const ULTIMATE_TRIAL_FOOTER_DESCRIPTION = s__(
  "Trial|You don't need a credit card to start a trial. After the 30-day trial period, your account automatically becomes a GitLab Free account. You can use your GitLab Free account forever, or upgrade to a paid tier.",
);
export const TRIAL_COMPANY_SIZE_PROMPT = s__('Trial|Select number of employees');
export const TRIAL_PHONE_DESCRIPTION = s__('Trial|Allowed characters: +, 0-9, -, and spaces.');
export const TRIAL_STATE_LABEL = s__('Trial|State or province');
export const TRIAL_STATE_PROMPT = s__('Trial|Select state or province');
export const TRIAL_DESCRIPTION = s__(
  'Trial|To activate your trial, we need additional details from you.',
);
export const TRIAL_REGISTRATION_DESCRIPTION = s__(
  'TrialRegistration|To complete registration, we need additional details from you.',
);
export const TRIAL_TERMS_TEXT = s__(
  'Trial|By clicking "%{buttonText}" you accept the %{gitlabSubscriptionAgreement} and acknowledge the %{privacyStatement} and %{cookiePolicy}',
);
export const TRIAL_GITLAB_SUBSCRIPTION_AGREEMENT = {
  text: s__('Trial|GitLab Subscription Agreement'),
  url: `${PROMO_URL}/handbook/legal/subscription-agreement`,
};
export const TRIAL_PRIVACY_STATEMENT = {
  text: s__('Trial|Privacy Statement'),
  url: `${PROMO_URL}/privacy`,
};
export const TRIAL_COOKIE_POLICY = {
  text: s__('Trial|Cookie Policy.'),
  url: `${PROMO_URL}/privacy/cookies`,
};
