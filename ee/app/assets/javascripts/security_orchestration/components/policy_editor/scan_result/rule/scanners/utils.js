import { xor, omit } from 'lodash';
import {
  ANY_OPERATOR,
  GREATER_THAN_OPERATOR,
  BRANCH_EXCEPTIONS_KEY,
} from 'ee/security_orchestration/components/policy_editor/constants';
import {
  AGE,
  AGE_TOOLTIP_NO_PREVIOUSLY_EXISTING_VULNERABILITY,
  AGE_TOOLTIP_MAXIMUM_REACHED,
  ATTRIBUTE,
  DEFAULT_VULNERABILITY_STATES,
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
  FIX_AVAILABLE,
  FALSE_POSITIVE,
  STATUS,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

/**
 * flatten groups of states to a single array
 * @param vulnerabilityStates
 * @returns {*[]|null}
 */
export function normalizeVulnerabilityStates(vulnerabilityStates) {
  const states = [
    ...(vulnerabilityStates[NEWLY_DETECTED] || []),
    ...(vulnerabilityStates[PREVIOUSLY_EXISTING] || []),
  ];

  if (!states.length) return null;

  const matchesDefault = xor(states, DEFAULT_VULNERABILITY_STATES).length === 0;

  return matchesDefault ? [] : states;
}

/**
 * used for adding new status filter
 * additionally to existing ones
 * @param filters
 * @returns {*&{[p: number]: boolean}}
 */
export function enableStatusFilter(filters) {
  const nextKey = filters[NEWLY_DETECTED] ? PREVIOUSLY_EXISTING : NEWLY_DETECTED;

  return {
    ...filters,
    [nextKey]: true,
  };
}

/**
 * Enable attribute filter based on selected attributes
 * @param attributes
 * @returns {*&{[p: number]: boolean}}
 */
export function enableAttributeFilter(attributes) {
  const key = Object.keys(attributes)[0] === FIX_AVAILABLE ? FALSE_POSITIVE : FIX_AVAILABLE;

  return {
    ...attributes,
    [key]: true,
  };
}

/**
 * Select/deselect filters
 * @param filter needs to be toggled
 * @param filters source object with all filters
 * @param onAttribute custom logic for attributes if required
 * @param vulnerabilityAttributes has more complex logic, requires whole object
 * @returns {*}
 */
export function selectFilter(filter, filters, { onAttribute, vulnerabilityAttributes } = {}) {
  switch (filter) {
    case STATUS:
      return enableStatusFilter(filters);
    case ATTRIBUTE:
      if (onAttribute) {
        onAttribute(enableAttributeFilter(vulnerabilityAttributes));
      }
      return filters;
    default:
      return {
        ...filters,
        [filter]: [],
      };
  }
}

/**
 * Remove property from payload
 * @param payload
 * @param key to be removed
 * @returns {Omit<{}, never>}
 */
export const removePropertyFromPayload = (payload, key = '') => {
  return omit(payload, [key]);
};

/**
 * Generate custom tooltip for age filter
 * @param filter
 * @param vulnerabilityStates
 * @returns {*|string}
 */
export function getAgeTooltip(filter, vulnerabilityStates) {
  switch (filter.value) {
    case AGE:
      if (!vulnerabilityStates[PREVIOUSLY_EXISTING]?.length) {
        return filter.tooltip[AGE_TOOLTIP_NO_PREVIOUSLY_EXISTING_VULNERABILITY];
      }
      return filter.tooltip[AGE_TOOLTIP_MAXIMUM_REACHED];
    default:
      return '';
  }
}

/**
 * Some yaml properties represented through empty array
 * when all items selected
 * @param values
 * @param allCount
 * @returns {*[]|any[]}
 */
export const selectEmptyArrayWhenAllSelected = (values = [], allCount) => {
  if (!Array.isArray(values) || Number.isNaN(Number(allCount))) {
    return [];
  }

  return values.length === allCount ? [] : values;
};

/**
 * Get collapse icon based on visibility state
 * @param isVisible
 * @returns {string}
 */
export const getCollapseIcon = (isVisible) => {
  return isVisible ? 'chevron-up' : 'chevron-down';
};

/**
 * Get vulnerabilities operator based on allowed count
 * @param vulnerabilitiesAllowed
 * @returns {string}
 */
export const getSelectedVulnerabilitiesOperator = (vulnerabilitiesAllowed) => {
  return vulnerabilitiesAllowed === 0 ? ANY_OPERATOR : GREATER_THAN_OPERATOR;
};

/**
 * Remove branch exceptions from scanner object
 * @param scanner
 * @returns {Object}
 */
export const removeExceptionsFromScanner = (scanner) => {
  const updatedScanner = { ...scanner };
  if (BRANCH_EXCEPTIONS_KEY in updatedScanner) {
    delete updatedScanner[BRANCH_EXCEPTIONS_KEY];
  }
  return updatedScanner;
};

/**
 * Update severity levels on scanner object
 * @param scanner
 * @param value
 * @returns {Object}
 */
export const updateSeverityLevels = (scanner, value) => {
  const updatedScanner = { ...scanner };
  if (value && value.length > 0) {
    updatedScanner.severity_levels = value;
  } else {
    delete updatedScanner.severity_levels;
  }
  return updatedScanner;
};
