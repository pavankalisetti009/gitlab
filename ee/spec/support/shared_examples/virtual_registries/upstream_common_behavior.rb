# frozen_string_literal: true

RSpec.shared_examples 'virtual registry upstream common behavior' do
  using RSpec::Parameterized::TableSyntax

  describe 'validations', :aggregate_failures do
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_length_of(:url).is_at_most(255) }
    it { is_expected.to validate_numericality_of(:cache_validity_hours).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(1024) }

    context 'for url' do
      where(:url, :valid, :error_messages) do
        'http://test.maven'   | true  | nil
        'https://test.maven'  | true  | nil
        'git://test.maven'    | false | ['Url is blocked: Only allowed schemes are http, https']
        nil                   | false | ["Url can't be blank", 'Url must be a valid URL']
        ''                    | false | ["Url can't be blank", 'Url must be a valid URL']
        "http://#{'a' * 255}" | false | 'Url is too long (maximum is 255 characters)'
        'http://127.0.0.1'    | false | 'Url is blocked: Requests to localhost are not allowed'
        'maven.local'         | false | 'Url is blocked: Only allowed schemes are http, https'
        'http://192.168.1.2'  | false | 'Url is blocked: Requests to the local network are not allowed'
        'http://foobar.x'     | false | 'Url is blocked: Host cannot be resolved or invalid'
      end

      with_them do
        before do
          upstream.url = url
        end

        if params[:valid]
          it { is_expected.to be_valid }
        else
          it { is_expected.to be_invalid.and have_attributes(errors: match_array(Array.wrap(error_messages))) }
        end
      end
    end
  end

  describe '#url_for' do
    subject { upstream.url_for(path) }

    where(:path, :expected_url) do
      'path'      | 'http://test.maven/path'
      ''          | 'http://test.maven/'
      '/path'     | 'http://test.maven/path'
      '/sub/path' | 'http://test.maven/sub/path'
    end

    with_them do
      before do
        upstream.url = 'http://test.maven/'
      end

      it { is_expected.to eq(expected_url) }
    end
  end
end
