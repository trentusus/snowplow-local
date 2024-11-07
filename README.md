## Snowplow-local

## Licensing

What licenses does this use?

## Background

- How is this different from Snowplow Micro?

- How is this different from Snowplow Mini?


## Instructions

1. Clone this repo
2. `cd` into this folder
3. Make sure you have `docker-compose` installed
4. Run everything with `docker-compose up`
5. Open up a page to fire test events in your [browser](http://localhost:8082) using the Javascript tracker.

## Differences to a production pipeline

This software is not designed to be run in production and is instead designed for a local experience.

This includes statsd reporting intervals as well as caching settings for Iglu clients in order to more easily allow for patching without needing to clear caches.

## Configuring loaders

Loaders are configured using the `--profile` flag. Currently the following loaders are supported:

[*] Snowflake streaming loader (`--profile snowflake-loader`)
[*] Lake loader (Delta, Hudi & Iceberg) (`--profile lake-loader`)
[*] BigQuery streaming loader (`--profile bigquery-loader`)

If you would like to (optionally) run the Snowflake streaming loader as well you will need to run these steps.

1. Create a `.env` environment file from `.env.example` and configure your Snowflake private key and warehouse details. You will need a [private key](https://docs.snowflake.com/en/user-guide/key-pair-auth) set up rather than a username / password as this is what the app uses for authentication.
2. Launch docker compose with the warehouse you would like:
* For Snowflake streaming loader use:  `docker-compose --profile snowflake-loader up` which will launch the normal components + the Snowflake Kinesis loader. Omitting this profile won't spin the loader up at all.
* For the Lake loader use `--profile lake-loader`.
* For the BigQuery loader use `--profile bigquery-loader`.
3. Send some events!

You can optionally start and additional loader for incomplete events (for Snowflake only currently) by adding `--profile snowflake-incomplete-loader`.

## Configuring the collector

The collector runs with mostly default settings. You can configure the collector settings in `collector/config.hocon`.

## Configuring enrich

The enrichment process runs with mostly default settings. You can configure the enrichment process in `enrich/enrich.hocon`. Enrichments are read on startup from the `enrich/enrichments` directory.

As part of the enrichment process (to enable faster patching) the Iglu client uses a resolver with a cacheSize of 0 which avoids it caching schemas from Iglu Server. This reduces the performance of the pipeline in favour of an easier developer experience (for patching schemas actively in development). In a production context this value is often significantly higher (e.g., 500). You can modify the resolver settings in `iglu-client/resolver.json`.

## Configuring Iglu Server

Iglu Server primarily uses sensible defaults with the exception of.
`debug` which is set to true to aid in easier debugging (and exposes meta endpoints).
`patchesAllowed` which allows schemas of the same version to be patched even if they already exist - this tends to be useful in a development context but it something to be avoided in production.

You can configure Iglu Server in `iglu-server/config.hocon`.

### Configuring Snowbridge

If you would like to run Snowbridge locally you can use `--profile snowbridge` which will start Snowbridge as part of the pipeline. By default it will read from the `enriched-good` stream. This behaviour (including transformations, destinations etc) can be configured as part of the HCL configuration file in `snowbridge/config.hcl`.

This configuration writes to stdout for both the successful and failure targets for easier debugging but this can be changed easily in the configuration file.

By default Snowbridge uses `TRIM_HORIZON` to read from the Kinesis enriched stream. If you do not want this behaviour and instead want something that resembles `LATEST` you can set an environment variable when running docker compose to avoid processing older events e.g.,

`export START_TIMESTAMP =$(date +"%Y-%m-%d %H:%M:%S") && docker-compose --profile snowbridge up`

The syntax for this command may vary slightly depending on your shell.

## Supported components

* Scala stream collector 3.2.0
* Enrich 5.0.0
* Iglu Server 0.12.1
* Javascript tracker 3.23
* Snowflake streaming loader 0.2.3
* Lake loader 0.4.1
* BigQuery loader (2.0.0-rc10)
* Snowbridge 2.4.1

Under the hood Localstack is used to simulate the AWS components - primarily used for service messaging (Kinesis and Dynamodb).

## Monitoring

This setup includes a Grafana dashboard that can be accessed at [http://localhost:3000](http://localhost:3000) with the default credentials of `admin:admin`. Most components will emit metrics to statsd and as a result become available in Grafana. A default Graphite source is setup for you so you should not need to connect this.

Logs for components that write them (e.g., KPL, KCL) are written to Cloudwatch on Localstack.

The storage for Grafana is mounted as a volume so you can persist any dashboards and data across restarts, rather than losing them on reboot!

## Gotchas

### Snowflake loader
Snowflake requires your private key to be specified on a single line with the private key header, footer and any newlines removed. To do this you can run `cat <filepath/rsa_key1.p8> | grep -v PRIVATE | tr -d '\n\r'` and paste it in your `.env` file.


### BigQuery loader
BigQuery requires a service account key to be specified. Currently this needs to be done on the command line rather than passed in via the `.env` file. To do this set an environment variable `SERVICE_ACCOUNT_CREDENTIALS` in your terminal _before_ running `docker compose`.

e.g., for BASH use
```bash
export SERVICE_ACCOUNT_CREDENTIALS=$(cat /path/to/your/service-account-key.json)
```

## Incomplete events

Currently incomplete events load into the same table as successful events. This is deliberate - but can be overwritten by specifying a different table in the `incomplete` loader HOCON configuration file.

Incomplete events can be enabled by using the `--profile incomplete` flag when running docker-compose. Currently this only works for the Snowflake streaming loader but plans are in place to allow this to work for other loaders as well (please create a Github issue if you have specific requests).

Events that are incomplete can be identified in the warehouse by querying for the context being non-null i.e.,

```
FROM
    events
WHERE
    CONTEXTS_COM_SNOWPLOWANALYTICS_SNOWPLOW_FAILURE_1 IS NOT NULL
```

If you'd like to fire some example incomplete events you can do so from the [kitchen sink page](http://localhost:8082).

This currently has support for:
- incorrect type

## Known issues

The KCL, specifically within enrich has a pesty habit of being slow to 'steal' leases and start processing data on initial startup. Although events can be collected immediately it may take up to 60 seconds on subsequent startups for enrich to start enriching events. Once this period has passed everything works as per normal.