import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import PremiumFeaturesSection from 'ee/groups/discover/components/premium_features_section.vue';
import FeatureCard from 'ee/groups/discover/components/feature_card.vue';
import FeatureItem from 'ee/groups/discover/components/feature_item.vue';

describe('PremiumFeaturesSection', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = mountExtended(PremiumFeaturesSection);
  };

  const findFeatureCards = () => wrapper.findAllComponents(FeatureCard);
  const findFeatureItems = () => wrapper.findAllComponents(FeatureItem);
  const findPremiumFeaturesCicd = () => findFeatureCards().at(0);
  const findPremiumFeaturesPlatform = () => findFeatureCards().at(1);
  const findPremiumFeaturesVisibility = () => findFeatureCards().at(2);
  const findPremiumFeaturesScale = () => findFeatureCards().at(3);
  const findDuoFeaturesCompanion = () => findFeatureCards().at(4);
  const findDuoFeaturesBuild = () => findFeatureCards().at(5);

  describe('renders', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders premium features sections', () => {
      expect(findPremiumFeaturesCicd().exists()).toBe(true);
      expect(findPremiumFeaturesPlatform().exists()).toBe(true);
      expect(findPremiumFeaturesVisibility().exists()).toBe(true);
      expect(findPremiumFeaturesScale().exists()).toBe(true);
    });

    it('renders GitLab Duo sections', () => {
      expect(findDuoFeaturesCompanion().exists()).toBe(true);
      expect(findDuoFeaturesBuild().exists()).toBe(true);
    });
  });

  describe('popover toggle', () => {
    beforeEach(() => {
      createComponent();
    });

    it('opens popover when feature item is clicked', async () => {
      const featureItems = findFeatureItems();
      const targetFeature = featureItems.wrappers.find((w) => w.props('id') === 'merge-trains');

      await targetFeature.vm.$emit('popover-toggle', 'merge-trains');
      await nextTick();

      expect(wrapper.vm.openPopoverId).toBe('merge-trains');
    });

    it('closes popover when same feature is clicked again', async () => {
      wrapper.vm.openPopoverId = 'merge-trains';
      await nextTick();

      const featureItems = findFeatureItems();
      const targetFeature = featureItems.wrappers.find((w) => w.props('id') === 'merge-trains');

      await targetFeature.vm.$emit('popover-toggle', 'merge-trains');
      await nextTick();

      expect(wrapper.vm.openPopoverId).toBeNull();
    });

    it('switches popover when different feature is clicked', async () => {
      wrapper.vm.openPopoverId = 'merge-trains';
      await nextTick();

      const featureItems = findFeatureItems();
      const targetFeature = featureItems.wrappers.find((w) => w.props('id') === 'push-rules');

      await targetFeature.vm.$emit('popover-toggle', 'push-rules');
      await nextTick();

      expect(wrapper.vm.openPopoverId).toBe('push-rules');
    });
  });

  describe('feature items', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders feature items in premium features sections', () => {
      const cicdItems = findPremiumFeaturesCicd().findAllComponents(FeatureItem);
      const platformItems = findPremiumFeaturesPlatform().findAllComponents(FeatureItem);
      const visibilityItems = findPremiumFeaturesVisibility().findAllComponents(FeatureItem);
      const scaleItems = findPremiumFeaturesScale().findAllComponents(FeatureItem);

      expect(cicdItems).toHaveLength(wrapper.vm.premiumFeaturesCicd.length);
      expect(platformItems).toHaveLength(wrapper.vm.premiumFeaturesPlatform.length);
      expect(visibilityItems).toHaveLength(wrapper.vm.premiumFeaturesVisibility.length);
      expect(scaleItems).toHaveLength(wrapper.vm.premiumFeaturesScale.length);
    });

    it('renders feature items in GitLab Duo sections', () => {
      const companionItems = findDuoFeaturesCompanion().findAllComponents(FeatureItem);
      const buildItems = findDuoFeaturesBuild().findAllComponents(FeatureItem);

      expect(companionItems).toHaveLength(wrapper.vm.duoFeaturesCompanion.length);
      expect(buildItems).toHaveLength(wrapper.vm.duoFeaturesBuild.length);
    });

    it('passes openPopoverId to all feature items', async () => {
      wrapper.vm.openPopoverId = 'merge-trains';
      await nextTick();

      findFeatureItems().wrappers.forEach((feature) => {
        expect(feature.props('openPopoverId')).toBe('merge-trains');
      });
    });
  });
});
