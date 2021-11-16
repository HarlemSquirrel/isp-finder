require_relative 'isp_base'

module ISPFinder
  class Frontier
    include ISPBase

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

    def availability_data
      @availability_data ||= Storage.fetch(
        "#{storage_key_base}.availability_data",
        Proc.new do
          JSON.parse post_response(
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
      )
    end

    def fiber?
      availability_data.dig('data', 'runServiceability', 'serviceablePrediction', 'fiber').to_f.positive?
    end

    def print_fiber_availability
      puts printable
    end

    def printable
      presenter.printable [
        "Serviceable? #{availability_data.dig('data', 'runServiceability', 'serviceable')}",
        "Existing service at address? #{availability_data.dig('data', 'runServiceability', 'existingServiceAtAddress')}",
        "Fiber prediction: #{fiber_prediction}",
        *availability_data.dig('data', 'runServiceability', 'products')
                          .to_a
                          .map { |prod| "$#{prod.dig('pricing', 'amount')} #{prod['name']} " \
                                        "#{prod.dig('attributes', 'downloadSpeed')}M ↓ / " \
                                        "#{prod.dig('attributes', 'uploadSpeed')}M ↑ " \
                                        "(Fiber? #{prod.dig('isFib') || (prod['name'].match?(/fiber/i) && 'yes') || 'no'})" }
      ]
    rescue Net::ReadTimeout
      presenter.printable(['Timed out'])
    end

    def fiber_confidence
      fiber_prediction +
        (availability_data.dig('data', 'runServiceability', 'products')
          .count { |prod| prod.dig('isFib') || prod['name'].match?(/fiber/i) } * 0.5)
    rescue Net::ReadTimeout
      0
    end

    def fiber_prediction
      (availability_data.dig('data', 'runServiceability', 'serviceablePrediction', 'fiber') || 0)
    end

    private

    def post_response(uri, params)
      req = Net::HTTP::Post.new(uri)

      req['content-type'] = 'application/json'
      req['x-client-session-id'] = SecureRandom.uuid
      req['x-tenant-id'] = SecureRandom.uuid

      req.body = params.to_json

      res = Net::HTTP.start(uri.hostname, uri.port, HTTP_OPTIONS) do |http|
        http.request(req)
      end
      return res if res.is_a?(Net::HTTPSuccess)

      raise(Error, "#{res.class} #{res.body}")
    end
  end
end
