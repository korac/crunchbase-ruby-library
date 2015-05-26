# encoding: utf-8

module Crunchbase::Model
  class PastTeam < Crunchbase::Model::Job
    
    RESOURCE_LIST = 'past_team'

    attr_reader :person

    def initialize(json)
      super

      unless (relationships = json['relationships']).nil?
        set_relationships_object(Crunchbase::Model::Person, 'person', relationships['person'])
      end
    end

    def set_relationships_object(object_name, key, item)
      return unless item

      instance_variable_set "@#{key}", ( object_name.new(item) || nil )
    end

  end
end