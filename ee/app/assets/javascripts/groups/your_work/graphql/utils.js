import { formatGroup as CeFormatGroup } from '~/groups/your_work/graphql/utils';

export const formatGroup = (group) => ({
  ...CeFormatGroup(group),
  // Properties below are hard coded for now until API has been
  // updated to support these fields.
  markedForDeletionOn: null,
  isAdjournedDeletionEnabled: false,
  permanentDeletionDate: null,
});
