require_relative 'isp_base'

module ISPFinder
  class Spectrum
    include ISPBase

    URLS = {
      location: 'https://www.spectrum.com/bin/spectrum/residential/location.json/'
    }.freeze

    def fiber_confidence
      0
    end

    def location_data
      @location_data ||= JSON.parse(response(location_uri).body)
    end

    def printable
      presenter.printable([
        "Service Vendor: #{location_data['serviceVendorName']}",
        *location_data.filter_map { |k,v| "#{k}: #{v}" if v == 'true' }
        ])
    end

    private

    def location_uri
      URI("#{URLS[:location]}/#{zip}")
    end

    def response(uri)
      req = Net::HTTP::Get.new(uri)
      req['Accept'] = 'application/json'
      req['User-Agent']= 'Mozilla/5.0 (X11; Linux x86_64; rv:94.0) Gecko/20100101 Firefox/94.0'

      opt = {
        open_timeout: 3,
        read_timeout: 5,
        write_timeout: 5,
        use_ssl: true
      }

      res = Net::HTTP.start(uri.hostname, uri.port, **opt) do |http|
        http.request(req)
      end

      return res if res.is_a?(Net::HTTPSuccess)

      raise(Error, "#{res.class} #{res.body}")
    end
  end
end
