# frozen_string_literal: true

RSpec.describe ISPFinder::Optimum do
  describe '#bundles_data' do
    subject(:finder) do
      # described_class.new street: '2300 Southern Blvd', city: 'Bronx', state: 'NY', zip: '10460'
      described_class.new street: '2300 SOUTHERN BOULEVARD', city: 'NEW YORK', state: 'NY', zip: '10460'
    end

    before do
      Timecop.freeze(2021, 10, 31, 6, 6, 6)
    end

    it 'returns the correct data' do
      VCR.use_cassette('optimum/1_times_square') do
        expect(finder.bundles_data.keys).to include(
          "availableLinesOfBusiness",
          "internetOnlyOffers"
        )
      end
    end
  end
end
