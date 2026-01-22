import { s__ } from '~/locale';

export default {
  registries: {
    emptyStateTitle: s__('VirtualRegistry|There are no container virtual registries yet'),
  },
  upstreams: {
    emptyStateTitle: s__('VirtualRegistry|Connect Container virtual registry to an upstream'),
    emptyStateDescription: s__(
      'VirtualRegistry|Configure an upstream registry to manage Container artifacts and cache entries.',
    ),
  },
};
