// https://docs.gitlab.com/ee/user/storage_usage_quotas#project-storage-limit
// declared in ee/app/models/namespaces/storage/root_excess_size.rb
export const PROJECT_ENFORCEMENT_TYPE = 'project_repository_limit';

// https://docs.gitlab.com/ee/user/storage_usage_quotas#namespace-storage-limit
// declared in ee/app/models/namespaces/storage/root_size.rb
export const NAMESPACE_ENFORCEMENT_TYPE = 'namespace_storage_limit';
