require_relative 'isp_base'

module ISPFinder
  class Att
    include ISPBase

    class Error < StandardError; end

    URLS = {
      base_offers: 'https://www.att.com/msapi/onlinesalesorchestration/att-wireline-sales-eapi/v1/baseoffers'
    }.freeze

    def printable
      presenter.printable([
        "Fiber available? #{fiber_available? ? 'yes' : 'no'}",
        "DSL available? #{dsl_available? ? 'yes' : 'no'}",
        "Best available: #{best_available_display_text}"
        ])
    end

    def fiber_confidence
      fiber_available? ? 1 : 0
    end

    private

    def availability_status
      base_offers.dig('content', 'serviceAvailability', 'availabilityStatus')
    end

    def base_offers
      @base_offers ||= Storage.fetch(
        "#{storage_key_base}.base_offers",
        Proc.new { JSON.parse(post_response(URI(URLS[:base_offers]), base_offers_args).body) }
      )
    end

    def base_offers_args
      { addressLine1: street, zip: zip, customerType: :consumer, lobs: [:broadband], mode: :fullAddress }
    end

    def best_available_display_text
      base_offers.dig('content', 'serviceAvailability', 'availableServices', 'maxInternetDisplayText')
    end

    def dsl_available?
      base_offers.dig('content', 'serviceAvailability', 'availableServices', 'dslAvailable')
    end

    def fiber_available?
      base_offers.dig('content', 'serviceAvailability', 'availableServices', 'fiberAvailable')
    end

    def post_response(uri, params)
      req = Net::HTTP::Post.new(uri)

      req['content-type'] = 'application/json'

      req.body = params.to_json

      res = Net::HTTP.start(uri.hostname, uri.port, HTTP_OPTIONS) do |http|
        http.request(req)
      end
      return res if res.is_a?(Net::HTTPSuccess)

      raise(Error, "#{res.class} #{res.body}")
    end
  end
end
