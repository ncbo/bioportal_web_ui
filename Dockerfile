FROM ruby:2.7.5-alpine AS app

WORKDIR /app

ARG UID=1000
ARG GID=1000

RUN apk add --no-cache \
    build-base \
    libxml2-dev \
    libxslt-dev \
    mariadb-dev \
    git \
    less \
    nodejs \
    tzdata \
    yarn \
  && addgroup --gid ${GID} ruby \
  && adduser  -u ${UID} -G ruby -D  ruby \
  && chown ruby:ruby -R /app \
  && mkdir /node_modules \
  && chown ruby:ruby -R /node_modules /app

USER ruby

COPY --chown=ruby:ruby bin/ ./bin
RUN chmod 0755 bin/*

ARG RAILS_ENV="production"

ENV RAILS_ENV="${RAILS_ENV}" \
    NODE_ENV="${NODE_ENV}" \
    PATH="${PATH}:/home/ruby/.local/bin:/node_modules/.bin" \
    USER="ruby" \
    BUNDLE_PATH=/usr/local/bundle

COPY --chown=ruby:ruby Gemfile* ./
RUN bundle install --jobs "$(nproc)"


RUN echo "--modules-folder /node_modules" > .yarnrc
COPY --chown=ruby:ruby package.json *yarn* ./
RUN yarn install

ENTRYPOINT ["/app/bin/docker-entrypoint-web"]

EXPOSE 3000

CMD ["sh"]