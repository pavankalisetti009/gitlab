import { get, set } from 'lodash';

export const buildVulnerabilitiesPayload = (payload, property = '', value = {}) => {
  return set(payload, ['vulnerabilities', 'vulnerability_attributes', property], value);
};

export const getVulnerabilityAttribute = (payload, property = '') => {
  return get(payload, ['vulnerabilities', 'vulnerability_attributes', property], undefined);
};
