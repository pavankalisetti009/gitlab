# frozen_string_literal: true

require "spec_helper"

RSpec.describe Types::Namespaces::UserLevelPermissions::GroupNamespaceUserLevelPermissionsType, feature_category: :shared do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }

  subject(:type) { described_class.resolve_type(group, {}) }

  it_behaves_like 'expose all user permissions fields for the namespace'

  describe "permission values" do
    let_it_be(:non_member) { create(:user) }
    let_it_be(:guest) { create(:user) }
    let_it_be(:developer) { create(:user) }
    let_it_be(:maintainer) { create(:user) }
    let_it_be(:owner) { create(:user) }
    let_it_be(:group) do
      create(
        :group,
        :private,
        guests: [guest],
        developers: [developer],
        maintainers: [maintainer],
        owners: [owner]
      )
    end

    context "for can_bulk_edit_epics permission" do
      where(:user_role, :expected) do
        :non_member | false
        :guest      | false
        :developer  | false
        :maintainer | true
        :owner      | true
      end

      with_them do
        let(:current_user) { send(user_role) }

        it "returns the correct permission value" do
          # More specific stubbing to ensure it applies to the current request
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:can?)
                      .with(current_user, :bulk_admin_epic, group).and_return(expected)
          end

          actual = resolve_field(:can_bulk_edit_epics, group, current_user: current_user)

          expect(actual).to eq(expected)
        end
      end
    end

    context "for can_create_epic permission" do
      where(:user_role, :expected) do
        :non_member | false
        :guest      | false
        :developer  | true
        :maintainer | true
        :owner      | true
      end

      with_them do
        let(:current_user) { send(user_role) }

        it "returns the correct permission value" do
          # More specific stubbing to ensure it applies to the current request
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:can?)
                      .with(current_user, :create_epic, group).and_return(expected)
          end

          actual = resolve_field(:can_create_epic, group, current_user: current_user)

          expect(actual).to eq(expected)
        end
      end
    end
  end

  context "when group settings restrict permissions" do
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:developer) { create(:user) }
    let_it_be(:owner) { create(:user) }

    before_all do
      group.add_developer(developer)
      group.add_owner(owner)
    end

    context "when bulk editing epics is restricted" do
      before do
        allow_next_instance_of(Ability) do |instance|
          allow(instance).to receive(:can?).with(:can_bulk_edit_epics, group).and_return(false)
        end
      end

      it "returns false when permission is denied" do
        expect(resolve_field(:can_bulk_edit_epics, group, current_user: user)).to be(false)
      end
    end

    context "when epic creation is restricted" do
      before do
        allow_next_instance_of(Ability) do |instance|
          allow(instance).to receive(:can?).with(:can_create_epic, group).and_return(false)
        end
      end

      it "returns false when permission is denied" do
        expect(resolve_field(:can_create_epic, group, current_user: user)).to be(false)
      end
    end
  end
end
