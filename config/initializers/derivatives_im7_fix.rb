# frozen_string_literal: true

# Fix: ValkyrieCreateDerivativesJob fails with MiniMagick::Error on all image ingest.
#
# Root cause (MiniMagick 4.x + ImageMagick 7 + hydra-derivatives 4.x):
#
#   hyrax-webapp's FileSetDerivativesServiceDecorator#create_image_derivatives
#   passes `layer: 0` unconditionally "for pyramidal tiffs".  hydra-derivatives'
#   Processors::Image#selected_layers checks the directive:
#
#     elsif directives.fetch(:layer, false)   # Ruby: integer 0 is TRUTHY
#       image.layers[directives.fetch(:layer)]
#
#   image.layers[0] calls MiniMagick::Image.new(path + "[0]"), which has
#   @tempfile = nil (Image.new never allocates a Tempfile).
#
#   Image#format("jpg") with @tempfile = nil computes:
#     new_path = Pathname(path).sub_ext(".jpg")
#   For path "/tmp/mini_magick...jpg[0]", Pathname#sub_ext strips the "[0]"
#   extension and returns "/tmp/mini_magick...jpg" — the same on-disk path.
#
#   IM7 then runs:
#     magick convert /tmp/mini_magick...jpg[0] /tmp/mini_magick...jpg
#   Writing to the destination truncates the source file before reading → IM7
#   reports "No such file or directory".
#
# Fix:
#   Prepend a module that overrides create_image_derivatives to omit `layer: 0`
#   for JPEG and other single-layer formats.  Only TIFF and PDF sources actually
#   need layer selection; passing it for plain images triggers the bug above.
#
# Side effect on UV (Universal Viewer):
#   Because no thumbnail derivative was written, the IIIF manifest had nothing
#   to serve and UV showed broken/empty images for affected records.  After this
#   fix, new ingest will succeed.  Re-run derivatives on existing broken records:
#
#     FileSet.find("FILESET_ID").tap do |fs|
#       ValkyrieCreateDerivativesJob.perform_later(fs.id.to_s)
#     end
#
#   Or from the console for all FileSets on a work:
#
#     Work.find("WORK_ID").file_sets.each do |fs|
#       ValkyrieCreateDerivativesJob.perform_later(fs.id.to_s)
#     end

Rails.application.config.after_initialize do
  im7_image_patch = Module.new do
    # @param filename [String] source file path passed by the derivatives pipeline
    def create_image_derivatives(filename)
      mime =
        begin
          Array(file_set.mime_type).first.to_s
        rescue StandardError
          ''
        end
      ext = File.extname(filename.to_s).downcase

      # Only multi-layer formats need the layer: 0 directive.
      # Passing it for JPEG/PNG/etc. causes MiniMagick 4.x + IM7 to fail
      # (see comment at top of file).
      needs_layer = mime.include?('tiff') || mime.include?('pdf') ||
                    ['.tiff', '.tif', '.pdf'].include?(ext)

      outputs = [{
        label: :thumbnail,
        format: 'jpg',
        size: '600x450>',
        url: derivative_url('thumbnail')
      }]
      outputs.first[:layer] = 0 if needs_layer

      Hydra::Derivatives::ImageDerivatives.create(filename, outputs:)
    end
  end

  Hyrax::FileSetDerivativesService.prepend(im7_image_patch)
end
