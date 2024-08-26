import { DUO_HEALTH_CHECK_CATEGORIES } from './constants';

export const probesByCategory = (probes) => {
  return DUO_HEALTH_CHECK_CATEGORIES.map((category) => ({
    ...category,
    probes: probes.filter(({ name }) => category.values.includes(name)),
  }));
};
