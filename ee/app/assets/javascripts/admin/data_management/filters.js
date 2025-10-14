export const formatListboxItems = (items) => {
  return items.map((type) => ({
    text: type.titlePlural,
    value: type.name,
  }));
};
