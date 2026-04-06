# frozen_string_literal: true

# Knapsack decorator — wires AI alt‑text remediation into Hyrax::FileSet
# (the Valkyrie resource class used in flexible/HYRAX_FLEXIBLE=true mode).
# Do NOT reference the old ActiveFedora FileSet here — it pulls in Wings which
# is not loaded in flexible mode and causes Wings::ModelRegistry errors.
Hyrax::FileSet.include AiMetadataBehavior
