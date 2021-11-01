#!/usr/bin/env ruby

require 'json'
require 'logger'
require 'net/http'
require 'securerandom'

require 'nokogiri'

module ISPFinder
  class Frontier
    class Error < StandardError; end

    GRAPHQL_URL = 'https://fr-direct-bff.integration-services.redventures.io/graphql'
    GRAPHQL_AVAIL_QUERY = <<~STRING
      mutation RUN_SERVICEABILITY_MUTATION($addressId: String, $address1: String!, $city: String!, $zip: String!, $orderId: String!, $state: String!, $overrideExistingService: Boolean) {
        runServiceability(addressId: $addressId, address1: $address1, zip: $zip, orderId: $orderId, city: $city, state: $state, overrideExistingService: $overrideExistingService) {
          existingCustomer
          serviceable
          existingServiceAtAddress
          markets
          suggestedAddresses {
            addressId
            address1
            address2
            city
            zip
            state
            __typename
          }
          products {
            productId
            name
            includedProducts {
              internet
              video
              voice
              __typename
            }
            pricing {
              name
              category
              paymentMethod
              delay
              duration
              frequency
              quantity
              amount
              amountMajor
              amountMinor
              promotionalAmount
              promotionalAmountMajor
              promotionalAmountMinor
              currency
              currencySymbol
              __typename
            }
            promotions {
              name
              description
              imageUrl
              promoType
              legal
              subtext
              toolTipText
              amount
              startDate
              endDate
              promotionalId
              source
              price
              __typename
            }
            priority
            features
            attributes {
              downloadSpeed
              uploadSpeed
              minChannels
              maxChannels
              __typename
            }
            shortLegal
            legal
            tags
            stateDisclosure
            description
            type
            isVrc
            isFib
            isEero
            isIont
            __typename
          }
          promotions {
            promoType
            name
            description
            imageUrl
            subtext
            toolTipText
            legal
            promoType
            amount
            startDate
            endDate
            promotionalId
            source
            __typename
          }
          disclosures {
            name
            text
            disclosureKey
            disclosureType
            options
            __typename
          }
          serviceablePrediction {
            fiber
            default
            __typename
          }
          segments
          tabKeys
          hasSpecialMessage
          __typename
        }
      }
    STRING

    attr_reader :street, :city, :state, :zip

    def initialize(street:, city:, state:, zip:)
      @street = street
      @city = city
      @state = state
      @zip = zip.to_s
    end

    def availability_data
      @availability_data ||= JSON.parse post_response(
        URI(GRAPHQL_URL),
        operationName: "RUN_SERVICEABILITY_MUTATION",
        query: GRAPHQL_AVAIL_QUERY,
        variables: {
          address1: street,
          city: city,
          state: state,
          zip: zip,
          # TODO: Figure out how to retrieve/generate this order ID.
          orderId: "08d99cec-08dc-18b7-371a-36c139e48826"
        }
      ).body
    end

    def print_fiber_availability
      puts "\n#{street} #{city}, #{state} #{zip}",
           "  Frontier serviceable? #{availability_data.dig('data', 'runServiceability', 'serviceable')}",
           "  Existing service at address? #{availability_data.dig('data', 'runServiceability', 'existingServiceAtAddress')}",
           "  Fiber: #{availability_data.dig('data', 'runServiceability', 'serviceablePrediction', 'fiber')}",
           availability_data.dig('data', 'runServiceability', 'products')
             .map { |prod| "   $#{prod.dig('pricing', 'amount')} #{prod['name']} " \
                           "#{prod.dig('attributes', 'downloadSpeed')}M down / " \
                           "#{prod.dig('attributes', 'uploadSpeed')}M up " \
                           "Fiber? #{prod.dig('isFib') || 'no'}" }
    end

    def self.session_id
      JSON.parse(Net::HTTP.get('https://frontier.com/api/session').body)['sessionId']
    end

    private

    def post_response(uri, params)
      req = Net::HTTP::Post.new(uri)

      req['content-type'] = 'application/json'
      req['x-client-session-id'] = SecureRandom.uuid
      req['x-tenant-id'] = SecureRandom.uuid

      req.body = params.to_json

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(req)
      end
      return res if res.is_a?(Net::HTTPSuccess)

      raise(Error, "#{res.class} #{res.body}")
    end

  end

  class Verizon
    class Error < StandardError; end

    API_BASE_URL = 'https://api.verizon.com'
    API_KEY_URL = 'https://www.verizon.com/5g/home/'
    API_TOKEN_URL = 'https://www.verizon.com/inhome/generatetoken'
    VISIT_IDS_URL = 'https://www.verizon.com/inhome/generatevisitid'

    attr_reader :city, :state, :street, :zip

    def initialize(street:, city:, state:, zip:)
      @city = city
      @state = state
      @street = street
      @zip = zip
    end

    def print_fios_data
      puts "\n#{street} #{city}, #{state}, #{zip}"
      #require 'pry'; binding.pry
      puts qualification_data.dig('meta', 'timestamp')
      puts "  Qualified? #{qualification_data.dig('data', 'qualified')}"
      fios_data = qualification_data.dig('data', 'services')
                                    .find { |service| service['servicename'] == 'FiOSData' }
                                    .dig('qualified')
      puts "  FiOS? #{fios_data}"
      puts "  FiOS Ready? #{qualification_data.dig('data', 'fiosReady')}"
      puts "  FiOS self install? #{qualification_data.dig('data', 'fiosSelfInstall')}"
    end

    def qualification_data
      @qualification_data ||= JSON.parse response(qualification_uri).body
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
      @address_from_typeahead ||= JSON.parse(response(typeahead_uri).body).dig('addresses', 0)
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
