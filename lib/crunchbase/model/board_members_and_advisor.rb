# encoding: utf-8

module Crunchbase::Model
  class BoardMembersAndAdvisor < Crunchbase::Model::Job
    
    RESOURCE_LIST = 'board_members_and_advisors'

    attr_reader :person

    def initialize(json)
      super

      unless (relationships = json['relationships']).nil?
        instance_relationships_object(Crunchbase::Model::Person, 'person', relationships['person'])
      end
    end

    # Factory method to return an instance from a permalink  
    def self.get(permalink)
      nil
    end

  end
end