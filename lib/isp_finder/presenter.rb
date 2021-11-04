module ISPFinder
  class Presenter
    class Error < StandardError; end

    attr_reader :brand, :fiber_confidence

    def initialize(brand:, fiber_confidence:)
      @brand = brand
      @fiber_confidence = fiber_confidence
    end

    def color
      if fiber_confidence.zero?
        :red
      elsif fiber_confidence >= 1
        :green
      else
        :yellow
      end
    end

    def printable(strings, colors: true)
      ["  #{brand}", *strings.map { |string| Rainbow("   #{string}").send(color) }]
    end
  end
end
