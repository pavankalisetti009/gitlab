import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { relayStylePagination } from '@apollo/client/utilities';
import createDefaultClient from '~/lib/graphql';
import resolvers from 'ee/security_configuration/security_attributes/graphql/resolvers';

Vue.use(VueApollo);

const defaultClient = createDefaultClient(resolvers);
const appendGroupsClient = createDefaultClient(
  {},
  {
    cacheConfig: {
      typePolicies: {
        Group: {
          fields: {
            descendantGroups: relayStylePagination(),
          },
        },
      },
    },
  },
);

export default new VueApollo({
  defaultClient,
  clients: {
    appendGroupsClient,
  },
});
