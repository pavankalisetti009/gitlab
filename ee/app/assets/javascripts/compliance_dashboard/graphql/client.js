import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { concatPagination } from '@apollo/client/utilities';
import createDefaultClient from '~/lib/graphql';

Vue.use(VueApollo);

export const cacheConfig = {
  typePolicies: {
    Namespace: {
      fields: {
        projects: {
          keyArgs(args) {
            const KNOWN_PAGINATION_ARGS = ['first', 'last', 'before', 'after'];
            return Object.keys(args).filter((key) => !KNOWN_PAGINATION_ARGS.includes(key));
          },
        },
      },
    },
    ProjectConnection: {
      fields: {
        nodes: concatPagination(),
      },
    },
  },
};

const defaultClient = createDefaultClient({}, { cacheConfig });

export const apolloProvider = new VueApollo({
  defaultClient,
});
