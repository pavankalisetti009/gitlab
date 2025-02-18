import Api from 'ee/api';

export const resolvers = {
  Query: {
    subscription(_, { namespaceId }) {
      return Api.userSubscription(namespaceId).then(({ data }) => {
        return {
          id: namespaceId,
          endDate: data.billing.subscription_end_date,
          startDate: data.billing.subscription_start_date,
          plan: {
            code: data.plan.code,
            name: data.plan.name,
            trial: Boolean(data.plan.trial),
            auto_renew: Boolean(data.plan.auto_renew),
            upgradable: Boolean(data.plan.upgradable),
            exclude_guests: Boolean(data.plan.exclude_guests),
          },
          usage: {
            seats_in_subscription: Number(data.usage.seats_in_subscription),
            seats_in_use: Number(data.usage.seats_in_use),
            max_seats_used: Number(data.usage.max_seats_used),
            seats_owed: Number(data.usage.seats_owed),
          },
          billing: {
            subscription_start_date: data.billing.subscription_start_date,
            subscription_end_date: data.billing.subscription_end_date,
            trial_ends_on: data.billing.trial_ends_on,
          },
        };
      });
    },
  },
};
