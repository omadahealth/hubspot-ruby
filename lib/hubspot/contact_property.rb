require 'hubspot/utils'
require 'httparty'

module Hubspot
  #
  # HubSpot Contact Properties API
  #
  # {http://developers.hubspot.com/docs/methods/contacts/get_properties}
  #
  class ContactProperty
    PROPERTIES_PATH = "/contacts/v1/properties"
    PROPERTY_PATH   = "/contacts/v1/properties/:name"

    # Class Methods
    class << self
      # Get all properties
      # {http://developers.hubspot.com/docs/methods/contacts/get_properties}
      # @return [Hubspot::ContactPropertyCollection] the paginated collection of
      # contact properties
      def all(opts = {})
        url = Hubspot::Utils.generate_url(PROPERTIES_PATH, opts)
        request = HTTParty.get(url, format: :json)

        raise(Hubspot::RequestError.new(request)) unless request.success?

        found = request.parsed_response
        return found.map{|h| new(h) }
      end

      # Creates a new Contact Property
      # {http://developers.hubspot.com/docs/methods/contacts/create_property}
      # @return [Hubspot::ContactProperty] the created property
      # @raise [Hubspot::ContactPropertyExistsError] if a property already exists with the given name
      # @raise [Hubspot::RequestError] if the creation fails
      def create!(name, params = {})
        # Merge the name with the rest of the params
        params_with_name = params.stringify_keys.merge("name" => name)
        # Merge in sensible defaults so we don't have to specify everything
        params_with_name.reverse_merge! default_creation_params
        # Transform keys to Hubspot's silly camelcase format
        params_with_name = params_with_name.map { |k,v| [k.camelize(:lower), v] }.to_h
        url = Hubspot::Utils.generate_url(PROPERTY_PATH, {name: name})
        resp = HTTParty.put(url, body: params_with_name.to_json, format: :json,
          headers: {"Content-Type" => "application/json"})
        raise(Hubspot::ContactPropertyExistsError.new(resp, "Contact Property already exists with name: #{name}")) if resp.code == 409
        raise(Hubspot::RequestError.new(resp, "Cannot create contact property with name: #{name}")) unless resp.success?
        new(resp.parsed_response)
      end

      protected

      def default_creation_params
        {
          "description"   => "",
          "group_name"    => "contactinformation",
          "type"          => "string",
          "field_type"    => "text",
        }
      end
    end

    attr_accessor :name, :description, :group_name, :type, :field_type,
      :form_field, :display_order, :options

    def initialize(hash)
      # Transform the hash keys into ruby friendly names
      hash = hash.map { |k,v| [k.underscore, v] }.to_h
      # Assign anything we have an accessor for with the same name
      hash.each do |key, value|
        self.send(:"#{key}=", value) if self.respond_to?(:"#{key}=")
      end
    end

    # Archives the contact property in hubspot
    # {http://developers.hubspot.com/docs/methods/contacts/delete_property}
    # @return [TrueClass] true
    def destroy!
      url = Hubspot::Utils.generate_url(PROPERTY_PATH, {name: name})
      resp = HTTParty.delete(url, format: :json)
      raise(Hubspot::RequestError.new(resp)) unless resp.success?
      @destroyed = true
    end

    def destroyed?
      !!@destroyed
    end

  end
end
