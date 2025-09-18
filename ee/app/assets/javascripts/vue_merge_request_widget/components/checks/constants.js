import { s__ } from '~/locale';

export const WARN_MODE = 'warn_mode';
export const EXCEPTION_MODE = 'exception_mode';

export const WARN_MODE_BYPASS_REASONS = [
  {
    value: 'policy_false_positive',
    text: s__('SecurityOrchestration|Policy false positive'),
  },
  {
    value: 'scanner_false_positive',
    text: s__('SecurityOrchestration|Scanner false positive'),
  },
  { value: 'emergency_hotfix', text: s__('SecurityOrchestration|Emergency hotfix') },
  { value: 'other', text: s__('SecurityOrchestration|Other') },
];

export const WARN_MODE_NEXT_STEPS = [
  s__('SecurityOrchestration|All selected policy requirements will be bypassed'),
  s__('SecurityOrchestration|The action will be logged in the audit log'),
];

export const INITIAL_STATE_NEXT_STEPS = [
  s__(
    'SecurityOrchestration|You have permissions to bypass all checks in this merge request or selectively only bypass Warn Mode policies.',
  ),
  s__(
    'SecurityOrchestration|Choose from the options below based on how you would like to proceed.',
  ),
];
