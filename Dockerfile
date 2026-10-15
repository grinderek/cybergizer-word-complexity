FROM ruby:4.0.7-slim AS build
RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential libyaml-dev libpq-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 && rm -rf /usr/local/bundle/cache

FROM ruby:4.0.7-slim
WORKDIR /app
ENV RAILS_ENV=development \
    RAILS_LOG_TO_STDOUT=1
COPY --from=build /usr/local/bundle /usr/local/bundle
RUN apt-get update -qq && apt-get install --no-install-recommends -y libpq5 && rm -rf /var/lib/apt/lists/*
RUN groupadd --gid 1000 app && useradd --uid 1000 --gid app --create-home app
COPY --chown=app:app . .
USER app
EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
