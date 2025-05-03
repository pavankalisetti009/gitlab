import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import resolvers from './resolvers/resolvers';
import typeDefs from './typedefs.graphql';

Vue.use(VueApollo);

const appendIncomingOntoExisting = (existing, incoming) => {
  if (!incoming) return existing;
  if (!existing) return incoming;

  return {
    ...incoming,
    nodes: [
      ...existing.nodes,
      ...incoming.nodes.filter(
        (incomingNode) =>
          // eslint-disable-next-line no-underscore-dangle
          !existing.nodes.find((existingNode) => existingNode.__ref === incomingNode.__ref),
      ),
    ],
  };
};

export const typePolicies = {
  Query: {
    fields: {
      sharedData: {
        read(cachedData) {
          return (
            cachedData || {
              showDiscardChangesModal: false,
              formTouched: false,
              history: [],
              cachedPayload: {
                __typename: 'CachedPayload',
                profileType: '',
                mode: '',
              },
              resetAndClose: false,
              __typename: 'SharedData',
            }
          );
        },
      },
    },
  },
  Group: {
    fields: {
      descendantGroups: {
        read(cachedData) {
          return cachedData;
        },
        merge: appendIncomingOntoExisting,
      },
    },
  },
};

export const defaultClient = createDefaultClient(resolvers, {
  cacheConfig: {
    typePolicies,
  },
  typeDefs,
});

export default new VueApollo({
  defaultClient,
});
