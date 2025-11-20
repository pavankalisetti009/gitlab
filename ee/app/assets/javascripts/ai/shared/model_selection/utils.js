import { __, sprintf } from '~/locale';

export const formatDefaultModelText = (defaultModel) => {
  return defaultModel?.name
    ? sprintf(__('%{modelName} - Default'), { modelName: defaultModel.name })
    : '';
};
