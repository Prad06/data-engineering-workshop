# data-engineering-workshop

1. Setup and loading data into POSTGRES
   `make up` or `docker compose up -d`

   In case that the data is not being loaded
   Go into the `my-postgres-container` bash
   `su - <postgres-username>`
   `cd docker-entrypoint-initdb.d`
   `sh init-db.sh`
