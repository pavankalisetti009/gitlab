import { s__ } from '~/locale';

export const AVAILABILITY_OPTIONS = {
  DEFAULT_ON: 'default_on',
  DEFAULT_OFF: 'default_off',
  NEVER_ON: 'never_on',
};

export const PROTECTION_LEVEL_OPTIONS = [
  {
    value: 'no_checks',
    text: s__('DuoWorkflowSettings|No checks'),
    description: s__(
      'DuoWorkflowSettings|Turn off scanning entirely. No prompt data is sent to third-party services.',
    ),
  },
  {
    value: 'log_only',
    text: s__('DuoWorkflowSettings|Log only'),
    description: s__('DuoWorkflowSettings|Scan and log results, but do not block requests.'),
  },
  {
    value: 'interrupt',
    text: s__('DuoWorkflowSettings|Interrupt'),
    description: s__('DuoWorkflowSettings|Scan and block detected prompt injection attempts.'),
  },
];
