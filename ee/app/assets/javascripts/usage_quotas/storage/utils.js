import { parseBoolean } from '~/lib/utils/common_utils';
import { storageTypeHelpPaths as helpLinks } from '~/usage_quotas/storage/constants';
import { NAMESPACE_ENFORCEMENT_TYPE, PROJECT_ENFORCEMENT_TYPE } from './constants';

export const parseNamespaceProvideData = (el) => {
  if (!el) {
    return {};
  }

  const {
    namespaceId,
    namespacePath,
    userNamespace,
    defaultPerPage,
    namespacePlanName,
    purchaseStorageUrl,
    buyAddonTargetAttr,
    enforcementType,
    isInNamespaceLimitsPreEnforcement,
    totalRepositorySizeExcess,
  } = el.dataset;

  const perProjectStorageLimit = el.dataset.perProjectStorageLimit
    ? Number(el.dataset.perProjectStorageLimit)
    : 0;
  const namespaceStorageLimit = el.dataset.namespaceStorageLimit
    ? Number(el.dataset.namespaceStorageLimit)
    : 0;
  const isUsingNamespaceEnforcement = enforcementType === NAMESPACE_ENFORCEMENT_TYPE;
  const isUsingProjectEnforcement = enforcementType === PROJECT_ENFORCEMENT_TYPE;
  const isUsingProjectEnforcementWithLimits =
    isUsingProjectEnforcement && perProjectStorageLimit !== 0;
  const isUsingProjectEnforcementWithNoLimits =
    isUsingProjectEnforcement && perProjectStorageLimit === 0;

  return {
    namespaceId: parseInt(namespaceId, 10),
    namespacePath,
    userNamespace: parseBoolean(userNamespace),
    defaultPerPage: Number(defaultPerPage),
    namespacePlanName,
    perProjectStorageLimit,
    namespaceStorageLimit,
    purchaseStorageUrl,
    buyAddonTargetAttr,
    isInNamespaceLimitsPreEnforcement: parseBoolean(isInNamespaceLimitsPreEnforcement),
    totalRepositorySizeExcess: totalRepositorySizeExcess && Number(totalRepositorySizeExcess),
    isUsingNamespaceEnforcement,
    isUsingProjectEnforcementWithLimits,
    isUsingProjectEnforcementWithNoLimits,
    customSortKey: isUsingProjectEnforcementWithLimits ? 'EXCESS_REPO_STORAGE_SIZE_DESC' : null,
    helpLinks,
  };
};
