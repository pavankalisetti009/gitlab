export default ({ pagination }) => ({
  pagination: {
    totalItems: pagination?.totalItems ?? 0,
  },
});
