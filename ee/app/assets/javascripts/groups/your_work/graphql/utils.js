import { formatGroup as CeFormatGroup } from '~/groups/your_work/graphql/utils';

export const formatGroup = (group) => ({
  ...CeFormatGroup(group),
  // Overwrite CE `children` key to avoid circular references
  children: group.children?.length ? group.children.map(formatGroup) : [],
  // Properties below are hard coded for now until API has been
  // updated to support these fields.
  markedForDeletionOn: null,
  isAdjournedDeletionEnabled: false,
  permanentDeletionDate: null,
});
