import { xor, omit } from 'lodash';
import {
  AGE,
  AGE_TOOLTIP_NO_PREVIOUSLY_EXISTING_VULNERABILITY,
  AGE_TOOLTIP_MAXIMUM_REACHED,
  DEFAULT_VULNERABILITY_STATES,
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
  FIX_AVAILABLE,
  FALSE_POSITIVE,
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
