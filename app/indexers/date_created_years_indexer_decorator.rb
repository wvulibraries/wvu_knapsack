# Populates date_created_years_ssim for every resource type that has a
# date_created property, by exploding it into every year it covers.
# Backs the "Date Created" range facet (catalog_controller_decorator.rb).
#
# Prepended onto Hyrax::Indexers::ResourceIndexer -- the shared ancestor
# of every indexer -- so new work types get this automatically. FileSets/
# AdminSets have no date_created, so this is a harmless no-op for them.
# date_created is expected to be real EDTF (loc.gov/standards/datetime)
# Non-EDTF values (e.g. "1940-1950", which should be "1940/1950") are not
# special-cased -- they land in the facet's "[Missing]" bucket on purpose;
# fix those at the metadata source, not here.
#
# One exception: some Collections write set sub-ranges with '/' instead
# of EDTF's '..' (e.g. "{1980/1994}" vs "{1980..1994}"). Kept as a
# fallback for now since it's live data -- remove once that data's fixed.
require 'edtf'

module DateCreatedYearsIndexerDecorator
  def to_solr
    super.tap do |solr_doc|
      solr_doc['date_created_years_ssim'] = date_created_years
    end
  end

  private

  def date_created_years
    Array(resource.try(:date_created)).flat_map { |raw| years_for(raw) }.uniq.sort
  end

  def years_for(raw)
    raw = raw.to_s.strip
    return [] if raw.empty?

    parsed = EDTF.parse(raw)
    # EDTF_SET_SLASH_FALLBACK -- see module comment above.
    parsed ||= (EDTF.parse(raw.gsub('/', '..')) if raw.start_with?('{'))
    return [] if parsed.nil?

    years_from(parsed)
  end

  # Most parsed values yield years straight from #year/#map(&:year). The
  # exception: an open/unknown-ended interval (e.g. "1978-03-07/open") is
  # valid EDTF, but the edtf gem's Interval#each yields nothing when the
  # end is open/unknown (no max to iterate to). Fall back to whichever
  # bound is an actual date.
  def years_from(parsed)
    years = parsed.respond_to?(:each) ? parsed.map(&:year) : [parsed.year]
    return years unless years.empty?

    bound = [parsed.try(:from), parsed.try(:to)].find { |d| d.is_a?(Date) }
    bound ? [bound.year] : []
  end
end

Hyrax::Indexers::ResourceIndexer.prepend(DateCreatedYearsIndexerDecorator)
