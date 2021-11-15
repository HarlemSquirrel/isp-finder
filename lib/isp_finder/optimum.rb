require_relative 'config'
require_relative 'isp_base'

module ISPFinder
  class Optimum
    include ISPBase

    class Error < StandardError; end

    URLS = {
      bundles: 'https://order.optimum.com/api/bundles',
      localize: 'https://order.optimum.com/api/localize',
      storefront: 'https://order.optimum.com/Buyflow/Storefront'
    }

    @@lock = false

    def initialize(street:, city:, state:, zip:)
      super

      @cookies = []
    end

    def printable
      return presenter.printable(["Error"]) if bundles_data.nil? && @buyflow_error

      return presenter.printable([bundles_data]) if bundles_data.is_a?(String)

      presenter.printable(
        bundles_data['internetOnlyOffers'].to_a.map do |offer|
          "#{offer['name']} $#{offer['price']}#{offer['priceTerm']} #{offer['internetSpeed']}"
        end
      )
    end

    def bundles_data
      # response(URI(URLS[:storefront]))
      # puts "localize_response: #{localize_response}"

      # Since we have to share a single sid and make multiple requests we need to lock
      # when doing parallel requests with async
      return @bundles_data if @bundles_data

      start = Time.now
      while @@lock && start < Time.now + 30
        # puts "#{self.class} waiting..."
        sleep(0.2)
      end
      @@lock = true
      data = Storage.fetch(
        "#{storage_key_base}.bundles_data",
        Proc.new { check_service }
      )
      @@lock = false

      if data == 'No Service'
        return @bundles_data = 'No Service'
      end

      if data == { "redirectUrl" => "/Buyflow/Error" }
        Storage.delete("#{storage_key_base}.bundles_data")
        @buyflow_error = true
        return @bundles_data = nil
      end

      @bundles_data = data
    end

    def fiber_confidence
      return 0 if @buyflow_error || bundles_data.nil?

      bundles_data['internetOnlyOffers'].to_a.any? { |d| d.dig('fiber') } ? 1 : 0
    end

    private

    attr_reader :cookies

    def check_service
      return 'No Service' if localize_response['redirectUrl'] == 'NoService'

      JSON.parse(response(URI(URLS[:bundles])).body)
    end

    def localize_response
      @localize_response ||= JSON.parse(post_response(URI(URLS[:localize]), {
	      # "adobeVisitorId": "",
      	enteredAddress: {
      		city: city.upcase,
      		# "customerInteractionId": "32027986",
          # customerInteractionId: "32065780",
      		state: state.upcase,
      		streetAddress: street,
      		zipCode: zip.to_s
      	},
        # recaptchaPassed: true
        # "experienceCloudVisitorId": "",
        # "recaptchaResponse": "..."
      }).body)
    end

    def post_response(uri, params)
      req = Net::HTTP::Post.new(uri)

      req['Accept'] = 'application/json'
      req['Content-Type'] = 'application/json'
      req['Cookie'] = cookies_string

      req.body = params.to_json

      res = Net::HTTP.start(uri.hostname, uri.port, HTTP_OPTIONS) do |http|
        http.request(req)
      end

      update_cookies(res)
      return res if res.is_a?(Net::HTTPSuccess)

      raise(Error, "#{res.class} #{res.body}")
    end

    def response(uri)
      req = Net::HTTP::Get.new(uri)
      req['Accept'] = 'application/json'
      req['Cookie'] = cookies_string

      opt = {
        open_timeout: 3,
        read_timeout: 5,
        write_timeout: 5,
        use_ssl: true
      }

      res = Net::HTTP.start(uri.hostname, uri.port, **opt) do |http|
        http.request(req)
      end

      update_cookies(res)
      return res if res.is_a?(Net::HTTPSuccess)

      raise(Error, "#{res.class} #{res.body}")
    end

    def cookies_string
      # cookies.join('; ')
      # TODO: We should be able to get a fresh sid by visiting the storefront
      # but right now it seems to be behind a Google recaptcha so we have to visit the
      # storefront URL in a browswer, fill in an address, and then we can get get a new sid.
      "connect.sid=#{Config.optimum['connect_sid']}"
    end

    def cookies_from(response)
      response.get_fields('set-cookie').to_a.map do |c|
        hash = CGI::Cookie.parse(c.split(';').first)
        "#{hash.keys.first}=#{hash.values.flatten.first}"
      end
    end

    def update_cookies(response)
      @cookies = [*cookies, *cookies_from(response)].compact.uniq.sort
      # puts "  Cookies: #{cookies.join("\n           ")}"
    end
  end
end
