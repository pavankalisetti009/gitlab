import {
  membersProvideData as ceMembersProvideData,
  groupsProvideData as ceGroupsProvideData,
} from '~/invite_members/utils';

export function membersProvideData(el) {
  if (!el) {
    return false;
  }

  const result = ceMembersProvideData(el);

  return {
    ...result,
    groupName: el.dataset.groupName,
  };
}

export function groupsProvideData(el) {
  if (!el) {
    return false;
  }

  const result = ceGroupsProvideData(el);

  return {
    ...result,
    groupName: el.dataset.groupName,
  };
}
