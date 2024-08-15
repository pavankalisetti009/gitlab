import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP, TYPENAME_USER } from '~/graphql_shared/constants';
import { defaultClient } from 'ee/vue_shared/security_configuration/graphql/provider';
import { POLICY_TYPE_COMPONENT_OPTIONS } from './components/constants';
import { GROUP_TYPE, ROLE_TYPE, USER_TYPE } from './constants';

/**
 * Get a property from a policy's typename
 * @param {String} typeName policy's typename from GraphQL
 * @returns {String|null} policy property if available
 */
export const getPolicyType = (typeName = '', field = 'value') => {
  return Object.values(POLICY_TYPE_COMPONENT_OPTIONS).find(
    (component) => component.typeName === typeName,
  )?.[field];
};

/**
 * Separate existing approvers by type
 * @param {Array} existingApprovers all approvers
 * @returns {Object} approvers separated by type
 */
export const decomposeApprovers = (existingApprovers) => {
  const GROUP_TYPE_UNIQ_KEY = 'fullName';

  return existingApprovers.reduce((acc, approver) => {
    if (typeof approver === 'string') {
      if (!acc[ROLE_TYPE]) {
        acc[ROLE_TYPE] = [approver];
        return acc;
      }

      acc[ROLE_TYPE].push(approver);
      return acc;
    }

    const approverKeys = Object.keys(approver);

    let type = USER_TYPE;
    let value = convertToGraphQLId(TYPENAME_USER, approver.id);

    if (approverKeys.includes(GROUP_TYPE_UNIQ_KEY)) {
      type = GROUP_TYPE;
      value = convertToGraphQLId(TYPENAME_GROUP, approver.id);
    }

    if (acc[type] === undefined) {
      acc[type] = [];
    }

    acc[type].push({
      ...approver,
      type,
      value,
    });

    return acc;
  }, {});
};

/**
 * Removes initial line dashes from a policy YAML that is received from the API, which
 * is not required for the user.
 * @param {String} manifest the policy from the API request
 * @returns {String} the policy without the initial dashes or the initial string
 */
export const removeUnnecessaryDashes = (manifest) => {
  return manifest.replace('---\n', '');
};

/**
 * Create GraphQL Client for security policies
 */
export const gqClient = defaultClient;
