import { formValidators } from '@gitlab/ui/src/utils';
import { s__, sprintf } from '~/locale';

export const createFieldValidators = ({ requiredLabel, maxLength } = {}) => {
  const validators = [];

  if (requiredLabel !== undefined) {
    validators.push(formValidators.required(requiredLabel));
  }

  if (maxLength !== undefined) {
    validators.push(
      formValidators.factory(
        sprintf(
          s__('AICatalog|Input cannot exceed %{value} characters. Please shorten your input.'),
          {
            value: maxLength,
          },
        ),
        (value) => (value?.length || 0) <= maxLength,
      ),
    );
  }

  return validators;
};

export const mapSteps = (steps) =>
  steps.nodes.map((s) => ({
    id: s.agent.id,
    name: s.agent.name,
    versions: s.agent.versions,
    versionName: s.pinnedVersionPrefix,
  }));
