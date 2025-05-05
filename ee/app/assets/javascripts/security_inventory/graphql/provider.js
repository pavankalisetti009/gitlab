import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';

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

const defaultClient = createDefaultClient();

const appendGroupsClient = createDefaultClient(
  {},
  {
    cacheConfig: {
      typePolicies: {
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
      },
    },
  },
);

export default new VueApollo({
  clients: {
    defaultClient,
    appendGroupsClient,
  },
  defaultClient,
});
