class ApplicationService
  # Forward positional AND keyword arguments (and a block) to the initializer, so
  # services can take keyword args (e.g. EntityGraphService.new(a, b, helpers:, lang:)).
  def self.call(...)
    new(...).call
  end
end