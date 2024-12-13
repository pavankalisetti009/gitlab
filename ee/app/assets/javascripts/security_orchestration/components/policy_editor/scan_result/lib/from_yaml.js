import { safeLoad } from 'js-yaml';
import { isBoolean, isEqual } from 'lodash';
import { extractPolicyContent } from 'ee/security_orchestration/components/utils';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { addIdsToPolicy, hasInvalidKey, isValidPolicy } from '../../utils';
import { PRIMARY_POLICY_KEYS } from '../../constants';
import { OPEN, CLOSED } from '../advanced_settings/constants';
import {
  BLOCK_GROUP_BRANCH_MODIFICATION,
  VALID_APPROVAL_SETTINGS,
  PERMITTED_INVALID_SETTINGS,
  PERMITTED_INVALID_SETTINGS_KEY,
} from './settings';

/*
  Construct a policy object expected by the policy editor from a yaml manifest.
*/
export const fromYaml = ({ manifest, validateRuleMode = false }) => {
  try {
    const { securityPoliciesNewYamlFormat = false } = window.gon?.features || {};
    const payload = securityPoliciesNewYamlFormat
      ? extractPolicyContent({
          manifest,
          type: POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter,
          withType: true,
        })
      : safeLoad(manifest, { json: true });

    const policy = addIdsToPolicy(payload);

    if (validateRuleMode) {
      /**
       * These values are what is supported by rule mode. If the yaml has any other values,
       * rule mode will be disabled. This validation should not be used to check whether
       * the yaml is a valid policy; that should be done on the backend with the official
       * schema. These values should not be retrieved from the backend schema because
       * the UI for new attributes may not be available.
       */

      const primaryKeys = [
        ...PRIMARY_POLICY_KEYS,
        'rules',
        'actions',
        'approval_settings',
        'fallback_behavior',
        'policy_tuning',
      ];

      const rulesKeys = [
        'type',
        'branches',
        'branch_type',
        'branch_exceptions',
        'commits',
        'license_states',
        'license_types',
        'scanners',
        'severity_levels',
        'vulnerabilities_allowed',
        'vulnerability_states',
        'vulnerability_age',
        'vulnerability_attributes',
        'id',
        'match_on_inclusion_license',
      ];
      const actionsKeys = [
        'type',
        'approvals_required',
        'user_approvers',
        'group_approvers',
        'user_approvers_ids',
        'group_approvers_ids',
        'role_approvers',
        'id',
        'enabled',
      ];

      if (gon.features?.excludeLicensePackages) {
        rulesKeys.push('licenses');
      }

      const { approval_settings: settings = {}, fallback_behavior: fallback } = policy;

      // Temporary workaround to allow the rule builder to load with wrongly persisted settings
      const hasInvalidApprovalSettings = hasInvalidKey(settings, [
        ...VALID_APPROVAL_SETTINGS,
        PERMITTED_INVALID_SETTINGS_KEY,
      ]);

      const hasInvalidSettingStructure = !isEqual(settings, PERMITTED_INVALID_SETTINGS)
        ? !Object.entries(settings).every(
            ([key, value]) => isBoolean(value) || key === BLOCK_GROUP_BRANCH_MODIFICATION,
          )
        : false;

      const hasInvalidFallbackBehavior = fallback && ![OPEN, CLOSED].includes(fallback.fail);

      return isValidPolicy({ policy, primaryKeys, rulesKeys, actionsKeys }) &&
        !hasInvalidApprovalSettings &&
        !hasInvalidSettingStructure &&
        !hasInvalidFallbackBehavior
        ? policy
        : { error: true };
    }

    return policy;
  } catch {
    /**
     * Catch parsing error of safeLoad
     */
    return { error: true, key: 'yaml-parsing' };
  }
};

/**
 * Converts a security policy from yaml to an object
 * @param {String} manifest a security policy in yaml form
 * @returns {Object} security policy object and any errors
 */
export const createPolicyObject = (manifest) => {
  const policy = fromYaml({ manifest, validateRuleMode: true });

  return { policy, hasParsingError: Boolean(policy.error) };
};
