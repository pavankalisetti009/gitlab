const createState = ({
  titlePlural,
  graphqlMutationRegistryClass,
  geoCurrentSiteId,
  geoTargetSiteId,
}) => ({
  titlePlural,
  graphqlMutationRegistryClass,
  geoCurrentSiteId,
  geoTargetSiteId,
  isLoading: false,
});
export default createState;
