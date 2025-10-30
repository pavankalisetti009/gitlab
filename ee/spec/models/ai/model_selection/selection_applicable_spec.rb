# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::ModelSelection::SelectionApplicable, feature_category: :"self-hosted_models" do
  context 'when the class is implemented correctly', :saas do
    let_it_be(:user) { create(:user) }

    let_it_be(:first_group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be(:second_group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :duo_pro) }

    let!(:different_namespace_add_on) do
      create(:gitlab_subscription_add_on_purchase, namespace: first_group, add_on: duo_pro_add_on)
    end

    let!(:same_namespace_add_on) do
      [
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: second_group),
        create(:gitlab_subscription_add_on_purchase, namespace: second_group, add_on: duo_pro_add_on)
      ]
    end

    let(:included_class) do
      Class.new do
        include Gitlab::Utils::StrongMemoize
        include ::Ai::ModelSelection::SelectionApplicable

        def initialize(current_user)
          @current_user = current_user
        end

        attr_reader :current_user
      end
    end

    subject(:included_instance) { included_class.new(user) }

    context 'when there is no assignment' do
      describe '#get_default_duo_namespace' do
        it 'returns nil' do
          expect(included_instance.get_default_duo_namespace).to be_nil
        end
      end

      describe '#distinct_eligible_assignments' do
        it 'returns an empty enumerable' do
          expect(included_instance.distinct_eligible_assignments).to be_empty
        end
      end

      describe '#user_assigned_duo_namespaces' do
        it 'returns an empty enumerable' do
          expect(included_instance.user_assigned_duo_namespaces).to be_empty
        end
      end

      describe '#default_duo_namespace_required?' do
        it 'returns false' do
          expect(included_instance.default_duo_namespace_required?).to be_falsey
        end
      end
    end

    context 'when there is only one assignment' do
      let!(:user_assignment) do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: different_namespace_add_on, user: user)
      end

      describe '#get_default_duo_namespace' do
        it 'returns the related group' do
          expect(included_instance.get_default_duo_namespace).to eq(first_group)
        end
      end

      describe '#distinct_eligible_assignments' do
        it 'returns the related assigment' do
          actual_assignment = included_instance.distinct_eligible_assignments
          expected_assignment = [user_assignment]

          expect(actual_assignment).to match_array(expected_assignment)
        end
      end

      describe '#user_assigned_duo_namespaces' do
        it 'returns an array with only one related group inside' do
          expect(included_instance.user_assigned_duo_namespaces).to match_array([first_group])
        end
      end

      describe '#default_duo_namespace_required?' do
        it 'returns false' do
          expect(included_instance.default_duo_namespace_required?).to be_falsey
        end
      end
    end

    context 'when there is multiple assignments' do
      let!(:user_assignments) do
        add_ons = [different_namespace_add_on, *same_namespace_add_on]

        add_ons.map do |add_on|
          create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on, user: user)
        end
      end

      describe '#distinct_eligible_assignments' do
        it 'returns the related assigments' do
          actual_assignment = included_instance.distinct_eligible_assignments

          expected_namespaces = [first_group, second_group]
          actual_namespaces = actual_assignment.map(&:namespace)

          expect(actual_assignment.size).to eq(2)
          expect(actual_namespaces).to match_array(expected_namespaces)
        end
      end

      describe '#user_assigned_duo_namespaces' do
        it 'returns an array with related groups inside' do
          expect(included_instance.user_assigned_duo_namespaces).to match_array([first_group, second_group])
        end
      end

      context 'when user preference has a default duo add on assignment' do
        before do
          allow(user.user_preference).to receive(:get_default_duo_namespace).and_return(second_group)
        end

        describe '#get_default_duo_namespace' do
          it 'returns the related group' do
            expect(included_instance.get_default_duo_namespace).to eq(second_group)
          end
        end

        describe '#default_duo_namespace_required?' do
          it 'returns false' do
            expect(included_instance.default_duo_namespace_required?).to be_falsey
          end
        end
      end

      context 'when user preference does not have a default duo add on assignment' do
        describe '#get_default_duo_namespace' do
          it 'returns nil' do
            expect(included_instance.get_default_duo_namespace).to be_nil
          end
        end

        describe '#default_duo_namespace_required?' do
          context 'when the user has a default namespace set' do
            before do
              allow(user.user_preference).to receive(:get_default_duo_namespace).and_return(second_group)
            end

            it 'returns false' do
              expect(included_instance.default_duo_namespace_required?).to be_falsey
            end
          end

          context 'when the user has no default namespace set' do
            before do
              allow(user.user_preference).to receive(:get_default_duo_namespace).and_return(nil)
            end

            context 'when user cannot :assign_default_duo_group' do
              before do
                allow(Ability).to receive(:allowed?).with(user, :assign_default_duo_group, user).and_return(false)
              end

              it 'returns false' do
                expect(included_instance.default_duo_namespace_required?).to be_falsey
              end
            end

            context 'when user can :assign_default_duo_group' do
              before do
                allow(Ability).to receive(:allowed?).with(user, :assign_default_duo_group, user).and_return(true)
              end

              it 'returns true' do
                expect(included_instance.default_duo_namespace_required?).to be_truthy
              end
            end
          end
        end
      end
    end
  end

  context 'when the methods are not implemented', :saas do
    let(:unimplemented_class) do
      Class.new do
        include Gitlab::Utils::StrongMemoize
        include ::Ai::ModelSelection::SelectionApplicable
      end
    end

    subject(:included_instance) { unimplemented_class.new }

    describe '#current_user' do
      it 'raises NotImplementedError when not implemented' do
        expect { included_instance.current_user }.to raise_error(
          NotImplementedError,
          "#current_user method must be implement in "
        )
      end
    end
  end
end
