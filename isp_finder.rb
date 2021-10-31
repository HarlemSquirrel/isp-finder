#!/usr/bin/env ruby

require 'json'
require 'logger'
require 'net/http'
require 'securerandom'

require 'nokogiri'

module ISPFinder
  class Verizon
    class Error < StandardError; end

    API_BASE_URL = 'https://api.verizon.com'

    attr_reader :city, :state, :street, :zip

    def initialize(street:, city:, state:, zip:)
      @city = city
      @state = state
      @street = street
      @zip = zip
    end

    def print_fios_data
      puts "\n#{street} #{city}, #{state}, #{zip}"
      puts qualification_data.dig('meta', 'timestamp')
      puts "  Qualified? #{qualification_data.dig('data', 'qualified')}"
      fios_data = qualification_data.dig('data', 'services')
                                    .find { |service| service['servicename'] == 'FiOSData' }['qualified']
      puts "  FiOS? #{fios_data}"
      puts "  FiOS Ready? #{qualification_data.dig('data', 'fiosReady')}"
      puts "  FiOS self install? #{qualification_data.dig('data', 'fiosSelfInstall')}"
    end

    def qualification_data
      @qualification_data ||= JSON.parse response(qualification_uri).body
    end

    def self.api_key
      @api_key ||= Nokogiri::HTML(Net::HTTP.get_response(URI('https://www.verizon.com/5g/home/')).body)
                     .search('#locusApiKey').first[:value]

    end

    def self.api_token
      @api_token ||= JSON.parse(Net::HTTP.get_response(URI("https://www.verizon.com/inhome/generatetoken?timestamp=#{Time.now.to_i * 1000}")).body)['access_token']
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
      address_from_typeahead['ntasAddrID']
    end

    def response(uri)
      req = Net::HTTP::Get.new(uri)
      req['apikey'] = api_key
      req['Accept'] = 'application/json'
      req['Authorization'] = "Bearer #{self.class.api_token}"

      # TODO: Figure out how to generate or retrieve visitor_id and visit_id
      # NESwyWuaJAA6zXyrok27STgroEw3V9yb9VAsBIm0ffk88FoQYefVt5LPHj871iuKlTV
      # NESwyWuaJAA6zXyrok27STgroEw3V9yb9VAsBIm0ffk88%2FoQYefVt5LPHj871iuKlTV
      # NES36tjUW03cBj4l50aksYRDw4Kq86%2B5fZCNtAOYfZXa8UukRX%2BKfbQ7kqTj5QTPdel
      # req['Cookie'] = "visitor_id=NES#{SecureRandom.alphanumeric(64)}; visit_id=#{SecureRandom.alphanumeric(26).downcase}; "
      req['Cookie'] = 'visitor_id=NES36tjUW03cBj4l50aksYRDw4Kq86%2B5fZCNtAOYfZXa8UukRX%2BKfbQ7kqTj5QTPdel; visit_id=2u4mkn2grrdglb03tapihmueb6; '
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


ISPFinder::Verizon.new(street: '16 hemlock hollow rd', city: 'ARMONK', state: 'NY', zip: '10504').print_fios_data
ISPFinder::Verizon.new(street: '240 Spring St', city: 'South Salem', state: 'NY', zip: '10590').print_fios_data
