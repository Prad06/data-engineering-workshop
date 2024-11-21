# Data Engineering Workshop

1. Setup and loading data into POSTGRES

   ```sh
   make up
   ```

   or

   ````sh
   docker compose up -d
   ```sh
   su - <postgres-username>
   ````

   - In case that the data is not being loaded

   - Go into the `my-postgres-container` bash

   `su - <postgres-username>`

   `cd docker-entrypoint-initdb.d`

   `sh init-db.sh` 2. Accessing the PostgreSQL Database

   - Connect to the PostgreSQL database using the following command:

     ```sh
     psql -h localhost -U <postgres-username> -d <database-name>
     ```

   3. Running Queries

      - Once connected, you can run SQL queries. For example, to list all tables:

        ```sql
        \dt
        ```

   4. Stopping the Services

      - To stop the Docker containers, use:

        ```sh
        make down
        ```

   5. Additional Resources

      - [PostgreSQL Documentation](https://www.postgresql.org/docs/)
      - [Docker Documentation](https://docs.docker.com/)
