# frozen_string_literal: true

# Knapsack decorator — wires AI alt‑text remediation into Hyrax::FileSet
# (the Valkyrie resource class used in flexible/HYRAX_FLEXIBLE=true mode).
# Do NOT reference the old ActiveFedora FileSet here — it pulls in Wings which
# is not loaded in flexible mode and causes Wings::ModelRegistry errors.
Hyrax::FileSet.include AiMetadataBehavior

# Declare alt_text as a native Valkyrie attribute to override the m3 profile definition.
# This ensures alt_text is treated as a native attribute rather than flexible metadata,
# preventing performance issues from schema conflicts.
Hyrax::FileSet.attribute :alt_text, Valkyrie::Types::Array.of(Valkyrie::Types::String)
