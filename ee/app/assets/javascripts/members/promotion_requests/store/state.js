export default ({ totalItems }) => ({
  pagination: {
    totalItems: totalItems ?? 0,
  },
});
