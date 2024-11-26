import { isEmpty } from 'lodash';
import {
  AGE,
  ALLOW_DENY,
  ALLOWED,
  ATTRIBUTE,
  DENIED,
  FALSE_POSITIVE,
  FIX_AVAILABLE,
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
  STATUS,
} from '../rule/scan_filters/constants';
import { groupVulnerabilityStatesWithDefaults } from './vulnerability_states';

export const buildFiltersFromRule = (rule) => {
  const {
    vulnerability_age: vulnerabilityAge,
    vulnerability_states: vulnerabilityStates,
    vulnerability_attributes: attributes,
  } = rule || {};

  const vulnerabilityStateGroups = groupVulnerabilityStatesWithDefaults(vulnerabilityStates);
  const vulnerabilityAttributes = attributes || {};

  const filters = {
    [AGE]: !isEmpty(vulnerabilityAge),
    [NEWLY_DETECTED]:
      Boolean(vulnerabilityStateGroups[NEWLY_DETECTED]) || isEmpty(vulnerabilityStateGroups),
    [PREVIOUSLY_EXISTING]: Boolean(vulnerabilityStateGroups[PREVIOUSLY_EXISTING]),
    [FALSE_POSITIVE]: vulnerabilityAttributes[FALSE_POSITIVE] !== undefined,
    [FIX_AVAILABLE]: vulnerabilityAttributes[FIX_AVAILABLE] !== undefined,
  };
  filters[STATUS] = Boolean(filters[NEWLY_DETECTED] && filters[PREVIOUSLY_EXISTING]);
  filters[ATTRIBUTE] = Boolean(filters[FALSE_POSITIVE] && filters[FIX_AVAILABLE]);

  return filters;
};

export const buildFiltersFromLicenceRule = (rule) => {
  let { licenses = {} } = rule || {};

  licenses = licenses ?? {};

  return {
    [STATUS]: true,
    [ALLOW_DENY]: ALLOWED in licenses || DENIED in licenses,
  };
};
