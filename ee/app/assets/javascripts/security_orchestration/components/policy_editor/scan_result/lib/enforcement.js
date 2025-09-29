import { s__ } from '~/locale';

export const ENFORCE_VALUE = 'enforce';

export const WARN_VALUE = 'warn';

export const ENFORCEMENT_OPTIONS = [
  { value: WARN_VALUE, text: s__('SecurityOrchestration|Warn mode') },
  { value: ENFORCE_VALUE, text: s__('SecurityOrchestration|Strictly enforced') },
];
