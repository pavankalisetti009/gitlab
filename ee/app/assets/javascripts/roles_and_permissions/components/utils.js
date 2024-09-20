// Custom roles have an id property, default roles don't.
export const isCustomRole = (role) => Boolean(role.id);
