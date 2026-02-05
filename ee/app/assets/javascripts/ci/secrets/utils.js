import { s__ } from '~/locale';

export const formatGraphQLError = (errorString, defaultMessage) => {
  if (typeof errorString === 'string' && errorString.length > 0) {
    return errorString.replace('GraphQL error: ', '');
  }

  return (
    defaultMessage ||
    s__('SecretsManager|An error occurred while fetching secrets manager data. Please try again.')
  );
};
