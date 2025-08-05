import { getExpectedFilterTokenConfigs } from 'jest/admin/users/mock_data';

export { STANDARD_TOKEN_CONFIGS } from 'jest/admin/users/mock_data';

export const FILTER_TOKEN_CONFIGS = getExpectedFilterTokenConfigs([
  { value: 'admins', title: 'Administrator' },
  { value: 'auditors', title: 'Auditor' },
  { value: 'external', title: 'External' },
]);
