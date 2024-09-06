/**
 * @file this service connects Promotion requests Vuex store with the Promotion requests App. When a
 * member role is changed — the App needs to reset it's pagination state and refetch the data
 */

const subscribers = [];

export const subscribe = (callback) => {
  subscribers.push(callback);
  return () => {
    const index = subscribers.indexOf(callback);
    if (index !== -1) {
      subscribers.splice(index, 1);
    }
  };
};

export const invalidate = () => {
  subscribers.forEach((callback) => callback());
};
