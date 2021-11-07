require_relative 'config'

module ISPFinder
  class RealtorDotCom
    class Error < StandardError; end

    # def initialize
    #
    # end

    def saved_properties
      saved_resources.dig('data', 'consumer', 'saved_properties', 'saved_properties')
    end

    def saved_resources
      JSON.parse response(URI('https://www.realtor.com/api/v1/saved_resources' \
        '?page=1&page_limit=200&exclude_deleted=true&sort_by=created_date&sort_order=desc')).body
    end

    private

    def headers
      Config.realtor_dot_com.fetch('headers')
    end

    def response(uri)
      req = Net::HTTP::Get.new(uri)
      req['Accept'] = 'application/json'
      req['authorization'] = headers['authorization']
      req['Cookie'] = headers['cookie']
      req['remember_me'] = headers['remember_me']

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(req)
      end

      # update_cookies(res)
      return res if res.is_a?(Net::HTTPSuccess)

      raise(Error, "#{res.class} #{res.body}")
    end
  end
end
