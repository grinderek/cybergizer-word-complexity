# Word Complexity API

An asynchronous Rails API that calculates a score for a list of English words using [Datamuse](https://www.datamuse.com/api/).

## Run

Requires Docker and Docker Compose. Run from the project directory:

```sh
docker compose up --build -d
```

The API is available at http://localhost:3000. PostgreSQL, Redis and Sidekiq start automatically, and database migrations run before the application starts.

To stop the services:

```sh
docker compose down
```

## Tests

Start the Docker stack as described in Run above. Before the first test run, prepare the separate test database:

```sh
docker compose exec -e RAILS_ENV=test api bin/rails db:prepare
```

Run all specs:

```sh
docker compose exec -e RAILS_ENV=test api bundle exec rspec
```

## API examples

### POST /complexity-score

```sh
curl http://localhost:3000/complexity-score \
  -H 'Content-Type: application/json' \
  -d '["angry", "sad", "qzxqzx"]'
```

Response (`200 OK`):

```json
{
  "job_id": "8b95272d-943a-446a-bcb4-09882aaee1c8"
}
```

### GET /complexity-score/:job_id

Use the `job_id` returned by POST:

```sh
curl http://localhost:3000/complexity-score/8b95272d-943a-446a-bcb4-09882aaee1c8
```

While waiting or processing, the response contains only `status`: `pending` or `in_progress` (`200 OK`):

```json
{
  "status": "in_progress"
}
```

Example completed response (`200 OK`):

```json
{
  "status": "completed",
  "result": {
    "angry": 7.5,
    "sad": 1.7
  },
  "errors": {
    "qzxqzx": "no_definitions"
  }
}
```

## Implementation

POST validates the input, normalizes words and removes duplicates. It creates a task in PostgreSQL to store the input, status, results and individual word errors, then enqueues a Sidekiq job. Status transitions use `with_lock` to prevent duplicate execution of the same task.

One background job processes the list, handling up to `WORD_CONCURRENCY` words concurrently (default: `3`). For each word, it checks `Rails.cache` first. On a cache miss, it fetches definitions, synonyms and antonyms from Datamuse. After removing duplicates, it calculates `(synonyms + antonyms) / definitions` and rounds the score to one decimal place. Successful scores are cached for 24 hours.

## Assumptions

- Input strings are trimmed and lowercased; blank strings are discarded. Invalid payloads and empty normalized lists return `422`.
- Related words are compared after trimming and lowercasing. A term appearing as both a synonym and an antonym counts in each category. Definitions use exact text matching after trimming; blank definitions are ignored.
- Missing definitions produce `no_definitions`. Empty synonym and antonym lists are valid and produce a score of `0.0` when definitions exist.
- Expected dictionary errors do not fail the task, even if every word has an error. Unexpected application errors set the task status to `failed`.
- Task records have no automatic expiry because retention is unspecified. Errors are not cached. If the cache is unavailable, calculations continue without caching.
- No application-level limit is imposed on input list size. Each relationship request asks for up to 1,000 entries. We assume this limit is more than sufficient for this assignment; counts may be incomplete if it is reached.
- Invalid JSON returns `400`, unknown task IDs return `404`, and storage or queue connection failures return `503`. Retrieving a failed task returns `200` with status `failed`.
