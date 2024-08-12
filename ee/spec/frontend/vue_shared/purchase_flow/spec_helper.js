import { merge } from 'lodash';
import activeStepQuery from 'ee/vue_shared/purchase_flow/graphql/queries/active_step.query.graphql';
import furthestAccessedStepQuery from 'ee/vue_shared/purchase_flow/graphql/queries/furthest_accessed_step.query.graphql';
import stepListQuery from 'ee/vue_shared/purchase_flow/graphql/queries/step_list.query.graphql';
import resolvers from 'ee/vue_shared/purchase_flow/graphql/resolvers';
import createMockApollo from 'helpers/mock_apollo_helper';

// eslint-disable-next-line max-params
export function createMockApolloProvider(
  stepList,
  initialStepIndex = 0,
  additionalResolvers = {},
  handlers = [],
) {
  const mockApollo = createMockApollo(handlers, merge({}, resolvers, additionalResolvers));
  mockApollo.clients.defaultClient.cache.writeQuery({
    query: stepListQuery,
    data: { stepList },
  });
  mockApollo.clients.defaultClient.cache.writeQuery({
    query: activeStepQuery,
    data: { activeStep: stepList[initialStepIndex] },
  });
  mockApollo.clients.defaultClient.cache.writeQuery({
    query: furthestAccessedStepQuery,
    data: { furthestAccessedStep: stepList[initialStepIndex] },
  });

  return mockApollo;
}
