# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::ProjectSecurityExclusionResolver, feature_category: :secret_detection do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project) }
    let_it_be(:active_exclusion) { create(:project_security_exclusion, project: project) }
    let_it_be(:inactive_exclusion) { create(:project_security_exclusion, project: project, active: false) }

    let(:args) { {} }

    subject(:resolver) { resolve(described_class, obj: project, ctx: { current_user: user }, args: args) }

    context 'when the feature is not licensed' do
      it 'raises a resource not available error' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          resolver
        end
      end
    end

    context 'when the feature is licensed' do
      before do
        stub_licensed_features(security_exclusions: true)
      end

      context 'for a role that can read security exclusions' do
        before_all do
          project.add_maintainer(user)
        end

        it 'calls ProjectSecurityExclusionsFinder with correct arguments' do
          finder = instance_double(
            ::Security::ProjectSecurityExclusionsFinder,
            execute: [active_exclusion, inactive_exclusion]
          )

          expect(::Security::ProjectSecurityExclusionsFinder).to receive(:new)
            .with(user, project: project, params: args)
            .and_return(finder)

          resolver
        end

        it 'returns all exclusions when no arguments are provided' do
          expect(resolver).to contain_exactly(active_exclusion, inactive_exclusion)
        end

        context 'when filtering by scanner' do
          let(:args) { { scanner: 'secret_push_protection' } }

          it 'passes the scanner argument to the finder' do
            expect(::Security::ProjectSecurityExclusionsFinder).to receive(:new)
              .with(user, project: project, params: hash_including(scanner: 'secret_push_protection'))
              .and_call_original

            resolver
          end
        end

        context 'when filtering by type' do
          let(:args) { { type: 'raw_value' } }

          it 'passes the type argument to the finder' do
            expect(::Security::ProjectSecurityExclusionsFinder).to receive(:new)
              .with(user, project: project, params: hash_including(type: 'raw_value'))
              .and_call_original

            resolver
          end
        end

        context 'when filtering by active status' do
          let(:args) { { active: true } }

          it 'passes the status argument to the finder' do
            expect(::Security::ProjectSecurityExclusionsFinder).to receive(:new)
              .with(user, project: project, params: hash_including(active: true))
              .and_call_original

            resolver
          end
        end
      end

      context 'for a role that cannot read security exclusions' do
        before_all do
          project.add_reporter(user)
        end

        it 'returns no exclusions' do
          expect(resolver).to be_empty
        end
      end
    end
  end
end
