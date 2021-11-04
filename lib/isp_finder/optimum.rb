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

    def printable_data
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

    private

    attr_reader :cookies

    def fiber_confidence
      bundles_data['internetOnlyOffers'].to_a.any? { |d| d.dig('fiber') } ? 1 : 0
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
        # "recaptchaResponse": "03AGdBq243AFpu--_XX2EJDwOnnA8k6r7_-MujuP2at0vR7h_ZkTBrfeMH0XpDv8PhFLMX9sreNB0kS8K-CWHfZjnwPJNeF2q_-e58uhq0pbNFDy0zRmipQ-ggBGhzlPzu-6_6ZmF4iX5NjVfdDq7IKLTPU1xtLFKyINCrdmSakhCoo7raomzkLOiGgGD-rYhn6G9ANPZGFlwARSt70c2VA7CRguX-omw_cU9J6CvO5KfcTe3LL3BcALyk7Yhvl3nmVloArA8UEBz2ntcRg0TBUIMYjPJ4Va_L4jvrRnkrBlQrISKC_JhAD0itHhatCiXxEKkNnWU6nabpR-bsGMKjSIBWnQ3cG58Qx5HOw6H6LGtPGitqa27mAzFsc78fmn2PGgs4XNQ-Xwj9QCsT3mJOs8zicqdTHPsffL4i0-SF7TzWooA5qD2hn5vApubIc6_Re8aisGEEnVJzusANFJQyOcSTqMru4UQi1g"
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
      "connect.sid=s:9UEVcPmE5UKbwWfTmeRllNz-62YnatEa.OGuasJzRQ2uDtuhdauzLAQzR2sh9i9j5VuAxX0gJgo0"
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
