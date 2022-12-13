require 'cgi'
require 'ostruct'
require 'json'
require 'open-uri'

class BpidResolver
  require Rails.root + 'lib/resolver/acronym_from_virtual'
  require Rails.root + 'lib/resolver/virtual_from_acronym'
  require Rails.root + 'lib/resolver/virtual_from_version'

  def self.id_to_acronym(id)
    acronym = self.acronym_from_virtual_id(id)
    acronym = self.acronym_from_version_id(id) unless acronym
    acronym
  end

  def self.acronym_to_virtual_id(acronym)
    self.virtual_id_from_acronym(acronym)
  end

  private

  def self.acronym_from_id(id)
    acronym = self.acronym_from_virtual_id(id)
    acronym = self.acronym_from_version_id(id) unless acronym
    acronym
  end

  def self.acronym_from_virtual_id(virtual_id)
    ACRONYM_FROM_VIRTUAL["old:acronym_from_virtual:#{virtual_id}"]
  end

  def self.acronym_from_version_id(version_id)
    virtual = virtual_id_from_version_id(version_id)
    acronym_from_virtual_id(virtual)
  end

  def self.virtual_id_from_version_id(version_id)
    VIRTUAL_FROM_VERSION["old:virtual_from_version:#{version_id}"]
  end

  def self.virtual_id_from_acronym(acronym)
    VIRTUAL_FROM_ACRONYM["old:virtual_from_acronym:#{acronym}"]
  end

end