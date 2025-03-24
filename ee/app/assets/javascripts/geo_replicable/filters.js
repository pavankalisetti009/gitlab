import { TOKEN_TYPES } from './constants';

export const getReplicableTypeFilter = (value) => {
  return {
    type: TOKEN_TYPES.REPLICABLE_TYPE,
    value,
  };
};
