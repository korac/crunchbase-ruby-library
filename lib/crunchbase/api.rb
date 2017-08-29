# encoding: utf-8
# frozen_string_literal: true

require 'net/http'

begin
  require 'yajl'
rescue LoadError
  require 'json'
end

require 'timeout'

module Crunchbase
  class API
    SUPPORTED_ENTITIES = {
      'categories' => Model::Category,
      'organizations' => Model::OrganizationSummary,
      'people' => Model::PersonSummary,
      'products' => Model::ProductSummary,
      'ipos' => Model::Ipo,
      'funding_rounds' => Model::FundingRound,
      'funding-rounds' => Model::FundingRound,
      'acquisitions' => Model::Acquisition,
      'locations' => Model::Location,
      'offices' => Model::Office,
      'customers' => Model::Customer,
      'degrees' => Model::Degree,
      # 'experience' => nil,
      'primary_affiliation' => Model::PrimaryAffiliation,
      'videos' => Model::Video,
      'founded_companies' => Model::FoundedCompany,
      'primary_location' => Model::PrimaryLocation,
      'advisor_at' => Model::AdvisoryRole
    }.freeze

    @timeout_limit  = 60
    @redirect_limit = 2
    @debug = false

    # Must be overridden in subclasses
    RESOURCE_NAME         = 'undefined'
    RESOURCE_LIST         = 'undefineds'

    ORDER_CREATED_AT_ASC  = 'created_at asc'
    ORDER_CREATED_AT_DESC = 'created_at desc'
    ORDER_UPDATED_AT_ASC  = 'updated_at asc'
    ORDER_UPDATED_AT_DESC = 'updated_at desc'

    class << self
      attr_accessor :timeout_limit, :redirect_limit, :key, :debug

      def api_url
        API_BASE_URL.gsub(/\/$/, '') + '/v' + API_VERSION + '/'
      end

      def single_entity(permalink, entity_name)
        raise CrunchException, 'Unsupported Entity Type' unless SUPPORTED_ENTITIES.keys.include?(entity_name)

        fetch(permalink, entity_name)
      end

      # Returns the JSON parser, whether that's an instance of Yajl or JSON
      def parser
        return Yajl::Parser if defined?(Yajl)

        JSON
      end

      # Fetches URI for the permalink interface.
      def fetch(permalink, object_name)
        get_json_response(api_url + "#{object_name}/#{permalink}")
      end

      # Fetches URI for the search interface.
      def search(options, resource_list)
        options[:page] = 1 if options[:page].nil?
        options[:order] = ORDER_CREATED_AT_ASC if options[:order].nil?

        uri = api_url + "#{resource_list}?" + collect_parameters(options)

        get_json_response(uri)
      end

      # Fetches URI for the search interface.
      def list(options, resource_list)
        options[:page]  = 1 if options[:page].nil?
        model_name      = options.delete(:model_name) || SUPPORTED_ENTITIES[resource_list]

        uri = api_url + "#{resource_list}?" + collect_parameters(options)

        Crunchbase::Model::Search.new options, get_json_response(uri), model_name
      end

      def collect_parameters(options)
        require 'cgi'

        options.map { |k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join('&')
      end

      def organization_lists(permalink, category, options)
        lists_for_category('organizations', permalink, category, options)
      end

      # Visit: https://api.crunchbase.com/v/#{version}/people/#{permalink}/#{category}?user_key=key
      def person_lists(permalink, category, options)
        lists_for_category('people', permalink, category, options)
      end

      # Visit: https://api.crunchbase.com/v/#{version}/funding-rounds/#{permalink}/#{category}?user_key=key
      def funding_rounds_lists(permalink, category, options)
        lists_for_category('funding-rounds', permalink, category, options)
      end

      def lists_for_category(classify_name, permalink, category, options)
        options[:page]  = 1 if options[:page].nil?
        options[:order] = ORDER_CREATED_AT_ASC if options[:order].nil?
        model_name      = options.delete(:model_name)

        uri = api_url + "#{classify_name}/#{permalink}/#{category}?#{collect_parameters(options)}"

        Crunchbase::Model::Search.new options, get_json_response(uri), model_name
      end

      # Gets specified URI, then parses the returned JSON. Raises Timeout error
      # if request time exceeds set limit. Raises Crunchbase::Exception if returned
      # JSON contains an error.
      def get_json_response(uri)
        raise Crunchbase::Exception, 'User key required, visit http://data.crunchbase.com' unless @key
        uri += "#{uri =~ /\?/ ? '&' : '?'}user_key=#{@key}"

        resp = Timeout.timeout(@timeout_limit) do
          get_url_following_redirects(uri, @redirect_limit)
        end

        response_data = parser.parse(resp)
        raise Crunchbase::Exception, message: response_data['error'], code: response_data['status'].to_i unless response_data['error'].nil?

        response = response_data['data']
        raise Crunchbase::Exception, response['error'] if response.class == Hash && response['error'] && response['error']['code'] != 500

        response
      end

      # Performs actual HTTP requests, recursively if a redirect response is
      # encountered. Will raise HTTP error if response is not 200, 404, or 3xx.
      def get_url_following_redirects(uri_str, limit = 10)
        raise Crunchbase::Exception, 'HTTP redirect too deep' if limit.zero?

        uri = URI.parse(URI.encode(uri_str))

        debug_log!(uri) if debug

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if uri.scheme == 'https'
        response = http.start do |h|
          h.request Net::HTTP::Get.new(uri.request_uri)
        end

        case response
        when Net::HTTPSuccess, Net::HTTPNotFound, Net::HTTPInternalServerError
          response.body
        when Net::HTTPRedirection
          get_url_following_redirects(response['location'], limit - 1)
        else
          response.error!
        end
      end

      def debug_log!(uri)
        puts '*' * 120
        puts "***  #{uri}  ***"
        puts '*' * 120
      end
    end
  end
end
