ARG HYRAX_IMAGE_VERSION=hyrax-v5.2.0
FROM ghcr.io/samvera/hyrax/hyrax-base:$HYRAX_IMAGE_VERSION AS hyku-web

USER root
RUN git config --system --add safe.directory \*
ENV PATH="/app/samvera/bin:${PATH}"

USER app
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2
ENV MALLOC_CONF='dirty_decay_ms:1000,narenas:2,background_thread:true'

ENV TESSDATA_PREFIX=/app/samvera/tessdata
ADD https://github.com/tesseract-ocr/tessdata_best/blob/main/eng.traineddata?raw=true /app/samvera/tessdata/eng_best.traineddata

############### KNAPSACK SPECIFIC CODE ###################
# This means bundler inject looks at /app/samvera/.bundler.d for overrides
ENV HOME=/app/samvera
# This is specifically NOT $APP_PATH but the parent directory
COPY --chown=1001:101 . /app/samvera
ENV BUNDLE_LOCAL__HYKU_KNAPSACK=/app/samvera
ENV BUNDLE_DISABLE_LOCAL_BRANCH_CHECK=true
RUN bundle install --jobs "$(nproc)"

# Remove broken initializer from hyrax-webapp submodule if it exists.
# disable_solr.rb has a Ruby syntax error at line 16 that aborts assets:precompile.
# We also do not want Solr disabled in production — Solr must remain enabled.
RUN rm -f /app/samvera/hyrax-webapp/config/initializers/disable_solr.rb
############## END KNAPSACK SPECIFIC CODE ################

# assets:precompile is NOT run here — it runs at container startup via initialize_app
# against the ./data/assets bind mount. Running it at build time loads all Rails
# initializers (including broken ones in the submodule) and is redundant.
CMD ./bin/web

FROM hyku-web AS hyku-worker
CMD ./bin/worker

# Use a Solr version with patched Log4j to address CVE-2021-44228
FROM solr:8.11.2 AS hyku-solr
ENV SOLR_USER="solr" \
    SOLR_GROUP="solr"
USER root
COPY --chown=solr:solr solr/security.json /var/solr/data/security.json
USER $SOLR_USER