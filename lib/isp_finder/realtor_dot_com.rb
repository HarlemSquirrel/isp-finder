require_relative 'config'

module ISPFinder
  class RealtorDotCom
    class Error < StandardError; end

    URLS = {
      signin: 'https://myaccount.realtor.com/signin',
      auth_token: 'https://graph.realtor.com/auth/token'
    }.freeze

    def initialize
      sign_in!
    end

    def saved_properties
      saved_resources.dig('data', 'consumer', 'saved_properties', 'saved_properties')
    end

    def saved_resources
      puts "Getting Realtor.com favorites..."
      JSON.parse response(URI('https://www.realtor.com/api/v1/saved_resources' \
        '?page=1&page_limit=200&exclude_deleted=true&sort_by=created_date&sort_order=desc')).body
    end

    private

    attr_reader :access_token, :cookies, :remember_me, :token_data

    def response(uri)
      req = Net::HTTP::Get.new(uri)
      req['Accept'] = 'application/json'
      req['authorization'] = "Bearer #{token}"
      req['Cookie'] = cookies_string
      req['remember_me'] = remember_me

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(req)
      end

      return res if res.is_a?(Net::HTTPSuccess)

      raise(Error, "#{res.class} #{res.body}")
    end

    def sign_in!
      data = Storage.read('realtor_dot_com.signin_data')
      if data
        @cookies = data['cookies']
        @remember_me = data['remember_me']
        return
      end

      puts "Signing in to Realtor.com..."
      uri = URI(URLS[:signin])
      req = Net::HTTP::Post.new(uri)
      req['Accept'] = 'application/json'
      req['Content-Type'] = 'application/json'
      req.body = {
        email: Config.realtor_dot_com.fetch('username'),
        password: Config.realtor_dot_com.fetch('password'),
        point_of_entry: 'gnav_registration_form',
        regustration_source: 'rdc-web'
      }.to_json

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(req)
      end

      raise(Error, "#{res.class} #{res.body}") unless res.is_a?(Net::HTTPSuccess)

      update_cookies(res)
      @remember_me = res['realtor_cookie'].split('REMEMBER_ME=').last
      Storage.write('realtor_dot_com.signin_data', { 'cookies' => cookies, 'remember_me' => remember_me })
    end

    def token
      return @access_token if @access_token

      data = Storage.read('realtor_dot_com.token_data')
      if data && Time.now < Time.at(data.fetch('expires_at', 1))
        @token_data = data
        return @access_token = data['access_token']
      end

      # Time to get a new token
      puts "Getting Realtor.com token..."
      uri = URI(URLS[:auth_token])
      req = Net::HTTP::Post.new(uri)
      req['Accept'] = 'application/json'
      req.body = {
        grant_type: 'password',
        username: Config.realtor_dot_com.fetch('username'),
        password: Config.realtor_dot_com.fetch('password'),
        point_of_entry: 'gnav_registration_form',
      }.to_json

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(req)
      end

      raise(Error, "#{res.class} #{res.body}") unless res.is_a?(Net::HTTPSuccess)

      parsed_res = JSON.parse(res.body)
      @token_data = parsed_res.merge('expires_at' => Time.now.to_i + parsed_res['expires_in'])
      Storage.write('realtor_dot_com.token_data', token_data)
      @access_token = parsed_res['access_token']
    end

    def cookies_from(response)
      response.get_fields('set-cookie').to_a.map do |c|
        hash = CGI::Cookie.parse(c.split(';').first)
        "#{hash.keys.first}=#{hash.values.flatten.first}"
      end
    end

    def cookies_string
      cookies.join('; ')
    end

    def update_cookies(response)
      @cookies = [*cookies, *cookies_from(response)].compact.uniq.sort
    end
  end
end
