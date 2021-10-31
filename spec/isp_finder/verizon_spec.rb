# frozen_string_literal: true

RSpec.describe ISPFinder::Verizon do
  describe '#qualification_data' do
    subject(:finder) do
      described_class.new street: '1 Times Square', city: 'New York', state: 'NY', zip: 10_036
    end

    before do
      Timecop.freeze(2021, 10, 31, 6, 6, 6)
    end

    it 'returns the correct data' do
      VCR.use_cassette('verizon/1_times_square') do
        expect(finder.qualification_data).to eq(
          {
            'data' => {
              'addressNotFound' => false,
              'availableFlag' => 'Y',
              'cpnelg' => 'N',
              'fiosReady' => 'N',
              'fiosSelfInstall' => 'N',
              'fiveG' => false,
              'hoaFlag' => 'N',
              'inService' => 'N',
              'isFCP' => true,
              'isLennarEligible' => 'N',
              'mvStopOrder' => false,
              'occupancyType' => '',
              'pendingOrder' => 'N',
              'qualified' => 'Y',
              'qualified4GHome' => false,
              'quantumEligible' => 'Y',
              'services' => [
                { 'qualified' => 'Y', 'servicename' => 'FiOSData' },
                { 'qualified' => 'N', 'servicename' => 'HSI' },
                { 'qualified' => 'Y', 'servicename' => 'Video' },
                { 'qualified' => 'Y', 'servicename' => 'Voice' }
              ],
              'tarCode' => '4002'
            },
            'meta' => {
              'code' => 200.01,
              'description' => 'Qualification  Completed successfully .',
              'timestamp' => 'Mon Nov 01 03:01:40 UTC 2021'
            }
          }
        )
      end
    end
  end
end
