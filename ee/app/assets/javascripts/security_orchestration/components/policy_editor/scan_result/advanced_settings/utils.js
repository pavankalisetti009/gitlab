import { uniqueId } from 'lodash';
import { EXCEPTIONS_FULL_OPTIONS_MAP } from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';

export const createSourceBranchPatternObject = ({ id = '', source = {}, target = {} } = {}) => ({
  id: id || uniqueId('pattern_'),
  source,
  target,
});

/**
 * remove ids from items
 * @param items
 * @returns {*[]}
 */
export const removeIds = (items = []) => {
  return items.map(({ id, ...item }) => ({ ...item }));
};

/**
 * Filter out invalid exceptions keys
 * @param keys
 * @returns {string[]};
 */
export const onlyValidKeys = (keys) => {
  const validKeys = Object.keys(EXCEPTIONS_FULL_OPTIONS_MAP);
  return keys.filter((key) => validKeys.includes(key));
};
