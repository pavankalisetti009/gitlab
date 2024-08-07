# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Observability::MetricsIssuesHelper, feature_category: :metrics do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { build_stubbed(:project) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need a project with a repository
  let_it_be(:developer) { build_stubbed(:user) }

  let(:user) { developer }

  before_all do
    project.add_developer(developer)
  end

  describe '#observability_issue_params' do
    let(:params) { {} }

    subject(:service) do
      ::Issues::BuildService.new(container: project, current_user: user, params: params).observability_issue_params
    end

    context 'when feature flag or licence flag is disabled' do
      where(:feature_flag_enabled, :licence_flag_enabled) do
        true  | false
        false | true
        false | false
      end

      with_them do
        before do
          stub_feature_flags(observability_features: licence_flag_enabled)
          stub_licensed_features(observability: feature_flag_enabled)
        end

        it { is_expected.to eq({}) }
      end
    end

    context 'when feature flag and licence flag are enabled' do
      before do
        stub_feature_flags(observability_features: true)
        stub_licensed_features(observability: true)
      end

      context 'when observabiilty_links params are empty' do
        it { is_expected.to eq({}) }
      end

      context 'when observability_links params are invalid' do
        let(:params) { { observability_links: 'this is not valid at all' } }

        it { is_expected.to eq({}) }
      end

      context 'when observability_links params are valid', :aggregate_failures do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :read_observability, project).and_return(true)
        end

        # rubocop:disable Layout/LineLength -- urls with params will be too long
        let(:params) do
          { observability_links: CGI.escape(
            %({"fullUrl":"http://gdk.test:3000/gitlab-org/gitlab-test/-/metrics/app.ads.ad_requests?type=Sum&date_range=1h&group_by_fn=sum&group_by_attrs[]=app.ads.ad_request_type&group_by_attrs[]=app.ads.ad_response_type", "name": "app.ads.ad_requests", "type": "Sum", "timeframe":["2024-07-2504:47:00UTC","2024-07-2505:47:00UTC"]})
          ) }
        end
        # rubocop:enable Layout/LineLength

        it 'has the correct output' do
          expect(service[:description]).to include("Name: `app.ads.ad_requests`")
          expect(service[:description]).to include("Type: `Sum`")
          expect(service[:description]).to include("Timeframe: `2024-07-2504:47:00UTC - 2024-07-2505:47:00UTC`")
          expect(service[:title]).to eq("Issue created from app.ads.ad_requests")
        end
      end

      context 'when observability_links params are invalid JSON' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :read_observability, project).and_return(true)
        end

        # rubocop:disable Layout/LineLength -- urls with params will be too long
        let(:params) do
          { observability_links: "thisisnotjson" }
        end
        # rubocop:enable Layout/LineLength

        it { is_expected.to eq({}) }
      end
    end
  end
end
