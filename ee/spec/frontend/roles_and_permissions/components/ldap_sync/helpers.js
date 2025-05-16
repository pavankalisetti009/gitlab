import { GlFormGroup } from '@gitlab/ui';
import { stubComponent } from 'helpers/stub_component';

export const glFormGroupStub = stubComponent(GlFormGroup, {
  props: ['label', 'state', 'invalidFeedback'],
});
