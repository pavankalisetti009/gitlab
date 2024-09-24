import { nextTick } from 'vue';
import waitForPromises from 'helpers/wait_for_promises';

export const groups = [
  {
    __typename: 'Group',
    id: 'gid://gitlab/Group/98',
    name: 'gitlab-policies-sub',
    fullPath: 'gitlab-policies/gitlab-policies-sub',
  },
  {
    __typename: 'Group',
    id: 'gid://gitlab/Group/99',
    name: 'gitlab-policies-sub-2',
    fullPath: 'gitlab-policies/gitlab-policies-sub-2',
  },
];

export const projects = [
  {
    __typename: 'Project',
    fullPath: 'gitlab-policies/test',
    id: 'gid://gitlab/Project/37',
    name: 'test',
  },
];

export const generateMockResponse = (index, basis, newPayload) => ({
  ...basis[index],
  policyScope: {
    ...basis[index].policyScope,
    ...newPayload,
  },
});

export const openDrawer = async (element, rows) => {
  element.vm.$emit('row-selected', rows);
  await nextTick();
  await waitForPromises();
};
