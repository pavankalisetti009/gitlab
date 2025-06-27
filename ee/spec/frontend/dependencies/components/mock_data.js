export const containerImagePath = {
  ancestors: null,
  topLevel: null,
  blobPath: 'test.link',
  path: 'container-image:nginx:1.17',
  image: 'nginx:1.17',
};

export const withoutPath = {
  ancestors: null,
  topLevel: null,
  blobPath: 'test.link',
  path: null,
};

export const withoutFilePath = {
  ancestors: null,
  topLevel: null,
  blobPath: null,
  path: 'package.json',
};

export const noPath = {
  ancestors: [],
  topLevel: false,
  blobPath: 'test.link',
  path: 'package.json',
};

export const topLevelPath = {
  ancestors: [],
  topLevel: true,
  blobPath: 'test.link',
  path: 'package.json',
};
