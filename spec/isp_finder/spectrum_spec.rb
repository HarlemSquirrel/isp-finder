# frozen_string_literal: true

RSpec.describe ISPFinder::Spectrum do
  describe '#location_data' do
    subject(:finder) do
      described_class.new street: '2300 SOUTHERN BOULEVARD', city: 'NEW YORK', state: 'NY', zip: '10460'
    end

    it 'returns the correct data' do
      VCR.use_cassette('spectrum/1_times_square') do
        expect(finder.location_data).to include(
          'city' => 'Bronx',
          'state' => 'NY',
          'zipcode' => '10460',
          'isNYCOutOfFootprint' => 'true',
          'serviceVendorName' => 'none'
        )
      end
    end
  end
end
