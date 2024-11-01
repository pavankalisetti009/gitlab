import activeStepQuery from 'ee/subscriptions/shared/components/purchase_flow/graphql/queries/active_step.query.graphql';
import stepListQuery from 'ee/subscriptions/shared/components/purchase_flow/graphql/queries/step_list.query.graphql';
import furthestAccessedStepQuery from 'ee/subscriptions/shared/components/purchase_flow/graphql/queries/furthest_accessed_step.query.graphql';
import resolvers from 'ee/subscriptions/shared/components/purchase_flow/graphql/resolvers';
import typeDefs from 'ee/subscriptions/shared/components/purchase_flow/graphql/typedefs.graphql';
import createDefaultClient from '~/lib/graphql';
import { STEPS } from '../constants';

function createClient(stepList) {
  const client = createDefaultClient(resolvers, {
    typeDefs,
  });

  client.cache.writeQuery({
    query: stepListQuery,
    data: {
      stepList,
    },
  });

  client.cache.writeQuery({
    query: activeStepQuery,
    data: {
      activeStep: stepList[0],
    },
  });

  client.cache.writeQuery({
    query: furthestAccessedStepQuery,
    data: {
      furthestAccessedStep: stepList[0],
    },
  });

  return client;
}

export default createClient(STEPS);
