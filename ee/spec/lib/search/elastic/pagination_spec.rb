# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Pagination, feature_category: :global_search do
  include_context 'with filters shared context'

  let(:paginator) { described_class.new(query_hash) }

  before do
    query_hash[:sort] = { created_at: :asc }
  end

  describe 'without before and after' do
    describe '#first' do
      subject(:first_10_records_query) { paginator.first(10) }

      it 'generates the query without keyset pagination filters' do
        expect(first_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: []
            }
          },
          sort: [
            { created_at: :asc },
            { id: :asc }
          ],
          size: 10
        })
      end
    end

    describe '#last' do
      subject(:last_10_records_query) { paginator.last(10) }

      it 'generates the query without keyset pagination filters' do
        expect(last_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: []
            }
          },
          sort: [
            { created_at: :desc },
            { id: :desc }
          ],
          size: 10
        })
      end
    end
  end

  describe '#before' do
    before do
      paginator.before('2025-01-01', 1)
    end

    describe '#first' do
      subject(:first_10_records_query) { paginator.first(10) }

      it 'generates the query' do
        expect(first_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: [
                {
                  bool: {
                    should: [
                      {
                        range: {
                          created_at: { lt: '2025-01-01' }
                        }
                      },
                      {
                        bool: {
                          must: [
                            {
                              term: {
                                created_at: '2025-01-01'
                              }
                            },
                            {
                              range: {
                                id: { lt: 1 }
                              }
                            }
                          ]
                        }
                      }
                    ]
                  }
                }
              ]
            }
          },
          sort: [
            { created_at: :asc },
            { id: :asc }
          ],
          size: 10
        })
      end
    end

    describe '#last' do
      subject(:last_10_records_query) { paginator.last(10) }

      it 'generates the query' do
        expect(last_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: [
                {
                  bool: {
                    should: [
                      {
                        range: {
                          created_at: { lt: '2025-01-01' }
                        }
                      },
                      {
                        bool: {
                          must: [
                            {
                              term: {
                                created_at: '2025-01-01'
                              }
                            },
                            {
                              range: {
                                id: { lt: 1 }
                              }
                            }
                          ]
                        }
                      }
                    ]
                  }
                }
              ]
            }
          },
          sort: [
            { created_at: :desc },
            { id: :desc }
          ],
          size: 10
        })
      end
    end
  end

  describe '#after' do
    before do
      paginator.after('2025-01-01', 1)
    end

    describe '#first' do
      subject(:first_10_records_query) { paginator.first(10) }

      it 'generates the query' do
        expect(first_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: [
                {
                  bool: {
                    should: [
                      {
                        range: {
                          created_at: { gt: '2025-01-01' }
                        }
                      },
                      {
                        bool: {
                          must: [
                            {
                              term: {
                                created_at: '2025-01-01'
                              }
                            },
                            {
                              range: {
                                id: { gt: 1 }
                              }
                            }
                          ]
                        }
                      }
                    ]
                  }
                }
              ]
            }
          },
          sort: [
            { created_at: :asc },
            { id: :asc }
          ],
          size: 10
        })
      end
    end

    describe '#last' do
      subject(:last_10_records_query) { paginator.last(10) }

      it 'generates the query' do
        expect(last_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: [
                {
                  bool: {
                    should: [
                      {
                        range: {
                          created_at: { gt: '2025-01-01' }
                        }
                      },
                      {
                        bool: {
                          must: [
                            {
                              term: {
                                created_at: '2025-01-01'
                              }
                            },
                            {
                              range: {
                                id: { gt: 1 }
                              }
                            }
                          ]
                        }
                      }
                    ]
                  }
                }
              ]
            }
          },
          sort: [
            { created_at: :desc },
            { id: :desc }
          ],
          size: 10
        })
      end
    end
  end

  describe 'providing a different tie-breaker property' do
    let(:paginator) { described_class.new(query_hash, :vulnerability_id) }

    subject(:first_10_records_query) { paginator.after('2025-01-01', 1).first(10) }

    it 'generates the query based on given tie-breaker property' do
      expect(first_10_records_query).to eq({
        query: {
          bool: {
            should: [],
            must_not: [],
            must: [],
            filter: [
              {
                bool: {
                  should: [
                    {
                      range: {
                        created_at: { gt: '2025-01-01' }
                      }
                    },
                    {
                      bool: {
                        must: [
                          {
                            term: {
                              created_at: '2025-01-01'
                            }
                          },
                          {
                            range: {
                              vulnerability_id: { gt: 1 }
                            }
                          }
                        ]
                      }
                    }
                  ]
                }
              }
            ]
          }
        },
        sort: [
          { created_at: :asc },
          { vulnerability_id: :asc }
        ],
        size: 10
      })
    end
  end
end
