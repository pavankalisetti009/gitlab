import { createMockApolloProvider } from 'ee_jest/subscriptions/shared/components/purchase_flow/spec_helper';
import { STEPS } from 'ee_jest/subscriptions/shared/components/purchase_flow/mock_data';
import { stateData as customerData } from 'ee_jest/subscriptions/mock_data';
import stateQuery from 'ee/subscriptions/graphql/queries/state.query.graphql';
import BillingAddress from './billing_address.vue';

export default {
  component: BillingAddress,
  title: 'ee/subscriptions/shared/components/purchase_flow/checkout/billing_address',
};

const NLcustomer = {
  ...customerData,
  customer: {
    country: 'NL',
    address1: 'Museumplein 6',
    address2: 'address line 2',
    city: 'Amsterdam',
    zipCode: '1071',
    state: null,
    company: null,
    __typename: 'CUSTOMER_TYPE',
  },
};

const apolloResolvers = {
  Query: {
    countries: () =>
      Promise.resolve([
        { id: 'NL', name: 'Netherlands', flag: 'NL', internationalDialCode: '31' },
        { id: 'US', name: 'United States of America', flag: 'US', internationalDialCode: '1' },
      ]),
    states: () => Promise.resolve([{ id: 'CA', name: 'California' }]),
  },
};

const apolloProvider = createMockApolloProvider(STEPS, 1, {
  ...apolloResolvers,
});
apolloProvider.clients.defaultClient.cache.writeQuery({
  query: stateQuery,
  data: NLcustomer,
});

const Template = (args, { argTypes }) => ({
  components: { BillingAddress },
  apolloProvider,
  props: Object.keys(argTypes),
  template: '<billing-address v-bind="$props" />',
});

export const Default = Template.bind({});
Default.args = {};
