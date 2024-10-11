import { s__ } from '~/locale';

// https://docs.gitlab.com/ee/user/storage_usage_quotas#project-storage-limit
// declared in ee/app/models/namespaces/storage/root_excess_size.rb
export const PROJECT_ENFORCEMENT_TYPE = 'project_repository_limit';

// https://docs.gitlab.com/ee/user/storage_usage_quotas#namespace-storage-limit
// declared in ee/app/models/namespaces/storage/root_size.rb
export const NAMESPACE_ENFORCEMENT_TYPE = 'namespace_storage_limit';

export const STORAGE_STATISTICS_USAGE_QUOTA_LEARN_MORE = s__(
  'UsageQuota|Learn more about usage quotas.',
);

export const STORAGE_STATISTICS_PERCENTAGE_REMAINING = s__(
  'UsageQuota|%{percentageRemaining}%% namespace storage remaining.',
);

export const STORAGE_STATISTICS_TOTAL_STORAGE = s__('UsageQuota|Total storage');

export const STORAGE_STATISTICS_PURCHASED_STORAGE = s__('UsageQuota|Total purchased storage');

export const BUY_STORAGE = s__('UsageQuota|Buy storage');
