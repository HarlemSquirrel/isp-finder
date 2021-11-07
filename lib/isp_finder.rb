#!/usr/bin/env ruby

require 'cgi'
require 'json'
require 'logger'
require 'net/http'
require 'securerandom'

require 'nokogiri'
require 'rainbow'

require_relative 'isp_finder/presenter'

require_relative 'isp_finder/frontier'
require_relative 'isp_finder/optimum'
require_relative 'isp_finder/verizon'

module ISPFinder
  class Finder
    class Error < StandardError; end
    class EmptyParamsError < StandardError; end

    attr_reader :city, :state, :street, :zip

    def self.init_keys
      Verizon.init_keys
    end

    def initialize(street:, city:, state:, zip:)
      @city = city
      @state = state
      @street = street
      @zip = zip
      raise(EmptyParamsError, "Missing param(s) in #{address_params}") if address_params.values.any?(&:nil?)
    end

    def best_fiber_confidence
      @best_fiber_confidence ||= [frontier, optimum, verizon].map(&:fiber_confidence).max
    end

    def print_findings
      puts "\n#{street}, #{city}, #{state} #{zip}",
           *frontier.printable,
           *optimum.printable,
           *verizon.printable
    end

    private

    def address_params
      { street: street, city: city, state: state, zip: zip }
    end

    def frontier
      @frontier ||= Frontier.new(**address_params)
    end

    def optimum
      @optimum ||= Optimum.new(**address_params)
    end

    def verizon
      @verizon ||= Verizon.new(**address_params)
    end
  end
end
