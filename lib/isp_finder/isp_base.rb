require_relative 'storage'

module ISPFinder
  module ISPBase
    HTTP_OPTIONS = {
      open_timeout: 3,
      read_timeout: 10,
      write_timeout: 5,
      use_ssl: true
    }.freeze

    attr_reader :city, :state, :street, :zip

    def initialize(street:, city:, state:, zip:)
      @street = street
      @city = city
      @state = state
      @zip = zip.to_s
    end

    def brand
      self.class.name.split('::').last
    end

    def fiber_confidence
      # Define in parent
    end

    private

    def presenter
      @presenter ||= Presenter.new(brand: brand, fiber_confidence: fiber_confidence)
    end

    def storage_key_base
      [street, city, state, zip, brand].join.downcase.gsub(/\s+/, '')
    end
  end
end
