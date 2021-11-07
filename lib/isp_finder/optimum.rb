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

    attr_reader :city, :state, :street, :zip

    @@lock = false

    def initialize(street:, city:, state:, zip:)
      @city = city
      @state = state
      @street = street
      @zip = zip

      @cookies = []
    end

    def printable
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
      start = Time.now
      while @@lock && start < Time.now + 30
        # puts "#{self.class} waiting..."
        sleep(0.5)
      end
      @@lock = true
      @bundles_data ||= Storage.fetch(
        "#{storage_key_base}.bundles_data",
        Proc.new { localize_response && JSON.parse(response(URI(URLS[:bundles])).body) }
      )
      @@lock = false
      @bundles_data
    end

    def fiber_confidence
      bundles_data['internetOnlyOffers'].to_a.any? { |d| d.dig('fiber') } ? 1 : 0
    end

    private

    attr_reader :cookies

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

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
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

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
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
