require_relative 'storage'

module ISPFinder
  class Verizon
    include ISPBase

    class Error < StandardError; end

    API_BASE_URL = 'https://api.verizon.com'
    API_KEY_URL = 'https://www.verizon.com/5g/home/'
    API_TOKEN_URL = 'https://www.verizon.com/inhome/generatetoken'
    VISIT_IDS_URL = 'https://www.verizon.com/inhome/generatevisitid'

    def fios_qualified?
      fios_data.dig('qualified') == 'Y'
    end

    def fios_ready?
      qualification_data.dig('data', 'fiosReady') == 'Y'
    end

    def fios_self_install?
      qualification_data.dig('data', 'fiosSelfInstall') == 'Y'
    end

    def printable
      return presenter.printable(["Address not found"]) if address_from_typeahead.nil?

      presenter.printable [
        # qualification_data.dig('meta', 'timestamp'),
        "Qualified? #{qualification_data.dig('data', 'qualified')}",
        "FiOS? #{fios_data.dig('qualified')}",
        "FiOS Ready? #{qualification_data.dig('data', 'fiosReady')}",
        "FiOS self install? #{qualification_data.dig('data', 'fiosSelfInstall')}"
      ]
    end

    def fios_data
      qualification_data.dig('data', 'services')
                        .find { |service| service['servicename'] == 'FiOSData' }

    end

    def qualified?
      qualification_data.dig('data', 'qualified') == 'Y'
    end

    def qualification_data
      @qualification_data ||= Storage.fetch(
        "#{storage_key_base}.qualification_data",
        Proc.new { JSON.parse(response(qualification_uri).body) }
      )
    end

    def fiber_confidence
      return 0 if address_from_typeahead.nil?

      (qualified? ? 0.5 : 0) +
        (fios_qualified? ? 0.5 : 0) +
        (fios_ready? ? 0.5 : 0) +
        (fios_self_install? ? 0.5 : 0)
    end

    ##
    # Get the tokens and keys we need for all checks
    #
    def self.init_keys
      # TODO: Store these for an hour or more in pstore
      api_key
      api_token
      home_page
    end

    def self.api_key
      @api_key ||= home_page.search('#locusApiKey').first[:value]
    end

    def self.api_token
      @api_token ||= JSON.parse(
        Net::HTTP.get_response(URI("#{API_TOKEN_URL}?timestamp=#{Time.now.to_i * 1000}")).body)
          .dig('access_token')
    end

    def self.home_page
      @home_page ||= Nokogiri::HTML(Net::HTTP.get_response(URI(API_KEY_URL)).body)
    end

    def self.response_with_auth(uri)
      req = Net::HTTP::Get.new(uri)
      req['apikey'] = api_key
      req['Accept'] = 'application/json'
      req['Authorization'] = "Bearer #{api_token}"
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(req)
      end
      return res if res.is_a?(Net::HTTPSuccess)

      raise(Error, "#{res.class} #{res.body}")
    end

    def self.visit_ids_data
      @visit_ids_data ||= JSON.parse(response_with_auth(URI(VISIT_IDS_URL)).body)
    end

    private

    def api_key
      self.class.api_key
    end


    def presenter
      @presenter ||= Presenter.new(brand: self.class.name.split('::').last,
                                   fiber_confidence: fiber_confidence)
    end

    def logger
      @logger ||= Logger.new(STDOUT)
    end

    def qualification_params
      { addressID: address_id, city: address_from_typeahead['city'], state: state, zip: zip, isRememberMe: 'N', oneLQ: 'Y' }
    end

    def qualification_uri
      URI("#{API_BASE_URL}/atomapi/v1/addressqualification/address/qualification").tap do |uri|
        uri.query = URI.encode_www_form(qualification_params)
      end
    end

    ##
    # Load the results from the typeahead endpoint from which we can get the address ID.
    #
    # Right now we assume the first result is what we want.
    #
    def address_from_typeahead
      @address_from_typeahead ||= Storage.fetch(
        "#{storage_key_base}.address_from_typeahead",
        Proc.new { JSON.parse(response(typeahead_uri).body).dig('addresses', 0) }
      )
    end

    def address_id
      address_from_typeahead['ntasAddrID'] || address_from_typeahead['locusID']
    end

    def response(uri)
      req = Net::HTTP::Get.new(uri)
      req['apikey'] = api_key
      req['Accept'] = 'application/json'
      req['Authorization'] = "Bearer #{self.class.api_token}"
      req['Cookie'] = "visitor_id=#{self.class.visit_ids_data['visitor_id']}; " \
                      "visit_id=#{self.class.visit_ids_data['visit_id']};"

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(req)
      end
      return res if res.is_a?(Net::HTTPSuccess)

      raise(Error, "#{res.class} #{res.body}")
    end

    def typeahead_params
      { streetterm: "#{street} #{city} #{state} #{zip}", sortByState: state }
    end

    def typeahead_uri
      @typeahead_uri ||= URI("#{API_BASE_URL}/locus-typeahead/address/typeahead-address").tap do |uri|
        uri.query = URI.encode_www_form(typeahead_params)
      end
    end
  end
end
