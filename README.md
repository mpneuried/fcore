fcore
=====

A Node.js based RESTful API with a PostgreSQL and memcached backend to make working with forum like data structures easy.


See the API docs: http://docs.fcore.apiary.io/

## What does the fcore API do?

It handles all Reads and Writes including caching for you. What you use this for is up to you. 

## Installation

Make sure you have a PostgeSQL server running and use the script: `_sql/fcore_schema.sql` to create the base db.

Run on as many servers as you like:

`docker run -p 8080:8080 -e POSTGRESQL_USER=pgusername -e POSTGRESQL_PW=ABC123xyz456 -e POSTGRESQL_HOST=192.168.1.2 -e POSTGRESQL_DBNAME=fcore -e MEMCACHED_SERVERS='["192.168.1.3:11211"]' smrchy/fcore`

Environment variables:

POSTGRESQL_USER
POSTGRESQL_PW
POSTGRESQL_HOST
POSTGRESQL_DBNAME
MEMCACHED_SERVERS


# The MIT License

Please see the LICENSE.md file.
