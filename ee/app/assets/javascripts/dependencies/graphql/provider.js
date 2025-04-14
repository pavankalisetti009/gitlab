import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';

Vue.use(VueApollo);

const getComponentVersions = () => {
  return {
    __typename: 'ComponentVersionConnection',
    pageInfo: {},
    nodes: [
      {
        id: '1',
        version: '1.0.0',
        __typename: 'ComponentVersion',
      },
      {
        id: '2',
        version: '1.0.1',
        __typename: 'ComponentVersion',
      },
      {
        id: '3',
        version: '1.0.2',
        __typename: 'ComponentVersion',
      },
      {
        id: '4',
        version: '1.0.4',
        __typename: 'ComponentVersion',
      },
      {
        id: '5',
        version: '2.0.0',
        __typename: 'ComponentVersion',
      },
    ],
  };
};

const resolvers = {
  Project: {
    componentVersions: getComponentVersions,
  },
  Group: {
    componentVersions: getComponentVersions,
  },
};

// Remove `resolvers` once backend returns project and group-level `componentVersions`
const defaultClient = createDefaultClient(resolvers);

export default new VueApollo({
  defaultClient,
});
