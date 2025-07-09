import { formValidators } from '@gitlab/ui/dist/utils';
import { s__, sprintf } from '~/locale';

export const createFieldValidators = ({ requiredLabel, maxLength }) => {
  return [
    formValidators.required(requiredLabel),
    formValidators.factory(
      sprintf(
        s__('AICatalog|Input cannot exceed %{value} characters. Please shorten your input.'),
        {
          value: maxLength,
        },
      ),
      (value) => (value?.length || 0) <= maxLength,
    ),
  ];
};
