import { convertToGraphQLId } from '~/graphql_shared/utils';

const TYPENAME_VIRTUAL_REGISTRY = 'VirtualRegistries::Packages::Maven::Registry';

export const convertToMavenRegistryGraphQLId = (id) =>
  convertToGraphQLId(TYPENAME_VIRTUAL_REGISTRY, id);
