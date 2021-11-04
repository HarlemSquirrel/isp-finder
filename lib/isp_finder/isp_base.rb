require_relative 'storage'

module ISPFinder
  module ISPBase
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
