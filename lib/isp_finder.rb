#!/usr/bin/env ruby

require 'json'
require 'logger'
require 'net/http'
require 'securerandom'

require 'nokogiri'
require 'rainbow'

require_relative 'isp_finder/frontier'
require_relative 'isp_finder/verizon'

module ISPFinder
  class Finder
    class Error < StandardError; end
    class EmptyParamsError < StandardError; end

    attr_reader :city, :state, :street, :zip

    def self.init_keys
      Frontier.init_keys
      # Verizon.init_keys
    end

    def initialize(street:, city:, state:, zip:)
      @city = city
      @state = state
      @street = street
      @zip = zip
      raise(EmptyParamsError, "Missing param(s) in #{address_params}") if address_params.values.any?(&:nil?)
    end

    def print_findings
      puts "\n#{street} #{city}, #{state}, #{zip}",
           *Frontier.new(**address_params).printable_fiber_availability,
           *Verizon.new(**address_params).printable_fios_data
    end

    private

    def address_params
      { street: street, city: city, state: state, zip: zip }
    end
  end
end
