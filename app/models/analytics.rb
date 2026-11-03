class Analytics < ApplicationRecord
  # Preserve the YAML format used by existing analytics records.
  serialize :params, coder: YAML
end
