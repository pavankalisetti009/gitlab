import { safeDump, safeLoad } from 'js-yaml';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { extractPolicyContent } from 'ee/security_orchestration/components/utils';
import { hasInvalidKey } from '../utils';
import { PRIMARY_POLICY_KEYS } from '../constants';

/*
  Construct a policy object expected by the policy editor from a yaml manifest.
*/
export const fromYaml = ({ manifest, validateRuleMode = false }) => {
  try {
    const { securityPoliciesNewYamlFormat = false } = window.gon?.features || {};

    const policy = securityPoliciesNewYamlFormat
      ? extractPolicyContent({
          manifest,
          type: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter,
          withType: true,
        })
      : safeLoad(manifest, { json: true });

    if (validateRuleMode) {
      /**
       * These values are what is supported by rule mode. If the yaml has any other values,
       * rule mode will be disabled. This validation should not be used to check whether
       * the yaml is a valid policy; that should be done on the backend with the official
       * schema. These values should not be retrieved from the backend schema because
       * the UI for new attributes may not be available.
       */
      const primaryKeys = [...PRIMARY_POLICY_KEYS, 'pipeline_config_strategy', 'content', 'suffix'];

      const contentKeys = ['include'];
      const pipelineConfigStrategies = ['inject_ci', 'override_project_ci'];

      const hasInvalidPipelineConfigStrategy = (strategy) =>
        !pipelineConfigStrategies.includes(strategy);

      return !(
        hasInvalidKey(policy, primaryKeys) ||
        hasInvalidKey(policy.content, contentKeys) ||
        hasInvalidPipelineConfigStrategy(policy.pipeline_config_strategy)
      )
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

export const getInitialPolicy = (defaultPolicy, params = {}) => {
  const {
    type,
    compliance_framework_id: frameworkId,
    compliance_framework_name: frameworkName,
  } = params;
  const [file, project] = params?.path?.split('@') ?? [];

  if (!file || !project || !frameworkId || !frameworkName || !type) {
    return defaultPolicy;
  }

  const newPolicy = Object.assign(fromYaml({ manifest: defaultPolicy }), {
    type,
    pipeline_config_strategy: 'override_project_ci',
    policy_scope: { compliance_frameworks: [{ id: Number(frameworkId) }] },
    content: { include: [{ project, file }] },
    metadata: { compliance_pipeline_migration: true },
  });

  return safeDump(newPolicy);
};
