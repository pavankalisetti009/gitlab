export const DRAWER_MODES = {
  ADD: 'add',
  EDIT: 'edit',
};

export const CATEGORY_EDITABLE = 'EDITABLE';
export const CATEGORY_PARTIALLY_EDITABLE = 'PARTIALLY_EDITABLE';
export const CATEGORY_LOCKED = 'LOCKED';

export const defaultCategory = {
  name: '',
  description: '',
  multipleSelection: false,
  editableState: CATEGORY_EDITABLE,
};
