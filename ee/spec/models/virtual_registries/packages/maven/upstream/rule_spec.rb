# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::Upstream::Rule, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  subject(:rule) { build(:virtual_registries_packages_maven_upstream_rule) }

  describe 'associations' do
    it { is_expected.to belong_to(:group).required(true) }

    it 'belongs to a remote upstream' do
      is_expected.to belong_to(:remote_upstream)
        .class_name('VirtualRegistries::Packages::Maven::Upstream').required(true)
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:pattern_type).with_values(wildcard: 0, regex: 1).with_prefix(true) }
    it { is_expected.to define_enum_for(:rule_type).with_values(allow: 0, deny: 1).with_prefix(true) }

    it 'defines a target coordinate enum' do
      is_expected.to define_enum_for(:target_coordinate)
        .with_values(group_id: 0, artifact_id: 1, version: 2)
        .with_prefix(true)
    end

    it_behaves_like 'having unique enum values'
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:pattern) }
    it { is_expected.to validate_length_of(:pattern).is_at_most(255) }

    it 'does not allow duplicate rules' do
      is_expected.to validate_uniqueness_of(:pattern)
        .scoped_to(:remote_upstream_id, :pattern_type, :rule_type, :target_coordinate)
    end

    it { is_expected.to validate_presence_of(:pattern_type) }
    it { is_expected.to validate_presence_of(:rule_type) }
    it { is_expected.to validate_presence_of(:target_coordinate) }

    describe 'top_level_group validation' do
      let(:subgroup) { build(:group, parent: build(:group)) }

      before do
        rule.group = subgroup
      end

      it 'is invalid with a non-top-level group' do
        expect(rule).to be_invalid
        expect(rule.errors[:group]).to include('must be a top level Group')
      end
    end

    describe 'pattern format validation' do
      context 'with wildcard pattern type and group_id target' do
        subject(:rule) { build(:virtual_registries_packages_maven_upstream_rule, :wildcard, :group_id) }

        where(:pattern, :valid) do
          'com.example'      | true
          'org.apache.maven' | true
          '*'                | true
          'com.example.*'    | true
          '*com.example'     | true
          '*com.example*'    | true
          'com/example'      | false
          'org:apache'       | false
          'test[0-9]'        | false
          'com example'      | false
          '**com.example'    | false
          'com.example.**'   | false
        end

        with_them do
          before do
            rule.pattern = pattern
          end

          if params[:valid]
            it { is_expected.to be_valid }
          else
            it 'is invalid with the expected error' do
              is_expected.to be_invalid
              expect(rule.errors).to match_array(
                ['Pattern should be a valid Maven group ID with optional wildcard characters.']
              )
            end
          end
        end
      end

      context 'with wildcard pattern type and artifact_id target' do
        subject(:rule) { build(:virtual_registries_packages_maven_upstream_rule, :wildcard, :artifact_id) }

        where(:pattern, :valid) do
          'my-app'    | true
          'my.app'    | true
          'my_app'    | true
          '*'         | true
          '*-app'     | true
          'my-app.*'  | true
          '*my-app*'  | true
          'my/app'    | false
          'my:app'    | false
          'my app'    | false
          'my[app]'   | false
          '**-app'    | false
          'my-app.**' | false
        end

        with_them do
          before do
            rule.pattern = pattern
          end

          if params[:valid]
            it { is_expected.to be_valid }
          else
            it 'is invalid with the expected error' do
              is_expected.to be_invalid
              expect(rule.errors).to match_array(
                ['Pattern should be a valid Maven artifact ID with optional wildcard characters.']
              )
            end
          end
        end
      end

      context 'with wildcard pattern type and version target' do
        subject(:rule) { build(:virtual_registries_packages_maven_upstream_rule, :wildcard, :version) }

        where(:pattern, :valid) do
          '1.0.0'           | true
          '1.0.0-SNAPSHOT'  | true
          '*-SNAPSHOT'      | true
          '*-beta'          | true
          '*-beta*'         | true
          '1.0.*'           | true
          '*'               | true
          '2.0.0-alpha+001' | true
          '1.*.*'           | true
          '1/0/0'           | false
          '1:0:0'           | false
          '1 0 0'           | false
          '1[0]0'           | false
          '1..0'            | false
          '1.0.**'          | false
          '**-beta'         | false
        end

        with_them do
          before do
            rule.pattern = pattern
          end

          if params[:valid]
            it { is_expected.to be_valid }
          else
            it 'is invalid with the expected error' do
              is_expected.to be_invalid
              expect(rule.errors).to match_array(
                ['Pattern should be a valid Maven version with optional wildcard characters.']
              )
            end
          end
        end
      end

      context 'with regex pattern type' do
        subject(:rule) { build(:virtual_registries_packages_maven_upstream_rule, :regex) }

        where(:pattern, :valid) do
          'com\\.example\\..*'         | true
          '^org\\.apache\\..*$'        | true
          '.*-SNAPSHOT$'               | true
          '^[0-9]+\\.[0-9]+\\.[0-9]+$' | true
          '([a-zA-Z]+[-._]?)+ '        | true
          'com[example'                | false
          'org.apache.*$)'             | false
          '[invalid'                   | false
          '(unclosed'                  | false
          '*invalid'                   | false
        end

        with_them do
          before do
            rule.pattern = pattern
          end

          if params[:valid]
            it { is_expected.to be_valid }
          else
            it 'is invalid with the expected error' do
              is_expected.to be_invalid
              expect(rule.errors).to match_array(/Pattern not valid RE2 syntax/)
            end
          end
        end
      end
    end

    describe 'max rules per upstream validation' do
      let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream) }

      let(:new_rule) do
        build(:virtual_registries_packages_maven_upstream_rule, remote_upstream: upstream)
      end

      before do
        create_list(
          :virtual_registries_packages_maven_upstream_rule,
          described_class::MAX_RULES_PER_UPSTREAM,
          remote_upstream: upstream
        )
      end

      it 'prevents creating more than MAX_RULES_PER_UPSTREAM rules' do
        expect(new_rule).to be_invalid
        expect(new_rule.errors[:base]).to include(
          "Maximum of #{described_class::MAX_RULES_PER_UPSTREAM} rules per upstream has been reached"
        )
      end
    end
  end
end
